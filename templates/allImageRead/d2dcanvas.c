/* ============================================================================
 *  d2dcanvas.c - a GPU picture canvas for Clarion, backed by Direct2D.
 *
 *  WHY. Zooming a picture on the CPU means resampling it again for every wheel
 *  notch, then handing the result to an IMAGE control through a file. On a
 *  12-megapixel photo at 400% that is 192 million pixels of work and a PNG
 *  round trip per notch. Direct2D uploads the picture to the GPU ONCE; after
 *  that a zoom or a pan is a 3x2 matrix and a redraw, which costs the same
 *  whether the picture is 300 pixels wide or 30,000.
 *
 *  HOW IT SITS IN A CLARION WINDOW. Every Clarion control owns a real HWND -
 *  including a REGION created at run time with CREATE(0,CREATE:Region,...) -
 *  so the canvas gets its own window to render into. That is what makes this
 *  clean: Direct2D renders to the REGION's HWND, clipping is Windows' problem,
 *  and Clarion keeps painting the rest of the window exactly as it always did.
 *  This file subclasses that one control and answers WM_PAINT itself.
 *
 *  NO IMPORT LIBRARY, NO REDISTRIBUTABLE. Clarion cannot link MSVC COFF import
 *  libraries, so d2d1.dll is bound at run time with LoadLibrary/GetProcAddress
 *  - the same trampoline trick gpcanvas.c uses for GDI+. If Direct2D is not
 *  there (or a factory cannot be made) every entry point returns 0 and the
 *  template quietly falls back to its CPU path. Direct2D ships with Windows 7
 *  and later, so in practice it is always there.
 *
 *  COM WITHOUT A HEADER. Clacpp has no Windows SDK, so the interfaces are
 *  hand-declared: a COM object is a pointer to a vtable, and a method call is
 *  an indexed jump through it. The indices below were read out of the SDK's
 *  own d2d1.h (10.0.22621.0) by walking each interface's declaration order,
 *  base class first - they are not guesses. Get one wrong and it crashes, so
 *  they are named in one place and used nowhere else:
 *
 *    ID2D1Factory           2 Release   14 CreateHwndRenderTarget
 *    ID2D1HwndRenderTarget  2 Release    4 CreateBitmap   26 DrawBitmap
 *                          30 SetTransform  47 Clear  48 BeginDraw
 *                          49 EndDraw   58 Resize
 *    ID2D1Bitmap            2 Release   10 CopyFromMemory
 *
 *  ABI notes, all deliberate:
 *    - 32-bit only, which is what Clarion builds. COM methods are stdcall,
 *      spelled `pascal` by Clacpp.
 *    - D2D1_SIZE_U is passed BY VALUE to CreateBitmap. Two UINT32s on the
 *      stack is byte-identical to the struct, so it is declared as two
 *      parameters rather than trusting the compiler's struct-by-value.
 *    - the render target and the bitmap are both created at 96 DPI, so one
 *      DIP is one device pixel and one image pixel is one screen pixel at
 *      zoom 100. Without that, everything is silently scaled by the user's
 *      display scaling.
 *    - the picture arrives as a 32-bit BMP written by ImageClass (once, when
 *      it is loaded), so all twelve of myImage's formats work and this file
 *      needs no decoders of its own.
 * ========================================================================== */

/* ---- the small Win32 surface we need, hand-declared ---------------------- */
#define WINAPI pascal
typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef int            BOOL;
typedef unsigned char  BYTE;
typedef void*          HMODULE;
typedef void*          HWND;
typedef void*          HDC;
typedef long           LONG;
typedef long           HRESULT;
typedef int (WINAPI *FARPROC)();
typedef long (WINAPI *WNDPROC)(HWND, UINT, UINT, long);

typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3;
                 unsigned char Data4[8]; } GUID;
typedef struct { long left, top, right, bottom; } RECT;

#define LPTR        0x0040
#define GWL_WNDPROC (-4)
#define WM_PAINT       0x000F
#define WM_ERASEBKGND  0x0014
#define WM_DESTROY     0x0002

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
HDC     WINAPI BeginPaint(HWND, void*);
BOOL    WINAPI EndPaint(HWND, const void*);
BOOL    WINAPI IsWindow(HWND);
void*   WINAPI CreateFileA(const char*, DWORD, DWORD, void*, DWORD, DWORD, void*);
BOOL    WINAPI ReadFile(void*, void*, DWORD, DWORD*, void*);
DWORD   WINAPI GetFileSize(void*, DWORD*);
BOOL    WINAPI CloseHandle(void*);

