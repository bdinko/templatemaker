/* ============================================================================
 *  d2grid.c - a grid drawn with Direct2D and DirectWrite, for Clarion.
 *
 *  WHY. Clarion's LIST is drawn by the runtime and looks it. This draws every
 *  pixel itself into an ordinary Clarion REGION - which owns a real HWND, like
 *  every Clarion control - so a browse can have banded rows, frozen columns,
 *  a proper header, smooth scrolling and any colour scheme you like, without
 *  giving up ABC's BrowseClass underneath.
 *
 *  WHAT IT DOES NOT DO. It holds no data. Clarion pushes the VISIBLE rows in
 *  before each paint - which is exactly what an ABC browse queue already
 *  contains - and the grid draws them. Scrolling posts an event back so the
 *  Clarion side can fetch the next page from the VIEW. The grid never owns the
 *  file, the sort order or the filter; BrowseClass keeps all of that.
 *
 *  BOUND AT RUN TIME. d2d1.dll and dwrite.dll are loaded with LoadLibrary, so
 *  there is no import library to link (Clarion cannot link MSVC COFF libs) and
 *  nothing to ship. Both have been part of Windows since 7.
 *
 *  COM WITHOUT A HEADER. Clacpp has no Windows SDK, so the interfaces are
 *  hand-declared. Every vtable index below was read out of the SDK's own
 *  d2d1.h / dwrite.h by walking each interface's declaration order, base class
 *  first - not remembered. They are named once, here, and nowhere else:
 *
 *    ID2D1Factory            2 Release  14 CreateHwndRenderTarget
 *    ID2D1HwndRenderTarget   2 Release   8 CreateSolidColorBrush
 *                           15 DrawLine 17 FillRectangle  27 DrawText
 *                           30 SetTransform 45 PushAxisAlignedClip
 *                           46 PopAxisAlignedClip 47 Clear 48 BeginDraw
 *                           49 EndDraw 58 Resize
 *    ID2D1SolidColorBrush    2 Release   8 SetColor
 *    IDWriteFactory          2 Release  15 CreateTextFormat
 *                           18 CreateTextLayout
 *    IDWriteTextLayout       2 Release   5 SetWordWrapping (TextFormat's, inherited)
 *                           60 GetMetrics
 *
 *  ABI notes:
 *    - 32-bit, stdcall (Clacpp spells it `pascal`).
 *    - D2D1_POINT_2F goes to DrawLine BY VALUE. Two floats on the stack is
 *      byte-identical to the struct, so they are declared as separate floats.
 *    - DrawText wants UTF-16. Clarion hands over ANSI, converted here.
 * ========================================================================== */

#define WINAPI pascal
typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef int            BOOL;
typedef unsigned char  BYTE;
typedef unsigned short WCHAR;
typedef void*          HMODULE;
typedef void*          HWND;
typedef long           HRESULT;
typedef int (WINAPI *FARPROC)();
typedef long (WINAPI *WNDPROC)(HWND, UINT, UINT, long);

typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3;
                 unsigned char Data4[8]; } GUID;
typedef struct { long left, top, right, bottom; } RECT;

#define LPTR         0x0040
#define CP_ACP       0
#define GWL_WNDPROC  (-4)
#define WM_PAINT      0x000F
#define WM_ERASEBKGND 0x0014

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);
void*   WINAPI LocalAlloc(UINT, unsigned long);
void*   WINAPI LocalFree(void*);
long    WINAPI SetWindowLongA(HWND, int, long);
long    WINAPI GetWindowLongA(HWND, int);
long    WINAPI CallWindowProcA(WNDPROC, HWND, UINT, UINT, long);
long    WINAPI DefWindowProcA(HWND, UINT, UINT, long);
BOOL    WINAPI InvalidateRect(HWND, const RECT*, BOOL);
BOOL    WINAPI GetClientRect(HWND, RECT*);
void*   WINAPI BeginPaint(HWND, void*);
BOOL    WINAPI EndPaint(HWND, const void*);
BOOL    WINAPI IsWindow(HWND);
int     WINAPI MultiByteToWideChar(UINT, DWORD, const char*, int, WCHAR*, int);

/* ---- Direct2D / DirectWrite types, exactly as the SDK lays them out ------ */
typedef struct { unsigned int w, h; }                SIZEU;
typedef struct { float l, t, r, b; }                 RECTF;
typedef struct { float r, g, b, a; }                 COLORF;
typedef struct { int format; int alphaMode; }        PIXFMT;
typedef struct { int type; PIXFMT pf; float dpiX, dpiY;
                 int usage; int minLevel; }          RTPROPS;
typedef struct { HWND hwnd; SIZEU size; int present; } HRTPROPS;
/* DWRITE_TEXT_METRICS, for IDWriteTextLayout::GetMetrics - seven floats and
   two UINT32s, of which lineCount, the last, is the only one wanted here. */
typedef struct { float left, top, width, widthTrail, height, layoutW, layoutH;
                 UINT bidi, lineCount; } DWTM;

#define DXGI_B8G8R8A8_UNORM  87
#define ALPHA_IGNORE          3
#define FACTORY_SINGLE        0
#define DW_FACTORY_SHARED     0
#define FONT_NORMAL         400
#define FONT_BOLD           700
#define STYLE_NORMAL          0
#define STRETCH_NORMAL        5
#define AA_ALIASED            1     /* D2D1_ANTIALIAS_MODE_ALIASED */
/* IDWriteTextFormat, which inherits straight from IUnknown:
     3 SetTextAlignment   4 SetParagraphAlignment   5 SetWordWrapping        */
#define DW_LEADING            0     /* left   */
#define DW_TRAILING           1     /* right  */
#define DW_CENTER             2
#define DW_PARA_CENTER        2     /* centred down the row, not hugging the top */
#define DW_NO_WRAP            1     /* a cell is one line; clip, never wrap      */
#define DW_WRAP               0     /* ...or let it run onto the next line       */

#define VT(o) (*(void***)(o))

typedef HRESULT (WINAPI *PFN_D2D1CreateFactory)(int, const GUID*, const void*, void**);
typedef HRESULT (WINAPI *PFN_DWriteCreateFactory)(int, const GUID*, void**);

#define G_MAX      8            /* grids at once                              */
#define G_COLS    32            /* columns                                    */
#define G_VIS     96            /* visible rows the Clarion side pushes in     */
#define G_TEXT   128            /* characters per cell. Long enough to be worth
                                   wrapping: at 64 a cell was cut at 63
                                   characters before it ever reached
                                   DirectWrite, which looks exactly like text
                                   that refused to wrap.                      */

typedef struct {
    int   used;
    HWND  hwnd;
    void* rt;                   /* ID2D1HwndRenderTarget */
    void* fmt;                  /* IDWriteTextFormat - the body font   */
    void* fmtHdr;               /* ... and the header font             */
    void* fmtIcon;              /* Windows' icon font, for the funnel  */
    void* brush;                /* one brush, recoloured as it goes    */
    WNDPROC oldProc;

    int   cols;
    int   colW[G_COLS];
    int   colAlign[G_COLS];     /* 0 left 1 right 2 centre */
    char  colTitle[G_COLS][G_TEXT];
    int   frozen;               /* how many columns stay put while scrolling  */

    int   rtW, rtH;             /* what the render target is currently sized to */
    int   rowH, hdrH;
    int   visRows;              /* rows the Clarion side has pushed in        */
    int   firstRow;             /* which record visRow 0 is                   */
    int   totalRows;
    int   selRow;               /* selected, in absolute row numbers          */
    int   scrollX;
    int   scrollY;              /* pixels the page is nudged UP by; 0..rowH-1
                                   is a part-row at the top, which is what
                                   makes scrolling smooth rather than jumpy   */
    char  cell[G_VIS][G_COLS][G_TEXT];

    unsigned int cBack, cBand, cGrid, cText, cHdrBack, cHdrText, cSelBack, cSelText;

    /* our own vertical scrollbar. Windows' one cannot be made to track: it
       drags inside a message loop of its own, and moving the browse needs
       records, which needs Clarion's ACCEPT, which that loop is holding up.
       Drawn here it is just pixels, and dragging it is an ordinary mouse
       event like any other. */
    int   vBar;                 /* drawn at all?                            */
    int   vPos;                 /* 0..100, the browse's own scale           */
    int   vPct;                 /* how much of the trough the thumb takes   */

    /* ---- how the bars look ------------------------------------------------
       0 Windows  the horizontal one is Windows' own, the vertical one drawn
       1 Slim     both drawn, thin and flat, taking their width from the rows
       2 Overlay  both drawn, thinner, ON TOP of the rows and only while the
                  pointer is over the grid - so nothing is taken from the data */
    int   barStyle;
    int   hBar, hPos, hPage, hTotal;   /* the drawn horizontal one           */
    int   barsShow;                    /* overlay: is the pointer over us?   */

    char  face[64];             /* kept so the font can be rebuilt bigger   */
    int   pt;

    int   btns;                 /* draw a filter button on every heading?   */
    /* Which columns are filtered - a SET, not one column. Filters add up the
       way Excel's do, so more than one can be on at once and every one of them
       has to say so on its own heading. */
    int   colFilt[G_COLS];
    int   sortCol;              /* which column is sorted, -1 for none      */
    int   sortDir;              /* 1 up, -1 down                            */

    /* a heading being carried to a new place. 0 = nothing carried, else the
       column + 1 - zero-safe, so a freshly attached grid carries nothing
       whatever the allocator left here. */
    int   carry;
    int   carryX;               /* where the pointer is, grid coords        */

    /* ---- grouped, multi-line formats -------------------------------------
       An ordinary browse has one line per record and its columns simply follow
       one another, which is what grps == 0 means and nothing below is touched.
       A grouped one puts several fields on each record over several lines,
       under headings that span them - so a column needs to say WHERE it goes
       rather than just how wide it is, and the headings belong to the groups
       rather than to the columns. */
    int   grps;                 /* 0 = an ordinary flat browse              */
    int   grpX[G_COLS], grpW[G_COLS];
    char  grpTitle[G_COLS][G_TEXT];
    int   colX[G_COLS];         /* where the column sits across the record  */
    int   colLine[G_COLS];      /* and which line of it                     */
    int   colGrp[G_COLS];       /* which group it belongs to                */
    /* Where the field sat inside its group when the format was read, and how
       wide the group was then. Resizing recomputes from THESE, never from the
       last result: scaling the current numbers again and again is destructive,
       and integer arithmetic drives them to nothing. Squeeze a group small
       enough that way and every offset rounds to zero, and growing it back
       multiplies zero by a ratio - still zero, so the fields stay piled up on
       the left.
       Keeping the ORIGINAL numbers rather than a proportion of them also means
       no double rounding: back at the width it started from, the arithmetic is
       exact rather than a pixel short. */
    int   colOx[G_COLS], colOw[G_COLS];
    int   grpOw[G_COLS];
    int   lines;                /* lines per record, 1 for an ordinary one  */

    int   wrap;                 /* let long text run onto another line?     */
    int   wrapLines;            /* how many lines a cell is allowed         */

    /* ---- variable-height rows --------------------------------------------
       With wrap alone every row carries the full allowance, wrapped or not.
       varRows grows a row only as far as its own text needs: the rows the
       page pushes in are MEASURED - DirectWrite says how many lines each
       cell takes at its column's width - and the worst cell sets the row.
       Flat browses only; a grouped format has said what it wants. */
    int   varRows;              /* grow rows only as needed?                */
    int   rowLines[G_VIS];      /* measured lines per visible row, >= 1     */
    int   linesDirty;           /* cells or widths changed since measuring  */
    int   noMeasure;            /* a column drag is live: hold the measuring */
} Grid;

