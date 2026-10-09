!ABCIncludeFile(MYFILTER)
! ============================================================================
!  MyFilterClass - a filter builder for any ABC browse.
!
!    * Tick the fields you want to search on, out of the browse's own columns
!    * Pick how to search each one: equals, begins with, contains, a range,
!      a date range, in the last N days, matches a pattern...
!    * Conditions join with AND or OR, and you can see the expression it built
!    * Save a filter by name and pick it again later - per user in the INI, or
!      shared in a table
!
!  It hands the browse a normal ABC filter through
!      BRW1.SetFilter(expression,'7 myFilter')
!  which is a NAMED SLOT: it is ANDed with whatever filter the browse already
!  had (range limits, a locator, a QBE) instead of replacing it. Passing an
!  empty string deletes the slot again, so clearing is clean.
!
!  ------------------------------------------------------------------------
!  THE ONE PREREQUISITE: the file must be BINDABLE
!  ------------------------------------------------------------------------
!  A filter expression is evaluated by name at run time, and the runtime
!  refuses a field it has not been told about:
!       "BIND has not been called for CUS:Name"
!  ABC calls BIND(record) for you every time it opens a file
!  (FileManager.OpenServer -> BindFields), but that only works if the file
!  carries the BINDABLE attribute. Tick "Bindable" on the file in the
!  dictionary. Nothing else is needed, and nothing else will do.
!
!  ------------------------------------------------------------------------
!  WHAT THE EXPRESSIONS LOOK LIKE
!  ------------------------------------------------------------------------
!  Every operator below was checked against a real TPS file before it was
!  offered here - see FltProbe in the test harness. Two findings shaped it:
!
!    * SUB() works, SLICING DOES NOT. 'UPPER(CUS:Name)[1 : 5] = ''SMITH'''
!      does not filter - it quietly matches every record. So "begins with"
!      is built with SUB(), never with [a : b].
!    * MATCH() works, including Match:Wild + Match:NoCase (17), which is
!      what the "matches pattern" operator uses.
!
!  ------------------------------------------------------------------------
!  USAGE (the myFilter template writes all of this for you)
!    INCLUDE('MyFilterClass.INC'),ONCE
!    Flt1  MyFilterClass
!
!      Flt1.AddField('CUS:Name',   'Customer', Flt:String, '@s30')
!      Flt1.AddField('CUS:Balance','Balance',  Flt:Number, '@n-12.2')
!      Flt1.AddField('CUS:Added',  'Added',    Flt:Date,   '@d17')
!      IF Flt1.Ask()
!        BRW1.SetFilter(Flt1.Expression(),'7 myFilter')
!        BRW1.ResetSort(1)
!      END
!
!  FILES: MyFilterClass.inc + MyFilterClass.clw on the redirection path,
!         ANSI, CRLF. The source is pure ASCII - the Spanish accents are
!         written as Clarion <nnn> escapes so no editor can eat them.
! ============================================================================

! ---- what kind of field it is, which decides the operators offered --------
Flt:String         EQUATE(1)
Flt:Number         EQUATE(2)
Flt:Date           EQUATE(3)
Flt:Time           EQUATE(4)
Flt:Flag           EQUATE(5)                   ! BYTE used as yes/no

! ---- the operators --------------------------------------------------------
Flt:Equal          EQUATE(1)
Flt:NotEqual       EQUATE(2)
Flt:Begins         EQUATE(3)                   ! strings
Flt:Ends           EQUATE(4)
Flt:Contains       EQUATE(5)
Flt:NotContains    EQUATE(6)
Flt:Empty          EQUATE(7)
Flt:NotEmpty       EQUATE(8)
Flt:Matches        EQUATE(9)                   ! * and ? wildcards
Flt:Less           EQUATE(10)                  ! numbers, dates, times
Flt:LessEqual      EQUATE(11)
Flt:Greater        EQUATE(12)
Flt:GreaterEqual   EQUATE(13)
Flt:Between        EQUATE(14)                  ! uses Value2
Flt:NotBetween     EQUATE(15)
Flt:Today          EQUATE(16)                  ! dates
Flt:Yesterday      EQUATE(17)
Flt:LastNDays      EQUATE(18)                  ! Value1 = N
Flt:NextNDays      EQUATE(19)
Flt:InMonth        EQUATE(20)                  ! Value1 = 1..12
Flt:InYear         EQUATE(21)                  ! Value1 = the year
Flt:IsTrue         EQUATE(22)                  ! flags
Flt:IsFalse        EQUATE(23)
Flt:LastOp         EQUATE(23)

