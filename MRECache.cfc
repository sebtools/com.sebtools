<cfcomponent display="Mr. Ecache" hint="I am a handy wrapper for the built-in Ehcache functionality.">
<cfscript>
public function init(
	string id="",
	string timeSpan,
	string idleTime,
	Observer,
	numeric waitLimit=10,
	string timeoutAction="default"
) {

	Variables.instance = Arguments;

	Variables.meta = {};
	Variables.processing = {};

	return This;
}

/*
* I clear all caches that start with the given prefix.
*/
public void function clearCaches(string prefix="") {
	var aIds = ids(Arguments.prefix);// Make sure to just get values for this instance of MrECache.
	var id = "";

	// Ditch all of the ids for this instance
	for ( id in aIds ) {
		remove(id);
	}

}

/*
* I get all of the cached data for this instance (use sparingly)
*/
public struct function dump(string prefix="") {
	var aIds = ids(Arguments.prefix);// Make sure to just get values for this instance of MrECache.
	var id = "";
	var sResult = {};

	// Ditch all of the ids for this instance
	for ( id in aIds ) {
		sResult[id] = get(id);
	}

	return sResult;
}

public boolean function exists(required string id) {
	var aCacheNames = CacheGetAllIds();
	var key = qualify(Arguments.id);
	var ii = 0;

	// Could use, cacheIdExists(), but ditching just that allows this to run on versions before ColdFusion 10.

	//Loop through all cache names to see if the given one exists.
	for ( ii=1; ii LTE ArrayLen(aCacheNames); ii=ii+1 ) {
		if ( aCacheNames[ii] EQ key ) {
			return true;
		}
	}

	return false;
}

/*
* I get data from the cache (getting the data from the function if isn't there yet).
*/
public function func(
	required string id,
	required Fun,
	struct Args,
	string timeSpan,
	string idleTime,
	numeric waitLimit=variables.instance.waitLimit,
	string timeoutAction=variables.instance.timeoutAction
) {
	var local = {};
	var begin = 0;

	// Try to get this from cache. If it isn't there, this will return void and obliterate the key from the struct.
	local.result = get(id=Arguments.id,waitLimit=Arguments.waitLimit,timeoutAction=Arguments.timeoutAction);

	if ( NOT StructKeyExists(local,"result") ) {
		if ( NOT StructKeyExists(Arguments,"Args") ) {
			Arguments["Args"] = {};
		}
		begin = getTickCount();
		startGetPut(Arguments.id);
		try {
			local.result = Arguments.Fun(ArgumentCollection=Arguments.Args);
		} catch (any e) {
			removeProcessingKey(Arguments.id);
			rethrow;
		}
		logCall(type="func",id=Arguments.id,began=begin,args=Arguments);
		// Need something to return and store in the cache so we don't call the method every time.
		if ( NOT StructKeyExists(local,"result") ) {
			local.result = "";
		}
		StructDelete(Arguments,"Fun");
		StructDelete(Arguments,"Args");
		if ( StructKeyExists(local,"result") ) {
			Arguments["value"] = local.result;
		} else {
			Arguments["value"] = "";
		}
		put(ArgumentCollection=Arguments);
	}

	return local.result;
}

/*
* I get data from the cache (first using the default if it is given but the id isn't in the cache).
*/
public function get(
	required string id,
	default,
	numeric waitLimit=variables.instance.waitLimit,
	string timeoutAction=variables.instance.timeoutAction
) {
	var startTime = getTickCount();

	if ( Arguments.waitLimit GT 0 ) {

		// Wait for the given time limit for the id to be available in the cache.
		// This is useful for when you are using a function to get the data and it is taking a while to run.
		while (
			StructKeyExists(Variables.processing,Arguments.id)
			AND
			(getTickCount() - startTime) LT ( Arguments.waitLimit * 1000 )
		) {
			sleep(100);
		}

		//Handle the case where the id is still in the processing struct after the wait time.
		if ( StructKeyExists(Variables.processing,Arguments.id) ) {
			switch( ListFirst(Arguments.timeoutAction,":") ) {
				case "announce":
						// Notify Observer (if available)
						if ( 
							StructKeyExists(Variables.instance,"Observer")
							AND
							StructKeyExists(Variables.instance["Observer"],"announceEvent")
						) {
							var EventName = (ListLen(Arguments.timeoutAction,":") GT 1) ? ListRest(Arguments.timeoutAction,":") : "MrECache:timeout";
							Variables.instance.Observer.announceEvent(EventName=EventName,Args=Arguments);
						}
					brea;
				case "error":
						var ErrorMessage = (ListLen(Arguments.timeoutAction,":") GT 1) ? ListRest(Arguments.timeoutAction,":") : "Cache id #Arguments.id# timed out after waiting for #Arguments.waitLimit# seconds.";
						throw(
							message=ErrorMessage,
							type="CacheError"
						);
					break;
			}
		}

	}
	
	if ( StructKeyExists(Arguments,"default") ) {
		if ( NOT exists(Arguments.id) ) {
			startGetPut(Arguments.id);
			put(Arguments.id,Arguments.default);
		}
	}

	got(Arguments.id);

	if ( exists(Arguments.id) ) {
		return CacheGet(qualify(Arguments.id));
	}
}

