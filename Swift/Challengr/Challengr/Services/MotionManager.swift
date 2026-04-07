import Foundation
import CoreMotion
import Combine

final class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private var timer: Timer?

    @Published var score: Double = 0
    @Published var isMeasuring = false

    private var startTime: Date?
    private let duration: TimeInterval = 10.0
    private let updateInterval: TimeInterval = 0.01
    private let threshold: Double = 0.2

    func startMeasuring() {
        score = 0
        isMeasuring = true
        startTime = Date()

        guard motionManager.isAccelerometerAvailable else {
            isMeasuring = false
            return
        }

        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    func stopMeasuring() {
        motionManager.stopAccelerometerUpdates()
        timer?.invalidate()
        timer = nil
        isMeasuring = false
    }

    private func update() {
        guard let data = motionManager.accelerometerData else { return }

        let acc = data.acceleration
        let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
        let adjusted = abs(magnitude - 1.0)

        if adjusted > threshold {
            score += adjusted
        }

        if let start = startTime, Date().timeIntervalSince(start) >= duration {
            stopMeasuring()
        }
    }
}
