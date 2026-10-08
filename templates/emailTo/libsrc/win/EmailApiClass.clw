! ============================================================================
!  EmailApiClass - implementation.
!
!  Three layers, and only the middle one knows anything about a provider:
!
!    BuildMap()        the matrix.  Data, not logic: one row per operation per
!                      provider.  Everything a provider does differently is
!                      spelled out here and nowhere else.
!    Fetch / Perform   the engine.  Expands the URL, signs the request, follows
!                      the paging, parses the reply, hands each item to
!                      MapItem.  It has no idea who it is talking to.
!    GetXxx / AddXxx   the public methods.  They set the argument slots, call
!                      the engine, and answer with a filled queue.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  INCLUDE('EmailApiClass.INC'),ONCE

ETA_DowTbl   STRING('MonTueWedThuFriSatSun')      ! 2024-01-01 was a Monday
ETA_MonTbl   STRING('JanFebMarAprMayJunJulAugSepOctNovDec')
ETA_Hex      STRING('0123456789ABCDEF')

!  Writing the CSV goes straight to kernel32 rather than through a Clarion
!  FILE.  A FILE would drag a file DRIVER into the link, and this template's
!  whole promise is that it adds no dependency to your application - an app
!  with no ASCII driver registered would stop linking the moment somebody
!  pressed Export.
ETA_GENERIC_WRITE    EQUATE(40000000h)
ETA_CREATE_ALWAYS    EQUATE(2)
ETA_FILE_ATTR_NORMAL EQUATE(80h)
ETA_INVALID_HANDLE   EQUATE(-1)

!  Windows' own UTC clock. TODAY() and CLOCK() are LOCAL time, and a signature
!  built on local time is refused everywhere but London in winter.
ETA_SystemTime      GROUP,TYPE
wYear                 USHORT
wMonth                USHORT
wDayOfWeek            USHORT
wDay                  USHORT
wHour                 USHORT
wMinute               USHORT
wSecond               USHORT
wMilliseconds         USHORT
                    END

  MAP
    MODULE('kernel32')
ETA_CreateFileA   PROCEDURE(*CSTRING,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,PASCAL,RAW,NAME('CreateFileA')
ETA_WriteFile     PROCEDURE(LONG,*STRING,ULONG,*ULONG,LONG),LONG,PROC,PASCAL,RAW,NAME('WriteFile')
ETA_CloseHandle   PROCEDURE(LONG),LONG,PROC,PASCAL,NAME('CloseHandle')
ETA_GetSystemTime PROCEDURE(*ETA_SystemTime),PASCAL,RAW,NAME('GetSystemTime')
    END
  END

! ============================================================================
!  Housekeeping
! ============================================================================
EmailApiClass.Construct PROCEDURE
  CODE
  SELF.MapQ      &= NEW(EmailApiMapQueue)
  SELF.SuppQ     &= NEW(EmailSuppQueue)
  SELF.StatQ     &= NEW(EmailStatQueue)
  SELF.EventQ    &= NEW(EmailEventQueue)
  SELF.ContactQ  &= NEW(EmailContactQueue)
  SELF.ListQ     &= NEW(EmailListQueue)
  SELF.CampaignQ &= NEW(EmailCampaignQueue)
  SELF.TemplateQ &= NEW(EmailTemplateQueue)
  SELF.SenderQ   &= NEW(EmailSenderQueue)
  SELF.DomainQ   &= NEW(EmailDomainQueue)
  SELF.HookQ     &= NEW(EmailHookQueue)
  SELF.Json      &= NEW(EmailJsonClass)
  SELF.Enc       &= NEW(EmailMsgClass)
  SELF.UrlBuf    &= NEW(EmailBufClass)
  SELF.BodyBuf   &= NEW(EmailBufClass)
  SELF.HdrBuf    &= NEW(EmailBufClass)
  SELF.TxtBuf    &= NEW(EmailBufClass)
  SELF.Language  = ETLng:English
  SELF.PageSize  = 100
  SELF.MaxRows   = 5000
  RETURN

EmailApiClass.Destruct PROCEDURE
  CODE
  IF NOT SELF.MapQ      &= NULL THEN FREE(SELF.MapQ)      ; DISPOSE(SELF.MapQ).
  IF NOT SELF.SuppQ     &= NULL THEN FREE(SELF.SuppQ)     ; DISPOSE(SELF.SuppQ).
  IF NOT SELF.StatQ     &= NULL THEN FREE(SELF.StatQ)     ; DISPOSE(SELF.StatQ).
  IF NOT SELF.EventQ    &= NULL THEN FREE(SELF.EventQ)    ; DISPOSE(SELF.EventQ).
  IF NOT SELF.ContactQ  &= NULL THEN FREE(SELF.ContactQ)  ; DISPOSE(SELF.ContactQ).
  IF NOT SELF.ListQ     &= NULL THEN FREE(SELF.ListQ)     ; DISPOSE(SELF.ListQ).
  IF NOT SELF.CampaignQ &= NULL THEN FREE(SELF.CampaignQ) ; DISPOSE(SELF.CampaignQ).
  IF NOT SELF.TemplateQ &= NULL THEN FREE(SELF.TemplateQ) ; DISPOSE(SELF.TemplateQ).
  IF NOT SELF.SenderQ   &= NULL THEN FREE(SELF.SenderQ)   ; DISPOSE(SELF.SenderQ).
  IF NOT SELF.DomainQ   &= NULL THEN FREE(SELF.DomainQ)   ; DISPOSE(SELF.DomainQ).
  IF NOT SELF.HookQ     &= NULL THEN FREE(SELF.HookQ)     ; DISPOSE(SELF.HookQ).
  IF NOT SELF.Json      &= NULL THEN DISPOSE(SELF.Json).
  IF NOT SELF.Enc       &= NULL THEN DISPOSE(SELF.Enc).
  IF NOT SELF.UrlBuf    &= NULL THEN DISPOSE(SELF.UrlBuf).
  IF NOT SELF.BodyBuf   &= NULL THEN DISPOSE(SELF.BodyBuf).
  IF NOT SELF.HdrBuf    &= NULL THEN DISPOSE(SELF.HdrBuf).
  IF NOT SELF.TxtBuf    &= NULL THEN DISPOSE(SELF.TxtBuf).
  RETURN

!  Borrow the account and the wire.  The API object never owns a credential of
!  its own: whatever the Setup window stored is what these calls use.
EmailApiClass.Init PROCEDURE(EmailToClass pMailer)
  CODE
  SELF.Mailer &= pMailer
  SELF.Net    &= pMailer.Net
  SELF.Language = pMailer.Language
  SELF.Silent   = pMailer.Silent
  FREE(SELF.MapQ)
  SELF.BuildMap()
  SELF.SetErr(ETApi:Ok)
  RETURN

EmailApiClass.SetErr PROCEDURE(LONG pCode,<STRING pText>)
  CODE
  SELF.LastError = pCode
  IF OMITTED(pText) OR NOT CLIP(pText)
    CASE pCode
    OF ETApi:Ok           ; SELF.LastErrorText = ''
    OF ETApi:NoKey        ; SELF.LastErrorText = 'No API key is configured for this account.'
    OF ETApi:NotSupported ; SELF.LastErrorText = SELF.Txt(ETATxt:NotSupport)
    OF ETApi:Http         ; SELF.LastErrorText = 'The provider could not be reached: ' & |
                                                 CLIP(SELF.Net.LastErrorText)
    OF ETApi:BadReply     ; SELF.LastErrorText = 'The provider''s reply could not be read.'
    OF ETApi:NoObject     ; SELF.LastErrorText = 'Init() has not been called on this object.'
    OF ETApi:Cancelled    ; SELF.LastErrorText = ''
    ELSE                  ; SELF.LastErrorText = 'API error ' & pCode & '.'
    END
  ELSE
    SELF.LastErrorText = SUB(CLIP(pText), 1, 512)
  END
  RETURN CHOOSE(pCode = ETApi:Ok, 1, 0)

EmailApiClass.ShowError PROCEDURE
  CODE
  IF SELF.Silent OR NOT SELF.LastError THEN RETURN.
  MESSAGE(CLIP(SELF.LastErrorText), SELF.Txt(ETATxt:Manage), ICON:Exclamation)

!  What the provider said, cut down to something that fits in a message box.
EmailApiClass.FailedText PROCEDURE()
body CSTRING(513)
  CODE
  body = SUB(CLIP(SELF.Net.Body()), 1, 400)
  IF NOT CLIP(body)
    RETURN 'HTTP ' & SELF.LastStatus & ' with no explanation.'
  END
  RETURN 'HTTP ' & SELF.LastStatus & ': ' & CLIP(body)

! ============================================================================
!  The provider matrix
!
!  Row(provider, operation, kind, verb, url, itempath, map, body, nextpath)
!
!  kind      for a suppression operation, which list it serves.  ETSup:All on a
!            LIST row means "this provider keeps one list for everything" - the
!            engine then works out each row's real kind from what the provider
!            called it.  For the Account operation, kind is a part number: the
!            answer is merged from every part, because most providers keep the
!            name, the plan and the address at three different addresses.
!            For ContactAdd, 0 = without a list, 1 = into a list.
!  itempath  '' the reply IS the array, '*' the reply is ONE item, otherwise
!            the path to the array.  A path that is not in the reply falls back
!            to the first array in the document.
! ============================================================================
EmailApiClass.BuildMap PROCEDURE()
  CODE
!===== SendGrid ==============================================================
  SELF.Row(ETPrv:SendGrid, ETOp:Account, 0, 'GET', '{{scheme}{{host}/v3/user/account', '*', |
           'Plan=type;Reputation=reputation')
  SELF.Row(ETPrv:SendGrid, ETOp:Account, 1, 'GET', '{{scheme}{{host}/v3/user/profile', '*', |
           'Name=first_name;Company=company')
  SELF.Row(ETPrv:SendGrid, ETOp:Account, 2, 'GET', '{{scheme}{{host}/v3/user/email', '*', |
           'Address=email')
  SELF.Row(ETPrv:SendGrid, ETOp:Suppressions, ETSup:Bounce, 'GET', |
           '{{scheme}{{host}/v3/suppression/bounces?limit={{limit}&offset={{offset}', '', |
           'Address=email;Reason=reason;Id=status;When=#created')
  SELF.Row(ETPrv:SendGrid, ETOp:Suppressions, ETSup:Block, 'GET', |
           '{{scheme}{{host}/v3/suppression/blocks?limit={{limit}&offset={{offset}', '', |
           'Address=email;Reason=reason;Id=status;When=#created')
  SELF.Row(ETPrv:SendGrid, ETOp:Suppressions, ETSup:Spam, 'GET', |
           '{{scheme}{{host}/v3/suppression/spam_reports?limit={{limit}&offset={{offset}', '', |
           'Address=email;Reason=!spam report;When=#created')
  SELF.Row(ETPrv:SendGrid, ETOp:Suppressions, ETSup:Unsub, 'GET', |
           '{{scheme}{{host}/v3/suppression/unsubscribes?limit={{limit}&offset={{offset}', '', |
           'Address=email;Reason=!unsubscribed;When=#created')
  SELF.Row(ETPrv:SendGrid, ETOp:Suppressions, ETSup:Invalid, 'GET', |
           '{{scheme}{{host}/v3/suppression/invalid_emails?limit={{limit}&offset={{offset}', '', |
           'Address=email;Reason=reason;When=#created')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppDelete, ETSup:Bounce,  'DELETE', '{{scheme}{{host}/v3/suppression/bounces/{{email}')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppDelete, ETSup:Block,   'DELETE', '{{scheme}{{host}/v3/suppression/blocks/{{email}')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppDelete, ETSup:Spam,    'DELETE', '{{scheme}{{host}/v3/suppression/spam_reports/{{email}')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppDelete, ETSup:Unsub,   'DELETE', '{{scheme}{{host}/v3/asm/suppressions/global/{{email}')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppDelete, ETSup:Invalid, 'DELETE', '{{scheme}{{host}/v3/suppression/invalid_emails/{{email}')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppDeleteAll, ETSup:Bounce,  'DELETE', '{{scheme}{{host}/v3/suppression/bounces',        '', '', '{{"delete_all":true}')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppDeleteAll, ETSup:Block,   'DELETE', '{{scheme}{{host}/v3/suppression/blocks',         '', '', '{{"delete_all":true}')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppDeleteAll, ETSup:Spam,    'DELETE', '{{scheme}{{host}/v3/suppression/spam_reports',   '', '', '{{"delete_all":true}')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppDeleteAll, ETSup:Invalid, 'DELETE', '{{scheme}{{host}/v3/suppression/invalid_emails', '', '', '{{"delete_all":true}')
  SELF.Row(ETPrv:SendGrid, ETOp:SuppAdd, ETSup:All, 'POST', '{{scheme}{{host}/v3/asm/suppressions/global', '', '', |
           '{{"recipient_emails":["{{email}"]}')
  SELF.Row(ETPrv:SendGrid, ETOp:Stats, 0, 'GET', |
           '{{scheme}{{host}/v3/stats?start_date={{ymdfrom}&end_date={{ymdto}&aggregated_by=day', '', |
           'When=$date;Requests=stats.0.metrics.requests;Delivered=stats.0.metrics.delivered;' & |
           'Opens=stats.0.metrics.opens;UniqueOpens=stats.0.metrics.unique_opens;' & |
           'Clicks=stats.0.metrics.clicks;UniqueClicks=stats.0.metrics.unique_clicks;' & |
           'HardBounces=stats.0.metrics.bounces;Blocks=stats.0.metrics.blocks;' & |
           'SpamReports=stats.0.metrics.spam_reports;Unsubscribed=stats.0.metrics.unsubscribes;' & |
           'Invalid=stats.0.metrics.invalid_emails')
  SELF.Row(ETPrv:SendGrid, ETOp:Events, 0, 'GET', '{{scheme}{{host}/v3/messages?limit={{limit}', 'messages', |
           'When=@last_event_time;Address=to_email;EventName=status;Subject=subject;MessageId=msg_id')
  SELF.Row(ETPrv:SendGrid, ETOp:Contacts, 0, 'GET', '{{scheme}{{host}/v3/marketing/contacts', 'result', |
           'Id=id;Address=email;Name=first_name;When=@created_at;ListIds=list_ids.0')
  SELF.Row(ETPrv:SendGrid, ETOp:Lists, 0, 'GET', '{{scheme}{{host}/v3/marketing/lists?page_size={{limit}', 'result', |
           'Id=id;Name=name;Members=contact_count')
  SELF.Row(ETPrv:SendGrid, ETOp:ContactAdd, 0, 'PUT', '{{scheme}{{host}/v3/marketing/contacts', '', '', |
           '{{"contacts":[{{"email":"{{email}","first_name":"{{text}"}]}')
  SELF.Row(ETPrv:SendGrid, ETOp:ContactAdd, 1, 'PUT', '{{scheme}{{host}/v3/marketing/contacts', '', '', |
           '{{"list_ids":["{{id}"],"contacts":[{{"email":"{{email}","first_name":"{{text}"}]}')
  SELF.Row(ETPrv:SendGrid, ETOp:ContactDelete, 0, 'DELETE', '{{scheme}{{host}/v3/marketing/contacts?ids={{id}')
  SELF.Row(ETPrv:SendGrid, ETOp:ListAdd, 0, 'POST', '{{scheme}{{host}/v3/marketing/lists', '', '', '{{"name":"{{text}"}')
  SELF.Row(ETPrv:SendGrid, ETOp:Campaigns, 0, 'GET', '{{scheme}{{host}/v3/marketing/singlesends', 'result', |
           'Id=id;Name=name;Status=status;When=@send_at')
  SELF.Row(ETPrv:SendGrid, ETOp:CampaignAdd, 0, 'POST', '{{scheme}{{host}/v3/marketing/singlesends', '', '', |
           '{{"name":"{{text}","send_to":{{"list_ids":["{{id}"]},' & |
           '"email_config":{{"subject":"{{subject}","html_content":"{{html}"}}')
  SELF.Row(ETPrv:SendGrid, ETOp:CampaignSend, 0, 'PUT', '{{scheme}{{host}/v3/marketing/singlesends/{{id}/schedule', |
           '', '', '{{"send_at":"now"}')
  SELF.Row(ETPrv:SendGrid, ETOp:Templates, 0, 'GET', |
           '{{scheme}{{host}/v3/templates?generations=dynamic&page_size={{limit}', 'result', |
           'Id=id;Name=name;When=@updated_at')
  SELF.Row(ETPrv:SendGrid, ETOp:Senders, 0, 'GET', '{{scheme}{{host}/v3/verified_senders', 'results', |
           'Id=id;Address=from_email;Name=from_name;Verified=verified')
  SELF.Row(ETPrv:SendGrid, ETOp:Domains, 0, 'GET', '{{scheme}{{host}/v3/whitelabel/domains', '', |
           'Id=id;Name=domain;Verified=valid')
  SELF.Row(ETPrv:SendGrid, ETOp:Webhooks, 0, 'GET', '{{scheme}{{host}/v3/user/webhooks/event/settings', '*', |
           'Url=url;Active=enabled;Events=!all')

!===== Brevo =================================================================
!  Brevo keeps ONE blocked list, with a reason code that says which kind of
!  block it really is - so the row is registered for ETSup:All and the engine
!  reads the kind off each row.
  SELF.Row(ETPrv:Brevo, ETOp:Account, 0, 'GET', '{{scheme}{{host}/v3/account', '*', |
           'Name=firstName;Company=companyName;Address=email;Plan=plan.0.type;Credits=plan.0.credits')
  SELF.Row(ETPrv:Brevo, ETOp:Suppressions, ETSup:All, 'GET', |
           '{{scheme}{{host}/v3/smtp/blockedContacts?limit={{limit}&offset={{offset}', 'contacts', |
           'Address=email;Reason=reason.message;KindText=reason.code;When=@blockedAt;Sender=senderEmail')
  SELF.Row(ETPrv:Brevo, ETOp:SuppDelete, ETSup:All, 'DELETE', '{{scheme}{{host}/v3/smtp/blockedContacts/{{email}')
  SELF.Row(ETPrv:Brevo, ETOp:SuppAdd, ETSup:All, 'PUT', '{{scheme}{{host}/v3/contacts/{{email}', '', '', |
           '{{"emailBlacklisted":true}')
  SELF.Row(ETPrv:Brevo, ETOp:Stats, 0, 'GET', |
           '{{scheme}{{host}/v3/smtp/statistics/reports?startDate={{ymdfrom}&endDate={{ymdto}&limit={{limit}', |
           'reports', |
           'When=$date;Requests=requests;Delivered=delivered;Opens=opens;UniqueOpens=uniqueOpens;' & |
           'Clicks=clicks;UniqueClicks=uniqueClicks;HardBounces=hardBounces;SoftBounces=softBounces;' & |
           'Blocks=blocked;SpamReports=spamReports;Unsubscribed=unsubscribed;Invalid=invalid')
  SELF.Row(ETPrv:Brevo, ETOp:Events, 0, 'GET', |
           '{{scheme}{{host}/v3/smtp/statistics/events?limit={{limit}&offset={{offset}' & |
           '&startDate={{ymdfrom}&endDate={{ymdto}', 'events', |
           'When=@date;Address=email;EventName=event;Reason=reason;Subject=subject;' & |
           'MessageId=messageId;Link=link')
  SELF.Row(ETPrv:Brevo, ETOp:Contacts, 0, 'GET', |
           '{{scheme}{{host}/v3/contacts?limit={{limit}&offset={{offset}', 'contacts', |
           'Id=id;Address=email;Blocked=emailBlacklisted;When=@createdAt;ListIds=listIds.0')
  SELF.Row(ETPrv:Brevo, ETOp:ListMembers, 0, 'GET', |
           '{{scheme}{{host}/v3/contacts/lists/{{id}/contacts?limit={{limit}&offset={{offset}', 'contacts', |
           'Id=id;Address=email;Blocked=emailBlacklisted;When=@createdAt')
  SELF.Row(ETPrv:Brevo, ETOp:Lists, 0, 'GET', |
           '{{scheme}{{host}/v3/contacts/lists?limit={{limit}&offset={{offset}', 'lists', |
           'Id=id;Name=name;Members=totalSubscribers;Blocked=totalBlacklisted;FolderId=folderId')
  SELF.Row(ETPrv:Brevo, ETOp:ContactAdd, 0, 'POST', '{{scheme}{{host}/v3/contacts', '', '', |
           '{{"email":"{{email}","attributes":{{"FIRSTNAME":"{{text}"},"updateEnabled":true}')
  SELF.Row(ETPrv:Brevo, ETOp:ContactAdd, 1, 'POST', '{{scheme}{{host}/v3/contacts', '', '', |
           '{{"email":"{{email}","attributes":{{"FIRSTNAME":"{{text}"},"listIds":[{{id}],"updateEnabled":true}')
  SELF.Row(ETPrv:Brevo, ETOp:ContactDelete, 0, 'DELETE', '{{scheme}{{host}/v3/contacts/{{email}')
  SELF.Row(ETPrv:Brevo, ETOp:ListAdd, 0, 'POST', '{{scheme}{{host}/v3/contacts/lists', '', '', |
           '{{"name":"{{text}","folderId":1}')
  SELF.Row(ETPrv:Brevo, ETOp:Campaigns, 0, 'GET', |
           '{{scheme}{{host}/v3/emailCampaigns?limit={{limit}&offset={{offset}', 'campaigns', |
           'Id=id;Name=name;Subject=subject;Status=status;When=@scheduledAt')
  SELF.Row(ETPrv:Brevo, ETOp:CampaignAdd, 0, 'POST', '{{scheme}{{host}/v3/emailCampaigns', '', '', |
           '{{"name":"{{text}","subject":"{{subject}","sender":{{"email":"{{from}","name":"{{fromname}"},' & |
           '"type":"classic","htmlContent":"{{html}","recipients":{{"listIds":[{{id}]}}')
  SELF.Row(ETPrv:Brevo, ETOp:CampaignSend, 0, 'POST', '{{scheme}{{host}/v3/emailCampaigns/{{id}/sendNow')
  SELF.Row(ETPrv:Brevo, ETOp:Templates, 0, 'GET', |
           '{{scheme}{{host}/v3/smtp/templates?limit={{limit}&offset={{offset}', 'templates', |
           'Id=id;Name=name;Subject=subject;Active=isActive;When=@createdAt')
  SELF.Row(ETPrv:Brevo, ETOp:Senders, 0, 'GET', '{{scheme}{{host}/v3/senders', 'senders', |
           'Id=id;Address=email;Name=name;Verified=active')
  SELF.Row(ETPrv:Brevo, ETOp:Domains, 0, 'GET', '{{scheme}{{host}/v3/senders/domains', 'domains', |
           'Name=domain;Verified=authenticated')
  SELF.Row(ETPrv:Brevo, ETOp:Webhooks, 0, 'GET', '{{scheme}{{host}/v3/webhooks', 'webhooks', |
           'Id=id;Url=url;Events=events.0;Active=!1')
  SELF.Row(ETPrv:Brevo, ETOp:WebhookAdd, 0, 'POST', '{{scheme}{{host}/v3/webhooks', '', '', |
           '{{"url":"{{text}","events":["hardBounce","spam","unsubscribed","delivered"],' & |
           '"type":"transactional"}')
  SELF.Row(ETPrv:Brevo, ETOp:WebhookDelete, 0, 'DELETE', '{{scheme}{{host}/v3/webhooks/{{id}')

