<cfcomponent display="Mr. Performance" hint="I track the performance of cacheable operations.">
<cfscript>
public function init(
	required DataMgr,
	required Observer,
	boolean autostart="true"
) {

	Variables.instance = Arguments;
	Variables.instance.Timer = CreateObject("component","utils.Timer").init(Arguments.DataMgr,Arguments.Observer);

	Variables.isTracking = false;

	if ( Arguments.autostart ) {
		startTracking();
	}

	return This;
}

/*
* I indicate if Mr Performance is currently tracking.
*/
public boolean function isTracking() {
	return Variables.isTracking;
}

/*
* I log information about running of cacheable code.
*/
public function logRunCacheable(
	required string id,
	required numeric RunTime
) {
	var sArgs = {time_ms=Arguments.RunTime,name=Arguments.id};
	var sComp = 0;

	if ( StructKeyExists(Arguments,"Fun") ) {
		sArgs["Label"] = Arguments.Fun.Metadata.Name;
	}

	if ( StructKeyExists(Arguments,"Component") AND StructKeyExists(Arguments,"MethodName") ) {
		sComp = getMetaData(Arguments.Component);
		if ( StructKeyExists(sComp,"DisplayName") ) {
			sArgs["Label"] = sComp.DisplayName & ": " & Arguments.MethodName;
		} else {
			sArgs["Label"] = sComp.Name & "." & Arguments.MethodName;
		}
	}

	// Variables.instance.Timer.hearMrECache(Arguments.id,Arguments.RunTime);
	Variables.instance.Timer.logTime(Arguments.RunTime,Arguments.id,sArgs["Label"]);

}

/*
* I log information about running of cacheable code.
*/
public function logRunObservable(
	required numeric RunTime,
	required string ListenerName
) {
	var sArgs = {time_ms=Arguments.RunTime,name=Arguments.ListenerName};
	var sComp = 0;

	if ( StructKeyExists(Arguments,"Fun") ) {
		sArgs["Label"] = Arguments.Fun.Metadata.Name;
	}

	if ( StructKeyExists(Arguments,"Component") AND StructKeyExists(Arguments,"MethodName") ) {
		sComp = getMetaData(Arguments.Component);
		if ( StructKeyExists(sComp,"DisplayName") ) {
			sArgs["Label"] = sComp.DisplayName & ": " & Arguments.MethodName;
		} else {
			sArgs["Label"] = sComp.Name & "." & Arguments.MethodName;
		}
	}

	if ( StructKeyExists(Arguments,"Args") AND StructCount(Arguments.Args) ) {
		sArgs.Data = Arguments.Args;
	}

	// Variables.instance.Timer.hearMrECache(Arguments.id,Arguments.RunTime)>--->
	Variables.instance.Timer.logTime(ArgumentCollection=sArgs);

}

/*
* I register a listener with Observer to listen for services being loaded.
*/
public void function startTracking() {
	
	Variables.isTracking = true;
	Variables.instance.Observer.registerListener(
		Listener = This,
		ListenerName = "MrPerformance",
		ListenerMethod = "logRunCacheable",
		EventName = "MrECache:run"
	);
	Variables.instance.Observer.registerListener(
		Listener = This,
		ListenerName = "MrPerformanceObserv",
		ListenerMethod = "logRunObservable",
		EventName = "Observer:announceEvent"
	);

}

/*
* I register a listener with Observer to listen for services being loaded.
*/
public void function stopTracking() {
	
	Variables.isTracking = false;
	Variables.instance.Observer.unregisterListener(
		ListenerName = "MrPerformance",
		ListenerMethod = "logRunCacheable",
		EventName = "MrECache:run"
	);
	Variables.instance.Observer.unregisterListener(
		ListenerName = "MrPerformanceObserv",
		ListenerMethod = "logRunObservable",
		EventName = "Observer:announceEvent"
	);

}
</cfscript>
</cfcomponent>
