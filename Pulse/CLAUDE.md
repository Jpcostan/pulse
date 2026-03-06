# Pulse - Claude Development Context

> **Last Updated:** 2026-03-05
> **Current Status:** Phase 14 (App Store Submission) — Build 15 on TestFlight
> **Next Steps:** Complete App Store submission checklist (see "Next Session" section below)

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
- **Single-chunk optimization (2026-03-03):** For recordings ≤30s (single chunk), the original audio file is passed directly to the speech recognizer instead of re-exporting via `AVAssetExportSession`. Fixes issue where AAC re-encoding clipped the first ~1-2 seconds of audio due to encoder delay and keyframe alignment at CMTime 0, causing the first spoken sentence to be lost in short recordings.
- **Progressive Saving:** Each transcript chunk saved to Core Data immediately after processing
- Transcripts viewable in MeetingDetailView (multiple chunks displayed in order)
- Error handling with user-friendly alerts
- Handles interruptions gracefully (saves partial transcripts)

### ✅ Phase 4: Action Engine (NaturalLanguage Framework) — COMPLETE
- `ActionDetectionService`: On-device NLP for action item detection
- Sentence segmentation using NLTokenizer
- **Compound sentence splitting (2026-03-02):** Added `splitCompoundSentence()` post-processor to break run-on speech-to-text at conjunction + subject + action verb boundaries (e.g., "and Sarah should", "we also need to"). Fixes issue where speech recognition without punctuation caused multiple action items to coalesce into one.
- Task detection via pattern matching (action verbs, commitments, requests)
- **Expanded Patterns (2026-01-27):** Added flexible patterns like "don't forget" (without requiring "to"), "remember", "make sure", etc.
- **Third-person assignment patterns (2026-03-02):** Added `\w+ needs to`, `\w+ should`, `\w+ has to`, `\w+ must` patterns (with `requiresTaskContext: true`) to detect assignments like "Josh needs to send the report" and "Sarah should update the spreadsheet". Previously only first/second person ("I need to", "you should", "we need to") were covered.
- **"Also" support + case-insensitive splitting (2026-03-02):** Team and first-person patterns now accept optional "also" (e.g., `"we (also )?have to "`, `"i (also )?need to "`) so "we also have to finalize..." and "I also need to send..." are detected. Compound sentence splitter now uses `.caseInsensitive` regex so mid-sentence "I need to" (capitalized by speech recognition) triggers a split.
- **Expanded negation filter (2026-03-02):** Previously only checked "don't/do not" at sentence start. Now also catches mid-sentence negations: "not going to", "won't", "shouldn't", "can't", "decided not to", "no longer", "no need to", etc. Fixes false positive on "I'm not going to schedule that meeting anymore".
- **Meeting/appointment pattern false positive fix (2026-03-03):** The `meeting (on |at |this |next |)` pattern had an empty alternative `|)` that matched ANY sentence containing "meeting " — e.g., "that meeting we went pretty well" was falsely detected at 75%. Removed empty alternative, added `with ` and `for ` as valid prepositions. Same fix applied to `appointment` pattern.
- Date extraction using NSDataDetector + relative date keywords
- ActionItem entities created and saved to Core Data
- ProcessingView runs action detection after transcription (2-phase processing)

### ✅ Phase 5: Action Review UI — COMPLETE
- ActionReviewView now uses real ActionItem Core Data entities
- Toggle include/exclude with persistent save
- Editable action item titles (auto-saves on focus loss, not just on Return)
- Expandable source sentences
- Empty state when no actions detected
- Confidence-sorted display (highest confidence first)
- **Swipe-to-delete action items (2026-03-02):** Added `.swipeActions` on ActionItemRow in ActionReviewView so users can swipe left to delete unwanted or accidentally added items. Found during Section 6 manual testing.
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

### 🔄 Phase 11: Polish & App Store Readiness (IN PROGRESS)

**Completed (2026-02-24):**
- ✅ **Onboarding Flow:** 3-slide `OnboardingView.swift` with TabView paging — Welcome, How It Works, Get Started (Pro upgrade). Uses `@AppStorage("hasCompletedOnboarding")` for first-launch detection. Presented as `.fullScreenCover` from PulseApp.swift.
- ✅ **Free-Mode UX:** Orange capsule badge on RecordingView showing "Free — 3 min limit" (hidden for Pro users)
- ✅ **Permission Explanations:** All 4 permission strings updated with privacy-reassuring language ("stays on your device", "never uploaded", "no data leaves your device")
- ✅ **Error Handling Pass:** Fixed 7 silent failures across 4 files — RecordingView (recording start failures), HomeView (meeting create/delete), MeetingDetailView (audio load), SummaryView (audio delete). All now show user-facing alerts.
- ✅ **iOS 26 Deprecation Fix:** Replaced `Text() + Text()` concatenation with string interpolation in PaywallView and OnboardingView

**Remaining (non-code / deferred):**
- ⏸️ **Siri Shortcuts Debugging:** Phase 8 code compiles but Siri doesn't recognize commands on device — deferred
- 📋 **Performance Pass:** Profile memory/CPU during long recordings and transcription (requires Instruments)
- 📋 **App Icon & Launch Screen:** Final design assets needed
- 📋 **App Store Copy & Screenshots:** Prepare store listing materials (App Store Connect)
- 📋 **Privacy Disclosures:** App Store privacy nutrition labels (App Store Connect)
- 📋 **App Review Checklist:** Audit for common App Store rejection reasons

**Files Created:**
- `Views/OnboardingView.swift`

**Files Modified:**
- `PulseApp.swift` — Added `@AppStorage` + `.fullScreenCover` for onboarding
- `Views/RecordingView.swift` — Free-mode badge, recording start error alerts
- `Views/PaywallView.swift` — Fixed deprecated Text concatenation
- `Views/HomeView.swift` — Error alerts for meeting create/delete
- `Views/MeetingDetailView.swift` — Audio load error alert
- `Views/SummaryView.swift` — Audio delete error alert
- `Pulse.xcodeproj/project.pbxproj` — Updated all 4 permission strings

