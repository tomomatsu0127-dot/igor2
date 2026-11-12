"""Read measurements from an Igor packed experiment and export reviewed curves."""
from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
import re
from tempfile import TemporaryDirectory
import unicodedata

import numpy as np
from igor2 import packed
from igor2.record.wave import WaveRecord


AUTO_NAME = re.compile(r"int_(\d+(?:[_-].+)?)", re.I | re.ASCII)
NUMBER = re.compile(r"[0-9]{1,16}")
NAME_NUMBER = re.compile(r"^(?:sample[ _-]?)?([0-9]{1,16})(?=$|[ _-])", re.I)
FOLDER_NUMBER = re.compile(r"(?:sample[ _-]?)?([0-9]{1,16})", re.I)
GASES = {
    "air": "Air", "n2": "N2", "ar": "Ar", "o2": "O2",
    "vac": "真空", "vacuum": "真空",
}
UNWRITTEN = "条件未記載"


def decode_name(value: str | bytes) -> str:
    if isinstance(value, str):
        return value
    try:
        return value.decode("utf-8")
    except UnicodeDecodeError:
        return value.decode("cp932", errors="replace")


def wave_path(parts: tuple[str, ...]) -> str:
    return "root:" + ":".join(parts)


def infer_metadata(parts: tuple[str, ...]) -> tuple[str, str, str]:
    folders, name = parts[:-1], parts[-1]
    stem = name[4:] if name.lower().startswith("int_") else name
    numbers = {
        match[1] for folder in folders
        if (match := FOLDER_NUMBER.fullmatch(folder))
    }
    if match := NAME_NUMBER.match(stem):
        numbers.add(match[1])
    notes = []
    number = next(iter(numbers)) if len(numbers) == 1 else ""
    if len(numbers) > 1:
        notes.append("試料番号の候補が複数")
    text = "_".join((*folders, stem))
    text = unicodedata.normalize("NFKC", text).lower().replace("°", "")
    for label, code in (
        ("大気中", "air"), ("空気中", "air"), ("窒素", "n2"),
        ("真空", "vacuum"), ("仮焼", "presinter"), ("粉砕", "milled"),
    ):
        text = text.replace(label, f"_{code}_")
    text = re.sub(r"(?<=\d)\s+c(?=$|[^a-z]|\s*in)", "c", text)
    text = re.sub(r"(\d{2,4}c)(?=(?:in)?(?:air|n2|ar|o2|vac(?:uum)?)(?:$|[^a-z0-9]))", r"\1_", text)
    tokens = re.split(r"[^a-z0-9.]+", text)
    temperatures = {f"{int(token[:-1])}C" for token in tokens if re.fullmatch(r"[0-9]{2,4}c", token)}
    atmospheres = {GASES[key] for token in tokens if (key := token.removeprefix("in")) in GASES}
    durations = {
        f"{float(match[1]):g}{'min' if match[2] == 'min' else 'h'}"
        for token in tokens if (match := re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)(h|hr|min)", token))
    }
    stages = []
    if any(re.fullmatch(r"presinter(?:ed|d)?", token) for token in tokens):
        stages.append("仮焼")
    if "milled" in tokens:
        stages.append("粉砕")
    if any(len(values) > 1 for values in (temperatures, atmospheres, durations)):
        notes.append("焼成条件の候補が複数")
        condition = ""
    else:
        condition = " ".join((*temperatures, *atmospheres, *durations, *stages))
    return number, condition, "、".join(notes)


@dataclass
class Measurement:
    angle_path: tuple[str, ...]
    intensity_path: tuple[str, ...]
    angles: np.ndarray
    intensities: np.ndarray
    number: str
    condition: str
    note: str
    method: str
    status: str = "未確認"

    @classmethod
    def from_waves(cls, angle_path, intensity_path, angles, intensities, method):
        if (
            angle_path == intensity_path or len(angles) != len(intensities)
            or not np.all(np.isfinite(angles)) or not np.all(np.isfinite(intensities))
            or angles[0] < 0 or angles[-1] > 180
            or not np.all(angles[1:] > angles[:-1])
        ):
            raise ValueError("点数が等しく、2θ が 0～180° で単調に増加する2本を選んでください。")
        number, condition, note = infer_metadata(intensity_path)
        return cls(angle_path, intensity_path, angles, intensities, number, condition, note, method)


