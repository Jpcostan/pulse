# Pulse - Claude Development Context

> **Last Updated:** 2026-02-19
> **Current Status:** Phase 10 COMPLETE — Monetization with StoreKit 2
> **Next Phase:** Phase 11 (Polish & App Store Readiness)

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

### ⏸️ Phase 8: Siri Shortcuts (App Intents) — CODE COMPLETE, DEBUGGING DEFERRED TO PHASE 11
- **StartMeetingIntent:** Opens app, creates meeting with optional title, navigates to RecordingView
- **StopMeetingIntent:** Stops current recording, updates meeting in Core Data, returns duration dialog
- **MeetingIntentState:** Shared `@Observable` state connecting intents to UI navigation
- **PulseShortcuts:** AppShortcutsProvider registering phrases with Siri:
  - "Start a meeting in Pulse" / "Start recording in Pulse"
  - "Stop meeting in Pulse" / "Stop recording in Pulse"
- **AudioRecordingService:** Converted to shared singleton for intent access
- **HomeView:** Observes intent state, auto-creates meeting and navigates when triggered

### ✅ Phase 9: Transcription & Action Item Refinement — COMPLETE
- **Two-Tier Pattern System (2026-02-17):** Patterns split into generic (need task context) and specific (pass through). Generic patterns like "i'll", "we should" require a task verb, task noun, or time reference in the sentence. Prevents poems/narrative from triggering false positives.
- **Task Context Validation:** `hasTaskIndicators()` checks ~60 task verbs, ~30 task nouns, ~20 time indicators, and digit+am/pm patterns
- **New Action Patterns:** Intent phrases, task markers, phrasal verbs, deadline indicators ("due at", "due by", "due tomorrow"), "i have a meeting/homework/appointment" patterns
- **Negation Detection:** Sentences starting with "don't/do not" + verb are filtered out (exception: "don't forget" remains an action)
- **Question Filtering:** Sentences ending in "?" excluded unless they contain request patterns ("can you", "could you", "will you", "please")
- **Improved Date Parsing:** "in X days/weeks/months", "within a week/month", "ASAP" → tomorrow, "end of month" → last day, time-of-day extraction ("by 3pm", "before noon", "eod")
- **False Positive Guards:** Sentence length (min 3 words, max 200 chars), stop-word title filter (single stop words like "see", "that" rejected; real action verbs like "call" allowed)
- **Diagnostic Logging:** Every filtered sentence logs the specific reason (too short, too long, negation, question, no task context, stop word title)
- **Chunk Overlap:** 2-second overlap between transcription chunks to prevent word loss at boundaries (28s stride for 30s chunks)
- **Chunk Retry:** 1 retry per failed chunk (2 attempts total) with 500ms pause between attempts
- **Manual Action Creation:** "+" toolbar button in ActionReviewView creates new ActionItem with empty title, 100% confidence, auto-focused for immediate typing
- **Date Picker:** Tap date or "Add date" on any action item opens graphical DatePicker sheet with time component; includes "Remove Date" option
- **Editable Transcript:** "Edit"/"Done" toggle in MeetingDetailView Transcript section; edit mode shows TextEditor fields per chunk; saves to Core Data on "Done"
- **Improved Debug View:** Shows chunk timing, full text per chunk, detected actions with source sentences
- **Testing Status (2026-02-17):** ✅ Detects real action items, filters poem/narrative false positives

### ✅ Phase 10: Monetization (StoreKit 2) — COMPLETE
- **StoreService:** `@MainActor @Observable` singleton using StoreKit 2 (`Product.products`, `Transaction.currentEntitlements`, `Transaction.updates`)
- **Product:** `com.jpcostan.Pulse.pro.lifetime` — $5.99 one-time non-consumable purchase
- **Free Tier:** Unlimited recordings, all features, 3-minute max per recording
- **Pro Tier:** Unlimited recording length (up to existing 60-min cap)
- **Gate:** Recording auto-stops at 3 minutes for free users → PaywallView presented as sheet
- **PaywallView:** Shows branding, feature list, price, purchase button, restore purchases link
- **SettingsView:** Account status (Free/Pro), upgrade button, restore purchases, Live Activity instructions, app version/build
- **HomeView:** Added gear icon toolbar button linking to SettingsView
- **StoreKit Config:** `Configuration.storekit` for simulator testing with sandbox purchases
- **PulseApp:** StoreService initialized at launch for early entitlement loading

