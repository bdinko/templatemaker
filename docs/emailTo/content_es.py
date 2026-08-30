# -*- coding: utf-8 -*-
"""El contenido en español de los cuatro volúmenes.

Mismos identificadores de sección y misma estructura de navegación que el
inglés, para que las comprobaciones de deriva valgan igual en los dos juegos.
Los ejemplos de código se comparten con content_en: son Clarion, y el Clarion
no se traduce.
"""
import sys
import os

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from shell import (esc, slug, code, usecode, note, table, h2, h3, p,   # noqa: E402
                   nextcards, page, PROBLEMS, EXAMPLES, extract)
from lang import PAGE_TITLES                                           # noqa: E402
from es_docs import MEMBER_DOCS_ES, FIELD_DOCS_ES, EQUATE_NOTES_ES  # noqa: E402
from content_en import (S_HELLO, S_PROJECT, S_ATTACH, S_OAUTHRUN,      # noqa: E402
                        S_OWNS, S_OAUTHFLOW, S_TABLE, S_ACCOUNTS, S_DERIVE, S_INLINE,
                        S_CLEARTRAP, S_BRACETRAP, S_STRINGTRAP, S_RETSTR,
                        S_GEN_GLOBAL, S_GEN_DERIVED, S_GEN_BUTTON,
                        S_ASK, S_SUPPORTS, S_MATRIX, S_ADDPROVIDER, S_APIEMBED,
                        S_SYNCGEN)


