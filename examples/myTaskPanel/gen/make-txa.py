"""
Writes TaskPanelGen.txa - an ABC application that exercises the myTaskPanel
templates end to end. build.sh imports it, generates it with ClarionCL and
compiles the result.

  Main          an ABC Frame with a MENUBAR (three levels deep) and a toolbar,
                carrying the myTaskPanel extension: groups with nested items,
                every kind of action, a separator, a label, the frame's menu
                copied at run time and a show/hide key.
  BrowseStub    a window the items start on their own thread
  AboutStub     a window an item calls
"""
import os, sys

ENGINE = sys.argv[1] if len(sys.argv) > 1 else 'DirectX (Direct2D and DirectWrite)'
q = lambda s: s.replace("'", "''")

# (group caption, glyph, open, accent, [items])
# item = dict(text, level, glyph, kind, action, proc, url, ctl, wincmd, shortcut, open)
GROUPS = [
    ('Catalogs', 'table', 1, 1, [
        dict(text='Customers', glyph='user', action='Start a procedure', proc='BrowseStub', shortcut='Ctrl+U'),
        dict(text='Products', glyph='box', action='Press a control or menu item', ctl='?BrProducts'),
        dict(text='Geography', glyph='globe', open=1),
        dict(text='Countries', level=1, action='Start a procedure', proc='BrowseStub'),
        dict(text='More', level=1, open=1),
        dict(text='Cities', level=2, action='Start a procedure', proc='BrowseStub'),
        dict(text='Too deep - clamped', level=5),
    ]),
    ('Exports', 'export', 1, 0, [
        dict(text='Excel (.xlsx)', glyph='excel'),
        dict(text='', kind='Separator'),
        dict(text='Formats', kind='Label'),
        dict(text='PDF', glyph='pdf'),
    ]),
    ('Window', 'window', 0, 0, [
        dict(text='Tile', glyph='tile', action='Window command', wincmd='Tile vertically'),
        dict(text='Cascade', glyph='cascade', action='Window command', wincmd='Cascade'),
    ]),
    ('Help', 'help', 1, 0, [
        dict(text="What's new", glyph='star', action='Open a URL or file', url='https://example.com/new?a=1&b=2'),
        dict(text='About...', glyph='info', action='Start a procedure', proc='AboutStub'),
        dict(text='Exit', glyph='exit', action='Close the window'),
    ]),
]

# conditions (Show only when / Enable only when): one shown, one hidden, one disabled, one group hidden
GROUPS[0][4][0]['showif'] = 'TODAY() > 0'
GROUPS[0][4][1]['showif'] = 'TODAY() < 0'
GROUPS[0][4][2]['enableif'] = 'CLOCK() < 0'
GROUP_SHOWIF = ['', '', '', 'TODAY() < 0'] + [''] * 20
# info cards, their values refreshed with the conditions; one clickable
GROUPS[1][4].extend([
    dict(kind='Info', text='Today', value='FORMAT(TODAY(), @d17)'),
    dict(kind='Progress', text='Target', value='64', action='Post an event', event='EVENT:User'),
    dict(kind='Chart', text='Weeks', value="'12,15,9,18,22'", chart='Line'),
])

# Extras: a description, a drop target, two hover buttons on Customers
GROUPS[0][4][0]['tip'] = 'Browse, add and change customers.'
GROUPS[0][4][0]['drop'] = 1
# Insert a record: an item and a hover button open FormStub (an MDI window) to insert, on their own thread
INS = 'Insert a record (a form)'
GROUPS[1][4].append(dict(text='New customer', glyph='plus', action=INS, proc='BrowseStub'))
INS_TAG = 'g2i%d' % len(GROUPS[1][4])
BUTTONS = {(0, 0): [dict(glyph='plus', tip='New customer', action=INS, proc='BrowseStub'),
                    dict(glyph='print', tip='Print', action='Embed code only')]}

