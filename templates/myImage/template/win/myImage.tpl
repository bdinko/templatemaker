#TEMPLATE(myImage,'myImage - image formats, colour formats and transforms - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myImage template set - read twelve image formats, write nine, convert
#!  between every common colour format, and transform along the way.
#!
#!    READ   BMP GIF JPEG PNG TIFF ICO EMF WMF TGA PCX PNM QOI
#!    WRITE  BMP GIF JPEG PNG TIFF TGA PCX PNM QOI
#!    COLOUR 32-bit ARGB, 24-bit RGB, 16-bit 5-6-5, 15-bit 5-5-5, 256 and 16
#!           colours (median cut, optional Floyd-Steinberg dither), 256/16/4
#!           greys, 1-bit black & white, web-safe 216
#!    SHAPE  rotate 90/180/270, free rotation, mirror, flip, crop, extend
#!           canvas, resize (nearest/bilinear/area), fit: stretch,
#!           proportional, cover, centred, contain
#!    TONE   brightness, contrast, saturation, gamma, levels, blur, sharpen,
#!           invert, sepia, posterise, alpha flatten, opacity, histogram
#!
#!  It is quick because the pixel work is C: imgcore.c is compiled INTO your
#!  exe by Clarion's own C compiler. Nothing to install and nothing to ship -
#!  the formats Windows already knows are decoded through GDI+, which is part
#!  of Windows.
#!
#!  myImageGlobal  (APPLICATION) - INCLUDEs ImageClass. Add once.
#!  myImage        (PROCEDURE)   - an image object on a window, drawn into an
#!                 IMAGE control, with a Load: and a Refresh: routine.
#!  myImageConvert (CODE)        - drop into any embed: convert one file to
#!                 another format / colour format / size, in one statement.
#!
#!  REQUIRED FILES: copy ImageClass.inc, ImageClass.clw AND imgcore.c (shipped
#!  beside this .tpl) to a folder on the Clarion redirection path (the app
#!  folder or \clarion12\libsrc\win). Keep the .inc/.clw in ANSI, CRLF.
#!
#!  API (the object is procedure data - drive it from any embed):
#!    Pic.LoadFile('holiday.jpg')
#!    Pic.Resize(800, 600, Img:Best) ; Pic.Convert(Img:Pal256, 1)
#!    Pic.SaveFile('holiday.gif')    ; Pic.Draw(MyWindow, ?Preview)
#!    DO Refresh:Pic                 ! re-apply the prompts and redraw
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myImageGlobal
#!#############################################################################
#EXTENSION(myImageGlobal,'myImage - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myImage')
      #DISPLAY('myImage Global - Version 1.0')
      #DISPLAY('Adds the ImageClass image engine: 12 formats in, 9 out,')
      #DISPLAY('every colour format, and the usual transforms.')
      #DISPLAY('')
      #DISPLAY('Add once, at the Application (global) level. IMPORTANT: copy')
      #DISPLAY('ImageClass.inc + ImageClass.clw + imgcore.c to the redirection')
      #DISPLAY('path. The .inc/.clw must be ANSI; imgcore.c is compiled by')
      #DISPLAY('Clarion''s own C compiler, so there is no DLL to ship.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%miDisable,DEFAULT(0),AT(10)
      #PROMPT('Declare the shared &worker object (ImgWork)',CHECK),%miWorker,DEFAULT(1),AT(10)
      #DISPLAY('The myImageConvert code template uses ImgWork. Untick only if')
      #DISPLAY('that name clashes with something you already have.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%miDisable=0)
