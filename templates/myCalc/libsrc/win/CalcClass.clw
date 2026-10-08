! ============================================================================
!  CalcClass - implementation.   See CalcClass.inc for the overview.
!
!  This file must be stored ANSI, with CRLF line endings.
! ============================================================================
  MEMBER()

  MAP
    MODULE('win32')
      cxModuleFile( LONG hModule, *CSTRING lpFilename, ULONG nSize ),ULONG,RAW,PASCAL,NAME('GetModuleFileNameA')
    END
  END

  INCLUDE('CalcClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

Calc:Pi            EQUATE(3.14159265358979324)
Calc:E             EQUATE(2.71828182845904524)
Calc:CRLF          EQUATE('<13,10>')
!  the numeric keypad codes KEYCODES.CLW does not name
Calc:KeyPadStar    EQUATE(006AH)
Calc:KeyPadDot     EQUATE(006EH)
Calc:OemPeriod     EQUATE(00BEH)

! ############################################################################
!  Lifetime
! ############################################################################
CalcClass.Construct PROCEDURE
  CODE
  SELF.Tape &= NEW CalcTapeQueue
  SELF.Title = 'Calculator'
  SELF.Reset()


CalcClass.Destruct PROCEDURE
  CODE
  IF ~SELF.Tape &= NULL
    FREE(SELF.Tape)
    DISPOSE(SELF.Tape)
  END


CalcClass.Reset PROCEDURE
  CODE
  SELF.Entry    = '0'
  SELF.Expr     = ''
  SELF.Acc      = 0
  SELF.Pend     = Act:None
  SELF.NewEnt   = 1
  SELF.PDepth   = 0
  SELF.ErrState = 0
  SELF.Running  = 0


! ############################################################################
!  Formatting
! ############################################################################
!  The readout: base-N in programmer mode, fixed decimals on the tape, and a
!  trimmed general format everywhere else.
CalcClass.Fmt PROCEDURE(REAL pV)
  CODE
  IF SELF.Mode = Calc:Programmer THEN RETURN SELF.ToBase(pV) .
  IF SELF.Mode = Calc:Accountant
    RETURN CLIP(LEFT(FORMAT(pV,'@n-18.' & SELF.Decimals)))
  END
  RETURN SELF.FmtPlain(pV)


!  A plain number: no thousands separators, no trailing zero noise.
!
!  Deliberately NOT via FORMAT(). An @N picture always groups with commas here
!  (FORMAT(1024,@n24.10) gives '1,024.0000000000'), and the grouped result then
!  fails to parse back. Clarion's own REAL -> STRING conversion gives exactly
!  what a calculator readout wants - '1024', '2.5', '-7.25' - so use that.
CalcClass.FmtPlain PROCEDURE(REAL pV)
s   CSTRING(48)
a   REAL,AUTO
  CODE
  a = ABS(pV)
  IF a <> 0 AND (a >= 1.0e15 OR a < 1.0e-11)
    RETURN CLIP(LEFT(FORMAT(pV,@e14-)))                   ! too big / too small: exponent form
  END
  s = pV                                                  ! plain, ungrouped, untrimmed of meaning
  s = CLIP(LEFT(s))
  IF ~s THEN s = '0' .
  RETURN s


CalcClass.MaskWord PROCEDURE(REAL pV)
n   REAL,AUTO
lim REAL,AUTO
  CODE
  n = INT(pV)
  CASE SELF.WordBits
  OF  8 ; lim = 256
  OF 16 ; lim = 65536
  ELSE  ; lim = 4294967296
  END
  n = n - INT(n / lim) * lim                              ! wrap into the word
  IF n < 0 THEN n += lim .
  RETURN n


CalcClass.ToBase PROCEDURE(REAL pV)
n     REAL,AUTO
d     LONG,AUTO
s     CSTRING(72)
digs  STRING(16)
  CODE
  digs = '0123456789ABCDEF'
  n = SELF.MaskWord(pV)
  IF SELF.Base = 10
    s = n                                                 ! ungrouped - see FmtPlain
    RETURN CLIP(LEFT(s))
  END
  s = ''
  IF n = 0 THEN RETURN '0' .
  LOOP WHILE n >= 1
    d = n - INT(n / SELF.Base) * SELF.Base
    s = digs[d+1] & s
    n = INT(n / SELF.Base)
  END
  RETURN s


CalcClass.FromBase PROCEDURE(STRING pS)
s   CSTRING(72)
i   LONG,AUTO
d   LONG,AUTO
n   REAL(0)
c   STRING(1)
  CODE
  s = UPPER(CLIP(LEFT(pS)))
  IF SELF.Base = 10 THEN RETURN DEFORMAT(s) .
  LOOP i = 1 TO LEN(s)
    c = s[i]
    IF c >= '0' AND c <= '9'
      d = VAL(c) - 48
    ELSIF c >= 'A' AND c <= 'F'
      d = VAL(c) - 55
    ELSE
      CYCLE
    END
    IF d >= SELF.Base THEN CYCLE .
    n = n * SELF.Base + d
  END
  RETURN n


CalcClass.Current PROCEDURE()
  CODE
  IF SELF.Mode = Calc:Programmer THEN RETURN SELF.FromBase(SELF.Entry) .
!  No picture on purpose: DEFORMAT with an @N picture reads '.' as the thousands
!  separator and turns '116.00' into 11600. Picture-less DEFORMAT keeps the
!  decimal point and the sign, and still strips the grouping commas the
!  accountant readout puts in.
  RETURN DEFORMAT(SELF.Entry)


CalcClass.DisplayText PROCEDURE()
  CODE
  IF SELF.ErrState THEN RETURN SELF.Entry .
  RETURN SELF.Entry


CalcClass.SetValue PROCEDURE(REAL pValue)
  CODE
  SELF.Value  = pValue
  SELF.Entry  = SELF.Fmt(pValue)
  SELF.NewEnt = 1
  SELF.ErrState = 0


CalcClass.Fail PROCEDURE(STRING pWhy)
  CODE
  SELF.Entry    = CLIP(pWhy)
  SELF.ErrState = 1
  SELF.NewEnt   = 1
  SELF.Pend     = Act:None
  SELF.PDepth   = 0


! ############################################################################
!  Words.  Everything the window shows, and every word-key label, comes through
!  here - so a whole calculator changes language by setting one property.
!  Digits, operators and the maths names (sin, log, x^y, HEX...) read the same
!  in both languages and are deliberately left alone.
! ############################################################################
CalcClass.Txt PROCEDURE(LONG pId)
  CODE
  IF SELF.Language = Calc:Spanish
    CASE pId
    OF CalcTxt:Calculator ; RETURN 'Calculadora'
    OF CalcTxt:Standard   ; RETURN 'Estándar'
    OF CalcTxt:Scientific ; RETURN 'Científica'
    OF CalcTxt:Programmer ; RETURN 'Programador'
    OF CalcTxt:Accountant ; RETURN 'Contable (cinta)'
    OF CalcTxt:Mode       ; RETURN '&Modo:'
    OF CalcTxt:PaperRoll  ; RETURN 'Cinta de &papel'
    OF CalcTxt:Roll       ; RETURN 'Cinta'
    OF CalcTxt:Copy       ; RETURN 'Copiar'
    OF CalcTxt:Clear      ; RETURN 'Limpiar'
    OF CalcTxt:Accept     ; RETURN '&Aceptar'
    OF CalcTxt:Cancel     ; RETURN 'Cancelar'
    OF CalcTxt:Hint       ; RETURN 'Entrar = igual   Esc = cerrar'
    OF CalcTxt:DivZero    ; RETURN 'No se puede dividir entre cero'
    OF CalcTxt:BadInput   ; RETURN 'Entrada no válida'
    OF CalcTxt:NotNumber  ; RETURN 'No es un número'
    OF CalcTxt:FixError   ; RETURN 'La calculadora muestra un error: bórralo primero.'
    OF CalcTxt:Bksp       ; RETURN 'Borr'
    OF CalcTxt:Subtotal   ; RETURN 'SUBT'
    OF CalcTxt:Total      ; RETURN 'TOTAL'
    OF CalcTxt:GrandTot   ; RETURN 'TG'
    OF CalcTxt:TaxPlus    ; RETURN 'IVA+'
    OF CalcTxt:TaxMinus   ; RETURN 'IVA-'
    OF CalcTxt:WordSize   ; RETURN 'BITS'
    OF CalcTxt:CopyTip    ; RETURN 'Copiar toda la cinta al portapapeles'
    END
    RETURN ''
  END
  CASE pId
  OF CalcTxt:Calculator ; RETURN 'Calculator'
  OF CalcTxt:Standard   ; RETURN 'Standard'
  OF CalcTxt:Scientific ; RETURN 'Scientific'
  OF CalcTxt:Programmer ; RETURN 'Programmer'
  OF CalcTxt:Accountant ; RETURN 'Accountant (tape)'
  OF CalcTxt:Mode       ; RETURN '&Mode:'
  OF CalcTxt:PaperRoll  ; RETURN 'Paper &roll'
  OF CalcTxt:Roll       ; RETURN 'Roll'
  OF CalcTxt:Copy       ; RETURN 'Copy'
  OF CalcTxt:Clear      ; RETURN 'Clear'
  OF CalcTxt:Accept     ; RETURN '&Accept'
  OF CalcTxt:Cancel     ; RETURN 'Cancel'
  OF CalcTxt:Hint       ; RETURN 'Enter = equals   Esc = close'
  OF CalcTxt:DivZero    ; RETURN 'Cannot divide by zero'
  OF CalcTxt:BadInput   ; RETURN 'Invalid input'
  OF CalcTxt:NotNumber  ; RETURN 'Not a number'
  OF CalcTxt:FixError   ; RETURN 'The calculator is showing an error - clear it first.'
  OF CalcTxt:Bksp       ; RETURN 'Bksp'
  OF CalcTxt:Subtotal   ; RETURN 'SUB'
  OF CalcTxt:Total      ; RETURN 'TOTAL'
  OF CalcTxt:GrandTot   ; RETURN 'GT'
  OF CalcTxt:TaxPlus    ; RETURN 'TAX+'
  OF CalcTxt:TaxMinus   ; RETURN 'TAX-'
  OF CalcTxt:WordSize   ; RETURN 'WORD'
  OF CalcTxt:CopyTip    ; RETURN 'Copy the whole roll to the clipboard'
  END
  RETURN ''


CalcClass.ModeName PROCEDURE(BYTE pMode)
  CODE
  CASE pMode
  OF Calc:Standard   ; RETURN SELF.Txt(CalcTxt:Standard)
  OF Calc:Scientific ; RETURN SELF.Txt(CalcTxt:Scientific)
  OF Calc:Programmer ; RETURN SELF.Txt(CalcTxt:Programmer)
  OF Calc:Accountant ; RETURN SELF.Txt(CalcTxt:Accountant)
  END
  RETURN ''


CalcClass.Allowed PROCEDURE(BYTE pMode)
  CODE
  IF pMode < 1 OR pMode > Calc:Modes THEN RETURN 0 .
  IF ~SELF.Allow THEN RETURN 1 .
  RETURN CHOOSE(BAND(SELF.Allow,BSHIFT(1,pMode-1)) <> 0,1,0)


CalcClass.OpText PROCEDURE(LONG pOp)
  CODE
  CASE pOp
  OF Act:Add ; RETURN '+'
  OF Act:Sub ; RETURN '-'
  OF Act:Mul ; RETURN '*'
  OF Act:Div ; RETURN '/'
  OF Act:Pow ; RETURN '^'
  OF Act:Mod ; RETURN ' mod '
  OF Act:And ; RETURN ' AND '
  OF Act:Or  ; RETURN ' OR '
  OF Act:Xor ; RETURN ' XOR '
  OF Act:Shl ; RETURN ' << '
  OF Act:Shr ; RETURN ' >> '
  END
  RETURN ''


! ############################################################################
!  Arithmetic
! ############################################################################
CalcClass.Apply PROCEDURE(LONG pOp,REAL pRight)
l  REAL,AUTO
r  REAL,AUTO
  CODE
  l = SELF.Acc
  r = pRight
  CASE pOp
  OF Act:None ; RETURN r
  OF Act:Add  ; RETURN l + r
  OF Act:Sub  ; RETURN l - r
  OF Act:Mul  ; RETURN l * r
  OF Act:Div
    IF r = 0
      SELF.Fail(SELF.Txt(CalcTxt:DivZero))
      RETURN 0
    END
    RETURN l / r
  OF Act:Pow
    IF l = 0 AND r < 0
      SELF.Fail(SELF.Txt(CalcTxt:DivZero))
      RETURN 0
    END
    IF l < 0 AND r <> INT(r)
      SELF.Fail(SELF.Txt(CalcTxt:NotNumber))
      RETURN 0
    END
    RETURN l ^ r
  OF Act:Mod
    IF INT(r) = 0
      SELF.Fail(SELF.Txt(CalcTxt:DivZero))
      RETURN 0
    END
    RETURN INT(l) - INT(INT(l) / INT(r)) * INT(r)
  OF Act:And  ; RETURN SELF.MaskWord(BAND(SELF.MaskWord(l),SELF.MaskWord(r)))
  OF Act:Or   ; RETURN SELF.MaskWord(BOR(SELF.MaskWord(l),SELF.MaskWord(r)))
  OF Act:Xor  ; RETURN SELF.MaskWord(BXOR(SELF.MaskWord(l),SELF.MaskWord(r)))
  OF Act:Shl  ; RETURN SELF.MaskWord(BSHIFT(SELF.MaskWord(l),INT(r)))
  OF Act:Shr  ; RETURN SELF.MaskWord(BSHIFT(SELF.MaskWord(l),-INT(r)))
  END
  RETURN r


CalcClass.Unary PROCEDURE(LONG pAct,REAL pV)
v  REAL,AUTO
i  LONG,AUTO
f  REAL,AUTO
  CODE
  v = pV
  CASE pAct
  OF Act:Sqrt
    IF v < 0 THEN SELF.Fail(SELF.Txt(CalcTxt:BadInput)) ; RETURN 0 .
    RETURN SQRT(v)
  OF Act:Sqr      ; RETURN v * v
  OF Act:Cube     ; RETURN v * v * v
  OF Act:CubeRoot
    IF v < 0 THEN RETURN -((-v) ^ (1/3)) .
    RETURN v ^ (1/3)
  OF Act:Inv
    IF v = 0 THEN SELF.Fail(SELF.Txt(CalcTxt:DivZero)) ; RETURN 0 .
    RETURN 1 / v
  OF Act:Abs      ; RETURN ABS(v)
  OF Act:Fact
    IF v < 0 OR v <> INT(v) OR v > 170
      SELF.Fail(SELF.Txt(CalcTxt:BadInput))
      RETURN 0
    END
    f = 1
    LOOP i = 2 TO INT(v)
      f = f * i
    END
    RETURN f
  OF Act:Ln
    IF v <= 0 THEN SELF.Fail(SELF.Txt(CalcTxt:BadInput)) ; RETURN 0 .
    RETURN LOGE(v)
  OF Act:Log
    IF v <= 0 THEN SELF.Fail(SELF.Txt(CalcTxt:BadInput)) ; RETURN 0 .
    RETURN LOG10(v)
  OF Act:ExpE     ; RETURN Calc:E ^ v
  OF Act:Exp10    ; RETURN 10 ^ v
  OF Act:Sin      ; RETURN SIN(CHOOSE(SELF.Angle=0,v * Calc:Pi / 180,v))
  OF Act:Cos      ; RETURN COS(CHOOSE(SELF.Angle=0,v * Calc:Pi / 180,v))
  OF Act:Tan      ; RETURN TAN(CHOOSE(SELF.Angle=0,v * Calc:Pi / 180,v))
  OF Act:ASin
    IF v < -1 OR v > 1 THEN SELF.Fail(SELF.Txt(CalcTxt:BadInput)) ; RETURN 0 .
    RETURN CHOOSE(SELF.Angle=0,ASIN(v) * 180 / Calc:Pi,ASIN(v))
  OF Act:ACos
    IF v < -1 OR v > 1 THEN SELF.Fail(SELF.Txt(CalcTxt:BadInput)) ; RETURN 0 .
    RETURN CHOOSE(SELF.Angle=0,ACOS(v) * 180 / Calc:Pi,ACOS(v))
  OF Act:ATan     ; RETURN CHOOSE(SELF.Angle=0,ATAN(v) * 180 / Calc:Pi,ATAN(v))
  OF Act:Not      ; RETURN SELF.MaskWord(BXOR(SELF.MaskWord(v),SELF.MaskWord(-1)))
  END
  RETURN v


! ############################################################################
!  One key press.  Everything the window does goes through here, so the whole
!  calculator can also be driven from code or from a test.
! ############################################################################
CalcClass.Press PROCEDURE(LONG pAct,STRING pText)
v    REAL,AUTO
r    REAL,AUTO
t    CSTRING(16)
  CODE
  t = CLIP(LEFT(pText))
  IF SELF.ErrState AND pAct <> Act:ClearAll AND pAct <> Act:ClearEntry
    SELF.ErrState = 0                                     ! any key clears an error first
    SELF.Entry    = '0'
    SELF.NewEnt   = 1
  END

  CASE pAct
! ---- typing ---------------------------------------------------------------
  OF Act:Digit
    IF SELF.NewEnt
      SELF.Entry  = ''
      SELF.NewEnt = 0
    END
    IF SELF.Entry = '0' AND t <> '.' THEN SELF.Entry = '' .
    IF LEN(SELF.Entry) + LEN(t) <= 40 THEN SELF.Entry = SELF.Entry & t .
    IF ~SELF.Entry THEN SELF.Entry = '0' .
  OF Act:Dot
    IF SELF.Mode = Calc:Programmer AND SELF.Base <> 10 THEN RETURN .
    IF SELF.NewEnt
      SELF.Entry  = '0'
      SELF.NewEnt = 0
    END
    IF ~INSTRING('.',SELF.Entry,1,1) THEN SELF.Entry = CLIP(SELF.Entry) & '.' .
  OF Act:Sign
    IF SELF.Entry[1] = '-'
      SELF.Entry = SUB(SELF.Entry,2,47)
    ELSIF SELF.Entry <> '0'
      SELF.Entry = '-' & SELF.Entry
    END
  OF Act:Back
    IF ~SELF.NewEnt
      IF LEN(SELF.Entry) > 1
        SELF.Entry = SUB(SELF.Entry,1,LEN(SELF.Entry)-1)
        IF SELF.Entry = '-' THEN SELF.Entry = '0' .
      ELSE
        SELF.Entry = '0'
      END
    END
  OF Act:ClearEntry
    SELF.Entry    = '0'
    SELF.NewEnt   = 1
    SELF.ErrState = 0
  OF Act:ClearAll
    SELF.Reset()
    SELF.GrandTot = 0

! ---- constants ------------------------------------------------------------
  OF Act:Pi
    SELF.Entry  = SELF.Fmt(Calc:Pi)
    SELF.NewEnt = 1
  OF Act:EulerE
    SELF.Entry  = SELF.Fmt(Calc:E)
    SELF.NewEnt = 1

! ---- memory ---------------------------------------------------------------
  OF Act:MemClear
    SELF.Mem    = 0
    SELF.MemSet = 0
  OF Act:MemRecall
    SELF.Entry  = SELF.Fmt(SELF.Mem)
    SELF.NewEnt = 1
  OF Act:MemStore
    SELF.Mem    = SELF.Current()
    SELF.MemSet = 1
    SELF.NewEnt = 1
  OF Act:MemAdd
    SELF.Mem   += SELF.Current()
    SELF.MemSet = 1
    SELF.NewEnt = 1
  OF Act:MemSub
    SELF.Mem   -= SELF.Current()
    SELF.MemSet = 1
    SELF.NewEnt = 1

! ---- toggles --------------------------------------------------------------
  OF Act:DegRad
    SELF.Angle = 1 - SELF.Angle
  OF Act:BaseHex OROF Act:BaseDec OROF Act:BaseOct OROF Act:BaseBin
    v = SELF.Current()                                    ! keep the value, change the view
    CASE pAct
    OF Act:BaseHex ; SELF.Base = 16
    OF Act:BaseDec ; SELF.Base = 10
    OF Act:BaseOct ; SELF.Base = 8
    ELSE           ; SELF.Base = 2
    END
    SELF.Entry  = SELF.Fmt(v)
    SELF.NewEnt = 1
  OF Act:WordSize
    CASE SELF.WordBits
    OF  8 ; SELF.WordBits = 16
    OF 16 ; SELF.WordBits = 32
    ELSE  ; SELF.WordBits = 8
    END
    SELF.Entry = SELF.Fmt(SELF.Current())

! ---- unary functions ------------------------------------------------------
  OF Act:Sqrt OROF Act:Sqr OROF Act:Cube OROF Act:CubeRoot OROF Act:Inv       |
  OROF Act:Fact OROF Act:Ln OROF Act:Log OROF Act:ExpE OROF Act:Exp10         |
  OROF Act:Sin OROF Act:Cos OROF Act:Tan OROF Act:ASin OROF Act:ACos          |
  OROF Act:ATan OROF Act:Not OROF Act:Abs
    v = SELF.Current()
    r = SELF.Unary(pAct,v)
    IF ~SELF.ErrState
      SELF.AddTape(CLIP(t) & '(' & SELF.FmtPlain(v) & ') = ' & SELF.Fmt(r),r,2)
      SELF.Entry  = SELF.Fmt(r)
      SELF.NewEnt = 1
    END

! ---- parentheses ----------------------------------------------------------
  OF Act:OpenParen
    IF SELF.PDepth < 16
      SELF.PDepth += 1
      SELF.PAcc[SELF.PDepth] = SELF.Acc
      SELF.POp[SELF.PDepth]  = SELF.Pend
      SELF.Acc    = 0
      SELF.Pend   = Act:None
      SELF.NewEnt = 1
      SELF.Expr   = CLIP(SELF.Expr) & '('
    END
  OF Act:CloseParen
    IF SELF.PDepth > 0
      v = SELF.Apply(SELF.Pend,SELF.Current())
      IF ~SELF.ErrState
        SELF.Acc    = SELF.PAcc[SELF.PDepth]
        SELF.Pend   = SELF.POp[SELF.PDepth]
        SELF.PDepth -= 1
        SELF.Entry  = SELF.Fmt(v)
        SELF.NewEnt = 1
        SELF.Expr   = CLIP(SELF.Expr) & ')'
      END
    END

! ---- percent --------------------------------------------------------------
  OF Act:Percent
    v = SELF.Current()
    CASE SELF.Pend
    OF Act:Add OROF Act:Sub ; r = SELF.Acc * v / 100      ! 200 + 10% = 220
    ELSE                    ; r = v / 100
    END
    SELF.Entry  = SELF.Fmt(r)
    SELF.NewEnt = 0

! ---- tax (accountant) -----------------------------------------------------
  OF Act:TaxPct
    v = SELF.Current()
    r = v * (1 + SELF.TaxRate / 100)
    SELF.AddTape('tax +' & CLIP(LEFT(FORMAT(SELF.TaxRate,@n-8.2))) & '%  ' & SELF.Fmt(r),r,2)
    SELF.Entry  = SELF.Fmt(r)
    SELF.NewEnt = 1
  OF Act:TaxLess
    v = SELF.Current()
    IF 1 + SELF.TaxRate / 100 = 0
      SELF.Fail(SELF.Txt(CalcTxt:DivZero))
    ELSE
      r = v / (1 + SELF.TaxRate / 100)
      SELF.AddTape('tax -' & CLIP(LEFT(FORMAT(SELF.TaxRate,@n-8.2))) & '%  ' & SELF.Fmt(r),r,2)
      SELF.Entry  = SELF.Fmt(r)
      SELF.NewEnt = 1
    END

! ---- the adding-machine roll ----------------------------------------------
  OF Act:Subtotal
    SELF.AddTape('                    ' & SELF.Fmt(SELF.Running) & '  *',SELF.Running,3)
    SELF.Entry  = SELF.Fmt(SELF.Running)
    SELF.NewEnt = 1
  OF Act:Total
    SELF.AddTape('                    ' & SELF.Fmt(SELF.Running) & '  T',SELF.Running,4)
    SELF.GrandTot += SELF.Running
    SELF.Entry    = SELF.Fmt(SELF.Running)
    SELF.Running  = 0
    SELF.NewEnt   = 1
  OF Act:GrandTotal
    SELF.AddTape('                    ' & SELF.Fmt(SELF.GrandTot) & ' GT',SELF.GrandTot,4)
    SELF.Entry    = SELF.Fmt(SELF.GrandTot)
    SELF.GrandTot = 0
    SELF.NewEnt   = 1

! ---- binary operators and = -----------------------------------------------
  OF Act:Add OROF Act:Sub OROF Act:Mul OROF Act:Div OROF Act:Pow OROF Act:Mod |
  OROF Act:And OROF Act:Or OROF Act:Xor OROF Act:Shl OROF Act:Shr
    v = SELF.Current()
    IF SELF.Mode = Calc:Accountant AND (pAct = Act:Add OR pAct = Act:Sub)
      IF pAct = Act:Add                                   ! post the entry to the roll
        SELF.Running += v
        SELF.AddTape(SELF.Fmt(v) & '  +',v,1)
      ELSE
        SELF.Running -= v
        SELF.AddTape(SELF.Fmt(v) & '  -',v,1)
      END
      SELF.Entry  = SELF.Fmt(v)
      SELF.NewEnt = 1
    ELSE
      IF SELF.Pend <> Act:None AND ~SELF.NewEnt
        r = SELF.Apply(SELF.Pend,v)
        IF SELF.ErrState THEN RETURN .
        SELF.Acc    = r
        SELF.Entry  = SELF.Fmt(r)
      ELSE
        SELF.Acc = v
      END
      SELF.Pend   = pAct
      SELF.NewEnt = 1
      SELF.Expr   = SELF.FmtPlain(SELF.Acc) & ' ' & CLIP(SELF.OpText(pAct))
    END

  OF Act:Equals
    IF SELF.Mode = Calc:Accountant
      SELF.Press(Act:Total,'')
      RETURN
    END
    v = SELF.Current()
    IF SELF.Pend <> Act:None
      r = SELF.Apply(SELF.Pend,v)
      IF SELF.ErrState THEN RETURN .
      SELF.AddTape(SELF.FmtPlain(SELF.Acc) & ' ' & CLIP(SELF.OpText(SELF.Pend)) & ' ' & |
                   SELF.FmtPlain(v) & ' = ' & SELF.Fmt(r),r,2)
      SELF.Entry = SELF.Fmt(r)
      SELF.Acc   = r
      SELF.Pend  = Act:None
    END
    SELF.Expr   = ''
    SELF.NewEnt = 1
  END


! ############################################################################
!  The paper roll
! ############################################################################
CalcClass.AddTape PROCEDURE(STRING pLine,REAL pVal,BYTE pKind)
  CODE
  IF SELF.Tape &= NULL THEN RETURN .
  SELF.Tape.TLine = CLIP(pLine)
  SELF.Tape.TVal  = pVal
  SELF.Tape.TKind = pKind
  ADD(SELF.Tape)
  IF RECORDS(SELF.Tape) > 500                             ! keep the roll a sane length
    GET(SELF.Tape,1)
    DELETE(SELF.Tape)
  END


CalcClass.ClearTape PROCEDURE
  CODE
  IF ~SELF.Tape &= NULL THEN FREE(SELF.Tape) .


CalcClass.TapeLines PROCEDURE()
  CODE
  IF SELF.Tape &= NULL THEN RETURN 0 .
  RETURN RECORDS(SELF.Tape)


CalcClass.TapeLine PROCEDURE(LONG pLine)
  CODE
  IF SELF.Tape &= NULL THEN RETURN '' .
  GET(SELF.Tape,pLine)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Tape.TLine)


