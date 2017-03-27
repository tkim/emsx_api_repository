VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "EMSXHistory"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
' Copyright 2017. Bloomberg Finance L.P.
'
' Permission is hereby granted, free of charge, to any person obtaining a copy
' of this software and associated documentation files (the "Software"), to
' deal in the Software without restriction, including without limitation the
' rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
' sell copies of the Software, and to permit persons to whom the Software is
' furnished to do so, subject to the following conditions:  The above
' copyright notice and this permission notice shall be included in all copies
' or substantial portions of the Software.
'
' THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
' IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
' FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
' AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
' LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
' FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
' IN THE SOFTWARE.

Option Explicit

Private WithEvents m_BBG_EMSX As blpapicomLib2.Session
Attribute m_BBG_EMSX.VB_VarHelpID = -1
Public running As Boolean
Private svc As blpapicomLib2.service
Private emsxHistoryService As String
Private requestID As blpapicomLib2.CorrelationId

Private Sub Class_Initialize()

    log "Bloomberg - EMSX API Example - EMSXHistory"

    emsxHistoryService = "//blp/emsx.history.uat"
    
    Set m_BBG_EMSX = New blpapicomLib2.Session
    
    running = True
    
    m_BBG_EMSX.QueueEvents = True
    m_BBG_EMSX.Start
    

End Sub

Private Sub Class_Terminate()
    Set m_BBG_EMSX = Nothing
End Sub

Private Sub m_BBG_EMSX_ProcessEvent(ByVal obj As Object)

    On Error GoTo errHandler

    Dim eventObj As blpapicomLib2.Event
    
     '   Assign the returned data to a Bloomberg type event
    Set eventObj = obj
    
    If Application.Ready Then
    
        Select Case eventObj.EventType
        
            Case SESSION_STATUS
                processSessionEvent eventObj
                
            Case BLPSERVICE_STATUS
                processServiceEvent eventObj
                
            Case RESPONSE
                processResponseEvent eventObj
                
        End Select
        
    End If

    Exit Sub

errHandler:
    Dim errmsg As Variant
    errmsg = Err.Description
    log (errmsg)
    running = False

End Sub


Private Sub processSessionEvent(evt As blpapicomLib2.Event)

    log "Processing SESSION_STATUS event"
    
    Dim it As blpapicomLib2.MessageIterator
    
    Set it = evt.CreateMessageIterator()

    ' Loop while we have messages remaining
    Do While it.Next()
              
        Dim msg As Message
        
        '   Pick up message
        Set msg = it.Message
        
        log "MessageType: " + msg.MessageTypeAsString
        
        If msg.MessageTypeAsString = "SessionStarted" Then
            log "Session started..."
            m_BBG_EMSX.OpenService emsxHistoryService
        ElseIf msg.MessageTypeAsString = "SessionStartupFailure" Then
            log "Error: Session startup failed"
            running = False
        End If
        
    Loop

End Sub

Private Sub processServiceEvent(evt As blpapicomLib2.Event)

    Dim req As REQUEST
    Dim service As service
    Dim scope As Element
    Dim filter As Element
    
    Dim it As blpapicomLib2.MessageIterator
    
    On Error GoTo failed
    
    log "Processing SERVICE_STATUS event"
    
    Set it = evt.CreateMessageIterator()

    ' Loop while we have messages remaining
    Do While it.Next()
              
        Dim msg As Message
        
        '   Pick up message
        Set msg = it.Message
        
        log "MessageType: " + msg.MessageTypeAsString
        
        If msg.MessageTypeAsString = "ServiceOpened" Then
    
            ' Get the service
            Set service = m_BBG_EMSX.GetService(emsxHistoryService)
    
            'First, create our request object
            Set req = service.CreateRequest("GetFills")
    
            req.Set "FromDateTime", "2017-02-08T00:00:00.000+00:00"
            req.Set "ToDateTime", "2017-02-11T23:59:00.000+00:00"

            Set scope = req.GetElement("Scope")
            
            'scope.SetChoice "Team"
            'scope.SetChoice "TradingSystem"
            scope.SetChoice "Uuids"
        
            'scope.SetElement "Team", "SEXEGROUP"
            'scope.SetElement "TradingSystem", False
        
            scope.GetElement("Uuids").AppendValue 6767714
            'scope.GetElement("Uuids").AppendValue 1234567
            'scope.GetElement("Uuids").AppendValue 1234568
            'scope.GetElement("Uuids").AppendValue 1234569
                    
            'Set filter = req.GetElement("FilterBy")
        
            'filter.SetChoice "Basket"
            'filter.SetChoice "Multileg"
            'filter.SetChoice "OrdersAndRoutes"
        
            'filter.GetElement("Basket").AppendValue "TESTRJC"
            'filter.GetElement("Multileg").AppendValue "mylegId"
            
            'Dim newOrder As Element
            
            'Set newOrder = filter.GetElement("OrdersAndRoutes").AppendElement()
            'newOrder.SetElement "OrderId", 4292580
            'newOrder.SetElement "RouteId", 1
           
            log "Request: " & req.Print
            
            ' Send the request
            Set requestID = m_BBG_EMSX.SendRequest(req)

        ElseIf msg.MessageTypeAsString = "ServiceOpenFailure" Then
        
            log "Error: Service failed to open"
            running = False
            
        End If
        
    Loop

    Exit Sub
    
