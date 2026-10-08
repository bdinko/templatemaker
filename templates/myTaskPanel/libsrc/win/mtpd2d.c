/* ============================================================================
 *  mtpd2d.c - the DirectX painter behind myTaskPanel.
 *
 *  MyTaskPanelClass does everything else in Clarion: the window, the layout,
 *  docking, the mouse. When the DirectX engine is chosen it hands each frame
 *  to this file instead of GDI: an ID2D1DCRenderTarget is bound to the
 *  panel's memory DC, the frame is drawn with Direct2D (antialiased shapes,
 *  real gradients) and DirectWrite (ClearType text with an ellipsis), and the
 *  Clarion side blits the DC to the screen as usual. Icons are drawn by GDI
 *  into the same DC after EndDraw. With the class's Effects on, the frame
 *  also gets what GDI cannot do: soft card shadows (mtpd2d_shadow), glass
 *  highlights and translucent hover fills (alpha in every colour).
 *
 *  Direct2D is COM, so only the flat entry points (D2D1CreateFactory,
 *  DWriteCreateFactory) are bound; every method is called through a
 *  hand-declared vtable (Clacpp has no DirectX headers). Only the slots used
 *  are typed, the rest are padding that keeps each method at its index.
 *  Slots checked against Windows SDK 10.0.26100 d2d1.h / dwrite.h.
 *
 *  Compiled into the program by Clarion's own C compiler:
 *      PRAGMA('compile(mtpd2d.c)')   - only when _MTP_D2D_ is defined.
 *  ABI: coordinates as double, colours as 0xAARRGGBB in a long, strings as
 *  char* (an ADDRESS() from Clarion). WINAPI == Clacpp 'pascal' == stdcall.
 * ========================================================================== */

#define WINAPI pascal
typedef long           HRESULT;
typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef unsigned short WCHAR;
typedef void*          HMODULE;
typedef int (WINAPI *FARPROC)();
typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3; unsigned char Data4[8]; } GUID;
typedef struct { long left, top, right, bottom; } RECT;

#define S_OK 0

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
DWORD   WINAPI GetCurrentThreadId(void);
void    WINAPI InitializeCriticalSection(void*);
void    WINAPI EnterCriticalSection(void*);
void    WINAPI LeaveCriticalSection(void*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);
int     WINAPI MultiByteToWideChar(UINT, DWORD, const char*, int, WCHAR*, int);

typedef struct ID2D1Factory       ID2D1Factory;
typedef struct ID2D1RenderTarget  ID2D1RenderTarget;
typedef struct ID2D1Brush         ID2D1Brush;
typedef struct ID2D1GradientStops ID2D1GradientStops;
typedef struct IDWriteFactory     IDWriteFactory;
typedef struct IDWriteTextFormat  IDWriteTextFormat;

typedef struct { float r, g, b, a; }                         D2D1_COLOR_F;
typedef struct { float left, top, right, bottom; }           D2D1_RECT_F;
typedef struct { float x, y; }                               D2D1_POINT_2F;
typedef struct { D2D1_POINT_2F point; float rx, ry; }        D2D1_ELLIPSE;
typedef struct { D2D1_RECT_F rect; float rx, ry; }           D2D1_ROUNDED_RECT;
typedef struct { int format; int alphaMode; }                D2D1_PIXEL_FORMAT;
typedef struct { int type; D2D1_PIXEL_FORMAT pixelFormat;
                 float dpiX, dpiY; int usage; int minLevel; } D2D1_RENDER_TARGET_PROPERTIES;
typedef struct { D2D1_POINT_2F startPoint, endPoint; }       D2D1_LINGRAD_PROPS;
typedef struct { float position; D2D1_COLOR_F color; }       D2D1_GRADIENT_STOP;
typedef struct { int granularity; UINT delimiter; UINT delimiterCount; } DWRITE_TRIMMING;

typedef struct { void* QueryInterface; void* AddRef; unsigned long (WINAPI* Release)(void*); } IUnknownVtbl;
typedef struct { IUnknownVtbl* v; } IUnknownObj;
static void rel(void* p) { if (p) ((IUnknownObj*)p)->v->Release(p); }