CalcClass.TapeText PROCEDURE()
s  ANY
i  LONG,AUTO
  CODE
  IF SELF.Tape &= NULL THEN RETURN '' .
  s = ''
  LOOP i = 1 TO RECORDS(SELF.Tape)
    GET(SELF.Tape,i)
    IF ERRORCODE() THEN CYCLE .
    s = s & CLIP(SELF.Tape.TLine) & Calc:CRLF
  END
  RETURN s


! ############################################################################
!  Key layouts.  A 7 x 7 grid; SetKey fills one cell, everything else is blank
!  and hidden for that mode.
! ############################################################################
CalcClass.SetKey PROCEDURE(LONG pCell,STRING pText,LONG pAct,BYTE pSpan=1)
  CODE
  IF pCell < 1 OR pCell > Calc:Cells THEN RETURN .
  SELF.BtnTxt[pCell]  = pText
  SELF.BtnAct[pCell]  = pAct
  SELF.BtnSpan[pCell] = pSpan


CalcClass.Layout PROCEDURE
i  LONG,AUTO
  CODE
  LOOP i = 1 TO Calc:Cells
    SELF.BtnTxt[i]  = ''
    SELF.BtnAct[i]  = Act:None
    SELF.BtnSpan[i] = 1
  END

  CASE SELF.Mode
