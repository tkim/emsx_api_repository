/* Copyright 2013. Bloomberg Finance L.P.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:  The above
 * copyright notice and this permission notice shall be included in all copies
 * or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */
package com.bloomberg.emsx.samples;

import com.bloomberglp.blpapi.CorrelationID;
import com.bloomberglp.blpapi.Event;
import com.bloomberglp.blpapi.EventHandler;
import com.bloomberglp.blpapi.Message;
import com.bloomberglp.blpapi.MessageIterator;
import com.bloomberglp.blpapi.Name;
import com.bloomberglp.blpapi.Session;
import com.bloomberglp.blpapi.SessionOptions;
import com.bloomberglp.blpapi.Subscription;
import com.bloomberglp.blpapi.SubscriptionList;

public class EMSXSubscriptions {
	
    private static final Name 	ORDER_ROUTE_FIELDS = new Name("OrderRouteFields");

	// ADMIN
	private static final Name 	SLOW_CONSUMER_WARNING	= new Name("SlowConsumerWarning");
	private static final Name 	SLOW_CONSUMER_WARNING_CLEARED	= new Name("SlowConsumerWarningCleared");

	// SESSION_STATUS
	private static final Name 	SESSION_STARTED 		= new Name("SessionStarted");
	private static final Name 	SESSION_TERMINATED 		= new Name("SessionTerminated");
	private static final Name 	SESSION_STARTUP_FAILURE = new Name("SessionStartupFailure");
	private static final Name 	SESSION_CONNECTION_UP 	= new Name("SessionConnectionUp");
	private static final Name 	SESSION_CONNECTION_DOWN	= new Name("SessionConnectionDown");

	// SERVICE_STATUS
	private static final Name 	SERVICE_OPENED 			= new Name("ServiceOpened");
	private static final Name 	SERVICE_OPEN_FAILURE 	= new Name("ServiceOpenFailure");

	// SUBSCRIPTION_STATUS + SUBSCRIPTION_DATA
	private static final Name	SUBSCRIPTION_FAILURE 	= new Name("SubscriptionFailure");
	private static final Name	SUBSCRIPTION_STARTED	= new Name("SubscriptionStarted");
	private static final Name	SUBSCRIPTION_TERMINATED	= new Name("SubscriptionTerminated");
	
	private Subscription 		orderSubscription;
	private Subscription 		routeSubscription;
	private CorrelationID		orderSubscriptionID;
	private CorrelationID		routeSubscriptionID;
	
	private String 				d_service;
    private String            	d_host;
    private int               	d_port;
    
    public static void main(String[] args) throws java.lang.Exception
    {
        System.out.println("Bloomberg - EMSX API Example - EMSXSubscriptions");
        System.out.println("Press ENTER at anytime to quit");

        EMSXSubscriptions example = new EMSXSubscriptions();
        example.run(args);

        System.in.read();    
    }
    
    public EMSXSubscriptions()
    {
    
    	// Define the service required, in this case the beta service, 
    	// and the values to be used by the SessionOptions object
    	// to identify IP/port of the back-end process.

    	d_service = "//blp/emapisvc_beta";
    	//d_service = "//blp/emapisvc";
    	d_host = "localhost";
        d_port = 8194;

    }

    private void run(String[] args) throws Exception
    {

        SessionOptions d_sessionOptions = new SessionOptions();
        d_sessionOptions.setServerHost(d_host);
        d_sessionOptions.setServerPort(d_port);

        Session session = new Session(d_sessionOptions, new EMSXEventHandler());
        
        session.startAsync();

    }

