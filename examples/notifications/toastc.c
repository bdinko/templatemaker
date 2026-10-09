/* ============================================================================
 *  toastc.c - Windows notifications (toasts) for Clarion, with no DLL.
 *
 *  Shows real Windows 10/11 notifications - the ones that slide in at the
 *  bottom-right and stay in the notification centre - from a Clarion program.
 *  It drives the WinRT API Windows.UI.Notifications directly through raw COM
 *  vtables, so there is nothing to ship and nothing to register as COM:
 *
 *    combase.dll   RoInitialize / RoGetActivationFactory / RoActivateInstance
 *                  WindowsCreateString / WindowsDeleteString / ...GetStringRawBuffer
 *    advapi32.dll  RegCreateKeyExA / RegSetValueExA / RegCloseKey / RegDeleteKeyA
 *
 *  both bound at run time with LoadLibrary + GetProcAddress.
 *
 *  An unpackaged desktop program needs an AppUserModelID that Windows knows
 *  the display name and icon of. toastc_init writes it under
 *  HKCU\Software\Classes\AppUserModelId\<id> (per user, no admin, no Start
 *  menu shortcut) and creates the notifier for that id.
 *
 *  Events (body clicked, button clicked, reply typed, dismissed, failed) are
 *  raised by Windows on a thread-pool thread. The handlers here are agile and
 *  only copy what they need into a small queue under a critical section; the
 *  Clarion program drains it from its own thread (toastc_next) - nothing in
 *  here ever calls back into the Clarion run-time.
 *
 *  Compiled by Clarion's own C++ compiler (Clacpp) via PRAGMA('compile(...)')
 *  in NotificationClass.clw. Clacpp has no Windows SDK headers and spells the
 *  stdcall convention `pascal`, so the Win32/WinRT surface is declared by hand
 *  below. Vtable slot numbers come from the Windows SDK 10.0.26100 headers;
 *  every WinRT interface starts at slot 6 (IUnknown 0-2, IInspectable 3-5).
 *
 *  Strings cross the boundary as ANSI (the program's code page, CP_ACP by
 *  default - toastc_codepage changes it, 65001 = UTF-8).
 * ========================================================================== */

#define WINAPI pascal
typedef unsigned long  DWORD;
typedef long           HRESULT;
typedef int            BOOL;
typedef unsigned int   UINT;
typedef unsigned short WCHAR;
typedef unsigned char  BYTE;
typedef void*          HMODULE;
typedef void*          HKEY;
typedef void*          HSTRING;
typedef int (WINAPI *FARPROC)();
typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3; unsigned char Data4[8]; } GUID;
typedef struct { void* DebugInfo; long LockCount; long RecursionCount; void* OwningThread; void* LockSemaphore; unsigned long SpinCount; } CRITICAL_SECTION;
typedef struct { unsigned long lo; unsigned long hi; } TOKEN64;   /* EventRegistrationToken (INT64) */

#define CP_ACP 0
#define LPTR   0x0040
#define S_OK   0
#define E_NOINTERFACE ((HRESULT)0x80004002L)
#define E_FAIL        ((HRESULT)0x80004005L)
#define HKCU   ((HKEY)0x80000001UL)
#define KEY_ALL_ACCESS 0xF003F
#define REG_SZ 1

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);
int     WINAPI MultiByteToWideChar(UINT, DWORD, const char*, int, WCHAR*, int);
int     WINAPI WideCharToMultiByte(UINT, DWORD, const WCHAR*, int, char*, int, const char*, BOOL*);
void*   WINAPI LocalAlloc(UINT, unsigned long);
void*   WINAPI LocalFree(void*);
void    WINAPI InitializeCriticalSection(CRITICAL_SECTION*);
void    WINAPI EnterCriticalSection(CRITICAL_SECTION*);
void    WINAPI LeaveCriticalSection(CRITICAL_SECTION*);
long    WINAPI InterlockedIncrement(long*);
long    WINAPI InterlockedDecrement(long*);
DWORD   WINAPI TlsAlloc(void);
void*   WINAPI TlsGetValue(DWORD);
BOOL    WINAPI TlsSetValue(DWORD, void*);
DWORD   WINAPI GetFullPathNameA(const char*, DWORD, char*, char**);
DWORD   WINAPI GetFileAttributesA(const char*);
void*   WINAPI CreateFileA(const char*, DWORD, DWORD, void*, DWORD, DWORD, void*);
BOOL    WINAPI ReadFile(void*, void*, DWORD, DWORD*, void*);
DWORD   WINAPI GetFileSize(void*, DWORD*);
BOOL    WINAPI CloseHandle(void*);
DWORD   WINAPI GetModuleFileNameA(HMODULE, char*, DWORD);
BOOL    WINAPI IsIconic(void*);
BOOL    WINAPI ShowWindow(void*, int);
BOOL    WINAPI SetForegroundWindow(void*);
BOOL    WINAPI BringWindowToTop(void*);
BOOL    WINAPI FlashWindow(void*, BOOL);

