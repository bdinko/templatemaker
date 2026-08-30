# -*- coding: utf-8 -*-
"""Las descripciones de una línea, en español, para el volumen de referencia.

Sólo llevan traducción los miembros que tienen una descripción en inglés: la
descripción sale del comentario en la fuente, así que si allá no hay nada,
aquí tampoco. La generación falla si aparece una descripción nueva en inglés
sin su par en español, igual que falla si un miembro se queda sin ejemplo.

Los nombres, las firmas y el código NO se traducen: son Clarion.
"""

MEMBER_DOCS_ES = {
 'EmailNetClass.Conn':          'id de la conexión abierta, 0 = cerrada',
 'EmailNetClass.Secure':        '1 en cuanto TLS está activo sobre Conn',
 'EmailNetClass.LastError':     'un código ETNet:; 0 = correcto',
 'EmailNetClass.LastWinError':  'el código de SSPI / Winsock que hay detrás',
 'EmailNetClass.Timeout':       'milisegundos; 30000 por omisión',
 'EmailNetClass.VerifyCert':    '1 = validar el certificado del servidor (por omisión)',
 'EmailNetClass.Trace':         '1 = guardar la conversación en TraceQ',
 'EmailNetClass.HidePasswords': '1 = ocultar las credenciales en el registro (por omisión)',
 'EmailNetClass.Response':      'el cuerpo de la última llamada a Http()',
 'EmailNetClass.RespCap':       'privada en espíritu; crece según haga falta',
 'EmailNetClass.Status':        'el código HTTP de la última llamada a Http()',
 'EmailNetClass.BinLen':        'longitud del valor binario que devolvió el último Sha256 / '
                                'RandomBytes / Protect / Unprotect (un STRING devuelto se '
                                'rellena con espacios al asignarlo, así que lo binario '
                                'necesita su longitud)',
 'EmailNetClass.Body':          'el cuerpo de la última respuesta',
 'EmailNetClass.Sha256':        '32 bytes en crudo',
 'EmailNetClass.Protect':       'DPAPI, para este usuario de Windows',
 'EmailNetClass.TraceText':     'la transcripción completa, separada por CRLF',

 'EmailBufClass.Need':          'hacer sitio para pExtra bytes más',
 'EmailBufClass.AddLine':       'pLine + CRLF',
 'EmailBufClass.ClearAll':      'NO se llama Clear: un miembro de clase cuya etiqueta '
                                'coincide con una intrínseca de Clarion redefine esa '
                                'intrínseca para CADA módulo que incluya este archivo, y el '
                                'siguiente CLEAR(UnaVariable) en cualquier parte de la '
                                'aplicación deja de compilar con "No matching prototype '
                                'available". La misma trampa que BEGIN y RESET.',
 'EmailBufClass.Value':         'todo el contenido, como STRING',

 'EmailMsgClass.CharSet':       'ETChs:Utf8 (por omisión) o ETChs:Ansi',
 'EmailMsgClass.ReadReceipt':   '1 = pedir acuse de lectura',
 'EmailMsgClass.BccInHeaders':  '1 = escribir un encabezado Bcc: en el MIME. APAGADO para SMTP, donde los destinatarios en copia oculta llegan al servidor como RCPT TO adicionales y un encabezado se los mostraría a todos. ENCENDIDO para la API de Gmail y para Graph, que toman los destinatarios DE los encabezados - no hay sobre donde ponerlos - y quitan la línea Bcc antes de entregar. EmailToClass lo fija según el transporte.',
 'EmailMsgClass.OwnMessageId':  '1 = escribir nuestro propio Message-ID (lo normal, y lo que quiere SMTP: muchos servidores no agregan uno). 0 = omitirlo y dejar que lo asigne el proveedor, que es lo que hacen la API de Gmail y Graph de todos modos, porque descartan el nuestro. Acuñar un id en un dominio que uno no controla - <...@gmail.com> sin ser Google - es algo que un servidor receptor tiene derecho a desconfiar. EmailToClass lo fija según el transporte.',
 'EmailMsgClass.MessageId':     'se genera si se deja vacío',
 'EmailMsgClass.TzMinutes':     'minutos al este de UTC para el encabezado Date:',
 'EmailMsgClass.Mime':          'lo que produjo Build()',
 'EmailMsgClass.MaxSize':       'negarse a construir por encima de esto (0 = sin límite)',
 'EmailMsgClass.Validate':      '1 = listo para enviar',
 'EmailMsgClass.Build':         'devuelve la longitud del MIME, <0 si hubo error',
 'EmailMsgClass.RecipientList': '"a@b.com, c@d.com" para un encabezado',
 'EmailMsgClass.EnvelopeCount': 'todos los To + Cc + Bcc, para el RCPT TO',
 'EmailMsgClass.Base64Url':     'RFC 4648 sección 5: -_ y sin relleno',
 'EmailMsgClass.Utf8':          'Windows-1252 -> UTF-8',
 'EmailMsgClass.EncodeHeader':  'RFC 2047, sólo si hace falta',
 'EmailMsgClass.NeedsEncoding': 'reglas de encabezado: cualquier carácter de control cuenta',
 'EmailMsgClass.JsonString':    'escapado y entre comillas, para los transportes REST',

 'EmailOAuthClass.Net':         'prestado de EmailToClass, no es suyo',
 'EmailOAuthClass.Msg':         'objeto codificador prestado, no es suyo',
 'EmailOAuthClass.LastAuthUrl': 'la dirección de consentimiento que realmente se abrió: '
                                'péguela a mano en un navegador cuando falle un inicio de '
                                'sesión y el proveedor dirá exactamente qué objeta',
 'EmailOAuthClass.RedirectPort': '0 = pedirle a Windows un puerto libre',
 'EmailOAuthClass.RedirectHost': 'vacío = 127.0.0.1 para Google, localhost para Microsoft. '
                                 'Tiene que coincidir con lo que registró, y los dos '
                                 'proveedores documentan uno distinto; el escucha responde '
                                 'en los dos',
 'EmailOAuthClass.WaitSeconds': 'cuánto tiempo dejar abierto el navegador',
 'EmailOAuthClass.SetErr':      'lo registra Y contesta',

 'EmailToClass.Msg':            'el mensaje propio de la clase que usa SendSimple',
 'EmailToClass.Language':       'ETLng:English / ETLng:Spanish',
 'EmailToClass.Silent':         '1 = no mostrar nunca un cuadro de mensaje',
 'EmailToClass.Trace':          '1 = conservar la transcripción de la conversación',
 'EmailToClass.IniFile':        'el almacén por omisión de LoadAccount / SaveAccount',
 'EmailToClass.LastServerReply': 'lo último que dijo el servidor',
 'EmailToClass.Capabilities':   'lo que reportó el EHLO',
 'EmailToClass.SetErr':         'lo registra Y contesta 1 = funcionó / 0 = falló, para que un '
                                'método pueda terminar con RETURN SELF.SetErr(...)',
 'EmailToClass.EhloDomain':     'el nombre con el que nos anunciamos en el EHLO',
 'EmailToClass.AccountQ':      u'cada cuenta que guarda el almacén; la fila 1 es la predeterminada sin nombre',
 'EmailToClass.ListAccounts':  u'las llena en AccountQ y contesta cuántas hay - VIRTUAL, porque sólo el '
                              u'código generado sabe recorrer su tabla',
 'EmailToClass.RememberAccount': u'recuerda con cuál cuenta volver a abrir; es una preferencia de esta '
                              u'máquina, así que vive en el INI aunque las cuentas estén en una tabla',
 'EmailToClass.PreferredAccount': u'la última cuenta elegida, o la que se le pase si ya no existe',
 'EmailToClass.DeleteAccount': u'olvida una cuenta guardada; la predeterminada sin nombre no se puede borrar',
 'EmailToClass.ApiUrl':         u'reemplaza el esquema y el host de una dirección de proveedor cuando '
                               u'ApiBase nombra otro - un relay propio, o un sustituto local sin '
                               u'certificado; idempotente',
 # ---- EmailJsonClass ------------------------------------------------------
 'EmailJsonClass.Doc':          u'nuestra propia copia del texto',
 'EmailJsonClass.Find':         u'número de nodo, 0 = esa ruta no existe',
 'EmailJsonClass.Count':        u'miembros de un objeto / elementos de un arreglo',
 'EmailJsonClass.Value':        u'sin escapes, con el UTF-8 pasado a Windows-1252. NO se '
                                u'llama Val: VAL es una intrínseca de Clarion, y un método '
                                u'con ese nombre la redefine para todos los módulos que '
                                u'incluyan este archivo - el siguiente VAL() de la '
                                u'aplicación deja de compilar.',
 'EmailJsonClass.ValueBool':    u'true / 1 / "yes" / "true" cuentan todos',
 'EmailJsonClass.Raw':          u'el trozo tal como llegó, objetos y arreglos incluidos - '
                                u'útil para registrar la fila que salió mal',
 'EmailJsonClass.FirstArray':   u'la ruta del arreglo más externo, o vacío si no hay ninguno',

 # ---- EmailApiClass -------------------------------------------------------
 'EmailApiClass.Mailer':        u'la cuenta y la capa HTTPS; prestadas, no propias',
 'EmailApiClass.Net':           u'prestada de Mailer',
 'EmailApiClass.Enc':           u'propia, sólo para base64',
 'EmailApiClass.Json':          u'propia',
 'EmailApiClass.Language':      u'ETLng:English / ETLng:Spanish',
 'EmailApiClass.Silent':        u'1 = no mostrar nunca un cuadro de mensaje',
 'EmailApiClass.PageSize':      u'filas por petición; 0 = 100',
 'EmailApiClass.MaxRows':       u'detenerse pasadas estas filas; 0 = 5000',
 'EmailApiClass.LastStatus':    u'el código HTTP de la última llamada',
 'EmailApiClass.LastUrl':       u'la dirección a la que fue, para una consulta de soporte',
 'EmailApiClass.ItemBase':      u'la ruta del elemento que se está mapeando - pública '
                                u'porque un MapItem derivado la necesita',
 'EmailApiClass.SuppKindOf':    u'leer la palabra que el proveedor usa para un bloqueo',
 'EmailApiClass.IsBlocked':     u'busca en la SuppQ ya cargada',
 'EmailApiClass.ExportSuppressions': u'CSV, para su propio archivo',
 'EmailApiClass.BuildMap':      u'redefínalo para añadir o corregir una fila',
 'EmailApiClass.FindRow':       u'la deja en MapQ',
 'EmailApiClass.ExactRow':      u'una fila para ESTE tipo, no una coincidencia ampliada',
 'EmailApiClass.FailedText':    u'lo que dijo el proveedor, recortado para un mensaje',
 'EmailJsonClass.ValueLong':   u'true / false también cuentan, como 1 y 0',
 'EmailApiClass.ArgId':        u'lo que hay detrás de {id} - el resto de las ranuras las llenan los métodos públicos antes de llamar al motor',
 'EmailApiClass.RawCall':      u'cualquier cosa para la que la matriz no tenga fila. La clave, las cabeceras y la dirección base se siguen resolviendo por usted; pPath puede ser una URL entera o sólo lo que va detrás del host',
 'EmailApiClass.AuthHeaders':  u'las cabeceras firmadas, listas para enviar',
 'EmailApiClass.SyncTables':   u'VIRTUAL, y la base no hace más que decirlo. La plantilla de emailTo genera una redefinición DERIVED contra las tablas que usted nombre - el mismo arreglo que EmailToClass.LoadAccount, y por la misma razón: cada aplicación de una suite multi-DLL alcanza la redefinición por la VMT del propio objeto, mientras que sólo la que posee los datos la compila',
 # ---- firma (AWS Signature Version 4) -------------------------------------
 'EmailNetClass.SignAws':       u'el bloque Authorization completo de una petición, firmado. Función pura de lo que se le pasa: sin cuenta, sin proveedor, sin nada que preparar antes',
 'EmailNetClass.Hmac256':       u'32 bytes en crudo',
 'EmailNetClass.HexOf':         u'en minúsculas, sin espacios',
 'EmailNetClass.SigningKey':    u'32 bytes en crudo',
 'EmailNetClass.AmzStamp':      u"'YYYYMMDDTHHMMSSZ', en UTC",
 'EmailNetClass.CanonPath':     u'cada segmento codificado una vez más',
 'EmailNetClass.CanonQuery':    u'ordenada por nombre, como quiere SigV4',
 'EmailApiClass.AwsKeyId':      u'ApiKey2, o UserName si aquél está en blanco',
 'EmailApiClass.ArgToken':      u'el token de continuación, para un proveedor que pagina con uno en vez de con una URL',
 'EmailApiClass.SignedHeaders': u'las cabeceras de ESTA petición. Todos menos Amazon reciben su clave de vuelta; Amazon recibe una firma sobre la petición entera, hecha por la capa de red',
}

