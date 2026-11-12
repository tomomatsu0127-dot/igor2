"""Build the Windows 64-bit distribution from an installed Python environment."""
from argparse import ArgumentParser
from importlib.metadata import distribution
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory
from zipfile import ZIP_DEFLATED, ZipFile

import igor2


def copy_licenses(destination: Path):
    destination.mkdir()
    for name in ("igor2", "numpy", "pyinstaller"):
        package = distribution(name)
        for item in package.files or ():
            if ".dist-info" in item.parts[0] and "licenses" in item.parts:
                relative = Path(*item.parts[item.parts.index("licenses") + 1:])
                output = destination / name / relative
                output.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(package.locate_file(item), output)
    for root in (Path(sys.base_prefix), Path(sys.base_prefix) / "tcl"):
        for item in root.rglob("license.terms") if root.name == "tcl" else root.glob("LICENSE.txt"):
            prefix = "Python_" if root.name != "tcl" else item.parent.name + "_"
            shutil.copyfile(item, destination / (prefix + item.name))


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    if args.destination.exists():
        parser.error("Choose a new output filename.")
    source = Path(__file__).resolve().parent
    with TemporaryDirectory(prefix="xrd-build-", dir=args.destination.resolve().parent) as temp:
        work = Path(temp)
        name = "XRD_Wave_Review"
        subprocess.run([
            sys.executable, "-m", "PyInstaller", "--noconfirm", "--windowed", "--onedir",
            "--name", name, "--exclude-module", "igor2", "--noupx",
            "--distpath", str(work / "dist"), "--workpath", str(work / "build"),
            "--specpath", str(work), str(source / "app.py"),
        ], cwd=source, check=True)
        app = work / "dist" / name
        external = app / "_internal" / "external" / "igor2"
        shutil.copytree(Path(igor2.__file__).parent, external, ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copyfile(source / "README_ja.md", app / "README_ja.md")
        copy_licenses(app / "licenses")
        with ZipFile(args.destination, "x", compression=ZIP_DEFLATED, compresslevel=5) as archive:
            for path in sorted(app.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(app.parent))


if __name__ == "__main__":
    main()
