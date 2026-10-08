/* ============================================================================
 *  yurucanvas.c - a DIRECT2D direct-to-window blit shim for myYuru.
 *
 *  myYuru renders its ~10-30k particle "yuruyurau" sketch by plotting them
 *  ADDITIVELY into an in-memory 24-bit BGR buffer on the Clarion side each frame.
 *  The classic backend then writes that buffer to a temp .bmp and reloads the
 *  IMAGE control - a file round-trip that dominates the frame time.
 *
 *  This shim kills that round-trip: it hosts a bare child window over the IMAGE
 *  control and owns a GPU-accelerated Direct2D render target on it, so each
 *  frame's pixel buffer is uploaded as a bitmap and BLITTED straight to the
 *  screen (DrawBitmap + Present), no file, no PROP:Text reload. This is the
 *  same "direct-to-window, no PNG" win added to CapeSoft Draw / DrawPlus, ported
 *  to myYuru's per-pixel model - the GPU does the scale + present; the particle
 *  math stays in Clarion.
 *
 *  Direct2D is a COM API (not flat exports), so we bind the one flat entry point
 *  d2d1.dll exposes (D2D1CreateFactory) and call every interface method through a
 *  hand-declared COM vtable (Clacpp has no DirectX headers). Only the vtable
 *  slots we call are typed; the rest are void* padding to keep each method at its
 *  correct index. Direct2D ships with every Windows 7+, so NO redistributable.
 *
 *  Symbols are yuru_d2d_* so this coexists with DrawPlus's dpcanvas.c (dp_*),
 *  d2dcanvas.c (dpcanvas_d2d_*) and gpcanvas.c (gp_*) in one app - no collision.
 *  Compiled by Clacpp via PRAGMA('compile(yurucanvas.c)') in YuruClass.clw.
 *
 *  ABI: coords cross as C double (Clarion REAL); the pixel buffer as a raw
 *  char* (*STRING,RAW). WINAPI == Clacpp 'pascal' (== __stdcall, also the COM
 *  calling convention).
 * ========================================================================== */

#define WINAPI pascal
typedef long           HRESULT;
typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef void*          HMODULE;
typedef int (WINAPI *FARPROC)();
typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3; unsigned char Data4[8]; } GUID;

#define S_OK   0

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);

/* ---- C math ----------------------------------------------------------------
   The Clarion C runtime does NOT link libm (sin/cos/sqrt/atan2 come back as
   Unresolved Externals), and binding msvcrt's cdecl CRT math through function
   pointers crashes (Clacpp defaults calls to stdcall). So we implement the four
   functions we need in PURE C - no external calls, no linkage, no calling-
   convention risk. Accuracy is ~1e-10 (sin/cos/sqrt) / ~1e-5 (atan2), far more
   than enough to place particles. The engine below just calls sin()/cos()/... */
#define YU_PI      3.14159265358979323846
#define YU_TWO_PI  6.28318530717958647692
#define YU_HALF_PI 1.57079632679489661923
static double ad(double a) { return a < 0 ? -a : a; }

