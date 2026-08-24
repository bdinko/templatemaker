! ============================================================================
!  EmailJsonClass - implementation.  Pure Clarion; no C, no DLL, no Windows.
!
!  A recursive-descent parser.  It never copies a value while parsing: a node
!  records WHERE its value sits in the document and how long it is, and the
!  bytes are only unescaped when somebody actually asks for them.  Parsing a
!  200 KB block list is therefore one pass and one allocation.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  INCLUDE('EmailJsonClass.INC'),ONCE

!  UTF-8 -> Windows-1252, for the 27 code points that Windows-1252 keeps in
!  80h..9Fh and Latin-1 does not have.  Anything else above 00FFh has no
!  Windows-1252 spelling at all and becomes a question mark.
ETJ_HiCp     LONG,DIM(27)
ETJ_HiByte   LONG,DIM(27)
ETJ_HexTbl   STRING('0123456789abcdef')

  MAP
  END

! ============================================================================
!  Housekeeping
! ============================================================================
EmailJsonClass.Construct PROCEDURE
  CODE
  SELF.NodeQ  &= NEW(EmailJsonQueue)
  SELF.IdxQ   &= NEW(EmailJsonIdxQueue)
  SELF.ValBuf &= NEW(EmailBufClass)
  SELF.NamBuf &= NEW(EmailBufClass)
  SELF.RawBuf &= NEW(EmailBufClass)
  DO BuildHiTable
  RETURN

BuildHiTable ROUTINE
  ETJ_HiCp[1]  = 20ACh ; ETJ_HiByte[1]  = 080h      ! euro
  ETJ_HiCp[2]  = 201Ah ; ETJ_HiByte[2]  = 082h      ! single low quote
  ETJ_HiCp[3]  = 0192h ; ETJ_HiByte[3]  = 083h      ! florin
  ETJ_HiCp[4]  = 201Eh ; ETJ_HiByte[4]  = 084h      ! double low quote
  ETJ_HiCp[5]  = 2026h ; ETJ_HiByte[5]  = 085h      ! ellipsis
  ETJ_HiCp[6]  = 2020h ; ETJ_HiByte[6]  = 086h      ! dagger
  ETJ_HiCp[7]  = 2021h ; ETJ_HiByte[7]  = 087h      ! double dagger
  ETJ_HiCp[8]  = 02C6h ; ETJ_HiByte[8]  = 088h      ! circumflex
  ETJ_HiCp[9]  = 2030h ; ETJ_HiByte[9]  = 089h      ! per mille
  ETJ_HiCp[10] = 0160h ; ETJ_HiByte[10] = 08Ah      ! S caron
  ETJ_HiCp[11] = 2039h ; ETJ_HiByte[11] = 08Bh      ! single left angle quote
  ETJ_HiCp[12] = 0152h ; ETJ_HiByte[12] = 08Ch      ! OE
  ETJ_HiCp[13] = 017Dh ; ETJ_HiByte[13] = 08Eh      ! Z caron
  ETJ_HiCp[14] = 2018h ; ETJ_HiByte[14] = 091h      ! left single quote
  ETJ_HiCp[15] = 2019h ; ETJ_HiByte[15] = 092h      ! right single quote
  ETJ_HiCp[16] = 201Ch ; ETJ_HiByte[16] = 093h      ! left double quote
  ETJ_HiCp[17] = 201Dh ; ETJ_HiByte[17] = 094h      ! right double quote
  ETJ_HiCp[18] = 2022h ; ETJ_HiByte[18] = 095h      ! bullet
  ETJ_HiCp[19] = 2013h ; ETJ_HiByte[19] = 096h      ! en dash
  ETJ_HiCp[20] = 2014h ; ETJ_HiByte[20] = 097h      ! em dash
  ETJ_HiCp[21] = 02DCh ; ETJ_HiByte[21] = 098h      ! small tilde
  ETJ_HiCp[22] = 2122h ; ETJ_HiByte[22] = 099h      ! trade mark
  ETJ_HiCp[23] = 0161h ; ETJ_HiByte[23] = 09Ah      ! s caron
  ETJ_HiCp[24] = 203Ah ; ETJ_HiByte[24] = 09Bh      ! single right angle quote
  ETJ_HiCp[25] = 0153h ; ETJ_HiByte[25] = 09Ch      ! oe
  ETJ_HiCp[26] = 017Eh ; ETJ_HiByte[26] = 09Eh      ! z caron
  ETJ_HiCp[27] = 0178h ; ETJ_HiByte[27] = 09Fh      ! Y diaeresis