#define D2G_BARW 15

static Grid  g_g[G_MAX + 1];
static void* g_d2d = 0;
static void* g_dw  = 0;
static int   g_tried = 0;

static long WINAPI d2g_WndProc(HWND h, UINT msg, UINT wp, long lp);

/* How tall a row and a heading are for a given point size. Leading has to grow
   WITH the type, not sit at a fixed number of pixels above it: pt + 10 is
   roomy at 9 point and cramped at 24, where the descenders start being cut off
   by the row below. Three halves and a bit keeps the same look all the way up,
   and lands on the same numbers as the old rule at the default size, so
   nothing moves for anyone who never touches it. */
#define D2G_ROWFOR(pt) ((pt) * 3 / 2 + 6)
/* A record is as tall as its format needs times as many lines as a wrapped
   cell is allowed. Every row is the same height either way - variable-height
   rows would take the page size, the hit testing and the scrolling with them,
   and none of those want to know that a particular address was long. */
/* A format that already says where its lines are does not also get the wrap
   allowance multiplied on top: three lines times two wrapped lines is a row six
   deep with every field floating in the middle of a box twice the size of its
   text. Wrapping is for a flat browse, where a cell has one line and needs
   more; a grouped record has been told exactly how many it wants. */
#define D2G_ROWH(c) (D2G_ROWFOR((c)->pt) * (c)->lines *                        \
                     (((c)->lines > 1) ? 1 : (c)->wrapLines))
#define D2G_HDRFOR(pt) ((pt) * 3 / 2 + 8)
static void d2g_VGeom(Grid* c, int* top, int* len, int* tTop, int* tLen);
static void d2g_HGeom(Grid* c, int* left, int* len, int* tLeft, int* tLen);
static int  barThick(Grid* c);
static int  barTakes(Grid* c);
static void sortMark(Grid* c, float right, float top, int dir, unsigned int rgb);
static void filterBtn(Grid* c, float right, float midY, unsigned int line_, unsigned int fill,
                      int dir, int filt);
static void glyph(Grid* c, unsigned short ch, float l, float t, float r, float b,
                  unsigned int rgb, void* fmt);

/* What the button says, as characters rather than shapes hand-built out of
   one-pixel rows. They scale with the type and read as icons because they are
   icons - the font's, not ours. */
#define D2G_G_MENU  0x02C5      /* a thin arrowhead: this opens a menu */
#define D2G_G_ASC   0x25B2      /* a solid triangle, pointing up       */
#define D2G_G_DESC  0x25BC      /* ...and pointing down                */
#define D2G_G_FILT  0xE71C      /* the funnel, out of Windows' own icon font */
#define D2G_BTNW 15         /* the drop-down box on a heading, as Excel draws it */

/* ---- the two factories --------------------------------------------------- */
static int d2g_Factories(void) {
    HMODULE d2dDll, dwDll;
    PFN_D2D1CreateFactory   mkD2D;
    PFN_DWriteCreateFactory mkDW;
    GUID iid;

    if (g_d2d && g_dw) return 1;
    if (g_tried) return 0;
    g_tried = 1;

    d2dDll = LoadLibraryA("d2d1.dll");
    dwDll  = LoadLibraryA("dwrite.dll");
    if (!d2dDll || !dwDll) return 0;
    mkD2D = (PFN_D2D1CreateFactory)GetProcAddress(d2dDll, "D2D1CreateFactory");
    mkDW  = (PFN_DWriteCreateFactory)GetProcAddress(dwDll, "DWriteCreateFactory");
    if (!mkD2D || !mkDW) return 0;

    /* IID_ID2D1Factory {06152247-6f50-465a-9245-118bfd3b6007} */
    iid.Data1 = 0x06152247; iid.Data2 = 0x6f50; iid.Data3 = 0x465a;
    iid.Data4[0]=0x92; iid.Data4[1]=0x45; iid.Data4[2]=0x11; iid.Data4[3]=0x8b;
    iid.Data4[4]=0xfd; iid.Data4[5]=0x3b; iid.Data4[6]=0x60; iid.Data4[7]=0x07;
    if (mkD2D(FACTORY_SINGLE, &iid, 0, &g_d2d) < 0) { g_d2d = 0; return 0; }

    /* IID_IDWriteFactory {b859ee5a-d838-4b5b-a2e8-1adc7d93db48} */
    iid.Data1 = 0xb859ee5a; iid.Data2 = 0xd838; iid.Data3 = 0x4b5b;
    iid.Data4[0]=0xa2; iid.Data4[1]=0xe8; iid.Data4[2]=0x1a; iid.Data4[3]=0xdc;
    iid.Data4[4]=0x7d; iid.Data4[5]=0x93; iid.Data4[6]=0xdb; iid.Data4[7]=0x48;
    if (mkDW(DW_FACTORY_SHARED, &iid, &g_dw) < 0) { g_dw = 0; return 0; }
    return 1;
}

static Grid* slot(int h) {
    if (h < 1 || h > G_MAX || !g_g[h].used) return 0;
    return &g_g[h];
}

static void wide(const char* src, WCHAR* dst, int cap) {
    int n = MultiByteToWideChar(CP_ACP, 0, src, -1, dst, cap);
    if (n <= 0) dst[0] = 0;
}

/* one text format (a font) */
static void* d2g_Font(const char* face, float size, int bold) {
    WCHAR wf[64], wl[8];
    void* fmt = 0;
    if (!g_dw) return 0;
    wide(face, wf, 64);
    wl[0] = 'e'; wl[1] = 'n'; wl[2] = '-'; wl[3] = 'u'; wl[4] = 's'; wl[5] = 0;
    /* IDWriteFactory::CreateTextFormat - slot 15 */
    if (((HRESULT (WINAPI*)(void*, const WCHAR*, void*, int, int, int, float,
                            const WCHAR*, void**))VT(g_dw)[15])
        (g_dw, wf, 0, bold ? FONT_BOLD : FONT_NORMAL, STYLE_NORMAL,
         STRETCH_NORMAL, size, wl, &fmt) < 0) return 0;
    /* down the middle of the row, and one line only */
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[4])(fmt, DW_PARA_CENTER);
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[5])(fmt, DW_NO_WRAP);
    return fmt;
}

static int d2g_MakeTarget(Grid* c) {
    RTPROPS  rp;
    HRTPROPS hp;
    RECT     r;
    COLORF   col;

    if (!d2g_Factories() || !c->hwnd || !IsWindow(c->hwnd)) return 0;
    if (c->rt) return 1;
    GetClientRect(c->hwnd, &r);
    if (r.right - r.left < 1 || r.bottom - r.top < 1) return 0;

    rp.type = 0; rp.pf.format = DXGI_B8G8R8A8_UNORM; rp.pf.alphaMode = ALPHA_IGNORE;
    rp.dpiX = 96.0f; rp.dpiY = 96.0f; rp.usage = 0; rp.minLevel = 0;
    hp.hwnd = c->hwnd;
    hp.size.w = (unsigned)(r.right - r.left);
    hp.size.h = (unsigned)(r.bottom - r.top);
    hp.present = 0;
    if (((HRESULT (WINAPI*)(void*, const RTPROPS*, const HRTPROPS*, void**))
         VT(g_d2d)[14])(g_d2d, &rp, &hp, &c->rt) < 0) { c->rt = 0; return 0; }
    c->rtW = r.right - r.left;                     /* what it was built at */
    c->rtH = r.bottom - r.top;

    col.r = col.g = col.b = 0.0f; col.a = 1.0f;
    /* ID2D1RenderTarget::CreateSolidColorBrush - slot 8 */
    ((HRESULT (WINAPI*)(void*, const COLORF*, const void*, void**))
     VT(c->rt)[8])(c->rt, &col, 0, &c->brush);
    return c->brush ? 1 : 0;
}

static void setColour(Grid* c, unsigned int rgb) {
    COLORF col;
    col.r = (float)((rgb >> 16) & 0xFF) / 255.0f;
    col.g = (float)((rgb >>  8) & 0xFF) / 255.0f;
    col.b = (float)( rgb        & 0xFF) / 255.0f;
    col.a = 1.0f;
    ((void (WINAPI*)(void*, const COLORF*))VT(c->brush)[8])(c->brush, &col);  /* SetColor */
}

static void fillRect(Grid* c, float l, float t, float r, float b, unsigned int rgb) {
    RECTF rc;
    rc.l = l; rc.t = t; rc.r = r; rc.b = b;
    setColour(c, rgb);
    ((void (WINAPI*)(void*, const RECTF*, void*))VT(c->rt)[17])(c->rt, &rc, c->brush);
}

