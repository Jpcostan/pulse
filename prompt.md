I am building an iOS app called Pulse — Turn Meetings Into Actions.

**IMPORTANT — Naming:** "Pulse" was taken on the App Store, so the app is publicly named **"Pulsio"**. The Xcode target name is "Pulsio", the Swift module is "Pulsio", and the built product is `Pulsio.app`. Internal/structural names (project file, scheme, Core Data model, source folders, bundle ID `com.jpcostan.Pulse`) still use "Pulse". Tests must use `@testable import Pulsio`. See CLAUDE.md "Naming: Pulse vs Pulsio" section for the full mapping.

I am a solo developer and will upload a PDF white paper that fully defines the product vision, scope, UX philosophy, architecture, and constraints.
Treat that white paper as the primary source of truth.

Your task is to help me implement this app step by step, keeping scope disciplined and aligned with Apple-native best practices.

App Overview

Pulse (marketed as "Pulsio") is a privacy-first iOS app that:

Records meetings (audio only)

Transcribes speech on device

Extracts action items and deadlines

Lets users review and edit those actions

Creates real Apple Reminders and Calendar events

Uses Live Activities while recording

Avoids chatbots and cloud dependency in the MVP

Pulse is not:

A transcription-first app

A chatbot

A team collaboration tool

A cloud SaaS

The core value is turning meetings into completed work with minimal friction.

Development Order (Do Not Reorder)

We will build the app in the following numbered phases.
Each phase is complete only when its “Done” criteria are met.

0) Project Setup

Create SwiftUI iOS project

Decide persistence layer (Core Data recommended)

Define core data models:

Meeting

TranscriptChunk

ActionItem

Done when:
The app launches and shows an empty Home screen.

1) UI Skeleton & Navigation

Build all core screens using placeholder data:

Home / Meetings list

Recording screen

Processing screen

Action Review screen

Summary screen

Use NavigationStack

No business logic yet

Done when:
The user can tap through the entire app flow using mock data.

2) Audio Recording (AVFoundation)

Start / stop recording

Save audio locally per meeting

Handle interruptions (calls, route changes)

Background recording if feasible

Done when:
Meetings can be reliably recorded and played back.

3) Transcription Pipeline (Speech Framework)

Request microphone + speech permissions

Implement chunked on-device transcription

Store transcript text locally per meeting

Provide a basic transcript debug view

Done when:
A real recording produces a usable stored transcript.

4) Action Engine

Sentence segmentation

Task candidate detection (rules + heuristics)

Basic date / deadline extraction

Confidence scoring and deduplication

Output structured ActionItem objects

Done when:
Typical meetings generate 3–10 reasonable action items.

5) Action Review UI

Display detected action items

Inline editing of titles

Due date picker

Toggle include / exclude

Expand to show source sentence

Done when:
Users can clean up tasks in under 30 seconds.

6) Reminders & Calendar Integration (EventKit)

Request permissions cleanly

Create Apple Reminders with:

Title

Notes

Due date

Optionally create Calendar events

Store EventKit identifiers

Done when:
“Create Reminders” reliably creates real system tasks.

7) Live Activities (ActivityKit)

Start Live Activity when recording begins

Show meeting title + timer on lock screen

End Live Activity when recording stops

Tapping returns to recording screen

Done when:
The lock screen accurately reflects active meetings.

8) Siri Shortcuts (App Intents)

"Start Meeting" shortcut

"Stop Meeting" shortcut

Optional meeting title parameter

Done when:
Recording can be controlled via Siri or Shortcuts.

9) Transcription & Action Item Refinement

Improve transcription accuracy and reliability

Enhance action item detection patterns

Add manual action item creation

Allow editing of transcript text

Improve date/deadline parsing

Add support for additional action phrases

Done when:
Transcription is robust and action detection covers common meeting language patterns.

10) Monetization (StoreKit 2)

Define Free vs Pro feature gates

Implement paywall screen

Restore purchases

Handle entitlements cleanly

Done when:
Feature gating and purchase restoration work correctly.

11) Polish & App Store Readiness

Onboarding flow (first-launch walkthrough with Pro purchase on final slide)

Free-mode UX indicator on RecordingView ("Free — 3 min limit")

Siri Shortcuts debugging (Phase 8 code compiles but doesn't work on device)

Permission explanations

Error handling

Performance pass

App Store copy and screenshots

Privacy disclosures

App Review checklist

Done when:
The app is ready for App Store submission.

12) Manual Testing

Comprehensive manual test pass covering every user-facing flow and edge case.
All scenarios documented below must be executed on a physical device.

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
- Chunk retry on failure → verify resilience
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

Done when:
All manual test scenarios pass on a physical device with no crashes or unexpected behavior.

13) Unit Testing (Swift Testing — 121 Tests) ✅ COMPLETE

Write XCTest unit tests in the PulseTests target covering service logic, data models,
and view model behavior. Use in-memory Core Data contexts for isolation. Target 70%+
line coverage across testable code.

