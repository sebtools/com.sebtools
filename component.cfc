<cfcomponent>
<cfscript>
Variables.component_instance_id = CreateUUID();

include "udfs.cfm";

public function init() {

	initInternal(ArgumentCollection=Arguments);

	return This;
}

private function initInternal() {
	var key = "";

	// Get all components from arguments
	for ( key in Arguments ) {
		Variables[key] = Arguments[key];
		if ( isObject(Arguments[key]) ) {
			This[key] = Arguments[key];
		}
	}

	if (
		NOT StructKeyExists(Variables,"DataMgr")
		AND
		StructKeyExists(Variables,"Manager")
		AND
		StructKeyExists(Variables.Manager,"DataMgr")
	) {
		Variables.DataMgr = Variables.Manager.DataMgr;
	}

	if ( StructKeyExists(Variables,"DataMgr") ) {
		Variables.datasource = Variables.DataMgr.getDatasource();
	}

	//addQueryMethods();

}

/**
* I remove arguments that are not explicitely declared in the function signature
*/
/*
Example:
function testExample(required string name, numeric age) {
    // Clean up the arguments scope
    Arguments = cleanArguments(GetFunctionCalledName(),Arguments);

    // Process the cleaned arguments
    writeDump(arguments);
}
*/
private function cleanArguments(required string functionName, required struct args) {
    // Extract declared argument names
    var aNamedArgs = getArgumentsArray(Variables[functionName]);
	var sResult = {};
	var arg = "";

	for (  arg in aNamedArgs ) {
		if ( StructKeyExists(args,arg) ) {
			sResult[arg] = args[arg];
		}
	}

	return sResult;
}

private array function getArgumentsArray(func) {
	var aResult = [];
	var sMethod = getMetaData(Arguments.func);
	var aa = 0;

	if ( ArrayLen(sMethod.Parameters) ) {
		for ( aa=1; aa LTE ArrayLen(sMethod.Parameters); aa++ ) {
			ArrayAppend(aResult,sMethod.Parameters[aa].name);
		}
	}

	return aResult;
}

private string function getArgumentsList(func) {

	return ArrayToList(getArgumentsArray(Arguments.func));
}

public string function getComponentInstanceID() {

	return Variables.component_instance_id;
}

//Inject one service into another
public void function injectService(
	required service,
	string name
) {
	var sMeta = 0;

	if ( NOT StructKeyHasLen(Arguments,"name") ) {
		sMeta = GetMetaData(Arguments.service);
		Arguments.name = ListLast(sMeta.name,".");
	}
	
	Variables[Arguments.name] = Arguments.service;
	This[Arguments.name] = Arguments.service;

}

public void function checkValidationErrors() {
	
	throwValidationError("",true);

}

public void function throwValidationError(
	required string message,
	boolean stop="false"
) {
	var result = "";
	if ( NOT StructKeyExists(Variables,"aValidationMessages") ) {
		Variables.aValidationMessages = [];
	}
	if ( Len(Trim(Arguments.message)) ) {
		ArrayAppend(
			Variables.aValidationMessages,
			Arguments.message
		);
	}

	if ( Arguments.stop AND ArrayLen(Variables.aValidationMessages) ) {
		if ( ArrayLen(Variables.aValidationMessages) EQ 1 ) {
			result = Variables.aValidationMessages[1];
		} else {
			result = SerializeJSON(Variables.aValidationMessages);
		}
		throw(
			type="validation",
			message="#result#"
		);
	}
}

private function sqlfile_get(required string name,struct args={},any context) {
	var loc = {};
	loc.name = sqlfile_name(Arguments.name);

	Arguments = Arguments.args;

	cf_DMSQL(name="loc.result") {
		include sqlfile_path(loc.name);
	}
	
	//If SQL was gotten, then return it
	if ( StructKeyExists(loc,"result") ) {
		return loc.result;
	}
}

private string function sqlfile_name(required string name) {
	var result = Arguments.name;

	var result = REReplaceNoCase(result, "^get_*", "");
	var result = REReplaceNoCase(result, "^sql_*", "");
	var result = REReplaceNoCase(result, "_*SQL$", "");

	return result;
}
private function sqlfile_run(required string name,struct args={}) {
	var loc = {};
	loc.name = sqlfile_name(Arguments.name);

	Arguments = Arguments.args;

	cf_DMQuery(name="loc.qResults") {
		include sqlfile_path(loc.name);
	}

	//If query returned a result, then return it
	if ( StructKeyExists(loc,"qResults") ) {
		return loc.qResults;
	}
}

private string function sqlfile_path(required string name) {
	return getChildRelativePath("sql/#Arguments.name#.sql.cfm");
}

public string function getRelativeFileContent(required string path) {
	var loc = {};
	loc.relpath = getChildRelativePath(Arguments.path);

	savecontent variable="loc.fileContent" {
		include loc.relpath;
	}

	return loc.fileContent;
}

public function getThisTemplatePath() {
	var sObj = getMetaData(This);

	while ( StructKeyExists(sObj,"Extends") ) {
		// Once the parent is in the sebtools package then we are at the highest point in the extension ladder that we need to go.
		if ( sObj.FullName CONTAINS "sebtools" ) {
			return sObj["Path"];
		}
		sObj = sObj["Extends"];
	}

	return getCurrentTemplatePath();
}

/**
 * Returns a relative path from the current template to an absolute file path.
 * v2 fix by Tony Monast
 * v2.1 fix by Tony Monast to deal with situations in which the specified path was the same as the current path, resulting in an error
 * v3 changed from getRelativePath() to getChildRelativePath() to solve related problem
 * 
 * @param relpath      Relative path from cild component. (Required)
 * @return Returns a string. 
 * @author Isaac Dealey (info@turnkey.to) 
 * @version 3, October 07, 2024
 */
function getChildRelativePath(required string relpath) {
	var currentPath = ListToArray(GetDirectoryFromPath(getThisTemplatePath()),"\/");
	var abspath = ListAppend(GetDirectoryFromPath(getCurrentTemplatePath()),relpath,"/");
	var filePath = ListToArray(abspath,"\/");
	var relativePath = ArrayNew(1);
	var pathStart = 0;
	var i = 0;

	/* Define the starting path (path in common) */
	for ( i = 1; i LTE ArrayLen(currentPath); i = i + 1 ) {

			if ( currentPath[i] NEQ filePath[i] ) {
					pathStart = i;
					break;
			}
	}

	if ( pathStart GT 0 ) {
			/* Build the prefix for the relative path (../../etc.) */
			for (i = ArrayLen(currentPath) - pathStart ; i GTE 0 ; i = i - 1) {
					ArrayAppend(relativePath,"..");
			}

			/* Build the relative path */
			for (i = pathStart; i LTE ArrayLen(filePath) ; i = i + 1) {
					ArrayAppend(relativePath,filePath[i]);
			}
	} else {
		/* Same level */
		ArrayAppend(relativePath,filePath[ArrayLen(filePath)]);
	}

	/* Return the relative path */
	return ArrayToList(relativePath,"/");
}

</cfscript>
</cfcomponent>
