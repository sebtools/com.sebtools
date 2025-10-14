<!--- 1.0 Beta 1 (Build 4) --->
<!--- Last Updated: 2010-11-23 --->
<!--- Created by Steve Bryant 2009-07-14 --->
<cfcomponent displayname="Records" extends="mxunit.framework.TestCase">
<cfscript>
include "udfs.cfm";
Variables.sObserverChecks = {};
Variables.sObserverEvents = {};
request.isTesting = true;

public function init() {

	request["isTesting"] = true;
	var key = "";

	for ( key in Arguments ) {
		variables[key] = Arguments[key];
	}

	return This;
}

public void function setUp() {
	var key = "";

	for (key in arguments) {
		variables[key] = arguments[key];
	}
}

/**
* I assert that given date is recent, as defined by the arguments provided.
*/
public void function assertRecent(
	required date date,
	string message="",
	numeric range="3",
	string interval="n"
) {

	assert("#arguments.date# GTE #getRecentDateTime(range=arguments.range,interval=arguments.interval)#",arguments.message);

}

/**
* I assert that email can be tested using isEmailTestable().
*/
public void function assertEmailTestable() {
	
	if ( NOT isEmailTestable() ) {
		fail("Email is not currently testable (DataMgr and Mailer must be available in the test component and logging email and DataMgr must be available and not in Simulation mode.)");
	}

}

/**
* I assert than an email has been sent. Arguments will match the keys of the email.
*/
public void function assertEmailSent(
	date when="#now()#",
	string message="Email was not sent"
) {

	assertEmailTestable();

	if ( NOT isEmailSent(argumentCollection=arguments) ) {
		fail(Arguments.message);
	}

}

public void function assertEmailNotSent(
	date when="#now()#",
	string message="Email was not sent"
) {

	if ( isEmailSent(argumentCollection=arguments) ) {
		fail(Arguments.message);
	}

}

public void function assertNoticeSent(
	required string notice,
	string to,
	date when="#now()#"
) {
	var message = "Notice (#arguments.notice#) was not sent";

	if ( StructKeyExists(arguments,"to") ) {
		message = "#message# to #arguments.to#";
	}
	message = "#message#.";

	if ( NOT isNoticeSent(argumentCollection=arguments) ) {
		fail(message);
	}

}

public void function assertNoticeNotSent(
	required string notice,
	string to,
	date when="#now()#"
) {
	var message = "Notice (#arguments.notice#) was sent";

	if ( StructKeyExists(arguments,"to") ) {
		message = "#message# to #arguments.to#";
	}
	message = "#message#.";

	if ( isNoticeSent(argumentCollection=arguments) ) {
		fail(message);
	}

}

public void function clearCaches() {
	var aCacheIDs = cacheGetAllIds();
	var ii = 0;
	var CacheName = "";

	// Clear all cached queries.
	objectcache(action="clear");

	// Clear all EhCaches except for those used by the Rate Limiter (I'm cheating here by know the implementation details of Rate Limiter).
	for ( ii=1; ii LTE ArrayLen(aCacheIDs); ii++ ) {
		CacheName = aCacheIDs[ii];
		if ( ListFirst(CacheName,"_") NEQ "LIMIT" ) {
			cacheRemove(CacheName);
		}
	}

}

