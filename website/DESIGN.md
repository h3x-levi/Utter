---
name: Utter website
description: A picture-book cutaway town where your sentence travels from your mouth to the text box and never leaves the house.
colors:
  paper: "#FBFAF5"
  brick: "#C8402F"
  brick-face: "#B9392A"
  brick-deep: "#8F2B20"
  bus: "#F3C13A"
  bus-side: "#B98A1E"
  grass: "#4E9A4A"
  grass-hi: "#6DB466"
  sky-day: "#A9D5EE"
  glass: "#CFE6F2"
  sand: "#E8CE9C"
  wood: "#8C5A3C"
  outline: "#6B4A2E"
  ink: "#3A2616"
  ink-soft: "#5A4130"
  field: "#FFFDF6"
  note-cream: "#FFF3CF"
  note-mint: "#E3F1DF"
  error: "#A5301F"
  sky-dusk: "#C9A2BF"
  sky-night: "#3B4782"
  footer-night: "#232B52"
  lamp: "#FFE08A"
  grass-night: "#2F6B3A"
  road-night: "#B9A57E"
  sky-square: "#35407A"
typography:
  display:
    fontFamily: "Grandstander, sans-serif"
    fontSize: "clamp(44px, 3.6vw, 88px)"
    fontWeight: 800
    lineHeight: 1.04
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "Grandstander, sans-serif"
    fontSize: "clamp(40px, 3.3vw, 76px)"
    fontWeight: 800
    lineHeight: 1.04
    letterSpacing: "-0.02em"
  title:
    fontFamily: "Grandstander, sans-serif"
    fontSize: "clamp(24px, 1.4vw, 32px)"
    fontWeight: 800
    lineHeight: 1.15
    letterSpacing: "-0.02em"
  body:
    fontFamily: "Patrick Hand, Comic Sans MS, cursive"
    fontSize: "clamp(20px, 0.5vw + 13.5px, 27px)"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "Patrick Hand, cursive"
    fontSize: "21px"
    fontWeight: 400
  sign:
    fontFamily: "Grandstander, sans-serif"
    fontSize: "26px"
    fontWeight: 800
    letterSpacing: "0.04em"
  field-label:
    fontFamily: "Grandstander, sans-serif"
    fontSize: "0.82em"
    fontWeight: 700
    lineHeight: 1.2
  button:
    fontFamily: "Grandstander, sans-serif"
    fontSize: "clamp(19px, 0.45vw + 13px, 25px)"
    fontWeight: 700
    lineHeight: 1
  signpost:
    fontFamily: "Grandstander, sans-serif"
    fontSize: "clamp(18px, 0.4vw + 12px, 24px)"
    fontWeight: 800
    lineHeight: 1.1
rounded:
  note: "6px"
  letter: "8px"
  key: "12px"
  tile: "14px"
  button: "16px"
  board: "18px"
  pill: "999px"
spacing:
  page-pad: "clamp(20px, 4vw, 104px)"
  road-band: "76px"
  column-gap: "clamp(32px, 3.4vw, 96px)"
  row-gap: "clamp(28px, 3vw, 56px)"
  block-top: "clamp(84px, 7vw, 176px)"
components:
  button-primary:
    backgroundColor: "{colors.bus}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.button}"
    padding: "0.72em 1.15em"
  button-small:
    backgroundColor: "{colors.bus}"
    textColor: "{colors.ink}"
    rounded: "{rounded.tile}"
    padding: "0.62em 1em"
  chip:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "0.35em 0.9em"
  chip-hover:
    backgroundColor: "{colors.note-cream}"
  input:
    backgroundColor: "{colors.field}"
    textColor: "{colors.ink}"
    rounded: "{rounded.key}"
    padding: "0.5em 0.7em"
  letter:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.letter}"
    padding: "clamp(22px, 2.2vw, 44px)"
  notice-board:
    backgroundColor: "{colors.wood}"
    textColor: "{colors.paper}"
    rounded: "{rounded.board}"
    padding: "clamp(20px, 2vw, 40px)"
  notice-card:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.note}"
    padding: "16px 18px 14px"
  signpost-arrow:
    backgroundColor: "{colors.bus}"
    textColor: "{colors.ink}"
    typography: "{typography.signpost}"
    rounded: "{rounded.letter}"
    padding: "0.45em 0.5em 0.45em 0.9em"