double sqrt(double x) {                          /* range-reduced Newton-Raphson */
    double r, m; int e, i;
    if (x <= 0) return 0;
    m = x; e = 0;                                /* reduce to m in [1,4): x = m * 4^e */
    while (m >= 4) { m *= 0.25; e++; }
    while (m <  1) { m *= 4;    e--; }
    r = (m + 1) * 0.5;                           /* good seed on [1,4) => 6 iters = full precision */
    for (i = 0; i < 6; i++) r = 0.5 * (r + m / r);
    while (e > 0) { r *= 2;   e--; }             /* scale back by 2^e (cheap mults, no divides) */
    while (e < 0) { r *= 0.5; e++; }
    return r;
}
double sin(double x) {                           /* range-reduce to [-pi/2,pi/2] + Taylor */
    double r, x2; long n;
    n = (long)(x / YU_TWO_PI + (x >= 0 ? 0.5 : -0.5));
    r = x - (double)n * YU_TWO_PI;               /* [-pi,pi] */
    if      (r >  YU_HALF_PI) r =  YU_PI - r;    /* fold into [-pi/2,pi/2] */
    else if (r < -YU_HALF_PI) r = -YU_PI - r;
    x2 = r * r;
    return r*(1 + x2*(-1.0/6 + x2*(1.0/120 + x2*(-1.0/5040 + x2*(1.0/362880 + x2*(-1.0/39916800))))));
}
double cos(double x) { return sin(x + YU_HALF_PI); }
static double atan_unit(double z) {              /* minimax atan on |z|<=1, err ~1e-5 */
    double z2 = z * z;
    return z*(0.99997726 + z2*(-0.33262347 + z2*(0.19354346 + z2*(-0.11643287 + z2*(0.05265332 + z2*(-0.01172120))))));
}
double atan2(double y, double x) {
    if (x == 0) { if (y > 0) return YU_HALF_PI; if (y < 0) return -YU_HALF_PI; return 0; }
    if (ad(x) >= ad(y)) {                        /* |y/x| <= 1 */
        double a = atan_unit(y / x);
        if (x < 0) { if (y >= 0) a += YU_PI; else a -= YU_PI; }
        return a;
    }
    if (y > 0) return  YU_HALF_PI - atan_unit(x / y);
    return             -YU_HALF_PI - atan_unit(x / y);
}

/* ---- opaque COM interface pointers ---- */
typedef struct ID2D1Factory      ID2D1Factory;
typedef struct ID2D1RenderTarget ID2D1RenderTarget;

/* ---- D2D value structs (must match the SDK layout exactly) ---- */
typedef struct { float r, g, b, a; }              D2D1_COLOR_F;
typedef struct { float left, top, right, bottom; } D2D1_RECT_F;
typedef struct { int format; int alphaMode; }     D2D1_PIXEL_FORMAT;
typedef struct { int type; D2D1_PIXEL_FORMAT pixelFormat;
                 float dpiX, dpiY; int usage; int minLevel; } D2D1_RENDER_TARGET_PROPERTIES;
typedef struct { unsigned int w, h; }             D2D1_SIZE_U;
typedef struct { void* hwnd; D2D1_SIZE_U pixelSize; int presentOptions; } D2D1_HWND_RT_PROPS;
typedef struct { D2D1_PIXEL_FORMAT pixelFormat; float dpiX, dpiY; } D2D1_BITMAP_PROPERTIES;

/* ---- IUnknown (generic Release for any COM object) ---- */
typedef struct { void* QueryInterface; void* AddRef; unsigned long (WINAPI* Release)(void*); } IUnknownVtbl;
typedef struct { IUnknownVtbl* v; } IUnknownObj;
static void rel(void* p) { if (p) ((IUnknownObj*)p)->v->Release(p); }

/* ---- ID2D1Factory: CreateHwndRenderTarget(14) ---- */
typedef struct {
    void* QueryInterface; void* AddRef; void* Release;                 /* 0..2 */
    void* ReloadSystemMetrics; void* GetDesktopDpi;                    /* 3,4  */
    void* CreateRectangleGeometry; void* CreateRoundedRectangleGeometry;
    void* CreateEllipseGeometry; void* CreateGeometryGroup;
    void* CreateTransformedGeometry;                                  /* 5..9 */
    void* CreatePathGeometry; void* CreateStrokeStyle;                /* 10,11 */
    void* CreateDrawingStateBlock;                                    /* 12   */
    void* CreateWicBitmapRenderTarget;                                /* 13   */
    HRESULT (WINAPI* CreateHwndRenderTarget)(ID2D1Factory*, const D2D1_RENDER_TARGET_PROPERTIES*,
             const D2D1_HWND_RT_PROPS*, ID2D1RenderTarget**);         /* 14 (HwndRT derives from RenderTarget) */
} ID2D1FactoryVtbl;
struct ID2D1Factory { ID2D1FactoryVtbl* v; };

/* ---- ID2D1RenderTarget: CreateBitmap(4), DrawBitmap(26), Clear(47),
        BeginDraw(48), EndDraw(49) ---- */
