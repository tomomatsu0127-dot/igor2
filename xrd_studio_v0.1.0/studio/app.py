"""Desktop entry point. The numerical engine and document model are UI independent."""
from __future__ import annotations

import argparse
import copy
import csv
import json
import os
from pathlib import Path
import sys
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, simpledialog
import traceback

import numpy as np
from matplotlib.figure import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk

from . import VERSION, analysis, demo, plotting
from .document import Document, uid, load_document, save_document
from .io import make_sample, read_reference


class Fold(ttk.Frame):
    def __init__(self, parent, title, opened=True):
        super().__init__(parent)
        self.opened = opened
        self.title = title
        self.button = ttk.Button(self, command=self.toggle, style="Section.TButton")
        self.button.pack(fill="x", pady=(8, 2))
        self.body = ttk.Frame(self, padding=(8, 5))
        if opened:
            self.body.pack(fill="x")
        self.button.configure(text=("▾ " if opened else "▸ ") + title)

    def toggle(self):
        self.opened = not self.opened
        self.button.configure(text=("▾ " if self.opened else "▸ ") + self.title)
        if self.opened:
            self.body.pack(fill="x")
        else:
            self.body.pack_forget()


class App:
    def __init__(self, root, document=None, filename=None):
        self.root, self.doc, self.filename = root, document or Document(), filename
        self.sample_id, self.peak_id, self.candidate = None, None, None
        self.candidates, self.compare, self.profile_view = [], False, False
        self.variables = {}
        self.refreshing = False
        self.autosave_generation = 0
        root.title(f"XRD Studio {VERSION} — 独立版・開発プレビュー")
        # Tk point scaling can exceed the available screen on mixed-DPI desktops.
        # Size the app from this screen and keep every toolbar action reachable.
        root.tk.call("tk", "scaling", min(float(root.tk.call("tk", "scaling")), 1.5))
        width, height = min(1480, root.winfo_screenwidth()-60), min(930, root.winfo_screenheight()-100)
        root.geometry(f"{width}x{height}")
        root.minsize(min(1050, width), min(700, height))
        self.compact = width < 1100
        root.option_add("*Font", ("Yu Gothic UI", 10))
        style = ttk.Style(root)
        style.theme_use("clam")
        style.configure("TFrame", background="#f3f5f7")
        style.configure("TLabel", background="#f3f5f7", foreground="#253746")
        style.configure("TButton", padding=(8, 5), font=("Yu Gothic UI", 10))
        style.configure("Section.TButton", anchor="w", font=("Yu Gothic UI", 10, "bold"))
        style.configure("Treeview", rowheight=27, font=("Yu Gothic UI", 10))
        style.configure("Treeview.Heading", font=("Yu Gothic UI", 10, "bold"))
        style.map("Treeview", background=[("selected", "#d8e8f5")], foreground=[("selected", "#102d46")])
        self.status = tk.StringVar(value="測定ファイルを追加、または人工データで操作を確認できます。")
        self.build()
        root.protocol("WM_DELETE_WINDOW", self.close)
        root.bind("<Control-s>", lambda e: self.safe(self.save))
        root.bind("<Control-o>", lambda e: self.safe(self.open_document))
        root.bind("<Control-z>", lambda e: self.undo())
        root.bind("<Control-y>", lambda e: self.redo())
        root.report_callback_exception = self.callback_error
        self.refresh()
        root.after(300000, self.autosave)

    def safe(self, function):
        try:
            return function()
        except Exception as error:
            self.status.set("操作を完了できませんでした。")
            messagebox.showerror("内容を確認してください", str(error), parent=self.root)
            return None

    def callback_error(self, exc, value, tb):
        self.status.set("操作中にエラーが発生しました。現在の文書は保持しています。")
        messagebox.showerror("操作エラー", str(value), parent=self.root)
        if sys.stderr:
            traceback.print_exception(exc, value, tb)

    def button(self, parent, text, function, **kwargs):
        button = ttk.Button(parent, text=text, command=lambda: self.safe(function))
        button.pack(**(kwargs or {"fill": "x", "pady": 3}))
        return button

    def table(self, parent, columns, widths, height=8):
        frame = ttk.Frame(parent)
        frame.pack(fill="both", expand=True)
        tree = ttk.Treeview(frame, columns=columns, show="headings", height=height, selectmode="browse")
        for key, width in zip(columns, widths):
            tree.heading(key, text=key)
            tree.column(key, width=width, minwidth=45, stretch=True)
        vertical = ttk.Scrollbar(frame, orient="vertical", command=tree.yview)
        horizontal = ttk.Scrollbar(frame, orient="horizontal", command=tree.xview)
        tree.configure(yscrollcommand=vertical.set, xscrollcommand=horizontal.set)
        tree.grid(row=0, column=0, sticky="nsew")
        vertical.grid(row=0, column=1, sticky="ns")
        horizontal.grid(row=1, column=0, sticky="ew")
        frame.rowconfigure(0, weight=1)
        frame.columnconfigure(0, weight=1)
        return tree

    def build(self):
        header = tk.Frame(self.root, background="#183650", height=52)
        header.pack(fill="x")
        tk.Label(header, text="XRD Studio", font=("Segoe UI", 19, "bold"), fg="white", bg="#183650").pack(side="left", padx=20, pady=9)
        tk.Label(header, text=f"v{VERSION}   ｜   独立版・開発プレビュー", fg="#dceaf5", bg="#183650").pack(side="left")
        toolbar = ttk.Frame(self.root, padding=(10, 5))
        toolbar.pack(fill="x")
        for index, (text, function) in enumerate([("新規文書", self.new_document), ("開く…", self.open_document),
                               ("保存", self.save), ("別名保存…", lambda: self.save(True)),
                               ("元に戻す", self.undo), ("やり直す", self.redo),
                               ("図を出力…", self.export_graph), ("結果CSV…", self.export_csv),
                               ("人工データで試す", self.load_demo), ("使い方", self.help)]):
            button = ttk.Button(toolbar, text=text, command=lambda fn=function: self.safe(fn))
            button.grid(row=index//5, column=index%5, sticky="ew", padx=3, pady=2)
            toolbar.columnconfigure(index%5, weight=1)
        if self.compact:
            workspace = ttk.Notebook(self.root)
            workspace.pack(fill="both", expand=True, padx=5, pady=(0, 5))
            center, left, right = (ttk.Frame(workspace) for _ in range(3))
            workspace.add(center, text="解析グラフ")
            workspace.add(left, text="プロジェクト・測定一覧")
            workspace.add(right, text="解析条件")
        else:
            panes = ttk.Panedwindow(self.root, orient="horizontal")
            panes.pack(fill="both", expand=True, padx=10, pady=(0, 5))
            left, center, right = ttk.Frame(panes, width=220), ttk.Frame(panes), ttk.Frame(panes, width=300)
            left.pack_propagate(False)
            right.pack_propagate(False)
            panes.add(left, weight=0)
            panes.add(center, weight=1)
            panes.add(right, weight=0)
            self.root.after(150, lambda: (panes.sashpos(0, 220), panes.sashpos(1, max(620, panes.winfo_width()-290))))
        ttk.Label(left, text="プロジェクト / 測定", font=("Yu Gothic UI", 11, "bold")).pack(anchor="w", pady=7)
        self.project_box = ttk.Combobox(left, state="readonly", width=25)
        self.project_box.pack(fill="x", pady=4)
        self.project_box.bind("<<ComboboxSelected>>", lambda e: self.safe(self.select_project))
        row = ttk.Frame(left)
        row.pack(fill="x")
        self.button(row, "追加", self.add_project, side="left", expand=True, fill="x")
        self.button(row, "名前を変更", self.rename_project, side="left", expand=True, fill="x")
        self.samples = self.table(left, ("比較", "番号 / 表示名", "状態"), (45, 120, 75), 12)
        self.samples.bind("<<TreeviewSelect>>", self.select_sample)
        self.samples.bind("<Button-1>", self.toggle_compare)
        self.button(left, "測定ファイルを追加…", self.import_samples)
        self.button(left, "試料名・番号・組成を編集…", self.edit_sample)
        self.button(left, "他プロジェクトへ複製…", self.copy_sample)
        self.button(left, "チェックした試料を比較", self.show_compare)
        self.button(left, "選択試料の同定へ戻る", self.show_single)
        ttk.Label(left, text="□ / ☑ をクリックして比較対象を選択\n図をダブルクリック：手動ピーク追加\nCtrl+S 保存  /  Ctrl+Z 元に戻す", wraplength=220, foreground="#596a79").pack(fill="x", pady=9)

        vertical = ttk.Panedwindow(center, orient="vertical")
        vertical.pack(fill="both", expand=True)
        graph_frame, tables = ttk.Frame(vertical), ttk.Notebook(vertical)
        vertical.add(graph_frame, weight=3)
        vertical.add(tables, weight=2)
        self.figure = Figure(figsize=(7.4, 4.0), dpi=100)
        self.canvas = FigureCanvasTkAgg(self.figure, master=graph_frame)
        self.navigation = NavigationToolbar2Tk(self.canvas, graph_frame, pack_toolbar=False)
        self.navigation.pack(fill="x")
        self.canvas.get_tk_widget().pack(fill="both", expand=True)
        self.canvas.mpl_connect("button_press_event", self.graph_click)
        identify, library, history = ttk.Frame(tables), ttk.Frame(tables), ttk.Frame(tables)
        tables.add(identify, text="ピーク・同定候補")
        tables.add(library, text="共通参照ライブラリ")
        tables.add(history, text="フィット・格子計算 / 保存履歴")
        if self.compact:
            peak_frame, candidate_frame = identify, ttk.Frame(tables)
            tables.tab(identify, text="登録ピーク")
            tables.insert(1, candidate_frame, text="同定候補")
        else:
            bottom = ttk.Panedwindow(identify, orient="horizontal")
            bottom.pack(fill="both", expand=True)
            peak_frame, candidate_frame = ttk.Frame(bottom), ttk.Frame(bottom)
            bottom.add(peak_frame, weight=1)
            bottom.add(candidate_frame, weight=2)
        ttk.Label(peak_frame, text="登録ピーク（選ぶと候補を検索）").pack(anchor="w", pady=4)
        self.peaks = self.table(peak_frame, ("ID", "2θ / deg", "同定・確認"), (40, 80, 170))
        self.peaks.bind("<<TreeviewSelect>>", self.select_peak)
        row = ttk.Frame(peak_frame)
        row.pack(fill="x")
        for text, function in [("Unknownにする", self.mark_unknown), ("同定を解除", self.clear_assignment), ("ピーク削除", self.remove_peak)]:
            self.button(row, text, function, side="left", expand=True, fill="x")
        ttk.Label(candidate_frame, text="候補は確認して採用。複数相の重なりを登録できます。").pack(anchor="w", pady=4)
        self.candidate_table = self.table(candidate_frame, ("相 / カード", "hkl", "総合", "全体", "Δ2θ", "欠落強反射"), (180, 65, 45, 45, 65, 70))
        self.candidate_table.bind("<<TreeviewSelect>>", self.select_candidate)
        self.button(candidate_frame, "選択した候補を同定に追加", self.adopt_candidate)
        self.refs = self.table(library, ("使用", "相 / 名称", "カード", "組成式", "分類", "反射数"), (45, 230, 130, 110, 100, 70))
        row = ttk.Frame(library)
        row.pack(fill="x")
        self.button(row, "参照ファイルを追加…", self.import_refs, side="left", padx=3)
        self.button(row, "参照フォルダを追加…", lambda: self.import_refs(True), side="left", padx=3)
        self.button(row, "表示名・分類・使用を編集…", self.edit_reference, side="left", padx=3)
        self.info = tk.Text(history, height=10, wrap="word", font=("Yu Gothic UI", 10), bg="white", relief="flat")
        self.info.pack(fill="both", expand=True, padx=8, pady=8)

        scroll = tk.Canvas(right, highlightthickness=0, width=300, background="#f3f5f7")
        bar = ttk.Scrollbar(right, orient="vertical", command=scroll.yview)
        bar.pack(side="right", fill="y")
        scroll.pack(side="left", fill="both", expand=True)
        scroll.configure(yscrollcommand=bar.set)
        options = ttk.Frame(scroll, padding=(5, 0, 7, 10))
        window = scroll.create_window((0, 0), window=options, anchor="nw")
        options.bind("<Configure>", lambda e: scroll.configure(scrollregion=scroll.bbox("all")))
        scroll.bind("<Configure>", lambda e: scroll.itemconfigure(window, width=e.width))
        detect = self.section(options, "1  ピークを検出")
        for key, label, value in [("height", "最低高さ (%)", 2), ("prominence", "最低突出度 (%)", 2),
                                  ("distance_deg", "最小間隔 (deg)", .15), ("smooth_deg", "平滑化幅 (deg)", .05)]:
            self.entry(detect, key, label, value)
        self.button(detect, "この条件でピークを検出", self.detect)
        self.button(detect, "角度を指定して手動追加…", self.manual_peak)
        match = self.section(options, "2  候補を照合")
        for key, label, value in [("tolerance", "一致幅 (deg)", .2), ("radius", "候補範囲 (deg)", .5), ("max_shift", "シフト上限 (deg)", .3)]:
            self.entry(match, key, label, value)
        self.shift_enabled = tk.BooleanVar(value=False)
        ttk.Checkbutton(match, text="カード全体の共通シフトを推定", variable=self.shift_enabled).pack(anchor="w")
        self.entry(match, "filter", "参照名・組成式で絞る", "")
        self.button(match, "条件を保存して候補を検索", self.search)
        self.button(match, "全ピークを確認して同定完了", self.finish)
        profile = self.section(options, "3  局所ピークフィット", False)
        self.model = ttk.Combobox(profile, values=("Gaussian", "Lorentzian"), state="readonly")
        self.model.set("Gaussian")
        self.model.pack(fill="x", pady=3)
        self.entry(profile, "fit_halfwidth", "片側範囲 (deg)", .4)
        self.button(profile, "選択ピークをフィット", self.fit_profile)
        self.button(profile, "フィット中心を採用", self.adopt_profile)
        self.button(profile, "採用前の中心へ戻す", lambda: self.adopt_profile(True))
        lattice = self.section(options, "4  格子定数", False)
        self.crystal = ttk.Combobox(lattice, values=("Cubic", "Hexagonal"), state="readonly")
        self.crystal.set("Cubic")
        self.crystal.pack(fill="x", pady=3)
        self.entry(lattice, "wavelength_A", "測定波長 (Å)", 1.5406)
        self.entry(lattice, "zero_deg", "ゼロ補正 (deg)", 0)
        self.entry(lattice, "exclude_peaks", "除外ピークID (例 1,3)", "")
        self.button(lattice, "参照相を選んで格子定数を計算", self.fit_lattice)
        plot = self.section(options, "5  図の書式・出力", False)
        for key, label, value in [("width_cm", "図全体の幅 (cm)", 16), ("height_cm", "図全体の高さ (cm)", 10),
                                  ("font_pt", "文字サイズ (pt)", 12), ("line_pt", "線幅 (pt)", 1.3),
                                  ("legend_columns", "凡例の列数", 2), ("offset", "比較図の縦ずらし (%)", 120),
                                  ("title", "図のタイトル", ""), ("x_min", "横軸の下限 (空欄=自動)", ""),
                                  ("x_max", "横軸の上限 (空欄=自動)", "")]:
            self.entry(plot, key, label, value)
        self.button(plot, "書式を保存して図に反映", self.apply_plot)
        self.button(plot, "図に注釈を追加…", self.add_annotation)
        self.button(plot, "PNG / SVG / PDFへ出力…", self.export_graph)
        ttk.Label(self.root, textvariable=self.status, padding=(12, 5), anchor="w").pack(fill="x")

    def section(self, parent, title, opened=True):
        fold = Fold(parent, title, opened)
        fold.pack(fill="x")
        return fold.body

    def entry(self, parent, key, label, value):
        frame = ttk.Frame(parent)
        frame.pack(fill="x", pady=2)
        ttk.Label(frame, text=label).pack(anchor="w")
        variable = tk.StringVar(value=str(value))
        self.variables[key] = variable
        ttk.Entry(frame, textvariable=variable, width=23).pack(fill="x", pady=(1, 2))

    def number(self, key):
        value = float(self.variables[key].get())
        if not np.isfinite(value):
            raise ValueError("設定値には有限の数値が必要です。")
        return value

    def current(self):
        if self.sample_id not in self.doc.state["samples"]:
            raise ValueError("先に測定データを選択してください。")
        return self.doc.state["samples"][self.sample_id]

    def selected_peak(self):
        sample = self.current()
        if not any(p["id"] == self.peak_id for p in sample["peaks"]):
            raise ValueError("登録ピークから対象を選択してください。")
        return next(p for p in sample["peaks"] if p["id"] == self.peak_id)

    def mutate(self, label, operation):
        result = self.doc.change(label, operation)
        self.candidate = None
        self.profile_view = False
        self.refresh()
        self.status.set(label + " を完了。変更は保存できます。")
        return result

    def refresh(self):
        state = self.doc.state
        project_id = state["active_project"]
        project = state["projects"][project_id]
        if self.sample_id not in project["sample_ids"]:
            self.sample_id = next(iter(project["sample_ids"]), None)
            self.peak_id = None
        self.project_ids = list(state["projects"])
        self.project_box["values"] = [state["projects"][i]["name"] for i in self.project_ids]
        self.project_box.current(self.project_ids.index(project_id))
        self.refreshing = True
        self.samples.delete(*self.samples.get_children())
        for sid in project["sample_ids"]:
            s = state["samples"][sid]
            self.samples.insert("", "end", iid=sid, values=("☑" if sid in project["compare_ids"] else "□", s["serial"] + "  " + s["name"], s["status"]))
        if self.sample_id:
            self.samples.selection_set(self.sample_id)
        self.peaks.delete(*self.peaks.get_children())
        if self.sample_id:
            sample = state["samples"][self.sample_id]
            for key, value in sample["parameters"].items():
                if key in self.variables:
                    self.variables[key].set(str(value))
            self.shift_enabled.set(sample["parameters"]["shift_enabled"])
            for peak in sample["peaks"]:
                label = plotting.assignment_label(sample, peak["id"], state["references"])
                self.peaks.insert("", "end", iid=str(peak["id"]), values=(peak["id"], f"{peak['angle']:.5f}", ("✓ " if peak["reviewed"] else "○ ") + label))
            if self.peak_id and self.peaks.exists(str(self.peak_id)):
                self.peaks.selection_set(str(self.peak_id))
        for key, value in state["plot"].items():
            if key in self.variables:
                self.variables[key].set("" if value is None else str(value))
        self.refs.delete(*self.refs.get_children())
        for rid, ref in state["references"].items():
            self.refs.insert("", "end", iid=rid, values=("✓" if ref["enabled"] else "—", ref["name"], ref["card"], ref["formula"], ref["phase_class"], len(ref["x"])))
        self.refreshing = False
        self.update_candidates()
        self.update_info()
        self.redraw()
        name = Path(self.filename).name if self.filename else "未保存文書"
        self.root.title(f"{'● ' if self.doc.dirty else ''}{name} — XRD Studio {VERSION}（開発プレビュー）")

    def redraw(self, preserve=False):
        limits = self.axis.get_xlim() if preserve and hasattr(self, "axis") else None
        can_profile = self.profile_view and self.sample_id in self.doc.state["samples"] and str(self.peak_id) in self.current()["profiles"]
        self.axis = plotting.draw(self.figure, self.doc.state, self.sample_id, self.compare,
                                  self.candidate, self.peak_id, can_profile)
        if limits and not can_profile:
            self.axis.set_xlim(limits)
        self.navigation.update()
        self.canvas.draw_idle()

    def select_project(self):
        index = self.project_box.current()
        self.doc.state["active_project"] = self.project_ids[index]
        self.doc.dirty = True
        self.sample_id = self.peak_id = self.candidate = None
        self.compare = self.profile_view = False
        self.refresh()

    def select_sample(self, event=None):
        selected = self.samples.selection()
        if self.refreshing or not selected or selected[0] == self.sample_id:
            return
        self.sample_id = selected[0]
        self.peak_id = self.candidate = None
        self.profile_view = self.compare = False
        self.refresh()

    def toggle_compare(self, event):
        if self.samples.identify_column(event.x) != "#1":
            return
        sid = self.samples.identify_row(event.y)
        if not sid:
            return
        def operation(state):
            ids = state["projects"][state["active_project"]]["compare_ids"]
            ids.remove(sid) if sid in ids else ids.append(sid)
        self.safe(lambda: self.mutate("比較対象の変更", operation))
        return "break"

    def add_project(self):
        name = simpledialog.askstring("プロジェクト", "プロジェクト名", parent=self.root)
        if not name or not name.strip():
            return
        def operation(state):
            pid = uid()
            state["projects"][pid] = {"id": pid, "name": name.strip(), "sample_ids": [], "compare_ids": []}
            state["active_project"] = pid
        self.mutate("プロジェクト追加", operation)

    def rename_project(self):
        project = self.doc.state["projects"][self.doc.state["active_project"]]
        name = simpledialog.askstring("プロジェクト名", "表示名", initialvalue=project["name"], parent=self.root)
        if name and name.strip():
            self.mutate("プロジェクト名変更", lambda state: state["projects"][state["active_project"]].update(name=name.strip()))

    def import_samples(self):
        paths = filedialog.askopenfilenames(parent=self.root, title="2列の測定ファイルを選択", filetypes=[("XRD測定", "*.txt *.csv *.xy *.dat"), ("すべて", "*.*")])
        if not paths:
            return
        pid = self.doc.state["active_project"]
        project = self.doc.state["projects"][pid]
        used = {self.doc.state["samples"][sid]["serial"] for sid in project["sample_ids"]}
        prepared, number = [], 1
        for path in paths:
            while f"{number:03d}" in used:
                number += 1
            serial = f"{number:03d}"
            prepared.append(make_sample(path, pid, serial))
            used.add(serial)
        def operation(state):
            for sample in prepared:
                state["samples"][sample["id"]] = sample
                state["projects"][pid]["sample_ids"].append(sample["id"])
        self.mutate(f"測定{len(prepared)}件を追加", operation)
        self.sample_id = prepared[0]["id"]
        self.refresh()

    def form(self, title, fields):
        dialog = tk.Toplevel(self.root)
        dialog.title(title)
        dialog.transient(self.root)
        dialog.grab_set()
        body = ttk.Frame(dialog, padding=16)
        body.pack(fill="both", expand=True)
        variables = {}
        for key, label, value in fields:
            ttk.Label(body, text=label).pack(anchor="w", pady=(5, 1))
            variables[key] = tk.StringVar(value=str(value))
            ttk.Entry(body, textvariable=variables[key], width=52).pack(fill="x")
        result = {}
        def apply():
            result.update({k: v.get() for k, v in variables.items()})
            dialog.destroy()
        self.button(body, "この内容を反映", apply)
        self.button(body, "キャンセル", dialog.destroy)
        self.root.wait_window(dialog)
        return result or None

    def edit_sample(self):
        sample = self.current()
        values = self.form("試料情報", [("serial", "通し番号（先頭の0を保持）", sample["serial"]),
            ("name", "表示名 / 凡例", sample["name"]), ("composition", "組成", sample["composition"]), ("notes", "メモ", sample["notes"])])
        if not values:
            return
        if not values["serial"].isdigit() or not values["name"].strip():
            raise ValueError("番号は数字、表示名は空欄以外が必要です。")
        if any(s["id"] != self.sample_id and s["project_id"] == sample["project_id"] and s["serial"] == values["serial"] for s in self.doc.state["samples"].values()):
            raise ValueError("同じ通し番号が存在します。")
        self.mutate("試料情報変更", lambda state: state["samples"][self.sample_id].update(values))

    def copy_sample(self):
        self.current()
        choices = [(pid, p["name"]) for pid, p in self.doc.state["projects"].items() if pid != self.doc.state["active_project"]]
        if not choices:
            raise ValueError("先に複製先のプロジェクトを追加してください。")
        text = "\n".join(f"{i+1}: {name}" for i, (_, name) in enumerate(choices))
        index = simpledialog.askinteger("複製先", text + "\n番号を選択", minvalue=1, maxvalue=len(choices), parent=self.root)
        if index is None:
            return
        serial = simpledialog.askstring("通し番号", "複製先で使う通し番号", initialvalue=self.current()["serial"], parent=self.root)
        if serial is None:
            return
        if not serial.isdigit():
            raise ValueError("通し番号は数字で指定してください。")
        self.mutate("試料を独立複製", lambda state: analysis.copy_sample(state, self.sample_id, choices[index-1][0], serial))

    def import_refs(self, folder=False):
        if folder:
            directory = filedialog.askdirectory(parent=self.root, title="参照ファイルのフォルダ")
            if not directory:
                return
            paths = sorted(p for p in Path(directory).iterdir() if p.suffix.lower() in (".txt", ".csv", ".tsv", ".dat"))
        else:
            paths = filedialog.askopenfilenames(parent=self.root, title="列名付きの参照データ", filetypes=[("参照", "*.txt *.csv *.tsv *.dat"), ("すべて", "*.*")])
        prepared, errors = [], []
        hashes = {r["scientific_hash"] for r in self.doc.state["references"].values()}
        for path in paths:
            try:
                ref = read_reference(path)
                if ref["scientific_hash"] not in hashes:
                    prepared.append(ref)
                    hashes.add(ref["scientific_hash"])
            except Exception as error:
                errors.append(f"{Path(path).name}: {error}")
        if prepared:
            self.mutate(f"参照{len(prepared)}件を追加", lambda state: state["references"].update({r["id"]: r for r in prepared}))
        if errors:
            messagebox.showwarning("読めなかった参照", "\n".join(errors), parent=self.root)
        self.status.set(f"参照追加 {len(prepared)}件 / エラー {len(errors)}件 / 同一内容は再利用")

    def edit_reference(self):
        selected = self.refs.selection()
        if not selected:
            raise ValueError("参照ライブラリから対象を選択してください。")
        rid = selected[0]
        ref = self.doc.state["references"][rid]
        values = self.form("参照の表示と使用", [("name", "表示名", ref["name"]), ("phase_class", "分類", ref["phase_class"]),
            ("enabled", "候補で使う：1 / 使わない：0", int(ref["enabled"])), ("color", "図の色（例 #1565a4）", ref.get("color", "#1565a4"))])
        if not values:
            return
        if not values["name"].strip() or values["enabled"] not in ("0", "1"):
            raise ValueError("名前と使用設定を確認してください。")
        from matplotlib.colors import is_color_like
        if not is_color_like(values["color"]):
            raise ValueError("色を認識できません。#1565a4などを指定してください。")
        values["enabled"] = values["enabled"] == "1"
        self.mutate("参照表示設定", lambda state: state["references"][rid].update(values))

    def detect(self):
        self.current()
        params = {k: self.number(k) for k in ("height", "prominence", "distance_deg", "smooth_deg")}
        self.mutate("ピーク検出", lambda state: analysis.detect_peaks(state["samples"][self.sample_id], params))

    def manual_peak(self, angle=None):
        sample = self.current()
        if angle is None:
            angle = simpledialog.askfloat("手動ピーク", "2θ (deg)", minvalue=float(sample["raw_x"][0]), maxvalue=float(sample["raw_x"][-1]), parent=self.root)
        if angle is None:
            return
        index = int(np.argmin(np.abs(sample["raw_x"] - angle)))
        self.mutate("手動ピーク追加", lambda state: analysis.add_peak(state["samples"][self.sample_id], index))

    def graph_click(self, event):
        if event.dblclick and event.inaxes == self.axis and event.xdata is not None and not self.compare and not self.profile_view and not self.navigation.mode:
            self.safe(lambda: self.manual_peak(event.xdata))

    def select_peak(self, event=None):
        selected = self.peaks.selection()
        if self.refreshing or not selected or int(selected[0]) == self.peak_id:
            return
        self.peak_id = int(selected[0])
        self.profile_view = self.compare = False
        self.candidate = None
        self.safe(self.update_candidates)
        self.redraw(True)

    def update_candidates(self):
        self.candidate_table.delete(*self.candidate_table.get_children())
        self.candidates, self.candidate = [], None
        if self.sample_id not in self.doc.state["samples"] or not any(p["id"] == self.peak_id for p in self.current()["peaks"]):
            return
        self.candidates = analysis.score_candidates(self.current(), self.doc.state["references"], self.peak_id,
            self.current()["parameters"], self.variables["filter"].get().strip())
        for index, candidate in enumerate(self.candidates):
            ref = self.doc.state["references"][candidate["ref_id"]]
            self.candidate_table.insert("", "end", iid=str(index), values=(f"{ref['name']} [{ref['card']}]",
                plotting.hkl_label(ref, candidate["reflection"]), f"{candidate['total']:.1f}", f"{candidate['global']:.1f}",
                f"{candidate['residual']:+.4f}", candidate["missing"]))

    def search(self):
        self.selected_peak()
        params = {k: self.number(k) for k in ("tolerance", "radius", "max_shift")}
        params["shift_enabled"] = self.shift_enabled.get()
        trial = dict(self.current()["parameters"], **params)
        analysis.score_candidates(self.current(), self.doc.state["references"], self.peak_id, trial)
        self.mutate("照合条件の保存", lambda state: state["samples"][self.sample_id]["parameters"].update(params))

    def select_candidate(self, event=None):
        selected = self.candidate_table.selection()
        if not selected or int(selected[0]) >= len(self.candidates):
            return
        self.candidate = self.candidates[int(selected[0])]
        self.profile_view = self.compare = False
        self.redraw(True)

    def adopt_candidate(self):
        self.selected_peak()
        if not self.candidate:
            raise ValueError("候補を選択してください。")
        candidate = self.candidate.copy()
        ref = self.doc.state["references"][candidate["ref_id"]]
        missing = analysis.strong_reflection_warnings(self.current(), ref, candidate["shift"], self.current()["parameters"]["tolerance"])
        if missing and not messagebox.askyesno("強い参照反射を確認", "主・第2反射に対応する登録ピークがありません：\n" + ", ".join(f"{v:.3f}°" for v in missing) + "\nそれでもこの候補を採用しますか？", parent=self.root):
            return
        self.mutate("候補を同定に追加", lambda state: analysis.assign(state["samples"][self.sample_id], self.peak_id, candidate))

    def mark_unknown(self):
        self.selected_peak()
        self.mutate("Unknownとして確認", lambda state: analysis.assign(state["samples"][self.sample_id], self.peak_id))

    def clear_assignment(self):
        self.selected_peak()
        self.mutate("同定解除", lambda state: analysis.clear_assignments(state["samples"][self.sample_id], self.peak_id))

    def remove_peak(self):
        self.selected_peak()
        self.mutate("ピーク削除", lambda state: analysis.delete_peak(state["samples"][self.sample_id], self.peak_id))
        self.peak_id = None

    def finish(self):
        sample = self.current()
        if not sample["peaks"] or any(not p["reviewed"] for p in sample["peaks"]):
            raise ValueError("全登録ピークを同定、またはUnknownとして確認してください。")
        self.mutate("同定完了", lambda state: state["samples"][self.sample_id].update(status="同定完了"))

    def fit_profile(self):
        peak, sample = self.selected_peak(), self.current()
        half = self.number("fit_halfwidth")
        if half <= 0:
            raise ValueError("フィット範囲は0より大きくしてください。")
        lo, hi = max(float(sample["raw_x"][0]), peak["angle"]-half), min(float(sample["raw_x"][-1]), peak["angle"]+half)
        self.mutate("局所ピークフィット", lambda state: analysis.fit_profile(state["samples"][self.sample_id], self.peak_id, lo, hi, self.model.get()))
        self.profile_view = True
        self.redraw()
        self.update_info()

    def adopt_profile(self, restore=False):
        self.selected_peak()
        if str(self.peak_id) not in self.current()["profiles"]:
            raise ValueError("先にピークをフィットしてください。")
        self.mutate("中心角度を復元" if restore else "フィット中心を採用",
                    lambda state: analysis.adopt_profile(state["samples"][self.sample_id], self.peak_id, restore))

    def fit_lattice(self):
        sample = self.current()
        ids = list(dict.fromkeys(a["ref_id"] for a in sample["assignments"] if a["ref_id"]))
        if not ids:
            raise ValueError("先にhkl付き参照を使って同定してください。")
        index = 1
        if len(ids) > 1:
            index = simpledialog.askinteger("計算対象の相", "\n".join(f"{i+1}: {self.doc.state['references'][rid]['name']}" for i, rid in enumerate(ids)), minvalue=1, maxvalue=len(ids), parent=self.root)
            if index is None:
                return
        params = {k: self.number(k) for k in ("wavelength_A", "zero_deg")}
        excluded = [int(v.strip()) for v in self.variables["exclude_peaks"].get().split(",") if v.strip()]
        rid = ids[index-1]
        def operation(state):
            target = state["samples"][self.sample_id]
            if any(target["parameters"][k] != v for k, v in params.items()):
                analysis.invalidate_lattice(target)
            target["parameters"].update(params)
            return analysis.fit_lattice(target, state["references"][rid], self.crystal.get(), excluded)
        result = self.mutate("格子定数を計算", operation)
        text = f"a = {result['a_A']:.7f} ± {result['a_sigma_A']:.3g} Å"
        if result["c_A"] is not None:
            text += f"\nc = {result['c_A']:.7f} ± {result['c_sigma_A']:.3g} Å"
        messagebox.showinfo("格子計算結果", text + "\n計算条件・入力・残差は文書に保存します。", parent=self.root)

    def show_compare(self):
        self.compare, self.profile_view, self.candidate = True, False, None
        self.redraw()
        self.status.set("チェックした試料だけを比較しています。")

    def show_single(self):
        self.compare = self.profile_view = False
        self.redraw()

    def apply_plot(self):
        values = {k: self.number(k) for k in ("width_cm", "height_cm", "font_pt", "line_pt", "legend_columns", "offset")}
        for key, low, high in [("width_cm", 5, 60), ("height_cm", 4, 60), ("font_pt", 6, 48), ("line_pt", .1, 10), ("legend_columns", 1, 6), ("offset", 0, 1000)]:
            if not low <= values[key] <= high:
                raise ValueError(f"{key}の設定範囲は{low}〜{high}です。")
        if values["legend_columns"] != int(values["legend_columns"]):
            raise ValueError("凡例の列数は整数が必要です。")
        values["legend_columns"] = int(values["legend_columns"])
        values["title"] = self.variables["title"].get()
        for key in ("x_min", "x_max"):
            values[key] = None if not self.variables[key].get().strip() else self.number(key)
        if values["x_min"] is not None and values["x_max"] is not None and values["x_min"] >= values["x_max"]:
            raise ValueError("横軸の上限は下限より大きくしてください。")
        self.mutate("図の書式設定", lambda state: state["plot"].update(values))

    def add_annotation(self):
        values = self.form("図の注釈", [("text", "文字列", ""), ("x", "横位置 2θ (deg)", 30), ("y", "縦位置 強度 (%)", 90)])
        if not values:
            return
        annotation = {"text": values["text"], "x": float(values["x"]), "y": float(values["y"])}
        if not np.isfinite(annotation["x"] + annotation["y"]):
            raise ValueError("注釈の位置が不正です。")
        self.mutate("図の注釈追加", lambda state: state["plot"].setdefault("annotations", []).append(annotation))

    def update_info(self):
        lines = ["文書：XRD Studio " + VERSION, "保存形式：.labx / schema 1", "自動復旧コピー：5分ごと・3世代（このPCのユーザーフォルダ）", ""]
        if self.sample_id in self.doc.state["samples"]:
            sample = self.current()
            lines += [f"試料：{sample['serial']}  {sample['name']}", f"元ファイル名：{sample['source_name']}",
                      f"点数：{len(sample['raw_x']):,} / 登録ピーク：{len(sample['peaks'])}", "元測定値と規格化強度は別保持。"]
            if sample["detection"]:
                lines.append("検出：" + sample["detection"]["algorithm"])
            for peak_id, result in sample["profiles"].items():
                lines.append(f"ピーク{peak_id}: {result['model']} 中心={result['center']:.6f}° ±{result['center_sigma']:.3g}, FWHM={result['fwhm']:.6f}°, RMSE={result['rmse']:.4g}; 採用={result['accepted_center']}")
            for result in sample["lattice_runs"]:
                lines.append(f"格子 {result['crystal']}: a={result['a_A']:.7f} Å, c={result['c_A']}; λ={result['wavelength_A']} Å, ゼロ={result['zero_deg']}°, 使用={len(result['inputs'])}本" + (" [条件変更後・再計算が必要]" if result["stale"] else ""))
        lines += ["", "Undo履歴（最大20操作・保存後も復元）:"] + [label for label, _ in self.doc.undo_stack]
        self.info.configure(state="normal")
        self.info.delete("1.0", "end")
        self.info.insert("1.0", "\n".join(lines))
        self.info.configure(state="disabled")

    def export_graph(self):
        self.current()
        path = filedialog.asksaveasfilename(parent=self.root, title="図を書き出す（現在の保存済み書式を使用）", defaultextension=".pdf", filetypes=[("PDF", "*.pdf"), ("SVG", "*.svg"), ("PNG 300 dpi", "*.png")])
        if path:
            plotting.export_figure(path, self.doc.state, self.sample_id, self.compare)
            self.status.set("図を書き出しました：" + path)

    def export_csv(self):
        sample = self.current()
        directory = filedialog.askdirectory(parent=self.root, title="CSVの新規出力先")
        if not directory:
            return
        destination = Path(directory) / ("xrd_export_" + uid()[:10])
        destination.mkdir()
        with (destination / "peaks_assignments.csv").open("w", encoding="utf-8-sig", newline="") as file:
            writer = csv.writer(file)
            writer.writerow(["peak_id", "two_theta_deg", "intensity_percent", "origin", "reviewed", "phase", "card", "h", "k", "l", "common_shift_deg"])
            for p in sample["peaks"]:
                assignments = [a for a in sample["assignments"] if a["peak_id"] == p["id"]] or [None]
                for a in assignments:
                    ref = self.doc.state["references"].get(a["ref_id"]) if a else None
                    extras = ([ref["name"], ref["card"]] + [ref[k][a["reflection"]] for k in ("h", "k", "l")] + [a["shift"]]) if ref else ["Unknown" if a else "", "", "", "", "", 0]
                    writer.writerow([p["id"], p["angle"], p["height"], p["origin"], p["reviewed"], *extras])
        np.savetxt(destination / "measurement.csv", np.column_stack([sample["raw_x"], sample["raw_y"], sample["processed_y"]]), delimiter=",", header="two_theta_deg,raw_instrument_intensity,normalized_percent", comments="")
        (destination / "parameters.json").write_text(json.dumps({"parameters": sample["parameters"], "normalization": sample["normalization"], "source_sha256":sample["source_sha256"]}, ensure_ascii=False, indent=2), encoding="utf-8")
        self.status.set("CSVを書き出しました：" + str(destination))

    def save(self, save_as=False):
        filename = self.filename
        if save_as or not filename:
            filename = filedialog.asksaveasfilename(parent=self.root, title="文書を保存", defaultextension=".labx", filetypes=[("Lab Studio文書", "*.labx")])
        if not filename:
            return False
        save_document(self.doc, filename)
        self.filename = filename
        self.refresh()
        self.status.set("保存しました：" + str(filename))
        return True

    def may_discard(self):
        if not self.doc.dirty:
            return True
        response = messagebox.askyesnocancel("文書の保存", "現在の変更を保存しますか？", parent=self.root)
        return self.save() if response else response is False

    def new_document(self):
        if self.may_discard():
            self.doc, self.filename, self.sample_id = Document(), None, None
            self.peak_id = self.candidate = None
            self.compare = self.profile_view = False
            self.refresh()

    def open_document(self):
        filename = filedialog.askopenfilename(parent=self.root, title="独立版の文書を開く", filetypes=[("Lab Studio文書", "*.labx")])
        if not filename:
            return
        document = load_document(filename)
        if self.may_discard():
            self.doc, self.filename, self.sample_id = document, filename, None
            self.peak_id = self.candidate = None
            self.compare = self.profile_view = False
            self.refresh()
            self.status.set("保存済み文書を開きました。")

    def load_demo(self):
        if self.may_discard():
            self.doc = Document()
            self.doc.change("人工データを作成", demo.populate)
            self.filename, self.sample_id, self.peak_id = None, None, None
            self.compare = self.profile_view = False
            self.refresh()
            self.status.set("人工データです。実在物質の解析結果ではありません。まずピーク検出を押してください。")

    def undo(self):
        if self.doc.undo():
            self.candidate = None
            self.profile_view = False
            self.refresh()

    def redo(self):
        if self.doc.redo():
            self.candidate = None
            self.profile_view = False
            self.refresh()

    def autosave(self):
        try:
            if self.doc.dirty:
                directory = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "LabStudio" / "Recovery"
                directory.mkdir(parents=True, exist_ok=True)
                self.autosave_generation = (self.autosave_generation % 3) + 1
                path = directory / f"{self.doc.state['id']}_{self.autosave_generation}.labx"
                save_document(self.doc, path, mark_saved=False)
                self.status.set("復旧コピーを保存しました。通常保存も行ってください。")
        except Exception as error:
            self.status.set("復旧コピーを保存できません：" + str(error))
        finally:
            self.root.after(300000, self.autosave)

    def close(self):
        if self.safe(self.may_discard):
            self.root.destroy()

    def help(self):
        messagebox.showinfo("はじめに", "1. 測定ファイルを追加（2θ・強度の2列）\n2. 共通参照ライブラリで列名付き参照を追加\n3. 条件を設定しピーク検出\n4. 登録ピーク→候補→同定に追加。Unknownも可\n5. 全ピーク確認後、同定完了\n6. 局所フィット・格子定数・比較図を作成\n7. .labxで保存。元測定値・参照・条件・図設定・履歴を含みます。\n\n拡大：図上部のPan/Zoom。手動ピーク：図をダブルクリック。\n既存の.pxpとIgorコード実行は対象外です。\n本版は開発プレビュー。実測・全機能の等価性は未確認です。", parent=self.root)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", nargs="?")
    parser.add_argument("--demo", action="store_true")
    args = parser.parse_args()
    root = tk.Tk()
    document = load_document(args.file) if args.file else Document()
    if args.demo:
        document.change("人工データ", demo.populate)
    App(root, document, args.file)
    root.mainloop()


if __name__ == "__main__":
    main()
