//
//  TranscriptionServiceTests.swift
//  PulseTests
//

import Testing
import Foundation
import Speech
@testable import Pulsio

struct TranscriptionServiceTests {

    // MARK: - Error Descriptions

    @Test
    func permissionDeniedErrorDescription() {
        let error = TranscriptionService.TranscriptionError.permissionDenied
        #expect(error.errorDescription?.contains("Speech recognition permission") == true)
    }

    @Test
    func recognizerUnavailableErrorDescription() {
        let error = TranscriptionService.TranscriptionError.recognizerUnavailable
        #expect(error.errorDescription?.contains("unavailable") == true)
    }

    @Test
    func audioFileNotFoundErrorDescription() {
        let error = TranscriptionService.TranscriptionError.audioFileNotFound
        #expect(error.errorDescription?.contains("Audio file not found") == true)
    }

    @Test
    func onDeviceModelNotReadyErrorDescription() {
        let error = TranscriptionService.TranscriptionError.onDeviceModelNotReady
        #expect(error.errorDescription?.contains("Settings") == true)
    }

    @Test
    func emptyTranscriptionErrorDescription() {
        let error = TranscriptionService.TranscriptionError.emptyTranscription
        #expect(error.errorDescription?.contains("No speech") == true)
    }

    @Test
    func timeoutErrorDescription() {
        let error = TranscriptionService.TranscriptionError.timeout
        #expect(error.errorDescription?.contains("timed out") == true)
    }

    @Test
    func allChunksFailedErrorDescription() {
        let error = TranscriptionService.TranscriptionError.allChunksFailed("test error")
        #expect(error.errorDescription?.contains("test error") == true)
    }

    // MARK: - Error Equality

    @Test
    func errorEqualitySameType() {
        let e1 = TranscriptionService.TranscriptionError.permissionDenied
        let e2 = TranscriptionService.TranscriptionError.permissionDenied
        #expect(e1 == e2)
    }

    @Test
    func errorEqualityDifferentType() {
        let e1 = TranscriptionService.TranscriptionError.permissionDenied
        let e2 = TranscriptionService.TranscriptionError.timeout
        #expect(e1 != e2)
    }

    @Test
    func allChunksFailedEquality() {
        let e1 = TranscriptionService.TranscriptionError.allChunksFailed("reason A")
        let e2 = TranscriptionService.TranscriptionError.allChunksFailed("reason A")
        let e3 = TranscriptionService.TranscriptionError.allChunksFailed("reason B")
        #expect(e1 == e2)
        #expect(e1 != e3)
    }

    // MARK: - Cancellation

    @Test @MainActor
    func cancelStopsTranscribing() {
        let service = TranscriptionService()
        service.cancel()
        #expect(service.isTranscribing == false)
    }

    // MARK: - Initial State

    @Test @MainActor
    func initialState() {
        let service = TranscriptionService()
        #expect(service.isTranscribing == false)
        #expect(service.progress == 0)
        #expect(service.chunksCompleted == 0)
        #expect(service.totalChunks == 0)
        #expect(service.error == nil)
    }
}
