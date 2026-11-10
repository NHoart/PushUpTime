import Combine
import FamilyControls
import Foundation
import ManagedSettings

/// Ziel für den Rücksprung nach einer erledigten Challenge.
struct ReturnTicket {
    let appName: String
    let url: URL
}

/// Zentraler Zustand der App: Shortcut-Regeln, optionale Bildschirmzeit-Sperren
/// und die laufende Challenge.
@MainActor
final class AppModel: ObservableObject {
    enum AuthState: Equatable {
        case unknown
        case notDetermined
        case approved
        case denied
        case failed(String)

        var isApproved: Bool { self == .approved }
    }

    struct ChallengeRequest: Identifiable {
        enum Kind {
            /// Reiner Test der Zählung ohne Sperre.
            case test
            /// Aufruf über eine Shortcuts-Automatisierung, optional mit App-Namen.
            case shortcut(String?)
            /// Echte Bildschirmzeit-Sperre, die nach der Challenge freigegeben wird.
            case screenTime(BlockerEntry)
        }

        let id = UUID()
        let kind: Kind

        var title: String? {
            switch kind {
            case .test:
                return nil
            case .shortcut(let name):
                return name
            case .screenTime(let entry):
                return entry.title
            }
        }

        /// Nur bei einer echten Sperre gibt es etwas freizugeben.
        var isBlocking: Bool {
            if case .screenTime = kind { return true }
            return false
        }
    }

    @Published private(set) var entries: [BlockerEntry] = []
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
    /// Wie viele Minuten eine übersprungene App freibleibt.
    @Published var bypassMinutes: Int = 10 {
        didSet { SharedStore.bypassMinutes = bypassMinutes }
    }
    @Published private(set) var auth: AuthState = .unknown
    @Published var challenge: ChallengeRequest?
    @Published var errorMessage: String?

    private var challengeObserver: AnyCancellable?

    init() {
        entries = SharedStore.loadEntries()
        shortcutRules = ShortcutRuleStore.load()
        history = ChallengeLog.load()
        exercise = SharedStore.exercise
        pushUpReps = SharedStore.reps(for: .pushUps)
        twistReps = SharedStore.reps(for: .russianTwists)
        bypassMinutes = SharedStore.bypassMinutes
        updateAuthorizationState()

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

    // MARK: - Shortcuts-Modus (ohne Bildschirmzeit)

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

    // MARK: - Manuelles Tracking

    /// Trägt eine Einheit von Hand in den Verlauf ein – ohne Kamera-Challenge.
    func trackExercise(_ kind: ExerciseKind, reps: Int, date: Date = Date()) {
        history = ChallengeLog.record(
            reps: max(1, reps),
            appName: nil,
            exercise: kind,
            date: date,
            source: .manual
        )
    }

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

    // MARK: - Bildschirmzeit-Freigabe

    func updateAuthorizationState() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            auth = .approved
        case .denied:
            auth = .denied
        case .notDetermined:
            auth = .notDetermined
        case .approvedWithDataAccess:
            auth = .approved
        @unknown default:
            auth = .unknown
        }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            updateAuthorizationState()
        } catch {
            updateAuthorizationState()
            if auth != .approved {
                auth = .failed(Self.describe(error))
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain.localizedCaseInsensitiveContains("FamilyControls")
            || nsError.domain.localizedCaseInsensitiveContains("Authorization") {
            return "Bildschirmzeit nicht verfügbar (Code \(nsError.code)). Das Sperren anderer Apps braucht die von Apple genehmigte Family-Controls-Berechtigung. Kostenlose persönliche Apple-Teams unterstützen sie nicht – dafür ist eine kostenpflichtige Apple-Developer-Mitgliedschaft nötig."
        }
        return error.localizedDescription
    }

    // MARK: - Bildschirmzeit-Sperren verwalten

    func reload() {
        entries = SharedStore.loadEntries()
    }

    func addBlocker(title: String, minutes: Int, selection: FamilyActivitySelection) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var entry = BlockerEntry(
            title: cleanTitle.isEmpty ? "Sperre" : cleanTitle,
            minutes: minutes,
            selection: selection
        )
        entry.roundSerial = 1

        var all = SharedStore.loadEntries()
        all.append(entry)
        SharedStore.save(all)

        if auth.isApproved {
            RoundScheduler.startRound(for: entry, serial: 1)
        }
        reload()
    }

    func delete(_ entry: BlockerEntry) {
        RoundScheduler.stopRounds(for: entry.id)
        ShieldManager.clearShield(for: entry.id)

        var all = SharedStore.loadEntries()
        all.removeAll { $0.id == entry.id }
        SharedStore.save(all)
        reload()
    }

    func setMinutes(_ minutes: Int, for entry: BlockerEntry) {
        SharedStore.update(id: entry.id) { $0.minutes = max(1, minutes) }
        reload()

        guard let updated = entries.first(where: { $0.id == entry.id }), !updated.isLocked else { return }
        RoundScheduler.startRound(for: updated, serial: updated.roundSerial)
    }

    // MARK: - Sperren und Freigeben

    /// Sperrt sofort (ohne Zeitlimit abzuwarten) – auch zum Testen.
    func lockNow(_ entry: BlockerEntry) {
        ShieldManager.applyShield(for: entry)
        RoundScheduler.stopRounds(for: entry.id)
        SharedStore.update(id: entry.id) { $0.isLocked = true }
        reload()
    }

    /// Startet eine neue Runde: Sperre weg, Zeitbudget läuft wieder.
    func startRound(_ entry: BlockerEntry) {
        let serial = entry.roundSerial + 1
        ShieldManager.clearShield(for: entry.id)
        let started = RoundScheduler.startRound(for: entry, serial: serial)
        SharedStore.update(id: entry.id) {
            $0.isLocked = false
            $0.roundSerial = serial
        }
        if !started {
            errorMessage = "Das Zeitlimit konnte nicht gestartet werden. Prüfe, ob Bildschirmzeit für PushUpTime freigegeben ist."
        }
        reload()
    }

    /// Notfall-Ausweg, damit niemand dauerhaft ausgesperrt ist.
    func emergencyUnlock(_ entry: BlockerEntry) {
        ShieldManager.clearShield(for: entry.id)
        RoundScheduler.stopRounds(for: entry.id)
        SharedStore.update(id: entry.id) { $0.isLocked = false }
        reload()
    }

    // MARK: - Challenge

    func beginChallenge(for entry: BlockerEntry) {
        challenge = ChallengeRequest(kind: .screenTime(entry))
    }

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

    /// Gibt die aktuell gesperrte App frei und beendet die Challenge.
    func emergencyUnlockCurrent() {
        guard let request = challenge, case .screenTime(let entry) = request.kind else {
            challenge = nil
            return
        }
        emergencyUnlock(entry)
        challenge = nil
    }

    /// Zählt die Challenge, gibt eine Bildschirmzeit-Sperre frei und liefert –
    /// wenn ein Rücksprung-Link hinterlegt ist – das Ziel für den Rücksprung.
    @discardableResult
    func completeChallenge() -> ReturnTicket? {
        guard let request = challenge else { return nil }
        challenge = nil

        var ticket: ReturnTicket?
        switch request.kind {
        case .screenTime(let entry):
            startRound(entry)
        case .shortcut(.some(let name)):
            ticket = self.ticket(forAppNamed: name)
        case .shortcut(.none), .test:
            break
        }

        // Testläufe zählen nicht in die Statistik.
        if case .test = request.kind { return ticket }
        history = ChallengeLog.record(
            reps: max(1, requiredReps),
            appName: request.title,
            exercise: exercise
        )
        return ticket
    }
}