failed:

    log "Failed to send the request: " + Err.Description
    
    running = False
    Exit Sub
    
End Sub

Private Sub processResponseEvent(evt As blpapicomLib2.Event)

    log "Processing RESPONSE event"
    
    Dim it As blpapicomLib2.MessageIterator
    Dim i As Integer
    Dim errorCode As Long
    Dim errorMessage As String
 
    Set it = evt.CreateMessageIterator()

    ' Loop while we have messages remaining
    Do While it.Next()
              
        Dim msg As Message
        
        '   Pick up message
        Set msg = it.Message
        
        log "MessageType: " + msg.MessageTypeAsString
        
        If evt.EventType = RESPONSE And msg.CorrelationId.Value = requestID.Value Then
        
            If msg.MessageTypeAsString = "ErrorInfo" Then
            
                errorCode = msg.GetElement("ERROR_CODE")
                errorMessage = msg.GetElement("ERROR_MESSAGE")
                
                log "ERROR CODE: " & errorCode & "    ERROR DESCRIPTION: " & errorMessage
            
                running = False
                
            ElseIf msg.MessageTypeAsString = "GetFillsResponse" Then
                
                Dim fills As Element
                Dim fill As Element
                Dim numFills As Integer
                Dim account As String
                Dim amount As Double
                Dim assetClass As String
                Dim basketId As Integer
                Dim bbgid As String
                Dim blockId As String
                Dim broker As String
                Dim clearingAccount As String
                Dim clearingFirm As String
                Dim contractExpDate As Date
                Dim correctedFillId As Integer
                Dim crncy As String
                Dim cusip As String
                Dim dateTimeOfFill As Date
                Dim exchange As String
                Dim execPrevSeqNo As Integer
                Dim execType As String
                Dim executingBroker As String
                Dim fillId As Integer
                Dim fillPrice As Double
                Dim fillShares As Double
                Dim investorId As String
                Dim isCFD As Boolean
                Dim isin As String
                Dim isLeg As Boolean
                Dim lastCapacity As String
                Dim lastMarket As String
                Dim limitPrice As Double
                Dim liquidity As String
                Dim localExchangeSymbol As String
                Dim locateBroker As String
                Dim locateId As String
                Dim locateRequired As Boolean
                Dim multiLedId As String
                Dim occSymbol As String
                Dim orderExecutionInstruction As String
                Dim orderHandlingInstruction As String
                Dim orderId As Long
                Dim orderInstruction As String
                Dim orderOrigin As String
                Dim orderReferenceId As String
                Dim originatingTraderUUId As Integer
                Dim reroutedBroker As String
                Dim routeCommissionAmount As Double
                Dim routeCommissionRate As Double
                Dim routeExecutionInstruction As String
                Dim routeHandlingInstruction As String
                Dim routeId As Integer
                Dim routeNetMoney As Double
                Dim routeNotes As String
                Dim routeShares As Double
                Dim securityName As String
                Dim sedol As String
                Dim settlementDate As Date
                Dim side As String
                Dim stopPrice As Double
                Dim strategyType As String
                Dim ticker As String
                Dim tif As String
                Dim traderName As String
                Dim traderUUId As Long
                Dim typ As String
                Dim userCommissionAmount As Double
                Dim userCommissionRate As Double
                Dim userFees As Double
                Dim userNetMoney As Double
                Dim yellowKey As String
                
                Set fills = msg.GetElement("Fills")
                        
                numFills = fills.numValues
                        
                For i = 0 To numFills - 1
                    
                    Set fill = fills.GetValueAsElement(i)

                    account = fill.GetElement("Account")
                    amount = fill.GetElement("Amount")
                    assetClass = fill.GetElement("AssetClass")
                    basketId = fill.GetElement("BasketId")
                    bbgid = fill.GetElement("BBGID")
                    blockId = fill.GetElement("BlockId")
                    broker = fill.GetElement("Broker")
                    clearingAccount = fill.GetElement("ClearingAccount")
                    clearingFirm = fill.GetElement("ClearingFirm")
                    contractExpDate = fill.GetElement("ContractExpDate")
                    correctedFillId = fill.GetElement("CorrectedFillId")
                    crncy = fill.GetElement("Currency")
                    cusip = fill.GetElement("Cusip")
                    dateTimeOfFill = fill.GetElement("DateTimeOfFill")
                    exchange = fill.GetElement("Exchange")
                    execPrevSeqNo = fill.GetElement("ExecPrevSeqNo")
                    execType = fill.GetElement("ExecType")
                    executingBroker = fill.GetElement("ExecutingBroker")
                    fillId = fill.GetElement("FillId")
                    fillPrice = fill.GetElement("FillPrice")
                    fillShares = fill.GetElement("FillShares")
                    investorId = fill.GetElement("InvestorID")
                    isCFD = fill.GetElement("IsCfd")
                    isin = fill.GetElement("Isin")
                    isLeg = fill.GetElement("IsLeg")
                    lastCapacity = fill.GetElement("LastCapacity")
                    lastMarket = fill.GetElement("LastMarket")
                    limitPrice = fill.GetElement("LimitPrice")
                    liquidity = fill.GetElement("Liquidity")
                    localExchangeSymbol = fill.GetElement("LocalExchangeSymbol")
                    locateBroker = fill.GetElement("LocateBroker")
                    locateId = fill.GetElement("LocateId")
                    locateRequired = fill.GetElement("LocateRequired")
                    multiLedId = fill.GetElement("MultilegId")
                    occSymbol = fill.GetElement("OCCSymbol")
                    orderExecutionInstruction = fill.GetElement("OrderExecutionInstruction")
                    orderHandlingInstruction = fill.GetElement("OrderHandlingInstruction")
                    orderId = fill.GetElement("OrderId")
                    orderInstruction = fill.GetElement("OrderInstruction")
                    orderOrigin = fill.GetElement("OrderOrigin")
                    orderReferenceId = fill.GetElement("OrderReferenceId")
                    originatingTraderUUId = fill.GetElement("OriginatingTraderUuid")
                    reroutedBroker = fill.GetElement("ReroutedBroker")
                    routeCommissionAmount = fill.GetElement("RouteCommissionAmount")
                    routeCommissionRate = fill.GetElement("RouteCommissionRate")
                    routeExecutionInstruction = fill.GetElement("RouteExecutionInstruction")
                    routeHandlingInstruction = fill.GetElement("RouteHandlingInstruction")
                    routeId = fill.GetElement("RouteId")
                    routeNetMoney = fill.GetElement("RouteNetMoney")
                    routeNotes = fill.GetElement("RouteNotes")
                    routeShares = fill.GetElement("RouteShares")
                    securityName = fill.GetElement("SecurityName")
                    sedol = fill.GetElement("Sedol")
                    settlementDate = fill.GetElement("SettlementDate")
                    side = fill.GetElement("Side")
                    stopPrice = fill.GetElement("StopPrice")
                    strategyType = fill.GetElement("StrategyType")
                    ticker = fill.GetElement("Ticker")
                    tif = fill.GetElement("TIF")
                    traderName = fill.GetElement("TraderName")
                    traderUUId = fill.GetElement("TraderUuid")
                    typ = fill.GetElement("Type")
                    userCommissionAmount = fill.GetElement("UserCommissionAmount")
                    userCommissionRate = fill.GetElement("UserCommissionRate")
                    userFees = fill.GetElement("UserFees")
                    userNetMoney = fill.GetElement("UserNetMoney")
                    yellowKey = fill.GetElement("YellowKey")
                            
                    log "OrderId: " & orderId & "    Fill ID: " & fillId & "    Date/Time: " & dateTimeOfFill & "    Shares: " & fillShares & "    Price: " & fillPrice
                    
                Next i
                
                m_BBG_EMSX.Stop
                running = False
            
            End If
        End If
    Loop

End Sub