INCLUDE('ImageClass.INC'),ONCE
#ENDAT
#!
#!  One shared object for one-shot work (the myImageConvert code template uses
#!  it). Conversions run start to finish in a single statement, so sharing it
#!  is safe and it keeps a converting embed down to no declarations at all.
#AT(%GlobalData),WHERE(%miDisable=0 AND %miWorker=1)
ImgWork              ImageClass                              ! shared by myImageConvert
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myImage  -  one image object per instance
#!#############################################################################
#EXTENSION(myImage,'myImage - An image on this window'),PROCEDURE,MULTI,REQ(myImageGlobal),DESCRIPTION('[Image] ' & %miObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this image',CHECK),%miWDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%miObject,REQ,DEFAULT('Pic' & %ActiveTemplateInstance)
      #PROMPT('&Show it in this IMAGE control:',CONTROL),%miControl
      #DISPLAY('Leave the control blank to work with the image in code only -')
      #DISPLAY('handy for converting or thumbnailing without showing anything.')
    #ENDBOXED
    #BOXED('What to load when the window opens')
      #PROMPT('&Load a file:',DROP('Nothing|A fixed file name|A variable or expression|A test card')),%miSource,DEFAULT('Nothing')
      #ENABLE(%miSource='A fixed file name')
        #PROMPT('File &name:',@s255),%miFile,DEFAULT('')
      #ENDENABLE
      #ENABLE(%miSource='A variable or expression')
        #PROMPT('&Variable / expression:',@s255),%miFileVar,DEFAULT('')
      #ENDENABLE
      #ENABLE(%miSource='A test card')
        #PROMPT('Test card &width:',SPIN(@n5,16,4000,16)),%miCardW,DEFAULT(640)
        #PROMPT('Test card &height:',SPIN(@n5,16,4000,16)),%miCardH,DEFAULT(480)
      #ENDENABLE
      #PROMPT('If the file will not load, tell the user',CHECK),%miWarn,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('How to fit it to the control')
      #PROMPT('&Fit:',DROP('Proportional (pad)|Contain (no pad)|Cover (crop)|Stretch|Centred 1:1')),%miFit,DEFAULT('Proportional (pad)')
      #PROMPT('Pad / background color:',COLOR),%miPad,DEFAULT(00FFFFFFH)
    #ENDBOXED
  #ENDTAB
  #TAB('&Colour')
    #BOXED('Colour format')
      #PROMPT('Con&vert to:',DROP('Leave as loaded|32-bit true colour + alpha|24-bit true colour|16-bit high colour (5-6-5)|15-bit high colour (5-5-5)|256 colours|16 colours|256 greys|16 greys|4 greys|Black and white|Web-safe 216')),%miMode,DEFAULT('Leave as loaded')
      #PROMPT('&Dither (Floyd-Steinberg)',CHECK),%miDither,DEFAULT(0),AT(10)
      #PROMPT('Black &&  white threshold:',SPIN(@n3,1,254,4)),%miThreshold,DEFAULT(128)
    #ENDBOXED
    #BOXED('Tone')
      #PROMPT('&Brightness (-100..100):',SPIN(@n4,-100,100,5)),%miBright,DEFAULT(0)
      #PROMPT('&Contrast (-100..100):',SPIN(@n4,-100,100,5)),%miContrast,DEFAULT(0)
      #PROMPT('&Saturation (-100..100):',SPIN(@n4,-100,100,5)),%miSatur,DEFAULT(0)
      #PROMPT('&Gamma (1 = leave alone):',@n5.2),%miGamma,DEFAULT(1.0)
      #PROMPT('B&lur radius (0 = none):',SPIN(@n3,0,20,1)),%miBlur,DEFAULT(0)
      #PROMPT('S&harpen (0 = none):',SPIN(@n4,0,300,10)),%miSharpen,DEFAULT(0)
      #PROMPT('&Invert',CHECK),%miInvert,DEFAULT(0),AT(10)
      #PROMPT('Se&pia',CHECK),%miSepia,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Shape')
    #BOXED('Turn it')
      #PROMPT('&Rotate:',DROP('No|90 right|180|90 left')),%miRotate,DEFAULT('No')
      #PROMPT('&Mirror (left to right)',CHECK),%miMirror,DEFAULT(0),AT(10)
      #PROMPT('&Flip (top to bottom)',CHECK),%miFlip,DEFAULT(0),AT(10)
      #PROMPT('Free rotation, &degrees (0 = none):',SPIN(@n4,-180,180,5)),%miDegrees,DEFAULT(0)
    #ENDBOXED
    #BOXED('Size it')
      #PROMPT('Resi&ze to:',DROP('Leave alone|A fixed width and height|A percentage|Fit a box, keep the ratio')),%miSize,DEFAULT('Leave alone')
      #ENABLE(%miSize='A fixed width and height' OR %miSize='Fit a box, keep the ratio')
        #PROMPT('&Width:',SPIN(@n5,1,20000,10)),%miNewW,DEFAULT(640)
        #PROMPT('&Height:',SPIN(@n5,1,20000,10)),%miNewH,DEFAULT(480)
      #ENDENABLE
      #ENABLE(%miSize='A percentage')
        #PROMPT('&Percent:',SPIN(@n5,1,2000,5)),%miPct,DEFAULT(100)
      #ENDENABLE
      #PROMPT('Resample with:',DROP('Best (area / bilinear)|Smooth (bilinear)|Fast (nearest)')),%miFilter,DEFAULT('Best (area / bilinear)')
    #ENDBOXED
  #ENDTAB
  #TAB('&Save')
    #BOXED('Write a copy every time the image is (re)loaded')
      #PROMPT('&Save a copy',CHECK),%miSave,DEFAULT(0),AT(10)
      #ENABLE(%miSave=1)
        #PROMPT('To file &name / expression:',@s255),%miSaveTo,DEFAULT('')
        #PROMPT('&Format:',DROP('From the file extension|PNG|JPEG|BMP|GIF|TIFF|Targa|PCX|PNM|QOI')),%miSaveFmt,DEFAULT('From the file extension')
        #PROMPT('&JPEG quality:',SPIN(@n3,1,100,5)),%miQuality,DEFAULT(85)
        #PROMPT('BMP bit depth (0 = from the colour format):',SPIN(@n2,0,32,1)),%miBmpBits,DEFAULT(0)
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%miWDisable=0)
%miObject            ImageClass                              ! one image object for this instance
#ENDAT
#!
#! PRIORITY(2000) puts this self-contained CASE EVENT() ABOVE the framework's own
#! LOOP/CASE scaffolding (registered at PRIORITY 2500) - the spot myGauge,
#! graficaBarra and myPixel all use. 2500 collides and duplicates CASE EVENT().
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%miWDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    DO Refresh:%miObject
#IF(%miControl)
  OF EVENT:Sized
    DO Show:%miObject
#ENDIF
  END
#ENDAT
#!
#!  Refresh: (re)load the source and apply everything on the prompts.
#!  Show: just redraw what is already loaded into the control.
#AT(%ProcedureRoutines),WHERE(%miWDisable=0)
Refresh:%miObject ROUTINE
#INSERT(%miEmitLoad)
#INSERT(%miEmitRecipe)
#IF(%miSave)
#INSERT(%miEmitSave)
#ENDIF
#IF(%miControl)
    DO Show:%miObject

Show:%miObject ROUTINE
    IF %miObject.Ok()
#INSERT(%miEmitFit)
    END