public struct function getRandomData(
	required comp,
	struct data
) {
	var aFields = Arguments.comp.getFieldsArray();
	var sResult = {};
	var ii = 0;
	var sArgs = StructCopy(Arguments);
	var skiptypes = "DeletionMark,Sorter,DeletionDate,UUID";

	// Create test data
	for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
		if (
				StructKeyExists(aFields[ii],"name")
			AND	NOT ( StructKeyExists(arguments,"data") AND StructKeyExists(arguments.data,aFields[ii]["name"]) )
		) {
			if (
				StructKeyExists(aFields[ii],"fentity")
				AND
				StructKeyExists(Arguments.comp,"Parent")
				AND
				StructKeyExists(Arguments.comp,"Manager")
				AND
				StructKeyExists(Arguments.comp.Manager,"pluralize")
				AND
				StructKeyExists(Arguments.comp.Parent,Arguments.comp.Manager.pluralize(aFields[ii].fentity))
				AND
				isObject(Arguments.comp.Parent[Arguments.comp.Manager.pluralize(aFields[ii].fentity)])
			) {
				sResult[aFields[ii]["name"]] = getRandomPrimaryKeyValue(
					Arguments.comp.Parent[Arguments.comp.Manager.pluralize(aFields[ii].fentity)],
					( StructKeyExists(aFields[ii],"jointype") AND aFields[ii].jointype CONTAINS "many" )
				);
			} else if (
					StructKeyExists(aFields[ii],"ftable")
				AND	Len(aFields[ii]["ftable"])
			) {
				sResult[aFields[ii]["name"]] = getRandomTablePrimaryKeyValue(
					aFields[ii].ftable,
					( StructKeyExists(aFields[ii],"jointype") AND aFields[ii].jointype CONTAINS "many" )
				);
			} else if (
				StructKeyExists(aFields[ii],"datatype")
				AND
				ListFindNoCase("pk,fk",ListFirst(aFields[ii].type,":"))
			) {
				// No value
			} else if (
				StructKeyExists(aFields[ii],"relation")
			) {
					// No value
			} else if (
				StructKeyExists(aFields[ii],"datatype")
				AND
				ListFirst(aFields[ii].type,":") NEQ "pk"
				AND
				ListFirst(aFields[ii].type,":") NEQ "fk"
				AND
				NOT ListFindNoCase(skiptypes,aFields[ii].type)
				AND
				NOT ( StructKeyExists(aFields[ii],"Special") AND ListFindNoCase(skiptypes,aFields[ii].Special) )
				AND
				NOT ( StructKeyExists(aFields[ii],"test") AND aFields[ii].test IS false )
			) {
				sResult[aFields[ii]["name"]] = getRandomFieldValue(aFields[ii]);
			} else {
				sResult[aFields[ii]["name"]] = "";
			}
		}
	}

	if ( StructKeyExists(arguments,"data") ) {
		StructAppend(sResult,arguments.data,"yes");
	}

	// Ability to pass in named arguments directly without loading into data struct
	StructDelete(sArgs,"comp");
	StructDelete(sArgs,"data");
	if ( StructCount(sArgs) ) {
		StructAppend(sResult,sArgs,"yes");
	}

	return sResult;
}

public string function getRandomFieldValue(required field) {
	var sField = arguments.field;
	var result = getRandomValue(sField.datatype);
	var length = 0;
	var email_suffix = "@example.com";

	if ( StructKeyExists(sField,"Length") ) {
		length = sField.Length;
		if ( StructKeyExists(sField,"type") AND sField.type EQ "email" ) {
			length = length - Len(email_suffix);
		}
		if ( Len(result) GT length ) {
			result = Left(result,length);
		}
	}

	if ( StructKeyExists(sField,"type") AND sField.type EQ "email" ) {
		result = "#result##email_suffix#";
	}

	return result;
}

public string function getRandomPrimaryKeyValue(
	required comp,
	boolean  multi="false"
) {
	var keys = Arguments.comp.getPrimaryKeyValues();
	var result = "";
	var times = 1;
	var ii = 0;

	if ( ListLen(keys) ) {
		if ( Arguments.multi ) {
			times = RandRange(0,Min(50,ListLen(keys)));
		}

		if ( Val(times) ) {
			for ( ii=1; ii LTE times; ii++ ) {
				result = ListAppend(
					result,
					ListGetAt(keys,RandRange(1,ListLen(keys)))
				);
			}
		}
	}

	return result;
}

public string function getRandomTablePrimaryKeyValue(
	required string tablename,
	boolean  multi="false"
) {
	var pklist = "";
	var qRecords = 0;
	var keys = "";
	var times = 1;
	var result = "";
	var sRecord = 0;

	cf_service(name="DataMgr");

	pklist = Variables.DataMgr.getPrimaryKeyFieldNames(Arguments.tablename);

	if ( ListLen(pklist) EQ 1 ) {
		qRecords = Variables.DataMgr.getRecords(tablename=Arguments.tablename,fieldlist=pklist,maxrows=50);
		for ( sRecord in qRecords ) {
			keys = ListAppend(keys,sRecord[pklist]);
		}
	}

	if ( ListLen(keys) ) {
		if ( Arguments.multi) {
			times = RandRange(0,ListLen(keys));
		}

		if ( Val(times) ) {
			for ( ii=1; ii LTE times; ii++ ) {
				result = ListAppend(
					result,
					ListGetAt(keys,RandRange(1,ListLen(keys)))
				);
			}
		}
	}

	return result;
}

