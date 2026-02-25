//
//  AudioRecordingServiceTests.swift
//  PulseTests
//

import Testing
import Foundation
import AVFoundation
import UIKit
import ActivityKit
import Combine
import StoreKit
import Observation
@testable import Pulsio

struct AudioRecordingServiceTests {

    // MARK: - Constants

    @Test @MainActor
    func maxRecordingDurationIs60Minutes() {
        #expect(AudioRecordingService.maxRecordingDuration == 3600)
    }

    @Test @MainActor
    func warningThresholdIs45Minutes() {
        #expect(AudioRecordingService.warningThreshold == 2700)
    }

    @Test @MainActor
    func lowBatteryThresholdIs20Percent() {
        #expect(AudioRecordingService.lowBatteryThreshold == 0.20)
    }

    @Test @MainActor
    func lowStorageThresholdIs500MB() {
        #expect(AudioRecordingService.lowStorageThreshold == 500 * 1024 * 1024)
    }

    // MARK: - Audio File URL

    @Test @MainActor
    func audioFileURLGeneratesCorrectPath() {
        let service = AudioRecordingService()
        let meetingID = UUID()
        let url = service.getAudioFileURL(for: meetingID)

        #expect(url.pathExtension == "m4a")
        #expect(url.lastPathComponent == "\(meetingID.uuidString).m4a")
        #expect(url.pathComponents.contains("Recordings"))
    }

    @Test @MainActor
    func audioFileURLIsInDocumentsDirectory() {
        let service = AudioRecordingService()
        let meetingID = UUID()
        let url = service.getAudioFileURL(for: meetingID)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        #expect(url.path.hasPrefix(documentsPath))
    }

    // MARK: - Audio File Existence

    @Test @MainActor
    func audioFileExistsReturnsFalseForNonExistent() {
        let service = AudioRecordingService()
        let randomID = UUID()
        #expect(service.audioFileExists(for: randomID) == false)
    }

    // MARK: - Formatted Remaining Time

    @Test @MainActor
    func formattedRemainingTimeDefault() {
        let service = AudioRecordingService()
        let formatted = service.formattedRemainingTime
        #expect(formatted == "60:00")
    }

    // MARK: - Dismiss Duration Warning

    @Test @MainActor
    func dismissDurationWarningSetsToFalse() {
        let service = AudioRecordingService()
        service.dismissDurationWarning()
        #expect(service.showDurationWarning == false)
    }

    // MARK: - Initial State

    @Test @MainActor
    func initialStateIsNotRecording() {
        let service = AudioRecordingService()
        #expect(service.isRecording == false)
        #expect(service.currentTime == 0)
        #expect(service.audioLevel == 0)
        #expect(service.didAutoStop == false)
    }

    // MARK: - Delete Audio File

    @Test @MainActor
    func deleteNonExistentFileDoesNotThrow() throws {
        let service = AudioRecordingService()
        let randomID = UUID()
        try service.deleteAudioFile(for: randomID)
    }

    // MARK: - Error Descriptions

    @Test
    func permissionDeniedErrorDescription() {
        let error = AudioRecordingService.AudioRecordingError.permissionDenied
        #expect(error.errorDescription?.contains("Microphone") == true)
    }

    @Test
    func noActiveRecordingErrorDescription() {
        let error = AudioRecordingService.AudioRecordingError.noActiveRecording
        #expect(error.errorDescription?.contains("No active recording") == true)
    }

    @Test
    func fileNotFoundErrorDescription() {
        let error = AudioRecordingService.AudioRecordingError.fileNotFound
        #expect(error.errorDescription?.contains("Audio file not found") == true)
    }

    @Test @MainActor
    func lowBatteryErrorDescription() {
        let error = AudioRecordingService.AudioRecordingError.lowBattery(0.15)
        #expect(error.errorDescription?.contains("Battery") == true)
        #expect(error.errorDescription?.contains("15") == true)
    }

    @Test @MainActor
    func lowStorageErrorDescription() {
        let error = AudioRecordingService.AudioRecordingError.lowStorage(200 * 1024 * 1024)
        #expect(error.errorDescription?.contains("Storage") == true)
    }
}
