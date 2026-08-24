! ============================================================================
!  EmailNetClass - implementation.
!
!  This is the ONLY module in emailTo that talks to C.  emailc.c is compiled
!  into the application by the PRAGMA below, so there is no DLL to ship and no
!  import library to find - the sockets, the SCHANNEL TLS handshake, WinHTTP,
!  DPAPI and SHA-256 all end up inside the .EXE.
!
!  Everything else in emailTo (SMTP, MIME, base64, OAuth2, JSON, the provider
!  presets, the windows) is pure Clarion and calls only the methods here.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  INCLUDE('EmailNetClass.INC'),ONCE
  INCLUDE('EmailMsgClass.INC'),ONCE                 ! EmailBufClass, for the signing buffers

ETN_Hex      STRING('0123456789ABCDEF')

!  Windows' own UTC clock. TODAY() and CLOCK() are LOCAL time, and a signature
!  built on local time is refused everywhere but London in winter.
ETN_SystemTime      GROUP,TYPE
wYear                 USHORT
wMonth                USHORT
wDayOfWeek            USHORT
wDay                  USHORT
wHour                 USHORT
wMinute               USHORT
wSecond               USHORT
wMilliseconds         USHORT
                    END               ! must precede the PRAGMA / prototypes

  PRAGMA('compile(emailc.c)')                     ! Clarion's own C compiler builds the network layer

  MAP                                             ! module-level MAP (folds BUILTINS.CLW + hosts emailc.c)
    MODULE('kernel32')
ETN_GetSystemTime PROCEDURE(*ETN_SystemTime),PASCAL,RAW,NAME('GetSystemTime')
    END
    MODULE('emailc.c')
et_open            PROCEDURE(*CSTRING,LONG,LONG,LONG,LONG),LONG,RAW,NAME('_et_open')
et_starttls        PROCEDURE(LONG,*CSTRING,LONG),LONG,RAW,NAME('_et_starttls')
et_send            PROCEDURE(LONG,*STRING,LONG),LONG,RAW,NAME('_et_send')
et_recvline        PROCEDURE(LONG,*CSTRING,LONG),LONG,RAW,NAME('_et_recvline')
et_recv            PROCEDURE(LONG,*STRING,LONG),LONG,RAW,NAME('_et_recv')
et_lasterr         PROCEDURE(LONG),LONG,NAME('_et_lasterr')
et_close           PROCEDURE(LONG),NAME('_et_close')
et_sha256          PROCEDURE(*STRING,LONG,*STRING),LONG,RAW,NAME('_et_sha256')
et_random          PROCEDURE(*STRING,LONG),LONG,RAW,NAME('_et_random')
et_http            PROCEDURE(*CSTRING,*CSTRING,*CSTRING,*STRING,LONG,*STRING,LONG,*LONG,*LONG,LONG,LONG),LONG,RAW,NAME('_et_http')
et_oauth_listen    PROCEDURE(LONG,*LONG),LONG,RAW,NAME('_et_oauth_listen')
et_oauth_wait      PROCEDURE(LONG,*CSTRING,LONG,LONG,*CSTRING),LONG,RAW,NAME('_et_oauth_wait')
et_protect         PROCEDURE(*STRING,LONG,*STRING,LONG),LONG,RAW,NAME('_et_protect')
et_unprotect       PROCEDURE(*STRING,LONG,*STRING,LONG),LONG,RAW,NAME('_et_unprotect')
et_open_url        PROCEDURE(*CSTRING),LONG,RAW,NAME('_et_open_url')
et_errtext         PROCEDURE(LONG,*CSTRING,LONG),LONG,RAW,NAME('_et_errtext')
et_shutdown        PROCEDURE(),NAME('_et_shutdown')
    END
  END