#ENDIF
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - myImageConvert  -  one file in, one file out
#!#############################################################################
#CODE(myImageConvert,'myImage - Convert an image file'),HLP('~myImageConvert')
#SHEET
  #TAB('&Files')
    #BOXED('In and out')
      #PROMPT('&Source file (name or expression):',@s255),%mcFrom,REQ
      #PROMPT('&Target file (name or expression):',@s255),%mcTo,REQ
      #PROMPT('&Format:',DROP('From the target extension|PNG|JPEG|BMP|GIF|TIFF|Targa|PCX|PNM|QOI')),%mcFmt,DEFAULT('From the target extension')
      #PROMPT('&JPEG quality:',SPIN(@n3,1,100,5)),%mcQuality,DEFAULT(85)
      #PROMPT('Put the result (1 = worked) in:',@s64),%mcResult,DEFAULT('')
      #DISPLAY('Leave the result variable blank if you do not need it.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Convert')
    #BOXED('Colour format')
      #PROMPT('Convert &to:',DROP('Leave as loaded|32-bit true colour + alpha|24-bit true colour|16-bit high colour (5-6-5)|15-bit high colour (5-5-5)|256 colours|16 colours|256 greys|16 greys|4 greys|Black and white|Web-safe 216')),%mcMode,DEFAULT('Leave as loaded')
      #PROMPT('&Dither (Floyd-Steinberg)',CHECK),%mcDither,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Size')
      #PROMPT('Resi&ze to:',DROP('Leave alone|A fixed width and height|A percentage|Fit a box, keep the ratio')),%mcSize,DEFAULT('Leave alone')
      #ENABLE(%mcSize='A fixed width and height' OR %mcSize='Fit a box, keep the ratio')
        #PROMPT('&Width:',SPIN(@n5,1,20000,10)),%mcW,DEFAULT(640)
        #PROMPT('&Height:',SPIN(@n5,1,20000,10)),%mcH,DEFAULT(480)
      #ENDENABLE
      #ENABLE(%mcSize='A percentage')
        #PROMPT('&Percent:',SPIN(@n5,1,2000,5)),%mcPct,DEFAULT(100)
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
  ImgWork.Quality = %mcQuality
  IF ImgWork.LoadFile(%mcFrom)
#INSERT(%miEmitMode,'ImgWork',%mcMode,%mcDither,128)
#INSERT(%miEmitSize,'ImgWork',%mcSize,%mcW,%mcH,%mcPct,'Best (area / bilinear)')
#IF(%mcResult)
#INSERT(%miEmitFmtResult,'ImgWork',%mcTo,%mcFmt,%mcResult)
  ELSE
    %mcResult = 0
#ELSE
#INSERT(%miEmitFmtCall,'ImgWork',%mcTo,%mcFmt)
#ENDIF
  END
  ImgWork.Kill()
#!#############################################################################
#!  GROUPS
#!#############################################################################
#!  Load the source the user picked.
#GROUP(%miEmitLoad)
#CASE(%miSource)
#OF('A fixed file name')
    IF NOT %miObject.LoadFile('%miFile')
#IF(%miWarn)
      MESSAGE('Could not read %miFile', '%Procedure', ICON:Exclamation)
#ENDIF
    END
#OF('A variable or expression')
    IF NOT %miObject.LoadFile(%miFileVar)
#IF(%miWarn)
      MESSAGE('Could not read ' & CLIP(%miFileVar), '%Procedure', ICON:Exclamation)
#ENDIF
    END
#OF('A test card')
    %miObject.TestCard(%miCardW, %miCardH)
#ENDCASE
#!
#!  Everything on the Colour and Shape tabs, in the order that makes sense:
#!  shape first, then tone, then the colour format last - so the palette is
#!  chosen from the pixels you actually end up with.
#GROUP(%miEmitRecipe)
    IF %miObject.Ok()
#CASE(%miRotate)
#OF('90 right')
      %miObject.RotateRight()
#OF('180')
      %miObject.Rotate180()
#OF('90 left')
      %miObject.RotateLeft()
#ENDCASE
#IF(%miMirror)
      %miObject.Mirror()
#ENDIF
#IF(%miFlip)
      %miObject.FlipVert()
#ENDIF
#IF(%miDegrees)
      %miObject.Rotate(%miDegrees, %miObject.ArgbOf(%miPad), 1, 1)
#ENDIF
#INSERT(%miEmitSize,%miObject,%miSize,%miNewW,%miNewH,%miPct,%miFilter)
#IF(%miBright OR %miContrast OR %miSatur)
      %miObject.Adjust(%miBright, %miContrast, %miSatur)
#ENDIF
#IF(%miGamma<>1.0)
      %miObject.Gamma(%miGamma)
#ENDIF
#IF(%miBlur)
      %miObject.Blur(%miBlur, 2)
#ENDIF
#IF(%miSharpen)
      %miObject.Sharpen(%miSharpen)
#ENDIF
#IF(%miInvert)
      %miObject.Invert()
#ENDIF
#IF(%miSepia)
      %miObject.Sepia()
#ENDIF
#INSERT(%miEmitMode,%miObject,%miMode,%miDither,%miThreshold)
    END
#!
#!  Colour format. Emitted as a whole line per choice so no symbol has to
#!  travel between groups.
#GROUP(%miEmitMode,%pObj,%pMode,%pDither,%pThreshold)
#CASE(%pMode)
#OF('32-bit true colour + alpha')
      %pObj.Convert(Img:True32, %pDither, %pThreshold)
