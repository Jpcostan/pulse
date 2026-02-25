//
//  AudioPlaybackServiceTests.swift
//  PulseTests
//

import Testing
import Foundation
import AVFoundation
@testable import Pulsio

struct AudioPlaybackServiceTests {

    // MARK: - Initial State

    @Test @MainActor
    func initialStateIsNotPlaying() {
        let service = AudioPlaybackService()
        #expect(service.isPlaying == false)
        #expect(service.currentTime == 0)
        #expect(service.duration == 0)
        #expect(service.error == nil)
    }

    // MARK: - Cleanup

    @Test @MainActor
    func cleanupResetsState() {
        let service = AudioPlaybackService()
        service.cleanup()
        #expect(service.isPlaying == false)
        #expect(service.currentTime == 0)
    }

    // MARK: - Error Descriptions

    @Test
    func fileNotFoundErrorDescription() {
        let error = AudioPlaybackService.PlaybackError.fileNotFound
        #expect(error.errorDescription?.contains("Audio file not found") == true)
    }

    @Test
    func playerInitFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "test error"])
        let error = AudioPlaybackService.PlaybackError.playerInitializationFailed(underlying)
        #expect(error.errorDescription?.contains("initialize player") == true)
    }

    @Test
    func playbackFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "decode error"])
        let error = AudioPlaybackService.PlaybackError.playbackFailed(underlying)
        #expect(error.errorDescription?.contains("Playback failed") == true)
    }

    // MARK: - Load Invalid URL

    @Test @MainActor
    func loadNonExistentFileThrows() {
        let service = AudioPlaybackService()
        let badURL = URL(fileURLWithPath: "/nonexistent/path/audio.m4a")

        #expect(throws: AudioPlaybackService.PlaybackError.self) {
            try service.load(url: badURL)
        }
    }
}
