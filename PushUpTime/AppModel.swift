import Combine
import Foundation

/// Ziel für den Rücksprung nach einer erledigten Challenge.
struct ReturnTicket {
    let appName: String
    let url: URL
}

/// Zentraler Zustand der App: Shortcut-Regeln, Verlauf und die laufende Challenge.
@MainActor
final class AppModel: ObservableObject {
    struct ChallengeRequest: Identifiable {
        enum Kind {
            /// Reiner Test der Zählung.
            case test
            /// Freies Training: Kamera zählt, ohne Ziel.
            case free
            /// Aufruf über eine Shortcuts-Automatisierung, optional mit App-Namen.
            case shortcut(String?)
        }

        let id = UUID()
        let kind: Kind

        init(kind: Kind) {
            self.kind = kind
        }

        var title: String? {
            switch kind {
            case .test, .free:
                return nil
            case .shortcut(let name):
                return name
            }
        }
    }

    @Published private(set) var shortcutRules: [ShortcutRule] = []
    @Published private(set) var history: [ChallengeRecord] = []
    /// Welche Übung die nächste Challenge verlangt.
    @Published var exercise: ExerciseKind = .pushUps {
        didSet { SharedStore.exercise = exercise }
    }
    @Published var pushUpReps: Int = 30 {
        didSet { SharedStore.setReps(pushUpReps, for: .pushUps) }
    }
    @Published var twistReps: Int = 220 {
        didSet { SharedStore.setReps(twistReps, for: .russianTwists) }
    }
    /// Wie viele Minuten dieselbe App nach dem Überspringen Ruhe hat.
    @Published var bypassMinutes: Int = 10 {
        didSet { SharedStore.bypassMinutes = bypassMinutes }
    }
    /// Wie viele Liegestütze eine Minute Pause einbringen.
    @Published var pushUpRepsPerMinute: Int = 2 {
        didSet { SharedStore.setRepsPerMinute(pushUpRepsPerMinute, for: .pushUps) }
    }
    /// Wie viele Russian Twists eine Minute Pause einbringen.
    @Published var twistRepsPerMinute: Int = 2 {
        didSet { SharedStore.setRepsPerMinute(twistRepsPerMinute, for: .russianTwists) }
    }
    @Published var challenge: ChallengeRequest?
    @Published var errorMessage: String?

    private var challengeObserver: AnyCancellable?

    init() {
        shortcutRules = ShortcutRuleStore.load()
        history = ChallengeLog.load()
        exercise = SharedStore.exercise
        pushUpReps = SharedStore.reps(for: .pushUps)
        twistReps = SharedStore.reps(for: .russianTwists)
        bypassMinutes = SharedStore.bypassMinutes
        pushUpRepsPerMinute = SharedStore.repsPerMinute(for: .pushUps)
        twistRepsPerMinute = SharedStore.repsPerMinute(for: .russianTwists)

        // Der Shortcuts-Intent läuft im selben Prozess und meldet sich hier,
        // sobald die App im Vordergrund ist.
        challengeObserver = NotificationCenter.default
            .publisher(for: .pushUpTimeChallengeRequested)
            .sink { [weak self] _ in
                // Schwache Referenz einmal auflösen und den Wert in den Task
                // reichen – sonst nimmt Swift für die äußere Closure
                // unbemerkt eine starke `self`-Referenz auf.
                guard let model = self else { return }
                Task { @MainActor in
                    model.consumePendingChallenge()
                }
            }
    }

    // MARK: - Shortcuts-Modus

    func addShortcutRule(appName: String) {
        let clean = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        var all = ShortcutRuleStore.load()
        let exists = all.contains { $0.appName.localizedCaseInsensitiveCompare(clean) == .orderedSame }
        guard !exists else { return }

        all.append(ShortcutRule(
            appName: clean,
            returnURLString: ShortcutRule.suggestedReturnURLString(for: clean)
        ))
        ShortcutRuleStore.save(all)
        shortcutRules = all
    }

    func deleteShortcutRule(_ rule: ShortcutRule) {
        var all = ShortcutRuleStore.load()
        all.removeAll { $0.id == rule.id }
        ShortcutRuleStore.save(all)
        shortcutRules = all
    }

    /// Legt fest, wohin PushUpTime nach der Challenge zurückspringt.
    func setReturnURL(_ raw: String, for rule: ShortcutRule) {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var all = ShortcutRuleStore.load()
        guard let index = all.firstIndex(where: { $0.id == rule.id }) else { return }
        all[index].returnURLString = clean.isEmpty ? nil : clean
        ShortcutRuleStore.save(all)
        shortcutRules = all
    }

    func returnURL(forAppNamed name: String) -> URL? {
        shortcutRules
            .first { $0.appName.caseInsensitiveCompare(name) == .orderedSame }?
            .returnURL
    }

    /// Wird beim Öffnen der App über `pushuptime://challenge[?app=Name]` aufgerufen.
    func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "pushuptime" else { return }

        let host = url.host?.lowercased()
        guard host == nil || host == "challenge" else { return }

