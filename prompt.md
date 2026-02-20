I am building an iOS app called Pulse — Turn Meetings Into Actions.

I am a solo developer and will upload a PDF white paper that fully defines the product vision, scope, UX philosophy, architecture, and constraints.
Treat that white paper as the primary source of truth.

Your task is to help me implement this app step by step, keeping scope disciplined and aligned with Apple-native best practices.

App Overview

Pulse is a privacy-first iOS app that:

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

Permission explanations

Error handling

Performance pass

App Store copy and screenshots

Privacy disclosures

App Review checklist

Done when:
The app is ready for App Store submission.

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
