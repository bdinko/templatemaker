!ABCIncludeFile(EMAILTO)
! ============================================================================
!  EmailApiClass - one class, every provider's management API.
!
!  EmailToClass answers one question: "send this".  This class answers all the
!  others, and it answers them the SAME WAY whoever you signed up with:
!
!      who am I ............. GetAccount()      plan, credits, reputation
!      who is blocked ....... GetSuppressions() address, kind, REASON, when
!      unblock one .......... DeleteSuppression()
!      unblock the lot ...... DeleteAllSuppressions()
!      block somebody ....... AddSuppression()
!      how did it go ........ GetStats()        per day, over a date range
!      what happened ........ GetEvents()       delivered / opened / bounced
!      my contacts .......... GetContacts()  GetLists()  AddContact()
!      my campaigns ......... GetCampaigns() AddCampaign() SendCampaign()
!      my templates ......... GetTemplates()
!      my senders ........... GetSenders()   GetDomains()
!      my webhooks .......... GetWebhooks()  AddWebhook()  DeleteWebhook()
!
!  NINE providers answer: SendGrid, Brevo, Mailgun, Postmark, Mailjet, Resend,
!  SparkPost, MailerSend and Amazon SES.  Eight of them take a key in a header;
!  Amazon signs the whole request, which is why EmailNetClass grew SignAws.
!
!  Every one of those fills a NORMALISED queue.  SendGrid calls a blocked
!  address "email" with a "reason" and a unix "created"; Brevo calls it "email"
!  with "reason":{"message"} and an ISO "blockedAt"; Mailgun calls it "address"
!  with "error", "code" and an RFC-2822 "created_at"; Mailjet buries it in
!  "Data" and spells everything with capitals.  After a GetSuppressions() they
!  are all one queue with the same six columns, and your code stops caring.
!
!  HOW ONE CLASS COVERS NINE APIS.  Not with ten branches per method - with a
!  TABLE.  Each row says: for THIS provider and THIS operation, use this verb
!  and this URL, the list is at this path in the reply, and these JSON members
!  fill these columns.  Adding a provider is adding rows, which is why the
!  whole matrix is one readable method (BuildMap) instead of a thousand lines
!  of CASE.  Supports() simply asks whether a row exists, so a window can grey
!  out what a provider genuinely cannot do rather than failing at run time.
!
!  IT USES THE ACCOUNT YOU ALREADY HAVE.  Init() borrows EmailToClass's account
!  and its HTTPS layer, so the key you typed into the Setup window - DPAPI
!  sealed, in your settings table or an INI - is the key these calls use.
!  Nothing new to configure and no second copy of a credential.
!
!  USAGE
!      MailApi.Init(Mailer)
!      IF MailApi.GetSuppressions(ETSup:All) >= 0
!         LOOP i = 1 TO RECORDS(MailApi.SuppQ)
!            GET(MailApi.SuppQ, i)
!            !  MailApi.SuppQ.Address / .KindName / .Reason / .WhenDate
!         END
!      END
!      MailApi.DeleteSuppression('bounced@example.com', ETSup:Bounce)
!      MailApi.Manage()                        ! or just show them the window
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

  OMIT('_EndOfInclude_',_EmailApiClassPresent_)
_EmailApiClassPresent_ EQUATE(1)

  INCLUDE('EmailToClass.INC'),ONCE
  INCLUDE('EmailJsonClass.INC'),ONCE

! ---- what a provider can be asked to do ------------------------------------
ETOp:Account       EQUATE(1)                     ! the profile behind the key
ETOp:Suppressions  EQUATE(2)                     ! list the blocked addresses
ETOp:SuppDelete    EQUATE(3)                     ! unblock one
ETOp:SuppDeleteAll EQUATE(4)                     ! unblock every one of a kind
ETOp:SuppAdd       EQUATE(5)                     ! block an address yourself
ETOp:Stats         EQUATE(6)
ETOp:Events        EQUATE(7)
ETOp:Contacts      EQUATE(8)
ETOp:ContactAdd    EQUATE(9)
ETOp:ContactDelete EQUATE(10)
ETOp:Lists         EQUATE(11)
ETOp:ListAdd       EQUATE(12)
ETOp:ListMembers   EQUATE(13)
ETOp:Campaigns     EQUATE(14)
ETOp:CampaignAdd   EQUATE(15)
ETOp:CampaignSend  EQUATE(16)
ETOp:Templates     EQUATE(17)
ETOp:Senders       EQUATE(18)
ETOp:Domains       EQUATE(19)
ETOp:Webhooks      EQUATE(20)
ETOp:WebhookAdd    EQUATE(21)
ETOp:WebhookDelete EQUATE(22)
ETOp:Last          EQUATE(22)

