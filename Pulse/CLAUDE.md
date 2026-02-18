# Pulse - Claude Development Context

> **Last Updated:** 2026-02-13
> **Current Status:** Phase 9 (Transcription & Action Item Refinement) - Code complete, NEEDS MORE TESTING
> **Next Phase:** Complete Phase 9 testing, then Phase 10 (Monetization / StoreKit 2)

---

## Project Overview

**Pulse** is a privacy-first iOS app that transforms spoken meetings into actionable outcomes—tasks, reminders, and calendar events—using on-device intelligence.

**Source of Truth:** `/Users/joshuacostanza/workspace/pulse/Pulse_White_Paper_v1.pdf`

### Core Philosophy
- Apple-native frameworks only
- On-device processing (no cloud AI)
- Action-oriented, not transcription-first
- No chatbot UI
- Professional, calm UX

---

## Development Phases

### ✅ Phase 0: Project Setup — COMPLETE
- Created SwiftUI iOS project
- Set up Core Data with entities: `Meeting`, `TranscriptChunk`, `ActionItem`
- Created `PersistenceController` for Core Data stack
- Basic HomeView showing empty state

### ✅ Phase 1: UI Skeleton & Navigation — COMPLETE
- **HomeView:** Meetings list with empty state, status badges
- **RecordingView:** Timer, audio level indicator, stop button
- **ProcessingView:** Animated progress indicator, 3-step simulation
- **ActionReviewView:** Mock action items, toggle include/exclude, expandable source
- **SummaryView:** Completion stats, Done button, audio cleanup option
- **MeetingDetailView:** View past meetings with audio player
- **Navigation:** Proper NavigationStack with pop-to-root via `onComplete` closure chain

### ✅ Phase 2: Audio Recording (AVFoundation) — COMPLETE + ENHANCED
- `AudioRecordingService`: Start/stop recording, AAC format, interruption handling
- `AudioPlaybackService`: Play/pause/seek, skip forward/backward
- Microphone permission added to Info.plist
- Audio files saved to `Documents/Recordings/{meetingID}.m4a`
- Real-time audio level metering in RecordingView
- **Recording Safeguards (2026-01-27):**
  - Max 60-minute recording duration
  - Warning alert at 45 minutes
  - Auto-stop at 60 minutes with graceful save
  - Low battery check (warns if < 20%)
  - Low storage check (warns if < 500MB)
- **Background Recording:** App continues recording when in background (UIBackgroundModes: audio)

### ✅ Phase 3: Transcription Pipeline (Speech Framework) — COMPLETE + MAJOR REWRITE
- `TranscriptionService`: On-device transcription using SFSpeechRecognizer
- Speech recognition permission added to Info.plist
- **Chunked Audio Processing (2026-01-27):** Splits long recordings into 30-second chunks for reliable full transcription (solves on-device recognition buffer limits)
- **Progressive Saving:** Each transcript chunk saved to Core Data immediately after processing
- Transcripts viewable in MeetingDetailView (multiple chunks displayed in order)
- Error handling with user-friendly alerts
- Handles interruptions gracefully (saves partial transcripts)

### ✅ Phase 4: Action Engine (NaturalLanguage Framework) — COMPLETE
- `ActionDetectionService`: On-device NLP for action item detection
- Sentence segmentation using NLTokenizer
- Task detection via pattern matching (action verbs, commitments, requests)
- **Expanded Patterns (2026-01-27):** Added flexible patterns like "don't forget" (without requiring "to"), "remember", "make sure", etc.
- Date extraction using NSDataDetector + relative date keywords
- ActionItem entities created and saved to Core Data
- ProcessingView runs action detection after transcription (2-phase processing)

### ✅ Phase 5: Action Review UI — COMPLETE
- ActionReviewView now uses real ActionItem Core Data entities
- Toggle include/exclude with persistent save
- Editable action item titles
- Expandable source sentences
- Empty state when no actions detected
- Confidence-sorted display (highest confidence first)
- **Audio Cleanup Option (2026-01-27):** SummaryView offers option to delete audio file after processing to save storage (keeps transcript)

