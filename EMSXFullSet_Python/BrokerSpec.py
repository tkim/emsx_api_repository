# BrokerSpec.py

import blpapi
import sys


SESSION_STARTED         = blpapi.Name("SessionStarted")
SESSION_STARTUP_FAILURE = blpapi.Name("SessionStartupFailure")
SERVICE_OPENED          = blpapi.Name("ServiceOpened")
SERVICE_OPEN_FAILURE    = blpapi.Name("ServiceOpenFailure")
ERROR_INFO              = blpapi.Name("ErrorInfo")
BROKER_SPEC             = blpapi.Name("BrokerSpec")

d_service="//blp/emsx.brokerspec" # The BrokerSpec service is only available in the production environment
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

            elif event.eventType() == blpapi.Event.RESPONSE or event.eventType() == blpapi.Event.PARTIAL_RESPONSE:
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
    
                request = service.createRequest("GetBrokerSpecForUuid")

                request.set("uuid", 6767714) # Users UUID

                print ("Request: %s" % request.toString())
                    
                self.requestID = blpapi.CorrelationId()
                
                session.sendRequest(request, correlationId=self.requestID )
                            
            elif msg.messageType() == SERVICE_OPEN_FAILURE:
                print >> sys.stderr, ("Error: Service failed to open")        
                
    def processResponseEvent(self, event):
        print ("Processing RESPONSE event")
        
        for msg in event:
            
            #print ("MESSAGE: %s" % msg.toString())
            #print ("CORRELATION ID: %d" % msg.correlationIds()[0].value())


            if msg.correlationIds()[0].value() == self.requestID.value():
                print ("MESSAGE TYPE: %s" % msg.messageType())
                
                if msg.messageType() == ERROR_INFO:
                    errorCode = msg.getElementAsInteger("ERROR_CODE")
                    errorMessage = msg.getElementAsString("ERROR_MESSAGE")
                    print ("ERROR CODE: %d\tERROR MESSAGE: %s" % (errorCode,errorMessage))
                elif msg.messageType() == BROKER_SPEC:
                    
                    brokers=msg.getElement("brokers")
                    
                    num = brokers.numValues()
                    
                    print ("Number of Brokers: %d\n" % (num))
                    
                    for broker in brokers.values():
                        code = broker.getElement("code").getValue()
                        assetClass = broker.getElement("assetClass").getValue()
                        
                        if broker.hasElement("strategyFixTag"):
                            tag = broker.getElement("strategyFixTag").getValue()
                            print ("\nBroker code: %s\tclass: %s\ttag: %s" % (code,assetClass,tag))
                            strats = broker.getElement("strategies")
                            numStrats = strats.numValues()
                            print ("\tNo. of Strategies: %d" % (numStrats))
                            for strat in strats.values():
                                name = strat.getElement("name").getValue()
                                fixVal = strat.getElement("fixValue").getValue()
                                print ("\n\tStrategy Name: %s\tFix Value: %s" % (name,fixVal))
                                
                                parameters = strat.getElement("parameters")
                                
                                numParams = parameters.numValues()
                                
                                print ("\t\tNo. of Parameters: %d\n" % (numParams))
                                
                                for param in parameters.values():
                                    pname = param.getElement("name").getValue()
                                    tag = param.getElement("fixTag").getValue()
                                    required = param.getElement("isRequired").getValue()
                                    replaceable = param.getElement("isReplaceable").getValue()
                                    print ("\t\tParameter: %s\tTag: %d\tRequired: %s\tReplaceable: %s" % (pname,tag,required,replaceable))
                                    
                                    typeName = param.getElement("type").getElement(0).name()
                                    
                                    vals = ""
                                    
                                    if typeName=="enumeration":
                                        
                                        enumerators = param.getElement("type").getElement(0).getElement("enumerators")
                                        
                                        for enum in enumerators.values():
                                            vals = vals + enum.getElement("name").getValue() + "[" + enum.getElement("fixValue").getValue() + "],"

                                        if len(vals) > 0: vals = vals[:-1]
                                        
                                    
                                    elif typeName=="range":
                                        rng = param.getElement("type").getElement(0)
                                        mn = rng.getElement("min").getValue()
                                        mx = rng.getElement("max").getValue()
                                        st = rng.getElement("step").getValue()
                                        vals = "min:%d max:%d step:%d" % (mn,mx,st)
                                        
                                        
                                    elif typeName=="string":
                                        possVals = param.getElement("type").getElement(0).getElement("possibleValues")
                                        
                                        
                                        for val in possVals.values():
                                            vals = vals + val +","
                                            
                                        if len(vals) > 0: vals = vals[:-1]
                                        
                                    
                                    if len(vals) > 0:
                                        print ("\t\t\tType: %s (%s)" % (typeName, vals))           
                                    else:
                                        print ("\t\t\tType: %s" % (typeName))           

                        else:
                            print ("\nBroker code: %s\tclass: %s" % (code,assetClass))
                            print ("\tNo strategies\n")
                            
                        
                        print ("\tTime In Force:")
                        tifs = broker.getElement("timesInForce")
                        for tif in tifs.values():
                            tifName = tif.getElement("name").getValue()
                            tifFixValue = tif.getElement("fixValue").getValue()
                            print ("\t\tName: %s\tFix Value: %s" % (tifName, tifFixValue))
                        
                        print ("\n\tOrder Types:")
                        ordTypes = broker.getElement("orderTypes")
                        for ordType in ordTypes.values():
                            typName = ordType.getElement("name").getValue()
                            typFixValue = ordType.getElement("fixValue").getValue()
                            print ("\t\tName: %s\tFix Value: %s" % (typName, typFixValue))
                    
                        print ("\n\tHandling Instructions:")
                        handInsts = broker.getElement("handlingInstructions")
                        for handInst in handInsts.values():
                            instName = handInst.getElement("name").getValue()
                            instFixValue = handInst.getElement("fixValue").getValue()
                            print ("\t\tName: %s\tFix Value: %s" % (instName, instFixValue))

                if event.eventType() == blpapi.Event.RESPONSE :
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
    print ("Bloomberg - EMSX API Example - BrokerSpec")
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
