#if os(macOS)
import Foundation
import CoreAudio

final class CoreAudioOutputDucker: SystemAudioDuckingControlling {
    private struct DuckingState {
        let sessionId: String
        let deviceId: AudioObjectID
        let originalVolume: Float32?
        let originalMute: Bool?
    }

    private let config: AudioDuckingConfig
    private let lock = NSLock()
    private var activeState: DuckingState?

    init(config: AudioDuckingConfig) {
        self.config = config
    }

    func beginDucking(sessionId: String) {
        guard config.enabled else { return }

        lock.lock()
        if activeState?.sessionId == sessionId {
            lock.unlock()
            return
        }
        let shouldRestoreExisting = activeState != nil
        lock.unlock()

        if shouldRestoreExisting {
            restoreDucking(sessionId: nil)
        }

        guard let deviceId = Self.defaultOutputDeviceId() else { return }
        let originalVolume = Self.readVolume(deviceId: deviceId)
        let originalMute = Self.readMute(deviceId: deviceId)

        lock.lock()
        activeState = DuckingState(
            sessionId: sessionId,
            deviceId: deviceId,
            originalVolume: originalVolume,
            originalMute: originalMute
        )
        lock.unlock()

        if config.muteInsteadOfDuck {
            Self.writeMute(true, deviceId: deviceId)
            return
        }

        let target = Float32(config.targetVolume)
        if let originalVolume {
            Self.writeVolume(min(originalVolume, target), deviceId: deviceId)
        } else {
            Self.writeVolume(target, deviceId: deviceId)
        }
    }

    func restoreDucking(sessionId: String?) {
        lock.lock()
        guard let state = activeState else {
            lock.unlock()
            return
        }
        if let sessionId, sessionId != state.sessionId {
            lock.unlock()
            return
        }
        activeState = nil
        lock.unlock()

        if let originalMute = state.originalMute {
            Self.writeMute(originalMute, deviceId: state.deviceId)
        }
        if let originalVolume = state.originalVolume {
            Self.writeVolume(originalVolume, deviceId: state.deviceId)
        }
    }

    private static func defaultOutputDeviceId() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceId = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceId
        )
        guard status == noErr, deviceId != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return deviceId
    }

    private static func readVolume(deviceId: AudioObjectID) -> Float32? {
        var address = volumeAddress()
        guard AudioObjectHasProperty(deviceId, &address) else { return nil }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &volume)
        guard status == noErr else { return nil }
        return volume
    }

    private static func writeVolume(_ volume: Float32, deviceId: AudioObjectID) {
        var address = volumeAddress()
        guard AudioObjectHasProperty(deviceId, &address),
              isPropertySettable(deviceId: deviceId, address: &address)
        else { return }
        var value = min(Float32(1), max(Float32(0), volume))
        AudioObjectSetPropertyData(
            deviceId,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &value
        )
    }

    private static func readMute(deviceId: AudioObjectID) -> Bool? {
        var address = muteAddress()
        guard AudioObjectHasProperty(deviceId, &address) else { return nil }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &muted)
        guard status == noErr else { return nil }
        return muted != 0
    }

    private static func writeMute(_ muted: Bool, deviceId: AudioObjectID) {
        var address = muteAddress()
        guard AudioObjectHasProperty(deviceId, &address),
              isPropertySettable(deviceId: deviceId, address: &address)
        else { return }
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(
            deviceId,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &value
        )
    }

    private static func volumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func isPropertySettable(deviceId: AudioObjectID, address: inout AudioObjectPropertyAddress) -> Bool {
        var isSettable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(deviceId, &address, &isSettable)
        return status == noErr && isSettable.boolValue
    }
}
#endif