# =====================================================================
#  1  PRIMEROS PASOS
# =====================================================================
def build_getting_started():
    B = []
    add = B.append

    add(h2('what', 'Qué es emailTo'))
    add(p('emailTo envía correo desde una aplicación Clarion, y administra la cuenta '
          'por la que lo envía. Son cinco clases, un '
          'archivo C incluido y diez plantillas, y se despliega dentro de su propio '
          '<code>.EXE</code>: no hay DLL que distribuir, ni .NET, ni OpenSSL, ni nada '
          'que registrar en la máquina donde corra.'))
    add(p('Puede poner un mensaje en la red de cuatro maneras, y las cuatro envían el '
          'mismo mensaje: <b>SMTP</b> en texto plano, STARTTLS o TLS directo; la '
          '<b>API de Gmail</b>; <b>Microsoft Graph</b>; o una <b>clave API</b> de '
          'SendGrid, Mailgun, Resend, Brevo, Postmark o Mailjet.'))
    add(table(['Si tiene', 'Use', 'Lo que necesita'], [
        ['Una cuenta de Gmail', 'SMTP + contraseña de aplicación',
         'Verificación en dos pasos activada, y luego una contraseña de aplicación'],
        ['Outlook.com o Hotmail', 'SMTP + OAuth2',
         'Un ID de cliente de escritorio, desde Azure'],
        ['Microsoft 365 del trabajo', 'Graph, o SMTP + OAuth2',
         'Un ID de cliente de escritorio, y su inquilino (tenant)'],
        ['Un servidor de correo propio', 'SMTP + contraseña',
         'Servidor, puerto, y si pide STARTTLS'],
        ['Nada de lo anterior', 'Un servicio con clave API',
         'Una clave gratuita de Resend o de Brevo'],
    ]))

    add(h2('install', 'Instalación'))
    add(note('tip', u'O deje que lo haga el instalador',
             u'<p><b>emailToSetup.exe</b> encuentra cada Clarion <b>10 o posterior</b> de la '
             u'm&aacute;quina &mdash; por la configuraci&oacute;n del propio IDE y recorriendo '
             u'los discos fijos &mdash;, copia las plantillas y las clases en los que usted '
             u'marque, y registra cada uno con el <code>ClarionCL</code> de esa '
             u'instalaci&oacute;n. Deja adem&aacute;s este manual, el diccionario y las demos '
             u'en el disco. El resto de esta p&aacute;gina es exactamente lo que hace, para '
             u'quien prefiera colocar los archivos a mano.</p>'
             u'<p>Clarion 10 recibe una compilaci&oacute;n de la plantilla con los prompts '
             u'dispuestos para su di&aacute;logo de AppGen m&aacute;s angosto &mdash; 480 px, '
             u'frente a 960 desde Clarion 11. Mismo nombre de plantilla y mismo c&oacute;digo '
             u'generado, as&iacute; que una aplicaci&oacute;n pasa de una a otra.</p>'))
    add(p('Copie estos once archivos a una carpeta que esté en la ruta de '
          'redirección de Clarion: la carpeta de la aplicación, o '
          '<code>\\clarion12\\accessory\\libsrc\\win</code>.'))
    add(table(['Archivo', 'Qué es'], [
        ['<code>EmailNetClass.inc</code> / <code>.clw</code>',
         'Sockets, TLS, HTTPS, DPAPI. Es la que compila el C.'],
        ['<code>EmailMsgClass.inc</code> / <code>.clw</code>',
         'El mensaje y su MIME. Clarion puro.'],
        ['<code>EmailToClass.inc</code> / <code>.clw</code>',
         'Cuentas, los cuatro transportes, OAuth2, las ventanas.'],
        ['<code>EmailJsonClass.inc</code> / <code>.clw</code>',
         u'Leer lo que contesta un proveedor. Clarion puro.'],
        ['<code>EmailApiClass.inc</code> / <code>.clw</code>',
         u'La API de gesti&oacute;n: bloqueados, estad&iacute;sticas, campa&ntilde;as.'],
        ['<code>emailc.c</code>',
         'Winsock, SCHANNEL, WinHTTP, DPAPI, SHA-256.'],
    ]))
    add(note('tip', u'Y un diccionario, si quiere guardar las respuestas',
             u'<p><code>emailToTables.dctx</code> viene con ellas: siete tablas &mdash; '
             u'la lista de bloqueados, las estadísticas, la actividad, los contactos, '
             u'las listas, las campañas y la propia cuenta. Editor de diccionario &rarr; '
             u'<b>File &rarr; Import</b>, y elija la entrada <b>DCTX / XML</b>. Sólo hace '
             u'falta si agrega la extensión <b>emailTo - Sync</b>; enviar y la ventana de '
             u'gestión no lo usan.</p>'
             u'<p><b>No</b> el <code>.txd</code> que está al lado &mdash; ése es el '
             u'formato de Report Writer, y el editor de diccionario lo dice con esas '
             u'mismas palabras.</p>'))
    add(p('Ponga <code>emailTo.tpl</code> en '
          '<code>\\clarion12\\accessory\\template\\win</code> y regístrelo, desde el '
          'IDE o desde la línea de comandos:'))
    add(code('ClarionCL.exe -tr "C:\\clarion12\\accessory\\template\\win\\emailTo.tpl"', 'dos'))
    add(note('warn', 'Las fuentes tienen que estar en ANSI, con saltos de línea CRLF',
             '<p>Clarion interpreta mal un include que sólo tenga LF: aparece '
             '<code>Illegal data type: EMAILTOCLASS</code> señalando la '
             '<em>declaración</em>, sin marcar nada dentro del include. Si movió estos '
             'archivos con alguna herramienta que reescribe los saltos de línea, '
             'conviértalos de vuelta antes de buscar un error de sintaxis que no '
             'existe.</p>'))

    add(h2('hello', 'Lo mínimo que envía'))
    add(p('Sin plantilla, sin ventana y sin diccionario. Este es un programa completo:'))
    add(code(S_HELLO))
    add(p('Vale la pena fijarse en dos cosas. <code>SetProvider</code> llena el '
          'servidor, el puerto, la seguridad y el método de autenticación, así que '
          'las únicas líneas que quedan son las que de verdad hablan de su cuenta. Y '
          'aquí no se revisa ningún código de retorno salvo el del envío: cualquier '
          'falla termina en <code>LastErrorText</code> como una frase que se le puede '
          'mostrar al usuario.'))
    add(note('tip', 'De dónde sale la contraseña de aplicación',
             '<p>Google, Yahoo e iCloud no aceptan su contraseña normal desde un '
             'programa. Active la verificación en dos pasos y genere una '
             '<b>contraseña de aplicación</b>, una cadena de dieciséis caracteres '
             'emitida para una sola aplicación. Esa es la que va en '
             '<code>Acc.Password</code>. Outlook.com ya no ofrece este camino: ahí es '
             'OAuth2 o nada, que es lo que cubre la guía del programador.</p>'))

    add(h2('handcoded', 'Compilarlo a mano'))
    add(p('Las clases se agregan solas a la compilación por su atributo '
          '<code>LINK</code>, y <code>EmailNetClass.clw</code> arrastra el C con su '
          '<code>PRAGMA</code>, así que un proyecto hecho a mano no necesita lista de '
          'archivos. Lo que sí necesita son las dos definiciones de modo de enlace que '
          'la plantilla escribiría por usted:'))
    add(code(S_PROJECT, 'xml'))
    add(note('danger', 'Si faltan, no falla el enlace',
             '<p>Sin <code>_emailToLinkMode_</code> las clases se enlazan como '
             '<em>importaciones</em> de una DLL que no existe, y el programa da una '
             'violación de acceso dentro de un constructor antes de que corra '
             '<code>main()</code>. La pila de llamadas no muestra nada suyo, así que '
             'parece cualquier cosa menos una opción del proyecto.</p>'))

    add(h2('fromappgen', 'Lo mismo desde AppGen'))
    add(p('Dos pasos, y sin escribir código:'))
    add('<ol class="b">'
        '<li><b>Propiedades globales &rarr; Extensiones &rarr; Insertar &rarr; '
        'emailTo - Global.</b> Llene la pestaña Cuenta: proveedor, dirección de '
        'remitente, usuario. Eso declara el objeto, fija los valores por omisión y '
        'carga la cuenta guardada al arrancar.</li>'
        '<li><b>Arrastre <i>emailTo - Botón de correo</i> a una ventana.</b> Elija qué '
        'hace &mdash; abrir la ventana de redacción, enviar de una vez, o abrir la '
        'ventana de configuración &mdash; y ya está.</li>'
        '</ol>')
    add(note('tip', 'La cuenta se configura una vez, no por botón',
             '<p>El paso 1 es donde vive el remitente: servidor, dirección, usuario, '
             'contraseña, cliente OAuth2. El paso 2 no pide nada de eso. Esa división '
             'es justamente el punto: ponga cinco botones de correo en cinco ventanas y '
             'sigue habiendo exactamente una cuenta, en un solo lugar, para toda la '
             'aplicación.</p>'
             '<p>Para que el <em>usuario</em> la cambie en tiempo de ejecución, dele un '
             'botón cuya acción sea <b>abrir la ventana de configuración de la '
             'cuenta</b>. Lo que guarde ahí gana sobre la pestaña Cuenta.</p>'))
    add(p('Desde cualquier embed en cualquier otro procedimiento de la aplicación, el '
          'objeto simplemente está ahí:'))
    add(usecode("Mailer.SendSimple(Cus:Email, 'Su estado de cuenta', 'Adjunto.', Loc:PdfName)"))

    add(h2('attachments', 'Un mensaje con más adentro'))
    add(p('<code>SendSimple</code> cubre una nota con un adjunto. Cualquier cosa más '
          'rica se arma sobre <code>Mailer.Msg</code> y se entrega a '
          '<code>Send</code>:'))
    add(code(S_ATTACH))
    add(p('Usted no le dice qué clase de documento MIME construir. Sólo texto es '
          '<code>text/plain</code>; texto y HTML juntos son '
          '<code>multipart/alternative</code>; una imagen incrustada lo vuelve '
          '<code>multipart/related</code>; un archivo adjunto envuelve todo en '
          '<code>multipart/mixed</code>. Una nota simple no llega convertida en un '
          'árbol de cuatro partes.'))

    add(h2('oauthsetup', 'Configurar OAuth2, paso a paso'))
    add(p('Esta es la parte donde se atora la gente, y casi siempre por una de dos '
          'razones: la URI de redirección no coincide, o la aplicación se registró con '
          'el tipo equivocado. Las dos se arreglan en el proveedor, no en su código.'))

    add(h3('oauth-google', 'Google'))
    add('<ol class="b">'
        '<li>Entre a <b>console.cloud.google.com</b> y elija o cree un proyecto.</li>'
        '<li><b>APIs y servicios &rarr; Pantalla de consentimiento de OAuth.</b> Elija '
        '<b>External</b>, ponga el nombre de la aplicación y su correo, y guarde. '
        'Mientras esté en <b>Testing</b>, agregue su propia dirección en <b>Usuarios de '
        'prueba</b>: un proyecto en pruebas rechaza a cualquiera que no esté en esa '
        'lista.</li>'
        '<li>Agregue el scope que realmente necesita: '
        '<code>https://mail.google.com/</code> para SMTP, o '
        '<code>https://www.googleapis.com/auth/gmail.send</code> para la API de '
        'Gmail.</li>'
        '<li><b>Credenciales &rarr; Crear credenciales &rarr; ID de cliente de '
        'OAuth</b>, y ponga el tipo de aplicación en <b>Aplicación de escritorio</b>. '
        'No en Aplicación web: un cliente web no acepta una redirección de '
        'loopback.</li>'
        '<li>Copie el <b>ID de cliente</b> a la pestaña Acceso. Google puede mostrarle '
        'también un secreto de cliente; péguelo si lo hay, déjelo vacío si no. Ninguno '
        'de los dos es sensible aquí, porque el flujo es PKCE.</li>'
        '</ol>')
    add(note('note', 'A un cliente de escritorio de Google no se le registra una URI de redirección',
             '<p>Los clientes de escritorio pueden usar cualquier puerto de loopback, '
             'así que no hay nada que escribir. emailTo envía '
             '<code>http://127.0.0.1:&lt;puerto&gt;</code>, que es la forma que Google '
             'documenta.</p>'))

    add(h3('oauth-microsoft', 'Microsoft &mdash; Outlook.com y Microsoft 365'))
    add('<ol class="b">'
        '<li>Entre a <b>portal.azure.com &rarr; Registros de aplicaciones &rarr; Nuevo '
        'registro</b>.</li>'
        '<li>En los tipos de cuenta admitidos elija <b>Cuentas en cualquier directorio '
        'organizativo y cuentas personales de Microsoft</b> si quiere las del trabajo y '
        'las de Outlook.com; ésa es la que corresponde a un inquilino '
        '<code>common</code>.</li>'
        '<li>En <b>URI de redirección</b> elija la plataforma <b>Aplicaciones móviles y '
        'de escritorio</b> y marque <code>http://localhost</code>. Este es el paso que '
        'se salta la gente: si deja la plataforma en Web, el acceso se rechaza con un '
        'error de URI de redirección.</li>'
        '<li><b>Autenticación &rarr; Permitir flujos de cliente público &rarr; '
        'Sí.</b></li>'
        '<li><b>Permisos de API &rarr; Agregar un permiso &rarr; Microsoft Graph &rarr; '
        'Delegados</b>. Agregue <code>Mail.Send</code> y <code>offline_access</code> '
        'para Graph, o <code>SMTP.Send</code> y <code>offline_access</code> para '
        'SMTP.</li>'
        '<li>Copie el <b>Id. de aplicación (cliente)</b> a la pestaña Acceso. Deje el '
        'secreto de cliente <b>vacío</b>: un cliente público que manda uno es '
        'rechazado.</li>'
        '</ol>')
    add(note('warn', 'Haga que el host de redirección coincida con lo que registró',
             '<p>Como Azure ofrece <code>http://localhost</code> y Google documenta '
             '<code>http://127.0.0.1</code>, emailTo manda el que le corresponde al '
             'proveedor que eligió. De todos modos escucha en <b>los dos</b> loopbacks, '
             'así que un navegador que resuelva <code>localhost</code> a '
             '<code>::1</code> &mdash; que es lo que hace Windows primero &mdash; '
             'igual llega. Si registró otra cosa, dígalo:</p>'
             "<p><code>Mailer.OAuth.RedirectHost = '127.0.0.1'</code></p>"))

    add(h3('oauth-verify', 'Google dice &ldquo;Acceso bloqueado&rdquo;'))
    add(p('<i>&ldquo;Acceso bloqueado: &lt;su aplicaci&oacute;n&gt; no completó el '
          'proceso de verificación de Google.&rdquo;</i> Es la pantalla de '
          'consentimiento la que lo rechaza, no emailTo el que falla, y tiene dos causas '
          'que dan casi el mismo texto. Cuál de las dos es la suya la decide el '
          '<b>estado de publicación</b> de su aplicación.'))
    add(table(['Estado de publicación', 'Qué significa el bloqueo', 'Qué hacer'], [
        ['<b>Testing</b> (en pruebas)',
         'La cuenta con la que está entrando no está en la lista de usuarios de prueba. '
         'La pantalla suele agregar &ldquo;currently being tested&hellip; '
         'developer-approved testers&rdquo;.',
         'Google Auth Platform &rarr; <b>Audience</b> &rarr; <b>Test users</b> &rarr; '
         'Add users, y agregue la dirección exacta con la que inicia sesión.'],
        ['<b>In production</b>, sin verificar, con <code>https://mail.google.com/</code>',
         'Ése es un scope <b>restringido</b>. Sin verificar, Google lo bloquea de plano: '
         'no hay ningún enlace <i>Advanced</i> para pasar de largo.',
         'O vuelve a Testing con usuarios de prueba, o cambia al scope '
         '<code>gmail.send</code>.'],
        ['<b>In production</b>, sin verificar, con <code>gmail.send</code>',
         'Ése es un scope <b>sensible</b>, así que sale una advertencia y no un bloqueo.',
         'Haga clic en <b>Advanced</b> &rarr; <b>Go to &lt;su aplicaci&oacute;n&gt;</b>. '
         'Es su propia aplicación; la advertencia es lo esperado.'],
    ]))
    add(note('warn', 'Publicar no es automáticamente la solución',
             '<p>Quedarse en <b>Testing</b> tiene su propio costo: Google caduca el token '
             'de refresco a los <b>siete días</b>, así que un inicio de sesión que '
             'funcionaba deja de funcionar a la semana siguiente. Publicar quita eso, '
             'pero sólo ayuda si su scope es <code>gmail.send</code>. Publique pidiendo '
             '<code>https://mail.google.com/</code> y habrá cambiado un re-login semanal '
             'por un muro permanente.</p>'
             '<p>Así que si va a usar OAuth con Gmail, use el transporte <b>Gmail API</b>. '
             'emailTo entonces pide <code>gmail.send</code>, que es el scope más estrecho '
             'y el que sí se puede publicar sin verificar.</p>'))
    add(note('tip', 'Para una sola cuenta de Gmail, una contraseña de aplicación evita todo esto',
             '<p>Sin pantalla de consentimiento, sin verificación, sin caducidad a los '
             'siete días, y sin nada que registrar. Active la verificación en dos pasos, '
             'genere una contraseña de aplicación en '
             '<b>myaccount.google.com/apppasswords</b>, y úsela como contraseña SMTP '
             '&mdash; <b>quitándole los espacios</b>. OAuth se gana su lugar cuando usted '
             'entrega la aplicación a los buzones de otras personas, o cuando un '
             'administrador de Workspace apagó las contraseñas de aplicación.</p>'))

    add(h3('oauth-run', 'Cómo se ejecuta'))
    add(p('Ponga la cuenta en OAuth y presione <b>Iniciar sesión&hellip;</b> en la '
          'ventana de configuración, o llámelo usted mismo:'))
    add(code(S_OAUTHRUN))
    add(p('Se abre su navegador en el proveedor. Inicie sesión, acepte los permisos, y '
          'la página regresa diciendo que ya puede cerrar la pestaña. Eso es todo: de '
          'ahí en adelante el token de refresco queda guardado y nadie vuelve a ver un '
          'navegador.'))
    add(note('tip', 'Cuando falle, lea la URL',
             '<p>La dirección exacta que se abrió queda en '
             '<code>Mailer.OAuth.LastAuthUrl</code>, y se escribe en el registro. '
             'Péguela a mano en un navegador y el proveedor le va a decir exactamente '
             'qué es lo que objeta, que es mucho mejor que adivinar a partir de una '
             'falla genérica.</p>'))
    add(table(['Lo que dice el proveedor', 'Qué hay que cambiar'], [
        ['<code>redirect_uri_mismatch</code>',
         'Google: el cliente es Aplicación web, no Aplicación de escritorio. '
         'Microsoft: la plataforma es Web, no Móviles y de escritorio.'],
        ['<code>invalid_client</code> / The OAuth client was not found',
         'El ID de cliente está mal, o es de otro proyecto o de otro inquilino.'],
        ['<code>unauthorized_client</code>',
         'Microsoft: <b>Permitir flujos de cliente público</b> sigue en No.'],
        ['<code>access_denied</code>, y usted es usuario de prueba',
         'Google: su dirección no está en Usuarios de prueba en la pantalla de '
         'consentimiento.'],
        ['El acceso funciona, pero el segundo envío lo vuelve a pedir',
         'No se emitió token de refresco. En Google hay que volver a aprobar la '
         'pantalla de consentimiento; emailTo ya manda '
         '<code>access_type=offline&amp;prompt=consent</code>.'],
        ['El navegador abre y nunca regresa nada',
         'Algo está ocupando el puerto de loopback. Fije uno con '
         '<code>Mailer.OAuth.RedirectPort</code> y permítalo en el firewall.'],
    ]))

    add(h2('ask', u'Qui\u00e9n est\u00e1 bloqueado, y por qu\u00e9'))
    add(p(u'Enviar es la mitad de lo que hace un proveedor de correo. La otra mitad es '
          u'mantener la lista de las direcciones a las que no va a entregar: las que '
          u'rebotaron en firme, las de quien pulsó "esto es basura", las de quien se '
          u'dio de baja. Si nadie la mira, esa lista se queda en su sitio web, y su '
          u'programa sigue escribiendo a direcciones que jamás pueden llegar, que es '
          u'exactamente lo que arruina la reputación de un remitente.'))
    add(p(u'<code>EmailApiClass</code> la lee. Un objeto, que toma prestada la cuenta '
          u'que usted ya configuró:'))
    add(code(S_ASK))
    add(p(u'Ese programa funciona sin cambios contra los nueve proveedores con API. '
          u'Tiene que hacerlo, porque no se ponen de acuerdo en casi nada:'))
    add(table([u'Proveedor', u'Dónde están las direcciones bloqueadas', u'Cómo es una fila'], [
        [u'SendGrid', u'Cinco listas separadas: bounces, blocks, spam_reports, '
                      u'unsubscribes, invalid_emails',
         u'<code>email</code>, <code>reason</code>, un <code>created</code> unix'],
        [u'Brevo', u'Una sola lista, <code>/smtp/blockedContacts</code>, con un CÓDIGO '
                   u'de motivo que dice de qué tipo es',
         u'<code>email</code>, <code>reason.message</code>, un <code>blockedAt</code> ISO'],
        [u'Mailgun', u'Por DOMINIO, y paginada con un cursor en vez de un desplazamiento',
         u'<code>address</code>, <code>error</code>, <code>code</code>, una fecha RFC-2822'],
        [u'Postmark', u'Un volcado del flujo, más un <code>/bounces</code> con mucho '
                      u'más detalle sólo para los rebotes',
         u'<code>EmailAddress</code>, <code>SuppressionReason</code> &mdash; con mayúsculas'],
        [u'Mailjet', u'Todo envuelto en <code>Data</code>, y todo con mayúscula inicial',
         u'<code>ContactAlt</code>, <code>ErrorRelatedTo</code>, <code>ErrorCode</code>'],
        [u'Amazon SES', u'Firmado con SigV4 en vez de una clave en una cabecera, y '
         u'paginado con un token de continuación',
         u'<code>EmailAddress</code>, <code>Reason</code> &mdash; BOUNCE o COMPLAINT'],
    ]))
    add(p(u'Después de <code>GetSuppressions()</code> son una sola cola con las mismas '
          u'columnas, y <code>SuppQ.Kind</code> dice de qué clase de bloqueo se trata '
          u'realmente cada fila &mdash; deducido de las palabras del propio proveedor '
          u'cuando éste las guarda todas juntas.'))
    add(note('tip', u'Pregunte antes de enviar',
             u'<p><code>IsBlocked()</code> busca en lo que cargó el último '
             u'<code>GetSuppressions()</code>. Llamarlo en el bucle que arma un envío '
             u'no cuesta nada y evita escribir a una dirección que el proveedor va a '
             u'rechazar de todos modos:</p>'
             u'<pre class="code"><code>IF MailApi.IsBlocked(CUS:EMail) THEN CYCLE.'
             u'</code></pre>'))

    add(h2('ask-more', u'El resto de la cuenta'))
    add(p(u'El mismo objeto responde a las demás preguntas, y todas llenan una cola de '
          u'la misma forma sea quien sea el proveedor:'))
    add(table([u'Usted quiere', u'Llame a', u'Llena'], [
        [u'Quién está bloqueado', u'<code>GetSuppressions(tipo)</code>', u'<code>SuppQ</code>'],
        [u'Readmitir a uno', u'<code>DeleteSuppression(dirección, tipo)</code>', u'&mdash;'],
        [u'Readmitirlos a todos', u'<code>DeleteAllSuppressions(tipo)</code>', u'&mdash;'],
        [u'Estadísticas por día', u'<code>GetStats(desde, hasta)</code>', u'<code>StatQ</code>'],
        [u'Qué pasó con un mensaje', u'<code>GetEvents(desde, hasta)</code>',
         u'<code>EventQ</code>'],
        [u'Contactos y listas', u'<code>GetContacts()</code> <code>GetLists()</code>',
         u'<code>ContactQ</code> <code>ListQ</code>'],
        [u'Campañas', u'<code>GetCampaigns()</code> <code>SendCampaign(id)</code>',
         u'<code>CampaignQ</code>'],
        [u'Plantillas, remitentes, dominios, webhooks',
         u'<code>GetTemplates()</code> &hellip;', u'<code>TemplateQ</code> &hellip;'],
        [u'Todo, en una ventana', u'<code>Manage()</code>', u'&mdash;'],
    ]))
    add(p(u'Ningún proveedor las ofrece todas. <code>Supports()</code> dice cuáles, de '
          u'modo que una ventana puede deshabilitar lo que esta cuenta realmente no '
          u'puede hacer, en vez de fallar cuando alguien lo pulsa:'))
    add(code(S_SUPPORTS))
    add(note('info', u'O simplemente muéstreles la ventana',
             u'<p><code>MailApi.Manage()</code> es una ventana completa, con pestañas, '
             u'sobre todo ello: las direcciones bloqueadas con su motivo, readmitir a '
             u'una o a todas, exportar a CSV, estadísticas, actividad, contactos, '
             u'listas, campañas, plantillas, remitentes, dominios y webhooks. Las '
             u'pestañas que este proveedor no puede contestar salen deshabilitadas, no '
             u'vacías. La plantilla de control <b>emailTo - Mail account button</b> '
             u'coloca un botón que la abre por la pestaña que usted diga.</p>'))

    add(h2('demo', 'La demostración'))
    add(p('<code>examples/emailTo/emailToDemo.clw</code> es el equivalente escrito a '
          'mano de lo que generan las plantillas: una ventana con <b>Configurar '
          'cuenta</b>, <b>Escribir un mensaje</b> y <b>Enviar una prueba</b>, con el '
          'registro de la conversación abajo. Compílela y presione los botones antes de '
          'conectar nada a su propia aplicación.'))
    add(code('MSBuild emailToDemo.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32\n'
             'emailToDemo.exe            ! la ventana de la demostración\n'
             'emailToDemo.exe /setup     ! directo a la ventana de la cuenta', 'dos'))
    add(p('<b>Probar cuenta</b> es el botón que hay que presionar primero. Conecta, '
          'negocia TLS y se autentica, y luego cuelga: no le manda nada a nadie, así '
          'que puede comprobar las credenciales sin escribirle a una persona real.'))

    add(h2('firstrun', 'Cuando el primer envío no funciona'))
    add(p('Encienda el registro (<code>Mailer.Trace = 1</code>) y lea la pestaña '
          'Registro de la ventana de configuración. Ahí está cada línea que dijo el '
          'servidor, con las contraseñas ocultas. Estas son las respuestas que salen '
          'primero:'))
    add(table(['Lo que ve', 'Qué significa'], [
        ['<code>The password was refused</code> en Gmail',
         'Una contraseña normal, no una de aplicación. O la verificación en dos pasos '
         'está apagada, así que Google no emite ninguna.'],
        ['<code>The password was refused</code> en Outlook.com',
         'Microsoft apagó la autenticación básica para cuentas personales. Use OAuth2.'],
        ['<code>The TLS handshake failed</code>, código de Windows 590624',
         'Ese es <code>SEC_I_INCOMPLETE_CREDENTIALS</code>. emailTo ya lo maneja; si lo '
         've, está corriendo una copia vieja de <code>emailc.c</code>.'],
        ['<code>Could not connect to the mail server</code>',
         'Un firewall, o el puerto equivocado. 587 es STARTTLS, 465 es TLS directo, 25 '
         'es texto plano.'],
        ['<code>The sender was refused</code>',
         'La dirección de remitente no es una que la cuenta tenga permitido usar.'],
        ['<code>Illegal data type: EMAILTOCLASS</code> al compilar',
         'Los includes llegaron con saltos de línea LF. Conviértalos a CRLF.'],
    ]))

    add(nextcards(['programmers-guide.html', 'template-guide.html', 'reference.html']))

    body = '\n'.join(B)
    groups = [
        ('Empiece aquí', [('what', 'Qué es emailTo'), ('install', 'Instalación')]),
        ('Enviar algo', [('hello', 'Lo mínimo que envía'),
                         ('handcoded', 'Compilarlo a mano'),
                         ('fromappgen', 'Lo mismo desde AppGen'),
                         ('attachments', 'Un mensaje con más adentro')]),
        ('OAuth2', [('oauthsetup', 'Configurar OAuth2'),
                    ('oauth-google', 'Google'),
                    ('oauth-microsoft', 'Microsoft'),
                    ('oauth-verify', 'Acceso bloqueado'),
                    ('oauth-run', 'Cómo se ejecuta')]),
        ('Preguntar al proveedor', [('ask', u'Qui\u00e9n est\u00e1 bloqueado, y por qu\u00e9'),
                                    ('ask-more', u'El resto de la cuenta')]),
        ('Después', [('demo', 'La demostración'),
                     ('firstrun', 'Cuando el primer envío no funciona')]),
    ]
    return page('getting-started.html', PAGE_TITLES['getting-started.html'][1],
                'Volumen 1', 'Primeros pasos',
                'Instalar las clases, registrar la plantilla y sacar un mensaje de un '
                'programa Clarion en unas veinte líneas.',
                ['Sin DLL que distribuir', 'Sin .NET', 'SMTP + OAuth2 + REST', 'Clarion 10 &ndash; 12'],
                groups, body)


