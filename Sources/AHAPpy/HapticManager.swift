import Foundation
import AVFoundation
import CoreHaptics

public final class HapticManager: NSObject {
    public enum Mode {
        case sfx
        case music
    }

    public struct Options: Sendable {
        public var windowDuration: TimeInterval
        public var transientThreshold: Float
        public var minimumIntensity: Float
        public var intensityMultiplier: Float
        public var maximumContinuousDuration: TimeInterval
        public var sharpnessRange: ClosedRange<Float>
        public var includeTransientEvents: Bool
        public var maximumEventCount: Int

        public init(
            windowDuration: TimeInterval,
            transientThreshold: Float,
            minimumIntensity: Float,
            intensityMultiplier: Float,
            maximumContinuousDuration: TimeInterval,
            sharpnessRange: ClosedRange<Float>,
            includeTransientEvents: Bool,
            maximumEventCount: Int
        ) {
            self.windowDuration = windowDuration
            self.transientThreshold = transientThreshold
            self.minimumIntensity = minimumIntensity
            self.intensityMultiplier = intensityMultiplier
            self.maximumContinuousDuration = maximumContinuousDuration
            self.sharpnessRange = sharpnessRange
            self.includeTransientEvents = includeTransientEvents
            self.maximumEventCount = maximumEventCount
        }

        public static let sfxDefaults = Options(
            windowDuration: 0.045,
            transientThreshold: 0.65,
            minimumIntensity: 0.05,
            intensityMultiplier: 1.0,
            maximumContinuousDuration: 0.18,
            sharpnessRange: 0.25...0.95,
            includeTransientEvents: true,
            maximumEventCount: 1400
        )

        public static let musicDefaults = Options(
            windowDuration: 0.085,
            transientThreshold: 0.55,
            minimumIntensity: 0.035,
            intensityMultiplier: 0.9,
            maximumContinuousDuration: 0.32,
            sharpnessRange: 0.15...0.85,
            includeTransientEvents: true,
            maximumEventCount: 1800
        )
    }

    public struct Configuration: Sendable {
        public var sfxOptions: Options
        public var musicOptions: Options

        public init(sfxOptions: Options = .sfxDefaults, musicOptions: Options = .musicDefaults) {
            self.sfxOptions = sfxOptions
            self.musicOptions = musicOptions
        }

        fileprivate func options(for mode: Mode) -> Options {
            switch mode {
            case .sfx:
                return sfxOptions
            case .music:
                return musicOptions
            }
        }
    }

    public static let shared = HapticManager()

    private let audioQueue = DispatchQueue(label: "com.samroman.AHAPpy.audio")
    private let engineQueue = DispatchQueue(label: "com.samroman.AHAPpy.engine")

    private enum EngineState {
        case idle
        case running
    }

    private var engine: CHHapticEngine?
    private var engineState: EngineState = .idle
    private var audioPlayers: [AVAudioPlayer] = []
    private let configuration: Configuration
    private var lastEngineError: Error?

    public var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    public override convenience init() {
        self.init(configuration: Configuration())
    }

    public init(configuration: Configuration) {
        self.configuration = configuration
        super.init()
        prepareEngineIfPossible()
    }

