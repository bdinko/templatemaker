! ============================================================================
!  ImageClass - implementation. A thin, safe Clarion skin over imgcore.c.
!
!  The split of labour is deliberate: anything that touches a pixel lives in C
!  (it is called once per pixel, so it has to be quick), and anything that
!  needs judgement, formatting or maths the C side cannot reach - COS/SIN for
!  free rotation, the gamma and levels lookup tables - is worked out here and
!  handed over. That is why imgcore.c needs no C runtime and no libm.
!
!  This file MUST be stored in ANSI (not UTF-8), CRLF line ends.
! ============================================================================
  MEMBER

  INCLUDE('ImageClass.INC'),ONCE              ! must precede the PRAGMA
  INCLUDE('EQUATES.CLW'),ONCE

  PRAGMA('compile(imgcore.c)')                ! Clarion's own C compiler builds the engine

  MAP                                         ! cdecl C symbols get a leading underscore
    MODULE('imgcore.c')
ic_load        PROCEDURE(*CSTRING),LONG,RAW,NAME('_img_load')
ic_create      PROCEDURE(LONG,LONG,ULONG),LONG,NAME('_img_create')
ic_testcard    PROCEDURE(LONG,LONG),LONG,NAME('_img_testcard')
ic_clone       PROCEDURE(LONG),LONG,NAME('_img_clone')
ic_free        PROCEDURE(LONG),LONG,PROC,NAME('_img_free')
ic_freeall     PROCEDURE(),LONG,NAME('_img_free_all')
ic_save        PROCEDURE(LONG,*CSTRING,LONG,LONG,LONG),LONG,RAW,NAME('_img_save')
ic_detect      PROCEDURE(*CSTRING),LONG,RAW,NAME('_img_detect')
ic_width       PROCEDURE(LONG),LONG,NAME('_img_width')
ic_height      PROCEDURE(LONG),LONG,NAME('_img_height')
ic_srcfmt      PROCEDURE(LONG),LONG,NAME('_img_src_format')
ic_srcdepth    PROCEDURE(LONG),LONG,NAME('_img_src_depth')
ic_mode        PROCEDURE(LONG),LONG,NAME('_img_mode')
ic_colors      PROCEDURE(LONG),LONG,NAME('_img_colors')
ic_frames      PROCEDURE(LONG),LONG,NAME('_img_frames')
ic_selframe    PROCEDURE(LONG,LONG),LONG,NAME('_img_select_frame')
ic_getpixel    PROCEDURE(LONG,LONG,LONG),ULONG,NAME('_img_get_pixel')
ic_setpixel    PROCEDURE(LONG,LONG,LONG,ULONG),LONG,NAME('_img_set_pixel')
ic_pal         PROCEDURE(LONG,LONG),ULONG,NAME('_img_palette')
ic_lasterr     PROCEDURE(),LONG,NAME('_img_last_error')
ic_tempdir     PROCEDURE(*CSTRING,LONG),LONG,RAW,PROC,NAME('_img_temp_dir')
ic_rot90       PROCEDURE(LONG,LONG),LONG,NAME('_img_rotate90')
ic_flip        PROCEDURE(LONG,LONG),LONG,NAME('_img_flip')
ic_rotfree     PROCEDURE(LONG,REAL,REAL,ULONG,LONG,LONG),LONG,NAME('_img_rotate_free')
ic_resize      PROCEDURE(LONG,LONG,LONG,LONG),LONG,NAME('_img_resize')
ic_crop        PROCEDURE(LONG,LONG,LONG,LONG,LONG),LONG,NAME('_img_crop')
ic_canvas      PROCEDURE(LONG,LONG,LONG,LONG,ULONG),LONG,NAME('_img_canvas')
ic_fit         PROCEDURE(LONG,LONG,LONG,LONG,ULONG),LONG,NAME('_img_fit')
ic_convert     PROCEDURE(LONG,LONG,LONG,LONG),LONG,NAME('_img_convert')
ic_grey        PROCEDURE(LONG,LONG),LONG,NAME('_img_greyscale')
ic_invert      PROCEDURE(LONG),LONG,NAME('_img_invert')
ic_sepia       PROCEDURE(LONG),LONG,NAME('_img_sepia')
ic_adjust      PROCEDURE(LONG,LONG,LONG,LONG),LONG,NAME('_img_adjust')
ic_lut         PROCEDURE(LONG,*STRING,LONG),LONG,RAW,NAME('_img_lut')
ic_posterize   PROCEDURE(LONG,LONG),LONG,NAME('_img_posterize')
ic_blur        PROCEDURE(LONG,LONG,LONG),LONG,NAME('_img_blur')
ic_sharpen     PROCEDURE(LONG,LONG),LONG,NAME('_img_sharpen')
ic_flatten     PROCEDURE(LONG,ULONG),LONG,NAME('_img_flatten')
ic_opacity     PROCEDURE(LONG,LONG),LONG,NAME('_img_opacity')
ic_histcalc    PROCEDURE(LONG),LONG,NAME('_img_hist_calc')
ic_histbin     PROCEDURE(LONG),ULONG,NAME('_img_hist_bin')
ic_draw        PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG),LONG,NAME('_img_draw')
    END
  END

