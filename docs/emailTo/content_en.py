# -*- coding: latin-1 -*-
"""The English content of the four volumes.

Spanish lives in content_es.py, built from the same shell with the same
heading ids, so the two sets stay structurally identical and the drift checks
apply to both.
"""
import sys
import os

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from shell import (esc, slug, code, usecode, note, table, h2, h3, p,   # noqa: E402
                   nextcards, page, PROBLEMS, EXAMPLES, extract)
from lang import PAGE_TITLES, T                                        # noqa: E402

# =====================================================================
#  1  GETTING STARTED
# =====================================================================
S_HELLO = """
  PROGRAM

  INCLUDE('EmailToClass.INC'),ONCE

  MAP
  END

Mailer  EmailToClass

  CODE
  Mailer.Init(PATH() & '\\mail.ini')          ! where the account is remembered

  Mailer.SetProvider(ETPrv:Gmail)             ! host, port, security, sign-in
  Mailer.Acc.UserName = 'you@gmail.com'
  Mailer.Acc.Password = 'abcd efgh ijkl mnop' ! a Google APP PASSWORD, not your own
  Mailer.Acc.FromAddr = 'you@gmail.com'
  Mailer.Acc.FromName = 'Acme Dispatch'

  IF Mailer.SendSimple('bob@example.com', 'It works', 'Sent from Clarion.')
    MESSAGE('Sent.')
  ELSE
    MESSAGE(CLIP(Mailer.LastErrorText))
  END
"""

S_ASK = """
  PROGRAM

  INCLUDE('EmailApiClass.INC'),ONCE

  MAP
  END

Mailer   EmailToClass
MailApi  EmailApiClass
i        LONG

  CODE
  Mailer.Init(PATH() & '\\mail.ini')
  Mailer.LoadAccount()                        ! the key you stored in Setup
  MailApi.Init(Mailer)                        ! borrows that account - no second copy

  IF MailApi.GetSuppressions(ETSup:All) < 0
    MESSAGE(CLIP(MailApi.LastErrorText))
  ELSE
    LOOP i = 1 TO RECORDS(MailApi.SuppQ)
      GET(MailApi.SuppQ, i)
      !  MailApi.SuppQ.Address   who
      !  MailApi.SuppQ.KindName  bounce / blocked / spam report / unsubscribed
      !  MailApi.SuppQ.Reason    what the receiving server actually said
      !  MailApi.SuppQ.WhenDate  when
    END
  END
"""

S_SUPPORTS = """
  IF NOT MailApi.Supports(ETOp:Campaigns)
    DISABLE(?Campaigns)                       ! Mailgun has no campaign API at all
  END
  IF NOT MailApi.Supports(ETOp:Suppressions)
    DISABLE(?Blocked)                         ! Resend keeps no block list
  END
"""

S_MATRIX = """
  SELF.Row(ETPrv:SendGrid, ETOp:Suppressions, ETSup:Bounce, 'GET', |
           '{scheme}{host}/v3/suppression/bounces?limit={limit}&offset={offset}', '', |
           'Address=email;Reason=reason;Id=status;When=#created')

  SELF.Row(ETPrv:Brevo, ETOp:Suppressions, ETSup:All, 'GET', |
           '{scheme}{host}/v3/smtp/blockedContacts?limit={limit}&offset={offset}', |
           'contacts', |
           'Address=email;Reason=reason.message;KindText=reason.code;When=@blockedAt')
"""

S_ADDPROVIDER = """
MyApiClass  CLASS(EmailApiClass)
BuildMap      PROCEDURE(),DERIVED
            END

MyApiClass.BuildMap PROCEDURE()
  CODE
  PARENT.BuildMap()                           ! keep the eight that are already there
  SELF.Row(ETPrv:Custom, ETOp:Suppressions, ETSup:All, 'GET', |
           '{scheme}{host}/api/blocked?page={page}', 'rows', |
           'Address=addr;Reason=why;When=@stamp')
  SELF.Row(ETPrv:Custom, ETOp:SuppDelete, ETSup:All, 'DELETE', |
           '{scheme}{host}/api/blocked/{email}')
"""

S_APIEMBED = """
  Loc:Rows = MailApi.GetSuppressions(0)
  IF MailApi.LastError
    MailApi.ShowError()
  END
"""

S_SYNCGEN = """
MailApi          CLASS(EmailApiClass)              ! the object, writing into your tables
SyncTables         PROCEDURE(BYTE pSilent=0),LONG,PROC,DERIVED
                 END

!  ... and, generated beside it:

MailApi.SyncTables PROCEDURE(BYTE pSilent)
  CODE
  DO ETySyncBlocked                               ! one routine per table you nominated
  DO ETySyncStats
  ...

ETySyncBlocked ROUTINE
  ETyN = SELF.GetSuppressions(ETSup:All)
  IF ETyN < 0 THEN ETyBad = 1; EXIT.
  Access:MailBlocked.Open()
  Access:MailBlocked.UseFile()
  LOOP ETyi = 1 TO RECORDS(SELF.SuppQ)
    GET(SELF.SuppQ, ETyi)
    CLEAR(MailBlocked:Record)
    DO ETyMapBlocked
    GET(MailBlocked, MBL:ByAddress)               ! already there?
    IF ERRORCODE()
      CLEAR(MailBlocked:Record); DO ETyMapBlocked
      ADD(MailBlocked)
    ELSE
      DO ETyMapBlocked
      PUT(MailBlocked)                            ! update, never duplicate
    END
  END
  Access:MailBlocked.Close()

ETyMapBlocked ROUTINE
  MBL:Address   = SELF.SuppQ.Address
  MBL:Kind      = SELF.SuppQ.Kind
  MBL:Reason    = SELF.SuppQ.Reason
  MBL:BlockedOn = SELF.SuppQ.WhenDate
  MBL:Provider  = SELF.Mailer.Acc.Provider
  MBL:SyncedOn  = TODAY()
"""

S_PROJECT = """<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <DefineConstants>_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3b_emailToDllMode_=&gt;0%3b_emailToLinkMode_=&gt;1</DefineConstants>
  </PropertyGroup>
</Project>"""

S_ATTACH = """
  Mailer.Msg.ClearAll()
  Mailer.Msg.AddTo('bob@example.com', 'Bob Smith')
  Mailer.Msg.AddCc('accounts@acme.com')
  Mailer.Msg.SetSubject('Invoice ' & CLIP(Inv:Number))
  Mailer.Msg.SetText('The invoice is attached.')
  Mailer.Msg.SetHtml('<p>The invoice is <b>attached</b>.</p>')
  Mailer.Msg.Attach('C:\\invoices\\INV-1042.pdf')

  IF NOT Mailer.Send(Mailer.Msg)
    Mailer.ShowError()
  END
"""


S_OAUTHRUN = """
  Mailer.SetProvider(ETPrv:Office365)         ! or ETPrv:Gmail, or ETPrv:Outlook
  Mailer.Acc.Transport = ETTrn:GraphApi       ! or ETTrn:Smtp with AuthMode XOAUTH2
  Mailer.Acc.ClientId  = '11111111-2222-3333-4444-555555555555'
  Mailer.Acc.TenantId  = 'common'
  Mailer.Acc.UserName  = 'you@company.com'
  Mailer.Acc.FromAddr  = 'you@company.com'

  IF Mailer.Authorize()                       ! browser opens, user consents
    Mailer.SaveAccount()                      ! keeps the refresh token, sealed
    MESSAGE('Signed in.')
  ELSE
    MESSAGE(CLIP(Mailer.LastErrorText))
  END
"""