!=== lifecycle ===============================================================
EmailNetClass.Construct PROCEDURE
  CODE
  SELF.SgnBuf &= NEW(EmailBufClass)
  SELF.HexBuf &= NEW(EmailBufClass)
  SELF.Timeout       = 30000
  SELF.VerifyCert    = 1
  SELF.Trace         = 0
  SELF.HidePasswords = 1
  SELF.Conn          = 0
  SELF.RespCap       = 32768
  SELF.Response     &= NEW(STRING(SELF.RespCap))
  SELF.TraceQ       &= NEW(EmailTraceQueue)

EmailNetClass.Destruct PROCEDURE
  CODE
  IF NOT SELF.SgnBuf &= NULL THEN DISPOSE(SELF.SgnBuf).
  IF NOT SELF.HexBuf &= NULL THEN DISPOSE(SELF.HexBuf).
  SELF.Close()
  IF NOT SELF.Response &= NULL
    DISPOSE(SELF.Response)
  END
  IF NOT SELF.Scratch &= NULL
    DISPOSE(SELF.Scratch)
  END
  IF NOT SELF.TraceQ &= NULL
    FREE(SELF.TraceQ)
    DISPOSE(SELF.TraceQ)
  END

!  Make the class-owned return buffer at least pBytes long.  Called by every
!  method that returns a STRING it had to build.
EmailNetClass.NeedScratch PROCEDURE(LONG pBytes)
  CODE
  IF pBytes < 1 THEN pBytes = 1.
  IF SELF.ScratchCap >= pBytes AND NOT SELF.Scratch &= NULL THEN RETURN.
  IF NOT SELF.Scratch &= NULL
    DISPOSE(SELF.Scratch)
  END
  SELF.ScratchCap = pBytes + 256
  SELF.Scratch   &= NEW(STRING(SELF.ScratchCap))

!=== diagnostics =============================================================
EmailNetClass.SetErr PROCEDURE(LONG pCode)
txt CSTRING(161)
  CODE
  SELF.LastError = pCode
  IF pCode < 0
    et_errtext(pCode, txt, SIZE(txt))
    SELF.LastErrorText = txt
    IF SELF.Conn
      SELF.LastWinError = et_lasterr(SELF.Conn)
    END
    IF SELF.Trace
      IF SELF.LastWinError
        SELF.AddTrace('*** ' & CLIP(SELF.LastErrorText) & ' (Windows code ' & SELF.LastWinError & ')')
      ELSE
        SELF.AddTrace('*** ' & CLIP(SELF.LastErrorText))
      END
    END
  ELSE
    SELF.LastErrorText = ''
    SELF.LastWinError  = 0
  END
  RETURN pCode

EmailNetClass.AddTrace PROCEDURE(STRING pLine)
  CODE
  IF NOT SELF.Trace OR SELF.TraceQ &= NULL THEN RETURN.
  SELF.TraceQ.Line = pLine
  ADD(SELF.TraceQ)

EmailNetClass.ClearTrace PROCEDURE
  CODE
  IF NOT SELF.TraceQ &= NULL THEN FREE(SELF.TraceQ).

EmailNetClass.TraceText PROCEDURE()
len  LONG
lineLen LONG
i    LONG
n    LONG
  CODE
  IF SELF.TraceQ &= NULL OR NOT RECORDS(SELF.TraceQ)
    RETURN ''
  END
  LOOP i = 1 TO RECORDS(SELF.TraceQ)
    GET(SELF.TraceQ, i)
    len += LEN(CLIP(SELF.TraceQ.Line)) + 2
  END
  SELF.NeedScratch(len)
  LOOP i = 1 TO RECORDS(SELF.TraceQ)
    GET(SELF.TraceQ, i)
    lineLen = LEN(CLIP(SELF.TraceQ.Line))
    IF lineLen > 0
      SELF.Scratch[n+1 : n+lineLen] = SELF.TraceQ.Line[1 : lineLen]
      n += lineLen
    END
    SELF.Scratch[n+1 : n+2] = '<13,10>'
    n += 2
  END
  IF n < 1 THEN RETURN ''.
  RETURN SELF.Scratch[1 : n]

