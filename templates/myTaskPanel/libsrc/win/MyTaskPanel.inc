!ABCIncludeFile(MYTASKPANEL)
! ============================================================================
!  MyTaskPanelClass - task panels for Clarion windows and MDI frames.
!
!  A task panel is the column of collapsible groups down the side of a window
!  (Catalogs, Reports, Exports, Help...), each group a card of clickable items.
!  Items can have submenus, and those submenus can have submenus, to any
!  depth - opened in place (a tree) or as a fly-out menu.
!
!  WHERE IT LIVES
!    Docked left or right, or floating in its own small window. On an MDI
!    frame the MDI client is narrowed to make room (under the toolbar, above
!    the status bar); on an ordinary window the window's client area is
!    narrowed and, optionally, the window grows by the panel's width. The user
!    can drag the panel off to float it, drag the floating panel back to an
!    edge to dock it, resize the docked panel by its inner edge, and pick
!    Dock left / Dock right / Float / Hide from the panel's own menu.
!
!  TWO ENGINES, ONE API
!    MTP:Clarion  - everything in Clarion source (GDI through the Windows API).
!                   No C, no DLL. The default.
!    MTP:DirectX  - Direct2D + DirectWrite: antialiased shapes, true
!                   gradients, ClearType text - and, with Effects on (the
!                   default), soft card shadows, glass headers, hover
!                   highlights that fade in and out, and a floating panel
!                   that turns see-through when the mouse leaves it
!                   (FloatOpacity). Painted by mtpd2d.c, compiled
!                   in by Clarion's own C compiler only when the project
!                   defines _MTP_D2D_=>1 (the global template does this). If
!                   it is not compiled in, or Direct2D will not start, the
!                   panel quietly paints with the Clarion engine instead.
!
!  QUICK START (hand code, after the window is open)
!      TP  MyTaskPanelClass
!      g   LONG
!      i   LONG
!        TP.Init(Window)                       ! or TP.Init(AppFrame, MTP:DirectX)
!        TP.Title = 'Tasks'
!        g = TP.AddGroup('Catalogs', 'table')
!        TP.AddItem(g, 'Customers', 'user', 'cust')
!        i = TP.AddItem(g, 'Geography', 'globe')       ! has children = a submenu
!        TP.AddItem(i, 'Countries', , 'countries')
!        TP.AddItem(i, 'Cities',    , 'cities')
!        TP.MirrorMenu()                       ! copy the window's MENUBAR in
!        TP.ShowPanel()
!    and in the ACCEPT loop:
!        OF MTP:Event                          ! posted when an item is clicked
!          LOOP WHILE TP.NextClick()
!            CASE TP.ClickTag
!            OF 'cust' ; START(BrowseCustomers, 25000)
!            END
!          END
!    A mirrored menu row needs no code: it POSTs EVENT:Accepted to the
!    original ITEM, so the menu's own embed code runs.
!
!  This file MUST be stored in ANSI with CRLF line endings.
! ============================================================================

  OMIT('_EndOfInclude_',_MyTaskPanelIncluded_)
_MyTaskPanelIncluded_ EQUATE(1)