**13.1 — ActionDetectionService Tests** (highest priority — 773 LOC)
- Test sentence segmentation: single sentence, multiple sentences, empty string
- Test each action pattern category: commitment phrases ("I'll send", "we should review"), request phrases ("can you", "please send"), task markers ("TODO:", "action item:"), deadline phrases ("due by Friday", "due tomorrow")
- Test two-tier pattern system: generic pattern WITH task context → detected; generic pattern WITHOUT task context → skipped
- Test hasTaskIndicators(): sentences with task verbs, task nouns, time indicators, digit+am/pm patterns
- Test negation filtering: "don't call him" → filtered; "don't forget to send" → NOT filtered (exception)
- Test question filtering: "Should we go?" → filtered; "Can you send the report?" → detected (request pattern)
- Test false positive guards: sentence < 3 words → filtered; sentence > 200 chars → filtered
- Test stop-word title filter: extracted title "see" → filtered; extracted title "call" → allowed
- Test confidence scoring: specific patterns score higher than generic patterns
- Test deduplication: duplicate sentences produce single action item
- Test date extraction: "by Friday" → next Friday date, "in 3 days" → correct date, "ASAP" → tomorrow, "end of month" → last day, "by 3pm" → correct time component
- Test spelled-out number conversion: "at nine" → "at 9", "noon" → "12", "midnight" → "12 AM"
- Test empty input: empty string → 0 actions, whitespace only → 0 actions
- Test Core Data integration: ActionItem entities created with correct fields (title, sourceSentence, confidence, dueDate, isIncluded)

**13.2 — TranscriptionService Tests**
- Test chunk calculation: 15s audio → 1 chunk, 45s audio → 2 chunks, 90s audio → 3 chunks
- Test chunk overlap: 30s chunk with 2s overlap → 28s stride
- Test progressive saving: verify TranscriptChunk entities saved per chunk
- Test chunk ordering: chunks saved with correct order field (0, 1, 2...)
- Test error handling: all chunks fail → throws allChunksFailed with message
- Test cancellation: cancel() sets flag, in-progress transcription stops
- Test permission request: authorization status mapping
- Test transcript text assembly: chunks joined with ". " separator

**13.3 — AudioRecordingService Tests**
- Test pre-recording validation: battery < 20% → returns error, storage < 500MB → returns error, both OK → returns nil
- Test free tier limit: StoreService.isPro = false → limit at 180 seconds; isPro = true → no limit
- Test formatted remaining time: 300s → "5:00", 65s → "1:05", 0s → "0:00"
- Test audio file URL generation: correct Documents/Recordings/{meetingID}.m4a path
- Test audio file existence check: file exists → true, file missing → false
- Test audio file deletion: file removed from disk, throws if file doesn't exist
- Test state reset: after stopRecording(), isRecording = false, currentTime = 0
- Test dismiss duration warning: showDurationWarning set to false

**13.4 — RemindersService Tests** (using mock EKEventStore where possible)
- Test authorization status updates: reflects EKEventStore auth status
- Test hasRemindersAccess computed property: authorized → true, denied → false, notDetermined → false
- Test hasCalendarAccess computed property: authorized → true, denied → false
- Test createReminders: creates correct number of reminders from included ActionItems
- Test createReminders skips excluded items: isIncluded = false → not synced
- Test createCalendarEvents: only creates events for items with due dates
- Test reminder identifier storage: reminderIdentifier saved to ActionItem after creation
- Test calendar event identifier storage: calendarEventIdentifier saved to ActionItem

**13.5 — AudioPlaybackService Tests**
- Test load: valid URL → duration > 0, isPlaying = false
- Test load: invalid URL → throws PlaybackError
- Test play/pause toggle: togglePlayPause flips isPlaying state
- Test stop: resets currentTime to 0, isPlaying = false
- Test seek: seek(to: 30) → currentTime = 30
- Test skip: skip(by: 15) → currentTime += 15; skip(by: -15) → currentTime -= 15
- Test skip bounds: skip past duration → clamped to duration; skip before 0 → clamped to 0
- Test cleanup: after cleanup, isPlaying = false, duration = 0

**13.6 — StoreService Tests** (using StoreKit Testing)
- Test initial state: isPro = false, product = nil
- Test loadProducts: products loaded from Configuration.storekit
- Test purchase flow: after purchase, isPro = true
- Test restore purchases: entitled transaction → isPro = true
- Test entitlement persistence: updateEntitlements reflects current state
- Test no entitlements: isPro remains false

**13.7 — Core Data Model Tests**
- Test Meeting creation: all fields populated correctly (id, title, createdAt, status)
- Test Meeting relationships: transcriptChunks and actionItems populated and accessible
- Test TranscriptChunk creation: id, text, startTime, endTime, order, meeting relationship
- Test TranscriptChunk ordering: fetched results sorted by order field
- Test ActionItem creation: id, title, sourceSentence, dueDate, isIncluded, confidence
- Test ActionItem defaults: isIncluded defaults based on confidence threshold
- Test cascade delete: deleting Meeting removes associated TranscriptChunks and ActionItems
- Test context save/fetch round-trip: save entities, re-fetch, verify all fields intact

**13.8 — Persistence Controller Tests**
- Test shared container loads: viewContext is not nil
- Test in-memory preview container: preview data contains 3 sample meetings
- Test merge policy: NSMergeByPropertyObjectTrumpMergePolicy is set
- Test automaticallyMergesChangesFromParent: enabled

**13.9 — RecordingActivityAttributes Tests**
- Test Codable conformance: encode → decode round-trip preserves all fields
- Test ContentState: elapsedSeconds and isRecording serialize correctly
- Test Hashable: equal attributes produce same hash

**13.10 — Intent Tests**
- Test StartMeetingIntent: sets MeetingIntentState.pendingMeetingTitle
- Test StartMeetingIntent default title: nil parameter → "Meeting"
- Test StopMeetingIntent: returns error dialog when no active recording
- Test MeetingIntentState: singleton pattern, pendingMeetingTitle observable