def build_getting_started():
    B = []
    add = B.append

    add(h2('what', 'What emailTo is'))
    add(p('emailTo sends e-mail from a Clarion application, and manages the account '
          'it sends through. It is five classes, one bundled C file and seven '
          'templates, and it deploys as part of your <code>.EXE</code> &mdash; there is '
          'no DLL to ship, no .NET, no OpenSSL and nothing to register on the machine '
          'it runs on.'))
    add(p('It can put a message on the wire four ways, and they all send the same '
          'message: <b>SMTP</b> over plain, STARTTLS or implicit TLS; the <b>Gmail '
          'API</b>; <b>Microsoft Graph</b>; or a provider <b>API key</b> for SendGrid, '
          'Mailgun, Resend, Brevo, Postmark, Mailjet, SparkPost, MailerSend and '
          '<b>Amazon SES</b>.'))
    add(p('Those nine API providers answer questions as well as taking messages, and '
          'the same account asks them: <b>who is blocked and why</b>, what the last '
          'month looked like, which contacts and campaigns exist. One set of methods '
          'covers all nine &mdash; see <a href="#ask">Who is blocked, and why</a>.'))
    add(table(['You have', 'Use', 'What you need'], [
        ['A Gmail account', 'SMTP + app password', 'Two-factor on, then an app password'],
        ['Outlook.com or Hotmail', 'SMTP + OAuth2', 'A desktop client ID from Azure'],
        ['Microsoft 365 at work', 'Graph, or SMTP + OAuth2', 'A desktop client ID, and your tenant'],
        ['A company mail server', 'SMTP + password', 'Host, port, and whether it wants STARTTLS'],
        ['None of the above', 'An API key service', 'A free key from Resend or Brevo'],
    ]))

    add(h2('install', 'Install'))
    add(p('Copy these eleven files to a folder on the Clarion redirection path &mdash; '
          'the application folder, or <code>\\clarion12\\accessory\\libsrc\\win</code>:'))
    add(table(['File', 'What it is'], [
        ['<code>EmailNetClass.inc</code> / <code>.clw</code>',
         'Sockets, TLS, HTTPS, DPAPI. Compiles the C in.'],
        ['<code>EmailMsgClass.inc</code> / <code>.clw</code>',
         'The message and its MIME. Pure Clarion.'],
        ['<code>EmailToClass.inc</code> / <code>.clw</code>',
         'Accounts, the four transports, OAuth2, the windows.'],
        ['<code>EmailJsonClass.inc</code> / <code>.clw</code>',
         'Reading what a provider answers. Pure Clarion.'],
        ['<code>EmailApiClass.inc</code> / <code>.clw</code>',
         'The management API: blocked, statistics, campaigns.'],
        ['<code>emailc.c</code>',
         'Winsock, SCHANNEL, WinHTTP, DPAPI, SHA-256.'],
    ]))
    add(note('tip', 'And a dictionary, if you want the answers kept',
             '<p><code>emailToTables.dctx</code> ships with them: seven tables &mdash; '
             'the blocked list, statistics, activity, contacts, lists, campaigns, and '
             'the account itself. Dictionary Editor &rarr; <b>File &rarr; Import</b>, and '
             'pick the <b>DCTX / XML</b> entry. You only need it if you add the '
             '<b>emailTo - Sync</b> extension; sending and the management window do not '
             'use it.</p>'
             '<p><b>Not</b> the <code>.txd</code> beside it &mdash; that is Report '
             'Writer&rsquo;s format, and the Dictionary Editor says so in as many '
             'words.</p>'))
    add(p('Put <code>emailTo.tpl</code> in <code>\\clarion12\\accessory\\template\\win</code> '
          'and register it &mdash; in the IDE, or from a command line:'))
    add(code('ClarionCL.exe -tr "C:\\clarion12\\accessory\\template\\win\\emailTo.tpl"', 'dos'))
    add(note('warn', 'The sources must be ANSI, with CRLF line endings',
             '<p>Clarion mis-parses an LF-only include: you get '
             '<code>Illegal data type: EMAILTOCLASS</code> reported at the '
             '<em>declaration</em>, with nothing flagged inside the include itself. '
             'If you have moved these files through a tool that rewrites line endings, '
             'convert them back before hunting for a phantom syntax error.</p>'))

    add(h2('hello', 'The smallest thing that sends'))
    add(p('No template, no window, no dictionary. This is a complete program:'))
    add(code(S_HELLO))
    add(p('Two things are worth noticing. <code>SetProvider</code> fills in the host, '
          'the port, the security and the sign-in method for you, so the only lines '
          'left are the ones that are actually about your account. And nothing here '
          'checks a return code except the send itself &mdash; every failure ends up in '
          '<code>LastErrorText</code> as a sentence you can show a user.'))
    add(note('tip', 'Where the app password comes from',
             '<p>Google, Yahoo and iCloud will not accept your normal password from a '
             'program. Turn on two-factor authentication, then generate an '
             '<b>app password</b> &mdash; a sixteen-character string issued for one '
             'application. Paste that into <code>Acc.Password</code>. Outlook.com no '
             'longer offers this route at all: it is OAuth2 or nothing, which the '
             "Programmer's Guide covers.</p>"))

    add(h2('handcoded', 'Building it by hand'))
    add(p('The class files pull themselves into the build through their <code>LINK</code> '
          'attribute, and <code>EmailNetClass.clw</code> pulls in the C through its '
          '<code>PRAGMA</code>, so a hand-coded project needs no file list. It does need '
          'the two link-mode defines that the template would otherwise write for you:'))
    add(code(S_PROJECT, 'xml'))
    add(note('danger', 'Leaving the defines out does not fail to link',
             '<p>Without <code>_emailToLinkMode_</code> the classes link as '
             '<em>imports</em> from a DLL that is not there, and the program takes an '
             'access violation inside a constructor before <code>main()</code> runs. '
             'The call stack shows nothing of yours on it, so it looks like anything '
             'except a project setting.</p>'))

    add(h2('fromappgen', 'The same thing from AppGen'))
    add(p('Two steps, and no code:'))
    add('<ol class="b">'
        '<li><b>Global Properties &rarr; Extensions &rarr; Insert &rarr; emailTo - Global.</b> '
        'Fill in the Account tab: provider, from address, user name. That declares the '
        'object, sets the defaults and loads the stored account at start-up.</li>'
        '<li><b>Drag <i>emailTo - E-mail button</i> onto a window.</b> Choose what it '
        'does &mdash; open the compose window, send a fixed message, or open the account '
        'setup window &mdash; and you are finished.</li>'
        '</ol>')
    add(note('tip', 'The account is set once, not per button',
             '<p>Step 1 is where the sender lives &mdash; server, from address, user '
             'name, password, OAuth2 client. Step 2 never asks for any of it. That '
             'division is the whole point: put five e-mail buttons on five windows and '
             'there is still exactly one account, in one place, for the whole '
             'application.</p>'
             '<p>To let the <em>user</em> change it at run time, give them a button '
             'whose action is <b>open the account setup window</b>. What they save '
             'there overrides the Account tab.</p>'))
    add(p('From any embed anywhere else in the application, the object is simply there:'))
    add(usecode("Mailer.SendSimple(Cus:Email, 'Your statement', 'Attached.', Loc:PdfName)"))

    add(h2('attachments', 'A message with more in it'))
    add(p('<code>SendSimple</code> covers a note with one attachment. Anything richer is '
          'built on <code>Mailer.Msg</code> and handed to <code>Send</code>:'))
    add(code(S_ATTACH))
    add(p('You do not tell it what kind of MIME document to build. Text alone is '
          '<code>text/plain</code>; text and HTML together become '
          '<code>multipart/alternative</code>; an inline image makes it '
          '<code>multipart/related</code>; a file attachment wraps the lot in '
          '<code>multipart/mixed</code>. A plain note does not arrive as a four-part tree.'))

    add(h2('oauthsetup', 'Setting up OAuth2, step by step'))
    add(p('This is the part that stops people, and almost always for one of two reasons: '
          'the redirect URI does not match, or the application was registered as the '
          'wrong type. Both are fixed at the provider, not in your code.'))

    add(h3('oauth-google', 'Google'))
    add('<ol class="b">'
        '<li>Go to <b>console.cloud.google.com</b> and pick or create a project.</li>'
        '<li><b>APIs &amp; Services &rarr; OAuth consent screen.</b> Choose '
        '<b>External</b>, fill in the app name and your e-mail, and save. While it is in '
        '<b>Testing</b>, add your own address under <b>Test users</b> &mdash; a project in '
        'testing will refuse anybody who is not on that list.</li>'
        '<li>Add the scope you actually need: <code>https://mail.google.com/</code> for '
        'SMTP, or <code>https://www.googleapis.com/auth/gmail.send</code> for the Gmail '
        'API.</li>'
        '<li><b>Credentials &rarr; Create credentials &rarr; OAuth client ID</b>, and set '
        'Application type to <b>Desktop app</b>. Not Web application &mdash; a web client '
        'will not accept a loopback redirect.</li>'
        '<li>Copy the <b>Client ID</b> into the Sign-in tab. Google may also show a client '
        'secret; paste it if there is one, leave it blank if there is not. Neither is '
        'sensitive here, because the flow is PKCE.</li>'
        '</ol>')
    add(note('note', 'You do not register a redirect URI for a Google desktop client',
             '<p>Desktop clients may use any loopback port, so there is nothing to type. '
             'emailTo sends <code>http://127.0.0.1:&lt;port&gt;</code>, which is the form '
             'Google documents.</p>'))

    add(h3('oauth-microsoft', 'Microsoft &mdash; Outlook.com and Microsoft 365'))
    add('<ol class="b">'
        '<li>Go to <b>portal.azure.com &rarr; App registrations &rarr; New '
        'registration</b>.</li>'
        '<li>For supported account types pick <b>Accounts in any organizational directory '
        'and personal Microsoft accounts</b> if you want both work and Outlook.com; that '
        'is the one that matches a Tenant of <code>common</code>.</li>'
        '<li>Under <b>Redirect URI</b> choose the platform <b>Mobile and desktop '
        'applications</b> and tick <code>http://localhost</code>. This is the step people '
        'miss &mdash; leave the platform as Web and the sign-in is refused with a redirect '
        'URI error.</li>'
        '<li><b>Authentication &rarr; Allow public client flows &rarr; Yes.</b></li>'
        '<li><b>API permissions &rarr; Add a permission &rarr; Microsoft Graph &rarr; '
        'Delegated</b>. Add <code>Mail.Send</code> and <code>offline_access</code> for '
        'Graph, or <code>SMTP.Send</code> and <code>offline_access</code> for SMTP.</li>'
        '<li>Copy the <b>Application (client) ID</b> into the Sign-in tab. Leave the client '
        'secret <b>blank</b> &mdash; a public client that sends one is rejected.</li>'
        '</ol>')
    add(note('warn', 'Match the redirect host to what you registered',
             '<p>Because Azure offers <code>http://localhost</code> and Google documents '
             '<code>http://127.0.0.1</code>, emailTo sends whichever one suits the '
             'provider you picked. It listens on <b>both</b> loopbacks either way, so a '
             'browser that resolves <code>localhost</code> to <code>::1</code> &mdash; '
             'which is what Windows does first &mdash; still arrives. If you registered '
             'something different, say so:</p>'
             '<p><code>Mailer.OAuth.RedirectHost = \'127.0.0.1\'</code></p>'))

    add(h3('oauth-verify', 'Google says &ldquo;Access blocked&rdquo;'))
    add(p('<i>&ldquo;Access blocked: &lt;your app&gt; has not completed the Google '
          'verification process.&rdquo;</i> This is the consent screen refusing you, '
          'not emailTo failing, and it has two causes that produce almost the same '
          'wording. Which one you have is decided by your app&rsquo;s <b>publishing '
          'status</b>.'))
    add(table(['Publishing status', 'What the block means', 'What to do'], [
        ['<b>Testing</b>',
         'The account you are signing in with is not on the Test users list. The screen '
         'usually adds &ldquo;currently being tested&hellip; developer-approved '
         'testers&rdquo;.',
         'Google Auth Platform &rarr; <b>Audience</b> &rarr; <b>Test users</b> &rarr; '
         'Add users, and add the exact address you sign in with.'],
        ['<b>In production</b>, unverified, with <code>https://mail.google.com/</code>',
         'That is a <b>restricted</b> scope. Unverified, Google blocks it outright &mdash; '
         'there is no <i>Advanced</i> link to click past.',
         'Either go back to Testing and use Test users, or switch to the '
         '<code>gmail.send</code> scope.'],
        ['<b>In production</b>, unverified, with <code>gmail.send</code>',
         'That is a <b>sensitive</b> scope, so you get a warning rather than a block.',
         'Click <b>Advanced</b> &rarr; <b>Go to &lt;your app&gt;</b>. It is your own app; '
         'the warning is expected.'],
    ]))
    add(note('warn', 'Publishing is not automatically the fix',
             '<p>Staying in <b>Testing</b> has its own cost: Google expires a refresh '
             'token after <b>seven days</b>, so a sign-in that worked stops working the '
             'following week. Publishing removes that &mdash; but only helps if your '
             'scope is <code>gmail.send</code>. Publish while asking for '
             '<code>https://mail.google.com/</code> and you trade a weekly re-login for '
             'a permanent wall.</p>'
             '<p>So if you are going to use OAuth on Gmail, use the <b>Gmail API</b> '
             'transport. emailTo then asks for <code>gmail.send</code>, which is the '
             'narrower scope and the one you can publish unverified.</p>'))
    add(note('tip', 'For a single Gmail account, an app password avoids all of this',
             '<p>No consent screen, no verification, no seven-day expiry, and nothing to '
             'register. Turn on 2-Step Verification, generate an app password at '
             '<b>myaccount.google.com/apppasswords</b>, and use it as the SMTP password '
             '&mdash; <b>with the spaces removed</b>. OAuth earns its keep when you are '
             'shipping to other people&rsquo;s mailboxes, or when a Workspace admin has '
             'turned app passwords off.</p>'))

    add(h3('oauth-run', 'Running it'))
    add(p('Set the account to use OAuth, then press <b>Sign in&hellip;</b> in the setup '
          'window &mdash; or call it yourself:'))
    add(code(S_OAUTHRUN))
    add(p('Your browser opens at the provider. Sign in, agree to the permissions, and the '
          'page comes back saying you can close the tab. That is the whole of it: from '
          'then on the refresh token is stored and nobody sees a browser again.'))
    add(note('tip', 'When it fails, read the URL',
             '<p>The exact address that was opened is kept in '
             '<code>Mailer.OAuth.LastAuthUrl</code>, and it is written to the log. Paste '
             'it into a browser by hand and the provider will tell you precisely what it '
             'objects to &mdash; which beats guessing from a generic failure.</p>'))
    add(table(['What the provider says', 'What to change'], [
        ['<code>redirect_uri_mismatch</code>',
         'Google: the client is a Web application, not a Desktop app. Microsoft: the '
         'platform is Web, not Mobile and desktop.'],
        ['<code>invalid_client</code> / The OAuth client was not found',
         'The Client ID is wrong, or belongs to a different project or tenant.'],
        ['<code>unauthorized_client</code>',
         'Microsoft: <b>Allow public client flows</b> is still No.'],
        ['<code>access_denied</code>, and you are a test user',
         'Google: your address is not in Test users on the consent screen.'],
        ['Sign-in works, the second send asks again',
         'No refresh token was issued. Google needs the consent screen re-approved; '
         'emailTo already sends <code>access_type=offline&amp;prompt=consent</code>.'],
        ['The browser opens and nothing ever comes back',
         'Something is holding the loopback port. Pin one with '
         '<code>Mailer.OAuth.RedirectPort</code> and allow it through the firewall.'],
    ]))

    add(h2('ask', 'Who is blocked, and why'))
    add(p('Sending is half of what a mail provider does. The other half is keeping a '
          'list of the addresses it will not deliver to &mdash; the ones that hard '
          'bounced, the people who pressed "this is junk", the ones who unsubscribed. '
          'Left alone that list stays on their web site, and your program keeps mailing '
          'addresses that can never arrive, which is exactly what ruins a sending '
          'reputation.'))
    add(p('<code>EmailApiClass</code> reads it. One object, borrowing the account you '
          'already set up:'))
    add(code(S_ASK))
    add(p('That program works unchanged against all nine API providers. It has to, '
          'because they agree about almost nothing:'))
    add(table(['Provider', 'Where the blocked addresses are', 'What a row looks like'], [
        ['SendGrid', 'Five separate lists: bounces, blocks, spam_reports, '
                     'unsubscribes, invalid_emails',
         '<code>email</code>, <code>reason</code>, a unix <code>created</code>'],
        ['Brevo', 'One list, <code>/smtp/blockedContacts</code>, with a reason CODE '
                  'saying which kind it is',
         '<code>email</code>, <code>reason.message</code>, an ISO <code>blockedAt</code>'],
        ['Mailgun', 'Per DOMAIN, and paged with a cursor rather than an offset',
         '<code>address</code>, <code>error</code>, <code>code</code>, an RFC-2822 date'],
        ['Postmark', 'A stream dump, plus a richer <code>/bounces</code> for bounces alone',
         '<code>EmailAddress</code>, <code>SuppressionReason</code> &mdash; capitalised'],
        ['Mailjet', 'Everything wrapped in <code>Data</code>, capitalised throughout',
         '<code>ContactAlt</code>, <code>ErrorRelatedTo</code>, <code>ErrorCode</code>'],
        ['Amazon SES', 'Signed with SigV4 rather than a key in a header, and paged with '
         'a continuation token',
         '<code>EmailAddress</code>, <code>Reason</code> &mdash; BOUNCE or COMPLAINT'],
    ]))
    add(p('After <code>GetSuppressions()</code> they are one queue with the same '
          'columns, and <code>SuppQ.Kind</code> says which sort of block each row '
          'really is &mdash; worked out from the provider\'s own wording where the '
          'provider keeps them all in one list.'))
    add(note('tip', 'Ask before you send',
             '<p><code>IsBlocked()</code> searches whatever the last '
             '<code>GetSuppressions()</code> loaded. Calling it in the loop that builds '
             'a mailing costs nothing and stops you sending to an address the provider '
             'is going to refuse anyway:</p>'
             '<pre class="code"><code>IF MailApi.IsBlocked(CUS:EMail) THEN CYCLE.'
             '</code></pre>'))

    add(h2('ask-more', 'The rest of the account'))
    add(p('The same object answers the other questions, and every one of them fills a '
          'queue of the same shape whoever the provider is:'))
    add(table(['You want', 'Call', 'It fills'], [
        ['Who is blocked', '<code>GetSuppressions(kind)</code>', '<code>SuppQ</code>'],
        ['Let one back in', '<code>DeleteSuppression(address, kind)</code>', '&mdash;'],
        ['Let them all back in', '<code>DeleteAllSuppressions(kind)</code>', '&mdash;'],
        ['Statistics per day', '<code>GetStats(from, to)</code>', '<code>StatQ</code>'],
        ['What happened to a message', '<code>GetEvents(from, to)</code>',
         '<code>EventQ</code>'],
        ['Contacts and lists', '<code>GetContacts()</code> <code>GetLists()</code>',
         '<code>ContactQ</code> <code>ListQ</code>'],
        ['Campaigns', '<code>GetCampaigns()</code> <code>SendCampaign(id)</code>',
         '<code>CampaignQ</code>'],
        ['Templates, senders, domains, webhooks',
         '<code>GetTemplates()</code> &hellip;', '<code>TemplateQ</code> &hellip;'],
        ['All of it, in a window', '<code>Manage()</code>', '&mdash;'],
    ]))
    add(p('No provider offers every one. <code>Supports()</code> says which, so a '
          'window can grey out what this account genuinely cannot do rather than '
          'failing when somebody presses it:'))
    add(code(S_SUPPORTS))
    add(note('info', 'Or just show them the window',
             '<p><code>MailApi.Manage()</code> is a complete tabbed window over all of '
             'it &mdash; blocked addresses with their reasons, unblock one or unblock '
             'every one, a CSV export, statistics, activity, contacts, lists, '
             'campaigns, templates, senders, domains and webhooks. Tabs this provider '
             'cannot answer are disabled rather than empty. The <b>emailTo - Mail '
             'account button</b> control template drops a button that opens it, on '
             'whichever tab you name.</p>'))

    add(h2('demo', 'The demo'))
    add(p('<code>examples/emailTo/emailToDemo.clw</code> is the hand-coded equivalent of '
          'what the templates generate: a window with <b>Account setup</b>, '
          '<b>Write a message</b> and <b>Send a test</b>, and the conversation log '
          'underneath. Build it and press the buttons before wiring anything into your '
          'own application.'))
    add(code('MSBuild emailToDemo.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32\n'
             'emailToDemo.exe            ! the demo window\n'
             'emailToDemo.exe /setup     ! straight to the account window', 'dos'))
    add(p('<b>Test account</b> is the button to press first. It connects, negotiates TLS '
          'and authenticates, then hangs up &mdash; it sends nothing to anybody, so you '
          'can prove the credentials without mailing a real person.'))

    add(h2('firstrun', 'When the first send does not work'))
    add(p('Turn the log on (<code>Mailer.Trace = 1</code>) and read the Log tab of the '
          'setup window. Every line the server said is there, with passwords masked. '
          'These are the answers that come up first:'))
    add(table(['What you see', 'What it means'], [
        ['<code>The password was refused</code> on Gmail',
         'A normal password, not an app password. Or two-factor is off, so Google will not issue one.'],
        ['<code>The password was refused</code> on Outlook.com',
         'Microsoft turned basic authentication off for personal accounts. Use OAuth2.'],
        ['<code>The TLS handshake failed</code>, Windows code 590624',
         'That is <code>SEC_I_INCOMPLETE_CREDENTIALS</code>. emailTo already handles it; '
         'if you see it, you are running an older copy of <code>emailc.c</code>.'],
        ['<code>Could not connect to the mail server</code>',
         'A firewall, or the wrong port. 587 is STARTTLS, 465 is implicit TLS, 25 is plain.'],
        ['<code>The sender was refused</code>',
         'The From address is not one the account is allowed to send as.'],
        ['<code>Illegal data type: EMAILTOCLASS</code> at compile time',
         'The includes arrived with LF line endings. Convert them to CRLF.'],
    ]))

    add(nextcards(['programmers-guide.html', 'template-guide.html', 'reference.html']))

    body = '\n'.join(B)
    groups = [
        ('Start here', [('what', 'What emailTo is'), ('install', 'Install')]),
        ('Send something', [('hello', 'The smallest thing that sends'),
                            ('handcoded', 'Building it by hand'),
                            ('fromappgen', 'The same thing from AppGen'),
                            ('attachments', 'A message with more in it')]),
        ('OAuth2', [('oauthsetup', 'Setting up OAuth2'),
                    ('oauth-google', 'Google'),
                    ('oauth-microsoft', 'Microsoft'),
                    ('oauth-verify', 'Access blocked'),
                    ('oauth-run', 'Running it')]),
        ('Ask the provider', [('ask', 'Who is blocked, and why'),
                              ('ask-more', 'The rest of the account')]),
        ('Then', [('demo', 'The demo'), ('firstrun', 'When the first send does not work')]),
    ]
    return page('getting-started.html', PAGE_TITLES['getting-started.html'][0], 'Volume 1',
                'Getting Started',
                'Install the classes, register the template, and get a message out of '
                'a Clarion program in about twenty lines.',
                ['No DLL to ship', 'No .NET', '8 provider APIs', 'Clarion 12'],
                groups, body)

