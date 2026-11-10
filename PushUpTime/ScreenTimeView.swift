import FamilyControls
import SwiftUI
import UIKit

/// Optionaler Zweig: echtes Blockieren über Apples Screen-Time-API.
/// Funktioniert nur mit der von Apple genehmigten Family-Controls-Berechtigung.
struct ScreenTimeView: View {
    @EnvironmentObject private var model: AppModel

    @State private var showAddBlocker = false

    var body: some View {
        List {
            authorizationSection
            blockersSection
            infoSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Bildschirmzeit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddBlocker = true } label: {
                    Image(systemName: "plus")
                }
                .disabled(!model.auth.isApproved)
                .accessibilityLabel("Sperre hinzufügen")
            }
        }
        .sheet(isPresented: $showAddBlocker) {
            AddBlockerView { title, minutes, selection in
                model.addBlocker(title: title, minutes: minutes, selection: selection)
            }
        }
    }

    @ViewBuilder
    private var authorizationSection: some View {
        switch model.auth {
        case .approved:
            Section {
                Label("Bildschirmzeit freigegeben", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        case .notDetermined:
            Section {
                Text("PushUpTime braucht Zugriff auf die Bildschirmzeit, um andere Apps sperren zu können.")
                    .font(.callout)
                Button("Bildschirmzeit freigeben") {
                    Task { await model.requestAuthorization() }
                }
            }
        case .denied:
            Section {
                Text("Der Bildschirmzeit-Zugriff wurde abgelehnt. Bitte in den Systemeinstellungen unter „Bildschirmzeit“ erlauben.")
                    .font(.callout)
                Button("Systemeinstellungen öffnen") {
                    openSystemSettings()
                }
                Button("Erneut versuchen") {
                    Task { await model.requestAuthorization() }
                }
            }
        case .failed(let message):
            Section {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.orange)
                Button("Erneut versuchen") {
                    Task { await model.requestAuthorization() }
                }
            }
        case .unknown:
            Section {
                Button("Bildschirmzeit verbinden") {
                    Task { await model.requestAuthorization() }
                }
            }
        }
    }

    private var blockersSection: some View {
        Section {
            if model.entries.isEmpty {
                Text("Noch keine Sperre angelegt. Tippe oben auf „+“, wähle Apps aus und lege fest, wie lange du sie pro Runde nutzen darfst.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.entries) { entry in
                    blockerRow(entry)
                }
            }
        } header: {
            Text("Sperren")
        } footer: {
            Text("Das Zeitbudget zählt die tatsächliche Nutzung der ausgewählten Apps. Ist es aufgebraucht, erscheint der Sperrbildschirm, bis du die Challenge gemacht hast. Die Minuten der nächsten Runde verdienst du mit Wiederholungen – wie viele eine Minute bringen, steht in den Einstellungen unter „Bildschirmzeit-Belohnung“.")
        }
    }

    private func blockerRow(_ entry: BlockerEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: entry.isLocked ? "lock.fill" : "lock.open")
                    .foregroundStyle(entry.isLocked ? .red : .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.headline)
                    Text("\(entry.minutes) Min · \(entry.selectionSummary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if entry.isLocked {
                    Button("Freimachen") {
                        model.beginChallenge(for: entry)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("Sperren") {
                        model.lockNow(entry)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 12) {
                Stepper(
                    value: Binding(
                        get: { entry.minutes },
                        set: { model.setMinutes($0, for: entry) }
                    ),
                    in: 1...240
                ) {
                    Text("\(entry.minutes) Minuten pro Runde")
                        .font(.caption)
                }

                Spacer()

                Button {
                    model.beginChallenge(for: entry)
                } label: {
                    Image(systemName: "figure.strengthtraining.traditional")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Challenge machen")
            }
        }
        .padding(.vertical, 4)
    }

    private var infoSection: some View {
        Section {
            Text("Die Sperre basiert auf Apples Screen-Time-API (Family Controls, Managed Settings, Device Activity). Ohne die von Apple genehmigte Family-Controls-Berechtigung kann die App keine anderen Apps sperren.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Wichtig: Kostenlose persönliche Apple-Teams unterstützen Family Controls nicht. Deshalb ist der Benachrichtigungs-Modus über Shortcuts der Standardweg.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Notaus: Eine aktive Sperre lässt sich jederzeit in iOS-Einstellungen → Bildschirmzeit aufheben.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Gut zu wissen")
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