EmailJsonClass.Destruct PROCEDURE
  CODE
  SELF.ClearAll()
  IF NOT SELF.NodeQ  &= NULL THEN DISPOSE(SELF.NodeQ).
  IF NOT SELF.IdxQ   &= NULL THEN DISPOSE(SELF.IdxQ).
  IF NOT SELF.ValBuf &= NULL THEN DISPOSE(SELF.ValBuf).
  IF NOT SELF.NamBuf &= NULL THEN DISPOSE(SELF.NamBuf).
  IF NOT SELF.RawBuf &= NULL THEN DISPOSE(SELF.RawBuf).
  RETURN

EmailJsonClass.ClearAll PROCEDURE
  CODE
  IF NOT SELF.NodeQ &= NULL THEN FREE(SELF.NodeQ).
  IF NOT SELF.IdxQ  &= NULL THEN FREE(SELF.IdxQ).
  IF NOT SELF.Doc   &= NULL
    DISPOSE(SELF.Doc)
    SELF.Doc &= NULL
  END
  SELF.DocLen = 0
  SELF.Pos    = 0
  RETURN

EmailJsonClass.SetErr PROCEDURE(LONG pCode,<STRING pText>)
  CODE
  SELF.LastError = pCode
  IF OMITTED(pText) OR NOT CLIP(pText)
    CASE pCode
    OF ETJs:Ok      ; SELF.LastErrorText = ''
    OF ETJs:Syntax  ; SELF.LastErrorText = 'The reply is not valid JSON.'
    OF ETJs:TooDeep ; SELF.LastErrorText = 'The reply nests deeper than this parser goes.'
    OF ETJs:Empty   ; SELF.LastErrorText = 'The reply was empty.'
    ELSE            ; SELF.LastErrorText = 'JSON error ' & pCode & '.'
    END
  ELSE
    SELF.LastErrorText = CLIP(pText)
  END
  RETURN CHOOSE(pCode = ETJs:Ok, 1, 0)

! ============================================================================
!  Parsing
! ============================================================================
EmailJsonClass.Parse PROCEDURE(STRING pJson)
n  LONG
i  LONG
  CODE
  SELF.ClearAll()
  n = SIZE(pJson)
  LOOP WHILE n > 0 AND VAL(pJson[n]) <= 32                  ! ignore the padding a STRING carries
    n -= 1
  END
  IF n < 1 THEN RETURN SELF.SetErr(ETJs:Empty).

  SELF.Doc &= NEW(STRING(n))
  SELF.Doc[1 : n] = pJson[1 : n]
  SELF.DocLen = n
  SELF.Pos    = 1

  !  A UTF-8 byte-order mark in front of the document is legal for a file and
  !  a nuisance here; two providers send one.
  IF n > 3 AND VAL(SELF.Doc[1 : 1]) = 0EFh AND VAL(SELF.Doc[2 : 2]) = 0BBh AND VAL(SELF.Doc[3 : 3]) = 0BFh
    SELF.Pos = 4
  END

  IF NOT SELF.ParseValue('', '', 0)
    RETURN 0
  END

  !  Build the sorted path index.  One pass, then one SORT: a lookup after
  !  this is a binary search instead of a walk.
  LOOP i = 1 TO RECORDS(SELF.NodeQ)
    GET(SELF.NodeQ, i)
    SELF.IdxQ.Path = SELF.NodeQ.Path
    SELF.IdxQ.Node = i
    ADD(SELF.IdxQ)
  END
  SORT(SELF.IdxQ, SELF.IdxQ.Path)
  RETURN SELF.SetErr(ETJs:Ok)

EmailJsonClass.SkipWs PROCEDURE
b LONG
  CODE
  LOOP WHILE SELF.Pos <= SELF.DocLen
    b = VAL(SELF.Doc[SELF.Pos : SELF.Pos])
    IF b <> 32 AND b <> 9 AND b <> 13 AND b <> 10 THEN BREAK.
    SELF.Pos += 1
  END
  RETURN

