VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "EMSXSubscriptions"
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
Private svc As blpapicomLib2.service
Private emsxService As String
Private orderSubscriptionID As blpapicomLib2.CorrelationId
Private routeSubscriptionID As blpapicomLib2.CorrelationId
Public monitoring As Boolean

Private Sub Class_Initialize()

    mon "Bloomberg - EMSX API Example - EMSXSubscriptions"

    emsxService = "//blp/emapisvc_beta"
    
    Set m_BBG_EMSX = New blpapicomLib2.Session
    
    monitoring = True
    
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
        
            Case ADMIN
                processAdminEvent eventObj
            
            Case SESSION_STATUS
                processSessionEvent eventObj
                
            Case BLPSERVICE_STATUS
                processServiceEvent eventObj
                
            Case SUBSCRIPTION_STATUS
                processSubscriptionStatusEvent eventObj
            
            Case SUBSCRIPTION_DATA
                processSubscriptionDataEvent eventObj
                
        End Select
        
    End If

    Exit Sub

errHandler:
    Dim errmsg As Variant
    errmsg = Err.Description
    mon (errmsg)

End Sub


Private Sub processAdminEvent(evt As blpapicomLib2.Event)

    mon "Processing SESSION_STATUS event"
    
    Dim it As blpapicomLib2.MessageIterator
    
    Set it = evt.CreateMessageIterator()

    ' Loop while we have messages remaining
    Do While it.Next()
              
        Dim msg As Message
        
        '   Pick up message
        Set msg = it.Message
        
        mon "MessageType: " + msg.MessageTypeAsString
        
        If msg.MessageTypeAsString = "SlowConsumerWarning" Then
            mon "Warning: Entered Slow Consumer status"
        ElseIf msg.MessageTypeAsString = "SlowConsumerWarningCleared" Then
            mon "Slow consumer status cleared"
        End If
        
    Loop

End Sub

Private Sub processSessionEvent(evt As blpapicomLib2.Event)

    mon "Processing SESSION_STATUS event"
    
    Dim it As blpapicomLib2.MessageIterator
    
    Set it = evt.CreateMessageIterator()

    ' Loop while we have messages remaining
    Do While it.Next()
              
        Dim msg As Message
        
        '   Pick up message
        Set msg = it.Message
        
        mon "MessageType: " + msg.MessageTypeAsString
        
        If msg.MessageTypeAsString = "SessionStarted" Then
            mon "Session started..."
            m_BBG_EMSX.OpenService emsxService
        ElseIf msg.MessageTypeAsString = "SessionStartupFailure" Then
            mon "Error: Session startup failed"
        ElseIf msg.MessageTypeAsString = "SessionTerminated" Then
            mon "Session has been terminated"
        ElseIf msg.MessageTypeAsString = "SessionConnectionUp" Then
            mon "Session connection is up"
        ElseIf msg.MessageTypeAsString = "SessionConnectionDown" Then
            mon "Session connection is down"
        End If
        
    Loop

End Sub

Private Sub processServiceEvent(evt As blpapicomLib2.Event)

    Dim it As blpapicomLib2.MessageIterator
    
    On Error GoTo failed
    
    mon "Processing SERVICE_STATUS event"
    
    Set it = evt.CreateMessageIterator()

    ' Loop while we have messages remaining
    Do While it.Next()
              
        Dim msg As Message
        
        '   Pick up message
        Set msg = it.Message
        
        mon "MessageType: " + msg.MessageTypeAsString
        
        If msg.MessageTypeAsString = "ServiceOpened" Then
    
            mon "Service opened..."
            
            createOrderSubscription
        
        ElseIf msg.MessageTypeAsString = "ServiceOpenFailure" Then
            
            mon "Error: Service failed to open"
        
        End If
        
    Loop

    Exit Sub
    
failed:

    mon "Failed to send the request: " + Err.Description
    
    Exit Sub
    
End Sub

Private Sub processSubscriptionStatusEvent(evt As blpapicomLib2.Event)

    Dim it As blpapicomLib2.MessageIterator
    
    mon "Processing SUBSCRIPTION_STATUS event"
    
    Set it = evt.CreateMessageIterator()

    ' Loop while we have messages remaining
    Do While it.Next()
              
        Dim msg As Message
        
        '   Pick up message
        Set msg = it.Message
        
        If msg.MessageTypeAsString = "SubscriptionStarted" Then
            If msg.CorrelationId.Value = orderSubscriptionID.Value Then
                mon "Order subscription started successfully"
                createRouteSubscription
            ElseIf msg.CorrelationId.Value = routeSubscriptionID.Value Then
                mon "Route subscription started successfully"
            End If
        
        ElseIf msg.MessageTypeAsString = "SubscriptionFailure" Then
            If msg.CorrelationId.Value = orderSubscriptionID.Value Then
                mon "Error: Order subscription failed"
            ElseIf msg.CorrelationId.Value = routeSubscriptionID.Value Then
                mon "Error: Route subscription failed"
            End If
            
        ElseIf msg.MessageTypeAsString = "SubscriptionTerminated" Then
            If msg.CorrelationId.Value = orderSubscriptionID.Value Then
                mon "Order subscription terminated"
            ElseIf msg.CorrelationId.Value = routeSubscriptionID.Value Then
                mon "Route subscription terminated"
            End If
        
        End If
        
    Loop

    Exit Sub
    
End Sub