/* ---- run-time bound entry points ------------------------------------------ */
typedef HRESULT (WINAPI *PFN_RoInitialize)(int);
typedef HRESULT (WINAPI *PFN_RoGetActivationFactory)(HSTRING, const GUID*, void**);
typedef HRESULT (WINAPI *PFN_RoActivateInstance)(HSTRING, void**);
typedef HRESULT (WINAPI *PFN_WindowsCreateString)(const WCHAR*, UINT, HSTRING*);
typedef HRESULT (WINAPI *PFN_WindowsDeleteString)(HSTRING);
typedef const WCHAR* (WINAPI *PFN_WindowsGetStringRawBuffer)(HSTRING, UINT*);
typedef long (WINAPI *PFN_RegCreateKeyExA)(HKEY, const char*, DWORD, char*, DWORD, DWORD, void*, HKEY*, DWORD*);
typedef long (WINAPI *PFN_RegSetValueExA)(HKEY, const char*, DWORD, DWORD, const BYTE*, DWORD);
typedef long (WINAPI *PFN_RegCloseKey)(HKEY);
typedef long (WINAPI *PFN_RegDeleteKeyA)(HKEY, const char*);
typedef long (WINAPI *PFN_RegOpenKeyExA)(HKEY, const char*, DWORD, DWORD, HKEY*);
typedef long (WINAPI *PFN_RegQueryValueExA)(HKEY, const char*, DWORD*, DWORD*, BYTE*, DWORD*);
typedef HRESULT (WINAPI *PFN_SetAppId)(const WCHAR*);

static PFN_RoInitialize              pRoInitialize;
static PFN_RoGetActivationFactory    pRoGetActivationFactory;
static PFN_RoActivateInstance        pRoActivateInstance;
static PFN_WindowsCreateString       pWindowsCreateString;
static PFN_WindowsDeleteString       pWindowsDeleteString;
static PFN_WindowsGetStringRawBuffer pWindowsGetStringRawBuffer;
static PFN_RegCreateKeyExA           pRegCreateKeyExA;
static PFN_RegSetValueExA            pRegSetValueExA;
static PFN_RegCloseKey               pRegCloseKey;
static PFN_RegDeleteKeyA             pRegDeleteKeyA;
static PFN_RegOpenKeyExA             pRegOpenKeyExA;
static PFN_RegQueryValueExA          pRegQueryValueExA;

/* ---- generic vtable calls ---------------------------------------------------- */
#define VT(o, i) ((*(void***)(o))[i])
typedef HRESULT (WINAPI *F_QI)(void*, const GUID*, void**);
typedef unsigned long (WINAPI *F_REL)(void*);
typedef HRESULT (WINAPI *F_P)(void*, void*);
typedef HRESULT (WINAPI *F_PP)(void*, void*, void*);
typedef HRESULT (WINAPI *F_PPP)(void*, void*, void*, void*);
typedef HRESULT (WINAPI *F_PPPP)(void*, void*, void*, void*, void*);
typedef HRESULT (WINAPI *F_I)(void*, int);
typedef HRESULT (WINAPI *F_U)(void*, unsigned long);

static HRESULT QI(void* o, const GUID* iid, void** out) { *out = 0; return ((F_QI)VT(o, 0))(o, iid, out); }
static void    REL(void* o) { if (o) ((F_REL)VT(o, 2))(o); }
static void    ADDREF(void* o) { if (o) ((F_REL)VT(o, 1))(o); }

/* ---- interface ids (Windows SDK 10.0.26100) ----------------------------------- */
static const GUID IID_IUnknown        = {0x00000000,0x0000,0x0000,{0xC0,0x00,0x00,0x00,0x00,0x00,0x00,0x46}};
static const GUID IID_IAgileObject    = {0x94ea2b94,0xe9cc,0x49e0,{0xc0,0xff,0xee,0x64,0xca,0x8f,0x5b,0x90}};
static const GUID IID_IToastNotificationManagerStatics  = {0x50ac103f,0xd235,0x4598,{0xbb,0xef,0x98,0xfe,0x4d,0x1a,0x3a,0xd4}};
static const GUID IID_IToastNotificationManagerStatics2 = {0x7ab93c52,0x0e48,0x4750,{0xba,0x9d,0x1a,0x41,0x13,0x98,0x18,0x47}};
static const GUID IID_IToastNotifier2          = {0x354389c6,0x7c01,0x4bd5,{0x9c,0x20,0x60,0x43,0x40,0xcd,0x2b,0x74}};
static const GUID IID_IToastNotificationFactory = {0x04124b20,0x82c6,0x4229,{0xb1,0x09,0xfd,0x9e,0xd4,0x66,0x2b,0x53}};
static const GUID IID_IToastNotification2      = {0x9dfb9fd1,0x143a,0x490e,{0x90,0xbf,0xb9,0xfb,0xa7,0x13,0x2d,0xe7}};
static const GUID IID_IToastNotification4      = {0x15154935,0x28ea,0x4727,{0x88,0xe9,0xc5,0x86,0x80,0xe2,0xd1,0x18}};
static const GUID IID_IToastActivatedEventArgs  = {0xe3bf92f3,0xc197,0x436f,{0x82,0x65,0x06,0x25,0x82,0x4f,0x8d,0xac}};
static const GUID IID_IToastActivatedEventArgs2 = {0xab7da512,0xcc61,0x568e,{0x81,0xbe,0x30,0x4a,0xc3,0x10,0x38,0xfa}};
static const GUID IID_INotificationData        = {0x9ffd2312,0x9d6a,0x4aaf,{0xb6,0xac,0xff,0x17,0xf0,0xc1,0xf2,0x80}};
static const GUID IID_IXmlDocument             = {0xf7f3a506,0x1e87,0x42d6,{0xbc,0xfb,0xb8,0xc8,0x09,0xfa,0x54,0x94}};
static const GUID IID_IXmlDocumentIO           = {0x6cd0e74e,0xee65,0x4489,{0x9e,0xbf,0xca,0x43,0xe8,0x7b,0xa6,0x37}};
static const GUID IID_IPropertyValue           = {0x4bd682dd,0x7554,0x40e9,{0x9a,0x9b,0x82,0x65,0x4e,0xde,0x7e,0x62}};
static const GUID IID_IMap_String_Object       = {0x1b0d3570,0x0877,0x5ec2,{0x8a,0x2c,0x3b,0x95,0x39,0x50,0x6a,0xca}};
/* TypedEventHandler<ToastNotification, X> - parameterised ids, computed with WinRT.GuidGenerator */
static const GUID IID_ActivatedHandler = {0xab54de2d,0x97d9,0x5528,{0xb6,0xad,0x10,0x5a,0xfe,0x15,0x65,0x30}};
static const GUID IID_DismissedHandler = {0x61c2402f,0x0ed0,0x5a18,{0xab,0x69,0x59,0xf4,0xaa,0x99,0xa3,0x68}};
static const GUID IID_FailedHandler    = {0x95e3e803,0xc969,0x5e3a,{0x97,0x53,0xea,0x2a,0xd2,0x2a,0x9a,0x33}};

