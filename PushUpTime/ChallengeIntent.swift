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

    @Parameter(title: "App")
    var app: TrackedAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Liegestütze für \(\.$app) starten")
    }

    func perform() async throws -> some IntentResult {
        let appName = app?.appName

        if let appName {
            // Frisch freigegeben: still bleiben, damit der Rücksprung nicht
            // sofort wieder von der Automatisierung unterbrochen wird.
            if LaunchPass.consume(for: appName) { return .result() }
            if ShortcutBypass.isActive(for: appName) { return .result() }
        }

        // Für den Kaltstart: Die Anfrage liegt in der App Group, bis die App
        // sie beim Aktivieren übernimmt.
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

/// Eine in PushUpTime angelegte App – als Auswahl für die Automatisierung.
@available(iOS 26.0, *)
struct TrackedAppEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "App"
    static let defaultQuery = TrackedAppQuery()

    var id: String
    var appName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(appName)")
    }
}

@available(iOS 26.0, *)
struct TrackedAppQuery: EntityQuery {
    func entities(for identifiers: [TrackedAppEntity.ID]) async throws -> [TrackedAppEntity] {
        let rules = ShortcutRuleStore.load()
        return identifiers.compactMap { identifier in
            rules.first { $0.id.uuidString == identifier }.map {
                TrackedAppEntity(id: $0.id.uuidString, appName: $0.appName)
            }
        }
    }

    func suggestedEntities() async throws -> [TrackedAppEntity] {
        ShortcutRuleStore.load().map {
            TrackedAppEntity(id: $0.id.uuidString, appName: $0.appName)
        }
    }

    func defaultResult() async -> TrackedAppEntity? {
        ShortcutRuleStore.load().first.map {
            TrackedAppEntity(id: $0.id.uuidString, appName: $0.appName)
        }
    }
}
