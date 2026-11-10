import Foundation

/// Gemeinsame Basis für App und App-Intent.
enum SharedConfig {
    static let repsKey = "requiredReps.v1"
    static let twistRepsKey = "requiredTwistReps.v1"
    static let exerciseKey = "exerciseKind.v1"
    static let bypassKey = "shortcutBypassMinutes.v1"
    static let rewardRateKey = "repsPerMinute.v1"
    static let pushUpRateKey = "repsPerMinute.pushUps.v1"
    static let twistRateKey = "repsPerMinute.russianTwists.v1"

    /// App und App-Intent laufen im selben Prozess und teilen diesen Speicher.
    static var defaults: UserDefaults { .standard }
}

/// Welche Übung eine Challenge verlangt.
enum ExerciseKind: String, Codable, CaseIterable, Identifiable {
    case pushUps
    case russianTwists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pushUps: return "Liegestütze"
        case .russianTwists: return "Russian Twists"
        }
    }

    /// Anzahl, die ohne eigene Einstellung gilt.
    var defaultReps: Int {
        switch self {
        case .pushUps: return 30
        case .russianTwists: return 220
        }
    }

    var icon: String {
        switch self {
        case .pushUps: return "figure.strengthtraining.traditional"
        case .russianTwists: return "figure.core.training"
        }
    }

    /// Kopfzeile der Challenge.
    var statusLabel: String {
        switch self {
        case .pushUps: return "ZEIT FÜR LIEGESTÜTZE"
        case .russianTwists: return "ZEIT FÜR RUSSIAN TWISTS"
        }
    }

    /// Einzahl/Mehrzahl für Anzeigen wie „220 Russian Twists“.
    func unit(for count: Int) -> String {
        switch self {
        case .pushUps:
            return count == 1 ? "Liegestütz" : "Liegestütze"
        case .russianTwists:
            return count == 1 ? "Russian Twist" : "Russian Twists"
        }
    }

    /// Wie das iPhone für die Kamera-Zählung stehen soll.
    var setupHint: String {
        switch self {
        case .pushUps:
            return "iPhone seitlich ablegen, sodass Schulter, Ellbogen und Handgelenk sichtbar sind."
        case .russianTwists:
            return "iPhone vor dich stellen, sodass Schultern, Hände und Becken sichtbar sind."
        }
    }
}

/// Persistenz für Standard-Übung, Wiederholungen und die Überspringen-Zeit.
enum SharedStore {
    /// Aktuell gewählte Übung – gilt für Shortcut-Aufrufe und die Oberfläche.
    static var exercise: ExerciseKind {
        get {
            guard let raw = SharedConfig.defaults.string(forKey: SharedConfig.exerciseKey),
                  let kind = ExerciseKind(rawValue: raw) else {
                return .pushUps
            }
            return kind
        }
        set { SharedConfig.defaults.set(newValue.rawValue, forKey: SharedConfig.exerciseKey) }
    }

    static func reps(for kind: ExerciseKind) -> Int {
        let stored = SharedConfig.defaults.integer(forKey: key(for: kind))
        return stored == 0 ? kind.defaultReps : max(1, stored)
    }

    static func setReps(_ value: Int, for kind: ExerciseKind) {
        SharedConfig.defaults.set(max(1, value), forKey: key(for: kind))
    }

    /// Anzahl für die aktuell gewählte Übung (z. B. für die Shortcut-Anleitung).
    static var requiredReps: Int { reps(for: exercise) }

    /// Wie viele Wiederholungen einer Übung eine Minute Pause einbringen
    /// (Standard 2 – pro Übung einstellbar).
    static func repsPerMinute(for kind: ExerciseKind) -> Int {
        let key = rateKey(for: kind)
        if SharedConfig.defaults.object(forKey: key) != nil {
            return max(1, SharedConfig.defaults.integer(forKey: key))
        }
        // Früher galt ein gemeinsamer Wert für beide Übungen – den übernehmen.
        if SharedConfig.defaults.object(forKey: SharedConfig.rewardRateKey) != nil {
            return max(1, SharedConfig.defaults.integer(forKey: SharedConfig.rewardRateKey))
        }
        return 2
    }

    static func setRepsPerMinute(_ value: Int, for kind: ExerciseKind) {
        SharedConfig.defaults.set(max(1, value), forKey: rateKey(for: kind))
    }

    /// Minuten, die eine übersprungene App freibleibt (Standard 10, 0 = keine Pause).
    static var bypassMinutes: Int {
        get {
            guard SharedConfig.defaults.object(forKey: SharedConfig.bypassKey) != nil else { return 10 }
            return max(0, SharedConfig.defaults.integer(forKey: SharedConfig.bypassKey))
        }
        set { SharedConfig.defaults.set(max(0, newValue), forKey: SharedConfig.bypassKey) }
    }

