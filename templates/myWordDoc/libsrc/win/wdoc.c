/* ============================================================================
 *  wdoc.c - myWordDoc: a word-processing control for Clarion, with NO COM.
 *
 *  WHAT THIS IS
 *  ------------
 *  Our own control. It registers its own window class ("myWordDocHost") whose
 *  window procedure lives in this file, and that host owns everything the user
 *  sees: a toolbar it paints itself (font, size, bold/italic/underline/strike,
 *  text colour, highlight, alignment, bullets, numbering, indent, picture,
 *  table, undo/redo), an optional "page view" that shows the document at its
 *  printed width on a grey desk, and the editing surface.
 *
 *  The editing surface is the Windows text engine - RICHEDIT50W in msftedit.dll,
 *  the engine behind WordPad - used as a component: it does the typing, line
 *  breaking, selection, undo, clipboard, accents/IME and the RTF format. The
 *  host is its PARENT, so its WM_NOTIFY / WM_COMMAND notifications come to OUR
 *  window procedure. The Clarion window is never subclassed.
 *
 *  STORAGE: the document is RTF (Word opens it). The Clarion class streams it
 *  into and out of a BLOB through wdoc_load / wdoc_save / wdoc_copy.
 *
 *  PRINTING: wdoc_paginate splits the document into pages (or band-sized
 *  chunks) of any size in twips, and wdoc_render_page draws one of them into an
 *  enhanced metafile. A Clarion report IMAGE pointing at that .emf plays its
 *  records straight into the page, so the text stays vector (sharp, small PDFs).
 *  A control created with no parent window is an invisible document - that is
 *  how a REPORT procedure renders a BLOB it never showed on screen.
 *
 *  TOOLS (the end of this file, used by WordDocTools.clw): search / replace /
 *  highlight, character runs and the fonts in use, plain text and counts, and
 *  HTML / Markdown export. They walk the RichEdit document itself, on a live
 *  editor or a hidden one, and put the user's selection back when they finish.
 *
 *  Everything is bound at run time with LoadLibrary/GetProcAddress, so there is
 *  no import library. Compiled into the exe by Clacpp via PRAGMA('compile(wdoc.c)').
 *
 *  ABI: ints by value, strings/buffers as char* (RAW). Results come back one
 *  value at a time through getters - no structs cross into Clarion.
 *  WINAPI == Clacpp 'pascal' == __stdcall. Win32 (32-bit) target.
 * ========================================================================== */

#define WINAPI pascal

typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef unsigned short WORD;
typedef unsigned short WCHAR;
typedef unsigned char  BYTE;
typedef int            BOOL;
typedef void*          HMODULE;
typedef void*          HANDLE;
typedef int (WINAPI *FARPROC)();

/* ---- window styles ---- */
#define WS_CHILD          0x40000000
#define WS_VISIBLE        0x10000000
#define WS_POPUP          0x80000000
#define WS_VSCROLL        0x00200000
#define WS_HSCROLL        0x00100000
#define WS_TABSTOP        0x00010000
#define WS_CLIPCHILDREN   0x02000000
#define WS_CLIPSIBLINGS   0x04000000
#define CBS_DROPDOWNLIST  0x0003
#define CBS_SORT          0x0100
#define CBS_HASSTRINGS    0x0200

/* ---- edit / richedit styles ---- */
#define ES_MULTILINE      0x0004
#define ES_AUTOVSCROLL    0x0040
#define ES_NOHIDESEL      0x0100
#define ES_WANTRETURN     0x1000
#define ES_SAVESEL        0x8000

/* ---- messages ---- */
#define WM_DESTROY        0x0002
#define WM_SIZE           0x0005
#define WM_SETFOCUS       0x0007
#define WM_PAINT          0x000F
#define WM_ERASEBKGND     0x0014
#define WM_SETFONT        0x0030
#define WM_NOTIFY         0x004E
#define WM_KEYDOWN        0x0100
#define WM_CHAR           0x0102
#define WM_COMMAND        0x0111
#define WM_GETDLGCODE     0x0087
#define WM_MOUSEMOVE      0x0200
#define WM_LBUTTONDOWN    0x0201
#define WM_LBUTTONUP      0x0202
#define WM_MOUSELEAVE     0x02A3
#define WM_CUT            0x0300
#define WM_COPY           0x0301
#define WM_PASTE          0x0302
#define WM_CLEAR          0x0303
#define WM_UNDO           0x0304
#define WM_USER           0x0400

#define EM_GETSEL         0x00B0
#define EM_SETSEL         0x00B1
#define EM_GETMODIFY      0x00B8
#define EM_SETMODIFY      0x00B9
#define EM_REPLACESEL     0x00C2
#define EM_SETREADONLY    0x00CF
#define EM_SETMARGINS     0x00D3
#define EM_EXGETSEL       (WM_USER + 52)
#define EM_EXLIMITTEXT    (WM_USER + 53)
#define EM_EXSETSEL       (WM_USER + 55)
#define EM_FORMATRANGE    (WM_USER + 57)
#define EM_GETCHARFORMAT  (WM_USER + 58)
#define EM_GETPARAFORMAT  (WM_USER + 61)
#define EM_SETBKGNDCOLOR  (WM_USER + 67)
#define EM_SETCHARFORMAT  (WM_USER + 68)
#define EM_SETEVENTMASK   (WM_USER + 69)
#define EM_SETOLECALLBACK (WM_USER + 70)
#define EM_GETOLEINTERFACE (WM_USER + 60)
#define EM_SETUNDOLIMIT   (WM_USER + 82)
#define EM_EMPTYUNDOBUFFER 0x00CD
#define EM_SETPARAFORMAT  (WM_USER + 71)
#define EM_SETTARGETDEVICE (WM_USER + 72)
#define EM_STREAMIN       (WM_USER + 73)
#define EM_STREAMOUT      (WM_USER + 74)
#define EM_FINDTEXTEXW    (WM_USER + 124)   /* RICHEDIT50W is Unicode: search with W text */
#define EM_REDO           (WM_USER + 84)
#define EM_CANUNDO        0x00C6
#define EM_UNDO           0x00C7
#define EM_CANREDO        (WM_USER + 85)
#define EM_GETTEXTLENGTHEX (WM_USER + 95)
#define EM_SETZOOM        (WM_USER + 225)
#define EM_GETTEXTEX      (WM_USER + 94)
#define EM_GETSCROLLPOS   (WM_USER + 221)
#define EM_SETSCROLLPOS   (WM_USER + 222)
#define EM_SCROLLCARET    0x00B7
#define WM_SETREDRAW      0x000B

#define CB_ADDSTRING      0x0143
#define CB_GETCURSEL      0x0147
#define CB_GETLBTEXT      0x0148
#define CB_RESETCONTENT   0x014B
#define CB_FINDSTRINGEXACT 0x0158
#define CB_SETCURSEL      0x014E
#define CB_SETDROPPEDWIDTH 0x0160
#define CBN_SELCHANGE     1
#define CBN_CLOSEUP       8
#define EN_CHANGE         0x0300
#define EN_SELCHANGE      0x0702

#define ENM_CHANGE        0x00000001
#define ENM_SELCHANGE     0x00080000

#define SF_TEXT           0x0001
#define SF_RTF            0x0002
#define SFF_SELECTION     0x8000
#define SCF_SELECTION     0x0001
#define SCF_ALL           0x0004
#define GTL_PRECISE       2
#define GTL_NUMCHARS      8

/* CHARFORMAT masks / effects */
#define CFM_BOLD          0x00000001
#define CFM_ITALIC        0x00000002
#define CFM_UNDERLINE     0x00000004
#define CFM_STRIKEOUT     0x00000008
#define CFM_SIZE          0x80000000
#define CFM_COLOR         0x40000000
#define CFM_FACE          0x20000000
#define CFM_CHARSET       0x08000000
#define CFM_BACKCOLOR     0x04000000
#define CFE_AUTOCOLOR     0x40000000
#define CFE_AUTOBACKCOLOR 0x04000000
#define CFM_SUBSCRIPT     0x00030000
#define CFE_SUBSCRIPT     0x00010000
#define CFE_SUPERSCRIPT   0x00020000

/* PARAFORMAT masks */
#define PFM_STARTINDENT   0x00000001
#define PFM_OFFSET        0x00000004
#define PFM_ALIGNMENT     0x00000008
#define PFM_NUMBERING     0x00000020
#define PFM_OFFSETINDENT  0x80000000
#define PFM_NUMBERINGSTYLE 0x00002000
#define PFM_NUMBERINGTAB  0x00004000
#define PFM_NUMBERINGSTART 0x00008000

#define FR_DOWN           0x00000001
#define FR_WHOLEWORD      0x00000002
#define FR_MATCHCASE      0x00000004

#define EC_LEFTMARGIN     0x0001
#define EC_RIGHTMARGIN    0x0002

#define SWP_NOSIZE        0x0001
#define SWP_NOMOVE        0x0002
#define SWP_NOZORDER      0x0004
#define SWP_NOACTIVATE    0x0010
#define SWP_FRAMECHANGED  0x0020
#define SWP_SHOWWINDOW    0x0040
#define GWL_STYLE         (-16)
#define LOGPIXELSX        88
#define LOGPIXELSY        90
#define TRANSPARENT       1
#define PS_SOLID          0
#define DT_CENTER         0x0001
#define DT_VCENTER        0x0004
#define DT_SINGLELINE     0x0020
#define DT_NOPREFIX       0x0800
#define TME_LEAVE         0x00000002
#define CC_RGBINIT        0x00000001
#define CC_FULLOPEN       0x00000002
#define OFN_FILEMUSTEXIST 0x00001000
#define OFN_PATHMUSTEXIST 0x00000800
#define OFN_HIDEREADONLY  0x00000004
#define OFN_NOCHANGEDIR   0x00000008
#define TPM_RETURNCMD     0x0100
#define TPM_LEFTALIGN     0x0000
#define MF_STRING         0x0000
#define MF_SEPARATOR      0x0800
#define GENERIC_READ      0x80000000
#define GENERIC_WRITE     0x40000000
#define OPEN_EXISTING     3
#define CREATE_ALWAYS     2
#define FILE_SHARE_READ   1
#define DEFAULT_CHARSET   1
#define IDC_ARROW         32512
#define IDC_HAND          32649

#define WD_MAX       32
#define TB_ROWH      30     /* one toolbar row, in 96-dpi pixels */
#define TB_BTN       26     /* button square */
#define TB_GAP       2
#define ID_EDIT      100
#define ID_FONT      101
#define ID_SIZE      102

/* create() flags - must match WD:Flag* in WordDocClass.inc */
#define WDF_TOOLBAR   0x0001
#define WDF_READONLY  0x0002
#define WDF_PAGEVIEW  0x0004
#define WDF_NOBORDER  0x0008

/* palette (COLORREF is 0x00BBGGRR) - neutral slate with a blue accent */
#define C_BAR      0x00F6F4F3   /* toolbar background  #F3F4F6 */
#define C_BARLINE  0x00DBD5D1   /* separators/border   #D1D5DB */
#define C_HOVER    0x00EBE7E5   /* hover               #E5E7EB */
#define C_ON       0x00FEEADB   /* pressed fill        #DBEAFE */
#define C_ONLINE   0x00F6823B   /* pressed edge        #3B82F6 */
#define C_INK      0x00372D1F   /* glyph ink           #1F2D37 */
#define C_DIM      0x00AFA39C   /* disabled ink        #9CA3AF */
#define C_DESK     0x00E1DCD8   /* page-view desk      #D8DCE1 */
#define C_FRAME    0x00E1D5CB   /* outer frame         #CBD5E1 */

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);

/* ---- plain value structs (must match the Win32 layout exactly) ---------- */
typedef struct { long left, top, right, bottom; } RECT;
typedef struct { long x, y; } POINT;
typedef struct { long cpMin, cpMax; } CHARRANGE;
typedef struct { void* hwndFrom; UINT idFrom; UINT code; } NMHDR;
typedef struct { NMHDR nmhdr; CHARRANGE chrg; WORD seltyp; } SELCHANGE;
typedef struct { void* hdc; void* hdcTarget; RECT rc; RECT rcPage; CHARRANGE chrg; } FORMATRANGE;
typedef struct { DWORD flags; UINT codepage; } GETTEXTLENGTHEX;
typedef struct { DWORD cb; DWORD flags; UINT codepage; const char* lpDefaultChar; int* lpUsedDefChar; } GETTEXTEX;
typedef struct { CHARRANGE chrg; const WCHAR* lpstrText; CHARRANGE chrgText; } FINDTEXTEXW;
typedef DWORD (WINAPI *EDITSTREAMCALLBACK)(DWORD, BYTE*, long, long*);
typedef struct { DWORD dwCookie; DWORD dwError; EDITSTREAMCALLBACK pfnCallback; } EDITSTREAM;

/* CHARFORMAT2A - 84 bytes. Clacpp packs structs on 2-byte boundaries, so the
   hole Win32 leaves before crBackColor (offset 62 -> 64) is spelled out. */
typedef struct {
    UINT  cbSize; DWORD dwMask; DWORD dwEffects; long yHeight; long yOffset;
    DWORD crTextColor; BYTE bCharSet; BYTE bPitchAndFamily; char szFaceName[32];
    WORD  wWeight; short sSpacing; WORD wPad; DWORD crBackColor; DWORD lcid; DWORD dwReserved;
    short sStyle; WORD wKerning; BYTE bUnderlineType, bAnimation, bRevAuthor, bUnderlineColor;
} CF2A;

/* PARAFORMAT2 - 188 bytes */
typedef struct {
    UINT  cbSize; DWORD dwMask; WORD wNumbering; WORD wEffects;
    long  dxStartIndent; long dxRightIndent; long dxOffset; WORD wAlignment; short cTabCount;
    long  rgxTabs[32];
    long  dySpaceBefore; long dySpaceAfter; long dyLineSpacing; short sStyle;
    BYTE  bLineSpacingRule; BYTE bOutlineLevel; WORD wShadingWeight; WORD wShadingStyle;
    WORD  wNumberingStart; WORD wNumberingStyle; WORD wNumberingTab;
    WORD  wBorderSpace; WORD wBorderWidth; WORD wBorders;
} PF2;

typedef long (WINAPI *WNDPROC)(void*, UINT, unsigned long, unsigned long);
typedef struct {
    UINT style; WNDPROC lpfnWndProc; int cbClsExtra; int cbWndExtra; void* hInstance;
    void* hIcon; void* hCursor; void* hbrBackground; const char* lpszMenuName; const char* lpszClassName;
} WNDCLASSA;
typedef struct { void* hdc; BOOL fErase; RECT rc; BOOL fRestore; BOOL fIncUpdate; BYTE rgb[32]; } PAINTSTRUCT;
typedef struct { DWORD cbSize; DWORD dwFlags; void* hwndTrack; DWORD dwHoverTime; } TRACKMOUSEEVENT;
typedef struct {
    DWORD lStructSize; void* hwndOwner; void* hInstance; DWORD rgbResult; DWORD* lpCustColors;
    DWORD Flags; long lCustData; void* lpfnHook; const char* lpTemplateName;
} CHOOSECOLORA;
typedef struct {
    DWORD lStructSize; void* hwndOwner; void* hInstance; const char* lpstrFilter;
    char* lpstrCustomFilter; DWORD nMaxCustFilter; DWORD nFilterIndex; char* lpstrFile;
    DWORD nMaxFile; char* lpstrFileTitle; DWORD nMaxFileTitle; const char* lpstrInitialDir;
    const char* lpstrTitle; DWORD Flags; WORD nFileOffset; WORD nFileExtension;
    const char* lpstrDefExt; long lCustData; void* lpfnHook; const char* lpTemplateName;
} OPENFILENAMEA;
typedef struct {
    long lfHeight, lfWidth, lfEscapement, lfOrientation, lfWeight;
    BYTE lfItalic, lfUnderline, lfStrikeOut, lfCharSet, lfOutPrecision, lfClipPrecision,
         lfQuality, lfPitchAndFamily;
    char lfFaceName[32];
} LOGFONTA;
typedef int (WINAPI *FONTENUMPROCA)(const LOGFONTA*, const void*, DWORD, long);

/* ---- dynamically bound entry points ------------------------------------- */
#define FN(ret, name, args) typedef ret (WINAPI *PFN_##name) args; static PFN_##name p_##name = 0;
FN(void*, CreateWindowExA, (DWORD, const char*, const char*, DWORD, int, int, int, int, void*, void*, void*, void*))
FN(long,  SendMessageA,   (void*, UINT, unsigned long, unsigned long))
FN(long,  DefWindowProcA, (void*, UINT, unsigned long, unsigned long))
FN(WORD,  RegisterClassA, (const WNDCLASSA*))
FN(int,   DestroyWindow,  (void*))
FN(int,   SetWindowPos,   (void*, void*, int, int, int, int, UINT))
FN(int,   MoveWindow,     (void*, int, int, int, int, int))
FN(int,   ShowWindow,     (void*, int))
FN(void*, SetFocus,       (void*))
FN(void*, GetFocus,       (void))
FN(int,   IsChild,        (void*, void*))
FN(int,   EnableWindow,   (void*, int))
FN(int,   InvalidateRect, (void*, const RECT*, int))
FN(int,   GetClientRect,  (void*, RECT*))
FN(long,  GetWindowLongA, (void*, int))
FN(long,  SetWindowLongA, (void*, int, long))
FN(void*, GetParent,      (void*))
FN(void*, BeginPaint,     (void*, PAINTSTRUCT*))
FN(int,   EndPaint,       (void*, const PAINTSTRUCT*))
FN(void*, GetDC,          (void*))
FN(int,   ReleaseDC,      (void*, void*))
FN(int,   FillRect,       (void*, const RECT*, void*))
FN(int,   DrawTextA,      (void*, const char*, int, RECT*, UINT))
FN(void*, LoadCursorA,    (void*, const char*))
FN(void*, SetCursor,      (void*))
FN(int,   TrackMouseEvent,(TRACKMOUSEEVENT*))
FN(int,   ClientToScreen, (void*, POINT*))
FN(void*, CreatePopupMenu,(void))
FN(int,   AppendMenuA,    (void*, UINT, UINT, const char*))
FN(int,   TrackPopupMenu, (void*, UINT, int, int, int, void*, const RECT*))
FN(int,   DestroyMenu,    (void*))
FN(void*, GetModuleHandleA, (const char*))
FN(int,   GetDeviceCaps,  (void*, int))
FN(void*, CreateFontA,    (int, int, int, int, int, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, const char*))
FN(void*, CreateSolidBrush, (DWORD))
FN(void*, CreatePen,      (int, int, DWORD))
FN(void*, SelectObject,   (void*, void*))
FN(int,   DeleteObject,   (void*))
FN(DWORD, SetTextColor,   (void*, DWORD))
FN(int,   SetBkMode,      (void*, int))
FN(int,   MoveToEx,       (void*, int, int, POINT*))
FN(int,   LineTo,         (void*, int, int))
FN(int,   Rectangle,      (void*, int, int, int, int))
FN(int,   Ellipse,        (void*, int, int, int, int))
FN(int,   Polygon,        (void*, const POINT*, int))
FN(int,   TextOutW,       (void*, int, int, const WCHAR*, int))
FN(void*, CreateCompatibleDC, (void*))
FN(void*, CreateCompatibleBitmap, (void*, int, int))
FN(int,   BitBlt,         (void*, int, int, int, int, void*, int, int, DWORD))
FN(int,   DeleteDC,       (void*))
FN(void*, CreateDCA,      (const char*, const char*, const char*, void*))
FN(void*, CreateEnhMetaFileA, (void*, const char*, const RECT*, const char*))
FN(void*, CloseEnhMetaFile, (void*))
FN(int,   DeleteEnhMetaFile, (void*))
FN(UINT,  GetWinMetaFileBits, (void*, UINT, BYTE*, int, void*))
FN(void*, CreateICA,      (const char*, const char*, const char*, void*))
FN(UINT,  GetEnhMetaFileBits, (void*, UINT, BYTE*))
FN(void*, SetEnhMetaFileBits, (UINT, const BYTE*))
FN(int,   GetDefaultPrinterA, (char*, DWORD*))
FN(int,   EnumFontFamiliesExA, (void*, LOGFONTA*, FONTENUMPROCA, long, DWORD))
FN(int,   SetMapMode,     (void*, int))
FN(int,   ChooseColorA,   (CHOOSECOLORA*))
FN(int,   GetOpenFileNameA, (OPENFILENAMEA*))
FN(void*, CreateFileA,    (const char*, DWORD, DWORD, void*, DWORD, DWORD, void*))
FN(int,   ReadFile,       (void*, void*, DWORD, DWORD*, void*))
FN(int,   WriteFile,      (void*, const void*, DWORD, DWORD*, void*))
FN(DWORD, GetFileSize,    (void*, DWORD*))
FN(int,   CloseHandle,    (void*))
FN(void*, GetProcessHeap, (void))
FN(void*, HeapAlloc,      (void*, DWORD, DWORD))
FN(void*, HeapReAlloc,    (void*, DWORD, void*, DWORD))
FN(int,   HeapFree,       (void*, DWORD, void*))
FN(long,  OleInitialize,  (void*))
FN(long,  CreateILockBytesOnHGlobal, (void*, BOOL, void**))
FN(long,  StgCreateDocfileOnILockBytes, (void*, DWORD, DWORD, void**))
FN(int,   MultiByteToWideChar, (UINT, DWORD, const char*, int, WCHAR*, int))
FN(DWORD, GetTempPathA,   (DWORD, char*))
FN(DWORD, GetCurrentProcessId, (void))
FN(int,   DeleteFileA,    (const char*))
FN(long,  SendMessageW,   (void*, UINT, unsigned long, unsigned long))
FN(int,   WideCharToMultiByte, (UINT, DWORD, const WCHAR*, int, char*, int, const char*, int*))
FN(void*, CreateDIBSection, (void*, const void*, UINT, void**, void*, DWORD))
FN(int,   PatBlt,         (void*, int, int, int, int, DWORD))
FN(int,   PlayEnhMetaFile, (void*, void*, const RECT*))
FN(void*, SetWinMetaFileBits, (UINT, const BYTE*, void*, const void*))
FN(int,   StretchDIBits,  (void*, int, int, int, int, int, int, int, int, const void*, const void*, UINT, DWORD))
FN(int,   SetStretchBltMode, (void*, int))