/* ---- ID2D1Factory: CreateDCRenderTarget(16) ---- */
typedef struct {
    void* QueryInterface; void* AddRef; void* Release;                 /* 0..2  */
    void* ReloadSystemMetrics; void* GetDesktopDpi;                    /* 3,4   */
    void* CreateRectangleGeometry; void* CreateRoundedRectangleGeometry;
    void* CreateEllipseGeometry; void* CreateGeometryGroup;
    void* CreateTransformedGeometry; void* CreatePathGeometry;
    void* CreateStrokeStyle; void* CreateDrawingStateBlock;
    void* CreateWicBitmapRenderTarget; void* CreateHwndRenderTarget;
    void* CreateDxgiSurfaceRenderTarget;                               /* 5..15 */
    HRESULT (WINAPI* CreateDCRenderTarget)(ID2D1Factory*, const D2D1_RENDER_TARGET_PROPERTIES*,
             ID2D1RenderTarget**);                                     /* 16    */
} ID2D1FactoryVtbl;
struct ID2D1Factory { ID2D1FactoryVtbl* v; };

/* ---- ID2D1SolidColorBrush: SetColor(8) ---- */
typedef struct {
    void* QueryInterface; void* AddRef; void* Release; void* GetFactory; /* 0..3 */
    void* SetOpacity; void* SetTransform; void* GetOpacity; void* GetTransform; /* 4..7 */
    void (WINAPI* SetColor)(ID2D1Brush*, const D2D1_COLOR_F*);         /* 8 */
} ID2D1BrushVtbl;
struct ID2D1Brush { ID2D1BrushVtbl* v; };

/* ---- ID2D1LinearGradientBrush: SetStartPoint(8) SetEndPoint(9) ---- */
typedef struct ID2D1LinBrush ID2D1LinBrush;
typedef struct {
    void* QueryInterface; void* AddRef; void* Release; void* GetFactory; /* 0..3 */
    void* SetOpacity; void* SetTransform; void* GetOpacity; void* GetTransform; /* 4..7 */
    void (WINAPI* SetStartPoint)(ID2D1LinBrush*, D2D1_POINT_2F);       /* 8 */
    void (WINAPI* SetEndPoint)(ID2D1LinBrush*, D2D1_POINT_2F);         /* 9 */
} ID2D1LinBrushVtbl;
struct ID2D1LinBrush { ID2D1LinBrushVtbl* v; };