!  Positioned on the opening quote.  Answers with the CONTENT slice (escapes
!  intact) and leaves Pos on the character after the closing quote.
EmailJsonClass.ScanString PROCEDURE(*LONG pOfs,*LONG pLen)
  CODE
  IF SELF.Pos > SELF.DocLen OR SELF.Doc[SELF.Pos : SELF.Pos] <> '"'
    RETURN SELF.SetErr(ETJs:Syntax, 'Expected a quoted string at character ' & SELF.Pos & '.')
  END
  SELF.Pos += 1
  pOfs = SELF.Pos
  LOOP WHILE SELF.Pos <= SELF.DocLen
    CASE SELF.Doc[SELF.Pos : SELF.Pos]
    OF '\'                                                  ! a backslash is not special to
      SELF.Pos += 2                                         !   Clarion, so this really is one
      CYCLE                                                 !   character - the escape and the
    OF '"'                                                  !   character it protects, skipped
      pLen = SELF.Pos - pOfs
      SELF.Pos += 1
      RETURN 1
    END
    SELF.Pos += 1
  END
  RETURN SELF.SetErr(ETJs:Syntax, 'A string was never closed.')

EmailJsonClass.ParseValue PROCEDURE(STRING pPath,STRING pName,BYTE pDepth)
ndx    LONG                                                 ! this node's number
kids   LONG
sOfs   LONG
sLen   LONG
mName CSTRING(129)
kidPth CSTRING(257)
vStart  LONG
b      LONG
  CODE
  IF pDepth > ETJs:MaxDepth THEN RETURN SELF.SetErr(ETJs:TooDeep).
  SELF.SkipWs()
  IF SELF.Pos > SELF.DocLen
    RETURN SELF.SetErr(ETJs:Syntax, 'The document ended in the middle of a value.')
  END

  CLEAR(SELF.NodeQ)
  SELF.NodeQ.Depth = pDepth
  SELF.NodeQ.Path  = SUB(CLIP(pPath), 1, 256)
  SELF.NodeQ.Name  = SUB(CLIP(pName), 1, 128)
  SELF.NodeQ.Ofs   = SELF.Pos
  vStart            = SELF.Pos

  CASE SELF.Doc[SELF.Pos : SELF.Pos]
  OF '{'
    SELF.NodeQ.Kind = ETJs:Object
    ADD(SELF.NodeQ)
    ndx = RECORDS(SELF.NodeQ)
    SELF.Pos += 1
    kids = 0
    LOOP
      SELF.SkipWs()
      IF SELF.Pos > SELF.DocLen THEN RETURN SELF.SetErr(ETJs:Syntax, 'An object was never closed.').
      IF SELF.Doc[SELF.Pos : SELF.Pos] = '}'
        SELF.Pos += 1
        BREAK
      END
      IF kids > 0
        IF SELF.Doc[SELF.Pos : SELF.Pos] <> ','
          RETURN SELF.SetErr(ETJs:Syntax, 'Expected a comma at character ' & SELF.Pos & '.')
        END
        SELF.Pos += 1
        SELF.SkipWs()
      END
      IF NOT SELF.ScanString(sOfs, sLen) THEN RETURN 0.
      SELF.Decode(sOfs, sLen, SELF.NamBuf)
      mName = SUB(SELF.NamBuf.Value(), 1, 128)
      SELF.SkipWs()
      IF SELF.Pos > SELF.DocLen OR SELF.Doc[SELF.Pos : SELF.Pos] <> ':'
        RETURN SELF.SetErr(ETJs:Syntax, 'Expected a colon after "' & CLIP(mName) & '".')
      END
      SELF.Pos += 1
      IF CLIP(pPath)
        kidPth = SUB(CLIP(pPath) & '.' & CLIP(mName), 1, 256)
      ELSE
        kidPth = SUB(CLIP(mName), 1, 256)
      END
      IF NOT SELF.ParseValue(kidPth, mName, pDepth + 1) THEN RETURN 0.
      kids += 1
    END

  OF '['
    SELF.NodeQ.Kind = ETJs:Array
    ADD(SELF.NodeQ)
    ndx = RECORDS(SELF.NodeQ)
    SELF.Pos += 1
    kids = 0
    LOOP
      SELF.SkipWs()
      IF SELF.Pos > SELF.DocLen THEN RETURN SELF.SetErr(ETJs:Syntax, 'An array was never closed.').
      IF SELF.Doc[SELF.Pos : SELF.Pos] = ']'
        SELF.Pos += 1
        BREAK
      END
      IF kids > 0
        IF SELF.Doc[SELF.Pos : SELF.Pos] <> ','
          RETURN SELF.SetErr(ETJs:Syntax, 'Expected a comma at character ' & SELF.Pos & '.')
        END
        SELF.Pos += 1
      END
      IF CLIP(pPath)
        kidPth = SUB(CLIP(pPath) & '.' & kids, 1, 256)
      ELSE
        kidPth = SUB('' & kids, 1, 256)
      END
      IF NOT SELF.ParseValue(kidPth, '', pDepth + 1) THEN RETURN 0.
      kids += 1
    END

  OF '"'
    IF NOT SELF.ScanString(sOfs, sLen) THEN RETURN 0.
    SELF.NodeQ.Kind = ETJs:String
    SELF.NodeQ.Ofs  = sOfs
    SELF.NodeQ.Len  = sLen
    ADD(SELF.NodeQ)
    RETURN 1

  ELSE
    !  true, false, null or a number - everything that runs to the next
    !  delimiter.  A provider that invents a bare word gets it back as a
    !  number-shaped value rather than an error, which is the forgiving
    !  reading and costs nothing.
    LOOP WHILE SELF.Pos <= SELF.DocLen
      b = VAL(SELF.Doc[SELF.Pos : SELF.Pos])
      IF b = 44 OR b = 125 OR b = 93 OR b <= 32 THEN BREAK.  ! , } ] or white space
      SELF.Pos += 1
    END
    SELF.NodeQ.Len = SELF.Pos - vStart
    IF SELF.NodeQ.Len < 1
      RETURN SELF.SetErr(ETJs:Syntax, 'An empty value at character ' & vStart & '.')
    END
    CASE LOWER(SELF.Doc[vStart : SELF.Pos - 1])
    OF 'true'  ; SELF.NodeQ.Kind = ETJs:True
    OF 'false' ; SELF.NodeQ.Kind = ETJs:False
    OF 'null'  ; SELF.NodeQ.Kind = ETJs:Null
    ELSE       ; SELF.NodeQ.Kind = ETJs:Number
    END
    ADD(SELF.NodeQ)
    RETURN 1
  END

  !  Only an object or an array reaches here, and only after its children have
  !  been added.  Adding never moves an existing entry, so ndx is still ours.
  GET(SELF.NodeQ, ndx)
  SELF.NodeQ.Items = kids
  SELF.NodeQ.Len   = SELF.Pos - SELF.NodeQ.Ofs
  PUT(SELF.NodeQ)
  RETURN 1

