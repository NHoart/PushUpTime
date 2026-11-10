import SwiftUI

/// Trägt eine Einheit von Hand ein – ohne Kamera und ohne Challenge.
struct TrackExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    @State private var exercise: ExerciseKind = .pushUps
    @State private var reps: Int = ExerciseKind.pushUps.defaultReps
    @State private var date: Date = Date()

    /// Feine Schritte bei Liegestützen, größere bei Russian Twists.
    private var step: Int { exercise == .pushUps ? 1 : 5 }

    private var quickAmounts: [Int] {
        exercise == .pushUps ? [10, 20, 30, 50] : [50, 100, 220, 300]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Übung", selection: $exercise) {
                        ForEach(ExerciseKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $reps, in: 1...2000, step: step) {
                        HStack {
                            Text("Wiederholungen")
                            Spacer()
                            Text("\(reps)")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .monospacedDigit()
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach(quickAmounts, id: \.self) { amount in
                            Button("\(amount)") { reps = amount }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 2)

                    DatePicker(
                        "Zeitpunkt",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } header: {
                    Text("Einheit")
                } footer: {
                    Text("\(reps) \(exercise.unit(for: reps)) landen in deinem Verlauf – wie eine abgeschlossene Challenge, nur ohne Kamera.")
                }
            }
            .navigationTitle("Übung eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Eintragen") {
                        model.trackExercise(exercise, reps: reps, date: date)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                exercise = model.exercise
                reps = max(1, model.reps(for: exercise))
            }
            // Übungswechsel übernimmt die eingestellte Anzahl der neuen Übung.
            .onChange(of: exercise) { _, kind in
                reps = max(1, SharedStore.reps(for: kind))
            }
        }
    }
}
