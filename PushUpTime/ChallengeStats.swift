import Foundation

/// Eine abgeschlossene Challenge – Grundlage für die kleine Statistik.
struct ChallengeRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var reps: Int
    /// nil = Challenge ohne App-Namen (z. B. reiner Aufruf über den Shortcut).
    var appName: String?
    /// nil bei alten Einträgen – die entstanden vor den Russian Twists.
    var exercise: ExerciseKind?

    init(id: UUID = UUID(),
         date: Date = Date(),
         reps: Int,
         appName: String? = nil,
         exercise: ExerciseKind? = nil) {
        self.id = id
        self.date = date
        self.reps = reps
        self.appName = appName
        self.exercise = exercise
    }

    var exerciseKind: ExerciseKind { exercise ?? .pushUps }

    /// „30 Liegestütze“ / „220 Russian Twists“.
    var amountLabel: String {
        "\(reps) \(exerciseKind.unit(for: reps))"
    }

    /// „Heute, 12:04“ / „Gestern, 12:04“ / „03.11.2026, 12:04“ in Systemsprache.
    var shortLabel: String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) { return "Heute, \(time)" }
        if Calendar.current.isDateInYesterday(date) { return "Gestern, \(time)" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

struct ChallengeStats: Equatable {
    var todayCount: Int = 0
    /// Aufeinanderfolgende Tage mit mindestens einer abgeschlossenen Challenge.
    var streak: Int = 0
    var last: ChallengeRecord?
}

enum ChallengeLog {
    private static let key = "challengeLog.v1"
    /// Reicht für Wochen Statistik, ohne den App-Group-Speicher vollzumüllen.
    private static let limit = 300

    static func load() -> [ChallengeRecord] {
        guard let data = SharedConfig.defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([ChallengeRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.date > $1.date }
    }

    /// Legt eine abgeschlossene Einheit ab und gibt den neuen Verlauf zurück.
    @discardableResult
    static func record(reps: Int,
                       appName: String?,
                       exercise: ExerciseKind,
                       date: Date = Date()) -> [ChallengeRecord] {
        var all = load()
        all.append(
            ChallengeRecord(date: date, reps: reps, appName: appName, exercise: exercise)
        )
        all.sort { $0.date > $1.date }
        if all.count > limit {
            all.removeLast(all.count - limit)
        }
        save(all)
        return all
    }

    /// Entfernt einen Eintrag, z. B. ein versehentlich eingetragenes Training.
    @discardableResult
    static func delete(id: UUID) -> [ChallengeRecord] {
        var all = load()
        all.removeAll { $0.id == id }
        save(all)
        return all
    }

    private static func save(_ records: [ChallengeRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            SharedConfig.defaults.set(data, forKey: key)
        }
    }

    static func summary(
        of records: [ChallengeRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ChallengeStats {
        var stats = ChallengeStats()
        stats.todayCount = records.filter { calendar.isDate($0.date, inSameDayAs: now) }.count
        stats.last = records.max { $0.date < $1.date }

        let days = Set(records.map { calendar.startOfDay(for: $0.date) })
        let today = calendar.startOfDay(for: now)

        // Ohne Einheit heute bleibt der Streak bestehen, solange er gestern endete.
        var cursor = days.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)

        while let day = cursor, days.contains(day) {
            stats.streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: day)
        }
        return stats
    }
}
