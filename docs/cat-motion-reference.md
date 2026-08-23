# Cat motion reference — measured numbers for the code-drawn cat rig

Reference spec for building a rigged, vector-drawn cat companion. Rig space is 100×100 units,
y up, ground at y = 0, facing +x (right). Rendered at 36–84 pt.

Everything here is expressed as a **ratio** — of shoulder height, of a bone length, or of the
gait cycle — so it drops into any rig scale and any stride rate.

## 0. How to read this

Every number carries a tag. Do not silently promote a tag.

| Tag | Meaning |
|---|---|
| `[M]` | **Measured** and published. The number is in a source, in the units given. |
| `[D]` | **Derived** — arithmetic I did on `[M]` values. The inputs are cited; the result is not in any paper. Recomputable from the formula given. |
| `[X]` | **Cross-study** — combines `[M]` values from different animals/populations. Directionally right, ±10% at best. |
| `[NF]` | **Not found.** No source. Do not fill this in by guessing. |

Tooling note: this was researched with **WebFetch** only — there is no WebSearch tool in this
environment, and Google/DuckDuckGo/Mojeek/Bing all bot-block or return junk. Literature came from
the Europe PMC REST API, Crossref, and direct fetches. **Where a source is paywalled it is said so
and the publicly available part is used.** Notably paywalled: Day & Jayne 2007 (403 on the
publisher PDF), Fischer et al. 2002, Fischer & Blickhan 2006, Boczek-Funcke et al. 1996,
Künzel et al. 2003 — for these, only the abstract was reachable, and only abstract-level claims
are quoted. TICA's breed standard is unreachable (robots.txt disallows this agent; host 403s).

**Provenance.** §§1–3, 6 and 7 were researched and the arithmetic run directly. §§4–5 were compiled
by delegated research passes against the sources named there; where a load-bearing citation was
re-checked, that is stated inline. **One bad citation was caught this way** — a reported "measured
cat limb phase = 0.30" turned out to be attributed to a dogs-only paper (see the warning box in
§2.1). Treat any figure in §§4–5 whose source is marked paywalled or second-hand as provisional.

**Master scale variable: `H` = standing shoulder height = standing hip height.** Fischer et al.
2002 report that in therian mammals the scapular pivot and the hip joint "sit at equal heights
above the ground" `[M]`, so one variable does both. The Persian standard independently asserts
the same thing ("having a height at the shoulders and rump about equal", ACFA) `[M]`.

Absolute anchor: **`H` = 25.98 ± 2.57 cm** for 37 adult European-shorthair-type cats (F 24.68 ±
2.4, M 27.09 ± 2.21) `[M]`, Poradowski et al. 2024. Measured with a zoometric stick on the
standing animal — though note the Methods never state landmarks, only the plain-language summary
does. This is the *only* measured feline withers height found anywhere.

---

## 1. Skeletal proportions

### 1.1 The headline result: two bones cannot reach the ground

From **one study, one set of 36–37 cats** (Poradowski et al. 2024 — so this comparison has no
cross-study error):

| | length | as fraction of `H` |
|---|---|---|
| femur + tibia | 22.19 cm | **0.854 `H`** `[D]` |
| humerus + radius | 19.80 cm | **0.762 `H`** `[D]` |

A two-bone hind leg spans **85%** of standing hip height; a two-bone front leg spans **76%**.
Even fully straightened, **the paw is 15% (hind) / 24% (fore) of `H` above the ground.** The
missing length is the third segment (metatarsus / metacarpus) plus the digits — a cat is
digitigrade and *walks on its toes*, so the digit segment is load-bearing, not decoration.

This is a structural fact, not a tuning problem. **Two-bone IK on a cat leg cannot be made to
work by changing numbers.** Four segments per limb are required.

### 1.2 Segment lengths normalised to shoulder height

Poradowski et al. 2024 publish a shoulder-height ÷ bone-length factor for each bone (they
rejected regression, R² < 40%, in favour of a multiplicative factor). Inverting it gives bone
length directly in units of `H`:

| Segment | fraction of `H` | source |
|---|---|---|
| **scapula** | 0.240 – 0.277 | `[X]` see 1.3 |
| **humerus** | **0.386** | `[D]` = 1/2.59 `[M]` |
| **radius** | **0.373** | `[D]` = 1/2.68 `[M]` |
| (ulna, for reference) | 0.439 | `[D]` = 1/2.28 `[M]` |
| **metacarpus + carpus** | 0.109 – 0.129 | `[X]` see 1.3 |
| fore digits | length `[NF]` | exists as a real segment — see note below |
| **pelvis (os coxae)** | **0.324** | `[D]` = 1/3.09 `[M]` |
| **femur** | **0.413** | `[D]` = 1/2.42 `[M]` |
| **tibia** | **0.437** | `[D]` = 1/2.29 `[M]` |
| **metatarsus / tarsus** | **0.285** | `[X]` see 1.3 |
| **hind digits** | **0.134** | `[X]` see 1.3 |
| calcaneus (heel lever) | 0.110 | `[D]` = 1/9.05 `[M]` |
| talus | 0.063 | `[D]` = 1/15.95 `[M]` |

Note **tibia > femur** (0.437 vs 0.413) and **ulna > humerus**. The distal bone of each proximal
pair is the *longer* one in a cat. Getting this backwards is one of the things that reads as
"lion" — big cats and dogs are not proportioned this way.

`os coxae` = 0.324 `H` is the pelvis length: use it as the length of the hip block in the spine
rig (§3.1), not a point.

**Fore digits are a real fifth segment with an unpublished length.** Rahmati et al. 2025 Table 3
lists five forelimb inertial segments — scapula, upper arm, forearm, carpals, **digits** (mass
5.1 ± 1.3 g, centre of mass 1.27 ± 0.41 cm from its proximal end) `[M]` — but Table 1 tabulates
lengths for only four. So the digit segment definitely exists and definitely bears load, and its
length is `[NF]`. The COM position gives a weak lower bound (> 1.27 cm ≈ 0.05 `H`). If a number is
needed, take it as a tunable initialised near the hind-digit ratio and label it unsourced in the
code; do not present it as measured.

### 1.3 Segments Poradowski did not measure

Scapula, metacarpus, metatarsus and digits are carried across from other studies via a bone both
studies measured. Two independent cross-checks on the shared bones agree to within 4%, which is
what licenses the transfer:

- tibia/femur: **1.092** (Prilutsky 2022) vs **1.053** (Poradowski 2024) `[M]`
- radius/humerus: **0.922** (Rahmati 2025) vs **0.968** (Poradowski 2024) `[M]`

Raw source values:

- **Forelimb, Rahmati et al. 2025 Table 1** (6 cadaveric limbs, 4.5–5.5 kg cats): scapula
  7.13 ± 0.25, humerus 9.95 ± 0.36, radius 9.17 ± 0.22, carpals + metacarpals 3.33 ± 0.19 cm `[M]`.
- **Forelimb in vivo, same paper Table 2** (7 live cats, 3.20 ± 0.34 kg, anthropometer): scapula
  5.77 ± 0.49, upper arm 9.28 ± 0.43, forearm 9.47 ± 0.46, carpals + metacarpals 2.61 ± 0.52 cm `[M]`.
- **Hindlimb, Prilutsky et al. 2022 Table 1** (5 cats, 3.27 ± 0.55 kg): thigh 96.6 ± 2.7,
  shank 105.5 ± 7.9, tarsals 66.5 ± 6.6, digits 31.4 ± 2.6 mm `[M]`.

**The scapula range is a real disagreement, not noise.** Cadaveric 7.13 cm vs in-vivo 5.77 cm on
comparable animals — the in-vivo anthropometer under-reads the scapula by ~19% because the
proximal border is buried in muscle. **Use the cadaveric value (0.277 `H`).** It is the one that
matches the bone.

### 1.4 The crouch factor — the number that decides whether the paws land

| chain | summed length | standing height ÷ chain |
|---|---|---|
| fore: scapula + humerus + radius + metacarpus | 1.165 `H` `[D]` | **0.858** `[D]` |
| hind: femur + tibia + metatarsus + digits | 1.269 `H` `[D]` | **0.788** `[D]` |

So at a normal stand the hind limb is folded to **~79%** of its fully-extended chain and the fore
limb to **~86%**. The hind limb is the more crouched of the two — build them with different
default flexion, not one shared value.

Corroboration that one crouch factor is safe across felids: Doube et al. 2009 report felids "do
not show limb straightening; rather bone allometry" `[M]`; Cuff et al. 2016 that felids "do not
change their crouched limb posture" across a 300-fold size range `[M]`; Day & Jayne 2007
(abstract) that "larger species of felids did not have more upright limbs than smaller species",
with only 3 of 24 angular variables shifting with mass `[M]`. A Persian is a small felid; the
crouch is the same crouch.

### 1.5 Measured joint angles (hind limb, walking cat)

Lecomte et al. 2021 Table 1, 4 cats, treadmill 0.4 m/s, n = 14 cycles, marker-based `[M]`:

| joint | at paw contact | at lift-off |
|---|---|---|
| hip | 92.2 ± 11.5° | 135.2 ± 13.7° |
| knee | 115.0 ± 6.4° | 118.4 ± 11.5° |
| ankle | 115.1 ± 10.1° | 139.3 ± 12.8° |
| MTP | 154.1 ± 8.1° | 155.0 ± 9.4° |

Markers: iliac crest, greater trochanter, lateral malleolus, MTP joint, toe tip. **The knee was
not marked** — its position is extrapolated from trochanter and malleolus, so the knee column is
the least trustworthy row. Forelimb angle curves exist in that paper but no numbers were
published for them: forelimb angles are `[NF]`.

Two cautions before using these to solve a pose:
1. **The sign/zero convention is not stated in a form that can be reproduced blind.** Kuhtz-Buschbeck
   et al. 1994 report cat MTP going "from ~230° to ~270°" `[M]` — angles above 180° — so
   conventions differ between labs. Do not trig a hip height out of these; use §1.4, which comes
   from a direct height measurement.
2. Note **knee barely changes** (115°→118°) while **hip and ankle sweep ~44° and ~24°**. Most of
   the visible limb motion is proximal. Fischer et al. 2002 say the same: the proximal elements
   (scapula, femur) "produce more than half of the propulsive movement of the whole limb at
   symmetrical gaits" `[M]`.

An independent reference posture, from a cat hindlimb model (Kim et al. 2022, parameters after
Ekeberg & Pearson 2005): **hip 65°, knee 90°, ankle 100°**, with "straight vertical" defined as
hip 135°, knee 180°, ankle 180° `[M]`. Different convention again — quoted only so an engineer
recognises it if they meet it.

### 1.6 Body, head and tail proportions

| ratio | value | tag |
|---|---|---|
| head length ÷ head-body length | **0.203** (M) / **0.204** (F) | `[M]` Fleming et al. 2020, n = 288/235 |
| head-body length ÷ `H` | **~1.94 – 2.12** | `[X]` |
| head length ÷ `H` | **~0.40 – 0.43** | `[X]` |
| tail length ÷ body length | `[NF]` | see below |
| caudal vertebrae, normal-tailed cat | **22** | `[M]` Xu et al. 2016, radiographed, small pedigree (kinked/short relatives 14–21) |

Fleming et al. 2020 (n = 568 Australian stray/feral cats): head-body length 551 ± 84 mm (M),
504 ± 74 mm (F); head length 112 ± 14, 103 ± 13 mm; mass 3.08 ± 1.24 kg `[M]`. **Their Methods
give no landmarks** — "measured with a dressmakers' tape (±0.5 cm)" is the whole definition. The
head ÷ head-body ratio is nonetheless robust because it lands on 0.203 and 0.204 independently in
the two sexes. The `÷ H` rows are `[X]`: feral Australian cats vs Polish indoor shorthairs.

**Tail length is a genuine gap.** Fleming (the largest external-morphometry dataset for *Felis
catus* found, n = 568) **did not measure the tail at all**. No paper defining a tail ÷ body index
for domestic cats surfaced. Wikipedia's caudal-vertebra counts are **self-contradictory and
uncited** (its skeleton diagram says 19–21, its body text 22–23) — do not use them. If a tail
length is needed, take it as a tunable and say in the code that it is unsourced.

### 1.7 Persian specifics

Persians are the one place where breed literature is quantitative, because brachycephaly is a
welfare topic.

**Skull** — Sieslack et al. 2021, CT, 69 Persian vs 10 domestic shorthair (DSH); all indices are
width ÷ length × 100, higher = more brachycephalic `[M]`:

| index | Persian | DSH | p |
|---|---|---|---|
| skull index (zygion–zygion ÷ inion–prosthion) | **94.55 ± 9.65** | **72.26 ± 2.27** | <0.001 |
| cranial index (euryon–euryon ÷ inion–nasion) | **85.20 ± 13.93** | **61.48 ± 2.73** | <0.001 |
| facial index (zygion–zygion ÷ nasion–prosthion) | **256.03 ± 35.40** | **186.64 ± 11.69** | <0.001 |
| craniofacial angle | 14.41 ± 7.65° | 20.27 ± 2.28° | **0.066 — not significant** |

Do not use the craniofacial angle as a discriminator; the authors' own p is 0.066 and in some
Persians the axes diverge so it is unmeasurable.

**Muzzle length** — Schmidt et al. 2017, 47 peke-face + 45 doll-face Persian + DSH. "Nose index"
= nasal bone length ÷ max cranial length `[M]`:

| | peke-face | doll-face | DSH |
|---|---|---|---|
| nose index | **0.15 ± 0.04** | **0.29 ± 0.08** | **0.46 ± 0.03** |
| cranial index (width ÷ length) | **0.97 ± 0.14** | **0.66 ± 0.04** | **0.63 ± 0.06** |
| relative interorbital distance (orbiton–orbiton ÷ skull width) | **0.28 ± 0.03** | **0.19 ± 0.02** | **0.15 ± 0.008** |

All pairwise p < 0.001. **A doll-face Persian's muzzle is ~63% the relative length of a normal
cat's; a peke-face's is ~33%.** The braincase is as wide as it is long (0.97).

> ⚠️ **Landmark trap.** Two incompatible "cranial index" definitions exist in this literature.
> Schmidt/Sieslack (euryon–euryon ÷ inion–nasion) gives ~61–63 for a mesocephalic cat; Ramos et al.
> 2021 (lateral cranium in the dorsal plane ÷ occiput-to-caudal-nasal-bone) gives ~52 for the same
> kind of cat. **Pin Sieslack 2021** — it is the only source with Persian *and* DSH values for all
> indices measured the same way on the same animals.

