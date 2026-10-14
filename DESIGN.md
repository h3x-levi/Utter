---
name: Utter
description: Private on-device dictation for the Mac, drawn as a cassette J-card.
colors:
  paper: "#F8F9FB"
  paper-dark: "#15171C"
  spine: "#EEF1F6"
  spine-dark: "#101216"
  fold: "#FBFCFD"
  fold-dark: "#181A20"
  ink: "#1C2A5E"
  ink-dark: "#E9EDF8"
  ink2: "#4A5680"
  ink2-dark: "#AEB6CD"
  ink3: "#646B82"
  ink3-dark: "#7D87A2"
  pen: "#2A4FC4"
  pen-dark: "#8FA8FF"
  pen-ink: "#20348C"
  pen-ink-dark: "#C2D0FF"
  tape-red: "#D8352A"
  tape-red-dark: "#E2463B"
  spine-gold: "#F1B632"
  spine-navy: "#1C2A5E"
  spine-navy-dark: "#2C3656"
  rule: "rgba(46, 80, 170, 0.13)"
  rule-dark: "rgba(150, 175, 255, 0.08)"
  rule2: "rgba(46, 80, 170, 0.26)"
  rule2-dark: "rgba(150, 175, 255, 0.18)"
  wash: "rgba(42, 79, 196, 0.08)"
  wash-dark: "rgba(143, 168, 255, 0.09)"
  mark: "rgba(216, 53, 42, 0.20)"
  mark-dark: "rgba(226, 70, 59, 0.32)"
  note: "rgba(241, 182, 50, 0.17)"
  note-dark: "rgba(241, 182, 50, 0.12)"
  edge: "rgba(30, 40, 70, 0.13)"
  edge-dark: "rgba(255, 255, 255, 0.08)"
  key: "#E6EAF1"
  key-dark: "#23262E"
  chrome-tape: "#121419"
  chrome-tape-ink: "#EEF2FB"
  chrome-transcript: "#DFE6FF"
typography:
  display:
    fontFamily: "SF Pro Rounded"
    fontSize: "30pt"
    fontWeight: 800
    letterSpacing: "0.02em"
  headline:
    fontFamily: "SF Pro Rounded"
    fontSize: "22pt"
    fontWeight: 800
    letterSpacing: "0.02em"
  title:
    fontFamily: "SF Pro Rounded"
    fontSize: "12.5pt"
    fontWeight: 800
    letterSpacing: "0.24em"
  label:
    fontFamily: "SF Pro Rounded"
    fontSize: "11pt"
    fontWeight: 800
    letterSpacing: "0.08em"
  body:
    fontFamily: "SF Pro Text"
    fontSize: "13pt"
    fontWeight: 400
  body-settings:
    fontFamily: "SF Pro Text"
    fontSize: "13.5pt"
    fontWeight: 400
  body-written:
    fontFamily: "SF Pro Text"
    fontSize: "16.5pt"
    fontWeight: 400
  mono:
    fontFamily: "SF Mono"
    fontSize: "11pt"
    fontWeight: 600
    fontFeature: "tnum"
rounded:
  segment: "1pt"
  keycap: "5pt"
  link: "7pt"
  deck: "10pt"
  note: "12pt"
  panel: "14pt"
  hub: "18pt"
  island: "22pt"
  pill: "9999pt"
spacing:
  x2: "8pt"
  x3: "12pt"
  x4: "16pt"
  rule: "34pt"
