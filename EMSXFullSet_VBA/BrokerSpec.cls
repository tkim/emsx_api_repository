VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "BrokerSpec"
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

    log "Bloomberg - EMSX API Example - BrokerSpec"

    ' The BrokerSpec service is only available in the production environment
    emsxService = "//blp/emsx.brokerspec"
    
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
            Set req = service.CreateRequest("GetBrokerSpecForUuid")
    
            req.Set "uuid", 6767714
            
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
                
            ElseIf msg.MessageTypeAsString = "BrokerSpec" Then
                
                Dim brokers As Element
                Dim broker As Element
                Dim numBkrs As Integer
                Dim b As Integer
                Dim code As String
                Dim assetClass As String
                Dim tag As Long
                Dim strats As Element
                Dim numStrats As Integer
                Dim s As Integer
                Dim strat As Element
                Dim stratName As String
                Dim fixVal As String
                Dim params As Element
                Dim numParams As Integer
                Dim p As Integer
                Dim param As Element
                Dim pname As String
                Dim fixTag As Integer
                Dim required As String
                Dim replaceable As String
                Dim typName As String
                Dim enumerators As Element
                Dim numEnums As Integer
                Dim e As Integer
                Dim vals As String
                Dim enumerator As Element
                Dim rng As Element
                Dim mn As Long
                Dim mx As Long
                Dim st As Long
                Dim possVals As Element
                Dim numVals As Integer
                Dim v As Integer
                Dim tifs As Element
                Dim numTifs As Integer
                Dim t As Integer
                Dim tif As Element
                Dim tifName As String
                Dim tifFixValue As String
                Dim ordTypes As Element
                Dim numOrdTypes As Integer
                Dim o As Integer
                Dim ordType As Element
                Dim ordName As String
                Dim ordFixValue As String
                Dim handInsts As Element
                Dim numHandInsts As Integer
                Dim h As Integer
                Dim handInst As Element
                Dim instName As String
                Dim instFixValue As String
                    
                Set brokers = msg.GetElement("brokers")
                
                numBkrs = brokers.numValues
                
                log "No. of Brokers: " & numBkrs
                
                For b = 0 To numBkrs - 1
                    
                    Set broker = brokers.GetValueAsElement(b)
                        
                    code = broker.GetElement("code")
                    assetClass = broker.GetElement("assetClass")
                    
                    If broker.HasElement("strategyFixTag") Then
                    
                        tag = broker.GetElement("strategyFixTag")
                        
                        log "Broker code: " & code & "    Class: " & assetClass & "    Tag: " & tag
                        
                        Set strats = broker.GetElement("strategies")
                        
                        numStrats = strats.numValues
                        
                        log "    No. of Strategies: " & numStrats
                        
                        For s = 0 To numStrats - 1
                            
                            Set strat = strats.GetValueAsElement(s)
                            
                            stratName = strat.GetElement("name")
                            fixVal = strat.GetElement("fixValue")
                            
                            log "    Strategy Name: " & stratName & "    Fix Value: " & fixVal
                            
                            Set params = strat.GetElement("parameters")
                            
                            numParams = params.numValues
                            
                            log "        No. of Parameters: " & numParams
                            
                            For p = 0 To numParams - 1
                            
                                Set param = params.GetValueAsElement(p)
                                
                                pname = param.GetElement("name")
                                fixTag = param.GetElement("fixTag")
                                required = param.GetElement("isRequired")
                                replaceable = param.GetElement("isReplaceable")
                                
                                log "        Parameter: " & pname & "    Tag: " & fixTag & "    Required: " & required & "    Replaceable: " & replaceable
                                
                                typName = param.GetElement("type").GetElement(0).Name
                                
                                vals = ""
                                
                                If typName = "enumeration" Then
                                    
                                    Set enumerators = param.GetElement("type").GetElement(0).GetElement("enumerators")
                                    
                                    numEnums = enumerators.numValues
                                    
                                    For e = 0 To numEnums - 1
                                        Set enumerator = enumerators.GetValueAsElement(e)
                                        vals = vals + enumerator.GetElement("name") & "[" & enumerator.GetElement("fixValue") + "],"
                                    Next e
                                    vals = Left$(vals, Len(vals) - 1)
                                    
                                ElseIf typName = "range" Then
                                
                                    Set rng = param.GetElement("type").GetElement(0)
                                    
                                    mn = rng.GetElement("min")
                                    mx = rng.GetElement("max")
                                    st = rng.GetElement("step")
                                    
                                    vals = "min:" & mn & " max:" & mx & " step:" & st
                                    
                                ElseIf typName = "string" Then
                                
                                    Set possVals = param.GetElement("type").GetElement(0).GetElement("possibleValues")
                                    
                                    numVals = possVals.numValues
                                    
                                    For v = 0 To numVals - 1
                                        vals = vals + possVals.GetValue(0) + ","
                                    Next v
                                    
                                    If Len(vals) > 0 Then vals = Left$(vals, Len(vals) - 1)
                                    
                                End If
                                
                                If Len(vals) > 0 Then
                                    log "            Type: " & typName & " (" & vals & ")"
                                Else
                                    log "            Type: " & typName
                                End If
                                
                            Next p
                            
                        Next s
                        
                    Else
                        log "Broker code: " & code & "    Class: " & assetClass
                        log "    No Strategies"
                    End If
                    
                    log "    Time In Force:"
                    Set tifs = broker.GetElement("timesInForce")
                    numTifs = tifs.numValues
                    For t = 0 To numTifs - 1
                        Set tif = tifs.GetValueAsElement(t)
                        tifName = tif.GetElement("name")
                        tifFixValue = tif.GetElement("fixValue")
                        log "        Name: " & tifName & "    Fix Value: " & tifFixValue
                    Next t
                    
                    log "    Order Types:"
                    Set ordTypes = broker.GetElement("orderTypes")
                    numOrdTypes = ordTypes.numValues
                    For o = 0 To numOrdTypes - 1
                        Set ordType = ordTypes.GetValueAsElement(o)
                        ordName = ordType.GetElement("name")
                        ordFixValue = ordType.GetElement("fixValue")
                        log "        Name: " & ordName & "    Fix Value: " & ordFixValue
                    Next o
                    
                    log "    Handling Instructions:"
                    Set handInsts = broker.GetElement("handlingInstructions")
                    numHandInsts = handInsts.numValues
                    For h = 0 To numHandInsts - 1
                        Set handInst = handInsts.GetValueAsElement(h)
                        instName = handInst.GetElement("name")
                        instFixValue = handInst.GetElement("fixValue")
                        log "        Name: " & instName & "    Fix Value: " & instFixValue
                    Next h
                    
                Next b
                
                m_BBG_EMSX.Stop
                running = False
            
            End If
        End If
    Loop

End Sub




