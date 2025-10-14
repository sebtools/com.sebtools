<cfcomponent displayname="Scheduler" extends="com.sebtools.RecordsTester" output="no">
<cfscript>
public void function beforeTests() {

	Variables.sTaskNames = {};
	
	Variables.DataMgr = CreateObject("component","DataMgr").init("TestSQL");
	loadScheduler();
	
	Variables.ThisDotPath = StructFind(GetMetaData(This),"FullName");
	Variables.ComponentsXML = '<site><components><component name="Example" path="#Variables.ThisDotPath#"></component></components></site>';
	
}

public void function runMe() {

	// I just track that the method ran

	if ( NOT StructKeyExists(Variables,"sRan") ) {
		Variables["sRan"] = {};
	}

	if ( StructKeyHasLen(Arguments,"TaskName") ) {
		Variables["sRan"][Arguments.TaskName] = now();
	}
	
}

/**
* condenseTaskName() should return just the task name.
*/
public void function testCondenseTaskName() testtype="unit" {

	makePublic(Variables.Scheduler,"condenseTaskName");
	
	assertEquals("23DCCC49-D5B7-A880-A820BD2FEF359D36",Variables.Scheduler.condenseTaskName("23DCCC49-D5B7-A880-A820BD2FEF359D36:202"),"condenseTaskName() failed to return only the task name.");
	assertEquals("TestName:Rubarb",Variables.Scheduler.condenseTaskName("TestName:Rubarb:202"),"condenseTaskName() failed to return only the task name for a task with a colon in it.");
	assertEquals("TestName:Rubarb",Variables.Scheduler.condenseTaskName("TestName:Rubarb"),"condenseTaskName() failed to return the whole task name for a task with a colon in it.");
	
}

/**
* isExpandedForm() should correctly identify expanded form task names.
*/
public void function testIsExpandedForm() testtype="unit" {

	makePublic(Variables.Scheduler,"isExpandedForm");
	
	assertEquals(True,Variables.Scheduler.isExpandedForm("23DCCC49-D5B7-A880-A820BD2FEF359D36:202"),"isExpandedForm() failed to recognize a traditional expanded task name.");
	assertEquals(False,Variables.Scheduler.isExpandedForm("23DCCC49-D5B7-A880-A820BD2FEF359D36"),"isExpandedForm() failed to recognize a traditional condensed task name.");
	assertEquals(True,Variables.Scheduler.isExpandedForm("TestName:Rubarb:202"),"isExpandedForm() failed to recognize an expanded task name with an extra colon in it.");
	assertEquals(False,Variables.Scheduler.isExpandedForm("TestName:Rubarb"),"isExpandedForm() mistakenly attributed as expanded a task name with a colon in it.");
	
}

/**
* splitTaskName() should a structure with the TaskID and TaskName.
*/
public void function testSplitTaskName() testtype="unit" {

	makePublic(Variables.Scheduler,"splitTaskName");
	
	assertEquals(StructFromArgs(Name="23DCCC49-D5B7-A880-A820BD2FEF359D36",TaskID=202),Variables.Scheduler.splitTaskName("23DCCC49-D5B7-A880-A820BD2FEF359D36:202"),"splitTaskName() failed to return the task name and id.");
	assertEquals(StructFromArgs(Name="TestName:Rubarb",TaskID=202),Variables.Scheduler.splitTaskName("TestName:Rubarb:202"),"splitTaskName() failed to return only the task name for a task with a colon in it.");
	assertEquals(StructFromArgs(Name="TestName:Rubarb"),Variables.Scheduler.splitTaskName("TestName:Rubarb"),"splitTaskName() failed to return the whole task name for a task with a colon in it.");
	
}