# =====================================================================
#  2  PROGRAMMER'S GUIDE
# =====================================================================
S_OWNS = """
Mailer  EmailToClass          ! you declare this one

  !  and it builds, at Construct:
  !     Mailer.Net    EmailNetClass    the socket, TLS, HTTPS, DPAPI
  !     Mailer.Msg    EmailMsgClass    the message SendSimple and Compose use
  !     Mailer.OAuth  EmailOAuthClass  the sign-in
  !
  !  EmailOAuthClass only BORROWS Net and a second message object; it frees
  !  neither.  One owner, one Destruct, no double-dispose.
"""

S_OAUTHFLOW = """
  Mailer.Acc.Provider  = ETPrv:Office365
  Mailer.Acc.Transport = ETTrn:GraphApi
  Mailer.Acc.ClientId  = '11111111-2222-3333-4444-555555555555'
  Mailer.Acc.TenantId  = 'common'
  Mailer.Acc.UserName  = 'you@company.com'

  IF Mailer.Authorize()                     ! browser opens; user consents
    Mailer.SaveAccount()                    ! stores the refresh token, sealed
  ELSE
    MESSAGE(CLIP(Mailer.LastErrorText))
  END
"""

S_TABLE = """
Mailer.LoadAccount PROCEDURE(<STRING pName>)
  CODE
  IF NOT OMITTED(pName) AND CLIP(pName)
    SELF.Acc.Name = CLIP(pName)
  END
  Access:MailAcct.Open()
  Access:MailAcct.UseFile()
  CLEAR(MAI:Record)
  MAI:Name = SELF.Acc.Name
  GET(MailAcct, MAI:ByName)
  IF ERRORCODE()
    Access:MailAcct.Close()
    RETURN 0                                ! nothing stored yet - keep the defaults
  END
  SELF.Acc.Host     = CLIP(MAI:Host)
  SELF.Acc.Password = SELF.Unseal(MAI:Password)
  ! ... one line per mapped column ...
  Access:MailAcct.Close()
  RETURN 1
"""

S_DERIVE = """
MyMailer  CLASS(EmailToClass)
Txt         PROCEDURE(LONG pId),STRING,DERIVED
SendSmtp    PROCEDURE(EmailMsgClass pMsg),BYTE,PROC,DERIVED
          END

MyMailer.Txt PROCEDURE(LONG pId)
  CODE
  IF GlobalLanguage = LNG:Portuguese
    CASE pId
    OF ETTxt:Send  ; RETURN 'Enviar'
    OF ETTxt:Sent  ; RETURN 'A mensagem foi enviada.'
    END
  END
  RETURN PARENT.Txt(pId)                    ! English and Spanish still work

MyMailer.SendSmtp PROCEDURE(EmailMsgClass pMsg)
Ok  BYTE
  CODE
  Ok = PARENT.SendSmtp(pMsg)
  Log:Sent = Ok; Log:Reason = SELF.LastErrorText; ADD(SendLog)
  RETURN Ok
"""

S_INLINE = """
  Mailer.Msg.ClearAll()
  Mailer.Msg.AddTo(Cus:Email)
  Mailer.Msg.SetSubject('Your statement')
  Mailer.Msg.SetHtml('<p><img src="cid:logo" width="180"></p>' & |
                     '<p>Your statement is attached.</p>')
  Mailer.Msg.AttachInline('C:\\art\\logo.png', 'logo')
  Mailer.Msg.Attach('C:\\stmt\\' & CLIP(Cus:Id) & '.pdf')
  Mailer.Send(Mailer.Msg)
"""

S_CLEARTRAP = """
!  In the CLASS declaration:
ClearAll             PROCEDURE       ! correct
!  Clear              PROCEDURE      ! WRONG - redefines the CLEAR intrinsic

!  With a method called Clear, this line, in code that has nothing to do
!  with e-mail, stops compiling:
  CLEAR(GlobalRequest)               ! error: No matching prototype available
"""

S_STRINGTRAP = """
!  WRONG - a literal, on a control bound to a variable.  Survives on its own,
!  faults inside OPEN(Window) as soon as the window also holds a LIST.
         STRING(''),AT(10,130,280,10),USE(LocStatus),FONT(,8)

!  RIGHT - a picture wide enough for the variable
         STRING(@s128),AT(10,130,280,10),USE(LocStatus),FONT(,8)
"""

S_RETSTR = """
!  A method that returns a STRING cannot free the buffer it built the answer
!  in: the copy happens at the RETURN.  So the buffer belongs to the object.
EmailMsgClass.Base64 PROCEDURE(STRING pRaw)
  CODE
  SELF.EncBuf.ClearAll()
  ! ... fill SELF.EncBuf ...
  RETURN SELF.EncBuf.Value()

!  And each encoder gets its OWN buffer, because they nest: the inner result
!  is still live while the outer call reads it.
  pOut.Add(SELF.QuotedPrintable(SELF.Utf8(pBody.Value())))
"""


