! ============================================================================
!  graficaBarra - the combo: bars and a line on the one chart.
!
!  A series can be told its own shape, whatever ChartType says, and the line
!  is drawn OVER the bars off the same value axis - sales as columns, the
!  trend as a line. The line series takes no room in the category slot, so
!  the top chart draws full-width bars even though it has two series.
!
!  Build:  msbuild ComboChart.cwproj -t:Build -p:Configuration=Debug
!                  -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin"
! ============================================================================
  PROGRAM

  INCLUDE('GraficaBarraClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE

  MAP
  END

G          GraficaBarraClass
M          LONG
Wnd      WINDOW('graficaBarra - bars and a line on one chart'),AT(,,880,412),SYSTEM,GRAY,CENTER, |
             FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),ICON(ICON:Application)
           IMAGE,AT(8,8,864,200),USE(?G1)
           IMAGE,AT(8,212,428,192),USE(?G2)
           IMAGE,AT(444,212,428,192),USE(?G3)
         END
  CODE
  OPEN(Wnd)
  DO Wide
  DO Grouped
  DO Trend
  ACCEPT
  END
  CLOSE(Wnd)
  RETURN

!----------------------------------------------------------------------------
Common ROUTINE
  G.ClearAll()
  G.ChartType = Chart:Column
  G.BackColor = 0FFFFFFh
  G.ShowValues = 0
  G.ShowLegend = 1
  G.LegendPos = Legend:Bottom
  G.ShowMarkers = 1
  G.LineWidth = 2

!----------------------------------------------------------------------------
Wide ROUTINE
  DO Common
  G.Title = 'Ventas 2026 y su tendencia'
  G.AddSeries('Ventas')
  G.AddSeries('Tendencia')
  G.SetSeriesPlot(2, Plot:Line)
  G.AddCat('Ene',  84500000,  85000000)
  G.AddCat('Feb',  78200000,  84900000)
  G.AddCat('Mar',  86100000,  85600000)
  G.AddCat('Abr',  75900000,  85100000)
  G.AddCat('May', 113300000,  88900000)
  G.AddCat('Jun',  88700000,  89400000)
  G.AddCat('Jul',  87200000,  89600000)
  G.AddCat('Ago',  93100000,  90600000)
  G.AddCat('Sep',  84800000,  90200000)
  G.AddCat('Oct', 111900000,  93100000)
  G.AddCat('Nov',  87300000,  93000000)
  G.AddCat('Dic',  95400000,  93700000)
  G.Draw(Wnd, ?G1)

!----------------------------------------------------------------------------
Grouped ROUTINE
  DO Common
  G.Title = 'Dos series de barras y una linea'
  G.AddSeries('Norte')
  G.AddSeries('Sur')
  G.AddSeries('Tendencia')
  G.SetSeriesPlot(3, Plot:Line)
  G.AddCat('Q1', 120,  90, 105)
  G.AddCat('Q2',  95, 100,  99)
  G.AddCat('Q3', 140,  80, 112)
  G.AddCat('Q4', 110, 125, 119)
  G.Draw(Wnd, ?G2)

!----------------------------------------------------------------------------
Trend ROUTINE
  DO Common
  G.Title = 'Resultado mensual, con negativos'
  G.LegendPos = Legend:Bottom
  G.Smooth = 1
  G.AddSeries('Resultado')
  G.AddSeries('Tendencia')
  G.SetSeriesPlot(2, Plot:Line)
  G.AddCat('Ene',  60,  40)
  G.AddCat('Feb', -30,  22)
  G.AddCat('Mar',  20,  18)
  G.AddCat('Abr', -50,  -4)
  G.AddCat('May',  70,  16)
  G.AddCat('Jun',  45,  24)
  G.Draw(Wnd, ?G3)
