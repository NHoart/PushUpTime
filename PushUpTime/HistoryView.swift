import Charts
import SwiftUI

/// Trainingsverlauf: ein Diagramm über die letzten 30 Tage, die wichtigsten
/// Zahlen dazu und alle Einheiten zum Durchsehen und Löschen.
struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    /// Liegestütze und Russian Twists haben sehr unterschiedliche
    /// Wiederholungszahlen – in einer Summe wäre das Diagramm irreführend.
    @State private var chartExercise: ExerciseKind = .pushUps

    private static let dayCount = 30

    private struct DayReps {
        let date: Date
        let reps: Int
    }

    var body: some View {
        NavigationStack {
            List {
                chartSection
                summarySection
                entriesSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Verlauf")
        }
    }

    // MARK: - Diagramm

    private var chartSection: some View {
        Section {
            Picker("Übung", selection: $chartExercise) {
                ForEach(ExerciseKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if monthlyTotal == 0 {
                Text("In den letzten 30 Tagen noch nichts gezählt.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 28)
            } else {
                Chart(dailyReps, id: \.date) { day in
                    BarMark(
                        x: .value("Tag", day.date, unit: .day),
                        y: .value("Wiederholungen", day.reps)
                    )
                    .foregroundStyle(chartExercise == .pushUps ? Color.orange : Color.teal)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 190)
                .padding(.vertical, 8)
                .accessibilityLabel("Wiederholungen pro Tag der letzten 30 Tage")
            }
        } header: {
            Text("Letzte 30 Tage")
        } footer: {
            Text("Jeder Balken ist ein Tag, gezählt werden die Wiederholungen dieser Übung.")
        }
    }

    // MARK: - Zusammenfassung

    private var summarySection: some View {
        Section {
            HStack {
                Label("In 30 Tagen", systemImage: "calendar.badge.clock")
                Spacer()
                Text("\(monthlyTotal) \(chartExercise.unit(for: monthlyTotal))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Aktive Tage", systemImage: "calendar")
                Spacer()
                Text("\(activeDays)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if let best = bestDay, best.reps > 0 {
                HStack {
                    Label("Bester Tag", systemImage: "trophy")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(best.reps) \(chartExercise.unit(for: best.reps))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(best.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Zusammenfassung")
        } footer: {
            Text("Bezieht sich immer auf die oben gewählte Übung.")
        }
    }

    // MARK: - Einheiten

    private var entriesSection: some View {
        Section {
            if model.history.isEmpty {
                Text("Noch keine Einheit eingetragen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.history) { record in
                    HStack(spacing: 12) {
                        Image(systemName: record.exerciseKind.icon)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.amountLabel)
                                .monospacedDigit()
                            Text(record.appName ?? record.shortLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            model.deleteRecord(record)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Alle Einheiten")
        } footer: {
            Text("Zum Löschen nach links wischen.")
        }
    }

    // MARK: - Daten

    /// Die letzten 30 Tage inklusive heute, ältester Tag zuerst.
    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<Self.dayCount).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private var dailyReps: [DayReps] {
        let calendar = Calendar.current
        var totals: [Date: Int] = [:]
        for record in model.history where record.exerciseKind == chartExercise {
            totals[calendar.startOfDay(for: record.date), default: 0] += record.reps
        }
        return days.map { DayReps(date: $0, reps: totals[$0] ?? 0) }
    }

    private var monthlyTotal: Int {
        dailyReps.reduce(0) { $0 + $1.reps }
    }

    private var activeDays: Int {
        dailyReps.filter { $0.reps > 0 }.count
    }

    private var bestDay: DayReps? {
        dailyReps.max { $0.reps < $1.reps }
    }
}
