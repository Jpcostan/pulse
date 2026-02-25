//
//  RecordingActivityAttributesTests.swift
//  PulseTests
//

import Testing
import Foundation
import ActivityKit
@testable import Pulsio

struct RecordingActivityAttributesTests {

    // MARK: - ContentState Codable

    @Test
    func contentStateCodableRoundTrip() throws {
        let state = RecordingActivityAttributes.ContentState(
            elapsedSeconds: 120,
            isRecording: true
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(RecordingActivityAttributes.ContentState.self, from: data)

        #expect(decoded.elapsedSeconds == 120)
        #expect(decoded.isRecording == true)
    }

    @Test
    func contentStateStoppedRoundTrip() throws {
        let state = RecordingActivityAttributes.ContentState(
            elapsedSeconds: 300,
            isRecording: false
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(RecordingActivityAttributes.ContentState.self, from: data)

        #expect(decoded.elapsedSeconds == 300)
        #expect(decoded.isRecording == false)
    }

    // MARK: - ContentState Hashable

    @Test
    func contentStateHashableEqual() {
        let state1 = RecordingActivityAttributes.ContentState(elapsedSeconds: 60, isRecording: true)
        let state2 = RecordingActivityAttributes.ContentState(elapsedSeconds: 60, isRecording: true)
        #expect(state1 == state2)
        #expect(state1.hashValue == state2.hashValue)
    }

    @Test
    func contentStateHashableDifferent() {
        let state1 = RecordingActivityAttributes.ContentState(elapsedSeconds: 60, isRecording: true)
        let state2 = RecordingActivityAttributes.ContentState(elapsedSeconds: 120, isRecording: true)
        #expect(state1 != state2)
    }
}
