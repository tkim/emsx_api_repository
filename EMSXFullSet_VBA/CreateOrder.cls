VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "CreateOrder"
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

    log "Bloomberg - EMSX API Example - CreateOrder"

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
            Set req = service.CreateRequest("CreateOrder")
    
            'The fields below are mandatory
            req.Set "EMSX_TICKER", "IBM US Equity"
            req.Set "EMSX_AMOUNT", 1000
            req.Set "EMSX_ORDER_TYPE", "MKT"
            req.Set "EMSX_TIF", "DAY"
            req.Set "EMSX_HAND_INSTRUCTION", "ANY"
            req.Set "EMSX_SIDE", "BUY"
            
            'The fields below are optional
            'req.Set "EMSX_ACCOUNT", "TestAccount"
            'req.Set "EMSX_BASKET_NAME", "HedgingBasket"
            'req.Set "EMSX_BROKER", "BMTB"
            'req.Set "EMSX_CFD_FLAG", "1"
            'req.Set "EMSX_CLEARING_ACCOUNT", "ClrAccName"
            'req.Set "EMSX_CLEARING_FIRM", "FirmName"
            'req.Set "EMSX_CUSTOM_NOTE1", "Note1"
            'req.Set "EMSX_CUSTOM_NOTE2", "Note2"
            'req.Set "EMSX_CUSTOM_NOTE3", "Note3"
            'req.Set "EMSX_CUSTOM_NOTE4", "Note4"
            'req.Set "EMSX_CUSTOM_NOTE5", "Note5"
            'req.Set "EMSX_EXCHANGE_DESTINATION", "ExchDest"
            'req.Set "EMSX_EXEC_INSTRUCTIONS", "AnyInst"
            'req.Set "EMSX_GET_WARNINGS", "0"
            'req.Set "EMSX_GTD_DATE", "20170105"
            'req.Set "EMSX_INVESTOR_ID", "InvID"
            'req.Set "EMSX_LIMIT_PRICE", 123.45
            'req.Set "EMSX_LOCATE_BROKER", "BMTB"
            'req.Set "EMSX_LOCATE_ID", "SomeID"
            'req.Set "EMSX_LOCATE_REQ", "Y"
            'req.Set "EMSX_NOTES", "Some notes"
            'req.Set "EMSX_ODD_LOT", "0"
            'req.Set "EMSX_ORDER_ORIGIN", ""
            'req.Set "EMSX_ORDER_REF_ID", "UniqueID"
            'req.Set "EMSX_P_A", "P"
            'req.Set "EMSX_RELEASE_TIME", 34341
            'req.Set "EMSX_REQUEST_SEQ", 1001
            'req.Set "EMSX_SETTLE_CURRENCY", "USD"
            'req.Set "EMSX_SETTLE_DATE", 20170106
            'req.Set "EMSX_SETTLE_TYPE", "T+2"
            'req.Set "EMSX_STOP_PRICE", 123.5
           
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
                
            ElseIf msg.MessageTypeAsString = "CreateOrder" Then
                
                Dim emsxSequence As Long
                Dim msgdesc As String
                
                emsxSequence = msg.GetElement("EMSX_SEQUENCE")
                msgdesc = msg.GetElement("MESSAGE")
                
                log "EMSX_SEQUENCE: " & emsxSequence & "    MESSAGE: " & msgdesc
                
                m_BBG_EMSX.Stop
                running = False
            
            End If
        End If
    Loop

End Sub