#define GENERIC_READ     0x80000000
#define FILE_SHARE_READ  0x00000001
#define OPEN_EXISTING    3
#define FILE_ATTR_NORMAL 0x00000080
#define INVALID_HANDLE   ((void*)-1)

/* ---- Direct2D types, laid out exactly as the SDK declares them ----------- */
typedef struct { unsigned int w, h; }                     SIZEU;   /* D2D1_SIZE_U   */
typedef struct { float l, t, r, b; }                      RECTF;   /* D2D1_RECT_F   */
typedef struct { float r, g, b, a; }                      COLORF;  /* D2D1_COLOR_F  */
typedef struct { float m11, m12, m21, m22, dx, dy; }      MAT32;   /* D2D1_MATRIX_3X2_F */
typedef struct { int format; int alphaMode; }             PIXFMT;  /* D2D1_PIXEL_FORMAT */
typedef struct { int type; PIXFMT pf; float dpiX, dpiY;
                 int usage; int minLevel; }               RTPROPS;
typedef struct { HWND hwnd; SIZEU size; int present; }    HRTPROPS;
typedef struct { PIXFMT pf; float dpiX, dpiY; }           BMPPROPS;

#define DXGI_B8G8R8A8_UNORM   87   /* dxgiformat.h                            */
#define ALPHA_IGNORE           3   /* D2D1_ALPHA_MODE_IGNORE - photos are opaque */
#define RT_TYPE_DEFAULT        0
#define RT_USAGE_NONE          0
#define FEATURE_LEVEL_DEFAULT  0
#define PRESENT_NONE           0
#define FACTORY_SINGLE         0   /* D2D1_FACTORY_TYPE_SINGLE_THREADED       */
#define INTERP_LINEAR          1   /* D2D1_BITMAP_INTERPOLATION_MODE_LINEAR   */
#define INTERP_NEAREST         0

/* a COM object is a pointer to its vtable; a call is an indexed jump */
#define VT(o) (*(void***)(o))

typedef HRESULT (WINAPI *PFN_D2D1CreateFactory)(int, const GUID*, const void*, void**);

/* ---- one canvas ---------------------------------------------------------- */
#define D2C_MAX 8

typedef struct {
    int   used;
    HWND  hwnd;
    void* rt;                    /* ID2D1HwndRenderTarget */
    void* bmp;                   /* ID2D1Bitmap           */
    WNDPROC oldProc;
    int   imgW, imgH;
    double zoom;                 /* 1.0 = one image pixel per screen pixel    */
    double panX, panY;           /* top-left of the view, in image pixels     */
    unsigned int bg;             /* 0x00RRGGBB                                */
    int   smooth;
} D2Canvas;

static D2Canvas g_c[D2C_MAX + 1];
static void*    g_factory = 0;
static int      g_tried   = 0;   /* we only try to load d2d1.dll once         */

static long WINAPI d2c_WndProc(HWND h, UINT msg, UINT wp, long lp);

/* ---- the factory --------------------------------------------------------- */
static void* d2c_Factory(void) {
    HMODULE dll;
    PFN_D2D1CreateFactory create;
    GUID iidFactory;
    void* f = 0;

    if (g_factory) return g_factory;
    if (g_tried)   return 0;
    g_tried = 1;

    dll = LoadLibraryA("d2d1.dll");
    if (!dll) return 0;
    create = (PFN_D2D1CreateFactory)GetProcAddress(dll, "D2D1CreateFactory");
    if (!create) return 0;

    /* IID_ID2D1Factory {06152247-6f50-465a-9245-118bfd3b6007} - d2d1.h:3341 */
    iidFactory.Data1 = 0x06152247;
    iidFactory.Data2 = 0x6f50;
    iidFactory.Data3 = 0x465a;
    iidFactory.Data4[0] = 0x92; iidFactory.Data4[1] = 0x45;
    iidFactory.Data4[2] = 0x11; iidFactory.Data4[3] = 0x8b;
    iidFactory.Data4[4] = 0xfd; iidFactory.Data4[5] = 0x3b;
    iidFactory.Data4[6] = 0x60; iidFactory.Data4[7] = 0x07;

    if (create(FACTORY_SINGLE, &iidFactory, 0, &f) < 0) return 0;
    g_factory = f;
    return f;
}