! ---------------------------------------------------------------- standard --
  OF Calc:Standard
    SELF.SetKey( 1,'MC',Act:MemClear)  ; SELF.SetKey( 2,'MR',Act:MemRecall)
    SELF.SetKey( 3,'M+',Act:MemAdd)    ; SELF.SetKey( 4,'M-',Act:MemSub)
    SELF.SetKey( 5,'MS',Act:MemStore)
    SELF.SetKey( 8,'%',Act:Percent)    ; SELF.SetKey( 9,'sqrt',Act:Sqrt)
    SELF.SetKey(10,'x^2',Act:Sqr)  ; SELF.SetKey(11,'1/x',Act:Inv)
    SELF.SetKey(12,'C',Act:ClearAll)
    SELF.SetKey(15,'7',Act:Digit)      ; SELF.SetKey(16,'8',Act:Digit)
    SELF.SetKey(17,'9',Act:Digit)      ; SELF.SetKey(18,'/',Act:Div)
    SELF.SetKey(19,'CE',Act:ClearEntry)
    SELF.SetKey(22,'4',Act:Digit)      ; SELF.SetKey(23,'5',Act:Digit)
    SELF.SetKey(24,'6',Act:Digit)      ; SELF.SetKey(25,'*',Act:Mul)
    SELF.SetKey(26,SELF.Txt(CalcTxt:Bksp),Act:Back)
    SELF.SetKey(29,'1',Act:Digit)      ; SELF.SetKey(30,'2',Act:Digit)
    SELF.SetKey(31,'3',Act:Digit)      ; SELF.SetKey(32,'-',Act:Sub)
    SELF.SetKey(33,'+/-',Act:Sign)
    SELF.SetKey(36,'0',Act:Digit,2)    ; SELF.SetKey(38,'.',Act:Dot)
    SELF.SetKey(39,'+',Act:Add)        ; SELF.SetKey(40,'=',Act:Equals)