/* ---- ID2D1DCRenderTarget : ID2D1RenderTarget ---- */
typedef struct {
    void* QueryInterface; void* AddRef; void* Release; void* GetFactory; /* 0..3 */
    void* CreateBitmap; void* CreateBitmapFromWicBitmap;
    void* CreateSharedBitmap; void* CreateBitmapBrush;               /* 4..7 */
    HRESULT (WINAPI* CreateSolidColorBrush)(ID2D1RenderTarget*, const D2D1_COLOR_F*,
             const void*, ID2D1Brush**);                              /* 8  */
    HRESULT (WINAPI* CreateGradientStopCollection)(ID2D1RenderTarget*, const D2D1_GRADIENT_STOP*,
             UINT, int, int, ID2D1GradientStops**);                   /* 9  */
    HRESULT (WINAPI* CreateLinearGradientBrush)(ID2D1RenderTarget*, const D2D1_LINGRAD_PROPS*,
             const void*, ID2D1GradientStops*, ID2D1Brush**);         /* 10 */
    void* CreateRadialGradientBrush;                                  /* 11 */
    void* CreateCompatibleRenderTarget; void* CreateLayer; void* CreateMesh; /* 12..14 */
    void (WINAPI* DrawLine)(ID2D1RenderTarget*, D2D1_POINT_2F, D2D1_POINT_2F,
             ID2D1Brush*, float, void*);                              /* 15 */
    void (WINAPI* DrawRectangle)(ID2D1RenderTarget*, const D2D1_RECT_F*,
             ID2D1Brush*, float, void*);                              /* 16 */
    void (WINAPI* FillRectangle)(ID2D1RenderTarget*, const D2D1_RECT_F*, ID2D1Brush*); /* 17 */
    void (WINAPI* DrawRoundedRectangle)(ID2D1RenderTarget*, const D2D1_ROUNDED_RECT*,
             ID2D1Brush*, float, void*);                              /* 18 */
    void (WINAPI* FillRoundedRectangle)(ID2D1RenderTarget*, const D2D1_ROUNDED_RECT*, ID2D1Brush*); /* 19 */
    void (WINAPI* DrawEllipse)(ID2D1RenderTarget*, const D2D1_ELLIPSE*,
             ID2D1Brush*, float, void*);                              /* 20 */
    void (WINAPI* FillEllipse)(ID2D1RenderTarget*, const D2D1_ELLIPSE*, ID2D1Brush*); /* 21 */
    void* DrawGeometry; void* FillGeometry; void* FillMesh;
    void* FillOpacityMask; void* DrawBitmap;                         /* 22..26 */
    void (WINAPI* DrawText)(ID2D1RenderTarget*, const WCHAR*, UINT, IDWriteTextFormat*,
             const D2D1_RECT_F*, ID2D1Brush*, int, int);               /* 27 */
    void* DrawTextLayout; void* DrawGlyphRun;                        /* 28,29 */
    void* SetTransform; void* GetTransform;                          /* 30,31 */
    void (WINAPI* SetAntialiasMode)(ID2D1RenderTarget*, int);         /* 32 */
    void* GetAntialiasMode;                                          /* 33 */
    void (WINAPI* SetTextAntialiasMode)(ID2D1RenderTarget*, int);     /* 34 */
    void* GetTextAntialiasMode;                                      /* 35 */
    void* SetTextRenderingParams; void* GetTextRenderingParams;      /* 36,37 */
    void* SetTags; void* GetTags; void* PushLayer; void* PopLayer;   /* 38..41 */
    void* Flush; void* SaveDrawingState; void* RestoreDrawingState;  /* 42..44 */
    void (WINAPI* PushAxisAlignedClip)(ID2D1RenderTarget*, const D2D1_RECT_F*, int); /* 45 */
    void (WINAPI* PopAxisAlignedClip)(ID2D1RenderTarget*);           /* 46 */
    void (WINAPI* Clear)(ID2D1RenderTarget*, const D2D1_COLOR_F*);    /* 47 */
    void (WINAPI* BeginDraw)(ID2D1RenderTarget*);                    /* 48 */
    HRESULT (WINAPI* EndDraw)(ID2D1RenderTarget*, void*, void*);     /* 49 */
    void* GetPixelFormat; void* SetDpi; void* GetDpi; void* GetSize;
    void* GetPixelSize; void* GetMaximumBitmapSize; void* IsSupported; /* 50..56 */
    HRESULT (WINAPI* BindDC)(ID2D1RenderTarget*, void*, const RECT*); /* 57 (ID2D1DCRenderTarget) */
} ID2D1RenderTargetVtbl;
struct ID2D1RenderTarget { ID2D1RenderTargetVtbl* v; };

/* ---- IDWriteFactory: CreateTextFormat(15), CreateEllipsisTrimmingSign(20) ---- */
typedef struct {
    void* QueryInterface; void* AddRef; void* Release;
    void* GetSystemFontCollection; void* CreateCustomFontCollection;
    void* RegisterFontCollectionLoader; void* UnregisterFontCollectionLoader;
    void* CreateFontFileReference; void* CreateCustomFontFileReference;
    void* CreateFontFace; void* CreateRenderingParams;
    void* CreateMonitorRenderingParams; void* CreateCustomRenderingParams;
    void* RegisterFontFileLoader; void* UnregisterFontFileLoader;     /* 3..14 */
    HRESULT (WINAPI* CreateTextFormat)(IDWriteFactory*, const WCHAR*, void*, int, int, int,
             float, const WCHAR*, IDWriteTextFormat**);               /* 15 */
    void* CreateTypography; void* GetGdiInterop; void* CreateTextLayout;
    void* CreateGdiCompatibleTextLayout;                              /* 16..19 */
    HRESULT (WINAPI* CreateEllipsisTrimmingSign)(IDWriteFactory*, IDWriteTextFormat*, void**); /* 20 */
} IDWriteFactoryVtbl;
struct IDWriteFactory { IDWriteFactoryVtbl* v; };

