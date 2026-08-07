#TEMPLATE(BrowseGrid,'BrowseGrid - draw any browse with Direct2D - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  BrowseGrid  -  a browse that does not look like 1995.
#!
#!  Drop it on a procedure that already has an ABC browse, point it at the
#!  LIST, and the LIST is hidden and a Direct2D grid drawn in its place:
#!  banded rows, a proper header, frozen columns, crisp DirectWrite text and
#!  any colours you like.
#!
#!  WHAT IT DOES NOT TOUCH. The browse. BrowseClass keeps the file, the sort
#!  order, the filter, the range limit and the locator, exactly as they are -
#!  this only replaces what the rows LOOK like. That is what makes it a drop-in
#!  rather than a rewrite, and it is why an existing browse keeps working if
#!  you disable the extension.
#!
#!  WHERE THE COLUMNS COME FROM. The LIST itself, at run time, through
#!  PROPLIST:Exists / FieldNo / Header / Width / Picture / Left / Right /
#!  Center / Decimal. So the widths, headings, pictures and alignment you
#!  already set in the window formatter carry straight over, and a column the
#!  user has resized or moved comes over as it now is - the same approach
#!  myExport uses to read any browse.
#!
#!  WHERE THE VALUES COME FROM. The browse's own QUEUE, read generically with
#!  WHAT(queue, fieldnumber) - so nothing here knows or cares what the file is.
#!
#!  REQUIRES d2grid.c on the redirection path (with the myImage files, if you
#!  have those). Direct2D and DirectWrite are part of Windows and are bound at
#!  run time, so there is no import library and nothing to ship.
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - BrowseGridGlobal
#!#############################################################################
#EXTENSION(BrowseGridGlobal,'BrowseGrid - Global (add once per application)'),APPLICATION,HLP('~BrowseGrid.htm')
#SHEET
  #TAB('&General')
    #BOXED('BrowseGrid')
      #DISPLAY('BrowseGrid - Version 1.0')
      #DISPLAY('Draws an ABC browse with Direct2D and DirectWrite instead of')
      #DISPLAY('the runtime LIST, without touching the browse underneath.')
      #DISPLAY('')
      #DISPLAY('REQUIRES d2grid.c on the redirection path.')
      #DISPLAY('Add this extension ONCE per application - and to EVERY app of')
      #DISPLAY('a multi-DLL set that carries a grid.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%bgGDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%bgGDisable=0)
  PRAGMA('compile(d2grid.c)')                                 ! the grid, built by Clarion's own C compiler
BG:Scrolled          EQUATE(EVENT:User + 244)                 ! a grid scrollbar moved
BG:GwlStyle          EQUATE(-16)
BG:GwlWndProc        EQUATE(-4)
BG:HScrollStyle      EQUATE(00100000h)
BG:VScrollStyle      EQUATE(00200000h)
BG:FrameChanged      EQUATE(0020h)
BG:NoMove            EQUATE(0002h)
BG:NoSize            EQUATE(0001h)
BG:NoZOrder          EQUATE(0004h)
BG:ClipSiblings      EQUATE(04000000h)                        ! WS_CLIPSIBLINGS
BG:Visible           EQUATE(10000000h)                        ! WS_VISIBLE
BG:HwndTop           EQUATE(0)
BG:SbHorz            EQUATE(0)
BG:SbVert            EQUATE(1)
BG:WmHScroll         EQUATE(0114h)
BG:WmVScroll         EQUATE(0115h)
BG:SifRange          EQUATE(1)
BG:SifPage           EQUATE(2)
BG:SifPos            EQUATE(4)
BG:SifTrack          EQUATE(10h)
BG:WmMouseWheel      EQUATE(020Ah)
BG:WheelNotch        EQUATE(120)                              ! WHEEL_DELTA
BG:WheelCode         EQUATE(99)                               ! not one of Windows' scroll codes
BG:WheelLines        EQUATE(3)                                ! rows per notch, as everything else does
BG:ThumbPct          EQUATE(12)                               ! fallback when the count is unknown
BG:FontCode          EQUATE(98)                               ! Ctrl-wheel resized the type
BG:MkControl         EQUATE(0008h)
BG:WmLButtonDown     EQUATE(0201h)
BG:WmLButtonUp       EQUATE(0202h)
BG:MkLButton         EQUATE(0001h)
BG:DragSlop          EQUATE(3)                                ! pixels before a click becomes a drag
BG:MaxScan           EQUATE(50000)                            ! records read looking for values
BG:MaxVals           EQUATE(500)                              ! distinct values offered
BG:VkLButton         EQUATE(1)
#ENDAT
#!
#!  The callback cannot hand anything to Clarion through POST, so what it saw
#!  is left here for the ACCEPT loop to pick up. Only one scrollbar can be
#!  moving at a time, so one set of variables is enough.
#AT(%GlobalData),WHERE(%bgGDisable=0)
BG:LastBar           LONG                                     ! 0 horizontal, 1 vertical
BG:LastCode          LONG                                     ! what the user did to it
BG:LastPos           LONG                                     ! and where the thumb ended up
#ENDAT
#!
#AT(%GlobalMap),WHERE(%bgGDisable=0)
#!  cdecl exports from C, so the Clarion name carries a leading underscore.
    MODULE('d2grid.c')
d2g_Available(),LONG,NAME('_d2g_Available')
d2g_Attach(LONG hwnd,*CSTRING face,LONG pt),LONG,RAW,NAME('_d2g_Attach')
d2g_Detach(LONG h),NAME('_d2g_Detach')
d2g_Columns(LONG h,LONG n),NAME('_d2g_Columns')
d2g_Column(LONG h,LONG col,LONG width,LONG align,*CSTRING title),RAW,NAME('_d2g_Column')
d2g_Frozen(LONG h,LONG n),NAME('_d2g_Frozen')
d2g_RowHeight(LONG h,LONG px),NAME('_d2g_RowHeight')
d2g_HeaderHeight(LONG h,LONG px),NAME('_d2g_HeaderHeight')
d2g_Total(LONG h,LONG n),NAME('_d2g_Total')
d2g_Select(LONG h,LONG row),NAME('_d2g_Select')
d2g_ScrollX(LONG h,LONG x),NAME('_d2g_ScrollX')
d2g_ScrollY(LONG h,LONG y),NAME('_d2g_ScrollY')
d2g_Colours(LONG h,ULONG back,ULONG band,ULONG grid,ULONG txt,ULONG hb,ULONG ht,ULONG sb,ULONG st),NAME('_d2g_Colours')
d2g_Page(LONG h,LONG firstRow,LONG rows),NAME('_d2g_Page')
d2g_Cell(LONG h,LONG visRow,LONG col,*CSTRING s),RAW,NAME('_d2g_Cell')
d2g_Repaint(LONG h),NAME('_d2g_Repaint')
d2g_PaintNow(LONG h),LONG,PROC,NAME('_d2g_PaintNow')
d2g_Resize(LONG h),LONG,PROC,NAME('_d2g_Resize')
d2g_PageSize(LONG h),LONG,NAME('_d2g_PageSize')
d2g_RowH(LONG h),LONG,NAME('_d2g_RowH')
d2g_HeaderH(LONG h),LONG,NAME('_d2g_HeaderH')
d2g_HitRow(LONG h,LONG y),LONG,NAME('_d2g_HitRow')
d2g_HitCol(LONG h,LONG x),LONG,NAME('_d2g_HitCol')
d2g_TotalWidth(LONG h),LONG,NAME('_d2g_TotalWidth')
d2g_HitEdge(LONG h,LONG x),LONG,NAME('_d2g_HitEdge')
d2g_ColWidth(LONG h,LONG col),LONG,NAME('_d2g_ColWidth')
d2g_SetWidth(LONG h,LONG col,LONG width),NAME('_d2g_SetWidth')
d2g_HdrHeight(LONG h),LONG,NAME('_d2g_HdrHeight')
d2g_FromHwnd(LONG hwnd),LONG,NAME('_d2g_FromHwnd')
d2g_VBar(LONG h,LONG show,LONG pos,LONG pct),NAME('_d2g_VBar')
d2g_VHit(LONG h,LONG x,LONG y),LONG,NAME('_d2g_VHit')
d2g_VGrab(LONG h,LONG y),LONG,NAME('_d2g_VGrab')
d2g_VDrag(LONG h,LONG y,LONG grab),LONG,NAME('_d2g_VDrag')
d2g_FontSize(LONG h,LONG pt),LONG,PROC,NAME('_d2g_FontSize')
d2g_FontPt(LONG h),LONG,NAME('_d2g_FontPt')
d2g_RowNeed(LONG h),LONG,NAME('_d2g_RowNeed')
d2g_SortMark(LONG h,LONG col,LONG dir),NAME('_d2g_SortMark')
d2g_Lines(LONG h,LONG n),NAME('_d2g_Lines')
d2g_Wrap(LONG h,LONG on,LONG lines),NAME('_d2g_Wrap')
d2g_HitGrpEdge(LONG h,LONG x),LONG,NAME('_d2g_HitGrpEdge')
d2g_GrpWidth(LONG h,LONG g),LONG,NAME('_d2g_GrpWidth')
d2g_SetGrpWidth(LONG h,LONG g,LONG width),NAME('_d2g_SetGrpWidth')
d2g_GrpColW(LONG h,LONG col),LONG,NAME('_d2g_GrpColW')
d2g_ColGrp(LONG h,LONG col),LONG,NAME('_d2g_ColGrp')
d2g_FilterBtns(LONG h,LONG on),NAME('_d2g_FilterBtns')
d2g_HitBtn(LONG h,LONG x,LONG y),LONG,NAME('_d2g_HitBtn')
d2g_FilterOn(LONG h,LONG col,LONG on),NAME('_d2g_FilterOn')
d2g_BarStyle(LONG h,LONG style),NAME('_d2g_BarStyle')
d2g_BarsShow(LONG h,LONG on),NAME('_d2g_BarsShow')
d2g_HBar(LONG h,LONG show,LONG pos,LONG page,LONG total),NAME('_d2g_HBar')
d2g_HitHBar(LONG h,LONG x,LONG y),LONG,NAME('_d2g_HitHBar')
d2g_HGrab(LONG h,LONG x),LONG,NAME('_d2g_HGrab')
d2g_HDrag(LONG h,LONG x,LONG grab),LONG,NAME('_d2g_HDrag')
d2g_Groups(LONG h,LONG n),NAME('_d2g_Groups')
d2g_Group(LONG h,LONG gi,LONG x,LONG width,*CSTRING title),RAW,NAME('_d2g_Group')
d2g_ColumnAt(LONG h,LONG col,LONG grp,LONG line,LONG x,LONG width,LONG align,*CSTRING title),RAW,NAME('_d2g_ColumnAt')
d2g_ViewWidth(LONG h),LONG,NAME('_d2g_ViewWidth')
    END
BG_Rgb(LONG),ULONG
BG_BarProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
BG_HookBars(LONG,LONG),BYTE,PROC
BG_DropBars(LONG),LONG,PROC
BG_SetBar(LONG,LONG,LONG,LONG,LONG)
BG_BarPos(LONG,LONG),LONG
    MODULE('win32')
bgApi_SetProp(ULONG hWnd,LONG lpString,LONG hData),LONG,PASCAL,PROC,NAME('SetPropA')
bgApi_GetProp(ULONG hWnd,LONG lpString),LONG,PASCAL,NAME('GetPropA')
bgApi_RemoveProp(ULONG hWnd,LONG lpString),LONG,PASCAL,PROC,NAME('RemovePropA')
bgApi_CallWndProc(LONG lpPrev,ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam),LONG,PASCAL,NAME('CallWindowProcA')
bgApi_SetWindowLong(ULONG hWnd,LONG nIndex,LONG dwNewLong),LONG,PASCAL,PROC,NAME('SetWindowLongA')
bgApi_GetWindowLong(ULONG hWnd,LONG nIndex),LONG,PASCAL,NAME('GetWindowLongA')
bgApi_SetWindowPos(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG flags),LONG,PASCAL,PROC,NAME('SetWindowPos')
bgApi_SetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi,LONG redraw),LONG,PASCAL,PROC,NAME('SetScrollInfo')
bgApi_GetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi),LONG,PASCAL,PROC,NAME('GetScrollInfo')
bgApi_GetAsyncKeyState(LONG vKey),SHORT,PASCAL,NAME('GetAsyncKeyState')
bgApi_PostMessage(ULONG hWnd,ULONG msg,ULONG wParam,LONG lParam),LONG,PASCAL,PROC,NAME('PostMessageA')
    END
