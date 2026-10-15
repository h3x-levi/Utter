# Third-party notices

## agent-robot-avatar

The robot companion in `Sources/UtterKit/Companion/Robot/` is a native Swift port of agent-robot-avatar by CX ArtLab.

Source: https://github.com/CX-ArtLab/agent-robot-avatar

The robot's name, character and visual identity belong to CX ArtLab; Utter does not present it as its own character.

```
MIT License

Copyright (c) 2026 CX ART Lab

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Whistle and libneedle (Cactus Compute)

The optional Fast speech engine links Cactus Compute's prebuilt `libneedle.a` and `needle.h` (`Vendor/Needle/`) and bundles the Whistle model `whistle.cact` (`Models/`). The x86_64 slice of `Vendor/Needle/Needle.xcframework` is Utter's own stub, not Cactus code.

Sources, pinned in `Vendor/Needle/CHECKSUMS`:
- https://huggingface.co/Cactus-Compute/needle3 at commit 93e88ede867e4311c39151285e74df513e4b835b (`macos-arm64/`)
- https://huggingface.co/Cactus-Compute/whistle at commit ca5287601bef25af26dcf2e1b2bdc0843a7c19e5

Licence: Apache License 2.0, copyright Cactus Compute. Both repositories ship the standard Apache 2.0 text and no NOTICE file. The full text is the same as the licence in Utter's `LICENSE`.

## whisper.cpp

The Accurate speech engine links whisper.cpp v1.9.2 as `WhisperFramework`, pinned by URL and checksum in `Package.swift`.

Source: https://github.com/ggml-org/whisper.cpp

```
MIT License

Copyright (c) 2023-2026 The ggml authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Silero VAD

Both apps bundle `Models/ggml-silero-v6.2.0.bin`, the Silero VAD model converted to ggml by the whisper.cpp authors, so whisper can skip stretches with no speech.

Source: https://github.com/snakers4/silero-vad, converted file from https://huggingface.co/ggml-org/whisper-vad at commit 9ffd54a1e1ee413ddf265af9913beaf518d1639b

```
MIT License

Copyright (c) 2020-present Silero Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