public string function getRandomValue(
	required string datatype,
	boolean allowNulls="yes"
) {
	var result = "";

	switch (arguments.datatype) {
		case "boolean":
				result = RandRange(0,1);
			break;
		case "date":
				result = DateFormat(DateAdd("d",RandRange(30,1095),now()),"yyyy-mm-dd");
			break;
		case "integer":
		case "number":
				result = RandRange(0,100);
			break;
		case "text":
				result = "Test#RandRange(1,1000000)#";
			break;
		case "email":
				result = "Test#RandRange(1,1000000)#@example.com";
			break;
	}

	// Add a 20% chance of a NULL/empty
	if ( Arguments.allowNulls AND RandRange(1,5) EQ 1 ) {
		return "";
	}

	return result;
}

public boolean function isEmailTestable() {
	var result = false;

	if ( StructKeyExists(variables,"NoticeMgr") ) {
		if ( NOT StructKeyExists(variables,"DataMgr") ) {
			variables.DataMgr = variables.NoticeMgr.getDataMgr();
		}
		if ( NOT StructKeyExists(variables,"Mailer") ) {
			variables.Mailer = variables.NoticeMgr.getMailer();
		}
	}
	if ( StructKeyExists(variables,"Manager") AND NOT StructKeyExists(Variables,"DataMgr") ) {
		variables.DataMgr = variables.Manager.DataMgr;
	}

	result = (
			StructKeyExists(variables,"DataMgr")
		AND	StructKeyExists(variables,"Mailer")
		AND	variables.DataMgr.getDatabase() NEQ "Sim"
	);

	if ( NOT variables.Mailer.getIsLogging() ) {
		Variables.Mailer.startLogging(Variables.DataMgr);
	}

	return result;
}

public boolean function isEmailSent(date when="#now()#") {
	var result = false;

	if ( NumEmailsSent(argumentCollection=arguments) ) {
		result = true;
	}

	return result;
}

public boolean function isNoticeSent(
	required string notice,
	string to,
	date when="#now()#"
) {

	return isEmailSent(argumentCollection=arguments);
}

public date function getRecentDateTime(
	date date="#now()#",
	numeric range="3",
	string interval="n"
) {

	return DateAdd(arguments.interval,-Abs(arguments.range),arguments.date);
}

public numeric function NumEmailsSent(date when="#now()#") {
	var result = 0;
	var aFilters = [];
	var sFilter = {};
	var qSentMessages = 0;
	var sSentMessage = 0;
	var oDataMgr = 0;
	var fieldlist = "LogID";
	var sData = Duplicate(Arguments);
	var RecipientFields = "To,CC,BCC,From";
	var ii = 0;
	var key = "";

	assertEmailTestable();

	oDataMgr = variables.DataMgr;

	sFilter["field"] = "DateSent";
	sFilter["operator"] = ">=";
	sFilter["value"] = DateAdd("n",-3,arguments.when);

	ArrayAppend(aFilters,sFilter);

	if ( StructKeyExists(arguments,"regex") AND Len(arguments.regex) ) {
		fieldlist = "LogID,Subject,Contents,HTML,Text";
	}

	qSentMessages = oDataMgr.getRecords(tablename=variables.Mailer.getLogTable(),data=sData,filters=aFilters,fieldlist=fieldlist);

	if ( qSentMessages.RecordCount EQ 0 ) {
		// look more thoroughly for a match
		// Exclude recipient fields from the query
		for ( key in ListToArray(RecipientFields) ) {
			StructDelete(sData,key);
		}
		fieldlist = ListAppend(fieldlist,RecipientFields);
		qSentMessages = oDataMgr.getRecords(tablename=variables.Mailer.getLogTable(),data=sData,filters=aFilters,fieldlist=fieldlist);

		if ( qSentMessages.RecordCount ) {
			// Get just the email addresses themselves
			for ( key in ListToArray(RecipientFields) ) {
				if ( StructKeyExists(Arguments,key) AND Len(Arguments[key]) ) {
					Arguments[key] = getEmailAddresses(Arguments[key] );
				}
			}

			//Find by just email address (must be in cfscript as CFCONTINUE is not available until CF9 and we need to support CF8)
			for ( ii = qSentMessages.RecordCount; ii GTE 1; ii=ii-1 ) {
				for ( key in Arguments ) {
					if ( ListFindNoCase(RecipientFields,key) AND StructKeyExists(Arguments,key) AND Len(Arguments[key]) ) {
						if ( StructKeyExists(Arguments,key) AND Len(Arguments[key]) ) {
							//Are all emails that were passed in as arguments found in the query record?
							if (
								NOT (
									Len(qSentMessages[key][ii])
									AND
									isListInList(Arguments[key],getEmailAddresses(qSentMessages[key][ii]))
								)
							) {
								qSentMessages = QueryDeleteRows(qSentMessages,ii);
								continue;
							}
						}
					}
				}
			}
		}
	}

	result = qSentMessages.RecordCount;

	if ( result AND StructKeyExists(arguments,"regex") AND Len(arguments.regex) ) {
		for ( sSentMessage in qSentMessages ) {
			if (
				NOT (
					ReFindNoCase(arguments.regex,sSentMessage.Subject)
					OR
					ReFindNoCase(arguments.regex,sSentMessage.Contents)
					OR
					ReFindNoCase(arguments.regex,sSentMessage.Text)
					OR
					ReFindNoCase(arguments.regex,sSentMessage.HTML)
				)
			) {
				result--;
			}
		}
	}

	return result;
}

