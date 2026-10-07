# Names

One name per thing, used in conversation, commit messages, release notes and code.
The point is that "the rectangular box", "the note popup" and "the card" stop being
three names for one thing.

## The floating pieces

| Name | What it is | In code |
|---|---|---|
| **the pill** | The floating capsule. Always the whole window *and* the capsule drawn in it; say "the capsule" only when the distinction matters (the window is 320×60, the capsule ~56×28). | `PillWindow`, `PillContent` |
| **the note card** | What the pill becomes while dictating into a note: 292×124, destination, live words, elapsed, meter. Not "popup", "box", or "rectangle". | `NoteCaptureBox` → rename to `NoteCard` |
| **the hands-free button** | The record ring the pill reveals on hover, and the stop square it becomes while latched. | `HandsFreeRevealButton` |
| **the companion** | The animated character. Its own window, its own saved position. Never "the pet" or "the mascot". | `CompanionWindow` |
| **a character** | One companion design - Panda, Golden Dog, Pixel Cat (Ginger), Pixel Cat (Gray). | `SpritePack` |
| **a pack** | The folder of art that supplies a character. | `SpritePack`, `Companions/<id>/` |
| **a pose** | One drawn state of a character: `resting`, `alert`, `thinking`, `delighted`, `startled`, `sleepy`. | `CompanionMood`, `CompanionPose` |

## The windows

| Name | What it is | In code |
|---|---|---|
| **the Utter window** | The main window, opened from the menu bar or a long press on the pill. Not "the app window" or "the dashboard". | `FlowSidebar` + `FlowContent` |
| **Settings** | The separate settings window. Its sections are **panes** (General, Speech, Appearance, Privacy, Diagnostics, About). | `SettingsSidebar` + `SettingsDetail` |
| **setup** | The seven-step first-run flow. Not "onboarding" in anything user-facing; "onboarding" is fine in code. | `OnboardingView` |
| **the menu bar item** | The status item and its menu. | `StatusBarController` |

## The three ways to dictate

Each has exactly one name. The distinction is *how it ends*, and that is the part
that gets muddled.

| Name | Gesture | Ends when |
|---|---|---|
| **push-to-talk** | Hold the hotkey (default Fn) | You release |
| **hands-free** | ⌃⌥Space, or hold the hotkey and tap Space, or click the pill's record button | You press again, click stop, or stop talking for 3s |
| **note dictation** | ⌃⌥N | Same, and the text goes to a note rather than the frontmost app |

"Recording" is the *act*; the pill's `.recording` state means push-to-talk
specifically. Say which one.

## Notes and meetings

| Name | What it is | In code |
|---|---|---|
| **a note** | One durable piece of writing. | `Note`, `NoteStore` |
| **note actions** | The on-device AI buttons: Summarise, Find action items, Clean up, Format as document, Suggest title. | `NoteAction`, `NoteActionRunner` |
| **a meeting** | A recording of both sides of a call, filed as a note, split into **turns** under two **speaker labels**. | `MeetingSession` |
| **a turn** | One paragraph of a meeting transcript: contiguous speech with no real pause in it. A timing fact only - a turn never claims *which* person spoke, and "a turn" is never called "a speaker". | `SpeechTurn`, `TurnSegmenter` |
| **a speaker label** | What a meeting calls one of its two audio **sources** - the mic (**You**) and the call (**Others**). Renameable per meeting. Say "source", not "speaker", when the distinction matters: the mic is one person, the call is however many. | `MeetingSpeakers`, `SpeakerRole` |
| **dictation history** | The log of what was typed into other apps. Distinct from notes. | `TranscriptionHistory` |

## Renames this implies

`NoteCaptureBox` → `NoteCard` is the only code name that contradicts this table.
Everything else already matches. Not done yet - it touches one type, its file and
its tests.