def prompts_groups():
    L = []
    n = len(GROUPS)
    ids = ', '.join(str(i + 1) for i in range(n))
    L.append(f'%mtpGroups MULTI LONG  ({ids})')
    def g(sym, typ, idx, fmt):
        L.append(f'{sym} DEPEND %mtpGroups {typ} TIMES {n}')
        for i, grp in enumerate(GROUPS):
            L.append(f'WHEN  ({i + 1}) ({fmt(grp[idx])})')
    g('%mtpGroupText', 'DEFAULT', 0, lambda v: f"'{q(v)}'")
    g('%mtpGroupGlyph', 'DEFAULT', 1, lambda v: f"'{v}'")
    g('%mtpGroupOpen', 'LONG', 2, str)
    g('%mtpGroupSpecial', 'LONG', 3, str)
    L.append(f'%mtpGroupIcon DEPEND %mtpGroups DEFAULT TIMES {n}')
    for i in range(n): L.append(f"WHEN  ({i + 1}) ('')")
    L.append(f'%mtpGroupHidden DEPEND %mtpGroups LONG TIMES {n}')
    for i in range(n): L.append(f"WHEN  ({i + 1}) (0)")
    L.append(f'%mtpGroupShowIf DEPEND %mtpGroups DEFAULT TIMES {n}')
    for i in range(n): L.append(f"WHEN  ({i + 1}) ('{q(GROUP_SHOWIF[i])}')")
    L.append(f'%mtpItems DEPEND %mtpGroups MULTI LONG TIMES {n}')
    for i, grp in enumerate(GROUPS):
        L.append(f"WHEN  ({i + 1}) ({', '.join(str(k + 1) for k in range(len(grp[4])))})")
    def it(sym, typ, key, default, fmt):
        L.append(f'{sym} DEPEND %mtpItems {typ} TIMES {n}')
        for i, grp in enumerate(GROUPS):
            L.append(f'WHEN  ({i + 1})TIMES {len(grp[4])}')
            for k, item in enumerate(grp[4]):
                L.append(f'WHEN  ({k + 1}) ({fmt(item.get(key, default))})')
    s = lambda v: f"'{q(str(v))}'"
    it('%mtpItemKind', 'DEFAULT', 'kind', 'Item', s)
    it('%mtpItemText', 'DEFAULT', 'text', '', s)
    it('%mtpItemLevel', 'LONG', 'level', 0, str)
    it('%mtpItemGlyph', 'DEFAULT', 'glyph', 'none', s)
    it('%mtpItemIcon', 'DEFAULT', 'icon', '', s)
    it('%mtpItemShortcut', 'DEFAULT', 'shortcut', '', s)
    it('%mtpItemTag', 'DEFAULT', 'tag', '', s)
    it('%mtpItemAction', 'DEFAULT', 'action', 'Embed code only', s)
    it('%mtpItemProc', 'PROCEDURE', 'proc', '', lambda v: v)
    it('%mtpItemStack', 'LONG', 'stack', 25000, str)
    it('%mtpItemParms', 'DEFAULT', 'parms', '', s)
    it('%mtpItemControl', 'DEFAULT', 'ctl', '', s)
    it('%mtpItemEvent', 'DEFAULT', 'event', 'EVENT:User', s)
    it('%mtpItemUrl', 'DEFAULT', 'url', '', s)
    it('%mtpItemWinCmd', 'DEFAULT', 'wincmd', 'Tile vertically', s)
    it('%mtpItemOpen', 'LONG', 'open', 0, str)
    it('%mtpItemDisabled', 'LONG', 'disabled', 0, str)
    it('%mtpItemHidden', 'LONG', 'hidden', 0, str)
    it('%mtpItemBold', 'LONG', 'bold', 0, str)
    it('%mtpItemShowIf', 'DEFAULT', 'showif', '', s)
    it('%mtpItemValue', 'DEFAULT', 'value', '', s)
    it('%mtpItemChart', 'DEFAULT', 'chart', 'Bars', s)
    it('%mtpItemTip', 'DEFAULT', 'tip', '', s)
    it('%mtpItemDrop', 'LONG', 'drop', 0, str)
    # hover buttons: a third level, listed only where there are some
    gs = sorted(set(g for g, i in BUTTONS))
    L.append(f'%mtpBtns DEPEND %mtpItems MULTI LONG TIMES {len(gs)}')
    for g in gs:
        its = sorted(i for gg, i in BUTTONS if gg == g)
        L.append(f'WHEN  ({g + 1})TIMES {len(its)}')
        for i in its:
            L.append(f"WHEN  ({i + 1}) ({', '.join(str(k + 1) for k in range(len(BUTTONS[(g, i)])))})")
    def bt(sym, typ, key, default, fmt):
        L.append(f'{sym} DEPEND %mtpBtns {typ} TIMES {len(gs)}')
        for g in gs:
            its = sorted(i for gg, i in BUTTONS if gg == g)
            L.append(f'WHEN  ({g + 1})TIMES {len(its)}')
            for i in its:
                L.append(f'WHEN  ({i + 1})TIMES {len(BUTTONS[(g, i)])}')
                for k, b in enumerate(BUTTONS[(g, i)]):
                    L.append(f'WHEN  ({k + 1}) ({fmt(b.get(key, default))})')
    bt('%mtpBtnGlyph', 'DEFAULT', 'glyph', 'plus', s)
    bt('%mtpBtnTip', 'DEFAULT', 'tip', '', s)
    bt('%mtpBtnTag', 'DEFAULT', 'tag', '', s)
    bt('%mtpBtnAction', 'DEFAULT', 'action', 'Embed code only', s)
    bt('%mtpBtnProc', 'PROCEDURE', 'proc', '', lambda v: v)
    bt('%mtpBtnEvent', 'DEFAULT', 'event', 'EVENT:User', s)
    it('%mtpItemEnableIf', 'DEFAULT', 'enableif', '', s)
    return L