!===== Mailgun ===============================================================
!  Mailgun is per-DOMAIN, and pages with a cursor rather than an offset - the
!  reply carries the address of the next page in paging.next.
  SELF.Row(ETPrv:Mailgun, ETOp:Suppressions, ETSup:Bounce, 'GET', |
           '{{scheme}{{host}/v3/{{domain}/bounces?limit={{limit}', 'items', |
           'Address=address;Reason=error;Code=code;When=%created_at', '', 'paging.next')
  SELF.Row(ETPrv:Mailgun, ETOp:Suppressions, ETSup:Spam, 'GET', |
           '{{scheme}{{host}/v3/{{domain}/complaints?limit={{limit}', 'items', |
           'Address=address;Reason=!spam complaint;When=%created_at', '', 'paging.next')
  SELF.Row(ETPrv:Mailgun, ETOp:Suppressions, ETSup:Unsub, 'GET', |
           '{{scheme}{{host}/v3/{{domain}/unsubscribes?limit={{limit}', 'items', |
           'Address=address;Reason=!unsubscribed;When=%created_at', '', 'paging.next')
  SELF.Row(ETPrv:Mailgun, ETOp:SuppDelete, ETSup:Bounce, 'DELETE', '{{scheme}{{host}/v3/{{domain}/bounces/{{email}')
  SELF.Row(ETPrv:Mailgun, ETOp:SuppDelete, ETSup:Spam,   'DELETE', '{{scheme}{{host}/v3/{{domain}/complaints/{{email}')
  SELF.Row(ETPrv:Mailgun, ETOp:SuppDelete, ETSup:Unsub,  'DELETE', '{{scheme}{{host}/v3/{{domain}/unsubscribes/{{email}')
  SELF.Row(ETPrv:Mailgun, ETOp:SuppDeleteAll, ETSup:Bounce, 'DELETE', '{{scheme}{{host}/v3/{{domain}/bounces')
  SELF.Row(ETPrv:Mailgun, ETOp:SuppDeleteAll, ETSup:Spam,   'DELETE', '{{scheme}{{host}/v3/{{domain}/complaints')
  SELF.Row(ETPrv:Mailgun, ETOp:SuppDeleteAll, ETSup:Unsub,  'DELETE', '{{scheme}{{host}/v3/{{domain}/unsubscribes')
  SELF.Row(ETPrv:Mailgun, ETOp:SuppAdd, ETSup:Bounce, 'POST', '{{scheme}{{host}/v3/{{domain}/bounces', '', '', |
           'form:address={{email}&error={{text}')
  SELF.Row(ETPrv:Mailgun, ETOp:SuppAdd, ETSup:Unsub, 'POST', '{{scheme}{{host}/v3/{{domain}/unsubscribes', '', '', |
           'form:address={{email}&tag=*')
  SELF.Row(ETPrv:Mailgun, ETOp:Stats, 0, 'GET', |
           '{{scheme}{{host}/v3/{{domain}/stats/total?event=accepted&event=delivered&event=failed' & |
           '&event=opened&event=clicked&event=unsubscribed&event=complained' & |
           '&start={{rfcfrom}&end={{rfcto}&resolution=day', 'stats', |
           'When=%time;Requests=accepted.total;Delivered=delivered.total;Opens=opened.total;' & |
           'Clicks=clicked.total;HardBounces=failed.permanent.total;' & |
           'SoftBounces=failed.temporary.total;SpamReports=complained.total;' & |
           'Unsubscribed=unsubscribed.total')
  SELF.Row(ETPrv:Mailgun, ETOp:Events, 0, 'GET', |
           '{{scheme}{{host}/v3/{{domain}/events?limit={{limit}', 'items', |
           'When=#timestamp;Address=recipient;EventName=event;Reason=reason;' & |
           'Subject=message.headers.subject;MessageId=message.headers.message-id', '', 'paging.next')
  SELF.Row(ETPrv:Mailgun, ETOp:Lists, 0, 'GET', '{{scheme}{{host}/v3/lists/pages?limit={{limit}', 'items', |
           'Id=address;Name=name;Members=members_count')
  SELF.Row(ETPrv:Mailgun, ETOp:ListMembers, 0, 'GET', |
           '{{scheme}{{host}/v3/lists/{{id}/members?limit={{limit}', 'items', |
           'Address=address;Name=name')
  SELF.Row(ETPrv:Mailgun, ETOp:ContactAdd, 1, 'POST', '{{scheme}{{host}/v3/lists/{{id}/members', '', '', |
           'form:address={{email}&name={{text}&upsert=yes')
  SELF.Row(ETPrv:Mailgun, ETOp:ContactDelete, 0, 'DELETE', '{{scheme}{{host}/v3/lists/{{id}/members/{{email}')
  SELF.Row(ETPrv:Mailgun, ETOp:ListAdd, 0, 'POST', '{{scheme}{{host}/v3/lists', '', '', |
           'form:address={{text}&name={{text}')
  SELF.Row(ETPrv:Mailgun, ETOp:Templates, 0, 'GET', |
           '{{scheme}{{host}/v3/{{domain}/templates?limit={{limit}', 'items', |
           'Id=name;Name=name;When=%createdAt')
  SELF.Row(ETPrv:Mailgun, ETOp:Domains, 0, 'GET', '{{scheme}{{host}/v4/domains?limit={{limit}', 'items', |
           'Id=id;Name=name;Status=state')

!===== Postmark ==============================================================
!  Two suppression views: the stream dump (everything, with the reason) and
!  /bounces (bounces only, with far more detail).  Both are registered, so
!  "show me everything" and "show me the bounces" each use the better one.
  SELF.Row(ETPrv:Postmark, ETOp:Account, 0, 'GET', '{{scheme}{{host}/server', '*', 'Name=Name')
  SELF.Row(ETPrv:Postmark, ETOp:Suppressions, ETSup:All, 'GET', |
           '{{scheme}{{host}/message-streams/outbound/suppressions/dump', 'Suppressions', |
           'Address=EmailAddress;KindText=SuppressionReason;Reason=SuppressionReason;' & |
           'Id=Origin;When=@CreatedAt')
  SELF.Row(ETPrv:Postmark, ETOp:Suppressions, ETSup:Bounce, 'GET', |
           '{{scheme}{{host}/bounces?count={{limit}&offset={{offset}', 'Bounces', |
           'Address=Email;Reason=Description;Code=TypeCode;Id=ID;When=@BouncedAt;Sender=From')
  SELF.Row(ETPrv:Postmark, ETOp:SuppDelete, ETSup:All, 'POST', |
           '{{scheme}{{host}/message-streams/outbound/suppressions/delete', '', '', |
           '{{"Suppressions":[{{"EmailAddress":"{{email}"}]}')
  SELF.Row(ETPrv:Postmark, ETOp:SuppDelete, ETSup:Bounce, 'PUT', '{{scheme}{{host}/bounces/{{id}/activate')
  SELF.Row(ETPrv:Postmark, ETOp:SuppAdd, ETSup:All, 'POST', |
           '{{scheme}{{host}/message-streams/outbound/suppressions', '', '', |
           '{{"Suppressions":[{{"EmailAddress":"{{email}"}]}')
  SELF.Row(ETPrv:Postmark, ETOp:Stats, 0, 'GET', |
           '{{scheme}{{host}/stats/outbound?fromdate={{ymdfrom}&todate={{ymdto}', '*', |
           'Requests=Sent;Opens=Opens;UniqueOpens=UniqueOpens;Clicks=TotalClicks;' & |
           'HardBounces=Bounced;SpamReports=SpamComplaints')
  SELF.Row(ETPrv:Postmark, ETOp:Events, 0, 'GET', |
           '{{scheme}{{host}/messages/outbound?count={{limit}&offset={{offset}', 'Messages', |
           'When=@ReceivedAt;Address=Recipients.0;EventName=Status;Subject=Subject;MessageId=MessageID')
  SELF.Row(ETPrv:Postmark, ETOp:Templates, 0, 'GET', |
           '{{scheme}{{host}/templates?count={{limit}&offset={{offset}', 'Templates', |
           'Id=TemplateId;Name=Name;Subject=Alias;Active=Active')
  SELF.Row(ETPrv:Postmark, ETOp:Senders, 0, 'GET', |
           '{{scheme}{{host}/senders?count={{limit}&offset={{offset}', 'SenderSignatures', |
           'Id=ID;Address=EmailAddress;Name=Name;Verified=Confirmed')
  SELF.Row(ETPrv:Postmark, ETOp:Domains, 0, 'GET', |
           '{{scheme}{{host}/domains?count={{limit}&offset={{offset}', 'Domains', |
           'Id=ID;Name=Name;Spf=SPFVerified;Dkim=DKIMVerified')
  SELF.Row(ETPrv:Postmark, ETOp:Webhooks, 0, 'GET', '{{scheme}{{host}/webhooks', 'Webhooks', |
           'Id=ID;Url=Url;Active=!1')
  SELF.Row(ETPrv:Postmark, ETOp:WebhookAdd, 0, 'POST', '{{scheme}{{host}/webhooks', '', '', |
           '{{"Url":"{{text}","MessageStream":"outbound"}')
  SELF.Row(ETPrv:Postmark, ETOp:WebhookDelete, 0, 'DELETE', '{{scheme}{{host}/webhooks/{{id}')

!===== Mailjet ===============================================================
!  Everything Mailjet answers is wrapped in "Data", and every column starts
!  with a capital.  One provider, one shape - the easiest rows in the table.
  SELF.Row(ETPrv:Mailjet, ETOp:Account, 0, 'GET', '{{scheme}{{host}/v3/REST/user', '*', |
           'Name=Data.0.Username;Address=Data.0.Email;Company=Data.0.LastName')
  SELF.Row(ETPrv:Mailjet, ETOp:Suppressions, ETSup:Bounce, 'GET', |
           '{{scheme}{{host}/v3/REST/bouncestatistics?Limit={{limit}&Offset={{offset}', 'Data', |
           'Address=ContactAlt;Reason=ErrorRelatedTo;Code=ErrorCode;When=@BouncedAt')
  SELF.Row(ETPrv:Mailjet, ETOp:Suppressions, ETSup:Unsub, 'GET', |
           '{{scheme}{{host}/v3/REST/contact?IsExcludedFromCampaigns=true&Limit={{limit}&Offset={{offset}', |
           'Data', 'Id=ID;Address=Email;Reason=!excluded from campaigns;When=@CreatedAt')
  SELF.Row(ETPrv:Mailjet, ETOp:SuppDelete, ETSup:Unsub, 'PUT', '{{scheme}{{host}/v3/REST/contact/{{email}', |
           '', '', '{{"IsExcludedFromCampaigns":false}')
  SELF.Row(ETPrv:Mailjet, ETOp:SuppAdd, ETSup:All, 'PUT', '{{scheme}{{host}/v3/REST/contact/{{email}', |
           '', '', '{{"IsExcludedFromCampaigns":true}')
  SELF.Row(ETPrv:Mailjet, ETOp:Stats, 0, 'GET', |
           '{{scheme}{{host}/v3/REST/statcounters?CounterSource=APIKey&CounterTiming=Message' & |
           '&CounterResolution=Day&FromTS={{ymdfrom}&ToTS={{ymdto}&Limit={{limit}', 'Data', |
           'When=@Timeslice;Requests=MessageSentCount;Delivered=MessageDeliveredCount;' & |
           'Opens=MessageOpenedCount;Clicks=MessageClickedCount;' & |
           'HardBounces=MessageHardBouncedCount;SoftBounces=MessageSoftBouncedCount;' & |
           'SpamReports=MessageSpamCount;Unsubscribed=MessageUnsubscribedCount;' & |
           'Blocks=MessageBlockedCount')
  SELF.Row(ETPrv:Mailjet, ETOp:Events, 0, 'GET', |
           '{{scheme}{{host}/v3/REST/message?Limit={{limit}&Offset={{offset}', 'Data', |
           'MessageId=ID;When=@ArrivedAt;EventName=Status;Address=ContactAlt')
  SELF.Row(ETPrv:Mailjet, ETOp:Contacts, 0, 'GET', |
           '{{scheme}{{host}/v3/REST/contact?Limit={{limit}&Offset={{offset}', 'Data', |
           'Id=ID;Address=Email;Name=Name;When=@CreatedAt;Unsubscribed=IsExcludedFromCampaigns')
  SELF.Row(ETPrv:Mailjet, ETOp:Lists, 0, 'GET', |
           '{{scheme}{{host}/v3/REST/contactslist?Limit={{limit}&Offset={{offset}', 'Data', |
           'Id=ID;Name=Name;Members=SubscriberCount')
  SELF.Row(ETPrv:Mailjet, ETOp:ContactAdd, 0, 'POST', '{{scheme}{{host}/v3/REST/contact', '', '', |
           '{{"Email":"{{email}","Name":"{{text}"}')
  SELF.Row(ETPrv:Mailjet, ETOp:ListAdd, 0, 'POST', '{{scheme}{{host}/v3/REST/contactslist', '', '', |
           '{{"Name":"{{text}"}')
  SELF.Row(ETPrv:Mailjet, ETOp:Campaigns, 0, 'GET', |
           '{{scheme}{{host}/v3/REST/campaigndraft?Limit={{limit}&Offset={{offset}', 'Data', |
           'Id=ID;Name=Title;Subject=Subject;Status=Status;When=@CreatedAt')
  SELF.Row(ETPrv:Mailjet, ETOp:CampaignSend, 0, 'POST', '{{scheme}{{host}/v3/REST/campaigndraft/{{id}/send')
  SELF.Row(ETPrv:Mailjet, ETOp:Templates, 0, 'GET', |
           '{{scheme}{{host}/v3/REST/template?Limit={{limit}&Offset={{offset}', 'Data', |
           'Id=ID;Name=Name')
  SELF.Row(ETPrv:Mailjet, ETOp:Senders, 0, 'GET', '{{scheme}{{host}/v3/REST/sender?Limit={{limit}', 'Data', |
           'Id=ID;Address=Email;Name=Name;Status=Status')
  SELF.Row(ETPrv:Mailjet, ETOp:Domains, 0, 'GET', '{{scheme}{{host}/v3/REST/dns?Limit={{limit}', 'Data', |
           'Id=ID;Name=Domain;Spf=SPFStatus;Dkim=DKIMStatus')
  SELF.Row(ETPrv:Mailjet, ETOp:Webhooks, 0, 'GET', '{{scheme}{{host}/v3/REST/eventcallbackurl', 'Data', |
           'Id=ID;Url=Url;Events=EventType;Active=Status')

!===== Resend ================================================================
!  Resend has no suppression API at all: bounces are reported per message and
!  through webhooks.  Supports(ETOp:Suppressions) is therefore 0, and the
!  Manage window greys the tab out rather than showing an empty list.
  SELF.Row(ETPrv:Resend, ETOp:Lists, 0, 'GET', '{{scheme}{{host}/audiences', 'data', |
           'Id=id;Name=name')
  SELF.Row(ETPrv:Resend, ETOp:ListAdd, 0, 'POST', '{{scheme}{{host}/audiences', '', '', '{{"name":"{{text}"}')
  SELF.Row(ETPrv:Resend, ETOp:ListMembers, 0, 'GET', '{{scheme}{{host}/audiences/{{id}/contacts', 'data', |
           'Id=id;Address=email;Name=first_name;Unsubscribed=unsubscribed;When=@created_at')
  SELF.Row(ETPrv:Resend, ETOp:ContactAdd, 1, 'POST', '{{scheme}{{host}/audiences/{{id}/contacts', '', '', |
           '{{"email":"{{email}","first_name":"{{text}"}')
  SELF.Row(ETPrv:Resend, ETOp:ContactDelete, 0, 'DELETE', '{{scheme}{{host}/audiences/{{id}/contacts/{{email}')
  SELF.Row(ETPrv:Resend, ETOp:Campaigns, 0, 'GET', '{{scheme}{{host}/broadcasts', 'data', |
           'Id=id;Name=name;Status=status;When=@created_at')
  SELF.Row(ETPrv:Resend, ETOp:CampaignAdd, 0, 'POST', '{{scheme}{{host}/broadcasts', '', '', |
           '{{"audience_id":"{{id}","from":"{{from}","subject":"{{subject}","html":"{{html}","name":"{{text}"}')
  SELF.Row(ETPrv:Resend, ETOp:CampaignSend, 0, 'POST', '{{scheme}{{host}/broadcasts/{{id}/send')
  SELF.Row(ETPrv:Resend, ETOp:Domains, 0, 'GET', '{{scheme}{{host}/domains', 'data', |
           'Id=id;Name=name;Status=status')

!===== SparkPost =============================================================
  SELF.Row(ETPrv:SparkPost, ETOp:Account, 0, 'GET', '{{scheme}{{host}/api/v1/account', '*', |
           'Company=results.company_name;Status=results.status;Plan=results.subscription.plan_id')
  SELF.Row(ETPrv:SparkPost, ETOp:Suppressions, ETSup:All, 'GET', |
           '{{scheme}{{host}/api/v1/suppression-list?per_page={{limit}&page={{page}', 'results', |
           'Address=recipient;Reason=description;KindText=type;Id=source;When=@created')
  SELF.Row(ETPrv:SparkPost, ETOp:SuppDelete, ETSup:All, 'DELETE', |
           '{{scheme}{{host}/api/v1/suppression-list/{{email}')
  SELF.Row(ETPrv:SparkPost, ETOp:SuppAdd, ETSup:All, 'PUT', |
           '{{scheme}{{host}/api/v1/suppression-list/{{email}', '', '', |
           '{{"type":"non_transactional","description":"{{text}"}')
  SELF.Row(ETPrv:SparkPost, ETOp:Stats, 0, 'GET', |
           '{{scheme}{{host}/api/v1/metrics/deliverability/time-series?from={{isofrom}&to={{isoto}' & |
           '&precision=day&metrics=count_sent,count_accepted,count_bounce,count_spam_complaint,' & |
           'count_unique_confirmed_opened,count_clicked,count_unsubscribe', 'results', |
           'When=@ts;Requests=count_sent;Delivered=count_accepted;HardBounces=count_bounce;' & |
           'SpamReports=count_spam_complaint;UniqueOpens=count_unique_confirmed_opened;' & |
           'Clicks=count_clicked;Unsubscribed=count_unsubscribe')
  SELF.Row(ETPrv:SparkPost, ETOp:Events, 0, 'GET', |
           '{{scheme}{{host}/api/v1/events/message?from={{isofrom}&to={{isoto}&per_page={{limit}', 'results', |
           'When=@timestamp;Address=rcpt_to;EventName=type;Reason=reason;Subject=subject;' & |
           'MessageId=message_id')
  SELF.Row(ETPrv:SparkPost, ETOp:Lists, 0, 'GET', '{{scheme}{{host}/api/v1/recipient-lists', 'results', |
           'Id=id;Name=name;Members=total_accepted_recipients')
  SELF.Row(ETPrv:SparkPost, ETOp:Templates, 0, 'GET', '{{scheme}{{host}/api/v1/templates', 'results', |
           'Id=id;Name=name;When=@last_update_time')
  SELF.Row(ETPrv:SparkPost, ETOp:Domains, 0, 'GET', '{{scheme}{{host}/api/v1/sending-domains', 'results', |
           'Name=domain;Verified=status.ownership_verified;Dkim=status.dkim_status;Spf=status.spf_status')
  SELF.Row(ETPrv:SparkPost, ETOp:Webhooks, 0, 'GET', '{{scheme}{{host}/api/v1/webhooks', 'results', |
           'Id=id;Url=target;Events=events.0;Active=!1')
  SELF.Row(ETPrv:SparkPost, ETOp:WebhookAdd, 0, 'POST', '{{scheme}{{host}/api/v1/webhooks', '', '', |
           '{{"name":"emailTo","target":"{{text}","events":["delivery","bounce","spam_complaint"]}')
  SELF.Row(ETPrv:SparkPost, ETOp:WebhookDelete, 0, 'DELETE', '{{scheme}{{host}/api/v1/webhooks/{{id}')