! -------------------------------------------------------------- scientific --
  OF Calc:Scientific
    SELF.SetKey( 1,'DEG',Act:DegRad)   ; SELF.SetKey( 2,'(',Act:OpenParen)
    SELF.SetKey( 3,')',Act:CloseParen) ; SELF.SetKey( 4,'n!',Act:Fact)
    SELF.SetKey( 5,'%',Act:Percent)    ; SELF.SetKey( 6,'MC',Act:MemClear)
    SELF.SetKey( 7,'MR',Act:MemRecall)
    SELF.SetKey( 8,'sin',Act:Sin)      ; SELF.SetKey( 9,'cos',Act:Cos)
    SELF.SetKey(10,'tan',Act:Tan)      ; SELF.SetKey(11,'ln',Act:Ln)
    SELF.SetKey(12,'log',Act:Log)      ; SELF.SetKey(13,'M+',Act:MemAdd)
    SELF.SetKey(14,'M-',Act:MemSub)
    SELF.SetKey(15,'asin',Act:ASin)    ; SELF.SetKey(16,'acos',Act:ACos)
    SELF.SetKey(17,'atan',Act:ATan)    ; SELF.SetKey(18,'e^x',Act:ExpE)
    SELF.SetKey(19,'10^x',Act:Exp10)   ; SELF.SetKey(20,'x^2',Act:Sqr)
    SELF.SetKey(21,'x^3',Act:Cube)
    SELF.SetKey(22,'sqrt',Act:Sqrt) ; SELF.SetKey(23,'cbrt',Act:CubeRoot)
    SELF.SetKey(24,'1/x',Act:Inv)      ; SELF.SetKey(25,'x^y',Act:Pow)
    SELF.SetKey(26,'mod',Act:Mod)      ; SELF.SetKey(27,'C',Act:ClearAll)
    SELF.SetKey(28,'CE',Act:ClearEntry)
    SELF.SetKey(29,'7',Act:Digit)      ; SELF.SetKey(30,'8',Act:Digit)
    SELF.SetKey(31,'9',Act:Digit)      ; SELF.SetKey(32,'/',Act:Div)
    SELF.SetKey(33,'pi',Act:Pi)        ; SELF.SetKey(34,'e',Act:EulerE)
    SELF.SetKey(35,SELF.Txt(CalcTxt:Bksp),Act:Back)
    SELF.SetKey(36,'4',Act:Digit)      ; SELF.SetKey(37,'5',Act:Digit)
    SELF.SetKey(38,'6',Act:Digit)      ; SELF.SetKey(39,'*',Act:Mul)
    SELF.SetKey(40,'+/-',Act:Sign)     ; SELF.SetKey(41,'abs',Act:Abs)
    SELF.SetKey(42,'+',Act:Add)
    SELF.SetKey(43,'1',Act:Digit)      ; SELF.SetKey(44,'2',Act:Digit)
    SELF.SetKey(45,'3',Act:Digit)      ; SELF.SetKey(46,'-',Act:Sub)
    SELF.SetKey(47,'0',Act:Digit)      ; SELF.SetKey(48,'.',Act:Dot)
    SELF.SetKey(49,'=',Act:Equals)

