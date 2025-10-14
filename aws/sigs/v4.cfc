<cfcomponent displayname="Amazon Signature Version 4" extends="base" output="false">
<cfscript>
/*
The underscores before a method name indicate how close they are to that which should be called externally
Method order and indention should reflect the order of events for the process, not alphabetical as usual
*/
public function init(required AWS) {
	
	Super.init(ArgumentCollection=Arguments);

	return This;
}

public string function getCommonParameters() {
	return "Action,Version,X-Amz-Algorithm,X-Amz-Credential,X-Amz-Date,X-Amz-Security-Token,X-Amz-Signature,X-Amz-SignedHeaders";
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
	var CommmonParameters = getCommonParameters();
	var sRequest = Super.getRequest(ArgumentCollection=Arguments);
	var timestamp = sRequest.headers["Date"];
	var sHeaders = {
		"host":Variables.AWS.getHost(Arguments.subdomain),
		"x-amz-date":getStringToSignDateFormat(timestamp)
	};
	var sAuthArgs = {
		Method=sRequest.method,
		URI=sRequest.URL,
		Headers=sHeaders,
		FormStruct={},
		Payload="",
		AccessKey=getAccessKey(),
		SecretKey=getSecretKey(),
		Region=getRegion(),
		Service=Arguments.subdomain,
		RequestDateTime=timestamp
	};
	CommmonParameters = "none";
	//Make sure URL parameters are in the URL for the request in the query string.
	sRequest.params.each(function(struct){
		if ( Arguments.struct["type"] EQ "URL" ) {
			if ( ListLen(sRequest["URL"],"?") EQ 1 ) {
				sRequest["URL"] &= "?";
			} else {
				sRequest["URL"] &= "&";
			}
			sRequest["URL"] &= Arguments.struct["name"] & "=" & Arguments.struct["value"];
		}
		if ( Arguments.struct["type"] EQ "FORMFIELD" ) {
			sAuthArgs["FormStruct"][Arguments.struct["name"]] = Arguments.struct["value"];
		}
	});
	sAuthArgs["URI"] = sRequest["URL"];// = sAuthArgs["URI"];
	sRequest.params = [];
	if ( StructCount(sAuthArgs["FormStruct"]) AND NOT Len(Trim(sAuthArgs.Payload)) ) {
		sAuthArgs.Payload = __buildCanonicalQueryString(sAuthArgs.FormStruct);
		sHeaders["Content-Type"] = "application/x-www-form-urlencoded";
		sHeaders["Content-Length"] = Len(sAuthArgs.Payload);
		sRequest.Payload = sAuthArgs.Payload;
	}
	sAuthArgs.Headers = sHeaders;

	sHeaders["Authorization"] = getAuthorizationString(ArgumentCollection=sAuthArgs);

	//StructDelete(sRequest["Headers"],"Date");
	StructAppend(sRequest["Headers"],sHeaders);

	return sRequest;
}