!=== lifecycle ===============================================================
ImageClass.Construct PROCEDURE()
  CODE
  SELF.H = 0
  SELF.Quality = 85
  SELF.BmpBits = 0
  SELF.Path = ''

ImageClass.Destruct PROCEDURE()
  CODE
  SELF.Kill()

ImageClass.Kill PROCEDURE()
  CODE
  IF SELF.H
    ic_free(SELF.H)
    SELF.H = 0
  END
  SELF.Path = ''

ImageClass.TakeOver PROCEDURE(LONG pHandle)
  CODE
  IF SELF.H AND SELF.H <> pHandle THEN ic_free(SELF.H).
  SELF.H = pHandle

ImageClass.LoadFile PROCEDURE(STRING pPath)
p  CSTRING(261)
n  LONG
  CODE
  p = CLIP(pPath)
  n = ic_load(p)
  SELF.Err = ic_lasterr()
  IF NOT n THEN RETURN 0.
  SELF.TakeOver(n)
  SELF.Path = p
  RETURN 1

ImageClass.LoadFrame PROCEDURE(LONG pFrame)
  CODE
  IF NOT SELF.H THEN RETURN 0.
  IF NOT ic_selframe(SELF.H, pFrame) THEN SELF.Err = ic_lasterr(); RETURN 0.
  RETURN 1

ImageClass.MakeImage PROCEDURE(LONG pW,LONG pH,ULONG pArgb=0FFFFFFFFh)
n  LONG
  CODE
  n = ic_create(pW, pH, pArgb)
  SELF.Err = ic_lasterr()
  IF NOT n THEN RETURN 0.
  SELF.TakeOver(n)
  SELF.Path = ''
  RETURN 1

ImageClass.TestCard PROCEDURE(LONG pW=640,LONG pH=480)
n  LONG
  CODE
  n = ic_testcard(pW, pH)
  SELF.Err = ic_lasterr()
  IF NOT n THEN RETURN 0.
  SELF.TakeOver(n)
  SELF.Path = ''
  RETURN 1

!=== what have we got ========================================================
ImageClass.Ok PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, 1, 0)

ImageClass.Wide PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_width(SELF.H), 0)

ImageClass.High PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_height(SELF.H), 0)

ImageClass.SrcFormat PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_srcfmt(SELF.H), 0)

ImageClass.SrcDepth PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_srcdepth(SELF.H), 0)

ImageClass.ColorMode PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_mode(SELF.H), 0)

ImageClass.Colors PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_colors(SELF.H), 0)

ImageClass.Frames PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_frames(SELF.H), 0)

ImageClass.Pixel PROCEDURE(LONG pX,LONG pY)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_getpixel(SELF.H, pX, pY), 0)

ImageClass.SetPixel PROCEDURE(LONG pX,LONG pY,ULONG pArgb)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_setpixel(SELF.H, pX, pY, pArgb), 0)

ImageClass.PaletteEntry PROCEDURE(LONG pIndex)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_pal(SELF.H, pIndex), 0)

ImageClass.LastError PROCEDURE()
  CODE
  RETURN SELF.Err

ImageClass.FormatOfFile PROCEDURE(STRING pPath)
p  CSTRING(261)
  CODE
  p = CLIP(pPath)
  RETURN ic_detect(p)