static void line(Grid* c, float x1, float y1, float x2, float y2, unsigned int rgb) {
    setColour(c, rgb);
    /* DrawLine - slot 15. Two POINT_2F by value = four floats on the stack. */
    ((void (WINAPI*)(void*, float, float, float, float, void*, float, void*))
     VT(c->rt)[15])(c->rt, x1, y1, x2, y2, c->brush, 1.0f, 0);
}

/* One character, given by code point rather than by string. The glyphs on a
   heading are not ASCII, and text() converts from ANSI on the way in, which
   would lose them. DirectWrite falls back to another font by itself if the
   chosen one has no glyph, so these draw on any Windows worth supporting. */
static void glyph(Grid* c, unsigned short ch, float l, float t, float r, float b,
                  unsigned int rgb, void* fmt) {
    WCHAR w[2];
    RECTF rc;
    w[0] = (WCHAR)ch; w[1] = 0;
    rc.l = l; rc.t = t; rc.r = r; rc.b = b;
    setColour(c, rgb);
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[3])(fmt, DW_CENTER);
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[5])(fmt, DW_NO_WRAP);
    ((void (WINAPI*)(void*, const WCHAR*, unsigned, void*, const RECTF*, void*, int, int))
     VT(c->rt)[27])(c->rt, w, 1, fmt, &rc, c->brush, 0, 0);
}

static void text(Grid* c, const char* s, float l, float t, float r, float b,
                 unsigned int rgb, int align, void* fmt, int wrap) {
    WCHAR w[G_TEXT * 2];
    RECTF rc;
    int   n = 0;
    if (!s || !s[0]) return;
    wide(s, w, G_TEXT * 2);
    while (w[n]) n++;
    if (!n) return;
    /* the caller has already reserved the padding it wants */
    rc.l = l; rc.t = t; rc.r = r; rc.b = b;
    setColour(c, rgb);
    /* IDWriteTextFormat::SetTextAlignment - slot 3. Set it per cell rather
       than keeping six formats about; it is a field assignment, not work. */
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[3])(fmt,
        align == 1 ? DW_TRAILING : (align == 2 ? DW_CENTER : DW_LEADING));
    /* IDWriteTextFormat::SetWordWrapping - slot 5, set the same way and for
       the same reason: it is a field assignment, not work. */
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[5])(fmt, wrap ? DW_WRAP : DW_NO_WRAP);
    ((void (WINAPI*)(void*, const WCHAR*, unsigned, void*, const RECTF*, void*, int, int))
     VT(c->rt)[27])(c->rt, w, (unsigned)n, fmt, &rc, c->brush, 0, 0);
}

/* How many lines this text takes at this width - DirectWrite's answer, not a
   guess from character counts. A layout is built, asked and released; the
   wrapping is set on the LAYOUT rather than the format, because the layout
   copied whatever state the last draw left the format in. */
static int measureLines(Grid* c, const char* s, int width) {
    WCHAR w[G_TEXT * 2];
    void* lay = 0;
    DWTM  tm;
    int   n = 0;
    if (!s || !s[0] || width < 8 || !g_dw || !c->fmt) return 1;
    wide(s, w, G_TEXT * 2);
    while (w[n]) n++;
    if (!n) return 1;
    /* IDWriteFactory::CreateTextLayout - slot 18. maxWidth and maxHeight go
       by value, the same two-floats-on-the-stack shape DrawLine uses. */
    if (((HRESULT (WINAPI*)(void*, const WCHAR*, unsigned, void*, float, float, void**))
         VT(g_dw)[18])(g_dw, w, (unsigned)n, c->fmt, (float)width, 100000.0f, &lay) < 0
        || !lay) return c->wrapLines;   /* cannot measure: fail TALL. The draw
           still wraps this cell, and a row sized short would let line two
           paint over the row below - overlap that reads as corruption. */
    ((HRESULT (WINAPI*)(void*, int))VT(lay)[5])(lay, DW_WRAP);   /* SetWordWrapping */
    tm.lineCount = 1;
    /* IDWriteTextLayout::GetMetrics - slot 60 */
    if (((HRESULT (WINAPI*)(void*, DWTM*))VT(lay)[60])(lay, &tm) < 0 || tm.lineCount < 1)
        tm.lineCount = 1;
    ((unsigned long (WINAPI*)(void*))VT(lay)[2])(lay);           /* Release */
    return (int)tm.lineCount;
}

/* Is this grid drawing rows of different heights right now? One question,
   asked the same way everywhere geometry is computed - the draw, the hit
   test, the scroll and the measure all have to agree or a click lands on
   the wrong row. */
static int varOn(Grid* c) {
    return c->wrap && c->varRows && !c->grps && c->wrapLines > 1;
}

/* The row heights variable mode draws from: every pushed cell measured at its
   column's width, the worst cell setting its row, clamped to the wrap
   allowance. Runs when the page or the widths have changed - never per paint,
   because a layout per cell is real work and a paint happens on every mouse
   move. Cells are measured at the width text() draws them at, four pixels of
   padding off each side. While a column edge is being dragged the measuring
   is held off entirely (noMeasure) - a drag paints on every mouse move, and
   the flag stays dirty so the button-up repaint measures once. */
static void d2g_Measure(Grid* c) {
    int i, col, m, n;
    if (!c->linesDirty || c->noMeasure) return;
    c->linesDirty = 0;
    for (i = 0; i < c->visRows; i++) {
        m = 1;
        if (varOn(c)) {
            for (col = 0; col < c->cols; col++) {
                if (c->colW[col] <= 16 || !c->cell[i][col][0]) continue;
                n = measureLines(c, c->cell[i][col], c->colW[col] - 8);
                if (n > m) m = n;
                if (m >= c->wrapLines) { m = c->wrapLines; break; }   /* cannot get taller */
            }
        }
        c->rowLines[i] = m;
    }
}

/* How tall visible row i is. Uniform mode: the one height every row has.
   Variable mode: the wrap allowance divided back into lines - so a developer
   who asked for taller rows keeps them taller - times the lines this row
   measured. */
static int rowHAt(Grid* c, int i) {
    if (!varOn(c)) return c->rowH;
    return (c->rowH / c->wrapLines) *
           ((i >= 0 && i < c->visRows && c->rowLines[i] >= 1) ? c->rowLines[i] : 1);
}

/* ---- the paint -----------------------------------------------------------
   Frozen columns are drawn LAST, on top, and the scrolling ones are clipped to
   the right of them. Drawn in plain left-to-right order the scrolling columns
   come after the frozen ones and paint straight over them, which is exactly
   what you see if you freeze two columns and scroll: the third slides over the
   first two instead of under them.                                          */