#ENDAT
#!
#AT(%ProgramProcedures),WHERE(%bgGDisable=0)
!  ---- scrollbars ---------------------------------------------------------
!  A REGION is not born with scrollbars, so the styles go on at run time and
!  the control is subclassed for the two scroll messages. The address of the
!  callback is taken HERE, in the module that defines it - taken in a member
!  module it is an import thunk, not the procedure.
BG_HookBars PROCEDURE(LONG pHwnd,LONG pStyle)
prop CSTRING('BrowseGridBarProc')
old  LONG,AUTO
sty  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  IF bgApi_GetProp(pHwnd,ADDRESS(prop)) THEN RETURN 0.
!  Only the horizontal bar is Windows'. The vertical one is drawn by the grid,
!  because Windows' cannot be made to follow the data: it drags inside a
!  message loop of its own, and moving the browse needs records, which needs
!  ACCEPT, which that loop is holding up. Sideways needed nothing from the
!  browse so it could be done inside the loop; downwards cannot be.
!  The subclass goes on whatever the style, because the roller comes through it
!  too. The SCROLLBAR only goes on for the Windows style - the other two draw
!  their own, and a Windows bar underneath would take width for nothing.
  IF pStyle = 0
    sty = bgApi_GetWindowLong(pHwnd,BG:GwlStyle)
    bgApi_SetWindowLong(pHwnd,BG:GwlStyle,BOR(sty,BG:HScrollStyle))
  END
  bgApi_SetWindowPos(pHwnd,0,0,0,0,0,BOR(BOR(BOR(BG:FrameChanged,BG:NoMove),BG:NoSize),BG:NoZOrder))
  old = bgApi_SetWindowLong(pHwnd,BG:GwlWndProc,ADDRESS(BG_BarProc))
  IF ~old THEN RETURN 0.
  bgApi_SetProp(pHwnd,ADDRESS(prop),old)
  RETURN 1

BG_DropBars PROCEDURE(LONG pHwnd)
prop CSTRING('BrowseGridBarProc')
old  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  old = bgApi_GetProp(pHwnd,ADDRESS(prop))
  IF old
    bgApi_SetWindowLong(pHwnd,BG:GwlWndProc,old)
  END
  bgApi_RemoveProp(pHwnd,ADDRESS(prop))
  RETURN old

BG_SetBar PROCEDURE(LONG pHwnd,LONG pBar,LONG pPos,LONG pPage,LONG pTotal)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  IF ~pHwnd THEN RETURN.
  si.cbSize = SIZE(si)
  si.fMask  = BOR(BOR(BG:SifRange,BG:SifPage),BG:SifPos)
  si.nMin   = 0
  si.nMax   = pTotal - 1
  si.nPage  = pPage
  si.nPos   = pPos
  bgApi_SetScrollInfo(pHwnd,pBar,ADDRESS(si),1)

BG_BarPos PROCEDURE(LONG pHwnd,LONG pBar)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  IF ~pHwnd THEN RETURN 0.
  si.cbSize = SIZE(si)
  si.fMask  = BG:SifPos
  IF ~bgApi_GetScrollInfo(pHwnd,pBar,ADDRESS(si)) THEN RETURN 0.
  RETURN si.nPos

!  Windows does not work out the new position for a scroll message; this does,
!  writes it back, leaves what happened in the globals and tells the ACCEPT
!  loop. Horizontal scrolling is the grid's own business - it just slides the
!  columns. Vertical is the BROWSE's, so it is passed on rather than acted on.
BG_BarProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
prop CSTRING('BrowseGridBarProc')
old  LONG,AUTO
g    LONG,AUTO
dz   LONG,AUTO
bar  LONG,AUTO
code LONG,AUTO
pos  LONG,AUTO
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  old = bgApi_GetProp(hWnd,ADDRESS(prop))
!  The roller. Windows sends this to whatever is under the pointer, which is
!  the region - the LIST underneath is invisible and cannot be hit. There is no
!  modal loop involved here, so unlike a thumb drag it is enough to post: the
!  ACCEPT loop runs between notches and the browse fetches its records as it
!  always would.
  IF wMsg = BG:WmMouseWheel
    dz = BSHIFT(BAND(wParam,0FFFF0000h),-16)
    IF dz > 32767 THEN dz -= 65536.                           ! it is a SIGNED short up there
    IF dz
      IF BAND(wParam,BG:MkControl)
!  Ctrl and the roller: bigger and smaller type, the way every other program
!  does it. The rows grow with the font, so the browse is told to reload - it
!  fits a different number of records now.
        g = d2g_FromHwnd(hWnd)
        IF g
          d2g_FontSize(g,d2g_FontPt(g) + CHOOSE(dz > 0, 1, -1))
          d2g_PaintNow(g)
          BG:LastBar  = BG:SbVert
          BG:LastCode = BG:FontCode
          BG:LastPos  = 0
          POST(BG:Scrolled)
        END
      ELSE
        BG:LastBar  = BG:SbVert
        BG:LastCode = BG:WheelCode
        BG:LastPos  = dz
        POST(BG:Scrolled)
      END
    END
  END
  IF wMsg = BG:WmHScroll OR wMsg = BG:WmVScroll
    bar = CHOOSE(wMsg = BG:WmHScroll, BG:SbHorz, BG:SbVert)
    code = BAND(wParam,0FFFFh)
    si.cbSize = SIZE(si)
    si.fMask  = BOR(BOR(BOR(BG:SifRange,BG:SifPage),BG:SifPos),BG:SifTrack)
    IF bgApi_GetScrollInfo(hWnd,bar,ADDRESS(si))
      pos = si.nPos
      CASE code
      OF 0
        pos -= INT(si.nPage / 8) + 1
      OF 1
        pos += INT(si.nPage / 8) + 1
      OF 2
        pos -= si.nPage
      OF 3
        pos += si.nPage
      OF 4
        pos = si.nTrack
      OF 5
        pos = si.nTrack
      OF 6
        pos = si.nMin
      OF 7
        pos = si.nMax
      END
      IF pos > si.nMax - si.nPage + 1 THEN pos = si.nMax - si.nPage + 1.
      IF pos < si.nMin THEN pos = si.nMin.
      IF bar = BG:SbHorz                                      ! ours: just move the columns
        si.fMask = BG:SifPos
        si.nPos  = pos
        bgApi_SetScrollInfo(hWnd,bar,ADDRESS(si),1)
!  AND MOVE THEM NOW, not on the next ACCEPT. Dragging a scrollbar thumb puts
!  Windows into a message loop of its OWN, and Clarion's ACCEPT does not get a
!  turn until the button comes back up - so anything POSTed from here just
!  queues, and the columns would not budge until you let go. Scrolling
!  sideways needs nothing from the browse though: it is the grid's own pixels.
!  So it is done right here, synchronously, and painted immediately rather than
!  invalidated - an invalidated window would not be repainted until the loop
!  ends either. Downwards is not like this: that one needs records, which only
!  the browse can fetch, so it still waits for the button.
        g = d2g_FromHwnd(hWnd)
        IF g
          d2g_ScrollX(g,pos)
          d2g_PaintNow(g)
        END
      END
      BG:LastBar  = bar
      BG:LastCode = code
      BG:LastPos  = pos
      POST(BG:Scrolled)
    END
  END
  IF old
    RETURN bgApi_CallWndProc(old,hWnd,wMsg,wParam,lParam)
  END
  RETURN 0

!  A Clarion COLOR is a BGR long; Direct2D wants 0xRRGGBB. One place, once.
BG_Rgb PROCEDURE(LONG pColor)
c LONG,AUTO
  CODE
  c = pColor
  IF c < 0 THEN c = 0FFFFFFh.                                 ! a system colour: use white
  RETURN BOR(BOR(BSHIFT(BAND(c,00000FFh),16),BAND(c,000FF00h)),                |
             BSHIFT(BAND(c,0FF0000h),-16))
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - BrowseGrid
#!#############################################################################
#EXTENSION(BrowseGrid,'BrowseGrid - draw this browse with Direct2D'),PROCEDURE,MULTI,REQ(BrowseGridGlobal),DESCRIPTION('Grid on ' & %bgList),HLP('~BrowseGrid.htm')
#SHEET
  #TAB('&Browse')
    #BOXED('Which browse')
      #PROMPT('&Disable this grid',CHECK),%bgDisable,DEFAULT(0),AT(10)
      #PROMPT('Show grid &diagnostics in the window title',CHECK),%bgDiag,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%bgObject,REQ,DEFAULT('Grid' & %ActiveTemplateInstance)
      #PROMPT('&LIST control to take over:',CONTROL),%bgList,REQ
      #PROMPT('Browse &queue:',@s64),%bgQueue,REQ,DEFAULT('Queue:Browse:1')
      #DISPLAY('The queue the LIST is FROM(). ABC calls the first one')
      #DISPLAY('Queue:Browse, the second Queue:Browse:2, and so on - look in')
      #DISPLAY('the generated source if you are not sure.')
    #ENDBOXED
    #BOXED('Columns')
      #DISPLAY('Taken from the LIST itself at run time: widths, headings,')
      #DISPLAY('pictures and alignment come over as they are, including any')
      #DISPLAY('the user has resized or reordered.')
      #PROMPT('&Frozen columns (stay put when scrolled sideways):',SPIN(@n2,0,8,1)),%bgFrozen,DEFAULT(0)
      #PROMPT('&Scrollbars on the grid',CHECK),%bgBars,DEFAULT(1),AT(10)
      #ENABLE(%bgBars)
        #PROMPT('  &Style:',DROP('Windows|Slim|Overlay')),%bgBarStyle,DEFAULT('Windows')
      #ENDENABLE
      #DISPLAY('Windows - the sideways bar is Windows<39> own, the downward one drawn.')
      #DISPLAY('Slim    - both drawn, thin and flat, in the grid<39>s own colours.')
      #DISPLAY('Overlay - both drawn over the rows and only while the pointer is on')
      #DISPLAY('          the grid, so the data keeps the whole width.')
      #PROMPT('Let the user &resize columns by dragging',CHECK),%bgSizeable,DEFAULT(1),AT(10)
      #PROMPT('Hand a right-click back to the &browse popup',CHECK),%bgPopup,DEFAULT(1),AT(10)
      #PROMPT('Scroll with the mouse &wheel',CHECK),%bgWheel,DEFAULT(1),AT(10)
      #PROMPT('&Sort when a heading is clicked',CHECK),%bgSortHdr,DEFAULT(1),AT(10)
      #PROMPT('&Columns... on the heading menu (show and hide columns)',CHECK),%bgChooser,DEFAULT(1),AT(10)
      #PROMPT('&Remember this grid<39>s layout between runs',CHECK),%bgRemember,DEFAULT(1),AT(10)
      #DISPLAY('Column widths and filters, through the application<39>s own INIMgr, under a')
      #DISPLAY('section named for this procedure and this grid. Nothing else stores it.')
      #PROMPT('&Excel-style drop-down button on every heading',CHECK),%bgFilterBtn,DEFAULT(0),AT(10)
      #ENABLE(%bgFilterBtn)
        #PROMPT('  &Browse object to filter through:',@s64),%bgBrowseObj,DEFAULT('BRW1')
      #ENDENABLE
      #DISPLAY('Sorting goes through the browse the same way a heading click does.')
      #DISPLAY('Filtering calls the browse object<39>s own SetFilter, so range limits and')
      #DISPLAY('locators keep working - which means the object has to be named here.')
      #DISPLAY('The field name is read at run time with WHO(), because an ABC browse')
      #DISPLAY('queue labels its fields with the file fields they came from.')
      #PROMPT('&Flatten a grouped or multi-line format',CHECK),%bgFlatten,DEFAULT(1),AT(10)
      #DISPLAY('A grouped browse puts several fields on each record, over more than one')
      #DISPLAY('line, under headings that span them. Flattened, every field becomes a')
      #DISPLAY('column of its own on a single line - so resizing, sorting and freezing')
      #DISPLAY('work per field, and the grid scrolls sideways instead of growing taller.')
      #DISPLAY('Untick it and the record is drawn the way the formatter lays it out:')
      #DISPLAY('the groups<39> headings span their fields and each record is as many lines')
      #DISPLAY('tall as the format makes it. Columns cannot be resized by dragging in')
      #DISPLAY('that mode - the fields inside the group would have to move as well.')
      #DISPLAY('Passes the click to the browse, so it sorts by whatever rule the browse')
      #DISPLAY('was already given. A browse with no sort headers will simply ignore it.')
      #PROMPT('F&ile the browse reads (sizes the scrollbar thumb):',@s64),%bgFile,DEFAULT(%Primary)
      #DISPLAY('RECORDS() reads the count from the file header, so the thumb can be')
      #DISPLAY('sized honestly: a page against the whole file. Leave it blank and the')
      #DISPLAY('thumb is a fixed size. A filtered or range-limited browse will read')
      #DISPLAY('high, because the count is the file<39>s, not the view<39>s. This is a')
      #DISPLAY('plain label, not a file prompt - naming it here must not change what')
      #DISPLAY('the procedure is considered to use.')
      #DISPLAY('Sideways is the grid<39>s own. Downwards is passed to the browse,')
      #DISPLAY('so paging, locators and range limits behave as they always did.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Type')
      #PROMPT('&Font:',@s32),%bgFont,DEFAULT('Segoe UI')
      #PROMPT('&Size (points):',SPIN(@n3,6,24,1)),%bgSize,DEFAULT(9)
      #PROMPT('&Wrap text that is too long for its column',CHECK),%bgWrap,DEFAULT(0),AT(10)
      #ENABLE(%bgWrap)
        #PROMPT('  &Lines a cell may use:',SPIN(@n1,2,4,1)),%bgWrapLines,DEFAULT(2)
      #ENDENABLE
      #DISPLAY('Every row is that many lines tall, whether its text needs them or not.')
      #DISPLAY('Rows of differing heights would take the page size, the hit testing and')
      #DISPLAY('the scrolling with them, and none of those want to know that one')
      #DISPLAY('particular address happened to be long.')
      #PROMPT('&Row height (pixels, 0 = follow the browse):',SPIN(@n3,0,80,1)),%bgRowH,DEFAULT(0)
      #DISPLAY('Left at 0 the grid draws to the LIST<39>s own line height, so the browse')
      #DISPLAY('loads exactly as many records as there is room to draw. Set it and the')
      #DISPLAY('LIST is given the same height, so the two still agree.')
      #PROMPT('&Header height (pixels, 0 = from the font):',SPIN(@n3,0,80,1)),%bgHdrH,DEFAULT(0)
    #ENDBOXED
    #BOXED('Colours')
      #PROMPT('&Background:',COLOR),%bgCBack,DEFAULT(00FFFFFFH)
      #PROMPT('&Banding (every other row):',COLOR),%bgCBand,DEFAULT(00FAF7F5H)
      #PROMPT('&Gridlines:',COLOR),%bgCGrid,DEFAULT(00EAE5E1H)
      #PROMPT('&Text:',COLOR),%bgCText,DEFAULT(0033291FH)
      #PROMPT('Header b&ackground:',COLOR),%bgCHdrBack,DEFAULT(004A3A2BH)
      #PROMPT('Header te&xt:',COLOR),%bgCHdrText,DEFAULT(00FFFFFFH)
      #PROMPT('&Selected row:',COLOR),%bgCSelBack,DEFAULT(00B56F2FH)
      #PROMPT('Selected te&xt:',COLOR),%bgCSelText,DEFAULT(00FFFFFFH)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%bgDisable=0 AND %bgList)