/* ---- IDWriteTextFormat: SetTextAlignment(3) SetParagraphAlignment(4)
        SetWordWrapping(5) SetTrimming(9) ---- */
typedef struct {
    void* QueryInterface; void* AddRef; void* Release;
    HRESULT (WINAPI* SetTextAlignment)(IDWriteTextFormat*, int);      /* 3 */
    HRESULT (WINAPI* SetParagraphAlignment)(IDWriteTextFormat*, int); /* 4 */
    HRESULT (WINAPI* SetWordWrapping)(IDWriteTextFormat*, int);       /* 5 */
    void* SetReadingDirection; void* SetFlowDirection; void* SetIncrementalTabStop; /* 6..8 */
    HRESULT (WINAPI* SetTrimming)(IDWriteTextFormat*, const DWRITE_TRIMMING*, void*); /* 9 */
} IDWriteTextFormatVtbl;
struct IDWriteTextFormat { IDWriteTextFormatVtbl* v; };

typedef HRESULT (WINAPI *PFN_D2D1CreateFactory)(int, const GUID*, const void*, void**);
typedef HRESULT (WINAPI *PFN_DWriteCreateFactory)(int, const GUID*, void**);

static GUID IID_ID2D1Factory   = {0x06152247,0x6f50,0x465a,{0x92,0x45,0x11,0x8b,0xfd,0x3b,0x60,0x07}};
static GUID IID_IDWriteFactory = {0xb859ee5a,0xd838,0x4b5b,{0xa2,0xe8,0x1a,0xdc,0x7d,0x93,0xdb,0x48}};

static int                g_ready = 0;     /* 1 = factories made, -n = failed at step n */
static ID2D1Factory*      g_d2d   = 0;     /* MULTI_THREADED: panels live on several threads */
static IDWriteFactory*    g_dw    = 0;
static HRESULT            g_hr    = 0;
static long               g_lock[8];       /* a CRITICAL_SECTION (24 bytes on Win32) */

/*  One render target per THREAD. A Clarion program runs a frame and each MDI
    child on its own thread, each with its own panel; a single shared target
    was rebound from two threads at once, and one panel's Kill released it
    under the others. Each thread now has its own target, brush and clip
    depth, found by GetCurrentThreadId(). */
#define MTP_THREADS 64
#define MTP_GRADS   16       /* gradient brushes kept per thread, by colour pair */
typedef struct { long c1, c2; ID2D1LinBrush* b; } MtpGrad;
static struct { DWORD tid; ID2D1RenderTarget* rt; ID2D1Brush* brush; int drawing; int clips;
                int rtType; MtpGrad grads[MTP_GRADS]; int nextGrad; } g_th[MTP_THREADS];

/* diagnostics (mtpd2d_diag): the render target type asked for, and the brush cache */
static int g_wantType  = 0;  /* D2D1_RENDER_TARGET_TYPE: 0 DEFAULT, 1 SOFTWARE, 2 HARDWARE */
static int g_gradCache = 1;

/* this thread's slot (made on first use); 0 when the table is full */
static int slot(int make)
{
    int i, free_ = -1;
    DWORD me = GetCurrentThreadId();
    for (i = 0; i < MTP_THREADS; i++) {
        if (g_th[i].tid == me) return i + 1;
        if (!g_th[i].tid && free_ < 0) free_ = i;
    }
    if (!make || free_ < 0) return 0;
    EnterCriticalSection(g_lock);
    if (g_th[free_].tid) { LeaveCriticalSection(g_lock); return 0; }
    g_th[free_].tid = me;
    LeaveCriticalSection(g_lock);
    return free_ + 1;
}