! -------------------------------------------------------------- programmer --
  OF Calc:Programmer
    SELF.SetKey( 1,'HEX',Act:BaseHex)  ; SELF.SetKey( 2,'DEC',Act:BaseDec)
    SELF.SetKey( 3,'OCT',Act:BaseOct)  ; SELF.SetKey( 4,'BIN',Act:BaseBin)
    SELF.SetKey( 5,SELF.Txt(CalcTxt:WordSize),Act:WordSize); SELF.SetKey( 6,'C',Act:ClearAll)
    SELF.SetKey( 7,'CE',Act:ClearEntry)
    SELF.SetKey( 8,'A',Act:Digit)      ; SELF.SetKey( 9,'B',Act:Digit)
    SELF.SetKey(10,'C',Act:Digit)      ; SELF.SetKey(11,'D',Act:Digit)
    SELF.SetKey(12,'E',Act:Digit)      ; SELF.SetKey(13,'F',Act:Digit)
    SELF.SetKey(14,SELF.Txt(CalcTxt:Bksp),Act:Back)
    SELF.SetKey(15,'AND',Act:And)      ; SELF.SetKey(16,'OR',Act:Or)
    SELF.SetKey(17,'XOR',Act:Xor)      ; SELF.SetKey(18,'NOT',Act:Not)
    SELF.SetKey(19,'Lsh',Act:Shl)       ; SELF.SetKey(20,'Rsh',Act:Shr)
    SELF.SetKey(21,'MOD',Act:Mod)
    SELF.SetKey(22,'7',Act:Digit)      ; SELF.SetKey(23,'8',Act:Digit)
    SELF.SetKey(24,'9',Act:Digit)      ; SELF.SetKey(25,'/',Act:Div)
    SELF.SetKey(26,'MC',Act:MemClear)  ; SELF.SetKey(27,'MR',Act:MemRecall)
    SELF.SetKey(28,'M+',Act:MemAdd)
    SELF.SetKey(29,'4',Act:Digit)      ; SELF.SetKey(30,'5',Act:Digit)
    SELF.SetKey(31,'6',Act:Digit)      ; SELF.SetKey(32,'*',Act:Mul)
    SELF.SetKey(33,'(',Act:OpenParen)  ; SELF.SetKey(34,')',Act:CloseParen)
    SELF.SetKey(35,'M-',Act:MemSub)
    SELF.SetKey(36,'1',Act:Digit)      ; SELF.SetKey(37,'2',Act:Digit)
    SELF.SetKey(38,'3',Act:Digit)      ; SELF.SetKey(39,'-',Act:Sub)
    SELF.SetKey(40,'+/-',Act:Sign)     ; SELF.SetKey(41,'%',Act:Percent)
    SELF.SetKey(43,'0',Act:Digit,2)    ; SELF.SetKey(45,'.',Act:Dot)
    SELF.SetKey(46,'+',Act:Add)        ; SELF.SetKey(47,'=',Act:Equals)