### ✅ Phase 6: Reminders & Calendar Integration (EventKit) — COMPLETE
- **RemindersService:** New service for EventKit integration
- **Permissions:** Added `NSRemindersFullAccessUsageDescription` and `NSCalendarsFullAccessUsageDescription` to Info.plist
- **Create Reminders:** Creates Apple Reminders from selected ActionItems with:
  - Title from action item
  - Notes containing source sentence
  - Due date with alarm if specified
- **Calendar Events:** Optional toggle to also create calendar events for items with due dates
  - Creates all-day events on due date
  - Adds 1-hour reminder alarm
- **Identifier Storage:** Stores `reminderIdentifier` and `calendarEventIdentifier` in ActionItem Core Data entity
- **Sync Status UI:**
  - ActionReviewView shows "Synced to Reminders" / "In Calendar" badges
  - MeetingDetailView shows sync icons (checklist for reminders, calendar for events)
- **SummaryView:** Updated to show counts of both reminders and calendar events created

### ✅ Phase 7: Live Activities (ActivityKit) — COMPLETE
- **RecordingActivityAttributes:** Defines static (meeting title, start time) and dynamic (elapsed seconds, recording status) data
- **PulseWidgets Extension:** Widget extension target created for Live Activities
- **Live Activity UI:** Lock screen and Dynamic Island views showing timer and recording status
- **Self-Updating Timer (2026-02-05):** Uses `Text(startTime, style: .timer)` so widget timer counts independently without app updates
- **Background Recording Fix (2026-02-05):** Added `UIBackgroundModes: [audio]` directly to Info.plist (build setting wasn't generating the array). Removed `.mixWithOthers` from audio session. Timers use `.common` run loop mode.
- **RecordingView Integration:** Start/stop/update Live Activity lifecycle managed in AudioRecordingService
- **Deep Linking:** URL scheme `pulse://recording` to return to active recording
- **Tested on physical device:** Timer updates on lock screen, recording continues in background

### 🚧 Phase 8: Siri Shortcuts (App Intents) — CODE COMPLETE, SIRI NOT WORKING
- **StartMeetingIntent:** Opens app, creates meeting with optional title, navigates to RecordingView
- **StopMeetingIntent:** Stops current recording, updates meeting in Core Data, returns duration dialog
- **MeetingIntentState:** Shared `@Observable` state connecting intents to UI navigation
- **PulseShortcuts:** AppShortcutsProvider registering phrases with Siri:
  - "Start a meeting in Pulse" / "Start recording in Pulse"
  - "Stop meeting in Pulse" / "Stop recording in Pulse"
- **AudioRecordingService:** Converted to shared singleton for intent access
- **HomeView:** Observes intent state, auto-creates meeting and navigates when triggered

### 🧪 Phase 9: Transcription & Action Item Refinement — CODE COMPLETE, NEEDS MORE TESTING
- **New Action Patterns:** Intent phrases ("i plan to", "i intend to"), task markers ("action item", "todo"), phrasal verbs ("reach out to", "circle back", "follow up on"), deadline indicators ("deadline is", "due by")
- **Negation Detection:** Sentences starting with "don't/do not" + verb are filtered out (exception: "don't forget" remains an action)
- **Question Filtering:** Sentences ending in "?" excluded unless they contain request patterns ("can you", "could you", "will you", "please")
- **Improved Date Parsing:** "in X days/weeks/months", "within a week/month", "ASAP" → tomorrow, "end of month" → last day, time-of-day extraction ("by 3pm", "before noon", "eod")
- **False Positive Guards (2026-02-13):** Added sentence length filters (min 3 words, max 200 chars) and minimum title length (2+ words after prefix removal) to prevent fragments and long non-action text from being detected
- **Chunk Overlap:** 2-second overlap between transcription chunks to prevent word loss at boundaries (28s stride for 30s chunks)
- **Chunk Retry:** 1 retry per failed chunk (2 attempts total) with 500ms pause between attempts
- **Manual Action Creation:** "+" toolbar button in ActionReviewView creates new ActionItem with empty title, 100% confidence, auto-focused for immediate typing
- **Date Picker:** Tap date or "Add date" on any action item opens graphical DatePicker sheet with time component; includes "Remove Date" option
- **Editable Transcript:** "Edit"/"Done" toggle in MeetingDetailView Transcript section; edit mode shows TextEditor fields per chunk; saves to Core Data on "Done"
- **Testing Status (2026-02-13):**
  - Test 1: Detected 2 real action items + 2 false positives (fragment "see" and entire poem). Fixed with length guards.
  - Test 2: After fix, only detected 1 of 2 real action items. May be over-filtering or transcription boundary issue.
  - **⚠️ MUST do additional testing before proceeding to Phase 10.**

### 📋 Remaining Phases (10-11)
10. Monetization (StoreKit 2)
11. Polish & App Store Readiness

---

## Recent Session Summary (2026-02-13)

### Phase 9 IMPLEMENTED: Transcription & Action Item Refinement — NEEDS MORE TESTING

**Code Changes (4 files modified):**

1. **ActionDetectionService.swift** — Major enhancements:
   - Added 17 new action patterns (intent phrases, task markers, phrasal verbs, deadline indicators)
   - Added corresponding prefix removals in `extractActionTitle`
   - Negation detection: filters "don't send that email" but keeps "don't forget to..."
   - Question filtering: filters "Should we reconsider?" but keeps "Can you send the report?"
   - Enhanced date parsing: "in X days/weeks/months", "within a week", "ASAP", "end of month"
   - Time-of-day extraction: "by 3pm", "before noon", "eod" → enriches dates with time
   - **False positive guards:** Sentences <3 words or >200 chars skipped; extracted titles <2 words skipped

2. **TranscriptionService.swift** — Reliability improvements:
   - 2-second overlap between chunks (28s stride for 30s chunks) to prevent word loss at boundaries
   - Retry logic: 1 retry per failed chunk with 500ms delay (2 attempts total)

3. **ActionReviewView.swift** — User editing capabilities:
   - "+" toolbar button for manual action item creation (empty title, 100% confidence, auto-focused)
   - Date picker sheet on action items with graphical DatePicker + time component
   - "Remove Date" and "Done" buttons in date picker
   - Time display on action items that have time-of-day set

4. **MeetingDetailView.swift** — Editable transcript:
   - "Edit"/"Done" toggle button in Transcript section header
   - Edit mode: TextEditor fields per chunk
   - Saves edited text to Core Data on "Done"

**Build Status:** ✅ Build successful

**Testing Results:**
- Test 1 (action item → poem → action item): Detected 2 real actions ✅ but also 2 false positives ❌ — the word "see" (90% confidence) and entire poem (82% confidence) were incorrectly flagged
- Root cause: Short fragments matching action patterns after prefix removal; long text containing incidental action words
- Fix applied: Added sentence length guards (min 3 words, max 200 chars) and title length guard (min 2 words)
- Test 2 (same format, after fix): Only detected 1 of 2 action items — false positives eliminated but possibly over-filtering
- **⚠️ More testing needed** — may need to adjust length thresholds or investigate if the missing action item is a transcription boundary issue vs. a filtering issue

**Next Steps:**
1. Test again with varied action item phrasings to diagnose why second action item was missed
2. Check Console.app logs (`subsystem:com.jpcostan.Pulse`) to see if the action item was transcribed but filtered, or not transcribed at all
3. Adjust filters if over-filtering is confirmed
4. Once action detection is reliable, proceed to Phase 10

---

## Previous Session Summary (2026-02-05)

### Phase 7 COMPLETED: Live Activities — Background Recording Fix

**Problem:** Recording and Live Activity timer both froze when screen was locked.

**Root Cause:** `UIBackgroundModes` was missing from built Info.plist. Build setting wasn't generating array format.

**Fixes Applied:**
1. Added `UIBackgroundModes` directly to Info.plist as proper array
2. Removed `.mixWithOthers` from audio session options
3. Changed timers to `.common` run loop mode
4. Live Activity uses `Text(startTime, style: .timer)` for self-updating display

**Testing Result:** ✅ Verified on physical iPhone

### Phase 8 COMPLETED: Siri Shortcuts (App Intents)

**Implementation:**
- `StartMeetingIntent` — Opens app, signals HomeView to create meeting and navigate to recording. Accepts optional title parameter.
- `StopMeetingIntent` — Stops recording via `AudioRecordingService.shared`, updates meeting Core Data entity, returns duration dialog to Siri.
- `MeetingIntentState` — `@Observable` singleton bridging intent triggers to SwiftUI navigation.
- `PulseShortcuts` — `AppShortcutsProvider` registering phrases: "Start a meeting in Pulse", "Stop meeting in Pulse", etc.
- `AudioRecordingService` — Converted to shared singleton so both RecordingView and intents use the same instance.
- `HomeView` — Added `onChange` observer for intent state to auto-create meetings from Siri.

**Files Created:**
- `Intents/StartMeetingIntent.swift`
- `Intents/StopMeetingIntent.swift`
- `Intents/MeetingIntentState.swift`
- `Intents/PulseShortcuts.swift`

**Files Modified:**
- `Services/AudioRecordingService.swift` — Added `static let shared`, state reset in `startRecording()`
- `Views/RecordingView.swift` — Changed to `@ObservedObject` using shared singleton
- `Views/HomeView.swift` — Added intent state observer and `startMeetingFromIntent(title:)`

**Build Status:** ✅ Build successful
**Testing:** ❌ "Hey Siri, start a meeting with Pulse" did NOT work on physical device. Siri did not recognize the shortcut. Needs debugging — possible issues:
- App Shortcuts may need the app to be launched at least once after install for registration
- Siri phrase matching may need adjustment
- May need to verify shortcuts appear in the Shortcuts app first
- `AppShortcutsProvider` may need to be explicitly referenced (e.g., in PulseApp.swift)
- iOS may require the app's display name to match the `\(.applicationName)` token exactly

---

## Previous Session Summary (2026-02-03)

### Phase 7 Implementation: Live Activities (ActivityKit)

**Code Implementation - COMPLETED:**
1. ✅ Created Widget Extension target `PulseWidgets` in Xcode
2. ✅ Created `RecordingActivityAttributes.swift` defining Live Activity data structure
3. ✅ Implemented `PulseWidgetsLiveActivity.swift` with lock screen and Dynamic Island UI
4. ✅ Integrated Live Activity lifecycle in `RecordingView`:
   - Starts Live Activity when recording begins
   - Updates timer every second
   - Ends Live Activity when recording stops/cancels
5. ✅ Added deep linking in `HomeView` to handle `pulse://recording` URL scheme
6. ✅ Lowered auto-include threshold from 0.80 to 0.75 (fixes action detection bug)
7. ✅ Clarified calendar toggle text from "X item(s) with due dates" to "Will add X item(s)"

**Xcode Configuration - IN PROGRESS (BUILD FAILING):**
1. ✅ Added `RecordingActivityAttributes.swift` to both `Pulse` and `PulseWidgetsExtension` targets
2. ⚠️ Need to verify: `NSSupportsLiveActivities` property in Info.plist
3. ⚠️ Need to verify: URL Type for `pulse://` scheme
4. ⚠️ Need to verify: Push Notifications capability

**Files Modified:**
- `Pulse/RecordingActivityAttributes.swift` (NEW)
- `PulseWidgets/PulseWidgetsLiveActivity.swift` (REPLACED)
- `Views/RecordingView.swift` (Added ActivityKit import and Live Activity management)
- `Views/HomeView.swift` (Added deep linking handler)
- `Views/ActionReviewView.swift` (Clarified toggle text)
- `Services/ActionDetectionService.swift` (Lowered auto-include threshold)

**Current Issue:**
- Build is failing - likely due to incorrect Info.plist configuration
- Need to re-verify all 3 Xcode configuration steps before testing

**Next Steps:**
1. Fix build errors by verifying Xcode configuration
2. Build successfully
3. Test on physical device (Live Activities require real device, not simulator)
4. Verify Live Activity appears on lock screen with timer
5. Test deep linking by tapping Live Activity

---

## Previous Session Summary (2026-01-29)

### Phase 6 Completed: Reminders & Calendar Integration
1. **RemindersService:** New service for creating Apple Reminders and Calendar events via EventKit
2. **Permissions:** Added Reminders and Calendar usage descriptions to Info.plist
3. **ActionReviewView:** "Create Reminders" button now creates real system reminders
4. **Calendar Toggle:** Optional toggle to also create calendar events for items with due dates
5. **Sync Status UI:** Visual indicators showing which items are synced to Reminders/Calendar
6. **SummaryView:** Shows counts of both reminders and calendar events created

### Action Detection Improvements (in progress)
1. **Added patterns without apostrophe:** "dont forget" now matches (speech recognition often omits apostrophes)
2. **Added meeting/appointment patterns:** "meeting on friday", "appointment at 3pm", "call with John" now detected
3. **Chunk boundary fix:** Changed chunk joining from space to ". " (period+space) for proper sentence segmentation
4. **Spelled-out number support:** "at nine" → "at 9", "noon" → "12" for date parsing
5. **Standalone weekday detection:** "on monday", "on friday" etc. now extract dates
6. **Debug UI:** Added transcript debug section in ActionReviewView to see what's being processed

### Logging System Overhaul
- **Problem:** NSLog and print statements weren't appearing in Xcode console
- **Solution:** Created `LoggingService.swift` using modern `os.Logger` API
- **Categories:** Transcription, ActionDetection, Audio, Reminders, General
- **Usage:** `Log.transcription.info("message")`, `Log.actionDetection.error("error")`
- **Viewing:** Use Console.app with filter `subsystem:com.jpcostan.Pulse`

### Issues Fixed Earlier This Session
1. **Silent transcription failures:** Chunk transcription errors were being silently swallowed. Now errors are tracked and if all chunks fail, a meaningful error is thrown with the actual failure reason.
2. **Better on-device model error handling:** Added `onDeviceModelNotReady` and `allChunksFailed` error types with clearer user-facing messages that guide users to download the speech recognition model in Settings.
3. **Deprecated API warnings:** Updated AVAssetExportSession to use modern `export(to:as:) async throws` API.
4. **Sendable warnings:** Fixed Core Data object captures in async closures by using objectID pattern.

### Current Issue Being Debugged
- **Problem:** Action items spoken at beginning/end of recordings sometimes not detected
- **Hypothesis:** Transcription chunks at boundaries may have issues, or sentence segmentation is inconsistent
- **Debug tool added:** ActionReviewView now shows "Debug: Transcript" section with raw chunk data
- **Next step:** User to test and report what the debug transcript shows

---

## Previous Session Summary (2026-01-27)

### Issues Fixed
1. **Action items not detected:** Core Data relationships weren't refreshing after saves. Added `viewContext.refresh(meeting, mergeChanges: true)` in ProcessingView.
2. **Incomplete transcription:** On-device Speech Recognition has buffer limits that discard older text. Implemented chunked audio processing (30-second segments).
3. **Pattern too strict:** "don't forget meeting" wasn't matching because pattern required "don't forget to". Added flexible patterns.

### Features Added
1. **Recording Safeguards:** Max duration (60 min), warnings (45 min), auto-stop, battery/storage checks
2. **Background Recording:** Configured audio background mode and audio session for recording when app is backgrounded
3. **Chunked Transcription:** Reliable full transcription for any length recording
4. **Progressive Saving:** Transcript chunks saved as they complete (resilient to interruptions)
5. **Audio Cleanup:** Option to delete audio file after processing to save storage

---

## Current File Structure

```
Pulse/
├── Pulse.xcodeproj/
├── Pulse/
│   ├── PulseApp.swift              # App entry point, Core Data injection
│   ├── Persistence.swift           # Core Data stack
│   ├── RecordingActivityAttributes.swift  # Live Activity data structure (shared with widget)
│   ├── Pulse.xcdatamodeld/         # Core Data model
│   │   └── Pulse.xcdatamodel/
│   │       └── contents            # Meeting, TranscriptChunk, ActionItem
│   ├── Intents/
│   │   ├── StartMeetingIntent.swift      # "Start Meeting" Siri shortcut
│   │   ├── StopMeetingIntent.swift       # "Stop Meeting" Siri shortcut
│   │   ├── MeetingIntentState.swift      # Shared state between intents and UI
│   │   └── PulseShortcuts.swift          # AppShortcutsProvider registration
│   ├── Services/
│   │   ├── AudioRecordingService.swift   # AVAudioRecorder + safeguards + background (shared singleton)
│   │   ├── AudioPlaybackService.swift    # AVAudioPlayer wrapper
│   │   ├── TranscriptionService.swift    # Chunked transcription (30s segments)
│   │   ├── ActionDetectionService.swift  # NaturalLanguage + pattern matching
│   │   ├── RemindersService.swift        # EventKit integration (Reminders + Calendar)
│   │   └── LoggingService.swift          # Centralized os.Logger for debugging
│   ├── Views/
│   │   ├── HomeView.swift          # Main screen, meetings list + deep linking
│   │   ├── RecordingView.swift     # Active recording UI + Live Activity management
│   │   ├── ProcessingView.swift    # Transcription + action detection
│   │   ├── ActionReviewView.swift  # Review detected actions (real data)
│   │   ├── SummaryView.swift       # Completion screen + audio cleanup
│   │   └── MeetingDetailView.swift # View past meeting details
│   └── Assets.xcassets/
├── PulseWidgets/                   # Widget Extension for Live Activities
│   ├── PulseWidgetsLiveActivity.swift   # Live Activity UI (lock screen + Dynamic Island)
│   ├── PulseWidgetsBundle.swift    # Widget bundle registration
│   └── Info.plist
├── PulseTests/
└── PulseUITests/
```

---

## Core Data Model

### Meeting
- `id`: UUID
- `title`: String?
- `createdAt`: Date
- `duration`: Double
- `audioFilePath`: String? (can be nil if audio deleted)
- `status`: String ("recording", "processing", "completed")
- Relationships: `transcriptChunks`, `actionItems`

### TranscriptChunk
- `id`: UUID
- `text`: String
- `startTime`: Double
- `endTime`: Double
- `order`: Int16 (for ordering chunks from chunked transcription)
- Relationship: `meeting`

### ActionItem
- `id`: UUID
- `title`: String
- `sourceSentence`: String?
- `dueDate`: Date?
- `isIncluded`: Bool
- `confidence`: Double
- `reminderIdentifier`: String?
- `calendarEventIdentifier`: String?
- Relationship: `meeting`

---

## Key Decisions Made

1. **Audio Format:** AAC (M4A) at 44.1kHz mono for good quality + small file size
2. **Navigation:** NavigationPath-based with closure chain for pop-to-root
3. **Transcription:** On-device only via SFSpeechRecognizer with requiresOnDeviceRecognition=true
4. **Chunked Transcription:** 30-second audio chunks processed separately to avoid on-device buffer limits
5. **Progressive Saving:** Transcript chunks saved immediately after each chunk completes
6. **Locale:** en-US speech recognizer (can be made configurable later)
7. **Action Detection:** Pattern-based matching for action verbs and commitment phrases
8. **Confidence Scoring:** Based on pattern strength (0.75-0.95 range)
9. **Auto-Include:** Actions with confidence >= 0.75 are auto-selected (lowered from 0.80 on 2026-02-03)
10. **Date Extraction:** NSDataDetector for explicit dates, keyword matching for relative dates
11. **Core Data Refresh:** After saving related entities, refresh the meeting object with `viewContext.refresh(meeting, mergeChanges: true)`
12. **Recording Limits:** 60-minute max duration with warnings at 45 minutes
13. **Background Recording:** Audio background mode enabled for continued recording
14. **Storage Management:** Optional audio deletion after processing (transcript preserved)
15. **Live Activities:** Self-updating timer via `Text(date, style: .timer)` on lock screen and Dynamic Island
16. **Deep Linking:** `pulse://recording` URL scheme to return to active recording from Live Activity tap
17. **UIBackgroundModes:** Must be added directly to Info.plist as array (build setting `INFOPLIST_KEY_UIBackgroundModes = audio` doesn't generate the key)
18. **Audio Session for Background:** Do NOT use `.mixWithOthers` — it prevents iOS from keeping the app alive in background for recording
19. **AudioRecordingService Singleton:** Shared instance (`AudioRecordingService.shared`) so both UI and App Intents access the same recorder
20. **Siri Integration:** App Intents with `openAppWhenRun = true` for Start (needs UI), background for Stop (just stops recording)
21. **False Positive Guards:** Sentence length (3-200 words/chars) and title length (2+ words) filters to prevent fragments and long non-action text from triggering patterns
22. **Chunk Overlap:** 2-second overlap between transcription chunks prevents word loss at boundaries
23. **Chunk Retry:** 1 retry per failed transcription chunk with 500ms delay for resilience

---

## How to Resume

Tell the next Claude session:

> "Read CLAUDE.md for project context. Phases 0-7 are complete. Phase 8 code is written (Siri not working on device). Phase 9 code is complete but NEEDS MORE TESTING — last test only detected 1 of 2 action items. Must verify action detection reliability before proceeding to Phase 10."

**Debugging tips for Phase 9 testing:**
- Use Console.app with filter `subsystem:com.jpcostan.Pulse` to check if missing actions were transcribed but filtered, or not transcribed at all
- Key filters that may over-filter: sentence min 3 words, sentence max 200 chars, title min 2 words
- Check `ActionDetectionService.swift` lines ~245-290 for the length guards

---

## Build & Run

```bash
cd /Users/joshuacostanza/workspace/pulse/Pulse
xcodebuild -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Bundle ID:** `com.jpcostan.Pulse`
**Min iOS:** 26.2 (Xcode 26)

---

## Known Issues / Notes

- **Console Logging:** NSLog/print statements don't appear in Xcode console. Switched to `os.Logger` API - use Console.app with filter `subsystem:com.jpcostan.Pulse` to view logs.
- **Action Detection at Boundaries:** Action items spoken at very beginning or end of recordings sometimes not detected. Currently debugging - transcript chunks may have boundary issues.
- **Chunk Concatenation:** Transcript chunks now joined with ". " to ensure proper sentence segmentation between chunks.
- **On-Device Model Required:** Transcription requires the on-device English speech recognition model to be downloaded. Users should go to Settings > General > Keyboard > Dictation and ensure the English language is downloaded for offline use.
- **Spelled-out Numbers:** Now supports "at nine" → "at 9" conversion for date parsing. Covers one-twelve, noon, midnight.
- **Siri Shortcuts NOT WORKING (2026-02-05):** Phase 8 code compiles and builds but "Hey Siri, start a meeting with Pulse" does not trigger the shortcut on physical device. Needs debugging. Check: shortcut registration, Siri phrase matching, Shortcuts app visibility, and whether `AppShortcutsProvider` is being picked up by the system.
- **Action Detection May Over-Filter (2026-02-13):** After adding false positive guards (sentence length 3-200 chars, title min 2 words), Test 2 only detected 1 of 2 action items. Need to determine if the missing item was not transcribed or was filtered out. Check Console.app logs for "ACTION FOUND" and "Sentence X:" entries to diagnose.