**Eyes** — extra-orbital globe volume as % of total globe volume: **Persian 39.9 ± 14.3%** vs
**DSH 9.9 ± 3.6%** (p < 0.0001) `[M]`, Sieslack 2021. Four times as much of the eye sits outside
the orbit. Each 1-unit rise in skull index adds 0.80% extra-orbital volume. Absolute globe
diameter for the Persian is `[NF]`. Mesocephalic orbit baseline for scale: orbital height ÷ skull
length 0.28 ± 0.02, orbital width ÷ skull length 0.39 ± 0.03, skull width ÷ length 0.67 ± 0.04
(Requicha et al. 2026, n = 24 European shorthair) `[M]`.

**Body mass** — 3,235 UK Persians under veterinary care: adults **3.9 ± 0.9 kg** (M 4.3 ± 0.8,
F 3.4 ± 0.7) `[M]`, O'Neill et al. 2019. Cross-check: Persian/Exotic median 3.4 kg (IQR 3.0–3.9)
vs all-breed median 4.2 kg, n = 355 `[M]`, Häggström et al. 2025. **Persians are among the
lightest breeds** — do not draw a heavy cat.

**Withers height for a Persian is `[NF]`.** The 25.98 cm figure is European shorthair type. The
standards say Persians are "low on the legs", so a Persian's `H` is *shorter* than 25.98 cm at
equal body length. Treat the leg-shortening as a tunable multiplier on `H` and label it unsourced.

**Ears, body and tail — verbatim breed standards** (all `[M]` as quotations; **no numeric ear
measurement for the Persian exists in anything reachable** — no pinna length, no spacing, no tilt
angle. Every registry uses relative language only):

- CFA (the only registry specifying a tilt): "**EARS:** small, round tipped, tilted forward, and
  not unduly open at the base. Set far apart, and low on the head, fitting into (without
  distorting) the rounded contour of the head."
- FIFe: "Small, round-tipped, well tufted on the inner side" / "Set very wide apart and rather low
  on the head."
- WCF: "The ears are very small and rounded, set low and wide apart on the skull."
- **ACFA — the single most useful line in any standard, because it is a ratio:** "Legs should be
  short, thick and heavily boned, **having a height at the shoulders and rump about equal to the
  length of the back**. In front view, forelegs should slant inward very slightly from breadth of
  chest."
- CFA body: "of cobby type, low on the legs, broad and deep through the chest, equally massive
  across the shoulders and rump, with a well-rounded mid-section and level back."
- CFA tail: "short, but in proportion to body length. Carried without a curve and at an angle
  lower than the back." (FIFe/WCF add "bushy", CFA/ACFA "brush very full".)
- CFA coat, and this is the note that matters for a vector silhouette: "The ruff immense and
  continuing in a deep frill between the front legs… **The long thick coat softens the lines of
  the cat and accentuates the roundness in appearance.**" GCCF repeats it verbatim.

So: *shoulder height ≈ rump height ≈ back length* for a Persian `[M]`, versus head-body ≈ 2 `H`
for a moderate cat `[X]` — but "back length" (shoulder to rump) and "head-body length" (nose to
tail base) are different spans, so these do not contradict. The Persian is short-backed **and**
short-legged. Numeric Persian body/leg morphometrics are `[NF]` — no study measures them.

Coat length in cm is `[NF]` for any domestic cat. The silhouette guidance is qualitative only:
immense ruff, deep frill between the forelegs, full tail brush, and the coat hiding the leg
joints.

---

## 2. The walk cycle, quantitatively

### 2.1 Footfall order and phase offsets

A cat walks a **lateral-sequence** symmetrical walk. Order `[M]`:

```
left hind → left fore → right hind → right fore
```

(Vincelette 2023 quotes "left hind, left front, right hind, right front"; Hutchinson & Pringle
2024 quote the same order for the elephant lateral-sequence walk.)

Hildebrand's **limb phase** (a.k.a. diagonality, lateral advanced placement) = the % of the
stride separating ipsilateral foot contacts, i.e. how far the fore contact follows the hind
contact on the same side. Bands, from Wimberly et al. 2021 `[M]`:

| limb phase | gait |
|---|---|
| 0–25 | lateral-sequence **lateral**-couplet (LSLC) |
| **25–50** | lateral-sequence **diagonal**-couplet (LSDC) |
| 50–75 | diagonal-sequence diagonal-couplet |
| 75–100 | "biomechanically unlikely and is rarely observed in nature" |

Verified phase convention, useful because it is unambiguous: "phase offset (**fraction of stride
between left-hind contact and contact of a given limb**)", and for a symmetrical gait "foot
touchdown and liftoff on the left side of the body being repeated **exactly half a stride later** on
the right side" `[M]` Polet & Bertram 2019. Muybridge stated the same sequence rule in 1899 — see
§5.2.

**A cat-specific measured limb phase was not found** `[NF]`. What is available:

- terrestrial mammals: mean **28.05, s.d. 13.08** (n = 105) `[M]`, Wimberly et al. 2021
- ancestral therian estimate **41.46** (in the LSDC band) `[M]`, same
- LSLC gaits are "common within large, long-legged terrestrial mammalian clades (Artiodactyla,
  Perissodactyla and **Carnivora**)" `[M]`, same
- an even four-beat "singlefoot" walk has limb phase **≈ 0.25** `[M]`, Vincelette 2023
- horse walk, for shape: lateral dissociation 23–27 %stride, diagonal dissociation −23 to −26
  %stride `[M]`, Rhodin et al. 2022
- coati (a carnivoran) uses "a lateral-sequence, lateral-couplet gait pattern typical of
  long-legged, highly terrestrial mammals" `[M]` Granatosky et al. 2024 (paywalled, abstract only)
- red panda "limb phase values are similar to those of (primarily terrestrial) Carnivora examined
  to date" — but the paper publishes no number `[M]` Plocek & Dunham 2023 (paywalled, abstract only)

**Recommendation: limb phase = 0.25, tunable over 0.20–0.30.** 0.25 is the even four-beat walk,
and three independent lines all point at or just below it for terrestrial carnivorans (Wimberly's
"LSLC common within Carnivora", the coati result, the terrestrial-mammal mean of 28 ± 13). A value
in the low twenties gives lateral couplets — ipsilateral pairs landing closer together — which is
what those sources describe; 0.30–0.35 gives diagonal couplets. Both are defensible; **0.25 is the
neutral choice and the only one that is a named gait.**

> ⚠️ **A citation to distrust, and the paper to read if you want to settle this.** A secondary
> research pass reported a measured **cat lateral-walk pair lag of 70%, i.e. limb phase 0.30**,
> attributed to *Maes et al. 2008, J Exp Biol 211:138–149, Tables 2 and 4*. **I checked that paper:
> it is a dogs-only study** — five malinois, 486 sequences, MeSH terms "Dogs" only, no mention of
> cats anywhere in the abstract. **That attribution is wrong and the 0.30 figure is unverified — do
> not cite it.** The paper that does cover cats is **Abourachid, Herbin, Hackert, Maes & Martin
> (2007), "Experimental study of coordination patterns during unsteady locomotion in mammals",
> *J Exp Biol* 210, PMID 17210971** — verified from its abstract: "We studied the interlimb
> coordination of **dogs and cats** moving on a runway with a symmetrical gait", and it defines fore
> lag (FL), hind lag (HL) and pair lag (PL). It is **paywalled with no PMC copy**, so the cat value
> could not be read. **If anyone gets library access to Abourachid et al. 2007, that one table
> supersedes the recommendation above.**

Limb phase must stay **below 0.40**. Verified numerically: for any LP from 0.15 to 0.35 the
support-pattern composition is identical (46% tripedal / 54% bipedal) because those fractions are
fixed by the duty factors alone — LP changes only *which* pairs are down together and *when*, not
how many feet. At LP = 0.40 four-foot support appears (6% of the cycle) and the gait starts sliding
toward a trot `[D]`.

Contact phases for limb phase `LP`:

```
LH = 0.00        RH = 0.50
LF = LP          RF = (0.50 + LP) mod 1
```

At `LP = 0.25`: **LH 0.00, LF 0.25, RH 0.50, RF 0.75.** Contralateral offset is exactly 0.50 —
that is what "symmetrical gait" means, and it is not a free parameter.

Mapped to the existing `(far-hind, far-fore, near-hind, near-fore)` tuple:

- near side = left: `[0.50, 0.75, 0.00, 0.25]`
- near side = right: `[0.00, 0.25, 0.50, 0.75]`

### 2.2 Duty factor — measured, and fore ≠ hind

Duty factor = stance duration ÷ stride duration `[M]` (Hutchinson & Pringle 2024). Four
independent feline datasets:

| source | n, method | speed | forelimb DF | hindlimb DF |
|---|---|---|---|---|
| Dowgray et al. 2024 | 53 cats, pressure walkway, overground | 0.69 ± 0.14 m/s | **0.64** (SD 0.035) | **0.60** (SD 0.024–0.026) |
| Weißig et al. 2025 | 14 cats, pressure treadmill | 2.4 km/h = 0.67 m/s | **0.622 – 0.628** | **0.590 – 0.592** |
| Rahmati et al. 2025 | 7 cats, overground | self-selected | **0.64 ± 0.01** | — |
| Zubair et al. 2016 | 3 cats, overground corridor | 0.49–0.65 m/s | **~0.60** (all limbs) | ~0.60 |

**Use forelimb DF = 0.63, hindlimb DF = 0.60** at a normal walk. The fore/hind difference is
consistent across every study and is driven by **swing**, not stance: fore swing 0.25 s vs hind
swing 0.30 s at near-identical stance (0.43 vs 0.44 s), Dowgray 2024 `[M]`. The hind leg spends
longer in the air.

One disagreeing source, worth knowing: Catavitello et al. 2018, pooling 35 quadruped species,
report stance **74 ± 4% fore, 69 ± 5% hind** `[M]` — much higher. Different species mix and
slower dimensionless speeds. The four cat-specific studies agree with each other and should win.

**Duty factor as a function of speed** — Dowgray 2024 mixed-model coefficients (v in m/s, weight
in kg, cats mean 4.9 kg) `[M]`:

```
DF_leftfore  = 0.677 − 0.053·v            (p < 0.001)
DF_rightfore = 0.668 − 0.040·v            (p = 0.059)
DF_lefthind  = 0.545 − 0.004·v + 0.012·weight   (v term n.s.; weight p < 0.001)
DF_righthind = 0.623 − 0.027·v            (p = 0.114)
stride_fore  = 0.392 + 0.124·v   metres   (p < 0.001)
stride_hind  = 0.419 + 0.106·v   metres   (p < 0.001)
```

Check at v = 0.69: DF_fore = 0.640, stride = 0.478 m — both match that paper's own medians.

**Trot:** the measured walk→run boundary for cats is where DF crosses 0.5, at
**~0.9 m/s** in intact cats `[M]` (Rybak et al. 2024, from Frigon-lab treadmill data). DF < 0.5
is a run by the standard criterion `[M]` (Hutchinson & Pringle 2024). **A measured feline trot
duty factor was not found** `[NF]` — the cat literature is almost entirely 0.4–1.0 m/s treadmill
walking. For shape only, horse values: trot DF 0.55 → 0.30, canter ~0.30, fast gallop ~0.20 `[M]`
(Vincelette 2023). If a trot is needed, use DF ≈ 0.45 and mark it unsourced; also change the
phasing — a trot is diagonal pairs in synchrony (limb phase 0.50).

### 2.3 Support patterns

With `LP = 0.25`, DF_fore 0.63, DF_hind 0.60 `[D]` (computed, §7):

```
3 feet @0.00 → 2 @0.10 → 3 @0.25 → 2 @0.38 → 3 @0.50 → 2 @0.60 → 3 @0.75 → 2 @0.88
```

- **46% of the cycle tripedal, 54% bipedal. Never 1 foot, never 4 feet, never airborne.**
- Eight support-pattern changes per cycle. This is the texture the current 2-beat implementation
  is missing (§6.3).
- Bipedal support alternates diagonal and ipsilateral pairs — Vincelette 2023 says exactly this of
  the horse walk: it "has bipedal support, alternating between diagonal and ipsilateral or
  tripedal support at all times" `[M]`.

**Validation against a measured quantity** — double-stance (both forelimbs down at once) is
`2·DF − 1` for a symmetrical gait:

| pair | predicted `[D]` | measured `[M]` (Weißig 2025) |
|---|---|---|
| fore | 26.0% | **25.0%** |
| hind | 20.0% | **18.2%** |

The model reproduces an independently measured number to ~1 percentage point. Keep this as a
regression check (§7).

### 2.4 Stride length, stride rate, and matching forward travel

| source | cats | speed | stride length | ÷ `H` `[X]` |
|---|---|---|---|---|
| Weißig 2025 | 14, 5.2 kg | 0.67 m/s | 51.8 cm | 1.99 |
| Dowgray 2024 | 53, 4.9 kg | 0.69 m/s | 48–50 cm | 1.85–1.92 |
| Lecomte 2021 | 4, 3.6–4.7 kg | 0.4–1.0 m/s | 48.2 ± 14.4 cm | 1.86 |
| Zubair 2016 | 3, 3.0–4.0 kg | 0.49–0.65 m/s | 36–47 cm (90% of strides) | 1.39–1.81 (small cats) |

**Stride length ≈ 1.9 `H`, range 1.7–2.0 `H`** across the measured walk band `[X]`. Step length is
half of it: 25.6–26.1 cm measured directly `[M]` (Weißig 2025).

**Stride frequency:** cycle duration 0.66 s (Dowgray) `[M]`, 0.692 ± 0.093 s (Rahmati) `[M]`,
0.594–0.768 s (Zubair) `[M]`; Zubair states stride frequency **1.25–1.75 Hz** and step frequency
**~3 Hz** `[M]`.

> ⚠️ **Do not compute stride frequency from Dowgray's stance+swing regressions.** I checked them:
> at v = 0.4 they imply stride ÷ cycle = 0.48 m/s against a stated v of 0.40 — 20% internally
> inconsistent. They are only self-consistent near 0.8–1.0 m/s. Use the kinematic identity
> instead, which cannot be wrong:
>
> ```
> stride_frequency = forward_speed / stride_length
> ```

**The anti-skate rule.** The paw's backward travel during stance, in world space, must equal the
forward travel of the body over one cycle. That is one equation:

```
stride_length_units = 1.9 × H                      (from measurement above)
stride_frequency_Hz = speed_pt_per_s / (1.9 × H × s)      where s = points per rig unit
```

For the 100-unit box rendered at `P` points, `s = P/100`. With `H = 40` units `[D]`:

