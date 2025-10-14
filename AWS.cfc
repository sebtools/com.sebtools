<cfcomponent displayname="AWS" output="false">
<cfscript>
/**
* I initialize and return the component.
* @Credentials AWS Credentials.
* @region The AWS region.
*/
public function init(
	required Credentials,
	string region,
	string signature="v4"
) {
	var key = "";

	for ( key in Arguments ) {
		Variables[key] = Arguments[key];
		if ( isObject(Arguments[key]) ) {
			This[key] = Arguments[key];
		}
	}

	// If region is not explicitely set, use the region from the credentials (if there is one).
	if ( NOT StructKeyExists(Variables,"region") ) {
		if ( Variables.Credentials.has("region") ) {
			Variables.region = Variables.Credentials.get("region");
		}
	}

	// Make sure needed credentials exist.
	if ( NOT ( Variables.Credentials.has("AccessKey") AND Variables.Credentials.has("SecretKey") ) ) {
		throw(message="AWS requires AWS credentials (AccessKey,SecretKey).",type="AWS");
	}

	// Make sure region is set.
	if ( NOT Variables.Credentials.has("region") ) {
		throw(message="AWS region has not been indicated.",type="AWS");
	}

	Variables.LockID = Hash(getAccessKey());

	Variables.MrECache = CreateObject("component","MrECache").init("AWS:#Variables.LockID#");
	This.MrECache = Variables.MrECache;

	Variables.RateLimiter = CreateObject("component","RateLimiter").init("AWS:#Variables.LockID#");
	This.RateLimiter = Variables.RateLimiter;

	Variables.sServices = {};

	Variables.oSignature = CreateObject("component","aws.sigs.#Arguments.signature#").init(This);

	return This;
}

/**
* I get the requested AWS service.
*/
public function getService(required string service) {

	if ( NOT StructKeyExists(Variables.sServices,Arguments.service) ) {
		Variables.sServices[Arguments.service] = CreateObject("component","aws.#LCase(Arguments.service)#").init(This);
	}

	return Variables.sServices[Arguments.service];
}

/**
* I get the LockID used by this instance of AWS.
*/
public function getLockID() {
	return Variables.LockID;
}

/**
* I get the Amazon credentials.
*/
public function getCredentials() {
	return Variables.Credentials;
}

/**
* I get the Amazon access key.
*/
public string function getAccessKey() {
	return Variables.Credentials.get("AccessKey");
}

/**
* I get the Amazon secret key.
*/
public string function getSecretKey() {
	return Variables.Credentials.get("SecretKey");
}

/**
* I get the endpoint for AWS Service.
* @subdomain The subdomain for the AWS service being used.
*/
public string function getEndPointUrl(required string subdomain) {
	return "https://#getHost(Arguments.subdomain)#/";
}

/**
* I get the host for AWS Service.
* @subdomain The subdomain for the AWS service being used.
*/
public string function getHost(required string subdomain) {
	return "#Arguments.subdomain#.#Variables.region#.amazonaws.com";
}

/**
* I get the region for AWS Service.
*/
public string function getRegion() {
	return Variables.region;
}

/**
* I determine if the action can be called.
* @subdomain The subdomain for the AWS service being used.
* @Action The AWS API action being called.
*/
public boolean function isCallable(
	required string subdomain,
	required string Action
) {
	return Variables.RateLimiter.isCallable("#Arguments.subdomain#_#Arguments.Action#");
}

/**
* I return the results of Amazon REST Call in the form easiest to use.
* @subdomain The subdomain for the AWS service being used.
* @Action The AWS API action being called.
* @default The value to return if within the rate limit.
* @method The HTTP method to invoke.
* @parameters An struct of HTTP URL parameters to send in the request.
* @timeout The default call timeout.
*/
public function callLimitedAPI(
	required string subdomain,
	required string Action,
	default,
	string method="GET",
	struct parameters="#{}#",
	numeric timeout="20",
	string timeSpan,
	string idleTime
) {
	var sArgs = {
		id="#Arguments.subdomain#_#Arguments.Action#",
		Component=This,
		MethodName="callAPI",
		Args=StructCopy(Arguments)
	};

	if ( StructKeyExists(Arguments,"default") ) {
		sArgs["default"] = Arguments.default;
	}
	if ( StructKeyExists(Arguments,"timeSpan") ) {
		sArgs["timeSpan"] = Arguments.timeSpan;
		StructDelete(sArgs["Args"],"timeSpan");
	}
	if ( StructKeyExists(Arguments,"idleTime") ) {
		sArgs["idleTime"] = Arguments.idleTime;
		StructDelete(sArgs["Args"],"idleTime");
	}
	if ( StructKeyExists(Arguments,"waitlimit") ) {
		sArgs["waitlimit"] = Arguments.waitlimit;
		StructDelete(sArgs["Args"],"waitlimit");
	}

	if ( StructKeyExists(Arguments,"timeSpan") ) {
		return Variables.RateLimiter.cached(ArgumentCollection=sArgs);
	} else {
		return Variables.RateLimiter.method(ArgumentCollection=sArgs);
	}
}