!===== MailerSend ============================================================
!  MailerSend keeps four separate lists and deletes by ID, not by address -
!  so DeleteSuppression looks the address up in whatever GetSuppressions
!  loaded, and sends the id it found.
  SELF.Row(ETPrv:MailerSend, ETOp:Account, 0, 'GET', '{{scheme}{{host}/v1/api-quota', '*', |
           'Credits=remaining;Plan=!api quota')
  SELF.Row(ETPrv:MailerSend, ETOp:Suppressions, ETSup:Bounce, 'GET', |
           '{{scheme}{{host}/v1/suppressions/hard-bounces?limit={{limit}&page={{page}', 'data', |
           'Id=id;Address=recipient.email|email;Reason=reason;When=@created_at')
  SELF.Row(ETPrv:MailerSend, ETOp:Suppressions, ETSup:Spam, 'GET', |
           '{{scheme}{{host}/v1/suppressions/spam-complaints?limit={{limit}&page={{page}', 'data', |
           'Id=id;Address=recipient.email|email;Reason=!spam complaint;When=@created_at')
  SELF.Row(ETPrv:MailerSend, ETOp:Suppressions, ETSup:Unsub, 'GET', |
           '{{scheme}{{host}/v1/suppressions/unsubscribes?limit={{limit}&page={{page}', 'data', |
           'Id=id;Address=recipient.email|email;Reason=reason;When=@created_at')
  SELF.Row(ETPrv:MailerSend, ETOp:Suppressions, ETSup:Block, 'GET', |
           '{{scheme}{{host}/v1/suppressions/blocklist?limit={{limit}&page={{page}', 'data', |
           'Id=id;Address=recipient.email|email;Reason=reason;When=@created_at')
  SELF.Row(ETPrv:MailerSend, ETOp:SuppDelete, ETSup:Bounce, 'DELETE', |
           '{{scheme}{{host}/v1/suppressions/hard-bounces', '', '', '{{"ids":["{{id}"]}')
  SELF.Row(ETPrv:MailerSend, ETOp:SuppDelete, ETSup:Spam, 'DELETE', |
           '{{scheme}{{host}/v1/suppressions/spam-complaints', '', '', '{{"ids":["{{id}"]}')
  SELF.Row(ETPrv:MailerSend, ETOp:SuppDelete, ETSup:Unsub, 'DELETE', |
           '{{scheme}{{host}/v1/suppressions/unsubscribes', '', '', '{{"ids":["{{id}"]}')
  SELF.Row(ETPrv:MailerSend, ETOp:SuppDelete, ETSup:Block, 'DELETE', |
           '{{scheme}{{host}/v1/suppressions/blocklist', '', '', '{{"ids":["{{id}"]}')
  SELF.Row(ETPrv:MailerSend, ETOp:SuppDeleteAll, ETSup:Bounce, 'DELETE', |
           '{{scheme}{{host}/v1/suppressions/hard-bounces', '', '', '{{"all":true}')
  SELF.Row(ETPrv:MailerSend, ETOp:SuppDeleteAll, ETSup:Spam, 'DELETE', |
           '{{scheme}{{host}/v1/suppressions/spam-complaints', '', '', '{{"all":true}')
  SELF.Row(ETPrv:MailerSend, ETOp:SuppDeleteAll, ETSup:Unsub, 'DELETE', |
           '{{scheme}{{host}/v1/suppressions/unsubscribes', '', '', '{{"all":true}')
  SELF.Row(ETPrv:MailerSend, ETOp:SuppDeleteAll, ETSup:Block, 'DELETE', |
           '{{scheme}{{host}/v1/suppressions/blocklist', '', '', '{{"all":true}')
  SELF.Row(ETPrv:MailerSend, ETOp:SuppAdd, ETSup:Block, 'POST', |
           '{{scheme}{{host}/v1/suppressions/blocklist', '', '', |
           '{{"domain_id":"{{domain}","recipients":["{{email}"]}')
  SELF.Row(ETPrv:MailerSend, ETOp:Stats, 0, 'GET', |
           '{{scheme}{{host}/v1/analytics/date?date_from={{epochfrom}&date_to={{epochto}' & |
           '&group_by=days&event[]=sent&event[]=delivered&event[]=opened&event[]=clicked' & |
           '&event[]=hard_bounced&event[]=soft_bounced&event[]=spam_complaints' & |
           '&event[]=unsubscribed', 'data.stats', |
           'When=#date;Requests=sent;Delivered=delivered;Opens=opened;Clicks=clicked;' & |
           'HardBounces=hard_bounced;SoftBounces=soft_bounced;SpamReports=spam_complaints;' & |
           'Unsubscribed=unsubscribed')
  SELF.Row(ETPrv:MailerSend, ETOp:Events, 0, 'GET', |
           '{{scheme}{{host}/v1/activity/{{domain}?limit={{limit}&page={{page}', 'data', |
           'When=@created_at;EventName=type;Address=email.recipient.email;Subject=email.subject')
  SELF.Row(ETPrv:MailerSend, ETOp:Contacts, 0, 'GET', |
           '{{scheme}{{host}/v1/recipients?limit={{limit}&page={{page}', 'data', |
           'Id=id;Address=email;When=@created_at')
  SELF.Row(ETPrv:MailerSend, ETOp:Templates, 0, 'GET', |
           '{{scheme}{{host}/v1/templates?limit={{limit}&page={{page}', 'data', |
           'Id=id;Name=name;When=@created_at')
  SELF.Row(ETPrv:MailerSend, ETOp:Domains, 0, 'GET', |
           '{{scheme}{{host}/v1/domains?limit={{limit}&page={{page}', 'data', |
           'Id=id;Name=name;Verified=is_verified;Dkim=dkim;Spf=spf')
  SELF.Row(ETPrv:MailerSend, ETOp:Webhooks, 0, 'GET', |
           '{{scheme}{{host}/v1/webhooks?domain_id={{domain}', 'data', |
           'Id=id;Url=url;Events=events.0;Active=enabled')
  SELF.Row(ETPrv:MailerSend, ETOp:WebhookDelete, 0, 'DELETE', '{{scheme}{{host}/v1/webhooks/{{id}')
!===== Amazon SES ============================================================
!  The only provider that signs its requests rather than taking a key in a
!  header - see SignedHeaders. The access key id goes in ApiKey2 and the
!  secret in ApiKey, which leaves UserName and Password free for the quite
!  separate SMTP credentials SES also issues.
  SELF.Row(ETPrv:AmazonSes, ETOp:Account, 0, 'GET', '{{scheme}{{host}/v2/email/account', '*', |
           'Status=EnforcementStatus;Credits=SendQuota.Max24HourSend')
  SELF.Row(ETPrv:AmazonSes, ETOp:Suppressions, ETSup:All, 'GET', |
           '{{scheme}{{host}/v2/email/suppression/addresses?PageSize={{limit}', |
           'SuppressedDestinationSummaries', |
           'Address=EmailAddress;KindText=Reason;Reason=Reason;When=@LastUpdateTime', |
           '', 'NextToken')
  SELF.Row(ETPrv:AmazonSes, ETOp:SuppDelete, ETSup:All, 'DELETE', |
           '{{scheme}{{host}/v2/email/suppression/addresses/{{email}')
  SELF.Row(ETPrv:AmazonSes, ETOp:SuppAdd, ETSup:Bounce, 'PUT', |
           '{{scheme}{{host}/v2/email/suppression/addresses/{{email}', '', '', |
           '{{"Reason":"BOUNCE"}')
  SELF.Row(ETPrv:AmazonSes, ETOp:SuppAdd, ETSup:Spam, 'PUT', |
           '{{scheme}{{host}/v2/email/suppression/addresses/{{email}', '', '', |
           '{{"Reason":"COMPLAINT"}')
  SELF.Row(ETPrv:AmazonSes, ETOp:Lists, 0, 'GET', |
           '{{scheme}{{host}/v2/email/contact-lists', 'ContactLists', |
           'Id=ContactListName;Name=ContactListName')
  SELF.Row(ETPrv:AmazonSes, ETOp:ListMembers, 0, 'GET', |
           '{{scheme}{{host}/v2/email/contact-lists/{{id}/contacts?PageSize={{limit}', 'Contacts', |
           'Address=EmailAddress;Unsubscribed=UnsubscribeAll', '', 'NextToken')
  SELF.Row(ETPrv:AmazonSes, ETOp:ContactAdd, 1, 'POST', |
           '{{scheme}{{host}/v2/email/contact-lists/{{id}/contacts', '', '', |
           '{{"EmailAddress":"{{email}"}')
  SELF.Row(ETPrv:AmazonSes, ETOp:ContactDelete, 0, 'DELETE', |
           '{{scheme}{{host}/v2/email/contact-lists/{{id}/contacts/{{email}')
  SELF.Row(ETPrv:AmazonSes, ETOp:Senders, 0, 'GET', |
           '{{scheme}{{host}/v2/email/identities?PageSize={{limit}', 'EmailIdentities', |
           'Id=IdentityName;Address=IdentityName;Verified=SendingEnabled;' & |
           'Status=IdentityType', '', 'NextToken')
  RETURN

!  One row of the matrix.  Nothing clever - but keeping it a method rather
!  than repeated queue assignments is what makes BuildMap readable, and what
!  lets a derived class add a provider with a handful of calls.
EmailApiClass.Row PROCEDURE(BYTE pProvider,BYTE pOp,BYTE pKind,STRING pVerb,STRING pUrl,|
                            <STRING pItemPath>,<STRING pMap>,<STRING pBody>,<STRING pNext>)
  CODE
  CLEAR(SELF.MapQ)
  SELF.MapQ.Provider = pProvider
  SELF.MapQ.Op       = pOp
  SELF.MapQ.Kind     = pKind
  SELF.MapQ.Verb     = CLIP(pVerb)
  SELF.MapQ.Url      = SUB(CLIP(pUrl), 1, 256)
  IF NOT OMITTED(pItemPath) THEN SELF.MapQ.ItemPath = SUB(CLIP(pItemPath), 1, 64).
  IF NOT OMITTED(pMap)      THEN SELF.MapQ.Map      = SUB(CLIP(pMap), 1, 768).
  IF NOT OMITTED(pBody)     THEN SELF.MapQ.Body     = SUB(CLIP(pBody), 1, 768).
  IF NOT OMITTED(pNext)     THEN SELF.MapQ.NextPath = SUB(CLIP(pNext), 1, 64).
  ADD(SELF.MapQ)
  RETURN

!  Look a row up and leave it in MapQ for the caller to read.
EmailApiClass.FindRow PROCEDURE(BYTE pOp,BYTE pKind)
i LONG
  CODE
  IF SELF.Mailer &= NULL THEN RETURN SELF.SetErr(ETApi:NoObject).
  LOOP i = 1 TO RECORDS(SELF.MapQ)
    GET(SELF.MapQ, i)
    IF SELF.MapQ.Provider = SELF.Mailer.Acc.Provider AND SELF.MapQ.Op = pOp |
       AND SELF.MapQ.Kind = pKind
      RETURN 1
    END
  END
  !  No row for that exact kind, so widen the search - in whichever direction
  !  makes sense.
  !
  !  Asking for a KIND: a provider that keeps ONE list registers it under
  !  ETSup:All, and that row answers for every kind (the engine works out what
  !  each row really is afterwards).
  !
  !  Asking for ANY kind: a provider that keeps a SEPARATE list per kind has no
  !  ETSup:All row at all, and the honest answer to "can you do suppressions"
  !  is still yes.  Without this, Supports(ETOp:Suppressions) said no to
  !  SendGrid, whose five lists are the reason the class exists.
  LOOP i = 1 TO RECORDS(SELF.MapQ)
    GET(SELF.MapQ, i)
    IF SELF.MapQ.Provider <> SELF.Mailer.Acc.Provider OR SELF.MapQ.Op <> pOp THEN CYCLE.
    IF pKind = ETSup:All THEN RETURN 1.
    IF SELF.MapQ.Kind = ETSup:All THEN RETURN 1.
  END
  CLEAR(SELF.MapQ)
  RETURN 0

!  Is there a row for exactly this kind - not a widened match?  The change
!  methods need to know the difference: "any list" is a fine thing to ask
!  Supports(), and a hopeless thing to put in a URL.
EmailApiClass.ExactRow PROCEDURE(BYTE pOp,BYTE pKind)
  CODE
  IF NOT SELF.FindRow(pOp, pKind) THEN RETURN 0.
  RETURN CHOOSE(SELF.MapQ.Kind = pKind, 1, 0)

EmailApiClass.Supports PROCEDURE(BYTE pOp,BYTE pKind)
  CODE
  IF pOp = ETOp:SuppDeleteAll
    !  Every provider can delete them all, even the ones with no endpoint for
    !  it: DeleteAllSuppressions falls back to deleting them one at a time.
    RETURN SELF.Supports(ETOp:SuppDelete, pKind)
  END
  RETURN SELF.FindRow(pOp, pKind)

! ============================================================================
!  Names
! ============================================================================
EmailApiClass.OpName PROCEDURE(BYTE pOp)
  CODE
  CASE pOp
  OF ETOp:Account       ; RETURN SELF.Txt(ETATxt:Account)
  OF ETOp:Suppressions  ; RETURN SELF.Txt(ETATxt:Blocked)
  OF ETOp:SuppDelete    ; RETURN SELF.Txt(ETATxt:Unblock)
  OF ETOp:SuppDeleteAll ; RETURN SELF.Txt(ETATxt:UnblockAll)
  OF ETOp:SuppAdd       ; RETURN SELF.Txt(ETATxt:Block)
  OF ETOp:Stats         ; RETURN SELF.Txt(ETATxt:Statistics)
  OF ETOp:Events        ; RETURN SELF.Txt(ETATxt:Activity)
  OF ETOp:Contacts      ; RETURN SELF.Txt(ETATxt:Contacts)
  OF ETOp:ListMembers   ; RETURN SELF.Txt(ETATxt:Contacts)
  OF ETOp:Lists         ; RETURN SELF.Txt(ETATxt:Lists)
  OF ETOp:Campaigns     ; RETURN SELF.Txt(ETATxt:Campaigns)
  OF ETOp:Templates     ; RETURN SELF.Txt(ETATxt:Templates)
  OF ETOp:Senders       ; RETURN SELF.Txt(ETATxt:Senders)
  OF ETOp:Domains       ; RETURN SELF.Txt(ETATxt:Domains)
  OF ETOp:Webhooks      ; RETURN SELF.Txt(ETATxt:Webhooks)
  END
  RETURN ''

EmailApiClass.SuppKindName PROCEDURE(BYTE pKind)
  CODE
  IF SELF.Language = ETLng:Spanish
    CASE pKind
    OF ETSup:Bounce  ; RETURN 'Rebote'
    OF ETSup:Block   ; RETURN 'Bloqueado'
    OF ETSup:Spam    ; RETURN 'Queja de spam'
    OF ETSup:Unsub   ; RETURN 'Baja'
    OF ETSup:Invalid ; RETURN 'No v<225>lida'
    END
    RETURN 'Todos'
  END
  CASE pKind
  OF ETSup:Bounce  ; RETURN 'Bounce'
  OF ETSup:Block   ; RETURN 'Blocked'
  OF ETSup:Spam    ; RETURN 'Spam report'
  OF ETSup:Unsub   ; RETURN 'Unsubscribed'
  OF ETSup:Invalid ; RETURN 'Invalid'
  END
  RETURN 'All'

!  Read a provider's own word for a block and say which of our five kinds it
!  is.  Every provider has its own vocabulary - "hardBounce", "HardBounce",
!  "spam_complaint", "SpamNotification", "policy_suppression" - and the whole
!  point of this class is that the caller never has to learn any of them.
EmailApiClass.SuppKindOf PROCEDURE(STRING pText)
s CSTRING(257)
  CODE
  s = LOWER(SUB(CLIP(pText), 1, 256))
  IF NOT CLIP(s) THEN RETURN 0.
  IF INSTRING('unsub', s, 1, 1)          THEN RETURN ETSup:Unsub.
  IF INSTRING('spam', s, 1, 1)           THEN RETURN ETSup:Spam.
  IF INSTRING('complain', s, 1, 1)       THEN RETURN ETSup:Spam.
  IF INSTRING('junk', s, 1, 1)           THEN RETURN ETSup:Spam.
  IF INSTRING('invalid', s, 1, 1)        THEN RETURN ETSup:Invalid.
  IF INSTRING('does not exist', s, 1, 1) THEN RETURN ETSup:Invalid.
  IF INSTRING('unknown', s, 1, 1)        THEN RETURN ETSup:Invalid.
  IF INSTRING('bounce', s, 1, 1)         THEN RETURN ETSup:Bounce.
  IF INSTRING('block', s, 1, 1)          THEN RETURN ETSup:Block.
  IF INSTRING('policy', s, 1, 1)         THEN RETURN ETSup:Block.
  IF INSTRING('admin', s, 1, 1)          THEN RETURN ETSup:Block.
  IF INSTRING('manual', s, 1, 1)         THEN RETURN ETSup:Block.
  IF INSTRING('compliance', s, 1, 1)     THEN RETURN ETSup:Block.
  RETURN 0

! ============================================================================
!  Signing the request
! ============================================================================
!  The one place a credential turns into a header.  Postmark is the only
!  provider with two different keys: the server token opens the mail
!  endpoints, and senders and domains belong to the ACCOUNT, which wants the
!  account token instead - put that one in ApiKey2.
EmailApiClass.AuthHeaders PROCEDURE(BYTE pOp)
key CSTRING(513)
  CODE
  SELF.HdrBuf.ClearAll()
  IF SELF.Mailer &= NULL THEN RETURN ''.
  key = CLIP(SELF.Mailer.Acc.ApiKey)
  CASE SELF.Mailer.Acc.Provider
  OF ETPrv:SendGrid
    SELF.HdrBuf.Add('Authorization: Bearer ' & CLIP(key))
  OF ETPrv:Resend
    SELF.HdrBuf.Add('Authorization: Bearer ' & CLIP(key))
  OF ETPrv:MailerSend
    SELF.HdrBuf.Add('Authorization: Bearer ' & CLIP(key))
  OF ETPrv:Brevo
    SELF.HdrBuf.Add('api-key: ' & CLIP(key))
  OF ETPrv:Mailgun
    SELF.HdrBuf.Add('Authorization: Basic ' & SELF.Enc.Base64('api:' & CLIP(key)))
  OF ETPrv:Postmark
    CASE pOp
    OF ETOp:Senders OROF ETOp:Domains
      IF CLIP(SELF.Mailer.Acc.ApiKey2)
        SELF.HdrBuf.Add('X-Postmark-Account-Token: ' & CLIP(SELF.Mailer.Acc.ApiKey2))
      ELSE
        SELF.HdrBuf.Add('X-Postmark-Account-Token: ' & CLIP(key))
      END
    ELSE
      SELF.HdrBuf.Add('X-Postmark-Server-Token: ' & CLIP(key))
    END
  OF ETPrv:Mailjet
    !  Mailjet signs with a PAIR: the public key in User name, the private
    !  one in API key.
    SELF.HdrBuf.Add('Authorization: Basic ' & |
                    SELF.Enc.Base64(CLIP(SELF.Mailer.Acc.UserName) & ':' & CLIP(key)))
  OF ETPrv:SparkPost
    SELF.HdrBuf.Add('Authorization: ' & CLIP(key))
  ELSE
    SELF.HdrBuf.Add('Authorization: Bearer ' & CLIP(key))
  END
  SELF.HdrBuf.Add('<13,10>Accept: application/json')
  RETURN SELF.HdrBuf.Value()

!  Which of the two credentials is the AWS access key id. SES keeps SMTP
!  credentials in UserName and Password - they are NOT the AWS keys - so the
!  key id belongs in ApiKey2 and the secret in ApiKey, and one account can
!  then send over SMTP and still answer questions over the API. UserName is
!  accepted as a fallback for anyone who put it there.
EmailApiClass.AwsKeyId PROCEDURE()
  CODE
  IF CLIP(SELF.Mailer.Acc.ApiKey2) THEN RETURN CLIP(SELF.Mailer.Acc.ApiKey2).
  RETURN CLIP(SELF.Mailer.Acc.UserName)

!  The headers for THIS request. Everybody but Amazon just gets their key
!  back; Amazon gets a signature over the whole thing, from the net layer.
EmailApiClass.SignedHeaders PROCEDURE(BYTE pOp,STRING pVerb,STRING pUrl,STRING pBody)
  CODE
  IF SELF.Mailer &= NULL THEN RETURN ''.
  IF SELF.Mailer.Acc.Provider <> ETPrv:AmazonSes
    RETURN SELF.AuthHeaders(pOp)
  END
  SELF.HdrBuf.ClearAll()
  SELF.HdrBuf.Add(SELF.Net.SignAws(pVerb, pUrl, pBody, SELF.AwsKeyId(), |
                                   SELF.Mailer.Acc.ApiKey, |
                                   CHOOSE(CLIP(SELF.Mailer.Acc.ApiRegion) <> '', |
                                          CLIP(SELF.Mailer.Acc.ApiRegion), 'us-east-1'), |
                                   'ses'))
  SELF.HdrBuf.Add('<13,10>Accept: application/json')
  RETURN SELF.HdrBuf.Value()

! ============================================================================
!  Filling in a URL or a body
!
!  The MODE is read off the text itself, which keeps the signature to one
!  argument and keeps the matrix rows readable:
!      starts with http    a URL   - every value is percent-encoded
!      starts with form:   a form  - every value is percent-encoded, prefix cut
!      anything else       JSON    - every value is JSON-escaped
!  Only the VALUE goes through the escaper, never the surrounding text, so the
!  quotes and separators the row itself contains stay exactly as written.
! ============================================================================
EmailApiClass.Expand PROCEDURE(STRING pText)
n      LONG
i      LONG
j      LONG
mode   BYTE                                        ! 1 url  2 json  3 form
name   CSTRING(33)
struct BYTE
ok     BYTE
p      LONG
  CODE
  SELF.UrlBuf.ClearAll()
  n = LEN(CLIP(pText))
  IF n < 1 THEN RETURN ''.
  i = 1
  IF n > 5 AND LOWER(pText[1 : 5]) = 'form:'
    mode = 3
    i    = 6
  ELSIF n > 4 AND LOWER(pText[1 : 4]) = 'http'
    mode = 1
  ELSIF n > 8 AND pText[1 : 8] = '{{scheme}'
    mode = 1
  ELSE
    mode = 2
  END

  LOOP WHILE i <= n
    IF pText[i] <> '{{'
      SELF.UrlBuf.Add(pText[i])
      i += 1
      CYCLE
    END
    j = INSTRING('}', pText[1 : n], 1, i)
    ok = 0
    IF j AND j - i > 1 AND j - i <= 32
      !  A placeholder is {letters} and nothing else.  Without that test the
      !  opening brace of a JSON body swallows everything up to the first
      !  closing one - {"delete_all":true} would be read as a placeholder
      !  called "delete_all":true.
      ok = 1
      LOOP p = i + 1 TO j - 1
        IF pText[p] < 'a' OR pText[p] > 'z'
          IF pText[p] < 'A' OR pText[p] > 'Z'
            ok = 0
            BREAK
          END
        END
      END
    END
    IF NOT ok
      SELF.UrlBuf.Add(pText[i])                    ! a brace that is not a placeholder -
      i += 1                                       !   a JSON body is full of them
      CYCLE
    END
    name = LOWER(pText[i + 1 : j - 1])
    i    = j + 1
    !  Structural pieces are part of the address, not data: they are never
    !  escaped, because escaping them would break the URL.
    struct = 0
    CASE name
    OF 'scheme' ; struct = 1
    OF 'host'   ; struct = 1
    OF 'domain' ; struct = 1
    OF 'user'   ; struct = 1
    OF 'region' ; struct = 1
    OF 'limit'  ; struct = 1
    OF 'offset' ; struct = 1
    OF 'page'   ; struct = 1
    END
    DO ValueIntoTxt
    IF struct
      SELF.UrlBuf.Add(SELF.TxtBuf.Value())
    ELSIF mode = 2
      SELF.UrlBuf.Add(SELF.JsonStr(SELF.TxtBuf.Value()))
    ELSE
      SELF.UrlBuf.Add(SELF.UrlEncode(SELF.TxtBuf.Value()))
    END
  END
  RETURN SELF.UrlBuf.Value()

