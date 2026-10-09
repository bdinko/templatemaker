#TEMPLATE(myCalc,'myCalc - Pop-up calculator beside any numeric field - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myCalc template set  -  puts a small calculator button beside a numeric
#!  entry field. Press it and a modal calculator opens, seeded with whatever the
#!  field already holds; press Accept and the answer goes back into the field.
#!
#!  Four calculators in one window, picked from a drop list:
#!      Standard     the everyday keypad, memory and percent
#!      Scientific   trig, logs, powers, roots, factorial, parentheses, DEG/RAD
#!      Programmer   HEX / DEC / OCT / BIN, AND OR XOR NOT, shifts, word size
#!      Accountant   an adding-machine tape: running total, subtotal, tax, GT
#!
#!  A paper roll runs down the right-hand side - the tape in accountant mode,
#!  the history of finished calculations in the others - and can be copied to
#!  the clipboard.
#!
#!  It REMEMBERS THE MODE. Whichever calculator the user was last on comes back
#!  next time the program runs, along with DEG/RAD, the number base, the word
#!  size and the decimals. Each profile has its own saved settings.
#!
#!  THE TEMPLATES
#!    myCalcGlobal (APPLICATION) - INCLUDEs CalcClass. Optional; the control
#!                 template pulls the class in on its own.
#!    myCalcButton (CONTROL)     - THE EASY PATH: drag it next to a numeric
#!                 entry, point it at that entry, done. MULTI - one per field.
#!    myCalcHere   (CODE)        - open the calculator from any embed, for an
#!                 existing button, a menu item or a hot key.
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder or \clarion12\libsrc\win), ANSI:
#!      CalcClass.inc     CalcClass.clw     calc16.ico
#!  CalcClass.clw is pulled into the build automatically by its LINK attribute.
#!  calc16.ico is the little calculator on the button. Clarion compiles an
#!  ICON() into the executable's own resources, so it is needed at BUILD time
#!  only - there is nothing extra to ship with the finished program.
#!
#!  API (the object lives in the procedure's data - call it from any embed):
#!    Calc1.AskFor(CUS:Amount)   seed from a field, write the answer back
#!    Calc1.Ask()                just ask; the answer is in Calc1.Value
#!    Calc1.Press(act,text)      drive a key from code
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myCalcGlobal
#!#############################################################################
#EXTENSION(myCalcGlobal,'myCalc - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myCalc')
      #DISPLAY('myCalc Global - Version 1.0')
      #DISPLAY('Makes CalcClass available to every procedure in the app.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: copy CalcClass.inc and CalcClass.clw to the')
      #DISPLAY('redirection path (the app folder, or \clarion12\libsrc\win).')
      #DISPLAY('Both files must be ANSI. CalcClass.clw links itself in.')
      #DISPLAY('calc16.ico (the button icon) goes there too - build time only.')
      #DISPLAY('')
      #DISPLAY('This extension is OPTIONAL - the calculator button control')
      #DISPLAY('template pulls the class in on its own. Add it if you want to')
      #DISPLAY('call the class from hand-written code.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%mcgDisable,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Language')
      #PROMPT('Calculator &language:',DROP('English[1]|Español (Spanish)[2]')),%mcgLanguage,DEFAULT('1')
      #DISPLAY('The language every calculator in this application opens in:')
      #DISPLAY('the mode names, the window labels and the word keys (Bksp,')
      #DISPLAY('SUB, TOTAL, GT, TAX+/-). Digits, operators and the maths')
      #DISPLAY('names (sin, log, x^y, HEX) read the same either way.')
      #DISPLAY('')
      #DISPLAY('Each calculator button can override this on its own tab.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%mcgDisable=0)