BG:Resized:%bgObject EQUATE(EVENT:User + 240 + %ActiveTemplateInstance)
BG:Popup:%bgObject   EQUATE(EVENT:User + 200 + %ActiveTemplateInstance)
BG:Cover:%bgObject   EQUATE(EVENT:User + 160 + %ActiveTemplateInstance)
BG:Refill:%bgObject  EQUATE(EVENT:User + 120 + %ActiveTemplateInstance)
%bgObject:G          LONG                                    ! the grid, 0 = not running
%bgObject:Rgn        SIGNED                                  ! the region it is drawn on
%bgObject:Cols       LONG                                    ! how many columns came over
%bgObject:Fld        LONG,DIM(32)                            ! queue field behind each column
%bgObject:Pic        STRING(32),DIM(32)                       ! and its picture, if it has one
%bgObject:Face       CSTRING(33)
%bgObject:Cell       CSTRING(65)
%bgObject:Sel        LONG
%bgObject:Clipped    BYTE                                    ! has the LIST been made invisible?
%bgObject:Barred     BYTE                                    ! does it have scrollbars yet?
%bgObject:ScrollX    LONG                                    ! how far sideways the columns are
%bgObject:Col        LONG,DIM(32)                            ! LIST column behind each grid one
%bgObject:RzCol      LONG                                    ! column being dragged, 0 = none
%bgObject:RzX        LONG                                    ! where the drag started
%bgObject:RzW        LONG                                    ! and how wide the column was then
%bgObject:RzCur      BYTE                                    ! is the sizing cursor showing?
%bgObject:VDrag      BYTE                                    ! is the thumb being dragged?
%bgObject:VGrab      LONG                                    ! and where it was taken hold of
%bgObject:HDrag      BYTE                                    ! the sideways thumb, being dragged
%bgObject:HGrab      LONG
%bgObject:SortCol    LONG                                    ! heading just clicked, for BG:Sort
%bgObject:RzGrp      BYTE                                    ! is a GROUP being dragged, not a column?
%bgObject:GrpCol     LONG,DIM(32)                            ! a LIST column in each group
%bgObject:Filters    LONG                                    ! how many columns are filtered
%bgObject:Hidden     LONG                                    ! LIST columns sitting at zero width
%bgObject:ColFilt    CSTRING(161),DIM(32)                    ! one filter per column, ANDed together
%bgObject:Fills      LONG                                    ! how many times it has been refilled
%bgObject:SortOn     LONG                                    ! LIST column the mark is on, 0 none
%bgObject:SortDir    LONG                                    ! 1 up, -1 down
%bgObject:RzArmed    BYTE                                    ! on an edge, but has it MOVED yet?
%bgObject:RzHide     BYTE                                    ! dragged past nothing: hide it
%bgObject:Lines      LONG                                    ! lines per record in the LIST's format
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(8800),WHERE(%bgDisable=0 AND %bgList)
  IF ReturnValue = Level:Benign
    DO BG:Setup:%bgObject
  END
#ENDAT
#!
#!  WHERE THE REFILL HANGS OFF. Not TakeEvent: that method returns the moment
#!  PARENT.TakeEvent() comes back, so code embedded after it is unreachable -
#!  it generates, it compiles, and it never runs. ABC calls Reset when the
#!  browse has refilled itself, and TakeNewSelection when the highlight moves,
#!  which between them cover scrolling, locating, filtering and editing.
#AT(%WindowManagerMethodCodeSection,'Reset','(BYTE Force=0)'),PRIORITY(8000),WHERE(%bgDisable=0 AND %bgList)
  IF %bgObject:G
    DO BG:Fill:%bgObject
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeNewSelection','(),BYTE'),PRIORITY(8000),WHERE(%bgDisable=0 AND %bgList)
  IF %bgObject:G
    DO BG:Fill:%bgObject
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
  CASE EVENT()
  OF EVENT:OpenWindow
!  The window is up and everything has been given its real place, which is the
!  first moment the LIST can be measured for where it truly is.
    POST(BG:Resized:%bgObject)
  OF EVENT:Sized
!  Do NOT move the region here. The window resizer is working on this same
!  event, and on this window it runs after us - so the LIST has not been given
!  its new size yet, and anything measured from it now is the old one. Posting
!  puts the move at the back of the queue, by which time the resizer has
!  finished and the LIST is the size it is going to be.
    POST(BG:Resized:%bgObject)
#IF(%bgBars OR %bgWheel)
  OF BG:Scrolled
    IF %bgObject:G AND %bgObject:Barred
      DO BG:Scroll:%bgObject
    END
#ENDIF
#IF(%bgPopup)
  OF BG:Popup:%bgObject
!  By now the SELECT has taken effect and the LIST really has the focus, so the
!  keystroke reaches it. Done in the same breath as the SELECT it would still
!  be sitting on the region.
!
!  Taking the focus is also what makes the LIST draw its own selected row, and
!  it draws it straight through the grid - at its own line height and its own
!  column widths, which is what makes it look like the row appears twice. So
!  the grid is put back over it BEFORE the menu opens, and again afterwards in
!  case the LIST repaints while the menu is up. PaintNow, not Repaint: an
!  invalidated window would not be redrawn until the menu closed.
    DO BG:Cover:%bgObject
    PRESSKEY(AppsKey)
    POST(BG:Cover:%bgObject)
  OF BG:Cover:%bgObject
    DO BG:Cover:%bgObject
#ENDIF
  OF BG:Refill:%bgObject
!  Posted LAST, so it is handled after everything the browse posted for itself.
!  Refilling the grid depends on ABC calling Reset or TakeNewSelection once it
!  has re-read, and after a filter that is not something to rely on - if
!  neither fires, or fires before the queue is rebuilt, the grid keeps showing
!  what it had. This does not care which: by the time it runs, the queue is
!  whatever the browse ended up with.
    IF %bgObject:G
      DO BG:Fill:%bgObject
      d2g_PaintNow(%bgObject:G)
    END
  OF BG:Resized:%bgObject
    IF %bgObject:G
      DO BG:Place:%bgObject                                   ! follow the LIST to its new size
      d2g_Resize(%bgObject:G)                                 ! and the render target with it
      DO BG:Items:%bgObject                                   ! and the browse loads to suit
      DO BG:Fill:%bgObject                                    ! a taller browse holds more rows
    END
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
  IF FIELD() = %bgObject:Rgn AND %bgObject:G
    CASE EVENT()
    OF EVENT:MouseDown
      DO BG:Hit:%bgObject
#IF(%bgPopup)
    OF EVENT:AlertKey
      IF KEYCODE() = MouseRightUp
        DO BG:Right:%bgObject
      END
#ENDIF
#IF(%bgBarStyle = 'Overlay')
    OF EVENT:MouseIn
      d2g_BarsShow(%bgObject:G,1)
    OF EVENT:MouseOut
      d2g_BarsShow(%bgObject:G,0)
#ENDIF
#IF(%bgSizeable)
    OF EVENT:MouseMove
      DO BG:Sizing:%bgObject
    OF EVENT:MouseUp
      DO BG:SizeEnd:%bgObject
#ENDIF
    END
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
#IF(%bgRemember)
  DO BG:Remember:%bgObject                                    ! before anything is taken down
#ENDIF
  DO BG:Reveal:%bgObject
  IF %bgObject:Barred
    BG_DropBars(%bgObject:Rgn{PROP:Handle})
    %bgObject:Barred = 0
  END
  IF %bgObject:G
    d2g_Detach(%bgObject:G)
    %bgObject:G = 0
  END
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%bgDisable=0 AND %bgList)
BG:Setup:%bgObject ROUTINE
!  Put a region exactly where the LIST is, hide the LIST, and hand the region
!  to the grid. The LIST stays in the window doing its job - it is simply not
!  the thing you look at any more, which is why the browse carries on working.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
  CODE
  IF ~d2g_Available() THEN EXIT.                              ! no Direct2D: leave the LIST alone
  IF ~%bgObject:Rgn
    %bgObject:Rgn = CREATE(0,CREATE:Region,%bgList{PROP:Parent})
    %bgObject:Rgn{PROP:IMM} = 1                               ! or no mouse events arrive
  END
  DO BG:Place:%bgObject
  UNHIDE(%bgObject:Rgn)
  %bgObject:Face = '%bgFont'
  %bgObject:G = d2g_Attach(%bgObject:Rgn{PROP:Handle},%bgObject:Face,%bgSize)
  IF ~%bgObject:G
    HIDE(%bgObject:Rgn)                                       ! could not start: leave the LIST alone
    EXIT
  END
#IF(%bgRemember)
  DO BG:Recall:%bgObject                                      ! widths, before they are read
#ENDIF
  DO BG:Columns:%bgObject
#IF(%bgRemember)
  DO BG:RecallF:%bgObject                                     ! and filters, once columns are known
#ENDIF
  DO BG:Conceal:%bgObject                                     ! only now the grid can be seen
!  The LIST is neither hidden nor moved: it stays exactly where it is, filling
!  its queue, counting its visible rows and holding the selection, and the
!  region sits on top of it. WS_CLIPSIBLINGS is what makes that stick - without
!  it the LIST paints over the grid whenever it redraws.
#IF(%bgWrap)
!  Before BG:Rows, which asks the engine how tall a row has to be - and with
!  wrapping on, that answer is several lines.
  d2g_Wrap(%bgObject:G,1,%bgWrapLines)
#ENDIF
  DO BG:Rows:%bgObject
  DO BG:Items:%bgObject                                       ! load what there is room to draw
#IF(%bgHdrH > 0)
  d2g_HeaderHeight(%bgObject:G,%bgHdrH)
#ENDIF
#IF(%bgBars OR %bgWheel)
#IF(%bgBarStyle = 'Windows')
  IF BG_HookBars(%bgObject:Rgn{PROP:Handle},0)                ! the roller comes through here too
#ELSE
  IF BG_HookBars(%bgObject:Rgn{PROP:Handle},1)                ! drawn bars: hooked only for the roller
#ENDIF
    %bgObject:Barred = 1
  END
#ENDIF
#IF(%bgPopup)
!  The region is on top, so it - not the LIST - is what a right-click lands on.
!  Alerting it here is what lets that click be handed back to the browse.
  %bgObject:Rgn{PROP:Alrt,250} = MouseRightUp
#ENDIF
#IF(%bgBarStyle = 'Slim')
  d2g_BarStyle(%bgObject:G,1)
#ELSIF(%bgBarStyle = 'Overlay')
  d2g_BarStyle(%bgObject:G,2)
#ELSE
  d2g_BarStyle(%bgObject:G,0)
#ENDIF
#IF(%bgFilterBtn)
  d2g_FilterBtns(%bgObject:G,1)
  d2g_FilterOn(%bgObject:G,-1,0)                              ! nothing is filtered to begin with
#ENDIF
  d2g_Frozen(%bgObject:G,%bgFrozen)
  d2g_Colours(%bgObject:G,BG_Rgb(%bgCBack),BG_Rgb(%bgCBand),                  |
              BG_Rgb(%bgCGrid),BG_Rgb(%bgCText),                               |
              BG_Rgb(%bgCHdrBack),BG_Rgb(%bgCHdrText),                         |
              BG_Rgb(%bgCSelBack),BG_Rgb(%bgCSelText))
  DO BG:Fill:%bgObject
!  ...and then place it again once the window has finished opening. At Init the
!  LIST is still where the DESIGNER put it: the window resizer has not run, and
!  on a window that opens maximised or restores to a remembered size it is about
!  to move. Placing the region now and leaving it there is what put the grid
!  over the buttons until the window was resized by hand. Posting means the
!  second placement happens after everything else has settled.
  POST(BG:Resized:%bgObject)

BG:Place:%bgObject ROUTINE
!  Sit the region exactly on the LIST and keep it on top. The LIST is not moved
!  and not hidden: it is left where the resizer wants it, doing everything it
!  did before, and WS_CLIPSIBLINGS stops it painting into the region's
!  rectangle. Moving it instead fought the resizer, which works out every
!  control's place from the design layout and put it back over the grid.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
sty LONG,AUTO
  CODE
  IF ~%bgObject:Rgn THEN EXIT.
  GETPOSITION(%bgList,x,y,w,h)
  SETPOSITION(%bgObject:Rgn,x,y,w,h)
  IF %bgObject:G
    DO BG:Conceal:%bgObject                                   ! a resize can bring it back
  END
