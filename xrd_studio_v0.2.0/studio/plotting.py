"""Print-size-aware graphs shared by preview and vector/raster export."""
import numpy as np
import matplotlib
from matplotlib.figure import Figure
from matplotlib import font_manager
import textwrap

PALETTE = ["#1565a4", "#b33b32", "#3d803b", "#8c55a1", "#b37812", "#248385"]
MARKERS = ["o", "s", "^", "D", "v", "P", "X", "*"]
FONT = next((f for f in ("Yu Gothic", "Meiryo", "MS Gothic", "DejaVu Sans")
             if f in {v.name for v in font_manager.fontManager.ttflist}), "DejaVu Sans")
matplotlib.rcParams.update({"font.family": FONT, "axes.unicode_minus": False,
                           "pdf.fonttype": 42, "ps.fonttype": 42, "svg.fonttype": "none"})


def hkl_label(reference, index):
    values = [reference[k][index] for k in ("h", "k", "l")]
    return "(" + " ".join(str(int(v)) for v in values) + ")" if np.all(np.isfinite(values)) else "hkl不明"


def assignment_label(sample, peak_id, references):
    labels = []
    for a in sample["assignments"]:
        if a["peak_id"] != peak_id:
            continue
        if a["ref_id"] is None:
            labels.append("Unknown")
        else:
            ref = references[a["ref_id"]]
            labels.append(ref["name"] + " " + hkl_label(ref, a["reflection"]))
    return " / ".join(labels) or "未同定"


def draw(figure, state, sample_id=None, compare=False, candidate=None, selected_peak=None, profile=False):
    settings = state["plot"]
    figure.clear()
    if profile:
        ax, residual_ax = figure.subplots(2, 1, sharex=True, gridspec_kw={"height_ratios": [3, 1]})
        sample = state["samples"][sample_id]
        fit = sample["profiles"][str(selected_peak)]
        ax.plot(fit["x"], fit["observed"], "k.", markersize=3, label="Observed")
        ax.plot(fit["x"], fit["fitted"], color="#b33b32", label=fit["model"])
        ax.plot(fit["x"], fit["baseline"], "--", color="#777777", label="Background")
        residual_ax.plot(fit["x"], fit["residual"], color="#1565a4", linewidth=1)
        residual_ax.axhline(0, color="gray", linewidth=.5)
        residual_ax.set(xlabel=r"$2\theta$ (deg)", ylabel="Residual")
        ax.set(ylabel="Intensity (%)", title=f"{fit['model']}  center={fit['center']:.6f}°  FWHM={fit['fwhm']:.5f}°")
        ax.legend(frameon=False)
        figure.tight_layout()
        return ax
    ax = figure.add_subplot(111)
    project = state["projects"][state["active_project"]]
    ids = [sid for sid in project["compare_ids"] if sid in state['samples'] and not state['samples'][sid].get('deleted')] if compare else ([sample_id] if sample_id in state["samples"] else [])
    offset = settings["offset"] if compare else 0
    style_indices = {rid: i for i, rid in enumerate(state['references'])}
    for row, sid in enumerate(ids):
        sample = state["samples"][sid]
        base = row * offset
        ax.plot(sample["raw_x"], sample["processed_y"] + base,
                color=PALETTE[row % len(PALETTE)] if compare else "#20272e",
                linewidth=settings["line_pt"], label=sample["name"])
        for rid in sorted({a["ref_id"] for a in sample["assignments"] if a["ref_id"]}):
            index = style_indices[rid]
            points = [p for p in sample["peaks"] if any(a["peak_id"] == p["id"] and a["ref_id"] == rid for a in sample["assignments"])]
            if points:
                color = state["references"][rid].get("color", PALETTE[index % len(PALETTE)])
                ax.scatter([p["angle"] for p in points], [p["height"] + base + 4 for p in points],
                           s=24, marker=MARKERS[index % len(MARKERS)], edgecolors=color, facecolors="none",
                           label=state["references"][rid]["name"] if not compare or row == 0 else None)
        if not compare and sample["peaks"]:
            ax.scatter([p["angle"] for p in sample["peaks"]], [p["height"] + 2 for p in sample["peaks"]],
                       s=16, marker="|", color="#707070", label="Registered peaks")
            peak = next((p for p in sample["peaks"] if p["id"] == selected_peak), None)
            if peak:
                ax.axvline(peak["angle"], color="#c55b1d", linewidth=.8, linestyle="--")
    if candidate and not compare:
        ref = state["references"][candidate["ref_id"]]
        intensities = 23 * ref["intensity"] / max(float(np.max(ref["intensity"])), 1e-12)
        ax.vlines(ref["x"] + candidate["shift"], -27, -27 + intensities,
                  color="#1565a4", linewidth=1, label=ref["name"] + " [reference]")
    ax.set(xlabel=r"$2\theta$ (deg)", ylabel="Normalized intensity (%)" + (" + offset" if compare else ""), title=settings["title"])
    if settings.get('x_label'):ax.set_xlabel(settings['x_label'])
    if settings.get('y_label'):ax.set_ylabel(settings['y_label'])
    ax.tick_params(direction="in", top=True, right=True, labelsize=settings["font_pt"])
    ax.xaxis.label.set_size(settings["font_pt"])
    ax.yaxis.label.set_size(settings["font_pt"])
    ax.title.set_size(settings["font_pt"])
    if ids:
        ax.set_ylim(-30, max(110, (len(ids)-1)*offset + 115))
        if settings["x_min"] is not None or settings["x_max"] is not None:
            ax.set_xlim(left=settings["x_min"], right=settings["x_max"])
        if settings.get('y_min') is not None or settings.get('y_max') is not None:
            ax.set_ylim(bottom=settings.get('y_min'),top=settings.get('y_max'))
        handles, labels = ax.get_legend_handles_labels()
        unique = dict(zip(labels, handles))
        wrapped = ['\n'.join(textwrap.wrap(label,22,break_long_words=True)) for label in unique]
        ax.legend(unique.values(), wrapped, frameon=False, ncol=settings["legend_columns"],
                  fontsize=settings["font_pt"]*.85, loc="upper right")
    else:
        ax.text(.5, .5, "測定ファイルを追加して解析を開始\nまたは「人工データで試す」", ha="center", va="center",
                transform=ax.transAxes, color="#677687", fontsize=13)
    for annotation in settings.get("annotations", []):
        ax.text(annotation["x"], annotation["y"], annotation["text"], fontsize=settings["font_pt"])
    figure.tight_layout(pad=1.3)
    return ax


def export_figure(filename, state, sample_id=None, compare=False, candidate=None, selected_peak=None, limits=None, dpi=300):
    settings = state["plot"]
    figure = Figure(figsize=(settings["width_cm"]/2.54, settings["height_cm"]/2.54), dpi=150)
    axis=draw(figure, state, sample_id, compare, candidate, selected_peak)
    if limits is not None:
        axis.set_xlim(limits[0]);axis.set_ylim(limits[1])
    figure.savefig(filename, dpi=dpi, facecolor="white")