### 📋 Phase 12: Manual Testing
Comprehensive manual test pass on a physical device covering every user-facing flow and edge case.

**12.1 — Recording Flow (Free Tier)**
- Start recording → verify timer runs and audio level indicator animates
- Hit 3-minute mark → verify auto-stop, paywall appears, recording saved
- Dismiss paywall without purchasing → verify 3-min recording proceeds to processing
- Purchase from paywall → verify Pro status updates immediately, sheet dismisses

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
- On-device model not downloaded → verify user-friendly error message guiding to Settings
- Empty/silent recording → verify graceful handling (no crash, empty transcript)

**12.5 — Action Detection**
- Recording with clear action items ("I need to send the report by Friday") → verify detection
- Recording with no action items (just conversation) → verify empty state in ActionReviewView
- False positive resistance: read a poem or tell a story → verify no spurious detections
- Negation filtering ("don't call him") → verify filtered out
- Question filtering ("Should we do X?") → verify filtered; "Can you send the report?" → verify detected
- Generic patterns with task context ("I'll schedule the meeting") → verify detected
- Generic patterns without task context ("I'll be fine") → verify filtered
- Multiple action items in one recording → verify all detected and sorted by confidence

**12.6 — Action Review & Editing**
- Manual action creation via "+" button → verify new item appears, title editable and focused
- Edit action item title inline → verify saved to Core Data
- Date picker: set due date → verify saved; remove date → verify removed
- Toggle include/exclude → verify persists across view transitions
- Expand source sentence → verify correct sentence shown with animation
- Confidence-sorted display → verify highest first
- Empty state → verify "No Action Items Detected" message

**12.7 — Reminders & Calendar (EventKit)**
- Create reminders from included action items → verify appear in Apple Reminders app
- Create calendar events for items with due dates → verify appear in Calendar app
- Sync status badges ("Synced to Reminders" / "In Calendar") → verify shown after creation
- Deny Reminders permission → verify graceful handling and clear error message
- Deny Calendar permission → verify graceful handling
- Items without due dates → verify no calendar event created
- Items excluded (toggled off) → verify not synced

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

**12.10 — Settings**
- Free user: shows "Free" status badge and "Upgrade to Pro" button
- Pro user: shows "Pro — Lifetime" confirmation, no upgrade button
- Restore purchases button → verify works
- Live Activity section → verify instructional text present
- App version and build number → verify correct values from Bundle

**12.11 — Navigation & Flow**
- Full happy path: Home → Recording → Processing → Action Review → Summary → Home
- Cancel recording mid-flow → verify returns to Home, meeting deleted from Core Data
- View past meeting via MeetingDetailView → verify transcript, actions, audio player
- Delete meeting from Home list (swipe to delete) → verify removed from Core Data and list
- Deep link pulse://recording → verify navigates to active recording
- Pop-to-root after Summary → verify clean navigation state (no stale views)

**12.12 — Audio Playback (MeetingDetailView)**
- Play/pause recorded audio → verify controls work
- Skip forward/backward (15s) → verify seek positions update
- Slider seek → verify playback jumps to correct position
- Audio file exists → verify playback works end-to-end
- Audio file deleted (user chose cleanup in Summary) → verify graceful handling (no crash, section hidden)

**12.13 — Transcript Editing (MeetingDetailView)**
- "Edit" button in transcript section → verify TextEditor fields appear per chunk
- Modify text in a chunk → click "Done" → verify saved to Core Data
- Navigate away and return → verify edits persisted
- Multiple chunks → verify correct order maintained after edit

**12.14 — Data Persistence & Core Data**
- Kill app during processing → verify partial data saved (transcript chunks so far)
- Kill app after completion → verify meeting, transcript, actions all intact
- Core Data relationships: Meeting → TranscriptChunks, Meeting → ActionItems → verify integrity
- TranscriptChunks ordered by order field → verify correct sequence
- ActionItem identifiers (reminder/calendar) → verify stored and retrievable after sync

**12.15 — Edge Cases & Error Handling**
- No microphone permission → verify clear error message directing to Settings
- No speech recognition permission → verify clear error message directing to Settings
- Low battery (< 20%) at recording start → verify warning shown with "Record Anyway" option
- Low storage (< 500MB) at recording start → verify warning shown with "Record Anyway" option
- Audio interruption (incoming phone call during recording) → verify pause/resume or graceful stop
- Route change (headphones unplugged) → verify recording continues with built-in mic
- Very short recording (< 5 seconds) → verify transcription handles gracefully
- Very long meeting title (50+ characters) → verify UI doesn't break or truncate poorly
- Rapid start/stop recording (tap stop immediately after start) → verify no crash or stale state
- Record with no speech (silence only) → verify empty transcript, no crash

**12.16 — Siri Shortcuts (if fixed in Phase 11)**
- "Start a meeting in Pulsio" → verify meeting created and RecordingView appears
- "Stop meeting in Pulsio" → verify recording stops and meeting saved
- Start with custom title parameter → verify title applied
- Shortcuts appear in Shortcuts app → verify listed
- No active recording + "Stop meeting" → verify graceful error dialog

**12.17 — Performance & Stability**
- Memory usage during 10+ minute recording → verify no memory leaks (Instruments)
- CPU usage during transcription of long recording → verify reasonable
- App launch time → verify under 2 seconds (cold start)
- UI responsiveness during processing → verify spinner animates, no freezes
- Multiple meetings in list (10+) → verify scroll performance
- Rapid navigation between screens → verify no crashes

