!ABCIncludeFile(EMAILTO)
! ============================================================================
!  EmailJsonClass - reading what a provider sends back.
!
!  Sending mail only ever needed JSON in one direction: build a request, post
!  it, look at the status code.  Asking a provider a QUESTION - who is blocked,
!  what did last week look like, which campaigns exist - needs the other
!  direction, and a document that comes back with a thousand objects in it
!  cannot be picked apart with INSTRING.
!
!  So this is a real parser.  It is pure Clarion, it allocates nothing per
!  value, and it turns a document into a QUEUE of nodes, each one carrying the
!  PATH it sits at:
!
!      {"count":2,"contacts":[{"email":"a@b.com","reason":{"code":"hardBounce"}}]}
!
!      Path                        Kind      Value
!      (blank - the root)          object
!      count                       number    2
!      contacts                    array
!      contacts.0                  object
!      contacts.0.email            string    a@b.com
!      contacts.0.reason           object
!      contacts.0.reason.code      string    hardBounce
!
!  An array element is addressed by its ZERO-based index, exactly as the
!  provider documentation numbers them.  So the whole of EmailApiClass reads
!  values by asking for a path:
!
!      Json.Parse(Net.Body())
!      LOOP i = 0 TO Json.Count('contacts') - 1
!         Addr   = Json.Value('contacts.' & i & '.email')
!         Reason = Json.Value('contacts.' & i & '.reason.message')
!      END
!
!  Lookups are a binary search, not a scan: after a parse the paths are copied
!  into a sorted index queue.  A 5,000-node document answers a path in a dozen
!  comparisons, which is what makes a provider's 1,000-row block list usable.
!
!  TEXT COMES BACK AS UTF-8.  Every one of these APIs is UTF-8, and a Clarion
!  STRING is Windows-1252.  Value() therefore does BOTH jobs: it undoes the JSON
!  escapes (\" \ \n \uXXXX) and then transcodes UTF-8 to Windows-1252, so a
!  bounce reason with an accent in it arrives readable.  Raw() is there for the
!  rare case you want the bytes exactly as they came.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

  OMIT('_EndOfInclude_',_EmailJsonClassPresent_)
_EmailJsonClassPresent_ EQUATE(1)

  INCLUDE('EmailMsgClass.INC'),ONCE                 ! EmailBufClass

! ---- node kinds ------------------------------------------------------------
ETJs:Object        EQUATE(1)
ETJs:Array         EQUATE(2)
ETJs:String        EQUATE(3)
ETJs:Number        EQUATE(4)
ETJs:True          EQUATE(5)
ETJs:False         EQUATE(6)
ETJs:Null          EQUATE(7)

! ---- errors ----------------------------------------------------------------
ETJs:Ok            EQUATE(0)
ETJs:Syntax        EQUATE(-301)
ETJs:TooDeep       EQUATE(-302)
ETJs:Empty         EQUATE(-303)

ETJs:MaxDepth      EQUATE(24)                       ! deeper than any mail API goes

! ---- the parsed document ---------------------------------------------------
EmailJsonQueue     QUEUE,TYPE
Kind                 BYTE                           ! ETJs:...
Depth                BYTE                           ! 0 = the root value
Path                 CSTRING(257)                   ! 'contacts.0.reason.message'
Name                 CSTRING(129)                   ! the member name; blank inside an array
Ofs                  LONG                           ! where the value starts in Doc, 1-based.
Len                  LONG                           !   For a string this is the CONTENT, with
                                                    !   the quotes and escapes still in it.
Items                LONG                           ! object / array: how many direct children
                   END

! The path index: the same paths, sorted, so a lookup is a binary search.
EmailJsonIdxQueue  QUEUE,TYPE
Path                 CSTRING(257)
Node                 LONG
                   END

EmailJsonClass     CLASS,TYPE,MODULE('EmailJsonClass.CLW'),LINK('EmailJsonClass.CLW',_emailToLinkMode_),DLL(_emailToDllMode_)
! ---- the document --------------------------------------------------------
NodeQ                &EmailJsonQueue
IdxQ                 &EmailJsonIdxQueue,PRIVATE
Doc                  &STRING                        ! our own copy of the text
DocLen               LONG
! ---- results -------------------------------------------------------------
LastError            LONG
LastErrorText        CSTRING(257)
! ---- internals -----------------------------------------------------------
Pos                  LONG,PRIVATE                   ! the parser cursor
ValBuf               &EmailBufClass,PRIVATE         ! one buffer per value-returning method,
NamBuf               &EmailBufClass,PRIVATE         !   because they nest - see the note in
RawBuf               &EmailBufClass,PRIVATE         !   EmailMsgClass.INC

Construct            PROCEDURE
Destruct             PROCEDURE
! ---- parsing -------------------------------------------------------------
Parse                PROCEDURE(STRING pJson),BYTE,PROC
ClearAll             PROCEDURE
! ---- asking questions ----------------------------------------------------
Find                 PROCEDURE(STRING pPath),LONG   ! node number, 0 = no such path
Has                  PROCEDURE(STRING pPath),BYTE
KindOf               PROCEDURE(STRING pPath),BYTE
Count                PROCEDURE(STRING pPath),LONG   ! members of an object / elements of an array
Value                PROCEDURE(STRING pPath),STRING ! unescaped, UTF-8 folded to Windows-1252.
                                                    !   NOT called Val: VAL is a Clarion
                                                    !   intrinsic, and a method with that name
                                                    !   redefines it for every module that
                                                    !   includes this file - the next VAL() in
                                                    !   the application stops compiling.
ValueLong            PROCEDURE(STRING pPath),LONG
ValueReal            PROCEDURE(STRING pPath),REAL
ValueBool            PROCEDURE(STRING pPath),BYTE   ! true / 1 / "yes" / "true" all count
Raw                  PROCEDURE(STRING pPath),STRING ! the slice exactly as it arrived, objects
                                                    !   and arrays included - handy for logging
                                                    !   the one row that went wrong
! ---- the first array in the document -------------------------------------
!  Providers disagree about where the list lives: SendGrid puts it at the root,
!  Brevo under "contacts", Mailjet under "Data", Mailgun under "items".  When a
!  descriptor names the wrong one, this finds it anyway.
FirstArray           PROCEDURE(),STRING             ! the path of the outermost array, '' if none
! ---- text ----------------------------------------------------------------
FromUtf8             PROCEDURE(STRING pUtf8),STRING
! ---- internals -----------------------------------------------------------
SetErr               PROCEDURE(LONG pCode,<STRING pText>),BYTE,PROC
ParseValue           PROCEDURE(STRING pPath,STRING pName,BYTE pDepth),BYTE,PROC,PRIVATE
SkipWs               PROCEDURE,PRIVATE
ScanString           PROCEDURE(*LONG pOfs,*LONG pLen),BYTE,PROC,PRIVATE
Decode               PROCEDURE(LONG pOfs,LONG pLen,EmailBufClass pOut),PRIVATE
                   END

  _EndOfInclude_
