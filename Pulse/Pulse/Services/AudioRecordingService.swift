//
//  AudioRecordingService.swift
//  Pulse
//

import AVFoundation
import Combine
import UIKit
import ActivityKit

@MainActor
final class AudioRecordingService: NSObject, ObservableObject {
    // MARK: - Shared Instance

    static let shared = AudioRecordingService()

    // MARK: - Constants

    static let maxRecordingDuration: TimeInterval = 60 * 60  // 60 minutes
    static let warningThreshold: TimeInterval = 45 * 60      // 45 minutes
    static let lowBatteryThreshold: Float = 0.20             // 20%
    static let lowStorageThreshold: Int64 = 500 * 1024 * 1024 // 500MB

    // MARK: - Published Properties

    @Published private(set) var isRecording = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var error: AudioRecordingError?
    @Published private(set) var showDurationWarning = false
    @Published private(set) var didAutoStop = false
    @Published private(set) var remainingTime: TimeInterval = maxRecordingDuration
    @Published private(set) var autoStopResult: (url: URL, duration: TimeInterval)?

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var levelTimer: Timer?
    private var currentFileURL: URL?
    private var hasShownDurationWarning = false
    private var liveActivity: Activity<RecordingActivityAttributes>?
    private var meetingTitle: String = "Meeting"

    // MARK: - Audio Recording Error