static D2Canvas* slot(int h) {
    if (h < 1 || h > D2C_MAX || !g_c[h].used) return 0;
    return &g_c[h];
}

/* ---- the render target, made to fit the control -------------------------- */
static int d2c_MakeTarget(D2Canvas* c) {
    void* fac = d2c_Factory();
    RTPROPS  rp;
    HRTPROPS hp;
    RECT     r;
    HRESULT  hr;

    if (!fac || !c->hwnd || !IsWindow(c->hwnd)) return 0;
    if (c->rt) return 1;

    GetClientRect(c->hwnd, &r);
    if (r.right - r.left < 1 || r.bottom - r.top < 1) return 0;

    rp.type          = RT_TYPE_DEFAULT;
    rp.pf.format     = DXGI_B8G8R8A8_UNORM;
    rp.pf.alphaMode  = ALPHA_IGNORE;
    rp.dpiX          = 96.0f;            /* 1 DIP == 1 pixel, whatever the    */
    rp.dpiY          = 96.0f;            /*   user's display scaling is       */
    rp.usage         = RT_USAGE_NONE;
    rp.minLevel      = FEATURE_LEVEL_DEFAULT;

    hp.hwnd          = c->hwnd;
    hp.size.w        = (unsigned)(r.right - r.left);
    hp.size.h        = (unsigned)(r.bottom - r.top);
    hp.present       = PRESENT_NONE;

    /* ID2D1Factory::CreateHwndRenderTarget - vtable slot 14 */
    hr = ((HRESULT (WINAPI*)(void*, const RTPROPS*, const HRTPROPS*, void**))
          VT(fac)[14])(fac, &rp, &hp, &c->rt);
    if (hr < 0) { c->rt = 0; return 0; }
    return 1;
}

static void d2c_DropBitmap(D2Canvas* c) {
    if (c->bmp) {
        ((unsigned long (WINAPI*)(void*))VT(c->bmp)[2])(c->bmp);   /* Release */
        c->bmp = 0;
    }
}

static void d2c_DropTarget(D2Canvas* c) {
    d2c_DropBitmap(c);
    if (c->rt) {
        ((unsigned long (WINAPI*)(void*))VT(c->rt)[2])(c->rt);     /* Release */
        c->rt = 0;
    }
}

/* ---- painting ------------------------------------------------------------ */
static void d2c_Draw(D2Canvas* c) {
    COLORF clear;
    MAT32  m;
    RECT   r;
    float  z;

    if (!c->rt && !d2c_MakeTarget(c)) return;

    ((void (WINAPI*)(void*))VT(c->rt)[48])(c->rt);                 /* BeginDraw */

    clear.r = (float)((c->bg >> 16) & 0xFF) / 255.0f;
    clear.g = (float)((c->bg >>  8) & 0xFF) / 255.0f;
    clear.b = (float)( c->bg        & 0xFF) / 255.0f;
    clear.a = 1.0f;
    ((void (WINAPI*)(void*, const COLORF*))VT(c->rt)[47])(c->rt, &clear);   /* Clear */

    if (c->bmp) {
        z = (float)c->zoom;
        m.m11 = z;   m.m12 = 0.0f;
        m.m21 = 0.0f; m.m22 = z;
        m.dx  = (float)(-c->panX * c->zoom);
        m.dy  = (float)(-c->panY * c->zoom);
        ((void (WINAPI*)(void*, const MAT32*))VT(c->rt)[30])(c->rt, &m);    /* SetTransform */

        /* DrawBitmap(bmp, destRect=NULL, opacity, interpolation, srcRect=NULL)
           destRect NULL means "at the bitmap's own size", which the transform
           above then scales and slides. */
        ((void (WINAPI*)(void*, void*, const RECTF*, float, int, const RECTF*))
         VT(c->rt)[26])(c->rt, c->bmp, 0, 1.0f, c->smooth ? INTERP_LINEAR : INTERP_NEAREST, 0);

        m.m11 = 1.0f; m.m12 = 0.0f; m.m21 = 0.0f; m.m22 = 1.0f; m.dx = 0.0f; m.dy = 0.0f;
        ((void (WINAPI*)(void*, const MAT32*))VT(c->rt)[30])(c->rt, &m);
    }

    /* EndDraw(tag1, tag2). A negative result means the device was lost - throw
       everything away and rebuild it on the next paint. */
    if (((HRESULT (WINAPI*)(void*, void*, void*))VT(c->rt)[49])(c->rt, 0, 0) < 0) {
        d2c_DropTarget(c);
        GetClientRect(c->hwnd, &r);
        InvalidateRect(c->hwnd, 0, 0);
    }
}