typedef struct {
    void* QueryInterface; void* AddRef; void* Release; void* GetFactory; /* 0..3 */
    HRESULT (WINAPI* CreateBitmap)(ID2D1RenderTarget*, D2D1_SIZE_U, const void*, UINT,
             const D2D1_BITMAP_PROPERTIES*, void**);                     /* 4 -> ID2D1Bitmap** */
    void* CreateBitmapFromWicBitmap; void* CreateSharedBitmap; void* CreateBitmapBrush; /* 5..7 */
    void* CreateSolidColorBrush; void* CreateGradientStopCollection;    /* 8,9   */
    void* CreateLinearGradientBrush; void* CreateRadialGradientBrush;   /* 10,11 */
    void* CreateCompatibleRenderTarget; void* CreateLayer; void* CreateMesh; /* 12..14 */
    void* DrawLine; void* DrawRectangle; void* FillRectangle;           /* 15..17 */
    void* DrawRoundedRectangle; void* FillRoundedRectangle;             /* 18,19 */
    void* DrawEllipse; void* FillEllipse;                              /* 20,21 */
    void* DrawGeometry; void* FillGeometry;                            /* 22,23 */
    void* FillMesh; void* FillOpacityMask;                            /* 24,25 */
    void (WINAPI* DrawBitmap)(ID2D1RenderTarget*, void*, const D2D1_RECT_F*, float, int, const D2D1_RECT_F*); /* 26 */
    void* DrawText; void* DrawTextLayout; void* DrawGlyphRun;          /* 27..29 */
    void* SetTransform; void* GetTransform;                           /* 30,31 */
    void* SetAntialiasMode; void* GetAntialiasMode;                   /* 32,33 */
    void* SetTextAntialiasMode; void* GetTextAntialiasMode;           /* 34,35 */
    void* SetTextRenderingParams; void* GetTextRenderingParams;       /* 36,37 */
    void* SetTags; void* GetTags; void* PushLayer; void* PopLayer;    /* 38..41 */
    void* Flush; void* SaveDrawingState; void* RestoreDrawingState;   /* 42..44 */
    void* PushAxisAlignedClip; void* PopAxisAlignedClip;              /* 45,46 */
    void (WINAPI* Clear)(ID2D1RenderTarget*, const D2D1_COLOR_F*);     /* 47 */
    void (WINAPI* BeginDraw)(ID2D1RenderTarget*);                     /* 48 */
    HRESULT (WINAPI* EndDraw)(ID2D1RenderTarget*, void*, void*);      /* 49 */
    void* GetPixelFormat; void* SetDpi; void* GetDpi;                 /* 50..52 */
    void* GetSize; void* GetPixelSize; void* GetMaximumBitmapSize;    /* 53..55 */
    void* IsSupported;                                                /* 56 */
    void* CheckWindowState;                                           /* 57 (ID2D1HwndRenderTarget) */
    HRESULT (WINAPI* Resize)(ID2D1RenderTarget*, const D2D1_SIZE_U*); /* 58 (ID2D1HwndRenderTarget) */
} ID2D1RenderTargetVtbl;
struct ID2D1RenderTarget { ID2D1RenderTargetVtbl* v; };

/* ---- flat DLL entry points ---- */
typedef HRESULT (WINAPI *PFN_D2D1CreateFactory)(int, const GUID*, const void*, void**);
/* user32 - the child host window over the IMAGE control */
typedef void* (WINAPI *PFN_CreateWindowExA)(DWORD, const char*, const char*, DWORD,
              int, int, int, int, void*, void*, void*, void*);
typedef int   (WINAPI *PFN_DestroyWindow)(void*);
typedef int   (WINAPI *PFN_SetWindowPos)(void*, void*, int, int, int, int, unsigned int);

/* ---- GUIDs ---- */
static GUID IID_ID2D1Factory = {0x06152247,0x6f50,0x465a,{0x92,0x45,0x11,0x8b,0xfd,0x3b,0x60,0x07}};

/* ---- module state ---- */
static int                 g_inited = 0;
static ID2D1Factory*       g_d2d = 0;
static PFN_CreateWindowExA p_CreateWin = 0;
static PFN_DestroyWindow   p_DestroyWin = 0;
static PFN_SetWindowPos    p_SetWinPos = 0;
static int                 g_step = 0;
static HRESULT             g_hr = 0;