/* text formats, cached by face + size + weight + alignment */
#define MTP_FMTS 24
static struct { IDWriteTextFormat* f; void* sign; char face[40]; float size; int bold; int align; } g_fmt[MTP_FMTS];
static int g_nfmt = 0;
static WCHAR g_locale[2] = {0, 0};

static D2D1_COLOR_F col(long argb)
{
    D2D1_COLOR_F c;
    unsigned long u = (unsigned long)argb;
    c.a = ((u >> 24) & 0xFF) / 255.0f;
    c.r = ((u >> 16) & 0xFF) / 255.0f;
    c.g = ((u >>  8) & 0xFF) / 255.0f;
    c.b = ( u        & 0xFF) / 255.0f;
    return c;
}

static D2D1_RECT_F rc(double x, double y, double w, double h)
{
    D2D1_RECT_F r;
    r.left = (float)x; r.top = (float)y; r.right = (float)(x + w); r.bottom = (float)(y + h);
    return r;
}

static int s_eq(const char* a, const char* b) { while (*a && *a == *b) { a++; b++; } return *a == *b; }
static void s_cpy(char* d, const char* s, int max) { int i = 0; while (s[i] && i < max-1) { d[i] = s[i]; i++; } d[i] = 0; }

static void drop_target(int k)
{
    int i;
    if (k < 1) return;
    for (i = 0; i < MTP_GRADS; i++) { rel(g_th[k-1].grads[i].b); g_th[k-1].grads[i].b = 0; }
    g_th[k-1].nextGrad = 0;
    rel(g_th[k-1].brush); g_th[k-1].brush = 0;
    rel(g_th[k-1].rt);    g_th[k-1].rt = 0;
    g_th[k-1].drawing = 0;
    g_th[k-1].clips = 0;
}

/* 1 = ready. Safe to call every frame. */
int mtpd2d_init(void)
{
    HMODULE hD2D, hDW;
    PFN_D2D1CreateFactory pD2D;
    PFN_DWriteCreateFactory pDW;
    if (g_ready) return g_ready;
    InitializeCriticalSection(g_lock);
    hD2D = LoadLibraryA("d2d1.dll");   if (!hD2D) { g_ready = -1; return g_ready; }
    hDW  = LoadLibraryA("dwrite.dll"); if (!hDW)  { g_ready = -2; return g_ready; }
    *(FARPROC*)&pD2D = GetProcAddress(hD2D, "D2D1CreateFactory");
    *(FARPROC*)&pDW  = GetProcAddress(hDW,  "DWriteCreateFactory");
    if (!pD2D || !pDW) { g_ready = -3; return g_ready; }
    g_hr = pD2D(1 /*MULTI_THREADED*/, &IID_ID2D1Factory, 0, (void**)&g_d2d);
    if (g_hr != S_OK || !g_d2d) { g_ready = -4; return g_ready; }
    g_hr = pDW(0 /*SHARED*/, &IID_IDWriteFactory, (void**)&g_dw);
    if (g_hr != S_OK || !g_dw) { g_ready = -5; return g_ready; }
    g_ready = 1;
    return g_ready;
}

long mtpd2d_last_hr(void) { return g_hr; }

