"""Windows desktop interface for XRD Wave Review."""
from pathlib import Path
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

# The packaged Igor reader is shipped as replaceable Python source.
if getattr(sys, "frozen", False):
    sys.path.insert(0, str(Path(sys._MEIPASS) / "external"))

from wave_review import Experiment, UNWRITTEN, export_reviewed, order_key, wave_path


class ReviewWindow:
    def __init__(self, root):
        self.root = root
        self.experiment = None
        self.dirty = False
        self.number = tk.StringVar()
        self.condition = tk.StringVar()
        self.source_label = tk.StringVar(value="Igor の保存済み .pxp を開いてください。")
        self.count_label = tk.StringVar()
        self.wave_label = tk.StringVar(value="測定を選ぶと、元の Wave と回折曲線を表示します。")
        self.detail_label = tk.StringVar()
        self.output_label = tk.StringVar()

        root.title("XRD Wave 確認ツール v0.2.0")
        root.geometry("1050x740")
        root.minsize(820, 675)
        root.option_add("*Font", ("Segoe UI", 10))
        root.protocol("WM_DELETE_WINDOW", self.close)
        style = ttk.Style(root)
        style.configure("Title.TLabel", font=("Segoe UI", 17, "bold"))
        style.configure("Treeview", rowheight=25)
        style.configure("Treeview.Heading", font=("Segoe UI", 10, "bold"))

        body = ttk.Frame(root, padding=(18, 12, 18, 12))
        body.pack(fill="both", expand=True)
        body.columnconfigure(0, weight=1)
        body.rowconfigure(2, weight=1)
        body.rowconfigure(5, weight=1)
        toolbar = ttk.Frame(body)
        toolbar.grid(row=0, column=0, sticky="ew")
        toolbar.columnconfigure(0, weight=1)
        ttk.Label(toolbar, text="XRD Wave 確認", style="Title.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Button(toolbar, text=".pxp を開く…", command=self.open_experiment).grid(row=0, column=1, padx=4)
        self.manual_button = ttk.Button(toolbar, text="Wave を手動で組む…", command=self.manual)
        self.manual_button.grid(row=0, column=2, padx=4)
        self.export_button = ttk.Button(toolbar, text="確認済みを書き出す…", command=self.export)
        self.export_button.grid(row=0, column=3, padx=(4, 0))

        description = ttk.Frame(body)
        description.grid(row=1, column=0, pady=(8, 5), sticky="ew")
        description.columnconfigure(0, weight=1)
        ttk.Label(description, textvariable=self.source_label).grid(row=0, column=0, sticky="w")
        ttk.Label(description, textvariable=self.count_label).grid(row=0, column=1, sticky="e")

        listing = ttk.Frame(body)
        listing.grid(row=2, column=0, sticky="nsew")
        listing.rowconfigure(0, weight=1)
        listing.columnconfigure(0, weight=1)
        columns = ("number", "condition", "state", "points", "wave")
        self.table = ttk.Treeview(listing, columns=columns, show="headings", selectmode="browse", height=8)
        for name, title, width, stretch in zip(
            columns, ("試料番号", "焼成条件・工程", "確認状態", "点数", "元の強度 Wave"),
            (85, 165, 105, 65, 400), (False, False, False, False, True),
        ):
            self.table.heading(name, text=title)
            self.table.column(name, width=width, stretch=stretch, anchor="w")
        self.table.tag_configure("確認済み", foreground="#116146")
        self.table.tag_configure("除外", foreground="#656e77")
        self.table.bind("<<TreeviewSelect>>", self.selection_changed)
        self.table.grid(row=0, column=0, sticky="nsew")
        scroll = ttk.Scrollbar(listing, orient="vertical", command=self.table.yview)
        scroll.grid(row=0, column=1, sticky="ns")
        self.table.configure(yscrollcommand=scroll.set)
        scroll_x = ttk.Scrollbar(listing, orient="horizontal", command=self.table.xview)
        scroll_x.grid(row=1, column=0, sticky="ew")
        self.table.configure(xscrollcommand=scroll_x.set)

        editor = ttk.Frame(body)
        editor.grid(row=3, column=0, pady=(12, 4), sticky="ew")
        editor.columnconfigure(3, weight=1)
        ttk.Label(editor, text="試料番号").grid(row=0, column=0, padx=(0, 5))
        self.number_input = ttk.Entry(editor, textvariable=self.number, width=12)
        self.number_input.grid(row=0, column=1, padx=(0, 15))
        ttk.Label(editor, text="焼成条件・工程").grid(row=0, column=2, padx=(0, 5))
        self.condition_input = ttk.Entry(editor, textvariable=self.condition)
        self.condition_input.grid(row=0, column=3, sticky="ew", padx=(0, 15))
        self.approve_button = ttk.Button(editor, text="この行を確認済みにする", command=self.approve)
        self.approve_button.grid(row=0, column=4, padx=4)
        self.skip_button = ttk.Button(editor, text="この行を除外", command=self.skip)
        self.skip_button.grid(row=0, column=5)

        ttk.Label(body, textvariable=self.wave_label).grid(row=4, column=0, sticky="w")
        self.graph = tk.Canvas(body, background="white", highlightbackground="#cbd2d9", highlightthickness=1, height=205)
        self.graph.grid(row=5, column=0, pady=(4, 0), sticky="nsew")
        self.graph.bind("<Configure>", self.draw)
        ttk.Label(body, textvariable=self.detail_label).grid(row=6, column=0, pady=(4, 0), sticky="w")
        ttk.Label(body, textvariable=self.output_label).grid(row=7, column=0, sticky="w")
        self.update_buttons()

    def can_leave(self):
        return not self.dirty or messagebox.askyesno(
            "確認内容を破棄", "書き出していない確認内容を破棄しますか？", parent=self.root
        )

    def close(self):
        if self.can_leave():
            self.root.destroy()

    def open_experiment(self):
        filename = filedialog.askopenfilename(
            parent=self.root, title="確認する Igor 実験", filetypes=[("Igor 実験", "*.pxp")]
        )
        if filename and self.can_leave():
            try:
                self.load(Path(filename))
            except Exception as exc:
                messagebox.showerror("実験を読み込めませんでした", str(exc), parent=self.root)

    def load(self, source):
        self.root.configure(cursor="watch")
        self.root.update_idletasks()
        try:
            experiment = Experiment.read(source)
        finally:
            self.root.configure(cursor="")
        self.experiment = experiment
        self.dirty = False
        self.source_label.set(experiment.source.name)
        self.output_label.set("")
        self.refresh()

    def refresh(self, selected_id=None):
        self.table.delete(*self.table.get_children())
        experiment = self.experiment
        ordered = sorted(enumerate(experiment.measurements), key=lambda item: order_key(item[1]))
        approved = 0
        for index, row in ordered:
            approved += row.status == "確認済み"
            self.table.insert("", "end", iid=str(index), values=(
                row.number or "要入力", row.condition or UNWRITTEN, row.status,
                len(row.angles), wave_path(row.intensity_path),
            ), tags=(row.status,))
        self.count_label.set(f"{len(ordered)} 組の候補　確認済み {approved} 組")
        if ordered:
            selected_id = str(ordered[0][0]) if selected_id is None else str(selected_id)
            self.table.selection_set(selected_id)
            self.table.focus(selected_id)
            self.table.see(selected_id)
        self.selection_changed()

    def selected(self):
        selected = self.table.selection()
        if selected and self.experiment:
            return self.experiment.measurements[int(selected[0])]
        return None

    def update_buttons(self):
        experiment = self.experiment
        self.manual_button.configure(state="normal" if experiment and len(experiment.waves) >= 2 else "disabled")
        self.export_button.configure(state="normal" if experiment and any(
            row.status == "確認済み" for row in experiment.measurements
        ) else "disabled")
        state = "normal" if self.selected() is not None else "disabled"
        for control in (self.number_input, self.condition_input, self.approve_button, self.skip_button):
            control.configure(state=state)

    def selection_changed(self, _event=None):
        row = self.selected()
        if row is None:
            self.number.set("")
            self.condition.set("")
            self.wave_label.set("測定が見つからない場合は、2θ と強度の Wave を手動で組んでください。")
            self.detail_label.set("")
        else:
            self.number.set(row.number)
            self.condition.set(row.condition)
            self.wave_label.set(f"2θ Wave　{wave_path(row.angle_path)}")
            self.detail_label.set(row.note or f"Wave の組み合わせ　{row.method}")
        if self.experiment and self.experiment.rejected:
            self.detail_label.set(self.detail_label.get() + f"　／　対応を確認できない名前の Wave {self.experiment.rejected} 本")
        self.update_buttons()
        self.draw()

    def draw(self, _event=None):
        graph = self.graph
        graph.delete("all")
        row = self.selected()
        if row is None or graph.winfo_width() < 160:
            return
        width, height = graph.winfo_width(), graph.winfo_height()
        left, top, right, bottom = 81, 13, width - 16, height - 34
        if bottom <= top:
            return
        angles, intensity = row.angles, row.intensities
        xmin, xmax = float(angles[0]), float(angles[-1])
        ymin, ymax = float(intensity.min()), float(intensity.max())
        if ymax == ymin:
            ymax += max(1.0, abs(ymax) * .01)
        graph.create_rectangle(left, top, right, bottom, outline="#b6c0ca")
        for i in range(6):
            fraction = i / 5
            gx = left + fraction * (right - left)
            gy = bottom - fraction * (bottom - top)
            graph.create_line(gx, top, gx, bottom, fill="#ecf0f3")
            graph.create_line(left, gy, right, gy, fill="#ecf0f3")
            graph.create_text(gx, bottom + 10, text=f"{xmin + fraction * (xmax - xmin):.1f}", fill="#465565")
            graph.create_text(left - 6, gy, text=f"{ymin + fraction * (ymax - ymin):.4g}", anchor="e", fill="#465565")
        graph.create_text((left + right) / 2, height - 9, text="2θ (°)", fill="#273b4e")
        graph.create_text(14, (top + bottom) / 2, text="強度", angle=90, fill="#273b4e")
        step = max(1, len(angles) // max(1, right - left))
        coords = []
        for start in range(0, len(angles), step):
            segment = intensity[start:start + step]
            if step == 1:
                indices = (start,)
            else:
                indices = sorted({start + int(segment.argmin()), start + int(segment.argmax())})
            for index in indices:
                coords.extend((
                    left + (float(angles[index]) - xmin) / (xmax - xmin) * (right - left),
                    bottom - (float(intensity[index]) - ymin) / (ymax - ymin) * (bottom - top),
                ))
        graph.create_line(*coords, fill="#18598a")

    def approve(self):
        row = self.selected()
        if row is None:
            return
        try:
            self.experiment.approve(row, self.number.get(), self.condition.get())
        except ValueError as exc:
            messagebox.showerror("入力を確認", str(exc), parent=self.root)
            return
        self.dirty = True
        self.refresh(self.table.selection()[0])

    def skip(self):
        row = self.selected()
        if row is not None:
            row.status = "除外"
            self.dirty = True
            self.refresh(self.table.selection()[0])

    def manual(self):
        dialog = tk.Toplevel(self.root)
        dialog.title("2θ と強度の Wave を選択")
        dialog.transient(self.root)
        dialog.resizable(True, False)
        dialog.grab_set()
        box = ttk.Frame(dialog, padding=15)
        box.grid(sticky="nsew")
        dialog.columnconfigure(0, weight=1)
        box.columnconfigure(1, weight=1)
        names = {wave_path(parts): parts for parts in sorted(self.experiment.waves)}
        choices = tuple(names)
        ttk.Label(box, text="2θ（度）").grid(row=0, column=0, sticky="w", padx=(0, 8))
        x = ttk.Combobox(box, values=choices, width=60)
        x.grid(row=0, column=1, sticky="ew", pady=4)
        ttk.Label(box, text="強度").grid(row=1, column=0, sticky="w", padx=(0, 8))
        y = ttk.Combobox(box, values=choices, width=60)
        y.grid(row=1, column=1, sticky="ew", pady=4)

        def add():
            try:
                row = self.experiment.add_pair(names[x.get()], names[y.get()])
            except KeyError:
                messagebox.showerror("Wave を選択", "一覧にある 2θ と強度の Wave を選んでください。", parent=dialog)
                return
            except ValueError as exc:
                messagebox.showerror("Wave を確認", str(exc), parent=dialog)
                return
            index = next(index for index, candidate in enumerate(self.experiment.measurements) if candidate is row)
            dialog.destroy()
            self.refresh(index)

        ttk.Button(box, text="この組を一覧に追加", command=add).grid(row=2, column=1, sticky="e", pady=(8, 0))
        x.focus_set()

    def export(self):
        folder = filedialog.askdirectory(parent=self.root, title="仕分けフォルダを作成する場所")
        if not folder:
            return
        try:
            output, count = export_reviewed(self.experiment, Path(folder))
        except (OSError, ValueError) as exc:
            messagebox.showerror("書き出せませんでした", str(exc), parent=self.root)
            return
        self.dirty = False
        self.output_label.set(f"{count} 組を書き出しました　{output}")
        messagebox.showinfo("書き出し完了", f"{count} 組を保存しました。\n{output}", parent=self.root)


def main():
    root = tk.Tk()
    window = ReviewWindow(root)
    if len(sys.argv) == 2:
        try:
            window.load(Path(sys.argv[1]))
        except Exception as exc:
            messagebox.showerror("実験を読み込めませんでした", str(exc), parent=root)
    root.mainloop()


if __name__ == "__main__":
    main()