!=== the socket conversation =================================================
EmailNetClass.Open PROCEDURE(STRING pHost,LONG pPort,BYTE pTls=0)
host CSTRING(300)
rc   LONG
  CODE
  SELF.Close()
  host = CLIP(pHost)
  IF SELF.Trace
    SELF.AddTrace('--- connect ' & CLIP(pHost) & ':' & pPort & CHOOSE(pTls=0,'',' (TLS)'))
  END
  rc = et_open(host, pPort, pTls, SELF.VerifyCert, SELF.Timeout)
  IF rc < 0
    SELF.Conn = 0
    SELF.SetErr(rc)
    SELF.LastWinError = et_lasterr(0)             ! the connect / handshake had no slot
    IF SELF.LastWinError AND SELF.Trace
      SELF.AddTrace('*** Windows code ' & SELF.LastWinError)
    END
    RETURN 0
  END
  SELF.Conn   = rc
  SELF.Secure = pTls
  SELF.SetErr(ETNet:Ok)
  RETURN 1

EmailNetClass.StartTls PROCEDURE(STRING pHost)
host CSTRING(300)
rc   LONG
  CODE
  IF NOT SELF.Conn
    SELF.SetErr(ETNet:BadId)
    RETURN 0
  END
  host = CLIP(pHost)
  SELF.AddTrace('--- STARTTLS handshake with ' & CLIP(pHost))
  rc = et_starttls(SELF.Conn, host, SELF.VerifyCert)
  IF rc < 0
    SELF.SetErr(rc)
    RETURN 0
  END
  SELF.Secure = 1
  SELF.SetErr(ETNet:Ok)
  RETURN 1

EmailNetClass.Send PROCEDURE(STRING pData)
buf  &STRING
n    LONG
rc   LONG
  CODE
  IF NOT SELF.Conn
    SELF.SetErr(ETNet:BadId)
    RETURN 0
  END
  n = SIZE(pData)
  IF n < 1 THEN RETURN 1.
  buf &= NEW(STRING(n))                            ! RAW needs a real variable, not a slice
  buf[1 : n] = pData[1 : n]
  rc = et_send(SELF.Conn, buf, n)
  DISPOSE(buf)
  IF rc < 0
    SELF.SetErr(rc)
    RETURN 0
  END
  SELF.SetErr(ETNet:Ok)
  RETURN 1

!  pSecret marks a line that carries a credential (an AUTH argument, a
!  base64 password, an OAuth bearer token).  With HidePasswords on - the
!  default - it is written to the transcript as asterisks, so a customer can
!  mail you the log of a failed send without mailing you their password too.
EmailNetClass.SendLine PROCEDURE(STRING pLine,BYTE pSecret=0)
  CODE
  IF SELF.Trace
    IF pSecret AND SELF.HidePasswords
      SELF.AddTrace('C: ******** (' & LEN(CLIP(pLine)) & ' characters, hidden)')
    ELSE
      SELF.AddTrace('C: ' & CLIP(pLine))
    END
  END
  RETURN SELF.Send(CLIP(pLine) & '<13,10>')

EmailNetClass.RecvLine PROCEDURE()
line CSTRING(ETNet:MaxLine)
rc   LONG
  CODE
  IF NOT SELF.Conn
    SELF.SetErr(ETNet:BadId)
    RETURN ''
  END
  rc = et_recvline(SELF.Conn, line, SIZE(line))
  IF rc < 0
    SELF.SetErr(rc)
    RETURN ''
  END
  IF rc = 0 AND line = ''
    SELF.SetErr(ETNet:Ok)
    SELF.AddTrace('S: <empty>')
    RETURN ''
  END
  SELF.SetErr(ETNet:Ok)
  SELF.AddTrace('S: ' & line)
  RETURN line

EmailNetClass.Close PROCEDURE
  CODE
  IF SELF.Conn
    et_close(SELF.Conn)
    SELF.Conn   = 0
    SELF.Secure = 0
  END

EmailNetClass.IsOpen PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.Conn > 0, 1, 0)