! ---- how a condition joins the one before it ------------------------------
Flt:And            EQUATE(0)
Flt:Or             EQUATE(1)

! ---- where saved filters live ---------------------------------------------
Flt:Ini            EQUATE(0)                   ! <exe>.INI, per user, no setup
Flt:Table          EQUATE(1)                   ! FilterHdr / FilterLine

! ---- languages ------------------------------------------------------------
Flt:English        EQUATE(1)
Flt:Spanish        EQUATE(2)

! ---- the slot the browse filter goes into ---------------------------------
!  '7 ' puts us after ABC's own '5 Standard', and the list is conjunctive, so
!  a range limit or a QBE still applies alongside ours.
Flt:Slot           EQUATE('7 myFilter')

! ---- every word the window shows ------------------------------------------
FTx:Title          EQUATE(1)
FTx:Hint           EQUATE(2)
FTx:Field          EQUATE(3)
FTx:Test           EQUATE(4)
FTx:Value          EQUATE(5)
FTx:AndOr          EQUATE(6)
FTx:And            EQUATE(7)
FTx:Or             EQUATE(8)
FTx:Add            EQUATE(9)
FTx:Edit           EQUATE(10)
FTx:Remove         EQUATE(11)
FTx:ClearAll       EQUATE(12)
FTx:Apply          EQUATE(13)
FTx:Cancel         EQUATE(14)
FTx:Save           EQUATE(15)
FTx:Saved          EQUATE(16)                  ! "Saved filters"
FTx:Delete         EQUATE(17)
FTx:NameIt         EQUATE(18)                  ! "Name for this filter"
FTx:Expression     EQUATE(19)
FTx:Matching       EQUATE(20)                  ! "n conditions"
FTx:NoFields       EQUATE(21)
FTx:PickField      EQUATE(22)
FTx:NeedValue      EQUATE(23)
FTx:NeedTwo        EQUATE(24)                  ! a range wants both ends
FTx:BadRange       EQUATE(25)                  ! ...and the right way round
FTx:Overwrite      EQUATE(26)
FTx:ConfirmDel     EQUATE(27)
FTx:And2           EQUATE(28)                  ! the word between range ends
FTx:Days           EQUATE(29)
FTx:Nothing        EQUATE(30)                  ! "no filter - showing everything"
FTx:Condition      EQUATE(31)                  ! the list's column heading
FTx:NeedNumber     EQUATE(32)                  ! text typed into a numeric field

! ---- the browse's fields, as the template registered them -----------------
FilterFieldQueue   QUEUE,TYPE
FFName               CSTRING(65)               ! 'CUS:Name' - goes into the expression
FFLabel              CSTRING(65)               ! what the user sees
FFType               BYTE                      ! Flt:String / Number / Date / ...
FFPicture            CSTRING(17)
                   END

! ---- one line of the filter the user built --------------------------------
FilterCondQueue    QUEUE,TYPE
FCField              LONG                      ! position in the field queue
FCOp                 SHORT
FCVal1               CSTRING(81)
FCVal2               CSTRING(81)
FCJoin               SHORT                     ! Flt:And / Flt:Or, ignored on line 1
                   END

! ---- a name plus a code: saved-filter names, and the operator drop list ----
!  A drop list only ever gives back a POSITION, so the operator code has to
!  travel beside the name or the window has to keep a second map in step.
FilterNameQueue    QUEUE,TYPE
FNName               CSTRING(65)
FNId                 LONG                      ! the operator, for OpsFor
                   END