#OF('24-bit true colour')
      %pObj.Convert(Img:True24, %pDither, %pThreshold)
#OF('16-bit high colour (5-6-5)')
      %pObj.Convert(Img:High16, %pDither, %pThreshold)
#OF('15-bit high colour (5-5-5)')
      %pObj.Convert(Img:High15, %pDither, %pThreshold)
#OF('256 colours')
      %pObj.Convert(Img:Pal256, %pDither, %pThreshold)
#OF('16 colours')
      %pObj.Convert(Img:Pal16, %pDither, %pThreshold)
#OF('256 greys')
      %pObj.Convert(Img:Grey256, %pDither, %pThreshold)
#OF('16 greys')
      %pObj.Convert(Img:Grey16, %pDither, %pThreshold)
#OF('4 greys')
      %pObj.Convert(Img:Grey4, %pDither, %pThreshold)
#OF('Black and white')
      %pObj.Convert(Img:Mono, %pDither, %pThreshold)
#OF('Web-safe 216')
      %pObj.Convert(Img:Web216, %pDither, %pThreshold)
#ENDCASE
#!
#!  Resize / fit.
#GROUP(%miEmitSize,%pObj,%pSize,%pW,%pH,%pPct,%pFilter)
#CASE(%pSize)
#OF('A fixed width and height')
#CASE(%pFilter)
#OF('Smooth (bilinear)')
      %pObj.Resize(%pW, %pH, Img:Smooth)
#OF('Fast (nearest)')
      %pObj.Resize(%pW, %pH, Img:Fast)
#ELSE
      %pObj.Resize(%pW, %pH, Img:Best)
#ENDCASE
#OF('A percentage')
#CASE(%pFilter)
#OF('Smooth (bilinear)')
      %pObj.Zoom(%pPct, Img:Smooth)
#OF('Fast (nearest)')
      %pObj.Zoom(%pPct, Img:Fast)
#ELSE
      %pObj.Zoom(%pPct, Img:Best)
#ENDCASE
#OF('Fit a box, keep the ratio')
      %pObj.Fit(%pW, %pH, Img:Contain, 0)
#ENDCASE
#!
#!  Draw into the IMAGE control with the fit the user picked.
#GROUP(%miEmitFit)
#CASE(%miFit)
#OF('Contain (no pad)')
      %miObject.Draw(%Window, %miControl, Img:Contain, %miObject.ArgbOf(%miPad))
#OF('Cover (crop)')
      %miObject.Draw(%Window, %miControl, Img:Cover, %miObject.ArgbOf(%miPad))
#OF('Stretch')
      %miObject.Draw(%Window, %miControl, Img:Stretch, %miObject.ArgbOf(%miPad))
#OF('Centred 1:1')
      %miObject.Draw(%Window, %miControl, Img:Centered, %miObject.ArgbOf(%miPad))
#ELSE
      %miObject.Draw(%Window, %miControl, Img:Proportional, %miObject.ArgbOf(%miPad))
#ENDCASE
#!
#!  Save a copy.
#GROUP(%miEmitSave)
    IF %miObject.Ok()
      %miObject.Quality = %miQuality
      %miObject.BmpBits = %miBmpBits
#INSERT(%miEmitFmtCall,%miObject,%miSaveTo,%miSaveFmt)
    END
#!
#!  One SaveFile line, with the format the user picked.
#GROUP(%miEmitFmtCall,%pObj,%pTo,%pFmt)
#CASE(%pFmt)
#OF('PNG')
      %pObj.SaveFile(%pTo, Img:Png)
#OF('JPEG')
      %pObj.SaveFile(%pTo, Img:Jpeg)
#OF('BMP')
      %pObj.SaveFile(%pTo, Img:Bmp)
#OF('GIF')
      %pObj.SaveFile(%pTo, Img:Gif)
#OF('TIFF')
      %pObj.SaveFile(%pTo, Img:Tiff)
#OF('Targa')
      %pObj.SaveFile(%pTo, Img:Tga)
#OF('PCX')
      %pObj.SaveFile(%pTo, Img:Pcx)
#OF('PNM')
      %pObj.SaveFile(%pTo, Img:Pnm)
#OF('QOI')
      %pObj.SaveFile(%pTo, Img:Qoi)
#ELSE
      %pObj.SaveFile(%pTo)
#ENDCASE
#!
#!  Same again, but the answer goes into the user's variable.
#GROUP(%miEmitFmtResult,%pObj,%pTo,%pFmt,%pRes)
#CASE(%pFmt)
#OF('PNG')
    %pRes = %pObj.SaveFile(%pTo, Img:Png)
#OF('JPEG')
    %pRes = %pObj.SaveFile(%pTo, Img:Jpeg)
#OF('BMP')
    %pRes = %pObj.SaveFile(%pTo, Img:Bmp)
#OF('GIF')
    %pRes = %pObj.SaveFile(%pTo, Img:Gif)
#OF('TIFF')
    %pRes = %pObj.SaveFile(%pTo, Img:Tiff)
#OF('Targa')
    %pRes = %pObj.SaveFile(%pTo, Img:Tga)
#OF('PCX')
    %pRes = %pObj.SaveFile(%pTo, Img:Pcx)
#OF('PNM')
    %pRes = %pObj.SaveFile(%pTo, Img:Pnm)
#OF('QOI')
    %pRes = %pObj.SaveFile(%pTo, Img:Qoi)
#ELSE
    %pRes = %pObj.SaveFile(%pTo)