/*
* I return a hash of the given data.
*/
public function getDataHash(required data) {

	if ( isSimpleValue(Arguments.data) ) {
		return Arguments.data;
	} else {
		return Hash(SerializeJSON(Arguments.data));
	}
}

/**
* I return a structure of currently processing ids.
*/
public struct function getProcessing() {

	return Variables.processing;
}

/*
* I make an id from a key and data.
*/
public function id(
	required string key,
	data
) {
	var result = Arguments.key;

	if ( StructKeyExists(Arguments,"data") ) {
		result = "#result#_" & getDataHash(Arguments.data);
	}

	return result;
}

public array function ids(string prefix="") {
	var id = qualify(Arguments.prefix);// Make sure to just get values for this instance of MrECache.
	var aCacheNames = CacheGetAllIds();
	var name = 0;
	var aResult = [];

	// Loop through all existing cache ids to get the ones that match the prefix.
	for ( name in aCacheNames ) {
		if ( Left(name,Len(id)) EQ id ) {
			ArrayAppend(
				aResult,
				dequalify(name)
			);
		}
	}

	return aResult;
}

/*
* I get data from the cache (getting the data from the method if isn't there yet).
*/
public function meth(
	required Component,
	required string MethodName,
	struct Args,
	string timeSpan,
	string idleTime,
	numeric waitLimit=variables.instance.waitLimit,
	string timeoutAction=variables.instance.timeoutAction
) {
	
	if ( NOT StructKeyExists(Arguments,"id") ) {
		Arguments.id = ListFirst(Arguments.MethodName,"_");
	}

	if ( StructKeyExists(Arguments,"Args") ) {
		Arguments.id = This.id(Arguments.id,Arguments.Args);
	}

	return method(ArgumentCollection=Arguments);
}

/*
* I get data from the cache (getting the data from the method if isn't there yet).
*/
public function method(
	required string id,
	required Component,
	required string MethodName,
	struct Args,
	string timeSpan,
	string idleTime,
	numeric waitLimit=variables.instance.waitLimit,
	string timeoutAction=variables.instance.timeoutAction
) {
	var local = {};
	var begin = 0;

	// Try to get this from cache. If it isn't there, this will return void and obliterate the key from the struct.
	local.result = get(id=Arguments.id,waitLimit=Arguments.waitLimit,timeoutAction=Arguments.timeoutAction);

	if ( NOT StructKeyExists(local,"result") ) {
		if ( NOT StructKeyExists(Arguments,"Args") ) {
			Arguments["Args"] = {};
		}
		begin = getTickCount();
		startGetPut(Arguments.id);
		try {
			// Call the method on the component and get the result.
			local.result = invoke(
				Arguments.Component,
				Arguments.MethodName,
				Arguments.Args
			);
		} catch (any e) {
			removeProcessingKey(Arguments.id);
			rethrow;
		}
		logCall(type="method",id=Arguments.id,began=begin,args=Arguments);
			StructDelete(Arguments,"Component");
			StructDelete(Arguments,"MethodName");
			StructDelete(Arguments,"Args");
			// Need something to return and store in the cache so we don't call the method every time.
			if ( NOT StructKeyExists(local,"result") ) {
				local.result = "";
			}
			Arguments["value"] = local.result;
			put(ArgumentCollection=Arguments);
	}

	return local.result;
}

