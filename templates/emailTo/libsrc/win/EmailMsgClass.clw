! ============================================================================
!  EmailMsgClass - implementation.  Pure Clarion; no C, no DLL.
!
!  The only Windows calls here are CreateFile/ReadFile (to load an attachment)
!  and GetTimeZoneInformation (for the Date: header offset) - both kernel32,
!  both resolved by the Clarion linker with no import library.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  INCLUDE('EmailMsgClass.INC'),ONCE

ET_SystemTime       GROUP,TYPE
wYear                USHORT
wMonth               USHORT
wDayOfWeek           USHORT
wDay                 USHORT
wHour                USHORT
wMinute              USHORT
wSecond              USHORT
wMilliseconds        USHORT
                   END

ET_TimeZoneInfo     GROUP,TYPE
Bias                 LONG
StandardName         USHORT,DIM(32)
StandardDate         LIKE(ET_SystemTime)
StandardBias         LONG
DaylightName         USHORT,DIM(32)
DaylightDate         LIKE(ET_SystemTime)
DaylightBias         LONG
                   END

  MAP
    MODULE('kernel32')
GetTimeZoneInformation PROCEDURE(*ET_TimeZoneInfo),LONG,PROC,RAW,PASCAL,NAME('GetTimeZoneInformation')
CreateFileA            PROCEDURE(*CSTRING,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,PASCAL,RAW,NAME('CreateFileA')
GetFileSize            PROCEDURE(LONG,LONG),ULONG,PASCAL,NAME('GetFileSize')
ReadFile               PROCEDURE(LONG,*STRING,ULONG,*ULONG,LONG),LONG,PROC,PASCAL,RAW,NAME('ReadFile')
CloseHandle            PROCEDURE(LONG),LONG,PROC,PASCAL,NAME('CloseHandle')
GetCurrentProcessId    PROCEDURE(),ULONG,PASCAL,NAME('GetCurrentProcessId')
GetTickCount           PROCEDURE(),ULONG,PASCAL,NAME('GetTickCount')
    END
  END

ET_GENERIC_READ           EQUATE(80000000h)
ET_FILE_SHARE_READ        EQUATE(1)
ET_OPEN_EXISTING          EQUATE(3)
ET_FILE_ATTR_NORMAL  EQUATE(80h)
ET_INVALID_HANDLE   EQUATE(-1)

ET_B64Tbl  STRING('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/')
ET_HexTbl  STRING('0123456789ABCDEF')
ET_DowTbl  STRING('SatSunMonTueWedThuFri')                 ! Zeller: 0 = Saturday
ET_MonTbl  STRING('JanFebMarAprMayJunJulAugSepOctNovDec')

!  Windows-1252 has 27 characters in 80h..9Fh that are NOT Latin-1 - the euro
!  sign, curly quotes, the em dash.  Everything else in A0h..FFh maps straight
!  to the same Unicode code point.  0 marks the five undefined slots.
ET_Cp1252Hi  LONG,DIM(32)

!  Clarion's RANDOM is NOT seeded: every run of every program produces the
!  same sequence, so the first Message-ID and the first MIME boundary a
!  process makes are byte-identical to every other process's first ones.
!  Two copies of an application sending inside the same clock tick would
!  then emit the same Message-ID, which a mail server is entitled to treat
!  as a duplicate and drop.  The process id fixes that: it is unique among
!  everything running, and with the tick count and a per-process counter the
!  three together cannot repeat.
ET_Serial    LONG

! ============================================================================
!  EmailBufClass
! ============================================================================
EmailBufClass.Construct PROCEDURE
  CODE
  SELF.Cap  = 1024
  SELF.Len  = 0
  SELF.Buf &= NEW(STRING(SELF.Cap))

EmailBufClass.Destruct PROCEDURE
  CODE
  IF NOT SELF.Buf &= NULL
    DISPOSE(SELF.Buf)
  END

!  Double until it fits.  Growing by a fixed amount would make building a big
!  attachment quadratic, which is the whole reason this class exists.
EmailBufClass.Need PROCEDURE(LONG pExtra)
newCap LONG
newBuf &STRING
  CODE
  IF SELF.Len + pExtra <= SELF.Cap THEN RETURN.
  newCap = SELF.Cap
  LOOP WHILE newCap < SELF.Len + pExtra
    newCap = newCap * 2
  END
  newBuf &= NEW(STRING(newCap))
  IF SELF.Len > 0
    newBuf[1 : SELF.Len] = SELF.Buf[1 : SELF.Len]
  END
  DISPOSE(SELF.Buf)
  SELF.Buf &= newBuf
  SELF.Cap  = newCap

EmailBufClass.Add PROCEDURE(STRING pData)
n LONG
  CODE
  n = SIZE(pData)
  IF n < 1 THEN RETURN.
  SELF.Need(n)
  SELF.Buf[SELF.Len+1 : SELF.Len+n] = pData[1 : n]
  SELF.Len += n

EmailBufClass.AddLen PROCEDURE(*STRING pData,LONG pLen)
  CODE
  IF pLen < 1 THEN RETURN.
  SELF.Need(pLen)
  SELF.Buf[SELF.Len+1 : SELF.Len+pLen] = pData[1 : pLen]
  SELF.Len += pLen

EmailBufClass.AddLine PROCEDURE(STRING pLine)
  CODE
  SELF.Add(pLine)
  SELF.Add('<13,10>')

EmailBufClass.ClearAll PROCEDURE
  CODE
  SELF.Len = 0

EmailBufClass.Value PROCEDURE()
  CODE
  IF SELF.Len < 1 THEN RETURN ''.
  RETURN SELF.Buf[1 : SELF.Len]

! ============================================================================
!  EmailMsgClass - lifecycle
! ============================================================================
EmailMsgClass.Construct PROCEDURE
  CODE
  SELF.AddrQ    &= NEW(EmailAddrQueue)
  SELF.AttachQ  &= NEW(EmailAttachQueue)
  SELF.HeaderQ  &= NEW(EmailHeaderQueue)
  SELF.TextBody &= NEW(EmailBufClass)
  SELF.HtmlBody &= NEW(EmailBufClass)
  SELF.Mime     &= NEW(EmailBufClass)
  SELF.EncBuf   &= NEW(EmailBufClass)
  SELF.DecBuf   &= NEW(EmailBufClass)
  SELF.QpBuf    &= NEW(EmailBufClass)
  SELF.U8Buf    &= NEW(EmailBufClass)
  SELF.HdrBuf   &= NEW(EmailBufClass)
  SELF.JsnBuf   &= NEW(EmailBufClass)
  SELF.ListBuf  &= NEW(EmailBufClass)
  SELF.CharSet   = ETChs:Utf8
  SELF.OwnMessageId = 1
  SELF.Priority  = ETPri:Normal
  SELF.MaxSize   = 0
  DO BuildCp1252
  RETURN

BuildCp1252 ROUTINE
  !  80h..9Fh, in order.  Zero = the slot is undefined in Windows-1252.
  ET_Cp1252Hi[1]  = 20ACh                                 ! 80 euro
  ET_Cp1252Hi[2]  = 0
  ET_Cp1252Hi[3]  = 201Ah                                 ! 82 single low quote
  ET_Cp1252Hi[4]  = 0192h                                 ! 83 florin
  ET_Cp1252Hi[5]  = 201Eh                                 ! 84 double low quote
  ET_Cp1252Hi[6]  = 2026h                                 ! 85 ellipsis
  ET_Cp1252Hi[7]  = 2020h                                 ! 86 dagger
  ET_Cp1252Hi[8]  = 2021h                                 ! 87 double dagger
  ET_Cp1252Hi[9]  = 02C6h                                 ! 88 circumflex
  ET_Cp1252Hi[10] = 2030h                                 ! 89 per mille
  ET_Cp1252Hi[11] = 0160h                                 ! 8A S caron
  ET_Cp1252Hi[12] = 2039h                                 ! 8B single left angle quote
  ET_Cp1252Hi[13] = 0152h                                 ! 8C OE
  ET_Cp1252Hi[14] = 0
  ET_Cp1252Hi[15] = 017Dh                                 ! 8E Z caron
  ET_Cp1252Hi[16] = 0
  ET_Cp1252Hi[17] = 0
  ET_Cp1252Hi[18] = 2018h                                 ! 91 left single quote
  ET_Cp1252Hi[19] = 2019h                                 ! 92 right single quote
  ET_Cp1252Hi[20] = 201Ch                                 ! 93 left double quote
  ET_Cp1252Hi[21] = 201Dh                                 ! 94 right double quote
  ET_Cp1252Hi[22] = 2022h                                 ! 95 bullet
  ET_Cp1252Hi[23] = 2013h                                 ! 96 en dash
  ET_Cp1252Hi[24] = 2014h                                 ! 97 em dash
  ET_Cp1252Hi[25] = 02DCh                                 ! 98 small tilde
  ET_Cp1252Hi[26] = 2122h                                 ! 99 trade mark
  ET_Cp1252Hi[27] = 0161h                                 ! 9A s caron
  ET_Cp1252Hi[28] = 203Ah                                 ! 9B single right angle quote
  ET_Cp1252Hi[29] = 0153h                                 ! 9C oe
  ET_Cp1252Hi[30] = 0
  ET_Cp1252Hi[31] = 017Eh                                 ! 9E z caron
  ET_Cp1252Hi[32] = 0178h                                 ! 9F Y diaeresis

EmailMsgClass.Destruct PROCEDURE
i LONG
  CODE
  IF NOT SELF.AttachQ &= NULL
    LOOP i = 1 TO RECORDS(SELF.AttachQ)
      GET(SELF.AttachQ, i)
      IF NOT SELF.AttachQ.Data &= NULL
        DISPOSE(SELF.AttachQ.Data)
      END
    END
    FREE(SELF.AttachQ)
    DISPOSE(SELF.AttachQ)
  END
  IF NOT SELF.AddrQ &= NULL
    FREE(SELF.AddrQ); DISPOSE(SELF.AddrQ)
  END
  IF NOT SELF.HeaderQ &= NULL
    FREE(SELF.HeaderQ); DISPOSE(SELF.HeaderQ)
  END
  IF NOT SELF.TextBody &= NULL THEN DISPOSE(SELF.TextBody).
  IF NOT SELF.HtmlBody &= NULL THEN DISPOSE(SELF.HtmlBody).
  IF NOT SELF.Mime     &= NULL THEN DISPOSE(SELF.Mime).
  IF NOT SELF.EncBuf   &= NULL THEN DISPOSE(SELF.EncBuf).
  IF NOT SELF.DecBuf   &= NULL THEN DISPOSE(SELF.DecBuf).
  IF NOT SELF.QpBuf    &= NULL THEN DISPOSE(SELF.QpBuf).
  IF NOT SELF.U8Buf    &= NULL THEN DISPOSE(SELF.U8Buf).
  IF NOT SELF.HdrBuf   &= NULL THEN DISPOSE(SELF.HdrBuf).
  IF NOT SELF.JsnBuf   &= NULL THEN DISPOSE(SELF.JsnBuf).
  IF NOT SELF.ListBuf  &= NULL THEN DISPOSE(SELF.ListBuf).

EmailMsgClass.ClearAll PROCEDURE
i LONG
  CODE
  SELF.FromAddr    = ''
  SELF.FromName    = ''
  SELF.ReplyTo     = ''
  SELF.Subject     = ''
  SELF.MessageId   = ''
  SELF.Priority    = ETPri:Normal
  SELF.ReadReceipt = 0
  SELF.LastError   = 0
  SELF.LastErrorText = ''
  FREE(SELF.AddrQ)
  FREE(SELF.HeaderQ)
  LOOP i = 1 TO RECORDS(SELF.AttachQ)
    GET(SELF.AttachQ, i)
    IF NOT SELF.AttachQ.Data &= NULL
      DISPOSE(SELF.AttachQ.Data)
    END
  END
  FREE(SELF.AttachQ)
  SELF.TextBody.ClearAll()
  SELF.HtmlBody.ClearAll()
  SELF.Mime.ClearAll()

EmailMsgClass.SetErr PROCEDURE(LONG pCode,<STRING pText>)
  CODE
  SELF.LastError = pCode
  IF OMITTED(pText)
    CASE pCode
    OF ETMsg:Ok            ; SELF.LastErrorText = ''
    OF ETMsg:NoFrom        ; SELF.LastErrorText = 'The message has no From address.'
    OF ETMsg:NoRecipient   ; SELF.LastErrorText = 'The message has no recipient.'
    OF ETMsg:NoBody        ; SELF.LastErrorText = 'The message has no text and no HTML body.'
    OF ETMsg:AttachMissing ; SELF.LastErrorText = 'An attachment file does not exist.'
    OF ETMsg:AttachRead    ; SELF.LastErrorText = 'An attachment file could not be read.'
    OF ETMsg:TooBig        ; SELF.LastErrorText = 'The message is larger than the size limit.'
    ELSE                 ; SELF.LastErrorText = 'Message error ' & pCode
    END
  ELSE
    SELF.LastErrorText = pText
  END
  RETURN pCode

! ============================================================================
!  Composing
! ============================================================================
EmailMsgClass.SetFrom PROCEDURE(STRING pAddress,<STRING pName>)
  CODE
  SELF.FromAddr = CLIP(pAddress)
  IF NOT OMITTED(pName)
    SELF.FromName = CLIP(pName)
  END

EmailMsgClass.SetSubject PROCEDURE(STRING pSubject)
  CODE
  SELF.Subject = CLIP(pSubject)

EmailMsgClass.AddAddress PROCEDURE(BYTE pKind,STRING pAddress,<STRING pName>)
  CODE
  IF NOT CLIP(pAddress) THEN RETURN.
  SELF.AddrQ.Kind        = pKind
  SELF.AddrQ.Address     = CLIP(LEFT(pAddress))
  SELF.AddrQ.DisplayName = CHOOSE(OMITTED(pName), '', CLIP(pName))
  ADD(SELF.AddrQ)

EmailMsgClass.AddTo PROCEDURE(STRING pAddress,<STRING pName>)
  CODE
  IF OMITTED(pName)
    SELF.AddAddress(ETAddr:To, pAddress)
  ELSE
    SELF.AddAddress(ETAddr:To, pAddress, pName)
  END

EmailMsgClass.AddCc PROCEDURE(STRING pAddress,<STRING pName>)
  CODE
  IF OMITTED(pName)
    SELF.AddAddress(ETAddr:Cc, pAddress)
  ELSE
    SELF.AddAddress(ETAddr:Cc, pAddress, pName)
  END

EmailMsgClass.AddBcc PROCEDURE(STRING pAddress,<STRING pName>)
  CODE
  IF OMITTED(pName)
    SELF.AddAddress(ETAddr:Bcc, pAddress)
  ELSE
    SELF.AddAddress(ETAddr:Bcc, pAddress, pName)
  END

!  Accepts the way people actually type a list: separated by ; or , and with
!  any amount of stray whitespace.  Returns how many addresses were added.
EmailMsgClass.AddList PROCEDURE(STRING pAddresses,BYTE pKind=ETAddr:To)
i     LONG
start LONG
n     LONG
ch    STRING(1)
one   CSTRING(256)
count LONG
  CODE
  n = LEN(CLIP(pAddresses))
  IF n < 1 THEN RETURN 0.
  start = 1
  LOOP i = 1 TO n + 1
    IF i > n
      ch = ';'
    ELSE
      ch = pAddresses[i]
    END
    IF ch = ';' OR ch = ','
      IF i > start
        one = CLIP(LEFT(pAddresses[start : i-1]))
        IF one
          SELF.AddAddress(pKind, one)
          count += 1
        END
      END
      start = i + 1
    END
  END
  RETURN count

EmailMsgClass.SetText PROCEDURE(STRING pText)
  CODE
  SELF.TextBody.ClearAll()
  SELF.TextBody.Add(CLIP(pText))

EmailMsgClass.AddText PROCEDURE(STRING pText)
  CODE
  SELF.TextBody.Add(CLIP(pText))

EmailMsgClass.SetHtml PROCEDURE(STRING pHtml)
  CODE
  SELF.HtmlBody.ClearAll()
  SELF.HtmlBody.Add(CLIP(pHtml))

EmailMsgClass.AddHtml PROCEDURE(STRING pHtml)
  CODE
  SELF.HtmlBody.Add(CLIP(pHtml))

EmailMsgClass.AddHeader PROCEDURE(STRING pName,STRING pValue)
  CODE
  SELF.HeaderQ.HName  = CLIP(pName)
  SELF.HeaderQ.HValue = CLIP(pValue)
  ADD(SELF.HeaderQ)

EmailMsgClass.Attach PROCEDURE(STRING pFileName,<STRING pShownAs>,<STRING pContentType>)
path CSTRING(261)
i    LONG
  CODE
  path = CLIP(pFileName)
  IF NOT EXISTS(path)
    SELF.SetErr(ETMsg:AttachMissing, 'Attachment not found: ' & CLIP(path))
    RETURN 0
  END
  SELF.AttachQ.FileName = path
  IF OMITTED(pShownAs) OR NOT CLIP(pShownAs)
    !  strip the folder: keep everything after the last \ or /
    LOOP i = LEN(CLIP(path)) TO 1 BY -1
      IF path[i] = '\' OR path[i] = '/'
        BREAK
      END
    END
    SELF.AttachQ.ShownAs = path[i+1 : LEN(CLIP(path))]
  ELSE
    SELF.AttachQ.ShownAs = CLIP(pShownAs)
  END
  IF OMITTED(pContentType) OR NOT CLIP(pContentType)
    SELF.AttachQ.ContentType = SELF.GuessType(SELF.AttachQ.ShownAs)
  ELSE
    SELF.AttachQ.ContentType = CLIP(pContentType)
  END
  SELF.AttachQ.ContentId = ''
  SELF.AttachQ.Data     &= NULL
  SELF.AttachQ.DataLen   = 0
  ADD(SELF.AttachQ)
  RETURN 1

!  Attach something already in memory - a report you just built, a BLOB you
!  just read.  The bytes are copied, so the caller can reuse its buffer.
EmailMsgClass.AttachData PROCEDURE(STRING pShownAs,STRING pData,<STRING pContentType>)
n LONG
  CODE
  n = SIZE(pData)
  IF n < 1 THEN RETURN 0.
  SELF.AttachQ.FileName = ''
  SELF.AttachQ.ShownAs  = CLIP(pShownAs)
  IF OMITTED(pContentType) OR NOT CLIP(pContentType)
    SELF.AttachQ.ContentType = SELF.GuessType(SELF.AttachQ.ShownAs)
  ELSE
    SELF.AttachQ.ContentType = CLIP(pContentType)
  END
  SELF.AttachQ.ContentId = ''
  SELF.AttachQ.Data     &= NEW(STRING(n))
  SELF.AttachQ.Data[1 : n] = pData[1 : n]
  SELF.AttachQ.DataLen   = n
  ADD(SELF.AttachQ)
  RETURN 1

!  An image the HTML body refers to as <img src="cid:logo">.  Pass 'logo'.
EmailMsgClass.AttachInline PROCEDURE(STRING pFileName,STRING pContentId,<STRING pContentType>)
  CODE
  IF OMITTED(pContentType)
    IF NOT SELF.Attach(pFileName) THEN RETURN 0.
  ELSE
    IF NOT SELF.Attach(pFileName, '', pContentType) THEN RETURN 0.
  END
  GET(SELF.AttachQ, RECORDS(SELF.AttachQ))
  SELF.AttachQ.ContentId = CLIP(pContentId)
  PUT(SELF.AttachQ)
  RETURN 1

! ============================================================================
!  Encoders
! ============================================================================
!  Windows-1252 bytes in, UTF-8 bytes out.  ASCII passes through untouched, so
!  an English message costs one comparison per character and nothing else.
EmailMsgClass.Utf8 PROCEDURE(STRING pAnsi)
i    LONG
n    LONG
b    LONG
cp   LONG
two  STRING(2)
three STRING(3)
  CODE
  n = SIZE(pAnsi)
  IF n < 1 THEN RETURN ''.
  !  Fast path: an all-ASCII string is already UTF-8, so an English message
  !  costs one comparison per character and no copying at all.
  LOOP i = 1 TO n
    IF VAL(pAnsi[i]) > 127 THEN BREAK.
  END
  IF i > n THEN RETURN pAnsi[1 : n].

  SELF.U8Buf.ClearAll()
  LOOP i = 1 TO n
    b = VAL(pAnsi[i])
    IF b < 128
      SELF.U8Buf.Add(pAnsi[i])
      CYCLE
    END
    IF b < 160
      cp = ET_Cp1252Hi[b - 127]
      IF NOT cp THEN cp = b.                        ! undefined slot: pass the byte through
    ELSE
      cp = b                                        ! A0h..FFh are Latin-1, same code point
    END
    IF cp < 2048
      two[1] = CHR(BOR(0C0h, BSHIFT(cp, -6)))
      two[2] = CHR(BOR(080h, BAND(cp, 3Fh)))
      SELF.U8Buf.Add(two)
    ELSE
      three[1] = CHR(BOR(0E0h, BSHIFT(cp, -12)))
      three[2] = CHR(BOR(080h, BAND(BSHIFT(cp, -6), 3Fh)))
      three[3] = CHR(BOR(080h, BAND(cp, 3Fh)))
      SELF.U8Buf.Add(three)
    END
  END
  RETURN SELF.U8Buf.Value()

EmailMsgClass.Base64 PROCEDURE(STRING pRaw)
i    LONG
n    LONG
b1   LONG
b2   LONG
b3   LONG
quad STRING(4)
  CODE
  n = SIZE(pRaw)
  IF n < 1 THEN RETURN ''.
  SELF.EncBuf.ClearAll()
  i = 1
  LOOP WHILE i <= n
    b1 = VAL(pRaw[i])
    b2 = CHOOSE(i+1 <= n, VAL(pRaw[i+1]), 0)
    b3 = CHOOSE(i+2 <= n, VAL(pRaw[i+2]), 0)
    quad[1] = ET_B64Tbl[BSHIFT(b1, -2) + 1]
    quad[2] = ET_B64Tbl[BOR(BSHIFT(BAND(b1, 3), 4), BSHIFT(b2, -4)) + 1]
    IF i+1 <= n
      quad[3] = ET_B64Tbl[BOR(BSHIFT(BAND(b2, 0Fh), 2), BSHIFT(b3, -6)) + 1]
    ELSE
      quad[3] = '='
    END
    IF i+2 <= n
      quad[4] = ET_B64Tbl[BAND(b3, 3Fh) + 1]
    ELSE
      quad[4] = '='
    END
    SELF.EncBuf.Add(quad)
    i += 3
  END
  RETURN SELF.EncBuf.Value()

!  RFC 4648 section 5 - the URL-safe alphabet, with the padding removed.
!  OAuth2 PKCE and the Gmail API both insist on this form; the standard
!  alphabet is rejected by both because + / and = are not URL-safe.
EmailMsgClass.Base64Url PROCEDURE(STRING pRaw)
i    LONG
n    LONG
b1   LONG
b2   LONG
b3   LONG
quad STRING(4)
keep LONG
  CODE
  n = SIZE(pRaw)
  IF n < 1 THEN RETURN ''.
  SELF.EncBuf.ClearAll()
  i = 1
  LOOP WHILE i <= n
    b1 = VAL(pRaw[i])
    b2 = CHOOSE(i+1 <= n, VAL(pRaw[i+1]), 0)
    b3 = CHOOSE(i+2 <= n, VAL(pRaw[i+2]), 0)
    quad[1] = ET_B64Tbl[BSHIFT(b1, -2) + 1]
    quad[2] = ET_B64Tbl[BOR(BSHIFT(BAND(b1, 3), 4), BSHIFT(b2, -4)) + 1]
    quad[3] = ET_B64Tbl[BOR(BSHIFT(BAND(b2, 0Fh), 2), BSHIFT(b3, -6)) + 1]
    quad[4] = ET_B64Tbl[BAND(b3, 3Fh) + 1]
    !  62 and 63 become - and _ ; the tail keeps only the meaningful characters
    IF quad[1] = '+' THEN quad[1] = '-'.
    IF quad[1] = '/' THEN quad[1] = '_'.
    IF quad[2] = '+' THEN quad[2] = '-'.
    IF quad[2] = '/' THEN quad[2] = '_'.
    IF quad[3] = '+' THEN quad[3] = '-'.
    IF quad[3] = '/' THEN quad[3] = '_'.
    IF quad[4] = '+' THEN quad[4] = '-'.
    IF quad[4] = '/' THEN quad[4] = '_'.
    IF i + 2 <= n
      keep = 4
    ELSIF i + 1 <= n
      keep = 3
    ELSE
      keep = 2
    END
    SELF.EncBuf.Add(quad[1 : keep])
    i += 3
  END
  RETURN SELF.EncBuf.Value()

!  Attachment encoding: 76-character lines straight into the caller buffer, so
!  a 10 MB PDF never exists twice in memory as one giant Clarion string.
EmailMsgClass.Base64Len PROCEDURE(*STRING pRaw,LONG pLen,EmailBufClass pOut)
i     LONG
b1    LONG
b2    LONG
b3    LONG
line  STRING(78)
col   LONG
  CODE
  IF pLen < 1 THEN RETURN.
  i   = 1
  col = 0
  LOOP WHILE i <= pLen
    b1 = VAL(pRaw[i])
    b2 = CHOOSE(i+1 <= pLen, VAL(pRaw[i+1]), 0)
    b3 = CHOOSE(i+2 <= pLen, VAL(pRaw[i+2]), 0)
    line[col+1] = ET_B64Tbl[BSHIFT(b1, -2) + 1]
    line[col+2] = ET_B64Tbl[BOR(BSHIFT(BAND(b1, 3), 4), BSHIFT(b2, -4)) + 1]
    IF i+1 <= pLen
      line[col+3] = ET_B64Tbl[BOR(BSHIFT(BAND(b2, 0Fh), 2), BSHIFT(b3, -6)) + 1]
    ELSE
      line[col+3] = '='
    END
    IF i+2 <= pLen
      line[col+4] = ET_B64Tbl[BAND(b3, 3Fh) + 1]
    ELSE
      line[col+4] = '='
    END
    col += 4
    i   += 3
    IF col >= 76
      line[col+1 : col+2] = '<13,10>'
      pOut.Add(line[1 : col+2])
      col = 0
    END
  END
  IF col > 0
    line[col+1 : col+2] = '<13,10>'
    pOut.Add(line[1 : col+2])
  END

EmailMsgClass.Base64Decode PROCEDURE(STRING pB64)
rev   STRING(256)
i     LONG
n     LONG
v     LONG
acc   LONG
bits  LONG
one   STRING(1)
  CODE
  n = SIZE(pB64)
  IF n < 1 THEN RETURN ''.
  rev = ALL('<255>', 256)
  LOOP i = 1 TO 64
    rev[VAL(ET_B64Tbl[i]) + 1] = CHR(i - 1)
  END
  rev[VAL('-') + 1] = CHR(62)                       ! also accept the URL-safe alphabet
  rev[VAL('_') + 1] = CHR(63)
  SELF.DecBuf.ClearAll()
  LOOP i = 1 TO n
    v = VAL(rev[VAL(pB64[i]) + 1])
    IF v = 255 THEN CYCLE.                          ! whitespace, newline, padding
    acc  = BOR(BSHIFT(acc, 6), v)
    bits += 6
    IF bits >= 8
      bits -= 8
      one = CHR(BAND(BSHIFT(acc, -bits), 0FFh))
      SELF.DecBuf.Add(one)
    END
  END
  RETURN SELF.DecBuf.Value()

!  RFC 2045 quoted-printable.  Readable for plain English, correct for anything
!  else, and it keeps every line inside the 998-character SMTP limit.
EmailMsgClass.QuotedPrintable PROCEDURE(STRING pText)
i    LONG
n    LONG
b    LONG
col  LONG
esc  STRING(3)
  CODE
  n = SIZE(pText)
  IF n < 1 THEN RETURN ''.
  SELF.QpBuf.ClearAll()
  LOOP i = 1 TO n
    b = VAL(pText[i])
    IF b = 13 THEN CYCLE.                           ! CR is emitted with the LF
    IF b = 10
      SELF.QpBuf.Add('<13,10>')
      col = 0
      CYCLE
    END
    IF col >= 73                                    ! room for a =XX plus the soft break
      SELF.QpBuf.Add('=<13,10>')
      col = 0
    END
    IF (b >= 33 AND b <= 60) OR (b >= 62 AND b <= 126)
      SELF.QpBuf.Add(pText[i])
      col += 1
    ELSIF b = 32 OR b = 9
      !  a space is only a problem at the end of a line; look ahead one
      IF i = n OR VAL(pText[i+1]) = 13 OR VAL(pText[i+1]) = 10
        esc[1] = '='
        esc[2] = ET_HexTbl[BSHIFT(b, -4) + 1]
        esc[3] = ET_HexTbl[BAND(b, 0Fh) + 1]
        SELF.QpBuf.Add(esc)
        col += 3
      ELSE
        SELF.QpBuf.Add(pText[i])
        col += 1
      END
    ELSE
      esc[1] = '='
      esc[2] = ET_HexTbl[BSHIFT(b, -4) + 1]
      esc[3] = ET_HexTbl[BAND(b, 0Fh) + 1]
      SELF.QpBuf.Add(esc)
      col += 3
    END
  END
  RETURN SELF.QpBuf.Value()

!  A BODY is not a header: CR, LF and TAB are ordinary content there, and the
!  only other reason to encode is a line over the 998-character limit RFC 5321
!  puts on an SMTP line.  Checking with the header rule instead would put an
!  ordinary English note into quoted-printable for no reason at all.
EmailMsgClass.BodyNeedsQp PROCEDURE(EmailBufClass pBody)
i    LONG
b    LONG
col  LONG
  CODE
  LOOP i = 1 TO pBody.Len
    b = VAL(pBody.Buf[i])
    IF b > 126 THEN RETURN 1.
    IF b = 10
      col = 0
      CYCLE
    END
    IF b = 13 THEN CYCLE.
    IF b < 32 AND b <> 9 THEN RETURN 1.
    col += 1
    IF col > 990 THEN RETURN 1.
  END
  RETURN 0

EmailMsgClass.NeedsEncoding PROCEDURE(STRING pText)
i LONG
b LONG
  CODE
  LOOP i = 1 TO SIZE(pText)
    b = VAL(pText[i])
    IF b > 126 OR (b < 32 AND b <> 9) THEN RETURN 1.
  END
  RETURN 0

!  RFC 2047 encoded words.  Only used when the text actually needs it, so a
!  plain English subject stays readable in the raw message.
EmailMsgClass.EncodeHeader PROCEDURE(STRING pText)
u8    &STRING
n     LONG
pos   LONG
take  LONG
  CODE
  IF NOT SELF.NeedsEncoding(pText) THEN RETURN CLIP(pText).

  SELF.HdrBuf.ClearAll()
  IF SELF.CharSet = ETChs:Ansi
    SELF.HdrBuf.Add('=?windows-1252?B?')
    SELF.HdrBuf.Add(SELF.Base64(CLIP(pText)))
    SELF.HdrBuf.Add('?=')
    RETURN SELF.HdrBuf.Value()
  END

  !  Transcode into a local buffer, not SELF.U8Buf: a caller may already be
  !  holding a Utf8() result while it asks for a header.
  u8 &= NEW(STRING(SIZE(pText) * 3 + 4))
  n = 0
  DO Transcode
  IF n < 1
    DISPOSE(u8)
    RETURN CLIP(pText)
  END

  pos = 1
  LOOP WHILE pos <= n
    !  45 UTF-8 bytes base64-encode to exactly 60 characters; with the
    !  "=?UTF-8?B?" prefix and the "?=" suffix that is 72, inside the
    !  75-character limit RFC 2047 puts on a single encoded word.
    take = 45
    IF pos + take - 1 > n THEN take = n - pos + 1.
    !  Never split a UTF-8 character across two encoded words: while the byte
    !  that would START the next word is a continuation byte (10xxxxxx), pull
    !  this word back by one.
    LOOP WHILE take > 1 AND pos + take <= n
      IF BAND(VAL(u8[pos + take]), 0C0h) <> 080h THEN BREAK.
      take -= 1
    END
    IF SELF.HdrBuf.Len > 0
      SELF.HdrBuf.Add('<13,10> ')                   ! folded continuation line
    END
    SELF.HdrBuf.Add('=?UTF-8?B?')
    SELF.HdrBuf.Add(SELF.Base64(u8[pos : pos + take - 1]))
    SELF.HdrBuf.Add('?=')
    pos += take
  END
  DISPOSE(u8)
  RETURN SELF.HdrBuf.Value()

Transcode ROUTINE
  DATA
i   LONG
cp  LONG
bb  LONG
  CODE
  LOOP i = 1 TO SIZE(pText)
    bb = VAL(pText[i])
    IF bb < 128
      n += 1
      u8[n] = pText[i]
      CYCLE
    END
    IF bb < 160
      cp = ET_Cp1252Hi[bb - 127]
      IF NOT cp THEN cp = bb.
    ELSE
      cp = bb
    END
    IF cp < 2048
      n += 1; u8[n] = CHR(BOR(0C0h, BSHIFT(cp, -6)))
      n += 1; u8[n] = CHR(BOR(080h, BAND(cp, 3Fh)))
    ELSE
      n += 1; u8[n] = CHR(BOR(0E0h, BSHIFT(cp, -12)))
      n += 1; u8[n] = CHR(BOR(080h, BAND(BSHIFT(cp, -6), 3Fh)))
      n += 1; u8[n] = CHR(BOR(080h, BAND(cp, 3Fh)))
    END
  END

EmailMsgClass.JsonString PROCEDURE(STRING pText)
u8   &STRING
i    LONG
n    LONG
b    LONG
esc  STRING(6)
  CODE
  SELF.JsnBuf.ClearAll()
  SELF.JsnBuf.Add('"')
  IF SIZE(pText) > 0
    u8 &= NEW(STRING(SIZE(pText) * 3 + 4))
    n = 0
    DO ToUtf8
    LOOP i = 1 TO n
      b = VAL(u8[i])
      CASE b
      OF 34  ; SELF.JsnBuf.Add('\"')
      OF 92  ; SELF.JsnBuf.Add('\')
      OF 8   ; SELF.JsnBuf.Add('\b')
      OF 12  ; SELF.JsnBuf.Add('\f')
      OF 10  ; SELF.JsnBuf.Add('\n')
      OF 13  ; SELF.JsnBuf.Add('\r')
      OF 9   ; SELF.JsnBuf.Add('\t')
      ELSE
        IF b < 32
          esc = '\u00' & ET_HexTbl[BSHIFT(b, -4) + 1] & ET_HexTbl[BAND(b, 0Fh) + 1]
          SELF.JsnBuf.Add(esc[1 : 6])
        ELSE
          SELF.JsnBuf.Add(u8[i])
        END
      END
    END
    DISPOSE(u8)
  END
  SELF.JsnBuf.Add('"')
  RETURN SELF.JsnBuf.Value()

ToUtf8 ROUTINE
  DATA
j   LONG
cp  LONG
bb  LONG
  CODE
  LOOP j = 1 TO SIZE(pText)
    bb = VAL(pText[j])
    IF bb < 128
      n += 1; u8[n] = pText[j]
      CYCLE
    END
    IF bb < 160
      cp = ET_Cp1252Hi[bb - 127]
      IF NOT cp THEN cp = bb.
    ELSE
      cp = bb
    END
    IF cp < 2048
      n += 1; u8[n] = CHR(BOR(0C0h, BSHIFT(cp, -6)))
      n += 1; u8[n] = CHR(BOR(080h, BAND(cp, 3Fh)))
    ELSE
      n += 1; u8[n] = CHR(BOR(0E0h, BSHIFT(cp, -12)))
      n += 1; u8[n] = CHR(BOR(080h, BAND(BSHIFT(cp, -6), 3Fh)))
      n += 1; u8[n] = CHR(BOR(080h, BAND(cp, 3Fh)))
    END
  END

! ============================================================================
!  Headers
! ============================================================================
EmailMsgClass.Boundary PROCEDURE()
  CODE
  ET_Serial += 1
  RETURN '----=_emailTo_' & FORMAT(GetCurrentProcessId(), @n010) & |
         '_' & FORMAT(GetTickCount(), @n010) & '_' & FORMAT(ET_Serial, @n05)

!  RFC 5322: "Sat, 22 Aug 2026 13:49:05 -0500".  The day and month names are
!  spelled out here rather than taken from FORMAT() because those follow the
!  machine locale, and a Spanish Windows would put "sab" in an English header.
EmailMsgClass.DateHeader PROCEDURE()
tz    LIKE(ET_TimeZoneInfo)
rc    LONG
bias  LONG
dt    LONG
tm    LONG
y     LONG
m     LONG
d     LONG
k     LONG
j     LONG
h     LONG
sign  STRING(1)
  CODE
  dt = TODAY()
  tm = CLOCK()
  y  = YEAR(dt)
  m  = MONTH(dt)
  d  = DAY(dt)

  !  Zeller congruence: h = 0 is Saturday
  IF m < 3
    m += 12
    y -= 1
  END
  k = y % 100
  j = INT(y / 100)
  h = (d + INT(13 * (m + 1) / 5) + k + INT(k / 4) + INT(j / 4) + 5 * j) % 7

  IF SELF.TzMinutes
    bias = SELF.TzMinutes
  ELSE
    rc = GetTimeZoneInformation(tz)
    CASE rc
    OF 2 ; bias = -(tz.Bias + tz.DaylightBias)      ! daylight saving in force
    OF 1 ; bias = -(tz.Bias + tz.StandardBias)
    ELSE ; bias = -tz.Bias
    END
  END
  IF bias < 0
    sign = '-'
    bias = -bias
  ELSE
    sign = '+'
  END

  RETURN ET_DowTbl[h*3+1 : h*3+3] & ', ' & FORMAT(DAY(dt), @n02) & ' ' & |
         ET_MonTbl[(MONTH(dt)-1)*3+1 : (MONTH(dt)-1)*3+3] & ' ' & FORMAT(YEAR(dt), @n04) & ' ' & |
         FORMAT(INT(tm / 360000), @n02) & ':' & |
         FORMAT(INT((tm % 360000) / 6000), @n02) & ':' & |
         FORMAT(INT((tm % 6000) / 100), @n02) & ' ' & |
         sign & FORMAT(INT(bias / 60), @n02) & FORMAT(bias % 60, @n02)

EmailMsgClass.RecipientList PROCEDURE(BYTE pKind)
i   LONG
  CODE
  SELF.ListBuf.ClearAll()
  LOOP i = 1 TO RECORDS(SELF.AddrQ)
    GET(SELF.AddrQ, i)
    IF SELF.AddrQ.Kind <> pKind THEN CYCLE.
    IF SELF.ListBuf.Len > 0 THEN SELF.ListBuf.Add(', ').
    IF SELF.AddrQ.DisplayName
      SELF.ListBuf.Add(SELF.EncodeHeader(SELF.AddrQ.DisplayName))
      SELF.ListBuf.Add(' <')
      SELF.ListBuf.Add(SELF.AddrQ.Address)
      SELF.ListBuf.Add('>')
    ELSE
      SELF.ListBuf.Add(SELF.AddrQ.Address)
    END
  END
  RETURN SELF.ListBuf.Value()

EmailMsgClass.EnvelopeCount PROCEDURE()
  CODE
  RETURN RECORDS(SELF.AddrQ)

EmailMsgClass.EnvelopeAddr PROCEDURE(LONG pIndex)
  CODE
  IF pIndex < 1 OR pIndex > RECORDS(SELF.AddrQ) THEN RETURN ''.
  GET(SELF.AddrQ, pIndex)
  RETURN CLIP(SELF.AddrQ.Address)

EmailMsgClass.GuessType PROCEDURE(STRING pFileName)
ext CSTRING(21)
i   LONG
n   LONG
  CODE
  n = LEN(CLIP(pFileName))
  LOOP i = n TO 1 BY -1
    IF pFileName[i] = '.' THEN BREAK.
  END
  IF i < 1 THEN RETURN 'application/octet-stream'.
  ext = UPPER(pFileName[i+1 : n])
  CASE ext
  OF 'PDF'                      ; RETURN 'application/pdf'
  OF 'TXT' OROF 'LOG' OROF 'INI'; RETURN 'text/plain'
  OF 'CSV'                      ; RETURN 'text/csv'
  OF 'HTM' OROF 'HTML'          ; RETURN 'text/html'
  OF 'XML'                      ; RETURN 'text/xml'
  OF 'JSON'                     ; RETURN 'application/json'
  OF 'ZIP'                      ; RETURN 'application/zip'
  OF 'RAR'                      ; RETURN 'application/x-rar-compressed'
  OF '7Z'                       ; RETURN 'application/x-7z-compressed'
  OF 'GZ'                       ; RETURN 'application/gzip'
  OF 'JPG' OROF 'JPEG'          ; RETURN 'image/jpeg'
  OF 'PNG'                      ; RETURN 'image/png'
  OF 'GIF'                      ; RETURN 'image/gif'
  OF 'BMP'                      ; RETURN 'image/bmp'
  OF 'TIF' OROF 'TIFF'          ; RETURN 'image/tiff'
  OF 'ICO'                      ; RETURN 'image/x-icon'
  OF 'SVG'                      ; RETURN 'image/svg+xml'
  OF 'WEBP'                     ; RETURN 'image/webp'
  OF 'DOC'                      ; RETURN 'application/msword'
  OF 'DOCX'                     ; RETURN 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  OF 'XLS'                      ; RETURN 'application/vnd.ms-excel'
  OF 'XLSX'                     ; RETURN 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  OF 'PPT'                      ; RETURN 'application/vnd.ms-powerpoint'
  OF 'PPTX'                     ; RETURN 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  OF 'RTF'                      ; RETURN 'application/rtf'
  OF 'MP3'                      ; RETURN 'audio/mpeg'
  OF 'WAV'                      ; RETURN 'audio/wav'
  OF 'MP4'                      ; RETURN 'video/mp4'
  OF 'AVI'                      ; RETURN 'video/x-msvideo'
  OF 'TPS'                      ; RETURN 'application/octet-stream'
  ELSE                          ; RETURN 'application/octet-stream'
  END

! ============================================================================
!  Reading an attachment off disk
! ============================================================================
EmailMsgClass.LoadFile PROCEDURE(STRING pFileName,EmailBufClass pOut)
path  CSTRING(261)
hFile LONG
size  ULONG
got   ULONG
chunk &STRING
want  LONG
  CODE
  path = CLIP(pFileName)
  hFile = CreateFileA(path, ET_GENERIC_READ, ET_FILE_SHARE_READ, 0, ET_OPEN_EXISTING, ET_FILE_ATTR_NORMAL, 0)
  IF hFile = ET_INVALID_HANDLE OR hFile = 0
    SELF.SetErr(ETMsg:AttachRead, 'Cannot open ' & CLIP(path))
    RETURN 0
  END
  size = GetFileSize(hFile, 0)
  IF size = 0
    CloseHandle(hFile)
    RETURN 1                                        ! an empty file is legal, just pointless
  END
  chunk &= NEW(STRING(65536))
  LOOP
    want = 65536
    IF pOut.Len >= size THEN BREAK.
    IF size - pOut.Len < want THEN want = size - pOut.Len.
    got = 0
    IF NOT ReadFile(hFile, chunk, want, got, 0) OR got = 0
      BREAK
    END
    pOut.AddLen(chunk, got)
  END
  DISPOSE(chunk)
  CloseHandle(hFile)
  RETURN 1

! ============================================================================
!  Build - turn all of the above into the actual message
! ============================================================================
EmailMsgClass.WriteBodyPart PROCEDURE(EmailBufClass pOut,STRING pContentType,EmailBufClass pBody)
enc  BYTE
  CODE
  IF SELF.CharSet = ETChs:Ansi
    pOut.AddLine('Content-Type: ' & CLIP(pContentType) & '; charset="windows-1252"')
    enc = SELF.BodyNeedsQp(pBody)
    IF enc
      pOut.AddLine('Content-Transfer-Encoding: quoted-printable')
      pOut.AddLine('')
      pOut.Add(SELF.QuotedPrintable(pBody.Value()))
    ELSE
      pOut.AddLine('Content-Transfer-Encoding: 7bit')
      pOut.AddLine('')
      pOut.AddLen(pBody.Buf, pBody.Len)
    END
  ELSE
    pOut.AddLine('Content-Type: ' & CLIP(pContentType) & '; charset="UTF-8"')
    IF SELF.BodyNeedsQp(pBody)
      pOut.AddLine('Content-Transfer-Encoding: quoted-printable')
      pOut.AddLine('')
      !  Utf8 answers out of U8Buf and QuotedPrintable out of QpBuf, so the
      !  inner result stays intact while the outer call reads it.
      pOut.Add(SELF.QuotedPrintable(SELF.Utf8(pBody.Value())))
    ELSE
      pOut.AddLine('Content-Transfer-Encoding: 7bit')
      pOut.AddLine('')
      pOut.AddLen(pBody.Buf, pBody.Len)
    END
  END
  pOut.AddLine('')

EmailMsgClass.WriteAttachment PROCEDURE(EmailBufClass pOut,LONG pIndex)
raw  &EmailBufClass
  CODE
  GET(SELF.AttachQ, pIndex)
  pOut.AddLine('Content-Type: ' & CLIP(SELF.AttachQ.ContentType) & '; name="' & |
               SELF.EncodeHeader(SELF.AttachQ.ShownAs) & '"')
  pOut.AddLine('Content-Transfer-Encoding: base64')
  IF SELF.AttachQ.ContentId
    pOut.AddLine('Content-ID: <' & CLIP(SELF.AttachQ.ContentId) & '>')
    pOut.AddLine('Content-Disposition: inline; filename="' & |
                 SELF.EncodeHeader(SELF.AttachQ.ShownAs) & '"')
  ELSE
    pOut.AddLine('Content-Disposition: attachment; filename="' & |
                 SELF.EncodeHeader(SELF.AttachQ.ShownAs) & '"')
  END
  pOut.AddLine('')

  IF NOT SELF.AttachQ.Data &= NULL
    SELF.Base64Len(SELF.AttachQ.Data, SELF.AttachQ.DataLen, pOut)
  ELSE
    raw &= NEW(EmailBufClass)
    IF SELF.LoadFile(SELF.AttachQ.FileName, raw)
      SELF.Base64Len(raw.Buf, raw.Len, pOut)
    END
    DISPOSE(raw)
  END
  pOut.AddLine('')

EmailMsgClass.Validate PROCEDURE()
  CODE
  IF NOT SELF.FromAddr
    SELF.SetErr(ETMsg:NoFrom)
    RETURN 0
  END
  IF NOT RECORDS(SELF.AddrQ)
    SELF.SetErr(ETMsg:NoRecipient)
    RETURN 0
  END
  IF SELF.TextBody.Len < 1 AND SELF.HtmlBody.Len < 1 AND NOT RECORDS(SELF.AttachQ)
    SELF.SetErr(ETMsg:NoBody)
    RETURN 0
  END
  SELF.SetErr(ETMsg:Ok)
  RETURN 1

EmailMsgClass.Build PROCEDURE()
mixedB  CSTRING(65)
relB    CSTRING(65)
altB    CSTRING(65)
hasText BYTE
hasHtml BYTE
nInline LONG
nFile   LONG
useAlt  BYTE
useRel  BYTE
useMix  BYTE
i       LONG
list    CSTRING(4001)
dom     CSTRING(129)
  CODE
  IF NOT SELF.Validate() THEN RETURN SELF.LastError.
  SELF.Mime.ClearAll()

  hasText = CHOOSE(SELF.TextBody.Len > 0, 1, 0)
  hasHtml = CHOOSE(SELF.HtmlBody.Len > 0, 1, 0)
  IF NOT hasText AND NOT hasHtml
    SELF.TextBody.Add(' ')                          ! attachment-only: a body is still required
    hasText = 1
  END
  LOOP i = 1 TO RECORDS(SELF.AttachQ)
    GET(SELF.AttachQ, i)
    IF SELF.AttachQ.ContentId
      nInline += 1
    ELSE
      nFile += 1
    END
  END
  useAlt = CHOOSE(hasText = 1 AND hasHtml = 1, 1, 0)
  useRel = CHOOSE(nInline > 0, 1, 0)
  useMix = CHOOSE(nFile > 0, 1, 0)
  mixedB = SELF.Boundary()
  relB   = SELF.Boundary()
  altB   = SELF.Boundary()

  !-- envelope headers -------------------------------------------------------
  SELF.Mime.AddLine('Date: ' & SELF.DateHeader())
  IF SELF.FromName
    SELF.Mime.AddLine('From: ' & SELF.EncodeHeader(SELF.FromName) & ' <' & CLIP(SELF.FromAddr) & '>')
  ELSE
    SELF.Mime.AddLine('From: ' & CLIP(SELF.FromAddr))
  END
  !  Written straight out of ListBuf rather than through a local CSTRING: a
  !  mailshot to 300 people would silently lose the tail of a fixed-size one.
  SELF.RecipientList(ETAddr:To)
  IF SELF.ListBuf.Len > 0
    SELF.Mime.Add('To: ')
    SELF.Mime.AddLen(SELF.ListBuf.Buf, SELF.ListBuf.Len)
    SELF.Mime.Add('<13,10>')
  END
  SELF.RecipientList(ETAddr:Cc)
  IF SELF.ListBuf.Len > 0
    SELF.Mime.Add('Cc: ')
    SELF.Mime.AddLen(SELF.ListBuf.Buf, SELF.ListBuf.Len)
    SELF.Mime.Add('<13,10>')
  END
  !  Bcc normally stays OUT of the headers: the whole point is that the other
  !  recipients never see it, and over SMTP it reaches the server as an extra
  !  RCPT TO instead.
  !
  !  But the REST transports have no envelope to carry it in - the Gmail API
  !  and Microsoft Graph read the recipients out of these very headers - so
  !  there a Bcc line is the ONLY way those people get the message, and both
  !  providers strip it again before delivering.  Without this, a Bcc over
  !  those transports is silently dropped: no error, no message.
  IF SELF.BccInHeaders
    SELF.RecipientList(ETAddr:Bcc)
    IF SELF.ListBuf.Len > 0
      SELF.Mime.Add('Bcc: ')
      SELF.Mime.AddLen(SELF.ListBuf.Buf, SELF.ListBuf.Len)
      SELF.Mime.Add('<13,10>')
    END
  END
  IF SELF.ReplyTo
    SELF.Mime.AddLine('Reply-To: ' & CLIP(SELF.ReplyTo))
  END
  SELF.Mime.AddLine('Subject: ' & SELF.EncodeHeader(SELF.Subject))
  IF NOT SELF.OwnMessageId AND NOT SELF.MessageId
    !  Nothing to write: the provider will put its own on, and an id minted in
    !  a domain we do not control is worse than no id at all.
  ELSIF NOT SELF.MessageId
    dom = ''
    LOOP i = 1 TO LEN(CLIP(SELF.FromAddr))
      IF SELF.FromAddr[i] = '@'
        dom = SELF.FromAddr[i+1 : LEN(CLIP(SELF.FromAddr))]
        BREAK
      END
    END
    IF NOT dom THEN dom = 'emailto.local'.
    ET_Serial += 1
    SELF.MessageId = '<' & FORMAT(TODAY(), @n07) & '.' & FORMAT(CLOCK(), @n08) & '.' & |
                     FORMAT(GetCurrentProcessId(), @n010) & '.' & |
                     FORMAT(GetTickCount(), @n010) & '.' & FORMAT(ET_Serial, @n05) & |
                     '@' & CLIP(dom) & '>'
  END
  IF SELF.MessageId
    SELF.Mime.AddLine('Message-ID: ' & CLIP(SELF.MessageId))
  END
  SELF.Mime.AddLine('MIME-Version: 1.0')
  SELF.Mime.AddLine('X-Mailer: emailTo for Clarion')
  CASE SELF.Priority
  OF ETPri:High
    SELF.Mime.AddLine('X-Priority: 1')
    SELF.Mime.AddLine('Importance: High')
  OF ETPri:Low
    SELF.Mime.AddLine('X-Priority: 5')
    SELF.Mime.AddLine('Importance: Low')
  END
  IF SELF.ReadReceipt
    SELF.Mime.AddLine('Disposition-Notification-To: ' & CLIP(SELF.FromAddr))
  END
  LOOP i = 1 TO RECORDS(SELF.HeaderQ)
    GET(SELF.HeaderQ, i)
    SELF.Mime.AddLine(CLIP(SELF.HeaderQ.HName) & ': ' & CLIP(SELF.HeaderQ.HValue))
  END

  !-- body -------------------------------------------------------------------
  IF useMix
    SELF.Mime.AddLine('Content-Type: multipart/mixed; boundary="' & CLIP(mixedB) & '"')
    SELF.Mime.AddLine('')
    SELF.Mime.AddLine('This is a multi-part message in MIME format.')
    SELF.Mime.AddLine('')
    SELF.Mime.AddLine('--' & CLIP(mixedB))
    DO WriteRelated
    LOOP i = 1 TO RECORDS(SELF.AttachQ)
      GET(SELF.AttachQ, i)
      IF SELF.AttachQ.ContentId THEN CYCLE.
      SELF.Mime.AddLine('--' & CLIP(mixedB))
      SELF.WriteAttachment(SELF.Mime, i)
    END
    SELF.Mime.AddLine('--' & CLIP(mixedB) & '--')
  ELSE
    DO WriteRelated
  END

  IF SELF.MaxSize > 0 AND SELF.Mime.Len > SELF.MaxSize
    RETURN SELF.SetErr(ETMsg:TooBig, 'The message is ' & SELF.Mime.Len & |
                       ' bytes, over the ' & SELF.MaxSize & ' byte limit.')
  END
  SELF.SetErr(ETMsg:Ok)
  RETURN SELF.Mime.Len

WriteRelated ROUTINE
  IF useRel
    SELF.Mime.AddLine('Content-Type: multipart/related; boundary="' & CLIP(relB) & '"')
    SELF.Mime.AddLine('')
    SELF.Mime.AddLine('--' & CLIP(relB))
    DO WriteAlternative
    LOOP i = 1 TO RECORDS(SELF.AttachQ)
      GET(SELF.AttachQ, i)
      IF NOT SELF.AttachQ.ContentId THEN CYCLE.
      SELF.Mime.AddLine('--' & CLIP(relB))
      SELF.WriteAttachment(SELF.Mime, i)
    END
    SELF.Mime.AddLine('--' & CLIP(relB) & '--')
  ELSE
    DO WriteAlternative
  END

WriteAlternative ROUTINE
  IF useAlt
    SELF.Mime.AddLine('Content-Type: multipart/alternative; boundary="' & CLIP(altB) & '"')
    SELF.Mime.AddLine('')
    SELF.Mime.AddLine('--' & CLIP(altB))
    SELF.WriteBodyPart(SELF.Mime, 'text/plain', SELF.TextBody)
    SELF.Mime.AddLine('--' & CLIP(altB))
    SELF.WriteBodyPart(SELF.Mime, 'text/html', SELF.HtmlBody)
    SELF.Mime.AddLine('--' & CLIP(altB) & '--')
  ELSIF hasHtml
    SELF.WriteBodyPart(SELF.Mime, 'text/html', SELF.HtmlBody)
  ELSE
    SELF.WriteBodyPart(SELF.Mime, 'text/plain', SELF.TextBody)
  END