public function getEmailAddresses(
	string string,
	string EmailAddresses=""
) {
	var sLenPos = 0;
	var emailAddress = "";

	if ( REFind("([a-zA-Z0-9_\.=-]+@[a-zA-Z0-9_\.-]+\.[[:alpha:]]{2,6})",arguments.string) ) {
		sLenPos = REFind("([a-zA-Z0-9_\.=-]+@[a-zA-Z0-9_\.-]+\.[[:alpha:]]{2,6})",arguments.string,1,true);
		emailAddress = mid(arguments.string, sLenPos.pos[1], sLenPos.len[1]);
		if ( NOT ListFindNoCase(arguments.EmailAddresses,emailAddress) ) {
			arguments.EmailAddresses = ListAppend(arguments.EmailAddresses, emailAddress);
		}
		arguments.string = Mid(arguments.string, sLenPos.pos[1] + sLenPos.len[1], len(arguments.string));
		if ( REFind("([a-zA-Z0-9_\.=-]+@[a-zA-Z0-9_\.-]+\.[[:alpha:]]{2,6})",arguments.string) ) {
			arguments.EmailAddresses = getEmailAddresses(arguments.string, arguments.EmailAddresses);
		}
	}

	return arguments.EmailAddresses;
}

/**
 * Removes rows from a query.
 * Added var col = "";
 * No longer using Evaluate. Function is MUCH smaller now.
 *
 * @param Query      Query to be modified
 * @param Rows      Either a number or a list of numbers
 * @return This function returns a query.
 * @author Raymond Camden (ray@camdenfamily.com)
 * @version 2, October 11, 2001
 */
function QueryDeleteRows(Query,Rows) {
    var tmp = QueryNew(Query.ColumnList);
    var i = 1;
    var x = 1;

    for( i=1;i LTE Query.recordCount; i=i+1 ) {
        if( NOT ListFind(Rows,i) ) {
            QueryAddRow(tmp,1);
            for(x=1;x LTE ListLen(tmp.ColumnList);x=x+1) {
                QuerySetCell(tmp, ListGetAt(tmp.ColumnList,x), query[ListGetAt(tmp.ColumnList,x)][i]);
            }
        }
    }
    return tmp;
}

/**
 * Checks is all elements of a list X is found in a list Y.
 * v2 by Raymond Camden
 * v3 idea by Bill King
 * v4 fix by Chris Phillips
 *
 * @param l1      The first list. (Required)
 * @param l2      The second list. UDF checks to see if all of l1 is in l2. (Required)
 * @param delim1      List delimiter for l1. Defaults to a comma. (Optional)
 * @param delim2      List delimiter for l2. Defaults to a comma. (Optional)
 * @param matchany      If true, UDF returns true if at least one item in l1 exists in l2. Defaults to false. (Optional)
 * @return Returns a boolean.
 * @author Daniel Chicayban (dbastos@math.utoledo.edu)
 * @version 4, September 4, 2008
 */
function isListInList(l1,l2) {
    var delim1 = ",";
    var delim2 = ",";
    var i = 1;
    var matchany = false;

    if(arrayLen(arguments) gte 3) delim1 = arguments[3];
    if(arrayLen(arguments) gte 4) delim2 = arguments[4];
    if(arrayLen(arguments) gte 5) matchany = arguments[5];

    for(i=1; i lte listLen(l1,delim1); i=i+1) {
        if(matchany and listFind(l2,listGetAt(l1,i,delim1),delim2)) return true;
        if(not matchany and not listFind(l2,listGetAt(l1,i,delim1),delim2)) return false;
    }
    return not matchany;
}