MTP:Event            EQUATE(0400h + 0D7h)  ! EVENT:User + 215: an item was clicked
MTP:Drop             EQUATE(0400h + 0D9h)  ! EVENT:User + 217: files were dropped on an item (NextDrop)
MTP:Check            EQUATE(0400h + 0D8h)  ! EVENT:User + 216: the mouse came in or the panel took the
                                           ! focus - re-check conditions (the template's Show/Enable when)

MTP:Left             EQUATE(1)             ! dock sides
MTP:Right            EQUATE(2)
MTP:Float            EQUATE(3)

MTP:Clarion          EQUATE(0)             ! engines
MTP:DirectX          EQUATE(1)

MTP:Group            EQUATE(1)             ! row kinds
MTP:Item             EQUATE(2)
MTP:Separator        EQUATE(3)
MTP:Label            EQUATE(4)
MTP:Info             EQUATE(5)             ! a label and a value ("Orders today   34")
MTP:Progress         EQUATE(6)             ! a label and a bar, 0..100
MTP:Chart            EQUATE(7)             ! a label and a small chart of a series of numbers

MTP:Bars             EQUATE(0)             ! chart styles
MTP:Line             EQUATE(1)

MTP:Inline           EQUATE(0)             ! how submenus open
MTP:Flyout           EQUATE(1)

MTP:Slate            EQUATE(1)             ! themes
MTP:Navy             EQUATE(2)
MTP:Graphite         EQUATE(3)             ! dark
MTP:Teal             EQUATE(4)
MTP:Light            EQUATE(5)
MTP:Forest           EQUATE(6)
MTP:HighContrast     EQUATE(7)             ! black, white and yellow; strong borders
MTP:LowContrast      EQUATE(8)             ! soft greys
MTP:Ocean            EQUATE(9)
MTP:Crimson          EQUATE(10)
MTP:Amber            EQUATE(11)
MTP:Copper           EQUATE(12)
MTP:Sky              EQUATE(13)
MTP:Mint             EQUATE(14)
MTP:Steel            EQUATE(15)
MTP:Sand             EQUATE(16)
MTP:Midnight         EQUATE(17)            ! dark
MTP:Olive            EQUATE(18)

MTP:TileH            EQUATE(1)             ! MdiCommand()
MTP:TileV            EQUATE(2)
MTP:Cascade          EQUATE(3)
MTP:Arrange          EQUATE(4)

MTPItemQ             QUEUE,TYPE
Id                     LONG
Parent                 LONG                ! 0 = a group
Kind                   BYTE                ! MTP:Group / Item / Separator / Label
Text                   STRING(120)         ! as shown (no & accelerators)
Shortcut               STRING(32)
Glyph                  STRING(24)          ! a built-in vector icon name
IconFile               STRING(255)         ! or an .ico file / linked icon name
HIcon                  LONG
Tag                    STRING(64)          ! the developer's key for the item
Tip                    STRING(255)
Feq                    LONG                ! <> 0: a click POSTs EVENT:Accepted here
Mirrored               BYTE                ! copied from the MENUBAR
Expanded               BYTE
Enabled                BYTE
Hidden                 BYTE
Checked                BYTE
Bold                   BYTE
Special                BYTE                ! group drawn in the accent colour
Reveal                 REAL                ! 0..1 while the group/submenu animates
Badge                  STRING(16)          ! a count or word in a pill on the right; '*' = a dot
BadgeClr               LONG                ! COLOR:None = the accent colour
Match                  BYTE                ! matches the search text
Value                  STRING(64)          ! Info: the value; Progress: shown instead of "64%"; Chart: the headline
Pct                    REAL                ! Progress: 0..100
Series                 STRING(255)         ! Chart: '12,15,9,18'
Style                  BYTE                ! Chart: MTP:Bars / MTP:Line
Clickable              BYTE                ! Info/Progress/Chart rows only react when this is set
Role                   BYTE                ! 1 the Favourites group, 2 the Recent group, 3 a row in one of them
RefId                  LONG                ! Role 3: the item it stands for
UserHidden             BYTE                ! hidden by the user (Customize); Hidden is the program's
Uses                   LONG                ! times run - the Most used group
DropOk                 BYTE                ! accepts files dropped on it
                     END

MTPRowQ              QUEUE,TYPE            ! the layout: one row per thing drawn
Id                     LONG
Kind                   BYTE                ! MTP:Group = a group header
Y                      LONG
H                      LONG
Level                  BYTE
ClipT                  LONG                ! visible between ClipT and ClipB
ClipB                  LONG
BodyH                  LONG                ! group header: height of its card
HasKids                BYTE
                     END

MTPKidQ              QUEUE,TYPE            ! host windows we narrow (MDIClient, ClaChildClient)
Hwnd                   LONG
OldProc                LONG
L                      LONG                ! the rect the host asked for
T                      LONG
R                      LONG
B                      LONG
                     END

MTPClickQ            QUEUE,TYPE
Id                     LONG
Act                    LONG                ! <> 0: one of the item's hover buttons
                     END

MTPActQ              QUEUE,TYPE            ! hover buttons
Id                     LONG
ItemId                 LONG
Glyph                  STRING(24)
Tag                    STRING(64)
Tip                    STRING(120)
                     END

MTPDropQ             QUEUE,TYPE            ! files dropped, waiting for NextDrop
Id                     LONG
Files                  STRING(8000)        ! 'C:\a.txt|C:\b.pdf'
Count                  LONG
                     END

MTPIconQ             QUEUE,TYPE            ! icons waiting for the GDI pass (DirectX engine)
X                      LONG
Y                      LONG
Sz                     LONG
HIcon                  LONG
                     END

MyTaskPanelClass     CLASS,TYPE,MODULE('MyTaskPanel.clw'),LINK('MyTaskPanel.clw',_MyTaskPanelLinkMode_),DLL(_MyTaskPanelDllMode_)
! ---- settings (set before Show, or call Refresh after) ----
Engine                 BYTE                ! MTP:Clarion / MTP:DirectX (asked for)
Title                  STRING(80)
DockSide               BYTE                ! MTP:Left / Right / Float
PanelWidth             LONG                ! docked width in pixels
MinWidth               LONG
MaxWidth               LONG
SubStyle               BYTE                ! MTP:Inline / MTP:Flyout
ShowShortcuts          BYTE
Accordion              BYTE                ! opening a group closes the others
Animate                BYTE
AllowFloat             BYTE
AllowDock              BYTE
AllowClose             BYTE
AllowResize            BYTE
GrowHost               BYTE                ! WINDOW host: widen it by the panel
FontName               STRING(40)
FontSize               LONG
ItemHeight             LONG
HeaderHeight           LONG
Radius                 LONG
IniFile                STRING(260)         ! SaveState/LoadState; blank = off
IniSection             STRING(60)
Language               STRING(2)           ! EN / ES (the panel's own menu)
AutoGlyphs             BYTE                ! mirrored rows guess an icon from their text
Effects                BYTE                ! DirectX only: shadows, glass, fading translucent hover (default on)
FloatOpacity           BYTE                ! DirectX + Effects: a floating panel's opacity (%) while the mouse is away; 100 = solid
ShowEngine             BYTE                ! a small "DirectX" / "GDI" badge in the corner, to see which is painting
ShowSearch             BYTE                ! a search box under the title (default on)
Favorites              BYTE                ! right-click an item: Add to favourites (default on)
RecentMax              LONG                ! the Recent group keeps this many (default 5; 0 = no Recent group)
Rail                   BYTE                ! docked as a strip of group icons (SetRail to change it once shown)
AutoHide               BYTE                ! docked panel tucks into the edge and slides out (SetAutoHide)
MostMax                LONG                ! the Most used group keeps this many (default 5; 0 = none)
ShowTips               BYTE                ! the description card after a pause on an item with a Tip (default on)
! ---- the last hover button / drop (NextClick, NextDrop fill these) ----
ClickAct               LONG                ! <> 0: the click came from a hover button (ClickTag is its tag)
DropId                 LONG
DropTag                STRING(64)
DropText               STRING(120)
DropFiles              STRING(8000)        ! 'C:\a.txt|C:\b.pdf'
DropCount              LONG
! ---- colours (Clarion COLOR values; SetTheme fills them) ----
ClrBack                LONG
ClrTitle1              LONG
ClrTitle2              LONG
ClrTitleText           LONG
ClrHead1               LONG
ClrHead2               LONG
ClrHeadText            LONG
ClrSpecial1            LONG
ClrSpecial2            LONG
ClrSpecialText         LONG
ClrCard                LONG
ClrCardLine            LONG
ClrText                LONG
ClrTextDim             LONG
ClrHover               LONG
ClrHoverLine           LONG
ClrAccent              LONG
ClrDisabled            LONG
ClrSep                 LONG
! ---- the last click (NextClick fills these) ----
ClickId                LONG
ClickTag               STRING(64)
ClickText              STRING(120)
! ---- data ----
Items                  &MTPItemQ
Rows                   &MTPRowQ,PROTECTED
Kids                   &MTPKidQ,PROTECTED
Clicks                 &MTPClickQ,PROTECTED
Acts                   &MTPActQ,PROTECTED
Drops                  &MTPDropQ,PROTECTED
PendIcons              &MTPIconQ,PROTECTED
D2DFailed              BYTE,PROTECTED
Win                    &WINDOW,PROTECTED
HostHwnd               LONG,PROTECTED
HostThread             LONG,PROTECTED
IsFrame                BYTE,PROTECTED
DockHwnd               LONG,PROTECTED
FloatHwnd              LONG,PROTECTED
Visible                BYTE,PROTECTED
UseD2D                 BYTE,PROTECTED      ! the engine actually painting
NextId                 LONG,PROTECTED
Inited                 BYTE,PROTECTED
Dpi                    LONG,PROTECTED
DC                     LONG,PROTECTED      ! the DC being painted
FontN                  LONG,PROTECTED
FontB                  LONG,PROTECTED
FontT                  LONG,PROTECTED
FontS                  LONG,PROTECTED
CurFont                LONG,PROTECTED
Hover                  LONG,PROTECTED      ! row id under the mouse (-1 title, -2 menu btn, -3 close)
Pressed                LONG,PROTECTED
ScrollY                LONG,PROTECTED
ContentH               LONG,PROTECTED
ViewH                  LONG,PROTECTED
ViewW                  LONG,PROTECTED
Drag                   BYTE,PROTECTED      ! 1 splitter, 2 title (undock), 3 thumb
DragX                  LONG,PROTECTED
DragY                  LONG,PROTECTED
DragV                  LONG,PROTECTED
HostMenu               LONG,PROTECTED
HideMenu               BYTE,PROTECTED
MenuTicks              BYTE,PROTECTED
Animating              BYTE,PROTECTED
FloatX                 LONG,PROTECTED
FloatY                 LONG,PROTECTED
FloatW                 LONG,PROTECTED
FloatH                 LONG,PROTECTED
Grown                  LONG,PROTECTED
SnapSide               BYTE,PROTECTED
InHost                 BYTE,PROTECTED      ! the mouse is over the panel
Replaying              BYTE,PROTECTED      ! ApplyLayout is pushing the host's rects through
HoverT                 REAL,PROTECTED      ! 0..1: how far the hover highlight has faded in
FadeId                 LONG,PROTECTED      ! the row the mouse just left, fading out
FadeT                  REAL,PROTECTED
Fading                 BYTE,PROTECTED
Fx                     BYTE,PROTECTED      ! this frame draws the DirectX effects
BenchEmpty             BYTE,PROTECTED      ! Diag 3: Benchmark times empty frames
Search                 CSTRING(61),PROTECTED ! the search text; blank = everything shows
KeyId                  LONG,PROTECTED      ! the row the keyboard is on
HasFocus               BYTE,PROTECTED
PrevFocus              LONG,PROTECTED      ! where the focus goes back to (Esc, Tab)
CaretOn                BYTE,PROTECTED
FavGroup               LONG,PROTECTED
RecentGroup            LONG,PROTECTED
MenuId                 LONG,PROTECTED      ! the row right-clicked
InMenu                 BYTE,PROTECTED      ! a pop-up menu is open: do not tuck or close anything
PeekHwnd               LONG,PROTECTED      ! the rail's pop-out window
PeekId                 LONG,PROTECTED      ! the group it shows
Slide                  REAL,PROTECTED      ! auto-hide: 0 tucked .. 1 out
SlideTo                BYTE,PROTECTED
Sliding                BYTE,PROTECTED
MostGroup              LONG,PROTECTED
Customizing            BYTE,PROTECTED
GroupOrder             STRING(1000),PROTECTED  ! ',7,2,12,' - the user's group order
DragCand               LONG,PROTECTED      ! pressed on something that can be dragged
DropAt                 LONG,PROTECTED      ! drag: lands before this (0 = at the end)
DropY                  LONG,PROTECTED
TipHwnd                LONG,PROTECTED
TipId                  LONG,PROTECTED      ! shown
TipCand                LONG,PROTECTED      ! waiting for the pause
NextAct                LONG,PROTECTED
Dropping               BYTE,PROTECTED      ! some item takes files
TipTitle               STRING(120),PROTECTED
TipBody                STRING(255),PROTECTED
TipFoot                STRING(200),PROTECTED
! ---- life cycle ----
Construct              PROCEDURE
Destruct               PROCEDURE,VIRTUAL
Init                   PROCEDURE(WINDOW host, BYTE engine=0),BYTE,PROC,VIRTUAL
Kill                   PROCEDURE,VIRTUAL
ShowPanel              PROCEDURE,VIRTUAL
HidePanel              PROCEDURE,VIRTUAL
TogglePanel            PROCEDURE
IsVisible              PROCEDURE(),BYTE
Dock                   PROCEDURE(BYTE side),VIRTUAL
SetWidth               PROCEDURE(LONG px)
Refresh                PROCEDURE
EngineInUse            PROCEDURE(),BYTE    ! MTP:Clarion or MTP:DirectX
Benchmark              PROCEDURE(BYTE engine, LONG frames=200, BYTE effects=1),REAL  ! ms per frame; -1 = engine not available
! ---- keyboard and search ----
Focus                  PROCEDURE           ! move the keyboard into the panel (arrows, Enter, typing searches)
HasKeyboard            PROCEDURE(),BYTE
SetSearch              PROCEDURE(STRING txt)
GetSearch              PROCEDURE(),STRING
Diag                   PROCEDURE(LONG what, LONG value),LONG,PROC,PROTECTED  ! speed-test switches; returns the old value
SetTheme               PROCEDURE(LONG theme)
SetAccent              PROCEDURE(LONG clr)
SetLanguage            PROCEDURE(STRING lang)
! ---- building ----
AddGroup               PROCEDURE(STRING text, <STRING glyph>, BYTE expanded=1, BYTE special=0),LONG,PROC
AddItem                PROCEDURE(LONG pid, STRING text, <STRING glyph>, <STRING tag>, LONG feq=0),LONG,PROC
AddSeparator           PROCEDURE(LONG pid),LONG,PROC
AddLabel               PROCEDURE(LONG pid, STRING text),LONG,PROC
DeleteItem             PROCEDURE(LONG id)
ClearAll               PROCEDURE
MirrorMenu             PROCEDURE(BYTE hideMenu=0, <STRING skip>, BYTE oneGroup=0),LONG,PROC
SyncMirror             PROCEDURE
! ---- items ----
SetText                PROCEDURE(LONG id, STRING text)
SetGlyph               PROCEDURE(LONG id, STRING glyph)
SetIcon                PROCEDURE(LONG id, STRING iconFile)
SetShortcut            PROCEDURE(LONG id, STRING txt)
SetTip                 PROCEDURE(LONG id, STRING txt)
SetEnabled             PROCEDURE(LONG id, BYTE on)
SetHidden              PROCEDURE(LONG id, BYTE on)
SetChecked             PROCEDURE(LONG id, BYTE on)
SetBold                PROCEDURE(LONG id, BYTE on)
SetSpecial             PROCEDURE(LONG id, BYTE on)
SetBadge               PROCEDURE(LONG id, STRING txt, LONG clr=-1) ! '' removes it; '*' = a dot; -1 = accent
! ---- info cards ----
AddInfo                PROCEDURE(LONG pid, STRING label, STRING value, <STRING tag>),LONG,PROC
AddProgress            PROCEDURE(LONG pid, STRING label, REAL pct, <STRING tag>),LONG,PROC
AddChart               PROCEDURE(LONG pid, STRING label, STRING series, BYTE style=0, <STRING tag>),LONG,PROC
SetValue               PROCEDURE(LONG id, STRING value)
SetProgress            PROCEDURE(LONG id, REAL pct)
SetSeries              PROCEDURE(LONG id, STRING series)
SetClickable           PROCEDURE(LONG id, BYTE on=1)     ! an info row that raises a click like an item
! ---- favourites and recent ----
AddFavorite            PROCEDURE(LONG id)
RemoveFavorite         PROCEDURE(LONG id)
IsFavorite             PROCEDURE(LONG id),BYTE
ClearRecent            PROCEDURE
! ---- rail and auto-hide ----
SetRail                PROCEDURE(BYTE on)
! ---- the user's own panel ----
Customize              PROCEDURE(BYTE on=1)       ! the panel's edit mode: eye toggles, Reset, Done
IsCustomizing          PROCEDURE(),BYTE
HideItem               PROCEDURE(LONG id, BYTE on=1)   ! as the user hides it (kept in the INI)
ResetCustom            PROCEDURE                  ! everything shown, the program's order
MoveGroup              PROCEDURE(LONG id, LONG beforeId)  ! 0 = to the end
! ---- hover buttons, file drops ----
AddAction              PROCEDURE(LONG id, STRING glyph, STRING tag, <STRING tip>),LONG,PROC
ClearActions           PROCEDURE(LONG id)
SetDropTarget          PROCEDURE(LONG id, BYTE on=1)
NextDrop               PROCEDURE(),BYTE
DropFile               PROCEDURE(LONG n),STRING   ! the n-th file of the last drop
SetAutoHide            PROCEDURE(BYTE on)
GetBadge               PROCEDURE(LONG id),STRING
SetFeq                 PROCEDURE(LONG id, LONG feq)
Expand                 PROCEDURE(LONG id, BYTE on=1)
ExpandAll              PROCEDURE(BYTE on=1)
IsExpanded             PROCEDURE(LONG id),BYTE
FindTag                PROCEDURE(STRING tag),LONG
FindText               PROCEDURE(STRING text, LONG pid=-1),LONG
ItemCount              PROCEDURE(),LONG
! ---- clicks ----
NextClick              PROCEDURE(),BYTE
TakeItem               PROCEDURE(LONG id, STRING tag),VIRTUAL
Click                  PROCEDURE(LONG id)  ! as if the user had clicked it
! ---- helpers ----
OpenUrl                PROCEDURE(STRING url)
MdiCommand             PROCEDURE(LONG cmd)
SaveState              PROCEDURE
LoadState              PROCEDURE
IniName                PROCEDURE(),STRING,PROTECTED
! ---- inside the panel (called by the window procedure) ----
WndMsg                 PROCEDURE(LONG hwnd, LONG msg, LONG wp, LONG lp, *BYTE handled),LONG,PROTECTED
KidPosChanging         PROCEDURE(LONG hwnd, LONG lp),PROTECTED
ForgetKid              PROCEDURE(LONG hwnd),PROTECTED
Paint                  PROCEDURE(LONG hwnd),PROTECTED
Render                 PROCEDURE(LONG w, LONG h, BYTE floating),VIRTUAL,PROTECTED
DrawGroup              PROCEDURE(LONG w, BYTE floating),PROTECTED
DrawRow                PROCEDURE(LONG w),PROTECTED
DrawGlyph              PROCEDURE(STRING glyph, REAL x, REAL y, REAL sz, LONG clr),VIRTUAL,PROTECTED
Layout                 PROCEDURE(LONG w, LONG h, BYTE floating),PROTECTED
AddRows                PROCEDURE(LONG pid, LONG level, *LONG y, LONG clipT, LONG clipB),PROTECTED
KidsHeight             PROCEDURE(LONG pid),LONG,PROTECTED
HasKids                PROCEDURE(LONG id),BYTE,PROTECTED
HitTest                PROCEDURE(LONG x, LONG y, BYTE floating),LONG,PROTECTED
OnClickRow             PROCEDURE(LONG id, LONG hwnd),PROTECTED
OptionsMenu            PROCEDURE(LONG hwnd),PROTECTED
FlyoutMenu             PROCEDURE(LONG id, LONG hwnd),PROTECTED
BuildMenu              PROCEDURE(LONG pid),LONG,PROTECTED
MirrorInto             PROCEDURE(LONG pid, SIGNED menuFeq),PROTECTED
MenuRank               PROCEDURE(SIGNED feq),LONG,PROTECTED
MinFeqIn               PROCEDURE(SIGNED menuFeq),LONG,PROTECTED
FindMenuBar            PROCEDURE(),SIGNED,PROTECTED
KeyText                PROCEDURE(LONG keycode),STRING,PROTECTED
GuessGlyph             PROCEDURE(STRING txt),STRING
CleanText              PROCEDURE(STRING txt),STRING,PROTECTED
MakeWindows            PROCEDURE,PROTECTED
ApplyLayout            PROCEDURE,PROTECTED
HookKids               PROCEDURE,PROTECTED
UnhookKids             PROCEDURE,PROTECTED
PlaceDocked            PROCEDURE,PROTECTED
ReserveW               PROCEDURE(),LONG,PROTECTED
Invalidate             PROCEDURE,PROTECTED
StartAnim              PROCEDURE,PROTECTED
StepAnim               PROCEDURE,PROTECTED
SetHover               PROCEDURE(LONG id),PROTECTED
HoverAmt               PROCEDURE(LONG id),REAL,PROTECTED
StepFade               PROCEDURE,PROTECTED
FxWanted               PROCEDURE(),BYTE,PROTECTED          ! DirectX painting + Effects on
SetFloatAlpha          PROCEDURE(BYTE over),PROTECTED
DrawBadge              PROCEDURE(LONG w, LONG h, LONG sbw),PROTECTED
DrawTitleBtn           PROCEDURE(LONG id, LONG btx, LONG bty, LONG bs),PROTECTED
DrawSearch             PROCEDURE(LONG w, BYTE floating),PROTECTED
DrawPill               PROCEDURE(REAL right, REAL cy, STRING txt, LONG clr, LONG textClr),LONG,PROC,PROTECTED ! returns its width
TitleH                 PROCEDURE(BYTE floating),LONG,PROTECTED  ! the title strip
ContentTop             PROCEDURE(BYTE floating),LONG,PROTECTED  ! where the groups start (under the search box)
TextW                  PROCEDURE(STRING txt, BYTE font),LONG,PROTECTED
KeyDown                PROCEDURE(LONG hwnd, LONG vk),BYTE,PROC,PROTECTED
KeyChar                PROCEDURE(LONG ch),PROTECTED
MoveKey                PROCEDURE(LONG steps),PROTECTED
EnsureVisible          PROCEDURE(LONG id),PROTECTED
LeaveFocus             PROCEDURE,PROTECTED
CurHwnd                PROCEDURE(),LONG,PROTECTED
UpdateMatches          PROCEDURE,PROTECTED
Fold                   PROCEDURE(STRING txt),STRING,PROTECTED  ! upper case, accents off: 'Código' = 'CODIGO'
CountMatches           PROCEDURE(LONG pid),LONG,PROTECTED
SearchRows             PROCEDURE(LONG pid, *LONG y, LONG clipT, LONG clipB),PROTECTED
PathOf                 PROCEDURE(LONG id),STRING,PROTECTED     ! "Browse > Geography" above an item
DrawInfo               PROCEDURE(LONG x, LONG y, LONG cw, LONG rh, LONG tx, LONG right),PROTECTED
NewRow                 PROCEDURE(LONG pid, BYTE kind, STRING label, <STRING tag>),LONG,PROTECTED
Resolve                PROCEDURE(LONG id),LONG,PROTECTED       ! a Favourites/Recent row -> the item it stands for
IsAction               PROCEDURE(LONG id),BYTE,PROTECTED       ! an item with no submenu
RefOk                  PROCEDURE(LONG refId),BYTE,PROTECTED
RoleGroup              PROCEDURE(BYTE role),LONG,PROTECTED
RefList                PROCEDURE(BYTE role),STRING,PROTECTED   ! ',12,15,' - the items the role group shows
SetRefs                PROCEDURE(BYTE role, STRING list),PROTECTED
PushRecent             PROCEDURE(LONG id),PROTECTED
ItemKey                PROCEDURE(LONG id),STRING,PROTECTED     ! tag, or the path of texts - for the INI
FindKey                PROCEDURE(STRING key),LONG,PROTECTED
ListKeys               PROCEDURE(STRING list),STRING,PROTECTED ! ',12,15,' -> 'T:cust|P:Menu/Browse/Countries'
KeyList                PROCEDURE(STRING keys),STRING,PROTECTED ! and back
KindOf                 PROCEDURE(LONG hwnd),BYTE,PROTECTED     ! 0 docked, 1 floating, 2 the rail's pop-out
HwndOf                 PROCEDURE(BYTE kind),LONG,PROTECTED
GroupAt                PROCEDURE(LONG k),LONG,PROTECTED        ! the k-th group shown, in display order
RailW                  PROCEDURE(),LONG,PROTECTED
RenderRail             PROCEDURE(LONG w, LONG h),PROTECTED
RailHit                PROCEDURE(LONG x, LONG y),LONG,PROTECTED
ShowPeek               PROCEDURE(LONG gid),PROTECTED
HidePeek               PROCEDURE,PROTECTED
PeekCheck              PROCEDURE,PROTECTED
StartSlide             PROCEDURE(BYTE out),PROTECTED
StepSlide              PROCEDURE,PROTECTED
Gone                   PROCEDURE(),BYTE,PROTECTED          ! the current item is not shown
RoleGid                PROCEDURE(BYTE role),LONG,PROTECTED
GroupList              PROCEDURE(BYTE all=0),STRING,PROTECTED ! ',id,id,' - the groups shown, in order (all: every ordinary group)
RebuildMost            PROCEDURE,PROTECTED
DragOver               PROCEDURE(LONG y),PROTECTED
DropDrag               PROCEDURE,PROTECTED
ActItem                PROCEDURE(LONG code),LONG,PROTECTED ! a hover button's hit code -> its item
ActCount               PROCEDURE(LONG id),LONG,PROTECTED
DrawActs               PROCEDURE(LONG id, LONG right, LONG y, LONG rh),LONG,PROTECTED
ActHit                 PROCEDURE(LONG id, LONG x, LONG right),LONG,PROTECTED
ShowTip                PROCEDURE(LONG id, LONG hwnd),PROTECTED
HideTip                PROCEDURE,PROTECTED
RenderTip              PROCEDURE(LONG w, LONG h),PROTECTED
TipBodyH               PROCEDURE(STRING txt, LONG w),LONG,PROTECTED
PTextWrap              PROCEDURE(REAL x, REAL y, REAL w, REAL h, STRING txt, LONG clr),PROTECTED   ! GDI only
TakeDrop               PROCEDURE(LONG hwnd, LONG hDrop),PROTECTED
AcceptDrops            PROCEDURE,PROTECTED
ActClick               PROCEDURE(LONG code),PROTECTED
DrawEye                PROCEDURE(REAL cx, REAL cy, BYTE on, LONG clr),PROTECTED
Alpha                  PROCEDURE(LONG clr, REAL a),LONG,PROTECTED
CheckSnap              PROCEDURE(BYTE final),PROTECTED
UndockAtCursor         PROCEDURE,PROTECTED
Txt                    PROCEDURE(STRING en, STRING es),STRING,PROTECTED
Px                     PROCEDURE(REAL n),LONG,PROTECTED    ! scale for DPI
Rgb                    PROCEDURE(LONG clr),LONG,PROTECTED  ! system colours resolved
Argb                   PROCEDURE(LONG clr),LONG,PROTECTED
Mix                    PROCEDURE(LONG c1, LONG c2, REAL t),LONG
MakeFonts              PROCEDURE,PROTECTED
FreeFonts              PROCEDURE,PROTECTED
LoadIcon               PROCEDURE(),PROTECTED               ! for the current Items record
! ---- the painter: GDI or Direct2D ----
PFill                  PROCEDURE(REAL x, REAL y, REAL w, REAL h, LONG clr),PROTECTED
PRound                 PROCEDURE(REAL x, REAL y, REAL w, REAL h, REAL r, LONG fill, LONG line=-1),PROTECTED
PGrad                  PROCEDURE(REAL x, REAL y, REAL w, REAL h, REAL r, LONG c1, LONG c2),PROTECTED
PLine                  PROCEDURE(REAL x1, REAL y1, REAL x2, REAL y2, LONG clr, REAL lw=1),PROTECTED
PEllipse               PROCEDURE(REAL cx, REAL cy, REAL rx, REAL ry, LONG fill, LONG line=-1, REAL lw=1),PROTECTED
PText                  PROCEDURE(REAL x, REAL y, REAL w, REAL h, STRING txt, LONG clr, BYTE font=0, BYTE align=0),PROTECTED
PClip                  PROCEDURE(REAL x, REAL y, REAL w, REAL h),PROTECTED
PUnclip                PROCEDURE,PROTECTED
PIcon                  PROCEDURE(LONG hIcon, REAL x, REAL y, REAL sz),PROTECTED
                     END

  _EndOfInclude_
