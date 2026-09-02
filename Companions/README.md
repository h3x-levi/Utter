# Companion packs

Utter’s built-in Charcoal Cat, Ginger Cat, Pixel Dog, and Pixel Panda are drawn
procedurally in `Sources/UtterKit/Companion/CodePixelCat.swift`. Production does not
load or bundle PNG artwork for these ids:

- `pixel-cat-gray`
- `pixel-cat-orange`
- `dog`
- `panda`

The code renderer supplies every mood, walk cycle, drag pose, and object interaction.
`SpritePackStore` reserves these ids, and `scripts/build-app.sh` excludes the legacy
image folders from `Utter.app`.

The image folders still present here are historical comparison material only. They are
not reachable from production execution and can be removed after visual migration review.

## User-installed characters

Users can add their own licensed artwork under:

```text
~/Library/Application Support/Utter/Companions/<pack-id>/
```

Supported layouts are documented on `SpritePack` in
`Sources/UtterKit/Companion/SpritePack.swift`: an animated PNG per state, numbered PNG
frames per state, or a sprite strip described by `pack.json`. A user pack whose id matches
a built-in id is ignored so it cannot replace the code-rendered companion.
