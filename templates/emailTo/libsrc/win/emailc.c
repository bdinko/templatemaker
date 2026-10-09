/* ==========================================================================
   emailc.c  -  the network layer for the emailTo Clarion template.

   Everything Clarion cannot do itself, and NOTHING else:

       * TCP sockets                (ws2_32.dll)
       * TLS 1.2 / 1.3 via SCHANNEL (secur32.dll)   - implicit TLS and STARTTLS
       * HTTPS requests             (winhttp.dll)   - OAuth2 + REST send
       * a one-shot loopback web server               - catches the OAuth redirect
       * DPAPI encrypt / decrypt    (crypt32.dll)   - at-rest secrets
       * SHA-256                    (ours)          - OAuth2 PKCE S256
       * cryptographic random       (advapi32.dll)  - PKCE verifier, MIME boundary
       * open the default browser   (shell32.dll)   - the OAuth consent screen

   MIME, base64, quoted-printable, the SMTP conversation, JSON and every
   provider preset are pure Clarion - see EmailMsgClass / EmailToClass.

   Compiled by the Clarion C compiler (Clacpp) through
       PRAGMA('compile(emailc.c)')
   in EmailNetClass.clw.  There is no import library and no redistributable:
   every DLL above is bound at run time with LoadLibrary/GetProcAddress, so a
   machine missing one gets a clean error code instead of a load failure.

   CLACPP RULES OBEYED HERE (each one cost somebody a day):
     - no <windows.h>: it does not ship with Clacpp.  Types and prototypes are
       hand-declared below.
     - __stdcall is spelled `pascal`.
     - the file is compiled as C++, so every void* conversion is an explicit
       cast.
     - there is no 64-bit integer type: 8-byte fields are struct{lo,hi}.
     - exported names get a leading underscore (cdecl), which is what the
       Clarion MAP NAME('_et_xxx') attribute expects.
   ========================================================================== */

#define WINAPI pascal
#define NULLP  0

typedef unsigned char  BYTE;
typedef unsigned short WORD;
typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef int            BOOL;
typedef void          *HMODULE;
typedef void          *HANDLE;
typedef unsigned int   SOCKET;
typedef unsigned short WCH;          /* a UTF-16 code unit; wchar_t is avoided */

#define INVALID_SOCKET  ((SOCKET)(~0))
#define SOCKET_ERROR    (-1)

/* -------------------------------------------------------------------------
   Error codes returned to Clarion.  Negative = failure, and every one is
   distinct so a support call can be diagnosed from the number alone.
   ------------------------------------------------------------------------- */
#define ET_OK               0
#define ET_E_NOWINSOCK     -1
#define ET_E_NOSECUR32     -2
#define ET_E_NOWINHTTP     -3
#define ET_E_RESOLVE       -4
#define ET_E_CONNECT       -5
#define ET_E_NOSLOT        -6
#define ET_E_BADID         -7
#define ET_E_SEND          -8
#define ET_E_RECV          -9
#define ET_E_CLOSED       -10
#define ET_E_TIMEOUT      -11
#define ET_E_CRED         -12
#define ET_E_HANDSHAKE    -13
#define ET_E_STREAMSIZES  -14
#define ET_E_ENCRYPT      -15
#define ET_E_DECRYPT      -16
#define ET_E_MEMORY       -17
#define ET_E_OVERFLOW     -18
#define ET_E_BADURL       -19
#define ET_E_HTTPOPEN     -20
#define ET_E_HTTPCONNECT  -21
#define ET_E_HTTPREQUEST  -22
#define ET_E_HTTPSEND     -23
#define ET_E_HTTPRECV     -24
#define ET_E_BIND         -25
#define ET_E_ACCEPT       -26
#define ET_E_NOCRYPT32    -27
#define ET_E_DPAPI        -28
#define ET_E_NOTTLS       -29
#define ET_E_ALREADYTLS   -30

/* =========================================================================
   1.  Dynamic binding.  kernel32 is resolved by the Clarion linker; every
       other DLL is loaded on first use so a missing one is an error code,
       not a failure to start the program.
   ========================================================================= */
extern "C" {
  HMODULE WINAPI LoadLibraryA(const char *name);
  void   *WINAPI GetProcAddress(HMODULE m, const char *name);
  int     WINAPI MultiByteToWideChar(UINT cp, DWORD f, const char *mb, int cb, WCH *wc, int cw);
  int     WINAPI WideCharToMultiByte(UINT cp, DWORD f, const WCH *wc, int cw, char *mb, int cb,
                                     const char *dflt, BOOL *used);
  void   *WINAPI LocalFree(void *p);
  DWORD   WINAPI GetTickCount(void);
  void    WINAPI Sleep(DWORD ms);
}

/* the C runtime bits we use - declared, never included */
extern "C" {
  void *malloc(unsigned int);
  void  free(void *);
  void *memcpy(void *, const void *, unsigned int);
  void *memmove(void *, const void *, unsigned int);
  void *memset(void *, int, unsigned int);
  int   memcmp(const void *, const void *, unsigned int);
  unsigned int strlen(const char *);
  int   strcmp(const char *, const char *);
  char *strchr(const char *, int);
}

static HMODULE h_ws2      = (HMODULE)NULLP;
static HMODULE h_secur32  = (HMODULE)NULLP;
static HMODULE h_winhttp  = (HMODULE)NULLP;
static HMODULE h_crypt32  = (HMODULE)NULLP;
static HMODULE h_advapi32 = (HMODULE)NULLP;
static HMODULE h_shell32  = (HMODULE)NULLP;

/* ---- ws2_32 ------------------------------------------------------------ */
struct SOCKADDR   { WORD sa_family; char sa_data[26]; };
struct SOCKADDRIN { short sin_family; WORD sin_port; DWORD sin_addr; char sin_zero[8]; };
struct SOCKADDRIN6 { short sin6_family; WORD sin6_port; DWORD sin6_flowinfo;
                     BYTE sin6_addr[16]; DWORD sin6_scope_id; };

#define ET_AF_INET       2
#define ET_AF_INET6     23            /* AF_INET6 is 23 on Windows, not the 10 Linux uses */
#define ET_IPPROTO_IPV6 41
#define ET_IPV6_V6ONLY  27
struct ADDRINFOA {
  int    ai_flags;  int ai_family; int ai_socktype; int ai_protocol;
  UINT   ai_addrlen;
  char  *ai_canonname;
  struct SOCKADDR  *ai_addr;
  struct ADDRINFOA *ai_next;
};
struct TIMEVAL { long tv_sec; long tv_usec; };
struct FDSET   { UINT fd_count; SOCKET fd_array[64]; };

typedef int    (WINAPI *PFN_WSAStartup)(WORD, void *);
typedef int    (WINAPI *PFN_WSACleanup)(void);
typedef int    (WINAPI *PFN_WSAGetLastError)(void);
typedef SOCKET (WINAPI *PFN_socket)(int, int, int);
typedef int    (WINAPI *PFN_connect)(SOCKET, const struct SOCKADDR *, int);
typedef int    (WINAPI *PFN_send)(SOCKET, const char *, int, int);
typedef int    (WINAPI *PFN_recv)(SOCKET, char *, int, int);
typedef int    (WINAPI *PFN_closesocket)(SOCKET);
typedef int    (WINAPI *PFN_getaddrinfo)(const char *, const char *, const struct ADDRINFOA *,
                                         struct ADDRINFOA **);
typedef void   (WINAPI *PFN_freeaddrinfo)(struct ADDRINFOA *);
typedef int    (WINAPI *PFN_setsockopt)(SOCKET, int, int, const char *, int);
typedef int    (WINAPI *PFN_bind)(SOCKET, const struct SOCKADDR *, int);
typedef int    (WINAPI *PFN_listen)(SOCKET, int);
typedef SOCKET (WINAPI *PFN_accept)(SOCKET, struct SOCKADDR *, int *);
typedef int    (WINAPI *PFN_select)(int, struct FDSET *, struct FDSET *, struct FDSET *,
                                    const struct TIMEVAL *);
typedef WORD   (WINAPI *PFN_htons)(WORD);
typedef int    (WINAPI *PFN_getsockname)(SOCKET, struct SOCKADDR *, int *);

static PFN_WSAStartup      p_WSAStartup      = 0;
static PFN_WSACleanup      p_WSACleanup      = 0;
static PFN_WSAGetLastError p_WSAGetLastError = 0;
static PFN_socket          p_socket          = 0;
static PFN_connect         p_connect         = 0;
static PFN_send            p_send            = 0;
static PFN_recv            p_recv            = 0;
static PFN_closesocket     p_closesocket     = 0;
static PFN_getaddrinfo     p_getaddrinfo     = 0;
static PFN_freeaddrinfo    p_freeaddrinfo    = 0;
static PFN_setsockopt      p_setsockopt      = 0;
static PFN_bind            p_bind            = 0;
static PFN_listen          p_listen          = 0;
static PFN_accept          p_accept          = 0;
static PFN_select          p_select          = 0;
static PFN_htons           p_htons           = 0;
static PFN_getsockname     p_getsockname     = 0;

static int g_wsa_started = 0;

