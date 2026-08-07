!ABCIncludeFile(MYCALC)
! ============================================================================
!  CalcClass - a pop-up calculator for Clarion, in four flavours.
!
!    Standard     the everyday four-function keypad, memory and percent
!    Scientific   trig, logs, powers, roots, factorial, parentheses, DEG/RAD
!    Programmer   HEX / DEC / OCT / BIN, AND OR XOR NOT, shifts, word size
!    Accountant   an adding-machine tape: running total, subtotal, tax, GT
!
!  Every mode shares one paper roll - the tape in accountant mode, the history
!  of finished calculations in the others - so nothing you worked out scrolls
!  away. Press Accept and the value lands in the field the button sits beside.
!
!  Pure Clarion. No DLL, no OCX, nothing to deploy.
!
!  USAGE (the myCalc template does all of this for you)
!    INCLUDE('CalcClass.INC'),ONCE
!    Calc1  CalcClass
!
!      IF Calc1.AskFor(CUS:CreditLimit)      ! seeds from the field, writes it
!        DISPLAY(?CUS:CreditLimit)           ! back when the user accepts
!      END
!
!    or, if you just want a number:
!      IF Calc1.Ask() THEN total = Calc1.Value .
!
!  FILES: CalcClass.inc + CalcClass.clw on the redirection path, ANSI, CRLF.
! ============================================================================

! ---- languages ------------------------------------------------------------
Calc:English       EQUATE(1)
Calc:Spanish       EQUATE(2)

! ---- every word the window and the word-keys show -------------------------
CalcTxt:Calculator     EQUATE(1)
CalcTxt:Standard       EQUATE(2)
CalcTxt:Scientific     EQUATE(3)
CalcTxt:Programmer     EQUATE(4)
CalcTxt:Accountant     EQUATE(5)
CalcTxt:Mode           EQUATE(6)
CalcTxt:PaperRoll      EQUATE(7)
CalcTxt:Roll           EQUATE(8)
CalcTxt:Copy           EQUATE(9)
CalcTxt:Clear          EQUATE(10)
CalcTxt:Accept         EQUATE(11)
CalcTxt:Cancel         EQUATE(12)
CalcTxt:Hint           EQUATE(13)
CalcTxt:DivZero        EQUATE(14)
CalcTxt:BadInput       EQUATE(15)
CalcTxt:NotNumber      EQUATE(16)
CalcTxt:FixError       EQUATE(17)
CalcTxt:Bksp           EQUATE(18)
CalcTxt:Subtotal       EQUATE(19)
CalcTxt:Total          EQUATE(20)
CalcTxt:GrandTot       EQUATE(21)
CalcTxt:TaxPlus        EQUATE(22)
CalcTxt:TaxMinus       EQUATE(23)
CalcTxt:WordSize       EQUATE(24)
CalcTxt:CopyTip        EQUATE(25)

! ---- the four flavours ----------------------------------------------------
Calc:Standard      EQUATE(1)
Calc:Scientific    EQUATE(2)
Calc:Programmer    EQUATE(3)
Calc:Accountant    EQUATE(4)
Calc:Modes         EQUATE(4)

! ---- which modes the button offers (BOR these into Allow) -----------------
Calc:AllowStandard   EQUATE(1)
Calc:AllowScientific EQUATE(2)
Calc:AllowProgrammer EQUATE(4)
Calc:AllowAccountant EQUATE(8)
Calc:AllowAll        EQUATE(15)

! ---- the keypad -----------------------------------------------------------
Calc:Cols          EQUATE(7)
Calc:Rows          EQUATE(7)
Calc:Cells         EQUATE(49)                  ! Calc:Cols * Calc:Rows