# =====================================================================
#  2  GUÍA DEL PROGRAMADOR
# =====================================================================
def build_programmers_guide():
    B = []
    add = B.append

    add(h2('model', 'El modelo de objetos'))
    add(p('Un objeto es suyo. Todo lo que cuelga de él se construye y se libera solo.'))
    add(code(S_OWNS))
    add(p('La separación es deliberada, y es la razón por la que emailTo no necesita '
          'ninguna librería de terceros. <b>EmailNetClass</b> es lo único que toca C: '
          'sockets, el handshake de SCHANNEL, WinHTTP, DPAPI, SHA-256. '
          '<b>EmailMsgClass</b> es Clarion puro y no sabe nada de redes: convierte '
          'campos en un documento RFC 5322. <b>EmailToClass</b> une los dos: tiene una '
          'cuenta y sabe cuatro maneras de entregar los bytes que produjo la clase del '
          'mensaje.'))
    add(note('note', 'Por qué la clase del mensaje no sabe de sockets',
             '<p>Porque los cuatro transportes quieren los mismos bytes. SMTP los '
             'escribe después de <code>DATA</code>, la API de Gmail los codifica en '
             'base64url dentro de un campo JSON, Graph los publica como texto en '
             'base64, y Mailgun los sube como archivo. Se construye el MIME una vez y '
             'cada transporte es una envoltura delgada.</p>'))

    add(h2('account', 'La cuenta'))
    add(p('<code>Mailer.Acc</code> es un <code>GROUP</code>, y es el contrato entre la '
          'clase y donde sea que usted guarde su configuración. La plantilla asigna una '
          'columna de tabla a cada campo. Los que más importan:'))
    add(table(['Campo', 'Qué decide'], [
        ['<code>Transport</code>', 'SMTP, API de Gmail, Graph, o una clave API del proveedor.'],
        ['<code>Provider</code>', 'Qué preajuste llenó lo demás, y qué forma de API hablar.'],
        ['<code>Host</code> / <code>Port</code> / <code>Security</code>', 'La conexión SMTP.'],
        ['<code>AuthMode</code>', 'Nada, AUTH LOGIN, AUTH PLAIN, o un token OAuth2.'],
        ['<code>UserName</code> / <code>Password</code>', 'La credencial, cuando es una contraseña.'],
        ['<code>ClientId</code> / <code>TenantId</code>', 'La aplicación registrada, cuando es OAuth2.'],
        ['<code>RefreshToken</code>', 'Lo que hace que el segundo envío no necesite navegador.'],
        ['<code>ApiKey</code> / <code>ApiDomain</code>', 'SendGrid, Mailgun, Resend, Brevo, Postmark, Mailjet.'],
        ['<code>VerifyCert</code>', 'Déjelo en 1 salvo que el servidor sea suyo y con certificado propio.'],
    ]))
    add(p('<code>SetProvider</code> llena servidor, puerto, seguridad y autenticación '
          'para catorce proveedores, así que una cuenta suelen ser tres líneas: el '
          'proveedor, la dirección y la credencial.'))

    add(h2('composing', 'Armar un mensaje'))
    add(p('Los destinatarios entran de uno en uno con <code>AddTo</code> / '
          '<code>AddCc</code> / <code>AddBcc</code>, o todos juntos con '
          '<code>AddList</code>, que acepta la forma en que la gente los escribe de '
          'verdad: separados por <code>;</code> o <code>,</code>, con los espacios de '
          'más que sean.'))
    add(p('<b>La copia oculta se comporta como debe.</b> Una dirección en Bcc se agrega '
          'al sobre como un <code>RCPT TO</code> más y deliberadamente <em>no</em> se '
          'escribe en los encabezados, así que los demás destinatarios nunca la ven.'))
    add(p('Los cuerpos se fijan con <code>SetText</code> y <code>SetHtml</code>, y se '
          'amplían con <code>AddText</code> y <code>AddHtml</code>. Los adjuntos vienen '
          'del disco con <code>Attach</code>, de memoria con <code>AttachData</code>, y '
          'una imagen a la que se refiere el HTML entra con '
          '<code>AttachInline</code>:'))
    add(code(S_INLINE))

    add(h2('accents', 'Los acentos, y por qué sobreviven'))
    add(p('Un <code>STRING</code> de Clarion guarda bytes Windows-1252. Enviado tal '
          'cual, <i>Factura Número</i> llega hecho un desastre, porque nada le dijo al '
          'lector qué significaban esos bytes.'))
    add(p('emailTo convierte el asunto, los nombres visibles, los cuerpos y los nombres '
          'de archivo adjuntos a <b>UTF-8</b> y los etiqueta. Los encabezados se '
          'envuelven en palabras codificadas RFC 2047 partidas en los límites de '
          'carácter &mdash; nunca a la mitad de uno &mdash; y los cuerpos salen en '
          'quoted-printable. Una nota sencilla en inglés sigue saliendo como texto '
          '<code>7bit</code> legible, porque el codificador sólo recurre a '
          'quoted-printable cuando el contenido, o una línea de 998 bytes, de verdad lo '
          'necesita.'))
    add(usecode("Mailer.Msg.CharSet = ETChs:Ansi   ! mandar los bytes crudos como windows-1252"))

    add(h2('transports', 'Elegir un transporte'))
    add(table(['Transporte', 'Cuándo es el correcto'], [
        ['<code>ETTrn:Smtp</code>',
         'Casi siempre. Cualquier servidor, cualquier proveedor que todavía acepte una '
         'contraseña o que soporte XOAUTH2.'],
        ['<code>ETTrn:GmailApi</code>',
         'Una cuenta de Google donde prefiere no habilitar SMTP. Requiere OAuth2.'],
        ['<code>ETTrn:GraphApi</code>',
         'Inquilinos de Microsoft 365 con SMTP AUTH deshabilitado, que cada vez son '
         'más.'],
        ['<code>ETTrn:ApiKey</code>',
         'Una aplicación desplegada que sólo tiene que enviar, en una red donde el '
         'puerto 587 puede estar bloqueado.'],
    ]))
    add(p('Cambiar es un campo. El mensaje, los adjuntos y el manejo de errores son '
          'idénticos:'))
    add(usecode("Mailer.Acc.Transport = ETTrn:GraphApi"))

    add(h2('oauth', 'OAuth2, de principio a fin'))
    add(p('Google y Microsoft ya no aceptan una contraseña común desde un programa de '
          'escritorio. El flujo que corre emailTo es el de código de autorización con '
          'PKCE, que es el que ellos documentan para aplicaciones nativas:'))
    add('<ol class="b">'
        '<li>Inventar un <b>verificador</b> al azar y sacarle SHA-256 para obtener un '
        '<b>desafío</b>.</li>'
        '<li>Abrir un escucha en '
        '<code>http://127.0.0.1:&lt;un puerto libre&gt;/</code>, antes que el '
        'navegador, para que no se pierda ninguna redirección.</li>'
        '<li>Abrir el navegador del propio usuario en la pantalla de consentimiento del '
        'proveedor, llevando el desafío y un <b>state</b> al azar.</li>'
        '<li>Atrapar la redirección, comprobar que el state coincide, y cambiar el '
        'código devuelto más el verificador por un <b>token de acceso</b> y un '
        '<b>token de refresco</b>.</li>'
        '</ol>')
    add(code(S_OAUTHFLOW))
    add(note('tip', 'Un ID de cliente de escritorio no es un secreto',
             '<p>Para eso es PKCE. Los clientes públicos de Microsoft no deben mandar '
             '<em>ningún</em> secreto de cliente, y emailTo sólo manda uno cuando la '
             'cuenta realmente lo tiene. En su <code>.EXE</code> no queda compilado '
             'nada confidencial.</p>'
             '<p>Regístrelo en <b>console.cloud.google.com</b> &rarr; Credenciales '
             '&rarr; ID de cliente de OAuth &rarr; <b>Aplicación de escritorio</b>, o '
             'en <b>portal.azure.com</b> &rarr; Registros de aplicaciones &rarr; '
             '<b>Cliente público</b> con redirección '
             '<code>http://localhost</code>.</p>'))
    add(p('Después del primer consentimiento nadie vuelve a ver un navegador. '
          '<code>EnsureToken</code> corre antes de cada envío: si el token de acceso '
          'todavía sirve no hace nada, si venció gasta el token de refresco en '
          'silencio, y sólo cuando ya no queda token de refresco le pide al usuario que '
          'inicie sesión.'))
    add(note('warn', 'Google sólo emite token de refresco si se le pide bien',
             '<p>Necesita <code>access_type=offline</code> <em>y</em> '
             '<code>prompt=consent</code>, y sin ellos el segundo envío falla sin causa '
             'aparente. emailTo manda los dos. Microsoft en cambio <b>rota</b> el token '
             'de refresco en cada uso, así que hay que guardar el nuevo cada vez, que es '
             'por lo que <code>Refresh</code> lo vuelve a escribir.</p>'))

    add(h2('api', u'Una clase, nueve proveedores'))
    add(p(u'<code>EmailToClass</code> responde a una pregunta: envía esto. '
          u'<code>EmailApiClass</code> responde a todas las demás &mdash; quién está '
          u'bloqueado, qué pasó el mes pasado, qué contactos y campañas hay &mdash; y '
          u'las responde igual sea cual sea el proveedor con el que usted se dio de '
          u'alta.'))
    add(p(u'No tiene nada propio. <code>Init(Mailer)</code> toma prestadas la cuenta y '
          u'la capa HTTPS, así que la clave que selló la ventana de configuración es la '
          u'que usan estas llamadas, y no hay una segunda copia de ninguna credencial '
          u'en ninguna parte del programa.'))
    add(code(S_ASK))
    add(p(u'Por dentro son tres capas, y sólo la del medio sabe algo de un proveedor:'))
    add(table([u'Capa', u'Qué es', u'¿Sabe de proveedores?'], [
        [u'<code>BuildMap()</code>', u'La matriz. Una fila por operación y proveedor.',
         u'Sí &mdash; y es lo único que lo sabe'],
        [u'<code>Fetch</code> / <code>Perform</code>',
         u'El motor: arma la dirección, la firma, sigue la paginación, analiza, mapea.',
         u'No'],
        [u'<code>GetXxx</code> / <code>AddXxx</code>',
         u'Los métodos públicos. Ponen los argumentos y llaman al motor.', u'No'],
    ]))

    add(h2('api-matrix', u'La matriz'))
    add(p(u'Añadir un proveedor es añadir filas, no escribir ramas. Una fila dice: para '
          u'ESTE proveedor y ESTA operación, use este verbo y esta dirección, la lista '
          u'está en esta ruta de la respuesta, y estos miembros JSON llenan estas '
          u'columnas.'))
    add(code(S_MATRIX))
    add(p(u'Las piezas de una fila:'))
    add(table([u'Pieza', u'Qué significa'], [
        [u'<code>{scheme}{host}</code>',
         u'La dirección del proveedor, respetando <code>ApiRegion</code> (eu) y '
         u'<code>ApiBase</code> (lo que usted diga, esquema incluido).'],
        [u'<code>{limit} {offset} {page}</code>',
         u'Los llena el bucle de paginación, una y otra vez, hasta que el proveedor se '
         u'queda sin filas.'],
        [u'<code>{email} {id} {text} {subject} {html}</code>',
         u'Sus datos. Codificados con % en una URL y escapados como JSON en un cuerpo '
         u'&mdash; el motor sabe cuál de los dos está armando.'],
        [u'<code>{ymdfrom} {isofrom} {epochfrom} {rfcfrom}</code>',
         u'El mismo rango de fechas en las cuatro escrituras que quieren los ocho.'],
        [u'la ruta del elemento', u'Dónde está el arreglo de filas: vacío significa que '
         u'la respuesta ES el arreglo, <code>*</code> que la respuesta es UN elemento. '
         u'Una ruta que resulte no estar ahí cae en el primer arreglo del documento.'],
        [u'el mapa', u'Pares <code>Columna=origen</code>. Un origen puede ser una ruta '
         u'(<code>reason.message</code>), ofrecer alternativas '
         u'(<code>recipient.email|email</code>), ser un literal '
         u'(<code>!spam report</code>) y llevar un convertidor de fecha: '
         u'<code>#</code> unix, <code>@</code> ISO-8601, <code>%</code> RFC-2822, '
         u'<code>$</code> un día suelto.'],
    ]))
    add(note('info', u'ETSup:All en una fila de lista significa algo concreto',
             u'<p>Los proveedores parten sus listas de bloqueo de dos maneras. SendGrid '
             u'guarda cinco separadas y cada fila se registra con su propio tipo. '
             u'Brevo, Postmark y SparkPost guardan UNA sola y etiquetan cada entrada, '
             u'así que su fila se registra con <code>ETSup:All</code> &mdash; y '
             u'entonces el motor deduce el tipo real de cada fila de las palabras del '
             u'propio proveedor (<code>hardBounce</code>, '
             u'<code>SpamNotification</code>, <code>policy_suppression</code>) con '
             u'<code>SuppKindOf()</code>. Pídale un tipo a cualquiera de los dos y '
             u'recibe ese tipo.</p>'))

    add(h2('api-queues', u'Las respuestas normalizadas'))
    add(p(u'Cada lectura llena una cola que se ve igual conteste quien conteste. Ése es '
          u'el trato completo: las diferencias se absorben en la matriz, y su código no '
          u'llega a aprenderlas nunca.'))
    add(note('cla', u'Amazon es el que no acepta una clave en una cabecera',
             u'<p>SES firma la petición &mdash; verbo, ruta, consulta, cabeceras y un '
             u'hash del cuerpo &mdash; con una clave derivada del secreto, la fecha, la '
             u'región y el servicio. Por eso <code>EmailNetClass</code> ganó '
             u'<code>SignAws</code>, <code>Hmac256</code> y los demás: están junto al '
             u'SHA-256 sobre el que se construyen, y tanto enviar como preguntar usan '
             u'los mismos. Cada pieza está comprobada contra un vector que publican el '
             u'RFC 4231 o Amazon.</p>'
             u'<p>Ponga el <b>access key id</b> de AWS en Second key y el <b>secreto</b> '
             u'en la clave de API. User name y Password quedan libres para las '
             u'credenciales SMTP, muy distintas, que SES también emite, de modo que una '
             u'cuenta puede hacer las dos cosas. La región forma parte de la firma, así '
             u'que tiene que ser la correcta &mdash; en blanco significa '
             u'<code>us-east-1</code>.</p>'))
    add(table([u'Cola', u'Qué hay en una fila'], [
        [u'<code>SuppQ</code>', u'Address, Kind, KindName, Reason, Code, WhenDate, '
         u'WhenTime, Id, Sender, Raw'],
        [u'<code>StatQ</code>', u'WhenDate, Requests, Delivered, Opens, UniqueOpens, '
         u'Clicks, UniqueClicks, HardBounces, SoftBounces, Blocks, SpamReports, '
         u'Unsubscribed, Invalid'],
        [u'<code>EventQ</code>', u'WhenDate, WhenTime, Address, EventName, Reason, '
         u'Subject, MessageId, Link'],
        [u'<code>ContactQ</code> <code>ListQ</code> <code>CampaignQ</code>',
         u'Id, Address, Name, Blocked, Unsubscribed &hellip; / Id, Name, Members '
         u'&hellip; / Id, Name, Subject, Status &hellip;'],
        [u'<code>TemplateQ</code> <code>SenderQ</code> <code>DomainQ</code> '
         u'<code>HookQ</code>', u'Lo mismo para el resto de la cuenta'],
    ]))
    add(p(u'<code>SuppQ.Raw</code> conserva el objeto original del proveedor para esa '
          u'fila, así que lo que la cola no tiene columna para guardar sigue estando '
          u'ahí cuando haga falta registrar la entrada que se ve rara.'))
    add(note('warn', u'Un LIST no puede apuntar a estas colas',
             u'<p><code>FROM(MailApi.SuppQ)</code> compila y luego truena al primer '
             u'dibujado: son REFERENCIAS a cola, y el control se liga a la variable de '
             u'referencia. Copie las filas a un <code>QUEUE</code> local de verdad para '
             u'mostrarlas &mdash; que es donde va a querer formatear las fechas de '
             u'todos modos. <code>Manage()</code> hace exactamente eso, y la '
             u'demostración lo enseña.</p>'))

    add(h2('api-paging', u'Paginación, de tres maneras'))
    add(p(u'Una lista de bloqueados no cabe en una página, y los nueve proveedores no se '
          u'ponen de acuerdo en cómo recorrerla. El motor se ocupa de las tres sin que '
          u'quien llama se entere:'))
    add(table([u'Estilo', u'Quién', u'Qué hace el motor'], [
        [u'límite y desplazamiento', u'SendGrid, Brevo, Mailjet, Postmark',
         u'Vuelve a pedir con el desplazamiento avanzado, y para cuando una página '
         u'vuelve más corta que el tamaño de página.'],
        [u'número de página', u'SparkPost, MailerSend',
         u'Lo mismo, contado en páginas en vez de en filas.'],
        [u'un cursor', u'Mailgun',
         u'Sigue la dirección que la respuesta trae en <code>paging.next</code>, y para '
         u'cuando una página vuelve vacía.'],
        [u'un token de continuación', u'Amazon SES',
         u'Devuelve el token como un parámetro que se llama igual que la ruta por la '
         u'que llegó, así que la fila de la matriz dice <code>NextToken</code> y el '
         u'motor no necesita saber nada de Amazon.'],
    ]))
    add(p(u'<code>PageSize</code> dice cuántas pedir de una vez y <code>MaxRows</code> '
          u'es la guarda &mdash; 5000 por omisión, 0 para no poner límite. Cien mil '
          u'direcciones suprimidas es algo real en un remitente grande, y leerlas todas '
          u'en memoria debería ser una decisión, no una sorpresa.'))
    add(note('tip', u'Que una lista falle no pierde las demás',
             u'<p>Pedirle todo a SendGrid son cinco peticiones. Si una falla &mdash; un '
             u'endpoint que el plan de esa cuenta no abre, un permiso que la clave no '
             u'tiene &mdash; las otras cuatro siguen contestando, y el fallo queda en '
             u'<code>LastErrorText</code>. Una respuesta parcial sirve muchísimo más '
             u'que ninguna.</p>'))

    add(h2('api-add', u'Añadir un proveedor'))
    add(p(u'<code>BuildMap</code> es VIRTUAL, así que un proveedor que la matriz de '
          u'fábrica no conoce no obliga a tocar ningún archivo de los que emailTo '
          u'entrega:'))
    add(code(S_ADDPROVIDER))
    add(p(u'Ponga <code>Acc.Provider</code> en <code>ETPrv:Custom</code> y '
          u'<code>Acc.ApiBase</code> en el host, y todos los métodos de arriba '
          u'funcionan contra él &mdash; incluida <code>Manage()</code>, que lee '
          u'<code>Supports()</code> para decidir qué pestañas ofrecer.'))
    add(p(u'Para una llamada suelta que no merece una fila, <code>RawCall()</code> '
          u'firma la petición con esta cuenta y le devuelve el estado; la respuesta '
          u'está en <code>Net.Body()</code>, y <code>Json</code> está ahí mismo para '
          u'analizarla.'))

    add(h2('settings', 'Dónde vive la configuración'))
    add(p('<code>LoadAccount</code> y <code>SaveAccount</code> son '
          '<code>VIRTUAL</code>. De fábrica leen y escriben un INI junto al '
          '<code>.EXE</code>, que alcanza para una demostración y para un programa de '
          'un solo usuario. Señale una tabla en la extensión global y la plantilla los '
          'reemplaza con código de esta forma:'))
    add(code(S_TABLE))
    add(p('Los dos métodos abren y cierran el archivo alrededor de su propio trabajo '
          'con el FileManager de ABC, cuyos <code>Open</code> y <code>Close</code> '
          'llevan cuenta de referencias, así que da igual si la tabla ya estaba abierta '
          'en otra parte del programa.'))

    add(h2('accounts', u'Varias cuentas, un solo programa'))
    add(p(u'Una cuenta tiene <b>nombre</b>, y el almacén guarda una configuración por '
          u'nombre. Nada se comparte entre ellas — proveedor, clave, región, dominio, '
          u'forma de autenticarse, todo pertenece a la cuenta — así que un programa '
          u'puede quedar configurado para SendGrid y Brevo a la vez, y cambiar de una a '
          u'otra en una línea:'))
    add(code(S_ACCOUNTS))
    add(p(u'Con un INI la cuenta predeterminada es la sección <code>[emailTo]</code> y '
          u'una con nombre es <code>[emailTo_brevo]</code>. Con una tabla es una fila por '
          u'nombre, buscada por la clave de la columna del nombre. A un INI no se le '
          u'puede preguntar qué secciones tiene, así que las que llevan nombre mantienen '
          u'un índice en la sección base que <code>SaveAccount</code> actualiza; una '
          u'tabla simplemente se recorre. Por eso <code>ListAccounts</code> y '
          u'<code>DeleteAccount</code> son <code>VIRTUAL</code> como los otros dos: '
          u'sólo el código generado sabe leer su tabla.'))
    add(table([u'Método', u'Qué hace'], [
        ['<code>LoadAccount(name)</code>', u'Cambia a esa cuenta. Sin argumento, la '
         u'predeterminada sin nombre.'],
        ['<code>SaveAccount()</code>', u'Escribe bajo <code>Acc.Name</code>. Un nombre que '
         u'nadie usó todavía crea una segunda cuenta.'],
        ['<code>ListAccounts()</code>', u'Llena <code>AccountQ</code> con cada cuenta del '
         u'almacén — nombre, proveedor, texto del proveedor y dirección — y contesta '
         u'cuántas hay. La fila 1 es la predeterminada sin nombre.'],
        ['<code>DeleteAccount(name)</code>', u'Olvida una. La predeterminada sin nombre no '
         u'se puede borrar.'],
        ['<code>RememberAccount(name)</code>', u'Con cuál abrir la próxima vez.'],
        ['<code>PreferredAccount(fallback)</code>', u'Ese nombre, o el de reserva si nunca '
         u'se fijó, o si la cuenta que nombra ya fue borrada.'],
    ]))
    add(note('note', u'La ventana de configuración hace todo esto sin código',
             u'<p>Encima de las pestañas lleva <b>Cuenta:</b>, una lista desplegable con '
             u'todo lo guardado, con <b>Cargar</b> y <b>Quitar</b>; y <b>Guardar como:</b> '
             u'debajo, donde un nombre nuevo crea una segunda cuenta. Cargar o guardar una '
             u'la recuerda, y la línea de arranque generada es '
             u'<code>LoadAccount(PreferredAccount(&#39;default&#39;))</code>, así que un '
             u'programa cambiado a un segundo proveedor vuelve a abrir con él.</p>'))

    add(h2('secrets', 'Los secretos guardados'))
    add(p('Cuatro campos nunca se guardan en claro: la contraseña, el secreto de '
          'cliente, el token de refresco y la clave API. Cada uno pasa por '
          '<code>Seal()</code>: DPAPI lo cifra para el usuario actual de Windows, y '
          'luego base64 deja el resultado apto para una columna de texto.'))
    add(usecode("Set:Password = Mailer.Seal(Loc:Typed)      ! 'dpapi:AQAAANCMnd8BFdERjHoAwE...'"))
    add(p('Una fila copiada a otra máquina, o leída por otro usuario de Windows, se '
          'descifra en nada. Dele tamaño de sobra a esas columnas: el valor guardado es '
          'tres o cuatro veces más largo que lo que se escribió.'))
    add(note('note', 'Una contraseña escrita a mano en la columna igual funciona',
             '<p><code>Unseal()</code> reconoce un valor que no es de los suyos y lo '
             'devuelve tal cual, lo que hace fácil sembrar una fila de prueba. Una '
             'máquina sin DPAPI recibe un prefijo <code>plain:</code>, para que nadie '
             'lo confunda con algo cifrado.</p>'))

    add(h2('errors', 'Los errores, y el registro'))
    add(p('Todo método público contesta <code>1</code> si funcionó y <code>0</code> si '
          'no, y deja el motivo en <code>LastErrorText</code> como una frase que se le '
          'puede mostrar al usuario. <code>LastServerReply</code> guarda lo último que '
          'dijo el servidor, que casi siempre es más específico que cualquier cosa que '
          'emailTo pudiera inventar.'))
    add(usecode("IF NOT Mailer.Send(Mailer.Msg) THEN Mailer.ShowError()."))
    add(p('Con <code>Trace</code> encendido, toda la conversación queda en '
          '<code>Mailer.Net.TraceQ</code> y se muestra en la pestaña Registro de la '
          'ventana de configuración. Las credenciales se ocultan antes de llegar ahí, '
          'así que un cliente puede mandarle el registro de un envío fallido sin '
          'mandarle su contraseña.'))
    add(note('danger', 'Un LIST no se puede apuntar directo a TraceQ',
             '<p><code>TraceQ</code> es una <em>referencia</em> a cola, y '
             '<code>FROM(Mailer.Net.TraceQ)</code> liga el control a la variable de '
             'referencia en vez de a la cola. La ventana entonces truena en su primer '
             'dibujado. Copie a una <code>QUEUE</code> local de verdad para mostrarla, '
             'como hacen la demostración y la ventana de configuración.</p>'))

    add(h2('deriving', 'Hacer que haga otra cosa'))
    add(p('Los métodos que vale la pena sobrescribir están marcados '
          '<code>VIRTUAL</code>: <code>Txt</code> para un tercer idioma, '
          '<code>LoadAccount</code> / <code>SaveAccount</code> para su propio almacén, '
          'y los cuatro métodos <code>Send*</code> para bitácora, limitación de ritmo o '
          'una política de reintentos.'))
    add(code(S_DERIVE))

    add(h2('notes', 'Notas de Clarion'))
    add(p('Esto no son comportamientos de emailTo: son de Clarion. Cada uno costó '
          'tiempo real de encontrar mientras se construía esto, y cada uno es de esos '
          'que no se ven hasta que muerden.'))

    add(h3('note-clear', 'Un método llamado Clear rompe CLEAR() en todas partes'))
    add(p('Un miembro de clase cuya etiqueta coincide con una intrínseca de Clarion '
          'redefine esa intrínseca para <em>cada módulo que incluya el archivo</em>. El '
          'compilador dice <code>Redefining system intrinsic: CLEAR</code> en el '
          'include, y después <code>CLEAR(UnaVariable)</code> en código que no tiene '
          'nada que ver con su clase deja de compilar.'))
    add(code(S_CLEARTRAP))
    add(p('Por eso las clases de buffer y de mensaje tienen <code>ClearAll</code>. '
          '<code>RESET</code>, <code>ADD</code>, <code>LEN</code> y <code>FREE</code> '
          'son los otros nombres de los que hay que alejarse.'))

    add(h3('note-brace', u'Una llave dentro de un literal hay que duplicarla'))
    add(p(u'<code>{</code> abre el escape de repetici&oacute;n de Clarion: '
          u'<code>&#39;ab{3}&#39;</code> es <code>&#39;abbb&#39;</code>. Clarion 12 deja pasar '
          u'como texto una llave que no lleva d&iacute;gitos detr&aacute;s, as&iacute; que un '
          u'literal JSON escrito a mano compila ah&iacute; y en ninguna otra versi&oacute;n: '
          u'Clarion 10 y 11 rechazan el literal entero con <code>Invalid string (misused '
          u'&lt;...&gt; or {...}, or literal is too long)</code>. La forma portable es '
          u'<code>{{</code>, y es una sola llave en todas las versiones.'))
    add(code(S_BRACETRAP))
    add(p(u'Aqu&iacute; importa porque este juego de clases escribe JSON a mano y lleva las '
          u'plantillas de URL de nueve proveedores. Si deriva <code>BuildMap()</code> para '
          u'a&ntilde;adir un proveedor propio, duplique las llaves de la URL que pase a '
          u'<code>Row()</code>: los marcadores se expanden igual que antes.'))

    add(h3('note-string', 'Un STRING ligado a una variable necesita una picture'))
    add(p('Escrito con un literal en su lugar, el control sobrevive solo, y luego '
          'truena dentro de <code>OPEN(Window)</code> en cuanto la misma ventana tiene '
          'también un <code>LIST</code>. No se dibuja nada, así que en pantalla no hay '
          'ninguna pista de qué control tiene la culpa.'))
    add(code(S_STRINGTRAP))
    add(p('La forma de encontrar uno así es abrir variantes de la ventana quitando un '
          'control cada vez: la variante que sí abre señala al culpable. Aquí lo '
          'arreglaban dos supresiones distintas &mdash; el LIST, o los STRING ligados '
          '&mdash; que es lo que dijo que era la combinación y no uno de los dos.'))

    add(h3('note-picture', 'Ninguna picture de Clarion pasa de @s255'))
    add(p('<code>ENTRY(@s512)</code> es error de compilación: <code>Invalid picture '
          'token</code>. En una cadena <code>FORMAT</code> es peor, porque '
          '<code>FORMAT</code> para el compilador es sólo texto y no se reporta nada. '
          'Deje los formatos de lista en <code>@s255</code> y dele una variable más '
          'ancha al ENTRY si la necesita.'))

    add(h3('note-map', 'Un módulo MEMBER sin MAP pierde las intrínsecas'))
    add(p('Un <code>MAP</code> a nivel de módulo es lo que trae <code>BUILTINS.CLW</code>. '
          'Sin uno &mdash; aunque esté vacío &mdash; <code>CLIP</code>, '
          '<code>CHOOSE</code> y las demás vuelven como <code>Unknown function '
          'label</code>, decenas de veces, que se lee como un include corrupto y no '
          'como cuatro líneas que faltan.'))
    add(code("  MEMBER\n\n  INCLUDE('EmailToClass.INC'),ONCE\n\n  MAP\n  END"))

    add(h3('note-return', 'Un método que devuelve STRING no puede liberar su propio buffer'))
    add(p('La copia ocurre en el <code>RETURN</code>, así que cualquier cosa que se '
          'libere antes ya no está cuando el llamador la ve. El buffer tiene que '
          'sobrevivir al retorno, y eso quiere decir que es del objeto; y cada '
          'codificador necesita el suyo, porque se anidan.'))
    add(code(S_RETSTR))

    add(h3('note-crlf', 'Las fuentes de Clarion tienen que ser CRLF'))
    add(p('Un include sólo con LF se interpreta mal como <code>Illegal data type: '
          '&lt;CLASS&gt;</code> en la <em>declaración</em>, sin marcar nada dentro del '
          'include. Ojo con que <code>sed -i</code> quita el CR y escribe LF, así que '
          'una edición de una línea basta para romper un archivo que compilaba hace un '
          'minuto.'))

    add(h3('note-schannel', 'SCHANNEL pide un certificado de cliente que usted no tiene'))
    add(p('El SMTP de Google, y Office 365, piden un certificado de cliente '
          '<em>opcional</em>. Sin certificado en la credencial, '
          '<code>InitializeSecurityContext</code> devuelve '
          '<code>SEC_I_INCOMPLETE_CREDENTIALS</code> (<code>0x00090320</code>) en vez '
          'de continuar, y el handshake se detiene. La solución es volver a emitir el '
          'mismo token &mdash; repetir sin leer más datos &mdash; y el handshake '
          'termina de forma anónima. Sin eso, toda conexión a Gmail falla.'))

    add(h3('note-dot', 'El punto solitario'))
    add(p('En SMTP, una línea que sólo tiene un <code>.</code> termina el mensaje. Una '
          'línea del cuerpo que legítimamente empiece con punto tiene entonces que '
          'mandarse con dos, y el servidor que recibe quita uno. Si esto sale mal, un '
          'mensaje se corta en silencio en la primera línea de ésas, que es justo la '
          'clase de cosa que nunca aparece en pruebas y luego le pasa a un cliente.'))

    add(nextcards(['template-guide.html', 'reference.html', 'getting-started.html']))

    body = '\n'.join(B)
    groups = [
        ('Cómo encaja', [('model', 'El modelo de objetos'), ('account', 'La cuenta')]),
        ('Armar un mensaje', [('composing', 'Armar un mensaje'),
                              ('accents', 'Los acentos')]),
        ('Sacarlo', [('transports', 'Elegir un transporte'),
                     ('oauth', 'OAuth2, de principio a fin')]),
        ('La API del proveedor', [('api', u'Una clase, nueve proveedores'),
                                  ('api-matrix', u'La matriz'),
                                  ('api-queues', u'Las respuestas normalizadas'),
                                  ('api-paging', u'Paginaci\u00f3n, de tres maneras'),
                                  ('api-add', u'A\u00f1adir un proveedor')]),
        ('Conservarlo', [('settings', 'Dónde vive la configuración'),
                         ('accounts', u'Varias cuentas, un solo programa'),
                         ('secrets', 'Los secretos guardados'),
                         ('errors', 'Los errores, y el registro'),
                         ('deriving', 'Hacer que haga otra cosa')]),
        ('Notas de Clarion', [('notes', 'Notas de Clarion'),
                              ('note-clear', 'Clear rompe CLEAR()'),
                              ('note-brace', u'Llaves en un literal'),
                              ('note-string', 'STRING necesita picture'),
                              ('note-picture', 'El tope de @s255'),
                              ('note-map', 'MEMBER necesita MAP'),
                              ('note-return', 'Devolver un STRING'),
                              ('note-crlf', 'CRLF'),
                              ('note-schannel', 'El certificado de cliente'),
                              ('note-dot', 'El punto solitario')]),
    ]
    return page('programmers-guide.html', PAGE_TITLES['programmers-guide.html'][1],
                'Volumen 2', 'Guía del programador',
                'Qué posee cada una de las cinco clases, cómo un mensaje se vuelve MIME, '
                'cómo corre OAuth2 de verdad, y el comportamiento de Clarion con el que '
                'tropezamos en el camino.',
                ['Modelo de objetos', 'MIME', 'OAuth2 + PKCE', 'Notas de Clarion'],
                groups, body)


