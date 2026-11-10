import AppIntents
import Foundation

/// Der Intent, den die Shortcuts-Automatisierung anstelle von
/// `pushuptime://challenge` aufruft.
///
/// Er startet im Hintergrund und schaut zuerst, ob gerade eben eine Challenge
/// erledigt wurde. Dann bleibt er still und die Ziel-App öffnet sich normal –
/// das ist der Rücksprung ohne Endlosschleife. Sonst wechselt er in den
/// Vordergrund und startet die Liegestütz-Zählung.
@available(iOS 26.0, *)
struct StartChallengeIntent: AppIntent {
    static let title: LocalizedStringResource = "Liegestütze starten"
    static let description = IntentDescription(
        "Prüft, ob du gerade freigegeben bist, und startet sonst die Liegestütz-Challenge."
    )
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    /// Pflichtfeld: Ohne App weiß PushUpTime nicht, wohin es zurückspringen
    /// soll – dann gäbe es nach der Challenge keinen Rücksprung.
    @Parameter(title: "App")
    var app: TrackedAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Liegestütze für \(\.$app) starten")
    }

    func perform() async throws -> some IntentResult {
        let appName = app.resolvedAppName
        guard !appName.isEmpty else { throw MissingTrackedAppError() }

        // Frisch freigegeben: still bleiben, damit der Rücksprung nicht
        // sofort wieder von der Automatisierung unterbrochen wird.
        if LaunchPass.consume(for: appName) { return .result() }
        if ShortcutBypass.isActive(for: appName) { return .result() }

        // Für den Kaltstart: Die Anfrage liegt im Speicher, bis die App sie
        // beim Aktivieren übernimmt.
        PendingChallenge.set(appName: appName)

        guard systemContext.currentMode.canContinueInForeground else {
            PendingChallenge.clear()
            return .result()
        }

        do {
            try await continueInForeground(alwaysConfirm: false)
        } catch {
            PendingChallenge.clear()
            return .result()
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .pushUpTimeChallengeRequested, object: nil)
        }
        return .result()
    }
}

/// Pflichtfeld leer: lieber sichtbar abbrechen, als still ohne
/// Rücksprung-Link weiterzulaufen.
@available(iOS 26.0, *)
struct MissingTrackedAppError: Error, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        "Bitte bei „App“ eine App aus PushUpTime auswählen."
    }
}

/// Eine in PushUpTime angelegte App – als Auswahl für die Automatisierung.
///
/// Die Kennung ist der App-Name selbst. Dadurch bleibt die Auswahl in
/// Shortcuts gültig, auch wenn der Eintrag in PushUpTime später neu angelegt
/// wird – und beim Ausführen braucht die Automatisierung die Einträge nicht
/// erneut zu laden.
@available(iOS 26.0, *)
struct TrackedAppEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "App"
    static let defaultQuery = TrackedAppQuery()

    var id: String
    var appName: String

    init(id: String, appName: String) {
        self.id = id
        self.appName = appName
    }

    init(appName: String) {
        let clean = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = clean
        self.appName = clean
    }

    /// Immer ein brauchbarer Name – notfalls die Kennung.
    var resolvedAppName: String {
        let name = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(appName)")
    }
}

@available(iOS 26.0, *)
struct TrackedAppQuery: EntityQuery {
    func entities(for identifiers: [TrackedAppEntity.ID]) async throws -> [TrackedAppEntity] {
        let rules = ShortcutRuleStore.load()
        return identifiers.compactMap { identifier in
            let clean = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }

            // Neuer Weg: Die Kennung ist der App-Name.
            if let rule = rules.first(where: {
                $0.appName.caseInsensitiveCompare(clean) == .orderedSame
            }) {
                return TrackedAppEntity(id: clean, appName: rule.appName)
            }

            // Alter Weg: Die Kennung ist die UUID des Eintrags. Groß- und
            // Kleinschreibung darf dabei keine Rolle spielen.
            if let rule = rules.first(where: {
                $0.id.uuidString.caseInsensitiveCompare(clean) == .orderedSame
            }) {
                return TrackedAppEntity(id: clean, appName: rule.appName)
            }

            // Eintrag wurde gelöscht: Den Namen aus der Kennung retten, damit
            // die Challenge weiterhin weiß, wohin der Rücksprung geht.
            if UUID(uuidString: clean) == nil {
                return TrackedAppEntity(id: clean, appName: clean)
            }
            return nil
        }
    }

    func suggestedEntities() async throws -> [TrackedAppEntity] {
        ShortcutRuleStore.load().map {
            TrackedAppEntity(id: $0.appName, appName: $0.appName)
        }
    }

    func defaultResult() async -> TrackedAppEntity? {
        ShortcutRuleStore.load().first.map {
            TrackedAppEntity(id: $0.appName, appName: $0.appName)
        }
    }
}