!  and raise the region above it, every time, because a resize can restack them
  bgApi_SetWindowPos(%bgObject:Rgn{PROP:Handle},BG:HwndTop,0,0,0,0,             |
                     BOR(BG:NoMove,BG:NoSize))

BG:Columns:%bgObject ROUTINE
!  Read the columns off the LIST as they stand. Every PROPLIST read goes
!  through a LONG first: a property comes back as a STRING, and the STRING '0'
!  is logically TRUE, so a hidden column would otherwise look visible.
  DATA
c     LONG,AUTO
n     LONG,AUTO
ex    LONG,AUTO
fld   LONG,AUTO
wid   LONG,AUTO
algn  LONG,AUTO
p     LONG,AUTO
grp     LONG,AUTO
lines   LONG,AUTO
glines  LONG,AUTO
lastgrp LONG,AUTO
pass    LONG,AUTO
head  CSTRING(65)
ghead CSTRING(65)
  CODE
!  Two passes, not two calls. A ROUTINE that does DO on itself is not a
!  recursive call in Clarion - a routine holds one return address, so calling it
!  from inside itself loses the way back and takes the program down with it.
!  That is what the rescue below did on the first window it was needed on.
  LOOP pass = 1 TO 2
  n = 0
  lines = 1
  glines = 1
  lastgrp = -1
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.                                       ! a decoration, not a data column
    wid = %bgList{PROPLIST:Width,c}
    IF wid < 1 THEN CYCLE.                                    ! hidden
    IF n >= 32 THEN BREAK.
    algn = 0
    p = %bgList{PROPLIST:Right,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Decimal,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Center,c}
    IF p THEN algn = 2.
!  A column inside a GROUP usually carries no heading of its own - the group's
!  heading stands over the whole set of them. Adding PROPLIST:Group to any of
!  these properties reads the GROUP's version of it, which is where the words
!  in the formatter's top row actually live. Flattened, each field becomes a
!  column of its own, so it needs a heading of its own: its own if it has one,
!  the group's if it has not.
    head = CLIP(%bgList{PROPLIST:Header,c})
    grp  = %bgList{PROPLIST:GroupNo,c}
    IF grp
      ghead = CLIP(%bgList{PROPLIST:Header + PROPLIST:Group,c})
      IF ~head
        head = ghead
      ELSIF ghead AND UPPER(ghead) <> UPPER(head)
        head = CLIP(ghead) & ' ' & CLIP(head)                 ! "Address City", not just "City"
      END
!  LastOnLine is where the format wraps onto the next line of the record. A
!  record is as tall as its TALLEST group, not as the sum of every break in
!  every group - counting them all made a three-line record report five, so the
!  LIST was given a line height a third too small and the rows came out stretched
!  with the text floating in the middle of them.
      IF grp <> lastgrp
        lastgrp = grp
        glines  = 1                                           ! a new group starts on line one
      END
      IF %bgList{PROPLIST:LastOnLine,c}
        glines += 1
        IF glines > lines THEN lines = glines.
      END
    END
    LOOP p = 1 TO LEN(head)                                   ! a bar wraps a heading on screen
      IF head[p] = '|' THEN head[p] = ' '.
    END
    head = CLIP(LEFT(head))
    %bgObject:Fld[n + 1] = fld
    %bgObject:Col[n + 1] = c                                  ! so a resize can be written back
    %bgObject:Pic[n + 1] = CLIP(%bgList{PROPLIST:Picture,c})
    d2g_Column(%bgObject:G,n,wid * 2,algn,head)               ! LIST widths are dialog units
    n += 1
  END
!  NOTHING VISIBLE. Every column came back zero-width, which means something hid
!  them all - the column chooser could, until it learned not to. An empty grid is
!  unusable and, worse, leaves nothing to click on to undo it, so the widths are
!  put back from what they were before they went and the loop goes round once
!  more. A grid can always be got back to.
  IF ~n AND pass = 1
    LOOP c = 1 TO 512
      ex = %bgList{PROPLIST:Exists,c}
      IF ~ex THEN BREAK.
      fld = %bgList{PROPLIST:FieldNo,c}
      IF ~fld THEN CYCLE.
      head = CLIP(INIMgr.Fetch('BrowseGrid:%Procedure:%bgObject','h' & c))
      %bgList{PROPLIST:Width,c} = CHOOSE(head <> '' AND head <> '0', head, 40)
      INIMgr.Update('BrowseGrid:%Procedure:%bgObject','w' & c,'')
    END
    CYCLE                                                     ! read them again, once
  END
  BREAK
  END
  %bgObject:Cols = n
  %bgObject:Hidden = 0
  LOOP c = 1 TO 512                                           ! for the diagnostics line
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    IF %bgList{PROPLIST:Width,c} < 1 THEN %bgObject:Hidden += 1.
  END
  %bgObject:Lines = lines                                     ! 1 = an ordinary flat browse
  d2g_Columns(%bgObject:G,n)
#IF(%bgFlatten = 0)
  IF lines > 1
    DO BG:Groups:%bgObject                                    ! place them where the format does
  END
#ENDIF

BG:Groups:%bgObject ROUTINE
!  Lay the record out the way the List Box Formatter does: fields sit inside
!  groups, several to a line, and the group's heading spans the lot. Three
!  things say how:
!
!    PROPLIST:GroupNo     which group a column is in
!    PROPLIST:LastOnLine  where the record wraps onto its next line
!    PROPLIST:Group       ADDED to any other property, reads the GROUP's one -
!                         which is where the heading and the overall width live
!
!  A column with no group is a group of its own, one field on one line, which
!  is how an ordinary browse falls out of the same code.
#IF(%bgFlatten = 0)
  DATA
c    LONG,AUTO
n    LONG,AUTO
g    LONG,AUTO
ex   LONG,AUTO
fld  LONG,AUTO
wid  LONG,AUTO
algn LONG,AUTO
p    LONG,AUTO
grp  LONG,AUTO
prev LONG,AUTO
gx   LONG,AUTO
gw   LONG,AUTO
ln   LONG,AUTO
xo   LONG,AUTO
mx   LONG,AUTO
head CSTRING(65)
  CODE
  n    = 0
  g    = -1
  prev = -9999
  gx   = 0
  mx   = 1
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    wid = %bgList{PROPLIST:Width,c}
    IF wid < 1 THEN CYCLE.
    IF n >= 32 THEN BREAK.
    grp = %bgList{PROPLIST:GroupNo,c}
    IF grp <> prev OR ~grp                                    ! a new group starts here
      IF g >= 0 THEN gx += gw.
      g += 1
      prev = grp
      ln = 0
      xo = 0
      IF grp
        gw   = %bgList{PROPLIST:Width + PROPLIST:Group,c} * 2
        head = CLIP(%bgList{PROPLIST:Header + PROPLIST:Group,c})
      ELSE
        gw   = wid * 2                                        ! ungrouped: a group of one
        head = CLIP(%bgList{PROPLIST:Header,c})
      END
      LOOP p = 1 TO LEN(head)
        IF head[p] = '|' THEN head[p] = ' '.
      END
      head = CLIP(LEFT(head))
      d2g_Group(%bgObject:G,g,gx,gw,head)
      %bgObject:GrpCol[g + 1] = c                             ! for writing a resize back
    END
    algn = 0
    p = %bgList{PROPLIST:Right,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Decimal,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Center,c}
    IF p THEN algn = 2.
!  Its own heading, which in a grouped format is where most of the words are.
    head = CLIP(%bgList{PROPLIST:Header,c})
    LOOP p = 1 TO LEN(head)
      IF head[p] = '|' THEN head[p] = ' '.
    END
    head = CLIP(LEFT(head))
    d2g_ColumnAt(%bgObject:G,n,g,ln,gx + xo,wid * 2,algn,head)
    xo += wid * 2
    IF grp AND %bgList{PROPLIST:LastOnLine,c}                 ! the record wraps here
      ln += 1
      xo = 0
      IF ln + 1 > mx THEN mx = ln + 1.
    END
    n += 1
  END
  IF g >= 0
    d2g_Groups(%bgObject:G,g + 1)
    d2g_Lines(%bgObject:G,mx)
  END
#ELSE
  EXIT
#ENDIF

BG:Hit:%bgObject ROUTINE
!  A click picks a row. The browse still owns the selection: it is told which
!  record was chosen and left to do the rest, so locators, range limits and
!  anything hanging off EVENT:NewSelection behave exactly as they always did.
!  MOUSEY answers in WINDOW units and the grid measures in pixels, hence the
!  switch - a window unit is half a pixel.
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
sp LONG,AUTO
mx LONG,AUTO
my LONG,AUTO
col LONG,AUTO
row LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  mx = MOUSEX() - rx
  my = MOUSEY() - ry
  row = d2g_HitRow(%bgObject:G,my)
  0{PROP:Pixels} = sp
!  The scrollbar first: it is drawn over everything else, so it is clicked
!  before everything else.
#IF(%bgBarStyle <> 'Windows')
  CASE d2g_HitHBar(%bgObject:G,mx,my)                         ! the drawn sideways bar
  OF 4
    %bgObject:HDrag = 1
    %bgObject:HGrab = d2g_HGrab(%bgObject:G,mx)
    EXIT
  OF 5
    %bgObject:ScrollX = %bgObject:ScrollX - d2g_ViewWidth(%bgObject:G)
    IF %bgObject:ScrollX < 0 THEN %bgObject:ScrollX = 0.
    d2g_ScrollX(%bgObject:G,%bgObject:ScrollX)
    DO BG:Bars:%bgObject
    d2g_PaintNow(%bgObject:G)
    EXIT
  OF 6
    %bgObject:ScrollX = %bgObject:ScrollX + d2g_ViewWidth(%bgObject:G)
    d2g_ScrollX(%bgObject:G,%bgObject:ScrollX)
    DO BG:Bars:%bgObject
    d2g_PaintNow(%bgObject:G)
    EXIT
  END
#ENDIF
  CASE d2g_VHit(%bgObject:G,mx,my)
  OF 1
    %bgObject:VDrag = 1
    %bgObject:VGrab = d2g_VGrab(%bgObject:G,my)               ! anchored, so it cannot jump
    EXIT
  OF 2
    POST(EVENT:PageUp,%bgList)
    EXIT
  OF 3
    POST(EVENT:PageDown,%bgList)
    EXIT
  END
!  A heading. On the edge of a column that is a resize; anywhere else it is a
!  request to sort by that column. Either way it never changes the selection.
  IF my < d2g_HdrHeight(%bgObject:G)
#IF(%bgFilterBtn)
!  The drop-down box is drawn over the right of the heading, so it is what a
!  click there means - before the resize edge, which is in the same few pixels.
    col = d2g_HitBtn(%bgObject:G,mx,my)
    IF col >= 0
      %bgObject:SortCol = col
      DO BG:Menu:%bgObject
      EXIT
    END
#ENDIF
#IF(%bgSortHdr)
    %bgObject:SortCol = d2g_HitCol(%bgObject:G,mx)            ! remember it either way
#ENDIF
#IF(%bgSizeable)
!  In a grouped format the draggable edges belong to the GROUPS - one heading
!  stands over several fields, and there is nothing sensible to grab between
!  two of them that sit on different lines.
    IF %bgObject:Lines > 1
      col = d2g_HitGrpEdge(%bgObject:G,mx)
      IF col >= 0
        %bgObject:RzGrp   = 1
        %bgObject:RzCol   = col + 1
        %bgObject:RzX     = mx
        %bgObject:RzW     = d2g_GrpWidth(%bgObject:G,col)
        %bgObject:RzArmed = 1
        EXIT
      END
    END
    col = d2g_HitEdge(%bgObject:G,mx)
    IF col >= 0
!  Near an edge - but a click and a drag both start here, and until the mouse
!  MOVES there is no telling which this is. So the resize is only armed. Commit
!  it on the first click and a narrow column can never be sorted at all: the
!  grab margin reaches four pixels either side of every boundary, so a narrow
!  heading is almost entirely edge, and every click on it was being swallowed
!  by a resize that then went nowhere.
      %bgObject:RzGrp   = 0
      %bgObject:RzCol   = col + 1                             ! 1-based: 0 means nothing is being dragged
      %bgObject:RzX     = mx
      %bgObject:RzW     = d2g_ColWidth(%bgObject:G,col)
      %bgObject:RzArmed = 1
      EXIT
    END
#ENDIF
#IF(%bgSortHdr)
    IF %bgObject:SortCol >= 0
      DO BG:Sort:%bgObject
    END
#ENDIF
    EXIT
  END
  IF row < 0 OR row >= RECORDS(%bgQueue) THEN EXIT.
  %bgList{PROP:Selected} = row + 1
  POST(EVENT:NewSelection,%bgList)                            ! let the browse react as usual
!  Give the focus to the BROWSE, not to the region. The LIST is invisible to
!  Windows but perfectly alive to Clarion, so with the focus on it every key an
!  ABC browse has always answered goes on working, unchanged and unwritten by
!  us: up and down arrows, PageUp and PageDown, Ctrl-PageUp and Ctrl-PageDown
!  for the two ends, the incremental locator, Insert, Delete and Enter. The
!  region only ever needed the mouse, and a REGION with PROP:IMM gets that
!  whether it has the focus or not.
  SELECT(%bgList)
  %bgObject:Sel = row
  d2g_Select(%bgObject:G,row)
  d2g_Repaint(%bgObject:G)