        let rawName = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "app" }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let appName = (rawName?.isEmpty ?? true) ? nil : rawName

        // Frisch übersprungen oder gerade zurückgesprungen: Die Automatisierung
        // hat uns nur wieder hergeholt, weil die App geöffnet wurde – dann keine
        // neue Challenge zeigen.
        if let appName {
            if LaunchPass.consume(for: appName) {
                challenge = nil
                return
            }
            if ShortcutBypass.isActive(for: appName) {
                challenge = nil
                return
            }
        }

        challenge = ChallengeRequest(kind: .shortcut(appName))
    }

    /// Übernimmt eine Challenge, die der Shortcuts-Intent im Hintergrund
    /// vorbereitet hat – auch nach einem Kaltstart.
    func consumePendingChallenge() {
        guard challenge == nil else { return }
        guard let pending = PendingChallenge.take() else { return }
        if let name = pending.appName, ShortcutBypass.isActive(for: name) { return }
        challenge = ChallengeRequest(kind: .shortcut(pending.appName))
    }

    func startTestChallenge() {
        challenge = ChallengeRequest(kind: .test)
    }

    /// Freies Training: Kamera zählt die Wiederholungen, ohne Ziel – das
    /// Ergebnis landet ganz normal im Verlauf.
    func startFreeChallenge() {
        challenge = ChallengeRequest(kind: .free)
    }

    /// Anzahl für eine Übung.
    func reps(for kind: ExerciseKind) -> Int {
        kind == .pushUps ? pushUpReps : twistReps
    }

    /// Anzahl für die gerade gewählte Übung.
    var requiredReps: Int { reps(for: exercise) }

    /// Setzt die Anzahl der gerade gewählten Übung.
    func setReps(_ value: Int) {
        switch exercise {
        case .pushUps:
            pushUpReps = max(1, value)
        case .russianTwists:
            twistReps = max(1, value)
        }
    }

    /// Wie viele Wiederholungen einer Übung eine Minute Pause einbringen.
    func repsPerMinute(for kind: ExerciseKind) -> Int {
        kind == .pushUps ? pushUpRepsPerMinute : twistRepsPerMinute
    }

    /// Rate der gerade gewählten Übung.
    var repsPerMinute: Int { repsPerMinute(for: exercise) }

    func setRepsPerMinute(_ value: Int, for kind: ExerciseKind) {
        switch kind {
        case .pushUps:
            pushUpRepsPerMinute = max(1, value)
        case .russianTwists:
            twistRepsPerMinute = max(1, value)
        }
    }

    /// Pause, die eine Anzahl Wiederholungen einbringt – mindestens eine Minute.
    /// - Parameter kind: Übung der Wiederholungen; ohne Angabe die gerade gewählte.
    func earnedMinutes(forReps reps: Int, exercise kind: ExerciseKind? = nil) -> Int {
        ChallengeRules.earnedMinutes(reps: reps, repsPerMinute: repsPerMinute(for: kind ?? exercise))
    }

    // MARK: - Verlauf

    func deleteRecord(_ record: ChallengeRecord) {
        history = ChallengeLog.delete(id: record.id)
    }

    /// Heute eingetragene Wiederholungen einer Übung.
    func todayReps(for kind: ExerciseKind) -> Int {
        history
            .filter { $0.exerciseKind == kind && Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.reps }
    }

    // MARK: - Statistik

    var stats: ChallengeStats {
        ChallengeLog.summary(of: history)
    }

    // MARK: - Challenge

    /// Beendet die Challenge ohne Zählung und gibt die App für eine Weile frei.
    /// Gibt es einen Rücksprung-Link, wird der Weg zurück vorbereitet.
    @discardableResult
    func skipChallenge() -> ReturnTicket? {
        guard let request = challenge else { return nil }
        challenge = nil

        guard case .shortcut(.some(let name)) = request.kind else { return nil }
        ShortcutBypass.grant(for: name, minutes: bypassMinutes)
        return ticket(forAppNamed: name)
    }

    // MARK: - Freigabe nach dem Überspringen

    /// Bis wann für diese App keine Challenge mehr kommt (`nil` = nie übersprungen).
    func bypassUntil(forAppNamed name: String) -> Date? {
        ShortcutBypass.until(for: name)
    }

    /// Bereitet den Rücksprung vor: Launch-Pass für die Automatisierung und
    /// das Ziel, das die Challenge-Ansicht anschließend öffnet.
    private func ticket(forAppNamed name: String) -> ReturnTicket? {
        guard let url = returnURL(forAppNamed: name) else { return nil }
        LaunchPass.grant(for: name)
        return ReturnTicket(appName: name, url: url)
    }

    /// Zählt die Challenge und liefert – wenn ein Rücksprung-Link hinterlegt
    /// ist – das Ziel für den Rücksprung.
    /// - Parameter reps: Tatsächlich per Kamera gezählte Wiederholungen. Ohne
    ///   Angabe wird die geforderte Anzahl eingetragen (normale Challenge).
    @discardableResult
    func completeChallenge(reps countedReps: Int? = nil) -> ReturnTicket? {
        guard let request = challenge else { return nil }
        challenge = nil

        var ticket: ReturnTicket?
        if case .shortcut(.some(let name)) = request.kind {
            // Nach der Challenge bleibt dieselbe App so lange ohne neue
            // Challenge, wie die Wiederholungen hergeben.
            let granted = earnedMinutes(
                forReps: max(1, countedReps ?? requiredReps),
                exercise: exercise
            )
            ShortcutBypass.grant(for: name, minutes: granted)
            ticket = self.ticket(forAppNamed: name)
        }

        // Testläufe zählen nicht in die Statistik.
        if case .test = request.kind { return ticket }
        history = ChallengeLog.record(
            reps: max(1, countedReps ?? requiredReps),
            appName: request.title,
            exercise: exercise
        )
        return ticket
    }
}
