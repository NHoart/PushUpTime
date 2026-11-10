import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Übung", selection: Binding(
                        get: { model.exercise },
                        set: { model.exercise = $0 }
                    )) {
                        ForEach(ExerciseKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(
                        value: Binding(
                            get: { model.requiredReps },
                            set: { model.setReps($0) }
                        ),
                        in: 1...500
                    ) {
                        HStack {
                            Text("\(model.exercise.title) pro Challenge")
                            Spacer()
                            Text("\(model.requiredReps)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Challenge")
                } footer: {
                    Text("Die gewählte Übung ist der Standard für Shortcut-Aufrufe. Wenn dich eine App wie Instagram hierher schickt, kannst du die Übung vor der Zählung trotzdem noch wechseln. Standard: 30 Liegestütze oder 220 Russian Twists.")
                }

                Section {
                    ForEach(ExerciseKind.allCases) { kind in
                        VStack(alignment: .leading, spacing: 4) {
                            Stepper(
                                value: Binding(
                                    get: { model.repsPerMinute(for: kind) },
                                    set: { model.setRepsPerMinute($0, for: kind) }
                                ),
                                in: 1...50
                            ) {
                                HStack {
                                    Label(kind.title, systemImage: kind.icon)
                                    Spacer()
                                    Text("\(model.repsPerMinute(for: kind))")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(rateHint(for: kind))
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Pause nach der Challenge")
                } footer: {
                    Text("Pro Übung getrennt: so viele Wiederholungen bringen eine Minute ohne neue Challenge. Standard sind 2 Wiederholungen pro Minute – 30 Liegestütze also 15 Minuten.")
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
                    Text("Unabhängig von der Pause nach einer Challenge: So lange löst dieselbe App nach dem Überspringen keine neue Challenge aus. Bei 0 Minuten ist die App sofort wieder dran.")
                }

                Section {
                    Text("Standardweg: Du legst im Startbildschirm eine App an und richtest in der Shortcuts-App die Automatisierung „App ist geöffnet“ ein. iOS erlaubt nur Shortcuts, das Öffnen anderer Apps zu bemerken.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("PushUpTime selbst sperrt keine Apps – die App erinnert dich beim Öffnen und zählt die Wiederholungen per Kamera.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Mit einem kostenlosen Apple-Team läuft die App nach 7 Tagen ab und muss über Xcode neu installiert werden.")
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

    /// „30 Liegestütze = 15 Min“ – zeigt, was die aktuelle Rate einbringt.
    private func rateHint(for kind: ExerciseKind) -> String {
        let reps = max(1, model.reps(for: kind))
        let minutes = model.earnedMinutes(forReps: reps, exercise: kind)
        return "\(reps) \(kind.unit(for: reps)) = \(minutes) Min"
    }
}
