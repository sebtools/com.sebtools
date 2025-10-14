<!---
<form file="">
	<field name="" required="" regex="" type="" message="" digitsonly="" filter="" />
</form>

Type
	name=""
	digitsonly = true/false
	regex = ""
	isBoolean = true/false
	isDate = true/false
	isNumeric = true/false
	isInteger = true/false
--->
<cfcomponent displayname="Scrubber">
<cfscript>
public function init() {
	
	Variables.Forms = {};
	Variables.ErrorMessages = {};
	Variables.Types = {};
	
	addType(name="phone",digitsonly=true,regex="^\d{10}$");
	addType(name="phoneext",digitsonly=true,regex="^\d{10}\d*$");
	addType(name="zipcode",digitsonly=true,regex="^((\d{5})|(\d{9}))$");
	addType(name="ssn",digitsonly=true,regex="^\d{9}$");
	addType(name="date",isDate=true);
	addType(name="boolean",isBoolean=true);
	addType(name="numeric",isNumeric=true);
	addType(name="integer",isInteger=true);
	//addType(name="email",regex="^(\w+\.)*\w+@(\w+\.)+[A-Za-z]+$");
	addType(name="email",regex="^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$");
	
	return This;
}

/**
* I add a form to Scrubber.
*/
public void function addForm(
	required string formfile,
	required struct fields
) {
	Variables.Forms[Arguments.formfile] = Arguments.fields;
}

/**
* I add a form to Scrubber using XML.
*/
public void function addFormXML(
	required string formfile,
	required struct fieldsXML
) {
	Variables.Forms[Arguments.formfile] = xmlForm(Arguments.fieldsXML);
}

/**
* I add a validation type to Scrubber.
*/
public void function addType(
	required string name,
	boolean digitsonly,
	string regex="",
	boolean isBoolean="false",
	boolean isDate="false"
	boolean isNumeric="false",
	boolean isInteger="false"
) {
	Variables.Types[Arguments.name] = Arguments;
}

/**
* I scrub a field.
*/
public string function scrubField(
	required string data,
	required struct checks
) {

	if ( Len(Arguments.data) ) {
	
		// Clear non-digits for digits only

		if ( StructKeyIsTrue(checks,"digitsonly") ) {
			Arguments.data = digitize(Arguments.data);
		}
	
		if ( StructKeyExists(checks,"type") AND Len(checks.type) ) {
			if ( StructKeyIsTrue(Variables.Types[checks.type],"digitsonly") ) {
				Arguments.data = digitize(Arguments.data);
			}
		}

	}
	
	return Arguments.data;
}

/*
* I check a field.
*/
public boolean function checkField(
	required string data,
	required struct checks
) {
	var isOK = true;
	var result = "";
	
	// Check required
	if ( StructKeyIsTrue(checks,"required") ) {
		if ( NOT Len(data) ) {
			isOK = false;
		}
	}
	
	if ( Len(data) ) {
		// Check type
		if ( StructKeyExists(checks,"type") AND Len(checks.type) ) {
			if ( NOT checkTests(data,variables.Types[checks.type]) ) {
				isOK = false;
			}
		}
	
		// Check particular tests for this field
		if ( NOT checkTests(data,checks) ) {
			isOK = false;
		}
	}

	return isOK;
}

public void function checkForm(
	required string formfile,
	required struct formdata,
	string sendto="#Arguments.formfile#",
	string urlvar
) {
	var errors = getFormErrors(Arguments.formfile,Arguments.formdata);
	
	if ( Len(errors) ) {
		// %%Need to change the way this works so no possibility of cflocation from cfc and no use of CGI
		if ( Right(CGI.SCRIPT_NAME,3) eq "cfc" ) {
			throw(
				message="Form has missing/invalid data. (#errors#)",
				type="MethodErr",
				detail="#errors#",
				errorcode="invalidfields",
				extendedinfo="#errors#"
			);
		} else {
			if ( StructKeyExists(Arguments,"urlvar") ) {
				sendErrFields(Arguments.sendto,errors,Arguments.urlvar);
			} else {
				sendErrFields(Arguments.sendto,errors);
			}
		}
	}

}

/*
* I check the given form.
*/
public string function getFormErrors(
	required string formfile,
	required struct formdata
) {
	var data = Arguments.formdata;
	var thisFieldName = "";
	var thisField = 0;
	var arrErrors = [];
	var thisError = "";
	var isValidField = true;
	
	// Make sure Scrubber is aware of form
	if ( NOT StructKeyExists(Variables.Forms,arguments.formfile) ) {
		throw(
			message="In order to use Scrubber with a form, Scrubber must be aware of that form. If you feel that you got this message in error, please return to the form and try again.",
			type="MethodErr",
			errorcode="ScrubberNeedsForm"
		);
	}
	
	for ( thisFieldName in Variables.Forms[Arguments.formfile] ) {
		thisField = Variables.Forms[arguments.formfile][thisFieldName];
		isValidField = true;
		
		if ( StructKeyExists(data,thisFieldName) ) {
			isValidField = checkField(data[thisFieldName],thisField);
		} else if ( StructKeyIsTrue(thisField,"required") ) {
			isValidField = false;
		}
		
		if ( NOT isValidField ) {
			ArrayAppend(arrErrors,thisFieldName);
		}
	}
	
	return ArrayToList(arrErrors);
}