# =====================================================================
#  3  GUÍA DE PLANTILLAS
# =====================================================================
def build_template_guide():
    B = []
    add = B.append

    add(h2('five', 'Las diez plantillas'))
    add(table(['Plantilla', 'Tipo', 'Para qué es'], [
        ['<b>emailTo - Global</b>', 'Extensión de aplicación',
         'Obligatoria, una vez por aplicación. Declara el objeto, fija los valores por '
         'omisión y genera el enlace con la tabla de configuración.'],
        ['<b>emailTo - Botón de correo</b>', 'Plantilla de control, MULTI',
         'Se arrastra a una ventana. Redactar, enviar de una vez, o abrir la ventana de '
         'la cuenta.'],
        ['<b>emailTo - Enviar un correo aquí</b>', 'Plantilla de código',
         'Cualquier embed: después de un reporte, en una opción de menú, dentro de un '
         'proceso por lotes.'],
        ['<b>emailTo - Abrir la ventana de redacción aquí</b>', 'Plantilla de código',
         'La ventana de escribir y enviar, opcionalmente prellenada.'],
        ['<b>emailTo - Abrir la ventana de configuración aquí</b>', 'Plantilla de código',
         'La ventana de la cuenta, para un menú de configuración.'],
        ['<b>emailTo - Provider API</b>', 'Extensión de aplicación',
         'Se agrega una vez. Declara el objeto que lee la lista de bloqueados, las '
         'estadísticas, los contactos y las campañas.'],
        ['<b>emailTo - Sync provider data into your tables</b>', 'Extensión de aplicación',
         'Se agrega una vez. Escribe todo eso en tablas suyas.'],
        ['<b>emailTo - Mail account button</b>', 'Plantilla de control, MULTI',
         'Se arrastra a una ventana. Abre la ventana de gestión: direcciones '
         'bloqueadas y por qué, estadísticas, actividad, contactos, campañas.'],
        ['<b>emailTo - Ask the provider</b>', 'Plantilla de código',
         'Cualquier embed: cargar la lista de bloqueados, desbloquear una o todas, '
         'consultar una dirección, leer las estadísticas, enviar una campaña, '
         'sincronizar las tablas.'],
        ['<b>emailTo - Sync mail data into your tables</b>', 'Plantilla de control, MULTI',
         'Se arrastra a una ventana. Baja la lista de bloqueados, las estadísticas, '
         'la actividad, los contactos, las listas y las campañas a sus tablas.'],
    ]))
    add(note('tip', 'Sólo la primera es obligatoria',
             '<p>Agregue <b>emailTo - Global</b> y los dos objetos existen en todas '
             'partes. Las otras siete son comodidades que los llaman: cualquier cosa que '
             'hagan, usted la puede hacer desde un embed escrito a mano con las mismas '
             'llamadas de una línea.</p>'))

    add(h2('global', 'emailTo - Global'))
    add(p('Propiedades globales &rarr; Extensiones &rarr; Insertar. Seis pestañas.'))

    add(h3('global-general', 'General'))
    add(table(['Campo', 'Por omisión', 'Qué hace'], [
        ['Deshabilitar esta plantilla', 'apagado',
         'No genera absolutamente nada. Sirve para acotar un problema de compilación.'],
        ['Nombre del objeto', '<code>Mailer</code>',
         'La etiqueta a la que se refieren todas las demás plantillas.'],
        ['Idioma', 'Inglés',
         'Fija <code>emailToLanguage</code>, que el objeto lee al arrancar.'],
        ['Guardar registro de la conversación', 'encendido',
         'Fija <code>Trace</code>. Las contraseñas se ocultan antes de llegar ahí.'],
    ]))

    add(h3('global-account', 'Cuenta'))
    add(p('Los valores con los que arranca el objeto. Si señala una tabla de '
          'configuración, lo que ella tenga los reemplaza al arrancar y la ventana de '
          'configuración escribe los cambios de vuelta; sin tabla, éstos <em>son</em> '
          'la configuración y la ventana guarda en un INI.'))
    add(table(['Campo', 'Notas'], [
        ['Proveedor', 'Dieciséis preajustes. Elegir uno llena servidor, puerto, seguridad '
         'y autenticación.'],
        ['Enviar usando', 'SMTP, API de Gmail, Microsoft Graph, o clave API del proveedor.'],
        ['Dirección / nombre del remitente / Responder a',
         'Se usan cuando el mensaje no trae los suyos.'],
        ['Servidor / Puerto / Seguridad', 'Sólo para el transporte SMTP.'],
        ['Autenticarse con', 'Nada, AUTH LOGIN, AUTH PLAIN, u OAuth2 XOAUTH2.'],
        ['Usuario / Contraseña',
         'Una contraseña escrita aquí queda compilada dentro del <code>.EXE</code>.'],
    ]))
    add(note('warn', 'Una contraseña en esta pestaña está en su ejecutable',
             '<p>Cualquiera que tenga el <code>.EXE</code> la tiene. Para algo que no '
             'publicaría, déjela vacía y deje que la guarde la ventana de '
             'configuración: por ese camino pasa por DPAPI para el usuario de '
             'Windows.</p>'))

    add(h3('global-signin', 'Acceso'))
    add(p('La aplicación OAuth2 y las claves API. El <b>ID de cliente</b> es el cliente '
          'de escritorio que registró con Google o Microsoft; no es un secreto. El '
          '<b>secreto de cliente</b> se queda vacío para clientes públicos de '
          'Microsoft. El <b>inquilino</b> es sólo de Microsoft: <code>common</code> '
          'acepta tanto una cuenta personal como una del trabajo, que es lo que '
          'necesita una aplicación que se le entrega a clientes desconocidos. El '
          '<b>dominio API</b> es sólo de Mailgun; para Mailjet la clave pública va en '
          'Usuario y la privada en Clave API.'))

    add(h2('global-sync', u'emailTo - Sync'))
    add(p(u'Una extensión de aplicación APARTE &mdash; <b>emailTo - Sync '
          u'provider data into your tables</b>, que se agrega una vez junto a la '
          u'global. La ventana de gestión pregunta al proveedor en vivo y no '
          u'guarda nada; ésta es la otra opción: nombre unas tablas y '
          u'las mismas respuestas se escriben además en sus propios datos '
          u'&mdash; así puede poner un browse ABC sobre la lista de '
          u'bloqueados, unirla con su tabla de clientes, o hacer un informe de '
          u'las aperturas del mes pasado sin acercarse a la red.'))
    add(note('tip', u'Hay un diccionario ya hecho &mdash; importe el .dctx',
             u'<p><code>emailToTables.dctx</code> viene junto a la plantilla y '
             u'contiene las seis tablas más la tabla de la cuenta. En el editor '
             u'de diccionario: <b>File &rarr; Import</b>, y elija la entrada '
             u'<b>DCTX / XML</b>.</p>'
             u'<p><b>No</b> <code>emailToTables.txd</code>. Un <code>.txd</code> '
             u'es el formato de Report Writer y el editor de diccionario lo '
             u'rechaza sin más &mdash; <i>"This TXD file is a Report Writer only '
             u'format"</i>. Se entrega sólo para <code>ClarionCL /di</code>, que '
             u'construye un diccionario entero a partir de texto en vez de '
             u'importar dentro de uno que ya existe.</p>'))
    add(table([u'Tabla', u'Una fila es', u'Se llena desde'], [
        [u'<code>MailBlocked</code>', u'Una dirección que el proveedor rechaza, '
         u'con el motivo, el código SMTP y cuándo', u'<code>GetSuppressions()</code>'],
        [u'<code>MailStat</code>', u'Un día', u'<code>GetStats()</code>'],
        [u'<code>MailEvent</code>', u'Algo que le pasó a un mensaje',
         u'<code>GetEvents()</code>'],
        [u'<code>MailContact</code>', u'Un contacto', u'<code>GetContacts()</code>'],
        [u'<code>MailList</code>', u'Una lista de contactos y su tamaño',
         u'<code>GetLists()</code>'],
        [u'<code>MailCampaign</code>', u'Una campaña y su estado',
         u'<code>GetCampaigns()</code>'],
    ]))
    add(p(u'Todas las tablas menos la de la cuenta llevan <code>Provider</code> '
          u'y <code>SyncedOn</code>, de modo que un diccionario sirve para una '
          u'aplicación que cambia de proveedor o que lleva dos cuentas.'))
    add(table([u'Campo', u'Qué hace'], [
        [u'Keep the provider''s data in tables',
         u'Enciende todo esto. Apagado, aquí no se genera nada.'],
        [u'Stamp each row with the provider and the date',
         u'Llena <code>Provider</code> y <code>SyncedOn</code> si la tabla los '
         u'tiene. Déjelo encendido salvo que una tabla sirva exactamente a una '
         u'cuenta.'],
        [u'Table / Key (seis veces)',
         u'La tabla, y la clave que identifica una fila &mdash; esa clave es lo '
         u'que hace que la sincronización actualice en vez de duplicar.'],
        [u'How many days back',
         u'Para las estadísticas y la actividad, que se piden por un rango de '
         u'fechas y no enteras.'],
    ]))
    add(note('info', u'Las columnas se emparejan por NOMBRE, no una por una',
             u'<p>Una tabla importada del diccionario que se entrega no necesita '
             u'ningún mapeo: la plantilla recorre las columnas de la tabla que '
             u'usted nombre y llena aquellas cuyo nombre reconoce. Una columna '
             u'que se llame de otra manera se deja en paz &mdash; así una '
             u'bandera suya, una nota, o un enlace a su fila de cliente '
             u'sobreviven a cada sincronización.</p>'
             u'<p>Eso también significa que puede apuntarla a una tabla que ya '
             u'tiene: nombre las columnas como lo hace el diccionario y las '
             u'llena.</p>'))
    add(p(u'Lo que genera es un objeto pequeño propio, con un solo método, '
          u'<code>Run</code>.'))
    add(note('warn', u'Por qué es una extensión aparte y no otra pestaña',
             u'<p>Una aplicación guarda el conjunto de campos con el que fue '
             u'construida. Un campo agregado a una extensión que la aplicación '
             u'<em>ya lleva</em> simplemente no está, y la generación se detiene '
             u'con <code>Unknown Variable</code> sobre un símbolo que el '
             u'programador nunca escribió &mdash; AppGen no rellena el DEFAULT '
             u'desde la línea de comandos.</p>'
             u'<p>Una aplicación que no agregue ESTA extensión nunca nombra esos '
             u'símbolos, así que todas las aplicaciones existentes siguen '
             u'generando igual que antes. Eso vale un Insert de más.</p>'
             u'<p>La pestaña <b>API del proveedor</b>, agregada a la extensión '
             u'global en la v1.03, no tiene esa protección: actualizar una '
             u'aplicación anterior a la v1.03 exige abrir una vez la hoja de '
             u'propiedades de esa extensión, para que el IDE vuelva a escribir '
             u'los campos nuevos. Desde un script que nunca abre el IDE, borre '
             u'la extensión y vuelva a insertarla.</p>'))
    add(code(S_SYNCGEN))
    add(p(u'Cada fila se busca por su clave antes de escribirla, así que correr '
          u'la sincronización dos veces no cambia nada: una fila que ya está se '
          u'actualiza, una nueva se agrega, y la cuenta vuelve igual. Eso es lo '
          u'que la hace segura en un botón que cualquiera puede pulsar dos '
          u'veces, o en un temporizador.'))

    add(h2('syncbutton', u'El botón de sincronizar'))
    add(p(u'<b>emailTo - Sync mail data into your tables</b> es una plantilla de '
          u'control: arrástrela a una ventana y coloca un botón ya cableado que '
          u'llama al método generado.'))
    add(table([u'Campo', u'Qué hace'], [
        [u'API object name', u'El objeto que declaró la extensión global.'],
        [u'Quietly - no message when it finishes',
         u'Apagado, informa cuántas filas bajaron y cuántas eran nuevas. '
         u'Enciéndalo para un botón que corre sin nadie delante.'],
        [u'Put the row count in', u'Una variable suya, para una línea de estado.'],
        [u'Reset the browse afterwards',
         u'Llama a <code>ResetFromFile()</code> sobre el browse que usted nombre, '
         u'para que un browse de la tabla sincronizada muestre las filas nuevas '
         u'sin que el usuario cierre la ventana.'],
    ]))
    add(p(u'Para una opción de menú o un proceso por lotes, la plantilla de '
          u'código <b>emailTo - Ask the provider</b> tiene <i>Sync it all into my '
          u'tables</i> entre sus operaciones.'))

    add(h3('global-table', 'Tabla, y Columnas de la tabla'))
    add(p('Señale una tabla y la plantilla genera <code>LoadAccount</code> y '
          '<code>SaveAccount</code> contra ella. Elija la clave con la que encuentra '
          'una cuenta, indique cuál cargar al arrancar, y luego asigne una columna a '
          'cada campo.'))
    add(p('Cada campo de columna es un selector: el botón <code>&hellip;</code> de al '
          'lado lista las columnas de la tabla que señaló, así que el mapeo se elige '
          'en vez de escribirse.'))
    add(table(['Campo', 'Notas'], [
        ['Tabla de configuración', 'Vacío significa usar un INI junto al <code>.EXE</code>.'],
        ['Clave para encontrar la cuenta', 'Se usa para el <code>GET</code> en los dos sentidos.'],
        ['Cuenta a cargar al arrancar', 'Vacío carga en su lugar el primer registro.'],
        ['Crear la fila si no existe',
         'Encendido, la ventana de configuración puede hacer <code>ADD</code> de la cuenta.'],
        ['Nombre de la cuenta', 'La única columna obligatoria.'],
        ['Todas las demás columnas',
         'Opcionales. Sin asignar, se conserva lo que puso la pestaña Cuenta.'],
    ]))
    add(note('note', 'Cuatro columnas tienen que ser anchas',
             '<p>Contraseña, secreto de cliente, token de refresco y clave API se '
             'guardan sellados, así que son tres o cuatro veces más largos que lo que '
             'se escribió. Póngalos de al menos 400 caracteres, y el token de refresco '
             'de 2000. <code>EmailTables.txt</code> trae una estructura lista para '
             'pegar en un diccionario.</p>'))

    add(h3('global-multidll', 'Multi-DLL'))
    add(p('Agregue la extensión a todas las aplicaciones de la suite y no toque la '
          'casilla. La aplicación dueña de los datos compila las clases y las exporta; '
          'las demás las importan. Las clases llevan la etiqueta '
          '<code>!ABCIncludeFile(EMAILTO)</code>, y registrar esa categoría le entrega '
          'todo el trabajo a la maquinaria de ABC: ella escribe las definiciones del '
          'proyecto y recorre el registro para armar el <code>.EXP</code>.'))
    add(code('#pragma define(_emailToDllMode_=>0)\n#pragma define(_emailToLinkMode_=>1)', 'dos'))
    add(p('Por eso en la plantilla no hay ningún símbolo con nombre decorado: agregue '
          'un método a una clase y la lista de exportación lo sigue en la siguiente '
          'generación. <code>emailc.c</code> se compila sólo dentro de la aplicación '
          'dueña de las clases, porque el <code>PRAGMA</code> vive en '
          '<code>EmailNetClass.clw</code>.'))

    add(h2('global-writes', 'Qué escribe la extensión global'))
    add(p('Sin tabla de configuración, dentro del módulo <code>PROGRAM</code>:'))
    add(code(S_GEN_GLOBAL))
    add(p('Con una, el objeto se declara <em>derivado</em>, y el enlace se escribe '
          'completo en <code>%ProgramProcedures</code>:'))
    add(code(S_GEN_DERIVED))
    add(note('note', 'Por qué derivar sigue funcionando en una suite',
             '<p>La instancia derivada se declara sólo en la aplicación que la posee. '
             'Las demás la importan como el tipo base y de todos modos alcanzan los '
             'métodos derivados, porque los dos son <code>VIRTUAL</code> y se despachan '
             'por la VMT del propio objeto.</p>'))

    add(h2('global-api', u'emailTo - Provider API'))
    add(note('warn', u'En la v1.03 era una pestaña de la extensión global',
             u'<p>Fue un error, y rompía toda aplicación construida antes de la '
             u'v1.03: una aplicación guarda el conjunto de campos con el que fue '
             u'construida, y AppGen no rellena uno agregado después &mdash; la '
             u'generación se detenía con <code>Unknown Variable %ETgApi</code>, sobre '
             u'un símbolo que nadie escribió.</p>'
             u'<p>Como extensión propia no puede hacer eso: una aplicación que no la '
             u'agrega nunca nombra sus símbolos. Si tenía la pestaña encendida en la '
             u'v1.03, inserte esta extensión y vuelva a poner el nombre del objeto '
             u'&mdash; lo que guardaba la pestaña vieja simplemente se ignora.</p>'))
    add(note('tip', u'Ahora las plantillas lo dicen solas',
             u'<p>Una ventana se genera antes que el módulo global, así que el '
             u'<b>botón de cuenta de correo</b> no puede saber, en el momento en que '
             u'escribe <code>MailApi.Manage(1)</code>, si algo va a declarar '
             u'<code>MailApi</code>. Anota lo que necesita; la extensión global lo '
             u'verifica cuando ya se conoce la aplicación entera.</p>'
             u'<p>Por eso desde la v1.07, un botón o un embed que llama a la API del '
             u'proveedor en una aplicación sin la extensión <b>Provider API</b> '
             u'detiene la generación con una sola línea que nombra el procedimiento '
             u'&mdash; en vez de un puñado de errores <code>Unknown function label</code> '
             u'y <code>Field not found: SUPPORTS</code> sobre código generado que '
             u'usted nunca escribió.</p>'))
    add(p(u'La pestaña que declara el segundo objeto. La misma clave que envía el '
          u'correo puede además contestar por la cuenta, así que aquí no hace falta '
          u'más que un nombre.'))
    add(table([u'Campo', u'Qué hace'], [
        [u'Add the management object',
         u'Declara <code>EmailApiClass</code> de forma global y le llama a '
         u'<code>Init</code> al arrancar, justo después de que el objeto de correo '
         u'haya cargado su cuenta. Activado por omisión.'],
        [u'Object name', u'Cómo se llama. <code>MailApi</code>, salvo que tenga un '
         u'motivo: las plantillas de control y de código también usan ese nombre por '
         u'omisión.'],
        [u'Rows per request', u'El tamaño de página. La clase sigue pidiendo hasta que '
         u'el proveedor se queda sin filas, así que esto no es un límite, sólo cuánto '
         u'llega de una vez.'],
        [u'Stop after this many rows', u'La guarda: 5000 por omisión, 0 sin límite.'],
        [u'Second key', u'Sólo Postmark necesita dos tokens: el de SERVIDOR envía y lee '
         u'rebotes, y el de CUENTA abre remitentes y dominios. En blanco para todos los '
         u'demás.'],
        [u'Region', u'<code>eu</code> para una cuenta de Mailgun o SparkPost creada en '
         u'Europa. Son servicios separados, con sus propios nombres de host y sus '
         u'propios datos &mdash; preguntada en el endpoint por omisión, una cuenta '
         u'europea se ve vacía en vez de equivocada.'],
        [u'Base address', u'Reemplaza el host del proveedor, y el esquema si usted lo '
         u'escribe. Para un relay propio, o para apuntar una compilación de prueba a un '
         u'sustituto. En blanco en producción.'],
    ]))
    add(p(u'Si nombra una tabla de configuración en la pestaña Tabla, aparecen tres '
          u'columnas más para éstos en la segunda pestaña de columnas: segunda clave '
          u'(sellada), región y dirección base.'))

    add(h2('apibutton', u'El botón de cuenta de correo'))
    add(p(u'<b>emailTo - Mail account button</b> es una plantilla de control: arrástrela '
          u'a cualquier ventana y coloca un botón ya cableado que abre la ventana de '
          u'gestión.'))
    add(table([u'Campo', u'Qué hace'], [
        [u'API object name', u'El objeto que declaró la extensión global.'],
        [u'Open on', u'Por qué pestaña: Cuenta, Bloqueados, Estadísticas, Actividad, '
         u'Contactos, Listas, Campañas, Plantillas, Remitentes y dominios, o Webhooks. '
         u'Si este proveedor no puede contestar ésa, la ventana abre por la primera que '
         u'SÍ puede, en vez de enseñar una lista vacía.'],
        [u'Hide the button if the provider has no API',
         u'Una cuenta que envía por SMTP a secas &mdash; un Exchange de la empresa, '
         u'Gmail con una contraseña de aplicación &mdash; no tiene API de gestión '
         u'ninguna. Marcado, el botón desaparece para esas cuentas en lugar de abrir '
         u'una ventana con todas las pestañas deshabilitadas. Es una comprobación en '
         u'tiempo de ejecución, así que una sola compilación sirve para las dos.'],
    ]))
    add(p(u'Colóquela más de una vez y cada instancia se queda con su propia pestaña: '
          u'un botón para la lista de bloqueados y otro para las campañas. La plantilla '
          u'escribe el manejador contra el equate de campo que AppGen le haya dado a esa '
          u'instancia.'))

    add(h2('apicode', u'Preguntar desde un embed'))
    add(p(u'<b>emailTo - Ask the provider</b> es la plantilla de código. Póngala en '
          u'cualquier embed &mdash; un botón, una opción de menú, el final de un proceso '
          u'&mdash; y elija la operación:'))
    add(table([u'Campo', u'Qué hace'], [
        [u'Do this', u'Cargar las direcciones bloqueadas, desbloquear una, '
         u'desbloquearlas todas, bloquear una dirección, saber si una dirección está '
         u'bloqueada, cargar las estadísticas, la actividad, los contactos, las listas '
         u'o las campañas, enviar una campaña, exportar la lista de bloqueados a CSV, o '
         u'abrir la ventana de gestión.'],
        [u'Which list', u'Todo, rebotes, bloqueados, quejas de spam, bajas o no '
         u'válidas. Un proveedor que guarda una sola lista para todas devuelve las '
         u'mismas filas elija lo que elija, etiquetadas con lo que son de verdad.'],
        [u'Value', u'La dirección, el id de campaña o el nombre de archivo sobre el que '
         u'opera &mdash; escrito, o tomado de una variable en tiempo de ejecución.'],
        [u'Put the result in', u'Para una carga, el NÚMERO de filas (o -1 si el '
         u'proveedor dijo que no). Para lo demás, 1 significa que funcionó.'],
        [u'Show the error', u'Muestra las palabras del propio proveedor. En cualquier '
         u'caso quedan en <code>LastErrorText</code>, y la dirección a la que llamó en '
         u'<code>LastUrl</code>.'],
    ]))
    add(p(u'Lo que escribe es corto, porque el trabajo está en la clase:'))
    add(code(S_APIEMBED))
    add(p(u'Las filas caen en las colas del objeto, que tienen la misma forma sea quien '
          u'sea el proveedor &mdash; <code>SuppQ</code>, <code>StatQ</code>, '
          u'<code>EventQ</code> y las demás. Recórralas usted, o llame a '
          u'<code>Manage()</code> y deje que lo haga la ventana que ya viene hecha.'))

    add(h2('button', 'emailTo - Botón de correo'))
    add(p('Arrástrelo a cualquier ventana; póngalo más de una vez si quiere. AppGen '
          'hace único el equate del campo (<code>?EmailBtn</code>, '
          '<code>?EmailBtn:2</code>&hellip;) y la plantilla engancha el manejador al '
          'que le haya tocado a esta instancia.'))
    add(note('tip', '¿Cuál botón lleva la dirección del remitente? Ninguno',
             '<p>Una cuenta pertenece a la <em>aplicación</em>, no a un botón. El '
             'servidor, la dirección de remitente, el usuario, la contraseña y el '
             'cliente OAuth2 se configuran una sola vez, en la pestaña Cuenta de '
             '<b>emailTo - Global</b>. Un botón sólo dice <em>qué hacer</em>, así que '
             'puede poner dos en una misma ventana, uno para enviar y otro para abrir '
             'la configuración, y ninguno de los dos lleva una credencial.</p>'
             '<p>La pestaña <b>Cuenta</b> del botón no tiene campos precisamente por '
             'eso. Está ahí para señalar el lugar que sí los tiene.</p>'))
    add(p('Cuál de los dos es cada instancia se ve en la lista de AppGen sin abrirla, '
          'porque la descripción nombra la acción:'))
    add(code('emailTo - E-mail button   E-mail button - opens the COMPOSE window\n'
             'emailTo - E-mail button   E-mail button - opens ACCOUNT SETUP', 'dos'))

    add(h3('button-general', 'General'))
    add(table(['Campo', 'Qué hace'], [
        ['Desactivar este botón',
         'No genera nada para esta instancia. El botón se queda en la ventana, inerte.'],
        ['Nombre del objeto de correo',
         'Tiene que coincidir con la extensión global. <code>Mailer</code> por omisión.'],
        ['Acción', 'Abrir la ventana de redacción, enviar de una vez sin ventana, o '
         'abrir la ventana de configuración de la cuenta.'],
        ['Avisar al usuario que funcionó',
         'Gris salvo que la acción sea <em>enviar de una vez</em>: la única que lo lee.'],
        ['Mostrar el error si falló',
         'Igual. Llama a <code>ShowError</code>; apagado, el motivo igual queda en '
         '<code>LastErrorText</code>.'],
    ]))
    add(note('note', 'Las tres acciones nacen rotuladas "E-mail..."',
             '<p>La acción se elige después de soltar el control, así que la plantilla '
             'no puede variar el texto por usted. Renombre el botón en el diseñador de '
             'ventanas: dos botones que dicen los dos <em>E-mail...</em> confunden al '
             'usuario del programa terminado tanto como lo confunden a usted en '
             'AppGen.</p>'))

    add(h3('button-account', 'Cuenta'))
    add(p('Sin campos. Nombra el único lugar donde se configura la cuenta &mdash; '
          '<b>Aplicación &rarr; Propiedades globales &rarr; Extensiones &rarr; '
          'emailTo - Global &rarr; Cuenta</b> &mdash; y explica que un botón de '
          'configuración es como el usuario final la sobreescribe: a su tabla de '
          'ajustes si mapeó una, y si no, a un INI junto al <code>.EXE</code>.'))

    add(h3('button-message', 'Mensaje'))
    add(p('A quién va y qué dice. Lo que esta pestaña <em>significa</em> depende de la '
          'acción, y por eso la pestaña General deletrea los tres casos:'))
    add(table(['Acción', 'Qué hace la pestaña Mensaje'], [
        ['Abrir la ventana de redacción',
         'Prellena la ventana. El usuario puede cambiar cualquier cosa antes de enviar.'],
        ['Enviar de una vez',
         'Es el mensaje. No se muestra nada; lo que deje en blanco simplemente se omite.'],
        ['Abrir la ventana de configuración',
         'Nada: la pestaña entera se pone gris, porque no hay mensaje de por medio.'],
    ]))
    add(table(['Campo', 'Qué hace'], [
        ['Para / Copia / Asunto / Cuerpo',
         'Literales, para un botón que siempre manda lo mismo.'],
        ['&hellip;o tomarlo de una variable',
         'Un selector de campo. Gana sobre el literal de al lado.'],
        ['El cuerpo es HTML',
         'Llama a <code>SetHtml</code> en vez de <code>SetText</code>.'],
        ['Adjunto', 'Una ruta literal, o una variable que la tenga.'],
    ]))
    add(p('Aquí están las tres acciones, tal como se generan:'))
    add(code(S_GEN_BUTTON))

    add(h2('codetemplates', 'Las tres plantillas de código'))
    add(p('<b>Enviar un correo aquí</b> es la que más se usa. Sus campos son los mismos '
          'de la pestaña Mensaje del botón, más un lugar donde dejar el resultado:'))
    add(table(['Campo', 'Qué hace'], [
        ['Para / Copia / Copia oculta', 'Literales, o una variable para Para.'],
        ['Asunto / Cuerpo', 'Literales, o variables. El cuerpo puede ser HTML.'],
        ['Adjunto',
         'Una ruta literal, o una variable: así es como se manda un reporte.'],
        ['Dejar el resultado en', 'Un campo que recibe 1 si se envió, 0 si no.'],
        ['Avisar que funcionó / Mostrar el error',
         'Los dos opcionales; el motivo siempre queda en <code>LastErrorText</code>.'],
    ]))
    add(note('tip', 'Mandar un reporte por correo',
             '<p>Escriba el PDF y luego ponga <b>Enviar un correo aquí</b> justo '
             'después, apuntando el campo del adjunto a la variable que tiene el nombre '
             'del archivo. Esa es toda la receta: no hay una plantilla aparte para '
             'reportes porque no hace falta.</p>'))
    add(p('<b>Abrir la ventana de redacción aquí</b> prellena y abre la ventana de '
          'escribir y enviar. <b>Abrir la ventana de configuración aquí</b> abre la '
          'ventana de la cuenta: póngala en un menú de configuración y sus usuarios '
          'pueden configurar su propio correo sin usted.'))

    add(p('Las tres llevan el mismo recordatorio que el botón: la dirección de '
          'remitente, el servidor y la contraseña no están entre sus campos, porque '
          'pertenecen a la extensión global.'))

    add(h2('embeds', 'Dónde cae el código generado'))
    add(table(['Plantilla', 'Punto de embed', 'Qué llega'], [
        ['Global', '<code>%AfterGlobalIncludes</code>', 'Un <code>INCLUDE</code>, <code>ONCE</code>.'],
        ['Global', '<code>%GlobalData</code>', 'El objeto y <code>emailToLanguage</code>.'],
        ['Global', '<code>%ProgramSetup</code> PRIORITY(8000)',
         'Init, los valores por omisión, <code>LoadAccount</code>.'],
        ['Global', '<code>%ProgramProcedures</code>', 'El enlace con la tabla, si hay una.'],
        ['Global', '<code>%DLLExportList</code>',
         'El objeto y el byte de idioma, cuando esta aplicación es la dueña.'],
        ['Global', '<code>%BeforeGenerateApplication</code>',
         'Registra la categoría de clases <code>EMAILTO</code>.'],
        ['Botón', '<code>%CustomGlobalDeclarations</code>',
         'El <code>INCLUDE</code>, para que el módulo vea la clase.'],
        ['Botón', '<code>%ControlEventHandling</code>',
         'El manejador, sobre el equate propio de esta instancia.'],
        ['Plantillas de código', 'donde usted las ponga', 'Las llamadas, en línea.'],
    ]))

    add(nextcards(['reference.html', 'programmers-guide.html', 'getting-started.html']))

    body = '\n'.join(B)
    groups = [
        ('Panorama', [('five', 'Las diez plantillas')]),
        ('La extensión global', [('global', 'emailTo - Global'),
                                 ('global-general', 'General'),
                                 ('global-account', 'Cuenta'),
                                 ('global-signin', 'Acceso'),
                                 ('global-api', u'emailTo - Provider API'),
                                 ('global-sync', u'Sincronizar tablas'),
                                 ('global-table', 'Tabla'),
                                 ('global-multidll', 'Multi-DLL'),
                                 ('global-writes', 'Qué escribe')]),
        ('Lo demás', [('apibutton', u'El bot\u00f3n de cuenta de correo'),
                      ('syncbutton', u'El bot\u00f3n de sincronizar'),
                      ('apicode', u'Preguntar desde un embed'),
                      ('button', 'El botón de correo'),
                      ('button-general', 'General'),
                      ('button-account', 'Cuenta'),
                      ('button-message', 'Mensaje'),
                      ('codetemplates', 'Las plantillas de código'),
                      ('embeds', 'Dónde cae el código')]),
    ]
    return page('template-guide.html', PAGE_TITLES['template-guide.html'][1],
                'Volumen 3', 'Guía de plantillas',
                'Cada plantilla, cada pestaña, cada campo &mdash; y el código que el '
                'generador realmente escribe en su aplicación.',
                ['10 plantillas', 'Cada campo', 'Código generado', 'Multi-DLL'],
                groups, body)


