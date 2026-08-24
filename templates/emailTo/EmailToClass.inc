!ABCIncludeFile(EMAILTO)
! ============================================================================
!  EmailToClass - the sender, and EmailOAuthClass - the sign-in.
!
!  This is the layer an application actually talks to.  It owns an ACCOUNT
!  (where to send from and how to prove who you are) and knows four ways to
!  put a message on the wire:
!
!    ETTrn:Smtp      the classic conversation, over plain / STARTTLS / TLS,
!                    authenticating with LOGIN, PLAIN or OAuth2 (XOAUTH2).
!    ETTrn:GmailApi  https POST to gmail.googleapis.com - no SMTP at all.
!    ETTrn:GraphApi  https POST to graph.microsoft.com - the only route many
!                    locked-down Microsoft 365 tenants still allow.
!    ETTrn:ApiKey    https POST to SendGrid / Mailgun / Resend / Brevo /
!                    Postmark / Mailjet / SparkPost / MailerSend with an API
!                    key.  No OAuth, no consent screen.  Those same providers
!                    also answer the MANAGEMENT questions - who is blocked and
!                    why, statistics, contacts, campaigns - through
!                    EmailApiClass, which shares this account.
!
!  All four send the SAME message: EmailMsgClass builds the MIME once and each
!  transport delivers those bytes its own way.
!
!  WHERE THE SETTINGS LIVE.  LoadAccount and SaveAccount are VIRTUAL.  Out of
!  the box they read and write an INI file, which is enough for a demo and for
!  a single-user program.  The emailTo template overrides them to read and
!  write a TABLE you nominate, so accounts can live in your own data with your
!  own security - see the Settings Table tab of the global extension.
!
!  SECRETS AT REST.  Whatever store you use, the password and the OAuth refresh
!  token go through Seal() first: DPAPI encrypts them to the current Windows
!  user, then they are base64-ed so they survive a text column.  A stolen
!  settings row is useless on another machine or under another login.
!
!  USAGE
!      Mailer.Init()                             ! or Mailer.Init('mail.ini')
!      Mailer.LoadAccount('default')
!      IF NOT Mailer.SendSimple('bob@acme.com','Hi','It works.')
!         MESSAGE(Mailer.LastErrorText)
!      END
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

  OMIT('_EndOfInclude_',_EmailToClassPresent_)
_EmailToClassPresent_ EQUATE(1)

  INCLUDE('EmailNetClass.INC'),ONCE
  INCLUDE('EmailMsgClass.INC'),ONCE

! ---- transports ------------------------------------------------------------
ETTrn:Smtp         EQUATE(1)
ETTrn:GmailApi     EQUATE(2)
ETTrn:GraphApi     EQUATE(3)
ETTrn:ApiKey       EQUATE(4)

! ---- providers -------------------------------------------------------------
ETPrv:Custom       EQUATE(0)                      ! you fill in host / port yourself
ETPrv:Gmail        EQUATE(1)
ETPrv:Outlook      EQUATE(2)                      ! outlook.com / hotmail.com / live.com
ETPrv:Office365    EQUATE(3)                      ! a Microsoft 365 work or school account
ETPrv:Yahoo        EQUATE(4)
ETPrv:ICloud       EQUATE(5)
ETPrv:Zoho         EQUATE(6)
ETPrv:AmazonSes    EQUATE(7)
ETPrv:SendGrid     EQUATE(8)
ETPrv:Mailgun      EQUATE(9)
ETPrv:Resend       EQUATE(10)
ETPrv:Brevo        EQUATE(11)
ETPrv:Postmark     EQUATE(12)
ETPrv:Mailjet      EQUATE(13)
ETPrv:SparkPost    EQUATE(14)
ETPrv:MailerSend   EQUATE(15)

! ---- connection security ---------------------------------------------------
ETSec:None         EQUATE(0)                      ! plain text, port 25 - a local relay only
ETSec:StartTls     EQUATE(1)                      ! connect plain, upgrade with STARTTLS (587)
ETSec:Tls          EQUATE(2)                      ! TLS from the first byte (465)

! ---- authentication --------------------------------------------------------
ETAuth:None        EQUATE(0)
ETAuth:Login       EQUATE(1)                      ! AUTH LOGIN  - user and password, base64
ETAuth:Plain       EQUATE(2)                      ! AUTH PLAIN  - one base64 blob
ETAuth:XOAuth2     EQUATE(3)                      ! AUTH XOAUTH2 - an OAuth2 access token