static int SameGuid(const GUID* a, const GUID* b)
{
    const unsigned char* x = (const unsigned char*)a;
    const unsigned char* y = (const unsigned char*)b;
    int i;
    for (i = 0; i < 16; i++) if (x[i] != y[i]) return 0;
    return 1;
}

/* ---- state -------------------------------------------------------------------- */
#define TC_MAXTOAST 64
#define TC_MAXEVENT 64
#define TC_ARGCAP   2048

typedef struct {
    int     id;            /* 0 = free slot */
    void*   toast;         /* IToastNotification* (AddRef'd) */
    void*   handlers[3];
    TOKEN64 tokens[3];
    char    tag[65];
    char    group[65];
} ToastSlot;

typedef struct {
    int     kind;          /* 1 activated, 2 dismissed, 3 failed */
    int     id;
    int     reason;        /* dismissed: 0 user, 1 app hid it, 2 timed out */
    HRESULT hr;            /* failed: the error */
    WCHAR   args[TC_ARGCAP];
    void*   inputs;        /* IMap<HSTRING,IInspectable>* of the user input, or 0 */
} ToastEvent;

static CRITICAL_SECTION gLock;
static int        gReady;          /* bindings + lock made */
static int        gInited;         /* notifier exists */
static DWORD      gTls = 0xFFFFFFFF;
static UINT       gCp = CP_ACP;
static void*      gManager;        /* IToastNotificationManagerStatics* */
static void*      gFactory;        /* IToastNotificationFactory* */
static void*      gNotifier;       /* IToastNotifier* */
static WCHAR      gAppId[260];
static ToastSlot  gSlots[TC_MAXTOAST];
static int        gNextId;
static ToastEvent gQueue[TC_MAXEVENT];
static int        gHead, gCount;
static ToastEvent gCur;            /* the event last taken by toastc_next */
static long       gLastHr;
static int        gLastStage;

/* last_stage codes: 1 bind, 2 apartment, 3 manager, 4 notifier, 5 xml, 6 create,
   7 tag, 8 data, 9 show, 10 update, 11 history, 12 registry */
static void Fail(int stage, HRESULT hr) { gLastStage = stage; gLastHr = hr; }

static int Bind(void)
{
    HMODULE cb, adv;
    if (gReady) return 1;
    cb = LoadLibraryA("combase.dll");
    adv = LoadLibraryA("advapi32.dll");
    if (!cb || !adv) { Fail(1, E_FAIL); return 0; }
    pRoInitialize              = (PFN_RoInitialize)GetProcAddress(cb, "RoInitialize");
    pRoGetActivationFactory    = (PFN_RoGetActivationFactory)GetProcAddress(cb, "RoGetActivationFactory");
    pRoActivateInstance        = (PFN_RoActivateInstance)GetProcAddress(cb, "RoActivateInstance");
    pWindowsCreateString       = (PFN_WindowsCreateString)GetProcAddress(cb, "WindowsCreateString");
    pWindowsDeleteString       = (PFN_WindowsDeleteString)GetProcAddress(cb, "WindowsDeleteString");
    pWindowsGetStringRawBuffer = (PFN_WindowsGetStringRawBuffer)GetProcAddress(cb, "WindowsGetStringRawBuffer");
    pRegCreateKeyExA           = (PFN_RegCreateKeyExA)GetProcAddress(adv, "RegCreateKeyExA");
    pRegSetValueExA            = (PFN_RegSetValueExA)GetProcAddress(adv, "RegSetValueExA");
    pRegCloseKey               = (PFN_RegCloseKey)GetProcAddress(adv, "RegCloseKey");
    pRegDeleteKeyA             = (PFN_RegDeleteKeyA)GetProcAddress(adv, "RegDeleteKeyA");
    pRegOpenKeyExA             = (PFN_RegOpenKeyExA)GetProcAddress(adv, "RegOpenKeyExA");
    pRegQueryValueExA          = (PFN_RegQueryValueExA)GetProcAddress(adv, "RegQueryValueExA");
    if (!pRoInitialize || !pRoGetActivationFactory || !pRoActivateInstance || !pWindowsCreateString ||
        !pWindowsDeleteString || !pWindowsGetStringRawBuffer || !pRegCreateKeyExA || !pRegSetValueExA ||
        !pRegCloseKey || !pRegDeleteKeyA || !pRegOpenKeyExA || !pRegQueryValueExA) { Fail(1, E_FAIL); return 0; }
    InitializeCriticalSection(&gLock);
    gTls = TlsAlloc();
    gReady = 1;
    return 1;
}

/* Every Clarion thread that calls in needs a COM apartment. Single-threaded,
   so a later OleInitialize by the Clarion run-time (OLE controls) still works;
   the event handlers below are agile, so Windows calls them directly. */
static void Apartment(void)
{
    if (gTls != 0xFFFFFFFF && TlsGetValue(gTls)) return;
    pRoInitialize(0);              /* S_OK, S_FALSE or RPC_E_CHANGED_MODE: all usable */
    if (gTls != 0xFFFFFFFF) TlsSetValue(gTls, (void*)1);
}