! ---- the kinds of block ----------------------------------------------------
!  Every provider keeps these lists; they just disagree about the names.  A
!  provider that lumps two of them together answers the same rows for both,
!  and Kind on each row says which one it really is.
ETSup:All          EQUATE(0)
ETSup:Bounce       EQUATE(1)                     ! the address does not exist / refused for good
ETSup:Block        EQUATE(2)                     ! the receiving server refused us, this time
ETSup:Spam         EQUATE(3)                     ! the recipient pressed "this is junk"
ETSup:Unsub        EQUATE(4)                     ! the recipient unsubscribed
ETSup:Invalid      EQUATE(5)                     ! it is not a working address at all
ETSup:Kinds        EQUATE(5)

! ---- errors ----------------------------------------------------------------
ETApi:Ok           EQUATE(0)
ETApi:NoKey        EQUATE(-401)
ETApi:NotSupported EQUATE(-402)
ETApi:Http         EQUATE(-403)
ETApi:Refused      EQUATE(-404)                  ! the provider answered, and said no
ETApi:BadReply     EQUATE(-405)
ETApi:NoObject     EQUATE(-406)                  ! Init() was never called
ETApi:Cancelled    EQUATE(-407)

! ---- Txt() string ids ------------------------------------------------------
ETATxt:Manage      EQUATE(1)
ETATxt:Account     EQUATE(2)
ETATxt:Blocked     EQUATE(3)
ETATxt:Statistics  EQUATE(4)
ETATxt:Activity    EQUATE(5)
ETATxt:Contacts    EQUATE(6)
ETATxt:Lists       EQUATE(7)
ETATxt:Campaigns   EQUATE(8)
ETATxt:Templates   EQUATE(9)
ETATxt:Senders     EQUATE(10)
ETATxt:Domains     EQUATE(11)
ETATxt:Webhooks    EQUATE(12)
ETATxt:Refresh     EQUATE(13)
ETATxt:Address     EQUATE(14)
ETATxt:Kind        EQUATE(15)
ETATxt:Reason      EQUATE(16)
ETATxt:When        EQUATE(17)
ETATxt:Code        EQUATE(18)
ETATxt:Unblock     EQUATE(19)
ETATxt:UnblockAll  EQUATE(20)
ETATxt:Block       EQUATE(21)
ETATxt:Close       EQUATE(22)
ETATxt:Working     EQUATE(23)
ETATxt:NoRows      EQUATE(24)
ETATxt:Rows        EQUATE(25)
ETATxt:Confirm     EQUATE(26)
ETATxt:ConfirmAll  EQUATE(27)
ETATxt:Done        EQUATE(28)
ETATxt:NotSupport  EQUATE(29)
ETATxt:Name        EQUATE(30)
ETATxt:Subject     EQUATE(31)
ETATxt:Status      EQUATE(32)
ETATxt:Members     EQUATE(33)
ETATxt:Sent        EQUATE(34)
ETATxt:Opens       EQUATE(35)
ETATxt:Clicks      EQUATE(36)
ETATxt:Bounces     EQUATE(37)
ETATxt:Spam        EQUATE(38)
ETATxt:Unsubs      EQUATE(39)
ETATxt:Delivered   EQUATE(40)
ETATxt:Requests    EQUATE(41)
ETATxt:From        EQUATE(42)
ETATxt:To          EQUATE(43)
ETATxt:Send        EQUATE(44)
ETATxt:Verified    EQUATE(45)
ETATxt:Url         EQUATE(46)
ETATxt:Events      EQUATE(47)
ETATxt:Export      EQUATE(48)
ETATxt:Exported    EQUATE(49)
ETATxt:Plan        EQUATE(50)
ETATxt:Credits     EQUATE(51)
ETATxt:Reputation  EQUATE(52)
ETATxt:Company     EQUATE(53)
ETATxt:Provider    EQUATE(54)
ETATxt:AddContact  EQUATE(55)
ETATxt:Delete      EQUATE(56)
ETATxt:Raw         EQUATE(57)
ETATxt:Kinds       EQUATE(58)
ETATxt:Search      EQUATE(59)
ETATxt:AllKinds    EQUATE(60)

