import DeviceActivity
import Foundation

/// Wird von iOS aufgerufen, sobald die ausgewählten Apps das Zeitbudget
/// aufgebraucht haben – auch wenn PushUpTime nicht im Vordergrund ist.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard let entryID = Self.entryID(from: activity),
              let entry = SharedStore.loadEntries().first(where: { $0.id == entryID }) else {
            return
        }

        ShieldManager.applyShield(for: entry)
        SharedStore.update(id: entryID) { $0.isLocked = true }
        DeviceActivityCenter().stopMonitoring([activity])
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let entryID = Self.entryID(from: activity) else { return }
        ShieldManager.clearShield(for: entryID)
    }

    /// Aktivitätsname: "round.<entry-uuid>.<serial>"
    private static func entryID(from activity: DeviceActivityName) -> UUID? {
        let parts = activity.rawValue.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        return UUID(uuidString: String(parts[1]))
    }
}