@dataclass
class Experiment:
    source: Path
    waves: dict[tuple[str, ...], np.ndarray]
    measurements: list[Measurement]
    rejected: int

    @classmethod
    def read(cls, source: Path) -> Experiment:
        source = source.resolve()
        if source.suffix.lower() != ".pxp":
            raise ValueError("Igor の保存済み .pxp ファイルを選んでください。")
        with source.open("rb") as stream:
            _, filesystem = packed.load(stream, ignore_unknown=True)
        waves = dict(numeric_waves(filesystem["root"]))
        by_name = {
            (*parts[:-1], parts[-1].casefold()): parts for parts in waves
        }
        measurements = []
        rejected = 0
        for parts, intensities in waves.items():
            match = AUTO_NAME.fullmatch(parts[-1])
            if match is None:
                continue
            stem = match[1].casefold()
            folder = parts[:-1]
            angle_path = by_name.get((*folder, "tt_" + stem))
            if angle_path is None:
                rejected += 1
                continue
            if all((*folder, index + "_" + stem) in by_name for index in "hkl"):
                continue
            try:
                measurements.append(Measurement.from_waves(
                    angle_path, parts, waves[angle_path], intensities, "自動"
                ))
            except ValueError:
                rejected += 1
        return cls(source, waves, measurements, rejected)

    def add_pair(self, angle_path, intensity_path) -> Measurement:
        for row in self.measurements:
            if (row.angle_path, row.intensity_path) == (angle_path, intensity_path):
                return row
        row = Measurement.from_waves(
            angle_path, intensity_path, self.waves[angle_path], self.waves[intensity_path], "手動"
        )
        self.measurements.append(row)
        return row

    def approve(self, row: Measurement, number: str, condition: str):
        number, condition = number.strip(), condition.strip()
        if not NUMBER.fullmatch(number):
            raise ValueError("試料番号は数字16桁以内で入力してください。先頭の 0 も保存します。")
        if len(condition) > 80 or any(ord(char) < 32 for char in condition):
            raise ValueError("焼成条件は80文字以内で入力してください。")
        if any(
            other is not row and other.status == "確認済み"
            and other.intensity_path == row.intensity_path
            for other in self.measurements
        ):
            raise ValueError("同じ強度 Wave を使う別の行が確認済みです。先にその行を除外してください。")
        row.number, row.condition, row.status = number, condition, "確認済み"
        row.note = ""


def numeric_waves(tree, folder=()):
    for name, node in tree.items():
        parts = (*folder, decode_name(name))
        if isinstance(node, dict):
            yield from numeric_waves(node, parts)
        elif isinstance(node, WaveRecord):
            wave = node.wave["wave"]["wData"]
            if wave.ndim == 1 and wave.size >= 3 and wave.dtype.kind in "fiu":
                yield parts, wave


def order_key(row: Measurement):
    return (
        not row.number, int(row.number) if row.number else 0, row.number,
        not row.condition, row.condition.casefold(), wave_path(row.intensity_path),
    )


def safe_name(label: str, limit: int = 48) -> str:
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", label)[:limit].rstrip(" .")
    if not name or name in (".", ".."):
        return "_"
    if re.fullmatch(r"CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³]", name.split(".", 1)[0], re.I):
        return "_" + name
    return name


def export_reviewed(experiment: Experiment, parent: Path) -> tuple[Path, int]:
    reviewed = sorted(
        (row for row in experiment.measurements if row.status == "確認済み"), key=order_key
    )
    if not reviewed:
        raise ValueError("書き出す測定を確認済みにしてください。")
    root_name = safe_name(experiment.source.stem, 28) + "_XRD確認済み"
    with TemporaryDirectory(prefix=".xrd-review-", dir=parent) as temp:
        staging = Path(temp) / "measurements"
        staging.mkdir()
        folders: dict[tuple[str, str], str] = {}
        used_folders: set[tuple[str, str]] = set()
        with (staging / "review_manifest.csv").open("w", encoding="utf-8-sig", newline="") as stream:
            manifest = csv.writer(stream)
            manifest.writerow(["元PXP", "試料番号", "焼成条件・工程", "2θ Wave", "強度 Wave", "点数", "出力ファイル"])
            for row in reviewed:
                key = row.number, row.condition
                if key not in folders:
                    base = safe_name(row.condition or UNWRITTEN)
                    name = base
                    counter = 2
                    while (row.number, name.casefold()) in used_folders:
                        name = f"{base}_{counter}"
                        counter += 1
                    folders[key] = name
                    used_folders.add((row.number, name.casefold()))
                condition_folder = folders[key]
                directory = staging / row.number / condition_folder
                directory.mkdir(parents=True, exist_ok=True)
                stem = safe_name(row.number + "_" + condition_folder, 60)
                target = directory / f"{stem}.txt"
                index = 2
                while target.exists():
                    target = directory / f"{stem}_{index}.txt"
                    index += 1
                with target.open("x", encoding="ascii", newline="") as output:
                    np.savetxt(output, np.column_stack((row.angles, row.intensities)), fmt="%.17g", delimiter="\t")
                manifest.writerow([
                    experiment.source.name, row.number, row.condition, wave_path(row.angle_path),
                    wave_path(row.intensity_path), len(row.angles), target.relative_to(staging).as_posix(),
                ])
        target = parent / root_name
        suffix = 2
        while target.exists():
            target = parent / f"{root_name}_{suffix}"
            suffix += 1
        staging.rename(target)
    return target, len(reviewed)