/* Starts a frame on an existing (memory) DC, on this thread's target. 1 = drawing. */
int mtpd2d_begin(long hdc, long w, long h)
{
    D2D1_RENDER_TARGET_PROPERTIES p;
    D2D1_COLOR_F c;
    RECT r;
    int k;
    if (mtpd2d_init() != 1) return 0;
    k = slot(1);
    if (!k) return 0;
    if (g_th[k-1].rt && g_th[k-1].rtType != g_wantType) drop_target(k);   /* the diagnostics changed it */
    if (!g_th[k-1].rt) {
        p.type = g_wantType;                /* DEFAULT unless the diagnostics say otherwise */
        g_th[k-1].rtType = g_wantType;
        p.pixelFormat.format = 87;          /* DXGI_FORMAT_B8G8R8A8_UNORM */
        p.pixelFormat.alphaMode = 3;        /* IGNORE - lets text use ClearType */
        p.dpiX = 96; p.dpiY = 96;           /* one unit = one pixel */
        p.usage = 0; p.minLevel = 0;
        g_hr = g_d2d->v->CreateDCRenderTarget(g_d2d, &p, &g_th[k-1].rt);
        if (g_hr != S_OK || !g_th[k-1].rt) { g_th[k-1].rt = 0; return 0; }
        c.r = 0; c.g = 0; c.b = 0; c.a = 1;
        g_hr = g_th[k-1].rt->v->CreateSolidColorBrush(g_th[k-1].rt, &c, 0, &g_th[k-1].brush);
        if (g_hr != S_OK || !g_th[k-1].brush) { drop_target(k); return 0; }
    }
    r.left = 0; r.top = 0; r.right = w; r.bottom = h;
    g_hr = g_th[k-1].rt->v->BindDC(g_th[k-1].rt, (void*)hdc, &r);
    if (g_hr != S_OK) { drop_target(k); return 0; }
    g_th[k-1].rt->v->BeginDraw(g_th[k-1].rt);
    g_th[k-1].rt->v->SetAntialiasMode(g_th[k-1].rt, 0);     /* PER_PRIMITIVE */
    g_th[k-1].rt->v->SetTextAntialiasMode(g_th[k-1].rt, 1); /* CLEARTYPE */
    g_th[k-1].drawing = 1;
    g_th[k-1].clips = 0;
    return 1;
}

/* this thread's target while a frame is open, else 0 */
static ID2D1RenderTarget* cur(int* pk)
{
    int k = slot(0);
    *pk = k;
    if (!k || !g_th[k-1].drawing) return 0;
    return g_th[k-1].rt;
}

/* Ends the frame. 0 = fine; otherwise the HRESULT (this thread's target is
   dropped and rebuilt on the next frame, which covers D2DERR_RECREATE_TARGET). */
long mtpd2d_end(void)
{
    int k;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt) return 0;
    while (g_th[k-1].clips > 0) { rt->v->PopAxisAlignedClip(rt); g_th[k-1].clips--; }
    g_hr = rt->v->EndDraw(rt, 0, 0);
    g_th[k-1].drawing = 0;
    if (g_hr != S_OK) { drop_target(k); return g_hr; }
    return 0;
}

static ID2D1Brush* solid(int k, long argb)
{
    D2D1_COLOR_F c = col(argb);
    g_th[k-1].brush->v->SetColor(g_th[k-1].brush, &c);
    return g_th[k-1].brush;
}

void mtpd2d_fill(double x, double y, double w, double h, long argb)
{
    int k; D2D1_RECT_F r;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt) return;
    r = rc(x, y, w, h);
    rt->v->FillRectangle(rt, &r, solid(k, argb));
}

/* Rounded rectangle; fill and/or outline (0 alpha = none). */
void mtpd2d_round(double x, double y, double w, double h, double rad, long fill, long line, double lw)
{
    int k; D2D1_ROUNDED_RECT rr;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt) return;
    rr.rect = rc(x, y, w, h); rr.rx = (float)rad; rr.ry = (float)rad;
    if (((unsigned long)fill >> 24) != 0) rt->v->FillRoundedRectangle(rt, &rr, solid(k, fill));
    if (((unsigned long)line >> 24) != 0) {
        rr.rect = rc(x + lw/2, y + lw/2, w - lw, h - lw);
        rt->v->DrawRoundedRectangle(rt, &rr, solid(k, line), (float)lw, 0);
    }
}

