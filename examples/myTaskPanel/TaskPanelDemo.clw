! ============================================================================
!  TaskPanelDemo - myTaskPanel on an MDI frame, hand-coded.
!
!  This is what the myTaskPanel template generates, written out by hand. Each
!  call is marked with the embed point the template emits it at.
!
!  Command line (any order):
!    engine=dx | engine=gdi     which painter (default: DirectX in TaskPanelDemoDX, GDI in TaskPanelDemo)
!    dock=left|right|float      where the panel starts
!    theme=1..18                MTP:Slate .. MTP:Olive (the toolbar's Theme button switches it live,
!                               the open browses' panels follow)
!    sub=flyout                 submenus as pop-up menus instead of in place
!    lang=es                    Spanish captions
!    open=all|none              start with every group expanded / collapsed
!    child                      open two MDI browses at start
!    auto                       run the self-test, write TaskPanelTest.ini, exit
!    shot                       keep still for an external screenshot (no auto)
!    fx=off                     DirectX without the effects (shadows, glass, fades)
!    badge=off                  hide the engine badge
!    search=text                type text into the panel's search box (keyboard in the panel)
!    keys                       give the panel the keyboard
!    rail | autohide            start collapsed to the icon rail / tucked into the edge
!    peek                       (with rail) pop the first group out, for a screenshot
!    bench                      time both engines, write TaskPanelBench.ini, exit
!    diag                       where a DirectX frame's time goes: TaskPanelDiag.ini, exit
! ============================================================================
  PROGRAM

  INCLUDE('MyTaskPanel.INC'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

  MAP
Main          PROCEDURE
FormDemo      PROCEDURE
BrowseWin     PROCEDURE(STRING title)
AboutWin      PROCEDURE
BenchWin      PROCEDURE(BYTE auto=0)
DiagRun       PROCEDURE
DiagBest      PROCEDURE(BYTE engine, BYTE fx),STRING
Arg           PROCEDURE(STRING name),STRING
Engine        PROCEDURE(),BYTE
PickTheme     PROCEDURE(LONG cur),LONG
ThemeName     PROCEDURE(LONG theme),STRING
ApplyTheme    PROCEDURE(LONG theme)
SelfTest      PROCEDURE
    MODULE('Windows API')
d_FindWindowEx         PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,NAME('FindWindowExA')
d_GetWindowRect        PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('GetWindowRect')
d_GetClientRect        PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('GetClientRect')
d_IsWindowVisible      PROCEDURE(LONG),LONG,PASCAL,NAME('IsWindowVisible')
d_SendMessage          PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('SendMessageA')
d_GetMenu              PROCEDURE(LONG),LONG,PASCAL,NAME('GetMenu')
d_SetCursorPos         PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('SetCursorPos')
d_ClientToScreen       PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('ClientToScreen')
d_GetFocus             PROCEDURE(),LONG,PASCAL,NAME('GetFocus')
d_PostMessage          PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('PostMessageA')
d_GlobalAlloc          PROCEDURE(LONG,LONG),LONG,PASCAL,NAME('GlobalAlloc')
d_GlobalLock           PROCEDURE(LONG),LONG,PASCAL,NAME('GlobalLock')
d_GlobalUnlock         PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('GlobalUnlock')
d_MemCpy               PROCEDURE(LONG,LONG,LONG),PASCAL,NAME('RtlMoveMemory')
    END
  END

! The test build exposes what the class keeps PROTECTED.
TestPanel            CLASS(MyTaskPanelClass)
GetDockHwnd                  PROCEDURE(),LONG
GetFloatHwnd                 PROCEDURE(),LONG
RowY                   PROCEDURE(LONG id),LONG
RowCount               PROCEDURE(),LONG
ShowFlyout             PROCEDURE(LONG id)
UsingD2D               PROCEDURE(),BYTE
DragState              PROCEDURE(),LONG
HitAt                  PROCEDURE(LONG x, LONG y),LONG
DoDiag                 PROCEDURE(LONG what, LONG value),LONG,PROC
KeyRow                 PROCEDURE(),LONG
FirstRef               PROCEDURE(BYTE role),LONG
RefOf                  PROCEDURE(LONG id),LONG
GetPeekHwnd            PROCEDURE(),LONG
PeekGroup              PROCEDURE(LONG gid)
SlideNow               PROCEDURE(BYTE out)
IsUserHidden           PROCEDURE(LONG id),BYTE
GetTipHwnd             PROCEDURE(),LONG
ActX                   PROCEDURE(),LONG
GroupPos               PROCEDURE(LONG gid),LONG
                     END

TP                   TestPanel                ! %GlobalData / procedure data: the panel object
Clicks               LONG
MtT1                 LONG
DemoTheme            LONG(MTP:Slate)       ! the Theme button's pick
ThemePicked          BYTE                  ! 0 = the browses keep their own Teal
ChildThread          LONG,DIM(16)          ! browses with a panel: told when the theme changes
LastClick            STRING(120)

  CODE
  IF Arg('win') THEN FormDemo() ELSE Main().

!-----------------------------------------------------------------------------
TestPanel.GetDockHwnd PROCEDURE
  CODE
  RETURN SELF.DockHwnd
TestPanel.GetFloatHwnd PROCEDURE
  CODE
  RETURN SELF.FloatHwnd
TestPanel.ShowFlyout PROCEDURE(LONG id)
pt GROUP
PX   LONG
PY   LONG
   END
  CODE
  pt.PX = SELF.PanelWidth - 24                         ! as if the row's arrow had been clicked
  pt.PY = SELF.RowY(id)
  d_ClientToScreen(SELF.DockHwnd, ADDRESS(pt))
  d_SetCursorPos(pt.PX, pt.PY)
  SELF.FlyoutMenu(id, SELF.DockHwnd)
TestPanel.RowCount PROCEDURE
  CODE
  RETURN RECORDS(SELF.Rows)
TestPanel.UsingD2D PROCEDURE
  CODE
  RETURN SELF.EngineInUse()
TestPanel.KeyRow PROCEDURE
  CODE
  RETURN SELF.KeyId
TestPanel.FirstRef PROCEDURE(BYTE role)
i LONG
gid LONG
  CODE
  gid = SELF.RoleGid(role)
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF gid AND SELF.Items.Parent = gid AND SELF.Items.Role = 3 THEN RETURN SELF.Items.Id.
  END
  RETURN 0
TestPanel.RefOf PROCEDURE(LONG id)
  CODE
  RETURN SELF.Resolve(id)
TestPanel.GetPeekHwnd PROCEDURE
  CODE
  RETURN SELF.PeekHwnd
TestPanel.PeekGroup PROCEDURE(LONG gid)
  CODE
  SELF.ShowPeek(gid)
TestPanel.IsUserHidden PROCEDURE(LONG id)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  RETURN CHOOSE(ERRORCODE() = 0 AND SELF.Items.UserHidden, 1, 0)
TestPanel.GetTipHwnd PROCEDURE
  CODE
  RETURN SELF.TipHwnd
TestPanel.ActX PROCEDURE                               ! the middle of a row's only hover button
r GROUP
X1  LONG
Y1  LONG
X2  LONG
Y2  LONG
  END
  CODE
  d_GetClientRect(SELF.DockHwnd, ADDRESS(r))
  RETURN SELF.Px(8) + (r.X2 - CHOOSE(SELF.ContentH > SELF.ViewH, SELF.Px(8), 0) - SELF.Px(16)) - SELF.Px(8) - SELF.Px(11)
TestPanel.GroupPos PROCEDURE(LONG gid)
k LONG
  CODE
  LOOP k = 1 TO 50
    IF SELF.GroupAt(k) = gid THEN RETURN k.
    IF ~SELF.GroupAt(k) THEN BREAK.
  END
  RETURN 0
TestPanel.SlideNow PROCEDURE(BYTE out)
  CODE
  SELF.Slide = out
  SELF.SlideTo = out
  SELF.PlaceDocked()
TestPanel.DoDiag PROCEDURE(LONG what, LONG value)
  CODE
  RETURN SELF.Diag(what, value)
TestPanel.DragState PROCEDURE
  CODE
  RETURN SELF.Drag
TestPanel.HitAt PROCEDURE(LONG x, LONG y)
  CODE
  RETURN SELF.HitTest(x, y, 0)
TestPanel.RowY PROCEDURE(LONG id)
i LONG
  CODE
  LOOP i = 1 TO RECORDS(SELF.Rows)
    GET(SELF.Rows, i)
    IF SELF.Rows.Id = id THEN RETURN SELF.Rows.Y + SELF.Rows.H / 2.
  END
  RETURN -1

!  The DirectX build (compiled with _MTP_D2D_) draws with DirectX unless told
!  engine=gdi; the Clarion build always draws with GDI.
Engine PROCEDURE
  CODE
  IF Arg('engine') = 'gdi' THEN RETURN MTP:Clarion.
  IF Arg('engine') = 'dx' THEN RETURN MTP:DirectX.
  COMPILE('ENDD2D',_MTP_D2D_)
  RETURN MTP:DirectX
  ! ENDD2D
  RETURN MTP:Clarion

Arg PROCEDURE(STRING name)
c   STRING(1024)
p   LONG
e   LONG
  CODE
  c = ' ' & LOWER(COMMAND('')) & ' '
  p = INSTRING(' ' & LOWER(name) & '=', c, 1, 1)
  IF p
    p += LEN(CLIP(name)) + 2
    e = INSTRING(' ', c, 1, p)
    RETURN SUB(c, p, e - p)
  END
  IF INSTRING(' ' & LOWER(name) & ' ', c, 1, 1) THEN RETURN '1'.
  RETURN ''

!-----------------------------------------------------------------------------
Main PROCEDURE
gCat   LONG
gRep   LONG
gExp   LONG
gHelp  LONG
geo    LONG
more   LONG
fin    LONG
i      LONG
gToday LONG

AppFrame APPLICATION('myTaskPanel demo'),AT(,,560,340),CENTER,MASK,SYSTEM,MAX,STATUS(-1,160), |
           FONT('Segoe UI',9),RESIZE,IMM,ICON(ICON:Application)
       MENUBAR,USE(?Menubar)
         MENU('&File'),USE(?FileMenu)
           ITEM('&Print Setup...'),USE(?PrintSetup),STD(STD:PrintSetup)
           ITEM,SEPARATOR
           ITEM('E&xit'),USE(?Exit),STD(STD:Close)
         END
         MENU('&Browse'),USE(?BrowseMenu)
           ITEM('&Customers'),USE(?BrCustomers),KEY(CtrlU)
           ITEM('&Products'),USE(?BrProducts),KEY(CtrlP)
           MENU('&Geography'),USE(?GeoMenu)
             ITEM('C&ountries'),USE(?BrCountries)
             ITEM('&States'),USE(?BrStates)
             MENU('&More'),USE(?MoreMenu)
               ITEM('C&ities'),USE(?BrCities)
               ITEM('&Zip codes'),USE(?BrZip)
             END
           END
         END
         MENU('&Reports'),USE(?RepMenu)
           ITEM('Sales by &month'),USE(?RepSales)
           ITEM('&Inventory'),USE(?RepInv),DISABLE
         END
         MENU('&Window'),USE(?WinMenu),STD(STD:WindowList),LAST
           ITEM('T&ile'),USE(?Tile),STD(STD:TileWindow)
           ITEM('&Cascade'),USE(?Cascade),STD(STD:CascadeWindow)
         END
         MENU('&Help'),USE(?HelpMenu)
           ITEM('&About...'),USE(?About)
         END
       END
       TOOLBAR,AT(0,0,560,18),USE(?Toolbar)
         BUTTON('Panel'),AT(4,2,40,14),USE(?BtnToggle),TIP('Show / hide the task panel')
         BUTTON('Left'),AT(48,2,44,14),USE(?BtnLeft)
         BUTTON('Right'),AT(94,2,44,14),USE(?BtnRight)
         BUTTON('Float'),AT(140,2,44,14),USE(?BtnFloat)
         BUTTON('Effects'),AT(192,2,44,14),USE(?BtnFx),TIP('DirectX: effects on / off')
         BUTTON('Speed test'),AT(238,2,52,14),USE(?BtnBench),TIP('Time both engines')
         BUTTON('Icons'),AT(296,2,40,14),USE(?BtnRail),TIP('Collapse the panel to a strip of group icons')
         BUTTON('Auto-hide'),AT(338,2,48,14),USE(?BtnAuto),TIP('Tuck the panel into the edge')
         BUTTON('Customize'),AT(388,2,52,14),USE(?BtnCustom),TIP('Hide items, reorder groups')
         BUTTON('Theme'),AT(442,2,44,14),USE(?BtnTheme),TIP('Pick the panel''s colours')
       END
     END

  CODE
  OPEN(AppFrame)
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      ! ---- %WindowManagerMethodCodeSection 'TakeWindowEvent' / OpenWindow ----
      IF Arg('lang') = 'es' THEN DO Spanish.          ! the frame's own menu too: it is copied below
      TP.Init(AppFrame, Engine())
      TP.Title = CHOOSE(Arg('lang') = 'es', 'Tareas', 'Tasks')
      IF Arg('lang') = 'es' THEN TP.SetLanguage('ES').
      IF Arg('theme') THEN DemoTheme = Arg('theme').
      TP.SetTheme(DemoTheme)
      IF Arg('sub') = 'flyout' THEN TP.SubStyle = MTP:Flyout.
      CASE Arg('dock')
      OF 'right' ; TP.DockSide = MTP:Right
      OF 'float' ; TP.DockSide = MTP:Float
      END
      TP.IniFile = ''                                  ! the template sets the INI when "remember" is on
      IF Arg('fx') = 'off' THEN TP.Effects = 0.
      TP.ShowEngine = CHOOSE(Arg('badge') = 'off', 0, 1)

      ! a group the developer built (template: Groups list)
      gCat = TP.AddGroup(CHOOSE(Arg('lang') = 'es', 'Cat<225>logos', 'Catalogs'), 'table', 1, 1)
      TP.AddItem(gCat, CHOOSE(Arg('lang') = 'es', 'Clientes', 'Customers'), 'user', 'cust')
      TP.AddItem(gCat, CHOOSE(Arg('lang') = 'es', 'Productos', 'Products'), 'box', 'prod')
      TP.AddItem(gCat, CHOOSE(Arg('lang') = 'es', 'Proveedores', 'Suppliers'), 'truck', 'supp')
      geo = TP.AddItem(gCat, CHOOSE(Arg('lang') = 'es', 'Geograf<237>a', 'Geography'), 'globe')
      TP.AddItem(geo, CHOOSE(Arg('lang') = 'es', 'Pa<237>ses', 'Countries'), , 'countries')
      TP.AddItem(geo, CHOOSE(Arg('lang') = 'es', 'Estados', 'States'), , 'states')
      more = TP.AddItem(geo, CHOOSE(Arg('lang') = 'es', 'M<225>s', 'More'))
      TP.AddItem(more, CHOOSE(Arg('lang') = 'es', 'Ciudades', 'Cities'), , 'cities')
      TP.AddItem(more, CHOOSE(Arg('lang') = 'es', 'C<243>digos postales', 'Zip codes'), , 'zip')
      TP.Expand(geo)
      ! descriptions (a card after a pause), hover buttons, a drop target (template: the item's Extras tab)
      TP.SetTip(TP.FindTag('cust'), CHOOSE(Arg('lang') = 'es', 'Consultar, agregar y cambiar clientes. Suelte archivos aqu<237> para adjuntarlos.', 'Browse, add and change customers. Drop files here to attach them.'))
      TP.SetTip(TP.FindTag('prod'), CHOOSE(Arg('lang') = 'es', 'Lista de precios, existencias y proveedores de cada producto.', 'Price list, stock and suppliers of every product.'))
      TP.AddAction(TP.FindTag('cust'), 'plus', 'cust_new', CHOOSE(Arg('lang') = 'es', 'Nuevo cliente', 'New customer'))
      TP.AddAction(TP.FindTag('cust'), 'print', 'cust_print', CHOOSE(Arg('lang') = 'es', 'Imprimir la lista', 'Print the list'))
      TP.SetDropTarget(TP.FindTag('cust'))
      TP.SetBadge(TP.FindTag('cust'), '12')            ! badges: a count, a word, a dot
      TP.SetBadge(TP.FindTag('supp'), '*', COLOR:Red)
      TP.SetBadge(gCat, '3')

      ! info cards: a value, a bar, two charts (template: item kinds Info / Progress / Chart)
      gToday = TP.AddGroup(CHOOSE(Arg('lang') = 'es', 'Hoy', 'Today'), 'calendar')
      TP.AddInfo(gToday, CHOOSE(Arg('lang') = 'es', 'Pedidos', 'Orders'), '34')
      TP.AddInfo(gToday, CHOOSE(Arg('lang') = 'es', 'Ventas', 'Sales'), '$12,400')
      TP.AddProgress(gToday, CHOOSE(Arg('lang') = 'es', 'Meta del mes', 'Monthly target'), 64)
      TP.AddChart(gToday, CHOOSE(Arg('lang') = 'es', 'Ventas, 12 semanas', 'Sales, 12 weeks'), '12,15,9,18,22,17,25,21,28,24,31,35', MTP:Bars)
      TP.AddChart(gToday, CHOOSE(Arg('lang') = 'es', 'Visitas, 14 d<237>as', 'Visits, 14 days'), '40,42,38,51,47,55,60,58,49,62,70,66,74,81', MTP:Line)

      gExp = TP.AddGroup(CHOOSE(Arg('lang') = 'es', 'Exportar', 'Exports'), 'export')
      TP.AddItem(gExp, 'Excel (.xlsx)', 'excel', 'x_xlsx')
      TP.AddItem(gExp, 'CSV', 'csv', 'x_csv')
      TP.AddItem(gExp, 'PDF', 'pdf', 'x_pdf')
      TP.AddItem(gExp, 'HTML', 'html', 'x_html')
      TP.AddSeparator(gExp)
      TP.AddItem(gExp, 'XML', 'xml', 'x_xml')
      TP.AddItem(gExp, 'JSON', 'json', 'x_json')
      TP.SetBadge(TP.FindTag('x_xlsx'), CHOOSE(Arg('lang') = 'es', 'nuevo', 'new'), 0308A2Dh)

      gRep = TP.AddGroup(CHOOSE(Arg('lang') = 'es', 'Informes', 'Reports'), 'report')
      TP.AddItem(gRep, CHOOSE(Arg('lang') = 'es', 'Ventas por mes', 'Sales by month'), 'chart', 'r_sales')
      TP.SetTip(TP.FindTag('r_sales'), CHOOSE(Arg('lang') = 'es', 'Ventas de cada mes de los <250>ltimos dos a<241>os, por regi<243>n.', 'Sales for every month of the last two years, by region.'))
      TP.AddAction(TP.FindTag('r_sales'), 'excel', 'r_sales_xls', CHOOSE(Arg('lang') = 'es', 'Exportar a Excel', 'Export to Excel'))
      fin = TP.AddItem(gRep, CHOOSE(Arg('lang') = 'es', 'Financieros', 'Financial'), 'money')
      TP.AddItem(fin, CHOOSE(Arg('lang') = 'es', 'Balance general', 'Balance sheet'), , 'r_bal')
      TP.AddItem(fin, CHOOSE(Arg('lang') = 'es', 'Estado de resultados', 'Income statement'), , 'r_inc')
      TP.AddLabel(gRep, CHOOSE(Arg('lang') = 'es', 'Recientes', 'Recent'))
      TP.AddItem(gRep, CHOOSE(Arg('lang') = 'es', 'Clientes inactivos', 'Inactive customers'), 'doc', 'r_inact')

      gHelp = TP.AddGroup(CHOOSE(Arg('lang') = 'es', 'Ayuda', 'Help'), 'help', 0)
      TP.AddItem(gHelp, CHOOSE(Arg('lang') = 'es', 'Sitio web', 'Website'), 'globe', 'web')
      TP.AddItem(gHelp, CHOOSE(Arg('lang') = 'es', 'Enviar un correo', 'Email support'), 'mail', 'mail')
      TP.AddItem(gHelp, CHOOSE(Arg('lang') = 'es', 'Acerca de...', 'About...'), 'info', 'about')

      ! the frame's own menu, copied in (template: "Copy the system menu")
      TP.MirrorMenu(0, CHOOSE(Arg('lang') = 'es', 'Ventana', 'Window'), 1)

      IF ~Arg('auto')                                  ! two favourites (users add their own with a right-click)
        TP.AddFavorite(TP.FindTag('r_sales'))
        TP.AddFavorite(TP.FindTag('x_pdf'))
      END
      IF Arg('rail') THEN TP.Rail = 1.
      IF Arg('autohide') THEN TP.AutoHide = 1.
      IF Arg('open') = 'all' THEN TP.ExpandAll(1).
      IF Arg('open') = 'none' THEN TP.ExpandAll(0).
      IF Arg('open') = 'today'                         ! only the info cards open
        TP.ExpandAll(0)
        TP.Expand(gToday)
      END
      IF Arg('open') = 'first'
        TP.ExpandAll(0)
        TP.Expand(gCat)
      END
      IF Arg('open') = 'menu'                          ! only the copied menu, opened down to Zip codes
        TP.ExpandAll(0)
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Men<250>', 'Menu'), 0))
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Consultas', 'Browse'), 0))
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Consultas', 'Browse')))
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Geograf<237>a', 'Geography'), TP.FindText(CHOOSE(Arg('lang') = 'es', 'Consultas', 'Browse'))))
        TP.Expand(TP.FindText(CHOOSE(Arg('lang') = 'es', 'M<225>s', 'More'), TP.FindText(CHOOSE(Arg('lang') = 'es', 'Geograf<237>a', 'Geography'), TP.FindText(CHOOSE(Arg('lang') = 'es', 'Consultas', 'Browse')))))
      END
      TP.ShowPanel()
      AppFrame{PROP:StatusText, 2} = CHOOSE(Arg('lang') = 'es', 'Motor: ', 'Engine: ') & CHOOSE(TP.UsingD2D() = MTP:DirectX, 'DirectX', 'Clarion (GDI)')
      IF Arg('search')                                 ! the keyboard in the panel, a search typed
        TP.Focus()
        TP.SetSearch(Arg('search'))
      END
      IF Arg('keys') THEN TP.Focus().                  ! the keyboard in the panel, no search
      IF Arg('peek') THEN TP.PeekGroup(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Hoy', 'Today'), 0)).
      IF Arg('hidden') THEN TP.HideItem(TP.FindTag('supp')).   ! as a user would have hidden it
      IF Arg('custom')                                 ! the panel's edit mode, Suppliers hidden
        TP.HideItem(TP.FindTag('supp'))
        TP.Customize()
      END
      IF Arg('flyout') THEN 0{PROP:Timer} = 60.          ! open a submenu as a pop-up, for a screenshot
      IF Arg('mt')                                     ! three child panels on three threads
        MtT1 = START(BrowseWin, 25000, 'Customers')
        START(BrowseWin, 25000, 'Products')
        START(BrowseWin, 25000, 'Suppliers')
        0{PROP:Timer} = 150
      END
      IF Arg('child')
        START(BrowseWin, 25000, CHOOSE(Arg('lang') = 'es', 'Clientes', 'Customers'))
        START(BrowseWin, 25000, CHOOSE(Arg('lang') = 'es', 'Productos', 'Products'))
      END
      IF Arg('auto') THEN POST(EVENT:User + 1).
      IF Arg('bench') THEN POST(EVENT:User + 2).
      IF Arg('diag') THEN POST(EVENT:User + 3).
    OF EVENT:User + 2
      BenchWin(1)
      POST(EVENT:CloseWindow)
    OF EVENT:User + 3
      DiagRun()
      POST(EVENT:CloseWindow)
    OF EVENT:User + 1
      SelfTest()                                       ! ends by clicking "Customers"
    OF EVENT:Timer                                     ! auto: the posted clicks have had time
      IF Arg('mt') AND MtT1                            ! close one child: its Kill must not hurt the others
        POST(EVENT:CloseWindow, , MtT1)
        MtT1 = 0
        0{PROP:Timer} = 0
        TP.Expand(TP.FindText('Exports', 0), 0)      ! and make the frame's panel repaint afterwards
      END
      IF Arg('flyout')
        0{PROP:Timer} = 0
        TP.ShowFlyout(TP.FindText(CHOOSE(Arg('lang') = 'es', 'Geograf<237>a', 'Geography'), 0 + TP.FindText(CHOOSE(Arg('lang') = 'es', 'Cat<225>logos', 'Catalogs'), 0)))
      END
      IF Arg('auto')
        0{PROP:Timer} = 0
        IF GETINI('t6', 'result', '', LONGPATH() & '\TaskPanelTest.ini') = ''
          PUTINI('t6', 'result', 'FAIL: no MTP:Event', LONGPATH() & '\TaskPanelTest.ini')
        END
        IF GETINI('t10', 'result', '', LONGPATH() & '\TaskPanelTest.ini') = ''
          PUTINI('t10', 'result', 'FAIL: the menu ITEM was not accepted', LONGPATH() & '\TaskPanelTest.ini')
        END
        IF GETINI('t16', 'clicked', '', LONGPATH() & '\TaskPanelTest.ini') = '' AND SUB(GETINI('t16', 'result', '', LONGPATH() & '\TaskPanelTest.ini'), 1, 4) = 'pass'
          PUTINI('t16', 'result', 'FAIL: the Favourites row did not click x_csv', LONGPATH() & '\TaskPanelTest.ini')
        END
        IF GETINI('t23', 'result', '', LONGPATH() & '\TaskPanelTest.ini') = ''
          PUTINI('t23', 'result', 'FAIL: the hover button raised nothing', LONGPATH() & '\TaskPanelTest.ini')
        END
        IF GETINI('t25', 'result', '', LONGPATH() & '\TaskPanelTest.ini') = ''
          PUTINI('t25', 'result', 'FAIL: no MTP:Drop', LONGPATH() & '\TaskPanelTest.ini')
        END
        IF GETINI('t13', 'result', '', LONGPATH() & '\TaskPanelTest.ini') = ''
          PUTINI('t13', 'result', 'FAIL: typing json + Enter ran nothing (search "' & TP.GetSearch() & '")', LONGPATH() & '\TaskPanelTest.ini')
        END
        POST(EVENT:CloseWindow)
      END
    OF MTP:Drop                                        ! files dropped on Customers
      LOOP WHILE TP.NextDrop()
        IF Arg('auto')
          PUTINI('t25', 'result', CHOOSE(TP.DropTag = 'cust' AND TP.DropCount = 2 AND TP.DropFile(2) = 'C:\b.pdf', 'pass: 2 files dropped on Customers arrived: ' & CLIP(TP.DropFiles), 'FAIL tag=' & TP.DropTag & ' n=' & TP.DropCount & ' 2nd=' & TP.DropFile(2)), LONGPATH() & '\TaskPanelTest.ini')
          CYCLE
        END
        AppFrame{PROP:StatusText, 1} = TP.DropCount & CHOOSE(Arg('lang') = 'es', ' archivo(s) en ', ' file(s) dropped on ') & CLIP(TP.DropText) & ': ' & TP.DropFile(1)
      END
    OF MTP:Event
      ! ---- the template: TakeWindowEvent, CASE on the item's tag ----
      LOOP WHILE TP.NextClick()
        Clicks += 1
        IF Arg('auto')
          IF TP.ClickTag = 'x_csv'                     ! t16: clicked on its Favourites row
            PUTINI('t16', 'clicked', 'x_csv', LONGPATH() & '\TaskPanelTest.ini')
          ELSIF TP.ClickTag = 'cust_new'               ! t23: the hover button
            PUTINI('t23', 'result', CHOOSE(TP.ClickAct <> 0 AND TP.ClickId = TP.FindTag('cust'), 'pass: the + button on Customers arrived as cust_new (row: Customers)', 'FAIL: ClickAct=' & TP.ClickAct), LONGPATH() & '\TaskPanelTest.ini')
          ELSIF TP.ClickTag = 'x_json'                 ! t13: typed "json" + Enter, through the ACCEPT loop
            PUTINI('t13', 'result', CHOOSE(d_GetFocus() <> TP.GetDockHwnd(), 'pass: typed json + Enter ran x_json, keyboard given back', 'FAIL: ran x_json but kept the keyboard'), LONGPATH() & '\TaskPanelTest.ini')
          ELSIF TP.ClickTag = 'cust'
            PUTINI('t6', 'result', 'pass: real click arrived as tag cust', LONGPATH() & '\TaskPanelTest.ini')
          END
          CYCLE
        END
        LastClick = TP.ClickTag
        AppFrame{PROP:StatusText, 1} = 'Clicked: ' & CLIP(TP.ClickText) & '  [' & CLIP(TP.ClickTag) & ']'
        CASE TP.ClickTag
        OF 'cust'    ; START(BrowseWin, 25000, 'Customers')
        OF 'prod'    ; START(BrowseWin, 25000, 'Products')
        OF 'supp'    ; START(BrowseWin, 25000, 'Suppliers')
        OF 'web'     ; TP.OpenUrl('https://github.com/robertorenz')
        OF 'about'   ; START(AboutWin, 25000)
        END
      END
    END
    CASE ACCEPTED()
    OF ?BrCustomers ; START(BrowseWin, 25000, 'Customers') ; LastClick = 'menu:customers'
    OF ?BrProducts  ; START(BrowseWin, 25000, 'Products')  ; LastClick = 'menu:products'
    OF ?BrCountries
      IF Arg('auto')
        PUTINI('t10', 'result', 'pass: the mirrored row POSTed EVENT:Accepted to ?BrCountries', LONGPATH() & '\TaskPanelTest.ini')
      ELSE
        START(BrowseWin, 25000, 'Countries')
      END
    OF ?BrStates    ; START(BrowseWin, 25000, 'States')    ; LastClick = 'menu:states'
    OF ?BrCities    ; START(BrowseWin, 25000, 'Cities')    ; LastClick = 'menu:cities'
    OF ?BrZip       ; START(BrowseWin, 25000, 'Zip codes') ; LastClick = 'menu:zip'
    OF ?RepSales    ; LastClick = 'menu:sales'
    OF ?About       ; START(AboutWin, 25000)
    OF ?BtnToggle   ; TP.TogglePanel()
    OF ?BtnLeft     ; TP.Dock(MTP:Left)
    OF ?BtnRight    ; TP.Dock(MTP:Right)
    OF ?BtnFloat    ; TP.Dock(MTP:Float)
    OF ?BtnFx       ; TP.Effects = 1 - TP.Effects ; TP.Refresh()
    OF ?BtnBench    ; BenchWin()
    OF ?BtnRail     ; TP.SetRail(1 - TP.Rail)
    OF ?BtnAuto     ; TP.SetAutoHide(1 - TP.AutoHide)
    OF ?BtnCustom   ; TP.Customize(1 - TP.IsCustomizing())
    OF ?BtnTheme
      i = PickTheme(DemoTheme)
      IF i
        TP.SetTheme(i)
        ApplyTheme(i)
        AppFrame{PROP:StatusText, 1} = CHOOSE(Arg('lang') = 'es', 'Tema: ', 'Theme: ') & ThemeName(i)
      END
    END
  END
  TP.Kill()                                             ! %WindowManagerMethodCodeSection 'Kill'

Spanish ROUTINE
  AppFrame{PROP:Text} = 'Demostraci<243>n de myTaskPanel'
  ?FileMenu{PROP:Text} = '&Archivo'
  ?PrintSetup{PROP:Text} = '&Configurar impresora...'
  ?Exit{PROP:Text} = '&Salir'
  ?BrowseMenu{PROP:Text} = '&Consultas'
  ?BrCustomers{PROP:Text} = '&Clientes'
  ?BrProducts{PROP:Text} = '&Productos'
  ?GeoMenu{PROP:Text} = '&Geograf<237>a'
  ?BrCountries{PROP:Text} = '&Pa<237>ses'
  ?BrStates{PROP:Text} = '&Estados'
  ?MoreMenu{PROP:Text} = '&M<225>s'
  ?BrCities{PROP:Text} = 'C&iudades'
  ?BrZip{PROP:Text} = 'C<243>digos &postales'
  ?RepMenu{PROP:Text} = '&Informes'
  ?RepSales{PROP:Text} = 'Ventas por &mes'
  ?RepInv{PROP:Text} = '&Inventario'
  ?WinMenu{PROP:Text} = '&Ventana'
  ?Tile{PROP:Text} = '&Mosaico'
  ?Cascade{PROP:Text} = '&Cascada'
  ?HelpMenu{PROP:Text} = 'A&yuda'
  ?About{PROP:Text} = '&Acerca de...'
  ?BtnToggle{PROP:Text} = 'Panel'
  ?BtnLeft{PROP:Text} = 'Izquierda'
  ?BtnRight{PROP:Text} = 'Derecha'
  ?BtnFloat{PROP:Text} = 'Flotante'
  ?BtnFx{PROP:Text} = 'Efectos'
  ?BtnBench{PROP:Text} = 'Velocidad'
  ?BtnRail{PROP:Text} = 'Iconos'
  ?BtnAuto{PROP:Text} = 'Ocultar'
  ?BtnCustom{PROP:Text} = 'Personalizar'
  ?BtnTheme{PROP:Text} = 'Tema'
  ?BtnTheme{PROP:Tip} = 'Elegir los colores del panel'

!-----------------------------------------------------------------------------
!  The self-test: real Win32 mouse messages at the panel, and the geometry of
!  the MDI client checked against the panel's width.
!-----------------------------------------------------------------------------
SelfTest PROCEDURE
ini     STRING(260)
mdi     LONG
cls     CSTRING('MDIClient')
r       GROUP
X1        LONG
Y1        LONG
X2        LONG
Y2        LONG
        END
rp      LIKE(r)
cr      LIKE(r)
fails   LONG
n       LONG
y       LONG
id      LONG
before  LONG
dragAfterDown LONG
gCat    LONG
k1      LONG
k2      LONG
k3      LONG
o1      BYTE
x       LONG
hd      LONG
pd      LONG
drop    STRING(20)
df      GROUP                                          ! DROPFILES
pFiles    LONG
X         LONG
Y         LONG
fNC       LONG
fWide     LONG
        END
  CODE
  ini = LONGPATH() & '\TaskPanelTest.ini'
  REMOVE(ini)
  fails = 0
  mdi = d_FindWindowEx(0{PROP:Handle}, 0, ADDRESS(cls), 0)

  ! 1. the panel exists and is docked left, the MDI client starts after it
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  PUTINI('t1', 'panel', rp.X1 & ',' & rp.Y1 & ',' & rp.X2 & ',' & rp.Y2, ini)
  PUTINI('t1', 'mdi', r.X1 & ',' & r.Y1 & ',' & r.X2 & ',' & r.Y2, ini)
  IF d_IsWindowVisible(TP.GetDockHwnd()) AND r.X1 >= rp.X2 - 1 AND rp.X2 - rp.X1 = TP.PanelWidth
    PUTINI('t1', 'result', 'pass: docked left, MDI client narrowed', ini)
  ELSE
    PUTINI('t1', 'result', 'FAIL', ini)
    fails += 1
  END

  ! 2. dock right
  TP.Dock(MTP:Right)
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF rp.X1 >= r.X2 - 1 AND rp.X2 - rp.X1 = TP.PanelWidth
    PUTINI('t2', 'result', 'pass: docked right', ini)
  ELSE
    PUTINI('t2', 'result', 'FAIL ' & rp.X1 & ' vs ' & r.X2, ini)
    fails += 1
  END

  ! 3. float: the MDI client gets its full width back
  d_GetClientRect(0{PROP:Handle}, ADDRESS(cr))
  TP.Dock(MTP:Float)
  d_GetWindowRect(mdi, ADDRESS(r))
  IF d_IsWindowVisible(TP.GetFloatHwnd()) AND ~d_IsWindowVisible(TP.GetDockHwnd()) AND r.X2 - r.X1 >= cr.X2 - 2
    PUTINI('t3', 'result', 'pass: floating, MDI client full width (' & r.X2 - r.X1 & ')', ini)
  ELSE
    PUTINI('t3', 'result', 'FAIL width ' & r.X2 - r.X1 & ' of ' & cr.X2, ini)
    fails += 1
  END

  ! 4. back to the left, resized
  TP.Dock(MTP:Left)
  TP.SetWidth(300)
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF rp.X2 - rp.X1 = 300 AND r.X1 >= rp.X2 - 1
    PUTINI('t4', 'result', 'pass: width 300, MDI client follows', ini)
  ELSE
    PUTINI('t4', 'result', 'FAIL', ini)
    fails += 1
  END

  ! 5. the mirrored menu arrived, nested
  n = TP.FindText('Zip codes')
  IF TP.FindText('Browse') AND n AND TP.FindText('Geography') AND ~TP.FindText('Window')
    PUTINI('t5', 'result', 'pass: menu mirrored with 3 levels, Window skipped (' & TP.ItemCount() & ' items)', ini)
  ELSE
    PUTINI('t5', 'result', 'FAIL', ini)
    fails += 1
  END

  ! 6. a real click on "Customers": WM_LBUTTONDOWN/UP at its row
  DISPLAY()
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)               ! lay out
  id = TP.FindTag('cust')
  y = TP.RowY(id)
  before = Clicks
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + 60)
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, y * 65536 + 60)
  PUTINI('t6', 'row y', y, ini)

  ! 7. a group header click collapses it (the Customers click is still queued)
  id = TP.FindText('Exports', 0)
  y = TP.RowY(id)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + 60)
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, y * 65536 + 60)
  IF ~TP.IsExpanded(id)
    PUTINI('t7', 'result', 'pass: header click collapsed Exports', ini)
  ELSE
    PUTINI('t7', 'result', 'FAIL y=' & y, ini)
    fails += 1
  END

  ! 9. drag the splitter 60 pixels wider
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  before = TP.PanelWidth
  d_SetCursorPos(rp.X2 - 2, rp.Y1 + 200)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, 200 * 65536 + (rp.X2 - rp.X1 - 2))
  dragAfterDown = TP.DragState()
  d_SetCursorPos(rp.X2 + 58, rp.Y1 + 200)
  d_SendMessage(TP.GetDockHwnd(), 0200h, 1, 200 * 65536 + (rp.X2 - rp.X1 + 58))
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, 200 * 65536 + (rp.X2 - rp.X1 + 58))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF TP.PanelWidth = before + 60 AND r.X1 >= rp.X1 + TP.PanelWidth - 1
    PUTINI('t9', 'result', 'pass: splitter drag ' & before & ' -> ' & TP.PanelWidth & ', MDI client follows', ini)
  ELSE
    PUTINI('t9', 'result', 'FAIL ' & before & ' -> ' & TP.PanelWidth & ' (drag after button-down: ' & dragAfterDown & ', hit at the edge: ' & TP.HitAt(rp.X2 - rp.X1 - 2, 200) & ')', ini)
    fails += 1
  END

  ! 11. drag the title into the MDI area: it floats
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_SetCursorPos(rp.X1 + 40, rp.Y1 + 15)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, 15 * 65536 + 40)
  d_SetCursorPos(rp.X2 + 300, rp.Y1 + 200)
  d_SendMessage(TP.GetDockHwnd(), 0200h, 1, 200 * 65536 + 300)
  IF d_IsWindowVisible(TP.GetFloatHwnd()) AND ~d_IsWindowVisible(TP.GetDockHwnd()) AND TP.DockSide = MTP:Float
    PUTINI('t11', 'result', 'pass: dragging the title undocked it', ini)
  ELSE
    PUTINI('t11', 'result', 'FAIL', ini)
    fails += 1
  END

  ! 12. let go of the floating panel at the right edge: it docks there
  d_GetWindowRect(mdi, ADDRESS(r))
  d_SetCursorPos(r.X2 - 12, (r.Y1 + r.Y2) / 2)
  d_SendMessage(TP.GetFloatHwnd(), 0232h, 0, 0)        ! WM_EXITSIZEMOVE
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF TP.DockSide = MTP:Right AND d_IsWindowVisible(TP.GetDockHwnd()) AND rp.X1 >= r.X2 - 1
    PUTINI('t12', 'result', 'pass: dropped at the right edge, docked right', ini)
  ELSE
    PUTINI('t12', 'result', 'FAIL side=' & TP.DockSide, ini)
    fails += 1
  END
  TP.Dock(MTP:Left)

  ! 10. click a mirrored menu row (Browse > Geography > Countries)
  TP.Animate = 0
  TP.ExpandAll(0)
  TP.Expand(TP.FindText('Menu', 0))
  TP.Expand(TP.FindText('Browse'))
  TP.Expand(TP.FindText('Geography', TP.FindText('Browse')))
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)
  id = TP.FindText('Countries', TP.FindText('Geography', TP.FindText('Browse')))
  y = TP.RowY(id)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + 80)
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, y * 65536 + 80)
  PUTINI('t10', 'row y', y, ini)

  ! 14. the keyboard: Focus, Home, Enter opens, Down, Left out, Left closes
  TP.ClearRecent()                                     ! the clicks above filled Recent, which sits first
  TP.ExpandAll(0)
  TP.Focus()
  gCat = TP.FindText('Catalogs', 0)
  d_SendMessage(TP.GetDockHwnd(), 0100h, 24h, 0)        ! Home
  k1 = TP.KeyRow()
  d_SendMessage(TP.GetDockHwnd(), 0100h, 0Dh, 0)        ! Enter: opens Catalogs
  o1 = TP.IsExpanded(gCat)
  d_SendMessage(TP.GetDockHwnd(), 0100h, 28h, 0)        ! Down: Customers
  k2 = TP.KeyRow()
  d_SendMessage(TP.GetDockHwnd(), 0100h, 25h, 0)        ! Left: back to the group
  k3 = TP.KeyRow()
  d_SendMessage(TP.GetDockHwnd(), 0100h, 25h, 0)        ! Left: closes it
  IF d_GetFocus() = TP.GetDockHwnd() AND k1 = gCat AND o1 AND k2 = TP.FindTag('cust') AND k3 = gCat AND ~TP.IsExpanded(gCat)
    PUTINI('t14', 'result', 'pass: focus taken; Home, Enter opened, Down, Left out, Left closed', ini)
  ELSE
    PUTINI('t14', 'result', 'FAIL focus=' & CHOOSE(d_GetFocus() = TP.GetDockHwnd(), 'yes', 'no') & ' k1=' & k1 & '/' & gCat & ' open=' & o1 & ' k2=' & k2 & ' k3=' & k3, ini)
    fails += 1
  END

  ! 15. search: rows filtered to the matches, the keyboard on the first
  TP.SetSearch('cou')
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)
  n = TP.RowCount()
  IF TP.RowY(TP.FindText('Countries', TP.FindText('Geography', TP.FindText('Browse')))) > 0 AND TP.KeyRow() <> 0 AND n <= 4
    PUTINI('t15', 'result', 'pass: "cou" leaves ' & n & ' rows, Countries among them, keyboard on a match', ini)
  ELSE
    PUTINI('t15', 'result', 'FAIL rows=' & n & ' key=' & TP.KeyRow(), ini)
    fails += 1
  END
  TP.SetSearch('')

  ! 16. favourites: a row that stands for x_csv, and clicking it clicks x_csv
  TP.AddFavorite(TP.FindTag('x_csv'))
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)
  id = TP.FirstRef(1)
  y = TP.RowY(id)
  IF TP.IsFavorite(TP.FindTag('x_csv')) AND id AND TP.RefOf(id) = TP.FindTag('x_csv') AND y > 0
    d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + 80)
    d_SendMessage(TP.GetDockHwnd(), 0202h, 0, y * 65536 + 80)
    PUTINI('t16', 'result', 'pass: Favourites row for x_csv at y=' & y & ', clicked (tag checked on MTP:Event)', ini)
  ELSE
    PUTINI('t16', 'result', 'FAIL fav=' & TP.IsFavorite(TP.FindTag('x_csv')) & ' ref=' & id & ' y=' & y, ini)
    fails += 1
  END

  ! 17. recent: that click put x_csv first in Recent
  IF TP.RefOf(TP.FirstRef(2)) = TP.FindTag('x_csv')
    PUTINI('t17', 'result', 'pass: the click put x_csv at the top of Recent', ini)
  ELSE
    PUTINI('t17', 'result', 'FAIL first recent=' & TP.RefOf(TP.FirstRef(2)), ini)
    fails += 1
  END
  TP.RemoveFavorite(TP.FindTag('x_csv'))
  TP.ClearRecent()

  ! 18. the rail: the panel is a strip, the MDI client follows, a group pops out
  TP.SetRail(1)
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  TP.PeekGroup(TP.FindText('Catalogs', 0))
  IF rp.X2 - rp.X1 = 44 AND r.X1 >= rp.X2 - 1 AND d_IsWindowVisible(TP.GetPeekHwnd())
    PUTINI('t18', 'result', 'pass: rail 44 px, MDI client starts after it, Catalogs popped out', ini)
  ELSE
    PUTINI('t18', 'result', 'FAIL rail=' & rp.X2 - rp.X1 & ' mdi.x1=' & r.X1 & ' dock.x2=' & rp.X2 & ' peek=' & d_IsWindowVisible(TP.GetPeekHwnd()), ini)
    fails += 1
  END
  TP.SetRail(0)
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  IF rp.X2 - rp.X1 <> TP.PanelWidth OR d_IsWindowVisible(TP.GetPeekHwnd())
    PUTINI('t18', 'result', 'FAIL back: width ' & rp.X2 - rp.X1 & ' peek=' & d_IsWindowVisible(TP.GetPeekHwnd()), ini)
    fails += 1
  END

  ! 19. auto-hide: tucked, the host loses 6 px; out, the panel lies over the host
  TP.SetAutoHide(1)
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  cr.X1 = r.X1                                         ! where the MDI client starts, tucked
  cr.X2 = rp.X2                                        ! where the panel ends, tucked
  TP.SlideNow(1)
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF cr.X2 = cr.X1 AND rp.X2 > r.X1 + 100 AND r.X1 = cr.X1
    PUTINI('t19', 'result', 'pass: tucked, the MDI client starts at the 6 px strip; out, the panel covers ' & rp.X2 - r.X1 & ' px of it', ini)
  ELSE
    PUTINI('t19', 'result', 'FAIL tucked panel end=' & cr.X2 & ' mdi=' & cr.X1 & '; out panel end=' & rp.X2 & ' mdi=' & r.X1, ini)
    fails += 1
  END
  TP.SetAutoHide(0)
  d_GetWindowRect(TP.GetDockHwnd(), ADDRESS(rp))
  d_GetWindowRect(mdi, ADDRESS(r))
  IF r.X1 < rp.X2 - 1
    PUTINI('t19', 'result', 'FAIL back: MDI client at ' & r.X1 & ', panel ends ' & rp.X2, ini)
    fails += 1
  END

  ! 20. Customize: a click hides Products, Done takes it away, Reset brings it back
  TP.ExpandAll(1)
  TP.Customize(1)
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)
  id = TP.FindTag('prod')
  y = TP.RowY(id)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + 80)
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, y * 65536 + 80)
  k1 = TP.IsUserHidden(id)
  k2 = TP.RowY(id)                                     ! still shown (faded) while customizing
  TP.Customize(0)
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)
  k3 = TP.RowY(id)
  TP.ResetCustom()
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)
  IF k1 AND k2 > 0 AND k3 = -1 AND TP.RowY(id) > 0
    PUTINI('t20', 'result', 'pass: Customize click hid Products (shown faded), Done removed it, Reset brought it back', ini)
  ELSE
    PUTINI('t20', 'result', 'FAIL hidden=' & k1 & ' y while customizing=' & k2 & ' after=' & k3 & ' reset=' & TP.RowY(id), ini)
    fails += 1
  END

  ! 21. drag the Exports header above Catalogs
  TP.ExpandAll(0)
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)
  gCat = TP.FindText('Catalogs', 0)
  k1 = TP.FindText('Exports', 0)
  y = TP.RowY(k1)
  k2 = TP.RowY(gCat) - 8
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + 60)
  d_SendMessage(TP.GetDockHwnd(), 0200h, 1, k2 * 65536 + 60)
  d_SendMessage(TP.GetDockHwnd(), 0200h, 1, k2 * 65536 + 60)
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, k2 * 65536 + 60)
  IF TP.GroupPos(k1) < TP.GroupPos(gCat) AND TP.GroupPos(k1) > 0
    PUTINI('t21', 'result', 'pass: Exports dragged above Catalogs (positions ' & TP.GroupPos(k1) & ', ' & TP.GroupPos(gCat) & ')', ini)
  ELSE
    PUTINI('t21', 'result', 'FAIL Exports at ' & TP.GroupPos(k1) & ', Catalogs at ' & TP.GroupPos(gCat), ini)
    fails += 1
  END
  TP.ResetCustom()

  ! 22. Most used: PDF run three times
  TP.Click(TP.FindTag('x_pdf'))
  TP.Click(TP.FindTag('x_pdf'))
  TP.Click(TP.FindTag('x_pdf'))
  IF TP.RefOf(TP.FirstRef(4)) = TP.FindTag('x_pdf')
    PUTINI('t22', 'result', 'pass: PDF, run three times, heads Most used', ini)
  ELSE
    PUTINI('t22', 'result', 'FAIL first most used=' & TP.RefOf(TP.FirstRef(4)), ini)
    fails += 1
  END

  ! 23. the + hover button on Customers (checked on MTP:Event)
  TP.ExpandAll(1)
  d_SendMessage(TP.GetDockHwnd(), 000Fh, 0, 0)
  y = TP.RowY(TP.FindTag('cust'))
  x = TP.ActX() - 22                                    ! the first of its two buttons
  d_SendMessage(TP.GetDockHwnd(), 0200h, 0, y * 65536 + x)
  d_SendMessage(TP.GetDockHwnd(), 0201h, 1, y * 65536 + x)
  d_SendMessage(TP.GetDockHwnd(), 0202h, 0, y * 65536 + x)

  ! 24. the description card: a pause on Customers shows it, moving away hides it
  d_SendMessage(TP.GetDockHwnd(), 0200h, 0, y * 65536 + 80)
  d_SendMessage(TP.GetDockHwnd(), 0113h, 8, 0)         ! the pause is over
  k1 = d_IsWindowVisible(TP.GetTipHwnd())
  d_SendMessage(TP.GetDockHwnd(), 0200h, 0, (y + 24) * 65536 + 80)
  IF k1 AND ~d_IsWindowVisible(TP.GetTipHwnd())
    PUTINI('t24', 'result', 'pass: the card showed after the pause and went with the mouse', ini)
  ELSE
    PUTINI('t24', 'result', 'FAIL shown=' & k1 & ' still=' & d_IsWindowVisible(TP.GetTipHwnd()), ini)
    fails += 1
  END

  ! 25. two files dropped on Customers: a real HDROP (DROPFILES + the names), checked on MTP:Drop
  drop = 'C:\a.txt<0>C:\b.pdf<0><0>'
  hd = d_GlobalAlloc(0042h, 20 + 20)                   ! GMEM_MOVEABLE | GMEM_ZEROINIT
  pd = d_GlobalLock(hd)
  df.pFiles = 20
  df.X = 80
  df.Y = y
  d_MemCpy(pd, ADDRESS(df), 20)
  d_MemCpy(pd + 20, ADDRESS(drop), 20)
  d_GlobalUnlock(hd)
  d_SendMessage(TP.GetDockHwnd(), 0233h, hd, 0)

  ! 13. type "json" + Enter, POSTED, so they go through the ACCEPT loop (checked on MTP:Event)
  TP.Focus()
  d_PostMessage(TP.GetDockHwnd(), 0102h, VAL('j'), 0)
  d_PostMessage(TP.GetDockHwnd(), 0102h, VAL('s'), 0)
  d_PostMessage(TP.GetDockHwnd(), 0102h, VAL('o'), 0)
  d_PostMessage(TP.GetDockHwnd(), 0102h, VAL('n'), 0)
  d_PostMessage(TP.GetDockHwnd(), 0100h, 0Dh, 0)

  ! 8. engine
  PUTINI('t8', 'engine', CHOOSE(TP.UsingD2D() = MTP:DirectX, 'DirectX', 'Clarion'), ini)
  PUTINI('summary', 'fails', fails, ini)
  PUTINI('summary', 'rows', TP.RowCount(), ini)
  0{PROP:Timer} = 300                                  ! watchdog for t6

