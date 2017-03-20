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
	Name GETFILLSRESPONSE("GetFillsResponse");

	const std::string d_service("//blp/emsx.history.uat");
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

				Request request = service.createRequest("GetFills");

				request.set("FromDateTime", "2017-02-08T00:00:00.000+00:00");
				request.set("ToDateTime", "2017-02-11T23:59:00.000+00:00");

				Element scope = request.getElement("Scope");

				//scope.setChoice("Team");
				//scope.setChoice("TradingSystem");
				scope.setChoice("Uuids");

				//scope.setElement("Team", "SEXEGROUP");
				//scope.setElement("TradingSystem",false);

				scope.getElement("Uuids").appendValue(8049857);

				/*scope.getElement("Uuids").appendValue(14348220);
				scope.getElement("Uuids").appendValue(8639067);
				scope.getElement("Uuids").appendValue(4674574);
				*/
				Element filter = request.getElement("FilterBy");

				//filter.setChoice("Basket");
				//filter.setChoice("Multileg");
				//filter.setChoice("OrdersAndRoutes");

				//filter.getElement("Basket").appendValue("TESTRJC");
				//filter.getElement("Multileg").appendValue("mymlegId");
				//Element newOrder = filter.getElement("OrdersAndRoutes").appendElement();
				//newOrder.setElement("OrderId",4292580);
				//newOrder.setElement("RouteId",1);

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

			ConsoleOut(d_consoleLock_p) << "MESSAGE TYPE: " << msg.messageType() << std::endl;

			if (msg.messageType() == ERROR_INFO) {

				int errorCode = msg.getElementAsInt32("ERROR_CODE");
				std::string errorMessage = msg.getElementAsString("ERROR_MESSAGE");

				ConsoleOut(d_consoleLock_p) << "ERROR CODE: " << errorCode << "\tERROR MESSAGE: " << errorMessage << std::endl;
			}
			else if (msg.messageType() == GETFILLSRESPONSE) {

				Element fills = msg.getElement("Fills");
				int numFills = fills.numValues();

				for (int i = 0; i<numFills; i++) {
				
					Element fill = fills.getValueAsElement(i);

					std::string account = fill.getElementAsString("Account");
					double amount = fill.getElementAsFloat64("Amount");
					std::string assetClass = fill.getElementAsString("AssetClass");
					int basketId = fill.getElementAsInt32("BasketId");
					std::string bbgid = fill.getElementAsString("BBGID");
					std::string blockId = fill.getElementAsString("BlockId");
					std::string broker = fill.getElementAsString("Broker");
					std::string clearingAccount = fill.getElementAsString("ClearingAccount");
					std::string clearingFirm = fill.getElementAsString("ClearingFirm");
					std::string contractExpDate = fill.getElementAsString("ContractExpDate");
					int correctedFillId = fill.getElementAsInt32("CorrectedFillId");
					std::string currency = fill.getElementAsString("Currency");
					std::string cusip = fill.getElementAsString("Cusip");
					std::string dateTimeOfFill = fill.getElementAsString("DateTimeOfFill");
					std::string exchange = fill.getElementAsString("Exchange");
					int execPrevSeqNo = fill.getElementAsInt32("ExecPrevSeqNo");
					std::string execType = fill.getElementAsString("ExecType");
					std::string executingBroker = fill.getElementAsString("ExecutingBroker");
					int fillId = fill.getElementAsInt32("FillId");
					double fillPrice = fill.getElementAsFloat64("FillPrice");
					double fillShares = fill.getElementAsFloat64("FillShares");
					std::string investorId = fill.getElementAsString("InvestorID");
					bool isCFD = fill.getElementAsBool("IsCfd");
					std::string isin = fill.getElementAsString("Isin");
					bool isLeg = fill.getElementAsBool("IsLeg");
					std::string lastCapacity = fill.getElementAsString("LastCapacity");
					std::string lastMarket = fill.getElementAsString("LastMarket");
					double limitPrice = fill.getElementAsFloat64("LimitPrice");
					std::string liquidity = fill.getElementAsString("Liquidity");
					std::string localExchangeSymbol = fill.getElementAsString("LocalExchangeSymbol");
					std::string locateBroker = fill.getElementAsString("LocateBroker");
					std::string locateId = fill.getElementAsString("LocateId");
					bool locateRequired = fill.getElementAsBool("LocateRequired");
					std::string multiLedId = fill.getElementAsString("MultilegId");
					std::string occSymbol = fill.getElementAsString("OCCSymbol");
					std::string orderExecutionInstruction = fill.getElementAsString("OrderExecutionInstruction");
					std::string orderHandlingInstruction = fill.getElementAsString("OrderHandlingInstruction");
					int orderId = fill.getElementAsInt32("OrderId");
					std::string orderInstruction = fill.getElementAsString("OrderInstruction");
					std::string orderOrigin = fill.getElementAsString("OrderOrigin");
					std::string orderReferenceId = fill.getElementAsString("OrderReferenceId");
					int originatingTraderUUId = fill.getElementAsInt32("OriginatingTraderUuid");
					std::string reroutedBroker = fill.getElementAsString("ReroutedBroker");
					double routeCommissionAmount = fill.getElementAsFloat64("RouteCommissionAmount");
					double routeCommissionRate = fill.getElementAsFloat64("RouteCommissionRate");
					std::string routeExecutionInstruction = fill.getElementAsString("RouteExecutionInstruction");
					std::string routeHandlingInstruction = fill.getElementAsString("RouteHandlingInstruction");
					int routeId = fill.getElementAsInt32("RouteId");
					double routeNetMoney = fill.getElementAsFloat64("RouteNetMoney");
					std::string routeNotes = fill.getElementAsString("RouteNotes");
					double routeShares = fill.getElementAsFloat64("RouteShares");
					std::string securityName = fill.getElementAsString("SecurityName");
					std::string sedol = fill.getElementAsString("Sedol");
					std::string settlementDate = fill.getElementAsString("SettlementDate");
					std::string side = fill.getElementAsString("Side");
					double stopPrice = fill.getElementAsFloat64("StopPrice");
					std::string strategyType = fill.getElementAsString("StrategyType");
					std::string ticker = fill.getElementAsString("Ticker");
					std::string tif = fill.getElementAsString("TIF");
					std::string traderName = fill.getElementAsString("TraderName");
					int traderUUId = fill.getElementAsInt32("TraderUuid");
					std::string type = fill.getElementAsString("Type");
					double userCommissionAmount = fill.getElementAsFloat64("UserCommissionAmount");
					double userCommissionRate = fill.getElementAsFloat64("UserCommissionRate");
					double userFees = fill.getElementAsFloat64("UserFees");
					double userNetMoney = fill.getElementAsFloat64("UserNetMoney");
					std::string yellowKey = fill.getElementAsString("YellowKey");

					ConsoleOut(d_consoleLock_p) << "OrderId: " << orderId << "\tFill ID: " << fillId << "\tDate/Time: " << dateTimeOfFill << "\tShares: " << fillShares << "\tPrice: " << fillPrice << std::endl;

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

class Route
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

	Route()
		: d_session(0)
		, d_eventHandler(0)
	{


		d_sessionOptions.setServerHost("localhost");
		d_sessionOptions.setServerPort(8194);
		d_sessionOptions.setMaxEventQueueSize(10000);
	}

	~Route()
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
	std::cout << "Bloomberg - EMSX API Example - History" << std::endl;
	Route route;
	try {
		route.run(argc, argv);
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
