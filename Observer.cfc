<cfcomponent displayname="Observer" output="no">
<cfscript>
/*
@Subject A component with a 'setObserver' method into which Observer will be passed.
*/
public function init(Subject) {
	// Here is where event listeners will be stored.
	Variables.sEvents = {};

	// Default the number of times a particular event can be announced in the same request.
	Variables.RecursionLimit = 15;

	// This just provides some friendly method names that CF won't allow natively.
	This["notifyEvent"] = announceEvent;
	This["register"] = registerListener;
	This["unregister"] = unregisterListener;

	This["announce"] = announceEvent;

	// Pass Observer to the Subject.
	if ( StructKeyExists(Arguments,"Subject") ) {
		setSubject(Arguments.Subject);
	}

	Variables.Me = This;

	return This;
}

/*
* I am called any time an event is run for which a listener may be attached.
*/
public void function announceEvent(
	string EventName="update",
	struct Args,
	result,
	This,
	numeric RecursionLimit
) {
	var key = "";
	var ii = 0;
	var begin = 0;
	var end = 0;
	var sRecursiveEvent = 0;
	var ArrLen = 0;

	// In case this is called before init().
	if ( NOT StructKeyExists(Variables,"sEvents") ) {
		exit;
	}

	// Set default for RecursionLimit. Must be after above line in case this is called before init().
	if ( NOT StructKeyExists(Arguments,"RecursionLimit") ) {
		Arguments.RecursionLimit = Variables.RecursionLimit;
	}
	// Ensure arguments exist.
	if ( NOT StructKeyExists(Arguments,"Args") ) {
		Arguments["Args"] = {};
	}
	// Pass on result and This.
	if ( StructKeyExists(Arguments,"result") AND NOT StructKeyExists(Arguments.Args,"result") ) {
		Arguments.Args.result = Arguments.result;
	}
	if ( StructKeyExists(Arguments,"This") AND NOT StructKeyExists(Arguments.Args,"This") ) {
		Arguments.Args.This = Arguments.This;
	}

	// Make sure that the event hasn't been called more times that Observer allows per request.
	checkEventRecursion(Arguments.EventName,Arguments.RecursionLimit);

	// If the event has listeners, call the listener method for each.
	if ( StructKeyExists(Variables.sEvents,Arguments.EventName) ) {
		ArrLen = ArrayLen(Variables.sEvents[Arguments.EventName]);
		if ( ArrLen ) {
			for ( ii=1; ii LTE ArrLen; ii++ ) {
				begin = getTickCount();
				callListener(Variables.sEvents[EventName][ii],Arguments.Args);
				end = getTickCount();
				// Observer should know about its own announcements.
				if ( NOT StructKeyExists(request,"Observer_announcingevent") ) {
					request["Observer_announcingevent"] = now();
					sRecursiveEvent = {
						EventName="Observer:announceEvent",
						Args={
							RunTime=end-begin,
							EventName=Arguments.EventName,
							ListenerName="#Variables.sEvents[EventName][ii].ListenerName#",
							Component=Variables.sEvents[EventName][ii].Listener,
							MethodName="#Variables.sEvents[EventName][ii].ListenerMethod#",
							args=Arguments.Args
						}
					};
					invoke(
						Variables.Me,
						"announceEvent",
						sRecursiveEvent
					);
					StructDelete(request,"Observer_announcingevent");
				}
			}
		}
	}

	request.ObserverEventStack[Arguments.EventName] = request.ObserverEventStack[Arguments.EventName] - 1;
}

/*
* I call the method for a listener.
*/
public function callListener(
	required struct sListener,
	struct Args
) {
	
	if ( sListener.delay ) {
		callListenerLater(ArgumentCollection=Arguments)
	} else {
		callListenerNow(ArgumentCollection=Arguments);
	}

}

/*
* I call the method for a listener.
*/
public function callListenerLater(
	required struct sListener,
	struct Args
) {
	var ii = 0;

	Arguments["Hash"] = makeListenerCallHash(ArgumentCollection=Arguments);

	loadRequestVars();

	//If this listener call already exists, remove it (so we can add it back at the end of the queue)
	for ( ii = ArrayLen(request["Observer"]["aDelayeds"]); ii GTE 1; ii=ii-1 ) {
		if ( request["Observer"]["aDelayeds"][ii]["Hash"] EQ Arguments["Hash"] ) {
			ArrayDeleteAt(request["Observer"]["aDelayeds"], ii);
		}
	}

	ArrayAppend(
		request["Observer"]["aDelayeds"],
		Arguments
	);

}

/*
* I call the method for a listener.
*/
public function callListenerNow(
	required struct sListener,
	struct Args
) {
	invoke(
		sListener.Listener,
		sListener.ListenerMethod,
		Arguments.Args
	);

}

/*
* I return all of the event listeners that Observer is tracking.
*/
public struct function getEventListeners() {

	return Variables.sEvents;
}

/*
* I return all of the listeners for the given event.
*/
public struct function getListeners(string EventName="update") {
	var sResult = {};
	var ii = "";

	// Look through all of the event listeners and get only the ones for the given event.
	if ( StructKeyExists(Variables.sEvents,Arguments.EventName) AND ArrayLen(Variables.sEvents[Arguments.EventName]) ) {
		for ( ii=1; ii LTE ArrayLen(Variables.sEvents[Arguments.EventName]); ii++ ) {
			sResult[Variables.sEvents[Arguments.EventName][ii]["ListenerName"]] = Variables.sEvents[Arguments.EventName][ii];
		}
	}

	return sResult;
}