static void d2g_Draw(Grid* c) {
    RECT  r;
    RECTF clip;
    int   i, col, x, fx, rowsDrawn, absRow, frozenW, barW, lineH, rowY;
    float top, bot, cl, cr;

    if (!c->rt && !d2g_MakeTarget(c)) return;
    d2g_Measure(c);                    /* row heights first; cheap when clean */
    GetClientRect(c->hwnd, &r);
    barW = c->vBar ? barTakes(c) : 0;
    r.right  -= barW;                      /* the columns stop at the scrollbar */
    r.bottom -= c->hBar ? barTakes(c) : 0; /* and the rows stop above one       */

    lineH = (c->lines > 1) ? (c->rowH / c->lines) : c->rowH;
    frozenW = 0;
    if (c->grps) {                               /* frozen counts GROUPS, not fields */
        for (col = 0; col < c->frozen && col < c->grps; col++) frozenW += c->grpW[col];
    } else {
        for (col = 0; col < c->frozen && col < c->cols; col++) frozenW += c->colW[col];
    }

    ((void (WINAPI*)(void*))VT(c->rt)[48])(c->rt);                     /* BeginDraw */
    {
        COLORF bg;
        bg.r = (float)((c->cBack >> 16) & 0xFF) / 255.0f;
        bg.g = (float)((c->cBack >>  8) & 0xFF) / 255.0f;
        bg.b = (float)( c->cBack        & 0xFF) / 255.0f;
        bg.a = 1.0f;
        ((void (WINAPI*)(void*, const COLORF*))VT(c->rt)[47])(c->rt, &bg);   /* Clear */
    }

    /* everything below the header is clipped, so a part-row at the top cannot
       paint over the titles - that is what makes pixel scrolling possible */
    clip.l = 0.0f; clip.t = (float)c->hdrH;
    clip.r = (float)r.right; clip.b = (float)r.bottom;
    ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);

    /* Where each row starts is the sum of the heights above it - which is the
       same i * rowH it always was until variable mode makes the heights
       differ, so the one accumulation serves both. */
    rowsDrawn = c->visRows;
    rowY = c->hdrH - c->scrollY;
    for (i = 0; i < rowsDrawn; i++) {
        unsigned int back, fore;
        int rh = rowHAt(c, i);
        top = (float)rowY;
        bot = top + (float)rh;
        rowY += rh;
        if (bot < (float)c->hdrH) continue;
        if (top > (float)r.bottom) break;
        absRow = c->firstRow + i;
        if (absRow == c->selRow)      { back = c->cSelBack; fore = c->cSelText; }
        else if (i & 1)               { back = c->cBand;    fore = c->cText;    }
        else                          { back = c->cBack;    fore = c->cText;    }
        fillRect(c, 0.0f, top, (float)r.right, bot, back);

        /* --- the scrolling columns, kept off the frozen strip -------------- */
        clip.l = (float)frozenW; clip.t = top;
        clip.r = (float)r.right; clip.b = bot;
        ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
        x = -c->scrollX;
        for (col = 0; col < c->cols; col++) {
            float ty, tb;
            if (c->grps) {                       /* grouped: it says where it goes */
                if (c->colGrp[col] < c->frozen) continue;   /* drawn with the frozen block */
                cl = (float)(c->colX[col] - c->scrollX);
                ty = top + (float)(c->colLine[col] * lineH);
                tb = ty + (float)lineH;
            } else {
                cl = (float)x;
                ty = top;
                tb = bot;
            }
            cr = cl + c->colW[col];
            if ((c->grps || col >= c->frozen) && cr > (float)frozenW && cl < (float)r.right)
                text(c, c->cell[i][col], cl + 4.0f, ty + 1.0f, cr - 4.0f, tb,
                     fore, c->colAlign[col], c->fmt, c->wrap);
            x += c->colW[col];
        }
        ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);

        /* --- then the frozen ones, on top of them ------------------------- */
        if (c->frozen > 0) {
            fillRect(c, 0.0f, top, (float)frozenW, bot, back);         /* wipe what slid under */
            clip.l = 0.0f; clip.t = top; clip.r = (float)frozenW; clip.b = bot;
            ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
            if (c->grps) {
                for (col = 0; col < c->cols; col++) {
                    float ty;
                    if (c->colGrp[col] >= c->frozen) continue;
                    ty = top + (float)(c->colLine[col] * lineH);
                    text(c, c->cell[i][col], (float)c->colX[col] + 4.0f, ty + 1.0f,
                         (float)(c->colX[col] + c->colW[col]) - 4.0f, ty + (float)lineH,
                         fore, c->colAlign[col], c->fmt, c->wrap);
                }
            } else {
                fx = 0;
                for (col = 0; col < c->frozen && col < c->cols; col++) {
                    text(c, c->cell[i][col], (float)fx + 4.0f, top + 1.0f,
                         (float)(fx + c->colW[col]) - 4.0f, bot, fore, c->colAlign[col], c->fmt, c->wrap);
                    fx += c->colW[col];
                }
            }
            ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);
        }
        line(c, 0.0f, bot - 0.5f, (float)r.right, bot - 0.5f, c->cGrid);
    }
    ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);                     /* done with the rows */

    /* ---- the column lines, scrolling ones clipped the same way ---------- */
    clip.l = (float)frozenW; clip.t = 0.0f;
    clip.r = (float)r.right; clip.b = (float)r.bottom;
    ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
    if (c->grps) {
        for (col = c->frozen; col < c->grps; col++) {
            x = c->grpX[col] + c->grpW[col] - c->scrollX;
            if ((float)x > (float)frozenW && (float)x < (float)r.right)
                line(c, (float)x - 0.5f, 0.0f, (float)x - 0.5f, (float)r.bottom, c->cGrid);
        }
    } else {
        x = -c->scrollX;
        for (col = 0; col < c->cols; col++) {
            x += c->colW[col];
            if (col >= c->frozen && (float)x > (float)frozenW && (float)x < (float)r.right)
                line(c, (float)x - 0.5f, 0.0f, (float)x - 0.5f, (float)r.bottom, c->cGrid);
        }
    }
    ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);

    /* ---- the header, over the rows -------------------------------------- */
    fillRect(c, 0.0f, 0.0f, (float)r.right, (float)c->hdrH, c->cHdrBack);
    clip.l = (float)frozenW; clip.t = 0.0f;
    clip.r = (float)r.right; clip.b = (float)c->hdrH;
    ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
    if (c->grps) {
        int hLine = (c->lines > 1) ? (c->hdrH / c->lines) : c->hdrH;
        for (col = c->frozen; col < c->grps; col++) {          /* the group, spanning */
            cl = (float)(c->grpX[col] - c->scrollX);
            cr = cl + c->grpW[col];
            if (cr > (float)frozenW && cl < (float)r.right) {
                text(c, c->grpTitle[col], cl + 4.0f, 2.0f,
                     cr - (c->btns ? (float)(D2G_BTNW + 6) : 4.0f), (float)c->hdrH,
                     c->cHdrText, 2, c->fmtHdr, 0);
                if (c->btns) {
                    int scol, sdir = 0, fcol = 0, i;
                    for (i = 0; i < c->cols; i++) if (c->colGrp[i] == col) {
                        if (i == c->sortCol)   sdir = c->sortDir;
                        if (c->colFilt[i]) fcol = 1;
                    }
                    scol = sdir;
                    filterBtn(c, cr, (float)(c->hdrH / 2), c->cHdrText,
                              fcol ? c->cSelBack : c->cHdrBack, scol, fcol);
                }
                line(c, cr - 0.5f, 0.0f, cr - 0.5f, (float)c->hdrH, c->cGrid);
            }
        }
        for (col = 0; col < c->cols; col++) {                  /* and each column's own */
            float hy;
            if (c->colGrp[col] < c->frozen) continue;
            cl = (float)(c->colX[col] - c->scrollX);
            cr = cl + c->colW[col];
            hy = (float)(c->colLine[col] * hLine);
            if (cr > (float)frozenW && cl < (float)r.right)
                text(c, c->colTitle[col], cl + 4.0f, hy + 2.0f, cr - 4.0f, hy + (float)hLine,
                     c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
        }
    }
    x = -c->scrollX;
    for (col = 0; col < c->cols && !c->grps; col++) {
        cl = (float)x;
        cr = cl + c->colW[col];
        if (col >= c->frozen && cr > (float)frozenW && cl < (float)r.right) {
            float bw = c->btns ? (float)(D2G_BTNW + 4) : 0.0f;
            float tr = cr - bw - ((!c->btns && col == c->sortCol) ? 14.0f : 4.0f);
            text(c, c->colTitle[col], cl + 4.0f, 2.0f, tr, (float)c->hdrH,
                 c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
            if (c->btns)
                filterBtn(c, cr, (float)(c->hdrH / 2), c->cHdrText,
                          c->colFilt[col] ? c->cSelBack : c->cHdrBack,
                          (col == c->sortCol) ? c->sortDir : 0,
                          c->colFilt[col]);
            else if (col == c->sortCol)
                sortMark(c, cr, (float)(c->hdrH / 2) - 2.0f, c->sortDir, c->cHdrText);
            line(c, cr - 0.5f, 0.0f, cr - 0.5f, (float)c->hdrH, c->cGrid);
        }
        x += c->colW[col];
    }
    ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);

    if (c->frozen > 0) {                                    /* frozen headings on top */
        fillRect(c, 0.0f, 0.0f, (float)frozenW, (float)c->hdrH, c->cHdrBack);
        clip.l = 0.0f; clip.t = 0.0f; clip.r = (float)frozenW; clip.b = (float)c->hdrH;
        ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
        if (c->grps) {
            int hLine = (c->lines > 1) ? (c->hdrH / c->lines) : c->hdrH;
            for (col = 0; col < c->frozen && col < c->grps; col++) {
                float ge = (float)(c->grpX[col] + c->grpW[col]);
                text(c, c->grpTitle[col], (float)c->grpX[col] + 4.0f, 2.0f, ge - 4.0f,
                     (float)c->hdrH, c->cHdrText, 2, c->fmtHdr, 0);
                line(c, ge - 0.5f, 0.0f, ge - 0.5f, (float)c->hdrH, c->cGrid);
            }
            for (col = 0; col < c->cols; col++) {
                float hy;
                if (c->colGrp[col] >= c->frozen) continue;
                hy = (float)(c->colLine[col] * hLine);
                text(c, c->colTitle[col], (float)c->colX[col] + 4.0f, hy + 2.0f,
                     (float)(c->colX[col] + c->colW[col]) - 4.0f, hy + (float)hLine,
                     c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
            }
        }
        fx = 0;
        for (col = 0; col < c->frozen && col < c->cols && !c->grps; col++) {
            float cre = (float)(fx + c->colW[col]);
            {
                float bw = c->btns ? (float)(D2G_BTNW + 4) : 0.0f;
                text(c, c->colTitle[col], (float)fx + 4.0f, 2.0f,
                     cre - bw - ((!c->btns && col == c->sortCol) ? 14.0f : 4.0f), (float)c->hdrH,
                     c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
                if (c->btns)
                    filterBtn(c, cre, (float)(c->hdrH / 2), c->cHdrText,
                              c->colFilt[col] ? c->cSelBack : c->cHdrBack,
                              (col == c->sortCol) ? c->sortDir : 0,
                              c->colFilt[col]);
                else if (col == c->sortCol)
                    sortMark(c, cre, (float)(c->hdrH / 2) - 2.0f, c->sortDir, c->cHdrText);
            }
            fx += c->colW[col];
            line(c, (float)fx - 0.5f, 0.0f, (float)fx - 0.5f, (float)c->hdrH, c->cGrid);
        }
        ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);
        /* the edge of the frozen block, so it reads as a seam */
        line(c, (float)frozenW - 0.5f, 0.0f, (float)frozenW - 0.5f, (float)r.bottom, c->cGrid);
    }
    line(c, 0.0f, (float)c->hdrH - 0.5f, (float)r.right, (float)c->hdrH - 0.5f, c->cGrid);

    /* ---- the scrollbars, drawn last so nothing paints over them ---------
       An overlay is drawn ON TOP of the rows rather than beside them, so it
       measures against the full client area, takes no width from the data, and
       appears only while the pointer is over the grid. */
    {
        RECT  full;
        int   thick = barThick(c);
        int   over  = (c->barStyle == 2);
        int   vis   = (!over || c->barsShow);
        GetClientRect(c->hwnd, &full);
        if (c->vBar && vis) {
            int   top, len, tTop, tLen;
            float bl = (float)(full.right - thick), br = (float)full.right;
            d2g_VGeom(c, &top, &len, &tTop, &tLen);
            if (!over) {
                fillRect(c, bl, 0.0f, br, (float)full.bottom, c->cBand);
                line(c, bl + 0.5f, 0.0f, bl + 0.5f, (float)full.bottom, c->cGrid);
            }
            fillRect(c, bl + 2.0f, (float)tTop + 2.0f,
                        br - 2.0f, (float)(tTop + tLen) - 2.0f, c->cHdrBack);
        }
        if (c->hBar && vis) {
            int   left, len, tLeft, tLen;
            float bt = (float)(full.bottom - thick), bb = (float)full.bottom;
            d2g_HGeom(c, &left, &len, &tLeft, &tLen);
            if (!over) {
                fillRect(c, 0.0f, bt, (float)full.right, bb, c->cBand);
                line(c, 0.0f, bt + 0.5f, (float)full.right, bt + 0.5f, c->cGrid);
            }
            fillRect(c, (float)tLeft + 2.0f, bt + 2.0f,
                        (float)(tLeft + tLen) - 2.0f, bb - 2.0f, c->cHdrBack);
        }
    }

    /* ---- a heading being carried: the ghost chip and the drop line ------
       Drawn after everything, so it rides on top. The chip is the carried
       column's own heading - same colours, same font - floating under the
       pointer; the drop line stands where the drop would PUT the column,
       which is the far side of the target coming from the left and the near
       side coming from the right, because that is what the drop itself does.
       Flat formats only, which is all the Clarion side reorders. */
    if (c->carry && !c->grps) {
        int   src = c->carry - 1;
        int   tgt = -1, col, at, fx = 0, x = c->carryX;
        float ex, cw, chipL, chipR;
        for (col = 0; col < c->frozen && col < c->cols; col++) {
            if (tgt < 0 && x >= fx && x < fx + c->colW[col]) tgt = col;
            fx += c->colW[col];
        }
        if (tgt < 0 && x >= fx) {
            at = -c->scrollX;
            for (col = 0; col < c->cols; col++) {
                if (col >= c->frozen && x >= at && x < at + c->colW[col]) { tgt = col; break; }
                at += c->colW[col];
            }
        }
        if (tgt >= 0 && tgt != src) {
            at = 0;
            for (col = 0; col < tgt; col++) at += c->colW[col];
            if (tgt >= c->frozen) at -= c->scrollX;
            ex = (float)(tgt > src ? at + c->colW[tgt] : at);
            fillRect(c, ex - 1.5f, 0.0f, ex + 1.5f, (float)r.bottom, c->cSelBack);
        }
        cw = (float)c->colW[src];
        if (cw > 160.0f) cw = 160.0f;
        chipL = (float)x - cw / 2.0f;
        chipR = chipL + cw;
        fillRect(c, chipL, 2.0f, chipR, (float)c->hdrH - 2.0f, c->cHdrBack);
        line(c, chipL + 0.5f, 2.0f, chipL + 0.5f, (float)c->hdrH - 2.0f, c->cText);
        line(c, chipR - 0.5f, 2.0f, chipR - 0.5f, (float)c->hdrH - 2.0f, c->cText);
        line(c, chipL, 2.5f, chipR, 2.5f, c->cText);
        line(c, chipL, (float)c->hdrH - 2.5f, chipR, (float)c->hdrH - 2.5f, c->cText);
        text(c, c->colTitle[src], chipL + 4.0f, 3.0f, chipR - 4.0f,
             (float)c->hdrH - 3.0f, c->cText, 0, c->fmtHdr, 0);
    }

    if (((HRESULT (WINAPI*)(void*, void*, void*))VT(c->rt)[49])(c->rt, 0, 0) < 0) {
        if (c->brush) { ((unsigned long (WINAPI*)(void*))VT(c->brush)[2])(c->brush); c->brush = 0; }
        if (c->rt)    { ((unsigned long (WINAPI*)(void*))VT(c->rt)[2])(c->rt);       c->rt = 0; }
        InvalidateRect(c->hwnd, 0, 0);
    }
}

static long WINAPI d2g_WndProc(HWND h, UINT msg, UINT wp, long lp) {
    int i;
    Grid* c = 0;
    char ps[128];
    for (i = 1; i <= G_MAX; i++) if (g_g[i].used && g_g[i].hwnd == h) { c = &g_g[i]; break; }
    if (!c) return DefWindowProcA(h, msg, wp, lp);
    if (msg == WM_PAINT)      { BeginPaint(h, ps); d2g_Draw(c); EndPaint(h, ps); return 0; }
    if (msg == WM_ERASEBKGND) return 1;
    return CallWindowProcA(c->oldProc, h, msg, wp, lp);
}

/* ========================================================================== */
/*  What Clarion calls                                                        */
/* ========================================================================== */

int d2g_Available(void) { return d2g_Factories() ? 1 : 0; }

int d2g_Attach(void* hwnd, const char* face, int pt) {
    int i;
    Grid* c;
    if (!hwnd || !IsWindow((HWND)hwnd) || !d2g_Factories()) return 0;
    for (i = 1; i <= G_MAX; i++) if (!g_g[i].used) break;
    if (i > G_MAX) return 0;
    c = &g_g[i];
    c->used = 1; c->hwnd = (HWND)hwnd; c->rt = 0; c->brush = 0;
    c->sortCol = -1; c->sortDir = 1;
    { int k; for (k = 0; k < G_COLS; k++) c->colFilt[k] = 0; }
    c->grps = 0; c->lines = 1; c->wrapLines = 1; c->btns = 0;
    c->barStyle = 0; c->hBar = 0; c->barsShow = 0;
    c->cols = 0; c->frozen = 0; c->visRows = 0; c->firstRow = 0;
    c->totalRows = 0; c->selRow = -1; c->scrollX = 0;
    c->rowH = D2G_ROWFOR(pt); c->hdrH = D2G_HDRFOR(pt);
    c->cBack = 0xFFFFFF; c->cBand = 0xF5F7FA; c->cGrid = 0xE1E5EA;
    c->cText = 0x1F2933; c->cHdrBack = 0x2B3A4A; c->cHdrText = 0xFFFFFF;
    c->cSelBack = 0x2F6FB5; c->cSelText = 0xFFFFFF;
    if (!d2g_MakeTarget(c)) { c->used = 0; return 0; }
    c->fmt     = d2g_Font(face, (float)pt, 0);
    c->fmtHdr  = d2g_Font(face, (float)pt, 1);
    /* Segoe MDL2 Assets is on Windows 10, Segoe Fluent Icons on 11; whichever
       resolves, the funnel is at the same code point. If neither is there
       DirectWrite falls back and the filled button still says it is filtered,
       so nothing depends on this being found. */
    c->fmtIcon = d2g_Font("Segoe MDL2 Assets", (float)pt, 0);
    if (!c->fmt || !c->fmtHdr) { c->used = 0; return 0; }
    c->wrap = 0; c->wrapLines = 1;
    c->varRows = 0; c->linesDirty = 0; c->noMeasure = 0;
    { int k; for (k = 0; k < 63 && face[k]; k++) c->face[k] = face[k]; c->face[k] = 0; }
    c->pt = pt;
    c->oldProc = (WNDPROC)GetWindowLongA((HWND)hwnd, GWL_WNDPROC);
    SetWindowLongA((HWND)hwnd, GWL_WNDPROC, (long)d2g_WndProc);
    return i;
}

void d2g_Detach(int h) {
    Grid* c = slot(h);
    if (!c) return;
    if (c->oldProc && IsWindow(c->hwnd))
        SetWindowLongA(c->hwnd, GWL_WNDPROC, (long)c->oldProc);
    if (c->brush)  ((unsigned long (WINAPI*)(void*))VT(c->brush)[2])(c->brush);
    if (c->fmtIcon)((unsigned long (WINAPI*)(void*))VT(c->fmtIcon)[2])(c->fmtIcon);
    if (c->fmt)    ((unsigned long (WINAPI*)(void*))VT(c->fmt)[2])(c->fmt);
    if (c->fmtHdr) ((unsigned long (WINAPI*)(void*))VT(c->fmtHdr)[2])(c->fmtHdr);
    if (c->rt)     ((unsigned long (WINAPI*)(void*))VT(c->rt)[2])(c->rt);
    c->used = 0; c->hwnd = 0; c->rt = 0; c->brush = 0;
}

/* ---- shape ---------------------------------------------------------------- */
void d2g_Columns(int h, int n) {
    Grid* c = slot(h);
    if (!c) return;
    if (n < 0) n = 0;
    if (n > G_COLS) n = G_COLS;
    c->cols = n;
}

void d2g_Column(int h, int col, int width, int align, const char* title) {
    Grid* c = slot(h);
    int i;
    if (!c || col < 0 || col >= G_COLS) return;
    c->colW[col] = width < 8 ? 8 : width;
    c->colAlign[col] = align;
    c->linesDirty = 1;              /* every other colW writer marks the cache */
    for (i = 0; i < G_TEXT - 1 && title && title[i]; i++) c->colTitle[col][i] = title[i];
    c->colTitle[col][i] = 0;
}

void d2g_Frozen(int h, int n)      { Grid* c = slot(h); if (c) c->frozen = n; }
/* A row can never be shorter than the type needs. Whatever asks - the LIST's
   line height, the developer's own setting - it is clamped here, because the
   alternative is big type crammed into short rows with its descenders cut off
   by the row below, and there are several paths that can ask. One place, once,
   instead of trusting all of them to have thought about it. */
void d2g_RowHeight(int h, int px) {
    Grid* c = slot(h);
    int   need;
    if (!c || px <= 4) return;
    need = D2G_ROWH(c);
    c->rowH = px < need ? need : px;
}

/* what the type needs, so the Clarion side can keep the LIST in step */
int d2g_RowNeed(int h) { Grid* c = slot(h); return c ? D2G_ROWH(c) : 0; }
void d2g_HeaderHeight(int h,int px){
    Grid* c = slot(h);
    int   need;
    if (!c || px < 0) return;
    need = D2G_HDRFOR(c->pt);
    c->hdrH = (px && px < need) ? need : px;   /* 0 means no heading at all */
}
void d2g_Total(int h, int n)       { Grid* c = slot(h); if (c) c->totalRows = n; }
void d2g_Select(int h, int row)    { Grid* c = slot(h); if (c) c->selRow = row; }
void d2g_ScrollX(int h, int x)     { Grid* c = slot(h); if (c) c->scrollX = x < 0 ? 0 : x; }
void d2g_ScrollY(int h, int y)     { Grid* c = slot(h);
                                     if (c) c->scrollY = (y < 0 || varOn(c)) ? 0 : y; }
int  d2g_RowH(int h)               { Grid* c = slot(h); return c ? c->rowH : 0; }
int  d2g_HeaderH(int h)            { Grid* c = slot(h); return c ? c->hdrH : 0; }

void d2g_Colours(int h, unsigned int back, unsigned int band, unsigned int grid,
                 unsigned int txt, unsigned int hdrBack, unsigned int hdrText,
                 unsigned int selBack, unsigned int selText) {
    Grid* c = slot(h);
    if (!c) return;
    c->cBack = back; c->cBand = band; c->cGrid = grid; c->cText = txt;
    c->cHdrBack = hdrBack; c->cHdrText = hdrText;
    c->cSelBack = selBack; c->cSelText = selText;
}

/* ---- the page of rows Clarion pushes in ---------------------------------- */
void d2g_Page(int h, int firstRow, int rows) {
    Grid* c = slot(h);
    if (!c) return;
    if (rows < 0) rows = 0;
    if (rows > G_VIS) rows = G_VIS;
    c->firstRow = firstRow;
    c->visRows  = rows;
    c->linesDirty = 1;
}

void d2g_Cell(int h, int visRow, int col, const char* s) {
    Grid* c = slot(h);
    int i;
    if (!c || visRow < 0 || visRow >= G_VIS || col < 0 || col >= G_COLS) return;
    for (i = 0; i < G_TEXT - 1 && s && s[i]; i++) c->cell[visRow][col][i] = s[i];
    c->cell[visRow][col][i] = 0;
    c->linesDirty = 1;
}

void d2g_Repaint(int h) { Grid* c = slot(h); if (c) InvalidateRect(c->hwnd, 0, 0); }

int d2g_PaintNow(int h) { Grid* c = slot(h); if (!c) return 0; d2g_Draw(c); return 1; }

/* Cheap enough to call whenever anything MIGHT have changed the client area -
   it does nothing at all unless it actually did. That matters because a
   scrollbar appearing or disappearing resizes the client area behind your
   back: hide the horizontal bar and the client grows by its height, and the
   strip it vacated is not covered by the render target until this has run. */
int d2g_Resize(int h) {
    Grid* c = slot(h);
    RECT  r;
    SIZEU s;
    if (!c) return 0;
    if (!c->rt && !d2g_MakeTarget(c)) return 0;
    GetClientRect(c->hwnd, &r);
    s.w = (unsigned)(r.right - r.left);
    s.h = (unsigned)(r.bottom - r.top);
    if (s.w < 1 || s.h < 1) return 0;
    if ((int)s.w == c->rtW && (int)s.h == c->rtH) return 1;    /* nothing moved */
    ((HRESULT (WINAPI*)(void*, const SIZEU*))VT(c->rt)[58])(c->rt, &s);
    c->rtW = (int)s.w;
    c->rtH = (int)s.h;
    InvalidateRect(c->hwnd, 0, 0);
    return 1;
}

/* how many whole rows fit below the header - what the Clarion side needs to
   know to fill a page */
/* how wide every column is together, and how wide the view is - what a
   horizontal scrollbar needs to size itself */
int d2g_TotalWidth(int h) {
    Grid* c = slot(h);
    int col, w = 0;
    if (!c) return 0;
    if (c->grps) {
        for (col = 0; col < c->grps; col++) w += c->grpW[col];
        return w;
    }
    for (col = 0; col < c->cols; col++) w += c->colW[col];
    return w;
}

int d2g_ViewWidth(int h) {
    Grid* c = slot(h);
    RECT  r;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r);
    if (c->vBar) r.right -= barTakes(c);
    return (int)(r.right - r.left);
}

