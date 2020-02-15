# EMSXHistory.py

import blpapi
import sys


SESSION_STARTED         = blpapi.Name("SessionStarted")
SESSION_STARTUP_FAILURE = blpapi.Name("SessionStartupFailure")
SERVICE_OPENED          = blpapi.Name("ServiceOpened")
SERVICE_OPEN_FAILURE    = blpapi.Name("ServiceOpenFailure")
ERROR_INFO              = blpapi.Name("ErrorInfo")
GET_FILLS_RESPONSE      = blpapi.Name("GetFillsResponse")

d_service="//blp/emsx.history.uat"
d_host="localhost"
d_port=8194
bEnd=False

class SessionEventHandler():

    def processEvent(self, event, session):
        try:
            if event.eventType() == blpapi.Event.SESSION_STATUS:
                self.processSessionStatusEvent(event,session)
            
            elif event.eventType() == blpapi.Event.SERVICE_STATUS:
                self.processServiceStatusEvent(event,session)

            elif event.eventType() == blpapi.Event.RESPONSE:
                self.processResponseEvent(event)
            
            else:
                self.processMiscEvents(event)
                
        except:
            print ("Exception:  %s" % sys.exc_info()[0])
            
        return False


    def processSessionStatusEvent(self,event,session):
        print ("Processing SESSION_STATUS event")

        for msg in event:
            if msg.messageType() == SESSION_STARTED:
                print ("Session started...")
                session.openServiceAsync(d_service)
                
            elif msg.messageType() == SESSION_STARTUP_FAILURE:
                print >> sys.stderr, ("Error: Session startup failed")
                
            else:
                print (msg)
                

    def processServiceStatusEvent(self,event,session):
        print ("Processing SERVICE_STATUS event")
        
        for msg in event:
            
            if msg.messageType() == SERVICE_OPENED:
                print ("Service opened...")

                service = session.getService(d_service)
    
                request = service.createRequest("GetFills")

                request.set("FromDateTime", "2017-11-03T00:00:00.000+00:00")
                request.set("ToDateTime", "2017-11-03T23:59:00.000+00:00")

                scope = request.getElement("Scope")
                
                #scope.setChoice("Team") # Team Name
                #scope.setChoice("TradingSystem") # AIM Px#
                scope.setChoice("Uuids") # UUID 
                
                #scope.setElement("Team", "MyTeamName")
                #scope.setElement("TradingSystem", True) # no need to specify px# this will be picked up based on the login.
                
                scope.getElement("Uuids").appendValue(1234) # User's UUID

                #scope.getElement("Uuids").appendValue(12345);
                #scope.getElement("Uuids").appendValue(123456);
                #scope.getElement("Uuids").appendValue(1234567);
                                
                #filter = request.getElement("FilterBy")
                
                #filter.setChoice("Basket")
                #filter.setChoice("Multileg")
                #filter.setChoice("OrdersAndRoutes")
                
                #filter.getElement("Basket").appendValue("TESTRJC")
                #filter.getElement("Multileg").appendValue("mymlegId")
                
                #newOrder = filter.getElement("OrdersAndRoutes").appendElement()
                #newOrder.setElement("OrderId",4292580)
                #newOrder.setElement("RouteId",1)
                
                print ("Request: %s" % request.toString())
                    
                self.requestID = blpapi.CorrelationId()
                
                session.sendRequest(request, correlationId=self.requestID )
                            
            elif msg.messageType() == SERVICE_OPEN_FAILURE:
                print >> sys.stderr, ("Error: Service failed to open")        
                
    def processResponseEvent(self, event):
        print ("Processing RESPONSE event")
        
        for msg in event:

            if msg.correlationIds()[0].value() == self.requestID.value():
                print ("MESSAGE TYPE: %s" % msg.messageType())
                
                if msg.messageType() == ERROR_INFO:
                    errorCode = msg.getElementAsInteger("ErrorCode")
                    errorMessage = msg.getElementAsString("ErrorMsg")
                    print ("ERROR CODE: %d\tERROR MESSAGE: %s" % (errorCode,errorMessage))
                elif msg.messageType() == GET_FILLS_RESPONSE:

                    fills = msg.getElement("Fills")
                    
                    for fill in fills.values():

                        #account = fill.getElement("Account").getValueAsString()
                        #amount = fill.getElement("Amount").getValueAsFloat()
                        #assetClass = fill.getElement("AssetClass").getValueAsString()
                        #basketId = fill.getElement("BasketId").getValueAsInteger()
                        #bbgid = fill.getElement("BBGID").getValueAsString()
                        #blockId = fill.getElement("BlockId").getValueAsString()
                        #broker = fill.getElement("Broker").getValueAsString()
                        #clearingAccount = fill.getElement("ClearingAccount").getValueAsString()
                        #clearingFirm = fill.getElement("ClearingFirm").getValueAsString()
                        #contractExpDate = fill.getElement("ContractExpDate").getValueAsString()
                        #correctedFillId = fill.getElement("CorrectedFillId").getValueAsInteger()
                        #currency = fill.getElement("Currency").getValueAsString()
                        #cusip = fill.getElement("Cusip").getValueAsString()
                        dateTimeOfFill = fill.getElement("DateTimeOfFill").getValueAsString()
                        #exchange = fill.getElement("Exchange").getValueAsString()
                        #execPrevSeqNo = fill.getElement("ExecPrevSeqNo").getValueAsInteger()
                        #execType = fill.getElement("ExecType").getValueAsString()
                        #executingBroker = fill.getElement("ExecutingBroker").getValueAsString()
                        fillId = fill.getElement("FillId").getValueAsInteger()
                        fillPrice = fill.getElement("FillPrice").getValueAsFloat()
                        fillShares = fill.getElement("FillShares").getValueAsFloat()
                        #investorId = fill.getElement("InvestorID").getValueAsString()
                        #isCFD = fill.getElement("IsCfd").getValueAsBool()
                        #isin = fill.getElement("Isin").getValueAsString()
                        #isLeg = fill.getElement("IsLeg").getValueAsBool()
                        #lastCapacity = fill.getElement("LastCapacity").getValueAsString()
                        #lastMarket = fill.getElement("LastMarket").getValueAsString()
                        #limitPrice = fill.getElement("LimitPrice").getValueAsFloat()
                        #liquidity = fill.getElement("Liquidity").getValueAsString()
                        #localExchangeSymbol = fill.getElement("LocalExchangeSymbol").getValueAsString()
                        #locateBroker = fill.getElement("LocateBroker").getValueAsString()
                        #locateId = fill.getElement("LocateId").getValueAsString()
                        #locateRequired = fill.getElement("LocateRequired").getValueAsBool()
                        #multiLedId = fill.getElement("MultilegId").getValueAsString()
                        #occSymbol = fill.getElement("OCCSymbol").getValueAsString()
                        #orderExecutionInstruction = fill.getElement("OrderExecutionInstruction").getValueAsString()
                        #orderHandlingInstruction = fill.getElement("OrderHandlingInstruction").getValueAsString()
                        orderId = fill.getElement("OrderId").getValueAsInteger()
                        #orderInstruction = fill.getElement("OrderInstruction").getValueAsString()
                        #orderOrigin = fill.getElement("OrderOrigin").getValueAsString()
                        #orderReferenceId = fill.getElement("OrderReferenceId").getValueAsString()
                        #originatingTraderUUId = fill.getElement("OriginatingTraderUuid").getValueAsInteger()
                        #reroutedBroker = fill.getElement("ReroutedBroker").getValueAsString()
                        #routeCommissionAmount = fill.getElement("RouteCommissionAmount").getValueAsFloat()
                        #routeCommissionRate = fill.getElement("RouteCommissionRate").getValueAsFloat()
                        #routeExecutionInstruction = fill.getElement("RouteExecutionInstruction").getValueAsString()
                        #routeHandlingInstruction = fill.getElement("RouteHandlingInstruction").getValueAsString()
                        #routeId = fill.getElement("RouteId").getValueAsInteger()
                        #routeNetMoney = fill.getElement("RouteNetMoney").getValueAsFloat()
                        #routeNotes = fill.getElement("RouteNotes").getValueAsString()
                        #routeShares = fill.getElement("RouteShares").getValueAsFloat()
                        #securityName = fill.getElement("SecurityName").getValueAsString()
                        #sedol = fill.getElement("Sedol").getValueAsString()
                        #settlementDate = fill.getElement("SettlementDate").getValueAsString()
                        #side = fill.getElement("Side").getValueAsString()
                        #stopPrice = fill.getElement("StopPrice").getValueAsFloat()
                        #strategyType = fill.getElement("StrategyType").getValueAsString()
                        #ticker = fill.getElement("Ticker").getValueAsString()
                        #tif = fill.getElement("TIF").getValueAsString()
                        #traderName = fill.getElement("TraderName").getValueAsString()
                        #traderUUId = fill.getElement("TraderUuid").getValueAsInteger()
                        #type = fill.getElement("Type").getValueAsString()
                        #userCommissionAmount = fill.getElement("UserCommissionAmount").getValueAsFloat()
                        #userCommissionRate = fill.getElement("UserCommissionRate").getValueAsFloat()
                        #userFees = fill.getElement("UserFees").getValueAsFloat()
                        #userNetMoney = fill.getElement("UserNetMoney").getValueAsFloat()
                        #yellowKey = fill.getElement("YellowKey").getValueAsString()
                            
                        print ("OrderId: %d\tFill ID: %d\tDate/Time: %s\tShares: %f\tPrice: %f" % (orderId,fillId, dateTimeOfFill, fillShares, fillPrice))
                            
                global bEnd
                bEnd = True
                
    def processMiscEvents(self, event):
        
        print ("Processing " + event.eventType() + " event")
        
        for msg in event:

            print ("MESSAGE: %s" % (msg.tostring()))


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
    
    global bEnd
    while bEnd==False:
        pass
    
    session.stop()
    
if __name__ == "__main__":
    print ("Bloomberg - EMSX API Example - EMSXHistory")
    try:
        main()
    except KeyboardInterrupt:
        print ("Ctrl+C pressed. Stopping...")


__copyright__ = """
Copyright 2017. Bloomberg Finance L.P.

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