!=== HTTPS ===================================================================
EmailNetClass.Http PROCEDURE(STRING pVerb,STRING pUrl,STRING pHeaders,STRING pBody)
verb    CSTRING(16)
url     &CSTRING
hdr     &CSTRING
body    &STRING
blen    LONG
status  LONG
needed  LONG
rc      LONG
tries   BYTE
  CODE
  verb = CLIP(pVerb)
  url &= NEW(CSTRING(LEN(CLIP(pUrl)) + 1))
  url  = CLIP(pUrl)
  hdr &= NEW(CSTRING(LEN(CLIP(pHeaders)) + 1))
  hdr  = CLIP(pHeaders)
  blen = SIZE(pBody)
  IF blen < 0 THEN blen = 0.
  body &= NEW(STRING(blen + 1))
  IF blen > 0 THEN body[1 : blen] = pBody[1 : blen].

  SELF.AddTrace('--- ' & CLIP(pVerb) & ' ' & CLIP(pUrl))

  LOOP tries = 1 TO 2
    rc = et_http(verb, url, hdr, body, blen, SELF.Response, SELF.RespCap, |
                 status, needed, SELF.VerifyCert, SELF.Timeout)
    IF rc = ETNet:Overflow AND needed > 0 AND tries = 1
      DISPOSE(SELF.Response)
      SELF.RespCap   = needed + 1024
      SELF.Response &= NEW(STRING(SELF.RespCap))
      CYCLE
    END
    BREAK
  END

  DISPOSE(url)
  DISPOSE(hdr)
  DISPOSE(body)

  IF rc < 0
    SELF.RespLen = 0
    SELF.Status  = 0
    SELF.SetErr(rc)
    RETURN rc
  END
  SELF.RespLen = rc
  SELF.Status  = status
  SELF.SetErr(ETNet:Ok)
  SELF.AddTrace('--- HTTP ' & status & ', ' & rc & ' bytes')
  RETURN status

EmailNetClass.Body PROCEDURE()
  CODE
  IF SELF.RespLen < 1 OR SELF.Response &= NULL
    RETURN ''
  END
  RETURN SELF.Response[1 : SELF.RespLen]


! ============================================================================
!  Signing - Amazon SES, and nobody else
!
!  Every other provider takes a key in a header. Amazon signs the request:
!  the verb, the path, the query, a chosen set of headers and a hash of the
!  body, all with a key derived from the secret, the date, the region and the
!  service. Get one byte of it wrong and the answer is a flat 403 that says
!  nothing useful, so every piece below is checked against a vector Amazon or
!  the RFC publishes.
! ============================================================================
!  HMAC-SHA256, on top of the SHA-256 emailc.c already provides.
!      HMAC(K,m) = H( (K^opad) || H( (K^ipad) || m ) )
!  The digests are copied into locals the moment they come back: Sha256 builds
!  its answer in a buffer the object owns, so a second call would overwrite
!  the first one while it was still needed.
EmailNetClass.Hmac256 PROCEDURE(STRING pKey,STRING pData)
key    STRING(64)
inner  STRING(32)
block  &STRING
n      LONG
i      LONG
  CODE
  !  ZERO-filled, not blank-filled. `key = ''` pads a Clarion STRING with
  !  SPACES, and a key padded with 20h instead of 00h produces a perfectly
  !  plausible digest that matches nothing on earth.
  LOOP i = 1 TO 64
    key[i] = CHR(0)
  END
  n = SIZE(pKey)
  IF n > 64
    inner = SELF.Sha256(pKey)                     ! a long key is hashed first
    key[1 : 32] = inner[1 : 32]
  ELSIF n > 0
    key[1 : n] = pKey[1 : n]
  END

  block &= NEW(STRING(64 + SIZE(pData)))
  LOOP i = 1 TO 64
    block[i] = CHR(BXOR(VAL(key[i]), 36h))            ! the inner pad
  END
  IF SIZE(pData) > 0
    block[65 : 64 + SIZE(pData)] = pData[1 : SIZE(pData)]
  END
  inner = SELF.Sha256(block[1 : 64 + SIZE(pData)])
  DISPOSE(block)

  block &= NEW(STRING(96))
  LOOP i = 1 TO 64
    block[i] = CHR(BXOR(VAL(key[i]), 5Ch))            ! and the outer
  END
  block[65 : 96] = inner[1 : 32]
  SELF.SgnBuf.ClearAll()
  SELF.SgnBuf.Add(SELF.Sha256(block[1 : 96]))
  DISPOSE(block)
  RETURN SELF.SgnBuf.Value()