!  Put the raw value of the placeholder in `name` into TxtBuf.  It goes
!  through a buffer rather than a CSTRING because {html} can be a whole
!  newsletter, and a campaign body will not fit in a fixed string.
ValueIntoTxt ROUTINE
  DATA
host CSTRING(129)
pg   LONG
  CODE
  SELF.TxtBuf.ClearAll()
  IF SELF.Mailer &= NULL THEN EXIT.
  CASE name
  OF 'scheme'
    !  https everywhere, unless ApiBase names something else.  It can, and the
    !  reason is not laziness: a test double on the far side of a plain socket
    !  is how the whole of this engine gets exercised without a real account.
    SELF.TxtBuf.Add('https://')
    IF CLIP(SELF.Mailer.Acc.ApiBase)
      j = INSTRING('://', CLIP(SELF.Mailer.Acc.ApiBase), 1, 1)
      IF j
        SELF.TxtBuf.ClearAll()
        SELF.TxtBuf.Add(SELF.Mailer.Acc.ApiBase[1 : j + 2])
      END
    END
  OF 'host'
    CASE SELF.Mailer.Acc.Provider
    OF ETPrv:SendGrid   ; host = 'api.sendgrid.com'
    OF ETPrv:Brevo      ; host = 'api.brevo.com'
    OF ETPrv:Mailgun    ; host = CHOOSE(LOWER(CLIP(SELF.Mailer.Acc.ApiRegion)) = 'eu', |
                                        'api.eu.mailgun.net', 'api.mailgun.net')
    OF ETPrv:Postmark   ; host = 'api.postmarkapp.com'
    OF ETPrv:Mailjet    ; host = 'api.mailjet.com'
    OF ETPrv:Resend     ; host = 'api.resend.com'
    OF ETPrv:SparkPost  ; host = CHOOSE(LOWER(CLIP(SELF.Mailer.Acc.ApiRegion)) = 'eu', |
                                        'api.eu.sparkpost.com', 'api.sparkpost.com')
    OF ETPrv:MailerSend ; host = 'api.mailersend.com'
    OF ETPrv:AmazonSes
      host = 'email.' & CHOOSE(CLIP(SELF.Mailer.Acc.ApiRegion) <> '', |
                               CLIP(SELF.Mailer.Acc.ApiRegion), 'us-east-1') & |
             '.amazonaws.com'
    END
    !  ApiBase wins over all of it - a private relay, a regional endpoint, or
    !  a test double standing in for the provider.
    IF CLIP(SELF.Mailer.Acc.ApiBase)
      host = CLIP(SELF.Mailer.Acc.ApiBase)
      j = INSTRING('://', host, 1, 1)
      IF j THEN host = host[j + 3 : LEN(CLIP(host))].
    END
    SELF.TxtBuf.Add(CLIP(host))
  OF 'domain'   ; SELF.TxtBuf.Add(CLIP(SELF.Mailer.Acc.ApiDomain))
  OF 'user'     ; SELF.TxtBuf.Add(CLIP(SELF.Mailer.Acc.UserName))
  OF 'region'   ; SELF.TxtBuf.Add(CLIP(SELF.Mailer.Acc.ApiRegion))
  OF 'id'       ; SELF.TxtBuf.Add(CLIP(SELF.ArgId))
  OF 'email'    ; SELF.TxtBuf.Add(CLIP(SELF.ArgEmail))
  OF 'text'     ; SELF.TxtBuf.Add(CLIP(SELF.ArgText))
  OF 'subject'  ; SELF.TxtBuf.Add(CLIP(SELF.ArgSubject))
  OF 'html'
    IF NOT SELF.ArgHtml &= NULL
      SELF.TxtBuf.AddLen(SELF.ArgHtml, SIZE(SELF.ArgHtml))
    END
  OF 'from'     ; SELF.TxtBuf.Add(CLIP(SELF.Mailer.Acc.FromAddr))
  OF 'fromname' ; SELF.TxtBuf.Add(CLIP(SELF.Mailer.Acc.FromName))
  OF 'token'    ; SELF.TxtBuf.Add(CLIP(SELF.ArgToken))
  OF 'limit'    ; SELF.TxtBuf.Add('' & CHOOSE(SELF.PageSize > 0, SELF.PageSize, 100))
  OF 'offset'   ; SELF.TxtBuf.Add('' & SELF.ArgOffset)
  OF 'page'
    pg = CHOOSE(SELF.PageSize > 0, SELF.PageSize, 100)
    SELF.TxtBuf.Add('' & (SELF.ArgOffset / pg + 1))
  OF 'epochfrom' ; SELF.TxtBuf.Add('' & ((SELF.ArgFrom - DATE(1, 1, 1970)) * 86400))
  OF 'epochto'   ; SELF.TxtBuf.Add('' & ((SELF.ArgTo - DATE(1, 1, 1970) + 1) * 86400 - 1))
  OF 'ymdfrom'   ; SELF.TxtBuf.Add(CLIP(FORMAT(SELF.ArgFrom, @D10-)))
  OF 'ymdto'     ; SELF.TxtBuf.Add(CLIP(FORMAT(SELF.ArgTo, @D10-)))
  OF 'isofrom'   ; SELF.TxtBuf.Add(CLIP(FORMAT(SELF.ArgFrom, @D10-)) & 'T00:00:00Z')
  OF 'isoto'     ; SELF.TxtBuf.Add(CLIP(FORMAT(SELF.ArgTo, @D10-)) & 'T23:59:59Z')
  OF 'rfcfrom'   ; SELF.TxtBuf.Add(SELF.RfcDate(SELF.ArgFrom))
  OF 'rfcto'     ; SELF.TxtBuf.Add(SELF.RfcDate(SELF.ArgTo))
  END

!  RFC-2822, which is what Mailgun wants its date ranges in.  The day of the
!  week is counted from a date we know rather than from the Clarion epoch, so
!  it cannot be a day out if that epoch is ever misremembered.
EmailApiClass.RfcDate PROCEDURE(DATE pDate)
dow LONG
mon LONG
  CODE
  IF NOT pDate THEN RETURN ''.
  dow = ((pDate - DATE(1, 1, 2024)) % 7 + 700) % 7          ! 1 January 2024 was a Monday
  mon = MONTH(pDate)
  RETURN ETA_DowTbl[dow * 3 + 1 : dow * 3 + 3] & ', ' & FORMAT(DAY(pDate), @n02) & ' ' & |
         ETA_MonTbl[(mon - 1) * 3 + 1 : (mon - 1) * 3 + 3] & ' ' & YEAR(pDate) & |
         ' 00:00:00 GMT'

EmailApiClass.UrlEncode PROCEDURE(STRING pText)
i LONG
n LONG
b LONG
  CODE
  SELF.BodyBuf.ClearAll()
  n = LEN(CLIP(pText))
  LOOP i = 1 TO n
    b = VAL(pText[i])
    !  RFC 3986 unreserved: A-Z a-z 0-9 - . _ ~   Everything else is escaped,
    !  which is what makes an address with a + in it survive a URL.
    IF (b >= 48 AND b <= 57) OR (b >= 65 AND b <= 90) OR (b >= 97 AND b <= 122) |
       OR b = 45 OR b = 46 OR b = 95 OR b = 126
      SELF.BodyBuf.Add(pText[i])
    ELSE
      SELF.BodyBuf.Add('%' & ETA_Hex[BSHIFT(b, -4) + 1] & ETA_Hex[BAND(b, 15) + 1])
    END
  END
  RETURN SELF.BodyBuf.Value()

!  JSON escaping WITHOUT the surrounding quotes: the matrix row already wrote
!  those, so a placeholder can sit inside a string the row spelled out.
EmailApiClass.JsonStr PROCEDURE(STRING pText)
i LONG
n LONG
b LONG
  CODE
  SELF.BodyBuf.ClearAll()
  n = LEN(CLIP(pText))
  LOOP i = 1 TO n
    b = VAL(pText[i])
    CASE b
    OF 34 ; SELF.BodyBuf.Add('\"')
    OF 92 ; SELF.BodyBuf.Add('\\')
    OF 8  ; SELF.BodyBuf.Add('\b')
    OF 9  ; SELF.BodyBuf.Add('\t')
    OF 10 ; SELF.BodyBuf.Add('\n')
    OF 12 ; SELF.BodyBuf.Add('\f')
    OF 13 ; SELF.BodyBuf.Add('\r')
    ELSE
      IF b < 32
        SELF.BodyBuf.Add('\u00' & ETA_Hex[BSHIFT(b, -4) + 1] & ETA_Hex[BAND(b, 15) + 1])
      ELSE
        SELF.BodyBuf.Add(pText[i])
      END
    END
  END
  RETURN SELF.BodyBuf.Value()

! ============================================================================
!  Reading one item out of the reply
! ============================================================================
!  Pull "Column=source" out of a map string.  The search is anchored on the
!  separator so that Opens= cannot match UniqueOpens=.
EmailApiClass.MapText PROCEDURE(STRING pMap,STRING pColumn)
hay CSTRING(772)
ndl CSTRING(65)
p   LONG
e   LONG
  CODE
  IF NOT CLIP(pMap) THEN RETURN ''.
  hay = ';' & CLIP(pMap)
  ndl = ';' & CLIP(pColumn) & '='
  p   = INSTRING(ndl, hay, 1, 1)
  IF NOT p THEN RETURN ''.
  p += LEN(ndl)
  e  = INSTRING(';', hay, 1, p)
  IF NOT e THEN e = LEN(CLIP(hay)) + 1.
  IF e <= p THEN RETURN ''.
  RETURN hay[p : e - 1]

!  The value of one mapped column for the item Fetch is standing on.
!
!  A source may be:
!      email                  a member of the item
!      reason.message         a path inside the item
!      recipient.email|email  alternates - the first one that is there wins,
!                             because two versions of an API disagree
!      !unsubscribed          a literal: this provider does not send a reason,
!                             but we know what this list means
!  A leading # @ % or $ is a date converter and is only meaningful to
!  ItemWhen; the plain readers step over it.
EmailApiClass.ItemVal PROCEDURE(STRING pMap,STRING pColumn)
spec CSTRING(129)
one  CSTRING(129)
path CSTRING(257)
p    LONG
  CODE
  spec = SUB(CLIP(SELF.MapText(pMap, pColumn)), 1, 128)
  IF NOT CLIP(spec) THEN RETURN ''.
  IF spec[1] = '!' THEN RETURN spec[2 : LEN(CLIP(spec))].
  CASE spec[1]
  OF '#' OROF '@' OROF '%' OROF '$'
    spec = spec[2 : LEN(CLIP(spec))]
  END
  LOOP
    p = INSTRING('|', spec, 1, 1)
    IF p
      one  = spec[1 : p - 1]
      spec = spec[p + 1 : LEN(CLIP(spec))]
    ELSE
      one  = spec
      spec = ''
    END
    IF CLIP(SELF.ItemBase)
      path = SUB(CLIP(SELF.ItemBase) & '.' & CLIP(one), 1, 256)
    ELSE
      path = SUB(CLIP(one), 1, 256)
    END
    IF SELF.Json.Has(path)
      RETURN SELF.Json.Value(path)
    END
    IF NOT CLIP(spec) THEN BREAK.
  END
  RETURN ''

EmailApiClass.ItemLong PROCEDURE(STRING pMap,STRING pColumn)
s CSTRING(65)
  CODE
  s = SUB(CLIP(SELF.ItemVal(pMap, pColumn)), 1, 64)
  IF NOT CLIP(s) THEN RETURN 0.
  RETURN DEFORMAT(s)

EmailApiClass.ItemBool PROCEDURE(STRING pMap,STRING pColumn)
s CSTRING(65)
  CODE
  s = LOWER(SUB(CLIP(SELF.ItemVal(pMap, pColumn)), 1, 64))
  IF NOT CLIP(s) THEN RETURN 0.
  CASE s
  OF 'true'
    RETURN 1
  OF 'yes'
    RETURN 1
  OF 'y'
    RETURN 1
  OF 'active'
    RETURN 1
  OF 'valid'
    RETURN 1
  OF 'verified'
    RETURN 1
  OF 'enabled'
    RETURN 1
  OF 'ok'
    RETURN 1
  END
  IF DEFORMAT(s) THEN RETURN 1.
  RETURN 0

!  Dates arrive in four different shapes and this is the only place that has
!  to know it:  1724500000 (unix), 2026-08-24T13:22:05Z (ISO), Sat, 24 Aug
!  2026 13:22:05 GMT (RFC-2822), 2026-08-24 (a plain day).  The converter in
!  the map says which; with none, the value is sniffed.
EmailApiClass.ItemWhen PROCEDURE(STRING pMap,STRING pColumn,*DATE pDate,*TIME pTime)
spec CSTRING(129)
conv STRING(1)
raw  CSTRING(129)
n    LONG
i    LONG
d    LONG
secs LONG
yy   LONG
mm   LONG
dd   LONG
hh   LONG
mi   LONG
ss   LONG
mon  CSTRING(4)
tmp  CSTRING(129)
  CODE
  pDate = 0
  pTime = 0
  spec  = SUB(CLIP(SELF.MapText(pMap, pColumn)), 1, 128)
  IF NOT CLIP(spec) THEN RETURN.
  conv = ' '
  CASE spec[1]
  OF '#' OROF '@' OROF '%' OROF '$'
    conv = spec[1]
  END
  raw = SUB(CLIP(SELF.ItemVal(pMap, pColumn)), 1, 128)
  n   = LEN(CLIP(raw))
  IF n < 4 THEN RETURN.

  !  No converter: work it out.  All digits and big enough to be a timestamp
  !  is one; anything with a dash in the first five characters is ISO.
  IF conv = ' '
    conv = '@'
    LOOP i = 1 TO n
      IF raw[i] < '0' OR raw[i] > '9' THEN BREAK.
    END
    IF i > n AND n >= 9 THEN conv = '#'.
  END

  CASE conv
  OF '#'
    secs = DEFORMAT(raw)
    IF secs < 1 THEN RETURN.
    d     = INT(secs / 86400)
    pDate = DATE(1, 1, 1970) + d
    pTime = (secs - d * 86400) * 100 + 1
  OF '%'
    !  Sat, 24 Aug 2026 13:22:05 GMT - skip the day name and read the rest.
    i = INSTRING(',', raw, 1, 1)
    IF i THEN raw = CLIP(raw[i + 1 : n]).
    raw = CLIP(LEFT(raw))
    n   = LEN(CLIP(raw))
    IF n < 11 THEN RETURN.
    IF raw[2] = ' '                                   ! a one-digit day: pad it, so that
      tmp = '0' & CLIP(raw)                           !   every field after it sits where
      raw = tmp                                       !   the two-digit case put it
      n   = LEN(CLIP(raw))
    END
    dd  = DEFORMAT(raw[1 : 2])
    mon = UPPER(raw[4 : 6])
    mm  = (INSTRING(UPPER(mon), UPPER(ETA_MonTbl), 1, 1) + 2) / 3
    yy  = DEFORMAT(raw[8 : 11])
    IF n >= 20
      hh = DEFORMAT(raw[13 : 14])
      mi = DEFORMAT(raw[16 : 17])
      ss = DEFORMAT(raw[19 : 20])
    END
    IF mm < 1 OR mm > 12 OR dd < 1 OR yy < 1900 THEN RETURN.
    pDate = DATE(mm, dd, yy)
    pTime = ((hh * 60 + mi) * 60 + ss) * 100 + 1
  ELSE
    !  ISO-8601, or a plain YYYY-MM-DD.  Everything after the seconds - a
    !  fraction, a Z, an offset - is ignored: none of these APIs reports in
    !  anything but UTC, and a mail log does not need the last second.
    IF n < 10 THEN RETURN.
    yy = DEFORMAT(raw[1 : 4])
    mm = DEFORMAT(raw[6 : 7])
    dd = DEFORMAT(raw[9 : 10])
    IF mm < 1 OR mm > 12 OR dd < 1 OR yy < 1900 THEN RETURN.
    pDate = DATE(mm, dd, yy)
    IF n >= 19
      hh = DEFORMAT(raw[12 : 13])
      mi = DEFORMAT(raw[15 : 16])
      ss = DEFORMAT(raw[18 : 19])
      pTime = ((hh * 60 + mi) * 60 + ss) * 100 + 1
    END
  END
  RETURN

! ============================================================================
!  Turning one item into one row of a normalised queue
!
!  This is the ONLY method that knows which queue an operation fills, and it
!  is VIRTUAL: a derived class that adds a provider with an extra column
!  overrides it, calls PARENT and then fills the extra in.
! ============================================================================
EmailApiClass.MapItem PROCEDURE(BYTE pOp,BYTE pKind,STRING pMap)
k BYTE
  CODE
  CASE pOp
  OF ETOp:Account
    !  Merged from several calls, so only ever fill in a blank: the second
    !  part must not wipe what the first one found.
    IF NOT CLIP(SELF.Account.Name)    THEN SELF.Account.Name    = SELF.ItemVal(pMap, 'Name').
    IF NOT CLIP(SELF.Account.Company) THEN SELF.Account.Company = SELF.ItemVal(pMap, 'Company').
    IF NOT CLIP(SELF.Account.Address) THEN SELF.Account.Address = SELF.ItemVal(pMap, 'Address').
    IF NOT CLIP(SELF.Account.Plan)    THEN SELF.Account.Plan    = SELF.ItemVal(pMap, 'Plan').
    IF NOT CLIP(SELF.Account.Status)  THEN SELF.Account.Status  = SELF.ItemVal(pMap, 'Status').
    IF SELF.Account.Credits < 0 AND CLIP(SELF.MapText(pMap, 'Credits'))
      SELF.Account.Credits = SELF.ItemLong(pMap, 'Credits')
    END
    IF NOT SELF.Account.Reputation THEN SELF.Account.Reputation = SELF.ItemLong(pMap, 'Reputation').
    IF NOT CLIP(SELF.Account.Raw)
      SELF.Account.Raw = SUB(SELF.Json.Raw(SELF.ItemBase), 1, 2048)
    END

  OF ETOp:Suppressions
    CLEAR(SELF.SuppQ)
    SELF.SuppQ.Address = SELF.ItemVal(pMap, 'Address')
    IF NOT CLIP(SELF.SuppQ.Address) THEN RETURN.       ! a row with no address is no row
    SELF.SuppQ.Reason  = SELF.ItemVal(pMap, 'Reason')
    SELF.SuppQ.Code    = SELF.ItemLong(pMap, 'Code')
    SELF.SuppQ.Id      = SELF.ItemVal(pMap, 'Id')
    SELF.SuppQ.Sender  = SELF.ItemVal(pMap, 'Sender')
    SELF.ItemWhen(pMap, 'When', SELF.SuppQ.WhenDate, SELF.SuppQ.WhenTime)
    IF pKind = ETSup:All
      !  A provider that keeps one list tells us the kind in its own words.
      k = SELF.SuppKindOf(SELF.ItemVal(pMap, 'KindText'))
      IF NOT k THEN k = SELF.SuppKindOf(SELF.SuppQ.Reason).
      IF NOT k THEN k = ETSup:Block.
    ELSE
      k = pKind
    END
    SELF.SuppQ.Kind     = k
    SELF.SuppQ.KindName = SELF.SuppKindName(k)
    SELF.SuppQ.Raw      = SUB(SELF.Json.Raw(SELF.ItemBase), 1, 1024)
    ADD(SELF.SuppQ)

  OF ETOp:Stats
    CLEAR(SELF.StatQ)
    SELF.ItemWhen(pMap, 'When', SELF.StatQ.WhenDate, SELF.TimeSink)
    SELF.StatQ.Requests     = SELF.ItemLong(pMap, 'Requests')
    SELF.StatQ.Delivered    = SELF.ItemLong(pMap, 'Delivered')
    SELF.StatQ.Opens        = SELF.ItemLong(pMap, 'Opens')
    SELF.StatQ.UniqueOpens  = SELF.ItemLong(pMap, 'UniqueOpens')
    SELF.StatQ.Clicks       = SELF.ItemLong(pMap, 'Clicks')
    SELF.StatQ.UniqueClicks = SELF.ItemLong(pMap, 'UniqueClicks')
    SELF.StatQ.HardBounces  = SELF.ItemLong(pMap, 'HardBounces')
    SELF.StatQ.SoftBounces  = SELF.ItemLong(pMap, 'SoftBounces')
    SELF.StatQ.Blocks       = SELF.ItemLong(pMap, 'Blocks')
    SELF.StatQ.SpamReports  = SELF.ItemLong(pMap, 'SpamReports')
    SELF.StatQ.Unsubscribed = SELF.ItemLong(pMap, 'Unsubscribed')
    SELF.StatQ.Invalid      = SELF.ItemLong(pMap, 'Invalid')
    ADD(SELF.StatQ)

  OF ETOp:Events
    CLEAR(SELF.EventQ)
    SELF.ItemWhen(pMap, 'When', SELF.EventQ.WhenDate, SELF.EventQ.WhenTime)
    SELF.EventQ.Address   = SELF.ItemVal(pMap, 'Address')
    SELF.EventQ.EventName = SELF.ItemVal(pMap, 'EventName')
    SELF.EventQ.Reason    = SELF.ItemVal(pMap, 'Reason')
    SELF.EventQ.Subject   = SELF.ItemVal(pMap, 'Subject')
    SELF.EventQ.MessageId = SELF.ItemVal(pMap, 'MessageId')
    SELF.EventQ.Link      = SELF.ItemVal(pMap, 'Link')
    ADD(SELF.EventQ)

  OF ETOp:Contacts
    DO AddContactRow
  OF ETOp:ListMembers
    DO AddContactRow

  OF ETOp:Lists
    CLEAR(SELF.ListQ)
    SELF.ListQ.Id       = SELF.ItemVal(pMap, 'Id')
    SELF.ListQ.Name     = SELF.ItemVal(pMap, 'Name')
    SELF.ListQ.Members  = SELF.ItemLong(pMap, 'Members')
    SELF.ListQ.Blocked  = SELF.ItemLong(pMap, 'Blocked')
    SELF.ListQ.FolderId = SELF.ItemVal(pMap, 'FolderId')
    ADD(SELF.ListQ)

  OF ETOp:Campaigns
    CLEAR(SELF.CampaignQ)
    SELF.CampaignQ.Id      = SELF.ItemVal(pMap, 'Id')
    SELF.CampaignQ.Name    = SELF.ItemVal(pMap, 'Name')
    SELF.CampaignQ.Subject = SELF.ItemVal(pMap, 'Subject')
    SELF.CampaignQ.Status  = SELF.ItemVal(pMap, 'Status')
    SELF.ItemWhen(pMap, 'When', SELF.CampaignQ.WhenDate, SELF.CampaignQ.WhenTime)
    SELF.CampaignQ.Recipients = SELF.ItemLong(pMap, 'Recipients')
    SELF.CampaignQ.Opens      = SELF.ItemLong(pMap, 'Opens')
    SELF.CampaignQ.Clicks     = SELF.ItemLong(pMap, 'Clicks')
    ADD(SELF.CampaignQ)

  OF ETOp:Templates
    CLEAR(SELF.TemplateQ)
    SELF.TemplateQ.Id      = SELF.ItemVal(pMap, 'Id')
    SELF.TemplateQ.Name    = SELF.ItemVal(pMap, 'Name')
    SELF.TemplateQ.Subject = SELF.ItemVal(pMap, 'Subject')
    SELF.TemplateQ.Active  = SELF.ItemBool(pMap, 'Active')
    SELF.ItemWhen(pMap, 'When', SELF.TemplateQ.WhenDate, SELF.TimeSink)
    ADD(SELF.TemplateQ)

  OF ETOp:Senders
    CLEAR(SELF.SenderQ)
    SELF.SenderQ.Id       = SELF.ItemVal(pMap, 'Id')
    SELF.SenderQ.Address  = SELF.ItemVal(pMap, 'Address')
    SELF.SenderQ.Name     = SELF.ItemVal(pMap, 'Name')
    SELF.SenderQ.Verified = SELF.ItemBool(pMap, 'Verified')
    SELF.SenderQ.Status   = SELF.ItemVal(pMap, 'Status')
    ADD(SELF.SenderQ)

  OF ETOp:Domains
    CLEAR(SELF.DomainQ)
    SELF.DomainQ.Id       = SELF.ItemVal(pMap, 'Id')
    SELF.DomainQ.Name     = SELF.ItemVal(pMap, 'Name')
    SELF.DomainQ.Verified = SELF.ItemBool(pMap, 'Verified')
    SELF.DomainQ.Spf      = SELF.ItemBool(pMap, 'Spf')
    SELF.DomainQ.Dkim     = SELF.ItemBool(pMap, 'Dkim')
    SELF.DomainQ.Status   = SELF.ItemVal(pMap, 'Status')
    ADD(SELF.DomainQ)

  OF ETOp:Webhooks
    CLEAR(SELF.HookQ)
    SELF.HookQ.Id     = SELF.ItemVal(pMap, 'Id')
    SELF.HookQ.Url    = SELF.ItemVal(pMap, 'Url')
    SELF.HookQ.Events = SELF.ItemVal(pMap, 'Events')
    SELF.HookQ.Active = SELF.ItemBool(pMap, 'Active')
    ADD(SELF.HookQ)
  END
  RETURN