INCLUDE('CalcClass.INC'),ONCE
#ENDAT
#!
#! The application-wide language, as a real global the per-window code can
#! read. Control templates default to it, and may override it per button.
#AT(%GlobalData),WHERE(%mcgDisable=0)
#IF(%mcgLanguage)
myCalcLanguage       BYTE(%mcgLanguage)                   ! 1 = English, 2 = Espanol
#ELSE
myCalcLanguage       BYTE(1)                              ! 1 = English, 2 = Espanol
#ENDIF
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - myCalcButton  -  a calculator beside one numeric field
#!#############################################################################
#!  Drops a small button and wires the whole calculator to it. The target
#!  field's USE variable is read at generate time out of the control's own USE
#!  attribute - EXTRACT(%ControlStatement,'USE',1), the same call the shipped
#!  ABDROPS.TPW makes - so there is nothing to type and nothing to keep in sync.
#!
#!  The button's own field equate is captured with the shipped
#!  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance) idiom
#!  (corpus: CONTROL.TPW:107) so MULTI drops keep working.
#!#############################################################################
#CONTROL(myCalcButton,'myCalc - Calculator button beside a numeric field'),WINDOW,MULTI,REQ(myCalcGlobal),DESCRIPTION('Calculator for ' & %mcField),HLP('~myCalc.htm')
  CONTROLS
    BUTTON(''),AT(,,14,12),USE(?CalcBtn),ICON('calc16.ico'),TIP('Open the calculator')
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this calculator',CHECK),%mcDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%mcObject,REQ,DEFAULT('Calc' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('The field it fills in')
      #PROMPT('&Field to calculate into:',CONTROL),%mcField,REQ
      #DISPLAY('The numeric ENTRY this button sits beside. The calculator opens')
      #DISPLAY('holding whatever the field contains, and Accept puts the answer')
      #DISPLAY('back into it.')
      #PROMPT('&Window title (blank = the localised name):',@s64),%mcTitle,DEFAULT('')
    #ENDBOXED
  #ENDTAB
  #TAB('&Calculators')
    #BOXED('Offer these in the mode list')
      #PROMPT('&Standard',CHECK),%mcStd,DEFAULT(1),AT(10)
      #PROMPT('S&cientific',CHECK),%mcSci,DEFAULT(1),AT(10)
      #PROMPT('&Programmer',CHECK),%mcPrg,DEFAULT(1),AT(10)
      #PROMPT('&Accountant (adding-machine tape)',CHECK),%mcAcc,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Start on')
      #PROMPT('&Mode the first time:',DROP('Standard[1]|Scientific[2]|Programmer[3]|Accountant[4]')),%mcMode,DEFAULT('1')
      #DISPLAY('After that, whichever calculator the user last used comes back -')
      #DISPLAY('see the Remember tab.')
      #PROMPT('Show the paper &roll',CHECK),%mcTape,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Numbers')
      #PROMPT('&Decimals on the tape:',SPIN(@n1,0,8,1)),%mcDecs,DEFAULT(2)
      #PROMPT('&Tax rate for the TAX+ / TAX- keys (%%):',@n7.2),%mcTax,DEFAULT(16)
      #PROMPT('Start in &radians (scientific)',CHECK),%mcRad,DEFAULT(0),AT(10)
      #PROMPT('Programmer &word size:',DROP('8 bits[8]|16 bits[16]|32 bits[32]')),%mcBits,DEFAULT('32')
    #ENDBOXED
    #BOXED('Language')
      #PROMPT('&Language:',DROP('Use the application setting[0]|English[1]|Español (Spanish)[2]')),%mcLang,DEFAULT('0')
      #DISPLAY('The application setting lives on the myCalc - Global extension,')
      #DISPLAY('and is what every calculator uses unless you override it here.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Remember')
    #BOXED('Remember the last session')
      #PROMPT('Remember the calculator &type and options between runs',CHECK),%mcPersist,DEFAULT(1),AT(10)
      #DISPLAY('Saves which calculator was in use (standard / scientific /')
      #DISPLAY('programmer / accountant) plus DEG-RAD, the number base, the word')
      #DISPLAY('size, the decimals and the tax rate - and restores them the next')
      #DISPLAY('time the program runs.')
      #ENABLE(%mcPersist)
        #PROMPT('&Profile name (blank = this procedure):',@s64),%mcProfile,DEFAULT('')
        #PROMPT('&INI file (blank = the application''s own .INI):',@s128),%mcIni,DEFAULT('')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%mcBtn)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%mcBtn,%Control)
  #ENDFOR
  #DECLARE(%mcVar)
  #FOR(%Control),WHERE(%Control=%mcField)
    #SET(%mcVar,EXTRACT(%ControlStatement,'USE',1))
  #ENDFOR
  #DECLARE(%mcMask)
  #SET(%mcMask,0)
  #IF(%mcStd)
    #SET(%mcMask,%mcMask+1)
  #ENDIF
  #IF(%mcSci)
    #SET(%mcMask,%mcMask+2)
  #ENDIF
  #IF(%mcPrg)
    #SET(%mcMask,%mcMask+4)
  #ENDIF
  #IF(%mcAcc)
    #SET(%mcMask,%mcMask+8)
  #ENDIF
  #IF(%mcMask=0)
    #SET(%mcMask,15)
  #ENDIF
