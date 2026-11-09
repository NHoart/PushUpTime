import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        value: Binding(
                            get: { model.requiredReps },
                            set: { model.requiredReps = $0 }
                        ),
                        in: 1...200
                    ) {
                        HStack {
                            Text("Liegestütze pro Freigabe")
                            Spacer()
                            Text("\(model.requiredReps)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Challenge")
                }

                Section {
                    Stepper(
                        value: Binding(
                            get: { model.bypassMinutes },
                            set: { model.bypassMinutes = $0 }
                        ),
                        in: 0...180
                    ) {
                        HStack {
                            Text("Freigabe nach „Überspringen“")
                            Spacer()
                            Text(model.bypassMinutes == 0 ? "keine" : "\(model.bypassMinutes) Min")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Überspringen")
                } footer: {
                    Text("So lange löst dieselbe App nach dem Überspringen keine neue Challenge aus. Bei 0 Minuten ist die App sofort wieder gesperrt.")
                }

                Section {
                    HStack {
                        Text("Bildschirmzeit")
                        Spacer()
                        Text(authText)
                            .foregroundStyle(model.auth.isApproved ? .green : .orange)
                    }

                    if !model.auth.isApproved {
                        Button("Bildschirmzeit freigeben") {
                            Task { await model.requestAuthorization() }
                        }
                    }

                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Button("iOS-Einstellungen öffnen") {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Berechtigungen")
                }

                Section {
                    Text("Standardweg: Du legst im Startbildschirm eine App an und richtest in der Shortcuts-App die Automatisierung „App ist geöffnet“ ein. iOS erlaubt nur Shortcuts, das Öffnen anderer Apps zu bemerken.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Die Sperren im Startbildschirm basieren auf Apples Screen-Time-API (Family Controls, Managed Settings, Device Activity). Persönliche kostenlose Apple-Teams unterstützen Family Controls nicht – echtes Blockieren braucht eine kostenpflichtige Apple-Developer-Mitgliedschaft und die Freigabe der Berechtigung durch Apple (developer.apple.com/contact/request/family-controls-distribution).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Notaus: Du kannst die Sperre jederzeit über iOS-Einstellungen → Bildschirmzeit aufheben oder PushUpTime den Bildschirmzeit-Zugriff entziehen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Hinweise")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var authText: String {
        switch model.auth {
        case .approved: return "freigegeben"
        case .denied: return "abgelehnt"
        case .notDetermined: return "nicht freigegeben"
        case .failed: return "Fehler"
        case .unknown: return "unbekannt"
        }
    }
}
