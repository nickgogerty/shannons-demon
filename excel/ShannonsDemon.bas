Attribute VB_Name = "ShannonsDemon"
Option Explicit

' Shannon's demon (constant-rebalanced portfolio) for the workbook shannons_demon.xlsx.
'
' Reads inputs from the Inputs sheet (B4 wealth, B7 rebalance interval, B8 cost, B10 horizon)
' and the selected stock price and cash price from the Prices sheet (columns F and G, rows 2-252).
' SweepWeights runs the demon for stock weights from 0% to 100% and writes the results to the
' Sweep sheet. Mirrors the Python reference in shannons_demon.py.

Private Const LAST_ROW As Long = 252
Private Const MAX_T As Long = 250

Private Function ReadColumn(ws As Worksheet, colLetter As String, firstRow As Long, lastRow As Long) As Double()
    Dim v As Variant
    Dim out() As Double
    Dim i As Long

    v = ws.Range(colLetter & firstRow & ":" & colLetter & lastRow).Value
    ReDim out(0 To lastRow - firstRow)
    For i = 1 To UBound(v, 1)
        out(i - 1) = CDbl(v(i, 1))
    Next i
    ReadColumn = out
End Function

' Final wealth after `horizon` periods. xsPrices and xcPrices are 0-based; index 0 is t = 0.
' turnover returns the sum of traded value as a multiple of wealth at each rebalance.
Public Function DemonFinalWealth(xsPrices() As Double, xcPrices() As Double, _
                                 ByVal wStock As Double, ByVal k As Long, _
                                 ByVal costRate As Double, ByVal w0 As Double, _
                                 ByVal horizon As Long, ByRef turnover As Double) As Double
    Dim t As Long
    Dim sS As Double, sC As Double, total As Double
    Dim traded As Double, costAmt As Double
    Dim xs As Double, xc As Double

    sS = w0 * wStock
    sC = w0 * (1# - wStock)
    turnover = 0#

    For t = 1 To horizon
        xs = xsPrices(t) / xsPrices(t - 1)
        xc = xcPrices(t) / xcPrices(t - 1)
        sS = sS * xs
        sC = sC * xc
        total = sS + sC

        If (t Mod k) = 0 Then
            traded = Abs(total * wStock - sS) + Abs(total * (1# - wStock) - sC)
            If total > 0# Then turnover = turnover + traded / total
            costAmt = traded * costRate
            total = total - costAmt
            sS = total * wStock
            sC = total * (1# - wStock)
        End If
    Next t

    DemonFinalWealth = sS + sC
End Function

Private Function GetOrAddSheet(sheetName As String) As Worksheet
    Dim ws As Worksheet

    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(sheetName)
    On Error GoTo 0

    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
        ws.Name = sheetName
    End If
    Set GetOrAddSheet = ws
End Function

Public Sub SweepWeights()
    Dim wsI As Worksheet, wsP As Worksheet, wsS As Worksheet
    Dim xs() As Double, xc() As Double
    Dim w0 As Double, costRate As Double
    Dim k As Long, horizon As Long
    Dim i As Long
    Dim wStock As Double, finalW As Double, turnover As Double
    Dim bestW As Double, bestF As Double

    Set wsI = ThisWorkbook.Worksheets("Inputs")
    Set wsP = ThisWorkbook.Worksheets("Prices")

    w0 = wsI.Range("B4").Value
    k = CLng(wsI.Range("B7").Value)
    costRate = wsI.Range("B8").Value
    horizon = CLng(wsI.Range("B10").Value)

    If k < 1 Then
        MsgBox "Inputs!B7 (rebalance interval) must be 1 or more.", vbExclamation, "Shannon's demon"
        Exit Sub
    End If
    If horizon < 1 Or horizon > MAX_T Then
        MsgBox "Inputs!B10 (horizon) must be between 1 and " & MAX_T & ".", vbExclamation, "Shannon's demon"
        Exit Sub
    End If

    xs = ReadColumn(wsP, "F", 2, LAST_ROW)
    xc = ReadColumn(wsP, "G", 2, LAST_ROW)

    Set wsS = GetOrAddSheet("Sweep")
    wsS.Cells.Clear
    wsS.Range("A1:D1").Value = Array("Stock weight", "Final wealth", "Growth per period", "Turnover (x wealth)")
    wsS.Range("A1:D1").Font.Bold = True

    bestF = -1#
    bestW = 0#
    For i = 0 To 100
        wStock = i / 100#
        finalW = DemonFinalWealth(xs, xc, wStock, k, costRate, w0, horizon, turnover)
        wsS.Cells(i + 2, 1).Value = wStock
        wsS.Cells(i + 2, 2).Value = finalW
        If finalW > 0# Then
            wsS.Cells(i + 2, 3).Value = (finalW / w0) ^ (1# / horizon) - 1#
        Else
            wsS.Cells(i + 2, 3).Value = "n/a"
        End If
        wsS.Cells(i + 2, 4).Value = turnover
        If finalW > bestF Then
            bestF = finalW
            bestW = wStock
        End If
    Next i

    wsS.Range("A2:A102").NumberFormat = "0%"
    wsS.Range("B2:B102").NumberFormat = "0.0000"
    wsS.Range("C2:C102").NumberFormat = "0.00%"
    wsS.Range("D2:D102").NumberFormat = "0.000"
    wsS.Columns("A:D").AutoFit

    MsgBox "Best stock weight in the sweep: " & Format(bestW, "0%") & vbCrLf & _
           "Final wealth at horizon " & horizon & ": " & Format(bestF, "0.0000") & vbCrLf & vbCrLf & _
           "Sheet 'Sweep' updated.", vbInformation, "Shannon's demon"
End Sub