int d2g_PageSize(int h) {
    Grid* c = slot(h);
    RECT  r;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r);
    if (c->rowH < 1) return 0;
    /* In variable mode this is the CONSERVATIVE answer - rowH is the full
       wrap allowance, so this many rows fit even if every one of them wraps
       to the limit. The rows that measured shorter leave room for more;
       d2g_RowsFit says how many actually made it. The horizontal bar comes
       off the same way it does in the draw and the measured answers - five
       functions, ONE view bottom, or "fits" means different things to the
       page arithmetic and the anchor judging against it. */
    return (int)((r.bottom - r.top - c->hdrH - (c->hBar ? barTakes(c) : 0)) / c->rowH);
}

/* The other end of the same answer: how many rows fit if NONE of them wrap -
   the most records a fill could ever need to push. Computed against the base
   line directly, NOT as PageSize times the allowance: PageSize already
   floor-divided by the full allowance, and multiplying the floor back up
   loses up to a wrap-allowance of base rows - which sat at the bottom of the
   view as a blank strip whenever the visible rows happened not to wrap. */
int d2g_PageMax(int h) {
    Grid* c = slot(h);
    RECT  r;
    int   base, n;
    if (!c || !IsWindow(c->hwnd)) return 0;
    base = varOn(c) ? (c->rowH / c->wrapLines) : c->rowH;
    if (base < 1) return 0;
    GetClientRect(c->hwnd, &r);
    n = (r.bottom - r.top - c->hdrH - (c->hBar ? barTakes(c) : 0)) / base;
    /* Capped just under what a page push can hold: the fill pushes this + 1,
       and the bottom-anchor probe fills a window this + 1 deep then walks it
       backwards from its LAST row. Let it exceed the pushed window and the
       walk's index is past visRows, the walk answers 0, and the anchor lands
       on a screen showing one record. */
    return (n < G_VIS) ? n : G_VIS - 1;
}