! ============================================================================
!  Asking questions
! ============================================================================
EmailJsonClass.Find PROCEDURE(STRING pPath)
  CODE
  IF SELF.IdxQ &= NULL OR NOT RECORDS(SELF.IdxQ) THEN RETURN 0.
  SELF.IdxQ.Path = SUB(CLIP(pPath), 1, 256)
  GET(SELF.IdxQ, SELF.IdxQ.Path)
  IF ERRORCODE() THEN RETURN 0.
  RETURN SELF.IdxQ.Node

EmailJsonClass.Has PROCEDURE(STRING pPath)
  CODE
  RETURN CHOOSE(SELF.Find(pPath) > 0, 1, 0)

EmailJsonClass.KindOf PROCEDURE(STRING pPath)
n LONG
  CODE
  n = SELF.Find(pPath)
  IF NOT n THEN RETURN 0.
  GET(SELF.NodeQ, n)
  RETURN SELF.NodeQ.Kind

EmailJsonClass.Count PROCEDURE(STRING pPath)
n LONG
  CODE
  n = SELF.Find(pPath)
  IF NOT n THEN RETURN 0.
  GET(SELF.NodeQ, n)
  RETURN SELF.NodeQ.Items

EmailJsonClass.Value PROCEDURE(STRING pPath)
n LONG
  CODE
  n = SELF.Find(pPath)
  IF NOT n THEN RETURN ''.
  GET(SELF.NodeQ, n)
  CASE SELF.NodeQ.Kind
  OF ETJs:Null   ; RETURN ''
  OF ETJs:True   ; RETURN 'true'
  OF ETJs:False  ; RETURN 'false'
  OF ETJs:Object OROF ETJs:Array
    RETURN ''                                               ! use Raw() for a whole subtree
  END
  IF SELF.NodeQ.Len < 1 THEN RETURN ''.
  SELF.Decode(SELF.NodeQ.Ofs, SELF.NodeQ.Len, SELF.ValBuf)
  RETURN SELF.FromUtf8(SELF.ValBuf.Value())

