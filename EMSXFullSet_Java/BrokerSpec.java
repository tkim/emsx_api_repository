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


public class BrokerSpec {
	
	private static final Name 	SESSION_STARTED 		= new Name("SessionStarted");
	private static final Name 	SESSION_STARTUP_FAILURE = new Name("SessionStartupFailure");
	private static final Name 	SERVICE_OPENED 			= new Name("ServiceOpened");
	private static final Name 	SERVICE_OPEN_FAILURE 	= new Name("ServiceOpenFailure");
	
    private static final Name 	ERROR_INFO = new Name("ErrorInfo");
    private static final Name 	BROKER_SPEC = new Name("BrokerSpec");

	private String 	d_service;
    private String  d_host;
    private int     d_port;
    
    private CorrelationID requestID;
    
    private static boolean quit=false;
    
    public static void main(String[] args) throws java.lang.Exception
    {
        System.out.println("Bloomberg - EMSX API Example - BrokerSpec\n");

        BrokerSpec example = new BrokerSpec();
        example.run(args);

        while(!quit) {
        	Thread.sleep(10);
        };
        
    }
    
    public BrokerSpec()
    {
    	
    	//The BrokerSpec service is only available in the production environment
    	
    	d_service = "//blp/emsx.brokerspec";
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

                    Request request = service.createRequest("GetBrokerSpecForUuid");
                    request.set("uuid", 8049857);

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
                //System.out.println("CORRELATION ID: " + msg.correlationID());
                
                if(event.eventType()==Event.EventType.RESPONSE && msg.correlationID()==requestID) {
                	
                	System.out.println("Message Type: " + msg.messageType());
                	if(msg.messageType().equals(ERROR_INFO)) {
                		Integer errorCode = msg.getElementAsInt32("ERROR_CODE");
                		String errorMessage = msg.getElementAsString("ERROR_MESSAGE");
                		System.out.println("ERROR CODE: " + errorCode + "\tERROR MESSAGE: " + errorMessage);
                	} else if(msg.messageType().equals(BROKER_SPEC)) {
                		
                		Element brokers = msg.getElement("brokers");
                		
                		int numBkrs = brokers.numValues();
                		
                		System.out.println("Number of Brokers: " + numBkrs);
                		
                		for(int i = 0; i < numBkrs; i++) {
                			
                			Element broker = brokers.getValueAsElement(i);
                			
                			String code = broker.getElementAsString("code");
                			String assetClass = broker.getElementAsString("assetClass");
                			
                			if(broker.hasElement("strategyFixTag")) {
                				Long tag = broker.getElementAsInt64("strategyFixTag");
                				System.out.println("\nBroker code: " + code + "\tClass: " + assetClass + "\tTag: " + tag);
                				
                				Element strats = broker.getElement("strategies");
                				
                				int numStrats = strats.numValues();
                				
                				System.out.println("\tNo. of Strategies: " + numStrats);
                				
                				for(int s=0; s < numStrats; s++) {
                					
                					Element strat = strats.getValueAsElement(s);
                					
                					String name = strat.getElementAsString("name");
                					String fixVal = strat.getElementAsString("fixValue");
                					
                					System.out.println("\n\tStrategy Name: " + name + "\tFix Value: " + fixVal);
                					
                					Element parameters = strat.getElement("parameters");
                					
                					int numParams = parameters.numValues();
                					
                					System.out.println("\t\tNo. of Parameters: " + numParams);
                					
                					for(int p=0; p < numParams; p++) {
                						
                						Element param = parameters.getValueAsElement(p);
                						
                						String pname = param.getElementAsString("name");
                						long fixTag = param.getElementAsInt64("fixTag");
                						boolean required = param.getElementAsBool("isRequired");
                						boolean replaceable = param.getElementAsBool("isReplaceable");
                						
                						System.out.println("\t\tParameter: " + pname + "\tTag: " + fixTag + "\tRequired: " + required + "\tReplaceable: " + replaceable);
                						
                						//String typeName = param.getElement("type").getElement(0).name().toString();
                						String typeName = param.getElement("type").getChoice().name().toString();
                						
                						String vals="";
                						
                						if(typeName.equals("enumeration")) {
                							Element enumerators = param.getElement("type").getElement(0).getElement("enumerators");

                							int numEnums = enumerators.numValues();
                							
                							for(int e=0; e < numEnums; e++) {
                								Element en = enumerators.getValueAsElement(e);
                								
                								vals = vals + en.getElementAsString("name") + "[" + en.getElementAsString("fixValue") + "],";
                							}
                							vals = vals.substring(0, vals.length()-1);
                						} else if(typeName.equals("range")) {
                							Element rng = param.getElement("type").getElement(0);
                							long mn = rng.getElementAsInt64("min");
                							long mx = rng.getElementAsInt64("max");
                							long st = rng.getElementAsInt64("step");
                							vals = "min:" + mn + " max:" + mx + " step:" + st;
                						} else if(typeName.equals("string")) {
                							Element possVals = param.getElement("type").getElement(0).getElement("possibleValues");
                							
                							int numVals = possVals.numValues();
                							
                							for(int v=0; v < numVals; v++) {
                								vals = vals + possVals.getValueAsString(v) + ",";
                							}
                							if(vals.length()>0) vals = vals.substring(0,vals.length()-1);
                						}
                						
                						if(vals.length() > 0) {
                							System.out.println("\t\t\tType: " + typeName + " (" + vals + ")");
                						} else {
                							System.out.println("\t\t\tType: " + typeName );
                						}
                						
                					}
                				
                				}
                				
                			} else {
                				System.out.println("\nBroker code: " + code + "\tClass: " + assetClass);
                				System.out.println("\tNo Strategies");
                			}

                			System.out.println("\n\tTime In Force:");
                			Element tifs = broker.getElement("timesInForce");
                			int numTifs = tifs.numValues();
                			for(int t=0; t<numTifs; t++) {
                				Element tif = tifs.getValueAsElement(t);
                				String tifName = tif.getElementAsString("name");
                				String tifFixValue = tif.getElementAsString("fixValue");
                				System.out.println("\t\tName: " + tifName + "\tFix Value: " + tifFixValue);
                			}
                			
                			System.out.println("\n\tOrder Types:");
                			Element ordTypes = broker.getElement("orderTypes");
                			int numOrdTypes = ordTypes.numValues();
                			for(int o=0; o<numOrdTypes; o++) {
                				Element ordType = ordTypes.getValueAsElement(o);
                				String typName = ordType.getElementAsString("name");
                				String typFixValue = ordType.getElementAsString("fixValue");
                				System.out.println("\t\tName: " + typName + "\tFix Value: " + typFixValue);
                			}
                			
                			System.out.println("\n\tHandling Instructions:");
                			Element handInsts = broker.getElement("handlingInstructions");
                			int numHandInsts = handInsts.numValues();
                			for(int h=0; h<numHandInsts; h++) {
                				Element handInst = handInsts.getValueAsElement(h);
                				String instName = handInst.getElementAsString("name");
                				String instFixValue = handInst.getElementAsString("fixValue");
                				System.out.println("\t\tName: " + instName + "\tFix Value: " + instFixValue);
                			}

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