! ---- what a key does ------------------------------------------------------
Act:None           EQUATE(0)
Act:Digit          EQUATE(1)                   ! 0..9 and A..F: the digit is in the key text
Act:Dot            EQUATE(2)
Act:Sign           EQUATE(3)
Act:Back           EQUATE(4)
Act:ClearEntry     EQUATE(5)
Act:ClearAll       EQUATE(6)
! binary operators - these share one code path
Act:Add            EQUATE(10)
Act:Sub            EQUATE(11)
Act:Mul            EQUATE(12)
Act:Div            EQUATE(13)
Act:Pow            EQUATE(14)
Act:Mod            EQUATE(15)
Act:And            EQUATE(16)
Act:Or             EQUATE(17)
Act:Xor            EQUATE(18)
Act:Shl            EQUATE(19)
Act:Shr            EQUATE(20)
Act:Equals         EQUATE(21)
Act:Percent        EQUATE(22)
! unary functions
Act:Sqrt           EQUATE(30)
Act:Sqr            EQUATE(31)
Act:Cube           EQUATE(32)
Act:CubeRoot       EQUATE(33)
Act:Inv            EQUATE(34)
Act:Fact           EQUATE(35)
Act:Ln             EQUATE(36)
Act:Log            EQUATE(37)
Act:ExpE           EQUATE(38)
Act:Exp10          EQUATE(39)
Act:Sin            EQUATE(40)
Act:Cos            EQUATE(41)
Act:Tan            EQUATE(42)
Act:ASin           EQUATE(43)
Act:ACos           EQUATE(44)
Act:ATan           EQUATE(45)
Act:Not            EQUATE(46)
Act:Abs            EQUATE(47)
! constants
Act:Pi             EQUATE(50)
Act:EulerE         EQUATE(51)
! memory
Act:MemClear       EQUATE(60)
Act:MemRecall      EQUATE(61)
Act:MemAdd         EQUATE(62)
Act:MemSub         EQUATE(63)
Act:MemStore       EQUATE(64)
! grouping + toggles
Act:OpenParen      EQUATE(70)
Act:CloseParen     EQUATE(71)
Act:DegRad         EQUATE(72)
Act:BaseHex        EQUATE(73)
Act:BaseDec        EQUATE(74)
Act:BaseOct        EQUATE(75)
Act:BaseBin        EQUATE(76)
Act:WordSize       EQUATE(77)
! the adding-machine roll
Act:TapePlus       EQUATE(80)                  ! post the entry to the tape as +
Act:TapeMinus      EQUATE(81)
Act:Subtotal       EQUATE(82)
Act:Total          EQUATE(83)
Act:GrandTotal     EQUATE(84)
Act:TaxPct         EQUATE(85)                  ! add tax at the configured rate
Act:TaxLess        EQUATE(86)                  ! back tax out of a gross figure

! ---- one line on the paper roll -------------------------------------------
CalcTapeQueue      QUEUE,TYPE
TLine                STRING(52)                ! what the roll shows
TVal                 REAL                      ! the number on that line
TKind                BYTE                      ! 1 entry, 2 result, 3 subtotal, 4 total
                   END

