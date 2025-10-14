<cfcomponent extends="com.sebtools.component">
<cfscript>
public function init(required Manager) {

	Variables.aServices = [];

	Variables.MrECache = CreateObject("component","MrECache").init(
		id="content_service",
		timeSpan=CreateTimeSpan(0,4,0,0)
	);

	return This;
}

public function addService(
	required Component,
	required string Method
) {

	ArrayAppend(Variables.aServices,Arguments);

	return This;
}

public string function phrase(
	required string key,
	string locale,
	struct data
) {
	var sService = 0;
	var sArgs = 0;
	var result = Arguments.key;

	for ( sService in Variables.aServices ) {
		sArgs = {phrase="#result#"};
		if ( StructKeyHasLen(Arguments,"locale") ) {
			sArgs["locale"] = Arguments.locale;
		}
		if ( StructKeyExists(Arguments,"data") AND StructCount(Arguments.data) ) {
			sArgs["data"] = Arguments.data;
		}
		result = invoke(sService["Component"],sService["Method"],sArgs);
	}

	return result;
}
</cfscript>
</cfcomponent>
