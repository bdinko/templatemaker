! ============================================================================
!  EmailToClass / EmailOAuthClass - implementation.  Pure Clarion.
!
!  Every byte that leaves this module goes through EmailNetClass, and every
!  byte of the message comes from EmailMsgClass.  Nothing here talks to C, to
!  a DLL or to the operating system except through those two.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  INCLUDE('EmailToClass.INC'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

  MAP                                             ! a MEMBER needs a MAP, even an
  END                                             !   empty one, to fold in BUILTINS.CLW

ET_Hex2       STRING('0123456789ABCDEF')

! The page the browser lands on once the provider has redirected back.  It is
! the last thing the user sees of the sign-in, so it says what happened and
! tells them they can close the tab.
ET_ConsentOk  STRING('<!doctype html><html><head><meta charset="utf-8">' & |
                     '<title>Signed in</title></head>' & |
                     '<body style="font-family:Segoe UI,Arial,sans-serif;background:#f4f6f8;' & |
                     'margin:0;display:flex;align-items:center;justify-content:center;height:100vh">' & |
                     '<div style="background:#fff;border:1px solid #d8dee4;border-radius:10px;' & |
                     'padding:36px 44px;text-align:center;box-shadow:0 2px 10px rgba(0,0,0,.06)">' & |
                     '<div style="font-size:40px;color:#1f7a3d">&#10004;</div>' & |
                     '<h2 style="margin:10px 0 6px;color:#1b2733">Signed in</h2>' & |
                     '<p style="margin:0;color:#5a6a78">You can close this tab and go back to ' & |
                     'the application.</p></div></body></html>')

! ============================================================================
!  EmailOAuthClass
! ============================================================================
EmailOAuthClass.Init PROCEDURE(EmailNetClass pNet,EmailMsgClass pMsg)
  CODE
  SELF.Net         &= pNet
  SELF.Msg         &= pMsg
  SELF.RedirectPort = 0                             ! let Windows pick a free one
  SELF.WaitSeconds  = 180

EmailOAuthClass.SetErr PROCEDURE(LONG pCode,<STRING pText>)
  CODE
  SELF.LastError = pCode
  IF OMITTED(pText)
    SELF.LastErrorText = ''
  ELSE
    SELF.LastErrorText = CLIP(pText)
  END
  RETURN CHOOSE(pCode = ETSend:Ok, 1, 0)

!  Google and Microsoft are the only two providers that use OAuth2 here; every
!  other one authenticates with a password or an API key.
EmailOAuthClass.SetEndpoints PROCEDURE(*EmailAccountGroup pAcc)
tenant CSTRING(129)
  CODE
  CASE pAcc.Provider
  OF ETPrv:Gmail
    SELF.AuthUrl  = 'https://accounts.google.com/o/oauth2/v2/auth'
    SELF.TokenUrl = 'https://oauth2.googleapis.com/token'
  OF ETPrv:Outlook OROF ETPrv:Office365
    tenant = CLIP(pAcc.TenantId)
    IF NOT tenant
      !  "common" accepts both a personal Microsoft account and a work one,
      !  which is what an application shipped to unknown customers needs.
      tenant = 'common'
    END
    SELF.AuthUrl  = 'https://login.microsoftonline.com/' & CLIP(tenant) & '/oauth2/v2.0/authorize'
    SELF.TokenUrl = 'https://login.microsoftonline.com/' & CLIP(tenant) & '/oauth2/v2.0/token'
  ELSE
    SELF.AuthUrl  = ''
    SELF.TokenUrl = ''
  END

!  The address the provider redirects back to.  It must match the redirect URI
!  registered with the provider EXACTLY, and the two of them document different
!  ones: Google's desktop guidance is the literal loopback address, while the
!  Azure portal offers "http://localhost" as its desktop preset.  So the host
!  follows the provider unless you have set RedirectHost yourself.
!
!  Either way the listener answers on both loopbacks - see et_oauth_listen.
EmailOAuthClass.RedirectUri PROCEDURE(*EmailAccountGroup pAcc,LONG pPort)
host CSTRING(65)
  CODE
  host = CLIP(SELF.RedirectHost)
  IF NOT host
    CASE pAcc.Provider
    OF ETPrv:Outlook OROF ETPrv:Office365
      host = 'localhost'
    ELSE
      host = '127.0.0.1'
    END
  END
  RETURN 'http://' & CLIP(host) & ':' & pPort

!  The consent-screen address.  Split out from Authorize so it can be built and
!  read without opening a browser - which is the only way to check it against
!  what the provider expects.
EmailOAuthClass.BuildAuthUrl PROCEDURE(*EmailAccountGroup pAcc,LONG pPort,STRING pChallenge,STRING pState)
url  &EmailBufClass
res  CSTRING(2049)
  CODE
  SELF.SetEndpoints(pAcc)
  IF NOT SELF.AuthUrl THEN RETURN ''.
  url &= NEW(EmailBufClass)
  url.Add(CLIP(SELF.AuthUrl))
  url.Add('?response_type=code')
  url.Add('&client_id=' & SELF.UrlEncode(pAcc.ClientId))
  url.Add('&redirect_uri=' & SELF.UrlEncode(SELF.RedirectUri(pAcc, pPort)))
  url.Add('&scope=' & SELF.UrlEncode(SELF.DefaultScope(pAcc)))
  url.Add('&state=' & SELF.UrlEncode(pState))
  url.Add('&code_challenge=' & CLIP(pChallenge))
  url.Add('&code_challenge_method=S256')
  CASE pAcc.Provider
  OF ETPrv:Gmail
    !  Google returns a refresh token only when BOTH of these are present, and
    !  only on the first consent unless prompt=consent forces it again.
    url.Add('&access_type=offline&prompt=consent')
    IF CLIP(pAcc.UserName)
      url.Add('&login_hint=' & SELF.UrlEncode(pAcc.UserName))
    END
  OF ETPrv:Outlook OROF ETPrv:Office365
    url.Add('&response_mode=query')
    IF CLIP(pAcc.UserName)
      url.Add('&login_hint=' & SELF.UrlEncode(pAcc.UserName))
    END
  END
  res = url.Value()
  DISPOSE(url)
  RETURN CLIP(res)

EmailOAuthClass.DefaultScope PROCEDURE(*EmailAccountGroup pAcc)
  CODE
  IF CLIP(pAcc.Scope) THEN RETURN CLIP(pAcc.Scope).
  CASE pAcc.Provider
  OF ETPrv:Gmail
    IF pAcc.Transport = ETTrn:GmailApi
      RETURN 'https://www.googleapis.com/auth/gmail.send'
    END
    RETURN 'https://mail.google.com/'
  OF ETPrv:Outlook OROF ETPrv:Office365
    IF pAcc.Transport = ETTrn:GraphApi
      RETURN 'offline_access openid profile https://graph.microsoft.com/Mail.Send'
    END
    RETURN 'offline_access openid profile https://outlook.office.com/SMTP.Send'
  END
  RETURN ''

EmailOAuthClass.UrlEncode PROCEDURE(STRING pText)
out  &EmailBufClass
i    LONG
n    LONG
b    LONG
esc  STRING(3)
res  CSTRING(4097)
  CODE
  n = LEN(CLIP(pText))
  IF n < 1 THEN RETURN ''.
  out &= NEW(EmailBufClass)
  LOOP i = 1 TO n
    b = VAL(pText[i])
    IF (b >= 48 AND b <= 57) OR (b >= 65 AND b <= 90) OR (b >= 97 AND b <= 122) OR |
       b = VAL('-') OR b = VAL('.') OR b = VAL('_') OR b = VAL('~')
      out.Add(pText[i])
    ELSE
      esc[1] = '%'
      esc[2] = ET_Hex2[BSHIFT(b, -4) + 1]
      esc[3] = ET_Hex2[BAND(b, 0Fh) + 1]
      out.Add(esc)
    END
  END
  res = out.Value()
  DISPOSE(out)
  RETURN CLIP(res)

EmailOAuthClass.UrlDecode PROCEDURE(STRING pText)
out  &EmailBufClass
i    LONG
n    LONG
hi   LONG
lo   LONG
res  CSTRING(4097)
  CODE
  n = LEN(CLIP(pText))
  IF n < 1 THEN RETURN ''.
  out &= NEW(EmailBufClass)
  i = 1
  LOOP WHILE i <= n
    IF pText[i] = '%' AND i + 2 <= n
      hi = INSTRING(UPPER(pText[i+1]), ET_Hex2, 1, 1) - 1
      lo = INSTRING(UPPER(pText[i+2]), ET_Hex2, 1, 1) - 1
      IF hi >= 0 AND lo >= 0
        out.Add(CHR(hi * 16 + lo))
        i += 3
        CYCLE
      END
    END
    IF pText[i] = '+'
      out.Add(' ')
    ELSE
      out.Add(pText[i])
    END
    i += 1
  END
  res = out.Value()
  DISPOSE(out)
  RETURN CLIP(res)

!  Pull one parameter out of "code=4/0Ab...&scope=...&state=xyz".
EmailOAuthClass.QueryValue PROCEDURE(STRING pQuery,STRING pKey)
i     LONG
n     LONG
start LONG
key   CSTRING(65)
  CODE
  n   = LEN(CLIP(pQuery))
  key = CLIP(pKey) & '='
  start = 1
  LOOP i = 1 TO n + 1
    IF i > n OR pQuery[i] = '&'
      IF i - start >= LEN(key)
        IF pQuery[start : start + LEN(key) - 1] = key
          RETURN SELF.UrlDecode(pQuery[start + LEN(key) : i - 1])
        END
      END
      start = i + 1
    END
  END
  RETURN ''

!  A deliberately small JSON reader: enough for a token endpoint response,
!  which is always a flat object of strings and numbers.  It is not a general
!  JSON parser and does not pretend to be one.
EmailOAuthClass.JsonValue PROCEDURE(STRING pJson,STRING pKey)
i     LONG
n     LONG
at    LONG
out   &EmailBufClass
res   CSTRING(4097)
esc   STRING(1)
  CODE
  n  = SIZE(pJson)
  at = INSTRING('"' & CLIP(pKey) & '"', pJson, 1, 1)
  IF NOT at THEN RETURN ''.
  i = at + LEN(CLIP(pKey)) + 2
  LOOP WHILE i <= n AND pJson[i] <> ':'
    i += 1
  END
  i += 1
  LOOP WHILE i <= n AND (pJson[i] = ' ' OR VAL(pJson[i]) = 9 OR VAL(pJson[i]) = 13 OR VAL(pJson[i]) = 10)
    i += 1
  END
  IF i > n THEN RETURN ''.

  out &= NEW(EmailBufClass)
  IF pJson[i] = '"'
    i += 1
    LOOP WHILE i <= n
      IF pJson[i] = '"' THEN BREAK.
      IF pJson[i] = '\' AND i < n
        i += 1
        esc = pJson[i]
        CASE esc
        OF 'n' ; out.Add('<10>')
        OF 'r' ; out.Add('<13>')
        OF 't' ; out.Add('<9>')
        OF 'b' ; out.Add('<8>')
        OF 'f' ; out.Add('<12>')
        OF 'u' ; i += 4                             ! a \uXXXX escape: skipped, not needed here
        ELSE   ; out.Add(esc)
        END
      ELSE
        out.Add(pJson[i])
      END
      i += 1
    END
  ELSE
    LOOP WHILE i <= n
      IF pJson[i] = ',' OR pJson[i] = '}' OR pJson[i] = ' ' OR |
         VAL(pJson[i]) = 13 OR VAL(pJson[i]) = 10
        BREAK
      END
      out.Add(pJson[i])
      i += 1
    END
  END
  res = out.Value()
  DISPOSE(out)
  RETURN CLIP(res)

!  The SASL XOAUTH2 initial response, exactly as Google and Microsoft define
!  it: user=<address>^Aauth=Bearer <token>^A^A, base64-encoded.
EmailOAuthClass.XOAuth2Blob PROCEDURE(STRING pUser,STRING pToken)
  CODE
  RETURN SELF.Msg.Base64('user=' & CLIP(pUser) & '<1>auth=Bearer ' & CLIP(pToken) & '<1><1>')

!  The full interactive flow.  Returns 1 when pAcc came back with a usable
!  access token (and, where the provider grants one, a refresh token).
EmailOAuthClass.Authorize PROCEDURE(*EmailAccountGroup pAcc)
verifier   CSTRING(129)
challenge  CSTRING(129)
state      CSTRING(65)
listenId   LONG
port       LONG
body       &EmailBufClass
query      CSTRING(4097)
code       CSTRING(2049)
status     LONG
  CODE
  SELF.SetEndpoints(pAcc)
  IF NOT SELF.AuthUrl
    RETURN SELF.SetErr(ETSend:NoOAuthApp, 'This provider does not use OAuth2 sign-in.')
  END
  IF NOT CLIP(pAcc.ClientId)
    RETURN SELF.SetErr(ETSend:NoOAuthApp, |
      'No OAuth Client ID. Register a Desktop application with the provider and put its Client ID here.')
  END

  !-- PKCE: a random verifier, and its SHA-256 as the challenge -------------
  verifier  = SELF.Msg.Base64Url(SELF.Net.RandomBytes(32))
  challenge = SELF.Msg.Base64Url(SELF.Net.Sha256(CLIP(verifier)))
  state     = SELF.Msg.Base64Url(SELF.Net.RandomBytes(12))

  !-- open the loopback listener BEFORE the browser, so no redirect is lost --
  listenId = SELF.Net.OAuthListen(SELF.RedirectPort, port)
  IF listenId < 0
    RETURN SELF.SetErr(ETSend:Consent, 'Cannot listen for the sign-in redirect: ' & |
                       CLIP(SELF.Net.LastErrorText))
  END

  SELF.LastAuthUrl = SELF.BuildAuthUrl(pAcc, port, challenge, state)
  SELF.Net.AddTrace('--- consent: ' & CLIP(SELF.LastAuthUrl))

  IF NOT SELF.Net.OpenUrl(SELF.LastAuthUrl)
    SELF.Net.OAuthStop(listenId)
    RETURN SELF.SetErr(ETSend:Consent, 'Could not open the browser for the sign-in page.')
  END

  query = SELF.Net.OAuthWait(listenId, SELF.WaitSeconds, ET_ConsentOk)
  SELF.Net.OAuthStop(listenId)
  IF NOT query
    RETURN SELF.SetErr(ETSend:Consent, 'The sign-in was not completed.')
  END
  IF SELF.QueryValue(query, 'error')
    RETURN SELF.SetErr(ETSend:Consent, 'The provider refused the sign-in: ' & |
                       SELF.QueryValue(query, 'error') & ' ' & |
                       SELF.QueryValue(query, 'error_description'))
  END
  IF SELF.QueryValue(query, 'state') <> CLIP(state)
    !  A mismatch means the redirect did not come from the request we made.
    RETURN SELF.SetErr(ETSend:Consent, 'The sign-in reply did not match the request.')
  END
  code = SELF.QueryValue(query, 'code')
  IF NOT code
    RETURN SELF.SetErr(ETSend:Consent, 'The provider did not return an authorisation code.')
  END

  !-- swap the code for tokens ----------------------------------------------
  body &= NEW(EmailBufClass)
  body.Add('grant_type=authorization_code')
  body.Add('&code=' & SELF.UrlEncode(code))
  body.Add('&redirect_uri=' & SELF.UrlEncode(SELF.RedirectUri(pAcc, port)))
  body.Add('&client_id=' & SELF.UrlEncode(pAcc.ClientId))
  body.Add('&code_verifier=' & CLIP(verifier))
  IF CLIP(pAcc.ClientSecret)
    !  Google desktop clients still carry one; Microsoft public clients must
    !  NOT send one, so it is only added when the account actually has it.
    body.Add('&client_secret=' & SELF.UrlEncode(pAcc.ClientSecret))
  END

  status = SELF.Net.Http('POST', SELF.TokenUrl, |
                         'Content-Type: application/x-www-form-urlencoded', body.Value())
  DISPOSE(body)
  IF status <> 200
    RETURN SELF.SetErr(ETSend:Token, 'The token request failed (HTTP ' & status & '): ' & |
                       SELF.JsonValue(SELF.Net.Body(), 'error_description') & |
                       SELF.JsonValue(SELF.Net.Body(), 'error'))
  END
  DO StoreTokens
  IF NOT CLIP(pAcc.AccessToken)
    RETURN SELF.SetErr(ETSend:Token, 'The provider returned no access token.')
  END
  RETURN SELF.SetErr(ETSend:Ok)

StoreTokens ROUTINE
  DATA
secs LONG
d    LONG
t    LONG
  CODE
  pAcc.AccessToken = SELF.JsonValue(SELF.Net.Body(), 'access_token')
  IF SELF.JsonValue(SELF.Net.Body(), 'refresh_token')
    pAcc.RefreshToken = SELF.JsonValue(SELF.Net.Body(), 'refresh_token')
  END
  secs = DEFORMAT(SELF.JsonValue(SELF.Net.Body(), 'expires_in'))
  IF secs < 60 THEN secs = 3600.
  secs -= 60                                        ! renew a minute early
  d = TODAY()
  t = CLOCK() + secs * 100
  LOOP WHILE t > 8640000
    t -= 8640000
    d += 1
  END
  pAcc.TokenExpDate = d
  pAcc.TokenExpTime = t

!  Swap the long-lived refresh token for a fresh access token.  No browser, no
!  user - this is what runs on every send after the first sign-in.
EmailOAuthClass.Refresh PROCEDURE(*EmailAccountGroup pAcc)
body   &EmailBufClass
status LONG
  CODE
  SELF.SetEndpoints(pAcc)
  IF NOT SELF.TokenUrl OR NOT CLIP(pAcc.RefreshToken)
    RETURN SELF.SetErr(ETSend:Token, 'There is no refresh token; sign in again.')
  END
  body &= NEW(EmailBufClass)
  body.Add('grant_type=refresh_token')
  body.Add('&refresh_token=' & SELF.UrlEncode(pAcc.RefreshToken))
  body.Add('&client_id=' & SELF.UrlEncode(pAcc.ClientId))
  IF CLIP(pAcc.ClientSecret)
    body.Add('&client_secret=' & SELF.UrlEncode(pAcc.ClientSecret))
  END
  IF CLIP(pAcc.Scope)
    body.Add('&scope=' & SELF.UrlEncode(pAcc.Scope))
  END
  status = SELF.Net.Http('POST', SELF.TokenUrl, |
                         'Content-Type: application/x-www-form-urlencoded', body.Value())
  DISPOSE(body)
  IF status <> 200
    RETURN SELF.SetErr(ETSend:Token, 'Could not refresh the sign-in (HTTP ' & status & '): ' & |
                       SELF.JsonValue(SELF.Net.Body(), 'error_description') & |
                       SELF.JsonValue(SELF.Net.Body(), 'error'))
  END
  DO StoreTokens2
  RETURN SELF.SetErr(ETSend:Ok)

StoreTokens2 ROUTINE
  DATA
secs LONG
d    LONG
t    LONG
  CODE
  pAcc.AccessToken = SELF.JsonValue(SELF.Net.Body(), 'access_token')
  IF SELF.JsonValue(SELF.Net.Body(), 'refresh_token')
    !  Microsoft rotates the refresh token on every use; Google does not.
    pAcc.RefreshToken = SELF.JsonValue(SELF.Net.Body(), 'refresh_token')
  END
  secs = DEFORMAT(SELF.JsonValue(SELF.Net.Body(), 'expires_in'))
  IF secs < 60 THEN secs = 3600.
  secs -= 60
  d = TODAY()
  t = CLOCK() + secs * 100
  LOOP WHILE t > 8640000
    t -= 8640000
    d += 1
  END
  pAcc.TokenExpDate = d
  pAcc.TokenExpTime = t

!  Make sure pAcc has a token that is good right now.  Refreshes silently if
!  it can; only asks the user to sign in when there is nothing to refresh.
EmailOAuthClass.EnsureToken PROCEDURE(*EmailAccountGroup pAcc)
  CODE
  IF CLIP(pAcc.AccessToken) AND pAcc.TokenExpDate
    IF TODAY() < pAcc.TokenExpDate OR |
       (TODAY() = pAcc.TokenExpDate AND CLOCK() < pAcc.TokenExpTime)
      RETURN SELF.SetErr(ETSend:Ok)                 ! still valid
    END
  END
  IF CLIP(pAcc.RefreshToken)
    IF SELF.Refresh(pAcc) THEN RETURN 1.
  END
  RETURN SELF.Authorize(pAcc)

! ============================================================================
!  EmailToClass - lifecycle
! ============================================================================
EmailToClass.Construct PROCEDURE
  CODE
  SELF.Net     &= NEW(EmailNetClass)
  SELF.Msg     &= NEW(EmailMsgClass)
  SELF.Enc     &= NEW(EmailMsgClass)
  SELF.OAuth   &= NEW(EmailOAuthClass)
  SELF.Stuffed &= NEW(EmailBufClass)
  SELF.OAuth.Init(SELF.Net, SELF.Enc)
  SELF.Language      = ETLng:English
  SELF.IniSection    = 'emailTo'
  SELF.Acc.Timeout   = 30000
  SELF.Acc.VerifyCert = 1
  SELF.Acc.Transport = ETTrn:Smtp

EmailToClass.Destruct PROCEDURE
  CODE
  IF NOT SELF.Net &= NULL
    SELF.Net.Close()
    DISPOSE(SELF.Net)
  END
  IF NOT SELF.Msg     &= NULL THEN DISPOSE(SELF.Msg).
  IF NOT SELF.Enc     &= NULL THEN DISPOSE(SELF.Enc).
  IF NOT SELF.OAuth   &= NULL THEN DISPOSE(SELF.OAuth).
  IF NOT SELF.Stuffed &= NULL THEN DISPOSE(SELF.Stuffed).

EmailToClass.Init PROCEDURE(<STRING pIniFile>)
  CODE
  IF OMITTED(pIniFile) OR NOT CLIP(pIniFile)
    !  Beside the .EXE, which is where a Clarion program expects its INI.
    SELF.IniFile = PATH() & '\emailTo.ini'
  ELSE
    SELF.IniFile = CLIP(pIniFile)
  END

EmailToClass.SetErr PROCEDURE(LONG pCode,<STRING pText>)
  CODE
  SELF.LastError = pCode
  IF OMITTED(pText)
    CASE pCode
    OF ETSend:Ok          ; SELF.LastErrorText = ''
    OF ETSend:NoAccount   ; SELF.LastErrorText = SELF.Txt(ETTxt:SendFailed)
    OF ETSend:NoTransport ; SELF.LastErrorText = 'No transport is configured for this account.'
    ELSE                  ; SELF.LastErrorText = 'emailTo error ' & pCode
    END
  ELSE
    SELF.LastErrorText = CLIP(pText)
  END
  RETURN CHOOSE(pCode = ETSend:Ok, 1, 0)

EmailToClass.ShowError PROCEDURE
  CODE
  IF SELF.Silent OR NOT SELF.LastError THEN RETURN.
  MESSAGE(CLIP(SELF.LastErrorText), SELF.Txt(ETTxt:SendFailed), ICON:Exclamation)

! ============================================================================
!  The account
! ============================================================================
EmailToClass.ProviderName PROCEDURE(BYTE pProvider)
  CODE
  CASE pProvider
  OF ETPrv:Gmail     ; RETURN 'Gmail'
  OF ETPrv:Outlook   ; RETURN 'Outlook.com / Hotmail'
  OF ETPrv:Office365 ; RETURN 'Microsoft 365'
  OF ETPrv:Yahoo     ; RETURN 'Yahoo Mail'
  OF ETPrv:ICloud    ; RETURN 'iCloud Mail'
  OF ETPrv:Zoho      ; RETURN 'Zoho Mail'
  OF ETPrv:AmazonSes ; RETURN 'Amazon SES'
  OF ETPrv:SendGrid  ; RETURN 'SendGrid'
  OF ETPrv:Mailgun   ; RETURN 'Mailgun'
  OF ETPrv:Resend    ; RETURN 'Resend'
  OF ETPrv:Brevo     ; RETURN 'Brevo'
  OF ETPrv:Postmark  ; RETURN 'Postmark'
  OF ETPrv:Mailjet   ; RETURN 'Mailjet'
  OF ETPrv:SparkPost ; RETURN 'SparkPost'
  OF ETPrv:MailerSend; RETURN 'MailerSend'
  END
  RETURN 'Other (SMTP)'

!  Fill in everything that is the same for everybody using this provider, so
!  the only things left to type are the address and the credential.
EmailToClass.SetProvider PROCEDURE(BYTE pProvider)
  CODE
  SELF.Acc.Provider = pProvider
  CASE pProvider
  OF ETPrv:Gmail
    SELF.Acc.Transport = ETTrn:Smtp
    SELF.Acc.Host      = 'smtp.gmail.com'
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    !  Either an App Password with AUTH LOGIN, or OAuth2.  LOGIN is the default
    !  because it needs no registered application; the Setup window offers the
    !  OAuth route for anyone who would rather not issue an app password.
    SELF.Acc.AuthMode  = ETAuth:Login
  OF ETPrv:Outlook
    SELF.Acc.Transport = ETTrn:Smtp
    SELF.Acc.Host      = 'smtp-mail.outlook.com'
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    !  Microsoft switched personal Outlook.com accounts off basic auth, so a
    !  password will simply be refused here - OAuth2 is the only way in.
    SELF.Acc.AuthMode  = ETAuth:XOAuth2
  OF ETPrv:Office365
    SELF.Acc.Transport = ETTrn:Smtp
    SELF.Acc.Host      = 'smtp.office365.com'
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:XOAuth2
    IF NOT CLIP(SELF.Acc.TenantId) THEN SELF.Acc.TenantId = 'common'.
  OF ETPrv:Yahoo
    SELF.Acc.Transport = ETTrn:Smtp
    SELF.Acc.Host      = 'smtp.mail.yahoo.com'
    SELF.Acc.Port      = 465
    SELF.Acc.Security  = ETSec:Tls
    SELF.Acc.AuthMode  = ETAuth:Login          ! an app password from Yahoo Account Security
  OF ETPrv:ICloud
    SELF.Acc.Transport = ETTrn:Smtp
    SELF.Acc.Host      = 'smtp.mail.me.com'
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:Login          ! an app-specific password from appleid.apple.com
  OF ETPrv:Zoho
    SELF.Acc.Transport = ETTrn:Smtp
    SELF.Acc.Host      = 'smtp.zoho.com'
    SELF.Acc.Port      = 465
    SELF.Acc.Security  = ETSec:Tls
    SELF.Acc.AuthMode  = ETAuth:Login
  OF ETPrv:AmazonSes
    SELF.Acc.Transport = ETTrn:Smtp
    IF NOT CLIP(SELF.Acc.Host)
      SELF.Acc.Host = 'email-smtp.us-east-1.amazonaws.com'
    END
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:Login          ! the SES SMTP user, not the AWS key
  OF ETPrv:SendGrid
    SELF.Acc.Transport = ETTrn:ApiKey
    SELF.Acc.Host      = 'smtp.sendgrid.net'   ! if you switch back to SMTP
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:Login
    SELF.Acc.UserName  = 'apikey'              ! SendGrid SMTP wants this literal user name
  OF ETPrv:Mailgun
    SELF.Acc.Transport = ETTrn:ApiKey
    SELF.Acc.Host      = 'smtp.mailgun.org'
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:Login
  OF ETPrv:Resend
    SELF.Acc.Transport = ETTrn:ApiKey
    SELF.Acc.Host      = 'smtp.resend.com'
    SELF.Acc.Port      = 465
    SELF.Acc.Security  = ETSec:Tls
    SELF.Acc.AuthMode  = ETAuth:Login
    SELF.Acc.UserName  = 'resend'
  OF ETPrv:Brevo
    SELF.Acc.Transport = ETTrn:ApiKey
    SELF.Acc.Host      = 'smtp-relay.brevo.com'
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:Login
  OF ETPrv:Postmark
    SELF.Acc.Transport = ETTrn:ApiKey
    SELF.Acc.Host      = 'smtp.postmarkapp.com'
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:Login
  OF ETPrv:Mailjet
    SELF.Acc.Transport = ETTrn:ApiKey
    SELF.Acc.Host      = 'in-v3.mailjet.com'
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:Login
  OF ETPrv:SparkPost
    SELF.Acc.Transport = ETTrn:ApiKey
    SELF.Acc.Host      = 'smtp.sparkpostmail.com'  ! if you switch back to SMTP
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:Login
    SELF.Acc.UserName  = 'SMTP_Injection'          ! SparkPost SMTP wants this literal user name
  OF ETPrv:MailerSend
    SELF.Acc.Transport = ETTrn:ApiKey
    SELF.Acc.Host      = 'smtp.mailersend.net'
    SELF.Acc.Port      = 587
    SELF.Acc.Security  = ETSec:StartTls
    SELF.Acc.AuthMode  = ETAuth:Login
  ELSE
    SELF.Acc.Transport = ETTrn:Smtp
    IF NOT SELF.Acc.Port THEN SELF.Acc.Port = 587.
    IF NOT SELF.Acc.Security THEN SELF.Acc.Security = ETSec:StartTls.
    IF NOT SELF.Acc.AuthMode THEN SELF.Acc.AuthMode = ETAuth:Login.
  END

!  DPAPI, then base64 so the result survives a text column or an INI line.
!  DPAPI produces BINARY, which contains NUL bytes - so it is never parked in
!  a CSTRING on the way through.  Protect() and Base64() are chained directly,
!  and each answers with a STRING of exactly the right length.
EmailToClass.Seal PROCEDURE(STRING pClear)
b64 CSTRING(3073)
  CODE
  IF NOT CLIP(pClear) THEN RETURN ''.
  b64 = SELF.Enc.Base64(SELF.Net.Protect(CLIP(pClear)))
  IF NOT b64
    !  No DPAPI on this machine.  Better to store it readable than to lose it,
    !  but the marker says so, so nobody mistakes it for encrypted.
    RETURN 'plain:' & CLIP(pClear)
  END
  RETURN 'dpapi:' & CLIP(b64)

EmailToClass.Unseal PROCEDURE(STRING pStored)
  CODE
  IF NOT CLIP(pStored) THEN RETURN ''.
  IF SUB(CLIP(pStored), 1, 6) = 'plain:'
    RETURN SUB(CLIP(pStored), 7, LEN(CLIP(pStored)) - 6)
  END
  IF SUB(CLIP(pStored), 1, 6) <> 'dpapi:'
    !  Not one of ours - somebody typed the password straight into the table.
    !  Take it at face value; that is almost certainly what they meant.
    RETURN CLIP(pStored)
  END
  RETURN SELF.Net.Unprotect(SELF.Enc.Base64Decode(SUB(CLIP(pStored), 7, LEN(CLIP(pStored)) - 6)))

!  The default store: an INI beside the .EXE.  The template REPLACES these two
!  with a derived class that reads and writes the table you nominate.
EmailToClass.LoadAccount PROCEDURE(<STRING pName>)
sec CSTRING(65)
  CODE
  IF NOT CLIP(SELF.IniFile) THEN SELF.Init().
  sec = SELF.IniSection
  IF NOT OMITTED(pName) AND CLIP(pName)
    SELF.Acc.Name = CLIP(pName)
    sec = SELF.IniSection & '_' & CLIP(pName)
  END
  SELF.Acc.Provider     = GETINI(sec, 'Provider',     0,  SELF.IniFile)
  SELF.Acc.Transport    = GETINI(sec, 'Transport',    ETTrn:Smtp, SELF.IniFile)
  SELF.Acc.Host         = GETINI(sec, 'Host',         '', SELF.IniFile)
  SELF.Acc.Port         = GETINI(sec, 'Port',         587, SELF.IniFile)
  SELF.Acc.Security     = GETINI(sec, 'Security',     ETSec:StartTls, SELF.IniFile)
  SELF.Acc.AuthMode     = GETINI(sec, 'AuthMode',     ETAuth:Login, SELF.IniFile)
  SELF.Acc.UserName     = GETINI(sec, 'UserName',     '', SELF.IniFile)
  SELF.Acc.Password     = SELF.Unseal(GETINI(sec, 'Password', '', SELF.IniFile))
  SELF.Acc.FromAddr     = GETINI(sec, 'FromAddr',     '', SELF.IniFile)
  SELF.Acc.FromName     = GETINI(sec, 'FromName',     '', SELF.IniFile)
  SELF.Acc.ReplyTo      = GETINI(sec, 'ReplyTo',      '', SELF.IniFile)
  SELF.Acc.ClientId     = GETINI(sec, 'ClientId',     '', SELF.IniFile)
  SELF.Acc.ClientSecret = SELF.Unseal(GETINI(sec, 'ClientSecret', '', SELF.IniFile))
  SELF.Acc.TenantId     = GETINI(sec, 'TenantId',     '', SELF.IniFile)
  SELF.Acc.Scope        = GETINI(sec, 'Scope',        '', SELF.IniFile)
  SELF.Acc.RefreshToken = SELF.Unseal(GETINI(sec, 'RefreshToken', '', SELF.IniFile))
  SELF.Acc.ApiKey       = SELF.Unseal(GETINI(sec, 'ApiKey',       '', SELF.IniFile))
  SELF.Acc.ApiKey2      = SELF.Unseal(GETINI(sec, 'ApiKey2',      '', SELF.IniFile))
  SELF.Acc.ApiDomain    = GETINI(sec, 'ApiDomain',    '', SELF.IniFile)
  SELF.Acc.ApiRegion    = GETINI(sec, 'ApiRegion',    '', SELF.IniFile)
  SELF.Acc.ApiBase      = GETINI(sec, 'ApiBase',      '', SELF.IniFile)
  SELF.Acc.Timeout      = GETINI(sec, 'Timeout',      30000, SELF.IniFile)
  SELF.Acc.VerifyCert   = GETINI(sec, 'VerifyCert',   1,  SELF.IniFile)
  !  The access token is deliberately NOT persisted: it is short-lived and the
  !  refresh token buys a new one in one round trip.
  SELF.Acc.AccessToken  = ''
  SELF.Acc.TokenExpDate = 0
  RETURN CHOOSE(CLIP(SELF.Acc.Host) <> '' OR CLIP(SELF.Acc.ApiKey) <> '', 1, 0)

EmailToClass.SaveAccount PROCEDURE()
sec CSTRING(65)
  CODE
  IF NOT CLIP(SELF.IniFile) THEN SELF.Init().
  sec = SELF.IniSection
  IF CLIP(SELF.Acc.Name)
    sec = SELF.IniSection & '_' & CLIP(SELF.Acc.Name)
  END
  PUTINI(sec, 'Provider',     SELF.Acc.Provider,  SELF.IniFile)
  PUTINI(sec, 'Transport',    SELF.Acc.Transport, SELF.IniFile)
  PUTINI(sec, 'Host',         CLIP(SELF.Acc.Host), SELF.IniFile)
  PUTINI(sec, 'Port',         SELF.Acc.Port,      SELF.IniFile)
  PUTINI(sec, 'Security',     SELF.Acc.Security,  SELF.IniFile)
  PUTINI(sec, 'AuthMode',     SELF.Acc.AuthMode,  SELF.IniFile)
  PUTINI(sec, 'UserName',     CLIP(SELF.Acc.UserName), SELF.IniFile)
  PUTINI(sec, 'Password',     SELF.Seal(SELF.Acc.Password), SELF.IniFile)
  PUTINI(sec, 'FromAddr',     CLIP(SELF.Acc.FromAddr), SELF.IniFile)
  PUTINI(sec, 'FromName',     CLIP(SELF.Acc.FromName), SELF.IniFile)
  PUTINI(sec, 'ReplyTo',      CLIP(SELF.Acc.ReplyTo),  SELF.IniFile)
  PUTINI(sec, 'ClientId',     CLIP(SELF.Acc.ClientId), SELF.IniFile)
  PUTINI(sec, 'ClientSecret', SELF.Seal(SELF.Acc.ClientSecret), SELF.IniFile)
  PUTINI(sec, 'TenantId',     CLIP(SELF.Acc.TenantId), SELF.IniFile)
  PUTINI(sec, 'Scope',        CLIP(SELF.Acc.Scope),    SELF.IniFile)
  PUTINI(sec, 'RefreshToken', SELF.Seal(SELF.Acc.RefreshToken), SELF.IniFile)
  PUTINI(sec, 'ApiKey',       SELF.Seal(SELF.Acc.ApiKey), SELF.IniFile)
  PUTINI(sec, 'ApiKey2',      SELF.Seal(SELF.Acc.ApiKey2), SELF.IniFile)
  PUTINI(sec, 'ApiDomain',    CLIP(SELF.Acc.ApiDomain), SELF.IniFile)
  PUTINI(sec, 'ApiRegion',    CLIP(SELF.Acc.ApiRegion), SELF.IniFile)
  PUTINI(sec, 'ApiBase',      CLIP(SELF.Acc.ApiBase),   SELF.IniFile)
  PUTINI(sec, 'Timeout',      SELF.Acc.Timeout,    SELF.IniFile)
  PUTINI(sec, 'VerifyCert',   SELF.Acc.VerifyCert, SELF.IniFile)
  RETURN 1

EmailToClass.Authorize PROCEDURE()
  CODE
  IF SELF.OAuth.Authorize(SELF.Acc)
    RETURN SELF.SetErr(ETSend:Ok)
  END
  RETURN SELF.SetErr(SELF.OAuth.LastError, SELF.OAuth.LastErrorText)

! ============================================================================
!  The SMTP conversation
! ============================================================================
!  The name we announce in EHLO.  Some servers reject "localhost", so the
!  domain of the sending address is used when there is one.
EmailToClass.EhloDomain PROCEDURE()
i LONG
n LONG
  CODE
  n = LEN(CLIP(SELF.Acc.FromAddr))
  LOOP i = 1 TO n
    IF SELF.Acc.FromAddr[i] = '@'
      RETURN SELF.Acc.FromAddr[i+1 : n]
    END
  END
  RETURN 'localhost'

!  Read one complete SMTP reply - which may be several lines, each with the
!  same code and a "-" in column 4 until the last one - and say whether its
!  code is in the list we were prepared for ("250" or "235,334").
EmailToClass.Expect PROCEDURE(STRING pWanted)
line CSTRING(ETNet:MaxLine)
code CSTRING(4)
  CODE
  LOOP
    line = SELF.Net.RecvLine()
    IF SELF.Net.LastError
      SELF.LastServerReply = ''
      SELF.SetErr(ETSend:Connect, CLIP(SELF.Net.LastErrorText))
      RETURN 0
    END
    SELF.LastServerReply = line
    IF LEN(CLIP(line)) < 4 THEN BREAK.
    IF line[4] <> '-' THEN BREAK.
    IF LEN(CLIP(SELF.Capabilities)) < 900 AND LEN(CLIP(line)) > 4
      SELF.Capabilities = CLIP(SELF.Capabilities) & ' ' & CLIP(line[5 : LEN(CLIP(line))])
    END
  END
  !  The LAST line of the reply carries a capability too, and it is the one
  !  that lists AUTH on several servers - so it is folded in as well.
  IF LEN(CLIP(SELF.Capabilities)) < 900 AND LEN(CLIP(line)) > 4
    SELF.Capabilities = CLIP(SELF.Capabilities) & ' ' & CLIP(line[5 : LEN(CLIP(line))])
  END
  code = SUB(CLIP(line), 1, 3)
  IF INSTRING(CLIP(code), CLIP(pWanted), 1, 1)
    RETURN 1
  END
  RETURN 0

EmailToClass.SmtpCmd PROCEDURE(STRING pCmd,STRING pWanted,BYTE pSecret=0)
  CODE
  IF NOT SELF.Net.SendLine(pCmd, pSecret)
    RETURN SELF.SetErr(ETSend:Connect, CLIP(SELF.Net.LastErrorText))
  END
  RETURN SELF.Expect(pWanted)

!  RFC 5321 transparency: a line of the message that starts with a full stop
!  must be sent with TWO, or the server would read it as the end of the data.
EmailToClass.DotStuff PROCEDURE(EmailMsgClass pMsg)
i      LONG
n      LONG
atBol  BYTE
  CODE
  SELF.Stuffed.ClearAll()
  n = pMsg.Mime.Len
  atBol = 1
  LOOP i = 1 TO n
    IF atBol AND pMsg.Mime.Buf[i] = '.'
      SELF.Stuffed.Add('.')
    END
    SELF.Stuffed.Add(pMsg.Mime.Buf[i])
    atBol = CHOOSE(VAL(pMsg.Mime.Buf[i]) = 10, 1, 0)
  END
  IF NOT atBol
    SELF.Stuffed.Add('<13,10>')                     ! the data must end on a line boundary
  END
  SELF.Stuffed.Add('.<13,10>')                      ! and then the lone full stop

EmailToClass.SendSmtp PROCEDURE(EmailMsgClass pMsg)
i     LONG
sent  LONG
chunk LONG
tls   BYTE
from  CSTRING(256)
auth  BYTE
  CODE
  IF pMsg.Mime.Len < 1
    IF pMsg.Build() < 0
      RETURN SELF.SetErr(ETSend:Build, CLIP(pMsg.LastErrorText))
    END
  END
  IF NOT CLIP(SELF.Acc.Host)
    RETURN SELF.SetErr(ETSend:NoAccount, 'No SMTP server is configured.')
  END

  SELF.Capabilities = ''
  SELF.Net.Trace      = SELF.Trace
  SELF.Net.VerifyCert = SELF.Acc.VerifyCert
  IF SELF.Acc.Timeout > 0 THEN SELF.Net.Timeout = SELF.Acc.Timeout.
  tls = CHOOSE(SELF.Acc.Security = ETSec:Tls, 1, 0)

  IF NOT SELF.Net.Open(SELF.Acc.Host, SELF.Acc.Port, tls)
    RETURN SELF.SetErr(ETSend:Connect, CLIP(SELF.Net.LastErrorText) & |
                       CHOOSE(SELF.Net.LastWinError = 0, '', ' (Windows ' & SELF.Net.LastWinError & ')'))
  END

  IF NOT SELF.Expect('220')
    DO Bye
    RETURN SELF.SetErr(ETSend:Greeting, 'The server did not greet us: ' & CLIP(SELF.LastServerReply))
  END
  IF NOT SELF.SmtpCmd('EHLO ' & SELF.EhloDomain(), '250')
    DO Bye
    RETURN SELF.SetErr(ETSend:Ehlo, 'EHLO was refused: ' & CLIP(SELF.LastServerReply))
  END

  IF SELF.Acc.Security = ETSec:StartTls
    IF NOT SELF.SmtpCmd('STARTTLS', '220')
      DO Bye
      RETURN SELF.SetErr(ETSend:StartTls, 'The server would not start TLS: ' & CLIP(SELF.LastServerReply))
    END
    IF NOT SELF.Net.StartTls(SELF.Acc.Host)
      DO Bye
      RETURN SELF.SetErr(ETSend:StartTls, 'The TLS handshake failed: ' & CLIP(SELF.Net.LastErrorText) & |
                         CHOOSE(SELF.Net.LastWinError = 0, '', ' (Windows ' & SELF.Net.LastWinError & ')'))
    END
    SELF.Capabilities = ''
    IF NOT SELF.SmtpCmd('EHLO ' & SELF.EhloDomain(), '250')
      DO Bye
      RETURN SELF.SetErr(ETSend:Ehlo, 'EHLO after STARTTLS was refused: ' & CLIP(SELF.LastServerReply))
    END
  END

  !-- authenticate ----------------------------------------------------------
  auth = SELF.Acc.AuthMode
  IF auth = ETAuth:None AND CLIP(SELF.Acc.Password)
    !  Nothing was chosen but there IS a password: take whichever mechanism
    !  the server just advertised.
    IF INSTRING('LOGIN', UPPER(SELF.Capabilities), 1, 1)
      auth = ETAuth:Login
    ELSIF INSTRING('PLAIN', UPPER(SELF.Capabilities), 1, 1)
      auth = ETAuth:Plain
    END
  END

  CASE auth
  OF ETAuth:Login
    IF NOT SELF.SmtpCmd('AUTH LOGIN', '334')
      DO Bye
      RETURN SELF.SetErr(ETSend:Auth, 'AUTH LOGIN was refused: ' & CLIP(SELF.LastServerReply))
    END
    IF NOT SELF.SmtpCmd(SELF.Enc.Base64(CLIP(SELF.Acc.UserName)), '334', 1)
      DO Bye
      RETURN SELF.SetErr(ETSend:Auth, 'The user name was refused: ' & CLIP(SELF.LastServerReply))
    END
    IF NOT SELF.SmtpCmd(SELF.Enc.Base64(CLIP(SELF.Acc.Password)), '235', 1)
      DO Bye
      RETURN SELF.SetErr(ETSend:Auth, 'The password was refused: ' & CLIP(SELF.LastServerReply))
    END
  OF ETAuth:Plain
    IF NOT SELF.SmtpCmd('AUTH PLAIN ' & |
         SELF.Enc.Base64('<0>' & CLIP(SELF.Acc.UserName) & '<0>' & CLIP(SELF.Acc.Password)), '235', 1)
      DO Bye
      RETURN SELF.SetErr(ETSend:Auth, 'AUTH PLAIN was refused: ' & CLIP(SELF.LastServerReply))
    END
  OF ETAuth:XOAuth2
    IF NOT SELF.OAuth.EnsureToken(SELF.Acc)
      DO Bye
      RETURN SELF.SetErr(ETSend:Token, CLIP(SELF.OAuth.LastErrorText))
    END
    IF NOT SELF.SmtpCmd('AUTH XOAUTH2 ' & |
         SELF.OAuth.XOAuth2Blob(SELF.Acc.UserName, SELF.Acc.AccessToken), '235', 1)
      !  A 334 here is the server offering to tell us WHY; an empty line asks
      !  for that explanation, which is far more use than "authentication
      !  failed" on its own.
      IF SUB(CLIP(SELF.LastServerReply), 1, 3) = '334'
        SELF.Net.SendLine('')
        SELF.Expect('235')
      END
      DO Bye
      RETURN SELF.SetErr(ETSend:Auth, 'The OAuth token was refused: ' & CLIP(SELF.LastServerReply))
    END
  END

  !-- envelope --------------------------------------------------------------
  from = CHOOSE(CLIP(SELF.Acc.FromAddr) <> '', CLIP(SELF.Acc.FromAddr), CLIP(pMsg.FromAddr))
  IF NOT SELF.SmtpCmd('MAIL FROM:<' & CLIP(from) & '>', '250')
    DO Bye
    RETURN SELF.SetErr(ETSend:MailFrom, 'The sender was refused: ' & CLIP(SELF.LastServerReply))
  END
  LOOP i = 1 TO pMsg.EnvelopeCount()
    IF NOT SELF.SmtpCmd('RCPT TO:<' & pMsg.EnvelopeAddr(i) & '>', '250,251')
      DO Bye
      RETURN SELF.SetErr(ETSend:RcptTo, 'The recipient ' & pMsg.EnvelopeAddr(i) & |
                         ' was refused: ' & CLIP(SELF.LastServerReply))
    END
  END

  !-- the message itself -----------------------------------------------------
  IF NOT SELF.SmtpCmd('DATA', '354')
    DO Bye
    RETURN SELF.SetErr(ETSend:Data, 'DATA was refused: ' & CLIP(SELF.LastServerReply))
  END
  SELF.DotStuff(pMsg)
  SELF.Net.AddTrace('C: <the message, ' & SELF.Stuffed.Len & ' bytes>')
  sent = 0
  LOOP WHILE sent < SELF.Stuffed.Len
    chunk = SELF.Stuffed.Len - sent
    IF chunk > 32768 THEN chunk = 32768.
    IF NOT SELF.Net.Send(SELF.Stuffed.Buf[sent+1 : sent+chunk])
      DO Bye
      RETURN SELF.SetErr(ETSend:Body, CLIP(SELF.Net.LastErrorText))
    END
    sent += chunk
  END
  IF NOT SELF.Expect('250')
    DO Bye
    RETURN SELF.SetErr(ETSend:Body, 'The server would not accept the message: ' & |
                       CLIP(SELF.LastServerReply))
  END

  SELF.SmtpCmd('QUIT', '221')
  SELF.Net.Close()
  RETURN SELF.SetErr(ETSend:Ok)

Bye ROUTINE
  SELF.Net.Close()

! ============================================================================
!  The REST transports.  All three send the SAME message EmailMsgClass built -
!  they just wrap it differently.
! ============================================================================
!  Gmail API.  The whole MIME document goes in one field, base64url encoded,
!  which means attachments, inline images and accents need no separate mapping:
!  whatever SMTP would have carried, this carries.
EmailToClass.SendGmailApi PROCEDURE(EmailMsgClass pMsg)
body   &EmailBufClass
status LONG
  CODE
  IF pMsg.Mime.Len < 1
    IF pMsg.Build() < 0
      RETURN SELF.SetErr(ETSend:Build, CLIP(pMsg.LastErrorText))
    END
  END
  IF NOT SELF.OAuth.EnsureToken(SELF.Acc)
    RETURN SELF.SetErr(ETSend:Token, CLIP(SELF.OAuth.LastErrorText))
  END

  SELF.Net.Trace      = SELF.Trace
  SELF.Net.VerifyCert = SELF.Acc.VerifyCert
  IF SELF.Acc.Timeout > 0 THEN SELF.Net.Timeout = SELF.Acc.Timeout.

  body &= NEW(EmailBufClass)
  body.Add('{"raw":"')
  body.Add(pMsg.Base64Url(pMsg.Mime.Value()))
  body.Add('"}')

  status = SELF.Net.Http('POST', 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send', |
                         'Authorization: Bearer ' & CLIP(SELF.Acc.AccessToken) & '<13,10>' & |
                         'Content-Type: application/json; charset=UTF-8', body.Value())
  DISPOSE(body)
  IF status = 200 OR status = 202
    RETURN SELF.SetErr(ETSend:Ok)
  END
  RETURN SELF.SetErr(ETSend:Api, 'The Gmail API refused the message (HTTP ' & status & '): ' & |
                     SELF.OAuth.JsonValue(SELF.Net.Body(), 'message'))

!  Microsoft Graph.  Posting the base64 of a raw MIME message as text/plain is
!  the documented way to hand Graph a complete message, and it keeps emailTo
!  from having to translate every part into the Graph JSON schema.
EmailToClass.SendGraphApi PROCEDURE(EmailMsgClass pMsg)
body   &EmailBufClass
status LONG
  CODE
  IF pMsg.Mime.Len < 1
    IF pMsg.Build() < 0
      RETURN SELF.SetErr(ETSend:Build, CLIP(pMsg.LastErrorText))
    END
  END
  IF NOT SELF.OAuth.EnsureToken(SELF.Acc)
    RETURN SELF.SetErr(ETSend:Token, CLIP(SELF.OAuth.LastErrorText))
  END

  SELF.Net.Trace      = SELF.Trace
  SELF.Net.VerifyCert = SELF.Acc.VerifyCert
  IF SELF.Acc.Timeout > 0 THEN SELF.Net.Timeout = SELF.Acc.Timeout.

  body &= NEW(EmailBufClass)
  body.Add(pMsg.Base64(pMsg.Mime.Value()))

  status = SELF.Net.Http('POST', 'https://graph.microsoft.com/v1.0/me/sendMail', |
                         'Authorization: Bearer ' & CLIP(SELF.Acc.AccessToken) & '<13,10>' & |
                         'Content-Type: text/plain', body.Value())
  DISPOSE(body)
  IF status = 202 OR status = 200
    RETURN SELF.SetErr(ETSend:Ok)
  END
  RETURN SELF.SetErr(ETSend:Api, 'Microsoft Graph refused the message (HTTP ' & status & '): ' & |
                     SELF.OAuth.JsonValue(SELF.Net.Body(), 'message'))

!  Recipients, in whichever shape the API in question wants them.
EmailToClass.JsonRecipients PROCEDURE(EmailMsgClass pMsg,BYTE pKind,STRING pStyle)
out   &EmailBufClass
i     LONG
res   CSTRING(8193)
first BYTE
  CODE
  out &= NEW(EmailBufClass)
  IF CLIP(pStyle) <> 'csv' THEN out.Add('[').
  first = 1
  LOOP i = 1 TO RECORDS(pMsg.AddrQ)
    GET(pMsg.AddrQ, i)
    IF pMsg.AddrQ.Kind <> pKind THEN CYCLE.
    IF NOT first
      out.Add(', ')
    END
    first = 0
    CASE CLIP(pStyle)
    OF 'sg'                                          ! SendGrid
      out.Add('{"email":' & pMsg.JsonString(pMsg.AddrQ.Address))
      IF pMsg.AddrQ.DisplayName
        out.Add(',"name":' & pMsg.JsonString(pMsg.AddrQ.DisplayName))
      END
      out.Add('}')
    OF 'brevo'
      out.Add('{"email":' & pMsg.JsonString(pMsg.AddrQ.Address))
      IF pMsg.AddrQ.DisplayName
        out.Add(',"name":' & pMsg.JsonString(pMsg.AddrQ.DisplayName))
      END
      out.Add('}')
    OF 'sp'                                          ! SparkPost wraps the address one deeper
      out.Add('{"address":{"email":' & pMsg.JsonString(pMsg.AddrQ.Address))
      IF pMsg.AddrQ.DisplayName
        out.Add(',"name":' & pMsg.JsonString(pMsg.AddrQ.DisplayName))
      END
      out.Add('}}')
    OF 'mj'                                          ! Mailjet capitalises its keys
      out.Add('{"Email":' & pMsg.JsonString(pMsg.AddrQ.Address))
      IF pMsg.AddrQ.DisplayName
        out.Add(',"Name":' & pMsg.JsonString(pMsg.AddrQ.DisplayName))
      END
      out.Add('}')
    OF 'csv'                                         ! Postmark: one comma-separated string
      IF pMsg.AddrQ.DisplayName
        out.Add(CLIP(pMsg.AddrQ.DisplayName) & ' <' & CLIP(pMsg.AddrQ.Address) & '>')
      ELSE
        out.Add(CLIP(pMsg.AddrQ.Address))
      END
    ELSE                                             ! Resend: a plain array of strings
      out.Add(pMsg.JsonString(pMsg.AddrQ.Address))
    END
  END
  IF CLIP(pStyle) <> 'csv' THEN out.Add(']').
  res = out.Value()
  DISPOSE(out)
  RETURN CLIP(res)

!  SendGrid / Mailgun / Resend / Brevo / Postmark / Mailjet.  One HTTPS POST
!  with an API key - no OAuth, no consent screen, nothing for the end user to
!  set up.  Mailgun is the odd one out: it takes the raw MIME as a file upload,
!  so it needs no field-by-field translation at all.
EmailToClass.SendApiKey PROCEDURE(EmailMsgClass pMsg)
body   &EmailBufClass
hdr    &EmailBufClass
raw    &EmailBufClass
url    CSTRING(513)
bound  CSTRING(65)
status LONG
i      LONG
okLo   LONG
okHi   LONG
  CODE
  IF pMsg.Mime.Len < 1
    IF pMsg.Build() < 0
      RETURN SELF.SetErr(ETSend:Build, CLIP(pMsg.LastErrorText))
    END
  END
  IF NOT CLIP(SELF.Acc.ApiKey)
    RETURN SELF.SetErr(ETSend:NoAccount, 'No API key is configured for this account.')
  END

  SELF.Net.Trace      = SELF.Trace
  SELF.Net.VerifyCert = SELF.Acc.VerifyCert
  IF SELF.Acc.Timeout > 0 THEN SELF.Net.Timeout = SELF.Acc.Timeout.

  body &= NEW(EmailBufClass)
  hdr  &= NEW(EmailBufClass)
  okLo  = 200
  okHi  = 202

  CASE SELF.Acc.Provider
  OF ETPrv:SendGrid
    url = 'https://api.sendgrid.com/v3/mail/send'
    hdr.Add('Authorization: Bearer ' & CLIP(SELF.Acc.ApiKey) & '<13,10>')
    hdr.Add('Content-Type: application/json')
    body.Add('{"personalizations":[{"to":' & SELF.JsonRecipients(pMsg, ETAddr:To, 'sg'))
    IF RECORDS(pMsg.AddrQ)
      IF SELF.JsonRecipients(pMsg, ETAddr:Cc, 'sg') <> '[]'
        body.Add(',"cc":' & SELF.JsonRecipients(pMsg, ETAddr:Cc, 'sg'))
      END
      IF SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'sg') <> '[]'
        body.Add(',"bcc":' & SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'sg'))
      END
    END
    body.Add('}],"from":{"email":' & pMsg.JsonString(pMsg.FromAddr))
    IF pMsg.FromName
      body.Add(',"name":' & pMsg.JsonString(pMsg.FromName))
    END
    body.Add('},"subject":' & pMsg.JsonString(pMsg.Subject) & ',"content":[')
    IF pMsg.TextBody.Len > 0
      body.Add('{"type":"text/plain","value":' & pMsg.JsonString(pMsg.TextBody.Value()) & '}')
      IF pMsg.HtmlBody.Len > 0 THEN body.Add(',').
    END
    IF pMsg.HtmlBody.Len > 0
      body.Add('{"type":"text/html","value":' & pMsg.JsonString(pMsg.HtmlBody.Value()) & '}')
    END
    body.Add(']')
    DO SendGridAttachments
    body.Add('}')

  OF ETPrv:Resend
    url = 'https://api.resend.com/emails'
    hdr.Add('Authorization: Bearer ' & CLIP(SELF.Acc.ApiKey) & '<13,10>')
    hdr.Add('Content-Type: application/json')
    body.Add('{"from":')
    IF pMsg.FromName
      body.Add(pMsg.JsonString(CLIP(pMsg.FromName) & ' <' & CLIP(pMsg.FromAddr) & '>'))
    ELSE
      body.Add(pMsg.JsonString(pMsg.FromAddr))
    END
    body.Add(',"to":' & SELF.JsonRecipients(pMsg, ETAddr:To, 'plain'))
    IF SELF.JsonRecipients(pMsg, ETAddr:Cc, 'plain') <> '[]'
      body.Add(',"cc":' & SELF.JsonRecipients(pMsg, ETAddr:Cc, 'plain'))
    END
    IF SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'plain') <> '[]'
      body.Add(',"bcc":' & SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'plain'))
    END
    body.Add(',"subject":' & pMsg.JsonString(pMsg.Subject))
    IF pMsg.TextBody.Len > 0
      body.Add(',"text":' & pMsg.JsonString(pMsg.TextBody.Value()))
    END
    IF pMsg.HtmlBody.Len > 0
      body.Add(',"html":' & pMsg.JsonString(pMsg.HtmlBody.Value()))
    END
    DO ResendAttachments
    body.Add('}')

  OF ETPrv:Brevo
    url = 'https://api.brevo.com/v3/smtp/email'
    hdr.Add('api-key: ' & CLIP(SELF.Acc.ApiKey) & '<13,10>')
    hdr.Add('Content-Type: application/json<13,10>')
    hdr.Add('Accept: application/json')
    body.Add('{"sender":{"email":' & pMsg.JsonString(pMsg.FromAddr))
    IF pMsg.FromName
      body.Add(',"name":' & pMsg.JsonString(pMsg.FromName))
    END
    body.Add('},"to":' & SELF.JsonRecipients(pMsg, ETAddr:To, 'brevo'))
    IF SELF.JsonRecipients(pMsg, ETAddr:Cc, 'brevo') <> '[]'
      body.Add(',"cc":' & SELF.JsonRecipients(pMsg, ETAddr:Cc, 'brevo'))
    END
    IF SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'brevo') <> '[]'
      body.Add(',"bcc":' & SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'brevo'))
    END
    body.Add(',"subject":' & pMsg.JsonString(pMsg.Subject))
    IF pMsg.TextBody.Len > 0
      body.Add(',"textContent":' & pMsg.JsonString(pMsg.TextBody.Value()))
    END
    IF pMsg.HtmlBody.Len > 0
      body.Add(',"htmlContent":' & pMsg.JsonString(pMsg.HtmlBody.Value()))
    END
    DO BrevoAttachments
    body.Add('}')

  OF ETPrv:Postmark
    url = 'https://api.postmarkapp.com/email'
    hdr.Add('X-Postmark-Server-Token: ' & CLIP(SELF.Acc.ApiKey) & '<13,10>')
    hdr.Add('Content-Type: application/json<13,10>')
    hdr.Add('Accept: application/json')
    body.Add('{"From":')
    IF pMsg.FromName
      body.Add(pMsg.JsonString(CLIP(pMsg.FromName) & ' <' & CLIP(pMsg.FromAddr) & '>'))
    ELSE
      body.Add(pMsg.JsonString(pMsg.FromAddr))
    END
    body.Add(',"To":' & pMsg.JsonString(SELF.JsonRecipients(pMsg, ETAddr:To, 'csv')))
    IF SELF.JsonRecipients(pMsg, ETAddr:Cc, 'csv')
      body.Add(',"Cc":' & pMsg.JsonString(SELF.JsonRecipients(pMsg, ETAddr:Cc, 'csv')))
    END
    IF SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'csv')
      body.Add(',"Bcc":' & pMsg.JsonString(SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'csv')))
    END
    body.Add(',"Subject":' & pMsg.JsonString(pMsg.Subject))
    IF pMsg.TextBody.Len > 0
      body.Add(',"TextBody":' & pMsg.JsonString(pMsg.TextBody.Value()))
    END
    IF pMsg.HtmlBody.Len > 0
      body.Add(',"HtmlBody":' & pMsg.JsonString(pMsg.HtmlBody.Value()))
    END
    DO PostmarkAttachments
    body.Add('}')

  OF ETPrv:Mailjet
    url = 'https://api.mailjet.com/v3.1/send'
    !  Mailjet authenticates with a PAIR of keys: the public one goes in
    !  UserName and the private one in ApiKey.
    hdr.Add('Authorization: Basic ' & |
            SELF.Enc.Base64(CLIP(SELF.Acc.UserName) & ':' & CLIP(SELF.Acc.ApiKey)) & '<13,10>')
    hdr.Add('Content-Type: application/json')
    body.Add('{"Messages":[{"From":{"Email":' & pMsg.JsonString(pMsg.FromAddr))
    IF pMsg.FromName
      body.Add(',"Name":' & pMsg.JsonString(pMsg.FromName))
    END
    body.Add('},"To":' & SELF.JsonRecipients(pMsg, ETAddr:To, 'mj'))
    IF SELF.JsonRecipients(pMsg, ETAddr:Cc, 'mj') <> '[]'
      body.Add(',"Cc":' & SELF.JsonRecipients(pMsg, ETAddr:Cc, 'mj'))
    END
    IF SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'mj') <> '[]'
      body.Add(',"Bcc":' & SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'mj'))
    END
    body.Add(',"Subject":' & pMsg.JsonString(pMsg.Subject))
    IF pMsg.TextBody.Len > 0
      body.Add(',"TextPart":' & pMsg.JsonString(pMsg.TextBody.Value()))
    END
    IF pMsg.HtmlBody.Len > 0
      body.Add(',"HTMLPart":' & pMsg.JsonString(pMsg.HtmlBody.Value()))
    END
    DO MailjetAttachments
    body.Add('}]}')

  OF ETPrv:SparkPost
    url = 'https://' & CHOOSE(LOWER(CLIP(SELF.Acc.ApiRegion)) = 'eu', |
                              'api.eu.sparkpost.com', 'api.sparkpost.com') & '/api/v1/transmissions'
    hdr.Add('Authorization: ' & CLIP(SELF.Acc.ApiKey) & '<13,10>')
    hdr.Add('Content-Type: application/json')
    !  SparkPost has no separate cc / bcc: every recipient goes in one list and
    !  the Cc: header is what makes a copy visible.  Bcc recipients are simply
    !  in the list with no header, which is exactly what blind means.
    body.Add('{"recipients":[')
    body.Add(SUB(SELF.JsonRecipients(pMsg, ETAddr:To, 'sp'), 2, |
                 LEN(CLIP(SELF.JsonRecipients(pMsg, ETAddr:To, 'sp'))) - 2))
    DO SparkPostMore
    body.Add('],"content":{"from":{"email":' & pMsg.JsonString(pMsg.FromAddr))
    IF pMsg.FromName
      body.Add(',"name":' & pMsg.JsonString(pMsg.FromName))
    END
    body.Add('},"subject":' & pMsg.JsonString(pMsg.Subject))
    IF pMsg.TextBody.Len > 0
      body.Add(',"text":' & pMsg.JsonString(pMsg.TextBody.Value()))
    END
    IF pMsg.HtmlBody.Len > 0
      body.Add(',"html":' & pMsg.JsonString(pMsg.HtmlBody.Value()))
    END
    IF SELF.JsonRecipients(pMsg, ETAddr:Cc, 'csv')
      body.Add(',"headers":{"CC":' & pMsg.JsonString(SELF.JsonRecipients(pMsg, ETAddr:Cc, 'csv')) & '}')
    END
    DO SparkPostAttachments
    body.Add('}}')

  OF ETPrv:MailerSend
    url = 'https://api.mailersend.com/v1/email'
    hdr.Add('Authorization: Bearer ' & CLIP(SELF.Acc.ApiKey) & '<13,10>')
    hdr.Add('Content-Type: application/json')
    body.Add('{"from":{"email":' & pMsg.JsonString(pMsg.FromAddr))
    IF pMsg.FromName
      body.Add(',"name":' & pMsg.JsonString(pMsg.FromName))
    END
    body.Add('},"to":' & SELF.JsonRecipients(pMsg, ETAddr:To, 'sg'))
    IF SELF.JsonRecipients(pMsg, ETAddr:Cc, 'sg') <> '[]'
      body.Add(',"cc":' & SELF.JsonRecipients(pMsg, ETAddr:Cc, 'sg'))
    END
    IF SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'sg') <> '[]'
      body.Add(',"bcc":' & SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'sg'))
    END
    body.Add(',"subject":' & pMsg.JsonString(pMsg.Subject))
    IF pMsg.TextBody.Len > 0
      body.Add(',"text":' & pMsg.JsonString(pMsg.TextBody.Value()))
    END
    IF pMsg.HtmlBody.Len > 0
      body.Add(',"html":' & pMsg.JsonString(pMsg.HtmlBody.Value()))
    END
    DO MailerSendAttachments
    body.Add('}')

  OF ETPrv:AmazonSes
    !  SES takes the whole MIME document base64'd, so the message crosses
    !  exactly as SMTP would have carried it - and the signing is the same
    !  SigV4 the management API uses, so it lives in EmailApiClass.
    url = 'https://email.' & CHOOSE(CLIP(SELF.Acc.ApiRegion) <> '', |
                                    CLIP(SELF.Acc.ApiRegion), 'us-east-1') & |
          '.amazonaws.com/v2/email/outbound-emails'
    body.Add('{"Content":{"Raw":{"Data":"')
    body.Add(pMsg.Base64(pMsg.Mime.Value()))
    body.Add('"}}}')
    hdr.Add(SELF.Net.SignAws('POST', url, body.Value(), |
                             CHOOSE(CLIP(SELF.Acc.ApiKey2) <> '', |
                                    CLIP(SELF.Acc.ApiKey2), CLIP(SELF.Acc.UserName)), |
                             SELF.Acc.ApiKey, |
                             CHOOSE(CLIP(SELF.Acc.ApiRegion) <> '', |
                                    CLIP(SELF.Acc.ApiRegion), 'us-east-1'), 'ses') & '<13,10>')
    hdr.Add('Content-Type: application/json')

  OF ETPrv:Mailgun
    !  Mailgun accepts a whole MIME document, so the message goes across
    !  exactly as SMTP would have carried it - attachments and all.
    IF NOT CLIP(SELF.Acc.ApiDomain)
      DISPOSE(body); DISPOSE(hdr)
      RETURN SELF.SetErr(ETSend:NoAccount, 'Mailgun needs the sending domain in ApiDomain.')
    END
    url   = 'https://api.mailgun.net/v3/' & CLIP(SELF.Acc.ApiDomain) & '/messages.mime'
    bound = '----emailTo' & FORMAT(RANDOM(100000000, 999999999), @n09)
    hdr.Add('Authorization: Basic ' & SELF.Enc.Base64('api:' & CLIP(SELF.Acc.ApiKey)) & '<13,10>')
    hdr.Add('Content-Type: multipart/form-data; boundary=' & CLIP(bound))
    LOOP i = 1 TO pMsg.EnvelopeCount()
      body.Add('--' & CLIP(bound) & '<13,10>')
      body.Add('Content-Disposition: form-data; name="to"<13,10><13,10>')
      body.Add(pMsg.EnvelopeAddr(i) & '<13,10>')
    END
    body.Add('--' & CLIP(bound) & '<13,10>')
    body.Add('Content-Disposition: form-data; name="message"; filename="message.mime"<13,10>')
    body.Add('Content-Type: message/rfc822<13,10><13,10>')
    body.AddLen(pMsg.Mime.Buf, pMsg.Mime.Len)
    body.Add('<13,10>--' & CLIP(bound) & '--<13,10>')

  ELSE
    DISPOSE(body); DISPOSE(hdr)
    RETURN SELF.SetErr(ETSend:NoTransport, |
      'The API transport does not know this provider. Choose SendGrid, Mailgun, Resend, ' & |
      'Brevo, Postmark, Mailjet, SparkPost, MailerSend or Amazon SES.')
  END

  status = SELF.Net.Http('POST', url, hdr.Value(), body.Value())
  DISPOSE(body)
  DISPOSE(hdr)
  IF status >= okLo AND status <= okHi
    RETURN SELF.SetErr(ETSend:Ok)
  END
  RETURN SELF.SetErr(ETSend:Api, SELF.ProviderName(SELF.Acc.Provider) & |
                     ' refused the message (HTTP ' & status & '): ' & |
                     SUB(SELF.Net.Body(), 1, 300))

