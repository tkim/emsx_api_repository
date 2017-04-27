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
#include "BlpThreadUtil.h"

#include <blpapi_correlationid.h>
#include <blpapi_element.h>
#include <blpapi_event.h>
#include <blpapi_message.h>
#include <blpapi_name.h>
#include <blpapi_session.h>
#include <blpapi_subscriptionlist.h>

#include <cassert>
#include <iostream>
#include <set>
#include <sstream>
#include <string>
#include <time.h>
#include <vector>

using namespace BloombergLP;
using namespace blpapi;

namespace {

	Name SESSION_STARTED("SessionStarted");
	Name SESSION_STARTUP_FAILURE("SessionStartupFailure");
	Name SERVICE_OPENED("ServiceOpened");
	Name SERVICE_OPEN_FAILURE("ServiceOpenFailure");
	Name ERROR_INFO("ErrorInfo");
	Name BROKER_SPEC("BrokerSpec");

	const std::string d_service("//blp/emsx.brokerspec"); //The BrokerSpec service is only available in the production environment
	CorrelationId requestID;

}

class ConsoleOut
{
private:
	std::ostringstream  d_buffer;
	Mutex              *d_consoleLock;
	std::ostream&       d_stream;

	// NOT IMPLEMENTED
	ConsoleOut(const ConsoleOut&);
	ConsoleOut& operator=(const ConsoleOut&);

public:
	explicit ConsoleOut(Mutex         *consoleLock,
		std::ostream&  stream = std::cout)
		: d_consoleLock(consoleLock)
		, d_stream(stream)
	{}

	~ConsoleOut() {
		MutexGuard guard(d_consoleLock);
		d_stream << d_buffer.str();
		d_stream.flush();
	}

	template <typename T>
	std::ostream& operator<<(const T& value) {
		return d_buffer << value;
	}

	std::ostream& stream() {
		return d_buffer;
	}
};

struct SessionContext
{
	Mutex            d_consoleLock;
	Mutex            d_mutex;
	bool             d_isStopped;
	SubscriptionList d_subscriptions;

	SessionContext()
		: d_isStopped(false)
	{
	}
};

class EMSXEventHandler : public EventHandler
{
	bool                     d_isSlow;
	SubscriptionList         d_pendingSubscriptions;
	std::set<CorrelationId>  d_pendingUnsubscribe;
	SessionContext          *d_context_p;
	Mutex                   *d_consoleLock_p;

	bool processSessionEvent(const Event &event, Session *session)
	{

		ConsoleOut(d_consoleLock_p) << "Processing SESSION_EVENT" << std::endl;

		MessageIterator msgIter(event);
		while (msgIter.next()) {

			Message msg = msgIter.message();

			if (msg.messageType() == SESSION_STARTED) {
				ConsoleOut(d_consoleLock_p) << "Session started..." << std::endl;
				session->openServiceAsync(d_service.c_str());
			}
			else if (msg.messageType() == SESSION_STARTUP_FAILURE) {
				ConsoleOut(d_consoleLock_p) << "Session startup failed" << std::endl;
				return false;
			}
		}
		return true;
	}

	bool processServiceEvent(const Event &event, Session *session)
	{

		ConsoleOut(d_consoleLock_p) << "Processing SERVICE_EVENT" << std::endl;

		MessageIterator msgIter(event);
		while (msgIter.next()) {

			Message msg = msgIter.message();

			if (msg.messageType() == SERVICE_OPENED) {
				ConsoleOut(d_consoleLock_p) << "Service opened..." << std::endl;

				Service service = session->getService(d_service.c_str());

				Request request = service.createRequest("GetBrokerSpecForUuid");
				request.set("uuid", 8049857);

				ConsoleOut(d_consoleLock_p) << "Request: " << request << std::endl;

				requestID = CorrelationId();

				session->sendRequest(request, requestID);

			}
			else if (msg.messageType() == SERVICE_OPEN_FAILURE) {
				ConsoleOut(d_consoleLock_p) << "Error: Service failed to open" << std::endl;
				return false;
			}

		}
		return true;
	}

