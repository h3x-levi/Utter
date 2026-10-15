# Changelog

All notable changes to Utter are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses semantic-ish versioning (the build script auto-bumps the patch).

## [1.2.3] - October 2026

- The companion has over a hundred new moments for dictation, meetings, care reminders, the time of day, the seasons and play
- Choose a finish and an outfit for the companion in Settings
- Speech detection now skips silence and background noise, so less work runs on your computer
- Dictionary words heard as similar sounds, like "cube or needs", are written as the word you added

## [1.1.58] - October 2026

- **First-Principles Utter 2.0 Architecture**: Rebuilt the entire user experience around a unified 3-tier attention hierarchy (Dynamic Capsule HUD, Unified Voice Canvas, and System Preferences).
- **Studio Workspace**: Live speech readiness monitor, active meeting detection and dual-stream recording banner, distraction-free voice scratchpad canvas with on-device AI polish, and desktop companion stage.
- **Memory Timeline**: Chronological intelligence stream fusing dictations and meeting notes into a single searchable timeline with instant AI actions and multi-format export (Markdown, CSV, Text).
- **Voice Engine**: Unified personal language center combining Custom Vocabulary and jargon, Spoken Snippets with variable expansions, and AI Writing Personas with interactive sandbox playground.
- **Preview Data Isolation**: Implemented SnapshotPreviewMode in-memory isolation to guarantee zero reading or writing of private user data during snapshot previews.

## [1.1.57] — September 2026

- **Authentic Apple HIG Redesign**: Redesigned System Settings and Main App windows adhering to native macOS 14/15 Sonoma and Sequoia guidelines.
- **Double-Tap Hotkey Hands-Free Mode**: Double-tap `Fn` (or configured hotkey) to engage continuous hands-free dictation without holding keys.
- **Simple Apple-Designed SF Symbols**: Cleaned up sidebar navigation, settings options, and stat cards with native, unboxed vector SF Symbols (`mic`, `character.book.closed`, `text.quote`, `sparkles`, `note.text`, `pawprint`).
- **Synchronized Assets & Website**: Refreshed AppKit window captures across documentation and website showcase.

## [3.0.40] — August 2026

- Organized Companion into native Today, Remember, Rewards, and Customize tabs.
- Added local typed and spoken memory capture with review-before-save, editing, completion, snoozing, deletion, and native actionable notifications.
- Added cumulative dictation milestones that unlock companion objects, animations, and five original synthesized cat sounds without purchases or expiring rewards.
- Made pill glyphs legible over both light and dark backgrounds and replaced the bouncing pencil with a continuous handwriting stroke.
- Added durable memory rollback and previous-generation recovery for failed writes or corrupted files.

## [3.0.39] — August 2026

- Rebuilt Companion as a full-width native macOS settings page instead of a narrow centered form.
- Redrew both pixel cats with longer bodies and added grooming, rolling, and loaf animations.
- Added autonomous play with the ball, box, yarn, and cushion, plus click, double-click, toss, feed, and brush reactions.
- Added local relationship memory with visible privacy controls, daily goals, and animations earned through normal use.
- Added focused-window edge avoidance and quiet behavior for presentations, screen sharing, full-screen apps, and Utter meeting capture.

## [3.0.38] — August 2026

- Fixed the standard Settings command and Command-, opening an empty window instead of Utter Settings.
- Settings sections now open at the top instead of inheriting another section's scroll position.
- Fixed Home activity labels and values collapsing into a centered cluster on wide windows.
- Settings are now written atomically, failures are reported, and an unreadable settings file is preserved for recovery instead of being overwritten.

## [3.0.37] — August 2026

- Expanded local automatic call detection beyond Zoom and Teams to major dedicated calling apps,
  including Webex, Skype, WhatsApp, Signal, Telegram, Viber, RingCentral, GoTo,
  Jitsi Meet, LINE, WeChat, and KakaoTalk.

## [3.0.36] — August 2026

- The resting pill’s microphone is now solid black in light themes and solid white in dark themes.

## [3.0.35] — August 2026

- Fixed automatic meeting offers appearing for browser playback such as YouTube.
- Automatic offers now require active microphone and speaker use from Zoom, Microsoft Teams,
  FaceTime, Slack, or Discord. Browser meetings remain available through “Record a meeting” in Notes.

## [3.0.32] — August 2026

- The companion is now a pixel cat. The two Mochi packs and the two code-drawn Persian cats were removed; the bundled characters are Golden Dog, Panda, Pixel Cat (Ginger) and Pixel Cat (Gray).
- No character is drawn in code any more — a sprite pack is the only way one can exist, which is ~3,100 fewer lines to maintain.
- An existing selection naming a removed character is migrated to the default pack on first launch and the correction saved, so nobody lands on an empty companion window.
- Fixed: a pixel-art pack whose canvas is larger than the chosen character size was drawn at full canvas size, overflowing the panel that clips it, so the cat was sliced at the window edge while roaming. Only reproduced on a non-Retina display.

## [3.0.15] — August 2026

**The pill no longer disappears into its background**

- Over a white window it went white, and over a dark one dark — the opposite of what it needs to do.
  The cause: the pill drew its edge from the *app's* light/dark setting, but the pill floats over the
  desktop, so the app's appearance and what is actually behind the pill are two different things. In
  dark appearance both of its strokes came out white, which means over anything pale it had no dark
  edge anywhere and simply dissolved
- Its outline is now two-tone and takes no notice of the appearance: a dark hairline on the outside
  with the lit highlight just inside it. One of the two always registers, whichever way the background
  goes — which is how buttons stay visible when they are drawn over arbitrary content. Checked in both
  appearances rather than assumed

## [3.0.14] — August 2026

- The pencil is visible again while transcribing. Rebuilding it as a scrolling wave in 3.0.12 parked
  the glyph 7.2 pt past the right edge of its own frame, hard against the capsule's bright rim, so what
  was left of it read as nothing and you saw only the squiggle. The cause is a SwiftUI trap: a rotated
  image keeps the layout size of the *unrotated* glyph, so an 11 pt pencil turned 38 degrees actually
  paints across 15.4 pt and positioning it by offset alone puts most of it outside. The pen now
  reserves the space it really paints, and a test checks every number against the frame

## [3.0.13] — August 2026

**The ghost when you press the hotkey**

- Holding the key showed a faint empty shape before the pill filled in. That was mine: 3.0.9 faded the
  pill's contents in just behind the shell, which on a small capsule means the first frames are an
  empty piece of glass with nothing in it. Over a wallpaper that reads as a shadow. The fade is gone —
  the capsule's contents are simply there. The note card keeps its own row-by-row entrance, which is
  where staging actually helps
- And it no longer stretches open. The width of a recording pill is measured from its own contents,
  and that measurement arrives one layout pass *after* the state changes — so the first frame drew at
  the resting 56pt with a dot, a meter and a timer already inside it, then jumped to the real width.
  Each state now has a floor wide enough for its own row, so the first frame is already the right size.
  The live transcript can still grow it past that as you speak

**Removed**

- The phase name on the pill ("Transcribing", "Rewriting", "Typing"). It was added because a code
  comment argued for it, which is not the same as anyone wanting it — and it turned a small round pill
  into a wide label three times per dictation. The pencil is back on its own. Screen readers still get
  the phase

**Also fixed**

- A sound that was refused by the audio device stayed silent forever, because the refusal was ignored
  and the dead player kept being reused
- Switching the companion's pet behaviours off while it was peeking left it parked two thirds off the
  side of the screen until the app was restarted
