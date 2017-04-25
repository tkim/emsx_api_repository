# AssignTrader.py

import sys

import blpapi


SESSION_STARTED         = blpapi.Name("SessionStarted")
SESSION_STARTUP_FAILURE = blpapi.Name("SessionStartupFailure")
SERVICE_OPENED          = blpapi.Name("ServiceOpened")
SERVICE_OPEN_FAILURE    = blpapi.Name("ServiceOpenFailure")
ERROR_INFO              = blpapi.Name("ErrorInfo")
ASSIGN_TRADER           = blpapi.Name("AssignTrader")

d_service="//blp/emapisvc_beta"
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
            print "Exception:  %s" % sys.exc_info()[0]
            
        return False


    def processSessionStatusEvent(self,event,session):
        print "Processing SESSION_STATUS event"

        for msg in event:
            if msg.messageType() == SESSION_STARTED:
                print "Session started..."
                session.openServiceAsync(d_service)
                
            elif msg.messageType() == SESSION_STARTUP_FAILURE:
                print >> sys.stderr, "Error: Session startup failed"
                
            else:
                print msg
                

    def processServiceStatusEvent(self,event,session):
        print "Processing SERVICE_STATUS event"
        
        for msg in event:
            
            if msg.messageType() == SERVICE_OPENED:
                print "Service opened..."

                service = session.getService(d_service)
    
                request = service.createRequest("AssignTrader")
                
                request.append("EMSX_SEQUENCE", 3744303)
                request.append("EMSX_SEQUENCE", 3744341)

                request.set("EMSX_ASSIGNEE_TRADER_UUID", 12109783)
            
                print "Request: %s" % request.toString()
                    
                self.requestID = blpapi.CorrelationId()
                
                session.sendRequest(request, correlationId=self.requestID )
                            
            elif msg.messageType() == SERVICE_OPEN_FAILURE:
                print >> sys.stderr, "Error: Service failed to open"        
                
    def processResponseEvent(self, event):
        print "Processing RESPONSE event"
        
        for msg in event:
            
            print "MESSAGE: %s" % msg.toString()
            print "CORRELATION ID: %d" % msg.correlationIds()[0].value()


            if msg.correlationIds()[0].value() == self.requestID.value():
                print "MESSAGE TYPE: %s" % msg.messageType()
                
                if msg.messageType() == ERROR_INFO:
                    errorCode = msg.getElementAsInteger("ERROR_CODE")
                    errorMessage = msg.getElementAsString("ERROR_MESSAGE")
                    print "ERROR CODE: %d\tERROR MESSAGE: %s" % (errorCode,errorMessage)
                elif msg.messageType() == ASSIGN_TRADER:
                    success = msg.getElementAsBool("EMSX_ALL_SUCCESS")
                    if success:
                        print "All orders successfully assigned"
                        successful = msg.getElement("EMSX_ASSIGN_TRADER_SUCCESSFUL_ORDERS") 
                        
                        if successful.numValues() > 0: print "Successful assignments:-"

                        for order in successful.values():
                            seq = order.getElement("EMSX_SEQUENCE").getValue()
                            print seq

                    else:
                        print "One or more failed assignments...\n"
                        
                        if msg.hasElement("EMSX_ASSIGN_TRADER_SUCCESSFUL_ORDERS"):
                            successful = msg.getElement("EMSX_ASSIGN_TRADER_SUCCESSFUL_ORDERS") 
                            
                            if successful.numValues() > 0: print "Successful assignments:-"

                            for order in successful.values():
                                seq = order.getElement("EMSX_SEQUENCE").getValue()
                                print seq
                                
                            
                        if msg.hasElement("EMSX_ASSIGN_TRADER_FAILED_ORDERS"):
                            failed = msg.getElement("EMSX_ASSIGN_TRADER_FAILED_ORDERS")

                            if failed.numValues() > 0: print "Failed assignments:-"

                            for order in failed.values():
                                seq = order.getElement("EMSX_SEQUENCE").getValue()
                                print seq

                global bEnd
                bEnd = True
                
    def processMiscEvents(self, event):
        
        print "Processing " + event.eventType() + " event"
        
        for msg in event:

            print "MESSAGE: %s" % (msg.tostring())


def main():
    
    sessionOptions = blpapi.SessionOptions()
    sessionOptions.setServerHost(d_host)
    sessionOptions.setServerPort(d_port)

    print "Connecting to %s:%d" % (d_host,d_port)

    eventHandler = SessionEventHandler()

    session = blpapi.Session(sessionOptions, eventHandler.processEvent)

    if not session.startAsync():
        print "Failed to start session."
        return
    
    global bEnd
    while bEnd==False:
        pass
    
    session.stop()
    
if __name__ == "__main__":
    print "Bloomberg - EMSX API Example - AssignTrader"
    try:
        main()
    except KeyboardInterrupt:
        print "Ctrl+C pressed. Stopping..."


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
