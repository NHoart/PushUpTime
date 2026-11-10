import AVFoundation
import SwiftUI
import UIKit

struct ChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @StateObject private var camera = PushUpCamera()

    /// Die Challenge ist erledigt – die Bestätigung läuft, danach der Rücksprung.
    @State private var finished = false

    /// Noch nichts gewählt = Übungsauswahl wird angezeigt.
    @State private var chosenExercise: ExerciseKind?

    /// Bei einer Sperre: Ziel für genau diese Challenge – freiwillig und frei wählbar.
    @State private var goal: Int?

    /// Übung, für die gerade das Ziel eingestellt wird.
    @State private var configuringGoal: ExerciseKind?

    /// Test, Shortcuts-Aufruf oder echte Bildschirmzeit-Sperre.
    let request: AppModel.ChallengeRequest

    private var exercise: ExerciseKind { chosenExercise ?? model.exercise }
    /// Ziel der Challenge: bei Sperren das selbst gesetzte, sonst der Standard.
    private var reps: Int { max(1, goal ?? model.reps(for: exercise)) }
    private var remaining: Int { max(0, reps - camera.count) }

    /// Freies Training: keine Sperre, kein Ziel – eingetragen wird, was gezählt wurde.
    private var isFree: Bool {
        if case .free = request.kind { return true }
        return false
    }

    /// Von einer App ausgelöst (Bildschirmzeit-Sperre oder Shortcuts-Aufruf):
    /// Ziel vorab festlegen, frei zählen und selbst über „Fertig“ beenden.
    private var isAppChallenge: Bool {
        switch request.kind {
        case .screenTime, .shortcut: return true
        case .test, .free: return false
        }
    }

    private var statusLabel: String {
        switch request.kind {
        case .test: return "TESTLAUF"
        case .free: return "FREIES TRAINING"
        case .shortcut: return exercise.statusLabel
        case .screenTime: return "GESPERRT"
        }
    }

    /// Bildschirmzeit, die der aktuelle Stand einbringt (nur bei echter Sperre).
    private var rewardMinutes: Int? {
        guard request.isBlocking else { return nil }
        return model.earnedMinutes(forReps: camera.count > 0 ? camera.count : reps)
    }

    /// Verdiente Minuten am Ende – gezählt, sonst das Ziel.
    private var grantedMinutes: Int {
        model.earnedMinutes(forReps: max(1, camera.count > 0 ? camera.count : reps))
    }

    /// Beschriftung des grünen Abschluss-Buttons (freies Training und Sperre).
    private var finishLabel: String {
        guard camera.count > 0 else { return "Fertig" }
        if request.isBlocking {
            return "Fertig · \(model.earnedMinutes(forReps: camera.count)) Min"
        }
        return "Fertig · \(camera.count) \(exercise.unit(for: camera.count))"
    }

    /// Beschriftung unter dem Zähler.
    private var counterCaption: String {
        if isFree { return "Wiederholungen" }
        if isAppChallenge { return "Ziel \(reps)" }
        return "von \(reps)"
    }

    /// Nur wenn ein Rücksprung-Link hinterlegt ist, wird auch gesprungen.
    private var returnAppName: String? {
        guard case .shortcut(.some(let name)) = request.kind,
              model.returnURL(forAppNamed: name) != nil else { return nil }
        return name
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(camera: camera)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.8), .black.opacity(0.3), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Text(statusLabel)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.6))

                    if let title = request.title {
                        Text(title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                counter

                Text(hintText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(hintColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(diagnostic)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if camera.status == .denied || camera.status == .noCamera {
                    cameraProblem
                }

                Spacer()

                footer
            }
            .padding(.vertical, 24)

            // Erst die Übung wählen, dann zählt die Kamera.
            if chosenExercise == nil {
                exerciseChooser
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
            }

            // Bei App-Challenges davor noch das Ziel für diese Challenge festlegen.
            if let kind = configuringGoal {
                goalChooser(for: kind)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
            }

            if finished {
                completionOverlay
            }
        }
        .preferredColorScheme(.dark)
        .keepScreenAwake()
        .onAppear {
            // Freies Training und App-Challenges haben kein festes Ende – dort
            // beendet der „Fertig“-Button die Zählung.
            if !isFree && !isAppChallenge {
                camera.onCompleted = {
                    finish()
                }
            }
            if chosenExercise != nil {
                startCamera()
            }
        }
        .onChange(of: chosenExercise) { _, value in
            guard value != nil else { return }
            startCamera()
        }
        .onDisappear {
            camera.stop()
        }
    }

    // MARK: - Views

    /// Auswahl direkt beim Weiterleiten aus einer App: Liegestütze oder Russian Twists.
    private var exerciseChooser: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                Text(isFree ? "FREIES TRAINING" : "DEINE CHALLENGE")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.6))

                if let title = request.title {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            Text("Was machst du?")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 14) {
                ForEach(ExerciseKind.allCases) { kind in
                    Button {
                        choose(kind)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: kind.icon)
                                .font(.system(size: 26, weight: .semibold))
                                .frame(width: 34)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title)
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                Text(amountLabel(for: kind))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.white.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            if isFree {
                Button {
                    model.challenge = nil
                    dismiss()
                } label: {
                    Text("Abbrechen")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(.white.opacity(0.14)))
                }
            } else if !request.isBlocking {
                Button {
                    leave(ticket: model.skipChallenge())
                } label: {
                    Text("Überspringen")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(.white.opacity(0.14)))
                }
                .accessibilityHint("Beendet die Challenge, ohne Wiederholungen zu zählen.")
            } else {
                Text("Notaus: 3 Sekunden halten")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onLongPressGesture(minimumDuration: 3) {
                        model.emergencyUnlockCurrent()
                        dismiss()
                    }
            }
        }
        .padding(.vertical, 24)
    }

    /// Ziel für eine Sperre: freiwillig – weniger geht, mehr zählt auch.
    private func goalChooser(for kind: ExerciseKind) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                Text("DEIN ZIEL")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.6))

                if let title = request.title {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(reps)")
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: reps)
                Text(kind.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 10) {
                ForEach([-10, -5, 5, 10], id: \.self) { delta in
                    Button {
                        setGoal(reps + delta)
                    } label: {
                        Text(delta > 0 ? "+\(delta)" : "\(delta)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 62)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 6) {
                if request.isBlocking {
                    Text("\(model.earnedMinutes(forReps: reps)) Min Bildschirmzeit")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.9, blue: 0.55))
                }
                Text("Das Ziel ist nur eine Marke. Du kannst früher auf „Fertig“ drücken – oder weitermachen.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                chosenExercise = kind
                configuringGoal = nil
            } label: {
                Text("Los")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(red: 0.45, green: 0.9, blue: 0.55)))
            }

            Button {
                configuringGoal = nil
                goal = nil
            } label: {
                Text("Zurück")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.vertical, 24)
    }

    private var completionOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(red: 0.45, green: 0.9, blue: 0.55))

            Text("Geschafft")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            if let name = returnAppName {
                Text("Zurück zu \(name) …")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text(request.isBlocking
                     ? "\(grantedMinutes) Min Bildschirmzeit freigegeben"
                     : "Challenge beendet")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.75))
        .ignoresSafeArea()
    }

    private var counter: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 12)
            if !isFree {
                Circle()
                    .trim(from: 0, to: min(1, Double(camera.count) / Double(reps)))
                    .stroke(
                        Color(red: 0.95, green: 0.3, blue: 0.3),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.25), value: camera.count)
            }

            VStack(spacing: 0) {
                Text("\(camera.count)")
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: camera.count)
                Text(counterCaption)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                if let reward = rewardMinutes {
                    Text("+ \(reward) Min Bildschirmzeit")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(width: 250, height: 250)
    }

    private var cameraProblem: some View {
        VStack(spacing: 10) {
            Text(camera.status == .denied
                 ? "Kamera-Zugriff nötig, um die Wiederholungen zu zählen."
                 : "Keine Kamera gefunden.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))

            if camera.status == .denied {
                Button("Kamera erlauben") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 32)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if isFree {
                Button("Abbrechen") {
                    model.challenge = nil
                    dismiss()
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            }

            // Ausweg aus der Meldung: schließt die Zählung ohne Wiederholungen.
            if !request.isBlocking && !isFree {
                Button {
                    leave(ticket: model.skipChallenge())
                } label: {
                    Text("Überspringen")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(.white.opacity(0.14)))
                }
                .accessibilityHint("Beendet die Challenge, ohne Wiederholungen zu zählen.")
            }

            // Freies Training und App-Challenge: so viele Wiederholungen wie
            // geschafft, dann selbst über „Fertig“ beenden.
            if isFree || isAppChallenge {
                Button {
                    finish(countedReps: camera.count)
                } label: {
                    Text(finishLabel)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color(red: 0.45, green: 0.9, blue: 0.55)))
                }
                .disabled(camera.count == 0)
                .opacity(camera.count == 0 ? 0.5 : 1)
                .accessibilityHint(request.isBlocking
                                   ? "Beendet die Challenge und rechnet die gezählten Wiederholungen ab."
                                   : "Beendet die Zählung und trägt die Wiederholungen im Verlauf ein.")
            }

            HStack(spacing: 8) {
                Image(systemName: "iphone.gen3")
                Text(exercise.setupHint)
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            if request.isBlocking {
                Text("Notaus: 3 Sekunden halten")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onLongPressGesture(minimumDuration: 3) {
                        model.emergencyUnlockCurrent()
                        dismiss()
                    }
            }
        }
    }

    private var hintText: String {
        if isAppChallenge && camera.count >= reps {
            return "Ziel erreicht 🎉 Fertig drücken oder weiterzählen"
        }
        return hint
    }

    private var hint: String {
        switch camera.status {
        case .denied:
            return "Kamera-Zugriff verweigert"
        case .noCamera:
            return "Keine Kamera verfügbar"
        case .idle, .requesting, .running:
            switch exercise {
            case .pushUps:
                switch camera.phase {
                case .down: return "Tiefer! 💥"
                case .up: return "Hoch – zählt! ✅"
                case .searching, .center, .left, .right: return "Geh in Position …"
                }
            case .russianTwists:
                switch camera.phase {
                case .left, .right: return "Gezählt! ✅ Jetzt zur anderen Seite"
                case .center: return "Weiter drehen …"
                case .searching, .down, .up: return "Setz dich hin, Hände vor der Brust …"
                }
            }
        }
    }

    /// Kurze Rückmeldung, ob Kamera und Pose überhaupt ankommen.
    private var diagnostic: String {
        switch camera.status {
        case .idle, .requesting:
            return "Kamera startet …"
        case .denied:
            return "Kamera: kein Zugriff"
        case .noCamera:
            return "Kamera: nicht gefunden"
        case .running:
            switch exercise {
            case .pushUps:
                if let angle = camera.poseMetric {
                    return "Pose erkannt · Ellbogen \(Int(angle.rounded()))°"
                }
                return "Kamera läuft · keine Pose im Bild"
            case .russianTwists:
                if let amplitude = camera.poseMetric {
                    return "Hände erkannt · Ausschlag \(Int((abs(amplitude) * 100).rounded()))"
                }
                return "Kamera läuft · Hände oder Becken nicht im Bild"
            }
        }
    }

    private var hintColor: Color {
        switch camera.phase {
        case .down:
            return Color(red: 1.0, green: 0.6, blue: 0.25)
        case .up, .left, .right:
            return Color(red: 0.45, green: 0.9, blue: 0.55)
        case .searching, .center:
            return .white.opacity(0.6)
        }
    }

    private func amountLabel(for kind: ExerciseKind) -> String {
        if isFree { return "Frei zählen, ohne Ziel" }
        let count = max(1, model.reps(for: kind))
        let amount = "\(count) \(kind.unit(for: count))"
        guard isAppChallenge else { return amount }
        if request.isBlocking {
            return "Ziel frei wählbar · \(model.earnedMinutes(forReps: count, exercise: kind)) Min"
        }
        return "Ziel frei wählbar"
    }

    /// Übung übernehmen (auch als neuen Standard) und die Zählung starten.
    /// Bei einer Sperre wird davor noch das Ziel für diese Challenge gesetzt.
    private func choose(_ kind: ExerciseKind) {
        model.exercise = kind
        if isAppChallenge {
            goal = max(1, model.reps(for: kind))
            configuringGoal = kind
        } else {
            chosenExercise = kind
        }
    }

    /// Ziel für diese eine Challenge (1...500) – unabhängig vom Standard.
    private func setGoal(_ value: Int) {
        goal = min(500, max(1, value))
    }

    private func startCamera() {
        camera.mode = exercise == .russianTwists ? .russianTwists : .pushUps
        // Sperren und freies Training zählen unbegrenzt weiter – das Ende
        // bestimmt der „Fertig“-Button.
        camera.target = (isFree || isAppChallenge) ? .max : reps
        camera.start()
    }

    /// Zählung beendet: kurz bestätigen und dann zurück in die App.
    /// - Parameter countedReps: Bei einer Sperre die tatsächlich geschafften
    ///   Wiederholungen; ohne Angabe das Ziel.
    private func finish(countedReps: Int? = nil) {
        guard !finished else { return }
        finished = true
        camera.stop()

        let counted = countedReps ?? (camera.count > 0 ? camera.count : nil)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            leave(ticket: model.completeChallenge(reps: counted))
        }
    }

    /// Räumt die Challenge weg und springt – wenn möglich – in die Ziel-App.
    private func leave(ticket: ReturnTicket?) {
        dismiss()
        guard let ticket else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            UIApplication.shared.open(ticket.url, options: [:]) { success in
                guard !success else { return }
                Task { @MainActor in
                    model.errorMessage = "„\(ticket.appName)“ ließ sich nicht öffnen. Prüfe den Rücksprung-Link in der Anleitung."
                }
            }
        }
    }
}