/**
* shouldCountContiguous() should count contiguous integers including and surrounding the target number in the given list
*/
public void function shouldCountContiguous() {
	var aTests = [
		{
			expected=3,
			args={list="5, 3, 7, 6, 4, 8, 10, 11, 12",target=11},
			message="Failed to count contiuous from a random list with no min/modulus."
		},

		{
			expected=4,
			args={list="1,2,4,6,7,8,9,10,3",target=3},
			message="Failed to find number in scrambled list with no min/modulus."
		},

		{
			expected=4,
			args={list="1,2,4,6,7,8,9,10,3",target=4},
			message="Failed to find right-most number in set in scrambled list with no min/modulus."
		},

		{
			expected=1,
			args={list="1,2,4,6,7,8,9,10",target=4},
			message="Failed to find solitary number in scrambled list with no min/modulus."
		},

		{
			expected=0,
			args={list="1,2,4,6,7,8,9,10",target=3},
			message="Failed to handle missing number in scrambled list with no min/modulus."
		},

		{
			expected=3,
			args={list="1,2,3,5,6,8,9,10",target=3},
			message="Failed to find number in ordered list with loop available without modulus argument."
		},

		{
			expected=6,
			args={list="1,2,3,5,6,8,9,10",target=3,modulus=10},
			message="Failed to find number in ordered list with left modulus."
		},

		{
			expected=6,
			args={list="1,2,3,5,6,8,9,10",target=9,modulus=10},
			message="Failed to find number in ordered list with right modulus."
		},

		{
			expected=3,
			args={list="2,3,5,6,8,9,10",target=9,modulus=10},
			message="Failed to find number in ordered list with max matching modulus, but no matching min."
		},

		{
			expected=3,
			args={list="1,2,3,5,6,8,9",target=2,modulus=10},
			message="Failed to find number in ordered list with min of one, but max not matching modulus."
		},

		{
			expected=2,
			args={list="7,8",target=7,modulus=10},
			message="Failed to find number at start of two-length ordered list."
		},

		{
			expected=2,
			args={list="7,8",target=8,modulus=10},
			message="Failed to find number at end of two-length ordered list."
		},

		{
			expected=1,
			args={list="7",target=7,modulus=10},
			message="Failed to find only number in list."
		},

		{
			expected=5,
			args={list="1,2,3,4,5,8,9,4,3",target=2,modulus=10},
			message="Failed to find number in list with repeated values."
		},

		{
			expected=5,
			args={list="1,2,3,5,6,7,9,10",target=2,modulus=10,min=1},
			message="Failed to find number on list with min."
		},

		{
			expected=0,
			args={list="1,2,3,4,5,6,7,9,10",target=2,modulus=10,min=3},
			message="Failed to handle number on list with invalid min."
		},

		{
			expected=7,
			args={list="1,2,3,4,5,6,7,9,10",target=4,modulus=10,min=3},
			message="Failed to find number on list with invalid min."
		},

		{
			expected=6,
			args={list="1,2,3,5,6,8,9,10,11",target=8,modulus=10,min=1},
			message="Failed to find number on list with invalid modulus."
		}

	];

	runMethodTests(aTests,"countContiguousIntegers",Variables.Scheduler,"assert");

}

/**
* Should correctly convert weekdays list to numeric values.
*/
public void function shouldConvertWeekdaysList() {
	var aTests = [

		{
			expected=1,
			args={weekdays="Sunday"},
			message="Failed to convert just Sunday."
		},
		
		{
			expected="1,2",
			args={weekdays="Sunday,Monday"},
			message="Failed to convert Sunday and Monday."
		},
		
		{
			expected="1,2",
			args={weekdays="Monday,Sunday"},
			message="Failed to convert Monday and Sunday."
		},
		
		{
			expected="2,4,6",
			args={weekdays="Monday, Wednesday, Friday"},
			message="Failed to convert Monday, Wednesday, Friday."
		},

		{
			expected="1,6,7",
			args={weekdays="Friday, Saturday, Sunday"},
			message="Failed to convert Friday, Saturday, Sunday"
		},

		{
			expected="1,5,6,7",
			args={weekdays="Friday, Saturday, Sunday, Wrenchday, Thursday"},
			message="Failed to convert Friday, Saturday, Sunday, Wrenchday, Thursday"
		},

		{
			expected="",
			args={weekdays=""},
			message="Failed to convert empty list"
		},

		{
			expected="",
			args={weekdays="any day you want"},
			message="Failed to convert nonsense string"
		}

	];

	runMethodTests(aTests,"DayOfWeekNumericList",Variables.Scheduler,"assert");
	
}