#ENDCASE
#!#############################################################################
#!  CONTROL TEMPLATE - myImageView  -  drop an image viewer onto a window
#!#############################################################################
#!  Populates an IMAGE control AND everything behind it: the picture object,
#!  a master copy, and the routines that load, rebuild and show it. Drop it and
#!  you have a working image view - no extension to add, nothing to wire up.
#!
#!  It keeps TWO images: the MASTER (as loaded, plus any permanent turn or
#!  resize) and the working copy the colour format is applied to. That is what
#!  lets the tools panel switch between 256 colours and black & white all day
#!  without the picture degrading a little more each time.
#!
#!  Everything it declares is keyed off the IMAGE control's own field equate,
#!  so the tools panel can find it by pointing at the same control - no name to
#!  keep in step, and several views on one window never collide.
#!#############################################################################
#CONTROL(myImageView,'myImage - Image view (drag onto a window)'),WINDOW,MULTI,REQ(myImageGlobal),DESCRIPTION('Image view ' & %mvImage),HLP('~myImage.htm')
  CONTROLS
    IMAGE,AT(,,240,180),USE(?ImgView)
  END
#SHEET
  #TAB('&General')
    #BOXED('The view')
      #PROMPT('&Disable this view',CHECK),%mvDisable,DEFAULT(0),AT(10)
      #DISPLAY('Everything this view declares is named after the IMAGE control')
      #DISPLAY('it just dropped, so point the tools panel at the same control')
      #DISPLAY('and the two find each other.')
    #ENDBOXED
    #BOXED('What to load when the window opens')
      #PROMPT('&Load:',DROP('Nothing[N]|A fixed file name[F]|A variable or expression[V]|A test card[T]')),%mvSource,DEFAULT('T')
      #ENABLE(%mvSource='F')
        #PROMPT('File &name:',@s255),%mvFile,DEFAULT('')
      #ENDENABLE
      #ENABLE(%mvSource='V')
        #PROMPT('&Variable / expression:',@s255),%mvFileVar,DEFAULT('')
      #ENDENABLE
      #ENABLE(%mvSource='T')
        #PROMPT('Test card &width:',SPIN(@n5,16,4000,16)),%mvCardW,DEFAULT(640)
        #PROMPT('Test card &height:',SPIN(@n5,16,4000,16)),%mvCardH,DEFAULT(480)
      #ENDENABLE
      #PROMPT('If the file will not load, tell the user',CHECK),%mvWarn,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('How it meets the control')
      #PROMPT('&Fit:',DROP('Proportional (pad)[1]|Contain (no pad)[4]|Cover (crop)[2]|Stretch[0]|Centred 1:1[3]')),%mvFit,DEFAULT('1')
      #PROMPT('Pad / background color:',COLOR),%mvPad,DEFAULT(00FFFFFFH)
    #ENDBOXED
    #BOXED('Colour format to start in')
      #PROMPT('&Colour:',DROP('As loaded[0]|32-bit true colour + alpha[1]|24-bit true colour[2]|16-bit high colour[3]|15-bit high colour[4]|256 colours[5]|16 colours[6]|256 greys[7]|16 greys[8]|4 greys[9]|Black and white[10]|Web-safe 216[11]')),%mvMode,DEFAULT('0')
      #PROMPT('&Dither',CHECK),%mvDither,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#ATSTART
  #DECLARE(%mvImage)
  #DECLARE(%mvKey)
  #DECLARE(%mvCp)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #IF(%ControlOriginal='?ImgView')
      #SET(%mvImage,%Control)
    #ENDIF
  #ENDFOR
  #IF(%mvImage='')
    #ERROR('myImage view in ' & %Procedure & ': the view could not find its own IMAGE control. Delete this control template instance and drop it again.')
  #ENDIF
  #SET(%mvKey,SUB(%mvImage,2,250))
  #SET(%mvCp,INSTRING(':',%mvKey,1,1))
  #LOOP,WHILE(%mvCp>0)
    #SET(%mvKey,SUB(%mvKey,1,%mvCp-1) & '_' & SUB(%mvKey,%mvCp+1,250))
    #SET(%mvCp,INSTRING(':',%mvKey,1,1))
  #ENDLOOP
#ENDAT
#!
#AT(%DataSection),WHERE(%mvDisable=0)
%mvKey:Master        ImageClass                              ! as loaded, plus any permanent turn
%mvKey:Pic           ImageClass                              ! the working copy that is on screen
%mvKey:Mode          LONG                                    ! colour format, live - the tools panel writes here
%mvKey:Dither        BYTE
%mvKey:Thresh        LONG
%mvKey:Src           CSTRING(261)                            ! what was loaded, so Reset can reload it
%mvKey:Redraw        EQUATE(EVENT:User + 230 + %ActiveTemplateInstance)
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%mvDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    %mvKey:Mode = %mvMode
    %mvKey:Dither = %mvDither
    %mvKey:Thresh = 128
    DO %mvKey:Load
  OF EVENT:Sized
    DO %mvKey:Show
  OF %mvKey:Redraw
    DO %mvKey:Rebuild
  END
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%mvDisable=0)
!  Load the source into the MASTER, then build the working copy from it.
%mvKey:Load ROUTINE
#CASE(%mvSource)
#OF('F')
    %mvKey:Src = '%mvFile'
#OF('V')
    %mvKey:Src = CLIP(%mvFileVar)
#ENDCASE
#CASE(%mvSource)
#OF('F')
#OROF('V')
    IF NOT %mvKey:Master.LoadFile(%mvKey:Src)
