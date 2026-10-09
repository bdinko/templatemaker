#TEMPLATE(myYuru,'myYuru - Yuruyurau animated flow-field art on windows - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myYuru template set  -  animated "yuruyurau" flow-field / particle art drawn
#!  onto an IMAGE control. Each frame the class plots ~10,000 particles into an
#!  in-memory 24-bit BMP and reloads the control - no external dependencies.
#!
#!  myYuruGlobal  (APPLICATION) - INCLUDEs YuruClass. Add once, globally.
#!  myYuru        (PROCEDURE)   - animates a flow field into an IMAGE you already
#!                have on a WINDOW. Add once per animation (multiple per window is
#!                fine - each instance gets its own object).
#!  myYuruControl (CONTROL)     - the EASY path: drag it onto a window and it drops
#!                a ready-made IMAGE with the animation already wired. Self-
#!                contained (INCLUDEs the class itself) - no global extension needed.
#!
#!  REQUIRED FILES: copy YuruClass.inc, YuruClass.clw AND yurucanvas.c (shipped
#!  beside this .tpl) to a folder on the Clarion redirection path (the app folder
#!  or \clarion12\libsrc\win). Store them in ANSI/CRLF (not UTF-8, not LF-only).
#!  The app also needs the DOS file driver (add it in the app's driver list, or it
#!  is pulled in automatically once any file uses DRIVER('DOS')).
#!
#!  BACKENDS: the "Rendering / Backend" prompt picks how each frame reaches the
#!  screen. "BMP file" (default) writes a temp .bmp and reloads the IMAGE - pure
#!  Clarion. "Direct2D GPU" hosts a child window over the IMAGE and blits each
#!  frame straight to the GPU - no temp file, no reload. Direct2D ships with
#!  Windows 7+ (no redistributable); yurucanvas.c is compiled in automatically by
#!  a PRAGMA in YuruClass.clw. If the target can't be created it falls back to BMP.
#!
#!  API (the object is in the procedure's data - call it from any embed):
#!    Flow.Preset   = Yuru:Ribbon        ! Ribbon/Seashell/Nebula/Lattice/Reeds/Plume
#!    Flow.InkColor = COLOR:White        ! any Clarion 00BBGGRR color
#!    Flow.Speed    = 1.5                ! time-step multiplier
#!    Flow.Paint()                       ! draw the current frame now
#!    DO Start:Flow  /  DO Stop:Flow     ! pause / resume the animation
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myYuruGlobal
#!#############################################################################
#EXTENSION(myYuruGlobal,'myYuru - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myYuru')
      #DISPLAY('myYuru Global - Version 1.0')
      #DISPLAY('Adds the YuruClass yuruyurau flow-field renderer.')
      #DISPLAY('Add once, at the Application (global) level. IMPORTANT: copy')
      #DISPLAY('YuruClass.inc + YuruClass.clw to the redirection path - ANSI/CRLF.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myYuruDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%myYuruDisable=0)
INCLUDE('YuruClass.INC'),ONCE
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myYuru (WINDOW)  -  add once per animation
#!#############################################################################
#EXTENSION(myYuru,'myYuru - Animate a flow field on this window'),PROCEDURE,REQ(myYuruGlobal),DESCRIPTION(' [Yuru] ' & %myYuruObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this animation',CHECK),%myYuruDisableThis,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%myYuruObject,REQ,DEFAULT('Flow' & %ActiveTemplateInstance)
      #PROMPT('&Image control to draw into:',CONTROL),%myYuruImage,REQ
    #ENDBOXED
    #BOXED('Sketch')
      #PROMPT('&Preset:',DROP('Ribbon[1]|Seashell[2]|Nebula[3]|Lattice[4]|Reeds[5]|Plume[6]')),%myYuruPreset,DEFAULT('1')
      #PROMPT('&Speed (time-step multiplier):',@n3.1),%myYuruSpeed,DEFAULT(1.0)
    #ENDBOXED
    #BOXED('Look')
      #PROMPT('&Ink color:',COLOR),%myYuruInk,DEFAULT(00FFFFFFH)
      #PROMPT('&Background grey (0-64, dark looks best):',SPIN(@n3,0,64,1)),%myYuruBack,DEFAULT(9)
      #PROMPT('&Glow per point (1-255):',SPIN(@n3,1,255,1)),%myYuruBright,DEFAULT(55)
    #ENDBOXED
    #BOXED('Animation')
      #PROMPT('&Run on window open',CHECK),%myYuruRun,DEFAULT(1),AT(10)
      #PROMPT('Timer &interval (1/100 sec):',SPIN(@n4,1,500,1)),%myYuruInterval,DEFAULT(4)
    #ENDBOXED
    #BOXED('Rendering')
      #PROMPT('&Backend:',DROP('BMP file - compatible, no extra files[0]|Direct2D GPU - direct-to-window, no temp file[1]')),%myYuruBackend,DEFAULT('0')
      #DISPLAY('Direct2D also needs yurucanvas.c on the redirection path (ANSI/CRLF).')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myYuruDisableThis=0 AND %myYuruImage)