| render | 1 unit | `H` in pt | stride (1.9 `H`) | natural walk speed (2.65 `H`/s) | stride freq at 42 pt/s |
|---|---|---|---|---|---|
| 36 pt | 0.36 pt | 14.4 | 27.4 pt | 38.2 pt/s | **1.53 Hz** ✅ in range |
| 48 pt | 0.48 | 19.2 | 36.5 | 50.9 | 1.15 Hz ✅ (slow walk) |
| 60 pt | 0.60 | 24.0 | 45.6 | 63.6 | 0.92 Hz ⚠️ below measured |
| 72 pt | 0.72 | 28.8 | 54.7 | 76.3 | 0.77 Hz ❌ |
| 84 pt | 0.84 | 33.6 | 63.8 | 89.0 | 0.66 Hz ❌ |

**42 pt/s is only a natural cat walk when the rig renders at roughly 36–48 pt.** Dimensionlessly:
cats walked 0.69 m/s ÷ 0.2598 m = **2.65 `H` per second**, and the slowest speed at which intact
cats stepped consistently is **0.4 m/s = 1.54 `H`/s** — below that they "showed inconsistent
stepping" `[M]` (Rybak et al. 2024). At 84 pt the rig's 42 pt/s is 1.25 `H`/s, i.e. **slower than
a cat can walk steadily.**

So: either **scale travel speed with render size** (`speed_pt_s = 2.65 × H_pt` for a normal walk,
1.54–3.46 × `H_pt` for the whole walk band), or hold 42 pt/s and accept that at large render
sizes the character is in a gait cats do not use — in which case raise duty factor toward 0.66
(the slow-speed value from the regression) and expect it to read as a stalk, not a walk.

### 2.5 Vertical oscillation of the body

Three things must be right: amplitude, **frequency relative to the stride**, and phase.

**Frequency — the point most often got wrong:**

| what is tracked | oscillations per stride | source |
|---|---|---|
| **midline trunk point** | **2** | `[M]` Zubair 2016 (cat): trunk marker "peaked twice (one peak mid-swing of each forelimb)" |
| a point on **one** scapula | **1** | `[M]` Zubair 2016 (cat): shoulder vertical "peaked once per stride"; Boczek-Funcke 1996: the scapular pivot rises and falls once per cycle |
| head, vertical | **2** | `[M]` Zubair 2016 |
| head, pitch | **2** | `[M]` Zubair 2016 |
| head, lateral / roll / yaw | **1** | `[M]` Zubair 2016 |
| horse withers and pelvis (midline) | **2**, and mutually out of phase | `[M]` Rhodin et al. 2022 |

There is no conflict between "shoulder once" and "withers twice": the shoulder marker tracks one
scapula so it cycles once per that limb's cycle, while a midline point is driven by both
forelimbs. **The body bob is 2 cycles per stride — one per forefoot pair — not 4, and not an
independent frequency.**

**Amplitude** — two independent routes converge on **~10% of `H`, peak-to-peak**:

- Cat, direct: head 1.4–1.7 cm p-p; shoulder 2.2–2.9 cm p-p; trunk marker 0.8 cm (one cat) `[M]`
  Zubair 2016. Shoulder ÷ `H` = **8.5–11.2%** `[X]`.
- Cross-species: hip vertical oscillation during stance **9.6 ± 3.8% of hindlimb length**, shoulder
  **11.4 ± 4.3% of forelimb length** `[M]` Catavitello et al. 2018 (n = 35 quadrupeds). Converting
  their limb length (thigh+shank+foot = 1.135 `H`; humerus+radius+metacarpus = 0.888 `H`) gives
  **10.9%** and **10.1%** of `H` `[D]`.

**Use 0.10 `H` peak-to-peak (±0.05 `H`).** At `H = 40` that is 4.0 units p-p, ±2.0 units.
Caveat: Catavitello does not state whether their figure is amplitude or peak-to-peak; it is being
read as peak-to-peak because that is what makes it agree with Zubair's explicitly-p-p value. Also
Zubair's cats carried a ~200 g head implant, "≈50% of the weight of an intact head", which shifted
head COM 1.0 cm caudally and 1.7 cm dorsally — a real confound on the head amplitudes.

**Phase:**

- Body **highest at mid-stance**, **lowest around footfall**. Cat: the scapular pivot is "highest
  at mid-stance, lowest at mid-swing" `[M]` (Boczek-Funcke 1996). Horse: withers minimum at
  3.7–13% of forelimb stance, maximum at 42–48% `[M]` (Rhodin 2022) — i.e. min just after hoof-on,
  max at mid-stance. Walk mechanics are inverted-pendulum: "segments low at hoof-on, highest at
  midstance, descending to lift-off" `[M]`.
- Consequently, for a midline point at 2 cycles/stride: **minima near each forefoot contact
  (phase `LF` and phase `RF`), maxima near each forelimb mid-stance (`LF + DF/2`, `RF + DF/2`).**
- Down is faster than up: vertical velocity down −0.09 to −0.13 m/s vs up +0.06 to +0.07 m/s
  (p < 0.01) `[M]` Zubair 2016. **Ease the rise, drop faster** — do not use a symmetric sine.
- Trunk is near-horizontal throughout: quadruped mean trunk inclination **8 ± 7°** to horizontal
  `[M]` Catavitello 2018.

---

## 3. What makes it read as agile rather than mechanical

### 3.1 Spinal flexion

Two facts that together say: **do not flex the spine much at a walk, flex it a lot at a bound.**

- **At symmetrical gaits (walk, trot): small.** Fischer et al. 2002 (abstract; paper paywalled):
  forelimb kinematics are dominated by the scapula and "unaffected by speed or gait", and it is
  specifically **in in-phase (bounding/galloping) gaits** that "sagittal lumbar spine movement
  supplies roughly half of hindlimb step length" `[M]`. The implication for a walk — that the
  lumbar contribution is small — is the authors' framing, but **a measured numeric sagittal
  spine excursion for a walking cat was not found** `[NF]`.
- **At a gallop/bound: 27°.** Cheetah, 4 adults, 15–18 m/s: sagittal spine flexion–extension
  range **0.47 ± 0.029 rad ≈ 27°**, measured as the angle between the neck-root→T12 line and the
  T12→tail-root line; whole-body pitch fluctuation 0.20 rad ≈ 11.5°; COM height fluctuation
  0.057 m `[M]` Kamimura et al. 2022.
- **Available range is much larger than used range.** Osteometric mobility of the posterior
  dorsal/lumbar region in *Felis catus*: cumulative sagittal bending **97.6°** and **108.8°**
  (2 specimens); Felidae family means sagittal 95.1°, lateral 88.9°, axial 21.8°; felids have the
  highest lumbar share of the thoracolumbar column of any carnivoran family (47.4%) `[M]` Belyaev
  et al. 2024. **This is passive anatomical capacity derived from facet geometry, not gait
  excursion** — do not animate 100° of spine bend at a walk.

Practical spec: replace the straight hips→chest line with a **3-segment chain** — pelvis block
(length 0.324 `H`, §1.2), lumbar, thoracic — and drive it with a small sagittal bend at a walk
(single-digit degrees, tunable, unsourced magnitude) rising to ~27° peak-to-peak at a bound. The
axial-rotation figure (21.8°, low) says the cat's back twists far less than it bends: keep any
roll small.

Related: Higurashi et al. 2026 find feline **thoracic** torsional flexibility exceeds lumbar
(paywalled, title-level only) `[M]` — so if a twist is needed, put it forward of the lumbar spine.

### 3.2 The scapula — part of the outline, not a hidden joint

Boczek-Funcke, Kuhtz-Buschbeck & Illert 1996 implanted metal spheres on the scapula and used 3D
pulsed X-ray at 20 ms resolution on cats walking 0.33–1.2 m/s. **Paper paywalled; the abstract
gives the pattern but not the amplitudes** — angular amplitudes are `[NF]`. The pattern `[M]`:

1. **Pivot location:** the scapula rotates about a point "near the vertebral border at the medial
   extension of the scapular spine" — i.e. **the pivot is at the TOP of the scapula, against the
   trunk**, not at the shoulder joint. Rig it that way.
2. **Flexion/extension, once per cycle:** the glenoid (bottom end) sweeps caudo→cranially during
   swing and cranio→caudally during stance.
3. **The pivot itself rises and falls once per cycle** — highest at mid-stance, lowest at
   mid-swing. This is the visible shoulder-blade ride.
4. **Abduction/adduction is two-phase** within swing and stance.
5. **Yield:** after ground contact "the scapula yields relative to the trunk under the body
   weight". A brief downward give at contact — this is the single most life-like detail on the
   list and it is one line of code.

Corroboration on why the scapula matters: proximal elements (scapula, femur) "produce more than
half of the propulsive movement of the whole limb at symmetrical gaits" `[M]` Fischer et al. 2002.
A rig whose front leg starts at a fixed shoulder point throws away more than half the forelimb's
motion.

### 3.3 Head stabilisation — highest-value item on the list

All from Zubair, Beloozerova, Sun & Marlinski 2016, 3 cats walking 0.49–0.65 m/s `[M]`:

| quantity | value |
|---|---|
| head vertical translation, p-p | **1.4–1.7 cm** (≈ 5–7% of `H`) `[X]` |
| shoulder vertical translation, p-p | **2.2–2.9 cm** |
| **head ÷ shoulder amplitude** | **0.59 and 0.73** (cats 1, 2) `[D]` |
| head pitch amplitude | **2.7–3.4°** (~3°) |
| head roll amplitude | 1.5–2.9° |
| head lateral translation, p-p | 1.0–1.3 cm |
| static head attitude | **10–30° nose-down** (individually 10°, 17–19° at start, progressing to 25–30° by stride 3) |
| vestibular constraint | horizontal canals/utriculi kept **within ~10° of earth horizontal** |
| pitch angular velocity | 20–50 °/s |
| dominant frequency | ~3 Hz (= step frequency, 2× stride) |

**Implement: head vertical amplitude ≈ 0.6 × body vertical amplitude, phase-lagged.** Lags `[M]`:

- head vertical max lags shoulder/trunk vertical max by **20–90°** (20 ± 17°, 30 ± 4°, 88 ± 9°
  in the three cats)
- nose-up pitch lags head vertical by **38–93°**, peaking at end of swing
- nose-up peak lags shoulder/trunk vertical peak by **103–136°**
- head is highest in the **second half of forelimb swing**; vertical minima fall in the **first
  half of stance**
- head translates and rolls **left during right-forelimb swing, right during right-forelimb
  stance** (once per stride)

Honesty flags: in the third cat the head moved *more* than its (trunk, not shoulder) marker, so
"the head is always stiller" is not universal; and the ~200 g implant confound applies. But the
0.6× ratio plus the lag is what produces the read of a cat gliding while its body bobs. For scale,
the same paper's cross-species table: pitch 2–4° (cat), 5–6° (macaque), 8–9° (human); vertical
translation ~1.5 cm (cat/monkey) vs 5–9 cm (human).

Also worth having: the cat's gaze fixation point sat **12.6 ± 8.6 cm above ground in light** vs
**6.7 ± 6.0 cm in darkness** (p < 0.001), and the head was carried **0.5–2 cm higher in light**
`[M]`. A "looking around" idle can be built from real numbers.

### 3.4 Tail as counterbalance

- **Cats specifically:** cats "swing tails opposite to lateral perturbations, with fewer falls
  than tail-impaired cats" `[M]` — Walker, Vierck & Ritz 1998, as reported in Shield et al. 2021.
  Primary paper not directly retrieved; the claim is quoted at second hand and labelled as such.
- **At a walk, in a dog:** tail swishing "offset[s] pelvic COM translation in walking/trotting"
  `[M]` — Wada et al. 1993, again via Shield et al. 2021. This is the closest thing to a
  walk-cycle tail rule: **the tail swings laterally, opposing the pelvis's lateral shift.** Since
  the pelvis shifts once per stride (lateral motion is a 1-per-stride quantity, §2.5), **the tail's
  lateral swing is 1 cycle per stride, in antiphase with pelvic sway.**
- **Magnitude, cheetah:** tail flicks reach peak angular velocities of **18 rad/s** during rapid
  manoeuvres; modelled as a 0.75 m, 0.66 kg appendage `[M]` Shield et al. 2021. The tail's torque
  on the body reverses sign through the manoeuvre.
- **Numeric lag/follow-through for a tail is `[NF]`.** No source gives a body→tail phase lag in
  degrees or frames. Shield et al. explicitly "report no measured body–tail phase lag." Build it
  as a damped follower chain and expose the lag as a tunable; do not claim a source.

### 3.5 Ears and whiskers