#IF(%mvWarn)
      MESSAGE('Could not read ' & CLIP(%mvKey:Src), '%Procedure', ICON:Exclamation)
#ENDIF
    END
#OF('T')
    %mvKey:Master.TestCard(%mvCardW, %mvCardH)
    %mvKey:Src = ''
#ENDCASE
    DO %mvKey:Rebuild

!  Working copy = master + the colour format that is selected right now. Doing
!  it this way means changing colour format never eats into the picture: it is
!  always derived from the master in one step.
%mvKey:Rebuild ROUTINE
    IF %mvKey:Master.Ok()
      %mvKey:Master.CloneInto(%mvKey:Pic)
      IF %mvKey:Mode > 0
        %mvKey:Pic.Convert(%mvKey:Mode, %mvKey:Dither, %mvKey:Thresh)
      END
    END
    DO %mvKey:Show

%mvKey:Show ROUTINE
    IF %mvKey:Pic.Ok()
      %mvKey:Pic.Draw(%Window, %mvImage, %mvFit, %mvKey:Pic.ArgbOf(%mvPad))
    END
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - myImageTools  -  the toolbar that drives it
#!#############################################################################
#!  A strip of buttons plus a colour-format list, wired straight to an image.
#!  Point it at the IMAGE control of a myImageView and it drives that; or name
#!  a myImage extension's object and it drives that instead.
#!
#!  Turn, mirror, flip, zoom and fit change the MASTER, so they stack up the way
#!  you would expect. The colour list only ever re-derives the working copy from
#!  the master, so you can go 256 colours -> black & white -> back to 24-bit and
#!  the picture is none the worse for it.
#!
#!  Not MULTI: one toolbar per window, which is what lets its own controls use
#!  real USE variables (a feq-only CHECK can never show its initial state).
#!#############################################################################
#CONTROL(myImageTools,'myImage - Image tools panel (drag onto a window)'),WINDOW,REQ(myImageGlobal),DESCRIPTION('Image tools'),HLP('~myImage.htm')
  CONTROLS
    GROUP('Image tools'),USE(?ImgTool:Group),AT(,,360,54),BOXED
      BUTTON('&Open...'),AT(8,12,46,14),USE(?ImgTool:Open),TIP('Open an image file')
      BUTTON('&Save...'),AT(50,0,46,14),USE(?ImgTool:Save),TIP('Save the picture as it looks now')
      BUTTON('Rot &L'),AT(50,0,26,14),USE(?ImgTool:RotL),TIP('Rotate left')
      BUTTON('Rot &R'),AT(30,0,26,14),USE(?ImgTool:RotR),TIP('Rotate right')
      BUTTON('M&irror'),AT(30,0,34,14),USE(?ImgTool:Mirror),TIP('Flip left to right')
      BUTTON('Fli&p'),AT(38,0,26,14),USE(?ImgTool:Flip),TIP('Flip top to bottom')
      BUTTON('-'),AT(30,0,22,14),USE(?ImgTool:ZoomOut),TIP('Zoom out 20%')
      BUTTON('+'),AT(26,0,22,14),USE(?ImgTool:ZoomIn),TIP('Zoom in 25%')
      BUTTON('&Fit'),AT(26,0,26,14),USE(?ImgTool:Fit),TIP('Shrink to fit the view')
      BUTTON('&Reset'),AT(30,0,34,14),USE(?ImgTool:Reset),TIP('Load it again and start over')
      PROMPT('Colour:'),AT(-310,22,38,10),USE(?ImgTool:ModeP)
      LIST,AT(40,-2,150,11),USE(?ImgTool:Mode),DROP(12),FROM('As loaded|32-bit true colour + alpha|24-bit true colour|16-bit high colour|15-bit high colour|256 colours|16 colours|256 greys|16 greys|4 greys|Black and white|Web-safe 216')
      CHECK('&Dither'),AT(156,1,44,10),USE(ImgTool:Dither),TIP('Floyd-Steinberg error diffusion')
      BUTTON('&Grey'),AT(48,-2,26,14),USE(?ImgTool:Grey),TIP('Greyscale')
      BUTTON('I&nvert'),AT(30,0,32,14),USE(?ImgTool:Invert),TIP('Invert')
      BUTTON('Sepi&a'),AT(36,0,32,14),USE(?ImgTool:Sepia),TIP('Sepia')
    END
  END
