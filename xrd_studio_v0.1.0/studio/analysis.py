"""Independent numerical XRD engine; no Igor runtime or procedure execution."""
from datetime import datetime, timezone
import copy

import numpy as np
import scipy
from scipy.optimize import curve_fit
from scipy.signal import find_peaks, savgol_filter

from .document import uid


def timestamp():
    return datetime.now(timezone.utc).isoformat()


def add_peak(sample, index, origin="Manual"):
    if not 0 <= index < len(sample["raw_x"]):
        raise ValueError("ピーク位置が測定範囲外です。")
    if any(p["index"] == index for p in sample["peaks"]):
        return None
    peak = {"id": sample["next_peak_id"], "index": int(index),
            "angle": float(sample["raw_x"][index]), "height": float(sample["processed_y"][index]),
            "origin": origin, "reviewed": False}
    sample["next_peak_id"] += 1
    sample["peaks"].append(peak)
    sample["peaks"].sort(key=lambda p: p["angle"])
    sample["status"] = "同定中"
    invalidate_lattice(sample)
    return peak


def invalidate_lattice(sample):
    for run in sample["lattice_runs"]:
        run["stale"] = True


def detect_peaks(sample, parameters):
    parameters = dict(parameters)
    for key in ("height", "prominence", "distance_deg", "smooth_deg"):
        if not np.isfinite(parameters[key]) or parameters[key] < 0:
            raise ValueError("ピーク検出の設定は0以上の有限値が必要です。")
    if parameters["height"] > 100 or parameters["prominence"] > 100:
        raise ValueError("高さと突出度は0〜100%で指定してください。")
    x, y = sample["raw_x"], sample["processed_y"]
    step = float(np.median(np.diff(x)))
    # Interpolation makes angular windows meaningful for nonuniform measurements.
    grid = np.linspace(x[0], x[-1], len(x))
    signal = np.interp(grid, x, y)
    grid_step = float(grid[1] - grid[0])
    window = min(len(x) if len(x) % 2 else len(x) - 1,
                 max(3, 2 * int(parameters["smooth_deg"] / grid_step / 2) + 1))
    if parameters["smooth_deg"] > 0 and window >= 5:
        signal = savgol_filter(signal, window, min(2, window - 1), mode="interp")
    indices, _ = find_peaks(signal, height=parameters["height"], prominence=parameters["prominence"])
    # Preserve manually entered/reviewed peaks and any peak with an assignment.
    assigned = {a["peak_id"] for a in sample["assignments"]}
    sample["peaks"] = [p for p in sample["peaks"] if p["origin"] != "Auto" or p["reviewed"] or p["id"] in assigned]
    for index in sorted(indices, key=lambda i: -signal[i]):
        original = int(np.argmin(np.abs(x - grid[index])))
        if all(abs(x[original] - p["angle"]) >= parameters["distance_deg"] for p in sample["peaks"]):
            add_peak(sample, original, "Auto")
    sample["parameters"].update(parameters)
    sample["detection"] = {"algorithm": "scipy-find-peaks-angular-v1", "scipy_version": scipy.__version__,
                           "parameters": parameters, "created": timestamp(), "grid_x": grid,
                           "signal": signal, "median_original_step_deg": step,
                           "note": "Savitzky-Golay + height/prominence + strongest-first angular spacing"}
    valid_ids = {str(p["id"]) for p in sample["peaks"]}
    sample["profiles"] = {k: v for k, v in sample["profiles"].items() if k in valid_ids}
    invalidate_lattice(sample)
    sample["status"] = "同定中"
    return len(sample["peaks"])


def delete_peak(sample, peak_id):
    sample["peaks"] = [p for p in sample["peaks"] if p["id"] != peak_id]
    sample["assignments"] = [a for a in sample["assignments"] if a["peak_id"] != peak_id]
    sample["profiles"].pop(str(peak_id), None)
    invalidate_lattice(sample)
    sample["status"] = "同定中"


def _matches(sample, reference, shift, tolerance):
    """Strongest reference first; one measured peak per reflection within a card."""
    peaks, used, result = sample["peaks"], set(), []
    for index in np.argsort(-reference["intensity"], kind="stable"):
        target = reference["x"][index] + shift
        if not sample["raw_x"][0] <= target <= sample["raw_x"][-1]:
            continue
        choices = [(abs(p["angle"] - target), p) for p in peaks if p["id"] not in used and abs(p["angle"] - target) <= tolerance]
        if choices:
            delta, peak = min(choices, key=lambda t: t[0])
            used.add(peak["id"])
            result.append((int(index), peak, float(delta)))
        else:
            result.append((int(index), None, None))
    return result