- Deleted a glass mechanism that had no callers left, so it can't be mistaken for something that works

## [3.0.12] — August 2026

A polish pass through the pill's states, working from the audit findings rather than from guesses.

**The note card**

- Its text finally has a hierarchy. Every line in the card — the note's name, the timer, the
  transcript, the footer hint — resolved to the same grey, so the words arriving, which are the card's
  entire reason to exist, were drawn in the same ink as its own footnote. The transcript and the note's
  name are now full-strength
- The rows arrive top-down instead of all at once: the destination, then the transcript, then the
  footer, 50 ms apart, each rising 5 pt as it fades in. The card reads as filling rather than as being
  uncovered. Nothing fades out, so this cannot double anything
- The spacing was one value used everywhere; it is now tighter above the transcript and looser below
  it, in the same total height, so the footer reads as a status band rather than another line of text

**States that looked unfinished**

- "Transcribing", "Rewriting" and "Typing" are actually shown now. The pill has always carried which
  phase it was in, and its own code comment said naming the phase was the point — but only the pencil
  was ever drawn. All three share one width, so moving between them does not resize the pill
- The pencil no longer teleports. It reset to the left every 1.4 seconds and erased its own line,
  once per cycle, for as long as transcription took. The wave now scrolls continuously, which has no
  seam because a wave shifted by exactly one wavelength is the wave it started as
- The level meter shows half a second of history instead of a sixth of a second. Five bars updated 30
  times a second held too little to read as movement, so it flickered rather than scrolled — the
  opposite of what it was for. Seven bars, shifted half as often, and the newest bar still tracks at
  full speed
- The "breathing" dot was panting at 35 cycles a minute, and shrinking to 60% while also dropping to
  45% opacity — two channels doing one job, both too deep. It now breathes at 27
- Notice and error used different glyph weights for the same row, and drew their message in footnote
  grey. Both now match, and an error you need to act on is full-strength
- A long error message can no longer be truncated mid-word off the edge of the pill

**Not changed, deliberately**

- The hands-free bead's neck was going to release later, on the reasoning that it currently breaks
  with only 62% of the gap open. The arithmetic says otherwise: releasing later also means releasing
  while the bridge is still 6.7 pt thick rather than 1.9 pt, so 6.7 pt of glass would vanish in about
  19 ms. That is a more visible pop, not less. Left alone, with the numbers written down

## [3.0.11] — August 2026

Found by putting specialist reviewers on the code instead of waiting to be told. Six real defects,
one of them mine from two releases ago.

**The animation that was never running**

- The settle added in 3.0.9 was inert. It set the start value and started the animation in the same
  breath, and SwiftUI coalesces those — so it interpolated from 1 to 1, a change of nothing, and the
  start value was never drawn. It failed silently and safely, which is why the pill looked fine and
  still snapped. It runs now
- The pill's colour was the real snap, and it was never animated at all. Starting a recording jumped
  the glass from clear to red, and its edge from grey to red, in a single frame — and that happens on
  every dictation, not just the two transitions that change size. The colour now crosses over 0.22s
- The settle no longer uses one scale for every state. A flat 10% moved the small pill 2.8pt and the
  note card 14.6pt, so the card lurched hardest and drew its transcript 11% small while fading it in.
  Every state now settles by the same 3pt of visible travel
- Its bounce is gone, because it was measured at 0.18pt — less than one pixel. It was never a bounce

**The hands-free button**

- Clicking it to stop hands-free left it stranded. The button was removed from the screen while your
  pointer was still on it, so it never received the matching "pointer left" event, and the flag stuck:
  the button then sat on the resting pill with no cursor near it, the two-second press that opens
  Utter stopped working entirely, and a strip beside the pill swallowed desktop clicks until you
  hovered the pill and left again
- Its ring is no longer dragged off its own outline. The settle scaled the pill but not the ring drawn
  on it, putting the two up to 7.4pt apart — a third of the button's width — for a third of a second

**Two more**

- A long error message could draw the pill wider than the window that holds it, losing its rounded
  ends and leaving a full-width strip across the bottom of the screen eating clicks
- A failed start could hide the pill while a recording was still running, because a timer asked what
  state the pill was in and got the previous answer
- Selected text is no longer occasionally lost. The 3.0.8 speed-up stopped waiting as soon as the
  clipboard was *claimed*, which is before the app has written to it, so a spoken "make it
  professional" could run against nothing

## [3.0.10] — August 2026

**The hands-free button no longer runs away from the cursor**

- Reaching for it made it retract. The 6pt gap between the pill and the button belongs to neither, so
  both hover flags go false while you cross it, and the button only survived that for 120 ms — about
  seven frames. Any unhurried movement overran it, the button pulled back, and because it stops
  accepting clicks when hidden, sitting on it did nothing. The window is now 350 ms, which covers an
  unhurried reach with room to spare
- The button's outline and the ring inside it were animating on two different curves — the pill's lobe
  arrived and settled in 110 ms while the ring was still springing for another 210 ms, so one event
  was drawn on two clocks. They now share a single spring, so the bead emerges as one object

**The pill's transitions are more pronounced**

- The settle was 6%, which was there but too slight to read as a transition. It is 10% now, where a
  presentation reads as arriving

## [3.0.9] — August 2026

**The pill animates again — with a transform instead of a resize**

- 3.0.8 removed the motion rather than replacing it, which was the wrong call. The size change still
  has to be instant, because resizing Liquid Glass re-anchors it and the system cross-fades the old
  against the new; that is the ghosting, and nine attempts have each died on it. But that only rules
  out animating the *size*
- So the pill now lands at its new size and springs the last 6% into place. A scale is a transform of
  something already drawn, so no second glass body exists and there is nothing to cross-fade. It
  scales about its bottom edge, because the pill sits on the Dock and scaling about the middle would
  make it bob
- The contents fade in just behind the shell, so opening a note capture reads as an empty glass card
  arriving and then filling. Nothing ever fades *out* — that was the second ghost, and keeping every
  removal instant is what stops two states being drawn at once
- Reduce Motion still gets a single clean render

## [3.0.8] — August 2026

**Pressing the hotkey now gets an immediate reaction**

- Every hotkey press slept for 80 ms before anything happened. Utter copies whatever is selected in
  the app in front, so a spoken command like "make it professional" has something to work on, and it
  waited a flat 80 ms for that copy to land — with the whole app frozen for it, before the pill could
  even draw. It now waits only until the copy actually arrives, which is usually 10 to 20 ms, and
  keeps 80 ms as a limit rather than a cost
- The pill's state is also set before the rest of the start-up work instead of after it, and reaching
  the screen now costs one pass through the event loop rather than two

**The ghosting**

- 3.0.7's fix was wrong, and the way it was wrong is worth writing down. It pinned the glass to one
  large fixed rectangle so the outline could animate inside it without the material being redrawn at
  a new size. The material turned out to fill that rectangle rather than being clipped to the outline
  drawn in it, so a pale full-panel slab sat behind the pill — visible for as long as the pill was
  up, which during transcription is several seconds. That is the "full note pop-up stays white"
- The glass is sized to the pill again, so the slab is gone. The consequence is accepted rather than
  worked around: resizing glass re-anchors it and the system cross-fades the old against the new, so
  the size change stays instant. Nine attempts have now each failed on that same fact
- A second, separate ghost is fixed properly. The note card was told not to fade in, but the row it
  replaces was never told not to fade *out*, so the old glyphs kept dissolving on top of the new card
  for a third of a second. That is the "ghosts from the pill" when the note pop-up opens. Both
  directions are now instant, so two states are never on screen together