ImageClass.FormatName PROCEDURE(LONG pFmt=-1)
f  LONG
  CODE
  f = pFmt
  IF f < 0 THEN f = SELF.SrcFormat().
  CASE f
  OF Img:Bmp  ; RETURN 'BMP'
  OF Img:Gif  ; RETURN 'GIF'
  OF Img:Jpeg ; RETURN 'JPEG'
  OF Img:Png  ; RETURN 'PNG'
  OF Img:Tiff ; RETURN 'TIFF'
  OF Img:Ico  ; RETURN 'Icon'
  OF Img:Emf  ; RETURN 'EMF'
  OF Img:Wmf  ; RETURN 'WMF'
  OF Img:Tga  ; RETURN 'Targa'
  OF Img:Pcx  ; RETURN 'PCX'
  OF Img:Pnm  ; RETURN 'PNM'
  OF Img:Qoi  ; RETURN 'QOI'
  END
  RETURN 'n/a'

ImageClass.ColorModeName PROCEDURE(LONG pMode=-1)
m  LONG
  CODE
  m = pMode
  IF m < 0 THEN m = SELF.ColorMode().
  CASE m
  OF Img:True32  ; RETURN '32-bit true colour + alpha'
  OF Img:True24  ; RETURN '24-bit true colour'
  OF Img:High16  ; RETURN '16-bit high colour (5-6-5)'
  OF Img:High15  ; RETURN '15-bit high colour (5-5-5)'
  OF Img:Pal256  ; RETURN '256 colours'
  OF Img:Pal16   ; RETURN '16 colours'
  OF Img:Grey256 ; RETURN '256 greys'
  OF Img:Grey16  ; RETURN '16 greys'
  OF Img:Grey4   ; RETURN '4 greys'
  OF Img:Mono    ; RETURN 'black & white'
  OF Img:Web216  ; RETURN 'web-safe 216'
  END
  RETURN 'n/a'

ImageClass.Extensions PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Img:Bmp  ; RETURN '*.bmp;*.dib;*.rle'
  OF Img:Gif  ; RETURN '*.gif'
  OF Img:Jpeg ; RETURN '*.jpg;*.jpeg;*.jpe;*.jfif'
  OF Img:Png  ; RETURN '*.png'
  OF Img:Tiff ; RETURN '*.tif;*.tiff'
  OF Img:Ico  ; RETURN '*.ico;*.cur'
  OF Img:Emf  ; RETURN '*.emf'
  OF Img:Wmf  ; RETURN '*.wmf'
  OF Img:Tga  ; RETURN '*.tga;*.targa;*.icb;*.vda;*.vst'
  OF Img:Pcx  ; RETURN '*.pcx'
  OF Img:Pnm  ; RETURN '*.pnm;*.ppm;*.pgm;*.pbm'
  OF Img:Qoi  ; RETURN '*.qoi'
  END
  RETURN ''

ImageClass.CanWrite PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Img:Bmp OROF Img:Gif OROF Img:Jpeg OROF Img:Png OROF Img:Tiff
  OROF Img:Tga OROF Img:Pcx OROF Img:Pnm OROF Img:Qoi
    RETURN 1
  END
  RETURN 0

ImageClass.FormatFromExt PROCEDURE(STRING pPath)
s   STRING(261)
e   STRING(8)
i   LONG
d   LONG
  CODE
  s = CLIP(pPath)
  d = 0
  LOOP i = LEN(CLIP(s)) TO 1 BY -1
    IF s[i] = '.' THEN d = i; BREAK.
    IF s[i] = '\' OR s[i] = '/' THEN BREAK.
  END
  IF NOT d THEN RETURN Img:Unknown.
  e = UPPER(SUB(s, d + 1, 8))
  CASE CLIP(e)
  OF 'BMP' OROF 'DIB' OROF 'RLE'                     ; RETURN Img:Bmp
  OF 'GIF'                                           ; RETURN Img:Gif
  OF 'JPG' OROF 'JPEG' OROF 'JPE' OROF 'JFIF'        ; RETURN Img:Jpeg
  OF 'PNG'                                           ; RETURN Img:Png
  OF 'TIF' OROF 'TIFF'                               ; RETURN Img:Tiff
  OF 'ICO' OROF 'CUR'                                ; RETURN Img:Ico
  OF 'EMF'                                           ; RETURN Img:Emf
  OF 'WMF'                                           ; RETURN Img:Wmf
  OF 'TGA' OROF 'TARGA' OROF 'ICB' OROF 'VDA' OROF 'VST' ; RETURN Img:Tga
  OF 'PCX'                                           ; RETURN Img:Pcx
  OF 'PNM' OROF 'PPM' OROF 'PGM' OROF 'PBM'          ; RETURN Img:Pnm
  OF 'QOI'                                           ; RETURN Img:Qoi
  END
  RETURN Img:Unknown