EmailNetClass.HexOf PROCEDURE(STRING pRaw)
i LONG
n LONG
b LONG
  CODE
  SELF.HexBuf.ClearAll()
  n = SIZE(pRaw)
  LOOP i = 1 TO n
    b = VAL(pRaw[i])
    SELF.HexBuf.Add(LOWER(ETN_Hex[BSHIFT(b, -4) + 1] & ETN_Hex[BAND(b, 15) + 1]))
  END
  RETURN SELF.HexBuf.Value()

EmailNetClass.Sha256Hex PROCEDURE(STRING pData)
raw STRING(32)
  CODE
  raw = SELF.Sha256(pData)
  RETURN SELF.HexOf(raw[1 : 32])

!  The four-step derivation. Each answer is 32 raw bytes and feeds the next,
!  so each one is copied out before the next call reuses the buffer.
EmailNetClass.SigningKey PROCEDURE(STRING pSecret,STRING pDate,STRING pRegion,STRING pService)
k STRING(32)
  CODE
  k = SELF.Hmac256('AWS4' & CLIP(pSecret), CLIP(pDate))
  k = SELF.Hmac256(k[1 : 32], CLIP(pRegion))
  k = SELF.Hmac256(k[1 : 32], CLIP(pService))
  k = SELF.Hmac256(k[1 : 32], 'aws4_request')
  SELF.SgnBuf.ClearAll()
  SELF.SgnBuf.Add(k[1 : 32])
  RETURN SELF.SgnBuf.Value()

!  UTC, straight from Windows. TODAY() and CLOCK() are LOCAL time, and a
!  signature built on local time is refused everywhere east or west of London.
EmailNetClass.AmzStamp PROCEDURE()
st LIKE(ETN_SystemTime)
  CODE
  ETN_GetSystemTime(st)
  RETURN FORMAT(st.wYear, @n04) & FORMAT(st.wMonth, @n02) & FORMAT(st.wDay, @n02) & 'T' & |
         FORMAT(st.wHour, @n02) & FORMAT(st.wMinute, @n02) & FORMAT(st.wSecond, @n02) & 'Z'

!  SigV4 wants each path segment encoded ONCE MORE than it already is (S3 is
!  the exception, and this is not S3). Our paths arrive with the address
!  already percent-encoded, so this is what turns %40 into %2540 - which is
!  what Amazon re-derives at its end.
EmailNetClass.CanonPath PROCEDURE(STRING pPath)
i LONG
n LONG
b LONG
  CODE
  SELF.SgnBuf.ClearAll()
  n = LEN(CLIP(pPath))
  IF n < 1
    SELF.SgnBuf.Add('/')
    RETURN SELF.SgnBuf.Value()
  END
  LOOP i = 1 TO n
    b = VAL(pPath[i])
    IF b = 47                                          ! keep the separators
      SELF.SgnBuf.Add('/')
      CYCLE
    END
    IF (b >= 48 AND b <= 57) OR (b >= 65 AND b <= 90) OR (b >= 97 AND b <= 122) |
       OR b = 45 OR b = 46 OR b = 95 OR b = 126
      SELF.SgnBuf.Add(pPath[i])
    ELSE
      SELF.SgnBuf.Add('%' & ETN_Hex[BSHIFT(b, -4) + 1] & ETN_Hex[BAND(b, 15) + 1])
    END
  END
  RETURN SELF.SgnBuf.Value()

!  Sorted by parameter name, which is what the canonical request is: a form
!  both ends can arrive at independently.
EmailNetClass.CanonQuery PROCEDURE(STRING pQuery)
Q     QUEUE,PRE(CQ)
Pair    STRING(256)
      END