!-----------------------------------------------------------------------------
!  The panel on an ordinary WINDOW: the window's client area is narrowed and
!  the window grows by the panel's width, so the form keeps its room.
!-----------------------------------------------------------------------------
FormDemo PROCEDURE
FP      TestPanel
g       LONG
ini     STRING(260)
wr      GROUP
X1        LONG
Y1        LONG
X2        LONG
Y2        LONG
        END
er      LIKE(wr)
wr2     LIKE(wr)
er2     LIKE(wr)
CusName STRING(40)
CusCity STRING(30)
win     WINDOW('Customer'),AT(,,260,120),CENTER,SYSTEM,FONT('Segoe UI',9),GRAY,RESIZE
          PROMPT('&Name:'),AT(10,12),USE(?NamePrompt)
          ENTRY(@s40),AT(60,10,180,12),USE(CusName)
          PROMPT('&City:'),AT(10,32),USE(?CityPrompt)
          ENTRY(@s30),AT(60,30,180,12),USE(CusCity)
          BUTTON('&Theme'),AT(10,96,44,14),USE(?Theme),TIP('Pick the panel''s colours')
          BUTTON('&OK'),AT(150,96,44,14),USE(?OK),DEFAULT
          BUTTON('&Cancel'),AT(198,96,44,14),USE(?Cancel),STD(STD:Close)
        END
  CODE
  OPEN(win)
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      d_GetWindowRect(0{PROP:Handle}, ADDRESS(wr))
      d_GetWindowRect(?CusName{PROP:Handle}, ADDRESS(er))
      FP.Init(win, Engine())
      FP.Title = 'Customer'
      FP.PanelWidth = 190
      IF Arg('theme') THEN DemoTheme = Arg('theme').
      FP.SetTheme(DemoTheme)
      g = FP.AddGroup('Record', 'doc', 1, 1)
      FP.AddItem(g, 'Save', 'plus', 'save', ?OK)       ! an item pointed at a BUTTON
      FP.AddItem(g, 'Print', 'print', 'print')
      FP.AddItem(g, 'Email', 'mail', 'mail')
      g = FP.AddGroup('Related', 'link')
      FP.AddItem(g, 'Invoices', 'money', 'inv')
      FP.AddItem(g, 'Orders', 'cart', 'ord')
      FP.ShowPanel()
      IF Arg('auto')
        ini = LONGPATH() & '\TaskPanelWinTest.ini'
        REMOVE(ini)
        d_GetWindowRect(0{PROP:Handle}, ADDRESS(wr2))
        d_GetWindowRect(?CusName{PROP:Handle}, ADDRESS(er2))
        PUTINI('w1', 'window', (wr.X2 - wr.X1) & ' -> ' & (wr2.X2 - wr2.X1), ini)
        PUTINI('w1', 'entry x', er.X1 & ' -> ' & er2.X1, ini)
        IF (wr2.X2 - wr2.X1) - (wr.X2 - wr.X1) = 190 AND er2.X1 - er.X1 = 190
          PUTINI('w1', 'result', 'pass: window grew by 190, the form moved right by 190', ini)
        ELSE
          PUTINI('w1', 'result', 'FAIL', ini)
        END
        FP.Dock(MTP:Float)
        d_GetWindowRect(0{PROP:Handle}, ADDRESS(wr2))
        d_GetWindowRect(?CusName{PROP:Handle}, ADDRESS(er2))
        IF wr2.X2 - wr2.X1 = wr.X2 - wr.X1 AND er2.X1 = er.X1
          PUTINI('w2', 'result', 'pass: floating gives the window its size and layout back', ini)
        ELSE
          PUTINI('w2', 'result', 'FAIL ' & (wr2.X2 - wr2.X1) & ' ' & er2.X1, ini)
        END
        FP.Dock(MTP:Right)
        d_GetWindowRect(?CusName{PROP:Handle}, ADDRESS(er2))
        d_GetWindowRect(FP.GetDockHwnd(), ADDRESS(wr2))
        IF er2.X1 = er.X1 AND wr2.X1 > er2.X2
          PUTINI('w3', 'result', 'pass: docked right, the form stays put', ini)
        ELSE
          PUTINI('w3', 'result', 'FAIL', ini)
        END
        POST(EVENT:CloseWindow)
      END
    OF MTP:Event
      LOOP WHILE FP.NextClick()
        0{PROP:Text} = 'Customer - ' & FP.ClickText
      END
    END
    CASE ACCEPTED()
    OF ?Theme
      g = PickTheme(DemoTheme)
      IF g THEN FP.SetTheme(g) ; DemoTheme = g.
    OF ?OK
      0{PROP:Text} = 'Customer - saved'
    END
  END
  FP.Kill()