BG:Rows:%bgObject ROUTINE
!  Make the grid and the browse agree on how tall a row is, because otherwise
!  they never agree on how long a PAGE is. ABC works out how many records to
!  load from the LIST's height and its line height; the grid works out how many
!  it can draw from the region's height and its row height. Let those differ
!  and the browse loads records the grid has no room for - they end up below
!  the visible area, and the last of them cannot be seen at all.
!
!  PROP:LineHeight answers in whatever PROP:Pixels is currently set to - 8
!  units, 16 pixels, measured in examples/BrowseGrid/lineh.clw - so it is read
!  in pixels, which is what the grid works in.
  DATA
sp   LONG,AUTO
lh   LONG,AUTO
need LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
!  Whatever height is wanted, it can never be less than the type needs - that
!  is what made big rows come out short. The engine clamps it too, but the
!  clamped value is what has to go back to the LIST, or the browse still loads
!  to a height nothing is drawn at.
!  d2g_RowNeed already counts the lines in a record and the lines a wrapped
!  cell may use. Multiplying by the line count again here made a row as tall as
!  its lines SQUARED - and on a four-line format that is taller than the whole
!  browse, so ABC worked out that nothing fitted, loaded no records, and the
!  grid had nothing whatever to draw.
  need = d2g_RowNeed(%bgObject:G)
#IF(%bgRowH > 0)
!  A row height was asked for, so the BROWSE is the one that gives way.
  lh = %bgRowH
#ELSE
!  Nothing was asked for: take the browse's own line height...
  lh = %bgList{PROP:LineHeight} * %bgObject:Lines             ! which is per LINE, not per record
#ENDIF
  IF lh < need THEN lh = need.                                ! ...but never squash the type
  d2g_RowHeight(%bgObject:G,lh)
!  PROP:LineHeight is the height of one LINE, not of one record. On a
!  multi-line format the LIST multiplies it by the lines in the record itself,
!  so handing it the whole record height meant the browse thought each record
!  was lines-times-taller than it is, worked out that one fitted, and loaded
!  one. The grid keeps the record height; the LIST is given one line of it.
  IF %bgObject:Lines > 1
    %bgList{PROP:LineHeight} = lh / %bgObject:Lines
  ELSE
    %bgList{PROP:LineHeight} = lh
  END
  0{PROP:Pixels} = sp

BG:Items:%bgObject ROUTINE
!  Make the browse load as many records as the grid can DRAW.
!
!  ABC works out how many to load from the LIST's own height and line height.
!  The grid works out how many it can draw from the region's height and its row
!  height. Those are close but not equal - the two headings are different sizes,
!  for one - and whatever is left over is drawn as empty grid: one blank banded
!  row and then background, which is the gap under the rows.
!
!  Rather than guess at the difference, it is measured. Whatever the LIST is
!  using for its own heading is (its height - items * line height), and that
!  stays true whatever else changes, so the height it needs to hold `fit` rows
!  is that plus fit line heights. The LIST is invisible, so making it taller or
!  shorter than the region costs nothing and is never seen.
  DATA
sp    LONG,AUTO
x     SIGNED,AUTO
y     SIGNED,AUTO
w     SIGNED,AUTO
h     SIGNED,AUTO
lh    LONG,AUTO
newlh LONG,AUTO
items LONG,AUTO
fit   LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  lh    = %bgList{PROP:LineHeight}
  items = %bgList{PROP:Items}
  fit   = d2g_PageSize(%bgObject:G)
!  Through the LINE HEIGHT, not the geometry. Stretching the LIST taller was
!  the obvious way to make ABC load more records, and it worked - until the
!  region started following the LIST on every fill, at which point the grid
!  inherited the stretch and ran off the bottom of the window and over the
!  buttons. Two mechanisms feeding each other.
!
!  The line height reaches the same answer and touches nothing anyone can see:
!  ABC divides the LIST height by it to decide how many records fit, so asking
!  for  of them is arithmetic on a number that is already invisible.
  IF lh > 0 AND items > 0 AND fit > 0 AND fit <> items
    newlh = items * lh / fit
    IF newlh < 2 THEN newlh = 2.
    %bgList{PROP:LineHeight} = newlh
  END
  0{PROP:Pixels} = sp

BG:Conceal:%bgObject ROUTINE
!  Take WS_VISIBLE off the LIST at the WINDOWS level. Not HIDE(): ABC works out
!  how many rows to load from the control's own state, and a hidden browse
!  decides it has none - that was the very first bug this template had. But
!  WS_VISIBLE is Windows' flag, not Clarion's. Strip it and Windows stops
!  painting and hit-testing the control, while PROP:Hide, the queue, the
!  visible-row count and everything else ABC reads are untouched. Proved in
!  examples/BrowseGrid/novis.clw: winvis 1>0, PROP:Hide 0>0, recs 20.
!
!  This replaces WS_CLIPSIBLINGS, which was never enough. The two controls
!  really are siblings - the same harness reports sameparent 1 - so the LIST
!  was painting by some route that ignores the clip, and it did it every time
!  it had any reason to redraw: on being given a new column width, on taking
!  the focus for the popup. A window Windows will not paint cannot do that.
  DATA
sty LONG,AUTO
  CODE
  sty = bgApi_GetWindowLong(%bgList{PROP:Handle},BG:GwlStyle)
  IF BAND(sty,BG:Visible)
    bgApi_SetWindowLong(%bgList{PROP:Handle},BG:GwlStyle,                       |
                        BAND(sty,BXOR(0FFFFFFFFh,BG:Visible)))
    bgApi_SetWindowPos(%bgList{PROP:Handle},0,0,0,0,0,                          |
                       BOR(BOR(BG:FrameChanged,BG:NoMove),BOR(BG:NoSize,BG:NoZOrder)))
    %bgObject:Clipped = 1
  END

BG:Reveal:%bgObject ROUTINE
!  ...and give it back, so a window that gives up on the grid still has a
!  working browse to show.
  DATA
sty LONG,AUTO
  CODE
  IF ~%bgObject:Clipped THEN EXIT.
  sty = bgApi_GetWindowLong(%bgList{PROP:Handle},BG:GwlStyle)
  bgApi_SetWindowLong(%bgList{PROP:Handle},BG:GwlStyle,BOR(sty,BG:Visible))
  bgApi_SetWindowPos(%bgList{PROP:Handle},0,0,0,0,0,                            |
                     BOR(BOR(BG:FrameChanged,BG:NoMove),BOR(BG:NoSize,BG:NoZOrder)))
  %bgObject:Clipped = 0

BG:Mark:%bgObject ROUTINE
!  Where ABC will say which column it sorted by, believe it rather than our own
!  memory of what was clicked - a sort can be changed by a tab, a button or the
!  browse's own code, none of which come through us. PROPLIST:SortColumn is
!  only kept when the browse was given sort colours, so when it says nothing
!  the mark stays where the last click put it.
#IF(%bgSortHdr)
  DATA
sc LONG,AUTO
i  LONG,AUTO
  CODE
#IF(%bgFilterBtn)
  d2g_FilterOn(%bgObject:G,-1,0)                              ! every mark, every refill
  LOOP i = 1 TO %bgObject:Cols
    IF %bgObject:ColFilt[i] THEN d2g_FilterOn(%bgObject:G,i - 1,1).
  END
#ENDIF
  sc = %bgList{PROPLIST:SortColumn}
  IF ~sc OR sc = %bgObject:SortOn THEN EXIT.
  %bgObject:SortOn = sc
  LOOP i = 1 TO %bgObject:Cols                                ! back to a GRID column
    IF %bgObject:Col[i] = sc
      d2g_SortMark(%bgObject:G,i - 1,%bgObject:SortDir)
      EXIT
    END
  END
  d2g_SortMark(%bgObject:G,-1,1)                              ! sorted on a column we do not draw
#ELSE
  EXIT
#ENDIF

BG:Menu:%bgObject ROUTINE
!  Excel's column drop-down. Sorting goes through the browse exactly as a
!  heading click does; filtering goes through ABC's own SetFilter, so range
!  limits, locators and everything else the browse was given keep working.
!
!  The field name for the filter comes from WHO(): an ABC browse queue labels
!  its fields with the file fields they came from, so WHO(Queue:Browse:1,n)
!  answers "STU:LastName" - which is exactly what a filter expression wants,
!  and means nothing has to be mapped by hand.
#IF(%bgFilterBtn)
  DATA
pick LONG,AUTO
fld  LONG,AUTO
lc   LONG,AUTO
nm   CSTRING(65)
val  CSTRING(129)
  CODE
  fld = %bgObject:Fld[%bgObject:SortCol + 1]
  IF ~fld THEN EXIT.
  nm  = CLIP(WHO(%bgQueue,fld))
  GET(%bgQueue,CHOICE(%bgList))
  IF ERRORCODE()
    val = ''
  ELSE
    val = CLIP(LEFT(WHAT(%bgQueue,fld)))
  END
!  NO SEPARATORS. POPUP counts a '-' as an item, so with two of them in here
!  every choice after the first was numbered one or two higher than it looked -
!  "Filter on" was item 3 and matched nothing, and "Clear this filter" was item
!  4, which is why CLEARING a filter is what applied one.
  pick = POPUP('Sort &Ascending|Sort &Descending|' |
             & '&Filter on {{' & CLIP(val) & '}|Filter &by value...|' |
             & 'Clear this &filter|Clear all f&ilters|&Columns...|&Reset layout')
  CASE pick
  OF 1                                                        ! ascending
    lc = %bgObject:Col[%bgObject:SortCol + 1]
    IF %bgObject:SortOn <> lc
      DO BG:Sort:%bgObject                                    ! a new heading starts ascending
    ELSIF %bgObject:SortDir < 0
      DO BG:Sort:%bgObject                                    ! it is descending: one press flips it
    END
  OF 2                                                        ! descending
!  Clearing SortOn first - which is what this used to do - makes BG:Sort take
!  its "a new column" branch, and that branch always sets ascending. So both
!  menu items came out ascending however many times they were pressed. Ask for
!  the direction instead, and press only as often as getting there takes.
    lc = %bgObject:Col[%bgObject:SortCol + 1]
    IF %bgObject:SortOn <> lc
      DO BG:Sort:%bgObject                                    ! ascending first...
      DO BG:Sort:%bgObject                                    ! ...then over to descending
    ELSIF %bgObject:SortDir > 0
      DO BG:Sort:%bgObject
    END
  OF 3                                                        ! filter on this value
    IF nm AND val
!  Per column, and they add up - filtering a second column used to replace the
!  first, so the browse quietly stopped being filtered on the one whose glyph
!  had just gone out.
      %bgObject:ColFilt[%bgObject:SortCol + 1] = CLIP(nm) & ' = ' & '''' & CLIP(val) & ''''
      d2g_FilterOn(%bgObject:G,%bgObject:SortCol,1)
      d2g_PaintNow(%bgObject:G)                               ! say so NOW, not when the data lands
      DO BG:Filter:%bgObject
    END
  OF 4                                                        ! pick from the values in the file
    DO BG:Values:%bgObject
  OF 5                                                        ! clear this column's
    %bgObject:ColFilt[%bgObject:SortCol + 1] = ''
    d2g_FilterOn(%bgObject:G,%bgObject:SortCol,0)
    d2g_PaintNow(%bgObject:G)
    DO BG:Filter:%bgObject
  OF 6                                                        ! clear every column's
    LOOP fld = 1 TO 32
      %bgObject:ColFilt[fld] = ''
    END
    d2g_FilterOn(%bgObject:G,-1,0)
    d2g_PaintNow(%bgObject:G)
    DO BG:Filter:%bgObject
  OF 7                                                        ! which columns to show
    DO BG:Chooser:%bgObject
  OF 8                                                        ! put everything back
    DO BG:Reset:%bgObject
  END
#ELSE
  EXIT
#ENDIF

BG:Filter:%bgObject ROUTINE
!  Hand the filter to the browse itself. Nothing else can do it: the records
!  come out of the VIEW, and only the browse object knows how to re-read them.
#IF(%bgFilterBtn)
#IF(%bgBrowseObj)
  DATA
i LONG,AUTO
  CODE
!  A filter ID OF OUR OWN, one per column. Two reasons, and the first is not
!  cosmetic: SetFilter with no ID uses '5 Standard', which is the ID the
!  BrowseBox template itself uses for the filter the developer set on the browse
!  (ABBROWSE.TPW:1120). Filtering from the grid was therefore throwing that
!  filter away, and clearing ours left the browse permanently unfiltered.
!
!  The second is that ABC already does the joining. ApplyFilter walks every ID
!  it holds and ANDs them, each in its own brackets, with the range limits in
!  front (ABFILE.CLW:2613) - so there is nothing to concatenate here, and an
!  empty expression DELETES that ID rather than leaving an empty bracket.
!  Setting all of them every time is therefore both safe and idempotent.
  %bgObject:Filters = 0
  LOOP i = 1 TO %bgObject:Cols
    %bgBrowseObj.SetFilter(%bgObject:ColFilt[i],'BrowseGrid:' & i)
    IF %bgObject:ColFilt[i] THEN %bgObject:Filters += 1.
  END