**12.18 — App Store Readiness Checks**
- All permission strings present in Info.plist and worded clearly
- Privacy nutrition labels accurate (microphone, speech recognition, no data collection)
- No crashes on cold launch
- No crashes on any supported device size (iPhone SE, standard, Pro Max)
- App icon renders correctly at all sizes
- Launch screen displays properly

### ✅ Phase 13: Unit Testing (Swift Testing — 135 Tests Passing) — COMPLETE
Implemented comprehensive unit tests using Swift Testing framework (`@Test` macro). In-memory Core Data contexts for test isolation. ActionDetectionService at 88.89% coverage, Persistence at 86.67%.
- **Test expansion (2026-03-03):** Added 14 new tests covering bugs found during manual testing: meeting/appointment pattern false positives (4 tests), first-person "also" patterns (3 tests), mid-sentence negation filtering (4 tests), third-person assignment patterns (3 tests). Total: 121 → 135 tests.

**13.1 — ActionDetectionService Tests** (highest priority — 773 LOC)
- Sentence segmentation: single sentence, multiple sentences, empty string
- Each action pattern category: commitment phrases ("I'll send", "we should review"), request phrases ("can you", "please send"), task markers ("TODO:", "action item:"), deadline phrases ("due by Friday", "due tomorrow")
- Two-tier pattern system: generic pattern WITH task context → detected; generic pattern WITHOUT task context → skipped
- hasTaskIndicators(): sentences with task verbs, task nouns, time indicators, digit+am/pm patterns
- Negation filtering: "don't call him" → filtered; "don't forget to send" → NOT filtered (exception)
- Question filtering: "Should we go?" → filtered; "Can you send the report?" → detected (request pattern)
- False positive guards: sentence < 3 words → filtered; sentence > 200 chars → filtered
- Stop-word title filter: extracted title "see" → filtered; extracted title "call" → allowed
- Confidence scoring: specific patterns score higher than generic patterns
- Deduplication: duplicate sentences produce single action item
- Date extraction: "by Friday" → next Friday, "in 3 days" → correct date, "ASAP" → tomorrow, "end of month" → last day, "by 3pm" → correct time
- Spelled-out number conversion: "at nine" → "at 9", "noon" → "12", "midnight" → "12 AM"
- Empty input: empty string → 0 actions, whitespace only → 0 actions
- Core Data integration: ActionItem entities created with correct fields

**13.2 — TranscriptionService Tests**
- Chunk calculation: 15s audio → 1 chunk, 45s audio → 2 chunks, 90s audio → 3 chunks
- Chunk overlap: 30s chunk with 2s overlap → 28s stride
- Progressive saving: TranscriptChunk entities saved per chunk with correct order
- Error handling: all chunks fail → throws allChunksFailed
- Cancellation: cancel() flag stops in-progress transcription
- Permission request: authorization status mapping
- Transcript text assembly: chunks joined with ". " separator

**13.3 — AudioRecordingService Tests**
- Pre-recording validation: battery < 20% → error, storage < 500MB → error, both OK → nil
- Free tier limit: isPro = false → limit at 180s; isPro = true → no limit
- Formatted remaining time: 300s → "5:00", 65s → "1:05", 0s → "0:00"
- Audio file URL generation: correct Documents/Recordings/{meetingID}.m4a path
- Audio file existence check: file exists → true, missing → false
- Audio file deletion: file removed from disk, throws if missing
- State reset: after stopRecording(), isRecording = false, currentTime = 0
- Dismiss duration warning: showDurationWarning set to false

**13.4 — RemindersService Tests**
- Authorization status updates: reflects EKEventStore auth status
- hasRemindersAccess: authorized → true, denied → false, notDetermined → false
- hasCalendarAccess: authorized → true, denied → false
- createReminders: correct count from included ActionItems only
- createReminders skips excluded items: isIncluded = false → not synced
- createCalendarEvents: only creates events for items with due dates
- Identifier storage: reminderIdentifier and calendarEventIdentifier saved to ActionItem

**13.5 — AudioPlaybackService Tests**
- Load valid URL → duration > 0, isPlaying = false
- Load invalid URL → throws PlaybackError
- Play/pause toggle: togglePlayPause flips isPlaying state
- Stop: resets currentTime to 0, isPlaying = false
- Seek: seek(to: 30) → currentTime = 30
- Skip: skip(by: 15) → currentTime += 15; skip(by: -15) → currentTime -= 15
- Skip bounds: skip past duration → clamped; skip before 0 → clamped
- Cleanup: isPlaying = false, duration = 0

**13.6 — StoreService Tests** (using StoreKit Testing)
- Initial state: isPro = false, product = nil
- loadProducts: products loaded from Configuration.storekit
- Purchase flow: after purchase, isPro = true
- Restore purchases: entitled transaction → isPro = true
- No entitlements: isPro remains false

**13.7 — Core Data Model Tests**
- Meeting creation: all fields populated (id, title, createdAt, status)
- Meeting relationships: transcriptChunks and actionItems populated and accessible
- TranscriptChunk: id, text, startTime, endTime, order, meeting relationship
- TranscriptChunk ordering: fetched results sorted by order field
- ActionItem: id, title, sourceSentence, dueDate, isIncluded, confidence
- Cascade delete: deleting Meeting removes associated chunks and actions
- Save/fetch round-trip: all fields intact after re-fetch

**13.8 — Persistence Controller Tests**
- Shared container loads: viewContext is not nil
- In-memory preview container: preview data contains sample meetings
- Merge policy: NSMergeByPropertyObjectTrumpMergePolicy is set
- automaticallyMergesChangesFromParent: enabled

**13.9 — RecordingActivityAttributes Tests**
- Codable: encode → decode round-trip preserves all fields
- ContentState: elapsedSeconds and isRecording serialize correctly
- Hashable: equal attributes produce same hash

