import Foundation
import AVFoundation
import Combine

class SoundMeter: ObservableObject {
    
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    
    @Published var level: Float = -60.0
    @Published var isRunning: Bool = false
    @Published var maxLevel: Float = -60.0
    
    func start() {
        isRunning = true
        maxLevel = -60.0
        
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Audio session error")
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]
        
        let url = URL(fileURLWithPath: "/dev/null")
        
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
        } catch {
            print("Recorder error")
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            
            self.recorder?.updateMeters()
            let power = self.recorder?.averagePower(forChannel: 0) ?? -60
            
            DispatchQueue.main.async {
                self.level = power
                self.maxLevel = max(self.maxLevel, power)
            }
        }
    }
    
    func stop() {
        recorder?.stop()
        timer?.invalidate()
        isRunning = false
    }
    
    func getMaxLevel() -> Float {
        return maxLevel
    }
    
    deinit {
        stop()
    }
}
