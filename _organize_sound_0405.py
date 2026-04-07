# -*- coding: utf-8 -*-
"""
（舊流程）依 sound_0405/sound_0405.xlsx 分類。若要「中文資料夾＋依內嵌 metadata 中文檔名」請改跑
_sound_0405_chinese_layout.py。

依 sound_0405/sound_0405.xlsx 將音效分類到子資料夾，並重新命名為「資料夾名_01.wav」形式。

- 比對：試算表第 2 欄前綴（「 / 」左側）；可選「代碼前綴」擴展（如 MAGMisc_）。
- 同一資料夾內依檔名字母排序後編號；位數隨數量自動加寬（至少 2 位）。
- 未匹配檔案可選擇收進「未分類」並編號。
- 會刪除舊的 .wav.import，請關閉 Godot 後執行，重開專案讓匯入重建。
"""
from __future__ import annotations

import re
import shutil
import sys
import uuid
from collections import defaultdict
from pathlib import Path

import openpyxl

# 不套用「代碼_」廣義前綴的開頭代碼（避免 OBJMisc_ 把整包理髮／道具都塞進「剪刀」）
BROAD_PREFIX_DENY: frozenset[str] = frozenset({"OBJMisc"})

# 試算表以外的 (前綴, 資料夾名)。最長前綴仍優先於較短者（可與試算表並存）。
# 例：("AMB", "環境總匯") 可把 AMBTown_ 等收進同一夾，但不會蓋過試算表較長的 AMBDsgn_Evil…。
EXTRA_PREFIX_RULES: list[tuple[str, str]] = []

# 未匹配檔是否集中放到此資料夾並編號；None = 維持原路徑不動
UNMATCHED_FOLDER: str | None = "未分類"

STAGING_DIRNAME = ".reorg_staging"


def _project_root() -> Path:
    return Path(__file__).resolve().parent


def load_rules(xlsx_path: Path) -> tuple[list[tuple[str, str]], set[str]]:
    wb = openpyxl.load_workbook(xlsx_path, read_only=True, data_only=True)
    try:
        ws = wb.active
        raw: list[tuple[str, str]] = []
        folder_names: set[str] = set()
        for i, row in enumerate(ws.iter_rows(values_only=True)):
            if i == 0:
                continue
            if not row or len(row) < 3:
                continue
            key_cell, folder_cell = row[1], row[2]
            if key_cell is None or folder_cell is None:
                continue
            key = str(key_cell).strip()
            folder = str(folder_cell).strip()
            if not key or not folder:
                continue
            if " / " in key:
                key = key.split(" / ", 1)[0].strip()
            raw.append((key, folder))
            folder_names.add(folder)
        return raw, folder_names
    finally:
        wb.close()


def expand_rules(rules: list[tuple[str, str]]) -> list[tuple[str, str]]:
    """加入廣義前綴（代碼 + '_'）：僅當該代碼在試算表中只對應一個目標資料夾時才加入。"""
    by_head: dict[str, set[str]] = defaultdict(set)
    for key, folder in rules:
        if "_" not in key:
            continue
        by_head[key.split("_", 1)[0]].add(folder)

    out: list[tuple[str, str]] = list(rules)
    seen: set[tuple[str, str]] = set(rules)
    for key, folder in rules:
        if "_" not in key:
            continue
        head = key.split("_", 1)[0]
        if len(head) < 4:
            continue
        if head in BROAD_PREFIX_DENY:
            continue
        if len(by_head[head]) != 1:
            continue
        broad = head + "_"
        if broad == key:
            continue
        pair = (broad, folder)
        if pair not in seen:
            seen.add(pair)
            out.append(pair)
    return out


def import_sidecar(wav: Path) -> Path:
    return wav.parent / f"{wav.name}.import"


def delete_import_sidecar(wav: Path) -> None:
    p = import_sidecar(wav)
    if p.is_file():
        p.unlink()