**13.10 — Intent Tests**
- StartMeetingIntent: sets MeetingIntentState.pendingMeetingTitle
- StartMeetingIntent default: nil parameter → "Meeting"
- StopMeetingIntent: returns error dialog when no active recording
- MeetingIntentState: singleton pattern, pendingMeetingTitle observable

**13.11 — Date Parsing Tests (ActionDetectionService)**
- "by Friday" → next occurrence of Friday
- "next Monday" → next Monday from today
- "tomorrow" → today + 1 day
- "in 3 days" → today + 3 days
- "in 2 weeks" → today + 14 days
- "end of month" → last day of current month
- "ASAP" → tomorrow
- "by 3pm" → today at 15:00 (or tomorrow if past 3pm)
- "before noon" → today at 12:00
- "eod" / "end of day" → today at 17:00
- "on Monday" → next Monday with correct date
- No date in sentence → nil dueDate
- NSDataDetector dates: "March 15" → correct date object

**13.12 — Navigation & State Tests**
- HomeView meeting creation: new Meeting entity with auto-incremented title
- Deep link URL parsing: "pulse://recording" → valid, "pulse://other" → ignored
- ProcessingView phase transitions: transcribing → detectingActions → complete
- ProcessingView progress calculation: transcription at 50% → overall 35%; action detection at 50% → overall 85%

### 📋 Phase 14: App Store Submission
Final submission to App Store Connect after all testing passes.

### ✅ Phase 15: Codebase Analysis & Cleanup — COMPLETE
Audited and cleaned codebase for production readiness.

**15.0 — Debug Artifact Removal & NSLog Migration (2026-02-25)**
- Removed 2 debug log lines from `PulseApp.swift` (NSLog + print launch messages)
- Removed ~15 debug log lines from `ProcessingView.swift` (processing flow NSLogs, action detection debug dump, print warning)
- Removed `Section("Debug: Transcript")` UI and `transcriptDebugText` computed property from `ActionReviewView.swift`
- Migrated 2 NSLog calls in `StoreService.swift` → `Log.general.error(...)`
- Migrated 3 NSLog calls in `AudioRecordingService.swift` → `Log.audio.info/error(...)`
- Migrated 8 NSLog calls in `RemindersService.swift` → `Log.reminders.info/error(...)`
- Added `import os` to StoreService, AudioRecordingService, RemindersService (required for `os.Logger` string interpolation)
- Deleted 3 unused widget template files: `PulseWidgets.swift`, `PulseWidgetsControl.swift`, `AppIntent.swift`
- Updated `PulseWidgetsBundle.swift` to only include `PulseWidgetsLiveActivity()`
- `aps-environment = development` in entitlements left as-is (Xcode overrides to production at archive time)
- Build succeeded, all 121 tests pass

**15.1 — Pulse/Pulsio Naming Audit — COMPLETE (2026-02-25)**
Audited all user-facing strings for correct "Pulsio" naming. Found and fixed 3 issues:
- `HomeView.swift` line 32: `.navigationTitle("Pulse")` → `"Pulsio"`
- `StopMeetingIntent.swift` line 48: "Open Pulse to process" → "Open Pulsio to process"
- `SettingsView.swift` line 69: "Pulse Live Activity widget" / "Pulse widget" → "Pulsio" (2 occurrences)
- `PulseUITests.swift` line 30: Updated nav bar assertion to match `"Pulsio"`
- All other items passed: CFBundleDisplayName, permission strings, Siri phrases, bundle ID, IAP product ID, URL scheme, app icon metadata

---

## App Store Connect — IAP Setup ✅ COMPLETE (2026-03-03)

> **Status:** "Ready to Submit" — sandbox purchase verified working on TestFlight Build 15.

| Field | Value |
|-------|-------|
| Reference Name | `Pro Lifetime` |
| Product ID | `com.jpcostan.Pulse.pro.lifetime` |
| Type | Non-Consumable |
| Price | $5.99 (all countries/regions) |
| Display Name | `Pulsio Pro` |
| Description | `Unlimited recording time, up to 60 minutes.` |
| Review Screenshot | PaywallView screenshot uploaded |
| Review Notes | `This is a one-time non-consumable purchase that removes the 3-minute recording limit for free users, allowing recordings up to 60 minutes.` |

### Previously Deferred Manual Tests (NOW UNBLOCKED)
1.4, 2.1-2.3, 8.1-8.5, 8.7, 9.3, 10.2, 10.3

---

## Recent Session Summary (2026-03-03, evening)

### CI Pipeline Fix + IAP Setup Complete

**CI Fix — Core Data test crash:**
- Tests were crashing with `NSInvalidArgumentException: Unacceptable type of value for to-one relationship` — Core Data couldn't disambiguate `Meeting` entity across 60+ duplicate `NSManagedObjectModel` instances.
- Root cause: Each test's `makeInMemoryContext()` created a new `PersistenceController(inMemory: true)`, which called `NSPersistentContainer(name: "Pulse")`, loading a fresh model each time.
- Fix: Added `private static let model` in `PersistenceController` to load the `NSManagedObjectModel` once, changed init to `NSPersistentContainer(name: "Pulse", managedObjectModel: Self.model)`.
- All 135 tests pass, CI pipeline green.

**IAP Setup in App Store Connect — COMPLETE:**
- Filled in missing metadata for `com.jpcostan.Pulse.pro.lifetime`: display name "Pulsio Pro", description, $5.99 pricing (all countries/regions), PaywallView screenshot, review notes.
- Status changed from "Missing Metadata" → "Ready to Submit".
- Sandbox purchase verified working on TestFlight Build 15.
- All 12 previously deferred manual tests now unblocked.

**Files Modified:**
- `Pulse/Persistence.swift` — Added static shared `NSManagedObjectModel`, changed container init