/* ---- strings ------------------------------------------------------------------ */
static WCHAR* Wide(const char* s)
{
    int n;
    WCHAR* w;
    if (!s) s = "";
    n = MultiByteToWideChar(gCp, 0, s, -1, 0, 0);
    if (n <= 0) n = 1;
    w = (WCHAR*)LocalAlloc(LPTR, (unsigned long)(n + 1) * 2);
    if (w) MultiByteToWideChar(gCp, 0, s, -1, w, n);
    return w;
}

static HSTRING HStr(const char* s)
{
    HSTRING h = 0;
    WCHAR* w = Wide(s);
    UINT n = 0;
    if (!w) return 0;
    while (w[n]) n++;
    pWindowsCreateString(w, n, &h);
    LocalFree(w);
    return h;
}

static HSTRING HStrW(const WCHAR* w)
{
    HSTRING h = 0;
    UINT n = 0;
    while (w[n]) n++;
    pWindowsCreateString(w, n, &h);
    return h;
}

static void HFree(HSTRING h) { if (h) pWindowsDeleteString(h); }

/* Copy a wide string out to an ANSI buffer. Returns the length, or -(needed)
   when the buffer is too small so the Clarion side can grow and retry. */
static int Narrow(const WCHAR* w, int wlen, char* out, int cap)
{
    int need;
    if (!w || wlen == 0) { if (cap > 0) out[0] = 0; return 0; }
    need = WideCharToMultiByte(gCp, 0, w, wlen, 0, 0, 0, 0);
    if (need + 1 > cap) { if (cap > 0) out[0] = 0; return -(need + 1); }
    WideCharToMultiByte(gCp, 0, w, wlen, out, cap, 0, 0);
    out[need] = 0;
    return need;
}

static void CopyW(WCHAR* dst, int cap, const WCHAR* src, UINT n)
{
    UINT i;
    if (n > (UINT)(cap - 1)) n = (UINT)(cap - 1);
    for (i = 0; i < n; i++) dst[i] = src[i];
    dst[n] = 0;
}

static void CopyA(char* dst, int cap, const char* src)
{
    int i = 0;
    if (src) while (src[i] && i < cap - 1) { dst[i] = src[i]; i++; }
    dst[i] = 0;
}

static int SameA(const char* a, const char* b)
{
    if (!a) a = "";
    if (!b) b = "";
    while (*a && *a == *b) { a++; b++; }
    return *a == *b;
}

/* ---- the event handler object ---------------------------------------------------
   One per toast per event kind. Agile (free-threaded): Invoke copies what it
   needs into the queue under the lock and returns. */
typedef struct {
    void** vtbl;
    long   refs;
    int    kind;
    int    id;
} Handler;

static HRESULT WINAPI H_QueryInterface(void* self, const GUID* iid, void** out)
{
    Handler* h = (Handler*)self;
    const GUID* mine = h->kind == 1 ? &IID_ActivatedHandler : h->kind == 2 ? &IID_DismissedHandler : &IID_FailedHandler;
    if (SameGuid(iid, &IID_IUnknown) || SameGuid(iid, &IID_IAgileObject) || SameGuid(iid, mine)) {
        *out = self;
        InterlockedIncrement(&h->refs);
        return S_OK;
    }
    *out = 0;
    return E_NOINTERFACE;
}

static unsigned long WINAPI H_AddRef(void* self)
{
    return (unsigned long)InterlockedIncrement(&((Handler*)self)->refs);
}

static unsigned long WINAPI H_Release(void* self)
{
    long n = InterlockedDecrement(&((Handler*)self)->refs);
    if (n == 0) LocalFree(self);
    return (unsigned long)n;
}

static ToastEvent* QueueSlot(void)   /* caller holds the lock */
{
    ToastEvent* e;
    if (gCount == TC_MAXEVENT) {   /* full: drop the oldest */
        e = &gQueue[gHead];
        if (e->inputs) REL(e->inputs);
        e->inputs = 0;
        gHead = (gHead + 1) % TC_MAXEVENT;
        gCount--;
    }
    e = &gQueue[(gHead + gCount) % TC_MAXEVENT];
    gCount++;
    e->kind = 0; e->id = 0; e->reason = 0; e->hr = 0; e->args[0] = 0; e->inputs = 0;
    return e;
}

static HRESULT WINAPI H_Invoke(void* self, void* sender, void* args)
{
    Handler* h = (Handler*)self;
    ToastEvent* e;
    void* a1 = 0;
    void* a2 = 0;
    void* set = 0;
    void* map = 0;
    HSTRING hs = 0;
    const WCHAR* raw = 0;
    UINT len = 0;
    int reason = 0;
    HRESULT code = 0;

    if (h->kind == 1 && args) {
        if (QI(args, &IID_IToastActivatedEventArgs, &a1) == S_OK) {
            if (((F_P)VT(a1, 6))(a1, &hs) == S_OK && hs) raw = pWindowsGetStringRawBuffer(hs, &len);
        }
        if (QI(args, &IID_IToastActivatedEventArgs2, &a2) == S_OK) {
            if (((F_P)VT(a2, 6))(a2, &set) == S_OK && set) {
                QI(set, &IID_IMap_String_Object, &map);
                REL(set);
            }
        }
    } else if (h->kind == 2 && args) {
        ((F_P)VT(args, 6))(args, &reason);        /* IToastDismissedEventArgs.get_Reason */
    } else if (h->kind == 3 && args) {
        ((F_P)VT(args, 6))(args, &code);          /* IToastFailedEventArgs.get_ErrorCode */
    }

    EnterCriticalSection(&gLock);
    e = QueueSlot();
    e->kind = h->kind;
    e->id = h->id;
    e->reason = reason;
    e->hr = code;
    if (raw) CopyW(e->args, TC_ARGCAP, raw, len);
    e->inputs = map;
    LeaveCriticalSection(&gLock);

    HFree(hs);
    REL(a1);
    REL(a2);
    return S_OK;
}