/**
* Scheduler should calculate time block lengths correctly.
*/
public void function shouldGetBlockLengths() {
	
	runMethodTests(
		[
			{
				expected=3,
				args={weekdays="Monday,Tuesday,Wednesday",runtime="2023-12-20"},
				message="Failed get block length for end of block of days."
			},
			{
				expected=3,
				args={weekdays="Saturday,Sunday,Monday,Wednesday",runtime="2023-12-18 8:15 AM"},
				message="Failed get block length for end of block of days."
			},
			{
				expected=3,
				args={weekdays="Saturday,Wednesday,Monday,Sunday",runtime="2023-12-18 8:15 AM"},
				message="Failed get block length for end of block of days with days out of order."
			}
		],
		"BlockLengthDays",
		Variables.Scheduler,
		"assert"
	);

	runMethodTests(
		[
			{
				expected=3,
				args={hours="6,7,8",runtime="2023-12-20 8:15 AM"},
				message="Failed get block length for end of block of hours."
			},
			{
				expected=4,
				args={hours="0,1,2,7,17,23",runtime="2023-12-20 2:15 AM"},
				message="Failed get block length for end of block of overnight hours."
			},
			{
				expected=3,
				args={hours="6,7,8",runtime="2023-12-20 6:15 AM"},
				message="Failed get block length for start of block of hours."
			},
			{
				expected=2,
				args={hours="7,8",runtime="2023-12-20 7:15 AM"},
				message="Failed get block length for start of block of two hours."
			},
			{
				expected=2,
				args={hours="7,8",runtime="2023-12-20 8:55 AM"},
				message="Failed get block length for end of block of two hours."
			}
		],
		"BlockLengthHours",
		Variables.Scheduler,
		"assert"
	);

}

/**
* Identically named one-time tasks should succeed if created/run back to back.
*/
public void function shouldRunBackToBackOneTimeTasks() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,args=TaskArgs);
	var TaskID2 = 0;
	
	runTasksWithCheck(TaskID1,"The first one-time task failed to run.");
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,args=TaskArgs);
	
	runTasksWithCheck(TaskID2,"The second one-time task failed to run.");
	
}

/**
* Identically named one-time tasks should succeed if created back to back and then run.
*/
public void function shouldRunSameNameOneTimeTasks() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,args=TaskArgs);
	var TaskID2 = 0;
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,args=TaskArgs);
	
	runTasksWithCheck(TaskID1,"The first one-time task failed to run.");
	runTasksWithCheck(TaskID2,"The second one-time task failed to run.");
	
}

/**
* One-time tasks with matching name, comp method and jsonArgs should succeed if created and run back to back.
*/
public void function shouldRunMatchingOneTimeTasksWithSameJSON() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var sTaskArgs = {PKID=100,"resend"=false};
	var TaskID1 = loadTask(Name=TaskName,args=sTaskArgs);
	var TaskID2 = 0;
	var TaskID3 = 0;

	runTasks(true);

	assertTrue(hasTaskRun(TaskID1),"The first one-time task failed to run.");

	TaskID2 = loadTask(Name=TaskName,args=sTaskArgs);

	runTasks(true);

	assertTrue(hasTaskRun(TaskID2),"The second one-time task failed to run.");

	TaskID3 = loadTask(Name=TaskName,args=sTaskArgs);

	runTasks(true);

	assertTrue(hasTaskRun(TaskID3),"The third one-time task failed to run.");
	
}

/**
* Identically named one-time tasks should succeed if created back to back and then run after Scheduler reinit with a defined Service Factory component.
*/
public void function shouldRunSameNameOneTimeTasksAfterReinitWithSFDef() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,args=TaskArgs);
	var TaskID2 = 0;
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,args=TaskArgs);
	
	dropScheduler();
	loadScheduler(True,Variables.ComponentsXML);
	
	runTasksWithCheck(TaskID1,"The first one-time task failed to run.");
	runTasksWithCheck(TaskID2,"The second one-time task failed to run.");
	
}

/**
* Identically named one-time tasks should succeed if created back to back and then run after Scheduler reinit with Service Factory and undefined but loadable component.
*/
public void function shouldRunSameNameOneTimeTasksAfterReinitWithSFNoDef() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,args=TaskArgs);
	var TaskID2 = 0;
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,args=TaskArgs);
	
	dropScheduler();
	loadScheduler(True);
	
	runTasksWithCheck(TaskID1,"The first one-time task failed to run.");
	runTasksWithCheck(TaskID2,"The second one-time task failed to run.");
	
}