static int et_load_ws2(void)
{
  char wsadata[512];
  if (p_socket) return ET_OK;
  h_ws2 = LoadLibraryA("ws2_32.dll");
  if (!h_ws2) return ET_E_NOWINSOCK;
  p_WSAStartup      = (PFN_WSAStartup)      GetProcAddress(h_ws2, "WSAStartup");
  p_WSACleanup      = (PFN_WSACleanup)      GetProcAddress(h_ws2, "WSACleanup");
  p_WSAGetLastError = (PFN_WSAGetLastError) GetProcAddress(h_ws2, "WSAGetLastError");
  p_socket          = (PFN_socket)          GetProcAddress(h_ws2, "socket");
  p_connect         = (PFN_connect)         GetProcAddress(h_ws2, "connect");
  p_send            = (PFN_send)            GetProcAddress(h_ws2, "send");
  p_recv            = (PFN_recv)            GetProcAddress(h_ws2, "recv");
  p_closesocket     = (PFN_closesocket)     GetProcAddress(h_ws2, "closesocket");
  p_getaddrinfo     = (PFN_getaddrinfo)     GetProcAddress(h_ws2, "getaddrinfo");
  p_freeaddrinfo    = (PFN_freeaddrinfo)    GetProcAddress(h_ws2, "freeaddrinfo");
  p_setsockopt      = (PFN_setsockopt)      GetProcAddress(h_ws2, "setsockopt");
  p_bind            = (PFN_bind)            GetProcAddress(h_ws2, "bind");
  p_listen          = (PFN_listen)          GetProcAddress(h_ws2, "listen");
  p_accept          = (PFN_accept)          GetProcAddress(h_ws2, "accept");
  p_select          = (PFN_select)          GetProcAddress(h_ws2, "select");
  p_htons           = (PFN_htons)           GetProcAddress(h_ws2, "htons");
  p_getsockname     = (PFN_getsockname)     GetProcAddress(h_ws2, "getsockname");
  if (!p_WSAStartup || !p_socket || !p_connect || !p_send || !p_recv ||
      !p_getaddrinfo || !p_select) return ET_E_NOWINSOCK;
  if (!g_wsa_started) {
    if (p_WSAStartup((WORD)0x0202, (void *)wsadata) != 0) return ET_E_NOWINSOCK;
    g_wsa_started = 1;
  }
  return ET_OK;
}

/* ---- secur32 / SCHANNEL ------------------------------------------------ */
struct SEC_HANDLE   { DWORD dwLower; DWORD dwUpper; };
struct SEC_TIMESTMP { DWORD lo; DWORD hi; };
struct SEC_BUFFER   { DWORD cbBuffer; DWORD BufferType; void *pvBuffer; };
struct SEC_BUFDESC  { DWORD ulVersion; DWORD cBuffers; struct SEC_BUFFER *pBuffers; };
struct SEC_STREAMSZ { DWORD cbHeader; DWORD cbTrailer; DWORD cbMaximumMessage;
                      DWORD cBuffers; DWORD cbBlockSize; };

/* SCHANNEL_CRED, version 4 - fourteen 4-byte fields on Win32 */
struct SCHANNEL_CRED {
  DWORD  dwVersion;
  DWORD  cCreds;
  void  *paCred;
  void  *hRootStore;
  DWORD  cMappers;
  void  *aphMappers;
  DWORD  cSupportedAlgs;
  void  *palgSupportedAlgs;
  DWORD  grbitEnabledProtocols;
  DWORD  dwMinimumCipherStrength;
  DWORD  dwMaximumCipherStrength;
  DWORD  dwSessionLifespan;
  DWORD  dwFlags;
  DWORD  dwCredFormat;
};

#define SCHANNEL_CRED_VERSION           4
#define UNISP_NAME_A                    "Microsoft Unified Security Protocol Provider"
#define SECPKG_CRED_OUTBOUND            2
#define SECBUFFER_VERSION               0
#define SECBUFFER_EMPTY                 0
#define SECBUFFER_DATA                  1
#define SECBUFFER_TOKEN                 2
#define SECBUFFER_EXTRA                 5
#define SECBUFFER_STREAM_TRAILER        6
#define SECBUFFER_STREAM_HEADER         7
#define SECBUFFER_ALERT                17
#define SECPKG_ATTR_STREAM_SIZES        4
#define SECURITY_NATIVE_DREP   0x00000010

#define SEC_E_OK                        0x00000000
#define SEC_I_CONTINUE_NEEDED           0x00090312
#define SEC_I_CONTEXT_EXPIRED           0x00090317
#define SEC_I_INCOMPLETE_CREDENTIALS    0x00090320
#define SEC_I_RENEGOTIATE               0x00090321
#define SEC_E_INCOMPLETE_MESSAGE        0x80090318

#define ISC_REQ_REPLAY_DETECT           0x00000004
#define ISC_REQ_SEQUENCE_DETECT         0x00000008
#define ISC_REQ_CONFIDENTIALITY         0x00000010
#define ISC_REQ_ALLOCATE_MEMORY         0x00000100
#define ISC_REQ_EXTENDED_ERROR          0x00004000
#define ISC_REQ_STREAM                  0x00008000
#define ISC_REQ_MANUAL_CRED_VALIDATION  0x00080000

#define SCH_CRED_MANUAL_CRED_VALIDATION 0x00000008
#define SCH_CRED_NO_DEFAULT_CREDS       0x00000010
#define SCH_CRED_AUTO_CRED_VALIDATION   0x00000020

typedef DWORD (WINAPI *PFN_AcquireCredentialsHandleA)(char *, char *, DWORD, void *, void *,
                        void *, void *, struct SEC_HANDLE *, struct SEC_TIMESTMP *);
typedef DWORD (WINAPI *PFN_InitializeSecurityContextA)(struct SEC_HANDLE *, struct SEC_HANDLE *,
                        char *, DWORD, DWORD, DWORD, struct SEC_BUFDESC *, DWORD,
                        struct SEC_HANDLE *, struct SEC_BUFDESC *, DWORD *, struct SEC_TIMESTMP *);
typedef DWORD (WINAPI *PFN_FreeCredentialsHandle)(struct SEC_HANDLE *);
typedef DWORD (WINAPI *PFN_DeleteSecurityContext)(struct SEC_HANDLE *);
typedef DWORD (WINAPI *PFN_FreeContextBuffer)(void *);
typedef DWORD (WINAPI *PFN_QueryContextAttributesA)(struct SEC_HANDLE *, DWORD, void *);
typedef DWORD (WINAPI *PFN_EncryptMessage)(struct SEC_HANDLE *, DWORD, struct SEC_BUFDESC *, DWORD);
typedef DWORD (WINAPI *PFN_DecryptMessage)(struct SEC_HANDLE *, struct SEC_BUFDESC *, DWORD, DWORD *);
typedef DWORD (WINAPI *PFN_ApplyControlToken)(struct SEC_HANDLE *, struct SEC_BUFDESC *);

static PFN_AcquireCredentialsHandleA  p_AcquireCred = 0;
static PFN_InitializeSecurityContextA p_InitCtx     = 0;
static PFN_FreeCredentialsHandle      p_FreeCred    = 0;
static PFN_DeleteSecurityContext      p_DeleteCtx   = 0;
static PFN_FreeContextBuffer          p_FreeCtxBuf  = 0;
static PFN_QueryContextAttributesA    p_QueryAttr   = 0;
static PFN_EncryptMessage             p_Encrypt     = 0;
static PFN_DecryptMessage             p_Decrypt     = 0;
static PFN_ApplyControlToken          p_ApplyCtl    = 0;

static int et_load_sspi(void)
{
  if (p_InitCtx) return ET_OK;
  h_secur32 = LoadLibraryA("secur32.dll");
  if (!h_secur32) return ET_E_NOSECUR32;
  p_AcquireCred = (PFN_AcquireCredentialsHandleA) GetProcAddress(h_secur32, "AcquireCredentialsHandleA");
  p_InitCtx     = (PFN_InitializeSecurityContextA)GetProcAddress(h_secur32, "InitializeSecurityContextA");
  p_FreeCred    = (PFN_FreeCredentialsHandle)     GetProcAddress(h_secur32, "FreeCredentialsHandle");
  p_DeleteCtx   = (PFN_DeleteSecurityContext)     GetProcAddress(h_secur32, "DeleteSecurityContext");
  p_FreeCtxBuf  = (PFN_FreeContextBuffer)         GetProcAddress(h_secur32, "FreeContextBuffer");
  p_QueryAttr   = (PFN_QueryContextAttributesA)   GetProcAddress(h_secur32, "QueryContextAttributesA");
  p_Encrypt     = (PFN_EncryptMessage)            GetProcAddress(h_secur32, "EncryptMessage");
  p_Decrypt     = (PFN_DecryptMessage)            GetProcAddress(h_secur32, "DecryptMessage");
  p_ApplyCtl    = (PFN_ApplyControlToken)         GetProcAddress(h_secur32, "ApplyControlToken");
  if (!p_AcquireCred || !p_InitCtx || !p_QueryAttr || !p_Encrypt || !p_Decrypt)
    return ET_E_NOSECUR32;
  return ET_OK;
}

/* =========================================================================
   2.  SHA-256 - ours, because OAuth2 PKCE needs S256 and pulling in bcrypt
       for 60 lines of arithmetic is not worth another dependency.
       Everything here is 32-bit, which Clacpp handles natively.
   ========================================================================= */
#define ROTR32(x,n) ((((DWORD)(x)) >> (n)) | (((DWORD)(x)) << (32 - (n))))