%myYuruObject        YuruClass                                ! one animation object for this instance
Run:%myYuruObject    BYTE                                     ! is the animation currently ticking?
Redraw:%myYuruObject EQUATE(EVENT:User + 210 + %ActiveTemplateInstance) ! private "repaint" event (unique per animation)
#ENDAT
#!
#! PRIORITY(2000) puts this self-contained CASE EVENT() ABOVE the framework's own
#! LOOP/CASE scaffolding (registered at PRIORITY 2500) - the same proven spot
#! myGauge/myQRDraw/myPixel use. 2500 collides with the framework's CASE EVENT().
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myYuruDisableThis=0 AND %myYuruImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    %myYuruObject.Init(%myYuruImage)
    %myYuruObject.Backend    = %myYuruBackend                 ! Yuru:BmpFile(0) or Yuru:Direct2D(1) - set before the first Paint
    %myYuruObject.Preset     = %myYuruPreset
    %myYuruObject.InkColor   = %myYuruInk
    %myYuruObject.BackGray   = %myYuruBack
    %myYuruObject.Brightness = %myYuruBright
    %myYuruObject.Speed      = %myYuruSpeed
    Run:%myYuruObject        = %myYuruRun
    POST(Redraw:%myYuruObject)                               ! first frame, after the window has opened
    IF 0{PROP:Timer} = 0 OR %myYuruInterval < 0{PROP:Timer}  ! claim the timer only if it's off or we'd make it faster
      0{PROP:Timer} = %myYuruInterval
    END
  OF Redraw:%myYuruObject
    %myYuruObject.Paint()
  OF EVENT:Sized
    POST(Redraw:%myYuruObject)                               ! re-sync the Direct2D host to the new control size at once
  OF EVENT:Timer
    IF Run:%myYuruObject
      %myYuruObject.NextFrame()                              ! advance the clock + repaint
    END
  END
#ENDAT
#!
#!  Convenience ROUTINEs: pause / resume / restart this animation from any embed.
#AT(%ProcedureRoutines),WHERE(%myYuruDisableThis=0 AND %myYuruImage)
Start:%myYuruObject ROUTINE
  Run:%myYuruObject = 1
Stop:%myYuruObject ROUTINE
  Run:%myYuruObject = 0