! ============================================================================
!  The normalised answers.  Whatever the provider called it, it arrives here.
! ============================================================================
EmailSuppQueue     QUEUE,TYPE
Address              CSTRING(256)
Kind                 BYTE                        ! ETSup:...
KindName             CSTRING(33)                 ! already in the object's language
Reason               CSTRING(513)                ! why - "550 5.1.1 user unknown", "spam report"
Code                 LONG                        ! the SMTP status, where the provider keeps one
WhenDate             DATE
WhenTime             TIME
Id                   CSTRING(65)                 ! the provider's handle, when it has one
Sender               CSTRING(256)                ! which of your senders it happened to
Raw                  CSTRING(1025)               ! the provider's own object, for anything
                   END                           !   this queue does not have a column for

EmailStatQueue     QUEUE,TYPE
WhenDate             DATE                        ! one row per day
Requests             LONG
Delivered            LONG
Opens                LONG
UniqueOpens          LONG
Clicks               LONG
UniqueClicks         LONG
HardBounces          LONG
SoftBounces          LONG
Blocks               LONG
SpamReports          LONG
Unsubscribed         LONG
Invalid              LONG
                   END

EmailEventQueue    QUEUE,TYPE
WhenDate             DATE
WhenTime             TIME
Address              CSTRING(256)
EventName            CSTRING(33)                 ! delivered / opened / clicked / bounced / spam
Reason               CSTRING(513)
Subject              CSTRING(257)
MessageId            CSTRING(129)
Link                 CSTRING(513)
                   END

EmailContactQueue  QUEUE,TYPE
Id                   CSTRING(65)
Address              CSTRING(256)
Name                 CSTRING(129)
Blocked              BYTE
Unsubscribed         BYTE
WhenDate             DATE
ListIds              CSTRING(257)
Raw                  CSTRING(1025)
                   END

EmailListQueue     QUEUE,TYPE
Id                   CSTRING(65)
Name                 CSTRING(129)
Members              LONG
Blocked              LONG
FolderId             CSTRING(65)
                   END

EmailCampaignQueue QUEUE,TYPE
Id                   CSTRING(65)
Name                 CSTRING(129)
Subject              CSTRING(257)
Status               CSTRING(33)
WhenDate             DATE
WhenTime             TIME
Recipients           LONG
Opens                LONG
Clicks               LONG
                   END

EmailTemplateQueue QUEUE,TYPE
Id                   CSTRING(65)
Name                 CSTRING(129)
Subject              CSTRING(257)
Active               BYTE
WhenDate             DATE
                   END

EmailSenderQueue   QUEUE,TYPE
Id                   CSTRING(65)
Address              CSTRING(256)
Name                 CSTRING(129)
Verified             BYTE
Status               CSTRING(65)
                   END

EmailDomainQueue   QUEUE,TYPE
Id                   CSTRING(65)
Name                 CSTRING(129)
Verified             BYTE
Spf                  BYTE
Dkim                 BYTE
Status               CSTRING(65)
                   END

EmailHookQueue     QUEUE,TYPE
Id                   CSTRING(65)
Url                  CSTRING(513)
Events               CSTRING(257)
Active               BYTE
                   END

! ---- what GetAccount() found -----------------------------------------------
EmailApiAcctGroup  GROUP,TYPE
Name                 CSTRING(129)
Company              CSTRING(129)
Address              CSTRING(256)
Plan                 CSTRING(65)
Credits              LONG                        ! -1 = the provider does not count them
Reputation           LONG                        ! 0..100 where the provider publishes one
Status               CSTRING(65)
Raw                  CSTRING(2049)
                   END

! ============================================================================
!  The provider matrix.  One row per (provider, operation).
!
!  Url      the whole address, with {placeholders} filled in at call time:
!             {domain} {user} {region} {id} {email} {limit} {offset}
!             {epochfrom} {epochto} {isofrom} {isoto} {ymdfrom} {ymdto}
!  ItemPath where the list of rows sits in the reply.  Blank means the reply
!           IS the list; a path that is not there falls back to the first
!           array in the document, so a provider that renames a wrapper does
!           not break the row.
!  Map      "Column=source;Column=source" - the JSON member each normalised
!           column comes from, relative to one item.  A source may be a path
!           ("reason.message"), and may carry a converter:
!             #  unix epoch seconds       @  ISO-8601      %  RFC-2822 date
!             $  YYYY-MM-DD               !  a literal value, not a lookup
!  Body     the request body for a POST / PUT / DELETE that needs one, with
!           the same placeholders.
!  NextPath cursor paging: where the next page's URL lives in the reply.
! ============================================================================
EmailApiMapQueue   QUEUE,TYPE
Provider             BYTE
Op                   BYTE
Kind                 BYTE                        ! suppression kind, ETSup:All = any
Verb                 CSTRING(8)
Url                  CSTRING(257)
ItemPath             CSTRING(65)
Map                  CSTRING(769)
Body                 CSTRING(769)
NextPath             CSTRING(65)
                   END