- Numeric ear kinematics for cats: `[NF]`. No pinna rotation range, no ear-movement amplitude
  during locomotion in anything reachable. (Wikipedia's "32 muscles, 180° rotation" is uncited.)
- Whisker positioning in cats: `[NF]`, and this is a real gap rather than a failed search. Grant's
  2026 *J Exp Biol* review of mammalian vibrissal sensing mentions cats only four times — for a
  cold-temperature vibrissal reflex (Britton 1922), drug-induced breakage, and isotope diet studies
  — and gives **no** whisker count, length, arrangement, or movement data for felids `[M]`. The
  whisking literature is overwhelmingly rodent. Precise prey-directed vibrissal targeting is
  documented in the Etruscan shrew and task-specific vibrissal control in the California sea lion,
  **not** in cats.
- What *is* available is the facial-expression vocabulary (ear position categories, whisker
  positions) from the Feline Grimace Scale / CatFACS work — see §4.

---

## 4. Idle and play behaviours

Sources are published ethograms. **Two free primary sources do most of the work here:**

- **Kappel I, Riedel M-C, Becker F, Hicks S, Warlich-Zach N, Ganslosser U (2024). Ethogram of the
  Domestic Cat. *Pets* 1(3):284–314, CC BY.** 117 behaviours, domestic cat specifically, every
  entry purpose-illustrated. `mdpi.com` 403s; the CDN path works:
  `res.mdpi.com/d_attachment/pets/pets-01-00021/article_deploy/pets-01-00021.pdf`
- **Stanton LA, Sullivan MS, Fazio JM (2015). A standardized ethogram for the Felidae.** *Appl Anim
  Behav Sci*. The paper is paywalled but **the complete 124-behaviour ethogram is a free Elsevier
  supplementary DOCX**: `ars.els-cdn.com/content/image/1-s2.0-S0168159115001008-mmc3.docx`.
  (Commonly mis-cited as "Faulkner" — the third author is **Fazio**.)

> **Blanket duration warning.** **No published duration exists for a sit, a loaf, a stretch, a
> roll, a stalk, a pounce, or a play bout, nor bouts-per-hour for play** `[NF]`. Grooming is the
> only behaviour in this section with published time-budget numbers. Every hold time in the rig is
> therefore a tunable — label them as such in code rather than implying they are measured.

### 4.1 Sit

> "Cat is in an upright position, with the hind legs flexed and resting on the ground, while front
> legs are extended and straight." `[M]` Stanton et al. 2015

> "The cat sits with the hind part of its body completely on the ground. Its front paws touch the
> ground, and its front legs are fully stretched upward." `[M]` Kappel et al. 2024, Table 2.1

Joint-level restatement naming the joint: "the thoracic limbs extended and the pelvic limbs flexed
with **the tarsi in contact with the ground**" `[M]` Marangoni, Beatty & Steagall 2023, after
Stanton. **So: hock on the ground, hip and stifle folded, elbow and carpus extended, thorax
vertical.**

Tail placement in the sit is `[NF]` — the familiar tail-wrapped-around-the-forepaws arrangement is
not in any ethogram. Entry/exit transitions are `[NF]` except one startle marker: "moving from
crouching to standing in response to a low intensity stressor" `[M]` Ellis 2018.

### 4.2 Loaf

**"Cat loaf" is not a scientific term** — Europe PMC returns nothing on cats for it. The published
equivalents:

> "**Squat**: The cat touches the ground with all four legs. Its belly may touch the ground. **Its
> front paws are placed directly in front of its body.** Its head is upright, its neck may be bent
> and its ears are pointed forwards." `[M]` Kappel et al. 2024, Table 5.2 — the closest published
> match, and the only one specifying forepaw placement.

> "**Half lay on the side**: The underside of the cat's body touches the ground. The cat's front
> paws are extended forward, **sphinx-like**. Its body axis is turned to one side from the middle of
> the trunk. Its head is upright." `[M]` Kappel et al. 2024, Table 5.5

Two named sternal variants worth having as separate poses (tiger, not domestic cat) `[M]` Holland
et al. 2023: **sternal "sphynx"** — "lies down on the sternum, back legs parallel and orientated
forward"; **sternal "lunula"** — "lies down on the sternum, legs lie to one side".

**Loaf vs sit:** in the sit the thorax is *vertical on extended forelimbs* with the tarsi down; in
squat/sternal the **sternum and belly contact the ground** and the forelimbs are folded or extended
*forward* rather than propping up a raised chest `[M]`.

> ⚠️ **Do not tuck the forepaws under the chest for a relaxed loaf.** The only published
> paws-under-body description is a **fear** posture: "hold their body close to the ground with all
> four feet planted firmly on the floor in a ventral flat posture… The feet are often under the
> body and therefore not visible" `[M]` Ellis 2018. Kappel's Squat says paws **forward**.

Tail: Cat-Stress-Score level 1–2 (relaxed, inactive) = "extended or loosely wrapped" `[M]` Kessler
& Turner 1997, Table 2.

### 4.3 Stretch — the two-stage premise is not supported

**"Pandiculation" is a real published term** — "the involuntary stretching of the soft tissues,
which occurs in most animal species and is associated with transitions between cyclic biological
behaviors, especially the sleep-wake rhythm"; with yawning it forms the **stretch-yawning syndrome
(SYS)**, associated with "the arousal function… to reset the central nervous system to the waking
state after a period of sleep" `[M]` Bertolucci 2011; founding comparative paper Fraser 1989.

**But every cat and felid ethogram describes stretching as a SINGLE phase, and two of them say all
limbs move together:**

> "Cat extends its forelegs while curving its back inwards." `[M]` Stanton et al. 2015 — forelegs
> only, no hind-limb component, no phases.

> "The cat stands or walks while **extending all legs away from the centre of its body** and
> lengthening its torso." `[M]` Kappel et al. 2024, Table 6.2 — **all legs simultaneously**,
> explicitly not sequential.

**`[NF]`, after multiple search strategies:** any source describing a forelimb-then-hindlimb
two-stage cat stretch; any source describing a cat's hind legs extending one at a time; any
duration for a cat stretch. The "one limb after another" pattern is published for **poultry wings**
and as an *or*-list for **livestock** (Fraser via Golani & Kafkafi 2024) — **not for cats.**

**Recommendation: build the two-stage stretch anyway if it looks right, but label it as artistic
licence, not observed behaviour.** It is a widely believed cat fact with no ethogram behind it.
Kappel codes Stretch as an **event**, not a state — i.e. short — but gives no number `[M]`.

Pair it with the yawn, which *is* defined: "The cat sits, squats or stands, opening its mouth wide
and exhaling air… usually occurs in the context of rest and recovery" `[M]` Kappel et al. 2024.

### 4.4 Grooming

**Published order is a cephalocaudal *trend*, explicitly "moderate" — not a fixed chain.** This is
the most important nuance in the section.

> "There was a **moderate and significant cephalocaudal trend** to grooming." `[M]` Eckstein RA &
> Hart BL (2000), The organization and control of grooming in cats, *Appl Anim Behav Sci*
> 68(2):131–140.

**The actual region-by-region order is `[NF]`** — it sits in the paywalled body, and no OA copy
exists (ScienceDirect, Unpaywall, OpenAlex `best_oa_location: None`, and all 41 OA citing works
checked). Two sources confirm no fixed order is established: a 2021 veterinary thesis calls the
behaviour "plus variable que chez d'autres espèces", and a 2025 paper still poses it as an open
question in its title.

**The paw-lick-then-face-wipe, defined:**

> "Cat cleans itself by licking, scratching, biting or chewing the fur on its body. **May also
> include the licking of a front paw and wiping it over one's head.**" `[M]` Stanton et al. 2015

> "…**To reach its head, the cat licks its front paws and strokes them across its head and ears.**
> By otherwise directly licking each body part, the cat cleans its entire body." `[M]` Kappel et
> al. 2024, Table 5.6

Scratch-grooming uses the **hind** feet, and is anatomically restricted: "Scratching is limited to
the neck, the cheek, under, and behind the ears", "with the hind paw and claws half out" `[M]`
Titeux et al. 2018.

> ⚠️ **CatFACS "lip wipe" is not the paw wipe.** AD37 Lip Wipe = "The tongue wipes the lips from
> the mouth midline till the mouth corner"; AD137 Nose Lick = tongue "wiping the nose". **No
> CatFACS code describes a forepaw wiping the face** — FACS codes facial muscles only.

Quantities `[M]`:

| figure | value | source |
|---|---|---|
| oral grooming, % of total time budget | **4%** | Eckstein & Hart 2000, n = 11 videotaped |
| oral grooming, % of non-sleeping/resting time | **8%** | ibid. |
| sleeping + resting | 50% of budget | ibid. |
| scratch grooming ÷ oral grooming time | **~1/50** | ibid. |
| bouts covering more than one region | **91%** | ibid. |
| bouts covering 2–7 body parts | **95%** | Guillon et al. 2026 |
| grooming, % of 24 h, free-ranging farm cats | **15%** (sleep 40%, rest 22%, hunt 15%) | Panaman 1981 |
| post-deprivation rebound (3-day collar) | oral **+67%**, scratch **+200%** in the first 12 h | Eckstein & Hart 2000 |

⚠️ **The 4% and 15% figures disagree** — confined/videotaped vs free-ranging, different
denominators. Report both, do not average.

**Entry transition, sourced and quantified:** grooming follows sleep — "a significant negative
correlation between sleep/rest duration and latency to the subsequent grooming bout" `[M]` Eckstein
& Hart 2000. Useful contrast for two grooming animations: frustrated grooming is "quick, lasting
just a few seconds, intense and only involves one or a few parts of the body", versus rhythmic
contented grooming `[M]` Ellis 2018. **Mean bout duration in seconds is `[NF]`** (measured by
Guillon et al. 2026 but paywalled).

> The famous 4-phase, 25-movement "syntactic grooming chain" with per-phase durations
> (Phase I ~1 s, II 0.25 s, III 1–3 s, IV 2–5 s) is **rodent**, not feline — its published species
> list is "Mice, rats, gerbils, hamsters, guinea pigs, ground squirrels" `[M]` Berridge et al. 2005.
> Do not port it to a cat and call it sourced.

### 4.5 Play solicitation — there is no feline play bow

**A play bow is not documented in Felidae** `[M]`:

- Europe PMC: `"play bow" felid` → **0 hits**; all 17 hits for `"play bow" AND cat` attribute the
  bow to canids.
- The comprehensive 2021 cat-play review contains no play bow outside its canid references
  (Gajdoš Kmecová et al. 2021).
- Framed as an open question in 2022: "Future research should explore if FRCs display play signals
  (similar to the play bow in dogs)" `[M]` Vitale 2022.
- "there is no scientific evidence for metasignals associated with playing cats" `[M]`
  Gajdoš Kmecová et al. 2023.
- Even the play face is asserted but unvalidated: "It has been suggested that cats, like dogs, can
  use a play face… but this is a somewhat subjective description and to our knowledge this has
  never been established by scientific observation of domestic cats" `[M]` Gajdoš Kmecová et al.
  2021.

**Use West's eight patterns instead** (West M 1974, Social play in the domestic cat, *Am Zool*
14:427–436; quoted from Gajdoš Kmecová et al. 2021 Table 1, which reproduces his wording — the
OUP PDF is Cloudflare-blocked, so this is a verbatim secondary quotation) `[M]`:

- **Belly-up** — "lies on its back, its belly up, with all four limbs held in a semivertical
  position. The tail is straight back and may be moved back and forth… move the back legs in a
  **treading motion** and to make reaching or pawing movements with the front legs. The mouth is
  held open and the teeth are exposed."
- **Stand-up** — "stands near or over another kitten with its head oriented toward the head and
  neck region… mouth is open… may also raise one of its front paws."
- **Side-step** — "**arches its back, curls its tail upwards and walks sideways** toward or around
  another kitten or object."
- **Vertical stance** — "assumes a sitting position and then rocks back on its hindquarters, lifts
  its front paws off the ground and stretches them out perpendicular to its body… stationary
  bipedal position."
- **Horizontal leap** — "assumes a lateral position… arches back slightly and curves its tail
  upwards and toward its body then leaps off the ground."
- **Face-off** — "sits near another kitten and hunches its body forward, moving its tail back and
  forth, and lifts a front paw and moves it in the direction of the other kitten."
- **Chase** — "running after or from another kitten."
- **Pounce** — see 4.6.

**Sequence, published:** play "is often initiated by one cat pouncing on another who often responds
with a belly-up posture… belly-up and stand-off, together with face-off behaviour are regular parts
of the continuation of mutual social play, while it is **most commonly terminated by chasing and
arching**" `[M]` Gajdoš Kmecová et al. 2021, after West 1974.

Ontogeny, relevant if the companion is meant to read as adult: **side-step declines from 12 weeks**
because it resembles the adult defensive arched-back posture `[M]`; social play peaks weeks 9–14
`[M]` Mendoza & Ramirez 1987. **Play bout length and rate are `[NF]`.**

Stanton's own entries, useful as separate poses `[M]`: **Rear** "stands up on its hind legs with
forelegs toward or against"; **Arch Back** "curves back upwards and stands rigidly" (may include
piloerection); **Rake** "makes kicking movements with one or both hind legs against"; **Wrestle**
"can include pulling toward itself with its forelegs and perform raking movements with the hind
legs".

### 4.6 Pounce crouch — and the bum wiggle, which IS documented

**The crouch** `[M]`:

> "Cat is alert and positions the body close to the ground, whereby all four legs are bent, and the
> belly is touching (or raised slightly off of) the ground." Stanton et al. 2015

> "Its body is pressed to the ground and all four legs touch the ground. Its tail may twitch. Its
> head is also close to the ground, and **its neck is outstretched**. Its eyes are fixated on an
> object… pupils mostly wide open." Kappel et al. 2024, Table 6.3 ("Crouch")

> "**Stalk:** Slow, forward locomotion in a crouched position directed toward, with head kept low
> and eyes focused on." Stanton et al. 2015

**The most joint-precise description in existence** — Leyhausen P (1979), *Cat Behavior*, p. 6,
Fig. 2-2. ⚠️ Read from a third-party OCR'd scan of a copyrighted book; **verify page numbers
against a library copy before publishing** `[M]`:

> "When within **2 to 5 m**… it stops and takes up the watching posture: **The whole of its body
> lies flat against the ground; the forelegs are drawn back to form a sharp angle, with the elbows
> projecting above the shoulder blades and the paws directly below the shoulder joint, supporting
> the body. The body itself is slightly hunched, the sole of each hind paw lies flat on the ground,
> and the tail is either stretched straight out behind or it lies curved around the body, its tip
> twitching gently. The head is stretched forward, the whiskers spread wide, the ears erect and
> turned toward the front.**"

**"Elbows projecting above the shoulder blades" is the single most distinctive line in this
document** and is unbuildable with two-bone IK.

**The pre-pounce hindquarter movement is documented under three published names** — "bum wiggle"
and "haunch shimmy" have **no scientific standing**; use one of these `[M]`:

1. **"Wobbling"** (Klein 1930-31, via Leyhausen 1979 p. 6, indexed as `"Wobbling," 6`): "The hind
   legs move gradually farther back, the heels are lifted off the ground and away from the body,
   the hind paws begin to move up and down in rhythmic alternation and with increasing intensity
   until finally **the whole of the hindquarters rocks from side to side in this rhythm**. Usually
   this final level of intensity… can only be seen in the **playful exaggeration of a kitten**
   pretending to catch prey. **Adult cats with real prey make at best only the merest suggestion of
   a 'wobble.'** The tail is stretched out behind the body and the tip of it twitches with
   increasing violence."
2. **"Tipple"** — "After the cat actively and quietly sneaks up on the target, the cat quickly
   tipples with its front and hind paws while crouching low to the ground. This is usually
   immediately followed by attacking or jumping on the prey." Kappel et al. 2024, Table 6.4.
3. **"hindlegs treading"** — the standard ethogram wording, inside the Stalk/Crouch definitions
   (Barrett & Bateson 1978; Caro 1981). Stanton defines **Treading**: "Rhythmic, raising and
   lowering of paws so that cat is stepping in place."

**Intensity gradient to implement:** full hindquarter rocking = kitten/play register; a hunting
adult barely does it `[M]`. **No measured frequency, amplitude, cycle count or duration exists**
`[NF]`.

**The spring is FLAT and the hindquarters stay down** `[M]` Leyhausen 1979:

> "the cat finally springs on its victim, but **not from above in one single, powerful leap**…
> rather **it darts forward flattened against the ground**… Still flattened in exactly the same
> way, with its last bound it reaches its prey at ground level."