def reference_shift(sample, reference, parameters):
    if not parameters["shift_enabled"] or not sample["peaks"]:
        return 0.0
    limit, tolerance = parameters["max_shift"], parameters["tolerance"]
    possible = [0.0]
    # Bounded seeds, then median refinement. This is a new, explicitly versioned algorithm.
    for peak in sample["peaks"]:
        possible.extend(float(peak["angle"] - x) for x in reference["x"] if abs(peak["angle"] - x) <= limit)
    if len(possible) > 400:
        possible = np.linspace(-limit, limit, 201).tolist() + [0.0]
    maximum = max(float(np.max(reference["intensity"])), 1e-12)
    best = (-1.0, -float("inf"), 0.0)
    for shift in possible:
        matches = _matches(sample, reference, shift, tolerance)
        deltas = [p["angle"] - reference["x"][i] for i, p, _ in matches if p]
        if deltas:
            shift = float(np.clip(np.median(deltas), -limit, limit))
        score = sum(np.sqrt(reference["intensity"][i] / maximum) * max(0, 1 - delta / tolerance)
                    for i, peak, delta in _matches(sample, reference, shift, tolerance) if peak)
        candidate = (score, -abs(shift), shift)
        if candidate[:2] > best[:2]:
            best = candidate
    return best[2]


def score_candidates(sample, references, peak_id, parameters, element_filter="", enabled_only=True):
    if not 0 < parameters["tolerance"] <= 5 or not 0.01 <= parameters["radius"] <= 5 or not 0 <= parameters["max_shift"] <= 5:
        raise ValueError("一致幅・候補範囲・シフト上限を確認してください。")
    peak = next(p for p in sample["peaks"] if p["id"] == peak_id)
    explained = {a["peak_id"] for a in sample["assignments"] if a["ref_id"] is not None}
    measured_max = max([p["height"] for p in sample["peaks"]] + [1e-12])
    results = []
    for rid, ref in references.items():
        if enabled_only and not ref["enabled"]:
            continue
        if element_filter and element_filter.casefold() not in (ref["name"] + " " + ref["formula"] + " " + ref["phase_class"]).casefold():
            continue
        maximum = max(float(np.max(ref["intensity"])), 1e-12)
        shift = reference_shift(sample, ref, parameters)
        matches = _matches(sample, ref, shift, parameters["tolerance"])
        denom = global_score = new_score = intensity_score = intensity_denom = 0.0
        missing = 0
        for index, observed, delta in matches:
            relative = 100 * ref["intensity"][index] / maximum
            weight = np.sqrt(relative / 100)
            denom += weight
            if observed:
                position = max(0, 1 - delta / parameters["tolerance"])
                global_score += weight * position
                new_score += weight * position * (observed["id"] not in explained)
                intensity_score += weight * max(0, 1 - abs(100 * observed["height"] / measured_max - relative) / 100)
                intensity_denom += weight
            elif relative >= 70:
                missing += 1
        if denom <= 0:
            continue
        global_score *= 100 / denom
        new_score *= 100 / denom
        intensity_score *= 100 / max(intensity_denom, 1e-12)
        for index, angle in enumerate(ref["x"]):
            residual = peak["angle"] - float(angle) - shift
            if abs(residual) > parameters["radius"]:
                continue
            local = 100 * max(0, 1 - abs(residual) / parameters["tolerance"])
            total = np.clip(.30 * local + .60 * global_score + .10 * intensity_score - min(15, 5 * missing), 0, 100)
            results.append({"ref_id": rid, "reflection": index, "shift": shift, "residual": residual,
                            "local": local, "global": global_score, "new": new_score,
                            "intensity": intensity_score, "missing": missing, "total": float(total),
                            "algorithm": "overlap-score-v1"})
    return sorted(results, key=lambda c: -c["total"])


def strong_reflection_warnings(sample, reference, shift, tolerance):
    missing = []
    for index in np.argsort(-reference["intensity"], kind="stable")[:2]:
        position = reference["x"][index] + shift
        if sample["raw_x"][0] <= position <= sample["raw_x"][-1] and not any(abs(p["angle"] - position) <= tolerance for p in sample["peaks"]):
            missing.append(float(position))
    return missing


