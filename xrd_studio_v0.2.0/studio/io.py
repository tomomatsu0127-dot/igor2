"""Strict import of measurements and named-column reflection cards."""
import csv
import hashlib
import re
from pathlib import Path

import numpy as np

from .document import uid

NUMBER = re.compile(r"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$")


def read_text(path):
    data = Path(path).read_bytes()
    for encoding in ("utf-8-sig", "cp932"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            pass
    raise ValueError("UTF-8または日本語Windowsの文字コードで読み込めません。")


def tokens(line):
    if "," in line:
        return [v.strip() for v in next(csv.reader([line]))]
    return re.split(r"[;\s]+", line.strip())


def finite_number(token):
    if not NUMBER.fullmatch(token):
        raise ValueError(f"数値を読めません: {token}")
    value = float(token)
    if not np.isfinite(value):
        raise ValueError("有限の数値が必要です。")
    return value


def read_measurement(path):
    points = []
    for line_no, line in enumerate(read_text(path).splitlines(), 1):
        line = line.strip()
        if not line or line.startswith(("#", "//")):
            continue
        try:
            fields = tokens(line)
            if len(fields) != 2:
                raise ValueError("測定ファイルは2列が必要です。")
            x, y = map(finite_number, fields)
        except ValueError as error:
            if not points and (not re.match(r"^[+\-.0-9]", line) or line.lower().startswith("2theta")):
                continue
            raise ValueError(f"{Path(path).name} {line_no}行目: {error}") from error
        if points and x <= points[-1][0]:
            raise ValueError(f"{line_no}行目: 2θは厳密な昇順が必要です。")
        points.append((x, y))
    if len(points) < 3:
        raise ValueError("3点以上の測定値が必要です。")
    return np.asarray(points, dtype=float).T.copy()


def normalize(y):
    span = float(np.ptp(y))
    return 100.0 * (y - np.min(y)) / span if span > 0 else np.zeros_like(y)


def make_sample(path, project_id, serial, name=None, composition=""):
    x, y = read_measurement(path)
    return {"id": uid(), "project_id": project_id, "serial": str(serial),
            "name": name or Path(path).stem, "composition": composition,
            "source_name": Path(path).name, "source_sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            "raw_x": x, "raw_y": y, "processed_y": normalize(y),
            "units": {"x": "deg", "raw_y": "instrument intensity", "processed_y": "%"},
            "normalization": "100*(raw-min(raw))/(max(raw)-min(raw)); constant->0",
            "parameters": {"height": 2.0, "prominence": 2.0, "distance_deg": 0.15,
                           "smooth_deg": 0.05, "tolerance": 0.2, "radius": 0.5,
                           "max_shift": 0.3, "shift_enabled": False,
                           "wavelength_A": 1.5406, "zero_deg": 0.0},
            "peaks": [], "assignments": [], "next_peak_id": 1,
            "detection": {}, "profiles": {}, "lattice_runs": [], "status": "未解析", "notes": ""}


ALIASES = {"tt": "x", "2theta": "x", "2θ": "x", "two_theta": "x", "twotheta": "x",
           "2-theta": "x", "tth": "x", "i": "intensity", "int": "intensity",
           "intensity": "intensity", "rel_intensity": "intensity", "i_rel": "intensity",
           "h": "h", "k": "k", "l": "l", "d": "d", "d_spacing": "d", "d-spacing": "d"}


def reference_header(line):
    line = re.sub(r"\s*\([^)]*\)", "", line.lower())
    fields = tokens(line)
    mapping = {}
    for index, field in enumerate(fields):
        key = ALIASES.get(field.strip())
        if key:
            if key in mapping:
                raise ValueError("参照ファイルの列名が重複しています。")
            mapping[key] = index
    return len(fields), mapping


def read_reference(path):
    metadata, rows, mapping, count = {}, [], None, 0
    for line_no, line in enumerate(read_text(path).splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        if line.startswith(("#", "!", "//")):
            body = line.lstrip("#!/ ").strip()
            if ":" in body:
                key, value = body.split(":", 1)
                metadata[key.strip().lower()] = value.strip()
            if mapping is None:
                candidate_count, candidate = reference_header(body)
                if {"x", "intensity", "h", "k", "l"}.issubset(candidate):
                    count, mapping = candidate_count, candidate
            continue
        if mapping is None:
            count, mapping = reference_header(line)
            if not {"x", "intensity", "h", "k", "l"}.issubset(mapping):
                raise ValueError(f"{line_no}行目: 2theta、I、h、k、lの列名が必要です。hkl不明は - と記入します。")
            continue
        fields = tokens(line)
        if len(fields) != count:
            raise ValueError(f"{line_no}行目: 参照の列数がヘッダーと一致しません。")
        row = {}
        for key in ("x", "intensity", "h", "k", "l", "d"):
            if key not in mapping:
                row[key] = np.nan
                continue
            token = fields[mapping[key]]
            value = np.nan if key in ("h", "k", "l") and token.lower() in ("-", "none") else finite_number(token)
            if key in ("h", "k", "l") and np.isfinite(value) and value != round(value):
                raise ValueError(f"{line_no}行目: hklは整数が必要です。")
            row[key] = value
        if not 0 < row["x"] < 180 or row["intensity"] < 0 or (np.isfinite(row["d"]) and row["d"] <= 0):
            raise ValueError(f"{line_no}行目: 参照の角度・強度・d値が不正です。")
        rows.append(row)
    if not rows:
        raise ValueError("参照反射がありません。")
    rows.sort(key=lambda r: r["x"])
    reference = {key: np.array([r[key] for r in rows]) for key in rows[0]}
    reference.update({"id": uid(), "revision": uid(), "card": metadata.get("card_number", "FILE:" + Path(path).name),
                      "name": metadata.get("name", Path(path).stem), "formula": metadata.get("formula", ""),
                      "phase_class": metadata.get("phase_class", ""), "source": metadata.get("source", ""),
                      "source_name": Path(path).name, "enabled": True})
    digest = hashlib.sha256()
    for key in ("x", "intensity", "h", "k", "l", "d"):
        digest.update(reference[key].tobytes())
    digest.update(repr(sorted(metadata.items())).encode("utf-8"))
    reference["scientific_hash"] = digest.hexdigest()
    return reference