def infer_folder_from_layout(
    wav: Path, root: Path, folder_names: set[str]
) -> str | None:
    """已整理成 子資料夾/資料夾名_數字.wav 的檔案，直接歸入該組。"""
    try:
        rel = wav.relative_to(root)
    except ValueError:
        return None
    if len(rel.parts) != 2:
        return None
    folder, fname = rel.parts[0], rel.name
    if folder not in folder_names and folder != UNMATCHED_FOLDER:
        return None
    stem = Path(fname).stem
    if stem == folder:
        return folder
    esc = re.escape(folder)
    if re.fullmatch(esc + r"_\d+", stem):
        return folder
    return None


def assign_folder(
    wav: Path,
    root: Path,
    rules: list[tuple[str, str]],
    folder_names: set[str],
) -> str | None:
    inferred = infer_folder_from_layout(wav, root, folder_names)
    if inferred is not None:
        return inferred
    stem = wav.stem
    best_key: str | None = None
    best_folder: str | None = None
    for key, folder in rules:
        if stem == key or stem.startswith(key):
            if best_key is None or len(key) > len(best_key):
                best_key = key
                best_folder = folder
    return best_folder


def collect_wavs(root: Path) -> list[Path]:
    skip = {STAGING_DIRNAME}
    out: list[Path] = []
    for p in root.rglob("*.wav"):
        if not p.is_file():
            continue
        parts = set(p.relative_to(root).parts)
        if parts & skip:
            continue
        out.append(p)
    return sorted(out, key=lambda x: x.as_posix().lower())


def main() -> int:
    root = _project_root() / "assets圖片_字體_音效" / "sound_0405"
    xlsx = root / "sound_0405.xlsx"
    if not xlsx.is_file():
        print("Missing:", xlsx, file=sys.stderr)
        return 1

    base_rules, folder_names = load_rules(xlsx)
    rules = expand_rules(base_rules) + list(EXTRA_PREFIX_RULES)
    for _, folder in EXTRA_PREFIX_RULES:
        folder_names.add(folder)
    wavs = collect_wavs(root)
    if not wavs:
        print("No wav under", root, file=sys.stderr)
        return 1

    groups: dict[str, list[Path]] = {}
    for w in wavs:
        folder = assign_folder(w, root, rules, folder_names)
        if folder is None and UNMATCHED_FOLDER:
            folder = UNMATCHED_FOLDER
        if folder is None:
            continue
        groups.setdefault(folder, []).append(w)

    staging = root / STAGING_DIRNAME
    staging.mkdir(parents=True, exist_ok=True)

    staged: list[tuple[Path, str]] = []

    try:
        for folder, paths in groups.items():
            paths_sorted = sorted(paths, key=lambda p: p.as_posix().lower())
            for _, src in enumerate(paths_sorted, start=1):
                delete_import_sidecar(src)
                tmp_name = f"{uuid.uuid4().hex}.wav"
                tmp_path = staging / tmp_name
                shutil.move(str(src), str(tmp_path))
                staged.append((tmp_path, folder))

        for folder, paths in groups.items():
            paths_sorted = sorted(
                [t for t, f in staged if f == folder], key=lambda p: p.as_posix().lower()
            )
            n = len(paths_sorted)
            width = max(2, len(str(n)))
            dest_dir = root / folder
            dest_dir.mkdir(parents=True, exist_ok=True)
            for i, src in enumerate(paths_sorted, start=1):
                final_name = f"{folder}_{i:0{width}d}.wav"
                dest = dest_dir / final_name
                shutil.move(str(src), str(dest))
    finally:
        if staging.exists():
            try:
                staging.rmdir()
            except OSError:
                pass

    for d in sorted(
        (p for p in root.iterdir() if p.is_dir() and p.name not in (STAGING_DIRNAME,)),
        key=lambda p: p.as_posix(),
        reverse=True,
    ):
        if d.name in folder_names or (UNMATCHED_FOLDER and d.name == UNMATCHED_FOLDER):
            continue
        try:
            if not any(d.iterdir()):
                d.rmdir()
        except OSError:
            pass

    total = sum(len(v) for v in groups.values())
    print(f"Processed {total} wav into {len(groups)} folder(s) under {root}")
    if UNMATCHED_FOLDER and UNMATCHED_FOLDER in groups:
        print(f"  ({UNMATCHED_FOLDER}: {len(groups[UNMATCHED_FOLDER])} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