> "the final spring… is kept so short that **the hind feet can propel the forequarters, with paws
> outstretched, onto the prey without the hindquarters leaving the ground themselves**. This
> ensures postural steadiness… The hind feet are still planted firmly on the ground, thus acting as
> a brake."

Exception: in long grass "cats often make the same high, curved jump as a fox does when catching a
mouse". Pursuit gait is a "**flattened gallop**".

Compare Kappel's **Prey jump**: "jumps with outstretched front legs and lands on a prey animal…
Its back may be either completely round or stretched out, depending on whether the target is far
away or directly next to the cat" `[M]`.

Full predatory sequence `[M]` Leyhausen 1979 pp. 5–8: stalking run → watching posture → (second
stalking run) → watching posture → a pause "which may be short or long" (no figure given) →
preparation for the spring → flat spring. Success rate once initiated: **30%** `[M]` McGregor,
Legge & Jones 2015.

### 4.7 Rolling onto the back

**Feldman HN 1994, "Domestic cats and passive submission", *Animal Behaviour* 47(2):457–459 —
could not be retrieved in any form.** Closed access, and no abstract exists in Europe PMC,
Crossref, OpenAlex or Semantic Scholar (`is_oa: false`, `any_repository_has_fulltext: false`). All
22 citing works were traced. **Everything about Feldman's position below is second-hand.**

**Stanton et al. 2015 splits rolling into three behaviours, and this is the structure to build**
`[M]`:

> **Roll** — "While lying on the ground, cat rotates body from one side to another. During the
> roll, **the back is rubbed against ground**, the belly is exposed and all paws are in the air.
> Cat may continue rolling repeatedly from side to side."

> **Roll on Back** — "rolls onto its back and becomes stationary, with its belly exposed and all
> paws in the air. **The body is usually tense, and may be accompanied by hissing and ears back.**"
> ← agonistic/defensive

> **Play Roll on Back** — "rolls onto its back, with its belly exposed and all paws in the air,
> within a playful context. **All agonistic behaviors are absent** (i.e. hissing, ears back)."
> ← play

**The same limb configuration serves three states. The disambiguators are the FACE and the muscle
TENSION, not the pose.** That is a direct rig requirement: the roll needs a tension parameter and a
face channel, or it will read as fear when you meant delight.

Kappel adds a detail Stanton omits: "The cat's back touches the ground, and the front or rear part
of its body may be turned or tilted to one side. **Its head also rests on the ground.** Its belly
is exposed." `[M]` Table 5.3

**Which way the spine twists: `[NF]`.** The only sourced statement is Kappel's "the front **or**
rear part of its body may be turned or tilted to one side" — an axial twist between fore and hind
quarters, **direction unspecified in every source.** Pick one and mark it a choice.

Where it sits behaviourally, honestly `[M]` Gajdoš Kmecová et al. 2021: rolling on the back
"has been observed within intercat play by various authors… but also within affiliative and
agonistic contexts, where it may be interpreted as a potentially deferential, appeasement or
submissive gesture (De Boer 1977; **Feldman 1994**). Further research is required."

The defensive roll and its transitions `[M]` Leyhausen 1979: "If the attacker now comes closer
still, **the defensive cat rolls over on its back and turns its underside toward it**"; "If the
attacker strikes, the defender rolls over on its back and **parries with both forepaws**."
**Duration for any roll variant: `[NF]`.**

### 4.8 Ears, eyes, muzzle, whiskers — with the only published numbers

**Feline Grimace Scale** — Evangelista MC, Watanabe R, Leung VSY, et al. (2019), *Sci Rep*
9:19128, CC-BY. **These are the only published numeric feline facial measurements found anywhere**
(Table 1, control n = 20 vs painful n = 31, mean ± SD, all p < 0.001) `[M]`:

| measurement | relaxed | painful |
|---|---|---|
| ear tips ÷ bases ratio | 2.85 ± 0.3 | 2.34 ± 0.3 |
| eye height ÷ width ratio | **0.79 ± 0.1** | **0.50 ± 0.2** |
| muzzle height ÷ width ratio | **0.70 ± 0.1** | **0.50 ± 0.1** |
| **medial ear angle** | **126.5 ± 4.7°** | **140.4 ± 6.5°** |
| **lateral ear angle** | **78.9 ± 3.1°** | **68.5 ± 5.9°** |

Its 0/1/2 descriptors give a directly poseable 3-step scale per feature `[M]`: ears "facing
forward" → "slightly pulled apart" → "rotated outwards"; eyes "opened" → "partially closed" →
"squinted"; muzzle "relaxed (round shape)" → "mild tension" → "tense (elliptical shape)"; whiskers
"loose (relaxed) and curved" → "slightly curved or straight (closer together)" → "straight and
moving forward (rostrally, away from the face)"; head "above the shoulder line" → "aligned with"
→ "below the shoulder line or tilted down". Reliability caveat from the authors: muzzle and
whiskers are the least discriminative and least reliable AUs.

**CatFACS** — Caeiro CC, Burrows AM, Waller BM (2017). Manual free at
`animalfacs.github.io/CatFACS/`. ⚠️ `catfacs.com` is a squatted domain — do not cite it.