static void* gHandlerVtbl[4] = { (void*)H_QueryInterface, (void*)H_AddRef, (void*)H_Release, (void*)H_Invoke };

static Handler* NewHandler(int kind, int id)
{
    Handler* h = (Handler*)LocalAlloc(LPTR, sizeof(Handler));
    if (!h) return 0;
    h->vtbl = gHandlerVtbl;
    h->refs = 1;
    h->kind = kind;
    h->id = id;
    return h;
}

/* ---- toast slots --------------------------------------------------------------- */
static void FreeSlot(ToastSlot* s)    /* caller holds the lock */
{
    int k;
    if (!s->id) return;
    for (k = 0; k < 3; k++) {
        if (s->handlers[k] && s->toast) {
            /* remove_Dismissed 10, remove_Activated 12, remove_Failed 14 take the token by value (INT64) */
            typedef HRESULT (WINAPI *F_TOK)(void*, unsigned long, unsigned long);
            int slot = k == 0 ? 12 : k == 1 ? 10 : 14;
            ((F_TOK)VT(s->toast, slot))(s->toast, s->tokens[k].lo, s->tokens[k].hi);
        }
        REL(s->handlers[k]);
        s->handlers[k] = 0;
    }
    REL(s->toast);
    s->toast = 0;
    s->id = 0;
    s->tag[0] = 0;
    s->group[0] = 0;
}

static ToastSlot* SlotFor(int id)
{
    int i;
    for (i = 0; i < TC_MAXTOAST; i++) if (gSlots[i].id == id && id) return &gSlots[i];
    return 0;
}

static ToastSlot* TakeSlot(void)      /* caller holds the lock; recycles the oldest */
{
    int i, best = 0;
    for (i = 0; i < TC_MAXTOAST; i++) if (!gSlots[i].id) return &gSlots[i];
    for (i = 1; i < TC_MAXTOAST; i++) if (gSlots[i].id < gSlots[best].id) best = i;
    FreeSlot(&gSlots[best]);
    return &gSlots[best];
}

/* ---- NotificationData from "key=value" lines ------------------------------------ */
static void* MakeData(const char* pairs, unsigned long seq)
{
    HSTRING cls = HStr("Windows.UI.Notifications.NotificationData");
    void* insp = 0;
    void* data = 0;
    void* values = 0;
    HRESULT hr = pRoActivateInstance(cls, &insp);
    HFree(cls);
    if (hr != S_OK || !insp) { Fail(8, hr); return 0; }
    hr = QI(insp, &IID_INotificationData, &data);
    REL(insp);
    if (hr != S_OK) { Fail(8, hr); return 0; }
    if (((F_P)VT(data, 6))(data, &values) == S_OK && values && pairs) {
        /* IMap<HSTRING,HSTRING>.Insert is slot 10 */
        const char* p = pairs;
        char key[256];
        char* val;
        int kn, vn;
        while (*p) {
            const char* eol = p;
            const char* eq = 0;
            while (*eol && *eol != '\n' && *eol != '\r') { if (!eq && *eol == '=') eq = eol; eol++; }
            if (eq && eq > p && eq - p < 255) {
                kn = (int)(eq - p);
                CopyA(key, kn + 1, p);
                vn = (int)(eol - eq - 1);
                val = (char*)LocalAlloc(LPTR, (unsigned long)vn + 1);
                if (val) {
                    HSTRING hk, hv;
                    BYTE replaced = 0;
                    CopyA(val, vn + 1, eq + 1);
                    hk = HStr(key);
                    hv = HStr(val);
                    ((F_PPP)VT(values, 10))(values, hk, hv, &replaced);
                    HFree(hk);
                    HFree(hv);
                    LocalFree(val);
                }
            }
            p = eol;
            while (*p == '\n' || *p == '\r') p++;
        }
    }
    REL(values);
    ((F_U)VT(data, 8))(data, seq);           /* put_SequenceNumber */
    return data;
}

/* ================================================================================
 *  The API Clarion calls
 * ================================================================================ */

int toastc_codepage(int cp) { gCp = (UINT)cp; return 1; }

/* Register the AppUserModelID for the current user and create the notifier.
   iconPath may be '' (Windows then uses a generic icon); a relative path is made
   absolute. Returns 1, or 0 with toastc_last_error/stage set. */
