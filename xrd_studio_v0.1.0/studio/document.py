"""Common, executable-code-free document format for independent analysis modules."""
from __future__ import annotations

import copy
import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
import uuid
import zipfile

import numpy as np

from . import VERSION

SCHEMA = 1
FORMAT = "laboratory-studio"


def uid():
    return uuid.uuid4().hex


def new_state():
    project_id = uid()
    return {"id": uid(), "module": "xrd", "projects": {
        project_id: {"id": project_id, "name": "新しいプロジェクト", "sample_ids": [], "compare_ids": []}},
        "active_project": project_id, "samples": {}, "references": {},
        "plot": {"width_cm": 16.0, "height_cm": 10.0, "font_pt": 12.0,
                 "line_pt": 1.3, "legend_columns": 2, "offset": 120.0,
                 "title": "", "x_min": None, "x_max": None}}


def validate(state):
    if state.get("module") != "xrd":
        raise ValueError("このアプリはXRD文書を開きます。")
    projects, samples, refs = (state[k] for k in ("projects", "samples", "references"))
    if state["active_project"] not in projects:
        raise ValueError("選択中のプロジェクトが見つかりません。")
    seen_samples = set()
    for pid, project in projects.items():
        if pid != project["id"] or len(project["sample_ids"]) != len(set(project["sample_ids"])):
            raise ValueError("プロジェクトIDまたは試料一覧が不正です。")
        for sid in project["sample_ids"]:
            if sid in seen_samples or sid not in samples or samples[sid]["project_id"] != pid:
                raise ValueError("試料とプロジェクトの対応が不正です。")
            seen_samples.add(sid)
        if not set(project["compare_ids"]).issubset(project["sample_ids"]):
            raise ValueError("比較対象の試料が見つかりません。")
    if seen_samples != set(samples):
        raise ValueError("所属のない試料が含まれています。")
    for rid, ref in refs.items():
        if ref["id"] != rid or not isinstance(ref["x"], np.ndarray):
            raise ValueError("参照IDまたはデータが不正です。")
        n = len(ref["x"])
        if n < 1 or any(len(ref[k]) != n for k in ("intensity", "h", "k", "l", "d")):
            raise ValueError("参照データの列数が一致しません。")
        if not np.all(np.isfinite(ref["x"])) or not np.all((ref["x"] > 0) & (ref["x"] < 180)):
            raise ValueError("参照の2θが不正です。")
        if not np.all(np.isfinite(ref["intensity"])) or np.any(ref["intensity"] < 0):
            raise ValueError("参照強度が不正です。")
        for key in ("h", "k", "l"):
            values = ref[key][np.isfinite(ref[key])]
            if np.any(values != np.rint(values)):
                raise ValueError("hklは整数または欠損値である必要があります。")
    for sid, sample in samples.items():
        x, y, processed = (sample[k] for k in ("raw_x", "raw_y", "processed_y"))
        if sid != sample["id"] or any(not isinstance(a, np.ndarray) or a.ndim != 1 for a in (x, y, processed)):
            raise ValueError("試料IDまたはデータ形状が不正です。")
        if len(x) < 3 or len(y) != len(x) or len(processed) != len(x):
            raise ValueError("測定データの点数が不正です。")
        if any(not np.all(np.isfinite(a)) for a in (x, y, processed)) or not np.all(np.diff(x) > 0):
            raise ValueError("測定値は有限値、2θは厳密な昇順が必要です。")
        peaks = {p["id"]: p for p in sample["peaks"]}
        if len(peaks) != len(sample["peaks"]):
            raise ValueError("ピークIDが重複しています。")
        for peak in peaks.values():
            index = peak["index"]
            if not isinstance(index, int) or index < 0 or index >= len(x) or not np.isfinite(peak["angle"]):
                raise ValueError("ピーク位置が不正です。")
        for assignment in sample["assignments"]:
            if assignment["peak_id"] not in peaks:
                raise ValueError("同定のピークが見つかりません。")
            rid = assignment["ref_id"]
            if rid is not None and (rid not in refs or not 0 <= assignment["reflection"] < len(refs[rid]["x"])):
                raise ValueError("同定の参照反射が見つかりません。")
            if not np.isfinite(assignment["shift"]):
                raise ValueError("同定のシフト値が不正です。")
    return state


