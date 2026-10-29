import os
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['XRD_TESTING']='1'
import copy
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch
import numpy as np
from PySide6.QtWidgets import QApplication,QDialog,QDialogButtonBox,QPushButton,QTableView,QComboBox
from PySide6.QtCore import Qt,QTimer
from PySide6.QtTest import QTest
from studio.qt_app import StudioWindow,ArrayModel
from studio import analysis,demo,workspace
from studio.document import Document,save_document

APP=QApplication.instance() or QApplication([])


class QtTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        d=Document();demo.populate(d.state);self.window=StudioWindow(d);self.window.show();APP.processEvents()
    def tearDown(self):
        self.window.document.dirty=False;self.window.close();self.window.deleteLater();APP.processEvents()
    def wait_jobs(self):
        deadline=time.monotonic()+15
        while self.window.jobs and time.monotonic()<deadline:APP.processEvents();QTest.qWait(10)
        self.assertFalse(self.window.jobs);APP.processEvents()
    def test_detector_button_adoption_undo_and_lattice_worker(self):
        w=self.window;raw=w.sample['raw_y'].copy();button=next(b for b in w.findChildren(QPushButton) if b.text()=='この条件でピークを検出')
        QTest.mouseClick(button,Qt.LeftButton);self.wait_jobs();self.assertEqual(w.peaks_table.rowCount(),5);np.testing.assert_array_equal(w.sample['raw_y'],raw)
        w.stages.setCurrentIndex(2);APP.processEvents();self.assertGreater(w.candidates_table.rowCount(),0)
        for row in range(5):w.peaks_table.selectRow(row);APP.processEvents();w.adopt_candidate()
        self.assertEqual(workspace.status(w.sample),'同定完了');w.undo();self.assertEqual(workspace.status(w.sample),'同定中');w.redo();self.assertEqual(workspace.status(w.sample),'同定完了')
        w.stages.setCurrentIndex(3);w.lattice();self.wait_jobs();self.assertEqual(w.history_table.rowCount(),1)
        self.assertAlmostEqual(w.sample['lattice_runs'][0]['a_A'],5.43,delta=.01)
    def test_supplementary_dialogs_preserve_main_geometry(self):
        w=self.window;size=w.size();geometry=w.geometry()
        for i in range(10):
            QTimer.singleShot(10,lambda:QApplication.activeModalWidget().reject())
            w.figure_settings();APP.processEvents();self.assertEqual(w.size(),size);self.assertEqual(w.geometry(),geometry)
        for stage in range(5):w.stages.setCurrentIndex(stage);APP.processEvents();self.assertEqual(w.size(),size)
    def test_array_models_guard_raw_and_undo_working_copy(self):
        w=self.window;rawmodel=w.raw_table.model();idx=rawmodel.index(0,1);self.assertFalse(rawmodel.flags(idx)&Qt.ItemIsEditable);self.assertFalse(rawmodel.setData(idx,999))
        wid=w.change('copy',lambda st:workspace.new_wave(st,w.sample_id));original=w.document.state['waves'][wid]['y'][0]
        model=ArrayModel(w.sample['raw_x'],w.document.state['waves'][wid]['y'],['x','y'],lambda row,value:(w.change('edit',lambda st:workspace.set_wave_value(st,wid,row,value)) or True))
        self.assertTrue(model.setData(model.index(0,1),12.3));self.assertEqual(w.document.state['waves'][wid]['y'][0],12.3);w.undo();self.assertEqual(w.document.state['waves'][wid]['y'][0],original)
    def test_cancel_discards_worker_result(self):
        w=self.window;w.detect();w.cancel_job();self.wait_jobs();self.assertEqual(len(w.sample['peaks']),0)
    def test_save_reopen_figure_and_cross_project_compare_ui(self):
        w=self.window;sid=w.sample_id;pid=w.change('project',lambda st:workspace.new_project(st,'別Project'))
        w.sample_id=sid;w.document.state['projects'][pid]['compare_ids']=[sid]
        plotid=w.change('plot',lambda st:workspace.save_plot(st,'固定図',[sid]));w.plot_id=plotid;w.refresh();w.stages.setCurrentIndex(4);APP.processEvents()
        self.assertEqual(len(w.axis.lines),1)
        path=Path(self.temp.name)/'ui.labx';save_document(w.document,path);w.load_path(str(path));self.assertIn(plotid,w.document.state['plots']);self.assertEqual(w.plots_combo.count(),2)
    def test_minimum_and_wide_layouts_have_available_actions(self):
        w=self.window
        for width,height in [(1366,768),(1920,1080)]:
            w.resize(width,height);APP.processEvents()
            self.assertGreater(w.canvas.width(),350);self.assertGreater(w.canvas.height(),160)
            self.assertTrue(w.conditions_dock.isVisible());self.assertTrue(w.tree_dock.isVisible())
    def test_data_browser_copy_and_edit_with_table_delegate(self):
        w=self.window;raw=w.sample['raw_y'].copy();errors=[]
        def interact():
            dialog=QApplication.activeModalWidget()
            try:
                button=next(b for b in dialog.findChildren(QPushButton) if b.text()=='規格化値を作業コピーへ')
                QTest.mouseClick(button,Qt.LeftButton);APP.processEvents()
                combo=dialog.findChild(QComboBox);wid=combo.currentData();view=dialog.findChild(QTableView)
                index=view.model().index(0,1);view.edit(index);APP.processEvents()
                editor=view.findChild(__import__('PySide6.QtWidgets',fromlist=['QLineEdit']).QLineEdit)
                self.assertIsNotNone(editor);editor.selectAll();QTest.keyClicks(editor,'123.5');QTest.keyClick(editor,Qt.Key_Return);APP.processEvents()
                self.assertEqual(w.document.state['waves'][wid]['y'][0],123.5)
                np.testing.assert_array_equal(w.sample['raw_y'],raw)
            except Exception as e:errors.append(e)
            finally:dialog.accept()
        QTimer.singleShot(30,interact);w.wave_dialog()
        if errors:raise errors[0]


if __name__=='__main__':unittest.main()
