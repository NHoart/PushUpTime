import Foundation

/// Eine App, bei deren Öffnen eine Shortcuts-Automatisierung PushUpTime aufruft.
///
/// iOS erlaubt es keiner App zu bemerken, dass eine andere App geöffnet wurde –
/// das darf nur eine persönliche Automatisierung in der Shortcuts-App. Deshalb
/// merkt sich PushUpTime hier nur den App-Namen als Gedankenstütze und liefert
/// die passende URL, die die Automatisierung öffnen soll.
struct ShortcutRule: Codable, Identifiable, Equatable {
    var id: UUID
    var appName: String
    var createdAt: Date

    init(id: UUID = UUID(), appName: String, createdAt: Date = Date()) {
        self.id = id
        self.appName = appName
        self.createdAt = createdAt
    }

    /// `pushuptime://challenge?app=Instagram` – startet direkt die Challenge.
    var challengeURLString: String {
        let encoded = appName.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return "pushuptime://challenge?app=\(encoded)"
    }

    var challengeURL: URL? {
        URL(string: challengeURLString)
    }
}

enum ShortcutRuleStore {
    private static let key = "shortcutRules.v1"

    static func load() -> [ShortcutRule] {
        guard let data = SharedConfig.defaults.data(forKey: key),
              let rules = try? JSONDecoder().decode([ShortcutRule].self, from: data) else {
            return []
        }
        return rules
    }

    static func save(_ rules: [ShortcutRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        SharedConfig.defaults.set(data, forKey: key)
    }
}