/* Draw right now, rather than waiting for the next WM_PAINT. Only used for
   measuring: it is the honest cost of one frame, Present included. */
int d2c_PaintNow(int h) {
    D2Canvas* c = slot(h);
    if (!c) return 0;
    d2c_Draw(c);
    return 1;
}

/* The canvas control's own window procedure. WM_PAINT is ours; the background
   is never erased (Direct2D covers every pixel, and erasing would flicker);
   everything else goes back to Clarion untouched. */
static long WINAPI d2c_WndProc(HWND h, UINT msg, UINT wp, long lp) {
    int i;
    D2Canvas* c = 0;
    char ps[128];                                   /* PAINTSTRUCT is 64 bytes */

    for (i = 1; i <= D2C_MAX; i++)
        if (g_c[i].used && g_c[i].hwnd == h) { c = &g_c[i]; break; }
    if (!c) return DefWindowProcA(h, msg, wp, lp);

    if (msg == WM_PAINT) {
        BeginPaint(h, ps);
        d2c_Draw(c);
        EndPaint(h, ps);
        return 0;
    }
    if (msg == WM_ERASEBKGND) return 1;

    return CallWindowProcA(c->oldProc, h, msg, wp, lp);
}

/* ========================================================================== */
/*  What Clarion calls                                                        */
/* ========================================================================== */

/* Is there a Direct2D to talk to at all? 0 => the caller uses its CPU path. */
int d2c_Available(void) { return d2c_Factory() ? 1 : 0; }

/* Take over a control's window. Returns a canvas handle, or 0. */
int d2c_Attach(void* hwnd) {
    int i;
    D2Canvas* c;

    if (!hwnd || !IsWindow((HWND)hwnd)) return 0;
    if (!d2c_Factory()) return 0;

    for (i = 1; i <= D2C_MAX; i++) if (!g_c[i].used) break;
    if (i > D2C_MAX) return 0;

    c = &g_c[i];
    c->used = 1;   c->hwnd = (HWND)hwnd;
    c->rt   = 0;   c->bmp  = 0;
    c->imgW = 0;   c->imgH = 0;
    c->zoom = 1.0; c->panX = 0.0; c->panY = 0.0;
    c->bg   = 0xFFFFFF; c->smooth = 1;

    if (!d2c_MakeTarget(c)) { c->used = 0; return 0; }

    c->oldProc = (WNDPROC)GetWindowLongA((HWND)hwnd, GWL_WNDPROC);
    SetWindowLongA((HWND)hwnd, GWL_WNDPROC, (long)d2c_WndProc);
    return i;
}

void d2c_Detach(int h) {
    D2Canvas* c = slot(h);
    if (!c) return;
    if (c->oldProc && IsWindow(c->hwnd))
        SetWindowLongA(c->hwnd, GWL_WNDPROC, (long)c->oldProc);
    d2c_DropTarget(c);
    c->used = 0;
    c->hwnd = 0;
}

/* Upload the picture. ImageClass has already decoded it - whatever the format
   was - and written it out as a 32-bit BMP, so all this has to understand is
   the simplest BMP there is. This happens ONCE per picture; zooming afterwards
   never touches it again. */
