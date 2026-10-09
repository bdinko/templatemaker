!ABCIncludeFile(EMAILTO)
! ============================================================================
!  EmailMsgClass - the message, and the MIME document it turns into.
!
!  PURE CLARION.  Nothing in this file touches a socket, a DLL or the C module:
!  it builds the RFC 5322 / RFC 2045 text of an e-mail and hands it over.  That
!  is exactly why every transport can share it - SMTP DATA, the Gmail API and
!  Microsoft Graph all want the same bytes.
!
!  WHAT IT PRODUCES
!    plain text only ............ text/plain
!    HTML only .................. text/html
!    both ....................... multipart/alternative
!    both + an inline image ..... multipart/related( alternative, image )
!    any file attachment ........ multipart/mixed( the above, attachments )
!  It picks the smallest structure that carries what you gave it, so a plain
!  note does not arrive as a four-part MIME tree.
!
!  ACCENTS.  A Clarion STRING holds ANSI bytes (Windows-1252).  Left alone,
!  "Direccion" is fine and "Direccion" with an accent arrives as mojibake.  So
!  by default the class transcodes the subject, the bodies and the file names
!  to UTF-8 and labels them as such - set CharSet to ETChs:Ansi to send the raw
!  bytes labelled windows-1252 instead.
!
!  USAGE
!      Msg.ClearAll()
!      Msg.SetFrom('sales@acme.com','Acme Sales')
!      Msg.AddTo('customer@example.com')
!      Msg.SetSubject('Your invoice')
!      Msg.SetText('The invoice is attached.')
!      Msg.SetHtml('<p>The invoice is <b>attached</b>.</p>')
!      Msg.Attach('C:\invoices\INV-1042.pdf')
!      Mailer.Send(Msg)
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

  OMIT('_EndOfInclude_',_EmailMsgClassPresent_)
_EmailMsgClassPresent_ EQUATE(1)

! ---- recipient kinds -------------------------------------------------------
ETAddr:To            EQUATE(1)
ETAddr:Cc            EQUATE(2)
ETAddr:Bcc           EQUATE(3)

! ---- character set handling ------------------------------------------------
ETChs:Utf8           EQUATE(1)                        ! transcode from Windows-1252 (default)
ETChs:Ansi           EQUATE(2)                        ! send the bytes as they are, labelled windows-1252

! ---- priority --------------------------------------------------------------
ETPri:Normal         EQUATE(0)
ETPri:High           EQUATE(1)
ETPri:Low            EQUATE(2)

! ---- errors ----------------------------------------------------------------
ETMsg:Ok             EQUATE(0)
ETMsg:NoFrom         EQUATE(-101)
ETMsg:NoRecipient    EQUATE(-102)
ETMsg:NoBody         EQUATE(-103)
ETMsg:AttachMissing  EQUATE(-104)
ETMsg:AttachRead     EQUATE(-105)
ETMsg:TooBig         EQUATE(-106)

EmailAddrQueue     QUEUE,TYPE
Kind                 BYTE                           ! ETAddr:To / ETAddr:Cc / ETAddr:Bcc
Address              CSTRING(256)
DisplayName          CSTRING(129)
                   END

EmailAttachQueue   QUEUE,TYPE
FileName             CSTRING(261)                   ! full path; empty when Data is used
ShownAs              CSTRING(161)                   ! the name the recipient sees
ContentType          CSTRING(101)                   ! guessed from the extension if left empty
ContentId            CSTRING(101)                   ! set = inline, referenced as <img src="cid:...">
Data                 &STRING                        ! in-memory content; NULL when FileName is used
DataLen              LONG
                   END

EmailHeaderQueue   QUEUE,TYPE
HName                CSTRING(65)
HValue               CSTRING(513)
                   END