/**
* I return the authorization string.
*/
public string function getAuthorizationString(
	required string Method,
	required string URI,
	struct Headers,
	struct FormStruct="#{}#",
	string Payload="",
	required string AccessKey,
	required string SecretKey,
	required string Region,
	date RequestDateTime="#now()#"
) {
	var sLoc = {};

	StructAppend(Arguments.Headers,{"x-amz-date":getStringToSignDateFormat(Arguments.RequestDateTime)});

	sLoc.T1_1_Method = UCase(Arguments.Method);

	sLoc.T1_2_CanonicalURI = __buildCanonicalURI(Arguments.URI);
	sLoc.T1_3_CanonicalQueryString = __buildCanonicalQueryString(Arguments.URI,false);
	sLoc.T1_4_CanonicalHeaders = __buildCanonicalHeaders(Arguments.Headers);
	sLoc.T1_5_SignedHeaders = __buildSignedHeaders(Arguments.Headers);
	//Payload is form structure if a form is passed in. Need to cross-check to method=POST?
	if ( StructCount(Arguments.FormStruct) AND NOT Len(Trim(Arguments.Payload)) ) {
		sLoc.CanonicalPayload = __buildCanonicalQueryString(Arguments.FormStruct);
		Arguments.Payload = sLoc.CanonicalPayload;
	}
	sLoc.T1_6_PayloadHash = __buildPayloadHash(Arguments.Payload);
	sLoc.T1_7_CanonicalRequest = (
			""
		&	sLoc.T1_1_Method & chr(10)
		&	sLoc.T1_2_CanonicalURI & chr(10)
		&	sLoc.T1_3_CanonicalQueryString & chr(10)
		&	sLoc.T1_4_CanonicalHeaders & chr(10)
		&	sLoc.T1_5_SignedHeaders & chr(10)
		&	sLoc.T1_6_PayloadHash
	);

	sLoc.T1_8_HashedCanonicalRequest = hashy(sLoc.T1_7_CanonicalRequest);
	sLoc.T2_1_Algorithm = "AWS4-HMAC-SHA256";
	sLoc.T2_2_DateTimeISO = getStringToSignDateFormat(Arguments.RequestDateTime);
	sLoc.T2_3_CredentialScope = "#DateFormat(Arguments.RequestDateTime,'yyyymmdd')#/#LCase(Arguments.Region)#/#Arguments.Service#/aws4_request";
	sLoc.T2_4_CanonicalRequestHash = sLoc.T1_8_HashedCanonicalRequest;
	sLoc.T2_5_StringToSign = _createSigningString(
		ServiceName=Arguments.Service,
		Region=Arguments.Region,
		CanonicalRequestHash=sLoc.T1_8_HashedCanonicalRequest,
		RequestDateTime=Arguments.RequestDateTime
	);

	sLoc.T3_1_SigningKey = __buildSigningKey(
		SecretKey=Arguments.SecretKey,
		Region=Arguments.Region,
		Service=Arguments.Service,
		RequestDateTime=Arguments.RequestDateTime
	);
	sLoc.T3_1_SigningKeyString = BinaryEncode( sLoc.T3_1_SigningKey, "hex" );
	sLoc.T3_2_Signature = _createSignature(
		StringToSign=sLoc.T2_5_StringToSign,
		SecretKey=Arguments.SecretKey,
		Region=Arguments.Region,
		Service=Arguments.Service,
		RequestDateTime=Arguments.RequestDateTime
	);
	sLoc.Credential = "#Arguments.AccessKey#/#sLoc.T2_3_CredentialScope#";
	sLoc.T4_AuthHeader = "#sLoc.T2_1_Algorithm# Credential=#sLoc.Credential#, SignedHeaders=#sLoc.T1_5_SignedHeaders#, Signature=#sLoc.T3_2_Signature#";

	return sLoc.T4_AuthHeader;
}