/*
* I check to see if the given data passes the given tests.
*/
private boolean function checkTests(
	required string data,
	required struct checks
) {
	var isOK = true;
	
	// Clear non-digits for digits only
	if ( StructKeyIsTrue(checks,"digitsonly") ) {
		Arguments.data = digitize(Arguments.data);
	}
	
	// Check regex
	if ( StructKeyExists(checks,"regex") AND Len(checks.regex) AND NOT ReFindNoCase(checks.regex, Arguments.data) ) {
		isOK = false;
	}
	
	// check isBoolean
	if ( StructKeyIsTrue(checks,"isBoolean") AND NOT isBoolean(Arguments.data) ) {
		isOK = false;
	}
	
	// check isDate
	if ( StructKeyIsTrue(checks,"isDate") AND NOT isDate(Arguments.data) ) {
		isOK = false;
	}
	
	// check isNumeric
	if ( StructKeyIsTrue(checks,"isNumeric") AND NOT isNumeric(Arguments.data) ) {
		isOK = false;
	}
	
	// check isInteger
	if ( StructKeyIsTrue(checks,"isinteger") AND NOT  ( isNumeric(Arguments.data) AND Int(Arguments.data) EQ Arguments.data ) ) {
		isOK = false;
	}
	
	return isOK;
}

public struct function getForms() {
	return variables.Forms;
}

/**
* I get a list of all validation types for this Scrubber.
*/
public string function getTypeList() {
	var result = "";
	var thisType = "";
	
	for ( thisType in Variables.Types ) {
		result = ListAppend(result,thisType);
	}

	return result;	
}

/**
* I get the validation types for this Scrubber.
*/
public struct function getTypes() {
	return Variables.Types;
}

public void function sendErrFields() {
	var page = sendto;
	
	if ( FindNoCase("?",page) ) {
		page &= "&";
	} else {
		page &= "?";
	}
	page &= "#urlvar#=#errFields#";
	
	location(page, "false");

}

public string function startFormHtml(
	required string formfile,
	required string fieldsXML,
	string errMessage="This form has errors.",
	string urlvar="errFields",
	string errClass="err"
) {
	var result = "";
	
	if ( NOT StructKeyExists(Variables.Forms,Arguments.formfile) ) {
		addFormXML(Arguments.formfile,Arguments.fieldsXML);
	}
	
	result = showErrorHtml(formfile,errMessage,urlvar,errClass);
	
	return result;
}

public string function showErrorHtml(
	required string formfile,
	string errMessage="This form has errors.",
	string urlvar="errFields",
	string errClass="err"
) {
	var result = "";
	
	if ( StructKeyExists(URL,Arguments.urlvar) AND Len(URL[Arguments.urlvar]) ) {
		result = '<p class="#errClass#">#Arguments.errMessage#</p>';
	}
	
	return result;
}

/**
* I return the numeric digits of the given string.
*/
private string function digitize(required string data) {
	var result = "";
	var ii = 0;
	var digit = "";
	
	for ( ii=1; ii LTE Len(data); ii++ ) {
		digit = Mid(data,ii,1);
		if ( isNumeric(digit) ) {
			result = result & digit;
		}
	}

	return result;
}

/**
* I check to see if the given key in the given structure exists and is true.
*/
private boolean function StructKeyIsTrue(
	required struct struct,
	required string key
) {
	return ( StructKeyExists(struct,key) AND struct[key] IS true );
}

/**
* I convert the given XML to the appropriate CFML structure.
*/
private struct function xmlForm(required string myXML) {
	var ii = 1;
	var result = {};
	var fieldname = "";
	var atts = 0;
	
	for ( ii=1; ii LTE ArrayLen(myXML.xmlRoot.XmlChildren); ii++  ) {
		atts = myXML.xmlRoot.XmlChildren[ii].XmlAttributes;
		fieldname = atts.name;
		result[fieldname] = {};
		result[fieldname].required = StructKeyIsTrue(atts,"required");
		result[fieldname].digitsonly = StructKeyIsTrue(atts,"digitsonly");
		if ( StructKeyExists(atts,"regex") ) {
			result[fieldname].regex = atts.regex;
		} else {
			result[fieldname].regex = "";
		}
		if ( StructKeyExists(atts,"type") ) {
			result[fieldname].type = atts.type;
		} else {
			result[fieldname].type = "";
		}
		if ( StructKeyExists(atts,"message") ) {
			result[fieldname].message = atts.message;
		} else {
			result[fieldname].message = "";
		}
		if ( StructKeyExists(atts,"filter") ) {
			result[fieldname].filter = atts.filter;
		} else {
			result[fieldname].filter = "";
		}
		result[fieldname].isBoolean = StructKeyIsTrue(atts,"isBoolean");
		result[fieldname].isDate = StructKeyIsTrue(atts,"isDate");
		result[fieldname].isNumeric = StructKeyIsTrue(atts,"isNumeric");
		result[fieldname].isInteger = StructKeyIsTrue(atts,"isInteger");
	}
	return result;
}
</cfscript>
</cfcomponent>