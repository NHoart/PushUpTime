import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Gestaltet den iOS-Sperrbildschirm für gesperrte Apps.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let reps = SharedStore.requiredReps
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.09, green: 0.07, blue: 0.08, alpha: 1.0),
            icon: UIImage(systemName: "figure.strengthtraining.traditional"),
            title: ShieldConfiguration.Label(
                text: "Zeit aufgebraucht",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Öffne PushUpTime und mach \(reps) Liegestütze, um weiterzumachen.",
                color: UIColor.white.withAlphaComponent(0.7)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Verstanden",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.9, green: 0.25, blue: 0.25, alpha: 1.0)
        )
    }
}
