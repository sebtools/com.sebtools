<cfcomponent displayname="Amazon Signature Version Base Component" output="false">
<cfscript>
public function init(required AWS) {
	var key = "";

	for ( key in Arguments ) {
		Variables[key] = Arguments[key];
		if ( isObject(Arguments[key]) ) {
			This[key] = Arguments[key];
		}
	}

	return This;
}

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
	var timestamp = makeTimeStamp();
	var paramtype = "URL";
	var sortedParams = "";
	var EndPointURL = Variables.AWS.getEndPointUrl(Arguments.subdomain);
	var NamedArgs = "subdomain,Action,method,parameters,timeout";
	var arg = "";
	var param = "";
	var sRequest = {};

	for (arg in Arguments) {
		if ( isSimpleValue(Arguments[arg]) AND Len(Trim(Arguments[arg])) AND NOT ListFindNoCase(NamedArgs,arg) ) {
			if ( ListLen(EndPointURL,"?") EQ 1 ) {
				EndPointURL &= "?";
			} else {
				EndPointURL &= "&";
			}
			EndPointURL &= "#arg#=#Trim(Arguments[arg])#";
		}
	}

	Arguments.parameters["Action"] = Arguments.Action;

	sortedParams = ListSort(StructKeyList(Arguments.parameters), "textnocase");

	if( Arguments.method IS "POST" ) {
		paramtype = "FORMFIELD";
	}

	sRequest = {
		method="#arguments.method#",
		url="#EndPointURL#",
		charset="utf-8",
		timeout="#arguments.timeout#",
		headers = {
			"Date":timestamp,
			"host":Variables.AWS.getHost(Arguments.subdomain)
		},
		params=[]
	};

	for ( param in ListToArray(sortedParams) ) {
		ArrayAppend(
			sRequest.params,
			{type="#paramType#",name="#param#",value="#trim(arguments.parameters[param])#"}
		);
	}

	return sRequest;
}

/**
* I create request signature according to AWS standards.
*/
public function createSignature(required any string) {
	throw(message="Method must be created in the signature component.");
}

/**
* I get the Amazon access key.
*/
public string function getAccessKey() {
	return Variables.AWS.getAccessKey();
}

/**
* I get the region for AWS Service.
*/
public string function getRegion() {
	return Variables.AWS.getRegion();
}

/**
* I get the Amazon secret key.
*/
public string function getSecretKey() {
	return Variables.AWS.getSecretKey();
}

/**
* I return the authorization string.
*/
public string function getAuthorizationString(required string timestamp) {
	throw(message="Method must be created in the signature component.");
}

public string function makeTimeStamp() {
	return GetHTTPTimeString(Now());
}

private binary function HMAC_SHA256(
	required string signKey,
	required string signMessage
) {
	var jMsg = JavaCast("string",Arguments.signMessage).getBytes("utf-8");
	var jKey = JavaCast("string",Arguments.signKey).getBytes("utf-8");
	var key = createObject("java","javax.crypto.spec.SecretKeySpec").init(jKey,"HmacSHA256");
	var mac = createObject("java","javax.crypto.Mac").getInstance(key.getAlgorithm());
	mac.init(key);
	mac.update(jMsg);

	return mac.doFinal();
}


/*
<OWNER> = James Solo
<YEAR> = 2013

In the original BSD license, both occurrences of the phrase "COPYRIGHT HOLDERS AND CONTRIBUTORS" in the disclaimer read "REGENTS AND CONTRIBUTORS".

Here is the license template:

Copyright (c) 2013, James Solo
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
/**
* THIS WORKS DO NOT FUCK WITH IT.
*/
public binary function HMAC_SHA256_bin(
	required string signMessage,
	required binary signKey
) {
	var jMsg = JavaCast("string",Arguments.signMessage).getBytes("UTF8");
	var jKey = Arguments.signKey;

	var key = createObject("java","javax.crypto.spec.SecretKeySpec");
	var mac = createObject("java","javax.crypto.Mac");

	key = key.init(jKey,"HmacSHA256");

	mac = mac.getInstance(key.getAlgorithm());
	mac.init(key);
	mac.update(jMsg);

	return mac.doFinal();
}
</cfscript>
</cfcomponent>