/* Vertical gradient c1 (top) -> c2 (bottom), optionally rounded. */
void mtpd2d_grad(double x, double y, double w, double h, double rad, long c1, long c2)
{
    int k;
    D2D1_GRADIENT_STOP st[2];
    D2D1_LINGRAD_PROPS lp;
    ID2D1GradientStops* gs = 0;
    ID2D1Brush* b = 0;
    D2D1_ROUNDED_RECT rr;
    int i, cached = 0;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt) return;
    lp.startPoint.x = (float)x; lp.startPoint.y = (float)y;
    lp.endPoint.x   = (float)x; lp.endPoint.y   = (float)(y + h);
    /* A brush is a GPU resource: making one per call is slow. Keep the last
       few by colour pair and move their end points to the new rectangle. */
    if (g_gradCache) {
        for (i = 0; i < MTP_GRADS; i++) {
            MtpGrad* g = &g_th[k-1].grads[i];
            if (g->b && g->c1 == c1 && g->c2 == c2) {
                g->b->v->SetStartPoint(g->b, lp.startPoint);
                g->b->v->SetEndPoint(g->b, lp.endPoint);
                b = (ID2D1Brush*)g->b;
                cached = 1;
                break;
            }
        }
    }
    if (!b) {
        st[0].position = 0; st[0].color = col(c1);
        st[1].position = 1; st[1].color = col(c2);
        if (rt->v->CreateGradientStopCollection(rt, st, 2, 0, 0, &gs) != S_OK || !gs) return;
        if (rt->v->CreateLinearGradientBrush(rt, &lp, 0, gs, &b) != S_OK) b = 0;
        rel(gs);                            /* the brush holds its own reference */
        if (!b) return;
        if (g_gradCache) {
            MtpGrad* g = &g_th[k-1].grads[g_th[k-1].nextGrad];
            rel(g->b);
            g->b = (ID2D1LinBrush*)b; g->c1 = c1; g->c2 = c2;
            g_th[k-1].nextGrad = (g_th[k-1].nextGrad + 1) % MTP_GRADS;
            cached = 1;
        }
    }
    rr.rect = rc(x, y, w, h); rr.rx = (float)rad; rr.ry = (float)rad;
    if (rad > 0) rt->v->FillRoundedRectangle(rt, &rr, b);
    else         rt->v->FillRectangle(rt, &rr.rect, b);
    if (!cached) rel(b);
}

/* A soft drop shadow under a rounded rectangle: n translucent rounded rects,
   each a pixel larger than the last, so their overlap fades out from the
   edge. argb's alpha is the darkest the shadow gets (right under the shape).
   Drawn before the shape, which covers the middle. */
void mtpd2d_shadow(double x, double y, double w, double h, double rad, double blur, double dy, long argb)
{
    int k, i, n;
    unsigned long a, step;
    D2D1_ROUNDED_RECT rr;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt || blur < 1) return;
    n = (int)(blur + 0.5);
    a = ((unsigned long)argb >> 24) & 0xFF;
    step = a / n; if (step < 1) step = 1;
    for (i = n; i >= 1; i--) {
        rr.rect = rc(x - i, y + dy - i, w + 2*i, h + 2*i);
        rr.rx = (float)(rad + i); rr.ry = rr.rx;
        rt->v->FillRoundedRectangle(rt, &rr, solid(k, (long)((step << 24) | ((unsigned long)argb & 0xFFFFFF))));
    }
}

void mtpd2d_line(double x1, double y1, double x2, double y2, long argb, double lw)
{
    int k; D2D1_POINT_2F a, b;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt) return;
    a.x = (float)x1; a.y = (float)y1; b.x = (float)x2; b.y = (float)y2;
    rt->v->DrawLine(rt, a, b, solid(k, argb), (float)lw, 0);
}

void mtpd2d_ellipse(double cx, double cy, double rx, double ry, long fill, long line, double lw)
{
    int k; D2D1_ELLIPSE e;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt) return;
    e.point.x = (float)cx; e.point.y = (float)cy; e.rx = (float)rx; e.ry = (float)ry;
    if (((unsigned long)fill >> 24) != 0) rt->v->FillEllipse(rt, &e, solid(k, fill));
    if (((unsigned long)line >> 24) != 0) rt->v->DrawEllipse(rt, &e, solid(k, line), (float)lw, 0);
}

void mtpd2d_clip(double x, double y, double w, double h)
{
    int k; D2D1_RECT_F r;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt) return;
    r = rc(x, y, w, h);
    rt->v->PushAxisAlignedClip(rt, &r, 0);
    g_th[k-1].clips++;
}

