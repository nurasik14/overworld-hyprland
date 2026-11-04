// Widget gallery for eyeballing the Overworld Kvantum themes (QA aid, not installed).
// Build+run: see build-gallery.sh.  Shows (almost) every widget Kvantum themes on one window.
#include <QtWidgets>
int main(int argc, char **argv) {
    QApplication app(argc, argv);
    QWidget w; w.resize(1000, 760);
    auto *grid = new QGridLayout(&w);
    auto *mb = new QMenuBar; mb->addMenu("File")->addAction("Open"); mb->addMenu("Edit");
    auto *menu = new QMenu("Popup");
    menu->addAction("Normal item"); auto *ck = menu->addAction("Checked item"); ck->setCheckable(true); ck->setChecked(true);
    auto *dis = menu->addAction("Disabled item"); dis->setEnabled(false);
    menu->addSeparator(); menu->addMenu("Submenu")->addAction("Sub");
    grid->setMenuBar(mb);

    auto *tabs = new QTabWidget; grid->addWidget(tabs, 0, 0, 1, 3);
    auto *t1 = new QWidget; auto *tl = new QGridLayout(t1);
    QMenu *menuPtr = nullptr; (void)menuPtr;
    // buttons
    auto *b1 = new QPushButton("Button"); auto *b2 = new QPushButton("Disabled"); b2->setEnabled(false);
    auto *b3 = new QPushButton("Checked"); b3->setCheckable(true); b3->setChecked(true);
    auto *b4 = new QPushButton("Default"); b4->setDefault(true);
    auto *tb = new QToolButton; tb->setText("Tool"); auto *tb2 = new QToolButton; tb2->setText("Tool on"); tb2->setCheckable(true); tb2->setChecked(true);
    auto *tb3 = new QToolButton; tb3->setText("Menu tool"); tb3->setPopupMode(QToolButton::MenuButtonPopup); tb3->setMenu(menu);
    tl->addWidget(b1, 0, 0); tl->addWidget(b2, 0, 1); tl->addWidget(b3, 0, 2); tl->addWidget(b4, 0, 3);
    tl->addWidget(tb, 1, 0); tl->addWidget(tb2, 1, 1); tl->addWidget(tb3, 1, 2);
    // check/radio
    auto *g = new QGroupBox("Group box"); auto *gl = new QVBoxLayout(g);
    auto *c1 = new QCheckBox("Unchecked"); auto *c2 = new QCheckBox("Checked"); c2->setChecked(true);
    auto *c3 = new QCheckBox("Tristate"); c3->setTristate(true); c3->setCheckState(Qt::PartiallyChecked);
    auto *c4 = new QCheckBox("Disabled on"); c4->setChecked(true); c4->setEnabled(false);
    auto *r1 = new QRadioButton("Radio off"); auto *r2 = new QRadioButton("Radio on"); r2->setChecked(true);
    auto *r3 = new QRadioButton("Radio disabled"); r3->setEnabled(false);
    for (auto *x : std::initializer_list<QWidget*>{c1, c2, c3, c4, r1, r2, r3}) gl->addWidget(x);
    tl->addWidget(g, 2, 0, 3, 2);
    // inputs
    auto *le = new QLineEdit("Line edit text"); auto *le2 = new QLineEdit("Disabled"); le2->setEnabled(false);
    auto *le3 = new QLineEdit; le3->setPlaceholderText("Placeholder"); le3->setFocus();
    auto *sp = new QSpinBox; sp->setValue(7); auto *co = new QComboBox; co->addItems({"Combo one", "Combo two"});
    auto *ce = new QComboBox; ce->setEditable(true); ce->addItems({"Editable"});
    auto *lev = new QWidget; auto *lel = new QVBoxLayout(lev); lel->setContentsMargins(0,0,0,0);
    lel->addWidget(le); lel->addWidget(le2); lel->addWidget(le3); lel->addStretch();
    tl->addWidget(lev, 2, 2, 3, 2);
    tl->addWidget(sp, 5, 0); tl->addWidget(co, 5, 1); tl->addWidget(ce, 5, 2);
    tabs->addTab(t1, "Widgets"); 
    auto *t2 = new QWidget; auto *t2l = new QVBoxLayout(t2); t2l->addWidget(new QLabel("Second tab (not selected)"));
    tabs->addTab(t2, "Other tab"); tabs->addTab(new QWidget, "Third");

    // sliders / progress / scrollbars
    auto *box = new QWidget; auto *bl = new QGridLayout(box);
    auto *s1 = new QSlider(Qt::Horizontal); s1->setValue(60); auto *s2 = new QSlider(Qt::Vertical); s2->setValue(30); s2->setMinimumHeight(110);
    auto *s3 = new QSlider(Qt::Horizontal); s3->setValue(40); s3->setEnabled(false);
    auto *p1 = new QProgressBar; p1->setValue(55); auto *p2 = new QProgressBar; p2->setValue(30); p2->setEnabled(false);
    auto *p3 = new QProgressBar; p3->setOrientation(Qt::Vertical); p3->setValue(70); p3->setMinimumHeight(110);
    auto *sb1 = new QScrollBar(Qt::Horizontal); sb1->setRange(0, 100); sb1->setPageStep(30); sb1->setValue(20);
    auto *sb2 = new QScrollBar(Qt::Vertical); sb2->setRange(0, 100); sb2->setPageStep(30); sb2->setValue(20); sb2->setMinimumHeight(110);
    bl->addWidget(s1, 0, 0); bl->addWidget(s3, 1, 0); bl->addWidget(p1, 2, 0); bl->addWidget(p2, 3, 0); bl->addWidget(sb1, 4, 0);
    bl->addWidget(s2, 0, 1, 5, 1); bl->addWidget(p3, 0, 2, 5, 1); bl->addWidget(sb2, 0, 3, 5, 1);
    grid->addWidget(box, 1, 0);
    // views
    auto *lw = new QListWidget; for (int i = 0; i < 6; i++) lw->addItem(QString("List item %1").arg(i)); lw->setCurrentRow(1); lw->setMaximumHeight(120);
    lw->item(3)->setSelected(true);
    auto *tw = new QTreeWidget; tw->setHeaderLabels({"Tree", "Value"});
    auto *top = new QTreeWidgetItem({"Parent", "1"}); top->addChild(new QTreeWidgetItem({"Child", "2"})); tw->addTopLevelItem(top); top->setExpanded(true);
    tw->addTopLevelItem(new QTreeWidgetItem({"Another", "3"}));
    auto *vb = new QWidget; auto *vl = new QVBoxLayout(vb); vl->addWidget(lw); vl->addWidget(tw);
    grid->addWidget(vb, 1, 1);
    auto *te = new QTextEdit("Text edit\nsecond line"); auto *tbx = new QToolBox; tbx->addItem(te, "Toolbox page"); tbx->addItem(new QLabel("x"), "Page 2");
    auto *rt = new QWidget; auto *rl = new QVBoxLayout(rt); rl->addWidget(tbx);
    auto *fr = new QFrame; fr->setFrameShape(QFrame::StyledPanel); fr->setMinimumHeight(40); rl->addWidget(fr);
    auto *lbl = new QLabel("Label text on the panel"); rl->addWidget(lbl);
    grid->addWidget(rt, 1, 2);
    w.setWindowTitle("overworld-test kvantum gallery");
    w.show();
    { menu->ensurePolished(); menu->resize(menu->sizeHint()); auto *ml = new QLabel; ml->setPixmap(menu->grab()); tl->addWidget(ml, 0, 4, 6, 1, Qt::AlignTop); }
    QTimer::singleShot(600000, [&] { QPoint p = w.mapToGlobal(QPoint(560, 140)); menu->popup(p); });
    QTimer::singleShot(900, [&] { QToolTip::showText(w.mapToGlobal(QPoint(360, 700)), "Tooltip: Diamond Pickaxe\nMining speed 8", &w); });
    return app.exec();
}
