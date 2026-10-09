  PROGRAM
  INCLUDE('WordDocClass.inc'),ONCE
  MAP
PrintDoc  PROCEDURE(STRING pRtfOrFile, BYTE pIsFile)
  END
Doc     WordDocClass
Res     CSTRING(260)
Mode    BYTE
Es      BYTE
Ttl     STRING(60)
I       LONG
N       LONG
P       LONG
PrevQ   QUEUE,PRE(PQ)
Name      STRING(260)
        END
Rpt REPORT,AT(1000,1000,6500,9000),PRE(RPT),THOUS,FONT('Arial',10)
        HEADER,AT(1000,400,6500,500)
          STRING('Flow test - header'),AT(0,100),FONT(,9,,FONT:bold),USE(?HeadText)
        END
Head    DETAIL,AT(0,0,6500,450),USE(?Head)
          STRING(@s60),AT(0,120,6500,250),USE(Ttl),FONT(,11,0C04020H,FONT:bold)
          LINE,AT(0,420,6500,0),COLOR(0C04020H)
        END
DocBand DETAIL,AT(0,0,6500,8000),USE(?DocBand)
          IMAGE,AT(0,0,6500,8000),USE(?DocImg)
        END
        FOOTER,AT(1000,10100,6500,400)
          STRING('footer'),AT(0,100),FONT(,8),USE(?FootText)
        END
      END
  CODE
  Res = LONGPATH() & '\flow.ini'
  REMOVE(Res)
  Mode = CHOOSE(UPPER(COMMAND(1)) = 'PAGES', WD:Pages, WD:Flow)
  Es = CHOOSE(UPPER(COMMAND(1)) = 'ES' OR UPPER(COMMAND(2)) = 'ES')   ! Spanish, for the docs
  OPEN(Rpt)
  Rpt{PROP:Preview} = PrevQ
  Doc.InitHidden()
  IF Es
    SETTARGET(Rpt)
    ?HeadText{PROP:Text} = 'Prueba de flujo - cabecera'
    ?FootText{PROP:Text} = 'pie'
    SETTARGET()
    Ttl = '1  Una nota corta'              ; PRINT(RPT:Head)
    PrintDoc('PRIMER REGISTRO - una nota corta, cargada como texto.', 0)
    Ttl = '2  Carta al cliente (larga)'    ; PRINT(RPT:Head)
    PrintDoc('sample_es.rtf', 1)
    Ttl = '3  Otra nota corta'             ; PRINT(RPT:Head)
    PrintDoc('TERCER REGISTRO - impreso justo despu' & CHR(233) & 's de la carta.', 0)
  ELSE
    Ttl = '1  A short note'                ; PRINT(RPT:Head)
    PrintDoc('FIRST RECORD - a short note, loaded as plain text.', 0)
    Ttl = '2  Customer letter (long)'      ; PRINT(RPT:Head)
    PrintDoc('sample.rtf', 1)
    Ttl = '3  Another short note'          ; PRINT(RPT:Head)
    PrintDoc('THIRD RECORD - printed straight after the letter.', 0)
  END
  ENDPAGE(Rpt)
  PUTINI('f','pages', RECORDS(PrevQ), Res)
  LOOP I = 1 TO RECORDS(PrevQ)
    GET(PrevQ, I)
    COPY(PQ:Name, 'flow' & I & '.wmf')
  END
  CLOSE(Rpt)
  Doc.Kill()

PrintDoc  PROCEDURE(STRING pRtfOrFile, BYTE pIsFile)
  CODE
  IF pIsFile THEN Doc.LoadFile(pRtfOrFile) ELSE Doc.LoadString(pRtfOrFile).
  N = Doc.PaginateForReport(Rpt, ?DocImg, Mode)
  PUTINI('f','pieces_' & CLIP(Ttl[1]), N, Res)
  LOOP P = 1 TO N
    Doc.PreparePage(Rpt, ?DocImg, P)
    PRINT(RPT:DocBand)
  END