**13.11 — Date Parsing Tests (ActionDetectionService)**
- Test "by Friday" → next occurrence of Friday
- Test "next Monday" → next Monday from today
- Test "tomorrow" → today + 1 day
- Test "in 3 days" → today + 3 days
- Test "in 2 weeks" → today + 14 days
- Test "end of month" → last day of current month
- Test "ASAP" → tomorrow
- Test "by 3pm" → today at 15:00 (or tomorrow if past 3pm)
- Test "before noon" → today at 12:00
- Test "eod" / "end of day" → today at 17:00
- Test "on Monday" → next Monday with correct date
- Test no date in sentence → nil dueDate
- Test NSDataDetector dates: "March 15" → correct date object

**13.12 — Navigation & State Tests**
- Test HomeView meeting creation: new Meeting entity with auto-incremented title
- Test deep link URL parsing: "pulse://recording" → valid, "pulse://other" → ignored
- Test ProcessingView phase transitions: transcribing → detectingActions → complete
- Test ProcessingView progress calculation: transcription at 50% → overall 35%; action detection at 50% → overall 85%

Done when:
Unit tests achieve 70%+ line coverage on services and models. All tests pass in CI (xcodebuild test).

14) App Store Submission

Final submission to App Store Connect after all testing passes.

Done when:
App approved and live on the App Store.

15) Codebase Analysis & Naming Audit ✅ COMPLETE

Cleaned codebase for production readiness:
- Removed all debug NSLog/print statements and debug UI sections
- Migrated remaining NSLog calls to LoggingService (os.Logger)
- Deleted 3 unused widget template files
- Audited and fixed all user-facing "Pulse" → "Pulsio" naming issues
- Created MANUALTESTING.md with 104 test cases for Phase 12

Done when:
Codebase is clean and production-ready with no dead code or debug artifacts.

Constraints (Must Follow)

Apple-native frameworks only where possible

On-device processing for MVP

No cloud AI required

No chat UI

No overengineering

Professional, calm UX

Action-oriented, not note-oriented

Instructions

Default to the simplest correct solution

Explain implementation decisions when helpful

Ask clarifying questions only when necessary

Respect the development order above

Keep momentum — avoid perfectionism

The Pulse White Paper pdf is in the root of this project titled (Pulse_White_Paper_v1.pdf)

After reviewing it, begin with Phase 0: Project Setup.

Why this version works well for Claude

Clear structure (Claude excels at this)

Explicit constraints

No unnecessary role-play

Strong “do not reorder” guardrails

Concrete definitions of “done”

Encourages forward progress

When you’re ready, open Claude, paste this prompt, upload the PDF, and you’ll be in execution mode immediately.




1/24/26
- Read CLAUDE.md for project context and continuation. Previously Phase 4 and 5 were implemented, however, no action items were detected in the last test. Something is not working here and needs to be double checked to complete Phase 5 before contuing to Phase 6.
- "Read CLAUDE.md for project context, then continue with Phase
   6: Reminders & Calendar Integration (EventKit)"

1/25/26
- Was in the process of finishing Phase 5, but we also added some changes to allow entire recording/transcription of the entire recording be saved and stored so the user can view in MeetingDetailView. 
- The following tasks were being taken care of before running out of tokens:
 Tasks (4 done, 1 in progress, 0 open) · ctrl+t to hide tasks    
  ◼ #5 Add storage safeguards and audio cleanup option            
  ✔#1 Add recording safeguards (max duration, warnings, auto-stop)
                                                                  
                                                                  
  ✔ #2 Enable background audio recording                          
  ✔ #3 Implement chunked audio processing for transcription       
  ✔ #4 Add progressive transcript saving    
- #5 Add storage safeguards and audio cleanup option   STILL NOT FINISHED
- The following were safeguards to be implemented:
      Recording Safeguards                                            
  Safeguard: Max recording duration                               
  Recommendation: 60 minutes (configurable)                       
  ────────────────────────────────────────                        
  Safeguard: Warning alert                                        
  Recommendation: At 45 minutes ("Recording will auto-stop in 15  
    minutes")                                                     
  ────────────────────────────────────────                        
  Safeguard: Auto-stop                                            
  Recommendation: At 60 minutes with graceful save                
  ────────────────────────────────────────                        
  Safeguard: Low battery check                                    
  Recommendation: Warn if battery < 20% when starting             
  Processing Safeguards                                           
  Safeguard: Chunk size                                           
  Recommendation: 30 seconds of audio per chunk                   
  ────────────────────────────────────────                        
  Safeguard: Sequential processing                                
  Recommendation: One chunk at a time (limits memory)             
  ────────────────────────────────────────                        
  Safeguard: Progressive save                                     
  Recommendation: Save each transcript chunk as it completes      
  ────────────────────────────────────────                        
  Safeguard: Processing timeout                                   
  Recommendation: 5 minutes max for entire transcription          
  ────────────────────────────────────────                        
  Safeguard: Interruption handling                                
  Recommendation: Save whatever we have if app is killed          
  Storage Safeguards                                              
  Safeguard: Pre-record check                                     
  Recommendation: Warn if < 500MB free space                      
  ────────────────────────────────────────                        
  Safeguard: Audio cleanup                                        
  Recommendation: Option to delete audio after processing (keep   
    transcript)                                                   
  Questions for you:                                              
                                                                  
  1. Max duration: Is 60 minutes reasonable? Or would you prefer  
  30 min / 2 hours?                                               
  2. Auto-delete audio: Should we offer to delete the audio file  
  after successful processing to save space (keeping only the     
  transcript)?                                                    
  3. Background recording: If user leaves app, should recording   
  continue in background or pause?                                
                                                                  
  Let me know your preferences and I'll implement the chunked     
  processing with these safeguards.                               
                                                                  
❯ 1) 60 min is fine for now 2) yes 3) yes it should continu