AddContactRow ROUTINE
  CLEAR(SELF.ContactQ)
  SELF.ContactQ.Id      = SELF.ItemVal(pMap, 'Id')
  SELF.ContactQ.Address = SELF.ItemVal(pMap, 'Address')
  SELF.ContactQ.Name    = SELF.ItemVal(pMap, 'Name')
  SELF.ContactQ.Blocked = SELF.ItemBool(pMap, 'Blocked')
  SELF.ContactQ.Unsubscribed = SELF.ItemBool(pMap, 'Unsubscribed')
  SELF.ItemWhen(pMap, 'When', SELF.ContactQ.WhenDate, SELF.TimeSink)
  SELF.ContactQ.ListIds = SELF.ItemVal(pMap, 'ListIds')
  SELF.ContactQ.Raw     = SUB(SELF.Json.Raw(SELF.ItemBase), 1, 1024)
  ADD(SELF.ContactQ)

! ============================================================================
!  The engine
! ============================================================================
!  Ask for a list and fill the queue behind it.  Handles both kinds of paging
!  the nine providers use: an offset or page number we count ourselves, a
!  cursor the provider hands back as a whole address, and a continuation
!  TOKEN that has to be handed back as a parameter.
EmailApiClass.Fetch PROCEDURE(BYTE pOp,BYTE pKind)
verb    CSTRING(8)
rowUrl  CSTRING(257)
itemPt  CSTRING(65)
mapStr  CSTRING(769)
nextPt  CSTRING(65)
rowKind BYTE
url     CSTRING(1025)
hdr     CSTRING(1025)
nextUrl CSTRING(1025)
nextVal CSTRING(1025)
p       LONG
base    CSTRING(129)
pageSz  LONG
maxRow  LONG
total   LONG
n       LONG
i       LONG
paged   BYTE
status  LONG
  CODE
  IF NOT SELF.FindRow(pOp, pKind)
    SELF.SetErr(ETApi:NotSupported)
    RETURN -1
  END
  IF NOT CLIP(SELF.Mailer.Acc.ApiKey)
    SELF.SetErr(ETApi:NoKey)
    RETURN -1
  END
  verb    = SELF.MapQ.Verb
  rowUrl  = SELF.MapQ.Url
  itemPt  = SELF.MapQ.ItemPath
  mapStr  = SELF.MapQ.Map
  nextPt  = SELF.MapQ.NextPath
  rowKind = SELF.MapQ.Kind

  SELF.Net.Trace      = SELF.Mailer.Trace
  SELF.Net.VerifyCert = SELF.Mailer.Acc.VerifyCert
  IF SELF.Mailer.Acc.Timeout > 0 THEN SELF.Net.Timeout = SELF.Mailer.Acc.Timeout.

  pageSz = CHOOSE(SELF.PageSize > 0, SELF.PageSize, 100)
  maxRow = CHOOSE(SELF.MaxRows > 0, SELF.MaxRows, 5000)
  paged  = 0
  IF INSTRING('{{offset}', rowUrl, 1, 1) THEN paged = 1.
  IF INSTRING('{{page}', rowUrl, 1, 1)   THEN paged = 1.
  SELF.ArgOffset = 0
  SELF.ArgToken  = ''
  nextUrl = ''
  total   = 0

  LOOP
    IF CLIP(nextUrl)
      url = nextUrl
    ELSE
      url = SUB(SELF.Expand(rowUrl), 1, 1024)
    END
    SELF.LastUrl = SUB(url, 1, 512)
    hdr    = SUB(SELF.SignedHeaders(pOp, verb, url, ''), 1, 1024)
    status = SELF.Net.Http(verb, url, hdr, '')
    SELF.LastStatus = status
    IF status < 200
      SELF.SetErr(ETApi:Http)
      RETURN -1
    END
    IF status > 299
      SELF.SetErr(ETApi:Refused, SELF.FailedText())
      RETURN -1
    END
    IF NOT SELF.Json.Parse(SELF.Net.Body())
      SELF.SetErr(ETApi:BadReply, SELF.Json.LastErrorText)
      RETURN -1
    END

    !  One object, not a list - an account profile or an aggregate report.
    IF itemPt = '*'
      SELF.ItemBase = ''
      SELF.MapItem(pOp, rowKind, mapStr)
      total += 1
      BREAK
    END

    !  Where the array really is.  A named path that is not in the reply, or
    !  no name at all when the reply is not itself an array, falls back to
    !  the first array in the document - which is what a provider that
    !  renamed its wrapper actually returns.
    base = itemPt
    IF CLIP(base)
      IF NOT SELF.Json.Has(base) THEN base = SUB(SELF.Json.FirstArray(), 1, 128).
    ELSE
      IF SELF.Json.KindOf('') <> ETJs:Array THEN base = SUB(SELF.Json.FirstArray(), 1, 128).
    END
    n = SELF.Json.Count(base)
    LOOP i = 0 TO n - 1
      IF CLIP(base)
        SELF.ItemBase = SUB(CLIP(base) & '.' & i, 1, 128)
      ELSE
        SELF.ItemBase = SUB('' & i, 1, 128)
      END
      SELF.MapItem(pOp, rowKind, mapStr)
      total += 1
      IF total >= maxRow THEN BREAK.
    END
    IF total >= maxRow THEN BREAK.

    IF CLIP(nextPt)
      nextVal = SUB(SELF.Json.Value(nextPt), 1, 1024)
      IF n < 1 THEN BREAK.
      IF NOT CLIP(nextVal) THEN BREAK.
      IF LOWER(SUB(nextVal, 1, 4)) = 'http'
        nextUrl = nextVal                              ! a whole address, as Mailgun sends
      ELSE
        !  A continuation TOKEN, as Amazon sends. The parameter it goes back
        !  in is the last segment of the path it arrived at, so the matrix row
        !  says NextToken and nothing here has to know the provider.
        SELF.ArgToken = nextVal
        nextUrl = SUB(SELF.Expand(rowUrl), 1, 1024)
        p = INSTRING('.', nextPt, 1, 1)
        LOOP WHILE p
          nextPt = nextPt[p + 1 : LEN(CLIP(nextPt))]
          p = INSTRING('.', nextPt, 1, 1)
        END
        nextUrl = CLIP(nextUrl) & CHOOSE(INSTRING('?', nextUrl, 1, 1) > 0, '&', '?') & |
                  CLIP(nextPt) & '=' & SELF.UrlEncode(nextVal)
      END
      CYCLE
    END
    IF NOT paged THEN BREAK.
    IF n < pageSz THEN BREAK.
    SELF.ArgOffset += pageSz
  END
  SELF.SetErr(ETApi:Ok)
  RETURN total

!  One call that changes something.  Same plumbing, no paging, and the answer
!  is simply whether the provider accepted it.
EmailApiClass.Perform PROCEDURE(BYTE pOp,BYTE pKind)
verb   CSTRING(8)
rowUrl CSTRING(257)
bodyT  CSTRING(769)
url    CSTRING(1025)
hdr    CSTRING(1153)
status LONG
  CODE
  IF NOT SELF.FindRow(pOp, pKind) THEN RETURN SELF.SetErr(ETApi:NotSupported).
  IF NOT CLIP(SELF.Mailer.Acc.ApiKey) THEN RETURN SELF.SetErr(ETApi:NoKey).
  verb   = SELF.MapQ.Verb
  rowUrl = SELF.MapQ.Url
  bodyT  = SELF.MapQ.Body

  SELF.Net.Trace      = SELF.Mailer.Trace
  SELF.Net.VerifyCert = SELF.Mailer.Acc.VerifyCert
  IF SELF.Mailer.Acc.Timeout > 0 THEN SELF.Net.Timeout = SELF.Mailer.Acc.Timeout.

  url = SUB(SELF.Expand(rowUrl), 1, 1024)
  SELF.LastUrl = SUB(url, 1, 512)
  hdr = SUB(SELF.SignedHeaders(pOp, verb, url, SELF.Expand(bodyT)), 1, 1024)
  IF CLIP(bodyT)
    IF LOWER(SUB(bodyT, 1, 5)) = 'form:'
      hdr = CLIP(hdr) & '<13,10>Content-Type: application/x-www-form-urlencoded'
    ELSE
      hdr = CLIP(hdr) & '<13,10>Content-Type: application/json'
    END
    status = SELF.Net.Http(verb, url, hdr, SELF.Expand(bodyT))
  ELSE
    status = SELF.Net.Http(verb, url, hdr, '')
  END
  SELF.LastStatus = status
  IF status < 200 THEN RETURN SELF.SetErr(ETApi:Http).
  IF status > 299 THEN RETURN SELF.SetErr(ETApi:Refused, SELF.FailedText()).
  RETURN SELF.SetErr(ETApi:Ok)

! ============================================================================
!  Reading
! ============================================================================
!  Most providers keep the name, the plan and the address at three different
!  addresses, so the answer is merged from up to four calls.  A provider that
!  publishes only one of them still fills in the one it has.
EmailApiClass.GetAccount PROCEDURE()
part BYTE
any  BYTE
  CODE
  CLEAR(SELF.Account)
  SELF.Account.Credits = -1
  any = 0
  LOOP part = 0 TO 3
    IF NOT SELF.FindRow(ETOp:Account, part) THEN CYCLE.
    IF SELF.MapQ.Kind <> part THEN CYCLE.
    IF SELF.Fetch(ETOp:Account, part) >= 0 THEN any = 1.
  END
  IF NOT any THEN RETURN SELF.SetErr(ETApi:NotSupported).
  RETURN SELF.SetErr(ETApi:Ok)

!  The blocked addresses, with the reason each one is blocked.
!
!  Providers split this two ways.  Some keep a separate list per kind
!  (SendGrid: bounces, blocks, spam_reports, unsubscribes, invalid_emails);
!  some keep ONE list and label each row (Brevo, Postmark, SparkPost).  Both
!  answer the same question here: ask for a kind and you get that kind, ask
!  for everything and you get everything, and every row says which it is.
EmailApiClass.GetSuppressions PROCEDURE(BYTE pKind)
k     BYTE
i     LONG
n     LONG
exact BYTE
any   BYTE
okAny BYTE
  CODE
  FREE(SELF.SuppQ)
  IF pKind <> ETSup:All
    IF NOT SELF.FindRow(ETOp:Suppressions, pKind)
      SELF.SetErr(ETApi:NotSupported)
      RETURN -1
    END
    exact = CHOOSE(SELF.MapQ.Kind = pKind, 1, 0)
    n = SELF.Fetch(ETOp:Suppressions, pKind)
    IF n < 0 THEN RETURN n.
    IF NOT exact
      !  One list for everything: keep only the rows that really are this
      !  kind, which the mapper worked out from the provider's own wording.
      LOOP i = RECORDS(SELF.SuppQ) TO 1 BY -1
        GET(SELF.SuppQ, i)
        IF SELF.SuppQ.Kind <> pKind THEN DELETE(SELF.SuppQ).
      END
    END
    RETURN RECORDS(SELF.SuppQ)
  END

  !  Everything.  One call if the provider keeps one list, otherwise one call
  !  per list it keeps.
  IF SELF.FindRow(ETOp:Suppressions, ETSup:All)
    IF SELF.MapQ.Kind = ETSup:All
      RETURN SELF.Fetch(ETOp:Suppressions, ETSup:All)
    END
  END
  any   = 0
  okAny = 0
  LOOP k = 1 TO ETSup:Kinds
    IF NOT SELF.ExactRow(ETOp:Suppressions, k) THEN CYCLE.
    any = 1
    n = SELF.Fetch(ETOp:Suppressions, k)
    !  One list refusing does not make the others worthless: an account
    !  without the add-on that opens one endpoint still has four to read, and
    !  a partial answer is a great deal more use than none.  The failure is
    !  still in LastErrorText.
    IF n >= 0 THEN okAny = 1.
  END
  IF NOT any
    SELF.SetErr(ETApi:NotSupported)
    RETURN -1
  END
  IF NOT okAny THEN RETURN -1.
  RETURN RECORDS(SELF.SuppQ)

EmailApiClass.GetStats PROCEDURE(DATE pFrom,DATE pTo)
  CODE
  FREE(SELF.StatQ)
  SELF.ArgFrom = CHOOSE(pFrom > 0, pFrom, TODAY() - 30)
  SELF.ArgTo   = CHOOSE(pTo > 0, pTo, TODAY())
  RETURN SELF.Fetch(ETOp:Stats, 0)

EmailApiClass.GetEvents PROCEDURE(DATE pFrom,DATE pTo)
  CODE
  FREE(SELF.EventQ)
  SELF.ArgFrom = CHOOSE(pFrom > 0, pFrom, TODAY() - 7)
  SELF.ArgTo   = CHOOSE(pTo > 0, pTo, TODAY())
  RETURN SELF.Fetch(ETOp:Events, 0)

!  With no list, every contact the account has.  With a list, the ones on it -
!  through whichever endpoint the provider offers for that.
EmailApiClass.GetContacts PROCEDURE(<STRING pListId>)
  CODE
  FREE(SELF.ContactQ)
  SELF.ArgId = ''
  IF NOT OMITTED(pListId)
    SELF.ArgId = SUB(CLIP(pListId), 1, 128)
  END
  IF CLIP(SELF.ArgId)
    IF SELF.FindRow(ETOp:ListMembers, 0)
      RETURN SELF.Fetch(ETOp:ListMembers, 0)
    END
  END
  RETURN SELF.Fetch(ETOp:Contacts, 0)

EmailApiClass.GetLists PROCEDURE()
  CODE
  FREE(SELF.ListQ)
  RETURN SELF.Fetch(ETOp:Lists, 0)

EmailApiClass.GetCampaigns PROCEDURE()
  CODE
  FREE(SELF.CampaignQ)
  RETURN SELF.Fetch(ETOp:Campaigns, 0)

EmailApiClass.GetTemplates PROCEDURE()
  CODE
  FREE(SELF.TemplateQ)
  RETURN SELF.Fetch(ETOp:Templates, 0)

EmailApiClass.GetSenders PROCEDURE()
  CODE
  FREE(SELF.SenderQ)
  RETURN SELF.Fetch(ETOp:Senders, 0)

EmailApiClass.GetDomains PROCEDURE()
  CODE
  FREE(SELF.DomainQ)
  RETURN SELF.Fetch(ETOp:Domains, 0)

EmailApiClass.GetWebhooks PROCEDURE()
  CODE
  FREE(SELF.HookQ)
  RETURN SELF.Fetch(ETOp:Webhooks, 0)

! ============================================================================
!  Changing
! ============================================================================
!  Unblock one address.
!
!  Three providers delete by an ID of their own rather than by the address -
!  MailerSend, and Postmark for a bounce.  Rather than make the caller carry
!  that, the id is looked up in whatever GetSuppressions last loaded.  If the
!  list has not been loaded, that is the error you get, and it says so.
EmailApiClass.DeleteSuppression PROCEDURE(STRING pAddress,BYTE pKind)
i      LONG
k      BYTE
needId BYTE
found  BYTE
  CODE
  SELF.ArgEmail = SUB(CLIP(pAddress), 1, 255)
  SELF.ArgId    = ''
  IF NOT CLIP(SELF.ArgEmail) THEN RETURN SELF.SetErr(ETApi:Refused, 'No address was given.').
  k = pKind

  !  "Whichever list it is on" has to become a real list before it goes on the
  !  wire: at a provider with five of them, deleting a bounce from the blocks
  !  list quite reasonably comes back as "never heard of it".
  IF k = ETSup:All
    IF NOT SELF.ExactRow(ETOp:SuppDelete, ETSup:All)
      !  The loaded list knows which one it is.
      LOOP i = 1 TO RECORDS(SELF.SuppQ)
        GET(SELF.SuppQ, i)
        IF UPPER(CLIP(SELF.SuppQ.Address)) <> UPPER(CLIP(SELF.ArgEmail)) THEN CYCLE.
        IF SELF.SuppQ.Kind THEN k = SELF.SuppQ.Kind.
        BREAK
      END
    END
  END
  !  Still no idea?  Try each list the provider keeps until one accepts it.
  IF k = ETSup:All
    IF NOT SELF.ExactRow(ETOp:SuppDelete, ETSup:All)
      LOOP k = 1 TO ETSup:Kinds
        IF NOT SELF.ExactRow(ETOp:SuppDelete, k) THEN CYCLE.
        IF SELF.DeleteSuppression(pAddress, k) THEN RETURN 1.
      END
      RETURN 0                                            ! the last error stands
    END
    k = ETSup:All
  END

  IF NOT SELF.FindRow(ETOp:SuppDelete, k) THEN RETURN SELF.SetErr(ETApi:NotSupported).
  needId = 0
  IF INSTRING('{{id}', SELF.MapQ.Url, 1, 1)  THEN needId = 1.
  IF INSTRING('{{id}', SELF.MapQ.Body, 1, 1) THEN needId = 1.
  IF needId
    found = 0
    LOOP i = 1 TO RECORDS(SELF.SuppQ)
      GET(SELF.SuppQ, i)
      IF UPPER(CLIP(SELF.SuppQ.Address)) = UPPER(CLIP(SELF.ArgEmail))
        SELF.ArgId = SUB(CLIP(SELF.SuppQ.Id), 1, 128)
        found = 1
        BREAK
      END
    END
    IF NOT found OR NOT CLIP(SELF.ArgId)
      RETURN SELF.SetErr(ETApi:Refused, CLIP(SELF.Mailer.ProviderName(SELF.Mailer.Acc.Provider)) & |
             ' removes a block by its own id, not by the address. Load the list with ' & |
             'GetSuppressions() first so the id is known.')
    END
  END
  RETURN SELF.Perform(ETOp:SuppDelete, k)

