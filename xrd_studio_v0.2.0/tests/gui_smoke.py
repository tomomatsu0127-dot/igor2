"""Exercise application callbacks on artificial data in real Tk, without user files."""
import json
import os
from pathlib import Path
import tempfile
import tkinter as tk
from unittest.mock import patch

from studio.app import App
from studio import demo
from studio.document import Document, load_document


def check_layout(wide):
    root = tk.Tk()
    if wide:
        root.winfo_screenwidth = lambda: 1600
        root.winfo_screenheight = lambda: 1100
    document = Document()
    demo.populate(document.state)
    app = App(root, document)
    root.withdraw()
    checks = []
    def check(condition, label):
        if not condition:
            raise AssertionError(label)
        checks.append(label)
    try:
        root.update()
        check(app.compact != wide, "responsive layout")
        app.detect()
        check(len(app.current()["peaks"]) == 5, "detect callback")
        for peak in list(app.current()["peaks"]):
            app.peak_id = peak["id"]
            app.update_candidates()
            app.candidate = app.candidates[0]
            app.adopt_candidate()
        app.finish()
        check(app.current()["status"] == "同定完了", "complete identification")
        app.peak_id = app.current()["peaks"][0]["id"]
        app.fit_profile()
        app.adopt_profile()
        app.fit_lattice()
        check(len(app.current()["lattice_runs"]) == 1, "lattice callback")
        app.apply_plot()
        app.show_compare()
        check(len(app.axis.lines) == 2, "compare callback")
        app.show_single()
        check(sum(line.get_label() == app.current()["name"] for line in app.axis.lines) == 1, "single callback")
        with tempfile.TemporaryDirectory() as directory:
            app.filename = str(Path(directory)/"workflow.labx")
            check(app.save(), "save callback")
            reopened = load_document(app.filename)
            check(len(reopened.state["samples"][app.sample_id]["assignments"]) == 5, "reopen assignments")
            app.doc.dirty = True
            with patch.dict(os.environ, {"LOCALAPPDATA":directory}):
                for _ in range(4):
                    app.autosave()
            copies = list((Path(directory)/"LabStudio"/"Recovery").glob("*.labx"))
            check(len(copies) == 3, "three generation recovery")
            check(app.doc.dirty, "recovery keeps unsaved marker")
        app.undo()
        app.redo()
        root.update()
        check(bool(app.samples.get_children()), "tables remain connected")
        return checks
    finally:
        for identifier in root.tk.call("after", "info"):
            root.after_cancel(identifier)
        root.destroy()


if __name__ == "__main__":
    def fail(*args, **kwargs):
        raise AssertionError(str(args))
    with patch("studio.app.messagebox.showinfo"), patch("studio.app.messagebox.showerror", side_effect=fail):
        result = {"compact":check_layout(False), "wide":check_layout(True)}
    print(json.dumps(result, indent=2))