void mtpd2d_unclip(void)
{
    int k;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt || g_th[k-1].clips <= 0) return;
    rt->v->PopAxisAlignedClip(rt);
    g_th[k-1].clips--;
}

/* Text formats are shared by every thread (DirectWrite objects are free-
   threaded once made); the cache itself is guarded. */
static IDWriteTextFormat* format(const char* face, float size, int bold, int align)
{
    int i;
    WCHAR wface[48];
    IDWriteTextFormat* f = 0;
    DWRITE_TRIMMING t;
    void* sign = 0;
    EnterCriticalSection(g_lock);
    for (i = 0; i < g_nfmt; i++)
        if (g_fmt[i].size == size && g_fmt[i].bold == bold && g_fmt[i].align == align && s_eq(g_fmt[i].face, face)) {
            f = g_fmt[i].f;
            LeaveCriticalSection(g_lock);
            return f;
        }
    if (g_nfmt >= MTP_FMTS) { f = g_fmt[0].f; LeaveCriticalSection(g_lock); return f; }
    if (!MultiByteToWideChar(0, 0, face, -1, wface, 48)) { wface[0] = 'S'; wface[1] = 0; }
    if (g_dw->v->CreateTextFormat(g_dw, wface, 0, bold ? 600 : 400, 0, 5, size, g_locale, &f) != S_OK || !f) {
        LeaveCriticalSection(g_lock);
        return 0;
    }
    f->v->SetWordWrapping(f, 1);                     /* NO_WRAP */
    f->v->SetParagraphAlignment(f, 2);               /* vertical CENTER */
    f->v->SetTextAlignment(f, align == 1 ? 2 : (align == 2 ? 1 : 0)); /* DWrite: LEADING 0, TRAILING 1, CENTER 2 */
    if (g_dw->v->CreateEllipsisTrimmingSign(g_dw, f, &sign) == S_OK && sign) {
        t.granularity = 1; t.delimiter = 0; t.delimiterCount = 0;   /* CHARACTER */
        f->v->SetTrimming(f, &t, sign);
    }
    g_fmt[g_nfmt].f = f; g_fmt[g_nfmt].sign = sign; g_fmt[g_nfmt].size = size;
    g_fmt[g_nfmt].bold = bold; g_fmt[g_nfmt].align = align;
    s_cpy(g_fmt[g_nfmt].face, face, 40);
    g_nfmt++;
    LeaveCriticalSection(g_lock);
    return f;
}

/* align: 0 left, 1 centre, 2 right. size is in points. */
void mtpd2d_text(long txt, double x, double y, double w, double h, long argb,
                 long face, double size, long bold, long align)
{
    WCHAR buf[512];
    int n, k;
    IDWriteTextFormat* f;
    D2D1_RECT_F r;
    ID2D1RenderTarget* rt = cur(&k);
    if (!rt || !txt) return;
    f = format(face ? (const char*)face : "Segoe UI", (float)(size * 96.0 / 72.0), bold ? 1 : 0, (int)align);
    if (!f) return;
    n = MultiByteToWideChar(0, 0, (const char*)txt, -1, buf, 512);
    if (n <= 1) return;
    r = rc(x, y, w, h);
    rt->v->DrawText(rt, buf, (UINT)(n - 1), f, &r, solid(k, argb), 2 /*CLIP*/, 0 /*NATURAL*/);
}

/* Diagnostics for the speed test. what 1: the render target type (0 DEFAULT,
   1 SOFTWARE, 2 HARDWARE); every thread rebuilds its target on its next frame.
   what 2: the gradient brush cache on (1) or off (0). Returns the old value. */
long mtpd2d_diag(long what, long value)
{
    long old = 0;
    if (what == 1) { old = g_wantType; g_wantType = (int)value; }
    if (what == 2) { old = g_gradCache; g_gradCache = (int)value; }
    return old;
}

/* Releases THIS thread's target only: other panels on other threads keep
   theirs. The shared factories and text formats live until the process ends. */
void mtpd2d_kill(void)
{
    int k = slot(0);
    if (!k) return;
    drop_target(k);
    g_th[k-1].tid = 0;
}

} /* extern "C" */