one   CSTRING(257)
rest  CSTRING(1025)
p     LONG
i     LONG
  CODE
  FREE(Q)
  rest = CLIP(pQuery)
  LOOP WHILE CLIP(rest)
    p = INSTRING('&', rest, 1, 1)
    IF p
      one  = rest[1 : p - 1]
      rest = rest[p + 1 : LEN(CLIP(rest))]
    ELSE
      one  = rest
      rest = ''
    END
    IF CLIP(one)
      IF NOT INSTRING('=', one, 1, 1)
        one = CLIP(one) & '='                          ! a bare flag still needs one
      END
      CQ:Pair = one
      ADD(Q, CQ:Pair)
    END
  END
  SELF.SgnBuf.ClearAll()
  LOOP i = 1 TO RECORDS(Q)
    GET(Q, i)
    IF i > 1 THEN SELF.SgnBuf.Add('&').
    SELF.SgnBuf.Add(CLIP(CQ:Pair))
  END
  RETURN SELF.SgnBuf.Value()

!  The whole Authorization block for one request, signed. A pure function of
!  what it is given: no account, no provider, nothing to set up first - which
!  is what makes it testable against Amazon's published example, and what lets
!  both EmailToClass (sending) and EmailApiClass (asking) call the same one.
EmailNetClass.SignAws PROCEDURE(STRING pVerb,STRING pUrl,STRING pBody,STRING pKeyId,|
                                STRING pSecret,STRING pRegion,STRING pService)
host   CSTRING(129)
path   CSTRING(513)
query  CSTRING(1025)
stamp  CSTRING(33)
datest CSTRING(9)
scope  CSTRING(129)
canon  &EmailBufClass
sts    CSTRING(513)
kSign  STRING(32)
sig    CSTRING(129)
url    CSTRING(1025)
p      LONG
q      LONG
  CODE
  url = CLIP(pUrl)
  p   = INSTRING('://', url, 1, 1)
  IF p THEN url = url[p + 3 : LEN(CLIP(url))].
  p = INSTRING('/', url, 1, 1)
  IF p
    host = url[1 : p - 1]
    path = url[p : LEN(CLIP(url))]
  ELSE
    host = url
    path = '/'
  END
  q = INSTRING('?', path, 1, 1)
  IF q
    query = path[q + 1 : LEN(CLIP(path))]
    path  = path[1 : q - 1]
  ELSE
    query = ''
  END

  stamp  = SELF.AmzStamp()
  datest = stamp[1 : 8]
  scope  = CLIP(datest) & '/' & CLIP(pRegion) & '/' & CLIP(pService) & '/aws4_request'

  canon &= NEW(EmailBufClass)
  canon.Add(UPPER(CLIP(pVerb)) & '<10>')
  canon.Add(SELF.CanonPath(path) & '<10>')
  canon.Add(SELF.CanonQuery(query) & '<10>')
  canon.Add('host:' & CLIP(host) & '<10>x-amz-date:' & CLIP(stamp) & '<10><10>')
  canon.Add('host;x-amz-date<10>')
  canon.Add(SELF.Sha256Hex(pBody))

  sts = 'AWS4-HMAC-SHA256<10>' & CLIP(stamp) & '<10>' & CLIP(scope) & '<10>' & |
        SELF.Sha256Hex(canon.Value())
  DISPOSE(canon)

  kSign = SELF.SigningKey(pSecret, datest, pRegion, pService)
  sig   = SELF.HexOf(SELF.Hmac256(kSign[1 : 32], sts))

  SELF.SgnBuf.ClearAll()
  SELF.SgnBuf.Add('Authorization: AWS4-HMAC-SHA256 Credential=' & CLIP(pKeyId) & '/' & |
                  CLIP(scope) & ', SignedHeaders=host;x-amz-date, Signature=' & |
                  CLIP(sig) & '<13,10>')
  SELF.SgnBuf.Add('x-amz-date: ' & CLIP(stamp))
  RETURN SELF.SgnBuf.Value()

