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

import com.bloomberglp.blpapi.CorrelationID;
import com.bloomberglp.blpapi.Event;
import com.bloomberglp.blpapi.EventHandler;
import com.bloomberglp.blpapi.Message;
import com.bloomberglp.blpapi.MessageIterator;
import com.bloomberglp.blpapi.Name;
import com.bloomberglp.blpapi.Request;
import com.bloomberglp.blpapi.Service;
import com.bloomberglp.blpapi.Session;
import com.bloomberglp.blpapi.SessionOptions;


public class ModifyRouteEx {
	
	private static final Name 	SESSION_STARTED 		= new Name("SessionStarted");
	private static final Name 	SESSION_STARTUP_FAILURE = new Name("SessionStartupFailure");
	private static final Name 	SERVICE_OPENED 			= new Name("ServiceOpened");
	private static final Name 	SERVICE_OPEN_FAILURE 	= new Name("ServiceOpenFailure");
	
    private static final Name 	ERROR_INFO = new Name("ErrorInfo");
    private static final Name 	MODIFY_ROUTE_EX = new Name("ModifyRouteEx");

	private String 	d_service;
    private String  d_host;
    private int     d_port;
    
    private CorrelationID requestID;
    
    private static boolean quit=false;
    
    public static void main(String[] args) throws java.lang.Exception
    {
        System.out.println("Bloomberg - EMSX API Example - ModifyRouteEx\n");

        ModifyRouteEx example = new ModifyRouteEx();
        example.run(args);

        while(!quit) {
        	Thread.sleep(10);
        };
        
    }
    
    public ModifyRouteEx()
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

                    Request request = service.createRequest("ModifyRouteEx");

            	    //request.set("EMSX_REQUEST_SEQ", 1);

                    // The fields below are mandatory
            	    request.set("EMSX_SEQUENCE", 3827449);
            	    request.set("EMSX_ROUTE_ID", 1);
            	    request.set("EMSX_AMOUNT", 500);
            	    request.set("EMSX_ORDER_TYPE", "MKT");
            	    request.set("EMSX_TIF", "DAY");
            	
            	    // The fields below are optional
            	    //request.set("EMSX_ACCOUNT","TestAccount");
            	    //request.set("EMSX_CLEARING_ACCOUNT", "ClearingAcnt");
            	    //request.set("EMSX_CLEARING_FIRM", "ClearingFirm");
            	    //request.set("EMSX_COMM_TYPE", "Absolute");
            	    //request.set("EMSX_EXCHANGE_DESTINATION", "DEST");
            	    //request.set("EMSX_GET_WARNINGS", "0");
            	    //request.set("EMSX_GTD_DATE", "20170105");
            	    //request.set("EMSX_LIMIT_PRICE", 123.45);
            	    //request.set("EMSX_LOC_BROKER", "ABCD");
            	    //request.set("EMSX_LOC_ID", "1234567");
            	    //request.set("EMSX_LOC_REQ", "Y");
            	    //request.set("EMSX_NOTES", "Some notes");
            	    //request.set("EMSX_ODD_LOT", "" );
            	    //request.set("EMSX_P_A", "P");
            	    //request.set("EMSX_STOP_PRICE", 123.5);
            	    //request.set("EMSX_TRADER_NOTES", "Trader notes");
            	    //request.set("EMSX_USER_COMM_RATE", 0.02);
            	    //request.set("EMSX_USER_FEES", "1.5");

            	    // Note: When changing order type to a LMT order, you will need to provide the EMSX_LIMIT_PRICE value.
            	    //       When changing order type away from LMT order, you will need to reset the EMSX_LIMIT_PRICE value
            	    //       by setting the content to -99999
            	    
            	    // Note: To clear down the stop price, set the content to -1
            	    
            	    // Set the strategy parameters, if required
            	    
            	    /*
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
					*/
            	    
            	    // If modifying on behalf of another trader, set the order owner's UUID
            	    //request.set("EMSX_TRADER_UUID", 1234567);
            	    
            	    // If modifying a multi-leg route, indicate the Multileg ID 
            	    //request.getElement("EMSX_REQUEST_TYPE").setChoice("Multileg").setElement("EMSX_ML_ID", "123456");
            	    
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
                	} else if(msg.messageType().equals(MODIFY_ROUTE_EX)) {
                		// The response has fields for EMSX_SEQUENCE and EMSX_ROUTE_ID, but these will always be zero
                		String message = msg.getElementAsString("MESSAGE");
                		System.out.println("MESSAGE: " + message);
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

