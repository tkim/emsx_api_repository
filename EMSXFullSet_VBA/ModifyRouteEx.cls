VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ModifyRouteEx"
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
Private emsxService As String
Private requestID As blpapicomLib2.CorrelationId

Private Sub Class_Initialize()

    log "Bloomberg - EMSX API Sell-Side Example - ModifyRouteEx"

    emsxService = "//blp/emapisvc_beta"
    
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
            m_BBG_EMSX.OpenService emsxService
        ElseIf msg.MessageTypeAsString = "SessionStartupFailure" Then
            log "Error: Session startup failed"
            running = False
        End If
        
    Loop

End Sub

Private Sub processServiceEvent(evt As blpapicomLib2.Event)

    Dim req As REQUEST
    Dim strategy As Element
    Dim indicator As Element
    Dim data As Element
    Dim service As service
    
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
            Set service = m_BBG_EMSX.GetService(emsxService)
    
            'First, create our request object
            Set req = service.CreateRequest("ModifyRouteEx")
    
            'req.Set "EMSX_REQUEST_SEQ", 1
            
            ' The fields below are mandatory
            req.Set "EMSX_SEQUENCE", 3827449
            req.Set "EMSX_ROUTE_ID", 1
            req.Set "EMSX_AMOUNT", 500
            req.Set "EMSX_ORDER_TYPE", "MKT"
            req.Set "EMSX_TIF", "DAY"
        
            ' The fields below are optional
            'req.Set "EMSX_ACCOUNT", "TestAccount"
            'req.Set "EMSX_CLEARING_ACCOUNT", "ClearingAcnt"
            'req.Set "EMSX_CLEARING_FIRM", "ClearingFirm"
            'req.Set "EMSX_COMM_TYPE", "Absolute"
            'req.Set "EMSX_EXCHANGE_DESTINATION", "DEST"
            'req.Set "EMSX_GET_WARNINGS", "0"
            'req.Set "EMSX_GTD_DATE", "20170105"
            'req.Set "EMSX_LIMIT_PRICE", 123.45
            'req.Set "EMSX_LOC_BROKER", "ABCD"
            'req.Set "EMSX_LOC_ID", "1234567"
            'req.Set "EMSX_LOC_REQ", "Y"
            'req.Set "EMSX_NOTES", "Some notes"
            'req.Set "EMSX_ODD_LOT", ""
            'req.Set "EMSX_P_A", "P"
            'req.Set "EMSX_STOP_PRICE", 123.5
            'req.Set "EMSX_TRADER_NOTES", "Trader notes"
            'req.Set "EMSX_USER_COMM_RATE", 0.02
            'req.Set "EMSX_USER_FEES", "1.5"'

            ' Note: When changing order type to a LMT order, you will need to provide the EMSX_LIMIT_PRICE value.
            '       When changing order type away from LMT order, you will need to reset the EMSX_LIMIT_PRICE value
            '       by setting the content to -99999
            
            ' Note: To clear down the stop price, set the content to -1
            
            ' Set the strategy parameters, if required
            
            
            Set strategy = req.GetElement("EMSX_STRATEGY_PARAMS")
            strategy.SetElement "EMSX_STRATEGY_NAME", "VWAP"
            
            Set indicator = strategy.GetElement("EMSX_STRATEGY_FIELD_INDICATORS")
            Set data = strategy.GetElement("EMSX_STRATEGY_FIELDS")
            
            ' Strategy parameters must be appended in the correct order. See the output
            ' of GetBrokerStrategyInfo request for the order. The indicator value is 0 for
            ' a field that carries a value, and 1 where the field should be ignored
            
            
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", "09:30:00"   ' StartTime
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 0
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", "10:30:00"   ' EndTime
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 0
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' Max%Volume
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' %AMSession
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' OPG
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' MOC
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' CompletePX
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' TriggerPX
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' DarkComplete
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' DarkCompPX
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' RefIndex
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            '
            'data.AppendElment().SetElement "EMSX_FIELD_DATA", ""           ' Discretion
            'indicator.AppendElment().SetElement "EMSX_FIELD_INDICATOR", 1
            
            ' If modifying on behalf of another trader, set the order owner's UUID
            'req.Set "EMSX_TRADER_UUID", 1234567
            
            ' If modifying a multi-leg route, indicate the Multileg ID
            'Dim requestType As Element
            'requestType = req.GetElement("EMSX_REQUEST_TYPE")
            'Dim multileg As Element
            'multileg = requestType.GetElement("Multileg")
            'multileg.SetElement "EMSX_ML_ID", "123456"
            
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
                
            ElseIf msg.MessageTypeAsString = "ModifyOrderEx" Then
                
                Dim msgdesc As String
                
                ' The response has fields for EMSX_SEQUENCE and EMSX_ROUTE_ID, but these will always be zero

                msgdesc = msg.GetElement("MESSAGE")
                
                log "MESSAGE: " & msgdesc
                
                m_BBG_EMSX.Stop
                running = False
            
            End If
        End If
    Loop

End Sub