/**
* Identically named one-time tasks should succeed if created back to back and then run after Scheduler reinit without setComponent or Service Factory.
*/
public void function shouldRunSameNameOneTimeTasksAfterReinitWithoutSF() mxunit:transaction="rollback" mxunit:expectedException="Scheduler" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,args=TaskArgs);
	var TaskID2 = 0;
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,args=TaskArgs);
	
	dropScheduler();
	loadScheduler();
	
	runTasksWithCheck(TaskID1,"The first one-time task failed to run.");
	runTasksWithCheck(TaskID2,"The second one-time task failed to run.");
	
}

/**
* Identically named one-time tasks should succeed if created back to back and then run after Scheduler reinit and setComponent.
*/
public void function shouldRunSameNameOneTimeTasksAfterReinitAndSetComp() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var sTaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,args=sTaskArgs);
	var TaskID2 = 0;
	
	sTaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,args=sTaskArgs);

	dropScheduler();
	loadScheduler();
	
	Variables.Scheduler.setComponent(Component=This,ComponentPath=Variables.ThisDotPath);
	
	runTasksWithCheck(TaskID1,"The first one-time task failed to run.");
	runTasksWithCheck(TaskID2,"The second one-time task failed to run.");
	
}

/**
* Identically named recurring tasks should succeed if created back to back and then run.
*/
public void function shouldRunSameNameRecurringTasks() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	var TaskID2 = 0;
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	
	runTasksWithCheck(TaskID1,"The first recurring task failed to run.");
	runTasksWithCheck(TaskID2,"The second recurring task failed to run.");
	
}

/**
* Identically named recurring tasks should succeed if created back to back and then run after Scheduler reinit with a defined Service Factory component.
*/
public void function shouldRunSameNameRecurringTasksAfterReinitWithSFDef() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	var TaskID2 = 0;
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	
	dropScheduler();
	loadScheduler(True,Variables.ComponentsXML);
	
	runTasksWithCheck(TaskID1,"The first recurring task failed to run.");
	runTasksWithCheck(TaskID2,"The second recurring task failed to run.");
	
}

/**
* Identically named recurring tasks should succeed if created back to back and then run after Scheduler reinit with Service Factory and undefined but loadable component.
*/
public void function shouldRunSameNameRecurringTasksAfterReinitWithSFNoDef() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	var TaskID2 = 0;
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	
	dropScheduler();
	loadScheduler(True);
	
	runTasksWithCheck(TaskID1,"The first recurring task failed to run.");
	runTasksWithCheck(TaskID2,"The second recurring task failed to run.");
	
}

/**
* Identically named recurring tasks should succeed if created back to back and then run after Scheduler reinit without setComponent or Service Factory.
*/
public void function shouldRunSameNameRecurringTasksAfterReinitWithoutSF() mxunit:transaction="rollback" mxunit:expectedException="Scheduler" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	var TaskID2 = 0;
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	
	dropScheduler();
	loadScheduler();
	
	runTasksWithCheck(TaskID1,"The first recurring task failed to run.");
	runTasksWithCheck(TaskID2,"The second recurring task failed to run.");
	
}

/**
* Identically named recurring tasks should run if created back to back and run after Scheduler reinit and setComponent.
*/
public void function shouldRunSameNameRecurringTasksAfterReinitAndSetComp() mxunit:transaction="rollback" {
	var TaskName = CreateUUID();
	var TaskArgs = {};
	var TaskID1 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	var TaskID2 = 0;
	
	TaskArgs["Test"] = 1;
	TaskID2 = loadTask(Name=TaskName,interval="hourly",args=TaskArgs);
	
	dropScheduler();
	loadScheduler();
	
	Variables.Scheduler.setComponent(Component=This,ComponentPath=Variables.ThisDotPath);
	
	runTasksWithCheck(TaskID1,"The first recurring task failed to run.");
	runTasksWithCheck(TaskID2,"The second recurring task failed to run.");
	
}

/**
* A one-time task should always run the next time that the scheduler runs tasks.
*/
public void function shouldRunOneTimeTask() mxunit:transaction="rollback" {
	// I don't need to do anything.
	var TaskID = loadTask();
	
	runTasksWithCheck(TaskID,"The one-time task failed to run.");
	
}