#define YU_MAX 16
static struct { ID2D1RenderTarget* rt; int w, h, drawing; } g_cv[YU_MAX+1];

/* staging buffer for the 24bpp->32bpp conversion (myYuru's canvas is 400x400) */
#define STAGE_MAX_PX (640*640)
static unsigned char g_stage[STAGE_MAX_PX*4];

/* ========================================================================== */
int yuru_d2d_init(void) {
    HMODULE hD2D, hU;
    PFN_D2D1CreateFactory pD2D;
    if (g_inited) return 0;
    hD2D = LoadLibraryA("d2d1.dll"); if (!hD2D) { g_step=-1; return -1; }
    hU   = LoadLibraryA("user32.dll");
    if (hU) {
        *(FARPROC*)&p_CreateWin  = GetProcAddress(hU, "CreateWindowExA");
        *(FARPROC*)&p_DestroyWin = GetProcAddress(hU, "DestroyWindow");
        *(FARPROC*)&p_SetWinPos  = GetProcAddress(hU, "SetWindowPos");
    }
    *(FARPROC*)&pD2D = GetProcAddress(hD2D, "D2D1CreateFactory");
    if (!pD2D) { g_step=-2; return -2; }
    g_hr = pD2D(0 /*SINGLE_THREADED*/, &IID_ID2D1Factory, 0, (void**)&g_d2d);
    if (g_hr != S_OK || !g_d2d) { g_step=-3; return -3; }
    g_inited = 1;
    return 0;
}
int  yuru_d2d_last_step(void) { return g_step; }
long yuru_d2d_last_hr(void)   { return g_hr;   }

/* ---- child HOST window: a bare WS_CHILD over the IMAGE control's rectangle, so
   the animation owns a real HWND for the Direct2D target. x,y,w,h are pixels in
   the PARENT window's client coords. Returns the child HWND (0 = failed). ---- */
int yuru_d2d_make_child(int parent, int x, int y, int w, int h) {
    void* hwnd;
    if (!g_inited && yuru_d2d_init() != 0) return 0;
    if (!p_CreateWin) return 0;
    hwnd = p_CreateWin(0, "STATIC", "",
                       0x50000000,              /* WS_CHILD | WS_VISIBLE */
                       x, y, w, h, (void*)(unsigned long)parent, 0, 0, 0);
    return (int)(unsigned long)hwnd;
}
void yuru_d2d_move_child(int hwnd, int x, int y, int w, int h) {
    if (p_SetWinPos && hwnd)
        p_SetWinPos((void*)(unsigned long)hwnd, 0, x, y, w, h, 0x14); /* SWP_NOZORDER|SWP_NOACTIVATE */
}
void yuru_d2d_destroy_child(int hwnd) {
    if (p_DestroyWin && hwnd) p_DestroyWin((void*)(unsigned long)hwnd);
}

/* ---- create a GPU-composited Direct2D render target ON a window HWND. It
   derives from ID2D1RenderTarget so the blit below works on it unchanged.
   presentOptions=3 == RETAIN_CONTENTS|IMMEDIATELY: keep the last frame on expose,
   no vsync wait. Returns a canvas handle (0 = failed). ---- */
int yuru_d2d_begin_hwnd(int hwnd, int w, int h) {
    int i; ID2D1RenderTarget* rt = 0;
    D2D1_RENDER_TARGET_PROPERTIES p; D2D1_HWND_RT_PROPS hp;
    if (!g_inited && yuru_d2d_init() != 0) return 0;
    if (w < 1) w = 1;  if (h < 1) h = 1;
    for (i = 1; i <= YU_MAX; i++) if (!g_cv[i].rt) break;
    if (i > YU_MAX) { g_step = -10; return 0; }
    p.type = 0;                         /* DEFAULT: hardware if available, else WARP */
    p.pixelFormat.format = 0; p.pixelFormat.alphaMode = 1; /* UNKNOWN + PREMULTIPLIED */
    p.dpiX = 0; p.dpiY = 0; p.usage = 0; p.minLevel = 0;
    hp.hwnd = (void*)(unsigned long)hwnd;
    hp.pixelSize.w = (unsigned int)w; hp.pixelSize.h = (unsigned int)h;
    hp.presentOptions = 3;
    g_hr = g_d2d->v->CreateHwndRenderTarget(g_d2d, &p, &hp, &rt);
    if (g_hr != S_OK || !rt) { g_step = -11; return 0; }
    rt->v->BeginDraw(rt);
    g_cv[i].rt = rt; g_cv[i].w = w; g_cv[i].h = h; g_cv[i].drawing = 1;
    return i;
}

