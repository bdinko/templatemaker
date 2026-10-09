!ABCIncludeFile(MYYURU)
! ============================================================================
!  YuruClass - "yuruyurau" animated flow-field / particle art for Clarion.
!
!  Renders the pure-trigonometry point sketches of the generative artist
!  @yuruyurau onto a Clarion IMAGE control. Clarion has no per-pixel canvas,
!  so each frame the class:
!    1. computes the formula for every particle (10,000 - or 30,000 Lattice),
!    2. plots each point ADDITIVELY into an in-memory 24-bit BMP byte buffer,
!       so overlapping points brighten (mimics the alpha-stroke glow of the
!       p5.js originals),
!    3. writes the buffer to a temp .bmp file,
!    4. loads it into the IMAGE control with feq{PROP:Text} = filename.
!  Two temp files are alternated per object so the control never holds a lock
!  on the file the next frame is being written to.
!
!  TWO BACKENDS (SELF.Backend):
!    Yuru:BmpFile  (default) - the classic path above: temp .bmp + PROP:Text
!                  reload. Pure Clarion, needs only the DOS file driver.
!    Yuru:Direct2D - GPU DIRECT-TO-WINDOW. Hosts a child window over the IMAGE
!                  control and owns a Direct2D render target on it; each frame's
!                  pixel buffer is uploaded as a bitmap and blitted straight to
!                  the screen - NO temp file, NO reload (the round-trip that
!                  dominated the frame time). Direct2D ships with Windows 7+, so
!                  still no redistributable; the C shim is yurucanvas.c, compiled
!                  in automatically via a PRAGMA in YuruClass.clw. If the target
!                  can't be created it silently falls back to the BMP-file path.
!
!  Pure Clarion + one small C shim (yurucanvas.c) for the optional Direct2D
!  backend - no dictionary, no third-party classes, no redistributable DLLs.
!  The internal bitmap is a fixed 400x400; the display (IMAGE control, or the
!  Direct2D host) scales it to whatever size you give the control.
!
!  USAGE (handled by the myYuru template, or call it yourself):
!    INCLUDE('YuruClass.INC'),ONCE     then one instance per animation:
!      Flow   YuruClass
!    Flow.Init(?Canvas)                 ! remember the IMAGE control
!    Flow.Backend  = Yuru:Direct2D      ! optional: GPU direct-to-window (else BMP file)
!    Flow.Preset   = Yuru:Ribbon
!    Flow.InkColor = COLOR:White        ! any Clarion 00BBGGRR color
!    Flow.Speed    = 1.0
!    Flow.Paint()                       ! draw the first frame
!    ...on each window EVENT:Timer:  Flow.NextFrame()   ! advance + repaint
!
!  This file MUST be stored in ANSI/CRLF (not UTF-8, not LF-only).
! ============================================================================

Yuru:Ribbon        EQUATE(1)                                 ! 10k particles, single loop
Yuru:Seashell      EQUATE(2)                                 ! atan2 petal bloom
Yuru:Nebula        EQUATE(3)                                 ! atan2 orbital rings
Yuru:Lattice       EQUATE(4)                                 ! 30k, modular interference
Yuru:Reeds         EQUATE(5)                                 ! swaying strands, reads the loop index
Yuru:Plume         EQUATE(6)                                 ! atan2 fast feather

! ---- rendering backends (SELF.Backend) ------------------------------------
Yuru:BmpFile       EQUATE(0)                                 ! classic: write a temp .bmp + reload the IMAGE (default, no deps)
Yuru:Direct2D      EQUATE(1)                                 ! GPU direct-to-window: blit the frame to a Direct2D child host (no file)

YuruClass CLASS,TYPE,MODULE('YuruClass.CLW'),LINK('YuruClass.CLW')
Feq                SIGNED                                    ! the IMAGE control we paint into
Preset             LONG                                      ! one of the Yuru:xxx equates
tVal               REAL                                      ! animation clock
Speed              REAL                                      ! time-step multiplier (0.1 .. 5.0)
InkColor           LONG                                      ! particle color, Clarion 00BBGGRR
BackGray           LONG                                      ! background grey level 0..255 (near-black looks best)
Brightness         LONG                                      ! additive brightness per plotted point (1..255)
Backend            BYTE                                      ! Yuru:BmpFile (default) or Yuru:Direct2D (GPU direct-to-window)
! ---- Direct2D direct-to-window state (only used when Backend=Yuru:Direct2D) -
HwndHost           LONG                                      ! child host HWND over the IMAGE control
HCanvas            LONG                                      ! Direct2D render-target handle
HostX              LONG                                      ! child host position in pixels (=the control's pixel rect)
HostY              LONG
HostW              LONG                                      ! child host size in pixels (=the control's pixel rect)
HostH              LONG
D2Ready            BYTE                                      ! host + target created and live
D2Failed           BYTE                                      ! setup failed once -> stay on the BMP-file fallback
! ---- internal (per instance) ----------------------------------------------
IncR               LONG                                      ! per-channel additive step (derived from InkColor+Brightness)
IncG               LONG
IncB               LONG
FileA              CSTRING(261)                              ! two temp .bmp files, alternated
FileB              CSTRING(261)
Toggle             BYTE
Inited             BYTE
! ---- methods --------------------------------------------------------------
Construct          PROCEDURE
Destruct           PROCEDURE                                 ! best-effort temp-file cleanup
Init               PROCEDURE(SIGNED pImageFeq)               ! remember the control, build unique temp names
SetBackend         PROCEDURE(BYTE pBackend)                  ! switch Yuru:BmpFile <-> Yuru:Direct2D at runtime (tears down the D2D host)
Restart            PROCEDURE                                 ! zero the clock
Dt                 PROCEDURE(),REAL                          ! time step for the current preset
Paint              PROCEDURE                                 ! render the current frame into the image
NextFrame          PROCEDURE                                 ! advance the clock one step, then Paint
SaveAs             PROCEDURE(STRING pFile)                   ! write the last-rendered frame to a named .bmp
! ---- internal -------------------------------------------------------------
RecalcInc          PROCEDURE                                 ! derive IncR/IncG/IncB from InkColor+Brightness
ClearBuf           PROCEDURE                                 ! fill the whole pixel buffer with BackGray (ALL() alone only does 255 bytes)
EnsureHwnd         PROCEDURE                                 ! lazily create the Direct2D child host + target (Backend=Yuru:Direct2D)
SyncSize           PROCEDURE                                 ! follow the IMAGE control when the window resizes/moves (Direct2D)
Plot               PROCEDURE(REAL pX,REAL pY)                ! additive plot of one point (off-canvas ignored)
Ribbon             PROCEDURE
Seashell           PROCEDURE
Nebula             PROCEDURE
Lattice            PROCEDURE
Reeds              PROCEDURE
Plume              PROCEDURE
                   END