/**
* I return the results of Amazon REST Call in the form easiest to use.
* @subdomain The subdomain for the AWS service being used.
* @Action The AWS API action being called.
* @default The value to return if within the rate limit.
* @method The HTTP method to invoke.
* @parameters An struct of HTTP URL parameters to send in the request.
*/
public function callAPI(
	required string subdomain,
	required string Action,
	string method="GET",
	struct parameters="#{}#",
	numeric timeout="20"
) {
	var response = _callAPI(ArgumentCollection=Arguments);
	var response_result = 0;
	var result = 0;
	var ii = 0;

	// Traverse down the response tree to get the most accurate result possible.
	if ( StructKeyExists(response,"RESPONSE") ) {
		if ( isSimpleValue(response["RESPONSE"]) ) {
			response_result = response["RESPONSE"];
		} else if ( StructKeyExists(response["RESPONSE"],"#Arguments.Action#Response") ) {
			if ( StructKeyExists(response["RESPONSE"]["#Arguments.Action#Response"],"#Arguments.Action#Result") ) {
				response_result = response["RESPONSE"]["#Arguments.Action#Response"]["#Arguments.Action#Result"];
				//If the result has no attributes or text and just one child, return that.
				if ( ArrayLen(response_result.XmlChildren) EQ 1 AND NOT Len(Trim(response_result.XmlText)) AND NOT StructCount(response_result.XmlAttributes) ) {
					response_result = response_result.XmlChildren[1];
				}
			} else {
				if ( isXml(response["RESPONSE"]["#Arguments.Action#Response"]) AND response["RESPONSE"]["#Arguments.Action#Response"].XmlName EQ "#Arguments.Action#Result" ) {
					response_result = response["RESPONSE"]["#Arguments.Action#Response"].XmlChildren;
				} else {
					response_result = response["RESPONSE"]["#Arguments.Action#Response"];
				}
			}
		} else {
			response_result = response["RESPONSE"];
		}
	} else {
		response_result = response;
	}

	if ( isSimpleValue(response_result) ) {
		return response_result;
	}

	//If we get an error response from AWS, throw that as an exception.
	if ( StructKeyExists(response_result,"ErrorResponse") ) {
		throwError(Message=response_result.ErrorResponse.Error.Message.XmlText,errorcode=response_result.ErrorResponse.Error.Code.XmlText);
	}

	//If the XML response has children, but no attributes then we can safely return the children as a struct.
	if (
				isXml(response_result)
			AND	StructKeyExists(response_result,"XmlChildren")
			AND	ArrayLen(response_result.XmlChildren)
			AND	NOT StructCount(response_result.XmlAttributes)
			AND	Len(Trim(response_result.XmlChildren[1].XmlText))
			AND	NOT StructCount(response_result.XmlChildren[1].XmlAttributes)
		) {
			//One element, return the string. Otherwise: If every element is the same, then make an array. Otherwise, a structure.
			if ( ArrayLen(response_result.XmlChildren) EQ 1 ) {
				result = response_result.XmlChildren[1].XmlText;
			} else if ( ArrayLen(response_result.XmlChildren) EQ ArrayLen(response_result[response_result.XmlChildren[1].XmlName]) ) {
				result = [];
				ArrayResize(result, ArrayLen(response_result.XmlChildren));
				for ( ii=1; ii <= ArrayLen(response_result.XmlChildren); ii=ii+1 ) {
					result[ii] = response_result.XmlChildren[ii].XmlText;
				}
			} else {
				result = {};
				for ( ii=1; ii <= ArrayLen(response_result.XmlChildren); ii=ii+1 ) {
					result[response_result.XmlChildren[ii].XmlName] = response_result.XmlChildren[ii].XmlText;
				}
			}
	} else {
		result = response_result;
	}

	return result;
}
</cfscript>