static const DWORD sha_k[64] = {
  0x428a2f98UL,0x71374491UL,0xb5c0fbcfUL,0xe9b5dba5UL,0x3956c25bUL,0x59f111f1UL,0x923f82a4UL,0xab1c5ed5UL,
  0xd807aa98UL,0x12835b01UL,0x243185beUL,0x550c7dc3UL,0x72be5d74UL,0x80deb1feUL,0x9bdc06a7UL,0xc19bf174UL,
  0xe49b69c1UL,0xefbe4786UL,0x0fc19dc6UL,0x240ca1ccUL,0x2de92c6fUL,0x4a7484aaUL,0x5cb0a9dcUL,0x76f988daUL,
  0x983e5152UL,0xa831c66dUL,0xb00327c8UL,0xbf597fc7UL,0xc6e00bf3UL,0xd5a79147UL,0x06ca6351UL,0x14292967UL,
  0x27b70a85UL,0x2e1b2138UL,0x4d2c6dfcUL,0x53380d13UL,0x650a7354UL,0x766a0abbUL,0x81c2c92eUL,0x92722c85UL,
  0xa2bfe8a1UL,0xa81a664bUL,0xc24b8b70UL,0xc76c51a3UL,0xd192e819UL,0xd6990624UL,0xf40e3585UL,0x106aa070UL,
  0x19a4c116UL,0x1e376c08UL,0x2748774cUL,0x34b0bcb5UL,0x391c0cb3UL,0x4ed8aa4aUL,0x5b9cca4fUL,0x682e6ff3UL,
  0x748f82eeUL,0x78a5636fUL,0x84c87814UL,0x8cc70208UL,0x90befffaUL,0xa4506cebUL,0xbef9a3f7UL,0xc67178f2UL };

static void sha256_block(DWORD *st, const BYTE *p)
{
  DWORD w[64], a, b, c, d, e, f, g, h, t1, t2;
  int i;
  for (i = 0; i < 16; i++)
    w[i] = ((DWORD)p[i*4] << 24) | ((DWORD)p[i*4+1] << 16) |
           ((DWORD)p[i*4+2] << 8) | (DWORD)p[i*4+3];
  for (i = 16; i < 64; i++) {
    DWORD s0 = ROTR32(w[i-15],7) ^ ROTR32(w[i-15],18) ^ (w[i-15] >> 3);
    DWORD s1 = ROTR32(w[i-2],17) ^ ROTR32(w[i-2],19)  ^ (w[i-2] >> 10);
    w[i] = w[i-16] + s0 + w[i-7] + s1;
  }
  a = st[0]; b = st[1]; c = st[2]; d = st[3];
  e = st[4]; f = st[5]; g = st[6]; h = st[7];
  for (i = 0; i < 64; i++) {
    DWORD S1 = ROTR32(e,6) ^ ROTR32(e,11) ^ ROTR32(e,25);
    DWORD ch = (e & f) ^ ((~e) & g);
    DWORD S0 = ROTR32(a,2) ^ ROTR32(a,13) ^ ROTR32(a,22);
    DWORD mj = (a & b) ^ (a & c) ^ (b & c);
    t1 = h + S1 + ch + sha_k[i] + w[i];
    t2 = S0 + mj;
    h = g; g = f; f = e; e = d + t1;
    d = c; c = b; b = a; a = t1 + t2;
  }
  st[0] += a; st[1] += b; st[2] += c; st[3] += d;
  st[4] += e; st[5] += f; st[6] += g; st[7] += h;
}

static void sha256_bytes(const BYTE *msg, int len, BYTE *out32)
{
  DWORD st[8];
  BYTE  tail[128];
  int   i, n, rem;
  DWORD bitlo, bithi;

  st[0]=0x6a09e667UL; st[1]=0xbb67ae85UL; st[2]=0x3c6ef372UL; st[3]=0xa54ff53aUL;
  st[4]=0x510e527fUL; st[5]=0x9b05688cUL; st[6]=0x1f83d9abUL; st[7]=0x5be0cd19UL;

  n = len / 64;
  for (i = 0; i < n; i++) sha256_block(st, msg + i*64);
  rem = len - n*64;
  memcpy(tail, msg + n*64, (unsigned int)rem);
  tail[rem] = 0x80;
  i = rem + 1;
  n = (i <= 56) ? 64 : 128;
  memset(tail + i, 0, (unsigned int)(n - i));
  /* the length in bits, 64-bit big-endian, assembled from two 32-bit halves */
  bitlo = ((DWORD)len) << 3;
  bithi = ((DWORD)len) >> 29;
  tail[n-8] = (BYTE)(bithi >> 24); tail[n-7] = (BYTE)(bithi >> 16);
  tail[n-6] = (BYTE)(bithi >> 8);  tail[n-5] = (BYTE)(bithi);
  tail[n-4] = (BYTE)(bitlo >> 24); tail[n-3] = (BYTE)(bitlo >> 16);
  tail[n-2] = (BYTE)(bitlo >> 8);  tail[n-1] = (BYTE)(bitlo);
  sha256_block(st, tail);
  if (n == 128) sha256_block(st, tail + 64);

  for (i = 0; i < 8; i++) {
    out32[i*4]   = (BYTE)(st[i] >> 24);
    out32[i*4+1] = (BYTE)(st[i] >> 16);
    out32[i*4+2] = (BYTE)(st[i] >> 8);
    out32[i*4+3] = (BYTE)(st[i]);
  }
}

/* =========================================================================
   3.  The connection table.  One slot per open conversation; TLS state and
       the two buffers (ciphertext in, plaintext out) live here so Clarion
       can just ask for the next line.
   ========================================================================= */
#define ET_MAXCONN   16
#define ET_ENCCAP    32768
#define ET_PLAINCAP  65536

struct ET_CONN {
  int    used;
  SOCKET sock;
  SOCKET sock6;                     /* the OAuth listener's IPv6 twin, else INVALID */
  int    tls;                       /* 1 once the handshake has completed */
  int    eof;                       /* peer closed and the buffers are drained */
  int    lasterr;                   /* the SSPI / winsock code, for diagnostics */
  int    timeout_ms;
  struct SEC_HANDLE hCred; int haveCred;
  struct SEC_HANDLE hCtx;  int haveCtx;
  DWORD  szHeader, szTrailer, szMaxMsg;
  char  *enc;   int enclen;         /* ciphertext read but not yet decrypted */
  char  *plain; int plainlen, plainpos;  /* decrypted, not yet handed to Clarion */
};

static struct ET_CONN g_conn[ET_MAXCONN];

/* The Windows code behind a failure that happened before there was a slot to
   put it in (a refused connect, a rejected certificate).  et_lasterr(0) reads
   it, which is the only thing Clarion can ask for when et_open returned an
   error instead of an id. */
static int g_lastopenerr = 0;

static struct ET_CONN *et_slot(int id)
{
  if (id < 1 || id > ET_MAXCONN) return (struct ET_CONN *)NULLP;
  if (!g_conn[id-1].used) return (struct ET_CONN *)NULLP;
  return &g_conn[id-1];
}

static int et_newslot(void)
{
  int i;
  for (i = 0; i < ET_MAXCONN; i++) {
    if (!g_conn[i].used) {
      memset(&g_conn[i], 0, sizeof(struct ET_CONN));
      g_conn[i].used  = 1;
      g_conn[i].sock  = INVALID_SOCKET;
      g_conn[i].sock6 = INVALID_SOCKET;
      g_conn[i].timeout_ms = 30000;
      g_conn[i].enc   = (char *)malloc(ET_ENCCAP);
      g_conn[i].plain = (char *)malloc(ET_PLAINCAP);
      if (!g_conn[i].enc || !g_conn[i].plain) {
        if (g_conn[i].enc)   free(g_conn[i].enc);
        if (g_conn[i].plain) free(g_conn[i].plain);
        g_conn[i].used = 0;
        return ET_E_MEMORY;
      }
      return i + 1;
    }
  }
  return ET_E_NOSLOT;
}

/* wait until the socket has something to read; 1 = ready, 0 = timeout */
static int et_wait_readable(struct ET_CONN *c, int ms)
{
  struct FDSET  fds;
  struct TIMEVAL tv;
  int rc;
  fds.fd_count = 1;
  fds.fd_array[0] = c->sock;
  tv.tv_sec  = ms / 1000;
  tv.tv_usec = (ms % 1000) * 1000;
  rc = p_select(0, &fds, (struct FDSET *)NULLP, (struct FDSET *)NULLP, &tv);
  return (rc > 0) ? 1 : 0;
}

/* raw bytes onto the wire, looping until the lot has gone */
static int et_raw_send(struct ET_CONN *c, const char *buf, int len)
{
  int sent = 0, n;
  while (sent < len) {
    n = p_send(c->sock, buf + sent, len - sent, 0);
    if (n == SOCKET_ERROR || n <= 0) {
      c->lasterr = p_WSAGetLastError ? p_WSAGetLastError() : 0;
      return ET_E_SEND;
    }
    sent += n;
  }
  return sent;
}

/* one read into the ciphertext buffer; 0 = peer closed, <0 = error/timeout */
static int et_raw_recv(struct ET_CONN *c)
{
  int n;
  if (c->enclen >= ET_ENCCAP) return ET_E_OVERFLOW;
  if (!et_wait_readable(c, c->timeout_ms)) return ET_E_TIMEOUT;
  n = p_recv(c->sock, c->enc + c->enclen, ET_ENCCAP - c->enclen, 0);
  if (n == SOCKET_ERROR) {
    c->lasterr = p_WSAGetLastError ? p_WSAGetLastError() : 0;
    return ET_E_RECV;
  }
  if (n == 0) return 0;
  c->enclen += n;
  return n;
}