**Files Created:**
- `Services/StoreService.swift`
- `Views/PaywallView.swift`
- `Views/SettingsView.swift`
- `Configuration.storekit`

**Files Modified:**
- `Services/AudioRecordingService.swift` — Added `freeLimitDuration` (3 min), `didHitFreeLimit` published property, free limit check in timer
- `Views/RecordingView.swift` — Observes `didHitFreeLimit`, presents PaywallView sheet, handles free limit stop
- `Views/HomeView.swift` — Added settings gear button in toolbar
- `PulseApp.swift` — Initializes StoreService.shared at launch

### 📋 Phase 11: Polish & App Store Readiness (NEXT)
- **Onboarding Flow:** Modal walkthrough screens on first launch explaining app features; final slide includes Pro purchase prompt
- **Free-Mode UX:** Subtle indicator on RecordingView showing "Free — 3 min limit" so users know before the cutoff hits
- **Siri Shortcuts Debugging:** Phase 8 code compiles but Siri doesn't recognize commands on device — needs root cause fix
- **Permission Explanations:** Review all permission request strings for clarity
- **Error Handling Pass:** Audit all error paths for user-friendly messaging
- **Performance Pass:** Profile memory/CPU during long recordings and transcription
- **App Icon & Launch Screen:** Final assets
- **App Store Copy & Screenshots:** Prepare store listing materials
- **Privacy Disclosures:** App Store privacy nutrition labels
- **App Review Checklist:** Ensure compliance with App Store guidelines

### 📋 Phase 12: End-to-End Testing
Comprehensive testing across all app flows and edge cases:

**12.1 — Recording Flow (Free Tier)**
- Start recording → verify timer runs and audio level indicator works
- Hit 3-minute mark → verify auto-stop, paywall appears, recording saved
- Dismiss paywall without purchasing → verify 3-min recording proceeds to processing
- Purchase from paywall → verify Pro status updates immediately

**12.2 — Recording Flow (Pro Tier)**
- Start recording → record past 3 minutes → verify no cutoff
- Reach 45-minute mark → verify warning alert appears
- Reach 60-minute mark → verify auto-stop with graceful save
- Cancel recording → verify meeting deleted and audio file cleaned up

**12.3 — Background Recording & Live Activity**
- Start recording → lock device → verify recording continues in background
- Start recording → switch to another app → verify recording continues
- Verify Live Activity timer updates on lock screen while device locked
- Tap Live Activity → verify deep link returns to RecordingView
- End recording while in background → verify Live Activity dismissed

**12.4 — Transcription Pipeline**
- Short recording (< 30s) → verify single-chunk transcription
- Long recording (> 30s) → verify multi-chunk transcription with correct ordering
- Verify chunk overlap (2s) doesn't create duplicate words at boundaries
- Chunk retry on failure → verify resilience
- On-device model not downloaded → verify user-friendly error message guiding to Settings
- Empty/silent recording → verify graceful handling

**12.5 — Action Detection**
- Recording with clear action items → verify detection with appropriate confidence scores
- Recording with no action items → verify empty state in ActionReviewView
- False positive resistance: narrative/poem text → verify no spurious detections
- Negation filtering ("don't call him") → verify filtered out
- Question filtering ("Should we do X?") → verify filtered; but "Can you send the report?" → verify detected
- Generic patterns with task context ("I'll schedule the meeting") → verify detected
- Generic patterns without task context ("I'll be fine") → verify filtered

**12.6 — Action Review & Editing**
- Manual action creation via "+" button → verify new item appears, title editable
- Edit action item title inline → verify saved to Core Data
- Date picker: set due date → verify saved; remove date → verify removed
- Toggle include/exclude → verify persists
- Expand source sentence → verify correct sentence shown
- Confidence-sorted display → verify highest first

**12.7 — Reminders & Calendar (EventKit)**
- Create reminders from included action items → verify appear in Apple Reminders app
- Create calendar events for items with due dates → verify appear in Calendar app
- Sync status badges ("Synced to Reminders" / "In Calendar") → verify shown after creation
- Deny Reminders permission → verify graceful handling and clear error message
- Deny Calendar permission → verify graceful handling
- Items without due dates → verify no calendar event created

**12.8 — Monetization / StoreKit**
- Purchase flow (StoreKit sandbox) → verify isPro updates, paywall dismisses
- Restore purchases → verify entitlement restored and UI updates
- Kill and relaunch app → verify Pro status persists across launches
- Product loading failure (no network in sandbox) → verify error message shown
- User cancels purchase → verify no state change, paywall remains
- Settings view: Free user → shows "Free" + "Upgrade to Pro"; Pro user → shows "Pro — Lifetime"

