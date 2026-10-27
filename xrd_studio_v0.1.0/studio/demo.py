"""Explicitly artificial, deterministic data. No user measurements included."""
import numpy as np

from .document import uid
from .io import normalize


def populate(state):
    project_id = state["active_project"]
    state["projects"][project_id]["name"] = "人工データ：立方晶の操作練習"
    hkl = np.array([[1,1,1], [2,0,0], [2,2,0], [3,1,1], [2,2,2]])
    a, wavelength = 5.43, 1.5406
    angles = 2*np.rad2deg(np.arcsin(wavelength*np.sqrt((hkl**2).sum(axis=1))/(2*a)))
    strengths = np.array([100., 35, 60, 28, 18])
    rid = uid()
    state["references"][rid] = {"id": rid, "revision": uid(), "card": "SYNTHETIC-CUBIC-001",
        "name": "人工立方晶（実在物質の同定用ではありません）", "formula": "", "phase_class": "人工データ",
        "source": "generated", "source_name": "synthetic", "enabled": True, "scientific_hash": "demo-cubic-v1",
        "x": angles, "intensity": strengths, "h": hkl[:,0].astype(float), "k": hkl[:,1].astype(float),
        "l": hkl[:,2].astype(float), "d": a/np.sqrt((hkl**2).sum(axis=1))}
    for row in range(2):
        x = np.linspace(20, 65, 4501)
        y = np.full_like(x, 10.)
        for angle, strength in zip(angles, strengths):
            y += strength*np.exp(-((x-angle-row*.025)/.085)**2)
        y += np.random.default_rng(2026+row).normal(0,.12,len(x))
        sid = uid()
        state["samples"][sid] = {"id":sid, "project_id":project_id, "serial":f"{row+1:03d}",
            "name":f"人工試料 {row+1}", "composition":"", "source_name":"synthetic", "source_sha256":"generated",
            "raw_x":x, "raw_y":y, "processed_y":normalize(y),
            "units":{"x":"deg", "raw_y":"synthetic intensity", "processed_y":"%"},
            "normalization":"100*(raw-min(raw))/(max(raw)-min(raw)); constant->0",
            "parameters":{"height":2., "prominence":2., "distance_deg":.15,"smooth_deg":.05,
                "tolerance":.2,"radius":.5,"max_shift":.3,"shift_enabled":False,"wavelength_A":wavelength,"zero_deg":0.},
            "peaks":[],"assignments":[],"next_peak_id":1,"detection":{},"profiles":{},"lattice_runs":[],"status":"未解析","notes":"人工データ"}
        state["projects"][project_id]["sample_ids"].append(sid)
        state["projects"][project_id]["compare_ids"].append(sid)