! -------------------------------------------------------------- accountant --
  OF Calc:Accountant
    SELF.SetKey( 1,'C',Act:ClearAll)   ; SELF.SetKey( 2,'CE',Act:ClearEntry)
    SELF.SetKey( 3,SELF.Txt(CalcTxt:Bksp),Act:Back)     ; SELF.SetKey( 4,'%',Act:Percent)
    SELF.SetKey( 5,SELF.Txt(CalcTxt:TaxPlus),Act:TaxPct)  ; SELF.SetKey( 6,SELF.Txt(CalcTxt:TaxMinus),Act:TaxLess)
    SELF.SetKey( 7,'MC',Act:MemClear)
    SELF.SetKey( 8,'7',Act:Digit)      ; SELF.SetKey( 9,'8',Act:Digit)
    SELF.SetKey(10,'9',Act:Digit)      ; SELF.SetKey(11,'/',Act:Div)
    SELF.SetKey(12,SELF.Txt(CalcTxt:Subtotal),Act:Subtotal) ; SELF.SetKey(13,'MR',Act:MemRecall)
    SELF.SetKey(14,'M+',Act:MemAdd)
    SELF.SetKey(15,'4',Act:Digit)      ; SELF.SetKey(16,'5',Act:Digit)
    SELF.SetKey(17,'6',Act:Digit)      ; SELF.SetKey(18,'*',Act:Mul)
    SELF.SetKey(19,SELF.Txt(CalcTxt:Total),Act:Total)  ; SELF.SetKey(20,'M-',Act:MemSub)
    SELF.SetKey(21,'MS',Act:MemStore)
    SELF.SetKey(22,'1',Act:Digit)      ; SELF.SetKey(23,'2',Act:Digit)
    SELF.SetKey(24,'3',Act:Digit)      ; SELF.SetKey(25,'-',Act:Sub)
    SELF.SetKey(26,SELF.Txt(CalcTxt:GrandTot),Act:GrandTotal)
    SELF.SetKey(29,'0',Act:Digit)      ; SELF.SetKey(30,'00',Act:Digit)
    SELF.SetKey(31,'.',Act:Dot)        ; SELF.SetKey(32,'+',Act:Add)
    SELF.SetKey(33,'=',Act:Equals)
  END


! ############################################################################
!  Remembering the last session
! ############################################################################
CalcClass.IniPath PROCEDURE()
nm  CSTRING(261)
n   ULONG,AUTO
i   LONG,AUTO
cut LONG(0)
  CODE
  IF CLIP(LEFT(SELF.IniFile)) THEN RETURN CLIP(LEFT(SELF.IniFile)) .
  nm = ''
  n  = cxModuleFile(0,nm,260)
  IF ~n THEN RETURN '' .
  LOOP i = LEN(nm) TO 1 BY -1
    IF nm[i] = '\' OR nm[i] = '/' THEN BREAK .
    IF nm[i] = '.' THEN cut = i; BREAK .
  END
  IF cut THEN nm = SUB(nm,1,cut-1) .
  RETURN CLIP(nm) & '.INI'


CalcClass.IniSection PROCEDURE()
p  CSTRING(65)
  CODE
  p = CLIP(LEFT(SELF.Profile))
  IF ~p THEN p = 'Default' .
  RETURN 'myCalc_' & p


!  The mode is the one the user notices, so it is the first thing restored.
!
!  Language is deliberately NOT saved or restored. There is no language
!  picker in the window - it is a developer setting that comes from the
!  template - so remembering it would let a value saved by an older build
!  silently override whatever the template now says.
CalcClass.LoadSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
m     BYTE,AUTO
  CODE
  SELF.Loaded = 1
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  m = GETINI(sect,'Mode',SELF.Mode,f)
  IF m >= 1 AND m <= Calc:Modes AND SELF.Allowed(m) THEN SELF.Mode = m .
  SELF.ShowTape = GETINI(sect,'ShowTape',SELF.ShowTape,f)
  SELF.Angle    = GETINI(sect,'Angle',SELF.Angle,f)
  SELF.Base     = GETINI(sect,'Base',SELF.Base,f)
  SELF.WordBits = GETINI(sect,'WordBits',SELF.WordBits,f)
  SELF.Decimals = GETINI(sect,'Decimals',SELF.Decimals,f)
  SELF.TaxRate  = GETINI(sect,'TaxRate',SELF.TaxRate,f)
  CASE SELF.Base                                          ! never restore rubbish
  OF 2 OROF 8 OROF 10 OROF 16
  ELSE
    SELF.Base = 10
  END
  CASE SELF.WordBits
  OF 8 OROF 16 OROF 32
  ELSE
    SELF.WordBits = 32
  END
  IF SELF.Decimals > 8 THEN SELF.Decimals = 2 .


CalcClass.SaveSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  PUTINI(sect,'Mode',SELF.Mode,f)
  PUTINI(sect,'ShowTape',SELF.ShowTape,f)
  PUTINI(sect,'Angle',SELF.Angle,f)
  PUTINI(sect,'Base',SELF.Base,f)
  PUTINI(sect,'WordBits',SELF.WordBits,f)
  PUTINI(sect,'Decimals',SELF.Decimals,f)
  PUTINI(sect,'TaxRate',SELF.TaxRate,f)


CalcClass.ForgetSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  PUTINI(sect,'Mode','',f)
  PUTINI(sect,'ShowTape','',f)
  PUTINI(sect,'Angle','',f)
  PUTINI(sect,'Base','',f)
  PUTINI(sect,'WordBits','',f)
  PUTINI(sect,'Decimals','',f)
  PUTINI(sect,'TaxRate','',f)
  PUTINI(sect,'Language','',f)                            ! tidy up older INIs
  SELF.Loaded = 0


! ############################################################################
!  Seed from a field, and put the answer back into it
! ############################################################################
CalcClass.AskFor PROCEDURE(*? pField)
  CODE
  SELF.SetValue(pField)
  IF ~SELF.Ask() THEN RETURN 0 .
  pField = SELF.Value
  RETURN 1


! ############################################################################
!  The pop-up
! ############################################################################
!  One window serves all four modes: the 7 x 7 keypad is re-labelled and
!  re-hidden per mode by ApplyKeys, and the paper roll slides in and out by
!  widening the window. ?B1..?B49 are declared consecutively, so FIELD() minus
!  ?B1 is the cell number - no 49-way CASE needed.
CalcClass.Ask PROCEDURE()
ModeQ        QUEUE,PRE(MQ)
MName          STRING(24)
MId            LONG
             END