!---- the attachment blocks, one per API shape -------------------------------
SendGridAttachments ROUTINE
  IF NOT RECORDS(pMsg.AttachQ) THEN EXIT.
  body.Add(',"attachments":[')
  LOOP i = 1 TO RECORDS(pMsg.AttachQ)
    GET(pMsg.AttachQ, i)
    IF i > 1 THEN body.Add(',').
    DO LoadOne
    body.Add('{"content":"')
    body.Add(pMsg.Base64(raw.Value()))
    body.Add('","filename":' & pMsg.JsonString(pMsg.AttachQ.ShownAs))
    body.Add(',"type":' & pMsg.JsonString(pMsg.AttachQ.ContentType))
    IF pMsg.AttachQ.ContentId
      body.Add(',"disposition":"inline","content_id":' & pMsg.JsonString(pMsg.AttachQ.ContentId))
    ELSE
      body.Add(',"disposition":"attachment"')
    END
    body.Add('}')
    DISPOSE(raw)
  END
  body.Add(']')

ResendAttachments ROUTINE
  IF NOT RECORDS(pMsg.AttachQ) THEN EXIT.
  body.Add(',"attachments":[')
  LOOP i = 1 TO RECORDS(pMsg.AttachQ)
    GET(pMsg.AttachQ, i)
    IF i > 1 THEN body.Add(',').
    DO LoadOne
    body.Add('{"filename":' & pMsg.JsonString(pMsg.AttachQ.ShownAs) & ',"content":"')
    body.Add(pMsg.Base64(raw.Value()))
    body.Add('"}')
    DISPOSE(raw)
  END
  body.Add(']')