/* How many of the pushed rows fit whole below the header, at the heights they
   measured. The Clarion side fills with the conservative page, asks this, and
   knows how far the page really reached - what Anchor needs to place the top
   record so a selection stays on screen. */
int d2g_RowsFit(int h) {
    Grid* c = slot(h);
    RECT  r;
    int   i, at, viewB;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r);
    viewB = r.bottom - (c->hBar ? barTakes(c) : 0);
    d2g_Measure(c);
    at = c->hdrH;
    for (i = 0; i < c->visRows; i++) {
        at += rowHAt(c, i);
        if (at > viewB) break;               /* this one does not fit whole */
    }
    return i;
}

/* Is there room below the last pushed row for at least one more BASE line?
   The bottom anchor asks before probing deeper - a probe costs a refill, and
   a tail already touching the bottom has nothing to gain from one. */
int d2g_TailGap(int h) {
    Grid* c = slot(h);
    RECT  r;
    int   i, at, viewB, base;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r);
    viewB = r.bottom - (c->hBar ? barTakes(c) : 0);
    base  = varOn(c) ? (c->rowH / c->wrapLines) : c->rowH;
    if (base < 1) return 0;
    d2g_Measure(c);
    at = c->hdrH;
    for (i = 0; i < c->visRows; i++) at += rowHAt(c, i);
    return (viewB - at >= base) ? 1 : 0;
}

/* How many pushed rows fit whole ENDING at visible row k - measured backwards,
   k first. The smallest scroll that brings row k fully into view keeps
   exactly this many rows: anchoring with anything less measured - a
   conservative page, a forward count - either over-scrolls, which is a click
   yanking the row it landed on up the screen, or under-scrolls, which is a
   selection still below the fold. 0 when k is not a pushed row, and the
   caller falls back to the conservative jump. */
int d2g_FitUpTo(int h, int k) {
    Grid* c = slot(h);
    RECT  r;
    int   i, at, viewB;
    if (!c || !IsWindow(c->hwnd)) return 0;
    if (k < 0 || k >= c->visRows) return 0;
    GetClientRect(c->hwnd, &r);
    viewB = r.bottom - (c->hBar ? barTakes(c) : 0);
    d2g_Measure(c);
    at = c->hdrH;
    for (i = k; i >= 0; i--) {
        at += rowHAt(c, i);
        if (at > viewB) break;               /* this one pushes k off screen */
    }
    return k - i;
}

/* which row and column a point landed on; row is absolute, -1 for the header */
int d2g_HitRow(int h, int y) {
    Grid* c = slot(h);
    if (!c || c->rowH < 1) return -1;    /* the divisor, guarded like PageSize's */
    if (y < c->hdrH) return -1;
    /* variable heights: walk the same numbers the draw accumulated. Below the
       last drawn row the uniform arithmetic takes over, so a click in the
       empty space answers a row past the data the way it always has. */
    if (varOn(c)) {
        int i, at = c->hdrH;               /* scrollY is 0 in variable mode */
        d2g_Measure(c);
        for (i = 0; i < c->visRows; i++) {
            at += rowHAt(c, i);
            if (y < at) return c->firstRow + i;
        }
        return c->firstRow + c->visRows + (y - at) / c->rowH;
    }
    return c->firstRow + (int)((y - c->hdrH + c->scrollY) / c->rowH);
}

/* Which column's RIGHT edge is under x, within a few pixels - the grab handle
   for resizing. Frozen columns keep their own edges, unscrolled. -1 for none. */
int d2g_HitEdge(int h, int x) {
    Grid* c = slot(h);
    int col, at, fx = 0;
    const int grab = 4;
    if (!c || c->grps) return -1;     /* grouped: the fields inside would have to move too */
    for (col = 0; col < c->frozen && col < c->cols; col++) {
        fx += c->colW[col];
        if (x >= fx - grab && x <= fx + grab) return col;
    }
    at = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        at += c->colW[col];
        if (col >= c->frozen && at > fx && x >= at - grab && x <= at + grab) return col;
    }
    return -1;
}

/* Which grid is drawn on this window? A scrollbar callback is handed an HWND
   and nothing else, and it has to be able to reach the grid from there. */
int d2g_FromHwnd(void* hwnd) {
    int i;
    for (i = 1; i <= G_MAX; i++)
        if (g_g[i].used && g_g[i].hwnd == (HWND)hwnd) return i;
    return 0;
}

/* ---- grouped formats ---------------------------------------------------- */
void d2g_Lines(int h, int n) {
    Grid* c = slot(h);
    if (!c || n < 1 || n > 8) return;
    c->lines = n;
    c->rowH  = D2G_ROWH(c);
    c->hdrH  = D2G_HDRFOR(c->pt) * n;          /* the headings stack the same way */
}

/* Long text runs onto another line instead of being cut off, and every row
   grows to suit. The wrapping itself is DirectWrite's - the only difference is
   which text format the cell is drawn with. */
