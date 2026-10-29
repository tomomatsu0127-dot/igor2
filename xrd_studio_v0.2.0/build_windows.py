from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parent

if __name__=='__main__':
    command=[sys.executable,'-m','PyInstaller','--noconfirm','--windowed','--onefile',
        '--name','XRD_Studio_v0.2.0','--distpath','dist','--workpath','build','--specpath','build',
        '--hidden-import','matplotlib.backends.backend_pdf','--hidden-import','matplotlib.backends.backend_svg',
        '--hidden-import','matplotlib.backends.backend_agg','--hidden-import','matplotlib.backends.backend_qtagg']
    for module in ['IPython','notebook','pytest','tkinter','_tkinter','PyQt5','PyQt6','PySide2',
        'PySide6.QtWebEngineCore','PySide6.QtWebEngineWidgets','PySide6.QtPdf','PySide6.QtQml','PySide6.QtQuick']:
        command+=['--exclude-module',module]
    subprocess.run(command+['run_studio.py'],cwd=ROOT,check=True)