    enum AudioRecordingError: LocalizedError {
        case permissionDenied
        case sessionConfigurationFailed(Error)
        case recorderInitializationFailed(Error)
        case recordingFailed(Error)
        case noActiveRecording
        case fileNotFound
        case lowBattery(Float)
        case lowStorage(Int64)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone access was denied. Please enable it in Settings."
            case .sessionConfigurationFailed(let error):
                return "Failed to configure audio session: \(error.localizedDescription)"
            case .recorderInitializationFailed(let error):
                return "Failed to initialize recorder: \(error.localizedDescription)"
            case .recordingFailed(let error):
                return "Recording failed: \(error.localizedDescription)"
            case .noActiveRecording:
                return "No active recording to stop."
            case .fileNotFound:
                return "Audio file not found."
            case .lowBattery(let level):
                return "Battery is low (\(Int(level * 100))%). Please charge your device before recording."
            case .lowStorage(let available):
                let availableMB = available / (1024 * 1024)
                return "Storage is low (\(availableMB)MB available). Please free up space before recording."
            }
        }
    }

    // MARK: - Pre-Recording Checks

    /// Check battery level - returns current level (0-1) or nil if unavailable
    func checkBatteryLevel() -> Float? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level >= 0 ? level : nil  // -1 means unknown
    }

    /// Check available storage in bytes
    func checkAvailableStorage() -> Int64? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let values = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            return nil
        }
    }

    /// Validate conditions before starting recording
    func validatePreRecordingConditions() -> AudioRecordingError? {
        // Check battery
        if let batteryLevel = checkBatteryLevel(),
           batteryLevel < Self.lowBatteryThreshold {
            return .lowBattery(batteryLevel)
        }

        // Check storage
        if let availableStorage = checkAvailableStorage(),
           availableStorage < Self.lowStorageThreshold {
            return .lowStorage(availableStorage)
        }

        return nil
    }

    // MARK: - Initialization

    override init() {
        super.init()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Request microphone permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Check current permission status
    private var hasRecordPermission: Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }

    /// Start recording audio to a file for the given meeting ID
    func startRecording(meetingID: UUID, meetingTitle: String = "Meeting") async throws -> URL {
        self.meetingTitle = meetingTitle

        // Check permission
        if !hasRecordPermission {
            let granted = await requestPermission()
            if !granted {
                throw AudioRecordingError.permissionDenied
            }
        }

        // Configure audio session
        try configureAudioSession()

        // Create file URL
        let fileURL = getAudioFileURL(for: meetingID)
        currentFileURL = fileURL

        // Configure recorder settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Initialize recorder
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
        } catch {
            throw AudioRecordingError.recorderInitializationFailed(error)
        }

        // Start recording
        guard audioRecorder?.record() == true else {
            throw AudioRecordingError.recordingFailed(NSError(domain: "AudioRecording", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"]))
        }

        isRecording = true
        currentTime = 0
        remainingTime = Self.maxRecordingDuration
        self.error = nil
        showDurationWarning = false
        didAutoStop = false
        autoStopResult = nil

        // Start timers
        startTimers()

        // Start Live Activity
        startLiveActivity()

        return fileURL
    }

    /// Stop the current recording
    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard isRecording, let recorder = audioRecorder, let fileURL = currentFileURL else {
            error = .noActiveRecording
            return nil
        }

        let duration = recorder.currentTime
        recorder.stop()

        stopTimers()
        isRecording = false

        // End Live Activity
        endLiveActivity()

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return (fileURL, duration)
    }

    /// Cancel the current recording and delete the file
    func cancelRecording() {
        guard isRecording else { return }

        audioRecorder?.stop()
        stopTimers()
        isRecording = false

        // End Live Activity
        endLiveActivity()

        // Delete the file
        if let fileURL = currentFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }

        currentFileURL = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Get the audio file URL for a meeting
    func getAudioFileURL(for meetingID: UUID) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDirectory = documentsPath.appendingPathComponent("Recordings", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

        return audioDirectory.appendingPathComponent("\(meetingID.uuidString).m4a")
    }

    /// Check if an audio file exists for a meeting
    func audioFileExists(for meetingID: UUID) -> Bool {
        let fileURL = getAudioFileURL(for: meetingID)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Delete audio file for a meeting
    func deleteAudioFile(for meetingID: UUID) throws {
        let fileURL = getAudioFileURL(for: meetingID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Dismiss the duration warning
    func dismissDurationWarning() {
        showDurationWarning = false
    }

    /// Format remaining time as string (e.g., "15:00")
    var formattedRemainingTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Private Methods

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            // Configure for background recording:
            // - .playAndRecord: allows both playback and recording
            // - .defaultToSpeaker: routes audio to speaker when no headphones
            // - .allowBluetoothA2DP: supports Bluetooth audio
            // NOTE: .mixWithOthers is intentionally omitted — it prevents iOS from
            // keeping the app alive in the background for audio recording.
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            throw AudioRecordingError.sessionConfigurationFailed(error)
        }
    }

    private func startTimers() {
        // Reset warning state
        hasShownDurationWarning = false
        showDurationWarning = false
        didAutoStop = false

        // Timer for current time and duration checks
        // Use .common run loop mode so the timer fires in background
        let recordingTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder, self.isRecording else { return }
                self.currentTime = recorder.currentTime
                self.remainingTime = Self.maxRecordingDuration - self.currentTime

                // Update Live Activity
                self.updateLiveActivity()

                // Check for warning threshold (45 minutes)
                if self.currentTime >= Self.warningThreshold && !self.hasShownDurationWarning {
                    self.hasShownDurationWarning = true
                    self.showDurationWarning = true
                }

                // Check for max duration (60 minutes) - auto-stop
                if self.currentTime >= Self.maxRecordingDuration {
                    self.autoStopResult = self.stopRecording()
                    self.didAutoStop = true
                }
            }
        }
        RunLoop.main.add(recordingTimer, forMode: .common)
        timer = recordingTimer

        // Timer for audio levels
        // Use .common run loop mode for consistency
        let audioLevelTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder, self.isRecording else { return }
                recorder.updateMeters()
                let level = recorder.averagePower(forChannel: 0)
                // Normalize from -160...0 dB to 0...1
                self.audioLevel = max(0, min(1, (level + 60) / 60))
            }
        }
        RunLoop.main.add(audioLevelTimer, forMode: .common)
        levelTimer = audioLevelTimer
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }

    // MARK: - Notification Handling

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        // Background/foreground transitions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        Task { @MainActor in
            switch type {
            case .began:
                // Interruption began (e.g., phone call)
                if isRecording {
                    audioRecorder?.pause()
                }
            case .ended:
                // Interruption ended
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        // Resume recording
                        audioRecorder?.record()
                    }
                }
            @unknown default:
                break
            }
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        Task { @MainActor in
            switch reason {
            case .oldDeviceUnavailable:
                // Headphones were unplugged - continue recording with built-in mic
                break
            case .newDeviceAvailable:
                // New device available (e.g., headphones plugged in)
                break
            default:
                break
            }
        }
    }

    @objc private func handleAppWillResignActive(_ notification: Notification) {
        // App going to background - recording continues automatically
        // with proper audio session configuration and background mode
        Task { @MainActor in
            if isRecording {
                NSLog("App going to background - recording continues")
            }
        }
    }

    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        // App returning to foreground
        Task { @MainActor in
            if isRecording {
                NSLog("App returned to foreground - recording active")
                // Ensure audio session is still active
                try? AVAudioSession.sharedInstance().setActive(true)
            }
        }
    }

    // MARK: - Live Activity Management

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let attributes = RecordingActivityAttributes(
            meetingTitle: meetingTitle,
            startTime: Date()
        )

        let initialState = RecordingActivityAttributes.ContentState(
            elapsedSeconds: 0,
            isRecording: true
        )

        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
        } catch {
            NSLog("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }

        let updatedState = RecordingActivityAttributes.ContentState(
            elapsedSeconds: Int(currentTime),
            isRecording: isRecording
        )

        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }

        Task {
            await activity.end(
                .init(
                    state: RecordingActivityAttributes.ContentState(
                        elapsedSeconds: Int(currentTime),
                        isRecording: false
                    ),
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
        }

        liveActivity = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.error = .recordingFailed(NSError(domain: "AudioRecording", code: -1, userInfo: [NSLocalizedDescriptionKey: "Recording did not finish successfully"]))
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.error = .recordingFailed(error)
            }
        }
    }
}