## [3.0.7] — August 2026

**The pill grows into the note card again, instead of snapping**

- The animation is back, and this time the ghosting has a named cause. Apple's documentation says
  `glassEffect` anchors Liquid Glass to a view's *bounds*. Every previous attempt animated the
  shell's frame, so every frame of the morph defined a new glass body and the system cross-faded the
  old one against the new — which is exactly the doubled, overlapping pill that got the animation
  deleted eight times. The identity the earlier release added to prevent it could not: that API is
  documented as applying when a shape appears or disappears during a view hierarchy change, not as a
  way to interpolate one body's size. It was the wrong tool, applied correctly
- So the glass now lives in a rectangle it never leaves, and the pill's outline animates inside it.
  One body, one set of bounds, a silhouette that grows. The glass edge is regenerated from the new
  outline each frame, which is why this works where masking the finished card down to a pill would
  not: a mask removes pixels and cannot recreate the lit edge, so the pill would read as a flat
  cut-out. Scaling was no good either, since the pill and the card have different proportions and a
  stretch would turn the rounded corners into ellipses
- The card's contents are still revealed by the growing outline rather than faded in over the
  previous state, because that fade was a second, independent cause of doubling
- Reduce Motion still gets the instant, single-render version
- The curve is unchanged: a 0.46s spring with no bounce, which was already measured for this travel

**Two more things the companion was doing every second**

- Checking whether something full-screen is in front took 2.30 ms on the main thread every second,
  most of it copying a description of every window on the system. That is a dropped frame per second,
  and it landed right where the pill's animation needed the run loop. The check moved off the main
  thread; only the decision to move the character stayed on it
- Working out which character pack to draw allocated a list of every installed pack, 30 times a
  second, to answer a question whose answer changes when you pick a different character. It is
  worked out once now and recomputed when packs are added or removed

Whether the morph now looks clean is a visual judgement only you can make.

## [3.0.6] — August 2026

**The app should feel faster. Five causes, each measured**

- The speech model is no longer held in memory forever. It was built at launch and released only at
  quit, which left an 869 MB footprint on an idle menu-bar app — and two thirds of it was not even
  resident: 667 MB sat in swap, including four 128 MB blocks that were 100% paged out. macOS was
  already evicting the model; it just evicted it somewhere that still cost address space, constant
  page-ins and a stall on the next dictation. It is now released after five minutes unused and
  reloaded on demand. Two hidden costs went with it: whisper keeps a GPU thread alive asking the
  kernel to keep those buffers resident (the single largest source of idle CPU in the whole app,
  measured, running whether or not you were dictating), and because Utter sits in the system's
  keystroke path, page faults on that much swapped-out memory are a plausible cause of typing lag
  everywhere, not just here
- The live transcript preview reads the last ten seconds instead of re-transcribing your whole
  utterance from the beginning every 0.7 seconds. The work grew as the square of how long you had
  been talking, so by 30 seconds a single pass took longer than the gap between passes and previews
  started crowding out the real transcription. Ten seconds is about what the card can display anyway
- Sounds no longer stall the app. Each one rebuilt an entire audio pipeline and then started the
  audio device synchronously on the main thread — about 31 ms frozen per sound, and the companion
  answers your keystrokes, so this fired as often as three times a second while you typed. Sounds
  are now loaded once and played off the main thread
- Call detection moved off the main thread. Asking CoreAudio which apps are using audio measured
  4.70 ms, over half a frame, every two seconds. The interval is unchanged, so nothing about
  detection got slower
- The pill stopped redrawing ten times a second to update a timer that changes once a second

The morph animation was also switched back on in this build, but on the old mechanism — 3.0.7 is the
one that fixes why it ghosted.

## [3.0.5] — August 2026

- Fixed a crash that could end a meeting recording partway through. Meeting capture transcribes in
  rolling 30-second windows and trims each one from its audio buffer once it has been written to the
  note. That trim left the buffer's internal indices shifted, so reading the next window back went
  out of bounds and crashed — which hit any meeting longer than about a minute, on the second
  window. The buffer is now rebased when it is trimmed, so reads stay in range; this also releases
  the used audio immediately instead of carrying it for the rest of the meeting

## [3.0.4] — August 2026

- The pill and note-card morph is now an instant, clean state change instead of an animated
  expansion. The animated morph was rebuilt many times and kept ghosting — every version produced
  intermediate frames where the glass re-rendered and the system cross-faded two overlapping
  copies. With no animation there are no in-between frames to ghost: the pill and the card are each
  a single clean render. Less flashy than a liquid expand, but correct. The hands-free bead, hover
  and tint keep their animations

## [3.0.3] — August 2026

- The pill's ghosting should be gone: the glass is no longer rebuilt on every frame of the morph
  (which made the system cross-fade two overlapping copies), and the note card no longer fades its
  text over the previous state's. The morph's sizes and shape are unchanged — only how the glass is
  drawn. Needs an on-device look to confirm; and if closing now feels too abrupt, that is a known
  follow-up, not a return to the fade that caused the ghost

## [3.0.2] — August 2026

- The hands-free button no longer flees the cursor. Moving from the pill toward the button crossed a
  gap that belonged to neither, so the button retracted mid-reach; it now holds through the crossing
- The pixel companion is cheaper to draw — it no longer rebuilds its sprite on the ~3 of every 4
  frames that show the same image, and it skips an offscreen compositing pass except while overheating
- Note: the pill-to-note-card morph still has the visual glitches (ghosting, stray outline). That fix
  is not in this build

## [3.0.1] — August 2026

**The note pop-up no longer jumps around**

- It was resizing and sliding erratically — sometimes smaller, sometimes bigger, sometimes drifting
  down and back up. Root cause: the pill's window was the only one in the app that never told its
  hosting view to stop sizing itself from its SwiftUI content, so the window silently chased the
  content's ideal size. The previous release made that size animate continuously, which turned a
  latent race into constant window chatter. Fixed with the one line every other window already had.
  A test now drives the morph 50 times and proves the window frame is identical every run

**The companion**

- Typing reactions: the cat only ever sees your keystrokes through a monitor that needs
  Accessibility permission. Without it, macOS silently delivers nothing and the cat can't react —
  no code fixes that. Utter already shows a warning in Companion settings; it now also logs a
  once-a-second line you can watch (`log stream --predicate 'subsystem == "utter.dictation.app"'`) that
  says whether keystrokes are reaching it. The typing pose itself is rebuilt as a four-frame hammer
  on the keycaps, and only plays while you actually type
- Dragging no longer jitters. The ambient motion was animating the character's offset underneath
  your live drag, so it fought the cursor; ambient motion now freezes while you drag, and the
  character moves 1:1 and settles anywhere on screen
- The cat can walk across the desktop — a real step cycle that moves the window and turns at the
  edges, not an in-place shuffle. Frozen under Reduce Motion and while dragging
- Long notification text in the speech bubble wraps and stays readable instead of being clipped to
  a middle fragment
- Both pixel packs regenerated with proper walk and typing frames

Whether the animations and art actually look good is a visual judgement only you can make.

## [3.0.0] — August 2026

First major version. What changed since 2.0 is less a feature list than a change of kind: Utter
started as a dictation transport that typed into whatever was frontmost, and it now keeps what you
say.

**Notes, and dictating into them**
- Notes are real records with their own file, titles, and no cap on how many you keep — not a single
  overwritten buffer living in the preferences blob
