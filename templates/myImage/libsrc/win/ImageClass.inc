!ABCIncludeFile(MYIMAGE)
! ============================================================================
!  ImageClass - read, convert and transform images from Clarion.
!
!  Twelve formats in, nine out; every common colour format; the usual
!  transforms - and it all runs through imgcore.c, a C engine compiled into
!  your app by Clarion's own C compiler. Nothing to install, nothing to ship:
!  the pixel work is plain C and the decoders Windows already owns are reached
!  through GDI+, which is part of Windows.
!
!  USAGE
!    INCLUDE('ImageClass.INC'),ONCE          then declare one per image:
!      Pic   ImageClass
!
!    IF Pic.LoadFile('holiday.jpg')
!      Pic.Resize(800, 600, Img:Best)
!      Pic.Convert(Img:Pal256, 1)            ! 256 colours, dithered
!      Pic.SaveFile('holiday.gif')
!      Pic.Draw(MyWindow, ?Preview)          ! show it in an IMAGE control
!    END
!
!  Every method returns 1 for done and 0 for failed; LastError() explains a 0.
!  An object owns exactly one image and cleans it up in its Destruct.
!
!  This file MUST be stored in ANSI (not UTF-8), CRLF line ends.
! ============================================================================

! ---- file formats -----------------------------------------------------------
Img:Unknown     EQUATE(0)
Img:Bmp         EQUATE(1)                    ! read + write (1/4/8/24/32-bit)
Img:Gif         EQUATE(2)                    ! read + write
Img:Jpeg        EQUATE(3)                    ! read + write (quality 0..100)
Img:Png         EQUATE(4)                    ! read + write
Img:Tiff        EQUATE(5)                    ! read + write
Img:Ico         EQUATE(6)                    ! read
Img:Emf         EQUATE(7)                    ! read
Img:Wmf         EQUATE(8)                    ! read
Img:Tga         EQUATE(9)                    ! read + write (RLE or raw)
Img:Pcx         EQUATE(10)                   ! read + write
Img:Pnm         EQUATE(11)                   ! read + write (pbm/pgm/ppm)
Img:Qoi         EQUATE(12)                   ! read + write

! ---- colour formats ---------------------------------------------------------
Img:True32      EQUATE(1)                    ! 32-bit, 8 bits of alpha
Img:True24      EQUATE(2)                    ! 24-bit, alpha discarded
Img:High16      EQUATE(3)                    ! 16-bit 5-6-5
Img:High15      EQUATE(4)                    ! 15-bit 5-5-5
Img:Pal256      EQUATE(5)                    ! 256 colours, median-cut palette
Img:Pal16       EQUATE(6)                    ! 16 colours, median-cut palette
Img:Grey256     EQUATE(7)                    ! 8-bit greyscale
Img:Grey16      EQUATE(8)                    ! 4-bit greyscale
Img:Grey4       EQUATE(9)                    ! 2-bit greyscale
Img:Mono        EQUATE(10)                   ! 1-bit black & white
Img:Web216      EQUATE(11)                   ! the 216-colour web-safe cube

! ---- resample filters -------------------------------------------------------
Img:Fast        EQUATE(0)                    ! nearest neighbour - keeps hard pixel edges
Img:Smooth      EQUATE(1)                    ! bilinear
Img:Best        EQUATE(2)                    ! area average shrinking, bilinear enlarging

! ---- fit modes --------------------------------------------------------------
Img:Stretch     EQUATE(0)                    ! fill the box, ignore the aspect ratio
Img:Proportional EQUATE(1)                   ! fit inside, keep the ratio, pad to the box
Img:Cover       EQUATE(2)                    ! fill the box, keep the ratio, crop the excess
Img:Centered    EQUATE(3)                    ! no scaling, centre in the box
Img:Contain     EQUATE(4)                    ! fit inside, keep the ratio, no padding

! ---- greyscale weighting ----------------------------------------------------
Img:Luma        EQUATE(0)                    ! BT.601 - matches how the eye weights channels
Img:Average     EQUATE(1)
Img:Lightness   EQUATE(2)
Img:Luma709     EQUATE(3)

! ---- canvas anchors (1..9, reading order) ----------------------------------
Img:TopLeft     EQUATE(1)
Img:Top         EQUATE(2)
Img:TopRight    EQUATE(3)
Img:Left        EQUATE(4)
Img:Center      EQUATE(5)
Img:Right       EQUATE(6)
Img:BottomLeft  EQUATE(7)
Img:Bottom      EQUATE(8)
Img:BottomRight EQUATE(9)

Img:Pi          EQUATE(3.14159265358979)

ImageClass CLASS,TYPE,MODULE('ImageClass.CLW'),LINK('ImageClass.CLW')
H                  LONG                      ! engine handle, 0 = nothing loaded
Path               CSTRING(261)              ! what LoadFile last opened
Err                LONG                      ! engine error from the last failure
Quality            LONG                      ! JPEG quality for SaveFile (default 85)
BmpBits            LONG                      ! forced BMP depth, 0 = pick from the colour format
TempA              CSTRING(261)              ! Draw ping-pongs two temp files so the
TempB              CSTRING(261)              !   IMAGE control actually reloads
Flip2              BYTE

