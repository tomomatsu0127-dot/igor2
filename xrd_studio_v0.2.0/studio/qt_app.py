"""Igor-independent desktop, graph, table and XRD workflow."""
from __future__ import annotations
import copy
import csv
import os
from pathlib import Path
import sys
import numpy as np
from PySide6.QtCore import Qt,QTimer,QSettings,QObject,Signal,QRunnable,QThreadPool,QAbstractTableModel,QModelIndex
from PySide6.QtGui import QAction,QKeySequence,QColor,QFont,QFontDatabase
from PySide6.QtWidgets import (QApplication,QMainWindow,QWidget,QVBoxLayout,QHBoxLayout,QFormLayout,
    QDockWidget,QTreeWidget,QTreeWidgetItem,QTabBar,QTabWidget,QTableWidget,QTableWidgetItem,QTableView,
    QHeaderView,QAbstractItemView,QPushButton,QLineEdit,QDoubleSpinBox,QSpinBox,QComboBox,QCheckBox,
    QLabel,QStackedWidget,QSplitter,QFileDialog,QMessageBox,QInputDialog,QDialog,QDialogButtonBox,
    QProgressBar,QMenu,QToolBar)
from matplotlib.figure import Figure
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg,NavigationToolbar2QT
from . import VERSION,analysis,demo,plotting,workspace
from .document import Document,load_document,save_document


class Signals(QObject):
    result=Signal(object)
    error=Signal(str)
    finished=Signal()


class Job(QRunnable):
    def __init__(self,operation):
        super().__init__();self.operation=operation;self.signals=Signals()
    def run(self):
        try:self.signals.result.emit(self.operation())
        except Exception as e:self.signals.error.emit(str(e))
        finally:self.signals.finished.emit()


class ArrayModel(QAbstractTableModel):
    """Lazy array table. Raw values have no edit callback."""
    def __init__(self,x,y,headers,on_edit=None):
        super().__init__();self.x=x;self.y=y;self.headers=headers;self.on_edit=on_edit
    def rowCount(self,parent=QModelIndex()):return 0 if parent.isValid() else len(self.x)
    def columnCount(self,parent=QModelIndex()):return 0 if parent.isValid() else 2
    def headerData(self,n,orientation,role=Qt.DisplayRole):
        if role==Qt.DisplayRole:return self.headers[n] if orientation==Qt.Horizontal else str(n+1)
    def data(self,index,role=Qt.DisplayRole):
        if not index.isValid():return None
        if role in (Qt.DisplayRole,Qt.EditRole):return f'{(self.x if index.column()==0 else self.y)[index.row()]:.12g}'
        if role==Qt.TextAlignmentRole:return Qt.AlignRight|Qt.AlignVCenter
        if role==Qt.BackgroundRole and self.on_edit and index.column()==1:return QColor('#eff8f5')
    def flags(self,index):
        f=super().flags(index)
        return f|Qt.ItemIsEditable if self.on_edit and index.column()==1 else f
    def setData(self,index,value,role=Qt.EditRole):
        if role!=Qt.EditRole or not self.on_edit or index.column()!=1:return False
        try:
            value=float(value)
            if not np.isfinite(value):return False
            success=bool(self.on_edit(index.row(),value))
            if success:self.dataChanged.emit(index,index,[Qt.DisplayRole,Qt.EditRole])
            return success
        except (ValueError,TypeError):return False


def table(headers):
    t=QTableWidget(0,len(headers));t.setHorizontalHeaderLabels(headers)
    t.setSelectionBehavior(QAbstractItemView.SelectRows);t.setSelectionMode(QAbstractItemView.SingleSelection)
    t.setEditTriggers(QAbstractItemView.NoEditTriggers);t.verticalHeader().hide();t.setAlternatingRowColors(True)
    t.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeToContents);t.horizontalHeader().setStretchLastSection(True)
    return t


def fill(t,rows):
    t.blockSignals(True);t.setRowCount(len(rows))
    for i,row in enumerate(rows):
        for j,value in enumerate(row):
            if isinstance(value,(float,np.floating)):value=f'{value:.7g}' if np.isfinite(value) else '-'
            t.setItem(i,j,QTableWidgetItem('' if value is None else str(value)))
    t.blockSignals(False)