---

# Design System: Utter website

The marketing site's world. It is separate from the macOS app's Mixtape system in `../DESIGN.md`. Source of truth: `public/index.html` (one file: inline CSS, JS and SVG). `npm run build` copies `public/` to `dist/`, which Vercel publishes.

## Overview

**Creative North Star: "The Picture-Book Cutaway Town"**

Each section is a building in one town, drawn as a gouache-flat dollhouse cross-section, and the reader walks down a single street from morning to night. The product story is told as a picture: your sentence goes from your mouth through the house's machinery to the screen, and the cloud van outside gets nothing. Copy sits beside the picture in large hand-lettered type, the same way a children's book puts a sentence next to the drawing.

Every drawn object has a thin warm-brown outline and a slight hand wobble. Every object that needs explaining gets a small printed label with a hairline pointer. Density is generous: the drawings fill the width and keep growing on wide screens, and the copy column stays narrow.

**Key Characteristics:**
- Hand-authored inline SVG on flat fills; no colour gradients, no generated rasters.
- One warm-brown outline (2.5px) holds every shape, in drawings and in UI chrome alike.
- The sky changes colour section by section from day blue to dusk to night.
- Each section ends on the same strip of grass, road and grass, which ties the town together.
- Dollhouse fronts swing open as each building scrolls in.

## Colors

Children's-book primaries (brick, school-bus yellow, grass, sky), softened onto paper white and held by one brown outline.

### Primary
- **School-Bus Yellow** (bus): the action colour. Primary buttons, the hold keycap, list bullets, selection highlight, the bus, lamps and pipes in drawings. The yellow says "press here", or marks something that carries your words.
- **Brick Red** (brick): roofs, curtains, focus rings, the input caret, required-field asterisks, notice-board pins and FAQ markers. Its darker shade (brick-deep) is the `em` colour for the second line of each headline in daytime sections.