/// Hält die automatische Bildschirmsperre an, solange die Challenge offen ist.
/// Wer in Position liegt, kann nicht alle 30 Sekunden das iPhone entsperren.
private struct KeepScreenAwake: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { setScreenAwake(true) }
            .onDisappear { setScreenAwake(false) }
            .onChange(of: scenePhase) { _, phase in
                // Im Hintergrund hält iOS die Sperre ohnehin an; beim Zurückkommen
                // (Kamera-App, Anruf, App-Wechsel) wieder aktivieren.
                setScreenAwake(phase == .active)
            }
    }

    private func setScreenAwake(_ awake: Bool) {
        guard UIApplication.shared.isIdleTimerDisabled != awake else { return }
        UIApplication.shared.isIdleTimerDisabled = awake
    }
}

extension View {
    func keepScreenAwake() -> some View {
        modifier(KeepScreenAwake())
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: PushUpCamera

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = camera.session
        view.attachedStatus = camera.status
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // Eine Vorschau-Ebene, die vor dem Aufbau der Session zugewiesen wurde,
        // bleibt schwarz. Deshalb bei jedem Statuswechsel neu zuweisen.
        guard uiView.attachedStatus != camera.status else { return }
        uiView.attachedStatus = camera.status
        uiView.previewLayer.session = camera.session
    }
}

/// UIView, dessen Hintergrund-Layer direkt die Vorschau-Ebene ist – so füllt
/// das Kamerabild die View immer aus, ohne manuelles Frame-Handling.
final class PreviewUIView: UIView {
    var attachedStatus: PushUpCamera.Status?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