#SHEET
  #TAB('&General')
    #BOXED('What it drives')
      #PROMPT('&Disable this panel',CHECK),%mtDisable,DEFAULT(0),AT(10)
      #PROMPT('Drive:',DROP('A myImage view control[V]|A myImage extension object[E]')),%mtLink,DEFAULT('V')
      #ENABLE(%mtLink='V')
        #PROMPT('The view''s &IMAGE control:',CONTROL),%mtImage,REQ
        #DISPLAY('Pick the IMAGE that the myImage view control dropped. The')
        #DISPLAY('panel works out every name it needs from that one control,')
        #DISPLAY('so there is nothing to keep in step.')
      #ENDENABLE
      #ENABLE(%mtLink='E')
        #PROMPT('The extension''s &Object name:',@s64),%mtObject,DEFAULT('Pic1')
        #DISPLAY('Type the same Object name you gave the myImage extension on')
        #DISPLAY('this procedure. Colour changes apply straight to that object,')
        #DISPLAY('and Reset runs its Refresh: routine.')
      #ENDENABLE
    #ENDBOXED
    #BOXED('Which tools to show')
      #PROMPT('&Open and Save',CHECK),%mtShowFile,DEFAULT(1),AT(10)
      #PROMPT('&Turn (rotate, mirror, flip)',CHECK),%mtShowTurn,DEFAULT(1),AT(10)
      #PROMPT('&Zoom and Fit',CHECK),%mtShowZoom,DEFAULT(1),AT(10)
      #PROMPT('&Colour format list',CHECK),%mtShowMode,DEFAULT(1),AT(10)
      #PROMPT('&Effects (grey, invert, sepia)',CHECK),%mtShowFx,DEFAULT(1),AT(10)
      #PROMPT('&Reset',CHECK),%mtShowReset,DEFAULT(1),AT(10)
      #DISPLAY('Anything unticked is hidden when the window opens - the buttons')
      #DISPLAY('stay on the window so you can turn them back on later.')
    #ENDBOXED
    #BOXED('Saving')
      #PROMPT('Default save format:',DROP('From the file extension[0]|PNG[4]|JPEG[3]|BMP[1]|GIF[2]|TIFF[5]|Targa[9]|PCX[10]|PNM[11]|QOI[12]')),%mtSaveFmt,DEFAULT('0')
      #PROMPT('JPEG quality:',SPIN(@n3,1,100,5)),%mtQuality,DEFAULT(85)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#ATSTART
  #DECLARE(%mtKey)
  #DECLARE(%mtCp)
  #DECLARE(%mtObj)
  #DECLARE(%mtMaster)
  #DECLARE(%mtRebuild)
  #DECLARE(%mtReload)
  #DECLARE(%mtLive)
  #SET(%mtLive,0)
  #IF(%mtLink='E')
    #IF(%mtObject='')
      #ERROR('myImage tools panel in ' & %Procedure & ': type the myImage extension''s Object name on the panel''s General tab.')
    #ENDIF
    #SET(%mtObj,%mtObject)
    #SET(%mtMaster,%mtObject)
    #SET(%mtRebuild,'DO Show:' & %mtObject)
    #SET(%mtReload,'DO Refresh:' & %mtObject)
  #ELSE
    #SET(%mtKey,SUB(%mtImage,2,250))
    #SET(%mtCp,INSTRING(':',%mtKey,1,1))
    #LOOP,WHILE(%mtCp>0)
      #SET(%mtKey,SUB(%mtKey,1,%mtCp-1) & '_' & SUB(%mtKey,%mtCp+1,250))
      #SET(%mtCp,INSTRING(':',%mtKey,1,1))
    #ENDLOOP
    #IF(%mtKey='')
      #ERROR('myImage tools panel in ' & %Procedure & ': pick the view''s IMAGE control on the panel''s General tab (the "Drive" prompt) - without it there is no image to drive.')
    #ENDIF
    #SET(%mtObj,%mtKey & ':Pic')
    #SET(%mtMaster,%mtKey & ':Master')
    #SET(%mtRebuild,'DO ' & %mtKey & ':Rebuild')
    #SET(%mtReload,'DO ' & %mtKey & ':Load')
    #SET(%mtLive,1)
  #ENDIF
#ENDAT
#!
#AT(%DataSectionBeforeWindow),WHERE(%mtDisable=0)
ImgTool:Dither       BYTE                                    ! the panel's own checkbox
#ENDAT
#!
#AT(%DataSection),WHERE(%mtDisable=0)
ImgTool:Sync         EQUATE(EVENT:User + 240)                ! deferred: read the target AFTER it has loaded
ImgTool:File         STRING(261)
#ENDAT
#!
#!  OpenWindow hides the tools that were turned off, then POSTs a private event
#!  so the colour list is filled in AFTER the view has had its own OpenWindow -
#!  which means it does not matter which of the two controls was dropped first.
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%mtDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
#IF(%mtShowFile=0)
    ?ImgTool:Open{PROP:Hide} = 1
    ?ImgTool:Save{PROP:Hide} = 1
#ENDIF
#IF(%mtShowTurn=0)
    ?ImgTool:RotL{PROP:Hide} = 1
    ?ImgTool:RotR{PROP:Hide} = 1
    ?ImgTool:Mirror{PROP:Hide} = 1
    ?ImgTool:Flip{PROP:Hide} = 1
#ENDIF
#IF(%mtShowZoom=0)
    ?ImgTool:ZoomOut{PROP:Hide} = 1
    ?ImgTool:ZoomIn{PROP:Hide} = 1
    ?ImgTool:Fit{PROP:Hide} = 1
#ENDIF
#IF(%mtShowMode=0)
    ?ImgTool:ModeP{PROP:Hide} = 1
    ?ImgTool:Mode{PROP:Hide} = 1
    ?ImgTool:Dither{PROP:Hide} = 1
#ENDIF
#IF(%mtShowFx=0)
    ?ImgTool:Grey{PROP:Hide} = 1
    ?ImgTool:Invert{PROP:Hide} = 1
    ?ImgTool:Sepia{PROP:Hide} = 1
#ENDIF
#IF(%mtShowReset=0)
    ?ImgTool:Reset{PROP:Hide} = 1
#ENDIF
    POST(ImgTool:Sync)
  OF ImgTool:Sync
#IF(%mtLive)
    ImgTool:Dither = %mtKey:Dither
    ?ImgTool:Mode{PROP:Selected} = %mtKey:Mode + 1
#ELSE
    ?ImgTool:Mode{PROP:Selected} = 1
#ENDIF
    DISPLAY
  END