!  No DATA section here, so no CODE statement either - a ROUTINE only accepts
!  CODE after a DATA block, and this one emitted a bare one the moment the
!  filter button was switched on.
!
!  Filling the grid HERE reads the old queue. ABC does not finish applying a
!  filter inside SetSort: it ends with PostNewSelection, which is a POST, so
!  the re-read lands on a later ACCEPT cycle - which is why the list only
!  caught up when something else was done to it, and why clearing a filter
!  appeared to do nothing until the next click. SetSort also restarts from the
!  queue's own view position rather than the top, so on a filter that matches
!  nothing where the cursor is, it can come back empty.
!
!  So: apply it, then ask the browse to go to the top of the new set through
!  its own event. ABC re-reads, calls Reset when it has, and the Reset embed
!  fills the grid - by which time there is something to fill it from.
  %bgBrowseObj.ResetSort(1)
  POST(EVENT:ScrollTop,%bgList)
  POST(BG:Refill:%bgObject)                                   ! and refresh once it has landed
#ELSE
  MESSAGE('This grid has no browse object named on its prompts, so it cannot ' |
        & 'filter. Put the browse<39>s object name - BRW1, usually - in ' |
        & '<39>Browse object to filter through<39>.','BrowseGrid',ICON:Exclamation)
#ENDIF
#ELSE
  EXIT
#ENDIF

BG:Sort:%bgObject ROUTINE
!  Sort by the column that was clicked, exactly as clicking the LIST's own
!  heading would. ABC's sort-header class reads PROPLIST:MouseDownField to find
!  out which column was pressed (brwext.clw:2926) - and that property can simply
!  be WRITTEN. So it is set and EVENT:HeaderPressed posted, and there is no
!  geometry in it at all.
!
!  It used to post a fake mouse click at the heading's x instead, which is why
!  a column could not be sorted until it had been resized once.
!  examples/BrowseGrid/mdfield.clw shows why: a posted click on a LIST that
!  Windows will not paint raises no header press whatever - "HeaderPressed n1"
!  counts the written one only, not the clicked one - while writing the field
!  and posting the event works on the concealed control every time.
#IF(%bgSortHdr)
  DATA
lc LONG,AUTO
  CODE
!  One press of a heading, and a note of what it will have done. ABC toggles
!  ascending and descending on each press of the SAME heading and starts a new
!  one ascending; nothing reports the direction back - PROPLIST:SortColumn is
!  an ABS() - so the only way to ask for a direction is to know where it
!  currently is. That is what SortOn and SortDir are: our model of ABC's state,
!  kept by the same rule ABC keeps it.
  lc = %bgObject:Col[%bgObject:SortCol + 1]                   ! which LIST column that was
  IF ~lc THEN EXIT.
  IF %bgObject:SortOn = lc
    %bgObject:SortDir = -%bgObject:SortDir
  ELSE
    %bgObject:SortOn  = lc
    %bgObject:SortDir = 1
  END
  d2g_SortMark(%bgObject:G,%bgObject:SortCol,%bgObject:SortDir)
  %bgList{PROPLIST:MouseDownField} = lc
  POST(EVENT:HeaderPressed,%bgList)
#ELSE
  EXIT
#ENDIF

BG:GrpBack:%bgObject ROUTINE
!  Put a resized group back onto the LIST: the group's own width, and every
!  field inside it, because they were all scaled to fit. The browse goes on
!  believing it owns its columns, and a rebuild reads back what is on screen.
#IF(%bgSizeable)
  DATA
i  LONG,AUTO
lc LONG,AUTO
g  LONG,AUTO
  CODE
  g = %bgObject:RzCol - 1
  lc = %bgObject:GrpCol[g + 1]
  IF lc
    %bgList{PROPLIST:Width + PROPLIST:Group,lc} = d2g_GrpWidth(%bgObject:G,g) / 2
  END
  LOOP i = 1 TO %bgObject:Cols
    IF d2g_ColGrp(%bgObject:G,i - 1) <> g THEN CYCLE.
    lc = %bgObject:Col[i]
    IF lc
      %bgList{PROPLIST:Width,lc} = d2g_GrpColW(%bgObject:G,i - 1) / 2
    END
  END
  DO BG:Place:%bgObject
  d2g_Resize(%bgObject:G)
  d2g_PaintNow(%bgObject:G)
#ELSE
  EXIT
#ENDIF

BG:Reset:%bgObject ROUTINE
!  Throw away everything this grid remembers and read the browse again as it was
!  designed. Anything that can be got into a state has to have a way out of it,
!  and hunting through an INI file is not one.
#IF(%bgRemember)
  DATA
c   LONG,AUTO
ex  LONG,AUTO
fld LONG,AUTO
was CSTRING(32)
  CODE
  IF ~%bgObject:G THEN EXIT.
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    was = CLIP(INIMgr.Fetch('BrowseGrid:%Procedure:%bgObject','h' & c))
    IF was AND was <> '0'                                     ! it was hidden: put it back
      %bgList{PROPLIST:Width,c} = was
    END
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','w' & c,'')
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','h' & c,'')
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','f' & c,'')
  END
  LOOP c = 1 TO 32
    %bgObject:ColFilt[c] = ''
  END
  d2g_FilterOn(%bgObject:G,-1,0)
  DO BG:Columns:%bgObject
  DO BG:Rows:%bgObject
  d2g_Resize(%bgObject:G)
  DO BG:Filter:%bgObject
#ELSE
  EXIT
#ENDIF

BG:Values:%bgObject ROUTINE
!  Excel's checklist: every value in this column, tick the ones to keep.
!
!  The field is known only by NAME - WHO() off the browse queue - so the values
!  are read with EVALUATE(), which resolves a name against whatever is bound.
!  ABC binds the whole record buffer (FileManager.BindFields), and the proof it
!  is already bound is that the filter expressions built from the same names
!  work at all.
!
!  Reading the file moves its record buffer, which the browse shares. That is
!  why this always finishes by re-applying the filters: the browse re-reads and
!  is put back where it belongs, whether values were chosen or not.
#IF(%bgFilterBtn AND %bgFile)
  DATA
VQ   QUEUE
Mark   STRING(4)                                              ! shown - see the note on ChQ
Val    STRING(64)                                             ! shown
On     BYTE                                                   ! not shown
     END
VW   WINDOW('Values'),AT(,,164,224),GRAY,SYSTEM,FONT('Segoe UI',9)
       LIST,AT(6,6,152,166),USE(?VList),FROM(VQ),                              |
            FORMAT('20C~Keep~@s4@126L(2)~Value~@s64@'),ALRT(SpaceKey)
       BUTTON('&All'),AT(6,176,34,14),USE(?VAll)
       BUTTON('&None'),AT(44,176,34,14),USE(?VNone)
       BUTTON('&OK'),AT(58,196,48,16),USE(?VOk),DEFAULT
       BUTTON('&Cancel'),AT(110,196,48,16),USE(?VCancel)
     END
nm   CSTRING(65)
v    CSTRING(65)
expr CSTRING(161)
n    LONG,AUTO
i    LONG,AUTO
on   LONG,AUTO
off  LONG,AUTO
  CODE
  nm = CLIP(WHO(%bgQueue,%bgObject:Fld[%bgObject:SortCol + 1]))
  IF ~nm THEN EXIT.
  FREE(VQ)
  SET(%bgFile)
  LOOP
    NEXT(%bgFile)
    IF ERRORCODE() THEN BREAK.
    n += 1
    IF n > BG:MaxScan THEN BREAK.
    v = CLIP(LEFT(EVALUATE(nm)))
    VQ.Val = v
    GET(VQ,+VQ.Val)                                           ! sorted, so this dedupes as it goes
    IF ERRORCODE()
      VQ.Val  = v
      VQ.On   = 1
      VQ.Mark = ' X'
      ADD(VQ,+VQ.Val)
      IF RECORDS(VQ) >= BG:MaxVals THEN BREAK.
    END
  END
  IF ~RECORDS(VQ)
    DO BG:Filter:%bgObject                                    ! put the browse back regardless
    EXIT
  END
  OPEN(VW)
  VW{PROP:Text} = 'Values in ' & CLIP(nm)
  ACCEPT
  IF EVENT() = EVENT:AlertKey AND KEYCODE() = SpaceKey AND FIELD() = ?VList
    GET(VQ,CHOICE(?VList))
    IF ~ERRORCODE()
      VQ.On   = 1 - VQ.On
      VQ.Mark = CHOOSE(VQ.On = 1, ' X', '')
      PUT(VQ)
      DISPLAY(?VList)
    END
    CYCLE
  END
    CASE ACCEPTED()
    OF ?VList
      GET(VQ,CHOICE(?VList))
      IF ~ERRORCODE()
        VQ.On   = 1 - VQ.On
        VQ.Mark = CHOOSE(VQ.On = 1, ' X', '')
        PUT(VQ)
        DISPLAY(?VList)
      END
    OF ?VAll
    OROF ?VNone
      LOOP i = 1 TO RECORDS(VQ)
        GET(VQ,i)
        VQ.On   = CHOOSE(ACCEPTED() = ?VAll, 1, 0)
        VQ.Mark = CHOOSE(VQ.On = 1, ' X', '')
        PUT(VQ)
      END
      DISPLAY(?VList)
    OF ?VOk
      LOOP i = 1 TO RECORDS(VQ)
        GET(VQ,i)
        IF VQ.On
          on += 1
          IF LEN(CLIP(expr)) < 120                            ! keep the expression sane
            IF expr
              expr = CLIP(expr) & ' OR ' & CLIP(nm) & ' = ' & '''' & CLIP(VQ.Val) & ''''
            ELSE
              expr = CLIP(nm) & ' = ' & '''' & CLIP(VQ.Val) & ''''
            END
          END
        ELSE
          off += 1
        END
      END
      IF ~off OR ~on                                          ! all of them, or none: no filter
        %bgObject:ColFilt[%bgObject:SortCol + 1] = ''
        d2g_FilterOn(%bgObject:G,%bgObject:SortCol,0)
      ELSE
        %bgObject:ColFilt[%bgObject:SortCol + 1] = '(' & CLIP(expr) & ')'
        d2g_FilterOn(%bgObject:G,%bgObject:SortCol,1)
      END
      POST(EVENT:CloseWindow)
    OF ?VCancel
      POST(EVENT:CloseWindow)
    END
  END
  CLOSE(VW)
  d2g_PaintNow(%bgObject:G)
  DO BG:Filter:%bgObject
#ELSE
!  Without a file named on the prompts there is nothing to read the values out
!  of - the grid only ever sees a page of the queue.
  MESSAGE('Name the file this browse reads, on the grid<39>s prompts, and the ' |
        & 'column menu can offer the values in it.','BrowseGrid',ICON:Asterisk)
#ENDIF

BG:Chooser:%bgObject ROUTINE
!  Which columns to show. Hiding one is not a grid idea at all - a LIST column
!  of zero width is already invisible to Clarion, and BG:Columns already skips
!  those - so this only has to set widths and read them back. The width it had
!  is remembered so unhiding puts it back where it was rather than at some
!  default, and the layout store keeps that across runs for free, because it
!  keys on LIST column number.
#IF(%bgChooser)
  DATA
!  ORDER MATTERS. A LIST with FROM(queue) hands its format columns the queue's
!  fields in the order they are declared - there is no naming of one to the
!  other - so the fields that are shown have to come first. Declared as
!  Mark, On, Name the second column showed On, which is why every row read "1".
ChQ  QUEUE
Mark   STRING(4)                                              ! shown: plain text, unmistakable
Name   STRING(64)                                             ! shown
On     BYTE                                                   ! and the rest are not
Col    LONG
Wid    LONG
     END
ChW  WINDOW('Columns'),AT(,,200,232),GRAY,SYSTEM,FONT('Segoe UI',9)
       LIST,AT(6,6,188,168),USE(?ChList),FROM(ChQ),                            |
            FORMAT('20C~Show~@s4@160L(2)~Column~@s64@'),ALRT(SpaceKey)
       BUTTON('&Show'),AT(6,178,44,14),USE(?ChShow)
       BUTTON('&Hide'),AT(54,178,44,14),USE(?ChHide)
       BUTTON('&All'),AT(102,178,44,14),USE(?ChAll)
       BUTTON('&None'),AT(150,178,44,14),USE(?ChNone)
       BUTTON('&OK'),AT(94,202,48,16),USE(?ChOk),DEFAULT
       BUTTON('&Cancel'),AT(146,202,48,16),USE(?ChCancel)
     END
c    LONG,AUTO
ex   LONG,AUTO
fld  LONG,AUTO
wid  LONG,AUTO
was  CSTRING(32)
head CSTRING(65)
p    LONG,AUTO
ok   LONG,AUTO
  CODE
  FREE(ChQ)
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.                                       ! a decoration, not a column
    wid = %bgList{PROPLIST:Width,c}
    head = CLIP(%bgList{PROPLIST:Header,c})
    IF ~head
      head = CLIP(%bgList{PROPLIST:Header + PROPLIST:Group,c})
    END
    LOOP p = 1 TO LEN(head)
      IF head[p] = '|' THEN head[p] = ' '.
    END
    ChQ.Name = CLIP(LEFT(head))