Private Sub processSubscriptionDataEvent(evt As blpapicomLib2.Event)

    Dim it As blpapicomLib2.MessageIterator
    Dim event_status As Integer
    
    On Error GoTo fail
    
    Set it = evt.CreateMessageIterator()

    ' Loop while we have messages remaining
    Do While it.Next()
              
        Dim msg As Message
        
        '   Pick up message
        Set msg = it.Message
        
        If msg.MessageTypeAsString = "OrderRouteFields" Then
        
            event_status = msg.GetElement("EVENT_STATUS")
            
            If event_status = 1 Then
                If msg.CorrelationId.Value = orderSubscriptionID.Value Then
                    'mon "O.", True
                ElseIf msg.CorrelationId.Value = routeSubscriptionID.Value Then
                    'mon "R.", True
                End If
            ElseIf event_status = 11 Then
                If msg.CorrelationId.Value = orderSubscriptionID.Value Then
                    mon "Order - End of initial paint"
                ElseIf msg.CorrelationId.Value = routeSubscriptionID.Value Then
                    mon "Route - End of initial paint"
                End If
            Else
                mon ""
                
                Dim api_seq_num As Long
                Dim emsx_account As String
                Dim emsx_amount As Long
                Dim emsx_arrival_price As Double
                Dim emsx_asset_class As String
                Dim emsx_assigned_trader As String
                Dim emsx_avg_price As Double
                Dim emsx_basket_name As String
                Dim emsx_basket_num As Long
                Dim emsx_broker As String
                Dim emsx_broker_comm As Double
                Dim emsx_bse_avg_price As Double
                Dim emsx_bse_filled As Long
                Dim emsx_cfd_flag As String
                Dim emsx_comm_diff_flag As String
                Dim emsx_comm_rate As Double
                Dim emsx_currency_pair As String
                Dim emsx_date As String
                Dim emsx_day_avg_price As Double
                Dim emsx_day_fill As Long
                Dim emsx_dir_broker_flag As String
                Dim emsx_exchange As String
                Dim emsx_exchange_destination As String
                Dim emsx_exec_instruction As String
                Dim emsx_fill_id As Long
                Dim emsx_filled As Long
                Dim emsx_gtd_date As Long
                Dim emsx_hand_instruction As String
                Dim emsx_idle_amount As Long
                Dim emsx_investor_id As String
                Dim emsx_isin As String
                Dim emsx_limit_price As Double
                Dim emsx_notes As String
                Dim emsx_nse_avg_price As Double
                Dim emsx_nse_filled As Long
                Dim emsx_ord_ref_id As String
                Dim emsx_order_type As String
                Dim emsx_originate_trader As String
                Dim emsx_originate_trader_firm As String
                Dim emsx_percent_remain As Double
                Dim emsx_pm_uuid As Long
                Dim emsx_port_mgr As String
                Dim emsx_port_name As String
                Dim emsx_port_num As Long
                Dim emsx_position As String
                Dim emsx_principle As Double
                Dim emsx_product As String
                Dim emsx_queued_date As Long
                Dim emsx_queued_time As Long
                Dim emsx_reason_code As String
                Dim emsx_reason_desc As String
                Dim emsx_remain_balance As Double
                Dim emsx_route_id As Long
                Dim emsx_route_price As Double
                Dim emsx_sec_name As String
                Dim emsx_sedol As String
                Dim emsx_sequence As Long
                Dim emsx_settle_amount As Double
                Dim emsx_settle_date As String
                Dim emsx_side As String
                Dim emsx_start_amount As Long
                Dim emsx_status As String
                Dim emsx_step_out_broker As String
                Dim emsx_stop_price As Double
                Dim emsx_strategy_end_time As Long
                Dim emsx_strategy_part_rate1 As Double
                Dim emsx_strategy_part_rate2 As Double
                Dim emsx_strategy_start_time As Long
                Dim emsx_strategy_style As String
                Dim emsx_strategy_type As String
                Dim emsx_ticker As String
                Dim emsx_tif As String
                Dim emsx_time_stamp As Long
                Dim emsx_trad_uuid As Long
                Dim emsx_trade_desk As String
                Dim emsx_trader As String
                Dim emsx_trader_notes As String
                Dim emsx_ts_ordnum As Long
                Dim emsx_type As String
                Dim emsx_underlying_ticker As String
                Dim emsx_user_comm_amount As Double
                Dim emsx_user_comm_rate As Double
                Dim emsx_user_fees As Double
                Dim emsx_user_net_money As Double
                Dim emsx_user_work_price As Double
                Dim emsx_working As Integer
                Dim emsx_yellow_key As String
                Dim emsx_clearing_account As String
                Dim emsx_clearing_firm As String
                Dim emsx_custom_account As String
                Dim emsx_execute_broker As String
                Dim emsx_is_manual_route As Integer
                Dim emsx_last_fill_date As Long
                Dim emsx_last_fill_time As Long
                Dim emsx_last_market As String
                Dim emsx_last_price As Double
                Dim emsx_last_shares As Long
                Dim emsx_misc_fees As Double
                Dim emsx_ml_leg_quantity As Long
                Dim emsx_ml_num_legs As Integer
                Dim emsx_ml_percent_filled As Double
                Dim emsx_ml_ratio As Double
                Dim emsx_ml_remain_balance As Double
                Dim emsx_ml_strategy As String
                Dim emsx_ml_total_quantity As Long
                Dim emsx_p_a As String
                Dim emsx_principal As Double
                Dim emsx_route_create_date As Long
                Dim emsx_route_create_time As Long
                Dim emsx_route_ref_id As String
                Dim emsx_route_last_update_time As Long
                Dim emsx_urgency_level As Integer
                
                If msg.CorrelationId.Value = orderSubscriptionID.Value Then
            
                    mon "ORDER MESSAGE: CorrelationID(" & msg.CorrelationId.Value & ")  Status(" & event_status & ")"
                    
                    If msg.AsElement.HasElement("API_SEQ_NUM") Then api_seq_num = msg.GetElement("API_SEQ_NUM") Else api_seq_num = 0
                    If msg.AsElement.HasElement("EMSX_ACCOUNT") Then emsx_account = msg.GetElement("EMSX_ACCOUNT") Else emsx_account = ""
                    If msg.AsElement.HasElement("EMSX_AMOUNT") Then emsx_amount = msg.GetElement("EMSX_AMOUNT") Else emsx_amount = 0
                    If msg.AsElement.HasElement("EMSX_ARRIVAL_PRICE") Then emsx_arrival_price = msg.GetElement("EMSX_ARRIVAL_PRICE") Else emsx_arrival_price = 0
                    If msg.AsElement.HasElement("EMSX_ASSET_CLASS") Then emsx_asset_class = msg.GetElement("EMSX_ASSET_CLASS") Else emsx_asset_class = ""
                    If msg.AsElement.HasElement("EMSX_ASSIGNED_TRADER") Then emsx_assigned_trader = msg.GetElement("EMSX_ASSIGNED_TRADER") Else emsx_assigned_trader = ""
                    If msg.AsElement.HasElement("EMSX_AVG_PRICE") Then emsx_avg_price = msg.GetElement("EMSX_AVG_PRICE") Else emsx_avg_price = 0
                    If msg.AsElement.HasElement("EMSX_BASKET_NAME") Then emsx_basket_name = msg.GetElement("EMSX_BASKET_NAME") Else emsx_basket_name = ""
                    If msg.AsElement.HasElement("EMSX_BASKET_NUM") Then emsx_basket_num = msg.GetElement("EMSX_BASKET_NUM") Else emsx_basket_num = 0
                    If msg.AsElement.HasElement("EMSX_BROKER") Then emsx_broker = msg.GetElement("EMSX_BROKER") Else emsx_broker = ""
                    If msg.AsElement.HasElement("EMSX_BROKER_COMM") Then emsx_broker_comm = msg.GetElement("EMSX_BROKER_COMM") Else emsx_broker_comm = 0
                    If msg.AsElement.HasElement("EMSX_BSE_AVG_PRICE") Then emsx_bse_avg_price = msg.GetElement("EMSX_BSE_AVG_PRICE") Else emsx_bse_avg_price = 0
                    If msg.AsElement.HasElement("EMSX_BSE_FILLED") Then emsx_bse_filled = msg.GetElement("EMSX_BSE_FILLED") Else emsx_bse_filled = 0
                    If msg.AsElement.HasElement("EMSX_CFD_FLAG") Then emsx_cfd_flag = msg.GetElement("EMSX_CFD_FLAG") Else emsx_cfd_flag = ""
                    If msg.AsElement.HasElement("EMSX_COMM_DIFF_FLAG") Then emsx_comm_diff_flag = msg.GetElement("EMSX_COMM_DIFF_FLAG") Else emsx_comm_diff_flag = ""
                    If msg.AsElement.HasElement("EMSX_COMM_RATE") Then emsx_comm_rate = msg.GetElement("EMSX_COMM_RATE") Else emsx_comm_rate = 0
                    If msg.AsElement.HasElement("EMSX_CURRENCY_PAIR") Then emsx_currency_pair = msg.GetElement("EMSX_CURRENCY_PAIR") Else emsx_currency_pair = ""
                    If msg.AsElement.HasElement("EMSX_DATE") Then emsx_date = msg.GetElement("EMSX_DATE") Else emsx_date = 0
                    If msg.AsElement.HasElement("EMSX_DAY_AVG_PRICE") Then emsx_day_avg_price = msg.GetElement("EMSX_DAY_AVG_PRICE") Else emsx_day_avg_price = 0
                    If msg.AsElement.HasElement("EMSX_DAY_FILL") Then emsx_day_fill = msg.GetElement("EMSX_DAY_FILL") Else emsx_day_fill = 0
                    If msg.AsElement.HasElement("EMSX_DIR_BROKER_FLAG") Then emsx_dir_broker_flag = msg.GetElement("EMSX_DIR_BROKER_FLAG") Else emsx_dir_broker_flag = ""
                    If msg.AsElement.HasElement("EMSX_EXCHANGE") Then emsx_exchange = msg.GetElement("EMSX_EXCHANGE") Else emsx_exchange = ""
                    If msg.AsElement.HasElement("EMSX_EXCHANGE_DESTINATION") Then emsx_exchange_destination = msg.GetElement("EMSX_EXCHANGE_DESTINATION") Else emsx_exchange_destination = ""
                    If msg.AsElement.HasElement("EMSX_EXEC_INSTRUCTION") Then emsx_exec_instruction = msg.GetElement("EMSX_EXEC_INSTRUCTION") Else emsx_exec_instruction = ""
                    If msg.AsElement.HasElement("EMSX_FILL_ID") Then emsx_fill_id = msg.GetElement("EMSX_FILL_ID") Else emsx_fill_id = 0
                    If msg.AsElement.HasElement("EMSX_FILLED") Then emsx_filled = msg.GetElement("EMSX_FILLED") Else emsx_filled = 0
                    If msg.AsElement.HasElement("EMSX_GTD_DATE") Then emsx_gtd_date = msg.GetElement("EMSX_GTD_DATE") Else emsx_gtd_date = 0
                    If msg.AsElement.HasElement("EMSX_HAND_INSTRUCTION") Then emsx_hand_instruction = msg.GetElement("EMSX_HAND_INSTRUCTION") Else emsx_hand_instruction = ""
                    If msg.AsElement.HasElement("EMSX_IDLE_AMOUNT") Then emsx_idle_amount = msg.GetElement("EMSX_IDLE_AMOUNT") Else emsx_idle_amount = 0
                    If msg.AsElement.HasElement("EMSX_INVESTOR_ID") Then emsx_investor_id = msg.GetElement("EMSX_INVESTOR_ID") Else emsx_investor_id = ""
                    If msg.AsElement.HasElement("EMSX_ISIN") Then emsx_isin = msg.GetElement("EMSX_ISIN") Else emsx_isin = ""
                    If msg.AsElement.HasElement("EMSX_LIMIT_PRICE") Then emsx_limit_price = msg.GetElement("EMSX_LIMIT_PRICE") Else emsx_limit_price = 0
                    If msg.AsElement.HasElement("EMSX_NOTES") Then emsx_notes = msg.GetElement("EMSX_NOTES") Else emsx_notes = ""
                    If msg.AsElement.HasElement("EMSX_NSE_AVG_PRICE") Then emsx_nse_avg_price = msg.GetElement("EMSX_NSE_AVG_PRICE") Else emsx_nse_avg_price = 0
                    If msg.AsElement.HasElement("EMSX_NSE_FILLED") Then emsx_nse_filled = msg.GetElement("EMSX_NSE_FILLED") Else emsx_nse_filled = 0
                    If msg.AsElement.HasElement("EMSX_ORD_REF_ID") Then emsx_ord_ref_id = msg.GetElement("EMSX_ORD_REF_ID") Else emsx_ord_ref_id = ""
                    If msg.AsElement.HasElement("EMSX_ORDER_TYPE") Then emsx_order_type = msg.GetElement("EMSX_ORDER_TYPE") Else emsx_order_type = ""
                    If msg.AsElement.HasElement("EMSX_ORIGINATE_TRADER") Then emsx_originate_trader = msg.GetElement("EMSX_ORIGINATE_TRADER") Else emsx_originate_trader = ""
                    If msg.AsElement.HasElement("EMSX_ORIGINATE_TRADER_FIRM") Then emsx_originate_trader_firm = msg.GetElement("EMSX_ORIGINATE_TRADER_FIRM") Else emsx_originate_trader_firm = ""
                    If msg.AsElement.HasElement("EMSX_PERCENT_REMAIN") Then emsx_percent_remain = msg.GetElement("EMSX_PERCENT_REMAIN") Else emsx_percent_remain = 0
                    If msg.AsElement.HasElement("EMSX_PM_UUID") Then emsx_pm_uuid = msg.GetElement("EMSX_PM_UUID") Else emsx_pm_uuid = 0
                    If msg.AsElement.HasElement("EMSX_PORT_MGR") Then emsx_port_mgr = msg.GetElement("EMSX_PORT_MGR") Else emsx_port_mgr = ""
                    If msg.AsElement.HasElement("EMSX_PORT_NAME") Then emsx_port_name = msg.GetElement("EMSX_PORT_NAME") Else emsx_port_name = ""
                    If msg.AsElement.HasElement("EMSX_PORT_NUM") Then emsx_port_num = msg.GetElement("EMSX_PORT_NUM") Else emsx_port_num = 0
                    If msg.AsElement.HasElement("EMSX_POSITION") Then emsx_position = msg.GetElement("EMSX_POSITION") Else emsx_position = ""
                    If msg.AsElement.HasElement("EMSX_PRINCIPAL") Then emsx_principle = msg.GetElement("EMSX_PRINCIPAL") Else emsx_principle = 0
                    If msg.AsElement.HasElement("EMSX_PRODUCT") Then emsx_product = msg.GetElement("EMSX_PRODUCT") Else emsx_product = ""
                    If msg.AsElement.HasElement("EMSX_QUEUED_DATE") Then emsx_queued_date = msg.GetElement("EMSX_QUEUED_DATE") Else emsx_queued_date = 0
                    If msg.AsElement.HasElement("EMSX_QUEUED_TIME") Then emsx_queued_time = msg.GetElement("EMSX_QUEUED_TIME") Else emsx_queued_time = 0
                    If msg.AsElement.HasElement("EMSX_REASON_CODE") Then emsx_reason_code = msg.GetElement("EMSX_REASON_CODE") Else emsx_reason_code = ""
                    If msg.AsElement.HasElement("EMSX_REASON_DESC") Then emsx_reason_desc = msg.GetElement("EMSX_REASON_DESC") Else emsx_reason_desc = ""
                    If msg.AsElement.HasElement("EMSX_REMAIN_BALANCE") Then emsx_remain_balance = msg.GetElement("EMSX_REMAIN_BALANCE") Else emsx_remain_balance = 0
                    If msg.AsElement.HasElement("EMSX_ROUTE_ID") Then emsx_route_id = msg.GetElement("EMSX_ROUTE_ID") Else emsx_route_id = 0
                    If msg.AsElement.HasElement("EMSX_ROUTE_PRICE") Then emsx_route_price = msg.GetElement("EMSX_ROUTE_PRICE") Else emsx_route_price = 0
                    If msg.AsElement.HasElement("EMSX_SEC_NAME") Then emsx_sec_name = msg.GetElement("EMSX_SEC_NAME") Else emsx_sec_name = ""
                    If msg.AsElement.HasElement("EMSX_SEDOL") Then emsx_sedol = msg.GetElement("EMSX_SEDOL") Else emsx_sedol = ""
                    If msg.AsElement.HasElement("EMSX_SEQUENCE") Then emsx_sequence = msg.GetElement("EMSX_SEQUENCE") Else emsx_sequence = 0
                    If msg.AsElement.HasElement("EMSX_SETTLE_AMOUNT") Then emsx_settle_amount = msg.GetElement("EMSX_SETTLE_AMOUNT") Else emsx_settle_amount = 0
                    If msg.AsElement.HasElement("EMSX_SETTLE_DATE") Then emsx_settle_date = msg.GetElement("EMSX_SETTLE_DATE") Else emsx_settle_date = 0
                    If msg.AsElement.HasElement("EMSX_SIDE") Then emsx_side = msg.GetElement("EMSX_SIDE") Else emsx_side = ""
                    If msg.AsElement.HasElement("EMSX_START_AMOUNT") Then emsx_start_amount = msg.GetElement("EMSX_START_AMOUNT") Else emsx_start_amount = 0
                    If msg.AsElement.HasElement("EMSX_STATUS") Then emsx_status = msg.GetElement("EMSX_STATUS") Else emsx_status = ""
                    If msg.AsElement.HasElement("EMSX_STEP_OUT_BROKER") Then emsx_step_out_broker = msg.GetElement("EMSX_STEP_OUT_BROKER") Else emsx_step_out_broker = ""
                    If msg.AsElement.HasElement("EMSX_STOP_PRICE") Then emsx_stop_price = msg.GetElement("EMSX_STOP_PRICE") Else emsx_stop_price = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_END_TIME") Then emsx_strategy_end_time = msg.GetElement("EMSX_STRATEGY_END_TIME") Else emsx_strategy_end_time = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_PART_RATE1") Then emsx_strategy_part_rate1 = msg.GetElement("EMSX_STRATEGY_PART_RATE1") Else emsx_strategy_part_rate1 = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_PART_RATE2") Then emsx_strategy_part_rate2 = msg.GetElement("EMSX_STRATEGY_PART_RATE2") Else emsx_strategy_part_rate2 = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_START_TIME") Then emsx_strategy_start_time = msg.GetElement("EMSX_STRATEGY_START_TIME") Else emsx_strategy_start_time = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_STYLE") Then emsx_strategy_style = msg.GetElement("EMSX_STRATEGY_STYLE") Else emsx_strategy_style = ""
                    If msg.AsElement.HasElement("EMSX_STRATEGY_TYPE") Then emsx_strategy_type = msg.GetElement("EMSX_STRATEGY_TYPE") Else emsx_strategy_type = ""
                    If msg.AsElement.HasElement("EMSX_TICKER") Then emsx_ticker = msg.GetElement("EMSX_TICKER") Else emsx_ticker = ""
                    If msg.AsElement.HasElement("EMSX_TIF") Then emsx_tif = msg.GetElement("EMSX_TIF") Else emsx_tif = ""
                    If msg.AsElement.HasElement("EMSX_TIME_STAMP") Then emsx_time_stamp = msg.GetElement("EMSX_TIME_STAMP") Else emsx_time_stamp = 0
                    If msg.AsElement.HasElement("EMSX_TRAD_UUID") Then emsx_trad_uuid = msg.GetElement("EMSX_TRAD_UUID") Else emsx_trad_uuid = 0
                    If msg.AsElement.HasElement("EMSX_TRADE_DESK") Then emsx_trade_desk = msg.GetElement("EMSX_TRADE_DESK") Else emsx_trade_desk = ""
                    If msg.AsElement.HasElement("EMSX_TRADER") Then emsx_trader = msg.GetElement("EMSX_TRADER") Else emsx_trader = ""
                    If msg.AsElement.HasElement("EMSX_TRADER_NOTES") Then emsx_trader_notes = msg.GetElement("EMSX_TRADER_NOTES") Else emsx_trader_notes = ""
                    If msg.AsElement.HasElement("EMSX_TS_ORDNUM") Then emsx_ts_ordnum = msg.GetElement("EMSX_TS_ORDNUM") Else emsx_ts_ordnum = 0
                    If msg.AsElement.HasElement("EMSX_TYPE") Then emsx_type = msg.GetElement("EMSX_TYPE") Else emsx_type = ""
                    If msg.AsElement.HasElement("EMSX_UNDERLYING_TICKER") Then emsx_underlying_ticker = msg.GetElement("EMSX_UNDERLYING_TICKER") Else emsx_underlying_ticker = ""
                    If msg.AsElement.HasElement("EMSX_USER_COMM_AMOUNT") Then emsx_user_comm_amount = msg.GetElement("EMSX_USER_COMM_AMOUNT") Else emsx_user_comm_amount = 0
                    If msg.AsElement.HasElement("EMSX_USER_COMM_RATE") Then emsx_user_comm_rate = msg.GetElement("EMSX_USER_COMM_RATE") Else emsx_user_comm_rate = 0
                    If msg.AsElement.HasElement("EMSX_USER_FEES") Then emsx_user_fees = msg.GetElement("EMSX_USER_FEES") Else emsx_user_fees = 0
                    If msg.AsElement.HasElement("EMSX_USER_NET_MONEY") Then emsx_user_net_money = msg.GetElement("EMSX_USER_NET_MONEY") Else emsx_user_net_money = 0
                    If msg.AsElement.HasElement("EMSX_WORK_PRICE") Then emsx_user_work_price = msg.GetElement("EMSX_WORK_PRICE") Else emsx_user_work_price = 0
                    If msg.AsElement.HasElement("EMSX_WORKING") Then emsx_working = msg.GetElement("EMSX_WORKING") Else emsx_working = 0
                    If msg.AsElement.HasElement("EMSX_YELLOW_KEY") Then emsx_yellow_key = msg.GetElement("EMSX_YELLOW_KEY") Else emsx_yellow_key = ""

                    mon "ORDER >> EMSX_SEQUENCE: " & emsx_sequence & "   EMSX_WORKING: " & emsx_working & "    EMSX_FILLED: " & emsx_filled & "    EMSX_STATUS: " & emsx_status
                    
                    'mon "API_SEQ_NUM: " & api_seq_num
                    'mon "EMSX_ACCOUNT: " & emsx_account
                    'mon "EMSX_AMOUNT: " & emsx_amount
                    'mon "EMSX_ARRIVAL_PRICE: " & emsx_arrival_price
                    'mon "EMSX_ASSET_CLASS: " & emsx_asset_class
                    'mon "EMSX_ASSIGNED_TRADER: " & emsx_assigned_trader
                    'mon "EMSX_AVG_PRICE: " & emsx_avg_price
                    'mon "EMSX_BASKET_NAME: " & emsx_basket_name
                    'mon "EMSX_BASKET_NUM: " & emsx_basket_num
                    'mon "EMSX_BROKER: " & emsx_broker
                    'mon "EMSX_BROKER_COMM: " & emsx_broker_comm
                    'mon "EMSX_BSE_AVG_PRICE: " & emsx_bse_avg_price
                    'mon "EMSX_BSE_FILLED: " & emsx_bse_filled
                    'mon "EMSX_CFD_FLAG: " & emsx_cfd_flag
                    'mon "EMSX_COMM_DIFF_FLAG: " & emsx_comm_diff_flag
                    'mon "EMSX_COMM_RATE: " & emsx_comm_rate
                    'mon "EMSX_CURRENCY_PAIR: " & emsx_currency_pair
                    'mon "EMSX_DATE: " & emsx_date
                    'mon "EMSX_DAY_AVG_PRICE: " & emsx_day_avg_price
                    'mon "EMSX_DAY_FILL: " & emsx_day_fill
                    'mon "EMSX_DIR_BROKER_FLAG: " & emsx_dir_broker_flag
                    'mon "EMSX_EXCHANGE: " & emsx_exchange
                    'mon "EMSX_EXCHANGE_DESTINATION: " & emsx_exchange_destination
                    'mon "EMSX_EXEC_INSTRUCTION: " & emsx_exec_instruction
                    'mon "EMSX_FILL_ID: " & emsx_fill_id
                    'mon "EMSX_FILLED: " & emsx_filled
                    'mon "EMSX_GTD_DATE: " & emsx_gtd_date
                    'mon "EMSX_HAND_INSTRUCTION: " & emsx_hand_instruction
                    'mon "EMSX_IDLE_AMOUNT: " & emsx_idle_amount
                    'mon "EMSX_INVESTOR_ID: " & emsx_investor_id
                    'mon "EMSX_ISIN: " & emsx_isin
                    'mon "EMSX_LIMIT_PRICE: " & emsx_limit_price
                    'mon "EMSX_NOTES: " & emsx_notes
                    'mon "EMSX_NSE_AVG_PRICE: " & emsx_nse_avg_price
                    'mon "EMSX_NSE_FILLED: " & emsx_nse_filled
                    'mon "EMSX_ORD_REF_ID: " & emsx_ord_ref_id
                    'mon "EMSX_ORDER_TYPE: " & emsx_order_type
                    'mon "EMSX_ORIGINATE_TRADER: " & emsx_originate_trader
                    'mon "EMSX_ORIGINATE_TRADER_FIRM: " & emsx_originate_trader_firm
                    'mon "EMSX_PERCENT_REMAIN: " & emsx_percent_remain
                    'mon "EMSX_PM_UUID: " & emsx_pm_uuid
                    'mon "EMSX_PORT_MGR: " & emsx_port_mgr
                    'mon "EMSX_PORT_NAME: " & emsx_port_name
                    'mon "EMSX_PORT_NUM: " & emsx_port_num
                    'mon "EMSX_POSITION: " & emsx_position
                    'mon "EMSX_PRINCIPAL: " & emsx_principle
                    'mon "EMSX_PRODUCT: " & emsx_product
                    'mon "EMSX_QUEUED_DATE: " & emsx_queued_date
                    'mon "EMSX_QUEUED_TIME: " & emsx_queued_time
                    'mon "EMSX_REASON_CODE: " & emsx_reason_code
                    'mon "EMSX_REASON_DESC: " & emsx_reason_desc
                    'mon "EMSX_REMAIN_BALANCE: " & emsx_remain_balance
                    'mon "EMSX_ROUTE_ID: " & emsx_route_id
                    'mon "EMSX_ROUTE_PRICE: " & emsx_route_price
                    'mon "EMSX_SEC_NAME: " & emsx_sec_name
                    'mon "EMSX_SEDOL: " & emsx_sedol
                    'mon "EMSX_SEQUENCE: " & emsx_sequence
                    'mon "EMSX_SETTLE_AMOUNT: " & emsx_settle_amount
                    'mon "EMSX_SETTLE_DATE: " & emsx_settle_date
                    'mon "EMSX_SIDE: " & emsx_side
                    'mon "EMSX_START_AMOUNT: " & emsx_start_amount
                    'mon "EMSX_STATUS: " & emsx_status
                    'mon "EMSX_STEP_OUT_BROKER: " & emsx_step_out_broker
                    'mon "EMSX_STOP_PRICE: " & emsx_stop_price
                    'mon "EMSX_STRATEGY_END_TIME: " & emsx_strategy_end_time
                    'mon "EMSX_STRATEGY_PART_RATE1: " & emsx_strategy_part_rate1
                    'mon "EMSX_STRATEGY_PART_RATE2: " & emsx_strategy_part_rate2
                    'mon "EMSX_STRATEGY_START_TIME: " & emsx_strategy_start_time
                    'mon "EMSX_STRATEGY_STYLE: " & emsx_strategy_style
                    'mon "EMSX_STRATEGY_TYPE: " & emsx_strategy_type
                    'mon "EMSX_TICKER: " & emsx_ticker
                    'mon "EMSX_TIF: " & emsx_tif
                    'mon "EMSX_TIME_STAMP: " & emsx_time_stamp
                    'mon "EMSX_TRAD_UUID: " & emsx_trad_uuid
                    'mon "EMSX_TRADE_DESK: " & emsx_trade_desk
                    'mon "EMSX_TRADER: " & emsx_trader
                    'mon "EMSX_TRADER_NOTES: " & emsx_trader_notes
                    'mon "EMSX_TS_ORDNUM: " & emsx_ts_ordnum
                    'mon "EMSX_TYPE: " & emsx_type
                    'mon "EMSX_UNDERLYING_TICKER: " & emsx_underlying_ticker
                    'mon "EMSX_USER_COMM_AMOUNT: " & emsx_user_comm_amount
                    'mon "EMSX_USER_COMM_RATE: " & emsx_user_comm_rate
                    'mon "EMSX_USER_FEES: " & emsx_user_fees
                    'mon "EMSX_USER_NET_MONEY: " & emsx_user_net_money
                    'mon "EMSX_WORK_PRICE: " & emsx_user_work_price
                    'mon "EMSX_WORKING: " & emsx_working
                    'mon "EMSX_YELLOW_KEY: " & emsx_yellow_key

                ElseIf msg.CorrelationId.Value = routeSubscriptionID.Value Then
                
                    mon "ROUTE MESSAGE: CorrelationID(" & msg.CorrelationId.Value & ")  Status(" & event_status & ")"
                    
                    If msg.AsElement.HasElement("API_SEQ_NUM") Then api_seq_num = msg.GetElement("API_SEQ_NUM") Else api_seq_num = 0
                    If msg.AsElement.HasElement("EMSX_ACCOUNT") Then emsx_account = msg.GetElement("EMSX_ACCOUNT") Else emsx_account = ""
                    If msg.AsElement.HasElement("EMSX_AMOUNT") Then emsx_amount = msg.GetElement("EMSX_AMOUNT") Else emsx_amount = 0
                    If msg.AsElement.HasElement("EMSX_AVG_PRICE") Then emsx_avg_price = msg.GetElement("EMSX_AVG_PRICE") Else emsx_avg_price = 0
                    If msg.AsElement.HasElement("EMSX_BROKER") Then emsx_broker = msg.GetElement("EMSX_BROKER") Else emsx_broker = ""
                    If msg.AsElement.HasElement("EMSX_BROKER_COMM") Then emsx_broker_comm = msg.GetElement("EMSX_BROKER_COMM") Else emsx_broker_comm = 0
                    If msg.AsElement.HasElement("EMSX_BSE_AVG_PRICE") Then emsx_bse_avg_price = msg.GetElement("EMSX_BSE_AVG_PRICE") Else emsx_bse_avg_price = 0
                    If msg.AsElement.HasElement("EMSX_BSE_FILLED") Then emsx_bse_filled = msg.GetElement("EMSX_BSE_FILLED") Else emsx_bse_filled = 0
                    If msg.AsElement.HasElement("EMSX_CLEARING_ACCOUNT") Then emsx_clearing_account = msg.GetElement("EMSX_CLEARING_ACCOUNT") Else emsx_clearing_account = ""
                    If msg.AsElement.HasElement("EMSX_CLEARING_FIRM") Then emsx_clearing_firm = msg.GetElement("EMSX_CLEARING_FIRM") Else emsx_clearing_firm = ""
                    If msg.AsElement.HasElement("EMSX_COMM_DIFF_FLAG") Then emsx_comm_diff_flag = msg.GetElement("EMSX_COMM_DIFF_FLAG") Else emsx_comm_diff_flag = ""
                    If msg.AsElement.HasElement("EMSX_COMM_RATE") Then emsx_comm_rate = msg.GetElement("EMSX_COMM_RATE") Else emsx_comm_rate = 0
                    If msg.AsElement.HasElement("EMSX_CURRENCY_PAIR") Then emsx_currency_pair = msg.GetElement("EMSX_CURRENCY_PAIR") Else emsx_currency_pair = ""
                    If msg.AsElement.HasElement("EMSX_CUSTOM_ACCOUNT") Then emsx_custom_account = msg.GetElement("EMSX_CUSTOM_ACCOUNT") Else emsx_custom_account = ""
                    If msg.AsElement.HasElement("EMSX_DAY_AVG_PRICE") Then emsx_day_avg_price = msg.GetElement("EMSX_DAY_AVG_PRICE") Else emsx_day_avg_price = 0
                    If msg.AsElement.HasElement("EMSX_DAY_FILL") Then emsx_day_fill = msg.GetElement("EMSX_DAY_FILL") Else emsx_day_fill = 0
                    If msg.AsElement.HasElement("EMSX_EXCHANGE_DESTINATION") Then emsx_exchange_destination = msg.GetElement("EMSX_EXCHANGE_DESTINATION") Else emsx_exchange_destination = ""
                    If msg.AsElement.HasElement("EMSX_EXEC_INSTRUCTION") Then emsx_exec_instruction = msg.GetElement("EMSX_EXEC_INSTRUCTION") Else emsx_exec_instruction = ""
                    If msg.AsElement.HasElement("EMSX_EXECUTE_BROKER") Then emsx_execute_broker = msg.GetElement("EMSX_EXECUTE_BROKER") Else emsx_execute_broker = ""
                    If msg.AsElement.HasElement("EMSX_FILL_ID") Then emsx_fill_id = msg.GetElement("EMSX_FILL_ID") Else emsx_fill_id = 0
                    If msg.AsElement.HasElement("EMSX_FILLED") Then emsx_filled = msg.GetElement("EMSX_FILLED") Else emsx_filled = 0
                    If msg.AsElement.HasElement("EMSX_GTD_DATE") Then emsx_gtd_date = msg.GetElement("EMSX_GTD_DATE") Else emsx_gtd_date = 0
                    If msg.AsElement.HasElement("EMSX_HAND_INSTRUCTION") Then emsx_hand_instruction = msg.GetElement("EMSX_HAND_INSTRUCTION") Else emsx_hand_instruction = ""
                    If msg.AsElement.HasElement("EMSX_IS_MANUAL_ROUTE") Then emsx_is_manual_route = msg.GetElement("EMSX_IS_MANUAL_ROUTE") Else emsx_is_manual_route = 0
                    If msg.AsElement.HasElement("EMSX_LAST_FILL_DATE") Then emsx_last_fill_date = msg.GetElement("EMSX_LAST_FILL_DATE") Else emsx_last_fill_date = 0
                    If msg.AsElement.HasElement("EMSX_LAST_FILL_TIME") Then emsx_last_fill_time = msg.GetElement("EMSX_LAST_FILL_TIME") Else emsx_last_fill_time = 0
                    If msg.AsElement.HasElement("EMSX_LAST_MARKET") Then emsx_last_market = msg.GetElement("EMSX_LAST_MARKET") Else emsx_last_market = ""
                    If msg.AsElement.HasElement("EMSX_LAST_PRICE") Then emsx_last_price = msg.GetElement("EMSX_LAST_PRICE") Else emsx_last_price = 0
                    If msg.AsElement.HasElement("EMSX_LAST_SHARES") Then emsx_last_shares = msg.GetElement("EMSX_LAST_SHARES") Else emsx_last_shares = 0
                    If msg.AsElement.HasElement("EMSX_LIMIT_PRICE") Then emsx_limit_price = msg.GetElement("EMSX_LIMIT_PRICE") Else emsx_limit_price = 0
                    If msg.AsElement.HasElement("EMSX_MISC_FEES") Then emsx_misc_fees = msg.GetElement("EMSX_MISC_FEES") Else emsx_misc_fees = 0
                    If msg.AsElement.HasElement("EMSX_ML_LEG_QUANTITY") Then emsx_ml_leg_quantity = msg.GetElement("EMSX_ML_LEG_QUANTITY") Else emsx_ml_leg_quantity = 0
                    If msg.AsElement.HasElement("EMSX_ML_NUM_LEGS") Then emsx_ml_num_legs = msg.GetElement("EMSX_ML_NUM_LEGS") Else emsx_ml_num_legs = 0
                    If msg.AsElement.HasElement("EMSX_ML_PERCENT_FILLED") Then emsx_ml_percent_filled = msg.GetElement("EMSX_ML_PERCENT_FILLED") Else emsx_ml_percent_filled = 0
                    If msg.AsElement.HasElement("EMSX_ML_RATIO") Then emsx_ml_ratio = msg.GetElement("EMSX_ML_RATIO") Else emsx_ml_ratio = 0
                    If msg.AsElement.HasElement("EMSX_ML_REMAIN_BALANCE") Then emsx_ml_remain_balance = msg.GetElement("EMSX_ML_REMAIN_BALANCE") Else emsx_ml_remain_balance = 0
                    If msg.AsElement.HasElement("EMSX_ML_STRATEGY") Then emsx_ml_strategy = msg.GetElement("EMSX_ML_STRATEGY") Else emsx_ml_strategy = ""
                    If msg.AsElement.HasElement("EMSX_ML_TOTAL_QUANTITY") Then emsx_ml_total_quantity = msg.GetElement("EMSX_ML_TOTAL_QUANTITY") Else emsx_ml_total_quantity = 0
                    If msg.AsElement.HasElement("EMSX_NOTES") Then emsx_notes = msg.GetElement("EMSX_NOTES") Else emsx_notes = ""
                    If msg.AsElement.HasElement("EMSX_NSE_AVG_PRICE") Then emsx_nse_avg_price = msg.GetElement("EMSX_NSE_AVG_PRICE") Else emsx_nse_avg_price = 0
                    If msg.AsElement.HasElement("EMSX_NSE_FILLED") Then emsx_nse_filled = msg.GetElement("EMSX_NSE_FILLED") Else emsx_nse_filled = 0
                    If msg.AsElement.HasElement("EMSX_ORDER_TYPE") Then emsx_order_type = msg.GetElement("EMSX_ORDER_TYPE") Else emsx_order_type = ""
                    If msg.AsElement.HasElement("EMSX_P_A") Then emsx_p_a = msg.GetElement("EMSX_P_A") Else emsx_p_a = ""
                    If msg.AsElement.HasElement("EMSX_PERCENT_REMAIN") Then emsx_percent_remain = msg.GetElement("EMSX_PERCENT_REMAIN") Else emsx_percent_remain = 0
                    If msg.AsElement.HasElement("EMSX_PRINCIPAL") Then emsx_principal = msg.GetElement("EMSX_PRINCIPAL") Else emsx_principal = 0
                    If msg.AsElement.HasElement("EMSX_QUEUED_DATE") Then emsx_queued_date = msg.GetElement("EMSX_QUEUED_DATE") Else emsx_queued_date = 0
                    If msg.AsElement.HasElement("EMSX_QUEUED_TIME") Then emsx_queued_time = msg.GetElement("EMSX_QUEUED_TIME") Else emsx_queued_time = 0
                    If msg.AsElement.HasElement("EMSX_REASON_CODE") Then emsx_reason_code = msg.GetElement("EMSX_REASON_CODE") Else emsx_reason_code = ""
                    If msg.AsElement.HasElement("EMSX_REASON_DESC") Then emsx_reason_desc = msg.GetElement("EMSX_REASON_DESC") Else emsx_reason_desc = ""
                    If msg.AsElement.HasElement("EMSX_REMAIN_BALANCE") Then emsx_remain_balance = msg.GetElement("EMSX_REMAIN_BALANCE") Else emsx_remain_balance = 0
                    If msg.AsElement.HasElement("EMSX_ROUTE_CREATE_DATE") Then emsx_route_create_date = msg.GetElement("EMSX_ROUTE_CREATE_DATE") Else emsx_route_create_date = 0
                    If msg.AsElement.HasElement("EMSX_ROUTE_CREATE_TIME") Then emsx_route_create_time = msg.GetElement("EMSX_ROUTE_CREATE_TIME") Else emsx_route_create_time = 0
                    If msg.AsElement.HasElement("EMSX_ROUTE_ID") Then emsx_route_id = msg.GetElement("EMSX_ROUTE_ID") Else emsx_route_id = 0
                    If msg.AsElement.HasElement("EMSX_ROUTE_REF_ID") Then emsx_route_ref_id = msg.GetElement("EMSX_ROUTE_REF_ID") Else emsx_route_ref_id = ""
                    If msg.AsElement.HasElement("EMSX_ROUTE_LAST_UPDATE_TIME") Then emsx_route_last_update_time = msg.GetElement("EMSX_ROUTE_LAST_UPDATE_TIME") Else emsx_route_last_update_time = 0
                    If msg.AsElement.HasElement("EMSX_ROUTE_PRICE") Then emsx_route_price = msg.GetElement("EMSX_ROUTE_PRICE") Else emsx_route_price = 0
                    If msg.AsElement.HasElement("EMSX_SEQUENCE") Then emsx_sequence = msg.GetElement("EMSX_SEQUENCE") Else emsx_sequence = 0
                    If msg.AsElement.HasElement("EMSX_SETTLE_AMOUNT") Then emsx_settle_amount = msg.GetElement("EMSX_SETTLE_AMOUNT") Else emsx_settle_amount = 0
                    If msg.AsElement.HasElement("EMSX_SETTLE_DATE") Then emsx_settle_date = msg.GetElement("EMSX_SETTLE_DATE") Else emsx_settle_date = 0
                    If msg.AsElement.HasElement("EMSX_STATUS") Then emsx_status = msg.GetElement("EMSX_STATUS") Else emsx_status = ""
                    If msg.AsElement.HasElement("EMSX_STOP_PRICE") Then emsx_stop_price = msg.GetElement("EMSX_STOP_PRICE") Else emsx_stop_price = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_END_TIME") Then emsx_strategy_end_time = msg.GetElement("EMSX_STRATEGY_END_TIME") Else emsx_strategy_end_time = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_PART_RATE1") Then emsx_strategy_part_rate1 = msg.GetElement("EMSX_STRATEGY_PART_RATE1") Else emsx_strategy_part_rate1 = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_PART_RATE2") Then emsx_strategy_part_rate2 = msg.GetElement("EMSX_STRATEGY_PART_RATE2") Else emsx_strategy_part_rate2 = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_START_TIME") Then emsx_strategy_start_time = msg.GetElement("EMSX_STRATEGY_START_TIME") Else emsx_strategy_start_time = 0
                    If msg.AsElement.HasElement("EMSX_STRATEGY_STYLE") Then emsx_strategy_style = msg.GetElement("EMSX_STRATEGY_STYLE") Else emsx_strategy_style = ""
                    If msg.AsElement.HasElement("EMSX_STRATEGY_TYPE") Then emsx_strategy_type = msg.GetElement("EMSX_STRATEGY_TYPE") Else emsx_strategy_type = ""
                    If msg.AsElement.HasElement("EMSX_TIF") Then emsx_tif = msg.GetElement("EMSX_TIF") Else emsx_tif = ""
                    If msg.AsElement.HasElement("EMSX_TIME_STAMP") Then emsx_time_stamp = msg.GetElement("EMSX_TIME_STAMP") Else emsx_time_stamp = 0
                    If msg.AsElement.HasElement("EMSX_TYPE") Then emsx_type = msg.GetElement("EMSX_TYPE") Else emsx_type = ""
                    If msg.AsElement.HasElement("EMSX_URGENCY_LEVEL") Then emsx_urgency_level = msg.GetElement("EMSX_URGENCY_LEVEL") Else emsx_urgency_level = 0
                    If msg.AsElement.HasElement("EMSX_USER_COMM_AMOUNT") Then emsx_user_comm_amount = msg.GetElement("EMSX_USER_COMM_AMOUNT") Else emsx_user_comm_amount = 0
                    If msg.AsElement.HasElement("EMSX_USER_COMM_RATE") Then emsx_user_comm_rate = msg.GetElement("EMSX_USER_COMM_RATE") Else emsx_user_comm_rate = 0
                    If msg.AsElement.HasElement("EMSX_USER_FEES") Then emsx_user_fees = msg.GetElement("EMSX_USER_FEES") Else emsx_user_fees = 0
                    If msg.AsElement.HasElement("EMSX_USER_NET_MONEY") Then emsx_user_net_money = msg.GetElement("EMSX_USER_NET_MONEY") Else emsx_user_net_money = 0
                    If msg.AsElement.HasElement("EMSX_WORKING") Then emsx_working = msg.GetElement("EMSX_WORKING") Else emsx_working = 0

                    mon "ROUTE >> EMSX_SEQUENCE: " & emsx_sequence & "   EMSX_ROUTE_ID: " & emsx_route_id & "   EMSX_WORKING: " & emsx_working & "    EMSX_FILLED: " & emsx_filled & "    EMSX_STATUS: " & emsx_status

                    'mon "API_SEQ_NUM: " & api_seq_num
                    'mon "EMSX_ACCOUNT: " & emsx_account
                    'mon "EMSX_AMOUNT: " & emsx_amount
                    'mon "EMSX_AVG_PRICE: " & emsx_avg_price
                    'mon "EMSX_BROKER: " & emsx_broker
                    'mon "EMSX_BROKER_COMM: " & emsx_broker_comm
                    'mon "EMSX_BSE_AVG_PRICE: " & emsx_bse_avg_price
                    'mon "EMSX_BSE_FILLED: " & emsx_bse_filled
                    'mon "EMSX_CLEARING_ACCOUNT: " & emsx_clearing_account
                    'mon "EMSX_CLEARING_FIRM: " & emsx_clearing_firm
                    'mon "EMSX_COMM_DIFF_FLAG: " & emsx_comm_diff_flag
                    'mon "EMSX_COMM_RATE: " & emsx_comm_rate
                    'mon "EMSX_CURRENCY_PAIR: " & emsx_currency_pair
                    'mon "EMSX_CUSTOM_ACCOUNT: " & emsx_custom_account
                    'mon "EMSX_DAY_AVG_PRICE: " & emsx_day_avg_price
                    'mon "EMSX_DAY_FILL: " & emsx_day_fill
                    'mon "EMSX_EXCHANGE_DESTINATION: " & emsx_exchange_destination
                    'mon "EMSX_EXEC_INSTRUCTION: " & emsx_exec_instruction
                    'mon "EMSX_EXECUTE_BROKER: " & emsx_execute_broker
                    'mon "EMSX_FILL_ID: " & emsx_fill_id
                    'mon "EMSX_FILLED: " & emsx_filled
                    'mon "EMSX_GTD_DATE: " & emsx_gtd_date
                    'mon "EMSX_HAND_INSTRUCTION: " & emsx_hand_instruction
                    'mon "EMSX_IS_MANUAL_ROUTE: " & emsx_is_manual_route
                    'mon "EMSX_LAST_FILL_DATE: " & emsx_last_fill_date
                    'mon "EMSX_LAST_FILL_TIME: " & emsx_last_fill_time
                    'mon "EMSX_LAST_MARKET: " & emsx_last_market
                    'mon "EMSX_LAST_PRICE: " & emsx_last_price
                    'mon "EMSX_LAST_SHARES: " & emsx_last_shares
                    'mon "EMSX_LIMIT_PRICE: " & emsx_limit_price
                    'mon "EMSX_MISC_FEES: " & emsx_misc_fees
                    'mon "EMSX_ML_LEG_QUANTITY: " & emsx_ml_leg_quantity
                    'mon "EMSX_ML_NUM_LEGS: " & emsx_ml_num_legs
                    'mon "EMSX_ML_PERCENT_FILLED: " & emsx_ml_percent_filled
                    'mon "EMSX_ML_RATIO: " & emsx_ml_ratio
                    'mon "EMSX_ML_REMAIN_BALANCE: " & emsx_ml_remain_balance
                    'mon "EMSX_ML_STRATEGY: " & emsx_ml_strategy
                    'mon "EMSX_ML_TOTAL_QUANTITY: " & emsx_ml_total_quantity
                    'mon "EMSX_NOTES: " & emsx_notes
                    'mon "EMSX_NSE_AVG_PRICE: " & emsx_nse_avg_price
                    'mon "EMSX_NSE_FILLED: " & emsx_nse_filled
                    'mon "EMSX_ORDER_TYPE: " & emsx_order_type
                    'mon "EMSX_P_A: " & emsx_p_a
                    'mon "EMSX_PERCENT_REMAIN: " & emsx_percent_remain
                    'mon "EMSX_PRINCIPAL: " & emsx_principal
                    'mon "EMSX_QUEUED_DATE: " & emsx_queued_date
                    'mon "EMSX_QUEUED_TIME: " & emsx_queued_time
                    'mon "EMSX_REASON_CODE: " & emsx_reason_code
                    'mon "EMSX_REASON_DESC: " & emsx_reason_desc
                    'mon "EMSX_REMAIN_BALANCE: " & emsx_remain_balance
                    'mon "EMSX_ROUTE_CREATE_DATE: " & emsx_route_create_date
                    'mon "EMSX_ROUTE_CREATE_TIME: " & emsx_route_create_time
                    'mon "EMSX_ROUTE_ID: " & emsx_route_id
                    'mon "EMSX_ROUTE_REF_ID: " & emsx_route_ref_id
                    'mon "EMSX_ROUTE_LAST_UPDATE_TIME: " & emsx_route_last_update_time
                    'mon "EMSX_ROUTE_PRICE: " & emsx_route_price
                    'mon "EMSX_SEQUENCE: " & emsx_sequence
                    'mon "EMSX_SETTLE_AMOUNT: " & emsx_settle_amount
                    'mon "EMSX_SETTLE_DATE: " & emsx_settle_date
                    'mon "EMSX_STATUS: " & emsx_status
                    'mon "EMSX_STOP_PRICE: " & emsx_stop_price
                    'mon "EMSX_STRATEGY_END_TIME: " & emsx_strategy_end_time
                    'mon "EMSX_STRATEGY_PART_RATE1: " & emsx_strategy_part_rate1
                    'mon "EMSX_STRATEGY_PART_RATE2: " & emsx_strategy_part_rate2
                    'mon "EMSX_STRATEGY_START_TIME: " & emsx_strategy_start_time
                    'mon "EMSX_STRATEGY_STYLE: " & emsx_strategy_style
                    'mon "EMSX_STRATEGY_TYPE: " & emsx_strategy_type
                    'mon "EMSX_TIF: " & emsx_tif
                    'mon "EMSX_TIME_STAMP: " & emsx_time_stamp
                    'mon "EMSX_TYPE: " & emsx_type
                    'mon "EMSX_URGENCY_LEVEL: " & emsx_urgency_level
                    'mon "EMSX_USER_COMM_AMOUNT: " & emsx_user_comm_amount
                    'mon "EMSX_USER_COMM_RATE: " & emsx_user_comm_rate
                    'mon "EMSX_USER_FEES: " & emsx_user_fees
                    'mon "EMSX_USER_NET_MONEY: " & emsx_user_net_money
                    'mon "EMSX_WORKING: " & emsx_working

                End If
            End If
        Else
            mon "Error: Unexpected message"
        End If
    Loop

    Exit Sub
    