!  Unblock the lot.
!
!  Where the provider has an endpoint for it, that is one call.  Where it has
!  not - Brevo, Mailjet, SparkPost - the rows are deleted one at a time, so
!  the operation still means the same thing everywhere.  Either way the answer
!  is how many addresses were let back in, or -1 if the provider said no.
EmailApiClass.DeleteAllSuppressions PROCEDURE(BYTE pKind)
i    LONG
k    BYTE
n    LONG
done LONG
any  BYTE
  CODE
  !  At a provider with a separate list per kind, "all of them" means all of
  !  them - one pass per list.  Doing anything else would empty the bounces
  !  and report that the spam reports had gone too.
  IF pKind = ETSup:All
    IF NOT SELF.ExactRow(ETOp:SuppDeleteAll, ETSup:All)
      IF NOT SELF.ExactRow(ETOp:SuppDelete, ETSup:All)
        done = 0
        any  = 0
        LOOP k = 1 TO ETSup:Kinds
          IF NOT SELF.ExactRow(ETOp:Suppressions, k) THEN CYCLE.
          any = 1
          n = SELF.DeleteAllSuppressions(k)
          IF n > 0 THEN done += n.
        END
        IF any
          FREE(SELF.SuppQ)
          RETURN done
        END
      END
    END
  END
  IF NOT RECORDS(SELF.SuppQ)
    IF SELF.GetSuppressions(pKind) < 0 THEN RETURN -1.
  END
  IF SELF.FindRow(ETOp:SuppDeleteAll, pKind)
    IF SELF.MapQ.Op = ETOp:SuppDeleteAll
      IF NOT SELF.Perform(ETOp:SuppDeleteAll, pKind) THEN RETURN -1.
      done = 0
      LOOP i = RECORDS(SELF.SuppQ) TO 1 BY -1
        GET(SELF.SuppQ, i)
        IF pKind <> ETSup:All AND SELF.SuppQ.Kind <> pKind THEN CYCLE.
        DELETE(SELF.SuppQ)
        done += 1
      END
      RETURN done
    END
  END
  done = 0
  LOOP i = RECORDS(SELF.SuppQ) TO 1 BY -1
    GET(SELF.SuppQ, i)
    IF pKind <> ETSup:All AND SELF.SuppQ.Kind <> pKind THEN CYCLE.
    IF NOT SELF.DeleteSuppression(SELF.SuppQ.Address, SELF.SuppQ.Kind) THEN CYCLE.
    GET(SELF.SuppQ, i)                                  ! the lookup moved the queue pointer
    DELETE(SELF.SuppQ)
    done += 1
  END
  IF NOT done AND SELF.LastError THEN RETURN -1.
  RETURN done

EmailApiClass.AddSuppression PROCEDURE(STRING pAddress,BYTE pKind,<STRING pReason>)
  CODE
  SELF.ArgEmail = SUB(CLIP(pAddress), 1, 255)
  SELF.ArgText  = 'Blocked by the application'
  IF NOT OMITTED(pReason)
    IF CLIP(pReason) THEN SELF.ArgText = SUB(CLIP(pReason), 1, 512).
  END
  RETURN SELF.Perform(ETOp:SuppAdd, pKind)

EmailApiClass.AddContact PROCEDURE(STRING pAddress,<STRING pName>,<STRING pListId>)
variant BYTE
  CODE
  SELF.ArgEmail = SUB(CLIP(pAddress), 1, 255)
  SELF.ArgText  = ''
  SELF.ArgId    = ''
  IF NOT OMITTED(pName)   THEN SELF.ArgText = SUB(CLIP(pName), 1, 512).
  IF NOT OMITTED(pListId) THEN SELF.ArgId   = SUB(CLIP(pListId), 1, 128).
  variant = CHOOSE(CLIP(SELF.ArgId) <> '', 1, 0)
  IF NOT SELF.FindRow(ETOp:ContactAdd, variant)
    !  A provider that only adds INTO a list (Mailgun, Resend) still works
    !  when a list was named; without one there is nothing it can do.
    RETURN SELF.SetErr(ETApi:NotSupported)
  END
  IF SELF.MapQ.Kind <> variant THEN RETURN SELF.SetErr(ETApi:NotSupported).
  RETURN SELF.Perform(ETOp:ContactAdd, variant)

EmailApiClass.DeleteContact PROCEDURE(STRING pIdOrAddress,<STRING pListId>)
  CODE
  !  Most providers delete a contact by one value - their own id, or the
  !  address - so {id} and {email} are both filled with it. Amazon SES is the
  !  first that needs BOTH: the LIST in {id} and the address in {email}. When
  !  a list is named it wins, or the address ends up standing in for the list
  !  and the row is deleted from a contact list that does not exist.
  SELF.ArgEmail = SUB(CLIP(pIdOrAddress), 1, 255)
  IF NOT OMITTED(pListId) AND CLIP(pListId) <> ''
    SELF.ArgId  = SUB(CLIP(pListId), 1, 128)
  ELSE
    SELF.ArgId  = SUB(CLIP(pIdOrAddress), 1, 128)
  END
  RETURN SELF.Perform(ETOp:ContactDelete, 0)

EmailApiClass.AddList PROCEDURE(STRING pName)
  CODE
  SELF.ArgText = SUB(CLIP(pName), 1, 512)
  RETURN SELF.Perform(ETOp:ListAdd, 0)

!  Create a campaign - a real one, in the provider's own dashboard, ready to
!  send.  It is NOT sent here: SendCampaign() does that, so a campaign can be
!  built by a batch process at night and released by a person in the morning.
EmailApiClass.AddCampaign PROCEDURE(STRING pName,STRING pSubject,STRING pHtml,STRING pListId)
n  LONG
ok BYTE
  CODE
  SELF.ArgText    = SUB(CLIP(pName), 1, 512)
  SELF.ArgSubject = SUB(CLIP(pSubject), 1, 256)
  SELF.ArgId      = SUB(CLIP(pListId), 1, 128)
  n = SIZE(pHtml)
  IF n < 1 THEN n = 1.
  SELF.ArgHtml &= NEW(STRING(n))
  SELF.ArgHtml[1 : n] = pHtml[1 : n]
  ok = SELF.Perform(ETOp:CampaignAdd, 0)
  DISPOSE(SELF.ArgHtml)
  SELF.ArgHtml &= NULL
  !  Most providers answer with the new campaign's id - worth keeping, since
  !  SendCampaign needs it.
  IF ok
    IF SELF.Json.Parse(SELF.Net.Body())
      SELF.ArgId = SUB(SELF.Json.Value('id'), 1, 128)
      IF NOT CLIP(SELF.ArgId) THEN SELF.ArgId = SUB(SELF.Json.Value('ID'), 1, 128).
      IF NOT CLIP(SELF.ArgId) THEN SELF.ArgId = SUB(SELF.Json.Value('Data.0.ID'), 1, 128).
    END
  END
  RETURN ok

EmailApiClass.SendCampaign PROCEDURE(STRING pId)
  CODE
  SELF.ArgId = SUB(CLIP(pId), 1, 128)
  IF NOT CLIP(SELF.ArgId) THEN RETURN SELF.SetErr(ETApi:Refused, 'No campaign id was given.').
  RETURN SELF.Perform(ETOp:CampaignSend, 0)

EmailApiClass.AddWebhook PROCEDURE(STRING pUrl,<STRING pEvents>)
  CODE
  SELF.ArgText = SUB(CLIP(pUrl), 1, 512)
  SELF.ArgId   = ''
  IF NOT OMITTED(pEvents) THEN SELF.ArgId = SUB(CLIP(pEvents), 1, 128).
  RETURN SELF.Perform(ETOp:WebhookAdd, 0)

EmailApiClass.DeleteWebhook PROCEDURE(STRING pId)
  CODE
  SELF.ArgId = SUB(CLIP(pId), 1, 128)
  RETURN SELF.Perform(ETOp:WebhookDelete, 0)

! ============================================================================
!  Using the answers
! ============================================================================
!  Is this address on the list we last loaded?  The point of asking is the
!  obvious one: do not send to somebody the provider will refuse anyway, and
!  do not burn reputation re-sending to a hard bounce.
EmailApiClass.IsBlocked PROCEDURE(STRING pAddress)
i LONG
a CSTRING(256)
  CODE
  a = UPPER(SUB(CLIP(pAddress), 1, 255))
  IF NOT CLIP(a) THEN RETURN 0.
  LOOP i = 1 TO RECORDS(SELF.SuppQ)
    GET(SELF.SuppQ, i)
    IF UPPER(CLIP(SELF.SuppQ.Address)) = a THEN RETURN 1.
  END
  RETURN 0

!  The loaded list as a CSV, for a spreadsheet or for your own records.  The
!  reason is the column people actually want, so it is not abbreviated.
EmailApiClass.ExportSuppressions PROCEDURE(STRING pFileName)
i     LONG
hFile LONG
wrote ULONG
path  CSTRING(261)
line  &STRING
text  CSTRING(2049)
  CODE
  path  = CLIP(pFileName)
  hFile = ETA_CreateFileA(path, ETA_GENERIC_WRITE, 0, 0, ETA_CREATE_ALWAYS, |
                          ETA_FILE_ATTR_NORMAL, 0)
  IF hFile = ETA_INVALID_HANDLE OR hFile = 0
    SELF.SetErr(ETApi:Refused, 'The file could not be written: ' & CLIP(path))
    RETURN -1
  END
  SELF.TxtBuf.ClearAll()
  SELF.BodyBuf.ClearAll()
  text = 'Address,Kind,Reason,Code,Date,Time,Sender<13,10>'
  line &= NEW(STRING(2050))
  line[1 : LEN(CLIP(text))] = text
  ETA_WriteFile(hFile, line, LEN(CLIP(text)), wrote, 0)
  LOOP i = 1 TO RECORDS(SELF.SuppQ)
    GET(SELF.SuppQ, i)
    !  Csv() and the two buffers it uses have to be read one at a time: every
    !  value-returning method here builds into a class-owned buffer, so two
    !  of them cannot be live in the same expression.
    text = SELF.Csv(SELF.SuppQ.Address)
    text = CLIP(text) & ',' & SELF.Csv(SELF.SuppQ.KindName)
    text = CLIP(text) & ',' & SELF.Csv(SELF.SuppQ.Reason)
    text = CLIP(text) & ',' & SELF.SuppQ.Code & ',' & |
           CHOOSE(SELF.SuppQ.WhenDate > 0, CLIP(FORMAT(SELF.SuppQ.WhenDate, @D10-)), '') & ',' & |
           CHOOSE(SELF.SuppQ.WhenTime > 0, CLIP(FORMAT(SELF.SuppQ.WhenTime, @T4)), '')
    text = CLIP(text) & ',' & SELF.Csv(SELF.SuppQ.Sender) & '<13,10>'
    line[1 : LEN(CLIP(text))] = text
    ETA_WriteFile(hFile, line, LEN(CLIP(text)), wrote, 0)
  END
  ETA_CloseHandle(hFile)
  DISPOSE(line)
  SELF.SetErr(ETApi:Ok)
  RETURN RECORDS(SELF.SuppQ)

!  One CSV field.  A bounce reason routinely contains a comma and sometimes a
!  quote, so quoting is not optional.
EmailApiClass.Csv PROCEDURE(STRING pText)
i LONG
n LONG
  CODE
  SELF.TxtBuf.ClearAll()
  SELF.TxtBuf.Add('"')
  n = LEN(CLIP(pText))
  LOOP i = 1 TO n
    IF pText[i] = '"'
      SELF.TxtBuf.Add('""')
    ELSIF VAL(pText[i]) < 32
      SELF.TxtBuf.Add(' ')
    ELSE
      SELF.TxtBuf.Add(pText[i])
    END
  END
  SELF.TxtBuf.Add('"')
  RETURN SELF.TxtBuf.Value()

!  Anything the matrix has no row for.  The key, the headers and the base
!  address are still handled; read the answer from Net.Body(), or parse it
!  with the Json object this class already owns.
EmailApiClass.RawCall PROCEDURE(STRING pVerb,STRING pPath,<STRING pBody>)
url CSTRING(1025)
hdr CSTRING(1153)
  CODE
  IF SELF.Mailer &= NULL THEN RETURN SELF.SetErr(ETApi:NoObject).
  IF LOWER(SUB(CLIP(pPath), 1, 4)) = 'http'
    url = SUB(SELF.Expand(pPath), 1, 1024)
  ELSIF SUB(CLIP(pPath), 1, 1) = '/'
    url = SUB(SELF.Expand('{{scheme}{{host}' & CLIP(pPath)), 1, 1024)
  ELSE
    url = SUB(SELF.Expand('{{scheme}{{host}/' & CLIP(pPath)), 1, 1024)
  END
  SELF.LastUrl = SUB(url, 1, 512)
  SELF.Net.Trace      = SELF.Mailer.Trace
  SELF.Net.VerifyCert = SELF.Mailer.Acc.VerifyCert
  IF NOT OMITTED(pBody)
    hdr = SUB(SELF.SignedHeaders(0, pVerb, url, pBody), 1, 1024)
  ELSE
    hdr = SUB(SELF.SignedHeaders(0, pVerb, url, ''), 1, 1024)
  END
  IF NOT OMITTED(pBody)
    hdr = CLIP(hdr) & '<13,10>Content-Type: application/json'
    SELF.LastStatus = SELF.Net.Http(pVerb, url, hdr, pBody)
  ELSE
    SELF.LastStatus = SELF.Net.Http(pVerb, url, hdr, '')
  END
  IF SELF.LastStatus < 200
    SELF.SetErr(ETApi:Http)
  ELSIF SELF.LastStatus > 299
    SELF.SetErr(ETApi:Refused, SELF.FailedText())
  ELSE
    SELF.SetErr(ETApi:Ok)
  END
  RETURN SELF.LastStatus

! ============================================================================
!  Wording
!
!  Identifiers, JSON member names and the matrix stay English - they are the
!  providers' own, and translating them would break them.  Only what a person
!  reads is translated.
! ============================================================================
EmailApiClass.Txt PROCEDURE(LONG pId)
  CODE
  IF SELF.Language = ETLng:Spanish
    CASE pId
    OF ETATxt:Manage     ; RETURN 'Cuenta de correo'
    OF ETATxt:Account    ; RETURN 'Cuenta'
    OF ETATxt:Blocked    ; RETURN 'Bloqueados'
    OF ETATxt:Statistics ; RETURN 'Estad<237>sticas'
    OF ETATxt:Activity   ; RETURN 'Actividad'
    OF ETATxt:Contacts   ; RETURN 'Contactos'
    OF ETATxt:Lists      ; RETURN 'Listas'
    OF ETATxt:Campaigns  ; RETURN 'Campa<241>as'
    OF ETATxt:Templates  ; RETURN 'Plantillas'
    OF ETATxt:Senders    ; RETURN 'Remitentes'
    OF ETATxt:Domains    ; RETURN 'Dominios'
    OF ETATxt:Webhooks   ; RETURN 'Webhooks'
    OF ETATxt:Refresh    ; RETURN '&Actualizar'
    OF ETATxt:Address    ; RETURN 'Direcci<243>n'
    OF ETATxt:Kind       ; RETURN 'Tipo'
    OF ETATxt:Reason     ; RETURN 'Motivo'
    OF ETATxt:When       ; RETURN 'Fecha'
    OF ETATxt:Code       ; RETURN 'C<243>digo'
    OF ETATxt:Unblock    ; RETURN '&Desbloquear'
    OF ETATxt:UnblockAll ; RETURN 'Desbloquear &todos'
    OF ETATxt:Block      ; RETURN '&Bloquear...'
    OF ETATxt:Close      ; RETURN 'Cerrar'
    OF ETATxt:Working    ; RETURN 'Consultando al proveedor...'
    OF ETATxt:NoRows     ; RETURN 'No hay nada que mostrar.'
    OF ETATxt:Rows       ; RETURN 'filas'
    OF ETATxt:Confirm    ; RETURN '<191>Desbloquear esta direcci<243>n?'
    OF ETATxt:ConfirmAll ; RETURN '<191>Desbloquear TODAS las direcciones de esta lista?'
    OF ETATxt:Done       ; RETURN 'Hecho.'
    OF ETATxt:NotSupport ; RETURN 'Este proveedor no ofrece esa operaci<243>n en su API.'
    OF ETATxt:Name       ; RETURN 'Nombre'
    OF ETATxt:Subject    ; RETURN 'Asunto'
    OF ETATxt:Status     ; RETURN 'Estado'
    OF ETATxt:Members    ; RETURN 'Miembros'
    OF ETATxt:Sent       ; RETURN 'Enviados'
    OF ETATxt:Opens      ; RETURN 'Aperturas'
    OF ETATxt:Clicks     ; RETURN 'Clics'
    OF ETATxt:Bounces    ; RETURN 'Rebotes'
    OF ETATxt:Spam       ; RETURN 'Spam'
    OF ETATxt:Unsubs     ; RETURN 'Bajas'
    OF ETATxt:Delivered  ; RETURN 'Entregados'
    OF ETATxt:Requests   ; RETURN 'Solicitados'
    OF ETATxt:From       ; RETURN 'Desde'
    OF ETATxt:To         ; RETURN 'Hasta'
    OF ETATxt:Send       ; RETURN '&Enviar'
    OF ETATxt:Verified   ; RETURN 'Verificado'
    OF ETATxt:Url        ; RETURN 'Direcci<243>n web'
    OF ETATxt:Events     ; RETURN 'Eventos'
    OF ETATxt:Export     ; RETURN 'E&xportar CSV...'
    OF ETATxt:Exported   ; RETURN 'Exportado.'
    OF ETATxt:Plan       ; RETURN 'Plan'
    OF ETATxt:Credits    ; RETURN 'Cr<233>ditos'
    OF ETATxt:Reputation ; RETURN 'Reputaci<243>n'
    OF ETATxt:Company    ; RETURN 'Empresa'
    OF ETATxt:Provider   ; RETURN 'Proveedor'
    OF ETATxt:AddContact ; RETURN 'A<241>adir...'
    OF ETATxt:Delete     ; RETURN 'Elimina&r'
    OF ETATxt:Raw        ; RETURN 'Respuesta del proveedor'
    OF ETATxt:Kinds      ; RETURN 'Mostrar:'
    OF ETATxt:Search     ; RETURN 'Buscar:'
    OF ETATxt:AllKinds   ; RETURN 'Todo'
    END
    RETURN ''
  END
  CASE pId
  OF ETATxt:Manage     ; RETURN 'Mail account'
  OF ETATxt:Account    ; RETURN 'Account'
  OF ETATxt:Blocked    ; RETURN 'Blocked'
  OF ETATxt:Statistics ; RETURN 'Statistics'
  OF ETATxt:Activity   ; RETURN 'Activity'
  OF ETATxt:Contacts   ; RETURN 'Contacts'
  OF ETATxt:Lists      ; RETURN 'Lists'
  OF ETATxt:Campaigns  ; RETURN 'Campaigns'
  OF ETATxt:Templates  ; RETURN 'Templates'
  OF ETATxt:Senders    ; RETURN 'Senders'
  OF ETATxt:Domains    ; RETURN 'Domains'
  OF ETATxt:Webhooks   ; RETURN 'Webhooks'
  OF ETATxt:Refresh    ; RETURN '&Refresh'
  OF ETATxt:Address    ; RETURN 'Address'
  OF ETATxt:Kind       ; RETURN 'Kind'
  OF ETATxt:Reason     ; RETURN 'Reason'
  OF ETATxt:When       ; RETURN 'When'
  OF ETATxt:Code       ; RETURN 'Code'
  OF ETATxt:Unblock    ; RETURN '&Unblock'
  OF ETATxt:UnblockAll ; RETURN 'Unblock &all'
  OF ETATxt:Block      ; RETURN '&Block...'
  OF ETATxt:Close      ; RETURN 'Close'
  OF ETATxt:Working    ; RETURN 'Asking the provider...'
  OF ETATxt:NoRows     ; RETURN 'Nothing to show.'
  OF ETATxt:Rows       ; RETURN 'rows'
  OF ETATxt:Confirm    ; RETURN 'Unblock this address?'
  OF ETATxt:ConfirmAll ; RETURN 'Unblock EVERY address on this list?'
  OF ETATxt:Done       ; RETURN 'Done.'
  OF ETATxt:NotSupport ; RETURN 'This provider does not offer that through its API.'
  OF ETATxt:Name       ; RETURN 'Name'
  OF ETATxt:Subject    ; RETURN 'Subject'
  OF ETATxt:Status     ; RETURN 'Status'
  OF ETATxt:Members    ; RETURN 'Members'
  OF ETATxt:Sent       ; RETURN 'Sent'
  OF ETATxt:Opens      ; RETURN 'Opens'
  OF ETATxt:Clicks     ; RETURN 'Clicks'
  OF ETATxt:Bounces    ; RETURN 'Bounces'
  OF ETATxt:Spam       ; RETURN 'Spam'
  OF ETATxt:Unsubs     ; RETURN 'Unsubs'
  OF ETATxt:Delivered  ; RETURN 'Delivered'
  OF ETATxt:Requests   ; RETURN 'Requested'
  OF ETATxt:From       ; RETURN 'From'
  OF ETATxt:To         ; RETURN 'To'
  OF ETATxt:Send       ; RETURN '&Send'
  OF ETATxt:Verified   ; RETURN 'Verified'
  OF ETATxt:Url        ; RETURN 'Address'
  OF ETATxt:Events     ; RETURN 'Events'
  OF ETATxt:Export     ; RETURN 'E&xport CSV...'
  OF ETATxt:Exported   ; RETURN 'Exported.'
  OF ETATxt:Plan       ; RETURN 'Plan'
  OF ETATxt:Credits    ; RETURN 'Credits'
  OF ETATxt:Reputation ; RETURN 'Reputation'
  OF ETATxt:Company    ; RETURN 'Company'
  OF ETATxt:Provider   ; RETURN 'Provider'
  OF ETATxt:AddContact ; RETURN 'A&dd...'
  OF ETATxt:Delete     ; RETURN 'Delete'
  OF ETATxt:Raw        ; RETURN 'What the provider sent'
  OF ETATxt:Kinds      ; RETURN 'Show:'
  OF ETATxt:Search     ; RETURN 'Find:'
  OF ETATxt:AllKinds   ; RETURN 'Everything'
  END
  RETURN ''

! ============================================================================
!  The management window
!
!  One window over every provider.  A tab whose operation this provider does
!  not offer is DISABLED rather than empty, so the difference between "there
!  is nothing there" and "this provider cannot answer that" is visible before
!  anybody presses anything.
!
!  Every LIST binds to a REAL queue declared here, never to the class's queue
!  reference: FROM(<a queue reference>) compiles and then faults on the first
!  paint.  So each Load routine copies across, which is also where the raw
!  values are turned into something a person can read.
! ============================================================================
EmailApiClass.Manage PROCEDURE(BYTE pTab)
LocStatus   CSTRING(200)
LocProvider CSTRING(200)
LocKindTxt  CSTRING(33)
LocFind     CSTRING(65)
LocFrom     DATE
LocTo       DATE
LocListSel  CSTRING(129)
LocListId   CSTRING(129)
LocAsk      CSTRING(256)
LocAskTitle CSTRING(129)
LocDetail   CSTRING(1400)
LocFromStr  CSTRING(2049)
LocVPrv     CSTRING(129)
LocVName    CSTRING(129)
LocVCo      CSTRING(129)
LocVAddr    CSTRING(256)
LocVPlan    CSTRING(65)
LocVCred    CSTRING(21)
LocVRep     CSTRING(21)
LocVStat    CSTRING(65)
i           LONG
n           LONG
k           BYTE
sel         LONG
feq         LONG
ok          BYTE

