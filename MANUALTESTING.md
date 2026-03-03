# Pulsio Manual Testing Checklist

> **Tester:** Joshua Costanza
> **Device:** iPhone 16 Pro Max
> **iOS Version:** 26.3
> **App Version/Build:** v1.0 (4)
> **Date:** 02/26/2026

---

## How to Use This Checklist

1. Go through each test case on a **physical device** (many features don't work on simulator)
2. Check the box when you've performed the test
3. Mark **Pass** or **Fail** for each test
4. If failed, write a brief explanation in the **Notes** field
5. After completing all sections, review any failures and file bugs or fixes as needed

---

## 1. Recording Flow (Free Tier)

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 1.1 | Start a recording. Verify timer runs and audio level indicator animates. | [Pass] | Pass / Fail | |
| 1.2 | Let recording hit the 3-minute mark. Verify auto-stop occurs and paywall appears. Verify the 3-minute recording is saved. | [Pass] | Pass / Fail | |
| 1.3 | Dismiss paywall without purchasing. Verify the 3-min recording proceeds to processing normally. | [Pass] | Pass / Fail | |
| 1.4 | Purchase Pro from the paywall (use StoreKit sandbox). Verify Pro status updates immediately and the paywall sheet dismisses. | [SKIP] | Skipped | **DEFERRED** — IAP product not yet configured in App Store Connect (missing metadata). First paywall state bug was fixed in build 5. Will re-test after IAP setup is complete. |

---

## 2. Recording Flow (Pro Tier)

> Ensure you are in Pro mode (purchased or sandbox) before running these tests.
>
> **DEFERRED** — All Pro tier tests skipped until IAP is configured in App Store Connect. Will re-test after purchase flow works.

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 2.1 | Start recording and continue past 3 minutes. Verify no cutoff occurs. | [SKIP] | Skipped | DEFERRED — requires Pro purchase |
| 2.2 | Record until the 45-minute mark. Verify the duration warning alert appears. | [SKIP] | Skipped | DEFERRED — requires Pro purchase |
| 2.3 | Record until the 60-minute mark. Verify auto-stop with graceful save (recording is preserved). | [SKIP] | Skipped | DEFERRED — requires Pro purchase |
| 2.4 | Start a recording, then cancel it. Verify meeting is deleted from Home and audio file is cleaned up. | [ ] | Pass / Fail | Can test on Free tier (cancel before 3-min limit) |

---

## 3. Background Recording & Live Activity

> These tests require a **physical device**. Live Activities do not work on simulator.

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|

| 3.1 | Start recording, then lock the device. Wait 30+ seconds. Unlock and verify recording continued (timer advanced). | [Pass] | Pass / Fail | |

| 3.2 | Start recording, then switch to another app. Wait 30+ seconds. Return and verify recording continued. | [Pass] | Pass | Recording continued in background as expected. "No speech detected" error after processing is expected — no speech was recorded. |

| 3.3 | Start recording and lock the device. Verify the Live Activity timer updates on the Lock Screen. | [Pass] | Pass / Fail | |

| 3.4 | Tap the Live Activity on the Lock Screen. Verify deep link (`pulse://recording`) returns you to the active RecordingView. | [Pass] | Pass | Deep link navigated to RecordingView correctly. "No speech detected" after processing is expected — no speech was recorded. |

| 3.5 | End a recording while the app is in the background. Verify the Live Activity is dismissed. **Tested via option 2:** Started recording on Free tier, backgrounded the app before 3-min auto-stop, waited for auto-stop to fire while backgrounded. | [Pass] | Pass | Live Activity dismissed from lock screen when auto-stop fired. Returning to app correctly showed paywall. Fixed in Build 6 (Date-based timer tracking + foreground recovery logic). |

---

## 4. Transcription Pipeline

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|

| 4.1 | Make a short recording (< 30 seconds). Verify single-chunk transcription completes and text is reasonable. | [Pass] | Pass / Fail | |

| 4.2 | Make a longer recording (> 30 seconds). Verify multi-chunk transcription with correct ordering (no jumbled text). | [Pass] | Pass / Fail | Ended recording at 49 seconds |

| 4.3 | Check chunk boundaries — listen for words at ~30s mark and verify they appear in the transcript (2s overlap should prevent word loss). | [Pass] | Pass / Fail | |

| 4.4 | If the on-device speech model is NOT downloaded, verify a user-friendly error message guides you to Settings. (To test: remove the English offline model from Settings > General > Keyboard > Dictation.) | [ ] | Pass / Fail | | - Skipping for now. I am not sure how to unincstall an on-device speech model or if I even have it installed on my iphone ( I think I do but not sure).

| 4.5 | Record a completely silent clip (no speech). Verify graceful handling — no crash, empty or near-empty transcript. | [Pass] | Pass / Fail | | - Might wana re-test after build 7 though to make sure new changes work after clicking "cancel" - need to check status of the meeting in the list with no audio detected"" | re-tested and [Pass]

---

## 5. Action Detection

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|

| 5.1 | Record clear action items (e.g., "I need to send the report by Friday"). Verify they are detected in ActionReviewView. | [Pass] | Pass | **Build 10 PASS:** 3/3 action items detected (first-person 92%, team w/ "also" 88%, third-person 80%). Required 3 rounds of fixes: compound sentence splitting (Build 8), third-person patterns (Build 9), "also" support + case-insensitive splitting (Build 10). |

| 5.2 | Record a casual conversation with no action items. Verify the empty state ("No Action Items Detected") appears in ActionReviewView. | [Pass] | Pass | Casual chat about weather/park/coffee — no false positives, empty state displayed correctly. **Build 15 re-test PASSED:** Conversation mentioning "meeting" without preposition correctly filtered after pattern fix. |

| 5.3 | Read a poem or tell a fictional story. Verify no spurious action items are detected (false positive resistance). | [Pass] | Pass | Fictional story about a knight/dragon/princess — no false positives. **Build 15 re-test PASSED:** Story mentioning both "meeting" and "appointment" in narrative context correctly filtered after pattern fix. |

| 5.4 | Say negation phrases like "Don't call him" or "We decided not to send the report." Verify they are filtered out. | [Pass] | Pass | **Build 11 PASS:** All 4 negation phrases filtered correctly ("don't call", "decided not to send", "not going to schedule", "shouldn't bother"). Required expanded negation filter (Build 10→11). |

| 5.5 | Ask questions: "Should we do X?" should be filtered. "Can you send the report?" should be detected (request pattern). Verify both behaviors. | [Pass] | Pass | 2/4 detected correctly: "Can you send the report by Friday" and "Could you update the project timeline before Thursday" kept; "Should we reschedule?" and "Do you think we need more time?" filtered. |

| 5.6 | Say generic commitments WITH task context: "I'll schedule the meeting." Verify detected. | [Pass] | Pass | 2/3 detected: "I'll schedule the meeting" (92%) and "We should review the budget" (85%). "I'm going to send the invoice" missed — likely speech recognition transcription or splitting issue. Core behavior confirmed: generic patterns with task context are detected. |

| 5.7 | Say generic commitments WITHOUT task context: "I'll be fine." Verify filtered (not detected). | [Pass] | Pass | 7 generic commitment phrases without task context — all filtered correctly. Two-tier system working as intended. |

| 5.8 | Record multiple action items in a single recording. Verify all are detected and sorted by confidence (highest first). | [Pass] | Pass | 4/4 detected: "Submit expense report" (92%), "Book conference room" (92%), "Mike should prepare slides" (80%), "Email meeting notes" (80%). Sorted correctly by confidence, dates extracted properly. |

---

## 6. Action Review & Editing

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 6.1 | Tap the "+" toolbar button in ActionReviewView. Verify a new empty action item appears with the title field focused for typing. | [Pass] | Pass | Build 12: Add via "+" and swipe-to-delete both work correctly. Count updates after add/delete. |

| 6.2 | Edit an action item's title inline. Verify the change is saved (navigate away and return to confirm). | [Pass] | Pass | Build 13: Edited title, tapped away (no Return), title persisted. Created reminder with edited title — calendar showed updated title correctly. Auto-save on focus loss working. |

| 6.3 | Tap a date field — set a due date using the DatePicker. Verify the date is saved and displayed. | [Pass] | Pass | Changed date via DatePicker, tapped Done — updated date displayed correctly on the action item. |

| 6.4 | Open the DatePicker on an item with a date and tap "Remove Date." Verify the date is removed. | [Pass] | Pass | Date removed and reflected on Review Actions. **UX note:** "Remove Date" button hidden below DatePicker at medium sheet detent — requires scrolling/expanding sheet to find. Non-blocking. |

| 6.5 | Toggle an action item's include/exclude checkbox. Verify the state persists if you navigate away and return. | [Pass] | Pass | Unchecked an item, backgrounded app, returned — toggle state persisted. Count updated correctly. |

| 6.6 | Tap the expand chevron on an item with a source sentence. Verify the source sentence appears with animation. | [Pass] | Pass | Source sentence expands/collapses on chevron tap. |

| 6.7 | Verify action items are sorted by confidence (highest first). | [Pass] | Pass | Confirmed in test 5.8: 4 items sorted 92% → 92% → 80% → 80%. |

| 6.8 | Process a recording with no action items. Verify the "No Action Items Detected" empty state appears. | [Pass] | Pass | Empty state displayed correctly. Also confirmed in tests 5.2 and 5.3. |

---

## 7. Reminders & Calendar (EventKit)

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|

| 7.1 | Create reminders from included action items. Open the Apple Reminders app and verify they appear with correct titles. | [Pass] | Pass | Both action items appeared in Apple Reminders with correct titles. |

| 7.2 | Enable the "Also add to Calendar" toggle and create. Open the Calendar app and verify events appear on the correct due dates. | [Pass] | Pass | Both items appeared in Calendar app on correct due dates. |

| 7.3 | After creating reminders/events, verify sync status badges ("Synced to Reminders" / "In Calendar") appear on the action items. | [Pass] | Pass | Green reminders badge and blue calendar badge both visible on action items in MeetingDetailView. |

| 7.4 | Deny Reminders permission when prompted (or revoke in Settings). Verify a clear error message is shown. | [Pass] | Pass | Revoked Reminders permission via Settings > Apps > Pulsio. Error message shown: "Reminders access was denied, please enable it in Settings, Privacy, Security, Reminders." No crash. |

| 7.5 | Deny Calendar permission. Verify a clear error message is shown. | [Pass] | Pass | Revoked Calendar permission. Error message: "Calendar access was denied." No crash. |

| 7.6 | Include items WITHOUT due dates and create reminders. Verify no calendar event is created for them (only reminders). | [Pass] | Pass | 2 items created: one with date, one without. Both in Reminders. Only the dated item in Calendar. "Will add 1 item(s)" correctly shown. |

| 7.7 | Exclude (toggle off) action items, then create reminders. Verify excluded items are NOT synced. | [Pass] | Pass | Build 14: Toggled off one item, created reminders + calendar. Only the included item ("vendor comparison spreadsheet") appeared in Reminders and Calendar. Excluded item not synced. **Note:** "All right so that meeting we went pretty well" was a false positive at 75% — needs investigation. Also, third-person "Kevin should reach out..." was not detected — possible transcription issue. |

---

## 8. Monetization / StoreKit

> Use StoreKit sandbox/testing environment for purchase tests.

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 8.1 | Trigger the purchase flow (hit 3-min limit or tap Upgrade in Settings). Complete purchase. Verify `isPro` updates and paywall dismisses. | [SKIP] | Skipped | DEFERRED — IAP not configured in App Store Connect |
| 8.2 | Tap "Restore Purchases." Verify entitlement is restored and UI updates to Pro. | [SKIP] | Skipped | DEFERRED — IAP not configured |
| 8.3 | Kill the app and relaunch. Verify Pro status persists across launches. | [SKIP] | Skipped | DEFERRED — IAP not configured |
| 8.4 | With no network (airplane mode in sandbox), attempt product loading. Verify an error message is shown (not a crash). | [SKIP] | Skipped | DEFERRED — IAP not configured |
| 8.5 | Start a purchase and cancel (tap Cancel on the StoreKit sheet). Verify no state change — paywall remains, user stays Free. | [SKIP] | Skipped | DEFERRED — IAP not configured |
| 8.6 | As a Free user, open Settings. Verify it shows "Free" status and "Upgrade to Pro" button. | [ ] | Pass / Fail | Can test without IAP |
| 8.7 | As a Pro user, open Settings. Verify it shows "Pro — Lifetime" and no upgrade button. | [SKIP] | Skipped | DEFERRED — requires successful purchase |

---

## 9. Onboarding

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 9.1 | Delete and reinstall the app (or reset `hasCompletedOnboarding` in UserDefaults). Verify onboarding appears on first launch. | [ ] | Pass / Fail | |
| 9.2 | Swipe through all 3 onboarding slides. Verify content is correct and layout looks good. | [ ] | Pass / Fail | |
| 9.3 | On the final slide, tap the purchase button. Verify Pro status activates (sandbox). | [SKIP] | Skipped | DEFERRED — IAP not configured in App Store Connect |
| 9.4 | On the final slide, tap "Continue for free" / skip. Verify the app works in Free mode. | [ ] | Pass / Fail | |
| 9.5 | Launch the app a second time. Verify onboarding does NOT appear again. | [ ] | Pass / Fail | |

---

## 10. Settings

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 10.1 | As a Free user, open Settings. Verify "Free" status badge and "Upgrade to Pro" button are visible. | [ ] | Pass / Fail | |
| 10.2 | As a Pro user, open Settings. Verify "Pro — Lifetime" confirmation is shown and no upgrade button. | [SKIP] | Skipped | DEFERRED — requires successful purchase |
| 10.3 | Tap "Restore Purchases" in Settings. Verify it works (restores or shows "No previous purchase found"). | [SKIP] | Skipped | DEFERRED — IAP not configured |
| 10.4 | Verify the Live Activity section has instructional text about adding the Pulsio widget. | [ ] | Pass / Fail | |
| 10.5 | Verify the app version and build number are displayed and show correct values. | [ ] | Pass / Fail | |

---

## 11. Navigation & Flow

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 11.1 | Complete the full happy path: Home > Recording > Processing > Action Review > Summary > Home. Verify smooth transitions. | [ ] | Pass / Fail | |
| 11.2 | Cancel a recording mid-flow. Verify you return to Home and the meeting is deleted from the list. | [ ] | Pass / Fail | |
| 11.3 | Tap a past meeting in the Home list. Verify MeetingDetailView shows transcript, actions, and audio player. | [ ] | Pass / Fail | |
| 11.4 | Swipe to delete a meeting from the Home list. Verify it is removed from the list and Core Data. | [ ] | Pass / Fail | |
| 11.5 | Open the app via `pulse://recording` deep link (while a recording is active). Verify it navigates to RecordingView. | [ ] | Pass / Fail | |
| 11.6 | After reaching the Summary screen and tapping Done, verify clean navigation state — no stale views on the back stack. | [ ] | Pass / Fail | |

---

## 12. Audio Playback (MeetingDetailView)

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 12.1 | Open a completed meeting. Tap play. Verify audio plays and pause button appears. | [ ] | Pass / Fail | |
| 12.2 | Tap skip forward (15s) and skip backward (15s). Verify the playback position updates correctly. | [ ] | Pass / Fail | |
| 12.3 | Drag the seek slider to a new position. Verify playback jumps to the correct time. | [ ] | Pass / Fail | |
| 12.4 | Open a meeting where the audio file was deleted (user chose cleanup in Summary). Verify no crash — the audio section should be hidden or show a graceful message. | [ ] | Pass / Fail | |

---

## 13. Transcript Editing (MeetingDetailView)

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 13.1 | Tap "Edit" in the transcript section. Verify TextEditor fields appear for each chunk. | [ ] | Pass / Fail | |
| 13.2 | Modify text in a chunk, then tap "Done." Verify changes are saved to Core Data. | [ ] | Pass / Fail | |
| 13.3 | Navigate away from the meeting and return. Verify edits persisted. | [ ] | Pass / Fail | |
| 13.4 | Edit a multi-chunk transcript. Verify correct chunk order is maintained after editing. | [ ] | Pass / Fail | |

---

## 14. Data Persistence & Core Data

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 14.1 | Force-kill the app during processing (after transcription starts but before completion). Relaunch and verify partial data was saved (transcript chunks so far). | [ ] | Pass / Fail | |
| 14.2 | Complete a full recording flow. Force-kill and relaunch. Verify the meeting, transcript, and action items are all intact. | [ ] | Pass / Fail | |
| 14.3 | Open a completed meeting. Verify Core Data relationships are intact: Meeting has TranscriptChunks and ActionItems. | [ ] | Pass / Fail | |
| 14.4 | Verify TranscriptChunks are ordered by their `order` field (check that text flows correctly in MeetingDetailView). | [ ] | Pass / Fail | |
| 14.5 | After syncing to Reminders/Calendar, verify `reminderIdentifier` and `calendarEventIdentifier` are stored (re-opening the meeting should show sync badges). | [ ] | Pass / Fail | |

---

## 15. Edge Cases & Error Handling

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 15.1 | Deny microphone permission (Settings > Privacy > Microphone > Pulsio OFF). Try to record. Verify a clear error message directing to Settings. | [ ] | Pass / Fail | |
| 15.2 | Deny speech recognition permission (Settings > Privacy > Speech Recognition > Pulsio OFF). Process a recording. Verify a clear error message. | [ ] | Pass / Fail | |
| 15.3 | With battery < 20%, start a recording. Verify a warning is shown with a "Record Anyway" option. | [ ] | Pass / Fail | |
| 15.4 | With storage < 500MB free, start a recording. Verify a warning is shown with a "Record Anyway" option. | [ ] | Pass / Fail | |
| 15.5 | Receive a phone call during recording. Verify recording pauses/resumes or stops gracefully (no crash or data loss). | [ ] | Pass / Fail | |
| 15.6 | Unplug headphones during recording. Verify recording continues with the built-in microphone. | [ ] | Pass / Fail | |
| 15.7 | Make a very short recording (< 5 seconds). Verify transcription handles it gracefully. | [ ] | Pass / Fail | |
| 15.8 | Create a meeting with a very long title (50+ characters). Verify UI doesn't break or truncate poorly. | [ ] | Pass / Fail | |
| 15.9 | Tap stop immediately after starting a recording (rapid start/stop). Verify no crash or stale state. | [ ] | Pass / Fail | |
| 15.10 | Record with no speech (silence only). Verify empty transcript and no crash. | [ ] | Pass / Fail | |

---

## 16. Siri Shortcuts (If Working)

> Note: Siri shortcuts were implemented in Phase 8 but were not recognizing commands on device as of 2026-02-05. Test if they work now; if not, note the failure.

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 16.1 | Say "Start a meeting in Pulsio." Verify a meeting is created and RecordingView appears. | [ ] | Pass / Fail | |
| 16.2 | Say "Stop meeting in Pulsio." Verify the recording stops and the meeting is saved. | [ ] | Pass / Fail | |
| 16.3 | Start a meeting via Siri with a custom title (e.g., "Start a meeting called Budget Review in Pulsio"). Verify the title is applied. | [ ] | Pass / Fail | |
| 16.4 | Open the Shortcuts app. Verify Pulsio shortcuts are listed. | [ ] | Pass / Fail | |
| 16.5 | With no active recording, say "Stop meeting in Pulsio." Verify a graceful error dialog (not a crash). | [ ] | Pass / Fail | |

---

## 17. Performance & Stability

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 17.1 | Record for 10+ minutes. Monitor memory in Instruments (or observe app behavior). Verify no memory leaks or excessive usage. | [ ] | Pass / Fail | |
| 17.2 | Process a long recording (5+ minutes). Verify CPU usage is reasonable and device doesn't overheat noticeably. | [ ] | Pass / Fail | |
| 17.3 | Cold-launch the app. Verify it opens and is usable within 2 seconds. | [ ] | Pass / Fail | |
| 17.4 | During processing (transcription + action detection), verify the progress spinner animates smoothly — no UI freezes. | [ ] | Pass / Fail | |
| 17.5 | Create 10+ meetings in the Home list. Verify smooth scrolling. | [ ] | Pass / Fail | |
| 17.6 | Rapidly navigate between screens (Home > Detail > Back > Detail > Back). Verify no crashes. | [ ] | Pass / Fail | |

---

## 18. App Store Readiness

| # | Test | Done | Result | Notes |
|---|------|:----:|--------|-------|
| 18.1 | Verify all permission strings are present in Info.plist and clearly worded. | [ ] | Pass / Fail | |
| 18.2 | Verify privacy nutrition labels are accurate (microphone, speech recognition, no data collection). | [ ] | Pass / Fail | |
| 18.3 | Cold-launch the app 3 times. Verify no crashes on any launch. | [ ] | Pass / Fail | |
| 18.4 | Test on different screen sizes if possible (iPhone SE, standard, Pro Max). Verify no layout issues. | [ ] | Pass / Fail | |
| 18.5 | Verify the app icon renders correctly (Home Screen, Settings, multitasker). | [ ] | Pass / Fail | |
| 18.6 | Verify the launch screen displays properly (no blank screen or stale content). | [ ] | Pass / Fail | |

---

## Summary

| Section | Total | Passed | Failed | Skipped |
|---------|:-----:|:------:|:------:|:-------:|
| 1. Recording (Free) | 4 | | | |
| 2. Recording (Pro) | 4 | | | |
| 3. Background & Live Activity | 5 | | | |
| 4. Transcription | 5 | | | |
| 5. Action Detection | 8 | | | |
| 6. Action Review & Editing | 8 | | | |
| 7. Reminders & Calendar | 7 | | | |
| 8. Monetization / StoreKit | 7 | | | |
| 9. Onboarding | 5 | | | |
| 10. Settings | 5 | | | |
| 11. Navigation & Flow | 6 | | | |
| 12. Audio Playback | 4 | | | |
| 13. Transcript Editing | 4 | | | |
| 14. Data Persistence | 5 | | | |
| 15. Edge Cases | 10 | | | |
| 16. Siri Shortcuts | 5 | | | |
| 17. Performance & Stability | 6 | | | |
| 18. App Store Readiness | 6 | | | |
| **TOTAL** | **104** | | | |

### Critical Failures (Must Fix Before Submission)

_List any test failures that would block App Store submission:_

1.
2.
3.

### Non-Critical Issues (Can Ship With)

_List any minor issues that don't block submission:_

1.
2.
3.