Seven ear action descriptors, each with minimum criteria `[M]`: **EAD101 Ears Forward** ("move
cranially"); **EAD102 Ears Adductor** ("move towards the midline", taking a more vertical position);
**EAD103 Ears Flattener** ("collapse towards the occipital region… covering the ear opening… may
disappear from view behind the head, giving a rounder appearance to the face"); **EAD104 Ears
Rotator** ("the ears opening turn laterally… **no folding or collapsing**"); **EAD105 Ears
Downward**; **EAD106 Ears Backward** ("swivel caudally… appearing taller"); **EAD107 Ears
Constrictor** ("the ears appear slender, taller and pointier").

Two rigging rules, quoted `[M]`: "The two ears have **independent movements** in all the EADs…
unilateral EADs should be coded whenever observed", and "**the neutral position of the ears must be
determined for each individual** before coding."

**Whiskers — the decisive fact: cats do not whisk** `[M]`:

> "each individual whisker has an intrinsic muscle band attached to its follicle, although **cats
> do not present independent movement of each whisker nor whisking movements** (Mitchinson et al
> 2011, Muchlinski et al 2013). The left and right set of whiskers can also move independently from
> each other."

Three codes, mutually exclusive for the first two `[M]`: **AU200 Whiskers retractor** ("caudal
movement… the whiskers lie against the side of the face… also agglomerated"); **AU201 Whiskers
protractor** ("cranial movement… the whiskers swivel and curl slightly towards each other, reaching
a medial region cranially to the face"); **AU202 Whiskers raiser** ("clear dorsal movement… more
noticeable on the upper rows"). At rest the Cat-Stress-Score whisker row reads simply "**lateral**"
(level 1), "lateral or forward" (levels 2–3) `[M]` Kessler & Turner 1997.

**Whiskers during a hunt** `[M]` Leyhausen 1979 pp. 6, 30–31 (same OCR caveat as 4.6):
watching posture — "the whiskers spread wide"; at the spring — "**at the time the cat springs on its
prey its whiskers protrude as far forward as possible**… **Small prey, such as mice for example,
are practically enveloped by them**"; before eating — "presumably it feels the direction of the
hairs with its outspread whiskers."

> ⚠️ **Forward whiskers are ambiguous.** AU201 is classed **affiliative** (Scott & Florkiewicz 2023)
> *and* is FGS whisker score **2 = pain**. Same pose, opposite valence — never use forward whiskers
> alone as a mood cue.

**No numeric whisker angle exists for *Felis catus* in any state** `[NF]` — every quantified
whisker angle in the literature is rodent or pinniped, precisely because cats are a non-whisking
species.

**Two Leyhausen rules that are directly useful for animation** `[M]` (1979 pp. 194–196):

> "the proportion of attacking mood is indicated by **how much of the back of the ear is visible
> from the front**; in purely defensive mood the ear is folded sideways and downward, so that one
> looks at the rim of the side of the ear."

> "**Facial expression is more mobile and changes more often, and thus indicates any swings of mood
> more precisely and much faster than the rest of the animal's posture. Only at the highest
> intensity of one or the other mood does absolute synchronization always occur.**"

The second is a timing law: **face leads, body lags, and they synchronise only at extremes.** He
also documents **asymmetric ear movement** ("While the left ear is still 'threatening,' the right
turns to indifference or defense") and explicitly **rejects** "ear fluttering" as a stimulation
artifact that "does not occur in… intact cats."

Plain-language sets, if the FACS codes are too fine-grained `[M]` Stanton et al. 2015:
**Ears Erect** / **Ears Forward** / **Ears Back** / **Ears Flat** ("lie flush with the top of the
head"), plus the **Alert** modifier: "eyes open, ears forward, mouth closed or slightly open, and
head up". The one study that tested ears against outcomes found "**the position of the ears is more
important than tail position**", and "when both cats interacted with their ears erect, the outcomes
were significantly likely to be positive" (n = 196, p < 0.001) `[M]` Deputte et al. 2021.

Eyes: **AU47 Half-blink** is the "slow blink" — "The upper and lower eyelids move towards each
other, **without ever closing the eye**"; **AU143 Eye Closure** = closed "half a second or more";
**AU145 Blink** = "the eye opens within half a second" `[M]`. Drawing rule: "In cats, the sclera is
rarely seen… When the aperture is maximal, **no sclera can be seen**" `[M]`.

### 4.9 Tail positions

Primary source obtained and read: **Cameron-Beaumont CL (1997) PhD thesis, University of
Southampton, Fig. 5.1 "Ethogram of tail positions and other stances in the domestic cat", p. 114**
— public at `eprints.soton.ac.uk/463206/1/525707.pdf`.

> ⚠️ **Attribution correction: the position NAMES are Cameron-Beaumont's, not
> Kiley-Worthington's.** Cameron-Beaumont, p. 124: Kiley-Worthington "characterised **six** tail
> positions… **although she only gave pictures of the positions; the terms were devised in this
> thesis**." Do not credit these names to Kiley-Worthington 1976.

Seven mutually exclusive positions, verbatim `[M]`:

| name | definition | note |
|---|---|---|
| **Tail Up** | "Tail held in upright position." | drawn **twice joined by "or"**: straight vertical, **or** vertical with the distal third hooking forward. The hook is a variant of the same category. |
| **Tail Half-Up** | "Tail held at **45°** to the tail up posture or thereabouts." | **the only numeric tail angle in the literature** — and note it means 45° *from vertical*. |
| **Tail Parallel** | "Tail parallel to the ground, sometimes slightly curved." | |
| **Tail Down** | "Tail held down, with the end kinked out." | |
| **Tail Under** | "Tail curled under, or to the side of the body." | drawn twice: under between the hind legs, **or** laterally against the thigh. |
| **Tail Bent-Up** | "Tail is bent in an upward curve." | rare; "included here for completeness" |
| **Tail Over** | "Tail bent directly over the body" | rare, spitz-like |

**Any tail angle other than 45° would be invented** `[NF]`. "Vertical", "upright", "parallel to the
ground" and "45° to the tail up posture" is the complete published geometric vocabulary.

Movements `[M]` (Cameron-Beaumont Appendix I p. 250; partly after UK Cat Behaviour Working Group
1995 — note the two systems' names collide, so state which you follow): **Tail Jerk** "A rapid
flick… in either side to side or up to down motion, more frequently from up to down" (= UKCBWG
"twitch"); **Tail Wave** "A slow and gentle wave… from side to side" (= UKCBWG "swish"); **Tail
Swish** "A violent swish… more rapid than a tail wave but smoother than a Tail Jerk"; **Tail
Quiver** "usually held in either the Tail Up or the Tail Half-Up positions and is quivered
rapidly"; **Arch Back** "curves its back upwards and stands rigidly. **The tail is usually tensely
curved and the fur may be piloerected.**"

**Two findings that matter directly for the walk rig** `[M]`:

- **Tail Parallel and Tail Down carry no signal — they are the locomotion positions.** "This may be
  either because these positions are the best for balance, or simply that these positions expend
  the least energy without dragging the tail along the floor." And "it seems likely that **the only
  two tail positions to have a signalling function are the Tail Up and Tail Under postures**."
- **At speed the tail must be near-parallel.** Kiley-Worthington, via Cameron-Beaumont pp. 127–128
  (her paper unobtainable, Brill 403 — second-hand): "At a walking and trotting pace, **any** tail
  position could be used, with the exception of Tail Under and Tail Bent-Up. **At faster paces… it
  was necessary for the tail position to be Tail Parallel or thereabouts, presumably for balance.**"

So: walking → tail free (use Tail Up for a friendly companion); running → tail parallel. That is a
sourced, implementable rule.

Also: **Tail Up is domestic-cat-specific.** Four undomesticated felid species showed most of the
ethogram "with the exception of the Tail Up signal… It was therefore concluded that Tail Up evolved
to function as a signal in the domestic cat, possibly during domestication" `[M]`. It is tightly
coupled to rubbing — Touch Nose 100%, Rub Head 84%, Allogroom 82% of occurrences happened with Tail
Up held `[M]`. And cats "approached Tail Up silhouettes faster, and with less hesitation or
fearfulness, than they did Tail Down silhouettes" `[M]`.

> ⚠️ **A vertical tail is ambiguous too.** Cameron-Beaumont Fig. 8.8 offers a fourth raised variant
> after Leyhausen — **"Tail Aggressively Raised"** — drawn as the arched-back, splay-legged
> defensive cat with **a straight vertical tail and no hook**. Same tail geometry as friendly Tail
> Up; disambiguated only by the body `[M]`. The hooked tip is the friendly cue.

Reliability warning for anyone building a mood system on the tail: a 2026 ethogram study reports
inter-observer **Tail twitch κ = 0.18, omitted as unreliable** (vs Tail up κ = 0.62) `[M]`. And
Deputte et al. 2021 found "in 75.6% of the interactions **both** cats showed a tail-down display"
— the tail was less informative than the ears `[M]`.

Not scientific terms, with their published equivalents: "question-mark tail" → the hooked-tip Tail
Up variant; "bottle-brush" → piloerection; "tail wrap" → **no ethogram definition exists** `[NF]`
(only "Friendly cats will also rub their tails against each other's bodies and wrap their tails
together so that the tails are intertwined", Crowell-Davis et al. 2004).

---

## 5. Animation-craft numbers

All frame counts are at **24 fps**. Where a source states drawings "on twos", the cycle length in
frames is twice the drawing count.

### 5.1 Frame counts for a quadruped walk and trot

**Richard Williams, *The Animator's Survival Kit*, "Animal Action" chapter** `[M]`. ⚠️ **Cite the
Expanded Edition (Faber & Faber 2009)** — only pp. 327–331 exist in the 2001 first edition; the
donkey, cartoon dog and horse walk/trot/gallop pages are Expanded-Edition-only.

| cycle | frames | exposure | seconds | Hz | pp. |
|---|---|---|---|---|---|
| "Basic Animal Walk Pattern", medium-size dog | **20** | 10 drawings on twos | 0.833 | 1.20 | 330–331 |
| invented donkey walk | 32 (2 steps × 16) | 16 on twos | 1.333 | 0.75 | 332 |
| cartoon dog (dachshund) | 24 | 24 on ones | 1.000 | 1.00 | 354–355 |
| horse walk | 32 | 16 on twos | 1.333 | 0.75 | 356–357 |
| **horse TROT** | **16** | 16 on ones | 0.667 | 1.50 | 358 |
| horse gallop | 12 | 12 on ones | 0.500 | 2.00 | 359 |

**Whitaker H & Halas J, *Timing for Animation*** (Focal Press; base 24 fps stated on p. 1; page
numbers differ by edition) — the only source that states quadruped counts outright `[M]`:

| species / gait | stated figure | frames | s | Hz |
|---|---|---|---|---|
| horse **walk** | "If **24 frames** is taken as the length of a walk cycle" | 24 | 1.000 | 1.00 |
| tiger / deer walk | "drawing 17 has the opposite feet positions to drawing 1, so the complete repeat would take **32 frames**" | 32 | 1.333 | 0.75 |
| **cat stride, general** | "a smaller animal such as a cat may take a complete stride in **half a second or less**" | ≤12 | ≤0.5 | ≥2.00 |
| **cat gallop** | "The complete stride of a cat takes about **1/3 second**" | 8 | 0.333 | 3.00 |
| horse gallop | "a complete stride takes about **half a second**" | 12 | 0.500 | 2.00 |
| elephant stride | "a second or perhaps a second and a half" | 24–36 | 1.0–1.5 | 1.00–0.67 |

⚠️ **Williams' horse walk (32 fr) and Whitaker & Halas' (24 fr) conflict. Do not average them** —
Williams is one specific drawn cycle on twos, Whitaker & Halas state a normative ~1 s stride.

**Preston Blair, *Cartoon Animation*, "Movements of the Four-Legged Figure"**: **WALK = 5 key
drawings, TROT = 5 key drawings, both half-cycles** → 10 keys per full cycle `[M]`. Verbatim: "THE
WALK, TROT, SNEAK, STRUT AND TIPTOE ARE HALF-CYCLES. THE GALLOP, CANTER, AND SNIFF ARE COMPLETE
CYCLES." **Blair gives no quadruped frame counts, and does so deliberately** `[M]`: "YOU MUST DRAW
ENOUGH IN-BETWEENS TO MAKE THE ACTION SMOOTH FOR THE SPECIFIC SPEED OF THE ACTION AND THE TIMING IN
FILMING." The whole revised edition was searched; the only frame counts anywhere are for a biped
run and a 12-frame hold. **Any "Blair says N frames for a quadruped" claim is unsourceable.**

**The number to actually use, because it is a measured cat:** gait cycle **0.66 s → 15.8 frames,
1.52 Hz** `[M]` Dowgray et al. 2024 (§2.4). Whitaker & Halas' "half a second or less" (≥2 Hz) is
faster than any measured walking cat and is probably describing a trot.

**A taught trot frame count for a cat or dog is `[NF]`** — Williams' horse trot (16) is the only
trot count in the animation literature reached. Also searched without result: Hultgren *The Art of
Animal Drawing*, Tony White *The Animator's Workbook*, Goldberg *Character Animation Crash Course*,
Maestri *Digital Character Animation 3*, and Sumida *Animal Locomotion for Animators* (rich on gait
structure but expresses everything as "% of cycle" — the word "frame" appears zero times).

### 5.2 Muybridge's cat plates and their real time base

**Plates, *Animal Locomotion* (1887), Vol. X** `[M]`:

- **Plate 716 = "Cat; walking; change to galloping"** — the walking-cat plate. Boston Public
  Library record via Wikimedia Commons.
- Plate 717 = "Cat trotting, changing to a gallop", **20 frames** (USC Libraries record).
- Plates 718 (trot→gallop), **719 and 720 = "Cat galloping"**.
- **There is no pure "cat walking" plate** — 716 is a walk transitioning to a gallop.

***Animals in Motion* (1902)**, read from two independent archive.org scans `[M]`:

| series | caption | phases | interval | total | p. |
|---|---|---|---|---|---|
| **11** | "BREAKING INTO A GALLOP. / The Cat." | **24** | **.031 s** | "Approximate time of complete series: **.71 second**" | 55 |
| **40** | "ONE STRIDE IN TEN PHASES. / The Cat." (trot) | **10** | **.035 s** | none printed | 131 |
| 55 | Gallop, Cat | 12 | not printed | — | 189 |

Arithmetic check: 23 × .031 = 0.713 s, matching the printed .71 s — which confirms 24 phases.
0.71 s = **17.0 frames**. Series 40 gives a cat trot stride of 9 × .035 = **0.315 s (7.6 fr,
3.2 Hz)** or 10 × .035 = 0.350 s — agreeing with Whitaker & Halas' "cat 1/3 second".

**Capture rate, verbatim — there is no global fps** `[M]`: "The time-intervals of exposures varied
from the one-hundredth of a second to several seconds"; "The time-intervals between the phases are
marked in thousandths of a second"; "The tuning-fork made one hundred vibrations in a second of
time. The number of vibrations occurring between any two exposures marks the time." **The interval
is printed per-series on the plate.**

**A cat *walk* stride duration is not printed anywhere in Muybridge** `[NF]` — use Dowgray's 0.66 s.
For comparison, printed quadruped walk strides: horse "Eagle" 1.20 s; mare "Annie" 0.95 s; ass
1.06 s; ox 1.15 s; goat 1.03 s; hog 0.85 s; elephant 1.32 s; horse amble 0.55 s `[M]`.

Muybridge's own footfall law, verbatim `[M]`: "The normal stride of a quadruped, while using four
limbs as supports, during locomotion, **consists of four steps**." The first move "will invariably
be made with **a hind-foot; the lateral fore-foot will next follow**", and that fore-foot leaves the
ground before the swinging hind-foot lands. **This is the lateral-sequence rule of §2.1, stated in
1899.**

### 5.3 Anticipation, overshoot and follow-through in a four-legged walk

| finding | number | source |
|---|---|---|
| **head lags the chest** | **2–4 frames** (0.083–0.167 s) | Williams, *ASK* p. 327, verbatim: "THE HEAD COMES UP SLIGHTLY LATER THAN THE CHEST **DELAYED 2 OR 4 FR.**" Head goes *down* as the chest goes down. |
| **shoulder "down" lags hip "down"** | **6 frames of 24 = 25% of the cycle** | Whitaker & Halas: rump lower on frames **1 and 13**, shoulders lower on **7 and 19**; on 7/19 "the head is pulled into a slightly more horizontal slant" |
| spine twists laterally through the walk | no number | Williams p. 331: "the SPINE TWISTS SIDE TO SIDE DURING the WALK", pelvis and shoulder dropping on offset frames |
| **settle order on a stop** | front legs squash **frame 2**, back legs **frame 4** (2-frame lag); by frame 5 head and front legs are static while **back legs, tail and ears are still moving** | Whitaker & Halas, Fig. 30A caption. Prose: front feet → back legs/feet → squash out, may **overshoot up** → floppy ears last to rest |
| settle order, no frames | feet arrive → body rises → arms → "followed by the tail" | Blair, *How to Animate Film Cartoons*, "Delayed Secondary Actions" |
| Disney's own statement | **no number**; head/chest/shoulders stop together, "then a few frames later, the rest of the parts would settle" | Thomas & Johnston, *The Illusion of Life*, principle 5, pp. 59–62 (the only figure in that section is the Moving Hold: 8–16 frames) |

`[M]` for all of the above. **"The hip leads the paw" as a frame count is `[NF]`.** The closest
sourced ordering is a footfall rule, not a lag: the swinging hind foot "kicks" the ipsilateral front
foot out of the way, and "the back foot of each pair usually comes off the ground immediately the
front foot is on the ground" `[M]` Whitaker & Halas; Chris Webster, *Animation: The Mechanics of
Motion*, Fig. 5.5. **Quadruped-specific anticipation lead time is `[NF]`.**

**The measured biological head lag is in §3.3 and is smaller than the animation convention.**
Zubair's cats: head vertical max lags shoulder/trunk max by **20–90°**; since head vertical runs
twice per stride, that is 2.8–12.5% of a stride ≈ **0.4–2.4 frames** on a 16-frame cat cycle `[D]`.
Williams' 2–4 frames is a stylisation, roughly 2× the measured lag. **Use the biological value for
realism, Williams' for appeal — but not both at once.**

### 5.4 Overlapping action / drag

| guidance | number | source |
|---|---|---|
| delay a loose-flesh mass behind head and body | "just **2 frames or 3 frames or 4 frames**" | Williams p. 290 |
| Tex Avery compound takes, chained parts | "delaying bits, often just **2 frames apart**" | Williams p. 290 |
| offset duplicated characters so they read as alive | "an overlap of **one or two frames**"; for ragged movement "a **four frame** overlap … may not be enough" | Whitaker & Halas p. 61 |
| five bouncing balls, one 1 frame late, one 1 frame early | **1 frame** | Whitaker & Halas Fig. 30B–F |
| oscillating repeats | springboard **4 frames** bottom-to-top; "**cycles of less than six frames may look mechanical**"; prefer a double near-repeat of **7 or 9 frames** over a 4-frame repeat | Whitaker & Halas pp. 62–63 |
| **segmented / chained tail** | movement passes from the section next to the body to the next "with **a slight time lag**", then "another time lag, and so on to the end" — **principle stated, NO NUMBER** | Whitaker & Halas, "Timing an Oscillating Movement" |
| Williams' "successive breaking of joints" | **no frame counts** — the numbers live in the drawings | Williams pp. 231, 251–252 |
| "the quicker or broader the action, the more extreme the drag" | no number | Goldberg, "Drag and Overlap", pp. 57–61 |

`[M]` for all. **Per-tail-segment lag, ear lag and whisker lag are all `[NF]` as numbers.** The only
defensible published anchors for a chained appendage are the **2–4 frame** flesh delay and the
**1–2 frame** offset rule. The "cycles under 6 frames look mechanical" figure is a useful floor: at
24 fps a 1.5 Hz cat stride is 16 frames, so any sub-cycle detail should be ≥ 6 frames or it will
read as buzz.

### 5.5 Easing — the sourced rule is not the one usually assumed

**"Linear stance, eased swing" does not appear in the literature in those words** `[NF]`. What is
sourced is a different split — **uniform *horizontal*, eased *vertical*** `[M]`:

> "The up-and-down movement of the body should slow in and out of the key positions, but **the
> forward movement of the body should be at a uniform speed**, or the animation 'sticks'."
> Whitaker & Halas, "Types of Walk", p. 100

> "The 3.6 inches, which the figure moves along every two paces, is now taken up by moving the foot
> backward **0.15 inch per frame**." (0.15 × 24 = 3.6 in — checks out; strictly uniform increment.)
> Whitaker & Halas, "Timing a Walk"

> "the contact foot must be animated in such a way that **its spacing appears even**… **If the foot
> is favored during contact, it will appear to slip and slide** during the constant rate pan."
> Goldberg, *Character Animation Crash Course!* ("favoring" = easing toward a key)

Spacing within the cycle `[M]`: "the spacing is much wider through the passing position, and more
cushioned toward the keys" (Goldberg p. 9); "the WEIGHT GOES DOWN JUST AFTER the CONTACT … the
WEIGHT GOES UP JUST AFTER the PASSING POSITION" (Williams p. 108). Ken Harris's word for easing is
"**cushioning**".

**This corroborates §2.5 and §7-Check 4 from the craft side: the planted paw must translate at
exactly the body's forward rate, unsmoothed, or it skates. Ease the body's vertical, never the
planted paw's horizontal.** An animation-side swing:stance ratio is `[NF]`; use the measured duty
factors instead (§2.2). Williams' own warning about going down this road, verbatim: "(DON'T) TRY TO
WORK OUT A CYCLE WALKING IN PLACE WITH THE FEET SLIDING BACK, ETC. THAT ALL BECOMES TOO TECHNICAL."
A procedural rig is exactly the case where it is not too technical.

### 5.6 Keys and breakdowns — and why the biped four-key structure does not port

**Williams, *ASK* p. 330, "BASIC ANIMAL WALK PATTERN"** uses **four pose types per leg pair** —
CONTACTS, PASS POSITION, the DOWN, the UP — colour-coded, with the fore and hind pairs offset and
**each pair getting its own contact and passing position** `[M]`.

**The only published quadruped key schedule with numbers** — Williams p. 332, invented donkey,
16-frame step on twos: extremes **#1 and #17** (level), **DOWN #5**, **PASS POS #9**, **UP #13** →
**down at 1/4 of the step, passing 1/2, up 3/4**, i.e. **1/8, 1/4, 3/8 of the 32-frame cycle**
`[M]`. Williams' own verdict on it, verbatim: "SIMPLE, BELIEVABLE, **BUT NO ANIMAL WALKS LIKE
THIS.**"

His 20-frame dog walk has contacts at frames **5, 9, 15, 19** — intervals 4, 6, 4, 6, with 5 and 15
front-foot contacts and 9 and 19 hind `[M]`. (Which left/right limb pairs with which is not
determined from that page; do not infer a signed offset from it.)

> ⚠️ **Explicit published statement that the biped "down/squash" key has no quadruped
> equivalent:** "**There is no equivalent of the 'squash' position of a human walk in a four-footed
> walk**, as the back foot of each pair usually comes off the ground immediately the front foot is
> on the ground." `[M]` Whitaker & Halas, "Other Quadrupeds". **Porting the biped four-key
> structure to the cat is contradicted by source, not merely unsupported.**

A published quadruped key table with pose names *and* cycle fractions is `[NF]`. Williams' donkey is
one invented example he disowns; Blair gives 5 keys per half-cycle with no fractions and no frames.

**The ¼-cycle footfall offset is the most robustly triangulated number in this whole document** —
three animation texts and the biomechanics literature agree independently `[M]`:

> "The order in which the feet of a horse touch the ground is: **back left, front left, back right,
> front right**… **If it is walking freely the feet touch the ground at equal intervals of time.**
> If 24 frames are taken as the length of a walk cycle, i.e. back left hits the ground on frame 1,
> 'back right' hits the ground on frame 13, and 'front left' and 'front right' hit the ground on
> frames 7 and 19 respectively." Whitaker & Halas → **LH 0, LF 0.25, RH 0.50, RF 0.75**

- Williams pp. 356–357, horse walk, 32 frames: rear contacts **1 and 17**, front **9 and 25** →
  front lags rear by **8/32 = exactly ¼**. "PLANNED FROM THE BACK LEG CONTACTS – WHERE THE POWER
  COMES FROM."
- Blair: "In animal walks, the back legs are usually **½ step ahead** of the front legs" (½ step =
  ¼ cycle). *Caveat: two scans disagree on his dog fraction, ¾ vs ¼.*
- Biomechanics: lateral advanced placement "**close to 0.25** with the limbs sequentially setting
  down in near quarter intervals of the stride duration" (Vincelette 2023, §2.1).

**Trot: all three animation sources agree the diagonal pair contacts simultaneously, offset zero**
`[M]`. Williams p. 358: "OPPOSITE LEGS LIFT AND CONTACT **AT THE SAME TIME**", contacts frames 6
and 14 of 16. And a rule that matters for the fast gaits: "ALL THESE QUICK ACTIONS ARE PLANNED FROM
THE UPS + DOWNS OF THE BODY MASS – **NOT THE LEG CONTACTS**"; "THE FASTER A FIGURE GOES – THE MORE
WE PLAN FROM THE BODY AND NOT FROM THE LEG CONTACTS." So: drive the walk from footfalls, drive the
gallop from the body.

---

## 6. What the current implementation gets wrong

Given: `femur 17, tibia 16` (span 33) with `standHeight 42` / `hipHeight 40`; `stance = 0.62`;
leg phases `[0.50, 0.00, 0.00, 0.50]` for (far-hind, far-fore, near-hind, near-fore); body bob
`sin(phase · 4 · 2π)`; two-point spine (hips, chest) joined by a straight line; two-bone IK on
all four limbs.

### 6.1 The back leg detaches because the leg is 18 units too short — arithmetic, not tuning

At `hipHeight = 40`, the measured hind chain is `1.269 × 40 = 50.7 units` `[D]`. The rig has
**33**. Even fully straightened, the current hind limb ends **7 units above the ground** — and at
the measured crouch (§1.4) it would need to *fold* 21% out of a 50.7-unit chain to reach y = 0.
There is no pair of femur/tibia values that fixes this: `femur + tibia = 0.854 H` is a within-study
measured ratio, so a two-bone leg is *always* 15% short.

Correct segments at `H = 40` `[D]`:

| | current | measured |
|---|---|---|
| femur | 17 | **16.5** ✅ nearly right |
| tibia | 16 | **17.5** (tibia is the *longer* bone) |
| metatarsus | — | **11.4** ← missing |
| hind digits | — | **5.4** ← missing |
| hind chain | 33 | **50.7** |
| scapula | — | **11.1** ← missing |
| humerus | — | **15.4** |
| radius/ulna | — | **14.9** |
| metacarpus | — | **5.2** |
| fore chain | — | **46.6** |
| pelvis block | (point) | **12.9** long |

Also: `standHeight 42` vs `hipHeight 40` disagree by 2 units, but the sources say shoulder and hip
sit at **equal** height `[M]` (Fischer 2002; ACFA standard). Use one variable.

### 6.2 Two-bone IK is structurally wrong

The hind limb has **four** functional segments (femur, tibia, metatarsus, digits) and the fore limb
**four** (scapula, humerus, radius/ulna, metacarpus — plus digits, unmeasured). A cat is
digitigrade: the digit segment carries load. And the scapula, not the shoulder joint, is the
forelimb's pivot `[M]` (§3.2). Two-bone IK cannot express the zig-zag, cannot express the
scapular ride, and throws away the >50% of forelimb propulsion the proximal segment provides
`[M]`.

### 6.3 The leg phases animate a trot, not a walk

`[0.50, 0.00, 0.00, 0.50]` puts **far-fore + near-hind at 0.00** and **far-hind + near-fore at
0.50** — diagonal pairs in exact synchrony. That is the definition of a trot (limb phase 0.50),
run at a walk's duty factor. Computed support pattern `[D]`:

| | current impl | measured cat walk |
|---|---|---|
| footfall events per cycle | **2** | **4** |
| four feet down | **24% of cycle** | **0%** |
| three feet down | **0%** | **46%** |
| two feet down | 76% | 54% |
| support sequence | `4 → 2 → 4 → 2` | `3 → 2 → 3 → 2 → 3 → 2 → 3 → 2` |

Two footfalls per cycle instead of four, and a support count that only ever alternates 4 and 2, is
exactly what a viewer calls mechanical. Fix: `[0.50, 0.75, 0.00, 0.25]` (near = left) or
`[0.00, 0.25, 0.50, 0.75]` (near = right), limb phase 0.25.

### 6.4 `stance = 0.62` is one value where there should be two

Measured: **fore 0.63, hind 0.60** `[M]` (four independent cat studies, §2.2). 0.62 is close for
the forelimb and ~0.03 too high for the hind. The fore/hind difference is real and comes from
swing duration (hind swing 0.30 s vs fore 0.25 s), so it also changes the *look* of the back legs,
not just the contact timing.

### 6.5 The body bob is at the wrong frequency, wrong amplitude source, and wrong phase

`sin(phase · 4 · 2π)` is **4 oscillations per stride on a timer unrelated to footfall**. Measured:
a midline trunk point oscillates **twice** per stride, locked to the forefoot pair `[M]`
(§2.5).

| | current | measured |
|---|---|---|
| cycles per stride | 4 | **2** |
| driven by | independent 4 Hz timer | the gait phase itself |
| amplitude | (unstated) | **0.10 `H` peak-to-peak** ≈ 4.0 units at `H` = 40 |
| phase | arbitrary | **min at forefoot contact, max at forelimb mid-stance** |
| shape | symmetric sine | **fall faster than rise** (down 0.09–0.13 m/s vs up 0.06–0.07) |

A 4 Hz bob against a ~1.5 Hz stride is a 2.67:1 beat against the footfalls — it will visibly drift
in and out of sync with the feet forever. This is very likely the largest single contributor to
"janky".

Second-order point from the craft side: a 4 Hz cycle is **6 frames at 24 fps** `[D]`, and
Whitaker & Halas warn that "cycles of less than six frames may look mechanical" `[M]` (§5.4). The
current bob sits exactly on that floor. The measured bob — 2 per stride at a 1.5 Hz stride = 3 Hz —
is 8 frames, comfortably above it.

### 6.6 The two-point straight spine cannot produce a cat outline

A straight hips→chest line has no pelvis length, no lumbar arch, no scapular rise, and no way to
express the one spine behaviour that matters. Minimum viable replacement: pelvis block (0.324 `H`)
→ lumbar segment → thoracic segment → neck → head, with the scapula pivoting against the thoracic
segment near its dorsal border, small sagittal bend at a walk, up to ~27° peak-to-peak at a bound
`[M]`, and the head driven at 0.6× the body's vertical amplitude with a 20–90° lag `[M]`.

### 6.7 The "badly drawn lion" problem is proportional

Three ratios most likely responsible, all `[M]`:

1. **tibia must exceed femur** (0.437 vs 0.413 `H`) and **ulna must exceed humerus**. Getting the
   proximal bone longer makes a big-cat/canid leg.
2. **head length ≈ 0.20 of head-body length** — a lion's head is proportionally far larger.
3. If a **Persian** is the target: nose index 0.29 (doll-face) or 0.15 (peke-face) against 0.46 for
   a normal cat; braincase as wide as long (cranial index 0.97 peke / 0.66 doll vs 0.63);
   interorbital distance 0.28/0.19 of skull width vs 0.15; 40% of the eye globe outside the orbit
   vs 9.9%; ears **small, low-set, wide apart, tilted forward**; legs short; back length ≈ shoulder
   height; and the long coat "softens the lines… accentuates the roundness" — the ruff and tail
   plume should hide the leg joints entirely.

---

## 7. Runnable checks

Keep these; each fails loudly if the rig regresses. All were run to produce the numbers above.

**Check 1 — leg reaches the ground.**
`hind_chain = femur + tibia + metatarsus + digits` must be ≥ `1.25 × H` (measured 1.269).
`fore_chain` must be ≥ `1.15 × H` (measured 1.165). A rig failing this can never plant a paw.

**Check 2 — support pattern.** Sample the cycle at ≥ 200 points, count feet in stance
(limb `i` is down when `((t − phase[i]) mod 1) < DF[i]`). Assert: min = 2, max = 3, tripedal
fraction 0.42–0.50, and **exactly 4 distinct footfall times**.

**Check 3 — double stance matches measurement.** `2·DF_fore − 1` must land within 2 points of
**25.0%** and `2·DF_hind − 1` within 2 points of **18.2%** (Weißig et al. 2025) `[M]`.

**Check 4 — no foot skate.** Over one cycle, a planted paw's backward travel in world space must
equal `speed / stride_frequency` to within 1%. Equivalently assert
`stride_frequency == speed_pt_s / (1.9 × H × s)`.

**Check 5 — gait is in the band cats use.** `speed_pt_s / H_pt` must fall in **1.54 – 3.46**
`H`/s. Below 1.54 (0.4 m/s) intact cats "showed inconsistent stepping" `[M]`; at ~3.46 (0.9 m/s)
duty factor crosses 0.5 and it is no longer a walk `[M]`.

**Check 6 — bob is locked to the feet.** Assert the body's vertical signal has exactly 2 minima
per stride and that each minimum lies within 0.05 of a forefoot contact phase.

---

## Appendix: sources

Open access unless marked. Retrieved via Europe PMC REST / Crossref / direct fetch.

**Feline gait, measured**
- Dowgray N, Comerford E, German AJ, Gardiner J, Pinchbeck G, Bates KT (2024). Paw pressure and
  gait in middle-aged client-owned cats with and without naturally-occurring musculoskeletal
  disease. *PLoS ONE* 19(12):e0314629. PMC11654939. — 53 cats, duty factors, stride length, the
  speed regressions.
- Weißig DM, Dobenecker B, Zablotski Y, Lauer SK (2025). Repeatability and reliability of kinetic
  and temporospatial gait parameters … in healthy cats. *Front Vet Sci* 12:1707477. PMC12753478.
  — stance %, stride/step length, double stance.
- Zubair HN, Beloozerova IN, Sun H, Marlinski V (2016). Head movement during walking in the cat.
  *Neuroscience* 332:101–120. PMC4986613. — head stabilisation, oscillation counts, phases.
- Rahmati SM, Klishko AN, Martin RS, et al. (2025). Role of forelimb morphology in muscle
  sensorimotor functions during locomotion in the cat. *J Physiol*. PMC11737544. — forelimb
  segment lengths and inertia.
- Prilutsky BI, Parker J, Cymbalyuk GS, Klishko AN (2022). Emergence of extreme paw accelerations
  during cat paw shaking. *Front Integr Neurosci*. PMC9007247. — hindlimb segment lengths (Table 1).
- Lecomte CG, Audet J, Harnie J, Frigon A (2021). A validation of supervised deep learning for gait
  analysis in the cat. *Front Neuroinform*. PMC8417424. — hindlimb joint angles at contact/liftoff.
- Harnie J, Audet J, Mari S, et al. (2022). State- and condition-dependent modulation of the
  hindlimb locomotor pattern … across speeds. *Front Syst Neurosci*. PMC8863752. — speed effects
  on cycle/stance vs swing.
- Rybak IA, Shevtsova NA, Markin SN, Prilutsky BI, Frigon A (2024). Operation regimes of spinal
  circuits controlling locomotion. *eLife*. PMC11473106. — DF crosses 0.5 at ~0.9 m/s; 0.4 m/s
  lower limit for consistent stepping.
- Schnabl-Feichter E, Tichy A, Gumpenberger M, Bockstahler B (2018). Comparison of ground reaction
  force measurements in Domestic Shorthair and Maine Coon cats. *PLoS ONE*. PMC6291092. — walk
  speeds, stance durations; explicitly did **not** measure body height.
- Boczek-Funcke A, Kuhtz-Buschbeck JP, Illert M (1996). Kinematic analysis of the cat shoulder
  girdle during treadmill locomotion: an X-ray study. *Eur J Neurosci* 8(2):261–272. PMID 8714697.
  **Paywalled — abstract only.** Scapular pivot, once-per-cycle rise, post-contact yield.
- Kuhtz-Buschbeck JP, Boczek-Funcke A, Illert M, Weinhardt C (1994). X-ray study of the cat
  hindlimb during treadmill locomotion. *Eur J Neurosci* 6(7):1187–1198. PMID 7952299.
  **Paywalled — abstract only.**

**Morphometry**
- Poradowski D, Mutlu Z, Altundağ Y, et al. (2024). Estimation of height at withers based on long
  bone measurements of living cats. *Vet Sci* 11(11):522. PMC11598937. — **the withers-height
  anchor and all bone-length factors.**
- Fleming PA, Crawford HM, Auckland CH, Calver MC (2020). Body size and bite force of stray and
  feral cats. *Animals* 10(4):707. PMC7222765. — head-body and head length, n = 568; landmarks
  undefined; tail not measured.
- Doube M, Wiktorowicz-Conroy A, Christiansen P, Hutchinson JR, Shefelbine S (2009).
  Three-dimensional geometric analysis of felid limb bone allometry. *PLoS ONE*. PMC2650414. —
  felids use bone allometry, not limb straightening. (Carries a published correction.)
- Cuff AR, Sparkes EL, Randau M, et al. (2016). Scaling of postcranial muscles in cats (Felidae)
  II. *J Anat*. **Paywalled — abstract only.** Crouched posture constant across 300-fold size range.
- Day LM, Jayne BC (2007). Interspecific scaling of the morphology and posture of the limbs during
  the locomotion of cats (Felidae). *J Exp Biol* 210:642–654. doi:10.1242/jeb.02703.
  **Paywalled — publisher PDF returns 403; abstract only.** Larger felids are not more upright.
- Xu X, Sun X, Hu XS, et al. (2016). Missense mutation in HES7 linked to short tails in Asian
  domestic cats. *Sci Rep* 6:31583. PMC4997960. — 22 caudal vertebrae in normal-tailed cats.

**Comparative locomotion and gait classification**
- Wimberly AN, Slater GJ, Granatosky MC (2021). Evolutionary history of quadrupedal walking gaits.
  *Proc Biol Sci*. PMC8370795 (in PMC, not in the OA subset). — **limb-phase bands 0–25/25–50/
  50–75/75–100**; terrestrial mammal mean 28.05 ± 13.08; DF > 50% defines a walk.
- Hutchinson JR, Pringle EV (2024). Footfall patterns and stride parameters of common hippopotamus.
  *PeerJ*. PMC11227274. — duty-factor definition, DF ≥ 0.5 = walk, lateral-sequence order,
  Hildebrand bibliography.
- Vincelette A (2023). The characteristics, distribution, function, and origin of alternative
  lateral horse gaits. *Animals* 13. PMC10451235. — LS footfall order, LAP ≈ 0.25 for an even
  four-beat walk, walk DF 0.60–0.70, walk support alternates bipedal/tripedal.
- Granatosky MC, Dickinson E, Young MW, Lemelin P (2024). A coati conundrum: how variation in
  levels of arboreality influences gait mechanics among three musteloid species. *J Exp Biol*
  227(19):jeb247630. PMID 39318348. **Paywalled — abstract only.** Coati uses lateral-sequence
  lateral-couplet; no numeric limb phase published in the abstract.
- Plocek MR, Dunham NT (2023). Spatiotemporal walking gait kinematics of semi-arboreal red pandas.
  *J Exp Zool A* 339(8):755–766. PMID 37395486. **Paywalled — abstract only.** States red panda
  limb phase resembles terrestrial Carnivora but publishes no value in the abstract.
- Rhodin M, Smit IH, Persson-Sjodin E, et al. (2022). Timing of vertical head, withers and pelvis
  movements relative to the footfalls in different equine gaits and breeds. *Animals* 12.
  PMC9657284. — two oscillations per stride at walk, min at hoof-on, max at mid-stance.
- Catavitello G, Ivanenko Y, Lacquaniti F (2018). A kinematic synergy for terrestrial locomotion
  shared by mammals and birds. *eLife* 7:e38190. PMC6257815. — hip/shoulder vertical oscillation
  9.6% / 11.4% of limb length; limb-length definition; quadruped trunk 8 ± 7°.
- Fischer MS, Schilling N, Schmidt M, Haarhaus D, Witte H (2002). Basic limb kinematics of small
  therian mammals. *J Exp Biol* 205:1315–1338. PMID 11948208. **Paywalled — abstract only.**
  Three-segment zig-zag limb; scapular/hip pivots at equal height; proximal segments > half of
  propulsion; lumbar spine ≈ half of hindlimb step length in in-phase gaits.
- Fischer MS, Blickhan R (2006). The tri-segmented limbs of therian mammals. *J Exp Zool A*
  305:935–952. PMID 17029268. **Paywalled — abstract only.**
- Belyaev RI, Nikolskaia NA, Bushuev AV, et al. (2024). Running, jumping, hunting and scavenging:
  functional analysis of vertebral mobility in carnivorans. *J Anat*. PMC10780164. — *Felis catus*
  lumbar sagittal ROM 97.6°/108.8°; felid family means; **osteometric capacity, not gait
  excursion.**
- Kamimura T, Sato K, Aoi S, et al. (2022). Three characteristics of cheetah galloping improve
  running performance through spinal movement. *Front Bioeng Biotechnol*. PMC9049215. — 27°
  sagittal spine range at 15–18 m/s.
- Shield S, Jericevich R, Patel A, Jusufi A (2021). Tails, flails, and sails: how appendages improve
  terrestrial manoeuvrability by improving stability. *Integr Comp Biol*. PMC8633431. — cheetah
  tail 18 rad/s; secondary reports of Walker et al. 1998 (cat tail vs lateral perturbation) and
  Wada et al. 1993 (dog tail offsets pelvic COM in walking/trotting).
- Grant RA (2026). Vibrissal sensing in mammals in a changing world. *J Exp Biol*. PMC12952711. —
  confirms the **absence** of felid whisker kinematics in the literature.

**Ethograms and behaviour (§4)**
- **Kappel I, Riedel M-C, Becker F, Hicks S, Warlich-Zach N, Ganslosser U (2024). Ethogram of the
  Domestic Cat. *Pets* 1(3):284–314. doi:10.3390/pets1030021, CC BY.** 117 illustrated behaviours.
  PDF via `res.mdpi.com` (mdpi.com itself 403s). **Caveat: the PDF's text layer interleaves table
  rows — check any quote against the rendered page.**
- **Stanton LA, Sullivan MS, Fazio JM (2015). A standardized ethogram for the Felidae.** *Appl Anim
  Behav Sci*. Paper paywalled; **complete ethogram free as supplementary DOCX**
  `ars.els-cdn.com/content/image/1-s2.0-S0168159115001008-mmc3.docx`. Often mis-cited as "Faulkner".
- **Cameron-Beaumont CL (1997).** PhD thesis, Univ. Southampton. `eprints.soton.ac.uk/463206/1/525707.pdf`
  — the seven tail positions (Fig. 5.1, p. 114) and the Tail Up findings. **The position names are
  hers, not Kiley-Worthington's.**
- Evangelista MC, Watanabe R, Leung VSY, Monteiro BP, O'Toole E, Pang DSJ, Steagall PV (2019).
  Facial expressions of pain in cats: the development and validation of a Feline Grimace Scale.
  *Sci Rep* 9:19128. PMC6911058, CC BY. — **the only published numeric feline facial angles/ratios.**
- Caeiro CC, Burrows AM, Waller BM (2017). CatFACS. Manual free at
  `animalfacs.github.io/CatFACS/`. **`catfacs.com` is a squatted domain — do not cite it.**
- Kessler MR, Turner DC (1997). Cat-Stress-Score. *Animal Welfare* 6:243–254, Table 2 — ear, eye,
  pupil, whisker and tail rows by arousal level.
- Eckstein RA, Hart BL (2000). The organization and control of grooming in cats. *Appl Anim Behav
  Sci* 68(2):131–140. **Paywalled; the region-by-region order is inside the paywall.** Note this is
  the organisation paper, not the companion flea paper at 68:141–150.
- Gajdoš Kmecová N, Peťková B, Kottferová J, Skurková L, Mills DS (2021). Are these cats playing?
  *Front Vet Sci* 8:712310. PMC8343019. — reproduces West 1974's eight patterns verbatim; the
  play-bow and play-face negatives.
- West M (1974). Social play in the domestic cat. *Am Zool* 14:427–436. **OUP PDF Cloudflare-blocked;
  quoted at second hand via Gajdoš Kmecová et al. 2021 Table 1.**
- Leyhausen P (1979). *Cat Behavior: The Predatory and Social Behavior of Domestic and Wild Cats*.
  Garland STPM Press. — the watching posture, "wobbling", the flat spring, the ear/face rules, the
  whisker-envelope. ⚠️ **Read from a third-party OCR'd scan of a copyrighted book; verify page
  numbers against a library copy, and one duration numeral is destroyed by OCR.**
- Ellis JJ (2018). Recognising and assessing feline emotions. *J Feline Med Surg* 20:445–456.
  PMC11395287. — the ventral-flat fear posture (paws under body); frustrated vs contented grooming.
- Vitale KR (2022). The social lives of free-ranging cats. *Animals* 12:126. PMC8749887.
- Deputte BL, Jumelet E, Gilbert C, Titeux E (2021). *Animals* 11:2752. PMC8469685. — ears matter
  more than tail; n = 196.
- Bertolucci LF (2011). Pandiculation. *J Bodyw Mov Ther* 15(3):268–280; Fraser AF (1989). *Appl
  Anim Behav Sci* 23(3):263–268 (**paywalled, no abstract anywhere**); Golani & Kafkafi (2024)
  *Front Integr Neurosci*, PMC11832518 — the livestock/poultry sequential pattern.
- Berridge KC, Aldridge JW, Houchard KR, Zhuang X (2005). *BMC Biology* 3:4. PMC552313. — the
  4-phase syntactic grooming chain. **Rodent, not feline.**
- **Feldman HN (1994). Domestic cats and passive submission. *Animal Behaviour* 47(2):457–459.
  NOT RETRIEVABLE in any form** — closed access with no abstract in Europe PMC, Crossref, OpenAlex
  or Semantic Scholar. All 22 citing works traced. Anything attributed to Feldman here is
  second-hand.
- **Kiley-Worthington M (1976). *Behaviour* 56:69–114. Not obtained** (Brill 403). Second-hand via
  Cameron-Beaumont 1997. Commonly mis-cited as "1975, 46".

**Animation craft (§5)**
- **Williams R. *The Animator's Survival Kit*, Expanded Edition, Faber & Faber 2009** — "Animal
  Action" chapter, pp. 327–332, 354–359. **Cite the 2009 edition: only pp. 327–331 exist in the 2001
  first edition.** Read from an archive.org page scan; OCR mangles digits, so figures were taken from
  page images.
- **Whitaker H & Halas J. *Timing for Animation*, Focal Press** — "Timing Animals' Movements —
  Horses", "Other Quadrupeds", "Timing a Walk", "Types of Walk", "Timing an Oscillating Movement".
  Page numbers differ by edition. **The source of the ¼-cycle footfall statement and of the "no
  quadruped squash key" statement.**
- Blair P. *Cartoon Animation* / *How to Draw Cartoon Animation*, "Movements of the Four-Legged
  Figure". **Contains no quadruped frame counts, deliberately.**
- Goldberg E. *Character Animation Crash Course!* — "Drag and Overlap"; the contact-foot spacing rule.
- Thomas F & Johnston O. *The Illusion of Life*, principle 5, pp. 59–62. **No numeric lag given.**
- Webster C. *Animation: The Mechanics of Motion*, Fig. 5.5, pp. 162–163.
- **Muybridge E. *Animals in Motion* (1902)** — read from two archive.org scans
  (`animalsmotion00muyb`, `gri_33125012264293`): Series 11 (cat, 24 phases, .031 s, .71 s total),
  Series 40 (cat trot, 10 phases, .035 s), and the four-step footfall law. Public domain.
- **Muybridge E. *Animal Locomotion* (1887), Vol. X** — **Plate 716 "Cat; walking; change to
  galloping"**, 717–718 trot→gallop, 719–720 galloping. Records via Wikimedia Commons (Boston Public
  Library, USC Libraries).
- Polet DT & Bertram JEA (2019). An inelastic quadrupedal model discovers four-beat walking.
  *PLoS Comput Biol*. PMC6871776. — **verified** phase-offset definition and the symmetrical-gait
  half-stride rule. Does **not** contain Hildebrand's fractional bands, despite being cited for them.
- **Maes LD, Herbin M, Hackert R, Bels VL, Abourachid A (2008). Steady locomotion in dogs.
  *J Exp Biol* 211:138–149. DOGS ONLY** — five malinois, MeSH "Dogs", no cats. **Do not cite it for
  a cat limb phase.**
- **Abourachid A, Herbin M, Hackert R, Maes L, Martin V (2007). Experimental study of coordination
  patterns during unsteady locomotion in mammals. *J Exp Biol* 210. PMID 17210971. Paywalled, no
  PMC copy.** Covers **dogs and cats**; defines fore lag, hind lag, pair lag. **The paper to read to
  settle the cat's limb phase.**

**Persian breed**
- Sieslack J, Farke D, Failing K, Kramer M, Schmidt MJ (2021). Correlation of brachycephaly grade
  with level of exophthalmos … in Persian cats. *PLoS ONE* 16(7):e0254420. PMC8294563. — skull/
  cranial/facial indices, craniofacial angle, exophthalmos. **The one to pin.**
- Schmidt MJ, Kampschulte M, Enderlein S, et al. (2017). Brachycephalic head features in modern
  Persian cats … *J Vet Intern Med* 31:1487–1501. PMC5598898. — nose index, cranial index,
  interorbital distance, peke- vs doll-face. (Figure 2 legend contradicts the main text on
  head-type assignment; follow the main text.)
- O'Neill DG, Romans C, Brodbelt DC, et al. (2019). Persian cats under first opinion veterinary
  care in the UK. *Sci Rep* 9:12952. PMC6748978. — mass, n = 3,235.
- Häggström J, Ohlsson Å, Falk T, et al. (2025). … heart size in 56,169 pure-bred cats.
  *J Vet Intern Med*. PMC12124920. — Persian/Exotic median mass.
- Ramos J, Viegas I, Pereira H, Requicha JF (2021). Morphometrical study of the European shorthair
  cat skull using CT. *Vet Sci* 8(8):152. PMC8402625. — mesocephalic baseline; **incompatible
  cranial-index landmarks, see the trap note in §1.7.**
- Requicha JF, Sousa AR, Proença N, Válega A, Alves-Pimenta S (2026). Tomographic characterization
  of the European shorthair cat orbital and infraorbital regions. *Animals*. PMC12784816.
- Breed standards (quoted verbatim): CFA Persian Show Standard rev. 2025,
  cfa.org/wp-content/uploads/2024/03/persian-standard.pdf · FIFe EXO/PER valid 01.01.2026,
  fifeweb.org/wp-content/uploads/2023/10/EXO-PER.pdf · GCCF Persian SOP Oct 2023 ·
  WCF PER 2022-01-25 · ACFA PERSIAN PER-1 (acfacat.com/Breed%20Standards/PERSIAN.pdf — the source
  of the 1:1:1 shoulder/rump/back relation) · ACF (Australia) Persian Oct 2023.
  **TICA: not retrieved** — tica.org returns 403 on every path and its robots.txt disallows this
  agent (`User-agent: ClaudeBot / Disallow: /`, plus `Content-Signal: ai-train=no, use=reference`).
  Fetch it in a browser if needed.

**Sources checked and found not to contain what they are commonly cited for**
- Schlueter C, Budras KD, Ludewig E, et al. (2009). Brachycephalic feline noses. *J Feline Med
  Surg* 11:891–900. PMC11383020. — **contains no morphometry**; the authors say so themselves. It
  gives a 4-grade phenotypic scale only.
- Künzel W, Breit S, Oppel M (2003). Morphometric investigations of breed-specific features in
  feline skulls. *Anat Histol Embryol* 32:218–223. — **paywalled, not in PMC; values not found.**
- Tagliavia C, et al. (2026). Craniofacial variations in Persian cats. *Animals* 16(13):2001. —
  exists (10 Persian + 5 DSH dry skulls) but MDPI returned 403 and there is no PMCID; **numbers
  not retrieved.** The only Persian-vs-DSH dry-skull morphometry study; worth a browser fetch.
- Kim Y, Aoi S, Fujiki S, et al. (2022). *Front Bioeng Biotechnol*. PMC9023865. — cat hindlimb
  model, but its segment parameters are inherited from Ekeberg & Pearson (2005) and are not
  reproduced in the paper.
- Wikipedia, *Cat anatomy* — caudal vertebra counts are **self-contradictory (19–21 vs 22–23) and
  uncited.** Rejected.