class StudioWindow(QMainWindow):
    def __init__(self,document=None):
        super().__init__()
        # The offscreen Windows plugin may have no usable system default font.
        # Register an installed OS font; do not redistribute Windows font files.
        font_path=Path(os.environ.get('WINDIR','C:/Windows'))/'Fonts'/'YuGothR.ttc'
        if font_path.exists():QFontDatabase.addApplicationFont(str(font_path))
        QApplication.instance().setFont(QFont('Yu Gothic',10))
        self.document=document or Document();self.filename=None
        self.sample_id=None;self.peak_id=None;self.candidate=None;self.candidates=[];self.reference_id=None;self.plot_id=None
        self.cursor_x=None;self.epoch=0;self.jobs=set();self.refreshing=False;self.views={}
        self.settings=QSettings('XRDStudio','Desktop');self.resize(1440,900);self.setMinimumSize(960,660)
        self.setObjectName('XRDStudioMain');self.build_actions();self.build_tree();self.build_center();self.build_conditions()
        self.status_label=QLabel();self.statusBar().addWidget(self.status_label,1)
        self.progress=QProgressBar();self.progress.setFixedWidth(100);self.progress.hide();self.statusBar().addPermanentWidget(self.progress)
        self.cancel=QPushButton('計算を取消');self.cancel.clicked.connect(self.cancel_job);self.cancel.hide();self.statusBar().addPermanentWidget(self.cancel)
        self.timer=QTimer(self);self.timer.timeout.connect(self.autosave);self.timer.start(300000)
        if os.environ.get('XRD_TESTING')!='1':
            geometry=self.settings.value('geometry')
            if geometry:self.restoreGeometry(geometry)
        self.refresh();QTimer.singleShot(300,self.offer_recovery)

    def action(self,title,fn,key=None):
        a=QAction(title,self);a.triggered.connect(lambda checked=False:self.guard(fn))
        if key:a.setShortcut(QKeySequence(key))
        return a

    def build_actions(self):
        bar=QToolBar('基本操作');bar.setObjectName('MainToolbar');bar.setMovable(False);self.addToolBar(bar)
        file=self.menuBar().addMenu('ファイル')
        for title,fn,key in [('新規',self.new_document,'Ctrl+N'),('開く',self.open_document,'Ctrl+O'),('保存',self.save,'Ctrl+S'),('別名保存',lambda:self.save(True),'Ctrl+Shift+S')]:
            a=self.action(title,fn,key);file.addAction(a);bar.addAction(a)
        bar.addSeparator();edit=self.menuBar().addMenu('編集')
        self.undo_action=self.action('元に戻す',self.undo,'Ctrl+Z');self.redo_action=self.action('やり直す',self.redo,'Ctrl+Shift+Z')
        for a in (self.undo_action,self.redo_action):edit.addAction(a);bar.addAction(a)
        export=self.menuBar().addMenu('出力')
        for title,fn in [('図を書き出す',self.export_graph),('結果CSV / Excel',self.export_results),('現在の表をCSV',self.export_table)]:
            a=self.action(title,fn);export.addAction(a)
            if title=='図を書き出す':bar.addAction(a)
        self.viewmenu=self.menuBar().addMenu('表示');self.viewmenu.addAction(self.action('データブラウザー',self.wave_dialog,'Ctrl+T'))
        self.viewmenu.addAction(self.action('グラフの書式',self.figure_settings))
        help=self.menuBar().addMenu('ヘルプ');help.addAction(self.action('人工データで試す',self.populate_demo))
        help.addAction(self.action('この版の実装範囲',self.scope));bar.addSeparator();bar.addAction(self.action('人工データで試す',self.populate_demo))

    def button(self,layout,title,fn):
        b=QPushButton(title);b.clicked.connect(lambda checked=False:self.guard(fn));layout.addWidget(b);return b

    def spin(self,value,lo=0,hi=100,dec=3):
        s=QDoubleSpinBox();s.setDecimals(dec);s.setRange(lo,hi);s.setValue(value);return s

    def build_tree(self):
        dock=QDockWidget('プロジェクトと試料',self);dock.setObjectName('SamplesDock')
        w=QWidget();box=QVBoxLayout(w);row=QHBoxLayout();self.button(row,'＋プロジェクト',self.add_project);self.button(row,'＋測定',self.import_measurement);box.addLayout(row)
        label=QLabel('選択＝編集 / チェック＝比較対象');label.setWordWrap(True);box.addWidget(label)
        self.tree=QTreeWidget();self.tree.setHeaderHidden(True);self.tree.setMinimumWidth(210)
        self.tree.currentItemChanged.connect(self.tree_selected);self.tree.itemChanged.connect(self.tree_checked)
        self.tree.setContextMenuPolicy(Qt.CustomContextMenu);self.tree.customContextMenuRequested.connect(self.tree_menu);box.addWidget(self.tree)
        box.addWidget(QLabel('保存した完成図'));self.plots_combo=QComboBox();self.plots_combo.currentIndexChanged.connect(self.select_plot);box.addWidget(self.plots_combo)
        dock.setWidget(w);self.addDockWidget(Qt.LeftDockWidgetArea,dock);self.tree_dock=dock;self.viewmenu.addAction(dock.toggleViewAction())

    def build_center(self):
        w=QWidget();box=QVBoxLayout(w);box.setContentsMargins(7,5,7,5)
        self.stages=QTabBar();self.stages.setExpanding(True)
        for name in ['1 測定ピーク','2 参照候補','3 ピーク同定','4 格子定数','比較・作図']:self.stages.addTab(name)
        self.stages.currentChanged.connect(self.stage_changed);box.addWidget(self.stages)
        self.figure=Figure(figsize=(9,5));self.canvas=FigureCanvasQTAgg(self.figure);self.nav=NavigationToolbar2QT(self.canvas,self);box.addWidget(self.nav)
        split=QSplitter(Qt.Vertical);split.setChildrenCollapsible(False);split.addWidget(self.canvas)
        self.tables=QTabWidget();self.peaks_table=table(['ID','2θ (deg)','強度 (%)','由来','同定 / Unknown'])
        self.candidates_table=table(['相 / カード','hkl','差 (deg)','スコア','局所','全体','不足'])
        self.evidence_table=table(['反射','2θ (deg)','参照強度','測定ID','差 (deg)','照合'])
        self.raw_table=QTableView();self.raw_table.horizontalHeader().setStretchLastSection(True)
        self.history_table=table(['計算日時','結晶系','a (Å)','σa (Å)','c (Å)','σc (Å)','状態'])
        for name,t in [('測定ピーク',self.peaks_table),('同定候補',self.candidates_table),('候補の証拠',self.evidence_table),('元データ',self.raw_table),('格子履歴',self.history_table)]:self.tables.addTab(t,name)
        split.addWidget(self.tables);split.setSizes([520,230]);box.addWidget(split,1);self.setCentralWidget(w)
        self.peaks_table.itemSelectionChanged.connect(self.peak_selected);self.candidates_table.itemSelectionChanged.connect(self.candidate_selected)
        self.candidates_table.cellDoubleClicked.connect(lambda *a:self.guard(self.adopt_candidate))
        self.canvas.mpl_connect('button_press_event',self.graph_click)

    def page(self,title):
        w=QWidget();box=QVBoxLayout(w);t=QLabel(title);t.setWordWrap(True);t.setStyleSheet('font-weight:600;color:#176e7a;padding:4px 0;');box.addWidget(t);return w,box

    def build_conditions(self):
        dock=QDockWidget('解析と図の操作',self);dock.setObjectName('ConditionsDock');dock.setMinimumWidth(270);self.conditions=QStackedWidget()
        w,box=self.page('元データを保ってピークを登録');form=QFormLayout();self.detect_controls={}
        for key,label,value in [('height','高さ (%)',2),('prominence','突出度 (%)',2),('distance_deg','最小間隔 (deg)',.15),('smooth_deg','平滑化幅 (deg)',.05)]:
            self.detect_controls[key]=self.spin(value);form.addRow(label,self.detect_controls[key])
        box.addLayout(form);self.button(box,'この条件でピークを検出',self.detect)
        self.angle=self.spin(30,-360,360,6);form=QFormLayout();form.addRow('追加位置 2θ (deg)',self.angle);box.addLayout(form)
        for label,fn in [('近傍測定点を手動追加',self.add_manual),('カーソル位置を確認して追加',self.add_cursor),('外部ピークリストを追加',self.import_peaks),('選択ピークを削除',self.delete_peak),('原値・作業データ表',self.wave_dialog),('全体表示',self.full_view)]:self.button(box,label,fn)
        self.cursor_label=QLabel('グラフをクリックすると角度を表示');self.cursor_label.setWordWrap(True);box.addWidget(self.cursor_label);box.addStretch();self.conditions.addWidget(w)
        w,box=self.page('参照ライブラリ / チェックしたカードを使用');self.button(box,'参照ファイルを追加',self.import_reference)
        self.reference_table=table(['使用','相名 / カード','分類','組成']);self.reference_table.itemChanged.connect(self.reference_enabled);self.reference_table.itemSelectionChanged.connect(self.reference_selected);box.addWidget(self.reference_table,1)
        self.elements=QLineEdit();self.elements.setPlaceholderText('例: Ba Fe Cu O');box.addWidget(QLabel('許可する元素（空欄は制限なし）'));box.addWidget(self.elements);self.button(box,'元素条件を保存',self.save_reference_settings)
        t=QLabel('type保護相と組成不明の参照は候補に残します。参照値は文書内に保存します。');t.setWordWrap(True);box.addWidget(t);self.conditions.addWidget(w)
        w,box=self.page('候補を比較して1ピークずつ同定');self.mode=QComboBox();self.mode.addItems(['全候補','既に採用した相','新しい相']);self.mode.currentIndexChanged.connect(lambda *_:self.guard(self.save_reference_settings));box.addWidget(self.mode)
        form=QFormLayout();self.tolerance=self.spin(.2,.00001,5,5);form.addRow('一致幅 (deg)',self.tolerance);self.shift=QCheckBox('カード共通シフトを使う');form.addRow(self.shift);box.addLayout(form)
        for label,fn in [('条件を保存して候補を再計算',self.match_parameters),('選択した候補を採用',self.adopt_candidate),('重なりとして追加',lambda:self.adopt_candidate(True)),('Unknownにする',self.unknown),('同定を解除',self.clear_assignment),('局所フィットを開く',self.profile_dialog)]:self.button(box,label,fn)
        self.follow=QCheckBox('選択時に±5°へ拡大');self.follow.setChecked(True);box.addWidget(self.follow)
        self.warning=QLabel('候補スコアは確率・含有率ではありません。');self.warning.setWordWrap(True);box.addWidget(self.warning);self.button(box,'全体表示',self.full_view);box.addStretch();self.conditions.addWidget(w)
        w,box=self.page('採用したhklから格子定数を計算');form=QFormLayout();self.lattice_ref=QComboBox();self.crystal=QComboBox();self.crystal.addItems(['立方晶','六方晶']);self.wavelength=self.spin(1.5406,.00001,20,6);self.zero=self.spin(0,-5,5,6);self.excluded=QLineEdit();self.excluded.setPlaceholderText('例: 2, 5')
        for label,control in [('相',self.lattice_ref),('結晶系',self.crystal),('波長 (Å)',self.wavelength),('ゼロ補正 (deg)',self.zero),('除外ピークID',self.excluded)]:form.addRow(label,control)
        box.addLayout(form);self.button(box,'格子定数を計算して履歴へ保存',self.lattice);self.lattice_label=QLabel('立方晶3本以上 / 六方晶4本以上\nhkl不明は除外');self.lattice_label.setWordWrap(True);box.addWidget(self.lattice_label);self.button(box,'結果CSV / Excel',self.export_results);box.addStretch();self.conditions.addWidget(w)
        w,box=self.page('比較は現在値 / 保存図は数値を固定')
        for label,fn in [('チェックした試料を比較',self.show_comparison),('比較を完成図として保存',self.capture_plot),('軸・線・文字・凡例を編集',self.figure_settings),('注釈を追加',self.add_annotation),('図をPDF / SVG / PNGへ',self.export_graph),('現在のグラフ範囲を保存',self.keep_graph_range),('全体表示',self.full_view)]:self.button(box,label,fn)
        self.plot_label=QLabel('保存図は後の解析変更で自動更新しません。');self.plot_label.setWordWrap(True);box.addWidget(self.plot_label);box.addStretch();self.conditions.addWidget(w)
        dock.setWidget(self.conditions);self.addDockWidget(Qt.RightDockWidgetArea,dock);self.conditions_dock=dock;self.viewmenu.addAction(dock.toggleViewAction())

    @property
    def sample(self):return self.document.state['samples'].get(self.sample_id)

    def guard(self,fn):
        try:return fn()
        except Exception as e:
            self.statusBar().showMessage(str(e),12000)
            if os.environ.get('XRD_TESTING')=='1':raise
            QMessageBox.warning(self,'操作を完了できません',str(e))

    def require_sample(self):
        if not self.sample or self.sample.get('deleted'):raise ValueError('左の一覧で測定試料を選んでください。')
        return self.sample

    def change(self,label,fn,refresh=True):
        result=self.document.change(label,fn);self.epoch+=1
        if refresh:self.refresh()
        return result

    def start_job(self,label,fn,accept):
        if self.jobs:raise ValueError('実行中の計算が終わってから操作してください。')
        epoch=self.epoch;job=Job(fn);self.jobs.add(job);self.progress.setRange(0,0);self.progress.show();self.cancel.show();self.statusBar().showMessage(label+'…')
        def result(value):
            if self.epoch==epoch:self.guard(lambda:accept(value))
            else:self.statusBar().showMessage('入力が変わったため古い計算結果を破棄しました。',7000)
        def error(message):
            if self.epoch==epoch:self.guard(lambda:(_ for _ in ()).throw(ValueError(message)))
        def finish():
            self.jobs.discard(job)
            if not self.jobs:self.progress.hide();self.cancel.hide()
        job.signals.result.connect(result);job.signals.error.connect(error);job.signals.finished.connect(finish);QThreadPool.globalInstance().start(job)

    def cancel_job(self):self.epoch+=1;self.statusBar().showMessage('取消しました。終了後に計算結果を破棄します。',7000)

    def refresh(self):
        self.refreshing=True
        try:
            st=self.document.state;active=st['active_project']
            if self.sample_id not in st['samples'] or st['samples'].get(self.sample_id,{}).get('deleted'):
                self.sample_id=next((sid for sid in st['projects'][active]['sample_ids'] if not st['samples'][sid].get('deleted')),None)
            s=self.sample;self.tree.clear();selected=None;trash=QTreeWidgetItem(['ごみ箱（右クリックで復元）']);trash.setData(0,Qt.UserRole,('trash',None))
            for pid,p in st['projects'].items():
                parent=QTreeWidgetItem([p['name']]);parent.setData(0,Qt.UserRole,('project',pid))
                if p.get('deleted'):trash.addChild(parent)
                else:self.tree.addTopLevelItem(parent)
                for sid in p['sample_ids']:
                    v=st['samples'][sid];item=QTreeWidgetItem([v['serial']+' / '+v['name']+' ['+workspace.status(v)+']']);item.setData(0,Qt.UserRole,('sample',sid));item.setFlags(item.flags()|Qt.ItemIsUserCheckable);item.setCheckState(0,Qt.Checked if sid in st['projects'][active]['compare_ids'] else Qt.Unchecked)
                    if v.get('deleted') and not p.get('deleted'):trash.addChild(item)
                    else:parent.addChild(item)
                    if sid==self.sample_id:selected=item
                parent.setExpanded(True)
            self.tree.addTopLevelItem(trash)
            if selected:self.tree.setCurrentItem(selected)
            fill(self.peaks_table,[[p['id'],p['angle'],p['height'],p['origin'],plotting.assignment_label(s,p['id'],st['references'])] for p in s['peaks']] if s else [])
            if s and self.peak_id not in {p['id'] for p in s['peaks']}:self.peak_id=s['peaks'][0]['id'] if s['peaks'] else None
            if s:
                for i,p in enumerate(s['peaks']):
                    if p['id']==self.peak_id:self.peaks_table.selectRow(i)
                self.raw_model=ArrayModel(s['raw_x'],s['raw_y'],['2θ (deg)','元強度 ('+s['units']['raw_y']+')']);self.raw_table.setModel(self.raw_model)
                for k,c in self.detect_controls.items():c.setValue(s['parameters'][k])
                self.tolerance.setValue(s['parameters']['tolerance']);self.shift.setChecked(s['parameters']['shift_enabled']);self.wavelength.setValue(s['parameters']['wavelength_A']);self.zero.setValue(s['parameters']['zero_deg'])
                fill(self.history_table,[[r['created'][:19],r['crystal'],r['a_A'],r['a_sigma_A'],r['c_A'],r['c_sigma_A'],'要再計算' if r['stale'] else '計算済み'] for r in s['lattice_runs']])
            else:
                self.raw_model=ArrayModel(np.array([]),np.array([]),['2θ (deg)','元強度']);self.raw_table.setModel(self.raw_model);fill(self.history_table,[])
            self.reference_ids=list(st['references']);fill(self.reference_table,[['',r['name']+' / '+r['card'],r['phase_class'],r['formula']] for r in st['references'].values()]);self.reference_table.blockSignals(True)
            for i,rid in enumerate(self.reference_ids):
                item=self.reference_table.item(i,0);item.setFlags(item.flags()|Qt.ItemIsUserCheckable);item.setCheckState(Qt.Checked if st['references'][rid]['enabled'] else Qt.Unchecked)
            self.reference_table.blockSignals(False);self.elements.setText(st['reference_settings']['allowed_elements']);self.mode.setCurrentIndex(['all','adopted','new'].index(st['reference_settings']['candidate_mode']))
            previous=self.lattice_ref.currentData();self.lattice_ref.clear();adopted={a['ref_id'] for a in s['assignments'] if a['ref_id']} if s else set()
            for rid in self.reference_ids:
                if rid in adopted:self.lattice_ref.addItem(st['references'][rid]['name'],rid)
            if previous:self.lattice_ref.setCurrentIndex(max(0,self.lattice_ref.findData(previous)))
            self.plots_combo.blockSignals(True);self.plots_combo.clear();self.plots_combo.addItem('現在の比較',None)
            for key,p in st['plots'].items():self.plots_combo.addItem(p['name']+(' [元解析に変更あり]' if p['stale'] else ''),key)
            self.plots_combo.setCurrentIndex(max(0,self.plots_combo.findData(self.plot_id)));self.plots_combo.blockSignals(False)
            self.undo_action.setEnabled(bool(self.document.undo_stack));self.redo_action.setEnabled(bool(self.document.redo_stack))
            self.setWindowTitle(f'XRD Studio {VERSION} - '+(Path(self.filename).name if self.filename else '新しい文書')+(' *' if self.document.dirty else ''))
            self.status_label.setText((s['serial']+' / '+s['name']+' | '+workspace.status(s) if s else '測定ファイルを追加してください')+' | '+('未保存' if self.document.dirty else '保存済み')+' | 原値保持')
        finally:self.refreshing=False
        self.recompute_candidates();self.draw()

    def tree_selected(self,item,previous):
        if self.refreshing or not item:return
        kind,key=item.data(0,Qt.UserRole);st=self.document.state
        if kind=='sample' and not st['samples'][key].get('deleted') and not st['projects'][st['samples'][key]['project_id']].get('deleted'):
            self.sample_id=key;st['active_project']=st['samples'][key]['project_id'];self.peak_id=None;self.candidate=None;self.plot_id=None;self.epoch+=1;self.refresh()
        elif kind=='project' and not st['projects'][key].get('deleted'):
            st['active_project']=key;self.sample_id=None;self.peak_id=None;self.epoch+=1;self.refresh()

    def tree_checked(self,item,column):
        if self.refreshing:return
        kind,key=item.data(0,Qt.UserRole)
        if kind!='sample':return
        checked=item.checkState(0)==Qt.Checked
        def op(st):
            ids=st['projects'][st['active_project']]['compare_ids']
            if checked and key not in ids:ids.append(key)
            elif not checked and key in ids:ids.remove(key)
        self.guard(lambda:self.change('比較試料を選択',op))

    def tree_menu(self,position):
        item=self.tree.itemAt(position)
        if not item:return
        kind,key=item.data(0,Qt.UserRole);actions=[];st=self.document.state
        if kind=='sample':
            if st['samples'][key].get('deleted'):actions=[('試料を復元',lambda:self.change('試料を復元',lambda s:workspace.delete_sample(s,key,False)))]
            else:actions=[('番号・表示名・組成を変更',lambda:self.metadata_dialog(key)),('別プロジェクトへ複製',lambda:self.copy_dialog(key)),('試料をごみ箱へ',lambda:self.change('試料を削除',lambda s:workspace.delete_sample(s,key)))]
        elif kind=='project':
            actions=[('復元',lambda:self.project_deleted(key,False))] if st['projects'][key].get('deleted') else [('名前を変更',lambda:self.rename_project(key)),('プロジェクトをごみ箱へ',lambda:self.project_deleted(key,True))]
        menu=QMenu(self)
        for title,fn in actions:menu.addAction(self.action(title,fn))
        if actions:menu.exec(self.tree.viewport().mapToGlobal(position))

    def stage_changed(self,index):
        if not hasattr(self,'conditions'):return
        self.conditions.setCurrentIndex(index)
        if index!=4:self.plot_id=None
        self.tables.setCurrentWidget(self.candidates_table if index==2 else self.history_table if index==3 else self.peaks_table)
        self.draw()

    def draw(self):
        st=self.document.state;stage=self.stages.currentIndex()
        if stage==4 and self.plot_id in st['plots']:
            plot=st['plots'][self.plot_id];self.axis=plotting.draw(self.figure,plot['snapshot'],compare=True);self.plot_label.setText('保存図: '+plot['name']+(' / 元解析に変更あり' if plot['stale'] else ' / 保存時の数値'))
        else:
            candidate=self.candidate if stage==2 else {'ref_id':self.reference_id,'shift':0.} if stage==1 and self.reference_id in st['references'] else None
            self.axis=plotting.draw(self.figure,st,self.sample_id,compare=stage==4,candidate=candidate,selected_peak=self.peak_id if stage==2 else None)
            if stage==2:self.axis.set_ylim(-30,110)
            if stage==4:self.plot_label.setText('ライブ比較: チェックした試料だけを表示')
            if self.sample_id in self.views and stage!=4:self.axis.set_xlim(self.views[self.sample_id])
        if stage==2:
            def lock_y(axis):
                if tuple(axis.get_ylim())!=(-30.,110.):axis.set_ylim(-30,110,emit=False)
            self.axis.callbacks.connect('ylim_changed',lock_y)
        if stage!=4:
            sid=self.sample_id
            self.axis.callbacks.connect('xlim_changed',lambda axis:self.views.update({sid:tuple(axis.get_xlim())}) if sid else None)
        self.canvas.draw_idle()

    def graph_click(self,event):
        if event.inaxes!=getattr(self,'axis',None) or event.xdata is None or self.nav.mode:return
        self.cursor_x=float(event.xdata);self.angle.setValue(self.cursor_x);self.cursor_label.setText(f'カーソル: {self.cursor_x:.6f} deg / 強度 {event.ydata:.5g}')
        if hasattr(self,'cursor_line') and self.cursor_line.axes==self.axis:
            self.cursor_line.remove()
        self.cursor_line=self.axis.axvline(self.cursor_x,color='#8b641c',linestyle=':',linewidth=1)
        self.canvas.draw_idle()
        if self.stages.currentIndex()==2 and self.sample and self.sample['peaks']:
            pixels=self.axis.transData.transform(np.array([[p['angle'],p['height']+2] for p in self.sample['peaks']]))
            d=np.linalg.norm(pixels-np.array([event.x,event.y]),axis=1);row=int(np.argmin(d))
            if d[row]<=12:self.peaks_table.selectRow(row)

    def peak_selected(self):
        if self.refreshing or not self.sample:return
        row=self.peaks_table.currentRow()
        if not 0<=row<len(self.sample['peaks']):return
        self.peak_id=self.sample['peaks'][row]['id']
        if self.stages.currentIndex()==2 and self.follow.isChecked():
            s=self.sample;x=s['peaks'][row]['angle'];lo,hi=s['raw_x'][0],s['raw_x'][-1];width=min(10,hi-lo);left=max(lo,min(x-width/2,hi-width));self.views[self.sample_id]=(left,left+width)
        self.recompute_candidates();self.draw()

    def recompute_candidates(self):
        if not self.sample or self.peak_id is None:self.candidates=[];self.candidate=None;fill(self.candidates_table,[]);fill(self.evidence_table,[]);return
        st=self.document.state;settings=st['reference_settings'];self.candidates=analysis.score_candidates(self.sample,st['references'],self.peak_id,self.sample['parameters'],settings['allowed_elements'],candidate_mode=settings['candidate_mode'])
        rows=[]
        for c in self.candidates:
            r=st['references'][c['ref_id']];rows.append([r['name']+' / '+r['card'],plotting.hkl_label(r,c['reflection']),c['residual'],c['total'],c['local'],c['global'],c['missing']])
        fill(self.candidates_table,rows)
        if self.candidates:self.candidate=self.candidates[0];self.candidates_table.selectRow(0);self.update_evidence()
        else:self.candidate=None;fill(self.evidence_table,[])

    def candidate_selected(self):
        row=self.candidates_table.currentRow()
        if not self.refreshing and 0<=row<len(self.candidates):self.candidate=self.candidates[row];self.update_evidence();self.draw()

    def update_evidence(self):
        if not self.sample or not self.candidate:return
        r=self.document.state['references'][self.candidate['ref_id']];fill(self.evidence_table,workspace.evidence(self.sample,r,self.candidate['shift'],self.sample['parameters']['tolerance']))
        missing=analysis.strong_reflection_warnings(self.sample,r,self.candidate['shift'],self.sample['parameters']['tolerance'])
        self.warning.setText(('主/第2参照ピークの不足: '+', '.join(f'{x:.3f}°' for x in missing)+'\n' if missing else '')+'スコアは確率・含有率ではありません。')

    def reference_enabled(self,item):
        if self.refreshing or item.column()!=0:return
        rid=self.reference_ids[item.row()];value=item.checkState()==Qt.Checked;self.guard(lambda:self.change('参照の使用を変更',lambda st:st['references'][rid].update(enabled=value)))
    def reference_selected(self):
        row=self.reference_table.currentRow()
        if not self.refreshing and 0<=row<len(self.reference_ids):self.reference_id=self.reference_ids[row];self.draw()
    def save_reference_settings(self):
        if self.refreshing:return
        values={'allowed_elements':self.elements.text().strip(),'candidate_mode':['all','adopted','new'][self.mode.currentIndex()]}
        analysis.formula_compatible({'formula':'','phase_class':''},values['allowed_elements'])
        self.change('候補の絞込み',lambda st:st['reference_settings'].update(values))
    def match_parameters(self):
        self.require_sample();sid=self.sample_id;value={'tolerance':self.tolerance.value(),'shift_enabled':self.shift.isChecked()};self.change('照合条件',lambda st:st['samples'][sid]['parameters'].update(value))
    def accept_sample(self,sid,sample,label):
        def op(st):st['samples'][sid]=sample;workspace.touch(st,sid)
        self.change(label,op)
    def detect(self):
        s=copy.deepcopy(self.require_sample());sid=self.sample_id;p=dict(s['parameters']);p.update({k:c.value() for k,c in self.detect_controls.items()})
        def op():analysis.detect_peaks(s,p);return s
        self.start_job('ピーク検出',op,lambda result:self.accept_sample(sid,result,'ピーク検出'))
    def add_manual(self):
        s=self.require_sample();angle=self.angle.value()
        if not s['raw_x'][0]<=angle<=s['raw_x'][-1]:raise ValueError('測定範囲内の角度を指定してください。')
        sid=self.sample_id;index=int(np.argmin(abs(s['raw_x']-angle)));self.change('ピークを手動追加',lambda st:(analysis.add_peak(st['samples'][sid],index),workspace.touch(st,sid)))
    def add_cursor(self):
        self.require_sample()
        if self.cursor_x is None:raise ValueError('グラフをクリックして位置を指定してください。')
        if QMessageBox.question(self,'ピークを追加',f'{self.cursor_x:.6f} deg の近傍点を登録しますか？')==QMessageBox.Yes:self.angle.setValue(self.cursor_x);self.add_manual()
    def delete_peak(self):
        self.require_sample()
        if self.peak_id is None:raise ValueError('削除するピークを選んでください。')
        sid,pid=self.sample_id,self.peak_id;self.change('ピークを削除',lambda st:(analysis.delete_peak(st['samples'][sid],pid),workspace.touch(st,sid)))
    def import_peaks(self):
        self.require_sample();path,_=QFileDialog.getOpenFileName(self,'外部ピークリスト','','Text (*.txt *.csv *.tsv *.dat)')
        if path:
            sid=self.sample_id;self.change('外部ピークを追加',lambda st:(workspace.external_peaks(st['samples'][sid],path),workspace.touch(st,sid)))
    def adopt_candidate(self,overlap=False):
        s=self.require_sample()
        if self.peak_id is None or self.candidate is None:raise ValueError('ピークと候補を選んでください。')
        c=dict(self.candidate);sid,pid=self.sample_id,self.peak_id;r=self.document.state['references'][c['ref_id']]
        missing=analysis.strong_reflection_warnings(s,r,c['shift'],s['parameters']['tolerance'])
        if missing and QMessageBox.question(self,'強い参照反射の確認','主/第2反射に対応する登録ピークが不足しています。\nこの候補を採用しますか？')!=QMessageBox.Yes:return
        def op(st):
            s=st['samples'][sid]
            if not overlap:analysis.clear_assignments(s,pid)
            analysis.assign(s,pid,c);workspace.touch(st,sid)
        self.change('同定候補を採用',op)
    def unknown(self):
        self.require_sample()
        if self.peak_id is None:raise ValueError('ピークを選んでください。')
        sid,pid=self.sample_id,self.peak_id;self.change('Unknown',lambda st:(analysis.assign(st['samples'][sid],pid),workspace.touch(st,sid)))
    def clear_assignment(self):
        self.require_sample()
        if self.peak_id is None:return
        sid,pid=self.sample_id,self.peak_id;self.change('同定を解除',lambda st:(analysis.clear_assignments(st['samples'][sid],pid),workspace.touch(st,sid)))
    def full_view(self):self.views.pop(self.sample_id,None);self.draw();self.nav.update()
    def lattice(self):
        s=copy.deepcopy(self.require_sample());sid=self.sample_id;rid=self.lattice_ref.currentData()
        if rid is None:raise ValueError('先に参照相へ同定してください。')
        r=copy.deepcopy(self.document.state['references'][rid]);crystal=['Cubic','Hexagonal'][self.crystal.currentIndex()];s['parameters'].update(wavelength_A=self.wavelength.value(),zero_deg=self.zero.value());excluded=[int(v.strip()) for v in self.excluded.text().split(',') if v.strip()]
        def op():analysis.invalidate_lattice(s);analysis.fit_lattice(s,r,crystal,excluded);return s
        def accept(result):
            self.accept_sample(sid,result,'格子定数を計算');run=result['lattice_runs'][-1];self.lattice_label.setText(f"a = {run['a_A']:.8f} ± {run['a_sigma_A']:.3g} Å"+(f"\nc = {run['c_A']:.8f} ± {run['c_sigma_A']:.3g} Å" if run['c_A'] is not None else '')+'\n回帰由来の標準誤差')
        self.start_job('格子計算',op,accept)

    def profile_dialog(self):
        self.require_sample()
        if self.peak_id is None:raise ValueError('フィットするピークを選んでください。')
        sid,pid=self.sample_id,self.peak_id;p=next(p for p in self.sample['peaks'] if p['id']==pid)
        dialog=QDialog(self);dialog.setWindowTitle('局所フィット / 中心の明示採用');dialog.resize(830,650);box=QVBoxLayout(dialog);row=QHBoxLayout()
        lo=self.spin(max(self.sample['raw_x'][0],p['angle']-.4),-360,360,6);hi=self.spin(min(self.sample['raw_x'][-1],p['angle']+.4),-360,360,6);model=QComboBox();model.addItems(['Gaussian','Lorentzian']);bg=QCheckBox('直線背景');bg.setChecked(True)
        for w in [QLabel('範囲 (deg)'),lo,hi,model,bg]:row.addWidget(w)
        box.addLayout(row);figure=Figure();canvas=FigureCanvasQTAgg(figure);box.addWidget(canvas,1);info=QLabel('計算だけでは登録角度を変更しません。');box.addWidget(info)
        def redraw():
            fit=self.document.state['samples'][sid]['profiles'].get(str(pid))
            if fit:
                plotting.draw(figure,self.document.state,sid,selected_peak=pid,profile=True);canvas.draw_idle();info.setText(f"中心 {fit['center']:.7f} ± {fit['center_sigma']:.3g} deg / FWHM {fit['fwhm']:.6f} deg\n採用済み中心: {fit.get('accepted_center')}")
        def fit():self.change('局所フィット',lambda st:analysis.fit_profile(st['samples'][sid],pid,lo.value(),hi.value(),model.currentText(),bg.isChecked()));redraw()
        def adopt(restore=False):
            self.change('登録位置へ復帰' if restore else '中心採用',lambda st:(analysis.adopt_profile(st['samples'][sid],pid,restore),workspace.touch(st,sid)));redraw()
        buttons=QHBoxLayout()
        for label,fn in [('フィットを計算',fit),('この中心を採用',adopt),('登録位置に戻す',lambda:adopt(True))]:self.button(buttons,label,fn)
        def export_fit():
            if str(pid) not in self.document.state['samples'][sid]['profiles']:raise ValueError('先にフィットを計算してください。')
            path,_=QFileDialog.getSaveFileName(dialog,'フィットと残差の図','profile.pdf','PDF (*.pdf);;SVG (*.svg);;PNG (*.png)')
            if path:figure.savefig(path,dpi=300,facecolor='white')
        self.button(buttons,'図を出力',export_fit)
        close=QPushButton('閉じる');close.clicked.connect(dialog.accept);buttons.addWidget(close);box.addLayout(buttons);redraw();dialog.exec()

    def show_comparison(self):self.plot_id=None;self.plots_combo.setCurrentIndex(0);self.stages.setCurrentIndex(4);self.draw()
    def capture_plot(self):
        ids=list(self.document.state['projects'][self.document.state['active_project']]['compare_ids']);name,ok=QInputDialog.getText(self,'完成図を保存','図の名前',text=f'比較図 {len(self.document.state["plots"])+1}')
        if ok and name.strip():self.plot_id=self.change('完成図を保存',lambda st:workspace.save_plot(st,name.strip(),ids));self.refresh();self.stages.setCurrentIndex(4);self.draw()
    def select_plot(self,index):
        if not self.refreshing:self.plot_id=self.plots_combo.currentData();self.stages.setCurrentIndex(4);self.draw()
    def figure_state(self):
        if self.stages.currentIndex()==4 and self.plot_id in self.document.state['plots']:return self.document.state['plots'][self.plot_id]['snapshot']
        return self.document.state
    def figure_settings(self):
        settings=self.figure_state()['plot'];dialog=QDialog(self);dialog.setWindowTitle('図の書式');form=QFormLayout(dialog);controls={}
        for key,label,lo,hi in [('width_cm','幅 (cm)',3,60),('height_cm','高さ (cm)',3,60),('font_pt','文字 (pt)',6,40),('line_pt','線幅 (pt)',.1,10),('offset','縦ずらし',0,500)]:controls[key]=self.spin(settings[key],lo,hi);form.addRow(label,controls[key])
        cols=QSpinBox();cols.setRange(1,4);cols.setValue(settings['legend_columns']);form.addRow('凡例の列数',cols);title=QLineEdit(settings['title']);form.addRow('タイトル',title)
        x_label=QLineEdit(settings.get('x_label',''));y_label=QLineEdit(settings.get('y_label',''))
        x_label.setPlaceholderText('空欄は2θ (deg)');y_label.setPlaceholderText('空欄は規格化強度')
        form.addRow('X軸ラベル',x_label);form.addRow('Y軸ラベル',y_label);limits={}
        for key,label in [('x_min','X下限 (deg)'),('x_max','X上限 (deg)'),('y_min','Y下限'),('y_max','Y上限')]:limits[key]=QLineEdit('' if settings.get(key) is None else str(settings[key]));limits[key].setPlaceholderText('空欄は自動');form.addRow(label,limits[key])
        buttons=QDialogButtonBox(QDialogButtonBox.Ok|QDialogButtonBox.Cancel);buttons.accepted.connect(dialog.accept);buttons.rejected.connect(dialog.reject);form.addRow(buttons)
        if dialog.exec()!=QDialog.Accepted:return
        values={k:v.value() for k,v in controls.items()};values.update(legend_columns=cols.value(),title=title.text(),x_label=x_label.text(),y_label=y_label.text());values.update({k:float(v.text()) if v.text().strip() else None for k,v in limits.items()})
        for a,b in [('x_min','x_max'),('y_min','y_max')]:
            if values[a] is not None and values[b] is not None and values[a]>=values[b]:raise ValueError('軸の下限は上限より小さくしてください。')
        if any(isinstance(v,float) and not np.isfinite(v) for v in values.values()):raise ValueError('有限値を入力してください。')
        saved=self.plot_id if self.stages.currentIndex()==4 else None;self.change('図の書式',lambda st:(st['plots'][saved]['snapshot']['plot'] if saved else st['plot']).update(values))
    def keep_graph_range(self):
        xmin,xmax=self.axis.get_xlim();ymin,ymax=self.axis.get_ylim();saved=self.plot_id if self.stages.currentIndex()==4 else None
        self.change('図の軸範囲',lambda st:(st['plots'][saved]['snapshot']['plot'] if saved else st['plot']).update(x_min=xmin,x_max=xmax,y_min=ymin,y_max=ymax))
    def add_annotation(self):
        text,ok=QInputDialog.getText(self,'注釈を追加','注釈の文字')
        if not ok or not text.strip():return
        x=float(np.mean(self.axis.get_xlim()));y=float(np.mean(self.axis.get_ylim()));saved=self.plot_id if self.stages.currentIndex()==4 else None
        self.change('図の注釈',lambda st:(st['plots'][saved]['snapshot']['plot'] if saved else st['plot'])['annotations'].append({'x':x,'y':y,'text':text}))
    def export_graph(self):
        path,_=QFileDialog.getSaveFileName(self,'図を書き出す','XRD_figure.pdf','PDF (*.pdf);;SVG (*.svg);;PNG (*.png)')
        if path:
            stage=self.stages.currentIndex();candidate=self.candidate if stage==2 else {'ref_id':self.reference_id,'shift':0.} if stage==1 and self.reference_id in self.document.state['references'] else None
            dpi=300
            if Path(path).suffix.lower()=='.png':
                value,ok=QInputDialog.getItem(self,'PNGの解像度','dpi',['300','600'],editable=False)
                if not ok:return
                dpi=int(value)
            plotting.export_figure(path,self.figure_state(),self.sample_id,stage==4,candidate,self.peak_id if stage==2 else None,(self.axis.get_xlim(),self.axis.get_ylim()),dpi)
            self.statusBar().showMessage('図を書き出しました。',7000)
    def export_results(self):
        path=QFileDialog.getExistingDirectory(self,'CSVとExcelの出力先')
        if path:workspace.export_tables(self.document.state,path,xlsx=True);self.statusBar().showMessage('CSVとXLSXを書き出しました。',7000)
    def export_table(self):
        widget=self.tables.currentWidget();path,_=QFileDialog.getSaveFileName(self,'表をCSVへ','XRD_table.csv','CSV (*.csv)')
        if not path:return
        with open(path,'w',newline='',encoding='utf-8-sig') as f:
            writer=csv.writer(f)
            if isinstance(widget,QTableWidget):writer.writerow([widget.horizontalHeaderItem(i).text() for i in range(widget.columnCount())]);writer.writerows([[widget.item(r,c).text() if widget.item(r,c) else '' for c in range(widget.columnCount())] for r in range(widget.rowCount())])
            else:writer.writerow(widget.model().headers);writer.writerows(zip(widget.model().x,widget.model().y))

    def wave_dialog(self):
        self.require_sample();sid=self.sample_id;dialog=QDialog(self);dialog.setWindowTitle('データブラウザー / 原値と作業コピー');dialog.resize(900,650);box=QVBoxLayout(dialog);row=QHBoxLayout();combo=QComboBox();row.addWidget(combo,1);make=QPushButton('規格化値を作業コピーへ');row.addWidget(make);box.addLayout(row)
        view=QTableView();view.horizontalHeader().setStretchLastSection(True)
        tabs=QTabWidget();tabs.addTab(view,'データ表');working_figure=Figure();working_canvas=FigureCanvasQTAgg(working_figure);tabs.addTab(working_canvas,'作業データのグラフ');box.addWidget(tabs,1)
        note=QLabel();note.setWordWrap(True);box.addWidget(note)
        def draw_working():
            m=view.model()
            if m is None:return
            working_figure.clear();ax=working_figure.add_subplot(111);ax.plot(m.x,m.y,color='#176e7a',linewidth=1)
            ax.set(xlabel=m.headers[0],ylabel=m.headers[1],title=combo.currentText());working_figure.tight_layout();working_canvas.draw_idle()
        def show():
            key=combo.currentData();s=self.document.state['samples'][sid]
            if key in ('raw','processed'):
                model=ArrayModel(s['raw_x'],s['raw_y'] if key=='raw' else s['processed_y'],['2θ (deg)','元強度' if key=='raw' else '規格化強度 (%)']);note.setText('読取専用。編集する場合は独立した作業コピーを作成します。')
            else:
                w=self.document.state['waves'][key]
                def edit(row,value):
                    self.change('作業データのセル編集',lambda st:workspace.set_wave_value(st,key,row,value),False);model.y=self.document.state['waves'][key]['y'];self.refresh();draw_working();return True
                model=ArrayModel(w['x'],w['y'],['X ('+w['x_unit']+')','Y ('+w['y_unit']+')'],edit);note.setText(w['note']+' 強度列をダブルクリックして編集できます。')
            view.setModel(model);view.array_model=model;draw_working()
        def populate(selected=None):
            combo.blockSignals(True);combo.clear();combo.addItem('元データ（読取専用）','raw');combo.addItem('規格化データ（読取専用）','processed')
            for key,w in self.document.state['waves'].items():
                if w['sample_id']==sid:combo.addItem(w['name'],key)
            if selected:combo.setCurrentIndex(max(0,combo.findData(selected)))
            combo.blockSignals(False);show()
        def create():key=self.change('作業データを複製',lambda st:workspace.new_wave(st,sid));populate(key)
        def transform():
            key=combo.currentData()
            if key in ('raw','processed'):raise ValueError('作業コピーを選んでください。')
            name,ok=QInputDialog.getItem(dialog,'作業データの処理','処理',['倍率を掛ける','定数を加える','0-100規格化','数値微分','平滑化'],editable=False)
            if not ok:return
            code={'倍率を掛ける':'scale','定数を加える':'offset','0-100規格化':'normalize','数値微分':'derivative','平滑化':'smooth'}[name];value=1
            if code in ('scale','offset','smooth'):
                value,ok=QInputDialog.getDouble(dialog,name,'値（平滑化は3以上の奇数点）',5 if code=='smooth' else 1,-1e8,1e8,4)
                if not ok:return
            self.change('作業データを処理',lambda st:workspace.transform_wave(st,key,code,value));show()
        def copy_cells():
            rows=sorted({i.row() for i in view.selectionModel().selectedIndexes()});model=view.model();QApplication.clipboard().setText('\n'.join(str(model.x[r])+'\t'+str(model.y[r]) for r in rows))
        def metadata():
            key=combo.currentData()
            if key in ('raw','processed'):raise ValueError('作業コピーを選んでください。')
            w=self.document.state['waves'][key];name,ok=QInputDialog.getText(dialog,'作業データ名','名前',text=w['name'])
            if not ok:return
            unit,ok=QInputDialog.getText(dialog,'単位','Y単位',text=w['y_unit'])
            if not ok:return
            note_text,ok=QInputDialog.getText(dialog,'注記','データの注記',text=w['note'])
            if ok:self.change('作業データの名前・単位・注記',lambda st:st['waves'][key].update(name=name,y_unit=unit,note=note_text));populate(key)
        def export_working():
            path,_=QFileDialog.getSaveFileName(dialog,'表示中のデータを書き出す','working.csv','CSV (*.csv);;PNG (*.png);;PDF (*.pdf);;SVG (*.svg)')
            if not path:return
            if Path(path).suffix.lower()=='.csv':
                with open(path,'w',newline='',encoding='utf-8-sig') as f:
                    writer=csv.writer(f);writer.writerow(view.model().headers);writer.writerows(zip(view.model().x,view.model().y))
            else:working_figure.savefig(path,dpi=300,facecolor='white')
        combo.currentIndexChanged.connect(show);make.clicked.connect(lambda:self.guard(create));row=QHBoxLayout()
        for label,fn in [('作業データを処理',transform),('名前・単位',metadata),('選択行をコピー',copy_cells),('表・図を出力',export_working)]:self.button(row,label,fn)
        close=QPushButton('閉じる');close.clicked.connect(dialog.accept);row.addWidget(close);box.addLayout(row);populate();dialog.exec()

    def add_project(self):
        name,ok=QInputDialog.getText(self,'プロジェクトを追加','プロジェクト名')
        if ok:self.sample_id=None;self.change('プロジェクトを追加',lambda st:workspace.new_project(st,name))
    def rename_project(self,pid):
        name,ok=QInputDialog.getText(self,'名前を変更','プロジェクト名',text=self.document.state['projects'][pid]['name'])
        if ok and name.strip():
            if any(p['id']!=pid and p['name']==name.strip() and not p.get('deleted') for p in self.document.state['projects'].values()):raise ValueError('同名のプロジェクトがあります。')
            self.change('プロジェクト名を変更',lambda st:st['projects'][pid].update(name=name.strip()))
    def project_deleted(self,pid,deleted):
        if deleted and QMessageBox.question(self,'ごみ箱へ移動','所属試料は保持され、あとから復元できます。移動しますか？')!=QMessageBox.Yes:return
        def op(st):
            st['projects'][pid]['deleted']=deleted
            if deleted and st['active_project']==pid:
                other=next((k for k,p in st['projects'].items() if not p.get('deleted')),None)
                st['active_project']=other if other else workspace.new_project(st,'新しいプロジェクト '+str(len(st['projects'])+1))
            if deleted:
                ids=set(st['projects'][pid]['sample_ids'])
                for p in st['projects'].values():p['compare_ids']=[x for x in p['compare_ids'] if x not in ids]
        self.sample_id=None;self.change('プロジェクトをごみ箱へ' if deleted else 'プロジェクトを復元',op)
    def metadata_dialog(self,sid):
        s=self.document.state['samples'][sid];dialog=QDialog(self);dialog.setWindowTitle('試料の登録情報');form=QFormLayout(dialog);serial=QLineEdit(s['serial']);name=QLineEdit(s['name']);composition=QLineEdit(s['composition'])
        form.addRow('通し番号（先頭0を保持）',serial);form.addRow('表示名',name);form.addRow('組成',composition);buttons=QDialogButtonBox(QDialogButtonBox.Ok|QDialogButtonBox.Cancel);buttons.accepted.connect(dialog.accept);buttons.rejected.connect(dialog.reject);form.addRow(buttons)
        if dialog.exec()==QDialog.Accepted:self.change('試料情報',lambda st:workspace.set_metadata(st,sid,serial.text(),name.text(),composition.text()))
    def copy_dialog(self,sid):
        choices=[(pid,p['name']) for pid,p in self.document.state['projects'].items() if not p.get('deleted')];name,ok=QInputDialog.getItem(self,'試料を複製','複製先',[x[1] for x in choices],editable=False)
        if not ok:return
        serial,ok=QInputDialog.getText(self,'試料を複製','複製後の通し番号',text=self.document.state['samples'][sid]['serial'])
        if ok:self.change('試料を複製',lambda st:workspace.copy_sample(st,sid,next(pid for pid,n in choices if n==name),serial))
    def import_measurement(self):
        path,_=QFileDialog.getOpenFileName(self,'測定ファイルを追加','','XRD (*.txt *.csv *.xy *.dat);;All files (*)')
        if not path:return
        serial,ok=QInputDialog.getText(self,'測定ファイルを追加','通し番号（015等。自動採番しません）')
        if not ok:return
        name,ok=QInputDialog.getText(self,'表示名','表示名',text=Path(path).stem)
        if not ok:return
        composition,ok=QInputDialog.getText(self,'組成','組成（表示名から初期入力）',text=name)
        if ok:self.sample_id=self.change('測定ファイルを追加',lambda st:workspace.add_measurement(st,path,serial,name,composition));self.refresh()
    def import_reference(self):
        files,_=QFileDialog.getOpenFileNames(self,'参照ファイルを追加','','Reference (*.txt *.csv *.tsv *.dat)')
        if files:self.change('参照を追加',lambda st:[workspace.add_reference(st,p) for p in files])
    def discard_ok(self):
        if not self.document.dirty:return True
        answer=QMessageBox.question(self,'文書の変更を保存','変更を保存してから続けますか？',QMessageBox.Save|QMessageBox.Discard|QMessageBox.Cancel,QMessageBox.Save)
        if answer==QMessageBox.Cancel:return False
        return bool(self.save()) if answer==QMessageBox.Save else True
    def new_document(self):
        if self.discard_ok():self.document=Document();self.filename=None;self.sample_id=None;self.peak_id=None;self.plot_id=None;self.views={};self.epoch+=1;self.refresh()
    def populate_demo(self):
        if not self.discard_ok():return
        self.document=Document();self.document.change('人工データ',demo.populate);self.filename=None;self.sample_id=None;self.peak_id=None;self.plot_id=None;self.epoch+=1;self.refresh()
    def open_document(self):
        if not self.discard_ok():return
        path,_=QFileDialog.getOpenFileName(self,'解析文書を開く','','XRD document (*.labx)')
        if path:self.load_path(path)
    def load_path(self,path):
        document=load_document(path);self.document=document;self.filename=path;self.sample_id=None;self.peak_id=None;self.plot_id=None;self.views={};self.epoch+=1;self.refresh()
    def save(self,save_as=False):
        path=self.filename
        if save_as or not path:path,_=QFileDialog.getSaveFileName(self,'解析文書を保存',path or 'XRD_project.labx','XRD document (*.labx)')
        if not path:return False
        save_document(self.document,path);self.filename=path;self.refresh();return True
    def recovery_dir(self):return Path(os.environ.get('LOCALAPPDATA',str(Path.home())))/'XRDStudio'/'Recovery'
    def autosave(self):
        if not self.document.dirty:return
        try:workspace.recover(self.document,self.recovery_dir());self.statusBar().showMessage('復旧用コピーを保存。通常保存は未実施です。',5000)
        except Exception as e:self.statusBar().showMessage('復旧コピーを保存できません: '+str(e),12000)
    def offer_recovery(self):
        if os.environ.get('XRD_TESTING')=='1':return
        directory=self.recovery_dir()
        if directory.exists() and list(directory.glob('*-1.labx')) and QMessageBox.question(self,'復旧コピー','前回の復旧コピーがあります。候補を表示しますか？')==QMessageBox.Yes:
            path,_=QFileDialog.getOpenFileName(self,'復旧する文書',str(directory),'XRD document (*.labx)')
            if path:self.guard(lambda:self.load_path(path));self.filename=None;self.document.dirty=True;self.refresh()
    def undo(self):self.document.undo();self.epoch+=1;self.refresh()
    def redo(self):self.document.redo();self.epoch+=1;self.refresh()
    def scope(self):QMessageBox.information(self,'XRD Studio '+VERSION,'Igorなしで起動するXRD開発版です。\nデータ表・作業コピー・グラフ操作・Undo/Redo・文書保存・復旧と基本XRD解析を実装。\n\n全コマンド互換、PXP直接読込、全機能の数値同等性、実測受入試験は未完了です。\n検出はSciPy方式でIgor Peak AutoFindと同一ではありません。')
    def closeEvent(self,event):
        if not self.discard_ok():event.ignore();return
        self.epoch+=1
        if os.environ.get('XRD_TESTING')!='1':self.settings.setValue('geometry',self.saveGeometry())
        event.accept()


def main():
    app=QApplication.instance() or QApplication(sys.argv);app.setApplicationName('XRD Studio');app.setApplicationVersion(VERSION);app.setFont(QFont('Yu Gothic UI',10));app.setStyle('Fusion')
    app.setStyleSheet('QToolBar {spacing:7px;padding:5px;} QPushButton {padding:6px 9px;} QTabBar::tab {padding:10px 12px;}')
    window=StudioWindow()
    if '--demo' in sys.argv:window.populate_demo()
    window.show();return app.exec()