! ---- language --------------------------------------------------------------
ETLng:English      EQUATE(1)
ETLng:Spanish      EQUATE(2)

! ---- send errors -----------------------------------------------------------
ETSend:Ok          EQUATE(0)
ETSend:NoAccount   EQUATE(-201)
ETSend:Connect     EQUATE(-202)
ETSend:Greeting    EQUATE(-203)
ETSend:Ehlo        EQUATE(-204)
ETSend:StartTls    EQUATE(-205)
ETSend:Auth        EQUATE(-206)
ETSend:MailFrom    EQUATE(-207)
ETSend:RcptTo      EQUATE(-208)
ETSend:Data        EQUATE(-209)
ETSend:Body        EQUATE(-210)
ETSend:Build       EQUATE(-211)
ETSend:Token       EQUATE(-212)
ETSend:Api         EQUATE(-213)
ETSend:NoTransport EQUATE(-214)
ETSend:Cancelled   EQUATE(-215)
ETSend:NoOAuthApp  EQUATE(-216)
ETSend:Consent     EQUATE(-217)

! ---- Txt() string ids ------------------------------------------------------
ETTxt:Setup        EQUATE(1)
ETTxt:Account      EQUATE(2)
ETTxt:Provider     EQUATE(3)
ETTxt:Transport    EQUATE(4)
ETTxt:Server       EQUATE(5)
ETTxt:Port         EQUATE(6)
ETTxt:Security     EQUATE(7)
ETTxt:AuthMethod   EQUATE(8)
ETTxt:UserName     EQUATE(9)
ETTxt:Password     EQUATE(10)
ETTxt:FromAddress  EQUATE(11)
ETTxt:FromName     EQUATE(12)
ETTxt:ReplyTo      EQUATE(13)
ETTxt:ClientId     EQUATE(14)
ETTxt:ClientSecret EQUATE(15)
ETTxt:Tenant       EQUATE(16)
ETTxt:ApiKey       EQUATE(17)
ETTxt:SignIn       EQUATE(18)
ETTxt:SendTest     EQUATE(19)
ETTxt:Save         EQUATE(20)
ETTxt:Cancel       EQUATE(21)
ETTxt:Close        EQUATE(22)
ETTxt:Log          EQUATE(23)
ETTxt:Testing      EQUATE(24)
ETTxt:TestOk       EQUATE(25)
ETTxt:TestFailed   EQUATE(26)
ETTxt:Sending      EQUATE(27)
ETTxt:Sent         EQUATE(28)
ETTxt:SendFailed   EQUATE(29)
ETTxt:SignedIn     EQUATE(30)
ETTxt:SignInFailed EQUATE(31)
ETTxt:WaitBrowser  EQUATE(32)
ETTxt:To           EQUATE(33)
ETTxt:Cc           EQUATE(34)
ETTxt:Bcc          EQUATE(35)
ETTxt:Subject      EQUATE(36)
ETTxt:Message      EQUATE(37)
ETTxt:Attach       EQUATE(38)
ETTxt:Send         EQUATE(39)
ETTxt:Compose      EQUATE(40)
ETTxt:NeedTo       EQUATE(41)
ETTxt:NeedSubject  EQUATE(42)
ETTxt:TestSubject  EQUATE(43)
ETTxt:TestBody     EQUATE(44)
ETTxt:Connecting   EQUATE(45)
ETTxt:Authorising  EQUATE(46)
ETTxt:Building     EQUATE(47)
ETTxt:Remove       EQUATE(48)
ETTxt:AddFile      EQUATE(49)
ETTxt:BrowserNote  EQUATE(50)