public void function loadExternalVars(
	required string varlist,
	string scope="Application",
	boolean skipmissing="false"
) {
	var varname = "";
	var scopestruct = 0;
	var OriginalScope = Arguments.scope;

	// Scopes that start with a dot are nested within a service.
	if ( Left(arguments.scope,1) EQ "." AND Len(arguments.scope) GTE 2 ) {
		// To start, drop the leading dot from the scope name since we know what it is within this conditional block.
		arguments.scope = Right(arguments.scope,Len(arguments.scope)-1);

		// Get it from ServiceFactory if we can.
		if ( Application.Framework.Loader.hasService(arguments.scope) ) {
			variables[arguments.scope] = Application.ServiceFactory.getService(arguments.scope);
		} else {
			// If not, try to get it from Application scope (may result in an exception).
			variables[arguments.scope] = Application[arguments.scope];
		}
		// Now we can just treat the service we got back as a scope.
		arguments.scope = "Variables.#arguments.scope#";
	}

	scopestruct = StructGet(arguments.scope);

	for ( varname in ListToArray(arguments.varlist) ) {
		if ( StructKeyExists(scopestruct,varname) ) {
			// Try to get it from the scope.
			variables[varname] = scopestruct[varname];
		} else if ( StructKeyExists(Application,"Framework") AND Application.Framework.Loader.hasService(varname) ) {
			// Get it from ServiceFactory if we can.
			variables[varname] = Application.ServiceFactory.getService(varname);
		} else if ( NOT arguments.skipmissing ) {
			throw(message="#scope#.#varname# is not available.");
		}
	}

}

public function getService(required string ServiceName) {

	loadServiceFactory();

	if ( NOT StructKeyExists(Variables,Arguments.ServiceName) ) {
		// Get it from ServiceFactory if we can.
		if ( StructKeyExists(Variables,"ServiceFactory") AND Variables.ServiceFactory.hasService(Arguments.ServiceName) ) {
			variables[Arguments.ServiceName] = Variables.ServiceFactory.getService(Arguments.ServiceName);
		} else {
			// If not, try to get it from Application scope (may result in an exception).
			variables[Arguments.ServiceName] = Application[Arguments.ServiceName];
		}
	}

	return Variables[Arguments.ServiceName];
}

public any function loadServiceFactory() {

	if ( NOT StructKeyExists(Variables,"ServiceFactory") ) {
		if ( NOT StructKeyExists(request,"TestServiceFactory") ) {
			request.TestServiceFactory = getServiceFactory();
		}
		// Variable won't exist unless running on Neptune.
		if ( StructKeyExists(request,"TestServiceFactory") ) {
			Variables.ServiceFactory = request.TestServiceFactory;
		}
	}

	// Variable won't exist unless running on Neptune.
	if ( StructKeyExists(Variables,"ServiceFactory") ) {
		return Variables.ServiceFactory;
	}
}

public any function getServiceFactory() {
	var RootPath = "";
	var CompCFMPath = "";
	var oConfigExisting = 0;
	var oConfigNew = 0;
	var sConfigData = 0;
	var sConfigObject = 0;
	var result = 0;

	if ( StructKeyExists(Application,"Framework") AND StructKeyExists(Application.Framework,"Config") ) {
		// Get reference to existing Config object
		oConfigExisting = Application.Framework.Config;
		// Get meta data on existing Config object just so we can init it from the same path
		sConfigObject = GetMetaData(oConfigExisting);
		// Get existing settings so we can pass them (perhaps altered) into our new config object
		sConfigData = StructCopy(oConfigExisting.getSettings());
		// Get path to components.cfm file
		RootPath = oConfigExisting.getSetting('RootPath');
		CompCFMPath = RootPath & "_config\components.cfm";
		// New config object (should only look in request, not Application)
		oConfigNew = CreateObject("component","#sConfigObject.Name#").init("request");
		// Copy existing settings in
		oConfigNew.setSettings(ArgumentCollection=sConfigData);
		/*
		This is our hook to allow RecordsTester to be extended and have extension pass in whatever it needs to new Config.
		Should be set up so that it will be the same for any test run in the same request.
		 */
		setSettings(oConfigNew);

		// Create new service factory from existing one (with potentially changed data)
		result = CreateObject("component","_framework.ServiceFactory").init(oConfigNew,CompCFMPath);

		return result;
	}
}