### Next Session: Phase 14 — App Store Submission

Phase 12 manual testing substantially complete (55+ tests passed, 0 failures). Remaining edge case/performance tests deferred to v2.0 based on user feedback.

**App Store Submission Checklist:**

1. **App Store Copy (App Store Connect → Distribution)**
   - [ ] App description (detailed, compelling — what the app does, key features, privacy)
   - [ ] Promotional text (170 chars, can be updated without new build)
   - [ ] Keywords (100 char limit, comma-separated, for search optimization)
   - [ ] Support URL (required)
   - [ ] Marketing URL (optional)
   - [ ] What's New text (for v1.0: can be brief)

2. **Screenshots (Required — App Store Connect → Media)**
   - [ ] 6.7" display (iPhone 16 Pro Max) — minimum 3, recommend 6-10
   - [ ] 6.5" display (iPhone 11 Pro Max / Xs Max) — required if supporting older devices
   - [ ] Capture key screens: Home, Recording, Action Review, Summary, Settings/Pro
   - [ ] Consider adding text overlays describing features

3. **App Review Information (App Store Connect → App Review)**
   - [ ] Review notes — explain how to test IAP (sandbox account credentials if needed)
   - [ ] Contact info for reviewer questions
   - [ ] Demo account (not needed — no login)

4. **Final Verification**
   - [ ] Privacy nutrition labels confirmed in App Store Connect (no data collected)
   - [ ] Export compliance (no encryption — already set)
   - [ ] Age rating (4+ — already set)
   - [ ] IAP product `com.jpcostan.Pulse.pro.lifetime` status "Ready to Submit"
   - [ ] Verify Info.plist has all required permission strings
   - [ ] Confirm build 15 is selected for submission (or upload new build if needed)

5. **Submit**
   - [ ] Review all fields one final time
   - [ ] Submit for App Review

**What Claude can help draft:** App description, promotional text, keywords, review notes.
**What requires Josh in App Store Connect:** Screenshots, uploading/selecting build, final submit button.

---

## Recent Session Summary (2026-02-26)

### Phase 12 Manual Testing — In Progress (Build 7 on TestFlight)

**Bugs Found & Fixed:**
1. **Paywall state stuck between recordings** — `.onReceive(audioService.$didHitFreeLimit)` fired with stale `true` from previous recording. Fix: added `&& hasStartedRecording` guard in RecordingView.swift:157.
2. **Live Activity stuck on Lock Screen after force-kill** — Added `cleanUpStaleLiveActivities()` in PulseApp.swift `init()` to end lingering activities on launch.
3. **Background auto-stop: timer reset to 0:00 and stale state (Build 6)** — When free tier 3-min auto-stop fired while app was backgrounded, `AVAudioRecorder.currentTime` returned 0/stale, and the `didHitFreeLimit` flag wasn't picked up by the UI. Fix: replaced `recorder.currentTime` with `Date`-based elapsed time tracking (`recordingStartDate` property in AudioRecordingService), and added foreground recovery logic in `handleAppDidBecomeActive` to re-publish `didHitFreeLimit`/`didAutoStop` flags so RecordingView transitions correctly.
4. **Silent recording cancel leaves orphaned meeting in "processing" status (Build 7)** — When a recording with no speech hit the "No speech detected" error in ProcessingView and user tapped Cancel, the meeting remained in Core Data with status "processing". Fix: Cancel button now deletes the audio file and the meeting from Core Data before navigating back to Home.

**Tests Completed:** Sections 1 (1.1–1.3 Pass), 3 (3.1–3.5 all Pass), 4 (in progress)
**Tests Deferred:** 12 tests requiring IAP (see checklist above)

---

## Recent Session Summary (2026-03-03)

### Phase 12 Manual Testing — Section 7 (Builds 13–14)

**Tests Completed:** Section 7 tests 7.1–7.6 all Pass.

**Bug Fix 6 — Speech recognition clipping first sentence in short recordings (Build 14):**
- **Problem:** During test 7.7, short recordings (~11s) consistently lost the first sentence from the transcript. Even with 3-second pauses and preamble, only the second sentence appeared. Affected all short recordings in Section 7 testing.
- **Root Cause:** For all recordings (including single-chunk ≤30s), the audio was re-exported via `AVAssetExportSession` with `AVAssetExportPresetAppleM4A` before being sent to the speech recognizer. AAC re-encoding introduces encoder delay (priming frames) and keyframe alignment issues at CMTime 0, which can clip the first ~1-2 seconds of audio. For short recordings, this was enough to lose the entire first sentence.
- **Fix:** In `TranscriptionService.swift`, single-chunk recordings (chunkCount == 1) now skip the export step entirely and pass the original audio file URL directly to `SFSpeechURLRecognitionRequest`. The export is only used when splitting longer recordings into time-ranged chunks. All 121 tests pass.

**Fix 7 — First-person "also" patterns (Build 14):**
- **Problem:** "I also need to send the report" didn't match the "I need to" pattern. Same issue previously fixed for team patterns ("we also need to") but never applied to first-person.
- **Fix:** Added optional "also" to first-person patterns in `ActionDetectionService.swift`: `"i (also )?need to "`, `"i (also )?have to "`, `"i (also )?should "`, `"i (also )?must "`.

**Test 7.7 — PASSED on Build 14.** Toggled off one item, created reminders + calendar. Only the included item appeared in Reminders and Calendar. Excluded item not synced. Section 7 complete.

**Bug Fix 8 — Meeting/appointment pattern false positive (Build 15):**
- **Problem:** During 7.7 testing, "All right so that meeting we went pretty well" was falsely detected at 75% confidence. Root cause: `meeting (on |at |this |next |)` pattern had an empty alternative `|)` that matched ANY sentence containing "meeting " regardless of context. Same bug on `appointment` pattern.
- **Fix:** Removed empty alternatives from `meeting` and `appointment` patterns in `ActionDetectionService.swift`. Added `with ` and `for ` as valid prepositions: `"meeting (on |at |this |next |with |for )"`. All 121 tests pass.