int toastc_init(const char* appId, const char* displayName, const char* iconPath, const char* iconBack)
{
    HSTRING cls = 0, id = 0;
    HRESULT hr;
    char key[400];
    char full[520];
    HKEY hk = 0;
    if (!Bind()) return 0;
    Apartment();
    if (!appId || !appId[0]) { Fail(4, E_FAIL); return 0; }

    /* HKCU\Software\Classes\AppUserModelId\<id>: DisplayName, IconUri, IconBackgroundColor */
    CopyA(key, sizeof(key), "Software\\Classes\\AppUserModelId\\");
    { int n = 0; while (key[n]) n++; CopyA(key + n, (int)sizeof(key) - n, appId); }
    if (pRegCreateKeyExA(HKCU, key, 0, 0, 0, KEY_ALL_ACCESS, 0, &hk, 0) == 0) {
        const char* dn = (displayName && displayName[0]) ? displayName : appId;
        int n = 0;
        while (dn[n]) n++;
        pRegSetValueExA(hk, "DisplayName", 0, REG_SZ, (const BYTE*)dn, (DWORD)n + 1);
        if (iconPath && iconPath[0]) {
            full[0] = 0;
            GetFullPathNameA(iconPath, sizeof(full), full, 0);
            n = 0;
            while (full[n]) n++;
            if (n) pRegSetValueExA(hk, "IconUri", 0, REG_SZ, (const BYTE*)full, (DWORD)n + 1);
        }
        if (iconBack && iconBack[0]) {
            n = 0;
            while (iconBack[n]) n++;
            pRegSetValueExA(hk, "IconBackgroundColor", 0, REG_SZ, (const BYTE*)iconBack, (DWORD)n + 1);
        }
        pRegCloseKey(hk);
    } else {
        Fail(12, E_FAIL);       /* not fatal: Windows may still know the id */
    }

    EnterCriticalSection(&gLock);
    if (gNotifier) { REL(gNotifier); gNotifier = 0; }
    if (!gManager) {
        cls = HStr("Windows.UI.Notifications.ToastNotificationManager");
        hr = pRoGetActivationFactory(cls, &IID_IToastNotificationManagerStatics, &gManager);
        HFree(cls);
        if (hr != S_OK) { gManager = 0; LeaveCriticalSection(&gLock); Fail(3, hr); return 0; }
    }
    if (!gFactory) {
        cls = HStr("Windows.UI.Notifications.ToastNotification");
        hr = pRoGetActivationFactory(cls, &IID_IToastNotificationFactory, &gFactory);
        HFree(cls);
        if (hr != S_OK) { gFactory = 0; LeaveCriticalSection(&gLock); Fail(3, hr); return 0; }
    }
    {
        WCHAR* w = Wide(appId);
        UINT n = 0;
        if (w) { while (w[n]) n++; CopyW(gAppId, 260, w, n); LocalFree(w); }
    }
    id = HStrW(gAppId);
    hr = ((F_PP)VT(gManager, 7))(gManager, id, &gNotifier);   /* CreateToastNotifierWithId */
    HFree(id);
    if (hr != S_OK) { gNotifier = 0; LeaveCriticalSection(&gLock); Fail(4, hr); return 0; }
    gInited = 1;
    LeaveCriticalSection(&gLock);
    return 1;
}

/* Remove the per-user registration (uninstall). */
int toastc_unregister(const char* appId)
{
    char key[400];
    int n = 0;
    if (!Bind()) return 0;
    CopyA(key, sizeof(key), "Software\\Classes\\AppUserModelId\\");
    while (key[n]) n++;
    CopyA(key + n, (int)sizeof(key) - n, appId);
    return pRegDeleteKeyA(HKCU, key) == 0 ? 1 : 0;
}

/* A DWORD under HKCU, or -1 when it is not there. */
static long RegDword(const char* key, const char* name)
{
    HKEY hk = 0;
    DWORD v = 0, type = 0, size = 4;
    long r = -1;
    if (pRegOpenKeyExA(HKCU, key, 0, 0x20019 /* KEY_READ */, &hk) != 0) return -1;
    if (pRegQueryValueExA(hk, name, 0, &type, (BYTE*)&v, &size) == 0 && type == 4 /* REG_DWORD */) r = (long)v;
    pRegCloseKey(hk);
    return r;
}

/* 0 enabled, 1 off for this app, 2 off for this user, 3 off by policy, 4 off by manifest.
   Windows will not answer get_Setting for an unpackaged program, so the two switches
   Settings > System > Notifications writes are read instead. */
int toastc_setting(void)
{
    int s = -1;
    char key[400];
    int n = 0;
    if (!gInited) return -1;
    Apartment();
    if (((F_P)VT(gNotifier, 8))(gNotifier, &s) == S_OK) return s;
    if (RegDword("Software\\Policies\\Microsoft\\Windows\\CurrentVersion\\PushNotifications", "NoToastApplicationNotification") == 1) return 3;
    if (RegDword("Software\\Microsoft\\Windows\\CurrentVersion\\PushNotifications", "ToastEnabled") == 0) return 2;
    CopyA(key, sizeof(key), "Software\\Microsoft\\Windows\\CurrentVersion\\Notifications\\Settings\\");
    while (key[n]) n++;
    { int i = 0; while (gAppId[i] && n < (int)sizeof(key) - 1) key[n++] = (char)gAppId[i++]; key[n] = 0; }
    if (RegDword(key, "Enabled") == 0) return 1;
    return 0;
}

/* Show a notification from toast XML. tag/group may be '' (tag max 64 chars).
   data = "key=value" lines for {bindings} (progress bars), seq its sequence number.
   silent = 1 puts it straight into the notification centre without the pop-up.
   Returns the toast id (> 0), or 0 on failure. */
