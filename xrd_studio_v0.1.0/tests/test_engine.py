import copy
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

import numpy as np
from studio import analysis, demo, plotting
from studio.document import Document, load_document, save_document, validate, uid
from studio.io import read_measurement, read_reference, make_sample, normalize


class EngineTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.doc = Document()
        demo.populate(self.doc.state)
        self.sample = next(iter(self.doc.state["samples"].values()))
        self.reference = next(iter(self.doc.state["references"].values()))

    def write(self, name, text):
        path = self.directory / name
        path.write_text(text, encoding="utf-8-sig")
        return path

    def detected(self):
        analysis.detect_peaks(self.sample, self.sample["parameters"])
        return self.sample["peaks"]

    def assigned(self):
        for peak in self.detected():
            candidates = analysis.score_candidates(self.sample, self.doc.state["references"], peak["id"], self.sample["parameters"])
            analysis.assign(self.sample, peak["id"], candidates[0])

    def test_import_headers_bom_comments_and_no_raw_mutation(self):
        path = self.write("sample.csv", "2theta,intensity\n# test\n10,15\n\n11,-2\n12,30\n")
        before = path.read_bytes()
        sample = make_sample(path, self.doc.state["active_project"], "015")
        np.testing.assert_array_equal(sample["raw_y"], [15, -2, 30])
        self.assertEqual(sample["serial"], "015")
        self.assertEqual(path.read_bytes(), before)
        self.assertEqual(float(sample["processed_y"].min()), 0)
        self.assertEqual(float(sample["processed_y"].max()), 100)

    def test_reject_malformed_unsorted_nonfinite_and_missing_values(self):
        for text in ("1 2\n2 3\n3 nan", "1 2\n1 3\n3 4", "1 2\n2 3 4\n3 4", "1 2\n2 3\n3 1e999"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                read_measurement(self.write("bad.txt", text))

    def test_constant_normalization(self):
        np.testing.assert_array_equal(normalize(np.ones(5)), np.zeros(5))

    def test_named_reference_columns_missing_hkl_extra_columns(self):
        path = self.write("ref.txt", "# name: テスト相\n# formula: Fe2O3\nl k h I 2theta d extra\n1 0 2 100 30 2.9 1\n- none - 20 40 2.1 1\n")
        ref = read_reference(path)
        self.assertEqual(ref["name"], "テスト相")
        self.assertEqual(ref["h"][0], 2)
        self.assertTrue(np.isnan(ref["h"][1]))
        self.assertEqual(ref["intensity"][0], 100)

    def test_reference_quoted_csv_and_validation(self):
        ref = read_reference(self.write("ref.csv", '"2theta (deg)","I (%)",h,k,l,comment\n30.2,100,1,0,-2,test\n'))
        self.assertEqual(ref["l"][0], -2)
        for text in ("tt I h k l\n30 -1 1 0 0", "tt I h k l\n30 10 .5 0 0", "tt I h k l\n180 10 1 0 0"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                read_reference(self.write("bad_ref.txt", text))

    def test_detection_finds_known_peaks_without_touching_raw(self):
        before = self.sample["raw_y"].copy()
        peaks = self.detected()
        self.assertEqual(len(peaks), 5)
        np.testing.assert_allclose([p["angle"] for p in peaks], self.reference["x"], atol=.011)
        np.testing.assert_array_equal(self.sample["raw_y"], before)
        self.assertEqual(self.sample["detection"]["algorithm"], "scipy-find-peaks-angular-v1")

    def test_detection_keeps_manual_assigned_unknown_and_ids(self):
        peaks = self.detected()
        peak_id = peaks[0]["id"]
        analysis.assign(self.sample, peak_id)
        manual = analysis.add_peak(self.sample, 100, "Manual")
        analysis.detect_peaks(self.sample, self.sample["parameters"])
        self.assertIn(peak_id, [p["id"] for p in self.sample["peaks"]])
        self.assertIn(manual["id"], [p["id"] for p in self.sample["peaks"]])
        self.assertEqual(self.sample["assignments"][0]["ref_id"], None)

    def test_score_assignment_overlap_and_unique_reflection(self):
        peak = self.detected()[0]
        candidate = analysis.score_candidates(self.sample, self.doc.state["references"], peak["id"], self.sample["parameters"])[0]
        self.assertGreater(candidate["total"], 90)
        analysis.assign(self.sample, peak["id"], candidate)
        second = copy.deepcopy(self.reference)
        second["id"] = uid()
        self.doc.state["references"][second["id"]] = second
        analysis.assign(self.sample, peak["id"], dict(candidate, ref_id=second["id"]))
        self.assertEqual(len(self.sample["assignments"]), 2)
        with self.assertRaises(ValueError):
            analysis.assign(self.sample, self.sample["peaks"][1]["id"], candidate)
        validate(self.doc.state)

    def test_shift_and_strong_reflection_warning(self):
        self.detected()
        for peak in self.sample["peaks"]:
            peak["angle"] += .125
        parameters = dict(self.sample["parameters"], shift_enabled=True)
        shift = analysis.reference_shift(self.sample, self.reference, parameters)
        self.assertAlmostEqual(shift, .125, delta=.006)
        strongest = int(np.argmax(self.reference["intensity"]))
        angle = self.reference["x"][strongest] + shift
        self.sample["peaks"] = [p for p in self.sample["peaks"] if abs(p["angle"] - angle) > .1]
        self.assertTrue(analysis.strong_reflection_warnings(self.sample, self.reference, shift, .2))

    def test_gaussian_center_and_refit_do_not_silently_adopt(self):
        peak = self.detected()[0]
        original = peak["angle"]
        center = float(self.reference["x"][0])
        result = analysis.fit_profile(self.sample, peak["id"], center-.4, center+.4)
        self.assertAlmostEqual(result["center"], center, delta=.001)
        self.assertAlmostEqual(result["fwhm"], 2*np.sqrt(np.log(2))*.085, delta=.002)
        self.assertEqual(peak["angle"], original)
        analysis.adopt_profile(self.sample, peak["id"])
        accepted = peak["angle"]
        analysis.fit_profile(self.sample, peak["id"], center-.45, center+.45)
        self.assertEqual(peak["angle"], accepted)
        self.assertEqual(self.sample["profiles"][str(peak["id"])]["accepted_center"], accepted)
        analysis.adopt_profile(self.sample, peak["id"], restore=True)
        self.assertEqual(peak["angle"], original)

    def test_lorentzian_fit_known_parameters(self):
        x = self.sample["raw_x"]
        center, width = 30.123, .07
        self.sample["processed_y"] = 2 + 90/(1 + ((x-center)/width)**2)
        self.sample["peaks"] = []
        peak = analysis.add_peak(self.sample, int(np.argmin(abs(x-center))))
        result = analysis.fit_profile(self.sample, peak["id"], center-.6, center+.6, "Lorentzian")
        self.assertAlmostEqual(result["center"], center, delta=1e-4)
        self.assertAlmostEqual(result["fwhm"], width*2, delta=.003)

    def test_cubic_lattice_known_result_and_stale_history(self):
        self.assigned()
        # Exact Bragg angles isolate the lattice algorithm from detector discretization.
        for peak, angle in zip(self.sample["peaks"], self.reference["x"]):
            peak["angle"] = float(angle)
        result = analysis.fit_lattice(self.sample, self.reference, "Cubic")
        self.assertAlmostEqual(result["a_A"], 5.43, places=8)
        self.assertFalse(result["stale"])
        analysis.clear_assignments(self.sample, self.sample["peaks"][0]["id"])
        self.assertTrue(result["stale"])

    def test_hexagonal_lattice_known_result_missing_hkl_and_rank(self):
        a, c, wavelength = 3.1, 5.2, 1.5406
        hkl = np.array([[1,0,0], [0,0,2], [1,0,1], [1,0,2], [1,1,0], [1,1,2]])
        inverse_d2 = 4*(hkl[:,0]**2 + hkl[:,0]*hkl[:,1] + hkl[:,1]**2)/(3*a*a) + hkl[:,2]**2/(c*c)
        angles = 2*np.rad2deg(np.arcsin(wavelength*np.sqrt(inverse_d2)/2))
        ref = copy.deepcopy(self.reference)
        ref["x"] = angles
        for column, key in enumerate(("h", "k", "l")):
            ref[key] = hkl[:,column].astype(float)
        self.sample["peaks"] = [{"id":i+1, "angle":float(angle), "index":i, "height":100, "origin":"Manual", "reviewed":True} for i, angle in enumerate(angles)]
        self.sample["assignments"] = [{"peak_id":i+1, "ref_id":ref["id"], "reflection":i, "shift":0} for i in range(len(angles))]
        result = analysis.fit_lattice(self.sample, ref, "Hexagonal")
        self.assertAlmostEqual(result["a_A"], a, places=8)
        self.assertAlmostEqual(result["c_A"], c, places=8)
        ref["h"][0] = np.nan
        result = analysis.fit_lattice(self.sample, ref, "Hexagonal")
        self.assertEqual(result["skipped_peak_ids"], [1])
        with self.assertRaises(ValueError):
            analysis.fit_lattice(self.sample, ref, "Hexagonal", excluded_ids=[2,3,4])

    def test_mutation_failure_is_atomic_undo_redo_and_copy_isolation(self):
        self.doc.change("detect", lambda state: analysis.detect_peaks(state["samples"][self.sample["id"]], self.sample["parameters"]))
        self.assertTrue(self.doc.undo())
        self.assertEqual(len(self.doc.state["samples"][self.sample["id"]]["peaks"]), 0)
        self.assertTrue(self.doc.redo())
        pid = uid()
        self.doc.state["projects"][pid] = {"id":pid,"name":"copy","sample_ids":[],"compare_ids":[]}
        sid = analysis.copy_sample(self.doc.state, self.sample["id"], pid, "015")
        self.doc.state["samples"][sid]["raw_y"][0] = 999
        self.assertNotEqual(self.doc.state["samples"][self.sample["id"]]["raw_y"][0], 999)
        before = len(self.doc.state["samples"])
        def fail(state):
            state["samples"].clear()
            raise ValueError("injected")
        with self.assertRaises(ValueError):
            self.doc.change("failure", fail)
        self.assertEqual(len(self.doc.state["samples"]), before)

    def test_full_save_restart_reopen_history_arrays_and_references(self):
        self.doc.change("detect", lambda state: analysis.detect_peaks(state["samples"][self.sample["id"]], self.sample["parameters"]))
        self.assigned()
        peak = self.sample["peaks"][0]
        analysis.fit_profile(self.sample, peak["id"], peak["angle"]-.4, peak["angle"]+.4)
        analysis.fit_lattice(self.sample, self.reference)
        path = self.directory / "saved.labx"
        save_document(self.doc, path)
        reopened = load_document(path)
        actual = reopened.state["samples"][self.sample["id"]]
        np.testing.assert_array_equal(actual["raw_y"], self.sample["raw_y"])
        self.assertEqual(actual["assignments"], self.sample["assignments"])
        self.assertEqual(len(reopened.undo_stack), 1)
        code = "from studio.document import load_document; import sys; d=load_document(sys.argv[1]); assert len(d.state['samples'])==2; assert d.undo(); print('REOPEN_OK')"
        result = subprocess.run([sys.executable, "-c", code, str(path)], capture_output=True, text=True, check=True)
        self.assertIn("REOPEN_OK", result.stdout)

    def test_corruption_and_future_schema_are_rejected(self):
        path = self.directory / "good.labx"
        save_document(self.doc, path)
        with zipfile.ZipFile(path) as archive:
            contents = {name:archive.read(name) for name in archive.namelist()}
        for mode in ("hash", "schema"):
            changed = dict(contents)
            if mode == "schema":
                payload = json.loads(changed["document.json"])
                payload["schema_version"] = 999
                changed["document.json"] = json.dumps(payload).encode()
            else:
                key = next(k for k in changed if k.startswith("arrays/"))
                changed[key] += b"changed"
            broken = self.directory / (mode + ".labx")
            with zipfile.ZipFile(broken, "w") as archive:
                for key, value in changed.items():
                    archive.writestr(key, value)
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                load_document(broken)

    def test_vector_and_raster_export_and_exact_comparison_selection(self):
        state = self.doc.state
        project = state["projects"][state["active_project"]]
        project["compare_ids"] = [self.sample["id"]]
        from matplotlib.figure import Figure
        fig = Figure()
        axis = plotting.draw(fig, state, self.sample["id"], compare=True)
        self.assertEqual(len(axis.lines), 1)
        project["compare_ids"] = []
        axis = plotting.draw(fig, state, self.sample["id"], compare=True)
        self.assertEqual(len(axis.lines), 0)
        for extension in ("svg", "pdf", "png"):
            path = self.directory / ("graph."+extension)
            plotting.export_figure(path, state, self.sample["id"])
            self.assertGreater(path.stat().st_size, 1000)


if __name__ == "__main__":
    unittest.main(verbosity=2)