! ---- open, make, close -----------------------------------------------------
Construct          PROCEDURE
Destruct           PROCEDURE
LoadFile           PROCEDURE(STRING pPath),BYTE,PROC
LoadFrame          PROCEDURE(LONG pFrame),BYTE,PROC     ! animated GIF / multi-page TIFF
MakeImage          PROCEDURE(LONG pW,LONG pH,ULONG pArgb=0FFFFFFFFh),BYTE,PROC
TestCard           PROCEDURE(LONG pW=640,LONG pH=480),BYTE,PROC
TakeOver           PROCEDURE(LONG pHandle)              ! adopt a raw engine handle
Kill               PROCEDURE                            ! release the image
! ---- what have we got ------------------------------------------------------
Ok                 PROCEDURE(),BYTE
Wide               PROCEDURE(),LONG
High               PROCEDURE(),LONG
SrcFormat          PROCEDURE(),LONG
SrcDepth           PROCEDURE(),LONG
ColorMode          PROCEDURE(),LONG
Colors             PROCEDURE(),LONG
Frames             PROCEDURE(),LONG
Pixel              PROCEDURE(LONG pX,LONG pY),ULONG
SetPixel           PROCEDURE(LONG pX,LONG pY,ULONG pArgb),BYTE,PROC
PaletteEntry       PROCEDURE(LONG pIndex),ULONG
LastError          PROCEDURE(),LONG
FormatName         PROCEDURE(LONG pFmt=-1),STRING
ColorModeName      PROCEDURE(LONG pMode=-1),STRING
Extensions         PROCEDURE(LONG pFmt),STRING          ! '*.jpg;*.jpeg' - for FILEDIALOG
CanWrite           PROCEDURE(LONG pFmt),BYTE
FormatOfFile       PROCEDURE(STRING pPath),LONG         ! sniff the signature, do not decode
FormatFromExt      PROCEDURE(STRING pPath),LONG
Describe           PROCEDURE(),STRING                   ! one line for a status bar
! ---- save ------------------------------------------------------------------
SaveFile           PROCEDURE(STRING pPath,LONG pFmt=0),BYTE,PROC
SaveTemp           PROCEDURE(),STRING                   ! PNG in %TEMP%, returns the path
! ---- geometry --------------------------------------------------------------
RotateRight        PROCEDURE(),BYTE,PROC
RotateLeft         PROCEDURE(),BYTE,PROC
Rotate180          PROCEDURE(),BYTE,PROC
Rotate             PROCEDURE(REAL pDegrees,ULONG pBack=0,BYTE pGrow=1,BYTE pSmooth=1),BYTE,PROC
Mirror             PROCEDURE(),BYTE,PROC                ! left <-> right
FlipVert           PROCEDURE(),BYTE,PROC                ! top <-> bottom
Resize             PROCEDURE(LONG pW,LONG pH,LONG pFilter=2),BYTE,PROC
Zoom               PROCEDURE(REAL pPercent,LONG pFilter=2),BYTE,PROC
Fit                PROCEDURE(LONG pW,LONG pH,LONG pMode=1,ULONG pBack=0),BYTE,PROC
Thumbnail          PROCEDURE(LONG pBox),BYTE,PROC
Crop               PROCEDURE(LONG pX,LONG pY,LONG pW,LONG pH),BYTE,PROC
CanvasSize         PROCEDURE(LONG pW,LONG pH,LONG pAnchor=5,ULONG pBack=0),BYTE,PROC
! ---- colour ----------------------------------------------------------------
Convert            PROCEDURE(LONG pMode,BYTE pDither=0,LONG pThreshold=128),BYTE,PROC
Greyscale          PROCEDURE(LONG pMode=0),BYTE,PROC
BlackWhite         PROCEDURE(LONG pThreshold=128,BYTE pDither=1),BYTE,PROC
Invert             PROCEDURE(),BYTE,PROC
Sepia              PROCEDURE(),BYTE,PROC
Adjust             PROCEDURE(LONG pBright,LONG pContrast,LONG pSaturation),BYTE,PROC
Gamma              PROCEDURE(REAL pGamma),BYTE,PROC
Levels             PROCEDURE(LONG pInLow,LONG pInHigh,LONG pOutLow=0,LONG pOutHigh=255),BYTE,PROC
ApplyLut           PROCEDURE(STRING pLut,LONG pChannels=7),BYTE,PROC
Posterize          PROCEDURE(LONG pLevels),BYTE,PROC
Blur               PROCEDURE(LONG pRadius=2,LONG pPasses=1),BYTE,PROC
Sharpen            PROCEDURE(LONG pAmount=80),BYTE,PROC
Flatten            PROCEDURE(ULONG pBack=0FFFFFFFFh),BYTE,PROC
Opacity            PROCEDURE(LONG pPercent),BYTE,PROC
Histogram          PROCEDURE(),LONG,PROC              ! builds it; returns the tallest bin
HistogramBin       PROCEDURE(LONG pIndex),ULONG          ! read bin 0..255 after Histogram()
! ---- combine and show ------------------------------------------------------
CloneInto          PROCEDURE(ImageClass pDest),BYTE,PROC   ! copy this image into another object
DrawOnto           PROCEDURE(ImageClass pSrc,LONG pX,LONG pY,LONG pW=0,LONG pH=0,LONG pAlpha=100),BYTE,PROC
Draw               PROCEDURE(WINDOW pWin,SIGNED pFeq,LONG pMode=1,ULONG pBack=0FFFFFFFFh),BYTE,PROC
! ---- internal --------------------------------------------------------------
ArgbOf             PROCEDURE(LONG pClarionColor,LONG pAlpha=255),ULONG  ! BGR -> 0xAARRGGBB
                   END