- A chord dictates straight into a note instead of into the frontmost app, with every correction
  stage applied identically, so a note is never second-class text
- The pill transforms into a note card while you dictate, showing the words landing

**Meetings**
- Captures both sides of a call and transcribes them into a note, labelled "You" and "Others" —
  which is exact, because it is two audio sources rather than a guess about voices
- Prefers a Core Audio process tap, which asks for *system audio recording* rather than Screen
  Recording, and captures only the meeting app instead of the whole system mix
- Notices when you are in a call and offers to transcribe it. It offers; it never starts

**The companion**
- A pixel character that reacts to what is actually happening — real audio levels, real keystrokes —
  with eyes that follow the cursor

**Liquid Glass**
- The pill, its hands-free bead and the window chrome are the system material, grouped and morphed
  through the platform's own APIs rather than approximated with blurs

**And roughly a hundred fixes**
- Including a crash that killed the app whenever you spoke loudly enough, two paths that silently
  lost notes, controls that were visible but could not be clicked, and permission prompts that asked
  twice or told you to do something impossible. The details are in the 2.0.x entries below

## [2.0.105] — August 2026

**The pill now actually transforms into the note card**

- Both axes of the shell are one animated value at last. The height was an explicit number that
  interpolated; the width was a *layout recomputation* from the content's ideal size, resolved
  above the animation — so the right edge arrived in a single frame and only then did the top edge
  start travelling. That is the jitter, and it is why this never read as one shape expanding
- Four earlier fixes were all real defects — a duplicate state change firing two morph transactions,
  a synchronous window resize on the animation's critical path, two competing animation drivers on
  one shell, and content filling before the shell had grown — but none of them was this one, which
  had been filed as speculative and never confirmed
- Closing changed too, and this is the part to watch: it used to hold the card's full width through
  the shrink and snap narrow at the very end, which is probably *why* closing always looked right —
  the snap was hidden behind an animation that had already finished. It now interpolates the whole way

**Settings has real glass, and a layout bug that had been there all along**

- The Settings navigation column is now the same material as the main window's sidebar. It was the
  only chrome layer in the app of the same kind as one that had already been converted
- Fixed a dead line that AppKit was silently discarding: the window set its hosting view's frame from
  `contentLayoutRect`, and a view framed at 528 comes back 560 immediately after assignment. SwiftUI
  was therefore honouring a 32pt titlebar safe area that stacked with the 30pt toolbar band, so
  Settings content had been starting ~32pt lower than intended. Glass would have made it obvious — a
  floating pane with a see-through strip above it
- Onboarding, What's New and sheets deliberately get no glass. Onboarding's nav buttons already *are*
  glass, so a band behind them would be glass on glass; What's New is content top to bottom with no
  controls; and what floats about a sheet is its window, which has no glass API to give it

## [2.0.102] — August 2026

**Liquid Glass, across the whole app rather than just the pill**

- The main window's chrome layer had no Liquid Glass in it at all. The sidebar drew nothing — a
  comment said "the sidebar IS the window surface" — and the shell was a frosted pane plus a
  coloured fill. The sidebar is now real glass, and the inset content card, its hard clip, its
  three-sided rim and both its insets are gone: the window is one continuous plane with glass
  floating on it, which is what Apple's shell actually is. The card's material moved up to become
  that plane, so every content pixel kept its tone; only the sidebar strip changed
- Sidebar and Settings rows used to get *darker* on hover and then jump light on selection — the
  pointer moved in two directions on one control, because the hover wash inverts per appearance
  while the selection is a white lift. Both now use one tested type whose ordering is
  backdrop-independent: a lift over any backdrop is monotonic, so no theme, wallpaper or material
  can reorder rest, hover and selected
- Removed the glass-on-glass in the meeting offer card: glass buttons on a glass card become
  vibrant fills, which is what Apple prescribes for controls sitting on a glass surface. Its border
  went too — it was drawing a second rim on three of four render paths and fighting the material's
  own moving highlight on the fourth. It gains a shadow where the material cannot supply one
- Seven no-op glass containers deleted. Each wrapped views with no glass in them while carrying a
  comment claiming a performance win
- Seven hand-tuned translucency recipes became five named tokens. Settings was 4–5 points thinner
  than the window that opened it, which is why it read cooler

**Contrast and legibility, measured**

- Accent-coloured text on an accent wash measured **2.58:1** on the default theme against a 4.5:1
  floor — worst on a numbered instruction, where the numeral is the content. The token built for
  exactly this case takes it to 8.06:1. It failed on one theme of six, because that theme's accent
  is tuned to read as a fill
- Tile header icons defaulted to the accent, putting a glyph at **2.95:1** under a 3:1 floor and
  making the accent mean nothing where 78 of them appeared at once. Colour is now reserved for
  glyphs that report something
- Keycaps drew the hotkey name on glass at 11pt. Text on Liquid Glass loses subpixel antialiasing —
  roughly 3× softer glyph edges — and the component 260 lines away in the same file already refused
  this case for that reason
- Replaced the system secondary label, which measured **4.01:1** on this app's surfaces, and the
  non-appearance-aware red/green/orange literals

**Things that were broken rather than untidy**

- **Reset Utter could not be reached.** The only reset path in the app lived inside a view with no
  callers, while the copy told you a button below would do it. Restored, in Settings, where the
  source says it was meant to be
- Three text fields had no focus ring at all — a keyboard-accessibility gap, not a styling drift
- `.controlSize(.small)` on a glass button did nothing: the style pinned its own size closer to the
  control, so five call sites were silently ignored. Size is a real parameter now
- Reduce Motion was honoured on the small movements and ignored on the largest ones, including a
  200pt panel collapse and every list insert that slid rather than faded
- 22 system separators replaced with the warm hairline the design system exists to provide. One
  stays: inside a context menu it is the API for a native separator
- What's New rendered 77 entries, 55 of them placeholder filler. Filtered by matching the filler
  text, so future placeholder entries filter themselves, and the version chip now marks the version
  actually running rather than assuming the newest entry is it

**Records that lied**

- Four comments, including the design system's own header and the README, claimed the sidebar and
  window surface were Liquid Glass. They were a frosted material and a fill. Two contradictory
  comments sat 20 lines apart on one property
- Deleted dead code that misdescribed the system: an unused tab component whose doc claimed the app
  used it everywhere, two colour tables the pill no longer painted with, two orphaned layout
  constants, and the generic tint helpers whose last callers were those tables

## [2.0.100] — August 2026

**Meetings can now be captured without the Screen Recording permission**

- Utter prefers a Core Audio process tap, which asks for *system audio recording* instead. These
  are two separate permissions with two separate prompts — verified against the system's own TCC
  strings: "would like access to record your system audio" versus "would like to capture the
  contents of the system display". Only the first describes what Utter does with it
- It also captures only the meeting app rather than the whole system mix, so Spotify, notification
  chimes and Utter's own speech no longer land in the transcript
- Screen Recording remains the fallback. The tap route has to actually deliver audio within 1.5
  seconds before it is committed to, so on any machine where it does not work the behaviour is
  exactly what shipped before
- Needs macOS 14.2; older systems use the fallback

**The offer card names the call**

- "You're in a Zoom call" rather than "You're in a call", read from the bundle ID of the process
  actually doing the audio — not from what happens to be running
- The app name never gates detection, only labels it. A call in an app nobody has heard of is
  still detected, because the rule is "some process has both input and output running", which
  needs no list. A browser meeting is named after the browser: Google Meet in a tab genuinely
  cannot be distinguished from a YouTube video