static ID2D1RenderTarget* RT(int h) {
    if (h < 1 || h > YU_MAX) return 0;
    return g_cv[h].rt;
}

/* ==========================================================================
 *  NATIVE PARTICLE ENGINE - the six "yuruyurau" sketches ported to C.
 *
 *  This is the real GPU-path win: the per-frame cost of myYuru was NEVER the
 *  file write - it was computing 10-30k particles (trig) and plotting them
 *  additively through Clarion string indexing (VAL(Pixels[ofs])/CHR()), which
 *  is slow. Here the whole frame is built in native C directly into a 32-bit
 *  PBGRA buffer, then handed to the GPU as one bitmap. The Clarion particle
 *  loop is skipped entirely on the Direct2D backend. Formulas mirror the
 *  Clarion YuruClass.<Preset> methods exactly (single-letter locals kept).
 * ========================================================================== */
static int g_frame_w = 0;   /* width of the last native frame in g_stage (square) */

static unsigned char sat8(int v) { return v > 255 ? 255 : (unsigned char)v; }

/* additive plot of one point into the 32-bit PBGRA buffer (top-down; off-canvas
   ignored). Clarion assigns REAL->LONG by ROUNDING, so round here too. */
static void plot_n(unsigned char* b, int w, double x, double y, int iR, int iG, int iB) {
    int ix = (int)(x < 0 ? x - 0.5 : x + 0.5);
    int iy = (int)(y < 0 ? y - 0.5 : y + 0.5);
    int o;
    if (ix < 0 || ix > w-1 || iy < 0 || iy > w-1) return;
    o = (iy * w + ix) * 4;
    b[o]   = sat8(b[o]   + iB);
    b[o+1] = sat8(b[o+1] + iG);
    b[o+2] = sat8(b[o+2] + iR);   /* alpha left at 255 (set on clear) */
}