public any function setSettings(required any oConfig) {

	// This method can be extended to pass in or change any configuration for testing.

}

public any function RecordObject(
	required Service,
	required Record,
	string fields
) {

	Arguments.Service = CreateObject("component","com.sebtools.TestRecords").init(Arguments.Service);

	return CreateObject("component","RecordObject").init(ArgumentCollection=Arguments);
}

/*
* I run an array of a test structures
* @Tests: A structure of test. Each struct should have "expected", "args", "message"
* @component: The component to test.
* @method: The name of the method to test (can be private)
* @type: Either "assert", which will run an assertion on each test or "dump" which will dump and abort all of the tests with their actual values.
*/
public void function runMethodTests(
	required array aTests,
	required string method,
	component="#Variables#",
	string type="assert"
) {
	var sTest = 0;

	makePublic(Arguments.component,Arguments.method);

	//Verify structs in array
	for ( sTest in aTests ) {
		if ( NOT isStruct(sTest) ) {
			throw("Every entry in the tests array must be a structure.");
		}
		if ( NOT StructKeyExists(sTest,"expected") ) {
			throw("Every key of each test must have an 'expected' key.");
		}
	}


	for ( sTest in aTests ) {
		sTest["actual"] = invoke(Arguments.component,Arguments.method,sTest.args);
	}

	handleTestResultsArray(aTests,Arguments.type);

}

/**
* I handle a test results array
*/
public function handleTestResultsArray(
	required array aTests,
	string type="assert"
) {
	var aFails = [];

	if ( Arguments.type EQ "dump" ) {
		writeDump(var=aTests,abort=true);
	} else {
		for ( sTest in aTests ) {
			
			if ( NOT StructKeyExists(sTest,"args") ) {
				sTest["args"] = {};
			}
			if ( NOT StructKeyExists(sTest,"message") ) {
				sTest["message"] = '"#Arguments.method#" method fails for arguments #SerializeJSON(sTest.args)#';
			}
			if ( NOT StructKeyExists(sTest,"assert") ) {
				sTest["assert"] = "Equals";
			}

			try {
				invoke(
					Variables,
					"assert#sTest.Assert#",
					{
						condition=sTest["actual"],
						expected=sTest["expected"],
						actual=sTest["actual"],
						message=sTest["message"]
					}
				);
			} catch ( mxunit.exception.AssertionFailedError e ) {
				ArrayAppend(aFails,sTest);
				sTest["isFail"] = true;
			}

		}

		if ( ArrayLen(aFails) ) {
			if ( Arguments.type EQ "dumpfails" ) {
				writeDump(var=aFails,abort=true);
			} else {
				if ( ArrayLen(aFails) EQ 1 ) {
					fail(ArgumentCollection=aFails[1]);
				} else {
					fail(message='#ArrayLen(aFails)# tests out of #ArrayLen(aTests)# failed. Switch to handleTestResultsArray to a type of "assert" or "dumpfails" to see the details.');
				}
			}
		}
		if (
			Arguments.type EQ "dumpfails"
			AND
			ArrayLen(aFails)
		) {
			writeDump(var=aFails,abort=true);
		} else {
			if ( ArrayLen(aFails) )
			fail();
		}

	}

}

public any function runInRollbackTransaction(
	required method,
	comp,
	struct args="#{}#"
) {
	var result = 0;
	var fMethod = 0;

	if ( StructKeyExists(arguments,"comp") AND isSimpleValue(arguments.method) ) {
		fMethod = arguments.com[arguments.method];
	} else if ( isCustomFunction(arguments.method) ) {
		fMethod = arguments.method;
	} else {
		throw(message="Method must be either the name of a method in a component or the method itself.");
	}

	transaction {
		try {
			result = fMethod(argumentCollection=arguments.args);
		} catch ( any e ) {
			transaction action="rollback";
			rethrow;
		}

		transaction action="rollback";
	}

	if ( isDefined("result") ) {
		return result;
	}
}

public void function stub() {
	fail("No test written yet.");
}

public query function getTestRecord(
	required comp,
	string data,
	string fieldlist=""
) {
	var sCompMeta = Arguments.comp.getMetaStruct();
	var id = saveTestRecord(argumentCollection=Arguments);
	var qRecord = 0;
	var sArgs = {
		"#sCompMeta.arg_pk#":id,
		"fieldlist":Arguments.fieldlist
	};

	qRecord = invoke(arguments.comp,sCompMeta.method_get,sArgs);

	return qRecord;
}

