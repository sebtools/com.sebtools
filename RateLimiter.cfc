<cfcomponent>
<cfscript>
public function init(
	string id="rate",
	string timeSpan="#CreateTimeSpan(0,0,0,3)#"
) {

	Variables.instance = Arguments;
	Variables.running = {};

	Variables.timeSpan_ms = Int(Arguments.timeSpan * 100000 / 1.1574074074) * 1000;

	Variables.Cacher = CreateObject("component","MrECache").init("rlcache",CreateTimeSpan(0,0,10,0));
	Variables.MrECache = CreateObject("component","MrECache").init("limit_#Arguments.id#",Arguments.timeSpan);

	return This;
}

/**
* I mark an id as having just been called.
*/
public void function called(
	required string id,
	result
) {

	if ( NOT StructKeyExists(Arguments,"result") ) {
		Arguments.result = now();
	}

	Variables.MrECache.put(Arguments.id,Arguments.result);
	StructDelete(Variables.running,Arguments.id);

}

/**
* I see if the given id is currently running.
*/
public void function calling(required string id) {
	Variables.running[Arguments.id] = now();
}

public boolean function isAvailable(required string id) {
	return Variables.MrECache.exists(Arguments.id);
}

/**
* I see if the given id is callable.
*/
public boolean function isCallable(required string id) {
	return NOT ( isAvailable(Arguments.id) OR isCalling(Arguments.id) );
}

/**
* I see if the given id is being called currently.
* @check Check if it was run recently.
*/
public boolean function isCalling(
	required string id,
	boolean check="false"
) {

	// If it was last called over 10 minutes ago, something is hinky and/or no need to worry about the rate limiting for this part.
	if (
		Arguments.check
		AND
		StructKeyExists(Variables.running,Arguments.id)
		AND
		DateAdd("n",10,Variables.running[Arguments.id]) LT now()
	) {
		StructDelete(Variables.running,Arguments.id);
	}

	return StructKeyExists(Variables.running,Arguments.id);
}

/**
* I call the given method if it hasn't been called within the rate limit time. I return a cached value if one is available.
* @waitlimit Maximum number of milliseconds to wait.
* @waitstep Milliseconds to wait between checks.
*/
public function cached(
	required string id,
	required Component,
	required MethodName,
	struct Args,
	default,
	string timeSpan,
	numeric waitlimit="100",
	numeric waitstep="20"
) {
	var sCacherArgs = {
		Component=This,
		MethodName="method",
		Args=Arguments
	};
	if ( StructKeyExists(Arguments,"timeSpan") ) {
		sCacherArgs["timeSpan"] = Arguments.timeSpan;
	}
	if ( StructKeyExists(Arguments,"idleTime") ) {
		sCacherArgs["idleTime"] = Arguments.idleTime;
	}

	return Variables.Cacher.meth(ArgumentCollection=sCacherArgs);
}

/**
* I call the given method if it hasn't been called within the rate limit time.
* @waitlimit Maximum number of milliseconds to wait.
* @waitstep Milliseconds to wait between checks.
*/
public function method(
	required string id,
	required Component,
	required MethodName,
	struct Args,
	default,
	numeric waitlimit="100",
	numeric waitstep="20"
) {
	var local = {};
	var waited = 0;

	// No reason to wait longer than the limit of the rate limiter.
	Arguments.waitlimit = Min(Arguments.waitlimit,Variables.timeSpan_ms);

	// If method is currently running, wait up to the wait limit for it to finish.
	if ( isCalling(Arguments.id,true) ) {
		while ( isCalling(Arguments.id) AND waited LT waitlimit ) {
			sleep(Arguments.waitstep);
			waited += Arguments.waitstep;
		}
	}

	if ( NOT isCallable(Arguments.id) ) {
		// If MrECache has rate limiter value then we are within the rate limit and must return the default value.
		if ( NOT StructKeyExists(Arguments,"default") ) {
			if ( isAvailable(Arguments.id) ) {
				Arguments.default = Variables.MrECache.get(Arguments.id);
			} else {
				called(Arguments.id);
				throw(message="Unable to retrieve data from #Arguments.MethodName# (waited #waited# milliseconds).",type="RateLimiter");
			}
		}
		called(Arguments.id,Arguments.default);
		return Arguments.default;
	} else {
		// If not within the rate limit then call the method and return the value.
		calling(Arguments.id);
		if ( NOT StructKeyExists(Arguments,"Args") ) {
			Arguments["Args"] = {};
		}
		local.result = invoke(Arguments.Component,Arguments.MethodName,Arguments.Args);
		if ( StructKeyExists(local,"result") ) {
			called(Arguments.id,local.result);
			return local.result;
		} else {
			called(Arguments.id);
		}
	}

}
</cfscript>
</cfcomponent>
