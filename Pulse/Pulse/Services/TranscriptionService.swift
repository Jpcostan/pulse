//
//  TranscriptionService.swift
//  Pulse
//

import Foundation
@preconcurrency import Speech
import AVFoundation
import CoreData
import Combine
import OSLog

@MainActor
final class TranscriptionService: ObservableObject {
    // MARK: - Constants

    /// Duration of each audio chunk for transcription (30 seconds)
    private static let chunkDuration: TimeInterval = 30.0

    /// Overlap between chunks to prevent word loss at boundaries (2 seconds)
    private static let chunkOverlap: TimeInterval = 2.0

    /// Maximum number of attempts per chunk (1 retry = 2 attempts total)
    private static let maxChunkAttempts = 2

    /// Pause between retry attempts (500ms)
    private static let retryDelay: UInt64 = 500_000_000

    /// Maximum time to wait for transcription to complete (5 minutes)
    private static let transcriptionTimeout: TimeInterval = 300.0

    // MARK: - Published Properties

    @Published private(set) var isTranscribing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentStep: String = ""
    @Published private(set) var error: TranscriptionError?
    @Published private(set) var chunksCompleted: Int = 0
    @Published private(set) var totalChunks: Int = 0

    // MARK: - Private Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isCancelled = false

    // MARK: - Error Types

    enum TranscriptionError: LocalizedError, Equatable {
        case permissionDenied
        case recognizerUnavailable
        case recognizerNotSupported
        case audioFileNotFound
        case transcriptionFailed(Error)
        case onDeviceNotAvailable
        case onDeviceModelNotReady
        case emptyTranscription
        case audioExportFailed
        case timeout
        case allChunksFailed(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Speech recognition permission was denied. Please enable it in Settings."
            case .recognizerUnavailable:
                return "Speech recognizer is currently unavailable."
            case .recognizerNotSupported:
                return "Speech recognition is not supported on this device."
            case .audioFileNotFound:
                return "Audio file not found."
            case .transcriptionFailed(let error):
                return "Transcription failed: \(error.localizedDescription)"
            case .onDeviceNotAvailable:
                return "On-device speech recognition is not available. Please download the language model in Settings."
            case .onDeviceModelNotReady:
                return "On-device speech recognition model is not ready. Please go to Settings > General > Keyboard > Dictation and ensure the English language is downloaded for offline use."
            case .emptyTranscription:
                return "No speech was detected in the recording."
            case .audioExportFailed:
                return "Failed to process audio file."
            case .timeout:
                return "Transcription timed out. The recording may be too long."
            case .allChunksFailed(let reason):
                return "Transcription failed for all audio segments: \(reason)"
            }
        }