**Issue noted — Kevin's sentence not transcribed:** "Kevin should reach out to the design agency before Thursday" was not detected during 7.7 testing. Investigation confirmed the detection logic is correct (`\w+ should` + "thursday" task context). Likely a transcription issue — sentence at end of ~30s recording may not have been captured cleanly by SFSpeechRecognizer. No code fix needed.

**Tests 5.2/5.3 re-tested on Build 15 — both PASSED.** Casual conversation mentioning "meeting" and fictional story mentioning both "meeting" and "appointment" correctly filtered after pattern fix. No regressions.

**Unit test expansion (135 tests, up from 121):**
Added 14 new tests in `ActionDetectionTests.swift` covering bugs found during manual testing:
- Meeting/appointment false positives (4): `filtersMeetingMentionWithoutPreposition`, `filtersCasualMeetingReference`, `detectsMeetingWithPreposition`, `detectsMeetingForPreposition`
- First-person "also" patterns (3): `detectsIAlsoNeedTo`, `detectsIAlsoShouldWithTaskContext`, `detectsWeAlsoNeedTo`
- Mid-sentence negation (4): `filtersNotGoingToMidSentence`, `filtersWontNegation`, `filtersShouldntNegation`, `filtersDecidedNotTo`
- Third-person assignments (3): `detectsThirdPersonNeedsTo`, `detectsThirdPersonShould`, `filtersThirdPersonShouldWithoutTaskContext`

**Test Results:** Sections 1, 3, 4, 5, 6, 7 complete. 135 unit tests passing. Next: Complete IAP setup in App Store Connect, then resume manual testing at Section 8.

---

## Previous Session Summary (2026-03-02)

### Phase 12 Manual Testing — Sections 4, 5, 6 (Builds 8–12)

**Bug Fix 1 — Compound sentence splitting for action detection (Build 8):**
- **Problem:** Speech recognition often omits punctuation, producing long run-on sentences. `NLTokenizer(.sentence)` couldn't split them, so multiple action items in one recording were coalesced into a single detected action. During test 5.1, 3 distinct action items ("send the report by Friday", "schedule a follow-up meeting", "update the budget spreadsheet") were merged into 1.
- **Fix:** Added `splitCompoundSentence()` in `ActionDetectionService.swift` that runs after NLTokenizer. It splits sentences >80 chars at conjunction + subject + action verb boundaries (e.g., "and [Name] should", "we also need to", "we need to" mid-sentence).

**Bug Fix 2 — Missing third-person assignment patterns (Build 9):**
- **Problem:** Build 8 re-test of 5.1 showed the compound splitting was partially working (source text was shorter), but "Josh needs to send..." and "Sarah should update..." were still not detected as action items. Root cause: action patterns only covered first/second person ("I need to", "we need to", "you should") — no patterns for third-person "[Name] needs to / should / has to / must".
- **Fix:** Added 4 new third-person patterns in `ActionDetectionService.swift`: `\w+ needs to`, `\w+ should`, `\w+ has to`, `\w+ must` (all with `requiresTaskContext: true` to prevent false positives).

**Bug Fix 3 — "also" in team patterns + case-insensitive splitting (Build 10):**
- **Problem:** Build 9 re-test detected 2 of 3 items. "we also have to finalize the budget spreadsheet by Thursday" was missed because `"we have to "` pattern didn't match with "also" in between. Also, compound splitter wasn't splitting before "I need to" mid-sentence because regex was case-sensitive and speech recognition capitalizes "I".
- **Fix:** Made team patterns accept optional "also" (`"we (also )?have to "`, `"we (also )?need to "`, `"we (also )?should "`). Made compound sentence splitter use `.caseInsensitive` regex. Test 5.1 passed on Build 10 (3/3 items). Tests 5.2, 5.3 also passed.

**Bug Fix 4 — Negation filter too narrow (Build 11):**
- **Problem:** Test 5.4 on Build 10 — "I'm not going to schedule that meeting anymore" was falsely detected as an action item. The negation filter only checked for "don't/do not" at the start of a sentence, missing mid-sentence negations like "not going to", "won't", "shouldn't", etc.
- **Fix:** Expanded `isNegated()` to check for 16 negation phrases anywhere in the sentence: "not going to", "won't", "will not", "wouldn't", "shouldn't", "can't", "cannot", "decided not to", "no longer", "no need to", etc. All 121 tests pass.
- **Re-test required:** Test 5.4 needs re-testing on Build 11.

**Enhancement — Swipe-to-delete action items (Build 12):**
- **Problem:** During test 6.1, discovered users can add action items via "+" but have no way to delete them. Accidentally added or empty items are stuck.
- **Fix:** Added `.swipeActions(edge: .trailing, allowsFullSwipe: true)` on `ActionItemRow` in `ActionReviewView.swift`. Swipe left to delete, using existing Core Data save pattern (`viewContext.delete(item)` + `try? viewContext.save()`). 6.1 passed on Build 12.

**Bug Fix 5 — Edited title not used by Reminders/Calendar (Build 13):**
- **Problem:** During test 6.2, editing an action item's title and then tapping "Create Reminders" used the original title, not the edited one. Root cause: `saveTitle()` only fired on `onCommit` (pressing Return). If the user tapped away without pressing Return, the edit stayed in local `@State editedTitle` but was never written back to Core Data.
- **Fix:** Added `.onChange(of: titleFocused)` in `ActionItemRow` to call `saveTitle()` when the TextField loses focus. All 121 tests pass.

