# EMSXSubscriptions.py

import blpapi
import sys


ORDER_ROUTE_FIELDS              = blpapi.Name("OrderRouteFields")

SLOW_CONSUMER_WARNING           = blpapi.Name("SlowConsumerWarning")
SLOW_CONSUMER_WARNING_CLEARED   = blpapi.Name("SlowConsumerWarningCleared")

SESSION_STARTED                 = blpapi.Name("SessionStarted")
SESSION_TERMINATED              = blpapi.Name("SessionTerminated")
SESSION_STARTUP_FAILURE         = blpapi.Name("SessionStartupFailure")
SESSION_CONNECTION_UP           = blpapi.Name("SessionConnectionUp")
SESSION_CONNECTION_DOWN         = blpapi.Name("SessionConnectionDown")

SERVICE_OPENED                  = blpapi.Name("ServiceOpened")
SERVICE_OPEN_FAILURE            = blpapi.Name("ServiceOpenFailure")

SUBSCRIPTION_FAILURE            = blpapi.Name("SubscriptionFailure")
SUBSCRIPTION_STARTED            = blpapi.Name("SubscriptionStarted")
SUBSCRIPTION_TERMINATED         = blpapi.Name("SubscriptionTerminated")

EXCEPTIONS = blpapi.Name("exceptions")
FIELD_ID = blpapi.Name("fieldId")
REASON = blpapi.Name("reason")
CATEGORY = blpapi.Name("category")
DESCRIPTION = blpapi.Name("description")

d_service="//blp/emapisvc_beta"
d_host="localhost"
d_port=8194
orderSubscriptionID=blpapi.CorrelationId(98)
routeSubscriptionID=blpapi.CorrelationId(99)