### Secondary
- **Grass Green** (grass, grass-hi): ground strips, plants and the checked state of use-case chips (#CDE8C9).
- **Sky Blue** (sky-day, glass): the hero sky, plus window glass in every building.

### Neutral
- **Paper** (paper): letter, notice cards, chips, clouds, screens inside drawings.
- **Field** (field): input and option-tile fill, one step warmer than paper.
- **Ink / Ink Soft** (ink, ink-soft): headlines / body copy in day sections.
- **Outline** (outline): every stroke, border and pointer.
- **Wood / Sand** (wood, sand): floors, furniture, the notice board, the road.

### Night
Sections marked night (platforms, apply, FAQ) swap the custom properties: headline ink becomes paper, body becomes #E9E0CF, `em` becomes lamp yellow (lamp), and the grass and road darken (grass-night, road-night). Lamps in the drawings cast flat cones of lamp yellow at 14 to 30% opacity.

### Named Rules
**The Sky Clock Rule.** Each section sets its own `--sky`, in this order down the page: #A9D5EE, #B4DBEF, #C3E3F1, #D2E9EC, #F6D2A8, #F1BD97, #E8A98F, #C9A2BF, #A799CB, #4F5C99, #3B4782, #2F3A6B, then the footer at #232B52. A new section takes the next sky in that sequence; it never jumps back to day.

**The One Outline Rule.** Strokes and borders use outline (#6B4A2E) and nothing else: 2.5px on objects and UI edges, 1.4px for hairlines and pointers. Black is reserved for the robot (#141414) and dark screens.

## Typography

**Display Font:** Grandstander (variable 100 to 900, used at 700 and 800; fallback sans-serif)
**Body Font:** Patrick Hand (fallback Comic Sans MS, cursive)

**Character:** Grandstander is chunky hand lettering for headlines, signs and buttons. Patrick Hand is the neat handwriting for prose and the labels in the drawings. Both are self-hosted with `font-display: block`, so the hand-drawn look never swaps in late.

### Hierarchy
- **Display** (800, clamp 44 to 88px, 1.04): the hero h1 only; the `em` second line is set on its own line.
- **Headline** (800, clamp 40 to 76px, 1.04): one h2 per building. Balanced wrap; the second phrase is in `em` colour.
- **Title** (800, clamp 24 to 32px, 1.15): h3 inside copy.
- **Body** (400, clamp 20 to 27px, 1.45): copy paragraphs, capped at 40ch (46ch for split rows, 54ch on the board).
- **Label** (Patrick Hand 21px in SVG units, 17px for the small set): object labels inside scenes.
- **Sign** (Grandstander 800, 26px, +0.04em): shop names, building names and timetables painted onto the drawings. In-world signs can be uppercase with wider tracking (POST OFFICE, NOW SHOWING).

### Named Rules
**The Painted Sign Rule.** Uppercase and wide tracking belong only to signs painted on buildings and vehicles inside the SVG. HTML copy is always sentence case.

## Layout

- **Blocks:** each section is a full-bleed block, padded top by clamp(84px, 7vw, 176px) and on the sides by page-pad. The bottom is reserved for the 76px road band (a `::after` layered strip: grass, outline, sand road with paper dashes, grass).
- **Stages:** each drawing sits in a stage with a fixed aspect ratio (`--ar`, matching the SVG viewBox, mostly 1700 wide). The SVG uses `xMidYMax meet`, so buildings always stand on the road.
- **Side by side from 1200px:** `.side` blocks become copy (18 to 24rem) plus stage (the rest); `.flip` swaps the sides so the walk alternates. From 1600px the copy column widens to 26 to 34rem. From 1000 to 1199px the copy itself splits into a headline column and a body column above a full-width stage. Below 1000px everything stacks.
- **Hero:** min-height 100svh; from 1100px copy is 24 to 36rem and the house is width-limited by viewport height so it fits above the fold.
- **Mobile pans (760px and below):** the main nav hides; each scene sits in a horizontal scroller (`.pan`) at a minimum width of 1080px (760px for the hero house), bleeding to the screen edges. `data-focus` sets the initial scroll so each pan opens on its subject. A "Swipe the house to look around" hint appears. The reel and post office go full-bleed instead of panning.
- **Apply:** from 1200px the letter (24rem to 1fr, then 28 to 48rem at 1600px) sits beside the post office, whose height is synced to the letter's.
- **FAQ:** town hall (20 to 30rem) beside the notice board from 1300px; the cards auto-fill at min 21rem.

## Elevation & Depth

Depth mostly comes from the drawing: rooms behind walls, things in front of furniture. UI objects that are physical in the world (a letter, a pinned card, a sign on a pole) get a soft brown ambient shadow, offset downward with a negative spread, so they seem to sit just off the scene.

### Shadow Vocabulary
- **Button rest / lift** (`0 5px 12px -4px rgba(58,38,22,.45)` / `0 9px 18px -6px rgba(58,38,22,.5)`): primary buttons; the lift goes with translateY(-2px) on hover.
- **Letter** (`0 18px 34px -16px rgba(10,12,30,.55)`): the application letter against the night sky.
- **Notice card** (`0 8px 14px -8px rgba(0,0,0,.5)`): pinned FAQ cards.
- **Board** (`inset 0 0 0 10px #7A4C30, 0 22px 38px -20px rgba(0,0,0,.6)`): the notice board's inset frame.
- **Keycap side** (`0 5px 0 bus-side`, collapsing to `0 1px 0` when pressed): the drawn side wall of the hold key. Used only on the keycap.

### Named Rules
**The Lit-Object Rule.** A shadow means "this is a physical thing lying on the scene". Flat page chrome gets no shadow.

## Shapes

Shapes are rounded the way cut paper is: soft corners, never sharp, never fully pill-shaped except for chips. Radii run from 6px (pinned notes) through 8px (letter), 12px (keycap, inputs), 14px (option tiles), 16px (buttons) and 18px (board), up to 999px (chips). Every UI edge carries the 2.5px outline. Drawn objects share a turbulence filter (`#hand`, baseFrequency .035, scale 2.4) for the hand wobble; moving parts sit outside the filter so they animate cheaply. Repeating SVG patterns provide the materials: bricks, shingles, planks, pegboard, awning stripes, floorboards.

## Components

### Buttons
- **Primary:** school-bus yellow, ink text, Grandstander 700, 2.5px outline, 16px radius, ambient shadow. Hover lifts 2px; active sinks 1px and scales to .98. Disabled is .6 opacity with a progress cursor. Every primary action is labelled "Apply for beta".
- **Small:** same, smaller type and 14px radius; used in the header and for "Send another".
- **Ghost:** no fill; a 34px drawn play disc (paper, brick triangle) plus text. On hover the text gets a 2px brick underline at 5px offset.
- **Play disc:** a large yellow disc with a brown triangle, centred on the cinema screen. It scales 1.06 on hover and hides once the video starts with native controls.

### Hold key
A yellow keycap reading "hold" (Grandstander 800, 12px radius) with a hint beside it. Pointer down, Enter or Space on the key, or Space anywhere while the house is on screen (and focus isn't in a field) starts the demo. While held: the speech balloon fills, the dashed flow lines march, the gears turn, the pill's bars pulse and the robot plays "input". On release the words type out on the drawn screen, the pill turns navy with a check and the robot plays "success".

### Cutaway stage
A dollhouse cross-section: brick side walls, a shingle roof, rooms of flat colour divided by wooden floors, and the road at the base. Interactive or live parts (the reel poster, the robot slot, the typed text) are layered over the filtered drawing. Real app screenshots appear only inside drawn screens and kiosks.

### Facade
A brick-patterned front (with two glass windows and an arched wooden door) covers the stage. It swings open on its left hinge (`rotateY(-104deg)`, 1.25s, cubic-bezier(.3,.7,.2,1), then fades) when 32% of the building is visible. The hero opens once fonts load, then plays one short demo. Removed entirely under reduced motion.

### Labels with hairline pointers
Patrick Hand text in ink. A 1.4px outline-brown line runs from the label to a 2.5px dot on the object. Lower-case, short and literal ("mic on only while you hold"). Every object in a scene that needs explaining gets one.

### Chips
Paper pills with the outline. Hover turns them note-cream and lifts 1px. Used as the companion section's moment chips (one per group of moments, plus "Change its look" stepping through finishes and outfits) and as use-case checkboxes in the form (checked = #CDE8C9).

### Letter form (Apply)
The form is a letter: a paper card with an envelope flap above it (an SVG triangle) and a tilted stamp of the house carrying an UTTER/BETA postmark. Field labels are Grandstander 700 at .82em; inputs are field-coloured with the outline and a 12px radius, and focus shows a 3px bus-yellow outline. The OS options are tiles with small drawn icons (checked = #FFF0BD with an inset yellow ring). Errors appear in an `role="alert"` line, coloured #A5301F. On send, the envelope on the post-office counter flies off and the letter becomes "Your letter is in the post."
- **Form rule:** `PREVIEW` is true when the hostname is `localhost`, `127.0.0.1` or empty (`file://`). Only when PREVIEW is false does the form POST (no-cors) to the existing Google Form. The entry is always saved to localStorage, and a preview shows "Preview: nothing was sent."

### FAQ notice board
A wooden board with an inset frame holds a grid of `details` cards. Each card has a brick pin, and the cards rotate in a 3-step cycle: -1.2deg on paper, .9deg on note-cream, -.5deg on note-mint. The summary is set in Grandstander 800.

### Town square (community)
A night section between Apply and the FAQ (`#square`, sky `#35407A`), so the sky keeps darkening. The text column has a headline, one paragraph and three signpost arrows nailed to a wooden post: "Leave a review" (bus yellow, GitHub show-and-tell), "Suggest a feature" (paper, ideas) and "Ask a question" (grass-hi, q-a). Under them sits a quiet "Read what people are saying" link to the Discussions index. Each arrow is a plank with the outline and an 8px left radius; the tip is a rotated square behind the text. Hover lifts 2px. Every link opens a new tab with `rel="noopener"` and has a hidden ", opens GitHub in a new tab". The scene shows a striped bandstand with string lights, a lamp with a flat light cone, and a "DISCUSSIONS" board split into show and tell, ideas and Q & A. The pinned notes are blank scribbles, with someone pinning a new one and two people on a bench with a "?" bubble and a lightbulb. Labels in this section are paper on the night sky.
- **Honesty rule:** no quoted reviews, names, counts or star ratings anywhere. The page links to GitHub and loads nothing from it.

### Navigation
The header lies over the hero: the brand (42px icon with an 11px radius and outline, wordmark in Grandstander 800 at 32px), text links in ink-soft that turn ink with a brick underline on hover, and a small primary button pushed right. Hidden at 760px and below. The footer sits under a night skyline SVG of the town and the bus, with paper links that get a bus-yellow underline on hover.

### Motion
One easing for UI (`cubic-bezier(.2,.8,.2,1)`, 150 to 200ms). Ambient loops: clouds drift 70 to 90s, the robot bobs 2.6s, the caret blinks. Demo loops (flow, gears, rising letters, pill bars) run only while the hold key is down. `prefers-reduced-motion` turns off every loop, the facades and smooth scrolling, and the demo shows the full sentence at once.

## Assets and provenance

- `icon.png`: copy of `Assets/AppIconSource.png`, the app icon.
- `reel-16x9.mp4`: copy of `promo/Utter-Hype-16x9.mp4`.
- `reel-poster.jpg`: one frame extracted from `promo/Utter-Hype-16x9.mp4` with ffmpeg.
- `shots/*.webp`: copies of `Assets/screenshots/`, rendered from the app's SwiftUI snapshot suites.
- `robot/`: copies of the app's files, laid out like the app: `vendor/agent-robot-avatar/` (the CX ArtLab web component, MIT, LICENSE included), `companion-player.js` and `companion-moments.json`. Credited in the footer and companion section. A drawn robot symbol stands in if the component fails to load.
- `fonts/`: Grandstander and Patrick Hand, both SIL OFL, licence files alongside.
- Every scene illustration is hand-authored inline SVG. There are no generated rasters.

## Do's and Don'ts

### Do:
- **Do** draw every new section as a building on the road band, with the next sky from the Sky Clock sequence.
- **Do** hold every shape with the 2.5px outline (#6B4A2E) and put drawn parts inside the `#hand` filter.
- **Do** explain scene objects with Patrick Hand labels and 1.4px hairline pointers ending in a dot.
- **Do** use school-bus yellow for the one action in a view, and keep its label "Apply for beta".
- **Do** give every scene a full `aria-label` or `title` describing the picture, and keep live parts out of the filter.
- **Do** honour reduced motion by stopping loops and leaving facades open.

### Don't:
- **Don't** use colour gradients, glass effects, photographs or generated rasters in scenes; app screenshots appear only inside drawn screens.
- **Don't** use black strokes or hard drop shadows; the keycap's side wall is the only flat offset.
- **Don't** put uppercase tracked labels above HTML headlines; uppercase lives only on painted signs.
- **Don't** shrink scenes on phones; pan them at their minimum width instead.
- **Don't** let the form post from localhost, 127.0.0.1 or file previews.