void d2g_Wrap(int h, int on, int lines) {
    Grid* c = slot(h);
    if (!c) return;
    if (lines < 1) lines = 1;
    if (lines > 4) lines = 4;
    c->wrap      = on ? 1 : 0;
    c->wrapLines = on ? lines : 1;
    c->rowH      = D2G_ROWH(c);
    c->linesDirty = 1;
}

/* Which record is drawn at the top - the anchor's proof that the heights it
   is about to walk belong to the rows it is placing. The Clarion side's Top
   and the grid's window drift apart in exactly two places (a clamp moving
   Top, a reload changing the record set), and both are its cue to fall back
   to the conservative page instead of measuring the wrong rows. */
int d2g_FirstRow(int h) { Grid* c = slot(h); return c ? c->firstRow : -1; }

/* A column drag is starting (or ending). Held-off measuring, see d2g_Measure:
   the drag repaints on every mouse move and a layout per cell per move is
   exactly the work the cache exists to avoid. */
void d2g_Sizing(int h, int on) {
    Grid* c = slot(h);
    if (!c) return;
    c->noMeasure = on ? 1 : 0;
}

/* Grow each row only as far as its own text needs, instead of every row
   carrying the whole wrap allowance. Means nothing without wrap on; the
   Clarion side only offers it to a file-loaded, flat browse. */
void d2g_VarRows(int h, int on) {
    Grid* c = slot(h);
    if (!c) return;
    c->varRows    = on ? 1 : 0;
    c->linesDirty = 1;
    if (on) c->scrollY = 0;            /* variable mode scrolls whole rows */
}

void d2g_Groups(int h, int n) {
    Grid* c = slot(h);
    if (!c || n < 0 || n > G_COLS) return;
    c->grps = n;
}

void d2g_Group(int h, int gi, int x, int width, const char* title) {
    Grid* c = slot(h);
    int   k;
    if (!c || gi < 0 || gi >= G_COLS) return;
    c->grpX[gi]  = x;
    c->grpW[gi]  = width;
    c->grpOw[gi] = width;               /* what the fields inside were sized against */
    for (k = 0; k < G_TEXT - 1 && title[k]; k++) c->grpTitle[gi][k] = title[k];
    c->grpTitle[gi][k] = 0;
}

/* A column that says where it goes: which group, which line of the record, how
   far across, how wide. The title is the group's, so it is not repeated here. */
void d2g_ColumnAt(int h, int col, int grp, int line, int x, int width, int align,
                  const char* title) {
    Grid* c = slot(h);
    int   k;
    if (!c || col < 0 || col >= G_COLS) return;
    c->colGrp[col]   = grp;
    c->colLine[col]  = line;
    c->colX[col]     = x;
    c->colW[col]     = width;
    c->colAlign[col] = align;
    c->colOx[col] = (grp >= 0 && grp < G_COLS) ? (x - c->grpX[grp]) : 0;
    c->colOw[col] = width;
    /* Its OWN heading, if it has one. In a grouped format most of the words in
       the header belong to the columns, not the groups - "Last Name", "Major",
       "Grad Year" are the columns', and only "Address" and "Telephone" are
       their groups'. Drawing group headings alone leaves the first group blank,
       which is exactly what it did. */
    for (k = 0; k < G_TEXT - 1 && title && title[k]; k++) c->colTitle[col][k] = title[k];
    c->colTitle[col][k] = 0;
}

void d2g_SortMark(int h, int col, int dir) {
    Grid* c = slot(h);
    if (!c) return;
    c->sortCol = col;
    c->sortDir = dir < 0 ? -1 : 1;
}

void d2g_FilterBtns(int h, int on) {
    Grid* c = slot(h);
    if (c) c->btns = on ? 1 : 0;
}

/* Mark a column as filtered, or unmark it. col < 0 clears the lot, which is
   what "clear all filters" wants and what a fresh grid starts from. */
void d2g_FilterOn(int h, int col, int on) {
    Grid* c = slot(h);
    int   k;
    if (!c) return;
    if (col < 0) {
        for (k = 0; k < G_COLS; k++) c->colFilt[k] = 0;
        return;
    }
    if (col < G_COLS) c->colFilt[col] = on ? 1 : 0;
}

/* A heading picked up, moved, or put down. col is the column being carried,
   -1 to stop; x is where the pointer is. The draw paints the ghost chip and
   the drop line from these - nothing else changes until the drop actually
   reorders the columns from the Clarion side. */
void d2g_Carry(int h, int col, int x) {
    Grid* c = slot(h);
    if (!c) return;
    c->carry  = (col >= 0 && col < c->cols) ? col + 1 : 0;
    c->carryX = x;
}

/* Excel's little boxed arrow at the right of a heading, and the one place the
   column says what it is doing. There is no second sort arrow beside the title
   any more - two arrows in the same corner meaning different things is worse
   than one that means something.

      not sorted    a thin chevron: this opens a menu
      ascending     a solid triangle pointing up
      descending    a solid triangle pointing down
      filtered      the button filled, whatever the sort is doing

   Drawn out of one-pixel rows rather than a path, because there is no geometry
   sink in this binding. */
static void filterBtn(Grid* c, float right, float midY, unsigned int line_, unsigned int fill,
                      int dir, int filt) {
    float l = right - (float)D2G_BTNW - 2.0f;
    float t = midY - 7.0f;
    float r = right - 2.0f;
    float b = midY + 7.0f;
    fillRect(c, l, t, r, b, fill);
    line(c, l + 0.5f, t, l + 0.5f, b, line_);
    line(c, r - 0.5f, t, r - 0.5f, b, line_);
    line(c, l, t + 0.5f, r, t + 0.5f, line_);
    line(c, l, b - 0.5f, r, b - 0.5f, line_);
    if (filt && c->fmtIcon) {
        glyph(c, D2G_G_FILT, l, t, r, b, line_, c->fmtIcon);
    } else {
        glyph(c, (unsigned short)(!dir ? D2G_G_MENU : (dir > 0 ? D2G_G_ASC : D2G_G_DESC)),
              l, t, r, b, line_, c->fmt);
    }
}

/* which heading's button is under the pointer, -1 for none */
int d2g_HitBtn(int h, int x, int y) {
    Grid* c = slot(h);
    int   col, at, fx = 0;
    if (!c || !c->btns || y > c->hdrH) return -1;
    if (c->grps) {
        for (col = 0; col < c->grps; col++) {
            at = c->grpX[col] + c->grpW[col] - ((col < c->frozen) ? 0 : c->scrollX);
            if (x >= at - D2G_BTNW - 2 && x < at - 2) {
                int i;
                for (i = 0; i < c->cols; i++) if (c->colGrp[i] == col) return i;
                return -1;
            }
        }
        return -1;
    }
    for (col = 0; col < c->frozen && col < c->cols; col++) {
        fx += c->colW[col];
        if (x >= fx - D2G_BTNW - 2 && x < fx - 2) return col;
    }
    at = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        at += c->colW[col];
        if (col >= c->frozen && at > fx && x >= at - D2G_BTNW - 2 && x < at - 2) return col;
    }
    return -1;
}

/* A small triangle, built out of four one-pixel rows rather than a path -
   there is no geometry sink here and at this size the steps are invisible. */
static void sortMark(Grid* c, float right, float top, int dir, unsigned int rgb) {
    int   i;
    float cx = right - 5.0f;
    for (i = 0; i < 4; i++) {
        float w = (dir > 0) ? (float)(1 + i * 2) : (float)(7 - i * 2);
        float y = top + (float)i;
        fillRect(c, cx - w / 2.0f, y, cx + w / 2.0f, y + 1.0f, rgb);
    }
}

/* ---- our own vertical scrollbar ---------------------------------------- */
/* How thick a drawn bar is, and how much room it takes OUT of the rows. An
   overlay takes none - that is the whole point of it - so the two are not the
   same question and are not answered by the same function. */
static int barThick(Grid* c) {
    if (c->barStyle == 2) return 8;
    if (c->barStyle == 1) return 10;
    return D2G_BARW;
}

static int barTakes(Grid* c) { return (c->barStyle == 2) ? 0 : barThick(c); }

void d2g_BarStyle(int h, int style) {
    Grid* c = slot(h);
    if (!c || style < 0 || style > 2) return;
    c->barStyle = style;
}

/* Overlay only: the bars are shown while the pointer is over the grid. */
void d2g_BarsShow(int h, int on) {
    Grid* c = slot(h);
    if (!c) return;
    if (c->barsShow == (on ? 1 : 0)) return;
    c->barsShow = on ? 1 : 0;
    if (c->barStyle == 2) InvalidateRect(c->hwnd, 0, 0);
}

/* The drawn horizontal bar. Sideways is the grid's own business either way -
   this only changes who paints the furniture. */
void d2g_HBar(int h, int show, int pos, int page, int total) {
    Grid* c = slot(h);
    if (!c) return;
    c->hBar   = show ? 1 : 0;
    c->hPos   = pos < 0 ? 0 : pos;
    c->hPage  = page < 1 ? 1 : page;
    c->hTotal = total < 1 ? 1 : total;
    if (c->hPos > c->hTotal - c->hPage) c->hPos = c->hTotal - c->hPage;
    if (c->hPos < 0) c->hPos = 0;
}

static void d2g_HGeom(Grid* c, int* left, int* len, int* tLeft, int* tLen) {
    RECT r;
    int  l, tl, room;
    GetClientRect(c->hwnd, &r);
    l = (r.right - r.left) - (c->vBar ? barTakes(c) : 0);
    if (l < 0) l = 0;
    tl = (c->hTotal > 0) ? (l * c->hPage / c->hTotal) : l;
    if (tl < 24) tl = 24;
    if (tl > l)  tl = l;
    room = c->hTotal - c->hPage;
    *left = 0; *len = l; *tLen = tl;
    *tLeft = (room > 0) ? (l - tl) * c->hPos / room : 0;
}

/* 0 none, 4 on the thumb, 5 to the left of it, 6 to the right */
int d2g_HitHBar(int h, int x, int y) {
    Grid* c = slot(h);
    RECT  r;
    int   left, len, tLeft, tLen, top;
    if (!c || !c->hBar) return 0;
    if (c->barStyle == 2 && !c->barsShow) return 0;
    GetClientRect(c->hwnd, &r);
    top = (r.bottom - r.top) - barThick(c);
    if (y < top) return 0;
    d2g_HGeom(c, &left, &len, &tLeft, &tLen);
    if (x < tLeft) return 5;
    if (x < tLeft + tLen) return 4;
    return 6;
}