!  In a grouped format most columns carry no heading of their own - the group's
!  heading stands over the lot - so this list came out blank, and "Column 7" is
!  no better. WHO() answers with the field the column shows, STU:LastName,
!  because an ABC browse queue labels its fields with the file fields they came
!  from. It is the same thing that lets the grid build a filter expression.
    IF ~ChQ.Name
      ChQ.Name = CLIP(WHO(%bgQueue,fld))
    END
    IF ~ChQ.Name THEN ChQ.Name = 'Column ' & c.
    ChQ.Col  = c
    ChQ.On   = CHOOSE(wid > 0, 1, 0)
    ChQ.Mark = CHOOSE(ChQ.On = 1, ' X', '')
    IF wid > 0
      ChQ.Wid = wid
    ELSE                                                      ! hidden: what was it before?
      was = CLIP(INIMgr.Fetch('BrowseGrid:%Procedure:%bgObject','h' & c))
      ChQ.Wid = CHOOSE(was <> '', was, 40)
    END
    ADD(ChQ)
  END
  IF ~RECORDS(ChQ) THEN EXIT.
  OPEN(ChW)
  ACCEPT
!  A Clarion LIST only raises ACCEPTED on a double click or Enter, so a single
!  click on a row did nothing at all and the dialog looked inert. Space toggles
!  the highlighted row, and there are buttons for people who would rather press
!  one - a list that appears to ignore you is worse than no list.
  IF EVENT() = EVENT:AlertKey AND KEYCODE() = SpaceKey AND FIELD() = ?ChList
    GET(ChQ,CHOICE(?ChList))
    IF ~ERRORCODE()
      ChQ.On   = 1 - ChQ.On
      ChQ.Mark = CHOOSE(ChQ.On = 1, ' X', '')
      PUT(ChQ)
      DISPLAY(?ChList)
    END
    CYCLE
  END
    CASE ACCEPTED()
    OF ?ChList
    OROF ?ChShow
    OROF ?ChHide
      GET(ChQ,CHOICE(?ChList))
      IF ~ERRORCODE()
        CASE ACCEPTED()
        OF ?ChShow ; ChQ.On = 1
        OF ?ChHide ; ChQ.On = 0
        ELSE       ; ChQ.On = 1 - ChQ.On                      ! double click or Enter
        END
        ChQ.Mark = CHOOSE(ChQ.On = 1, ' X', '')
        PUT(ChQ)
        DISPLAY(?ChList)
      END
    OF ?ChAll
    OROF ?ChNone
      LOOP p = 1 TO RECORDS(ChQ)
        GET(ChQ,p)
        ChQ.On   = CHOOSE(ACCEPTED() = ?ChAll, 1, 0)
        ChQ.Mark = CHOOSE(ChQ.On = 1, ' X', '')
        PUT(ChQ)
      END
      DISPLAY(?ChList)
    OF ?ChOk
      wid = 0
      LOOP p = 1 TO RECORDS(ChQ)                              ! is anything left to look at?
        GET(ChQ,p)
        IF ChQ.On THEN wid += 1.
      END
      IF ~wid
        MESSAGE('A grid has to show at least one column.','Columns',ICON:Exclamation)
        CYCLE
      END
      ok = 1                                                  ! decided; applied further down
      POST(EVENT:CloseWindow)
    OF ?ChCancel
      CLOSE(ChW)
      EXIT
    END
  END
  CLOSE(ChW)
  IF ~ok THEN EXIT.
!  APPLIED HERE, not in the button. A field equate is resolved against whatever
!  window is CURRENT, and while this dialog was open that was the dialog - so
!  every ?Browse:1{PROPLIST:Width} written inside the ACCEPT loop above went to
!  a control of the Columns window instead of to the browse, and did nothing at
!  all. Nothing complains: the write is legal, it simply lands somewhere else.
!  With the dialog closed the browse window is current again and the same lines
!  do what they read as.
  LOOP p = 1 TO RECORDS(ChQ)
    GET(ChQ,p)
    IF ChQ.On
      %bgList{PROPLIST:Width,ChQ.Col} = ChQ.Wid
    ELSE
!  Remember how wide it was before it went, so it comes back the same size.
      INIMgr.Update('BrowseGrid:%Procedure:%bgObject','h' & ChQ.Col,ChQ.Wid)
      %bgList{PROPLIST:Width,ChQ.Col} = 0
    END
  END
!  The columns are different now, so they have to be read again from scratch.
  DO BG:Columns:%bgObject
  DO BG:Rows:%bgObject
  d2g_Resize(%bgObject:G)
  DO BG:Fill:%bgObject
  d2g_PaintNow(%bgObject:G)
#ELSE
  EXIT
#ENDIF

BG:Recall:%bgObject ROUTINE
!  Put remembered column widths back on the LIST BEFORE the grid reads them, so
!  there is one path that decides a width and the grid does not have to be told
!  twice. Keyed by LIST column number rather than by grid column, because a
!  hidden column is not in the grid's list at all and its width would otherwise
!  have nowhere to come back to.
#IF(%bgRemember)
  DATA
c   LONG,AUTO
ex  LONG,AUTO
val CSTRING(32)
  CODE
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
!  A stored 0 means "this column was hidden" and has to be honoured, not
!  skipped - skipping it is what made hiding a column last only until the
!  window was next opened.
    val = CLIP(INIMgr.Fetch('BrowseGrid:%Procedure:%bgObject','w' & c))
    IF val
      %bgList{PROPLIST:Width,c} = val
    END
  END
#ELSE
  EXIT
#ENDIF

BG:RecallF:%bgObject ROUTINE
!  Filters are NOT restored, and any that were stored are thrown away here.
!
!  Widths are safe to put back: the worst a bad one can do is look wrong. A
!  filter is not. It is handed to ABC as an expression, and an expression that
!  will not parse is a run-time error - at window open, before there is anything
!  on screen to explain it. A filter stored by an earlier version of this
!  template therefore killed the application every time the window opened, and
!  went on doing it through every rebuild, because it was in the INI file and
!  not in the program.
!
!  Restoring them was also the wrong idea on its own merits. Someone who opens
!  a browse expects to see the records, not yesterday's filter with no
!  indication of why three quarters of the file is missing.
#IF(%bgRemember)
  DATA
i LONG,AUTO
  CODE
  LOOP i = 1 TO 512
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','f' & i,'')
  END
#ELSE
  EXIT
#ENDIF

BG:Remember:%bgObject ROUTINE
!  Written at Kill, so it costs nothing until the window closes.
#IF(%bgRemember)
  DATA
i   LONG,AUTO
c   LONG,AUTO
ex  LONG,AUTO
fld LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
!  EVERY column, not only the ones the grid is drawing. A hidden column is not
!  in the grid's list at all, so writing only those left its old width sitting
!  in the file - and BG:Recall put it back on the next open, which is a hidden
!  column coming back from the dead. Zero is a width too, and has to be stored
!  like one.
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','w' & c,%bgList{PROPLIST:Width,c})
  END
  LOOP i = 1 TO %bgObject:Cols                                ! the drawn ones, at grid precision
    IF ~%bgObject:Col[i] THEN CYCLE.
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','w' & %bgObject:Col[i], |
                  d2g_ColWidth(%bgObject:G,i - 1) / 2)
  END
#ELSE
  EXIT
#ENDIF

BG:Cover:%bgObject ROUTINE
!  Put the grid back over the LIST and draw it THIS INSTANT. Wanted any time
!  the LIST has had a reason to paint itself - taking the focus, being given a
!  new column width - because the clip style stops it owning the region's
!  pixels but does not stop it drawing into them.
#IF(%bgPopup)
  IF ~%bgObject:G THEN EXIT.
  DO BG:Place:%bgObject
  d2g_Resize(%bgObject:G)
  d2g_PaintNow(%bgObject:G)
#ELSE
  EXIT
#ENDIF

BG:Right:%bgObject ROUTINE
!  Hand a right-click back to the browse. NOT by forwarding the click itself:
!  the grid's rows and the LIST's rows are not the same height, so the same
!  y would pick a different record. The row is worked out in the grid's own
!  geometry, the LIST is told to select it, and then the browse is sent
!  AppsKey - "show the menu for what is selected", which needs no coordinates
!  at all. ABC alerts AppsKey on the list alongside MouseRightUp and treats
!  the two identically, so Insert/Change/Delete behave exactly as they always
!  did, popup formatter and all.
#IF(%bgPopup)
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
sp LONG,AUTO
row LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  row = d2g_HitRow(%bgObject:G,MOUSEY() - ry)
  0{PROP:Pixels} = sp
  IF row >= 0 AND row < RECORDS(%bgQueue)                     ! on a row: take it with us
    %bgList{PROP:Selected} = row + 1
    %bgObject:Sel = row
    d2g_Select(%bgObject:G,row)
    d2g_Repaint(%bgObject:G)
  END
  SELECT(%bgList)
  POST(BG:Popup:%bgObject)
#ELSE
  EXIT
#ENDIF

BG:Sizing:%bgObject ROUTINE
!  Two jobs on one event. Dragging: widen or narrow the column under the
!  pointer, measured from where the drag STARTED rather than from the last
!  event - deltas lose their remainder and the column creeps away from the
!  pointer. Not dragging: show the sizing cursor when the edge is grabbable, so
!  the user can see there is something there. Only when it CHANGES, or the
!  cursor is reset on every mouse move and flickers.
#IF(%bgSizeable)
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
sp LONG,AUTO
mx LONG,AUTO
my LONG,AUTO
col LONG,AUTO
wid LONG,AUTO
vp  LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  mx = MOUSEX() - rx
  my = MOUSEY() - ry
  0{PROP:Pixels} = sp
#IF(%bgBarStyle <> 'Windows')
  IF %bgObject:HDrag
    IF bgApi_GetAsyncKeyState(BG:VkLButton) >= 0
      %bgObject:HDrag = 0
      EXIT
    END
    %bgObject:ScrollX = d2g_HDrag(%bgObject:G,mx,%bgObject:HGrab)
    d2g_ScrollX(%bgObject:G,%bgObject:ScrollX)
    DO BG:Bars:%bgObject
    d2g_PaintNow(%bgObject:G)                                 ! sideways is ours: instant
    EXIT
  END
#ENDIF
  IF %bgObject:VDrag
!  THIS is what Windows' own scrollbar could not do. There is no modal loop
!  here - it is an ordinary mouse move - so ACCEPT runs, the browse is told to
!  scroll exactly as its own thumb would tell it, and by the time the pointer
!  has moved again the records are on screen. The thumb follows the POINTER
!  while the drag is on rather than the browse, so it cannot stutter.
    IF bgApi_GetAsyncKeyState(BG:VkLButton) >= 0
      %bgObject:VDrag = 0
      EXIT
    END
    vp = d2g_VDrag(%bgObject:G,my,%bgObject:VGrab)
    d2g_VBar(%bgObject:G,1,vp,BG:ThumbPct)
    IF vp <> %bgList{PROP:VScrollPos}
      %bgList{PROP:VScrollPos} = vp
      POST(EVENT:ScrollDrag,%bgList)                          ! ABC fetches, Reset redraws
    ELSE
      d2g_Repaint(%bgObject:G)
    END
    EXIT
  END
  IF %bgObject:RzCol
!  Windows answers with the high bit set while the button is down, and a SHORT
!  is signed, so "still held" is simply "negative". Clarion has no MOUSEDOWN,
!  and the mouse can be released off the grid, where no MouseUp ever arrives.
    IF bgApi_GetAsyncKeyState(BG:VkLButton) >= 0

      DO BG:SizeEnd:%bgObject
      EXIT
    END
    IF %bgObject:RzArmed
      IF ABS(mx - %bgObject:RzX) < BG:DragSlop THEN EXIT.      ! still just a click
      %bgObject:RzArmed = 0                                    ! it has moved: a real drag
    END
    wid = %bgObject:RzW + mx - %bgObject:RzX
!  Dragged shut. The width itself cannot go below the button, so what the
!  developer was reaching for - Excel's "drag it to nothing and it is hidden" -
!  was simply unreachable. The INTENT is caught here, before the clamp, and
!  acted on when the button comes up.
    %bgObject:RzHide = CHOOSE(wid < 8, 1, 0)
    IF wid < 16 THEN wid = 16.
    IF %bgObject:RzGrp
      d2g_SetGrpWidth(%bgObject:G,%bgObject:RzCol - 1,wid)    ! fields inside come with it
    ELSE
      d2g_SetWidth(%bgObject:G,%bgObject:RzCol - 1,wid)
    END
    DO BG:Bars:%bgObject                                      ! the columns are a different width now
    d2g_Repaint(%bgObject:G)
    EXIT
  END
  col = -1
  IF my < d2g_HdrHeight(%bgObject:G)
    col = d2g_HitEdge(%bgObject:G,mx)
  END
  IF col >= 0
    IF ~%bgObject:RzCur
      %bgObject:Rgn{PROP:Cursor} = CURSOR:SizeWE
      %bgObject:RzCur = 1
    END
  ELSIF %bgObject:RzCur
    %bgObject:Rgn{PROP:Cursor} = ''
    %bgObject:RzCur = 0
  END
#ELSE
  EXIT
#ENDIF

BG:SizeEnd:%bgObject ROUTINE
!  Put the new width back on the LIST as well. The browse goes on believing it
!  owns its own columns - anything that reads them, saves them or rebuilds the
!  grid from them then agrees with what is on screen.
#IF(%bgSizeable)
  DATA
c LONG,AUTO
  CODE
  %bgObject:VDrag = 0
  %bgObject:HDrag = 0
  IF ~%bgObject:RzCol THEN EXIT.
  IF %bgObject:RzArmed
!  It never moved, so it was a click on the heading after all - and a click on
!  a heading sorts. Nothing has been resized, so there is no width to write.
    %bgObject:RzArmed = 0
    %bgObject:RzCol   = 0
#IF(%bgSortHdr)
    IF %bgObject:SortCol >= 0
      DO BG:Sort:%bgObject
    END