# =====================================================================
#  4  REFERENCIA   (generada desde las fuentes)
# =====================================================================
CLASS_BLURB_ES = {
    'EmailNetClass':
        'Las primitivas de transporte, y la única clase que toca C. Un socket, '
        'opcionalmente envuelto en TLS; una petición HTTPS; la redirección de loopback '
        'de OAuth2; DPAPI, SHA-256 y aleatorio seguro.',
    'EmailBufClass':
        'Un buffer de bytes que crece. Armar MIME es agregar miles de pedacitos a algo '
        'que termina midiendo megabytes, y Clarion no tiene constructor de cadenas: '
        'éste duplica su capacidad, así que armar sale lineal.',
    'EmailMsgClass':
        'El mensaje, y el documento MIME en que se convierte. Clarion puro: aquí nada '
        'toca un socket, que es por lo que los cuatro transportes pueden compartirlo.',
    'EmailOAuthClass':
        'El flujo de código de autorización de OAuth2 con PKCE. Toma prestados los '
        'objetos de red y de codificación de EmailToClass, y no es dueño de ninguno.',
    'EmailToClass':
        'El emisor. Tiene una cuenta y sabe cuatro maneras de poner un mensaje en la '
        'red, más las ventanas de configuración y de redacción.',
}

EQ_TITLES_ES = {
    'ETTrn': 'Transportes', 'ETPrv': 'Proveedores', 'ETSec': 'Seguridad de la conexión',
    'ETAuth': 'Autenticación', 'ETLng': 'Idioma', 'ETSend': 'Errores de envío',
    'ETMsg': 'Errores de mensaje', 'ETAddr': 'Tipos de destinatario',
    'ETChs': 'Juegos de caracteres', 'ETPri': 'Prioridad',
    'ETNet': 'Errores de red', 'ETTxt': 'Cadenas traducibles',
}