def build_programmers_guide():
    B = []
    add = B.append

    add(h2('model', 'The object model'))
    add(p('One object is yours. Everything under it is built and freed for you.'))
    add(code(S_OWNS))
    add(p('The split is deliberate and it is the reason emailTo needs no third-party '
          'library. <b>EmailNetClass</b> is the only place that touches C: sockets, the '
          'SCHANNEL handshake, WinHTTP, DPAPI, SHA-256. <b>EmailMsgClass</b> is pure '
          'Clarion and knows nothing about networks &mdash; it turns fields into an RFC '
          '5322 document. <b>EmailToClass</b> joins them: it owns an account and knows '
          'four ways to deliver the bytes the message class produced.'))
    add(note('note', 'Why the message class does not know about sockets',
             '<p>Because all four transports want the same bytes. SMTP writes them '
             'after <code>DATA</code>, the Gmail API base64url-encodes them into a JSON '
             'field, Graph posts them as base64 text, Mailgun uploads them as a file. '
             'Build the MIME once and every transport is a thin wrapper.</p>'))

    add(h2('account', 'The account'))
    add(p('<code>Mailer.Acc</code> is a <code>GROUP</code>, and it is the contract '
          'between the class and wherever you keep your settings. The template maps one '
          'table column onto each field. The fields that matter most:'))
    add(table(['Field', 'What it decides'], [
        ['<code>Transport</code>', 'SMTP, Gmail API, Graph, or a provider API key.'],
        ['<code>Provider</code>', 'Which preset filled the rest in, and which API shape to speak.'],
        ['<code>Host</code> / <code>Port</code> / <code>Security</code>', 'The SMTP connection.'],
        ['<code>AuthMode</code>', 'Nothing, AUTH LOGIN, AUTH PLAIN, or an OAuth2 token.'],
        ['<code>UserName</code> / <code>Password</code>', 'The credential, when it is a password.'],
        ['<code>ClientId</code> / <code>TenantId</code>', 'The registered application, when it is OAuth2.'],
        ['<code>RefreshToken</code>', 'What makes the second send need no browser.'],
        ['<code>ApiKey</code> / <code>ApiDomain</code>', 'SendGrid, Mailgun, Resend, Brevo, Postmark, Mailjet.'],
        ['<code>VerifyCert</code>', 'Leave it at 1 unless the server is yours and self-signed.'],
    ]))
    add(p('<code>SetProvider</code> fills in host, port, security and sign-in for '
          'fourteen providers, so an account is usually three lines: the provider, the '
          'address and the credential.'))

    add(h2('composing', 'Composing a message'))
    add(p('Recipients come in one at a time with <code>AddTo</code> / <code>AddCc</code> '
          '/ <code>AddBcc</code>, or all at once with <code>AddList</code>, which takes '
          'the way people actually type them &mdash; separated by <code>;</code> or '
          '<code>,</code>, with any amount of stray space.'))
    add(p('<b>Bcc behaves properly.</b> A Bcc address is added to the envelope as an '
          'extra <code>RCPT TO</code> and is deliberately <em>not</em> written into the '
          'headers, so the other recipients never see it.'))
    add(p('Bodies are set with <code>SetText</code> and <code>SetHtml</code>, appended '
          'with <code>AddText</code> and <code>AddHtml</code>. Attachments come from '
          'disk with <code>Attach</code>, from memory with <code>AttachData</code>, and '
          'an image the HTML refers to goes in with <code>AttachInline</code>:'))
    add(code(S_INLINE))

    add(h2('accents', 'Accents, and why they survive'))
    add(p('A Clarion <code>STRING</code> holds Windows-1252 bytes. Sent as-is, '
          '<i>Factura N&uacute;mero</i> arrives as mojibake, because nothing told the '
          'reader what those bytes meant.'))
    add(p('emailTo transcodes the subject, the display names, the bodies and the '
          'attachment file names to <b>UTF-8</b> and labels them. Headers are wrapped in '
          'RFC 2047 encoded words split on character boundaries &mdash; never through the '
          'middle of a character &mdash; and bodies go out quoted-printable. A plain '
          'English note is still sent as readable <code>7bit</code> text, because the '
          'encoder only reaches for quoted-printable when the content, or a 998-byte '
          'line, actually needs it.'))
    add(usecode("Mailer.Msg.CharSet = ETChs:Ansi   ! send the raw bytes labelled windows-1252 instead"))

    add(h2('transports', 'Choosing a transport'))
    add(table(['Transport', 'When it is the right one'], [
        ['<code>ETTrn:Smtp</code>',
         'Almost always. Any server, any provider that still allows a password or supports XOAUTH2.'],
        ['<code>ETTrn:GmailApi</code>',
         'A Google account where you would rather not enable SMTP at all. Needs OAuth2.'],
        ['<code>ETTrn:GraphApi</code>',
         'Microsoft 365 tenants that have SMTP AUTH disabled &mdash; increasingly, all of them.'],
        ['<code>ETTrn:ApiKey</code>',
         'A deployed application that must just send, on a network where port 587 may be blocked.'],
    ]))
    add(p('Switching is one field. The message, the attachments and the error handling '
          'are identical:'))
    add(usecode("Mailer.Acc.Transport = ETTrn:GraphApi"))

    add(h2('oauth', 'OAuth2, end to end'))
    add(p('Google and Microsoft no longer accept an ordinary password from a desktop '
          'program. The flow emailTo runs is the authorisation-code flow with PKCE, '
          'which is the one they document for native applications:'))
    add('<ol class="b">'
        '<li>Invent a random <b>verifier</b> and hash it with SHA-256 into a '
        '<b>challenge</b>.</li>'
        '<li>Open a listener on <code>http://127.0.0.1:&lt;a free port&gt;/</code> '
        '&mdash; before the browser, so no redirect can be missed.</li>'
        '<li>Open the user&rsquo;s own browser at the provider&rsquo;s consent screen, '
        'carrying the challenge and a random <b>state</b>.</li>'
        '<li>Catch the redirect, check the state matches, and swap the returned code '
        'plus the verifier for an <b>access token</b> and a <b>refresh token</b>.</li>'
        '</ol>')
    add(code(S_OAUTHFLOW))
    add(note('tip', 'A desktop client ID is not a secret',
             '<p>That is what PKCE is for. Microsoft public clients must send '
             '<em>no</em> client secret at all, and emailTo only sends one when the '
             'account actually has one. Nothing confidential is compiled into your '
             '<code>.EXE</code>.</p>'
             '<p>Register at <b>console.cloud.google.com</b> &rarr; Credentials &rarr; '
             'OAuth client ID &rarr; <b>Desktop app</b>, or <b>portal.azure.com</b> '
             '&rarr; App registrations &rarr; <b>Public client</b> with redirect '
             '<code>http://localhost</code>.</p>'))
    add(p('After the first consent nobody sees a browser again. <code>EnsureToken</code> '
          'runs before every send: if the access token is still good it does nothing, if '
          'it has expired it spends the refresh token silently, and only when there is '
          'no refresh token left does it ask the user to sign in.'))
    add(note('warn', 'Google only issues a refresh token when asked properly',
             '<p>It needs <code>access_type=offline</code> <em>and</em> '
             '<code>prompt=consent</code>, and without them the second send fails with '
             'no obvious cause. emailTo sends both. Microsoft instead <b>rotates</b> the '
             'refresh token on every use, so the new one has to be stored each time '
             '&mdash; which is why <code>Refresh</code> writes it back.</p>'))

    add(h2('api', 'One class, nine providers'))
    add(p('<code>EmailToClass</code> answers one question: send this. '
          '<code>EmailApiClass</code> answers all the others &mdash; who is blocked, '
          'what happened last month, which contacts and campaigns exist &mdash; and it '
          'answers them the same way whoever you signed up with.'))
    add(p('It owns nothing of its own. <code>Init(Mailer)</code> borrows the account '
          'and the HTTPS layer, so the key the Setup window sealed is the key these '
          'calls use, and there is no second copy of a credential anywhere in the '
          'program.'))
    add(code(S_ASK))
    add(p('Underneath it is three layers, and only the middle one knows anything about '
          'a provider:'))
    add(table(['Layer', 'What it is', 'Knows about providers?'], [
        ['<code>BuildMap()</code>', 'The matrix. One row per operation per provider.',
         'Yes &mdash; and it is the only thing that does'],
        ['<code>Fetch</code> / <code>Perform</code>',
         'The engine: expand the URL, sign it, follow the paging, parse, map.', 'No'],
        ['<code>GetXxx</code> / <code>AddXxx</code>',
         'The public methods. Set the arguments, call the engine.', 'No'],
    ]))

    add(h2('api-matrix', 'The matrix'))
    add(p('Adding a provider is adding rows, not writing branches. A row says: for '
          'THIS provider and THIS operation, use this verb and this address, the list '
          'is at this path in the reply, and these JSON members fill these columns.'))
    add(code(S_MATRIX))
    add(p('The pieces of a row:'))
    add(table(['Part', 'What it means'], [
        ['<code>{scheme}{host}</code>',
         'The provider&rsquo;s address, honouring <code>ApiRegion</code> (eu) and '
         '<code>ApiBase</code> (anything you name, scheme included).'],
        ['<code>{limit} {offset} {page}</code>',
         'Filled in by the paging loop, over and over, until the provider runs out.'],
        ['<code>{email} {id} {text} {subject} {html}</code>',
         'Your data. Percent-encoded in a URL, JSON-escaped in a body &mdash; the '
         'engine can tell which it is building.'],
        ['<code>{ymdfrom} {isofrom} {epochfrom} {rfcfrom}</code>',
         'The same date range in the four spellings the nine providers want.'],
        ['the item path', 'Where the array of rows sits: blank means the reply IS the '
         'array, <code>*</code> means the reply is ONE item. A path that turns out not '
         'to be there falls back to the first array in the document.'],
        ['the map', '<code>Column=source</code> pairs. A source may be a path '
         '(<code>reason.message</code>), may offer alternates '
         '(<code>recipient.email|email</code>), may be a literal '
         '(<code>!spam report</code>), and may carry a date converter: '
         '<code>#</code> unix, <code>@</code> ISO-8601, <code>%</code> RFC-2822, '
         '<code>$</code> a plain day.'],
    ]))
    add(note('info', 'ETSup:All on a list row means something specific',
             '<p>Providers split their block lists two ways. SendGrid keeps five '
             'separate ones and each row is registered under its own kind. Brevo, '
             'Postmark and SparkPost keep ONE list and label each entry, so their row '
             'is registered under <code>ETSup:All</code> &mdash; and the engine then '
             'reads each row&rsquo;s real kind out of the provider&rsquo;s own wording '
             '(<code>hardBounce</code>, <code>SpamNotification</code>, '
             '<code>policy_suppression</code>) through <code>SuppKindOf()</code>. Ask '
             'either sort for one kind and you get that kind.</p>'))

    add(h2('api-queues', 'The normalised answers'))
    add(p('Every read fills a queue that looks the same whoever answered. That is the '
          'whole bargain: the differences are absorbed in the matrix, and your code '
          'never learns them.'))
    add(table(['Queue', 'What is in a row'], [
        ['<code>SuppQ</code>', 'Address, Kind, KindName, Reason, Code, WhenDate, '
         'WhenTime, Id, Sender, Raw'],
        ['<code>StatQ</code>', 'WhenDate, Requests, Delivered, Opens, UniqueOpens, '
         'Clicks, UniqueClicks, HardBounces, SoftBounces, Blocks, SpamReports, '
         'Unsubscribed, Invalid'],
        ['<code>EventQ</code>', 'WhenDate, WhenTime, Address, EventName, Reason, '
         'Subject, MessageId, Link'],
        ['<code>ContactQ</code> <code>ListQ</code> <code>CampaignQ</code>',
         'Id, Address, Name, Blocked, Unsubscribed &hellip; / Id, Name, Members &hellip; '
         '/ Id, Name, Subject, Status &hellip;'],
        ['<code>TemplateQ</code> <code>SenderQ</code> <code>DomainQ</code> '
         '<code>HookQ</code>', 'The same treatment for the rest of the account'],
    ]))
    add(p('<code>SuppQ.Raw</code> keeps the provider&rsquo;s own object for the row, so '
          'anything the queue has no column for is still there when you need to log the '
          'one entry that looks wrong.'))
    add(note('warn', 'A LIST cannot be pointed at these',
             '<p><code>FROM(MailApi.SuppQ)</code> compiles and then faults on the first '
             'paint: these are queue REFERENCES, and the control binds to the reference '
             'variable itself. Copy the rows into a real local <code>QUEUE</code> for '
             'display &mdash; which is where you want to format the dates anyway. '
             '<code>Manage()</code> does exactly that, and the demo shows it.</p>'))

    add(h2('api-paging', 'Paging, three ways'))
    add(p('A block list is not a page long, and the nine providers disagree about how '
          'to walk it. The engine handles all three without the caller knowing:'))
    add(table(['Style', 'Who', 'What the engine does'], [
        ['limit and offset', 'SendGrid, Brevo, Mailjet, Postmark',
         'Asks again with the offset advanced, and stops when a page comes back '
         'shorter than the page size.'],
        ['page number', 'SparkPost, MailerSend',
         'The same, counted in pages instead of rows.'],
        ['a cursor', 'Mailgun',
         'Follows the address the reply carries in <code>paging.next</code>, and stops '
         'when a page comes back empty.'],
        ['a continuation token', 'Amazon SES',
         'Hands the token back as a parameter named after the path it arrived at, so '
         'the matrix row says <code>NextToken</code> and the engine needs to know '
         'nothing about Amazon.'],
    ]))
    add(p('<code>PageSize</code> sets how many to ask for at a time and '
          '<code>MaxRows</code> is the guard &mdash; 5,000 by default, 0 for no limit. '
          'A hundred thousand suppressed addresses is a real thing at a large sender, '
          'and reading them all into memory by accident should be a decision rather '
          'than a surprise.'))
    add(note('tip', 'One list refusing does not lose the others',
             '<p>Asking SendGrid for everything means five requests. If one of them '
             'fails &mdash; an endpoint an account&rsquo;s plan does not open, a '
             'permission the key was not given &mdash; the other four still answer, '
             'and the failure is in <code>LastErrorText</code>. A partial answer is a '
             'great deal more use than none.</p>'))

    add(h2('api-add', 'Adding a provider'))
    add(p('<code>BuildMap</code> is VIRTUAL, so a provider the shipped matrix does not '
          'know needs no change to any file emailTo ships:'))
    add(code(S_ADDPROVIDER))
    add(p('Set <code>Acc.Provider</code> to <code>ETPrv:Custom</code> and '
          '<code>Acc.ApiBase</code> to the host, and every method above works against '
          'it &mdash; including <code>Manage()</code>, which reads '
          '<code>Supports()</code> to decide which tabs to offer.'))
    add(p('For a single call that deserves no row at all, <code>RawCall()</code> signs '
          'the request with this account and hands you back the status; the reply is in '
          '<code>Net.Body()</code>, and <code>Json</code> is right there to parse it.'))

    add(h2('settings', 'Where the settings live'))
    add(p('<code>LoadAccount</code> and <code>SaveAccount</code> are <code>VIRTUAL</code>. '
          'Out of the box they read and write an INI beside the <code>.EXE</code>, which '
          'is enough for a demo and for a single-user program. Nominate a table on the '
          'global extension and the template overrides them with code shaped like this:'))
    add(code(S_TABLE))
    add(p('Both methods open and close the file around their own work through the ABC '
          'FileManager, whose <code>Open</code> and <code>Close</code> are '
          'reference-counted &mdash; so it is safe whether or not the table is already '
          'open elsewhere in the program.'))

    add(h2('secrets', 'Secrets at rest'))
    add(p('Four fields are never stored in the clear: the password, the client secret, '
          'the refresh token and the API key. Each goes through <code>Seal()</code> '
          '&mdash; DPAPI encrypts it for the current Windows user, then base64 makes the '
          'result safe for a text column.'))
    add(usecode("Set:Password = Mailer.Seal(Loc:Typed)      ! 'dpapi:AQAAANCMnd8BFdERjHoAwE...'"))
    add(p('A row copied to another machine, or read by another Windows user, decrypts to '
          'nothing. Size those columns generously: the stored value is three to four '
          'times longer than what was typed.'))
    add(note('note', 'A password typed straight into the column still works',
             '<p><code>Unseal()</code> recognises a value that is not one of its own and '
             'hands it back unchanged, which makes seeding a test row easy. A machine '
             'with no DPAPI gets a <code>plain:</code> prefix instead, so nobody '
             'mistakes it for encrypted.</p>'))

    add(h2('errors', 'Errors, and the log'))
    add(p('Every public method answers <code>1</code> for worked and <code>0</code> for '
          'failed, and leaves the reason in <code>LastErrorText</code> as a sentence you '
          'can show a user. <code>LastServerReply</code> holds the last thing the server '
          'actually said, which is usually more specific than anything emailTo could '
          'invent.'))
    add(usecode("IF NOT Mailer.Send(Mailer.Msg) THEN Mailer.ShowError()."))
    add(p('With <code>Trace</code> on, the whole conversation is kept in '
          '<code>Mailer.Net.TraceQ</code> and shown on the Log tab of the setup window. '
          'Credentials are masked before they reach it, so a customer can send you the '
          'log of a failed send without sending you their password.'))
    add(note('danger', 'A LIST cannot be pointed at TraceQ directly',
             '<p><code>TraceQ</code> is a queue <em>reference</em>, and '
             '<code>FROM(Mailer.Net.TraceQ)</code> binds the control to the reference '
             'variable rather than to the queue. The window then faults on its first '
             'paint. Copy into a real local <code>QUEUE</code> for display &mdash; the '
             'demo and the setup window both do.</p>'))

    add(h2('deriving', 'Making it do something else'))
    add(p('The methods worth overriding are marked <code>VIRTUAL</code>: '
          '<code>Txt</code> for a third language, <code>LoadAccount</code> / '
          '<code>SaveAccount</code> for your own store, and the four '
          '<code>Send*</code> methods for logging, throttling or a retry policy.'))
    add(code(S_DERIVE))

    add(h2('notes', 'Clarion notes'))
    add(p('These are not emailTo behaviours &mdash; they belong to Clarion. Each one cost '
          'real time to find while this was being built, and each is the kind of thing '
          'that is invisible until it bites.'))

    add(h3('note-clear', 'A method named Clear breaks CLEAR() everywhere'))
    add(p('A class member whose label matches a Clarion intrinsic redefines that '
          'intrinsic for <em>every module that includes the file</em>. The compiler says '
          '<code>Redefining system intrinsic: CLEAR</code> at the include, and then '
          '<code>CLEAR(SomeVariable)</code> in code that has nothing to do with your '
          'class stops compiling.'))
    add(code(S_CLEARTRAP))
    add(p('This is why the buffer and message classes have <code>ClearAll</code>. '
          '<code>RESET</code>, <code>ADD</code>, <code>LEN</code> and <code>FREE</code> '
          'are the other names to keep away from.'))

    add(h3('note-string', 'A STRING bound to a variable needs a picture'))
    add(p('Written with a literal instead, the control survives on its own &mdash; and '
          'then faults inside <code>OPEN(Window)</code> as soon as the same window also '
          'holds a <code>LIST</code>. Nothing is drawn, so there is no clue on screen '
          'about which control is at fault.'))
    add(code(S_STRINGTRAP))
    add(p('The way to find one like this is to open variants of the window with one '
          'control removed at a time: the variant that opens names the culprit. Here '
          'two removals fixed it &mdash; the LIST, or the bound STRINGs &mdash; which is '
          'what said it was the combination rather than either one.'))

    add(h3('note-picture', 'No Clarion picture is wider than @s255'))
    add(p('<code>ENTRY(@s512)</code> is a compile error &mdash; <code>Invalid picture '
          'token</code>. In a <code>FORMAT</code> string it is worse, because '
          '<code>FORMAT</code> is just text to the compiler and nothing is reported at '
          'all. Keep list formats at <code>@s255</code> and give the entry a wider '
          'variable if you need one.'))

    add(h3('note-map', 'A MEMBER module with no MAP loses the built-ins'))
    add(p('A module-level <code>MAP</code> is what folds in <code>BUILTINS.CLW</code>. '
          'Without one &mdash; even an empty one &mdash; <code>CLIP</code>, '
          '<code>CHOOSE</code> and the rest come back as <code>Unknown function '
          'label</code>, dozens of times, which reads like a corrupt include rather '
          'than a missing four lines.'))
    add(code("  MEMBER\n\n  INCLUDE('EmailToClass.INC'),ONCE\n\n  MAP\n  END"))

    add(h3('note-return', 'A method returning STRING cannot free its own buffer'))
    add(p('The copy happens at the <code>RETURN</code>, so anything disposed first is '
          'gone before the caller sees it. The buffer has to outlive the return, which '
          'means it belongs to the object &mdash; and each encoder needs its own, '
          'because they nest.'))
    add(code(S_RETSTR))

    add(h3('note-crlf', 'Clarion source must be CRLF'))
    add(p('An LF-only include mis-parses as <code>Illegal data type: &lt;CLASS&gt;</code> '
          'at the <em>declaration</em>, with nothing flagged inside the include. Note '
          'that <code>sed -i</code> strips the CR and writes LF, so a one-line edit is '
          'enough to break a file that compiled a minute earlier.'))

    add(h3('note-schannel', 'SCHANNEL asks for a client certificate you do not have'))
    add(p('Google&rsquo;s SMTP, and Office 365, request an <em>optional</em> client '
          'certificate. With no certificate in the credential, '
          '<code>InitializeSecurityContext</code> returns '
          '<code>SEC_I_INCOMPLETE_CREDENTIALS</code> (<code>0x00090320</code>) rather '
          'than continuing, and the handshake stops. The fix is to re-issue the same '
          'token &mdash; loop again without reading more data &mdash; and the handshake '
          'completes anonymously. Without it every connection to Gmail fails.'))

    add(h3('note-dot', 'The lone full stop'))
    add(p('In SMTP, a line consisting of a single <code>.</code> ends the message. A '
          'body line that legitimately starts with a full stop must therefore be sent '
          'with two, and the receiving server removes one. Get this wrong and a message '
          'is silently truncated at the first such line &mdash; which is exactly the kind '
          'of thing that never shows up in testing and then happens to a customer.'))

    add(nextcards(['template-guide.html', 'reference.html', 'getting-started.html']))

    body = '\n'.join(B)
    groups = [
        ('How it fits together', [('model', 'The object model'), ('account', 'The account')]),
        ('Building a message', [('composing', 'Composing a message'),
                                ('accents', 'Accents')]),
        ('Getting it out', [('transports', 'Choosing a transport'),
                            ('oauth', 'OAuth2, end to end')]),
        ('The provider API', [('api', 'One class, nine providers'),
                              ('api-matrix', 'The matrix'),
                              ('api-queues', 'The normalised answers'),
                              ('api-paging', 'Paging, three ways'),
                              ('api-add', 'Adding a provider')]),
        ('Keeping it', [('settings', 'Where the settings live'),
                        ('secrets', 'Secrets at rest'),
                        ('errors', 'Errors, and the log'),
                        ('deriving', 'Making it do something else')]),
        ('Clarion notes', [('notes', 'Clarion notes'),
                           ('note-clear', 'Clear breaks CLEAR()'),
                           ('note-string', 'STRING needs a picture'),
                           ('note-picture', 'The @s255 ceiling'),
                           ('note-map', 'MEMBER needs a MAP'),
                           ('note-return', 'Returning a STRING'),
                           ('note-crlf', 'CRLF'),
                           ('note-schannel', 'The client certificate'),
                           ('note-dot', 'The lone full stop')]),
    ]
    return page('programmers-guide.html', PAGE_TITLES['programmers-guide.html'][0], 'Volume 2',
                "Programmer's Guide",
                'What the five classes own, how a message becomes MIME, how one class '
                'covers nine provider APIs, and the Clarion behaviour that bit us.',
                ['Object model', 'MIME', 'The provider matrix', 'Clarion notes'],
                groups, body)

