VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "AssignTrader"
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

    log "Bloomberg - EMSX API Example - AssignTrader"

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
            Set req = service.CreateRequest("AssignTrader")
    
            'req.Set "EMSX_REQUEST_SEQ", 1
            
            ' Append the order numbers...
            req.Append "EMSX_SEQUENCE", 3770185
            req.Append "EMSX_SEQUENCE", 3770186
            
            req.Set "EMSX_ASSIGNEE_TRADER_UUID", 8049857
            
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
    Dim successful As Element
    Dim failed As Element
    Dim order As Element
    Dim numValues As Integer
    Dim errorCode As Long
    Dim errorMessage As String
    Dim success As Boolean

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
                
            ElseIf msg.MessageTypeAsString = "AssignTrader" Then
                
                success = msg.GetElement("EMSX_ALL_SUCCESS")
                
                If success Then
                    
                    log "All orders successfully assigned"
                    
                    Set successful = msg.GetElement("EMSX_ASSIGN_TRADER_SUCCESSFUL_ORDERS")
                    
                    numValues = successful.numValues
                    
                    If numValues > 0 Then log "Successful assignments:-"
                    
                    For i = 0 To numValues - 1
                        
                        Set order = successful.GetValueAsElement(i)
                        
                        log order.GetElement("EMSX_SEQUENCE")
                        
                    Next i
                
                Else
                
                    log "One or more failed assignments..."
                    
                    If msg.AsElement.HasElement("EMSX_ASSIGN_TRADER_SUCCESSFUL_ORDERS") Then
                    
                        Set successful = msg.GetElement("EMSX_ASSIGN_TRADER_SUCCESSFUL_ORDERS")
                    
                        numValues = successful.numValues
                    
                        If numValues > 0 Then log "Successful assignments:-"
                    
                        For i = 0 To numValues - 1
                            
                            Set order = successful.GetValueAsElement(i)
                        
                            log order.GetElement("EMSX_SEQUENCE")
                        
                        Next i
                    
                    End If
                    
                    If msg.AsElement.HasElement("EMSX_ASSIGN_TRADER_FAILED_ORDERS") Then
                    
                        Set successful = msg.GetElement("EMSX_ASSIGN_TRADER_FAILED_ORDERS")
                    
                        numValues = successful.numValues
                    
                        If numValues > 0 Then log "Failed assignments:-"
                    
                        For i = 0 To numValues - 1
                        
                            Set order = successful.GetValueAsElement(i)
                        
                            log order.GetElement("EMSX_SEQUENCE")
                        
                        Next i
                    
                    End If
                End If
                
                m_BBG_EMSX.Stop
                running = False
            
            End If
        End If
    Loop

End Sub