def methrow_es(cls, m):
    key = cls + '.' + m['name']
    ex = EXAMPLES.get(key)
    if not ex:
        PROBLEMS.append('reference-es.html: %s no tiene ejemplo' % key)
        ex = ''
    eng = (m['doc'] or m['lead']).strip()
    doc = MEMBER_DOCS_ES.get(key, '')
    if eng and not doc:
        PROBLEMS.append('reference-es.html: %s tiene descripcion en ingles pero no en espanol' % key)
        doc = eng
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


def proprow_es(cls, pr):
    key = cls + '.' + pr['name']
    ex = EXAMPLES.get(key)
    if not ex:
        PROBLEMS.append('reference-es.html: %s no tiene ejemplo' % key)
        ex = ''
    eng = (pr['doc'] or pr['lead']).strip()
    doc = MEMBER_DOCS_ES.get(key, '')
    if eng and not doc:
        PROBLEMS.append('reference-es.html: %s tiene descripcion en ingles pero no en espanol' % key)
        doc = eng
    return ('<tr class="fn"><td><code class="mem">%s</code>'
            '<div class="sig">%s</div>%s%s</td></tr>'
            % (esc(pr['name']), esc(pr['type']),
               '<p class="mdoc">%s</p>' % esc(doc) if doc else '',
               usecode(ex)))