class SessionEventHandler(object):

    def processEvent(self, event, session):
        try:
            if event.eventType() == blpapi.Event.ADMIN:
                self.processAdminEvent(event)  
                
            elif event.eventType() == blpapi.Event.SESSION_STATUS:
                self.processSessionStatusEvent(event,session)
            
            elif event.eventType() == blpapi.Event.SERVICE_STATUS:
                self.processServiceStatusEvent(event,session)
                
            elif event.eventType() == blpapi.Event.SUBSCRIPTION_STATUS:
                self.processSubscriptionStatusEvent(event, session)

            elif event.eventType() == blpapi.Event.SUBSCRIPTION_DATA:
                self.processSubscriptionDataEvent(event)
            
            else:
                self.processMiscEvents(event)
                
        except:
            print ("Exception:  %s" % sys.exc_info()[0])
            
        return False



    def processAdminEvent(self,event):
        print ("Processing ADMIN event")

        for msg in event:
            
            if msg.messageType() == SLOW_CONSUMER_WARNING:
                print ("Warning: Entered Slow Consumer status")
            elif msg.messageType() ==  SLOW_CONSUMER_WARNING_CLEARED:
                print ("Slow consumer status cleared")
                
 
    def processSessionStatusEvent(self,event,session):
        print ("Processing SESSION_STATUS event")

        for msg in event:
            
            if msg.messageType() == SESSION_STARTED:
                print ("Session started...")
                session.openServiceAsync(d_service)
                
            elif msg.messageType() == SESSION_STARTUP_FAILURE:
                print >> sys.stderr, ("Error: Session startup failed")
                
            elif msg.messageType() == SESSION_TERMINATED:
                print >> sys.stderr, ("Error: Session has been terminated")
                
            elif msg.messageType() == SESSION_CONNECTION_UP:
                print ("Session connection is up")
                
            elif msg.messageType() == SESSION_CONNECTION_DOWN:
                print >> sys.stderr, ("Error: Session connection is down")
                
                

    def processServiceStatusEvent(self,event,session):
        print ("Processing SERVICE_STATUS event")
        
        for msg in event:
            
            if msg.messageType() == SERVICE_OPENED:
                print ("Service opened...")
                self.createOrderSubscription(session)
                
            elif msg.messageType() == SERVICE_OPEN_FAILURE:
                print >> sys.stderr, ("Error: Service failed to open")        
                
                
    def processSubscriptionStatusEvent(self, event, session):
        print ("Processing SUBSCRIPTION_STATUS event")

        for msg in event:
            
            if msg.messageType() == SUBSCRIPTION_STARTED:
                
                print ("OrderSubID: %s\tRouteSubID: %s" % (orderSubscriptionID.value(), routeSubscriptionID.value()))

                if msg.correlationIds()[0].value() == orderSubscriptionID.value():
                    print ("Order subscription started successfully")
                    self.createRouteSubscription(session)
                    
                elif msg.correlationIds()[0].value() == routeSubscriptionID.value():
                    print ("Route subscription started successfully")
                    
            elif msg.messageType() == SUBSCRIPTION_FAILURE:
                print >> sys.stderr, ("Error: Subscription failed")
                print >> sys.stderr, ("MESSAGE: %s" % (msg))
                    
                reason = msg.getElement("reason");
                errorcode = reason.getElementAsInteger("errorCode")
                description = reason.getElementAsString("description")
            
                print >> sys.stdout, ("Error: (%d) %s" % (errorcode, description))                
                
            elif msg.messageType() == SUBSCRIPTION_TERMINATED:
                print >> sys.stderr, ("Error: Subscription terminated")
                print >> sys.stderr, ("MESSAGE: %s" % (msg))


    def processSubscriptionDataEvent(self, event):
        #print ("Processing SUBSCRIPTION_DATA event")
        
        for msg in event:
            
            if msg.messageType() == ORDER_ROUTE_FIELDS:
                
                event_status = msg.getElementAsInteger("EVENT_STATUS")
                
                if event_status == 1:
                
                    if msg.correlationIds()[0].value() == orderSubscriptionID.value():
                        print ("O."),
                    elif msg.correlationIds()[0].value() == routeSubscriptionID.value():
                        print ("R."),
                    
                elif event_status == 11:
                
                    if msg.correlationIds()[0].value() == orderSubscriptionID.value():
                        print ("Order - End of initial paint")
                    elif msg.correlationIds()[0].value() == routeSubscriptionID.value():
                        print ("Route - End of initial paint")

                else:
                    print ("")
                    
                    if msg.correlationIds()[0].value() == orderSubscriptionID.value():
                        
                        api_seq_num = msg.getElementAsInteger("API_SEQ_NUM") if msg.hasElement("API_SEQ_NUM") else 0
                        emsx_account = msg.getElementAsString("EMSX_ACCOUNT") if msg.hasElement("EMSX_ACCOUNT") else ""
                        emsx_amount = msg.getElementAsInteger("EMSX_AMOUNT") if msg.hasElement("EMSX_AMOUNT") else 0
                        emsx_arrival_price = msg.getElementAsFloat("EMSX_ARRIVAL_PRICE") if msg.hasElement("EMSX_ARRIVAL_PRICE") else 0
                        emsx_asset_class = msg.getElementAsString("EMSX_ASSET_CLASS") if msg.hasElement("EMSX_ASSET_CLASS") else ""
                        emsx_assigned_trader = msg.getElementAsString("EMSX_ASSIGNED_TRADER") if msg.hasElement("EMSX_ASSIGNED_TRADER") else ""
                        emsx_avg_price = msg.getElementAsFloat("EMSX_AVG_PRICE") if msg.hasElement("EMSX_AVG_PRICE") else 0
                        emsx_basket_name = msg.getElementAsString("EMSX_BASKET_NAME") if msg.hasElement("EMSX_BASKET_NAME") else ""
                        emsx_basket_num = msg.getElementAsInteger("EMSX_BASKET_NUM") if msg.hasElement("EMSX_BASKET_NUM") else 0
                        emsx_broker = msg.getElementAsString("EMSX_BROKER") if msg.hasElement("EMSX_BROKER") else ""
                        emsx_broker_comm = msg.getElementAsFloat("EMSX_BROKER_COMM") if msg.hasElement("EMSX_BROKER_COMM") else 0
                        emsx_bse_avg_price = msg.getElementAsFloat("EMSX_BSE_AVG_PRICE") if msg.hasElement("EMSX_BSE_AVG_PRICE") else 0
                        emsx_bse_filled = msg.getElementAsInteger("EMSX_BSE_FILLED") if msg.hasElement("EMSX_BSE_FILLED") else 0
                        emsx_cfd_flag = msg.getElementAsString("EMSX_CFD_FLAG") if msg.hasElement("EMSX_CFD_FLAG") else ""
                        emsx_comm_diff_flag = msg.getElementAsString("EMSX_COMM_DIFF_FLAG") if msg.hasElement("EMSX_COMM_DIFF_FLAG") else ""
                        emsx_comm_rate = msg.getElementAsFloat("EMSX_COMM_RATE") if msg.hasElement("EMSX_COMM_RATE") else 0
                        emsx_currency_pair = msg.getElementAsString("EMSX_CURRENCY_PAIR") if msg.hasElement("EMSX_CURRENCY_PAIR") else ""
                        emsx_date = msg.getElementAsInteger("EMSX_DATE") if msg.hasElement("EMSX_DATE") else 0
                        emsx_day_avg_price = msg.getElementAsFloat("EMSX_DAY_AVG_PRICE") if msg.hasElement("EMSX_DAY_AVG_PRICE") else 0
                        emsx_day_fill = msg.getElementAsInteger("EMSX_DAY_FILL") if msg.hasElement("EMSX_DAY_FILL") else 0
                        emsx_dir_broker_flag = msg.getElementAsString("EMSX_DIR_BROKER_FLAG") if msg.hasElement("EMSX_DIR_BROKER_FLAG") else ""
                        emsx_exchange = msg.getElementAsString("EMSX_EXCHANGE") if msg.hasElement("EMSX_EXCHANGE") else ""
                        emsx_exchange_destination = msg.getElementAsString("EMSX_EXCHANGE_DESTINATION") if msg.hasElement("EMSX_EXCHANGE_DESTINATION") else ""
                        emsx_exec_instruction = msg.getElementAsString("EMSX_EXEC_INSTRUCTION") if msg.hasElement("EMSX_EXEC_INSTRUCTION") else ""
                        emsx_fill_id = msg.getElementAsInteger("EMSX_FILL_ID") if msg.hasElement("EMSX_FILL_ID") else 0
                        emsx_filled = msg.getElementAsInteger("EMSX_FILLED") if msg.hasElement("EMSX_FILLED") else 0
                        emsx_gtd_date = msg.getElementAsInteger("EMSX_GTD_DATE") if msg.hasElement("EMSX_GTD_DATE") else 0
                        emsx_hand_instruction = msg.getElementAsString("EMSX_HAND_INSTRUCTION") if msg.hasElement("EMSX_HAND_INSTRUCTION") else ""
                        emsx_idle_amount = msg.getElementAsInteger("EMSX_IDLE_AMOUNT") if msg.hasElement("EMSX_IDLE_AMOUNT") else 0
                        emsx_investor_id = msg.getElementAsString("EMSX_INVESTOR_ID") if msg.hasElement("EMSX_INVESTOR_ID") else ""
                        emsx_isin = msg.getElementAsString("EMSX_ISIN") if msg.hasElement("EMSX_ISIN") else ""
                        emsx_limit_price = msg.getElementAsFloat("EMSX_LIMIT_PRICE") if msg.hasElement("EMSX_LIMIT_PRICE") else 0
                        emsx_notes = msg.getElementAsString("EMSX_NOTES") if msg.hasElement("EMSX_NOTES") else ""
                        emsx_nse_avg_price = msg.getElementAsFloat("EMSX_NSE_AVG_PRICE") if msg.hasElement("EMSX_NSE_AVG_PRICE") else 0
                        emsx_nse_filled = msg.getElementAsInteger("EMSX_NSE_FILLED") if msg.hasElement("EMSX_NSE_FILLED") else 0
                        emsx_ord_ref_id = msg.getElementAsString("EMSX_ORD_REF_ID") if msg.hasElement("EMSX_ORD_REF_ID") else ""
                        emsx_order_type = msg.getElementAsString("EMSX_ORDER_TYPE") if msg.hasElement("EMSX_ORDER_TYPE") else ""
                        emsx_originate_trader = msg.getElementAsString("EMSX_ORIGINATE_TRADER") if msg.hasElement("EMSX_ORIGINATE_TRADER") else ""
                        emsx_originate_trader_firm = msg.getElementAsString("EMSX_ORIGINATE_TRADER_FIRM") if msg.hasElement("EMSX_ORIGINATE_TRADER_FIRM") else ""
                        emsx_percent_remain = msg.getElementAsFloat("EMSX_PERCENT_REMAIN") if msg.hasElement("EMSX_PERCENT_REMAIN") else 0
                        emsx_pm_uuid = msg.getElementAsInteger("EMSX_PM_UUID") if msg.hasElement("EMSX_PM_UUID") else 0
                        emsx_port_mgr = msg.getElementAsString("EMSX_PORT_MGR") if msg.hasElement("EMSX_PORT_MGR") else ""
                        emsx_port_name = msg.getElementAsString("EMSX_PORT_NAME") if msg.hasElement("EMSX_PORT_NAME") else ""
                        emsx_port_num = msg.getElementAsInteger("EMSX_PORT_NUM") if msg.hasElement("EMSX_PORT_NUM") else 0
                        emsx_position = msg.getElementAsString("EMSX_POSITION") if msg.hasElement("EMSX_POSITION") else ""
                        emsx_principle = msg.getElementAsFloat("EMSX_PRINCIPAL") if msg.hasElement("EMSX_PRINCIPAL") else 0
                        emsx_product = msg.getElementAsString("EMSX_PRODUCT") if msg.hasElement("EMSX_PRODUCT") else ""
                        emsx_queued_date = msg.getElementAsInteger("EMSX_QUEUED_DATE") if msg.hasElement("EMSX_QUEUED_DATE") else 0
                        emsx_queued_time = msg.getElementAsInteger("EMSX_QUEUED_TIME") if msg.hasElement("EMSX_QUEUED_TIME") else 0
                        emsx_reason_code = msg.getElementAsString("EMSX_REASON_CODE") if msg.hasElement("EMSX_REASON_CODE") else ""
                        emsx_reason_desc = msg.getElementAsString("EMSX_REASON_DESC") if msg.hasElement("EMSX_REASON_DESC") else ""
                        emsx_remain_balance = msg.getElementAsFloat("EMSX_REMAIN_BALANCE") if msg.hasElement("EMSX_REMAIN_BALANCE") else 0
                        emsx_route_id = msg.getElementAsInteger("EMSX_ROUTE_ID") if msg.hasElement("EMSX_ROUTE_ID") else 0
                        emsx_route_price = msg.getElementAsFloat("EMSX_ROUTE_PRICE") if msg.hasElement("EMSX_ROUTE_PRICE") else 0
                        emsx_sec_name = msg.getElementAsString("EMSX_SEC_NAME") if msg.hasElement("EMSX_SEC_NAME") else ""
                        emsx_sedol = msg.getElementAsString("EMSX_SEDOL") if msg.hasElement("EMSX_SEDOL") else ""
                        emsx_sequence = msg.getElementAsInteger("EMSX_SEQUENCE") if msg.hasElement("EMSX_SEQUENCE") else 0
                        emsx_settle_amount = msg.getElementAsFloat("EMSX_SETTLE_AMOUNT") if msg.hasElement("EMSX_SETTLE_AMOUNT") else 0
                        emsx_settle_date = msg.getElementAsInteger("EMSX_SETTLE_DATE") if msg.hasElement("EMSX_SETTLE_DATE") else 0
                        emsx_side = msg.getElementAsString("EMSX_SIDE") if msg.hasElement("EMSX_SIDE") else ""
                        emsx_start_amount = msg.getElementAsInteger("EMSX_START_AMOUNT") if msg.hasElement("EMSX_START_AMOUNT") else 0
                        emsx_status = msg.getElementAsString("EMSX_STATUS") if msg.hasElement("EMSX_STATUS") else ""
                        emsx_step_out_broker = msg.getElementAsString("EMSX_STEP_OUT_BROKER") if msg.hasElement("EMSX_STEP_OUT_BROKER") else ""
                        emsx_stop_price = msg.getElementAsFloat("EMSX_STOP_PRICE") if msg.hasElement("EMSX_STOP_PRICE") else 0
                        emsx_strategy_end_time = msg.getElementAsInteger("EMSX_STRATEGY_END_TIME") if msg.hasElement("EMSX_STRATEGY_END_TIME") else 0
                        emsx_strategy_part_rate1 = msg.getElementAsFloat("EMSX_STRATEGY_PART_RATE1") if msg.hasElement("EMSX_STRATEGY_PART_RATE1") else 0
                        emsx_strategy_part_rate2 = msg.getElementAsFloat("EMSX_STRATEGY_PART_RATE2") if msg.hasElement("EMSX_STRATEGY_PART_RATE2") else 0
                        emsx_strategy_style = msg.getElementAsString("EMSX_STRATEGY_STYLE") if msg.hasElement("EMSX_STRATEGY_STYLE") else ""
                        emsx_strategy_type = msg.getElementAsString("EMSX_STRATEGY_TYPE") if msg.hasElement("EMSX_STRATEGY_TYPE") else ""
                        emsx_ticker = msg.getElementAsString("EMSX_TICKER") if msg.hasElement("EMSX_TICKER") else ""
                        emsx_tif = msg.getElementAsString("EMSX_TIF") if msg.hasElement("EMSX_TIF") else ""
                        emsx_time_stamp = msg.getElementAsInteger("EMSX_TIME_STAMP") if msg.hasElement("EMSX_TIME_STAMP") else 0
                        emsx_trad_uuid = msg.getElementAsInteger("EMSX_TRAD_UUID") if msg.hasElement("EMSX_TRAD_UUID") else 0
                        emsx_trade_desk = msg.getElementAsString("EMSX_TRADE_DESK") if msg.hasElement("EMSX_TRADE_DESK") else ""
                        emsx_trader = msg.getElementAsString("EMSX_TRADER") if msg.hasElement("EMSX_TRADER") else ""
                        emsx_trader_notes = msg.getElementAsString("EMSX_TRADER_NOTES") if msg.hasElement("EMSX_TRADER_NOTES") else ""
                        emsx_ts_ordnum = msg.getElementAsInteger("EMSX_TS_ORDNUM") if msg.hasElement("EMSX_TS_ORDNUM") else 0
                        emsx_type = msg.getElementAsString("EMSX_TYPE") if msg.hasElement("EMSX_TYPE") else ""
                        emsx_underlying_ticker = msg.getElementAsString("EMSX_UNDERLYING_TICKER") if msg.hasElement("EMSX_UNDERLYING_TICKER") else ""
                        emsx_user_comm_amount = msg.getElementAsFloat("EMSX_USER_COMM_AMOUNT") if msg.hasElement("EMSX_USER_COMM_AMOUNT") else 0
                        emsx_user_comm_rate = msg.getElementAsFloat("EMSX_USER_COMM_RATE") if msg.hasElement("EMSX_USER_COMM_RATE") else 0
                        emsx_user_fees = msg.getElementAsFloat("EMSX_USER_FEES") if msg.hasElement("EMSX_USER_FEES") else 0
                        emsx_user_net_money = msg.getElementAsFloat("EMSX_USER_NET_MONEY") if msg.hasElement("EMSX_USER_NET_MONEY") else 0
                        emsx_user_work_price = msg.getElementAsFloat("EMSX_WORK_PRICE") if msg.hasElement("EMSX_WORK_PRICE") else 0
                        emsx_working = msg.getElementAsInteger("EMSX_WORKING") if msg.hasElement("EMSX_WORKING") else 0
                        emsx_yellow_key = msg.getElementAsString("EMSX_YELLOW_KEY") if msg.hasElement("EMSX_YELLOW_KEY") else ""
                        
                        print ("ORDER MESSAGE: CorrelationID(%d)   Status(%d)" % (msg.correlationIds()[0].value(),event_status))
                        
                        print ("API_SEQ_NUM: %d" % (api_seq_num))
                        print ("EMSX_ACCOUNT: %s" % (emsx_account))
                        print ("EMSX_AMOUNT: %d" % (emsx_amount))
                        print ("EMSX_ARRIVAL_PRICE: %d" % (emsx_arrival_price))
                        print ("EMSX_ASSET_CLASS: %s" % (emsx_asset_class))
                        print ("EMSX_ASSIGNED_TRADER: %s" % (emsx_assigned_trader))
                        print ("EMSX_AVG_PRICE: %d" % (emsx_avg_price))
                        print ("EMSX_BASKET_NAME: %s" % (emsx_basket_name))
                        print ("EMSX_BASKET_NUM: %d" % (emsx_basket_num))
                        print ("EMSX_BROKER: %s" % (emsx_broker))
                        #print ("EMSX_BROKER_COMM: %d" % (emsx_broker_comm))
                        #print ("EMSX_BSE_AVG_PRICE: %d" % (emsx_bse_avg_price))
                        #print ("EMSX_BSE_FILLED: %d" % (emsx_bse_filled))
                        #print ("EMSX_CFD_FLAG: %s" % (emsx_cfd_flag))
                        #print ("EMSX_COMM_DIFF_FLAG: %s" % (emsx_comm_diff_flag))
                        #print ("EMSX_COMM_RATE: %d" % (emsx_comm_rate))
                        #print ("EMSX_CURRENCY_PAIR: %s" % (emsx_currency_pair))
                        #print ("EMSX_DATE: %d" % (emsx_date))
                        #print ("EMSX_DAY_AVG_PRICE: %d" % (emsx_day_avg_price))
                        #print ("EMSX_DAY_FILL: %d" % (emsx_day_fill))
                        #print ("EMSX_DIR_BROKER_FLAG: %s" % (emsx_dir_broker_flag))
                        #print ("EMSX_EXCHANGE: %s" % (emsx_exchange))
                        #print ("EMSX_EXCHANGE_DESTINATION: %s" % (emsx_exchange_destination))
                        print ("EMSX_EXEC_INSTRUCTION: %s" % (emsx_exec_instruction))
                        #print ("EMSX_FILL_ID: %d" % (emsx_fill_id))
                        #print ("EMSX_FILLED: %d" % (emsx_filled))
                        #print ("EMSX_GTD_DATE: %d" % (emsx_gtd_date))
                        #print ("EMSX_HAND_INSTRUCTION: %s" % (emsx_hand_instruction))
                        #print ("EMSX_IDLE_AMOUNT: %d" % (emsx_idle_amount))
                        #print ("EMSX_INVESTOR_ID: %s" % (emsx_investor_id))
                        #print ("EMSX_ISIN: %s" % (emsx_isin))
                        print ("EMSX_LIMIT_PRICE: %0.8f" % (emsx_limit_price))
                        print ("EMSX_NOTES: %s" % (emsx_notes))
                        #print ("EMSX_NSE_AVG_PRICE: %d" % (emsx_nse_avg_price))
                        #print ("EMSX_NSE_FILLED: %d" % (emsx_nse_filled))
                        #print ("EMSX_ORD_REF_ID: %s" % (emsx_ord_ref_id))
                        print ("EMSX_ORDER_TYPE: %s" % (emsx_order_type))
                        #print ("EMSX_ORIGINATE_TRADER: %s" % (emsx_originate_trader))
                        #print ("EMSX_ORIGINATE_TRADER_FIRM: %s" % (emsx_originate_trader_firm))
                        print ("EMSX_PERCENT_REMAIN: %d" % (emsx_percent_remain))
                        #print ("EMSX_PM_UUID: %d" % (emsx_pm_uuid))
                        #print ("EMSX_PORT_MGR: %s" % (emsx_port_mgr))
                        #print ("EMSX_PORT_NAME: %s" % (emsx_port_name))
                        #print ("EMSX_PORT_NUM: %d" % (emsx_port_num))
                        #print ("EMSX_POSITION: %s" % (emsx_position))
                        #print ("EMSX_PRINCIPAL: %d" % (emsx_principle))
                        #print ("EMSX_PRODUCT: %s" % (emsx_product))
                        #print ("EMSX_QUEUED_DATE: %d" % (emsx_queued_date))
                        #print ("EMSX_QUEUED_TIME: %d" % (emsx_queued_time))
                        #print ("EMSX_REASON_CODE: %s" % (emsx_reason_code))
                        #print ("EMSX_REASON_DESC: %s" % (emsx_reason_desc))
                        #print ("EMSX_REMAIN_BALANCE: %d" % (emsx_remain_balance))
                        #print ("EMSX_ROUTE_ID: %d" % (emsx_route_id))
                        #print ("EMSX_ROUTE_PRICE: %d" % (emsx_route_price))
                        #print ("EMSX_SEC_NAME: %s" % (emsx_sec_name))
                        #print ("EMSX_SEDOL: %s" % (emsx_sedol))
                        print ("EMSX_SEQUENCE: %d" % (emsx_sequence))
                        #print ("EMSX_SETTLE_AMOUNT: %d" % (emsx_settle_amount))
                        #print ("EMSX_SETTLE_DATE: %d" % (emsx_settle_date))
                        print ("EMSX_SIDE: %s" % (emsx_side))
                        #print ("EMSX_START_AMOUNT: %d" % (emsx_start_amount))
                        #print ("EMSX_STATUS: %s" % (emsx_status))
                        #print ("EMSX_STEP_OUT_BROKER: %s" % (emsx_step_out_broker))
                        #print ("EMSX_STOP_PRICE: %d" % (emsx_stop_price))
                        #print ("EMSX_STRATEGY_END_TIME: %d" % (emsx_strategy_end_time))
                        #print ("EMSX_STRATEGY_PART_RATE1: %d" % (emsx_strategy_part_rate1))
                        #print ("EMSX_STRATEGY_PART_RATE2: %d" % (emsx_strategy_part_rate2))
                        #print ("EMSX_STRATEGY_STYLE: %s" % (emsx_strategy_style))
                        #print ("EMSX_STRATEGY_TYPE: %s" % (emsx_strategy_type))
                        print ("EMSX_TICKER: %s" % (emsx_ticker))
                        #print ("EMSX_TIF: %s" % (emsx_tif))
                        #print ("EMSX_TIME_STAMP: %d" % (emsx_time_stamp))
                        #print ("EMSX_TRAD_UUID: %d" % (emsx_trad_uuid))
                        #print ("EMSX_TRADE_DESK: %s" % (emsx_trade_desk))
                        print ("EMSX_TRADER: %s" % (emsx_trader))
                        #print ("EMSX_TRADER_NOTES: %s" % (emsx_trader_notes))
                        #print ("EMSX_TS_ORDNUM: %d" % (emsx_ts_ordnum))
                        #print ("EMSX_TYPE: %s" % (emsx_type))
                        #print ("EMSX_UNDERLYING_TICKER: %s" % (emsx_underlying_ticker))
                        #print ("EMSX_USER_COMM_AMOUNT: %d" % (emsx_user_comm_amount))
                        #print ("EMSX_USER_COMM_RATE: %d" % (emsx_user_comm_rate))
                        #print ("EMSX_USER_FEES: %d" % (emsx_user_fees))
                        #print ("EMSX_USER_NET_MONEY: %d" % (emsx_user_net_money))
                        #print ("EMSX_WORK_PRICE: %d" % (emsx_user_work_price))
                        #print ("EMSX_WORKING: %d" % (emsx_working))
                        #print ("EMSX_YELLOW_KEY: %s" % (emsx_yellow_key))
            
                    elif msg.correlationIds()[0].value() == routeSubscriptionID.value():

                        api_seq_num = msg.getElementAsInteger("API_SEQ_NUM") if msg.hasElement("API_SEQ_NUM") else 0
                        emsx_amount = msg.getElementAsInteger("EMSX_AMOUNT") if msg.hasElement("EMSX_AMOUNT") else 0
                        emsx_avg_price = msg.getElementAsFloat("EMSX_AVG_PRICE") if msg.hasElement("EMSX_AVG_PRICE") else 0
                        emsx_broker = msg.getElementAsString("EMSX_BROKER") if msg.hasElement("EMSX_BROKER") else ""
                        emsx_broker_comm = msg.getElementAsFloat("EMSX_BROKER_COMM") if msg.hasElement("EMSX_BROKER_COMM") else 0
                        emsx_bse_avg_price = msg.getElementAsFloat("EMSX_BSE_AVG_PRICE") if msg.hasElement("EMSX_BSE_AVG_PRICE") else 0
                        emsx_bse_filled = msg.getElementAsInteger("EMSX_BSE_FILLED") if msg.hasElement("EMSX_BSE_FILLED") else 0
                        emsx_clearing_account = msg.getElementAsString("EMSX_CLEARING_ACCOUNT") if msg.hasElement("EMSX_CLEARING_ACCOUNT") else ""
                        emsx_clearing_firm = msg.getElementAsString("EMSX_CLEARING_FIRM") if msg.hasElement("EMSX_CLEARING_FIRM") else ""
                        emsx_comm_diff_flag = msg.getElementAsString("EMSX_COMM_DIFF_FLAG") if msg.hasElement("EMSX_COMM_DIFF_FLAG") else ""
                        emsx_comm_rate = msg.getElementAsFloat("EMSX_COMM_RATE") if msg.hasElement("EMSX_COMM_RATE") else 0
                        emsx_currency_pair = msg.getElementAsString("EMSX_CURRENCY_PAIR") if msg.hasElement("EMSX_CURRENCY_PAIR") else ""
                        emsx_custom_account = msg.getElementAsString("EMSX_CUSTOM_ACCOUNT") if msg.hasElement("EMSX_CUSTOM_ACCOUNT") else ""
                        emsx_day_avg_price = msg.getElementAsFloat("EMSX_DAY_AVG_PRICE") if msg.hasElement("EMSX_DAY_AVG_PRICE") else 0
                        emsx_day_fill = msg.getElementAsInteger("EMSX_DAY_FILL") if msg.hasElement("EMSX_DAY_FILL") else 0
                        emsx_exchange_destination = msg.getElementAsString("EMSX_EXCHANGE_DESTINATION") if msg.hasElement("EMSX_EXCHANGE_DESTINATION") else ""
                        emsx_exec_instruction = msg.getElementAsString("EMSX_EXEC_INSTRUCTION") if msg.hasElement("EMSX_EXEC_INSTRUCTION") else ""
                        emsx_execute_broker = msg.getElementAsString("EMSX_EXECUTE_BROKER") if msg.hasElement("EMSX_EXECUTE_BROKER") else ""
                        emsx_fill_id = msg.getElementAsInteger("EMSX_FILL_ID") if msg.hasElement("EMSX_FILL_ID") else 0
                        emsx_filled = msg.getElementAsInteger("EMSX_FILLED") if msg.hasElement("EMSX_FILLED") else 0
                        emsx_gtd_date = msg.getElementAsInteger("EMSX_GTD_DATE") if msg.hasElement("EMSX_GTD_DATE") else 0
                        emsx_hand_instruction = msg.getElementAsString("EMSX_HAND_INSTRUCTION") if msg.hasElement("EMSX_HAND_INSTRUCTION") else ""
                        emsx_is_manual_route = msg.getElementAsInteger("EMSX_IS_MANUAL_ROUTE") if msg.hasElement("EMSX_IS_MANUAL_ROUTE") else 0
                        emsx_last_fill_date = msg.getElementAsInteger("EMSX_LAST_FILL_DATE") if msg.hasElement("EMSX_LAST_FILL_DATE") else 0
                        emsx_last_fill_time = msg.getElementAsInteger("EMSX_LAST_FILL_TIME") if msg.hasElement("EMSX_LAST_FILL_TIME") else 0
                        emsx_last_market = msg.getElementAsString("EMSX_LAST_MARKET") if msg.hasElement("EMSX_LAST_MARKET") else ""
                        emsx_last_price = msg.getElementAsFloat("EMSX_LAST_PRICE") if msg.hasElement("EMSX_LAST_PRICE") else 0
                        emsx_last_shares = msg.getElementAsInteger("EMSX_LAST_SHARES") if msg.hasElement("EMSX_LAST_SHARES") else 0
                        emsx_limit_price = msg.getElementAsFloat("EMSX_LIMIT_PRICE") if msg.hasElement("EMSX_LIMIT_PRICE") else 0
                        emsx_misc_fees = msg.getElementAsFloat("EMSX_MISC_FEES") if msg.hasElement("EMSX_MISC_FEES") else 0
                        emsx_ml_leg_quantity = msg.getElementAsInteger("EMSX_ML_LEG_QUANTITY") if msg.hasElement("EMSX_ML_LEG_QUANTITY") else 0
                        emsx_ml_num_legs = msg.getElementAsInteger("EMSX_ML_NUM_LEGS") if msg.hasElement("EMSX_ML_NUM_LEGS") else 0
                        emsx_ml_percent_filled = msg.getElementAsFloat("EMSX_ML_PERCENT_FILLED") if msg.hasElement("EMSX_ML_PERCENT_FILLED") else 0
                        emsx_ml_ratio = msg.getElementAsFloat("EMSX_ML_RATIO") if msg.hasElement("EMSX_ML_RATIO") else 0
                        emsx_ml_remain_balance = msg.getElementAsFloat("EMSX_ML_REMAIN_BALANCE") if msg.hasElement("EMSX_ML_REMAIN_BALANCE") else 0
                        emsx_ml_strategy = msg.getElementAsString("EMSX_ML_STRATEGY") if msg.hasElement("EMSX_ML_STRATEGY") else ""
                        emsx_ml_total_quantity = msg.getElementAsInteger("EMSX_ML_TOTAL_QUANTITY") if msg.hasElement("EMSX_ML_TOTAL_QUANTITY") else 0
                        emsx_notes = msg.getElementAsString("EMSX_NOTES") if msg.hasElement("EMSX_NOTES") else ""
                        emsx_nse_avg_price = msg.getElementAsFloat("EMSX_NSE_AVG_PRICE") if msg.hasElement("EMSX_NSE_AVG_PRICE") else 0
                        emsx_nse_filled = msg.getElementAsInteger("EMSX_NSE_FILLED") if msg.hasElement("EMSX_NSE_FILLED") else 0
                        emsx_order_type = msg.getElementAsString("EMSX_ORDER_TYPE") if msg.hasElement("EMSX_ORDER_TYPE") else ""
                        emsx_p_a = msg.getElementAsString("EMSX_P_A") if msg.hasElement("EMSX_P_A") else ""
                        emsx_percent_remain = msg.getElementAsFloat("EMSX_PERCENT_REMAIN") if msg.hasElement("EMSX_PERCENT_REMAIN") else 0
                        emsx_principle = msg.getElementAsFloat("EMSX_PRINCIPAL") if msg.hasElement("EMSX_PRINCIPAL") else 0
                        emsx_queued_date = msg.getElementAsInteger("EMSX_QUEUED_DATE") if msg.hasElement("EMSX_QUEUED_DATE") else 0
                        emsx_queued_time = msg.getElementAsInteger("EMSX_QUEUED_TIME") if msg.hasElement("EMSX_QUEUED_TIME") else 0
                        emsx_reason_code = msg.getElementAsString("EMSX_REASON_CODE") if msg.hasElement("EMSX_REASON_CODE") else ""
                        emsx_reason_desc = msg.getElementAsString("EMSX_REASON_DESC") if msg.hasElement("EMSX_REASON_DESC") else ""
                        emsx_remain_balance = msg.getElementAsFloat("EMSX_REMAIN_BALANCE") if msg.hasElement("EMSX_REMAIN_BALANCE") else 0
                        emsx_route_create_date = msg.getElementAsInteger("EMSX_ROUTE_CREATE_DATE") if msg.hasElement("EMSX_ROUTE_CREATE_DATE") else 0
                        emsx_route_create_time = msg.getElementAsInteger("EMSX_ROUTE_CREATE_TIME") if msg.hasElement("EMSX_ROUTE_CREATE_TIME") else 0
                        emsx_route_id = msg.getElementAsInteger("EMSX_ROUTE_ID") if msg.hasElement("EMSX_ROUTE_ID") else 0
                        emsx_route_last_update_time = msg.getElementAsInteger("EMSX_ROUTE_LAST_UPDATE_TIME") if msg.hasElement("EMSX_ROUTE_LAST_UPDATE_TIME") else 0
                        emsx_route_price = msg.getElementAsFloat("EMSX_ROUTE_PRICE") if msg.hasElement("EMSX_ROUTE_PRICE") else 0
                        emsx_sequence = msg.getElementAsInteger("EMSX_SEQUENCE") if msg.hasElement("EMSX_SEQUENCE") else 0
                        emsx_settle_amount = msg.getElementAsFloat("EMSX_SETTLE_AMOUNT") if msg.hasElement("EMSX_SETTLE_AMOUNT") else 0
                        emsx_settle_date = msg.getElementAsInteger("EMSX_SETTLE_DATE") if msg.hasElement("EMSX_SETTLE_DATE") else 0
                        emsx_status = msg.getElementAsString("EMSX_STATUS") if msg.hasElement("EMSX_STATUS") else ""
                        emsx_stop_price = msg.getElementAsFloat("EMSX_STOP_PRICE") if msg.hasElement("EMSX_STOP_PRICE") else 0
                        emsx_strategy_end_time = msg.getElementAsInteger("EMSX_STRATEGY_END_TIME") if msg.hasElement("EMSX_STRATEGY_END_TIME") else 0
                        emsx_strategy_part_rate1 = msg.getElementAsFloat("EMSX_STRATEGY_PART_RATE1") if msg.hasElement("EMSX_STRATEGY_PART_RATE1") else 0
                        emsx_strategy_part_rate2 = msg.getElementAsFloat("EMSX_STRATEGY_PART_RATE2") if msg.hasElement("EMSX_STRATEGY_PART_RATE2") else 0
                        emsx_strategy_start_time = msg.getElementAsInteger("EMSX_STRATEGY_START_TIME") if msg.hasElement("EMSX_STRATEGY_START_TIME") else 0
                        emsx_strategy_style = msg.getElementAsString("EMSX_STRATEGY_STYLE") if msg.hasElement("EMSX_STRATEGY_STYLE") else ""
                        emsx_strategy_type = msg.getElementAsString("EMSX_STRATEGY_TYPE") if msg.hasElement("EMSX_STRATEGY_TYPE") else ""
                        emsx_tif = msg.getElementAsString("EMSX_TIF") if msg.hasElement("EMSX_TIF") else ""
                        emsx_time_stamp = msg.getElementAsInteger("EMSX_TIME_STAMP") if msg.hasElement("EMSX_TIME_STAMP") else 0
                        emsx_type = msg.getElementAsString("EMSX_TYPE") if msg.hasElement("EMSX_TYPE") else ""
                        emsx_urgency_level = msg.getElementAsInteger("EMSX_URGENCY_LEVEL") if msg.hasElement("EMSX_URGENCY_LEVEL") else ""
                        emsx_user_comm_amount = msg.getElementAsFloat("EMSX_USER_COMM_AMOUNT") if msg.hasElement("EMSX_USER_COMM_AMOUNT") else 0
                        emsx_user_comm_rate = msg.getElementAsFloat("EMSX_USER_COMM_RATE") if msg.hasElement("EMSX_USER_COMM_RATE") else 0
                        emsx_user_fees = msg.getElementAsFloat("EMSX_USER_FEES") if msg.hasElement("EMSX_USER_FEES") else 0
                        emsx_user_net_money = msg.getElementAsFloat("EMSX_USER_NET_MONEY") if msg.hasElement("EMSX_USER_NET_MONEY") else 0
                        emsx_working = msg.getElementAsInteger("EMSX_WORKING") if msg.hasElement("EMSX_WORKING") else 0
                        
                        print ("ROUTE MESSAGE: CorrelationID(%d)   Status(%d)" % (msg.correlationIds()[0].value(),event_status))
                        
                        print ("API_SEQ_NUM: %d" % (api_seq_num))
                        print ("EMSX_AMOUNT: %d" % (emsx_amount))
                        print ("EMSX_AVG_PRICE: %d" % (emsx_avg_price))
                        print ("EMSX_BROKER: %s" % (emsx_broker))
                        print ("EMSX_BROKER_COMM: %d" % (emsx_broker_comm))
                        #print ("EMSX_BSE_AVG_PRICE: %d" % (emsx_bse_avg_price))
                        #print ("EMSX_BSE_FILLED: %d" % (emsx_bse_filled))
                        print ("EMSX_CLEARING_ACCOUNT: %s" % (emsx_clearing_account))
                        #print ("EMSX_CLEARING_FIRM: %s" % (emsx_clearing_firm))
                        #print ("EMSX_COMM_DIFF_FLAG: %s" % (emsx_comm_diff_flag))
                        #print ("EMSX_COMM_RATE: %d" % (emsx_comm_rate))
                        print ("EMSX_CURRENCY_PAIR: %s" % (emsx_currency_pair))
                        print ("EMSX_CUSTOM_ACCOUNT: %s" % (emsx_custom_account))
                        print ("EMSX_DAY_AVG_PRICE: %d" % (emsx_day_avg_price))
                        print ("EMSX_DAY_FILL: %d" % (emsx_day_fill))
                        #print ("EMSX_EXCHANGE_DESTINATION: %s" % (emsx_exchange_destination))
                        #print ("EMSX_EXEC_INSTRUCTION: %s" % (emsx_exec_instruction))
                        print ("EMSX_EXECUTE_BROKER: %s" % (emsx_execute_broker))
                        print ("EMSX_FILL_ID: %d" % (emsx_fill_id))
                        print ("EMSX_FILLED: %d" % (emsx_filled))
                        #print ("EMSX_GTD_DATE: %d" % (emsx_gtd_date))
                        print ("EMSX_HAND_INSTRUCTION: %s" % (emsx_hand_instruction))
                        print ("EMSX_IS_MANUAL_ROUTE: %d" % (emsx_is_manual_route))
                        print ("EMSX_LAST_FILL_DATE: %d" % (emsx_last_fill_date))
                        print ("EMSX_LAST_FILL_TIME: %d" % (emsx_last_fill_time))
                        print ("EMSX_LAST_MARKET: %s" % (emsx_last_market))
                        print ("EMSX_LAST_PRICE: %d" % (emsx_last_price))
                        print ("EMSX_LAST_SHARES: %d" % (emsx_last_shares))
                        print ("EMSX_LIMIT_PRICE: %d" % (emsx_limit_price))
                        #print ("EMSX_MISC_FEES: %d" % (emsx_misc_fees))
                        #print ("EMSX_ML_LEG_QUANTITY: %d" % (emsx_ml_leg_quantity))
                        #print ("EMSX_ML_NUM_LEGS: %d" % (emsx_ml_num_legs))
                        #print ("EMSX_ML_PERCENT_FILLED: %d" % (emsx_ml_percent_filled))
                        #print ("EMSX_ML_RATIO: %d" % (emsx_ml_ratio))
                        #print ("EMSX_ML_REMAIN_BALANCE: %d" % (emsx_ml_remain_balance))
                        #print ("EMSX_ML_STRATEGY: %s" % (emsx_ml_strategy))
                        #print ("EMSX_ML_TOTAL_QUANTITY: %d" % (emsx_ml_total_quantity))
                        print ("EMSX_NOTES: %s" % (emsx_notes))
                        #print ("EMSX_NSE_AVG_PRICE: %d" % (emsx_nse_avg_price))
                        #print ("EMSX_NSE_FILLED: %d" % (emsx_nse_filled))
                        print ("EMSX_ORDER_TYPE: %s" % (emsx_order_type))
                        #print ("EMSX_P_A: %s" % (emsx_p_a))
                        print ("EMSX_PERCENT_REMAIN: %d" % (emsx_percent_remain))
                        #print ("EMSX_PRINCIPAL: %d" % (emsx_principle))
                        #print ("EMSX_QUEUED_DATE: %d" % (emsx_queued_date))
                        #print ("EMSX_QUEUED_TIME: %d" % (emsx_queued_time))
                        #print ("EMSX_REASON_CODE: %s" % (emsx_reason_code))
                        #print ("EMSX_REASON_DESC: %s" % (emsx_reason_desc))
                        #print ("EMSX_REMAIN_BALANCE: %d" % (emsx_remain_balance))
                        #print ("EMSX_ROUTE_CREATE_DATE: %d" % (emsx_route_create_date))
                        #print ("EMSX_ROUTE_CREATE_TIME: %d" % (emsx_route_create_time))
                        print ("EMSX_ROUTE_ID: %d" % (emsx_route_id))
                        #print ("EMSX_ROUTE_LAST_UPDATE_TIME: %d" % (emsx_route_last_update_time))
                        #print ("EMSX_ROUTE_PRICE: %d" % (emsx_route_price))
                        #print ("EMSX_SEQUENCE: %d" % (emsx_sequence))
                        #print ("EMSX_SETTLE_AMOUNT: %d" % (emsx_settle_amount))
                        #print ("EMSX_SETTLE_DATE: %d" % (emsx_settle_date))
                        print ("EMSX_STATUS: %s" % (emsx_status))
                        #print ("EMSX_STOP_PRICE: %d" % (emsx_stop_price))
                        #print ("EMSX_STRATEGY_END_TIME: %d" % (emsx_strategy_end_time))
                        #print ("EMSX_STRATEGY_PART_RATE1: %d" % (emsx_strategy_part_rate1))
                        #print ("EMSX_STRATEGY_PART_RATE2: %d" % (emsx_strategy_part_rate2))
                        #print ("EMSX_STRATEGY_START_TIME: %s" % (emsx_strategy_start_time))
                        #print ("EMSX_STRATEGY_STYLE: %s" % (emsx_strategy_style))
                        #print ("EMSX_STRATEGY_TYPE: %s" % (emsx_strategy_type))
                        #print ("EMSX_TIF: %s" % (emsx_tif))
                        #print ("EMSX_TIME_STAMP: %d" % (emsx_time_stamp))
                        #print ("EMSX_TYPE: %s" % (emsx_type))
                        #print ("EMSX_URGENCY_LEVEL: %d" % (emsx_urgency_level))
                        #print ("EMSX_USER_COMM_AMOUNT: %d" % (emsx_user_comm_amount))
                        #print ("EMSX_USER_COMM_RATE: %d" % (emsx_user_comm_rate))
                        #print ("EMSX_USER_FEES: %d" % (emsx_user_fees))
                        #print ("EMSX_USER_NET_MONEY: %d" % (emsx_user_net_money))
                        #print ("EMSX_WORKING: %d" % (emsx_working))

            else:
                print >> sys.stderr, ("Error: Unexpected message")


    def processMiscEvents(self, event):
        
        print ("Processing " + event.eventType() + " event")
        
        for msg in event:

            print ("MESSAGE: %s" % (msg))


    def createOrderSubscription(self, session):
        
        print ("Create Order subscription")
        
        orderTopic = d_service + "/order?fields="
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

        subscriptions = blpapi.SubscriptionList()
        
        subscriptions.add(topic=orderTopic,correlationId=orderSubscriptionID)

        session.subscribe(subscriptions)


    def createRouteSubscription(self, session):
        
        print ("Create Route subscription")
        
        routeTopic = d_service + "/route?fields="
        routeTopic = routeTopic + "API_SEQ_NUM,"
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

        subscriptions = blpapi.SubscriptionList()
        
        subscriptions.add(topic=routeTopic,correlationId=routeSubscriptionID)

        session.subscribe(subscriptions)

def main():

    sessionOptions = blpapi.SessionOptions()
    sessionOptions.setServerHost(d_host)
    sessionOptions.setServerPort(d_port)

    print ("Connecting to %s:%d" % (d_host,d_port))

    eventHandler = SessionEventHandler()

    session = blpapi.Session(sessionOptions, eventHandler.processEvent)
    
    if not session.startAsync():
        print ("Failed to start session.")
        return

    try:
        # Wait for enter key to exit application
        print ("Press ENTER to quit")
        raw_input()
    finally:
        session.stop()

if __name__ == "__main__":
    print ("Bloomberg - EMSX API Example - EMSXSubscriptions")

    try:
        main()
    except KeyboardInterrupt:
        print ("Ctrl+C pressed. Stopping...")

__copyright__ = """
Copyright 2013. Bloomberg Finance L.P.
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:  The above
copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.
"""