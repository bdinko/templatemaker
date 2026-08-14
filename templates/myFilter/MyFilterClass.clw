! ============================================================================
!  MyFilterClass - see MyFilterClass.inc for what it does and why.
!
!  Pure ASCII on purpose: the Spanish strings spell their accents as Clarion
!  <nnn> escapes (225 a-acute, 233 e-acute, 237 i-acute, 241 n-tilde,
!  243 o-acute, 250 u-acute, 191 inverted-?) so that no editor can rewrite the
!  file as UTF-8 and turn them into question marks.
!
!  And note every literal '<' in an expression is written '<<'. Inside a
!  Clarion string <n> is an ASCII escape, so '<>' must be '<<>'.
! ============================================================================
  MEMBER()

  INCLUDE('MyFilterClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

  MAP
    MODULE('win32')
      FltGetModuleFileName(UNSIGNED hModule,*CSTRING lpFilename,UNSIGNED nSize), |
                           UNSIGNED,PASCAL,RAW,NAME('GetModuleFileNameA')
    END
    FltAskName(STRING pPrompt,STRING pTitle,*CSTRING pName),BYTE
    FltIniKey(STRING pName),STRING
  END

MaxCond   EQUATE(24)                                        ! more than anyone builds by hand


! ############################################################################
!  Lifecycle
! ############################################################################
MyFilterClass.Construct PROCEDURE
  CODE
  SELF.Fields &= NEW FilterFieldQueue
  SELF.Conds  &= NEW FilterCondQueue


MyFilterClass.Destruct PROCEDURE
  CODE
  IF ~SELF.Fields &= NULL
    FREE(SELF.Fields)
    DISPOSE(SELF.Fields)
  END
  IF ~SELF.Conds &= NULL
    FREE(SELF.Conds)
    DISPOSE(SELF.Conds)
  END


! ############################################################################
!  The browse's fields
! ############################################################################
MyFilterClass.AddField PROCEDURE(STRING pName,STRING pLabel,BYTE pType,<STRING pPicture>)
  CODE
  IF ~CLIP(pName) THEN RETURN .
  SELF.Fields.FFName  = CLIP(LEFT(pName))
  SELF.Fields.FFLabel = CHOOSE(CLIP(pLabel) <> '',CLIP(LEFT(pLabel)),CLIP(LEFT(pName)))
  SELF.Fields.FFType  = CHOOSE(pType >= Flt:String AND pType <= Flt:Flag,pType,Flt:String)
  IF ~OMITTED(4)
    SELF.Fields.FFPicture = CLIP(LEFT(pPicture))
  ELSE
    SELF.Fields.FFPicture = ''
  END
  ADD(SELF.Fields)


MyFilterClass.FieldCount PROCEDURE()
  CODE
  RETURN RECORDS(SELF.Fields)


MyFilterClass.ClearFields PROCEDURE
  CODE
  FREE(SELF.Fields)


! ############################################################################
!  The conditions
! ############################################################################
MyFilterClass.AddCond PROCEDURE(LONG pField,SHORT pOp,<STRING pV1>,<STRING pV2>,SHORT pJoin=0)
  CODE
  IF pField < 1 OR pField > RECORDS(SELF.Fields) THEN RETURN 0 .
  IF pOp    < 1 OR pOp    > Flt:LastOp          THEN RETURN 0 .
  IF RECORDS(SELF.Conds) >= MaxCond             THEN RETURN 0 .
  SELF.Conds.FCField = pField
  SELF.Conds.FCOp    = pOp
  SELF.Conds.FCVal1  = CHOOSE(~OMITTED(3),CLIP(LEFT(pV1)),'')
  SELF.Conds.FCVal2  = CHOOSE(~OMITTED(4),CLIP(LEFT(pV2)),'')
  SELF.Conds.FCJoin  = CHOOSE(pJoin = Flt:Or,Flt:Or,Flt:And)
  ADD(SELF.Conds)
  RETURN RECORDS(SELF.Conds)


MyFilterClass.RemoveCond PROCEDURE(LONG pLine)
  CODE
  GET(SELF.Conds,pLine)
  IF ~ERRORCODE() THEN DELETE(SELF.Conds) .


MyFilterClass.CondCount PROCEDURE()
  CODE
  RETURN RECORDS(SELF.Conds)


MyFilterClass.ClearConds PROCEDURE
  CODE
  FREE(SELF.Conds)
  SELF.Loaded = ''


MyFilterClass.Active PROCEDURE()
  CODE
  RETURN CHOOSE(RECORDS(SELF.Conds) > 0,1,0)


! ############################################################################
!  Building the expression
! ############################################################################
!  A value going into a literal has to have its quotes doubled, or a name like
!  O'Brien ends the string early and the whole filter fails to parse.
MyFilterClass.Quote PROCEDURE(STRING pText)
s   CSTRING(201)
o   CSTRING(401)
i   LONG,AUTO
  CODE
  s = CLIP(LEFT(pText))
  o = ''
  LOOP i = 1 TO LEN(s)
    IF s[i] = ''''
      o = o & ''''''
    ELSE
      o = o & s[i]
    END
  END
  RETURN o


!  Text compares are caseless unless the caller asked otherwise, which means
!  UPPER() round the field AND an upper-cased literal on the other side.
MyFilterClass.FieldRef PROCEDURE(LONG pField)
  CODE
  GET(SELF.Fields,pField)
  IF ERRORCODE() THEN RETURN '' .
  IF SELF.Fields.FFType = Flt:String AND ~SELF.CaseSensitive
    RETURN 'UPPER(' & CLIP(SELF.Fields.FFName) & ')'
  END
  RETURN CLIP(SELF.Fields.FFName)


!  Whatever the user typed, as the number the file actually holds. Dates go
!  through their picture; plain numbers deliberately do NOT - DEFORMAT with an
!  @n picture reads the decimal point as a thousands separator and turns
!  116.00 into 11600.
MyFilterClass.Num PROCEDURE(LONG pField,STRING pText)
t   CSTRING(81)
d   DECIMAL(18,6)
l   LONG
  CODE
  t = CLIP(LEFT(pText))
  IF ~t THEN RETURN '0' .
  GET(SELF.Fields,pField)
  IF ERRORCODE() THEN RETURN '0' .
!  Go through a numeric VARIABLE, never straight out of DEFORMAT. DEFORMAT of
!  something that is not a number at all ('Law' typed into a department number)
!  hands back an empty string, and '(TEA:Department = )' is not an expression -
!  the filter fails to parse and the browse shows nothing with no clue why.
  CASE SELF.Fields.FFType
  OF Flt:Date
    IF SELF.Fields.FFPicture AND SELF.Fields.FFPicture[1 : 2] = '@d'
      d = DEFORMAT(t,SELF.Fields.FFPicture)
    ELSE
      d = DEFORMAT(t,'@d17')
    END
  OF Flt:Time
    IF SELF.Fields.FFPicture AND SELF.Fields.FFPicture[1 : 2] = '@t'
      d = DEFORMAT(t,SELF.Fields.FFPicture)
    ELSE
      d = DEFORMAT(t)
    END
  ELSE
    d = DEFORMAT(t)                                         ! no picture, on purpose
  END
  IF d = INT(d)                                             ! whole numbers read cleanly
    l = d
    RETURN l
  END
  RETURN d


!  One condition as a filter expression. Every form here was checked against a
!  real file first - in particular "begins with" uses SUB(), because slicing a
!  field inside a filter silently matches everything.
MyFilterClass.OneCond PROCEDURE(LONG pLine)
f     CSTRING(81)                                           ! the field reference
raw   CSTRING(65)                                           ! the field, unwrapped
v1    CSTRING(401)
v2    CSTRING(401)
n     LONG,AUTO
  CODE
  GET(SELF.Conds,pLine)
  IF ERRORCODE() THEN RETURN '' .
  GET(SELF.Fields,SELF.Conds.FCField)
  IF ERRORCODE() THEN RETURN '' .
  f   = SELF.FieldRef(SELF.Conds.FCField)
  raw = CLIP(SELF.Fields.FFName)
  IF SELF.Fields.FFType = Flt:String AND ~SELF.CaseSensitive
    v1 = SELF.Quote(UPPER(SELF.Conds.FCVal1))
    v2 = SELF.Quote(UPPER(SELF.Conds.FCVal2))
  ELSE
    v1 = SELF.Quote(SELF.Conds.FCVal1)
    v2 = SELF.Quote(SELF.Conds.FCVal2)
  END
  n = LEN(CLIP(SELF.Conds.FCVal1))

  CASE SELF.Conds.FCOp
! ---- the ones that read the same for every type ---------------------------
  OF Flt:Equal
    IF SELF.Fields.FFType = Flt:String
      RETURN f & ' = ''' & v1 & ''''
    END
    RETURN raw & ' = ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal1)
  OF Flt:NotEqual
    IF SELF.Fields.FFType = Flt:String
      RETURN f & ' <<> ''' & v1 & ''''
    END
    RETURN raw & ' <<> ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal1)

! ---- strings --------------------------------------------------------------
  OF Flt:Begins
    IF ~n THEN RETURN '' .
    RETURN 'UPPER(SUB(' & raw & ',1,' & n & ')) = ''' & v1 & ''''
  OF Flt:Ends
    IF ~n THEN RETURN '' .
    RETURN 'UPPER(SUB(CLIP(' & raw & '),LEN(CLIP(' & raw & '))-' & (n - 1) & ',' & n & ')) = ''' & v1 & ''''
  OF Flt:Contains
    IF ~n THEN RETURN '' .
    RETURN 'INSTRING(''' & v1 & ''',UPPER(' & raw & '),1,1) > 0'
  OF Flt:NotContains
    IF ~n THEN RETURN '' .
    RETURN 'INSTRING(''' & v1 & ''',UPPER(' & raw & '),1,1) = 0'
  OF Flt:Empty
    RETURN 'CLIP(' & raw & ') = '''''
  OF Flt:NotEmpty
    RETURN 'CLIP(' & raw & ') <<> '''''
  OF Flt:Matches
    IF ~n THEN RETURN '' .
    RETURN 'MATCH(' & raw & ',''' & SELF.Quote(SELF.Conds.FCVal1) & ''',17)'   ! wild + nocase

! ---- numbers, dates and times ---------------------------------------------
  OF Flt:Less
    RETURN raw & ' << ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal1)
  OF Flt:LessEqual
    RETURN raw & ' <<= ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal1)
  OF Flt:Greater
    RETURN raw & ' > ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal1)
  OF Flt:GreaterEqual
    RETURN raw & ' >= ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal1)
  OF Flt:Between
    RETURN '(' & raw & ' >= ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal1) & |
           ' AND ' & raw & ' <<= ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal2) & ')'
  OF Flt:NotBetween
    RETURN '(' & raw & ' << ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal1) & |
           ' OR ' & raw & ' > ' & SELF.Num(SELF.Conds.FCField,SELF.Conds.FCVal2) & ')'

! ---- dates, the friendly ones ---------------------------------------------
  OF Flt:Today
    RETURN raw & ' = ' & TODAY()
  OF Flt:Yesterday
    RETURN raw & ' = ' & (TODAY() - 1)
  OF Flt:LastNDays
    RETURN '(' & raw & ' >= ' & (TODAY() - DEFORMAT(SELF.Conds.FCVal1)) & |
           ' AND ' & raw & ' <<= ' & TODAY() & ')'
  OF Flt:NextNDays
    RETURN '(' & raw & ' >= ' & TODAY() & |
           ' AND ' & raw & ' <<= ' & (TODAY() + DEFORMAT(SELF.Conds.FCVal1)) & ')'
  OF Flt:InMonth
    RETURN 'MONTH(' & raw & ') = ' & DEFORMAT(SELF.Conds.FCVal1)
  OF Flt:InYear
    RETURN 'YEAR(' & raw & ') = ' & DEFORMAT(SELF.Conds.FCVal1)

! ---- flags ----------------------------------------------------------------
  OF Flt:IsTrue
    RETURN raw & ' <<> 0'
  OF Flt:IsFalse
    RETURN raw & ' = 0'
  END
  RETURN ''


!  All the conditions, joined. Each one is parenthesised so an OR in the middle
!  cannot quietly swallow the conditions either side of it.
MyFilterClass.Expression PROCEDURE()
i    LONG,AUTO
one  CSTRING(401)
  CODE
  SELF.Expr = ''
  LOOP i = 1 TO RECORDS(SELF.Conds)
    one = SELF.OneCond(i)
    IF ~one THEN CYCLE .                                    ! an incomplete line filters nothing
    GET(SELF.Conds,i)
    IF SELF.Expr
      SELF.Expr = SELF.Expr & CHOOSE(SELF.Conds.FCJoin = Flt:Or,' OR ',' AND ')
    END
    IF LEN(SELF.Expr) + LEN(one) + 2 > SIZE(SELF.Expr) - 1
      BREAK                                                 ! never build a truncated filter
    END
    SELF.Expr = SELF.Expr & '(' & one & ')'
  END
  RETURN SELF.Expr


! ############################################################################
!  How it reads to a human
! ############################################################################
MyFilterClass.CondText PROCEDURE(LONG pLine)
s CSTRING(201)
  CODE
  GET(SELF.Conds,pLine)
  IF ERRORCODE() THEN RETURN '' .
  GET(SELF.Fields,SELF.Conds.FCField)
  IF ERRORCODE() THEN RETURN '' .
  s = CLIP(SELF.Fields.FFLabel) & ' ' & CLIP(SELF.OpName(SELF.Conds.FCOp))
  IF SELF.OpTakesValue(SELF.Conds.FCOp)
    s = s & ' ' & CLIP(SELF.Conds.FCVal1)
    IF SELF.OpTakesTwo(SELF.Conds.FCOp)
      s = s & ' ' & CLIP(SELF.Txt(FTx:And2)) & ' ' & CLIP(SELF.Conds.FCVal2)
    END
    IF SELF.Conds.FCOp = Flt:LastNDays OR SELF.Conds.FCOp = Flt:NextNDays
      s = s & ' ' & CLIP(SELF.Txt(FTx:Days))
    END
  END
  RETURN s


MyFilterClass.Summary PROCEDURE()
i LONG,AUTO
s CSTRING(401)
  CODE
  s = ''
  LOOP i = 1 TO RECORDS(SELF.Conds)
    GET(SELF.Conds,i)
    IF s
      s = s & ' ' & CHOOSE(SELF.Conds.FCJoin = Flt:Or,CLIP(SELF.Txt(FTx:Or)), |
                                                      CLIP(SELF.Txt(FTx:And))) & ' '
    END
    IF LEN(s) > 300
      s = s & '...'
      BREAK
    END
    s = s & CLIP(SELF.CondText(i))
  END
  IF ~s THEN RETURN SELF.Txt(FTx:Nothing) .
  RETURN s


! ############################################################################
!  Which operators suit which field
! ############################################################################
MyFilterClass.OpTakesValue PROCEDURE(SHORT pOp)
  CODE
  CASE pOp
  OF Flt:Empty OROF Flt:NotEmpty OROF Flt:Today OROF Flt:Yesterday
  OROF Flt:IsTrue OROF Flt:IsFalse
    RETURN 0
  END
  RETURN 1


MyFilterClass.OpTakesTwo PROCEDURE(SHORT pOp)
  CODE
  RETURN CHOOSE(pOp = Flt:Between OR pOp = Flt:NotBetween,1,0)


!  Fills a queue with the operator names that make sense for this type, in the
!  order they are offered. The position in the queue is NOT the operator - the
!  window keeps its own map, because a drop list only gives back a position.
MyFilterClass.OpsFor PROCEDURE(BYTE pType,*FilterNameQueue pQ)
  CODE
  FREE(pQ)
  CASE pType
  OF Flt:String
    DO Add1 ; DO Add2 ; DO Add3 ; DO Add4 ; DO Add5 ; DO Add6
    DO Add7 ; DO Add8 ; DO Add9
  OF Flt:Flag
    pQ.FNName = SELF.OpName(Flt:IsTrue)  ; pQ.FNId = Flt:IsTrue ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:IsFalse) ; pQ.FNId = Flt:IsFalse ; ADD(pQ)
  OF Flt:Date
    DO Add1 ; DO Add2
    pQ.FNName = SELF.OpName(Flt:Less)         ; pQ.FNId = Flt:Less ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:LessEqual)    ; pQ.FNId = Flt:LessEqual ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:Greater)      ; pQ.FNId = Flt:Greater ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:GreaterEqual) ; pQ.FNId = Flt:GreaterEqual ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:Between)      ; pQ.FNId = Flt:Between ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:NotBetween)   ; pQ.FNId = Flt:NotBetween ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:Today)        ; pQ.FNId = Flt:Today ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:Yesterday)    ; pQ.FNId = Flt:Yesterday ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:LastNDays)    ; pQ.FNId = Flt:LastNDays ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:NextNDays)    ; pQ.FNId = Flt:NextNDays ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:InMonth)      ; pQ.FNId = Flt:InMonth ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:InYear)       ; pQ.FNId = Flt:InYear ; ADD(pQ)
  ELSE                                                      ! numbers and times
    DO Add1 ; DO Add2
    pQ.FNName = SELF.OpName(Flt:Less)         ; pQ.FNId = Flt:Less ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:LessEqual)    ; pQ.FNId = Flt:LessEqual ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:Greater)      ; pQ.FNId = Flt:Greater ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:GreaterEqual) ; pQ.FNId = Flt:GreaterEqual ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:Between)      ; pQ.FNId = Flt:Between ; ADD(pQ)
    pQ.FNName = SELF.OpName(Flt:NotBetween)   ; pQ.FNId = Flt:NotBetween ; ADD(pQ)
  END
  RETURN

Add1 ROUTINE
  pQ.FNName = SELF.OpName(Flt:Equal)       ; pQ.FNId = Flt:Equal ; ADD(pQ)
Add2 ROUTINE
  pQ.FNName = SELF.OpName(Flt:NotEqual)    ; pQ.FNId = Flt:NotEqual ; ADD(pQ)
Add3 ROUTINE
  pQ.FNName = SELF.OpName(Flt:Begins)      ; pQ.FNId = Flt:Begins ; ADD(pQ)
Add4 ROUTINE
  pQ.FNName = SELF.OpName(Flt:Ends)        ; pQ.FNId = Flt:Ends ; ADD(pQ)
Add5 ROUTINE
  pQ.FNName = SELF.OpName(Flt:Contains)    ; pQ.FNId = Flt:Contains ; ADD(pQ)
Add6 ROUTINE
  pQ.FNName = SELF.OpName(Flt:NotContains) ; pQ.FNId = Flt:NotContains ; ADD(pQ)
Add7 ROUTINE
  pQ.FNName = SELF.OpName(Flt:Empty)       ; pQ.FNId = Flt:Empty ; ADD(pQ)
Add8 ROUTINE
  pQ.FNName = SELF.OpName(Flt:NotEmpty)    ; pQ.FNId = Flt:NotEmpty ; ADD(pQ)
Add9 ROUTINE
  pQ.FNName = SELF.OpName(Flt:Matches)     ; pQ.FNId = Flt:Matches ; ADD(pQ)


MyFilterClass.OpName PROCEDURE(SHORT pOp)
  CODE
  IF SELF.Language = Flt:Spanish
    CASE pOp
    OF Flt:Equal        ; RETURN 'es igual a'
    OF Flt:NotEqual     ; RETURN 'no es igual a'
    OF Flt:Begins       ; RETURN 'empieza por'
    OF Flt:Ends         ; RETURN 'termina en'
    OF Flt:Contains     ; RETURN 'contiene'
    OF Flt:NotContains  ; RETURN 'no contiene'
    OF Flt:Empty        ; RETURN 'est<225> vac<237>o'
    OF Flt:NotEmpty     ; RETURN 'no est<225> vac<237>o'
    OF Flt:Matches      ; RETURN 'coincide con'
    OF Flt:Less         ; RETURN 'es menor que'
    OF Flt:LessEqual    ; RETURN 'es menor o igual a'
    OF Flt:Greater      ; RETURN 'es mayor que'
    OF Flt:GreaterEqual ; RETURN 'es mayor o igual a'
    OF Flt:Between      ; RETURN 'est<225> entre'
    OF Flt:NotBetween   ; RETURN 'no est<225> entre'
    OF Flt:Today        ; RETURN 'es hoy'
    OF Flt:Yesterday    ; RETURN 'fue ayer'
    OF Flt:LastNDays    ; RETURN 'en los <250>ltimos'
    OF Flt:NextNDays    ; RETURN 'en los pr<243>ximos'
    OF Flt:InMonth      ; RETURN 'en el mes'
    OF Flt:InYear       ; RETURN 'en el a<241>o'
    OF Flt:IsTrue       ; RETURN 'es s<237>'
    OF Flt:IsFalse      ; RETURN 'es no'
    END
    RETURN ''
  END
  CASE pOp
  OF Flt:Equal        ; RETURN 'equals'
  OF Flt:NotEqual     ; RETURN 'does not equal'
  OF Flt:Begins       ; RETURN 'begins with'
  OF Flt:Ends         ; RETURN 'ends with'
  OF Flt:Contains     ; RETURN 'contains'
  OF Flt:NotContains  ; RETURN 'does not contain'
  OF Flt:Empty        ; RETURN 'is empty'
  OF Flt:NotEmpty     ; RETURN 'is not empty'
  OF Flt:Matches      ; RETURN 'matches'
  OF Flt:Less         ; RETURN 'is less than'
  OF Flt:LessEqual    ; RETURN 'is at most'
  OF Flt:Greater      ; RETURN 'is more than'
  OF Flt:GreaterEqual ; RETURN 'is at least'
  OF Flt:Between      ; RETURN 'is between'
  OF Flt:NotBetween   ; RETURN 'is not between'
  OF Flt:Today        ; RETURN 'is today'
  OF Flt:Yesterday    ; RETURN 'was yesterday'
  OF Flt:LastNDays    ; RETURN 'in the last'
  OF Flt:NextNDays    ; RETURN 'in the next'
  OF Flt:InMonth      ; RETURN 'in month'
  OF Flt:InYear       ; RETURN 'in year'
  OF Flt:IsTrue       ; RETURN 'is yes'
  OF Flt:IsFalse      ; RETURN 'is no'
  END
  RETURN ''


! ############################################################################
!  Words
! ############################################################################
MyFilterClass.Txt PROCEDURE(LONG pId)
  CODE
  IF SELF.Language = Flt:Spanish
    CASE pId
    OF FTx:Title      ; RETURN 'Filtros'
    OF FTx:Hint       ; RETURN 'Elige un campo, di c<243>mo buscarlo y pulsa A<241>adir.'
    OF FTx:Field      ; RETURN '&Campo:'
    OF FTx:Test       ; RETURN '&Prueba:'
    OF FTx:Value      ; RETURN '&Valor:'
    OF FTx:AndOr      ; RETURN '&Unir con:'
    OF FTx:And        ; RETURN 'Y'
    OF FTx:Or         ; RETURN 'O'
    OF FTx:Add        ; RETURN '&A<241>adir'
    OF FTx:Edit       ; RETURN 'Ac&tualizar'
    OF FTx:Remove     ; RETURN '&Quitar'
    OF FTx:ClearAll   ; RETURN '&Limpiar todo'
    OF FTx:Apply      ; RETURN 'A&plicar'
    OF FTx:Cancel     ; RETURN 'Cancelar'
    OF FTx:Save       ; RETURN '&Guardar'
    OF FTx:Saved      ; RETURN 'Filtros &guardados:'
    OF FTx:Delete     ; RETURN '&Borrar'
    OF FTx:NameIt     ; RETURN 'Nombre para este filtro:'
    OF FTx:Expression ; RETURN 'Expresi<243>n:'
    OF FTx:Matching   ; RETURN 'condiciones'
    OF FTx:NoFields   ; RETURN 'Este browse no expone ning<250>n campo para filtrar.'
    OF FTx:PickField  ; RETURN 'Elige primero un campo.'
    OF FTx:NeedValue  ; RETURN 'Esa prueba necesita un valor.'
    OF FTx:NeedTwo    ; RETURN 'Un rango necesita los dos extremos.'
    OF FTx:BadRange   ; RETURN 'El final del rango es anterior al principio.'
    OF FTx:Overwrite  ; RETURN 'Ya existe un filtro con ese nombre. <191>Lo reemplazo?'
    OF FTx:ConfirmDel ; RETURN '<191>Borrar el filtro guardado?'
    OF FTx:And2       ; RETURN 'y'
    OF FTx:Days       ; RETURN 'd<237>as'
    OF FTx:Nothing    ; RETURN 'Sin filtro: se ve todo.'
    OF FTx:Condition  ; RETURN 'Condici<243>n'
    OF FTx:NeedNumber ; RETURN 'Ese campo guarda un n<250>mero, no texto.'
    END
    RETURN ''
  END
  CASE pId
  OF FTx:Title      ; RETURN 'Filters'
  OF FTx:Hint       ; RETURN 'Pick a field, say how to test it, then press Add.'
  OF FTx:Field      ; RETURN '&Field:'
  OF FTx:Test       ; RETURN '&Test:'
  OF FTx:Value      ; RETURN '&Value:'
  OF FTx:AndOr      ; RETURN '&Join with:'
  OF FTx:And        ; RETURN 'AND'
  OF FTx:Or         ; RETURN 'OR'
  OF FTx:Add        ; RETURN '&Add'
  OF FTx:Edit       ; RETURN 'Up&date'
  OF FTx:Remove     ; RETURN '&Remove'
  OF FTx:ClearAll   ; RETURN 'C&lear all'
  OF FTx:Apply      ; RETURN 'A&pply'
  OF FTx:Cancel     ; RETURN 'Cancel'
  OF FTx:Save       ; RETURN '&Save'
  OF FTx:Saved      ; RETURN '&Saved filters:'
  OF FTx:Delete     ; RETURN '&Delete'
  OF FTx:NameIt     ; RETURN 'Name for this filter:'
  OF FTx:Expression ; RETURN 'Expression:'
  OF FTx:Matching   ; RETURN 'conditions'
  OF FTx:NoFields   ; RETURN 'This browse offers no fields to filter on.'
  OF FTx:PickField  ; RETURN 'Choose a field first.'
  OF FTx:NeedValue  ; RETURN 'That test needs a value.'
  OF FTx:NeedTwo    ; RETURN 'A range needs both ends.'
  OF FTx:BadRange   ; RETURN 'The end of the range is before the start.'
  OF FTx:Overwrite  ; RETURN 'A filter of that name already exists. Replace it?'
  OF FTx:ConfirmDel ; RETURN 'Delete the saved filter?'
  OF FTx:And2       ; RETURN 'and'
  OF FTx:Days       ; RETURN 'days'
  OF FTx:Nothing    ; RETURN 'No filter - showing everything.'
  OF FTx:Condition  ; RETURN 'Condition'
  OF FTx:NeedNumber ; RETURN 'That field holds a number, not text.'
  END
  RETURN ''


! ############################################################################
!  Saved filters
! ############################################################################
MyFilterClass.IniPath PROCEDURE()
p CSTRING(261)
i LONG,AUTO
  CODE
  IF SELF.IniFile THEN RETURN SELF.IniFile .
  p = ''
  FltGetModuleFileName(0,p,SIZE(p) - 1)
  i = LEN(CLIP(p))
  LOOP WHILE i > 0
    IF p[i] = '.' THEN BREAK .
    IF p[i] = '\' THEN i = 0 ; BREAK .
    i -= 1
  END
  IF i > 0 THEN RETURN p[1 : i] & 'INI' .
  RETURN CLIP(p) & '.INI'


MyFilterClass.IniSection PROCEDURE()
  CODE
  RETURN 'myFilter_' & CHOOSE(CLIP(SELF.Profile) <> '',CLIP(SELF.Profile),'Default')


!  A filter's name in an INI KEY, made safe. The profile API splits every line
!  at its FIRST '=', so a name like "Shipper code = 10" makes a key that can be
!  written but never read back - Load answers empty, and the blanking writes in
!  Save and Delete APPEND fresh junk lines instead of replacing, because the
!  API cannot find those keys either. '[' ']' and ';' are section and comment
!  characters with quieter versions of the same disease. All become '~' - in
!  the KEY only. The Filters= list, the menu and Loaded keep the real name:
!  '=' on the VALUE side of a profile line is legal.
FltIniKey PROCEDURE(STRING pName)
k CSTRING(65)
i LONG,AUTO
  CODE
  k = CLIP(LEFT(pName))
  LOOP i = 1 TO LEN(k)
    CASE k[i]
    OF '=' OROF '[' OROF ']' OROF ';'
      k[i] = '~'
    END
  END
  RETURN k


MyFilterClass.SavedNames PROCEDURE(*FilterNameQueue pQ)
list  CSTRING(1025)
one   CSTRING(65)
i     LONG,AUTO
c     LONG,AUTO
  CODE
  FREE(pQ)
  IF SELF.Storage = Flt:Table
    SELF.TableNames(pQ)
    RETURN
  END
  list = GETINI(SELF.IniSection(),'Filters','',SELF.IniPath())
  one  = ''
  c    = LEN(CLIP(list))
  LOOP i = 1 TO c + 1
    IF i > c OR list[i] = '|'
      IF one
        pQ.FNName = one
        pQ.FNId   = 0
        ADD(pQ)
        one = ''
      END
    ELSE
      IF LEN(one) < SIZE(one) - 1 THEN one = one & list[i] .
    END
  END


MyFilterClass.Save PROCEDURE(STRING pName)
  CODE
  IF ~CLIP(pName) THEN RETURN 0 .
  IF SELF.Storage = Flt:Table THEN RETURN SELF.SaveTable(pName) .
  RETURN SELF.SaveIni(pName)


MyFilterClass.Load PROCEDURE(STRING pName)
  CODE
  IF ~CLIP(pName) THEN RETURN 0 .
  IF SELF.Storage = Flt:Table THEN RETURN SELF.LoadTable(pName) .
  RETURN SELF.LoadIni(pName)


MyFilterClass.DeleteSaved PROCEDURE(STRING pName)
q     FilterNameQueue
list  CSTRING(1025)
i     LONG,AUTO
  CODE
  IF ~CLIP(pName) THEN RETURN 0 .
  IF SELF.Storage = Flt:Table THEN RETURN SELF.DeleteTable(pName) .
  SELF.SavedNames(q)
  q.FNName = CLIP(LEFT(pName))
  GET(q,q.FNName)
  IF ERRORCODE()
    FREE(q)
    RETURN 0
  END
  DELETE(q)
  list = ''
  LOOP i = 1 TO RECORDS(q)
    GET(q,i)
    list = CHOOSE(list = '',CLIP(q.FNName),CLIP(list) & '|' & CLIP(q.FNName))
  END
  PUTINI(SELF.IniSection(),'Filters',list,SELF.IniPath())
  PUTINI(SELF.IniSection(),FltIniKey(pName) & '.n','',SELF.IniPath())
  LOOP i = 1 TO MaxCond
    PUTINI(SELF.IniSection(),FltIniKey(pName) & '.' & i,'',SELF.IniPath())
  END
  IF UPPER(CLIP(SELF.Loaded)) = UPPER(CLIP(pName)) THEN SELF.Loaded = '' .
  FREE(q)
  RETURN 1


!  One line per condition, pipe separated: field|op|value1|value2|join
MyFilterClass.SaveIni PROCEDURE(STRING pName)
q     FilterNameQueue
nm    CSTRING(65)
ky    CSTRING(65)
list  CSTRING(1025)
i     LONG,AUTO
found BYTE(0)
  CODE
  nm = CLIP(LEFT(pName))
  ky = FltIniKey(nm)
  SELF.SavedNames(q)
  LOOP i = 1 TO RECORDS(q)
    GET(q,i)
    IF UPPER(CLIP(q.FNName)) = UPPER(nm)
      found = 1
      BREAK
    END
  END
  IF ~found
    q.FNName = nm
    ADD(q)
  END
  list = ''
  LOOP i = 1 TO RECORDS(q)
    GET(q,i)
    list = CHOOSE(list = '',CLIP(q.FNName),CLIP(list) & '|' & CLIP(q.FNName))
  END
  PUTINI(SELF.IniSection(),'Filters',list,SELF.IniPath())
  PUTINI(SELF.IniSection(),ky & '.n',RECORDS(SELF.Conds),SELF.IniPath())
  LOOP i = 1 TO RECORDS(SELF.Conds)
    GET(SELF.Conds,i)
    GET(SELF.Fields,SELF.Conds.FCField)
    PUTINI(SELF.IniSection(),ky & '.' & i, |
           CLIP(SELF.Fields.FFName) & '|' & SELF.Conds.FCOp & '|' & |
           CLIP(SELF.Conds.FCVal1)  & '|' & CLIP(SELF.Conds.FCVal2) & '|' & |
           SELF.Conds.FCJoin, SELF.IniPath())
  END
  LOOP i = RECORDS(SELF.Conds) + 1 TO MaxCond                ! clear anything longer
    PUTINI(SELF.IniSection(),ky & '.' & i,'',SELF.IniPath())
  END
  SELF.Loaded = nm
  FREE(q)
  RETURN 1


!  Reading back matches on the FIELD NAME, not its position: the browse may
!  have gained or lost a column since the filter was saved, and a stale index
!  would silently filter on the wrong field.
MyFilterClass.LoadIni PROCEDURE(STRING pName)
nm    CSTRING(65)
ky    CSTRING(65)
line  CSTRING(301)
part  CSTRING(81)
fname CSTRING(65)
op    LONG
v1    CSTRING(81)
v2    CSTRING(81)
jn    LONG
n     LONG,AUTO
i     LONG,AUTO
c     LONG,AUTO
p     LONG,AUTO
fi    LONG,AUTO
got   LONG(0)
  CODE
  nm = CLIP(LEFT(pName))
  ky = FltIniKey(nm)
  n  = DEFORMAT(GETINI(SELF.IniSection(),ky & '.n','0',SELF.IniPath()))
  IF n < 1 THEN RETURN 0 .
  FREE(SELF.Conds)
  LOOP i = 1 TO n
    line = GETINI(SELF.IniSection(),ky & '.' & i,'',SELF.IniPath())
    IF ~line THEN CYCLE .
    fname = '' ; op = 0 ; v1 = '' ; v2 = '' ; jn = 0
    part  = ''
    p     = 1
    c     = LEN(CLIP(line))
    LOOP fi = 1 TO c + 1
      IF fi > c OR line[fi] = '|'
        CASE p
        OF 1 ; fname = part
        OF 2 ; op    = DEFORMAT(part)
        OF 3 ; v1    = part
        OF 4 ; v2    = part
        OF 5 ; jn    = DEFORMAT(part)
        END
        part = ''
        p   += 1
      ELSE
        IF LEN(part) < SIZE(part) - 1 THEN part = part & line[fi] .
      END
    END
    IF ~fname THEN CYCLE .
    LOOP fi = 1 TO RECORDS(SELF.Fields)                     ! match by name, never by index
      GET(SELF.Fields,fi)
      IF UPPER(CLIP(SELF.Fields.FFName)) = UPPER(CLIP(fname))
        IF SELF.AddCond(fi,op,v1,v2,jn) THEN got += 1 .
        BREAK
      END
    END
  END
  SELF.Loaded = nm
  RETURN CHOOSE(got > 0,1,0)


! ############################################################################
!  Table storage - the hooks. Derive and override these, or let the myFilter
!  template generate the overrides against FilterHdr / FilterLine.
!  See FilterTables.txt for the structures.
! ############################################################################
MyFilterClass.SaveTable PROCEDURE(STRING pName)
  CODE
  RETURN 0


MyFilterClass.LoadTable PROCEDURE(STRING pName)
  CODE
  RETURN 0


MyFilterClass.DeleteTable PROCEDURE(STRING pName)
  CODE
  RETURN 0


MyFilterClass.TableNames PROCEDURE(*FilterNameQueue pQ)
  CODE
  FREE(pQ)


MyFilterClass.LoadedName PROCEDURE()
  CODE
  RETURN SELF.Loaded


! ############################################################################
!  The pop-up
! ############################################################################
!  Top half builds one condition, bottom half is the list of the ones already
!  built. The operator list is rebuilt whenever the field changes, because the
!  tests worth offering depend on the type - you do not want "begins with" on
!  a balance, or "in the last N days" on a name.
MyFilterClass.Ask PROCEDURE()
FieldQ       QUEUE,PRE(FQ)
FQLabel        STRING(64)
             END
OpQ          FilterNameQueue
JoinQ        QUEUE,PRE(JQ)
JQName         STRING(8)
             END
SavedQ       FilterNameQueue
ShowQ        QUEUE,PRE(SHQ)
SHNo           STRING(3)
SHJoin         STRING(8)
SHText         STRING(120)
             END
fi           LONG
op           LONG
v1           CSTRING(81)
v2           CSTRING(81)
jn           LONG
i            LONG,AUTO
sel          LONG,AUTO
nm           CSTRING(65)
expr         CSTRING(256)                                   ! what ?FExpr displays
jn2          LONG                                           ! PullDown's join, before LoadOps
bad          BYTE(0)                                        ! Validate's answer
FWnd WINDOW('Filters'),AT(,,404,318),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI), |
         CENTER,GRAY,SYSTEM,MODAL,ALRT(EscKey)
       PANEL,AT(0,0,404,32),USE(?FBand),FILL(0603A1FH)
       STRING(''),AT(12,5),USE(?FTitle),FONT('Segoe UI',12,COLOR:White,FONT:bold),TRN
       STRING(''),AT(12,18),USE(?FSub),FONT('Segoe UI',8,0D8C8B4H),TRN
       PROMPT(''),AT(12,42),USE(?FFieldP)
       LIST,AT(56,41,120,10),USE(?FFld),DROP(12),FROM(FieldQ),FORMAT('116L(2)@s64@')
       PROMPT(''),AT(184,42),USE(?FOpP)
       LIST,AT(214,41,110,10),USE(?FOp),DROP(14),FROM(OpQ),FORMAT('106L(2)@s64@')
       PROMPT(''),AT(12,58),USE(?FValP)
       ENTRY(@s60),AT(56,57,120,10),USE(v1)
       STRING(''),AT(182,58),USE(?FAnd2),TRN
       ENTRY(@s60),AT(200,57,80,10),USE(v2)
       PROMPT(''),AT(290,58),USE(?FJoinP)
       LIST,AT(330,57,54,10),USE(?FJn),DROP(3),FROM(JoinQ),FORMAT('50L(2)@s8@')
       BUTTON(''),AT(12,76,54,14),USE(?FAdd),DEFAULT
       BUTTON(''),AT(70,76,54,14),USE(?FUpd)
       BUTTON(''),AT(128,76,54,14),USE(?FDel)
       BUTTON(''),AT(330,76,54,14),USE(?FClear)
       LIST,AT(12,96,372,96),USE(?FList),FROM(ShowQ),VSCROLL, |
         FORMAT('22L(2)|M~#~@s3@24L(2)|M~~@s8@300L(2)|M~Condition~@s120@')
       PROMPT(''),AT(12,198),USE(?FExprP)
       ENTRY(@s255),AT(56,197,328,10),USE(expr),READONLY,SKIP,FONT('Consolas',8)
       PANEL,AT(12,214,372,1),USE(?FRule),FILL(00D4D0CCH)
       PROMPT(''),AT(12,224),USE(?FSavedP)
       LIST,AT(76,223,140,10),USE(?FSav),DROP(10),FROM(SavedQ),FORMAT('136L(2)@s64@')
       BUTTON(''),AT(222,222,50,14),USE(?FSave)
       BUTTON(''),AT(276,222,50,14),USE(?FDelSave)
       STRING(''),AT(12,246,372,10),USE(?FCount),FONT('Segoe UI',8,0603A1FH,FONT:bold),TRN
       STRING(''),AT(12,258,372,20),USE(?FSummary),FONT('Segoe UI',8,00808080H),TRN
       BUTTON(''),AT(270,290,54,15),USE(?FOk)
       BUTTON(''),AT(330,290,54,15),USE(?FCancel)
     END
  CODE
  IF SELF.Language <> Flt:Spanish THEN SELF.Language = Flt:English .
  SELF.Accepted = 0
  IF ~RECORDS(SELF.Fields)
    MESSAGE(SELF.Txt(FTx:NoFields),SELF.Txt(FTx:Title),ICON:Exclamation)
    RETURN 0
  END
  LOOP i = 1 TO RECORDS(SELF.Fields)
    GET(SELF.Fields,i)
    FQ:FQLabel = SELF.Fields.FFLabel
    ADD(FieldQ)
  END
  JQ:JQName = SELF.Txt(FTx:And) ; ADD(JoinQ)
  JQ:JQName = SELF.Txt(FTx:Or)  ; ADD(JoinQ)
  OPEN(FWnd)
  ?FTitle{PROP:Text}   = CHOOSE(CLIP(SELF.Title) <> '',CLIP(SELF.Title),SELF.Txt(FTx:Title))
  0{PROP:Text}         = ?FTitle{PROP:Text}
  ?FSub{PROP:Text}     = SELF.Txt(FTx:Hint)
  ?FFieldP{PROP:Text}  = SELF.Txt(FTx:Field)
  ?FOpP{PROP:Text}     = SELF.Txt(FTx:Test)
  ?FValP{PROP:Text}    = SELF.Txt(FTx:Value)
  ?FAnd2{PROP:Text}    = SELF.Txt(FTx:And2)
  ?FJoinP{PROP:Text}   = SELF.Txt(FTx:AndOr)
  ?FAdd{PROP:Text}     = SELF.Txt(FTx:Add)
  ?FUpd{PROP:Text}     = SELF.Txt(FTx:Edit)
  ?FDel{PROP:Text}     = SELF.Txt(FTx:Remove)
  ?FClear{PROP:Text}   = SELF.Txt(FTx:ClearAll)
  ?FExprP{PROP:Text}   = SELF.Txt(FTx:Expression)
  ?FSavedP{PROP:Text}  = SELF.Txt(FTx:Saved)
  ?FSave{PROP:Text}    = SELF.Txt(FTx:Save)
  ?FDelSave{PROP:Text} = SELF.Txt(FTx:Delete)
  ?FOk{PROP:Text}      = SELF.Txt(FTx:Apply)
  ?FCancel{PROP:Text}  = SELF.Txt(FTx:Cancel)
  ?FList{PROP:Format}  = '22L(2)|M~#~@s3@24L(2)|M~~@s8@300L(2)|M~' & |
                         CLIP(SELF.Txt(FTx:Condition)) & '~@s120@'
!  Set the selection AFTER the window is open. OPEN() re-reads a LIST's USE
!  variable from the control, and the control has no selection yet, so
!  anything assigned beforehand comes back as zero.
!  The drops USE a field equate, not a variable - set the current row with
!  PROP:Selected and read it back with CHOICE(). A numeric USE variable looks
!  simpler but fights you: OPEN() zeroes it, PROP:Selected re-syncs it from the
!  control, and DISPLAY() will not make the box show anything. This is the
!  idiom the rest of the collection uses.
  ?FFld{PROP:Selected} = 1
  ?FJn{PROP:Selected}  = 1
  DO LoadOps
  DO LoadSaved
  DO ShowList
  ACCEPT
    CASE EVENT()
    OF EVENT:AlertKey
      IF KEYCODE() = EscKey THEN POST(EVENT:CloseWindow) .
    END
    CASE FIELD()
    OF ?FList
      IF EVENT() = EVENT:NewSelection AND CHOICE(?FList) > 0
        DO PullDown                                         ! put that line back in the editor
      END
    OF ?FFld
      IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
        DO LoadOps
      END
    OF ?FOp
      IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
        DO ShowValues
      END
    OF ?FAdd
      IF EVENT() = EVENT:Accepted
        IF SELF.CondCount() >= MaxCond
          CYCLE
        END
        DO Validate
        IF ~bad
          GET(OpQ,op)
          SELF.AddCond(fi,OpQ.FNId,v1,v2,jn - 1)
          v1 = '' ; v2 = ''
          DISPLAY(?v1) ; DISPLAY(?v2)
          DO ShowList
        END
      END
    OF ?FUpd
      IF EVENT() = EVENT:Accepted
        i = CHOICE(?FList)
        IF i > 0
          DO Validate
          IF ~bad
            GET(SELF.Conds,i)
            IF ~ERRORCODE()
              GET(OpQ,op)
              SELF.Conds.FCField = fi
              SELF.Conds.FCOp    = OpQ.FNId
              SELF.Conds.FCVal1  = v1
              SELF.Conds.FCVal2  = v2
              SELF.Conds.FCJoin  = jn - 1
              PUT(SELF.Conds)
              DO ShowList
            END
          END
        END
      END
    OF ?FDel
      IF EVENT() = EVENT:Accepted
        i = CHOICE(?FList)
        IF i > 0
          SELF.RemoveCond(i)
          DO ShowList
        END
      END
    OF ?FClear
      IF EVENT() = EVENT:Accepted
        SELF.ClearConds()
        DO LoadSaved
        DO ShowList
      END
    OF ?FSav
      IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
        sel = CHOICE(?FSav)
        IF sel > 0
          GET(SavedQ,sel)
          IF ~ERRORCODE()
            SELF.Load(SavedQ.FNName)
            DO ShowList
          END
        END
      END
    OF ?FSave
      IF EVENT() = EVENT:Accepted
        nm = SELF.Loaded
        IF SELF.CondCount()
          IF FltAskName(SELF.Txt(FTx:NameIt),SELF.Txt(FTx:Title),nm)
            SELF.Save(nm)
            DO LoadSaved
          END
        END
      END
    OF ?FDelSave
      IF EVENT() = EVENT:Accepted
        sel = CHOICE(?FSav)
        IF sel > 0
          GET(SavedQ,sel)
          IF ~ERRORCODE()
            IF MESSAGE(CLIP(SELF.Txt(FTx:ConfirmDel)) & '||' & CLIP(SavedQ.FNName), |
                       SELF.Txt(FTx:Title),ICON:Question,BUTTON:Yes+BUTTON:No,BUTTON:No) = BUTTON:Yes
              SELF.DeleteSaved(SavedQ.FNName)
              DO LoadSaved
            END
          END
        END
      END
    OF ?FOk
      IF EVENT() = EVENT:Accepted
        SELF.Accepted = 1
        POST(EVENT:CloseWindow)
      END
    OF ?FCancel
      IF EVENT() = EVENT:Accepted
        POST(EVENT:CloseWindow)
      END
    END
  END
  CLOSE(FWnd)
  RETURN SELF.Accepted

!  ---- the operators that suit the field now chosen -------------------------
LoadOps ROUTINE
  fi = CHOICE(?FFld)
  GET(SELF.Fields,fi)
  IF ERRORCODE() THEN EXIT .
  SELF.OpsFor(SELF.Fields.FFType,OpQ)
  ?FOp{PROP:Selected} = 1
  DO ShowValues

!  ---- only show the value boxes the operator actually uses -----------------
ShowValues ROUTINE
  op = CHOICE(?FOp)
  GET(OpQ,op)
  IF ERRORCODE() THEN EXIT .
  IF SELF.OpTakesValue(OpQ.FNId)
    ENABLE(?v1)
  ELSE
    v1 = ''
    DISABLE(?v1)
  END
  IF SELF.OpTakesTwo(OpQ.FNId)
    UNHIDE(?FAnd2) ; UNHIDE(?v2)
  ELSE
    v2 = ''
    HIDE(?FAnd2) ; HIDE(?v2)
  END
  DISPLAY(?v1)
  DISPLAY(?v2)

!  ---- refuse the half-finished lines before they become a filter -----------
Validate ROUTINE
  bad = 1                                                   ! assume no until it passes
  fi  = CHOICE(?FFld)
  op  = CHOICE(?FOp)
  jn  = CHOICE(?FJn)
  GET(OpQ,op)
  IF ERRORCODE()
    MESSAGE(SELF.Txt(FTx:PickField),SELF.Txt(FTx:Title),ICON:Exclamation)
    EXIT
  END
  IF SELF.OpTakesValue(OpQ.FNId) AND ~CLIP(v1)
    MESSAGE(SELF.Txt(FTx:NeedValue),SELF.Txt(FTx:Title),ICON:Exclamation)
    SELECT(?v1)
    EXIT
  END
!  'Law' in a department NUMBER is a mistake worth catching here, where it can
!  be explained, rather than letting it become a filter that quietly matches
!  nothing.
  GET(SELF.Fields,fi)
  IF ~ERRORCODE() AND SELF.Fields.FFType <> Flt:String AND SELF.OpTakesValue(OpQ.FNId)
    IF ~DEFORMAT(SELF.Num(fi,v1)) AND CLIP(v1) <> '0'
      MESSAGE(CLIP(SELF.Txt(FTx:NeedNumber)) & '||' & CLIP(SELF.Fields.FFLabel), |
              SELF.Txt(FTx:Title),ICON:Exclamation)
      SELECT(?v1)
      EXIT
    END
  END
  IF SELF.OpTakesTwo(OpQ.FNId)
    IF ~CLIP(v2)
      MESSAGE(SELF.Txt(FTx:NeedTwo),SELF.Txt(FTx:Title),ICON:Exclamation)
      SELECT(?v2)
      EXIT
    END
    GET(SELF.Fields,fi)
    IF SELF.Fields.FFType <> Flt:String
      IF DEFORMAT(SELF.Num(fi,v2)) < DEFORMAT(SELF.Num(fi,v1))
        MESSAGE(SELF.Txt(FTx:BadRange),SELF.Txt(FTx:Title),ICON:Exclamation)
        SELECT(?v2)
        EXIT
      END
    END
  END
  bad = 0

!  ---- clicking a line loads it back into the editor ------------------------
PullDown ROUTINE
  GET(SELF.Conds,CHOICE(?FList))
  IF ERRORCODE() THEN EXIT .
  jn2 = SELF.Conds.FCJoin + 1
  ?FFld{PROP:Selected} = SELF.Conds.FCField
  v1 = SELF.Conds.FCVal1
  v2 = SELF.Conds.FCVal2
  DO LoadOps
  LOOP i = 1 TO RECORDS(OpQ)                                ! find that operator in the new list
    GET(OpQ,i)
    IF OpQ.FNId = SELF.Conds.FCOp
      ?FOp{PROP:Selected} = i
      BREAK
    END
  END
  ?FJn{PROP:Selected} = jn2
  DO ShowValues
  DISPLAY(?v1)
  DISPLAY(?v2)

ShowList ROUTINE
  FREE(ShowQ)
  LOOP i = 1 TO RECORDS(SELF.Conds)
    GET(SELF.Conds,i)
    SHQ:SHNo   = i
    SHQ:SHJoin = CHOOSE(i = 1,'', |
                        CHOOSE(SELF.Conds.FCJoin = Flt:Or,CLIP(SELF.Txt(FTx:Or)), |
                                                          CLIP(SELF.Txt(FTx:And))))
    SHQ:SHText = SELF.CondText(i)
    ADD(ShowQ)
  END
  DISPLAY(?FList)
  expr = SELF.Expression()
  DISPLAY(?expr)
  ?FCount{PROP:Text}   = SELF.CondCount() & ' ' & CLIP(SELF.Txt(FTx:Matching))
  ?FSummary{PROP:Text} = SELF.Summary()
  IF SELF.CondCount()
    ENABLE(?FClear) ; ENABLE(?FSave)
  ELSE
    DISABLE(?FClear) ; DISABLE(?FSave)
  END

LoadSaved ROUTINE
  SELF.SavedNames(SavedQ)
  sel = 0
  LOOP i = 1 TO RECORDS(SavedQ)
    GET(SavedQ,i)
    IF UPPER(CLIP(SavedQ.FNName)) = UPPER(CLIP(SELF.Loaded))
      ?FSav{PROP:Selected} = i
      BREAK
    END
  END
  IF RECORDS(SavedQ)
    ENABLE(?FSav) ; ENABLE(?FDelSave)
  ELSE
    DISABLE(?FSav) ; DISABLE(?FDelSave)
  END


! ############################################################################
!  A one-line "what shall we call it?" prompt, so saving needs no extra window
!  in the caller. Module scope - it is not part of the class's interface.
! ############################################################################
FltAskName PROCEDURE(STRING pPrompt,STRING pTitle,*CSTRING pName)
ok   BYTE(0)
buf  CSTRING(65)
NWnd WINDOW('Save'),AT(,,220,84),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI), |
         CENTER,GRAY,SYSTEM,MODAL,ALRT(EscKey)
       PROMPT(''),AT(12,14,196,10),USE(?NPrompt)
       ENTRY(@s64),AT(12,28,196,12),USE(buf)
       BUTTON('OK'),AT(102,56,50,15),USE(?NOk),DEFAULT
       BUTTON('Cancel'),AT(158,56,50,15),USE(?NCancel)
     END
  CODE
  buf = pName
  OPEN(NWnd)
  0{PROP:Text}        = pTitle
  ?NPrompt{PROP:Text} = pPrompt
  ACCEPT
    CASE EVENT()
    OF EVENT:AlertKey
      IF KEYCODE() = EscKey THEN POST(EVENT:CloseWindow) .
    END
    CASE FIELD()
    OF ?NOk
      IF EVENT() = EVENT:Accepted
        IF CLIP(buf)
          ok = 1
          POST(EVENT:CloseWindow)
        END
      END
    OF ?NCancel
      IF EVENT() = EVENT:Accepted THEN POST(EVENT:CloseWindow) .
    END
  END
  CLOSE(NWnd)
  IF ok THEN pName = CLIP(LEFT(buf)) .
  RETURN ok