/*
* I put data into the cache.
*/
public void function put(
	required string id,
	required value,
	string timeSpan,
	string idleTime
) {
	
	start(Arguments.id);

	Arguments = putargs(ArgumentCollection=Arguments);

	if ( StructKeyExists(Arguments,"idleTime") AND StructKeyExists(Arguments,"timeSpan") ) {
		CachePut(qualify(Arguments.id),Arguments.value,convertTimeSpan(Arguments.timeSpan),convertTimeSpan(Arguments.idleTime));
	} else if ( StructKeyExists(Arguments,"timeSpan") ) {
		CachePut(qualify(Arguments.id),Arguments.value,convertTimeSpan(Arguments.timeSpan));
	} else {
		CachePut(qualify(Arguments.id),Arguments.value);
	}

	removeProcessingKey(Arguments.id);

}

/*
* I return the prefix value for the given id.
*/
public string function getPrefix(required string id) {
	var prefix = "";

	if ( Len(Trim(Variables.instance.id)) ) {
		prefix = Trim(Variables.instance.id);
		if ( Len(Trim(Arguments.id)) ) {
			prefix &= ":";
		}
	}

	return prefix;
}

/*
* I return the localized reference to a fully qualified caching id.
*/
public string function dequalify(required string id) {
	var prefix = getPrefix(Arguments.id);

	if ( Len(Trim(prefix)) ) {
		Arguments.id = ReplaceNoCase(Arguments.id,prefix,"","ONE");
	}

	return Arguments.id;
}

/*
* I return the fully qualified id for caching.
*/
public string function qualify(required string id) {
	var prefix = getPrefix(Arguments.id);
	var result = prefix & Trim(Arguments.id);

	if ( NOT Len(Trim(result)) ) {
		throw(message="An id is required for caching.");
	}

	return result;
}

/*
* I remove an id from the cache.
*/
public void function remove(required string id) {
	
	CacheRemove(qualify(Arguments.id));
	StructDelete(Variables.meta,Arguments.id);
}

/**
* I remove a key from the processing struct.
*/
public void function removeProcessingKey(required string id) {
	
	StructDelete(Variables.processing,Arguments.id);

}

/*
* I am here just in case you forget that the method is called 'put'.
*/
public void function set(
	required string id,
	required value
) {
	put(ArgumentCollection=Arguments);
}

/*
* I set the default idle time for this instance of MRECache.
*/
public void function setIdleTime(required string idleTime) {
	
	Variables.instance.idleTime = Arguments.idleTime;

}

/*
* I set the default time span for this instance of MRECache.
*/
public void function setTimeSpan(required string timeSpan) {
	
	Variables.instance.timeSpan = Arguments.timeSpan;

}

/*
* I spawn and return a new instance of MrECache.
*/
public function spawn(
	required string id,
	string timeSpan,
	string idleTime
) {

	//If this instance of MRECache has an Observer, then any instances that it creates should as well.
	if ( StructKeyExists(Variables.Instance,"Observer") ) {
		Arguments.Observer = Variables.Instance.Observer;
	}

	return CreateObject("component","MRECache").init(ArgumentCollection=Arguments);
}

/*
* I return a timespan from an interval string.
*/
public numeric function convertTimeSpan(required string interval) {
	
	if ( isNumeric(Arguments.interval) ) {
		return Arguments.interval;
	}

	return getTimeSpanFromInterval(Arguments.interval);
}

function getSecondsFromTimeSpan(required numeric timeSpan) {
	var timeObj = ParseDateTime("00:00:00") + timeSpan;
	return DateDiff("s", ParseDateTime("00:00:00"), timeObj);
}