fail:

    mon "Error: " & Err.Description
    Exit Sub
    
End Sub

Private Sub createOrderSubscription()

    mon "Create Order subscription"

    ' Create the topic string for the order subscription. Here, we are subscribing
    ' to every available order field, however, you can subscribe to only the fields
    ' required for your application.
            
    Dim orderTopic As String
    
    orderTopic = emsxService + "/order?fields="
            
    orderTopic = orderTopic + "API_SEQ_NUM,"
    orderTopic = orderTopic + "EMSX_ACCOUNT,"
    orderTopic = orderTopic + "EMSX_AMOUNT,"
    orderTopic = orderTopic + "EMSX_ARRIVAL_PRICE,"
    orderTopic = orderTopic + "EMSX_ASSET_CLASS,"
    orderTopic = orderTopic + "EMSX_ASSIGNED_TRADER,"
    orderTopic = orderTopic + "EMSX_AVG_PRICE,"
    orderTopic = orderTopic + "EMSX_BASKET_NAME,"
    orderTopic = orderTopic + "EMSX_BASKET_NUM,"
    orderTopic = orderTopic + "EMSX_BROKER,"
    orderTopic = orderTopic + "EMSX_BROKER_COMM,"
    orderTopic = orderTopic + "EMSX_BSE_AVG_PRICE,"
    orderTopic = orderTopic + "EMSX_BSE_FILLED,"
    orderTopic = orderTopic + "EMSX_CFD_FLAG,"
    orderTopic = orderTopic + "EMSX_COMM_DIFF_FLAG,"
    orderTopic = orderTopic + "EMSX_COMM_RATE,"
    orderTopic = orderTopic + "EMSX_CURRENCY_PAIR,"
    orderTopic = orderTopic + "EMSX_DATE,"
    orderTopic = orderTopic + "EMSX_DAY_AVG_PRICE,"
    orderTopic = orderTopic + "EMSX_DAY_FILL,"
    orderTopic = orderTopic + "EMSX_DIR_BROKER_FLAG,"
    orderTopic = orderTopic + "EMSX_EXCHANGE,"
    orderTopic = orderTopic + "EMSX_EXCHANGE_DESTINATION,"
    orderTopic = orderTopic + "EMSX_EXEC_INSTRUCTION,"
    orderTopic = orderTopic + "EMSX_FILL_ID,"
    orderTopic = orderTopic + "EMSX_FILLED,"
    orderTopic = orderTopic + "EMSX_GTD_DATE,"
    orderTopic = orderTopic + "EMSX_HAND_INSTRUCTION,"
    orderTopic = orderTopic + "EMSX_IDLE_AMOUNT,"
    orderTopic = orderTopic + "EMSX_INVESTOR_ID,"
    orderTopic = orderTopic + "EMSX_ISIN,"
    orderTopic = orderTopic + "EMSX_LIMIT_PRICE,"
    orderTopic = orderTopic + "EMSX_NOTES,"
    orderTopic = orderTopic + "EMSX_NSE_AVG_PRICE,"
    orderTopic = orderTopic + "EMSX_NSE_FILLED,"
    orderTopic = orderTopic + "EMSX_ORD_REF_ID,"
    orderTopic = orderTopic + "EMSX_ORDER_TYPE,"
    orderTopic = orderTopic + "EMSX_ORIGINATE_TRADER,"
    orderTopic = orderTopic + "EMSX_ORIGINATE_TRADER_FIRM,"
    orderTopic = orderTopic + "EMSX_PERCENT_REMAIN,"
    orderTopic = orderTopic + "EMSX_PM_UUID,"
    orderTopic = orderTopic + "EMSX_PORT_MGR,"
    orderTopic = orderTopic + "EMSX_PORT_NAME,"
    orderTopic = orderTopic + "EMSX_PORT_NUM,"
    orderTopic = orderTopic + "EMSX_POSITION,"
    orderTopic = orderTopic + "EMSX_PRINCIPAL,"
    orderTopic = orderTopic + "EMSX_PRODUCT,"
    orderTopic = orderTopic + "EMSX_QUEUED_DATE,"
    orderTopic = orderTopic + "EMSX_QUEUED_TIME,"
    orderTopic = orderTopic + "EMSX_REASON_CODE,"
    orderTopic = orderTopic + "EMSX_REASON_DESC,"
    orderTopic = orderTopic + "EMSX_REMAIN_BALANCE,"
    orderTopic = orderTopic + "EMSX_ROUTE_ID,"
    orderTopic = orderTopic + "EMSX_ROUTE_PRICE,"
    orderTopic = orderTopic + "EMSX_SEC_NAME,"
    orderTopic = orderTopic + "EMSX_SEDOL,"
    orderTopic = orderTopic + "EMSX_SEQUENCE,"
    orderTopic = orderTopic + "EMSX_SETTLE_AMOUNT,"
    orderTopic = orderTopic + "EMSX_SETTLE_DATE,"
    orderTopic = orderTopic + "EMSX_SIDE,"
    orderTopic = orderTopic + "EMSX_START_AMOUNT,"
    orderTopic = orderTopic + "EMSX_STATUS,"
    orderTopic = orderTopic + "EMSX_STEP_OUT_BROKER,"
    orderTopic = orderTopic + "EMSX_STOP_PRICE,"
    orderTopic = orderTopic + "EMSX_STRATEGY_END_TIME,"
    orderTopic = orderTopic + "EMSX_STRATEGY_PART_RATE1,"
    orderTopic = orderTopic + "EMSX_STRATEGY_PART_RATE2,"
    orderTopic = orderTopic + "EMSX_STRATEGY_START_TIME,"
    orderTopic = orderTopic + "EMSX_STRATEGY_STYLE,"
    orderTopic = orderTopic + "EMSX_STRATEGY_TYPE,"
    orderTopic = orderTopic + "EMSX_TICKER,"
    orderTopic = orderTopic + "EMSX_TIF,"
    orderTopic = orderTopic + "EMSX_TIME_STAMP,"
    orderTopic = orderTopic + "EMSX_TRAD_UUID,"
    orderTopic = orderTopic + "EMSX_TRADE_DESK,"
    orderTopic = orderTopic + "EMSX_TRADER,"
    orderTopic = orderTopic + "EMSX_TRADER_NOTES,"
    orderTopic = orderTopic + "EMSX_TS_ORDNUM,"
    orderTopic = orderTopic + "EMSX_TYPE,"
    orderTopic = orderTopic + "EMSX_UNDERLYING_TICKER,"
    orderTopic = orderTopic + "EMSX_USER_COMM_AMOUNT,"
    orderTopic = orderTopic + "EMSX_USER_COMM_RATE,"
    orderTopic = orderTopic + "EMSX_USER_FEES,"
    orderTopic = orderTopic + "EMSX_USER_NET_MONEY,"
    orderTopic = orderTopic + "EMSX_WORK_PRICE,"
    orderTopic = orderTopic + "EMSX_WORKING,"
    orderTopic = orderTopic + "EMSX_YELLOW_KEY"
    
    'mon "Order Topic: " + orderTopic
    
    Dim subs As blpapicomLib2.SubscriptionList
    
    Set subs = m_BBG_EMSX.CreateSubscriptionList()
    
    Set orderSubscriptionID = m_BBG_EMSX.CreateCorrelationId(98) ' 98 is an arbitrarily selected ID
    subs.AddEx orderTopic, , , orderSubscriptionID
    
    m_BBG_EMSX.Subscribe subs

