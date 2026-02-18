//
//  AudioPlaybackService.swift
//  Pulse
//

import AVFoundation
import Combine

@MainActor
final class AudioPlaybackService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var error: PlaybackError?

    // MARK: - Private Properties

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    // MARK: - Playback Error

    enum PlaybackError: LocalizedError {
        case fileNotFound
        case playerInitializationFailed(Error)
        case playbackFailed(Error)

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Audio file not found."
            case .playerInitializationFailed(let error):
                return "Failed to initialize player: \(error.localizedDescription)"
            case .playbackFailed(let error):
                return "Playback failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Public Methods

    /// Load an audio file for playback
    func load(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PlaybackError.fileNotFound
        }

        do {
            // Configure audio session for playback
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            error = nil
        } catch {
            throw PlaybackError.playerInitializationFailed(error)
        }
    }

    /// Load from a file path string
    func load(path: String) throws {
        let url = URL(fileURLWithPath: path)
        try load(url: url)
    }

    /// Start or resume playback
    func play() {
        guard let player = audioPlayer else { return }

        player.play()
        isPlaying = true
        startTimer()
    }

    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Stop playback and reset to beginning
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimer()
    }

    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    /// Seek by a relative amount
    func skip(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(duration, player.currentTime + seconds))
        seek(to: newTime)
    }

    /// Clean up resources
    func cleanup() {
        stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private Methods

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.error = .playbackFailed(error)
            }
            self.isPlaying = false
            self.stopTimer()
        }
    }
}