    class EMSXEventHandler implements EventHandler
    {
        public void processEvent(Event event, Session session)
        {
            try {
                switch (event.eventType().intValue())
                {                
                case Event.EventType.Constants.ADMIN:
                    processAdminEvent(event, session);
                    break;
                case Event.EventType.Constants.SESSION_STATUS:
                    processSessionEvent(event, session);
                    break;
                case Event.EventType.Constants.SERVICE_STATUS:
                    processServiceEvent(event, session);
                    break;
                case Event.EventType.Constants.SUBSCRIPTION_DATA:
                    processSubscriptionDataEvent(event, session);
                    break;
                case Event.EventType.Constants.SUBSCRIPTION_STATUS:
                    processSubscriptionStatus(event, session);
                    break;
                default:
                    processMiscEvents(event, session);
                    break;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

		private boolean processAdminEvent(Event event, Session session) throws Exception 
		{
            System.out.println("Processing " + event.eventType().toString());
        	MessageIterator msgIter = event.messageIterator();
            while (msgIter.hasNext()) {
                Message msg = msgIter.next();
                if(msg.messageType().equals(SLOW_CONSUMER_WARNING)) {
                	System.err.println("Warning: Entered Slow Consumer status");
                } else if(msg.messageType().equals(SLOW_CONSUMER_WARNING_CLEARED)) {
                	System.out.println("Slow consumer status cleared");
                	return false;
                }
            }
            return true;
		}

		private boolean processSessionEvent(Event event, Session session) throws Exception 
		{
            System.out.println("Processing " + event.eventType().toString());
        	MessageIterator msgIter = event.messageIterator();
            while (msgIter.hasNext()) {
                Message msg = msgIter.next();
                if(msg.messageType().equals(SESSION_STARTED)) {
                	System.out.println("Session started...");
                	session.openServiceAsync(d_service);
                } else if(msg.messageType().equals(SESSION_STARTUP_FAILURE)) {
                	System.err.println("Error: Session startup failed");
                	return false;
                } else if(msg.messageType().equals(SESSION_TERMINATED)) {
                	System.err.println("Session has been terminated");
                	return false;
                } else if(msg.messageType().equals(SESSION_CONNECTION_UP)) {
                	System.out.println("Session connection is up");
                } else if(msg.messageType().equals(SESSION_CONNECTION_DOWN)) {
                	System.err.println("Session connection is down");
                	return false;
                }
            }
            return true;
		}

        private boolean processServiceEvent(Event event, Session session) 
        {
            System.out.println("Processing " + event.eventType().toString());
        	MessageIterator msgIter = event.messageIterator();
            while (msgIter.hasNext()) {
                Message msg = msgIter.next();
                if(msg.messageType().equals(SERVICE_OPENED)) {
                	
                	System.out.println("Service opened...");

                	createOrderSubscription(session);

                } else if(msg.messageType().equals(SERVICE_OPEN_FAILURE)) {
                	System.err.println("Error: Service failed to open");
                	return false;
                }
            }
            return true;
		}

		private boolean processSubscriptionStatus(Event event, Session session) throws Exception 
		{
            System.out.println("Processing " + event.eventType().toString());
            MessageIterator msgIter = event.messageIterator();
            while (msgIter.hasNext()) {
                Message msg = msgIter.next();
                if(msg.messageType().equals(SUBSCRIPTION_STARTED)) {
                	if(msg.correlationID()==orderSubscriptionID) {
                		System.out.println("Order subscription started successfully");
                    	createRouteSubscription(session);
                	} else if(msg.correlationID()==routeSubscriptionID) {
                		System.out.println("Route subscription started successfully");
                	}
                } else if(msg.messageType().equals(SUBSCRIPTION_FAILURE)) {
                	if(msg.correlationID()==orderSubscriptionID) {
                		System.err.println("Error: Order subscription failed");
                	} else if(msg.correlationID()==routeSubscriptionID) {
                		System.err.println("Error: Route subscription failed");
                	}
                    System.out.println("MESSAGE: " + msg);
                	return false;
                } else if(msg.messageType().equals(SUBSCRIPTION_TERMINATED)) {
                	if(msg.correlationID()==orderSubscriptionID) {
                		System.err.println("Order subscription terminated");
                	} else if(msg.correlationID()==routeSubscriptionID) {
                		System.err.println("Route subscription terminated");
                	}
                    System.out.println("MESSAGE: " + msg);
                	return false;
                }
            }
            return true;
        }

        private boolean processSubscriptionDataEvent(Event event, Session session) throws Exception
        {

        	MessageIterator msgIter = event.messageIterator();
            
        	while (msgIter.hasNext()) {
            
        		Message msg = msgIter.next();
                
                // Processing the field values in the subscription data...
                
        		if(msg.messageType().equals(ORDER_ROUTE_FIELDS)) {

        			Integer event_status = msg.getElementAsInt32("EVENT_STATUS");
        			
        			if(event_status==1) {

        				//Heartbeat event, arrives every 1 second of inactivity on a subscription
        				
        				if(msg.correlationID()==orderSubscriptionID) {
        					System.out.print("O."); 
        				} else if(msg.correlationID()==routeSubscriptionID) {
        					System.out.print("R."); 
        				}
        			} else if(event_status==11) {

        				if(msg.correlationID()==orderSubscriptionID) {
        					System.out.println("Order - End of initial paint"); 
        				} else if(msg.correlationID()==routeSubscriptionID) {
        					System.out.println("Route - End of initial paint"); 
        				}
            				
        			} else {

        				System.out.println(""); 

        				if(msg.correlationID()==orderSubscriptionID) {

        					Long api_seq_num = msg.hasElement("API_SEQ_NUM") ? msg.getElementAsInt64("API_SEQ_NUM") : 0;
        					String emsx_account = msg.hasElement("EMSX_ACCOUNT") ? msg.getElementAsString("EMSX_ACCOUNT") : "";
        					Integer emsx_amount = msg.hasElement("EMSX_AMOUNT") ? msg.getElementAsInt32("EMSX_AMOUNT") : 0;
        					Double emsx_arrival_price = msg.hasElement("EMSX_ARRIVAL_PRICE") ? msg.getElementAsFloat64("EMSX_ARRIVAL_PRICE") : 0;
        					String emsx_asset_class = msg.hasElement("EMSX_ASSET_CLASS") ? msg.getElementAsString("EMSX_ASSET_CLASS") : "";
        					String emsx_assigned_trader = msg.hasElement("EMSX_ASSIGNED_TRADER") ? msg.getElementAsString("EMSX_ASSIGNED_TRADER") : "";
        					Double emsx_avg_price = msg.hasElement("EMSX_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_AVG_PRICE") : 0;
        					String emsx_basket_name = msg.hasElement("EMSX_BASKET_NAME") ? msg.getElementAsString("EMSX_BASKET_NAME") : "";
        					Integer emsx_basket_num = msg.hasElement("EMSX_BASKET_NUM") ? msg.getElementAsInt32("EMSX_BASKET_NUM") : 0;
        					String emsx_broker = msg.hasElement("EMSX_BROKER") ? msg.getElementAsString("EMSX_BROKER") : "";
        					Double emsx_broker_comm = msg.hasElement("EMSX_BROKER_COMM") ? msg.getElementAsFloat64("EMSX_BROKER_COMM") : 0;
        					Double emsx_bse_avg_price = msg.hasElement("EMSX_BSE_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_BSE_AVG_PRICE") : 0;
        					Integer emsx_bse_filled = msg.hasElement("EMSX_BSE_FILLED") ? msg.getElementAsInt32("EMSX_BSE_FILLED") : 0;
        					String emsx_cfd_flag = msg.hasElement("EMSX_CFD_FLAG") ? msg.getElementAsString("EMSX_CFD_FLAG") : "";
        					String emsx_comm_diff_flag = msg.hasElement("EMSX_COMM_DIFF_FLAG") ? msg.getElementAsString("EMSX_COMM_DIFF_FLAG") : "";
        					Double emsx_comm_rate = msg.hasElement("EMSX_COMM_RATE") ? msg.getElementAsFloat64("EMSX_COMM_RATE") : 0;
        					String emsx_currency_pair = msg.hasElement("EMSX_CURRENCY_PAIR") ? msg.getElementAsString("EMSX_CURRENCY_PAIR") : "";
        					Integer emsx_date = msg.hasElement("EMSX_DATE") ? msg.getElementAsInt32("EMSX_DATE") : 0;
        					Double emsx_day_avg_price = msg.hasElement("EMSX_DAY_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_DAY_AVG_PRICE") : 0;
        					Integer emsx_day_fill = msg.hasElement("EMSX_DAY_FILL") ? msg.getElementAsInt32("EMSX_DAY_FILL") : 0;
        					String emsx_dir_broker_flag = msg.hasElement("EMSX_DIR_BROKER_FLAG") ? msg.getElementAsString("EMSX_DIR_BROKER_FLAG") : "";
        					String emsx_exchange = msg.hasElement("EMSX_EXCHANGE") ? msg.getElementAsString("EMSX_EXCHANGE") : "";
        					String emsx_exchange_destination = msg.hasElement("EMSX_EXCHANGE_DESTINATION") ? msg.getElementAsString("EMSX_EXCHANGE_DESTINATION") : "";
        					String emsx_exec_instruction = msg.hasElement("EMSX_EXEC_INSTRUCTION") ? msg.getElementAsString("EMSX_EXEC_INSTRUCTION") : "";
        					Integer emsx_fill_id = msg.hasElement("EMSX_FILL_ID") ? msg.getElementAsInt32("EMSX_FILL_ID") : 0;
        					Integer emsx_filled = msg.hasElement("EMSX_FILLED") ? msg.getElementAsInt32("EMSX_FILLED") : 0;
        					Integer emsx_gtd_date = msg.hasElement("EMSX_GTD_DATE") ? msg.getElementAsInt32("EMSX_GTD_DATE") : 0;
        					String emsx_hand_instruction = msg.hasElement("EMSX_HAND_INSTRUCTION") ? msg.getElementAsString("EMSX_HAND_INSTRUCTION") : "";
        					Integer emsx_idle_amount = msg.hasElement("EMSX_IDLE_AMOUNT") ? msg.getElementAsInt32("EMSX_IDLE_AMOUNT") : 0;
        					String emsx_investor_id = msg.hasElement("EMSX_INVESTOR_ID") ? msg.getElementAsString("EMSX_INVESTOR_ID") : "";
        					String emsx_isin = msg.hasElement("EMSX_ISIN") ? msg.getElementAsString("EMSX_ISIN") : "";
        					Double emsx_limit_price = msg.hasElement("EMSX_LIMIT_PRICE") ? msg.getElementAsFloat64("EMSX_LIMIT_PRICE") : 0;
        					String emsx_notes = msg.hasElement("EMSX_NOTES") ? msg.getElementAsString("EMSX_NOTES") : "";
        					Double emsx_nse_avg_price = msg.hasElement("EMSX_NSE_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_NSE_AVG_PRICE") : 0;
        					Integer emsx_nse_filled = msg.hasElement("EMSX_NSE_FILLED") ? msg.getElementAsInt32("EMSX_NSE_FILLED") : 0;
        					String emsx_ord_ref_id = msg.hasElement("EMSX_ORD_REF_ID") ? msg.getElementAsString("EMSX_ORD_REF_ID") : "";
        					String emsx_order_type = msg.hasElement("EMSX_ORDER_TYPE") ? msg.getElementAsString("EMSX_ORDER_TYPE") : "";
        					String emsx_originate_trader = msg.hasElement("EMSX_ORIGINATE_TRADER") ? msg.getElementAsString("EMSX_ORIGINATE_TRADER") : "";
        					String emsx_originate_trader_firm = msg.hasElement("EMSX_ORIGINATE_TRADER_FIRM") ? msg.getElementAsString("EMSX_ORIGINATE_TRADER_FIRM") : "";
        					Double emsx_percent_remain = msg.hasElement("EMSX_PERCENT_REMAIN") ? msg.getElementAsFloat64("EMSX_PERCENT_REMAIN") : 0;
        					Integer emsx_pm_uuid = msg.hasElement("EMSX_PM_UUID") ? msg.getElementAsInt32("EMSX_PM_UUID") : 0;
        					String emsx_port_mgr = msg.hasElement("EMSX_PORT_MGR") ? msg.getElementAsString("EMSX_PORT_MGR") : "";
        					String emsx_port_name = msg.hasElement("EMSX_PORT_NAME") ? msg.getElementAsString("EMSX_PORT_NAME") : "";
        					Integer emsx_port_num = msg.hasElement("EMSX_PORT_NUM") ? msg.getElementAsInt32("EMSX_PORT_NUM") : 0;
        					String emsx_position = msg.hasElement("EMSX_POSITION") ? msg.getElementAsString("EMSX_POSITION") : "";
        					Double emsx_principle = msg.hasElement("EMSX_PRINCIPAL") ? msg.getElementAsFloat64("EMSX_PRINCIPAL") : 0;
        					String emsx_product = msg.hasElement("EMSX_PRODUCT") ? msg.getElementAsString("EMSX_PRODUCT") : "";
        					Integer emsx_queued_date = msg.hasElement("EMSX_QUEUED_DATE") ? msg.getElementAsInt32("EMSX_QUEUED_DATE") : 0;
        					Integer emsx_queued_time = msg.hasElement("EMSX_QUEUED_TIME") ? msg.getElementAsInt32("EMSX_QUEUED_TIME") : 0;
        					String emsx_reason_code = msg.hasElement("EMSX_REASON_CODE") ? msg.getElementAsString("EMSX_REASON_CODE") : "";
        					String emsx_reason_desc = msg.hasElement("EMSX_REASON_DESC") ? msg.getElementAsString("EMSX_REASON_DESC") : "";
        					Double emsx_remain_balance = msg.hasElement("EMSX_REMAIN_BALANCE") ? msg.getElementAsFloat64("EMSX_REMAIN_BALANCE") : 0;
        					Integer emsx_route_id = msg.hasElement("EMSX_ROUTE_ID") ? msg.getElementAsInt32("EMSX_ROUTE_ID") : 0;
        					Double emsx_route_price = msg.hasElement("EMSX_ROUTE_PRICE") ? msg.getElementAsFloat64("EMSX_ROUTE_PRICE") : 0;
        					String emsx_sec_name = msg.hasElement("EMSX_SEC_NAME") ? msg.getElementAsString("EMSX_SEC_NAME") : "";
        					String emsx_sedol = msg.hasElement("EMSX_SEDOL") ? msg.getElementAsString("EMSX_SEDOL") : "";
        					Integer emsx_sequence = msg.hasElement("EMSX_SEQUENCE") ? msg.getElementAsInt32("EMSX_SEQUENCE") : 0;
        					Double emsx_settle_amount = msg.hasElement("EMSX_SETTLE_AMOUNT") ? msg.getElementAsFloat64("EMSX_SETTLE_AMOUNT") : 0;
        					Integer emsx_settle_date = msg.hasElement("EMSX_SETTLE_DATE") ? msg.getElementAsInt32("EMSX_SETTLE_DATE") : 0;
        					String emsx_side = msg.hasElement("EMSX_SIDE") ? msg.getElementAsString("EMSX_SIDE") : "";
        					Integer emsx_start_amount = msg.hasElement("EMSX_START_AMOUNT") ? msg.getElementAsInt32("EMSX_START_AMOUNT") : 0;
        					String emsx_status = msg.hasElement("EMSX_STATUS") ? msg.getElementAsString("EMSX_STATUS") : "";
        					String emsx_step_out_broker = msg.hasElement("EMSX_STEP_OUT_BROKER") ? msg.getElementAsString("EMSX_STEP_OUT_BROKER") : "";
        					Double emsx_stop_price = msg.hasElement("EMSX_STOP_PRICE") ? msg.getElementAsFloat64("EMSX_STOP_PRICE") : 0;
        					Integer emsx_strategy_end_time = msg.hasElement("EMSX_STRATEGY_END_TIME") ? msg.getElementAsInt32("EMSX_STRATEGY_END_TIME") : 0;
        					Double emsx_strategy_part_rate1 = msg.hasElement("EMSX_STRATEGY_PART_RATE1") ? msg.getElementAsFloat64("EMSX_STRATEGY_PART_RATE1") : 0;
        					Double emsx_strategy_part_rate2 = msg.hasElement("EMSX_STRATEGY_PART_RATE2") ? msg.getElementAsFloat64("EMSX_STRATEGY_PART_RATE2") : 0;
        					Integer emsx_strategy_start_time = msg.hasElement("EMSX_STRATEGY_START_TIME") ? msg.getElementAsInt32("EMSX_STRATEGY_START_TIME") : 0;
        					String emsx_strategy_style = msg.hasElement("EMSX_STRATEGY_STYLE") ? msg.getElementAsString("EMSX_STRATEGY_STYLE") : "";
        					String emsx_strategy_type = msg.hasElement("EMSX_STRATEGY_TYPE") ? msg.getElementAsString("EMSX_STRATEGY_TYPE") : "";
        					String emsx_ticker = msg.hasElement("EMSX_TICKER") ? msg.getElementAsString("EMSX_TICKER") : "";
        					String emsx_tif = msg.hasElement("EMSX_TIF") ? msg.getElementAsString("EMSX_TIF") : "";
        					Integer emsx_time_stamp = msg.hasElement("EMSX_TIME_STAMP") ? msg.getElementAsInt32("EMSX_TIME_STAMP") : 0;
        					Integer emsx_trad_uuid = msg.hasElement("EMSX_TRAD_UUID") ? msg.getElementAsInt32("EMSX_TRAD_UUID") : 0;
        					String emsx_trade_desk = msg.hasElement("EMSX_TRADE_DESK") ? msg.getElementAsString("EMSX_TRADE_DESK") : "";
        					String emsx_trader = msg.hasElement("EMSX_TRADER") ? msg.getElementAsString("EMSX_TRADER") : "";
        					String emsx_trader_notes = msg.hasElement("EMSX_TRADER_NOTES") ? msg.getElementAsString("EMSX_TRADER_NOTES") : "";
        					Integer emsx_ts_ordnum = msg.hasElement("EMSX_TS_ORDNUM") ? msg.getElementAsInt32("EMSX_TS_ORDNUM") : 0;
        					String emsx_type = msg.hasElement("EMSX_TYPE") ? msg.getElementAsString("EMSX_TYPE") : "";
        					String emsx_underlying_ticker = msg.hasElement("EMSX_UNDERLYING_TICKER") ? msg.getElementAsString("EMSX_UNDERLYING_TICKER") : "";
        					Double emsx_user_comm_amount = msg.hasElement("EMSX_USER_COMM_AMOUNT") ? msg.getElementAsFloat64("EMSX_USER_COMM_AMOUNT") : 0;
        					Double emsx_user_comm_rate = msg.hasElement("EMSX_USER_COMM_RATE") ? msg.getElementAsFloat64("EMSX_USER_COMM_RATE") : 0;
        					Double emsx_user_fees = msg.hasElement("EMSX_USER_FEES") ? msg.getElementAsFloat64("EMSX_USER_FEES") : 0;
        					Double emsx_user_net_money = msg.hasElement("EMSX_USER_NET_MONEY") ? msg.getElementAsFloat64("EMSX_USER_NET_MONEY") : 0;
        					Double emsx_user_work_price = msg.hasElement("EMSX_WORK_PRICE") ? msg.getElementAsFloat64("EMSX_WORK_PRICE") : 0;
        					Integer emsx_working = msg.hasElement("EMSX_WORKING") ? msg.getElementAsInt32("EMSX_WORKING") : 0;
        					String emsx_yellow_key = msg.hasElement("EMSX_YELLOW_KEY") ? msg.getElementAsString("EMSX_YELLOW_KEY") : "";
        					
        					System.out.println("ORDER MESSAGE: CorrelationID(" + msg.correlationID() + ")  Status(" + event_status + ")");
	                    
        					System.out.println("API_SEQ_NUM: " + api_seq_num);
        					System.out.println("EMSX_ACCOUNT: " + emsx_account);
        					System.out.println("EMSX_AMOUNT: " + emsx_amount);
        					System.out.println("EMSX_ARRIVAL_PRICE: " + emsx_arrival_price);
        					System.out.println("EMSX_ASSET_CLASS: " + emsx_asset_class);
        					System.out.println("EMSX_ASSIGNED_TRADER: " + emsx_assigned_trader);
        					System.out.println("EMSX_AVG_PRICE: " + emsx_avg_price);
        					System.out.println("EMSX_BASKET_NAME: " + emsx_basket_name);
        					System.out.println("EMSX_BASKET_NUM: " + emsx_basket_num);
        					System.out.println("EMSX_BROKER: " + emsx_broker);
        					System.out.println("EMSX_BROKER_COMM: " + emsx_broker_comm);
        					System.out.println("EMSX_BSE_AVG_PRICE: " + emsx_bse_avg_price);
        					System.out.println("EMSX_BSE_FILLED: " + emsx_bse_filled);
        					System.out.println("EMSX_CFD_FLAG: " + emsx_cfd_flag);
        					System.out.println("EMSX_COMM_DIFF_FLAG: " + emsx_comm_diff_flag);
        					System.out.println("EMSX_COMM_RATE: " + emsx_comm_rate);
        					System.out.println("EMSX_CURRENCY_PAIR: " + emsx_currency_pair);
        					System.out.println("EMSX_DATE: " + emsx_date);
        					System.out.println("EMSX_DAY_AVG_PRICE: " + emsx_day_avg_price);
        					System.out.println("EMSX_DAY_FILL: " + emsx_day_fill);
        					System.out.println("EMSX_DIR_BROKER_FLAG: " + emsx_dir_broker_flag);
        					System.out.println("EMSX_EXCHANGE: " + emsx_exchange);
        					System.out.println("EMSX_EXCHANGE_DESTINATION: " + emsx_exchange_destination);
        					System.out.println("EMSX_EXEC_INSTRUCTION: " + emsx_exec_instruction);
        					System.out.println("EMSX_FILL_ID: " + emsx_fill_id);
        					System.out.println("EMSX_FILLED: " + emsx_filled);
        					System.out.println("EMSX_GTD_DATE: " + emsx_gtd_date);
        					System.out.println("EMSX_HAND_INSTRUCTION: " + emsx_hand_instruction);
        					System.out.println("EMSX_IDLE_AMOUNT: " + emsx_idle_amount);
        					System.out.println("EMSX_INVESTOR_ID: " + emsx_investor_id);
        					System.out.println("EMSX_ISIN: " + emsx_isin);
        					System.out.println("EMSX_LIMIT_PRICE: " + emsx_limit_price);
        					System.out.println("EMSX_NOTES: " + emsx_notes);
        					System.out.println("EMSX_NSE_AVG_PRICE: " + emsx_nse_avg_price);
        					System.out.println("EMSX_NSE_FILLED: " + emsx_nse_filled);
        					System.out.println("EMSX_ORD_REF_ID: " + emsx_ord_ref_id);
        					System.out.println("EMSX_ORDER_TYPE: " + emsx_order_type);
        					System.out.println("EMSX_ORIGINATE_TRADER: " + emsx_originate_trader);
        					System.out.println("EMSX_ORIGINATE_TRADER_FIRM: " + emsx_originate_trader_firm);
        					System.out.println("EMSX_PERCENT_REMAIN: " + emsx_percent_remain);
        					System.out.println("EMSX_PM_UUID: " + emsx_pm_uuid);
        					System.out.println("EMSX_PORT_MGR: " + emsx_port_mgr);
        					System.out.println("EMSX_PORT_NAME: " + emsx_port_name);
        					System.out.println("EMSX_PORT_NUM: " + emsx_port_num);
        					System.out.println("EMSX_POSITION: " + emsx_position);
        					System.out.println("EMSX_PRINCIPAL: " + emsx_principle);
        					System.out.println("EMSX_PRODUCT: " + emsx_product);
        					System.out.println("EMSX_QUEUED_DATE: " + emsx_queued_date);
        					System.out.println("EMSX_QUEUED_TIME: " + emsx_queued_time);
        					System.out.println("EMSX_REASON_CODE: " + emsx_reason_code);
        					System.out.println("EMSX_REASON_DESC: " + emsx_reason_desc);
        					System.out.println("EMSX_REMAIN_BALANCE: " + emsx_remain_balance);
        					System.out.println("EMSX_ROUTE_ID: " + emsx_route_id);
        					System.out.println("EMSX_ROUTE_PRICE: " + emsx_route_price);
        					System.out.println("EMSX_SEC_NAME: " + emsx_sec_name);
        					System.out.println("EMSX_SEDOL: " + emsx_sedol);
        					System.out.println("EMSX_SEQUENCE: " + emsx_sequence);
        					System.out.println("EMSX_SETTLE_AMOUNT: " + emsx_settle_amount);
        					System.out.println("EMSX_SETTLE_DATE: " + emsx_settle_date);
        					System.out.println("EMSX_SIDE: " + emsx_side);
        					System.out.println("EMSX_START_AMOUNT: " + emsx_start_amount);
        					System.out.println("EMSX_STATUS: " + emsx_status);
        					System.out.println("EMSX_STEP_OUT_BROKER: " + emsx_step_out_broker);
        					System.out.println("EMSX_STOP_PRICE: " + emsx_stop_price);
        					System.out.println("EMSX_STRATEGY_END_TIME: " + emsx_strategy_end_time);
        					System.out.println("EMSX_STRATEGY_PART_RATE1: " + emsx_strategy_part_rate1);
        					System.out.println("EMSX_STRATEGY_PART_RATE2: " + emsx_strategy_part_rate2);
        					System.out.println("EMSX_STRATEGY_START_TIME: " + emsx_strategy_start_time);
        					System.out.println("EMSX_STRATEGY_STYLE: " + emsx_strategy_style);
        					System.out.println("EMSX_STRATEGY_TYPE: " + emsx_strategy_type);
        					System.out.println("EMSX_TICKER: " + emsx_ticker);
        					System.out.println("EMSX_TIF: " + emsx_tif);
        					System.out.println("EMSX_TIME_STAMP: " + emsx_time_stamp);
        					System.out.println("EMSX_TRAD_UUID: " + emsx_trad_uuid);
        					System.out.println("EMSX_TRADE_DESK: " + emsx_trade_desk);
        					System.out.println("EMSX_TRADER: " + emsx_trader);
        					System.out.println("EMSX_TRADER_NOTES: " + emsx_trader_notes);
        					System.out.println("EMSX_TS_ORDNUM: " + emsx_ts_ordnum);
        					System.out.println("EMSX_TYPE: " + emsx_type);
        					System.out.println("EMSX_UNDERLYING_TICKER: " + emsx_underlying_ticker);
        					System.out.println("EMSX_USER_COMM_AMOUNT: " + emsx_user_comm_amount);
        					System.out.println("EMSX_USER_COMM_RATE: " + emsx_user_comm_rate);
        					System.out.println("EMSX_USER_FEES: " + emsx_user_fees);
        					System.out.println("EMSX_USER_NET_MONEY: " + emsx_user_net_money);
        					System.out.println("EMSX_WORK_PRICE: " + emsx_user_work_price);
        					System.out.println("EMSX_WORKING: " + emsx_working);
        					System.out.println("EMSX_YELLOW_KEY: " + emsx_yellow_key);
        				
        				} else if(msg.correlationID()==routeSubscriptionID) {
    					
            				Long api_seq_num = msg.hasElement("API_SEQ_NUM") ? msg.getElementAsInt64("API_SEQ_NUM") : 0;
    						String emsx_account = msg.hasElement("EMSX_ACCOUNT") ? msg.getElementAsString("EMSX_ACCOUNT") : "";
    						Integer emsx_amount  = msg.hasElement("EMSX_AMOUNT") ? msg.getElementAsInt32("EMSX_AMOUNT") : 0;
    						Double emsx_avg_price = msg.hasElement("EMSX_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_AVG_PRICE") : 0;
    						String emsx_broker = msg.hasElement("EMSX_BROKER") ? msg.getElementAsString("EMSX_BROKER") : "";
    						Double emsx_broker_comm = msg.hasElement("EMSX_BROKER_COMM") ? msg.getElementAsFloat64("EMSX_BROKER_COMM") : 0;
    						Double emsx_bse_avg_price = msg.hasElement("EMSX_BSE_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_BSE_AVG_PRICE") : 0;
    						Integer emsx_bse_filled = msg.hasElement("EMSX_BSE_FILLED") ? msg.getElementAsInt32("EMSX_BSE_FILLED") : 0;
    						String emsx_clearing_account = msg.hasElement("EMSX_CLEARING_ACCOUNT") ? msg.getElementAsString("EMSX_CLEARING_ACCOUNT") : "";
    						String emsx_clearing_firm = msg.hasElement("EMSX_CLEARING_FIRM") ? msg.getElementAsString("EMSX_CLEARING_FIRM") : "";
    						String emsx_comm_diff_flag = msg.hasElement("EMSX_COMM_DIFF_FLAG") ? msg.getElementAsString("EMSX_COMM_DIFF_FLAG") : "";
    						Double emsx_comm_rate = msg.hasElement("EMSX_COMM_RATE") ? msg.getElementAsFloat64("EMSX_COMM_RATE") : 0;
    						String emsx_currency_pair = msg.hasElement("EMSX_CURRENCY_PAIR") ? msg.getElementAsString("EMSX_CURRENCY_PAIR") : "";
    						String emsx_custom_account = msg.hasElement("EMSX_CUSTOM_ACCOUNT") ? msg.getElementAsString("EMSX_CUSTOM_ACCOUNT") : "";
    						Double emsx_day_avg_price = msg.hasElement("EMSX_DAY_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_DAY_AVG_PRICE") : 0;
    						Integer emsx_day_fill = msg.hasElement("EMSX_DAY_FILL") ? msg.getElementAsInt32("EMSX_DAY_FILL") : 0;
    						String emsx_exchange_destination = msg.hasElement("EMSX_EXCHANGE_DESTINATION") ? msg.getElementAsString("EMSX_EXCHANGE_DESTINATION") : "";
    						String emsx_exec_instruction = msg.hasElement("EMSX_EXEC_INSTRUCTION") ? msg.getElementAsString("EMSX_EXEC_INSTRUCTION") : "";
    						String emsx_execute_broker = msg.hasElement("EMSX_EXECUTE_BROKER") ? msg.getElementAsString("EMSX_EXECUTE_BROKER") : "";
    						Integer emsx_fill_id = msg.hasElement("EMSX_FILL_ID") ? msg.getElementAsInt32("EMSX_FILL_ID") : 0;
    						Integer emsx_filled = msg.hasElement("EMSX_FILLED") ? msg.getElementAsInt32("EMSX_FILLED") : 0;
    						Integer emsx_gtd_date = msg.hasElement("EMSX_GTD_DATE") ? msg.getElementAsInt32("EMSX_GTD_DATE") : 0;
    						String emsx_hand_instruction = msg.hasElement("EMSX_HAND_INSTRUCTION") ? msg.getElementAsString("EMSX_HAND_INSTRUCTION") : "";
    						Integer emsx_is_manual_route = msg.hasElement("EMSX_IS_MANUAL_ROUTE") ? msg.getElementAsInt32("EMSX_IS_MANUAL_ROUTE") : 0;
    						Integer emsx_last_fill_date = msg.hasElement("EMSX_LAST_FILL_DATE") ? msg.getElementAsInt32("EMSX_LAST_FILL_DATE") : 0;
    						Integer emsx_last_fill_time = msg.hasElement("EMSX_LAST_FILL_TIME") ? msg.getElementAsInt32("EMSX_LAST_FILL_TIME") : 0;
    						String emsx_last_market = msg.hasElement("EMSX_LAST_MARKET") ? msg.getElementAsString("EMSX_LAST_MARKET") : "";
    						Double emsx_last_price = msg.hasElement("EMSX_LAST_PRICE") ? msg.getElementAsFloat64("EMSX_LAST_PRICE") : 0;
    						Integer emsx_last_shares = msg.hasElement("EMSX_LAST_SHARES") ? msg.getElementAsInt32("EMSX_LAST_SHARES") : 0;
    						Double emsx_limit_price = msg.hasElement("EMSX_LIMIT_PRICE") ? msg.getElementAsFloat64("EMSX_LIMIT_PRICE") : 0;
    						Double emsx_misc_fees = msg.hasElement("EMSX_MISC_FEES") ? msg.getElementAsFloat64("EMSX_MISC_FEES") : 0;
    						Integer emsx_ml_leg_quantity = msg.hasElement("EMSX_ML_LEG_QUANTITY") ? msg.getElementAsInt32("EMSX_ML_LEG_QUANTITY") : 0;
    						Integer emsx_ml_num_legs = msg.hasElement("EMSX_ML_NUM_LEGS") ? msg.getElementAsInt32("EMSX_ML_NUM_LEGS") : 0;
    						Double emsx_ml_percent_filled = msg.hasElement("EMSX_ML_PERCENT_FILLED") ? msg.getElementAsFloat64("EMSX_ML_PERCENT_FILLED") : 0;
    						Double emsx_ml_ratio = msg.hasElement("EMSX_ML_RATIO") ? msg.getElementAsFloat64("EMSX_ML_RATIO") : 0;
    						Double emsx_ml_remain_balance = msg.hasElement("EMSX_ML_REMAIN_BALANCE") ? msg.getElementAsFloat64("EMSX_ML_REMAIN_BALANCE") : 0;
    						String emsx_ml_strategy = msg.hasElement("EMSX_ML_STRATEGY") ? msg.getElementAsString("EMSX_ML_STRATEGY") : "";
    						Integer emsx_ml_total_quantity = msg.hasElement("EMSX_ML_TOTAL_QUANTITY") ? msg.getElementAsInt32("EMSX_ML_TOTAL_QUANTITY") : 0;
    						String emsx_notes = msg.hasElement("EMSX_NOTES") ? msg.getElementAsString("EMSX_NOTES") : "";
    						Double emsx_nse_avg_price = msg.hasElement("EMSX_NSE_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_NSE_AVG_PRICE") : 0;
    						Integer emsx_nse_filled = msg.hasElement("EMSX_NSE_FILLED") ? msg.getElementAsInt32("EMSX_NSE_FILLED") : 0;
    						String emsx_order_type = msg.hasElement("EMSX_ORDER_TYPE") ? msg.getElementAsString("EMSX_ORDER_TYPE") : "";
    						String emsx_p_a = msg.hasElement("EMSX_P_A") ? msg.getElementAsString("EMSX_P_A") : "";
    						Double emsx_percent_remain = msg.hasElement("EMSX_PERCENT_REMAIN") ? msg.getElementAsFloat64("EMSX_PERCENT_REMAIN") : 0;
    						Double emsx_principal = msg.hasElement("EMSX_PRINCIPAL") ? msg.getElementAsFloat64("EMSX_PRINCIPAL") : 0;
    						Integer emsx_queued_date = msg.hasElement("EMSX_QUEUED_DATE") ? msg.getElementAsInt32("EMSX_QUEUED_DATE") : 0;
    						Integer emsx_queued_time = msg.hasElement("EMSX_QUEUED_TIME") ? msg.getElementAsInt32("EMSX_QUEUED_TIME") : 0;
    						String emsx_reason_code = msg.hasElement("EMSX_REASON_CODE") ? msg.getElementAsString("EMSX_REASON_CODE") : "";
    						String emsx_reason_desc = msg.hasElement("EMSX_REASON_DESC") ? msg.getElementAsString("EMSX_REASON_DESC") : "";
    						Double emsx_remain_balance = msg.hasElement("EMSX_REMAIN_BALANCE") ? msg.getElementAsFloat64("EMSX_REMAIN_BALANCE") : 0;
    						Integer emsx_route_create_date = msg.hasElement("EMSX_ROUTE_CREATE_DATE") ? msg.getElementAsInt32("EMSX_ROUTE_CREATE_DATE") : 0;
    						Integer emsx_route_create_time = msg.hasElement("EMSX_ROUTE_CREATE_TIME") ? msg.getElementAsInt32("EMSX_ROUTE_CREATE_TIME") : 0;
    						Integer emsx_route_id = msg.hasElement("EMSX_ROUTE_ID") ? msg.getElementAsInt32("EMSX_ROUTE_ID") : 0;
    						String emsx_route_ref_id = msg.hasElement("EMSX_ROUTE_REF_ID") ? msg.getElementAsString("EMSX_ROUTE_REF_ID") : "";
    						Integer emsx_route_last_update_time = msg.hasElement("EMSX_ROUTE_LAST_UPDATE_TIME") ? msg.getElementAsInt32("EMSX_ROUTE_LAST_UPDATE_TIME") : 0;
    						Double emsx_route_price = msg.hasElement("EMSX_ROUTE_PRICE") ? msg.getElementAsFloat64("EMSX_ROUTE_PRICE") : 0;
    						Integer emsx_sequence = msg.hasElement("EMSX_SEQUENCE") ? msg.getElementAsInt32("EMSX_SEQUENCE") : 0;
    						Double emsx_settle_amount = msg.hasElement("EMSX_SETTLE_AMOUNT") ? msg.getElementAsFloat64("EMSX_SETTLE_AMOUNT") : 0;
    						Integer emsx_settle_date = msg.hasElement("EMSX_SETTLE_DATE") ? msg.getElementAsInt32("EMSX_SETTLE_DATE") : 0;
    						String emsx_status = msg.hasElement("EMSX_STATUS") ? msg.getElementAsString("EMSX_STATUS") : "";
    						Double emsx_stop_price = msg.hasElement("EMSX_STOP_PRICE") ? msg.getElementAsFloat64("EMSX_STOP_PRICE") : 0;
    						Integer emsx_strategy_end_time = msg.hasElement("EMSX_STRATEGY_END_TIME") ? msg.getElementAsInt32("EMSX_STRATEGY_END_TIME") : 0;
    						Double emsx_strategy_part_rate1 = msg.hasElement("EMSX_STRATEGY_PART_RATE1") ? msg.getElementAsFloat64("EMSX_STRATEGY_PART_RATE1") : 0;
    						Double emsx_strategy_part_rate2 = msg.hasElement("EMSX_STRATEGY_PART_RATE2") ? msg.getElementAsFloat64("EMSX_STRATEGY_PART_RATE2") : 0;
    						Integer emsx_strategy_start_time = msg.hasElement("EMSX_STRATEGY_START_TIME") ? msg.getElementAsInt32("EMSX_STRATEGY_START_TIME") : 0;
    						String emsx_strategy_style = msg.hasElement("EMSX_STRATEGY_STYLE") ? msg.getElementAsString("EMSX_STRATEGY_STYLE") : "";
    						String emsx_strategy_type = msg.hasElement("EMSX_STRATEGY_TYPE") ? msg.getElementAsString("EMSX_STRATEGY_TYPE") : "";
    						String emsx_tif = msg.hasElement("EMSX_TIF") ? msg.getElementAsString("EMSX_TIF") : "";
    						Integer emsx_time_stamp = msg.hasElement("EMSX_TIME_STAMP") ? msg.getElementAsInt32("EMSX_TIME_STAMP") : 0;
    						String emsx_type = msg.hasElement("EMSX_TYPE") ? msg.getElementAsString("EMSX_TYPE") : "";
    						Integer emsx_urgency_level = msg.hasElement("EMSX_URGENCY_LEVEL") ? msg.getElementAsInt32("EMSX_URGENCY_LEVEL") : 0;
    						Double emsx_user_comm_amount = msg.hasElement("EMSX_USER_COMM_AMOUNT") ? msg.getElementAsFloat64("EMSX_USER_COMM_AMOUNT") : 0;
    						Double emsx_user_comm_rate = msg.hasElement("EMSX_USER_COMM_RATE") ? msg.getElementAsFloat64("EMSX_USER_COMM_RATE") : 0;
    						Double emsx_user_fees = msg.hasElement("EMSX_USER_FEES") ? msg.getElementAsFloat64("EMSX_USER_FEES") : 0;
    						Double emsx_user_net_money = msg.hasElement("EMSX_USER_NET_MONEY") ? msg.getElementAsFloat64("EMSX_USER_NET_MONEY") : 0;
    						Integer emsx_working = msg.hasElement("EMSX_WORKING") ? msg.getElementAsInt32("EMSX_WORKING") : 0;
            			
    	                    System.out.println("ROUTE MESSAGE: CorrelationID(" + msg.correlationID() + ")  Status(" + event_status + ")");
    	                    
    	                    System.out.println("API_SEQ_NUM: " + api_seq_num);
    	                    System.out.println("EMSX_ACCOUNT: " + emsx_account);
    	                    System.out.println("EMSX_AMOUNT: " + emsx_amount);
    	                    System.out.println("EMSX_AVG_PRICE: " + emsx_avg_price);
    	                    System.out.println("EMSX_BROKER: " + emsx_broker);
    	                    System.out.println("EMSX_BROKER_COMM: " + emsx_broker_comm);
    	                    System.out.println("EMSX_BSE_AVG_PRICE: " + emsx_bse_avg_price);
    	                    System.out.println("EMSX_BSE_FILLED: " + emsx_bse_filled);
    	                    System.out.println("EMSX_CLEARING_ACCOUNT: " + emsx_clearing_account);
    	                    System.out.println("EMSX_CLEARING_FIRM: " + emsx_clearing_firm);
    	                    System.out.println("EMSX_COMM_DIFF_FLAG: " + emsx_comm_diff_flag);
    	                    System.out.println("EMSX_COMM_RATE: " + emsx_comm_rate);
    	                    System.out.println("EMSX_CURRENCY_PAIR: " + emsx_currency_pair);
    	                    System.out.println("EMSX_CUSTOM_ACCOUNT: " + emsx_custom_account);
    	                    System.out.println("EMSX_DAY_AVG_PRICE: " + emsx_day_avg_price);
    	                    System.out.println("EMSX_DAY_FILL: " + emsx_day_fill);
    	                    System.out.println("EMSX_EXCHANGE_DESTINATION: " + emsx_exchange_destination);
    	                    System.out.println("EMSX_EXEC_INSTRUCTION: " + emsx_exec_instruction);
    	                    System.out.println("EMSX_EXECUTE_BROKER: " + emsx_execute_broker);
    	                    System.out.println("EMSX_FILL_ID: " + emsx_fill_id);
    	                    System.out.println("EMSX_FILLED: " + emsx_filled);
    	                    System.out.println("EMSX_GTD_DATE: " + emsx_gtd_date);
    	                    System.out.println("EMSX_HAND_INSTRUCTION: " + emsx_hand_instruction);
    	                    System.out.println("EMSX_IS_MANUAL_ROUTE: " + emsx_is_manual_route);
    	                    System.out.println("EMSX_LAST_FILL_DATE: " + emsx_last_fill_date);
    	                    System.out.println("EMSX_LAST_FILL_TIME: " + emsx_last_fill_time);
    	                    System.out.println("EMSX_LAST_MARKET: " + emsx_last_market);
    	                    System.out.println("EMSX_LAST_PRICE: " + emsx_last_price);
    	                    System.out.println("EMSX_LAST_SHARES: " + emsx_last_shares);
    	                    System.out.println("EMSX_LIMIT_PRICE: " + emsx_limit_price);
    	                    System.out.println("EMSX_MISC_FEES: " + emsx_misc_fees);
    	                    System.out.println("EMSX_ML_LEG_QUANTITY: " + emsx_ml_leg_quantity);
    	                    System.out.println("EMSX_ML_NUM_LEGS: " + emsx_ml_num_legs);
    	                    System.out.println("EMSX_ML_PERCENT_FILLED: " + emsx_ml_percent_filled);
    	                    System.out.println("EMSX_ML_RATIO: " + emsx_ml_ratio);
    	                    System.out.println("EMSX_ML_REMAIN_BALANCE: " + emsx_ml_remain_balance);
    	                    System.out.println("EMSX_ML_STRATEGY: " + emsx_ml_strategy);
    	                    System.out.println("EMSX_ML_TOTAL_QUANTITY: " + emsx_ml_total_quantity);
    	                    System.out.println("EMSX_NOTES: " + emsx_notes);
    	                    System.out.println("EMSX_NSE_AVG_PRICE: " + emsx_nse_avg_price);
    	                    System.out.println("EMSX_NSE_FILLED: " + emsx_nse_filled);
    	                    System.out.println("EMSX_ORDER_TYPE: " + emsx_order_type);
    	                    System.out.println("EMSX_P_A: " + emsx_p_a);
    	                    System.out.println("EMSX_PERCENT_REMAIN: " + emsx_percent_remain);
    	                    System.out.println("EMSX_PRINCIPAL: " + emsx_principal);
    	                    System.out.println("EMSX_QUEUED_DATE: " + emsx_queued_date);
    	                    System.out.println("EMSX_QUEUED_TIME: " + emsx_queued_time);
    	                    System.out.println("EMSX_REASON_CODE: " + emsx_reason_code);
    	                    System.out.println("EMSX_REASON_DESC: " + emsx_reason_desc);
    	                    System.out.println("EMSX_REMAIN_BALANCE: " + emsx_remain_balance);
    	                    System.out.println("EMSX_ROUTE_CREATE_DATE: " + emsx_route_create_date);
    	                    System.out.println("EMSX_ROUTE_CREATE_TIME: " + emsx_route_create_time);
    	                    System.out.println("EMSX_ROUTE_ID: " + emsx_route_id);
    	                    System.out.println("EMSX_ROUTE_REF_ID: " + emsx_route_ref_id);
    	                    System.out.println("EMSX_ROUTE_LAST_UPDATE_TIME: " + emsx_route_last_update_time);
    	                    System.out.println("EMSX_ROUTE_PRICE: " + emsx_route_price);
    	                    System.out.println("EMSX_SEQUENCE: " + emsx_sequence);
    	                    System.out.println("EMSX_SETTLE_AMOUNT: " + emsx_settle_amount);
    	                    System.out.println("EMSX_SETTLE_DATE: " + emsx_settle_date);
    	                    System.out.println("EMSX_STATUS: " + emsx_status);
    	                    System.out.println("EMSX_STOP_PRICE: " + emsx_stop_price);
    	                    System.out.println("EMSX_STRATEGY_END_TIME: " + emsx_strategy_end_time);
    	                    System.out.println("EMSX_STRATEGY_PART_RATE1: " + emsx_strategy_part_rate1);
    	                    System.out.println("EMSX_STRATEGY_PART_RATE2: " + emsx_strategy_part_rate2);
    	                    System.out.println("EMSX_STRATEGY_START_TIME: " + emsx_strategy_start_time);
    	                    System.out.println("EMSX_STRATEGY_STYLE: " + emsx_strategy_style);
    	                    System.out.println("EMSX_STRATEGY_TYPE: " + emsx_strategy_type);
    	                    System.out.println("EMSX_TIF: " + emsx_tif);
    	                    System.out.println("EMSX_TIME_STAMP: " + emsx_time_stamp);
    	                    System.out.println("EMSX_TYPE: " + emsx_type);
    	                    System.out.println("EMSX_URGENCY_LEVEL: " + emsx_urgency_level);
    	                    System.out.println("EMSX_USER_COMM_AMOUNT: " + emsx_user_comm_amount);
    	                    System.out.println("EMSX_USER_COMM_RATE: " + emsx_user_comm_rate);
    	                    System.out.println("EMSX_USER_FEES: " + emsx_user_fees);
    	                    System.out.println("EMSX_USER_NET_MONEY: " + emsx_user_net_money);
    	                    System.out.println("EMSX_WORKING: " + emsx_working);

        				}
        			}
        			
        		} else {
        			System.err.println("Error: Unexpected message");
        		}
                
            }
            return true;
        }

        private boolean processMiscEvents(Event event, Session session) throws Exception 
        {
            System.out.println("Processing " + event.eventType().toString());
            MessageIterator msgIter = event.messageIterator();
            while (msgIter.hasNext()) {
                Message msg = msgIter.next();
                System.out.println("MESSAGE: " + msg);
            }
            return true;
        }
        
        private void createOrderSubscription(Session session) 
        {
        	System.out.println("Create Order subscription");

        	// Create the topic string for the order subscription. Here, we are subscribing 
            // to every available order field, however, you can subscribe to only the fields
            // required for your application.
        	String orderTopic = d_service + "/order?fields=";
    		
    		orderTopic = orderTopic + "API_SEQ_NUM,";
    		orderTopic = orderTopic + "EMSX_ACCOUNT,";
    		orderTopic = orderTopic + "EMSX_AMOUNT,";
    		orderTopic = orderTopic + "EMSX_ARRIVAL_PRICE,";
    		orderTopic = orderTopic + "EMSX_ASSET_CLASS,";
    		orderTopic = orderTopic + "EMSX_ASSIGNED_TRADER,";
    		orderTopic = orderTopic + "EMSX_AVG_PRICE,";
    		orderTopic = orderTopic + "EMSX_BASKET_NAME,";
    		orderTopic = orderTopic + "EMSX_BASKET_NUM,";
    		orderTopic = orderTopic + "EMSX_BROKER,";
    		orderTopic = orderTopic + "EMSX_BROKER_COMM,";
    		orderTopic = orderTopic + "EMSX_BSE_AVG_PRICE,";
    		orderTopic = orderTopic + "EMSX_BSE_FILLED,";
    		orderTopic = orderTopic + "EMSX_CFD_FLAG,";
    		orderTopic = orderTopic + "EMSX_COMM_DIFF_FLAG,";
    		orderTopic = orderTopic + "EMSX_COMM_RATE,";
    		orderTopic = orderTopic + "EMSX_CURRENCY_PAIR,";
    		orderTopic = orderTopic + "EMSX_DATE,";
    		orderTopic = orderTopic + "EMSX_DAY_AVG_PRICE,";
    		orderTopic = orderTopic + "EMSX_DAY_FILL,";
    		orderTopic = orderTopic + "EMSX_DIR_BROKER_FLAG,";
    		orderTopic = orderTopic + "EMSX_EXCHANGE,";
    		orderTopic = orderTopic + "EMSX_EXCHANGE_DESTINATION,";
    		orderTopic = orderTopic + "EMSX_EXEC_INSTRUCTION,";
    		orderTopic = orderTopic + "EMSX_FILL_ID,";
    		orderTopic = orderTopic + "EMSX_FILLED,";
    		orderTopic = orderTopic + "EMSX_GTD_DATE,";
    		orderTopic = orderTopic + "EMSX_HAND_INSTRUCTION,";
    		orderTopic = orderTopic + "EMSX_IDLE_AMOUNT,";
    		orderTopic = orderTopic + "EMSX_INVESTOR_ID,";
    		orderTopic = orderTopic + "EMSX_ISIN,";
    		orderTopic = orderTopic + "EMSX_LIMIT_PRICE,";
    		orderTopic = orderTopic + "EMSX_NOTES,";
    		orderTopic = orderTopic + "EMSX_NSE_AVG_PRICE,";
    		orderTopic = orderTopic + "EMSX_NSE_FILLED,";
    		orderTopic = orderTopic + "EMSX_ORD_REF_ID,";
    		orderTopic = orderTopic + "EMSX_ORDER_TYPE,";
    		orderTopic = orderTopic + "EMSX_ORIGINATE_TRADER,";
    		orderTopic = orderTopic + "EMSX_ORIGINATE_TRADER_FIRM,";
    		orderTopic = orderTopic + "EMSX_PERCENT_REMAIN,";
    		orderTopic = orderTopic + "EMSX_PM_UUID,";
    		orderTopic = orderTopic + "EMSX_PORT_MGR,";
    		orderTopic = orderTopic + "EMSX_PORT_NAME,";
    		orderTopic = orderTopic + "EMSX_PORT_NUM,";
    		orderTopic = orderTopic + "EMSX_POSITION,";
    		orderTopic = orderTopic + "EMSX_PRINCIPAL,";
    		orderTopic = orderTopic + "EMSX_PRODUCT,";
    		orderTopic = orderTopic + "EMSX_QUEUED_DATE,";
    		orderTopic = orderTopic + "EMSX_QUEUED_TIME,";
    		orderTopic = orderTopic + "EMSX_REASON_CODE,";
    		orderTopic = orderTopic + "EMSX_REASON_DESC,";
    		orderTopic = orderTopic + "EMSX_REMAIN_BALANCE,";
    		orderTopic = orderTopic + "EMSX_ROUTE_ID,";
    		orderTopic = orderTopic + "EMSX_ROUTE_PRICE,";
    		orderTopic = orderTopic + "EMSX_SEC_NAME,";
    		orderTopic = orderTopic + "EMSX_SEDOL,";
    		orderTopic = orderTopic + "EMSX_SEQUENCE,";
    		orderTopic = orderTopic + "EMSX_SETTLE_AMOUNT,";
    		orderTopic = orderTopic + "EMSX_SETTLE_DATE,";
    		orderTopic = orderTopic + "EMSX_SIDE,";
    		orderTopic = orderTopic + "EMSX_START_AMOUNT,";
    		orderTopic = orderTopic + "EMSX_STATUS,";
    		orderTopic = orderTopic + "EMSX_STEP_OUT_BROKER,";
    		orderTopic = orderTopic + "EMSX_STOP_PRICE,";
    		orderTopic = orderTopic + "EMSX_STRATEGY_END_TIME,";
    		orderTopic = orderTopic + "EMSX_STRATEGY_PART_RATE1,";
    		orderTopic = orderTopic + "EMSX_STRATEGY_PART_RATE2,";
    		orderTopic = orderTopic + "EMSX_STRATEGY_START_TIME,";
    		orderTopic = orderTopic + "EMSX_STRATEGY_STYLE,";
    		orderTopic = orderTopic + "EMSX_STRATEGY_TYPE,";
    		orderTopic = orderTopic + "EMSX_TICKER,";
    		orderTopic = orderTopic + "EMSX_TIF,";
    		orderTopic = orderTopic + "EMSX_TIME_STAMP,";
    		orderTopic = orderTopic + "EMSX_TRAD_UUID,";
    		orderTopic = orderTopic + "EMSX_TRADE_DESK,";
    		orderTopic = orderTopic + "EMSX_TRADER,";
    		orderTopic = orderTopic + "EMSX_TRADER_NOTES,";
    		orderTopic = orderTopic + "EMSX_TS_ORDNUM,";
    		orderTopic = orderTopic + "EMSX_TYPE,";
    		orderTopic = orderTopic + "EMSX_UNDERLYING_TICKER,";
    		orderTopic = orderTopic + "EMSX_USER_COMM_AMOUNT,";
    		orderTopic = orderTopic + "EMSX_USER_COMM_RATE,";
    		orderTopic = orderTopic + "EMSX_USER_FEES,";
    		orderTopic = orderTopic + "EMSX_USER_NET_MONEY,";
    		orderTopic = orderTopic + "EMSX_WORK_PRICE,";
    		orderTopic = orderTopic + "EMSX_WORKING,";
    		orderTopic = orderTopic + "EMSX_YELLOW_KEY";

    		// We define a correlation ID that allows us to identify the original
    		// request when we examine the events. This is useful in situations where
    		// the same event handler is used the process messages for the Order and Route 
    		// subscriptions, as well as request/response requests.
    		orderSubscriptionID = new CorrelationID();
        	
        	orderSubscription = new Subscription(orderTopic,orderSubscriptionID);
        	System.out.println("Order Topic: " + orderTopic);
        	SubscriptionList subscriptions = new SubscriptionList();
        	subscriptions.add(orderSubscription);

        	try {
        		session.subscribe(subscriptions);
        	} catch (Exception ex) {
        		System.err.println("Failed to create Order subscription");
        	}
        	
        }
        
        private void createRouteSubscription(Session session)
        {
        	System.out.println("Create Route subscription");

        	// Create the topic string for the route subscription. Here, we are subscribing 
            // to every available route field, however, you can subscribe to only the fields
            // required for your application.
        	String routeTopic = d_service + "/route?fields=";
    		
    		routeTopic = routeTopic + "API_SEQ_NUM,";
    		routeTopic = routeTopic + "EMSX_ACCOUNT,";
    		routeTopic = routeTopic + "EMSX_AMOUNT,";
    		routeTopic = routeTopic + "EMSX_AVG_PRICE,";
    		routeTopic = routeTopic + "EMSX_BROKER,";
    		routeTopic = routeTopic + "EMSX_BROKER_COMM,";
    		routeTopic = routeTopic + "EMSX_BSE_AVG_PRICE,";
    		routeTopic = routeTopic + "EMSX_BSE_FILLED,";
    		routeTopic = routeTopic + "EMSX_CLEARING_ACCOUNT,";
    		routeTopic = routeTopic + "EMSX_CLEARING_FIRM,";
    		routeTopic = routeTopic + "EMSX_COMM_DIFF_FLAG,";
    		routeTopic = routeTopic + "EMSX_COMM_RATE,";
    		routeTopic = routeTopic + "EMSX_CURRENCY_PAIR,";
    		routeTopic = routeTopic + "EMSX_CUSTOM_ACCOUNT,";
    		routeTopic = routeTopic + "EMSX_DAY_AVG_PRICE,";
    		routeTopic = routeTopic + "EMSX_DAY_FILL,";
    		routeTopic = routeTopic + "EMSX_EXCHANGE_DESTINATION,";
    		routeTopic = routeTopic + "EMSX_EXEC_INSTRUCTION,";
    		routeTopic = routeTopic + "EMSX_EXECUTE_BROKER,";
    		routeTopic = routeTopic + "EMSX_FILL_ID,";
    		routeTopic = routeTopic + "EMSX_FILLED,";
    		routeTopic = routeTopic + "EMSX_GTD_DATE,";
    		routeTopic = routeTopic + "EMSX_HAND_INSTRUCTION,";
    		routeTopic = routeTopic + "EMSX_IS_MANUAL_ROUTE,";
    		routeTopic = routeTopic + "EMSX_LAST_FILL_DATE,";
    		routeTopic = routeTopic + "EMSX_LAST_FILL_TIME,";
    		routeTopic = routeTopic + "EMSX_LAST_MARKET,";
    		routeTopic = routeTopic + "EMSX_LAST_PRICE,";
    		routeTopic = routeTopic + "EMSX_LAST_SHARES,";
    		routeTopic = routeTopic + "EMSX_LIMIT_PRICE,";
    		routeTopic = routeTopic + "EMSX_MISC_FEES,";
    		routeTopic = routeTopic + "EMSX_ML_LEG_QUANTITY,";
    		routeTopic = routeTopic + "EMSX_ML_NUM_LEGS,";
    		routeTopic = routeTopic + "EMSX_ML_PERCENT_FILLED,";
    		routeTopic = routeTopic + "EMSX_ML_RATIO,";
    		routeTopic = routeTopic + "EMSX_ML_REMAIN_BALANCE,";
    		routeTopic = routeTopic + "EMSX_ML_STRATEGY,";
    		routeTopic = routeTopic + "EMSX_ML_TOTAL_QUANTITY,";
    		routeTopic = routeTopic + "EMSX_NOTES,";
    		routeTopic = routeTopic + "EMSX_NSE_AVG_PRICE,";
    		routeTopic = routeTopic + "EMSX_NSE_FILLED,";
    		routeTopic = routeTopic + "EMSX_ORDER_TYPE,";
    		routeTopic = routeTopic + "EMSX_P_A,";
    		routeTopic = routeTopic + "EMSX_PERCENT_REMAIN,";
    		routeTopic = routeTopic + "EMSX_PRINCIPAL,";
    		routeTopic = routeTopic + "EMSX_QUEUED_DATE,";
    		routeTopic = routeTopic + "EMSX_QUEUED_TIME,";
    		routeTopic = routeTopic + "EMSX_REASON_CODE,";
    		routeTopic = routeTopic + "EMSX_REASON_DESC,";
    		routeTopic = routeTopic + "EMSX_REMAIN_BALANCE,";
    		routeTopic = routeTopic + "EMSX_ROUTE_CREATE_DATE,";
    		routeTopic = routeTopic + "EMSX_ROUTE_CREATE_TIME,";
    		routeTopic = routeTopic + "EMSX_ROUTE_ID,";
    		routeTopic = routeTopic + "EMSX_ROUTE_REF_ID,";
    		routeTopic = routeTopic + "EMSX_ROUTE_LAST_UPDATE_TIME,";
    		routeTopic = routeTopic + "EMSX_ROUTE_PRICE,";
    		routeTopic = routeTopic + "EMSX_SEQUENCE,";
    		routeTopic = routeTopic + "EMSX_SETTLE_AMOUNT,";
    		routeTopic = routeTopic + "EMSX_SETTLE_DATE,";
    		routeTopic = routeTopic + "EMSX_STATUS,";
    		routeTopic = routeTopic + "EMSX_STOP_PRICE,";
    		routeTopic = routeTopic + "EMSX_STRATEGY_END_TIME,";
    		routeTopic = routeTopic + "EMSX_STRATEGY_PART_RATE1,";
    		routeTopic = routeTopic + "EMSX_STRATEGY_PART_RATE2,";
    		routeTopic = routeTopic + "EMSX_STRATEGY_START_TIME,";
    		routeTopic = routeTopic + "EMSX_STRATEGY_STYLE,";
    		routeTopic = routeTopic + "EMSX_STRATEGY_TYPE,";
    		routeTopic = routeTopic + "EMSX_TIF,";
    		routeTopic = routeTopic + "EMSX_TIME_STAMP,";
    		routeTopic = routeTopic + "EMSX_TYPE,";
    		routeTopic = routeTopic + "EMSX_URGENCY_LEVEL,";
    		routeTopic = routeTopic + "EMSX_USER_COMM_AMOUNT,";
    		routeTopic = routeTopic + "EMSX_USER_COMM_RATE,";
    		routeTopic = routeTopic + "EMSX_USER_FEES,";
    		routeTopic = routeTopic + "EMSX_USER_NET_MONEY,";
    		routeTopic = routeTopic + "EMSX_WORKING";

        	
    		// We define a correlation ID that allows us to identify the original
    		// request when we examine the responses. This is useful in situations where
    		// the same event handler is used the process messages for the Order and Route 
    		// subscriptions, as well as request/response requests.
    		routeSubscriptionID = new CorrelationID();
        	
        	routeSubscription = new Subscription(routeTopic,routeSubscriptionID);
        	System.out.println("Route Topic: " + routeTopic);
        	SubscriptionList subscriptions = new SubscriptionList();
        	subscriptions.add(routeSubscription);

        	try {
        		session.subscribe(subscriptions);
        	} catch (Exception ex) {
        		System.err.println("Failed to create Route subscription");
        	}

        }

    }	
}


