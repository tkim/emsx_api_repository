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
    public class BrokerSpec
    {

        private static readonly Name SESSION_STARTED = new Name("SessionStarted");
        private static readonly Name SESSION_STARTUP_FAILURE = new Name("SessionStartupFailure");
        private static readonly Name SERVICE_OPENED = new Name("ServiceOpened");
        private static readonly Name SERVICE_OPEN_FAILURE = new Name("ServiceOpenFailure");

        private static readonly Name ERROR_INFO = new Name("ErrorInfo");
        private static readonly Name BROKER_SPEC = new Name("BrokerSpec");

        private string d_service;
        private string d_host;
        private int d_port;

        private static bool quit = false;

        private CorrelationID requestID;

        public static void Main(String[] args)
        {
            System.Console.WriteLine("Bloomberg - EMSX API Example - BrokerSpec\n");

            BrokerSpec example = new BrokerSpec();
            example.run(args);

            while (!quit) { };

            System.Console.WriteLine("Press ENTER to terminate...");
            System.Console.ReadKey();
            
        }

        public BrokerSpec()
        {

            //The BrokerSpec service is only available in the production environment
            d_service = "//blp/emsx.brokerspec";
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

                    Request request = service.CreateRequest("GetBrokerSpecForUuid");
                    request.Set("uuid", 8049857);

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

                //System.Console.WriteLine("MESSAGE: " + msg.ToString());
                //System.Console.WriteLine("CORRELATION ID: " + msg.CorrelationID);

                if (evt.Type == Event.EventType.RESPONSE && msg.CorrelationID == requestID)
                {
                    System.Console.WriteLine("Message Type: " + msg.MessageType);
                    if (msg.MessageType.Equals(ERROR_INFO))
                    {
                        int errorCode = msg.GetElementAsInt32("ERROR_CODE");
                        String errorMessage = msg.GetElementAsString("ERROR_MESSAGE");
                        System.Console.WriteLine("ERROR CODE: " + errorCode + "\tERROR MESSAGE: " + errorMessage);
                    }
                    else if (msg.MessageType.Equals(BROKER_SPEC))
                    {
                        Element brokers = msg.GetElement("brokers");

                        int numBkrs = brokers.NumValues;

                        System.Console.WriteLine("Number of Brokers: " + numBkrs);

                        for (int i = 0; i < numBkrs; i++)
                        {

                            Element broker = brokers.GetValueAsElement(i);

                            String code = broker.GetElementAsString("code");
                            String assetClass = broker.GetElementAsString("assetClass");

                            if (broker.HasElement("strategyFixTag"))
                            {
                                long tag = broker.GetElementAsInt64("strategyFixTag");
                                System.Console.WriteLine("\nBroker code: " + code + "\tClass: " + assetClass + "\tTag: " + tag);

                                Element strats = broker.GetElement("strategies");

                                int numStrats = strats.NumValues;

                                System.Console.WriteLine("\tNo. of Strategies: " + numStrats);

                                for (int s = 0; s < numStrats; s++)
                                {

                                    Element strat = strats.GetValueAsElement(s);

                                    String name = strat.GetElementAsString("name");
                                    String fixVal = strat.GetElementAsString("fixValue");

                                    System.Console.WriteLine("\n\tStrategy Name: " + name + "\tFix Value: " + fixVal);

                                    Element parameters = strat.GetElement("parameters");

                                    int numParams = parameters.NumValues;

                                    System.Console.WriteLine("\t\tNo. of Parameters: " + numParams);

                                    for (int p = 0; p < numParams; p++)
                                    {

                                        Element param = parameters.GetValueAsElement(p);

                                        String pname = param.GetElementAsString("name");
                                        long fixTag = param.GetElementAsInt64("fixTag");
                                        bool required = param.GetElementAsBool("isRequired");
                                        bool replaceable = param.GetElementAsBool("isReplaceable");

                                        System.Console.WriteLine("\t\tParameter: " + pname + "\tTag: " + fixTag + "\tRequired: " + required + "\tReplaceable: " + replaceable);

                                        String typeName = param.GetElement("type").GetElement(0).Name.ToString();

                                        String vals = "";

                                        if (typeName.Equals("enumeration"))
                                        {
                                            Element enumerators = param.GetElement("type").GetElement(0).GetElement("enumerators");

                                            int numEnums = enumerators.NumValues;

                                            for (int e = 0; e < numEnums; e++)
                                            {
                                                Element en = enumerators.GetValueAsElement(e);

                                                vals = vals + en.GetElementAsString("name") + "[" + en.GetElementAsString("fixValue") + "],";
                                            }
                                            vals = vals.Substring(0, vals.Length - 1);
                                        }
                                        else if (typeName.Equals("range"))
                                        {
                                            Element rng = param.GetElement("type").GetElement(0);
                                            long mn = rng.GetElementAsInt64("min");
                                            long mx = rng.GetElementAsInt64("max");
                                            long st = rng.GetElementAsInt64("step");
                                            vals = "min:" + mn + " max:" + mx + " step:" + st;
                                        }
                                        else if (typeName.Equals("string"))
                                        {
                                            Element possVals = param.GetElement("type").GetElement(0).GetElement("possibleValues");

                                            int numVals = possVals.NumValues;

                                            for (int v = 0; v < numVals; v++)
                                            {
                                                vals = vals + possVals.GetValueAsString(v) + ",";
                                            }
                                            if (vals.Length > 0) vals = vals.Substring(0, vals.Length - 1);
                                        }

                                        if (vals.Length > 0)
                                        {
                                            System.Console.WriteLine("\t\t\tType: " + typeName + " (" + vals + ")");
                                        }
                                        else
                                        {
                                            System.Console.WriteLine("\t\t\tType: " + typeName);
                                        }

                                    }

                                }

                            }
                            else
                            {
                                System.Console.WriteLine("\nBroker code: " + code + "\tclass: " + assetClass);
                                System.Console.WriteLine("\tNo Strategies");
                            }

                            System.Console.WriteLine("\n\tTime In Force:");
                            Element tifs = broker.GetElement("timesInForce");
                            int numTifs = tifs.NumValues;
                            for (int t = 0; t < numTifs; t++)
                            {
                                Element tif = tifs.GetValueAsElement(t);
                                String tifName = tif.GetElementAsString("name");
                                String tifFixValue = tif.GetElementAsString("fixValue");
                                System.Console.WriteLine("\t\tName: " + tifName + "\tFix Value: " + tifFixValue);
                            }

                            System.Console.WriteLine("\n\tOrder Types:");
                            Element ordTypes = broker.GetElement("orderTypes");
                            int numOrdTypes = ordTypes.NumValues;
                            for (int o = 0; o < numOrdTypes; o++)
                            {
                                Element ordType = ordTypes.GetValueAsElement(o);
                                String typName = ordType.GetElementAsString("name");
                                String typFixValue = ordType.GetElementAsString("fixValue");
                                System.Console.WriteLine("\t\tName: " + typName + "\tFix Value: " + typFixValue);
                            }

                            System.Console.WriteLine("\n\tHandling Instructions:");
                            Element handInsts = broker.GetElement("handlingInstructions");
                            int numHandInsts = handInsts.NumValues;
                            for (int h = 0; h < numHandInsts; h++)
                            {
                                Element handInst = handInsts.GetValueAsElement(h);
                                String instName = handInst.GetElementAsString("name");
                                String instFixValue = handInst.GetElementAsString("fixValue");
                                System.Console.WriteLine("\t\tName: " + instName + "\tFix Value: " + instFixValue);
                            }

                        }
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