BrevoAttachments ROUTINE
  IF NOT RECORDS(pMsg.AttachQ) THEN EXIT.
  body.Add(',"attachment":[')
  LOOP i = 1 TO RECORDS(pMsg.AttachQ)
    GET(pMsg.AttachQ, i)
    IF i > 1 THEN body.Add(',').
    DO LoadOne
    body.Add('{"name":' & pMsg.JsonString(pMsg.AttachQ.ShownAs) & ',"content":"')
    body.Add(pMsg.Base64(raw.Value()))
    body.Add('"}')
    DISPOSE(raw)
  END
  body.Add(']')

PostmarkAttachments ROUTINE
  IF NOT RECORDS(pMsg.AttachQ) THEN EXIT.
  body.Add(',"Attachments":[')
  LOOP i = 1 TO RECORDS(pMsg.AttachQ)
    GET(pMsg.AttachQ, i)
    IF i > 1 THEN body.Add(',').
    DO LoadOne
    body.Add('{"Name":' & pMsg.JsonString(pMsg.AttachQ.ShownAs) & ',"Content":"')
    body.Add(pMsg.Base64(raw.Value()))
    body.Add('","ContentType":' & pMsg.JsonString(pMsg.AttachQ.ContentType))
    IF pMsg.AttachQ.ContentId
      body.Add(',"ContentID":' & pMsg.JsonString('cid:' & CLIP(pMsg.AttachQ.ContentId)))
    END
    body.Add('}')
    DISPOSE(raw)
  END
  body.Add(']')