MyFilterClass      CLASS,TYPE,MODULE('MyFilterClass.CLW'),LINK('MyFilterClass.CLW')
! ---- what the caller sets -------------------------------------------------
Title                CSTRING(64)               ! blank = the localised word
Language             BYTE(1)
Storage              BYTE(0)                   ! Flt:Ini / Flt:Table
Profile              CSTRING(65)               ! which browse these filters belong to
IniFile              CSTRING(261)              ! blank = the application's own
CaseSensitive        BYTE(0)                   ! off: text compares are UPPERed
! ---- results --------------------------------------------------------------
Accepted             BYTE                      ! 1 = the user pressed Apply
! ---- the data -------------------------------------------------------------
Fields               &FilterFieldQueue
Conds                &FilterCondQueue
! ---- internals ------------------------------------------------------------
Expr                 CSTRING(1025),PROTECTED   ! Expression() builds into this
Loaded               CSTRING(65),PROTECTED     ! the saved filter now in use

! ---- lifecycle ------------------------------------------------------------
Construct            PROCEDURE
Destruct             PROCEDURE

! ---- telling it about the browse (the template does this) -----------------
AddField             PROCEDURE(STRING pName,STRING pLabel,BYTE pType,<STRING pPicture>)
FieldCount           PROCEDURE(),LONG
ClearFields          PROCEDURE

! ---- the conditions -------------------------------------------------------
AddCond              PROCEDURE(LONG pField,SHORT pOp,<STRING pV1>,<STRING pV2>,SHORT pJoin=0),LONG,PROC
RemoveCond           PROCEDURE(LONG pLine)
CondCount            PROCEDURE(),LONG
ClearConds           PROCEDURE
Active               PROCEDURE(),BYTE          ! is anything actually filtering?

! ---- the filter itself ----------------------------------------------------
Expression           PROCEDURE(),STRING        ! the whole thing, ready for SetFilter
OneCond              PROCEDURE(LONG pLine),STRING   ! just that line's expression
CondText             PROCEDURE(LONG pLine),STRING   ! ...as the user reads it
Summary              PROCEDURE(),STRING        ! "Balance > 100 AND Added is today"

! ---- the pop-up -----------------------------------------------------------
Ask                  PROCEDURE(),BYTE,VIRTUAL  ! modal; 1 = the user pressed Apply

! ---- which operators suit which field -------------------------------------
OpsFor               PROCEDURE(BYTE pType,*FilterNameQueue pQ)   ! fills a drop list
OpName               PROCEDURE(SHORT pOp),STRING
OpTakesValue         PROCEDURE(SHORT pOp),BYTE
OpTakesTwo           PROCEDURE(SHORT pOp),BYTE

! ---- saved filters --------------------------------------------------------
SavedNames           PROCEDURE(*FilterNameQueue pQ)
Save                 PROCEDURE(STRING pName),BYTE,PROC
Load                 PROCEDURE(STRING pName),BYTE,PROC
DeleteSaved          PROCEDURE(STRING pName),BYTE,PROC
LoadedName           PROCEDURE(),STRING

! ---- words ----------------------------------------------------------------
Txt                  PROCEDURE(LONG pId),STRING

! ---- internals (protected) ------------------------------------------------
Quote                PROCEDURE(STRING pText),STRING,PROTECTED  ! 'it''s' - doubles the quote
FieldRef             PROCEDURE(LONG pField),STRING,PROTECTED   ! UPPER(x) or x
Num                  PROCEDURE(LONG pField,STRING pText),STRING,PROTECTED ! value as the file sees it
IniPath              PROCEDURE(),STRING,PROTECTED
IniSection           PROCEDURE(),STRING,PROTECTED
SaveIni              PROCEDURE(STRING pName),BYTE,PROTECTED
LoadIni              PROCEDURE(STRING pName),BYTE,PROTECTED
SaveTable            PROCEDURE(STRING pName),BYTE,PROTECTED,VIRTUAL
LoadTable            PROCEDURE(STRING pName),BYTE,PROTECTED,VIRTUAL
DeleteTable          PROCEDURE(STRING pName),BYTE,PROTECTED,VIRTUAL
TableNames           PROCEDURE(*FilterNameQueue pQ),PROTECTED,VIRTUAL
                   END