def assign(sample, peak_id, candidate=None):
    peak = next(p for p in sample["peaks"] if p["id"] == peak_id)
    if candidate is None:
        sample["assignments"] = [a for a in sample["assignments"] if a["peak_id"] != peak_id]
        sample["assignments"].append({"id": uid(), "peak_id": peak_id, "ref_id": None,
                                      "reflection": 0, "shift": 0.0, "mode": "Unknown", "created": timestamp()})
    else:
        rid, reflection = candidate["ref_id"], candidate["reflection"]
        # A reflection belongs to only one measured peak, but a measured peak may overlap phases.
        if any(a["ref_id"] == rid and a["reflection"] == reflection and a["peak_id"] != peak_id for a in sample["assignments"]):
            raise ValueError("この参照反射は別の測定ピークに割り当て済みです。")
        sample["assignments"] = [a for a in sample["assignments"] if not (a["peak_id"] == peak_id and (a["ref_id"] is None or (a["ref_id"] == rid and a["reflection"] == reflection)))]
        sample["assignments"].append({"id": uid(), "peak_id": peak_id, "ref_id": rid, "reflection": reflection,
                                      "shift": float(candidate["shift"]), "mode": "Manual", "created": timestamp()})
    peak["reviewed"] = True
    invalidate_lattice(sample)
    sample["status"] = "同定中"


def clear_assignments(sample, peak_id):
    sample["assignments"] = [a for a in sample["assignments"] if a["peak_id"] != peak_id]
    next(p for p in sample["peaks"] if p["id"] == peak_id)["reviewed"] = False
    invalidate_lattice(sample)
    sample["status"] = "同定中"


def fit_profile(sample, peak_id, lo, hi, model="Gaussian"):
    x, y = sample["raw_x"], sample["processed_y"]
    peak = next(p for p in sample["peaks"] if p["id"] == peak_id)
    if not x[0] <= lo < peak["angle"] < hi <= x[-1]:
        raise ValueError("フィット範囲は測定内で、選択ピークを含めてください。")
    mask = (x >= lo) & (x <= hi)
    fx, observed = x[mask], y[mask]
    if len(fx) < 9:
        raise ValueError("フィット範囲には9点以上が必要です。")
    baseline = np.interp(fx, [fx[0], fx[-1]], [np.mean(observed[:3]), np.mean(observed[-3:])])
    signal = observed - baseline
    if model == "Gaussian":
        def function(x, constant, amplitude, center, width):
            return constant + amplitude * np.exp(-((x - center) / width) ** 2)
        fwhm_factor = 2 * np.sqrt(np.log(2))
    elif model == "Lorentzian":
        def function(x, constant, amplitude, center, width):
            return constant + amplitude / (1 + ((x - center) / width) ** 2)
        fwhm_factor = 2.0
    else:
        raise ValueError("未知のフィットモデルです。")
    coefficients, covariance = curve_fit(function, fx, signal,
        p0=[0, max(float(np.max(signal)), 1e-6), peak["angle"], (hi - lo) / 8],
        bounds=([-np.inf, 0, lo, 1e-9], [np.inf, np.inf, hi, hi - lo]), maxfev=20000)
    sigma = np.sqrt(np.diag(covariance))
    if not np.all(np.isfinite(coefficients)) or not np.all(np.isfinite(sigma)):
        raise ValueError("フィットの不確かさを評価できません。範囲を見直してください。")
    fitted = function(fx, *coefficients) + baseline
    residual = observed - fitted
    previous = sample["profiles"].get(str(peak_id), {})
    result = {"model": model, "algorithm": "scipy-curve-fit-v1", "created": timestamp(),
              "lo": lo, "hi": hi, "center": float(coefficients[2]), "center_sigma": float(sigma[2]),
              "fwhm": float(coefficients[3] * fwhm_factor), "fwhm_sigma": float(sigma[3] * fwhm_factor),
              "coefficients": coefficients, "covariance": covariance,
              "x": fx.copy(), "observed": observed.copy(), "fitted": fitted, "residual": residual,
              "baseline": baseline, "rmse": float(np.sqrt(np.mean(residual ** 2))),
              "original_angle": previous.get("original_angle", peak["angle"]),
              "accepted_center": previous.get("accepted_center"), "accepted_model": previous.get("accepted_model")}
    sample["profiles"][str(peak_id)] = result
    return result


def adopt_profile(sample, peak_id, restore=False):
    profile = sample["profiles"][str(peak_id)]
    peak = next(p for p in sample["peaks"] if p["id"] == peak_id)
    peak["angle"] = profile["original_angle"] if restore else profile["center"]
    profile["accepted_center"] = None if restore else profile["center"]
    profile["accepted_model"] = None if restore else profile["model"]
    sample["peaks"].sort(key=lambda p: p["angle"])
    invalidate_lattice(sample)
    sample["status"] = "同定中"