    public func playAudioNamed(
        _ resourceName: String,
        withExtension fileExtension: String,
        in bundle: Bundle = .main,
        mode: Mode = .sfx,
        options overrideOptions: Options? = nil
    ) throws {
        guard let url = bundle.url(forResource: resourceName, withExtension: fileExtension) else {
            throw NSError(domain: "com.samroman.AHAPpy", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Resource \(resourceName).\(fileExtension) was not found in bundle \(bundle)."
            ])
        }
        try playAudio(at: url, mode: mode, options: overrideOptions)
    }

    public func playAudio(
        at audioURL: URL,
        mode: Mode = .sfx,
        options overrideOptions: Options? = nil
    ) throws {
        let options = overrideOptions ?? configuration.options(for: mode)

        let engine = try prepareEngineIfNeeded()
        let hapticPattern = try engine != nil ? generateHapticPattern(for: audioURL, options: options) : nil
        let hapticPlayer = try hapticPattern.flatMap { try engine?.makeAdvancedPlayer(with: $0) }

        let audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()

        audioQueue.sync {
            audioPlayers.append(audioPlayer)
        }

        if let engine = engine, let hapticPlayer = hapticPlayer {
            engineQueue.sync {
                do {
                    try engine.start()
                    self.engineState = .running
                    try hapticPlayer.start(atTime: CHHapticTimeImmediate)
                } catch {
                    lastEngineError = error
                    self.engineState = .idle
                }
            }
        }

        audioPlayer.play()
    }

    public func stopAll() {
        audioQueue.sync {
            for player in audioPlayers {
                player.stop()
            }
            audioPlayers.removeAll()
        }

        engineQueue.sync {
            guard let engine = engine else { return }
            do {
                try engine.stop()
                self.engineState = .idle
            } catch {
                lastEngineError = error
                self.engineState = .idle
            }
        }
    }

    @discardableResult
    public func prepareHaptics(
        for audioURL: URL,
        mode: Mode = .sfx,
        options overrideOptions: Options? = nil
    ) throws -> CHHapticPattern? {
        let options = overrideOptions ?? configuration.options(for: mode)
        guard try prepareEngineIfNeeded() != nil else { return nil }
        return try generateHapticPattern(for: audioURL, options: options)
    }

    private func prepareEngineIfPossible() {
        guard supportsHaptics else { return }
        engineQueue.sync {
            if self.engine != nil { return }
            do {
                let engine = try CHHapticEngine()
                engine.isAutoShutdownEnabled = true
                engine.playsHapticsOnly = false
                engine.stoppedHandler = { [weak self] reason in
                    guard let self else { return }
                    switch reason {
                    case .audioSessionInterrupt:
                        break
                    default:
                        self.lastEngineError = NSError(
                            domain: "com.samroman.AHAPpy",
                            code: Int(reason.rawValue),
                            userInfo: [NSLocalizedDescriptionKey: "Haptic engine stopped with reason \(reason.rawValue)."]
                        )
                    }
                    self.engineQueue.async {
                        self.engineState = .idle
                    }
                }
                engine.resetHandler = { [weak self] in
                    guard let self else { return }
                    self.engineQueue.async {
                        do {
                            try self.engine?.start()
                            self.engineState = .running
                        } catch {
                            self.lastEngineError = error
                            self.engineState = .idle
                        }
                    }
                }
                self.engine = engine
                try engine.start()
                self.engineState = .running
            } catch {
                self.lastEngineError = error
                self.engine = nil
                self.engineState = .idle
            }
        }
    }

    private func prepareEngineIfNeeded() throws -> CHHapticEngine? {
        guard supportsHaptics else { return nil }

        var engineError: Error?
        var readyEngine: CHHapticEngine?

        engineQueue.sync {
            if self.engine == nil {
                do {
                    let engine = try CHHapticEngine()
                    engine.isAutoShutdownEnabled = true
                    engine.playsHapticsOnly = false
                    engine.resetHandler = { [weak self] in
                        guard let self else { return }
                        self.engineQueue.async {
                            do {
                                try self.engine?.start()
                                self.engineState = .running
                            } catch {
                                self.lastEngineError = error
                                self.engineState = .idle
                            }
                        }
                    }
                    engine.stoppedHandler = { [weak self] reason in
                        guard let self else { return }
                        switch reason {
                        case .audioSessionInterrupt:
                            break
                        default:
                            self.lastEngineError = NSError(
                                domain: "com.samroman.AHAPpy",
                                code: Int(reason.rawValue),
                                userInfo: [NSLocalizedDescriptionKey: "Haptic engine stopped with reason \(reason.rawValue)."]
                            )
                        }
                        self.engineQueue.async {
                            self.engineState = .idle
                        }
                    }
                    self.engine = engine
                } catch {
                    engineError = error
                    self.engine = nil
                    self.engineState = .idle
                }
            }

            guard engineError == nil else { return }

            guard let engine = self.engine else { return }
            do {
                if self.engineState != .running {
                    try engine.start()
                    self.engineState = .running
                }
                readyEngine = engine
            } catch {
                engineError = error
                self.engineState = .idle
            }
        }

        if let error = engineError {
            throw error
        }
        return readyEngine
    }

    private func generateHapticPattern(for audioURL: URL, options: Options) throws -> CHHapticPattern {
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat
        let frameCapacity = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            throw NSError(domain: "com.samroman.AHAPpy", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to allocate audio buffer."
            ])
        }
        try audioFile.read(into: buffer)

        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0 else {
            return try CHHapticPattern(events: [], parameters: [])
        }

        let frameLength = Int(buffer.frameLength)
        let windowSize = max(1, Int(options.windowDuration * buffer.format.sampleRate))
        var rmsValues: [Float] = []
        rmsValues.reserveCapacity(frameLength / windowSize + 1)

        func normalizeSample(_ sample: Float) -> Float {
            return sample
        }

        func normalizeSample(_ sample: Int16) -> Float {
            return Float(sample) / Float(Int16.max)
        }

        func normalizeSample(_ sample: Int32) -> Float {
            return Float(sample) / Float(Int32.max)
        }

        if let floatChannelData = buffer.floatChannelData {
            for start in stride(from: 0, to: frameLength, by: windowSize) {
                let end = min(start + windowSize, frameLength)
                let frameCount = end - start
                guard frameCount > 0 else { continue }

                var cumulative: Float = 0
                for channel in 0..<channelCount {
                    let channelPointer = floatChannelData[channel]
                    var channelEnergy: Float = 0
                    var index = start
                    while index < end {
                        let sample = channelPointer[index]
                        channelEnergy += sample * sample
                        index += 1
                    }
                    cumulative += channelEnergy / Float(frameCount)
                }
                let rms = sqrt(cumulative / Float(channelCount))
                rmsValues.append(rms)
            }
        } else if let int16ChannelData = buffer.int16ChannelData {
            for start in stride(from: 0, to: frameLength, by: windowSize) {
                let end = min(start + windowSize, frameLength)
                let frameCount = end - start
                guard frameCount > 0 else { continue }

                var cumulative: Float = 0
                for channel in 0..<channelCount {
                    let channelPointer = int16ChannelData[channel]
                    var channelEnergy: Float = 0
                    var index = start
                    while index < end {
                        let sample = normalizeSample(channelPointer[index])
                        channelEnergy += sample * sample
                        index += 1
                    }
                    cumulative += channelEnergy / Float(frameCount)
                }
                let rms = sqrt(cumulative / Float(channelCount))
                rmsValues.append(rms)
            }
        } else if let int32ChannelData = buffer.int32ChannelData {
            for start in stride(from: 0, to: frameLength, by: windowSize) {
                let end = min(start + windowSize, frameLength)
                let frameCount = end - start
                guard frameCount > 0 else { continue }

                var cumulative: Float = 0
                for channel in 0..<channelCount {
                    let channelPointer = int32ChannelData[channel]
                    var channelEnergy: Float = 0
                    var index = start
                    while index < end {
                        let sample = normalizeSample(channelPointer[index])
                        channelEnergy += sample * sample
                        index += 1
                    }
                    cumulative += channelEnergy / Float(frameCount)
                }
                let rms = sqrt(cumulative / Float(channelCount))
                rmsValues.append(rms)
            }
        } else {
            return try CHHapticPattern(events: [], parameters: [])
        }

        guard let maxRMS = rmsValues.max(), maxRMS > 0 else {
            return try CHHapticPattern(events: [], parameters: [])
        }

        var downsampled = rmsValues
        var effectiveWindowDuration = Double(windowSize) / format.sampleRate

        if downsampled.count > options.maximumEventCount {
            let strideFactor = Int(ceil(Double(downsampled.count) / Double(options.maximumEventCount)))
            guard strideFactor > 1 else { return try CHHapticPattern(events: [], parameters: []) }
            var compressed: [Float] = []
            compressed.reserveCapacity(options.maximumEventCount)

            var index = 0
            while index < downsampled.count {
                let end = min(index + strideFactor, downsampled.count)
                let slice = downsampled[index..<end]
                compressed.append(slice.max() ?? 0)
                index += strideFactor
            }

            downsampled = compressed
            effectiveWindowDuration *= Double(strideFactor)
        }

        var events: [CHHapticEvent] = []
        events.reserveCapacity(downsampled.count)
        let sharpnessRangeWidth = options.sharpnessRange.upperBound - options.sharpnessRange.lowerBound

        for (index, rms) in downsampled.enumerated() {
            var intensity = min(max(rms / maxRMS, 0), 1)
            intensity = min(max(intensity * options.intensityMultiplier, 0), 1)
            guard intensity >= options.minimumIntensity else { continue }

            let relativeTime = Double(index) * effectiveWindowDuration
            let sharpness = options.sharpnessRange.lowerBound + (sharpnessRangeWidth * intensity)
            let parameters = [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(sharpness, options.sharpnessRange.lowerBound), options.sharpnessRange.upperBound))
            ]

            if options.includeTransientEvents, intensity >= options.transientThreshold {
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: parameters,
                    relativeTime: relativeTime
                )
                events.append(event)
            } else {
                let duration = min(options.maximumContinuousDuration, effectiveWindowDuration)
                let event = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: parameters,
                    relativeTime: relativeTime,
                    duration: duration
                )
                events.append(event)
            }
        }

        return try CHHapticPattern(events: events, parameters: [])
    }
}

extension HapticManager: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioQueue.async {
            self.audioPlayers.removeAll { $0 === player }
        }
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        audioQueue.async {
            self.audioPlayers.removeAll { $0 === player }
        }
    }
}