! ============================================================================
!  The account.  This GROUP is the contract between the class and wherever you
!  keep your settings - the template maps a table column onto each field.
! ============================================================================
EmailAccountGroup  GROUP,TYPE
Name                 CSTRING(65)                  ! the label this account is stored under
Transport            BYTE                         ! ETTrn:...
Provider             BYTE                         ! ETPrv:...
Host                 CSTRING(129)
Port                 LONG
Security             BYTE                         ! ETSec:...
AuthMode             BYTE                         ! ETAuth:...
UserName             CSTRING(256)
Password             CSTRING(256)                 ! or the app password
FromAddr             CSTRING(256)
FromName             CSTRING(129)
ReplyTo              CSTRING(256)
ClientId             CSTRING(256)                 ! OAuth2: your registered application
ClientSecret         CSTRING(256)                 ! blank for a public / desktop client
TenantId             CSTRING(129)                 ! Microsoft: common, organizations or a GUID
Scope                CSTRING(513)
RefreshToken         CSTRING(2049)
AccessToken          CSTRING(4097)
TokenExpDate         DATE
TokenExpTime         TIME
ApiKey               CSTRING(513)
ApiKey2              CSTRING(513)                 ! the SECOND credential, where a provider has
                                                  !   one: Postmark's account token, which its
                                                  !   senders and domains endpoints want instead
                                                  !   of the server token
ApiDomain            CSTRING(129)                 ! Mailgun sending domain; MailerSend domain id
ApiRegion            CSTRING(33)                  ! 'eu' picks a provider's European endpoint
                                                  !   (Mailgun, SparkPost); otherwise blank
ApiBase              CSTRING(129)                 ! host, or host:port, that replaces the
                                                  !   provider's own - a private relay, a
                                                  !   regional endpoint, or a test double
Timeout              LONG                         ! milliseconds; 0 = 30000
VerifyCert           BYTE                         ! 1 = check the server certificate (default)
                   END

! ============================================================================
!  EmailOAuthClass - the OAuth2 authorisation-code flow with PKCE.
!
!  This is the modern desktop flow and the only one Google and Microsoft still
!  accept for a native application:
!    1. invent a random verifier, hash it (S256) into a challenge
!    2. open the system browser at the provider consent screen
!    3. listen on http://127.0.0.1:<free port>/ for the redirect back
!    4. swap the returned code + the verifier for an access and refresh token
!  No client secret is required (and Microsoft public clients must not send
!  one), so nothing that has to stay secret is ever compiled into the .EXE.
! ============================================================================
EmailOAuthClass    CLASS,TYPE,MODULE('EmailToClass.CLW'),LINK('EmailToClass.CLW',_emailToLinkMode_),DLL(_emailToDllMode_)
Net                  &EmailNetClass                ! borrowed from EmailToClass, not owned
Msg                  &EmailMsgClass                ! borrowed encoder object, not owned
LastError            LONG
LastErrorText        CSTRING(513)
AuthUrl              CSTRING(513)
TokenUrl             CSTRING(513)
LastAuthUrl          CSTRING(2049)                 ! the consent address actually opened -
                                                   !   paste it into a browser by hand when a
                                                   !   sign-in fails and the provider will say
                                                   !   exactly what it objects to

RedirectPort         LONG                          ! 0 = ask Windows for a free port
RedirectHost         CSTRING(65)                   ! blank = 127.0.0.1 for Google,
                                                   !   localhost for Microsoft.  It has to
                                                   !   match what you registered, and the
                                                   !   two providers document different
                                                   !   ones - the listener answers on both.
WaitSeconds          LONG                          ! how long to leave the browser open

Init                 PROCEDURE(EmailNetClass pNet,EmailMsgClass pMsg)
SetEndpoints         PROCEDURE(*EmailAccountGroup pAcc)
RedirectUri          PROCEDURE(*EmailAccountGroup pAcc,LONG pPort),STRING
BuildAuthUrl         PROCEDURE(*EmailAccountGroup pAcc,LONG pPort,STRING pChallenge,STRING pState),STRING
Authorize            PROCEDURE(*EmailAccountGroup pAcc),BYTE,PROC
Refresh              PROCEDURE(*EmailAccountGroup pAcc),BYTE,PROC
EnsureToken          PROCEDURE(*EmailAccountGroup pAcc),BYTE,PROC
DefaultScope         PROCEDURE(*EmailAccountGroup pAcc),STRING
XOAuth2Blob          PROCEDURE(STRING pUser,STRING pToken),STRING
JsonValue            PROCEDURE(STRING pJson,STRING pKey),STRING
UrlEncode            PROCEDURE(STRING pText),STRING
UrlDecode            PROCEDURE(STRING pText),STRING
QueryValue           PROCEDURE(STRING pQuery,STRING pKey),STRING
SetErr               PROCEDURE(LONG pCode,<STRING pText>),BYTE,PROC  ! records it AND answers
                                                   !   1 = worked / 0 = failed, so a method can end
                                                   !   with RETURN SELF.SetErr(...)
                   END

