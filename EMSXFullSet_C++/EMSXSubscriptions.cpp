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
	Name SESSION_TERMINATED("SessionTerminated");
	Name SESSION_CONNECTION_UP("SessionConnectionUp");
	Name SESSION_CONNECTION_DOWN("SessionConnectionDown");
	Name SERVICE_OPENED("ServiceOpened");
	Name SERVICE_OPEN_FAILURE("ServiceOpenFailure");
	Name ERROR_INFO("ErrorInfo");
	Name SLOW_CONSUMER_WARNING("SlowConsumerWarning");
	Name SLOW_CONSUMER_WARNING_CLEARED("SlowConsumerWarningCleared");
	Name SUBSCRIPTION_FAILURE("SubscriptionFailure");
	Name SUBSCRIPTION_STARTED("SubscriptionStarted");
	Name SUBSCRIPTION_TERMINATED("SubscriptionTerminated");
	Name ORDER_ROUTE_FIELDS("OrderRouteFields");

	const std::string d_service("//blp/emapisvc_beta");
	CorrelationId orderSubscriptionID;
	CorrelationId routeSubscriptionID;
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

	void createOrderSubscription(Session *session)
	{
		ConsoleOut(d_consoleLock_p) << "Create Order subscription" << std::endl;

		// Create the topic string for the order subscription. Here, we are subscribing 
		// to every available order field, however, you can subscribe to only the fields
		// required for your application.
		std::string orderTopic = d_service + "/order?fields=";

		orderTopic = orderTopic + "API_SEQ_NUM,";
		orderTopic = orderTopic + "EMSX_ACCOUNT,";
		orderTopic = orderTopic + "EMSX_AMOUNT,";
		orderTopic = orderTopic + "EMSX_ARRIVAL_PRICE,";
		orderTopic = orderTopic + "EMSX_ASSET_CLASS,";
		orderTopic = orderTopic + "EMSX_ASSIGNED_TRADER,";
		orderTopic = orderTopic + "EMSX_AVG_PRICE,";
		orderTopic = orderTopic + "EMSX_BASKET_NAME,";
		orderTopic = orderTopic + "EMSX_BASKET_NUM,";
		orderTopic = orderTopic + "EMSX_BROKER,";
		orderTopic = orderTopic + "EMSX_BROKER_COMM,";
		orderTopic = orderTopic + "EMSX_BSE_AVG_PRICE,";
		orderTopic = orderTopic + "EMSX_BSE_FILLED,";
		orderTopic = orderTopic + "EMSX_CFD_FLAG,";
		orderTopic = orderTopic + "EMSX_COMM_DIFF_FLAG,";
		orderTopic = orderTopic + "EMSX_COMM_RATE,";
		orderTopic = orderTopic + "EMSX_CURRENCY_PAIR,";
		orderTopic = orderTopic + "EMSX_DATE,";
		orderTopic = orderTopic + "EMSX_DAY_AVG_PRICE,";
		orderTopic = orderTopic + "EMSX_DAY_FILL,";
		orderTopic = orderTopic + "EMSX_DIR_BROKER_FLAG,";
		orderTopic = orderTopic + "EMSX_EXCHANGE,";
		orderTopic = orderTopic + "EMSX_EXCHANGE_DESTINATION,";
		orderTopic = orderTopic + "EMSX_EXEC_INSTRUCTION,";
		orderTopic = orderTopic + "EMSX_FILL_ID,";
		orderTopic = orderTopic + "EMSX_FILLED,";
		orderTopic = orderTopic + "EMSX_GTD_DATE,";
		orderTopic = orderTopic + "EMSX_HAND_INSTRUCTION,";
		orderTopic = orderTopic + "EMSX_IDLE_AMOUNT,";
		orderTopic = orderTopic + "EMSX_INVESTOR_ID,";
		orderTopic = orderTopic + "EMSX_ISIN,";
		orderTopic = orderTopic + "EMSX_LIMIT_PRICE,";
		orderTopic = orderTopic + "EMSX_NOTES,";
		orderTopic = orderTopic + "EMSX_NSE_AVG_PRICE,";
		orderTopic = orderTopic + "EMSX_NSE_FILLED,";
		orderTopic = orderTopic + "EMSX_ORD_REF_ID,";
		orderTopic = orderTopic + "EMSX_ORDER_TYPE,";
		orderTopic = orderTopic + "EMSX_ORIGINATE_TRADER,";
		orderTopic = orderTopic + "EMSX_ORIGINATE_TRADER_FIRM,";
		orderTopic = orderTopic + "EMSX_PERCENT_REMAIN,";
		orderTopic = orderTopic + "EMSX_PM_UUID,";
		orderTopic = orderTopic + "EMSX_PORT_MGR,";
		orderTopic = orderTopic + "EMSX_PORT_NAME,";
		orderTopic = orderTopic + "EMSX_PORT_NUM,";
		orderTopic = orderTopic + "EMSX_POSITION,";
		orderTopic = orderTopic + "EMSX_PRINCIPAL,";
		orderTopic = orderTopic + "EMSX_PRODUCT,";
		orderTopic = orderTopic + "EMSX_QUEUED_DATE,";
		orderTopic = orderTopic + "EMSX_QUEUED_TIME,";
		orderTopic = orderTopic + "EMSX_REASON_CODE,";
		orderTopic = orderTopic + "EMSX_REASON_DESC,";
		orderTopic = orderTopic + "EMSX_REMAIN_BALANCE,";
		orderTopic = orderTopic + "EMSX_ROUTE_ID,";
		orderTopic = orderTopic + "EMSX_ROUTE_PRICE,";
		orderTopic = orderTopic + "EMSX_SEC_NAME,";
		orderTopic = orderTopic + "EMSX_SEDOL,";
		orderTopic = orderTopic + "EMSX_SEQUENCE,";
		orderTopic = orderTopic + "EMSX_SETTLE_AMOUNT,";
		orderTopic = orderTopic + "EMSX_SETTLE_DATE,";
		orderTopic = orderTopic + "EMSX_SIDE,";
		orderTopic = orderTopic + "EMSX_START_AMOUNT,";
		orderTopic = orderTopic + "EMSX_STATUS,";
		orderTopic = orderTopic + "EMSX_STEP_OUT_BROKER,";
		orderTopic = orderTopic + "EMSX_STOP_PRICE,";
		orderTopic = orderTopic + "EMSX_STRATEGY_END_TIME,";
		orderTopic = orderTopic + "EMSX_STRATEGY_PART_RATE1,";
		orderTopic = orderTopic + "EMSX_STRATEGY_PART_RATE2,";
		orderTopic = orderTopic + "EMSX_STRATEGY_START_TIME,";
		orderTopic = orderTopic + "EMSX_STRATEGY_STYLE,";
		orderTopic = orderTopic + "EMSX_STRATEGY_TYPE,";
		orderTopic = orderTopic + "EMSX_TICKER,";
		orderTopic = orderTopic + "EMSX_TIF,";
		orderTopic = orderTopic + "EMSX_TIME_STAMP,";
		orderTopic = orderTopic + "EMSX_TRAD_UUID,";
		orderTopic = orderTopic + "EMSX_TRADE_DESK,";
		orderTopic = orderTopic + "EMSX_TRADER,";
		orderTopic = orderTopic + "EMSX_TRADER_NOTES,";
		orderTopic = orderTopic + "EMSX_TS_ORDNUM,";
		orderTopic = orderTopic + "EMSX_TYPE,";
		orderTopic = orderTopic + "EMSX_UNDERLYING_TICKER,";
		orderTopic = orderTopic + "EMSX_USER_COMM_AMOUNT,";
		orderTopic = orderTopic + "EMSX_USER_COMM_RATE,";
		orderTopic = orderTopic + "EMSX_USER_FEES,";
		orderTopic = orderTopic + "EMSX_USER_NET_MONEY,";
		orderTopic = orderTopic + "EMSX_WORK_PRICE,";
		orderTopic = orderTopic + "EMSX_WORKING,";
		orderTopic = orderTopic + "EMSX_YELLOW_KEY";

		// We define a correlation ID that allows us to identify the original
		// request when we examine the events. This is useful in situations where
		// the same event handler is used the process messages for the Order and Route 
		// subscriptions, as well as request/response requests.
		orderSubscriptionID = CorrelationId(98);

		ConsoleOut(d_consoleLock_p) << "Order Topic: " << orderTopic <<std::endl;
		ConsoleOut(d_consoleLock_p) << "Order ID: " << orderSubscriptionID << std::endl;

		SubscriptionList subscriptions = SubscriptionList();
		subscriptions.add(orderTopic.c_str(), orderSubscriptionID);

		try {
			session->subscribe(subscriptions);
		}
		catch (Exception &e) {
			ConsoleOut(d_consoleLock_p) << "Failed to create Order subscription: " << e.description() << std::endl;
		}

	}

	void createRouteSubscription(Session *session)
	{
		ConsoleOut(d_consoleLock_p) << "Create Route subscription" << std::endl;

		// Create the topic string for the route subscription. Here, we are subscribing 
		// to every available route field, however, you can subscribe to only the fields
		// required for your application.
		std::string routeTopic = d_service + "/route?fields=";

		routeTopic = routeTopic + "API_SEQ_NUM,";
		routeTopic = routeTopic + "EMSX_ACCOUNT,";
		routeTopic = routeTopic + "EMSX_AMOUNT,";
		routeTopic = routeTopic + "EMSX_AVG_PRICE,";
		routeTopic = routeTopic + "EMSX_BROKER,";
		routeTopic = routeTopic + "EMSX_BROKER_COMM,";
		routeTopic = routeTopic + "EMSX_BSE_AVG_PRICE,";
		routeTopic = routeTopic + "EMSX_BSE_FILLED,";
		routeTopic = routeTopic + "EMSX_CLEARING_ACCOUNT,";
		routeTopic = routeTopic + "EMSX_CLEARING_FIRM,";
		routeTopic = routeTopic + "EMSX_COMM_DIFF_FLAG,";
		routeTopic = routeTopic + "EMSX_COMM_RATE,";
		routeTopic = routeTopic + "EMSX_CURRENCY_PAIR,";
		routeTopic = routeTopic + "EMSX_CUSTOM_ACCOUNT,";
		routeTopic = routeTopic + "EMSX_DAY_AVG_PRICE,";
		routeTopic = routeTopic + "EMSX_DAY_FILL,";
		routeTopic = routeTopic + "EMSX_EXCHANGE_DESTINATION,";
		routeTopic = routeTopic + "EMSX_EXEC_INSTRUCTION,";
		routeTopic = routeTopic + "EMSX_EXECUTE_BROKER,";
		routeTopic = routeTopic + "EMSX_FILL_ID,";
		routeTopic = routeTopic + "EMSX_FILLED,";
		routeTopic = routeTopic + "EMSX_GTD_DATE,";
		routeTopic = routeTopic + "EMSX_HAND_INSTRUCTION,";
		routeTopic = routeTopic + "EMSX_IS_MANUAL_ROUTE,";
		routeTopic = routeTopic + "EMSX_LAST_FILL_DATE,";
		routeTopic = routeTopic + "EMSX_LAST_FILL_TIME,";
		routeTopic = routeTopic + "EMSX_LAST_MARKET,";
		routeTopic = routeTopic + "EMSX_LAST_PRICE,";
		routeTopic = routeTopic + "EMSX_LAST_SHARES,";
		routeTopic = routeTopic + "EMSX_LIMIT_PRICE,";
		routeTopic = routeTopic + "EMSX_MISC_FEES,";
		routeTopic = routeTopic + "EMSX_ML_LEG_QUANTITY,";
		routeTopic = routeTopic + "EMSX_ML_NUM_LEGS,";
		routeTopic = routeTopic + "EMSX_ML_PERCENT_FILLED,";
		routeTopic = routeTopic + "EMSX_ML_RATIO,";
		routeTopic = routeTopic + "EMSX_ML_REMAIN_BALANCE,";
		routeTopic = routeTopic + "EMSX_ML_STRATEGY,";
		routeTopic = routeTopic + "EMSX_ML_TOTAL_QUANTITY,";
		routeTopic = routeTopic + "EMSX_NOTES,";
		routeTopic = routeTopic + "EMSX_NSE_AVG_PRICE,";
		routeTopic = routeTopic + "EMSX_NSE_FILLED,";
		routeTopic = routeTopic + "EMSX_ORDER_TYPE,";
		routeTopic = routeTopic + "EMSX_P_A,";
		routeTopic = routeTopic + "EMSX_PERCENT_REMAIN,";
		routeTopic = routeTopic + "EMSX_PRINCIPAL,";
		routeTopic = routeTopic + "EMSX_QUEUED_DATE,";
		routeTopic = routeTopic + "EMSX_QUEUED_TIME,";
		routeTopic = routeTopic + "EMSX_REASON_CODE,";
		routeTopic = routeTopic + "EMSX_REASON_DESC,";
		routeTopic = routeTopic + "EMSX_REMAIN_BALANCE,";
		routeTopic = routeTopic + "EMSX_ROUTE_CREATE_DATE,";
		routeTopic = routeTopic + "EMSX_ROUTE_CREATE_TIME,";
		routeTopic = routeTopic + "EMSX_ROUTE_ID,";
		routeTopic = routeTopic + "EMSX_ROUTE_REF_ID,";
		routeTopic = routeTopic + "EMSX_ROUTE_LAST_UPDATE_TIME,";
		routeTopic = routeTopic + "EMSX_ROUTE_PRICE,";
		routeTopic = routeTopic + "EMSX_SEQUENCE,";
		routeTopic = routeTopic + "EMSX_SETTLE_AMOUNT,";
		routeTopic = routeTopic + "EMSX_SETTLE_DATE,";
		routeTopic = routeTopic + "EMSX_STATUS,";
		routeTopic = routeTopic + "EMSX_STOP_PRICE,";
		routeTopic = routeTopic + "EMSX_STRATEGY_END_TIME,";
		routeTopic = routeTopic + "EMSX_STRATEGY_PART_RATE1,";
		routeTopic = routeTopic + "EMSX_STRATEGY_PART_RATE2,";
		routeTopic = routeTopic + "EMSX_STRATEGY_START_TIME,";
		routeTopic = routeTopic + "EMSX_STRATEGY_STYLE,";
		routeTopic = routeTopic + "EMSX_STRATEGY_TYPE,";
		routeTopic = routeTopic + "EMSX_TIF,";
		routeTopic = routeTopic + "EMSX_TIME_STAMP,";
		routeTopic = routeTopic + "EMSX_TYPE,";
		routeTopic = routeTopic + "EMSX_URGENCY_LEVEL,";
		routeTopic = routeTopic + "EMSX_USER_COMM_AMOUNT,";
		routeTopic = routeTopic + "EMSX_USER_COMM_RATE,";
		routeTopic = routeTopic + "EMSX_USER_FEES,";
		routeTopic = routeTopic + "EMSX_USER_NET_MONEY,";
		routeTopic = routeTopic + "EMSX_WORKING";

		// We define a correlation ID that allows us to identify the original
		// request when we examine the events. This is useful in situations where
		// the same event handler is used the process messages for the Order and Route 
		// subscriptions, as well as request/response requests.
		routeSubscriptionID = CorrelationId(99);

		ConsoleOut(d_consoleLock_p) << "Route Topic: " << routeTopic << std::endl;
		ConsoleOut(d_consoleLock_p) << "Route ID: " << routeSubscriptionID << std::endl;

		SubscriptionList subscriptions = SubscriptionList();
		subscriptions.add(routeTopic.c_str(), routeSubscriptionID);

		try {
			session->subscribe(subscriptions);
		}
		catch (Exception &e) {
			ConsoleOut(d_consoleLock_p) << "Failed to create Route subscription: " << e.description() << std::endl;
		}

	}

	bool processAdminEvent(const Event &event, Session *session)
	{

		ConsoleOut(d_consoleLock_p) << "Processing ADMIN event" << std::endl;

		MessageIterator msgIter(event);
		while (msgIter.next()) {

			Message msg = msgIter.message();

			if (msg.messageType() == SLOW_CONSUMER_WARNING) {
				ConsoleOut(d_consoleLock_p) << "Warning: Entered Slow Consumer status" << std::endl;
			}
			else if (msg.messageType() == SLOW_CONSUMER_WARNING_CLEARED) {
				ConsoleOut(d_consoleLock_p) << "Slow consumer status cleared" << std::endl;
				return false;
			}
		}
		return true;
	}

	bool processSessionEvent(const Event &event, Session *session)
	{

		ConsoleOut(d_consoleLock_p) << "Processing SESSION_STATUS event" << std::endl;

		MessageIterator msgIter(event);
		while (msgIter.next()) {

			Message msg = msgIter.message();

			if (msg.messageType() == SESSION_STARTED) {
				ConsoleOut(d_consoleLock_p) << "Session started..." << std::endl;
				session->openServiceAsync(d_service.c_str());
			}
			else if (msg.messageType() == SESSION_STARTUP_FAILURE) {
				ConsoleOut(d_consoleLock_p) << "Error: Session startup failed" << std::endl;
				return false;
			}
			else if (msg.messageType() == SESSION_TERMINATED) {
				ConsoleOut(d_consoleLock_p) << "Session has been terminated" << std::endl;
				return false;
			}
			else if (msg.messageType() == SESSION_CONNECTION_UP) {
				ConsoleOut(d_consoleLock_p) << "Session connection is up" << std::endl;
				return false;
			}
			else if (msg.messageType() == SESSION_CONNECTION_DOWN) {
				ConsoleOut(d_consoleLock_p) << "Session connection is down" << std::endl;
				return false;
			}
		}
		return true;
	}

	bool processServiceEvent(const Event &event, Session *session)
	{

		ConsoleOut(d_consoleLock_p) << "Processing SERVICE_STATUS event" << std::endl;

		MessageIterator msgIter(event);
		while (msgIter.next()) {

			Message msg = msgIter.message();

			if (msg.messageType() == SERVICE_OPENED) {
				ConsoleOut(d_consoleLock_p) << "Service opened..." << std::endl;

				createOrderSubscription(session);
			}
			else if (msg.messageType() == SERVICE_OPEN_FAILURE) {
				ConsoleOut(d_consoleLock_p) << "Error: Service failed to open" << std::endl;
				return false;
			}

		}
		return true;
	}

	bool processSubscriptionStatusEvent(const Event &event, Session *session)
	{
		ConsoleOut(d_consoleLock_p) << "Processing SUBSCRIPTION_STATUS event" << std::endl;

		MessageIterator msgIter(event);
		while (msgIter.next()) {

			Message msg = msgIter.message();

			if (msg.messageType() == SUBSCRIPTION_STARTED) {

				if (msg.correlationId().asInteger() == orderSubscriptionID.asInteger()) {
					ConsoleOut(d_consoleLock_p) << "Order subscription started successfully" << std::endl;
					createRouteSubscription(session);
				}
				else if (msg.correlationId().asInteger() == routeSubscriptionID.asInteger()) {
					ConsoleOut(d_consoleLock_p) << "Route subscription started successfully" << std::endl;
				}
			}
			else if (msg.messageType() == SUBSCRIPTION_FAILURE) {
				if (msg.correlationId().asInteger() == orderSubscriptionID.asInteger()) {
					ConsoleOut(d_consoleLock_p) << "Error: Order subscription failed" << std::endl;
				}
				else if (msg.correlationId().asInteger() == routeSubscriptionID.asInteger()) {
					ConsoleOut(d_consoleLock_p) << "Error: Route subscription failed" << std::endl;
				}
				ConsoleOut(d_consoleLock_p) << "MESSAGE: " << msg << std::endl;
				return false;
			}
			else if (msg.messageType() == SUBSCRIPTION_TERMINATED) {
				if (msg.correlationId().asInteger() == orderSubscriptionID.asInteger()) {
					ConsoleOut(d_consoleLock_p) << "Order subscription terminated" << std::endl;
				}
				else if (msg.correlationId() == routeSubscriptionID) {
					ConsoleOut(d_consoleLock_p) << "Route subscription terminated" << std::endl;
				}
				ConsoleOut(d_consoleLock_p) << "MESSAGE: " << msg << std::endl;
				return false;
			}

		}
		return true;
	}

	bool processSubscriptionDataEvent(const Event &event, Session *session)
	{
		//ConsoleOut(d_consoleLock_p) << "Processing SUBSCRIPTION_DATA event" << std::endl;

		MessageIterator msgIter(event);
		while (msgIter.next()) {

			Message msg = msgIter.message();

			if (msg.messageType() == ORDER_ROUTE_FIELDS) {

				int event_status = msg.getElementAsInt32("EVENT_STATUS");

				if (event_status == 1) {

					//Heartbeat event, arrives every 1 second of inactivity on a subscription

					if (msg.correlationId().asInteger() == orderSubscriptionID.asInteger()) {
						ConsoleOut(d_consoleLock_p) << "O.";
					}
					else if (msg.correlationId().asInteger() == routeSubscriptionID.asInteger()) {
						ConsoleOut(d_consoleLock_p) << "R.";
					}
				}
				else {
					ConsoleOut(d_consoleLock_p) << "" << std::endl;

					if (msg.correlationId().asInteger() == orderSubscriptionID.asInteger()) {
						long api_seq_num = msg.hasElement("API_SEQ_NUM") ? msg.getElementAsInt64("API_SEQ_NUM") : 0;
						std::string emsx_account = msg.hasElement("EMSX_ACCOUNT") ? msg.getElementAsString("EMSX_ACCOUNT") : "";
						int emsx_amount = msg.hasElement("EMSX_AMOUNT") ? msg.getElementAsInt32("EMSX_AMOUNT") : 0;
						double emsx_arrival_price = msg.hasElement("EMSX_ARRIVAL_PRICE") ? msg.getElementAsFloat64("EMSX_ARRIVAL_PRICE") : 0;
						std::string emsx_asset_class = msg.hasElement("EMSX_ASSET_CLASS") ? msg.getElementAsString("EMSX_ASSET_CLASS") : "";
						std::string emsx_assigned_trader = msg.hasElement("EMSX_ASSIGNED_TRADER") ? msg.getElementAsString("EMSX_ASSIGNED_TRADER") : "";
						double emsx_avg_price = msg.hasElement("EMSX_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_AVG_PRICE") : 0;
						std::string emsx_basket_name = msg.hasElement("EMSX_BASKET_NAME") ? msg.getElementAsString("EMSX_BASKET_NAME") : "";
						int emsx_basket_num = msg.hasElement("EMSX_BASKET_NUM") ? msg.getElementAsInt32("EMSX_BASKET_NUM") : 0;
						std::string emsx_broker = msg.hasElement("EMSX_BROKER") ? msg.getElementAsString("EMSX_BROKER") : "";
						double emsx_broker_comm = msg.hasElement("EMSX_BROKER_COMM") ? msg.getElementAsFloat64("EMSX_BROKER_COMM") : 0;
						double emsx_bse_avg_price = msg.hasElement("EMSX_BSE_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_BSE_AVG_PRICE") : 0;
						int emsx_bse_filled = msg.hasElement("EMSX_BSE_FILLED") ? msg.getElementAsInt32("EMSX_BSE_FILLED") : 0;
						std::string emsx_cfd_flag = msg.hasElement("EMSX_CFD_FLAG") ? msg.getElementAsString("EMSX_CFD_FLAG") : "";
						std::string emsx_comm_diff_flag = msg.hasElement("EMSX_COMM_DIFF_FLAG") ? msg.getElementAsString("EMSX_COMM_DIFF_FLAG") : "";
						double emsx_comm_rate = msg.hasElement("EMSX_COMM_RATE") ? msg.getElementAsFloat64("EMSX_COMM_RATE") : 0;
						std::string emsx_currency_pair = msg.hasElement("EMSX_CURRENCY_PAIR") ? msg.getElementAsString("EMSX_CURRENCY_PAIR") : "";
						int emsx_date = msg.hasElement("EMSX_DATE") ? msg.getElementAsInt32("EMSX_DATE") : 0;
						double emsx_day_avg_price = msg.hasElement("EMSX_DAY_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_DAY_AVG_PRICE") : 0;
						int emsx_day_fill = msg.hasElement("EMSX_DAY_FILL") ? msg.getElementAsInt32("EMSX_DAY_FILL") : 0;
						std::string emsx_dir_broker_flag = msg.hasElement("EMSX_DIR_BROKER_FLAG") ? msg.getElementAsString("EMSX_DIR_BROKER_FLAG") : "";
						std::string emsx_exchange = msg.hasElement("EMSX_EXCHANGE") ? msg.getElementAsString("EMSX_EXCHANGE") : "";
						std::string emsx_exchange_destination = msg.hasElement("EMSX_EXCHANGE_DESTINATION") ? msg.getElementAsString("EMSX_EXCHANGE_DESTINATION") : "";
						std::string emsx_exec_instruction = msg.hasElement("EMSX_EXEC_INSTRUCTION") ? msg.getElementAsString("EMSX_EXEC_INSTRUCTION") : "";
						int emsx_fill_id = msg.hasElement("EMSX_FILL_ID") ? msg.getElementAsInt32("EMSX_FILL_ID") : 0;
						int emsx_filled = msg.hasElement("EMSX_FILLED") ? msg.getElementAsInt32("EMSX_FILLED") : 0;
						int emsx_gtd_date = msg.hasElement("EMSX_GTD_DATE") ? msg.getElementAsInt32("EMSX_GTD_DATE") : 0;
						std::string emsx_hand_instruction = msg.hasElement("EMSX_HAND_INSTRUCTION") ? msg.getElementAsString("EMSX_HAND_INSTRUCTION") : "";
						int emsx_idle_amount = msg.hasElement("EMSX_IDLE_AMOUNT") ? msg.getElementAsInt32("EMSX_IDLE_AMOUNT") : 0;
						std::string emsx_investor_id = msg.hasElement("EMSX_INVESTOR_ID") ? msg.getElementAsString("EMSX_INVESTOR_ID") : "";
						std::string emsx_isin = msg.hasElement("EMSX_ISIN") ? msg.getElementAsString("EMSX_ISIN") : "";
						double emsx_limit_price = msg.hasElement("EMSX_LIMIT_PRICE") ? msg.getElementAsFloat64("EMSX_LIMIT_PRICE") : 0;
						std::string emsx_notes = msg.hasElement("EMSX_NOTES") ? msg.getElementAsString("EMSX_NOTES") : "";
						double emsx_nse_avg_price = msg.hasElement("EMSX_NSE_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_NSE_AVG_PRICE") : 0;
						int emsx_nse_filled = msg.hasElement("EMSX_NSE_FILLED") ? msg.getElementAsInt32("EMSX_NSE_FILLED") : 0;
						std::string emsx_ord_ref_id = msg.hasElement("EMSX_ORD_REF_ID") ? msg.getElementAsString("EMSX_ORD_REF_ID") : "";
						std::string emsx_order_type = msg.hasElement("EMSX_ORDER_TYPE") ? msg.getElementAsString("EMSX_ORDER_TYPE") : "";
						std::string emsx_originate_trader = msg.hasElement("EMSX_ORIGINATE_TRADER") ? msg.getElementAsString("EMSX_ORIGINATE_TRADER") : "";
						std::string emsx_originate_trader_firm = msg.hasElement("EMSX_ORIGINATE_TRADER_FIRM") ? msg.getElementAsString("EMSX_ORIGINATE_TRADER_FIRM") : "";
						double emsx_percent_remain = msg.hasElement("EMSX_PERCENT_REMAIN") ? msg.getElementAsFloat64("EMSX_PERCENT_REMAIN") : 0;
						int emsx_pm_uuid = msg.hasElement("EMSX_PM_UUID") ? msg.getElementAsInt32("EMSX_PM_UUID") : 0;
						std::string emsx_port_mgr = msg.hasElement("EMSX_PORT_MGR") ? msg.getElementAsString("EMSX_PORT_MGR") : "";
						std::string emsx_port_name = msg.hasElement("EMSX_PORT_NAME") ? msg.getElementAsString("EMSX_PORT_NAME") : "";
						int emsx_port_num = msg.hasElement("EMSX_PORT_NUM") ? msg.getElementAsInt32("EMSX_PORT_NUM") : 0;
						std::string emsx_position = msg.hasElement("EMSX_POSITION") ? msg.getElementAsString("EMSX_POSITION") : "";
						double emsx_principle = msg.hasElement("EMSX_PRINCIPAL") ? msg.getElementAsFloat64("EMSX_PRINCIPAL") : 0;
						std::string emsx_product = msg.hasElement("EMSX_PRODUCT") ? msg.getElementAsString("EMSX_PRODUCT") : "";
						int emsx_queued_date = msg.hasElement("EMSX_QUEUED_DATE") ? msg.getElementAsInt32("EMSX_QUEUED_DATE") : 0;
						int emsx_queued_time = msg.hasElement("EMSX_QUEUED_TIME") ? msg.getElementAsInt32("EMSX_QUEUED_TIME") : 0;
						std::string emsx_reason_code = msg.hasElement("EMSX_REASON_CODE") ? msg.getElementAsString("EMSX_REASON_CODE") : "";
						std::string emsx_reason_desc = msg.hasElement("EMSX_REASON_DESC") ? msg.getElementAsString("EMSX_REASON_DESC") : "";
						double emsx_remain_balance = msg.hasElement("EMSX_REMAIN_BALANCE") ? msg.getElementAsFloat64("EMSX_REMAIN_BALANCE") : 0;
						int emsx_route_id = msg.hasElement("EMSX_ROUTE_ID") ? msg.getElementAsInt32("EMSX_ROUTE_ID") : 0;
						double emsx_route_price = msg.hasElement("EMSX_ROUTE_PRICE") ? msg.getElementAsFloat64("EMSX_ROUTE_PRICE") : 0;
						std::string emsx_sec_name = msg.hasElement("EMSX_SEC_NAME") ? msg.getElementAsString("EMSX_SEC_NAME") : "";
						std::string emsx_sedol = msg.hasElement("EMSX_SEDOL") ? msg.getElementAsString("EMSX_SEDOL") : "";
						int emsx_sequence = msg.hasElement("EMSX_SEQUENCE") ? msg.getElementAsInt32("EMSX_SEQUENCE") : 0;
						double emsx_settle_amount = msg.hasElement("EMSX_SETTLE_AMOUNT") ? msg.getElementAsFloat64("EMSX_SETTLE_AMOUNT") : 0;
						int emsx_settle_date = msg.hasElement("EMSX_SETTLE_DATE") ? msg.getElementAsInt32("EMSX_SETTLE_DATE") : 0;
						std::string emsx_side = msg.hasElement("EMSX_SIDE") ? msg.getElementAsString("EMSX_SIDE") : "";
						int emsx_start_amount = msg.hasElement("EMSX_START_AMOUNT") ? msg.getElementAsInt32("EMSX_START_AMOUNT") : 0;
						std::string emsx_status = msg.hasElement("EMSX_STATUS") ? msg.getElementAsString("EMSX_STATUS") : "";
						std::string emsx_step_out_broker = msg.hasElement("EMSX_STEP_OUT_BROKER") ? msg.getElementAsString("EMSX_STEP_OUT_BROKER") : "";
						double emsx_stop_price = msg.hasElement("EMSX_STOP_PRICE") ? msg.getElementAsFloat64("EMSX_STOP_PRICE") : 0;
						int emsx_strategy_end_time = msg.hasElement("EMSX_STRATEGY_END_TIME") ? msg.getElementAsInt32("EMSX_STRATEGY_END_TIME") : 0;
						double emsx_strategy_part_rate1 = msg.hasElement("EMSX_STRATEGY_PART_RATE1") ? msg.getElementAsFloat64("EMSX_STRATEGY_PART_RATE1") : 0;
						double emsx_strategy_part_rate2 = msg.hasElement("EMSX_STRATEGY_PART_RATE2") ? msg.getElementAsFloat64("EMSX_STRATEGY_PART_RATE2") : 0;
						int emsx_strategy_start_time = msg.hasElement("EMSX_STRATEGY_START_TIME") ? msg.getElementAsInt32("EMSX_STRATEGY_START_TIME") : 0;
						std::string emsx_strategy_style = msg.hasElement("EMSX_STRATEGY_STYLE") ? msg.getElementAsString("EMSX_STRATEGY_STYLE") : "";
						std::string emsx_strategy_type = msg.hasElement("EMSX_STRATEGY_TYPE") ? msg.getElementAsString("EMSX_STRATEGY_TYPE") : "";
						std::string emsx_ticker = msg.hasElement("EMSX_TICKER") ? msg.getElementAsString("EMSX_TICKER") : "";
						std::string emsx_tif = msg.hasElement("EMSX_TIF") ? msg.getElementAsString("EMSX_TIF") : "";
						int emsx_time_stamp = msg.hasElement("EMSX_TIME_STAMP") ? msg.getElementAsInt32("EMSX_TIME_STAMP") : 0;
						int emsx_trad_uuid = msg.hasElement("EMSX_TRAD_UUID") ? msg.getElementAsInt32("EMSX_TRAD_UUID") : 0;
						std::string emsx_trade_desk = msg.hasElement("EMSX_TRADE_DESK") ? msg.getElementAsString("EMSX_TRADE_DESK") : "";
						std::string emsx_trader = msg.hasElement("EMSX_TRADER") ? msg.getElementAsString("EMSX_TRADER") : "";
						std::string emsx_trader_notes = msg.hasElement("EMSX_TRADER_NOTES") ? msg.getElementAsString("EMSX_TRADER_NOTES") : "";
						int emsx_ts_ordnum = msg.hasElement("EMSX_TS_ORDNUM") ? msg.getElementAsInt32("EMSX_TS_ORDNUM") : 0;
						std::string emsx_type = msg.hasElement("EMSX_TYPE") ? msg.getElementAsString("EMSX_TYPE") : "";
						std::string emsx_underlying_ticker = msg.hasElement("EMSX_UNDERLYING_TICKER") ? msg.getElementAsString("EMSX_UNDERLYING_TICKER") : "";
						double emsx_user_comm_amount = msg.hasElement("EMSX_USER_COMM_AMOUNT") ? msg.getElementAsFloat64("EMSX_USER_COMM_AMOUNT") : 0;
						double emsx_user_comm_rate = msg.hasElement("EMSX_USER_COMM_RATE") ? msg.getElementAsFloat64("EMSX_USER_COMM_RATE") : 0;
						double emsx_user_fees = msg.hasElement("EMSX_USER_FEES") ? msg.getElementAsFloat64("EMSX_USER_FEES") : 0;
						double emsx_user_net_money = msg.hasElement("EMSX_USER_NET_MONEY") ? msg.getElementAsFloat64("EMSX_USER_NET_MONEY") : 0;
						double emsx_user_work_price = msg.hasElement("EMSX_WORK_PRICE") ? msg.getElementAsFloat64("EMSX_WORK_PRICE") : 0;
						int emsx_working = msg.hasElement("EMSX_WORKING") ? msg.getElementAsInt32("EMSX_WORKING") : 0;
						std::string emsx_yellow_key = msg.hasElement("EMSX_YELLOW_KEY") ? msg.getElementAsString("EMSX_YELLOW_KEY") : "";

						ConsoleOut(d_consoleLock_p) << "ORDER MESSAGE: CorrelationID(" << msg.correlationId() << ")  Status(" << event_status << ")" << std::endl;

						ConsoleOut(d_consoleLock_p) << "API_SEQ_NUM: " << api_seq_num << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ACCOUNT: " << emsx_account << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_AMOUNT: " << emsx_amount << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ARRIVAL_PRICE: " << emsx_arrival_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ASSET_CLASS: " << emsx_asset_class << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ASSIGNED_TRADER: " << emsx_assigned_trader << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_AVG_PRICE: " << emsx_avg_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BASKET_NAME: " << emsx_basket_name << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BASKET_NUM: " << emsx_basket_num << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BROKER: " << emsx_broker << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BROKER_COMM: " << emsx_broker_comm << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BSE_AVG_PRICE: " << emsx_bse_avg_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BSE_FILLED: " << emsx_bse_filled << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_CFD_FLAG: " << emsx_cfd_flag << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_COMM_DIFF_FLAG: " << emsx_comm_diff_flag << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_COMM_RATE: " << emsx_comm_rate << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_CURRENCY_PAIR: " << emsx_currency_pair << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_DATE: " << emsx_date << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_DAY_AVG_PRICE: " << emsx_day_avg_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_DAY_FILL: " << emsx_day_fill << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_DIR_BROKER_FLAG: " << emsx_dir_broker_flag << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_EXCHANGE: " << emsx_exchange << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_EXCHANGE_DESTINATION: " << emsx_exchange_destination << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_EXEC_INSTRUCTION: " << emsx_exec_instruction << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_FILL_ID: " << emsx_fill_id << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_FILLED: " << emsx_filled << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_GTD_DATE: " << emsx_gtd_date << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_HAND_INSTRUCTION: " << emsx_hand_instruction << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_IDLE_AMOUNT: " << emsx_idle_amount << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_INVESTOR_ID: " << emsx_investor_id << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ISIN: " << emsx_isin << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_LIMIT_PRICE: " << emsx_limit_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_NOTES: " << emsx_notes << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_NSE_AVG_PRICE: " << emsx_nse_avg_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_NSE_FILLED: " << emsx_nse_filled << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ORD_REF_ID: " << emsx_ord_ref_id << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ORDER_TYPE: " << emsx_order_type << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ORIGINATE_TRADER: " << emsx_originate_trader << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ORIGINATE_TRADER_FIRM: " << emsx_originate_trader_firm << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_PERCENT_REMAIN: " << emsx_percent_remain << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_PM_UUID: " << emsx_pm_uuid << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_PORT_MGR: " << emsx_port_mgr << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_PORT_NAME: " << emsx_port_name << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_PORT_NUM: " << emsx_port_num << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_POSITION: " << emsx_position << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_PRINCIPAL: " << emsx_principle << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_PRODUCT: " << emsx_product << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_QUEUED_DATE: " << emsx_queued_date << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_QUEUED_TIME: " << emsx_queued_time << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_REASON_CODE: " << emsx_reason_code << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_REASON_DESC: " << emsx_reason_desc << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_REMAIN_BALANCE: " << emsx_remain_balance << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ROUTE_ID: " << emsx_route_id << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ROUTE_PRICE: " << emsx_route_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_SEC_NAME: " << emsx_sec_name << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_SEDOL: " << emsx_sedol << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_SEQUENCE: " << emsx_sequence << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_SETTLE_AMOUNT: " << emsx_settle_amount << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_SETTLE_DATE: " << emsx_settle_date << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_SIDE: " << emsx_side << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_START_AMOUNT: " << emsx_start_amount << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STATUS: " << emsx_status << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STEP_OUT_BROKER: " << emsx_step_out_broker << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STOP_PRICE: " << emsx_stop_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_END_TIME: " << emsx_strategy_end_time << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_PART_RATE1: " << emsx_strategy_part_rate1 << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_PART_RATE2: " << emsx_strategy_part_rate2 << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_START_TIME: " << emsx_strategy_start_time << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_STYLE: " << emsx_strategy_style << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_TYPE: " << emsx_strategy_type << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TICKER: " << emsx_ticker << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TIF: " << emsx_tif << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TIME_STAMP: " << emsx_time_stamp << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TRAD_UUID: " << emsx_trad_uuid << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TRADE_DESK: " << emsx_trade_desk << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TRADER: " << emsx_trader << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TRADER_NOTES: " << emsx_trader_notes << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TS_ORDNUM: " << emsx_ts_ordnum << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TYPE: " << emsx_type << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_UNDERLYING_TICKER: " << emsx_underlying_ticker << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_USER_COMM_AMOUNT: " << emsx_user_comm_amount << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_USER_COMM_RATE: " << emsx_user_comm_rate << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_USER_FEES: " << emsx_user_fees << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_USER_NET_MONEY: " << emsx_user_net_money << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_WORK_PRICE: " << emsx_user_work_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_WORKING: " << emsx_working << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_YELLOW_KEY: " << emsx_yellow_key << std::endl;

					}
					else if (msg.correlationId().asInteger() == routeSubscriptionID.asInteger()) {

						long api_seq_num = msg.hasElement("API_SEQ_NUM") ? msg.getElementAsInt64("API_SEQ_NUM") : 0;
						std::string emsx_account = msg.hasElement("EMSX_ACCOUNT") ? msg.getElementAsString("EMSX_ACCOUNT") : "";
						int emsx_amount = msg.hasElement("EMSX_AMOUNT") ? msg.getElementAsInt32("EMSX_AMOUNT") : 0;
						double emsx_avg_price = msg.hasElement("EMSX_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_AVG_PRICE") : 0;
						std::string emsx_broker = msg.hasElement("EMSX_BROKER") ? msg.getElementAsString("EMSX_BROKER") : "";
						double emsx_broker_comm = msg.hasElement("EMSX_BROKER_COMM") ? msg.getElementAsFloat64("EMSX_BROKER_COMM") : 0;
						double emsx_bse_avg_price = msg.hasElement("EMSX_BSE_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_BSE_AVG_PRICE") : 0;
						int emsx_bse_filled = msg.hasElement("EMSX_BSE_FILLED") ? msg.getElementAsInt32("EMSX_BSE_FILLED") : 0;
						std::string emsx_clearing_account = msg.hasElement("EMSX_CLEARING_ACCOUNT") ? msg.getElementAsString("EMSX_CLEARING_ACCOUNT") : "";
						std::string emsx_clearing_firm = msg.hasElement("EMSX_CLEARING_FIRM") ? msg.getElementAsString("EMSX_CLEARING_FIRM") : "";
						std::string emsx_comm_diff_flag = msg.hasElement("EMSX_COMM_DIFF_FLAG") ? msg.getElementAsString("EMSX_COMM_DIFF_FLAG") : "";
						double emsx_comm_rate = msg.hasElement("EMSX_COMM_RATE") ? msg.getElementAsFloat64("EMSX_COMM_RATE") : 0;
						std::string emsx_currency_pair = msg.hasElement("EMSX_CURRENCY_PAIR") ? msg.getElementAsString("EMSX_CURRENCY_PAIR") : "";
						std::string emsx_custom_account = msg.hasElement("EMSX_CUSTOM_ACCOUNT") ? msg.getElementAsString("EMSX_CUSTOM_ACCOUNT") : "";
						double emsx_day_avg_price = msg.hasElement("EMSX_DAY_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_DAY_AVG_PRICE") : 0;
						int emsx_day_fill = msg.hasElement("EMSX_DAY_FILL") ? msg.getElementAsInt32("EMSX_DAY_FILL") : 0;
						std::string emsx_exchange_destination = msg.hasElement("EMSX_EXCHANGE_DESTINATION") ? msg.getElementAsString("EMSX_EXCHANGE_DESTINATION") : "";
						std::string emsx_exec_instruction = msg.hasElement("EMSX_EXEC_INSTRUCTION") ? msg.getElementAsString("EMSX_EXEC_INSTRUCTION") : "";
						std::string emsx_execute_broker = msg.hasElement("EMSX_EXECUTE_BROKER") ? msg.getElementAsString("EMSX_EXECUTE_BROKER") : "";
						int emsx_fill_id = msg.hasElement("EMSX_FILL_ID") ? msg.getElementAsInt32("EMSX_FILL_ID") : 0;
						int emsx_filled = msg.hasElement("EMSX_FILLED") ? msg.getElementAsInt32("EMSX_FILLED") : 0;
						int emsx_gtd_date = msg.hasElement("EMSX_GTD_DATE") ? msg.getElementAsInt32("EMSX_GTD_DATE") : 0;
						std::string emsx_hand_instruction = msg.hasElement("EMSX_HAND_INSTRUCTION") ? msg.getElementAsString("EMSX_HAND_INSTRUCTION") : "";
						int emsx_is_manual_route = msg.hasElement("EMSX_IS_MANUAL_ROUTE") ? msg.getElementAsInt32("EMSX_IS_MANUAL_ROUTE") : 0;
						int emsx_last_fill_date = msg.hasElement("EMSX_LAST_FILL_DATE") ? msg.getElementAsInt32("EMSX_LAST_FILL_DATE") : 0;
						int emsx_last_fill_time = msg.hasElement("EMSX_LAST_FILL_TIME") ? msg.getElementAsInt32("EMSX_LAST_FILL_TIME") : 0;
						std::string emsx_last_market = msg.hasElement("EMSX_LAST_MARKET") ? msg.getElementAsString("EMSX_LAST_MARKET") : "";
						double emsx_last_price = msg.hasElement("EMSX_LAST_PRICE") ? msg.getElementAsFloat64("EMSX_LAST_PRICE") : 0;
						int emsx_last_shares = msg.hasElement("EMSX_LAST_SHARES") ? msg.getElementAsInt32("EMSX_LAST_SHARES") : 0;
						double emsx_limit_price = msg.hasElement("EMSX_LIMIT_PRICE") ? msg.getElementAsFloat64("EMSX_LIMIT_PRICE") : 0;
						double emsx_misc_fees = msg.hasElement("EMSX_MISC_FEES") ? msg.getElementAsFloat64("EMSX_MISC_FEES") : 0;
						int emsx_ml_leg_quantity = msg.hasElement("EMSX_ML_LEG_QUANTITY") ? msg.getElementAsInt32("EMSX_ML_LEG_QUANTITY") : 0;
						int emsx_ml_num_legs = msg.hasElement("EMSX_ML_NUM_LEGS") ? msg.getElementAsInt32("EMSX_ML_NUM_LEGS") : 0;
						double emsx_ml_percent_filled = msg.hasElement("EMSX_ML_PERCENT_FILLED") ? msg.getElementAsFloat64("EMSX_ML_PERCENT_FILLED") : 0;
						double emsx_ml_ratio = msg.hasElement("EMSX_ML_RATIO") ? msg.getElementAsFloat64("EMSX_ML_RATIO") : 0;
						double emsx_ml_remain_balance = msg.hasElement("EMSX_ML_REMAIN_BALANCE") ? msg.getElementAsFloat64("EMSX_ML_REMAIN_BALANCE") : 0;
						std::string emsx_ml_strategy = msg.hasElement("EMSX_ML_STRATEGY") ? msg.getElementAsString("EMSX_ML_STRATEGY") : "";
						int emsx_ml_total_quantity = msg.hasElement("EMSX_ML_TOTAL_QUANTITY") ? msg.getElementAsInt32("EMSX_ML_TOTAL_QUANTITY") : 0;
						std::string emsx_notes = msg.hasElement("EMSX_NOTES") ? msg.getElementAsString("EMSX_NOTES") : "";
						double emsx_nse_avg_price = msg.hasElement("EMSX_NSE_AVG_PRICE") ? msg.getElementAsFloat64("EMSX_NSE_AVG_PRICE") : 0;
						int emsx_nse_filled = msg.hasElement("EMSX_NSE_FILLED") ? msg.getElementAsInt32("EMSX_NSE_FILLED") : 0;
						std::string emsx_order_type = msg.hasElement("EMSX_ORDER_TYPE") ? msg.getElementAsString("EMSX_ORDER_TYPE") : "";
						std::string emsx_p_a = msg.hasElement("EMSX_P_A") ? msg.getElementAsString("EMSX_P_A") : "";
						double emsx_percent_remain = msg.hasElement("EMSX_PERCENT_REMAIN") ? msg.getElementAsFloat64("EMSX_PERCENT_REMAIN") : 0;
						double emsx_principal = msg.hasElement("EMSX_PRINCIPAL") ? msg.getElementAsFloat64("EMSX_PRINCIPAL") : 0;
						int emsx_queued_date = msg.hasElement("EMSX_QUEUED_DATE") ? msg.getElementAsInt32("EMSX_QUEUED_DATE") : 0;
						int emsx_queued_time = msg.hasElement("EMSX_QUEUED_TIME") ? msg.getElementAsInt32("EMSX_QUEUED_TIME") : 0;
						std::string emsx_reason_code = msg.hasElement("EMSX_REASON_CODE") ? msg.getElementAsString("EMSX_REASON_CODE") : "";
						std::string emsx_reason_desc = msg.hasElement("EMSX_REASON_DESC") ? msg.getElementAsString("EMSX_REASON_DESC") : "";
						double emsx_remain_balance = msg.hasElement("EMSX_REMAIN_BALANCE") ? msg.getElementAsFloat64("EMSX_REMAIN_BALANCE") : 0;
						int emsx_route_create_date = msg.hasElement("EMSX_ROUTE_CREATE_DATE") ? msg.getElementAsInt32("EMSX_ROUTE_CREATE_DATE") : 0;
						int emsx_route_create_time = msg.hasElement("EMSX_ROUTE_CREATE_TIME") ? msg.getElementAsInt32("EMSX_ROUTE_CREATE_TIME") : 0;
						int emsx_route_id = msg.hasElement("EMSX_ROUTE_ID") ? msg.getElementAsInt32("EMSX_ROUTE_ID") : 0;
						std::string emsx_route_ref_id = msg.hasElement("EMSX_ROUTE_REF_ID") ? msg.getElementAsString("EMSX_ROUTE_REF_ID") : "";
						int emsx_route_last_update_time = msg.hasElement("EMSX_ROUTE_LAST_UPDATE_TIME") ? msg.getElementAsInt32("EMSX_ROUTE_LAST_UPDATE_TIME") : 0;
						double emsx_route_price = msg.hasElement("EMSX_ROUTE_PRICE") ? msg.getElementAsFloat64("EMSX_ROUTE_PRICE") : 0;
						int emsx_sequence = msg.hasElement("EMSX_SEQUENCE") ? msg.getElementAsInt32("EMSX_SEQUENCE") : 0;
						double emsx_settle_amount = msg.hasElement("EMSX_SETTLE_AMOUNT") ? msg.getElementAsFloat64("EMSX_SETTLE_AMOUNT") : 0;
						int emsx_settle_date = msg.hasElement("EMSX_SETTLE_DATE") ? msg.getElementAsInt32("EMSX_SETTLE_DATE") : 0;
						std::string emsx_status = msg.hasElement("EMSX_STATUS") ? msg.getElementAsString("EMSX_STATUS") : "";
						double emsx_stop_price = msg.hasElement("EMSX_STOP_PRICE") ? msg.getElementAsFloat64("EMSX_STOP_PRICE") : 0;
						int emsx_strategy_end_time = msg.hasElement("EMSX_STRATEGY_END_TIME") ? msg.getElementAsInt32("EMSX_STRATEGY_END_TIME") : 0;
						double emsx_strategy_part_rate1 = msg.hasElement("EMSX_STRATEGY_PART_RATE1") ? msg.getElementAsFloat64("EMSX_STRATEGY_PART_RATE1") : 0;
						double emsx_strategy_part_rate2 = msg.hasElement("EMSX_STRATEGY_PART_RATE2") ? msg.getElementAsFloat64("EMSX_STRATEGY_PART_RATE2") : 0;
						int emsx_strategy_start_time = msg.hasElement("EMSX_STRATEGY_START_TIME") ? msg.getElementAsInt32("EMSX_STRATEGY_START_TIME") : 0;
						std::string emsx_strategy_style = msg.hasElement("EMSX_STRATEGY_STYLE") ? msg.getElementAsString("EMSX_STRATEGY_STYLE") : "";
						std::string emsx_strategy_type = msg.hasElement("EMSX_STRATEGY_TYPE") ? msg.getElementAsString("EMSX_STRATEGY_TYPE") : "";
						std::string emsx_tif = msg.hasElement("EMSX_TIF") ? msg.getElementAsString("EMSX_TIF") : "";
						int emsx_time_stamp = msg.hasElement("EMSX_TIME_STAMP") ? msg.getElementAsInt32("EMSX_TIME_STAMP") : 0;
						std::string emsx_type = msg.hasElement("EMSX_TYPE") ? msg.getElementAsString("EMSX_TYPE") : "";
						int emsx_urgency_level = msg.hasElement("EMSX_URGENCY_LEVEL") ? msg.getElementAsInt32("EMSX_URGENCY_LEVEL") : 0;
						double emsx_user_comm_amount = msg.hasElement("EMSX_USER_COMM_AMOUNT") ? msg.getElementAsFloat64("EMSX_USER_COMM_AMOUNT") : 0;
						double emsx_user_comm_rate = msg.hasElement("EMSX_USER_COMM_RATE") ? msg.getElementAsFloat64("EMSX_USER_COMM_RATE") : 0;
						double emsx_user_fees = msg.hasElement("EMSX_USER_FEES") ? msg.getElementAsFloat64("EMSX_USER_FEES") : 0;
						double emsx_user_net_money = msg.hasElement("EMSX_USER_NET_MONEY") ? msg.getElementAsFloat64("EMSX_USER_NET_MONEY") : 0;
						int emsx_working = msg.hasElement("EMSX_WORKING") ? msg.getElementAsInt32("EMSX_WORKING") : 0;

						ConsoleOut(d_consoleLock_p) << "ROUTE MESSAGE: CorrelationID(" << msg.correlationId() << ")  Status(" << event_status << ")" << std::endl;

						ConsoleOut(d_consoleLock_p) << "API_SEQ_NUM: " << api_seq_num << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ACCOUNT: " << emsx_account << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_AMOUNT: " << emsx_amount << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_AVG_PRICE: " << emsx_avg_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BROKER: " << emsx_broker << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BROKER_COMM: " << emsx_broker_comm << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BSE_AVG_PRICE: " << emsx_bse_avg_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_BSE_FILLED: " << emsx_bse_filled << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_CLEARING_ACCOUNT: " << emsx_clearing_account << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_CLEARING_FIRM: " << emsx_clearing_firm << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_COMM_DIFF_FLAG: " << emsx_comm_diff_flag << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_COMM_RATE: " << emsx_comm_rate << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_CURRENCY_PAIR: " << emsx_currency_pair << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_CUSTOM_ACCOUNT: " << emsx_custom_account << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_DAY_AVG_PRICE: " << emsx_day_avg_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_DAY_FILL: " << emsx_day_fill << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_EXCHANGE_DESTINATION: " << emsx_exchange_destination << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_EXEC_INSTRUCTION: " << emsx_exec_instruction << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_EXECUTE_BROKER: " << emsx_execute_broker << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_FILL_ID: " << emsx_fill_id << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_FILLED: " << emsx_filled << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_GTD_DATE: " << emsx_gtd_date << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_HAND_INSTRUCTION: " << emsx_hand_instruction << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_IS_MANUAL_ROUTE: " << emsx_is_manual_route << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_LAST_FILL_DATE: " << emsx_last_fill_date << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_LAST_FILL_TIME: " << emsx_last_fill_time << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_LAST_MARKET: " << emsx_last_market << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_LAST_PRICE: " << emsx_last_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_LAST_SHARES: " << emsx_last_shares << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_LIMIT_PRICE: " << emsx_limit_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_MISC_FEES: " << emsx_misc_fees << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ML_LEG_QUANTITY: " << emsx_ml_leg_quantity << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ML_NUM_LEGS: " << emsx_ml_num_legs << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ML_PERCENT_FILLED: " << emsx_ml_percent_filled << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ML_RATIO: " << emsx_ml_ratio << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ML_REMAIN_BALANCE: " << emsx_ml_remain_balance << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ML_STRATEGY: " << emsx_ml_strategy << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ML_TOTAL_QUANTITY: " << emsx_ml_total_quantity << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_NOTES: " << emsx_notes << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_NSE_AVG_PRICE: " << emsx_nse_avg_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_NSE_FILLED: " << emsx_nse_filled << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ORDER_TYPE: " << emsx_order_type << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_P_A: " << emsx_p_a << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_PERCENT_REMAIN: " << emsx_percent_remain << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_PRINCIPAL: " << emsx_principal << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_QUEUED_DATE: " << emsx_queued_date << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_QUEUED_TIME: " << emsx_queued_time << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_REASON_CODE: " << emsx_reason_code << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_REASON_DESC: " << emsx_reason_desc << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_REMAIN_BALANCE: " << emsx_remain_balance << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ROUTE_CREATE_DATE: " << emsx_route_create_date << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ROUTE_CREATE_TIME: " << emsx_route_create_time << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ROUTE_ID: " << emsx_route_id << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ROUTE_REF_ID: " << emsx_route_ref_id << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ROUTE_LAST_UPDATE_TIME: " << emsx_route_last_update_time << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_ROUTE_PRICE: " << emsx_route_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_SEQUENCE: " << emsx_sequence << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_SETTLE_AMOUNT: " << emsx_settle_amount << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_SETTLE_DATE: " << emsx_settle_date << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STATUS: " << emsx_status << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STOP_PRICE: " << emsx_stop_price << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_END_TIME: " << emsx_strategy_end_time << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_PART_RATE1: " << emsx_strategy_part_rate1 << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_PART_RATE2: " << emsx_strategy_part_rate2 << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_START_TIME: " << emsx_strategy_start_time << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_STYLE: " << emsx_strategy_style << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_STRATEGY_TYPE: " << emsx_strategy_type << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TIF: " << emsx_tif << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TIME_STAMP: " << emsx_time_stamp << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_TYPE: " << emsx_type << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_URGENCY_LEVEL: " << emsx_urgency_level << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_USER_COMM_AMOUNT: " << emsx_user_comm_amount << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_USER_COMM_RATE: " << emsx_user_comm_rate << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_USER_FEES: " << emsx_user_fees << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_USER_NET_MONEY: " << emsx_user_net_money << std::endl;
						ConsoleOut(d_consoleLock_p) << "EMSX_WORKING: " << emsx_working << std::endl;
					}
				}
			}
			else {
				ConsoleOut(d_consoleLock_p) << "Error: Unexpected message" << std::endl;
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
			case Event::ADMIN: {
				MutexGuard guard(&d_context_p->d_mutex);
				return processAdminEvent(event, session);
			} break;
			case Event::SESSION_STATUS: {
				MutexGuard guard(&d_context_p->d_mutex);
				return processSessionEvent(event, session);
			} break;
			case Event::SERVICE_STATUS: {
				MutexGuard guard(&d_context_p->d_mutex);
				return processServiceEvent(event, session);
			} break;
			case Event::SUBSCRIPTION_STATUS: {
				MutexGuard guard(&d_context_p->d_mutex);
				return processSubscriptionStatusEvent(event, session);
			} break;
			case Event::SUBSCRIPTION_DATA: {
				MutexGuard guard(&d_context_p->d_mutex);
				return processSubscriptionDataEvent(event, session);
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

class EMSXSubscriptions
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

	EMSXSubscriptions()
		: d_session(0)
		, d_eventHandler(0)
	{


		d_sessionOptions.setServerHost("localhost");
		d_sessionOptions.setServerPort(8194);
		d_sessionOptions.setMaxEventQueueSize(10000);
	}

	~EMSXSubscriptions()
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
	std::cout << "Bloomberg - EMSX API Example - EMSXSubscriptions" << std::endl;
	EMSXSubscriptions emsxSubscriptions;
	try {
		emsxSubscriptions.run(argc, argv);
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