! ============================================================================
!  EmailApiClass
! ============================================================================
EmailApiClass      CLASS,TYPE,MODULE('EmailApiClass.CLW'),LINK('EmailApiClass.CLW',_emailToLinkMode_),DLL(_emailToDllMode_)
! ---- what it borrows -----------------------------------------------------
Mailer               &EmailToClass                ! the account and the HTTPS layer, not owned
Net                  &EmailNetClass               ! borrowed from Mailer
Enc                  &EmailMsgClass               ! borrowed from Mailer, for base64
Json                 &EmailJsonClass              ! owned
! ---- the answers ---------------------------------------------------------
Account              LIKE(EmailApiAcctGroup)
SuppQ                &EmailSuppQueue
StatQ                &EmailStatQueue
EventQ               &EmailEventQueue
ContactQ             &EmailContactQueue
ListQ                &EmailListQueue
CampaignQ            &EmailCampaignQueue
TemplateQ            &EmailTemplateQueue
SenderQ              &EmailSenderQueue
DomainQ              &EmailDomainQueue
HookQ                &EmailHookQueue
! ---- behaviour -----------------------------------------------------------
Language             BYTE                         ! ETLng:English / ETLng:Spanish
Silent               BYTE                         ! 1 = never pop a message box
PageSize             LONG                         ! rows per request; 0 = 100
MaxRows              LONG                         ! stop after this many; 0 = 5000
! ---- results -------------------------------------------------------------
LastError            LONG
LastErrorText        CSTRING(513)
LastStatus           LONG                         ! the HTTP status of the last call
LastUrl              CSTRING(513)                 ! the address it went to, for a support call
! ---- internals -----------------------------------------------------------
MapQ                 &EmailApiMapQueue,PRIVATE
UrlBuf               &EmailBufClass,PRIVATE       ! one buffer per value-returning method:
BodyBuf              &EmailBufClass,PRIVATE       !   they nest, so they cannot share one
HdrBuf               &EmailBufClass,PRIVATE
TxtBuf               &EmailBufClass,PRIVATE
ItemBase             CSTRING(129)                 ! the path of the item being mapped - public
                                                  !   because an override of MapItem needs it
TimeSink             TIME,PRIVATE                 ! somewhere for ItemWhen to put a time that
                                                  !   the queue it is filling has no column for

