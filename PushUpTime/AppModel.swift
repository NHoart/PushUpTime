import Combine
import FamilyControls
import Foundation
import ManagedSettings
import UIKit

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

        var statusLabel: String {
            switch kind {
            case .test:
                return "TESTLAUF"
            case .shortcut:
                return "ZEIT FÜR LIEGESTÜTZE"
            case .screenTime:
                return "GESPERRT"
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
    @Published var requiredReps: Int = 30 {
        didSet { SharedStore.requiredReps = requiredReps }
    }
    @Published private(set) var auth: AuthState = .unknown
    @Published var challenge: ChallengeRequest?
    @Published var errorMessage: String?

    init() {
        entries = SharedStore.loadEntries()
        shortcutRules = ShortcutRuleStore.load()
        history = ChallengeLog.load()
        requiredReps = SharedStore.requiredReps
        updateAuthorizationState()
    }

    // MARK: - Shortcuts-Modus (ohne Bildschirmzeit)

    func addShortcutRule(appName: String) {
        let clean = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        var all = ShortcutRuleStore.load()
        let exists = all.contains { $0.appName.localizedCaseInsensitiveCompare(clean) == .orderedSame }
        guard !exists else { return }

        all.append(ShortcutRule(appName: clean))
        ShortcutRuleStore.save(all)
        shortcutRules = all
    }

    func deleteShortcutRule(_ rule: ShortcutRule) {
        var all = ShortcutRuleStore.load()
        all.removeAll { $0.id == rule.id }
        ShortcutRuleStore.save(all)
        shortcutRules = all
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

        // Frisch übersprungen: Die Automatisierung hat uns nur wieder hergeholt,
        // weil die App geöffnet wurde – dann keine neue Challenge zeigen.
        if let appName, let until = bypassUntil(forAppNamed: appName), until > Date() {
            challenge = nil
            return
        }

        challenge = ChallengeRequest(kind: .shortcut(appName))
    }

    func startTestChallenge() {
        challenge = ChallengeRequest(kind: .test)
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

    /// Beendet die Challenge, ohne Liegestütze zu zählen, und springt zurück in die
    /// App, die sie per Shortcuts-Automatisierung ausgelöst hat.
    func skipChallenge() {
        guard let request = challenge else { return }
        challenge = nil

        guard case .shortcut(let name?) = request.kind else { return }
        // Ohne Freigabe würde das Öffnen der App die Automatisierung erneut auslösen
        // und die Challenge sofort wieder erscheinen.
        grantBypass(forAppNamed: name)

        guard let target = AppDeepLink.url(forAppNamed: name) else { return }

        // Erst die Challenge-Ansicht schließen lassen, dann die App öffnen.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            _ = await UIApplication.shared.open(target)
        }
    }

    // MARK: - Freigabe nach dem Überspringen

    /// So lange löst ein übersprungener App-Aufruf keine neue Challenge aus.
    private static let bypassDuration: TimeInterval = 10 * 60

    private func bypassKey(forAppNamed name: String) -> String {
        "shortcutBypassUntil." + name.lowercased()
    }

    /// Bis wann für diese App keine Challenge mehr kommt (`nil` = nie übersprungen).
    func bypassUntil(forAppNamed name: String) -> Date? {
        let stored = SharedConfig.defaults.double(forKey: bypassKey(forAppNamed: name))
        guard stored > 0 else { return nil }
        return Date(timeIntervalSince1970: stored)
    }

    private func grantBypass(forAppNamed name: String) {
        let until = Date().addingTimeInterval(Self.bypassDuration)
        SharedConfig.defaults.set(until.timeIntervalSince1970, forKey: bypassKey(forAppNamed: name))
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

    func completeChallenge() {
        guard let request = challenge else { return }
        challenge = nil

        if case .screenTime(let entry) = request.kind {
            startRound(entry)
        }

        // Testläufe zählen nicht in die Statistik.
        if case .test = request.kind { return }
        history = ChallengeLog.record(reps: max(1, requiredReps), appName: request.title)
    }
}