/* ---- toolbar buttons ---------------------------------------------------- */
enum {
    B_NONE = 0, B_BOLD, B_ITALIC, B_UNDER, B_STRIKE, B_COLOR, B_HILITE,
    B_LEFT, B_CENTER, B_RIGHT, B_JUSTIFY, B_BULLETS, B_NUMBERS, B_OUTDENT, B_INDENT,
    B_PICTURE, B_TABLE, B_UNDO, B_REDO, B_SEP, B_FONT, B_SIZE
};
/* the order they appear in; B_SEP draws a divider */
static const int g_layout[] = {
    B_FONT, B_SIZE, B_SEP, B_BOLD, B_ITALIC, B_UNDER, B_STRIKE, B_SEP, B_COLOR, B_HILITE, B_SEP,
    B_LEFT, B_CENTER, B_RIGHT, B_JUSTIFY, B_SEP, B_BULLETS, B_NUMBERS, B_OUTDENT, B_INDENT, B_SEP,
    B_PICTURE, B_TABLE, B_SEP, B_UNDO, B_REDO, -1
};
#define NBTN 32

/* one stretch of text with a single look (tools) */
typedef struct { long cp, end; long size; DWORD eff, col, back; int face; } RUNX;

/* ---- per-document state ------------------------------------------------- */
typedef struct {
    void* host;          /* our myWordDocHost window (0 for an invisible doc) */
    void* edit;          /* the RICHEDIT50W window                         */
    void* cbFont;        /* toolbar combos                                 */
    void* cbSize;
    int   flags;
    int   pageTw;        /* printed line width in twips, 0 = wrap to window */
    int   tbH;           /* toolbar height in px (0 when hidden)           */
    int   seq;           /* bumped on every edit                           */
    int   selseq;        /* bumped on every selection move                 */
    int   hot;           /* button under the mouse                         */
    int   down;          /* button being pressed                           */
    int   tracking;
    RECT  br[NBTN];      /* button rectangles, by layout index             */
    int   state[NBTN];   /* 1 = shown pressed                              */
    DWORD fore, back;    /* last colours chosen from the toolbar           */
    int   lastPick;      /* toolbar pick count, readable from Clarion      */
    int   lastCmd;
    /* stream-out buffer */
    char* buf; long len, cap;
    /* pagination */
    long* pstart; long* pused; int pages, pcap;
    /* tools: last search hit, character runs, fonts in use */
    long  fEnd;
    RUNX* runs; int nruns, rcap;
    char* faces; long* fchars; int nfaces, fcap;
    /* undo grouping: TOM's ITextDocument, and how deep the groups are nested */
    void* tom; int tomTried; int group;
} WDOC;

static WDOC  g_d[WD_MAX + 1];
static int   g_inited = 0;
static int   g_step   = 0;
static void* g_heap   = 0;
static void* g_inst   = 0;
static void* g_refDC  = 0;    /* measuring device for edit, paginate and render: the default printer */
static void* g_scrDC  = 0;    /* the display */
static void* g_fUI    = 0;    /* toolbar fonts */
static void* g_fBold  = 0;
static void* g_fItal  = 0;
static void* g_fUnd   = 0;
static void* g_fStrk  = 0;
static void* g_fIcon  = 0;
static void* g_curArrow = 0;
static DWORD g_custColors[16];
static int   g_dpi = 96;

static long WINAPI host_proc(void* w, UINT m, unsigned long wp, unsigned long lp);

/* ========================================================================== */
static void* mem_alloc(long n) { return p_HeapAlloc(g_heap, 8 /*ZERO*/, (DWORD)n); }
static void* mem_grow(void* p, long n) { return p ? p_HeapReAlloc(g_heap, 8, p, (DWORD)n) : mem_alloc(n); }
static void  mem_free(void* p) { if (p) p_HeapFree(g_heap, 0, p); }
static int   px(int v) { return v * g_dpi / 96; }
static int   slen(const char* s) { int n = 0; if (s) while (s[n]) n++; return n; }
static void  scpy(char* d, const char* s, int cap) { int i = 0; if (cap <= 0) return; while (s && s[i] && i < cap - 1) { d[i] = s[i]; i++; } d[i] = 0; }
static void  zero(void* p, int n) { char* c = (char*)p; while (n-- > 0) *c++ = 0; }
static int   seq_ci(const char* a, const char* b) {
    while (*a && *b) { char x = *a, y = *b; if (x >= 'A' && x <= 'Z') x += 32; if (y >= 'A' && y <= 'Z') y += 32; if (x != y) return 0; a++; b++; }
    return *a == *b;
}

#define BIND(mod, name) *(FARPROC*)&p_##name = GetProcAddress(mod, #name)