out = []
w = out.append
w('[APPLICATION]'); w('VERSION 34'); w('PROCEDURE Main'); w('[COMMON]'); w('FROM ABC'); w('[PROMPTS]')
w('[ADDITION]'); w('NAME myTaskPanel myTaskPanelGlobal'); w('[INSTANCE]'); w('INSTANCE 1'); w('[PROMPTS]')
w('%mtpgDisable LONG  (0)')
w(f"%mtpgEngine DEFAULT  ('{ENGINE}')")
w("%mtpgTheme DEFAULT  ('Navy')")
w('%mtpgUseAccent LONG  (0)')
w('%mtpgAccent LONG  (12873749)')
w("%mtpgFont DEFAULT  ('Segoe UI')")
w('%mtpgFontSize LONG  (9)')
w('%mtpgItemH LONG  (24)')
w('%mtpgHeadH LONG  (30)')
w('%mtpgRadius LONG  (6)')
w('%mtpgAnimate LONG  (1)')
w("%mtpgLanguage DEFAULT  ('English')")
w('%mtpgRemember LONG  (1)')
w("%mtpgIniFile DEFAULT  ('TaskPanelGen.ini')")
w('%OverrideAbcSettings LONG  (0)')
w("%AbcSourceLocation DEFAULT  ('LINK')")
w("%AbcLibraryName DEFAULT  ('')")
w('[PROGRAM]'); w('[COMMON]'); w('FROM ABC ABC')
w('[MODULE]'); w("NAME 'TASKPANELGEN001.CLW'"); w('[COMMON]'); w('FROM ABC GENERATED')
w('[PROCEDURE]'); w('NAME Main'); w('[COMMON]'); w("DESCRIPTION 'myTaskPanel test frame'"); w('FROM ABC Frame'); w("CATEGORY 'Frame'")
w('[ADDITION]'); w('NAME myTaskPanel myTaskPanel'); w('[INSTANCE]'); w('INSTANCE 1'); w('[PROMPTS]')
w('%mtpDisable LONG  (0)')
w("%mtpObject DEFAULT  ('TaskPanel')")
w("%mtpTitle DEFAULT  ('Tasks')")
w("%mtpDock DEFAULT  ('Docked on the left')")
w('%mtpWidth LONG  (230)')
w('%mtpHidden LONG  (0)')
w('%mtpGrow LONG  (1)')
w('%mtpAllowFloat LONG  (1)')
w('%mtpAllowDock LONG  (1)')
w('%mtpAllowClose LONG  (1)')
w('%mtpAllowResize LONG  (1)')
w("%mtpToggleKey DEFAULT  ('F12Key')")
w("%mtpFocusKey DEFAULT  ('F6Key')")
w('%mtpSearch LONG  (1)')
out += prompts_groups()
w("%mtpPreset DEFAULT  ('Catalogs')")
w('%mtpMirror LONG  (1)')
w("%mtpMirrorMode DEFAULT  ('One group called Menu')")
w("%mtpMirrorWhere DEFAULT  ('After my groups')")
w("%mtpMirrorSkip DEFAULT  ('Window')")
w('%mtpMirrorHide LONG  (0)')
w("%mtpSubStyle DEFAULT  ('Open in place')")
w('%mtpAccordion LONG  (0)')
w('%mtpFavorites LONG  (1)')
w('%mtpRecent LONG  (5)')
w('%mtpMost LONG  (5)')
w('%mtpTips LONG  (1)')
w('%mtpRail LONG  (0)')
w('%mtpAutoHide LONG  (0)')
w('%mtpShortcuts LONG  (1)')
w("%mtpTheme DEFAULT  ('Global setting')")
# an item embed: proves the per-item embed tree resolves
w('[EMBED]'); w('EMBED %mtpItemClicked'); w('[INSTANCES]'); w("WHEN '1'"); w('[INSTANCES]'); w("WHEN '1'")
w('[DEFINITION]'); w('[SOURCE]'); w('PROPERTY:BEGIN'); w('PRIORITY 4000'); w('PROPERTY:END')
w("        0{PROP:StatusText,1} = 'Customers clicked (item embed)'")
w('[END]'); w('[END]'); w('[END]')        # [DEFINITION], two [INSTANCES]
# 'insert' on the command line clicks the New customer item once the panel is built
w('EMBED %mtpAfterBuild'); w('[DEFINITION]'); w('[SOURCE]'); w('PROPERTY:BEGIN'); w('PRIORITY 5000'); w('PROPERTY:END')
w("  IF INSTRING('insert', LOWER(COMMAND('')), 1, 1) THEN TaskPanel.Click(TaskPanel.FindTag('" + INS_TAG + "')).")
w('[END]')                                # its [DEFINITION]
w('[END]')                                # the [EMBED] section
w('[WINDOW]')
w("AppFrame APPLICATION('myTaskPanel - template test'),AT(,,520,300),STATUS(-1,200),FONT('Segoe UI',9),RESIZE,CENTER,MAX,SYSTEM,IMM")
for line in """  MENUBAR,USE(?Menubar)
    MENU('&File'),USE(?FileMenu)
      ITEM('&Print Setup...'),USE(?PrintSetup),STD(STD:PrintSetup)
      ITEM,SEPARATOR,USE(?Sep1)
      ITEM('E&xit'),USE(?Exit),STD(STD:Close)
    END
    MENU('&Browse'),USE(?BrowseMenu)
      ITEM('&Customers'),USE(?BrCustomers),KEY(CtrlU)
      ITEM('&Products'),USE(?BrProducts)
      MENU('&Geography'),USE(?GeoMenu)
        ITEM('C&ountries'),USE(?BrCountries)
        MENU('&More'),USE(?MoreMenu)
          ITEM('C&ities'),USE(?BrCities)
        END
      END
    END
    MENU('&Window'),USE(?WindowMenu),STD(STD:WindowList),LAST
      ITEM('T&ile'),USE(?Tile),STD(STD:TileWindow)
    END
    MENU('&Help'),USE(?HelpMenu)
      ITEM('&About...'),USE(?About)
    END
  END
  TOOLBAR,AT(0,0,520,18),USE(?Toolbar)
    BUTTON('Panel'),AT(4,2,40,14),USE(?BtnPanel)
  END
 END
""".splitlines():
    w(line)
