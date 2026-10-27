"""Package a reviewed binary, documentation, source and artificial examples only."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

from studio import demo, plotting
from studio.document import Document, save_document
import numpy as np

ROOT = Path(__file__).resolve().parent


def package(destination):
    destination = Path(destination).resolve()
    if destination.exists():
        raise FileExistsError("配布先は未使用のフォルダ名を指定してください。")
    if destination.with_name(destination.name+".zip").exists():
        raise FileExistsError("同名の配布ZIPが既に存在します。")
    binary = ROOT / "dist" / "XRD_Studio_v0.1.0.exe"
    if not binary.is_file():
        raise FileNotFoundError("先にWindows実行ファイルをビルドしてください。")
    destination.mkdir(parents=True)
    shutil.copy2(binary, destination / binary.name)
    for name in ("README_ja.md", "MIGRATION_SCOPE_v0.1.0.md", "TEST_RESULTS_v0.1.0.md", "THIRD_PARTY_NOTICES.txt"):
        shutil.copy2(ROOT / name, destination / name)
    source = destination / "source"
    source.mkdir()
    for name in ("studio", "tests"):
        shutil.copytree(ROOT/name, source/name, ignore=shutil.ignore_patterns("__pycache__"))
    for name in ("run_studio.py", "build_windows.py", "package_release.py", "requirements.txt"):
        shutil.copy2(ROOT/name, source/name)
    samples = destination / "artificial_examples"
    samples.mkdir()
    document = Document()
    demo.populate(document.state)
    save_document(document, samples / "synthetic_cubic.labx")
    for sample in document.state["samples"].values():
        np.savetxt(samples / (sample["serial"]+"_synthetic.csv"), np.column_stack([sample["raw_x"],sample["raw_y"]]),
                   delimiter=",", header="2theta,intensity", comments="", fmt="%.17g")
    reference = next(iter(document.state["references"].values()))
    plotting.export_figure(samples/"synthetic_comparison.png", document.state,
                           next(iter(document.state["samples"])), compare=True)
    with (samples/"synthetic_cubic_reference.txt").open("w", encoding="utf-8") as file:
        file.write("# card_number: SYNTHETIC-CUBIC-001\n# name: 人工立方晶（実在物質の同定用ではありません）\n# phase_class: 人工データ\ntt I h k l d\n")
        for i in range(len(reference["x"])):
            file.write(" ".join(format(reference[key][i], ".17g") for key in ("x","intensity","h","k","l","d"))+"\n")
    files = [{"path":p.relative_to(destination).as_posix(),"bytes":p.stat().st_size,
              "sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(destination.rglob("*")) if p.is_file()]
    (destination/"MANIFEST_v0.1.0.json").write_text(json.dumps({"version":"0.1.0","files":files},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    archive_path = destination.with_name(destination.name+".zip")
    with zipfile.ZipFile(archive_path,"w",zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(destination.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(destination.parent).as_posix())
    with zipfile.ZipFile(archive_path) as archive:
        for info in archive.infolist():
            data = archive.read(info.filename)
            original = destination.parent / info.filename
            if hashlib.sha256(data).hexdigest() != hashlib.sha256(original.read_bytes()).hexdigest():
                raise AssertionError("ZIP content mismatch: " + info.filename)
    digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    archive_path.with_suffix(".zip.sha256").write_text(digest+"  "+archive_path.name+"\n",encoding="ascii")
    print(json.dumps({"archive":str(archive_path),"bytes":archive_path.stat().st_size,"sha256":digest,"files":len(files)+1},indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("destination")
    package(parser.parse_args().destination)