!  SparkPost takes cc and bcc recipients in the same list as to.
SparkPostMore ROUTINE
  DATA
r CSTRING(8193)
  CODE
  r = SELF.JsonRecipients(pMsg, ETAddr:Cc, 'sp')
  IF CLIP(r) <> '[]'
    body.Add(',' & SUB(r, 2, LEN(CLIP(r)) - 2))
  END
  r = SELF.JsonRecipients(pMsg, ETAddr:Bcc, 'sp')
  IF CLIP(r) <> '[]'
    body.Add(',' & SUB(r, 2, LEN(CLIP(r)) - 2))
  END

SparkPostAttachments ROUTINE
  IF NOT RECORDS(pMsg.AttachQ) THEN EXIT.
  body.Add(',"attachments":[')
  LOOP i = 1 TO RECORDS(pMsg.AttachQ)
    GET(pMsg.AttachQ, i)
    IF i > 1 THEN body.Add(',').
    DO LoadOne
    body.Add('{"type":' & pMsg.JsonString(pMsg.AttachQ.ContentType))
    body.Add(',"name":' & pMsg.JsonString(pMsg.AttachQ.ShownAs) & ',"data":"')
    body.Add(pMsg.Base64(raw.Value()))
    body.Add('"}')
    DISPOSE(raw)
  END
  body.Add(']')