BlkQ  QUEUE
BAddr   STRING(120)
BKind   STRING(20)
BReason STRING(200)
BWhen   STRING(20)
BRow    LONG                                        ! which SuppQ entry this row came from
      END
StQ   QUEUE
SDate   STRING(12)
SReq    STRING(10)
SDlv    STRING(10)
SOpn    STRING(10)
SClk    STRING(10)
SBnc    STRING(10)
SSpm    STRING(10)
SUns    STRING(10)
      END
EvQ   QUEUE
EWhen   STRING(20)
EAddr   STRING(120)
EEvent  STRING(24)
EReason STRING(160)
ESubj   STRING(120)
      END
CtQ   QUEUE
CAddr   STRING(120)
CName   STRING(60)
CFlag   STRING(24)
CWhen   STRING(12)
CId     STRING(64)
      END
LsQ   QUEUE
LName   STRING(80)
LCount  STRING(10)
LId     STRING(64)
      END
CpQ   QUEUE
PName   STRING(80)
PSubj   STRING(100)
PStat   STRING(24)
PWhen   STRING(20)
PId     STRING(64)
      END
TpQ   QUEUE
TName   STRING(80)
TSubj   STRING(100)
TId     STRING(64)
      END
SdQ   QUEUE
DAddr   STRING(120)
DName   STRING(60)
DVer    STRING(20)
      END
DmQ   QUEUE
MName   STRING(100)
MVer    STRING(20)
MStat   STRING(40)
      END
WhQ   QUEUE
HUrl    STRING(180)
HEvents STRING(60)
HId     STRING(64)
      END

Win WINDOW('Mail account'),AT(,,520,332),GRAY,SYSTEM,FONT('Segoe UI',9),CENTER,ICON(ICON:Application)
      STRING(@s199),AT(8,6,380,10),USE(LocProvider),FONT(,10,,FONT:bold)
      BUTTON('&Refresh'),AT(456,4,56,14),USE(?Refresh)
      SHEET,AT(4,20,512,288),USE(?Sheet),SPREAD
        TAB('Account'),USE(?TabAccount)
          PROMPT('Provider:'),AT(14,40),USE(?PrPrv)
          STRING(@s128),AT(90,40,300,10),USE(LocVPrv)
          PROMPT('Name:'),AT(14,54),USE(?PrName)
          STRING(@s128),AT(90,54,300,10),USE(LocVName)
          PROMPT('Company:'),AT(14,68),USE(?PrCo)
          STRING(@s128),AT(90,68,300,10),USE(LocVCo)
          PROMPT('Address:'),AT(14,82),USE(?PrAddr)
          STRING(@s255),AT(90,82,400,10),USE(LocVAddr)
          PROMPT('Plan:'),AT(14,96),USE(?PrPlan)
          STRING(@s64),AT(90,96,200,10),USE(LocVPlan)
          PROMPT('Credits:'),AT(14,110),USE(?PrCred)
          STRING(@s20),AT(90,110,100,10),USE(LocVCred)
          PROMPT('Reputation:'),AT(14,124),USE(?PrRep)
          STRING(@s20),AT(90,124,100,10),USE(LocVRep)
          PROMPT('Status:'),AT(14,138),USE(?PrStat)
          STRING(@s64),AT(90,138,200,10),USE(LocVStat)
          GROUP('What the provider sent'),AT(10,156,500,142),USE(?GrpRaw),BOXED
            TEXT,AT(16,168,488,124),USE(LocDetail),VSCROLL,HSCROLL,READONLY,FONT('Consolas',8)
          END
        END
        TAB('Blocked'),USE(?TabBlocked)
          PROMPT('Show:'),AT(12,38),USE(?PrKind)
          LIST,AT(42,36,110,10),USE(LocKindTxt),DROP(8),FROM(' ')
          PROMPT('Find:'),AT(168,38),USE(?PrFind)
          ENTRY(@s64),AT(190,36,120,10),USE(LocFind)
          BUTTON('&Unblock'),AT(320,34,60,14),USE(?Unblock)
          BUTTON('Unblock &all'),AT(384,34,64,14),USE(?UnblockAll)
          BUTTON('&Block...'),AT(452,34,60,14),USE(?BlockOne)
          LIST,AT(10,52,500,182),USE(?BlkList),FROM(BlkQ),VSCROLL,|
               FORMAT('120L(2)|M~Address~@s120@60L(2)|M~Kind~@s20@200L(2)|M~Reason~@s200@' & |
                      '70L(2)|M~When~@s20@')
          GROUP('Reason'),AT(10,240,500,58),USE(?GrpWhy),BOXED
            TEXT,AT(16,250,430,42),USE(LocDetail,,?DetailBlk),VSCROLL,READONLY,FONT('Consolas',8)
            BUTTON('E&xport CSV...'),AT(452,250,56,14),USE(?Export)
          END
        END
        TAB('Statistics'),USE(?TabStats)
          PROMPT('From:'),AT(12,38),USE(?PrFrom)
          ENTRY(@d10-),AT(38,36,60,10),USE(LocFrom)
          PROMPT('To:'),AT(108,38),USE(?PrTo)
          ENTRY(@d10-),AT(126,36,60,10),USE(LocTo)
          LIST,AT(10,52,500,246),USE(?StatList),FROM(StQ),VSCROLL,|
               FORMAT('60L(2)|M~Date~@s12@56R(2)|M~Requested~@s10@56R(2)|M~Delivered~@s10@' & |
                      '46R(2)|M~Opens~@s10@46R(2)|M~Clicks~@s10@50R(2)|M~Bounces~@s10@' & |
                      '46R(2)|M~Spam~@s10@50R(2)|M~Unsubs~@s10@')
        END
        TAB('Activity'),USE(?TabEvents)
          LIST,AT(10,36,500,262),USE(?EventList),FROM(EvQ),VSCROLL,|
               FORMAT('70L(2)|M~When~@s20@120L(2)|M~Address~@s120@50L(2)|M~Event~@s24@' & |
                      '130L(2)|M~Reason~@s160@110L(2)|M~Subject~@s120@')
        END
        TAB('Contacts'),USE(?TabContacts)
          PROMPT('List:'),AT(12,38),USE(?PrList)
          LIST,AT(34,36,160,10),USE(LocListSel),DROP(10),FROM(' ')
          BUTTON('A&dd...'),AT(400,34,52,14),USE(?AddContact)
          BUTTON('Delete'),AT(456,34,52,14),USE(?DelContact)
          LIST,AT(10,52,500,246),USE(?ContactList),FROM(CtQ),VSCROLL,|
               FORMAT('160L(2)|M~Address~@s120@100L(2)|M~Name~@s60@60L(2)|M~State~@s24@' & |
                      '60L(2)|M~Added~@s12@')
        END
        TAB('Lists'),USE(?TabLists)
          BUTTON('A&dd...'),AT(456,34,52,14),USE(?AddList)
          LIST,AT(10,52,500,246),USE(?ListList),FROM(LsQ),VSCROLL,|
               FORMAT('220L(2)|M~Name~@s80@60R(2)|M~Members~@s10@120L(2)|M~Id~@s64@')
        END
        TAB('Campaigns'),USE(?TabCampaigns)
          BUTTON('&Send now'),AT(440,34,68,14),USE(?SendCampaign)
          LIST,AT(10,52,500,246),USE(?CampaignList),FROM(CpQ),VSCROLL,|
               FORMAT('130L(2)|M~Name~@s80@150L(2)|M~Subject~@s100@60L(2)|M~Status~@s24@' & |
                      '70L(2)|M~When~@s20@80L(2)|M~Id~@s64@')
        END
        TAB('Templates'),USE(?TabTemplates)
          LIST,AT(10,36,500,262),USE(?TemplateList),FROM(TpQ),VSCROLL,|
               FORMAT('160L(2)|M~Name~@s80@200L(2)|M~Subject~@s100@110L(2)|M~Id~@s64@')
        END
        TAB('Senders'),USE(?TabSenders)
          LIST,AT(10,36,500,130),USE(?SenderList),FROM(SdQ),VSCROLL,|
               FORMAT('200L(2)|M~Address~@s120@140L(2)|M~Name~@s60@70L(2)|M~Verified~@s20@')
          LIST,AT(10,170,500,128),USE(?DomainList),FROM(DmQ),VSCROLL,|
               FORMAT('200L(2)|M~Domain~@s100@70L(2)|M~Verified~@s20@120L(2)|M~Status~@s40@')
        END
        TAB('Webhooks'),USE(?TabWebhooks)
          BUTTON('Delete'),AT(456,34,52,14),USE(?DelHook)
          LIST,AT(10,52,500,246),USE(?HookList),FROM(WhQ),VSCROLL,|
               FORMAT('280L(2)|M~Address~@s180@100L(2)|M~Events~@s60@100L(2)|M~Id~@s64@')
        END
      END
      STRING(@s199),AT(8,314,420,10),USE(LocStatus),FONT(,8)
      BUTTON('Close'),AT(462,312,50,14),USE(?CloseBtn),STD(STD:Close)
    END

Ask WINDOW('Address'),AT(,,220,66),GRAY,SYSTEM,FONT('Segoe UI',9),CENTER
      STRING(@s128),AT(10,8,200,10),USE(LocAskTitle)
      ENTRY(@s255),AT(10,24,200,10),USE(LocAsk)
      BUTTON('OK'),AT(102,44,50,14),USE(?AskOk),DEFAULT
      BUTTON('Cancel'),AT(158,44,50,14),USE(?AskCancel)
    END

  CODE
  IF SELF.Mailer &= NULL
    SELF.SetErr(ETApi:NoObject)
    SELF.ShowError()
    RETURN 0
  END
  LocFrom = TODAY() - 30
  LocTo   = TODAY()
  OPEN(Win)
  Win{PROP:Text} = SELF.Txt(ETATxt:Manage)
  DO NameEverything
  DO NameColumns
  DO ShowCapability
  LocProvider = CLIP(SELF.Mailer.ProviderName(SELF.Mailer.Acc.Provider)) & '   -   ' & |
                CLIP(SELF.Mailer.Acc.FromAddr)
  DO PickTab
  DISPLAY()
  DO LoadCurrent

  ACCEPT
    CASE EVENT()
    OF EVENT:CloseWindow
      BREAK
    END
    CASE FIELD()
    OF ?Sheet
      IF EVENT() = EVENT:NewSelection THEN DO LoadCurrent.
    OF ?Refresh
      IF EVENT() = EVENT:Accepted THEN DO LoadCurrent.
    OF ?LocKindTxt
      IF EVENT() = EVENT:Accepted THEN DO LoadBlocks.
    OF ?LocFind
      IF EVENT() = EVENT:Accepted THEN DO FillBlocks.
    OF ?BlkList
      IF EVENT() = EVENT:NewSelection THEN DO ShowWhy.
    OF ?Unblock
      IF EVENT() = EVENT:Accepted THEN DO DoUnblock.
    OF ?UnblockAll
      IF EVENT() = EVENT:Accepted THEN DO DoUnblockAll.
    OF ?BlockOne
      IF EVENT() = EVENT:Accepted THEN DO DoBlock.
    OF ?Export
      IF EVENT() = EVENT:Accepted THEN DO DoExport.
    OF ?LocListSel
      IF EVENT() = EVENT:Accepted THEN DO PickList.
    OF ?AddContact
      IF EVENT() = EVENT:Accepted THEN DO DoAddContact.
    OF ?DelContact
      IF EVENT() = EVENT:Accepted THEN DO DoDelContact.
    OF ?AddList
      IF EVENT() = EVENT:Accepted THEN DO DoAddList.
    OF ?SendCampaign
      IF EVENT() = EVENT:Accepted THEN DO DoSendCampaign.
    OF ?DelHook
      IF EVENT() = EVENT:Accepted THEN DO DoDelHook.
    OF ?LocFrom
      IF EVENT() = EVENT:Accepted THEN DO LoadStats.
    OF ?LocTo
      IF EVENT() = EVENT:Accepted THEN DO LoadStats.
    OF ?CloseBtn
      IF EVENT() = EVENT:Accepted THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)
  RETURN 1

!---- wording -----------------------------------------------------------------
NameEverything ROUTINE
  ?Refresh{PROP:Text}      = SELF.Txt(ETATxt:Refresh)
  ?TabAccount{PROP:Text}   = SELF.Txt(ETATxt:Account)
  ?TabBlocked{PROP:Text}   = SELF.Txt(ETATxt:Blocked)
  ?TabStats{PROP:Text}     = SELF.Txt(ETATxt:Statistics)
  ?TabEvents{PROP:Text}    = SELF.Txt(ETATxt:Activity)
  ?TabContacts{PROP:Text}  = SELF.Txt(ETATxt:Contacts)
  ?TabLists{PROP:Text}     = SELF.Txt(ETATxt:Lists)
  ?TabCampaigns{PROP:Text} = SELF.Txt(ETATxt:Campaigns)
  ?TabTemplates{PROP:Text} = SELF.Txt(ETATxt:Templates)
  ?TabSenders{PROP:Text}   = SELF.Txt(ETATxt:Senders)
  ?TabWebhooks{PROP:Text}  = SELF.Txt(ETATxt:Webhooks)
  ?PrPrv{PROP:Text}        = CLIP(SELF.Txt(ETATxt:Provider)) & ':'
  ?PrName{PROP:Text}       = CLIP(SELF.Txt(ETATxt:Name)) & ':'
  ?PrCo{PROP:Text}         = CLIP(SELF.Txt(ETATxt:Company)) & ':'
  ?PrAddr{PROP:Text}       = CLIP(SELF.Txt(ETATxt:Address)) & ':'
  ?PrPlan{PROP:Text}       = CLIP(SELF.Txt(ETATxt:Plan)) & ':'
  ?PrCred{PROP:Text}       = CLIP(SELF.Txt(ETATxt:Credits)) & ':'
  ?PrRep{PROP:Text}        = CLIP(SELF.Txt(ETATxt:Reputation)) & ':'
  ?PrStat{PROP:Text}       = CLIP(SELF.Txt(ETATxt:Status)) & ':'
  ?GrpRaw{PROP:Text}       = SELF.Txt(ETATxt:Raw)
  ?GrpWhy{PROP:Text}       = SELF.Txt(ETATxt:Reason)
  ?PrKind{PROP:Text}       = SELF.Txt(ETATxt:Kinds)
  ?PrFind{PROP:Text}       = SELF.Txt(ETATxt:Search)
  ?Unblock{PROP:Text}      = SELF.Txt(ETATxt:Unblock)
  ?UnblockAll{PROP:Text}   = SELF.Txt(ETATxt:UnblockAll)
  ?BlockOne{PROP:Text}     = SELF.Txt(ETATxt:Block)
  ?Export{PROP:Text}       = SELF.Txt(ETATxt:Export)
  ?PrFrom{PROP:Text}       = CLIP(SELF.Txt(ETATxt:From)) & ':'
  ?PrTo{PROP:Text}         = CLIP(SELF.Txt(ETATxt:To)) & ':'
  ?PrList{PROP:Text}       = CLIP(SELF.Txt(ETATxt:Lists)) & ':'
  ?AddContact{PROP:Text}   = SELF.Txt(ETATxt:AddContact)
  ?AddList{PROP:Text}      = SELF.Txt(ETATxt:AddContact)
  ?DelContact{PROP:Text}   = SELF.Txt(ETATxt:Delete)
  ?DelHook{PROP:Text}      = SELF.Txt(ETATxt:Delete)
  ?SendCampaign{PROP:Text} = SELF.Txt(ETATxt:Send)
  ?CloseBtn{PROP:Text}     = SELF.Txt(ETATxt:Close)
  !  A drop list cannot be built from a variable at design time, so the
  !  choices are made here - once the window is open and the language is
  !  known.  The order matters: entry 1 is "everything", and after that the
  !  entry number IS the ETSup: kind.
  ?LocKindTxt{PROP:From} = CLIP(SELF.Txt(ETATxt:AllKinds)) & '|' & |
                           CLIP(SELF.SuppKindName(ETSup:Bounce))  & '|' & |
                           CLIP(SELF.SuppKindName(ETSup:Block))   & '|' & |
                           CLIP(SELF.SuppKindName(ETSup:Spam))    & '|' & |
                           CLIP(SELF.SuppKindName(ETSup:Unsub))   & '|' & |
                           CLIP(SELF.SuppKindName(ETSup:Invalid))
  LocKindTxt = SELF.Txt(ETATxt:AllKinds)
  ?LocListSel{PROP:From} = SELF.Txt(ETATxt:AllKinds)
  LocListSel = SELF.Txt(ETATxt:AllKinds)

!  The headings are the one part of this window that a FORMAT string owns, and
!  a FORMAT string is fixed at design time - so everything else here answered in
!  the user's language while nine lists went on saying Address, Kind, Reason.
!  They are set by column number, once, from the same table as the rest.
NameColumns ROUTINE
  ?BlkList{PROPLIST:Header, 1}      = SELF.Txt(ETATxt:Address)
  ?BlkList{PROPLIST:Header, 2}      = SELF.Txt(ETATxt:Kind)
  ?BlkList{PROPLIST:Header, 3}      = SELF.Txt(ETATxt:Reason)
  ?BlkList{PROPLIST:Header, 4}      = SELF.Txt(ETATxt:When)
  ?StatList{PROPLIST:Header, 1}     = SELF.Txt(ETATxt:When)
  ?StatList{PROPLIST:Header, 2}     = SELF.Txt(ETATxt:Requests)
  ?StatList{PROPLIST:Header, 3}     = SELF.Txt(ETATxt:Delivered)
  ?StatList{PROPLIST:Header, 4}     = SELF.Txt(ETATxt:Opens)
  ?StatList{PROPLIST:Header, 5}     = SELF.Txt(ETATxt:Clicks)
  ?StatList{PROPLIST:Header, 6}     = SELF.Txt(ETATxt:Bounces)
  ?StatList{PROPLIST:Header, 7}     = SELF.Txt(ETATxt:Spam)
  ?StatList{PROPLIST:Header, 8}     = SELF.Txt(ETATxt:Unsubs)
  ?EventList{PROPLIST:Header, 1}    = SELF.Txt(ETATxt:When)
  ?EventList{PROPLIST:Header, 2}    = SELF.Txt(ETATxt:Address)
  ?EventList{PROPLIST:Header, 3}    = SELF.Txt(ETATxt:Events)
  ?EventList{PROPLIST:Header, 4}    = SELF.Txt(ETATxt:Reason)
  ?EventList{PROPLIST:Header, 5}    = SELF.Txt(ETATxt:Subject)
  ?ContactList{PROPLIST:Header, 1}  = SELF.Txt(ETATxt:Address)
  ?ContactList{PROPLIST:Header, 2}  = SELF.Txt(ETATxt:Name)
  ?ContactList{PROPLIST:Header, 3}  = SELF.Txt(ETATxt:Status)
  ?ContactList{PROPLIST:Header, 4}  = SELF.Txt(ETATxt:When)
  ?ListList{PROPLIST:Header, 1}     = SELF.Txt(ETATxt:Name)
  ?ListList{PROPLIST:Header, 2}     = SELF.Txt(ETATxt:Members)
  ?CampaignList{PROPLIST:Header, 1} = SELF.Txt(ETATxt:Name)
  ?CampaignList{PROPLIST:Header, 2} = SELF.Txt(ETATxt:Subject)
  ?CampaignList{PROPLIST:Header, 3} = SELF.Txt(ETATxt:Status)
  ?CampaignList{PROPLIST:Header, 4} = SELF.Txt(ETATxt:When)
  ?TemplateList{PROPLIST:Header, 1} = SELF.Txt(ETATxt:Name)
  ?TemplateList{PROPLIST:Header, 2} = SELF.Txt(ETATxt:Subject)
  ?SenderList{PROPLIST:Header, 1}   = SELF.Txt(ETATxt:Address)
  ?SenderList{PROPLIST:Header, 2}   = SELF.Txt(ETATxt:Name)
  ?SenderList{PROPLIST:Header, 3}   = SELF.Txt(ETATxt:Verified)
  ?DomainList{PROPLIST:Header, 1}   = SELF.Txt(ETATxt:Domains)
  ?DomainList{PROPLIST:Header, 2}   = SELF.Txt(ETATxt:Verified)
  ?DomainList{PROPLIST:Header, 3}   = SELF.Txt(ETATxt:Status)
  ?HookList{PROPLIST:Header, 1}     = SELF.Txt(ETATxt:Url)
  ?HookList{PROPLIST:Header, 2}     = SELF.Txt(ETATxt:Events)