/* =========================================================================
   4.  The SCHANNEL handshake.  Identical for implicit TLS (port 465) and for
       STARTTLS (port 587) - the only difference is whether the socket has
       already carried plaintext, which is why the caller drains first.
   ========================================================================= */
static int et_tls_handshake(struct ET_CONN *c, const char *host, int verify)
{
  struct SCHANNEL_CRED sc;
  struct SEC_TIMESTMP  ts;
  struct SEC_BUFFER    inb[2], outb[2];
  struct SEC_BUFDESC   ind, outd;
  struct SEC_STREAMSZ  sizes;
  DWORD  flags, ctxattr, rc;
  int    first = 1, n, nocred = 0;
  char   hostbuf[300];

  n = (int)strlen(host);
  if (n > 290) n = 290;
  memcpy(hostbuf, host, (unsigned int)n);
  hostbuf[n] = 0;

  memset(&sc, 0, sizeof(sc));
  sc.dwVersion = SCHANNEL_CRED_VERSION;
  /* grbitEnabledProtocols stays 0: let Windows negotiate, so the app picks up
     TLS 1.3 on a machine that has it without a rebuild. */
  sc.dwFlags = SCH_CRED_NO_DEFAULT_CREDS |
               (verify ? SCH_CRED_AUTO_CRED_VALIDATION : SCH_CRED_MANUAL_CRED_VALIDATION);

  rc = p_AcquireCred((char *)NULLP, (char *)UNISP_NAME_A, SECPKG_CRED_OUTBOUND,
                     (void *)NULLP, (void *)&sc, (void *)NULLP, (void *)NULLP,
                     &c->hCred, &ts);
  if (rc != SEC_E_OK) { c->lasterr = (int)rc; return ET_E_CRED; }
  c->haveCred = 1;

  flags = ISC_REQ_SEQUENCE_DETECT | ISC_REQ_REPLAY_DETECT | ISC_REQ_CONFIDENTIALITY |
          ISC_REQ_ALLOCATE_MEMORY | ISC_REQ_EXTENDED_ERROR | ISC_REQ_STREAM;
  if (!verify) flags |= ISC_REQ_MANUAL_CRED_VALIDATION;

  c->enclen = 0;

  for (;;) {
    memset(inb, 0, sizeof(inb));
    memset(outb, 0, sizeof(outb));

    inb[0].BufferType = SECBUFFER_TOKEN;
    inb[0].pvBuffer   = c->enc;
    inb[0].cbBuffer   = (DWORD)c->enclen;
    inb[1].BufferType = SECBUFFER_EMPTY;
    ind.ulVersion = SECBUFFER_VERSION; ind.cBuffers = 2; ind.pBuffers = inb;

    outb[0].BufferType = SECBUFFER_TOKEN;
    outb[1].BufferType = SECBUFFER_ALERT;
    outd.ulVersion = SECBUFFER_VERSION; outd.cBuffers = 2; outd.pBuffers = outb;

    rc = p_InitCtx(&c->hCred,
                   first ? (struct SEC_HANDLE *)NULLP : &c->hCtx,
                   hostbuf, flags, 0, SECURITY_NATIVE_DREP,
                   first ? (struct SEC_BUFDESC *)NULLP : &ind,
                   0, &c->hCtx, &outd, &ctxattr, &ts);
    first = 0;
    c->haveCtx = 1;

    /* whatever SCHANNEL produced goes to the server, success or not */
    if (outb[0].cbBuffer && outb[0].pvBuffer) {
      if (et_raw_send(c, (const char *)outb[0].pvBuffer, (int)outb[0].cbBuffer) < 0) {
        p_FreeCtxBuf(outb[0].pvBuffer);
        return ET_E_SEND;
      }
      p_FreeCtxBuf(outb[0].pvBuffer);
      outb[0].pvBuffer = (void *)NULLP;
      outb[0].cbBuffer = 0;
    }

    if (rc == SEC_E_INCOMPLETE_MESSAGE) {
      n = et_raw_recv(c);
      if (n <= 0) { if (n == 0) c->lasterr = 0; return (n < 0) ? n : ET_E_CLOSED; }
      continue;
    }

    if (rc == SEC_I_INCOMPLETE_CREDENTIALS) {
      /* The server asked for a CLIENT certificate and this credential has
         none.  Gmail and Office 365 both do this, and both are happy without
         one - the ask is optional.  Re-issue the SAME token (do not read more
         data) and SCHANNEL finishes the handshake anonymously.  This is the
         handling in Microsoft own Schannel client sample; without it every
         connection to smtp.gmail.com dies at 0x00090320. */
      if (++nocred > 2) { c->lasterr = (int)rc; return ET_E_HANDSHAKE; }
      continue;
    }

    if (rc == SEC_E_OK || rc == SEC_I_CONTINUE_NEEDED) {
      /* SCHANNEL may have left application data or the next token behind */
      if (inb[1].BufferType == SECBUFFER_EXTRA && inb[1].cbBuffer) {
        memmove(c->enc, c->enc + (c->enclen - (int)inb[1].cbBuffer),
                (unsigned int)inb[1].cbBuffer);
        c->enclen = (int)inb[1].cbBuffer;
      } else {
        c->enclen = 0;
      }
      if (rc == SEC_E_OK) break;
      if (c->enclen == 0) {
        n = et_raw_recv(c);
        if (n <= 0) { return (n < 0) ? n : ET_E_CLOSED; }
      }
      continue;
    }

    c->lasterr = (int)rc;
    return ET_E_HANDSHAKE;
  }

  memset(&sizes, 0, sizeof(sizes));
  rc = p_QueryAttr(&c->hCtx, SECPKG_ATTR_STREAM_SIZES, (void *)&sizes);
  if (rc != SEC_E_OK) { c->lasterr = (int)rc; return ET_E_STREAMSIZES; }
  c->szHeader  = sizes.cbHeader;
  c->szTrailer = sizes.cbTrailer;
  c->szMaxMsg  = sizes.cbMaximumMessage;
  if (c->szMaxMsg > 16384) c->szMaxMsg = 16384;
  c->tls = 1;
  return ET_OK;
}

/* move one TLS record from `enc` into `plain`; 0 = clean close, <0 = error */
static int et_tls_pump(struct ET_CONN *c)
{
  struct SEC_BUFFER  b[4];
  struct SEC_BUFDESC d;
  DWORD rc;
  int   i, n, extra, got = 0;

  for (;;) {
    if (c->enclen == 0) {
      n = et_raw_recv(c);
      if (n <= 0) return (n < 0) ? n : 0;
    }
    memset(b, 0, sizeof(b));
    b[0].BufferType = SECBUFFER_DATA;
    b[0].pvBuffer   = c->enc;
    b[0].cbBuffer   = (DWORD)c->enclen;
    b[1].BufferType = SECBUFFER_EMPTY;
    b[2].BufferType = SECBUFFER_EMPTY;
    b[3].BufferType = SECBUFFER_EMPTY;
    d.ulVersion = SECBUFFER_VERSION; d.cBuffers = 4; d.pBuffers = b;

    rc = p_Decrypt(&c->hCtx, &d, 0, (DWORD *)NULLP);

    if (rc == SEC_E_INCOMPLETE_MESSAGE) {
      n = et_raw_recv(c);
      if (n <= 0) return (n < 0) ? n : 0;
      continue;
    }
    if (rc == SEC_I_CONTEXT_EXPIRED) { c->eof = 1; return 0; }
    if (rc != SEC_E_OK && rc != SEC_I_RENEGOTIATE) {
      c->lasterr = (int)rc;
      return ET_E_DECRYPT;
    }

    extra = 0;
    for (i = 0; i < 4; i++) {
      if (b[i].BufferType == SECBUFFER_DATA && b[i].cbBuffer) {
        if (c->plainlen + (int)b[i].cbBuffer > ET_PLAINCAP) return ET_E_OVERFLOW;
        memcpy(c->plain + c->plainlen, b[i].pvBuffer, (unsigned int)b[i].cbBuffer);
        c->plainlen += (int)b[i].cbBuffer;
        got += (int)b[i].cbBuffer;
      }
      if (b[i].BufferType == SECBUFFER_EXTRA && b[i].cbBuffer) {
        memmove(c->enc, b[i].pvBuffer, (unsigned int)b[i].cbBuffer);
        extra = (int)b[i].cbBuffer;
      }
    }
    c->enclen = extra;
    if (got) return got;
    if (rc == SEC_I_RENEGOTIATE) {
      /* the server asked to renegotiate; treat it as an error rather than
         silently dropping to an unverified session */
      c->lasterr = (int)rc;
      return ET_E_HANDSHAKE;
    }
  }
}