    private static func key(for kind: ExerciseKind) -> String {
        switch kind {
        case .pushUps: return SharedConfig.repsKey
        case .russianTwists: return SharedConfig.twistRepsKey
        }
    }

    private static func rateKey(for kind: ExerciseKind) -> String {
        switch kind {
        case .pushUps: return SharedConfig.pushUpRateKey
        case .russianTwists: return SharedConfig.twistRateKey
        }
    }
}

/// Kurzlebige Freigabe für den Rücksprung in die Ziel-App.
///
/// Beim Verlassen von PushUpTime wird ein Pass hinterlegt. Die
/// Shortcuts-Automatisierung fragt beim Öffnen der Ziel-App erneut an – der
/// App-Intent sieht den Pass, bleibt im Hintergrund und lässt die App normal
/// aufgehen. Ohne Pass würde die Automatisierung PushUpTime sofort wieder
/// nach vorn holen.
enum LaunchPass {
    /// Gültigkeit in Sekunden – der Rücksprung passiert normalerweise sofort.
    private static let defaultLifetime: TimeInterval = 180
    private static let prefix = "launchPass."

    static func grant(for appName: String, lifetime: TimeInterval = defaultLifetime) {
        let until = Date().addingTimeInterval(lifetime)
        SharedConfig.defaults.set(until.timeIntervalSince1970, forKey: prefix + appName.lowercased())
    }

    /// Einmaliger Verbrauch. `true` = gerade eben freigegeben, Challenge überspringen.
    static func consume(for appName: String) -> Bool {
        let key = prefix + appName.lowercased()
        let until = SharedConfig.defaults.double(forKey: key)
        guard until > 0 else { return false }
        SharedConfig.defaults.removeObject(forKey: key)
        return Date(timeIntervalSince1970: until) > Date()
    }

    static func clear(for appName: String) {
        SharedConfig.defaults.removeObject(forKey: prefix + appName.lowercased())
    }
}

/// Freigabe nach „Überspringen“: So lange löst dieselbe App keine Challenge aus.
enum ShortcutBypass {
    private static let prefix = "shortcutBypassUntil."

    static func until(for appName: String) -> Date? {
        let stored = SharedConfig.defaults.double(forKey: prefix + appName.lowercased())
        guard stored > 0 else { return nil }
        return Date(timeIntervalSince1970: stored)
    }

    static func isActive(for appName: String) -> Bool {
        guard let until = until(for: appName) else { return false }
        return until > Date()
    }

    static func grant(for appName: String, minutes: Int) {
        let key = prefix + appName.lowercased()
        guard minutes > 0 else {
            // 0 Minuten = keine Freigabe nach dem Überspringen.
            SharedConfig.defaults.removeObject(forKey: key)
            return
        }
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
        SharedConfig.defaults.set(until.timeIntervalSince1970, forKey: key)
    }
}

/// Von der Shortcuts-Automatisierung gestartete Challenge, die die App beim
/// Aktivieren übernimmt.
struct PendingChallengeRequest {
    var appName: String?
}

enum PendingChallenge {
    private static let appKey = "pendingChallenge.app"
    private static let dateKey = "pendingChallenge.createdAt"

    static func set(appName: String?) {
        SharedConfig.defaults.set(appName ?? "", forKey: appKey)
        SharedConfig.defaults.set(Date().timeIntervalSince1970, forKey: dateKey)
    }

    static func clear() {
        SharedConfig.defaults.removeObject(forKey: appKey)
        SharedConfig.defaults.removeObject(forKey: dateKey)
    }

    /// Holt die Anfrage genau einmal. `nil` = keine (oder eine zu alte) Anfrage.
    static func take(maxAge: TimeInterval = 30) -> PendingChallengeRequest? {
        let defaults = SharedConfig.defaults
        let createdAt = defaults.double(forKey: dateKey)
        guard createdAt > 0 else { return nil }

        let raw = defaults.string(forKey: appKey) ?? ""
        clear()

        let age = Date().timeIntervalSince1970 - createdAt
        guard age >= 0, age <= maxAge else { return nil }
        return PendingChallengeRequest(appName: raw.isEmpty ? nil : raw)
    }
}

extension Notification.Name {
    /// Wird vom App-Intent gepostet, sobald PushUpTime im Vordergrund ist.
    static let pushUpTimeChallengeRequested = Notification.Name("pushUpTimeChallengeRequested")
}