public query function getTestRecords(
	required comp,
	numeric records,
	struct data,
	string fieldlist=""
) {
	var sCompMeta = Arguments.comp.getMetaStruct();
	var ids = saveTestRecords(argumentCollection=Arguments);
	var qRecords = 0;
	var sArgs = {
		"#LCase(sCompMeta.arg_sort)#":ids,
		"fieldlist":Arguments.fieldlist
	};

	qRecords = invoke(arguments.comp,sCompMeta.method_gets,sArgs);

	return qRecords;
}

public string function saveTestRecord(
	required comp,
	struct data
) {
	var sCompMeta = arguments.comp.getMetaStruct();
	var sData = getRandomData(argumentCollection=arguments);

	return invoke(arguments.comp,sCompMeta.method_save,sData);
}

public string function loadTestRecords(
	required comp,
	numeric records,
	struct data
) {
	var result = "";

	Arguments = convertTestRecordsArgs(ArgumentCollection=Arguments);

	result = Arguments.comp.getPrimaryKeyValues(ArgumentCollection=Arguments.data,MaxRows=Arguments.records);
	Arguments.records = Arguments.records - ListLen(result);

	if ( Arguments.records GT 0 ) {
		result = ListAppend(result,saveTestRecords(ArgumentCollection=Arguments));
	}

	return result;
}

public struct function convertTestRecordsArgs(
	required comp,
	numeric records,
	struct data
) {

	// Handle if data is passed in to records slot or if arguments are reversed
	if (
		StructKeyExists(Arguments,"records")
		AND
		isStruct(Arguments.records)
		AND
		(
			NOT StructKeyExists(Arguments,"data")
			OR
			isNumeric(Arguments.data)
		)
	) {
		if ( StructKeyExists(Arguments,"data") ) {
			Arguments.temp = Arguments.data;
		}
		Arguments.data = Arguments.records;
		if ( StructKeyExists(Arguments,"temp") ) {
			Arguments.records = Arguments.temp;
			StructDelete(Arguments,"temp");
		}
	}

	if (
		NOT (
			StructKeyExists(Arguments,"records")
			AND
			isSimpleValue(Arguments.records)
			AND
			Val(Arguments.records)
		)
	) {
		Arguments.records = 0;
	}

	if ( NOT ( StructKeyExists(Arguments,"data") AND isStruct(Arguments.data) ) ) {
		Arguments.data = {};
	}

	return Arguments;
}

// *** Observer Tests ***
/**
* I assert that the given listener was called.
*/
public void function assertAnnounced(
	required string UUID,
	string message=""
) {

	listened(Arguments.UUID);

	if ( NOT ArrayLen(Variables.sObserverEvents[UUID]) ) {
		fail(Arguments.message);
	}

}

/**
* I assert that the given listener was called.
*/
public void function assertNotAnnounced(
	required string UUID,
	string message=""
) {

	listened(Arguments.UUID);

	if ( ArrayLen(Variables.sObserverEvents[UUID]) ) {
		fail(Arguments.message);
	}

}

/**
* I make sure that the listener is listening for the given event.
*/
public string function listen(
	required string EventName,
	struct Args
) {
	var UUID = createUUID();

	Variables.sObserverChecks[UUID] = Arguments;
	Variables.sObserverEvents[UUID] = [];

	cf_service(name="Observer");

	Variables.Observer.registerListener(
		Listener=This,
		ListenerName=UUID,
		ListenerMethod="listen_callback",
		EventName=Arguments.EventName
	);

	return UUID;
}

/**
* I respond to the an event from a listener.
*/
public function listen_callback() {
	var UUID = "";

	var UUID = "";
	var isCalled = false;
	var arg = "";
	for ( UUID in Variables.sObserverChecks  ) {
		isCalled = true;
		for ( arg in Variables.sObserverChecks[UUID]["Args"] ) {
			//Make sure every argument matches what is expected.
			if ( NOT ( StructKeyExists(Arguments,arg) AND Arguments[arg] EQ Variables.sObserverChecks[UUID]["Args"][arg] ) ) {
				isCalled = false;
			}
		}
		if ( isCalled IS true ) {
			ArrayAppend(Variables.sObserverEvents[UUID],Arguments);
		}
	}
	
}