/* fill `plain` with at least one more byte; 0 = closed, <0 = error */
static int et_fill(struct ET_CONN *c)
{
  int n;
  if (c->plainpos > 0 && c->plainpos == c->plainlen) { c->plainpos = 0; c->plainlen = 0; }
  if (c->plainpos > 0 && c->plainlen > c->plainpos) {
    memmove(c->plain, c->plain + c->plainpos, (unsigned int)(c->plainlen - c->plainpos));
    c->plainlen -= c->plainpos;
    c->plainpos  = 0;
  }
  if (c->tls) return et_tls_pump(c);
  if (c->plainlen >= ET_PLAINCAP) return ET_E_OVERFLOW;
  if (!et_wait_readable(c, c->timeout_ms)) return ET_E_TIMEOUT;
  n = p_recv(c->sock, c->plain + c->plainlen, ET_PLAINCAP - c->plainlen, 0);
  if (n == SOCKET_ERROR) { c->lasterr = p_WSAGetLastError ? p_WSAGetLastError() : 0; return ET_E_RECV; }
  if (n == 0) { c->eof = 1; return 0; }
  c->plainlen += n;
  return n;
}

/* =========================================================================
   5.  The exported API.  Everything below is what Clarion calls.
   ========================================================================= */
extern "C" {

/* ---- open a connection ------------------------------------------------- */
/* tls: 0 = plain (STARTTLS may follow), 1 = TLS from the first byte.
   Returns a connection id (1..16) or a negative ET_E_ code.               */
int et_open(const char *host, int port, int tls, int verify, int timeout_ms)
{
  struct ADDRINFOA hints, *res = (struct ADDRINFOA *)NULLP, *ai;
  struct ET_CONN  *c;
  char   portstr[16];
  int    id, rc, i, v;

  g_lastopenerr = 0;
  rc = et_load_ws2();
  if (rc != ET_OK) return rc;
  if (tls) { rc = et_load_sspi(); if (rc != ET_OK) return rc; }

  id = et_newslot();
  if (id < 0) return id;
  c = &g_conn[id-1];
  if (timeout_ms > 0) c->timeout_ms = timeout_ms;

  /* itoa without the CRT */
  v = port; i = 0;
  if (v <= 0) { portstr[i++] = '0'; }
  else { char tmp[8]; int j = 0;
         while (v > 0 && j < 7) { tmp[j++] = (char)('0' + (v % 10)); v /= 10; }
         while (j > 0) portstr[i++] = tmp[--j]; }
  portstr[i] = 0;

  memset(&hints, 0, sizeof(hints));
  hints.ai_family   = 0;   /* AF_UNSPEC - IPv4 or IPv6, whichever answers */
  hints.ai_socktype = 1;   /* SOCK_STREAM */
  hints.ai_protocol = 6;   /* IPPROTO_TCP */

  if (p_getaddrinfo(host, portstr, &hints, &res) != 0 || !res) {
    c->used = 0;
    return ET_E_RESOLVE;
  }

  for (ai = res; ai; ai = ai->ai_next) {
    c->sock = p_socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
    if (c->sock == INVALID_SOCKET) continue;
    if (p_connect(c->sock, ai->ai_addr, (int)ai->ai_addrlen) == 0) break;
    p_closesocket(c->sock);
    c->sock = INVALID_SOCKET;
  }
  p_freeaddrinfo(res);

  if (c->sock == INVALID_SOCKET) {
    g_lastopenerr = p_WSAGetLastError ? p_WSAGetLastError() : 0;
    free(c->enc); free(c->plain);
    c->used = 0;
    return ET_E_CONNECT;
  }

  /* SO_RCVTIMEO / SO_SNDTIMEO as a backstop; select() does the real waiting */
  if (p_setsockopt) {
    DWORD t = (DWORD)c->timeout_ms;
    p_setsockopt(c->sock, 0xffff /*SOL_SOCKET*/, 0x1006 /*SO_RCVTIMEO*/, (const char *)&t, 4);
    p_setsockopt(c->sock, 0xffff, 0x1005 /*SO_SNDTIMEO*/, (const char *)&t, 4);
  }

  if (tls) {
    rc = et_tls_handshake(c, host, verify);
    if (rc != ET_OK) {
      g_lastopenerr = c->lasterr;    /* survives for et_lasterr(0) */
      if (c->haveCtx  && p_DeleteCtx) p_DeleteCtx(&c->hCtx);
      if (c->haveCred && p_FreeCred)  p_FreeCred(&c->hCred);
      p_closesocket(c->sock);
      free(c->enc); free(c->plain);
      memset(c, 0, sizeof(struct ET_CONN));
      return rc;
    }
  }
  return id;
}

/* ---- upgrade a plain connection (SMTP STARTTLS) ------------------------ */
int et_starttls(int id, const char *host, int verify)
{
  struct ET_CONN *c = et_slot(id);
  int rc;
  if (!c) return ET_E_BADID;
  if (c->tls) return ET_E_ALREADYTLS;
  rc = et_load_sspi();
  if (rc != ET_OK) return rc;
  /* anything the server sent before the handshake must already be consumed */
  c->plainlen = 0; c->plainpos = 0; c->enclen = 0;
  return et_tls_handshake(c, host, verify);
}

/* ---- send -------------------------------------------------------------- */
int et_send(int id, const char *buf, int len)
{
  struct ET_CONN *c = et_slot(id);
  char  *rec;
  int    off = 0, chunk, rc;
  struct SEC_BUFFER  b[4];
  struct SEC_BUFDESC d;
  DWORD  st;

  if (!c) return ET_E_BADID;
  if (len <= 0) return 0;
  if (!c->tls) return et_raw_send(c, buf, len);

  rec = (char *)malloc(c->szHeader + c->szMaxMsg + c->szTrailer);
  if (!rec) return ET_E_MEMORY;

  while (off < len) {
    chunk = len - off;
    if ((DWORD)chunk > c->szMaxMsg) chunk = (int)c->szMaxMsg;
    memcpy(rec + c->szHeader, buf + off, (unsigned int)chunk);

    memset(b, 0, sizeof(b));
    b[0].BufferType = SECBUFFER_STREAM_HEADER;  b[0].pvBuffer = rec;                            b[0].cbBuffer = c->szHeader;
    b[1].BufferType = SECBUFFER_DATA;           b[1].pvBuffer = rec + c->szHeader;              b[1].cbBuffer = (DWORD)chunk;
    b[2].BufferType = SECBUFFER_STREAM_TRAILER; b[2].pvBuffer = rec + c->szHeader + chunk;      b[2].cbBuffer = c->szTrailer;
    b[3].BufferType = SECBUFFER_EMPTY;
    d.ulVersion = SECBUFFER_VERSION; d.cBuffers = 4; d.pBuffers = b;

    st = p_Encrypt(&c->hCtx, 0, &d, 0);
    if (st != SEC_E_OK) { c->lasterr = (int)st; free(rec); return ET_E_ENCRYPT; }

    rc = et_raw_send(c, rec, (int)(b[0].cbBuffer + b[1].cbBuffer + b[2].cbBuffer));
    if (rc < 0) { free(rec); return rc; }
    off += chunk;
  }
  free(rec);
  return len;
}

/* ---- receive one CRLF-terminated line (the SMTP unit of conversation) ---
   The line arrives WITHOUT its CRLF and NUL-terminated.  Returns the length,
   0 on a clean close with nothing left, or a negative ET_E_ code.        */
int et_recvline(int id, char *out, int cap)
{
  struct ET_CONN *c = et_slot(id);
  int i, n, avail;

  if (!c) return ET_E_BADID;
  if (cap < 2) return ET_E_OVERFLOW;

  for (;;) {
    for (i = c->plainpos; i < c->plainlen; i++) {
      if (c->plain[i] == '\n') {
        int end = i;
        if (end > c->plainpos && c->plain[end-1] == '\r') end--;
        n = end - c->plainpos;
        if (n > cap - 1) n = cap - 1;
        memcpy(out, c->plain + c->plainpos, (unsigned int)n);
        out[n] = 0;
        c->plainpos = i + 1;
        return n;
      }
    }
    if (c->eof) {
      /* a last line with no CRLF */
      avail = c->plainlen - c->plainpos;
      if (avail <= 0) return 0;
      n = (avail > cap - 1) ? cap - 1 : avail;
      memcpy(out, c->plain + c->plainpos, (unsigned int)n);
      out[n] = 0;
      c->plainpos += n;
      return n;
    }
    n = et_fill(c);
    if (n < 0) return n;
    if (n == 0) { c->eof = 1; }
  }
}

/* ---- receive raw bytes (used for non-line protocols) ------------------- */
int et_recv(int id, char *out, int cap)
{
  struct ET_CONN *c = et_slot(id);
  int n, avail;
  if (!c) return ET_E_BADID;
  if (c->plainpos >= c->plainlen) {
    n = et_fill(c);
    if (n < 0) return n;
    if (n == 0) return 0;
  }
  avail = c->plainlen - c->plainpos;
  if (avail > cap) avail = cap;
  memcpy(out, c->plain + c->plainpos, (unsigned int)avail);
  c->plainpos += avail;
  return avail;
}

int et_lasterr(int id)
{
  if (id == 0) return g_lastopenerr;            /* the failure had no slot yet */
  if (id < 1 || id > ET_MAXCONN) return 0;
  return g_conn[id-1].lasterr;
}

void et_close(int id)
{
  struct ET_CONN *c = et_slot(id);
  if (!c) return;
  if (c->haveCtx) {
    /* a polite TLS shutdown alert, best effort */
    struct SEC_BUFFER  b[1];
    struct SEC_BUFDESC d;
    DWORD  tok = 1;                      /* SCHANNEL_SHUTDOWN */
    b[0].BufferType = SECBUFFER_TOKEN;
    b[0].pvBuffer   = (void *)&tok;
    b[0].cbBuffer   = 4;
    d.ulVersion = SECBUFFER_VERSION; d.cBuffers = 1; d.pBuffers = b;
    if (p_ApplyCtl) p_ApplyCtl(&c->hCtx, &d);
    if (p_DeleteCtx) p_DeleteCtx(&c->hCtx);
  }
  if (c->haveCred && p_FreeCred) p_FreeCred(&c->hCred);
  if (c->sock != INVALID_SOCKET && p_closesocket) p_closesocket(c->sock);
  if (c->sock6 != INVALID_SOCKET && p_closesocket) p_closesocket(c->sock6);
  if (c->enc)   free(c->enc);
  if (c->plain) free(c->plain);
  memset(c, 0, sizeof(struct ET_CONN));
}

/* ---- SHA-256 (PKCE) ---------------------------------------------------- */
int et_sha256(const char *in, int len, char *out32)
{
  if (len < 0) return ET_E_OVERFLOW;
  sha256_bytes((const BYTE *)in, len, (BYTE *)out32);
  return 32;
}

/* ---- cryptographic random --------------------------------------------- */
typedef BYTE (WINAPI *PFN_RtlGenRandom)(void *, DWORD);
static PFN_RtlGenRandom p_RtlGenRandom = 0;

int et_random(char *out, int len)
{
  int i;
  if (!p_RtlGenRandom) {
    if (!h_advapi32) h_advapi32 = LoadLibraryA("advapi32.dll");
    if (h_advapi32)
      p_RtlGenRandom = (PFN_RtlGenRandom)GetProcAddress(h_advapi32, "SystemFunction036");
  }
  if (p_RtlGenRandom && p_RtlGenRandom((void *)out, (DWORD)len)) return len;
  /* a machine without RtlGenRandom still gets non-repeating bytes */
  for (i = 0; i < len; i++) {
    DWORD t = GetTickCount() + (DWORD)(i * 2654435761UL);
    out[i] = (char)((t >> ((i % 4) * 8)) & 0xff);
  }
  return len;
}

}   /* extern "C" - sockets, TLS, hashing */