MailerSendAttachments ROUTINE
  IF NOT RECORDS(pMsg.AttachQ) THEN EXIT.
  body.Add(',"attachments":[')
  LOOP i = 1 TO RECORDS(pMsg.AttachQ)
    GET(pMsg.AttachQ, i)
    IF i > 1 THEN body.Add(',').
    DO LoadOne
    body.Add('{"filename":' & pMsg.JsonString(pMsg.AttachQ.ShownAs) & ',"content":"')
    body.Add(pMsg.Base64(raw.Value()))
    body.Add('"')
    IF pMsg.AttachQ.ContentId
      body.Add(',"disposition":"inline","id":' & pMsg.JsonString(pMsg.AttachQ.ContentId))
    ELSE
      body.Add(',"disposition":"attachment"')
    END
    body.Add('}')
    DISPOSE(raw)
  END
  body.Add(']')

MailjetAttachments ROUTINE
  IF NOT RECORDS(pMsg.AttachQ) THEN EXIT.
  body.Add(',"Attachments":[')
  LOOP i = 1 TO RECORDS(pMsg.AttachQ)
    GET(pMsg.AttachQ, i)
    IF i > 1 THEN body.Add(',').
    DO LoadOne
    body.Add('{"ContentType":' & pMsg.JsonString(pMsg.AttachQ.ContentType))
    body.Add(',"Filename":' & pMsg.JsonString(pMsg.AttachQ.ShownAs) & ',"Base64Content":"')
    body.Add(pMsg.Base64(raw.Value()))
    body.Add('"}')
    DISPOSE(raw)
  END
  body.Add(']')