**Test Results:** Section 4 complete (4.1–4.3 Pass, 4.4 skipped, 4.5 Pass). Section 5 complete (5.1–5.8 all Pass). Section 6 complete (6.1–6.8 all Pass). Next: Section 7 (Reminders & Calendar).

---

## Recent Session Summary (2026-03-01)

### Phase 12 Manual Testing — Sections 1, 3, 4

**Bug Fix 1 — Background auto-stop stale state:**
- `AudioRecordingService.swift`: Added `recordingStartDate: Date?` property to track elapsed time independently of `AVAudioRecorder.currentTime` (which returns 0/stale in background)
- Timer callback now uses `Date().timeIntervalSince(startDate)` instead of `recorder.currentTime`
- `stopRecording()` calculates duration from `recordingStartDate`
- `handleAppDidBecomeActive` now re-publishes `didHitFreeLimit`/`didAutoStop` flags when auto-stop occurred while backgrounded, so RecordingView picks up the transition
- Also syncs `currentTime` from `recordingStartDate` on foreground return during active recording

**Bug Fix 2 — Orphaned meeting on silent recording cancel:**
- `ProcessingView.swift`: Cancel button on "Processing Error" alert now deletes the audio file via `AudioRecordingService.shared.deleteAudioFile(for:)` and deletes the meeting from Core Data before calling `onComplete()`

**Test Results:** Section 3 (Background & Live Activity) — 5/5 Pass. Section 4 (Transcription) — in progress.

---

## Previous Session Summary (2026-02-25)

### Phase 15 Codebase Cleanup & Phase 15.1 Naming Audit Complete

**Phase 15.0 — Debug Artifact Removal & NSLog Migration:**
- Removed debug NSLog/print statements from PulseApp.swift, ProcessingView.swift
- Removed debug transcript UI section from ActionReviewView.swift (Section + computed property)
- Migrated 13 NSLog calls → LoggingService (`Log.general`, `Log.audio`, `Log.reminders`) in StoreService, AudioRecordingService, RemindersService
- Added `import os` to 3 service files (required for `os.Logger` string interpolation)
- Deleted 3 unused widget template files (PulseWidgets.swift, PulseWidgetsControl.swift, AppIntent.swift)
- Updated PulseWidgetsBundle.swift to only register PulseWidgetsLiveActivity

**Phase 15.1 — Naming Audit:**
- Found and fixed 3 user-facing "Pulse" → "Pulsio" strings: HomeView nav title, StopMeetingIntent dialog, SettingsView Live Activity instructions
- Updated PulseUITests nav bar assertion to match
- All other naming items passed audit (CFBundleDisplayName, permissions, Siri phrases, bundle ID, IAP, URL scheme, app icon)

**Manual Testing Checklist:**
- Created `MANUALTESTING.md` in project root with 104 test cases across 18 sections
- Includes checkboxes, pass/fail columns, notes fields, and summary table

**Build & Tests:** All 121 tests pass, build succeeds

### To Resume
> "Read CLAUDE.md and prompt.md for project context. Phases 0-11, 13, 15, and 15.1 are complete. 121 tests passing with CI pipeline. Manual testing checklist ready at MANUALTESTING.md. Next: Phase 12 (Manual Testing on physical device), then Phase 14 (App Store Submission). The app is 'Pulse' internally but 'Pulsio' publicly — see Naming section."

---

## Previous Session Summary (2026-02-25)

### Phase 13 Unit Testing Complete — 121 Tests Passing

**Test Files Created (12 files):**
- `TestHelpers.swift` — shared `makeInMemoryContext()` and `makeMeeting()` utilities
- `ActionDetectionTests.swift` — 42 tests: patterns, two-tier system, negation, questions, false positives, dedup, confidence
- `DateParsingTests.swift` — 15 tests: explicit dates, relative, weekdays, ASAP, EOD, end-of-month, time-of-day
- `AudioRecordingServiceTests.swift` — 13 tests: constants, URL gen, formatted time, error descriptions
- `TranscriptionServiceTests.swift` — 11 tests: error descriptions, error equality, cancellation, initial state
- `CoreDataModelTests.swift` — 9 tests: entity creation, relationships, cascade delete, round-trip
- `PersistenceControllerTests.swift` — 4 tests: in-memory container, preview, merge policy, auto-merge
- `RecordingActivityAttributesTests.swift` — 4 tests: Codable round-trip, Hashable
- `IntentTests.swift` — 3 tests: singleton, default nil, observable
- `AudioPlaybackServiceTests.swift` — 6 tests: initial state, cleanup, errors, load non-existent
- `RemindersServiceTests.swift` — 6 tests: all error descriptions
- `StoreServiceTests.swift` — DELETED (`@Observable` types inaccessible from test target with MemberImportVisibility)

**Build/Config Fixes:**
- Added PulseTests target to scheme's TestAction with code coverage enabled
- Fixed TEST_HOST from `Pulse.app/Pulse` → `Pulsio.app/Pulsio` (Debug + Release)
- Changed all test files from `@testable import Pulse` → `@testable import Pulsio`
- Added explicit framework imports per MemberImportVisibility requirement

**Coverage:** ActionDetectionService 88.89%, Persistence 86.67%, overall app 24.61% (views untestable without UI tests)

**CI Pipeline Created:**
- `.github/workflows/tests.yml` — runs on every push, `macos-26` runner, Xcode 26.2, uploads test results artifact
- `.gitignore` updated with signing certs, secrets, test output, SPM artifacts

---

## Previous Session Summary (2026-02-24)

### Phase 11 Code Polish Complete

**Onboarding Flow:**
- Created `OnboardingView.swift` — 3-slide TabView (Welcome → How It Works → Get Started/Pro upgrade)
- `@AppStorage("hasCompletedOnboarding")` tracks first launch, presented as `.fullScreenCover` from PulseApp.swift
- Slide 3 has purchase button (StoreService integration) and "Continue for free" skip option