!=== OAuth2 plumbing =========================================================
EmailNetClass.OAuthListen PROCEDURE(LONG pPort,*LONG pActualPort)
rc LONG
  CODE
  rc = et_oauth_listen(pPort, pActualPort)
  IF rc < 0
    SELF.SetErr(rc)
    RETURN rc
  END
  SELF.AddTrace('--- listening on http://127.0.0.1:' & pActualPort & '/ for the sign-in redirect')
  RETURN rc

EmailNetClass.OAuthWait PROCEDURE(LONG pId,LONG pSeconds,STRING pReplyHtml)
query CSTRING(4096)
html  &CSTRING
rc    LONG
  CODE
  html &= NEW(CSTRING(LEN(CLIP(pReplyHtml)) + 1))
  html  = CLIP(pReplyHtml)
  rc = et_oauth_wait(pId, query, SIZE(query), pSeconds * 1000, html)
  DISPOSE(html)
  IF rc < 0
    SELF.SetErr(rc)
    RETURN ''
  END
  IF rc = 0
    SELF.SetErr(ETNet:Timeout)
    RETURN ''
  END
  SELF.SetErr(ETNet:Ok)
  RETURN query

EmailNetClass.OAuthStop PROCEDURE(LONG pId)
  CODE
  IF pId > 0 THEN et_close(pId).

EmailNetClass.OpenUrl PROCEDURE(STRING pUrl)
url &CSTRING
rc  LONG
  CODE
  url &= NEW(CSTRING(LEN(CLIP(pUrl)) + 1))
  url  = CLIP(pUrl)
  rc = et_open_url(url)
  DISPOSE(url)
  RETURN CHOOSE(rc = 0, 1, 0)

!=== crypto helpers ==========================================================
EmailNetClass.Sha256 PROCEDURE(STRING pData)
inb  &STRING
out  STRING(32)
n    LONG
  CODE
  n = SIZE(pData)
  inb &= NEW(STRING(n + 1))
  IF n > 0 THEN inb[1 : n] = pData[1 : n].
  et_sha256(inb, n, out)
  DISPOSE(inb)
  SELF.BinLen = 32
  RETURN out

EmailNetClass.RandomBytes PROCEDURE(LONG pLen)
  CODE
  IF pLen < 1 THEN RETURN ''.
  SELF.NeedScratch(pLen)
  et_random(SELF.Scratch, pLen)
  SELF.BinLen = pLen
  RETURN SELF.Scratch[1 : pLen]

EmailNetClass.Protect PROCEDURE(STRING pData)
inb &STRING
n   LONG
rc  LONG
  CODE
  n = SIZE(pData)
  IF n < 1 THEN RETURN ''.
  inb &= NEW(STRING(n))
  inb[1 : n] = pData[1 : n]
  SELF.NeedScratch(n + 1024)
  rc = et_protect(inb, n, SELF.Scratch, SELF.ScratchCap)
  DISPOSE(inb)
  IF rc < 1
    SELF.BinLen = 0
    SELF.SetErr(rc)
    RETURN ''
  END
  SELF.BinLen = rc
  SELF.SetErr(ETNet:Ok)
  RETURN SELF.Scratch[1 : rc]

EmailNetClass.Unprotect PROCEDURE(STRING pData)
inb &STRING
n   LONG
rc  LONG
  CODE
  n = SIZE(pData)
  IF n < 1 THEN RETURN ''.
  inb &= NEW(STRING(n))
  inb[1 : n] = pData[1 : n]
  SELF.NeedScratch(n + 256)
  rc = et_unprotect(inb, n, SELF.Scratch, SELF.ScratchCap)
  DISPOSE(inb)
  IF rc < 1
    SELF.BinLen = 0
    SELF.SetErr(rc)
    RETURN ''
  END
  SELF.BinLen = rc
  SELF.SetErr(ETNet:Ok)
  RETURN SELF.Scratch[1 : rc]
