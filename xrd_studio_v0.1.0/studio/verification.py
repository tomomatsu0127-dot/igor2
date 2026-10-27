"""A compiled-binary integration check on generated data, with no user files."""
import json
from pathlib import Path
import sys
import tempfile

import numpy as np
import scipy
import matplotlib

from . import VERSION, analysis, demo, plotting
from .document import Document, load_document, save_document


def run_check(output):
    document = Document()
    demo.populate(document.state)
    sample = next(iter(document.state["samples"].values()))
    reference = next(iter(document.state["references"].values()))
    raw = sample["raw_y"].copy()
    analysis.detect_peaks(sample, sample["parameters"])
    if len(sample["peaks"]) != 5:
        raise AssertionError("Expected five synthetic peaks")
    for peak in sample["peaks"]:
        choices = analysis.score_candidates(sample, document.state["references"], peak["id"], sample["parameters"])
        analysis.assign(sample, peak["id"], choices[0])
    peak = sample["peaks"][0]
    fit = analysis.fit_profile(sample, peak["id"], peak["angle"]-.4, peak["angle"]+.4)
    if abs(fit["center"]-reference["x"][0]) > .001:
        raise AssertionError("Gaussian center mismatch")
    lattice = analysis.fit_lattice(sample, reference)
    if abs(lattice["a_A"] - 5.43) > .01:
        raise AssertionError("Cubic lattice mismatch")
    with tempfile.TemporaryDirectory() as directory:
        filename = Path(directory)/"self_check.labx"
        save_document(document, filename)
        reopened = load_document(filename)
        np.testing.assert_array_equal(raw, reopened.state["samples"][sample["id"]]["raw_y"])
        if reopened.state["samples"][sample["id"]]["assignments"] != sample["assignments"]:
            raise AssertionError("Assignments changed after reopen")
        exports = {}
        for extension in ("pdf", "svg", "png"):
            path = Path(directory)/("figure."+extension)
            plotting.export_figure(path, document.state, sample["id"])
            if path.stat().st_size < 1000:
                raise AssertionError("Figure export is empty")
            exports[extension] = path.stat().st_size
    Path(output).write_text(json.dumps({"status":"PASS", "app_version":VERSION,
        "frozen":bool(getattr(sys, "frozen", False)), "python":sys.version.split()[0],
        "numpy":np.__version__, "scipy":scipy.__version__, "matplotlib":matplotlib.__version__,
        "synthetic_peaks":len(sample["peaks"]), "assignments":len(sample["assignments"]),
        "gaussian_center_deg":fit["center"], "cubic_a_A":lattice["a_A"],
        "raw_preserved":True, "reopened_assignments_preserved":True, "export_bytes":exports}, indent=2), encoding="utf-8")