End Sub

Private Sub createRouteSubscription()

    mon "Create Route subscription"

    ' Create the topic string for the route subscription. Here, we are subscribing
    ' to every available route field, however, you can subscribe to only the fields
    ' required for your application.
            
    Dim routeTopic As String
    
    routeTopic = emsxService + "/route?fields="
    
    routeTopic = routeTopic + "API_SEQ_NUM,"
    routeTopic = routeTopic + "EMSX_ACCOUNT,"
    routeTopic = routeTopic + "EMSX_AMOUNT,"
    routeTopic = routeTopic + "EMSX_AVG_PRICE,"
    routeTopic = routeTopic + "EMSX_BROKER,"
    routeTopic = routeTopic + "EMSX_BROKER_COMM,"
    routeTopic = routeTopic + "EMSX_BSE_AVG_PRICE,"
    routeTopic = routeTopic + "EMSX_BSE_FILLED,"
    routeTopic = routeTopic + "EMSX_CLEARING_ACCOUNT,"
    routeTopic = routeTopic + "EMSX_CLEARING_FIRM,"
    routeTopic = routeTopic + "EMSX_COMM_DIFF_FLAG,"
    routeTopic = routeTopic + "EMSX_COMM_RATE,"
    routeTopic = routeTopic + "EMSX_CURRENCY_PAIR,"
    routeTopic = routeTopic + "EMSX_CUSTOM_ACCOUNT,"
    routeTopic = routeTopic + "EMSX_DAY_AVG_PRICE,"
    routeTopic = routeTopic + "EMSX_DAY_FILL,"
    routeTopic = routeTopic + "EMSX_EXCHANGE_DESTINATION,"
    routeTopic = routeTopic + "EMSX_EXEC_INSTRUCTION,"
    routeTopic = routeTopic + "EMSX_EXECUTE_BROKER,"
    routeTopic = routeTopic + "EMSX_FILL_ID,"
    routeTopic = routeTopic + "EMSX_FILLED,"
    routeTopic = routeTopic + "EMSX_GTD_DATE,"
    routeTopic = routeTopic + "EMSX_HAND_INSTRUCTION,"
    routeTopic = routeTopic + "EMSX_IS_MANUAL_ROUTE,"
    routeTopic = routeTopic + "EMSX_LAST_FILL_DATE,"
    routeTopic = routeTopic + "EMSX_LAST_FILL_TIME,"
    routeTopic = routeTopic + "EMSX_LAST_MARKET,"
    routeTopic = routeTopic + "EMSX_LAST_PRICE,"
    routeTopic = routeTopic + "EMSX_LAST_SHARES,"
    routeTopic = routeTopic + "EMSX_LIMIT_PRICE,"
    routeTopic = routeTopic + "EMSX_MISC_FEES,"
    routeTopic = routeTopic + "EMSX_ML_LEG_QUANTITY,"
    routeTopic = routeTopic + "EMSX_ML_NUM_LEGS,"
    routeTopic = routeTopic + "EMSX_ML_PERCENT_FILLED,"
    routeTopic = routeTopic + "EMSX_ML_RATIO,"
    routeTopic = routeTopic + "EMSX_ML_REMAIN_BALANCE,"
    routeTopic = routeTopic + "EMSX_ML_STRATEGY,"
    routeTopic = routeTopic + "EMSX_ML_TOTAL_QUANTITY,"
    routeTopic = routeTopic + "EMSX_NOTES,"
    routeTopic = routeTopic + "EMSX_NSE_AVG_PRICE,"
    routeTopic = routeTopic + "EMSX_NSE_FILLED,"
    routeTopic = routeTopic + "EMSX_ORDER_TYPE,"
    routeTopic = routeTopic + "EMSX_P_A,"
    routeTopic = routeTopic + "EMSX_PERCENT_REMAIN,"
    routeTopic = routeTopic + "EMSX_PRINCIPAL,"
    routeTopic = routeTopic + "EMSX_QUEUED_DATE,"
    routeTopic = routeTopic + "EMSX_QUEUED_TIME,"
    routeTopic = routeTopic + "EMSX_REASON_CODE,"
    routeTopic = routeTopic + "EMSX_REASON_DESC,"
    routeTopic = routeTopic + "EMSX_REMAIN_BALANCE,"
    routeTopic = routeTopic + "EMSX_ROUTE_CREATE_DATE,"
    routeTopic = routeTopic + "EMSX_ROUTE_CREATE_TIME,"
    routeTopic = routeTopic + "EMSX_ROUTE_ID,"
    routeTopic = routeTopic + "EMSX_ROUTE_REF_ID,"
    routeTopic = routeTopic + "EMSX_ROUTE_LAST_UPDATE_TIME,"
    routeTopic = routeTopic + "EMSX_ROUTE_PRICE,"
    routeTopic = routeTopic + "EMSX_SEQUENCE,"
    routeTopic = routeTopic + "EMSX_SETTLE_AMOUNT,"
    routeTopic = routeTopic + "EMSX_SETTLE_DATE,"
    routeTopic = routeTopic + "EMSX_STATUS,"
    routeTopic = routeTopic + "EMSX_STOP_PRICE,"
    routeTopic = routeTopic + "EMSX_STRATEGY_END_TIME,"
    routeTopic = routeTopic + "EMSX_STRATEGY_PART_RATE1,"
    routeTopic = routeTopic + "EMSX_STRATEGY_PART_RATE2,"
    routeTopic = routeTopic + "EMSX_STRATEGY_START_TIME,"
    routeTopic = routeTopic + "EMSX_STRATEGY_STYLE,"
    routeTopic = routeTopic + "EMSX_STRATEGY_TYPE,"
    routeTopic = routeTopic + "EMSX_TIF,"
    routeTopic = routeTopic + "EMSX_TIME_STAMP,"
    routeTopic = routeTopic + "EMSX_TYPE,"
    routeTopic = routeTopic + "EMSX_URGENCY_LEVEL,"
    routeTopic = routeTopic + "EMSX_USER_COMM_AMOUNT,"
    routeTopic = routeTopic + "EMSX_USER_COMM_RATE,"
    routeTopic = routeTopic + "EMSX_USER_FEES,"
    routeTopic = routeTopic + "EMSX_USER_NET_MONEY,"
    routeTopic = routeTopic + "EMSX_WORKING"

    'mon "Route Topic: " + routeTopic
    
    Dim subs As blpapicomLib2.SubscriptionList
    
    Set subs = m_BBG_EMSX.CreateSubscriptionList()
    
    Set routeSubscriptionID = m_BBG_EMSX.CreateCorrelationId(99) ' 99 is an arbitrarily selected ID
    subs.AddEx routeTopic, , , routeSubscriptionID
    
    m_BBG_EMSX.Subscribe subs

End Sub