- Recognised apps are corrected rather than looked up, because the system's own names are wrong
  for the ones that matter — macOS reports `us.zoom.xos` as "zoom.us", and Chrome's audio helper
  has no name at all. Everything else falls back to the system name, which is why the list is
  five entries instead of fifty
- Fixed a bug this created: a longer title wraps in the card, and a wrapped title pushed the
  buttons below the window's bottom edge — the same defect the card's height calculation was
  written to prevent. The title is now measured too

**Permissions read honestly**

- Screen Recording no longer shows a warning dot and a Grant button when you have never asked to
  record a meeting. It gets a neutral state with a reason instead, and only becomes a warning once
  meeting capture is switched on or a capture has actually been attempted
- Distinguished three ways rather than by colour alone — a hollow ring instead of a filled dot, a
  text link instead of a button, and a line saying why — so it survives colourblindness and reads
  correctly in VoiceOver
- All three permission rows had an identically named "Grant" button, so VoiceOver offered three
  indistinguishable controls. Each is now named

**Dependencies**

- whisper.cpp 1.9.1 to 1.9.2. Checked before trusting it: the C API diff is additive only, the
  framework's platform slices are unchanged, and every symbol the app calls is still present
- Pinned swift-testing exactly. It was on an open upper bound and moved from 0.10.0 to 0.99.0 on
  its own during an unrelated rebuild — a test dependency that can change version silently makes a
  green suite prove less than it looks like it does

**"Offer to transcribe calls" did not work. Two of these seven fixes are why it could not be used
at all.**

- A podcast on AirPods counted as a call. The check asked CoreAudio whether the default input device
  and the default output device were in use, but that property is device-wide with no direction in
  it, and on AirPods, on most headsets and on any aggregate device those are the *same* device. So
  both questions returned one answer and "the microphone is open and audio is playing" collapsed into
  "something is using this device". It now asks which *processes* are running input and output, per
  direction, and leaves Utter's own process out of both by process id, rather than by a check
  elsewhere remembering to
- On a Mac whose audio system will not answer that per-process question, the feature switches itself
  off and says so in the log. It does not fall back to the old signal, because offering to record
  other people on half the evidence is worse than not offering at all
- The card's two buttons were laid out below the bottom edge of its own window, where nothing draws
  and no click lands — it was created 96pt tall for 133.5pt of content, and the 37.5pt that did not
  fit was the button row. So the offer appeared and could not be accepted or declined. Its height is
  now derived from the same spacing and type tokens the card lays out with, and a test measures the
  real text and fails if it stops fitting
- "Not now" re-offered the same call five seconds later, and kept doing it — roughly 540 cards over a
  45-minute meeting. Declining now silences that call until the call actually ends, and only that call
- Pressing Transcribe without Screen Recording permission was a dead end: it dismissed the card,
  asked for a permission macOS prompts for only once, and said "then try again" when nothing was left
  to try it on and granting it needs a relaunch anyway. The card now stays until a capture is really
  running, and carries the reason it could not start
- Accepting could record everyone on the call with nothing on screen saying so. The only feedback was
  a 2.5-second pill notice, and with "always show the pill" switched off the pill had already been
  ordered away, so the success *and* the failure were invisible. It now opens the Notes screen, where
  the recording banner, the elapsed time and the Stop button are, and leaves it open for the capture
- Sleeping and waking mid-call skipped the five-second debounce whose whole job is to sit out a chime,
  because the timing ran on the wall clock and inherited an interval that had accrued while the
  machine was asleep. It runs on a clock that does not advance during sleep and cannot go backwards

## [2.0.97] — August 2026

- Onboarding's "Open System Settings" no longer puts a second dialog in your way. It was doing two
  things on one click: raising macOS's own "Utter would like to control this computer — grant
  access in Privacy & Security settings" modal, *and* opening exactly that pane. So the system's
  advice was already obsolete when it appeared, and the modal sat in front of the pane covering the
  switch you had come to flip. The screen now opens the pane and nothing else
- It also bypassed the once-only guard on the launch check, so finishing onboarding could raise a
  second prompt for a permission you had just been shown where to grant
- Both routes go through one place now, with one rule: the app either opens the pane or raises the
  system dialog, never both. Screens that explain themselves open the pane; the launch check may
  raise the dialog, once, for a returning user with no onboarding in front of them

## [2.0.96] — August 2026

**Your data folder was renamed.** (The app was renamed to Utter later; `AppDirectory` migrates
the old `Lumen` folder.)

- Renamed, and migrated rather than orphaned: on first launch the old folder is moved to the new
  name. A rename on the same volume is what `FileManager.moveItem` performs, so it is atomic —
  there is no moment where half your notes are in one folder and half in the other. If the move
  fails the app keeps using the old folder rather than starting empty beside it
- If both folders somehow exist — an older build run after a newer one — they are deliberately
  *not* merged. Two files of the same name would mean choosing which notes to overwrite, and there
  is no basis for that choice
- Six stores each spelled the folder name out for themselves, and one of them
  (`ModelStore`) had already been changed to `Utter` — so the app was writing to two different
  folders depending on which store you asked. One owner now holds the name

**Security pass, for a local-only app**

- The data folder is created owner-only (0700). It was inheriting the process umask, which is
  world-readable; `Application Support` being 0700 meant nothing could actually traverse in, but a
  folder holding dictation transcripts should not depend on its parent for that
- Notes keep one generation back, as `notes.previous.json`. Atomic writes prevent a *torn* file
  and moving an unreadable file aside prevents it being overwritten, but neither helps against a
  write that succeeds and is wrong. Notes are the only thing here that cannot be recreated from
  something else. It is a plain readable copy on purpose: recovery must not need the app that
  broke it
- Removed a force unwrap that every one of those six stores carried — `urls(for:in:).first!` on a
  lookup that is permitted to return an empty array. It never has, which is exactly why it would
  have been an unexplained launch crash if it ever did
- "Delete all my data" now also removes the pre-rename folder, so it means everything rather than
  everything under the current name

## [2.0.95] — August 2026

**The companion's eyes now actually follow the cursor.**

- The aim was divided by a fixed 220 pt reference distance and then clamped per axis, so any
  cursor further away than that pinned both axes to ±1 — the eyes snapped to one of four 45°
  diagonals and stopped responding to the mouse at all. Measured error against the true bearing
  was up to 33°. It now divides by the actual distance, so the direction is exact at any range;
  re-measured across eight cursor positions, worst error 0.00°
- This is the same defect the corrected eye-aim test describes from the other side: per-axis
  clamping puts the pupil √2 outside its socket on the diagonals

**Mochi rebuilt from measurements rather than from memory**

- The reference sprite is flat two-tone — one near-black and one white, no third fur tone — and
  what had been built was a four-tone shaded chibi with light eye-rings and pink inner ears. A
  different animal. Rebuilt flat, and it took four visual passes because each miss was only
  visible by looking at it
- Small white eyes with a hard square pupil, which is also why the reference reads as tracking so
  well: a 2px pupil moving inside a 5px white field changes a fifth of the eye, where an iris that
  already fills its socket barely appears to move at all
- Whiskers extend past the silhouette again — they only failed previously because a shaded rim
  gave them something to merge into
- Ears are the head's top corners with a notch between them. Drawn as spikes on a flat-topped
  head they read as insect antennae however carefully the bases line up
- Pear body, curled tail, feet with a gap. Aspect ratio measured and corrected: the reference is
  0.91, the first rebuild came out 0.79 — too narrow and upright — and it now sits at 0.85