/**
* A one-time task should always run the next time that the scheduler runs tasks after it is reinitialized.
*/
public void function shouldRunOneTimeTaskAfterReinit() mxunit:transaction="rollback" {
	// I don't need to do anything.
	var TaskID = loadTask();
	
	dropScheduler();
	loadScheduler();
	
	Variables.Scheduler.setComponent(Component=This,ComponentPath=Variables.ThisDotPath);
	
	runTasksWithCheck(TaskID,"The one-time task failed to run.");
	
}

/**
* Simple arguments should be preserved across Scheduler restarts.
*/
public void function shouldPreverseArgs() mxunit:transaction="rollback" {
	// I don't need to do anything.
	var sArgs = StructFromArgs(a="Apple",b="Banana");
	var TaskID = loadTask(args=sArgs);
	
	dropScheduler();
	loadScheduler();
	
	stub();
}

/**
* Scheduled Tasks should run at appropriate intervals
*/
public void function shouldRunAtIntervals() mxunit:transaction="rollback" {
	var rec = {};
	var aTests = [];
	
	rec["Daily"] = loadTask(Name="Test_Daily",Interval="Daily");
	rec["Daily_Hours_78"] = loadTask(Name="Test_Daily_Hours",Interval="Daily",hours="7,8");

	//Just an internal shortcut method to build up an array of test results. That way we can run all of the assertions properly or just dump the results
	function addTest(
		required boolean expected,
		required string TaskName,
		string message=""
	) {
		ArrayAppend(
			aTests,
			{
				expected=Arguments.expected,
				actual=hasTaskRun(TaskID=rec[Arguments.TaskName]),
				message=Arguments.message,
				runtime=rec["now"]
			}
		);
	}

	/*
	Not the rollback happens after all of these run.
	We can, however, have as many different tasks (above) as we need to test scenarios thoroughly
	*/

	// *** Day 1
	
	// ****** Morning 1
	rec["now"] = "2023-01-01 6:30 AM";
	runTasks(runtime=rec["now"]);

	addTest(true,"Daily","Daily task failed to run first time.");
	addTest(false,"Daily_Hours_78","Daily_Hours task ran outside of listed hours.");

	// ****** Morning 2
	rec["now"] = "2023-01-01 7:30 AM";
	runTasks(runtime=rec["now"]);

	addTest(false,"Daily","Daily task ran twice in the same day.");
	addTest(true,"Daily_Hours_78","Daily_Hours failed to run in its first available time slot.");

	// ****** Afternoon
	rec["now"] = "2023-01-01 6:30 PM";
	runTasks(runtime=rec["now"]);

	addTest(false,"Daily","Daily task ran twice in the same day.");

	// *** Day Two
	rec["now"] = "2023-01-02 6:30 AM";
	runTasks(runtime=rec["now"]);

	addTest(true,"Daily","Daily task failed to run on the second day.");
	addTest(false,"Daily_Hours_78","Daily_Hours ran outside its time slot on the second day.");

	// ****** Morning 2
	rec["now"] = "2023-01-02 7:45 AM";
	runTasks(runtime=rec["now"]);

	addTest(false,"Daily","Daily task ran twice in the same day.");
	addTest(true,"Daily_Hours_78","Daily_Hours failed to run in its time slot on the second day.");

	// *** Day Three
	rec["now"] = "2023-01-03 6:30 AM";
	runTasks(runtime=rec["now"]);

	addTest(true,"Daily","Daily failed to run on third day.");
	addTest(false,"Daily_Hours_78","Daily_Hours ran before its time slot on the third day.");

	rec["now"] = "2023-01-03 9:15 AM";
	runTasks(runtime=rec["now"]);

	addTest(false,"Daily","Daily ran outside its timeslot on day three.");
	addTest(true,"Daily_Hours_78","Daily_Hours failed to run slightly outside of its time slot.");

	rec["now"] = "2023-01-03 10:15 PM";
	runTasks(runtime=rec["now"]);

	addTest(false,"Daily","Daily ran outside its timeslot on day three.");
	addTest(false,"Daily_Hours_78","Daily_Hours ran outside its timeslot on day three.");

	// *** Day Four
	rec["now"] = "2023-01-04 12:30 AM";
	runTasks(runtime=rec["now"]);

	addTest(false,"Daily","Daily ran on 4th day way too early.");
	addTest(false,"Daily_Hours_78","Daily_Hours ran before its time slot on the fourth day.");


	rec["now"] = "2023-01-04 6:30 AM";
	runTasks(runtime=rec["now"]);

	addTest(true,"Daily","Daily failed to run on fouth day.");
	addTest(false,"Daily_Hours_78","Daily_Hours ran before its time slot on the fourth day.");

	rec["now"] = "2023-01-04 7:15 AM";
	runTasks(runtime=rec["now"]);

	addTest(false,"Daily","Daily ran outside its timeslot on day four.");
	addTest(true,"Daily_Hours_78","Daily_Hours failed to return to its timeslot after running outside of it.");

	// ** Day Five (run failure)

	// ** Day Six (run failure)
	rec["now"] = "2023-01-06 12:30 AM";
	runTasks(runtime=rec["now"]);

	addTest(true,"Daily","Daily failed to run at first opportunity after missed day.");
	addTest(false,"Daily_Hours_78","Daily_Hours ran before its time slot on the sixth day.");

	rec["now"] = "2023-01-06 7:00 AM";
	runTasks(runtime=rec["now"]);

	addTest(false,"Daily","Daily ran outside its timeslot on day six.");
	addTest(true,"Daily_Hours_78","Daily_Hours failed to run at first opportunity after missed day");



	handleTestResultsArray(
		aTests=aTests,
		type="assert"
	);

}

