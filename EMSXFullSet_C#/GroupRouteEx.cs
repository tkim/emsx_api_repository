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

using Name = Bloomberglp.Blpapi.Name;
using SessionOptions = Bloomberglp.Blpapi.SessionOptions;
using Session = Bloomberglp.Blpapi.Session;
using Service = Bloomberglp.Blpapi.Service;
using Request = Bloomberglp.Blpapi.Request;
using Element = Bloomberglp.Blpapi.Element;
using CorrelationID = Bloomberglp.Blpapi.CorrelationID;
using Event = Bloomberglp.Blpapi.Event;
using Message = Bloomberglp.Blpapi.Message;
using EventHandler = Bloomberglp.Blpapi.EventHandler;
using System;

namespace com.bloomberg.emsx.samples
{
    public class GroupRouteEx
    {

        private static readonly Name SESSION_STARTED = new Name("SessionStarted");
        private static readonly Name SESSION_STARTUP_FAILURE = new Name("SessionStartupFailure");
        private static readonly Name SERVICE_OPENED = new Name("ServiceOpened");
        private static readonly Name SERVICE_OPEN_FAILURE = new Name("ServiceOpenFailure");

        private static readonly Name ERROR_INFO = new Name("ErrorInfo");
        private static readonly Name GROUP_ROUTE_EX = new Name("GroupRouteEx");

        private string d_service;
        private string d_host;
        private int d_port;

        private static bool quit = false;

        private CorrelationID requestID;

        public static void Main(String[] args)
        {
            System.Console.WriteLine("Bloomberg - EMSX API Example - GroupRouteEx\n");

            GroupRouteEx example = new GroupRouteEx();
            example.run(args);

            while (!quit) { };

            System.Console.WriteLine("Press ENTER to terminate...");
            System.Console.ReadKey();
            
        }

        public GroupRouteEx()
        {

            // Define the service required, in this case the beta service, 
            // and the values to be used by the SessionOptions object
            // to identify IP/port of the back-end process.

            d_service = "//blp/emapisvc_beta";
            d_host = "localhost";
            d_port = 8194;

        }

        private void run(String[] args)
        {

            SessionOptions d_sessionOptions = new SessionOptions();
            d_sessionOptions.ServerHost = d_host;
            d_sessionOptions.ServerPort = d_port;

            Session session = new Session(d_sessionOptions, new EventHandler(processEvent));

            session.StartAsync();

        }

        public void processEvent(Event evt, Session session)
        {
            try
            {
                switch (evt.Type)
                {
                    case Event.EventType.SESSION_STATUS:
                        processSessionEvent(evt, session);
                        break;
                    case Event.EventType.SERVICE_STATUS:
                        processServiceEvent(evt, session);
                        break;
                    case Event.EventType.RESPONSE:
                        processResponseEvent(evt, session);
                        break;
                    default:
                        processMiscEvents(evt, session);
                        break;
                }
            }
            catch (Exception e)
            {
                System.Console.Error.WriteLine(e);
            }
        }

        private void processSessionEvent(Event evt, Session session)
        {
            System.Console.WriteLine("\nProcessing " + evt.Type);

            foreach (Message msg in evt)
            {
                if (msg.MessageType.Equals(SESSION_STARTED))
                {
                    System.Console.WriteLine("Session started...");
                    session.OpenServiceAsync(d_service);
                }
                else if (msg.MessageType.Equals(SESSION_STARTUP_FAILURE))
                {
                    System.Console.Error.WriteLine("Error: Session startup failed");
                }
            }
        }

