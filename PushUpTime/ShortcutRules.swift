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

/// Überspringen heißt: zurück in die App, die die Challenge ausgelöst hat.
///
/// iOS erlaubt es keiner App, eine andere über ihren Namen zu öffnen – das geht
/// nur über deren URL-Schema. Deshalb kennt PushUpTime die gängigen Ablenkungs-Apps;
/// bei unbekannten Namen bleibt es beim bloßen Schließen der Challenge.
enum AppDeepLink {
    /// App-Name (klein, ohne Leerzeichen) → URL-Schema, das die App öffnet.
    private static let schemes: [String: String] = [
        "instagram": "instagram://app",
        "threads": "barcelona://",
        "youtube": "youtube://",
        "youtubemusic": "youtubemusic://",
        "tiktok": "snssdk1128://",
        "twitter": "twitter://",
        "x": "twitter://",
        "facebook": "fb://",
        "snapchat": "snapchat://",
        "reddit": "reddit://",
        "netflix": "nflx://",
        "twitch": "twitch://",
        "discord": "discord://",
        "pinterest": "pinterest://",
        "linkedin": "linkedin://",
        "whatsapp": "whatsapp://",
        "telegram": "tg://",
        "spotify": "spotify://"
    ]

    /// URL, die die App öffnet – `nil`, wenn der Name unbekannt ist.
    static func url(forAppNamed name: String?) -> URL? {
        guard let name else { return nil }
        let key = name.lowercased().filter { !$0.isWhitespace }
        guard let raw = schemes[key] else { return nil }
        return URL(string: raw)
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