#ENDAT
#!
#! Self-contained: pull in the class (,ONCE = safe alongside the global extension).
#AT(%CustomGlobalDeclarations),WHERE(%mcDisable=0)
INCLUDE('CalcClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%mcDisable=0 AND %mcField AND %mcVar)
%mcObject            CalcClass                            ! calculator for %mcField
#ENDAT
#!
#AT(%ControlEventHandling,%mcBtn,'Accepted'),WHERE(%mcDisable=0 AND %mcField AND %mcVar)
#IF(%mcTitle)
  %mcObject.Title    = '%mcTitle'
#ENDIF
  %mcObject.Allow    = %mcMask
  %mcObject.Mode     = %mcMode
  %mcObject.ShowTape = %mcTape
  %mcObject.Decimals = %mcDecs
  %mcObject.TaxRate  = %mcTax
  %mcObject.Angle    = %mcRad
  %mcObject.WordBits = %mcBits
#IF(%mcLang AND %mcLang <> '0')
  %mcObject.Language = %mcLang                             ! this button overrides
#ELSE
  %mcObject.Language = myCalcLanguage                      ! whatever the global says
#ENDIF
#IF(%mcPersist)
  %mcObject.Persist  = 1                                   ! remember the calculator type
#IF(%mcProfile)
  %mcObject.Profile  = '%mcProfile'
#ELSE
  %mcObject.Profile  = '%Procedure'
#ENDIF
#IF(%mcIni)
  %mcObject.IniFile  = '%mcIni'
#ENDIF
#ENDIF
#EMBED(%myCalcBeforeOpen,'myCalc - before the calculator opens'),%ActiveTemplateInstance,HIDE
  IF %mcObject.AskFor(%mcVar)                              ! seeds from the field, writes it back
    DISPLAY(%mcField)
#EMBED(%myCalcAfterAccept,'myCalc - after the value was accepted'),%ActiveTemplateInstance,HIDE
  END
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - myCalcHere  -  open the calculator from any embed
#!#############################################################################
#!  ,PROCEDURE lets a #CODE template own procedure-scope #AT sections (corpus:
#!  ABPOPUP.TPW:1), which is how it declares its own object in %DataSection.
#!#############################################################################
#CODE(myCalcHere,'myCalc - Open the calculator and return a value'),MULTI,PROCEDURE,REQ(myCalcGlobal),DESCRIPTION('Calculator into ' & %mkTarget),HLP('~myCalc.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Object name:',@s64),%mkObject,REQ,DEFAULT('Calc' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('Where the answer goes')
      #PROMPT('&Variable / field to fill in:',@s128),%mkTarget,REQ
      #DISPLAY('Any numeric variable or file field, e.g. CUS:CreditLimit or')
      #DISPLAY('LOC:Total. It seeds the calculator and receives the answer.')
      #PROMPT('&Refresh this control afterwards:',CONTROL),%mkRefresh
      #PROMPT('&Window title (blank = the localised name):',@s64),%mkTitle,DEFAULT('')
    #ENDBOXED
  #ENDTAB
  #TAB('&Calculators')
    #BOXED('Offer these in the mode list')
      #PROMPT('&Standard',CHECK),%mkStd,DEFAULT(1),AT(10)
      #PROMPT('S&cientific',CHECK),%mkSci,DEFAULT(1),AT(10)
      #PROMPT('&Programmer',CHECK),%mkPrg,DEFAULT(1),AT(10)
      #PROMPT('&Accountant (adding-machine tape)',CHECK),%mkAcc,DEFAULT(1),AT(10)
      #PROMPT('&Mode the first time:',DROP('Standard[1]|Scientific[2]|Programmer[3]|Accountant[4]')),%mkMode,DEFAULT('1')
      #PROMPT('Show the paper &roll',CHECK),%mkTape,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Numbers')
      #PROMPT('&Decimals on the tape:',SPIN(@n1,0,8,1)),%mkDecs,DEFAULT(2)
      #PROMPT('&Tax rate (%%):',@n7.2),%mkTax,DEFAULT(16)
      #PROMPT('&Language:',DROP('Use the application setting[0]|English[1]|Español (Spanish)[2]')),%mkLang,DEFAULT('0')
      #PROMPT('Remember the calculator &type between runs',CHECK),%mkPersist,DEFAULT(1),AT(10)
      #ENABLE(%mkPersist)
        #PROMPT('&Profile name (blank = this procedure):',@s64),%mkProfile,DEFAULT('')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%mkMask)
  #SET(%mkMask,0)
  #IF(%mkStd)
    #SET(%mkMask,%mkMask+1)
  #ENDIF
  #IF(%mkSci)
    #SET(%mkMask,%mkMask+2)
  #ENDIF
  #IF(%mkPrg)
    #SET(%mkMask,%mkMask+4)
  #ENDIF
  #IF(%mkAcc)
    #SET(%mkMask,%mkMask+8)
  #ENDIF
  #IF(%mkMask=0)
    #SET(%mkMask,15)
  #ENDIF
#ENDAT
#!
#AT(%CustomGlobalDeclarations)
INCLUDE('CalcClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%mkTarget)
%mkObject            CalcClass                            ! calculator into %mkTarget
#ENDAT
#!
#! ...and the code template's own output, right where it was dropped:
#IF(%mkTarget)
#IF(%mkTitle)
%mkObject.Title    = '%mkTitle'
#ENDIF
%mkObject.Allow    = %mkMask
%mkObject.Mode     = %mkMode
%mkObject.ShowTape = %mkTape
%mkObject.Decimals = %mkDecs
%mkObject.TaxRate  = %mkTax
#IF(%mkLang AND %mkLang <> '0')
%mkObject.Language = %mkLang                               ! this one overrides
#ELSE
%mkObject.Language = myCalcLanguage                        ! whatever the global says
#ENDIF
#IF(%mkPersist)
%mkObject.Persist  = 1
#IF(%mkProfile)
%mkObject.Profile  = '%mkProfile'
#ELSE
%mkObject.Profile  = '%Procedure'
#ENDIF
#ENDIF
IF %mkObject.AskFor(%mkTarget)
#IF(%mkRefresh)
  DISPLAY(%mkRefresh)
#ENDIF
END
#ELSE
! myCalc: fill in the target variable in the code template's prompts.
#ENDIF
#!-----------------------------------------------------------------------------
#! End of myCalc template set
#!-----------------------------------------------------------------------------