/**
* I run code to end listening for an event.
*/
public void function listened(required string UUID) {

	Variables.Observer.runDelays();

	if ( StructKeyExists(Variables.sObserverChecks,UUID) ) {
		Variables.Observer.registerListener(
			Listener=This,
			ListenerName=UUID,
			ListenerMethod="listen_callback",
			EventName=Variables.sObserverChecks[UUID].EventName
		);
	}

}

public string function saveTestRecords(
	required comp,
	records,
	struct data
) {
	var ii = 0;
	var result = "";

	Arguments = convertTestRecordsArgs(ArgumentCollection=Arguments);

	if ( NOT Val(Arguments.records) ) {
		Arguments.records = RandRange(10,40);
	}

	if ( StructKeyExists(Arguments,"data") AND NOT isStruct(Arguments.data) ) {
		StructDelete(Arguments,"data");
	}

	for ( ii=1; ii LTE Arguments.records; ii++ ) {
		result = ListAppend(result,saveTestRecord(ArgumentCollection=Arguments));
	}

	return result;
}

public string function saveTestRecordOnly(
	required comp,
	struct data
) {
	var sCompMeta = arguments.comp.getMetaStruct();
	var sData = getRandomData(argumentCollection=arguments);
	var result = 0;

	result = invoke(arguments.comp,"saveRecordOnly",sData);

	return result;
}

public query function QueryGetRandomRow(required query) {
	var cols = arguments.query.ColumnList;
	var qResult = QueryNew(cols);
	var rownum = 0;
	var col = "";

	if ( arguments.query.RecordCount ) {
		rownum = RandRange(1,arguments.query.RecordCount);
		QueryAddRow(qResult);
		for ( col in ListToArray(cols) ) {
			QuerySetCell(qResult,col,arguments.query[col][rownum]);
		}
	}

	return qResult;
}

function QueryFromArgs() {
	return Struct2Query(arguments);
}
//By Charlie Griefer
function Struct2Query(struct) {
	var key = "";
	var qResult = 0;

	if ( NOT isStruct(arguments.struct) ) return false;

	qResult = QueryNew(StructKeyList(arguments.struct));
	QueryAddRow(qResult, 1);
	for (key in arguments.struct) {
		QuerySetCell(qResult, key, arguments.struct[key]);
	}

	return qResult;
}
/**
* Accepts a specifically formatted chunk of text, and returns it as a query object.
* v2 rewrite by Jamie Jackson
*
* @param queryData      Specifically format chunk of text to convert to a query. (Required)
* @return Returns a query object.
* @author Bert Dawson (bert@redbanner.com)
* @version 2, December 18, 2007
*/
function QuerySim(queryData) {
	var fieldsDelimiter="|";
	var colnamesDelimiter=",";
	var listOfColumns="";
	var tmpQuery="";
	var numLines="";
	var cellValue="";
	var cellValues="";
	var colName="";
	var lineDelimiter=chr(10) & chr(13);
	var lineNum=0;
	var colPosition=0;

	// the first line is the column list, eg "column1,column2,column3"
	listOfColumns = Trim(ListGetAt(queryData, 1, lineDelimiter));

	// create a temporary Query
	tmpQuery = QueryNew(listOfColumns);

	// the number of lines in the queryData
	numLines = ListLen(queryData, lineDelimiter);

	// loop though the queryData starting at the second line
	for(lineNum=2; lineNum LTE numLines; lineNum = lineNum + 1) {
		cellValues = ListGetAt(queryData, lineNum, lineDelimiter);

		if (ListLen(cellValues, fieldsDelimiter) IS ListLen(listOfColumns,",")) {
			QueryAddRow(tmpQuery);
			for (colPosition=1; colPosition LTE ListLen(listOfColumns); colPosition = colPosition + 1){
				cellValue = Trim(ListGetAt(cellValues, colPosition, fieldsDelimiter));
				colName = Trim(ListGetAt(listOfColumns,colPosition));
				QuerySetCell(tmpQuery, colName, cellValue);
			}
		}
	}

	return( tmpQuery );
}

public struct function StructFromArgs() {
	var sTemp = 0;
	var sResult = {};
	var key = "";

	if ( ArrayLen(arguments) EQ 1 AND isStruct(arguments[1]) ) {
		sTemp = arguments[1];
	} else {
		sTemp = arguments;
	}

	// set all arguments into the return struct
	for ( key in sTemp ) {
		if ( StructKeyExists(sTemp, key) ) {
			sResult[key] = sTemp[key];
		}
	}

	return sResult;
}
</cfscript>
</cfcomponent>