**12.9 — Onboarding (Phase 11 feature)**
- First launch → verify onboarding appears automatically
- Walk through all slides → verify content and flow
- Purchase from final slide → verify Pro status activates
- Skip/dismiss onboarding → verify app works in free mode
- Second launch → verify onboarding does NOT appear again
- Fresh install → verify onboarding triggers again

**12.10 — Settings**
- Free user: shows "Free" status badge and "Upgrade to Pro" button
- Pro user: shows "Pro — Lifetime" confirmation, no upgrade button
- Restore purchases button → verify works (covered in 12.8)
- Live Activity section → verify instructional text present
- App version and build number → verify correct values from Bundle

**12.11 — Navigation & Flow**
- Full happy path: Home → Recording → Processing → Action Review → Summary → Home
- Cancel recording mid-flow → verify returns to Home, meeting deleted from Core Data
- View past meeting via MeetingDetailView → verify transcript, actions, audio player
- Delete meeting from Home list (swipe to delete) → verify removed from Core Data
- Deep link `pulse://recording` → verify navigates to active recording
- Pop-to-root after Summary → verify clean navigation state

**12.12 — Audio Playback (MeetingDetailView)**
- Play/pause recorded audio → verify controls work
- Skip forward/backward → verify seek positions
- Audio file exists → verify playback works
- Audio file deleted (user chose cleanup) → verify graceful handling (no crash)

**12.13 — Data Persistence & Core Data**
- Kill app during processing → verify partial data saved (transcript chunks)
- Kill app after completion → verify meeting, transcript, actions all intact
- Core Data relationships: Meeting → TranscriptChunks, Meeting → ActionItems → verify integrity
- TranscriptChunks ordered by `order` field → verify correct sequence
- ActionItem identifiers (reminder/calendar) → verify stored and retrievable

**12.14 — Edge Cases & Error Handling**
- No microphone permission → verify clear error message directing to Settings
- No speech recognition permission → verify clear error message
- Low battery (< 20%) at recording start → verify warning shown
- Low storage (< 500MB) at recording start → verify warning shown
- Audio interruption (incoming phone call during recording) → verify pause/resume
- Route change (headphones unplugged) → verify recording continues with built-in mic
- Very short recording (< 5 seconds) → verify transcription handles gracefully
- Very long meeting title → verify UI doesn't break
- Rapid start/stop recording → verify no crashes or stale state

**12.15 — Siri Shortcuts (if fixed in Phase 11)**
- "Start a meeting in Pulse" → verify meeting created and RecordingView appears
- "Stop meeting in Pulse" → verify recording stops and meeting saved
- Start with custom title parameter → verify title applied
- Shortcuts appear in Shortcuts app → verify listed
- No active recording + "Stop meeting" → verify graceful error

**12.16 — Performance & Stability**
- Memory usage during 30+ minute recording → verify no memory leaks
- CPU usage during transcription of long recording → verify reasonable
- App launch time → verify under 2 seconds
- UI responsiveness during processing (spinner, no freezes)
- Multiple meetings in list (20+) → verify scroll performance

**12.17 — App Store Readiness Checks**
- All permission strings present in Info.plist and worded clearly
- Privacy nutrition labels accurate (microphone, speech recognition, no data collection)
- No crashes on cold launch
- No crashes on any supported device size
- StoreKit product approved in App Store Connect
- App icon renders correctly at all sizes
- Launch screen displays properly

---

## Recent Session Summary (2026-02-19)

### Phase 10 COMPLETED: Monetization (StoreKit 2) ✅

**Implementation:**
- Created `StoreService` using StoreKit 2 async APIs — loads products, listens for transaction updates, checks entitlements on launch
- Created `PaywallView` — presented as sheet when free user hits 3-minute recording limit
- Created `SettingsView` — account status, upgrade/restore buttons, Live Activity guide, app version
- Created `Configuration.storekit` — local StoreKit testing config for simulator
- Modified `AudioRecordingService` — added 3-minute free limit check in timer callback, `didHitFreeLimit` flag
- Modified `RecordingView` — observes `didHitFreeLimit`, presents paywall sheet, handles auto-stop gracefully
- Modified `HomeView` — added gear icon in toolbar for settings navigation
- Modified `PulseApp` — initializes `StoreService.shared` at launch

**Build Status:** ✅ Build successful

---

## Previous Session Summary (2026-02-17)

