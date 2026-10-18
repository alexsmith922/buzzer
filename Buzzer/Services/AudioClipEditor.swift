import AVFoundation

/// Reads and trims recorded clips. Work happens off the main thread and every
/// completion handler is called on the main thread.
enum AudioClipEditor {

    /// Format for recordings: mono AAC, small files that play anywhere.
    static let recordingSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    struct Waveform {
        /// Loudest level in each slice of the clip, scaled so the loudest slice is 1.
        let peaks: [Float]
        let duration: TimeInterval
    }

    static func loadWaveform(of url: URL, bucketCount: Int = 120,
                             completion: @escaping (Result<Waveform, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try waveform(of: url, bucketCount: bucketCount) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Replaces the clip at `url` with just the part from `start` to `end` seconds.
    static func trim(_ url: URL, from start: TimeInterval, to end: TimeInterval,
                     completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let trimmedURL = url.deletingLastPathComponent()
                .appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
            do {
                try writeTrimmed(url, from: start, to: end, into: trimmedURL)
                _ = try FileManager.default.replaceItemAt(url, withItemAt: trimmedURL)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                try? FileManager.default.removeItem(at: trimmedURL)
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    // MARK: - Private

    private static func waveform(of url: URL, bucketCount: Int) throws -> Waveform {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let duration = Double(file.length) / format.sampleRate
        let buffer = try readFrames(of: file, from: 0, count: file.length)
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else {
            return Waveform(peaks: [], duration: duration)
        }

        let frameCount = Int(buffer.frameLength)
        let framesPerBucket = max(1, frameCount / bucketCount)
        var peaks: [Float] = []
        peaks.reserveCapacity(bucketCount)
        for bucketStart in stride(from: 0, to: frameCount, by: framesPerBucket) {
            var peak: Float = 0
            for frame in bucketStart..<min(bucketStart + framesPerBucket, frameCount) {
                peak = max(peak, abs(samples[frame]))
            }
            peaks.append(peak)
        }

        if let loudest = peaks.max(), loudest > 0 {
            peaks = peaks.map { $0 / loudest }
        }
        return Waveform(peaks: peaks, duration: duration)
    }

    private static func writeTrimmed(_ url: URL, from start: TimeInterval, to end: TimeInterval,
                                     into destination: URL) throws {
        let input = try AVAudioFile(forReading: url)
        let format = input.processingFormat
        let startFrame = max(0, AVAudioFramePosition(start * format.sampleRate))
        let endFrame = min(AVAudioFramePosition(end * format.sampleRate), input.length)
        let buffer = try readFrames(of: input, from: startFrame, count: endFrame - startFrame)

        // The output file is finished and closed when it goes out of scope here.
        let output = try AVAudioFile(forWriting: destination, settings: recordingSettings,
                                     commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        try output.write(from: buffer)
    }

    private static func readFrames(of file: AVAudioFile, from start: AVAudioFramePosition,
                                   count: AVAudioFramePosition) throws -> AVAudioPCMBuffer {
        guard count > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(count)) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        file.framePosition = start
        try file.read(into: buffer, frameCount: AVAudioFrameCount(count))
        return buffer
    }
}