static void np_ribbon(unsigned char* b, int w, double t, int iR, int iG, int iB) {
    int i; double yY, kK, eE, dD, qQ, cC;
    for (i = 9999; i >= 0; i--) {
        yY = i / 235.0;
        kK = (4 + sin(yY*2 - t)*3) * cos(i/29.0);
        if (kK < 0.0001 && kK > -0.0001) kK = 0.0001;
        eE = yY/8.0 - 13;
        dD = sqrt(kK*kK + eE*eE);
        qQ = 3*sin(kK*2) + 0.3/kK + sin(yY/25.0)*kK*(9 + 4*sin(eE*9 - dD*3 + t*2));
        cC = dD - t;
        plot_n(b, w, qQ + 30*cos(cC) + 200, qQ*sin(cC) + dD*39 - 220, iR, iG, iB);
    }
}
static void np_seashell(unsigned char* b, int w, double t, int iR, int iG, int iB) {
    int i; double xX, yY, kK, eE, dD, qQ, cC;
    for (i = 9999; i >= 0; i--) {
        xX = i % 200; yY = i / 55.0;
        kK = 9*cos(xX/8.0);
        eE = yY/8.0 - 12.5;
        dD = (kK*kK + eE*eE)/99.0 + sin(t)/6.0 + 0.5;
        qQ = 99 - eE*sin(atan2(kK,eE)*7)/dD + kK*(3 + cos(dD*dD - t)*2);
        cC = dD/2.0 + eE/69.0 - t/16.0;
        plot_n(b, w, qQ*sin(cC) + 200, (qQ + 19*dD)*cos(cC) + 200, iR, iG, iB);
    }
}
static void np_nebula(unsigned char* b, int w, double t, int iR, int iG, int iB) {
    int i; double xX, yY, kK, eE, dD, qQ, cC;
    for (i = 9999; i >= 0; i--) {
        xX = i; yY = i / 41.0;
        kK = 5*cos(xX/19.0)*cos(yY/30.0);
        eE = yY/8.0 - 12;
        dD = (kK*kK + eE*eE)/59.0 + 2;
        qQ = 4*sin(atan2(kK,eE)*9) + 9*sin(dD - t) - kK/dD*(9 + sin(dD*9 - t*16)*3);
        cC = dD*dD/7.0 - t;
        plot_n(b, w, qQ + 50*cos(cC) + 200, qQ*sin(cC) + dD*45 - 9, iR, iG, iB);
    }
}
static void np_lattice(unsigned char* b, int w, double t, int iR, int iG, int iB) {
    int i; double yY, kK, eE, dD, qQ, cC;
    for (i = 29999; i >= 0; i--) {
        yY = i / 799.0;
        kK = 5*cos(i/48.0);
        eE = 5*cos(yY/9.0);
        dD = sqrt(kK*kK + eE*eE) / (6 + (i%4));
        dD = dD*dD*dD*dD + 4;
        qQ = kK*(3 + eE/2.0*sin(dD*8 + kK/9.0 - t)) - 3*sin(kK*dD/3.0) + ((i&1)+1)*80;
        cC = dD - t/9.0 + (i%5);
        plot_n(b, w, qQ*sin(cC) + 200, qQ*cos(cC - (i%2) + (i%5)*3 + 7) + 200, iR, iG, iB);
    }
}
static void np_reeds(unsigned char* b, int w, double t, int iR, int iG, int iB) {
    int i; double yY, kK, eE, dD, qQ, cC;
    for (i = 9999; i >= 0; i--) {
        yY = i / 790.0;
        if (yY < 5) kK = (6 + sin((double)(((int)yY)^1))*6) * cos(i + t/4.0);
        else        kK = (4 + cos(yY)) * cos(i + t/4.0);
        eE = yY/3.0 - 13;
        dD = sqrt(kK*kK + eE*eE) + sin(eE/4.0 - t)/3.0;
        qQ = yY*kK/5.0 * (2 + sin(dD*2 + yY - t*4));
        cC = dD/3.0 - t/2.0 + (i%2);
        plot_n(b, w, qQ + 90*cos(cC) + 200, qQ*sin(cC) + dD*29 - 170, iR, iG, iB);
    }
}
static void np_plume(unsigned char* b, int w, double t, int iR, int iG, int iB) {
    int i; double xX, yY, kK, eE, dD, qQ, cC;
    for (i = 9999; i >= 0; i--) {
        xX = i; yY = i / 235.0;
        kK = 4*cos(xX/29.0);
        eE = yY/7.0 - 13;
        dD = sqrt(kK*kK + eE*eE);
        qQ = 3*sin(atan2(kK,eE)*19) + sin(yY/19.0)*kK*(9 + 2*sin(eE*9 - dD*3 + t/4.0));
        cC = dD - t/8.0;
        plot_n(b, w, qQ + 60*cos(cC) + 200, qQ*sin(cC) + dD*39 - 195, iR, iG, iB);
    }
}

/* build one frame natively into g_stage (32-bit PBGRA, w x w, top-down). */
void yuru_native_frame(int preset, double t, int iR, int iG, int iB, int backGray, int w) {
    unsigned char* b = g_stage; int n, k;
    if (w < 1 || w*w > STAGE_MAX_PX) return;
    n = w * w;
    for (k = 0; k < n; k++) {                      /* clear to the flat background, opaque */
        b[k*4] = (unsigned char)backGray; b[k*4+1] = (unsigned char)backGray;
        b[k*4+2] = (unsigned char)backGray; b[k*4+3] = 255;
    }
    switch (preset) {
        case 2:  np_seashell(b, w, t, iR, iG, iB); break;
        case 3:  np_nebula  (b, w, t, iR, iG, iB); break;
        case 4:  np_lattice (b, w, t, iR, iG, iB); break;
        case 5:  np_reeds   (b, w, t, iR, iG, iB); break;
        case 6:  np_plume   (b, w, t, iR, iG, iB); break;
        default: np_ribbon  (b, w, t, iR, iG, iB); break;
    }
    g_frame_w = w;
}