/*
* I return a timespan from an interval string.
*/
public numeric function getTimeSpanFromInterval(required string interval) {
	var result = 0;
	var timespans = "second,minute,hour,day,week,month,quarter,year";
	var dateparts = "s,n,h,d,ww,m,q,yyyy";
	var vals = "#CreateTimeSpan(0,0,0,1)#,#CreateTimeSpan(0,0,1,0)#,#CreateTimeSpan(0,1,0,0)#,1,7,30,90,365";
	var num = 1;
	var timespan = "";
	var value = 0;
	var ordinals = "first,second,third,fourth,fifth,sixth,seventh,eighth,ninth,tenth,eleventh,twelfth";
	var ordinal = "";
	var numbers = "one,two,three,four,five,six,seven,eight,nine,ten,eleven,twelve";
	var number = "";
	var instances = "once,twice";
	var instance = "";
	var thisint = "";
	var sNums = 0;

	if ( ListLen(arguments.interval) GT 1 ) {
		for ( thisint in ListToArray(arguments.interval) ) {
			result += getTimeSpanFromInterval(thisint);
		}
	} else {
		arguments.interval = ReplaceNoCase(arguments.interval,"annually","yearly","ALL");
		arguments.interval = ReReplaceNoCase(arguments.interval,"\b(\d+)(nd|rd|th)\b","\1","ALL");
		sNums = ReFindNoCase("\b\d+\b",arguments.interval,1,true);
		// Figure out number
		if ( ArrayLen(sNums.pos) AND sNums.pos[1] GT 0 ) {
			num = Mid(arguments.interval,sNums.pos[1],sNums.len[1]);
		}
		if ( ListFindNoCase(arguments.interval,"every"," ") ) {
			arguments.interval = ListDeleteAt(arguments.interval,ListFindNoCase(arguments.interval,"every"," ")," ");
		}
		for ( ordinal in ListToArray(ordinals) ) {
			if ( ListFindNoCase(arguments.interval,ordinal," ") ) {
				num = num * ListFindNoCase(ordinals,ordinal);
			}
		}
		for ( number in ListToArray(numbers) ) {
			if ( REFindNoCase("\b#number# times\b",arguments.interval) ) {
				num = num / ListFindNoCase(numbers,number);
			} else if ( ListFindNoCase(arguments.interval,number," ") ) {
				num = num * ListFindNoCase(numbers,number);
			}
		}
		for ( instance in ListToArray(instances) ) {
			if ( ListFindNoCase(arguments.interval,instance," ") ) {
				num = num / ListFindNoCase(instances,instance);
			}
		}
		if ( ListFindNoCase(arguments.interval,"other"," ") ) {
			arguments.interval = ListDeleteAt(arguments.interval,ListFindNoCase(arguments.interval,"other"," ")," ");
			num = num * 2;
		}

		// Figure out timespan
		timespan = ListLast(arguments.interval," ");

		// Ditch ending "s" or "ly"
		if ( Right(timespan,1) EQ "s" ) {
			timespan = Left(timespan,Len(timespan)-1);
		}
		if ( Right(timespan,2) EQ "ly" ) {
			timespan = Left(timespan,Len(timespan)-2);
		}
		if ( timespan EQ "dai" ) {
			timespan = "day";
		}

		if ( ListFindNoCase(timespans,timespan) ) {
			value = ListGetAt(vals,ListFindNoCase(timespans,timespan));
		} else {
			throw(message="#timespan# is not a valid inteval measurement.");
		}

		result = value * num;
	}

	return result;
}

private void function got(required string id) {
	
	start(Arguments.id);

	Variables.meta[Arguments.id]["NumCalls"] += 1;

}

private numeric function getRunTime(required numeric began) {
	return getTickCount() - Arguments.began;
}

private void function logCall (
	required string id,
	required numeric began,
	required string type
) {

	// Notify Observer (if available)
	if ( 
		StructKeyExists(Variables.instance,"Observer")
		AND
		StructKeyExists(Variables.instance["Observer"],"announceEvent")
	) {
		Arguments.args.runTime = getRunTime(Arguments.began);
		try {
			Variables.instance.Observer.announceEvent(EventName="MrECache:run",Args=args);
		} catch (any e) {
		}
		if ( StructKeyExists(args,"type") ) {
			try {
				Variables.instance.Observer.announceEvent(EventName="MrECache:#args.type#",Args=args);
			} catch (any e) {
			}
		}
	}

}

private struct function putargs(
	required string id,
	required value,
	string timeSpan,
	string idleTime
) {

	if ( NOT StructKeyExists(Arguments,"timeSpan") ) {
		if ( StructKeyExists(Variables.instance,"timeSpan") ) {
			Arguments.timeSpan = Variables.instance.timeSpan;
		}
	}

	if ( NOT StructKeyExists(Arguments,"idleTime") ) {
		if ( StructKeyExists(Variables.instance,"idleTime") ) {
			Arguments.idleTime = Variables.instance.idleTime;
		}
	}

	return Arguments;
}

private void function start(required string id) {

	// Make sure we have a key in meta for this id.
	if ( NOT StructKeyExists(Variables.meta,Arguments.id) ) {
		Variables.meta[Arguments.id] = {};
	}

	if (
		NOT (
			StructKeyExists(Variables.meta[Arguments.id],"NumCalls")
			AND
			isSimpleValue(Variables.meta[Arguments.id]["NumCalls"])
			AND
			isNumeric(Variables.meta[Arguments.id]["NumCalls"])
		)
	) {
		Variables.meta[Arguments.id]["NumCalls"] = 0;
	}

}

private void function startGetPut(id) {
	Variables.processing[Arguments.id] = now();
}

</cfscript>
</cfcomponent>