! ============================================================================
!  EmailToClass
! ============================================================================
EmailToClass       CLASS,TYPE,MODULE('EmailToClass.CLW'),LINK('EmailToClass.CLW',_emailToLinkMode_),DLL(_emailToDllMode_)
! ---- the account ---------------------------------------------------------
Acc                  LIKE(EmailAccountGroup)
! ---- the machinery -------------------------------------------------------
Net                  &EmailNetClass
OAuth                &EmailOAuthClass
Msg                  &EmailMsgClass                ! the class-owned message SendSimple uses
Enc                  &EmailMsgClass,PRIVATE        ! a SECOND message object, used only for its
                                                   !   encoders (base64, JSON, UTF-8).  Kept apart
                                                   !   from Msg so sealing a password cannot
                                                   !   disturb a message that is mid-send.
Stuffed              &EmailBufClass,PRIVATE        ! the dot-stuffed copy for SMTP DATA
! ---- behaviour -----------------------------------------------------------
Language             BYTE                          ! ETLng:English / ETLng:Spanish
Silent               BYTE                          ! 1 = never pop a message box
Trace                BYTE                          ! 1 = keep the conversation transcript
IniFile              CSTRING(261)                  ! default LoadAccount / SaveAccount store
IniSection           CSTRING(65)
! ---- results -------------------------------------------------------------
LastError            LONG
LastErrorText        CSTRING(513)
LastServerReply      CSTRING(513)                  ! the last thing the server actually said
Capabilities         CSTRING(1025)                 ! what EHLO reported

Construct            PROCEDURE
Destruct             PROCEDURE
Init                 PROCEDURE(<STRING pIniFile>)
! ---- account ------------------------------------------------------------
SetProvider          PROCEDURE(BYTE pProvider)
ProviderName         PROCEDURE(BYTE pProvider),STRING
LoadAccount          PROCEDURE(<STRING pName>),BYTE,PROC,VIRTUAL
SaveAccount          PROCEDURE(),BYTE,PROC,VIRTUAL
Seal                 PROCEDURE(STRING pClear),STRING
Unseal               PROCEDURE(STRING pStored),STRING
! ---- sending ------------------------------------------------------------
Send                 PROCEDURE(EmailMsgClass pMsg),BYTE,PROC
SendSimple           PROCEDURE(STRING pTo,STRING pSubject,STRING pBody,<STRING pAttach>),BYTE,PROC
TestAccount          PROCEDURE(),BYTE,PROC
SendSmtp             PROCEDURE(EmailMsgClass pMsg),BYTE,PROC,VIRTUAL
SendGmailApi         PROCEDURE(EmailMsgClass pMsg),BYTE,PROC,VIRTUAL
SendGraphApi         PROCEDURE(EmailMsgClass pMsg),BYTE,PROC,VIRTUAL
SendApiKey           PROCEDURE(EmailMsgClass pMsg),BYTE,PROC,VIRTUAL
Authorize            PROCEDURE(),BYTE,PROC
! ---- windows ------------------------------------------------------------
Setup                PROCEDURE(),BYTE,PROC
Compose              PROCEDURE(<STRING pTo>,<STRING pSubject>,<STRING pBody>,<STRING pAttach>),BYTE,PROC
ShowError            PROCEDURE
! ---- helpers ------------------------------------------------------------
Txt                  PROCEDURE(LONG pId),STRING,VIRTUAL
SetErr               PROCEDURE(LONG pCode,<STRING pText>),BYTE,PROC  ! records it AND answers
                                                   !   1 = worked / 0 = failed, so a method can end
                                                   !   with RETURN SELF.SetErr(...)
EhloDomain           PROCEDURE(),STRING
Expect               PROCEDURE(STRING pWanted),BYTE,PROC
SmtpCmd              PROCEDURE(STRING pCmd,STRING pWanted,BYTE pSecret=0),BYTE,PROC
DotStuff             PROCEDURE(EmailMsgClass pMsg)
JsonRecipients       PROCEDURE(EmailMsgClass pMsg,BYTE pKind,STRING pStyle),STRING
                   END

  _EndOfInclude_