!  Get one attachment into `raw`, whether it came from disk or from memory.
LoadOne ROUTINE
  raw &= NEW(EmailBufClass)
  IF NOT pMsg.AttachQ.Data &= NULL
    raw.AddLen(pMsg.AttachQ.Data, pMsg.AttachQ.DataLen)
  ELSE
    pMsg.LoadFile(pMsg.AttachQ.FileName, raw)
  END

! ============================================================================
!  The public entry points
! ============================================================================
EmailToClass.Send PROCEDURE(EmailMsgClass pMsg)
  CODE
  SELF.SetErr(ETSend:Ok)
  SELF.Net.ClearTrace()
  SELF.LastServerReply = ''

  !  The account fills in anything the caller left blank.
  IF NOT pMsg.FromAddr AND CLIP(SELF.Acc.FromAddr)
    pMsg.SetFrom(SELF.Acc.FromAddr, SELF.Acc.FromName)
  END
  IF NOT pMsg.ReplyTo AND CLIP(SELF.Acc.ReplyTo)
    pMsg.ReplyTo = SELF.Acc.ReplyTo
  END
  IF NOT pMsg.FromAddr AND CLIP(SELF.Acc.UserName)
    !  Most providers use the address as the user name; better a sensible
    !  guess than a message that cannot be built at all.
    pMsg.SetFrom(SELF.Acc.UserName)
  END

  !  Who carries the Bcc list depends on the transport.  SMTP has an envelope
  !  and uses it; the Gmail API and Graph have none and read the headers, so
  !  the Bcc has to be written into the MIME for them (they strip it again).
  !  The API-key providers get their Bcc list in the JSON, or - for Mailgun -
  !  as separate form fields, so they want it out of the headers too.
  pMsg.BccInHeaders = CHOOSE(SELF.Acc.Transport = ETTrn:GmailApi OR |
                             SELF.Acc.Transport = ETTrn:GraphApi, 1, 0)

  !  And who mints the Message-ID.  Over SMTP we do, because plenty of servers
  !  will not add one.  Over the REST transports the provider assigns its own
  !  and throws ours away, so writing one only risks claiming an id in a domain
  !  we do not own - <...@gmail.com> when we are not Google.
  pMsg.OwnMessageId = CHOOSE(SELF.Acc.Transport = ETTrn:GmailApi OR |
                             SELF.Acc.Transport = ETTrn:GraphApi, 0, 1)

  pMsg.Mime.ClearAll()
  IF pMsg.Build() < 0
    RETURN SELF.SetErr(ETSend:Build, CLIP(pMsg.LastErrorText))
  END

  CASE SELF.Acc.Transport
  OF ETTrn:Smtp     ; RETURN SELF.SendSmtp(pMsg)
  OF ETTrn:GmailApi ; RETURN SELF.SendGmailApi(pMsg)
  OF ETTrn:GraphApi ; RETURN SELF.SendGraphApi(pMsg)
  OF ETTrn:ApiKey   ; RETURN SELF.SendApiKey(pMsg)
  END
  RETURN SELF.SetErr(ETSend:NoTransport)

EmailToClass.SendSimple PROCEDURE(STRING pTo,STRING pSubject,STRING pBody,<STRING pAttach>)
  CODE
  SELF.Msg.ClearAll()
  SELF.Msg.AddList(pTo, ETAddr:To)
  SELF.Msg.SetSubject(pSubject)
  SELF.Msg.SetText(pBody)
  IF NOT OMITTED(pAttach) AND CLIP(pAttach)
    IF NOT SELF.Msg.Attach(pAttach)
      RETURN SELF.SetErr(ETSend:Build, CLIP(SELF.Msg.LastErrorText))
    END
  END
  RETURN SELF.Send(SELF.Msg)

!  Prove the account works without sending anything to anybody: connect,
!  authenticate, then say goodbye.  For the API transports there is nothing to
!  connect to, so the credential is checked by asking the service about itself.
EmailToClass.TestAccount PROCEDURE()
tls    BYTE
status LONG
  CODE
  SELF.SetErr(ETSend:Ok)
  SELF.Net.ClearTrace()
  SELF.Net.Trace      = 1
  SELF.Net.VerifyCert = SELF.Acc.VerifyCert
  IF SELF.Acc.Timeout > 0 THEN SELF.Net.Timeout = SELF.Acc.Timeout.

  CASE SELF.Acc.Transport
  OF ETTrn:GmailApi OROF ETTrn:GraphApi
    IF NOT SELF.OAuth.EnsureToken(SELF.Acc)
      RETURN SELF.SetErr(ETSend:Token, CLIP(SELF.OAuth.LastErrorText))
    END
    RETURN SELF.SetErr(ETSend:Ok)
  OF ETTrn:ApiKey
    IF NOT CLIP(SELF.Acc.ApiKey)
      RETURN SELF.SetErr(ETSend:NoAccount, 'No API key is configured.')
    END
    RETURN SELF.SetErr(ETSend:Ok)
  END

  IF NOT CLIP(SELF.Acc.Host)
    RETURN SELF.SetErr(ETSend:NoAccount, 'No SMTP server is configured.')
  END
  SELF.Capabilities = ''
  tls = CHOOSE(SELF.Acc.Security = ETSec:Tls, 1, 0)
  IF NOT SELF.Net.Open(SELF.Acc.Host, SELF.Acc.Port, tls)
    RETURN SELF.SetErr(ETSend:Connect, CLIP(SELF.Net.LastErrorText) & |
                       CHOOSE(SELF.Net.LastWinError = 0, '', ' (Windows ' & SELF.Net.LastWinError & ')'))
  END
  IF NOT SELF.Expect('220')
    SELF.Net.Close()
    RETURN SELF.SetErr(ETSend:Greeting, CLIP(SELF.LastServerReply))
  END
  IF NOT SELF.SmtpCmd('EHLO ' & SELF.EhloDomain(), '250')
    SELF.Net.Close()
    RETURN SELF.SetErr(ETSend:Ehlo, CLIP(SELF.LastServerReply))
  END
  IF SELF.Acc.Security = ETSec:StartTls
    IF NOT SELF.SmtpCmd('STARTTLS', '220')
      SELF.Net.Close()
      RETURN SELF.SetErr(ETSend:StartTls, CLIP(SELF.LastServerReply))
    END
    IF NOT SELF.Net.StartTls(SELF.Acc.Host)
      SELF.Net.Close()
      RETURN SELF.SetErr(ETSend:StartTls, CLIP(SELF.Net.LastErrorText))
    END
    SELF.Capabilities = ''
    IF NOT SELF.SmtpCmd('EHLO ' & SELF.EhloDomain(), '250')
      SELF.Net.Close()
      RETURN SELF.SetErr(ETSend:Ehlo, CLIP(SELF.LastServerReply))
    END
  END

  CASE SELF.Acc.AuthMode
  OF ETAuth:Login
    IF NOT SELF.SmtpCmd('AUTH LOGIN', '334') |
    OR NOT SELF.SmtpCmd(SELF.Enc.Base64(CLIP(SELF.Acc.UserName)), '334', 1) |
    OR NOT SELF.SmtpCmd(SELF.Enc.Base64(CLIP(SELF.Acc.Password)), '235', 1)
      SELF.Net.Close()
      RETURN SELF.SetErr(ETSend:Auth, CLIP(SELF.LastServerReply))
    END
  OF ETAuth:Plain
    IF NOT SELF.SmtpCmd('AUTH PLAIN ' & |
         SELF.Enc.Base64('<0>' & CLIP(SELF.Acc.UserName) & '<0>' & CLIP(SELF.Acc.Password)), '235', 1)
      SELF.Net.Close()
      RETURN SELF.SetErr(ETSend:Auth, CLIP(SELF.LastServerReply))
    END
  OF ETAuth:XOAuth2
    IF NOT SELF.OAuth.EnsureToken(SELF.Acc)
      SELF.Net.Close()
      RETURN SELF.SetErr(ETSend:Token, CLIP(SELF.OAuth.LastErrorText))
    END
    IF NOT SELF.SmtpCmd('AUTH XOAUTH2 ' & |
         SELF.OAuth.XOAuth2Blob(SELF.Acc.UserName, SELF.Acc.AccessToken), '235', 1)
      SELF.Net.Close()
      RETURN SELF.SetErr(ETSend:Auth, CLIP(SELF.LastServerReply))
    END
  END

  SELF.SmtpCmd('QUIT', '221')
  SELF.Net.Close()
  RETURN SELF.SetErr(ETSend:Ok)

! ============================================================================
!  Every word the user sees, in English and Spanish.
!
!  Override this ONE method in a derived class to add a third language - no
!  other part of emailTo contains a literal the user reads.  The Spanish is
!  written with Clarion <nnn> escapes so this file stays plain ANSI and no
!  editor can quietly mangle the accents.
! ============================================================================
EmailToClass.Txt PROCEDURE(LONG pId)
  CODE
  IF SELF.Language = ETLng:Spanish
    CASE pId
    OF ETTxt:Setup        ; RETURN 'Configuraci<243>n de correo'
    OF ETTxt:Account      ; RETURN 'Cuenta'
    OF ETTxt:Provider     ; RETURN 'Proveedor:'
    OF ETTxt:Transport    ; RETURN 'M<233>todo de env<237>o:'
    OF ETTxt:Server       ; RETURN 'Servidor:'
    OF ETTxt:Port         ; RETURN 'Puerto:'
    OF ETTxt:Security     ; RETURN 'Seguridad:'
    OF ETTxt:AuthMethod   ; RETURN 'Autenticaci<243>n:'
    OF ETTxt:UserName     ; RETURN 'Usuario:'
    OF ETTxt:Password     ; RETURN 'Contrase<241>a:'
    OF ETTxt:FromAddress  ; RETURN 'Direcci<243>n del remitente:'
    OF ETTxt:FromName     ; RETURN 'Nombre del remitente:'
    OF ETTxt:ReplyTo      ; RETURN 'Responder a:'
    OF ETTxt:ClientId     ; RETURN 'ID de cliente:'
    OF ETTxt:ClientSecret ; RETURN 'Secreto de cliente:'
    OF ETTxt:Tenant       ; RETURN 'Inquilino (tenant):'
    OF ETTxt:ApiKey       ; RETURN 'Clave API:'
    OF ETTxt:SignIn       ; RETURN 'Iniciar sesi<243>n...'
    OF ETTxt:SendTest     ; RETURN 'Probar cuenta'
    OF ETTxt:Save         ; RETURN 'Guardar'
    OF ETTxt:Cancel       ; RETURN 'Cancelar'
    OF ETTxt:Close        ; RETURN 'Cerrar'
    OF ETTxt:Log          ; RETURN 'Registro'
    OF ETTxt:Testing      ; RETURN 'Probando la cuenta...'
    OF ETTxt:TestOk       ; RETURN 'La cuenta funciona correctamente.'
    OF ETTxt:TestFailed   ; RETURN 'La prueba fall<243>'
    OF ETTxt:Sending      ; RETURN 'Enviando...'
    OF ETTxt:Sent         ; RETURN 'El mensaje fue enviado.'
    OF ETTxt:SendFailed   ; RETURN 'No se pudo enviar'
    OF ETTxt:SignedIn     ; RETURN 'Sesi<243>n iniciada correctamente.'
    OF ETTxt:SignInFailed ; RETURN 'No se pudo iniciar sesi<243>n'
    OF ETTxt:WaitBrowser  ; RETURN 'Termine el inicio de sesi<243>n en el navegador...'
    OF ETTxt:To           ; RETURN 'Para:'
    OF ETTxt:Cc           ; RETURN 'Copia:'
    OF ETTxt:Bcc          ; RETURN 'Copia oculta:'
    OF ETTxt:Subject      ; RETURN 'Asunto:'
    OF ETTxt:Message      ; RETURN 'Mensaje:'
    OF ETTxt:Attach       ; RETURN 'Adjuntos:'
    OF ETTxt:Send         ; RETURN 'Enviar'
    OF ETTxt:Compose      ; RETURN 'Redactar mensaje'
    OF ETTxt:NeedTo       ; RETURN 'Escriba al menos un destinatario.'
    OF ETTxt:NeedSubject  ; RETURN '<191>Enviar el mensaje sin asunto?'
    OF ETTxt:TestSubject  ; RETURN 'Mensaje de prueba de emailTo'
    OF ETTxt:TestBody     ; RETURN 'Si est<225> leyendo esto, la cuenta de correo funciona.'
    OF ETTxt:Connecting   ; RETURN 'Conectando...'
    OF ETTxt:Authorising  ; RETURN 'Autorizando...'
    OF ETTxt:Building     ; RETURN 'Preparando el mensaje...'
    OF ETTxt:Remove       ; RETURN 'Quitar'
    OF ETTxt:AddFile      ; RETURN 'Agregar archivo...'
    OF ETTxt:BrowserNote  ; RETURN 'Se abrir<225> su navegador para iniciar sesi<243>n con el proveedor.'
    END
    RETURN ''
  END

  CASE pId
  OF ETTxt:Setup        ; RETURN 'Mail account setup'
  OF ETTxt:Account      ; RETURN 'Account'
  OF ETTxt:Provider     ; RETURN 'Provider:'
  OF ETTxt:Transport    ; RETURN 'Send using:'
  OF ETTxt:Server       ; RETURN 'Server:'
  OF ETTxt:Port         ; RETURN 'Port:'
  OF ETTxt:Security     ; RETURN 'Security:'
  OF ETTxt:AuthMethod   ; RETURN 'Sign in with:'
  OF ETTxt:UserName     ; RETURN 'User name:'
  OF ETTxt:Password     ; RETURN 'Password:'
  OF ETTxt:FromAddress  ; RETURN 'From address:'
  OF ETTxt:FromName     ; RETURN 'From name:'
  OF ETTxt:ReplyTo      ; RETURN 'Reply to:'
  OF ETTxt:ClientId     ; RETURN 'Client ID:'
  OF ETTxt:ClientSecret ; RETURN 'Client secret:'
  OF ETTxt:Tenant       ; RETURN 'Tenant:'
  OF ETTxt:ApiKey       ; RETURN 'API key:'
  OF ETTxt:SignIn       ; RETURN 'Sign in...'
  OF ETTxt:SendTest     ; RETURN 'Test account'
  OF ETTxt:Save         ; RETURN 'Save'
  OF ETTxt:Cancel       ; RETURN 'Cancel'
  OF ETTxt:Close        ; RETURN 'Close'
  OF ETTxt:Log          ; RETURN 'Log'
  OF ETTxt:Testing      ; RETURN 'Testing the account...'
  OF ETTxt:TestOk       ; RETURN 'The account works.'
  OF ETTxt:TestFailed   ; RETURN 'The test failed'
  OF ETTxt:Sending      ; RETURN 'Sending...'
  OF ETTxt:Sent         ; RETURN 'The message was sent.'
  OF ETTxt:SendFailed   ; RETURN 'The message was not sent'
  OF ETTxt:SignedIn     ; RETURN 'Signed in successfully.'
  OF ETTxt:SignInFailed ; RETURN 'Sign-in failed'
  OF ETTxt:WaitBrowser  ; RETURN 'Finish signing in using the browser...'
  OF ETTxt:To           ; RETURN 'To:'
  OF ETTxt:Cc           ; RETURN 'Cc:'
  OF ETTxt:Bcc          ; RETURN 'Bcc:'
  OF ETTxt:Subject      ; RETURN 'Subject:'
  OF ETTxt:Message      ; RETURN 'Message:'
  OF ETTxt:Attach       ; RETURN 'Attachments:'
  OF ETTxt:Send         ; RETURN 'Send'
  OF ETTxt:Compose      ; RETURN 'Write a message'
  OF ETTxt:NeedTo       ; RETURN 'Please enter at least one recipient.'
  OF ETTxt:NeedSubject  ; RETURN 'Send the message with no subject?'
  OF ETTxt:TestSubject  ; RETURN 'emailTo test message'
  OF ETTxt:TestBody     ; RETURN 'If you are reading this, the mail account works.'
  OF ETTxt:Connecting   ; RETURN 'Connecting...'
  OF ETTxt:Authorising  ; RETURN 'Authorising...'
  OF ETTxt:Building     ; RETURN 'Preparing the message...'
  OF ETTxt:Remove       ; RETURN 'Remove'
  OF ETTxt:AddFile      ; RETURN 'Add file...'
  OF ETTxt:BrowserNote  ; RETURN 'Your browser will open so you can sign in with the provider.'
  END
  RETURN ''

