  PROGRAM
!  Does a Clarion window see the mouse wheel through PROP:WndProc, and can the
!  callback POST an event back into the ACCEPT loop? The window title is the
!  answer: the driver script sends WM_MOUSEWHEEL and reads the title back.
  MAP
Main PROCEDURE
    AirImg_WheelProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
    AirImg_HookWheel(LONG,LONG),LONG,PROC
    AirImg_DropWheel(LONG),LONG,PROC
    MODULE('win32')
      airApi_SetProp(ULONG hWnd,LONG lpString,LONG hData),LONG,PASCAL,PROC,NAME('SetPropA')
      airApi_GetProp(ULONG hWnd,LONG lpString),LONG,PASCAL,NAME('GetPropA')
      airApi_RemoveProp(ULONG hWnd,LONG lpString),LONG,PASCAL,PROC,NAME('RemovePropA')
      airApi_CallWndProc(LONG lpPrevWndFunc,ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam),LONG,PASCAL,NAME('CallWindowProcA')
      airApi_KeyState(LONG),SHORT,PASCAL,NAME('GetKeyState')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE

AirImg:WheelUp       EQUATE(EVENT:User + 216)
AirImg:WheelDown     EQUATE(EVENT:User + 217)
AirImg:CtrlUp        EQUATE(EVENT:User + 218)
AirImg:CtrlDown      EQUATE(EVENT:User + 219)

  CODE
  Main

Main PROCEDURE
Win     WINDOW('AirWheelTest'),AT(,,200,120),SYSTEM,GRAY,TIMER(100)
          IMAGE,AT(4,4,190,110),USE(?Pic)
        END
up      LONG
down    LONG
cup     LONG
cdown   LONG
ticks   LONG
  CODE
  OPEN(Win)
  AirImg_HookWheel(Win{PROP:Handle},Win{PROP:WndProc})
  Win{PROP:WndProc} = ADDRESS(AirImg_WheelProc)
  ACCEPT
    CASE EVENT()
    OF AirImg:WheelUp
      up += 1
      DO Retitle
    OF AirImg:WheelDown
      down += 1
      DO Retitle
    OF AirImg:CtrlUp
      cup += 1
      DO Retitle
    OF AirImg:CtrlDown
      cdown += 1
      DO Retitle
    OF EVENT:Timer
      ticks += 1
      IF ticks > 12 THEN POST(EVENT:CloseWindow).             ! never hang the harness
    END
  END
  Win{PROP:WndProc} = AirImg_DropWheel(Win{PROP:Handle})
  CLOSE(Win)

Retitle ROUTINE
  Win{PROP:Text} = 'AirWheelTest U=' & up & ' D=' & down & ' CU=' & cup & ' CD=' & cdown

!  Park the window's own procedure on the window itself, so one callback can
!  serve any number of windows without a scrap of Clarion-side bookkeeping.
AirImg_HookWheel PROCEDURE(LONG pHwnd,LONG pOldProc)
prop CSTRING('AirImgOldWndProc')
  CODE
  airApi_SetProp(pHwnd,ADDRESS(prop),pOldProc)
  RETURN pOldProc

AirImg_DropWheel PROCEDURE(LONG pHwnd)
prop CSTRING('AirImgOldWndProc')
old  LONG,AUTO
  CODE
  old = airApi_GetProp(pHwnd,ADDRESS(prop))
  airApi_RemoveProp(pHwnd,ADDRESS(prop))
  RETURN old

AirImg_WheelProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
WM_MOUSEWHEEL EQUATE(020Ah)
prop CSTRING('AirImgOldWndProc')
old  LONG,AUTO
dz   LONG,AUTO
  CODE
  old = airApi_GetProp(hWnd,ADDRESS(prop))
  IF wMsg = WM_MOUSEWHEEL
    dz = BSHIFT(BAND(wParam,0FFFF0000h),-16)                  ! HIWORD = the distance
    IF dz > 32767 THEN dz -= 65536.                           ! and it is signed
    IF BAND(wParam,0008h)                                     ! LOWORD carries MK_CONTROL
      IF dz > 0
        POST(AirImg:CtrlUp)
      ELSIF dz < 0
        POST(AirImg:CtrlDown)
      END
    ELSE
      IF dz > 0
        POST(AirImg:WheelUp)
      ELSIF dz < 0
        POST(AirImg:WheelDown)
      END
    END
  END
  IF old
    RETURN airApi_CallWndProc(old,hWnd,wMsg,wParam,lParam)
  END
  RETURN 0