i            LONG,AUTO
k            LONG,AUTO
cell         LONG,AUTO
feq          LONG,AUTO
d            LONG,AUTO
sel          LONG(1)
flag         CSTRING(24)
CShowTape    BYTE
CalcWnd WINDOW('Calculator'),AT(,,352,302),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI), |
          CENTER,GRAY,SYSTEM,MODAL, |
          ALRT(EscKey),ALRT(EnterKey),ALRT(BSKey),ALRT(DeleteKey), |
          ALRT(Key0),ALRT(Key1),ALRT(Key2),ALRT(Key3),ALRT(Key4), |
          ALRT(Key5),ALRT(Key6),ALRT(Key7),ALRT(Key8),ALRT(Key9), |
          ALRT(KeyPad0),ALRT(KeyPad1),ALRT(KeyPad2),ALRT(KeyPad3),ALRT(KeyPad4), |
          ALRT(KeyPad5),ALRT(KeyPad6),ALRT(KeyPad7),ALRT(KeyPad8),ALRT(KeyPad9), |
          ALRT(PlusKey),ALRT(MinusKey),ALRT(SlashKey),ALRT(006AH),ALRT(006EH), |
          ALRT(00BEH),ALRT(00BBH)
           PANEL,AT(0,0,512,30),USE(?CBand),FILL(0603A1FH)
           STRING(''),AT(12,5),USE(?CTitle),FONT('Segoe UI',12,COLOR:White,FONT:bold),TRN
           STRING(''),AT(12,18),USE(?CSub),FONT('Segoe UI',8,0D8C8B4H),TRN
           PROMPT('&Mode:'),AT(10,38),USE(?CModeP)
           LIST,AT(40,36,124,10),USE(?CMode),DROP(6),FROM(ModeQ),FORMAT('110L(2)@s24@')
           CHECK('Paper &roll'),AT(174,37),USE(CShowTape)
           PANEL,AT(10,52,332,42),USE(?CDisp),FILL(00FFFFFFH),BEVEL(-1)
           STRING(''),AT(14,56,290,9),USE(?CExpr),FONT('Segoe UI',8,00808080H),RIGHT,TRN
           STRING(''),AT(14,67,290,23),USE(?CVal),FONT('Segoe UI',17,0603A1FH,FONT:bold),RIGHT,TRN
           STRING(''),AT(308,57,30,9),USE(?CMem),FONT('Segoe UI',8,0603A1FH,FONT:bold),TRN
           STRING(''),AT(308,68,30,9),USE(?CFlag),FONT('Segoe UI',8,00808080H),TRN
           BUTTON(''),AT(10,100,44,20),USE(?B1),HIDE
           BUTTON(''),AT(58,100,44,20),USE(?B2),HIDE
           BUTTON(''),AT(106,100,44,20),USE(?B3),HIDE
           BUTTON(''),AT(154,100,44,20),USE(?B4),HIDE
           BUTTON(''),AT(202,100,44,20),USE(?B5),HIDE
           BUTTON(''),AT(250,100,44,20),USE(?B6),HIDE
           BUTTON(''),AT(298,100,44,20),USE(?B7),HIDE
           BUTTON(''),AT(10,124,44,20),USE(?B8),HIDE
           BUTTON(''),AT(58,124,44,20),USE(?B9),HIDE
           BUTTON(''),AT(106,124,44,20),USE(?B10),HIDE
           BUTTON(''),AT(154,124,44,20),USE(?B11),HIDE
           BUTTON(''),AT(202,124,44,20),USE(?B12),HIDE
           BUTTON(''),AT(250,124,44,20),USE(?B13),HIDE
           BUTTON(''),AT(298,124,44,20),USE(?B14),HIDE
           BUTTON(''),AT(10,148,44,20),USE(?B15),HIDE
           BUTTON(''),AT(58,148,44,20),USE(?B16),HIDE
           BUTTON(''),AT(106,148,44,20),USE(?B17),HIDE
           BUTTON(''),AT(154,148,44,20),USE(?B18),HIDE
           BUTTON(''),AT(202,148,44,20),USE(?B19),HIDE
           BUTTON(''),AT(250,148,44,20),USE(?B20),HIDE
           BUTTON(''),AT(298,148,44,20),USE(?B21),HIDE
           BUTTON(''),AT(10,172,44,20),USE(?B22),HIDE
           BUTTON(''),AT(58,172,44,20),USE(?B23),HIDE
           BUTTON(''),AT(106,172,44,20),USE(?B24),HIDE
           BUTTON(''),AT(154,172,44,20),USE(?B25),HIDE
           BUTTON(''),AT(202,172,44,20),USE(?B26),HIDE
           BUTTON(''),AT(250,172,44,20),USE(?B27),HIDE
           BUTTON(''),AT(298,172,44,20),USE(?B28),HIDE
           BUTTON(''),AT(10,196,44,20),USE(?B29),HIDE
           BUTTON(''),AT(58,196,44,20),USE(?B30),HIDE
           BUTTON(''),AT(106,196,44,20),USE(?B31),HIDE
           BUTTON(''),AT(154,196,44,20),USE(?B32),HIDE
           BUTTON(''),AT(202,196,44,20),USE(?B33),HIDE
           BUTTON(''),AT(250,196,44,20),USE(?B34),HIDE
           BUTTON(''),AT(298,196,44,20),USE(?B35),HIDE
           BUTTON(''),AT(10,220,44,20),USE(?B36),HIDE
           BUTTON(''),AT(58,220,44,20),USE(?B37),HIDE
           BUTTON(''),AT(106,220,44,20),USE(?B38),HIDE
           BUTTON(''),AT(154,220,44,20),USE(?B39),HIDE
           BUTTON(''),AT(202,220,44,20),USE(?B40),HIDE
           BUTTON(''),AT(250,220,44,20),USE(?B41),HIDE
           BUTTON(''),AT(298,220,44,20),USE(?B42),HIDE
           BUTTON(''),AT(10,244,44,20),USE(?B43),HIDE
           BUTTON(''),AT(58,244,44,20),USE(?B44),HIDE
           BUTTON(''),AT(106,244,44,20),USE(?B45),HIDE
           BUTTON(''),AT(154,244,44,20),USE(?B46),HIDE
           BUTTON(''),AT(202,244,44,20),USE(?B47),HIDE
           BUTTON(''),AT(250,244,44,20),USE(?B48),HIDE
           BUTTON(''),AT(298,244,44,20),USE(?B49),HIDE
           STRING('Roll'),AT(360,40),USE(?CRollP),FONT('Segoe UI',9,,FONT:bold),HIDE
           BUTTON('Copy'),AT(414,36,42,11),USE(?CCopy),HIDE,TIP('Copy the whole roll to the clipboard')
           BUTTON('Clear'),AT(458,36,42,11),USE(?CClear),HIDE
           LIST,AT(360,52,140,214),USE(?CTape),FROM(''),VSCROLL,FONT('Consolas',9), |
             FORMAT('134L(2)@s52@'),HIDE
           PANEL,AT(10,274,332,1),USE(?CRule),FILL(00D4D0CCH)
           STRING('Enter = equals   Esc = close'),AT(12,281),USE(?CHint), |
             FONT('Segoe UI',8,00808080H),TRN
           BUTTON('&Accept'),AT(228,280,54,15),USE(?COk),TIP('Put this value into the field')
           BUTTON('Cancel'),AT(286,280,54,15),USE(?CCancel)
         END
  CODE
  IF SELF.Language <> Calc:Spanish THEN SELF.Language = Calc:English .
  IF SELF.Persist AND ~SELF.Loaded THEN SELF.LoadSettings() .
  IF ~SELF.Allowed(SELF.Mode)                             ! the saved mode may be switched off now
    LOOP i = 1 TO Calc:Modes
      IF SELF.Allowed(i)
        SELF.Mode = i
        BREAK
      END
    END
  END
  LOOP i = 1 TO Calc:Modes
    IF ~SELF.Allowed(i) THEN CYCLE .
    MQ:MName = SELF.ModeName(i)
    MQ:MId   = i
    ADD(ModeQ)
  END
  IF ~RECORDS(ModeQ)
    MQ:MName = SELF.ModeName(Calc:Standard)
    MQ:MId   = Calc:Standard
    ADD(ModeQ)
    SELF.Mode = Calc:Standard
  END
  LOOP i = 1 TO RECORDS(ModeQ)
    GET(ModeQ,i)
    IF MQ:MId = SELF.Mode
      sel = i
      BREAK
    END
  END
  SELF.Accepted = 0
  SELF.Entry    = SELF.Fmt(SELF.Value)
  SELF.NewEnt   = 1
  CShowTape     = SELF.ShowTape
  OPEN(CalcWnd)
  ?CTitle{PROP:Text} = CHOOSE(CLIP(SELF.Title) <> '',CLIP(SELF.Title),SELF.Txt(CalcTxt:Calculator))
  0{PROP:Text}       = ?CTitle{PROP:Text}                 ! the caption follows too
  ?CModeP{PROP:Text}    = SELF.Txt(CalcTxt:Mode)             ! the whole window speaks Language
  ?CShowTape{PROP:Text} = SELF.Txt(CalcTxt:PaperRoll)
  ?CRollP{PROP:Text}    = SELF.Txt(CalcTxt:Roll)
  ?CCopy{PROP:Text}     = SELF.Txt(CalcTxt:Copy)
  ?CCopy{PROP:Tip}      = SELF.Txt(CalcTxt:CopyTip)
  ?CClear{PROP:Text}    = SELF.Txt(CalcTxt:Clear)
  ?COk{PROP:Text}       = SELF.Txt(CalcTxt:Accept)
  ?CCancel{PROP:Text}   = SELF.Txt(CalcTxt:Cancel)
  ?CHint{PROP:Text}     = SELF.Txt(CalcTxt:Hint)
  ?CMode{PROP:Selected} = sel
  ?CTape{PROP:From} = SELF.Tape
  DO ApplyKeys
  DO ShowRoll
  DO ShowIt
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      SELECT(?CMode)
    OF EVENT:AlertKey
      k = KEYCODE()
      IF k = EscKey
        POST(EVENT:CloseWindow)
      ELSIF k >= Key0 AND k <= Key9
        SELF.Press(Act:Digit,CHR(k))
        DO ShowIt
      ELSIF k >= KeyPad0 AND k <= KeyPad9
        SELF.Press(Act:Digit,CHR(k - KeyPad0 + 48))
        DO ShowIt
      ELSE
        CASE k
        OF PlusKey   ; SELF.Press(Act:Add,'+')
        OF MinusKey  ; SELF.Press(Act:Sub,'-')
        OF 006AH     ; SELF.Press(Act:Mul,'*')
        OF SlashKey  ; SELF.Press(Act:Div,'/')
        OF EnterKey  ; SELF.Press(Act:Equals,'=')
        OF 00BBH     ; SELF.Press(Act:Equals,'=')
        OF BSKey     ; SELF.Press(Act:Back,'')
        OF DeleteKey ; SELF.Press(Act:ClearEntry,'')
        OF 006EH     ; SELF.Press(Act:Dot,'.')
        OF 00BEH     ; SELF.Press(Act:Dot,'.')
        END
        DO ShowIt
      END
    END
    IF FIELD() >= ?B1 AND FIELD() <= ?B49                 ! one handler for the whole keypad
      IF EVENT() = EVENT:Accepted
        cell = FIELD() - ?B1 + 1
        IF SELF.BtnAct[cell] <> Act:None
          SELF.Press(SELF.BtnAct[cell],SELF.BtnTxt[cell])
          IF SELF.BtnAct[cell] = Act:DegRad OR SELF.BtnAct[cell] = Act:WordSize |
             OR SELF.BtnAct[cell] = Act:BaseHex OR SELF.BtnAct[cell] = Act:BaseDec |
             OR SELF.BtnAct[cell] = Act:BaseOct OR SELF.BtnAct[cell] = Act:BaseBin
            DO ApplyKeys                                  ! these change what the keys mean
          END
          DO ShowIt
        END
      END
      CYCLE
    END
    CASE FIELD()
    OF ?CMode
      IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
        i = CHOICE(?CMode)
        IF i
          GET(ModeQ,i)
          IF ~ERRORCODE() AND MQ:MId <> SELF.Mode
            SELF.Mode  = MQ:MId
            SELF.Entry = SELF.Fmt(SELF.Current())
            DO ApplyKeys
            DO ShowIt
          END
        END
      END
    OF ?CShowTape
      IF EVENT() = EVENT:Accepted
        SELF.ShowTape = CShowTape
        DO ShowRoll
      END
    OF ?CCopy
      IF EVENT() = EVENT:Accepted THEN SETCLIPBOARD(SELF.TapeText()) .
    OF ?CClear
      IF EVENT() = EVENT:Accepted
        SELF.ClearTape()
        DISPLAY(?CTape)
      END
    OF ?COk
      IF EVENT() = EVENT:Accepted
        IF SELF.ErrState
          Message(SELF.Txt(CalcTxt:FixError),SELF.Txt(CalcTxt:Calculator), |
                  ICON:Exclamation,BUTTON:OK,BUTTON:OK,0)
          CYCLE
        END
        SELF.Value    = SELF.Current()
        SELF.Accepted = 1
        POST(EVENT:CloseWindow)
      END
    OF ?CCancel
      IF EVENT() = EVENT:Accepted THEN POST(EVENT:CloseWindow) .
    END
  END
  CLOSE(CalcWnd)
  IF SELF.Persist THEN SELF.SaveSettings() .              ! remember the mode we left it on
  RETURN SELF.Accepted