/*
* I make sure that an event isn't called more times than Observer is set to allow.
*/
private void function checkEventRecursion(
	string EventName="update",
	required numeric RecursionLimit
) {

	// Make sure the request variable exists.
	if ( NOT StructKeyExists(request,"ObserverEventStack") ) {
		request["ObserverEventStack"] = {};
	}

	// Default the count to zero for this event.
	if ( NOT StructKeyExists(request.ObserverEventStack,Arguments.EventName) ) {
		request.ObserverEventStack[Arguments.EventName] = 0;
	}

	// Increment the count for this event
	request.ObserverEventStack[Arguments.EventName] = request.ObserverEventStack[Arguments.EventName] + 1;

	// Throw an exception if the event is called more times in a request than allowed.
	if ( request.ObserverEventStack[Arguments.EventName] GT Arguments.RecursionLimit ) {
		throw(type="Observer",message="Event announced recursively",detail="The #Arguments.EventName# event was announced more than the maximum number of times allowed (#Arguments.RecursionLimit#) during a single request.");
	}

}

/*
* I register a listener for an event. Not Idempotent.
* @Listener The component listening for the event, on which a method will be called.
* @ListenerName A name for the listening component.
* @ListenerMethod The method to call on the component when the event occurs.
* @EventName The name of the event to which this listener should respond.
* @delay Indicate if the listener method call should be delayed until the runDelays method is called at the end of the request.
*/
public void function registerListener(
	required Listener,
	required string ListenerName,
	string ListenerMethod="listen",
	string EventName="update",
	boolean delay="false"
) {
	
	unregisterListener(ArgumentCollection=Arguments);

	if ( NOT StructKeyExists(Variables.sEvents,Arguments.EventName) ) {
		Variables.sEvents[Arguments.EventName] = ArrayNew(1);
	}

	ArrayAppend(Variables.sEvents[Arguments.EventName],Arguments);

}

/*
* I register one listener to listen for multiple events at once.
* @Listener The component listening for the event, on which a method will be called.
* @ListenerName A name for the listening component.
* @ListenerMethod The method to call on the component when the event occurs.
* @EventNames A list of events to which this listener should respond.
* @delay Indicate if the listener method call should be delayed until the runDelays method is called at the end of the request.
*/
public void function registerListeners(
	required Listener,
	required string ListenerName,
	string ListenerMethod="listen",
	required string EventNames,
	boolean delay
) {
	var event = "";

	for ( event in ListToArray(Arguments.EventNames) ) {
		registerListener(Listener=Listener,ListenerName=ListenerName,ListenerMethod=ListenerMethod,EventName=event);
	}

}

/*
* I run any delayed listener method calls.
*/
public void function runDelays() {
	var sListener = 0;

	//Make sure request variables exist.
	loadRequestVars();

	//Get the first item and delete it instead of looping through the array so that items can be appeneded as we are moving through the list.
	while ( ArrayLen(request.Observer.aDelayeds) ) {
		sListener = StructCopy(request.Observer.aDelayeds[1]);
		ArrayDeleteAt(request.Observer.aDelayeds,1);
		callListenerNow(ArgumentCollection=sListener);
	}
}

/*
* I make a listener no longer listen for the given event.
* @Listener The component that was listening for the event.
* @ListenerMethod The method that was to be called on the component when the event occurs.
* @EventName The name of the event to which this listener would have responded. No action is taken unless this is included.
*/
public void function unregisterListener(
	required string ListenerName,
	string ListenerMethod="listen"	,
	string EventName
) {
	var ii = 0;

	if ( StructKeyExists(Variables.sEvents,Arguments.EventName) ) {
		for ( ii=ArrayLen(Variables.sEvents[Arguments.EventName]); ii GTE 1; ii-- ) {
			if (
					Arguments.ListenerName EQ Variables.sEvents[Arguments.EventName][ii].ListenerName
				AND	Arguments.ListenerMethod EQ Variables.sEvents[Arguments.EventName][ii].ListenerMethod
				AND	Arguments.EventName EQ Variables.sEvents[Arguments.EventName][ii].EventName
			) {
				ArrayDeleteAt(Variables.sEvents[Arguments.EventName],ii);
				break;
			}
		}
	}
}

public void function injectObserver(required Component) {
	
	Arguments.Component.setObserver = setObserver;

	Arguments.Component.setObserver(This);

}

public void function setObserver(required Observer) {
	
	if ( NOT StructKeyExists(Variables,"Observer") ) {
		Variables.Observer = Arguments.Observer;
		This.Observer = Arguments.Observer;
	}
}

public function setSubject(required Subject) {

	Variables.Subject = Arguments.Subject;

	if ( StructKeyExists(Variables.Subject,"setObserver") ) {
		Variables.Subject.setObserver(This);
	}

	return This;
}

/*
* I make sure the needed request variables exist.
*/
private function loadRequestVars() {
	
	if ( NOT StructKeyExists(request,"Observer") ) {
		request["Observer"] = {};
	}
	if ( NOT StructKeyExists(request["Observer"],"aDelayeds") ) {
		request["Observer"]["aDelayeds"] = [];
	}

}

private string function makeListenerCallHash(
	required struct sListener,
	struct Args
) {
	var result = Arguments.sListener.ListenerName & "." & Arguments.sListener.ListenerMethod & "." & Arguments.sListener.EventName;
	var sCanonicalArgs = {};
	var key = "";

	if ( StructKeyExists(Arguments,"Args") AND StructCount(Arguments.Args) ) {
		for ( key in Arguments.Args ) {
			//We don't want to deal with null args
			if ( StructKeyExists(Arguments.Args,key) ) {
				sCanonicalArgs[key] = Arguments.Args[key];
			}
		}
		if ( StructCount(sCanonicalArgs) ) {
			result = result & "." & SerializeJSON(sCanonicalArgs);
		}
	}

	result = Hash(LCase(result));

	return result;
}
</cfscript>

</cfcomponent>
