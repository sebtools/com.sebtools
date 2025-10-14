<!--- Created by Steve Bryant 2007-01-26 --->
<cfcomponent displayname="PhoneFormatter" hint="I ensure that phone numbers are in the correct format.">
<cfscript>
/*
* I initialize and return this component.
*/
public function init(
	required DataMgr,
	required Format,
	string DefaultAreaCode="000"
) {

	Variables.DataMgr = Arguments.DataMgr;
	Variables.Format = Arguments.Format;
	Variables.DefaultAreaCode = Arguments.DefaultAreaCode;

	if ( Len(variables.DefaultAreaCode) NEQ 3 ) {
		Variables.DefaultAreaCode = "000";
	}

	Variables.phonechars = "()- ext./\";
	Variables.badchars = getBadChars();
	Variables.goodchars = getGoodChars();

	Variables.datasource = variables.DataMgr.getDatasource();

	return This;
}

/*
* I return the given phone number in the correct format.
* @phonenum The phone number to be formatted.
* @areacodeThe area code to use if none is present.
*/
public string function fixPhoneNumber(
	required string phonenum,
	string areacode="#variables.DefaultAreaCode#"
) {
	var digits = ReReplace(ListFirst(Arguments.phonenum,"x"),"[^[:digit:]]","","all");
	var result = "";

	if ( Len(Arguments.areacode) NEQ 3 ) {
		Arguments.areacode = Variables.DefaultAreaCode;
	}

	if ( Len(digits) ) {
		if ( Len(digits) EQ 7 OR ( Len(digits) GT 7 AND Len(digits) LT 10 ) ) {
			result = PhoneFormat("#Arguments.areacode##Arguments.phonenum#",Variables.Format);
		} else { 
			result = PhoneFormat(Arguments.phonenum,Variables.Format);
		}
	}

	return result;
}

/*
* I fix all of the phone numbers in the given field of the given table.
* @table The table to correct
* @phonefield The field holding the phone number (must not have other information).
* @pkfields The primary key field of the table (must be exactly one to work).
*/
public void function fixPhoneNumbers(
	required string table,
	required string phonefield,
	required string pkfields
) {
	var qPhoneNumbers = getProblemNumbers(Arguments.table,Arguments.pkfields,Arguments.phonefield);
	var pkfield = "";
	var data = 0;
	var sPhone = 0;

	for ( sPhone in qPhoneNumbers ) {
		if ( sPhone.PhoneNumber NEQ sPhone.PhoneNumber_Formatted ) {
			data = {};
			for ( pkfield in ListToArray(Arguments.pkfields) ) {
				data[pkfield] = sPhone[pkfield];
			}
			data[Arguments.phonefield] = sPhone.PhoneNumber_Formatted;

			Variables.DataMgr.updateRecord(Arguments.table,data);
		}
	}

}
</cfscript>

<cffunction name="getProblemNumbers" access="public" returntype="query" output="no" hint="I get all of the phone numbers from the given table that are not formatted correctly (as well as the correct formatting for that phone number).">
	<cfargument name="table" type="string" required="yes" hint="The table to correct">
	<cfargument name="idfield" type="string" required="yes" hint="The primary key field of the table (must be exactly one to work).">
	<cfargument name="phonefield" type="string" required="yes" hint="The field holding the phone number (must not have other information).">

	<cfset var sqlTable = variables.DataMgr.escape(arguments.table)>
	<cfset var sqlIdField = variables.DataMgr.escape(arguments.idfield)>
	<cfset var sqlPhoneField = variables.DataMgr.escape(arguments.phonefield)>
	<cfset var qPhoneNumbers = QueryNew("ID,PhoneNumber,PhoneNumber_Formatted")>
	<cfset var thisChar = "">

	<cftry>
		<cfquery name="qPhoneNumbers" datasource="#variables.datasource#">
		SELECT	#sqlIdField# AS ID, #sqlPhoneField# AS PhoneNumber, '' AS PhoneNumber_Formatted
				<cfif sqlIdField NEQ "ID">
					, #sqlIdField#
				</cfif>
		FROM	#sqlTable#
		WHERE	(
						#sqlPhoneField# IS NOT NULL
					AND	#sqlPhoneField# <> ''
				)
			AND	(
						1 = 0
				<cfloop index="thisChar" list="#variables.badchars#">
					OR	#sqlPhoneField# LIKE '%#thisChar#%'
				</cfloop>
				<cfloop index="thisChar" list="#variables.goodchars#">
					OR	NOT #sqlPhoneField# LIKE '%#thisChar#%'
				</cfloop>
				)
		</cfquery>

		<cfloop query="qPhoneNumbers">
			<cfset QuerySetCell(qPhoneNumbers, "PhoneNumber_Formatted", fixPhoneNumber(PhoneNumber), CurrentRow)>
		</cfloop>
	<cfcatch>
	</cfcatch>
	</cftry>

	<cfreturn qPhoneNumbers>
