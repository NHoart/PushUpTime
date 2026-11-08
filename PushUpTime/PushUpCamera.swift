import AVFoundation
import Combine
import Foundation
import QuartzCore
import Vision

/// Zählt Liegestütze per Kamera (Vision-Body-Pose, Ellbogen-Winkel).
final class PushUpCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    enum Status: Equatable {
        case idle
        case requesting
        case denied
        case noCamera
        case running
    }

    enum Phase: Equatable {
        case searching
        case down
        case up
    }

    @Published private(set) var count = 0
    @Published private(set) var phase: Phase = .searching
    @Published private(set) var status: Status = .idle
    /// Aktueller Ellbogen-Winkel, falls eine Pose erkannt wurde.
    @Published private(set) var poseAngle: Double?

    var target = 30
    var onCompleted: (() -> Void)?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "pushuptime.camera.session")
    private let visionQueue = DispatchQueue(label: "pushuptime.camera.vision")

    // Winkel (Grad) am Ellbogen, bei denen „unten“ bzw. „oben“ erreicht ist.
    private let downAngle: Double = 105
    private let upAngle: Double = 148
    private let minJointConfidence: Float = 0.2

    private var configured = false

    // Nur auf visionQueue benutzt.
    private var running = false
    private var frameCounter = 0
    /// Einmal gefundene Bild-Orientierung. Solange sie gut erkannt wird, wird
    /// nicht mehr in alle Richtungen gesucht.
    private var lockedOrientation: CGImagePropertyOrientation?
    private var lostFrames = 0
    private var preferredSide: Side?
    private var smoothedAngle: Double?
    private var smoothedAt: CFTimeInterval = 0
    private var isDown = false
    private var downSince: CFTimeInterval = 0
    private var lastRepAt: CFTimeInterval = 0
    private var phaseCache: Phase = .searching
    private var publishedAngle: Double?
    private var lastAnglePublish: CFTimeInterval = 0

    // Nur auf dem Main Thread benutzt.
    private var didComplete = false

    private enum Side: CaseIterable {
        case left
        case right

        typealias Joint = VNHumanBodyPoseObservation.JointName

        var shoulder: Joint { self == .left ? .leftShoulder : .rightShoulder }
        var elbow: Joint { self == .left ? .leftElbow : .rightElbow }
        var wrist: Joint { self == .left ? .leftWrist : .rightWrist }
    }

    private struct ArmReading {
        let side: Side
        let angle: Double
        let confidence: Float
    }

    private static let allOrientations: [CGImagePropertyOrientation] = [.up, .right, .down, .left]

    // MARK: - Lifecycle

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            publish { self.status = .requesting }
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.startSession()
                    } else {
                        self.status = .denied
                    }
                }
            }
        default:
            publish { self.status = .denied }
        }
    }

    func stop() {
        visionQueue.async { [weak self] in
            self?.running = false
            self?.resetTracking()
        }
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    // MARK: - Session

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.configureIfNeeded() else {
                DispatchQueue.main.async { self.status = .noCamera }
                return
            }
            self.visionQueue.async {
                self.resetTracking()
                self.running = true
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { self.status = .running }
        }
    }

    @discardableResult
    private func configureIfNeeded() -> Bool {
        if configured { return true }

        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)

        guard let device, let input = try? AVCaptureDeviceInput(device: device) else {
            return false
        }

        session.beginConfiguration()
        // Höhere Auflösung als .medium: Ellbogen und Handgelenk werden damit
        // auch aus etwas Entfernung sicher erkannt.
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: visionQueue)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(output)

        // Bewusst keine feste Rotation am Datenausgang: das iPhone liegt beim
        // Training oft seitlich, deshalb ermittelt Vision die Orientierung selbst.

        session.commitConfiguration()
        configured = true
        return true
    }

    // MARK: - Vision

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard running else { return }

        frameCounter += 1
        if frameCounter % 2 != 0 { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var observation: VNHumanBodyPoseObservation?

        if let locked = lockedOrientation {
            observation = detect(pixelBuffer, orientation: locked)
            if let observation, poseScore(observation) >= minJointConfidence {
                lostFrames = 0
            } else {
                observation = nil
                lostFrames += 1
                // Handy wurde gedreht oder verdeckt: Orientierung neu bestimmen.
                if lostFrames >= 10 {
                    lockedOrientation = nil
                    lostFrames = 0
                }
            }
        }

        if observation == nil {
            if let found = probe(pixelBuffer) {
                observation = found.0
                lockedOrientation = found.1
                lostFrames = 0
            }
        }

        handlePose(observation)
    }

    /// Probiert alle vier Bild-Orientierungen und nimmt das beste Ergebnis.
    private func probe(_ pixelBuffer: CVPixelBuffer) -> (VNHumanBodyPoseObservation, CGImagePropertyOrientation)? {
        var bestObservation: VNHumanBodyPoseObservation?
        var bestOrientation: CGImagePropertyOrientation = .up
        var bestScore: Float = 0

        for orientation in Self.allOrientations {
            guard let observation = detect(pixelBuffer, orientation: orientation) else { continue }
            let score = poseScore(observation)
            if score > bestScore {
                bestScore = score
                bestObservation = observation
                bestOrientation = orientation
            }
        }

        guard let bestObservation, bestScore >= 0.3 else { return nil }
        return (bestObservation, bestOrientation)
    }

    private func detect(_ pixelBuffer: CVPixelBuffer,
                        orientation: CGImagePropertyOrientation) -> VNHumanBodyPoseObservation? {
        // Pro Durchlauf ein eigener Request: derselbe Request darf nicht
        // gleichzeitig für mehrere Handler laufen.
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        return request.results?.first
    }

    /// Wie gut ist ein Arm dieser Pose zu sehen?
    private func poseScore(_ observation: VNHumanBodyPoseObservation) -> Float {
        var best: Float = 0
        for side in Side.allCases {
            guard let shoulder = try? observation.recognizedPoint(side.shoulder),
                  let elbow = try? observation.recognizedPoint(side.elbow),
                  let wrist = try? observation.recognizedPoint(side.wrist) else { continue }
            let score = min(shoulder.confidence, min(elbow.confidence, wrist.confidence))
            best = max(best, score)
        }
        return best
    }

    // MARK: - Zählen

    private func handlePose(_ observation: VNHumanBodyPoseObservation?) {
        let now = CACurrentMediaTime()

        guard let observation, let arm = bestArm(observation) else {
            // Kurze Aussetzer überbrücken, statt den Satz zu verlieren.
            if smoothedAngle == nil || now - smoothedAt > 0.8 {
                smoothedAngle = nil
                isDown = false
                preferredSide = nil
                publishPhase(.searching)
                publishAngle(nil)
            }
            return
        }

        preferredSide = arm.side
        publishAngle(arm.angle)

        let smoothed: Double
        if let previous = smoothedAngle, now - smoothedAt < 0.4 {
            smoothed = previous * 0.6 + arm.angle * 0.4
        } else {
            smoothed = arm.angle
        }
        smoothedAngle = smoothed
        smoothedAt = now

        if smoothed <= downAngle {
            if !isDown {
                isDown = true
                downSince = now
            }
            publishPhase(.down)
            return
        }

        guard smoothed >= upAngle else {
            // Zwischen den Schwellen: Zustand halten (Hysterese).
            return
        }

        guard isDown else {
            publishPhase(.up)
            return
        }

        guard now - downSince > 0.25, now - lastRepAt > 0.45 else { return }

        isDown = false
        lastRepAt = now
        phaseCache = .up
        publish {
            self.phase = .up
            self.registerRep()
        }
    }

    private func bestArm(_ observation: VNHumanBodyPoseObservation) -> ArmReading? {
        var readings: [ArmReading] = []

        for side in Side.allCases {
            guard let shoulder = try? observation.recognizedPoint(side.shoulder),
                  let elbow = try? observation.recognizedPoint(side.elbow),
                  let wrist = try? observation.recognizedPoint(side.wrist) else { continue }

            let confidence = min(shoulder.confidence, min(elbow.confidence, wrist.confidence))
            guard confidence >= minJointConfidence else { continue }

            let angle = elbowAngle(shoulder.location, elbow.location, wrist.location)
            guard angle.isFinite else { continue }

            readings.append(ArmReading(side: side, angle: angle, confidence: confidence))
        }

        // Einmal gewählter Arm bleibt aktiv, damit der Winkel nicht zwischen
        // links und rechts hin und her springt.
        if let preferred = preferredSide,
           let match = readings.first(where: { $0.side == preferred }),
           match.confidence >= 0.35 {
            return match
        }

        return readings.max(by: { $0.confidence < $1.confidence })
    }

    private func elbowAngle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let m1 = hypot(v1.dx, v1.dy)
        let m2 = hypot(v2.dx, v2.dy)
        guard m1 > 0.0001, m2 > 0.0001 else { return .nan }
        let cosine = max(-1.0, min(1.0, dot / (m1 * m2)))
        return acos(cosine) * 180.0 / .pi
    }

    private func resetTracking() {
        frameCounter = 0
        lockedOrientation = nil
        lostFrames = 0
        preferredSide = nil
        smoothedAngle = nil
        smoothedAt = 0
        isDown = false
        downSince = 0
        lastRepAt = 0
        phaseCache = .searching
        publish { self.phase = .searching }
        publishedAngle = nil
        lastAnglePublish = 0
        publish { self.poseAngle = nil }
    }

    // MARK: - Zählung (Main Thread)

    private func registerRep() {
        guard !didComplete else { return }
        count += 1
        if count >= target {
            didComplete = true
            onCompleted?()
        }
    }

    private func publishPhase(_ newPhase: Phase) {
        guard phaseCache != newPhase else { return }
        phaseCache = newPhase
        publish { self.phase = newPhase }
    }

    /// Meldet den Winkel gedrosselt an die Oberfläche, damit die Diagnosezeile
    /// nicht bei jedem Frame neu zeichnet.
    private func publishAngle(_ angle: Double?) {
        let rounded = angle.map { ($0 * 10).rounded() / 10 }
        guard rounded != publishedAngle else { return }
        let now = CACurrentMediaTime()
        if rounded != nil, now - lastAnglePublish < 0.2 { return }
        publishedAngle = rounded
        lastAnglePublish = now
        publish { self.poseAngle = rounded }
    }

    private func publish(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}
