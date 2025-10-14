<!--- Created by Steve Bryant 2007-01-31 --->
<cfcomponent displayname="Scheduler" extends="com.sebtools.component">
<cfscript>
public function init(
	required DataMgr,
	ServiceFactory
) {

	initInternal(ArgumentCollection=Arguments);

	Variables.DataMgr.loadXml(getDbXml(),true,true);

	Variables.tasks = {};
	Variables.sComponents = {};
	Variables.sRunningTasks = {};

	// Initialize Date of run from last action if there is one.
	Variables.DateLastRunTasks = getDateOfLastAction();
	if ( NOT isDate(Variables.DateLastRunTasks) ) {
		StructDelete(Variables,"DateLastRunTasks");
	}

	return This;
}

/**
* I remove all tasks from the internal track of running tasks. **Use with Care** - only if you are sure none are running.
*/
public void function clearRunningTasks() {
	Variables.sRunningTasks = {};
}
</cfscript>

<cffunction name="createCFTask" access="public" returntype="void" output="no">
	<cfargument name="URL" type="string" required="yes">
	<cfargument name="Name" type="string" required="yes">
	<cfargument name="interval" type="string" default="1800">
	<cfargument name="runtime" type="date" default="#now()#">

	<cfschedule action="UPDATE" task="#condenseTaskName(arguments.Name)#"  operation="HTTPRequest" url="#arguments.URL#" startdate="#Arguments.runtime#" starttime="12:00 AM" interval="#arguments.interval#">

</cffunction>

<cfscript>
public string function DateAddInterval(
	required string interval,
	string date="#now()#"
) {
	var result = arguments.date;
	var timespans = "millisecond,second,minute,hour,day,week,month,quarter,year";
	var dateparts = "l,s,n,h,d,ww,m,q,yyyy";
	var num = 1;
	var timespan = "";
	var datepart = "";
	var DayOf = "";
	var OrdinationString = "";
	var ordinals = "first,second,third,fourth,fifth,sixth,seventh,eighth,ninth,tenth,eleventh,twelfth";
	var ordinal = "";
	var numbers = "one,two,three,four,five,six,seven,eight,nine,ten,eleven,twelve";
	var number = "";
	var weekdays = "Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday";
	var weekday = "";
	var thisint = "";
	var sNums = 0;
	var isSubtraction = Left(Trim(arguments.interval),1) EQ "-";
	var sub = "";

	if ( NOT isDate(Arguments.date) ) {
		return "";
	}

	if ( isSubtraction ) {
		arguments.interval = Trim(ReplaceNoCase(arguments.interval,"-","","ALL"));
		sub = "-";
	}

	arguments.interval = REReplaceNoCase(arguments.interval,"\s+(and|plus)\b",",","ALL");

	if ( ListLen(arguments.interval) GT 1 ) {
		for ( thisint in ListToArray(arguments.interval) ) {
			result = DateAddInterval("#sub##thisint#",result);
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

		// Day of the month/year
		OrdinationString = REReplaceNoCase(arguments.interval,"\bsecond$","");// Making sure "every [other,ordinal] second" isn't considered as an ordinal interval
		for ( ordinal in ListToArray(ordinals) ) {
			if ( ReFindNoCase("#ordinal#\s+of\s+",OrdinationString) ) {
				DayOf = ListFindNoCase(ordinals,ordinal);
				OrdinationString = ReReplaceNoCase(OrdinationString,"#ordinal#\s+of\s+","");
			}
		}

		// Regular ordination
		for ( ordinal in ListToArray(ordinals) ) {
			if ( ListFindNoCase(OrdinationString,ordinal," ") ) {
				num = num * ListFindNoCase(ordinals,ordinal);
			}
		}
		for ( number in ListToArray(numbers) ) {
			if ( ListFindNoCase(arguments.interval,number," ") ) {
				num = num * ListFindNoCase(numbers,number);
			}
		}
		if ( ListFindNoCase(arguments.interval,"other"," ") ) {
			arguments.interval = ListDeleteAt(arguments.interval,ListFindNoCase(arguments.interval,"other"," ")," ");
			num = num * 2;
		}
		// Check if day of week is specified
		for ( weekday in ListToArray(weekdays) ) {
			// Make sure user could pluralize the weekday and this would still work.
			arguments.interval = ReplaceNoCase(arguments.interval,"#weekday#s",weekday,"ALL");
			if ( ListFindNoCase(arguments.interval,weekday," ") ) {
				// Make sure the date given is on the day of week specified (subtract days as needed)
				arguments.date = DateAdd("d",- Abs( 7 - ListFindNoCase(weekdays,weekday) + DayOfWeek(arguments.date) ) MOD 7,arguments.date);
				arguments.interval = ListDeleteAt(arguments.interval,ListFindNoCase(arguments.interval,weekday," ")," ");
				// Make sure we are adding weeks
				arguments.interval = ListAppend(arguments.interval,"week"," ");
			}
		}

		// Figure out timespan
		if ( IsNumeric(arguments.interval) ) {
            timespan = "second";
        } else {
            timespan = ListLast(arguments.interval," ");
        }

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
			datepart = ListGetAt(dateparts,ListFindNoCase(timespans,timespan));
		} else {
			throw(message="#timespan# is not a valid interval measurement.");
		}

		result = DateAdd(datepart,"#sub##num#",arguments.date);

		if ( Val(DayOf) ) {
			result = CreateDateTime(Year(result),Month(result),DayOf,Hour(result),Minute(result),Second(result));
		}
	}

	return result;
}
</cfscript>