/* copy the last native frame out as 24-bit BOTTOM-UP BGR (the myYuru BMP layout),
   for headless verification against the Clarion-rendered golden shots. */
void yuru_native_copy24(unsigned char* dst, int w) {
    int x, y; unsigned char* s; unsigned char* d;
    if (!dst || w < 1 || w*w > STAGE_MAX_PX) return;
    for (y = 0; y < w; y++) {
        s = g_stage + y * w * 4;             /* g_stage is top-down   */
        d = dst + (w-1 - y) * w * 3;         /* BMP rows are bottom-up */
        for (x = 0; x < w; x++) { d[0]=s[0]; d[1]=s[1]; d[2]=s[2]; s+=4; d+=3; }
    }
}

/* ---- BLIT the native frame in g_stage straight to the GPU target, scaled into
   (dx,dy,dw,dh). No conversion, no file, no reload. ---- */
void yuru_d2d_blit_native(int h, double dx, double dy, double dw, double dh) {
    ID2D1RenderTarget* rt = RT(h); void* bmp = 0; int w = g_frame_w;
    D2D1_SIZE_U sz; D2D1_BITMAP_PROPERTIES bp; D2D1_RECT_F dst;
    if (!rt || w < 1) return;
    sz.w = (unsigned int)w; sz.h = (unsigned int)w;
    bp.pixelFormat.format = 87;    /* DXGI_FORMAT_B8G8R8A8_UNORM */
    bp.pixelFormat.alphaMode = 1;  /* PREMULTIPLIED (a=255 => same as straight) */
    bp.dpiX = 0; bp.dpiY = 0;
    if (rt->v->CreateBitmap(rt, sz, g_stage, (UINT)(w*4), &bp, &bmp) != S_OK || !bmp) return;
    dst.left=(float)dx; dst.top=(float)dy; dst.right=(float)(dx+dw); dst.bottom=(float)(dy+dh);
    rt->v->DrawBitmap(rt, bmp, &dst, 1.0f, 1 /*LINEAR*/, 0);
    rel(bmp);
}

/* ---- resize the HWND render target's back buffer when the host window changes
   size. Direct2D forbids Resize() inside a BeginDraw/EndDraw pair, so close the
   current draw first, resize, then re-open (keeping the same "always drawing"
   invariant that begin_hwnd/present maintain). Without this the target keeps its
   original pixel size and the frame stays boxed into it when the control grows. */
void yuru_d2d_resize(int h, int w, int hgt) {
    ID2D1RenderTarget* rt = RT(h);
    D2D1_SIZE_U sz;
    if (!rt) return;
    if (w < 1) w = 1;  if (hgt < 1) hgt = 1;
    if (g_cv[h].drawing) { rt->v->EndDraw(rt, 0, 0); g_cv[h].drawing = 0; }
    sz.w = (unsigned int)w; sz.h = (unsigned int)hgt;
    rt->v->Resize(rt, &sz);
    g_cv[h].w = w; g_cv[h].h = hgt;
    rt->v->BeginDraw(rt); g_cv[h].drawing = 1;
}

/* present the window canvas: EndDraw flips it to the screen, then re-open for next frame */
void yuru_d2d_present(int h) {
    ID2D1RenderTarget* rt = RT(h);
    if (!rt) return;
    if (g_cv[h].drawing) { rt->v->EndDraw(rt, 0, 0); g_cv[h].drawing = 0; }
    rt->v->BeginDraw(rt); g_cv[h].drawing = 1;
}

void yuru_d2d_end(int h) {
    if (h < 1 || h > YU_MAX) return;
    if (g_cv[h].rt && g_cv[h].drawing) { g_cv[h].rt->v->EndDraw(g_cv[h].rt, 0, 0); g_cv[h].drawing = 0; }
    if (g_cv[h].rt) { rel(g_cv[h].rt); g_cv[h].rt = 0; }
}

}  /* extern "C" */
