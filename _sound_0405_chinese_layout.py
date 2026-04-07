# -*- coding: utf-8 -*-
"""
依 WAV 內嵌 metadata（title / genre / comment）自動分類到中文資料夾，並改為簡短中文檔名。

採用 15 個細分類（介面、人聲、交通工具、戰鬥、魔法與怪物、動物蟲鳥、天候自然、環境空間、
生活擬音、機械電子、轉場旋律、飛行、船隻、運動裝備、其他），以降低誤判。

需 ffprobe（PATH 或 D:\\ComfyUI\\ffmpeg\\bin\\ffprobe.exe）。
關閉 Godot 後執行；完成後重開專案讓匯入重建。
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

STAGING = ".metadata_restage"
SKIP_DIRS = {STAGING}

# (關鍵字, 分數, 資料夾名) — 同分時保留清單中較前的規則
CATEGORY_RULES: list[tuple[tuple[str, ...], int, str]] = [
    (
        (
            "ui ",
            "interface",
            "button",
            "menu",
            "click",
            "kalimba",
            "xylophone",
            "notification",
            "glitch",
            "error",
            "collect",
            "inventory",
            "deploy",
            "power up",
            "board game",
            "game play",
        ),
        3,
        "介面與按鈕",
    ),
    (
        (
            "voice",
            "vocal",
            "announcer",
            "cry",
            "laugh",
            "breath",
            "grunt",
            "anime",
            "police radio",
            "spectator",
            "futz",
            "reac",
            "warrior",
            "schoolgirl",
        ),
        3,
        "人聲語音",
    ),
    (
        (
            "car ",
            "vehicle",
            "motorcycle",
            "engine",
            "horn",
            "skid",
            "train",
            "tram",
            "truck",
            "driving",
            "freight",
            "bike",
            "cup holder",
            "climate control",
            "gas and brake",
            "pass by",
        ),
        3,
        "交通工具",
    ),
    (
        (
            "sword",
            "weapon",
            "swing",
            "shield",
            "punch",
            "fight",
            "combat",
            "blade",
            "whip",
            "spear",
            "grab",
            "choking",
            "melee",
            "blood spill",
            "explosion",
            "blast",
            "punch impact",
            "body impact",
        ),
        3,
        "戰鬥與打擊",
    ),
    (
        (
            "magic",
            "spell",
            "evil",
            "ghost",
            "haunt",
            "werewolf",
            "orc",
            "creature",
            "dinosaur",
            "dragon",
            "beast",
            "insectoid",
            "sea beast",
            "entity",
            "death whistle",
            "ethereal",
        ),
        3,
        "魔法與怪物",
    ),
    (
        (
            "dog ",
            "bark",
            "frog",
            "reptile",
            "hatchling",
            "raptor",
            "animal",
            "dino",
            "egg",
            "bird",
            "cricket",
            "insect",
            "jungle night",
            "pipits",
        ),
        3,
        "動物與蟲鳥",
    ),
    (
        (
            "rain",
            "thunder",
            "storm",
            "hail",
            "wind",
            "wave",
            "water",
            "fire ",
            "flame",
            "crackle",
            "campfire",
            "ocean",
            "lake",
            "river",
            "splash",
            "bubble",
            "snow",
            "ice ",
        ),
        3,
        "天候水火自然",
    ),
    (
        (
            "ambience",
            "ambiance",
            "roomtone",
            "walla",
            "crowd",
            "city",
            "street",
            "park",
            "metro",
            "station",
            "factory",
            "construction",
            "traffic",
            "interior",
            "jungle",
            "forest",
            "night",
            "urban",
            "pub ",
            "distant",
            "courtyard",
            "paintball",
            "cruise ship",
            "battlefield",
        ),
        2,
        "環境與空間",
    ),
    (
        (
            "typewriter",
            "telephone",
            "radio",
            "paper",
            "book",
            "page",
            "zipper",
            "cloth",
            "velcro",
            "luggage",
            "suitcase",
            "scissor",
            "hair ",
            "barber",
            "spray",
            "cracker",
            "scratch",
            "coin",
            "foley",
            "broom",
            "sitting",
            "washing",
            "tape measure",
            "door",
            "latch",
            "switch",
            "clock",
            "tick",
        ),
        2,
        "生活擬音與道具",
    ),
    (
        (
            "metal",
            "wood ",
            "wooden",
            "glass",
            "plastic",
            "mechanism",
            "servo",
            "robot",
            "electric",
            "arc",
            "buzz",
            "thermometer",
            "static",
            "hum ",
            "synth",
            "reactor",
            "tonal",
            "scrape",
            "rattle",
            "spring",
        ),
        2,
        "機械金屬電子",
    ),
    (
        (
            "music box",
            "musicbox",
            "bell",
            "church bell",
            "firework",
            "alarm",
            "boom",
            "braam",
            "downer",
            "drop",
            "trailer",
            "whoosh",
            "swoosh",
            "transition",
            "stinger",
            "jumpscare",
            "noise box",
        ),
        2,
        "轉場警示與旋律片段",
    ),
    (
        ("airplane", "plane", "jet", "quadcopter", "drone", "helicopter"),
        2,
        "飛行載具",
    ),
    (("boat", "diesel engine boat"), 2, "船隻與水域載具"),
    (("climb", "carabiner", "rope", "gear"), 2, "運動與戶外裝備"),
]

NAME_HINTS: list[tuple[tuple[str, ...], str]] = [
    (("rain",), "雨聲"),
    (("thunder", "lightning", "storm"), "雷雨"),
    (("wind", "gust"), "風聲"),
    (("wave", "water", "ocean", "lake", "splash"), "水聲"),
    (("fire", "crackle", "flame", "campfire"), "火焰"),
    (("crowd", "walla", "cheer"), "人群"),
    (("traffic", "street", "city"), "街市"),
    (("forest", "bird", "cricket", "insect", "jungle"), "林間"),
    (("night", "humid"), "夜晚"),
    (("click", "button", "ui"), "按鈕"),
    (("metal",), "金屬"),
    (("wood",), "木頭"),
    (("glass",), "玻璃"),
    (("door",), "門"),
    (("footstep", "walk"), "腳步"),
    (("sword", "blade"), "刀劍"),
    (("punch", "fight"), "拳擊"),
    (("magic", "spell"), "魔法"),
    (("dog", "bark"), "狗"),
    (("train", "tram"), "火車"),
    (("car", "driving", "vehicle"), "汽車"),
    (("explosion", "blast"), "爆炸"),
    (("whoosh", "swoosh"), "呼嘯"),
    (("clock", "tick"), "鐘錶"),
    (("paper", "book", "page"), "紙張"),
    (("voice", "vocal"), "人聲"),
    (("music box", "musicbox"), "音樂盒"),
    (("alarm",), "警報"),
    (("horn",), "喇叭"),
    (("engine",), "引擎"),
]


def find_ffprobe() -> str | None:
    candidates = ["ffprobe", r"D:\ComfyUI\ffmpeg\bin\ffprobe.exe"]
    flags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    for c in candidates:
        try:
            r = subprocess.run(
                [c, "-version"],
                capture_output=True,
                text=True,
                timeout=5,
                creationflags=flags,
            )
            if r.returncode == 0:
                return c
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            continue
    return None


def ffprobe_tags(path: Path, ffprobe: str) -> dict[str, str]:
    flags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    try:
        r = subprocess.run(
            [ffprobe, "-v", "quiet", "-print_format", "json", "-show_format", str(path)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
            creationflags=flags,
        )
        if r.returncode != 0:
            return {}
        data = json.loads(r.stdout or "{}")
        fmt = data.get("format") or {}
        tags = fmt.get("tags") or {}
        return {str(k).lower(): str(v) for k, v in tags.items() if v is not None}
    except (json.JSONDecodeError, subprocess.TimeoutExpired, OSError):
        return {}


def haystack(tags: dict[str, str], stem: str) -> str:
    parts = [
        tags.get("title", ""),
        tags.get("comment", ""),
        tags.get("genre", ""),
        tags.get("album", ""),
        tags.get("artist", ""),
        stem,
    ]
    return " ".join(parts).lower()


def classify(hay: str) -> str:
    best_score = 0
    best_i = 10**9
    best_cat = "其他音效"
    for i, (kws, weight, cat) in enumerate(CATEGORY_RULES):
        sc = sum(weight for kw in kws if kw in hay)
        if sc > best_score or (sc == best_score and sc > 0 and i < best_i):
            best_score = sc
            best_cat = cat
            best_i = i
    return best_cat


def brief_zh(hay: str) -> str:
    seen: list[str] = []
    for kws, zh in NAME_HINTS:
        if any(kw in hay for kw in kws):
            if zh not in seen:
                seen.append(zh)
    s = "".join(seen[:4]) if seen else ""
    if not s:
        s = "音效"
    return s[:20]


def sanitize_stem(s: str) -> str:
    s = re.sub(r'[\\/:*?"<>|]', "_", s)
    s = re.sub(r"\s+", "", s)
    return s or "音效"


def delete_import_sidecar(wav: Path) -> None:
    p = wav.parent / f"{wav.name}.import"
    if p.is_file():
        p.unlink()


def collect_wavs(root: Path) -> list[Path]:
    out: list[Path] = []
    for p in root.rglob("*.wav"):
        if not p.is_file():
            continue
        rel = p.relative_to(root)
        if rel.parts and rel.parts[0] in SKIP_DIRS:
            continue
        out.append(p)
    return sorted(out, key=lambda x: x.as_posix().lower())


def main() -> int:
    root = Path(__file__).resolve().parent / "assets圖片_字體_音效" / "sound_0405"
    if not root.is_dir():
        print("Missing folder:", root, file=sys.stderr)
        return 1

    ffprobe = find_ffprobe()
    if not ffprobe:
        print("ffprobe not found.", file=sys.stderr)
        return 1

    wavs = collect_wavs(root)
    if not wavs:
        print("No wav files.", file=sys.stderr)
        return 1

    rows: list[tuple[Path, str, str, str]] = []
    for w in wavs:
        tags = ffprobe_tags(w, ffprobe)
        hay = haystack(tags, w.stem)
        cat = classify(hay)
        sort_key = (tags.get("title") or tags.get("comment") or w.stem).lower()
        rows.append((w, cat, sort_key, brief_zh(hay)))

    by_cat: dict[str, list[tuple[Path, str, str]]] = {}
    for w, cat, sk, bzh in rows:
        by_cat.setdefault(cat, []).append((w, sk, bzh))

    staging = root / STAGING
    staging.mkdir(parents=True, exist_ok=True)
    staged: list[tuple[Path, str, str]] = []

    try:
        for cat in sorted(by_cat.keys()):
            for w, _, bzh in sorted(by_cat[cat], key=lambda x: x[1]):
                delete_import_sidecar(w)
                tmp = staging / f"{uuid.uuid4().hex}.wav"
                shutil.move(str(w), str(tmp))
                staged.append((tmp, cat, bzh))

        totals = {c: sum(1 for _, ca, _ in staged if ca == c) for c in by_cat}
        widths = {c: max(3, len(str(totals[c]))) for c in totals}
        counts: dict[str, int] = {}

        for tmp, cat, bzh in sorted(staged, key=lambda x: (x[1], x[0].name)):
            dest_dir = root / cat
            dest_dir.mkdir(parents=True, exist_ok=True)
            counts[cat] = counts.get(cat, 0) + 1
            n = counts[cat]
            stem = sanitize_stem(bzh)
            final = f"{stem}_{n:0{widths[cat]}d}.wav"
            dest = dest_dir / final
            shutil.move(str(tmp), str(dest))
    finally:
        if staging.exists():
            for left in staging.glob("*"):
                left.unlink(missing_ok=True)
            try:
                staging.rmdir()
            except OSError:
                pass

    for d in sorted((p for p in root.iterdir() if p.is_dir()), key=lambda p: p.as_posix(), reverse=True):
        if d.name in SKIP_DIRS or d.name in by_cat:
            continue
        try:
            if not any(d.iterdir()):
                d.rmdir()
        except OSError:
            pass

    print(f"Done: {len(wavs)} files → {len(by_cat)} categories under {root}")
    for c in sorted(by_cat.keys(), key=lambda x: x.encode("utf-8")):
        print(f"  {c}: {len(by_cat[c])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