<cffunction name="failsafe" access="public" returntype="void" output="no">
	<cfargument name="runtime" type="date" default="#now()#">

	<!--- So long as runTasks is called every three hours, then all is well. --->
	<cfif NOT ( StructKeyExists(Variables,"DateLastRunTasks") AND DateDiff("h",Variables.DateLastRunTasks,Arguments.runtime) LTE 3 )>
		<!--- Otherwise, raise the alerm and call the method to keep things running. --->
		<cf_scaledAlert><cfoutput>
		Scheduler (#CGI.SERVER_NAME#) runTasks hasn't run since <cfif isDate(Variables.DateLastRunTasks)>#DateFormat(Variables.DateLastRunTasks,'mmm d yyy')# at #TimeFormat(Variables.DateLastRunTasks,'hh:mm:ss tt')#<cfelse>it was loaded</cfif>.
		Running now...
		</cfoutput></cf_scaledAlert>
		<cfset runTasks(runtime=Arguments.runtime)>
	</cfif>

</cffunction>

<cffunction name="getActionRecords" access="public" returntype="query" output="no">

	<cfif StructKeyExists(Arguments,"TaskName")>
		<cfset Arguments.TaskName = condenseTaskName(arguments.TaskName)>
	</cfif>

	<cfreturn variables.DataMgr.getRecords("schActions",arguments)>
</cffunction>

<cffunction name="getDateOfLastAction" access="public" returntype="string" output="no">

	<cfset var qLastAction = 0>

	<cfquery name="qLastAction" datasource="#variables.datasource#">
	SELECT	Max(DateRun) AS DateLastRun
	FROM	schActions
	</cfquery>

	<cfreturn qLastAction.DateLastRun>
</cffunction>

<cfscript>
public query function getTaskRecords() {

	if ( StructKeyExists(Arguments,"TaskName") ) {
		Arguments.TaskName = condenseTaskName(arguments.TaskName);
	}

	return variables.DataMgr.getRecords("schTasks",arguments);
}

public struct function getTasks() {

	loadAbandonedTasks();

	return variables.tasks;
}

public struct function getTasksTruncated() {
	var sResult = {};
	var key = "";
	var key2 = "";

	loadAbandonedTasks();

	for ( key in variables.tasks ) {
		sResult[key] = {};
		for ( key2 in variables.tasks[key] ) {
			if ( isSimpleValue(variables.tasks[key][key2]) ) {
				sResult[key][key2] = variables.tasks[key][key2];
			}
		}
	}

	return sResult;
}

public void function loadAbandonedTasks(date runtime="#now()#") {
	// var qTasks = getTaskRecords(interval="once");
	var qTasks = getTaskRecords();
	var sSavedArgs = 0;
	var aErrorMessages = [];
	var ExpandedTaskName = "";
	var sTask = 0;

	for ( sTask in qTasks ) {
		ExpandedTaskName = expandTaskName(Name=sTask.Name,jsonArgs=sTask.jsonArgs,TaskID=sTask.TaskID);
		if (
				NOT StructKeyExists(variables.tasks,ExpandedTaskName)
			AND	sTask.dateCreated GTE DateAdd("d",-1,Arguments.runtime)
		) {
			if ( StructKeyExists(Variables,"ServiceFactory") AND NOT StructKeyExists(variables.sComponents,sTask.ComponentPath) ) {
				try {
					setComponent(sTask.ComponentPath,Variables.ServiceFactory.getServiceByPath(sTask.ComponentPath));
				} catch ( any e ) {

				}
			}
			if ( NOT StructKeyExists(variables.sComponents,sTask.ComponentPath) ) {
				removeTask(sTask.Name);
				ArrayAppend(aErrorMessages,"The task #sTask.Name# has been deleted because the component specified by this task's component path (#sTask.ComponentPath#) is not available to Scheduler.");
			} else {
				variables.tasks[ExpandedTaskName] = {};
				variables.tasks[ExpandedTaskName]["ComponentPath"] = sTask.ComponentPath;
				variables.tasks[ExpandedTaskName]["Component"] = variables.sComponents[sTask.ComponentPath];
				variables.tasks[ExpandedTaskName]["MethodName"] = sTask.MethodName;
				variables.tasks[ExpandedTaskName]["interval"] = "once";
				variables.tasks[ExpandedTaskName]["Hours"] = sTask.Hours;
				variables.tasks[ExpandedTaskName]["jsonArgs"] = sTask.jsonArgs;
				variables.tasks[ExpandedTaskName]["Priority"] = sTask.Priority;
				variables.tasks[ExpandedTaskName]["name"] = ExpandedTaskName;

				if ( sTask.jsonArgs CONTAINS "[[Complex Value Removed by Scheduler]]" ) {
					removeTask(sTask.Name);
					ArrayAppend(aErrorMessages,"Unable to retrieve complex arguments for #sTask.MethodName# method in the #sTask.Name# task. The task has been deleted.");
				} else {
					// Load arguments from the json string in db and if not empty
					sSavedArgs = DeserializeJSON( sTask.jsonArgs );
					if ( StructCount( sSavedArgs ) GT 0 ) {
						variables.tasks[ExpandedTaskName]["Args"] = sSavedArgs;
					}
				}
			}
		}
	}

	// Now we can throw any errors since successful tasks have now been reloaded into variables scope
	if ( ArrayLen(aErrorMessages) ) {
		if ( ArrayLen(aErrorMessages) EQ 1 ) {
			throw(message="#aErrorMessages[1]#",type="Scheduler");
		} else {
			throw(message="The following errors occurred when trying to load abandoned tasks.",detail="#ArrayToList(aErrorMessages,';')#",type="Scheduler");
		}
	}

}

public void function removeTask(required string Name) {
	var qTask = getTaskNameRecord(Name=Arguments.Name,fieldlist="TaskID");
	var data = {};

	data["TaskID"] = qTask.TaskID;

	StructDelete(variables.tasks, expandTaskName(arguments.Name,qTask.jsonargs,qTask.TaskID));
	variables.DataMgr.deleteRecord("schTasks",data);

}

private string function serializeArgsJSON(required args) {
	var serializedJSON = "";
	var argCount = 1;
	var quotedKey = "";
	var quotedValue = "";
	var keyValuePair = "";
	var key = "";

	for ( key in arguments.args ) {
		quotedKey = ListQualify( key ,'"',",","CHAR");
		if ( IsSimpleValue( args[ key ] ) ) {
			quotedValue = ListQualify( args[ key ] ,'"',",","CHAR");
		} else {
			quotedValue = '"[[Complex Value Removed by Scheduler]]"';
		}
		keyValuePair = quotedKey & ":" & quotedValue;
		if ( argCount NEQ 1 ) {
			serializedJSON &= "," & keyValuePair;
		} else {
			serializedJSON &= keyValuePair;
		}
		argCount = argCount + 1;
	}

	return "{" & serializedJSON & "}";
}

/**
* @ComponentPath The path to your component (example com.sebtools.NoticeMgr).
*/
public void function setComponent(
	required string ComponentPath,
	required Component
) {

	Variables.sComponents[arguments.ComponentPath] = Arguments.Component;

}

/**
* @ComponentPath The path to your component (example com.sebtools.NoticeMgr).
* @hours The hours in which the task can be run.
* @weekdays The week days on which the task can be run.
*/
public numeric function setTask(
	required string Name,
	required string ComponentPath,
	required Component,
	required string MethodName,
	required string interval,
	struct args,
	string hours,
	string weekdays,
	numeric Priority
) {
	var qTask = 0;
	var ExpandedTaskName = "";

	if ( Len(Arguments.ComponentPath) GT 50 ) {
		Arguments.ComponentPath = Right(Arguments.ComponentPath,50);
	}

	if ( StructKeyExists(arguments,"hours") ) {
		arguments.hours = expandHoursList(arguments.hours);
	}

	if ( StructKeyExists( arguments, "args" ) ) {
		arguments.jsonArgs = serializeArgsJSON( arguments.args );
	} else {
		arguments.jsonArgs = "{}"; // compliant empty json string
	}

	qTask = getTaskNameRecord(ArgumentCollection=arguments);
	if ( qTask.RecordCount ) {
		arguments.TaskID = qTask.TaskID;
	} else {
		arguments.TaskID = variables.DataMgr.saveRecord("schTasks",arguments);
	}

	ExpandedTaskName = expandTaskName(arguments.Name,arguments.jsonArgs,arguments.TaskID);

	// Make sure task of this name doesn't exist for another component.
	if ( StructKeyExists(variables.tasks,ExpandedTaskName) ) {
		if (
				( variables.tasks[ExpandedTaskName].ComponentPath NEQ arguments.ComponentPath )
			OR	( variables.tasks[ExpandedTaskName].MethodName NEQ arguments.MethodName )
		) {
			throw(message="A task using this name already exists for another component method.",type="Scheduler",errorcode="NameExists");
		}
	}

	/*
	Set the component even if we have it to ensure that we are always using the newest version of a component.
	The component could have gotten loaded while loading missing tasks, using an old copy.
	*/
	if ( isObject(arguments.Component) ) {
		setComponent(arguments.ComponentPath,arguments.Component);
	}

	variables.tasks[ExpandedTaskName] = arguments;

	return arguments.TaskID;
}

public function rerun(required string Name) {
	var qTask = getTaskNameRecord(arguments.Name);
	var sTaskUpdate = {};

	sTaskUpdate["TaskID"] = qTask.TaskID;
	sTaskUpdate["rerun"] = 1;
	variables.DataMgr.updateRecord("schTasks",sTaskUpdate);

}

public function runTask(
	required string Name,
	boolean remove="false",
	date runtime="#now()#"
) {
	var sTask = {};
	var qTask = getTaskNameRecord(arguments.Name);
	var ExpandedTaskName = expandTaskName(arguments.Name);
	var sTaskUpdate = {};
	var sAction = {};
	var key = "";

	var TimeMarkBegin = 0;
	var TimeMarkEnd = 0;

	if ( qTask.RecordCount ) {
		if ( StructKeyExists(variables.sRunningTasks,ExpandedTaskName) ) {
			return false;
		}

		variables.sRunningTasks[ExpandedTaskName] = Arguments.runtime;

		sTaskUpdate["TaskID"] = qTask.TaskID;
		sTaskUpdate["rerun"] = 0;
		variables.DataMgr.updateRecord("schTasks",sTaskUpdate);

		sAction["TaskID"] = qTask.TaskID;
		sAction["ActionID"] = variables.DataMgr.insertRecord("schActions",sAction,"insert");

		for ( key in variables.tasks[ExpandedTaskName] ) {
			sTask[key] = variables.tasks[ExpandedTaskName][key];
		}

		if ( arguments.remove ) {
			removeTask(arguments.Name);
		}

		TimeMarkBegin = getTickCount();
		sAction.DateRun = Arguments.runtime;
		sAction.DateRunStart = Arguments.runtime;
		try {
			if ( StructKeyExists(sTask,"args") ) {
				sAction.ReturnVar = invoke(sTask.Component,sTask.MethodName,sTask.args);
			} else {
				sAction.ReturnVar = invoke(sTask.Component,sTask.MethodName);
			}
			TimeMarkEnd = getTickCount();
			sAction.Success = true;
		} catch ( any e ) {
			StructDelete(variables.sRunningTasks,ExpandedTaskName);
			sAction.Success = false;
			TimeMarkEnd = getTickCount();
			sAction.Seconds = GetSecondsDiff(TimeMarkBegin,TimeMarkEnd);
			if ( StructKeyExists(e,"Message") ) {
				sAction.ErrorMessage = e.Message;
			} else {
				sAction.ErrorMessage = "";
			}
			if ( StructKeyExists(e,"Detail") ) {
				sAction.ErrorDetail = e.Detail;
			} else {
				sAction.ErrorDetail = "";
			}
			sAction.DateRunEnd = Arguments.runtime;
			sAction = variables.DataMgr.truncate("schActions",sAction);
			variables.DataMgr.updateRecord("schActions",sAction);
			rethrow;
		}

		sAction.Seconds = GetSecondsDiff(TimeMarkBegin,TimeMarkEnd);

		sAction.DateRunEnd = Arguments.runtime;
		sAction = variables.DataMgr.truncate("schActions",sAction);
		variables.DataMgr.updateRecord("schActions",sAction);

		StructDelete(variables.sRunningTasks,ExpandedTaskName);
	}

}

public void function runTasks(boolean force="false",date runtime="#now()#") {
	var aTasks = 0;
	var aPriorities = 0;
	var ii = 0;
	var pp = 0;
	var priority = 0;
	var sRunTask = 0;

	// Don't do this more than once every 3 minutes
	if (
		Arguments.force
		OR
		NOT (
			StructKeyExists(Variables,"DateLastRunTasks")
			AND
			DateDiff("n",Variables.DateLastRunTasks,Arguments.runtime) LTE 3
		)
	) {

		Variables.DateLastRunTasks = Arguments.runtime;

		aTasks = getCurrentTasks(Arguments.runtime);
		aPriorities = getPriorities();

		for ( pp=1; pp LTE ArrayLen(aPriorities); pp++ ) {
			priority = aPriorities[pp];	
			for ( ii=1; ii LTE ArrayLen(aTasks); ii++ ) {
				if (
					StructKeyExists(aTasks[ii],"name")
					AND
					NOT StructKeyExists(variables.sRunningTasks,aTasks[ii].name)
					AND
					( Val(aTasks[ii].Priority) EQ Val(priority) )
				) {
					sRunTask = {
						Name=ExpandTaskName(aTasks[ii].name,aTasks[ii].jsonArgs),
						runtime=Arguments.runtime
					};
					if ( aTasks[ii].interval EQ "once" ) {
						sRunTask["remove"] = true;
					}
					runTask(ArgumentCollection=sRunTask);
				}
			}
		}


	}

}

public struct function getComponentDefs() {

	return variables.sComponents;
}

public array function getCurrentTasks(date runtime="#now()#") {
	var aResults = [];
	var task = "";

	loadAbandonedTasks();

	// Look at each task
	for ( task in Variables.tasks ) {
		if ( isRunnableTask(ExpandTaskName(task,variables.tasks[task].jsonargs),arguments.runtime) ) {
			ArrayAppend(aResults,variables.tasks[task]);
		}
	}

	return aResults;
}

public struct function getIncompleteTasks() {
	var sResult = {};

	StructAppend(sResult,Variables.Tasks);

	StructAppend(sResult,Variables.sRunningTasks);

	return sResult;
}

public array function getPriorities() {
	var task = "";
	var sPriorities = {};

	for ( task in Variables.tasks ) {
		if ( StructKeyExists(Variables.tasks[task],"Priority") ) {
			sPriorities[Val(Variables.tasks[task].Priority)] = Variables.tasks[task].Priority;
		}
	}

	return ListToArray(ListSort(StructKeyList(sPriorities),"numeric","desc"));;
}

public struct function getRunningTasks() {
	return StructCopy(Variables.sRunningTasks);
}

/**
* I tell whether there are tasks currently running.
*/
public boolean function hasRunningTasks() {
	return BooleanFormat(StructCount(Variables.sRunningTasks) GT 0);
}

/**
* I return the date since which a task would have been run to be within the current interval defined for it.
*/
public void function getIntervalFromDate(
	required string Name,
	date runtime="#now()#"
) {
	var sIntervals = getIntervals();
	var adjustedtime = DateAdd("n",10,arguments.runtime);// Tasks run every 15 minutes at most and we need a margin of error for date checks.
	var result = Arguments.runtime;
	var task = expandTaskName(Arguments.Name);

	// If the interval is numeric, check by the number of seconds
	if ( isNumeric(variables.tasks[task].interval) AND variables.tasks[task].interval GT 0 ) {
		adjustedtime = DateAdd("s",Int(variables.tasks[task].interval/10),arguments.runtime);
		result = DateAdd("s", -Int(variables.tasks[task].interval), adjustedtime);
	// If a key exists for the interval, use that
	} else if ( StructKeyExists(sIntervals,variables.tasks[task].interval) ) {
		// If the key value is numeric, check by the number of seconds
		if ( sIntervals[variables.tasks[task].interval] GT 0 ) {
			adjustedtime = DateAdd("s",Int(sIntervals[variables.tasks[task].interval]/10),arguments.runtime);
			result = DateAdd("s", -Int(sIntervals[variables.tasks[task].interval]), adjustedtime);
		// If the key value is "daily", check by one day
		} else if ( variables.tasks[task].interval EQ "daily" ) {
			adjustedtime = DateAdd("n",55,arguments.runtime);
			result = DateAdd("d", -1, adjustedtime);
		// If the key value is "weekly", check by one week
		} else if ( variables.tasks[task].interval EQ "weekly" ) {
			adjustedtime = DateAdd("h",12,arguments.runtime);
			result = DateAdd("ww", -1, adjustedtime);
		// If the key value is "monthly", check by one month
		} else if ( variables.tasks[task].interval EQ "monthly" ) {
			adjustedtime = DateAdd("h",12,arguments.runtime);
			result = DateAdd("m", -1, adjustedtime);
		}
	} else {
		result = DateAdd("s", -3600, adjustedtime);
	}

	return result;
}

public query function getLastRunAction(
	required numeric TaskID,
	string fields="DateRun"
) {

	return Variables.DataMgr.getRecords(tablename="schActions",data={TaskID=Arguments.TaskID},fieldlist=Arguments.fields,orderby='ActionID DESC',maxrows=1);
}

public any function getLastRunDate(
	required numeric TaskID
) {
	var qLastRun = getLastRunAction(Arguments.TaskID);

	if ( isDate(qLastRun.DateRun) ) {
		return qLastRun.DateRun;
	}
}

/**
* I check to see if the given task has already run within the period of the interval defined for it. 
*/
public boolean function hasRunWithinInterval(
	required string interval,
	required date lastrun,
	date runtime,
	string weekdays="",
	string hours=""
) {
	var NextRunDate = DateAddInterval(Arguments.interval,Arguments.lastrun);
	var EffectiveIntervalHours = DateDiff("h",Arguments.lastrun,NextRunDate);
	var BlockLength = 0;
	var result = false;

	//Atttempt to bump back to original weekday
	//Only needed if now is in the timeslot, but it last ran outside of it
	if (
		Len(Arguments.weekdays)
		AND
		ListFindNoCase(Arguments.weekdays,DayOfWeek(Arguments.runtime))
		AND
		NOT ListFindNoCase(Arguments.weekdays,DayOfWeek(Arguments.lastrun))
	) {
		BlockLength = BlockLengthDays(Arguments.weekdays,Arguments.runtime);
		//If effective interval is greater than the amount of time in the last bloack, then back up the NextRunDate a bit
		if (
			BlockLength GT 0
			AND
			( EffectiveIntervalHours GT ( BlockLength * 24 ) )
		) {
			NextRunDate = DateAdd("d", -BlockLength, NextRunDate);
		}
	}

	//Atttempt to bump back to original hour
	//Only needed if now is in the timeslot, but it last ran outside of it
	if (
		Len(Arguments.hours)
		AND
		ListFindNoCase(Arguments.hours,Hour(Arguments.runtime))
		AND
		NOT ListFindNoCase(Arguments.hours,Hour(Arguments.lastrun))
	) {
		BlockLength = BlockLengthHours(Arguments.hours,Arguments.runtime);
		//If effective interval is greater than the amount of time in the last bloack, then back up the NextRunDate a bit
		if (
			BlockLength GT 0
			AND
			( EffectiveIntervalHours GT BlockLength )
		) {
			NextRunDate = DateAdd("h", -BlockLength, NextRunDate);
		}
	}

	return ( NextRunDate GT Arguments.runtime );
}

/**
* I check to see if the given task has already run within the period of the interval defined for it.
*/
public boolean function hasTaskRunWithinInterval(
	required string Name,
	date runtime="#now()#"
	date lastrun
) {
	var qTask = getTaskNameRecord(Arguments.Name);

	if ( Len(variables.datasource) AND NOT StructKeyExists(Arguments,"lastrun") ) {
		// See if the task has already been run within its interval
		Arguments.lastrun = getLastRunDate(qTask.TaskID);
	}

	if ( StructKeyExists(Arguments,"lastrun") ) {
		return hasRunWithinInterval(
			interval=qTask.interval,
			lastrun=Arguments.lastrun,
			runtime=Arguments.runtime,
			weekdays=qTask.weekdays,
			hours=qTask.hours
		);
	}

	return false;
}

public boolean function isRunnableTask(
	required string Name,
	date runtime="#now()#"
) {
	var result = false;
	var loc = {};

	loc.qTask = getTaskNameRecord(Name=Arguments.Name,fieldlist="rerun,interval,weekdays,hours");
	loc.task = expandTaskName(Arguments.Name);
	loc.lastrun = getLastRunDate(loc.qTask.TaskID);
	
	if ( loc.qTask.rerun IS true ) {
		result = true;
	} else if ( NOT hasTaskRunWithinInterval(Arguments.Name,Arguments.runtime) ) {
		
		result = isInTimeSlot(
			weekdays=loc.qTask.weekdays,
			hours=loc.qTask.hours,
			runtime=Arguments.runtime
		);

		if ( StructKeyExists(loc,"lastrun") AND NOT result ) {
			result = isInTimeSlotAdjusted(
				interval=loc.qTask.interval,
				lastrun=loc.lastrun,
				weekdays=loc.qTask.weekdays,
				hours=loc.qTask.hours,
				runtime=Arguments.runtime
			);
		}

	}

	return result;
}

public boolean function isInTimeSlot(
	string weekdays="",
	string hours="",
	date runtime="#now()#"
) {
	var result = true;

	// If weekdays are specified, make sure current day is in that list of weekdays
	if (
		Len(Arguments.weekdays)
		AND
		NOT ListFindNoCase(Arguments.weekdays,DayofWeekAsString(DayOfWeek(Arguments.runtime)))
	) {
		result = false;
	}

	// If hours are specified, make sure current time is in that list of hours
	if (
		Len(Arguments.hours)
		AND
		NOT ListFindNoCase(Arguments.hours,Hour(arguments.runtime))
	) {
		result = false;
	}

	return result;
}

private boolean function isInTimeSlotAdjusted(
	required string interval,
	required date lastrun,
	string weekdays="",
	string hours=""
) {
	var NextRunDate = DateAddInterval(Arguments.interval,Arguments.lastrun);
	var EffectiveIntervalHours = DateDiff("h",Arguments.lastrun,NextRunDate);
	var BlockLength = 0;
	var result = false;
	
	//If Interval has a weekdays in it,but runtime isn't in hours, then see if we need to back up the next run time a little.
	if (
		Len(Arguments.weekdays)
		AND
		NOT ListFindNoCase(Arguments.weekdays,DayOfWeek(Arguments.runtime))
	) {
		BlockLength = BlockLengthDays(Arguments.weekdays,Arguments.lastrun);
		//If effective interval is greater than the amount of time in the last bloack, then back up the runtim a bit
		if (
			BlockLength GT 0
			AND
			( EffectiveIntervalHours GT ( BlockLength * 24 ) )
		) {
			Arguments.runtime = DateAdd("d", -BlockLength, Arguments.runtime);
		}
	}

	//If Interval has a hours in it,but runtime isn't in hours, then see if we need to back up the next run time a little.
	if (
		Len(Arguments.hours)
		AND
		NOT ListFindNoCase(Arguments.hours,Hour(Arguments.runtime))
	) {
		BlockLength = BlockLengthHours(Arguments.hours,Arguments.lastrun);
		//If effective interval is greater than the amount of time in the last bloack, then back up the runtim a bit
		if (
			BlockLength GT 0
			AND
			( EffectiveIntervalHours GT BlockLength )
		) {
			Arguments.runtime = DateAdd("h", -BlockLength, Arguments.runtime);
		}
	}

	return isInTimeSlot(Arguments.weekdays,Arguments.hours,Arguments.runtime);
}

/**
* @ComponentPath The path to your component (example com.sebtools.NoticeMgr).
*/
public void function notifyComponent(
	required string ComponentPath,
	required Component
) {

	Variables.sComponents[arguments.ComponentPath] = Arguments.Component;

}

private numeric function ArrayGetAtMod(
	required array array,
	required numeric position
) {
	Arguments.position = Arguments.position MOD ArrayLen(array);

	if ( Arguments.position EQ 0 ) {
		Arguments.position = ArrayLen(array)
	}

	return array[Arguments.position];
}

/**
* I get the number of days - in a row - that are part of the set that include the runtime day.
*/
private numeric function BlockLengthDays(
	required string weekdays,
	required date runtime
) {

	return countContiguousIntegers(
		list=DayOfWeekNumericList(Arguments.weekdays),
		target=DayOfWeek(Arguments.runtime),
		modulus=7,
		min=1
	);
}

/**
* I get the number of hours - in a row - that are part of the set that include the runtime hour.
*/
private numeric function BlockLengthHours(
	required string hours,
	required date runtime
) {
	return countContiguousIntegers(
		list=Arguments.hours,
		target=Hour(Arguments.runtime),
		modulus=23,
		min=0
	);
}

/**
* I return the TaskName in its condensed form, that is just the task name itself.
*/
private string function condenseTaskName(required string Name) {

	// SEB: This is the same as ListFirst(Arguments.Name,":") except that it allows for TaskNames that contain ":".
	return ReReplaceNoCase(Arguments.Name,":\d+$","");
}

/**
* I count the contiguous integers including and surrounding the target number in the given list
*/
private numeric function countContiguousIntegers(
	required string list,
	required string target,
	numeric modulus="0",
	numeric min="1"
) {
	var contiguousCount = 0;
	// Convert the comma-separated list to an array
	var aIntegers = ListToArray(ListRemoveDuplicates(Arguments.list));
	var targetIndex = 0;
	var currentIndex = 0;
	var aDirections = ["left","right"];
	var direction = "";
	var sFilterArgs = {array=aIntegers,minvalue=Arguments.min};

	if ( StructKeyHasVal(Arguments,"modulus") ) {
		sFilterArgs["maxvalue"] = Arguments.modulus;
	}
	//writeDump(aIntegers);
	aIntegers = ArrayFilterNumbersRange(ArgumentCollection=sFilterArgs);

	if ( NOT ArrayLen(aIntegers) ) {
		return 0;
	}

	if (
		( Arguments.target LT Arguments.min )
		OR
		(
			Arguments.modulus GT 0
			AND
			Arguments.target GT Arguments.modulus
		)
	) {
		return 0;
	}

	// Sort the array for easier comparison
	ArraySort(aIntegers,"numeric");

	// Find the index of the target number in the sorted array
	targetIndex = ArrayFind(aIntegers, target);

	//Only do work if the target is found
	if ( targetIndex GT 0 ) {

		//Remove numbers outside of designated range.
		if ( Arguments.modulus GT 0 ) {

		}

		// Initialize counters
		contiguousCount = -1;//Below will find target number twice, so we offset by one to make up for the duplication.

		for ( direction in aDirections ) {
			
			nextIndex = targetIndex;

			do {
				currentIndex = nextIndex;
				nextIndex = ((direction EQ "left") ? (currentIndex-1) : (currentIndex+1))
				contiguousCount++;
				if ( nextIndex EQ 0 ) {
					nextIndex = ArrayLen(aIntegers);
				}
				if ( nextIndex GT ArrayLen(aIntegers) ) {
					nextIndex = 1;
				}
			/*
				Loop if...
				-Count can't exceed number of items
				-Loop when modulues is used and loop runs from one to modulus and we are at the ends
			*/
			} while (
				contiguousCount LTE ArrayLen(aIntegers)
				AND
				(
					ArrayGetAtMod(aIntegers,Max(currentIndex,nextIndex)) - ArrayGetAtMod(aIntegers,Min(currentIndex,nextIndex)) EQ 1
					OR
					(
						Arguments.modulus GT 0
						AND
						aIntegers[1] EQ Arguments.min
						AND
						aIntegers[ArrayLen(aIntegers)] EQ Arguments.modulus
						AND
						ArrayGetAtMod(aIntegers,Min(currentIndex,nextIndex)) EQ Arguments.min
						AND
						ArrayGetAtMod(aIntegers,Max(currentIndex,nextIndex)) EQ Arguments.modulus
					)
				)
			)
		}

		contiguousCount = Min(contiguousCount,ArrayLen(aIntegers));

	}

    return contiguousCount;
}

/**
* The reverse of DayOfWeekAsString
*/
private numeric function DayofWeekFromString(required string weekday) {
	var aNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
	
	return ArrayFindNoCase(aNames, weekday);
}

private string function DayOfWeekNumericList(required string weekdays) {
	var result = "";
	var weekday = "";
	var dayval = 0;

	for ( weekday in ListToArray(Arguments.weekdays) ) {
		dayval = DayofWeekFromString(Trim(weekday));
		if ( dayval ) {
			result = ListAppend(result,dayval);
		}
	}

	result = ListSort(result,"numeric");

	return result;
}

/**
* I return the TaskName in its expanded form - including the TaskID.
*/
private string function expandTaskName(
	required string Name,
	string jsonArgs,
	string TaskID
) {
	var result = Arguments.Name;
	var qTask = 0;
	var sRecord = 0;

	// Only take action if the name doesn't already match the expanded form
	if ( NOT isExpandedForm(Arguments.Name) ) {
		if ( NOT StructKeyExists(Arguments,"TaskID") ) {
			sRecord = {};
			sRecord["Name"] = Arguments.Name;
			sRecord["fieldlist"] = "TaskID";
			if ( StructKeyExists(Arguments,"jsonArgs") ) {
				sRecord["jsonArgs"] = Arguments.jsonArgs;
			}
			qTask = getTaskNameRecord(ArgumentCollection=sRecord);
			if ( qTask.RecordCount EQ 1 ) {
				Arguments.TaskID = qTask.TaskID;
				/*
				if ( NOT StructKeyExists(variables.tasks,"#Arguments.Name#:#qTask.TaskID#") ) {
					result = "#Arguments.Name#:#qTask.TaskID#";
				} else {
					throw(message="Unable to uniquely identify the task #Arguments.Name#.",type="Scheduler",errorcode="NoUniqueTaskFound");
				}
				*/
			} else {
				throw(message="The task record for #Arguments.Name# was not found.",type="Scheduler",errorcode="NoTaskFound");
			}
		}
		result = "#Arguments.Name#:#Arguments.TaskID#";
	}

	return result;
}

/**
* I return a structure of values from a TaskName.
*/
private struct function splitTaskName(required string Name) {
	var sResult = {};

	if ( isExpandedForm(Arguments.Name) ) {
		sResult["Name"] = condenseTaskName(Arguments.Name);
		sResult["TaskID"] = ListLast(Arguments.Name,":");
	} else {
		sResult["Name"] = Arguments.Name;
	}

	return sResult;
}

/**
* I determine if the given TaskName is in expanded form.
*/
private boolean function isExpandedForm(required string Name) {
	var result = false;

	if ( ReFindNoCase(":\d+$",Arguments.Name) ) {
		result = true;
	}

	return result;
}

private struct function getIntervals() {
	var sResult = {};

	sResult["once"] = 0;
	sResult["hourly"] = 3600;
	sResult["daily"] = 86400;
	sResult["daily"] = 0;
	sResult["weekly"] = 604800;
	sResult["monthly"] = 0;

	return sResult;
}

private numeric function GetSecondsDiff(
	required numeric begin,
	required numeric end
) {
	var result = 0;

	if ( arguments.end GTE arguments.begin ) {
		result = Int( ( arguments.end - arguments.begin ) / 1000 );
	}

	return result;
}

private query function getTaskNameRecord(required string Name) {

	return variables.DataMgr.getRecords("schTasks",splitTaskName(Arguments.Name));
}

public string function expandHoursList(required string Hours) {
	var hourset = 0;
	var hour = 0;
	var result = "";
	var hour_from = 0;
	var hour_to = 0;

	if ( ListLen(arguments.hours,"-") GT 1 ) {
		for ( hourset in ListToArray(arguments.hours) ) {
			if ( ListLen(hourset,"-") GT 1 ) {
				hour_from  = Val(ListFirst(hourset,"-")) MOD 24;
				hour_to  = Val(ListLast(hourset,"-")) MOD 24;
				if ( hour_from GT hour_to ) {
					for ( hour=hour_from; hour LTE 23; hour++ ) {
						result = ListAppend(result,hour);
					}
					for ( hour=0; hour LTE hour_to; hour++ ) {
						result = ListAppend(result,hour);
					}
				} else {
					for ( hour=hour_from; hour LTE hour_to; hour++ ) {
						result = ListAppend(result,hour);
					}
				}
			} else {
				result = ListAppend(result,Val(hourset));
			}
		}
	} else {
		result = arguments.hours;
	}

	return result;
}

/**
 * Function to remove numbers from a list that are outside of a given range.
 * @param listString - The list of numbers as a string.
 * @param minValue - The minimum value of the range.
 * @param maxValue - The maximum value of the range.
 * @return A filtered list of numbers within the specified range.
 */
private string function ListFilterNumbersRange(
	required string list,
	numeric minValue,
	numeric maxValue
) {
	// Convert the list to an array
	Arguments.array = ListToArray(list);

	return ArrayToList(ArrayFilterNumbersRange(ArgumentCollection=Arguments));
}

private array function ArrayFilterNumbersRange(
	required array array,
	numeric minValue,
	numeric maxValue
) {
    // Convert the list to an array
    // Initialize an empty array to hold the filtered numbers
    var aResults = [];
	var currentNumber = 0;
    
    // Loop through the array to filter out numbers outside of the range
    for ( currentNumber in Arguments.array ) {
        
        // Check if the current number is within the range
        if (
			NOT (
				StructKeyExists(Arguments,"minValue")
				AND
				Arguments.minValue GT currentNumber
			)
			AND
			NOT (
				StructKeyExists(Arguments,"maxValue")
				AND
				Arguments.maxValue LT currentNumber
			)
		) {
			ArrayAppend(aResults, currentNumber);
		}
    }
    
    return aResults;
}
</cfscript>

<cffunction name="getDbXml" access="private" returntype="string" output="no" hint="I return the XML for the tables needed for Searcher to work.">

	<cfset var result = "">

	<cfsavecontent variable="result">
	<tables>
		<table name="schTasks">
			<field ColumnName="TaskID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="Name" CF_DataType="CF_SQL_VARCHAR" Length="50" />
			<field ColumnName="ComponentPath" CF_DataType="CF_SQL_VARCHAR" Length="50" />
			<field ColumnName="MethodName" CF_DataType="CF_SQL_VARCHAR" Length="50" />
			<field ColumnName="interval" CF_DataType="CF_SQL_VARCHAR" Length="100" />
			<field ColumnName="weekdays" CF_DataType="CF_SQL_VARCHAR" Length="60" />
			<field ColumnName="hours" CF_DataType="CF_SQL_VARCHAR" Length="60" />
			<field ColumnName="dateCreated" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
			<field ColumnName="dateDeleted" CF_DataType="CF_SQL_DATE" Special="DeletionMark" />
			<field ColumnName="rerun" CF_DataType="CF_SQL_BIT" Default="0" />
			<field ColumnName="AvgSeconds">
				<relation
					type="avg"
					table="schActions"
					field="Seconds"
					join-field="TaskID"
				/>
			</field>
			<field ColumnName="jsonArgs" CF_DataType="CF_SQL_VARCHAR" Length="320" />
			<field ColumnName="Priority" CF_DataType="CF_SQL_INTEGER" Default="2" />
		</table>
		<table name="schActions">
			<field ColumnName="ActionID" CF_DataType="CF_SQL_BIGINT" PrimaryKey="true" Increment="true" />
			<field ColumnName="TaskID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="DateRun" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
			<field ColumnName="DateRunStart" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
			<field ColumnName="DateRunEnd" CF_DataType="CF_SQL_DATE" Special="Date" />
			<field ColumnName="ErrorMessage" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="ErrorDetail" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="Success" CF_DataType="CF_SQL_BIT" />
			<field ColumnName="Seconds" CF_DataType="CF_SQL_BIGINT" />
			<field ColumnName="ReturnVar" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="TaskName">
				<relation
					type="label"
					table="schTasks"
					field="Name"
					join-field="TaskID"
				/>
			</field>
		</table>
	</tables>
	</cfsavecontent>

	<cfreturn result>
</cffunction>

</cfcomponent>