Construct            PROCEDURE
Destruct             PROCEDURE
Init                 PROCEDURE(EmailToClass pMailer)
! ---- what this provider can do -------------------------------------------
Supports             PROCEDURE(BYTE pOp,BYTE pKind=ETSup:All),BYTE
OpName               PROCEDURE(BYTE pOp),STRING
SuppKindName         PROCEDURE(BYTE pKind),STRING
SuppKindOf           PROCEDURE(STRING pText),BYTE  ! read a provider's own word for it
! ---- reading -------------------------------------------------------------
GetAccount           PROCEDURE(),BYTE,PROC
GetSuppressions      PROCEDURE(BYTE pKind=ETSup:All),LONG,PROC
GetStats             PROCEDURE(DATE pFrom,DATE pTo),LONG,PROC
GetEvents            PROCEDURE(DATE pFrom,DATE pTo),LONG,PROC
GetContacts          PROCEDURE(<STRING pListId>),LONG,PROC
GetLists             PROCEDURE(),LONG,PROC
GetCampaigns         PROCEDURE(),LONG,PROC
GetTemplates         PROCEDURE(),LONG,PROC
GetSenders           PROCEDURE(),LONG,PROC
GetDomains           PROCEDURE(),LONG,PROC
GetWebhooks          PROCEDURE(),LONG,PROC
! ---- changing ------------------------------------------------------------
DeleteSuppression    PROCEDURE(STRING pAddress,BYTE pKind),BYTE,PROC
DeleteAllSuppressions PROCEDURE(BYTE pKind),LONG,PROC
AddSuppression       PROCEDURE(STRING pAddress,BYTE pKind,<STRING pReason>),BYTE,PROC
AddContact           PROCEDURE(STRING pAddress,<STRING pName>,<STRING pListId>),BYTE,PROC
DeleteContact        PROCEDURE(STRING pIdOrAddress,<STRING pListId>),BYTE,PROC
AddList              PROCEDURE(STRING pName),BYTE,PROC
AddCampaign          PROCEDURE(STRING pName,STRING pSubject,STRING pHtml,STRING pListId),BYTE,PROC
SendCampaign         PROCEDURE(STRING pId),BYTE,PROC
AddWebhook           PROCEDURE(STRING pUrl,<STRING pEvents>),BYTE,PROC
DeleteWebhook        PROCEDURE(STRING pId),BYTE,PROC
! ---- using the answers ---------------------------------------------------
IsBlocked            PROCEDURE(STRING pAddress),BYTE   ! searches the loaded SuppQ
ExportSuppressions   PROCEDURE(STRING pFileName),LONG,PROC  ! CSV, for your own records
! ---- the escape hatch ----------------------------------------------------
!  Anything this class has no row for.  The key, the headers and the base
!  address are still handled for you; pPath may be a whole URL or just the
!  part after the host.
RawCall              PROCEDURE(STRING pVerb,STRING pPath,<STRING pBody>),LONG,PROC
! ---- windows -------------------------------------------------------------
Manage               PROCEDURE(BYTE pTab=0),BYTE,PROC
ShowError            PROCEDURE
! ---- helpers -------------------------------------------------------------
Txt                  PROCEDURE(LONG pId),STRING,VIRTUAL
SetErr               PROCEDURE(LONG pCode,<STRING pText>),BYTE,PROC
BuildMap             PROCEDURE(),VIRTUAL          ! override to add or correct a row
Row                  PROCEDURE(BYTE pProvider,BYTE pOp,BYTE pKind,STRING pVerb,STRING pUrl,|
                               <STRING pItemPath>,<STRING pMap>,<STRING pBody>,<STRING pNext>)
FindRow              PROCEDURE(BYTE pOp,BYTE pKind=ETSup:All),BYTE,PROC  ! leaves it in MapQ
ExactRow             PROCEDURE(BYTE pOp,BYTE pKind),BYTE,PROC  ! a row for THIS kind, not a
                                                  !   widened match
AuthHeaders          PROCEDURE(BYTE pOp),STRING   ! the static credential headers
! ---- signing, for the one provider that needs it -------------------------
!  Amazon does not take a key in a header: it wants the request signed. These
!  are public because they are worth having on their own - HMAC-SHA256 and a
!  SigV4 signing key are useful well beyond e-mail - and because every one of
!  them is checked against a published test vector.
SignedHeaders        PROCEDURE(BYTE pOp,STRING pVerb,STRING pUrl,STRING pBody),STRING
AwsKeyId             PROCEDURE(),STRING            ! ApiKey2, or UserName if that is blank
Expand               PROCEDURE(STRING pText),STRING
RfcDate              PROCEDURE(DATE pDate),STRING
Fetch                PROCEDURE(BYTE pOp,BYTE pKind),LONG,PROC
MapItem              PROCEDURE(BYTE pOp,BYTE pKind,STRING pMap),VIRTUAL
Perform              PROCEDURE(BYTE pOp,BYTE pKind),BYTE,PROC
MapText              PROCEDURE(STRING pMap,STRING pColumn),STRING
ItemVal              PROCEDURE(STRING pMap,STRING pColumn),STRING
ItemLong             PROCEDURE(STRING pMap,STRING pColumn),LONG
ItemBool             PROCEDURE(STRING pMap,STRING pColumn),BYTE
ItemWhen             PROCEDURE(STRING pMap,STRING pColumn,*DATE pDate,*TIME pTime)
UrlEncode            PROCEDURE(STRING pText),STRING
JsonStr              PROCEDURE(STRING pText),STRING
Csv                  PROCEDURE(STRING pText),STRING
FailedText           PROCEDURE(),STRING           ! what the provider said, trimmed for a message
! ---- the argument slots the placeholders read ----------------------------
!  Set by the public methods before they call Fetch / Perform.  Kept as
!  members rather than passed down so that every operation, whatever its
!  shape, goes through one Expand().
ArgId                CSTRING(129)
ArgEmail             CSTRING(256)
ArgText              CSTRING(513)
ArgSubject           CSTRING(257)
ArgHtml              &STRING
ArgFrom              DATE
ArgTo                DATE
ArgOffset            LONG
ArgToken             CSTRING(513)                 ! the continuation token, for a provider
                                                  !   that pages with one instead of a URL
                   END

  _EndOfInclude_