ImageClass.Describe PROCEDURE()
s  STRING(200)
  CODE
  IF NOT SELF.H THEN RETURN 'no image'.
  IF SELF.SrcFormat() = Img:Unknown AND NOT SELF.Path
    s = 'made in memory  ' & SELF.Wide() & ' x ' & SELF.High() & |
        '  now ' & CLIP(SELF.ColorModeName())
  ELSE
    s = CLIP(SELF.FormatName()) & '  ' & SELF.Wide() & ' x ' & SELF.High() &  |
        '  source ' & SELF.SrcDepth() & '-bit  now ' & CLIP(SELF.ColorModeName())
  END
  IF SELF.Colors() > 0
    s = CLIP(s) & ' (' & SELF.Colors() & ' entries)'
  END
  IF SELF.Frames() > 1
    s = CLIP(s) & '  ' & SELF.Frames() & ' frames'
  END
  RETURN CLIP(s)

!=== save ====================================================================
ImageClass.SaveFile PROCEDURE(STRING pPath,LONG pFmt=0)
p  CSTRING(261)
f  LONG
q  LONG
  CODE
  IF NOT SELF.H THEN RETURN 0.
  p = CLIP(pPath)
  f = pFmt
  IF NOT f THEN f = SELF.FormatFromExt(p).
  IF NOT SELF.CanWrite(f) THEN SELF.Err = 51; RETURN 0.
  q = SELF.Quality
  IF f = Img:Tga THEN q = CHOOSE(SELF.Quality = 0, 0, 1).      ! TGA: 0 = raw, else RLE
  IF NOT ic_save(SELF.H, p, f, q, SELF.BmpBits)
    SELF.Err = ic_lasterr()
    RETURN 0
  END
  RETURN 1

ImageClass.SaveTemp PROCEDURE()
dir   CSTRING(261)
path  CSTRING(261)
  CODE
  IF NOT SELF.H THEN RETURN ''.
  dir = ''
  ic_tempdir(dir, SIZE(dir))
  path = CLIP(dir) & 'myimage_tmp.png'
  IF NOT SELF.SaveFile(path, Img:Png) THEN RETURN ''.
  RETURN CLIP(path)

!=== geometry ================================================================
ImageClass.RotateRight PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_rot90(SELF.H, 1), 0)

ImageClass.RotateLeft PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_rot90(SELF.H, 3), 0)

ImageClass.Rotate180 PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_rot90(SELF.H, 2), 0)

ImageClass.Mirror PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_flip(SELF.H, 1), 0)

ImageClass.FlipVert PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_flip(SELF.H, 2), 0)

!  Free rotation. The C side has no libm, so the trigonometry is done here and
!  the cosine and sine are handed over.
ImageClass.Rotate PROCEDURE(REAL pDegrees,ULONG pBack=0,BYTE pGrow=1,BYTE pSmooth=1)
r   REAL
d   REAL
  CODE
  IF NOT SELF.H THEN RETURN 0.
  d = pDegrees - INT(pDegrees / 360) * 360
  IF d < 0 THEN d += 360.
  IF d = 0 THEN RETURN 1.
  IF pGrow = 1 AND pBack = 0
    IF d = 90  THEN RETURN SELF.RotateRight().
    IF d = 180 THEN RETURN SELF.Rotate180().
    IF d = 270 THEN RETURN SELF.RotateLeft().
  END
  r = d * Img:Pi / 180
  IF NOT ic_rotfree(SELF.H, COS(r), SIN(r), pBack, pGrow, pSmooth)
    SELF.Err = ic_lasterr()
    RETURN 0
  END
  RETURN 1

ImageClass.Resize PROCEDURE(LONG pW,LONG pH,LONG pFilter=2)
  CODE
  IF NOT SELF.H THEN RETURN 0.
  IF NOT ic_resize(SELF.H, pW, pH, pFilter) THEN SELF.Err = ic_lasterr(); RETURN 0.
  RETURN 1

