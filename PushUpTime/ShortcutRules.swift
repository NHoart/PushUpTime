import Foundation

/// Eine App, bei deren Öffnen eine Shortcuts-Automatisierung PushUpTime aufruft.
///
/// iOS erlaubt es keiner App zu bemerken, dass eine andere App geöffnet wurde –
/// das darf nur eine persönliche Automatisierung in der Shortcuts-App. Deshalb
/// merkt sich PushUpTime hier nur den App-Namen als Gedankenstütze und liefert
/// die passende Aktion, die die Automatisierung auslösen soll.
struct ShortcutRule: Codable, Identifiable, Equatable {
    var id: UUID
    var appName: String
    var createdAt: Date
    /// Link, mit dem PushUpTime nach der Challenge zurück in die App springt,
    /// z. B. `instagram://`. `nil` = aus dem App-Namen ableiten.
    var returnURLString: String?

    init(id: UUID = UUID(),
         appName: String,
         createdAt: Date = Date(),
         returnURLString: String? = nil) {
        self.id = id
        self.appName = appName
        self.createdAt = createdAt
        self.returnURLString = returnURLString
    }

    /// `pushuptime://challenge?app=Instagram` – startet direkt die Challenge.
    var challengeURLString: String {
        let encoded = appName.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return "pushuptime://challenge?app=\(encoded)"
    }

    var challengeURL: URL? {
        URL(string: challengeURLString)
    }

    /// Wohin es nach den Liegestützen zurückgeht (`nil` = kein Rücksprung).
    var returnURL: URL? {
        let stored = returnURLString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw: String?
        if let stored, !stored.isEmpty {
            raw = Self.migratedReturnURLString(stored, for: appName)
        } else {
            raw = Self.suggestedReturnURLString(for: appName)
        }
        return Self.normalizedURL(raw)
    }

    /// Link-Schema für bekannte Apps, damit das Feld meist schon stimmt.
    static func suggestedReturnURLString(for appName: String) -> String? {
        knownSchemes[appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    /// YouTube öffnete früher nur die Startseite (`youtube://`). Wer den Link so
    /// gespeichert hat, landet jetzt direkt in „Später ansehen“ – eigene Links
    /// bleiben unangetastet.
    static func migratedReturnURLString(_ stored: String, for appName: String) -> String {
        guard appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "youtube" else {
            return stored
        }
        let compact = stored.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        return legacyYouTubeLinks.contains(compact) ? youtubeWatchLaterURLString : stored
    }

    /// „Später ansehen“ im YouTube-App-Link (`list=WL`).
    static let youtubeWatchLaterURLString = "youtube://www.youtube.com/playlist?list=WL"

    /// Frühere YouTube-Links, die nur die Startseite öffneten.
    private static let legacyYouTubeLinks: Set<String> = [
        "youtube:",
        "youtube://",
        "youtube:///",
        "youtube://youtube.com",
        "youtube://www.youtube.com",
        "youtube://m.youtube.com",
        "https://youtube.com",
        "https://www.youtube.com",
        "https://m.youtube.com"
    ]

    /// Macht aus „instagram“ ein `instagram://` und filtert Unsinn aus.
    static func normalizedURL(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains(":") {
            text += "://"
        }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme != "pushuptime" else {
            return nil
        }
        return url
    }

    private static let knownSchemes: [String: String] = [
        "instagram": "instagram://",
        "tiktok": "tiktok://",
        "youtube": youtubeWatchLaterURLString,
        "x": "twitter://",
        "twitter": "twitter://",
        "snapchat": "snapchat://",
        "facebook": "fb://",
        "reddit": "reddit://",
        "whatsapp": "whatsapp://",
        "telegram": "tg://",
        "discord": "discord://",
        "spotify": "spotify://",
        "netflix": "nflx://",
        "pinterest": "pinterest://",
        "linkedin": "linkedin://",
        "twitch": "twitch://",
        "threads": "barcelona://",
        "mail": "mailto:",
        "nachrichten": "sms:",
        "messages": "sms:",
        "musik": "music://",
        "music": "music://",
        "karten": "maps://",
        "maps": "maps://",
        "kalender": "calshow://",
        "calendar": "calshow://",
        "notizen": "mobilenotes://",
        "notes": "mobilenotes://"
    ]
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