</cffunction>

<cfscript>
/*
* I return a list of all of the unacceptable characters for phone numbers.
*/
private string function getBadChars(
	string Format="#Variables.Format#"
) {
	var ii = 0;
	var thischar = "";
	var result = "";

	// Loop through all phone characters
	for ( ii=1; ii LTE Len(variables.phonechars); ii++ ) {
		// Get the character
		thisChar = Mid(variables.phonechars,ii,1);
		// If the character isn't in the format, add it to the list of unacceptable characters
		if ( NOT FindNoCase(thisChar, arguments.Format) ) {
			result = ListAppend(result,thisChar);
		}
	}

	return result;
}

/*
* I return a list of all of the acceptable non-numeric characters for phone numbers.
*/
private string function getGoodChars(
	string Format="#Variables.Format#"
) {
	var ii = 0;
	var thischar = "";
	var result = "";

	// Loop through the format
	for ( ii=1; ii LTE Len(Arguments.Format); ii++ ) {
		// Get the character
		thisChar = Mid(arguments.Format,ii,1);
		// If the character isn't numeric and isn't already in the list of good characters, add it to the list
		if ( NOT isNumeric(thisChar) AND NOT ListFindNoCase(result,thisChar) ) {
			result = ListAppend(result,thisChar);
		}
	}

	return result;
}

function ParsePhoneNumber(Phone) {
	var Phone_Orig = Phone;
	var sPhone = {};

	Phone = ListFirst(Phone,"x");
	Phone = REReplaceNoCase(Phone, "[^\d]", "","ALL");
	if ( Len(Phone) GT 10 AND ( Left(Phone,1) EQ "1" OR Left(Phone,1) EQ "0" ) ) {
		Phone = Right(Phone,Len(Phone)-1);
	}
	if ( Len(Phone) GT 10 ) {
		Phone = Left(Phone,10);
	}

	sPhone["area_code"] = Left(Phone,3);
	sPhone["prefix"] = Mid(Phone,4,3);
	sPhone["line_number"] = Right(Phone,4);

	if ( ListLen(Phone_Orig,"x") EQ 2 ) {
		sPhone["extension"] = REReplaceNoCase(ListLast(Phone_Orig,"x"), "[^\d]", "","ALL");
	}

	return sPhone;
}
function PhoneFormat (input, mask) {
	var curPosition = "";
	var newFormat = "";
	var ii = 0;//counter
	var area = "   ";
	var numsonly = reReplace(input,"[^[:digit:]]","","all");//numbers extraced from input
	var digits = 0;//number of digits in mask

	//If third argument is passed in, set srea code to value of third argument
	if ( ArrayLen(arguments) gt 2 ) {
		area = arguments[3];
	}

	if ( Len(numsonly) GT 10 ) {
		mask = mask & "x";
	}

	//count number of numbers
	for (ii=1; ii lte len(trim(mask)); ii=ii+1) {
		curPosition = mid(mask,ii,1);
		if ( isNumeric(curPosition) ) {
			digits = digits + 1;
		}
	}
	//prepend three numbers to mask if it has less than 10 digits (they will be ditched out later anyway)
	if ( digits lt 10 ) {
		mask = "000" & mask;
	}

	newFormat = " " & numsonly;//new format is numbers stripped from input prepended with a space

	if ( Len(newFormat) lt 10 ) {
		newFormat = " #area##trim(newFormat)#";
	}

	while ( Len(newFormat) LT 10 ) {
		newFormat = "0#trim(newFormat)#";
	}

	newFormat = " #trim(newFormat)#";

	//Loop through mask and replace digits with numbers from input
	for (ii=1; ii lte len(trim(mask)); ii=ii+1) {
		curPosition = mid(mask,ii,1);
		if( NOT isNumeric(curPosition) ) newFormat = insert(curPosition,newFormat, ii) & " ";
	}

	//If this is a 7-digit number (no area code passed or in input), start with a number
	if ( NOT Len(Trim(area)) AND Len(numsonly) lt 10 AND Len(newFormat) ) {
		while ( NOT isNumeric(Left(newFormat,1)) ) {
			if ( Len(newFormat) gt 1 ) {
				newFormat = Right(newFormat,Len(newFormat)-1);
			}  else {
				newFormat = "";
				break;
			}
		}
	}

	return Trim(newFormat);
}
</cfscript>
</cfcomponent>