!  A tab whose operation this provider does not have is switched off.  That is
!  what Supports() is for: the difference between "no rows" and "not offered"
!  should be visible before anybody presses Refresh.
ShowCapability ROUTINE
  ?TabAccount{PROP:Disable}   = CHOOSE(SELF.Supports(ETOp:Account) = 0, 1, 0)
  ?TabBlocked{PROP:Disable}   = CHOOSE(SELF.Supports(ETOp:Suppressions) = 0, 1, 0)
  ?TabStats{PROP:Disable}     = CHOOSE(SELF.Supports(ETOp:Stats) = 0, 1, 0)
  ?TabEvents{PROP:Disable}    = CHOOSE(SELF.Supports(ETOp:Events) = 0, 1, 0)
  ?TabContacts{PROP:Disable}  = 1
  IF SELF.Supports(ETOp:Contacts) OR SELF.Supports(ETOp:ListMembers)
    ?TabContacts{PROP:Disable} = 0
  END
  ?TabLists{PROP:Disable}     = CHOOSE(SELF.Supports(ETOp:Lists) = 0, 1, 0)
  ?TabCampaigns{PROP:Disable} = CHOOSE(SELF.Supports(ETOp:Campaigns) = 0, 1, 0)
  ?TabTemplates{PROP:Disable} = CHOOSE(SELF.Supports(ETOp:Templates) = 0, 1, 0)
  ?TabSenders{PROP:Disable}   = 1
  IF SELF.Supports(ETOp:Senders) OR SELF.Supports(ETOp:Domains)
    ?TabSenders{PROP:Disable} = 0
  END
  ?TabWebhooks{PROP:Disable}  = CHOOSE(SELF.Supports(ETOp:Webhooks) = 0, 1, 0)
  ?Unblock{PROP:Disable}      = CHOOSE(SELF.Supports(ETOp:SuppDelete) = 0, 1, 0)
  ?UnblockAll{PROP:Disable}   = CHOOSE(SELF.Supports(ETOp:SuppDeleteAll) = 0, 1, 0)
  ?BlockOne{PROP:Disable}     = CHOOSE(SELF.Supports(ETOp:SuppAdd) = 0, 1, 0)
  ?AddContact{PROP:Disable}   = 1
  IF SELF.Supports(ETOp:ContactAdd, 0) OR SELF.Supports(ETOp:ContactAdd, 1)
    ?AddContact{PROP:Disable} = 0
  END
  ?DelContact{PROP:Disable}   = CHOOSE(SELF.Supports(ETOp:ContactDelete) = 0, 1, 0)
  ?AddList{PROP:Disable}      = CHOOSE(SELF.Supports(ETOp:ListAdd) = 0, 1, 0)
  ?SendCampaign{PROP:Disable} = CHOOSE(SELF.Supports(ETOp:CampaignSend) = 0, 1, 0)
  ?DelHook{PROP:Disable}      = CHOOSE(SELF.Supports(ETOp:WebhookDelete) = 0, 1, 0)

TabFeq ROUTINE
  CASE sel
  OF 1  ; feq = ?TabAccount
  OF 2  ; feq = ?TabBlocked
  OF 3  ; feq = ?TabStats
  OF 4  ; feq = ?TabEvents
  OF 5  ; feq = ?TabContacts
  OF 6  ; feq = ?TabLists
  OF 7  ; feq = ?TabCampaigns
  OF 8  ; feq = ?TabTemplates
  OF 9  ; feq = ?TabSenders
  ELSE  ; feq = ?TabWebhooks
  END

!  Land on a tab the provider can actually answer.
PickTab ROUTINE
  sel = pTab
  IF sel < 1 OR sel > 10 THEN sel = 1.
  LOOP k = 1 TO 10
    DO TabFeq
    IF NOT feq{PROP:Disable}
      SELECT(feq)
      EXIT
    END
    sel = sel % 10 + 1
  END

!---- loading -----------------------------------------------------------------
LoadCurrent ROUTINE
  CASE CHOICE(?Sheet)
  OF 1  ; DO LoadAccount
  OF 2  ; DO LoadBlocks
  OF 3  ; DO LoadStats
  OF 4  ; DO LoadEvents
  OF 5  ; DO LoadLists ; DO LoadContacts
  OF 6  ; DO LoadLists
  OF 7  ; DO LoadCampaigns
  OF 8  ; DO LoadTemplates
  OF 9  ; DO LoadSenders
  OF 10 ; DO LoadHooks
  END

Working ROUTINE
  LocStatus = SELF.Txt(ETATxt:Working)
  DISPLAY(?LocStatus)
  SETCURSOR(CURSOR:Wait)

Rested ROUTINE
  SETCURSOR()

Told ROUTINE
  IF SELF.LastError
    LocStatus = CLIP(SELF.LastErrorText)
  ELSIF n < 1
    LocStatus = SELF.Txt(ETATxt:NoRows)
  ELSE
    LocStatus = n & ' ' & CLIP(SELF.Txt(ETATxt:Rows))
  END

LoadAccount ROUTINE
  DO Working
  ok = SELF.GetAccount()
  DO Rested
  LocVPrv  = CLIP(SELF.Mailer.ProviderName(SELF.Mailer.Acc.Provider))
  LocVName = CLIP(SELF.Account.Name)
  LocVCo   = CLIP(SELF.Account.Company)
  LocVAddr = CHOOSE(CLIP(SELF.Account.Address) <> '', CLIP(SELF.Account.Address), |
                    CLIP(SELF.Mailer.Acc.FromAddr))
  LocVPlan = CLIP(SELF.Account.Plan)
  LocVCred = CHOOSE(SELF.Account.Credits >= 0, '' & SELF.Account.Credits, '-')
  LocVRep  = CHOOSE(SELF.Account.Reputation > 0, '' & SELF.Account.Reputation, '-')
  LocVStat = CLIP(SELF.Account.Status)
  LocDetail = SUB(CLIP(SELF.Account.Raw), 1, 1399)
  IF ok
    LocStatus = ''
  ELSE
    LocStatus = CLIP(SELF.LastErrorText)
  END
  DISPLAY()

LoadBlocks ROUTINE
  k = CHOICE(?LocKindTxt) - 1                       ! entry 1 is "everything" = ETSup:All
  IF k < 0 THEN k = ETSup:All.
  DO Working
  n = SELF.GetSuppressions(k)
  DO Rested
  DO FillBlocks
  DO Told
  DISPLAY()

!  Copy into the display queue, applying whatever is typed in Find.  Filtering
!  here rather than at the provider makes it instant, and lets it search the
!  REASON as well as the address - which is what people actually look for.
FillBlocks ROUTINE
  FREE(BlkQ)
  LOOP i = 1 TO RECORDS(SELF.SuppQ)
    GET(SELF.SuppQ, i)
    IF CLIP(LocFind)
      IF NOT INSTRING(UPPER(CLIP(LocFind)), UPPER(CLIP(SELF.SuppQ.Address)), 1, 1)
        IF NOT INSTRING(UPPER(CLIP(LocFind)), UPPER(CLIP(SELF.SuppQ.Reason)), 1, 1)
          CYCLE
        END
      END
    END
    BlkQ.BAddr   = SELF.SuppQ.Address
    BlkQ.BKind   = SELF.SuppQ.KindName
    BlkQ.BReason = SELF.SuppQ.Reason
    IF SELF.SuppQ.WhenDate > 0
      BlkQ.BWhen = FORMAT(SELF.SuppQ.WhenDate, @D10-)
    ELSE
      BlkQ.BWhen = ''
    END
    BlkQ.BRow = i
    ADD(BlkQ)
  END
  n = RECORDS(BlkQ)
  DO ShowWhy
  DISPLAY(?BlkList)

!  The reason, in full.  A LIST column truncates a 200-character SMTP refusal,
!  and being able to read it is the whole point of the tab.
ShowWhy ROUTINE
  LocDetail = ''
  IF CHOICE(?Sheet) = 2 AND RECORDS(BlkQ)
    GET(BlkQ, CHOICE(?BlkList))
    IF NOT ERRORCODE()
      GET(SELF.SuppQ, BlkQ.BRow)
      IF NOT ERRORCODE()
        LocDetail = CLIP(SELF.SuppQ.Address) & '  (' & CLIP(SELF.SuppQ.KindName) & ')<13,10>' & |
                    CLIP(SELF.SuppQ.Reason)
        IF SELF.SuppQ.Code
          LocDetail = CLIP(LocDetail) & '<13,10>' & CLIP(SELF.Txt(ETATxt:Code)) & ': ' & |
                      SELF.SuppQ.Code
        END
        IF CLIP(SELF.SuppQ.Sender)
          LocDetail = CLIP(LocDetail) & '<13,10>' & CLIP(SELF.SuppQ.Sender)
        END
        IF CLIP(SELF.SuppQ.Raw)
          LocDetail = SUB(CLIP(LocDetail) & '<13,10><13,10>' & CLIP(SELF.SuppQ.Raw), 1, 1399)
        END
      END
    END
  END
  DISPLAY(?DetailBlk)

LoadStats ROUTINE
  DO Working
  n = SELF.GetStats(LocFrom, LocTo)
  DO Rested
  FREE(StQ)
  LOOP i = 1 TO RECORDS(SELF.StatQ)
    GET(SELF.StatQ, i)
    StQ.SDate = CHOOSE(SELF.StatQ.WhenDate > 0, CLIP(FORMAT(SELF.StatQ.WhenDate, @D10-)), '')
    StQ.SReq  = SELF.StatQ.Requests
    StQ.SDlv  = SELF.StatQ.Delivered
    StQ.SOpn  = SELF.StatQ.Opens
    StQ.SClk  = SELF.StatQ.Clicks
    StQ.SBnc  = SELF.StatQ.HardBounces + SELF.StatQ.SoftBounces
    StQ.SSpm  = SELF.StatQ.SpamReports
    StQ.SUns  = SELF.StatQ.Unsubscribed
    ADD(StQ)
  END
  DO Told
  DISPLAY()

LoadEvents ROUTINE
  DO Working
  n = SELF.GetEvents(TODAY() - 7, TODAY())
  DO Rested
  FREE(EvQ)
  LOOP i = 1 TO RECORDS(SELF.EventQ)
    GET(SELF.EventQ, i)
    IF SELF.EventQ.WhenDate > 0
      EvQ.EWhen = CLIP(FORMAT(SELF.EventQ.WhenDate, @D10-)) & ' ' & |
                  CLIP(FORMAT(SELF.EventQ.WhenTime, @T4))
    ELSE
      EvQ.EWhen = ''
    END
    EvQ.EAddr   = SELF.EventQ.Address
    EvQ.EEvent  = SELF.EventQ.EventName
    EvQ.EReason = SELF.EventQ.Reason
    EvQ.ESubj   = SELF.EventQ.Subject
    ADD(EvQ)
  END
  DO Told
  DISPLAY()

PickList ROUTINE
  LocListId = ''
  sel = CHOICE(?LocListSel) - 1                     ! entry 1 is "everything"
  IF sel >= 1
    GET(LsQ, sel)
    IF NOT ERRORCODE() THEN LocListId = CLIP(LsQ.LId).
  END
  DO LoadContacts

LoadContacts ROUTINE
  DO Working
  IF CLIP(LocListId)
    n = SELF.GetContacts(LocListId)
  ELSE
    n = SELF.GetContacts()
  END
  DO Rested
  FREE(CtQ)
  LOOP i = 1 TO RECORDS(SELF.ContactQ)
    GET(SELF.ContactQ, i)
    CtQ.CAddr = SELF.ContactQ.Address
    CtQ.CName = SELF.ContactQ.Name
    IF SELF.ContactQ.Blocked = 1
      CtQ.CFlag = SELF.SuppKindName(ETSup:Block)
    ELSIF SELF.ContactQ.Unsubscribed = 1
      CtQ.CFlag = SELF.SuppKindName(ETSup:Unsub)
    ELSE
      CtQ.CFlag = ''
    END
    CtQ.CWhen = CHOOSE(SELF.ContactQ.WhenDate > 0, |
                       CLIP(FORMAT(SELF.ContactQ.WhenDate, @D10-)), '')
    CtQ.CId   = SELF.ContactQ.Id
    ADD(CtQ)
  END
  DO Told
  DISPLAY()

LoadLists ROUTINE
  IF NOT SELF.Supports(ETOp:Lists) THEN EXIT.
  DO Working
  n = SELF.GetLists()
  DO Rested
  FREE(LsQ)
  LocFromStr = SELF.Txt(ETATxt:AllKinds)
  LOOP i = 1 TO RECORDS(SELF.ListQ)
    GET(SELF.ListQ, i)
    LsQ.LName  = SELF.ListQ.Name
    LsQ.LCount = SELF.ListQ.Members
    LsQ.LId    = SELF.ListQ.Id
    ADD(LsQ)
    LocFromStr = SUB(CLIP(LocFromStr) & '|' & CLIP(SELF.ListQ.Name), 1, 2048)
  END
  ?LocListSel{PROP:From} = LocFromStr
  DO Told
  DISPLAY()

LoadCampaigns ROUTINE
  DO Working
  n = SELF.GetCampaigns()
  DO Rested
  FREE(CpQ)
  LOOP i = 1 TO RECORDS(SELF.CampaignQ)
    GET(SELF.CampaignQ, i)
    CpQ.PName = SELF.CampaignQ.Name
    CpQ.PSubj = SELF.CampaignQ.Subject
    CpQ.PStat = SELF.CampaignQ.Status
    CpQ.PWhen = CHOOSE(SELF.CampaignQ.WhenDate > 0, |
                       CLIP(FORMAT(SELF.CampaignQ.WhenDate, @D10-)), '')
    CpQ.PId   = SELF.CampaignQ.Id
    ADD(CpQ)
  END
  DO Told
  DISPLAY()

LoadTemplates ROUTINE
  DO Working
  n = SELF.GetTemplates()
  DO Rested
  FREE(TpQ)
  LOOP i = 1 TO RECORDS(SELF.TemplateQ)
    GET(SELF.TemplateQ, i)
    TpQ.TName = SELF.TemplateQ.Name
    TpQ.TSubj = SELF.TemplateQ.Subject
    TpQ.TId   = SELF.TemplateQ.Id
    ADD(TpQ)
  END
  DO Told
  DISPLAY()

LoadSenders ROUTINE
  DO Working
  n = 0
  IF SELF.Supports(ETOp:Senders)
    n = SELF.GetSenders()
    IF n < 0 THEN n = 0.
  END
  FREE(SdQ)
  LOOP i = 1 TO RECORDS(SELF.SenderQ)
    GET(SELF.SenderQ, i)
    SdQ.DAddr = SELF.SenderQ.Address
    SdQ.DName = SELF.SenderQ.Name
    SdQ.DVer  = CHOOSE(SELF.SenderQ.Verified = 1, SELF.Txt(ETATxt:Verified), '')
    ADD(SdQ)
  END
  FREE(DmQ)
  IF SELF.Supports(ETOp:Domains)
    IF SELF.GetDomains() > 0
      LOOP i = 1 TO RECORDS(SELF.DomainQ)
        GET(SELF.DomainQ, i)
        DmQ.MName = SELF.DomainQ.Name
        DmQ.MVer  = CHOOSE(SELF.DomainQ.Verified = 1, SELF.Txt(ETATxt:Verified), '')
        DmQ.MStat = SELF.DomainQ.Status
        ADD(DmQ)
      END
      n += RECORDS(DmQ)
    END
  END
  DO Rested
  DO Told
  DISPLAY()

LoadHooks ROUTINE
  DO Working
  n = SELF.GetWebhooks()
  DO Rested
  FREE(WhQ)
  LOOP i = 1 TO RECORDS(SELF.HookQ)
    GET(SELF.HookQ, i)
    WhQ.HUrl    = SELF.HookQ.Url
    WhQ.HEvents = SELF.HookQ.Events
    WhQ.HId     = SELF.HookQ.Id
    ADD(WhQ)
  END
  DO Told
  DISPLAY()

!---- acting ------------------------------------------------------------------
DoUnblock ROUTINE
  IF NOT RECORDS(BlkQ) THEN EXIT.
  GET(BlkQ, CHOICE(?BlkList))
  IF ERRORCODE() THEN EXIT.
  IF MESSAGE(CLIP(SELF.Txt(ETATxt:Confirm)) & '<13,10><13,10>' & CLIP(BlkQ.BAddr), |
             SELF.Txt(ETATxt:Unblock), ICON:Question, BUTTON:Yes + BUTTON:No, BUTTON:No) |
     <> BUTTON:Yes
    EXIT
  END
  GET(SELF.SuppQ, BlkQ.BRow)
  IF ERRORCODE() THEN EXIT.
  DO Working
  ok = SELF.DeleteSuppression(SELF.SuppQ.Address, SELF.SuppQ.Kind)
  DO Rested
  IF ok
    DO LoadBlocks
    LocStatus = SELF.Txt(ETATxt:Done)
  ELSE
    LocStatus = CLIP(SELF.LastErrorText)
  END
  DISPLAY()

DoUnblockAll ROUTINE
  IF NOT RECORDS(SELF.SuppQ) THEN EXIT.
  IF MESSAGE(CLIP(SELF.Txt(ETATxt:ConfirmAll)) & '<13,10><13,10>' & |
             RECORDS(SELF.SuppQ) & ' ' & CLIP(SELF.Txt(ETATxt:Rows)), |
             SELF.Txt(ETATxt:UnblockAll), ICON:Question, BUTTON:Yes + BUTTON:No, BUTTON:No) |
     <> BUTTON:Yes
    EXIT
  END
  k = CHOICE(?LocKindTxt) - 1
  IF k < 0 THEN k = ETSup:All.
  DO Working
  n = SELF.DeleteAllSuppressions(k)
  DO Rested
  IF n < 0
    LocStatus = CLIP(SELF.LastErrorText)
  ELSE
    sel = n
    DO LoadBlocks
    LocStatus = CLIP(SELF.Txt(ETATxt:Done)) & '  ' & sel
  END
  DISPLAY()

DoBlock ROUTINE
  LocAsk      = ''
  LocAskTitle = SELF.Txt(ETATxt:Address)
  DO AskForOne
  IF NOT CLIP(LocAsk) THEN EXIT.
  k = CHOICE(?LocKindTxt) - 1
  IF k < 1 THEN k = ETSup:Block.
  DO Working
  ok = SELF.AddSuppression(LocAsk, k)
  DO Rested
  IF ok
    DO LoadBlocks
    LocStatus = SELF.Txt(ETATxt:Done)
  ELSE
    LocStatus = CLIP(SELF.LastErrorText)
  END
  DISPLAY()

DoExport ROUTINE
  LocAsk = 'blocked.csv'
  IF NOT FILEDIALOG(SELF.Txt(ETATxt:Export), LocAsk, 'CSV|*.csv|All files|*.*', |
                    FILE:Save + FILE:KeepDir + FILE:AddExtension)
    EXIT
  END
  n = SELF.ExportSuppressions(LocAsk)
  IF n < 0
    LocStatus = CLIP(SELF.LastErrorText)
  ELSE
    LocStatus = CLIP(SELF.Txt(ETATxt:Exported)) & '  ' & n
  END
  DISPLAY()

DoAddContact ROUTINE
  LocAsk      = ''
  LocAskTitle = SELF.Txt(ETATxt:Address)
  DO AskForOne
  IF NOT CLIP(LocAsk) THEN EXIT.
  DO Working
  IF CLIP(LocListId)
    ok = SELF.AddContact(LocAsk, '', LocListId)
  ELSE
    ok = SELF.AddContact(LocAsk)
  END
  DO Rested
  IF ok
    DO LoadContacts
    LocStatus = SELF.Txt(ETATxt:Done)
  ELSE
    LocStatus = CLIP(SELF.LastErrorText)
  END
  DISPLAY()

DoDelContact ROUTINE
  IF NOT RECORDS(CtQ) THEN EXIT.
  GET(CtQ, CHOICE(?ContactList))
  IF ERRORCODE() THEN EXIT.
  IF MESSAGE(CLIP(SELF.Txt(ETATxt:Delete)) & '  ' & CLIP(CtQ.CAddr) & ' ?', |
             SELF.Txt(ETATxt:Contacts), ICON:Question, BUTTON:Yes + BUTTON:No, BUTTON:No) |
     <> BUTTON:Yes
    EXIT
  END
  DO Working
  !  Some providers delete a contact by their own id, some by the address.
  !  The id is preferred when there is one; the address is the fallback.
  IF CLIP(CtQ.CId)
    ok = SELF.DeleteContact(CtQ.CId, LocListId)
  ELSE
    ok = SELF.DeleteContact(CtQ.CAddr, LocListId)
  END
  DO Rested
  IF ok
    DO LoadContacts
    LocStatus = SELF.Txt(ETATxt:Done)
  ELSE
    LocStatus = CLIP(SELF.LastErrorText)
  END
  DISPLAY()

DoAddList ROUTINE
  LocAsk      = ''
  LocAskTitle = SELF.Txt(ETATxt:Name)
  DO AskForOne
  IF NOT CLIP(LocAsk) THEN EXIT.
  DO Working
  ok = SELF.AddList(LocAsk)
  DO Rested
  IF ok
    DO LoadLists
    LocStatus = SELF.Txt(ETATxt:Done)
  ELSE
    LocStatus = CLIP(SELF.LastErrorText)
  END
  DISPLAY()

DoSendCampaign ROUTINE
  IF NOT RECORDS(CpQ) THEN EXIT.
  GET(CpQ, CHOICE(?CampaignList))
  IF ERRORCODE() THEN EXIT.
  IF MESSAGE(CLIP(SELF.Txt(ETATxt:Send)) & '  ' & CLIP(CpQ.PName) & ' ?', |
             SELF.Txt(ETATxt:Campaigns), ICON:Question, BUTTON:Yes + BUTTON:No, BUTTON:No) |
     <> BUTTON:Yes
    EXIT
  END
  DO Working
  ok = SELF.SendCampaign(CpQ.PId)
  DO Rested
  IF ok
    DO LoadCampaigns
    LocStatus = SELF.Txt(ETATxt:Done)
  ELSE
    LocStatus = CLIP(SELF.LastErrorText)
  END
  DISPLAY()

DoDelHook ROUTINE
  IF NOT RECORDS(WhQ) THEN EXIT.
  GET(WhQ, CHOICE(?HookList))
  IF ERRORCODE() THEN EXIT.
  IF MESSAGE(CLIP(SELF.Txt(ETATxt:Delete)) & '  ' & CLIP(WhQ.HUrl) & ' ?', |
             SELF.Txt(ETATxt:Webhooks), ICON:Question, BUTTON:Yes + BUTTON:No, BUTTON:No) |
     <> BUTTON:Yes
    EXIT
  END
  DO Working
  ok = SELF.DeleteWebhook(WhQ.HId)
  DO Rested
  IF ok
    DO LoadHooks
    LocStatus = SELF.Txt(ETATxt:Done)
  ELSE
    LocStatus = CLIP(SELF.LastErrorText)
  END
  DISPLAY()

AskForOne ROUTINE
  OPEN(Ask)
  Ask{PROP:Text} = CLIP(LocAskTitle)
  ACCEPT
    CASE EVENT()
    OF EVENT:CloseWindow
      BREAK
    END
    CASE FIELD()
    OF ?AskOk
      IF EVENT() = EVENT:Accepted THEN POST(EVENT:CloseWindow).
    OF ?AskCancel
      IF EVENT() = EVENT:Accepted
        LocAsk = ''
        POST(EVENT:CloseWindow)
      END
    END
  END
  CLOSE(Ask)
