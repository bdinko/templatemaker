! ============================================================================
!  MyTaskPanelClass - implementation. See MyTaskPanel.inc for the API.
!
!  The panel is a real Win32 window, created and driven from Clarion:
!  MTP_WndProc below is a Clarion procedure that Windows calls directly
!  (the same technique as Clarion's own smartzoom.clw). It runs on the
!  host window's thread, inside that thread's ACCEPT loop, so it only
!  paints, tracks the mouse and queues clicks - a click is handed to the
!  Clarion code by POSTing MTP:Event, never run from inside the callback.
!
!  Making room on the host: the host's own child windows (the MDIClient of
!  a frame, the ClaChildClient of a window) are subclassed and every
!  WM_WINDOWPOSCHANGING is corrected in flight - the host keeps laying them
!  out against the full client area, we take the panel's width off the
!  side. The rect the host asked for is remembered, so applying a change is
!  just replaying that rect through the same hook. (Measured and explained
!  in ClaCommandBar's commandbar.cpp; this is the same idea in Clarion.)
!
!  The painter has two back ends. GDI is plain Clarion calling the Windows
!  API. Direct2D is mtpd2d.c, and is only compiled in when the project
!  defines _MTP_D2D_=>1; without it every COMPILE block below vanishes and
!  this module contains no C at all.
!
!  This file MUST be stored in ANSI with CRLF line endings.
! ============================================================================
  MEMBER

  INCLUDE('MyTaskPanel.INC'),ONCE

  COMPILE('ENDD2D',_MTP_D2D_)
  PRAGMA('compile(mtpd2d.c)')
  ! ENDD2D

  MAP
    MODULE('Windows API')
mtp_RegisterClass      PROCEDURE(LONG pWc),LONG,PASCAL,PROC,NAME('RegisterClassA')
mtp_CreateWindowEx     PROCEDURE(LONG exSt, LONG pCls, LONG pTitle, LONG st, LONG x, LONG y, LONG w, LONG h, LONG pid, LONG menu, LONG inst, LONG prm),LONG,PASCAL,NAME('CreateWindowExA')
mtp_DestroyWindow      PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('DestroyWindow')
mtp_DefWindowProc      PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,NAME('DefWindowProcA')
mtp_CallWindowProc     PROCEDURE(LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,NAME('CallWindowProcA')
mtp_SetWindowLong      PROCEDURE(LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('SetWindowLongA')
mtp_GetWindowLong      PROCEDURE(LONG,LONG),LONG,PASCAL,NAME('GetWindowLongA')
mtp_SetWindowPos       PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('SetWindowPos')
mtp_ShowWindow         PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('ShowWindow')
mtp_IsWindow           PROCEDURE(LONG),LONG,PASCAL,NAME('IsWindow')
mtp_IsWindowVisible    PROCEDURE(LONG),LONG,PASCAL,NAME('IsWindowVisible')
mtp_GetClientRect      PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('GetClientRect')
mtp_GetWindowRect      PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('GetWindowRect')
mtp_ScreenToClient     PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('ScreenToClient')
mtp_ClientToScreen     PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('ClientToScreen')
mtp_GetCursorPos       PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('GetCursorPos')
mtp_GetAsyncKeyState   PROCEDURE(LONG),SHORT,PASCAL,NAME('GetAsyncKeyState')
mtp_InvalidateRect     PROCEDURE(LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('InvalidateRect')
mtp_BeginPaint         PROCEDURE(LONG,LONG),LONG,PASCAL,NAME('BeginPaint')
mtp_EndPaint           PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('EndPaint')
mtp_GetDC              PROCEDURE(LONG),LONG,PASCAL,NAME('GetDC')
mtp_ReleaseDC          PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('ReleaseDC')
mtp_SetCapture         PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('SetCapture')
mtp_ReleaseCapture     PROCEDURE(),LONG,PASCAL,PROC,NAME('ReleaseCapture')
mtp_SetCursor          PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('SetCursor')
mtp_LoadCursor         PROCEDURE(LONG,LONG),LONG,PASCAL,NAME('LoadCursorA')
mtp_SetTimer           PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('SetTimer')
mtp_KillTimer          PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('KillTimer')
mtp_PostMessage        PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('PostMessageA')
mtp_SendMessage        PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('SendMessageA')
mtp_FindWindowEx       PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,NAME('FindWindowExA')
mtp_GetWindow          PROCEDURE(LONG,LONG),LONG,PASCAL,NAME('GetWindow')
mtp_GetAncestor        PROCEDURE(LONG,LONG),LONG,PASCAL,NAME('GetAncestor')
mtp_GetMenu            PROCEDURE(LONG),LONG,PASCAL,NAME('GetMenu')
mtp_SetMenu            PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('SetMenu')
mtp_DrawMenuBar        PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('DrawMenuBar')
mtp_CreatePopupMenu    PROCEDURE(),LONG,PASCAL,NAME('CreatePopupMenu')
mtp_AppendMenu         PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('AppendMenuA')
mtp_TrackPopupMenu     PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,NAME('TrackPopupMenu')
mtp_DestroyMenu        PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('DestroyMenu')
mtp_DrawIconEx         PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('DrawIconEx')
mtp_DestroyIcon        PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('DestroyIcon')
mtp_LoadImage          PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,NAME('LoadImageA')
mtp_FillRect           PROCEDURE(LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('FillRect')
mtp_DrawText           PROCEDURE(LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('DrawTextA')
mtp_SetWindowText      PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('SetWindowTextA')
mtp_GetSysColor        PROCEDURE(LONG),LONG,PASCAL,NAME('GetSysColor')
mtp_ShellExecute       PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('ShellExecuteA')
mtp_GetModuleHandle    PROCEDURE(LONG),LONG,PASCAL,NAME('GetModuleHandleA')
mtp_MemCpy             PROCEDURE(LONG,LONG,LONG),PASCAL,NAME('RtlMoveMemory')
mtp_CreateCompatibleDC PROCEDURE(LONG),LONG,PASCAL,NAME('CreateCompatibleDC')
mtp_CreateCompatibleBitmap PROCEDURE(LONG,LONG,LONG),LONG,PASCAL,NAME('CreateCompatibleBitmap')
mtp_SelectObject       PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('SelectObject')
mtp_DeleteObject       PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('DeleteObject')
mtp_DeleteDC           PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('DeleteDC')
mtp_BitBlt             PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('BitBlt')
mtp_CreateSolidBrush   PROCEDURE(LONG),LONG,PASCAL,NAME('CreateSolidBrush')
mtp_CreatePen          PROCEDURE(LONG,LONG,LONG),LONG,PASCAL,NAME('CreatePen')
mtp_GetStockObject     PROCEDURE(LONG),LONG,PASCAL,NAME('GetStockObject')
mtp_RoundRect          PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('RoundRect')
mtp_Ellipse            PROCEDURE(LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('Ellipse')
mtp_MoveToEx           PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('MoveToEx')
mtp_LineTo             PROCEDURE(LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('LineTo')
mtp_SetBkMode          PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('SetBkMode')
mtp_SetTextColor       PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('SetTextColor')
mtp_CreateFont         PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,NAME('CreateFontA')
mtp_GetDeviceCaps      PROCEDURE(LONG,LONG),LONG,PASCAL,NAME('GetDeviceCaps')
mtp_SaveDC             PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('SaveDC')
mtp_RestoreDC          PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('RestoreDC')
mtp_IntersectClipRect  PROCEDURE(LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('IntersectClipRect')
mtp_CreateRoundRectRgn PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG),LONG,PASCAL,NAME('CreateRoundRectRgn')
mtp_ExtSelectClipRgn   PROCEDURE(LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('ExtSelectClipRgn')
mtp_SetLayeredAttr     PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('SetLayeredWindowAttributes')
mtp_QPCounter          PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('QueryPerformanceCounter')
mtp_QPFrequency        PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('QueryPerformanceFrequency')
mtp_GetFocus           PROCEDURE(),LONG,PASCAL,NAME('GetFocus')
mtp_SetFocus           PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('SetFocus')
mtp_GetTextExtent      PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('GetTextExtentPoint32A')
mtp_DragAcceptFiles    PROCEDURE(LONG,LONG),PASCAL,NAME('DragAcceptFiles')
mtp_DragQueryFile      PROCEDURE(LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('DragQueryFileA')
mtp_DragQueryPoint     PROCEDURE(LONG,LONG),LONG,PASCAL,PROC,NAME('DragQueryPoint')
mtp_DragFinish         PROCEDURE(LONG),PASCAL,NAME('DragFinish')
    END
    COMPILE('ENDD2D',_MTP_D2D_)
    MODULE('mtpd2d.c')
mtp_d2_init            PROCEDURE(),LONG,PROC,NAME('_mtpd2d_init')
mtp_d2_begin           PROCEDURE(LONG,LONG,LONG),LONG,NAME('_mtpd2d_begin')
mtp_d2_end             PROCEDURE(),LONG,PROC,NAME('_mtpd2d_end')
mtp_d2_fill            PROCEDURE(REAL,REAL,REAL,REAL,LONG),NAME('_mtpd2d_fill')
mtp_d2_round           PROCEDURE(REAL,REAL,REAL,REAL,REAL,LONG,LONG,REAL),NAME('_mtpd2d_round')
mtp_d2_grad            PROCEDURE(REAL,REAL,REAL,REAL,REAL,LONG,LONG),NAME('_mtpd2d_grad')
mtp_d2_line            PROCEDURE(REAL,REAL,REAL,REAL,LONG,REAL),NAME('_mtpd2d_line')
mtp_d2_ellipse         PROCEDURE(REAL,REAL,REAL,REAL,LONG,LONG,REAL),NAME('_mtpd2d_ellipse')
mtp_d2_text            PROCEDURE(LONG,REAL,REAL,REAL,REAL,LONG,LONG,REAL,LONG,LONG),NAME('_mtpd2d_text')
mtp_d2_clip            PROCEDURE(REAL,REAL,REAL,REAL),NAME('_mtpd2d_clip')
mtp_d2_unclip          PROCEDURE(),NAME('_mtpd2d_unclip')
mtp_d2_kill            PROCEDURE(),NAME('_mtpd2d_kill')
mtp_d2_shadow          PROCEDURE(REAL,REAL,REAL,REAL,REAL,REAL,REAL,LONG),NAME('_mtpd2d_shadow')
mtp_d2_diag            PROCEDURE(LONG,LONG),LONG,PROC,NAME('_mtpd2d_diag')
    END
    ! ENDD2D
MTP_WndProc            PROCEDURE(LONG hWnd, LONG uMsg, LONG wParam, LONG lParam),LONG,PASCAL
MTP_KidProc            PROCEDURE(LONG hWnd, LONG uMsg, LONG wParam, LONG lParam),LONG,PASCAL
MTP_Hex                PROCEDURE(LONG rrggbb),LONG              ! 0RRGGBBh -> Clarion COLOR
MTP_Signed16           PROCEDURE(LONG v),LONG
  END

! ---- module data ----
MTP_Map              QUEUE,PRE(MTPM),THREAD   ! hwnd -> object, for the callbacks
Hwnd                   LONG
Kind                   BYTE                   ! 1 our panel, 2 a host child, 3 orphaned host child
OldProc                LONG
Obj                    &MyTaskPanelClass
                     END
MTP_ClassName        CSTRING('MyTaskPanel.Pane')
MTP_MdiClass         CSTRING('MDIClient')
MTP_Registered       BYTE
MTP_PeekClass        CSTRING('MyTaskPanel.Peek')  ! the rail's pop-out: same procedure, a drop shadow
MTP_PeekReg          BYTE

MTP_Rect             GROUP,TYPE
X1                     LONG
Y1                     LONG
X2                     LONG
Y2                     LONG
                     END

MTP_WndPos           GROUP,TYPE               ! WINDOWPOS
wHwnd                  LONG
wAfter                 LONG
wX                     LONG
wY                     LONG
wCX                    LONG
wCY                    LONG
wFlags                 LONG
                     END

! window styles and messages
MTP:WS_CHILD         EQUATE(040000000h)
MTP:WS_CLIPSIBLINGS  EQUATE(004000000h)
MTP:WS_CLIPCHILDREN  EQUATE(002000000h)
MTP:WS_CAPTION       EQUATE(000C00000h)
MTP:WS_SYSMENU       EQUATE(000080000h)
MTP:WS_THICKFRAME    EQUATE(000040000h)
MTP:WS_POPUP         EQUATE(-2147483648)      ! 80000000h
MTP:WS_EX_TOOLWINDOW EQUATE(00080h)
MTP:WS_EX_LAYERED    EQUATE(080000h)

MTP_Large            GROUP,TYPE               ! LARGE_INTEGER
Lo                     ULONG
Hi                     LONG
                     END
MTP:SWP_Replay       EQUATE(00114h)           ! NOZORDER|NOACTIVATE|NOCOPYBITS
MTP:WM_APP_PLACE     EQUATE(08001h)

! ============================================================================
!  callbacks
! ============================================================================
MTP_WndProc          PROCEDURE(LONG hWnd, LONG uMsg, LONG wParam, LONG lParam)
handled                BYTE
res                    LONG
obj                    &MyTaskPanelClass
  CODE
  MTPM:Hwnd = hWnd
  GET(MTP_Map, MTPM:Hwnd)
  IF ERRORCODE() OR MTPM:Kind <> 1
    RETURN mtp_DefWindowProc(hWnd, uMsg, wParam, lParam)
  END
  obj &= MTPM:Obj
  IF uMsg = 082h                                ! WM_NCDESTROY
    DELETE(MTP_Map)
  END
  handled = 0
  res = obj.WndMsg(hWnd, uMsg, wParam, lParam, handled)
  IF handled THEN RETURN res.
  RETURN mtp_DefWindowProc(hWnd, uMsg, wParam, lParam)

MTP_KidProc          PROCEDURE(LONG hWnd, LONG uMsg, LONG wParam, LONG lParam)
old                    LONG
kind                   BYTE
obj                    &MyTaskPanelClass
res                    LONG
  CODE
  MTPM:Hwnd = hWnd
  GET(MTP_Map, MTPM:Hwnd)
  IF ERRORCODE() OR MTPM:Kind < 2
    RETURN mtp_DefWindowProc(hWnd, uMsg, wParam, lParam)
  END
  old  = MTPM:OldProc
  kind = MTPM:Kind
  IF kind = 2 THEN obj &= MTPM:Obj.
  CASE uMsg
  OF 046h                                       ! WM_WINDOWPOSCHANGING
    IF kind = 2
      !  Let the host place it first - it knows where its toolbar and status
      !  bar go - then take the panel's width off the answer.
      res = mtp_CallWindowProc(old, hWnd, uMsg, wParam, lParam)
      obj.KidPosChanging(hWnd, lParam)
      RETURN res
    END
  OF 082h                                       ! WM_NCDESTROY
    IF mtp_GetWindowLong(hWnd, -4) = ADDRESS(MTP_KidProc)
      mtp_SetWindowLong(hWnd, -4, old)
    END
    DELETE(MTP_Map)
    IF kind = 2 THEN obj.ForgetKid(hWnd).
  END
  RETURN mtp_CallWindowProc(old, hWnd, uMsg, wParam, lParam)

MTP_Hex              PROCEDURE(LONG rrggbb)
  CODE
  RETURN BAND(BSHIFT(rrggbb, -16), 0FFh) + BAND(rrggbb, 0FF00h) + BAND(rrggbb, 0FFh) * 65536

MTP_Signed16         PROCEDURE(LONG v)
  CODE
  v = BAND(v, 0FFFFh)
  IF v > 32767 THEN v -= 65536.
  RETURN v

! ============================================================================
!  life cycle
! ============================================================================
MyTaskPanelClass.Construct PROCEDURE
  CODE
  SELF.Items     &= NEW(MTPItemQ)
  SELF.Rows      &= NEW(MTPRowQ)
  SELF.Kids      &= NEW(MTPKidQ)
  SELF.Clicks    &= NEW(MTPClickQ)
  SELF.PendIcons &= NEW(MTPIconQ)
  SELF.Acts      &= NEW(MTPActQ)
  SELF.Drops     &= NEW(MTPDropQ)
  SELF.Title        = 'Tasks'
  SELF.DockSide     = MTP:Left
  SELF.PanelWidth   = 230
  SELF.MinWidth     = 150
  SELF.MaxWidth     = 560
  SELF.SubStyle     = MTP:Inline
  SELF.ShowShortcuts = 1
  SELF.Animate      = 1
  SELF.AllowFloat   = 1
  SELF.AllowDock    = 1
  SELF.AllowClose   = 1
  SELF.AllowResize  = 1
  SELF.GrowHost     = 1
  SELF.AutoGlyphs   = 1
  SELF.Effects      = 1
  SELF.ShowSearch   = 1
  SELF.Favorites    = 1
  SELF.RecentMax    = 5
  SELF.MostMax      = 5
  SELF.ShowTips     = 1
  SELF.FloatOpacity = 88
  SELF.HoverT       = 1
  SELF.FontName     = 'Segoe UI'
  SELF.FontSize     = 9
  SELF.ItemHeight   = 24
  SELF.HeaderHeight = 30
  SELF.Radius       = 6
  SELF.Language     = 'EN'
  SELF.IniSection   = 'TaskPanel'
  SELF.Dpi          = 96
  SELF.SetTheme(MTP:Slate)

MyTaskPanelClass.Destruct PROCEDURE
  CODE
  IF SELF.Inited THEN SELF.Kill().
  DISPOSE(SELF.Items)
  DISPOSE(SELF.Rows)
  DISPOSE(SELF.Kids)
  DISPOSE(SELF.Clicks)
  DISPOSE(SELF.PendIcons)
  DISPOSE(SELF.Acts)
  DISPOSE(SELF.Drops)

MyTaskPanelClass.Init PROCEDURE(WINDOW host, BYTE engine=0)
dc                     LONG
  CODE
  IF SELF.Inited THEN SELF.Kill().
  SELF.Win       &= host
  SELF.HostHwnd   = host{PROP:Handle}
  SELF.HostThread = THREAD()
  SELF.Engine     = engine
  SELF.IsFrame    = CHOOSE(mtp_FindWindowEx(SELF.HostHwnd, 0, ADDRESS(MTP_MdiClass), 0) <> 0, 1, 0)
  dc = mtp_GetDC(0)
  SELF.Dpi = mtp_GetDeviceCaps(dc, 88)          ! LOGPIXELSX
  mtp_ReleaseDC(0, dc)
  IF SELF.Dpi < 96 THEN SELF.Dpi = 96.
  SELF.D2DFailed = 0
  SELF.Inited = CHOOSE(SELF.HostHwnd <> 0, 1, 0)
  RETURN SELF.Inited

MyTaskPanelClass.Kill PROCEDURE
i                      LONG
  CODE
  IF ~SELF.Inited THEN RETURN.
  SELF.SaveState()
  SELF.UnhookKids()
  IF SELF.HideMenu AND SELF.HostMenu AND mtp_IsWindow(SELF.HostHwnd)
    mtp_SetMenu(SELF.HostHwnd, SELF.HostMenu)
    mtp_DrawMenuBar(SELF.HostHwnd)
  END
  SELF.HideMenu = 0
  IF SELF.DockHwnd AND mtp_IsWindow(SELF.DockHwnd) THEN mtp_DestroyWindow(SELF.DockHwnd).
  IF SELF.FloatHwnd AND mtp_IsWindow(SELF.FloatHwnd) THEN mtp_DestroyWindow(SELF.FloatHwnd).
  IF SELF.PeekHwnd AND mtp_IsWindow(SELF.PeekHwnd) THEN mtp_DestroyWindow(SELF.PeekHwnd).
  IF SELF.TipHwnd AND mtp_IsWindow(SELF.TipHwnd) THEN mtp_DestroyWindow(SELF.TipHwnd).
  SELF.TipHwnd = 0
  SELF.TipId = 0
  SELF.DockHwnd = 0
  SELF.FloatHwnd = 0
  SELF.PeekHwnd = 0
  SELF.PeekId = 0
  LOOP i = RECORDS(MTP_Map) TO 1 BY -1          ! anything still pointing at us
    GET(MTP_Map, i)
    IF MTPM:Kind <> 3 AND MTPM:Obj &= SELF
      DELETE(MTP_Map)
    END
  END
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.HIcon
      mtp_DestroyIcon(SELF.Items.HIcon)
      SELF.Items.HIcon = 0
      PUT(SELF.Items)
    END
  END
  SELF.FreeFonts()
  COMPILE('ENDD2D',_MTP_D2D_)
  mtp_d2_kill()
  ! ENDD2D
  FREE(SELF.Clicks)
  SELF.Visible = 0
  SELF.Inited = 0
  SELF.Win &= NULL

MyTaskPanelClass.ShowPanel PROCEDURE
  CODE
  IF ~SELF.Inited THEN RETURN.
  SELF.Visible = 1
  SELF.MakeWindows()
  SELF.Dock(SELF.DockSide)

MyTaskPanelClass.HidePanel PROCEDURE
  CODE
  IF SELF.HasFocus THEN SELF.LeaveFocus().
  SELF.HidePeek()
  SELF.HideTip()
  SELF.Visible = 0
  IF SELF.DockHwnd THEN mtp_ShowWindow(SELF.DockHwnd, 0).
  IF SELF.FloatHwnd THEN mtp_ShowWindow(SELF.FloatHwnd, 0).
  IF SELF.Inited THEN SELF.ApplyLayout().

MyTaskPanelClass.TogglePanel PROCEDURE
  CODE
  IF SELF.Visible THEN SELF.HidePanel() ELSE SELF.ShowPanel().

MyTaskPanelClass.IsVisible PROCEDURE
  CODE
  RETURN SELF.Visible

MyTaskPanelClass.Dock PROCEDURE(BYTE side)
r                      LIKE(MTP_Rect)
  CODE
  IF side < MTP:Left OR side > MTP:Float THEN side = MTP:Left.
  IF side = MTP:Float AND ~SELF.AllowFloat AND SELF.Visible THEN RETURN.
  SELF.DockSide = side
  SELF.HidePeek()
  IF ~SELF.Inited OR ~SELF.Visible THEN RETURN.
  SELF.MakeWindows()
  IF side = MTP:Float
    IF SELF.FloatW <= 0
      mtp_GetWindowRect(SELF.HostHwnd, ADDRESS(r))
      SELF.FloatW = SELF.PanelWidth + SELF.Px(16)
      SELF.FloatH = (r.Y2 - r.Y1) * 2 / 3
      IF SELF.FloatH < SELF.Px(260) THEN SELF.FloatH = SELF.Px(260).
      SELF.FloatX = r.X1 + SELF.Px(48)
      SELF.FloatY = r.Y1 + SELF.Px(96)
    END
    mtp_ShowWindow(SELF.DockHwnd, 0)
    mtp_SetWindowPos(SELF.FloatHwnd, 0, SELF.FloatX, SELF.FloatY, SELF.FloatW, SELF.FloatH, 0054h) ! NOZORDER|NOACTIVATE|SHOWWINDOW
  ELSE
    mtp_ShowWindow(SELF.FloatHwnd, 0)
  END
  SELF.ApplyLayout()

MyTaskPanelClass.SetWidth PROCEDURE(LONG px)
  CODE
  IF px < SELF.MinWidth THEN px = SELF.MinWidth.
  IF px > SELF.MaxWidth THEN px = SELF.MaxWidth.
  IF px = SELF.PanelWidth THEN RETURN.
  SELF.PanelWidth = px
  IF SELF.Inited AND SELF.Visible AND SELF.DockSide <> MTP:Float THEN SELF.ApplyLayout().

MyTaskPanelClass.Refresh PROCEDURE
  CODE
  IF SELF.Inited AND SELF.Visible THEN SELF.ApplyLayout().

MyTaskPanelClass.EngineInUse PROCEDURE
  CODE
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.Engine = MTP:DirectX AND ~SELF.D2DFailed THEN RETURN MTP:DirectX.
  ! ENDD2D
  RETURN MTP:Clarion

!  How long one frame of this panel takes to paint, in milliseconds, with the
!  given engine - drawn off screen, at the panel's own size and contents, the
!  same steps as WM_PAINT (layout, drawing, icons) minus the final blit to
!  the screen, which costs both engines the same. The first frame is a
!  warm-up (fonts, the Direct2D target) and is not timed; after it one item
!  is held under the mouse so the hover highlight is part of every frame.
!  -1 = that engine is not compiled in or will not start.
MyTaskPanelClass.Benchmark PROCEDURE(BYTE engine, LONG frames=200, BYTE effects=1)
hwnd                   LONG
r                      LIKE(MTP_Rect)
w                      LONG
h                      LONG
sdc                    LONG
mem                    LONG
bmp                    LONG
old                    LONG
f                      LONG
i                      LONG
floating               BYTE
ok                     BYTE
t0                     LIKE(MTP_Large)
t1                     LIKE(MTP_Large)
fq                     LIKE(MTP_Large)
svEffects              BYTE
svHover                LONG
svHoverT               REAL
svFadeId               LONG
ms                     REAL
  CODE
  IF frames < 1 THEN frames = 1.
  ok = 1
  IF engine = MTP:DirectX
    ok = 0
    COMPILE('ENDD2D',_MTP_D2D_)
    ok = CHOOSE(mtp_d2_init() = 1, 1, 0)
    ! ENDD2D
    IF ~ok THEN RETURN -1.
  END
  floating = CHOOSE(SELF.DockSide = MTP:Float AND SELF.FloatHwnd <> 0, 1, 0)
  hwnd = CHOOSE(floating = 1, SELF.FloatHwnd, SELF.DockHwnd)
  IF hwnd THEN mtp_GetClientRect(hwnd, ADDRESS(r)).
  w = r.X2
  h = r.Y2
  IF w < 50 OR h < 50
    w = SELF.PanelWidth
    h = SELF.Px(700)
  END
  sdc = mtp_GetDC(0)
  mem = mtp_CreateCompatibleDC(sdc)
  bmp = mtp_CreateCompatibleBitmap(sdc, w, h)
  mtp_ReleaseDC(0, sdc)
  old = mtp_SelectObject(mem, bmp)
  mtp_SetBkMode(mem, 1)
  svEffects = SELF.Effects
  svHover   = SELF.Hover
  svHoverT  = SELF.HoverT
  svFadeId  = SELF.FadeId
  SELF.Effects = effects
  SELF.HoverT  = 1
  SELF.FadeId  = 0
  SELF.DC = mem
  LOOP f = 0 TO frames
    IF f = 1 THEN mtp_QPCounter(ADDRESS(t0)).
    SELF.MakeFonts()
    FREE(SELF.PendIcons)
    SELF.UseD2D = 0
    SELF.Fx = 0
    IF engine = MTP:DirectX
      COMPILE('ENDD2D',_MTP_D2D_)
      IF ~mtp_d2_begin(mem, w, h)
        ok = 0
        BREAK
      END
      SELF.UseD2D = 1
      SELF.Fx = SELF.Effects
      ! ENDD2D
    END
    IF ~SELF.BenchEmpty THEN SELF.Render(w, h, floating).
    COMPILE('ENDD2D',_MTP_D2D_)
    IF SELF.UseD2D THEN mtp_d2_end().
    ! ENDD2D
    SELF.UseD2D = 0
    SELF.Fx = 0
    LOOP i = 1 TO RECORDS(SELF.PendIcons)
      GET(SELF.PendIcons, i)
      mtp_DrawIconEx(mem, SELF.PendIcons.X, SELF.PendIcons.Y, SELF.PendIcons.HIcon, SELF.PendIcons.Sz, SELF.PendIcons.Sz, 0, 0, 3)
    END
    IF f = 0                                    ! hold the first item under the mouse
      LOOP i = 1 TO RECORDS(SELF.Rows)
        GET(SELF.Rows, i)
        IF SELF.Rows.Kind = MTP:Item THEN BREAK.
      END
      IF i <= RECORDS(SELF.Rows) THEN SELF.Hover = SELF.Rows.Id.
    END
  END
  mtp_QPCounter(ADDRESS(t1))
  mtp_QPFrequency(ADDRESS(fq))
  FREE(SELF.PendIcons)
  SELF.Effects = svEffects
  SELF.Hover   = svHover
  SELF.HoverT  = svHoverT
  SELF.FadeId  = svFadeId
  SELF.DC = 0
  mtp_SelectObject(mem, old)
  mtp_DeleteObject(bmp)
  mtp_DeleteDC(mem)
  IF ~ok THEN RETURN -1.
  ms = ((t1.Hi * 4294967296.0 + t1.Lo) - (t0.Hi * 4294967296.0 + t0.Lo)) * 1000 / (fq.Hi * 4294967296.0 + fq.Lo) / frames
  RETURN ms

!  Switches for the speed test, to see where a DirectX frame's time goes.
!    1  the Direct2D target type: 0 let Direct2D choose, 1 software (CPU), 2 hardware (GPU)
!    2  cache gradient brushes (1, the default) or make one per call (0)
!    3  Benchmark times empty frames (begin + end, nothing drawn): the fixed cost
MyTaskPanelClass.Diag PROCEDURE(LONG what, LONG value)
old                    LONG
  CODE
  IF what = 3
    old = SELF.BenchEmpty
    SELF.BenchEmpty = value
    RETURN old
  END
  COMPILE('ENDD2D',_MTP_D2D_)
  RETURN mtp_d2_diag(what, value)
  ! ENDD2D
  RETURN 0

MyTaskPanelClass.SetLanguage PROCEDURE(STRING lang)
  CODE
  SELF.Language = UPPER(lang)

MyTaskPanelClass.Txt PROCEDURE(STRING en, STRING es)
  CODE
  IF UPPER(SELF.Language) = 'ES' THEN RETURN CLIP(es).
  RETURN CLIP(en)

! ============================================================================
!  themes - professional palettes, no purple. Written as 0RRGGBBh.
! ============================================================================
MyTaskPanelClass.SetTheme PROCEDURE(LONG theme)
  CODE
  CASE theme
  OF MTP:Navy
    SELF.ClrBack      = MTP_Hex(0EDF1F6h)
    SELF.ClrTitle1    = MTP_Hex(0132C52h)
    SELF.ClrTitle2    = MTP_Hex(00B1F3Ah)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(0234978h)
    SELF.ClrHead2     = MTP_Hex(01A3A62h)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(01F6FB2h)
    SELF.ClrSpecial2  = MTP_Hex(0185A92h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0D3DAE4h)
    SELF.ClrText      = MTP_Hex(01C2533h)
    SELF.ClrTextDim   = MTP_Hex(06B7280h)
    SELF.ClrHover     = MTP_Hex(0E6EEF8h)
    SELF.ClrHoverLine = MTP_Hex(0B9CDE8h)
    SELF.ClrAccent    = MTP_Hex(01F6FB2h)
  OF MTP:Graphite
    SELF.ClrBack      = MTP_Hex(01C2026h)
    SELF.ClrTitle1    = MTP_Hex(0181B20h)
    SELF.ClrTitle2    = MTP_Hex(0121418h)
    SELF.ClrTitleText = MTP_Hex(0E6E9EDh)
    SELF.ClrHead1     = MTP_Hex(02E353Dh)
    SELF.ClrHead2     = MTP_Hex(0262C33h)
    SELF.ClrHeadText  = MTP_Hex(0E6E9EDh)
    SELF.ClrSpecial1  = MTP_Hex(02563A8h)
    SELF.ClrSpecial2  = MTP_Hex(01D4F88h)
    SELF.ClrCard      = MTP_Hex(024292Fh)
    SELF.ClrCardLine  = MTP_Hex(0343B44h)
    SELF.ClrText      = MTP_Hex(0E3E7EBh)
    SELF.ClrTextDim   = MTP_Hex(09AA3ADh)
    SELF.ClrHover     = MTP_Hex(0313A45h)
    SELF.ClrHoverLine = MTP_Hex(0425467h)
    SELF.ClrAccent    = MTP_Hex(05AA9F5h)
  OF MTP:Teal
    SELF.ClrBack      = MTP_Hex(0F1F6F6h)
    SELF.ClrTitle1    = MTP_Hex(0134E52h)
    SELF.ClrTitle2    = MTP_Hex(00C383Bh)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(0127F88h)
    SELF.ClrHead2     = MTP_Hex(00D666Eh)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(01D6FA3h)
    SELF.ClrSpecial2  = MTP_Hex(01A5C86h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0D2E2E3h)
    SELF.ClrText      = MTP_Hex(01E2A2Bh)
    SELF.ClrTextDim   = MTP_Hex(0667778h)
    SELF.ClrHover     = MTP_Hex(0E3F2F2h)
    SELF.ClrHoverLine = MTP_Hex(0A9D6D8h)
    SELF.ClrAccent    = MTP_Hex(00E7C86h)
  OF MTP:Light
    SELF.ClrBack      = MTP_Hex(0F5F6F8h)
    SELF.ClrTitle1    = MTP_Hex(0FFFFFFh)
    SELF.ClrTitle2    = MTP_Hex(0EEF1F5h)
    SELF.ClrTitleText = MTP_Hex(01F2937h)
    SELF.ClrHead1     = MTP_Hex(0F4F7FBh)
    SELF.ClrHead2     = MTP_Hex(0E6ECF4h)
    SELF.ClrHeadText  = MTP_Hex(01F2937h)
    SELF.ClrSpecial1  = MTP_Hex(02F6FD6h)
    SELF.ClrSpecial2  = MTP_Hex(0215CB8h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0DCE1E8h)
    SELF.ClrText      = MTP_Hex(01F2937h)
    SELF.ClrTextDim   = MTP_Hex(06B7280h)
    SELF.ClrHover     = MTP_Hex(0EAF1FCh)
    SELF.ClrHoverLine = MTP_Hex(0BFD3F2h)
    SELF.ClrAccent    = MTP_Hex(02563EBh)
  OF MTP:Forest
    SELF.ClrBack      = MTP_Hex(0F2F6F3h)
    SELF.ClrTitle1    = MTP_Hex(01F3B2Dh)
    SELF.ClrTitle2    = MTP_Hex(0152A20h)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(02F6B4Fh)
    SELF.ClrHead2     = MTP_Hex(024563Fh)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(01F6FB2h)
    SELF.ClrSpecial2  = MTP_Hex(0185A92h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0D5E0D8h)
    SELF.ClrText      = MTP_Hex(01F2A23h)
    SELF.ClrTextDim   = MTP_Hex(066746Ah)
    SELF.ClrHover     = MTP_Hex(0E5F1E8h)
    SELF.ClrHoverLine = MTP_Hex(0ADD3B7h)
    SELF.ClrAccent    = MTP_Hex(02F855Ah)
  OF MTP:HighContrast
    SELF.ClrBack      = MTP_Hex(0000000h)
    SELF.ClrTitle1    = MTP_Hex(0000000h)
    SELF.ClrTitle2    = MTP_Hex(0000000h)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(0000000h)
    SELF.ClrHead2     = MTP_Hex(0000000h)
    SELF.ClrHeadText  = MTP_Hex(0FFFF00h)
    SELF.ClrSpecial1  = MTP_Hex(00A3D91h)
    SELF.ClrSpecial2  = MTP_Hex(00A3D91h)
    SELF.ClrCard      = MTP_Hex(0000000h)
    SELF.ClrCardLine  = MTP_Hex(0FFFFFFh)
    SELF.ClrText      = MTP_Hex(0FFFFFFh)
    SELF.ClrTextDim   = MTP_Hex(0E6E6E6h)
    SELF.ClrHover     = MTP_Hex(03A3A00h)
    SELF.ClrHoverLine = MTP_Hex(0FFFF00h)
    SELF.ClrAccent    = MTP_Hex(01AEBFFh)
  OF MTP:LowContrast
    SELF.ClrBack      = MTP_Hex(0E9EBEEh)
    SELF.ClrTitle1    = MTP_Hex(0CDD2D9h)
    SELF.ClrTitle2    = MTP_Hex(0C2C8D0h)
    SELF.ClrTitleText = MTP_Hex(03E4652h)
    SELF.ClrHead1     = MTP_Hex(0D9DDE3h)
    SELF.ClrHead2     = MTP_Hex(0CFD4DBh)
    SELF.ClrHeadText  = MTP_Hex(03E4652h)
    SELF.ClrSpecial1  = MTP_Hex(08EA3BDh)
    SELF.ClrSpecial2  = MTP_Hex(08297B2h)
    SELF.ClrCard      = MTP_Hex(0F5F6F8h)
    SELF.ClrCardLine  = MTP_Hex(0E2E5E9h)
    SELF.ClrText      = MTP_Hex(04B5360h)
    SELF.ClrTextDim   = MTP_Hex(0858C97h)
    SELF.ClrHover     = MTP_Hex(0EAEDF1h)
    SELF.ClrHoverLine = MTP_Hex(0D2D8E0h)
    SELF.ClrAccent    = MTP_Hex(06F86A6h)
  OF MTP:Ocean
    SELF.ClrBack      = MTP_Hex(0F3F5F7h)
    SELF.ClrTitle1    = MTP_Hex(0123B5Eh)
    SELF.ClrTitle2    = MTP_Hex(00C2840h)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(01D609Ah)
    SELF.ClrHead2     = MTP_Hex(0184D7Ch)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(02270B4h)
    SELF.ClrSpecial2  = MTP_Hex(01D5D96h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0DAE1E7h)
    SELF.ClrText      = MTP_Hex(01E272Eh)
    SELF.ClrTextDim   = MTP_Hex(0626C74h)
    SELF.ClrHover     = MTP_Hex(0EAF0F5h)
    SELF.ClrHoverLine = MTP_Hex(0B4C8DAh)
    SELF.ClrAccent    = MTP_Hex(0216BABh)
  OF MTP:Crimson
    SELF.ClrBack      = MTP_Hex(0F6F3F4h)
    SELF.ClrTitle1    = MTP_Hex(05B151Ch)
    SELF.ClrTitle2    = MTP_Hex(03E0F13h)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(095232Eh)
    SELF.ClrHead2     = MTP_Hex(0781C25h)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(0AE2936h)
    SELF.ClrSpecial2  = MTP_Hex(091222Dh)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0E6DBDCh)
    SELF.ClrText      = MTP_Hex(02D1F21h)
    SELF.ClrTextDim   = MTP_Hex(0736365h)
    SELF.ClrHover     = MTP_Hex(0F4EBECh)
    SELF.ClrHoverLine = MTP_Hex(0D8B6B9h)
    SELF.ClrAccent    = MTP_Hex(0A52733h)
  OF MTP:Amber
    SELF.ClrBack      = MTP_Hex(0F7F5F3h)
    SELF.ClrTitle1    = MTP_Hex(0693F07h)
    SELF.ClrTitle2    = MTP_Hex(0482B05h)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(0A8640Bh)
    SELF.ClrHead2     = MTP_Hex(0865009h)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(0A8640Bh)
    SELF.ClrSpecial2  = MTP_Hex(0865009h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0E8E1D8h)
    SELF.ClrText      = MTP_Hex(030281Ch)
    SELF.ClrTextDim   = MTP_Hex(0766D60h)
    SELF.ClrHover     = MTP_Hex(0F6F1E9h)
    SELF.ClrHoverLine = MTP_Hex(0E0CAAEh)
    SELF.ClrAccent    = MTP_Hex(0A8640Bh)
  OF MTP:Copper
    SELF.ClrBack      = MTP_Hex(0F6F4F3h)
    SELF.ClrTitle1    = MTP_Hex(0572E19h)
    SELF.ClrTitle2    = MTP_Hex(03B1F11h)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(08E4B29h)
    SELF.ClrHead2     = MTP_Hex(0733C21h)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(0A65730h)
    SELF.ClrSpecial2  = MTP_Hex(08A4928h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0E5DFDBh)
    SELF.ClrText      = MTP_Hex(02D2420h)
    SELF.ClrTextDim   = MTP_Hex(0726964h)
    SELF.ClrHover     = MTP_Hex(0F4EEEBh)
    SELF.ClrHoverLine = MTP_Hex(0D6C2B7h)
    SELF.ClrAccent    = MTP_Hex(09E532Eh)
  OF MTP:Sky
    SELF.ClrBack      = MTP_Hex(0F3F6F7h)
    SELF.ClrTitle1    = MTP_Hex(0084E68h)
    SELF.ClrTitle2    = MTP_Hex(0063547h)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(00D7DA5h)
    SELF.ClrHead2     = MTP_Hex(00B6484h)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(00D7DA5h)
    SELF.ClrSpecial2  = MTP_Hex(00B6484h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0D9E4E8h)
    SELF.ClrText      = MTP_Hex(01C2B30h)
    SELF.ClrTextDim   = MTP_Hex(0607076h)
    SELF.ClrHover     = MTP_Hex(0E9F3F6h)
    SELF.ClrHoverLine = MTP_Hex(0AFD2DFh)
    SELF.ClrAccent    = MTP_Hex(00D7DA5h)
  OF MTP:Mint
    SELF.ClrBack      = MTP_Hex(0F4F6F5h)
    SELF.ClrTitle1    = MTP_Hex(01D5343h)
    SELF.ClrTitle2    = MTP_Hex(014392Eh)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(02E846Ah)
    SELF.ClrHead2     = MTP_Hex(0256A55h)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(02E846Ah)
    SELF.ClrSpecial2  = MTP_Hex(0256A55h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0DCE5E2h)
    SELF.ClrText      = MTP_Hex(0212C28h)
    SELF.ClrTextDim   = MTP_Hex(065716Eh)
    SELF.ClrHover     = MTP_Hex(0ECF3F1h)
    SELF.ClrHoverLine = MTP_Hex(0B9D4CCh)
    SELF.ClrAccent    = MTP_Hex(02E846Ah)
  OF MTP:Steel
    SELF.ClrBack      = MTP_Hex(0F4F5F5h)
    SELF.ClrTitle1    = MTP_Hex(0303740h)
    SELF.ClrTitle2    = MTP_Hex(021262Ch)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(04F5A69h)
    SELF.ClrHead2     = MTP_Hex(0404954h)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(05C697Ah)
    SELF.ClrSpecial2  = MTP_Hex(04D5866h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0DFE0E2h)
    SELF.ClrText      = MTP_Hex(0252628h)
    SELF.ClrTextDim   = MTP_Hex(0696B6Dh)
    SELF.ClrHover     = MTP_Hex(0EFF0F1h)
    SELF.ClrHoverLine = MTP_Hex(0C3C6CBh)
    SELF.ClrAccent    = MTP_Hex(0586474h)
  OF MTP:Sand
    SELF.ClrBack      = MTP_Hex(0F6F5F4h)
    SELF.ClrTitle1    = MTP_Hex(0483C28h)
    SELF.ClrTitle2    = MTP_Hex(031291Ch)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(0766342h)
    SELF.ClrHead2     = MTP_Hex(05F4F35h)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(089734Dh)
    SELF.ClrSpecial2  = MTP_Hex(0726040h)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0E3E1DEh)
    SELF.ClrText      = MTP_Hex(0292723h)
    SELF.ClrTextDim   = MTP_Hex(06F6C68h)
    SELF.ClrHover     = MTP_Hex(0F2F0EEh)
    SELF.ClrHoverLine = MTP_Hex(0CFC9BFh)
    SELF.ClrAccent    = MTP_Hex(0836E49h)
  OF MTP:Midnight
    SELF.ClrBack      = MTP_Hex(00F1626h)
    SELF.ClrTitle1    = MTP_Hex(00B1220h)
    SELF.ClrTitle2    = MTP_Hex(0070C17h)
    SELF.ClrTitleText = MTP_Hex(0E6EBF5h)
    SELF.ClrHead1     = MTP_Hex(01D2B4Ah)
    SELF.ClrHead2     = MTP_Hex(016223Ch)
    SELF.ClrHeadText  = MTP_Hex(0E6EBF5h)
    SELF.ClrSpecial1  = MTP_Hex(02563EBh)
    SELF.ClrSpecial2  = MTP_Hex(01D4FBFh)
    SELF.ClrCard      = MTP_Hex(0162036h)
    SELF.ClrCardLine  = MTP_Hex(025314Dh)
    SELF.ClrText      = MTP_Hex(0E2E8F0h)
    SELF.ClrTextDim   = MTP_Hex(094A3B8h)
    SELF.ClrHover     = MTP_Hex(01E2A45h)
    SELF.ClrHoverLine = MTP_Hex(034508Ah)
    SELF.ClrAccent    = MTP_Hex(060A5FAh)
  OF MTP:Olive
    SELF.ClrBack      = MTP_Hex(0F5F6F4h)
    SELF.ClrTitle1    = MTP_Hex(0454D23h)
    SELF.ClrTitle2    = MTP_Hex(02F3518h)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(06E7B37h)
    SELF.ClrHead2     = MTP_Hex(058632Ch)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(06E7B37h)
    SELF.ClrSpecial2  = MTP_Hex(058632Ch)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0E2E4DDh)
    SELF.ClrText      = MTP_Hex(0292B22h)
    SELF.ClrTextDim   = MTP_Hex(06E7066h)
    SELF.ClrHover     = MTP_Hex(0F1F3EDh)
    SELF.ClrHoverLine = MTP_Hex(0CDD2BCh)
    SELF.ClrAccent    = MTP_Hex(06E7B37h)
  ELSE                                          ! MTP:Slate
    SELF.ClrBack      = MTP_Hex(0F2F4F7h)
    SELF.ClrTitle1    = MTP_Hex(02B3A4Fh)
    SELF.ClrTitle2    = MTP_Hex(01E2A3Bh)
    SELF.ClrTitleText = MTP_Hex(0FFFFFFh)
    SELF.ClrHead1     = MTP_Hex(03E5F86h)
    SELF.ClrHead2     = MTP_Hex(02F4B6Eh)
    SELF.ClrHeadText  = MTP_Hex(0FFFFFFh)
    SELF.ClrSpecial1  = MTP_Hex(01570C4h)
    SELF.ClrSpecial2  = MTP_Hex(00F5A9Fh)
    SELF.ClrCard      = MTP_Hex(0FFFFFFh)
    SELF.ClrCardLine  = MTP_Hex(0D8DEE6h)
    SELF.ClrText      = MTP_Hex(01F2937h)
    SELF.ClrTextDim   = MTP_Hex(06B7280h)
    SELF.ClrHover     = MTP_Hex(0E8F0FAh)
    SELF.ClrHoverLine = MTP_Hex(0BDD2EEh)
    SELF.ClrAccent    = MTP_Hex(01570C4h)
  END
  SELF.ClrSpecialText = MTP_Hex(0FFFFFFh)
  SELF.ClrDisabled = SELF.Mix(SELF.ClrTextDim, SELF.ClrCard, 0.45)
  SELF.ClrSep      = SELF.Mix(SELF.ClrCardLine, SELF.ClrCard, 0.3)
  SELF.Invalidate()

MyTaskPanelClass.SetAccent PROCEDURE(LONG clr)
  CODE
  SELF.ClrAccent   = clr
  SELF.ClrSpecial1 = clr
  SELF.ClrSpecial2 = SELF.Mix(clr, 0, 0.18)
  SELF.Invalidate()

! ============================================================================
!  building
! ============================================================================
MyTaskPanelClass.AddGroup PROCEDURE(STRING text, <STRING glyph>, BYTE expanded=1, BYTE special=0)
  CODE
  CLEAR(SELF.Items)
  SELF.NextId += 1
  SELF.Items.Id       = SELF.NextId
  SELF.Items.Parent   = 0
  SELF.Items.Kind     = MTP:Group
  SELF.Items.Text     = SELF.CleanText(text)
  IF ~OMITTED(glyph) THEN SELF.Items.Glyph = glyph.
  SELF.Items.Expanded = expanded
  SELF.Items.Reveal   = expanded
  SELF.Items.Enabled  = 1
  SELF.Items.Special  = special
  ADD(SELF.Items)
  SELF.Invalidate()
  RETURN SELF.NextId

MyTaskPanelClass.AddItem PROCEDURE(LONG pid, STRING text, <STRING glyph>, <STRING tag>, LONG feq=0)
  CODE
  CLEAR(SELF.Items)
  SELF.NextId += 1
  SELF.Items.Id       = SELF.NextId
  SELF.Items.Parent   = pid
  SELF.Items.Kind     = MTP:Item
  SELF.Items.Text     = SELF.CleanText(text)
  IF ~OMITTED(glyph) THEN SELF.Items.Glyph = glyph.
  IF ~OMITTED(tag) THEN SELF.Items.Tag = tag.
  SELF.Items.Feq      = feq
  SELF.Items.Enabled  = 1
  ADD(SELF.Items)
  SELF.Invalidate()
  RETURN SELF.NextId

MyTaskPanelClass.AddSeparator PROCEDURE(LONG pid)
  CODE
  CLEAR(SELF.Items)
  SELF.NextId += 1
  SELF.Items.Id      = SELF.NextId
  SELF.Items.Parent  = pid
  SELF.Items.Kind    = MTP:Separator
  SELF.Items.Enabled = 1
  ADD(SELF.Items)
  RETURN SELF.NextId

MyTaskPanelClass.AddLabel PROCEDURE(LONG pid, STRING text)
  CODE
  CLEAR(SELF.Items)
  SELF.NextId += 1
  SELF.Items.Id      = SELF.NextId
  SELF.Items.Parent  = pid
  SELF.Items.Kind    = MTP:Label
  SELF.Items.Text    = SELF.CleanText(text)
  SELF.Items.Enabled = 1
  ADD(SELF.Items)
  RETURN SELF.NextId

MyTaskPanelClass.DeleteItem PROCEDURE(LONG id)
i                      LONG
kid                    LONG
  CODE
  LOOP                                          ! children first, to any depth
    kid = 0
    LOOP i = 1 TO RECORDS(SELF.Items)
      GET(SELF.Items, i)
      IF SELF.Items.Parent = id AND id <> 0
        kid = SELF.Items.Id
        BREAK
      END
    END
    IF ~kid THEN BREAK.
    SELF.DeleteItem(kid)
  END
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Id = id
      IF SELF.Items.HIcon THEN mtp_DestroyIcon(SELF.Items.HIcon).
      DELETE(SELF.Items)
      BREAK
    END
  END
  SELF.Invalidate()

MyTaskPanelClass.ClearAll PROCEDURE
i                      LONG
  CODE
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.HIcon THEN mtp_DestroyIcon(SELF.Items.HIcon).
  END
  FREE(SELF.Items)
  FREE(SELF.Rows)
  SELF.ScrollY = 0
  SELF.Invalidate()

MyTaskPanelClass.CleanText PROCEDURE(STRING txt)
res                    STRING(256)
i                      LONG
n                      LONG
  CODE
  res = ''
  n = 0
  i = 1
  LOOP WHILE i <= LEN(CLIP(txt))
    IF txt[i] = '&'
      IF i < LEN(CLIP(txt)) AND txt[i+1] = '&'
        n += 1
        res[n] = '&'
        i += 2
        CYCLE
      END
      i += 1
      CYCLE
    END
    n += 1
    IF n > 255 THEN BREAK.
    res[n] = txt[i]
    i += 1
  END
  RETURN CLIP(res)

! ============================================================================
!  items
! ============================================================================
MyTaskPanelClass.FindTag PROCEDURE(STRING tag)
i                      LONG
  CODE
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF UPPER(SELF.Items.Tag) = UPPER(tag) AND tag <> '' THEN RETURN SELF.Items.Id.
  END
  RETURN 0

MyTaskPanelClass.FindText PROCEDURE(STRING text, LONG pid=-1)
i                      LONG
  CODE
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF pid >= 0 AND SELF.Items.Parent <> pid THEN CYCLE.
    IF UPPER(SELF.Items.Text) = UPPER(SELF.CleanText(text)) THEN RETURN SELF.Items.Id.
  END
  RETURN 0

MyTaskPanelClass.ItemCount PROCEDURE
  CODE
  RETURN RECORDS(SELF.Items)

MyTaskPanelClass.SetText PROCEDURE(LONG id, STRING text)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Text = SELF.CleanText(text)
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetGlyph PROCEDURE(LONG id, STRING glyph)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Glyph = glyph
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetIcon PROCEDURE(LONG id, STRING iconFile)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  IF SELF.Items.HIcon THEN mtp_DestroyIcon(SELF.Items.HIcon).
  SELF.Items.HIcon = 0
  SELF.Items.IconFile = iconFile
  SELF.LoadIcon()
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetShortcut PROCEDURE(LONG id, STRING txt)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Shortcut = txt
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetTip PROCEDURE(LONG id, STRING txt)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Tip = txt
  PUT(SELF.Items)

MyTaskPanelClass.SetEnabled PROCEDURE(LONG id, BYTE on)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Enabled = on
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetHidden PROCEDURE(LONG id, BYTE on)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Hidden = on
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetChecked PROCEDURE(LONG id, BYTE on)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Checked = on
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetBold PROCEDURE(LONG id, BYTE on)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Bold = on
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetSpecial PROCEDURE(LONG id, BYTE on)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Special = on
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetFeq PROCEDURE(LONG id, LONG feq)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Feq = feq
  PUT(SELF.Items)

MyTaskPanelClass.Expand PROCEDURE(LONG id, BYTE on=1)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Expanded = on
  IF ~SELF.Animate OR ~SELF.Visible THEN SELF.Items.Reveal = on.
  PUT(SELF.Items)
  IF SELF.Animate AND SELF.Visible THEN SELF.StartAnim().
  SELF.Invalidate()

MyTaskPanelClass.ExpandAll PROCEDURE(BYTE on=1)
i                      LONG
  CODE
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Kind = MTP:Group OR SELF.HasKids(SELF.Items.Id)
      GET(SELF.Items, i)
      SELF.Items.Expanded = on
      IF ~SELF.Animate OR ~SELF.Visible THEN SELF.Items.Reveal = on.
      PUT(SELF.Items)
    END
  END
  IF SELF.Animate AND SELF.Visible THEN SELF.StartAnim().
  SELF.Invalidate()

MyTaskPanelClass.IsExpanded PROCEDURE(LONG id)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN 0.
  RETURN SELF.Items.Expanded

MyTaskPanelClass.HasKids PROCEDURE(LONG id)
i                      LONG
pos                    LONG
res                    BYTE
  CODE
  pos = POINTER(SELF.Items)
  res = 0
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Parent = id AND ~SELF.Gone() AND id <> 0
      res = 1
      BREAK
    END
  END
  IF pos THEN GET(SELF.Items, pos).
  RETURN res

! ============================================================================
!  clicks
! ============================================================================
MyTaskPanelClass.Click PROCEDURE(LONG id)
  CODE
  id = SELF.Resolve(id)                         ! a Favourites / Recent row runs the real item
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() OR ~SELF.Items.Enabled THEN RETURN.
  IF SELF.Items.Kind = MTP:Item AND SELF.Items.Role = 0  ! counted for Most used
    SELF.Items.Uses += 1
    PUT(SELF.Items)
  END
  SELF.PushRecent(id)
  SELF.RebuildMost()
  SELF.Clicks.Act = 0
  SELF.Clicks.Id = id
  ADD(SELF.Clicks)
  POST(MTP:Event, , SELF.HostThread)

MyTaskPanelClass.NextClick PROCEDURE
id                     LONG
act                    LONG
i                      LONG
  CODE
  LOOP
    IF ~RECORDS(SELF.Clicks)
      SELF.ClickId = 0
      RETURN 0
    END
    GET(SELF.Clicks, 1)
    id = SELF.Clicks.Id
    act = SELF.Clicks.Act
    DELETE(SELF.Clicks)
    SELF.Items.Id = id
    GET(SELF.Items, SELF.Items.Id)
    IF ERRORCODE() THEN CYCLE.
    SELF.ClickAct = 0
    IF act                                      ! a hover button: its own tag, the row's text
      SELF.ClickId   = id
      SELF.ClickText = SELF.Items.Text
      SELF.ClickAct  = act
      LOOP i = 1 TO RECORDS(SELF.Acts)
        GET(SELF.Acts, i)
        IF SELF.Acts.Id = act THEN BREAK.
      END
      IF i > RECORDS(SELF.Acts) THEN CYCLE.
      SELF.ClickTag = SELF.Acts.Tag
      SELF.TakeItem(id, CLIP(SELF.ClickTag))
      RETURN 1
    END
    IF SELF.Items.Feq
      !  A mirrored menu row (or an item pointed at a control): hand the click
      !  to the original, so its own embed code runs.
      POST(EVENT:Accepted, SELF.Items.Feq)
      CYCLE
    END
    SELF.ClickId   = id
    SELF.ClickTag  = SELF.Items.Tag
    SELF.ClickText = SELF.Items.Text
    SELF.TakeItem(id, CLIP(SELF.ClickTag))
    RETURN 1
  END

MyTaskPanelClass.TakeItem PROCEDURE(LONG id, STRING tag)
  CODE

! ============================================================================
!  helpers
! ============================================================================
MyTaskPanelClass.OpenUrl PROCEDURE(STRING url)
verb                   CSTRING(8)
target                 CSTRING(1024)
  CODE
  verb = 'open'
  target = CLIP(url)
  mtp_ShellExecute(SELF.HostHwnd, ADDRESS(verb), ADDRESS(target), 0, 0, 1)

MyTaskPanelClass.MdiCommand PROCEDURE(LONG cmd)
mdi                    LONG
  CODE
  IF ~SELF.Inited THEN RETURN.
  mdi = mtp_FindWindowEx(SELF.HostHwnd, 0, ADDRESS(MTP_MdiClass), 0)
  IF ~mdi THEN RETURN.
  CASE cmd
  OF MTP:TileH   ; mtp_SendMessage(mdi, 0226h, 1, 0)   ! WM_MDITILE, MDITILE_HORIZONTAL
  OF MTP:TileV   ; mtp_SendMessage(mdi, 0226h, 0, 0)   ! WM_MDITILE, MDITILE_VERTICAL
  OF MTP:Cascade ; mtp_SendMessage(mdi, 0227h, 0, 0)   ! WM_MDICASCADE
  OF MTP:Arrange ; mtp_SendMessage(mdi, 0228h, 0, 0)   ! WM_MDIICONARRANGE
  END

!  PUTINI and GETINI read a bare file name as "in the Windows directory"
!  (which Windows then quietly redirects to VirtualStore), so a name with no
!  folder is taken from the program's own folder instead.
MyTaskPanelClass.IniName PROCEDURE
  CODE
  IF INSTRING('\', SELF.IniFile, 1, 1) OR INSTRING(':', SELF.IniFile, 1, 1) THEN RETURN CLIP(SELF.IniFile).
  RETURN CLIP(PATH()) & '\' & CLIP(SELF.IniFile)

MyTaskPanelClass.SaveState PROCEDURE
i                      LONG
id                     LONG
n                      LONG
hid                    STRING(1000)
uses                   STRING(4000)
sec                    STRING(60)
ini                    STRING(400)
  CODE
  IF ~SELF.IniFile THEN RETURN.
  ini = SELF.IniName()
  sec = CHOOSE(SELF.IniSection = '', 'TaskPanel', SELF.IniSection)
  PUTINI(sec, 'Dock', SELF.DockSide, ini)
  PUTINI(sec, 'Width', SELF.PanelWidth, ini)
  PUTINI(sec, 'Visible', SELF.Visible, ini)
  PUTINI(sec, 'Rail', SELF.Rail, ini)
  PUTINI(sec, 'AutoHide', SELF.AutoHide, ini)
  PUTINI(sec, 'Favourites', SELF.ListKeys(SELF.RefList(1)), ini)
  PUTINI(sec, 'Recent', SELF.ListKeys(SELF.RefList(2)), ini)
  PUTINI(sec, 'GroupOrder', SELF.ListKeys(SELF.GroupOrder), ini)
  hid = ','                                     ! hidden by the user; times each item was run
  uses = ''
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.UserHidden THEN hid = CLIP(hid) & SELF.Items.Id & ','.
    IF SELF.Items.Uses > 0 AND SELF.Items.Role = 0
      id = SELF.Items.Id
      n = SELF.Items.Uses
      uses = CHOOSE(CLIP(uses) = '', '', CLIP(uses) & '|') & SELF.ItemKey(id) & '=' & n
      GET(SELF.Items, i)
    END
  END
  PUTINI(sec, 'Hidden', SELF.ListKeys(hid), ini)
  PUTINI(sec, 'Uses', CLIP(uses), ini)
  IF SELF.FloatW > 0
    PUTINI(sec, 'FloatX', SELF.FloatX, ini)
    PUTINI(sec, 'FloatY', SELF.FloatY, ini)
    PUTINI(sec, 'FloatW', SELF.FloatW, ini)
    PUTINI(sec, 'FloatH', SELF.FloatH, ini)
  END
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Kind <> MTP:Group THEN CYCLE.
    PUTINI(sec, 'Open.' & CLIP(CHOOSE(SELF.Items.Tag <> '', SELF.Items.Tag, SELF.Items.Text)), SELF.Items.Expanded, ini)
  END

MyTaskPanelClass.LoadState PROCEDURE
i                      LONG
lst                    STRING(4000)
pair                   STRING(400)
p                      LONG
q                      LONG
e                      LONG
id                     LONG
sec                    STRING(60)
v                      LONG
ini                    STRING(400)
  CODE
  IF ~SELF.IniFile THEN RETURN.
  ini = SELF.IniName()
  sec = CHOOSE(SELF.IniSection = '', 'TaskPanel', SELF.IniSection)
  SELF.DockSide   = GETINI(sec, 'Dock', SELF.DockSide, ini)
  SELF.PanelWidth = GETINI(sec, 'Width', SELF.PanelWidth, ini)
  IF SELF.PanelWidth < SELF.MinWidth THEN SELF.PanelWidth = SELF.MinWidth.
  IF SELF.PanelWidth > SELF.MaxWidth THEN SELF.PanelWidth = SELF.MaxWidth.
  SELF.Rail     = GETINI(sec, 'Rail', SELF.Rail, ini)
  SELF.AutoHide = GETINI(sec, 'AutoHide', SELF.AutoHide, ini)
  IF SELF.Rail THEN SELF.AutoHide = 0.
  IF SELF.Favorites THEN SELF.SetRefs(1, SELF.KeyList(GETINI(sec, 'Favourites', '', ini))).
  IF SELF.RecentMax > 0 THEN SELF.SetRefs(2, SELF.KeyList(GETINI(sec, 'Recent', '', ini))).
  SELF.GroupOrder = SELF.KeyList(GETINI(sec, 'GroupOrder', '', ini))
  lst = SELF.KeyList(GETINI(sec, 'Hidden', '', ini))
  p = 2
  LOOP
    q = INSTRING(',', lst, 1, p)
    IF ~q THEN BREAK.
    SELF.HideItem(SUB(lst, p, q - p), 1)
    p = q + 1
  END
  lst = GETINI(sec, 'Uses', '', ini)            ! 'T:cust=12|P:Menu/Browse/Countries=3'
  p = 1
  LOOP WHILE p <= LEN(CLIP(lst))
    q = INSTRING('|', lst, 1, p)
    IF ~q THEN q = LEN(CLIP(lst)) + 1.
    pair = SUB(lst, p, q - p)
    e = INSTRING('=', pair, 1, 1)
    LOOP WHILE e AND INSTRING('=', pair, 1, e + 1)
      e = INSTRING('=', pair, 1, e + 1)
    END
    IF e
      id = SELF.FindKey(SUB(pair, 1, e - 1))
      IF id
        SELF.Items.Id = id
        GET(SELF.Items, SELF.Items.Id)
        SELF.Items.Uses = SUB(pair, e + 1, 12)
        PUT(SELF.Items)
      END
    END
    p = q + 1
  END
  SELF.RebuildMost()
  SELF.FloatW = GETINI(sec, 'FloatW', SELF.FloatW, ini)
  IF SELF.FloatW > 0
    SELF.FloatX = GETINI(sec, 'FloatX', SELF.FloatX, ini)
    SELF.FloatY = GETINI(sec, 'FloatY', SELF.FloatY, ini)
    SELF.FloatH = GETINI(sec, 'FloatH', SELF.FloatH, ini)
  END
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Kind <> MTP:Group THEN CYCLE.
    v = GETINI(sec, 'Open.' & CLIP(CHOOSE(SELF.Items.Tag <> '', SELF.Items.Tag, SELF.Items.Text)), SELF.Items.Expanded, ini)
    SELF.Items.Expanded = CHOOSE(v <> 0, 1, 0)
    SELF.Items.Reveal = SELF.Items.Expanded
    PUT(SELF.Items)
  END

! ============================================================================
!  mirroring the window's own MENUBAR
!
!  Measured on Clarion 12 by ClaCommandBar (examples\MenuMirrorTest):
!   * 0{PROP:MenuBar} is the MENUBAR's equate (not always - so we also scan).
!   * A MENU answers PROP:Child,n with its children in declaration order,
!     submenus and separators included. The MENUBAR itself does not, so the
!     top-level menus are found by scanning for CREATE:menu controls whose
!     PROP:Parent is the menubar.
!   * Menu controls land in four equate ranges:
!                          with a USE        without
!       WINDOW             1, 2, 3 ...       32768 upward
!       APPLICATION        -1, -2, -3 ...    32767 downward
!     and a frame answers LASTFIELD() = 0. Top-level menus are sorted on
!     the lowest RANK of any named control in their subtree.
!   * An ITEM with empty text is a separator.
! ============================================================================
MyTaskPanelClass.MirrorMenu PROCEDURE(BYTE hideMenu=0, <STRING skip>, BYTE oneGroup=0)
MenuQ                  QUEUE,PRE(MQ)
Feq                      SIGNED
Order                    LONG
                       END
mb                     SIGNED
pass                   SIGNED
lo                     SIGNED
hi                     SIGNED
stp                    SIGNED
feq                    SIGNED
i                      LONG
n                      LONG
g                      LONG
top                    LONG
txt                    STRING(120)
skipList               STRING(512)
v                      LONG
  CODE
  IF SELF.Win &= NULL THEN RETURN 0.
  skipList = ''
  IF ~OMITTED(skip) THEN skipList = '|' & UPPER(CLIP(skip)) & '|'.
  SETTARGET(SELF.Win)
  mb = 0{PROP:MenuBar}
  SETTARGET()
  IF ~mb THEN mb = SELF.FindMenuBar().
  IF ~mb THEN RETURN 0.
  SETTARGET(SELF.Win)
  FREE(MenuQ)
  LOOP pass = 1 TO 4
    CASE pass
    OF 1
      lo = -1
      hi = -2048
      stp = -1
    OF 2
      lo = 1
      hi = LASTFIELD()
      stp = 1
    OF 3
      lo = 32767
      hi = 32767 - 1023
      stp = -1
    ELSE
      lo = 32768
      hi = 32768 + 1023
      stp = 1
    END
    IF stp > 0 AND hi < lo THEN CYCLE.
    LOOP feq = lo TO hi BY stp
      IF feq = mb THEN CYCLE.
      IF feq{PROP:Type} <> CREATE:menu THEN CYCLE.
      IF feq{PROP:Parent} <> mb THEN CYCLE.
      CLEAR(MenuQ)
      MQ:Feq   = feq
      MQ:Order = SELF.MinFeqIn(feq)
      ADD(MenuQ)
    END
  END
  SORT(MenuQ, MQ:Order)
  n = 0
  g = 0
  LOOP i = 1 TO RECORDS(MenuQ)
    GET(MenuQ, i)
    feq = MQ:Feq
    txt = SELF.CleanText(feq{PROP:Text})
    IF skipList AND INSTRING('|' & UPPER(CLIP(txt)) & '|', skipList, 1, 1) THEN CYCLE.
    IF oneGroup
      IF ~g THEN g = SELF.AddGroup(SELF.Txt('Menu', 'Men<250>'), 'menu').
      top = SELF.AddItem(g, txt, CHOOSE(SELF.AutoGlyphs = 1, SELF.GuessGlyph(txt), ''))
    ELSE
      top = SELF.AddGroup(txt, CHOOSE(SELF.AutoGlyphs = 1, SELF.GuessGlyph(txt), ''))
    END
    SELF.Items.Id = top
    GET(SELF.Items, SELF.Items.Id)
    SELF.Items.Mirrored = 1
    v = feq{PROP:Disable}
    IF v THEN SELF.Items.Enabled = 0.
    PUT(SELF.Items)
    SELF.MirrorInto(top, feq)
    n += 1
  END
  FREE(MenuQ)
  SETTARGET()
  IF hideMenu AND n
    SELF.HideMenu = 1
    SELF.HostMenu = mtp_GetMenu(SELF.HostHwnd)
    IF SELF.HostMenu
      mtp_SetMenu(SELF.HostHwnd, 0)
      mtp_DrawMenuBar(SELF.HostHwnd)
    END
    SELF.MenuTicks = 6                         ! the runtime re-attaches it while opening
  END
  SELF.Invalidate()
  RETURN n

!  One level of the menu. Assumes SETTARGET(SELF.Win).
MyTaskPanelClass.MirrorInto PROCEDURE(LONG pid, SIGNED menuFeq)
n                      SIGNED
child                  SIGNED
ty                     LONG
sub                    LONG
row                    LONG
txt                    STRING(256)
ic                     STRING(255)
v                      LONG
  CODE
  LOOP n = 1 TO 512
    child = menuFeq{PROP:Child, n}
    IF ~child THEN BREAK.
    ty  = child{PROP:Type}
    txt = child{PROP:Text}
    IF ty = CREATE:menu
      sub = SELF.AddItem(pid, txt, CHOOSE(SELF.AutoGlyphs = 1, SELF.GuessGlyph(SELF.CleanText(txt)), ''))
      SELF.Items.Id = sub
      GET(SELF.Items, SELF.Items.Id)
      SELF.Items.Mirrored = 1
      v = child{PROP:Disable}
      IF v THEN SELF.Items.Enabled = 0.
      PUT(SELF.Items)
      SELF.MirrorInto(sub, child)
      CYCLE
    END
    IF ty <> CREATE:item THEN CYCLE.
    IF ~txt
      SELF.AddSeparator(pid)
      CYCLE
    END
    row = SELF.AddItem(pid, txt, CHOOSE(SELF.AutoGlyphs = 1, SELF.GuessGlyph(SELF.CleanText(txt)), ''), , child)
    SELF.Items.Id = row
    GET(SELF.Items, SELF.Items.Id)
    SELF.Items.Mirrored = 1
    v = child{PROP:Key}
    IF v THEN SELF.Items.Shortcut = SELF.KeyText(v).
    v = child{PROP:Disable}
    IF v THEN SELF.Items.Enabled = 0.
    v = child{PROP:Checked}
    IF v THEN SELF.Items.Checked = 1.
    ic = child{PROP:Icon}
    IF ic AND VAL(ic[1]) <> 255                 ! not one of the built-in ICON: equates
      SELF.Items.IconFile = ic
      SELF.LoadIcon()
    END
    PUT(SELF.Items)
  END

!  Re-read enabled / checked / text from the original menu ITEMs. Called
!  when the mouse comes into the panel, so what you see is current.
MyTaskPanelClass.SyncMirror PROCEDURE
i                      LONG
v                      LONG
en                     BYTE
ch                     BYTE
dirty                  BYTE
  CODE
  IF SELF.Win &= NULL THEN RETURN.
  dirty = 0
  SETTARGET(SELF.Win)
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF ~SELF.Items.Mirrored OR ~SELF.Items.Feq THEN CYCLE.
    v = SELF.Items.Feq{PROP:Disable}
    en = CHOOSE(v = 0, 1, 0)
    v = SELF.Items.Feq{PROP:Checked}
    ch = CHOOSE(v = 0, 0, 1)
    IF en <> SELF.Items.Enabled OR ch <> SELF.Items.Checked
      SELF.Items.Enabled = en
      SELF.Items.Checked = ch
      PUT(SELF.Items)
      dirty = 1
    END
  END
  SETTARGET()
  IF dirty THEN SELF.Invalidate().

MyTaskPanelClass.MenuRank PROCEDURE(SIGNED feq)
  CODE
  IF feq < 0 THEN RETURN -feq.
  IF feq >= 32768 THEN RETURN feq - 32767.
  IF feq > 16384 THEN RETURN 32768 - feq.
  RETURN feq

MyTaskPanelClass.MinFeqIn PROCEDURE(SIGNED menuFeq)
n                      SIGNED
child                  SIGNED
best                   LONG
sub                    LONG
  CODE
  best = 0
  IF ABS(menuFeq) <= 16384 THEN best = SELF.MenuRank(menuFeq).
  LOOP n = 1 TO 512
    child = menuFeq{PROP:Child, n}
    IF ~child THEN BREAK.
    IF ABS(child) <= 16384
      sub = SELF.MenuRank(child)
      IF sub > 0 AND (best = 0 OR sub < best) THEN best = sub.
    END
    IF child{PROP:Type} = CREATE:menu
      sub = SELF.MinFeqIn(child)
      IF sub > 0 AND (best = 0 OR sub < best) THEN best = sub.
    END
  END
  IF ~best THEN best = 1000000 + SELF.MenuRank(menuFeq).
  RETURN best

MyTaskPanelClass.FindMenuBar PROCEDURE
pass                   SIGNED
lo                     SIGNED
hi                     SIGNED
stp                    SIGNED
feq                    SIGNED
res                    SIGNED
  CODE
  IF SELF.Win &= NULL THEN RETURN 0.
  res = 0
  SETTARGET(SELF.Win)
  LOOP pass = 1 TO 4
    CASE pass
    OF 1
      lo = -1
      hi = -2048
      stp = -1
    OF 2
      lo = 1
      hi = LASTFIELD()
      stp = 1
    OF 3
      lo = 32767
      hi = 32767 - 1023
      stp = -1
    ELSE
      lo = 32768
      hi = 32768 + 1023
      stp = 1
    END
    IF stp > 0 AND hi < lo THEN CYCLE.
    LOOP feq = lo TO hi BY stp
      IF feq{PROP:Type} = CREATE:menubar
        res = feq
        BREAK
      END
    END
    IF res THEN BREAK.
  END
  SETTARGET()
  RETURN res

MyTaskPanelClass.KeyText PROCEDURE(LONG keycode)
vk                     LONG
cm                     LONG
res                    STRING(40)
nm                     STRING(12)
  CODE
  IF ~keycode THEN RETURN ''.
  vk = BAND(keycode, 0FFh)
  cm = BAND(BSHIFT(keycode, -8), 0FFh)
  nm = ''
  CASE vk
  OF 8   ; nm = 'Backspace'
  OF 9   ; nm = 'Tab'
  OF 13  ; nm = 'Enter'
  OF 27  ; nm = 'Esc'
  OF 32  ; nm = 'Space'
  OF 33  ; nm = 'PgUp'
  OF 34  ; nm = 'PgDn'
  OF 35  ; nm = 'End'
  OF 36  ; nm = 'Home'
  OF 45  ; nm = 'Ins'
  OF 46  ; nm = 'Del'
  ELSE
    IF vk >= 112 AND vk <= 123
      nm = 'F' & (vk - 111)
    ELSIF (vk >= 48 AND vk <= 57) OR (vk >= 65 AND vk <= 90)
      nm = CHR(vk)
    END
  END
  IF ~nm THEN RETURN ''.
  res = ''
  IF BAND(cm, 2) THEN res = 'Ctrl+'.
  IF BAND(cm, 4) THEN res = CLIP(res) & 'Alt+'.
  IF BAND(cm, 1) THEN res = CLIP(res) & 'Shift+'.
  RETURN CLIP(res) & CLIP(nm)

!  A plausible icon from the words in a caption (English and Spanish), so a
!  mirrored menu does not arrive as a wall of bare text.
MyTaskPanelClass.GuessGlyph PROCEDURE(STRING txt)
t                      STRING(130)
  CODE
  t = ' ' & LOWER(CLIP(txt)) & ' '
  IF INSTRING('exit', t, 1, 1) OR INSTRING('salir', t, 1, 1) OR INSTRING('quit', t, 1, 1) THEN RETURN 'exit'.
  IF INSTRING('print', t, 1, 1) OR INSTRING('imprim', t, 1, 1) THEN RETURN 'print'.
  IF INSTRING('about', t, 1, 1) OR INSTRING('acerca', t, 1, 1) THEN RETURN 'info'.
  IF INSTRING('help', t, 1, 1) OR INSTRING('ayuda', t, 1, 1) OR INSTRING('content', t, 1, 1) OR INSTRING('conteni', t, 1, 1) THEN RETURN 'help'.
  IF INSTRING('export', t, 1, 1) THEN RETURN 'export'.
  IF INSTRING('import', t, 1, 1) THEN RETURN 'import'.
  IF INSTRING('report', t, 1, 1) OR INSTRING('informe', t, 1, 1) OR INSTRING('listado', t, 1, 1) THEN RETURN 'report'.
  IF INSTRING('chart', t, 1, 1) OR INSTRING('graf', t, 1, 1) OR INSTRING('statist', t, 1, 1) OR INSTRING('estad', t, 1, 1) THEN RETURN 'chart'.
  IF INSTRING('setup', t, 1, 1) OR INSTRING('option', t, 1, 1) OR INSTRING('opcion', t, 1, 1) OR INSTRING('config', t, 1, 1) OR INSTRING('setting', t, 1, 1) OR INSTRING('prefer', t, 1, 1) THEN RETURN 'gear'.
  IF INSTRING('backup', t, 1, 1) OR INSTRING('respald', t, 1, 1) OR INSTRING('copia de seg', t, 1, 1) THEN RETURN 'backup'.
  IF INSTRING('restor', t, 1, 1) OR INSTRING('restaur', t, 1, 1) THEN RETURN 'restore'.
  IF INSTRING('tile', t, 1, 1) OR INSTRING('mosaico', t, 1, 1) THEN RETURN 'tile'.
  IF INSTRING('cascad', t, 1, 1) THEN RETURN 'cascade'.
  IF INSTRING('window', t, 1, 1) OR INSTRING('ventana', t, 1, 1) THEN RETURN 'window'.
  IF INSTRING('user', t, 1, 1) OR INSTRING('usuario', t, 1, 1) THEN RETURN 'users'.
  IF INSTRING('password', t, 1, 1) OR INSTRING('contrase', t, 1, 1) OR INSTRING('login', t, 1, 1) THEN RETURN 'key'.
  IF INSTRING('customer', t, 1, 1) OR INSTRING('client', t, 1, 1) OR INSTRING('employee', t, 1, 1) OR INSTRING('emplead', t, 1, 1) OR INSTRING('contact', t, 1, 1) THEN RETURN 'user'.
  IF INSTRING('product', t, 1, 1) OR INSTRING('item', t, 1, 1) OR INSTRING('articul', t, 1, 1) OR INSTRING('invent', t, 1, 1) THEN RETURN 'box'.
  IF INSTRING('invoice', t, 1, 1) OR INSTRING('factur', t, 1, 1) OR INSTRING('payment', t, 1, 1) OR INSTRING('pago', t, 1, 1) THEN RETURN 'money'.
  IF INSTRING('order', t, 1, 1) OR INSTRING('pedido', t, 1, 1) OR INSTRING('venta', t, 1, 1) OR INSTRING('sale', t, 1, 1) THEN RETURN 'cart'.
  IF INSTRING('supplier', t, 1, 1) OR INSTRING('proveed', t, 1, 1) OR INSTRING('ship', t, 1, 1) OR INSTRING('envio', t, 1, 1) THEN RETURN 'truck'.
  IF INSTRING('find', t, 1, 1) OR INSTRING('search', t, 1, 1) OR INSTRING('buscar', t, 1, 1) THEN RETURN 'search'.
  IF INSTRING('calendar', t, 1, 1) OR INSTRING('calendario', t, 1, 1) OR INSTRING('agenda', t, 1, 1) THEN RETURN 'calendar'.
  IF INSTRING('mail', t, 1, 1) OR INSTRING('correo', t, 1, 1) THEN RETURN 'mail'.
  IF INSTRING('geogra', t, 1, 1) OR INSTRING('countr', t, 1, 1) OR INSTRING('pais', t, 1, 1) THEN RETURN 'globe'.
  IF INSTRING('web', t, 1, 1) OR INSTRING('internet', t, 1, 1) OR INSTRING('online', t, 1, 1) THEN RETURN 'globe'.
  IF INSTRING('browse', t, 1, 1) OR INSTRING('catalog', t, 1, 1) OR INSTRING('table', t, 1, 1) OR INSTRING('tabla', t, 1, 1) OR INSTRING('maint', t, 1, 1) OR INSTRING('mantenim', t, 1, 1) THEN RETURN 'table'.
  IF INSTRING(' file ', t, 1, 1) OR INSTRING('archivo', t, 1, 1) OR INSTRING('open', t, 1, 1) OR INSTRING('abrir', t, 1, 1) THEN RETURN 'folder'.
  IF INSTRING(' new ', t, 1, 1) OR INSTRING('nuevo', t, 1, 1) OR INSTRING(' add', t, 1, 1) OR INSTRING('agregar', t, 1, 1) THEN RETURN 'plus'.
  IF INSTRING('edit', t, 1, 1) OR INSTRING('cut', t, 1, 1) OR INSTRING('copy', t, 1, 1) OR INSTRING('paste', t, 1, 1) OR INSTRING('copiar', t, 1, 1) THEN RETURN 'doc'.
  IF INSTRING('tool', t, 1, 1) OR INSTRING('herram', t, 1, 1) OR INSTRING('utilit', t, 1, 1) THEN RETURN 'tools'.
  RETURN ''

! ============================================================================
!  the panel windows and the room they take
! ============================================================================
MyTaskPanelClass.MakeWindows PROCEDURE
wc                     GROUP                    ! WNDCLASSA
wcStyle                  LONG
wcWndProc                LONG
wcClsExtra               LONG
wcWndExtra               LONG
wcInst                   LONG
wcIcon                   LONG
wcCursor                 LONG
wcBack                   LONG
wcMenuName               LONG
wcClassName              LONG
                       END
inst                   LONG
owner                  LONG
st                     LONG
title                  CSTRING(81)
  CODE
  inst = mtp_GetModuleHandle(0)
  IF ~MTP_Registered
    CLEAR(wc)
    wc.wcStyle     = 3                            ! CS_HREDRAW | CS_VREDRAW
    wc.wcWndProc   = ADDRESS(MTP_WndProc)
    wc.wcInst      = inst
    wc.wcCursor    = mtp_LoadCursor(0, 32512)     ! IDC_ARROW
    wc.wcClassName = ADDRESS(MTP_ClassName)
    mtp_RegisterClass(ADDRESS(wc))
    MTP_Registered = 1
  END
  IF ~SELF.DockHwnd OR ~mtp_IsWindow(SELF.DockHwnd)
    st = BOR(MTP:WS_CHILD, MTP:WS_CLIPSIBLINGS)
    SELF.DockHwnd = mtp_CreateWindowEx(0, ADDRESS(MTP_ClassName), 0, st, 0, 0, 10, 10, SELF.HostHwnd, 0, inst, 0)
    IF SELF.DockHwnd
      MTPM:Hwnd = SELF.DockHwnd
      MTPM:Kind = 1
      MTPM:OldProc = 0
      MTPM:Obj &= SELF
      ADD(MTP_Map, MTPM:Hwnd)
    END
  END
  IF ~SELF.FloatHwnd OR ~mtp_IsWindow(SELF.FloatHwnd)
    owner = mtp_GetAncestor(SELF.HostHwnd, 2)   ! GA_ROOT
    title = CLIP(SELF.Title)
    st = BOR(BOR(BOR(BOR(MTP:WS_POPUP, MTP:WS_CAPTION), MTP:WS_SYSMENU), MTP:WS_THICKFRAME), MTP:WS_CLIPCHILDREN)
    SELF.FloatHwnd = mtp_CreateWindowEx(MTP:WS_EX_TOOLWINDOW, ADDRESS(MTP_ClassName), ADDRESS(title), st, 0, 0, 200, 300, owner, 0, inst, 0)
    IF SELF.FloatHwnd
      MTPM:Hwnd = SELF.FloatHwnd
      MTPM:Kind = 1
      MTPM:OldProc = 0
      MTPM:Obj &= SELF
      ADD(MTP_Map, MTPM:Hwnd)
    END
  END
  IF ~MTP_PeekReg
    CLEAR(wc)
    wc.wcStyle     = 020003h                      ! CS_DROPSHADOW | CS_HREDRAW | CS_VREDRAW
    wc.wcWndProc   = ADDRESS(MTP_WndProc)
    wc.wcInst      = inst
    wc.wcCursor    = mtp_LoadCursor(0, 32512)
    wc.wcClassName = ADDRESS(MTP_PeekClass)
    mtp_RegisterClass(ADDRESS(wc))
    MTP_PeekReg = 1
  END
  IF ~SELF.PeekHwnd OR ~mtp_IsWindow(SELF.PeekHwnd)
    owner = mtp_GetAncestor(SELF.HostHwnd, 2)
    SELF.PeekHwnd = mtp_CreateWindowEx(08000080h, ADDRESS(MTP_PeekClass), 0, MTP:WS_POPUP, 0, 0, 10, 10, owner, 0, inst, 0)   ! NOACTIVATE|TOOLWINDOW
    IF SELF.PeekHwnd
      MTPM:Hwnd = SELF.PeekHwnd
      MTPM:Kind = 1
      MTPM:OldProc = 0
      MTPM:Obj &= SELF
      ADD(MTP_Map, MTPM:Hwnd)
    END
  END
  IF ~SELF.TipHwnd OR ~mtp_IsWindow(SELF.TipHwnd)  ! the description card: the mouse goes through it
    owner = mtp_GetAncestor(SELF.HostHwnd, 2)
    SELF.TipHwnd = mtp_CreateWindowEx(080800A0h, ADDRESS(MTP_PeekClass), 0, MTP:WS_POPUP, 0, 0, 10, 10, owner, 0, inst, 0)   ! NOACTIVATE|LAYERED|TOOLWINDOW|TRANSPARENT
    IF SELF.TipHwnd
      mtp_SetLayeredAttr(SELF.TipHwnd, 0, 255, 2)
      MTPM:Hwnd = SELF.TipHwnd
      MTPM:Kind = 1
      MTPM:OldProc = 0
      MTPM:Obj &= SELF
      ADD(MTP_Map, MTPM:Hwnd)
    END
  END
  SELF.AcceptDrops()
  !  Without WS_CLIPCHILDREN the host paints straight over the panel; the
  !  style only takes effect once the frame is recalculated.
  st = mtp_GetWindowLong(SELF.HostHwnd, -16)
  IF ~BAND(st, MTP:WS_CLIPCHILDREN)
    mtp_SetWindowLong(SELF.HostHwnd, -16, BOR(st, MTP:WS_CLIPCHILDREN))
    mtp_SetWindowPos(SELF.HostHwnd, 0, 0, 0, 0, 0, 0037h)
  END
  IF SELF.MenuTicks AND SELF.DockHwnd
    mtp_SetTimer(SELF.DockHwnd, 3, 250, 0)
  END

MyTaskPanelClass.ReserveW PROCEDURE
  CODE
  IF SELF.Visible AND SELF.DockSide <> MTP:Float AND SELF.DockHwnd
    IF SELF.Rail THEN RETURN SELF.RailW().
    IF SELF.AutoHide THEN RETURN SELF.Px(6).    ! the edge it waits in; out, it lies over the host
    RETURN SELF.PanelWidth
  END
  RETURN 0

MyTaskPanelClass.HookKids PROCEDURE
child                  LONG
i                      LONG
found                  BYTE
r                      LIKE(MTP_Rect)
  CODE
  child = mtp_GetWindow(SELF.HostHwnd, 5)       ! GW_CHILD
  LOOP WHILE child
    IF child <> SELF.DockHwnd AND child <> SELF.FloatHwnd
      found = 0
      LOOP i = 1 TO RECORDS(SELF.Kids)
        GET(SELF.Kids, i)
        IF SELF.Kids.Hwnd = child
          found = 1
          BREAK
        END
      END
      IF ~found
        MTPM:Hwnd = child
        GET(MTP_Map, MTPM:Hwnd)
        IF ~ERRORCODE() THEN found = 1.         ! another panel already holds it
      END
      IF ~found
        mtp_GetWindowRect(child, ADDRESS(r))
        mtp_ScreenToClient(SELF.HostHwnd, ADDRESS(r))
        mtp_ScreenToClient(SELF.HostHwnd, ADDRESS(r) + 8)
        CLEAR(SELF.Kids)
        SELF.Kids.Hwnd = child
        SELF.Kids.L = r.X1
        SELF.Kids.T = r.Y1
        SELF.Kids.R = r.X2
        SELF.Kids.B = r.Y2
        SELF.Kids.OldProc = mtp_SetWindowLong(child, -4, ADDRESS(MTP_KidProc))
        ADD(SELF.Kids)
        MTPM:Hwnd = child
        MTPM:Kind = 2
        MTPM:OldProc = SELF.Kids.OldProc
        MTPM:Obj &= SELF
        ADD(MTP_Map, MTPM:Hwnd)
      END
    END
    child = mtp_GetWindow(child, 2)             ! GW_HWNDNEXT
  END

MyTaskPanelClass.UnhookKids PROCEDURE
i                      LONG
  CODE
  LOOP i = RECORDS(SELF.Kids) TO 1 BY -1
    GET(SELF.Kids, i)
    MTPM:Hwnd = SELF.Kids.Hwnd
    GET(MTP_Map, MTPM:Hwnd)
    IF mtp_IsWindow(SELF.Kids.Hwnd)
      IF mtp_GetWindowLong(SELF.Kids.Hwnd, -4) = ADDRESS(MTP_KidProc)
        mtp_SetWindowLong(SELF.Kids.Hwnd, -4, SELF.Kids.OldProc)
        IF ~ERRORCODE() THEN DELETE(MTP_Map).
      ELSIF ~ERRORCODE()
        !  Someone subclassed it after us: we cannot step out of the chain,
        !  so stay in it as a pass-through that no longer needs this object.
        MTPM:Kind = 3
        MTPM:Obj &= NULL
        PUT(MTP_Map)
      END
      mtp_SetWindowPos(SELF.Kids.Hwnd, 0, SELF.Kids.L, SELF.Kids.T, SELF.Kids.R - SELF.Kids.L, SELF.Kids.B - SELF.Kids.T, MTP:SWP_Replay)
    ELSIF ~ERRORCODE()
      DELETE(MTP_Map)
    END
  END
  FREE(SELF.Kids)

MyTaskPanelClass.ForgetKid PROCEDURE(LONG hwnd)
i                      LONG
  CODE
  LOOP i = RECORDS(SELF.Kids) TO 1 BY -1
    GET(SELF.Kids, i)
    IF SELF.Kids.Hwnd = hwnd THEN DELETE(SELF.Kids).
  END

!  WM_WINDOWPOSCHANGING on one of the host's own children, after the host
!  has had its say. Remember what it asked for, then narrow a FILLER (the
!  MDI client, the window's client) by the panel. A BAND (the toolbar) is
!  left alone. Show/hide/z-order changes carry no geometry and are ignored.
MyTaskPanelClass.KidPosChanging PROCEDURE(LONG hwnd, LONG lp)
wp                     LIKE(MTP_WndPos)
pc                     LIKE(MTP_Rect)
i                      LONG
nl                     LONG
nt                     LONG
nr                     LONG
nb                     LONG
res                    LONG
  CODE
  mtp_MemCpy(ADDRESS(wp), lp, SIZE(wp))
  !  NOMOVE|NOSIZE is a show, a hide or a z-order change - no layout. But
  !  Clarion's MDI client procedure also VETOES a move it did not ask for by
  !  setting exactly those flags, so our own replay has to push through.
  IF BAND(wp.wFlags, 3) = 3 AND ~SELF.Replaying THEN RETURN.
  LOOP i = 1 TO RECORDS(SELF.Kids)
    GET(SELF.Kids, i)
    IF SELF.Kids.Hwnd = hwnd THEN BREAK.
  END
  IF SELF.Kids.Hwnd <> hwnd THEN RETURN.
  nl = CHOOSE(BAND(wp.wFlags, 2) <> 0, SELF.Kids.L, wp.wX)
  nt = CHOOSE(BAND(wp.wFlags, 2) <> 0, SELF.Kids.T, wp.wY)
  nr = nl + CHOOSE(BAND(wp.wFlags, 1) <> 0, SELF.Kids.R - SELF.Kids.L, wp.wCX)
  nb = nt + CHOOSE(BAND(wp.wFlags, 1) <> 0, SELF.Kids.B - SELF.Kids.T, wp.wCY)
  IF nr <= nl OR nb <= nt THEN RETURN.              ! the host parking it, not a layout
  SELF.Kids.L = nl
  SELF.Kids.T = nt
  SELF.Kids.R = nr
  SELF.Kids.B = nb
  PUT(SELF.Kids)
  res = SELF.ReserveW()
  mtp_GetClientRect(SELF.HostHwnd, ADDRESS(pc))
  IF res AND (nb - nt) * 10 > pc.Y2 * 6            ! a filler
    IF SELF.DockSide = MTP:Left THEN nl += res.
    IF SELF.DockSide = MTP:Right THEN nr -= res.
    IF nr <= nl THEN nr = nl + 1.
  END
  wp.wX  = nl
  wp.wY  = nt
  wp.wCX = nr - nl
  wp.wCY = nb - nt
  wp.wFlags = BOR(BAND(wp.wFlags, -4), 0100h)     ! clear NOSIZE|NOMOVE, add NOCOPYBITS
  mtp_MemCpy(lp, ADDRESS(wp), SIZE(wp))
  IF SELF.DockHwnd THEN mtp_PostMessage(SELF.DockHwnd, MTP:WM_APP_PLACE, 0, 0).

MyTaskPanelClass.PlaceDocked PROCEDURE
pc                     LIKE(MTP_Rect)
i                      LONG
nl                     LONG
nt                     LONG
nr                     LONG
nb                     LONG
w                      LONG
shown                  LONG
  CODE
  IF ~SELF.DockHwnd THEN RETURN.
  w = SELF.ReserveW()
  IF ~w
    mtp_ShowWindow(SELF.DockHwnd, 0)
    RETURN
  END
  mtp_GetClientRect(SELF.HostHwnd, ADDRESS(pc))
  nl = pc.X1
  nt = pc.Y1
  nr = pc.X2
  nb = pc.Y2
  LOOP i = 1 TO RECORDS(SELF.Kids)
    GET(SELF.Kids, i)
    IF ~mtp_IsWindowVisible(SELF.Kids.Hwnd) THEN CYCLE.
    IF (SELF.Kids.B - SELF.Kids.T) * 10 > pc.Y2 * 6
      nl = SELF.Kids.L
      nt = SELF.Kids.T
      nr = SELF.Kids.R
      nb = SELF.Kids.B
      BREAK
    END
  END
  IF SELF.AutoHide AND ~SELF.Rail               ! full width, only 'shown' of it inside the host
    shown = w + (SELF.PanelWidth - w) * SELF.Slide
    IF SELF.DockSide = MTP:Left
      mtp_SetWindowPos(SELF.DockHwnd, 0, nl - SELF.PanelWidth + shown, nt, SELF.PanelWidth, nb - nt, 0050h)
    ELSE
      mtp_SetWindowPos(SELF.DockHwnd, 0, nr - shown, nt, SELF.PanelWidth, nb - nt, 0050h)
    END
    RETURN
  END
  IF SELF.DockSide = MTP:Left
    mtp_SetWindowPos(SELF.DockHwnd, 0, nl, nt, w, nb - nt, 0050h)       ! HWND_TOP, NOACTIVATE|SHOWWINDOW
  ELSE
    mtp_SetWindowPos(SELF.DockHwnd, 0, nr - w, nt, w, nb - nt, 0050h)
  END

MyTaskPanelClass.ApplyLayout PROCEDURE
i                      LONG
want                   LONG
r                      LIKE(MTP_Rect)
  CODE
  IF ~SELF.Inited OR ~mtp_IsWindow(SELF.HostHwnd) THEN RETURN.
  !  An ordinary window can grow by the panel's width, so its controls keep
  !  their room. A frame never does - its MDI client simply gets narrower.
  IF SELF.GrowHost AND ~SELF.IsFrame
    want = SELF.ReserveW()
    IF want <> SELF.Grown
      mtp_GetWindowRect(SELF.HostHwnd, ADDRESS(r))
      mtp_SetWindowPos(SELF.HostHwnd, 0, 0, 0, r.X2 - r.X1 + want - SELF.Grown, r.Y2 - r.Y1, 0016h) ! NOMOVE|NOZORDER|NOACTIVATE
      SELF.Grown = want
    END
  END
  SELF.HookKids()
  LOOP i = 1 TO RECORDS(SELF.Kids)
    GET(SELF.Kids, i)
    IF ~mtp_IsWindow(SELF.Kids.Hwnd) THEN CYCLE.
    SELF.Replaying = 1
    mtp_SetWindowPos(SELF.Kids.Hwnd, 0, SELF.Kids.L, SELF.Kids.T, SELF.Kids.R - SELF.Kids.L, SELF.Kids.B - SELF.Kids.T, MTP:SWP_Replay)
    SELF.Replaying = 0
  END
  SELF.PlaceDocked()
  SELF.Invalidate()

MyTaskPanelClass.Invalidate PROCEDURE
  CODE
  IF SELF.DockHwnd THEN mtp_InvalidateRect(SELF.DockHwnd, 0, 0).
  IF SELF.FloatHwnd THEN mtp_InvalidateRect(SELF.FloatHwnd, 0, 0).
  IF SELF.PeekId AND SELF.PeekHwnd THEN mtp_InvalidateRect(SELF.PeekHwnd, 0, 0).

MyTaskPanelClass.StartAnim PROCEDURE
h                      LONG
  CODE
  h = CHOOSE(SELF.DockSide = MTP:Float, SELF.FloatHwnd, SELF.DockHwnd)
  IF ~h THEN RETURN.
  IF ~SELF.Animating
    SELF.Animating = 1
    mtp_SetTimer(h, 2, 15, 0)
  END

MyTaskPanelClass.StepAnim PROCEDURE
i                      LONG
d                      REAL
busy                   BYTE
  CODE
  busy = 0
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Reveal = SELF.Items.Expanded THEN CYCLE.
    d = SELF.Items.Expanded - SELF.Items.Reveal
    IF ABS(d) < 0.04
      SELF.Items.Reveal = SELF.Items.Expanded
    ELSE
      SELF.Items.Reveal += d * 0.34
      busy = 1
    END
    PUT(SELF.Items)
  END
  IF ~busy
    SELF.Animating = 0
    IF SELF.DockHwnd THEN mtp_KillTimer(SELF.DockHwnd, 2).
    IF SELF.FloatHwnd THEN mtp_KillTimer(SELF.FloatHwnd, 2).
  END
  SELF.Invalidate()

! ============================================================================
!  Hover. GDI switches the highlight on and off; the DirectX effects fade it:
!  the row under the mouse fades in while the one it left fades out.
! ============================================================================
MyTaskPanelClass.FxWanted PROCEDURE
  CODE
  IF SELF.Effects AND SELF.EngineInUse() = MTP:DirectX THEN RETURN 1.
  RETURN 0

MyTaskPanelClass.SetHover PROCEDURE(LONG id)
h                      LONG
t                      REAL
  CODE
  IF id = SELF.Hover THEN RETURN.
  IF SELF.FxWanted()
    t = CHOOSE(id = SELF.FadeId AND id <> 0, SELF.FadeT, 0)    ! coming back: carry on from where it was
    SELF.FadeId = SELF.Hover
    SELF.FadeT  = SELF.HoverT
    SELF.Hover  = id
    SELF.HoverT = t
    h = CHOOSE(SELF.DockSide = MTP:Float, SELF.FloatHwnd, SELF.DockHwnd)
    IF h AND ~SELF.Fading
      SELF.Fading = 1
      mtp_SetTimer(h, 4, 15, 0)
    END
  ELSE
    SELF.Hover  = id
    SELF.HoverT = 1
    SELF.FadeId = 0
  END
  SELF.Invalidate()

MyTaskPanelClass.HoverAmt PROCEDURE(LONG id)
  CODE
  IF id = 0 THEN RETURN 0.
  IF SELF.Hover <= -1000000 AND SELF.Hover > -2000000 AND SELF.ActItem(SELF.Hover) = SELF.Resolve(id) THEN RETURN 1.
  IF id = SELF.Hover THEN RETURN SELF.HoverT.
  IF id = SELF.FadeId THEN RETURN SELF.FadeT.
  RETURN 0

MyTaskPanelClass.StepFade PROCEDURE
  CODE
  SELF.HoverT += 0.2
  IF SELF.HoverT > 1 THEN SELF.HoverT = 1.
  SELF.FadeT -= 0.15
  IF SELF.FadeT <= 0
    SELF.FadeT  = 0
    SELF.FadeId = 0
  END
  IF SELF.HoverT >= 1 AND SELF.FadeT = 0
    SELF.Fading = 0
    IF SELF.DockHwnd THEN mtp_KillTimer(SELF.DockHwnd, 4).
    IF SELF.FloatHwnd THEN mtp_KillTimer(SELF.FloatHwnd, 4).
  END
  SELF.Invalidate()

!  The floating panel turns see-through while the mouse is elsewhere (DirectX
!  effects only) and solid again when the mouse comes back.
MyTaskPanelClass.SetFloatAlpha PROCEDURE(BYTE over)
ex                     LONG
  CODE
  IF ~SELF.FloatHwnd THEN RETURN.
  ex = mtp_GetWindowLong(SELF.FloatHwnd, -20)   ! GWL_EXSTYLE
  IF SELF.FxWanted() AND SELF.FloatOpacity > 0 AND SELF.FloatOpacity < 100
    IF ~BAND(ex, MTP:WS_EX_LAYERED) THEN mtp_SetWindowLong(SELF.FloatHwnd, -20, BOR(ex, MTP:WS_EX_LAYERED)).
    mtp_SetLayeredAttr(SELF.FloatHwnd, 0, CHOOSE(over = 1, 255, INT(SELF.FloatOpacity * 255 / 100)), 2)   ! LWA_ALPHA
  ELSIF BAND(ex, MTP:WS_EX_LAYERED)
    mtp_SetWindowLong(SELF.FloatHwnd, -20, BAND(ex, BXOR(-1, MTP:WS_EX_LAYERED)))
  END

!  While the floating panel is dragged: is the cursor at an edge of the host?
MyTaskPanelClass.CheckSnap PROCEDURE(BYTE final)
pt                     GROUP
PX                       LONG
PY                       LONG
                       END
r                      LIKE(MTP_Rect)
side                   BYTE
title                  CSTRING(120)
  CODE
  mtp_GetCursorPos(ADDRESS(pt))
  mtp_GetClientRect(SELF.HostHwnd, ADDRESS(r))
  mtp_ClientToScreen(SELF.HostHwnd, ADDRESS(r))
  mtp_ClientToScreen(SELF.HostHwnd, ADDRESS(r) + 8)
  side = 0
  IF SELF.AllowDock AND pt.PY >= r.Y1 AND pt.PY <= r.Y2
    IF pt.PX >= r.X1 - SELF.Px(10) AND pt.PX <= r.X1 + SELF.Px(44)
      side = MTP:Left
    ELSIF pt.PX <= r.X2 + SELF.Px(10) AND pt.PX >= r.X2 - SELF.Px(44)
      side = MTP:Right
    END
  END
  IF ~final
    IF side <> SELF.SnapSide
      SELF.SnapSide = side
      CASE side
      OF MTP:Left  ; title = SELF.Txt('Release to dock on the left', 'Suelte para acoplar a la izquierda')
      OF MTP:Right ; title = SELF.Txt('Release to dock on the right', 'Suelte para acoplar a la derecha')
      ELSE         ; title = CLIP(SELF.Title)
      END
      mtp_SetWindowText(SELF.FloatHwnd, ADDRESS(title))
    END
    RETURN
  END
  mtp_GetWindowRect(SELF.FloatHwnd, ADDRESS(r))
  SELF.FloatX = r.X1
  SELF.FloatY = r.Y1
  SELF.FloatW = r.X2 - r.X1
  SELF.FloatH = r.Y2 - r.Y1
  IF SELF.SnapSide
    title = CLIP(SELF.Title)
    mtp_SetWindowText(SELF.FloatHwnd, ADDRESS(title))
  END
  SELF.SnapSide = 0
  IF side THEN SELF.Dock(side).

!  The docked panel's title was dragged: float it under the cursor and let
!  Windows carry on moving it as if its caption had been grabbed.
MyTaskPanelClass.UndockAtCursor PROCEDURE
pt                     GROUP
PX                       LONG
PY                       LONG
                       END
  CODE
  mtp_ReleaseCapture()
  SELF.Drag = 0
  mtp_GetCursorPos(ADDRESS(pt))
  IF SELF.FloatW <= 0
    SELF.FloatW = SELF.PanelWidth + SELF.Px(16)
    SELF.FloatH = SELF.Px(420)
  END
  SELF.FloatX = pt.PX - SELF.FloatW / 2
  SELF.FloatY = pt.PY - SELF.Px(12)
  SELF.Dock(MTP:Float)
  !  Only while the button is really down: with it up, SC_MOVE falls back to
  !  moving the window with the arrow keys and waits for Enter.
  IF SELF.FloatHwnd AND BAND(mtp_GetAsyncKeyState(1), 08000h)
    mtp_PostMessage(SELF.FloatHwnd, 0112h, 0F012h, 0)  ! WM_SYSCOMMAND, SC_MOVE|HTCAPTION
  END

! ============================================================================
!  the window procedure
! ============================================================================
MyTaskPanelClass.WndMsg PROCEDURE(LONG hwnd, LONG msg, LONG wp, LONG lp, *BYTE handled)
x                      LONG
y                      LONG
hit                    LONG
floating               BYTE
pt                     GROUP
PX                       LONG
PY                       LONG
                       END
r                      LIKE(MTP_Rect)
d                      LONG
th                     LONG
  CODE
  floating = SELF.KindOf(hwnd)                  ! 0 docked, 1 floating, 2 the rail's pop-out, 3 the card
  IF floating = 3 AND msg <> 000Fh AND msg <> 0014h THEN RETURN 0.
  CASE msg
  OF 000Fh                                      ! WM_PAINT
    SELF.Paint(hwnd)
    handled = 1
    RETURN 0
  OF 0014h                                      ! WM_ERASEBKGND - painted in full by WM_PAINT
    handled = 1
    RETURN 1
  OF 0021h                                      ! WM_MOUSEACTIVATE: clicking must not steal focus
    handled = 1
    RETURN 3                                    ! MA_NOACTIVATE
  OF 0005h                                      ! WM_SIZE
    SELF.Invalidate()
  OF 0010h                                      ! WM_CLOSE (the floating panel's X)
    IF floating = 1
      SELF.HidePanel()
      handled = 1
      RETURN 0
    END
  OF MTP:WM_APP_PLACE
    SELF.PlaceDocked()
    handled = 1
    RETURN 0
  OF 0216h                                      ! WM_MOVING
    IF floating = 1 THEN SELF.CheckSnap(0).
  OF 0232h                                      ! WM_EXITSIZEMOVE
    IF floating = 1 THEN SELF.CheckSnap(1).
  OF 0215h                                      ! WM_CAPTURECHANGED
    SELF.Drag = 0
  OF 0113h                                      ! WM_TIMER
    CASE wp
    OF 1                                        ! has the mouse left?
      mtp_GetCursorPos(ADDRESS(pt))
      mtp_GetWindowRect(hwnd, ADDRESS(r))
      IF (pt.PX < r.X1 OR pt.PX >= r.X2 OR pt.PY < r.Y1 OR pt.PY >= r.Y2) AND ~SELF.Drag
        mtp_KillTimer(hwnd, 1)
        SELF.InHost = 0
        SELF.SetHover(0)
        SELF.HideTip()
        SELF.TipCand = 0
        IF floating = 1 THEN SELF.SetFloatAlpha(0).
        IF floating = 0 AND SELF.AutoHide AND ~SELF.HasFocus AND ~SELF.InMenu THEN SELF.StartSlide(0).
      END
    OF 2
      SELF.StepAnim()
    OF 4
      SELF.StepFade()
    OF 6                                        ! the rail's pop-out: has the mouse gone?
      SELF.PeekCheck()
    OF 7                                        ! auto-hide sliding in or out
      SELF.StepSlide()
    OF 8                                        ! the pause before the description card
      mtp_KillTimer(hwnd, 8)
      IF SELF.TipCand AND SELF.TipCand = SELF.Hover THEN SELF.ShowTip(SELF.TipCand, hwnd).
    OF 5                                        ! the search box's caret
      SELF.CaretOn = 1 - SELF.CaretOn
      SELF.Invalidate()
    OF 3                                        ! keep the real menu off while the frame settles
      IF SELF.HideMenu AND mtp_GetMenu(SELF.HostHwnd)
        mtp_SetMenu(SELF.HostHwnd, 0)
        mtp_DrawMenuBar(SELF.HostHwnd)
        SELF.ApplyLayout()
      END
      IF SELF.MenuTicks > 0 THEN SELF.MenuTicks -= 1.
      IF SELF.MenuTicks = 0 THEN mtp_KillTimer(hwnd, 3).
    END
    handled = 1
    RETURN 0
  OF 0020h                                      ! WM_SETCURSOR
    IF BAND(lp, 0FFFFh) = 1                     ! HTCLIENT
      mtp_GetCursorPos(ADDRESS(pt))
      mtp_ScreenToClient(hwnd, ADDRESS(pt))
      hit = SELF.HitTest(pt.PX, pt.PY, floating)
      IF SELF.Drag = 4
        mtp_SetCursor(mtp_LoadCursor(0, 32645))  ! IDC_SIZENS: reordering
      ELSIF hit = -4
        mtp_SetCursor(mtp_LoadCursor(0, 32644))  ! IDC_SIZEWE
      ELSIF hit = -6
        mtp_SetCursor(mtp_LoadCursor(0, 32513))  ! IDC_IBEAM
      ELSIF hit > 0 OR hit = -2 OR hit = -3 OR hit = -7 OR hit = -8 OR hit = -9 OR hit = -10 OR hit = -11 OR hit <= -1000000
        mtp_SetCursor(mtp_LoadCursor(0, 32649))  ! IDC_HAND
      ELSE
        mtp_SetCursor(mtp_LoadCursor(0, 32512))  ! IDC_ARROW
      END
      handled = 1
      RETURN 1
    END
  OF 0200h                                      ! WM_MOUSEMOVE
    x = MTP_Signed16(lp)
    y = MTP_Signed16(BSHIFT(lp, -16))
    IF ~SELF.InHost
      SELF.InHost = 1
      SELF.SyncMirror()
      mtp_SetTimer(hwnd, 1, 150, 0)
      IF floating = 1 THEN SELF.SetFloatAlpha(1).
      POST(MTP:Check, , SELF.HostThread)        ! the template re-checks its Show/Enable conditions
      IF floating = 0 AND SELF.AutoHide THEN SELF.StartSlide(1).
    END
    CASE SELF.Drag
    OF 1                                        ! the splitter
      mtp_GetCursorPos(ADDRESS(pt))
      d = pt.PX - SELF.DragX
      SELF.SetWidth(SELF.DragV + CHOOSE(SELF.DockSide = MTP:Left, d, -d))
    OF 2                                        ! the title: far enough to undock?
      mtp_GetCursorPos(ADDRESS(pt))
      IF ABS(pt.PX - SELF.DragX) + ABS(pt.PY - SELF.DragY) > SELF.Px(6)
        SELF.UndockAtCursor()
      END
    OF 3                                        ! the scroll thumb
      th = SELF.ViewH * SELF.ViewH / CHOOSE(SELF.ContentH > 0, SELF.ContentH, 1)
      IF th < SELF.Px(24) THEN th = SELF.Px(24).
      IF SELF.ViewH - th > 0
        SELF.ScrollY = SELF.DragV + (y - SELF.DragY) * (SELF.ContentH - SELF.ViewH) / (SELF.ViewH - th)
        SELF.Invalidate()
      END
    OF 4                                        ! reordering a group or a favourite
      SELF.DragOver(y)
    ELSE
      IF SELF.DragCand AND BAND(wp, 1) AND ABS(y - SELF.DragY) > SELF.Px(6)
        SELF.Drag = 4                           ! far enough: a drag, not a click
        SELF.Pressed = 0
        SELF.HideTip()
        mtp_SetCapture(hwnd)
        SELF.DragOver(y)
      ELSE
        hit = SELF.HitTest(x, y, floating)
        IF hit <> SELF.Hover THEN SELF.HideTip().
        SELF.SetHover(hit)
        IF SELF.ShowTips AND (hit > 0 OR (hit <= -1000000 AND hit > -2000000)) AND hit <> SELF.TipCand AND hit <> SELF.TipId
          SELF.TipCand = hit
          mtp_SetTimer(hwnd, 8, 600, 0)
        END
        IF SELF.Rail AND floating = 0 AND SELF.Hover > 0 AND SELF.Hover <> SELF.PeekId THEN SELF.ShowPeek(SELF.Hover).
      END
    END
    handled = 1
    RETURN 0
  OF 0201h                                      ! WM_LBUTTONDOWN
  OROF 0203h                                    ! WM_LBUTTONDBLCLK
    x = MTP_Signed16(lp)
    y = MTP_Signed16(BSHIFT(lp, -16))
    hit = SELF.HitTest(x, y, floating)
    mtp_GetCursorPos(ADDRESS(pt))
    SELF.HideTip()
    SELF.TipCand = 0
    CASE hit
    OF -4
      SELF.Drag  = 1
      SELF.DragX = pt.PX
      SELF.DragV = SELF.PanelWidth
      mtp_SetCapture(hwnd)
    OF -1
      IF SELF.AllowFloat
        SELF.Drag  = 2
        SELF.DragX = pt.PX
        SELF.DragY = pt.PY
        mtp_SetCapture(hwnd)
      END
    OF -5
      SELF.Drag  = 3
      SELF.DragY = y
      SELF.DragV = SELF.ScrollY
      mtp_SetCapture(hwnd)
    OF -6                                       ! the search box
      SELF.Focus()
    OF -7                                       ! its clear button
      SELF.SetSearch('')
      SELF.Focus()
    ELSE
      SELF.Pressed = hit
      SELF.DragCand = 0                         ! a group header or a favourite can be dragged
      IF hit > 0 AND floating <> 2 AND ~SELF.Rail AND CLIP(SELF.Search) = ''
        SELF.Items.Id = hit
        GET(SELF.Items, SELF.Items.Id)
        IF ~ERRORCODE()
          IF (SELF.Items.Kind = MTP:Group AND SELF.Items.Role = 0) OR (SELF.Items.Role = 3 AND SELF.Items.Parent = SELF.FavGroup AND SELF.FavGroup)
            SELF.DragCand = hit
            SELF.DragY = y
          END
        END
      END
      SELF.Invalidate()
    END
    handled = 1
    RETURN 0
  OF 0202h                                      ! WM_LBUTTONUP
    x = MTP_Signed16(lp)
    y = MTP_Signed16(BSHIFT(lp, -16))
    IF SELF.Drag
      IF SELF.Drag = 4 THEN SELF.DropDrag().
      SELF.Drag = 0
      SELF.DragCand = 0
      mtp_ReleaseCapture()
      handled = 1
      RETURN 0
    END
    hit = SELF.HitTest(x, y, floating)
    IF hit = SELF.Pressed AND hit <> 0
      SELF.Pressed = 0
      CASE hit
      OF -2
        SELF.OptionsMenu(hwnd)
      OF -3
        SELF.HidePanel()
      OF -8                                     ! the rail's expand button
        SELF.SetRail(0)
      OF -9                                     ! collapse to the rail
        SELF.SetRail(1)
      OF -10                                    ! Customize: Done
        SELF.Customize(0)
      OF -11                                    ! Customize: Reset
        SELF.ResetCustom()
      ELSE
        IF hit <= -2000000                      ! Customize: a group's eye
          SELF.Items.Id = -hit - 2000000
          GET(SELF.Items, SELF.Items.Id)
          IF ~ERRORCODE() THEN SELF.HideItem(SELF.Items.Id, 1 - SELF.Items.UserHidden).
        ELSIF hit <= -1000000                   ! a hover button
          SELF.ActClick(hit)
          IF floating = 2 THEN SELF.HidePeek().
        ELSIF hit > 0 AND SELF.Customizing      ! Customize: a row shows or hides; a header still opens
          SELF.Items.Id = hit
          GET(SELF.Items, SELF.Items.Id)
          IF ~ERRORCODE()
            IF SELF.Items.Kind = MTP:Group
              SELF.OnClickRow(hit, hwnd)
            ELSIF SELF.Items.Role <> 3
              SELF.HideItem(hit, 1 - SELF.Items.UserHidden)
            END
          END
        ELSIF hit > 0
          IF SELF.Rail AND floating = 0         ! a group icon: its pop-out
            SELF.ShowPeek(hit)
          ELSIF floating = 2                    ! in the pop-out: not its header
            IF hit <> SELF.PeekId
              SELF.OnClickRow(hit, hwnd)
              IF SELF.HasKids(hit) AND SELF.SubStyle = MTP:Inline
                SELF.ShowPeek(SELF.PeekId)      ! a submenu opened or closed: fit the pop-out to it
              ELSE
                SELF.HidePeek()
              END
            END
          ELSE
            SELF.KeyId = hit
            SELF.OnClickRow(hit, hwnd)
          END
        END
      END
    END
    SELF.Pressed = 0
    SELF.DragCand = 0
    SELF.Invalidate()
    handled = 1
    RETURN 0
  OF 0233h                                      ! WM_DROPFILES
    SELF.TakeDrop(hwnd, wp)
    handled = 1
    RETURN 0
  OF 0205h                                      ! WM_RBUTTONUP
    SELF.HideTip()
    SELF.MenuId = SELF.HitTest(MTP_Signed16(lp), MTP_Signed16(BSHIFT(lp, -16)), floating)
    IF SELF.MenuId < 0 THEN SELF.MenuId = 0.
    SELF.OptionsMenu(hwnd)
    handled = 1
    RETURN 0
  OF 020Ah                                      ! WM_MOUSEWHEEL
    SELF.HideTip()
    d = MTP_Signed16(BSHIFT(wp, -16))
    SELF.ScrollY -= d * SELF.Px(SELF.ItemHeight) * 3 / 120
    IF SELF.ScrollY < 0 THEN SELF.ScrollY = 0.
    SELF.Invalidate()
    handled = 1
    RETURN 0
  OF 0007h                                      ! WM_SETFOCUS: the keyboard is ours
    SELF.HasFocus = 1
    SELF.CaretOn = 1
    mtp_SetTimer(hwnd, 5, 530, 0)
    IF ~SELF.KeyId THEN SELF.MoveKey(1).
    POST(MTP:Check, , SELF.HostThread)
    SELF.Invalidate()
  OF 0008h                                      ! WM_KILLFOCUS
    SELF.HasFocus = 0
    mtp_KillTimer(hwnd, 5)
    IF floating = 0 AND SELF.AutoHide AND ~SELF.InHost THEN SELF.StartSlide(0).
    SELF.Invalidate()
  OF 0087h                                      ! WM_GETDLGCODE: arrows, Tab and Enter come to us,
    handled = 1                                 ! not to the host's dialog navigation
    RETURN 4                                    ! DLGC_WANTALLKEYS
  OF 0100h                                      ! WM_KEYDOWN
    IF SELF.KeyDown(hwnd, wp)
      handled = 1
      RETURN 0
    END
  OF 0102h                                      ! WM_CHAR: typing searches
    SELF.KeyChar(wp)
    handled = 1
    RETURN 0
  OF 0082h                                      ! WM_NCDESTROY
    IF hwnd = SELF.DockHwnd THEN SELF.DockHwnd = 0.
    IF hwnd = SELF.FloatHwnd THEN SELF.FloatHwnd = 0.
    IF hwnd = SELF.PeekHwnd THEN SELF.PeekHwnd = 0.
  END
  RETURN 0

MyTaskPanelClass.OnClickRow PROCEDURE(LONG id, LONG hwnd)
i                      LONG
kind                   BYTE
on                     BYTE
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  kind = SELF.Items.Kind
  IF kind = MTP:Group
    on = CHOOSE(SELF.Items.Expanded = 0, 1, 0)
    IF on AND SELF.Accordion
      LOOP i = 1 TO RECORDS(SELF.Items)
        GET(SELF.Items, i)
        IF SELF.Items.Kind = MTP:Group AND SELF.Items.Id <> id AND SELF.Items.Expanded
          SELF.Items.Expanded = 0
          IF ~SELF.Animate THEN SELF.Items.Reveal = 0.
          PUT(SELF.Items)
        END
      END
    END
    SELF.Expand(id, on)
    RETURN
  END
  IF ~SELF.Items.Enabled THEN RETURN.
  IF SELF.HasKids(id)
    IF SELF.SubStyle = MTP:Flyout
      SELF.FlyoutMenu(id, hwnd)
    ELSE
      SELF.Expand(id, CHOOSE(SELF.Items.Expanded = 0, 1, 0))
    END
    RETURN
  END
  IF CLIP(SELF.Search) <> '' THEN SELF.SetSearch('').
  SELF.Click(id)

MyTaskPanelClass.OptionsMenu PROCEDURE(LONG hwnd)
m                      LONG
pt                     GROUP
PX                       LONG
PY                       LONG
                       END
cmd                    LONG
t1                     CSTRING(64)
t2                     CSTRING(64)
t3                     CSTRING(64)
t4                     CSTRING(64)
t5                     CSTRING(64)
t6                     CSTRING(64)
t7                     CSTRING(64)
t8                     CSTRING(64)
t9                     CSTRING(64)
t10                    CSTRING(64)
t11                    CSTRING(64)
t12                    CSTRING(64)
t13                    CSTRING(64)
tgt                    LONG
i                      LONG
canHide                BYTE
r                      LIKE(MTP_Rect)
  CODE
  m = mtp_CreatePopupMenu()
  IF ~m THEN RETURN.
  t1 = SELF.Txt('Dock on the &left', 'Acoplar a la &izquierda')
  t2 = SELF.Txt('Dock on the &right', 'Acoplar a la &derecha')
  t3 = SELF.Txt('&Float', '&Flotante')
  t4 = SELF.Txt('&Expand all', '&Expandir todo')
  t5 = SELF.Txt('&Collapse all', '&Contraer todo')
  t6 = SELF.Txt('&Hide the panel', '&Ocultar el panel')
  !  On an item: favourite or not. On the Recent group or a row in it: clear it.
  tgt = SELF.Resolve(SELF.MenuId)
  IF SELF.Favorites AND SELF.MenuId > 0 AND SELF.IsAction(tgt)
    t7 = CHOOSE(SELF.IsFavorite(tgt) = 1, SELF.Txt('Remove from &favourites', 'Quitar de &favoritos'), SELF.Txt('Add to &favourites', 'Agregar a &favoritos'))
    mtp_AppendMenu(m, 0, 20, ADDRESS(t7))
    mtp_AppendMenu(m, 0800h, 0, 0)
  END
  canHide = 0                                   ! an item or group of the program's (not a Favourites row)
  IF SELF.MenuId > 0
    SELF.Items.Id = SELF.MenuId
    GET(SELF.Items, SELF.Items.Id)
    IF ~ERRORCODE() AND SELF.Items.Role = 0 AND ~SELF.Customizing THEN canHide = 1.
    IF ~ERRORCODE() AND SELF.MostGroup AND (SELF.Items.Id = SELF.MostGroup OR SELF.Items.Parent = SELF.MostGroup)
      t13 = SELF.Txt('Reset &most used', 'Reiniciar &m<225>s usados')
      mtp_AppendMenu(m, 0, 24, ADDRESS(t13))
      mtp_AppendMenu(m, 0800h, 0, 0)
    END
  END
  IF canHide
    t11 = SELF.Txt('Hi&de this', '&Ocultar esto')
    mtp_AppendMenu(m, 0, 25, ADDRESS(t11))
  END
  t12 = CHOOSE(SELF.Customizing = 1, SELF.Txt('&Done customizing', '&Terminar de personalizar'), SELF.Txt('C&ustomize...', '&Personalizar...'))
  mtp_AppendMenu(m, 0, 26, ADDRESS(t12))
  mtp_AppendMenu(m, 0800h, 0, 0)
  IF SELF.RecentGroup AND SELF.MenuId > 0
    SELF.Items.Id = SELF.MenuId
    GET(SELF.Items, SELF.Items.Id)
    IF ~ERRORCODE() AND (SELF.Items.Id = SELF.RecentGroup OR SELF.Items.Parent = SELF.RecentGroup)
      t8 = SELF.Txt('Clear &recent', 'Borrar &recientes')
      mtp_AppendMenu(m, 0, 21, ADDRESS(t8))
      mtp_AppendMenu(m, 0800h, 0, 0)
    END
  END
  mtp_AppendMenu(m, CHOOSE(SELF.AllowDock = 1, 0, 1) + CHOOSE(SELF.DockSide = MTP:Left, 8, 0), 1, ADDRESS(t1))
  mtp_AppendMenu(m, CHOOSE(SELF.AllowDock = 1, 0, 1) + CHOOSE(SELF.DockSide = MTP:Right, 8, 0), 2, ADDRESS(t2))
  mtp_AppendMenu(m, CHOOSE(SELF.AllowFloat = 1, 0, 1) + CHOOSE(SELF.DockSide = MTP:Float, 8, 0), 3, ADDRESS(t3))
  mtp_AppendMenu(m, 0800h, 0, 0)
  mtp_AppendMenu(m, 0, 4, ADDRESS(t4))
  mtp_AppendMenu(m, 0, 5, ADDRESS(t5))
  IF SELF.DockSide <> MTP:Float
    t9  = CHOOSE(SELF.Rail = 1, SELF.Txt('Show the &whole panel', 'Mostrar el panel &completo'), SELF.Txt('Collapse to &icons', 'Contraer a &iconos'))
    t10 = SELF.Txt('A&uto-hide', 'Ocultar a&utom<225>ticamente')
    mtp_AppendMenu(m, 0800h, 0, 0)
    mtp_AppendMenu(m, 0, 22, ADDRESS(t9))
    mtp_AppendMenu(m, CHOOSE(SELF.AutoHide = 1, 8, 0), 23, ADDRESS(t10))
  END
  IF SELF.AllowClose
    mtp_AppendMenu(m, 0800h, 0, 0)
    mtp_AppendMenu(m, 0, 6, ADDRESS(t6))
  END
  mtp_GetCursorPos(ADDRESS(pt))
  SELF.InMenu = 1
  cmd = mtp_TrackPopupMenu(m, 0182h, pt.PX, pt.PY, 0, hwnd, 0)   ! RETURNCMD|NONOTIFY|RIGHTBUTTON
  SELF.InMenu = 0
  mtp_DestroyMenu(m)
  SELF.MenuId = 0
  CASE cmd
  OF 20
    IF SELF.IsFavorite(tgt) THEN SELF.RemoveFavorite(tgt) ELSE SELF.AddFavorite(tgt).
  OF 21 ; SELF.ClearRecent()
  OF 22 ; SELF.SetRail(1 - SELF.Rail)
  OF 23 ; SELF.SetAutoHide(1 - SELF.AutoHide)
  OF 24                                         ! Most used starts again
    LOOP i = 1 TO RECORDS(SELF.Items)
      GET(SELF.Items, i)
      IF SELF.Items.Uses
        SELF.Items.Uses = 0
        PUT(SELF.Items)
      END
    END
    SELF.SetRefs(4, ',')
  OF 25 ; SELF.HideItem(tgt, 1)
  OF 26 ; SELF.Customize(1 - SELF.Customizing)
  OF 1 ; SELF.Dock(MTP:Left)
  OF 2 ; SELF.Dock(MTP:Right)
  OF 3 ; SELF.Dock(MTP:Float)
  OF 4 ; SELF.ExpandAll(1)
  OF 5 ; SELF.ExpandAll(0)
  OF 6 ; SELF.HidePanel()
  END
  IF SELF.AutoHide AND SELF.DockHwnd AND ~SELF.HasFocus     ! the menu closed away from the panel
    mtp_GetCursorPos(ADDRESS(pt))
    mtp_GetWindowRect(SELF.DockHwnd, ADDRESS(r))
    IF pt.PX < r.X1 OR pt.PX >= r.X2 OR pt.PY < r.Y1 OR pt.PY >= r.Y2 THEN SELF.StartSlide(0).
  END

!  A submenu as a real pop-up menu, nested to any depth.
MyTaskPanelClass.FlyoutMenu PROCEDURE(LONG id, LONG hwnd)
i                      LONG
m                      LONG
pt                     GROUP
PX                       LONG
PY                       LONG
                       END
cmd                    LONG
  CODE
  m = SELF.BuildMenu(id)
  IF ~m THEN RETURN.
  mtp_GetCursorPos(ADDRESS(pt))
  IF SELF.HasFocus AND SELF.KeyId = id          ! opened from the keyboard: beside its row
    LOOP i = 1 TO RECORDS(SELF.Rows)
      GET(SELF.Rows, i)
      IF SELF.Rows.Id = id
        pt.PX = SELF.ViewW - SELF.Px(8)
        pt.PY = SELF.Rows.Y
        mtp_ClientToScreen(hwnd, ADDRESS(pt))
        BREAK
      END
    END
  END
  SELF.InMenu = 1
  cmd = mtp_TrackPopupMenu(m, 0182h, pt.PX, pt.PY, 0, hwnd, 0)
  SELF.InMenu = 0
  mtp_DestroyMenu(m)
  IF cmd > 0 THEN SELF.Click(cmd).

MyTaskPanelClass.BuildMenu PROCEDURE(LONG pid)
m                      LONG
sub                    LONG
i                      LONG
pos                    LONG
id                     LONG
fl                     LONG
cap                    CSTRING(200)
  CODE
  m = mtp_CreatePopupMenu()
  IF ~m THEN RETURN 0.
  pos = POINTER(SELF.Items)
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Parent <> pid OR SELF.Gone() THEN CYCLE.
    id = SELF.Items.Id
    CASE SELF.Items.Kind
    OF MTP:Separator
      mtp_AppendMenu(m, 0800h, 0, 0)
    OF MTP:Label
      cap = CLIP(SELF.Items.Text)
      mtp_AppendMenu(m, 1, 0, ADDRESS(cap))
    ELSE
      cap = CLIP(SELF.Items.Text)
      IF SELF.ShowShortcuts AND SELF.Items.Shortcut THEN cap = cap & '<9>' & CLIP(SELF.Items.Shortcut).
      fl = CHOOSE(SELF.Items.Enabled = 1, 0, 1) + CHOOSE(SELF.Items.Checked = 1, 8, 0)
      IF SELF.HasKids(id)
        sub = SELF.BuildMenu(id)
        GET(SELF.Items, i)
        mtp_AppendMenu(m, BOR(fl, 010h), sub, ADDRESS(cap))   ! MF_POPUP
      ELSE
        mtp_AppendMenu(m, fl, id, ADDRESS(cap))
      END
    END
  END
  IF pos THEN GET(SELF.Items, pos).
  RETURN m

! ============================================================================
!  layout
! ============================================================================
MyTaskPanelClass.Px PROCEDURE(REAL n)
  CODE
  RETURN INT(n * SELF.Dpi / 96 + 0.5)

MyTaskPanelClass.KidsHeight PROCEDURE(LONG pid)
i                      LONG
pos                    LONG
h                      LONG
id                     LONG
kind                   BYTE
rev                    REAL
  CODE
  pos = POINTER(SELF.Items)
  h = 0
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Parent <> pid OR SELF.Gone() OR pid = 0 THEN CYCLE.
    id   = SELF.Items.Id
    kind = SELF.Items.Kind
    rev  = SELF.Items.Reveal
    IF SELF.Items.Role = 3 AND ~SELF.RefOk(SELF.Items.RefId) THEN CYCLE.
    CASE kind
    OF MTP:Separator ; h += SELF.Px(9)
    OF MTP:Label     ; h += SELF.Px(22)
    OF MTP:Progress  ; h += SELF.Px(38)
    OF MTP:Chart     ; h += SELF.Px(72)
    ELSE
      h += SELF.Px(SELF.ItemHeight)
      IF SELF.SubStyle = MTP:Inline AND rev > 0 AND SELF.HasKids(id)
        h += INT(SELF.KidsHeight(id) * rev + 0.5)
      END
    END
  END
  IF pos THEN GET(SELF.Items, pos).
  RETURN h

MyTaskPanelClass.AddRows PROCEDURE(LONG pid, LONG level, *LONG y, LONG clipT, LONG clipB)
i                      LONG
pos                    LONG
id                     LONG
kind                   BYTE
rev                    REAL
h                      LONG
sub                    LONG
yy                     LONG
kids                   BYTE
  CODE
  pos = POINTER(SELF.Items)
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Parent <> pid OR SELF.Gone() THEN CYCLE.
    id   = SELF.Items.Id
    kind = SELF.Items.Kind
    rev  = SELF.Items.Reveal
    IF SELF.Items.Role = 3 AND ~SELF.RefOk(SELF.Items.RefId) THEN CYCLE.
    CASE kind
    OF MTP:Separator ; h = SELF.Px(9)
    OF MTP:Label     ; h = SELF.Px(22)
    OF MTP:Progress  ; h = SELF.Px(38)
    OF MTP:Chart     ; h = SELF.Px(72)
    ELSE             ; h = SELF.Px(SELF.ItemHeight)
    END
    kids = CHOOSE(kind = MTP:Item AND SELF.HasKids(id), 1, 0)
    CLEAR(SELF.Rows)
    SELF.Rows.Id      = id
    SELF.Rows.Kind    = kind
    SELF.Rows.Y       = y
    SELF.Rows.H       = h
    SELF.Rows.Level   = level
    SELF.Rows.ClipT   = clipT
    SELF.Rows.ClipB   = clipB
    SELF.Rows.HasKids = kids
    ADD(SELF.Rows)
    y += h
    IF kids AND SELF.SubStyle = MTP:Inline AND rev > 0
      sub = INT(SELF.KidsHeight(id) * rev + 0.5)
      yy = y
      SELF.AddRows(id, level + 1, yy, y, CHOOSE(y + sub < clipB, y + sub, clipB))
      y += sub
    END
  END
  IF pos THEN GET(SELF.Items, pos).

MyTaskPanelClass.Layout PROCEDURE(LONG w, LONG h, BYTE floating)
i                      LONG
top                    LONG
y                      LONG
id                     LONG
rev                    REAL
body                   LONG
shown                  LONG
hdr                    LONG
yy                     LONG
maxS                   LONG
pass                   LONG
searching              BYTE
found                  LONG
glist                  STRING(1000)
p                      LONG
q                      LONG
  CODE
  top = SELF.ContentTop(floating)
  searching = CHOOSE(CLIP(SELF.Search) <> '' AND floating <> 2, 1, 0)
  IF searching THEN SELF.UpdateMatches().
  SELF.ViewH = h - top
  SELF.ViewW = w
  LOOP pass = 1 TO 2
    FREE(SELF.Rows)
    y = top + SELF.Px(8) - SELF.ScrollY
    glist = SELF.GroupList()                    ! Favourites, Most used, Recent, then the user's order
    p = 2
    LOOP
      q = INSTRING(',', glist, 1, p)
      IF ~q THEN BREAK.
      id = SUB(glist, p, q - p)
      p = q + 1
      IF floating = 2 AND id <> SELF.PeekId THEN CYCLE.   ! the pop-out: its group only
      SELF.Items.Id = id
      GET(SELF.Items, SELF.Items.Id)
      IF ERRORCODE() THEN CYCLE.
      rev = SELF.Items.Reveal
      IF floating = 2 THEN rev = 1.
      IF searching                              ! only groups with a match, opened, matches only
        found = SELF.CountMatches(id)
        IF ~found THEN CYCLE.
        rev = 1
      END
      CLEAR(SELF.Rows)
      SELF.Rows.Id    = id
      SELF.Rows.Kind  = MTP:Group
      SELF.Rows.Y     = y
      SELF.Rows.H     = SELF.Px(SELF.HeaderHeight)
      SELF.Rows.ClipT = top
      SELF.Rows.ClipB = h
      ADD(SELF.Rows)
      hdr = RECORDS(SELF.Rows)
      y += SELF.Px(SELF.HeaderHeight)
      IF searching
        body = found * SELF.Px(SELF.ItemHeight) + SELF.Px(12)
      ELSE
        body = SELF.KidsHeight(id)
        IF body > 0 THEN body += SELF.Px(12).
      END
      shown = INT(body * rev + 0.5)
      IF shown > 0
        yy = y + SELF.Px(6)
        IF searching
          SELF.SearchRows(id, yy, y, y + shown)
        ELSE
          SELF.AddRows(id, 0, yy, y, y + shown)
        END
      END
      GET(SELF.Rows, hdr)
      SELF.Rows.BodyH = shown
      SELF.Rows.HasKids = CHOOSE(body > 0, 1, 0)
      PUT(SELF.Rows)
      y += shown + SELF.Px(10)
    END
    SELF.ContentH = y + SELF.ScrollY - top
    maxS = SELF.ContentH - SELF.ViewH
    IF maxS < 0 THEN maxS = 0.
    IF SELF.ScrollY > maxS
      SELF.ScrollY = maxS
      CYCLE                                     ! lay out again at the corrected scroll
    END
    IF SELF.ScrollY < 0
      SELF.ScrollY = 0
      CYCLE
    END
    BREAK
  END

!  -1 title, -2 the menu button, -3 close, -4 splitter, -5 scroll thumb,
!  >0 a row's item id, 0 nothing.
MyTaskPanelClass.HitTest PROCEDURE(LONG x, LONG y, BYTE floating)
i                      LONG
w                      LONG
sbw                    LONG
cw                     LONG
a                      LONG
top                    LONG
th                     LONG
r                      LIKE(MTP_Rect)
  CODE
  mtp_GetClientRect(SELF.HwndOf(floating), ADDRESS(r))
  w = r.X2
  IF floating = 0 AND SELF.Rail THEN RETURN SELF.RailHit(x, y).
  IF floating = 0 AND SELF.AutoHide AND SELF.Slide < 1 THEN RETURN 0.   ! tucked or still sliding
  th  = SELF.TitleH(floating)
  top = SELF.ContentTop(floating)
  IF ~floating AND SELF.AllowResize
    IF SELF.DockSide = MTP:Left AND x >= w - SELF.Px(4) THEN RETURN -4.
    IF SELF.DockSide = MTP:Right AND x < SELF.Px(4) THEN RETURN -4.
  END
  IF ~floating AND y < th
    IF x >= w - SELF.Px(81) AND x < w - SELF.Px(57) THEN RETURN -9.
    IF x >= w - SELF.Px(56) AND x < w - SELF.Px(32) THEN RETURN -2.
    IF SELF.AllowClose AND x >= w - SELF.Px(30) AND x < w - SELF.Px(6) THEN RETURN -3.
    RETURN -1
  END
  IF y < top AND SELF.Customizing               ! the Customize bar: Reset, Done
    IF x >= w - SELF.Px(60) AND x < w - SELF.Px(8) THEN RETURN -10.
    IF x >= w - SELF.Px(116) AND x < w - SELF.Px(64) THEN RETURN -11.
    RETURN 0
  END
  IF y < top                                    ! the search band
    IF x < SELF.Px(8) OR x >= w - SELF.Px(8) THEN RETURN 0.
    IF CLIP(SELF.Search) <> '' AND x >= w - SELF.Px(32) THEN RETURN -7.
    RETURN -6
  END
  IF SELF.ContentH > SELF.ViewH AND x >= w - SELF.Px(12) AND x < w - SELF.Px(4) AND y >= top THEN RETURN -5.
  IF x < SELF.Px(6) OR x > w - SELF.Px(6) THEN RETURN 0.
  LOOP i = 1 TO RECORDS(SELF.Rows)
    GET(SELF.Rows, i)
    IF y < SELF.Rows.Y OR y >= SELF.Rows.Y + SELF.Rows.H THEN CYCLE.
    IF y < SELF.Rows.ClipT OR y >= SELF.Rows.ClipB THEN CYCLE.
    IF SELF.Rows.Kind = MTP:Separator OR SELF.Rows.Kind = MTP:Label THEN RETURN 0.
    IF SELF.Rows.Kind >= MTP:Info               ! an info card reacts only when made clickable
      SELF.Items.Id = SELF.Rows.Id
      GET(SELF.Items, SELF.Items.Id)
      IF ERRORCODE() OR ~SELF.Items.Clickable THEN RETURN 0.
    END
    sbw = CHOOSE(SELF.ContentH > SELF.ViewH, SELF.Px(8), 0)
    cw = w - sbw - SELF.Px(16)
    IF SELF.Rows.Kind = MTP:Group
      IF SELF.Customizing AND x >= SELF.Px(8) + cw - SELF.Px(54) AND x < SELF.Px(8) + cw - SELF.Px(30) THEN RETURN -(2000000 + SELF.Rows.Id).
    ELSIF ~SELF.Customizing
      a = SELF.Resolve(SELF.Rows.Id)
      IF SELF.ActCount(a)                       ! a hover button?
        a = SELF.ActHit(a, x, SELF.Px(8) + cw - SELF.Px(8) - CHOOSE(SELF.Rows.HasKids = 1, SELF.Px(14), 0))
        IF a THEN RETURN -(1000000 + a).
      END
    END
    RETURN SELF.Rows.Id
  END
  RETURN 0

! ============================================================================
!  painting
! ============================================================================
MyTaskPanelClass.Paint PROCEDURE(LONG hwnd)
ps                     GROUP                    ! PAINTSTRUCT
psHdc                    LONG
psErase                  LONG
psL                      LONG
psT                      LONG
psR                      LONG
psB                      LONG
psRestore                LONG
psIncUpdate              LONG
psReserved               STRING(32)
                       END
r                      LIKE(MTP_Rect)
hdc                    LONG
mem                    LONG
bmp                    LONG
old                    LONG
i                      LONG
  CODE
  hdc = mtp_BeginPaint(hwnd, ADDRESS(ps))
  mtp_GetClientRect(hwnd, ADDRESS(r))
  IF r.X2 > 0 AND r.Y2 > 0
    mem = mtp_CreateCompatibleDC(hdc)
    bmp = mtp_CreateCompatibleBitmap(hdc, r.X2, r.Y2)
    old = mtp_SelectObject(mem, bmp)
    SELF.DC = mem
    mtp_SetBkMode(mem, 1)                       ! TRANSPARENT
    SELF.MakeFonts()
    FREE(SELF.PendIcons)
    SELF.UseD2D = 0
    COMPILE('ENDD2D',_MTP_D2D_)
    IF SELF.Engine = MTP:DirectX AND ~SELF.D2DFailed AND SELF.KindOf(hwnd) <> 3   ! the card wraps text: GDI
      IF mtp_d2_begin(mem, r.X2, r.Y2)
        SELF.UseD2D = 1
        SELF.Fx = SELF.Effects
      ELSE
        SELF.D2DFailed = 1                      ! paint with GDI from now on
      END
    END
    ! ENDD2D
    SELF.Render(r.X2, r.Y2, SELF.KindOf(hwnd))
    COMPILE('ENDD2D',_MTP_D2D_)
    IF SELF.UseD2D
      IF mtp_d2_end()                           ! lost the device: next frame rebuilds
        mtp_InvalidateRect(hwnd, 0, 0)
      END
    END
    ! ENDD2D
    SELF.UseD2D = 0
    SELF.Fx = 0
    LOOP i = 1 TO RECORDS(SELF.PendIcons)       ! icons always go through GDI
      GET(SELF.PendIcons, i)
      mtp_DrawIconEx(mem, SELF.PendIcons.X, SELF.PendIcons.Y, SELF.PendIcons.HIcon, SELF.PendIcons.Sz, SELF.PendIcons.Sz, 0, 0, 3)
    END
    FREE(SELF.PendIcons)
    mtp_BitBlt(hdc, 0, 0, r.X2, r.Y2, mem, 0, 0, 0CC0020h)   ! SRCCOPY
    mtp_SelectObject(mem, old)
    mtp_DeleteObject(bmp)
    mtp_DeleteDC(mem)
    SELF.DC = 0
  END
  mtp_EndPaint(hwnd, ADDRESS(ps))

MyTaskPanelClass.Render PROCEDURE(LONG w, LONG h, BYTE floating)
i                      LONG
th                     LONG
btx                     LONG
bty                     LONG
bs                     LONG
sbw                    LONG
thumbH                 LONG
thumbY                 LONG
c                      LONG
cx                     REAL
cy                     REAL
d                      LONG
  CODE
  IF floating = 3
    SELF.RenderTip(w, h)
    RETURN
  END
  IF floating = 0 AND SELF.Rail
    SELF.RenderRail(w, h)
    RETURN
  END
  IF floating = 0 AND SELF.AutoHide AND SELF.Slide = 0   ! tucked: only a strip of it shows
    SELF.PFill(0, 0, w, h, SELF.ClrTitle2)
    cx = CHOOSE(SELF.DockSide = MTP:Left, w - SELF.Px(3), SELF.Px(3))
    LOOP d = -1 TO 1
      SELF.PEllipse(cx, h / 2 + d * SELF.Px(7), SELF.Px(1.3), SELF.Px(1.3), SELF.ClrTitleText)
    END
    RETURN
  END
  SELF.Layout(w, h, floating)
  SELF.PFill(0, 0, w, h, SELF.ClrBack)
  sbw = CHOOSE(SELF.ContentH > SELF.ViewH, SELF.Px(8), 0)
  ! ---- the groups and their rows ----
  LOOP i = 1 TO RECORDS(SELF.Rows)
    GET(SELF.Rows, i)
    IF SELF.Rows.Kind = MTP:Group
      SELF.DrawGroup(w - sbw, floating)
    ELSE
      SELF.DrawRow(w - sbw)
    END
  END
  IF RECORDS(SELF.Rows) THEN SELF.PUnclip().    ! DrawGroup leaves its card clip open
  ! ---- scroll thumb ----
  IF sbw
    th = SELF.ContentTop(floating)
    thumbH = SELF.ViewH * SELF.ViewH / SELF.ContentH
    IF thumbH < SELF.Px(24) THEN thumbH = SELF.Px(24).
    thumbY = th + SELF.ScrollY * (SELF.ViewH - thumbH) / (SELF.ContentH - SELF.ViewH)
    c = CHOOSE(SELF.Hover = -5 OR SELF.Drag = 3, SELF.ClrTextDim, SELF.Mix(SELF.ClrTextDim, SELF.ClrBack, 0.45))
    SELF.PRound(w - SELF.Px(11), thumbY + SELF.Px(2), SELF.Px(5), thumbH - SELF.Px(4), SELF.Px(2.5), c)
  END
  IF CLIP(SELF.Search) <> '' AND RECORDS(SELF.Rows) = 0 AND floating <> 2
    SELF.PText(SELF.Px(12), SELF.ContentTop(floating) + SELF.Px(14), w - SELF.Px(24), SELF.Px(24), SELF.Txt('No matches', 'Sin resultados'), SELF.ClrTextDim, 0, 1)
  END
  IF SELF.Drag = 4 AND SELF.DropY                ! where the dragged group / favourite lands
    SELF.PFill(SELF.Px(10), SELF.DropY - 1, w - sbw - SELF.Px(20), SELF.Px(2), SELF.ClrAccent)
    SELF.PEllipse(SELF.Px(10), SELF.DropY, SELF.Px(3), SELF.Px(3), SELF.ClrAccent)
  END
  IF (SELF.ShowSearch OR SELF.Customizing) AND floating <> 2 THEN SELF.DrawSearch(w, floating).
  IF floating = 2 THEN SELF.PRound(0, 0, w, h, 0, -1, SELF.ClrCardLine).   ! the pop-out's edge
  ! ---- the title strip (docked only: a floating panel has a real caption) ----
  IF ~floating
    th = SELF.Px(30)
    SELF.PGrad(0, 0, w, th, 0, SELF.ClrTitle1, SELF.ClrTitle2)
    SELF.PText(SELF.Px(10), 0, w - SELF.Px(95), th, SELF.Title, SELF.ClrTitleText, 2, 0)
    bs = SELF.Px(22)
    bty = (th - bs) / 2
    btx = w - SELF.Px(79)                       ! collapse to the icon rail: a double chevron
    SELF.DrawTitleBtn(-9, btx, bty, bs)
    cx = btx + bs / 2
    cy = bty + bs / 2
    d = CHOOSE(SELF.DockSide = MTP:Left, 1, -1)
    SELF.PLine(cx + d * SELF.Px(0.5), cy - SELF.Px(4), cx - d * SELF.Px(3.5), cy, SELF.ClrTitleText, SELF.Px(1.6))
    SELF.PLine(cx - d * SELF.Px(3.5), cy, cx + d * SELF.Px(0.5), cy + SELF.Px(4), SELF.ClrTitleText, SELF.Px(1.6))
    SELF.PLine(cx + d * SELF.Px(4.5), cy - SELF.Px(4), cx + d * SELF.Px(0.5), cy, SELF.ClrTitleText, SELF.Px(1.6))
    SELF.PLine(cx + d * SELF.Px(0.5), cy, cx + d * SELF.Px(4.5), cy + SELF.Px(4), SELF.ClrTitleText, SELF.Px(1.6))
    btx = w - SELF.Px(54)
    SELF.DrawTitleBtn(-2, btx, bty, bs)
    SELF.PLine(btx + SELF.Px(7), bty + SELF.Px(9), btx + SELF.Px(11), bty + SELF.Px(13), SELF.ClrTitleText, SELF.Px(1.6))
    SELF.PLine(btx + SELF.Px(11), bty + SELF.Px(13), btx + SELF.Px(15), bty + SELF.Px(9), SELF.ClrTitleText, SELF.Px(1.6))
    IF SELF.AllowClose
      btx = w - SELF.Px(29)
      SELF.DrawTitleBtn(-3, btx, bty, bs)
      SELF.PLine(btx + SELF.Px(7), bty + SELF.Px(7), btx + SELF.Px(15), bty + SELF.Px(15), SELF.ClrTitleText, SELF.Px(1.6))
      SELF.PLine(btx + SELF.Px(15), bty + SELF.Px(7), btx + SELF.Px(7), bty + SELF.Px(15), SELF.ClrTitleText, SELF.Px(1.6))
    END
    ! ---- the inner edge, which is also the splitter ----
    IF SELF.DockSide = MTP:Left
      SELF.PFill(w - 1, th, 1, h - th, SELF.ClrCardLine)
    ELSE
      SELF.PFill(0, th, 1, h - th, SELF.ClrCardLine)
    END
  END
  IF SELF.ShowEngine THEN SELF.DrawBadge(w, h, sbw).

!  A title-strip button's hover square: solid in GDI, a fading glass square
!  with the DirectX effects.
MyTaskPanelClass.DrawTitleBtn PROCEDURE(LONG id, LONG btx, LONG bty, LONG bs)
t                      REAL
  CODE
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.Fx
    t = SELF.HoverAmt(id)
    IF t > 0 THEN mtp_d2_round(btx, bty, bs, bs, SELF.Px(4), SELF.Alpha(SELF.ClrTitleText, 0.20 * t), SELF.Alpha(SELF.ClrTitleText, 0.30 * t), 1).
    RETURN
  END
  ! ENDD2D
  IF SELF.Hover = id THEN SELF.PRound(btx, bty, bs, bs, SELF.Px(4), SELF.Mix(SELF.ClrTitle1, SELF.ClrTitleText, 0.18)).

! ============================================================================
!  Keyboard and search. Focus() (or a click in the search box) gives the
!  panel the keyboard: arrows move, Enter runs, Right/Left open and close,
!  typing filters every group down to the matching actions, Esc clears the
!  search and then gives the keyboard back, Tab gives it back at once.
! ============================================================================
MyTaskPanelClass.CurHwnd PROCEDURE
  CODE
  RETURN CHOOSE(SELF.DockSide = MTP:Float, SELF.FloatHwnd, SELF.DockHwnd)

MyTaskPanelClass.TitleH PROCEDURE(BYTE floating)
  CODE
  RETURN CHOOSE(floating = 0, SELF.Px(30), 0)

MyTaskPanelClass.ContentTop PROCEDURE(BYTE floating)
  CODE
  RETURN SELF.TitleH(floating) + CHOOSE((SELF.ShowSearch = 1 OR SELF.Customizing = 1) AND floating < 2, SELF.Px(36), 0)

MyTaskPanelClass.HasKeyboard PROCEDURE
  CODE
  RETURN SELF.HasFocus

MyTaskPanelClass.Focus PROCEDURE
h                      LONG
f                      LONG
  CODE
  IF SELF.Rail THEN SELF.SetRail(0).            ! the keyboard needs the whole panel
  IF SELF.AutoHide THEN SELF.StartSlide(1).
  h = SELF.CurHwnd()
  IF ~h OR ~SELF.Visible THEN RETURN.
  f = mtp_GetFocus()
  IF f <> h THEN SELF.PrevFocus = f.
  mtp_SetFocus(h)

MyTaskPanelClass.LeaveFocus PROCEDURE
  CODE
  IF SELF.PrevFocus AND mtp_IsWindow(SELF.PrevFocus) AND SELF.PrevFocus <> SELF.CurHwnd()
    mtp_SetFocus(SELF.PrevFocus)
  ELSE
    mtp_SetFocus(SELF.HostHwnd)
  END
  SELF.PrevFocus = 0

MyTaskPanelClass.SetSearch PROCEDURE(STRING txt)
  CODE
  SELF.Search  = txt
  SELF.ScrollY = 0
  SELF.KeyId   = 0
  SELF.CaretOn = 1
  IF CLIP(SELF.Search) <> '' THEN SELF.MoveKey(1).      ! the keyboard starts on the first match
  SELF.Invalidate()

MyTaskPanelClass.GetSearch PROCEDURE
  CODE
  RETURN SELF.Search

MyTaskPanelClass.KeyDown PROCEDURE(LONG hwnd, LONG vk)
id                     LONG
kind                   BYTE
kids                   BYTE
leaf                   BYTE
searching              BYTE
  CODE
  searching = CHOOSE(CLIP(SELF.Search) <> '', 1, 0)
  id = SELF.KeyId
  IF id
    SELF.Items.Id = id
    GET(SELF.Items, SELF.Items.Id)
    IF ERRORCODE()
      id = 0
    ELSE
      kind = SELF.Items.Kind
      kids = SELF.HasKids(id)
    END
  END
  CASE vk
  OF 26h ; SELF.MoveKey(-1)                     ! Up
  OF 28h ; SELF.MoveKey(1)                      ! Down
  OF 21h ; SELF.MoveKey(-8)                     ! Page Up
  OF 22h ; SELF.MoveKey(8)                      ! Page Down
  OF 24h                                        ! Home
    SELF.KeyId = 0
    SELF.MoveKey(1)
  OF 23h                                        ! End
    SELF.KeyId = 0
    SELF.MoveKey(-1)
  OF 0Dh                                        ! Enter: what a click would do
    IF ~id
      SELF.MoveKey(1)
      RETURN 1
    END
    leaf = CHOOSE(kind = MTP:Item AND ~kids, 1, 0)
    SELF.OnClickRow(id, hwnd)
    IF leaf THEN SELF.LeaveFocus().             ! an action ran: back to the program
  OF 27h                                        ! Right: open, or step into what is open
    IF ~id OR searching THEN RETURN 1.
    IF kind = MTP:Group OR kids
      IF kind = MTP:Item AND SELF.SubStyle = MTP:Flyout
        SELF.FlyoutMenu(id, hwnd)
      ELSIF ~SELF.Items.Expanded
        SELF.Expand(id, 1)
      ELSE
        SELF.MoveKey(1)
      END
    END
  OF 25h                                        ! Left: close, or step out to the parent
    IF ~id OR searching THEN RETURN 1.
    IF (kind = MTP:Group OR kids) AND SELF.Items.Expanded
      SELF.Expand(id, 0)
    ELSIF SELF.Items.Parent
      SELF.KeyId = SELF.Items.Parent
      SELF.EnsureVisible(SELF.KeyId)
    END
  OF 1Bh                                        ! Esc: clear the search, then give the keyboard back
    IF searching
      SELF.SetSearch('')
    ELSE
      SELF.LeaveFocus()
    END
  OF 09h                                        ! Tab
    SELF.LeaveFocus()
  ELSE
    RETURN 0
  END
  SELF.Invalidate()
  RETURN 1

MyTaskPanelClass.KeyChar PROCEDURE(LONG ch)
  CODE
  IF ~SELF.ShowSearch OR SELF.Customizing THEN RETURN.
  CASE ch
  OF 8                                          ! Backspace
    IF LEN(SELF.Search) > 0 THEN SELF.SetSearch(SUB(SELF.Search, 1, LEN(SELF.Search) - 1)).
  OF 32
    IF LEN(SELF.Search) = 0                     ! Space on an empty search: a click
      SELF.KeyDown(SELF.CurHwnd(), 0Dh)
    ELSIF LEN(SELF.Search) < 60
      SELF.SetSearch(SELF.Search & ' ')
    END
  OF 33 TO 126
  OROF 128 TO 255
    IF LEN(SELF.Search) < 60 THEN SELF.SetSearch(SELF.Search & CHR(ch)).
  END

!  Moves the keyboard steps rows (negative = up) among the rows that can be
!  used: group headers and items, or only the matches while searching. With
!  no row yet it goes to the first (steps > 0) or the last.
MyTaskPanelClass.MoveKey PROCEDURE(LONG steps)
ids                    LONG,DIM(1000)
n                      LONG
cur                    LONG
i                      LONG
h                      LONG
r                      LIKE(MTP_Rect)
searching              BYTE
  CODE
  h = SELF.CurHwnd()
  IF ~h THEN RETURN.
  mtp_GetClientRect(h, ADDRESS(r))
  SELF.Layout(r.X2, r.Y2, CHOOSE(h = SELF.FloatHwnd, 1, 0))
  searching = CHOOSE(CLIP(SELF.Search) <> '', 1, 0)
  LOOP i = 1 TO RECORDS(SELF.Rows)
    GET(SELF.Rows, i)
    IF SELF.Rows.Kind <> MTP:Group AND SELF.Rows.Kind <> MTP:Item THEN CYCLE.
    IF searching AND SELF.Rows.Kind = MTP:Group THEN CYCLE.
    IF SELF.Rows.Y >= SELF.Rows.ClipB OR SELF.Rows.Y + SELF.Rows.H <= SELF.Rows.ClipT THEN CYCLE.
    IF n >= 1000 THEN BREAK.
    n += 1
    ids[n] = SELF.Rows.Id
    IF SELF.Rows.Id = SELF.KeyId THEN cur = n.
  END
  IF n = 0
    SELF.KeyId = 0
    RETURN
  END
  IF cur = 0
    cur = CHOOSE(steps > 0, 1, n)
  ELSE
    cur += steps
    IF cur < 1 THEN cur = 1.
    IF cur > n THEN cur = n.
  END
  SELF.KeyId = ids[cur]
  SELF.EnsureVisible(SELF.KeyId)

MyTaskPanelClass.EnsureVisible PROCEDURE(LONG id)
h                      LONG
r                      LIKE(MTP_Rect)
i                      LONG
floating               BYTE
top                    LONG
bottom                 LONG
  CODE
  h = SELF.CurHwnd()
  IF ~h OR ~id THEN RETURN.
  floating = CHOOSE(h = SELF.FloatHwnd, 1, 0)
  mtp_GetClientRect(h, ADDRESS(r))
  SELF.Layout(r.X2, r.Y2, floating)
  LOOP i = 1 TO RECORDS(SELF.Rows)
    GET(SELF.Rows, i)
    IF SELF.Rows.Id = id THEN BREAK.
  END
  IF i > RECORDS(SELF.Rows) THEN RETURN.
  top = SELF.ContentTop(floating) + SELF.Px(4)
  bottom = r.Y2 - SELF.Px(4)
  IF SELF.Rows.Y < top
    SELF.ScrollY -= top - SELF.Rows.Y
  ELSIF SELF.Rows.Y + SELF.Rows.H > bottom
    SELF.ScrollY += SELF.Rows.Y + SELF.Rows.H - bottom
  END
  IF SELF.ScrollY < 0 THEN SELF.ScrollY = 0.
  SELF.Invalidate()

!  Match = an action (an item with no submenu) whose text holds the search.
MyTaskPanelClass.UpdateMatches PROCEDURE
i                      LONG
s                      STRING(60)
m                      BYTE
  CODE
  s = SELF.Fold(SELF.Search)
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    m = 0
    IF SELF.Items.Kind = MTP:Item AND SELF.Items.Role = 0 AND INSTRING(CLIP(s), SELF.Fold(SELF.Items.Text), 1, 1)
      m = CHOOSE(SELF.HasKids(SELF.Items.Id) = 0, 1, 0)
    END
    IF SELF.Items.Match <> m
      SELF.Items.Match = m
      PUT(SELF.Items)
    END
  END

MyTaskPanelClass.Fold PROCEDURE(STRING txt)
res                    STRING(255)
i                      LONG
p                      LONG
from                   STRING('<193><201><205><211><218><220><209><225><233><237><243><250><252><241>')
into                   STRING('AEIOUUNAEIOUUN')
  CODE
  res = UPPER(txt)
  LOOP i = 1 TO LEN(CLIP(res))
    p = INSTRING(res[i], from, 1, 1)
    IF p THEN res[i] = into[p].
  END
  RETURN res

MyTaskPanelClass.CountMatches PROCEDURE(LONG pid)
i                      LONG
n                      LONG
pos                    LONG
id                     LONG
  CODE
  pos = POINTER(SELF.Items)
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Parent <> pid OR SELF.Gone() OR pid = 0 THEN CYCLE.
    id = SELF.Items.Id
    IF SELF.Items.Match THEN n += 1.
    n += SELF.CountMatches(id)
  END
  IF pos THEN GET(SELF.Items, pos).
  RETURN n

!  The matches under pid, at any depth, one row each in the group's card.
MyTaskPanelClass.SearchRows PROCEDURE(LONG pid, *LONG y, LONG clipT, LONG clipB)
i                      LONG
pos                    LONG
id                     LONG
m                      BYTE
  CODE
  pos = POINTER(SELF.Items)
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Parent <> pid OR SELF.Gone() THEN CYCLE.
    id = SELF.Items.Id
    m  = SELF.Items.Match
    IF m
      CLEAR(SELF.Rows)
      SELF.Rows.Id    = id
      SELF.Rows.Kind  = MTP:Item
      SELF.Rows.Y     = y
      SELF.Rows.H     = SELF.Px(SELF.ItemHeight)
      SELF.Rows.ClipT = clipT
      SELF.Rows.ClipB = clipB
      ADD(SELF.Rows)
      y += SELF.Px(SELF.ItemHeight)
    END
    SELF.SearchRows(id, y, clipT, clipB)
  END
  IF pos THEN GET(SELF.Items, pos).

!  "Browse > Geography" for Countries: the submenus between the item and its group.
MyTaskPanelClass.PathOf PROCEDURE(LONG id)
p                      LONG
res                    STRING(160)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN ''.
  p = SELF.Items.Parent
  LOOP WHILE p
    SELF.Items.Id = p
    GET(SELF.Items, SELF.Items.Id)
    IF ERRORCODE() OR SELF.Items.Kind = MTP:Group THEN BREAK.
    res = CHOOSE(res = '', CLIP(SELF.Items.Text), CLIP(SELF.Items.Text) & ' <155> ' & CLIP(res))
    p = SELF.Items.Parent
  END
  RETURN CLIP(res)

MyTaskPanelClass.TextW PROCEDURE(STRING txt, BYTE font)
dc                     LONG
old                    LONG
f                      LONG
cs                     CSTRING(256)
sz                     GROUP
cx                       LONG
cy                       LONG
                       END
  CODE
  cs = CLIP(txt)                                ! a STRING arrives padded: measure what shows
  IF ~LEN(cs) THEN RETURN 0.
  SELF.MakeFonts()
  CASE font
  OF 1 ; f = SELF.FontB
  OF 2 ; f = SELF.FontT
  OF 3 ; f = SELF.FontS
  ELSE ; f = SELF.FontN
  END
  dc = mtp_GetDC(0)                             ! never the frame's DC: Direct2D may own it
  old = mtp_SelectObject(dc, f)
  mtp_GetTextExtent(dc, ADDRESS(cs), LEN(cs), ADDRESS(sz))
  mtp_SelectObject(dc, old)
  mtp_ReleaseDC(0, dc)
  RETURN sz.cx

!  The search box, fixed under the title while the groups scroll beneath it.
MyTaskPanelClass.DrawSearch PROCEDURE(LONG w, BYTE floating)
th                     LONG
band                   LONG
bx                     LONG
bt                     LONG
bw                     LONG
bh                     LONG
tx                     LONG
cx                     REAL
cy                     REAL
c                      LONG
  CODE
  th   = SELF.TitleH(floating)
  band = SELF.ContentTop(floating) - th
  SELF.PFill(0, th, w - CHOOSE(SELF.DockSide = MTP:Left AND ~floating, 1, 0), band, SELF.ClrBack)
  IF SELF.Customizing                           ! the Customize bar instead of the search box
    SELF.PText(SELF.Px(12), th, w - SELF.Px(128), band, SELF.Txt('Customize', 'Personalizar'), SELF.ClrText, 1, 0)
    SELF.PRound(w - SELF.Px(60), th + SELF.Px(6), SELF.Px(52), band - SELF.Px(12), SELF.Px(5), CHOOSE(SELF.Hover = -10, SELF.Mix(SELF.ClrAccent, MTP_Hex(0FFFFFFh), 0.15), SELF.ClrAccent))
    SELF.PText(w - SELF.Px(60), th + SELF.Px(6), SELF.Px(52), band - SELF.Px(12), SELF.Txt('Done', 'Listo'), MTP_Hex(0FFFFFFh), 1, 1)
    SELF.PRound(w - SELF.Px(116), th + SELF.Px(6), SELF.Px(52), band - SELF.Px(12), SELF.Px(5), SELF.ClrCard, CHOOSE(SELF.Hover = -11, SELF.ClrAccent, SELF.ClrCardLine))
    SELF.PText(w - SELF.Px(116), th + SELF.Px(6), SELF.Px(52), band - SELF.Px(12), SELF.Txt('Reset', 'Reiniciar'), SELF.ClrText, 3, 1)
    RETURN
  END
  bx = SELF.Px(8)
  bt = th + SELF.Px(6)
  bw = w - SELF.Px(16)
  bh = band - SELF.Px(10)
  SELF.PRound(bx, bt, bw, bh, SELF.Px(5), SELF.ClrCard, CHOOSE(SELF.HasFocus = 1, SELF.ClrAccent, SELF.ClrCardLine))
  SELF.DrawGlyph('search', bx + SELF.Px(7), bt + (bh - SELF.Px(14)) / 2, SELF.Px(14), CHOOSE(SELF.HasFocus = 1, SELF.ClrAccent, SELF.ClrTextDim))
  tx = bx + SELF.Px(27)
  IF LEN(SELF.Search) > 0
    SELF.PText(tx, bt, bw - SELF.Px(27) - SELF.Px(24), bh, SELF.Search, SELF.ClrText, 0, 0)
    cx = bx + bw - SELF.Px(12)
    cy = bt + bh / 2
    c = CHOOSE(SELF.Hover = -7, SELF.ClrText, SELF.ClrTextDim)
    SELF.PLine(cx - SELF.Px(3.5), cy - SELF.Px(3.5), cx + SELF.Px(3.5), cy + SELF.Px(3.5), c, SELF.Px(1.5))
    SELF.PLine(cx + SELF.Px(3.5), cy - SELF.Px(3.5), cx - SELF.Px(3.5), cy + SELF.Px(3.5), c, SELF.Px(1.5))
  ELSE
    SELF.PText(tx, bt, bw - SELF.Px(32), bh, SELF.Txt('Search...', 'Buscar...'), SELF.ClrTextDim, 0, 0)
  END
  IF SELF.HasFocus AND SELF.CaretOn
    SELF.PFill(tx + SELF.TextW(SELF.Search & '|', 0) - SELF.TextW('|', 0) + 1, bt + SELF.Px(6), 1, bh - SELF.Px(12), SELF.ClrText)   ! '|' keeps a typed trailing space
  END

!  A badge: a pill with a count or a word, or a dot for '*'. Drawn with its
!  right edge at right; returns how wide it was.
MyTaskPanelClass.DrawPill PROCEDURE(REAL right, REAL cy, STRING txt, LONG clr, LONG textClr)
w                      LONG
hh                     LONG
d                      LONG
  CODE
  IF CLIP(txt) = '*'
    d = SELF.Px(8)
    SELF.PEllipse(right - d / 2, cy, d / 2, d / 2, clr)
    RETURN d
  END
  hh = SELF.Px(16)
  w = SELF.TextW(CLIP(txt), 3) + SELF.Px(12)
  IF w < hh THEN w = hh.
  SELF.PRound(right - w, cy - hh / 2, w, hh, hh / 2, clr)
  SELF.PText(right - w, cy - hh / 2, w, hh, CLIP(txt), textClr, 3, 1)
  RETURN w

MyTaskPanelClass.SetBadge PROCEDURE(LONG id, STRING txt, LONG clr=-1)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Badge    = txt
  SELF.Items.BadgeClr = clr
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.GetBadge PROCEDURE(LONG id)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN ''.
  RETURN CLIP(SELF.Items.Badge)

! ============================================================================
!  Info cards: rows that show something instead of doing something - a label
!  and a value, a progress bar, a small chart. They sit in any group, beside
!  ordinary items; SetClickable makes one raise a click like an item.
! ============================================================================
MyTaskPanelClass.NewRow PROCEDURE(LONG pid, BYTE kind, STRING label, <STRING tag>)
  CODE
  CLEAR(SELF.Items)
  SELF.NextId += 1
  SELF.Items.Id      = SELF.NextId
  SELF.Items.Parent  = pid
  SELF.Items.Kind    = kind
  SELF.Items.Text    = SELF.CleanText(label)
  IF ~OMITTED(tag) THEN SELF.Items.Tag = tag.
  SELF.Items.Enabled = 1
  ADD(SELF.Items)
  SELF.Invalidate()
  RETURN SELF.NextId

MyTaskPanelClass.AddInfo PROCEDURE(LONG pid, STRING label, STRING value, <STRING tag>)
id                     LONG
  CODE
  IF OMITTED(tag)
    id = SELF.NewRow(pid, MTP:Info, label)
  ELSE
    id = SELF.NewRow(pid, MTP:Info, label, tag)
  END
  SELF.SetValue(id, value)
  RETURN id

MyTaskPanelClass.AddProgress PROCEDURE(LONG pid, STRING label, REAL pct, <STRING tag>)
id                     LONG
  CODE
  IF OMITTED(tag)
    id = SELF.NewRow(pid, MTP:Progress, label)
  ELSE
    id = SELF.NewRow(pid, MTP:Progress, label, tag)
  END
  SELF.SetProgress(id, pct)
  RETURN id

MyTaskPanelClass.AddChart PROCEDURE(LONG pid, STRING label, STRING series, BYTE style=0, <STRING tag>)
id                     LONG
  CODE
  IF OMITTED(tag)
    id = SELF.NewRow(pid, MTP:Chart, label)
  ELSE
    id = SELF.NewRow(pid, MTP:Chart, label, tag)
  END
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  SELF.Items.Style = style
  PUT(SELF.Items)
  SELF.SetSeries(id, series)
  RETURN id

MyTaskPanelClass.SetValue PROCEDURE(LONG id, STRING value)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  IF SELF.Items.Value = value THEN RETURN.
  SELF.Items.Value = value
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetProgress PROCEDURE(LONG id, REAL pct)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  IF pct < 0 THEN pct = 0.
  IF pct > 100 THEN pct = 100.
  IF SELF.Items.Pct = pct THEN RETURN.
  SELF.Items.Pct = pct
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetSeries PROCEDURE(LONG id, STRING series)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  IF SELF.Items.Series = series THEN RETURN.
  SELF.Items.Series = series
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.SetClickable PROCEDURE(LONG id, BYTE on=1)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.Clickable = on
  PUT(SELF.Items)

!  Draws the current SELF.Items record, an Info / Progress / Chart row.
MyTaskPanelClass.DrawInfo PROCEDURE(LONG x, LONG y, LONG cw, LONG rh, LONG tx, LONG right)
id                     LONG
tx2                    LONG
vw                     LONG
gy                     LONG
txt                    STRING(64)
bt                     LONG
bh                     LONG
fw                     LONG
v                      REAL,DIM(40)
n                      LONG
i                      LONG
tok                    STRING(32)
ser                    STRING(255)
c                      STRING(1)
mx                     REAL
mn                     REAL
ax                     LONG
ay                     LONG
aw                     LONG
ah                     LONG
bw                     REAL
gap                    REAL
hh                     REAL
px                     REAL
py                     REAL
lx                     REAL
ly                     REAL
  CODE
  id = SELF.Rows.Id
  IF SELF.Items.Clickable AND SELF.Hover = id AND SELF.Items.Enabled
    SELF.PRound(x + SELF.Px(4), y + 1, cw - SELF.Px(8), rh - 2, SELF.Px(4), SELF.ClrHover, SELF.ClrHoverLine)
  END
  tx2 = tx
  gy = y + (SELF.Px(24) - SELF.Px(16)) / 2
  IF SELF.Items.HIcon
    SELF.PIcon(SELF.Items.HIcon, tx, gy, SELF.Px(16))
    tx2 += SELF.Px(24)
  ELSIF SELF.Items.Glyph
    SELF.DrawGlyph(SELF.Items.Glyph, tx, gy, SELF.Px(16), SELF.ClrAccent)
    tx2 += SELF.Px(24)
  END
  CASE SELF.Items.Kind
  OF MTP:Info                                   ! label ............ value
    vw = SELF.TextW(SELF.Items.Value, 1) + 2
    IF vw > (right - tx2) * 6 / 10 THEN vw = (right - tx2) * 6 / 10.
    SELF.PText(right - vw, y, vw, rh, SELF.Items.Value, SELF.ClrText, 1, 2)
    SELF.PText(tx2, y, right - vw - SELF.Px(6) - tx2, rh, SELF.Items.Text, SELF.ClrTextDim, 0, 0)
  OF MTP:Progress                               ! label ....... 64%, a bar under it
    txt = CHOOSE(CLIP(SELF.Items.Value) <> '', CLIP(SELF.Items.Value), INT(SELF.Items.Pct + 0.5) & '%')
    vw = SELF.TextW(txt, 3) + 2
    SELF.PText(right - vw, y + SELF.Px(3), vw, SELF.Px(18), txt, SELF.ClrTextDim, 3, 2)
    SELF.PText(tx2, y + SELF.Px(3), right - vw - SELF.Px(6) - tx2, SELF.Px(18), SELF.Items.Text, SELF.ClrText, 0, 0)
    bt = y + SELF.Px(25)
    bh = SELF.Px(6)
    SELF.PRound(tx, bt, right - tx, bh, bh / 2, SELF.Mix(SELF.ClrSep, SELF.ClrCardLine, 0.5))
    fw = (right - tx) * SELF.Items.Pct / 100
    IF fw > 0
      IF fw < bh THEN fw = bh.
      SELF.PRound(tx, bt, fw, bh, bh / 2, SELF.ClrAccent)
    END
  OF MTP:Chart                                  ! label ....... headline, bars or a line under it
    ser = SELF.Items.Series
    LOOP i = 1 TO LEN(CLIP(ser))
      c = ser[i]
      IF c = ',' OR c = ';' OR c = ' '
        IF CLIP(tok) <> '' AND n < 40
          n += 1
          v[n] = tok
        END
        tok = ''
      ELSE
        tok = CLIP(tok) & c
      END
    END
    IF CLIP(tok) <> '' AND n < 40
      n += 1
      v[n] = tok
    END
    txt = CLIP(SELF.Items.Value)
    IF txt = '' AND n THEN txt = v[n].
    vw = SELF.TextW(txt, 1) + 2
    SELF.PText(right - vw, y + SELF.Px(2), vw, SELF.Px(18), txt, SELF.ClrText, 1, 2)
    SELF.PText(tx2, y + SELF.Px(2), right - vw - SELF.Px(6) - tx2, SELF.Px(18), SELF.Items.Text, SELF.ClrTextDim, 0, 0)
    IF ~n THEN RETURN.
    ax = tx
    ay = y + SELF.Px(24)
    aw = right - tx
    ah = rh - SELF.Px(30)
    mx = v[1]
    mn = 0
    LOOP i = 1 TO n
      IF v[i] > mx THEN mx = v[i].
      IF v[i] < mn THEN mn = v[i].
    END
    IF mx <= mn THEN mx = mn + 1.
    SELF.PFill(ax, ay + ah, aw, 1, SELF.ClrSep)
    IF SELF.Items.Style = MTP:Line AND n > 1
      LOOP i = 1 TO n
        px = ax + (i - 1) * aw / (n - 1)
        py = ay + ah - ah * (v[i] - mn) / (mx - mn)
        IF i > 1 THEN SELF.PLine(lx, ly, px, py, SELF.ClrAccent, SELF.Px(1.8)).
        lx = px
        ly = py
      END
      SELF.PEllipse(lx, ly, SELF.Px(3), SELF.Px(3), SELF.ClrAccent, SELF.ClrCard, SELF.Px(1.5))
    ELSE
      bw = aw / n
      gap = bw / 4
      IF gap > SELF.Px(4) THEN gap = SELF.Px(4).
      LOOP i = 1 TO n
        hh = ah * (v[i] - mn) / (mx - mn)
        IF hh < 1 THEN hh = 1.
        SELF.PRound(ax + (i - 1) * bw + gap / 2, ay + ah - hh, bw - gap, hh, CHOOSE(bw - gap > SELF.Px(4), SELF.Px(1.5), 0), CHOOSE(i = n, SELF.ClrAccent, SELF.Mix(SELF.ClrAccent, SELF.ClrCard, 0.55)))
      END
    END
  END

! ============================================================================
!  Favourites and Recent: two groups at the top whose rows stand for items
!  elsewhere (Role 3, RefId). Clicking one runs the real item. Kept in the
!  INI by tag, or by the path of texts when the item has no tag.
! ============================================================================
MyTaskPanelClass.Resolve PROCEDURE(LONG id)
  CODE
  IF id <= 0 THEN RETURN id.
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ~ERRORCODE() AND SELF.Items.Role = 3 THEN RETURN SELF.Items.RefId.
  RETURN id

MyTaskPanelClass.IsAction PROCEDURE(LONG id)
  CODE
  IF id <= 0 THEN RETURN 0.
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() OR SELF.Items.Kind <> MTP:Item OR SELF.Items.Role <> 0 THEN RETURN 0.
  RETURN CHOOSE(SELF.HasKids(id) = 0, 1, 0)

MyTaskPanelClass.RefOk PROCEDURE(LONG refId)
pos                    LONG
ok                     BYTE
  CODE
  pos = POINTER(SELF.Items)
  SELF.Items.Id = refId
  GET(SELF.Items, SELF.Items.Id)
  ok = CHOOSE(~ERRORCODE() AND ~SELF.Gone(), 1, 0)
  IF pos THEN GET(SELF.Items, pos).
  RETURN ok

MyTaskPanelClass.RoleGroup PROCEDURE(BYTE role)
gid                    LONG
  CODE
  gid = SELF.RoleGid(role)
  IF gid
    SELF.Items.Id = gid
    GET(SELF.Items, SELF.Items.Id)
    IF ~ERRORCODE() THEN RETURN gid.
  END
  CASE role
  OF 1 ; gid = SELF.AddGroup(SELF.Txt('Favourites', 'Favoritos'), 'star', 1, 0)
  OF 4 ; gid = SELF.AddGroup(SELF.Txt('Most used', 'M<225>s usados'), 'chart', 0, 0)
  ELSE ; gid = SELF.AddGroup(SELF.Txt('Recent', 'Recientes'), 'clock', 0, 0)
  END
  SELF.Items.Id = gid
  GET(SELF.Items, SELF.Items.Id)
  SELF.Items.Role = role
  PUT(SELF.Items)
  CASE role
  OF 1 ; SELF.FavGroup = gid
  OF 4 ; SELF.MostGroup = gid
  ELSE ; SELF.RecentGroup = gid
  END
  RETURN gid

MyTaskPanelClass.RefList PROCEDURE(BYTE role)
gid                    LONG
i                      LONG
res                    STRING(1000)
  CODE
  res = ','
  gid = SELF.RoleGid(role)
  IF ~gid THEN RETURN ','.
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Parent = gid AND SELF.Items.Role = 3
      res = CLIP(res) & SELF.Items.RefId & ','
    END
  END
  RETURN CLIP(res)

!  Rebuilds the role group's rows from ',12,15,' (item ids, in order).
MyTaskPanelClass.SetRefs PROCEDURE(BYTE role, STRING list)
gid                    LONG
i                      LONG
found                  LONG
p                      LONG
q                      LONG
id                     LONG
txt                    STRING(120)
gly                    STRING(24)
  CODE
  IF ~SELF.RoleGid(role) AND CLIP(list) = ',' THEN RETURN.     ! nothing to keep: no group either
  gid = SELF.RoleGroup(role)
  LOOP
    found = 0
    LOOP i = 1 TO RECORDS(SELF.Items)
      GET(SELF.Items, i)
      IF SELF.Items.Parent = gid AND SELF.Items.Role = 3
        found = SELF.Items.Id
        BREAK
      END
    END
    IF ~found THEN BREAK.
    SELF.DeleteItem(found)
  END
  p = 2
  LOOP
    q = INSTRING(',', list, 1, p)
    IF ~q THEN BREAK.
    id = SUB(list, p, q - p)
    p = q + 1
    IF id <= 0 THEN CYCLE.
    SELF.Items.Id = id
    GET(SELF.Items, SELF.Items.Id)
    IF ERRORCODE() THEN CYCLE.
    txt = SELF.Items.Text
    gly = SELF.Items.Glyph
    CLEAR(SELF.Items)
    SELF.NextId += 1
    SELF.Items.Id      = SELF.NextId
    SELF.Items.Parent  = gid
    SELF.Items.Kind    = MTP:Item
    SELF.Items.Text    = txt
    SELF.Items.Glyph   = gly
    SELF.Items.Enabled = 1
    SELF.Items.Role    = 3
    SELF.Items.RefId   = id
    ADD(SELF.Items)
  END
  SELF.Invalidate()

MyTaskPanelClass.AddFavorite PROCEDURE(LONG id)
list                   STRING(1000)
  CODE
  id = SELF.Resolve(id)
  IF ~SELF.IsAction(id) THEN RETURN.
  list = SELF.RefList(1)
  IF INSTRING(',' & id & ',', list, 1, 1) THEN RETURN.
  SELF.SetRefs(1, CLIP(list) & id & ',')

MyTaskPanelClass.RemoveFavorite PROCEDURE(LONG id)
list                   STRING(1000)
key                    STRING(16)
p                      LONG
  CODE
  id = SELF.Resolve(id)
  list = SELF.RefList(1)
  key = ',' & id & ','
  p = INSTRING(CLIP(key), list, 1, 1)
  IF ~p THEN RETURN.
  list = SUB(list, 1, p) & SUB(list, p + LEN(CLIP(key)), 1000)
  SELF.SetRefs(1, list)

MyTaskPanelClass.IsFavorite PROCEDURE(LONG id)
  CODE
  id = SELF.Resolve(id)
  RETURN CHOOSE(INSTRING(',' & id & ',', SELF.RefList(1), 1, 1) > 0, 1, 0)

MyTaskPanelClass.ClearRecent PROCEDURE
  CODE
  IF SELF.RecentGroup THEN SELF.SetRefs(2, ',').

!  The item just run goes to the top of Recent; the list keeps RecentMax.
MyTaskPanelClass.PushRecent PROCEDURE(LONG id)
list                   STRING(1000)
key                    STRING(16)
p                      LONG
n                      LONG
  CODE
  IF SELF.RecentMax <= 0 OR ~SELF.IsAction(id) THEN RETURN.
  list = SELF.RefList(2)
  key = ',' & id & ','
  p = INSTRING(CLIP(key), list, 1, 1)
  IF p THEN list = SUB(list, 1, p) & SUB(list, p + LEN(CLIP(key)), 1000).
  list = ',' & id & CLIP(list)
  p = 1                                         ! keep the first RecentMax
  LOOP
    p = INSTRING(',', list, 1, p + 1)
    IF ~p THEN BREAK.
    n += 1
    IF n = SELF.RecentMax
      list = SUB(list, 1, p)
      BREAK
    END
  END
  SELF.SetRefs(2, list)

MyTaskPanelClass.ItemKey PROCEDURE(LONG id)
k                      STRING(400)
p                      LONG
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN ''.
  IF CLIP(SELF.Items.Tag) <> '' THEN RETURN 'T:' & CLIP(SELF.Items.Tag).
  k = SELF.Items.Text
  p = SELF.Items.Parent
  LOOP WHILE p
    SELF.Items.Id = p
    GET(SELF.Items, SELF.Items.Id)
    IF ERRORCODE() THEN BREAK.
    k = CLIP(SELF.Items.Text) & '/' & CLIP(k)
    p = SELF.Items.Parent
  END
  RETURN 'P:' & CLIP(k)

MyTaskPanelClass.FindKey PROCEDURE(STRING key)
i                      LONG
id                     LONG
  CODE
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Role <> 0 OR SELF.Items.Kind = MTP:Separator THEN CYCLE.   ! items and groups
    id = SELF.Items.Id
    IF SELF.ItemKey(id) = key THEN RETURN id.
  END
  RETURN 0

!  ',12,15,' -> 'T:cust|P:Menu/Browse/Countries'
MyTaskPanelClass.ListKeys PROCEDURE(STRING list)
res                    STRING(2000)
p                      LONG
q                      LONG
  CODE
  p = 2
  LOOP
    q = INSTRING(',', list, 1, p)
    IF ~q THEN BREAK.
    res = CHOOSE(CLIP(res) = '', '', CLIP(res) & '|') & SELF.ItemKey(SUB(list, p, q - p))
    p = q + 1
  END
  RETURN CLIP(res)

!  'T:cust|P:Menu/Browse/Countries' -> ',12,15,' (keys no longer found are dropped)
MyTaskPanelClass.KeyList PROCEDURE(STRING keys)
res                    STRING(1000)
p                      LONG
q                      LONG
id                     LONG
  CODE
  res = ','
  IF CLIP(keys) = '' THEN RETURN ','.
  p = 1
  LOOP
    q = INSTRING('|', keys, 1, p)
    IF ~q THEN q = LEN(CLIP(keys)) + 1.
    id = SELF.FindKey(SUB(keys, p, q - p))
    IF id THEN res = CLIP(res) & id & ','.
    IF q > LEN(CLIP(keys)) THEN BREAK.
    p = q + 1
  END
  RETURN CLIP(res)

! ============================================================================
!  The rail: the docked panel as a strip of group icons. Pointing at one
!  slides that group out beside the strip (the pop-out, PeekHwnd); it goes
!  away when the mouse is on neither.
! ============================================================================
MyTaskPanelClass.KindOf PROCEDURE(LONG hwnd)
  CODE
  IF hwnd AND hwnd = SELF.TipHwnd THEN RETURN 3.
  IF hwnd AND hwnd = SELF.PeekHwnd THEN RETURN 2.
  IF hwnd AND hwnd = SELF.FloatHwnd THEN RETURN 1.
  RETURN 0

MyTaskPanelClass.HwndOf PROCEDURE(BYTE kind)
  CODE
  CASE kind
  OF 1 ; RETURN SELF.FloatHwnd
  OF 2 ; RETURN SELF.PeekHwnd
  OF 3 ; RETURN SELF.TipHwnd
  END
  RETURN SELF.DockHwnd

MyTaskPanelClass.RailW PROCEDURE
  CODE
  RETURN SELF.Px(44)

!  The k-th group shown: Favourites, Recent, then the rest, skipping the hidden
!  and the empty Favourites / Recent.
MyTaskPanelClass.GroupAt PROCEDURE(LONG k)
glist                  STRING(1000)
n                      LONG
p                      LONG
q                      LONG
  CODE
  glist = SELF.GroupList()
  p = 2
  LOOP
    q = INSTRING(',', glist, 1, p)
    IF ~q THEN BREAK.
    n += 1
    IF n = k THEN RETURN SUB(glist, p, q - p).
    p = q + 1
  END
  RETURN 0

MyTaskPanelClass.RailHit PROCEDURE(LONG x, LONG y)
  CODE
  IF y < SELF.Px(30) THEN RETURN -8.
  IF y < SELF.Px(36) THEN RETURN 0.
  RETURN SELF.GroupAt((y - SELF.Px(36)) / SELF.Px(40) + 1)

MyTaskPanelClass.RenderRail PROCEDURE(LONG w, LONG h)
th                     LONG
k                      LONG
id                     LONG
i                      LONG
bx                     REAL
bt                     REAL
bs                     REAL
cx                     REAL
cy                     REAL
d                      LONG
c1                     LONG
c2                     LONG
ct                     LONG
dot                    BYTE
dotClr                 LONG
gly                    STRING(24)
hi                     LONG
ch                     STRING(1)
hov                    BYTE
  CODE
  SELF.PFill(0, 0, w, h, SELF.ClrBack)
  th = SELF.Px(30)
  SELF.PGrad(0, 0, w, th, 0, SELF.ClrTitle1, SELF.ClrTitle2)
  bs = SELF.Px(22)
  SELF.DrawTitleBtn(-8, (w - bs) / 2, (th - bs) / 2, bs)
  cx = w / 2
  cy = th / 2
  d = CHOOSE(SELF.DockSide = MTP:Left, -1, 1)   ! points the way the panel opens
  SELF.PLine(cx + d * SELF.Px(0.5), cy - SELF.Px(4), cx - d * SELF.Px(3.5), cy, SELF.ClrTitleText, SELF.Px(1.6))
  SELF.PLine(cx - d * SELF.Px(3.5), cy, cx + d * SELF.Px(0.5), cy + SELF.Px(4), SELF.ClrTitleText, SELF.Px(1.6))
  SELF.PLine(cx + d * SELF.Px(4.5), cy - SELF.Px(4), cx + d * SELF.Px(0.5), cy, SELF.ClrTitleText, SELF.Px(1.6))
  SELF.PLine(cx + d * SELF.Px(0.5), cy, cx + d * SELF.Px(4.5), cy + SELF.Px(4), SELF.ClrTitleText, SELF.Px(1.6))
  LOOP k = 1 TO 200
    id = SELF.GroupAt(k)
    IF ~id THEN BREAK.
    SELF.Items.Id = id
    GET(SELF.Items, SELF.Items.Id)
    IF SELF.Items.Special
      c1 = SELF.ClrSpecial1
      c2 = SELF.ClrSpecial2
      ct = SELF.ClrSpecialText
    ELSE
      c1 = SELF.ClrHead1
      c2 = SELF.ClrHead2
      ct = SELF.ClrHeadText
    END
    gly = SELF.Items.Glyph
    hi  = SELF.Items.HIcon
    ch  = SELF.Items.Text[1]
    dot = CHOOSE(CLIP(SELF.Items.Badge) <> '', 1, 0)
    dotClr = CHOOSE(SELF.Items.BadgeClr = -1, SELF.ClrAccent, SELF.Items.BadgeClr)
    IF ~dot                                     ! or a badge on anything inside it
      LOOP i = 1 TO RECORDS(SELF.Items)
        GET(SELF.Items, i)
        IF SELF.Items.Parent = id AND CLIP(SELF.Items.Badge) <> ''
          dot = 1
          dotClr = CHOOSE(SELF.Items.BadgeClr = -1, SELF.ClrAccent, SELF.Items.BadgeClr)
          BREAK
        END
      END
    END
    hov = CHOOSE(SELF.Hover = id OR SELF.PeekId = id, 1, 0)
    IF hov
      c1 = SELF.Mix(c1, MTP_Hex(0FFFFFFh), 0.15)
      c2 = SELF.Mix(c2, MTP_Hex(0FFFFFFh), 0.15)
    END
    bs = SELF.Px(32)
    bx = (w - bs) / 2
    bt = th + SELF.Px(6) + (k - 1) * SELF.Px(40) + SELF.Px(4)
    COMPILE('ENDD2D',_MTP_D2D_)
    IF SELF.Fx THEN mtp_d2_shadow(bx, bt, bs, bs, SELF.Px(7), SELF.Px(4), SELF.Px(1.5), SELF.Alpha(COLOR:Black, 0.25)).
    ! ENDD2D
    SELF.PGrad(bx, bt, bs, bs, SELF.Px(7), c1, c2)
    IF hi
      SELF.PIcon(hi, bx + SELF.Px(8), bt + SELF.Px(8), SELF.Px(16))
    ELSIF gly
      SELF.DrawGlyph(gly, bx + SELF.Px(8), bt + SELF.Px(8), SELF.Px(16), ct)
    ELSE
      SELF.PText(bx, bt, bs, bs, UPPER(ch), ct, 1, 1)
    END
    IF dot THEN SELF.PEllipse(bx + bs - SELF.Px(3), bt + SELF.Px(3), SELF.Px(4.5), SELF.Px(4.5), dotClr, SELF.ClrBack, SELF.Px(1.5)).
  END
  IF SELF.DockSide = MTP:Left
    SELF.PFill(w - 1, th, 1, h - th, SELF.ClrCardLine)
  ELSE
    SELF.PFill(0, th, 1, h - th, SELF.ClrCardLine)
  END

MyTaskPanelClass.ShowPeek PROCEDURE(LONG gid)
k                      LONG
hh                     LONG
x                      LONG
y                      LONG
dr                     LIKE(MTP_Rect)
  CODE
  IF ~SELF.PeekHwnd THEN SELF.MakeWindows().
  IF ~SELF.PeekHwnd OR ~SELF.DockHwnd OR ~gid THEN RETURN.
  LOOP k = 1 TO 200
    IF SELF.GroupAt(k) = gid OR SELF.GroupAt(k) = 0 THEN BREAK.
  END
  SELF.PeekId  = gid
  SELF.ScrollY = 0
  SELF.Layout(SELF.PanelWidth, 32000, 2)        ! how tall the group is, fully open
  hh = SELF.ContentH + 2
  mtp_GetWindowRect(SELF.DockHwnd, ADDRESS(dr))
  IF hh > dr.Y2 - dr.Y1 THEN hh = dr.Y2 - dr.Y1.
  y = dr.Y1 + SELF.Px(36) + (k - 1) * SELF.Px(40)
  IF y + hh > dr.Y2 THEN y = dr.Y2 - hh.
  x = CHOOSE(SELF.DockSide = MTP:Right, dr.X1 - SELF.PanelWidth, dr.X2)
  mtp_SetWindowPos(SELF.PeekHwnd, 0, x, y, SELF.PanelWidth, hh, 0050h)   ! NOACTIVATE|SHOWWINDOW
  mtp_InvalidateRect(SELF.PeekHwnd, 0, 0)
  mtp_SetTimer(SELF.DockHwnd, 6, 120, 0)
  SELF.Invalidate()

MyTaskPanelClass.HidePeek PROCEDURE
  CODE
  IF ~SELF.PeekId THEN RETURN.
  SELF.PeekId = 0
  IF SELF.PeekHwnd THEN mtp_ShowWindow(SELF.PeekHwnd, 0).
  IF SELF.DockHwnd THEN mtp_KillTimer(SELF.DockHwnd, 6).
  SELF.Invalidate()

MyTaskPanelClass.PeekCheck PROCEDURE
pt                     GROUP
PX                       LONG
PY                       LONG
                       END
r                      LIKE(MTP_Rect)
  CODE
  IF ~SELF.PeekId
    IF SELF.DockHwnd THEN mtp_KillTimer(SELF.DockHwnd, 6).
    RETURN
  END
  IF SELF.InMenu THEN RETURN.
  mtp_GetCursorPos(ADDRESS(pt))
  mtp_GetWindowRect(SELF.DockHwnd, ADDRESS(r))
  IF pt.PX >= r.X1 AND pt.PX < r.X2 AND pt.PY >= r.Y1 AND pt.PY < r.Y2 THEN RETURN.
  mtp_GetWindowRect(SELF.PeekHwnd, ADDRESS(r))
  IF pt.PX >= r.X1 AND pt.PX < r.X2 AND pt.PY >= r.Y1 AND pt.PY < r.Y2 THEN RETURN.
  SELF.HidePeek()

MyTaskPanelClass.SetRail PROCEDURE(BYTE on)
  CODE
  IF on AND SELF.DockSide = MTP:Float THEN RETURN.
  SELF.Rail = on
  IF on THEN SELF.AutoHide = 0.
  SELF.HidePeek()
  SELF.ApplyLayout()

! ============================================================================
!  Auto-hide: docked, the panel waits as a strip in the edge (the host loses
!  only that) and slides out over the host when the mouse touches it.
! ============================================================================
MyTaskPanelClass.SetAutoHide PROCEDURE(BYTE on)
  CODE
  SELF.AutoHide = on
  IF on
    SELF.Rail = 0
    SELF.HidePeek()
  END
  SELF.Slide   = 0
  SELF.SlideTo = 0
  SELF.ApplyLayout()

MyTaskPanelClass.StartSlide PROCEDURE(BYTE out)
  CODE
  IF ~SELF.AutoHide OR SELF.Rail OR ~SELF.DockHwnd THEN RETURN.
  SELF.SlideTo = out
  IF SELF.Slide = out THEN RETURN.
  IF ~SELF.Sliding
    SELF.Sliding = 1
    mtp_SetTimer(SELF.DockHwnd, 7, 15, 0)
  END

MyTaskPanelClass.StepSlide PROCEDURE
d                      REAL
  CODE
  d = SELF.SlideTo - SELF.Slide
  IF ABS(d) < 0.04
    SELF.Slide = SELF.SlideTo
    SELF.Sliding = 0
    IF SELF.DockHwnd THEN mtp_KillTimer(SELF.DockHwnd, 7).
  ELSE
    SELF.Slide += d * 0.4
  END
  SELF.PlaceDocked()
  SELF.Invalidate()

! ============================================================================
!  The user's own panel: Customize (an edit mode in the panel itself - every
!  row an eye, hidden ones faded so they can come back, Reset and Done), and
!  groups / favourites dragged into the user's order. Kept in the INI.
! ============================================================================
MyTaskPanelClass.Gone PROCEDURE
  CODE
  IF SELF.Items.Hidden THEN RETURN 1.
  IF SELF.Items.UserHidden AND ~SELF.Customizing THEN RETURN 1.
  RETURN 0

MyTaskPanelClass.Customize PROCEDURE(BYTE on=1)
  CODE
  IF on
    IF CLIP(SELF.Search) <> '' THEN SELF.SetSearch('').
    IF SELF.Rail THEN SELF.SetRail(0).
    SELF.HidePeek()
    SELF.HideTip()
  END
  SELF.Customizing = on
  SELF.Invalidate()

MyTaskPanelClass.IsCustomizing PROCEDURE
  CODE
  RETURN SELF.Customizing

MyTaskPanelClass.HideItem PROCEDURE(LONG id, BYTE on=1)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() OR SELF.Items.Role = 3 THEN RETURN.
  SELF.Items.UserHidden = on
  PUT(SELF.Items)
  SELF.Invalidate()

MyTaskPanelClass.ResetCustom PROCEDURE
i                      LONG
  CODE
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.UserHidden
      SELF.Items.UserHidden = 0
      PUT(SELF.Items)
    END
  END
  SELF.GroupOrder = ''
  SELF.Invalidate()

!  Favourites, Most used and Recent (when they have rows), then the ordinary
!  groups: the user's order first, the rest as the program added them.
!  all = 1: every ordinary group, hidden ones too, no role groups.
MyTaskPanelClass.GroupList PROCEDURE(BYTE all=0)
res                    STRING(1000)
ord                    LONG
i                      LONG
id                     LONG
gid                    LONG
p                      LONG
q                      LONG
  CODE
  res = ','
  IF ~all
    LOOP ord = 1 TO 3
      gid = SELF.RoleGid(CHOOSE(ord, 1, 4, 2))
      IF ~gid THEN CYCLE.
      SELF.Items.Id = gid
      GET(SELF.Items, SELF.Items.Id)
      IF ERRORCODE() OR SELF.Gone() OR ~SELF.HasKids(gid) THEN CYCLE.
      res = CLIP(res) & gid & ','
    END
  END
  p = 2
  LOOP
    q = INSTRING(',', SELF.GroupOrder, 1, p)
    IF ~q THEN BREAK.
    id = SUB(SELF.GroupOrder, p, q - p)
    p = q + 1
    SELF.Items.Id = id
    GET(SELF.Items, SELF.Items.Id)
    IF ERRORCODE() OR SELF.Items.Kind <> MTP:Group OR SELF.Items.Parent <> 0 OR SELF.Items.Role <> 0 THEN CYCLE.
    IF ~all AND SELF.Gone() THEN CYCLE.
    IF INSTRING(',' & id & ',', res, 1, 1) THEN CYCLE.
    res = CLIP(res) & id & ','
  END
  LOOP i = 1 TO RECORDS(SELF.Items)
    GET(SELF.Items, i)
    IF SELF.Items.Kind <> MTP:Group OR SELF.Items.Parent <> 0 OR SELF.Items.Role <> 0 THEN CYCLE.
    IF ~all AND SELF.Gone() THEN CYCLE.
    id = SELF.Items.Id
    IF INSTRING(',' & id & ',', res, 1, 1) THEN CYCLE.
    res = CLIP(res) & id & ','
  END
  RETURN CLIP(res)

MyTaskPanelClass.MoveGroup PROCEDURE(LONG id, LONG beforeId)
lst                    STRING(1000)
key                    STRING(16)
p                      LONG
  CODE
  IF id = beforeId THEN RETURN.
  lst = SELF.GroupList(1)
  key = ',' & id & ','
  p = INSTRING(CLIP(key), lst, 1, 1)
  IF ~p THEN RETURN.
  lst = SUB(lst, 1, p) & SUB(lst, p + LEN(CLIP(key)), 1000)
  p = CHOOSE(beforeId <> 0, INSTRING(',' & beforeId & ',', lst, 1, 1), 0)
  IF p
    lst = SUB(lst, 1, p) & id & ',' & SUB(lst, p + 1, 1000)
  ELSE
    lst = CLIP(lst) & id & ','
  END
  SELF.GroupOrder = lst
  SELF.Invalidate()

!  While dragging: which row the mouse is before, and where the line goes.
MyTaskPanelClass.DragOver PROCEDURE(LONG y)
i                      LONG
isGroup                BYTE
last                   LONG
  CODE
  SELF.Items.Id = SELF.DragCand
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  isGroup = CHOOSE(SELF.Items.Kind = MTP:Group, 1, 0)
  SELF.DropAt = 0
  SELF.DropY  = 0
  LOOP i = 1 TO RECORDS(SELF.Rows)
    GET(SELF.Rows, i)
    SELF.Items.Id = SELF.Rows.Id
    GET(SELF.Items, SELF.Items.Id)
    IF ERRORCODE() THEN CYCLE.
    IF isGroup
      IF SELF.Rows.Kind <> MTP:Group OR SELF.Items.Role <> 0 THEN CYCLE.
      IF y < SELF.Rows.Y + SELF.Rows.H / 2
        SELF.DropAt = SELF.Rows.Id
        SELF.DropY  = SELF.Rows.Y - SELF.Px(5)
        BREAK
      END
      last = SELF.Rows.Y + SELF.Rows.H + SELF.Rows.BodyH + SELF.Px(5)
    ELSE
      IF SELF.Items.Role <> 3 OR SELF.Items.Parent <> SELF.FavGroup THEN CYCLE.
      IF y < SELF.Rows.Y + SELF.Rows.H / 2
        SELF.DropAt = SELF.Rows.Id
        SELF.DropY  = SELF.Rows.Y
        BREAK
      END
      last = SELF.Rows.Y + SELF.Rows.H
    END
  END
  IF ~SELF.DropAt THEN SELF.DropY = last.
  SELF.Invalidate()

MyTaskPanelClass.DropDrag PROCEDURE
lst                    STRING(1000)
key                    STRING(16)
mv                     LONG
bf                     LONG
p                      LONG
  CODE
  SELF.Items.Id = SELF.DragCand
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  IF SELF.Items.Kind = MTP:Group
    SELF.MoveGroup(SELF.DragCand, SELF.DropAt)
  ELSE                                          ! a favourite: the Favourites list in a new order
    mv = SELF.Resolve(SELF.DragCand)
    bf = CHOOSE(SELF.DropAt <> 0, SELF.Resolve(SELF.DropAt), 0)
    IF mv = bf THEN RETURN.
    lst = SELF.RefList(1)
    key = ',' & mv & ','
    p = INSTRING(CLIP(key), lst, 1, 1)
    IF ~p THEN RETURN.
    lst = SUB(lst, 1, p) & SUB(lst, p + LEN(CLIP(key)), 1000)
    p = CHOOSE(bf <> 0, INSTRING(',' & bf & ',', lst, 1, 1), 0)
    IF p
      lst = SUB(lst, 1, p) & mv & ',' & SUB(lst, p + 1, 1000)
    ELSE
      lst = CLIP(lst) & mv & ','
    END
    SELF.SetRefs(1, lst)
  END
  SELF.DropY = 0
  SELF.Invalidate()

MyTaskPanelClass.DrawEye PROCEDURE(REAL cx, REAL cy, BYTE on, LONG clr)
  CODE
  SELF.PEllipse(cx, cy, SELF.Px(7), SELF.Px(4.2), -1, clr, SELF.Px(1.3))
  SELF.PEllipse(cx, cy, SELF.Px(2), SELF.Px(2), clr)
  IF ~on THEN SELF.PLine(cx - SELF.Px(7), cy + SELF.Px(5), cx + SELF.Px(7), cy - SELF.Px(5), clr, SELF.Px(1.5)).

! ============================================================================
!  Most used: every run counted (Items.Uses); the group shows the MostMax
!  run most, twice at least.
! ============================================================================
MyTaskPanelClass.RoleGid PROCEDURE(BYTE role)
  CODE
  CASE role
  OF 1 ; RETURN SELF.FavGroup
  OF 2 ; RETURN SELF.RecentGroup
  OF 4 ; RETURN SELF.MostGroup
  END
  RETURN 0

MyTaskPanelClass.RebuildMost PROCEDURE
lst                    STRING(1000)
n                      LONG
i                      LONG
best                   LONG
bu                     LONG
id                     LONG
  CODE
  IF SELF.MostMax <= 0 THEN RETURN.
  lst = ','
  LOOP n = 1 TO SELF.MostMax
    best = 0
    bu = 1                                      ! twice at least
    LOOP i = 1 TO RECORDS(SELF.Items)
      GET(SELF.Items, i)
      IF SELF.Items.Kind <> MTP:Item OR SELF.Items.Role <> 0 OR SELF.Items.Uses <= bu THEN CYCLE.
      id = SELF.Items.Id
      IF INSTRING(',' & id & ',', lst, 1, 1) THEN CYCLE.
      best = id
      bu = SELF.Items.Uses
    END
    IF ~best THEN BREAK.
    lst = CLIP(lst) & best & ','
  END
  IF CLIP(lst) <> SELF.RefList(4) THEN SELF.SetRefs(4, lst).

! ============================================================================
!  Hover buttons: small buttons at the end of a row while the mouse is on it,
!  each with its own tag (NextClick: ClickTag = the button's, ClickAct <> 0).
!  Hit codes: -(1000000 + button id).
! ============================================================================
MyTaskPanelClass.AddAction PROCEDURE(LONG id, STRING glyph, STRING tag, <STRING tip>)
  CODE
  SELF.NextAct += 1
  CLEAR(SELF.Acts)
  SELF.Acts.Id     = SELF.NextAct
  SELF.Acts.ItemId = id
  SELF.Acts.Glyph  = glyph
  SELF.Acts.Tag    = tag
  IF ~OMITTED(tip) THEN SELF.Acts.Tip = tip.
  ADD(SELF.Acts)
  SELF.Invalidate()
  RETURN SELF.NextAct

MyTaskPanelClass.ClearActions PROCEDURE(LONG id)
i                      LONG
  CODE
  LOOP i = RECORDS(SELF.Acts) TO 1 BY -1
    GET(SELF.Acts, i)
    IF SELF.Acts.ItemId = id THEN DELETE(SELF.Acts).
  END
  SELF.Invalidate()

MyTaskPanelClass.ActCount PROCEDURE(LONG id)
i                      LONG
n                      LONG
  CODE
  IF ~id THEN RETURN 0.
  LOOP i = 1 TO RECORDS(SELF.Acts)
    GET(SELF.Acts, i)
    IF SELF.Acts.ItemId = id THEN n += 1.
  END
  RETURN n

MyTaskPanelClass.ActItem PROCEDURE(LONG code)
i                      LONG
a                      LONG
  CODE
  a = -code - 1000000
  LOOP i = 1 TO RECORDS(SELF.Acts)
    GET(SELF.Acts, i)
    IF SELF.Acts.Id = a THEN RETURN SELF.Acts.ItemId.
  END
  RETURN 0

!  Buttons right-aligned at right, first added leftmost; returns the new right.
MyTaskPanelClass.DrawActs PROCEDURE(LONG id, LONG right, LONG y, LONG rh)
i                      LONG
n                      LONG
k                      LONG
bw                     LONG
bl                     LONG
bs                     LONG
  CODE
  n = SELF.ActCount(id)
  IF ~n THEN RETURN right.
  bw = SELF.Px(22)
  bs = SELF.Px(20)
  LOOP i = 1 TO RECORDS(SELF.Acts)
    GET(SELF.Acts, i)
    IF SELF.Acts.ItemId <> id THEN CYCLE.
    k += 1
    bl = right - (n - k + 1) * bw
    IF SELF.Hover = -(1000000 + SELF.Acts.Id)
      SELF.PRound(bl + 1, y + (rh - bs) / 2, bs, bs, SELF.Px(4), SELF.ClrCard, SELF.ClrAccent)
    ELSE
      SELF.PRound(bl + 1, y + (rh - bs) / 2, bs, bs, SELF.Px(4), SELF.ClrCard, SELF.ClrHoverLine)
    END
    SELF.DrawGlyph(SELF.Acts.Glyph, bl + 1 + (bs - SELF.Px(14)) / 2, y + (rh - SELF.Px(14)) / 2, SELF.Px(14), SELF.ClrAccent)
  END
  RETURN right - n * bw - SELF.Px(4)

MyTaskPanelClass.ActHit PROCEDURE(LONG id, LONG x, LONG right)
i                      LONG
n                      LONG
k                      LONG
bw                     LONG
bl                     LONG
  CODE
  n = SELF.ActCount(id)
  bw = SELF.Px(22)
  LOOP i = 1 TO RECORDS(SELF.Acts)
    GET(SELF.Acts, i)
    IF SELF.Acts.ItemId <> id THEN CYCLE.
    k += 1
    bl = right - (n - k + 1) * bw
    IF x >= bl AND x < bl + bw THEN RETURN SELF.Acts.Id.
  END
  RETURN 0

MyTaskPanelClass.ActClick PROCEDURE(LONG code)
itm                    LONG
  CODE
  itm = SELF.ActItem(code)
  IF ~itm THEN RETURN.
  SELF.Clicks.Id  = itm
  SELF.Clicks.Act = -code - 1000000
  ADD(SELF.Clicks)
  POST(MTP:Event, , SELF.HostThread)

! ============================================================================
!  Files dropped from Explorer onto an item that takes them (SetDropTarget):
!  queued, MTP:Event's sister MTP:Drop posted, read with NextDrop.
! ============================================================================
MyTaskPanelClass.SetDropTarget PROCEDURE(LONG id, BYTE on=1)
  CODE
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  SELF.Items.DropOk = on
  PUT(SELF.Items)
  IF on
    SELF.Dropping = 1
    SELF.AcceptDrops()
  END

MyTaskPanelClass.AcceptDrops PROCEDURE
k                      LONG
h                      LONG
  CODE
  IF ~SELF.Dropping THEN RETURN.
  LOOP k = 0 TO 2
    h = SELF.HwndOf(k)
    IF ~h THEN CYCLE.
    mtp_DragAcceptFiles(h, 1)                   ! (Windows will not let Explorer drop on a program run as administrator)
  END

MyTaskPanelClass.TakeDrop PROCEDURE(LONG hwnd, LONG hDrop)
pt                     GROUP
PX                       LONG
PY                       LONG
                       END
hit                    LONG
id                     LONG
n                      LONG
i                      LONG
buf                    CSTRING(261)
files                  STRING(8000)
  CODE
  mtp_DragQueryPoint(hDrop, ADDRESS(pt))
  hit = SELF.HitTest(pt.PX, pt.PY, SELF.KindOf(hwnd))
  IF hit <= -1000000 AND hit > -2000000 THEN hit = SELF.ActItem(hit).
  id = SELF.Resolve(hit)
  IF id > 0
    SELF.Items.Id = id
    GET(SELF.Items, SELF.Items.Id)
    IF ~ERRORCODE() AND SELF.Items.DropOk AND SELF.Items.Enabled
      n = mtp_DragQueryFile(hDrop, -1, 0, 0)
      LOOP i = 0 TO n - 1
        mtp_DragQueryFile(hDrop, i, ADDRESS(buf), 260)
        files = CHOOSE(CLIP(files) = '', '', CLIP(files) & '|') & buf
      END
      SELF.Drops.Id    = id
      SELF.Drops.Files = files
      SELF.Drops.Count = n
      ADD(SELF.Drops)
      POST(MTP:Drop, , SELF.HostThread)
    END
  END
  mtp_DragFinish(hDrop)

MyTaskPanelClass.NextDrop PROCEDURE
  CODE
  IF ~RECORDS(SELF.Drops)
    SELF.DropId = 0
    RETURN 0
  END
  GET(SELF.Drops, 1)
  SELF.DropId    = SELF.Drops.Id
  SELF.DropFiles = SELF.Drops.Files
  SELF.DropCount = SELF.Drops.Count
  DELETE(SELF.Drops)
  SELF.Items.Id = SELF.DropId
  GET(SELF.Items, SELF.Items.Id)
  SELF.DropTag  = CHOOSE(ERRORCODE() = 0, SELF.Items.Tag, '')
  SELF.DropText = CHOOSE(ERRORCODE() = 0, SELF.Items.Text, '')
  RETURN 1

MyTaskPanelClass.DropFile PROCEDURE(LONG n)
p                      LONG
q                      LONG
k                      LONG
  CODE
  p = 1
  LOOP k = 1 TO n
    q = INSTRING('|', SELF.DropFiles, 1, p)
    IF ~q THEN q = LEN(CLIP(SELF.DropFiles)) + 1.
    IF k = n THEN RETURN SUB(SELF.DropFiles, p, q - p).
    p = q + 1
    IF p > LEN(CLIP(SELF.DropFiles)) THEN BREAK.
  END
  RETURN ''

! ============================================================================
!  The description card: after a pause on an item with a Tip, a card beside
!  the panel - its name, the description (wrapped), the shortcut and where it
!  lives. Painted with GDI (it wraps text); the mouse goes through it.
! ============================================================================
MyTaskPanelClass.ShowTip PROCEDURE(LONG id, LONG hwnd)
rid                    LONG
w                      LONG
h                      LONG
bodyH                  LONG
path                   STRING(160)
pt                     GROUP
PX                       LONG
PY                       LONG
                       END
r                      LIKE(MTP_Rect)
i                      LONG
rowId                  LONG
  CODE
  IF ~SELF.TipHwnd THEN SELF.MakeWindows().
  IF ~SELF.TipHwnd THEN RETURN.
  rowId = id
  IF id <= -1000000                             ! a hover button: its own tip
    rowId = 0
    LOOP i = 1 TO RECORDS(SELF.Acts)
      GET(SELF.Acts, i)
      IF SELF.Acts.Id = -id - 1000000
        SELF.TipTitle = SELF.Acts.Tip
        rowId = SELF.Acts.ItemId
        BREAK
      END
    END
    IF CLIP(SELF.TipTitle) = '' OR ~rowId THEN RETURN.
    SELF.TipBody = ''
    SELF.TipFoot = ''
  ELSE
    rid = SELF.Resolve(id)
    path = SELF.PathOf(rid)
    SELF.Items.Id = rid
    GET(SELF.Items, SELF.Items.Id)
    IF ERRORCODE() OR CLIP(SELF.Items.Tip) = '' THEN RETURN.    ! a card only for a real description
    SELF.TipTitle = SELF.Items.Text
    SELF.TipBody  = SELF.Items.Tip
    SELF.TipFoot  = CLIP(SELF.Items.Shortcut) & CHOOSE(CLIP(SELF.Items.Shortcut) <> '' AND CLIP(path) <> '', '   ', '') & CLIP(path)
  END
  w = SELF.Px(260)
  bodyH = CHOOSE(CLIP(SELF.TipBody) <> '', SELF.TipBodyH(SELF.TipBody, w - SELF.Px(24)) + SELF.Px(4), 0)
  h = SELF.Px(8) + SELF.Px(22) + bodyH + CHOOSE(CLIP(SELF.TipFoot) <> '', SELF.Px(20), 0) + SELF.Px(6)
  pt.PY = 0
  LOOP i = 1 TO RECORDS(SELF.Rows)              ! level with its row
    GET(SELF.Rows, i)
    IF SELF.Rows.Id = id OR SELF.Rows.Id = rowId
      pt.PY = SELF.Rows.Y
      BREAK
    END
  END
  mtp_ClientToScreen(hwnd, ADDRESS(pt))
  mtp_GetWindowRect(hwnd, ADDRESS(r))
  IF SELF.DockSide = MTP:Right AND SELF.KindOf(hwnd) = 0
    pt.PX = r.X1 - w - SELF.Px(6)
  ELSE
    pt.PX = r.X2 + SELF.Px(6)
  END
  mtp_SetWindowPos(SELF.TipHwnd, 0, pt.PX, pt.PY, w, h, 0050h)   ! NOACTIVATE|SHOWWINDOW
  mtp_InvalidateRect(SELF.TipHwnd, 0, 0)
  SELF.TipId = id

MyTaskPanelClass.HideTip PROCEDURE
  CODE
  IF ~SELF.TipId THEN RETURN.
  SELF.TipId = 0
  IF SELF.TipHwnd THEN mtp_ShowWindow(SELF.TipHwnd, 0).

MyTaskPanelClass.TipBodyH PROCEDURE(STRING txt, LONG w)
dc                     LONG
old                    LONG
cs                     CSTRING(256)
r                      LIKE(MTP_Rect)
  CODE
  cs = CLIP(txt)
  IF ~LEN(cs) THEN RETURN 0.
  SELF.MakeFonts()
  dc = mtp_GetDC(0)
  old = mtp_SelectObject(dc, SELF.FontN)
  r.X2 = w
  mtp_DrawText(dc, ADDRESS(cs), -1, ADDRESS(r), 0C10h)    ! CALCRECT|WORDBREAK|NOPREFIX
  mtp_SelectObject(dc, old)
  mtp_ReleaseDC(0, dc)
  IF r.Y2 > SELF.Px(130) THEN r.Y2 = SELF.Px(130).
  RETURN r.Y2

MyTaskPanelClass.PTextWrap PROCEDURE(REAL x, REAL y, REAL w, REAL h, STRING txt, LONG clr)
cs                     CSTRING(256)
r                      LIKE(MTP_Rect)
  CODE
  cs = CLIP(txt)
  IF ~LEN(cs) OR SELF.UseD2D THEN RETURN.
  mtp_SelectObject(SELF.DC, SELF.FontN)
  mtp_SetTextColor(SELF.DC, SELF.Rgb(clr))
  r.X1 = INT(x + 0.5)
  r.Y1 = INT(y + 0.5)
  r.X2 = INT(x + w + 0.5)
  r.Y2 = INT(y + h + 0.5)
  mtp_DrawText(SELF.DC, ADDRESS(cs), -1, ADDRESS(r), 8810h)   ! WORDBREAK|NOPREFIX|END_ELLIPSIS

MyTaskPanelClass.RenderTip PROCEDURE(LONG w, LONG h)
bodyH                  LONG
  CODE
  SELF.PFill(0, 0, w, h, SELF.ClrCard)
  SELF.PRound(0, 0, w, h, 0, -1, SELF.ClrCardLine)
  SELF.PFill(0, 0, SELF.Px(3), h, SELF.ClrAccent)
  SELF.PText(SELF.Px(12), SELF.Px(8), w - SELF.Px(20), SELF.Px(22), SELF.TipTitle, SELF.ClrText, 1, 0)
  IF CLIP(SELF.TipBody) <> ''
    bodyH = SELF.TipBodyH(SELF.TipBody, w - SELF.Px(24))
    SELF.PTextWrap(SELF.Px(12), SELF.Px(30), w - SELF.Px(24), bodyH, SELF.TipBody, SELF.ClrTextDim)
  END
  IF CLIP(SELF.TipFoot) <> ''
    SELF.PText(SELF.Px(12), h - SELF.Px(26), w - SELF.Px(24), SELF.Px(20), SELF.TipFoot, SELF.ClrAccent, 3, 0)
  END

!  Which engine is painting, in a small pill at the bottom corner.
MyTaskPanelClass.DrawBadge PROCEDURE(LONG w, LONG h, LONG sbw)
bw                     LONG
bh                     LONG
bl                     LONG
bt                     LONG
txt                    STRING(24)
  CODE
  IF SELF.UseD2D
    txt = CHOOSE(SELF.Fx = 1, 'DirectX', 'DirectX (flat)')
  ELSE
    txt = 'GDI'
  END
  bw = SELF.Px(CHOOSE(SELF.UseD2D = 1, CHOOSE(SELF.Fx = 1, 58, 86), 38))
  bh = SELF.Px(18)
  bl = w - sbw - bw - SELF.Px(12)
  bt = h - bh - SELF.Px(6)
  IF SELF.UseD2D
    COMPILE('ENDD2D',_MTP_D2D_)
    IF SELF.Fx THEN mtp_d2_shadow(bl, bt, bw, bh, bh / 2, SELF.Px(4), SELF.Px(1), SELF.Alpha(COLOR:Black, 0.30)).
    ! ENDD2D
    SELF.PRound(bl, bt, bw, bh, bh / 2, SELF.ClrAccent)
    SELF.PText(bl, bt, bw, bh, txt, MTP_Hex(0FFFFFFh), 3, 1)
  ELSE
    SELF.PRound(bl, bt, bw, bh, bh / 2, SELF.ClrCard, SELF.ClrTextDim)
    SELF.PText(bl, bt, bw, bh, txt, SELF.ClrText, 3, 1)
  END

!  A group header, and the card its rows sit on. Leaves a clip around the
!  card open for the rows that follow; the next group (or Render) closes it.
MyTaskPanelClass.DrawGroup PROCEDURE(LONG w, BYTE floating)
x                      LONG
y                      LONG
cw                     LONG
hh                     LONG
rad                    LONG
c1                     LONG
c2                     LONG
ct                     LONG
tx                     LONG
cx                     REAL
cy                     REAL
hov                    BYTE
id                     LONG
top                    LONG
t                      REAL
ex                     LONG
bk                     LONG
bw                     LONG
  CODE
  id  = SELF.Rows.Id
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  IF POINTER(SELF.Rows) > 1 THEN SELF.PUnclip().
  top = SELF.ContentTop(floating)
  SELF.PClip(0, top, w, 32000)
  x   = SELF.Px(8)
  y   = SELF.Rows.Y
  cw  = w - SELF.Px(16)
  hh  = SELF.Rows.H
  rad = SELF.Px(SELF.Radius)
  hov = CHOOSE(SELF.Hover = id, 1, 0)
  t   = CHOOSE(SELF.Fx = 1, SELF.HoverAmt(id), hov)
  IF SELF.Items.Special
    c1 = SELF.ClrSpecial1
    c2 = SELF.ClrSpecial2
    ct = SELF.ClrSpecialText
  ELSE
    c1 = SELF.ClrHead1
    c2 = SELF.ClrHead2
    ct = SELF.ClrHeadText
  END
  IF SELF.Customizing AND SELF.Items.UserHidden ! hidden by the user: faded until shown again
    c1 = SELF.Mix(c1, SELF.ClrBack, 0.6)
    c2 = SELF.Mix(c2, SELF.ClrBack, 0.6)
  END
  IF hov AND ~SELF.Fx                           ! the effects fade a glass layer in instead
    c1 = SELF.Mix(c1, MTP_Hex(0FFFFFFh), 0.10)
    c2 = SELF.Mix(c2, MTP_Hex(0FFFFFFh), 0.10)
  END
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.Fx                                    ! a soft shadow under the whole card, deeper on a dark theme
    bk = SELF.Rgb(SELF.ClrBack)
    bk = BAND(bk, 0FFh) + BAND(BSHIFT(bk, -8), 0FFh) + BAND(BSHIFT(bk, -16), 0FFh)
    mtp_d2_shadow(x, y, cw, hh + CHOOSE(SELF.Rows.BodyH > 0, SELF.Rows.BodyH, 0), rad, SELF.Px(7), SELF.Px(2), SELF.Alpha(COLOR:Black, CHOOSE(bk < 300, 0.55, 0.28)))
  END
  ! ENDD2D
  ! the card first, so the header overlaps its top edge
  IF SELF.Rows.BodyH > 0
    SELF.PRound(x, y + hh - rad, cw, SELF.Rows.BodyH + rad, rad, SELF.ClrCard, SELF.ClrCardLine)
  END
  SELF.PGrad(x, y, cw, hh, rad, c1, c2)
  IF SELF.Rows.BodyH > 0                        ! square off the bottom corners
    SELF.PGrad(x, y + hh / 2, cw, hh - hh / 2, 0, SELF.Mix(c1, c2, 0.5), c2)
  END
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.Fx                                    ! glass: a light falling off down the header, a bright top edge
    ex = CHOOSE(SELF.Rows.BodyH > 0, rad * 2, 0) ! an open card's header is square at the bottom
    mtp_d2_clip(x, y, cw, hh)
    mtp_d2_grad(x, y, cw, hh + ex, rad, SELF.Alpha(MTP_Hex(0FFFFFFh), 0.22), SELF.Alpha(MTP_Hex(0FFFFFFh), 0))
    IF t > 0 THEN mtp_d2_round(x, y, cw, hh + ex, rad, SELF.Alpha(MTP_Hex(0FFFFFFh), 0.14 * t), 0, 1).
    mtp_d2_unclip()
    mtp_d2_line(x + rad, y + 0.5, x + cw - rad, y + 0.5, SELF.Alpha(MTP_Hex(0FFFFFFh), 0.40), 1)
  END
  ! ENDD2D
  IF SELF.HasFocus AND SELF.KeyId = id         ! the keyboard is here
    SELF.PRound(x + 2, y + 2, cw - 4, hh - 4, rad - 1, -1, ct)
  END
  tx = x + SELF.Px(10)
  IF SELF.Items.HIcon
    SELF.PIcon(SELF.Items.HIcon, tx, y + (hh - SELF.Px(16)) / 2, SELF.Px(16))
    tx += SELF.Px(22)
  ELSIF SELF.Items.Glyph
    SELF.DrawGlyph(SELF.Items.Glyph, tx, y + (hh - SELF.Px(16)) / 2, SELF.Px(16), ct)
    tx += SELF.Px(22)
  END
  bw = 0
  IF SELF.Customizing AND SELF.Items.Role <> 3  ! Customize: the group's eye
    SELF.DrawEye(x + cw - SELF.Px(42), y + hh / 2, CHOOSE(SELF.Items.UserHidden = 0, 1, 0), ct)
    bw = SELF.Px(24)
  ELSIF CLIP(SELF.Items.Badge) <> ''            ! a light pill on the coloured header
    bw = SELF.DrawPill(x + cw - SELF.Px(CHOOSE(SELF.Rows.HasKids = 1, 30, 10)), y + hh / 2, SELF.Items.Badge, CHOOSE(SELF.Items.BadgeClr = -1, ct, SELF.Items.BadgeClr), CHOOSE(SELF.Items.BadgeClr = -1, c1, MTP_Hex(0FFFFFFh))) + SELF.Px(6)
  END
  SELF.PText(tx, y, cw - (tx - x) - SELF.Px(30) - bw, hh, SELF.Items.Text, ct, 1, 0)
  ! the expand / collapse button
  IF SELF.Rows.HasKids
    cx = x + cw - SELF.Px(15)
    cy = y + hh / 2
    SELF.PEllipse(cx, cy, SELF.Px(8), SELF.Px(8), SELF.Mix(c1, ct, 0.18 + 0.12 * t))
    IF SELF.Items.Expanded
      SELF.PLine(cx - SELF.Px(3.5), cy + SELF.Px(1.5), cx, cy - SELF.Px(2), ct, SELF.Px(1.6))
      SELF.PLine(cx, cy - SELF.Px(2), cx + SELF.Px(3.5), cy + SELF.Px(1.5), ct, SELF.Px(1.6))
    ELSE
      SELF.PLine(cx - SELF.Px(3.5), cy - SELF.Px(1.5), cx, cy + SELF.Px(2), ct, SELF.Px(1.6))
      SELF.PLine(cx, cy + SELF.Px(2), cx + SELF.Px(3.5), cy - SELF.Px(1.5), ct, SELF.Px(1.6))
    END
  END
  ! rows are clipped to the card while it opens and closes
  SELF.PUnclip()
  SELF.PClip(x, CHOOSE(y + hh > top, y + hh, top), cw, CHOOSE(SELF.Rows.BodyH > 0, SELF.Rows.BodyH, 1))

MyTaskPanelClass.DrawRow PROCEDURE(LONG w)
x                      LONG
y                      LONG
rh                     LONG
cw                     LONG
tx                     LONG
right                  LONG
clr                    LONG
hov                    BYTE
prs                    BYTE
id                     LONG
font                   BYTE
cx                     REAL
cy                     REAL
t                      REAL
path                   STRING(160)
pw                     LONG
p                      LONG
rrole                  BYTE
oid                    LONG
hot                    BYTE
acts                   BYTE
  CODE
  IF SELF.Rows.Y >= SELF.Rows.ClipB OR SELF.Rows.Y + SELF.Rows.H <= SELF.Rows.ClipT THEN RETURN.
  id = SELF.Rows.Id
  SELF.Items.Id = id
  GET(SELF.Items, SELF.Items.Id)
  IF ERRORCODE() THEN RETURN.
  rrole = SELF.Items.Role
  IF SELF.Items.Role = 3                        ! a Favourites / Recent row: draw the item it stands for
    SELF.Items.Id = SELF.Items.RefId
    GET(SELF.Items, SELF.Items.Id)
    IF ERRORCODE() THEN RETURN.
  END
  oid = SELF.Items.Id
  x  = SELF.Px(8)
  cw = w - SELF.Px(16)
  y  = SELF.Rows.Y
  rh = SELF.Rows.H
  right = x + cw - SELF.Px(8)
  tx = x + SELF.Px(10) + SELF.Rows.Level * SELF.Px(14)
  CASE SELF.Rows.Kind
  OF MTP:Separator
    SELF.PFill(tx, y + rh / 2, right - tx, 1, SELF.ClrSep)
    RETURN
  OF MTP:Label
    SELF.PText(tx, y + SELF.Px(2), right - tx, rh - SELF.Px(2), UPPER(SELF.Items.Text), SELF.ClrTextDim, 3, 0)
    RETURN
  OF MTP:Info
  OROF MTP:Progress
  OROF MTP:Chart
    SELF.DrawInfo(x, y, cw, rh, tx, right)
    RETURN
  END
  hot = CHOOSE(SELF.Hover = id OR (SELF.Hover <= -1000000 AND SELF.Hover > -2000000 AND SELF.ActItem(SELF.Hover) = oid), 1, 0)
  IF SELF.Customizing THEN hot = CHOOSE(SELF.Hover = id, 1, 0).
  hov = CHOOSE(hot = 1 AND SELF.Items.Enabled = 1, 1, 0)
  prs = CHOOSE(SELF.Pressed = id AND hov = 1, 1, 0)
  acts = CHOOSE(hot = 1 AND ~SELF.Customizing AND SELF.ActCount(oid) > 0, 1, 0)
  IF SELF.Fx                                    ! a translucent accent wash that fades in and out
    t = CHOOSE(SELF.Items.Enabled = 1, SELF.HoverAmt(id), 0)
    COMPILE('ENDD2D',_MTP_D2D_)
    IF t > 0 THEN mtp_d2_round(x + SELF.Px(4), y + 1, cw - SELF.Px(8), rh - 2, SELF.Px(4), SELF.Alpha(SELF.ClrAccent, CHOOSE(prs = 1, 0.28, 0.12) * t), SELF.Alpha(SELF.ClrAccent, 0.45 * t), 1).
    ! ENDD2D
    clr = CHOOSE(SELF.Items.Enabled = 1, SELF.Mix(SELF.ClrText, SELF.ClrAccent, t), SELF.ClrDisabled)
  ELSE
    IF hov
      SELF.PRound(x + SELF.Px(4), y + 1, cw - SELF.Px(8), rh - 2, SELF.Px(4), CHOOSE(prs = 1, SELF.Mix(SELF.ClrHover, SELF.ClrHoverLine, 0.5), SELF.ClrHover), SELF.ClrHoverLine)
    END
    clr = CHOOSE(SELF.Items.Enabled = 1, CHOOSE(hov = 1, SELF.ClrAccent, SELF.ClrText), SELF.ClrDisabled)
  END
  IF SELF.HasFocus AND SELF.KeyId = id          ! the keyboard is here
    SELF.PRound(x + SELF.Px(4), y + 1, cw - SELF.Px(8), rh - 2, SELF.Px(4), -1, SELF.ClrAccent)
  END
  IF SELF.Customizing AND SELF.Items.UserHidden THEN clr = SELF.ClrDisabled.
  ! icon column
  IF SELF.Items.Checked
    SELF.PLine(tx + SELF.Px(3), y + rh / 2, tx + SELF.Px(6.5), y + rh / 2 + SELF.Px(3.5), SELF.ClrAccent, SELF.Px(2))
    SELF.PLine(tx + SELF.Px(6.5), y + rh / 2 + SELF.Px(3.5), tx + SELF.Px(13), y + rh / 2 - SELF.Px(4), SELF.ClrAccent, SELF.Px(2))
  ELSIF SELF.Items.HIcon
    SELF.PIcon(SELF.Items.HIcon, tx, y + (rh - SELF.Px(16)) / 2, SELF.Px(16))
  ELSIF SELF.Items.Glyph
    SELF.DrawGlyph(SELF.Items.Glyph, tx, y + (rh - SELF.Px(16)) / 2, SELF.Px(16), CHOOSE(SELF.Items.Enabled = 1, SELF.ClrAccent, SELF.ClrDisabled))
  ELSE
    SELF.PEllipse(tx + SELF.Px(8), y + rh / 2, SELF.Px(2), SELF.Px(2), CHOOSE(SELF.Items.Enabled = 1, SELF.Mix(SELF.ClrAccent, SELF.ClrCard, 0.35), SELF.ClrDisabled))
  END
  tx += SELF.Px(24)
  IF SELF.Customizing AND rrole <> 3            ! Customize: the eye that shows or hides it
    SELF.DrawEye(right - SELF.Px(7), y + rh / 2, CHOOSE(SELF.Items.UserHidden = 0, 1, 0), CHOOSE(SELF.Items.UserHidden = 0, SELF.ClrAccent, SELF.ClrDisabled))
    right -= SELF.Px(22)
  END
  ! sub-menu marker
  IF SELF.Rows.HasKids
    cx = right - SELF.Px(4)
    cy = y + rh / 2
    IF SELF.SubStyle = MTP:Inline AND SELF.Items.Expanded
      SELF.PLine(cx - SELF.Px(4), cy - SELF.Px(2), cx, cy + SELF.Px(2), SELF.ClrTextDim, SELF.Px(1.5))
      SELF.PLine(cx, cy + SELF.Px(2), cx + SELF.Px(4), cy - SELF.Px(2), SELF.ClrTextDim, SELF.Px(1.5))
    ELSE
      SELF.PLine(cx - SELF.Px(2), cy - SELF.Px(4), cx + SELF.Px(2), cy, SELF.ClrTextDim, SELF.Px(1.5))
      SELF.PLine(cx + SELF.Px(2), cy, cx - SELF.Px(2), cy + SELF.Px(4), SELF.ClrTextDim, SELF.Px(1.5))
    END
    right -= SELF.Px(14)
  END
  IF acts                                       ! the hover buttons take the right-hand end
    right = SELF.DrawActs(oid, right, y, rh)
  ELSIF CLIP(SELF.Search) <> '' AND ~SELF.Rows.HasKids   ! a search result: where it lives, dimmed
    path = SELF.PathOf(id)
    SELF.Items.Id = id
    GET(SELF.Items, SELF.Items.Id)
    IF path
      pw = SELF.TextW(path, 3) + 2
      IF pw > (right - tx) / 2                  ! too long: just the nearest submenu
        p = INSTRING(' <155> ', path, 1, 1)
        LOOP WHILE p
          path = SUB(path, p + 3, 160)
          p = INSTRING(' <155> ', path, 1, 1)
        END
        pw = SELF.TextW(path, 3) + 2
      END
      IF pw > (right - tx) / 2 THEN pw = (right - tx) / 2.
      SELF.PText(right - pw, y, pw, rh, path, SELF.ClrTextDim, 3, 2)
      right -= pw + SELF.Px(6)
    END
  ELSIF SELF.ShowShortcuts AND SELF.Items.Shortcut AND ~SELF.Rows.HasKids
    SELF.PText(right - SELF.Px(74), y, SELF.Px(74), rh, SELF.Items.Shortcut, SELF.ClrTextDim, 3, 2)
    right -= SELF.Px(78)
  END
  IF CLIP(SELF.Items.Badge) <> '' AND ~acts
    right -= SELF.DrawPill(right, y + rh / 2, SELF.Items.Badge, CHOOSE(SELF.Items.Enabled = 0, SELF.ClrDisabled, CHOOSE(SELF.Items.BadgeClr = -1, SELF.ClrAccent, SELF.Items.BadgeClr)), MTP_Hex(0FFFFFFh)) + SELF.Px(6)
  END
  font = CHOOSE(SELF.Items.Bold = 1, 1, 0)
  SELF.PText(tx, y, right - tx, rh, SELF.Items.Text, clr, font, 0)

! ============================================================================
!  built-in vector icons, drawn in a 16x16 box with the painter, so they are
!  sharp at any DPI and look the same in both engines.
! ============================================================================
MyTaskPanelClass.DrawGlyph PROCEDURE(STRING glyph, REAL x, REAL y, REAL sz, LONG clr)
u                      REAL
lw                     REAL
soft                   LONG
white                  LONG
g                      STRING(24)
  CODE
  u  = sz / 16
  lw = CHOOSE(u * 1.4 < 1, 1, u * 1.4)
  soft  = SELF.Mix(clr, SELF.ClrCard, 0.65)
  white = MTP_Hex(0FFFFFFh)
  g = LOWER(glyph)
  CASE CLIP(g)
  OF 'folder'
    SELF.PRound(x + 1*u, y + 3*u, 6*u, 3*u, 1*u, clr)
    SELF.PRound(x + 1*u, y + 5*u, 14*u, 9*u, 1.5*u, clr)
    SELF.PFill(x + 2*u, y + 7*u, 12*u, 1*u, SELF.Mix(clr, white, 0.35))
  OF 'table'
    SELF.PRound(x + 1*u, y + 2*u, 14*u, 12*u, 1.5*u, -1, clr)
    SELF.PFill(x + 1*u, y + 2*u, 14*u, 3.5*u, clr)
    SELF.PLine(x + 1.5*u, y + 9*u, x + 14.5*u, y + 9*u, clr, lw * 0.8)
    SELF.PLine(x + 6*u, y + 5*u, x + 6*u, y + 13.5*u, clr, lw * 0.8)
  OF 'user'
    SELF.PEllipse(x + 8*u, y + 5*u, 3*u, 3*u, clr)
    SELF.PRound(x + 3*u, y + 9.5*u, 10*u, 5.5*u, 2.75*u, clr)
  OF 'users'
    SELF.PEllipse(x + 11*u, y + 5*u, 2.5*u, 2.5*u, soft)
    SELF.PRound(x + 7.5*u, y + 9*u, 8*u, 5*u, 2.5*u, soft)
    SELF.PEllipse(x + 6*u, y + 5.5*u, 2.8*u, 2.8*u, clr)
    SELF.PRound(x + 1*u, y + 9.5*u, 10*u, 5.5*u, 2.75*u, clr)
  OF 'box'
    SELF.PRound(x + 2*u, y + 3*u, 12*u, 11*u, 1.5*u, clr)
    SELF.PFill(x + 2*u, y + 6.5*u, 12*u, 1*u, SELF.Mix(clr, white, 0.4))
    SELF.PFill(x + 7*u, y + 3*u, 2*u, 3.5*u, SELF.Mix(clr, white, 0.4))
  OF 'doc'
  OROF 'report'
    SELF.PRound(x + 3*u, y + 1*u, 10*u, 14*u, 1.5*u, -1, clr)
    SELF.PLine(x + 5.5*u, y + 5*u, x + 10.5*u, y + 5*u, clr, lw)
    SELF.PLine(x + 5.5*u, y + 8*u, x + 10.5*u, y + 8*u, clr, lw)
    SELF.PLine(x + 5.5*u, y + 11*u, x + 9*u, y + 11*u, clr, lw)
  OF 'chart'
    SELF.PFill(x + 2*u, y + 9*u, 3*u, 5*u, clr)
    SELF.PFill(x + 6.5*u, y + 5*u, 3*u, 9*u, clr)
    SELF.PFill(x + 11*u, y + 2*u, 3*u, 12*u, clr)
    SELF.PFill(x + 1*u, y + 14.2*u, 14*u, 1*u, soft)
  OF 'export'
    SELF.PRound(x + 1*u, y + 1*u, 9*u, 14*u, 1.5*u, -1, clr)
    SELF.PLine(x + 6*u, y + 8*u, x + 15*u, y + 8*u, clr, lw * 1.2)
    SELF.PLine(x + 11.5*u, y + 4.5*u, x + 15*u, y + 8*u, clr, lw * 1.2)
    SELF.PLine(x + 11.5*u, y + 11.5*u, x + 15*u, y + 8*u, clr, lw * 1.2)
  OF 'import'
    SELF.PRound(x + 6*u, y + 1*u, 9*u, 14*u, 1.5*u, -1, clr)
    SELF.PLine(x + 1*u, y + 8*u, x + 10*u, y + 8*u, clr, lw * 1.2)
    SELF.PLine(x + 6.5*u, y + 4.5*u, x + 10*u, y + 8*u, clr, lw * 1.2)
    SELF.PLine(x + 6.5*u, y + 11.5*u, x + 10*u, y + 8*u, clr, lw * 1.2)
  OF 'excel'
  OROF 'csv'
  OROF 'pdf'
  OROF 'html'
  OROF 'xml'
  OROF 'json'
  OROF 'txt'
    CASE CLIP(g)
    OF 'excel' ; soft = MTP_Hex(01D6F42h)
    OF 'csv'   ; soft = MTP_Hex(00E7C86h)
    OF 'pdf'   ; soft = MTP_Hex(0B42318h)
    OF 'html'  ; soft = MTP_Hex(0C2410Ch)
    OF 'xml'   ; soft = MTP_Hex(0475569h)
    OF 'json'  ; soft = MTP_Hex(0A16207h)
    ELSE       ; soft = MTP_Hex(06B7280h)
    END
    SELF.PRound(x + 2.5*u, y + 1*u, 11*u, 14*u, 1.5*u, white, SELF.Mix(soft, white, 0.35))
    SELF.PRound(x + 1*u, y + 7*u, 14*u, 6.5*u, 1.2*u, soft)
    SELF.PLine(x + 5*u, y + 4*u, x + 11*u, y + 4*u, SELF.Mix(soft, white, 0.4), lw * 0.8)
    IF CLIP(g) = 'excel'
      SELF.PLine(x + 5.5*u, y + 8.2*u, x + 10.5*u, y + 12.3*u, white, lw)
      SELF.PLine(x + 10.5*u, y + 8.2*u, x + 5.5*u, y + 12.3*u, white, lw)
    ELSE
      SELF.PLine(x + 3.5*u, y + 10.25*u, x + 12.5*u, y + 10.25*u, white, lw)
    END
  OF 'print'
    SELF.PFill(x + 4*u, y + 1.5*u, 8*u, 4*u, soft)
    SELF.PRound(x + 1*u, y + 5*u, 14*u, 7*u, 1.5*u, clr)
    SELF.PRound(x + 4*u, y + 9.5*u, 8*u, 5*u, 0.5*u, white, clr)
  OF 'mail'
    SELF.PRound(x + 1*u, y + 3*u, 14*u, 10*u, 1.5*u, -1, clr)
    SELF.PLine(x + 1.5*u, y + 3.8*u, x + 8*u, y + 9*u, clr, lw)
    SELF.PLine(x + 8*u, y + 9*u, x + 14.5*u, y + 3.8*u, clr, lw)
  OF 'help'
  OROF 'info'
    SELF.PEllipse(x + 8*u, y + 8*u, 6.6*u, 6.6*u, -1, clr, lw * 1.1)
    IF CLIP(g) = 'help'
      SELF.PText(x, y + 0.5*u, 16*u, 15*u, '?', clr, 1, 1)
    ELSE
      SELF.PFill(x + 7.2*u, y + 7*u, 1.6*u, 4.8*u, clr)
      SELF.PEllipse(x + 8*u, y + 4.8*u, 1*u, 1*u, clr)
    END
  OF 'book'
    SELF.PRound(x + 1*u, y + 2*u, 6.5*u, 12*u, 1*u, clr)
    SELF.PRound(x + 8.5*u, y + 2*u, 6.5*u, 12*u, 1*u, clr)
    SELF.PLine(x + 2.5*u, y + 5*u, x + 6*u, y + 5*u, SELF.Mix(clr, white, 0.5), lw * 0.8)
    SELF.PLine(x + 10*u, y + 5*u, x + 13.5*u, y + 5*u, SELF.Mix(clr, white, 0.5), lw * 0.8)
  OF 'globe'
  OROF 'web'
    SELF.PEllipse(x + 8*u, y + 8*u, 6.5*u, 6.5*u, -1, clr, lw)
    SELF.PEllipse(x + 8*u, y + 8*u, 3*u, 6.5*u, -1, clr, lw * 0.8)
    SELF.PLine(x + 1.5*u, y + 8*u, x + 14.5*u, y + 8*u, clr, lw * 0.8)
  OF 'gear'
  OROF 'settings'
    SELF.PLine(x + 8*u, y + 1*u, x + 8*u, y + 15*u, clr, 2.6*u)
    SELF.PLine(x + 1*u, y + 8*u, x + 15*u, y + 8*u, clr, 2.6*u)
    SELF.PLine(x + 3*u, y + 3*u, x + 13*u, y + 13*u, clr, 2.6*u)
    SELF.PLine(x + 13*u, y + 3*u, x + 3*u, y + 13*u, clr, 2.6*u)
    SELF.PEllipse(x + 8*u, y + 8*u, 5*u, 5*u, clr)
    SELF.PEllipse(x + 8*u, y + 8*u, 2*u, 2*u, SELF.ClrCard)
  OF 'tools'
    SELF.PLine(x + 3*u, y + 13*u, x + 10*u, y + 6*u, clr, 2.6*u)
    SELF.PEllipse(x + 11*u, y + 5*u, 3.5*u, 3.5*u, clr)
    SELF.PEllipse(x + 12.2*u, y + 3.8*u, 1.5*u, 1.5*u, SELF.ClrCard)
  OF 'backup'
  OROF 'database'
    SELF.PFill(x + 2*u, y + 3.5*u, 12*u, 9*u, clr)
    SELF.PEllipse(x + 8*u, y + 12.5*u, 6*u, 2.2*u, clr)
    SELF.PEllipse(x + 8*u, y + 3.5*u, 6*u, 2.2*u, SELF.Mix(clr, white, 0.35))
    SELF.PLine(x + 2.5*u, y + 8*u, x + 13.5*u, y + 8*u, SELF.Mix(clr, white, 0.35), lw * 0.8)
  OF 'restore'
  OROF 'refresh'
    SELF.PEllipse(x + 8*u, y + 8*u, 5.5*u, 5.5*u, -1, clr, lw * 1.2)
    SELF.PFill(x + 9*u, y + 1*u, 6*u, 5.5*u, SELF.ClrCard)
    SELF.PLine(x + 9*u, y + 2.5*u, x + 13.5*u, y + 2.5*u, clr, lw * 1.2)
    SELF.PLine(x + 13.5*u, y + 2.5*u, x + 13.5*u, y + 7*u, clr, lw * 1.2)
  OF 'key'
    SELF.PEllipse(x + 5*u, y + 8*u, 3.5*u, 3.5*u, -1, clr, lw * 1.3)
    SELF.PLine(x + 8.5*u, y + 8*u, x + 15*u, y + 8*u, clr, lw * 1.3)
    SELF.PLine(x + 13*u, y + 8*u, x + 13*u, y + 11*u, clr, lw * 1.3)
    SELF.PLine(x + 10.5*u, y + 8*u, x + 10.5*u, y + 10.5*u, clr, lw * 1.3)
  OF 'lock'
    SELF.PRound(x + 4.5*u, y + 1.5*u, 7*u, 9*u, 3.5*u, -1, clr)
    SELF.PRound(x + 2.5*u, y + 7*u, 11*u, 8*u, 1.5*u, clr)
  OF 'exit'
  OROF 'logout'
    SELF.PRound(x + 1.5*u, y + 1.5*u, 8*u, 13*u, 1*u, -1, clr)
    SELF.PLine(x + 6*u, y + 8*u, x + 15*u, y + 8*u, clr, lw * 1.2)
    SELF.PLine(x + 12*u, y + 5*u, x + 15*u, y + 8*u, clr, lw * 1.2)
    SELF.PLine(x + 12*u, y + 11*u, x + 15*u, y + 8*u, clr, lw * 1.2)
  OF 'home'
    SELF.PLine(x + 1*u, y + 8*u, x + 8*u, y + 1.5*u, clr, lw * 1.4)
    SELF.PLine(x + 8*u, y + 1.5*u, x + 15*u, y + 8*u, clr, lw * 1.4)
    SELF.PFill(x + 3.5*u, y + 7.5*u, 9*u, 7*u, clr)
    SELF.PFill(x + 6.8*u, y + 10*u, 2.4*u, 4.5*u, SELF.ClrCard)
  OF 'star'
  OROF 'favorite'
    SELF.PLine(x + 8*u, y + 1*u, x + 10*u, y + 6*u, clr, lw)
    SELF.PLine(x + 10*u, y + 6*u, x + 15*u, y + 6*u, clr, lw)
    SELF.PLine(x + 15*u, y + 6*u, x + 11*u, y + 9.5*u, clr, lw)
    SELF.PLine(x + 11*u, y + 9.5*u, x + 12.5*u, y + 15*u, clr, lw)
    SELF.PLine(x + 12.5*u, y + 15*u, x + 8*u, y + 11.5*u, clr, lw)
    SELF.PLine(x + 8*u, y + 11.5*u, x + 3.5*u, y + 15*u, clr, lw)
    SELF.PLine(x + 3.5*u, y + 15*u, x + 5*u, y + 9.5*u, clr, lw)
    SELF.PLine(x + 5*u, y + 9.5*u, x + 1*u, y + 6*u, clr, lw)
    SELF.PLine(x + 1*u, y + 6*u, x + 6*u, y + 6*u, clr, lw)
    SELF.PLine(x + 6*u, y + 6*u, x + 8*u, y + 1*u, clr, lw)
  OF 'clock'
  OROF 'recent'
    SELF.PEllipse(x + 8*u, y + 8*u, 6.5*u, 6.5*u, -1, clr, lw)
    SELF.PLine(x + 8*u, y + 4*u, x + 8*u, y + 8.3*u, clr, lw)
    SELF.PLine(x + 8*u, y + 8*u, x + 11*u, y + 10*u, clr, lw)
  OF 'window'
    SELF.PRound(x + 1*u, y + 2*u, 14*u, 12*u, 1.5*u, -1, clr)
    SELF.PFill(x + 1*u, y + 2*u, 14*u, 3*u, clr)
  OF 'tile'
    SELF.PRound(x + 1*u, y + 1*u, 6.5*u, 6.5*u, 1*u, clr)
    SELF.PRound(x + 8.5*u, y + 1*u, 6.5*u, 6.5*u, 1*u, clr)
    SELF.PRound(x + 1*u, y + 8.5*u, 6.5*u, 6.5*u, 1*u, clr)
    SELF.PRound(x + 8.5*u, y + 8.5*u, 6.5*u, 6.5*u, 1*u, clr)
  OF 'cascade'
    SELF.PRound(x + 1*u, y + 1*u, 9*u, 8*u, 1*u, soft)
    SELF.PRound(x + 3.5*u, y + 3.5*u, 9*u, 8*u, 1*u, SELF.Mix(clr, SELF.ClrCard, 0.35))
    SELF.PRound(x + 6*u, y + 6*u, 9*u, 8*u, 1*u, clr)
  OF 'calendar'
    SELF.PRound(x + 1.5*u, y + 2.5*u, 13*u, 12*u, 1.5*u, -1, clr)
    SELF.PFill(x + 1.5*u, y + 2.5*u, 13*u, 3.5*u, clr)
    SELF.PFill(x + 4*u, y + 8*u, 2*u, 2*u, clr)
    SELF.PFill(x + 7*u, y + 8*u, 2*u, 2*u, clr)
    SELF.PFill(x + 10*u, y + 8*u, 2*u, 2*u, clr)
    SELF.PFill(x + 4*u, y + 11*u, 2*u, 2*u, clr)
  OF 'money'
    SELF.PRound(x + 1*u, y + 3.5*u, 14*u, 9*u, 1.5*u, clr)
    SELF.PEllipse(x + 8*u, y + 8*u, 2.5*u, 2.5*u, SELF.Mix(clr, white, 0.55))
  OF 'cart'
    SELF.PLine(x + 1*u, y + 2*u, x + 3.5*u, y + 2*u, clr, lw)
    SELF.PLine(x + 3.5*u, y + 2*u, x + 5*u, y + 10*u, clr, lw)
    SELF.PRound(x + 4.5*u, y + 4*u, 10.5*u, 6*u, 1*u, clr)
    SELF.PEllipse(x + 6*u, y + 13*u, 1.5*u, 1.5*u, clr)
    SELF.PEllipse(x + 12.5*u, y + 13*u, 1.5*u, 1.5*u, clr)
  OF 'truck'
    SELF.PRound(x + 0.5*u, y + 3*u, 9.5*u, 8*u, 1*u, clr)
    SELF.PRound(x + 10.5*u, y + 6*u, 5*u, 5*u, 1*u, soft)
    SELF.PEllipse(x + 4*u, y + 12.5*u, 2*u, 2*u, clr)
    SELF.PEllipse(x + 12.5*u, y + 12.5*u, 2*u, 2*u, clr)
  OF 'search'
  OROF 'find'
    SELF.PEllipse(x + 6.5*u, y + 6.5*u, 4.5*u, 4.5*u, -1, clr, lw * 1.3)
    SELF.PLine(x + 10*u, y + 10*u, x + 14.5*u, y + 14.5*u, clr, lw * 1.8)
  OF 'plus'
  OROF 'new'
    SELF.PEllipse(x + 8*u, y + 8*u, 6.6*u, 6.6*u, -1, clr, lw * 1.1)
    SELF.PLine(x + 8*u, y + 4.5*u, x + 8*u, y + 11.5*u, clr, lw * 1.3)
    SELF.PLine(x + 4.5*u, y + 8*u, x + 11.5*u, y + 8*u, clr, lw * 1.3)
  OF 'link'
    SELF.PRound(x + 1*u, y + 5*u, 8.5*u, 6*u, 3*u, -1, clr)
    SELF.PRound(x + 6.5*u, y + 5*u, 8.5*u, 6*u, 3*u, -1, clr)
  OF 'menu'
    SELF.PRound(x + 2*u, y + 3*u, 12*u, 2*u, 1*u, clr)
    SELF.PRound(x + 2*u, y + 7*u, 12*u, 2*u, 1*u, clr)
    SELF.PRound(x + 2*u, y + 11*u, 12*u, 2*u, 1*u, clr)
  OF 'bell'
    SELF.PRound(x + 3.5*u, y + 2*u, 9*u, 10*u, 4.5*u, clr)
    SELF.PFill(x + 2*u, y + 10*u, 12*u, 2*u, clr)
    SELF.PEllipse(x + 8*u, y + 13.5*u, 1.8*u, 1.8*u, clr)
  OF 'phone'
    SELF.PRound(x + 4*u, y + 1*u, 8*u, 14*u, 2*u, clr)
    SELF.PFill(x + 5.5*u, y + 3*u, 5*u, 8.5*u, SELF.Mix(clr, white, 0.6))
  ELSE
    SELF.PEllipse(x + 8*u, y + 8*u, 2.5*u, 2.5*u, clr)
  END

! ============================================================================
!  the painter - one call, two engines
! ============================================================================
MyTaskPanelClass.Rgb PROCEDURE(LONG clr)
  CODE
  IF clr < 0 THEN RETURN mtp_GetSysColor(BAND(clr, 0FFh)).   ! COLOR:BtnFace and friends
  RETURN BAND(clr, 0FFFFFFh)

MyTaskPanelClass.Argb PROCEDURE(LONG clr)
c                      LONG
  CODE
  IF clr = -1 THEN RETURN 0.                    ! COLOR:None: transparent
  c = SELF.Rgb(clr)
  RETURN BOR(-16777216, BAND(c, 0FFh) * 65536 + BAND(c, 0FF00h) + BAND(BSHIFT(c, -16), 0FFh))

!  0xAARRGGBB for Direct2D with an opacity of a (0..1).
MyTaskPanelClass.Alpha PROCEDURE(LONG clr, REAL a)
n                      LONG
  CODE
  n = INT(a * 255 + 0.5)
  IF n < 0 THEN n = 0.
  IF n > 255 THEN n = 255.
  RETURN BOR(BAND(SELF.Argb(clr), 0FFFFFFh), BSHIFT(n, 24))

MyTaskPanelClass.Mix PROCEDURE(LONG c1, LONG c2, REAL t)
a                      LONG
b                      LONG
  CODE
  a = SELF.Rgb(c1)
  b = SELF.Rgb(c2)
  RETURN INT(BAND(a, 0FFh) + (BAND(b, 0FFh) - BAND(a, 0FFh)) * t + 0.5) +                               |
         INT(BAND(BSHIFT(a, -8), 0FFh) + (BAND(BSHIFT(b, -8), 0FFh) - BAND(BSHIFT(a, -8), 0FFh)) * t + 0.5) * 256 + |
         INT(BAND(BSHIFT(a, -16), 0FFh) + (BAND(BSHIFT(b, -16), 0FFh) - BAND(BSHIFT(a, -16), 0FFh)) * t + 0.5) * 65536

MyTaskPanelClass.MakeFonts PROCEDURE
face                   CSTRING(41)
h                      LONG
  CODE
  IF SELF.FontN THEN RETURN.
  face = CLIP(SELF.FontName)
  h = -INT(SELF.FontSize * SELF.Dpi / 72 + 0.5)
  SELF.FontN = mtp_CreateFont(h, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, ADDRESS(face))
  SELF.FontB = mtp_CreateFont(h, 0, 0, 0, 600, 0, 0, 0, 1, 0, 0, 5, 0, ADDRESS(face))
  SELF.FontT = mtp_CreateFont(-INT((SELF.FontSize + 1) * SELF.Dpi / 72 + 0.5), 0, 0, 0, 600, 0, 0, 0, 1, 0, 0, 5, 0, ADDRESS(face))
  SELF.FontS = mtp_CreateFont(-INT((SELF.FontSize - 1) * SELF.Dpi / 72 + 0.5), 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, ADDRESS(face))

MyTaskPanelClass.FreeFonts PROCEDURE
  CODE
  IF SELF.FontN THEN mtp_DeleteObject(SELF.FontN).
  IF SELF.FontB THEN mtp_DeleteObject(SELF.FontB).
  IF SELF.FontT THEN mtp_DeleteObject(SELF.FontT).
  IF SELF.FontS THEN mtp_DeleteObject(SELF.FontS).
  SELF.FontN = 0
  SELF.FontB = 0
  SELF.FontT = 0
  SELF.FontS = 0

!  Loads the current SELF.Items record's icon: a file on disk, or an icon
!  linked into the program (Clarion files those by upper-case file name).
MyTaskPanelClass.LoadIcon PROCEDURE
nm                     CSTRING(256)
sz                     LONG
  CODE
  SELF.Items.HIcon = 0
  IF ~SELF.Items.IconFile THEN RETURN.
  nm = CLIP(SELF.Items.IconFile)
  IF nm[1] = '~' THEN nm = SUB(nm, 2, 255).
  sz = SELF.Px(16)
  IF EXISTS(nm)
    SELF.Items.HIcon = mtp_LoadImage(0, ADDRESS(nm), 1, sz, sz, 010h)          ! IMAGE_ICON, LR_LOADFROMFILE
  END
  IF ~SELF.Items.HIcon
    nm = UPPER(nm)
    SELF.Items.HIcon = mtp_LoadImage(mtp_GetModuleHandle(0), ADDRESS(nm), 1, sz, sz, 0)
  END

MyTaskPanelClass.PFill PROCEDURE(REAL x, REAL y, REAL w, REAL h, LONG clr)
r                      LIKE(MTP_Rect)
br                     LONG
  CODE
  IF clr = -1 OR w <= 0 OR h <= 0 THEN RETURN.
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.UseD2D
    mtp_d2_fill(x, y, w, h, SELF.Argb(clr))
    RETURN
  END
  ! ENDD2D
  r.X1 = INT(x + 0.5)
  r.Y1 = INT(y + 0.5)
  r.X2 = INT(x + w + 0.5)
  r.Y2 = INT(y + h + 0.5)
  IF r.X2 <= r.X1 THEN r.X2 = r.X1 + 1.
  IF r.Y2 <= r.Y1 THEN r.Y2 = r.Y1 + 1.
  br = mtp_CreateSolidBrush(SELF.Rgb(clr))
  mtp_FillRect(SELF.DC, ADDRESS(r), br)
  mtp_DeleteObject(br)

MyTaskPanelClass.PRound PROCEDURE(REAL x, REAL y, REAL w, REAL h, REAL r, LONG fill, LONG line=-1)
br                     LONG
pn                     LONG
ob                     LONG
op                     LONG
L                      LONG
T                      LONG
  CODE
  IF w <= 0 OR h <= 0 THEN RETURN.
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.UseD2D
    mtp_d2_round(x, y, w, h, r, SELF.Argb(fill), SELF.Argb(line), 1)
    RETURN
  END
  ! ENDD2D
  br = CHOOSE(fill = -1, mtp_GetStockObject(5), mtp_CreateSolidBrush(SELF.Rgb(fill)))   ! NULL_BRUSH
  pn = CHOOSE(line = -1, mtp_GetStockObject(8), mtp_CreatePen(0, 1, SELF.Rgb(line)))    ! NULL_PEN
  ob = mtp_SelectObject(SELF.DC, br)
  op = mtp_SelectObject(SELF.DC, pn)
  L = INT(x + 0.5)
  T = INT(y + 0.5)
  !  A NULL pen leaves the right and bottom edge unfilled, so grow by one.
  mtp_RoundRect(SELF.DC, L, T, INT(x + w + 0.5) + CHOOSE(line = -1, 1, 0), INT(y + h + 0.5) + CHOOSE(line = -1, 1, 0), INT(r * 2 + 0.5), INT(r * 2 + 0.5))
  mtp_SelectObject(SELF.DC, ob)
  mtp_SelectObject(SELF.DC, op)
  IF fill <> -1 THEN mtp_DeleteObject(br).
  IF line <> -1 THEN mtp_DeleteObject(pn).

MyTaskPanelClass.PGrad PROCEDURE(REAL x, REAL y, REAL w, REAL h, REAL r, LONG c1, LONG c2)
i                      LONG
n                      LONG
L                      LONG
T                      LONG
rgn                    LONG
  CODE
  IF w <= 0 OR h <= 0 THEN RETURN.
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.UseD2D
    mtp_d2_grad(x, y, w, h, r, SELF.Argb(c1), SELF.Argb(c2))
    RETURN
  END
  ! ENDD2D
  L = INT(x + 0.5)
  T = INT(y + 0.5)
  n = INT(h + 0.5)
  IF r > 0
    mtp_SaveDC(SELF.DC)
    rgn = mtp_CreateRoundRectRgn(L, T, INT(x + w + 0.5) + 1, T + n + 1, INT(r * 2 + 0.5), INT(r * 2 + 0.5))
    mtp_ExtSelectClipRgn(SELF.DC, rgn, 1)       ! RGN_AND
    mtp_DeleteObject(rgn)
  END
  !  One band per pixel row: the same result as GradientFill, without msimg32.
  LOOP i = 0 TO n - 1
    SELF.PFill(L, T + i, w, 1, SELF.Mix(c1, c2, CHOOSE(n > 1, i / (n - 1), 0)))
  END
  IF r > 0 THEN mtp_RestoreDC(SELF.DC, -1).

MyTaskPanelClass.PLine PROCEDURE(REAL x1, REAL y1, REAL x2, REAL y2, LONG clr, REAL lw=1)
pn                     LONG
op                     LONG
  CODE
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.UseD2D
    mtp_d2_line(x1, y1, x2, y2, SELF.Argb(clr), lw)
    RETURN
  END
  ! ENDD2D
  pn = mtp_CreatePen(0, CHOOSE(lw < 1, 1, INT(lw + 0.5)), SELF.Rgb(clr))
  op = mtp_SelectObject(SELF.DC, pn)
  mtp_MoveToEx(SELF.DC, INT(x1 + 0.5), INT(y1 + 0.5), 0)
  mtp_LineTo(SELF.DC, INT(x2 + 0.5), INT(y2 + 0.5))
  mtp_SelectObject(SELF.DC, op)
  mtp_DeleteObject(pn)

MyTaskPanelClass.PEllipse PROCEDURE(REAL cx, REAL cy, REAL rx, REAL ry, LONG fill, LONG line=-1, REAL lw=1)
br                     LONG
pn                     LONG
ob                     LONG
op                     LONG
  CODE
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.UseD2D
    mtp_d2_ellipse(cx, cy, rx, ry, SELF.Argb(fill), SELF.Argb(line), lw)
    RETURN
  END
  ! ENDD2D
  br = CHOOSE(fill = -1, mtp_GetStockObject(5), mtp_CreateSolidBrush(SELF.Rgb(fill)))
  pn = CHOOSE(line = -1, mtp_GetStockObject(8), mtp_CreatePen(0, CHOOSE(lw < 1, 1, INT(lw + 0.5)), SELF.Rgb(line)))
  ob = mtp_SelectObject(SELF.DC, br)
  op = mtp_SelectObject(SELF.DC, pn)
  mtp_Ellipse(SELF.DC, INT(cx - rx + 0.5), INT(cy - ry + 0.5), INT(cx + rx + 0.5) + CHOOSE(line = -1, 1, 0), INT(cy + ry + 0.5) + CHOOSE(line = -1, 1, 0))
  mtp_SelectObject(SELF.DC, ob)
  mtp_SelectObject(SELF.DC, op)
  IF fill <> -1 THEN mtp_DeleteObject(br).
  IF line <> -1 THEN mtp_DeleteObject(pn).

!  font: 0 normal, 1 bold, 2 title, 3 small. align: 0 left, 1 centre, 2 right.
MyTaskPanelClass.PText PROCEDURE(REAL x, REAL y, REAL w, REAL h, STRING txt, LONG clr, BYTE font=0, BYTE align=0)
cs                     CSTRING(256)
r                      LIKE(MTP_Rect)
f                      LONG
face                   CSTRING(41)
pt                     REAL
  CODE
  IF w <= 0 OR ~txt THEN RETURN.
  cs = CLIP(txt)
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.UseD2D
    face = CLIP(SELF.FontName)
    CASE font
    OF 2 ; pt = SELF.FontSize + 1
    OF 3 ; pt = SELF.FontSize - 1
    ELSE ; pt = SELF.FontSize
    END
    pt = pt * SELF.Dpi / 96
    mtp_d2_text(ADDRESS(cs), x, y, w, h, SELF.Argb(clr), ADDRESS(face), pt, CHOOSE(font = 1 OR font = 2, 1, 0), align)
    RETURN
  END
  ! ENDD2D
  CASE font
  OF 1 ; f = SELF.FontB
  OF 2 ; f = SELF.FontT
  OF 3 ; f = SELF.FontS
  ELSE ; f = SELF.FontN
  END
  mtp_SelectObject(SELF.DC, f)
  mtp_SetTextColor(SELF.DC, SELF.Rgb(clr))
  r.X1 = INT(x + 0.5)
  r.Y1 = INT(y + 0.5)
  r.X2 = INT(x + w + 0.5)
  r.Y2 = INT(y + h + 0.5)
  mtp_DrawText(SELF.DC, ADDRESS(cs), -1, ADDRESS(r), 08824h + align)   ! SINGLELINE|VCENTER|NOPREFIX|END_ELLIPSIS

MyTaskPanelClass.PClip PROCEDURE(REAL x, REAL y, REAL w, REAL h)
  CODE
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.UseD2D
    mtp_d2_clip(x, y, w, h)
    RETURN
  END
  ! ENDD2D
  mtp_SaveDC(SELF.DC)
  mtp_IntersectClipRect(SELF.DC, INT(x + 0.5), INT(y + 0.5), INT(x + w + 0.5), INT(y + h + 0.5))

MyTaskPanelClass.PUnclip PROCEDURE
  CODE
  COMPILE('ENDD2D',_MTP_D2D_)
  IF SELF.UseD2D
    mtp_d2_unclip()
    RETURN
  END
  ! ENDD2D
  mtp_RestoreDC(SELF.DC, -1)

MyTaskPanelClass.PIcon PROCEDURE(LONG hIcon, REAL x, REAL y, REAL sz)
  CODE
  IF ~hIcon THEN RETURN.
  IF SELF.UseD2D                                ! drawn by GDI after EndDraw
    SELF.PendIcons.X = INT(x + 0.5)
    SELF.PendIcons.Y = INT(y + 0.5)
    SELF.PendIcons.Sz = INT(sz + 0.5)
    SELF.PendIcons.HIcon = hIcon
    ADD(SELF.PendIcons)
    RETURN
  END
  mtp_DrawIconEx(SELF.DC, INT(x + 0.5), INT(y + 0.5), hIcon, INT(sz + 0.5), INT(sz + 0.5), 0, 0, 3)
