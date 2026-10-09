!ABCIncludeFile(EMAILTO)
! ============================================================================
!  EmailNetClass - the transport primitives for emailTo.
!
!  A thin, honest wrapper over emailc.c.  It owns exactly the four things
!  Clarion cannot do for itself:
!
!      * a TCP connection, optionally wrapped in TLS (SCHANNEL)
!      * an HTTPS request               (WinHTTP)
!      * the OAuth2 loopback redirect   (a one-shot local listener)
!      * DPAPI, SHA-256 and secure random
!
!  Nothing above this line knows about e-mail: SMTP, MIME and OAuth are built
!  on top of it in pure Clarion.  That split is deliberate - it is the whole
!  reason emailTo needs no third-party DLL, no .NET and no OpenSSL.
!
!  TYPICAL USE (EmailToClass does this for you):
!      IF Net.Open('smtp.gmail.com', 587)
!         Line = Net.RecvLine()                    ! 220 smtp.gmail.com ESMTP
!         Net.SendLine('EHLO localhost')
!         ...
!         Net.SendLine('STARTTLS')
!         Line = Net.RecvLine()                    ! 220 2.0.0 Ready to start TLS
!         Net.StartTls('smtp.gmail.com')           ! everything after is encrypted
!      END
!
!  ERRORS.  Every method sets SELF.LastError (one of the ETNet: equates below,
!  0 = success) and SELF.LastErrorText.  When Windows itself refused - a failed
!  TLS handshake, a refused connection - SELF.LastWinError carries the SSPI or
!  Winsock code so a support call can be diagnosed from the two numbers.
!
!  HAND-CODED PROJECTS.  The emailTo templates write the project defines
!  _emailToLinkMode_ and _emailToDllMode_ for you.  Without the template you
!  must add them yourself (Project > Properties > Defines):
!       _emailToLinkMode_=>1;_emailToDllMode_=>0
!  Omitting them links the class as an import and faults in the constructor.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

  OMIT('_EndOfInclude_',_EmailNetClassPresent_)
_EmailNetClassPresent_ EQUATE(1)

! ---- error codes, mirroring emailc.c ---------------------------------------
ETNet:Ok             EQUATE(0)
ETNet:NoWinsock      EQUATE(-1)
ETNet:NoSchannel     EQUATE(-2)
ETNet:NoWinHttp      EQUATE(-3)
ETNet:Resolve        EQUATE(-4)
ETNet:Connect        EQUATE(-5)
ETNet:NoSlot         EQUATE(-6)
ETNet:BadId          EQUATE(-7)
ETNet:SendFail       EQUATE(-8)
ETNet:RecvFail       EQUATE(-9)
ETNet:Closed         EQUATE(-10)
ETNet:Timeout        EQUATE(-11)
ETNet:Cred           EQUATE(-12)
ETNet:Handshake      EQUATE(-13)
ETNet:StreamSizes    EQUATE(-14)
ETNet:Encrypt        EQUATE(-15)
ETNet:Decrypt        EQUATE(-16)
ETNet:Memory         EQUATE(-17)
ETNet:Overflow       EQUATE(-18)
ETNet:BadUrl         EQUATE(-19)
ETNet:HttpOpen       EQUATE(-20)
ETNet:HttpConnect    EQUATE(-21)
ETNet:HttpRequest    EQUATE(-22)
ETNet:HttpSend       EQUATE(-23)
ETNet:HttpRecv       EQUATE(-24)
ETNet:Bind           EQUATE(-25)
ETNet:Accept         EQUATE(-26)
ETNet:NoCrypt32      EQUATE(-27)
ETNet:Dpapi          EQUATE(-28)
ETNet:NotTls         EQUATE(-29)
ETNet:AlreadyTls     EQUATE(-30)

ETNet:MaxLine        EQUATE(4096)                    ! longest protocol line we will read

! The conversation transcript, ready to drop straight into a LIST control.
EmailTraceQueue    QUEUE,TYPE
Line                 STRING(512)
                   END

