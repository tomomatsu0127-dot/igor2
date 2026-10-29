from pathlib import Path
import os
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
    # Poppler and other development tools may put an incompatible icuuc.dll on
    # PATH. Qt uses Windows' ICU API; never bundle a foreign tool's same-name DLL.
    environment=dict(os.environ)
    windows=Path(os.environ.get('WINDIR','C:/Windows'))
    environment['PATH']=os.pathsep.join([str(windows/'System32'),str(windows),
        str(Path(sys.executable).parent),str(Path(sys.base_prefix)),str(Path(sys.base_prefix)/'DLLs')])
    subprocess.run(command+['--clean','run_studio.py'],cwd=ROOT,env=environment,check=True)
    from PyInstaller.archive.readers import CArchiveReader
    archive=CArchiveReader(ROOT/'dist/XRD_Studio_v0.2.0.exe')
    if any(Path(k.replace('\\','/')).name.lower()=='icuuc.dll' for k in archive.toc):
        raise RuntimeError('A foreign ICU DLL was bundled. Qt must use the Windows ICU API.')