# =====================================================================
#  3  TEMPLATE GUIDE
# =====================================================================
S_GEN_GLOBAL = """
!  %AfterGlobalIncludes
INCLUDE('EmailToClass.INC'),ONCE

!  %GlobalData
Mailer             EmailToClass                            ! the mail object
emailToLanguage        BYTE(1)                             ! 1 = English, 2 = Espanol

!  %ProgramSetup, PRIORITY(8000)
    Mailer.Init()
    Mailer.Language = emailToLanguage
    Mailer.Trace = 1
    Mailer.SetProvider(1)                     ! host, port, security and auth
    Mailer.Acc.Transport = 1
    Mailer.Acc.Host      = 'smtp.gmail.com'
    Mailer.Acc.Port      = 587
    Mailer.Acc.Security  = 1
    Mailer.Acc.AuthMode  = 1
    Mailer.Acc.UserName  = 'sales@acme.com'
    Mailer.Acc.FromAddr  = 'sales@acme.com'
    Mailer.LoadAccount()
"""

S_GEN_DERIVED = """
!  %GlobalData, when a settings table is nominated
Mailer             CLASS(EmailToClass)
LoadAccount              PROCEDURE(<STRING pName>),BYTE,PROC,DERIVED
SaveAccount              PROCEDURE(),BYTE,PROC,DERIVED
                       END

!  %ProgramProcedures - the whole binding, written from your column mapping
Mailer.LoadAccount PROCEDURE(<STRING pName>)
  CODE
  ...
"""