ImageClass.Zoom PROCEDURE(REAL pPercent,LONG pFilter=2)
w  LONG
h  LONG
  CODE
  IF NOT SELF.H OR pPercent <= 0 THEN RETURN 0.
  w = INT(SELF.Wide() * pPercent / 100 + 0.5)
  h = INT(SELF.High() * pPercent / 100 + 0.5)
  IF w < 1 THEN w = 1.
  IF h < 1 THEN h = 1.
  RETURN SELF.Resize(w, h, pFilter)

ImageClass.Fit PROCEDURE(LONG pW,LONG pH,LONG pMode=1,ULONG pBack=0)
  CODE
  IF NOT SELF.H THEN RETURN 0.
  IF NOT ic_fit(SELF.H, pW, pH, pMode, pBack) THEN SELF.Err = ic_lasterr(); RETURN 0.
  RETURN 1

ImageClass.Thumbnail PROCEDURE(LONG pBox)
  CODE
  RETURN SELF.Fit(pBox, pBox, Img:Contain, 0)

ImageClass.Crop PROCEDURE(LONG pX,LONG pY,LONG pW,LONG pH)
  CODE
  IF NOT SELF.H THEN RETURN 0.
  IF NOT ic_crop(SELF.H, pX, pY, pW, pH) THEN SELF.Err = ic_lasterr(); RETURN 0.
  RETURN 1

ImageClass.CanvasSize PROCEDURE(LONG pW,LONG pH,LONG pAnchor=5,ULONG pBack=0)
  CODE
  IF NOT SELF.H THEN RETURN 0.
  IF NOT ic_canvas(SELF.H, pW, pH, pAnchor, pBack) THEN SELF.Err = ic_lasterr(); RETURN 0.
  RETURN 1

!=== colour ==================================================================
ImageClass.Convert PROCEDURE(LONG pMode,BYTE pDither=0,LONG pThreshold=128)
  CODE
  IF NOT SELF.H THEN RETURN 0.
  IF NOT ic_convert(SELF.H, pMode, pDither, pThreshold) THEN SELF.Err = ic_lasterr(); RETURN 0.
  RETURN 1

ImageClass.Greyscale PROCEDURE(LONG pMode=0)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_grey(SELF.H, pMode), 0)

ImageClass.BlackWhite PROCEDURE(LONG pThreshold=128,BYTE pDither=1)
  CODE
  RETURN SELF.Convert(Img:Mono, pDither, pThreshold)

ImageClass.Invert PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_invert(SELF.H), 0)

ImageClass.Sepia PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_sepia(SELF.H), 0)

ImageClass.Adjust PROCEDURE(LONG pBright,LONG pContrast,LONG pSaturation)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_adjust(SELF.H, pBright, pContrast, pSaturation), 0)

!  Gamma and Levels both build a 256-entry lookup table here and let the C side
!  blast it over the pixels - that keeps pow() out of the engine entirely.
ImageClass.Gamma PROCEDURE(REAL pGamma)
lut  STRING(256)
i    LONG
v    REAL
g    REAL
  CODE
  IF NOT SELF.H THEN RETURN 0.
  g = pGamma
  IF g <= 0 THEN RETURN 0.
  LOOP i = 0 TO 255
    v = 255 * ((i / 255) ^ (1 / g))
    IF v < 0 THEN v = 0.
    IF v > 255 THEN v = 255.
    lut[i + 1] = CHR(INT(v + 0.5))
  END
  RETURN SELF.ApplyLut(lut, 7)

ImageClass.Levels PROCEDURE(LONG pInLow,LONG pInHigh,LONG pOutLow=0,LONG pOutHigh=255)
lut  STRING(256)
i    LONG
v    REAL
lo   LONG
hi   LONG
  CODE
  IF NOT SELF.H THEN RETURN 0.
  lo = pInLow; hi = pInHigh
  IF hi <= lo THEN hi = lo + 1.
  LOOP i = 0 TO 255
    v = (i - lo) / (hi - lo)
    IF v < 0 THEN v = 0.
    IF v > 1 THEN v = 1.
    v = pOutLow + v * (pOutHigh - pOutLow)
    IF v < 0 THEN v = 0.
    IF v > 255 THEN v = 255.
    lut[i + 1] = CHR(INT(v + 0.5))
  END
  RETURN SELF.ApplyLut(lut, 7)