1/29/26
## Session Summary

### Phase 6 COMPLETED: Reminders & Calendar Integration (EventKit)
- Created RemindersService.swift for EventKit integration
- Added permissions for Reminders and Calendar to Info.plist
- "Create Reminders" button now creates real Apple Reminders
- Optional toggle to also create Calendar events for items with due dates
- Sync status UI shows which items are synced to Reminders/Calendar
- SummaryView shows counts of reminders and calendar events created

### Transcription & Action Detection Improvements
- Fixed silent transcription failures - errors now properly surfaced
- Added better on-device model error handling with user-friendly messages
- Fixed deprecated AVAssetExportSession API warnings
- Fixed Sendable warnings in async closures
- Added patterns for "dont forget" (without apostrophe)
- Added patterns for "meeting on [day]", "appointment at [time]"
- Fixed chunk boundary issues - chunks now joined with ". " for proper sentence segmentation
- Added spelled-out number conversion ("at nine" → "at 9")
- Added standalone weekday detection ("on friday" extracts date)

### Logging System Overhaul
- Created LoggingService.swift using modern os.Logger API
- NSLog/print statements weren't appearing in Xcode console
- Use Console.app with filter `subsystem:com.jpcostan.Pulse` to view logs

### Current Issue Being Debugged
- Action items at beginning/end of recordings sometimes not detected
- Added debug transcript view in ActionReviewView to diagnose
- Need to test and check what the debug output shows

### What's Left
1. **Finish debugging action detection** - verify action items are reliably detected
2. **Phase 7: Live Activities (ActivityKit)** - show recording status on lock screen
3. **Phase 8: Siri Shortcuts (App Intents)** - voice control for recording
4. **Phase 9: Transcription & Action Item Refinement** - polish detection patterns
5. **Phase 10: Monetization (StoreKit 2)** - paywall and feature gates
6. **Phase 11: Polish & App Store Readiness** - final cleanup

### To Resume
> "Read CLAUDE.md for project context. We need to finish debugging action detection before moving to Phase 7."

2/03/26
## Session Summary

### Phase 7 STARTED: Live Activities (ActivityKit)

**Implementation Completed:**
- Created PulseWidgets extension target for Live Activities
- Implemented RecordingActivityAttributes.swift defining Live Activity data structure
- Created Live Activity UI for lock screen and Dynamic Island
- Integrated Live Activity lifecycle in RecordingView (start/update/end)
- Added deep linking to return to recording screen when tapping Live Activity
- Fixed action detection bug: lowered auto-include threshold from 0.80 to 0.75
- Clarified calendar toggle text in ActionReviewView

**Xcode Configuration Required (Build Currently Failing):**
Need to complete 3 manual configuration steps in Xcode:
1. Add NSSupportsLiveActivities to Info.plist (Boolean = YES)
2. Add URL Type for pulse:// scheme (Identifier: com.jpcostan.Pulse, Scheme: pulse, Role: Editor)
3. Add Push Notifications capability in Signing & Capabilities

**Files Created/Modified:**
- NEW: Pulse/RecordingActivityAttributes.swift
- MODIFIED: PulseWidgets/PulseWidgetsLiveActivity.swift
- MODIFIED: Views/RecordingView.swift (Live Activity management)
- MODIFIED: Views/HomeView.swift (deep linking)
- MODIFIED: Views/ActionReviewView.swift (toggle text clarity)
- MODIFIED: Services/ActionDetectionService.swift (auto-include threshold)

### Current Issue
- Build is failing due to Xcode configuration not properly set
- Need to verify all 3 configuration steps are correct

### To Resume
> "Read CLAUDE.md for project context. Phase 7 code is complete but build is failing. Need to fix Xcode configuration (NSSupportsLiveActivities, URL scheme, Push Notifications) and get a successful build for testing on physical device."

2/04/26
## Session Summary

### Phase 7 COMPLETED (Code): Live Activities Background Updates

**Critical Fix Implemented:**
Live Activity was appearing on lock screen but timer wasn't updating when device was locked. Refactored Live Activity management from RecordingView into AudioRecordingService so updates happen from the background audio timer.

**Changes Made:**
1. Moved Live Activity logic to AudioRecordingService
2. Live Activity updates now integrated with audio recording timer (runs in background)
3. Fixed all Swift 6 concurrency warnings
4. Fixed non-Sendable type warnings
5. Build successful

**Warnings Fixed:**
- Swift 6 concurrency: Reference to captured var 'self' - Fixed with proper [weak self] capture
- Non-Sendable type: Meeting capture in async closure - Fixed with objectID pattern
- Deprecated API warnings remain but don't affect functionality