!-----------------------------------------------------------------------------
!  The Theme button: a pop-up of the eighteen themes in three groups, the
!  current one ticked. Returns the theme picked, or 0 when it was dismissed.
!-----------------------------------------------------------------------------
PickTheme PROCEDURE(LONG cur)
Order  BYTE,DIM(18)                             ! menu position -> theme (separators are not counted)
m      STRING(700)
n      LONG
  CODE
  Order[1] = MTP:Slate     ; Order[2] = MTP:Navy     ; Order[3] = MTP:Graphite
  Order[4] = MTP:Teal      ; Order[5] = MTP:Light    ; Order[6] = MTP:Forest
  Order[7] = MTP:Ocean     ; Order[8] = MTP:Crimson  ; Order[9] = MTP:Amber
  Order[10] = MTP:Copper   ; Order[11] = MTP:Sky     ; Order[12] = MTP:Mint
  Order[13] = MTP:Steel    ; Order[14] = MTP:Sand    ; Order[15] = MTP:Midnight
  Order[16] = MTP:Olive    ; Order[17] = MTP:HighContrast ; Order[18] = MTP:LowContrast
  LOOP n = 1 TO 18
    IF n > 1 THEN m = CLIP(m) & '|'.
    IF n = 7 OR n = 17 THEN m = CLIP(m) & '-|'.
    m = CLIP(m) & CHOOSE(Order[n] = cur, '+', '-') & ThemeName(Order[n])
  END
  n = POPUP(m)
  RETURN CHOOSE(n = 0, 0, Order[n])

