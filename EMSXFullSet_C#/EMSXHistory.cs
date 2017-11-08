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

namespace com.bloomberg.samples
{
    public class EMSXHistory
    {

        private static readonly Name SESSION_STARTED = new Name("SessionStarted");
        private static readonly Name SESSION_STARTUP_FAILURE = new Name("SessionStartupFailure");
        private static readonly Name SERVICE_OPENED = new Name("ServiceOpened");
        private static readonly Name SERVICE_OPEN_FAILURE = new Name("ServiceOpenFailure");

        private static readonly Name ERROR_INFO = new Name("ErrorInfo");
        private static readonly Name GET_FILLS_RESPONSE = new Name("GetFillsResponse");

        private string d_service;
        private string d_host;
        private int d_port;

        private static bool quit = false;

        private CorrelationID requestID;


        public static void Main(String[] args)
        {
            System.Console.WriteLine("Bloomberg - EMSX API Example - EMSXHistory\n");

            EMSXHistory example = new EMSXHistory();
            example.run(args);

            while (!quit) { };

            System.Console.WriteLine("Press any key...");
            System.Console.ReadKey();

        }

        public EMSXHistory()
        {

            // Define the service required, in this case the beta service, 
            // and the values to be used by the SessionOptions object
            // to identify IP/port of the back-end process.

            d_service = "//blp/emsx.history.uat";
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

                    Request request = service.CreateRequest("GetFills");

                    // The Date/Time values from and to may contain a timezone element
                    request.Set("FromDateTime", "2017-11-06T00:00:00.000+00:00");
                    request.Set("ToDateTime", "2017-11-06T23:59:00.000+00:00");

                    Element scope = request.GetElement("Scope");


                    // The name of the user team 
                    //scope.SetChoice("Team");
                    //scope.SetElement("Team", "RCAM_API");

                    // Use the Trading System view - boolean
                    //scope.SetChoice("TradingSystem");
                    //scope.SetElement("TradingSystem",False);

                    // One or more specified UUIDs
                    scope.SetChoice("Uuids");
                    scope.GetElement("Uuids").AppendValue(1234567);

                    //filterBy = request.GetElement("FilterBy");

                    // The backet name, as created in the terminal
                    //filterBy.SetChoice("Basket");
                    //filterBy.GetElement("Basket").AppendValue("TESTRJC");

                    // The Multileg ID, can append multiple values
                    //filterBy.SetChoice("Multileg");
                    //filterBy.GetElement("Multileg").AppendValue("12345");
                    //filterBy.GetElement("Multileg").AppendValue("56478");

                    // Specific order numbers and route IDs
                    //filterBy.SetChoice("OrdersAndRoutes");
                    //newOrder = filterBy.GetElement("OrdersAndRoutes").AppendElement();
                    //newOrder.SetElement("OrderId",2744093);
                    //newOrder.SetElement("RouteId",1);

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

                if (evt.Type == Event.EventType.RESPONSE && msg.CorrelationID == requestID)
                {

                    System.Console.WriteLine("Message Type: " + msg.MessageType);
                    if (msg.MessageType.Equals(ERROR_INFO))
                    {
                        int errorCode = msg.GetElementAsInt32("ERROR_CODE");
                        String errorMessage = msg.GetElementAsString("ERROR_MESSAGE");
                        System.Console.WriteLine("ERROR CODE: " + errorCode + "\tERROR MESSAGE: " + errorMessage);
                    }
                    else if (msg.MessageType.Equals(GET_FILLS_RESPONSE))
                    {
                        Element fills = msg.GetElement("Fills");

                        int numValues = fills.NumValues;

                        for (int i = 0; i < numValues; i++)
                        {

                            Element fill = fills.GetValueAsElement(i);

                            String account = fill.GetElementAsString("Account");
                            double amount = fill.GetElementAsFloat64("Amount");
                            String assetClass = fill.GetElementAsString("AssetClass");
                            int basketId = fill.GetElementAsInt32("BasketId");
                            String bbgid = fill.GetElementAsString("BBGID");
                            String blockId = fill.GetElementAsString("BlockId");
                            String broker = fill.GetElementAsString("Broker");
                            String clearingAccount = fill.GetElementAsString("ClearingAccount");
                            String clearingFirm = fill.GetElementAsString("ClearingFirm");
                            DateTime contractExpDate = fill.GetElementAsDate("ContractExpDate").ToSystemDateTime();
                            int correctedFillId = fill.GetElementAsInt32("CorrectedFillId");
                            String currency = fill.GetElementAsString("Currency");
                            String cusip = fill.GetElementAsString("Cusip");
                            DateTime dateTimeOfFill = fill.GetElementAsDate("DateTimeOfFill").ToSystemDateTime();
                            String exchange = fill.GetElementAsString("Exchange");
                            int execPrevSeqNo = fill.GetElementAsInt32("ExecPrevSeqNo");
                            String execType = fill.GetElementAsString("ExecType");
                            String executingBroker = fill.GetElementAsString("ExecutingBroker");
                            int fillId = fill.GetElementAsInt32("FillId");
                            double fillPrice = fill.GetElementAsFloat64("FillPrice");
                            double fillShares = fill.GetElementAsFloat64("FillShares");
                            String investorId = fill.GetElementAsString("InvestorID");
                            bool isCFD = fill.GetElementAsBool("IsCfd");
                            String isin = fill.GetElementAsString("Isin");
                            bool isLeg = fill.GetElementAsBool("IsLeg");
                            String lastCapacity = fill.GetElementAsString("LastCapacity");
                            String lastMarket = fill.GetElementAsString("LastMarket");
                            double limitPrice = fill.GetElementAsFloat64("LimitPrice");
                            String liquidity = fill.GetElementAsString("Liquidity");
                            String localExchangeSymbol = fill.GetElementAsString("LocalExchangeSymbol");
                            String locateBroker = fill.GetElementAsString("LocateBroker");
                            String locateId = fill.GetElementAsString("LocateId");
                            bool locateRequired = fill.GetElementAsBool("LocateRequired");
                            String multiLedId = fill.GetElementAsString("MultilegId");
                            String occSymbol = fill.GetElementAsString("OCCSymbol");
                            String orderExecutionInstruction = fill.GetElementAsString("OrderExecutionInstruction");
                            String orderHandlingInstruction = fill.GetElementAsString("OrderHandlingInstruction");
                            int orderId = fill.GetElementAsInt32("OrderId");
                            String orderInstruction = fill.GetElementAsString("OrderInstruction");
                            String orderOrigin = fill.GetElementAsString("OrderOrigin");
                            String orderReferenceId = fill.GetElementAsString("OrderReferenceId");
                            int originatingTraderUUId = fill.GetElementAsInt32("OriginatingTraderUuid");
                            String reroutedBroker = fill.GetElementAsString("ReroutedBroker");
                            double routeCommissionAmount = fill.GetElementAsFloat64("RouteCommissionAmount");
                            double routeCommissionRate = fill.GetElementAsFloat64("RouteCommissionRate");
                            String routeExecutionInstruction = fill.GetElementAsString("RouteExecutionInstruction");
                            String routeHandlingInstruction = fill.GetElementAsString("RouteHandlingInstruction");
                            int routeId = fill.GetElementAsInt32("RouteId");
                            double routeNetMoney = fill.GetElementAsFloat64("RouteNetMoney");
                            String routeNotes = fill.GetElementAsString("RouteNotes");
                            double routeShares = fill.GetElementAsFloat64("RouteShares");
                            String securityName = fill.GetElementAsString("SecurityName");
                            String sedol = fill.GetElementAsString("Sedol");
                            DateTime settlementDate = fill.GetElementAsDate("SettlementDate").ToSystemDateTime();
                            String side = fill.GetElementAsString("Side");
                            double stopPrice = fill.GetElementAsFloat64("StopPrice");
                            String strategyType = fill.GetElementAsString("StrategyType");
                            String ticker = fill.GetElementAsString("Ticker");
                            String tif = fill.GetElementAsString("TIF");
                            String traderName = fill.GetElementAsString("TraderName");
                            int traderUUId = fill.GetElementAsInt32("TraderUuid");
                            String type = fill.GetElementAsString("Type");
                            double userCommissionAmount = fill.GetElementAsFloat64("UserCommissionAmount");
                            double userCommissionRate = fill.GetElementAsFloat64("UserCommissionRate");
                            double userFees = fill.GetElementAsFloat64("UserFees");
                            double userNetMoney = fill.GetElementAsFloat64("UserNetMoney");
                            String yellowKey = fill.GetElementAsString("YellowKey");

                            System.Console.WriteLine("Order: " + orderId.ToString() + "\tDate/Time: " + dateTimeOfFill.ToString() + "\tTicker: " + ticker + "\tFill ID: " + fillId.ToString() + "\tShares: " + fillShares.ToString() + "\tPrice: " + fillPrice.ToString());

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