! ============================================================================
!  Setup - the window an end user configures the account in.
!
!  It is deliberately one window with four tabs rather than a wizard: the
!  people who use it are usually setting up a server they already know, and a
!  wizard would make them click through four pages to change a port number.
! ============================================================================
EmailToClass.Setup PROCEDURE()
LocName      CSTRING(65)
LocHost      CSTRING(129)
LocPort      LONG
LocUser      CSTRING(256)
LocPass      CSTRING(256)
LocFrom      CSTRING(256)
LocFromName  CSTRING(129)
LocReplyTo   CSTRING(256)
LocClientId  CSTRING(256)
LocSecret    CSTRING(256)
LocTenant    CSTRING(129)
LocApiKey    CSTRING(513)
LocApiDomain CSTRING(129)
LocTimeout   LONG
LocVerify    BYTE
LocStatus    CSTRING(129)
LocTokenInfo CSTRING(129)
Saved        BYTE

ProviderQ    QUEUE
PName          STRING(30)
PId            BYTE
             END
TransportQ   QUEUE
TName          STRING(34)
TId            BYTE
             END
SecurityQ    QUEUE
SName          STRING(34)
SId            BYTE
             END
AuthQ        QUEUE
AName          STRING(34)
AId            BYTE
             END
!  The log the window shows.  It is a REAL queue, filled from Net.TraceQ, not
!  FROM(SELF.Net.TraceQ): a LIST cannot be pointed at a queue REFERENCE - the
!  control binds to the reference variable itself and the window faults on its
!  first paint (0xC000041D, a fault inside the window callback).
LogQ         QUEUE
LLine          STRING(512)
             END

Window WINDOW('Mail account setup'),AT(,,352,246),GRAY,SYSTEM,FONT('Segoe UI',9),CENTER,ICON(ICON:Application)
         SHEET,AT(4,4,344,214),USE(?Sheet)
           TAB('Account'),USE(?TabAccount)
             PROMPT('Provider:'),AT(10,24),USE(?PrProvider)
             LIST,AT(92,22,150,10),USE(?ListProvider),DROP(16),FROM(ProviderQ),FORMAT('110L(2)@s30@')
             PROMPT('Send using:'),AT(10,40),USE(?PrTransport)
             LIST,AT(92,38,150,10),USE(?ListTransport),DROP(6),FROM(TransportQ),FORMAT('110L(2)@s34@')
             LINE,AT(10,56,332,0),USE(?Line1),COLOR(COLOR:Silver)
             PROMPT('From address:'),AT(10,64),USE(?PrFrom)
             ENTRY(@s255),AT(92,62,150,10),USE(LocFrom)
             PROMPT('From name:'),AT(10,80),USE(?PrFromName)
             ENTRY(@s128),AT(92,78,150,10),USE(LocFromName)
             PROMPT('Reply to:'),AT(10,96),USE(?PrReplyTo)
             ENTRY(@s255),AT(92,94,150,10),USE(LocReplyTo)
             LINE,AT(10,112,332,0),USE(?Line2),COLOR(COLOR:Silver)
             PROMPT('Server:'),AT(10,120),USE(?PrServer)
             ENTRY(@s128),AT(92,118,150,10),USE(LocHost)
             PROMPT('Port:'),AT(10,136),USE(?PrPort)
             ENTRY(@n5),AT(92,134,40,10),USE(LocPort)
             PROMPT('Security:'),AT(148,136),USE(?PrSecurity)
             LIST,AT(196,134,146,10),USE(?ListSecurity),DROP(5),FROM(SecurityQ),FORMAT('110L(2)@s34@')
             PROMPT('Sign in with:'),AT(10,152),USE(?PrAuth)
             LIST,AT(92,150,150,10),USE(?ListAuth),DROP(6),FROM(AuthQ),FORMAT('110L(2)@s34@')
             PROMPT('User name:'),AT(10,168),USE(?PrUser)
             ENTRY(@s255),AT(92,166,150,10),USE(LocUser)
             PROMPT('Password:'),AT(10,184),USE(?PrPass)
             ENTRY(@s255),AT(92,182,150,10),USE(LocPass),PASSWORD
             STRING(''),AT(250,184,92,20),USE(?PassNote),FONT(,7),COLOR(COLOR:None)
           END
           TAB('Sign-in (OAuth2)'),USE(?TabOAuth)
             STRING('Register a DESKTOP application with the provider and paste its Client ID'),AT(10,22),USE(?OaNote1),FONT(,8)
             STRING('here. Nothing secret is compiled into your program.'),AT(10,32),USE(?OaNote2),FONT(,8)
             PROMPT('Client ID:'),AT(10,52),USE(?PrClientId)
             ENTRY(@s255),AT(92,50,250,10),USE(LocClientId)
             PROMPT('Client secret:'),AT(10,68),USE(?PrSecret)
             ENTRY(@s255),AT(92,66,250,10),USE(LocSecret),PASSWORD
             STRING('(leave blank for Microsoft, and for Google desktop clients that have none)'),AT(92,79),USE(?SecretNote),FONT(,7)
             PROMPT('Tenant:'),AT(10,94),USE(?PrTenant)
             ENTRY(@s128),AT(92,92,150,10),USE(LocTenant)
             STRING('(Microsoft only: common, organizations, or your tenant GUID)'),AT(92,105),USE(?TenantNote),FONT(,7)
             BUTTON('Sign in...'),AT(92,122,90,14),USE(?SignIn)
             STRING(@s128),AT(190,126,152,10),USE(LocTokenInfo),FONT(,8)
             LINE,AT(10,146,332,0),USE(?Line3),COLOR(COLOR:Silver)
             PROMPT('API key:'),AT(10,156),USE(?PrApiKey)
             ENTRY(@s255),AT(92,154,250,10),USE(LocApiKey),PASSWORD
             PROMPT('API domain:'),AT(10,172),USE(?PrApiDomain)
             ENTRY(@s128),AT(92,170,150,10),USE(LocApiDomain)
             STRING('(Mailgun only: the domain you send from)'),AT(92,183),USE(?DomainNote),FONT(,7)
           END
           TAB('Advanced'),USE(?TabAdvanced)
             PROMPT('Account name:'),AT(10,24),USE(?PrName)
             ENTRY(@s64),AT(92,22,150,10),USE(LocName)
             STRING('(the label these settings are stored under)'),AT(92,35),USE(?NameNote),FONT(,7)
             PROMPT('Timeout (ms):'),AT(10,52),USE(?PrTimeout)
             ENTRY(@n7),AT(92,50,60,10),USE(LocTimeout)
             CHECK('Check the server certificate'),AT(92,68),USE(LocVerify)
             STRING('Turn this off ONLY for a server with a self-signed certificate on'),AT(92,80),USE(?VerifyNote1),FONT(,7)
             STRING('your own network. It disables the protection TLS gives you.'),AT(92,89),USE(?VerifyNote2),FONT(,7)
           END
           TAB('Log'),USE(?TabLog)
             LIST,AT(10,22,332,182),USE(?ListLog),FROM(LogQ),FORMAT('320L(2)@s255@'),VSCROLL,HSCROLL,FONT('Consolas',8)
           END
         END
         BUTTON('Test account'),AT(6,224,72,16),USE(?Test)
         STRING(@s128),AT(84,228,150,10),USE(LocStatus),FONT(,8)
         BUTTON('Save'),AT(240,224,52,16),USE(?Ok),DEFAULT
         BUTTON('Cancel'),AT(296,224,52,16),USE(?CancelBtn),STD(STD:Close)
       END

  CODE
  DO FillLists
  DO AccToLocal
  OPEN(Window)
  DO Localise
  DO Reflect
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      DO Reflect
    END
    CASE FIELD()
    OF ?ListProvider
      IF EVENT() = EVENT:NewSelection
        DO LocalToAcc
        GET(ProviderQ, CHOICE(?ListProvider))
        IF NOT ERRORCODE()
          SELF.SetProvider(ProviderQ.PId)
          DO AccToLocal
          DO Reflect
          DISPLAY()
        END
      END
    OF ?ListTransport OROF ?ListAuth
      IF EVENT() = EVENT:NewSelection
        DO Reflect
        DISPLAY()
      END
    OF ?SignIn
      IF EVENT() = EVENT:Accepted
        DO LocalToAcc
        LocStatus = SELF.Txt(ETTxt:WaitBrowser)
        DISPLAY()
        SETCURSOR(CURSOR:Wait)
        IF SELF.Authorize()
          SETCURSOR()
          LocStatus = SELF.Txt(ETTxt:SignedIn)
          DO AccToLocal
        ELSE
          SETCURSOR()
          LocStatus = SELF.Txt(ETTxt:SignInFailed)
          IF NOT SELF.Silent
            MESSAGE(CLIP(SELF.LastErrorText), SELF.Txt(ETTxt:SignInFailed), ICON:Exclamation)
          END
        END
        DO RefreshLog
        DO Reflect
        DISPLAY()
      END
    OF ?Test
      IF EVENT() = EVENT:Accepted
        DO LocalToAcc
        LocStatus = SELF.Txt(ETTxt:Testing)
        DISPLAY()
        SETCURSOR(CURSOR:Wait)
        SELF.Trace = 1
        IF SELF.TestAccount()
          SETCURSOR()
          LocStatus = SELF.Txt(ETTxt:TestOk)
        ELSE
          SETCURSOR()
          LocStatus = SELF.Txt(ETTxt:TestFailed)
          IF NOT SELF.Silent
            MESSAGE(CLIP(SELF.LastErrorText), SELF.Txt(ETTxt:TestFailed), ICON:Exclamation)
          END
        END
        DO RefreshLog
        SELECT(?TabLog)
        DISPLAY()
      END
    OF ?Ok
      IF EVENT() = EVENT:Accepted
        DO LocalToAcc
        SELF.SaveAccount()
        Saved = 1
        POST(EVENT:CloseWindow)
      END
    END
  END
  CLOSE(Window)
  RETURN Saved

RefreshLog ROUTINE
  DATA
n LONG
  CODE
  FREE(LogQ)
  IF SELF.Net.TraceQ &= NULL THEN EXIT.
  LOOP n = 1 TO RECORDS(SELF.Net.TraceQ)
    GET(SELF.Net.TraceQ, n)
    LogQ.LLine = SELF.Net.TraceQ.Line
    ADD(LogQ)
  END

FillLists ROUTINE
  FREE(ProviderQ)
  DO AddProviders
  FREE(TransportQ)
  TransportQ.TName = 'SMTP server';                        TransportQ.TId = ETTrn:Smtp;     ADD(TransportQ)
  TransportQ.TName = 'Gmail API (https)';                  TransportQ.TId = ETTrn:GmailApi; ADD(TransportQ)
  TransportQ.TName = 'Microsoft Graph (https)';            TransportQ.TId = ETTrn:GraphApi; ADD(TransportQ)
  TransportQ.TName = 'Provider API key (https)';           TransportQ.TId = ETTrn:ApiKey;   ADD(TransportQ)
  FREE(SecurityQ)
  SecurityQ.SName = 'None (plain, port 25)';               SecurityQ.SId = ETSec:None;     ADD(SecurityQ)
  SecurityQ.SName = 'STARTTLS (port 587)';                 SecurityQ.SId = ETSec:StartTls; ADD(SecurityQ)
  SecurityQ.SName = 'TLS / SSL (port 465)';                SecurityQ.SId = ETSec:Tls;      ADD(SecurityQ)
  FREE(AuthQ)
  AuthQ.AName = 'Nothing (open relay)';                    AuthQ.AId = ETAuth:None;    ADD(AuthQ)
  AuthQ.AName = 'Password (AUTH LOGIN)';                   AuthQ.AId = ETAuth:Login;   ADD(AuthQ)
  AuthQ.AName = 'Password (AUTH PLAIN)';                   AuthQ.AId = ETAuth:Plain;   ADD(AuthQ)
  AuthQ.AName = 'OAuth2 token (XOAUTH2)';                  AuthQ.AId = ETAuth:XOAuth2; ADD(AuthQ)

