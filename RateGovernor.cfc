<cfcomponent displayname="Rate Governor" extends="com.sebtools.component" output="false"><cfscript>

/**
@id The ID of the rate governor instance.
@interval The interval for rate limiting (e.g., "1 minute", "2 hours").
@limit The maximum number of requests allowed within the interval. 
*/
public function init(
	required any Scheduler,
	required string id,
	required any Service,
	required string MethodName,
	required string interval,
	numeric limit=1,
	string IdempotentKey
) {

	initInternal(ArgumentCollection=Arguments);

	// Create MrECache instance with daily cache times which we'll change immediately below.
	// This is so that we can use MrECacheto get the TimeSpan and Seconds values.
	Variables.MrECache = CreateObject("component","com.sebtools.MrECache").init(
		"RateGovernor:#Variables.id#",
		CreateTimeSpan(1,0,0,0),
		CreateTimeSpan(1,0,0,0)
	);
	Variables.TimeSpan = Variables.MrECache.getTimeSpanFromInterval(Variables.interval);
	Variables.Seconds = Variables.MrECache.getSecondsFromTimeSpan(Variables.TimeSpan);

	// Make sure the MrECache time span is long enough to handle scheduled tasks and the rate limiting.
	Variables.MrECacheTimeSpan = (
		2
		*
		Min(
			Variables.TimeSpan,
			Variables.MrECache.getTimeSpanFromInterval("20 minutes")
		)
	);
	Variables.MrECache.setTimeSpan( Variables.MrECacheTimeSpan );
	Variables.MrECache.setIdleTime( Variables.MrECacheTimeSpan );

	return This;
}

/**
 * Adds a request to the queue.
 * @param args The arguments to pass to the method.
 * @param callback The callback function to execute after the request is completed.
 */
public void function addToQueue(
	required struct args,
	function callback,
	boolean doProcess=true
) {
	var aRequestQueue = getQueued();
	var sArgs = Arguments;
	// Only add the request if it is not already in the queue with the same IdempotentKey
	var doAdd = aRequestQueue.every(function(req) {
		return !(
			StructKeyExists(Variables,"IdempotentKey")
			AND
			(
				StructKeyExists(req.args, Variables.IdempotentKey)
				AND
				req.args[Variables.IdempotentKey] == sArgs.args[Variables.IdempotentKey]
			)
		);
	});
	//StructDelete(sArgs,"doProcess");
	if ( doAdd ) {
		ArrayAppend(aRequestQueue, sArgs);
		Variables.MrECache.put("aRequestQueue", aRequestQueue);
	}
	if ( Arguments.doProcess ) {
		processQueue();
	}
}

public array function getQueued() {
	
	return Variables.MrECache.get("aRequestQueue",[]);
}

public array function getRequestTimes() {
	
	return Variables.MrECache.get("aRequestTimes",[]);
}

public void function clearQueued() {
	Variables.MrECache.put("aRequestQueue",[]);
}

/**
 * I process the request queue while respecting rate limits.
 */
public void function processQueue() {
	var aRequestQueue = Variables.MrECache.get("aRequestQueue",[]); // Get the request queue from the cache
	var aRequestTimes = Variables.MrECache.get("aRequestTimes",[]); // Get the request times from the cache

	// No requests to process
	if ( NOT ArrayLen(aRequestQueue) ) {
		return;
	}

	// Remove timestamps older than the rate limit interval. The purpuse of this array is to track the number of requests made in the last interval.
	aRequestTimes = aRequestTimes.filter(function(requestTime) {
		return ( DateDiff("s", requestTime,  now()) < Variables.Seconds );
	});

	//Process as many items in the queue as possible based on the rate limit
	while ( ArrayLen(aRequestQueue) AND ArrayLen(aRequestTimes) < Variables.limit ) {
		try {
			runRequest(aRequestQueue[1]);
		} catch (any e) {
			ArrayAppend(aRequestTimes, now());
			ArrayDeleteAt(aRequestQueue, 1); // Remove the processed request from the queue
			Variables.MrECache.put("aRequestQueue", aRequestQueue); // Update the request queue in the cache
			Variables.MrECache.put("aRequestTimes", aRequestTimes); // Update the request times in the cache
			rethrow;
		}
		ArrayAppend(aRequestTimes, now());
		ArrayDeleteAt(aRequestQueue, 1); // Remove the processed request from the queue
	}

	Variables.MrECache.put("aRequestQueue", aRequestQueue); // Update the request queue in the cache
	Variables.MrECache.put("aRequestTimes", aRequestTimes); // Update the request times in the cache

	// If there are more requests in the queue, schedule the next one. This does limit to 15 minutes as the minimum interval.
	if ( ArrayLen(aRequestQueue) ) {
		Variables.Scheduler.setTask(
			Name="RateGovernor:#Variables.id#",
			ComponentPath="com.sebtools.RateGovernor",
			Component=This,
			MethodName="processQueue",
			Interval="once"
		);
	}

}

private void function runRequest(required struct sRequest) {
	var loc = {};

	loc.result = invoke(Variables.Service, Variables.MethodName, sRequest.args);

	// Call the callback function with the result
	if ( StructKeyExists(sRequest,"callback") AND isCustomFunction(sRequest.callback) ) {
		if ( StructKeyExists(loc,"result") ) {
			sRequest.callback(loc.result);
		} else {
			sRequest.callback();
		}
	}

}
</cfscript>
</cfcomponent>