/* =========================================================================
   6.  HTTPS through WinHTTP.  OAuth2 token exchange, the Gmail API, Microsoft
       Graph and every API-key service (SendGrid, Mailgun, Resend, Brevo) are
       all one POST, so they all come through here.

       The URL is parsed by hand rather than with WinHttpCrackUrl: it saves
       declaring URL_COMPONENTS and it is nine lines.
   ========================================================================= */
typedef HANDLE (WINAPI *PFN_WinHttpOpen)(const WCH *, DWORD, const WCH *, const WCH *, DWORD);
typedef HANDLE (WINAPI *PFN_WinHttpConnect)(HANDLE, const WCH *, WORD, DWORD);
typedef HANDLE (WINAPI *PFN_WinHttpOpenRequest)(HANDLE, const WCH *, const WCH *, const WCH *,
                                                const WCH *, const WCH **, DWORD);
typedef BOOL   (WINAPI *PFN_WinHttpSendRequest)(HANDLE, const WCH *, DWORD, void *, DWORD, DWORD, DWORD);
typedef BOOL   (WINAPI *PFN_WinHttpReceiveResponse)(HANDLE, void *);
typedef BOOL   (WINAPI *PFN_WinHttpQueryHeaders)(HANDLE, DWORD, const WCH *, void *, DWORD *, DWORD *);
typedef BOOL   (WINAPI *PFN_WinHttpReadData)(HANDLE, void *, DWORD, DWORD *);
typedef BOOL   (WINAPI *PFN_WinHttpCloseHandle)(HANDLE);
typedef BOOL   (WINAPI *PFN_WinHttpSetTimeouts)(HANDLE, int, int, int, int);
typedef BOOL   (WINAPI *PFN_WinHttpSetOption)(HANDLE, DWORD, void *, DWORD);

static PFN_WinHttpOpen            p_HttpOpen    = 0;
static PFN_WinHttpConnect         p_HttpConnect = 0;
static PFN_WinHttpOpenRequest     p_HttpOpenReq = 0;
static PFN_WinHttpSendRequest     p_HttpSend    = 0;
static PFN_WinHttpReceiveResponse p_HttpRecv    = 0;
static PFN_WinHttpQueryHeaders    p_HttpQuery   = 0;
static PFN_WinHttpReadData        p_HttpRead    = 0;
static PFN_WinHttpCloseHandle     p_HttpClose   = 0;
static PFN_WinHttpSetTimeouts     p_HttpTimeout = 0;
static PFN_WinHttpSetOption       p_HttpOption  = 0;

#define WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY  4
#define WINHTTP_ACCESS_TYPE_NO_PROXY         1
#define WINHTTP_FLAG_SECURE          0x00800000
#define WINHTTP_FLAG_REFRESH         0x00000100
#define WINHTTP_QUERY_STATUS_CODE            19
#define WINHTTP_QUERY_FLAG_NUMBER    0x20000000
#define WINHTTP_OPTION_SECURITY_FLAGS        31
#define SECURITY_FLAG_IGNORE_ALL     0x00003300

static int et_load_winhttp(void)
{
  if (p_HttpOpen) return ET_OK;
  h_winhttp = LoadLibraryA("winhttp.dll");
  if (!h_winhttp) return ET_E_NOWINHTTP;
  p_HttpOpen    = (PFN_WinHttpOpen)           GetProcAddress(h_winhttp, "WinHttpOpen");
  p_HttpConnect = (PFN_WinHttpConnect)        GetProcAddress(h_winhttp, "WinHttpConnect");
  p_HttpOpenReq = (PFN_WinHttpOpenRequest)    GetProcAddress(h_winhttp, "WinHttpOpenRequest");
  p_HttpSend    = (PFN_WinHttpSendRequest)    GetProcAddress(h_winhttp, "WinHttpSendRequest");
  p_HttpRecv    = (PFN_WinHttpReceiveResponse)GetProcAddress(h_winhttp, "WinHttpReceiveResponse");
  p_HttpQuery   = (PFN_WinHttpQueryHeaders)   GetProcAddress(h_winhttp, "WinHttpQueryHeaders");
  p_HttpRead    = (PFN_WinHttpReadData)       GetProcAddress(h_winhttp, "WinHttpReadData");
  p_HttpClose   = (PFN_WinHttpCloseHandle)    GetProcAddress(h_winhttp, "WinHttpCloseHandle");
  p_HttpTimeout = (PFN_WinHttpSetTimeouts)    GetProcAddress(h_winhttp, "WinHttpSetTimeouts");
  p_HttpOption  = (PFN_WinHttpSetOption)      GetProcAddress(h_winhttp, "WinHttpSetOption");
  if (!p_HttpOpen || !p_HttpConnect || !p_HttpOpenReq || !p_HttpSend || !p_HttpRecv || !p_HttpRead)
    return ET_E_NOWINHTTP;
  return ET_OK;
}

/* UTF-8 (CP 65001) to UTF-16.  Headers and JSON bodies carry accents, so the
   ANSI code page would corrupt a Spanish subject line. */
static WCH *et_widen(const char *s, int len)
{
  int n;
  WCH *w;
  if (len < 0) len = (int)strlen(s);
  n = MultiByteToWideChar(65001, 0, s, len, (WCH *)NULLP, 0);
  if (n < 0) n = 0;
  w = (WCH *)malloc((unsigned int)(n + 1) * 2);
  if (!w) return (WCH *)NULLP;
  if (n) MultiByteToWideChar(65001, 0, s, len, w, n);
  w[n] = 0;
  return w;
}

/* Split "https://host:443/path" into its parts.  Returns 1 on success. */
static int et_split_url(const char *url, char *host, int hostcap, int *port, char *path,
                        int pathcap, int *secure)
{
  const char *p = url, *hstart, *pstart;
  int n = 0;

  *secure = 0; *port = 80;
  if (url[0]=='h' && url[1]=='t' && url[2]=='t' && url[3]=='p') {
    if (url[4]=='s' && url[5]==':') { *secure = 1; *port = 443; p = url + 8; }
    else if (url[4]==':')           { *secure = 0; *port = 80;  p = url + 7; }
    else return 0;
  } else return 0;

  hstart = p;
  while (*p && *p != '/' && *p != ':') p++;
  n = (int)(p - hstart);
  if (n <= 0 || n >= hostcap) return 0;
  memcpy(host, hstart, (unsigned int)n);
  host[n] = 0;

  if (*p == ':') {
    int v = 0;
    p++;
    while (*p >= '0' && *p <= '9') { v = v * 10 + (*p - '0'); p++; }
    if (v > 0) *port = v;
  }

  pstart = p;
  if (!*pstart) { if (pathcap < 2) return 0; path[0] = '/'; path[1] = 0; return 1; }
  n = (int)strlen(pstart);
  if (n >= pathcap) return 0;
  memcpy(path, pstart, (unsigned int)n);
  path[n] = 0;
  return 1;
}

