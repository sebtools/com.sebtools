<cfcomponent displayname="SessionMgr" hint="I handle setting and retreiving session-related variables. Enabling storage mechanism for the variables to be changed.">
<!--- %%Must add time-out. --->
<cfscript>
public function init(
	string scope="Session",
	string requestvar="SessionInfo"
) {
	var scopes = "Client,Session";

	if ( NOT ListFindNoCase(scopes, Arguments.scope) ) {
		throw(
			message="The scope argument for SessionMgr must be a valid scope (#scopes#).",
			type="MethodErr"
		);
	}

	Variables.scope = Arguments.scope;
	Variables.requestvar = Arguments.requestvar;
	updateRequestVar();

	This.AddRowToQuery = AddToQuery;

	Variables.DateInitialized = now();

	return This;
}

/**
* I add a value to an array.
*/
public function AddToArray(
	required string variablename,
	required value
) {
	
	var result = [];

	if ( exists(Arguments.variablename) ) {
		result = getValue(Arguments.variablename);
	}

	ArrayAppend(result,Arguments.value);
	setValue(Arguments.variablename,result);

}

/**
* I add a value to a string.
*/
public function AddToList(
	required string variablename,
	string value,
	string delimiter=","
) {
	
	var result = "";

	if ( exists(Arguments.variablename) ) {
		result = getValue(Arguments.variablename);
	}

	result = ListAppend(result,Arguments.value,Arguments.delimiter);
	setValue(Arguments.variablename,result);

}

/**
* I add a structure as a row to a query.
*/
public function AddToQuery(
	required string variablename,
	required struct rowstruct
) {
	var result = 0;
	var col = 0;
	var sRows = StructCopy(Arguments.rowstruct);

	if ( exists(Arguments.variablename) ) {
		result = getValue(Arguments.variablename);
	} else {
		result = QueryNew(StructKeyList(sRows));
	}

	// Add row
	QueryAddRow(result);
	for ( col in sRows ) {
		QuerySetCell(result,col,sRows[col]);
	}

	setValue(Arguments.variablename,result);

}

/**
* I add a value to a string.
*/
public function AddToString(
	required string variablename,
	requried value
) {
	var result = "";

	if ( exists(Arguments.variablename) ) {
		result = getValue(Arguments.variablename);
	}

	result = result & Arguments.value;
	setValue(Arguments.variablename,result);

}

/**
* I add a value to a structure.
*/
public function AddToStruct(
	required string variablename,
	required string key,
	required value,
	boolean overwrite="true"
) {
	var result = {};

	if ( exists(Arguments.variablename) ) {
		result = getValue(Arguments.variablename);
	}

	// Make sure we don't overwrite properties if we are told not to do so.
	if ( Arguments.overwrite OR NOT StructKeyExists(result,key) ) {
		result[Arguments.key] = Arguments.value;
		setValue(Arguments.variablename,result);
	}
}

/**
*
*/
public function paramVar(
	required string variablename,
	required value
) {

	cfparam(name="#variables.scope#.#Arguments.variablename#", default="#Arguments.value#");
	updateRequestVar();

}

public void function deleteVar( required string variablename ) {
	if ( hasSessionManagement() ) {
		lock timeout="20" throwontimeout="Yes" name="SessionMgr" type="EXCLUSIVE" {
			StructDelete( Evaluate( variables.scope ), Arguments.variablename );
		}
	}
	setDateLastChanged();
	updateRequestVar();
}

/**
* I indicate if session scope is enabled.
*/
public boolean function hasSessionManagement() {
	var foo = "";

	if ( NOT StructKeyExists(request,"SessionMgr_hasSessionManagement") ) {
		try {
			foo = Evaluate(variables.scope);
			request["SessionMgr_hasSessionManagement"] = true;
		} catch ( any e ) {
			request["SessionMgr_hasSessionManagement"] = false;
		}
	}

	return request["SessionMgr_hasSessionManagement"];
}

/**
* I delete all of the variables from this session.
*/
public void function killSession() {
	var itms = dump();
	var itm = "";

	// Delete selected keys from struct to prevent problems when calling deleteVar on each key
	StructDelete(itms,"timecreated");
	StructDelete(itms,"urltoken");
	StructDelete(itms,"cftoken ");
	StructDelete(itms,"cfid");
	StructDelete(itms,"hitcount");
	StructDelete(itms,"lastvisit");

	// Ditch all variables (except as already removed above)
	for ( itm in itms ) {
		variables.deleteVar(itm);
	}

	setDateLastChanged();

}

/**
 * I dump the scope holding SessionMgr data.
 */
public struct function dump() {

	if ( hasSessionManagement() ) {
		try {
			return StructCopy(Evaluate(Variables.scope));
		} catch ( any e ) {
			return Evaluate(Variables.scope);
		}
	} else {
		return {};
	}
}

/**
* I check if the given variable exists in the SessionMgr scope.
*/
public boolean function exists(required string variablename) {
	
	if ( hasSessionManagement() ) {
		try {
			return StructKeyExists(Evaluate(Variables.scope),Arguments.variablename);
		} catch (any e) {
			request["SessionMgr_hasSessionManagement"] = false;
			return false;
		}
	} else {
		return false;
	}
}

public date function getLastChanged() {

	if ( exists("DateSessionMgrLastChanged") ) {
		return getValue("DateSessionMgrLastChanged");
	} else {
		return Variables.DateInitialized;
	}
}

/**
* I return session data ( deprecated in favor of dump() ).
*/
public struct function getSessionData() {

	return dump();
}

/**
* I get the value of the given user-specific variable.
*/
public function getValue(required string variablename) {
	var result = 0;

	if ( hasSessionManagement() ) {
		lock timeout="20" throwontimeout="Yes" name="SessionMgr" type="READONLY" {
			result = Evaluate(Variables.scope & "." & Arguments.variablename);
		}
	}

	if ( isWDDX(result) ) {
		wddx(action="WDDX2CFML",input="#result#",output="result");
	}

	return result;
}


/**
* I set the value of the given user-specific variable.
*/
public void function setValue(
	required string variablename,
	required value
) {
	var val = arguments.value;

	if ( variables.scope eq "Client" AND NOT isSimpleValue(arguments.value) ) {
		wddx(action="CFML2WDDX",input="#arguments.value#",output="val");
	}

	lock timeout="20" throwontimeout="Yes" name="SessionMgr" type="EXCLUSIVE" {
		SetVariable("#variables.scope#.#arguments.variablename#", val);
		setDateLastChanged();
	}
	updateRequestVar();
}

/*
 * I update the request variable to match the contents of the scope.
 */
public void function updateRequestVar() {

	request[variables.requestvar] = dump();

}

package void function setDateLastChanged() {
	SetVariable("#variables.scope#.DateSessionMgrLastChanged", now());
}

/**
 * Gets all the session keys and session ids for an application.
 *
 * @return Returns an array.
 * @author Rupert de Guzman (rndguzmanjr@yahoo.com)
 * @version 2, September 23, 2004
 */
function getSessionList(){
 	var obj = "";
	var i = 1;
	var sessionlist = ArrayNew(1);
	var enum = "";

 	obj = CreateObject("java","coldfusion.runtime.SessionTracker");
	enum = obj.getSessionKeys();

	for(;i lte obj.getSessionCount(); i=i+1){
			arrayAppend(sessionlist,obj.getSession(enum.next()));
	}
	return sessionlist;
}
</cfscript>
</cfcomponent>