**Free-Mode UX:**
- Added orange capsule badge on RecordingView: "Free — 3 min limit" with clock icon
- Hidden for Pro users via `!StoreService.shared.isPro` check

**Permission Explanations:**
- Updated all 4 permission strings in project.pbxproj (Debug + Release) with privacy-first language
- Microphone: "Audio stays on your device and is never uploaded."
- Speech Recognition: "Pulsio transcribes your recordings entirely on-device... No audio is sent to the cloud."
- Reminders/Calendar: "...action items you choose to export. No data leaves your device."

**Error Handling Pass:**
- Fixed 7 silent `print()` failures → user-facing `.alert()` modifiers:
  - RecordingView: recording start failures (2 catch blocks)
  - HomeView: meeting creation (2 places) and deletion
  - MeetingDetailView: audio file load failure
  - SummaryView: audio file deletion failure

**iOS 26 Deprecation Fix:**
- Replaced `Text() + Text()` concatenation with string interpolation in PaywallView and OnboardingView

**Phase 15 Added:**
- Codebase Analysis phase added after Phase 14 — audit for dead code, debug artifacts, unused imports, and anything that shouldn't ship to production

---

## Older Session Summary (2026-02-23)

### First TestFlight Build Uploaded — Version 1.0 (3) ✅

**Pre-Upload Fixes:**
- Copied main app icon to widget extension `AppIcon.appiconset` (was empty)
- Bumped `CURRENT_PROJECT_VERSION` from 2 → 3 (main app + widget extension synced)
- Updated permission strings from "Pulse" → "Pulsio" to match `CFBundleDisplayName`
- Build verified clean

**App Store Connect Setup:**
- App name: "Pulsio" (because "Pulse" was taken — no technical impact)
- Subtitle: "Turn Meetings Into Actions"
- Category: Productivity | Pricing: Free (IAP monetized) | Age: 4+
- App Privacy: No data collected | Export Compliance: No encryption
- Internal TestFlight group created, build installed on device ✅

**Still TODO in App Store Connect:**
- Create IAP product `com.jpcostan.Pulse.pro.lifetime` ($5.99) — only exists locally in `Configuration.storekit`
- Fill out Distribution section (description, screenshots, keywords) — not needed for TestFlight

---

## Previous Session Summary (2026-02-19)

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
│   ├── PulseWidgetsBundle.swift    # Widget bundle registration (Live Activity only)
│   └── Info.plist
├── MANUALTESTING.md                # 104-test manual testing checklist for Phase 12
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

> "Read CLAUDE.md and prompt.md for project context. Phases 0-11, 13, 15, and 15.1 are complete. 121 tests passing with CI pipeline. Manual testing checklist ready at MANUALTESTING.md. Next: Phase 12 (Manual Testing on physical device), then Phase 14 (App Store Submission). The app is 'Pulse' internally but 'Pulsio' publicly — see Naming section."

---

## Naming: "Pulse" vs "Pulsio"

> **IMPORTANT:** "Pulse" was already taken on the App Store, so the app was renamed to **"Pulsio"** for public-facing purposes. This creates a split naming convention that must be kept consistent:

| Context | Name | Why |
|---------|------|-----|
| **App Store / Display Name** | **Pulsio** | `CFBundleDisplayName = Pulsio` — what users see |
| **Xcode Target Name** | **Pulsio** | The main app target is named "Pulsio" |
| **Swift Module Name** | **Pulsio** | Derived from target name → `import Pulsio` in tests |
| **Product (.app)** | **Pulsio.app** | Built product is `Pulsio.app` with executable `Pulsio` |
| **Bundle ID** | `com.jpcostan.Pulse` | Original bundle ID, kept as-is (not user-visible) |
| **Xcode Project** | `Pulse.xcodeproj` | Project file name, not changed |
| **Xcode Scheme** | `Pulse` | Build scheme name |
| **Core Data Model** | `Pulse.xcdatamodeld` | Model file name |
| **Source Folder** | `Pulse/` | Filesystem directory name |
| **Permission Strings** | "Pulsio records..." | User-facing strings use "Pulsio" |
| **Siri Phrases** | "...in Pulsio" | App Shortcuts use display name |
| **Test Target** | `PulseTests` | `@testable import Pulsio` (module is Pulsio) |
| **TEST_HOST** | `Pulsio.app/Pulsio` | Must match actual product name |

**Rule of thumb:** Internal/structural names stayed "Pulse". Anything user-facing or derived from the target name is "Pulsio". When writing tests, always use `@testable import Pulsio`.

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
- **Action Detection at Boundaries:** RESOLVED (2026-03-03). First sentence in short recordings was consistently lost. Root cause: `AVAssetExportSession` AAC re-encoding clipped the first ~1-2 seconds. Fix: single-chunk recordings (≤30s) skip export and use original audio file directly.
- **Chunk Concatenation:** Transcript chunks now joined with ". " to ensure proper sentence segmentation between chunks.
- **On-Device Model Required:** Transcription requires the on-device English speech recognition model to be downloaded. Users should go to Settings > General > Keyboard > Dictation and ensure the English language is downloaded for offline use.
- **Spelled-out Numbers:** Now supports "at nine" → "at 9" conversion for date parsing. Covers one-twelve, noon, midnight.
- **Siri Shortcuts NOT WORKING (2026-02-05):** Phase 8 code compiles and builds but "Hey Siri, start a meeting with Pulse" does not trigger the shortcut on physical device. Needs debugging. Check: shortcut registration, Siri phrase matching, Shortcuts app visibility, and whether `AppShortcutsProvider` is being picked up by the system.
- **Action Detection Over-Filtering RESOLVED (2026-02-17):** Previous false positive guards (title min 2 words) were too strict. Replaced with two-tier pattern system + stop-word title filter. Tested and working.