FIELD_DOCS_ES = {
 'EmailAccountGroup.Name':         'la etiqueta con la que se guarda esta cuenta',
 'EmailAccountGroup.Transport':    'ETTrn:...',
 'EmailAccountGroup.Provider':     'ETPrv:...',
 'EmailAccountGroup.Security':     'ETSec:...',
 'EmailAccountGroup.AuthMode':     'ETAuth:...',
 'EmailAccountGroup.Password':     'o la contraseña de aplicación',
 'EmailAccountGroup.ClientId':     'OAuth2: su aplicación registrada',
 'EmailAccountGroup.ClientSecret': 'vacío para un cliente público o de escritorio',
 'EmailAccountGroup.TenantId':     'Microsoft: common, organizations o un GUID',
 'EmailAccountGroup.ApiDomain':    'el dominio de envío de Mailgun',
 'EmailAccountGroup.Timeout':      'milisegundos; 0 = 30000',
 'EmailAccountGroup.VerifyCert':   '1 = comprobar el certificado del servidor (por omisión)',

 'EmailAddrQueue.Kind':            'ETAddr:To / ETAddr:Cc / ETAddr:Bcc',
 'EmailAttachQueue.FileName':      'ruta completa; vacío cuando se usa Data',
 'EmailAttachQueue.ShownAs':       'el nombre que ve el destinatario',
 'EmailAttachQueue.ContentType':   'se deduce de la extensión si se deja vacío',
 'EmailAttachQueue.ContentId':     'con valor = incrustado, referido como <img src="cid:...">',
 'EmailAttachQueue.Data':          'contenido en memoria; NULL cuando se usa FileName',
}

EQUATE_NOTES_ES = {
 'ETNet:MaxLine':    'la línea de protocolo más larga que vamos a leer',
 'ETChs:Utf8':       'convertir desde Windows-1252 (por omisión)',
 'ETChs:Ansi':       'mandar los bytes tal cual, etiquetados windows-1252',
 'ETPrv:Custom':     'usted pone el servidor y el puerto',
 'ETPrv:Outlook':    'outlook.com / hotmail.com / live.com',
 'ETPrv:Office365':  'una cuenta de trabajo o escuela de Microsoft 365',
 'ETSec:None':       'texto plano, puerto 25 - sólo para un relay local',
 'ETSec:StartTls':   'conectar en plano y elevar con STARTTLS (587)',
 'ETSec:Tls':        'TLS desde el primer byte (465)',
 'ETAuth:Login':     'AUTH LOGIN  - usuario y contraseña, en base64',
 'ETAuth:Plain':     'AUTH PLAIN  - un solo bloque base64',
 'ETAuth:XOAuth2':   'AUTH XOAUTH2 - un token de acceso OAuth2',

}