S_GEN_BUTTON = """
!  %ControlEventHandling, on this button's Accepted
    OF ?EmailBtn
      ThisWindow.Update()
        Mailer.Compose('bob@example.com', 'Hello from Clarion', 'It works.', '')
    OF ?EmailBtn:2
      ThisWindow.Update()
          Mailer.Msg.ClearAll()
          Mailer.Msg.AddList('ops@example.com', ETAddr:To)
          Mailer.Msg.AddList('audit@example.com', ETAddr:Cc)
          Mailer.Msg.SetSubject('Nightly run finished')
          Mailer.Msg.SetHtml('<p>Fixed <b>HTML</b> body.</p>')
        IF Mailer.Send(Mailer.Msg)
          MESSAGE(Mailer.Txt(ETTxt:Sent), Mailer.Txt(ETTxt:Compose), ICON:Asterisk)
        ELSE
          Mailer.ShowError()
        END
    OF ?EmailBtn:3
      ThisWindow.Update()
        Mailer.Setup()
"""


def build_template_guide():
    B = []
    add = B.append

    add(h2('five', 'The ten templates'))
    add(table(['Template', 'Kind', 'What it is for'], [
        ['<b>emailTo - Global</b>', 'Application extension',
         'Required, once per app. Declares the object, sets the defaults, '
         'generates the settings-table binding.'],
        ['<b>emailTo - E-mail button</b>', 'Control template, MULTI',
         'Drag onto a window. Compose, send straight away, or open the account window.'],
        ['<b>emailTo - Send an e-mail here</b>', 'Code template',
         'Any embed: after a report, on a menu item, inside a batch process.'],
        ['<b>emailTo - Open the compose window here</b>', 'Code template',
         'The write-and-send window, optionally pre-filled.'],
        ['<b>emailTo - Open the mail account setup window here</b>', 'Code template',
         'The account window, for a Setup menu.'],
        ['<b>emailTo - Provider API</b>', 'Application extension',
         'Add once. Declares the object that reads the blocked list, statistics, '
         'contacts and campaigns.'],
        ['<b>emailTo - Sync provider data into your tables</b>', 'Application extension',
         'Add once. Writes all of that into tables of your own.'],
        ['<b>emailTo - Mail account button</b>', 'Control template, MULTI',
         'Drag onto a window. Opens the management window: blocked addresses and why, '
         'statistics, activity, contacts, campaigns.'],
        ['<b>emailTo - Ask the provider</b>', 'Code template',
         'Any embed: load the blocked list, unblock one or all of them, check an '
         'address, read the statistics, send a campaign, sync the tables.'],
        ['<b>emailTo - Sync mail data into your tables</b>', 'Control template, MULTI',
         'Drag onto a window. Brings the blocked list, statistics, activity, '
         'contacts, lists and campaigns down into your own tables.'],
    ]))
    add(note('tip', 'Only the first one is required',
             '<p>Add <b>emailTo - Global</b> and both objects exist everywhere. The '
             'other six are conveniences that call them &mdash; anything they do, you '
             'can do from a hand-written embed with the same one-line calls.</p>'))

    add(h2('global', 'emailTo - Global'))
    add(p('Global Properties &rarr; Extensions &rarr; Insert. Six tabs.'))

    add(h3('global-general', 'General'))
    add(table(['Prompt', 'Default', 'What it does'], [
        ['Disable this template', 'off', 'Generates nothing at all. Use it to bisect a build.'],
        ['Object name', '<code>Mailer</code>', 'The label every other template refers to.'],
        ['Language', 'English', 'Sets <code>emailToLanguage</code>, which the object reads at start-up.'],
        ['Keep a conversation log', 'on', 'Sets <code>Trace</code>. Passwords are masked before they reach it.'],
    ]))

    add(h3('global-account', 'Account'))
    add(p('The defaults the object starts with. If a settings table is nominated, '
          'whatever it holds overrides these at start-up and the setup window writes '
          'changes back; with no table these <em>are</em> the settings and the setup '
          'window saves to an INI.'))
    add(table(['Prompt', 'Notes'], [
        ['Provider', 'Fourteen presets. Choosing one fills in server, port, security and sign-in.'],
        ['Send using', 'SMTP, Gmail API, Microsoft Graph, or a provider API key.'],
        ['From address / From name / Reply to', 'Used when the message does not set its own.'],
        ['Server / Port / Security', 'Only for the SMTP transport.'],
        ['Sign in with', 'Nothing, AUTH LOGIN, AUTH PLAIN, or OAuth2 XOAUTH2.'],
        ['User name / Password', 'A password typed here is compiled into the <code>.EXE</code>.'],
    ]))
    add(note('warn', 'A password on this tab is in your executable',
             '<p>Anyone with the <code>.EXE</code> has it. For anything you would not '
             'publish, leave it blank and let the setup window store it &mdash; that '
             'path puts it through DPAPI for the Windows user.</p>'))

    add(h3('global-signin', 'Sign-in'))
    add(p('The OAuth2 application and the API keys. <b>Client ID</b> is the desktop '
          'client you registered with Google or Microsoft; it is not a secret. '
          '<b>Client secret</b> stays blank for Microsoft public clients. <b>Tenant</b> '
          'is Microsoft only &mdash; <code>common</code> accepts both a personal account '
          'and a work one, which is what an application shipped to unknown customers '
          'needs. <b>API domain</b> is Mailgun only; for Mailjet the public key goes in '
          'User name and the private key in API key.'))

    add(h2('global-sync', 'emailTo - Sync'))
    add(p('A SEPARATE application extension &mdash; <b>emailTo - Sync provider '
          'data into your tables</b>, added once alongside the global one. The '
          'management window asks the provider live and keeps nothing; this is '
          'the other option: nominate tables, and the same '
          'answers are also written into your own data &mdash; so you can put '
          'an ABC browse on the blocked list, join it to your customer table, '
          'or report on last month&rsquo;s opens without going near the '
          'network.'))
    add(note('tip', 'There is a ready-made dictionary &mdash; import the .dctx',
             '<p><code>emailToTables.dctx</code> ships beside the template and '
             'holds all six tables plus the account table. In the Dictionary '
             'Editor: <b>File &rarr; Import</b>, and pick the <b>DCTX / XML</b> '
             'entry.</p>'
             '<p><b>Not</b> <code>emailToTables.txd</code>. A <code>.txd</code> '
             'is Report Writer&rsquo;s format and the Dictionary Editor refuses '
             'it outright &mdash; <i>"This TXD file is a Report Writer only '
             'format"</i>. It ships only for <code>ClarionCL /di</code>, which '
             'builds a whole dictionary from text rather than importing into an '
             'existing one.</p>'))
    add(table(['Table', 'One row is', 'Filled from'], [
        ['<code>MailBlocked</code>', 'An address the provider refuses, with the '
         'reason, the SMTP code and when', '<code>GetSuppressions()</code>'],
        ['<code>MailStat</code>', 'One day', '<code>GetStats()</code>'],
        ['<code>MailEvent</code>', 'One thing that happened to one message',
         '<code>GetEvents()</code>'],
        ['<code>MailContact</code>', 'A contact', '<code>GetContacts()</code>'],
        ['<code>MailList</code>', 'A contact list and its size',
         '<code>GetLists()</code>'],
        ['<code>MailCampaign</code>', 'A campaign and its status',
         '<code>GetCampaigns()</code>'],
    ]))
    add(p('Every table but the account carries <code>Provider</code> and '
          '<code>SyncedOn</code>, so one dictionary serves an application that '
          'switches provider or keeps two accounts.'))
    add(table(['Prompt', 'What it does'], [
        ['Sync object name / API object name',
         'What to call the object it declares, and the API object the global '
         'extension declared for it to read through.'],
        ['Keep the provider&rsquo;s data in tables',
         'Turns the tables on. Off, nothing here generates.'],
        ['Stamp each row with the provider and the date',
         'Fills <code>Provider</code> and <code>SyncedOn</code> if the table has '
         'them. Leave it on unless one table serves exactly one account.'],
        ['Table / Key (six times)',
         'The table, and the key that identifies one row &mdash; that key is '
         'what makes the sync an update rather than a duplicate.'],
        ['How many days back',
         'For statistics and activity, which are asked for over a date range '
         'rather than in full.'],
    ]))
    add(note('info', 'Columns are matched by NAME, not mapped one by one',
             '<p>A table imported from the shipped dictionary needs no mapping '
             'at all: the template walks the columns of whatever table you '
             'nominate and fills the ones whose names it recognises. A column '
             'called anything else is left alone &mdash; so a flag of your own, '
             'a note, or a link to your customer row all survive every sync.</p>'
             '<p>That also means you can point it at a table you already have: '
             'name the columns as the dictionary does and it fills them.</p>'))
    add(p('What it generates is a small object of its own with one method, '
          '<code>Run</code>.'))
    add(note('warn', 'Why this is a separate extension, and not another tab',
             '<p>An application stores the set of prompts it was built with. A '
             'prompt added to an extension the app <em>already carries</em> is '
             'simply not there, and generating stops with <code>Unknown '
             'Variable</code> on a symbol the developer never typed &mdash; '
             'AppGen does not fill in the DEFAULT from the command line.</p>'
             '<p>An app that does not add THIS extension never names these '
             'symbols, so every existing application keeps generating exactly as '
             'it did. That is worth one extra Insert.</p>'
             '<p>The <b>Provider API</b> tab, added to the global extension in '
             'v1.03, does not have that protection: upgrading an app older than '
             "v1.03 means opening that extension's property sheet once, so the "
             'IDE writes the new prompts back. From a build script that never '
             'opens the IDE, delete the extension and insert it again.</p>'))
    add(code(S_SYNCGEN))
    add(p('Each row is looked up by its key before it is written, so running the '
          'sync twice changes nothing: a row already there is updated, a new one '
          'is added, and the count comes back the same. That is what makes it '
          'safe on a button anybody can press twice, or on a timer.'))

    add(h2('syncbutton', 'The sync button'))
    add(p('<b>emailTo - Sync mail data into your tables</b> is a control '
          'template: drag it onto a window and it drops a wired button that '
          'calls the generated method.'))
    add(table(['Prompt', 'What it does'], [
        ['Sync object name', 'The object the <b>emailTo - Sync</b> extension '
         'declared.'],
        ['Quietly &mdash; no message when it finishes',
         'Off, it reports how many rows came down and how many were new. On for '
         'a button that runs unattended.'],
        ['Put the row count in', 'A variable of yours, for a status line.'],
        ['Reset the browse afterwards',
         'Calls <code>ResetFromFile()</code> on the browse you name, so a browse '
         'of the synced table shows the new rows without the user closing the '
         'window.'],
    ]))
    add(p('For a menu item or a batch process instead, the <b>emailTo - Ask the '
          'provider</b> code template has <i>Sync it all into my tables</i> as '
          'one of its operations.'))

    add(h3('global-table', 'Table, and Table columns'))
    add(p('Nominate a table and the template generates <code>LoadAccount</code> and '
          '<code>SaveAccount</code> against it. Pick the key it finds an account by, '
          'name the account to load at start-up, then map a column onto each field.'))
    add(p('Each column prompt is a picker: the <code>&hellip;</code> button beside it '
          'lists the columns of the table you nominated, so the mapping is chosen '
          'rather than typed.'))
    add(table(['Prompt', 'Notes'], [
        ['Settings table', 'Blank means use an INI beside the <code>.EXE</code>.'],
        ['Key to find the account by', 'Used for the <code>GET</code> in both directions.'],
        ['Account to load at start-up', 'Blank loads the first record instead.'],
        ['Create the row if it is missing', 'On, the setup window can <code>ADD</code> the account.'],
        ['Account name', 'The only required column.'],
        ['Every other column', 'Optional. Unmapped keeps whatever the Account tab set.'],
    ]))
    add(note('note', 'Four columns need to be wide',
             '<p>Password, client secret, refresh token and API key are stored sealed, '
             'so they are three to four times longer than what was typed. Make them at '
             'least 400 characters, and the refresh token 2000. '
             '<code>EmailTables.txt</code> ships a structure ready to paste into a '
             'dictionary.</p>'))

    add(h3('global-multidll', 'Multi-DLL'))
    add(p('Add the extension to every application in the suite and leave the box alone. '
          'The app that owns the data compiles the classes in and exports them; the '
          'others import them. The classes are tagged '
          '<code>!ABCIncludeFile(EMAILTO)</code>, and registering that category hands '
          'the whole job to the shipped ABC machinery &mdash; it writes the project '
          'defines and walks the registry to build the <code>.EXP</code>.'))
    add(code('#pragma define(_emailToDllMode_=>0)\n#pragma define(_emailToLinkMode_=>1)', 'dos'))
    add(p('That is why nothing in the template lists a mangled symbol: add a method to a '
          'class and the export list follows on the next generate. <code>emailc.c</code> '
          'is compiled only into the application that owns the classes, because the '
          '<code>PRAGMA</code> lives in <code>EmailNetClass.clw</code>.'))

    add(h2('global-writes', 'What the global extension writes'))
    add(p('With no settings table, into the <code>PROGRAM</code> module:'))
    add(code(S_GEN_GLOBAL))
    add(p('With one, the object is <em>derived</em> instead, and the binding is written '
          'out in full at <code>%ProgramProcedures</code>:'))
    add(code(S_GEN_DERIVED))
    add(note('note', 'Why deriving still works across a suite',
             '<p>The derived instance is declared only in the application that owns it. '
             'The others import it as the base type and still reach the derived methods, '
             'because both are <code>VIRTUAL</code> and dispatch through the '
             'object&rsquo;s own VMT.</p>'))

    add(h2('global-api', 'emailTo - Provider API'))
    add(p('A SEPARATE application extension, added once alongside the global one. '
          'The same key that sends the mail can also answer for the account, so this '
          'needs nothing except a name.'))
    add(note('warn', 'It was a tab on the global extension in v1.03',
             '<p>That was a mistake, and it broke every application built before '
             'v1.03: an app stores the set of prompts it was built with, and AppGen '
             'does not backfill one added later &mdash; generation stopped with '
             '<code>Unknown Variable %ETgApi</code>, on a symbol nobody typed.</p>'
             '<p>As an extension of its own it cannot do that: an app that does not '
             'add it never names its symbols. If you had the tab switched on in '
             'v1.03, insert this extension and put the object name back &mdash; what '
             'the old tab stored is simply ignored.</p>'))
    add(table(['Prompt', 'What it does'], [
        ['Object name', 'What to call it. <code>MailApi</code> unless you have a '
         'reason &mdash; the control and code templates default to that name too.'],
        ['Mail object name', 'The object <b>emailTo - Global</b> declared. This one '
         'borrows its account and its HTTPS layer, so there is no second copy of a '
         'credential anywhere in the program.'],
        ['Rows per request', 'The page size. The class keeps asking until the provider '
         'runs out, so this is not a limit, only how much comes back at a time.'],
        ['Stop after this many rows', 'The guard: 5,000 by default, 0 for no limit.'],
        ['Second key', 'Postmark alone needs two tokens: the SERVER token sends and '
         'reads bounces, the ACCOUNT token opens senders and domains. Blank for '
         'everybody else. All three of these can come from your settings table '
         'instead &mdash; name a column <code>ApiKey2</code>, <code>ApiRegion</code> '
         'or <code>ApiBase</code> and the global extension fills it, by name, with no '
         'prompt to set.'],
        ['Region', '<code>eu</code> for a Mailgun or SparkPost account created in '
         'Europe. Those are separate services with their own hostnames and their own '
         'data &mdash; asked at the default endpoint, a European account looks empty '
         'rather than wrong.'],
        ['Base address', 'Replaces the provider&rsquo;s host, and its scheme if you '
         'give one. For a relay of your own, or for pointing a test build at a '
         'stand-in. Blank in production.'],
    ]))
    add(p('Nominate a settings table on the Table tab and three more columns become '
          'available for these on the second columns tab: second key (sealed), region '
          'and base address.'))

    add(h2('apibutton', 'The mail account button'))
    add(p('<b>emailTo - Mail account button</b> is a control template: drag it onto any '
          'window and it drops a wired button that opens the management window.'))
    add(table(['Prompt', 'What it does'], [
        ['API object name', 'The object the global extension declared.'],
        ['Open on', 'Which tab: Account, Blocked addresses, Statistics, Activity, '
         'Contacts, Lists, Campaigns, Templates, Senders and domains, or Webhooks. If '
         'this provider cannot answer that one, the window opens on the first tab it '
         'CAN answer rather than showing an empty list.'],
        ['Hide the button if the provider has no API',
         'An account sending over plain SMTP &mdash; a company Exchange server, Gmail '
         'with an app password &mdash; has no management API at all. Ticked, the '
         'button disappears for those accounts instead of opening a window with every '
         'tab greyed out. It is a run-time test, so one build serves both.'],
    ]))
    add(p('Drop it more than once and each instance gets its own tab: one button for '
          'the blocked list, another for campaigns. The template writes the event '
          'handler against whichever field equate AppGen gave that instance.'))

    add(h2('apicode', 'Asking from an embed'))
    add(p('<b>emailTo - Ask the provider</b> is the code template. Drop it in any embed '
          '&mdash; a button, a menu item, the end of a process &mdash; and pick the '
          'operation:'))
    add(table(['Prompt', 'What it does'], [
        ['Do this', 'Load the blocked addresses, unblock one, unblock every one, block '
         'an address, is this address blocked, load the statistics, the activity, the '
         'contacts, the lists, the campaigns, send a campaign, export the blocked list '
         'to CSV, or open the management window.'],
        ['Which list', 'Everything, bounces, blocked, spam reports, unsubscribed or '
         'invalid. A provider that keeps one list for all of them answers the same '
         'rows whichever you pick, labelled with what they really are.'],
        ['Value', 'The address, campaign id or file name the operation works on &mdash; '
         'typed, or taken from a variable at run time.'],
        ['Put the result in', 'For a load, the NUMBER of rows (or -1 if the provider '
         'said no). For everything else, 1 means it worked.'],
        ['Show the error', 'Pops the provider&rsquo;s own words. Either way they are in '
         '<code>LastErrorText</code>, and the address called is in '
         '<code>LastUrl</code>.'],
    ]))
    add(p('What it writes is short, because the class is where the work is:'))
    add(code(S_APIEMBED))
    add(p('The rows land in the object&rsquo;s queues, which are the same shape '
          'whoever the provider is &mdash; <code>SuppQ</code>, <code>StatQ</code>, '
          '<code>EventQ</code> and the rest. Loop them yourself, or call '
          '<code>Manage()</code> and let the shipped window do it.'))

    add(h2('button', 'emailTo - E-mail button'))
    add(p('Drag it onto any window; drop it more than once if you want to. AppGen uniques '
          'the field equate (<code>?EmailBtn</code>, <code>?EmailBtn:2</code>&hellip;) '
          'and the template attaches the handler to whichever one this instance got.'))
    add(note('tip', "Which button holds the sender's address? Neither",
             '<p>An account belongs to the <em>application</em>, not to a button. The '
             'server, the from address, the user name, the password and the OAuth2 '
             'client are set once, on <b>emailTo - Global</b>&rsquo;s Account tab. A '
             'button only says <em>what to do</em> &mdash; so you can put two on one '
             'window, one to send and one to open the setup window, and neither of them '
             'carries a credential.</p>'
             '<p>The button&rsquo;s own <b>Account</b> tab has no prompts for exactly '
             'that reason. It is there to point at the place that does.</p>'))
    add(p('Which of the two a given instance is shows in the AppGen list without '
          'opening it, because the description names the action:'))
    add(code('emailTo - E-mail button   E-mail button - opens the COMPOSE window\n'
             'emailTo - E-mail button   E-mail button - opens ACCOUNT SETUP', 'dos'))

    add(h3('button-general', 'General'))
    add(table(['Prompt', 'What it does'], [
        ['Disable this button', 'Generates nothing for this instance. The button stays on the window, inert.'],
        ['Mail object name', 'Must match the global extension. <code>Mailer</code> by default.'],
        ['Action', 'Open the compose window, send straight away with no window, or open the account setup window.'],
        ['Tell the user it worked',
         'Greyed unless the action is <em>send straight away</em> &mdash; the only action that reads it.'],
        ['Show the error if it failed',
         'Same. Calls <code>ShowError</code>; off, the reason is still in <code>LastErrorText</code>.'],
    ]))
    add(note('note', 'All three actions start life labelled "E-mail..."',
             '<p>The action is chosen after the control is dropped, so the template '
             'cannot vary the caption for you. Rename the button in the window designer '
             '&mdash; two buttons that both read <em>E-mail...</em> confuse the user of '
             'the finished program as much as they confuse you in AppGen.</p>'))

    add(h3('button-account', 'Account'))
    add(p('No prompts. It names the one place the account is configured &mdash; '
          '<b>Application &rarr; Global Properties &rarr; Extensions &rarr; emailTo - '
          'Global &rarr; Account</b> &mdash; and explains that a setup-window button is '
          'how an end user overrides it: into your settings table if you mapped one, '
          'otherwise into an INI beside the <code>.EXE</code>.'))

    add(h3('button-message', 'Message'))
    add(p('Who it goes to and what it says. What this tab <em>means</em> depends on the '
          'action, which is why the General tab spells the three cases out:'))
    add(table(['Action', 'What the Message tab does'], [
        ['Open the compose window', 'Pre-fills the window. The user can change any of it before sending.'],
        ['Send straight away', 'Is the message. Nothing is shown; anything left blank is omitted.'],
        ['Open the account setup window', 'Nothing &mdash; the whole tab greys out, because no message is involved.'],
    ]))
    add(table(['Prompt', 'What it does'], [
        ['To / Cc / Subject / Body', 'Literals for a button that always sends the same thing.'],
        ['&hellip;or take it from a variable', 'A field picker. Overrides the literal beside it.'],
        ['Body is HTML', 'Calls <code>SetHtml</code> instead of <code>SetText</code>.'],
        ['Attachment', 'A literal path, or a variable holding one.'],
    ]))
    add(p('Here are all three actions, as generated:'))
    add(code(S_GEN_BUTTON))

    add(h2('codetemplates', 'The three code templates'))
    add(p('<b>Send an e-mail here</b> is the one that gets used most. Its prompts mirror '
          'the button&rsquo;s Message tab, plus a place to put the result:'))
    add(table(['Prompt', 'What it does'], [
        ['To / Cc / Bcc', 'Literals, or a variable for To.'],
        ['Subject / Body', 'Literals, or variables. Body can be HTML.'],
        ['Attachment', 'A literal path, or a variable &mdash; this is how a report gets mailed.'],
        ['Put the result in', 'A field that receives 1 for sent, 0 for not.'],
        ['Tell the user it worked / Show the error', 'Both optional; the reason is always in <code>LastErrorText</code>.'],
    ]))
    add(note('tip', 'Mailing a report',
             '<p>Write the PDF, then drop <b>Send an e-mail here</b> immediately after '
             'it and point the attachment prompt at the variable holding the file name. '
             'That is the whole recipe &mdash; there is no separate report template '
             'because there does not need to be one.</p>'))
    add(p('<b>Open the compose window here</b> pre-fills and opens the write-and-send '
          'window. <b>Open the mail account setup window here</b> opens the account '
          'window &mdash; put it on a Setup menu and your users can configure their own '
          'mail without you.'))
    add(p('All three carry the same reminder the button does: the sender address, the '
          'server and the password are not among their prompts, because they belong to '
          'the global extension.'))

    add(h2('embeds', 'Where the generated code lands'))
    add(table(['Template', 'Embed point', 'What arrives'], [
        ['Global', '<code>%AfterGlobalIncludes</code>', 'One <code>INCLUDE</code>, <code>ONCE</code>.'],
        ['Global', '<code>%GlobalData</code>', 'The object and <code>emailToLanguage</code>.'],
        ['Global', '<code>%ProgramSetup</code> PRIORITY(8000)', 'Init, the defaults, <code>LoadAccount</code>.'],
        ['Global', '<code>%ProgramProcedures</code>', 'The table binding, when one is mapped.'],
        ['Global', '<code>%DLLExportList</code>', 'The object and the language byte, when this app is the owner.'],
        ['Global', '<code>%BeforeGenerateApplication</code>', 'Registers the <code>EMAILTO</code> class category.'],
        ['Button', '<code>%CustomGlobalDeclarations</code>', 'The <code>INCLUDE</code>, so the module sees the class.'],
        ['Button', '<code>%ControlEventHandling</code>', 'The handler, on this instance&rsquo;s own equate.'],
        ['Code templates', 'wherever you drop them', 'The calls, inline.'],
    ]))

    add(nextcards(['reference.html', 'programmers-guide.html', 'getting-started.html']))

    body = '\n'.join(B)
    groups = [
        ('Overview', [('five', 'The ten templates')]),
        ('The global extension', [('global', 'emailTo - Global'),
                                  ('global-general', 'General'),
                                  ('global-account', 'Account'),
                                  ('global-signin', 'Sign-in'),
                                  ('global-api', 'emailTo - Provider API'),
                                  ('global-sync', 'Sync tables'),
                                  ('global-table', 'Table'),
                                  ('global-multidll', 'Multi-DLL'),
                                  ('global-writes', 'What it writes')]),
        ('The rest', [('apibutton', 'The mail account button'),
                      ('syncbutton', 'The sync button'),
                      ('apicode', 'Asking from an embed'),
                      ('button', 'The e-mail button'),
                      ('button-general', 'General'),
                      ('button-account', 'Account'),
                      ('button-message', 'Message'),
                      ('codetemplates', 'The code templates'),
                      ('embeds', 'Where the code lands')]),
    ]
    return page('template-guide.html', PAGE_TITLES['template-guide.html'][0], 'Volume 3',
                'Template Guide',
                'Every template, every tab, every prompt &mdash; and the code the '
                'generator actually writes into your application.',
                ['10 templates', 'Every prompt', 'Generated code', 'Multi-DLL'],
                groups, body)