ImageClass.ApplyLut PROCEDURE(STRING pLut,LONG pChannels=7)
lut  STRING(256)
  CODE
  IF NOT SELF.H THEN RETURN 0.
  lut = pLut
  RETURN ic_lut(SELF.H, lut, pChannels)

ImageClass.Posterize PROCEDURE(LONG pLevels)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_posterize(SELF.H, pLevels), 0)

ImageClass.Blur PROCEDURE(LONG pRadius=2,LONG pPasses=1)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_blur(SELF.H, pRadius, pPasses), 0)

ImageClass.Sharpen PROCEDURE(LONG pAmount=80)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_sharpen(SELF.H, pAmount), 0)

ImageClass.Flatten PROCEDURE(ULONG pBack=0FFFFFFFFh)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_flatten(SELF.H, pBack), 0)

ImageClass.Opacity PROCEDURE(LONG pPercent)
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_opacity(SELF.H, pPercent), 0)

ImageClass.Histogram PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H > 0, ic_histcalc(SELF.H), 0)

ImageClass.HistogramBin PROCEDURE(LONG pIndex)
  CODE
  RETURN ic_histbin(pIndex)

!=== combine and show ========================================================
ImageClass.CloneInto PROCEDURE(ImageClass pDest)
n  LONG
  CODE
  IF NOT SELF.H THEN RETURN 0.
  n = ic_clone(SELF.H)
  IF NOT n THEN SELF.Err = ic_lasterr(); RETURN 0.
  pDest.TakeOver(n)
  RETURN 1

ImageClass.DrawOnto PROCEDURE(ImageClass pSrc,LONG pX,LONG pY,LONG pW=0,LONG pH=0,LONG pAlpha=100)
  CODE
  IF NOT SELF.H OR NOT pSrc.H THEN RETURN 0.
  RETURN ic_draw(SELF.H, pSrc.H, pX, pY, pW, pH, Img:Best, pAlpha)

!  Show the image in an IMAGE control. A COPY is fitted to the control's pixel
!  size and written to a temp PNG - the original is never touched. Two temp
!  names are used in turn, because Clarion will not reload a file whose name
!  has not changed.
ImageClass.Draw PROCEDURE(WINDOW pWin,SIGNED pFeq,LONG pMode=1,ULONG pBack=0FFFFFFFFh)
w      LONG
h      LONG
savePx LONG
dir    CSTRING(261)
path   CSTRING(261)
copy   LONG
tmp    ImageClass
  CODE
  IF NOT SELF.H THEN RETURN 0.
  SETTARGET(pWin)
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = pFeq{PROP:Width}
  h = pFeq{PROP:Height}
  0{PROP:Pixels} = savePx
  SETTARGET()
  IF w < 4 OR h < 4 THEN RETURN 0.
  IF NOT SELF.TempA
    dir = ''
    ic_tempdir(dir, SIZE(dir))
    SELF.TempA = CLIP(dir) & 'myimage_' & pFeq & '_a.png'
    SELF.TempB = CLIP(dir) & 'myimage_' & pFeq & '_b.png'
  END
  copy = ic_clone(SELF.H)
  IF NOT copy THEN SELF.Err = ic_lasterr(); RETURN 0.
  tmp.TakeOver(copy)
  IF pMode >= 0 THEN tmp.Fit(w, h, pMode, pBack).
  SELF.Flip2 = 1 - SELF.Flip2
  IF SELF.Flip2 THEN path = SELF.TempA ELSE path = SELF.TempB.
  IF NOT tmp.SaveFile(path, Img:Png)
    SELF.Err = tmp.Err
    tmp.Kill()
    RETURN 0
  END
  tmp.Kill()
  pFeq{PROP:Text} = path
  DISPLAY(pFeq)
  RETURN 1

!=== helpers =================================================================
!  Clarion colours are BGR longs; the engine wants 0xAARRGGBB.
ImageClass.ArgbOf PROCEDURE(LONG pClarionColor,LONG pAlpha=255)
c  LONG
r  LONG
g  LONG
b  LONG
  CODE
  c = pClarionColor
  IF c < 0 THEN c = 0FFFFFFh.
  b = BSHIFT(BAND(c, 0FF0000h), -16)
  g = BSHIFT(BAND(c, 000FF00h), -8)
  r = BAND(c, 00000FFh)
  RETURN BOR(BOR(BSHIFT(BAND(pAlpha,0FFh),24), BSHIFT(r,16)), BOR(BSHIFT(g,8), b))