- The typing animation has a keyboard to type on. The keystroke signal was always correct; two
  paws bobbing over empty space is simply ambiguous. Mochi now rests its forepaws on a three-key
  keyboard with the pressed key visibly depressed, cycling across the keys as you type

## [2.0.93] — August 2026

- Opening the note card now reads as the pill *becoming* a card. The content was laid out at its
  final size on the first frame and revealed by the shell's clip, so what was on screen mid-morph
  was a horizontal band through a complete card — fragments of header and transcript — which reads
  as something uncovering text that was already there, followed by the rest snapping into place.
  The shell now grows as an empty glass card and the content fades in once it has arrived, which
  is exactly what closing does in reverse and why closing always looked right
- The fill is a delayed transition rather than a flag set from the growth's completion handler: a
  transition ends at fully-visible however it is interrupted, where a completion callback that
  fails to fire would leave the card permanently blank
- The two halves of the morph can no longer drift apart unnoticed — the growth duration and the
  fill's delay are named constants with a test pinning that the fill lands inside the growth
- Fixed the companion's eye-aim test, which asserted the one answer that breaks its own promise.
  The pupil is drawn at a fixed radius times the aim vector, so the vector has to be unit length
  for the eyes to stay in their sockets; the test expected per-axis clamping, which is 1.41 times
  too far out on the diagonals

## [2.0.92] — August 2026

**Fixed a crash that killed the app mid-sentence.**

- Talking loudly enough to produce a full-scale audio sample crashed Utter. The
  voice-activity scan used `abs()` on a 16-bit sample, and `abs(-32768)` has no representable
  result in a 16-bit signed integer, so Swift trapped on overflow — on the audio render thread,
  where there is no recovery. -32768 is not an exotic value: it is full-scale negative, which
  loud speech and any clipping conversion produce. The same trap was in the silence-trimming
  pass twice more. All three now measure magnitude in a type that can hold it, and there are
  tests pinning the exact sample that crashed

**The hands-free bead**

- The bead is now part of the pill's own silhouette rather than a second glass object placed
  near it: one shape, one outline, which is what stopped the stray edges. It extrudes from the
  capsule's trailing end through a necked fillet, pinches off, and merges back on the return
- This replaces the previous approach, which relied on the system blending two separate glass
  bodies. That only worked on macOS 26 with transparency enabled — it was a plain passthrough
  under Reduce Transparency and on earlier systems, so three of the four render configurations
  got no liquid at all
- The note-card morph is driven by one animation instead of two. The shell's height was
  animated by a modifier attached inside the pill while its width was resolved above that
  modifier, so the two axes rode separate animation instances of the same curve — phase-locked
  only until a frame was dropped, and the frame they disagreed on put the contrast ring a point
  off the glass. That was the "jittery" as distinct from the "too fast"
- Expanding into the note card uses a slower, bounce-free curve than the capsule-to-capsule
  changes, since a fourfold height change is where overshoot is visible

## [2.0.91] — August 2026

- The hands-free bead no longer appears long before the pointer reaches the pill. Hover was
  being measured against the whole window — which is now permanently tall enough for the note
  card — so the pointer up to 96pt above the capsule, and well to either side of it, counted as
  hovering. It is measured against the drawn capsule again
- The bead now detaches from the pill instead of staying joined to it: the neck stretches and
  thins through 30 of its 32pt of travel, then pinches off, and merges back the same way on the
  return
- Fixed the stray outlines that appeared around the pill and the note card mid-transform. The
  shell is one glass element whose shape animates from a 56x28 capsule to a 292x124 card, and
  inside a glass group it had no stable identity — so the group resolved its geometry against
  shapes the shell no longer had, which drew as edges leading the real elements. Both the shell
  and the bead now carry a `glassEffectID`

## [2.0.90] — August 2026

- The hands-free button is now genuinely liquid: the pill's own glass body stretches out and
  necks into a circular bead, instead of a button sliding out from behind it. Both the capsule
  and the bead draw real Liquid Glass inside a `GlassEffectContainer`, so their fields merge —
  that neck-and-pinch is Apple's own effect, not an imitation of it
- Tucked away, the bead sits exactly inscribed in the capsule's rounded end, so it adds nothing
  to the pill's outline at rest. Its glass stays at full strength the whole time and only the
  record glyph fades, which is what makes the movement read as the pill extending rather than
  as something appearing next to it
- The bead no longer draws its own border while the glass is real. Two outlined circles sliding
  through each other was what betrayed the merge — an outline belongs to a silhouette, and
  mid-merge there is only one. The border comes back under Reduce Transparency and before
  macOS 26, where the material is opaque and genuinely needs one

## [2.0.89] — August 2026

Fourteen bugs found by a nine-lens code review of everything recently touched, each one
confirmed against the code before being fixed.

**Data that was being lost**

- Dictating into a note that was open in the Notes screen, then switching tabs, erased the dictation — the editor held a stale copy of the note's text and wrote it back over the new words
- A crash or power loss while saving history wiped the entire history instead of one entry; history and streak files are now written atomically, and an unreadable file is preserved rather than overwritten by the next dictation
- Starting a dictation while a meeting was still finishing silently deleted the dictation's opening seconds
- A capture that recorded no usable audio ended silently, with no chime and no message, so nothing appeared to have gone wrong

**The note card**

- Opening the note card is no longer jittery. The real cause was not the animation: `⌃⌥N` set the pill's state twice in one runloop turn, so the second call ran its animation inside the first call's window resize and the pill ran two morph transactions for one state change. Closing it only ever fired once, which is why only opening looked wrong
- The pill's window no longer resizes at all — it is now permanently tall enough for the card. That removes the resize from the animation's path, and with it the class of crash that killed 2.0.84
- A failed microphone start no longer leaves the pill wedged open as a note card that is recording nothing, with the error never shown
- The card now shows live transcript when a running hands-free session is redirected into a note, instead of reading "Listening…" for the whole capture

**Controls that could not be used**

- The hands-free stop button was visible but unclickable whenever a session was latched from the keyboard without the pointer on the pill — the button was drawn from one rule and the window's clickable area from another
- With live preview on, the stop button was drawn past the edge of its own window and clipped in half
- Every switch in Settings was unnamed to VoiceOver
- The tooltip and VoiceOver action on the stop button said "Start hands-free dictation"
- Right-clicking the empty space around the pill opened the pill's menu
- Brushing the dictation hotkey during a note capture reported "Couldn't start the microphone" over a recording that was working fine, and tore down its timer, meter and preview

**Reduce Motion and Reduce Transparency**

- Turning either on now takes effect immediately instead of at the next launch — the app was listening on the wrong notification centre, so it never heard the change
- The Settings segmented control animated *only* when Reduce Motion was on; the branches were inverted

**The companion**

- The character no longer freezes on a mid-blink frame when it falls asleep, and its animation restarts properly when it wakes
- An error caption could stick above the character for the rest of the session; captions now expire on the same clock as everything else
- Long error messages were clipped to a centred fragment; they now truncate inside the bubble
- The character stood 48pt above the pill it is meant to sit beside, because it read the capsule's position off the middle of the pill's window
- Dragging the companion to a second display no longer sends it back to the primary one on relaunch, or whenever a display changes

**Under the hood**

- Note captures are no longer reformatted for whichever app happens to be frontmost — that formatting belongs to text being typed into that app, not to a note
- The companion's random behaviour is now seedable, so its tests are reproducible instead of failing about one run in a hundred
- Removed dead code left behind when the hands-free button moved out of the pill