components:
  pen-fill:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "0 14pt"
    height: "30pt"
  pen-fill-small:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.pill}"
    padding: "0 11pt"
    height: "26pt"
  pen-outline:
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "0 14pt"
    height: "30pt"
  pen-outline-hover:
    backgroundColor: "{colors.wash}"
  pen-ghost:
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "0 14pt"
    height: "30pt"
  ink-icon:
    textColor: "{colors.ink2}"
    rounded: "{rounded.pill}"
    size: "28pt"
  ink-icon-hover:
    backgroundColor: "{colors.wash}"
    textColor: "{colors.ink}"
  chip-tab:
    textColor: "{colors.ink2}"
    rounded: "{rounded.pill}"
    padding: "0 13pt"
    height: "28pt"
  chip-tab-selected:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
  chip-choice:
    textColor: "{colors.ink2}"
    rounded: "{rounded.pill}"
    padding: "0 11pt"
    height: "26pt"
  chip-choice-selected:
    backgroundColor: "{colors.wash}"
    textColor: "{colors.ink}"
  line-field:
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    height: "32pt"
  ink-note:
    backgroundColor: "{colors.note}"
    textColor: "{colors.ink2}"
    rounded: "{rounded.note}"
    padding: "11pt 14pt"
  tape-stripe:
    backgroundColor: "{colors.tape-red}"
    textColor: "#FFFFFF"
    height: "30pt"
  tape-stripe-setup:
    backgroundColor: "{colors.spine-gold}"
    textColor: "{colors.spine-navy}"
  track-row:
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    height: "34pt"
  deck-key:
    backgroundColor: "{colors.key}"
    textColor: "{colors.ink2}"
    rounded: "{rounded.deck}"
    height: "52pt"
  keycap:
    textColor: "{colors.ink2}"
    rounded: "{rounded.keycap}"
    height: "18pt"
  ink-switch:
    rounded: "{rounded.pill}"
    width: "40pt"
    height: "22pt"
---

# Design System: Utter

## Overview

**Creative North Star: "The Mixtape J-card"**

Utter's day is a cassette inlay. Every dictation is a numbered, timed track written in navy ballpoint on white ruled stock, and today's red tape stripe fills toward a word goal. Dark mode is chrome tape: a near-black shell with pale ink and the same red stripe. The window is custom-painted; inside it nothing is a stock macOS control unless it is hidden behind an ink style.

Rows sit on the 34 pt rules with no boxes around them. Emphasis comes from running time, weight and the hand marks (a ballpoint circle round the chosen track number, a tick on a pasted track), not from cards or fills. Density is a tracklist: one line per track, truncated, with mono times on the right.