extern "C" {

/* One HTTPS (or HTTP) request.
     verb     "GET" / "POST"
     url      absolute
     headers  CRLF-separated extra headers, may be ""
     body     request body, may be NULL/0 length
     out      response body buffer
     status   receives the HTTP status code
   Returns the response length, or a negative ET_E_ code.  If the response does
   not fit, returns ET_E_OVERFLOW and *needed gets the full length so Clarion
   can grow the buffer and retry.                                          */
int et_http(const char *verb, const char *url, const char *headers,
            const char *body, int bodylen, char *out, int outcap,
            int *status, int *needed, int verify, int timeout_ms)
{
  char  host[300], path[2048];
  int   port, secure, total = 0, over = 0;
  HANDLE hs = (HANDLE)NULLP, hc = (HANDLE)NULLP, hr = (HANDLE)NULLP;
  WCH   *wverb = (WCH *)NULLP, *wpath = (WCH *)NULLP, *whost = (WCH *)NULLP, *whdr = (WCH *)NULLP;
  DWORD  code = 0, codelen = 4, got = 0, flags;
  int    rc = ET_E_HTTPREQUEST;

  *status = 0; *needed = 0;
  rc = et_load_winhttp();
  if (rc != ET_OK) return rc;
  if (!et_split_url(url, host, (int)sizeof(host), &port, path, (int)sizeof(path), &secure))
    return ET_E_BADURL;

  {
    WCH *wagent = et_widen("emailTo/1.0 (Clarion)", -1);
    hs = p_HttpOpen(wagent, WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                    (const WCH *)NULLP, (const WCH *)NULLP, 0);
    if (!hs)   /* pre-Win8.1 has no automatic proxy resolution */
      hs = p_HttpOpen(wagent, WINHTTP_ACCESS_TYPE_NO_PROXY,
                      (const WCH *)NULLP, (const WCH *)NULLP, 0);
    if (wagent) free(wagent);
  }
  if (!hs) return ET_E_HTTPOPEN;
  if (p_HttpTimeout && timeout_ms > 0)
    p_HttpTimeout(hs, timeout_ms, timeout_ms, timeout_ms, timeout_ms);

  whost = et_widen(host, -1);
  hc = whost ? p_HttpConnect(hs, whost, (WORD)port, 0) : (HANDLE)NULLP;
  if (!hc) { rc = ET_E_HTTPCONNECT; goto done; }

  wverb = et_widen(verb, -1);
  wpath = et_widen(path, -1);
  flags = WINHTTP_FLAG_REFRESH | (secure ? WINHTTP_FLAG_SECURE : 0);
  hr = (wverb && wpath) ? p_HttpOpenReq(hc, wverb, wpath, (const WCH *)NULLP,
                                        (const WCH *)NULLP, (const WCH **)NULLP, flags)
                        : (HANDLE)NULLP;
  if (!hr) { rc = ET_E_HTTPREQUEST; goto done; }

  if (!verify && p_HttpOption) {
    DWORD ign = SECURITY_FLAG_IGNORE_ALL;
    p_HttpOption(hr, WINHTTP_OPTION_SECURITY_FLAGS, (void *)&ign, 4);
  }

  if (headers && headers[0]) whdr = et_widen(headers, -1);

  if (!p_HttpSend(hr, whdr, whdr ? (DWORD)-1L : 0,
                  (void *)((bodylen > 0) ? (void *)body : (void *)NULLP),
                  (DWORD)((bodylen > 0) ? bodylen : 0),
                  (DWORD)((bodylen > 0) ? bodylen : 0), 0)) {
    rc = ET_E_HTTPSEND; goto done;
  }
  if (!p_HttpRecv(hr, (void *)NULLP)) { rc = ET_E_HTTPRECV; goto done; }

  if (p_HttpQuery)
    p_HttpQuery(hr, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                (const WCH *)NULLP, (void *)&code, &codelen, (DWORD *)NULLP);
  *status = (int)code;

  for (;;) {
    char chunk[4096];
    got = 0;
    if (!p_HttpRead(hr, (void *)chunk, (DWORD)sizeof(chunk), &got)) break;
    if (got == 0) break;
    total += (int)got;
    if (total <= outcap) memcpy(out + total - (int)got, chunk, got);
    else over = 1;
  }
  *needed = total;
  rc = over ? ET_E_OVERFLOW : total;

done:
  if (hr) p_HttpClose(hr);
  if (hc) p_HttpClose(hc);
  if (hs) p_HttpClose(hs);
  if (wverb) free(wverb);
  if (wpath) free(wpath);
  if (whost) free(whost);
  if (whdr)  free(whdr);
  return rc;
}

/* =========================================================================
   7.  The OAuth2 loopback catcher.  Google and Microsoft both redirect a
       desktop app back to http://127.0.0.1:<port>/, so we listen on exactly
       one connection, read the GET line, answer with a "you can close this
       tab" page and hand the query string back to Clarion.
   ========================================================================= */
/* Returns the length of the query string (everything after the "?"), 0 on
   timeout, or a negative ET_E_ code.  `port` 0 asks the OS to pick a free
   port, which is then written back through *actualport.                   */
/*  Listen on BOTH loopbacks, on the same port.
 *
 *  This is not belt-and-braces.  Windows resolves "localhost" to ::1 FIRST, so
 *  a browser sent to http://localhost:<port> arrives over IPv6 and an
 *  IPv4-only listener never hears it - the sign-in simply hangs until it times
 *  out.  And the redirect URI is not ours to choose: Azure offers
 *  "http://localhost" as its desktop preset while Google documents
 *  "http://127.0.0.1".  Binding both means either registration works.
 *
 *  Both sockets bind the LOOPBACK address, never the wildcard.  A dual-stack
 *  wildcard socket would take IPv4 and IPv6 on one handle, but it would also
 *  be listening to the whole network - not a trade worth making for one
 *  redirect that arrives from this machine.
 */
int et_oauth_listen(int port, int *actualport)
{
  struct SOCKADDRIN  sa;
  struct SOCKADDRIN6 sa6;
  SOCKET s, s6;
  int    len, rc, id, off = 0;

  rc = et_load_ws2();
  if (rc != ET_OK) return rc;

  s = p_socket(ET_AF_INET, 1 /*SOCK_STREAM*/, 6);
  if (s == INVALID_SOCKET) return ET_E_BIND;

  memset(&sa, 0, sizeof(sa));
  sa.sin_family = ET_AF_INET;
  sa.sin_port   = p_htons((WORD)port);
  sa.sin_addr   = 0x0100007fUL;          /* 127.0.0.1, network byte order */

  if (p_bind(s, (const struct SOCKADDR *)&sa, (int)sizeof(sa)) != 0) {
    p_closesocket(s);
    return ET_E_BIND;
  }
  if (p_listen(s, 1) != 0) { p_closesocket(s); return ET_E_BIND; }

  len = (int)sizeof(sa);
  if (p_getsockname && p_getsockname(s, (struct SOCKADDR *)&sa, &len) == 0) {
    WORD nport = sa.sin_port;
    *actualport = (int)(WORD)(((nport & 0xff) << 8) | ((nport >> 8) & 0xff));
  } else {
    *actualport = port;
  }

  /*  Now ::1, on whatever port the first bind landed on.  If this fails we
   *  carry on with IPv4 alone rather than refusing to sign in at all - that is
   *  still the right answer for a 127.0.0.1 redirect. */
  s6 = p_socket(ET_AF_INET6, 1, 6);
  if (s6 != INVALID_SOCKET) {
    if (p_setsockopt)
      p_setsockopt(s6, ET_IPPROTO_IPV6, ET_IPV6_V6ONLY, (const char *)&off, 4);
    memset(&sa6, 0, sizeof(sa6));
    sa6.sin6_family   = ET_AF_INET6;
    sa6.sin6_port     = p_htons((WORD)*actualport);
    sa6.sin6_addr[15] = 1;               /* ::1 */
    if (p_bind(s6, (const struct SOCKADDR *)&sa6, (int)sizeof(sa6)) != 0 ||
        p_listen(s6, 1) != 0) {
      p_closesocket(s6);
      s6 = INVALID_SOCKET;
    }
  }

  id = et_newslot();
  if (id < 0) {
    p_closesocket(s);
    if (s6 != INVALID_SOCKET) p_closesocket(s6);
    return id;
  }
  g_conn[id-1].sock  = s;
  g_conn[id-1].sock6 = s6;
  g_conn[id-1].timeout_ms = 300000;      /* five minutes to finish signing in */
  return id;
}

/* Wait for the browser to arrive.  Fills `query` with what followed the "?"
   in the GET line.  Returns its length, 0 on timeout, negative on error. */
int et_oauth_wait(int id, char *query, int cap, int timeout_ms, const char *replyhtml)
{
  struct ET_CONN *c = et_slot(id);
  SOCKET cs;
  char   req[4096];
  char   resp[4096];
  int    n, i, qs, qe, hl, bl;
  struct FDSET fds;
  struct TIMEVAL tv;

  if (!c) return ET_E_BADID;

  /*  Watch both loopbacks and take whichever one the browser actually used. */
  fds.fd_count = 1; fds.fd_array[0] = c->sock;
  if (c->sock6 != INVALID_SOCKET) { fds.fd_array[1] = c->sock6; fds.fd_count = 2; }
  tv.tv_sec = timeout_ms / 1000; tv.tv_usec = (timeout_ms % 1000) * 1000;
  if (p_select(0, &fds, (struct FDSET *)NULLP, (struct FDSET *)NULLP, &tv) <= 0) return 0;

  /*  select() rewrites fd_array with just the ready sockets, so whatever is
   *  left in slot 0 is the one to accept on. */
  cs = p_accept(fds.fd_count ? fds.fd_array[0] : c->sock,
                (struct SOCKADDR *)NULLP, (int *)NULLP);
  if (cs == INVALID_SOCKET) return ET_E_ACCEPT;

  n = p_recv(cs, req, (int)sizeof(req) - 1, 0);
  if (n <= 0) { p_closesocket(cs); return ET_E_RECV; }
  req[n] = 0;

  /* answer first, so the browser never shows a connection error */
  bl = (int)strlen(replyhtml);
  hl = 0;
  {
    const char *h1 = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: ";
    const char *h2 = "\r\nConnection: close\r\n\r\n";
    char numbuf[16]; int v = bl, j = 0, k;
    memcpy(resp, h1, strlen(h1)); hl = (int)strlen(h1);
    if (v == 0) numbuf[j++] = '0';
    else { char t[12]; int m = 0;
           while (v > 0 && m < 11) { t[m++] = (char)('0' + (v % 10)); v /= 10; }
           while (m > 0) numbuf[j++] = t[--m]; }
    for (k = 0; k < j; k++) resp[hl++] = numbuf[k];
    memcpy(resp + hl, h2, strlen(h2)); hl += (int)strlen(h2);
    if (hl + bl < (int)sizeof(resp)) { memcpy(resp + hl, replyhtml, (unsigned int)bl); hl += bl; }
    p_send(cs, resp, hl, 0);
  }
  p_closesocket(cs);

  /* GET /?code=...&state=... HTTP/1.1 */
  qs = -1; qe = -1;
  for (i = 0; i < n; i++) {
    if (req[i] == '?') { qs = i + 1; break; }
    if (req[i] == '\r' || req[i] == '\n') break;
  }
  if (qs < 0) { if (cap > 0) query[0] = 0; return 0; }
  for (i = qs; i < n; i++) {
    if (req[i] == ' ' || req[i] == '\r' || req[i] == '\n') { qe = i; break; }
  }
  if (qe < 0) qe = n;
  if (qe - qs > cap - 1) qe = qs + cap - 1;
  memcpy(query, req + qs, (unsigned int)(qe - qs));
  query[qe - qs] = 0;
  return qe - qs;
}

/* =========================================================================
   8.  DPAPI.  A password or a refresh token sitting in a settings table is
       encrypted to the Windows user, so copying the row to another machine
       yields nothing.
   ========================================================================= */
struct DATA_BLOB { DWORD cbData; BYTE *pbData; };
typedef BOOL (WINAPI *PFN_CryptProtectData)(struct DATA_BLOB *, const WCH *, struct DATA_BLOB *,
                                            void *, void *, DWORD, struct DATA_BLOB *);
typedef BOOL (WINAPI *PFN_CryptUnprotectData)(struct DATA_BLOB *, WCH **, struct DATA_BLOB *,
                                              void *, void *, DWORD, struct DATA_BLOB *);
static PFN_CryptProtectData   p_Protect   = 0;
static PFN_CryptUnprotectData p_Unprotect = 0;

static int et_load_crypt32(void)
{
  if (p_Protect) return ET_OK;
  h_crypt32 = LoadLibraryA("crypt32.dll");
  if (!h_crypt32) return ET_E_NOCRYPT32;
  p_Protect   = (PFN_CryptProtectData)  GetProcAddress(h_crypt32, "CryptProtectData");
  p_Unprotect = (PFN_CryptUnprotectData)GetProcAddress(h_crypt32, "CryptUnprotectData");
  if (!p_Protect || !p_Unprotect) return ET_E_NOCRYPT32;
  return ET_OK;
}

#define CRYPTPROTECT_UI_FORBIDDEN 0x1

int et_protect(const char *in, int inlen, char *out, int outcap)
{
  struct DATA_BLOB bin, bout;
  int rc = et_load_crypt32();
  if (rc != ET_OK) return rc;
  bin.cbData = (DWORD)inlen; bin.pbData = (BYTE *)in;
  bout.cbData = 0; bout.pbData = (BYTE *)NULLP;
  if (!p_Protect(&bin, (const WCH *)NULLP, (struct DATA_BLOB *)NULLP, (void *)NULLP,
                 (void *)NULLP, CRYPTPROTECT_UI_FORBIDDEN, &bout))
    return ET_E_DPAPI;
  if ((int)bout.cbData > outcap) { LocalFree((void *)bout.pbData); return ET_E_OVERFLOW; }
  memcpy(out, bout.pbData, bout.cbData);
  rc = (int)bout.cbData;
  LocalFree((void *)bout.pbData);
  return rc;
}

int et_unprotect(const char *in, int inlen, char *out, int outcap)
{
  struct DATA_BLOB bin, bout;
  int rc = et_load_crypt32();
  if (rc != ET_OK) return rc;
  bin.cbData = (DWORD)inlen; bin.pbData = (BYTE *)in;
  bout.cbData = 0; bout.pbData = (BYTE *)NULLP;
  if (!p_Unprotect(&bin, (WCH **)NULLP, (struct DATA_BLOB *)NULLP, (void *)NULLP,
                   (void *)NULLP, CRYPTPROTECT_UI_FORBIDDEN, &bout))
    return ET_E_DPAPI;
  if ((int)bout.cbData > outcap) { LocalFree((void *)bout.pbData); return ET_E_OVERFLOW; }
  memcpy(out, bout.pbData, bout.cbData);
  rc = (int)bout.cbData;
  LocalFree((void *)bout.pbData);
  return rc;
}

/* =========================================================================
   9.  Open the consent screen in whatever browser the user actually uses.
   ========================================================================= */
typedef HANDLE (WINAPI *PFN_ShellExecuteA)(HANDLE, const char *, const char *, const char *,
                                           const char *, int);
static PFN_ShellExecuteA p_ShellExec = 0;

int et_open_url(const char *url)
{
  if (!p_ShellExec) {
    if (!h_shell32) h_shell32 = LoadLibraryA("shell32.dll");
    if (h_shell32) p_ShellExec = (PFN_ShellExecuteA)GetProcAddress(h_shell32, "ShellExecuteA");
  }
  if (!p_ShellExec) return -1;
  /* ShellExecute returns >32 on success */
  return ((int)(long)p_ShellExec((HANDLE)NULLP, "open", url, (const char *)NULLP,
                                 (const char *)NULLP, 1) > 32) ? ET_OK : -1;
}

/* A human-readable name for our own error codes.  Windows codes (SSPI,
   winsock) come back through et_lasterr and are formatted by Clarion. */
int et_errtext(int code, char *out, int cap)
{
  const char *s;
  int n;
  switch (code) {
    case ET_OK:            s = "OK"; break;
    case ET_E_NOWINSOCK:   s = "Winsock (ws2_32.dll) is not available"; break;
    case ET_E_NOSECUR32:   s = "SCHANNEL (secur32.dll) is not available"; break;
    case ET_E_NOWINHTTP:   s = "WinHTTP (winhttp.dll) is not available"; break;
    case ET_E_RESOLVE:     s = "The mail server name could not be resolved"; break;
    case ET_E_CONNECT:     s = "Could not connect to the mail server"; break;
    case ET_E_NOSLOT:      s = "Too many connections are open at once"; break;
    case ET_E_BADID:       s = "The connection is not open"; break;
    case ET_E_SEND:        s = "The connection failed while sending"; break;
    case ET_E_RECV:        s = "The connection failed while receiving"; break;
    case ET_E_CLOSED:      s = "The server closed the connection"; break;
    case ET_E_TIMEOUT:     s = "The server did not answer in time"; break;
    case ET_E_CRED:        s = "Windows would not supply TLS credentials"; break;
    case ET_E_HANDSHAKE:   s = "The TLS handshake failed"; break;
    case ET_E_STREAMSIZES: s = "TLS stream sizes could not be read"; break;
    case ET_E_ENCRYPT:     s = "TLS encryption failed"; break;
    case ET_E_DECRYPT:     s = "TLS decryption failed"; break;
    case ET_E_MEMORY:      s = "Out of memory"; break;
    case ET_E_OVERFLOW:    s = "The buffer was too small"; break;
    case ET_E_BADURL:      s = "The URL is not a valid http/https address"; break;
    case ET_E_HTTPOPEN:    s = "WinHTTP could not start a session"; break;
    case ET_E_HTTPCONNECT: s = "WinHTTP could not connect to the host"; break;
    case ET_E_HTTPREQUEST: s = "WinHTTP could not build the request"; break;
    case ET_E_HTTPSEND:    s = "WinHTTP could not send the request"; break;
    case ET_E_HTTPRECV:    s = "WinHTTP got no response"; break;
    case ET_E_BIND:        s = "The loopback port for the sign-in redirect is in use"; break;
    case ET_E_ACCEPT:      s = "The browser redirect was not received"; break;
    case ET_E_NOCRYPT32:   s = "DPAPI (crypt32.dll) is not available"; break;
    case ET_E_DPAPI:       s = "Windows could not encrypt or decrypt the stored secret"; break;
    case ET_E_NOTTLS:      s = "The connection is not secured"; break;
    case ET_E_ALREADYTLS:  s = "The connection is already secured"; break;
    default:               s = "Unknown error"; break;
  }
  n = (int)strlen(s);
  if (n > cap - 1) n = cap - 1;
  memcpy(out, s, (unsigned int)n);
  out[n] = 0;
  return n;
}

/* Close every connection - called from the class destructor so a program that
   forgets to close still releases its sockets and credential handles. */
void et_shutdown(void)
{
  int i;
  for (i = 1; i <= ET_MAXCONN; i++) et_close(i);
}

}   /* extern "C" - HTTP, OAuth, DPAPI, shell */