        static func == (lhs: TranscriptionError, rhs: TranscriptionError) -> Bool {
            switch (lhs, rhs) {
            case (.permissionDenied, .permissionDenied),
                 (.recognizerUnavailable, .recognizerUnavailable),
                 (.recognizerNotSupported, .recognizerNotSupported),
                 (.audioFileNotFound, .audioFileNotFound),
                 (.onDeviceNotAvailable, .onDeviceNotAvailable),
                 (.onDeviceModelNotReady, .onDeviceModelNotReady),
                 (.emptyTranscription, .emptyTranscription),
                 (.audioExportFailed, .audioExportFailed),
                 (.timeout, .timeout):
                return true
            case (.transcriptionFailed(let e1), .transcriptionFailed(let e2)):
                return e1.localizedDescription == e2.localizedDescription
            case (.allChunksFailed(let r1), .allChunksFailed(let r2)):
                return r1 == r2
            default:
                return false
            }
        }
    }

    // MARK: - Initialization

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Permission Handling

    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Transcription

    /// Transcribes audio using chunked processing for reliable full transcription
    func transcribe(
        audioURL: URL,
        meeting: Meeting,
        context: NSManagedObjectContext
    ) async throws {
        Log.transcription.info("=== CHUNKED TRANSCRIPTION START ===")
        Log.transcription.info("Audio URL: \(audioURL.path)")

        // Reset state
        isTranscribing = true
        isCancelled = false
        progress = 0
        chunksCompleted = 0
        currentStep = "Preparing transcription..."
        error = nil

        defer {
            isTranscribing = false
        }

        // Check permission
        if authorizationStatus != .authorized {
            let granted = await requestPermission()
            if !granted {
                throw TranscriptionError.permissionDenied
            }
        }

        // Verify recognizer is available
        guard let recognizer = speechRecognizer else {
            throw TranscriptionError.recognizerNotSupported
        }

        guard recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        // Check if audio file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        // Check on-device availability
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceNotAvailable
        }

        // Get audio duration
        let asset = AVURLAsset(url: audioURL)
        let duration: TimeInterval
        do {
            duration = try await asset.load(.duration).seconds
        } catch {
            Log.transcription.error("Failed to load audio duration: \(error.localizedDescription)")
            throw TranscriptionError.audioExportFailed
        }

        Log.transcription.info("Audio duration: \(duration, format: .fixed(precision: 2)) seconds")

        // Calculate chunks with overlap
        // Effective stride = chunkDuration - chunkOverlap (e.g., 28s stride for 30s chunks with 2s overlap)
        let stride = Self.chunkDuration - Self.chunkOverlap
        let chunkCount = max(1, Int(ceil(duration / stride)))
        totalChunks = chunkCount
        Log.transcription.info("Will process \(chunkCount) chunks of \(Self.chunkDuration, format: .fixed(precision: 0))s with \(Self.chunkOverlap, format: .fixed(precision: 0))s overlap")

        currentStep = "Transcribing audio (0/\(chunkCount))..."
        progress = 0.05

        // Process each chunk
        var allTranscripts: [(order: Int, text: String, startTime: TimeInterval, endTime: TimeInterval)] = []
        var chunkErrors: [String] = []
        var lastError: Error?

        for chunkIndex in 0..<chunkCount {
            guard !isCancelled else { break }

            let startTime = TimeInterval(chunkIndex) * stride
            let endTime = min(startTime + Self.chunkDuration, duration)

            currentStep = "Transcribing chunk \(chunkIndex + 1)/\(chunkCount)..."
            Log.transcription.info("Processing chunk \(chunkIndex + 1): \(startTime, format: .fixed(precision: 2))s - \(endTime, format: .fixed(precision: 2))s")

            // Export this chunk to a temporary file
            let chunkURL = try await exportAudioChunk(
                from: audioURL,
                startTime: startTime,
                endTime: endTime,
                chunkIndex: chunkIndex
            )

            defer {
                // Clean up temp file
                try? FileManager.default.removeItem(at: chunkURL)
            }

            // Transcribe this chunk with retry
            var chunkSucceeded = false
            for attempt in 1...Self.maxChunkAttempts {
                guard !isCancelled else { break }

                do {
                    let transcript = try await transcribeChunk(
                        url: chunkURL,
                        recognizer: recognizer
                    )

                    Log.transcription.info("Chunk \(chunkIndex + 1) raw transcript: '\(transcript)' (length: \(transcript.count))")

                    if !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        allTranscripts.append((
                            order: chunkIndex,
                            text: transcript,
                            startTime: startTime,
                            endTime: endTime
                        ))

                        // Save chunk progressively to Core Data
                        try await saveTranscriptChunk(
                            text: transcript,
                            order: Int16(chunkIndex),
                            startTime: startTime,
                            endTime: endTime,
                            meeting: meeting,
                            context: context
                        )
                    } else {
                        Log.transcription.warning("Chunk \(chunkIndex + 1) produced empty transcript (no speech detected)")
                    }

                    chunkSucceeded = true
                    break
                } catch {
                    let errorDesc = error.localizedDescription
                    Log.transcription.error("Chunk \(chunkIndex + 1) attempt \(attempt) FAILED: \(errorDesc)")
                    lastError = error

                    if attempt < Self.maxChunkAttempts {
                        Log.transcription.info("Retrying chunk \(chunkIndex + 1) after 500ms...")
                        try? await Task.sleep(nanoseconds: Self.retryDelay)
                    }
                }
            }

            if !chunkSucceeded {
                let errorDesc = lastError?.localizedDescription ?? "Unknown error"
                chunkErrors.append("Chunk \(chunkIndex + 1): \(errorDesc)")

                // Check for on-device model not ready error
                if errorDesc.contains("offline") || errorDesc.contains("not available") || errorDesc.contains("download") {
                    Log.transcription.error("On-device model may not be downloaded")
                }
            }

            chunksCompleted = chunkIndex + 1
            progress = 0.05 + (Double(chunkIndex + 1) / Double(chunkCount)) * 0.9
        }

        // Check if we got any transcription
        if allTranscripts.isEmpty {
            // If all chunks failed with errors, provide more specific feedback
            if !chunkErrors.isEmpty {
                Log.transcription.error("=== ALL CHUNKS FAILED ===")
                for errorMsg in chunkErrors {
                    Log.transcription.error("\(errorMsg)")
                }

                // Check if the error suggests on-device model issue
                if let lastErr = lastError {
                    let errDesc = lastErr.localizedDescription.lowercased()
                    if errDesc.contains("offline") || errDesc.contains("not available") || errDesc.contains("download") || errDesc.contains("siri") {
                        throw TranscriptionError.onDeviceModelNotReady
                    }
                }

                // Provide the first error as context
                let firstError = chunkErrors.first ?? "Unknown error"
                throw TranscriptionError.allChunksFailed(firstError)
            }

            throw TranscriptionError.emptyTranscription
        }

        currentStep = "Complete"
        progress = 1.0

        Log.transcription.info("=== CHUNKED TRANSCRIPTION COMPLETE ===")
        Log.transcription.info("Processed \(chunkCount) chunks, saved \(allTranscripts.count) transcripts")
    }

    func cancel() {
        isCancelled = true
        recognitionTask?.cancel()
        recognitionTask = nil
        isTranscribing = false
    }

    // MARK: - Private Methods

    /// Exports a time range from the source audio to a temporary file
    private func exportAudioChunk(
        from sourceURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval,
        chunkIndex: Int
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)

        // Create temp file URL
        let tempDir = FileManager.default.temporaryDirectory
        let chunkURL = tempDir.appendingPathComponent("chunk_\(chunkIndex)_\(UUID().uuidString).m4a")

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.audioExportFailed
        }

        // Set time range
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 1000)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 1000)
        exportSession.timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

        // Export using modern async/throws API
        do {
            try await exportSession.export(to: chunkURL, as: .m4a)
        } catch {
            Log.transcription.error("Export failed: \(error.localizedDescription)")
            throw TranscriptionError.audioExportFailed
        }

        return chunkURL
    }

    /// Transcribes a single audio chunk
    private func transcribeChunk(
        url: URL,
        recognizer: SFSpeechRecognizer
    ) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            var longestTranscript = ""

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return }

                if let error = error {
                    // Some errors are recoverable (like no speech detected)
                    if (error as NSError).domain == "kAFAssistantErrorDomain" {
                        // No speech detected in this chunk - return empty
                        hasResumed = true
                        continuation.resume(returning: "")
                        return
                    }

                    hasResumed = true
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed(error))
                    return
                }

                guard let result = result else { return }

                let currentText = result.bestTranscription.formattedString
                if currentText.count > longestTranscript.count {
                    longestTranscript = currentText
                }

                if result.isFinal {
                    hasResumed = true
                    continuation.resume(returning: longestTranscript)
                }
            }
        }
    }

    /// Saves a transcript chunk to Core Data
    private func saveTranscriptChunk(
        text: String,
        order: Int16,
        startTime: TimeInterval,
        endTime: TimeInterval,
        meeting: Meeting,
        context: NSManagedObjectContext
    ) async throws {
        // Capture objectID to avoid Sendable warning
        let meetingObjectID = meeting.objectID

        try await context.perform {
            // Fetch meeting inside perform block
            guard let meetingInContext = try? context.existingObject(with: meetingObjectID) as? Meeting else {
                return
            }

            let chunk = TranscriptChunk(context: context)
            chunk.id = UUID()
            chunk.text = text
            chunk.order = order
            chunk.startTime = startTime
            chunk.endTime = endTime
            chunk.meeting = meetingInContext

            try context.save()
            Log.transcription.info("Saved transcript chunk \(order): \(text.count) characters")
        }
    }
}