int toastc_show(const char* xml, const char* tag, const char* group, const char* data, unsigned long seq, int silent)
{
    HSTRING cls = 0, hx = 0, h = 0;
    void* insp = 0;
    void* io = 0;
    void* doc = 0;
    void* toast = 0;
    void* t2 = 0;
    void* t4 = 0;
    void* nd = 0;
    ToastSlot* s;
    HRESULT hr;
    int id, k;

    if (!gInited) { Fail(4, E_FAIL); return 0; }
    Apartment();

    cls = HStr("Windows.Data.Xml.Dom.XmlDocument");
    hr = pRoActivateInstance(cls, &insp);
    HFree(cls);
    if (hr != S_OK) { Fail(5, hr); return 0; }
    QI(insp, &IID_IXmlDocumentIO, &io);
    QI(insp, &IID_IXmlDocument, &doc);
    REL(insp);
    if (!io || !doc) { REL(io); REL(doc); Fail(5, E_NOINTERFACE); return 0; }
    hx = HStr(xml);
    hr = ((F_P)VT(io, 6))(io, hx);                              /* LoadXml */
    HFree(hx);
    REL(io);
    if (hr != S_OK) { REL(doc); Fail(5, hr); return 0; }

    hr = ((F_PP)VT(gFactory, 6))(gFactory, doc, &toast);        /* CreateToastNotification */
    REL(doc);
    if (hr != S_OK || !toast) { Fail(6, hr); return 0; }

    if ((tag && tag[0]) || (group && group[0]) || silent) {
        if (QI(toast, &IID_IToastNotification2, &t2) == S_OK) {
            if (tag && tag[0])     { h = HStr(tag);   hr = ((F_P)VT(t2, 6))(t2, h); HFree(h); if (hr != S_OK) Fail(7, hr); }
            if (group && group[0]) { h = HStr(group); hr = ((F_P)VT(t2, 8))(t2, h); HFree(h); if (hr != S_OK) Fail(7, hr); }
            if (silent) ((F_I)VT(t2, 10))(t2, 1);              /* put_SuppressPopup */
            REL(t2);
        }
    }
    if (data && data[0]) {
        nd = MakeData(data, seq);
        if (nd && QI(toast, &IID_IToastNotification4, &t4) == S_OK) {
            ((F_P)VT(t4, 7))(t4, nd);                            /* put_Data */
            REL(t4);
        }
        REL(nd);
    }

    EnterCriticalSection(&gLock);
    id = ++gNextId;
    s = TakeSlot();
    s->id = id;
    s->toast = toast;
    CopyA(s->tag, 65, tag);
    CopyA(s->group, 65, group);
    for (k = 0; k < 3; k++) {
        int kind = k + 1;                                        /* 1 activated, 2 dismissed, 3 failed */
        int slot = k == 0 ? 11 : k == 1 ? 9 : 13;                /* add_Activated / add_Dismissed / add_Failed */
        s->handlers[k] = NewHandler(kind, id);
        s->tokens[k].lo = 0;
        s->tokens[k].hi = 0;
        if (s->handlers[k]) ((F_PP)VT(toast, slot))(toast, s->handlers[k], &s->tokens[k]);
    }
    LeaveCriticalSection(&gLock);

    hr = ((F_P)VT(gNotifier, 6))(gNotifier, toast);             /* Show */
    if (hr != S_OK) {
        EnterCriticalSection(&gLock);
        FreeSlot(s);
        LeaveCriticalSection(&gLock);
        Fail(9, hr);
        return 0;
    }
    return id;
}

/* Update the {bindings} of a toast already shown with that tag (and group).
   Returns 0 updated, 1 failed, 2 not found (gone from the notification centre), -1 error. */
int toastc_update(const char* tag, const char* group, const char* data, unsigned long seq)
{
    void* n2 = 0;
    void* nd;
    HSTRING ht, hg;
    HRESULT hr;
    int result = -1;
    if (!gInited) return -1;
    Apartment();
    if (QI(gNotifier, &IID_IToastNotifier2, &n2) != S_OK) { Fail(10, E_NOINTERFACE); return -1; }
    nd = MakeData(data, seq);
    if (!nd) { REL(n2); return -1; }
    ht = HStr(tag);
    if (group && group[0]) {
        hg = HStr(group);
        hr = ((F_PPPP)VT(n2, 6))(n2, nd, ht, hg, &result);      /* UpdateWithTagAndGroup */
        HFree(hg);
    } else {
        hr = ((F_PPP)VT(n2, 7))(n2, nd, ht, &result);           /* UpdateWithTag */
    }
    HFree(ht);
    REL(nd);
    REL(n2);
    if (hr != S_OK) { Fail(10, hr); return -1; }
    return result;
}

/* Take a toast off the screen and out of the notification centre, by id. */
int toastc_hide(int id)
{
    ToastSlot* s;
    void* t = 0;
    HRESULT hr;
    if (!gInited) return 0;
    Apartment();
    EnterCriticalSection(&gLock);
    s = SlotFor(id);
    if (s) { t = s->toast; ADDREF(t); }
    LeaveCriticalSection(&gLock);
    if (!t) return 0;
    hr = ((F_P)VT(gNotifier, 7))(gNotifier, t);                 /* Hide */
    REL(t);
    return hr == S_OK ? 1 : 0;
}

/* Remove from the notification centre: by tag (+group), a whole group (tag ''),
   or everything this program has shown (both ''). */
int toastc_remove(const char* tag, const char* group)
{
    void* m2 = 0;
    void* hist = 0;
    HSTRING ht = 0, hg = 0, ha = 0;
    HRESULT hr = E_FAIL;
    if (!gInited) return 0;
    Apartment();
    if (QI(gManager, &IID_IToastNotificationManagerStatics2, &m2) != S_OK) { Fail(11, E_NOINTERFACE); return 0; }
    ((F_P)VT(m2, 6))(m2, &hist);                                /* get_History */
    REL(m2);
    if (!hist) { Fail(11, E_FAIL); return 0; }
    ha = HStrW(gAppId);
    if (tag && tag[0]) {
        ht = HStr(tag);
        hg = HStr(group);
        hr = ((F_PPP)VT(hist, 8))(hist, ht, hg, ha);            /* RemoveGroupedTagWithId */
    } else if (group && group[0]) {
        hg = HStr(group);
        hr = ((F_PP)VT(hist, 7))(hist, hg, ha);                 /* RemoveGroupWithId */
    } else {
        hr = ((F_P)VT(hist, 12))(hist, ha);                     /* ClearWithId */
    }
    HFree(ht);
    HFree(hg);
    HFree(ha);
    REL(hist);
    if (hr != S_OK) { Fail(11, hr); return 0; }
    return 1;
}

/* Events waiting to be taken. */
int toastc_pending(void)
{
    int n;
    if (!gReady) return 0;
    EnterCriticalSection(&gLock);
    n = gCount;
    LeaveCriticalSection(&gLock);
    return n;
}

