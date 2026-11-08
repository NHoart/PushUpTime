import Foundation

/// Eine abgeschlossene Challenge – Grundlage für die kleine Statistik.
struct ChallengeRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var reps: Int
    /// nil = Challenge ohne App-Namen (z. B. reiner Aufruf über den Shortcut).
    var appName: String?

    init(id: UUID = UUID(), date: Date = Date(), reps: Int, appName: String? = nil) {
        self.id = id
        self.date = date
        self.reps = reps
        self.appName = appName
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

    /// Legt eine abgeschlossene Challenge ab und gibt den neuen Verlauf zurück.
    @discardableResult
    static func record(reps: Int, appName: String?, date: Date = Date()) -> [ChallengeRecord] {
        var all = load()
        all.insert(ChallengeRecord(date: date, reps: reps, appName: appName), at: 0)
        if all.count > limit {
            all.removeLast(all.count - limit)
        }
        if let data = try? JSONEncoder().encode(all) {
            SharedConfig.defaults.set(data, forKey: key)
        }
        return all
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
