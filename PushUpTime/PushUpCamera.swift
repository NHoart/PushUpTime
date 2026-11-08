import AVFoundation
import Combine
import Foundation
import Vision

/// Zählt Liegestütze per Frontkamera (Vision-Body-Pose, Ellbogen-Winkel).
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

    var target = 30
    var onCompleted: (() -> Void)?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "pushuptime.camera.session")
    private let visionQueue = DispatchQueue(label: "pushuptime.camera.vision")
    private let poseRequest = VNDetectHumanBodyPoseRequest()

    private var configured = false
    private var running = false
    private var smoothedAngle: Double?
    private var isDown = false
    private var lastRepDate = Date.distantPast
    private var didComplete = false
    private var frameCounter = 0

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
        running = false
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    // MARK: - Session

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.configureIfNeeded() else {
                DispatchQueue.main.async { self.status = .noCamera }
                return
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.running = true
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
        session.sessionPreset = .medium

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

        if let connection = output.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

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

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([poseRequest])
        } catch {
            return
        }

        let observation = poseRequest.results?.first as? VNHumanBodyPoseObservation
        handlePose(observation)
    }

    private func handlePose(_ observation: VNHumanBodyPoseObservation?) {
        guard let observation, let (rawAngle, _) = bestArmAngle(observation) else {
            smoothedAngle = nil
            isDown = false
            publish { self.phase = .searching }
            return
        }

        let smoothed = smoothedAngle.map { $0 * 0.55 + rawAngle * 0.45 } ?? rawAngle
        smoothedAngle = smoothed

        if smoothed <= 105 {
            isDown = true
            publish { self.phase = .down }
        } else if smoothed >= 148 {
            var counted = false
            if isDown, Date().timeIntervalSince(lastRepDate) > 0.35 {
                isDown = false
                lastRepDate = Date()
                counted = true
            }
            publish {
                self.phase = .up
                if counted { self.registerRep() }
            }
        }
    }

    private func bestArmAngle(_ observation: VNHumanBodyPoseObservation) -> (Double, Float)? {
        typealias Joint = VNHumanBodyPoseObservation.JointName
        let arms: [(Joint, Joint, Joint)] = [
            (.rightShoulder, .rightElbow, .rightWrist),
            (.leftShoulder, .leftElbow, .leftWrist)
        ]

        var best: (Double, Float)?
        for arm in arms {
            guard let shoulder = try? observation.recognizedPoint(arm.0),
                  let elbow = try? observation.recognizedPoint(arm.1),
                  let wrist = try? observation.recognizedPoint(arm.2) else { continue }
            let confidence = min(shoulder.confidence, min(elbow.confidence, wrist.confidence))
            guard confidence > 0.25 else { continue }
            let value = elbowAngle(shoulder.location, elbow.location, wrist.location)
            guard value.isFinite else { continue }
            if best == nil || confidence > best!.1 {
                best = (value, confidence)
            }
        }
        return best
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

    // MARK: - Counting (Main Thread)

    private func registerRep() {
        guard !didComplete else { return }
        count += 1
        if count >= target {
            didComplete = true
            onCompleted?()
        }
    }

    private func publish(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}