AddProviders ROUTINE
  DATA
p BYTE
  CODE
  LOOP p = 0 TO 15
    ProviderQ.PName = SELF.ProviderName(p)
    ProviderQ.PId   = p
    ADD(ProviderQ)
  END

Localise ROUTINE
  Window{PROP:Text}        = SELF.Txt(ETTxt:Setup)
  ?PrProvider{PROP:Text}   = SELF.Txt(ETTxt:Provider)
  ?PrTransport{PROP:Text}  = SELF.Txt(ETTxt:Transport)
  ?PrServer{PROP:Text}     = SELF.Txt(ETTxt:Server)
  ?PrPort{PROP:Text}       = SELF.Txt(ETTxt:Port)
  ?PrSecurity{PROP:Text}   = SELF.Txt(ETTxt:Security)
  ?PrAuth{PROP:Text}       = SELF.Txt(ETTxt:AuthMethod)
  ?PrUser{PROP:Text}       = SELF.Txt(ETTxt:UserName)
  ?PrPass{PROP:Text}       = SELF.Txt(ETTxt:Password)
  ?PrFrom{PROP:Text}       = SELF.Txt(ETTxt:FromAddress)
  ?PrFromName{PROP:Text}   = SELF.Txt(ETTxt:FromName)
  ?PrReplyTo{PROP:Text}    = SELF.Txt(ETTxt:ReplyTo)
  ?PrClientId{PROP:Text}   = SELF.Txt(ETTxt:ClientId)
  ?PrSecret{PROP:Text}     = SELF.Txt(ETTxt:ClientSecret)
  ?PrTenant{PROP:Text}     = SELF.Txt(ETTxt:Tenant)
  ?PrApiKey{PROP:Text}     = SELF.Txt(ETTxt:ApiKey)
  ?SignIn{PROP:Text}       = SELF.Txt(ETTxt:SignIn)
  ?Test{PROP:Text}         = SELF.Txt(ETTxt:SendTest)
  ?Ok{PROP:Text}           = SELF.Txt(ETTxt:Save)
  ?CancelBtn{PROP:Text}    = SELF.Txt(ETTxt:Cancel)
  ?TabLog{PROP:Text}       = SELF.Txt(ETTxt:Log)
  ?TabAccount{PROP:Text}   = SELF.Txt(ETTxt:Account)
  ?OaNote1{PROP:Text}      = SELF.Txt(ETTxt:BrowserNote)

AccToLocal ROUTINE
  LocName      = SELF.Acc.Name
  LocHost      = SELF.Acc.Host
  LocPort      = SELF.Acc.Port
  LocUser      = SELF.Acc.UserName
  LocPass      = SELF.Acc.Password
  LocFrom      = SELF.Acc.FromAddr
  LocFromName  = SELF.Acc.FromName
  LocReplyTo   = SELF.Acc.ReplyTo
  LocClientId  = SELF.Acc.ClientId
  LocSecret    = SELF.Acc.ClientSecret
  LocTenant    = SELF.Acc.TenantId
  LocApiKey    = SELF.Acc.ApiKey
  LocApiDomain = SELF.Acc.ApiDomain
  LocTimeout   = CHOOSE(SELF.Acc.Timeout > 0, SELF.Acc.Timeout, 30000)
  LocVerify    = SELF.Acc.VerifyCert
  DO SelectLists

SelectLists ROUTINE
  DATA
i LONG
  CODE
  LOOP i = 1 TO RECORDS(ProviderQ)
    GET(ProviderQ, i)
    IF ProviderQ.PId = SELF.Acc.Provider
      ?ListProvider{PROP:Selected} = i
      BREAK
    END
  END
  LOOP i = 1 TO RECORDS(TransportQ)
    GET(TransportQ, i)
    IF TransportQ.TId = SELF.Acc.Transport
      ?ListTransport{PROP:Selected} = i
      BREAK
    END
  END
  LOOP i = 1 TO RECORDS(SecurityQ)
    GET(SecurityQ, i)
    IF SecurityQ.SId = SELF.Acc.Security
      ?ListSecurity{PROP:Selected} = i
      BREAK
    END
  END
  LOOP i = 1 TO RECORDS(AuthQ)
    GET(AuthQ, i)
    IF AuthQ.AId = SELF.Acc.AuthMode
      ?ListAuth{PROP:Selected} = i
      BREAK
    END
  END

LocalToAcc ROUTINE
  SELF.Acc.Name         = LocName
  SELF.Acc.Host         = LocHost
  SELF.Acc.Port         = LocPort
  SELF.Acc.UserName     = LocUser
  SELF.Acc.Password     = LocPass
  SELF.Acc.FromAddr     = LocFrom
  SELF.Acc.FromName     = LocFromName
  SELF.Acc.ReplyTo      = LocReplyTo
  SELF.Acc.ClientId     = LocClientId
  SELF.Acc.ClientSecret = LocSecret
  SELF.Acc.TenantId     = LocTenant
  SELF.Acc.ApiKey       = LocApiKey
  SELF.Acc.ApiDomain    = LocApiDomain
  SELF.Acc.Timeout      = LocTimeout
  SELF.Acc.VerifyCert   = LocVerify
  IF CHOICE(?ListProvider) > 0
    GET(ProviderQ, CHOICE(?ListProvider))
    IF NOT ERRORCODE() THEN SELF.Acc.Provider = ProviderQ.PId.
  END
  IF CHOICE(?ListTransport) > 0
    GET(TransportQ, CHOICE(?ListTransport))
    IF NOT ERRORCODE() THEN SELF.Acc.Transport = TransportQ.TId.
  END
  IF CHOICE(?ListSecurity) > 0
    GET(SecurityQ, CHOICE(?ListSecurity))
    IF NOT ERRORCODE() THEN SELF.Acc.Security = SecurityQ.SId.
  END
  IF CHOICE(?ListAuth) > 0
    GET(AuthQ, CHOICE(?ListAuth))
    IF NOT ERRORCODE() THEN SELF.Acc.AuthMode = AuthQ.AId.
  END

!  Grey out whatever this combination of transport and sign-in does not use, so
!  nobody fills in an API key for an SMTP account and wonders why it is ignored.
Reflect ROUTINE
  DATA
trn  BYTE
auth BYTE
smtp BYTE
oa   BYTE
  CODE
  trn  = ETTrn:Smtp
  auth = ETAuth:Login
  IF CHOICE(?ListTransport) > 0
    GET(TransportQ, CHOICE(?ListTransport))
    IF NOT ERRORCODE() THEN trn = TransportQ.TId.
  END
  IF CHOICE(?ListAuth) > 0
    GET(AuthQ, CHOICE(?ListAuth))
    IF NOT ERRORCODE() THEN auth = AuthQ.AId.
  END
  smtp = CHOOSE(trn = ETTrn:Smtp, 1, 0)
  oa   = CHOOSE(trn = ETTrn:GmailApi OR trn = ETTrn:GraphApi OR |
                (smtp = 1 AND auth = ETAuth:XOAuth2), 1, 0)

  ?LocHost{PROP:Disable}      = 1 - smtp
  ?LocPort{PROP:Disable}      = 1 - smtp
  ?ListSecurity{PROP:Disable} = 1 - smtp
  ?ListAuth{PROP:Disable}     = 1 - smtp
  ?LocPass{PROP:Disable}      = CHOOSE(smtp = 1 AND (auth = ETAuth:Login OR auth = ETAuth:Plain), 0, 1)
  ?LocClientId{PROP:Disable}  = 1 - oa
  ?LocSecret{PROP:Disable}    = 1 - oa
  ?LocTenant{PROP:Disable}    = 1 - oa
  ?SignIn{PROP:Disable}       = 1 - oa
  ?LocApiKey{PROP:Disable}    = CHOOSE(trn = ETTrn:ApiKey, 0, 1)
  ?LocApiDomain{PROP:Disable} = CHOOSE(trn = ETTrn:ApiKey, 0, 1)

  IF CLIP(SELF.Acc.RefreshToken)
    LocTokenInfo = 'Signed in - a refresh token is stored.'
    IF SELF.Language = ETLng:Spanish
      LocTokenInfo = 'Sesi<243>n guardada.'
    END
  ELSE
    LocTokenInfo = ''
  END
  IF smtp = 1 AND (auth = ETAuth:Login OR auth = ETAuth:Plain)
    CASE SELF.Acc.Provider
    OF ETPrv:Gmail OROF ETPrv:Yahoo OROF ETPrv:ICloud
      ?PassNote{PROP:Text} = 'Use an APP PASSWORD, not your normal one.'
    ELSE
      ?PassNote{PROP:Text} = ''
    END
  ELSE
    ?PassNote{PROP:Text} = ''
  END

! ============================================================================
!  Compose - a small write-and-send window, for a button that has no window of
!  its own to put the fields on.
! ============================================================================
EmailToClass.Compose PROCEDURE(<STRING pTo>,<STRING pSubject>,<STRING pBody>,<STRING pAttach>)
LocTo      CSTRING(1025)
LocCc      CSTRING(1025)
LocSubject CSTRING(513)
LocBody    CSTRING(8193)
LocFile    CSTRING(261)
Sent       BYTE
i          LONG

AttachQ    QUEUE
AFile        STRING(260)
           END

Window WINDOW('Write a message'),AT(,,320,236),GRAY,SYSTEM,FONT('Segoe UI',9),CENTER,ICON(ICON:Application)
         PROMPT('To:'),AT(8,10),USE(?PrTo)
         ENTRY(@s255),AT(58,8,254,10),USE(LocTo)
         PROMPT('Cc:'),AT(8,26),USE(?PrCc)
         ENTRY(@s255),AT(58,24,254,10),USE(LocCc)
         PROMPT('Subject:'),AT(8,42),USE(?PrSubject)
         ENTRY(@s255),AT(58,40,254,10),USE(LocSubject)
         PROMPT('Message:'),AT(8,58),USE(?PrBody)
         TEXT,AT(58,56,254,110),USE(LocBody),VSCROLL,FONT('Segoe UI',9)
         PROMPT('Attachments:'),AT(8,172),USE(?PrAttach)
         LIST,AT(58,170,190,32),USE(?ListAttach),FROM(AttachQ),FORMAT('180L(2)@s260@'),VSCROLL
         BUTTON('Add file...'),AT(252,170,60,14),USE(?AddFile)
         BUTTON('Remove'),AT(252,188,60,14),USE(?RemoveFile)
         BUTTON('Send'),AT(206,212,52,16),USE(?SendBtn),DEFAULT
         BUTTON('Cancel'),AT(262,212,52,16),USE(?CancelBtn),STD(STD:Close)
       END

  CODE
  IF NOT OMITTED(pTo)      THEN LocTo      = CLIP(pTo).
  IF NOT OMITTED(pSubject) THEN LocSubject = CLIP(pSubject).
  IF NOT OMITTED(pBody)    THEN LocBody    = CLIP(pBody).
  IF NOT OMITTED(pAttach) AND CLIP(pAttach)
    AttachQ.AFile = CLIP(pAttach)
    ADD(AttachQ)
  END

  OPEN(Window)
  Window{PROP:Text}     = SELF.Txt(ETTxt:Compose)
  ?PrTo{PROP:Text}      = SELF.Txt(ETTxt:To)
  ?PrCc{PROP:Text}      = SELF.Txt(ETTxt:Cc)
  ?PrSubject{PROP:Text} = SELF.Txt(ETTxt:Subject)
  ?PrBody{PROP:Text}    = SELF.Txt(ETTxt:Message)
  ?PrAttach{PROP:Text}  = SELF.Txt(ETTxt:Attach)
  ?AddFile{PROP:Text}   = SELF.Txt(ETTxt:AddFile)
  ?RemoveFile{PROP:Text}= SELF.Txt(ETTxt:Remove)
  ?SendBtn{PROP:Text}   = SELF.Txt(ETTxt:Send)
  ?CancelBtn{PROP:Text} = SELF.Txt(ETTxt:Cancel)

  ACCEPT
    CASE FIELD()
    OF ?AddFile
      IF EVENT() = EVENT:Accepted
        LocFile = ''
        IF FILEDIALOG(SELF.Txt(ETTxt:AddFile), LocFile, |
                      'All files|*.*|PDF|*.pdf|Images|*.png;*.jpg;*.gif', |
                      FILE:KeepDir + FILE:LongName)
          AttachQ.AFile = LocFile
          ADD(AttachQ)
          DISPLAY(?ListAttach)
        END
      END
    OF ?RemoveFile
      IF EVENT() = EVENT:Accepted
        IF CHOICE(?ListAttach) > 0
          GET(AttachQ, CHOICE(?ListAttach))
          IF NOT ERRORCODE()
            DELETE(AttachQ)
            DISPLAY(?ListAttach)
          END
        END
      END
    OF ?SendBtn
      IF EVENT() = EVENT:Accepted
        IF NOT CLIP(LocTo)
          MESSAGE(SELF.Txt(ETTxt:NeedTo), SELF.Txt(ETTxt:Compose), ICON:Exclamation)
          SELECT(?LocTo)
          CYCLE
        END
        IF NOT CLIP(LocSubject)
          IF MESSAGE(SELF.Txt(ETTxt:NeedSubject), SELF.Txt(ETTxt:Compose), |
                     ICON:Question, BUTTON:Yes + BUTTON:No, BUTTON:No) = BUTTON:No
            SELECT(?LocSubject)
            CYCLE
          END
        END
        SELF.Msg.ClearAll()
        SELF.Msg.AddList(LocTo, ETAddr:To)
        IF CLIP(LocCc) THEN SELF.Msg.AddList(LocCc, ETAddr:Cc).
        SELF.Msg.SetSubject(LocSubject)
        SELF.Msg.SetText(LocBody)
        LOOP i = 1 TO RECORDS(AttachQ)
          GET(AttachQ, i)
          SELF.Msg.Attach(AttachQ.AFile)
        END
        SETCURSOR(CURSOR:Wait)
        IF SELF.Send(SELF.Msg)
          SETCURSOR()
          Sent = 1
          IF NOT SELF.Silent
            MESSAGE(SELF.Txt(ETTxt:Sent), SELF.Txt(ETTxt:Compose), ICON:Asterisk)
          END
          POST(EVENT:CloseWindow)
        ELSE
          SETCURSOR()
          SELF.ShowError()
        END
      END
    END
  END
  CLOSE(Window)
  FREE(AttachQ)
  RETURN Sent