w('[END]')
for name, title in (('BrowseStub', 'A browse'), ('AboutStub', 'About')):
    w('[PROCEDURE]'); w(f'NAME {name}'); w('[COMMON]'); w(f"DESCRIPTION '{title}'"); w('FROM ABC Window'); w("CATEGORY 'Window'")
    if name == 'BrowseStub':                    # records the request, the thread and MDI, then closes (the insert test)
        w('[EMBED]'); w('EMBED %WindowManagerMethodCodeSection'); w('[INSTANCES]'); w("WHEN 'Init'"); w('[INSTANCES]'); w("WHEN '(),BYTE'")
        w('[DEFINITION]'); w('[SOURCE]'); w('PROPERTY:BEGIN'); w('PRIORITY 9500'); w('PROPERTY:END')
        w("  PUTINI('insert', 'request', SELF.Request, LONGPATH() & '\InsertTest.ini')")
        w("  PUTINI('insert', 'thread', THREAD(), LONGPATH() & '\InsertTest.ini')")
        w("  PUTINI('insert', 'mdi', 0{PROP:MDI}, LONGPATH() & '\InsertTest.ini')")
        w("  POST(EVENT:CloseWindow)")
        w('[END]'); w('[END]'); w('[END]'); w('[END]')
    w('[WINDOW]')
    w(f"Window WINDOW('{title}'),AT(,,200,80),CENTER,GRAY,SYSTEM,MDI,FONT('Segoe UI',9)")
    w("       BUTTON('Close'),AT(146,58,44,14),USE(?Close),STD(STD:Close)")
    w('     END')
    w(''); w('[END]')
here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, 'TaskPanelGen.txa'), 'w', newline='\r\n', encoding='latin-1') as f:
    f.write('\n'.join(out) + '\n')
print('wrote TaskPanelGen.txa,', len(out), 'lines, engine', ENGINE)
