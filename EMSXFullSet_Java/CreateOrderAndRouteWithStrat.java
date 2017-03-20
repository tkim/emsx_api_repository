/* Copyright 2017. Bloomberg Finance L.P.
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

import com.bloomberglp.blpapi.Element;
import com.bloomberglp.blpapi.Event;
import com.bloomberglp.blpapi.EventHandler;
import com.bloomberglp.blpapi.Message;
import com.bloomberglp.blpapi.MessageIterator;
import com.bloomberglp.blpapi.Name;
import com.bloomberglp.blpapi.Session;
import com.bloomberglp.blpapi.SessionOptions;
import com.bloomberglp.blpapi.Request;
import com.bloomberglp.blpapi.Service;
import com.bloomberglp.blpapi.CorrelationID;


public class CreateOrderAndRouteWithStrat {
	
	private static final Name 	SESSION_STARTED 		= new Name("SessionStarted");
	private static final Name 	SESSION_STARTUP_FAILURE = new Name("SessionStartupFailure");
	private static final Name 	SERVICE_OPENED 			= new Name("ServiceOpened");
	private static final Name 	SERVICE_OPEN_FAILURE 	= new Name("ServiceOpenFailure");
	
    private static final Name 	ERROR_INFO = new Name("ErrorInfo");
    private static final Name 	CREATE_ORDER_AND_ROUTE_WITH_STRAT = new Name("CreateOrderAndRouteEx");

	private String 	d_service;
    private String  d_host;
    private int     d_port;
    
    private CorrelationID requestID;
    
    private static boolean quit=false;
    
    public static void main(String[] args) throws java.lang.Exception
    {
        System.out.println("Bloomberg - EMSX API Example - CreateOrderAndRouteWithStrat\n");

        CreateOrderAndRouteWithStrat example = new CreateOrderAndRouteWithStrat();
        example.run(args);

        while(!quit) {
        	Thread.sleep(10);
        };
        
    }
    
    public CreateOrderAndRouteWithStrat()
    {
    	
    	// Define the service required, in this case the EMSX beta service, 
    	// and the values to be used by the SessionOptions object
    	// to identify IP/port of the back-end process.
    	
    	d_service = "//blp/emapisvc_beta";
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
                case Event.EventType.Constants.SESSION_STATUS:
                    processSessionEvent(event, session);
                    break;
                case Event.EventType.Constants.SERVICE_STATUS:
                    processServiceEvent(event, session);
                    break;
                case Event.EventType.Constants.RESPONSE:
                    processResponseEvent(event, session);
                    break;
                default:
                    processMiscEvents(event, session);
                    break;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

		private boolean processSessionEvent(Event event, Session session) throws Exception {

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
                }
            }
            return true;
		}

        private boolean processServiceEvent(Event event, Session session) {

        	System.out.println("Processing " + event.eventType().toString());
        	
        	MessageIterator msgIter = event.messageIterator();
            
        	while (msgIter.hasNext()) {
            
        		Message msg = msgIter.next();
                
        		if(msg.messageType().equals(SERVICE_OPENED)) {
                
        			System.out.println("Service opened...");
                	
                    Service service = session.getService(d_service);

                    Request request = service.createRequest("CreateOrderAndRouteEx");

            	    // The fields below are mandatory
            	    request.set("EMSX_TICKER", "IBM US Equity");
            	    request.set("EMSX_AMOUNT", 1000);
            	    request.set("EMSX_ORDER_TYPE", "MKT");
            	    request.set("EMSX_TIF", "DAY");
            	    request.set("EMSX_HAND_INSTRUCTION", "ANY");
            	    request.set("EMSX_SIDE", "BUY");
            	    request.set("EMSX_BROKER", "BMTB");
            	
            	    // The fields below are optional
            	    //request.set("EMSX_ACCOUNT","TestAccount");
            	    //request.set("EMSX_BOOKNAME","BookName");
            	    //request.set("EMSX_BASKET_NAME", "HedgingBasket");
            	    //request.set("EMSX_CFD_FLAG", "1");
            	    //request.set("EMSX_CLEARING_ACCOUNT", "ClrAccName");
            	    //request.set("EMSX_CLEARING_FIRM", "FirmName");
            	    //request.set("EMSX_CUSTOM_NOTE1", "Note1");
            	    //request.set("EMSX_CUSTOM_NOTE2", "Note2");
            	    //request.set("EMSX_CUSTOM_NOTE3", "Note3");
            	    //request.set("EMSX_CUSTOM_NOTE4", "Note4");
            	    //request.set("EMSX_CUSTOM_NOTE5", "Note5");
            	    //request.set("EMSX_EXCHANGE_DESTINATION", "ExchDest");
            	    //request.set("EMSX_EXEC_INSTRUCTIONS", "AnyInst");
            	    //request.set("EMSX_GET_WARNINGS", "0");
            	    //request.set("EMSX_GTD_DATE", "20170105");
            	    //request.set("EMSX_INVESTOR_ID", "InvID");
            	    //request.set("EMSX_LIMIT_PRICE", 123.45);
            	    //request.set("EMSX_LOCATE_BROKER", "BMTB");
            	    //request.set("EMSX_LOCATE_ID", "SomeID");
            	    //request.set("EMSX_LOCATE_REQ", "Y");
            	    //request.set("EMSX_NOTES", "Some notes");
            	    //request.set("EMSX_ODD_LOT", "0");
            	    //request.set("EMSX_ORDER_ORIGIN", "");
            	    //request.set("EMSX_ORDER_REF_ID", "UniqueID");
            	    //request.set("EMSX_P_A", "P");
            	    //request.set("EMSX_RELEASE_TIME", 34341);
            	    //request.set("EMSX_REQUEST_SEQ", 1001);
            	    //request.set("EMSX_ROUTE_REF_ID", "UniqueID");
            	    //request.set("EMSX_SETTLE_CURRENCY", "USD");
            	    //request.set("EMSX_SETTLE_DATE", 20170106);
            	    //request.set("EMSX_SETTLE_TYPE", "T+2");
            	    //request.set("EMSX_STOP_PRICE", 123.5);
            	    
            	    // Below we establish the strategy details
            	    
            	    Element strategy = request.getElement("EMSX_STRATEGY_PARAMS");
            	    strategy.setElement("EMSX_STRATEGY_NAME", "VWAP");
            	    
            	    Element indicator = strategy.getElement("EMSX_STRATEGY_FIELD_INDICATORS");
            	    Element data = strategy.getElement("EMSX_STRATEGY_FIELDS");
            	    
            		// Strategy parameters must be appended in the correct order. See the output 
            	    // of GetBrokerStrategyInfo request for the order. The indicator value is 0 for 
            	    // a field that carries a value, and 1 where the field should be ignored
            	    
            	    data.appendElement().setElement("EMSX_FIELD_DATA", "09:30:00"); // StartTime
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 0);

               		data.appendElement().setElement("EMSX_FIELD_DATA", "10:30:00"); // EndTime
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 0);

               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// Max%Volume
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);

               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// %AMSession
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);

               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// OPG
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);

               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// MOC
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);

               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// CompletePX
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);
               		
               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// TriggerPX
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);

               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// DarkComplete
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);

               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// DarkCompPX
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);

               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// RefIndex
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);

               		data.appendElement().setElement("EMSX_FIELD_DATA", ""); 		// Discretion
               		indicator.appendElement().setElement("EMSX_FIELD_INDICATOR", 1);

               		System.out.println("Request: " + request.toString());

                    requestID = new CorrelationID();
                    
                    // Submit the request
                	try {
                        session.sendRequest(request, requestID);
                	} catch (Exception ex) {
                		System.err.println("Failed to send the request");
                		return false;
                	}
                	
                } else if(msg.messageType().equals(SERVICE_OPEN_FAILURE)) {
                	System.err.println("Error: Service failed to open");
                	return false;
                }
            }
            return true;
		}

		private boolean processResponseEvent(Event event, Session session) throws Exception 
		{
			System.out.println("Received Event: " + event.eventType().toString());
            
            MessageIterator msgIter = event.messageIterator();
            
            while(msgIter.hasNext())
            {
            	Message msg = msgIter.next();
                System.out.println("MESSAGE: " + msg.toString());
                System.out.println("CORRELATION ID: " + msg.correlationID());
                
                if(event.eventType()==Event.EventType.RESPONSE && msg.correlationID()==requestID) {
                	
                	System.out.println("Message Type: " + msg.messageType());
                	if(msg.messageType().equals(ERROR_INFO)) {
                		Integer errorCode = msg.getElementAsInt32("ERROR_CODE");
                		String errorMessage = msg.getElementAsString("ERROR_MESSAGE");
                		System.out.println("ERROR CODE: " + errorCode + "\tERROR MESSAGE: " + errorMessage);
                	} else if(msg.messageType().equals(CREATE_ORDER_AND_ROUTE_WITH_STRAT)) {
                		Integer emsx_sequence = msg.getElementAsInt32("EMSX_SEQUENCE");
                		Integer emsx_route_id = msg.getElementAsInt32("EMSX_ROUTE_ID");
                		String message = msg.getElementAsString("MESSAGE");
                		System.out.println("EMSX_SEQUENCE: " + emsx_sequence + "\tEMSX_ROUTE_ID: " + emsx_route_id + "\tMESSAGE: " + message);
                	}
                	                	
                	quit=true;
                	session.stop();
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

    }	
	
}