/**
* I assert that given date is recent, as defined by the arguments provided.
*/
public void function assertTaskRan(
	required numeric TaskID,
	string message ="The task did not run."
) {
	
	assertTrue(hasTaskRun(Arguments.TaskID),arguments.message);
	
}

/**
* I assert that given date is recent, as defined by the arguments provided.
*/
public void function assertTaskNotRan(
	required numeric TaskID,
	string message ="The task did not run."
) {
	
	assertFalse(hasTaskRun(Arguments.TaskID),arguments.message);
	
}

private void function dropScheduler() {
	
	StructDelete(Variables,"Scheduler");
	
}

private boolean function hasTaskRun(required numeric TaskID) {
	var TaskName = "";
	var result = false;

	if ( StructKeyHasVal(Arguments,"TaskID") AND StructKeyExists(Variables.staskNames,Arguments.TaskID) ) {
		TaskName = Variables.staskNames[Arguments.TaskID];

		if ( StructKeyExists(Variables.sRan,TaskName) ) {
			result = true;
		}
	}

	return result;
}


private void function loadScheduler(
	boolean WithServiceFactory="false",
	string Components
) {
	var oServiceFactory = 0;
	
	if ( Arguments.WithServiceFactory ) {
		oServiceFactory = CreateObject("component","_framework.ServiceFactory").init();
		if ( StructKeyExists(Arguments,"Components") ) {
			oServiceFactory.loadXml(Arguments.Components);
		}
		Variables.Scheduler = CreateObject("component","com.sebtools.Scheduler").init(DataMgr=Variables.DataMgr,ServiceFactory=oServiceFactory);
	} else {
		Variables.Scheduler = CreateObject("component","com.sebtools.Scheduler").init(DataMgr=Variables.DataMgr);
	}
	
}

private string function loadTask(
	string interval="once",
	string Name,
	string MethodName="runMe"
) {
	var result = 0;
	
	if ( NOT ( StructKeyExists(Arguments,"Name") AND Len(Arguments.Name) ) ) {
		Arguments.Name = CreateUUID();
	}
	
	Arguments.ComponentPath = Variables.ThisDotPath;
	Arguments.Component = This;
	
	if ( NOT StructKeyExists(Variables,"Scheduler") ) {
		loadScheduler();
	}

	if ( NOT StructKeyExists(Arguments,"args") ) {
		Arguments["args"] = {};
	}

	Arguments["args"]["TaskName"] = Arguments.Name;

	result = Variables.Scheduler.setTask(ArgumentCollection=Arguments);

	Variables.sTaskNames[result] =  Arguments.Name;

	return result;
}

private void function reloadScheduler() {
	
	dropScheduler();
	loadScheduler();
	
}

private void function runTasks(boolean force="false",date runtime="#now()#") {

	Variables.sRan = {};
	
	Variables.Scheduler.runTasks(force=Arguments.force,runtime=Arguments.runtime);
	
}

private void function runTasksWithCheck(
	required numeric TaskID,
	string message
) {
	
	runTasks();
	assertTaskRan(ArgumentCollection=Arguments);
	
}
</cfscript>
</cfcomponent>