#ENDIF
    EXIT
  END
  IF %bgObject:RzGrp
    DO BG:GrpBack:%bgObject                                   ! the whole group, fields and all
    %bgObject:RzGrp = 0
    %bgObject:RzCol = 0
    EXIT
  END
  c = %bgObject:Col[%bgObject:RzCol]
#IF(%bgChooser)
  IF c AND %bgObject:RzHide AND %bgObject:Cols > 1            ! never the last one
!  Hidden by dragging it shut, the way Excel does. Its width is kept so
!  Columns... can put it back the size it was.
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','h' & c, |
                  d2g_ColWidth(%bgObject:G,%bgObject:RzCol - 1) / 2)
    %bgList{PROPLIST:Width,c} = 0
    %bgObject:RzHide  = 0
    %bgObject:RzCol   = 0
    %bgObject:RzArmed = 0
    DO BG:Columns:%bgObject
    DO BG:Rows:%bgObject
    d2g_Resize(%bgObject:G)
    DO BG:Fill:%bgObject
    d2g_PaintNow(%bgObject:G)
    EXIT
  END
#ENDIF
  %bgObject:RzHide = 0
  IF c
    %bgList{PROPLIST:Width,c} = d2g_ColWidth(%bgObject:G,%bgObject:RzCol - 1) / 2
!  Changing a LIST's format makes it redraw itself, and it comes back over the
!  grid when it does - the clip style and the stacking order both survive the
!  write, so it is the painting that gets through, not the ordering. Putting
!  the region back on top and repainting it undoes that in the same breath.
!  Nothing else in the drag touches the LIST, which is why it only ever
!  happened when the button came up.
    DO BG:Place:%bgObject
    d2g_Resize(%bgObject:G)
    d2g_PaintNow(%bgObject:G)
  END
  %bgObject:RzCol = 0
#ELSE
  EXIT
#ENDIF

BG:Fill:%bgObject ROUTINE
!  Push the browse's queue into the grid. This is every visible row and no
!  more, which is exactly what the queue holds - the grid is told nothing
!  about the file.
  DATA
i     LONG,AUTO
col   LONG,AUTO
rows  LONG,AUTO
fit   LONG,AUTO
sp    LONG,AUTO
dx    SIGNED,AUTO
dy    SIGNED,AUTO
dw    SIGNED,AUTO
dh    SIGNED,AUTO
first LONG,AUTO
sel   LONG,AUTO
total LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  %bgObject:Fills += 1                                        ! for the diagnostics line
!  Keep the region ON the LIST, every time. Chasing the one right moment to
!  place it has now been wrong three times - at Init the resizer has not run, at
!  OpenWindow it may not have either, and a window restored to a remembered size
!  need not raise EVENT:Sized at all. A fill already happens whenever anything
!  changes, and following the LIST costs a GETPOSITION and a SETPOSITION.
  DO BG:Place:%bgObject
  total = RECORDS(%bgQueue)
  fit   = d2g_PageSize(%bgObject:G) + 1
  sel   = CHOICE(%bgList)
  first = 0
  rows  = total
  IF fit > 0 AND total > fit
!  The grid cannot draw the whole queue. Its rows are taller than the LIST's
!  lines, so the browse has loaded more records than there is room for, and
!  drawing from the top simply throws the tail away. Start far enough down that
!  the SELECTED record is one of the ones drawn - at the bottom of the file ABC
!  selects the last entry, and without this it was never on screen, which is
!  what made Ctrl-PageDown look as though it had selected nothing. The top
!  never showed it: entry one is always drawn.
    rows = fit
    IF sel > fit
      first = sel - fit
      IF first > total - fit THEN first = total - fit.
      IF first < 0 THEN first = 0.
    END
  END
  d2g_Page(%bgObject:G,first,rows)
  LOOP i = 1 TO rows
    GET(%bgQueue,first + i)
    IF ERRORCODE() THEN BREAK.
    LOOP col = 1 TO %bgObject:Cols
      IF %bgObject:Pic[col]
        %bgObject:Cell = CLIP(LEFT(FORMAT(WHAT(%bgQueue,%bgObject:Fld[col]), |
                                          CLIP(%bgObject:Pic[col]))))
      ELSE
        %bgObject:Cell = CLIP(LEFT(WHAT(%bgQueue,%bgObject:Fld[col])))
      END
      d2g_Cell(%bgObject:G,i - 1,col - 1,%bgObject:Cell)
    END
  END
#IF(%bgSortHdr)
  DO BG:Mark:%bgObject
#ENDIF
#IF(%bgDiag)
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgList,dx,dy,dw,dh)                            ! where the LIST really is
  0{PROP:Pixels} = sp
!  Everything the grid is working from, in the window title. When a browse
!  draws nothing there is no way to tell from the outside whether the queue was
!  empty, the rows were too tall to fit, or the columns never got read - and
!  those want different fixes.
  0{PROP:Text} = 'BG q=' & total & ' fill=' & %bgObject:Fills                   |
               & ' filt=' & %bgObject:Filters & ' hid=' & %bgObject:Hidden        |
               & ' cols=' & %bgObject:Cols                                      |
               & ' lines=' & %bgObject:Lines & ' rowh=' & d2g_RowH(%bgObject:G) |
               & ' need=' & d2g_RowNeed(%bgObject:G)                            |
               & ' page=' & d2g_PageSize(%bgObject:G) & ' fit=' & fit           |
               & ' draw=' & rows & ' lh=' & %bgList{PROP:LineHeight}            |
               & ' items=' & %bgList{PROP:Items}                               |
               & ' L=' & dx & ',' & dy & ',' & dw & ',' & dh
#ENDIF
  d2g_Total(%bgObject:G,total)
  %bgObject:Sel = sel                                         ! the browse owns the selection
  d2g_Select(%bgObject:G,sel - 1)                             ! absolute, and now always in view
  DO BG:Bars:%bgObject
  d2g_Repaint(%bgObject:G)

BG:Scroll:%bgObject ROUTINE
!  Sideways is ours: slide the columns and repaint, nothing else changes.
!  Downwards is the browse's: it is told to scroll exactly as it would be by
!  its own scrollbar, and when it has refilled its queue ABC calls Reset, which
!  is where the grid picks the new page up. So paging, locators and range
!  limits keep behaving as they always did.
#IF(%bgBars OR %bgWheel)
  DATA
i  LONG,AUTO
n  LONG,AUTO
sp LONG,AUTO
  CODE
  IF BG:LastCode = BG:FontCode
!  The type changed size, so the rows did too - and this time the GRID is the
!  one that knows how tall they are. NOT BG:Rows, which reads the height off
!  the LIST: that would pull the rows straight back down to the old line
!  height, leaving big type crammed into short rows with its descenders cut
!  off. The height goes the other way here, from the grid to the LIST, so the
!  browse reloads to fit however many rows there is now room for.
!  NOT BG:Rows. That asks the LIST how tall a row should be - and the LIST's
!  line height is the number we ourselves pushed up the last time the type grew.
!  Asking it again just gets that number back, so the rows would ratchet up and
!  never come down. When the type changes size the GRID is the authority and the
!  LIST is told, never the other way round.
    sp = 0{PROP:Pixels}
    0{PROP:Pixels} = 1
!  PER LINE, not per record - the same rule BG:Rows follows. This line had its
!  own copy of the calculation and so never got that fix: after a zoom the LIST
!  was told a whole three-line record was ONE line, worked out that a record was
!  three times taller again, and loaded a single one. Which is exactly what
!  zooming a multi-line browse looked like - every row but the first vanishing.
    IF %bgObject:Lines > 1
      %bgList{PROP:LineHeight} = d2g_RowH(%bgObject:G) / %bgObject:Lines
    ELSE
      %bgList{PROP:LineHeight} = d2g_RowH(%bgObject:G)
    END
    0{PROP:Pixels} = sp
    DO BG:Items:%bgObject                                     ! and load to the new page size
    DO BG:Fill:%bgObject
    EXIT
  END
  IF BG:LastCode = BG:WheelCode
!  One notch is three rows, the same as everywhere else in Windows. The browse
!  is asked to scroll exactly as its own scrollbar would ask it, so paging,
!  locators and range limits are none of our business.
    n = INT(ABS(BG:LastPos) / BG:WheelNotch) * BG:WheelLines
    IF n < 1 THEN n = 1.
    IF n > 30 THEN n = 30.                                    ! a flicked wheel is not a page jump
    LOOP i = 1 TO n
      IF BG:LastPos > 0
        POST(EVENT:ScrollUp,%bgList)
      ELSE
        POST(EVENT:ScrollDown,%bgList)
      END
    END
    EXIT
  END
  IF BG:LastBar = BG:SbHorz
    %bgObject:ScrollX = BG:LastPos
    d2g_ScrollX(%bgObject:G,%bgObject:ScrollX)
    d2g_Repaint(%bgObject:G)
    EXIT
  END
  CASE BG:LastCode
  OF 0
    POST(EVENT:ScrollUp,%bgList)
  OF 1
    POST(EVENT:ScrollDown,%bgList)
  OF 2
    POST(EVENT:PageUp,%bgList)
  OF 3
    POST(EVENT:PageDown,%bgList)
  OF 6
    POST(EVENT:ScrollTop,%bgList)
  OF 7
    POST(EVENT:ScrollBottom,%bgList)
  ELSE
    %bgList{PROP:VScrollPos} = BG:LastPos                     ! the thumb, dragged
    POST(EVENT:ScrollDrag,%bgList)
  END
#ELSE
  EXIT
#ENDIF

BG:Bars:%bgObject ROUTINE
!  Size both scrollbars from what is actually showing. Windows hides a bar
!  whose page covers its whole range, so the horizontal one appears only when
!  the columns are wider than the view, which is what anyone expects.
#IF(%bgBars)
  DATA
tot   LONG,AUTO
view  LONG,AUTO
pct   LONG,AUTO
fRecs LONG,AUTO
  CODE
  IF ~%bgObject:Barred THEN EXIT.
!  Sideways: the grid's own business - the total column width against the view.
  tot  = d2g_TotalWidth(%bgObject:G)
  view = d2g_ViewWidth(%bgObject:G)
  IF view < 1 THEN view = 1.
  IF tot <= view
    %bgObject:ScrollX = 0
    d2g_ScrollX(%bgObject:G,0)
#IF(%bgBarStyle = 'Windows')
    BG_SetBar(%bgObject:Rgn{PROP:Handle},BG:SbHorz,0,1,1)     ! nothing to scroll: no bar
#ELSE
    d2g_HBar(%bgObject:G,0,0,1,1)
#ENDIF
  ELSE
    IF %bgObject:ScrollX > tot - view THEN %bgObject:ScrollX = tot - view.
#IF(%bgBarStyle = 'Windows')
    BG_SetBar(%bgObject:Rgn{PROP:Handle},BG:SbHorz,%bgObject:ScrollX,view,tot)
#ELSE
    d2g_HBar(%bgObject:G,1,%bgObject:ScrollX,view,tot)
#ENDIF
  END
!  Down: NOT ours. The browse knows where it is in the file and keeps that in
!  the LIST's own PROP:VScrollPos, nought to a hundred - the same approximate
!  position Clarion's own browse thumb shows, because on an ISAM file that is
!  the only answer there is.
!  Downwards, ABC gives us one number and only one: PROP:VScrollPos, nought to
!  a hundred. It is the same approximate position Clarion's own browse thumb
!  shows, because on an ISAM file that is the only answer there is - nothing
!  knows the record count without reading the whole file. So the thumb is a
!  fixed size and the position is ABC's.
!  ABC only keeps PROP:VScrollPos when the browse was given a thumb, and turns
!  the LIST's scrollbar off when it was not - and with it off, writing
!  PROP:VScrollPos is ignored, so every drag read back as nought and was taken
!  for "go to the top". Turning it on costs nothing: the LIST is invisible, so
!  this is a number we are borrowing, not a scrollbar anyone will see.
  %bgList{PROP:VScroll} = 1
  IF ~%bgObject:VDrag                                         ! not while it is being dragged
    pct = BG:ThumbPct
#IF(%bgFile)
!  How big the thumb should be is a question that CAN be answered honestly:
!  RECORDS() reads the count out of the file header, so it costs nothing. A
!  page against the whole file is what every other scrollbar in Windows means
!  by the size of its thumb.
    fRecs = RECORDS(%bgFile)
    IF fRecs > 0
      pct = 100 * RECORDS(%bgQueue) / fRecs
      IF pct < 4 THEN pct = 4.
      IF pct > 100 THEN pct = 100.
    END
#ENDIF
    d2g_VBar(%bgObject:G,CHOOSE(pct >= 100, 0, 1),%bgList{PROP:VScrollPos},pct)
  END
!  A scrollbar appearing or disappearing RESIZES the client area behind our
!  back - hide the horizontal one and the client grows by its height. Nothing
!  covers the strip it vacated until the render target is grown to match, so
!  what shows there is whatever is underneath, which is the old list. This does
!  nothing at all unless the client area really did change.
  d2g_Resize(%bgObject:G)
#ELSE
  EXIT
#ENDIF
#ENDAT
#!#############################################################################
#!  GROUPS
#!#############################################################################
#!-----------------------------------------------------------------------------
#!  A Clarion COLOR prompt is a BGR long; the grid wants 0xRRGGBB.
#!-----------------------------------------------------------------------------
#!-----------------------------------------------------------------------------
#!  End of BrowseGrid template set
#!-----------------------------------------------------------------------------
