"""Build with the verified Python environment; never changes global packages."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
if __name__ == "__main__":
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-v"], cwd=ROOT, check=True)
    subprocess.run([sys.executable, "-m", "PyInstaller", "--noconfirm", "--windowed", "--onefile",
                    "--name", "XRD_Studio_v0.1.0", "--distpath", "dist", "--workpath", "build",
                    "--specpath", "build", "--exclude-module", "IPython", "--exclude-module", "notebook",
                    "--hidden-import", "matplotlib.backends.backend_pdf",
                    "--hidden-import", "matplotlib.backends.backend_svg",
                    "--hidden-import", "matplotlib.backends.backend_agg",
                    "--exclude-module", "PyQt5", "--exclude-module", "PyQt6", "--exclude-module", "PySide6",
                    "run_studio.py"], cwd=ROOT, check=True)