### Phase 9 COMPLETED: Action Detection False Positive Fix ✅

**Problem:** Generic commitment patterns ("I'll", "we should", "let's") matched poem/narrative lines as false positives at 90% confidence, while some real action items were being over-filtered.

**Solution: Two-Tier Pattern System**
- Added `requiresTaskContext` flag to each pattern in `actionPatterns` array
- Generic patterns (i'll, we should, let's, i must, etc.) → `requiresTaskContext: true`
- Specific patterns (^send, follow up, due by, meeting, don't forget, etc.) → `requiresTaskContext: false`
- New `hasTaskIndicators()` method validates generic matches against task verbs (~60), task nouns (~30), time indicators (~20), and time patterns
- Generic patterns that fail validation `continue` to next pattern (don't reject sentence entirely)

**Additional Fixes:**
- Relaxed title filter: 1-word titles allowed unless they're stop words (was: minimum 2 words)
- Added patterns: "due at", "due today/tonight/tomorrow", "i have a meeting/homework/appointment"
- Added diagnostic logging for every filter decision
- Improved debug transcript view with chunk timing and action summary
- Reverted experimental chunk deduplication (was untested, could corrupt transcripts)

**Testing:** ✅ Detects real action items, filters poem false positives

**Git Repo Fix:** Removed nested `.git` from `Pulse/` directory. All files now tracked by outer repo. Added `.gitignore`. Pushed to GitHub.

**Files Modified:**
- `Services/ActionDetectionService.swift` — Two-tier patterns, task context validation, stop-word filter, diagnostic logging
- `Views/ActionReviewView.swift` — Enhanced debug transcript view
- `Views/ProcessingView.swift` — Reverted chunk deduplication, back to ". " join

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
│   │   ├── StoreService.swift            # StoreKit 2 IAP (Pro lifetime purchase)
│   │   └── LoggingService.swift          # Centralized os.Logger for debugging
│   ├── Views/
│   │   ├── HomeView.swift          # Main screen, meetings list + deep linking + settings
│   │   ├── RecordingView.swift     # Active recording UI + Live Activity + paywall gate
│   │   ├── ProcessingView.swift    # Transcription + action detection
│   │   ├── ActionReviewView.swift  # Review detected actions (real data)
│   │   ├── SummaryView.swift       # Completion screen + audio cleanup
│   │   ├── MeetingDetailView.swift # View past meeting details
│   │   ├── PaywallView.swift       # Pro upgrade paywall sheet
│   │   └── SettingsView.swift      # Settings: account, restore, about
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
21. **Two-Tier Action Patterns:** Generic commitment patterns (i'll, we should, let's) require task context validation; specific patterns (send, meeting, due by) pass directly
22. **Task Context Validation:** Sentences matching generic patterns must contain a task verb, task noun, or time reference to avoid poem/narrative false positives
23. **False Positive Guards:** Sentence length (3-200 words/chars), stop-word title filter (rejects "see", "that" but allows "call", "send")
24. **Chunk Overlap:** 2-second overlap between transcription chunks prevents word loss at boundaries
25. **Chunk Retry:** 1 retry per failed transcription chunk with 500ms delay for resilience
26. **Git Structure:** Single repo at `pulse/` level; inner `Pulse/.git` removed. `.gitignore` excludes xcuserdata, DerivedData, .DS_Store, .claude/
27. **Monetization Model:** One-time $5.99 lifetime purchase (non-consumable). Free users get all features but 3-min recording cap. Pro removes the cap.
28. **StoreKit 2:** Uses modern async/await API — `Product.products(for:)`, `Transaction.currentEntitlements`, `Transaction.updates` listener
29. **Free Limit Gate:** Recording auto-stops at 3 minutes for free users, saves what was captured, presents paywall sheet. After dismiss, proceeds to processing with the 3-min recording.
30. **StoreService Pattern:** `@MainActor @Observable` singleton accessed directly via `StoreService.shared` (not environment injection — simpler for service-to-service access in AudioRecordingService)

---

## How to Resume

Tell the next Claude session:

> "Read CLAUDE.md for project context. Phases 0-10 are complete and tested. Phase 8 (Siri) code is written but not working on device. Ready for Phase 11 (Polish & App Store Readiness), then Phase 12 (End-to-End Testing)."

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
- **Action Detection Over-Filtering RESOLVED (2026-02-17):** Previous false positive guards (title min 2 words) were too strict. Replaced with two-tier pattern system + stop-word title filter. Tested and working.