def fit_lattice(sample, reference, crystal="Cubic", excluded_ids=()):
    wavelength, zero = (sample["parameters"][k] for k in ("wavelength_A", "zero_deg"))
    if not np.isfinite(wavelength) or wavelength <= 0 or not np.isfinite(zero):
        raise ValueError("波長は正の有限値、ゼロ補正は有限値が必要です。")
    peaks = {p["id"]: p for p in sample["peaks"]}
    rows, skipped = [], []
    for a in sample["assignments"]:
        if a["ref_id"] != reference["id"] or a["peak_id"] in excluded_ids:
            continue
        index = a["reflection"]
        hkl = [float(reference[k][index]) for k in ("h", "k", "l")]
        if not np.all(np.isfinite(hkl)) or sum(v * v for v in hkl) == 0:
            skipped.append(a["peak_id"])
            continue
        angle = peaks[a["peak_id"]]["angle"]
        theta = np.deg2rad((angle - zero) / 2)
        if not 0 < theta < np.pi / 2:
            raise ValueError("ゼロ補正後の角度が物理範囲外です。")
        rows.append((a["peak_id"], angle, *hkl, theta))
    minimum = 3 if crystal == "Cubic" else 4
    if len(rows) < minimum:
        raise ValueError(f"hklが既知の反射が{minimum}本以上必要です（除外 {len(skipped)}本）。")
    values = np.asarray(rows)
    h, k, l, theta = values[:, 2:].T
    s, c = np.sin(theta), np.cos(theta)
    if crystal == "Cubic":
        norm = h*h + k*k + l*l
        xx = 8*s*c*c/(wavelength*wavelength*norm)
        yy = 4*s*s/(wavelength*wavelength*norm)
        design = np.column_stack([np.ones(len(rows)), xx])
    elif crystal == "Hexagonal":
        xx = (h*h+h*k+k*k)*wavelength*wavelength/(6*s*c*c)
        yy = s/(2*c*c)
        second = l*l*wavelength*wavelength/(8*s*c*c)
        design = np.column_stack([np.ones(len(rows)), xx, second])
    else:
        raise ValueError("立方晶または六方晶を指定してください。")
    coef, _, rank, _ = np.linalg.lstsq(design, yy, rcond=None)
    if rank != design.shape[1] or np.linalg.cond(design) > 1e12:
        raise ValueError("独立な反射が不足しているか、回帰が不安定です。")
    residual = yy - design @ coef
    covariance = np.linalg.inv(design.T @ design) * np.sum(residual**2)/(len(rows)-len(coef))
    a_index = 0 if crystal == "Cubic" else 1
    if coef[a_index] <= 0 or (crystal == "Hexagonal" and coef[2] <= 0):
        raise ValueError("回帰から正の格子定数が得られません。反射・波長・結晶系を確認してください。")
    result = {"id": uid(), "created": timestamp(), "ref_id": reference["id"], "revision": reference["revision"],
              "crystal": crystal, "algorithm": "transformed-unweighted-lstsq-v1",
              "wavelength_A": wavelength, "zero_deg": zero, "inputs": values[:, :5],
              "coefficients": coef, "covariance": covariance, "fitted": design @ coef,
              "residual": residual, "skipped_peak_ids": skipped, "excluded_peak_ids": list(excluded_ids),
              "a_A": float(1/np.sqrt(coef[a_index])),
              "a_sigma_A": float(.5*np.sqrt(max(covariance[a_index, a_index], 0))/coef[a_index]**1.5),
              "c_A": None, "c_sigma_A": None, "stale": False}
    if crystal == "Hexagonal":
        result["c_A"] = float(1/np.sqrt(coef[2]))
        result["c_sigma_A"] = float(.5*np.sqrt(max(covariance[2, 2], 0))/coef[2]**1.5)
    sample["lattice_runs"].append(result)
    return result


def copy_sample(state, sample_id, project_id, serial):
    if any(state["samples"][sid]["serial"] == serial for sid in state["projects"][project_id]["sample_ids"]):
        raise ValueError("このプロジェクトには同じ通し番号があります。")
    sample = copy.deepcopy(state["samples"][sample_id])
    sample.update(id=uid(), project_id=project_id, serial=serial)
    state["samples"][sample["id"]] = sample
    state["projects"][project_id]["sample_ids"].append(sample["id"])
    return sample["id"]