CalcClass          CLASS,TYPE,MODULE('CalcClass.CLW'),LINK('CalcClass.CLW')
! ---- what the caller sets -------------------------------------------------
Mode                 BYTE(1)                   ! Calc:Standard .. Calc:Accountant
Allow                LONG(15)                  ! which modes the drop list offers
Title                CSTRING(64)               ! shown in the header band
Value                REAL                      ! the accepted number (also the seed)
Decimals             BYTE(2)                   ! accountant / display decimals
TaxRate              REAL(16)                  ! percent, for the tax keys
Angle                BYTE(0)                   ! 0 = degrees, 1 = radians
Base                 BYTE(10)                  ! programmer: 16 / 10 / 8 / 2
WordBits             BYTE(32)                  ! programmer: 8 / 16 / 32
ShowTape             BYTE(1)                   ! show the paper roll beside the keys
Language             BYTE(1)                   ! Calc:English / Calc:Spanish
! ---- remembering the last session -----------------------------------------
Persist              BYTE(0)                   ! 1 = remember the mode and options
Profile              CSTRING(65)               ! blank = 'Default'
IniFile              CSTRING(261)              ! blank = <the exe>.INI
! ---- results --------------------------------------------------------------
Accepted             BYTE                      ! 1 = the user pressed Accept
! ---- internals ------------------------------------------------------------
Tape                 &CalcTapeQueue,PROTECTED
Entry                CSTRING(48),PROTECTED     ! the number being typed
Expr                 CSTRING(128),PROTECTED    ! the faint line above the readout
Acc                  REAL,PROTECTED            ! the accumulator
Pend                 LONG,PROTECTED            ! the operator waiting for its right side
NewEnt               BYTE,PROTECTED            ! next digit starts a fresh number
Mem                  REAL,PROTECTED
MemSet               BYTE,PROTECTED
ErrState             BYTE,PROTECTED            ! 1 = display shows an error, keys reset it
Running              REAL,PROTECTED            ! accountant: the running total
GrandTot             REAL,PROTECTED
PAcc                 REAL,DIM(16),PROTECTED    ! parenthesis stack
POp                  LONG,DIM(16),PROTECTED
PDepth               LONG,PROTECTED
BtnAct               LONG,DIM(49),PROTECTED    ! the current layout
BtnTxt               STRING(7),DIM(49),PROTECTED
BtnSpan              BYTE,DIM(49),PROTECTED    ! 1 or 2 cells wide
Loaded               BYTE,PROTECTED

! ---- lifecycle ------------------------------------------------------------
Construct            PROCEDURE
Destruct             PROCEDURE
Reset                PROCEDURE                 ! clear everything except memory

! ---- the pop-up -----------------------------------------------------------
Ask                  PROCEDURE(),BYTE,VIRTUAL  ! modal; 1 = the user accepted
AskFor               PROCEDURE(*? pField),BYTE,PROC   ! seed from a field, write it back

! ---- driving it from code -------------------------------------------------
Press                PROCEDURE(LONG pAct,STRING pText)  ! press one key
SetValue             PROCEDURE(REAL pValue)             ! load the readout
Current              PROCEDURE(),REAL                   ! what the readout holds
DisplayText          PROCEDURE(),STRING                 ! the readout, formatted
ModeName             PROCEDURE(BYTE pMode),STRING
Txt                  PROCEDURE(LONG pId),STRING   ! one string, in Language
Allowed              PROCEDURE(BYTE pMode),BYTE

! ---- the paper roll -------------------------------------------------------
AddTape              PROCEDURE(STRING pLine,REAL pVal,BYTE pKind)
ClearTape            PROCEDURE
TapeText             PROCEDURE(),STRING        ! the whole roll as CR/LF text
TapeLines            PROCEDURE(),LONG          ! how many lines are on the roll
TapeLine             PROCEDURE(LONG pLine),STRING

! ---- remembering ----------------------------------------------------------
LoadSettings         PROCEDURE()
SaveSettings         PROCEDURE()
ForgetSettings       PROCEDURE()

! ---- internals (protected) ------------------------------------------------
Layout               PROCEDURE,PROTECTED       ! fill BtnAct/BtnTxt for Mode
SetKey               PROCEDURE(LONG pCell,STRING pText,LONG pAct,BYTE pSpan=1),PROTECTED
Apply                PROCEDURE(LONG pOp,REAL pRight),REAL,PROTECTED
Unary                PROCEDURE(LONG pAct,REAL pV),REAL,PROTECTED
OpText               PROCEDURE(LONG pOp),STRING,PROTECTED
Fmt                  PROCEDURE(REAL pV),STRING,PROTECTED
FmtPlain             PROCEDURE(REAL pV),STRING,PROTECTED
ToBase               PROCEDURE(REAL pV),STRING,PROTECTED
FromBase             PROCEDURE(STRING pS),REAL,PROTECTED
MaskWord             PROCEDURE(REAL pV),REAL,PROTECTED
Fail                 PROCEDURE(STRING pWhy),PROTECTED
IniPath              PROCEDURE(),STRING,PROTECTED
IniSection           PROCEDURE(),STRING,PROTECTED
                   END