# =====================================================================
#  4  REFERENCE   (generated from the sources)
# =====================================================================
CLASS_BLURB = {
    'EmailNetClass':
        'The transport primitives, and the only class that touches C. A socket, '
        'optionally wrapped in TLS; an HTTPS request; the OAuth2 loopback redirect; '
        'DPAPI, SHA-256 and secure random.',
    'EmailBufClass':
        'A growing byte buffer. Building MIME means appending thousands of small pieces '
        'to something that ends up megabytes long, and Clarion has no string builder - '
        'this doubles its capacity instead, so building stays linear.',
    'EmailMsgClass':
        'The message, and the MIME document it turns into. Pure Clarion: nothing here '
        'touches a socket, which is why all four transports can share it.',
    'EmailOAuthClass':
        'The OAuth2 authorisation-code flow with PKCE. It borrows the network and '
        'encoder objects from EmailToClass and owns neither.',
    'EmailToClass':
        'The sender. It owns an account and knows four ways to put a message on the '
        'wire, plus the setup and compose windows.',
}


def methrow(cls, m):
    key = cls + '.' + m['name']
    ex = EXAMPLES.get(key)
    if not ex:
        PROBLEMS.append('reference.html: %s has no worked example' % key)
        ex = ''
    doc = m['doc'] or m['lead']
    attrs = []
    if 'VIRTUAL' in m['attrs']:
        attrs.append('<span class="tag">VIRTUAL</span>')
    if 'DERIVED' in m['attrs']:
        attrs.append('<span class="tag">DERIVED</span>')
    return ('<tr class="fn"><td><code class="mem">%s</code>%s<div class="sig">%s</div>'
            '%s%s</td></tr>'
            % (esc(m['name']), ' ' + ''.join(attrs) if attrs else '',
               esc(m['sig']),
               '<p class="mdoc">%s</p>' % esc(doc) if doc else '',
               usecode(ex)))


