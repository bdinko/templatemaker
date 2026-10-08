/* ============================================================================
 *  imgcore.c - the image engine behind the myImage template for Clarion.
 *
 *  WHAT IT DOES
 *    - reads 12 image formats and writes 9, including formats Clarion cannot
 *      touch on its own;
 *    - converts between colour formats: 32-bit ARGB, 24-bit RGB, 16-bit 565,
 *      15-bit 555, 256/16-colour palettes (median-cut quantised, optional
 *      Floyd-Steinberg dither), 8/4/2-bit greyscale, 1-bit black & white,
 *      web-safe 216;
 *    - transforms: rotate 90/180/270, free rotation at any angle, mirror,
 *      flip, crop, extend canvas, resize (nearest / bilinear / box-average)
 *      and the fit modes - stretch, proportional, cover, centred;
 *    - adjusts: brightness, contrast, 256-entry LUT (gamma, levels, curves),
 *      saturation, greyscale, sepia, invert, posterise, blur, sharpen,
 *      alpha flatten, opacity; plus a luma histogram and a test card.
 *
 *  WHO DOES WHAT
 *    GDI+ (gdiplus.dll, bound at run time - ships with every Windows, so no
 *    import library and nothing to redistribute) does only what it is good at:
 *    DECODING bmp/gif/jpeg/png/tiff/ico/wmf/emf and ENCODING png/jpeg/gif/tiff.
 *    Everything else - all the pixel work, and the tga/pcx/pnm/qoi/bmp codecs -
 *    is plain C in this file, which is why it is quick and why it behaves
 *    identically on every machine.
 *
 *  HOW IT PLUGS INTO CLARION
 *    Compiled by Clarion's own C++ compiler (Clacpp) through
 *    PRAGMA('compile(imgcore.c)') in ImageClass.clw. Exports are extern "C"
 *    and prototyped in a MODULE('imgcore.c') block with NAME('_img_xxx')
 *    (cdecl => leading underscore). An image is a small int handle (1..32).
 *
 *  DELIBERATE CONSTRAINTS (they are what make it compile everywhere)
 *    - Clacpp has NO Windows SDK headers: the handful of kernel32 calls are
 *      hand-declared. The Clarion linker resolves them natively.
 *    - Clacpp spells __stdcall as `pascal`.
 *    - NO C runtime is assumed: no malloc, no memcpy, no strlen, no math.
 *      Memory comes from LocalAlloc, files from CreateFileA/ReadFile/WriteFile,
 *      and the few helpers we need are written out below.
 *    - NO libm: anything needing sin/cos/pow is handed the numbers by Clarion
 *      (free rotation takes cos+sin; gamma and curves arrive as a 256-byte LUT).
 *    - pixels are stored B,G,R,A - the byte order of GDI+ 32bppARGB - so a
 *      GDI+ bitmap can be wrapped straight over our buffer with no copy.
 * ========================================================================== */

#define WINAPI pascal

typedef unsigned long  DWORD;
typedef int            BOOL;
typedef unsigned int   UINT;
typedef unsigned short WCHAR;
typedef unsigned char  BYTE;
typedef void*          HMODULE;
typedef void*           HANDLE;
typedef unsigned long  ULONG_PTR;
typedef int (WINAPI *FARPROC)();
typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3; unsigned char Data4[8]; } GUID;

#define CP_ACP 0
#define LPTR   0x0040

#define GENERIC_READ    0x80000000
#define GENERIC_WRITE   0x40000000
#define FILE_SHARE_READ 0x00000001
#define OPEN_EXISTING   3
#define CREATE_ALWAYS   2
#define FILE_ATTRIBUTE_NORMAL 0x00000080
#define INVALID_HANDLE_VALUE ((HANDLE)(-1))

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);
int     WINAPI MultiByteToWideChar(UINT, DWORD, const char*, int, WCHAR*, int);
void*   WINAPI LocalAlloc(UINT, unsigned long);
void*   WINAPI LocalFree(void*);
DWORD   WINAPI GetTempPathA(DWORD, char*);
HANDLE  WINAPI CreateFileA(const char*, DWORD, DWORD, void*, DWORD, DWORD, HANDLE);
BOOL    WINAPI ReadFile(HANDLE, void*, DWORD, DWORD*, void*);
BOOL    WINAPI WriteFile(HANDLE, const void*, DWORD, DWORD*, void*);
BOOL    WINAPI CloseHandle(HANDLE);
DWORD   WINAPI GetFileSize(HANDLE, DWORD*);

/* ------------------------------------------------------------------ GDI+ -- */
typedef void* GpImage;
typedef void* GpBitmap;
typedef void* GpGraphics;
typedef unsigned int ARGB;

typedef struct {
    unsigned int GdiplusVersion;
    void* DebugEventCallback;
    int   SuppressBackgroundThread;
    int   SuppressExternalCodecs;
} GdiplusStartupInput;

typedef struct { GUID Guid; unsigned long NumberOfValues; unsigned long Type; void* Value; } EncoderParameter;
typedef struct { unsigned long Count; EncoderParameter Parameter[1]; } EncoderParameters;

#define PF_32ARGB     0x0026200A
#define INTERP_HQBIC  7      /* InterpolationModeHighQualityBicubic */
#define INTERP_NN     5      /* InterpolationModeNearestNeighbor    */
#define PIXOFF_HALF   4      /* PixelOffsetModeHighQuality          */

typedef int (WINAPI *PFN_Startup)(ULONG_PTR*, const GdiplusStartupInput*, void*);
typedef int (WINAPI *PFN_LoadFile)(const WCHAR*, GpImage*);
typedef int (WINAPI *PFN_Dispose)(GpImage);
typedef int (WINAPI *PFN_GetW)(GpImage, UINT*);
typedef int (WINAPI *PFN_GetH)(GpImage, UINT*);
typedef int (WINAPI *PFN_GetPF)(GpImage, int*);
typedef int (WINAPI *PFN_GetRaw)(GpImage, GUID*);
typedef int (WINAPI *PFN_Scan0)(int, int, int, int, BYTE*, GpBitmap*);
typedef int (WINAPI *PFN_GetCtx)(GpImage, GpGraphics*);
typedef int (WINAPI *PFN_DelGfx)(GpGraphics);
typedef int (WINAPI *PFN_ClearG)(GpGraphics, ARGB);
typedef int (WINAPI *PFN_DrawRectI)(GpGraphics, GpImage, int, int, int, int);
typedef int (WINAPI *PFN_SetI)(GpGraphics, int);
typedef int (WINAPI *PFN_SaveFile)(GpImage, const WCHAR*, const GUID*, const EncoderParameters*);
typedef int (WINAPI *PFN_FrameCount)(GpImage, const GUID*, UINT*);
typedef int (WINAPI *PFN_SelFrame)(GpImage, const GUID*, UINT);

static PFN_Startup    p_Startup    = 0;
static PFN_LoadFile   p_LoadFile   = 0;
static PFN_Dispose    p_Dispose    = 0;
static PFN_GetW       p_GetW       = 0;
static PFN_GetH       p_GetH       = 0;
static PFN_GetPF      p_GetPF      = 0;
static PFN_GetRaw     p_GetRaw     = 0;
static PFN_Scan0      p_Scan0      = 0;
static PFN_GetCtx     p_GetCtx     = 0;
static PFN_DelGfx     p_DelGfx     = 0;
static PFN_ClearG     p_ClearG     = 0;
static PFN_DrawRectI  p_DrawRectI  = 0;
static PFN_SetI       p_SetInterp  = 0;
static PFN_SetI       p_SetPixOff  = 0;
static PFN_SaveFile   p_SaveFile   = 0;
static PFN_FrameCount p_FrameCount = 0;
static PFN_SelFrame   p_SelFrame   = 0;

static int       g_inited = 0;
static ULONG_PTR g_token  = 0;
static int       g_err    = 0;