/* Take the next event. Returns its kind (1 activated, 2 dismissed, 3 failed) or 0. */
int toastc_next(int* id, int* reason, long* hr)
{
    int kind = 0;
    if (!gReady) return 0;
    EnterCriticalSection(&gLock);
    if (gCur.inputs) { REL(gCur.inputs); gCur.inputs = 0; }
    gCur.kind = 0;
    gCur.args[0] = 0;
    if (gCount) {
        gCur = gQueue[gHead];
        gQueue[gHead].inputs = 0;
        gHead = (gHead + 1) % TC_MAXEVENT;
        gCount--;
        kind = gCur.kind;
    }
    LeaveCriticalSection(&gLock);
    *id = gCur.id;
    *reason = gCur.reason;
    *hr = gCur.hr;
    return kind;
}

/* The arguments of the event last taken (launch="..." / arguments="..."). */
int toastc_args(char* out, int cap)
{
    int n = 0;
    while (gCur.args[n]) n++;
    return Narrow(gCur.args, n, out, cap);
}

/* The tag of the toast the last event came from. */
int toastc_tag(char* out, int cap)
{
    ToastSlot* s;
    EnterCriticalSection(&gLock);
    s = SlotFor(gCur.id);
    CopyA(out, cap, s ? s->tag : "");
    LeaveCriticalSection(&gLock);
    { int n = 0; while (out[n]) n++; return n; }
}

/* What the user typed or picked in input <id> of the event last taken.
   Returns the length, -2 if there is no such input, or -(needed) if cap is too small. */
int toastc_input(const char* inputId, char* out, int cap)
{
    HSTRING k, v = 0;
    void* val = 0;
    void* pv = 0;
    const WCHAR* raw;
    UINT len = 0;
    int r = -2;
    if (cap > 0) out[0] = 0;
    if (!gCur.inputs) return -2;
    Apartment();
    k = HStr(inputId);
    if (((F_PP)VT(gCur.inputs, 6))(gCur.inputs, k, &val) == S_OK && val) {   /* Lookup */
        if (QI(val, &IID_IPropertyValue, &pv) == S_OK) {
            if (((F_P)VT(pv, 19))(pv, &v) == S_OK) {                          /* GetString */
                raw = pWindowsGetStringRawBuffer(v, &len);
                r = Narrow(raw, (int)len, out, cap);
                HFree(v);
            }
            REL(pv);
        }
        REL(val);
    }
    HFree(k);
    return r;
}

int toastc_last_error(void) { return (int)gLastHr; }
int toastc_ready(void) { return gInited; }

/* The folder the program runs from, with no trailing backslash. */
int toastc_exefolder(char* out, int cap)
{
    DWORD n = GetModuleFileNameA(0, out, (DWORD)cap);
    if (n == 0 || (int)n >= cap) { if (cap > 0) out[0] = 0; return 0; }
    while (n > 0 && out[n - 1] != 92) n--;           /* back to the last backslash */
    if (n > 0) n--;
    out[n] = 0;
    return (int)n;
}
int toastc_last_stage(void) { return gLastStage; }

/* Release everything (end of program). Shown toasts stay in the notification centre. */
int toastc_kill(void)
{
    int i;
    if (!gReady) return 1;
    EnterCriticalSection(&gLock);
    for (i = 0; i < TC_MAXTOAST; i++) FreeSlot(&gSlots[i]);
    while (gCount) {
        if (gQueue[gHead].inputs) REL(gQueue[gHead].inputs);
        gQueue[gHead].inputs = 0;
        gHead = (gHead + 1) % TC_MAXEVENT;
        gCount--;
    }
    if (gCur.inputs) { REL(gCur.inputs); gCur.inputs = 0; }
    REL(gNotifier); gNotifier = 0;
    REL(gFactory);  gFactory = 0;
    REL(gManager);  gManager = 0;
    gInited = 0;
    LeaveCriticalSection(&gLock);
    return 1;
}

/* Bring a window forward after its notification was clicked. Windows lets the
   process that owns the clicked notification take the foreground; if it still
   says no, the taskbar button flashes instead. Returns 1 if it came forward. */
int toastc_front(long hwnd)
{
    void* h = (void*)hwnd;
    if (!h) return 0;
    if (IsIconic(h)) ShowWindow(h, 9);          /* SW_RESTORE */
    BringWindowToTop(h);
    if (SetForegroundWindow(h)) return 1;
    FlashWindow(h, 1);
    return 0;
}

/* Does a file exist? (used to resolve image paths) */
int toastc_exists(const char* path) { return GetFileAttributesA(path) != 0xFFFFFFFF ? 1 : 0; }

/* Read a whole file (a saved design). Returns its size, -(size+1) when cap is
   too small (grow and call again), or -1 if it cannot be opened. */
int toastc_readfile(const char* path, char* out, int cap)
{
    void* f = CreateFileA(path, 0x80000000UL /* GENERIC_READ */, 1 /* FILE_SHARE_READ */, 0, 3 /* OPEN_EXISTING */, 0x80, 0);
    DWORD size, got = 0;
    if (f == (void*)-1) return -1;
    size = GetFileSize(f, 0);
    if ((int)size + 1 > cap) { CloseHandle(f); return -((int)size + 1); }
    if (!ReadFile(f, out, size, &got, 0)) got = 0;
    CloseHandle(f);
    out[got] = 0;
    return (int)got;
}

/* Make a path absolute. */
int toastc_fullpath(const char* path, char* out, int cap)
{
    DWORD n = GetFullPathNameA(path, (DWORD)cap, out, 0);
    if (n == 0 || (int)n >= cap) { if (cap > 0) out[0] = 0; return n ? -(int)n : 0; }
    return (int)n;
}

} /* extern "C" */