Restart:%myYuruObject ROUTINE
  %myYuruObject.Restart()
  %myYuruObject.Paint()
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - myYuruControl  -  drag a ready-made animation onto a window
#!#############################################################################
#!  Drops an IMAGE control AND wires the animation to it in one drag. Self-
#!  contained: it emits INCLUDE('YuruClass.INC'),ONCE at %CustomGlobalDeclarations
#!  - the per-MODULE compile-global embed - so the user does NOT need the
#!  myYuruGlobal extension. WINDOW + MULTI = many per window. The control's own
#!  field equate is captured in %myYuruCtlImage via the proven
#!  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance) idiom.
#!#############################################################################
#CONTROL(myYuruControl,'myYuru - Yuruyurau animation (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('Yuru animation ' & %myYuruCtlObject),HLP('~myYuru.htm')
  CONTROLS
    IMAGE,AT(,,160,160),USE(?Yuru)
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this animation',CHECK),%myYuruCtlDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%myYuruCtlObject,REQ,DEFAULT('Flow' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('Sketch')
      #PROMPT('&Preset:',DROP('Ribbon[1]|Seashell[2]|Nebula[3]|Lattice[4]|Reeds[5]|Plume[6]')),%myYuruCtlPreset,DEFAULT('1')
      #PROMPT('&Speed (time-step multiplier):',@n3.1),%myYuruCtlSpeed,DEFAULT(1.0)
    #ENDBOXED
    #BOXED('Look')
      #PROMPT('&Ink color:',COLOR),%myYuruCtlInk,DEFAULT(00FFFFFFH)
      #PROMPT('&Background grey (0-64, dark looks best):',SPIN(@n3,0,64,1)),%myYuruCtlBack,DEFAULT(9)
      #PROMPT('&Glow per point (1-255):',SPIN(@n3,1,255,1)),%myYuruCtlBright,DEFAULT(55)
    #ENDBOXED
    #BOXED('Animation')
      #PROMPT('&Run on window open',CHECK),%myYuruCtlRun,DEFAULT(1),AT(10)
      #PROMPT('Timer &interval (1/100 sec):',SPIN(@n4,1,500,1)),%myYuruCtlInterval,DEFAULT(4)
    #ENDBOXED
    #BOXED('Rendering')
      #PROMPT('&Backend:',DROP('BMP file - compatible, no extra files[0]|Direct2D GPU - direct-to-window, no temp file[1]')),%myYuruCtlBackend,DEFAULT('0')
      #DISPLAY('Direct2D also needs yurucanvas.c on the redirection path (ANSI/CRLF).')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Capture THIS instance's IMAGE field equate (auto-uniqued by AppGen on drop).
#ATSTART
  #DECLARE(%myYuruCtlImage)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%myYuruCtlImage,%Control)
  #ENDFOR
#ENDAT
#!
#! Self-contained: pull in the class globally (ONCE = safe if the global extension
#! or another yuru control is also present).
#AT(%CustomGlobalDeclarations),WHERE(%myYuruCtlDisable=0)
INCLUDE('YuruClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%myYuruCtlDisable=0)
%myYuruCtlObject        YuruClass                             ! one animation object for this control
Run:%myYuruCtlObject    BYTE
Redraw:%myYuruCtlObject EQUATE(EVENT:User + 210 + %ActiveTemplateInstance) ! private "repaint" event (unique per animation)
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myYuruCtlDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    %myYuruCtlObject.Init(%myYuruCtlImage)
    %myYuruCtlObject.Backend    = %myYuruCtlBackend           ! Yuru:BmpFile(0) or Yuru:Direct2D(1) - set before the first Paint
    %myYuruCtlObject.Preset     = %myYuruCtlPreset
    %myYuruCtlObject.InkColor   = %myYuruCtlInk
    %myYuruCtlObject.BackGray   = %myYuruCtlBack
    %myYuruCtlObject.Brightness = %myYuruCtlBright
    %myYuruCtlObject.Speed      = %myYuruCtlSpeed
    Run:%myYuruCtlObject        = %myYuruCtlRun
    POST(Redraw:%myYuruCtlObject)                            ! first frame, after the window has opened
    IF 0{PROP:Timer} = 0 OR %myYuruCtlInterval < 0{PROP:Timer} ! claim the timer only if it's off or we'd make it faster
      0{PROP:Timer} = %myYuruCtlInterval
    END
  OF Redraw:%myYuruCtlObject
    %myYuruCtlObject.Paint()
  OF EVENT:Sized
    POST(Redraw:%myYuruCtlObject)                            ! re-sync the Direct2D host to the new control size at once
  OF EVENT:Timer
    IF Run:%myYuruCtlObject
      %myYuruCtlObject.NextFrame()
    END
  END
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%myYuruCtlDisable=0)
Start:%myYuruCtlObject ROUTINE
  Run:%myYuruCtlObject = 1
Stop:%myYuruCtlObject ROUTINE
  Run:%myYuruCtlObject = 0
Restart:%myYuruCtlObject ROUTINE
  %myYuruCtlObject.Restart()
  %myYuruCtlObject.Paint()
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myYuru template set
#!-----------------------------------------------------------------------------