EmailJsonClass.ValueLong PROCEDURE(STRING pPath)
s CSTRING(65)
  CODE
  s = SUB(CLIP(SELF.Value(pPath)), 1, 64)
  IF NOT CLIP(s) THEN RETURN 0.
  IF LOWER(s) = 'true'  THEN RETURN 1.
  IF LOWER(s) = 'false' THEN RETURN 0.
  RETURN DEFORMAT(s)

EmailJsonClass.ValueReal PROCEDURE(STRING pPath)
s CSTRING(65)
  CODE
  s = SUB(CLIP(SELF.Value(pPath)), 1, 64)
  IF NOT CLIP(s) THEN RETURN 0.
  RETURN DEFORMAT(s)

EmailJsonClass.ValueBool PROCEDURE(STRING pPath)
s CSTRING(33)
  CODE
  s = LOWER(SUB(CLIP(SELF.Value(pPath)), 1, 32))
  CASE s
  OF 'true' OROF '1' OROF 'yes' OROF 'y' OROF 'active' OROF 'valid'
    RETURN 1
  END
  RETURN 0

EmailJsonClass.Raw PROCEDURE(STRING pPath)
n LONG
  CODE
  n = SELF.Find(pPath)
  IF NOT n THEN RETURN ''.
  GET(SELF.NodeQ, n)
  IF SELF.NodeQ.Len < 1 THEN RETURN ''.
  SELF.RawBuf.ClearAll()
  SELF.RawBuf.Add(SELF.Doc[SELF.NodeQ.Ofs : SELF.NodeQ.Ofs + SELF.NodeQ.Len - 1])
  RETURN SELF.RawBuf.Value()

!  The outermost array, wherever the provider chose to hang it.  Document
!  order is depth order, so the first array we meet is the shallowest one.
EmailJsonClass.FirstArray PROCEDURE()
i LONG
  CODE
  LOOP i = 1 TO RECORDS(SELF.NodeQ)
    GET(SELF.NodeQ, i)
    IF SELF.NodeQ.Kind = ETJs:Array
      RETURN CLIP(SELF.NodeQ.Path)
    END
  END
  RETURN ''

! ============================================================================
!  Text
! ============================================================================
!  Undo the JSON escapes.  \uXXXX is written out as UTF-8 so that the single
!  FromUtf8 pass in Value() folds it with everything else.
EmailJsonClass.Decode PROCEDURE(LONG pOfs,LONG pLen,EmailBufClass pOut)
i     LONG
last  LONG
cp    LONG
lo    LONG
h     LONG
d     LONG
ch    STRING(1)
two   STRING(2)
three STRING(3)
four  STRING(4)
  CODE
  pOut.ClearAll()
  IF pLen < 1 THEN RETURN.
  last = pOfs + pLen - 1
  i    = pOfs
  LOOP WHILE i <= last
    ch = SELF.Doc[i : i]
    IF ch <> '\' OR i = last
      pOut.Add(ch)
      i += 1
      CYCLE
    END
    i += 1
    ch = SELF.Doc[i : i]
    CASE ch
    OF 'n' ; pOut.Add('<10>')  ; i += 1 ; CYCLE
    OF 'r' ; pOut.Add('<13>')  ; i += 1 ; CYCLE
    OF 't' ; pOut.Add('<9>')   ; i += 1 ; CYCLE
    OF 'b' ; pOut.Add('<8>')   ; i += 1 ; CYCLE
    OF 'f' ; pOut.Add('<12>')  ; i += 1 ; CYCLE
    OF 'u'
      IF i + 4 > last
        pOut.Add(ch)
        i += 1
        CYCLE
      END
      cp = 0
      LOOP h = 1 TO 4
        d = INSTRING(LOWER(SELF.Doc[i + h : i + h]), ETJ_HexTbl, 1, 1)
        IF NOT d THEN d = 1.
        cp = cp * 16 + (d - 1)
      END
      i += 5
      !  A surrogate pair is two escapes that mean one character.
      IF cp >= 0D800h AND cp <= 0DBFFh AND i + 5 <= last + 1
        IF SELF.Doc[i : i] = '\' AND LOWER(SELF.Doc[i + 1 : i + 1]) = 'u'
          lo = 0
          LOOP h = 1 TO 4
            d = INSTRING(LOWER(SELF.Doc[i + 1 + h : i + 1 + h]), ETJ_HexTbl, 1, 1)
            IF NOT d THEN d = 1.
            lo = lo * 16 + (d - 1)
          END
          IF lo >= 0DC00h AND lo <= 0DFFFh
            cp = 10000h + (cp - 0D800h) * 400h + (lo - 0DC00h)
            i += 6
          END
        END
      END
      DO EmitUtf8
      CYCLE
    END
    pOut.Add(ch)                                            ! \" \\ \/ and anything unexpected
    i += 1
  END
  RETURN