!  ---- re-label the keypad for the current mode ----------------------------
ApplyKeys ROUTINE
  SELF.Layout()
  LOOP i = 1 TO Calc:Cells
    feq = ?B1 + i - 1
    IF SELF.BtnTxt[i]
      feq{PROP:Text}  = SELF.BtnTxt[i]
      feq{PROP:Width} = CHOOSE(SELF.BtnSpan[i] = 2,44 * 2 + 4,44)
      UNHIDE(feq)
      ENABLE(feq)
      IF SELF.Mode = Calc:Programmer                      ! grey out digits the base has no use for
        IF SELF.BtnAct[i] = Act:Digit
          d = VAL(SELF.BtnTxt[i])
          IF d >= 65 THEN d -= 55 ELSE d -= 48 .
          IF d >= SELF.Base THEN DISABLE(feq) .
        ELSIF SELF.BtnAct[i] = Act:Dot AND SELF.Base <> 10
          DISABLE(feq)
        END
      END
    ELSE
      HIDE(feq)
    END
  END
  ?CSub{PROP:Text} = SELF.ModeName(SELF.Mode)

!  ---- slide the paper roll in or out --------------------------------------
ShowRoll ROUTINE
  IF SELF.ShowTape
    0{PROP:Width} = 512
    UNHIDE(?CTape) ; UNHIDE(?CCopy) ; UNHIDE(?CClear) ; UNHIDE(?CRollP)
    ?CBand{PROP:Width} = 512
  ELSE
    HIDE(?CTape) ; HIDE(?CCopy) ; HIDE(?CClear) ; HIDE(?CRollP)
    0{PROP:Width} = 352
    ?CBand{PROP:Width} = 352
  END

!  ---- repaint the readout -------------------------------------------------
ShowIt ROUTINE
  ?CVal{PROP:Text}  = SELF.DisplayText()
  ?CExpr{PROP:Text} = SELF.Expr
  ?CMem{PROP:Text}  = CHOOSE(SELF.MemSet = 1,'M','')
  flag = ''
  CASE SELF.Mode
  OF Calc:Scientific
    flag = CHOOSE(SELF.Angle = 0,'DEG','RAD')
  OF Calc:Programmer
    CASE SELF.Base
    OF 16 ; flag = 'HEX'
    OF  8 ; flag = 'OCT'
    OF  2 ; flag = 'BIN'
    ELSE  ; flag = 'DEC'
    END
    flag = CLIP(flag) & ' ' & SELF.WordBits
  OF Calc:Accountant
    flag = 'T ' & CLIP(LEFT(SELF.Fmt(SELF.Running)))      ! one formatter, one look
  END
  ?CFlag{PROP:Text} = flag
  IF ~SELF.Tape &= NULL AND RECORDS(SELF.Tape)
    ?CTape{PROP:Selected} = RECORDS(SELF.Tape)            ! keep the newest line in view
  END
  DISPLAY(?CTape)
