"""Run the current Qt integration checks; the original Tk UI was replaced."""
from pathlib import Path
import unittest

if __name__=='__main__':
    suite=unittest.defaultTestLoader.discover(str(Path(__file__).parent),pattern='test_qt.py')
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