/**
* I get the signature for the given request.
*/
public string function getSignature(
	required string Method,
	required string URI,
	struct Headers,
	string Payload="",
	required string SecretKey,
	required string Region,
	required string Service,
	date RequestDateTime="#now()#"
) {
	var HashedCanonicalRequest = _createCanonicalRequestHash(
		Method=Arguments.Method,
		URI=Arguments.URI,
		Headers=Arguments.Headers,
		Payload=Arguments.Payload
	);
	var StringToSign = _createSigningString(
		ServiceName=Arguments.Service,
		Region=Arguments.Region,
		CanonicalRequestHash=HashedCanonicalRequest,
		RequestDateTime=Arguments.RequestDateTime
	);
	var Signature = _createSignature(
		StringToSign=StringToSign,
		SecretKey=Arguments.SecretKey,
		Region=Arguments.Region,
		Service=Arguments.Service,
		RequestDateTime=Arguments.RequestDateTime
	);

	return Signature;
}

	/**
	* Step 1: Task 1
	*/
	public string function _createCanonicalRequestHash(
		required string Method,
		required string URI,
		struct Headers,
		string Payload=""
	) {
		return hashy(_createCanonicalRequest(ArgumentCollection=Arguments));
	}

	/**
	* Step 1: Task 1
	*/
	public string function _createCanonicalRequest(
		required string Method,
		required string URI,
		struct Headers,
		string Payload=""
	) {
		var result = "";

		result = (
				""
			&	UCase(Arguments.Method) & chr(10)
			&	__buildCanonicalURI(Arguments.URI) & chr(10)
			&	__buildCanonicalQueryString(Arguments.URI) & chr(10)
			&	__buildCanonicalHeaders(Arguments.Headers) & chr(10)
			&	__buildSignedHeaders(Arguments.Headers) & chr(10)
			&	__buildPayloadHash(Arguments.Payload)
		);

		return result;
	}

		/**
		* Step 1: Task 1: Part 1: Canonical URI.
		*/
		public string function __buildCanonicalURI(required string URI) {
			var result = ListFirst(Arguments.URI,"?");

			result = REReplaceNoCase(result, "^\w+://", "", "ONE");
			result = ListDeleteAt(result,1,"/");

			result = "/#result#";

			result = replace( urlEncode( result ), "%2F", "/", "all");
			// Double-encode (except S3)
			result = replace( urlEncode( result ), "%2F", "/", "all");

			return result;
		}

		/**
		* Step 1: Task 1: Part 2: Canonical Query String.
		*/
		public string function __buildCanonicalQueryString(
			required parameters,
			boolean isEncoded="true"
		) {
			var sParams = {};
			var param = "";
			var aParams = [];
			var aResults = [];

			// Make sure parameters are a struct.
			if ( isStruct(Arguments.parameters) ) {
				sParams = Arguments.parameters;
			} else if ( isSimpleValue(Arguments.parameters) ) {
				Arguments.parameters = ListRest(Arguments.parameters,"?");
				for ( param in ListToArray(Arguments.parameters,"&") ) {
					sParams[ListFirst(param,"=")] = ListRest(param,"=");
				}
			} else {
				throw(message="parameters must be either a query string or a structure.");
			}

			sParams = isEncoded ? sParams : encodeQueryParams( sParams );

			// Sort parameters
			aParams = StructKeyArray( sParams );
			ArraySort( aParams, "text", "asc" );

			arrayEach( aParams, function(string param) {
				ArrayAppend( aResults, Arguments.param & "=" & sParams[ Arguments.param ] );
			});

			return ArrayToList(aResults, "&");
		}

		/**
		* Step 1: Task 1: Part 3: Canonical Headers.
		*/
		public string function __buildCanonicalHeaders(required struct sHeaders) {
			var aPairs = "";
			var aHeaders = "";
			// Scrub the header names and values first
			var sCleanHeaders = cleanHeaders( Arguments.sHeaders );


			// Sort header names in ASCII order
			aHeaders = StructKeyArray( sCleanHeaders );
			ArraySort( aHeaders, "text", "asc" );

			// Build array of sorted header name and value pairs
			aPairs = [];
			aHeaders.each(function(string key) {
				ArrayAppend( aPairs, arguments.key & ":" & sCleanHeaders[ arguments.key ] );
			});

			// Generate list. Note: List must END WITH a new line character
			return ArrayToList( aPairs, chr(10)) & chr(10);

		}

		/**
		* Step 1: Task 1: Part 4: Signed Headers.
		*/
		public string function __buildSignedHeaders(required struct sHeaders) {
			var aPairs = "";
			var aHeaders = "";
			// Scrub the header names and values first
			var sCleanHeaders = cleanHeaders( Arguments.sHeaders );


			// Sort header names in ASCII order
			aHeaders = StructKeyArray( sCleanHeaders );
			ArraySort( aHeaders, "text", "asc" );

			// Build array of sorted header name and value pairs
			aPairs = [];
			aHeaders.each(function(string key) {
				ArrayAppend( aPairs, arguments.key );
			});

			// Generate list.
			return ArrayToList( aPairs, ";");
		}
	
		/**
		* Step 1: Task 1: Part 4: Payload Hash.
		*/
		public string function __buildPayloadHash(string Payload="") {
			return hashy(Arguments.Payload);
		}
	
	/**
	* Step 1: Task 2
	*/
	public string function _createSigningString(
		required string ServiceName,
		required string Region,
		required string CanonicalRequestHash,
		date RequestDateTime="#now()#"
	) {
		var result = "";

		result = (
				""
			&	"AWS4-HMAC-SHA256" & chr(10)
			&	getStringToSignDateFormat(Arguments.RequestDateTime) & chr(10)
			&	"#DateFormat(Arguments.RequestDateTime,'yyyymmdd')#/#LCase(Arguments.Region)#/#LCase(Arguments.ServiceName)#/aws4_request" & chr(10)
			&	Arguments.CanonicalRequestHash
		);

		return result;
	}

	/**
	* Step 1: Task 3
	*/
	public string function _createSignature(
		required string StringToSign,
		required string SecretKey,
		required string Region,
		required string Service,
		date RequestDateTime="#now()#"
	) {
		var key = __buildSigningKey(ArgumentCollection=Arguments);

		return LCase( BinaryEncode( HMAC_SHA256_bin( Arguments.StringToSign, key), "hex") );
	}

		/**
		* Step 1: Task 3: Part 1
		*/
		public binary function __buildSigningKey(
			required string SecretKey,
			required string Region,
			required string Service,
			date RequestDateTime="#now()#"
		) {
			var DateStamp = DateFormat(Arguments.RequestDateTime,"yyyymmdd");
			/*
			var kSecret = charsetDecode("AWS4" & Arguments.SecretKey, "UTF-8");
			var kDate = hmacBinary( DateStamp, kSecret  );
			// Region information as a lowercase alphanumeric string
			var kRegion = hmacBinary( LCase(Arguments.Region), kDate  );
			// Service name information as a lowercase alphanumeric string
			var kService = hmacBinary( LCase(Arguments.Service), kRegion  );
			// A special termination string: aws4_request
			var kSigning = hmacBinary( "aws4_request", kService  );
			*/

			var kSecret        = JavaCast("string","AWS4" & Arguments.SecretKey).getBytes("UTF8");
			var kDate        = HMAC_SHA256_bin(DateStamp, kSecret);
			var kRegion        = HMAC_SHA256_bin(arguments.Region, kDate);
			var kService    = HMAC_SHA256_bin(arguments.Service, kRegion);
			var kSigning    = HMAC_SHA256_bin("aws4_request", kService);

			return kSigning;
		}

		/**
		* Step 1: Task 3: Part 1
		*/
		public string function __buildSigningKeyString(
			required string SecretKey,
			required string Region,
			required string Service,
			date RequestDateTime="#now()#"
		) {
			return BinaryEncode( __buildSigningKey(ArgumentCollection=Arguments), "hex" );
		}

			/**
			* I return a formatted date time for the string to sign section
			*/
			private string function getStringToSignDateFormat(required date date) {
				return "#Dateformat(Arguments.date, 'yyyymmdd')#T#TimeFormat(Arguments.date, 'HHmmss')#Z";
			}

			private string function hashy(string string="") {
				return LCase(Hash(Arguments.string, "SHA-256"));
			}

			/**
			 * Scrubs header names and values:
			 * <ul>
			 *    <li>Removes leading and trailing spaces from names and values</li>
			 *	  <li>Converts sequential spaces to single space in names and values</li>
			 *	  <li>Converts all header names to lower case</li>
			 * </ul>
			 * @headers Header names and values to scrub
			 * @returns structure of parsed header names and values
			 */
			private struct function cleanHeaders(required struct headers) {
				var key  = "";
				var sResult  = {};

				for ( key in Arguments.Headers ) {
					sResult[ LCase(TrimAll(key)) ] = TrimAll( Arguments.Headers[key] );
				}

				return sResult;
			}

			/**
			 * URL encode query parameters and names
			 * @params Structure containing all query parameters for the request
			 * @returns new structure with all parameter names and values encoded
			 */
			private struct function encodeQueryParams(required struct sParams) {
				// First encode parameter names and values
				var sResult = {};
				sParams.each( function(string key, string value) {
					sResult[ urlEncode(arguments.key) ] = urlEncode( arguments.value );
				});
				return sResult;
			}

			/**
			 * Convenience method which generates a (binary) HMAC code for the specified message
			 *
			 * @message Message to sign
			 * @key HMAC key in binary form
			 * @algorithm Signing algorithm. [ Default is "HMACSHA256" ]
			 * @encoding Character encoding of message string. [ Default is UTF-8 ]
			 * @returns HMAC value for the specified message as binary (currently unsupported in CF11)
			*/
			private binary function hmacBinary (
				required string message
				, required binary key
				, string algorithm = "HMACSHA256"
				, string encoding = "UTF-8"
			){
				// Generate HMAC and decode result into binary
				return binaryDecode( HMAC( Arguments.message, Arguments.key, Arguments.algorithm, Arguments.encoding), "hex" );
			}

			private string function TrimAll(required string str) {
				return ReReplace( Trim( Arguments.str ), "\s+", chr(32), "ALL" );
			}

			/**
			 * URL encodes the supplied string per RFC 3986, which defines the following as
			 * unreserved characters that should NOT be encoded:
			 *
			 * A-Z, a-z, 0-9, hyphen ( - ), underscore ( _ ), period ( . ), and tilde ( ~ ).
			 *
			 * @value string to encode
			 * @returns URI encoded string
			 */
			private string function urlEncode( string value ) {
				var result = encodeForURL(Arguments.value);
				// Reverse encoding of tilde "~"
				result = replace( result, encodeForURL("~"), "~", "all" );
				// Fix encoding of spaces, ie replace '+' into "%20"
				result = replace( result, "+", "%20", "all" );
				// Asterisk "*" should be encoded
				result = replace( result, "*", "%2A", "all" );

				return result;
			}

/*
https://gist.github.com/Leigh-/a2798584b79fd9072605a4cc7ff60df4
https://webdeveloperpadawan.blogspot.com/2013/07/amazon-aws-signature-version-4.html
*/
</cfscript>

</cfcomponent>