ThemeName PROCEDURE(LONG theme)
  CODE
  IF Arg('lang') = 'es'
    RETURN CHOOSE(theme, 'Pizarra', 'Marino', 'Grafito (oscuro)', 'Verde azulado', 'Claro', 'Bosque', |
                  'Alto contraste', 'Bajo contraste', 'Oc<233>ano', 'Carmes<237>', '<193>mbar', 'Cobre', |
                  'Cielo', 'Menta', 'Acero', 'Arena', 'Medianoche (oscuro)', 'Oliva', '')
  END
  RETURN CHOOSE(theme, 'Slate', 'Navy', 'Graphite (dark)', 'Teal', 'Light', 'Forest', |
                'High contrast', 'Low contrast', 'Ocean', 'Crimson', 'Amber', 'Copper', |
                'Sky', 'Mint', 'Steel', 'Sand', 'Midnight (dark)', 'Olive', '')

ApplyTheme PROCEDURE(LONG theme)               ! remember it and tell every open browse
i      LONG
  CODE
  DemoTheme = theme
  ThemePicked = 1
  LOOP i = 1 TO MAXIMUM(ChildThread, 1)
    IF ChildThread[i] THEN POST(EVENT:User + 5, , ChildThread[i]).
  END

!-----------------------------------------------------------------------------
BrowseWin PROCEDURE(STRING title)
CP     MyTaskPanelClass                         ! a panel on this MDI child's own thread
cg     LONG
Q      QUEUE
Name     STRING(40)
City     STRING(30)
       END