**Testing Required (Next Session):**
MUST test on physical iPhone (Live Activities don't work in simulator):
1. Start recording
2. Lock device
3. **Verify timer continues updating on lock screen** (critical test)
4. Tap Live Activity to return to app
5. Verify recording continues in background

**Files Modified:**
- Services/AudioRecordingService.swift (Live Activity integration)
- Views/RecordingView.swift (removed duplicate code)
- Services/AudioPlaybackService.swift (concurrency fix)
- Services/TranscriptionService.swift (Sendable fix)

### Current Status
- Build: ✅ Successful
- Code: ✅ Complete
- Testing: ⏳ Pending (requires physical device)

### To Resume
> "Read CLAUDE.md for project context. Phase 7 implementation is complete and builds successfully. Need to test Live Activity on physical iPhone to verify timer updates when device is locked. If successful, proceed to Phase 8 (Siri Shortcuts)."

2/05/26
## Session Summary

### Phase 7 COMPLETED: Live Activities — Background Recording Fix
- Fixed UIBackgroundModes missing from built Info.plist (added directly as array)
- Removed .mixWithOthers from audio session (was preventing background recording)
- Changed timers to .common run loop mode for background reliability
- Live Activity now uses Text(startTime, style: .timer) for self-updating display
- ✅ Tested on physical device — background recording and lock screen timer working

### Phase 8 CODE COMPLETE: Siri Shortcuts (App Intents) — NOT WORKING
- Created StartMeetingIntent, StopMeetingIntent, PulseShortcuts, MeetingIntentState
- AudioRecordingService converted to shared singleton
- HomeView observes intent state for Siri-triggered meeting starts
- Build succeeds ✅
- ❌ **SIRI NOT WORKING**: "Hey Siri, start a meeting with Pulse" did NOT trigger the shortcut on physical device. Needs debugging before Phase 8 can be marked complete.

### To Resume
> "Read CLAUDE.md for project context. Phases 0-7 are complete. Phase 8 (Siri Shortcuts) code is written but Siri does not recognize the commands on device. Debug Siri shortcut registration before proceeding to Phase 9."

02/13/26
## Session Summary

### Phase 9 CODE COMPLETE: Transcription & Action Item Refinement — NEEDS MORE TESTING

**What was implemented:**
- ActionDetectionService: 17 new patterns (intent phrases, task markers, phrasal verbs, deadline indicators), negation detection, question filtering, improved date parsing ("in X days", "ASAP", "end of month", time-of-day like "by 3pm")
- TranscriptionService: 2-second chunk overlap to prevent word loss at boundaries, 1 retry per failed chunk with 500ms delay
- ActionReviewView: "+" button for manual action creation, date picker sheet with graphical DatePicker + time
- MeetingDetailView: Edit/Done toggle for editable transcript chunks, saves to Core Data

**Testing Results:**
- Test 1 (action item → poem → action item): Detected 2 real actions ✅ but also 2 false positives ❌ — the word "see" (90% confidence, likely from "I'll see" prefix removal leaving just "See") and entire poem text (82% confidence, poem contained an action-like word such as "let's" or "remember")
- Fix applied: Added false positive guards — sentence must be 3-200 words, extracted title must be 2+ words
- Test 2 (same format after fix): False positives eliminated ✅ but only detected 1 of 2 real action items ❌ — may be over-filtering or transcription boundary issue

**⚠️ MUST do additional testing before proceeding to Phase 10 (Monetization / StoreKit 2)**
- Need to verify if the missing action item was not transcribed or was incorrectly filtered out
- Check Console.app logs (subsystem:com.jpcostan.Pulse) to diagnose
- May need to adjust length thresholds if over-filtering is confirmed

### Files Modified This Session
- Services/ActionDetectionService.swift (patterns, negation, question filtering, date parsing, length guards)
- Services/TranscriptionService.swift (chunk overlap, retry logic)
- Views/ActionReviewView.swift (manual creation, date picker)
- Views/MeetingDetailView.swift (editable transcript)

### To Resume
> "Read CLAUDE.md for project context. Phase 9 code is complete but needs more testing — last test only detected 1 of 2 action items. Must diagnose and fix before proceeding to Phase 10."

2/17/26
## Session Summary

### Phase 9 COMPLETED: Action Detection False Positive Fix — TESTED & WORKING ✅

**Problem:** Action detection was picking up poem/narrative lines as false positives (90% confidence) while sometimes missing real action items.

**Root Cause:** Generic commitment patterns like "I'll", "I will", "we should", "let's" matched ANY sentence starting with those phrases — including poetry and narrative text.

**Fix: Two-Tier Pattern System with Task Context Validation**
- Split all action patterns into two tiers via `requiresTaskContext` flag:
  - **Generic patterns** (i'll, we should, let's, i must, etc.) → require the sentence to ALSO contain a task verb, task noun, or time reference
  - **Specific patterns** (^send, follow up, due by, meeting, don't forget, etc.) → pass through directly
- Added `hasTaskIndicators()` method checking against ~60 task verbs, ~30 task nouns, ~20 time indicators, and time patterns (digits + am/pm)
- Generic patterns that fail task context `continue` to next pattern instead of rejecting the sentence

**Additional Fixes This Session:**
- Relaxed title minimum from 2 words to 1 word (stop-word check instead) — fixes over-filtering of legitimate short actions like "Call" from "I need to call"
- Added diagnostic logging for every filter reason (FILTERED/SKIPPED with specific cause)
- Added "due at" pattern alongside "due by"
- Added "due today/tonight/tomorrow" pattern
- Added "i have a meeting/homework/appointment" patterns
- Improved debug transcript view with chunk timing, detected actions summary
- Reverted experimental chunk deduplication code (was risky/untested)

**Testing Results:**
- Test 1: Detected both real action items ✅, no poem false positives ✅
- Phase 9 can now be considered COMPLETE

### Git Repo Consolidation
- Removed nested `.git` inside `Pulse/` directory (was a separate repo from Xcode init)
- All files now tracked individually by the outer `pulse/` repo
- Added `.gitignore` (excludes .DS_Store, xcuserdata, DerivedData, .claude/)
- Pushed all 49 files to GitHub: https://github.com/Jpcostan/pulse.git

### To Resume
> "Read CLAUDE.md for project context. Phases 0-9 are complete and tested. Phase 8 (Siri) code is written but not working on device. Ready for Phase 10 (Monetization / StoreKit 2)."

2/19/26
## Session Summary

### Phase 10 COMPLETED: Monetization (StoreKit 2) ✅

**Implementation:**
- Created `StoreService.swift` — `@MainActor @Observable` singleton using StoreKit 2 async APIs (Product.products, Transaction.currentEntitlements, Transaction.updates)
- Created `PaywallView.swift` — presented as sheet when free user hits 3-minute limit; shows branding, features, $5.99 purchase button, restore link
- Created `SettingsView.swift` — account status (Free/Pro), upgrade button, restore purchases, Live Activity guide, app version/build
- Created `Configuration.storekit` — local StoreKit testing config for simulator/sandbox testing
- Modified `AudioRecordingService.swift` — added 3-minute free limit check in timer callback, `didHitFreeLimit` published property
- Modified `RecordingView.swift` — observes `didHitFreeLimit`, presents PaywallView sheet, handles auto-stop gracefully
- Modified `HomeView.swift` — added gear icon toolbar button for Settings navigation
- Modified `PulseApp.swift` — initializes StoreService.shared at launch for early entitlement loading
- Set `Configuration.storekit` as StoreKit Configuration in Xcode scheme (Run > Options)

**Build & Testing:**
- ✅ Build successful
- ✅ StoreKit sandbox purchase tested and working on device
- StoreKit config must be set via Xcode UI (Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration)

**Phase 11 & 12 Planned:**
- Phase 11: Polish & App Store Readiness — onboarding flow with purchase on last slide, free-mode UX indicator, Siri debugging, performance pass, App Store assets
- Phase 12: Comprehensive end-to-end testing (17 test categories covering every flow, edge case, and integration)

### To Resume
> "Read CLAUDE.md for project context. Phases 0-10 are complete and tested. Phase 8 (Siri) code is written but not working on device. Ready for Phase 11 (Polish & App Store Readiness), then Phase 12 (End-to-End Testing)."

2/23/26
## Session Summary

### First TestFlight Build Uploaded — Version 1.0 (3) ✅

**Pre-Upload Fixes:**
- Copied main app icon to widget extension `AppIcon.appiconset` (was empty/placeholder)
- Bumped `CURRENT_PROJECT_VERSION` from 2 → 3 (synced main app + widget extension)
- Updated all 4 permission strings from "Pulse" → "Pulsio" to match `CFBundleDisplayName` (avoids App Review flags)
- Build verified clean ✅

**TestFlight Upload:**
- Archived via Xcode (Product → Archive)
- Distributed via "App Store Connect" method
- Export Compliance: No encryption — answered "No"
- Build processed successfully, status: "Ready to Submit"
- Added internal testing group, accepted TestFlight invite, installed on device ✅

**App Store Connect Setup (Partial — enough for TestFlight):**
- App name: "Pulsio" (because "Pulse" was taken — no technical issues from this)
- Subtitle: "Turn Meetings Into Actions"
- Bundle ID confirmed: `com.jpcostan.Pulse`
- Category: Productivity
- Pricing: Free (monetized via IAP)
- App Privacy: No data collected (all on-device processing)
- Age Rating: All Ages / 4+
- Content Rights, Parental Controls, Web Access, UGC, Messaging, Advertising: all N/A or No

**Still TODO in App Store Connect (before App Store submission):**
- Create IAP product `com.jpcostan.Pulse.pro.lifetime` ($5.99 non-consumable) — currently only exists in local `Configuration.storekit`
- Fill out Distribution section (description, screenshots, keywords) — not needed for TestFlight
- App icon shows in TestFlight but not in main ASC listing (normal — populates after attaching build to a version for review)

### To Resume
> "Read CLAUDE.md and prompt.md for project context. First TestFlight build (1.0 build 3) is uploaded and installable. Phases 0-10 complete. Ready for Phase 11 (Polish & App Store Readiness)."

2/24/26
## Session Summary

### Phase 11 Code Polish — Complete

**Onboarding Flow (OnboardingView.swift — NEW):**
- 3-slide TabView with PageTabViewStyle: Welcome → How It Works → Get Started (Pro upgrade)
- `@AppStorage("hasCompletedOnboarding")` persists first-launch state in UserDefaults
- Presented as `.fullScreenCover` from PulseApp.swift — only shows on first launch
- Slide 3: Purchase button (StoreService.shared), "Continue for free" skip — both dismiss and set flag

**Free-Mode UX (RecordingView.swift):**
- Orange capsule badge: clock icon + "Free — 3 min limit"
- Hidden for Pro users (`!StoreService.shared.isPro`)

**Permission Explanations (project.pbxproj):**
- All 4 strings rewritten with privacy-reassuring language
- Microphone: "Audio stays on your device and is never uploaded."
- Speech Recognition: "...entirely on-device... No audio is sent to the cloud."
- Reminders/Calendar: "...action items you choose to export. No data leaves your device."

**Error Handling Pass (4 files, 7 fixes):**
- RecordingView: 2 silent `print()` catch blocks → error alert with `error.localizedDescription`
- HomeView: meeting create (2 places) and delete → "Failed to [create/delete] meeting" alerts
- MeetingDetailView: audio load failure → "Failed to load the audio recording" alert
- SummaryView: audio delete failure → "Failed to delete the audio file" alert

**iOS 26 Deprecation Fix:**
- `Text() + Text()` → string interpolation in PaywallView and OnboardingView

**Phase 15 Added:**
- Codebase Analysis phase — audit for dead code, debug artifacts, unused files before App Store deploy

### Phase 11 Remaining (non-code / deferred)
- Siri Shortcuts debugging (deferred)
- Performance profiling (requires Instruments)
- App Icon & Launch Screen (design assets needed)
- App Store Copy & Screenshots (App Store Connect)
- Privacy Disclosures (App Store Connect)
- App Review Checklist

### To Resume
> "Read CLAUDE.md and prompt.md for project context. Phases 0-11 and 13 complete. 121 unit tests passing with CI pipeline on GitHub Actions. Ready for Phase 12 (Manual Testing), Phase 14 (App Store Submission), or Phase 15 (Codebase Analysis + 15.1 Naming Audit)."

2/26/26
## Session Summary

### Phase 12 Manual Testing — In Progress (Build 5 on TestFlight)

**Bugs Found & Fixed:**
1. **Paywall state stuck between recordings** — `.onReceive(audioService.$didHitFreeLimit)` fired with stale `true` value from previous recording before `startRecording()` could reset it. Fix: added `&& hasStartedRecording` guard in RecordingView.swift:157.
2. **Live Activity stuck on Lock Screen after force-kill** — `endLiveActivity()` never called when app is killed. Fix: added `cleanUpStaleLiveActivities()` in PulseApp.swift `init()` that ends all lingering `RecordingActivityAttributes` activities on launch.

**Tests Completed:** 1.1 (Pass), 1.2 (Pass), 1.3 (Pass)
**Tests Deferred (IAP not configured):** 1.4, 2.1-2.3, 8.1-8.5, 8.7, 9.3, 10.2, 10.3

### App Store Connect — IAP Setup Required

The in-app purchase product `com.jpcostan.Pulse.pro.lifetime` was created in App Store Connect but has status "Missing Metadata". It must be fully configured before purchase-related tests can run on TestFlight. See the checklist below.

---

## App Store Connect IAP Setup Checklist

The following steps must be completed in App Store Connect to make the Pro Lifetime in-app purchase work in TestFlight sandbox.

### Step 1: Complete IAP Metadata (App Store Connect > Monetization > In-App Purchases)

Open the `com.jpcostan.Pulse.pro.lifetime` product and fill in:

| Field | Value |
|-------|-------|
| **Reference Name** | Pro Lifetime |
| **Product ID** | `com.jpcostan.Pulse.pro.lifetime` (already set) |
| **Type** | Non-Consumable (already set) |
| **Price** | $5.99 (Price Tier — select from price schedule) |
| **Display Name** (Localization > English) | Pulsio Pro |
| **Description** (Localization > English) | Unlock unlimited recording time. Record meetings up to 60 minutes with a one-time purchase. All processing stays on your device. |
| **Screenshot** | Take a screenshot of the PaywallView on device (showing the purchase UI). Must be at least 640x920 pixels. |
| **Review Notes** | This is a one-time non-consumable purchase that removes the 3-minute recording limit for free users, allowing recordings up to 60 minutes. |

### Step 2: Set Up Pricing (App Store Connect > Monetization > In-App Purchases > Pricing)

- Click "Add Pricing" or "Set Price"
- Select **$5.99** (USD) as the base price
- Apple will auto-calculate international prices — review and confirm

### Step 3: Link IAP to App Version (App Store Connect > App > Your App Version)

- Go to your app's version page (the one with build 5)
- Scroll to **"In-App Purchases and Subscriptions"** section
- Click the **"+"** button to add the IAP
- Select `com.jpcostan.Pulse.pro.lifetime`
- This links it to the version for review submission

### Step 4: Verify Status

After completing all metadata, the IAP status should change from "Missing Metadata" to **"Ready to Submit"**.

### Step 5: Test on TestFlight

- Install the latest TestFlight build (build 5+)
- The IAP should now load in sandbox mode
- Test purchasing from both the paywall (3-min limit) and Settings > Upgrade to Pro
- Use a sandbox Apple ID for testing (Settings > App Store > Sandbox Account on device)

### After IAP Works — Resume Deferred Tests

Once the purchase works in TestFlight sandbox, run these deferred tests:
- **1.4** — Purchase Pro from 3-min paywall
- **2.1-2.3** — Pro recording (past 3 min, 45-min warning, 60-min auto-stop)
- **8.1-8.5, 8.7** — Full StoreKit test suite
- **9.3** — Onboarding purchase button
- **10.2, 10.3** — Pro Settings view, restore purchases

---

3/2/26
## Session Summary

### Phase 12 Manual Testing — Continued (Builds 8–12)

**Bugs Found & Fixed:**
1. **Action items coalescing into one (Build 7→8)** — During test 5.1, spoke 3 distinct action items but only 1 was detected. Root cause: speech recognition produced unpunctuated run-on text, and `NLTokenizer(.sentence)` treated it as a single sentence, so only one pattern matched. Fix: added `splitCompoundSentence()` in `ActionDetectionService.swift` — a post-processor that splits sentences >80 chars at conjunction + subject + action verb boundaries.
2. **Third-person assignments not detected (Build 8→9)** — Build 8 re-test showed compound splitting partially worked (source text was shorter), but "Josh needs to send..." and "Sarah should update..." still not detected. Root cause: action patterns only covered first/second person ("I need to", "we need to", "you should") — no patterns for "[Name] needs to / should". Fix: added 4 third-person patterns (`\w+ needs to`, `\w+ should`, `\w+ has to`, `\w+ must`) with `requiresTaskContext: true`.
3. **"also" breaking team patterns + case-sensitive splitting (Build 9→10)** — Build 9 re-test detected 2 of 3 items. "we also have to finalize..." missed because `"we have to "` didn't match with "also" in between. Compound splitter also missed mid-sentence "I need to" due to case sensitivity. Fix: team patterns now accept optional "also" (`"we (also )?have to "`), and compound splitter uses `.caseInsensitive` regex. Test 5.1 passed Build 10 (3/3). Tests 5.2, 5.3 also passed.
4. **Negation filter too narrow (Build 10→11)** — Test 5.4: "I'm not going to schedule that meeting anymore" falsely detected. Negation filter only checked "don't/do not" at sentence start. Fix: expanded `isNegated()` with 16 mid-sentence negation phrases ("not going to", "won't", "shouldn't", "can't", "decided not to", "no longer", etc.). All 121 tests pass. Section 5 complete (5.1–5.8 all Pass).

**Enhancement:**
5. **Swipe-to-delete action items (Build 12)** — During test 6.1, discovered users can add items via "+" but have no way to delete them. Fix: added `.swipeActions` on ActionItemRow in ActionReviewView.swift. Swipe left to delete from Core Data.

6. **Edited title not used by Reminders/Calendar (Build 12→13)** — During test 6.2, editing a title and tapping "Create Reminders" used the original title. `saveTitle()` only fired on Return key, not on focus loss. Fix: added `.onChange(of: titleFocused)` to call `saveTitle()` when TextField loses focus. All 121 tests pass.

**Test Results:** Sections 4, 5, 6 complete. Next: Section 7 (Reminders & Calendar).

### To Resume
> "Read CLAUDE.md, prompt.md, MEMORY.md and MANUALTESTING.md for project context. Phase 12 manual testing is in progress — Build 13 on TestFlight. Sections 1, 3, 4, 5, 6 complete. Next: Section 7 (Reminders & Calendar). IAP setup in App Store Connect must be completed before purchase-related tests can run. Continue manual testing on non-purchase tests, then circle back to deferred tests after IAP is configured."

3/3/26
## Session Summary

### Phase 12 Manual Testing — Section 7, Continued (Builds 13–14)

**Section 7 progress:** Tests 7.1–7.6 all Pass. Test 7.7 blocked by transcription clipping bug, needs re-test on Build 14.

**Bugs Found & Fixed:**
1. **Speech recognition clipping first sentence in short recordings (Build 13→14)** — During test 7.7, short recordings (~11s) consistently lost the first spoken sentence from the transcript. Root cause: `TranscriptionService` re-exported ALL recordings through `AVAssetExportSession` before sending to the speech recognizer, even single-chunk recordings (≤30s) that didn't need splitting. AAC re-encoding introduces encoder delay and keyframe alignment issues at CMTime 0, clipping the first ~1-2 seconds. Fix: single-chunk recordings now skip the export and pass the original audio file directly to `SFSpeechURLRecognitionRequest`. Multi-chunk exports still work as before.
2. **First-person "also" patterns missing (Build 14)** — "I also need to send the report" didn't match the `"i need to "` pattern. Same issue previously fixed for team patterns ("we also need to") but never applied to first-person. Fix: added optional "also" to first-person patterns: `"i (also )?need to "`, `"i (also )?have to "`, `"i (also )?should "`, `"i (also )?must "`.

**Files Modified:**
- `Services/TranscriptionService.swift` — Skip AVAssetExportSession for single-chunk recordings
- `Services/ActionDetectionService.swift` — First-person "also" optional in patterns

**Test 7.7 — PASSED on Build 14.** Excluded items not synced to Reminders or Calendar. Section 7 complete.

**Additional fix (Build 15):**
3. **Meeting/appointment pattern false positive** — "All right so that meeting we went pretty well" falsely detected at 75%. The `meeting (on |at |this |next |)` pattern had an empty alternative matching ANY "meeting " occurrence. Fix: removed empty alternatives from `meeting` and `appointment` patterns, added `with ` and `for ` as valid prepositions. Same issue didn't exist on `call` pattern (already had no empty alternative). All 121 tests pass.

**Files Modified:**
- `Services/ActionDetectionService.swift` — Removed empty regex alternatives from meeting/appointment patterns

**Test Results:** All 121 tests pass. Build succeeds. Sections 1, 3, 4, 5, 6, 7 complete. Tests 5.2/5.3 should be re-verified on Build 15 as regression check after meeting pattern change.

### To Resume
> "Read CLAUDE.md, prompt.md, MEMORY.md and MANUALTESTING.md for project context. Phase 12 manual testing is in progress — Build 15 on TestFlight. Sections 1, 3, 4, 5, 6, 7 complete. Re-test 5.2/5.3 on Build 15 as false-positive regression check after meeting pattern fix. Next: Section 8 (Monetization — mostly deferred pending IAP setup), then Sections 9+. IAP setup in App Store Connect must be completed before purchase-related tests can run."