class Document:
    def __init__(self, state=None):
        self.state = new_state() if state is None else validate(state)
        self.undo_stack = []
        self.redo_stack = []
        self.dirty = False

    def change(self, label, operation):
        before = copy.deepcopy(self.state)
        try:
            result = operation(self.state)
            validate(self.state)
        except Exception:
            self.state = before
            raise
        self.undo_stack.append((label, before))
        self.undo_stack = self.undo_stack[-20:]
        self.redo_stack.clear()
        self.dirty = True
        return result

    def undo(self):
        if not self.undo_stack:
            return False
        label, previous = self.undo_stack.pop()
        self.redo_stack.append((label, self.state))
        self.state = previous
        self.dirty = True
        return True

    def redo(self):
        if not self.redo_stack:
            return False
        label, future = self.redo_stack.pop()
        self.undo_stack.append((label, self.state))
        self.state = future
        self.dirty = True
        return True


def save_document(document, filename, mark_saved=True):
    """Deduplicate immutable arrays; replace only after a complete flushed write."""
    filename = Path(filename)
    if filename.suffix.lower() != ".labx":
        raise ValueError("保存先の拡張子は.labxにしてください。")
    validate(document.state)
    arrays = {}

    def encode(value):
        if isinstance(value, np.ndarray):
            buffer = io.BytesIO()
            np.save(buffer, value, allow_pickle=False)
            data = buffer.getvalue()
            digest = hashlib.sha256(data).hexdigest()
            arrays[digest] = data
            return {"$array": digest}
        if isinstance(value, dict):
            return {str(k): encode(v) for k, v in value.items()}
        if isinstance(value, (list, tuple)):
            return [encode(v) for v in value]
        if isinstance(value, np.generic):
            return value.item()
        return value

    payload = {"format": FORMAT, "schema_version": SCHEMA, "app_version": VERSION,
               "state": encode(document.state), "undo": encode(document.undo_stack),
               "redo": encode(document.redo_stack)}
    data = json.dumps(payload, ensure_ascii=False, allow_nan=False).encode("utf-8")
    handle, temporary = tempfile.mkstemp(prefix=".studio-", suffix=".tmp", dir=filename.parent)
    try:
        with os.fdopen(handle, "w+b") as file:
            with zipfile.ZipFile(file, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("document.json", data)
                for digest, array_data in arrays.items():
                    archive.writestr("arrays/" + digest + ".npy", array_data)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, filename)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    if mark_saved:
        document.dirty = False


def load_document(filename):
    with zipfile.ZipFile(filename, "r") as archive:
        if sum(i.file_size for i in archive.infolist()) > 2_000_000_000:
            raise ValueError("文書の展開後サイズが2GBを超えています。")
        payload = json.loads(archive.read("document.json"))
        if payload.get("format") != FORMAT or payload.get("schema_version") != SCHEMA:
            raise ValueError("この保存形式または新しい保存版には対応していません。")
        cache = {}

        def decode(value):
            if isinstance(value, dict):
                if set(value) == {"$array"}:
                    digest = value["$array"]
                    if not isinstance(digest, str) or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
                        raise ValueError("配列の識別子が不正です。")
                    if digest not in cache:
                        data = archive.read("arrays/" + digest + ".npy")
                        if hashlib.sha256(data).hexdigest() != digest:
                            raise ValueError("保存データのハッシュが一致しません。")
                        cache[digest] = np.load(io.BytesIO(data), allow_pickle=False)
                    return cache[digest].copy()
                return {k: decode(v) for k, v in value.items()}
            if isinstance(value, list):
                return [decode(v) for v in value]
            return value

        document = Document(decode(payload["state"]))
        document.undo_stack = decode(payload.get("undo", []))
        document.redo_stack = decode(payload.get("redo", []))
        for _, state in document.undo_stack + document.redo_stack:
            validate(state)
        return document
