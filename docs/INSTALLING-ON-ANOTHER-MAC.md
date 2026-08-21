# Installing Utter on another Mac

Utter is signed, but it is not **notarized** — notarization requires a paid Apple Developer
account, and this project deliberately does not have one. So macOS will refuse to open it on any
Mac other than the one it was built on, until you approve it once by hand.

This is not a sign that anything is wrong with the build. Verified on the shipped image:

```
$ spctl -a -vvv -t install Utter-3.0.15.dmg
Utter-3.0.15.dmg: rejected
source=no usable signature

$ xcrun stapler validate Utter-3.0.15.dmg
Utter-3.0.15.dmg does not have a ticket stapled to it.
```

The app's own signature is intact and valid — `codesign --verify --deep --strict` passes. What is
missing is Apple's notarization ticket.

## Whether you get blocked depends on how the file arrives

macOS only enforces this on files carrying a **quarantine** flag, which the *receiving* program
applies:

| How you move it | Quarantined? | What happens |
|---|---|---|
| USB stick, `scp`, `rsync`, external drive | No | Opens normally, no approval needed |
| Downloaded in a browser | Yes | Blocked until approved |
| AirDrop | Yes | Blocked until approved |
| Email or chat attachment | Yes | Blocked until approved |

So the least friction is a USB stick or `scp`. If the file already carries the flag, use one of the
two routes below.

## Route 1: approve it in System Settings

1. Open the DMG and drag **Utter** to Applications.
2. Try to open Utter. macOS refuses, with "Apple could not verify Utter is free of malware".
3. Open **System Settings → Privacy & Security**, scroll to Security, and click **Open Anyway**
   next to the message about Utter.
4. Open Utter again and confirm.

The old trick of Control-clicking the app and choosing Open does not work: Apple removed that
bypass in macOS 15. System Settings is the only route in the interface now.

## Route 2: remove the quarantine flag in Terminal

Faster if you have a terminal open, and it does the same thing:

```sh
xattr -dr com.apple.quarantine /Applications/Utter.app
```

Then open the app normally. You can run this on the `.dmg` before mounting it instead, which avoids
the refusal entirely.

## Permissions have to be granted again on each Mac

Separate from Gatekeeper: macOS ties Microphone, Accessibility and Screen Recording grants to the
machine, so the new Mac prompts for them on first use regardless of what the old one allowed.

- **Microphone** — prompted on the first dictation.
- **Accessibility** — needed for the hotkey and for typing text into other apps. Grant it in
  System Settings → Privacy & Security → Accessibility.
- **Screen Recording** — only for meeting capture, and only on hardware where the narrower
  system-audio route is unavailable.

## What would remove all of this

A paid Apple Developer account ($99/year), which allows a `Developer ID Application` certificate.
Three changes then make the installer open anywhere with no warning:

1. Sign with `Developer ID Application` and add `--options runtime --timestamp` for the hardened
   runtime, which notarization requires. The app currently signs with `flags=0x0(none)`, so the
   hardened runtime is off.
2. Submit the DMG to `notarytool`, then staple the returned ticket to both the app and the image.
3. Sign the DMG itself — right now only the app inside it is signed.

Until then, treat this installer as something you send to people who already trust you, and send
them this page with it.
