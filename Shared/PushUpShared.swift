import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Gemeinsame Basis für App und Erweiterungen (App Group).
enum SharedConfig {
    /// Muss mit der App-Group in den Entitlements und im Developer-Portal übereinstimmen.
    static let appGroupID = "group.com.noahh.pushuptime.9c31f7"
    static let entriesKey = "blockers.v1"
    static let repsKey = "requiredReps.v1"
    static let bypassKey = "shortcutBypassMinutes.v1"
    static let activityPrefix = "round."

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

/// Eine Sperre: eine Auswahl an Apps/Kategorien mit eigenem Zeitbudget.
struct BlockerEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var minutes: Int
    var isEnabled: Bool
    var isLocked: Bool
    var roundSerial: Int
    var selectionData: Data

    init(id: UUID = UUID(),
         title: String,
         minutes: Int = 10,
         isEnabled: Bool = true,
         isLocked: Bool = false,
         roundSerial: Int = 0,
         selection: FamilyActivitySelection = FamilyActivitySelection()) {
        self.id = id
        self.title = title
        self.minutes = max(1, minutes)
        self.isEnabled = isEnabled
        self.isLocked = isLocked
        self.roundSerial = roundSerial
        self.selectionData = (try? JSONEncoder().encode(selection)) ?? Data()
    }

    var selection: FamilyActivitySelection {
        (try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData)) ?? FamilyActivitySelection()
    }

    var hasSelection: Bool {
        let value = selection
        return !value.applicationTokens.isEmpty
            || !value.categoryTokens.isEmpty
            || !value.webDomainTokens.isEmpty
    }

    /// Kurze Beschreibung der Auswahl, da iOS keine App-Namen herausgibt.
    var selectionSummary: String {
        let value = selection
        var parts: [String] = []
        if !value.applicationTokens.isEmpty {
            parts.append("\(value.applicationTokens.count) App\(value.applicationTokens.count == 1 ? "" : "s")")
        }
        if !value.categoryTokens.isEmpty {
            parts.append("\(value.categoryTokens.count) Kategorie\(value.categoryTokens.count == 1 ? "" : "n")")
        }
        if !value.webDomainTokens.isEmpty {
            parts.append("\(value.webDomainTokens.count) Website\(value.webDomainTokens.count == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "keine Auswahl" : parts.joined(separator: " · ")
    }
}

/// Persistenz über die App Group, damit auch die Erweiterungen Zugriff haben.
enum SharedStore {
    static func loadEntries() -> [BlockerEntry] {
        guard let data = SharedConfig.defaults.data(forKey: SharedConfig.entriesKey),
              let entries = try? JSONDecoder().decode([BlockerEntry].self, from: data) else {
            return []
        }
        return entries
    }

    static func save(_ entries: [BlockerEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        SharedConfig.defaults.set(data, forKey: SharedConfig.entriesKey)
    }

    static func update(id: UUID, _ body: (inout BlockerEntry) -> Void) {
        var entries = loadEntries()
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        body(&entries[index])
        save(entries)
    }

    static var requiredReps: Int {
        get {
            let stored = SharedConfig.defaults.integer(forKey: SharedConfig.repsKey)
            return stored == 0 ? 30 : stored
        }
        set { SharedConfig.defaults.set(max(1, newValue), forKey: SharedConfig.repsKey) }
    }

    /// Minuten, die eine übersprungene App freibleibt (Standard 10).
    static var bypassMinutes: Int {
        get {
            let stored = SharedConfig.defaults.integer(forKey: SharedConfig.bypassKey)
            return stored == 0 ? 10 : stored
        }
        set { SharedConfig.defaults.set(max(1, newValue), forKey: SharedConfig.bypassKey) }
    }
}

/// Setzt und entfernt die Bildschirmzeit-Sperren.
enum ShieldManager {
    static func store(for entryID: UUID) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name("blocker.\(entryID.uuidString)"))
    }

    static func applyShield(for entry: BlockerEntry) {
        let selection = entry.selection
        guard entry.hasSelection else { return }

        let store = store(for: entry.id)
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }
    }

    static func clearShield(for entryID: UUID) {
        store(for: entryID).clearAllSettings()
    }
}

/// Startet die eigentliche Zeitmessung: Device Activity zählt die echte Nutzung
/// der ausgewählten Apps und meldet die Erweiterung, sobald das Budget erreicht ist.
enum RoundScheduler {
    static func dailySchedule() -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
    }

    static func activities(for entryID: UUID) -> [DeviceActivityName] {
        let prefix = SharedConfig.activityPrefix + entryID.uuidString + "."
        return DeviceActivityCenter().activities.filter { $0.rawValue.hasPrefix(prefix) }
    }

    static func stopRounds(for entryID: UUID) {
        let names = activities(for: entryID)
        guard !names.isEmpty else { return }
        DeviceActivityCenter().stopMonitoring(names)
    }

    @discardableResult
    static func startRound(for entry: BlockerEntry, serial: Int) -> Bool {
        stopRounds(for: entry.id)
        guard entry.hasSelection else { return false }

        let selection = entry.selection
        let activityName = DeviceActivityName("\(SharedConfig.activityPrefix)\(entry.id.uuidString).\(serial)")
        let eventName = DeviceActivityEvent.Name("usage.\(entry.id.uuidString).\(serial)")
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: max(1, entry.minutes))
        )

        do {
            try DeviceActivityCenter().startMonitoring(
                activityName,
                during: dailySchedule(),
                events: [eventName: event]
            )
            return true
        } catch {
            return false
        }
    }
}
