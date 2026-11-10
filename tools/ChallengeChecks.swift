import Darwin
import Foundation

/// Ausführbare Prüfung der Challenge-Regeln und der Pausen-Sperre.
/// Wird von `tools/check-challenge-rules.sh` zusammen mit den echten
/// Produktionsdateien kompiliert und ausgeführt.
@main
struct ChallengeChecks {
    @MainActor
    static func main() {
        var failures = 0

        func check(_ condition: Bool, _ label: String) {
            if condition {
                print("PASS  \(label)")
            } else {
                failures += 1
                print("FAIL  \(label)")
            }
        }

        resetStore()

        // 1. Ziel startet beim Standard.
        check(SharedStore.reps(for: .pushUps) == 30, "Standard-Ziel Liegestütze ist 30")
        check(SharedStore.reps(for: .russianTwists) == 220, "Standard-Ziel Russian Twists ist 220")
        check(ChallengeRules.initialGoal(standardReps: 30) == 30, "Ziel startet bei 30")
        check(ChallengeRules.initialGoal(standardReps: 220) == 220, "Ziel startet bei 220")
        check(SharedStore.repsPerMinute(for: .pushUps) == 2, "Standardrate Liegestütze bleibt 2")
        check(SharedStore.repsPerMinute(for: .russianTwists) == 2, "Standardrate Russian Twists bleibt 2")

        // 2. Ziel verstellen und an den Rändern begrenzen.
        check(ChallengeRules.adjustedGoal(30, by: -10) == 20, "30 - 10 = 20")
        check(ChallengeRules.adjustedGoal(20, by: -10) == 10, "20 - 10 = 10")
        check(ChallengeRules.adjustedGoal(10, by: -10) == 1, "10 - 10 wird auf 1 begrenzt")
        check(ChallengeRules.adjustedGoal(1, by: -10) == 1, "unter 1 bleibt 1")
        check(ChallengeRules.adjustedGoal(490, by: 10) == 500, "490 + 10 = 500")
        check(ChallengeRules.adjustedGoal(500, by: 10) == 500, "über 500 bleibt 500")
        check(ChallengeRules.clampGoal(0) == 1, "0 wird auf 1 begrenzt")
        check(ChallengeRules.clampGoal(1) == 1, "1 bleibt 1")
        check(ChallengeRules.clampGoal(500) == 500, "500 bleibt 500")
        check(ChallengeRules.clampGoal(501) == 500, "501 wird auf 500 begrenzt")
        check(ChallengeRules.clampGoal(-100) == 1, "negative Werte werden auf 1 begrenzt")
        check(ChallengeRules.clampGoal(9999) == 500, "sehr große Werte werden auf 500 begrenzt")

        check(ChallengeRules.adjustedGoal(220, by: -10) == 210, "220 - 10 = 210")
        check(ChallengeRules.adjustedGoal(220, by: 10) == 230, "220 + 10 = 230")

        var twistGoal = 220
        for _ in 0..<28 {
            twistGoal = ChallengeRules.adjustedGoal(twistGoal, by: 10)
        }
        check(twistGoal == 500, "220 + 28x10 endet bei 500")
        check(ChallengeRules.adjustedGoal(twistGoal, by: 10) == 500, "500 + 10 bleibt 500")

        // 3. Zählung unabhängig vom Ziel.
        check(ChallengeRules.cameraTarget(isFree: false, isAppChallenge: true, goal: 30) == Int.max,
              "App-Challenge stoppt nicht am Ziel")
        check(ChallengeRules.cameraTarget(isFree: true, isAppChallenge: false, goal: 30) == Int.max,
              "freies Training zählt unbegrenzt")
        check(ChallengeRules.cameraTarget(isFree: false, isAppChallenge: false, goal: 30) == 30,
              "Testlauf stoppt am Ziel")
        check(ChallengeRules.countedReps(cameraCount: 12, goal: 30) == 12,
              "vorzeitig Fertig zählt 12 statt 30")
        check(ChallengeRules.countedReps(cameraCount: 45, goal: 30) == 45,
              "über dem Ziel zählt 45")
        check(ChallengeRules.countedReps(cameraCount: 30, goal: 30) == 30,
              "genau am Ziel zählt 30")
        check(ChallengeRules.countedReps(cameraCount: 0, goal: 30) == 30,
              "ohne Zählung gilt das Ziel")

        // 4. Pause mit der Standardrate 2.
        check(ChallengeRules.earnedMinutes(reps: 1, repsPerMinute: 2) == 1,
              "1 Wiederholung = mindestens 1 Minute")
        check(ChallengeRules.earnedMinutes(reps: 5, repsPerMinute: 2) == 2,
              "5 / 2 = 2 Minuten (abgeschnitten)")
        check(ChallengeRules.earnedMinutes(reps: 7, repsPerMinute: 2) == 3,
              "7 / 2 = 3 Minuten")
        check(ChallengeRules.earnedMinutes(reps: 30, repsPerMinute: 2) == 15,
              "30 / 2 = 15 Minuten")
        check(ChallengeRules.earnedMinutes(reps: 3, repsPerMinute: 3) == 1,
              "3 / 3 = 1 Minute")
        check(ChallengeRules.earnedMinutes(reps: 10, repsPerMinute: 50) == 1,
              "sehr hohe Rate = mindestens 1 Minute")
        check(ChallengeRules.earnedMinutes(reps: 500, repsPerMinute: 1) == 500,
              "500 / 1 = 500 Minuten")

        // 5. Rate verstellen, speichern und neu laden.
        let model = AppModel()
        model.setRepsPerMinute(4, for: .pushUps)
        check(model.repsPerMinute(for: .pushUps) == 4, "Rate im Modell verstellbar")
        check(SharedStore.repsPerMinute(for: .pushUps) == 4, "Rate wird gespeichert")
        check(AppModel().repsPerMinute(for: .pushUps) == 4, "Rate wird neu geladen")
        check(model.earnedMinutes(forReps: 12, exercise: .pushUps) == 3,
              "12 Wiederholungen bei Rate 4 = 3 Minuten")

        // 6. Abschluss über dem Ziel: 45 statt 30, Standardrate 2.
        resetStore()
        SharedStore.setRepsPerMinute(2, for: .pushUps)
        let appName = "Instagram"
        let completion = AppModel()
        completion.addShortcutRule(appName: appName)
        completion.challenge = AppModel.ChallengeRequest(kind: .shortcut(appName))
        _ = completion.completeChallenge(reps: 45)
        if let until = ShortcutBypass.until(for: appName) {
            let expected = Date().addingTimeInterval(22 * 60)
            check(abs(until.timeIntervalSince(expected)) < 5,
                  "45 Wiederholungen bei Rate 2 = 22 Minuten Pause")
        } else {
            check(false, "Pause nach Abschluss wurde gesetzt")
        }
        check(ShortcutBypass.isActive(for: appName), "Pause ist nach Abschluss aktiv")

        // 7. Während der Pause keine neue Challenge, danach wieder normal.
        LaunchPass.clear(for: appName)
        let gated = AppModel()
        gated.addShortcutRule(appName: appName)
        gated.handleIncomingURL(URL(string: "pushuptime://challenge?app=Instagram")!)
        check(gated.challenge == nil, "während der Pause startet keine neue Challenge")

        SharedConfig.defaults.set(
            Date().addingTimeInterval(-1).timeIntervalSince1970,
            forKey: "shortcutBypassUntil.instagram"
        )
        check(!ShortcutBypass.isActive(for: appName), "Pause ist abgelaufen")
        gated.challenge = nil
        gated.handleIncomingURL(URL(string: "pushuptime://challenge?app=Instagram")!)
        check(gated.challenge != nil, "nach der Pause startet wieder eine Challenge")

        // 8. Geänderte Rate ändert die tatsächlich vergebene Pause.
        resetStore()
        SharedStore.setRepsPerMinute(3, for: .pushUps)
        let rated = AppModel()
        rated.addShortcutRule(appName: appName)
        rated.challenge = AppModel.ChallengeRequest(kind: .shortcut(appName))
        _ = rated.completeChallenge(reps: 30)
        if let until = ShortcutBypass.until(for: appName) {
            let expected = Date().addingTimeInterval(10 * 60)
            check(abs(until.timeIntervalSince(expected)) < 5,
                  "Rate 3: 30 Wiederholungen = 10 Minuten Pause")
        } else {
            check(false, "Pause mit geänderter Rate wurde gesetzt")
        }

        // 9. Unter dem Ziel: 12 statt 30.
        resetStore()
        SharedStore.setRepsPerMinute(2, for: .pushUps)
        let early = AppModel()
        early.addShortcutRule(appName: appName)
        early.challenge = AppModel.ChallengeRequest(kind: .shortcut(appName))
        _ = early.completeChallenge(reps: 12)
        if let until = ShortcutBypass.until(for: appName) {
            let expected = Date().addingTimeInterval(6 * 60)
            check(abs(until.timeIntervalSince(expected)) < 5,
                  "12 Wiederholungen bei Rate 2 = 6 Minuten Pause")
        } else {
            check(false, "Pause bei vorzeitigem Fertig wurde gesetzt")
        }

        print("")
        if failures == 0 {
            print("ALLE PRÜFUNGEN BESTANDEN")
        } else {
            print("\(failures) PRÜFUNG(EN) FEHLGESCHLAGEN")
        }
        exit(failures == 0 ? 0 : 1)
    }

    /// Setzt die von der App genutzten Werte zurück, damit der Lauf wiederholbar ist.
    static func resetStore() {
        let defaults = UserDefaults.standard
        let prefixes = ["launchPass.", "shortcutBypassUntil."]
        for key in defaults.dictionaryRepresentation().keys
        where prefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
        for key in [
            "requiredReps.v1",
            "requiredTwistReps.v1",
            "exerciseKind.v1",
            "shortcutBypassMinutes.v1",
            "repsPerMinute.v1",
            "repsPerMinute.pushUps.v1",
            "repsPerMinute.russianTwists.v1",
            "challengeLog.v1",
            "shortcutRules.v1"
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
