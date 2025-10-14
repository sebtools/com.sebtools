<cfcomponent output="false">
<cfscript>
/**
*  I initialize and return the component.
*/
public function init(
	required AWS,
	required string subdomain
) {

	initInternal(ArgumentCollection=Arguments);

	return This;
}

/**
*  I initialize and return the component.
*/
public function initInternal(
	required AWS,
	required string subdomain
) {
	
	Variables.AWS = Arguments.AWS;
	Variables.subdomain = Arguments.subdomain;

	Variables.MrECache = Variables.AWS.MrECache;
	Variables.RateLimiter = Variables.AWS.RateLimiter;

	Variables.LockID = Variables.AWS.getLockID();

}

public function onMissingMethod() {
	return Variables.AWS.callAPI(
		subdomain=Variables.subdomain,
		Action=Arguments["missingMethodName"],
		parameters=Arguments.missingMethodArguments
	);
}

/*
* I invoke an Amazon REST Call.
* @Action The AWS API action being called.
* @method The HTTP method to invoke.
* @parameters A struct of HTTP URL parameters to send in the request.
*/
private function callAPI(
	required string Action,
	string method="GET",
	struct parameters="#{}#"
) {

	Arguments.subdomain = Variables.subdomain;

	return Variables.AWS.callAPI(ArgumentCollection=Arguments);
}

/*
* I invoke an Amazon REST Call.
* @Action The AWS API action being called.
* @method The HTTP method to invoke.
* @parameters A struct of HTTP URL parameters to send in the request.
*/
private function callLimitedAPI(
	required string Action,
	string method="GET",
	struct parameters="#{}#"
) {

	Arguments.subdomain = Variables.subdomain;

	return Variables.AWS.callLimitedAPI(ArgumentCollection=Arguments);
}

function AWSTime2CFTime(str) {
	if ( REFindNoCase("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z",str) ) {
		return DateAdd("d",0,Trim(REReplaceNoCase(str,"(T|Z)"," ","ALL")));
	} else {
		return Trim(str);
	}
}
</cfscript>
</cfcomponent>