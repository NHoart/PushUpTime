import AVFoundation
import SwiftUI
import UIKit

struct ChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @StateObject private var camera = PushUpCamera()

    /// Die Challenge ist erledigt – die Bestätigung läuft, danach der Rücksprung.
    @State private var finished = false

    /// Test, Shortcuts-Aufruf oder echte Bildschirmzeit-Sperre.
    let request: AppModel.ChallengeRequest

    private var reps: Int { max(1, model.requiredReps) }
    private var remaining: Int { max(0, reps - camera.count) }

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
                    Text(request.statusLabel)
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

                Text(hint)
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

            if finished {
                completionOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            camera.target = reps
            camera.onCompleted = {
                finish()
            }
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    // MARK: - Views

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
                Text(request.isBlocking ? "Sperre aufgehoben" : "Challenge beendet")
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
            Circle()
                .trim(from: 0, to: min(1, Double(camera.count) / Double(reps)))
                .stroke(
                    Color(red: 0.95, green: 0.3, blue: 0.3),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.25), value: camera.count)

            VStack(spacing: 0) {
                Text("\(camera.count)")
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: camera.count)
                Text("von \(reps)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 250, height: 250)
    }

    private var cameraProblem: some View {
        VStack(spacing: 10) {
            Text(camera.status == .denied
                 ? "Kamera-Zugriff nötig, um Liegestütze zu zählen."
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
            // Ausweg aus der Meldung: schließt die Zählung ohne Liegestütze.
            if !request.isBlocking {
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
                .accessibilityHint("Beendet die Challenge, ohne Liegestütze zu zählen.")
            }

            HStack(spacing: 8) {
                Image(systemName: "iphone.gen3")
                Text("iPhone seitlich ablegen, sodass Schulter, Ellbogen und Handgelenk sichtbar sind.")
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

    private var hint: String {
        switch camera.status {
        case .denied:
            return "Kamera-Zugriff verweigert"
        case .noCamera:
            return "Keine Kamera verfügbar"
        case .idle, .requesting, .running:
            switch camera.phase {
            case .searching:
                return "Geh in Position …"
            case .down:
                return "Tiefer! 💥"
            case .up:
                return "Hoch – zählt! ✅"
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
            if let angle = camera.poseAngle {
                return "Pose erkannt · Ellbogen \(Int(angle.rounded()))°"
            }
            return "Kamera läuft · keine Pose im Bild"
        }
    }

    private var hintColor: Color {
        switch camera.phase {
        case .down:
            return Color(red: 1.0, green: 0.6, blue: 0.25)
        case .up:
            return Color(red: 0.45, green: 0.9, blue: 0.55)
        case .searching:
            return .white.opacity(0.6)
        }
    }

    /// Zählung abgeschlossen: kurz bestätigen und dann zurück in die App.
    private func finish() {
        guard !finished else { return }
        finished = true
        camera.stop()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            leave(ticket: model.completeChallenge())
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
