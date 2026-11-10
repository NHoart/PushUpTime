import Foundation

/// Reine Rechenregeln für Ziel, Zählung und Pause – ohne UI und ohne Speicher.
enum ChallengeRules {
    /// Erlaubter Zielbereich einer Challenge.
    static let goalRange = 1...500

    /// Ziel beim Start einer Challenge: der gespeicherte Standard, begrenzt.
    static func initialGoal(standardReps: Int) -> Int {
        clampGoal(standardReps)
    }

    static func clampGoal(_ value: Int) -> Int {
        min(goalRange.upperBound, max(goalRange.lowerBound, value))
    }

    /// Verstellt das Ziel und hält es im erlaubten Bereich.
    static func adjustedGoal(_ goal: Int, by delta: Int) -> Int {
        clampGoal(goal + delta)
    }

    /// Am Ende zählt, was die Kamera gezählt hat; ohne Zählung das Ziel.
    static func countedReps(cameraCount: Int, goal: Int) -> Int {
        max(1, cameraCount > 0 ? cameraCount : goal)
    }

    /// Pause in Minuten – ganze Minuten, mindestens eine.
    static func earnedMinutes(reps: Int, repsPerMinute: Int) -> Int {
        max(1, max(1, reps) / max(1, repsPerMinute))
    }

    /// Die Kamera stoppt bei App-Challenges nicht am Ziel.
    static func cameraTarget(isFree: Bool, isAppChallenge: Bool, goal: Int) -> Int {
        (isFree || isAppChallenge) ? .max : goal
    }
}