<cffunction name="_callAPI" access="public" returntype="struct" output="false" hint="I return the raw(ish) results of Amazon REST Call.">
	<cfargument name="subdomain" type="string" required="true" hint="The subdomain for the AWS service being used.">
	<cfargument name="Action" type="string" required="true" hint="The AWS API action being called.">
	<cfargument name="method" type="string" default="GET" hint="The HTTP method to invoke.">
	<cfargument name="parameters" type="struct" default="#structNew()#" hint="An struct of HTTP URL parameters to send in the request.">
	<cfargument name="timeout" type="numeric" default="20" hint="The default call timeout.">

	<cfscript>
	var results = {};
	var HTTPResults = "";
	var sRequest = Variables.oSignature.getRequest(ArgumentCollection=Arguments);
	var sParam = 0;
	var header = "";

	results.error = false;
	results.response = {};
	results.message ="";
	results.responseheader = {};
	</cfscript>

	<cf_http result="HTTPResults" AttributeCollection="#sRequest#">
		<cfloop list="#ListSort(StructKeyList(sRequest.Headers),'text')#" index="header">
			<cf_httpparam type="header" name="#header#" value="#sRequest.Headers[header]#" />
		</cfloop>
		<cfif StructKeyExists(sRequest,"Payload")>
			<cf_httpparam type="body" value="#sRequest.Payload#" />
		</cfif>
		<cfloop array="#sRequest.params#" index="sParam">
			<cf_httpparam AttributeCollection="#sParam#" />
		</cfloop>
	</cf_http>

	<cfscript>
	results["Method"] = Arguments.method;
	results["URL"] = sRequest.url;
	results["Host"] = getHost(Arguments.subdomain);
	if ( StructKeyExists(HTTPResults,"fileContent") ) {
		results.response = HTTPResults.fileContent;
	} else {
		results.response = "";
	}
	results.responseHeader = HTTPResults.responseHeader;
	results.message = HTTPResults.errorDetail;
	if( Len(HTTPResults.errorDetail) ) {
		results.error = true;
	}

	if (
				StructKeyExists(HTTPResults.responseHeader, "content-type")
			AND	HTTPResults.responseHeader["content-type"] EQ "text/xml"
			AND	isXML(HTTPResults.fileContent)
		) {
		results.response = XMLParse(HTTPResults.fileContent);
		// Check for Errors
		if( NOT listFindNoCase("200,204",HTTPResults.responseHeader.status_code) ) {
			// check error xml
			results.error = true;
			results.message = "Type:#results.response.errorresponse.error.Type.XMLText# Code: #results.response.errorresponse.error.code.XMLText#. Message: #results.response.errorresponse.error.message.XMLText#";
		}
	}

	if(
			NOT results.error
		AND structKeyExists(HTTPResults,"responseHeader")
		AND structKeyExists(HTTPResults.responseHeader,"status_code")
		AND NOT listFindNoCase("200,204",HTTPResults.responseHeader.status_code)
	) {
		results.error = true;
		if ( isXML(HTTPResults.fileContent) ) {
			results.response = XMLParse(HTTPResults.fileContent);
			results.aMessage = XmlSearch(results.response,"//Message");
			if ( ArrayLen(results.aMessage) ) {
				results.message = results.aMessage[1].XmlText;
			}
			StructDelete(results,"aMessage");
		} else {
			results.message = HTTPResults.fileContent;
		}
		throwError(results.message);
	}

	return results;
	</cfscript>
</cffunction>

<cfscript>
/**
* Create request signature according to AWS standards.
*/
public function createSignature(required any string) {
	var fixedData = Replace(Arguments.string,"\n","#chr(10)#","all");

	return toBase64( HMAC_SHA256(getSecretKey(),fixedData) );
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

public void function throwError(
	required string message,
	string errorcode="",
	string detail="",
	string extendedinfo=""
) {
	throw(
		type="AWS",
		message="#Arguments.message#",
		errorcode="#Arguments.errorcode#",
		detail="#Arguments.detail#",
		extendedinfo="#Arguments.extendedinfo#"
	);
}

public function onMissingMethod() {
	
	if ( ListLen(Arguments["missingMethodName"],"_") EQ 2 ) {
		return callAPI(
			subdomain=ListFirst(Arguments["missingMethodName"],"_"),
			Action=ListLast(Arguments["missingMethodName"],"_"),
			parameters=Arguments.missingMethodArguments
		);
	} else {
		throw(
			message="The method #Arguments.missingMethodName# was not found in component.",
			detail="Ensure that the method is defined, and that it is spelled correctly.",
			type="Application"
		);
	}
}

/*
Like anything worthwhile, this has had lots of influence:
https://github.com/anujgakhar/AmazonSESCFC/blob/master/com/anujgakhar/AmazonSES.cfc
http://webdeveloperpadawan.blogspot.com/2012/02/coldfusion-and-amazon-aws-ses-simple.html
http://cflove.org/2013/02/using-amazon-ses-api-sendrawemail-with-coldfusion.cfm
https://gist.github.com/cflove/4716338

More recent finds:
** https://github.com/jcberquist/aws-cfml
** https://github.com/simonfree/cfAWSWrapper
http://www.codegist.net/snippet/coldfusion-cfc/s3wrappercfc_shtakai_coldfusion-cfc
http://amazonsnscfc.riaforge.org/
https://www.snip2code.com/Snippet/1180201/Amazon-Web-Services-(AWS)-S3-Wrapper-for
https://codegists.com/snippet/coldfusion-cfc/s3wrappercfc_malpaso_coldfusion-cfc
https://www.petefreitag.com/item/833.cfm
*/
</cfscript>
</cfcomponent>