i      LONG
win    WINDOW('Browse'),AT(,,300,170),MDI,SYSTEM,RESIZE,FONT('Segoe UI',9),MAX
         LIST,AT(6,6,288,138),USE(?List),FULL,VSCROLL,FROM(Q),FORMAT('140L(2)|M~Name~@s40@120L(2)~City~@s30@')
         BUTTON('&Close'),AT(250,150,44,14),USE(?Close),STD(STD:Close)
       END
  CODE
  LOOP i = 1 TO 40
    Q.Name = CLIP(title) & ' ' & i
    Q.City = CHOOSE(i - INT(i / 4) * 4 + 1, 'Monterrey', 'Guadalajara', 'Austin', 'Madrid')
    ADD(Q)
  END
  OPEN(win)
  win{PROP:Text} = title
  IF Arg('lang') = 'es'
    ?List{PROPLIST:Header, 1} = 'Nombre'
    ?List{PROPLIST:Header, 2} = 'Ciudad'
    ?Close{PROP:Text} = '&Cerrar'
  END
  IF Arg('childpanel') OR Arg('mt')
    CP.Init(win, Engine())
    CP.Title = title
    CP.PanelWidth = 170
    CP.SetTheme(CHOOSE(ThemePicked = 0, MTP:Teal, DemoTheme))
    cg = CP.AddGroup('Record', 'doc', 1, 1)
    CP.AddItem(cg, 'Insert', 'plus')
    CP.AddItem(cg, 'Change', 'doc')
    CP.AddItem(cg, 'Print', 'print')
    CP.ShowPanel()
    LOOP i = 1 TO MAXIMUM(ChildThread, 1)          ! so the frame's Theme button reaches this panel
      IF ChildThread[i] = 0 THEN ChildThread[i] = THREAD() ; BREAK.
    END
  END
  ACCEPT
    CASE EVENT()
    OF MTP:Event
      LOOP WHILE CP.NextClick()
      END
    OF EVENT:User + 5                                  ! the frame picked a theme
      CP.SetTheme(DemoTheme)
    END
  END
  LOOP i = 1 TO MAXIMUM(ChildThread, 1)
    IF ChildThread[i] = THREAD() THEN ChildThread[i] = 0.
  END
  CP.Kill()