EmitUtf8 ROUTINE
  IF cp < 80h
    pOut.Add(CHR(cp))
  ELSIF cp < 800h
    two[1] = CHR(BOR(0C0h, BSHIFT(cp, -6)))
    two[2] = CHR(BOR(080h, BAND(cp, 3Fh)))
    pOut.Add(two)
  ELSIF cp < 10000h
    three[1] = CHR(BOR(0E0h, BSHIFT(cp, -12)))
    three[2] = CHR(BOR(080h, BAND(BSHIFT(cp, -6), 3Fh)))
    three[3] = CHR(BOR(080h, BAND(cp, 3Fh)))
    pOut.Add(three)
  ELSE
    four[1] = CHR(BOR(0F0h, BSHIFT(cp, -18)))
    four[2] = CHR(BOR(080h, BAND(BSHIFT(cp, -12), 3Fh)))
    four[3] = CHR(BOR(080h, BAND(BSHIFT(cp, -6), 3Fh)))
    four[4] = CHR(BOR(080h, BAND(cp, 3Fh)))
    pOut.Add(four)
  END

!  UTF-8 in, Windows-1252 out.  Anything Windows-1252 cannot spell becomes '?'
!  rather than a run of mojibake, because the answer usually ends up in a LIST
!  in front of somebody trying to read a bounce reason.
EmailJsonClass.FromUtf8 PROCEDURE(STRING pUtf8)
n     LONG
i     LONG
b     LONG
b2    LONG
cp    LONG
k     LONG
extra LONG
  CODE
  n = SIZE(pUtf8)
  IF n < 1 THEN RETURN ''.
  !  Fast path: pure ASCII is already Windows-1252, so an English reply costs
  !  one comparison per character and no copying at all.
  LOOP i = 1 TO n
    IF VAL(pUtf8[i]) > 127 THEN BREAK.
  END
  IF i > n THEN RETURN pUtf8[1 : n].

  SELF.NamBuf.ClearAll()
  i = 1
  LOOP WHILE i <= n
    b = VAL(pUtf8[i])
    IF b < 80h
      SELF.NamBuf.Add(pUtf8[i])
      i += 1
      CYCLE
    END
    IF BAND(b, 0E0h) = 0C0h
      cp = BAND(b, 1Fh) ; extra = 1
    ELSIF BAND(b, 0F0h) = 0E0h
      cp = BAND(b, 0Fh) ; extra = 2
    ELSIF BAND(b, 0F8h) = 0F0h
      cp = BAND(b, 07h) ; extra = 3
    ELSE
      SELF.NamBuf.Add('?')                                  ! a stray continuation byte
      i += 1
      CYCLE
    END
    IF i + extra > n
      SELF.NamBuf.Add('?')
      BREAK
    END
    LOOP k = 1 TO extra
      b2 = VAL(pUtf8[i + k])
      IF BAND(b2, 0C0h) <> 80h
        cp = -1
        BREAK
      END
      cp = cp * 40h + BAND(b2, 3Fh)
    END
    i += extra + 1
    IF cp < 0
      SELF.NamBuf.Add('?')
      CYCLE
    END
    IF cp >= 0A0h AND cp <= 0FFh
      SELF.NamBuf.Add(CHR(cp))                              ! Latin-1: the same code point
      CYCLE
    END
    LOOP k = 1 TO 27
      IF ETJ_HiCp[k] = cp
        SELF.NamBuf.Add(CHR(ETJ_HiByte[k]))
        BREAK
      END
    END
    IF k <= 27 THEN CYCLE.
    IF cp < 0A0h
      SELF.NamBuf.Add(CHR(cp))                              ! a C1 control: pass it through
    ELSE
      SELF.NamBuf.Add('?')
    END
  END
  RETURN SELF.NamBuf.Value()