**Key Characteristics:**
- White ruled stock, one blue rule at the foot of every 34 pt line.
- Navy ballpoint ink in three strengths; brighter ballpoint blue only for hand marks.
- One red stripe per surface (today's tape), backed by a red, gold and navy spine.
- SF Pro Rounded heavy caps for headings and pen labels, SF Pro for sentences, SF Mono for times and counts.
- Outlined capsule pens for actions, at most one filled per group.
- State marked by hand: circled, ticked, written on.

## Colors

Low-chroma navy on near-white, with cassette red as the one loud colour and gold reserved for "needs you". Every token is a four-way swatch (light, dark, light increased contrast, dark increased contrast) resolved in `Look.Swatch`; increased-contrast values are listed where they differ.

### Primary
- **Cassette Red** (`tape-red`): today's tape stripe, the Library spine's top band, the recording dot, focused line-field underline and text cursor, the selected track number, `SettingsMeter` fill, the on-dot of a deck key. Never body text.

### Secondary
- **Spine Gold** (`spine-gold`): the stripe while setup is needed (ink switches to navy on it), the spine's middle band, the warn dot in `SettingsStatus`, and the `note` tint behind `InkNote`.
- **Ballpoint Blue** (`pen`): hand marks only: `HandCircle`, `InkTick`, `DrawnStroke`, and the Library window tint.
- **Pen Ink** (`pen-ink`): text the user wrote, read back at 16.5 pt in the fold, onboarding try field and note editor.

### Neutral
- **Inlay Paper** (`paper`): hub, Library main column, Settings, onboarding.
- **Spine Stock** (`spine`): Library sidebar and onboarding/companion inset panels (14 pt radius).
- **Fold Stock** (`fold`): the Library fold pane on the right.
- **Navy Ink** (`ink`): primary text, pen fills and outlines, section rules (2 pt), switch fill.
- **Ink 2** (`ink2`): secondary text, icon buttons, deck key labels, InkNote body.
- **Ink 3** (`ink3`): running times, track numbers, details, placeholders. Increased contrast: #565F7E light, #A3ABC2 dark.
- **Rule / Rule 2** (`rule`, `rule2`): ruled lines and row dividers; `rule2` for ghost borders, keycaps, chip borders, the dashed fold edge. Increased contrast: rule 0.36 / 0.28 alpha, rule2 0.55 / 0.45.
- **Wash** (`wash`): hover fill on pens, icons, chips, links, and the half-height highlighter behind a hovered track title.
- **Mark** (`mark`): red highlighter for search hits and the current spine row underline.
- **Edge** (`edge`): hairline round the hub and deck keys. Increased contrast: 0.4 / 0.3 alpha.
- **Key / Key Hi / Key Lo** (`key`, plus white and navy/black overlays): deck keys and the onboarding demo key only.
- **Chrome Tape** (`chrome-tape`, `chrome-tape-ink`, `chrome-transcript`): the pill island and caption, always dark. Defined separately in `PillColor` (see drift note in Do's and Don'ts).

### Named Rules
**The One Stripe Rule.** Each surface carries one red tape stripe (hub top, Library tape, onboarding setup stripe) plus at most the red, gold and navy spine. Red elsewhere is a mark, never a fill.

**The Gold Means You Rule.** Gold appears only when the user has something to do: setup stripe, warn dot, InkNote, pill error. It is never decoration.

**The Ink3 Is Quiet Text Rule.** Ink 3 measures 5.0:1 on paper in light and dark (4.7:1 on the spine), so it passes WCAG AA for small text. It carries secondary lines (row descriptions, times, counts, placeholders); the main line of anything uses Ink 2 (6.8:1) or Ink.

## Typography

**Display Font:** SF Pro Rounded, heavy, uppercase (`mixtapeCaps`, tracking in em of size)
**Body Font:** SF Pro Text
**Label/Mono Font:** SF Mono with monospaced digits

**Character:** Rounded heavy caps read like a J-card's printed headings; SF Pro sentences read as handwriting on the line; mono keeps times and counts aligned like a tracklist.

### Hierarchy
- **Display** (heavy, 30 pt, 0.02 em, caps): today's day title in Library, onboarding step titles.
- **Headline** (heavy, 22 pt, 0.02 em, caps): earlier day titles. Fold track title at 18 pt (0.01 em); rename sheet 15 pt.
- **Title** (heavy, 12.5 pt, 0.24 em, caps): `SideHeader` (Side A, Side B, Settings sections). Hub heading 12 pt, 0.22 em.
- **Label** (heavy, 11 pt pen / 10.5 pt small pen and chips, 0.08 to 0.14 em, caps): pens, chips, stripe label (10.5 pt, 0.2 em), deck keys (9.5 pt, 0.14 em), spine group label (10 pt, 0.2 em), spine printed label (10.5 pt, 0.34 em).
- **Body** (regular, 13 pt; 13.5 pt in Settings; 12.5 pt for notes, empty states and status; 12 pt for row details; 11 pt for key hints): sentences. Semibold for the selected or meeting track and for the bold first sentence of prose.
- **Written** (regular, 16.5 pt, pen ink, line spacing 14 pt to sit on the 34 pt rules): the user's own words.
- **Mono** (11 pt semibold for counts and track numbers, 11.5 pt for times and SideHeader detail, 12 pt semibold for pick values, 10.5 to 11 pt for keycaps).
- **Pill** uses system text styles (`.callout` semibold for messages, `.body` transcript, `.caption` header) so it follows the user's text size.

### Named Rules
**The Caps Are Earned Rule.** Heavy caps are for headings, pen labels, chips, deck keys and the stripe. Sentences and track titles are never caps.

**The Mono Is Data Rule.** SF Mono only for numbers the eye compares: times, counts, word totals, key legends.

## Layout

- **The rule rhythm.** `Mixtape.ruleSpacing` = 34 pt. `RuledBackground` draws a 1 pt rule at the foot of each 34 pt line; `TrackRow` is exactly 34 pt; the hub list is 8 rules (272 pt); text the user wrote uses 16.5 pt with 14 pt line spacing so lines land on rules.
- **Spacing scale.** 8 / 12 / 16 (`Space.x2/x3/x4`), with observed component padding of 10, 14 and 18. Side A and Side B columns sit 34 pt apart.
- **Hub.** 384 pt wide, 18 pt continuous corners, 1 pt edge. Stripe on top, then content inset 14 / 18 / 12 / 18: heading, setup line, line field, 8-rule list, deck keys, footer links, key hints.
- **Library window.** Min 1000 x 680, ideal 1380 x 960. Spine sidebar 214 pt with a 6 pt red, gold and navy band on its trailing edge and a rotated printed label; main column with toolbar, tape stripe (insets 34 / 30), day blocks; fold pane 360 pt behind a 1.5 pt dashed `rule2` edge.
- **Settings.** Fixed 780 pt column, height 420 to user's choice (ideal 700). Caps tab chips on top (Cmd-1 to 5), `SettingsSection` blocks of `SettingsRow` (min 51 pt, 68 pt with detail, 1 pt rule at foot).
- **Onboarding.** Fixed 700 x 520 so no step resizes it. Red setup stripe with step segments; footer above a 1 pt rule with ghost / outline / fill pens.
- **Pill.** Rest 32 x 6, hover 48 x 16, listening 64 x 20, hands-free / glyph 80 x 20, dot 8, message up to 260 x 20, island 360 wide (12 pt padding, 6 pt spacing, 24 pt footer, up to 6 transcript lines), 14 pt panel margin.

## Elevation & Depth

Flat paper. Depth comes from rules, the dashed fold, and stock tones (paper, spine, fold), not shadows. Two exceptions, both physical objects:

### Shadow Vocabulary
- **Deck key skirt** (`keyLo` fill offset 2 pt down; key-hi gradient on top 40%; pressed or on keys sink 1.5 pt with a 6 pt top shade): deck keys and the onboarding demo key only. This is a cassette-deck key, not a card shadow.
- **Pill float** (black 0.25, radius 5, y 3, plus a 1 pt ring just outside the edge, black 0.1 or white 0.08 on the island): the pill and island, which float over other apps.

### Named Rules
**The Paper Is Flat Rule.** Nothing on the ink world casts a shadow. If a surface needs separation, give it a rule, a stock tone, or a 1 pt edge.

## Shapes

- Capsules for every action: pens, chips, ink icons (28 pt circles), the switch, the pick, the meter.
- Continuous rounded rectangles for containers: hub 18, onboarding/companion panels 14, InkNote 12, deck 10, footer link hover 7, keycaps 5. Tape segments 1.
- The pill's corner radius is a function of its size (`min(22, h/2, w/2)`), so it is a capsule until it grows into the island and the corners spring with it.
- Lines over boxes: section titles sit on a 2 pt ink rule, rows on 1 pt rules, fields on a 1.5 pt underline, the pick on an underline that curves up at the capsule ends.

## Components

### Buttons (Pens)
Ink capsules with heavy caps labels (`.pen(kind, size)`).
- **Fill:** ink capsule, paper label. One per group: Paste again, Grant, Add to Words, Stop, the onboarding Continue.
- **Outline:** 1.5 pt ink border, ink label; hover adds wash. Copy, New note, Record a meeting, Try again.
- **Ghost:** 1.5 pt `rule2` border. Not now, Clear search, Skip.
- **Size:** regular 30 pt high, 14 pt padding, 11 pt label; small 26 pt, 11 pt padding, 10.5 pt label.
- **States:** hover fades in 0.15 s; fill brightens 6% on hover; press scales to 0.95 on `Mixtape.press`; disabled 40% opacity.
- **Island pens:** same shape on chrome tape: Copy filled in tape ink, Save as note outlined, 24 pt high.

### Ink Icon Buttons
28 pt circle, SF Symbol 13 pt medium in Ink 2, Ink plus wash on hover, press 0.9. For row actions (copy, paste, open) and More menus. Always give an accessibility label.

### Links
Footer text links in 12.5 pt semibold ink, 28 pt high, wash on hover in a 7 pt rounded rect. Hub footer only.

### Chips (Caps Chips)
- **Tab:** 28 pt, picked = ink fill with paper label; unpicked `rule2` border, Ink 2 border on hover. Settings sections.
- **Choice:** 26 pt, picked = ink border with wash; for a choice among two to four values (`SettingsChoice`).

### Inputs / Fields
- **LineField / SettingsField:** no box. Text on a 1.5 pt ink underline that turns red while focused; red cursor; placeholder in Ink 3, hidden from VoiceOver with the field labelled instead. LineField adds a magnifier and is 32 pt.
- **SettingsPick:** a Menu whose label is the value in 12 pt mono semibold with an up-down chevron, over an ink underline curving up the capsule ends; wash on hover. Its options are an inline Picker inside the menu.
- **InkSwitch:** 40 x 22 outline capsule, 15 pt knob; on = ink fill with paper knob. Springs across (response 0.3, damping 0.62), 0.15 s ease under Reduce Motion. Exposes a real Toggle to accessibility.
- **SettingsStatus:** drawn tick for OK, 7 pt gold dot for warn, plain Ink 3 for neutral.
- **SettingsMeter:** 4 pt red capsule on a `rule2` track, 120 pt default.

### InkNote
Gold-tinted callout (`note` fill, 12 pt radius, 11 / 14 padding), 12.5 pt Ink 2 text with a bold Ink lead, then pens. Use for one suggestion or setup need at a time: a newly heard name, a missing permission, a model upgrade. The sign-in screen uses the onboarding window and type, with Google's official light or dark button art unchanged (their branding rules forbid restyling it). The meeting banner is the one InkNote with a live row: Stop (fill) and Pause (outline), then two `SettingsMeter` lines labelled You and Others, hidden from VoiceOver. `TapeNote` is its quiet sibling for empty states: bold line, quiet line, optional action, no fill.

### TapeStripe (signature)
The red stripe: optional caps label, an 8 pt capsule track, and a mono count (`180 / 500 WORDS`, or `180 WORDS` with no goal), 30 pt high.
- One white segment per track, 2 pt gaps, each a share of `max(goal, total)` so the tape fills toward the goal. With no goal the segments fill the whole track by share.
- **Unkept segment:** words dictated today with Keep history off appear as one segment labelled "Dictated today, not kept"; it does not open anything.
- **Status:** ready = red; setup = gold with navy ink; recording = red with a pulsing 8 pt dot. Colour change eases 0.3 s.
- Hover or the selected track dims a segment to 62%; tapping opens that track.

### TrackRow
A 34 pt line: 2-digit mono number (26 pt column), title in 13 pt (semibold when selected or a meeting), mono running time. Hover draws a half-height wash highlighter under the title. Selected: number turns red and gets a `HandCircle`; the time gives way to ink icon actions. Pasted: an `InkTick` after the title. Search hits get the `mark` highlighter.

### Hand Marks
- **HandCircle:** an ellipse open at the top like a ballpoint stroke, 32 x 24, round the selected number.
- **InkTick:** three-point tick, 12 x 10, line width 1.8.
- **DrawnStroke:** draws either shape once on appear in Ballpoint Blue, round caps, 1.7 pt default, timing (0.3, 0.7, 0.3, 1) 0.5 s. Under Reduce Motion it is simply there. Always hidden from accessibility; the row label carries the meaning ("pasted").

### WriteOn
The signature interaction: a new track is unmasked from the left over 0.9 s (timing 0.4, 0.1, 0.3, 1; 0.15 s delay) while its tape segment grows in. Reduce Motion shows it whole.

### DeckKeys
Joined transport keys like a cassette deck: 52 pt high, 10 pt corners, icon 14 pt over a 9.5 pt caps label, 1 pt `edge` dividers. A key that is on sinks 1.5 pt and shows a 6 pt red dot; Record meeting's symbol carries a red palette layer. Hub only: Hands-free, New note, Record meeting.

### Keycap
Mono 10.5 pt in Ink 2 inside a 5 pt `rule2` outline, min 20 x 18 (Settings variant 11 pt, 22 x 20, labelled "X key"). For printed shortcut hints; hub hints are hidden from VoiceOver because each action has its own control.

### Navigation (Library spine)
Spine rows in body text with mono counts; the current row is semibold with a red `mark` underline at 60% height. A "Vocabulary" caps group label, Words, and Settings pinned at the foot. Cmd-1 to 5 switch filters.

### Pill (REC stripe)
One shell for every look, opaque, always in dark scheme:
- **Rest:** 32 x 6 red, gold and navy stripe (bands at 60 / 80 / 100%).
- **Hover:** 48 x 16 navy with resting bars; a lock square when hands-free is offered.
- **Listening / thinking:** 64 x 20 red with seven white bars; hands-free, note and memory add a trailing glyph square (80 wide).
- **Done:** navy with a white tick drawn after the bars fade (0.08 s delay, 0.3 s draw), held 0.45 s.
- **Message:** navy for a notice, gold with navy ink and an exclamation for an error; flat bars, text truncates with full text in the tooltip.
- **Dot:** 8 pt navy or gold for an unseen message.
- **Island:** 360 wide chrome tape with a 5 pt red, gold and blue stripe on top, faint tape rules under the transcript, Copy (Cmd-C), Save as note (Cmd-S), Esc to close. Shows only when no text box took the words.

## Motion

- **Press:** `Mixtape.press` spring (response 0.22, damping 0.55); island pens damping 0.62.
- **Hover:** ease-out 0.12 to 0.15 s; segment hover 0.2 s.
- **Tape fill:** timing (0.2, 1, 0.3, 1) 0.7 s; segments grow from the leading edge.
- **Pill:** open spring 0.42 s bounce 0.2; close 0.36 s bounce 0; hover 0.3 s bounce 0.15. Opening may overshoot, closing never does. Content follows the shape: in after 0.1 s (island 0.18 s) over 0.22 s, out in 0.1 s. 0.1 s hover intent.
- **Onboarding steps:** spring 0.46 s bounce 0.16.
- **Reduce Motion:** springs become 0.14 to 0.18 s ease-outs, pulses stop, strokes and write-ons appear whole, segments fade instead of growing, press scaling is off. The pill reads the setting from AppKit (`MotionPreference`) because its panel does not get SwiftUI's environment reliably.

## Accessibility

- Every icon-only control carries a label (Copy, Paste in Mail, Open in Library, More, Close); state changes swap the label (Copied, Saved as a note) and the island posts an announcement.
- Rows combine into one element: "Track 6, Dear Ms Okafor, 0:08, pasted", with a named action for paste or open. Selected rows, tabs, chips, segments and on deck keys add the selected trait.
- Section titles and day titles carry the header trait; decorative rules, hand marks, the spine label and key hints are hidden.
- The stripe count reads "180 of 500 words"; the tape reads as "Today's tape" with one labelled element per segment.
- The pill is one element with label and value, updates-frequently while recording, and a named hands-free action.
- Caps are drawn with `.textCase(.uppercase)` on the source string. Treat labels as reaching VoiceOver in caps and keep pen titles short real words.
- Menus (More, SettingsPick) are SwiftUI `Menu`s, so assistive tech opens them with the standard show-menu action rather than a custom gesture.
- Contrast: every swatch has increased-contrast values for `ink3`, `rule`, `rule2` and `edge`; the pill firms its ring to black 0.6 and adds a white inner edge; island quiet text rises from 0.6 to 0.85 opacity.

## Do's and Don'ts

### Do:
- **Do** put rows on the 34 pt rules and size new text so it lands on them.
- **Do** use one filled pen per group and outline or ghost for the rest.
- **Do** mark state by hand: `HandCircle` for chosen, `InkTick` for done, `WriteOn` for new.
- **Do** take every colour from `Mixtape` swatches so light, dark and increased contrast all resolve.
- **Do** wrap any needed system control in an ink style (`.pen`, `.inkIcon`, `.settingsSwitch`, `SettingsPick`, `LineField`) and keep its accessibility representation.
- **Do** give every motion a Reduce Motion path that is instant or a short ease.

### Don't:
- **Don't** place stock bordered buttons, switches, segmented controls or pop-up buttons in the ink world; the only system pickers live inline inside an ink Menu.
- **Don't** use the system accent blue; the Library tints with `pen`, onboarding with `ink`, fields with red.
- **Don't** put glass or materials behind the Library, hub, Settings or onboarding; paper is opaque. Glass stays with the companion bubble over the desktop.
- **Don't** box rows in cards or add drop shadows to paper surfaces.
- **Don't** set sentences or track titles in caps, or numbers outside mono.
- **Don't** add a second red stripe to a surface or use gold where nothing needs the user.
- **Don't** use Ink 3 for text a user must read.