AboutWin PROCEDURE
win    WINDOW('About'),AT(,,200,80),CENTER,MDI,SYSTEM,FONT('Segoe UI',9)
         STRING('myTaskPanel demo'),AT(10,10),FONT(,12,,FONT:bold)
         STRING('Task panels for Clarion - Clarion and DirectX engines.'),AT(10,30)
         BUTTON('OK'),AT(150,58,40,14),USE(?OK),STD(STD:Close),DEFAULT
       END
  CODE
  OPEN(win)
  ACCEPT
  END

!-----------------------------------------------------------------------------
!  Times the frame's panel with each engine (TP.Benchmark: off screen, the
!  panel's own size and contents). Three rounds, alternating, best of each,
!  so a busy moment on the machine does not decide the result.
BenchWin PROCEDURE(BYTE auto=0)
es     BYTE
r      LONG
ms     REAL,DIM(3)
v      REAL
best   BYTE
lab    STRING(40),DIM(3)
txt    STRING(90),DIM(3)
L1     STRING(90)
L2     STRING(90)
L3     STRING(90)
L4     STRING(120)
L5     STRING(120)
Frames EQUATE(300)
win    WINDOW('Speed test'),AT(,,300,112),CENTER,SYSTEM,FONT('Segoe UI',9),GRAY
         STRING(@s90),AT(10,10,280,10),USE(L1)
         STRING(@s90),AT(10,22,280,10),USE(L2)
         STRING(@s90),AT(10,34,280,10),USE(L3)
         STRING(@s120),AT(10,52,280,10),USE(L4),FONT(,,,FONT:bold)
         STRING(@s120),AT(10,66,280,10),USE(L5)
         BUTTON('OK'),AT(250,90,40,14),USE(?OK),STD(STD:Close),DEFAULT
       END
  CODE
  es = CHOOSE(Arg('lang') = 'es', 1, 0)
  lab[1] = CHOOSE(es = 1, 'Clarion (GDI)', 'Clarion (GDI)')
  lab[2] = CHOOSE(es = 1, 'DirectX sin efectos', 'DirectX, no effects')
  lab[3] = CHOOSE(es = 1, 'DirectX con efectos', 'DirectX with effects')
  ms[1] = 999999 ; ms[2] = 999999 ; ms[3] = 999999
  SETCURSOR(CURSOR:Wait)
  LOOP r = 1 TO 3
    v = TP.Benchmark(MTP:Clarion, Frames)
    IF v < ms[1] THEN ms[1] = v.
    v = TP.Benchmark(MTP:DirectX, Frames, 0)
    IF v < ms[2] THEN ms[2] = v.
    v = TP.Benchmark(MTP:DirectX, Frames, 1)
    IF v < ms[3] THEN ms[3] = v.
  END
  SETCURSOR()
  LOOP r = 1 TO 3
    IF ms[r] < 0
      txt[r] = CLIP(lab[r]) & ':  ' & CHOOSE(es = 1, 'no disponible', 'not available')
    ELSE
      txt[r] = CLIP(lab[r]) & ':  ' & LEFT(FORMAT(ms[r], @n8.3)) & CHOOSE(es = 1, ' ms por cuadro  (', ' ms per frame  (') & INT(1000 / ms[r]) & CHOOSE(es = 1, ' cuadros/s)', ' frames/s)')
    END
  END
  L1 = txt[1]
  L2 = txt[2]
  L3 = txt[3]
  IF ms[2] < 0
    L4 = CHOOSE(es = 1, 'DirectX no est<225> compilado en esta versi<243>n (TaskPanelDemoDX.exe lo trae).', 'DirectX is not compiled into this build (TaskPanelDemoDX.exe has it).')
  ELSE
    best = 1
    IF ms[2] < ms[best] THEN best = 2.
    IF ms[3] < ms[best] THEN best = 3.
    L4 = CHOOSE(es = 1, 'M<225>s r<225>pido: ', 'Fastest: ') & CLIP(lab[best])
    L5 = CHOOSE(es = 1, 'GDI vs DirectX con efectos: ', 'GDI vs DirectX with effects: ') & LEFT(FORMAT(ms[3] / ms[1], @n6.2)) & CHOOSE(es = 1, ' veces el tiempo de GDI', 'x the GDI time')
  END
  IF auto
    PUTINI('bench', 'gdi',      ms[1], LONGPATH() & '\TaskPanelBench.ini')
    PUTINI('bench', 'dx',       ms[2], LONGPATH() & '\TaskPanelBench.ini')
    PUTINI('bench', 'dxfx',     ms[3], LONGPATH() & '\TaskPanelBench.ini')
    PUTINI('bench', 'engine',   TP.UsingD2D(), LONGPATH() & '\TaskPanelBench.ini')
    PUTINI('bench', 'frames',   Frames, LONGPATH() & '\TaskPanelBench.ini')
    RETURN
  END
  OPEN(win)
  IF es
    0{PROP:Text} = 'Prueba de velocidad'
  END
  ACCEPT
  END