int wdoc_init(void) {
    HMODULE hU, hG, hK, hC, hR, hO;
    WNDCLASSA wc;
    if (g_inited) return 0;
    hU = LoadLibraryA("user32.dll");   if (!hU) { g_step = -1; return -1; }
    hG = LoadLibraryA("gdi32.dll");    if (!hG) { g_step = -2; return -2; }
    hK = LoadLibraryA("kernel32.dll"); if (!hK) { g_step = -3; return -3; }
    hR = LoadLibraryA("msftedit.dll"); if (!hR) { g_step = -4; return -4; }   /* registers RICHEDIT50W */
    hC = LoadLibraryA("comdlg32.dll");
    hO = LoadLibraryA("ole32.dll");

    BIND(hU, CreateWindowExA); BIND(hU, SendMessageA); BIND(hU, DefWindowProcA); BIND(hU, RegisterClassA);
    BIND(hU, DestroyWindow); BIND(hU, SetWindowPos); BIND(hU, MoveWindow); BIND(hU, ShowWindow);
    BIND(hU, SetFocus); BIND(hU, GetFocus); BIND(hU, IsChild); BIND(hU, EnableWindow);
    BIND(hU, InvalidateRect); BIND(hU, GetClientRect); BIND(hU, GetWindowLongA); BIND(hU, SetWindowLongA);
    BIND(hU, GetParent); BIND(hU, BeginPaint); BIND(hU, EndPaint); BIND(hU, GetDC); BIND(hU, ReleaseDC);
    BIND(hU, FillRect); BIND(hU, DrawTextA); BIND(hU, LoadCursorA); BIND(hU, SetCursor);
    BIND(hU, TrackMouseEvent); BIND(hU, ClientToScreen); BIND(hU, CreatePopupMenu); BIND(hU, AppendMenuA);
    BIND(hU, TrackPopupMenu); BIND(hU, DestroyMenu);
    BIND(hK, GetModuleHandleA); BIND(hK, CreateFileA); BIND(hK, ReadFile); BIND(hK, WriteFile);
    BIND(hK, GetFileSize); BIND(hK, CloseHandle); BIND(hK, GetProcessHeap); BIND(hK, HeapAlloc);
    BIND(hK, HeapReAlloc); BIND(hK, HeapFree); BIND(hK, GetTempPathA); BIND(hK, GetCurrentProcessId);
    BIND(hK, DeleteFileA); BIND(hK, MultiByteToWideChar); BIND(hK, WideCharToMultiByte); BIND(hU, SendMessageW);
    BIND(hG, CreateDIBSection); BIND(hG, PatBlt); BIND(hG, PlayEnhMetaFile); BIND(hG, SetWinMetaFileBits);
    BIND(hG, StretchDIBits); BIND(hG, SetStretchBltMode);
    BIND(hG, GetDeviceCaps); BIND(hG, CreateFontA); BIND(hG, CreateSolidBrush); BIND(hG, CreatePen);
    BIND(hG, SelectObject); BIND(hG, DeleteObject); BIND(hG, SetTextColor); BIND(hG, SetBkMode);
    BIND(hG, MoveToEx); BIND(hG, LineTo); BIND(hG, Rectangle); BIND(hG, Ellipse); BIND(hG, Polygon);
    BIND(hG, TextOutW); BIND(hG, CreateCompatibleDC); BIND(hG, CreateCompatibleBitmap); BIND(hG, BitBlt);
    BIND(hG, DeleteDC); BIND(hG, CreateDCA); BIND(hG, CreateEnhMetaFileA); BIND(hG, CloseEnhMetaFile);
    BIND(hG, DeleteEnhMetaFile); BIND(hG, GetWinMetaFileBits); BIND(hG, CreateICA); BIND(hG, GetEnhMetaFileBits); BIND(hG, SetEnhMetaFileBits); BIND(hG, EnumFontFamiliesExA); BIND(hG, SetMapMode);
    if (hC) { BIND(hC, ChooseColorA); BIND(hC, GetOpenFileNameA); }
    if (hO) { BIND(hO, OleInitialize); BIND(hO, CreateILockBytesOnHGlobal); BIND(hO, StgCreateDocfileOnILockBytes); }

    if (!p_CreateWindowExA || !p_SendMessageA || !p_RegisterClassA || !p_HeapAlloc || !p_CreateEnhMetaFileA) {
        g_step = -5; return -5;
    }
    /* Pictures inside RTF are OLE static objects to RichEdit; it needs OLE up
       on this thread. Harmless if the RTL already did it (returns S_FALSE). */
    if (p_OleInitialize) p_OleInitialize(0);

    g_heap = p_GetProcessHeap();
    g_inst = p_GetModuleHandleA(0);
    /* The screen is the UI's device (toolbar sizes)... */
    g_scrDC = p_CreateDCA("DISPLAY", 0, 0, 0);
    if (!g_scrDC) { g_step = -6; return -6; }
    g_dpi = p_GetDeviceCaps(g_scrDC, LOGPIXELSY);
    if (g_dpi < 96) g_dpi = 96;
    /* ...but text is MEASURED on the default printer. At 96 dpi glyph widths are
       hinted to whole pixels, so a line measured on screen prints wider at true
       scale and runs off the right edge of the report IMAGE. Measuring at
       printer resolution keeps editor line breaks, pagination and the printed
       page in step (WordPad does the same). No printer -> the screen. */
    {   HMODULE hW = LoadLibraryA("winspool.drv");
        char pn[260]; DWORD pl = sizeof(pn);
        if (hW) *(FARPROC*)&p_GetDefaultPrinterA = GetProcAddress(hW, "GetDefaultPrinterA");
        if (p_GetDefaultPrinterA && p_CreateICA && p_GetDefaultPrinterA(pn, &pl))
            g_refDC = p_CreateICA("WINSPOOL", pn, 0, 0);
        if (!g_refDC) g_refDC = g_scrDC;
    }
    g_curArrow = p_LoadCursorA(0, (const char*)IDC_ARROW);

    zero(&wc, sizeof(wc));
    wc.lpfnWndProc   = host_proc;
    wc.hInstance     = g_inst;
    wc.hCursor       = g_curArrow;
    wc.lpszClassName = "myWordDocHost";
    p_RegisterClassA(&wc);          /* fails harmlessly if already registered */

    g_fUI   = p_CreateFontA(-px(12), 0, 0, 0, 400, 0, 0, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe UI");
    g_fBold = p_CreateFontA(-px(15), 0, 0, 0, 700, 0, 0, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe UI");
    g_fItal = p_CreateFontA(-px(16), 0, 0, 0, 400, 1, 0, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Georgia");
    g_fUnd  = p_CreateFontA(-px(15), 0, 0, 0, 400, 0, 1, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe UI");
    g_fStrk = p_CreateFontA(-px(15), 0, 0, 0, 400, 0, 0, 1, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe UI");
    g_fIcon = p_CreateFontA(-px(15), 0, 0, 0, 400, 0, 0, 0, DEFAULT_CHARSET, 0, 0, 5, 0, "Segoe MDL2 Assets");
    {   int i; for (i = 0; i < 16; i++) g_custColors[i] = 0x00FFFFFF; }

    g_inited = 1;
    return 0;
}

int wdoc_last_step(void) { return g_step; }
int wdoc_struct_sizes(void) { return (int)sizeof(CF2A) * 1000 + (int)sizeof(PF2); }  /* expect 84188 */

/* ---- helpers ------------------------------------------------------------- */
static WDOC* D(int h) {
    if (h < 1 || h > WD_MAX || !g_d[h].edit) return 0;
    return &g_d[h];
}
static long E(WDOC* d, UINT m, unsigned long wp, unsigned long lp) {
    return d && d->edit ? p_SendMessageA(d->edit, m, wp, lp) : 0;
}
static int slot_of_host(void* w) {
    int i; for (i = 1; i <= WD_MAX; i++) if (g_d[i].host == w && w) return i; return 0;
}

/* ---- streaming ----------------------------------------------------------- */
typedef struct { const char* p; long len, pos; } MEMIN;

static DWORD WINAPI cb_in(DWORD cookie, BYTE* buf, long cb, long* pcb) {
    MEMIN* m = (MEMIN*)cookie;
    long n = m->len - m->pos;
    if (n > cb) n = cb;
    if (n < 0) n = 0;
    {   long i; for (i = 0; i < n; i++) buf[i] = (BYTE)m->p[m->pos + i]; }
    m->pos += n;
    *pcb = n;
    return 0;
}
static DWORD WINAPI cb_out(DWORD cookie, BYTE* buf, long cb, long* pcb) {
    WDOC* d = (WDOC*)cookie;
    if (d->len + cb + 1 > d->cap) {
        long nc = d->cap ? d->cap * 2 : 65536;
        char* nb;
        while (nc < d->len + cb + 1) nc *= 2;
        nb = (char*)mem_grow(d->buf, nc);
        if (!nb) { *pcb = 0; return 1; }
        d->buf = nb; d->cap = nc;
    }
    {   long i; for (i = 0; i < cb; i++) d->buf[d->len + i] = (char)buf[i]; }
    d->len += cb;
    d->buf[d->len] = 0;
    *pcb = cb;
    return 0;
}
static int stream_in(WDOC* d, const char* p, long len, int selection) {
    MEMIN m; EDITSTREAM es; int fmt;
    m.p = p; m.len = len; m.pos = 0;
    es.dwCookie = (DWORD)&m; es.dwError = 0; es.pfnCallback = cb_in;
    /* "{\rtf" is RTF; anything else is plain text in the ANSI code page */
    fmt = (len >= 5 && p[0] == '{' && p[1] == '\\' && p[2] == 'r' && p[3] == 't' && p[4] == 'f') ? SF_RTF : SF_TEXT;
    if (selection) fmt |= SFF_SELECTION;
    E(d, EM_STREAMIN, fmt, (unsigned long)&es);
    return es.dwError == 0 ? 1 : 0;
}

/* ---- layout -------------------------------------------------------------- */
static int btn_w(int b) {
    if (b == B_SEP)  return px(9);
    if (b == B_FONT) return px(150);
    if (b == B_SIZE) return px(52);
    return px(TB_BTN);
}
/* lays the toolbar out in rows that wrap at the host width; returns its height */
static int layout_toolbar(WDOC* d, int width) {
    int i, x = px(6), row = 0, rowH = px(TB_ROWH);
    if (!(d->flags & WDF_TOOLBAR)) return 0;
    for (i = 0; g_layout[i] >= 0 && i < NBTN; i++) {
        int b = g_layout[i], w = btn_w(b);
        if (b == B_SEP && x == px(6)) { d->br[i].left = d->br[i].right = -1; continue; }
        if (x + w > width - px(4) && x > px(6)) {
            row++; x = px(6);
            if (b == B_SEP) { d->br[i].left = d->br[i].right = -1; continue; }
        }
        d->br[i].left   = x;
        d->br[i].top    = row * rowH + (rowH - px(TB_BTN)) / 2 + px(1);
        d->br[i].right  = x + w;
        d->br[i].bottom = d->br[i].top + px(TB_BTN);
        x += w + px(TB_GAP);
    }
    return (row + 1) * rowH + px(2);
}
static void layout(WDOC* d) {
    RECT rc; int w, h, ex, ew, i;
    if (!d->host) return;
    p_GetClientRect(d->host, &rc);
    w = rc.right; h = rc.bottom;
    d->tbH = layout_toolbar(d, w);
    for (i = 0; g_layout[i] >= 0; i++) {
        void* cb = g_layout[i] == B_FONT ? d->cbFont : g_layout[i] == B_SIZE ? d->cbSize : 0;
        if (cb) p_MoveWindow(cb, d->br[i].left, d->br[i].top + px(1), d->br[i].right - d->br[i].left, px(300), 1);
    }
    /* page view: the editor is a sheet of the printed width, centred on a desk */
    ex = 1; ew = w - 2;
    if ((d->flags & WDF_PAGEVIEW) && d->pageTw > 0) {
        int pagePx = d->pageTw * g_dpi / 1440 + px(48);     /* + the sheet's own margins */
        if (pagePx < ew - px(24)) { ex = (w - pagePx) / 2; ew = pagePx; }
    }
    p_MoveWindow(d->edit, ex, d->tbH + (d->flags & WDF_PAGEVIEW ? px(8) : 1), ew,
                 h - d->tbH - (d->flags & WDF_PAGEVIEW ? px(8) : 2), 1);
    p_InvalidateRect(d->host, 0, 0);
}

/* ---- reading the selection's format back into the toolbar ----------------- */
static void refresh_state(WDOC* d) {
    CF2A cf; PF2 pf; int i;
    if (!d->host || !(d->flags & WDF_TOOLBAR)) return;
    zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
    zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    E(d, EM_GETPARAFORMAT, 0, (unsigned long)&pf);
    for (i = 0; g_layout[i] >= 0; i++) {
        int b = g_layout[i], on = 0;
        switch (b) {
        case B_BOLD:    on = (cf.dwMask & CFM_BOLD)      && (cf.dwEffects & CFM_BOLD); break;
        case B_ITALIC:  on = (cf.dwMask & CFM_ITALIC)    && (cf.dwEffects & CFM_ITALIC); break;
        case B_UNDER:   on = (cf.dwMask & CFM_UNDERLINE) && (cf.dwEffects & CFM_UNDERLINE); break;
        case B_STRIKE:  on = (cf.dwMask & CFM_STRIKEOUT) && (cf.dwEffects & CFM_STRIKEOUT); break;
        case B_LEFT:    on = (pf.dwMask & PFM_ALIGNMENT) && (pf.wAlignment == 1 || pf.wAlignment == 0); break;
        case B_RIGHT:   on = (pf.dwMask & PFM_ALIGNMENT) && pf.wAlignment == 2; break;
        case B_CENTER:  on = (pf.dwMask & PFM_ALIGNMENT) && pf.wAlignment == 3; break;
        case B_JUSTIFY: on = (pf.dwMask & PFM_ALIGNMENT) && pf.wAlignment == 4; break;
        case B_BULLETS: on = (pf.dwMask & PFM_NUMBERING) && pf.wNumbering == 1; break;
        case B_NUMBERS: on = (pf.dwMask & PFM_NUMBERING) && pf.wNumbering >= 2; break;
        }
        if (d->state[i] != on) { d->state[i] = on; p_InvalidateRect(d->host, &d->br[i], 0); }
    }
    /* font + size combos */
    if (d->cbFont) {
        long k = (cf.dwMask & CFM_FACE) ? p_SendMessageA(d->cbFont, CB_FINDSTRINGEXACT, (unsigned long)-1, (unsigned long)cf.szFaceName) : -1;
        p_SendMessageA(d->cbFont, CB_SETCURSEL, (unsigned long)k, 0);
    }
    if (d->cbSize) {
        long k = -1;
        if (cf.dwMask & CFM_SIZE) {
            char s[8]; int pt = (int)(cf.yHeight / 20), n = 0;
            if (pt >= 100) s[n++] = (char)('0' + pt / 100);
            if (pt >= 10)  s[n++] = (char)('0' + (pt / 10) % 10);
            s[n++] = (char)('0' + pt % 10); s[n] = 0;
            k = p_SendMessageA(d->cbSize, CB_FINDSTRINGEXACT, (unsigned long)-1, (unsigned long)s);
        }
        p_SendMessageA(d->cbSize, CB_SETCURSEL, (unsigned long)k, 0);
    }
}

/* ---- formatting primitives (shared by the toolbar and the Clarion API) ---- */
static void set_char(WDOC* d, DWORD mask, DWORD effects, CF2A* src) {
    CF2A cf;
    if (src) cf = *src; else zero(&cf, sizeof(cf));
    cf.cbSize = sizeof(cf); cf.dwMask = mask; cf.dwEffects = effects;
    E(d, EM_SETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
}
static void effect(WDOC* d, DWORD bit, int how) {     /* how: 0 off, 1 on, 2 toggle */
    CF2A cf; int on;
    if (how == 2) {
        zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
        E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
        on = !((cf.dwMask & bit) && (cf.dwEffects & bit));
    } else on = how;
    set_char(d, bit, on ? bit : 0, 0);
}
static void para_align(WDOC* d, int a) {
    PF2 pf; zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    pf.dwMask = PFM_ALIGNMENT; pf.wAlignment = (WORD)a;
    E(d, EM_SETPARAFORMAT, 0, (unsigned long)&pf);
}
/* 0 none, 1 bullet, 2 1.2.3., 3 a.b.c., 4 A.B.C., 5 i.ii., 6 I.II. ; toggles off if already that */
static void para_numbering(WDOC* d, int style, int toggle) {
    PF2 pf, cur;
    zero(&cur, sizeof(cur)); cur.cbSize = sizeof(cur);
    E(d, EM_GETPARAFORMAT, 0, (unsigned long)&cur);
    if (toggle && (cur.dwMask & PFM_NUMBERING) &&
        ((style == 1 && cur.wNumbering == 1) || (style >= 2 && cur.wNumbering >= 2))) style = 0;
    zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    pf.dwMask = PFM_NUMBERING | PFM_OFFSET | PFM_NUMBERINGSTYLE | PFM_NUMBERINGTAB | PFM_NUMBERINGSTART;
    pf.wNumbering = (WORD)style;
    pf.dxOffset = style ? 360 : 0;
    pf.wNumberingStyle = style >= 2 ? 0x0200 /* PFNS_PERIOD */ : 0;
    pf.wNumberingTab = style ? 360 : 0;
    pf.wNumberingStart = 1;
    E(d, EM_SETPARAFORMAT, 0, (unsigned long)&pf);
}
static void para_indent(WDOC* d, int deltaTw) {
    PF2 pf; zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    pf.dwMask = PFM_OFFSETINDENT; pf.dxStartIndent = deltaTw;
    E(d, EM_SETPARAFORMAT, 0, (unsigned long)&pf);
}
static void set_color(WDOC* d, DWORD c, int back) {
    CF2A cf; zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    if (back) { cf.dwMask = CFM_BACKCOLOR; if (c == 0xFFFFFFFF) cf.dwEffects = CFE_AUTOBACKCOLOR; else cf.crBackColor = c; }
    else      { cf.dwMask = CFM_COLOR;     if (c == 0xFFFFFFFF) cf.dwEffects = CFE_AUTOCOLOR;     else cf.crTextColor = c; }
    E(d, EM_SETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
}
static void set_face(WDOC* d, const char* face) {
    CF2A cf; zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    cf.dwMask = CFM_FACE | CFM_CHARSET; cf.bCharSet = DEFAULT_CHARSET;
    scpy(cf.szFaceName, face, 32);
    E(d, EM_SETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
}
static void set_size(WDOC* d, int pt10) {      /* tenths of a point */
    CF2A cf; zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    cf.dwMask = CFM_SIZE; cf.yHeight = pt10 * 2;
    E(d, EM_SETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
}

/* ---- pictures -------------------------------------------------------------
   A picture is inserted as RTF - {\pict\pngblip ...hex...} - streamed into the
   selection. That is the same thing Word writes, so the BLOB stays plain RTF
   and the picture travels with the text. */
static unsigned long be32(const BYTE* p) { return ((unsigned long)p[0] << 24) | ((unsigned long)p[1] << 16) | ((unsigned long)p[2] << 8) | p[3]; }
static unsigned long le32(const BYTE* p) { return ((unsigned long)p[3] << 24) | ((unsigned long)p[2] << 16) | ((unsigned long)p[1] << 8) | p[0]; }
static int le16s(const BYTE* p) { return (short)(p[0] | (p[1] << 8)); }

static char* put(char* o, const char* s) { while (*s) *o++ = *s++; return o; }
static char* putn(char* o, long v) {
    char t[12]; int n = 0;
    if (v < 0) { *o++ = '-'; v = -v; }
    do { t[n++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (n) *o++ = t[--n];
    return o;
}

static BYTE* bmp_to_png(const char* path, long* n);   /* tools section: GDI+ */

/* returns 1 ok, -1 cannot read, -2 unknown format, -3 out of memory */
int wdoc_insert_image(int h, const char* path, int maxWidthTw) {
    WDOC* d = D(h);
    void* f; DWORD sz, got = 0; BYTE* data; char* rtf; char* o;
    long skip = 0, wPx = 0, hPx = 0, picw = 0, pich = 0, goalW, goalH;
    const char* kind = 0;
    static const char hex[] = "0123456789abcdef";
    long i;
    if (!d) return 0;
    f = p_CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0);
    if (!f || f == (void*)-1) return -1;
    sz = p_GetFileSize(f, 0);
    data = (BYTE*)mem_alloc((long)sz + 4);
    if (!data) { p_CloseHandle(f); return -3; }
    p_ReadFile(f, data, sz, &got, 0);
    p_CloseHandle(f);
    if (got < 32) { mem_free(data); return -1; }

    if (data[0] == 0x89 && data[1] == 'P' && data[2] == 'N' && data[3] == 'G') {
        kind = "\\pngblip"; wPx = (long)be32(data + 16); hPx = (long)be32(data + 20);
    } else if (data[0] == 0xFF && data[1] == 0xD8) {
        unsigned long p = 2;
        kind = "\\jpegblip";
        while (p + 9 < got) {                          /* walk to the SOFn marker */
            BYTE mk;
            if (data[p] != 0xFF) { p++; continue; }
            mk = data[p + 1];
            if (mk >= 0xC0 && mk <= 0xCF && mk != 0xC4 && mk != 0xC8 && mk != 0xCC) {
                hPx = (data[p + 5] << 8) | data[p + 6];
                wPx = (data[p + 7] << 8) | data[p + 8];
                break;
            }
            if (mk == 0xD8 || mk == 0x01 || (mk >= 0xD0 && mk <= 0xD7)) { p += 2; continue; }
            p += 2 + ((data[p + 2] << 8) | data[p + 3]);
        }
    } else if (data[0] == 'B' && data[1] == 'M') {
        /* RichEdit drops \dibitmap pictures without a word, so a BMP goes in as PNG */
        long pn = 0; BYTE* png = bmp_to_png(path, &pn);
        wPx = (long)le32(data + 18); hPx = (long)le32(data + 22); if (hPx < 0) hPx = -hPx;
        if (png && pn > 32) { mem_free(data); data = png; got = (DWORD)pn; kind = "\\pngblip"; }
        else { mem_free(png); kind = "\\dibitmap0"; skip = 14; }
    } else if (le32(data) == 1 && le32(data + 40) == 0x464D4520) {   /* EMF: " EMF" signature */
        RECT fr; kind = "\\emfblip";
        fr.left = (long)le32(data + 24); fr.top = (long)le32(data + 28);
        fr.right = (long)le32(data + 32); fr.bottom = (long)le32(data + 36);
        picw = fr.right - fr.left; pich = fr.bottom - fr.top;         /* .01 mm */
        wPx = picw * 96 / 2540; hPx = pich * 96 / 2540;
    } else if (le32(data) == 0x9AC6CDD7) {                            /* placeable WMF */
        int inch = data[14] | (data[15] << 8);
        long ww = le16s(data + 10) - le16s(data + 6), hh = le16s(data + 12) - le16s(data + 8);
        if (inch <= 0) inch = 1440;
        if (ww < 0) ww = -ww; if (hh < 0) hh = -hh;
        kind = "\\wmetafile8"; skip = 22;
        picw = ww * 2540 / inch; pich = hh * 2540 / inch;
        wPx = ww * 96 / inch; hPx = hh * 96 / inch;
    }
    if (!kind || wPx <= 0 || hPx <= 0) { mem_free(data); return -2; }

    goalW = wPx * 15; goalH = hPx * 15;               /* 96 dpi pixels -> twips */
    if (maxWidthTw <= 0) maxWidthTw = d->pageTw > 0 ? d->pageTw : 9360;
    if (goalW > maxWidthTw) { goalH = goalH * maxWidthTw / goalW; goalW = maxWidthTw; }
    if (!picw) { picw = wPx; pich = hPx; }

    rtf = (char*)mem_alloc((long)(got - skip) * 2 + (long)(got - skip) / 32 + 256);   /* hex + a CRLF per 64 bytes */
    if (!rtf) { mem_free(data); return -3; }
    o = put(rtf, "{\\rtf1{\\pict");
    o = put(o, kind);
    o = put(o, "\\picw"); o = putn(o, picw); o = put(o, "\\pich"); o = putn(o, pich);
    o = put(o, "\\picwgoal"); o = putn(o, goalW); o = put(o, "\\pichgoal"); o = putn(o, goalH);
    o = put(o, "\r\n");
    for (i = skip; i < (long)got; i++) {
        *o++ = hex[data[i] >> 4]; *o++ = hex[data[i] & 15];
        if (((i - skip) & 63) == 63) { *o++ = '\r'; *o++ = '\n'; }
    }
    o = put(o, "}}");
    *o = 0;
    stream_in(d, rtf, (long)(o - rtf), 1);
    mem_free(rtf); mem_free(data);
    d->seq++;
    return 1;
}

/* a rows x cols grid with thin borders, spread across the line width */
int wdoc_insert_table(int h, int rows, int cols, int widthTw) {
    WDOC* d = D(h);
    char* rtf; char* o; int r, c; long cw;
    if (!d || rows < 1 || cols < 1 || rows > 200 || cols > 30) return 0;
    if (widthTw <= 0) widthTw = d->pageTw > 0 ? d->pageTw : 9360;
    cw = widthTw / cols;
    rtf = (char*)mem_alloc(rows * (cols * 160 + 64) + 64);
    if (!rtf) return 0;
    o = put(rtf, "{\\rtf1");
    for (r = 0; r < rows; r++) {
        o = put(o, "\\trowd\\trgaph108\\trleft0");
        for (c = 0; c < cols; c++) {
            o = put(o, "\\clbrdrt\\brdrs\\brdrw10\\clbrdrl\\brdrs\\brdrw10\\clbrdrb\\brdrs\\brdrw10\\clbrdrr\\brdrs\\brdrw10\\cellx");
            o = putn(o, cw * (c + 1));
        }
        o = put(o, "\\pard\\intbl");
        for (c = 0; c < cols; c++) o = put(o, "\\cell");
        o = put(o, "\\row");
    }
    o = put(o, "\\pard\\par}");
    *o = 0;
    stream_in(d, rtf, (long)(o - rtf), 1);
    mem_free(rtf);
    d->seq++;
    return 1;
}

/* ---- toolbar actions ------------------------------------------------------ */
static void pick_colour(WDOC* d, int back) {
    CHOOSECOLORA cc;
    if (!p_ChooseColorA) return;
    zero(&cc, sizeof(cc));
    cc.lStructSize = sizeof(cc); cc.hwndOwner = d->host;
    cc.rgbResult = back ? d->back : d->fore;
    cc.lpCustColors = g_custColors; cc.Flags = CC_RGBINIT | CC_FULLOPEN;
    if (p_ChooseColorA(&cc)) {
        if (back) d->back = cc.rgbResult; else d->fore = cc.rgbResult;
        set_color(d, cc.rgbResult, back);
        p_InvalidateRect(d->host, 0, 0);
    }
}
static void pick_picture(WDOC* d) {
    OPENFILENAMEA of; char file[520];
    if (!p_GetOpenFileNameA) return;
    zero(&of, sizeof(of)); file[0] = 0;
    of.lStructSize = 76;            /* OPENFILENAME_SIZE_VERSION_400 */
    of.hwndOwner = d->host;
    of.lpstrFilter = "Pictures (*.png;*.jpg;*.jpeg;*.bmp;*.emf;*.wmf)\0*.png;*.jpg;*.jpeg;*.bmp;*.emf;*.wmf\0All files\0*.*\0";
    of.lpstrFile = file; of.nMaxFile = sizeof(file);
    of.lpstrTitle = "Insert picture";
    of.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY | OFN_NOCHANGEDIR;
    if (p_GetOpenFileNameA(&of)) wdoc_insert_image((int)(d - g_d), file, 0);
}
static void pick_table(WDOC* d, RECT* br) {
    static const int dims[][2] = { {2,2}, {2,3}, {3,3}, {3,4}, {4,4}, {5,3}, {6,4}, {8,5} };
    void* m; POINT pt; int i, r;
    char lab[24];
    m = p_CreatePopupMenu();
    for (i = 0; i < 8; i++) {
        char* o = lab;
        o = putn(o, dims[i][0]); o = put(o, " rows x "); o = putn(o, dims[i][1]); o = put(o, " columns"); *o = 0;
        p_AppendMenuA(m, MF_STRING, (UINT)(i + 1), lab);
    }
    pt.x = br->left; pt.y = br->bottom;
    p_ClientToScreen(d->host, &pt);
    r = p_TrackPopupMenu(m, TPM_RETURNCMD | TPM_LEFTALIGN, pt.x, pt.y, 0, d->host, 0);
    p_DestroyMenu(m);
    if (r >= 1 && r <= 8) wdoc_insert_table((int)(d - g_d), dims[r - 1][0], dims[r - 1][1], 0);
}
static void run_button(WDOC* d, int b, RECT* br) {
    switch (b) {
    case B_BOLD:    effect(d, CFM_BOLD, 2); break;
    case B_ITALIC:  effect(d, CFM_ITALIC, 2); break;
    case B_UNDER:   effect(d, CFM_UNDERLINE, 2); break;
    case B_STRIKE:  effect(d, CFM_STRIKEOUT, 2); break;
    case B_COLOR:   pick_colour(d, 0); break;
    case B_HILITE:  pick_colour(d, 1); break;
    case B_LEFT:    para_align(d, 1); break;
    case B_CENTER:  para_align(d, 3); break;
    case B_RIGHT:   para_align(d, 2); break;
    case B_JUSTIFY: para_align(d, 4); break;
    case B_BULLETS: para_numbering(d, 1, 1); break;
    case B_NUMBERS: para_numbering(d, 2, 1); break;
    case B_OUTDENT: para_indent(d, -360); break;
    case B_INDENT:  para_indent(d, 360); break;
    case B_PICTURE: pick_picture(d); break;
    case B_TABLE:   pick_table(d, br); break;
    case B_UNDO:    E(d, EM_UNDO, 0, 0); break;
    case B_REDO:    E(d, EM_REDO, 0, 0); break;
    }
    d->lastCmd = b; d->lastPick++;
    p_SetFocus(d->edit);
    refresh_state(d);
}

/* ---- painting the toolbar ------------------------------------------------- */
static void hline(void* dc, int x1, int x2, int y) { p_MoveToEx(dc, x1, y, 0); p_LineTo(dc, x2, y); }
static void fill(void* dc, int l, int t, int r, int b, DWORD c) {
    RECT rc; void* br = p_CreateSolidBrush(c);
    rc.left = l; rc.top = t; rc.right = r; rc.bottom = b;
    p_FillRect(dc, &rc, br); p_DeleteObject(br);
}
static void text_in(void* dc, void* font, const char* s, RECT* r, DWORD ink) {
    void* of = p_SelectObject(dc, font);
    RECT t = *r;
    p_SetTextColor(dc, ink);
    p_DrawTextA(dc, s, -1, &t, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    p_SelectObject(dc, of);
}
static void glyph(void* dc, WCHAR g, RECT* r, DWORD ink) {
    void* of = p_SelectObject(dc, g_fIcon);
    int cx = (r->left + r->right) / 2 - px(8), cy = (r->top + r->bottom) / 2 - px(8);
    p_SetTextColor(dc, ink);
    p_TextOutW(dc, cx, cy, &g, 1);
    p_SelectObject(dc, of);
}
/* four "lines of text" drawn with the requested alignment */
static void lines_icon(void* dc, RECT* r, int align, int bullets) {
    int cx = (r->left + r->right) / 2, cy = (r->top + r->bottom) / 2, i;
    int full = px(14), part = px(9);
    for (i = 0; i < 4; i++) {
        int y = cy - px(6) + i * px(4), w = (i & 1) ? part : full, x1;
        if (bullets) {
            int bx = cx - px(7);
            if (bullets == 1) fill(dc, bx, y - px(1), bx + px(2), y + px(1), C_INK);
            else { fill(dc, bx, y - px(1), bx + px(1), y + px(1), C_INK); }
            x1 = cx - px(3); w = px(10);
            if (i == 3) break;
            hline(dc, x1, x1 + w, y);
            continue;
        }
        if (align == 2)      x1 = cx + full / 2 - w;
        else if (align == 3) x1 = cx - w / 2;
        else                 x1 = cx - full / 2;
        if (align == 4) w = full;
        hline(dc, x1, x1 + w, y);
    }
}
static void indent_icon(void* dc, RECT* r, int in) {
    int cx = (r->left + r->right) / 2, cy = (r->top + r->bottom) / 2, i;
    POINT tri[3];
    for (i = 0; i < 4; i++) {
        int y = cy - px(6) + i * px(4);
        if (i == 0 || i == 3) hline(dc, cx - px(7), cx + px(7), y);
        else hline(dc, cx - px(1), cx + px(7), y);
    }
    if (in) { tri[0].x = cx - px(7); tri[0].y = cy - px(3); tri[1].x = cx - px(3); tri[1].y = cy; tri[2].x = cx - px(7); tri[2].y = cy + px(3); }
    else    { tri[0].x = cx - px(3); tri[0].y = cy - px(3); tri[1].x = cx - px(7); tri[1].y = cy; tri[2].x = cx - px(3); tri[2].y = cy + px(3); }
    p_Polygon(dc, tri, 3);
}
static void picture_icon(void* dc, RECT* r) {
    int cx = (r->left + r->right) / 2, cy = (r->top + r->bottom) / 2;
    void* ob = p_SelectObject(dc, p_CreateSolidBrush(0x00FFFFFF));
    POINT m[3];
    p_Rectangle(dc, cx - px(8), cy - px(6), cx + px(8), cy + px(7));
    p_DeleteObject(p_SelectObject(dc, p_CreateSolidBrush(0x0000A5F5)));    /* sun, amber */
    p_Ellipse(dc, cx + px(1), cy - px(4), cx + px(5), cy);
    p_DeleteObject(p_SelectObject(dc, p_CreateSolidBrush(0x00609B10)));    /* hill, green */
    m[0].x = cx - px(7); m[0].y = cy + px(6); m[1].x = cx - px(2); m[1].y = cy - px(1); m[2].x = cx + px(5); m[2].y = cy + px(6);
    p_Polygon(dc, m, 3);
    p_DeleteObject(p_SelectObject(dc, ob));
}
static void table_icon(void* dc, RECT* r) {
    int cx = (r->left + r->right) / 2, cy = (r->top + r->bottom) / 2, i;
    void* ob = p_SelectObject(dc, p_CreateSolidBrush(0x00FFFFFF));
    p_Rectangle(dc, cx - px(8), cy - px(7), cx + px(8), cy + px(7));
    p_DeleteObject(p_SelectObject(dc, ob));
    fill(dc, cx - px(8), cy - px(7), cx + px(8), cy - px(3), 0x00E6B98A);  /* header row tint */
    for (i = 1; i < 3; i++) hline(dc, cx - px(8), cx + px(8), cy - px(7) + i * px(14) / 3);
    for (i = 1; i < 3; i++) { int x = cx - px(8) + i * px(16) / 3; p_MoveToEx(dc, x, cy - px(7), 0); p_LineTo(dc, x, cy + px(7)); }
}
static void paint_button(WDOC* d, void* dc, int i) {
    int b = g_layout[i];
    RECT r = d->br[i];
    DWORD ink = C_INK;
    if (r.right <= r.left || b == B_FONT || b == B_SIZE) return;
    if (b == B_SEP) {
        int x = (r.left + r.right) / 2;
        fill(dc, x, r.top + px(3), x + 1, r.bottom - px(3), C_BARLINE);
        return;
    }
    if (d->state[i] || d->down == i) {
        void* pen = p_CreatePen(PS_SOLID, 1, C_ONLINE);
        void* br  = p_CreateSolidBrush(C_ON);
        void* op = p_SelectObject(dc, pen); void* ob = p_SelectObject(dc, br);
        p_Rectangle(dc, r.left, r.top, r.right, r.bottom);
        p_SelectObject(dc, op); p_SelectObject(dc, ob); p_DeleteObject(pen); p_DeleteObject(br);
    } else if (d->hot == i) {
        fill(dc, r.left, r.top, r.right, r.bottom, C_HOVER);
    }
    if (b == B_UNDO && !E(d, EM_CANUNDO, 0, 0)) ink = C_DIM;
    if (b == B_REDO && !E(d, EM_CANREDO, 0, 0)) ink = C_DIM;
    {
        void* pen = p_CreatePen(PS_SOLID, px(1) < 2 ? 1 : 2, ink);
        void* br  = p_CreateSolidBrush(ink);
        void* op = p_SelectObject(dc, pen); void* ob = p_SelectObject(dc, br);
        switch (b) {
        case B_BOLD:    text_in(dc, g_fBold, "B", &r, ink); break;
        case B_ITALIC:  text_in(dc, g_fItal, "I", &r, ink); break;
        case B_UNDER:   text_in(dc, g_fUnd,  "U", &r, ink); break;
        case B_STRIKE:  text_in(dc, g_fStrk, "S", &r, ink); break;
        case B_COLOR: {
            RECT t = r; t.bottom -= px(5);
            text_in(dc, g_fBold, "A", &t, ink);
            fill(dc, r.left + px(5), r.bottom - px(7), r.right - px(5), r.bottom - px(4), d->fore);
            break; }
        case B_HILITE: {
            RECT t = r; t.bottom -= px(5);
            text_in(dc, g_fUI, "ab", &t, ink);
            fill(dc, r.left + px(5), r.bottom - px(7), r.right - px(5), r.bottom - px(4), d->back);
            break; }
        case B_LEFT:    lines_icon(dc, &r, 1, 0); break;
        case B_CENTER:  lines_icon(dc, &r, 3, 0); break;
        case B_RIGHT:   lines_icon(dc, &r, 2, 0); break;
        case B_JUSTIFY: lines_icon(dc, &r, 4, 0); break;
        case B_BULLETS: lines_icon(dc, &r, 1, 1); break;
        case B_NUMBERS: lines_icon(dc, &r, 1, 2); break;
        case B_OUTDENT: indent_icon(dc, &r, 0); break;
        case B_INDENT:  indent_icon(dc, &r, 1); break;
        case B_PICTURE: { void* p2 = p_CreatePen(PS_SOLID, 1, ink); void* o2 = p_SelectObject(dc, p2); picture_icon(dc, &r); p_SelectObject(dc, o2); p_DeleteObject(p2); break; }
        case B_TABLE:   { void* p2 = p_CreatePen(PS_SOLID, 1, ink); void* o2 = p_SelectObject(dc, p2); table_icon(dc, &r); p_SelectObject(dc, o2); p_DeleteObject(p2); break; }
        case B_UNDO:    glyph(dc, 0xE7A7, &r, ink); break;
        case B_REDO:    glyph(dc, 0xE7A6, &r, ink); break;
        }
        p_SelectObject(dc, op); p_SelectObject(dc, ob); p_DeleteObject(pen); p_DeleteObject(br);
    }
}
static void paint_host(WDOC* d) {
    PAINTSTRUCT ps; RECT rc; void* dc; void* mdc; void* bmp; void* ob; int i;
    dc = p_BeginPaint(d->host, &ps);
    p_GetClientRect(d->host, &rc);
    mdc = p_CreateCompatibleDC(dc);
    bmp = p_CreateCompatibleBitmap(dc, rc.right, rc.bottom);
    ob = p_SelectObject(mdc, bmp);
    p_SetBkMode(mdc, TRANSPARENT);
    /* desk / frame behind the editor */
    fill(mdc, 0, 0, rc.right, rc.bottom, (d->flags & WDF_PAGEVIEW) ? C_DESK : 0x00FFFFFF);
    if (d->tbH) {
        fill(mdc, 0, 0, rc.right, d->tbH, C_BAR);
        fill(mdc, 0, d->tbH - 1, rc.right, d->tbH, C_BARLINE);
        for (i = 0; g_layout[i] >= 0; i++) paint_button(d, mdc, i);
    }
    if (!(d->flags & WDF_NOBORDER)) {
        void* pen = p_CreatePen(PS_SOLID, 1, C_FRAME);
        void* op = p_SelectObject(mdc, pen);
        hline(mdc, 0, rc.right, 0); hline(mdc, 0, rc.right, rc.bottom - 1);
        p_MoveToEx(mdc, 0, 0, 0); p_LineTo(mdc, 0, rc.bottom);
        p_MoveToEx(mdc, rc.right - 1, 0, 0); p_LineTo(mdc, rc.right - 1, rc.bottom);
        p_SelectObject(mdc, op); p_DeleteObject(pen);
    }
    p_BitBlt(dc, 0, 0, rc.right, rc.bottom, mdc, 0, 0, 0x00CC0020 /*SRCCOPY*/);
    p_SelectObject(mdc, ob); p_DeleteObject(bmp); p_DeleteDC(mdc);
    p_EndPaint(d->host, &ps);
}
static int hit(WDOC* d, int x, int y) {
    int i;
    for (i = 0; g_layout[i] >= 0; i++) {
        int b = g_layout[i];
        if (b == B_SEP || b == B_FONT || b == B_SIZE) continue;
        if (x >= d->br[i].left && x < d->br[i].right && y >= d->br[i].top && y < d->br[i].bottom) return i;
    }
    return -1;
}

/* ---- the host window procedure: OUR window, so its notifications are ours -- */
static int WINAPI font_enum(const LOGFONTA* lf, const void* tm, DWORD type, long lp) {
    void* cb = (void*)lp;
    if (lf->lfFaceName[0] == '@') return 1;            /* vertical variants */
    if (p_SendMessageA(cb, CB_FINDSTRINGEXACT, (unsigned long)-1, (unsigned long)lf->lfFaceName) < 0)
        p_SendMessageA(cb, CB_ADDSTRING, 0, (unsigned long)lf->lfFaceName);
    return 1;
}
static long WINAPI host_proc(void* w, UINT m, unsigned long wp, unsigned long lp) {
    int s = slot_of_host(w);
    WDOC* d = s ? &g_d[s] : 0;
    if (!d) return p_DefWindowProcA(w, m, wp, lp);
    switch (m) {
    case WM_ERASEBKGND: return 1;
    case WM_PAINT:      paint_host(d); return 0;
    case WM_SIZE:       if (d->edit) layout(d); return 0;
    case WM_SETFOCUS:   if (d->edit) p_SetFocus(d->edit); return 0;
    case WM_MOUSEMOVE: {
        int x = (short)(lp & 0xFFFF), y = (short)(lp >> 16), i = hit(d, x, y);
        if (!d->tracking) {
            TRACKMOUSEEVENT t; t.cbSize = sizeof(t); t.dwFlags = TME_LEAVE; t.hwndTrack = w; t.dwHoverTime = 0;
            p_TrackMouseEvent(&t); d->tracking = 1;
        }
        if (i != d->hot) {
            if (d->hot >= 0) p_InvalidateRect(w, &d->br[d->hot], 0);
            d->hot = i;
            if (i >= 0) p_InvalidateRect(w, &d->br[i], 0);
        }
        return 0; }
    case WM_MOUSELEAVE:
        d->tracking = 0;
        if (d->hot >= 0) { p_InvalidateRect(w, &d->br[d->hot], 0); d->hot = -1; }
        return 0;
    case WM_LBUTTONDOWN: {
        int x = (short)(lp & 0xFFFF), y = (short)(lp >> 16), i = hit(d, x, y);
        if (i >= 0) { d->down = i; p_InvalidateRect(w, &d->br[i], 0); }
        return 0; }
    case WM_LBUTTONUP: {
        int x = (short)(lp & 0xFFFF), y = (short)(lp >> 16), i = hit(d, x, y), was = d->down;
        d->down = -1;
        if (was >= 0) p_InvalidateRect(w, &d->br[was], 0);
        if (i >= 0 && i == was && !(d->flags & WDF_READONLY)) run_button(d, g_layout[i], &d->br[i]);
        return 0; }
    case WM_COMMAND: {
        int id = (int)(wp & 0xFFFF), code = (int)(wp >> 16);
        if (id == ID_EDIT && code == EN_CHANGE) {
            d->seq++;
            p_InvalidateRect(w, 0, 0);       /* undo/redo enablement */
        } else if ((id == ID_FONT || id == ID_SIZE) && code == CBN_SELCHANGE) {
            void* cb = id == ID_FONT ? d->cbFont : d->cbSize;
            long k = p_SendMessageA(cb, CB_GETCURSEL, 0, 0);
            char txt[64];
            if (k >= 0) {
                p_SendMessageA(cb, CB_GETLBTEXT, (unsigned long)k, (unsigned long)txt);
                if (id == ID_FONT) set_face(d, txt);
                else { int v = 0, j; for (j = 0; txt[j] >= '0' && txt[j] <= '9'; j++) v = v * 10 + txt[j] - '0'; if (v > 0) set_size(d, v * 10); }
                d->lastPick++;
            }
        } else if ((id == ID_FONT || id == ID_SIZE) && code == CBN_CLOSEUP) {
            p_SetFocus(d->edit);
        }
        return 0; }
    case WM_NOTIFY: {
        NMHDR* n = (NMHDR*)lp;
        if (n->idFrom == ID_EDIT && n->code == EN_SELCHANGE) { d->selseq++; refresh_state(d); }
        return 0; }
    }
    return p_DefWindowProcA(w, m, wp, lp);
}

/* ========================================================================== */
/*  Creating and destroying                                                    */
/* ========================================================================== */
static void clip_children(void* w) {
    long st;
    if (!w || !p_GetWindowLongA) return;
    st = p_GetWindowLongA(w, GWL_STYLE);
    if (st & WS_CLIPCHILDREN) return;
    p_SetWindowLongA(w, GWL_STYLE, st | WS_CLIPCHILDREN);
    p_SetWindowPos(w, 0, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

/* ---- IRichEditOleCallback ------------------------------------------------
   RichEdit keeps a BMP, EMF or WMF picture as an OLE object, and it can only
   create one when its owner hands it storage through this callback - without
   it such pictures are dropped without a word (PNG and JPEG are drawn
   natively and never needed it). WordPad registers the same thing. One static
   object serves every editor; it is never freed, so AddRef/Release are no-ops. */
#define E_NOTIMPL_ ((long)0x80004001)
#define E_NOINTERFACE_ ((long)0x80004002)
typedef struct { void** vtbl; } RECB;
static long WINAPI recb_qi(RECB* t, const DWORD* iid, void** pp) {
    /* IUnknown {00000000-...-C000-000000000046}, IRichEditOleCallback {00020403-...} */
    if (iid && (iid[0] == 0 || iid[0] == 0x00020403) && iid[1] == 0 && iid[2] == 0x000000C0 && iid[3] == 0x46000000) { *pp = t; return 0; }
    *pp = 0; return E_NOINTERFACE_;
}
static unsigned long WINAPI recb_addref(RECB* t) { return 1; }
static unsigned long WINAPI recb_release(RECB* t) { return 1; }
static long WINAPI recb_storage(RECB* t, void** stg) {
    void* lb = 0; long hr;
    *stg = 0;
    if (!p_CreateILockBytesOnHGlobal || !p_StgCreateDocfileOnILockBytes) return E_NOTIMPL_;
    hr = p_CreateILockBytesOnHGlobal(0, 1, &lb);
    if (hr || !lb) return hr ? hr : E_NOTIMPL_;
    hr = p_StgCreateDocfileOnILockBytes(lb, 0x00001012 /*SHARE_EXCLUSIVE|CREATE|READWRITE*/, 0, stg);
    ((unsigned long (WINAPI*)(void*))((*(void***)lb)[2]))(lb);     /* the storage holds its own reference */
    return hr;
}
static long WINAPI recb_inplace(RECB* t, void* a, void* b, void* c) { return E_NOTIMPL_; }
static long WINAPI recb_showui(RECB* t, BOOL show) { return 0; }
static long WINAPI recb_queryinsert(RECB* t, void* clsid, void* stg, long cp) { return 0; }
static long WINAPI recb_delete(RECB* t, void* obj) { return 0; }
static long WINAPI recb_acceptdata(RECB* t, void* dobj, void* cf, DWORD reco, BOOL really, void* mp) { return 0; }
static long WINAPI recb_help(RECB* t, BOOL on) { return 0; }
static long WINAPI recb_clipdata(RECB* t, void* chrg, DWORD reco, void** dobj) { return E_NOTIMPL_; }
static long WINAPI recb_dragdrop(RECB* t, BOOL drag, DWORD keys, DWORD* effect) { return E_NOTIMPL_; }
static long WINAPI recb_menu(RECB* t, DWORD seltype, void* obj, void* chrg, void** menu) { return E_NOTIMPL_; }
static void* g_recbVtbl[13];
static RECB  g_recb;
static void* ole_callback(void) {
    if (!g_recb.vtbl) {
        g_recbVtbl[0] = (void*)recb_qi;        g_recbVtbl[1] = (void*)recb_addref;   g_recbVtbl[2] = (void*)recb_release;
        g_recbVtbl[3] = (void*)recb_storage;   g_recbVtbl[4] = (void*)recb_inplace;  g_recbVtbl[5] = (void*)recb_showui;
        g_recbVtbl[6] = (void*)recb_queryinsert; g_recbVtbl[7] = (void*)recb_delete; g_recbVtbl[8] = (void*)recb_acceptdata;
        g_recbVtbl[9] = (void*)recb_help;      g_recbVtbl[10] = (void*)recb_clipdata; g_recbVtbl[11] = (void*)recb_dragdrop;
        g_recbVtbl[12] = (void*)recb_menu;
        g_recb.vtbl = g_recbVtbl;
    }
    return &g_recb;
}

/* parent == 0 makes an invisible document: no host, no toolbar - for reports */
int wdoc_create(int parent, int x, int y, int w, int h, int flags) {
    int s;
    WDOC* d;
    DWORD es = WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_TABSTOP | ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN | ES_NOHIDESEL | ES_SAVESEL;
    if (!g_inited && wdoc_init() != 0) return 0;
    for (s = 1; s <= WD_MAX; s++) if (!g_d[s].edit) break;
    if (s > WD_MAX) return 0;
    d = &g_d[s];
    zero(d, sizeof(WDOC));
    d->flags = flags; d->hot = -1; d->down = -1;
    d->fore = 0x00262DDC;            /* red-ish default ink for the A bar  #DC2626 */
    d->back = 0x0000FFFF;            /* yellow highlighter                 */

    if (!parent) {
        d->flags = 0;
        d->edit = p_CreateWindowExA(0, "RICHEDIT50W", "", WS_POPUP | ES_MULTILINE | ES_WANTRETURN,
                                    0, 0, w > 0 ? w : 800, h > 0 ? h : 600, 0, 0, g_inst, 0);
        if (!d->edit) { g_step = -10; return 0; }
    } else {
        clip_children((void*)parent);
        d->host = p_CreateWindowExA(0, "myWordDocHost", "", WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS,
                                    x, y, w, h, (void*)parent, 0, g_inst, 0);
        if (!d->host) { g_step = -11; return 0; }
        d->edit = p_CreateWindowExA(0, "RICHEDIT50W", "", es, 0, 0, 10, 10, d->host, (void*)ID_EDIT, g_inst, 0);
        if (!d->edit) { p_DestroyWindow(d->host); d->host = 0; g_step = -12; return 0; }
        if (flags & WDF_TOOLBAR) {
            static const char* sizes[] = { "8","9","10","11","12","14","16","18","20","22","24","26","28","36","48","72", 0 };
            LOGFONTA lf; int i;
            d->cbFont = p_CreateWindowExA(0, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | WS_VSCROLL | CBS_DROPDOWNLIST | CBS_SORT | CBS_HASSTRINGS,
                                          0, 0, 10, 10, d->host, (void*)ID_FONT, g_inst, 0);
            d->cbSize = p_CreateWindowExA(0, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | WS_VSCROLL | CBS_DROPDOWNLIST | CBS_HASSTRINGS,
                                          0, 0, 10, 10, d->host, (void*)ID_SIZE, g_inst, 0);
            p_SendMessageA(d->cbFont, WM_SETFONT, (unsigned long)g_fUI, 0);
            p_SendMessageA(d->cbSize, WM_SETFONT, (unsigned long)g_fUI, 0);
            p_SendMessageA(d->cbFont, CB_SETDROPPEDWIDTH, (unsigned long)px(220), 0);
            zero(&lf, sizeof(lf)); lf.lfCharSet = DEFAULT_CHARSET;
            p_EnumFontFamiliesExA(g_scrDC, &lf, font_enum, (long)d->cbFont, 0);
            for (i = 0; sizes[i]; i++) p_SendMessageA(d->cbSize, CB_ADDSTRING, 0, (unsigned long)sizes[i]);
        }
        p_SendMessageA(d->edit, EM_SETMARGINS, EC_LEFTMARGIN | EC_RIGHTMARGIN, (unsigned long)((px(12) << 16) | px(12)));
        p_SendMessageA(d->edit, EM_SETEVENTMASK, 0, ENM_CHANGE | ENM_SELCHANGE);
    }
    p_SendMessageA(d->edit, EM_EXLIMITTEXT, 0, 0x7FFFFFFF);
    p_SendMessageA(d->edit, EM_SETOLECALLBACK, 0, (unsigned long)ole_callback());   /* BMP / EMF / WMF pictures */
    if (flags & WDF_READONLY) p_SendMessageA(d->edit, EM_SETREADONLY, 1, 0);
    /* default typing font: Segoe UI 11pt */
    {   CF2A cf; zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
        cf.dwMask = CFM_FACE | CFM_SIZE | CFM_CHARSET | CFM_COLOR; cf.dwEffects = CFE_AUTOCOLOR;
        cf.yHeight = 220; cf.bCharSet = DEFAULT_CHARSET; scpy(cf.szFaceName, "Segoe UI", 32);
        p_SendMessageA(d->edit, EM_SETCHARFORMAT, SCF_ALL, (unsigned long)&cf);
    }
    p_SendMessageA(d->edit, EM_SETMODIFY, 0, 0);
    if (d->host) {
        layout(d);
        p_SetWindowPos(d->host, 0 /*HWND_TOP*/, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
        refresh_state(d);
    }
    return s;
}

void wdoc_destroy(int h) {
    WDOC* d = D(h);
    if (!d) return;
    if (d->host) p_DestroyWindow(d->host);      /* takes the editor + combos with it */
    else p_DestroyWindow(d->edit);
    mem_free(d->buf); mem_free(d->pstart); mem_free(d->pused);
    mem_free(d->runs); mem_free(d->faces); mem_free(d->fchars);
    if (d->tom) ((unsigned long (WINAPI*)(void*))((*(void***)d->tom)[2]))(d->tom);
    zero(d, sizeof(WDOC));
}

int  wdoc_alive(int h)  { return D(h) ? 1 : 0; }
int  wdoc_hwnd(int h)   { WDOC* d = D(h); return d ? (int)(d->host ? d->host : d->edit) : 0; }
int  wdoc_edit_hwnd(int h) { WDOC* d = D(h); return d ? (int)d->edit : 0; }
void wdoc_move(int h, int x, int y, int w, int hh) { WDOC* d = D(h); if (d && d->host) p_MoveWindow(d->host, x, y, w, hh, 1); }
void wdoc_show(int h, int on) { WDOC* d = D(h); if (d && d->host) p_ShowWindow(d->host, on ? 5 : 0); }
void wdoc_enable(int h, int on) { WDOC* d = D(h); if (d && d->host) { p_EnableWindow(d->host, on); p_EnableWindow(d->edit, on); } }
void wdoc_focus(int h) { WDOC* d = D(h); if (d) p_SetFocus(d->edit); }
int  wdoc_has_focus(int h) {
    WDOC* d = D(h); void* f;
    if (!d) return 0;
    f = p_GetFocus();
    return f && (f == d->edit || (d->host && (f == d->host || p_IsChild(d->host, f)))) ? 1 : 0;
}
void wdoc_set_flags(int h, int flags) {
    WDOC* d = D(h);
    if (!d || !d->host) return;
    if ((flags & WDF_TOOLBAR) && !d->cbFont) flags &= ~WDF_TOOLBAR;   /* combos are made at create time */
    d->flags = flags;
    p_SendMessageA(d->edit, EM_SETREADONLY, (flags & WDF_READONLY) ? 1 : 0, 0);
    if (d->cbFont) { p_ShowWindow(d->cbFont, (flags & WDF_TOOLBAR) ? 5 : 0); p_ShowWindow(d->cbSize, (flags & WDF_TOOLBAR) ? 5 : 0); }
    layout(d);
}

/* ========================================================================== */
/*  Content                                                                    */
/* ========================================================================== */
int wdoc_load(int h, const char* buf, int len) {
    WDOC* d = D(h); int ok;
    if (!d) return 0;
    if (len <= 0) { E(d, EM_SETSEL, 0, (unsigned long)-1); E(d, EM_REPLACESEL, 0, (unsigned long)""); ok = 1; }
    else ok = stream_in(d, buf, len, 0);
    E(d, EM_SETSEL, 0, 0);
    E(d, EM_EMPTYUNDOBUFFER, 0, 0);         /* Undo never goes back past a load */
    E(d, EM_SETMODIFY, 0, 0);
    d->seq++;
    refresh_state(d);
    return ok;
}
/* fmt 0 = RTF, 1 = plain text. Returns the length; fetch it with wdoc_copy. */
int wdoc_save(int h, int fmt) {
    WDOC* d = D(h); EDITSTREAM es;
    if (!d) return 0;
    d->len = 0;
    es.dwCookie = (DWORD)d; es.dwError = 0; es.pfnCallback = cb_out;
    E(d, EM_STREAMOUT, fmt == 1 ? SF_TEXT : SF_RTF, (unsigned long)&es);
    return (int)d->len;
}
int wdoc_copy(int h, char* dst, int cap) {
    WDOC* d = D(h); long n, i;
    if (!d || !d->buf) return 0;
    n = d->len < cap ? d->len : cap;
    for (i = 0; i < n; i++) dst[i] = d->buf[i];
    return (int)n;
}
int wdoc_insert_rtf(int h, const char* buf, int len) { WDOC* d = D(h); int r; if (!d) return 0; r = stream_in(d, buf, len, 1); d->seq++; return r; }
void wdoc_insert_text(int h, const char* s) { WDOC* d = D(h); if (d) { E(d, EM_REPLACESEL, 1, (unsigned long)s); d->seq++; } }
int wdoc_length(int h) {
    WDOC* d = D(h); GETTEXTLENGTHEX g;
    if (!d) return 0;
    g.flags = GTL_PRECISE | GTL_NUMCHARS; g.codepage = 1200;
    return (int)E(d, EM_GETTEXTLENGTHEX, (unsigned long)&g, 0);
}
int  wdoc_get_modified(int h) { WDOC* d = D(h); return d ? (E(d, EM_GETMODIFY, 0, 0) ? 1 : 0) : 0; }
void wdoc_set_modified(int h, int on) { WDOC* d = D(h); if (d) E(d, EM_SETMODIFY, on ? 1 : 0, 0); }
int  wdoc_seq(int h)    { WDOC* d = D(h); return d ? d->seq : 0; }
int  wdoc_selseq(int h) { WDOC* d = D(h); return d ? d->selseq : 0; }
int  wdoc_picks(int h)  { WDOC* d = D(h); return d ? d->lastPick : 0; }

/* ========================================================================== */
/*  Formatting API                                                             */
/* ========================================================================== */
/* effect: 1 bold, 2 italic, 3 underline, 4 strikeout; how: 0 off, 1 on, 2 toggle */
void wdoc_effect(int h, int which, int how) {
    static const DWORD bits[] = { 0, CFM_BOLD, CFM_ITALIC, CFM_UNDERLINE, CFM_STRIKEOUT };
    WDOC* d = D(h);
    if (!d || which < 1 || which > 4) return;
    effect(d, bits[which], how); d->seq++; refresh_state(d);
}
void wdoc_set_face(int h, const char* face) { WDOC* d = D(h); if (d) { set_face(d, face); refresh_state(d); } }
void wdoc_set_size(int h, int pt10)         { WDOC* d = D(h); if (d && pt10 > 0) { set_size(d, pt10); refresh_state(d); } }
void wdoc_set_color(int h, int c)           { WDOC* d = D(h); if (d) set_color(d, (DWORD)c, 0); }
void wdoc_set_back(int h, int c)            { WDOC* d = D(h); if (d) set_color(d, (DWORD)c, 1); }
void wdoc_set_align(int h, int a)           { WDOC* d = D(h); if (d) { para_align(d, a); refresh_state(d); } }
void wdoc_set_numbering(int h, int style)   { WDOC* d = D(h); if (d) { para_numbering(d, style, 0); refresh_state(d); } }
void wdoc_indent(int h, int deltaTw)        { WDOC* d = D(h); if (d) para_indent(d, deltaTw); }

/* which: 1 bold 2 italic 3 underline 4 strike 5 size(pt*10) 6 colour 7 back colour
          8 align 9 numbering ; -1 = mixed across the selection */
int wdoc_get_format(int h, int which) {
    WDOC* d = D(h); CF2A cf; PF2 pf;
    if (!d) return 0;
    if (which <= 7) {
        zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
        E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
        switch (which) {
        case 1: return (cf.dwMask & CFM_BOLD) ? ((cf.dwEffects & CFM_BOLD) ? 1 : 0) : -1;
        case 2: return (cf.dwMask & CFM_ITALIC) ? ((cf.dwEffects & CFM_ITALIC) ? 1 : 0) : -1;
        case 3: return (cf.dwMask & CFM_UNDERLINE) ? ((cf.dwEffects & CFM_UNDERLINE) ? 1 : 0) : -1;
        case 4: return (cf.dwMask & CFM_STRIKEOUT) ? ((cf.dwEffects & CFM_STRIKEOUT) ? 1 : 0) : -1;
        case 5: return (cf.dwMask & CFM_SIZE) ? (int)(cf.yHeight / 2) : -1;
        case 6: return (cf.dwMask & CFM_COLOR) ? ((cf.dwEffects & CFE_AUTOCOLOR) ? 0 : (int)cf.crTextColor) : -1;
        case 7: return (cf.dwMask & CFM_BACKCOLOR) ? ((cf.dwEffects & CFE_AUTOBACKCOLOR) ? 0x00FFFFFF : (int)cf.crBackColor) : -1;
        }
        return 0;
    }
    zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    E(d, EM_GETPARAFORMAT, 0, (unsigned long)&pf);
    if (which == 8) return (pf.dwMask & PFM_ALIGNMENT) ? (pf.wAlignment ? pf.wAlignment : 1) : -1;
    if (which == 9) return (pf.dwMask & PFM_NUMBERING) ? pf.wNumbering : -1;
    return 0;
}
int wdoc_get_face(int h, char* dst, int cap) {
    WDOC* d = D(h); CF2A cf;
    if (!d || cap <= 0) return 0;
    zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
    if (!(cf.dwMask & CFM_FACE)) { dst[0] = 0; return 0; }
    scpy(dst, cf.szFaceName, cap);
    return slen(dst);
}

/* 1 undo 2 redo 3 cut 4 copy 5 paste 6 select all 7 delete selection 8 select none */
void wdoc_command(int h, int cmd) {
    WDOC* d = D(h);
    if (!d) return;
    switch (cmd) {
    case 1: E(d, EM_UNDO, 0, 0); break;
    case 2: E(d, EM_REDO, 0, 0); break;
    case 3: E(d, WM_CUT, 0, 0); break;
    case 4: E(d, WM_COPY, 0, 0); break;
    case 5: E(d, WM_PASTE, 0, 0); break;
    case 6: E(d, EM_SETSEL, 0, (unsigned long)-1); break;
    case 7: E(d, WM_CLEAR, 0, 0); break;
    case 8: E(d, EM_SETSEL, (unsigned long)-1, 0); break;
    }
    refresh_state(d);
}
int wdoc_can(int h, int what) {           /* 1 undo, 2 redo */
    WDOC* d = D(h);
    if (!d) return 0;
    return (int)E(d, what == 2 ? EM_CANREDO : EM_CANUNDO, 0, 0) ? 1 : 0;
}
void wdoc_set_readonly(int h, int on) {
    WDOC* d = D(h);
    if (!d) return;
    if (on) d->flags |= WDF_READONLY; else d->flags &= ~WDF_READONLY;
    E(d, EM_SETREADONLY, on ? 1 : 0, 0);
}
void wdoc_set_zoom(int h, int pct) { WDOC* d = D(h); if (d) E(d, EM_SETZOOM, pct > 0 ? (unsigned long)pct : 0, pct > 0 ? 100 : 0); }
void wdoc_set_paper(int h, int c) { WDOC* d = D(h); if (d) E(d, EM_SETBKGNDCOLOR, c < 0 ? 1 : 0, (unsigned long)(c < 0 ? 0 : c)); }
/* wrap the editor at the PRINTED width (twips), so lines break where they will
   on paper. 0 = wrap at the window edge. */
void wdoc_set_page_width(int h, int tw) {
    WDOC* d = D(h);
    if (!d) return;
    d->pageTw = tw > 0 ? tw : 0;
    E(d, EM_SETTARGETDEVICE, d->pageTw ? (unsigned long)g_refDC : 0, (unsigned long)d->pageTw);
    if (d->host) layout(d);
}
void wdoc_select(int h, int from, int to) { WDOC* d = D(h); if (d) { CHARRANGE r; r.cpMin = from; r.cpMax = to; E(d, EM_EXSETSEL, 0, (unsigned long)&r); } }
int  wdoc_sel(int h, int which) { WDOC* d = D(h); CHARRANGE r; if (!d) return 0; E(d, EM_EXGETSEL, 0, (unsigned long)&r); return which == 2 ? r.cpMax : r.cpMin; }
/* finds forward from the caret and selects the hit; returns its position or -1 */
int wdoc_find(int h, const char* text, int matchCase, int wholeWord) {
    WDOC* d = D(h); FINDTEXTEXW ft; CHARRANGE cur; long r; WCHAR w[256]; DWORD fl;
    if (!d || !text || !text[0]) return -1;
    if (!p_MultiByteToWideChar(0 /*CP_ACP*/, 0, text, -1, w, 256)) return -1;
    fl = FR_DOWN | (matchCase ? FR_MATCHCASE : 0) | (wholeWord ? FR_WHOLEWORD : 0);
    E(d, EM_EXGETSEL, 0, (unsigned long)&cur);
    ft.chrg.cpMin = cur.cpMax; ft.chrg.cpMax = -1; ft.lpstrText = w;
    r = E(d, EM_FINDTEXTEXW, fl, (unsigned long)&ft);
    if (r < 0 && cur.cpMax > 0) {       /* wrap around to the top */
        ft.chrg.cpMin = 0; ft.chrg.cpMax = -1;
        r = E(d, EM_FINDTEXTEXW, fl, (unsigned long)&ft);
    }
    if (r >= 0) E(d, EM_EXSETSEL, 0, (unsigned long)&ft.chrgText);
    return (int)r;
}

/* ========================================================================== */
/*  Printing: pages / band chunks as vector metafiles                          */
/* ========================================================================== */
static void fr_setup(WDOC* d, FORMATRANGE* fr, void* dc, int wTw, int hTw, long from) {
    fr->hdc = dc; fr->hdcTarget = g_refDC;
    fr->rc.left = 0; fr->rc.top = 0; fr->rc.right = wTw; fr->rc.bottom = hTw;
    fr->rcPage = fr->rc;
    fr->chrg.cpMin = from; fr->chrg.cpMax = -1;
}
/* Splits the document into pages wTw x hTw (twips). Returns the page count.
   Use a band's size to flow a long document across many report pages. */
int wdoc_paginate(int h, int wTw, int hTw) {
    WDOC* d = D(h); FORMATRANGE fr; long cp = 0, total, next; int guard = 0;
    if (!d || wTw <= 0 || hTw <= 0) return 0;
    total = wdoc_length(h);
    d->pages = 0;
    do {
        if (d->pages >= d->pcap) {
            int nc = d->pcap ? d->pcap * 2 : 64;
            long* a = (long*)mem_grow(d->pstart, nc * 4);
            long* b = (long*)mem_grow(d->pused, nc * 4);
            if (!a || !b) break;
            d->pstart = a; d->pused = b; d->pcap = nc;
        }
        fr_setup(d, &fr, g_refDC, wTw, hTw, cp);
        next = E(d, EM_FORMATRANGE, 0, (unsigned long)&fr);   /* measure only */
        d->pstart[d->pages] = cp;
        d->pused[d->pages]  = fr.rc.bottom;                    /* RichEdit trims this to what it used */
        d->pages++;
        if (next <= cp) next = cp + 1;                         /* an object taller than the page: skip on */
        cp = next;
    } while (cp < total && ++guard < 100000);
    E(d, EM_FORMATRANGE, 0, 0);                                /* release RichEdit's cache */
    return d->pages;
}
int wdoc_page_start(int h, int page) { WDOC* d = D(h); return d && page >= 1 && page <= d->pages ? (int)d->pstart[page - 1] : -1; }
int wdoc_page_used(int h, int page)  { WDOC* d = D(h); return d && page >= 1 && page <= d->pages ? (int)d->pused[page - 1] : 0; }

/* ---- pictures for the WMF -------------------------------------------------
   RichEdit draws a picture with AlphaBlend, pre-scaled to the reference
   device (a 360x200 PNG arrives as a 2250x1250 32-bit bitmap at 600 dpi).
   A Windows metafile has no alpha blend, so GetWinMetaFileBits just drops
   it. We walk the EMF ourselves, composite each such bitmap onto white,
   box-filter it down to PIC_DPI, and hand it on as a META_STRETCHDIB record.
   The WMF's logical units are the EMF's device pixels (its SETWINDOWEXT is
   the frame in reference-device pixels), so the destination carries over. */
#define PIC_DPI 200
typedef struct { BYTE* p; long len, cap; } GROW;
static int grow_put(GROW* g, const void* src, long n) {
    long i;
    if (g->len + n > g->cap) {
        long nc = g->cap ? g->cap * 2 : 65536; BYTE* nb;
        while (nc < g->len + n) nc *= 2;
        nb = (BYTE*)mem_grow(g->p, nc);
        if (!nb) return 0;
        g->p = nb; g->cap = nc;
    }
    for (i = 0; i < n; i++) g->p[g->len + i] = ((const BYTE*)src)[i];
    g->len += n;
    return 1;
}
static void put16(BYTE* o, long v) { o[0] = (BYTE)v; o[1] = (BYTE)(v >> 8); }
static void put32(BYTE* o, long v) { o[0] = (BYTE)v; o[1] = (BYTE)(v >> 8); o[2] = (BYTE)(v >> 16); o[3] = (BYTE)(v >> 24); }

/* EMR_ALPHABLEND: rclBounds@8 xDest@24 yDest@28 cxDest@32 cyDest@36 blend@40
   xSrc@44 ySrc@48 xform@52 bk@76 usage@80 offBmi@84 cbBmi@88 offBits@92
   cbBits@96 cxSrc@100 cySrc@104 */
static void alphablend_to_stretchdib(const BYTE* r, long rsz, GROW* out) {
    long xD = (long)le32(r + 24), yD = (long)le32(r + 28), cxD = (long)le32(r + 32), cyD = (long)le32(r + 36);
    BYTE konst = r[42];                              /* BLENDFUNCTION.SourceConstantAlpha */
    BYTE flags = r[43];                              /* BLENDFUNCTION.AlphaFormat (1 = per-pixel) */
    long xS = (long)le32(r + 44), yS = (long)le32(r + 48);
    long offBmi = (long)le32(r + 84), offBits = (long)le32(r + 92);
    long cxS = (long)le32(r + 100), cyS = (long)le32(r + 104);
    const BYTE* bmi; const BYTE* bits;
    long bw, bh, bpp, stride, k, ow, oh, ostride, dib, x, y, rec;
    int topdown, dpi;
    BYTE* recb;
    if (offBmi <= 0 || offBits <= 0 || offBmi + 40 > rsz || cxS <= 0 || cyS <= 0 || cxD <= 0 || cyD <= 0) return;
    bmi = r + offBmi; bits = r + offBits;
    bw = (long)le32(bmi + 4); bh = (long)le32(bmi + 8);
    bpp = bmi[14] | (bmi[15] << 8);
    if (bpp != 32 && bpp != 24) return;
    topdown = bh < 0; if (bh < 0) bh = -bh;
    stride = ((bw * bpp + 31) / 32) * 4;
    if (offBits + stride * bh > rsz) return;
    if (xS < 0 || yS < 0 || xS + cxS > bw || yS + cyS > bh) return;
    /* how far to shrink: never sharper than PIC_DPI on paper */
    dpi = p_GetDeviceCaps(g_refDC, LOGPIXELSX); if (dpi <= 0) dpi = 96;
    {   long want = cxD * PIC_DPI / dpi; if (want < 1) want = 1;
        k = (cxS + want - 1) / want; if (k < 1) k = 1; }
    ow = (cxS + k - 1) / k; oh = (cyS + k - 1) / k;
    ostride = ((ow * 24 + 31) / 32) * 4;
    dib = 40 + ostride * oh;
    rec = 6 + 22 + dib;
    recb = (BYTE*)mem_alloc(rec);
    if (!recb) return;
    put32(recb, rec / 2); put16(recb + 4, 0x0F43);              /* META_STRETCHDIB */
    put16(recb + 6, 0x0020); put16(recb + 8, 0x00CC);          /* SRCCOPY */
    put16(recb + 10, 0);                                        /* DIB_RGB_COLORS */
    put16(recb + 12, oh); put16(recb + 14, ow); put16(recb + 16, 0); put16(recb + 18, 0);
    put16(recb + 20, cyD); put16(recb + 22, cxD); put16(recb + 24, yD); put16(recb + 26, xD);
    {   BYTE* hd = recb + 28;
        put32(hd, 40); put32(hd + 4, ow); put32(hd + 8, oh); put16(hd + 12, 1); put16(hd + 14, 24);
        put32(hd + 16, 0); put32(hd + 20, ostride * oh);
    }
    for (y = 0; y < oh; y++) {                 /* y counts from the TOP of the picture */
        BYTE* orow = recb + 28 + 40 + (oh - 1 - y) * ostride;   /* written bottom-up */
        for (x = 0; x < ow; x++) {
            long sb = 0, sg = 0, sr = 0, n = 0, yy, xx;
            for (yy = y * k; yy < y * k + k && yy < cyS; yy++) {
                long srow = yS + yy;
                const BYTE* row = bits + (topdown ? srow : bh - 1 - srow) * stride;
                for (xx = x * k; xx < x * k + k && xx < cxS; xx++) {
                    const BYTE* q = row + (xS + xx) * (bpp / 8);
                    long b = q[0], g = q[1], rr = q[2];
                    if (bpp == 32) {
                        if (flags & 1) {               /* premultiplied: over white */
                            long a = q[3];
                            b += 255 - a; g += 255 - a; rr += 255 - a;
                        }
                        if (konst < 255) {
                            b  = (b  * konst + 255 * (255 - konst)) / 255;
                            g  = (g  * konst + 255 * (255 - konst)) / 255;
                            rr = (rr * konst + 255 * (255 - konst)) / 255;
                        }
                        if (b > 255) b = 255;
                        if (g > 255) g = 255;
                        if (rr > 255) rr = 255;
                    }
                    sb += b; sg += g; sr += rr; n++;
                }
            }
            if (n) { orow[x * 3] = (BYTE)(sb / n); orow[x * 3 + 1] = (BYTE)(sg / n); orow[x * 3 + 2] = (BYTE)(sr / n); }
        }
    }
    grow_put(out, recb, rec);
    mem_free(recb);
}
/* Reads the EMF once, on the way: collects its pictures (above) and fixes its
   symbol-font text. RichEdit writes a Symbol/Wingdings character as U+F0xx -
   the private-use range symbol fonts are addressed through - and the ANSI
   conversion into a WMF has no mapping for it, so a bullet prints as "?".
   U+F0xx -> U+00xx is the same character to a symbol font, and converts.
   Returns a fresh EMF handle (the caller deletes it), or 0 to use the original. */
static void* prepare_emf(void* emf, GROW* out) {
    UINT n = p_GetEnhMetaFileBits ? p_GetEnhMetaFileBits(emf, 0, 0) : 0;
    BYTE* e; long p = 0; int fixed = 0; void* again = 0;
    if (!n) return 0;
    e = (BYTE*)mem_alloc((long)n);
    if (!e) return 0;
    p_GetEnhMetaFileBits(emf, n, e);
    while (p + 8 <= (long)n) {
        DWORD t = le32(e + p), sz = le32(e + p + 4);
        if (sz < 8 || p + (long)sz > (long)n) break;
        if (t == 114 /*EMR_ALPHABLEND*/ && sz >= 108) alphablend_to_stretchdib(e + p, (long)sz, out);
        if (t == 84 /*EMR_EXTTEXTOUTW*/ && sz >= 76) {
            long nch = (long)le32(e + p + 44), off = (long)le32(e + p + 48), i;
            if (off > 0 && off + nch * 2 <= (long)sz)
                for (i = 0; i < nch; i++) {
                    BYTE* c = e + p + off + i * 2;
                    WORD  u = (WORD)(c[0] | (c[1] << 8));
                    if (c[1] == 0xF0) { c[1] = 0; fixed = 1; }
                    /* RichEdit draws list bullets as U+2981 in Segoe UI Symbol;
                       U+2022 is the same dot and exists in the ANSI code page */
                    else if (u == 0x2981 || u == 0x25CF || u == 0x2219) { c[0] = 0x22; c[1] = 0x20; fixed = 1; }
                }
        }
        if (t == 14 /*EMR_EOF*/) break;
        p += (long)sz;
    }
    if (fixed && p_SetEnhMetaFileBits) again = p_SetEnhMetaFileBits(n, e);
    mem_free(e);
    return again;
}

/* Writes a placeable WMF: the 22-byte Aldus header (bounding box in twips,
   1440 units per inch) followed by the Windows-format records. */
static int write_wmf(void* emf, const char* path, int wTw, int hTw) {
    UINT n; BYTE* bits; BYTE* out; BYTE hdr[22]; WORD* w = (WORD*)hdr; WORD sum = 0; int i;
    void* f; DWORD put_ = 0, maxRec = 0; long ip, op; int ok;
    GROW pics;
    void* fixedEmf;
    pics.p = 0; pics.len = 0; pics.cap = 0;
    fixedEmf = prepare_emf(emf, &pics);
    if (fixedEmf) emf = fixedEmf;
    n = p_GetWinMetaFileBits(emf, 0, 0, 8 /*MM_ANISOTROPIC*/, g_refDC);
    bits = n ? (BYTE*)mem_alloc((long)n) : 0;
    out  = n ? (BYTE*)mem_alloc((long)n + (long)n / 2 + pics.len + 64) : 0;
    if (!bits || !out) { mem_free(bits); mem_free(out); mem_free(pics.p); if (fixedEmf) p_DeleteEnhMetaFile(fixedEmf); return 0; }
    p_GetWinMetaFileBits(emf, n, bits, 8, g_refDC);
    if (fixedEmf) p_DeleteEnhMetaFile(fixedEmf);

    /* Copy the records. Three edits on the way:
       - our converted pictures go in just before the EOF record;
       - the "WMFC" comments are dropped (see below);
       - a META_DIBBITBLT that carries a bitmap becomes META_STRETCHDIB, the
         record Clarion's own IMAGE control emits. */
    for (i = 0; i < 18; i++) out[i] = bits[i];
    ip = 18; op = 18;
    while (ip + 6 <= (long)n) {
        DWORD rs = le32(bits + ip);                       /* record size in WORDs */
        WORD  fn = (WORD)(bits[ip + 4] | (bits[ip + 5] << 8));
        if (rs < 3 || ip + (long)rs * 2 > (long)n) break;
        if (fn == 0 && pics.len) {
            long k = 0, j;
            while (k < pics.len) {
                DWORD prs = le32(pics.p + k);
                for (j = 0; j < (long)prs * 2; j++) out[op + j] = pics.p[k + j];
                op += (long)prs * 2; k += (long)prs * 2;
                if (prs > maxRec) maxRec = prs;
            }
        }
        /* MFCOMMENT "WMFC": GetWinMetaFileBits tucks a whole copy of the EMF
           into the WMF so it can be converted back. Nothing here reads it, and
           with a picture on the page it is megabytes. */
        if (fn == 0x0626 && rs >= 7 && bits[ip + 6] == 15 && bits[ip + 10] == 'W' &&
            bits[ip + 11] == 'M' && bits[ip + 12] == 'F' && bits[ip + 13] == 'C') {
            ip += (long)rs * 2;
            continue;
        }
        if (fn == 0x0940 && rs * 2 > 6 + 16 + 40) {
            /* DIBBITBLT params: rop(2w) ySrc xSrc h w yDst xDst, then the DIB
               STRETCHDIB params: rop(2w) usage srcH srcW ySrc xSrc dstH dstW yDst xDst, DIB */
            const BYTE* pr = bits + ip + 6;
            WORD ySrc = (WORD)(pr[4] | pr[5] << 8), xSrc = (WORD)(pr[6] | pr[7] << 8);
            WORD hh = (WORD)(pr[8] | pr[9] << 8),   ww = (WORD)(pr[10] | pr[11] << 8);
            WORD yD = (WORD)(pr[12] | pr[13] << 8), xD = (WORD)(pr[14] | pr[15] << 8);
            long dib = (long)rs * 2 - 6 - 16;
            long bw = (long)le32(pr + 16 + 4), bh = (long)le32(pr + 16 + 8);
            DWORD nrs = rs + 3; WORD* o;
            long k;
            if (bh < 0) bh = -bh;
            out[op] = (BYTE)nrs; out[op + 1] = (BYTE)(nrs >> 8); out[op + 2] = (BYTE)(nrs >> 16); out[op + 3] = (BYTE)(nrs >> 24);
            out[op + 4] = 0x43; out[op + 5] = 0x0F;
            o = (WORD*)(out + op + 6);
            o[0] = (WORD)(pr[0] | pr[1] << 8); o[1] = (WORD)(pr[2] | pr[3] << 8);   /* rop */
            o[2] = 0;                                                                /* DIB_RGB_COLORS */
            o[3] = (WORD)(hh < bh ? hh : bh); o[4] = (WORD)(ww < bw ? ww : bw);      /* source extent, DIB pixels */
            o[5] = ySrc; o[6] = xSrc;
            o[7] = hh; o[8] = ww; o[9] = yD; o[10] = xD;
            for (k = 0; k < dib; k++) out[op + 6 + 22 + k] = pr[16 + k];
            op += (long)nrs * 2;
            if (nrs > maxRec) maxRec = nrs;
        } else {
            long k;
            for (k = 0; k < (long)rs * 2; k++) out[op + k] = bits[ip + k];
            op += (long)rs * 2;
            if (rs > maxRec) maxRec = rs;
        }
        ip += (long)rs * 2;
    }
    /* fix the header: total size and largest record, in WORDs */
    {   DWORD tot = (DWORD)(op / 2);
        out[6] = (BYTE)tot; out[7] = (BYTE)(tot >> 8); out[8] = (BYTE)(tot >> 16); out[9] = (BYTE)(tot >> 24);
        out[12] = (BYTE)maxRec; out[13] = (BYTE)(maxRec >> 8); out[14] = (BYTE)(maxRec >> 16); out[15] = (BYTE)(maxRec >> 24);
    }

    zero(hdr, sizeof(hdr));
    w[0] = 0xCDD7; w[1] = 0x9AC6;            /* key */
    w[3] = 0; w[4] = 0;                        /* bbox left, top */
    w[5] = (WORD)wTw; w[6] = (WORD)hTw;        /* bbox right, bottom */
    w[7] = 1440;                               /* units per inch */
    for (i = 0; i < 10; i++) sum ^= w[i];
    w[10] = sum;
    f = p_CreateFileA(path, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, 0, 0);
    if (!f || f == (void*)-1) { mem_free(bits); mem_free(out); mem_free(pics.p); return 0; }
    ok = p_WriteFile(f, hdr, 22, &put_, 0) && p_WriteFile(f, out, (DWORD)op, &put_, 0);
    p_CloseHandle(f);
    mem_free(bits); mem_free(out); mem_free(pics.p);
    return ok ? 1 : 0;
}

static int ends_with_wmf(const char* p) {
    int n = slen(p);
    return n > 4 && p[n - 4] == '.' && (p[n - 3] | 32) == 'w' && (p[n - 2] | 32) == 'm' && (p[n - 1] | 32) == 'f';
}

/* Draws page N (from the last wdoc_paginate) into a metafile: an enhanced
   metafile for a .emf path, a placeable Windows metafile for .wmf (which is
   what a Clarion REPORT IMAGE plays). hTw may be less than the paginated
   height to trim the last page. 1 = ok. */
int wdoc_render_page(int h, int page, int wTw, int hTw, const char* path) {
    WDOC* d = D(h); FORMATRANGE fr; RECT frame; void* mdc; void* emf; int wmf, ok = 1;
    if (!d || page < 1 || page > d->pages || wTw <= 0 || hTw <= 0) return 0;
    wmf = ends_with_wmf(path);
    frame.left = 0; frame.top = 0;
    frame.right = wTw * 2540 / 1440; frame.bottom = hTw * 2540 / 1440;    /* .01 mm */
    mdc = p_CreateEnhMetaFileA(g_refDC, wmf ? 0 : path, &frame, "myWordDoc\0page\0");
    if (!mdc) return 0;
    fr_setup(d, &fr, mdc, wTw, hTw, d->pstart[page - 1]);
    fr.chrg.cpMax = page < d->pages ? d->pstart[page] : -1;
    E(d, EM_FORMATRANGE, 1, (unsigned long)&fr);
    E(d, EM_FORMATRANGE, 0, 0);
    emf = p_CloseEnhMetaFile(mdc);
    if (!emf) return 0;
    if (wmf) ok = write_wmf(emf, path, wTw, hTw);
    p_DeleteEnhMetaFile(emf);       /* the handle only - an .emf stays on disk */
    return ok;
}

/* %TEMP%\wdoc_<pid>_<slot>_<page>.wmf - unique per process, document and page */
int wdoc_temp_name(int h, int page, char* dst, int cap) {
    char t[300]; char* o; DWORD n;
    if (cap < 64) return 0;
    n = p_GetTempPathA(260, t);
    if (n == 0 || n > 259) { t[0] = '.'; t[1] = 92; n = 2; }
    o = t + n;
    o = put(o, "wdoc_"); o = putn(o, (long)p_GetCurrentProcessId()); *o++ = '_';
    o = putn(o, h); *o++ = '_'; o = putn(o, page); o = put(o, ".wmf"); *o = 0;
    scpy(dst, t, cap);
    return slen(dst);
}
int wdoc_delete_file(const char* path) { return p_DeleteFileA ? p_DeleteFileA(path) : 0; }

/* ========================================================================== */
/*  Tools - what WordDocTools.clw builds its classes on                        */
/*    search / count / replace / highlight      (RtfSearchClass, RtfMergeClass) */
/*    character runs, fonts in use              (RtfFontClass)                  */
/*    plain text and statistics                 (RtfTextClass)                  */
/*    HTML and Markdown                         (RtfHtmlClass, RtfMarkdownClass)*/
/*  Every routine works on a live editor as well as a hidden document: it      */
/*  saves the user's selection and scroll position, works with notifications   */
/*  and painting off, and puts both back.                                      */
/*  Text results are left in the slot's buffer; Clarion fetches them with      */
/*  wdoc_copy, exactly like wdoc_save.                                         */
/* ========================================================================== */

/* ---- undo groups ------------------------------------------------------------
   RichEdit records every replace and every format change as its own undo step,
   so a Replace All of 19 words took 19 presses of Ctrl+Z. Between
   BeginEditCollection and EndEditCollection (TOM, RichEdit 8 = Windows 8 and
   later) everything collapses into ONE step for Ctrl+Z, the toolbar and
   WordDocClass.Undo. Groups nest; only the outermost pair talks to RichEdit.
   Where TOM is missing the edits simply stay separate steps. */
static void* tom_doc(WDOC* d) {
    static const DWORD iid[4] = { 0x8CC497C0, 0x11CEA1DF, 0xAA009880, 0x5DBE4700 };   /* ITextDocument */
    void* ole = 0;
    if (d->tom || d->tomTried) return d->tom;
    d->tomTried = 1;
    E(d, EM_GETOLEINTERFACE, 0, (unsigned long)&ole);
    if (!ole) return 0;
    ((long (WINAPI*)(void*, const DWORD*, void**))((*(void***)ole)[0]))(ole, iid, &d->tom);
    ((unsigned long (WINAPI*)(void*))((*(void***)ole)[2]))(ole);
    return d->tom;
}
static long tom_call(WDOC* d, int slot) {          /* 20 BeginEditCollection, 21 EndEditCollection */
    void* t = tom_doc(d);
    if (!t) return E_NOTIMPL_;
    return ((long (WINAPI*)(void*))((*(void***)t)[slot]))(t);
}
static void group_on(WDOC* d)  { if (d->group++ == 0) tom_call(d, 20); }
static void group_off(WDOC* d) { if (d->group > 0 && --d->group == 0) { tom_call(d, 21); if (d->host) p_InvalidateRect(d->host, 0, 0); } }
/* on: 1 opens a group, 0 closes it. Returns 1 when RichEdit groups undo here. */
int wdoc_undo_group(int h, int on) {
    WDOC* d = D(h);
    if (!d) return 0;
    if (on) group_on(d); else group_off(d);
    return tom_doc(d) ? 1 : 0;
}
void wdoc_undo_clear(int h) { WDOC* d = D(h); if (d) { E(d, EM_EMPTYUNDOBUFFER, 0, 0); if (d->host) p_InvalidateRect(d->host, 0, 0); } }
void wdoc_undo_limit(int h, int n) { WDOC* d = D(h); if (d) E(d, EM_SETUNDOLIMIT, (unsigned long)(n < 0 ? 0 : n), 0); }

/* ---- output buffer of UTF-16, converted once at the end ------------------ */
typedef struct { WCHAR* p; long len, cap; } WBUF;
static int wb_room(WBUF* b, long n) {
    if (b->len + n + 1 > b->cap) {
        long nc = b->cap ? b->cap * 2 : 32768; WCHAR* q;
        while (nc < b->len + n + 1) nc *= 2;
        q = (WCHAR*)mem_grow(b->p, nc * 2);
        if (!q) return 0;
        b->p = q; b->cap = nc;
    }
    return 1;
}
static void wb_ch(WBUF* b, WCHAR c) { if (wb_room(b, 1)) { b->p[b->len++] = c; b->p[b->len] = 0; } }
static void wb_str(WBUF* b, const char* s) {          /* ASCII only */
    long n = slen(s), i;
    if (n <= 0 || !wb_room(b, n)) return;
    for (i = 0; i < n; i++) b->p[b->len + i] = (WCHAR)(BYTE)s[i];
    b->len += n; b->p[b->len] = 0;
}
static void wb_num(WBUF* b, long v) { char t[16]; char* e = putn(t, v); *e = 0; wb_str(b, t); }
static void wb_ansi(WBUF* b, const char* s) {         /* text in the ANSI code page */
    int n;
    if (!s || !s[0]) return;
    n = p_MultiByteToWideChar(0, 0, s, -1, 0, 0);
    if (n <= 1 || !wb_room(b, n)) return;
    p_MultiByteToWideChar(0, 0, s, -1, b->p + b->len, n);
    b->len += n - 1; b->p[b->len] = 0;
}
static void wb_hex2(WBUF* b, int v) { static const char hx[] = "0123456789ABCDEF"; wb_ch(b, (WCHAR)hx[(v >> 4) & 15]); wb_ch(b, (WCHAR)hx[v & 15]); }
static void wb_color(WBUF* b, DWORD c) {               /* COLORREF -> #RRGGBB */
    wb_ch(b, '#'); wb_hex2(b, (int)(c & 255)); wb_hex2(b, (int)((c >> 8) & 255)); wb_hex2(b, (int)((c >> 16) & 255));
}
static void wb_pt(WBUF* b, long tw) {                  /* twips -> points, one decimal */
    long t = tw * 10 / 20;
    if (t < 0) { wb_ch(b, '-'); t = -t; }
    wb_num(b, t / 10);
    if (t % 10) { wb_ch(b, '.'); wb_ch(b, (WCHAR)('0' + t % 10)); }
    wb_str(b, "pt");
}
/* hands the result to the slot's buffer as UTF-8 (cp 65001) or ANSI (cp 0) */
static int wb_publish(WDOC* d, WBUF* b, UINT cp) {
    int n;
    d->len = 0;
    if (b->len > 0 && p_WideCharToMultiByte) {
        n = p_WideCharToMultiByte(cp, 0, b->p, (int)b->len, 0, 0, 0, 0);
        if (n > 0) {
            if (n + 1 > d->cap) {
                char* nb = (char*)mem_grow(d->buf, n + 1);
                if (nb) { d->buf = nb; d->cap = n + 1; }
            }
            if (n + 1 <= d->cap) { p_WideCharToMultiByte(cp, 0, b->p, (int)b->len, d->buf, n, 0, 0); d->len = n; d->buf[n] = 0; }
        }
    }
    mem_free(b->p); b->p = 0; b->len = b->cap = 0;
    return (int)d->len;
}

/* ---- byte buffer (RTF streamed out of a selection) ------------------------ */
typedef struct { char* p; long len, cap; } OBUF;
static DWORD WINAPI cb_obuf(DWORD cookie, BYTE* buf, long cb, long* pcb) {
    OBUF* o = (OBUF*)cookie; long i;
    if (o->len + cb + 1 > o->cap) {
        long nc = o->cap ? o->cap * 2 : 65536; char* q;
        while (nc < o->len + cb + 1) nc *= 2;
        q = (char*)mem_grow(o->p, nc);
        if (!q) { *pcb = 0; return 1; }
        o->p = q; o->cap = nc;
    }
    for (i = 0; i < cb; i++) o->p[o->len + i] = (char)buf[i];
    o->len += cb; o->p[o->len] = 0;
    *pcb = cb;
    return 0;
}

/* ---- quiet selection work ------------------------------------------------- */
typedef struct { CHARRANGE sel; POINT scroll; long mask; } QUIET;
static void sel2(WDOC* d, long a, long b) { CHARRANGE r; r.cpMin = a; r.cpMax = b; E(d, EM_EXSETSEL, 0, (unsigned long)&r); }
static void quiet_on(WDOC* d, QUIET* q) {
    E(d, EM_EXGETSEL, 0, (unsigned long)&q->sel);
    E(d, EM_GETSCROLLPOS, 0, (unsigned long)&q->scroll);
    q->mask = E(d, EM_SETEVENTMASK, 0, 0);
    if (d->host) E(d, WM_SETREDRAW, 0, 0);
}
/* keepSel = 0 puts the user's selection back; 1 leaves the new one and scrolls to it */
static void quiet_off(WDOC* d, QUIET* q, int keepSel) {
    if (!keepSel) { E(d, EM_EXSETSEL, 0, (unsigned long)&q->sel); E(d, EM_SETSCROLLPOS, 0, (unsigned long)&q->scroll); }
    E(d, EM_SETEVENTMASK, 0, (unsigned long)q->mask);
    if (d->host) {
        E(d, WM_SETREDRAW, 1, 0);
        if (keepSel) E(d, EM_SCROLLCARET, 0, 0);
        p_InvalidateRect(d->edit, 0, 1);
        d->selseq++;
        refresh_state(d);
    }
}
static long doc_len(WDOC* d) {
    GETTEXTLENGTHEX g; g.flags = GTL_PRECISE | GTL_NUMCHARS; g.codepage = 1200;
    return E(d, EM_GETTEXTLENGTHEX, (unsigned long)&g, 0);
}
/* the whole text as UTF-16: paragraphs end in CR, so index == character position */
static WCHAR* wtext(WDOC* d, long* pn) {
    GETTEXTEX gt; long n = doc_len(d); WCHAR* w = (WCHAR*)mem_alloc((n + 2) * 2);
    *pn = 0;
    if (!w) return 0;
    zero(&gt, sizeof(gt)); gt.cb = (DWORD)((n + 1) * 2); gt.flags = 4 /*GT_RAWTEXT: table marks + U+FFFC kept*/; gt.codepage = 1200;
    n = E(d, EM_GETTEXTEX, (unsigned long)&gt, (unsigned long)w);
    if (n < 0) n = 0;
    w[n] = 0; *pn = n;
    return w;
}
static WCHAR* to_w(const char* s, long* pn) {
    int n; WCHAR* w;
    *pn = 0;
    if (!s) return 0;
    n = p_MultiByteToWideChar(0, 0, s, -1, 0, 0);
    if (n <= 0) return 0;
    w = (WCHAR*)mem_alloc(n * 2 + 2);
    if (!w) return 0;
    p_MultiByteToWideChar(0, 0, s, -1, w, n);
    *pn = n - 1;
    return w;
}

/* ========================================================================== */
/*  Search                                                                     */
/* ========================================================================== */
/* flags: 1 forward (else backward), 2 whole word, 4 match case.
   Forward searches from..to (to -1 = the end); backward searches from down to 'to'. */
static long find_w(WDOC* d, const WCHAR* w, long from, long to, int flags, long* end) {
    FINDTEXTEXW ft; DWORD fl = 0; long r;
    if (flags & 1) fl |= FR_DOWN;
    if (flags & 2) fl |= FR_WHOLEWORD;
    if (flags & 4) fl |= FR_MATCHCASE;
    ft.chrg.cpMin = from; ft.chrg.cpMax = to; ft.lpstrText = w;
    ft.chrgText.cpMin = ft.chrgText.cpMax = -1;
    r = E(d, EM_FINDTEXTEXW, fl, (unsigned long)&ft);
    if (end) *end = r >= 0 ? ft.chrgText.cpMax : -1;
    return r;
}
/* returns the hit's start or -1 - nothing is selected; wdoc_found_end gives its end */
int wdoc_find_at(int h, const char* text, int from, int to, int flags) {
    WDOC* d = D(h); WCHAR* w; long n, r, end = -1;
    if (!d || !text || !text[0]) return -1;
    w = to_w(text, &n);
    if (!w || n <= 0) { mem_free(w); return -1; }
    r = find_w(d, w, from, to, flags, &end);
    mem_free(w);
    d->fEnd = r >= 0 ? end : -1;
    return (int)r;
}
int wdoc_found_end(int h) { WDOC* d = D(h); return d ? (int)d->fEnd : -1; }
void wdoc_show_range(int h, int from, int to) {     /* select and scroll into view */
    WDOC* d = D(h);
    if (!d) return;
    sel2(d, from, to);
    E(d, EM_SCROLLCARET, 0, 0);
}
int wdoc_count(int h, const char* text, int flags) {
    WDOC* d = D(h); WCHAR* w; long n, pos = 0, r, end, c = 0;
    if (!d || !text || !text[0]) return 0;
    w = to_w(text, &n);
    if (!w || n <= 0) { mem_free(w); return 0; }
    for (;;) {
        r = find_w(d, w, pos, -1, flags | 1, &end);
        if (r < 0) break;
        c++;
        pos = end > r ? end : r + 1;
    }
    mem_free(w);
    return (int)c;
}
/* replaces from..to with text, keeping the formatting of the first character
   replaced; returns where the new text ends */
static void replace_w(WDOC* d, long a, long b, const WCHAR* w) {
    sel2(d, a, b);
    if (p_SendMessageW) p_SendMessageW(d->edit, EM_REPLACESEL, 1, (unsigned long)w);
}
int wdoc_replace_range(int h, int from, int to, const char* text) {
    WDOC* d = D(h); WCHAR* w; long n; WCHAR none = 0;
    if (!d) return -1;
    w = to_w(text ? text : "", &n);
    replace_w(d, from, to, w ? w : &none);
    mem_free(w);
    d->seq++;
    return (int)(from + n);
}
/* every hit of find becomes repl; returns how many */
int wdoc_replace_all(int h, const char* find, const char* repl, int flags) {
    WDOC* d = D(h); WCHAR* wf; WCHAR* wr; long nf, nr, pos = 0, r, end, c = 0; QUIET q; WCHAR none = 0;
    if (!d || !find || !find[0]) return 0;
    wf = to_w(find, &nf);
    if (!wf || nf <= 0) { mem_free(wf); return 0; }
    wr = to_w(repl ? repl : "", &nr);
    quiet_on(d, &q); group_on(d);
    for (;;) {
        r = find_w(d, wf, pos, -1, flags | 1, &end);
        if (r < 0 || end <= r) break;
        replace_w(d, r, end, wr ? wr : &none);
        c++;
        pos = r + nr;
    }
    group_off(d); quiet_off(d, &q, 0);
    mem_free(wf); mem_free(wr);
    if (c) d->seq++;
    return (int)c;
}
/* paints every hit with a highlight colour (-1 takes the highlight off) */
int wdoc_mark_all(int h, const char* text, int flags, int color) {
    WDOC* d = D(h); WCHAR* w; long n, pos = 0, r, end, c = 0; QUIET q;
    if (!d || !text || !text[0]) return 0;
    w = to_w(text, &n);
    if (!w || n <= 0) { mem_free(w); return 0; }
    quiet_on(d, &q); group_on(d);
    for (;;) {
        r = find_w(d, w, pos, -1, flags | 1, &end);
        if (r < 0 || end <= r) break;
        sel2(d, r, end);
        set_color(d, (DWORD)color, 1);
        c++;
        pos = end;
    }
    group_off(d); quiet_off(d, &q, 0);
    mem_free(w);
    if (c) d->seq++;
    return (int)c;
}
/* plain text of from..to (ANSI, paragraph breaks as spaces) - for "...context..." */
int wdoc_text_range(int h, int from, int to) {
    WDOC* d = D(h); WCHAR* w; long n, i; WBUF b;
    if (!d) return 0;
    zero(&b, sizeof(b));
    w = wtext(d, &n);
    if (!w) return 0;
    if (from < 0) from = 0;
    if (to < 0 || to > n) to = n;
    for (i = from; i < to; i++) {
        WCHAR c = w[i];
        if (c == 13 || c == 10 || c == 11 || c == 7) c = ' ';
        else if (c >= 0xFFF9 && c <= 0xFFFC) continue;
        wb_ch(&b, c);
    }
    mem_free(w);
    return wb_publish(d, &b, 0);
}

/* ========================================================================== */
/*  Character runs: stretches of text with one look                            */
/* ========================================================================== */
#define RUNMASK (CFM_BOLD | CFM_ITALIC | CFM_UNDERLINE | CFM_STRIKEOUT | CFM_SIZE | CFM_COLOR | CFM_FACE | CFM_BACKCOLOR | CFM_SUBSCRIPT)

static int face_index(WDOC* d, const char* name) {
    int i;
    for (i = 0; i < d->nfaces; i++) if (seq_ci(d->faces + i * 32, name)) return i;
    if (d->nfaces >= d->fcap) {
        int nc = d->fcap ? d->fcap * 2 : 16;
        char* f = (char*)mem_grow(d->faces, nc * 32);
        long* k = (long*)mem_grow(d->fchars, nc * 4);
        if (!f || !k) return 0;
        d->faces = f; d->fchars = k; d->fcap = nc;
    }
    scpy(d->faces + d->nfaces * 32, name, 32);
    d->fchars[d->nfaces] = 0;
    return d->nfaces++;
}
static int same_look(WDOC* d, long a, long b) {
    CF2A cf;
    sel2(d, a, b);
    zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
    return (cf.dwMask & RUNMASK) == RUNMASK;
}
/* Walks the document once. A run is found by doubling its length while the
   selection still reports one look, then halving back to the exact edge, so a
   long run costs a handful of messages, not one per character. */
static int build_runs(WDOC* d) {
    long total = doc_len(d), s = 0, wn = 0, i;
    QUIET q; WCHAR* w; int k, m;
    d->nruns = 0; d->nfaces = 0;
    if (total <= 0) return 0;
    w = wtext(d, &wn);
    quiet_on(d, &q);
    while (s < total) {
        CF2A cf; long good, bad = -1, step = 1, t, mid; RUNX* r;
        sel2(d, s, s + 1);
        zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
        E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
        good = s + 1;
        while (good < total) {
            t = good + step;
            if (t > total) t = total;
            if (same_look(d, s, t)) { good = t; step *= 2; } else { bad = t; break; }
        }
        if (bad > 0) while (bad - good > 1) {
            mid = good + (bad - good) / 2;
            if (same_look(d, s, mid)) good = mid; else bad = mid;
        }
        if (d->nruns >= d->rcap) {
            int nc = d->rcap ? d->rcap * 2 : 256;
            RUNX* nr = (RUNX*)mem_grow(d->runs, nc * (long)sizeof(RUNX));
            if (!nr) break;
            d->runs = nr; d->rcap = nc;
        }
        r = &d->runs[d->nruns++];
        r->cp = s; r->end = good; r->size = cf.yHeight; r->eff = cf.dwEffects;
        r->col = cf.crTextColor; r->back = cf.crBackColor;
        r->face = face_index(d, cf.szFaceName);
        /* only characters you can see count: paragraph and table marks keep a
           font of their own that formatting the text never changes */
        for (i = s; i < good && i < wn; i++) {
            WCHAR c = w[i];
            if (c != 13 && c != 7 && c != 0xFFF9 && c != 0xFFFB) d->fchars[r->face]++;
        }
        s = good;
    }
    quiet_off(d, &q, 0);
    mem_free(w);
    /* drop the fonts that only marks use; their runs get face -1 */
    for (k = 0, m = 0; k < d->nfaces; k++) {
        int j;
        if (d->fchars[k] == 0) { for (j = 0; j < d->nruns; j++) if (d->runs[j].face == k) d->runs[j].face = -1; continue; }
        if (m != k) {
            scpy(d->faces + m * 32, d->faces + k * 32, 32); d->fchars[m] = d->fchars[k];
            for (j = 0; j < d->nruns; j++) if (d->runs[j].face == k) d->runs[j].face = m;
        }
        m++;
    }
    d->nfaces = m;
    return d->nruns;
}
int wdoc_runs(int h) { WDOC* d = D(h); return d ? build_runs(d) : 0; }
/* which: 1 start 2 end 3 size (pt*10) 4 bold 5 italic 6 underline 7 strike
          8 colour (-1 automatic) 9 highlight (-1 none) 10 font number (1-based)
          11 1 superscript / 2 subscript */
int wdoc_run_info(int h, int n, int which) {
    WDOC* d = D(h); RUNX* r;
    if (!d || n < 1 || n > d->nruns) return 0;
    r = &d->runs[n - 1];
    switch (which) {
    case 1: return (int)r->cp;
    case 2: return (int)r->end;
    case 3: return (int)(r->size / 2);
    case 4: return (r->eff & CFM_BOLD) ? 1 : 0;
    case 5: return (r->eff & CFM_ITALIC) ? 1 : 0;
    case 6: return (r->eff & CFM_UNDERLINE) ? 1 : 0;
    case 7: return (r->eff & CFM_STRIKEOUT) ? 1 : 0;
    case 8: return (r->eff & CFE_AUTOCOLOR) ? -1 : (int)r->col;
    case 9: return (r->eff & CFE_AUTOBACKCOLOR) ? -1 : (int)r->back;
    case 10: return r->face + 1;
    case 11: return (r->eff & CFE_SUPERSCRIPT) ? 1 : (r->eff & CFE_SUBSCRIPT) ? 2 : 0;
    }
    return 0;
}
int wdoc_face_count(int h) { WDOC* d = D(h); return d ? d->nfaces : 0; }
int wdoc_face_name(int h, int n, char* dst, int cap) {
    WDOC* d = D(h);
    if (cap > 0) dst[0] = 0;
    if (!d || n < 1 || n > d->nfaces || cap <= 0) return 0;
    scpy(dst, d->faces + (n - 1) * 32, cap);
    return slen(dst);
}
int wdoc_face_chars(int h, int n) { WDOC* d = D(h); return d && n >= 1 && n <= d->nfaces ? (int)d->fchars[n - 1] : 0; }

/* every run set in oldFace is set in newFace; returns how many runs changed */
int wdoc_replace_face(int h, const char* oldFace, const char* newFace) {
    WDOC* d = D(h); int i, c = 0, k = -1; QUIET q;
    if (!d || !oldFace || !newFace || !newFace[0]) return 0;
    build_runs(d);
    for (i = 0; i < d->nfaces; i++) if (seq_ci(d->faces + i * 32, oldFace)) k = i;
    if (k < 0) return 0;
    quiet_on(d, &q); group_on(d);
    for (i = 0; i < d->nruns; i++) if (d->runs[i].face == k) { sel2(d, d->runs[i].cp, d->runs[i].end); set_face(d, newFace); c++; }
    group_off(d); quiet_off(d, &q, 0);
    if (c) d->seq++;
    return c;
}
/* every size times pct/100 (never under 4 pt); returns how many runs changed */
int wdoc_scale_sizes(int h, int pct) {
    WDOC* d = D(h); int i, c = 0; QUIET q;
    if (!d || pct <= 0) return 0;
    build_runs(d);
    quiet_on(d, &q); group_on(d);
    for (i = 0; i < d->nruns; i++) {
        long tw = d->runs[i].size * pct / 100;
        CF2A cf;
        if (tw < 80) tw = 80;
        sel2(d, d->runs[i].cp, d->runs[i].end);
        zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf); cf.dwMask = CFM_SIZE; cf.yHeight = tw;
        E(d, EM_SETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
        c++;
    }
    group_off(d); quiet_off(d, &q, 0);
    if (c) d->seq++;
    return c;
}
/* face ("" = leave) and/or size (pt*10, 0 = leave) over from..to (to -1 = the end) */
void wdoc_set_font_range(int h, int from, int to, const char* face, int pt10) {
    WDOC* d = D(h); QUIET q;
    if (!d) return;
    quiet_on(d, &q); group_on(d);
    sel2(d, from, to);
    if (face && face[0]) set_face(d, face);
    if (pt10 > 0) set_size(d, pt10);
    group_off(d); quiet_off(d, &q, 0);
    d->seq++;
}
/* the look at a position (pos -1 = the selection as it is).
   which: 1 bold 2 italic 3 underline 4 strike (1/0, -1 mixed) 5 size pt*10 (0 mixed)
          6 colour (-1 automatic, -2 mixed) 7 highlight (-1 none, -2 mixed)
          8 alignment (-1 mixed) 9 list style (-1 mixed) 10 super/subscript 1/2 (-1 mixed) */
int wdoc_look(int h, int pos, int which) {
    WDOC* d = D(h); CF2A cf; PF2 pf; QUIET q; int r = 0;
    if (!d) return 0;
    if (pos >= 0) { quiet_on(d, &q); sel2(d, pos, pos + 1); }
    zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
    zero(&pf, sizeof(pf)); pf.cbSize = sizeof(pf);
    E(d, EM_GETPARAFORMAT, 0, (unsigned long)&pf);
    switch (which) {
    case 1: r = (cf.dwMask & CFM_BOLD) ? ((cf.dwEffects & CFM_BOLD) ? 1 : 0) : -1; break;
    case 2: r = (cf.dwMask & CFM_ITALIC) ? ((cf.dwEffects & CFM_ITALIC) ? 1 : 0) : -1; break;
    case 3: r = (cf.dwMask & CFM_UNDERLINE) ? ((cf.dwEffects & CFM_UNDERLINE) ? 1 : 0) : -1; break;
    case 4: r = (cf.dwMask & CFM_STRIKEOUT) ? ((cf.dwEffects & CFM_STRIKEOUT) ? 1 : 0) : -1; break;
    case 5: r = (cf.dwMask & CFM_SIZE) ? (int)(cf.yHeight / 2) : 0; break;
    case 6: r = !(cf.dwMask & CFM_COLOR) ? -2 : (cf.dwEffects & CFE_AUTOCOLOR) ? -1 : (int)cf.crTextColor; break;
    case 7: r = !(cf.dwMask & CFM_BACKCOLOR) ? -2 : (cf.dwEffects & CFE_AUTOBACKCOLOR) ? -1 : (int)cf.crBackColor; break;
    case 8: r = (pf.dwMask & PFM_ALIGNMENT) ? (pf.wAlignment ? pf.wAlignment : 1) : -1; break;
    case 9: r = (pf.dwMask & PFM_NUMBERING) ? pf.wNumbering : -1; break;
    case 10: r = (cf.dwMask & CFM_SUBSCRIPT) != CFM_SUBSCRIPT ? -1 : (cf.dwEffects & CFE_SUPERSCRIPT) ? 1 : (cf.dwEffects & CFE_SUBSCRIPT) ? 2 : 0; break;
    }
    if (pos >= 0) quiet_off(d, &q, 0);
    return r;
}
int wdoc_face_at(int h, int pos, char* dst, int cap) {
    WDOC* d = D(h); CF2A cf; QUIET q;
    if (cap > 0) dst[0] = 0;
    if (!d || cap <= 0) return 0;
    if (pos >= 0) { quiet_on(d, &q); sel2(d, pos, pos + 1); }
    zero(&cf, sizeof(cf)); cf.cbSize = sizeof(cf);
    E(d, EM_GETCHARFORMAT, SCF_SELECTION, (unsigned long)&cf);
    if (cf.dwMask & CFM_FACE) scpy(dst, cf.szFaceName, cap);
    if (pos >= 0) quiet_off(d, &q, 0);
    return slen(dst);
}

/* ========================================================================== */
/*  Paragraph helpers shared by text, HTML and Markdown                        */
/* ========================================================================== */
#define CH_CELL   0x0007     /* ends a table cell                     */
#define CH_LINE   0x000B     /* Shift+Enter: a line break, same paragraph */
#define CH_ROW    0xFFF9     /* starts a table row (followed by CR)   */
#define CH_ROWEND 0xFFFB     /* ends a table row (followed by CR)     */
#define CH_OBJ    0xFFFC     /* a picture                             */

static void para_at(WDOC* d, long cp, PF2* pf) {
    sel2(d, cp, cp);
    zero(pf, sizeof(PF2)); pf->cbSize = sizeof(PF2);
    E(d, EM_GETPARAFORMAT, 0, (unsigned long)pf);
}
/* "1." "b." "IV." ... for list style 2..6 and item number n */
static void list_label(WBUF* b, int style, int n) {
    if (n < 1) n = 1;
    if (style == 3 || style == 4) {
        char t[8]; int k = 0, m = n;
        while (m > 0 && k < 7) { t[k++] = (char)((style == 3 ? 'a' : 'A') + (m - 1) % 26); m = (m - 1) / 26; }
        while (k) wb_ch(b, (WCHAR)t[--k]);
    } else if (style == 5 || style == 6) {
        static const int val[] = { 1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1 };
        static const char* sym[] = { "m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i" };
        int i, m = n;
        for (i = 0; i < 13; i++) while (m >= val[i]) {
            const char* s = sym[i];
            while (*s) { wb_ch(b, (WCHAR)(style == 6 ? *s - 32 : *s)); s++; }
            m -= val[i];
        }
    } else wb_num(b, n);
    wb_ch(b, '.');
}
static int is_sep(WCHAR c) { return c <= 32 || c == 0xA0 || (c >= 0x2000 && c <= 0x200B) || c == 0x3000 || (c >= 0xFFF9 && c <= 0xFFFC); }

/* ========================================================================== */
/*  Plain text                                                                 */
/* ========================================================================== */
/* opts: 1 UTF-8 (else ANSI)  2 list prefixes ("- " / "1.")  4 tab between table
         cells (else " | ")  8 "[picture]" where a picture was */
int wdoc_to_text(int h, int opts, const char* bullet) {
    WDOC* d = D(h); WCHAR* w; long n, i = 0, cellMark = -1; int paraStart = 1, inRow = 0;
    int lastList = 0, counter = 0; WBUF b; QUIET q; PF2 pf;
    if (!d) return 0;
    zero(&b, sizeof(b));
    w = wtext(d, &n);
    if (!w) return 0;
    quiet_on(d, &q);
    while (i < n) {
        WCHAR c = w[i];
        if (paraStart) {
            paraStart = 0;
            if (c == CH_ROW) { inRow = 1; i++; if (i < n && w[i] == 13) i++; paraStart = 1; lastList = 0; continue; }
            if (!inRow && (opts & 2)) {
                para_at(d, i, &pf);
                if ((pf.dwMask & PFM_NUMBERING) && pf.wNumbering) {
                    if (pf.wNumbering == 1) wb_ansi(&b, bullet && bullet[0] ? bullet : "- ");
                    else {
                        counter = lastList == pf.wNumbering ? counter + 1 : (pf.wNumberingStart ? pf.wNumberingStart : 1);
                        list_label(&b, pf.wNumbering, counter); wb_ch(&b, ' ');
                    }
                    lastList = pf.wNumbering;
                } else lastList = 0;
            }
        }
        if (c == 13) { wb_ch(&b, 13); wb_ch(&b, 10); paraStart = 1; i++; continue; }
        if (c == CH_LINE) { wb_ch(&b, 13); wb_ch(&b, 10); i++; continue; }
        if (c == CH_CELL) {
            cellMark = b.len;
            if (opts & 4) wb_ch(&b, 9); else wb_str(&b, " | ");
            paraStart = 1; i++; continue;
        }
        if (c == CH_ROWEND) {
            if (cellMark >= 0 && cellMark <= b.len) b.len = cellMark;     /* no separator after the last cell */
            cellMark = -1; inRow = 0;
            wb_ch(&b, 13); wb_ch(&b, 10);
            i++; if (i < n && w[i] == 13) i++;
            paraStart = 1; continue;
        }
        if (c == CH_ROW) { i++; continue; }
        if (c == CH_OBJ) { if (opts & 8) wb_str(&b, "[picture]"); i++; continue; }
        wb_ch(&b, c);
        i++;
    }
    quiet_off(d, &q, 0);
    mem_free(w);
    while (b.len >= 2 && b.p[b.len - 1] == 10 && b.p[b.len - 2] == 13) b.len -= 2;   /* no trailing blank lines */
    return wb_publish(d, &b, (opts & 1) ? 65001 : 0);
}
/* which: 1 words 2 characters 3 characters without spaces 4 paragraphs with text
          5 pictures 6 tables 7 table rows */
int wdoc_stats(int h, int which) {
    WDOC* d = D(h); WCHAR* w; long n, i, r = 0; int inWord = 0, paraHas = 0;
    if (!d) return 0;
    w = wtext(d, &n);
    if (!w) return 0;
    for (i = 0; i < n; i++) {
        WCHAR c = w[i];
        switch (which) {
        case 1: if (is_sep(c) || c == CH_CELL) inWord = 0; else if (!inWord) { inWord = 1; r++; } break;
        case 2: if (c != 13 && c != 10 && c != CH_CELL && c != CH_LINE && !(c >= 0xFFF9 && c <= 0xFFFC)) r++; break;
        case 3: if (!is_sep(c) && c != CH_CELL) r++; break;
        case 4:
            if (c == 13 || c == CH_CELL) { if (paraHas) r++; paraHas = 0; }
            else if (!is_sep(c) || c == CH_OBJ) paraHas = 1;
            if (i == n - 1 && paraHas) r++;
            break;
        case 5: if (c == CH_OBJ) r++; break;
        case 6: if (c == CH_ROW && (i < 2 || w[i - 2] != CH_ROWEND)) r++; break;
        case 7: if (c == CH_ROW) r++; break;
        }
    }
    mem_free(w);
    return (int)r;
}

/* ========================================================================== */
/*  Pictures for HTML / Markdown                                               */
/* ========================================================================== */
typedef struct { int kind; BYTE* data; long n; long goalW, goalH, picw, pich, sx, sy; } PICT;   /* kind 1 png 2 jpeg 3 emf 4 wmf 5 dib */

static int hexv(char c) { return c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1; }
static int word_is(const char* w, int n, const char* k) { int i; for (i = 0; i < n; i++) if (!k[i] || w[i] != k[i]) return 0; return k[n] == 0; }
/* reads one {\pict ...} group that starts just after "\pict" at s; data stays hex-decoded in pk */
static void pict_parse(const char* s, const char* end, PICT* pk) {
    int depth = 0, hi = -1; long cap = (long)(end - s) / 2 + 4;
    pk->data = (BYTE*)mem_alloc(cap); pk->n = 0; pk->kind = 0;
    pk->goalW = pk->goalH = pk->picw = pk->pich = 0; pk->sx = pk->sy = 100;
    if (!pk->data) return;
    while (s < end) {
        char c = *s;
        if (c == '{') { depth++; s++; continue; }
        if (c == '}') { if (depth == 0) break; depth--; s++; continue; }
        if (depth > 0) { s++; continue; }               /* {\*\blipuid ...} and the like */
        if (c == '\\') {
            const char* w = ++s; int wn = 0; long v = 0, neg = 0, hasv = 0;
            while (s < end && ((*s >= 'a' && *s <= 'z') || (*s >= 'A' && *s <= 'Z'))) { s++; wn++; }
            if (wn == 0) { s++; continue; }
            if (s < end && *s == '-') { neg = 1; s++; }
            while (s < end && *s >= '0' && *s <= '9') { v = v * 10 + (*s - '0'); s++; hasv = 1; }
            if (neg) v = -v;
            if (s < end && *s == ' ') s++;
            if (word_is(w, wn, "pngblip")) pk->kind = 1;
            else if (word_is(w, wn, "jpegblip")) pk->kind = 2;
            else if (word_is(w, wn, "emfblip")) pk->kind = 3;
            else if (word_is(w, wn, "wmetafile")) pk->kind = 4;
            else if (word_is(w, wn, "dibitmap")) pk->kind = 5;
            else if (word_is(w, wn, "picwgoal") && hasv) pk->goalW = v;
            else if (word_is(w, wn, "pichgoal") && hasv) pk->goalH = v;
            else if (word_is(w, wn, "picw") && hasv) pk->picw = v;
            else if (word_is(w, wn, "pich") && hasv) pk->pich = v;
            else if (word_is(w, wn, "picscalex") && hasv) pk->sx = v;
            else if (word_is(w, wn, "picscaley") && hasv) pk->sy = v;
            continue;
        }
        {   int x = hexv(c);
            if (x >= 0 && pk->n < cap) {
                if (hi < 0) hi = x; else { pk->data[pk->n++] = (BYTE)(hi * 16 + x); hi = -1; }
            }
        }
        s++;
    }
}
static int pict_rank(int kind) { return kind == 1 || kind == 2 ? 3 : kind == 3 ? 2 : kind ? 1 : 0; }
/* the picture at cp, as RichEdit writes it out (the best of its \pict groups) */
static int pict_at(WDOC* d, long cp, PICT* best) {
    OBUF o; EDITSTREAM es; char* s; char* end;
    zero(best, sizeof(PICT)); zero(&o, sizeof(o));
    sel2(d, cp, cp + 1);
    es.dwCookie = (DWORD)&o; es.dwError = 0; es.pfnCallback = cb_obuf;
    E(d, EM_STREAMOUT, SF_RTF | SFF_SELECTION, (unsigned long)&es);
    if (!o.p) return 0;
    s = o.p; end = o.p + o.len;
    while (s + 5 < end) {
        if (s[0] == '\\' && s[1] == 'p' && s[2] == 'i' && s[3] == 'c' && s[4] == 't' &&
            !((s[5] >= 'a' && s[5] <= 'z') || (s[5] >= 'A' && s[5] <= 'Z'))) {
            PICT pk;
            pict_parse(s + 5, end, &pk);
            if (pk.n > 0 && pict_rank(pk.kind) > pict_rank(best->kind)) { mem_free(best->data); *best = pk; }
            else mem_free(pk.data);
        }
        s++;
    }
    mem_free(o.p);
    return best->kind != 0 && best->n > 0;
}

/* GDI+ - only to encode a rendered picture as PNG */
typedef struct { UINT GdiplusVersion; void* DebugEventCallback; BOOL SuppressBackgroundThread; BOOL SuppressExternalCodecs; } GPINPUT;
typedef struct { DWORD d1; WORD d2, d3; BYTE d4[8]; } WCLSID;
typedef struct { DWORD biSize; long biWidth; long biHeight; WORD biPlanes; WORD biBitCount; DWORD biCompression;
                 DWORD biSizeImage; long biXPelsPerMeter; long biYPelsPerMeter; DWORD biClrUsed; DWORD biClrImportant; } BIHDR;
typedef struct { long mm; long xExt; long yExt; void* hMF; } METAPICT;
FN(int,   GdiplusStartup, (unsigned long*, const GPINPUT*, void*))
FN(int,   GdipCreateBitmapFromHBITMAP, (void*, void*, void**))
FN(int,   GdipSaveImageToFile, (void*, const WCHAR*, const WCLSID*, const void*))
FN(int,   GdipDisposeImage, (void*))
FN(int,   GdipCreateBitmapFromFile, (const WCHAR*, void**))
static int g_gp = 0;     /* 0 not tried, 1 ready, -1 unavailable */
static int gp_ready(void) {
    if (!g_gp) {
        HMODULE m = LoadLibraryA("gdiplus.dll"); unsigned long tok = 0; GPINPUT in;
        g_gp = -1;
        if (m) {
            BIND(m, GdiplusStartup); BIND(m, GdipCreateBitmapFromHBITMAP); BIND(m, GdipSaveImageToFile); BIND(m, GdipDisposeImage); BIND(m, GdipCreateBitmapFromFile);
            zero(&in, sizeof(in)); in.GdiplusVersion = 1;
            if (p_GdiplusStartup && p_GdipCreateBitmapFromHBITMAP && p_GdipSaveImageToFile && p_GdipDisposeImage &&
                p_GdiplusStartup(&tok, &in, 0) == 0) g_gp = 1;
        }
    }
    return g_gp == 1;
}
static BYTE* read_all(const char* path, long* n) {
    void* f = p_CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0);
    DWORD sz, got = 0; BYTE* p;
    *n = 0;
    if (!f || f == (void*)-1) return 0;
    sz = p_GetFileSize(f, 0);
    p = (BYTE*)mem_alloc((long)sz + 1);
    if (p) { p_ReadFile(f, p, sz, &got, 0); *n = (long)got; }
    p_CloseHandle(f);
    return p;
}
static int write_all(const char* path, const BYTE* p, long n) {
    void* f = p_CreateFileA(path, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, 0, 0);
    DWORD put = 0;
    if (!f || f == (void*)-1) return 0;
    p_WriteFile(f, p, (DWORD)n, &put, 0);
    p_CloseHandle(f);
    return (long)put == n;
}
/* draws a metafile / DIB picture at wpx x hpx and returns it as PNG bytes */
static BYTE* pict_png(WDOC* d, PICT* pk, int wpx, int hpx, long* outN) {
    static const WCLSID png = { 0x557CF406, 0x1A04, 0x11D3, { 0x9A, 0x73, 0x00, 0x00, 0xF8, 0x1E, 0xF3, 0x2E } };
    void* dc; void* bm; void* old; void* bits = 0; void* img = 0; BIHDR bi; RECT rc; BYTE* out = 0;
    char tmp[300]; WCHAR wtmp[300]; char* o; DWORD tn;
    *outN = 0;
    if (!gp_ready() || !p_CreateDIBSection || wpx <= 0 || hpx <= 0 || wpx > 6000 || hpx > 6000) return 0;
    dc = p_CreateCompatibleDC(g_scrDC);
    zero(&bi, sizeof(bi)); bi.biSize = 40; bi.biWidth = wpx; bi.biHeight = hpx; bi.biPlanes = 1; bi.biBitCount = 24;
    bm = p_CreateDIBSection(dc, &bi, 0, &bits, 0, 0);
    if (!bm) { p_DeleteDC(dc); return 0; }
    old = p_SelectObject(dc, bm);
    p_PatBlt(dc, 0, 0, wpx, hpx, 0x00FF0062 /*WHITENESS*/);
    rc.left = 0; rc.top = 0; rc.right = wpx; rc.bottom = hpx;
    if (pk->kind == 3 && p_SetEnhMetaFileBits && p_PlayEnhMetaFile) {
        void* emf = p_SetEnhMetaFileBits((UINT)pk->n, pk->data);
        if (emf) { p_PlayEnhMetaFile(dc, emf, &rc); p_DeleteEnhMetaFile(emf); }
    } else if (pk->kind == 4 && p_SetWinMetaFileBits && p_PlayEnhMetaFile) {
        METAPICT mp; void* emf;
        mp.mm = 8 /*MM_ANISOTROPIC*/; mp.xExt = pk->picw; mp.yExt = pk->pich; mp.hMF = 0;
        emf = p_SetWinMetaFileBits((UINT)pk->n, pk->data, 0, &mp);
        if (emf) { p_PlayEnhMetaFile(dc, emf, &rc); p_DeleteEnhMetaFile(emf); }
    } else if (pk->kind == 5 && p_StretchDIBits && pk->n > 40) {
        BIHDR* h2 = (BIHDR*)pk->data; long pal = 0, off;
        if (h2->biBitCount <= 8) pal = h2->biClrUsed ? (long)h2->biClrUsed : (1L << h2->biBitCount);
        off = (long)h2->biSize + pal * 4 + (h2->biCompression == 3 ? 12 : 0);
        if (off < pk->n) {
            if (p_SetStretchBltMode) p_SetStretchBltMode(dc, 4 /*HALFTONE*/);
            p_StretchDIBits(dc, 0, 0, wpx, hpx, 0, 0, h2->biWidth, h2->biHeight < 0 ? -h2->biHeight : h2->biHeight,
                            pk->data + off, pk->data, 0, 0x00CC0020 /*SRCCOPY*/);
        }
    }
    p_SelectObject(dc, old);
    tn = p_GetTempPathA(260, tmp);
    if (tn == 0 || tn > 259) { tmp[0] = '.'; tmp[1] = 92; tn = 2; }
    o = tmp + tn; o = put(o, "wdoc_"); o = putn(o, (long)p_GetCurrentProcessId()); o = put(o, "_pict.png"); *o = 0;
    p_MultiByteToWideChar(0, 0, tmp, -1, wtmp, 300);
    if (p_GdipCreateBitmapFromHBITMAP(bm, 0, &img) == 0 && img) {
        if (p_GdipSaveImageToFile(img, wtmp, &png, 0) == 0) out = read_all(tmp, outN);
        p_GdipDisposeImage(img);
        p_DeleteFileA(tmp);
    }
    p_DeleteObject(bm);
    p_DeleteDC(dc);
    return out;
}
/* a .bmp file as PNG bytes (GDI+), or 0 */
static BYTE* bmp_to_png(const char* path, long* outN) {
    static const WCLSID png = { 0x557CF406, 0x1A04, 0x11D3, { 0x9A, 0x73, 0x00, 0x00, 0xF8, 0x1E, 0xF3, 0x2E } };
    WCHAR wsrc[300], wtmp[300]; char tmp[300]; char* o; DWORD tn; void* img = 0; BYTE* out = 0;
    *outN = 0;
    if (!gp_ready() || !p_GdipCreateBitmapFromFile) return 0;
    if (!p_MultiByteToWideChar(0, 0, path, -1, wsrc, 300)) return 0;
    tn = p_GetTempPathA(260, tmp);
    if (tn == 0 || tn > 259) { tmp[0] = '.'; tmp[1] = 92; tn = 2; }
    o = tmp + tn; o = put(o, "wdoc_"); o = putn(o, (long)p_GetCurrentProcessId()); o = put(o, "_bmp.png"); *o = 0;
    p_MultiByteToWideChar(0, 0, tmp, -1, wtmp, 300);
    if (p_GdipCreateBitmapFromFile(wsrc, &img) == 0 && img) {
        if (p_GdipSaveImageToFile(img, wtmp, &png, 0) == 0) out = read_all(tmp, outN);
        p_GdipDisposeImage(img);
        p_DeleteFileA(tmp);
    }
    return out;
}
static void wb_base64(WBUF* b, const BYTE* p, long n) {
    static const char t[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    long i;
    if (!wb_room(b, (n + 2) / 3 * 4 + 4)) return;
    for (i = 0; i + 2 < n; i += 3) {
        unsigned long v = ((unsigned long)p[i] << 16) | ((unsigned long)p[i + 1] << 8) | p[i + 2];
        b->p[b->len++] = (WCHAR)t[v >> 18]; b->p[b->len++] = (WCHAR)t[(v >> 12) & 63];
        b->p[b->len++] = (WCHAR)t[(v >> 6) & 63]; b->p[b->len++] = (WCHAR)t[v & 63];
    }
    if (i < n) {
        unsigned long v = (unsigned long)p[i] << 16; int two = i + 1 < n;
        if (two) v |= (unsigned long)p[i + 1] << 8;
        b->p[b->len++] = (WCHAR)t[v >> 18]; b->p[b->len++] = (WCHAR)t[(v >> 12) & 63];
        b->p[b->len++] = two ? (WCHAR)t[(v >> 6) & 63] : '='; b->p[b->len++] = '=';
    }
    b->p[b->len] = 0;
}

/* ========================================================================== */
/*  HTML and Markdown                                                          */
/* ========================================================================== */
typedef struct {
    WDOC* d; WBUF* o; int md; int frag; int noPics;
    const char* imgDir; const char* imgUrl; int nimg; int pics;
    int baseFace; long baseSize;
    /* the look that is open right now */
    int open; int oFace; long oSize; DWORD oCol, oBack, oEff;
    /* markdown inline state */
    int mdOn; int mdHold; WCHAR held[64]; int heading;
    int rowCells, rowNo;
} XP;

#define XE_B 1
#define XE_I 2
#define XE_U 4
#define XE_S 8
#define XE_SUP 16
#define XE_SUB 32
static DWORD xeff(RUNX* r) {
    return ((r->eff & CFM_BOLD) ? XE_B : 0) | ((r->eff & CFM_ITALIC) ? XE_I : 0) | ((r->eff & CFM_UNDERLINE) ? XE_U : 0) |
           ((r->eff & CFM_STRIKEOUT) ? XE_S : 0) | ((r->eff & CFE_SUPERSCRIPT) ? XE_SUP : 0) | ((r->eff & CFE_SUBSCRIPT) ? XE_SUB : 0);
}
static void x_esc(XP* x, WCHAR c) {
    WBUF* o = x->o;
    if (!x->md) {
        if (c == '&') wb_str(o, "&amp;"); else if (c == '<') wb_str(o, "&lt;"); else if (c == '>') wb_str(o, "&gt;");
        else if (c == '"') wb_str(o, "&quot;"); else if (c == 0xA0) wb_str(o, "&nbsp;"); else wb_ch(o, c);
        return;
    }
    if (c == '\\' || c == '*' || c == '_' || c == '`' || c == '[' || c == ']' || c == '<' || c == '>' || c == '|' || c == '#' || c == '~')
        wb_ch(o, '\\');
    wb_ch(o, c);
}
/* ---- HTML spans ---- */
static void h_close(XP* x) {
    if (!x->open) return;
    if (x->oEff & XE_SUB) wb_str(x->o, "</sub>");
    if (x->oEff & XE_SUP) wb_str(x->o, "</sup>");
    if (x->oEff & XE_S) wb_str(x->o, "</s>");
    if (x->oEff & XE_U) wb_str(x->o, "</u>");
    if (x->oEff & XE_I) wb_str(x->o, "</i>");
    if (x->oEff & XE_B) wb_str(x->o, "</b>");
    if (x->open == 2) wb_str(x->o, "</span>");
    x->open = 0;
}
static void h_open(XP* x, RUNX* r) {
    int face = r->face < 0 ? x->baseFace : r->face; long size = r->size; DWORD eff = xeff(r);
    int col = !(r->eff & CFE_AUTOCOLOR) && r->col != 0, back = !(r->eff & CFE_AUTOBACKCOLOR);
    if (x->open && x->oFace == face && x->oSize == size && x->oEff == eff &&
        x->oCol == (col ? r->col : 0xFFFFFFFF) && x->oBack == (back ? r->back : 0xFFFFFFFF)) return;
    h_close(x);
    x->open = 1;
    if (face != x->baseFace || size != x->baseSize || col || back) {
        x->open = 2;
        wb_str(x->o, "<span style=\"");
        if (face != x->baseFace) { wb_str(x->o, "font-family:'"); wb_ansi(x->o, x->d->faces + face * 32); wb_str(x->o, "';"); }
        if (size != x->baseSize) { wb_str(x->o, "font-size:"); wb_pt(x->o, size); wb_ch(x->o, ';'); }
        if (col) { wb_str(x->o, "color:"); wb_color(x->o, r->col); wb_ch(x->o, ';'); }
        if (back) { wb_str(x->o, "background-color:"); wb_color(x->o, r->back); wb_ch(x->o, ';'); }
        wb_str(x->o, "\">");
    }
    if (eff & XE_B) wb_str(x->o, "<b>");
    if (eff & XE_I) wb_str(x->o, "<i>");
    if (eff & XE_U) wb_str(x->o, "<u>");
    if (eff & XE_S) wb_str(x->o, "<s>");
    if (eff & XE_SUP) wb_str(x->o, "<sup>");
    if (eff & XE_SUB) wb_str(x->o, "<sub>");
    x->oFace = face; x->oSize = size; x->oEff = eff;
    x->oCol = col ? r->col : 0xFFFFFFFF; x->oBack = back ? r->back : 0xFFFFFFFF;
}
/* ---- Markdown emphasis: markers hug the words, spaces stay outside ---- */
static void m_marks(XP* x, int on, int closing) {
    if (closing) {
        if (on & XE_S) wb_str(x->o, "~~");
        if (on & XE_I) wb_ch(x->o, '*');
        if (on & XE_B) wb_str(x->o, "**");
    } else {
        if (on & XE_B) wb_str(x->o, "**");
        if (on & XE_I) wb_ch(x->o, '*');
        if (on & XE_S) wb_str(x->o, "~~");
    }
}
static void m_flush_held(XP* x) { int i; for (i = 0; i < x->mdHold; i++) wb_ch(x->o, x->held[i]); x->mdHold = 0; }
static void m_char(XP* x, WCHAR c, int want) {
    if (x->heading) want &= ~XE_B;
    if (c == ' ' || c == 9 || c == 0xA0) {
        if (x->mdOn && x->mdHold < 64) { x->held[x->mdHold++] = c; return; }
        m_flush_held(x); wb_ch(x->o, c); return;
    }
    if (want != x->mdOn) { m_marks(x, x->mdOn, 1); m_flush_held(x); m_marks(x, want, 0); x->mdOn = want; }
    else m_flush_held(x);
    x_esc(x, c);
}
static void m_end(XP* x) { m_marks(x, x->mdOn, 1); x->mdOn = 0; x->mdHold = 0; }
static void x_endlook(XP* x) { if (x->md) m_end(x); else h_close(x); }

/* a picture: data: URI or a file next to the page */
static void x_picture(XP* x, long cp) {
    PICT pk; BYTE* bytes; long nb; int wpx, hpx; const char* mime; const char* ext;
    if (x->noPics || !pict_at(x->d, cp, &pk)) return;
    wpx = (int)((pk.goalW ? pk.goalW : pk.picw * 15) * pk.sx / 100 / 15);
    hpx = (int)((pk.goalH ? pk.goalH : pk.pich * 15) * pk.sy / 100 / 15);
    if (wpx <= 0) wpx = 100;
    if (hpx <= 0) hpx = 100;
    if (pk.kind == 1 || pk.kind == 2) { bytes = pk.data; nb = pk.n; pk.data = 0; }
    else bytes = pict_png(x->d, &pk, wpx * 2, hpx * 2, &nb);     /* twice the size: sharp on high-dpi screens */
    mem_free(pk.data);
    if (!bytes || nb <= 0) { mem_free(bytes); return; }
    mime = pk.kind == 2 ? "image/jpeg" : "image/png";
    ext = pk.kind == 2 ? ".jpg" : ".png";
    x->nimg++;
    x_endlook(x);
    if (x->md) wb_str(x->o, "![picture "); else wb_str(x->o, "<img alt=\"picture ");
    wb_num(x->o, x->nimg);
    wb_str(x->o, x->md ? "](" : "\" src=\"");
    if (x->imgDir && x->imgDir[0]) {
        char path[400]; char name[40]; char* o = name; int k;
        o = put(o, "image"); o = putn(o, x->nimg); o = put(o, ext); *o = 0;
        scpy(path, x->imgDir, 360); k = slen(path);
        if (k && path[k - 1] != 92 && path[k - 1] != '/') { path[k++] = 92; path[k] = 0; }
        scpy(path + k, name, 40);
        write_all(path, bytes, nb);
        wb_ansi(x->o, x->imgUrl); wb_str(x->o, name);
    } else {
        wb_str(x->o, "data:"); wb_str(x->o, mime); wb_str(x->o, ";base64,");
        wb_base64(x->o, bytes, nb);
    }
    if (x->md) wb_ch(x->o, ')');
    else { wb_str(x->o, "\" width=\""); wb_num(x->o, wpx); wb_str(x->o, "\" height=\""); wb_num(x->o, hpx); wb_str(x->o, "\">"); }
    mem_free(bytes);
}
/* paragraph style for <p>/<li> */
static void h_pstyle(XP* x, PF2* pf, int li) {
    long start = (pf->dwMask & PFM_STARTINDENT) ? pf->dxStartIndent : 0;
    long off = (pf->dwMask & PFM_OFFSET) ? pf->dxOffset : 0;
    wb_str(x->o, " style=\"white-space:pre-wrap;margin:");
    wb_pt(x->o, pf->dySpaceBefore); wb_ch(x->o, ' ');
    wb_str(x->o, "0 "); wb_pt(x->o, pf->dySpaceAfter); wb_ch(x->o, ' ');
    if (li) wb_str(x->o, "0"); else wb_pt(x->o, start + off);
    wb_ch(x->o, ';');
    if (!li && off) { wb_str(x->o, "text-indent:"); wb_pt(x->o, -off); wb_ch(x->o, ';'); }
    if (pf->wAlignment == 2) wb_str(x->o, "text-align:right;");
    else if (pf->wAlignment == 3) wb_str(x->o, "text-align:center;");
    else if (pf->wAlignment == 4) wb_str(x->o, "text-align:justify;");
    if (pf->bLineSpacingRule == 1) wb_str(x->o, "line-height:1.5;");
    else if (pf->bLineSpacingRule == 2) wb_str(x->o, "line-height:2;");
    else if (pf->bLineSpacingRule == 5 && pf->dyLineSpacing > 0) {
        long t = pf->dyLineSpacing * 100 / 20;
        wb_str(x->o, "line-height:"); wb_num(x->o, t / 100); wb_ch(x->o, '.'); wb_num(x->o, (t % 100) / 10); wb_num(x->o, t % 10); wb_ch(x->o, ';');
    }
    wb_ch(x->o, '"');
}
/* markdown heading level from the paragraph's biggest text: 0 none */
static int m_heading(XP* x, long a, long b, int ri) {
    long big = 0, chars = 0, boldChars = 0; int i;
    for (i = ri; i < x->d->nruns && x->d->runs[i].cp < b; i++) {
        RUNX* r = &x->d->runs[i]; long s = r->cp < a ? a : r->cp, e = r->end > b ? b : r->end;
        if (e <= s) continue;
        if (r->size > big) big = r->size;
        chars += e - s;
        if (r->eff & CFM_BOLD) boldChars += e - s;
    }
    if (chars == 0 || chars > 200 || x->baseSize <= 0) return 0;
    if (big * 100 >= x->baseSize * 160) return 1;
    if (big * 100 >= x->baseSize * 130) return 2;
    if (big * 100 >= x->baseSize * 112 && boldChars == chars) return 3;
    return 0;
}

/* mode: 0 HTML page, 1 HTML fragment (inline styles only), 2 Markdown
   opts: 1 leave pictures out
   imgDir: "" embeds pictures as data: URIs; a folder writes image1.png... there
           and links them as imgUrl + name. Result: UTF-8, in the slot buffer. */
int wdoc_export(int h, int mode, int opts, const char* title, const char* imgDir, const char* imgUrl) {
    WDOC* d = D(h); WCHAR* w; long n, i = 0; int ri = 0, k;
    int paraStart = 1, paraOpen = 0, paraChars = 0, inTable = 0, inCell = 0, list = 0, counter = 0, cellFirstPara = 0;
    WBUF b; XP x; QUIET q; PF2 pf;
    if (!d) return 0;
    zero(&b, sizeof(b)); zero(&x, sizeof(x));
    x.d = d; x.o = &b; x.md = mode == 2; x.frag = mode == 1; x.noPics = opts & 1;
    x.imgDir = imgDir; x.imgUrl = imgUrl ? imgUrl : "";
    build_runs(d);
    /* the body font: the face and the size most of the text uses */
    x.baseFace = 0; x.baseSize = 220;
    for (k = 0; k < d->nfaces; k++) if (d->fchars[k] > d->fchars[x.baseFace]) x.baseFace = k;
    {   long bestN = -1; int a, c;
        for (a = 0; a < d->nruns; a++) {
            long sz = d->runs[a].size, tot = 0;
            for (c = 0; c < d->nruns; c++) if (d->runs[c].size == sz) tot += d->runs[c].end - d->runs[c].cp;
            if (tot > bestN) { bestN = tot; x.baseSize = sz; }
            if (a > 400) break;        /* plenty to decide on */
        }
    }
    w = wtext(d, &n);
    if (!w) return 0;
    quiet_on(d, &q);

    if (!x.md) {
        if (!x.frag) {
            wb_str(&b, "<!DOCTYPE html>\r\n<html>\r\n<head>\r\n<meta charset=\"utf-8\">\r\n<title>");
            if (title) { const char* t = title; WBUF tb; zero(&tb, sizeof(tb)); wb_ansi(&tb, t);
                for (k = 0; k < tb.len; k++) x_esc(&x, tb.p[k]); mem_free(tb.p); }
            wb_str(&b, "</title>\r\n<style>\r\nbody{margin:2em auto;max-width:52em;padding:0 1em;}\r\n</style>\r\n</head>\r\n<body>\r\n");
        }
        wb_str(&b, "<div style=\"font-family:'");
        if (d->nfaces) wb_ansi(&b, d->faces + x.baseFace * 32); else wb_str(&b, "Segoe UI");
        wb_str(&b, "',sans-serif;font-size:"); wb_pt(&b, x.baseSize);
        wb_str(&b, ";\">\r\n");
    }

    while (i < n) {
        WCHAR c = w[i];
        while (ri < d->nruns && d->runs[ri].end <= i) ri++;
        if (paraStart) {
            paraStart = 0;
            if (c == CH_ROW) {                                   /* a table row starts */
                if (list) { wb_str(&b, x.md ? "\r\n" : (list == 1 ? "</ul>\r\n" : "</ol>\r\n")); list = 0; }
                if (!inTable) {
                    inTable = 1; x.rowNo = 0;
                    wb_str(&b, x.md ? "\r\n" : "<table style=\"border-collapse:collapse;margin:4pt 0;\">\r\n");
                }
                x.rowNo++; x.rowCells = 0;
                wb_str(&b, x.md ? "|" : "<tr>");
                i++; if (i < n && w[i] == 13) i++;
                inCell = 1; cellFirstPara = 1; paraStart = 1;
                if (!x.md) wb_str(&b, "<td style=\"border:1px solid #9CA3AF;padding:2pt 6pt;vertical-align:top;white-space:pre-wrap;\">");
                else wb_ch(&b, ' ');
                continue;
            }
            if (inCell) {
                if (!cellFirstPara && c != CH_ROWEND) { x_endlook(&x); wb_str(&b, "<br>"); }
                cellFirstPara = 0;
            } else {
                long pe = i; int num;
                while (pe < n && w[pe] != 13) pe++;
                para_at(d, i, &pf);
                num = (pf.dwMask & PFM_NUMBERING) ? pf.wNumbering : 0;
                if (num != list) {
                    if (list) { wb_str(&b, x.md ? "\r\n" : (list == 1 ? "</ul>\r\n" : "</ol>\r\n")); }
                    list = 0;
                    if (num) {
                        list = num;
                        counter = pf.wNumberingStart ? pf.wNumberingStart : 1;
                        if (!x.md) {
                            if (num == 1) wb_str(&b, "<ul style=\"margin:0;\">\r\n");
                            else {
                                wb_str(&b, "<ol style=\"margin:0;\" type=\"");
                                wb_str(&b, num == 3 ? "a" : num == 4 ? "A" : num == 5 ? "i" : num == 6 ? "I" : "1");
                                wb_str(&b, "\" start=\""); wb_num(&b, counter); wb_str(&b, "\">\r\n");
                            }
                        }
                    }
                } else if (num) counter++;
                if (x.md) {
                    if (list == 1) wb_str(&b, "- ");
                    else if (list) { wb_num(&b, counter); wb_str(&b, ". "); }
                    else {
                        x.heading = m_heading(&x, i, pe, ri);
                        if (x.heading) { int t; for (t = 0; t < x.heading; t++) wb_ch(&b, '#'); wb_ch(&b, ' '); }
                        else if (c == '-' || c == '+' || (c >= '0' && c <= '9')) wb_ch(&b, '\\');
                    }
                } else {
                    wb_str(&b, list ? "<li" : "<p");
                    h_pstyle(&x, &pf, list != 0);
                    wb_ch(&b, '>');
                }
                paraOpen = 1; paraChars = 0;
            }
        }
        if (c == 13) {                                          /* end of a paragraph */
            if (inCell) { paraStart = 1; i++; continue; }
            x_endlook(&x);
            if (x.md) { if (paraChars || list) wb_str(&b, list ? "\r\n" : "\r\n\r\n"); x.heading = 0; }
            else { if (!paraChars && !list) wb_str(&b, "&nbsp;"); wb_str(&b, list ? "</li>\r\n" : "</p>\r\n"); }
            paraOpen = 0; paraStart = 1; i++;
            continue;
        }
        if (c == CH_CELL) {                                     /* end of a cell */
            x_endlook(&x);
            x.rowCells++;
            wb_str(&b, x.md ? " |" : "</td>");
            i++;
            if (i < n && w[i] != CH_ROWEND) {
                wb_str(&b, x.md ? " " : "<td style=\"border:1px solid #9CA3AF;padding:2pt 6pt;vertical-align:top;white-space:pre-wrap;\">");
                cellFirstPara = 1;
            }
            paraStart = 1;
            continue;
        }
        if (c == CH_ROWEND) {                                   /* end of a row */
            int t;
            wb_str(&b, x.md ? "\r\n" : "</tr>\r\n");
            if (x.md && x.rowNo == 1) { wb_ch(&b, '|'); for (t = 0; t < x.rowCells; t++) wb_str(&b, " --- |"); wb_str(&b, "\r\n"); }
            i++; if (i < n && w[i] == 13) i++;
            inCell = 0; paraStart = 1;
            if (i >= n || w[i] != CH_ROW) { inTable = 0; wb_str(&b, x.md ? "\r\n" : "</table>\r\n"); }
            continue;
        }
        if (c == CH_OBJ) { x_picture(&x, i); paraChars++; i++; continue; }
        if (c == CH_LINE) { x_endlook(&x); wb_str(&b, x.md ? (inCell ? "<br>" : "  \r\n") : "<br>"); i++; continue; }
        if (c == CH_ROW) { i++; continue; }
        paraChars++;
        if (ri < d->nruns) {
            if (x.md) m_char(&x, c, (int)(xeff(&d->runs[ri]) & (XE_B | XE_I | XE_S)));
            else { h_open(&x, &d->runs[ri]); x_esc(&x, c); }
        } else x_esc(&x, c);
        i++;
    }
    x_endlook(&x);
    if (paraOpen && !x.md) wb_str(&b, list ? "</li>\r\n" : "</p>\r\n");
    if (list && !x.md) wb_str(&b, list == 1 ? "</ul>\r\n" : "</ol>\r\n");
    if (inTable && !x.md) wb_str(&b, "</table>\r\n");
    if (!x.md) {
        wb_str(&b, "</div>\r\n");
        if (!x.frag) wb_str(&b, "</body>\r\n</html>\r\n");
    }
    quiet_off(d, &q, 0);
    mem_free(w);
    return wb_publish(d, &b, 65001);
}

/* a raw dump of the text's character codes - for the tests */
int wdoc_debug_codes(int h) {
    WDOC* d = D(h); WCHAR* w; long n, i; WBUF b;
    if (!d) return 0;
    zero(&b, sizeof(b));
    w = wtext(d, &n);
    if (!w) return 0;
    for (i = 0; i < n; i++) {
        WCHAR c = w[i];
        if (c < 32 || c >= 0xFFF0) { wb_ch(&b, '<'); wb_num(&b, c); wb_ch(&b, '>'); if (c == 13) { wb_ch(&b, 13); wb_ch(&b, 10); } }
        else wb_ch(&b, c);
    }
    mem_free(w);
    return wb_publish(d, &b, 0);
}

}   /* extern "C" */