int d2c_LoadBmp(int h, const char* path) {
    D2Canvas* c = slot(h);
    void* fh;
    DWORD size, got = 0;
    BYTE* buf;
    BYTE* rows;
    int w, hh, bpp, off, y, stride, flip;
    BMPPROPS bp;
    HRESULT hr;

    if (!c) return 0;
    if (!c->rt && !d2c_MakeTarget(c)) return 0;

    fh = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTR_NORMAL, 0);
    if (fh == INVALID_HANDLE || !fh) return 0;
    size = GetFileSize(fh, 0);
    if (size < 54 || size > 0x7000000) { CloseHandle(fh); return 0; }
    buf = (BYTE*)LocalAlloc(LPTR, size);
    if (!buf) { CloseHandle(fh); return 0; }
    if (!ReadFile(fh, buf, size, &got, 0) || got != size) {
        CloseHandle(fh); LocalFree(buf); return 0;
    }
    CloseHandle(fh);

    if (buf[0] != 'B' || buf[1] != 'M') { LocalFree(buf); return 0; }
    off = (int)(buf[10] | (buf[11] << 8) | (buf[12] << 16) | (buf[13] << 24));
    w   = (int)(buf[18] | (buf[19] << 8) | (buf[20] << 16) | (buf[21] << 24));
    hh  = (int)(buf[22] | (buf[23] << 8) | (buf[24] << 16) | (buf[25] << 24));
    bpp = (int)(buf[28] | (buf[29] << 8));
    flip = 1;
    if (hh < 0) { hh = -hh; flip = 0; }                  /* top-down BMP       */
    if (bpp != 32 || w < 1 || hh < 1) { LocalFree(buf); return 0; }
    stride = w * 4;
    if (off + (long)stride * hh > (long)size) { LocalFree(buf); return 0; }

    /* BMP rows run bottom-up; Direct2D wants them top-down. */
    if (flip) {
        rows = (BYTE*)LocalAlloc(LPTR, (unsigned long)stride * hh);
        if (!rows) { LocalFree(buf); return 0; }
        for (y = 0; y < hh; y++) {
            BYTE* src = buf + off + (long)(hh - 1 - y) * stride;
            BYTE* dst = rows + (long)y * stride;
            int   i2;
            for (i2 = 0; i2 < stride; i2++) dst[i2] = src[i2];
        }
    } else {
        rows = buf + off;
    }

    d2c_DropBitmap(c);
    bp.pf.format    = DXGI_B8G8R8A8_UNORM;
    bp.pf.alphaMode = ALPHA_IGNORE;
    bp.dpiX = 96.0f;
    bp.dpiY = 96.0f;

    /* ID2D1RenderTarget::CreateBitmap - slot 4. D2D1_SIZE_U goes by value,
       which on 32-bit is exactly two dwords on the stack. */
    hr = ((HRESULT (WINAPI*)(void*, unsigned, unsigned, const void*, unsigned,
                             const BMPPROPS*, void**))VT(c->rt)[4])
         (c->rt, (unsigned)w, (unsigned)hh, rows, (unsigned)stride, &bp, &c->bmp);

    if (flip) LocalFree(rows);
    LocalFree(buf);

    if (hr < 0) { c->bmp = 0; return 0; }
    c->imgW = w;
    c->imgH = hh;
    return 1;
}

/* Zoom, pan, background, smoothing - then ask for a repaint. This is the whole
   cost of a wheel notch: six floats and an InvalidateRect. */
void d2c_SetView(int h, double zoom, double panX, double panY,
                 unsigned int bg, int smooth) {
    D2Canvas* c = slot(h);
    if (!c) return;
    if (zoom < 0.001) zoom = 0.001;
    c->zoom = zoom; c->panX = panX; c->panY = panY;
    c->bg = bg; c->smooth = smooth;
    InvalidateRect(c->hwnd, 0, 0);
}

/* The control moved or the window was resized. */
int d2c_Resize(int h) {
    D2Canvas* c = slot(h);
    RECT r;
    SIZEU s;
    if (!c) return 0;
    if (!c->rt && !d2c_MakeTarget(c)) return 0;
    GetClientRect(c->hwnd, &r);
    s.w = (unsigned)(r.right - r.left);
    s.h = (unsigned)(r.bottom - r.top);
    if (s.w < 1 || s.h < 1) return 0;
    ((HRESULT (WINAPI*)(void*, const SIZEU*))VT(c->rt)[58])(c->rt, &s);  /* Resize */
    InvalidateRect(c->hwnd, 0, 0);
    return 1;
}

int d2c_ImageW(int h)  { D2Canvas* c = slot(h); return c ? c->imgW : 0; }
int d2c_ImageH(int h)  { D2Canvas* c = slot(h); return c ? c->imgH : 0; }
int d2c_HasImage(int h){ D2Canvas* c = slot(h); return (c && c->bmp) ? 1 : 0; }

/* How wide and high the canvas is, in real pixels. */
int d2c_ViewW(int h) {
    D2Canvas* c = slot(h); RECT r;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r); return (int)(r.right - r.left);
}
int d2c_ViewH(int h) {
    D2Canvas* c = slot(h); RECT r;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r); return (int)(r.bottom - r.top);
}

/* Throw the picture away and leave an empty canvas. */
void d2c_Clear(int h) {
    D2Canvas* c = slot(h);
    if (!c) return;
    d2c_DropBitmap(c);
    c->imgW = 0; c->imgH = 0;
    InvalidateRect(c->hwnd, 0, 0);
}

}  /* extern "C" */