EmailNetClass      CLASS,TYPE,MODULE('EmailNetClass.CLW'),LINK('EmailNetClass.CLW',_emailToLinkMode_),DLL(_emailToDllMode_)
! ---- state ---------------------------------------------------------------
Conn                 LONG                          ! open connection id, 0 = closed
Secure               BYTE                          ! 1 once TLS is active on Conn
LastError            LONG                          ! a ETNet: code; 0 = success
LastWinError         LONG                          ! the SSPI / Winsock code behind it
LastErrorText        CSTRING(161)
! ---- configuration -------------------------------------------------------
Timeout              LONG                          ! milliseconds; default 30000
VerifyCert           BYTE                          ! 1 = validate the server certificate (default)
Trace                BYTE                          ! 1 = record the conversation in TraceQ
HidePasswords        BYTE                          ! 1 = mask credentials in the trace (default)
! ---- the last HTTP response ----------------------------------------------
Response             &STRING                       ! body of the last Http() call
RespLen              LONG
RespCap              LONG                          ! PRIVATE in spirit; grows as needed
Status               LONG                          ! HTTP status code of the last Http() call
BinLen               LONG                          ! length of the binary value the last Sha256 /
                                                   !   RandomBytes / Protect / Unprotect returned
                                                   !   (a returned STRING gets space-padded on
                                                   !    assignment, so binary needs its length)
! ---- the transcript ------------------------------------------------------
TraceQ               &EmailTraceQueue
! ---- a class-owned working buffer ----------------------------------------
!  A Clarion method that returns a STRING cannot free the buffer it built the
!  answer in - the copy happens at the RETURN.  So the buffer belongs to the
!  object: every value-returning method below builds into Scratch, and the
!  NEXT call (or Destruct) releases it.  One buffer, no leak, no guesswork.
Scratch              &STRING,PRIVATE
ScratchCap           LONG,PRIVATE
SgnBuf               &EmailBufClass,PRIVATE        ! one buffer per value-returning method:
HexBuf               &EmailBufClass,PRIVATE        !   they nest, so they cannot share one

Construct            PROCEDURE
Destruct             PROCEDURE
! ---- socket conversation -------------------------------------------------
Open                 PROCEDURE(STRING pHost,LONG pPort,BYTE pTls=0),BYTE,PROC
StartTls             PROCEDURE(STRING pHost),BYTE,PROC
Send                 PROCEDURE(STRING pData),BYTE,PROC
SendLine             PROCEDURE(STRING pLine,BYTE pSecret=0),BYTE,PROC
RecvLine             PROCEDURE(),STRING
Close                PROCEDURE
IsOpen               PROCEDURE(),BYTE
! ---- HTTPS ---------------------------------------------------------------
Http                 PROCEDURE(STRING pVerb,STRING pUrl,STRING pHeaders,STRING pBody),LONG,PROC
Body                 PROCEDURE(),STRING            ! the last response body
! ---- OAuth2 plumbing -----------------------------------------------------
OAuthListen          PROCEDURE(LONG pPort,*LONG pActualPort),LONG
OAuthWait            PROCEDURE(LONG pId,LONG pSeconds,STRING pReplyHtml),STRING
OAuthStop            PROCEDURE(LONG pId)
OpenUrl              PROCEDURE(STRING pUrl),BYTE,PROC
! ---- signing (AWS Signature Version 4) -----------------------------------
!  Amazon is the only service here that signs a request rather than taking a
!  key in a header. These sit at this level because SHA-256 does, and because
!  a signature is a pure function of the request and the credentials - the
!  sender and the management API call the same one. Every piece is checked
!  against a vector the RFC or Amazon publishes.
SignAws              PROCEDURE(STRING pVerb,STRING pUrl,STRING pBody,STRING pKeyId,|
                               STRING pSecret,STRING pRegion,STRING pService),STRING
Hmac256              PROCEDURE(STRING pKey,STRING pData),STRING  ! 32 raw bytes
HexOf                PROCEDURE(STRING pRaw),STRING               ! lower case, no spaces
Sha256Hex            PROCEDURE(STRING pData),STRING
SigningKey           PROCEDURE(STRING pSecret,STRING pDate,STRING pRegion,|
                               STRING pService),STRING           ! 32 raw bytes
AmzStamp             PROCEDURE(),STRING            ! 'YYYYMMDDTHHMMSSZ', in UTC
CanonPath            PROCEDURE(STRING pPath),STRING  ! each segment encoded once more
CanonQuery           PROCEDURE(STRING pQuery),STRING ! sorted by name, as SigV4 wants
! ---- crypto helpers ------------------------------------------------------
Sha256               PROCEDURE(STRING pData),STRING          ! 32 raw bytes
RandomBytes          PROCEDURE(LONG pLen),STRING
Protect              PROCEDURE(STRING pData),STRING          ! DPAPI, this Windows user
Unprotect            PROCEDURE(STRING pData),STRING
! ---- diagnostics ---------------------------------------------------------
SetErr               PROCEDURE(LONG pCode),LONG,PROC
AddTrace             PROCEDURE(STRING pLine)
ClearTrace           PROCEDURE
TraceText            PROCEDURE(),STRING            ! the whole transcript, CRLF separated
NeedScratch          PROCEDURE(LONG pBytes),PRIVATE
                   END

  _EndOfInclude_