#ENDAT
#!
#!  The buttons and the list are FIELD events, so they belong in TakeFieldEvent
#!  - a handler for them in TakeWindowEvent compiles and never fires.
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%mtDisable=0)
  CASE FIELD()
  OF ?ImgTool:Open
    IF EVENT() = EVENT:Accepted
      ImgTool:File = ''
      IF FILEDIALOG('Open an image', ImgTool:File, |
           'All images|*.bmp;*.dib;*.rle;*.gif;*.jpg;*.jpeg;*.jpe;*.jfif;*.png;*.tif;*.tiff;' & |
           '*.ico;*.cur;*.emf;*.wmf;*.tga;*.pcx;*.pnm;*.ppm;*.pgm;*.pbm;*.qoi|' & |
           'BMP|*.bmp|GIF|*.gif|JPEG|*.jpg;*.jpeg|PNG|*.png|TIFF|*.tif;*.tiff|' & |
           'Targa|*.tga|PCX|*.pcx|PNM|*.pnm;*.ppm;*.pgm;*.pbm|QOI|*.qoi|All files|*.*', |
           FILE:KeepDir + FILE:LongName)
        IF %mtMaster.LoadFile(ImgTool:File)
#IF(%mtLive)
          %mtKey:Src = CLIP(ImgTool:File)
#ENDIF
          %mtRebuild
        ELSE
          MESSAGE('Could not read that file.||' & CLIP(ImgTool:File), '%Procedure', ICON:Exclamation)
        END
      END
    END
  OF ?ImgTool:Save
    IF EVENT() = EVENT:Accepted
      ImgTool:File = ''
      IF FILEDIALOG('Save the image as', ImgTool:File, |
           'PNG|*.png|JPEG|*.jpg|BMP|*.bmp|GIF|*.gif|TIFF|*.tif|Targa|*.tga|PCX|*.pcx|' & |
           'PNM|*.ppm|QOI|*.qoi', FILE:KeepDir + FILE:LongName + FILE:Save)
        %mtObj.Quality = %mtQuality
        IF NOT %mtObj.SaveFile(ImgTool:File, %mtSaveFmt)
          MESSAGE('Could not write that file.||' & CLIP(ImgTool:File) & |
                  '||Engine error ' & %mtObj.LastError(), '%Procedure', ICON:Exclamation)
        END
      END
    END
  OF ?ImgTool:RotL
    IF EVENT() = EVENT:Accepted
      %mtMaster.RotateLeft()
      %mtRebuild
    END
  OF ?ImgTool:RotR
    IF EVENT() = EVENT:Accepted
      %mtMaster.RotateRight()
      %mtRebuild
    END
  OF ?ImgTool:Mirror
    IF EVENT() = EVENT:Accepted
      %mtMaster.Mirror()
      %mtRebuild
    END
  OF ?ImgTool:Flip
    IF EVENT() = EVENT:Accepted
      %mtMaster.FlipVert()
      %mtRebuild
    END
  OF ?ImgTool:ZoomIn
    IF EVENT() = EVENT:Accepted
      %mtMaster.Zoom(125, Img:Best)
      %mtRebuild
    END
  OF ?ImgTool:ZoomOut
    IF EVENT() = EVENT:Accepted
      %mtMaster.Zoom(80, Img:Best)
      %mtRebuild
    END
  OF ?ImgTool:Fit
    IF EVENT() = EVENT:Accepted
      DO ImgTool:FitToView
    END
  OF ?ImgTool:Reset
    IF EVENT() = EVENT:Accepted
      %mtReload
    END
  OF ?ImgTool:Grey
    IF EVENT() = EVENT:Accepted
      %mtMaster.Greyscale(Img:Luma)
      %mtRebuild
    END
  OF ?ImgTool:Invert
    IF EVENT() = EVENT:Accepted
      %mtMaster.Invert()
      %mtRebuild
    END
  OF ?ImgTool:Sepia
    IF EVENT() = EVENT:Accepted
      %mtMaster.Sepia()
      %mtRebuild
    END
  OF ?ImgTool:Mode
    IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
      DO ImgTool:Apply
    END
  OF ?ImgTool:Dither
    IF EVENT() = EVENT:Accepted
      DO ImgTool:Apply
    END
  END
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%mtDisable=0)
!  Push the panel's colour choice at the target and redraw it.
ImgTool:Apply ROUTINE
#IF(%mtLive)
    %mtKey:Mode = CHOICE(?ImgTool:Mode) - 1
    IF %mtKey:Mode < 0 THEN %mtKey:Mode = 0.
    %mtKey:Dither = ImgTool:Dither
    %mtRebuild
#ELSE
    IF CHOICE(?ImgTool:Mode) > 1
      %mtObj.Convert(CHOICE(?ImgTool:Mode) - 1, ImgTool:Dither, 128)
      %mtRebuild
    ELSE
      %mtReload
    END
#ENDIF

!  Shrink the picture itself down to the view, keeping the ratio.
ImgTool:FitToView ROUTINE
  DATA
vw  LONG
vh  LONG
sp  LONG
  CODE
#IF(%mtLive)
    SETTARGET(%Window)
    sp = 0{PROP:Pixels}
    0{PROP:Pixels} = 1
    vw = %mtImage{PROP:Width}
    vh = %mtImage{PROP:Height}
    0{PROP:Pixels} = sp
    SETTARGET()
    IF vw > 3 AND vh > 3
      %mtMaster.Fit(vw, vh, Img:Contain, 0)
      %mtRebuild
    END
#ELSE
    %mtObj.Fit(320, 240, Img:Contain, 0)
    %mtRebuild
#ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myImage template set
#!-----------------------------------------------------------------------------
