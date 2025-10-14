<cfcomponent displayname="Amazon Signature Version 3" extends="base" output="false">
<cfscript>

/**
* I return the raw(ish) results of Amazon REST Call.
* @subdomain The subdomain for the AWS service being used.
* @Action The AWS API action being called.
* @method The HTTP method to invoke.
* @parameters A struct of HTTP URL parameters to send in the request.
* @timeout The default call timeout.
*/

public struct function getRequest(
	required string subdomain,
	required string Action,
	string method="GET",
	struct parameters="#{}#",
	numeric timeout="20"
) {
	var sRequest = Super.getRequest(ArgumentCollection=Arguments);
	var timestamp = sRequest.headers["Date"];

	sRequest["Headers"]["X-Amzn-Authorization"] = getAuthorizationString(timestamp);

	return sRequest;
}

/**
* I return the authorization string.
*/
public string function getAuthorizationString(required string timestamp) {
	
	if ( NOT StructKeyExists(Arguments,"timestamp") ) {
		Arguments.timestamp = makeTimeStamp();
	}

	return "AWS3-HTTPS AWSAccessKeyId=#getAccessKey()#,Algorithm=HmacSHA256,Signature=#createSignature(Arguments.timestamp)#";
}

/**
* I create request signature according to AWS standards.
*/
public function createSignature(required any string) {
	var fixedData = Replace(Arguments.string,"\n","#chr(10)#","all");

	return toBase64(HMAC_SHA256(getSecretKey(),fixedData) );
}

public string function makeTimeStamp() {
	return GetHTTPTimeString(Now());
}
</cfscript>
</cfcomponent>
