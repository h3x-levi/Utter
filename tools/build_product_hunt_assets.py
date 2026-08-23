from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "ProductHuntAssets" / "raw"
FINAL = ROOT / "ProductHuntAssets" / "final"
SIZE = (1920, 1080)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        Path("/System/Library/Fonts/SFNS.ttf"),
        Path("/System/Library/Fonts/SFNSRounded.ttf"),
        Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
             else "/System/Library/Fonts/Supplemental/Arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


TITLE = font(62, bold=True)
SUBTITLE = font(28)
LABEL = font(25, bold=True)


def background() -> Image.Image:
    image = Image.new("RGBA", SIZE)
    pixels = image.load()
    for y in range(SIZE[1]):
        t = y / (SIZE[1] - 1)
        for x in range(SIZE[0]):
            s = x / (SIZE[0] - 1)
            pixels[x, y] = (
                int(13 + 22 * s + 9 * t),
                int(12 + 7 * s + 4 * t),
                int(19 + 33 * s + 20 * t),
                255,
            )
    return image


def heading(canvas: Image.Image, title: str, subtitle: str = "") -> None:
    draw = ImageDraw.Draw(canvas)
    draw.text((100, 72), title, font=TITLE, fill=(250, 248, 255, 255))
    if subtitle:
        draw.text((104, 150), subtitle, font=SUBTITLE, fill=(187, 181, 199, 255))


def fit(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    width = box[2] - box[0]
    height = box[3] - box[1]
    scale = min(width / image.width, height / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(size, Image.Resampling.LANCZOS)


def place(canvas: Image.Image, image: Image.Image, box: tuple[int, int, int, int]) -> None:
    image = fit(image.convert("RGBA"), box)
    x = box[0] + (box[2] - box[0] - image.width) // 2
    y = box[1] + (box[3] - box[1] - image.height) // 2

    alpha = image.getchannel("A")
    shadow = Image.new("RGBA", canvas.size)
    shadow_alpha = Image.new("L", canvas.size)
    shadow_alpha.paste(alpha, (x, y + 18))
    shadow_alpha = shadow_alpha.filter(ImageFilter.GaussianBlur(24))
    shadow.putalpha(shadow_alpha.point(lambda value: int(value * 0.55)))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(image, (x, y))


def load(name: str) -> Image.Image:
    return Image.open(RAW / name).convert("RGBA")


def save(image: Image.Image, name: str) -> None:
    FINAL.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(FINAL / name, quality=95)


def pill_states() -> None:
    canvas = background()
    heading(
        canvas,
        "One pill, every stage of dictation",
        "The production UI rendered directly from Utter’s SwiftUI views.",
    )
    states = [
        ("Ready", "pill-idle.png"),
        ("Recording", "pill-recording.png"),
        ("Hands-free", "pill-hands-free.png"),
        ("Transcribing", "pill-processing.png"),
        ("Needs attention", "pill-error.png"),
        ("Dictating into a note", "pill-note.png"),
    ]
    boxes = [
        (90, 245, 600, 550),
        (705, 245, 1215, 550),
        (1320, 245, 1830, 550),
        (90, 650, 600, 975),
        (705, 650, 1215, 975),
        (1320, 650, 1830, 975),
    ]
    draw = ImageDraw.Draw(canvas)
    for (label, filename), box in zip(states, boxes):
        place(canvas, load(filename), box)
        text_box = draw.textbbox((0, 0), label, font=LABEL)
        text_width = text_box[2] - text_box[0]
        draw.text(
            ((box[0] + box[2] - text_width) // 2, box[3] + 10),
            label,
            font=LABEL,
            fill=(226, 221, 236, 255),
        )
    save(canvas, "01-pill-state-transformation.png")


def meeting_offer() -> None:
    canvas = background()
    heading(
        canvas,
        "The pill becomes a transcription offer",
        "Utter detects a likely call, asks first, and never records without approval.",
    )
    place(canvas, load("transcribe-offer.png"), (520, 255, 1400, 720))
    place(canvas, load("pill-idle.png"), (785, 790, 1135, 1010))
    draw = ImageDraw.Draw(canvas)
    draw.line((960, 755, 960, 700), fill=(126, 150, 255, 255), width=7)
    draw.polygon([(946, 718), (974, 718), (960, 696)], fill=(126, 150, 255, 255))
    save(canvas, "02-transcribe-offer.png")


def companion() -> None:
    canvas = background()
    heading(
        canvas,
        "A code-drawn pixel companion",
        "It reacts to dictation, cursor movement, and typing rate—never typed content.",
    )
    place(canvas, load("pixel-cat-poses.png"), (120, 260, 1800, 880))
    save(canvas, "03-pixel-cat-companion.png")


def main_window() -> None:
    canvas = background()
    heading(
        canvas,
        "Private dictation, ready across macOS",
        "Permission, model, AI, and network readiness remain visible at a glance.",
    )
    screenshot = load("main-dictation.png")
    screenshot = screenshot.crop((0, 0, screenshot.width, 1280))
    place(canvas, screenshot, (80, 240, 1840, 1015))
    save(canvas, "04-main-window.png")


def paired_windows(
    output: str,
    title: str,
    subtitle: str,
    left: str,
    right: str,
) -> None:
    canvas = background()
    heading(canvas, title, subtitle)
    place(canvas, load(left), (55, 245, 955, 1015))
    place(canvas, load(right), (965, 245, 1865, 1015))
    save(canvas, output)


def single_window(output: str, title: str, subtitle: str, source: str) -> None:
    canvas = background()
    heading(canvas, title, subtitle)
    place(canvas, load(source), (70, 230, 1850, 1035))
    save(canvas, output)


def build() -> None:
    pill_states()
    meeting_offer()
    companion()
    main_window()
    paired_windows(
        "05-dictionary-and-snippets.png",
        "Teach Utter your words and reusable phrases",
        "Custom vocabulary improves recognition; snippets expand spoken triggers.",
        "main-dictionary.png",
        "main-snippets.png",
    )
    single_window(
        "06-voice-transforms.png",
        "Transform text by voice",
        "Restyle, translate, fix, summarize, reply, or define custom commands.",
        "main-transforms.png",
    )
    paired_windows(
        "07-notes-and-companion.png",
        "Capture ideas—and keep a little company",
        "Searchable notes, meeting capture, and a draggable reactive companion.",
        "main-notes.png",
        "main-companion.png",
    )
    single_window(
        "08-settings-general.png",
        "Native macOS controls and preferences",
        "Global behavior, sound, notes, hotkeys, permissions, and pill controls.",
        "settings-general.png",
    )
    single_window(
        "09-settings-speech.png",
        "Choose the speech model that fits your Mac",
        "Compare speed, memory, accuracy, and optional on-device recognition features.",
        "settings-speech.png",
    )


if __name__ == "__main__":
    build()