	bool processResponseEvent(const Event &event, Session *session)
	{
		ConsoleOut(d_consoleLock_p) << "Processing RESPONSE_EVENT" << std::endl;

		MessageIterator msgIter(event);
		while (msgIter.next()) {

			Message msg = msgIter.message();

			//ConsoleOut(d_consoleLock_p) << "MESSAGE: " << msg << std::endl;

			if (msg.messageType() == ERROR_INFO) {

				int errorCode = msg.getElementAsInt32("ERROR_CODE");
				std::string errorMessage = msg.getElementAsString("ERROR_MESSAGE");

				ConsoleOut(d_consoleLock_p) << "ERROR CODE: " << errorCode << "\tERROR MESSAGE: " << errorMessage << std::endl;
			}
			else if (msg.messageType() == BROKER_SPEC) {

				Element brokers = msg.getElement("brokers");

				int numBkrs = brokers.numValues();

				ConsoleOut(d_consoleLock_p) << "Number of Brokers: " << numBkrs << std::endl;

				for (int i = 0; i < numBkrs; i++) {

					Element broker = brokers.getValueAsElement(i);

					std::string code = broker.getElementAsString("code");
					std::string assetClass = broker.getElementAsString("assetClass");

					if (broker.hasElement("strategyFixTag")) {
						long tag = broker.getElementAsInt64("strategyFixTag");
						ConsoleOut(d_consoleLock_p) << "\nBroker code: " << code << "\tClass: " << assetClass << "\tTag: " << tag << std::endl;

						Element strats = broker.getElement("strategies");

						int numStrats = strats.numValues();

						ConsoleOut(d_consoleLock_p) << "\tNo. of Strategies: " << numStrats << std::endl;

						for (int s = 0; s < numStrats; s++) {

							Element strat = strats.getValueAsElement(s);

							std::string name = strat.getElementAsString("name");
							std::string fixVal = strat.getElementAsString("fixValue");

							ConsoleOut(d_consoleLock_p) << "\n\tStrategy Name: " << name << "\tFix Value: " << fixVal << std::endl;

							Element parameters = strat.getElement("parameters");

							int numParams = parameters.numValues();

							ConsoleOut(d_consoleLock_p) << "\t\tNo. of Parameters: " << numParams << std::endl;

							for (int p = 0; p < numParams; p++) {

								Element param = parameters.getValueAsElement(p);

								std::string pname = param.getElementAsString("name");
								long fixTag = param.getElementAsInt64("fixTag");
								std::string required = param.getElementAsString("isRequired");
								std::string replaceable = param.getElementAsString("isReplaceable");

								ConsoleOut(d_consoleLock_p) << "\t\tParameter: " << pname << "\tTag: " << fixTag << "\tRequired: " << required << "\tReplaceable: " << replaceable << std::endl;

								std::string typeName = param.getElement("type").getChoice().name().string();

								std::string vals = "";

								if (typeName == "enumeration") {
									Element enumerators = param.getElement("type").getElement((size_t)0).getElement("enumerators");

									int numEnums = enumerators.numValues();

									for (int e = 0; e < numEnums; e++) {
										Element en = enumerators.getValueAsElement(e);

										vals = vals + en.getElementAsString("name") + "[" + en.getElementAsString("fixValue") + "],";
									}
									vals = vals.substr(0, vals.length() - 1);
								}
								else if (typeName == "range") {
									Element rng = param.getElement("type").getElement((size_t)0);
									long mn = rng.getElementAsInt64("min");
									long mx = rng.getElementAsInt64("max");
									long st = rng.getElementAsInt64("step");
									vals = "min:" + std::to_string(mn) + " max:" + std::to_string(mx) + " step:" + std::to_string(st);
								}
								else if (typeName == "string") {
									Element possVals = param.getElement("type").getElement((size_t)0).getElement("possibleValues");

									int numVals = possVals.numValues();

									for (int v = 0; v < numVals; v++) {
										vals = vals + possVals.getValueAsString(v) + ",";
									}
									if (vals.length()>0) vals = vals.substr(0, vals.length() - 1);
								}

								if (vals.length() > 0) {
									ConsoleOut(d_consoleLock_p) << "\t\t\tType: " << typeName << " (" << vals << ")" << std::endl;
								}
								else {
									ConsoleOut(d_consoleLock_p) << "\t\t\tType: " << typeName << std::endl;
								}

							}

						}

					}
					else {
						ConsoleOut(d_consoleLock_p) << "\nBroker code: " << code << "\tclass: " << assetClass << std::endl;
						ConsoleOut(d_consoleLock_p) << "\tNo Strategies" << std::endl;
					}

					ConsoleOut(d_consoleLock_p) << "\n\tTime In Force:" << std::endl;
					Element tifs = broker.getElement("timesInForce");
					int numTifs = tifs.numValues();
					for (int t = 0; t<numTifs; t++) {
						Element tif = tifs.getValueAsElement(t);
						std::string tifName = tif.getElementAsString("name");
						std::string tifFixValue = tif.getElementAsString("fixValue");
						ConsoleOut(d_consoleLock_p) << "\t\tName: " << tifName << "\tFix Value: " << tifFixValue << std::endl;
					}

					ConsoleOut(d_consoleLock_p) << "\n\tOrder Types:" << std::endl;
					Element ordTypes = broker.getElement("orderTypes");
					int numOrdTypes = ordTypes.numValues();
					for (int o = 0; o<numOrdTypes; o++) {
						Element ordType = ordTypes.getValueAsElement(o);
						std::string typName = ordType.getElementAsString("name");
						std::string typFixValue = ordType.getElementAsString("fixValue");
						ConsoleOut(d_consoleLock_p) << "\t\tName: " << typName << "\tFix Value: " << typFixValue << std::endl;
					}

					ConsoleOut(d_consoleLock_p) << "\n\tHandling Instructions:" << std::endl;
					Element handInsts = broker.getElement("handlingInstructions");
					int numHandInsts = handInsts.numValues();
					for (int h = 0; h<numHandInsts; h++) {
						Element handInst = handInsts.getValueAsElement(h);
						std::string instName = handInst.getElementAsString("name");
						std::string instFixValue = handInst.getElementAsString("fixValue");
						ConsoleOut(d_consoleLock_p) << "\t\tName: " << instName << "\tFix Value: " << instFixValue << std::endl;
					}
				}
			}
		}
		return true;
	}

