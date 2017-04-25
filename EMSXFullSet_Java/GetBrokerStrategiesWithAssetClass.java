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
import com.bloomberglp.blpapi.Element;
import com.bloomberglp.blpapi.Event;
import com.bloomberglp.blpapi.EventHandler;
import com.bloomberglp.blpapi.Message;
import com.bloomberglp.blpapi.MessageIterator;
import com.bloomberglp.blpapi.Name;
import com.bloomberglp.blpapi.Request;
import com.bloomberglp.blpapi.Service;
import com.bloomberglp.blpapi.Session;
import com.bloomberglp.blpapi.SessionOptions;


public class GetBrokerStrategiesWithAssetClass {
	
	private static final Name 	SESSION_STARTED 		= new Name("SessionStarted");
	private static final Name 	SESSION_STARTUP_FAILURE = new Name("SessionStartupFailure");
	private static final Name 	SERVICE_OPENED 			= new Name("ServiceOpened");
	private static final Name 	SERVICE_OPEN_FAILURE 	= new Name("ServiceOpenFailure");
	
    private static final Name 	ERROR_INFO = new Name("ErrorInfo");
    private static final Name 	GET_BROKER_STRATEGIES_WITH_ASSET_CLASS = new Name("GetBrokerStrategiesWithAssetClass");

	private String 	d_service;
    private String  d_host;
    private int     d_port;
    
    private CorrelationID requestID;
    
    private static boolean quit=false;
    
    public static void main(String[] args) throws java.lang.Exception
    {
        System.out.println("Bloomberg - EMSX API Example - GetBrokerStrategiesWithAssetClass\n");

        GetBrokerStrategiesWithAssetClass example = new GetBrokerStrategiesWithAssetClass();
        example.run(args);

        while(!quit) {
        	Thread.sleep(10);
        };
        
    }
    
    public GetBrokerStrategiesWithAssetClass()
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

                    Request request = service.createRequest("GetBrokerStrategiesWithAssetClass");

                    //request.set("EMSX_REQUEST_SEQ", 1);
                    
                    request.set("EMSX_ASSET_CLASS","EQTY"); //one of EQTY, OPT, FUT or MULTILEG_OPT
                    request.set("EMSX_BROKER","BMTB");
                    
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
                	} else if(msg.messageType().equals(GET_BROKER_STRATEGIES_WITH_ASSET_CLASS)) {
                		
                		Element strategies = msg.getElement("EMSX_STRATEGIES");
                		
            			int numValues = strategies.numValues();
            			System.out.println("Number of Strategies: " + numValues);
                		
                		for(int i = 0; i < numValues; i++) {
                			
                			String strategy = strategies.getValueAsString(i);
                			
                    		System.out.println("EMSX_STRATEGIES: " + strategy);                	
                		}
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