def proprow(cls, pr):
    key = cls + '.' + pr['name']
    ex = EXAMPLES.get(key)
    if not ex:
        PROBLEMS.append('reference.html: %s has no worked example' % key)
        ex = ''
    doc = pr['doc'] or pr['lead']
    return ('<tr class="fn"><td><code class="mem">%s</code>'
            '<div class="sig">%s</div>%s%s</td></tr>'
            % (esc(pr['name']), esc(pr['type']),
               '<p class="mdoc">%s</p>' % esc(doc) if doc else '',
               usecode(ex)))


def build_reference():
    B = []
    add = B.append
    cs = extract.classes()

    add(h2('how', 'How to read this'))
    add(p('Every signature on this page was read out of the shipped '
          '<code>.inc</code> files when the page was built, so it is the signature in '
          'your build. Every member carries a line of real code &mdash; the build fails '
          'if one does not.'))
    add(p('<code>Mailer</code> throughout is the global <code>EmailToClass</code> object '
          'the template declares. <code>PROC</code> on a signature means the return '
          'value may be ignored; <code>VIRTUAL</code> means it is meant to be '
          'overridden.'))
    add(table(['Class', 'Lives in', 'What it is'],
              [['<code>%s</code>' % c['name'], '<code>%s</code>' % c['inc'],
                esc(CLASS_BLURB.get(c['name'], ''))] for c in cs]))

    for c in cs:
        cid = slug(c['name'])
        add(h2(cid, c['name']))
        add(p(esc(CLASS_BLURB.get(c['name'], ''))))
        props = [x for x in c['props'] if not x['private']]
        meths = [x for x in c['methods'] if not x['private']]
        if props:
            add(h3(cid + '-props', c['name'] + ' properties'))
            add('<div class="tw"><table class="api"><tbody>%s</tbody></table></div>'
                % ''.join(proprow(c['name'], x) for x in props))
        if meths:
            add(h3(cid + '-meths', c['name'] + ' methods'))
            add('<div class="tw"><table class="api"><tbody>%s</tbody></table></div>'
                % ''.join(methrow(c['name'], x) for x in meths))

    #  ---- the account group ----
    add(h2('account-group', 'EmailAccountGroup'))
    add(p('The account, field by field. This is the structure the template maps your '
          'table columns onto.'))
    for gname, inc, fields in extract.groups():
        if gname != 'EmailAccountGroup':
            continue
        add(table(['Field', 'Type', 'What it is'],
                  [['<code>%s</code>' % esc(f[0]), '<code>%s</code>' % esc(f[1]),
                    esc(f[2])] for f in fields]))

    #  ---- the queues ----
    add(h2('queues', 'The queues'))
    add(p('Four <code>TYPE</code>d queues are part of the public surface. Walk them with '
          '<code>RECORDS</code> and <code>GET</code>; do not <code>ADD</code> to them '
          'directly &mdash; the <code>AddTo</code> / <code>Attach</code> / '
          '<code>AddHeader</code> methods keep them consistent.'))
    for qname, inc, fields in extract.queues():
        add(h3(slug(qname), qname))
        add(table(['Field', 'Type', 'What it is'],
                  [['<code>%s</code>' % esc(f[0]), '<code>%s</code>' % esc(f[1]),
                    esc(f[2])] for f in fields]))

    #  ---- the equates ----
    add(h2('equates', 'The equates'))
    add(p('Every equate emailTo defines, grouped by prefix. They all begin '
          '<code>ET</code> so nothing collides with another template.'))
    eq = extract.equates()
    order = ['ETTrn', 'ETPrv', 'ETSec', 'ETAuth', 'ETLng', 'ETSend',
             'ETMsg', 'ETAddr', 'ETChs', 'ETPri', 'ETNet', 'ETTxt']
    titles = {
        'ETTrn': 'Transports', 'ETPrv': 'Providers', 'ETSec': 'Connection security',
        'ETAuth': 'Authentication', 'ETLng': 'Language', 'ETSend': 'Send errors',
        'ETMsg': 'Message errors', 'ETAddr': 'Recipient kinds',
        'ETChs': 'Character sets', 'ETPri': 'Priority',
        'ETNet': 'Network errors', 'ETTxt': 'Translatable strings',
    }
    for prefix in order:
        if prefix not in eq:
            continue
        items = eq[prefix]['items']
        add(h3('eq-' + prefix.lower(), titles.get(prefix, prefix)))
        add(table(['Equate', 'Value', 'Notes'],
                  [['<code>%s</code>' % esc(n), '<code>%s</code>' % esc(v), esc(cm)]
                   for n, v, cm in items]))

    #  ---- the C layer ----
    add(h2('capi', 'The C layer'))
    add(p('<code>emailc.c</code> is compiled into your <code>.EXE</code> by '
          'Clarion&rsquo;s own C compiler. You do not call these directly &mdash; '
          '<code>EmailNetClass</code> wraps every one &mdash; but the list is here '
          'because it is the whole of what emailTo cannot do in Clarion.'))
    add(table(['Function', 'Prototype'],
              [['<code>%s</code>' % esc(n), '<code>%s</code>' % esc(s)]
               for n, s in extract.c_api()]))
    add(note('note', 'Every one of these DLLs ships with Windows',
             '<p><code>ws2_32</code>, <code>secur32</code>, <code>winhttp</code>, '
             '<code>crypt32</code>, <code>advapi32</code> and <code>shell32</code> are '
             'bound at run time with <code>LoadLibrary</code>, so there is no import '
             'library, nothing to redistribute, and a machine missing one gives a clean '
             'error code rather than failing to start.</p>'))

    add(nextcards(['getting-started.html', 'programmers-guide.html', 'template-guide.html']))

    body = '\n'.join(B)
    groups = [('', [('how', 'How to read this')])]
    for c in cs:
        cid = slug(c['name'])
        items = [(cid, c['name'])]
        if [x for x in c['props'] if not x['private']]:
            items.append((cid + '-props', 'Properties'))
        if [x for x in c['methods'] if not x['private']]:
            items.append((cid + '-meths', 'Methods'))
        groups.append((c['name'], items))
    groups.append(('Structures', [('account-group', 'EmailAccountGroup'),
                                  ('queues', 'The queues')] +
                   [(slug(q[0]), q[0]) for q in extract.queues()]))
    groups.append(('Equates', [('equates', 'The equates')] +
                   [('eq-' + pfx.lower(), titles.get(pfx, pfx))
                    for pfx in order if pfx in eq]))
    groups.append(('C', [('capi', 'The C layer')]))

    return page('reference.html', PAGE_TITLES['reference.html'][0], 'Volume 4', 'Reference',
                'Every class, method, property, equate and structure &mdash; read out '
                'of the sources when this page was built.',
                ['5 classes', '%d members' % len(EXAMPLES), 'Generated', 'Every one worked'],
                groups, body, showfilter=True)


# =====================================================================
NEWLINE = chr(10)

if __name__ == '__main__':
    built = [
        ('getting-started.html',   build_getting_started()),
        ('programmers-guide.html', build_programmers_guide()),
        ('template-guide.html',    build_template_guide()),
        ('reference.html',         build_reference()),
    ]
    for name, size in built:
        print('  %-24s %7d bytes' % (name, size))
    if PROBLEMS:
        print(NEWLINE + '%d problem(s) - the manual has drifted from the code:' % len(PROBLEMS))
        for x in PROBLEMS:
            print('   ', x)
        raise SystemExit(1)
    print(NEWLINE + 'no drift: every nav entry lands on a heading, every heading is in a nav,')
    print('and all %d public members carry a worked example.' % len(EXAMPLES))