def build_reference():
    B = []
    add = B.append
    cs = extract.classes()

    add(h2('how', 'Cómo leer esto'))
    add(p('Cada firma de esta página se leyó de los archivos <code>.inc</code> que se '
          'distribuyen, en el momento en que se generó la página, así que es la firma '
          'que hay en su compilación. Cada miembro trae una línea de código real: la '
          'generación falla si alguno no la tiene.'))
    add(p('<code>Mailer</code> en todos lados es el objeto global '
          '<code>EmailToClass</code> que declara la plantilla. <code>PROC</code> en una '
          'firma quiere decir que se puede ignorar el valor devuelto; '
          '<code>VIRTUAL</code> quiere decir que está pensado para sobrescribirse.'))
    add(note('note', 'Los nombres y el código están en inglés a propósito',
             '<p>Los identificadores de las clases, los equates y los ejemplos son '
             'Clarion, y el Clarion que usted va a escribir dice '
             '<code>Mailer.SendSimple</code>, no una traducción. Lo que está en español '
             'aquí son las descripciones; lo que se copia y se pega no se toca.</p>'))
    add(table(['Clase', 'Vive en', 'Qué es'],
              [['<code>%s</code>' % c['name'], '<code>%s</code>' % c['inc'],
                esc(CLASS_BLURB_ES.get(c['name'], ''))] for c in cs]))

    for c in cs:
        cid = slug(c['name'])
        add(h2(cid, c['name']))
        add(p(esc(CLASS_BLURB_ES.get(c['name'], ''))))
        props = [x for x in c['props'] if not x['private']]
        meths = [x for x in c['methods'] if not x['private']]
        if props:
            add(h3(cid + '-props', 'Propiedades de ' + c['name']))
            add('<div class="tw"><table class="api"><tbody>%s</tbody></table></div>'
                % ''.join(proprow_es(c['name'], x) for x in props))
        if meths:
            add(h3(cid + '-meths', 'Métodos de ' + c['name']))
            add('<div class="tw"><table class="api"><tbody>%s</tbody></table></div>'
                % ''.join(methrow_es(c['name'], x) for x in meths))

    add(h2('account-group', 'EmailAccountGroup'))
    add(p('La cuenta, campo por campo. Ésta es la estructura sobre la que la plantilla '
          'asigna las columnas de su tabla.'))
    for gname, inc, fields in extract.groups():
        if gname != 'EmailAccountGroup':
            continue
        add(table(['Campo', 'Tipo', 'Qué es'],
                  [['<code>%s</code>' % esc(f[0]), '<code>%s</code>' % esc(f[1]),
                    esc(FIELD_DOCS_ES.get('EmailAccountGroup.' + f[0], f[2]))]
                   for f in fields]))

    add(h2('queues', 'Las colas'))
    add(p('Cuatro colas <code>TYPE</code> forman parte de la superficie pública. '
          'Recórralas con <code>RECORDS</code> y <code>GET</code>; no les haga '
          '<code>ADD</code> directamente: los métodos <code>AddTo</code> / '
          '<code>Attach</code> / <code>AddHeader</code> son los que las mantienen '
          'consistentes.'))
    for qname, inc, fields in extract.queues():
        add(h3(slug(qname), qname))
        add(table(['Campo', 'Tipo', 'Qué es'],
                  [['<code>%s</code>' % esc(f[0]), '<code>%s</code>' % esc(f[1]),
                    esc(FIELD_DOCS_ES.get(qname + '.' + f[0], f[2]))]
                   for f in fields]))

    add(h2('equates', 'Los equates'))
    add(p('Todos los equates que define emailTo, agrupados por prefijo. Todos empiezan '
          'con <code>ET</code> para que no choquen con otra plantilla.'))
    eq = extract.equates()
    order = ['ETTrn', 'ETPrv', 'ETSec', 'ETAuth', 'ETLng', 'ETSend',
             'ETMsg', 'ETAddr', 'ETChs', 'ETPri', 'ETNet', 'ETTxt']
    for prefix in order:
        if prefix not in eq:
            continue
        items = eq[prefix]['items']
        add(h3('eq-' + prefix.lower(), EQ_TITLES_ES.get(prefix, prefix)))
        add(table(['Equate', 'Valor', 'Notas'],
                  [['<code>%s</code>' % esc(n), '<code>%s</code>' % esc(v),
                    esc(EQUATE_NOTES_ES.get(n, cm))] for n, v, cm in items]))

    add(h2('capi', 'La capa C'))
    add(p('<code>emailc.c</code> lo compila dentro de su <code>.EXE</code> el propio '
          'compilador de C de Clarion. Usted no llama a estas funciones directamente '
          '&mdash; <code>EmailNetClass</code> envuelve cada una &mdash; pero la lista '
          'está aquí porque es todo lo que emailTo no puede hacer en Clarion.'))
    add(table(['Función', 'Prototipo'],
              [['<code>%s</code>' % esc(n), '<code>%s</code>' % esc(s)]
               for n, s in extract.c_api()]))
    add(note('note', 'Todas estas DLL vienen con Windows',
             '<p><code>ws2_32</code>, <code>secur32</code>, <code>winhttp</code>, '
             '<code>crypt32</code>, <code>advapi32</code> y <code>shell32</code> se '
             'enlazan en tiempo de ejecución con <code>LoadLibrary</code>, así que no '
             'hay librería de importación, no hay nada que redistribuir, y una máquina '
             'a la que le falte alguna da un código de error limpio en vez de no '
             'arrancar.</p>'))

    add(nextcards(['getting-started.html', 'programmers-guide.html', 'template-guide.html']))

    body = '\n'.join(B)
    groups = [('', [('how', 'Cómo leer esto')])]
    for c in cs:
        cid = slug(c['name'])
        items = [(cid, c['name'])]
        if [x for x in c['props'] if not x['private']]:
            items.append((cid + '-props', 'Propiedades'))
        if [x for x in c['methods'] if not x['private']]:
            items.append((cid + '-meths', 'Métodos'))
        groups.append((c['name'], items))
    groups.append(('Estructuras', [('account-group', 'EmailAccountGroup'),
                                   ('queues', 'Las colas')] +
                   [(slug(q[0]), q[0]) for q in extract.queues()]))
    groups.append(('Equates', [('equates', 'Los equates')] +
                   [('eq-' + pfx.lower(), EQ_TITLES_ES.get(pfx, pfx))
                    for pfx in order if pfx in eq]))
    groups.append(('C', [('capi', 'La capa C')]))

    return page('reference.html', PAGE_TITLES['reference.html'][1], 'Volumen 4',
                'Referencia',
                'Cada clase, método, propiedad, equate y estructura &mdash; leídos de '
                'las fuentes en el momento de generar esta página.',
                ['5 clases', '%d miembros' % len(EXAMPLES), 'Generada',
                 'Todos con ejemplo'],
                groups, body, showfilter=True)