## [2.0.87] — August 2026

- The note card now grows out of the pill when it opens, matching the way it shrinks back when it closes — the card used to be drawn at full size on the first frame, hiding the animation behind it
- The hands-free button is Liquid Glass like the pill, with the same tint and edge, and morphs out of the pill's edge instead of appearing beside it

## [2.0.86] — August 2026

- The hands-free button now pops out beside the pill as its own circular button instead of sitting inside it — the microphone stays centred and the pill never changes size or shifts
- Hovering anywhere on the pill reveals it, and it stays put while you move onto it to click
- The pill grows smoothly into the note card and shrinks back again, without the crash that animation caused in 2.0.84

## [2.0.85] — August 2026

- Fixed the crash when starting a note — the smooth pill-to-card animation added in 2.0.84 invalidated the window's layout mid-display-cycle and AppKit killed the app
- The resting pill is a centred microphone again; the hands-free button appears beside it on hover, as it did before 2.0.84

## [2.0.84] — August 2026

- The pill now grows smoothly into the note card and shrinks back into the pill, instead of the card appearing all at once
- The pill is fixed in place — it cannot be dragged, and it no longer shifts sideways when the hands-free button appears
- Hovering anywhere on the pill reveals the hands-free button; the companion's window no longer covers the pill's left half
- The stop button stays visible for the whole hands-free recording instead of hiding until you hover
- The companion's window is now sized to the character instead of being twice as large, so it stops swallowing clicks near the pill
- Removed leftover references to a cloud AI service the app no longer uses

## [2.0.83] — August 2026

- The companion now rides inside the note card while you dictate a note, instead of standing beside the pill where it could overlap
- Drag the pill anywhere and it stays — it no longer snaps or jumps after you let go
- The whole pill is hoverable now: the record button appears wherever you point, not only near one end
- No more dead zone — a click beside the pill or the companion passes through to whatever is behind, instead of being swallowed; only the pill and the character take clicks
- A stop button appears on the pill while hands-free is recording, so a click can stop it
- Fixed: the pill was briefly unclickable for a moment right after a note card closed
- New “Keep dictation history” setting — turn it off to stop Utter logging what you dictate
- Dictated text no longer appears in internal debug logs
- The privacy page now states the facts accurately: one optional model download, and Screen Recording used only for meetings
- Reset now names your notes and installed characters before it deletes them
- Removing a downloaded speech model no longer edits the app itself, which could quietly reset your permissions
- Utter now declares its minimum macOS version, so an unsupported system gets a clear message instead of failing silently

## [2.0.80] — August 2026

- The companion is larger and easier to read — 52pt instead of 28, so its face and mood register at a glance
- Each character is sized on its own: a tall slim figure reads smaller than a round one at the same height, so it is drawn a little larger
- Characters redrawn from individual poses: consistent size between moods, nothing cropped
- The companion sits on the pill's line in every mood — the sleeping pose used to hang 8pt below it
- The companion is its own window now: drag it anywhere, independently of the pill, and it stays where you put it
- Four companion sizes to choose from, in the companion settings
- The Dog is now a golden retriever puppy, drawn pose by pose
- Every character now animates at the speed it was drawn for — sleepy was playing 60% too fast, celebrating 33% too slow
- Characters no longer float over the menu bar when the pill sits at the top of the screen
- The four code-drawn characters have been retired; the animated packs are the companions now
- Dictating into a note no longer types into whatever app is in front, and the pill shows when a note is the destination
- Pressing ⌃⌥N now grows the pill into a small note card: which note the words are going into, the words themselves as they are heard, and the chord that finishes it
- Say "start a new note" and the next thing you say goes into it — this never worked before
- Starting a meeting now tells you when the microphone could not be opened instead of recording only the other side
- A meeting window that fails to transcribe is retried rather than lost
- The window remembers its size and position again after being closed once
- Onboarding scrolls instead of pushing its buttons off the bottom at larger text sizes
- The installer window shows its background again instead of opening plain white
- Settings follows the theme the moment you change it, instead of when you next reopen it
- Settings and the setup window can be resized, and Settings remembers the size you chose
- The Hotkey settings card now explains hands-free and note dictation, and the voice commands that route into a note
- Hands-free without a chord — while you are dictating, keep the hotkey held and tap Space; the recording carries on after you let go, and the tapped key never reaches the app you are typing into
- Hover the pill and a record button appears; click it to start hands-free, no keyboard needed
- Setup resumes where you left it: granting Screen Recording makes macOS relaunch Utter, which used to send you back to the welcome screen
- “Show in Dock” off now really means no Dock icon — opening a window no longer adds one until you close it again
- No Dock icon flashes at launch any more
- The countdown line along the foot of the pill is gone; hands-free still stops on its own when you stop talking

## [2.0.72] — August 2026

- Panda and Dog companions now ship with the app — no setup, available on a fresh install
- Companion art is no longer cropped: full body, including hair, tails and legs
- Your own character packs still work, and override a shipped one of the same name

## [2.0.68] — August 2026

- Permissions now survive replacing the app — Utter is signed with a real developer certificate, so macOS keeps your Accessibility, Microphone and Screen Recording grants across updates
- Granting Accessibility takes effect immediately instead of needing a relaunch
- Fixed a crash risk in the microphone path when a recording stopped mid-buffer
- Quitting during transcription no longer hangs
- A meeting that produced no audio from others now says why instead of failing silently
- The companion is fully released when switched off

## [2.0.66] — August 2026

- Companion sits fully in view beside the pill and never overlaps it
- Companion moved into the main window, and offered once during setup
- Say “start a new note” or “continue the note” to route dictation by voice
- The note hotkey (⌃⌥N) is now shown where you would look for it
- Screen Recording for meetings is asked for during setup and listed with the other permissions
- Dictation history scrolls smoothly with a trackpad, however long it gets

## [2.0.65] — August 2026

- Notes — dictate straight into Utter with ⌃⌥N instead of into the app in front; notes are searchable, exportable to Markdown, and no longer a single overwritten buffer
- Meeting capture — records both sides of a call and files it as a transcript, labelled You and Others, transcribed on this Mac in rolling windows
- AI note actions — summarise, extract action items, clean up dictation, format as a document, or suggest a title, all on-device
- Desktop companion — an animated character beside the pill, with built-in designs or your own APNG sprite packs
- Onboarding now shows the pill working instead of describing it
- Diagnostics — crash reports are readable in Settings, with a link to Apple's symbolicated report
- Fixed: dictating during a meeting could type the whole meeting into the app in front of you
- Fixed: a transcription hiccup mid-meeting silently discarded 30 seconds of speech
- Fixed: a long meeting grew memory without bound; now flat
- Fixed: crash reports were unreliable exactly when they mattered, and suppressed macOS's own report
- Fixed: holding the hands-free chord toggled it repeatedly; the Right Control option fired on every Control shortcut
- Fixed: editing a note's body froze its automatic title for good

## [2.0.59–2.0.64] — August 2026

- Development builds during the work released in 2.0.65

## [2.0.51] — August 2026

### Changed

- The sidebar is now a fixed column. It no longer collapses, and the
  sidebar-toggle button is gone from the title bar — that button was supplied
  automatically by `NavigationSplitView` and kept changing position, so the
  split view was replaced outright.
- Redesigned the interface around Liquid Glass. The pill and the sidebar use the
  material directly; window and tile surfaces use a translucent standard
  material, which is what Apple's guidance calls for behind text. The bento
  layout is unchanged.
