# EMSXRouteAsSpread.py

import blpapi
import sys


SESSION_STARTED         = blpapi.Name("SessionStarted")
SESSION_STARTUP_FAILURE = blpapi.Name("SessionStartupFailure")
SERVICE_OPENED          = blpapi.Name("ServiceOpened")
SERVICE_OPEN_FAILURE    = blpapi.Name("ServiceOpenFailure")
ERROR_INFO              = blpapi.Name("ErrorInfo")
GROUP_ROUTE_EX          = blpapi.Name("GroupRouteEx")
CREATE_ORDER            = blpapi.Name("CreateOrder")

d_service="//blp/emapisvc_beta"
d_host="localhost"
d_port=8194
bEnd=False


class SessionEventHandler():

    def __init__(self):
        
        self.buyCorrID=0
        self.sellCorrID=0
        self.buySeqNo=0
        self.sellSeqNo=0
        self.requestID=0
        
    def processEvent(self, event, session):
        try:
            if event.eventType() == blpapi.Event.SESSION_STATUS:
                self.processSessionStatusEvent(event,session)
            
            elif event.eventType() == blpapi.Event.SERVICE_STATUS:
                self.processServiceStatusEvent(event,session)

            elif event.eventType() == blpapi.Event.RESPONSE:
                self.processResponseEvent(event, session)
            
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

                self.service = session.getService(d_service)
    
                self.createBuyOrder(session)
                
            elif msg.messageType() == SERVICE_OPEN_FAILURE:
                print >> sys.stderr, ("Error: Service failed to open")
                
    def processResponseEvent(self, event, session):
        print ("Processing RESPONSE event")
        
        for msg in event:
            
            print ("MESSAGE: %s" % msg.toString())
            print ("CORRELATION ID: %d" % msg.correlationIds()[0].value())

            if msg.correlationIds()[0].value() == self.buyCorrID.value():
                print ("MESSAGE TYPE: %s" % msg.messageType())
                
                if msg.messageType() == ERROR_INFO:
                    errorCode = msg.getElementAsInteger("ERROR_CODE")
                    errorMessage = msg.getElementAsString("ERROR_MESSAGE")
                    print ("Failed to create buy order >> ERROR CODE: %d\tERROR MESSAGE: %s" % (errorCode,errorMessage))
                elif msg.messageType() == CREATE_ORDER:
                    self.buySeqNo = msg.getElementAsInteger("EMSX_SEQUENCE")
                    message = msg.getElementAsString("MESSAGE")
                    print ("Buy order created >> EMSX_SEQUENCE: %d\tMESSAGE: %s" % (self.buySeqNo ,message))
                
                if self.sellSeqNo > 0: # already received sell order response
                    self.routeSpread(session)
                else:
                    self.createSellOrder(session)


            elif msg.correlationIds()[0].value() == self.sellCorrID.value():
                print ("MESSAGE TYPE: %s" % msg.messageType())
                
                if msg.messageType() == ERROR_INFO:
                    errorCode = msg.getElementAsInteger("ERROR_CODE")
                    errorMessage = msg.getElementAsString("ERROR_MESSAGE")
                    print ("Failed to create sell order >> ERROR CODE: %d\tERROR MESSAGE: %s" % (errorCode,errorMessage))
                elif msg.messageType() == CREATE_ORDER:
                    self.sellSeqNo = msg.getElementAsInteger("EMSX_SEQUENCE")
                    message = msg.getElementAsString("MESSAGE")
                    print ("Sell order created >> EMSX_SEQUENCE: %d\tMESSAGE: %s" % (self.sellSeqNo ,message))
                
                if self.buySeqNo > 0: # already received buy order response
                    self.routeSpread(session)
                else:
                    self.createBuyOrder(session)

                
            elif msg.correlationIds()[0].value() == self.requestID.value():
                print ("MESSAGE TYPE: %s" % msg.messageType())
                
                if msg.messageType() == ERROR_INFO:
                    errorCode = msg.getElementAsInteger("ERROR_CODE")
                    errorMessage = msg.getElementAsString("ERROR_MESSAGE")
                    print ("ERROR CODE: %d\tERROR MESSAGE: %s" % (errorCode,errorMessage))
                elif msg.messageType() == GROUP_ROUTE_EX:

                    if(msg.hasElement("EMSX_SUCCESS_ROUTES")):
                        success = msg.getElement("EMSX_SUCCESS_ROUTES")

                        nV = success.numValues()
                        
                        for i in range(0,nV):
                            e = success.getValueAsElement(i)
                            sq = e.getElementAsInteger("EMSX_SEQUENCE")
                            rid = e.getElementAsInteger("EMSX_ROUTE_ID")

                            print ("SUCCESS: %d,%d" % (sq,rid))
                    
                    if(msg.hasElement("EMSX_FAILED_ROUTES")):
                        failed = msg.getElement("EMSX_FAILED_ROUTES")

                        nV = failed.numValues()
                        
                        for i in range(0,nV):
                            e = failed.getValueAsElement(i)
                            sq = e.getElementAsInteger("EMSX_SEQUENCE")

                            print ("FAILED: %d" % (sq))


                    ''' 
********************************                    
Expected Sample Output
********************************

Bloomberg - EMSX API Example - EMSXRouteAsSpread
Connecting to localhost:8194
Processing SESSION_STATUS event
SessionConnectionUp = {
    server = "localhost:8194"
}

Processing SESSION_STATUS event
Session started...
Processing SERVICE_STATUS event
Service opened...
Request: CreateOrder = {
    EMSX_TICKER = "CLN7 Comdty"
    EMSX_AMOUNT = 100
    EMSX_ORDER_TYPE = MKT
    EMSX_TIF = DAY
    EMSX_HAND_INSTRUCTION = "ANY"
    EMSX_SIDE = BUY
}

Processing RESPONSE event
MESSAGE: CreateOrder = {
    EMSX_SEQUENCE = 3952712
    MESSAGE = "Order created"
}

CORRELATION ID: 5
MESSAGE TYPE: CreateOrder
Buy order created >> EMSX_SEQUENCE: 3952712    MESSAGE: Order created
Request: CreateOrder = {
    EMSX_TICKER = "CLQ7 Comdty"
    EMSX_AMOUNT = 100
    EMSX_ORDER_TYPE = MKT
    EMSX_TIF = DAY
    EMSX_HAND_INSTRUCTION = "ANY"
    EMSX_SIDE = SELL
}

Processing RESPONSE event
MESSAGE: CreateOrder = {
    EMSX_SEQUENCE = 3952713
    MESSAGE = "Order created"
}

CORRELATION ID: 6
MESSAGE TYPE: CreateOrder
Sell order created >> EMSX_SEQUENCE: 3952713    MESSAGE: Order created
Request: GroupRouteEx = {
    EMSX_SEQUENCE[] = {
        3952712, 3952713
    }
    EMSX_AMOUNT_PERCENT = 100
    EMSX_BROKER = "ETI"
    EMSX_HAND_INSTRUCTION = "ANY"
    EMSX_ORDER_TYPE = MKT
    EMSX_TIF = DAY
    EMSX_TICKER = "CLN7 Comdty"
    EMSX_RELEASE_TIME = -1
    EMSX_REQUEST_TYPE = {
        Spread = {
        }
    }
}

Processing RESPONSE event
MESSAGE: GroupRouteEx = {
    EMSX_SUCCESS_ROUTES[] = {
        EMSX_SUCCESS_ROUTES = {
            EMSX_SEQUENCE = 3952712
            EMSX_ROUTE_ID = 1
        }
        EMSX_SUCCESS_ROUTES = {
            EMSX_SEQUENCE = 3952713
            EMSX_ROUTE_ID = 1
        }
    }
    EMSX_FAILED_ROUTES[] = {
    }
    MESSAGE = "2 of 2 Order(s) Routed"
    EMSX_ML_ID = "1496247061:284950582"
}

CORRELATION ID: 7
MESSAGE TYPE: GroupRouteEx
SUCCESS: 3952712,1
SUCCESS: 3952713,1
Processing SESSION_STATUS event
SessionConnectionDown = {
    server = "localhost:8194"
}

Processing SESSION_STATUS event
SessionTerminated = {
}

********************************

                '''
                            
                global bEnd
                bEnd = True
                
    def processMiscEvents(self, event):
        
        print ("Processing " + event.eventType() + " event")
        
        for msg in event:

            print ("MESSAGE: %s" % (msg.tostring()))


    def createBuyOrder(self, session):
        
        request = self.service.createRequest("CreateOrder")

        # The fields below are mandatory
        request.set("EMSX_TICKER", "CLN7 Comdty")
        request.set("EMSX_AMOUNT", 100)
        request.set("EMSX_ORDER_TYPE", "MKT")
        request.set("EMSX_TIF", "DAY")
        request.set("EMSX_HAND_INSTRUCTION", "ANY")
        request.set("EMSX_SIDE", "BUY")
        
        print ("Request: %s" % request.toString())
                    
        self.buyCorrID = blpapi.CorrelationId()
                
        session.sendRequest(request, correlationId=self.buyCorrID)
        
    def createSellOrder(self, session):

        request = self.service.createRequest("CreateOrder")

        # The fields below are mandatory
        request.set("EMSX_TICKER", "CLQ7 Comdty")
        request.set("EMSX_AMOUNT", 100)
        request.set("EMSX_ORDER_TYPE", "MKT")
        request.set("EMSX_TIF", "DAY")
        request.set("EMSX_HAND_INSTRUCTION", "ANY")
        request.set("EMSX_SIDE", "SELL")
        
        print ("Request: %s" % request.toString())
                    
        self.sellCorrID = blpapi.CorrelationId()
                
        session.sendRequest(request, correlationId=self.sellCorrID )
    
    def routeSpread(self, session):
        
        request = self.service.createRequest("GroupRouteEx")

        request.append("EMSX_SEQUENCE", self.buySeqNo) 
        request.append("EMSX_SEQUENCE", self.sellSeqNo) 
        request.set("EMSX_AMOUNT_PERCENT", 100)
        request.set("EMSX_BROKER", "EFIX");
        request.set("EMSX_HAND_INSTRUCTION", "ANY")
        request.set("EMSX_ORDER_TYPE", "MKT")
        request.set("EMSX_TIF", "DAY")
        request.set("EMSX_TICKER","CLN7 Comdty")
        request.set("EMSX_RELEASE_TIME",-1)
        requestType = request.getElement("EMSX_REQUEST_TYPE") 
        requestType.setChoice("Spread")
    
        print ("Request: %s" % request.toString())
            
        self.requestID = blpapi.CorrelationId()
        
        session.sendRequest(request, correlationId=self.requestID )

    
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
    print ("Bloomberg - EMSX API Example - EMSXRouteAsSpread")
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