! ============================================================================
!  EmailBufClass - a growing byte buffer.
!
!  Building a MIME document means appending thousands of small pieces to
!  something that ends up megabytes long.  Clarion has no string builder, and
!  "s = s & more" in a loop is quadratic - a 4 MB attachment would take
!  minutes.  This doubles its capacity instead, so building is linear.
! ============================================================================
EmailBufClass      CLASS,TYPE,MODULE('EmailMsgClass.CLW'),LINK('EmailMsgClass.CLW',_emailToLinkMode_),DLL(_emailToDllMode_)
Buf                  &STRING
Len                  LONG
Cap                  LONG

Construct            PROCEDURE
Destruct             PROCEDURE
Need                 PROCEDURE(LONG pExtra)         ! make room for pExtra more bytes
Add                  PROCEDURE(STRING pData)
AddLen               PROCEDURE(*STRING pData,LONG pLen)
AddLine              PROCEDURE(STRING pLine)        ! pLine + CRLF
!  NOT called Clear: a class member whose label matches a Clarion intrinsic
!  redefines that intrinsic for EVERY module that includes this file, and
!  the next CLEAR(SomeVariable) anywhere in the application stops compiling
!  with "No matching prototype available".  Same trap as BEGIN and RESET.
ClearAll             PROCEDURE
Value                PROCEDURE(),STRING             ! the lot, as a STRING
                   END

! ============================================================================
!  EmailMsgClass
! ============================================================================
EmailMsgClass      CLASS,TYPE,MODULE('EmailMsgClass.CLW'),LINK('EmailMsgClass.CLW',_emailToLinkMode_),DLL(_emailToDllMode_)
! ---- the envelope --------------------------------------------------------
FromAddr             CSTRING(256)
FromName             CSTRING(129)
ReplyTo              CSTRING(256)
Subject              CSTRING(1025)
Priority             BYTE
CharSet              BYTE                           ! ETChs:Utf8 (default) or ETChs:Ansi
ReadReceipt          BYTE                           ! 1 = ask for a read receipt
BccInHeaders         BYTE                           ! 1 = write a Bcc: header into the MIME.
                                                    !   OFF for SMTP, where Bcc recipients reach
                                                    !   the server as extra RCPT TO commands and
                                                    !   a header would show them to everybody.
                                                    !   ON for the Gmail API and Graph, which
                                                    !   take the recipients FROM the headers -
                                                    !   there is no envelope to put them in - and
                                                    !   strip the Bcc line before delivering.
                                                    !   EmailToClass sets it per transport.
MessageId            CSTRING(129)                   ! generated if left empty
OwnMessageId         BYTE                           ! 1 = write our own Message-ID (the default,
                                                    !   and what SMTP wants - plenty of servers
                                                    !   do not add one).  0 = leave it out and
                                                    !   let the provider assign it, which is what
                                                    !   the Gmail API and Graph do anyway: they
                                                    !   discard ours.  Minting an id in a domain
                                                    !   you do not own - <...@gmail.com> when you
                                                    !   are not Google - is a thing a receiving
                                                    !   server is entitled to distrust.
                                                    !   EmailToClass sets it per transport.
TzMinutes            LONG                           ! minutes east of UTC for the Date: header
! ---- the parts -----------------------------------------------------------
AddrQ                &EmailAddrQueue
AttachQ              &EmailAttachQueue
HeaderQ              &EmailHeaderQueue
TextBody             &EmailBufClass
HtmlBody             &EmailBufClass
Mime                 &EmailBufClass                 ! what Build() produced
! ---- one working buffer per value-returning encoder ----------------------
!  A Clarion method returning a STRING cannot free the buffer it built the
!  answer in, so the buffer has to outlive the RETURN and belong to the object.
!  Each encoder gets its OWN buffer rather than sharing one, because they nest:
!  QuotedPrintable(Utf8(x)) is evaluated with the inner result still live, and
!  EncodeHeader calls Base64 while its own answer is half-built.  One shared
!  scratch would corrupt the message it is in the middle of writing.
EncBuf               &EmailBufClass,PRIVATE
DecBuf               &EmailBufClass,PRIVATE
QpBuf                &EmailBufClass,PRIVATE
U8Buf                &EmailBufClass,PRIVATE
HdrBuf               &EmailBufClass,PRIVATE
JsnBuf               &EmailBufClass,PRIVATE
ListBuf              &EmailBufClass,PRIVATE
! ---- diagnostics ---------------------------------------------------------
LastError            LONG
LastErrorText        CSTRING(257)
MaxSize              LONG                           ! refuse to build past this (0 = no limit)