- Rewrote the four UI sounds. Softness now comes from the sound design — long
  raised-cosine attacks, lower fundamentals, exponential tails, no spliced tone
  changes — rather than from turning the volume down, so playback level went back
  up to a normal setting. Timbre measures 16-36% darker than before.

### Fixed

- The selected sidebar row was unreadable: its label measured 1.17:1 against its
  own background (4.5:1 is the minimum for body text). Now 12.1:1 in light and
  7.5:1 in dark.
- Unselected sidebar labels measured 3.9:1 on the translucent column, also under
  the minimum. Now 14:1.
- The main window opened at roughly 133x143 points, partly off-screen, once the
  split view was removed.
- A missing speech asset used to play louder than a present one.
- `scripts/generate_sounds.py` required numpy, which meant it could not run on a
  clean machine and the build silently shipped stale audio. It now uses only the
  standard library, and the build regenerates sounds when the script changes.

## [2.0.16] — July 2026

### Changed
- **Utter is now fully on-device.** Speech recognition runs on a Whisper
  `small.en` model bundled in the app; AI commands run on Apple's on-device
  language model. No account, no API keys, no network requests, no usage limits,
  and it works offline.
- Dictation latency dropped from a network round trip to roughly 0.3 s.
- Redesigned UI: native `NavigationSplitView` sidebar, a semantic token and
  typography layer, real empty states, and a Home screen showing live readiness
  instead of decorative cards.
- The floating pill now displays a real microphone level (previously an animated
  placeholder), names the active phase, surfaces error reasons, and visualises
  the hands-free silence countdown.

### Removed
- Every cloud service. Nothing is stored, bundled, or required to sign in.

### Fixed
- Scratchpad notes were silently discarded when switching tabs.
- "Clear All Data" left preferences, the streak, and custom commands behind.
- History exports were coerced to `.txt` regardless of chosen format, and a
  failed write was silent.
- Permission indicators in Settings never refreshed after access was granted.
- A fresh install ignored the macOS appearance setting.
- Fixed a data race reading voice-activity state across threads, and a dangling
  buffer pointer in silence trimming.

## [2.0.13] — July 2026

- Clipboard preservation: dictation now snapshots and restores all pasteboard content (images, rich text, files) instead of only plain text, and selection capture no longer clears the clipboard when nothing is selected
- Spoken punctuation is now an opt-in toggle (Settings → Behavior), off by default, using word-boundary matching so words like "period", "comma-separated", and "first thing in the morning" are never mangled

## [2.0.12] — July 2026

### Added
- **Custom Dictionary now improves transcriptions.** Dictionary words are
  applied as a post-transcription correction pass: exact terms get their canonical spelling
  and capitalization enforced (e.g. `kubernetes` → `Kubernetes`, `macos` →
  `macOS`), and close misspellings of long, distinctive words are fixed
  (`terrafrom` → `Terraform`). Short words are corrected for casing only, so
  ordinary text is never rewritten.
- **On-device language detection.** Each transcription's language is detected
  locally (Apple NaturalLanguage) and shown as a tag on the history entry.
- **First-run onboarding.** A guided flow walks new users through Microphone
  and Accessibility permissions, with live status that updates as access is granted.
- **Re-inject from history.** Paste any past transcription into the app you were
  last using, straight from the Home history list.

### Fixed
- **AI commands on selected text no longer corrupt your document.** Translate,
  Style (professional/concise/casual/formal), Fix grammar, Summarize, and custom
  replace-commands issued a stray Undo (Cmd+Z) that undid your last real edit
  when operating on a selection in another app. The undo now only applies when
  transforming Utter's own just-dictated text.
- **Failed AI commands surface an error** (error sound + error pill) instead of
  silently playing the success chime and doing nothing.

### Changed
- Removed a 100 ms main-thread stall in the AI-command paste path.
- Corrected misleading "auto = English" language messaging: Utter
  auto-detects the spoken language; a forced language is sent as a strong hint.

_(Consolidates builds 2.0.9–2.0.12.)_

## [2.0.4] — May 2026

### Added
- **Hands-free dictation**: press `Control+Option+Space` (⌃⌥Space) anywhere to
  toggle hands-free dictation. The recorder runs without holding any key and
  ends automatically after 3 seconds of silence (VAD), or by pressing the
  shortcut again. Works from idle, or upgrades an active push-to-talk
  session into hands-free without dropping audio.
- **Hands-free pill state**: orange tint plus a lock icon make it obvious when
  the recorder is locked on.
- **Custom AI commands**: users can now define their own voice triggers in the
  AI Commands view. Each command pairs a trigger phrase with a
  system prompt, an optional user-prompt template (`{{text}}` placeholder),
  and a replace-vs-append toggle.
- **Custom commands override built-ins**: matching runs against user-defined
  commands first, so existing phrases can be customized without code changes.
- **Dynamic snippet placeholders**: `[date]`, `[time]`, `[datetime]`, `[day]`,
  and `[clipboard]` are resolved at expansion time. Snippets without
  placeholders behave exactly as before.
- **Snippet placeholder chips**: the Snippets editor now shows click-to-insert
  chips for available placeholders, with a magic-wand badge on rows that use
  them.

### Changed
- `KeyMonitor` now also watches `keyDown` events to detect the global
  Control+Option+Space shortcut independently of the push-to-talk hotkey.
- `AudioRecorder` exposes `installVoiceStoppedCallback(_:)` so VAD can be
  attached mid-recording when entering hands-free mode.
- `PillWindow` exposes `currentState` so the hands-free toggle can branch on
  the current pill state.
- Settings → How to use copy updated to document the new gesture.

### Notes
- Push-to-talk behavior is unchanged: hold the hotkey, release to transcribe.
- The hands-free shortcut is fixed at Control+Option+Space (not customizable
  in this release) to keep it independent of the push-to-talk hotkey.

---

## [2.0.1] — April 2026
- Major UI overhaul — two-column Home with feature cards and history.
- 5 themes — Default, Midnight, Frost, Ocean, Ember.
- AI Assistant — translate, fix grammar, reply, summarize.
- Style commands — make it professional/concise/casual/formal on any text.
- Works on selected text in any app, not just dictation.
- What's New page with full version history.
- Custom menu bar icon.
- Dynamic version from build system, build ID tracking per release.

## [1.1.3] — April 2026
- Multiple themes (Default, Midnight, Frost, Ocean, Ember).
- What's New page with version history.
- Build ID tracking per release.

## [1.1.2] — April 2026
- AI Commands page replacing Style — full guide for voice commands.
- Clear All Data confirmation dialog.

## [1.1.1] — March 2026
- Context-aware formatting (code, chat, email, document detection).
- Auto-detect language with force option.
- VAD silence detection (later disabled for stability).
- Silence trimming with 200ms tail buffer.
- Crash reporter with disk logging.
- Ad-hoc code signing.

## [1.1.0] — March 2026
- Renamed to Utter with lightbulb icon.
- Multi-language support (20 languages).
- Voice commands — keyboard actions (undo, select all, new line).
- Configurable hotkey (Fn, Right Option, Right Command, Right Control).
- Dark/light mode toggle.
- History search and export (Markdown, CSV, Text).
- Privacy & Security page.
- Custom sounds for recording feedback.
- Pill position memory.
- Right-click context menu on pill.

## [1.0.0] — March 2026
- Initial release.
- Voice to text with Whisper.
- Floating pill UI with recording states.
- Menu bar integration.
- Transcription history with word count and streak.
- Dictionary, Snippets, Scratchpad.
- DMG installer with build script.