!-----------------------------------------------------------------------------
!  diag: where a DirectX frame's time goes. For each Direct2D target type
!  (let it choose / software / hardware): an empty frame (the fixed cost of
!  begin + end), then full frames with the gradient brush cache off and on,
!  with and without the effects. GDI's empty and full frames for comparison.
!  Best of three rounds, 300 frames a round. ms per frame in TaskPanelDiag.ini.
DiagRun PROCEDURE
ini    STRING(260)
t      LONG
  CODE
  ini = LONGPATH() & '\TaskPanelDiag.ini'
  REMOVE(ini)
  TP.DoDiag(3, 1)
  PUTINI('gdi', 'empty', DiagBest(MTP:Clarion, 1), ini)
  TP.DoDiag(3, 0)
  PUTINI('gdi', 'full', DiagBest(MTP:Clarion, 1), ini)
  LOOP t = 0 TO 2
    TP.DoDiag(1, t)
    TP.DoDiag(3, 1)
    PUTINI('type' & t, 'empty', DiagBest(MTP:DirectX, 0), ini)
    TP.DoDiag(3, 0)
    TP.DoDiag(2, 0)
    PUTINI('type' & t, 'flat, no cache', DiagBest(MTP:DirectX, 0), ini)
    PUTINI('type' & t, 'fx, no cache', DiagBest(MTP:DirectX, 1), ini)
    TP.DoDiag(2, 1)
    PUTINI('type' & t, 'flat, cache', DiagBest(MTP:DirectX, 0), ini)
    PUTINI('type' & t, 'fx, cache', DiagBest(MTP:DirectX, 1), ini)
  END
  TP.DoDiag(1, 0)

DiagBest PROCEDURE(BYTE engine, BYTE fx)
r      LONG
v      REAL
b      REAL
  CODE
  b = 999999
  LOOP r = 1 TO 3
    v = TP.Benchmark(engine, 300, fx)
    IF v < b THEN b = v.
  END
  RETURN FORMAT(b, @n8.3)