int d2g_HGrab(int h, int x) {
    Grid* c = slot(h);
    int   left, len, tLeft, tLen;
    if (!c || !c->hBar) return 0;
    d2g_HGeom(c, &left, &len, &tLeft, &tLen);
    return x - tLeft;
}

int d2g_HDrag(int h, int x, int grab) {
    Grid* c = slot(h);
    int   left, len, tLeft, tLen, room, pos;
    if (!c || !c->hBar) return 0;
    d2g_HGeom(c, &left, &len, &tLeft, &tLen);
    room = len - tLen;
    if (room < 1) return 0;
    pos = (x - grab) * (c->hTotal - c->hPage) / room;
    if (pos < 0) pos = 0;
    if (pos > c->hTotal - c->hPage) pos = c->hTotal - c->hPage;
    return pos;
}

void d2g_VBar(int h, int show, int pos, int pct) {
    Grid* c = slot(h);
    if (!c) return;
    c->vBar = show ? 1 : 0;
    c->vPos = pos < 0 ? 0 : (pos > 100 ? 100 : pos);
    c->vPct = pct < 4 ? 4 : (pct > 100 ? 100 : pct);
}

int d2g_VBarW(int h) { Grid* c = slot(h); return (c && c->vBar) ? barTakes(c) : 0; }

/* where the trough runs, and where the thumb sits inside it */
static void d2g_VGeom(Grid* c, int* top, int* len, int* tTop, int* tLen) {
    RECT r;
    int  t, l, tl;
    GetClientRect(c->hwnd, &r);
    t  = c->hdrH;
    l  = (r.bottom - r.top) - t - (c->hBar ? barTakes(c) : 0);
    if (l < 0) l = 0;
    tl = l * c->vPct / 100;
    if (tl < 24) tl = 24;
    if (tl > l)  tl = l;
    *top = t; *len = l; *tLen = tl;
    *tTop = t + (l - tl) * c->vPos / 100;
}

/* 0 nowhere near it, 1 on the thumb, 2 above it, 3 below it */
int d2g_VHit(int h, int x, int y) {
    Grid* c = slot(h);
    RECT  r;
    int   top, len, tTop, tLen;
    if (!c || !c->vBar) return 0;
    GetClientRect(c->hwnd, &r);
    if (c->barStyle == 2 && !c->barsShow) return 0;
    if (x < r.right - barThick(c)) return 0;
    d2g_VGeom(c, &top, &len, &tTop, &tLen);
    if (y < top) return 0;
    if (y < tTop) return 2;
    if (y < tTop + tLen) return 1;
    return 3;
}

/* how far down the thumb the pointer took hold - so the drag is anchored and
   the thumb does not jump under the cursor when it starts */
int d2g_VGrab(int h, int y) {
    Grid* c = slot(h);
    int   top, len, tTop, tLen;
    if (!c || !c->vBar) return 0;
    d2g_VGeom(c, &top, &len, &tTop, &tLen);
    return y - tTop;
}

/* where the thumb has been dragged to, back on the browse's 0..100 scale */
int d2g_VDrag(int h, int y, int grab) {
    Grid* c = slot(h);
    int   top, len, tTop, tLen, room, pos;
    if (!c || !c->vBar) return 0;
    d2g_VGeom(c, &top, &len, &tTop, &tLen);
    room = len - tLen;
    if (room < 1) return 0;
    pos = (y - grab - top) * 100 / room;
    return pos < 0 ? 0 : (pos > 100 ? 100 : pos);
}

/* Build the text formats again at a new size, and grow the rows to match -
   Ctrl and the wheel, the way every other program does it. Returns the size
   actually used, so the caller can see where it stopped. */
int d2g_FontSize(int h, int pt) {
    Grid* c = slot(h);
    void *f, *fh;
    if (!c) return 0;
    if (pt < 6)  pt = 6;
    if (pt > 32) pt = 32;
    if (pt == c->pt) return c->pt;
    f  = d2g_Font(c->face, (float)pt, 0);
    fh = d2g_Font(c->face, (float)pt, 1);
    if (!f || !fh) {
        if (f)  ((unsigned long (WINAPI*)(void*))VT(f)[2])(f);
        if (fh) ((unsigned long (WINAPI*)(void*))VT(fh)[2])(fh);
        return c->pt;
    }
    if (c->fmt)     ((unsigned long (WINAPI*)(void*))VT(c->fmt)[2])(c->fmt);
    if (c->fmtHdr)  ((unsigned long (WINAPI*)(void*))VT(c->fmtHdr)[2])(c->fmtHdr);
    c->fmt = f; c->fmtHdr = fh;
    /* set outright, not through d2g_RowHeight - that clamps against the size
       the type needs, and here the type is what just changed. Going through it
       would let the rows grow and never come back down. */
    /* The columns come with it. Growing the type without growing the columns
       is not a bigger grid, it is the same grid with the words too large for
       it: every cell wraps or clips and the headings run into each other. A
       zoom scales the layout, so the widths, the group boxes and every field's
       place inside its group are all taken along - including the originals a
       group resize measures against, or the next drag would undo this. */
    if (c->pt > 0 && pt != c->pt) {
        int k, was = c->pt;
        for (k = 0; k < G_COLS; k++) {
            c->colW[k]  = c->colW[k]  * pt / was;
            c->colX[k]  = c->colX[k]  * pt / was;
            c->colOx[k] = c->colOx[k] * pt / was;
            c->colOw[k] = c->colOw[k] * pt / was;
            c->grpX[k]  = c->grpX[k]  * pt / was;
            c->grpW[k]  = c->grpW[k]  * pt / was;
            c->grpOw[k] = c->grpOw[k] * pt / was;
        }
    }
    c->pt   = pt;
    c->rowH = D2G_ROWH(c);                      /* the same rule d2g_Attach uses */
    c->hdrH = D2G_HDRFOR(pt);
    c->pt = pt;
    c->linesDirty = 1;                          /* new type, new line counts */
    InvalidateRect(c->hwnd, 0, 0);
    return c->pt;
}

int d2g_FontPt(int h) { Grid* c = slot(h); return c ? c->pt : 0; }


/* ---- resizing a GROUP ---------------------------------------------------
   In a grouped format the draggable edges are the groups', not the fields' -
   there is one heading over the lot and nothing sensible to grab between two
   fields that sit on different lines. Widening a group has to carry the fields
   inside it and shift every group to its right, which is why this could not
   just reuse the flat column code. */
int d2g_HitGrpEdge(int h, int x) {
    Grid* c = slot(h);
    int   g, at;
    const int grab = 4;
    if (!c || !c->grps) return -1;
    for (g = 0; g < c->grps; g++) {
        at = c->grpX[g] + c->grpW[g] - ((g < c->frozen) ? 0 : c->scrollX);
        if (x >= at - grab && x <= at + grab) return g;
    }
    return -1;
}

int d2g_GrpWidth(int h, int g) {
    Grid* c = slot(h);
    if (!c || g < 0 || g >= c->grps) return 0;
    return c->grpW[g];
}

void d2g_SetGrpWidth(int h, int g, int w) {
    Grid* c = slot(h);
    int   old, delta, i, gx;
    if (!c || g < 0 || g >= c->grps) return;
    if (w < 32) w = 32;
    old = c->grpW[g];
    if (old < 1) return;
    gx = c->grpX[g];
    delta = w - old;
    c->grpW[g] = w;
    /* Rebuilt from the proportions the format was read with, not from where
       the fields happen to be now - so shrinking and growing again lands back
       where it started instead of collapsing everything onto the left. */
    if (c->grpOw[g] < 1) c->grpOw[g] = old;
    for (i = 0; i < c->cols; i++) {
        if (c->colGrp[i] != g) continue;
        c->colX[i] = gx + c->colOx[i] * w / c->grpOw[g];
        c->colW[i] = c->colOw[i] * w / c->grpOw[g];
        if (c->colW[i] < 8) c->colW[i] = 8;
    }
    for (i = g + 1; i < c->grps; i++) c->grpX[i] += delta;     /* everything right moves */
    for (i = 0; i < c->cols; i++) if (c->colGrp[i] > g) c->colX[i] += delta;
}

/* which field of a group is which, so the new widths can go back on the LIST */
int d2g_GrpColW(int h, int col) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return 0;
    return c->colW[col];
}

int d2g_ColGrp(int h, int col) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return -1;
    return c->colGrp[col];
}

int d2g_HdrHeight(int h) {
    Grid* c = slot(h);
    return c ? c->hdrH : 0;
}

int d2g_ColWidth(int h, int col) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return 0;
    return c->colW[col];
}

/* just the width - d2g_Column would want the title and alignment again */
void d2g_SetWidth(int h, int col, int w) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return;
    c->colW[col] = w < 16 ? 16 : w;
    c->linesDirty = 1;
}

int d2g_HitCol(int h, int x) {
    Grid* c = slot(h);
    int col, at, fx = 0;
    if (!c) return -1;
    if (c->grps) {                    /* a heading is a group: answer its first field */
        int g = -1, gx;
        for (col = 0; col < c->grps; col++) {
            gx = c->grpX[col] - ((col < c->frozen) ? 0 : c->scrollX);
            if (x >= gx && x < gx + c->grpW[col]) { g = col; break; }
        }
        if (g < 0) return -1;
        for (col = 0; col < c->cols; col++) if (c->colGrp[col] == g) return col;
        return -1;
    }
    for (col = 0; col < c->frozen && col < c->cols; col++) {   /* the frozen strip first */
        if (x >= fx && x < fx + c->colW[col]) return col;
        fx += c->colW[col];
    }
    if (x < fx) return -1;
    at = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        if (col >= c->frozen && x >= at && x < at + c->colW[col]) return col;
        at += c->colW[col];
    }
    return -1;
}

}  /* extern "C" */