/* encoder CLSIDs */
static const GUID CLSID_BMP  = {0x557cf400,0x1a04,0x11d3,{0x9a,0x73,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID CLSID_JPEG = {0x557cf401,0x1a04,0x11d3,{0x9a,0x73,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID CLSID_GIF  = {0x557cf402,0x1a04,0x11d3,{0x9a,0x73,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID CLSID_TIFF = {0x557cf405,0x1a04,0x11d3,{0x9a,0x73,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID CLSID_PNG  = {0x557cf406,0x1a04,0x11d3,{0x9a,0x73,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
/* EncoderQuality {1D5BE4B5-FA4A-452D-9CDD-5DB35105E7EB} */
static const GUID GUID_Quality = {0x1d5be4b5,0xfa4a,0x452d,{0x9c,0xdd,0x5d,0xb3,0x51,0x05,0xe7,0xeb}};
/* FrameDimensionTime {6AEDBD6D-3FB5-418A-83A6-7F45229DC872} */
static const GUID DIM_TIME = {0x6aedbd6d,0x3fb5,0x418a,{0x83,0xa6,0x7f,0x45,0x22,0x9d,0xc8,0x72}};
/* FrameDimensionPage {7462DC86-6180-4C7E-8E3F-EE7333A7A483} */
static const GUID DIM_PAGE = {0x7462dc86,0x6180,0x4c7e,{0x8e,0x3f,0xee,0x73,0x33,0xa7,0xa4,0x83}};
/* raw-format GUIDs, to report what the file actually was */
static const GUID FMT_BMP  = {0xb96b3cab,0x0728,0x11d3,{0x9d,0x7b,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID FMT_GIF  = {0xb96b3cb0,0x0728,0x11d3,{0x9d,0x7b,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID FMT_JPEG = {0xb96b3cae,0x0728,0x11d3,{0x9d,0x7b,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID FMT_PNG  = {0xb96b3caf,0x0728,0x11d3,{0x9d,0x7b,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID FMT_TIFF = {0xb96b3cb1,0x0728,0x11d3,{0x9d,0x7b,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID FMT_ICO  = {0xb96b3cb5,0x0728,0x11d3,{0x9d,0x7b,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID FMT_EMF  = {0xb96b3cac,0x0728,0x11d3,{0x9d,0x7b,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};
static const GUID FMT_WMF  = {0xb96b3cad,0x0728,0x11d3,{0x9d,0x7b,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};

/* ---- format ids shared with the Clarion side (Img:Fmt equates) ---- */
#define F_UNKNOWN 0
#define F_BMP     1
#define F_GIF     2
#define F_JPEG    3
#define F_PNG     4
#define F_TIFF    5
#define F_ICO     6
#define F_EMF     7
#define F_WMF     8
#define F_TGA     9
#define F_PCX     10
#define F_PNM     11
#define F_QOI     12

/* ---- colour modes shared with the Clarion side (Img:Mode equates) ---- */
#define M_32ARGB   1
#define M_24RGB    2
#define M_16_565   3
#define M_15_555   4
#define M_PAL256   5
#define M_PAL16    6
#define M_GREY8    7
#define M_GREY4    8
#define M_GREY2    9
#define M_BW1      10
#define M_WEB216   11

#define IMG_MAX 32

typedef struct {
    BYTE* px;              /* w*h*4, B,G,R,A                                  */
    int   w, h;
    int   used;
    int   srcfmt;          /* F_*  - what the file was                        */
    int   srcdepth;        /* bits per pixel in the file                      */
    int   mode;            /* M_*  - current logical colour mode              */
    int   palcount;        /* palette entries in use (indexed modes)          */
    unsigned int pal[256]; /* 0x00RRGGBB                                      */
    int   frames;
    GpImage gp;            /* kept only while a multi-frame file is open      */
    int   gppage;          /* 1 = frames are pages (tiff), 0 = time (gif)     */
} Img;

static Img g_img[IMG_MAX + 1];

/* ===================================================== tiny C helpers ==== */
static void mzero(void* d, int n) { BYTE* p = (BYTE*)d; while (n-- > 0) *p++ = 0; }
static void mcopy(void* d, const void* s, int n) {
    BYTE* a = (BYTE*)d; const BYTE* b = (const BYTE*)s;
    while (n-- > 0) *a++ = *b++;
}
static int slen(const char* s) { int n = 0; if (!s) return 0; while (s[n]) n++; return n; }
static int ieq(int a, int b) { return a == b; }
static int guid_eq(const GUID* a, const GUID* b) {
    int i;
    if (a->Data1 != b->Data1 || a->Data2 != b->Data2 || a->Data3 != b->Data3) return 0;
    for (i = 0; i < 8; i++) if (a->Data4[i] != b->Data4[i]) return 0;
    return 1;
}
static int iclamp(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }
static int iabs(int v) { return v < 0 ? -v : v; }

/* luma, 0..255 (BT.601 - the one that matches how eyes weight the channels) */
static int luma(int r, int g, int b) { return (r * 77 + g * 151 + b * 28) >> 8; }

/* ---- whole-file read into a LocalAlloc'd buffer (caller frees) ---- */
static BYTE* file_slurp(const char* path, int* outlen) {
    HANDLE fh;
    DWORD  sz, got = 0;
    BYTE*  buf;
    *outlen = 0;
    fh = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if (fh == INVALID_HANDLE_VALUE) return 0;
    sz = GetFileSize(fh, 0);
    if (sz == 0 || sz > 268435456UL) { CloseHandle(fh); return 0; }   /* 256MB sanity cap */
    buf = (BYTE*)LocalAlloc(LPTR, sz);
    if (!buf) { CloseHandle(fh); return 0; }
    if (!ReadFile(fh, buf, sz, &got, 0) || got != sz) { LocalFree(buf); CloseHandle(fh); return 0; }
    CloseHandle(fh);
    *outlen = (int)sz;
    return buf;
}

static int file_dump(const char* path, const BYTE* buf, int len) {
    HANDLE fh;
    DWORD  put = 0;
    fh = CreateFileA(path, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
    if (fh == INVALID_HANDLE_VALUE) return 0;
    if (!WriteFile(fh, buf, (DWORD)len, &put, 0) || (int)put != len) { CloseHandle(fh); return 0; }
    CloseHandle(fh);
    return 1;
}

/* a growable output buffer for the encoders */
typedef struct { BYTE* p; int len, cap; int oom; } Obuf;
static void ob_init(Obuf* o, int cap) {
    o->p = (BYTE*)LocalAlloc(LPTR, (unsigned long)cap); o->len = 0;
    o->cap = o->p ? cap : 0; o->oom = o->p ? 0 : 1;
}
static void ob_free(Obuf* o) { if (o->p) LocalFree(o->p); o->p = 0; o->len = o->cap = 0; }
static void ob_need(Obuf* o, int extra) {
    int want;
    BYTE* n;
    if (o->oom) return;
    if (o->len + extra <= o->cap) return;
    want = o->cap * 2;
    while (want < o->len + extra) want *= 2;
    n = (BYTE*)LocalAlloc(LPTR, (unsigned long)want);
    if (!n) { o->oom = 1; return; }
    mcopy(n, o->p, o->len);
    LocalFree(o->p);
    o->p = n; o->cap = want;
}
static void ob_b(Obuf* o, int v) { ob_need(o, 1); if (o->oom) return; o->p[o->len++] = (BYTE)(v & 0xFF); }
static void ob_w(Obuf* o, int v) { ob_b(o, v); ob_b(o, v >> 8); }                    /* little endian */
static void ob_d(Obuf* o, unsigned int v) { ob_b(o, (int)v); ob_b(o, (int)(v >> 8)); ob_b(o, (int)(v >> 16)); ob_b(o, (int)(v >> 24)); }
static void ob_bytes(Obuf* o, const void* s, int n) {
    ob_need(o, n); if (o->oom) return;
    mcopy(o->p + o->len, s, n); o->len += n;
}
static void ob_str(Obuf* o, const char* s) { ob_bytes(o, s, slen(s)); }
static void ob_num(Obuf* o, int v) {           /* decimal, for the PNM headers */
    char t[16]; int n = 0, i;
    if (v == 0) { ob_b(o, '0'); return; }
    while (v > 0 && n < 15) { t[n++] = (char)('0' + (v % 10)); v /= 10; }
    for (i = n - 1; i >= 0; i--) ob_b(o, t[i]);
}

/* =============================================== GDI+ runtime binding ==== */
static int gp_init(void) {
    HMODULE h;
    GdiplusStartupInput in;
    if (g_inited) return 1;
    h = LoadLibraryA("gdiplus.dll");
    if (!h) { g_err = 1; return 0; }
    *(FARPROC*)&p_Startup    = GetProcAddress(h, "GdiplusStartup");
    *(FARPROC*)&p_LoadFile   = GetProcAddress(h, "GdipLoadImageFromFile");
    *(FARPROC*)&p_Dispose    = GetProcAddress(h, "GdipDisposeImage");
    *(FARPROC*)&p_GetW       = GetProcAddress(h, "GdipGetImageWidth");
    *(FARPROC*)&p_GetH       = GetProcAddress(h, "GdipGetImageHeight");
    *(FARPROC*)&p_GetPF      = GetProcAddress(h, "GdipGetImagePixelFormat");
    *(FARPROC*)&p_GetRaw     = GetProcAddress(h, "GdipGetImageRawFormat");
    *(FARPROC*)&p_Scan0      = GetProcAddress(h, "GdipCreateBitmapFromScan0");
    *(FARPROC*)&p_GetCtx     = GetProcAddress(h, "GdipGetImageGraphicsContext");
    *(FARPROC*)&p_DelGfx     = GetProcAddress(h, "GdipDeleteGraphics");
    *(FARPROC*)&p_ClearG     = GetProcAddress(h, "GdipGraphicsClear");
    *(FARPROC*)&p_DrawRectI  = GetProcAddress(h, "GdipDrawImageRectI");
    *(FARPROC*)&p_SetInterp  = GetProcAddress(h, "GdipSetInterpolationMode");
    *(FARPROC*)&p_SetPixOff  = GetProcAddress(h, "GdipSetPixelOffsetMode");
    *(FARPROC*)&p_SaveFile   = GetProcAddress(h, "GdipSaveImageToFile");
    *(FARPROC*)&p_FrameCount = GetProcAddress(h, "GdipImageGetFrameCount");
    *(FARPROC*)&p_SelFrame   = GetProcAddress(h, "GdipImageSelectActiveFrame");
    if (!p_Startup)  { g_err = 2; return 0; }
    if (!p_LoadFile) { g_err = 3; return 0; }
    if (!p_Scan0)    { g_err = 4; return 0; }
    if (!p_SaveFile) { g_err = 5; return 0; }
    in.GdiplusVersion = 1; in.DebugEventCallback = 0;
    in.SuppressBackgroundThread = 0; in.SuppressExternalCodecs = 0;
    g_err = p_Startup(&g_token, &in, 0);
    if (g_err != 0) { g_err = 100 + g_err; return 0; }
    g_inited = 1;
    return 1;
}

/* ANSI -> UTF-16 for the two GDI+ calls that take a filename */
static WCHAR* to_wide(const char* s) {
    int n = MultiByteToWideChar(CP_ACP, 0, s, -1, 0, 0);
    WCHAR* w;
    if (n <= 0) return 0;
    w = (WCHAR*)LocalAlloc(LPTR, (unsigned long)(n * (int)sizeof(WCHAR)));
    if (!w) return 0;
    MultiByteToWideChar(CP_ACP, 0, s, -1, w, n);
    return w;
}

/* ================================================== handle management ==== */
static int slot_new(int w, int h) {
    int i;
    BYTE* px;
    if (w < 1 || h < 1 || w > 30000 || h > 30000) { g_err = 10; return 0; }
    if ((double)w * (double)h > 80000000.0) { g_err = 11; return 0; }
    for (i = 1; i <= IMG_MAX; i++) if (!g_img[i].used) break;
    if (i > IMG_MAX) { g_err = 12; return 0; }
    px = (BYTE*)LocalAlloc(LPTR, (unsigned long)w * (unsigned long)h * 4UL);
    if (!px) { g_err = 13; return 0; }
    mzero(&g_img[i], (int)sizeof(Img));
    g_img[i].px = px; g_img[i].w = w; g_img[i].h = h;
    g_img[i].used = 1; g_img[i].mode = M_32ARGB; g_img[i].frames = 1;
    g_img[i].srcfmt = F_UNKNOWN; g_img[i].srcdepth = 32;
    return i;
}
static Img* slot(int hnd) {
    if (hnd < 1 || hnd > IMG_MAX) return 0;
    if (!g_img[hnd].used) return 0;
    return &g_img[hnd];
}
/* swap in a freshly allocated pixel buffer of a new size */
static int slot_replace(Img* im, BYTE* np, int nw, int nh) {
    if (!np) return 0;
    LocalFree(im->px);
    im->px = np; im->w = nw; im->h = nh;
    return 1;
}
static BYTE* pxalloc(int w, int h) {
    if (w < 1 || h < 1) return 0;
    if ((double)w * (double)h > 80000000.0) return 0;
    return (BYTE*)LocalAlloc(LPTR, (unsigned long)w * (unsigned long)h * 4UL);
}

int img_last_error(void) { return g_err; }

int img_free(int hnd) {
    Img* im = slot(hnd);
    if (!im) return 0;
    if (im->px) LocalFree(im->px);
    if (im->gp && p_Dispose) p_Dispose(im->gp);
    mzero(im, (int)sizeof(Img));
    return 1;
}
int img_free_all(void) { int i, n = 0; for (i = 1; i <= IMG_MAX; i++) if (g_img[i].used) { img_free(i); n++; } return n; }

int img_width(int hnd)     { Img* im = slot(hnd); return im ? im->w : 0; }
int img_height(int hnd)    { Img* im = slot(hnd); return im ? im->h : 0; }
int img_src_format(int hnd){ Img* im = slot(hnd); return im ? im->srcfmt : 0; }
int img_src_depth(int hnd) { Img* im = slot(hnd); return im ? im->srcdepth : 0; }
int img_mode(int hnd)      { Img* im = slot(hnd); return im ? im->mode : 0; }
int img_colors(int hnd)    { Img* im = slot(hnd); return im ? im->palcount : 0; }
int img_frames(int hnd)    { Img* im = slot(hnd); return im ? im->frames : 0; }

int img_temp_dir(char* dst, int cap) {
    DWORD n;
    if (!dst || cap < 8) return 0;
    n = GetTempPathA((DWORD)cap, dst);
    return (n > 0 && (int)n < cap) ? (int)n : 0;
}

unsigned int img_get_pixel(int hnd, int x, int y) {
    Img* im = slot(hnd);
    BYTE* p;
    if (!im || x < 0 || y < 0 || x >= im->w || y >= im->h) return 0;
    p = im->px + ((long)y * im->w + x) * 4;
    return ((unsigned int)p[3] << 24) | ((unsigned int)p[2] << 16) | ((unsigned int)p[1] << 8) | p[0];
}
int img_set_pixel(int hnd, int x, int y, unsigned int argb) {
    Img* im = slot(hnd);
    BYTE* p;
    if (!im || x < 0 || y < 0 || x >= im->w || y >= im->h) return 0;
    p = im->px + ((long)y * im->w + x) * 4;
    p[0] = (BYTE)(argb & 0xFF); p[1] = (BYTE)((argb >> 8) & 0xFF);
    p[2] = (BYTE)((argb >> 16) & 0xFF); p[3] = (BYTE)((argb >> 24) & 0xFF);
    return 1;
}
unsigned int img_palette(int hnd, int i) {
    Img* im = slot(hnd);
    if (!im || i < 0 || i > 255) return 0;
    return im->pal[i];
}

/* ============================================== signature-based sniffing = */
static int sniff(const BYTE* b, int n) {
    if (n >= 8 && b[0] == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') return F_PNG;
    if (n >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF)              return F_JPEG;
    if (n >= 6 && b[0] == 'G' && b[1] == 'I' && b[2] == 'F')                 return F_GIF;
    if (n >= 2 && b[0] == 'B' && b[1] == 'M')                                return F_BMP;
    if (n >= 4 && ((b[0] == 'I' && b[1] == 'I' && b[2] == 42 && b[3] == 0) ||
                   (b[0] == 'M' && b[1] == 'M' && b[2] == 0  && b[3] == 42))) return F_TIFF;
    if (n >= 4 && b[0] == 0 && b[1] == 0 && b[2] == 1 && b[3] == 0)          return F_ICO;
    if (n >= 4 && b[0] == 'q' && b[1] == 'o' && b[2] == 'i' && b[3] == 'f')  return F_QOI;
    if (n >= 4 && b[0] == 1 && b[1] == 0 && b[2] == 0 && b[3] == 0)          return F_EMF;   /* EMR_HEADER */
    if (n >= 4 && b[0] == 0xD7 && b[1] == 0xCD && b[2] == 0xC6 && b[3] == 0x9A) return F_WMF;
    if (n >= 2 && b[0] == 'P' && b[1] >= '1' && b[1] <= '6')                 return F_PNM;
    if (n >= 4 && b[0] == 0x0A && b[2] == 1 && (b[1] <= 5))                  return F_PCX;
    /* TGA has no magic at the front; check the v2 footer, then the header shape */
    if (n >= 44) {
        const BYTE* f = b + n - 18;
        if (f[0]=='T'&&f[1]=='R'&&f[2]=='U'&&f[3]=='E'&&f[4]=='V'&&f[5]=='I'&&f[6]=='S'&&f[7]=='I'&&
            f[8]=='O'&&f[9]=='N'&&f[10]=='-'&&f[11]=='X'&&f[12]=='F'&&f[13]=='I'&&f[14]=='L'&&f[15]=='E')
            return F_TGA;
    }
    if (n >= 18) {
        int it = b[2], bpp = b[16];
        if ((it==1||it==2||it==3||it==9||it==10||it==11) &&
            (bpp==8||bpp==15||bpp==16||bpp==24||bpp==32) && b[1] <= 1) return F_TGA;
    }
    return F_UNKNOWN;
}

int img_detect(const char* path) {
    BYTE* b; int n, f;
    b = file_slurp(path, &n);
    if (!b) return F_UNKNOWN;
    f = sniff(b, n);
    LocalFree(b);
    return f;
}

/* ====================================================== TGA decode/encode */
static int dec_tga(const BYTE* b, int n, int* pw, int* ph, BYTE** out, int* depth) {
    int idlen, cmtype, it, cmfirst, cmlen, cmbits, w, h, bpp, desc, rle, topdown;
    int i, px, total, cmsize = 0;
    const BYTE* p; const BYTE* cm = 0;
    BYTE* dst;
    if (n < 18) return 0;
    idlen = b[0]; cmtype = b[1]; it = b[2];
    cmfirst = b[3] | (b[4] << 8); cmlen = b[5] | (b[6] << 8); cmbits = b[7];
    w = b[12] | (b[13] << 8); h = b[14] | (b[15] << 8);
    bpp = b[16]; desc = b[17];
    topdown = (desc & 0x20) ? 1 : 0;
    rle = (it >= 9) ? 1 : 0;
    if (w < 1 || h < 1) return 0;
    if (!(bpp == 8 || bpp == 15 || bpp == 16 || bpp == 24 || bpp == 32)) return 0;
    p = b + 18 + idlen;
    if (cmtype == 1 && cmlen > 0) {
        cmsize = (cmbits + 7) / 8;
        cm = p;
        p += (long)cmlen * cmsize;
    }
    if (p >= b + n) return 0;
    dst = pxalloc(w, h);
    if (!dst) return 0;
    total = w * h;
    px = 0;
    while (px < total) {
        int count = 1, raw = 1, k;
        if (rle) {
            if (p >= b + n) break;
            k = *p++;
            count = (k & 0x7F) + 1;
            raw = (k & 0x80) ? 0 : 1;
        } else {
            count = total - px;                 /* consume the lot in one go */
        }
        for (k = 0; k < count && px < total; k++) {
            int r = 0, g = 0, bl = 0, a = 255, v;
            const BYTE* s = p;
            if (s + ((bpp + 7) / 8) > b + n) { px = total; break; }
            if (bpp == 8) {
                if (cm && cmsize >= 3) {
                    int ci = *s; const BYTE* e;
                    ci -= cmfirst; if (ci < 0) ci = 0; if (ci >= cmlen) ci = cmlen - 1;
                    e = cm + (long)ci * cmsize;
                    bl = e[0]; g = e[1]; r = e[2]; if (cmsize >= 4) a = e[3];
                } else { r = g = bl = *s; }        /* type 3 = greyscale */
            } else if (bpp == 15 || bpp == 16) {
                v = s[0] | (s[1] << 8);
                bl = (v & 0x1F) << 3;  bl |= bl >> 5;
                g  = ((v >> 5) & 0x1F) << 3; g |= g >> 5;
                r  = ((v >> 10) & 0x1F) << 3; r |= r >> 5;
                if (bpp == 16 && !(v & 0x8000) && (desc & 0x0F)) a = 0;
            } else {
                bl = s[0]; g = s[1]; r = s[2];
                if (bpp == 32) a = s[3];
            }
            {
                int x = px % w, y = px / w;
                int yy = topdown ? y : (h - 1 - y);
                BYTE* d = dst + ((long)yy * w + x) * 4;
                d[0] = (BYTE)bl; d[1] = (BYTE)g; d[2] = (BYTE)r; d[3] = (BYTE)a;
            }
            px++;
            if (raw || !rle) p += (bpp + 7) / 8;
        }
        if (rle && !raw) p += (bpp + 7) / 8;      /* the single repeated pixel */
    }
    *pw = w; *ph = h; *out = dst; *depth = bpp;
    return 1;
}

static int enc_tga(Img* im, Obuf* o, int rle) {
    int x, y;
    ob_b(o, 0); ob_b(o, 0); ob_b(o, rle ? 10 : 2);
    ob_w(o, 0); ob_w(o, 0); ob_b(o, 0);
    ob_w(o, 0); ob_w(o, 0);
    ob_w(o, im->w); ob_w(o, im->h);
    ob_b(o, 32); ob_b(o, 0x28);                    /* 32bpp, top-down, 8 alpha bits */
    for (y = 0; y < im->h; y++) {
        BYTE* row = im->px + (long)y * im->w * 4;
        if (!rle) {
            ob_bytes(o, row, im->w * 4);
        } else {
            x = 0;
            while (x < im->w) {
                int runlen = 1;
                BYTE* a = row + (long)x * 4;
                while (x + runlen < im->w && runlen < 128) {
                    BYTE* c = row + (long)(x + runlen) * 4;
                    if (c[0]!=a[0]||c[1]!=a[1]||c[2]!=a[2]||c[3]!=a[3]) break;
                    runlen++;
                }
                if (runlen >= 2) {
                    ob_b(o, 0x80 | (runlen - 1)); ob_bytes(o, a, 4);
                    x += runlen;
                } else {
                    int lit = 1;
                    while (x + lit < im->w && lit < 128) {
                        BYTE* c = row + (long)(x + lit) * 4;
                        BYTE* pv = row + (long)(x + lit - 1) * 4;
                        if (c[0]==pv[0]&&c[1]==pv[1]&&c[2]==pv[2]&&c[3]==pv[3]) break;
                        lit++;
                    }
                    ob_b(o, lit - 1); ob_bytes(o, row + (long)x * 4, lit * 4);
                    x += lit;
                }
            }
        }
    }
    ob_d(o, 0); ob_d(o, 0);
    ob_str(o, "TRUEVISION-XFILE."); ob_b(o, 0);
    return !o->oom;
}

/* ====================================================== QOI decode/encode */
#define QOI_OP_INDEX 0x00
#define QOI_OP_DIFF  0x40
#define QOI_OP_LUMA  0x80
#define QOI_OP_RUN   0xC0
#define QOI_OP_RGB   0xFE
#define QOI_OP_RGBA  0xFF
#define QOI_HASH(r,g,b,a) (((r)*3 + (g)*5 + (b)*7 + (a)*11) & 63)

static int dec_qoi(const BYTE* b, int n, int* pw, int* ph, BYTE** out, int* depth) {
    int w, h, ch, i, px, total, run = 0, pos = 14;
    BYTE idx[64][4];
    BYTE cr = 0, cg = 0, cb = 0, ca = 255;
    BYTE* dst;
    if (n < 22) return 0;
    w = (b[4] << 24) | (b[5] << 16) | (b[6] << 8) | b[7];
    h = (b[8] << 24) | (b[9] << 16) | (b[10] << 8) | b[11];
    ch = b[12];
    if (w < 1 || h < 1 || (ch != 3 && ch != 4)) return 0;
    dst = pxalloc(w, h);
    if (!dst) return 0;
    mzero(idx, 64 * 4);
    total = w * h;
    for (px = 0; px < total; px++) {
        if (run > 0) { run--; }
        else if (pos < n) {
            int t = b[pos++];
            if (t == QOI_OP_RGB && pos + 2 < n) { cr = b[pos]; cg = b[pos+1]; cb = b[pos+2]; pos += 3; }
            else if (t == QOI_OP_RGBA && pos + 3 < n) { cr = b[pos]; cg = b[pos+1]; cb = b[pos+2]; ca = b[pos+3]; pos += 4; }
            else if ((t & 0xC0) == QOI_OP_INDEX) { int k = t & 63; cr = idx[k][0]; cg = idx[k][1]; cb = idx[k][2]; ca = idx[k][3]; }
            else if ((t & 0xC0) == QOI_OP_DIFF) {
                cr = (BYTE)(cr + ((t >> 4) & 3) - 2);
                cg = (BYTE)(cg + ((t >> 2) & 3) - 2);
                cb = (BYTE)(cb + (t & 3) - 2);
            } else if ((t & 0xC0) == QOI_OP_LUMA && pos < n) {
                int t2 = b[pos++];
                int vg = (t & 63) - 32;
                cr = (BYTE)(cr + vg - 8 + ((t2 >> 4) & 15));
                cb = (BYTE)(cb + vg - 8 + (t2 & 15));
                cg = (BYTE)(cg + vg);
            } else if ((t & 0xC0) == QOI_OP_RUN) { run = t & 63; }
            i = QOI_HASH(cr, cg, cb, ca);
            idx[i][0] = cr; idx[i][1] = cg; idx[i][2] = cb; idx[i][3] = ca;
        }
        {
            BYTE* d = dst + (long)px * 4;
            d[0] = cb; d[1] = cg; d[2] = cr; d[3] = ca;
        }
    }
    *pw = w; *ph = h; *out = dst; *depth = ch * 8;
    return 1;
}

static int enc_qoi(Img* im, Obuf* o) {
    int px, total = im->w * im->h, run = 0;
    BYTE idx[64][4];
    BYTE pr = 0, pg = 0, pb = 0, pa = 255;
    ob_str(o, "qoif");
    ob_b(o, (im->w >> 24) & 0xFF); ob_b(o, (im->w >> 16) & 0xFF); ob_b(o, (im->w >> 8) & 0xFF); ob_b(o, im->w & 0xFF);
    ob_b(o, (im->h >> 24) & 0xFF); ob_b(o, (im->h >> 16) & 0xFF); ob_b(o, (im->h >> 8) & 0xFF); ob_b(o, im->h & 0xFF);
    ob_b(o, 4); ob_b(o, 0);                                  /* RGBA, sRGB-with-linear-alpha */
    mzero(idx, 64 * 4);
    for (px = 0; px < total; px++) {
        BYTE* s = im->px + (long)px * 4;
        BYTE r = s[2], g = s[1], b = s[0], a = s[3];
        if (r == pr && g == pg && b == pb && a == pa) {
            run++;
            if (run == 62 || px == total - 1) { ob_b(o, QOI_OP_RUN | (run - 1)); run = 0; }
        } else {
            int i;
            if (run > 0) { ob_b(o, QOI_OP_RUN | (run - 1)); run = 0; }
            i = QOI_HASH(r, g, b, a);
            if (idx[i][0] == r && idx[i][1] == g && idx[i][2] == b && idx[i][3] == a) {
                ob_b(o, QOI_OP_INDEX | i);
            } else {
                idx[i][0] = r; idx[i][1] = g; idx[i][2] = b; idx[i][3] = a;
                if (a == pa) {
                    int vr = (int)r - pr, vg = (int)g - pg, vb = (int)b - pb;
                    int dr = vr - vg, db = vb - vg;
                    if (vr > -3 && vr < 2 && vg > -3 && vg < 2 && vb > -3 && vb < 2) {
                        ob_b(o, QOI_OP_DIFF | ((vr + 2) << 4) | ((vg + 2) << 2) | (vb + 2));
                    } else if (dr > -9 && dr < 8 && vg > -33 && vg < 32 && db > -9 && db < 8) {
                        ob_b(o, QOI_OP_LUMA | (vg + 32));
                        ob_b(o, ((dr + 8) << 4) | (db + 8));
                    } else {
                        ob_b(o, QOI_OP_RGB); ob_b(o, r); ob_b(o, g); ob_b(o, b);
                    }
                } else {
                    ob_b(o, QOI_OP_RGBA); ob_b(o, r); ob_b(o, g); ob_b(o, b); ob_b(o, a);
                }
            }
            pr = r; pg = g; pb = b; pa = a;
        }
    }
    { int i; for (i = 0; i < 7; i++) ob_b(o, 0); ob_b(o, 1); }
    return !o->oom;
}

/* ====================================================== PCX decode/encode */
static int dec_pcx(const BYTE* b, int n, int* pw, int* ph, BYTE** out, int* depth) {
    int bpp, planes, x0, y0, x1, y1, bpl, w, h, y, pl;
    const BYTE* p; const BYTE* vga = 0;
    BYTE* dst; BYTE* line;
    if (n < 128 || b[0] != 0x0A) return 0;
    bpp = b[3]; x0 = b[4] | (b[5] << 8); y0 = b[6] | (b[7] << 8);
    x1 = b[8] | (b[9] << 8); y1 = b[10] | (b[11] << 8);
    planes = b[65]; bpl = b[66] | (b[67] << 8);
    w = x1 - x0 + 1; h = y1 - y0 + 1;
    if (w < 1 || h < 1 || bpl < 1 || planes < 1 || planes > 4) return 0;
    if (!(bpp == 1 || bpp == 8)) return 0;
    if (n >= 769 && b[n - 769] == 12) vga = b + n - 768;
    dst = pxalloc(w, h);
    if (!dst) return 0;
    line = (BYTE*)LocalAlloc(LPTR, (unsigned long)bpl * planes + 8);
    if (!line) { LocalFree(dst); return 0; }
    p = b + 128;
    for (y = 0; y < h; y++) {
        int need = bpl * planes, got = 0;
        while (got < need && p < b + n) {
            int v = *p++;
            if ((v & 0xC0) == 0xC0) {
                int cnt = v & 0x3F;
                int val = (p < b + n) ? *p++ : 0;
                while (cnt-- > 0 && got < need) line[got++] = (BYTE)val;
            } else line[got++] = (BYTE)v;
        }
        while (got < need) line[got++] = 0;
        for (pl = 0; pl < w; pl++) {
            int r = 0, g = 0, bl = 0;
            if (bpp == 8 && planes >= 3) {
                r = line[pl]; g = line[bpl + pl]; bl = line[2 * bpl + pl];
            } else if (bpp == 8) {
                int ci = line[pl];
                if (vga) { r = vga[ci * 3]; g = vga[ci * 3 + 1]; bl = vga[ci * 3 + 2]; }
                else { r = g = bl = ci; }
            } else {                                        /* 1 bit per plane */
                int ci = 0, k;
                for (k = 0; k < planes; k++)
                    if (line[k * bpl + (pl >> 3)] & (0x80 >> (pl & 7))) ci |= (1 << k);
                r = b[16 + ci * 3]; g = b[16 + ci * 3 + 1]; bl = b[16 + ci * 3 + 2];
            }
            {
                BYTE* d = dst + ((long)y * w + pl) * 4;
                d[0] = (BYTE)bl; d[1] = (BYTE)g; d[2] = (BYTE)r; d[3] = 255;
            }
        }
    }
    LocalFree(line);
    *pw = w; *ph = h; *out = dst; *depth = bpp * planes;
    return 1;
}

static void pcx_rle_row(Obuf* o, const BYTE* row, int n) {
    int i = 0;
    while (i < n) {
        int run = 1;
        while (i + run < n && row[i + run] == row[i] && run < 63) run++;
        if (run > 1 || (row[i] & 0xC0) == 0xC0) { ob_b(o, 0xC0 | run); ob_b(o, row[i]); }
        else ob_b(o, row[i]);
        i += run;
    }
}

static int enc_pcx(Img* im, Obuf* o) {          /* 24-bit, 3 planes, RLE */
    int y, x, bpl = im->w;
    BYTE* pl;
    ob_b(o, 0x0A); ob_b(o, 5); ob_b(o, 1); ob_b(o, 8);
    ob_w(o, 0); ob_w(o, 0); ob_w(o, im->w - 1); ob_w(o, im->h - 1);
    ob_w(o, 96); ob_w(o, 96);
    { int i; for (i = 0; i < 48; i++) ob_b(o, 0); }
    ob_b(o, 0); ob_b(o, 3); ob_w(o, bpl);
    ob_w(o, 1); ob_w(o, 0); ob_w(o, 0);
    { int i; for (i = 0; i < 54; i++) ob_b(o, 0); }
    pl = (BYTE*)LocalAlloc(LPTR, (unsigned long)bpl);
    if (!pl) return 0;
    for (y = 0; y < im->h; y++) {
        BYTE* row = im->px + (long)y * im->w * 4;
        int c;
        for (c = 0; c < 3; c++) {
            int srcofs = 2 - c;                 /* our order is B,G,R -> want R,G,B */
            for (x = 0; x < im->w; x++) pl[x] = row[(long)x * 4 + srcofs];
            pcx_rle_row(o, pl, bpl);
        }
    }
    LocalFree(pl);
    return !o->oom;
}

/* ============================================ PNM (pbm/pgm/ppm) codecs == */
static int pnm_tok(const BYTE* b, int n, int* pos) {
    int v = -1;
    while (*pos < n) {
        BYTE c = b[*pos];
        if (c == '#') { while (*pos < n && b[*pos] != '\n') (*pos)++; continue; }
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') { (*pos)++; continue; }
        break;
    }
    while (*pos < n && b[*pos] >= '0' && b[*pos] <= '9') {
        if (v < 0) v = 0;
        v = v * 10 + (b[*pos] - '0');
        (*pos)++;
    }
    return v;
}

static int dec_pnm(const BYTE* b, int n, int* pw, int* ph, BYTE** out, int* depth) {
    int kind, w, h, maxv = 1, pos = 2, i, total;
    BYTE* dst;
    if (n < 8 || b[0] != 'P') return 0;
    kind = b[1] - '0';
    if (kind < 1 || kind > 6) return 0;
    w = pnm_tok(b, n, &pos);
    h = pnm_tok(b, n, &pos);
    if (kind != 1 && kind != 4) maxv = pnm_tok(b, n, &pos);
    if (w < 1 || h < 1 || maxv < 1) return 0;
    if (kind >= 4) pos++;                        /* single whitespace before binary data */
    dst = pxalloc(w, h);
    if (!dst) return 0;
    total = w * h;
    if (kind == 1 || kind == 4) {                /* bitmap: 1 = black */
        for (i = 0; i < total; i++) {
            int bit = 0;
            if (kind == 1) {
                while (pos < n && (b[pos]==' '||b[pos]=='\n'||b[pos]=='\r'||b[pos]=='\t')) pos++;
                if (pos < n) bit = (b[pos++] == '1');
            } else {
                int x = i % w, y = i / w;
                long ofs = (long)y * ((w + 7) / 8) + (x >> 3);
                if (pos + ofs < n) bit = (b[pos + ofs] & (0x80 >> (x & 7))) ? 1 : 0;
            }
            { BYTE v = bit ? 0 : 255; BYTE* d = dst + (long)i * 4; d[0]=v; d[1]=v; d[2]=v; d[3]=255; }
        }
        *depth = 1;
    } else if (kind == 2 || kind == 5) {         /* greyscale */
        for (i = 0; i < total; i++) {
            int v = (kind == 2) ? pnm_tok(b, n, &pos) : ((pos < n) ? b[pos++] : 0);
            if (v < 0) v = 0;
            v = (maxv == 255) ? v : (v * 255 / maxv);
            { BYTE* d = dst + (long)i * 4; d[0]=(BYTE)v; d[1]=(BYTE)v; d[2]=(BYTE)v; d[3]=255; }
        }
        *depth = 8;
    } else {                                     /* colour */
        for (i = 0; i < total; i++) {
            int r, g, bl;
            if (kind == 3) { r = pnm_tok(b,n,&pos); g = pnm_tok(b,n,&pos); bl = pnm_tok(b,n,&pos); }
            else { r = (pos<n)?b[pos++]:0; g = (pos<n)?b[pos++]:0; bl = (pos<n)?b[pos++]:0; }
            if (r < 0) r = 0; if (g < 0) g = 0; if (bl < 0) bl = 0;
            if (maxv != 255) { r = r*255/maxv; g = g*255/maxv; bl = bl*255/maxv; }
            { BYTE* d = dst + (long)i * 4; d[0]=(BYTE)bl; d[1]=(BYTE)g; d[2]=(BYTE)r; d[3]=255; }
        }
        *depth = 24;
    }
    *pw = w; *ph = h; *out = dst;
    return 1;
}

static int enc_pnm(Img* im, Obuf* o) {          /* binary P6, or P5/P4 if the image is already grey/bw */
    int x, y, kind = 6;
    if (im->mode == M_BW1) kind = 4;
    else if (im->mode == M_GREY8 || im->mode == M_GREY4 || im->mode == M_GREY2) kind = 5;
    ob_b(o, 'P'); ob_b(o, '0' + kind); ob_b(o, '\n');
    ob_num(o, im->w); ob_b(o, ' '); ob_num(o, im->h); ob_b(o, '\n');
    if (kind != 4) { ob_num(o, 255); ob_b(o, '\n'); }
    for (y = 0; y < im->h; y++) {
        BYTE* row = im->px + (long)y * im->w * 4;
        if (kind == 4) {
            int acc = 0, bits = 0;
            for (x = 0; x < im->w; x++) {
                BYTE* p = row + (long)x * 4;
                acc = (acc << 1) | (luma(p[2], p[1], p[0]) < 128 ? 1 : 0);
                if (++bits == 8) { ob_b(o, acc); acc = 0; bits = 0; }
            }
            if (bits) ob_b(o, acc << (8 - bits));
        } else if (kind == 5) {
            for (x = 0; x < im->w; x++) { BYTE* p = row + (long)x * 4; ob_b(o, luma(p[2], p[1], p[0])); }
        } else {
            for (x = 0; x < im->w; x++) { BYTE* p = row + (long)x * 4; ob_b(o, p[2]); ob_b(o, p[1]); ob_b(o, p[0]); }
        }
    }
    return !o->oom;
}

/* ============================================================ BMP encode = */
/* our own, because GDI+ only ever writes 24/32-bit BMPs - this one writes
   1, 4, 8, 24 and 32-bit files, using the palette a conversion left behind. */
static int enc_bmp(Img* im, Obuf* o, int bits) {
    int x, y, rowbytes, pad, palents, dataofs, i;
    if (bits == 0) {
        switch (im->mode) {
        case M_BW1:    bits = 1;  break;
        case M_GREY2:  bits = 8;  break;
        case M_GREY4:
        case M_PAL16:  bits = 4;  break;
        case M_PAL256:
        case M_GREY8:
        case M_WEB216: bits = 8;  break;
        case M_32ARGB: bits = 32; break;
        default:       bits = 24; break;
        }
    }
    palents = (bits <= 8) ? (1 << bits) : 0;
    rowbytes = ((im->w * bits + 31) / 32) * 4;
    dataofs = 14 + 40 + palents * 4;
    ob_b(o, 'B'); ob_b(o, 'M');
    ob_d(o, (unsigned int)(dataofs + rowbytes * im->h));
    ob_w(o, 0); ob_w(o, 0);
    ob_d(o, (unsigned int)dataofs);
    ob_d(o, 40);
    ob_d(o, (unsigned int)im->w); ob_d(o, (unsigned int)im->h);
    ob_w(o, 1); ob_w(o, bits);
    ob_d(o, 0); ob_d(o, (unsigned int)(rowbytes * im->h));
    ob_d(o, 3780); ob_d(o, 3780);                 /* ~96 dpi */
    ob_d(o, (unsigned int)palents); ob_d(o, 0);
    if (palents) {
        int have = im->palcount;
        for (i = 0; i < palents; i++) {
            unsigned int c = (i < have) ? im->pal[i] : 0;
            if (i >= have && im->mode != M_PAL256 && im->mode != M_PAL16 && im->mode != M_WEB216) {
                int v = (palents == 2) ? (i ? 255 : 0) : (i * 255 / (palents - 1));
                c = ((unsigned int)v << 16) | ((unsigned int)v << 8) | (unsigned int)v;
            }
            ob_b(o, (int)(c & 0xFF));           /* blue  */
            ob_b(o, (int)((c >> 8) & 0xFF));    /* green */
            ob_b(o, (int)((c >> 16) & 0xFF));   /* red   */
            ob_b(o, 0);
        }
    }
    for (y = im->h - 1; y >= 0; y--) {           /* BMP rows run bottom-up */
        BYTE* row = im->px + (long)y * im->w * 4;
        int written = 0;
        if (bits == 32) {
            ob_bytes(o, row, im->w * 4); written = im->w * 4;
        } else if (bits == 24) {
            for (x = 0; x < im->w; x++) { BYTE* p = row + (long)x * 4; ob_b(o, p[0]); ob_b(o, p[1]); ob_b(o, p[2]); }
            written = im->w * 3;
        } else {
            int acc = 0, bitsfilled = 0;
            for (x = 0; x < im->w; x++) {
                BYTE* p = row + (long)x * 4;
                int idx = 0;
                if (bits == 1) idx = (luma(p[2], p[1], p[0]) >= 128) ? 1 : 0;
                else {
                    /* nearest entry in the palette we already built */
                    int best = 0, bd = 1 << 30, k, lim = im->palcount ? im->palcount : 1;
                    for (k = 0; k < lim; k++) {
                        int pr = (int)((im->pal[k] >> 16) & 0xFF);
                        int pg = (int)((im->pal[k] >> 8) & 0xFF);
                        int pb = (int)(im->pal[k] & 0xFF);
                        int d = (pr - p[2]) * (pr - p[2]) + (pg - p[1]) * (pg - p[1]) + (pb - p[0]) * (pb - p[0]);
                        if (d < bd) { bd = d; best = k; }
                    }
                    idx = best;
                }
                acc = (acc << bits) | (idx & ((1 << bits) - 1));
                bitsfilled += bits;
                if (bitsfilled == 8) { ob_b(o, acc); acc = 0; bitsfilled = 0; written++; }
            }
            if (bitsfilled) { ob_b(o, acc << (8 - bitsfilled)); written++; }
        }
        for (pad = written; pad < rowbytes; pad++) ob_b(o, 0);
    }
    return !o->oom;
}

/* ================================================ GDI+ decode into RGBA == */
static int gdip_decode(const char* path, Img* im) {
    GpImage gi = 0;
    GpBitmap wrap = 0;
    GpGraphics g = 0;
    WCHAR* wp;
    UINT uw = 0, uh = 0;
    int pf = 0, st, fc = 0;
    GUID raw;
    BYTE* px;
    if (!gp_init()) return 0;
    wp = to_wide(path);
    if (!wp) { g_err = 20; return 0; }
    st = p_LoadFile(wp, &gi);
    LocalFree(wp);
    if (st != 0 || !gi) { g_err = 200 + st; return 0; }
    p_GetW(gi, &uw); p_GetH(gi, &uh);
    if ((int)uw < 1 || (int)uh < 1) { p_Dispose(gi); g_err = 21; return 0; }
    px = pxalloc((int)uw, (int)uh);
    if (!px) { p_Dispose(gi); g_err = 22; return 0; }
    /* wrap OUR buffer in a GDI+ bitmap and let GDI+ draw the decoded image
       into it - no LockBits, no second copy. */
    st = p_Scan0((int)uw, (int)uh, (int)uw * 4, PF_32ARGB, px, &wrap);
    if (st != 0 || !wrap) { LocalFree(px); p_Dispose(gi); g_err = 23; return 0; }
    if (p_GetCtx(wrap, &g) == 0 && g) {
        if (p_ClearG) p_ClearG(g, 0x00000000);
        if (p_SetInterp) p_SetInterp(g, INTERP_NN);
        p_DrawRectI(g, gi, 0, 0, (int)uw, (int)uh);
        p_DelGfx(g);
    } else { p_Dispose(wrap); LocalFree(px); p_Dispose(gi); g_err = 24; return 0; }
    p_Dispose(wrap);
    /* metadata: what was it, and how deep */
    im->srcdepth = 32;
    if (p_GetPF && p_GetPF(gi, &pf) == 0) im->srcdepth = (pf >> 8) & 0xFF;
    im->srcfmt = F_UNKNOWN;
    if (p_GetRaw && p_GetRaw(gi, &raw) == 0) {
        if      (guid_eq(&raw, &FMT_PNG))  im->srcfmt = F_PNG;
        else if (guid_eq(&raw, &FMT_JPEG)) im->srcfmt = F_JPEG;
        else if (guid_eq(&raw, &FMT_GIF))  im->srcfmt = F_GIF;
        else if (guid_eq(&raw, &FMT_BMP))  im->srcfmt = F_BMP;
        else if (guid_eq(&raw, &FMT_TIFF)) im->srcfmt = F_TIFF;
        else if (guid_eq(&raw, &FMT_ICO))  im->srcfmt = F_ICO;
        else if (guid_eq(&raw, &FMT_EMF))  im->srcfmt = F_EMF;
        else if (guid_eq(&raw, &FMT_WMF))  im->srcfmt = F_WMF;
    }
    im->frames = 1;
    im->gppage = (im->srcfmt == F_TIFF) ? 1 : 0;
    if (p_FrameCount) {
        const GUID* dim = im->gppage ? &DIM_PAGE : &DIM_TIME;
        if (p_FrameCount(gi, dim, (UINT*)&fc) == 0 && fc > 0) im->frames = fc;
    }
    if (im->px) LocalFree(im->px);
    im->px = px; im->w = (int)uw; im->h = (int)uh;
    if (im->frames > 1) im->gp = gi; else p_Dispose(gi);
    return 1;
}

/* redraw the currently selected frame of a kept multi-frame image */
int img_select_frame(int hnd, int frame) {
    Img* im = slot(hnd);
    GpBitmap wrap = 0;
    GpGraphics g = 0;
    const GUID* dim;
    if (!im || !im->gp || frame < 0 || frame >= im->frames) return 0;
    dim = im->gppage ? &DIM_PAGE : &DIM_TIME;
    if (!p_SelFrame || p_SelFrame(im->gp, dim, (UINT)frame) != 0) { g_err = 25; return 0; }
    if (p_Scan0(im->w, im->h, im->w * 4, PF_32ARGB, im->px, &wrap) != 0 || !wrap) { g_err = 26; return 0; }
    if (p_GetCtx(wrap, &g) == 0 && g) {
        if (p_ClearG) p_ClearG(g, 0x00000000);
        if (p_SetInterp) p_SetInterp(g, INTERP_NN);
        p_DrawRectI(g, im->gp, 0, 0, im->w, im->h);
        p_DelGfx(g);
    }
    p_Dispose(wrap);
    im->mode = M_32ARGB; im->palcount = 0;
    return 1;
}

/* ================================================ GDI+ encode from RGBA == */
static int gdip_encode(Img* im, const char* path, const GUID* clsid, int quality) {
    GpBitmap wrap = 0;
    WCHAR* wp;
    int st;
    EncoderParameters ep;
    long qv = quality;
    if (!gp_init()) return 0;
    if (p_Scan0(im->w, im->h, im->w * 4, PF_32ARGB, im->px, &wrap) != 0 || !wrap) { g_err = 30; return 0; }
    wp = to_wide(path);
    if (!wp) { p_Dispose(wrap); g_err = 31; return 0; }
    if (quality >= 0 && quality <= 100) {
        ep.Count = 1;
        ep.Parameter[0].Guid = GUID_Quality;
        ep.Parameter[0].NumberOfValues = 1;
        ep.Parameter[0].Type = 4;                 /* EncoderParameterValueTypeLong */
        ep.Parameter[0].Value = &qv;
        st = p_SaveFile(wrap, wp, clsid, &ep);
    } else {
        st = p_SaveFile(wrap, wp, clsid, 0);
    }
    LocalFree(wp);
    p_Dispose(wrap);
    if (st != 0) { g_err = 300 + st; return 0; }
    return 1;
}

/* ================================================================ load === */
int img_load(const char* path) {
    BYTE* raw; int n, f, hnd, w = 0, h = 0, depth = 0;
    BYTE* px = 0;
    Img* im;
    g_err = 0;
    if (!path || !path[0]) { g_err = 40; return 0; }
    raw = file_slurp(path, &n);
    if (!raw) { g_err = 41; return 0; }
    f = sniff(raw, n);
    /* the four formats Windows knows nothing about, decoded here */
    if (f == F_TGA)      dec_tga(raw, n, &w, &h, &px, &depth);
    else if (f == F_QOI) dec_qoi(raw, n, &w, &h, &px, &depth);
    else if (f == F_PCX) dec_pcx(raw, n, &w, &h, &px, &depth);
    else if (f == F_PNM) dec_pnm(raw, n, &w, &h, &px, &depth);
    LocalFree(raw);
    if (px) {
        int i;
        for (i = 1; i <= IMG_MAX; i++) if (!g_img[i].used) break;
        if (i > IMG_MAX) { LocalFree(px); g_err = 12; return 0; }
        mzero(&g_img[i], (int)sizeof(Img));
        im = &g_img[i];
        im->px = px; im->w = w; im->h = h; im->used = 1;
        im->mode = M_32ARGB; im->frames = 1;
        im->srcfmt = f; im->srcdepth = depth;
        return i;
    }
    /* everything else goes to GDI+ */
    hnd = slot_new(1, 1);
    if (!hnd) return 0;
    im = &g_img[hnd];
    if (!gdip_decode(path, im)) { img_free(hnd); return 0; }
    im->mode = M_32ARGB; im->palcount = 0;
    if (im->srcfmt == F_UNKNOWN) im->srcfmt = f;
    return hnd;
}

int img_create(int w, int h, unsigned int argb) {
    int hnd = slot_new(w, h), i, total;
    Img* im;
    BYTE b, g, r, a;
    g_err = 0;
    if (!hnd) return 0;
    im = &g_img[hnd];
    b = (BYTE)(argb & 0xFF); g = (BYTE)((argb >> 8) & 0xFF);
    r = (BYTE)((argb >> 16) & 0xFF); a = (BYTE)((argb >> 24) & 0xFF);
    total = w * h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        p[0] = b; p[1] = g; p[2] = r; p[3] = a;
    }
    return hnd;
}

int img_clone(int hnd) {
    Img* s = slot(hnd);
    int nh;
    Img* d;
    if (!s) return 0;
    nh = slot_new(s->w, s->h);
    if (!nh) return 0;
    d = &g_img[nh];
    mcopy(d->px, s->px, s->w * s->h * 4);
    d->srcfmt = s->srcfmt; d->srcdepth = s->srcdepth;
    d->mode = s->mode; d->palcount = s->palcount;
    mcopy(d->pal, s->pal, 256 * (int)sizeof(unsigned int));
    return nh;
}

/* ================================================================ save === */
int img_save(int hnd, const char* path, int fmt, int quality, int bmpbits) {
    Img* im = slot(hnd);
    Obuf o;
    int ok = 0;
    g_err = 0;
    if (!im || !path || !path[0]) { g_err = 50; return 0; }
    switch (fmt) {
    case F_PNG:  return gdip_encode(im, path, &CLSID_PNG,  -1);
    case F_JPEG: return gdip_encode(im, path, &CLSID_JPEG, (quality < 0 || quality > 100) ? 85 : quality);
    case F_GIF:  return gdip_encode(im, path, &CLSID_GIF,  -1);
    case F_TIFF: return gdip_encode(im, path, &CLSID_TIFF, -1);
    case F_BMP:  ob_init(&o, 65536); ok = enc_bmp(im, &o, bmpbits); break;
    case F_TGA:  ob_init(&o, 65536); ok = enc_tga(im, &o, quality == 0 ? 0 : 1); break;
    case F_QOI:  ob_init(&o, 65536); ok = enc_qoi(im, &o); break;
    case F_PCX:  ob_init(&o, 65536); ok = enc_pcx(im, &o); break;
    case F_PNM:  ob_init(&o, 65536); ok = enc_pnm(im, &o); break;
    default: g_err = 51; return 0;
    }
    if (!ok || o.oom) { ob_free(&o); g_err = 52; return 0; }
    ok = file_dump(path, o.p, o.len);
    ob_free(&o);
    if (!ok) { g_err = 53; return 0; }
    return 1;
}

/* ======================================================= geometry ops === */
int img_rotate90(int hnd, int quads) {
    Img* im = slot(hnd);
    BYTE* np;
    int x, y, nw, nh;
    if (!im) return 0;
    quads = ((quads % 4) + 4) % 4;
    if (quads == 0) return 1;
    nw = (quads == 2) ? im->w : im->h;
    nh = (quads == 2) ? im->h : im->w;
    np = pxalloc(nw, nh);
    if (!np) { g_err = 60; return 0; }
    for (y = 0; y < im->h; y++) {
        BYTE* srow = im->px + (long)y * im->w * 4;
        for (x = 0; x < im->w; x++) {
            int dx, dy;
            if (quads == 1)      { dx = nw - 1 - y; dy = x; }
            else if (quads == 2) { dx = im->w - 1 - x; dy = im->h - 1 - y; }
            else                 { dx = y; dy = nh - 1 - x; }
            mcopy(np + ((long)dy * nw + dx) * 4, srow + (long)x * 4, 4);
        }
    }
    return slot_replace(im, np, nw, nh);
}

int img_flip(int hnd, int mode) {          /* 1 = mirror left/right, 2 = top/bottom, 3 = both */
    Img* im = slot(hnd);
    int x, y;
    BYTE t[4];
    if (!im) return 0;
    if (mode & 1) {
        for (y = 0; y < im->h; y++) {
            BYTE* row = im->px + (long)y * im->w * 4;
            for (x = 0; x < im->w / 2; x++) {
                BYTE* a = row + (long)x * 4;
                BYTE* b = row + (long)(im->w - 1 - x) * 4;
                mcopy(t, a, 4); mcopy(a, b, 4); mcopy(b, t, 4);
            }
        }
    }
    if (mode & 2) {
        for (y = 0; y < im->h / 2; y++) {
            BYTE* a = im->px + (long)y * im->w * 4;
            BYTE* b = im->px + (long)(im->h - 1 - y) * im->w * 4;
            for (x = 0; x < im->w; x++) {
                mcopy(t, a + (long)x * 4, 4);
                mcopy(a + (long)x * 4, b + (long)x * 4, 4);
                mcopy(b + (long)x * 4, t, 4);
            }
        }
    }
    return 1;
}

/* bilinear sample with edge clamp */
static void sample_bil(Img* im, double sx, double sy, BYTE* out) {
    int x0, y0, x1, y1, c;
    double fx, fy;
    x0 = (int)sx; y0 = (int)sy;
    if (sx < 0) x0 = 0; if (sy < 0) y0 = 0;
    fx = sx - x0; fy = sy - y0;
    x1 = x0 + 1; y1 = y0 + 1;
    x0 = iclamp(x0, 0, im->w - 1); x1 = iclamp(x1, 0, im->w - 1);
    y0 = iclamp(y0, 0, im->h - 1); y1 = iclamp(y1, 0, im->h - 1);
    {
        BYTE* p00 = im->px + ((long)y0 * im->w + x0) * 4;
        BYTE* p10 = im->px + ((long)y0 * im->w + x1) * 4;
        BYTE* p01 = im->px + ((long)y1 * im->w + x0) * 4;
        BYTE* p11 = im->px + ((long)y1 * im->w + x1) * 4;
        for (c = 0; c < 4; c++) {
            double top = p00[c] + (p10[c] - p00[c]) * fx;
            double bot = p01[c] + (p11[c] - p01[c]) * fx;
            double v = top + (bot - top) * fy;
            out[c] = (BYTE)iclamp((int)(v + 0.5), 0, 255);
        }
    }
}

int img_resize(int hnd, int nw, int nh, int filter) {   /* 0 nearest 1 bilinear 2 box-average */
    Img* im = slot(hnd);
    BYTE* np;
    int x, y, c;
    if (!im || nw < 1 || nh < 1) return 0;
    if (nw == im->w && nh == im->h) return 1;
    np = pxalloc(nw, nh);
    if (!np) { g_err = 61; return 0; }
    if (filter == 2 && (nw < im->w || nh < im->h)) {
        /* area average - the right way to shrink; no moire, no lost detail */
        for (y = 0; y < nh; y++) {
            int sy0 = (int)((double)y * im->h / nh);
            int sy1 = (int)((double)(y + 1) * im->h / nh);
            if (sy1 <= sy0) sy1 = sy0 + 1;
            if (sy1 > im->h) sy1 = im->h;
            for (x = 0; x < nw; x++) {
                int sx0 = (int)((double)x * im->w / nw);
                int sx1 = (int)((double)(x + 1) * im->w / nw);
                long acc[4]; int cnt = 0, yy, xx;
                if (sx1 <= sx0) sx1 = sx0 + 1;
                if (sx1 > im->w) sx1 = im->w;
                acc[0] = acc[1] = acc[2] = acc[3] = 0;
                for (yy = sy0; yy < sy1; yy++) {
                    BYTE* row = im->px + (long)yy * im->w * 4;
                    for (xx = sx0; xx < sx1; xx++) {
                        BYTE* p = row + (long)xx * 4;
                        acc[0] += p[0]; acc[1] += p[1]; acc[2] += p[2]; acc[3] += p[3];
                        cnt++;
                    }
                }
                if (!cnt) cnt = 1;
                { BYTE* d = np + ((long)y * nw + x) * 4;
                  for (c = 0; c < 4; c++) d[c] = (BYTE)(acc[c] / cnt); }
            }
        }
    } else if (filter == 0) {
        for (y = 0; y < nh; y++) {
            int sy = (int)((double)y * im->h / nh);
            sy = iclamp(sy, 0, im->h - 1);
            for (x = 0; x < nw; x++) {
                int sx = (int)((double)x * im->w / nw);
                sx = iclamp(sx, 0, im->w - 1);
                mcopy(np + ((long)y * nw + x) * 4, im->px + ((long)sy * im->w + sx) * 4, 4);
            }
        }
    } else {
        for (y = 0; y < nh; y++) {
            double sy = ((double)y + 0.5) * im->h / nh - 0.5;
            for (x = 0; x < nw; x++) {
                double sx = ((double)x + 0.5) * im->w / nw - 0.5;
                sample_bil(im, sx, sy, np + ((long)y * nw + x) * 4);
            }
        }
    }
    return slot_replace(im, np, nw, nh);
}

int img_crop(int hnd, int cx, int cy, int cw, int ch) {
    Img* im = slot(hnd);
    BYTE* np;
    int y;
    if (!im) return 0;
    if (cx < 0) { cw += cx; cx = 0; }
    if (cy < 0) { ch += cy; cy = 0; }
    if (cx + cw > im->w) cw = im->w - cx;
    if (cy + ch > im->h) ch = im->h - cy;
    if (cw < 1 || ch < 1) { g_err = 62; return 0; }
    np = pxalloc(cw, ch);
    if (!np) { g_err = 63; return 0; }
    for (y = 0; y < ch; y++)
        mcopy(np + (long)y * cw * 4, im->px + ((long)(cy + y) * im->w + cx) * 4, cw * 4);
    return slot_replace(im, np, cw, ch);
}

/* grow/shrink the canvas without scaling; anchor 1..9 = top-left..bottom-right */
int img_canvas(int hnd, int nw, int nh, int anchor, unsigned int bg) {
    Img* im = slot(hnd);
    BYTE* np;
    int x, y, ox, oy, i, total;
    BYTE b, g, r, a;
    if (!im || nw < 1 || nh < 1) return 0;
    np = pxalloc(nw, nh);
    if (!np) { g_err = 64; return 0; }
    b = (BYTE)(bg & 0xFF); g = (BYTE)((bg >> 8) & 0xFF);
    r = (BYTE)((bg >> 16) & 0xFF); a = (BYTE)((bg >> 24) & 0xFF);
    total = nw * nh;
    for (i = 0; i < total; i++) { BYTE* p = np + (long)i * 4; p[0]=b; p[1]=g; p[2]=r; p[3]=a; }
    if (anchor < 1 || anchor > 9) anchor = 5;
    ox = ((anchor - 1) % 3) * (nw - im->w) / 2;
    oy = ((anchor - 1) / 3) * (nh - im->h) / 2;
    for (y = 0; y < im->h; y++) {
        int dy = y + oy;
        if (dy < 0 || dy >= nh) continue;
        for (x = 0; x < im->w; x++) {
            int dx = x + ox;
            if (dx < 0 || dx >= nw) continue;
            mcopy(np + ((long)dy * nw + dx) * 4, im->px + ((long)y * im->w + x) * 4, 4);
        }
    }
    return slot_replace(im, np, nw, nh);
}

/* fit into a box: 0 stretch, 1 proportional+padded(centred), 2 cover(crop),
   3 centre at 1:1 (pad or crop), 4 proportional, no padding                */
int img_fit(int hnd, int bw, int bh, int mode, unsigned int bg) {
    Img* im = slot(hnd);
    double sx, sy, s;
    int nw, nh;
    if (!im || bw < 1 || bh < 1) return 0;
    switch (mode) {
    case 0:
        return img_resize(hnd, bw, bh, 2);
    case 3:
        return img_canvas(hnd, bw, bh, 5, bg);
    case 2:
        sx = (double)bw / im->w; sy = (double)bh / im->h;
        s = (sx > sy) ? sx : sy;
        nw = (int)(im->w * s + 0.5); nh = (int)(im->h * s + 0.5);
        if (nw < bw) nw = bw; if (nh < bh) nh = bh;
        if (!img_resize(hnd, nw, nh, 2)) return 0;
        return img_crop(hnd, (nw - bw) / 2, (nh - bh) / 2, bw, bh);
    default:
        sx = (double)bw / im->w; sy = (double)bh / im->h;
        s = (sx < sy) ? sx : sy;
        nw = (int)(im->w * s + 0.5); nh = (int)(im->h * s + 0.5);
        if (nw < 1) nw = 1; if (nh < 1) nh = 1;
        if (!img_resize(hnd, nw, nh, 2)) return 0;
        if (mode == 4) return 1;
        return img_canvas(hnd, bw, bh, 5, bg);
    }
}

/* free rotation. Clarion hands us cos+sin (no libm here); grow = 1 expands the
   canvas so nothing is clipped, 0 keeps the size. */
int img_rotate_free(int hnd, double cosv, double sinv, unsigned int bg, int grow, int smooth) {
    Img* im = slot(hnd);
    BYTE* np;
    int nw, nh, x, y, i, total;
    double cx, cy, ncx, ncy;
    BYTE bb, bg2, br, ba;
    if (!im) return 0;
    if (grow) {
        double aw = (cosv < 0 ? -cosv : cosv) * im->w + (sinv < 0 ? -sinv : sinv) * im->h;
        double ah = (sinv < 0 ? -sinv : sinv) * im->w + (cosv < 0 ? -cosv : cosv) * im->h;
        nw = (int)(aw + 0.5); nh = (int)(ah + 0.5);
    } else { nw = im->w; nh = im->h; }
    if (nw < 1) nw = 1; if (nh < 1) nh = 1;
    np = pxalloc(nw, nh);
    if (!np) { g_err = 65; return 0; }
    bb = (BYTE)(bg & 0xFF); bg2 = (BYTE)((bg >> 8) & 0xFF);
    br = (BYTE)((bg >> 16) & 0xFF); ba = (BYTE)((bg >> 24) & 0xFF);
    total = nw * nh;
    for (i = 0; i < total; i++) { BYTE* p = np + (long)i * 4; p[0]=bb; p[1]=bg2; p[2]=br; p[3]=ba; }
    cx = im->w / 2.0; cy = im->h / 2.0;
    ncx = nw / 2.0;   ncy = nh / 2.0;
    for (y = 0; y < nh; y++) {
        for (x = 0; x < nw; x++) {
            double dx = x + 0.5 - ncx, dy = y + 0.5 - ncy;
            double sx =  cosv * dx + sinv * dy + cx - 0.5;
            double sy = -sinv * dx + cosv * dy + cy - 0.5;
            BYTE* d = np + ((long)y * nw + x) * 4;
            if (sx < -0.5 || sy < -0.5 || sx > im->w - 0.5 || sy > im->h - 0.5) continue;
            if (smooth) sample_bil(im, sx, sy, d);
            else {
                int ix = iclamp((int)(sx + 0.5), 0, im->w - 1);
                int iy = iclamp((int)(sy + 0.5), 0, im->h - 1);
                mcopy(d, im->px + ((long)iy * im->w + ix) * 4, 4);
            }
        }
    }
    return slot_replace(im, np, nw, nh);
}

/* ========================================================== colour ops == */
int img_greyscale(int hnd, int mode) {   /* 0 luma601 1 average 2 lightness 3 BT709 */
    Img* im = slot(hnd);
    int i, total;
    if (!im) return 0;
    total = im->w * im->h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        int r = p[2], g = p[1], b = p[0], v;
        switch (mode) {
        case 1: v = (r + g + b) / 3; break;
        case 2: { int mx = r > g ? r : g; int mn = r < g ? r : g;
                  if (b > mx) mx = b; if (b < mn) mn = b; v = (mx + mn) / 2; } break;
        case 3: v = (r * 54 + g * 183 + b * 19) >> 8; break;
        default: v = luma(r, g, b); break;
        }
        v = iclamp(v, 0, 255);
        p[0] = p[1] = p[2] = (BYTE)v;
    }
    im->mode = M_GREY8; im->palcount = 0;
    return 1;
}

int img_invert(int hnd) {
    Img* im = slot(hnd);
    int i, total;
    if (!im) return 0;
    total = im->w * im->h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        p[0] = (BYTE)(255 - p[0]); p[1] = (BYTE)(255 - p[1]); p[2] = (BYTE)(255 - p[2]);
    }
    return 1;
}

int img_sepia(int hnd) {
    Img* im = slot(hnd);
    int i, total;
    if (!im) return 0;
    total = im->w * im->h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        int r = p[2], g = p[1], b = p[0];
        int nr = (r * 393 + g * 769 + b * 189) / 1000;
        int ng = (r * 349 + g * 686 + b * 168) / 1000;
        int nb = (r * 272 + g * 534 + b * 131) / 1000;
        p[2] = (BYTE)iclamp(nr, 0, 255); p[1] = (BYTE)iclamp(ng, 0, 255); p[0] = (BYTE)iclamp(nb, 0, 255);
    }
    return 1;
}

/* brightness -100..100, contrast -100..100, saturation -100..100 */
int img_adjust(int hnd, int bright, int contrast, int satur) {
    Img* im = slot(hnd);
    int i, total, cf;
    if (!im) return 0;
    total = im->w * im->h;
    contrast = iclamp(contrast, -100, 100);
    cf = (contrast >= 0) ? (contrast == 100 ? 25600 : 25600 / (100 - contrast) ) : (256 * (100 + contrast) / 100);
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        int c, v[3];
        v[0] = p[0]; v[1] = p[1]; v[2] = p[2];
        for (c = 0; c < 3; c++) {
            int t = v[c] + bright * 255 / 100;
            t = ((t - 128) * cf >> 8) + 128;
            v[c] = iclamp(t, 0, 255);
        }
        if (satur != 0) {
            int lv = luma(v[2], v[1], v[0]);
            for (c = 0; c < 3; c++)
                v[c] = iclamp(lv + (v[c] - lv) * (100 + satur) / 100, 0, 255);
        }
        p[0] = (BYTE)v[0]; p[1] = (BYTE)v[1]; p[2] = (BYTE)v[2];
    }
    return 1;
}

/* apply a 256-entry lookup table - this is how gamma, levels and curves get
   done: Clarion works out the table (it has ** and LOG), C blasts the pixels.
   chan bit 1=blue 2=green 4=red, 7 = all three.                            */
int img_lut(int hnd, const BYTE* lut, int chan) {
    Img* im = slot(hnd);
    int i, total;
    if (!im || !lut) return 0;
    if (chan == 0) chan = 7;
    total = im->w * im->h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        if (chan & 1) p[0] = lut[p[0]];
        if (chan & 2) p[1] = lut[p[1]];
        if (chan & 4) p[2] = lut[p[2]];
    }
    return 1;
}

int img_flatten(int hnd, unsigned int bg) {      /* composite alpha onto a colour */
    Img* im = slot(hnd);
    int i, total, br, bgc, bb;
    if (!im) return 0;
    bb = (int)(bg & 0xFF); bgc = (int)((bg >> 8) & 0xFF); br = (int)((bg >> 16) & 0xFF);
    total = im->w * im->h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        int a = p[3];
        if (a == 255) continue;
        p[0] = (BYTE)((p[0] * a + bb  * (255 - a)) / 255);
        p[1] = (BYTE)((p[1] * a + bgc * (255 - a)) / 255);
        p[2] = (BYTE)((p[2] * a + br  * (255 - a)) / 255);
        p[3] = 255;
    }
    return 1;
}

int img_opacity(int hnd, int pct) {
    Img* im = slot(hnd);
    int i, total;
    if (!im) return 0;
    pct = iclamp(pct, 0, 100);
    total = im->w * im->h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        p[3] = (BYTE)(p[3] * pct / 100);
    }
    return 1;
}

/* separable box blur, run `passes` times - three passes approximate a gaussian */
int img_blur(int hnd, int radius, int passes) {
    Img* im = slot(hnd);
    BYTE* tmp;
    int pass, x, y, c;
    if (!im || radius < 1) return 0;
    if (radius > 100) radius = 100;
    if (passes < 1) passes = 1;
    if (passes > 3) passes = 3;
    tmp = pxalloc(im->w, im->h);
    if (!tmp) { g_err = 70; return 0; }
    for (pass = 0; pass < passes; pass++) {
        for (y = 0; y < im->h; y++) {                        /* horizontal */
            BYTE* srow = im->px + (long)y * im->w * 4;
            BYTE* drow = tmp + (long)y * im->w * 4;
            for (x = 0; x < im->w; x++) {
                long acc[4]; int n = 0, k;
                acc[0]=acc[1]=acc[2]=acc[3]=0;
                for (k = x - radius; k <= x + radius; k++) {
                    int kk = iclamp(k, 0, im->w - 1);
                    BYTE* p = srow + (long)kk * 4;
                    acc[0]+=p[0]; acc[1]+=p[1]; acc[2]+=p[2]; acc[3]+=p[3]; n++;
                }
                for (c = 0; c < 4; c++) drow[(long)x * 4 + c] = (BYTE)(acc[c] / n);
            }
        }
        for (x = 0; x < im->w; x++) {                        /* vertical */
            for (y = 0; y < im->h; y++) {
                long acc[4]; int n = 0, k;
                acc[0]=acc[1]=acc[2]=acc[3]=0;
                for (k = y - radius; k <= y + radius; k++) {
                    int kk = iclamp(k, 0, im->h - 1);
                    BYTE* p = tmp + ((long)kk * im->w + x) * 4;
                    acc[0]+=p[0]; acc[1]+=p[1]; acc[2]+=p[2]; acc[3]+=p[3]; n++;
                }
                for (c = 0; c < 4; c++) im->px[((long)y * im->w + x) * 4 + c] = (BYTE)(acc[c] / n);
            }
        }
    }
    LocalFree(tmp);
    return 1;
}

/* unsharp mask: amount 0..200 percent */
int img_sharpen(int hnd, int amount) {
    Img* im = slot(hnd);
    BYTE* blur;
    int i, total, c;
    if (!im) return 0;
    amount = iclamp(amount, 0, 300);
    total = im->w * im->h;
    blur = pxalloc(im->w, im->h);
    if (!blur) { g_err = 71; return 0; }
    mcopy(blur, im->px, total * 4);
    {   /* blur the copy in place with a 1px box, twice */
        int pass, x, y;
        BYTE* tmp = pxalloc(im->w, im->h);
        if (!tmp) { LocalFree(blur); g_err = 72; return 0; }
        for (pass = 0; pass < 2; pass++) {
            for (y = 0; y < im->h; y++)
                for (x = 0; x < im->w; x++) {
                    long acc[3]; int n = 0, k;
                    acc[0]=acc[1]=acc[2]=0;
                    for (k = x - 1; k <= x + 1; k++) {
                        BYTE* p = blur + ((long)y * im->w + iclamp(k, 0, im->w - 1)) * 4;
                        acc[0]+=p[0]; acc[1]+=p[1]; acc[2]+=p[2]; n++;
                    }
                    for (c = 0; c < 3; c++) tmp[((long)y * im->w + x) * 4 + c] = (BYTE)(acc[c] / n);
                }
            for (x = 0; x < im->w; x++)
                for (y = 0; y < im->h; y++) {
                    long acc[3]; int n = 0, k;
                    acc[0]=acc[1]=acc[2]=0;
                    for (k = y - 1; k <= y + 1; k++) {
                        BYTE* p = tmp + ((long)iclamp(k, 0, im->h - 1) * im->w + x) * 4;
                        acc[0]+=p[0]; acc[1]+=p[1]; acc[2]+=p[2]; n++;
                    }
                    for (c = 0; c < 3; c++) blur[((long)y * im->w + x) * 4 + c] = (BYTE)(acc[c] / n);
                }
        }
        LocalFree(tmp);
    }
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        BYTE* b = blur + (long)i * 4;
        for (c = 0; c < 3; c++)
            p[c] = (BYTE)iclamp(p[c] + (p[c] - b[c]) * amount / 100, 0, 255);
    }
    LocalFree(blur);
    return 1;
}

/* Luma histogram. Deliberately NOT an array parameter: a Clarion array does
   not cross to C as a bare pointer reliably, so the counts are built here and
   read back one bin at a time. img_hist_calc returns the tallest bin, which is
   exactly what you need to scale a chart. */
static unsigned int g_hist[256];

int img_hist_calc(int hnd) {
    Img* im = slot(hnd);
    int i, total;
    unsigned int peak = 0;
    for (i = 0; i < 256; i++) g_hist[i] = 0;
    if (!im) return 0;
    total = im->w * im->h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        g_hist[luma(p[2], p[1], p[0])]++;
    }
    for (i = 0; i < 256; i++) if (g_hist[i] > peak) peak = g_hist[i];
    return (int)peak;
}

unsigned int img_hist_bin(int i) {
    if (i < 0 || i > 255) return 0;
    return g_hist[i];
}

/* ============================================ colour-depth conversion === */
/* median cut. Histogram in 5-5-5 space (32768 cells), split the box with the
   longest axis at its population median until we have the colours we want,
   then map every pixel through a 32768-entry nearest-entry cache.           */
typedef struct { int r0, r1, g0, g1, b0, b1; long pop; } Box;

static long box_pop(const unsigned int* hist, const Box* bx) {
    int r, g, b; long n = 0;
    for (r = bx->r0; r <= bx->r1; r++)
        for (g = bx->g0; g <= bx->g1; g++)
            for (b = bx->b0; b <= bx->b1; b++)
                n += hist[(r << 10) | (g << 5) | b];
    return n;
}

static void box_avg(const unsigned int* hist, const Box* bx, unsigned int* outrgb) {
    int r, g, b;
    double sr = 0, sg = 0, sb = 0; double n = 0;
    for (r = bx->r0; r <= bx->r1; r++)
        for (g = bx->g0; g <= bx->g1; g++)
            for (b = bx->b0; b <= bx->b1; b++) {
                long c = hist[(r << 10) | (g << 5) | b];
                if (!c) continue;
                sr += (double)c * ((r << 3) | (r >> 2));
                sg += (double)c * ((g << 3) | (g >> 2));
                sb += (double)c * ((b << 3) | (b >> 2));
                n += (double)c;
            }
    if (n < 1) { *outrgb = 0; return; }
    *outrgb = ((unsigned int)iclamp((int)(sr / n + 0.5), 0, 255) << 16)
            | ((unsigned int)iclamp((int)(sg / n + 0.5), 0, 255) << 8)
            |  (unsigned int)iclamp((int)(sb / n + 0.5), 0, 255);
}

static int build_palette(Img* im, int want) {
    unsigned int* hist;
    Box* boxes;
    int i, total, nb = 1;
    if (want < 2) want = 2;
    if (want > 256) want = 256;
    hist = (unsigned int*)LocalAlloc(LPTR, 32768UL * (unsigned long)sizeof(unsigned int));
    if (!hist) { g_err = 80; return 0; }
    boxes = (Box*)LocalAlloc(LPTR, (unsigned long)want * (unsigned long)sizeof(Box));
    if (!boxes) { LocalFree(hist); g_err = 81; return 0; }
    total = im->w * im->h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        hist[((p[2] >> 3) << 10) | ((p[1] >> 3) << 5) | (p[0] >> 3)]++;
    }
    boxes[0].r0 = boxes[0].g0 = boxes[0].b0 = 0;
    boxes[0].r1 = boxes[0].g1 = boxes[0].b1 = 31;
    boxes[0].pop = total;
    while (nb < want) {
        int bi = -1, axis, split, r, g, b;
        long best = 1;
        for (i = 0; i < nb; i++) {
            Box* bx = &boxes[i];
            if (bx->pop <= 1) continue;
            if (bx->r1 == bx->r0 && bx->g1 == bx->g0 && bx->b1 == bx->b0) continue;
            if (bx->pop > best) { best = bx->pop; bi = i; }
        }
        if (bi < 0) break;
        {
            Box* bx = &boxes[bi];
            int dr = bx->r1 - bx->r0, dg = bx->g1 - bx->g0, db = bx->b1 - bx->b0;
            long half = bx->pop / 2, acc = 0;
            axis = (dr >= dg && dr >= db) ? 0 : ((dg >= db) ? 1 : 2);
            split = (axis == 0) ? bx->r0 : ((axis == 1) ? bx->g0 : bx->b0);
            /* walk the chosen axis until we pass half the population */
            for (;;) {
                long slice = 0;
                if (axis == 0) {
                    for (g = bx->g0; g <= bx->g1; g++) for (b = bx->b0; b <= bx->b1; b++) slice += hist[(split << 10) | (g << 5) | b];
                } else if (axis == 1) {
                    for (r = bx->r0; r <= bx->r1; r++) for (b = bx->b0; b <= bx->b1; b++) slice += hist[(r << 10) | (split << 5) | b];
                } else {
                    for (r = bx->r0; r <= bx->r1; r++) for (g = bx->g0; g <= bx->g1; g++) slice += hist[(r << 10) | (g << 5) | split];
                }
                acc += slice;
                if (acc >= half) break;
                if ((axis == 0 && split >= bx->r1 - 1) || (axis == 1 && split >= bx->g1 - 1) || (axis == 2 && split >= bx->b1 - 1)) break;
                split++;
            }
            boxes[nb] = *bx;
            if (axis == 0)      { boxes[nb].r0 = split + 1; bx->r1 = split; }
            else if (axis == 1) { boxes[nb].g0 = split + 1; bx->g1 = split; }
            else                { boxes[nb].b0 = split + 1; bx->b1 = split; }
            if (boxes[nb].r0 > boxes[nb].r1 || boxes[nb].g0 > boxes[nb].g1 || boxes[nb].b0 > boxes[nb].b1) { bx->pop = 1; continue; }
            bx->pop = box_pop(hist, bx);
            boxes[nb].pop = box_pop(hist, &boxes[nb]);
            nb++;
        }
    }
    for (i = 0; i < nb; i++) box_avg(hist, &boxes[i], &im->pal[i]);
    im->palcount = nb;
    LocalFree(boxes);
    LocalFree(hist);
    return nb;
}

/* nearest palette entry, cached on the 5-5-5 cell */
static int pal_nearest(Img* im, short* cache, int r, int g, int b) {
    int cell = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
    int k, best = 0, bd = 1 << 30;
    if (cache[cell] >= 0) return cache[cell];
    for (k = 0; k < im->palcount; k++) {
        int pr = (int)((im->pal[k] >> 16) & 0xFF);
        int pg = (int)((im->pal[k] >> 8) & 0xFF);
        int pb = (int)(im->pal[k] & 0xFF);
        int d = (pr - r) * (pr - r) * 3 + (pg - g) * (pg - g) * 6 + (pb - b) * (pb - b);
        if (d < bd) { bd = d; best = k; }
    }
    cache[cell] = (short)best;
    return best;
}

int img_convert(int hnd, int mode, int dither, int threshold) {
    Img* im = slot(hnd);
    int x, y, total, i;
    if (!im) return 0;
    total = im->w * im->h;
    if (threshold < 1 || threshold > 254) threshold = 128;

    if (mode == M_32ARGB) { im->mode = M_32ARGB; im->palcount = 0; return 1; }

    if (mode == M_24RGB) {
        for (i = 0; i < total; i++) im->px[(long)i * 4 + 3] = 255;
        im->mode = M_24RGB; im->palcount = 0; return 1;
    }

    if (mode == M_16_565 || mode == M_15_555) {
        int rb = 5, gb = (mode == M_16_565) ? 6 : 5, bb = 5;
        if (!dither) {
            for (i = 0; i < total; i++) {
                BYTE* p = im->px + (long)i * 4;
                int r = p[2] >> (8 - rb), g = p[1] >> (8 - gb), b = p[0] >> (8 - bb);
                p[2] = (BYTE)((r << (8 - rb)) | (r >> (2 * rb - 8 > 0 ? 2 * rb - 8 : 0)));
                p[1] = (BYTE)((g << (8 - gb)) | (g >> (2 * gb - 8 > 0 ? 2 * gb - 8 : 0)));
                p[0] = (BYTE)((b << (8 - bb)) | (b >> (2 * bb - 8 > 0 ? 2 * bb - 8 : 0)));
                p[3] = 255;
            }
        } else {
            /* ordered 4x4 Bayer - cheap, no error buffer, looks good on gradients */
            static const int bay[16] = {0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
            for (y = 0; y < im->h; y++)
                for (x = 0; x < im->w; x++) {
                    BYTE* p = im->px + ((long)y * im->w + x) * 4;
                    int t = bay[(y & 3) * 4 + (x & 3)];
                    int r = iclamp(p[2] + (t - 8) * 255 / (16 * ((1 << rb) - 1)) * 2, 0, 255) >> (8 - rb);
                    int g = iclamp(p[1] + (t - 8) * 255 / (16 * ((1 << gb) - 1)) * 2, 0, 255) >> (8 - gb);
                    int b = iclamp(p[0] + (t - 8) * 255 / (16 * ((1 << bb) - 1)) * 2, 0, 255) >> (8 - bb);
                    p[2] = (BYTE)(r * 255 / ((1 << rb) - 1));
                    p[1] = (BYTE)(g * 255 / ((1 << gb) - 1));
                    p[0] = (BYTE)(b * 255 / ((1 << bb) - 1));
                    p[3] = 255;
                }
        }
        im->mode = mode; im->palcount = 0; return 1;
    }

    if (mode == M_GREY8 || mode == M_GREY4 || mode == M_GREY2 || mode == M_BW1) {
        int levels = (mode == M_GREY8) ? 256 : ((mode == M_GREY4) ? 16 : ((mode == M_GREY2) ? 4 : 2));
        img_greyscale(hnd, 0);
        if (levels < 256) {
            if (!dither) {
                for (i = 0; i < total; i++) {
                    BYTE* p = im->px + (long)i * 4;
                    int v;
                    if (levels == 2) v = (p[0] >= threshold) ? 255 : 0;
                    else { v = p[0] * (levels - 1) / 255; v = v * 255 / (levels - 1); }
                    p[0] = p[1] = p[2] = (BYTE)v;
                }
            } else {
                /* Floyd-Steinberg on the luma plane */
                int* err = (int*)LocalAlloc(LPTR, (unsigned long)(im->w + 2) * 2UL * (unsigned long)sizeof(int));
                if (!err) { g_err = 82; return 0; }
                for (y = 0; y < im->h; y++) {
                    int* cur = err + (y & 1) * (im->w + 2);
                    int* nxt = err + ((y + 1) & 1) * (im->w + 2);
                    for (x = 0; x < im->w + 2; x++) nxt[x] = 0;
                    for (x = 0; x < im->w; x++) {
                        BYTE* p = im->px + ((long)y * im->w + x) * 4;
                        int want = iclamp(p[0] + cur[x + 1], 0, 255);
                        int got, e;
                        if (levels == 2) got = (want >= threshold) ? 255 : 0;
                        else { got = want * (levels - 1) / 255; got = got * 255 / (levels - 1); }
                        e = want - got;
                        p[0] = p[1] = p[2] = (BYTE)got;
                        cur[x + 2] += e * 7 / 16;
                        nxt[x]     += e * 3 / 16;
                        nxt[x + 1] += e * 5 / 16;
                        nxt[x + 2] += e * 1 / 16;
                    }
                }
                LocalFree(err);
            }
        }
        im->palcount = levels <= 256 ? levels : 0;
        for (i = 0; i < im->palcount; i++) {
            int v = (im->palcount == 1) ? 0 : (i * 255 / (im->palcount - 1));
            im->pal[i] = ((unsigned int)v << 16) | ((unsigned int)v << 8) | (unsigned int)v;
        }
        im->mode = mode;
        return 1;
    }

    if (mode == M_WEB216) {
        for (i = 0; i < total; i++) {
            BYTE* p = im->px + (long)i * 4;
            p[2] = (BYTE)((p[2] + 25) / 51 * 51);
            p[1] = (BYTE)((p[1] + 25) / 51 * 51);
            p[0] = (BYTE)((p[0] + 25) / 51 * 51);
            p[3] = 255;
        }
        { int r, g, b, k = 0;
          for (r = 0; r < 6; r++) for (g = 0; g < 6; g++) for (b = 0; b < 6; b++)
            im->pal[k++] = ((unsigned int)(r*51) << 16) | ((unsigned int)(g*51) << 8) | (unsigned int)(b*51);
          im->palcount = 216; }
        im->mode = M_WEB216;
        return 1;
    }

    if (mode == M_PAL256 || mode == M_PAL16) {
        int want = (mode == M_PAL256) ? 256 : 16;
        short* cache;
        if (!build_palette(im, want)) return 0;
        cache = (short*)LocalAlloc(LPTR, 32768UL * (unsigned long)sizeof(short));
        if (!cache) { g_err = 83; return 0; }
        for (i = 0; i < 32768; i++) cache[i] = -1;
        if (!dither) {
            for (i = 0; i < total; i++) {
                BYTE* p = im->px + (long)i * 4;
                int k = pal_nearest(im, cache, p[2], p[1], p[0]);
                p[2] = (BYTE)((im->pal[k] >> 16) & 0xFF);
                p[1] = (BYTE)((im->pal[k] >> 8) & 0xFF);
                p[0] = (BYTE)(im->pal[k] & 0xFF);
                p[3] = 255;
            }
        } else {
            int* err = (int*)LocalAlloc(LPTR, (unsigned long)(im->w + 2) * 2UL * 3UL * (unsigned long)sizeof(int));
            if (!err) { LocalFree(cache); g_err = 84; return 0; }
            for (y = 0; y < im->h; y++) {
                int* cur = err + (y & 1) * (im->w + 2) * 3;
                int* nxt = err + ((y + 1) & 1) * (im->w + 2) * 3;
                for (x = 0; x < (im->w + 2) * 3; x++) nxt[x] = 0;
                for (x = 0; x < im->w; x++) {
                    BYTE* p = im->px + ((long)y * im->w + x) * 4;
                    int wr = iclamp(p[2] + cur[(x + 1) * 3 + 0], 0, 255);
                    int wg = iclamp(p[1] + cur[(x + 1) * 3 + 1], 0, 255);
                    int wb = iclamp(p[0] + cur[(x + 1) * 3 + 2], 0, 255);
                    int k = pal_nearest(im, cache, wr, wg, wb);
                    int gr = (int)((im->pal[k] >> 16) & 0xFF);
                    int gg = (int)((im->pal[k] >> 8) & 0xFF);
                    int gb = (int)(im->pal[k] & 0xFF);
                    int er = wr - gr, eg = wg - gg, eb = wb - gb;
                    p[2] = (BYTE)gr; p[1] = (BYTE)gg; p[0] = (BYTE)gb; p[3] = 255;
                    cur[(x + 2) * 3 + 0] += er * 7 / 16; cur[(x + 2) * 3 + 1] += eg * 7 / 16; cur[(x + 2) * 3 + 2] += eb * 7 / 16;
                    nxt[(x    ) * 3 + 0] += er * 3 / 16; nxt[(x    ) * 3 + 1] += eg * 3 / 16; nxt[(x    ) * 3 + 2] += eb * 3 / 16;
                    nxt[(x + 1) * 3 + 0] += er * 5 / 16; nxt[(x + 1) * 3 + 1] += eg * 5 / 16; nxt[(x + 1) * 3 + 2] += eb * 5 / 16;
                    nxt[(x + 2) * 3 + 0] += er     / 16; nxt[(x + 2) * 3 + 1] += eg     / 16; nxt[(x + 2) * 3 + 2] += eb     / 16;
                }
            }
            LocalFree(err);
        }
        LocalFree(cache);
        im->mode = mode;
        return 1;
    }
    g_err = 85;
    return 0;
}

int img_posterize(int hnd, int levels) {
    Img* im = slot(hnd);
    int i, total, c;
    if (!im) return 0;
    levels = iclamp(levels, 2, 64);
    total = im->w * im->h;
    for (i = 0; i < total; i++) {
        BYTE* p = im->px + (long)i * 4;
        for (c = 0; c < 3; c++) {
            int v = p[c] * (levels - 1) / 255;
            p[c] = (BYTE)(v * 255 / (levels - 1));
        }
    }
    return 1;
}

/* ========================================================== composite === */
int img_draw(int dsth, int srch, int dx, int dy, int dw, int dh, int filter, int alphapct) {
    Img* d = slot(dsth);
    Img* s = slot(srch);
    int x, y, sh;
    if (!d || !s) return 0;
    if (dw < 1) dw = s->w;
    if (dh < 1) dh = s->h;
    alphapct = iclamp(alphapct, 0, 100);
    sh = 0;
    if (dw != s->w || dh != s->h) {
        sh = img_clone(srch);
        if (!sh) return 0;
        if (!img_resize(sh, dw, dh, filter)) { img_free(sh); return 0; }
        s = slot(sh);
    }
    for (y = 0; y < dh; y++) {
        int ty = dy + y;
        if (ty < 0 || ty >= d->h) continue;
        for (x = 0; x < dw; x++) {
            int tx = dx + x;
            BYTE* sp; BYTE* tp; int a;
            if (tx < 0 || tx >= d->w) continue;
            sp = s->px + ((long)y * s->w + x) * 4;
            tp = d->px + ((long)ty * d->w + tx) * 4;
            a = sp[3] * alphapct / 100;
            if (a <= 0) continue;
            if (a >= 255) { mcopy(tp, sp, 4); continue; }
            tp[0] = (BYTE)((sp[0] * a + tp[0] * (255 - a)) / 255);
            tp[1] = (BYTE)((sp[1] * a + tp[1] * (255 - a)) / 255);
            tp[2] = (BYTE)((sp[2] * a + tp[2] * (255 - a)) / 255);
            tp[3] = (BYTE)(tp[3] > a ? tp[3] : a);
        }
    }
    if (sh) img_free(sh);
    return 1;
}

/* =========================================================== test card == */
/* something colourful to convert when you have no file to hand: colour bars,
   a full-spectrum sweep, a grey ramp and a soft radial - between them they
   show off every depth reduction and every dither. */
int img_testcard(int w, int h) {
    int hnd = img_create(w, h, 0xFF101418);
    Img* im;
    int x, y;
    if (!hnd) return 0;
    im = &g_img[hnd];
    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            BYTE* p = im->px + ((long)y * w + x) * 4;
            double fy = (double)y / h, fx = (double)w > 1 ? (double)x / (w - 1) : 0.0;
            int r = 0, g = 0, b = 0;
            if (fy < 0.28) {                                  /* colour bars */
                static const int bar[8][3] = {{255,255,255},{255,255,0},{0,255,255},{0,255,0},
                                              {255,0,255},{255,0,0},{0,0,255},{20,20,20}};
                int k = (int)(fx * 8); if (k > 7) k = 7;
                r = bar[k][0]; g = bar[k][1]; b = bar[k][2];
            } else if (fy < 0.56) {                           /* hue sweep */
                double hh = fx * 6.0;
                int seg = (int)hh;
                double f = hh - seg;
                int v = 255, q = (int)(255 * (1 - f)), t = (int)(255 * f);
                switch (seg) {
                case 0: r=v; g=t; b=0; break;
                case 1: r=q; g=v; b=0; break;
                case 2: r=0; g=v; b=t; break;
                case 3: r=0; g=q; b=v; break;
                case 4: r=t; g=0; b=v; break;
                default: r=v; g=0; b=q; break;
                }
                { double sh2 = 1.0 - (fy - 0.28) / 0.28 * 0.75;
                  r = (int)(r * sh2); g = (int)(g * sh2); b = (int)(b * sh2); }
            } else if (fy < 0.72) {                           /* smooth grey ramp */
                int v = (int)(fx * 255);
                r = g = b = v;
            } else if (fy < 0.80) {                           /* 16 grey steps */
                int v = (int)(fx * 16); if (v > 15) v = 15;
                r = g = b = v * 17;
            } else {                                          /* radial + gradient */
                double cx = w / 2.0, cy = h * 0.90;
                double dx = (x - cx) / (w * 0.30), dy2 = (y - cy) / (h * 0.16);
                double d2 = dx * dx + dy2 * dy2;
                double t2 = d2 > 1.0 ? 1.0 : d2;
                r = (int)(40 + 200 * (1.0 - t2));
                g = (int)(60 + 150 * (1.0 - t2) * fx);
                b = (int)(90 + 160 * t2);
            }
            p[0] = (BYTE)iclamp(b, 0, 255);
            p[1] = (BYTE)iclamp(g, 0, 255);
            p[2] = (BYTE)iclamp(r, 0, 255);
            p[3] = 255;
        }
    }
    im->srcfmt = F_UNKNOWN; im->srcdepth = 32; im->mode = M_32ARGB;
    return hnd;
}

}  /* extern "C" */