	bool processMiscEvents(const Event &event)
	{
		ConsoleOut(d_consoleLock_p) << "Processing UNHANDLED event" << std::endl;

		MessageIterator msgIter(event);
		while (msgIter.next()) {
			Message msg = msgIter.message();
			ConsoleOut(d_consoleLock_p) << msg.messageType().string() << "\n" << msg << std::endl;
		}
		return true;
	}

public:
	EMSXEventHandler(SessionContext *context)
		: d_isSlow(false)
		, d_context_p(context)
		, d_consoleLock_p(&context->d_consoleLock)
	{
	}

	bool processEvent(const Event &event, Session *session)
	{
		try {
			switch (event.eventType()) {
			case Event::SESSION_STATUS: {
				MutexGuard guard(&d_context_p->d_mutex);
				return processSessionEvent(event, session);
			} break;
			case Event::SERVICE_STATUS: {
				MutexGuard guard(&d_context_p->d_mutex);
				return processServiceEvent(event, session);
			} break;
			case Event::RESPONSE: {
				MutexGuard guard(&d_context_p->d_mutex);
				return processResponseEvent(event, session);
			} break;
			default: {
				return processMiscEvents(event);
			}  break;
			}
		}
		catch (Exception &e) {
			ConsoleOut(d_consoleLock_p)
				<< "Library Exception !!!"
				<< e.description() << std::endl;
		}
		return false;
	}
};

class BrokerSpec
{

	SessionOptions            d_sessionOptions;
	Session                  *d_session;
	EMSXEventHandler		 *d_eventHandler;
	SessionContext            d_context;

	bool createSession() {
		ConsoleOut(&d_context.d_consoleLock)
			<< "Connecting to " << d_sessionOptions.serverHost()
			<< ":" << d_sessionOptions.serverPort() << std::endl;

		d_eventHandler = new EMSXEventHandler(&d_context);
		d_session = new Session(d_sessionOptions, d_eventHandler);

		d_session->startAsync();

		return true;
	}

public:

	BrokerSpec()
		: d_session(0)
		, d_eventHandler(0)
	{


		d_sessionOptions.setServerHost("localhost");
		d_sessionOptions.setServerPort(8194);
		d_sessionOptions.setMaxEventQueueSize(10000);
	}

	~BrokerSpec()
	{
		if (d_session) delete d_session;
		if (d_eventHandler) delete d_eventHandler;
	}

	void run(int argc, char **argv)
	{
		if (!createSession()) return;

		// wait for enter key to exit application
		ConsoleOut(&d_context.d_consoleLock)
			<< "\nPress ENTER to quit" << std::endl;
		char dummy[2];
		std::cin.getline(dummy, 2);
		{
			MutexGuard guard(&d_context.d_mutex);
			d_context.d_isStopped = true;
		}
		d_session->stop();
		ConsoleOut(&d_context.d_consoleLock) << "\nExiting..." << std::endl;
	}
};

int main(int argc, char **argv)
{
	std::cout << "Bloomberg - EMSX API Example - BrokerSpec" << std::endl;
	BrokerSpec brokerSpec;
	try {
		brokerSpec.run(argc, argv);
	}
	catch (Exception &e) {
		std::cout << "Library Exception!!!" << e.description() << std::endl;
	}
	// wait for enter key to exit application
	std::cout << "Press ENTER to quit" << std::endl;
	char dummy[2];
	std::cin.getline(dummy, 2);
	return 0;
}
