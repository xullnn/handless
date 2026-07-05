#if os(macOS)
import Foundation
import AVFoundation

final class AudioCapture {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var pendingPCM = Data()
    private var preRollPCM = Data()
    private let pendingLock = NSLock()
    private let queue = DispatchQueue(label: "localvoiceinput.audio.capture")
    private let chunkBytes = 16000 * 2 * 480 / 1000 // 480ms, 16kHz, int16 mono
    private let preRollBytes = 16000 * 2 * 900 / 1000 // 900ms local in-memory pre-roll
    private var isRunning = false
    private var isCapturingSession = false
    private var currentSessionToken: AudioSessionToken?

    var onPCMChunk: ((AudioSessionToken, Data) -> Void)?
    var onError: ((Error) -> Void)?

    func prewarm() {
        queue.async { [weak self] in
            self?.startEngineIfNeeded(capturing: false)
        }
    }

    func start(sessionToken: AudioSessionToken) {
        queue.async { [weak self] in
            guard let self else { return }
            self.pendingLock.lock()
            self.pendingPCM.removeAll(keepingCapacity: true)
            self.pendingPCM.append(self.preRollPCM)
            self.currentSessionToken = sessionToken
            self.isCapturingSession = true
            self.pendingLock.unlock()
            self.startEngineIfNeeded(capturing: true)
        }
    }

    func cancel() {
        queue.async { [weak self] in
            guard let self else { return }
            self.pendingLock.lock()
            self.isCapturingSession = false
            self.currentSessionToken = nil
            self.pendingPCM.removeAll(keepingCapacity: true)
            self.pendingLock.unlock()
        }
    }

    func stopAndFlush(completion: @escaping (AudioSessionToken?, [Data]) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(nil, []) }
                return
            }
            self.pendingLock.lock()
            let sessionToken = self.currentSessionToken
            self.isCapturingSession = false
            self.currentSessionToken = nil
            let remaining = self.drainPendingChunksLocked(includePartial: true)
            self.pendingLock.unlock()
            DispatchQueue.main.async { completion(sessionToken, remaining) }
        }
    }

    private func startEngineIfNeeded(capturing: Bool) {
        do {
            pendingLock.lock()
            isCapturingSession = capturing
            if !capturing {
                currentSessionToken = nil
            }
            pendingLock.unlock()
            guard !isRunning && !engine.isRunning else { return }

            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true) else {
                throw NSError(domain: "LocalVoiceInput.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create 16kHz PCM output format"])
            }
            outputFormat = outFormat
            converter = AVAudioConverter(from: inputFormat, to: outFormat)

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                self?.handle(buffer: buffer, inputFormat: inputFormat)
            }

            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            DispatchQueue.main.async { self.onError?(error) }
        }
    }

    private func stopEngineIfNeeded() {
        guard isRunning || engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func handle(buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {
        guard let converter, let outputFormat else { return }
        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        var didProvideInput = false
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
        if let error {
            DispatchQueue.main.async { self.onError?(error) }
            return
        }
        guard let bytes = pcmBytes(from: outBuffer) else { return }
        appendOrBuffer(bytes)
    }

    private func pcmBytes(from buffer: AVAudioPCMBuffer) -> Data? {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        guard let data = audioBuffer.mData else { return nil }
        return Data(bytes: data, count: Int(audioBuffer.mDataByteSize))
    }

    private func appendOrBuffer(_ data: Data) {
        pendingLock.lock()
        guard isCapturingSession, let sessionToken = currentSessionToken else {
            appendPreRollLocked(data)
            pendingLock.unlock()
            return
        }
        pendingPCM.append(data)
        var chunks: [Data] = []
        while pendingPCM.count >= chunkBytes {
            let chunk = pendingPCM.prefix(chunkBytes)
            chunks.append(Data(chunk))
            pendingPCM.removeFirst(chunkBytes)
        }
        pendingLock.unlock()

        for chunk in chunks {
            DispatchQueue.main.async { self.onPCMChunk?(sessionToken, chunk) }
        }
    }

    private func appendPreRollLocked(_ data: Data) {
        preRollPCM.append(data)
        if preRollPCM.count > preRollBytes {
            preRollPCM.removeFirst(preRollPCM.count - preRollBytes)
        }
    }

    private func drainPendingChunksLocked(includePartial: Bool) -> [Data] {
        var chunks: [Data] = []
        while pendingPCM.count >= chunkBytes {
            let chunk = pendingPCM.prefix(chunkBytes)
            chunks.append(Data(chunk))
            pendingPCM.removeFirst(chunkBytes)
        }
        if includePartial && !pendingPCM.isEmpty {
            chunks.append(pendingPCM)
            pendingPCM.removeAll(keepingCapacity: true)
        }
        return chunks
    }
}
#endif