Construct            PROCEDURE
Destruct             PROCEDURE
ClearAll             PROCEDURE
! ---- composing -----------------------------------------------------------
SetFrom              PROCEDURE(STRING pAddress,<STRING pName>)
SetSubject           PROCEDURE(STRING pSubject)
AddTo                PROCEDURE(STRING pAddress,<STRING pName>)
AddCc                PROCEDURE(STRING pAddress,<STRING pName>)
AddBcc               PROCEDURE(STRING pAddress,<STRING pName>)
AddList              PROCEDURE(STRING pAddresses,BYTE pKind=ETAddr:To),LONG,PROC
SetText              PROCEDURE(STRING pText)
AddText              PROCEDURE(STRING pText)
SetHtml              PROCEDURE(STRING pHtml)
AddHtml              PROCEDURE(STRING pHtml)
Attach               PROCEDURE(STRING pFileName,<STRING pShownAs>,<STRING pContentType>),BYTE,PROC
AttachData           PROCEDURE(STRING pShownAs,STRING pData,<STRING pContentType>),BYTE,PROC
AttachInline         PROCEDURE(STRING pFileName,STRING pContentId,<STRING pContentType>),BYTE,PROC
AddHeader            PROCEDURE(STRING pName,STRING pValue)
! ---- producing -----------------------------------------------------------
Validate             PROCEDURE(),BYTE,PROC          ! 1 = ready to send
Build                PROCEDURE(),LONG,PROC          ! returns the MIME length, <0 on error
RecipientList        PROCEDURE(BYTE pKind),STRING   ! "a@b.com, c@d.com" for a header
EnvelopeCount        PROCEDURE(),LONG               ! every To + Cc + Bcc, for RCPT TO
EnvelopeAddr         PROCEDURE(LONG pIndex),STRING
! ---- encoders (public: they are useful on their own) ---------------------
Base64               PROCEDURE(STRING pRaw),STRING
Base64Len            PROCEDURE(*STRING pRaw,LONG pLen,EmailBufClass pOut)
Base64Decode         PROCEDURE(STRING pB64),STRING
Base64Url            PROCEDURE(STRING pRaw),STRING  ! RFC 4648 s5: -_ and no padding
QuotedPrintable      PROCEDURE(STRING pText),STRING
Utf8                 PROCEDURE(STRING pAnsi),STRING ! Windows-1252 -> UTF-8
EncodeHeader         PROCEDURE(STRING pText),STRING ! RFC 2047, only if it needs it
NeedsEncoding        PROCEDURE(STRING pText),BYTE   ! header rules: any control char counts
BodyNeedsQp          PROCEDURE(EmailBufClass pBody),BYTE
Boundary             PROCEDURE(),STRING
DateHeader           PROCEDURE(),STRING
GuessType            PROCEDURE(STRING pFileName),STRING
JsonString           PROCEDURE(STRING pText),STRING ! escaped and quoted, for the REST transports
! ---- internals -----------------------------------------------------------
SetErr               PROCEDURE(LONG pCode,<STRING pText>),LONG,PROC
LoadFile             PROCEDURE(STRING pFileName,EmailBufClass pOut),BYTE,PROC
AddAddress           PROCEDURE(BYTE pKind,STRING pAddress,<STRING pName>),PRIVATE
WriteBodyPart        PROCEDURE(EmailBufClass pOut,STRING pContentType,EmailBufClass pBody),PRIVATE
WriteAttachment      PROCEDURE(EmailBufClass pOut,LONG pIndex),PRIVATE
                   END

  _EndOfInclude_