        private void processServiceEvent(Event evt, Session session)
        {

            System.Console.WriteLine("\nProcessing " + evt.Type);

            foreach (Message msg in evt)
            {
                if (msg.MessageType.Equals(SERVICE_OPENED))
                {
                    System.Console.WriteLine("Service opened...");

                    Service service = session.GetService(d_service);

                    Request request = service.CreateRequest("GroupRouteEx");

                    // Multiple order numbers can be added
                    request.Append("EMSX_SEQUENCE", 3663923);
                    request.Append("EMSX_SEQUENCE", 3663924);
                    request.Append("EMSX_SEQUENCE", 3663925);

                    // The fields below are mandatory
                    request.Set("EMSX_AMOUNT_PERCENT", 100); // Note the amount here is %age of order amount
                    request.Set("EMSX_BROKER", "BMTB");

                    // For GroupRoute, the below values need to be added, but are taken 
                    // from the original order when the route is created.
                    request.Set("EMSX_HAND_INSTRUCTION", "ANY");
                    request.Set("EMSX_ORDER_TYPE", "MKT");
                    request.Set("EMSX_TICKER", "IBM US Equity");
                    request.Set("EMSX_TIF", "DAY");

                    // The fields below are optional
                    //request.Set("EMSX_ACCOUNT","TestAccount");
                    //request.Set("EMSX_BOOKNAME","BookName");
                    //request.Set("EMSX_CFD_FLAG", "1");
                    //request.Set("EMSX_CLEARING_ACCOUNT", "ClrAccName");
                    //request.Set("EMSX_CLEARING_FIRM", "FirmName");
                    //request.Set("EMSX_EXEC_INSTRUCTIONS", "AnyInst");
                    //request.Set("EMSX_GET_WARNINGS", "0");
                    //request.Set("EMSX_GTD_DATE", "20170105");
                    //request.Set("EMSX_LIMIT_PRICE", 123.45);
                    //request.Set("EMSX_LOCATE_BROKER", "BMTB");
                    //request.Set("EMSX_LOCATE_ID", "SomeID");
                    //request.Set("EMSX_LOCATE_REQ", "Y");
                    //request.Set("EMSX_NOTES", "Some notes");
                    //request.Set("EMSX_ODD_LOT", "0");
                    //request.Set("EMSX_P_A", "P");
                    //request.Set("EMSX_RELEASE_TIME", 34341);
                    //request.Set("EMSX_REQUEST_SEQ", 1001);
                    //request.Set("EMSX_STOP_PRICE", 123.5);
                    //request.Set("EMSX_TRADER_UUID", 1234567);

                    // Set the Request Type if this is for multi-leg orders
                    // only valid for options
                    /*
                    Element requestType = request.GetElement("EMSX_REQUEST_TYPE"); 
            	    requestType.SetChoice("Multileg");
            	    Element multileg = requestType.GetElement("Multileg");
            	    multileg.SetElement("EMSX_AMOUNT",10);
            	    multileg.GetElement("EMSX_ML_RATIO").AppendValue(2);
            	    multileg.GetElement("EMSX_ML_RATIO").AppendValue(3);
            	    */

                    // Add the Route Ref ID values
                    Element routeRefIDPairs = request.GetElement("EMSX_ROUTE_REF_ID_PAIRS");
                    Element route1 = routeRefIDPairs.AppendElement();
                    route1.SetElement("EMSX_ROUTE_REF_ID", "MyRouteRef1");
                    route1.SetElement("EMSX_SEQUENCE", 3663923);

                    Element route2 = routeRefIDPairs.AppendElement();
                    route2.SetElement("EMSX_ROUTE_REF_ID", "MyRouteRef2");
                    route2.SetElement("EMSX_SEQUENCE", 3663924);

                    Element route3 = routeRefIDPairs.AppendElement();
                    route3.SetElement("EMSX_ROUTE_REF_ID", "MyRouteRef3");
                    route3.SetElement("EMSX_SEQUENCE", 3663925);

                    // Below we establish the strategy details. Strategy details
                    // are common across all orders in a GroupRoute operation.
                    // The following segment can be removed if no broker strategies are used

                    Element strategy = request.GetElement("EMSX_STRATEGY_PARAMS");
                    strategy.SetElement("EMSX_STRATEGY_NAME", "VWAP");

                    Element indicator = strategy.GetElement("EMSX_STRATEGY_FIELD_INDICATORS");
                    Element data = strategy.GetElement("EMSX_STRATEGY_FIELDS");

                    // Strategy parameters must be appended in the correct order. See the output 
                    // of GetBrokerStrategyInfo request for the order. The indicator value is 0 for 
                    // a field that carries a value, and 1 where the field should be ignored

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "09:30:00"); // StartTime
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 0);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "10:30:00"); // EndTime
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 0);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // Max%Volume
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // %AMSession
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // OPG
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // MOC
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // CompletePX
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // TriggerPX
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // DarkComplete
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // DarkCompPX
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // RefIndex
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    data.AppendElement().SetElement("EMSX_FIELD_DATA", "");         // Discretion
                    indicator.AppendElement().SetElement("EMSX_FIELD_INDICATOR", 1);

                    System.Console.WriteLine("Request: " + request.ToString());

                    requestID = new CorrelationID();

                    // Submit the request
                    try
                    {
                        session.SendRequest(request, requestID);
                    }
                    catch (Exception ex)
                    {
                        System.Console.Error.WriteLine("Failed to send the request: " + ex.Message);
                    }

                }
                else if (msg.MessageType.Equals(SERVICE_OPEN_FAILURE))
                {
                    System.Console.Error.WriteLine("Error: Service failed to open");
                }
            }
        }

        private void processResponseEvent(Event evt, Session session)
        {
            System.Console.WriteLine("Received Event: " + evt.Type);

            foreach (Message msg in evt)
            {

                System.Console.WriteLine("MESSAGE: " + msg.ToString());
                System.Console.WriteLine("CORRELATION ID: " + msg.CorrelationID);

                if (evt.Type == Event.EventType.RESPONSE && msg.CorrelationID == requestID)
                {
                    System.Console.WriteLine("Message Type: " + msg.MessageType);

                    if (msg.MessageType.Equals(ERROR_INFO))
                    {
                        int errorCode = msg.GetElementAsInt32("ERROR_CODE");
                        String errorMessage = msg.GetElementAsString("ERROR_MESSAGE");
                        System.Console.WriteLine("ERROR CODE: " + errorCode + "\tERROR MESSAGE: " + errorMessage);
                    }
                    else if (msg.MessageType.Equals(GROUP_ROUTE_EX))
                    {
                        int numValues = 0;

                        if (msg.HasElement("EMSX_SUCCESS_ROUTES"))
                        {

                            Element success = msg.GetElement("EMSX_SUCCESS_ROUTES");

                            numValues = success.NumValues;

                            for (int i = 0; i < numValues; i++)
                            {

                                Element e = success.GetValueAsElement(i);

                                int emsx_sequence = e.GetElementAsInt32("EMSX_SEQUENCE");
                                int emsx_route_id = e.GetElementAsInt32("EMSX_ROUTE_ID");

                                System.Console.WriteLine("Success: " + emsx_sequence + ", " + emsx_route_id);
                            }

                            if (msg.HasElement("EMSX_FAILED_ROUTES"))
                            {

                                Element failed = msg.GetElement("EMSX_FAILED_ROUTES");

                                numValues = failed.NumValues;

                                for (int i = 0; i < numValues; i++)
                                {

                                    Element e = failed.GetValueAsElement(i);

                                    int emsx_sequence = e.GetElementAsInt32("EMSX_SEQUENCE");
                                    int error_code = e.GetElementAsInt32("ERROR_CODE");
                                    String error_message = e.GetElementAsString("ERROR_MESSAGE");

                                    System.Console.WriteLine("Failed: " + emsx_sequence + ", " + error_code + ": " + error_message);
                                }

                            }
                        }

                        String message = msg.GetElementAsString("MESSAGE");
                        System.Console.WriteLine("MESSAGE:" + message);
                    }

                    quit = true;
                    session.Stop();
                }
            }
        }

        private void processMiscEvents(Event evt, Session session)
        {
            System.Console.WriteLine("Processing " + evt.Type);

            foreach (Message msg in evt)
            {
                System.Console.WriteLine("MESSAGE: " + msg);
            }
        }
    }
}