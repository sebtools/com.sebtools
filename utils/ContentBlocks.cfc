<cfcomponent extends="com.sebtools.Records" output="no">
<cfscript>
Variables.prefix = "util"

public function init(
	required Manager,
	Settings
) {
	initInternal(ArgumentCollection=Arguments);
	
	Variables.sContentBocks = {};
	
	return This;
}

/**
* I add the given content block if it doesn't yet exist.
*/
public function addComponent(
	required ComponentRef,
	required string ComponentName
) {
	
	Arguments.ComponentRef["ContentBlocks"] = This;
	Arguments.ComponentRef["ContentBlocksCompName"] = Arguments.ComponentName;
	Arguments.ComponentRef["addContentBlock"] = addContentBlockThis;

}

public function addContentBlockThis() {

	Arguments["Component"] = This.ContentBlocksCompName;
	
	This.ContentBlocks.addContentBlock(ArgumentCollection=Arguments);

}

/**
* I add the given content block if it doesn't yet exist.
*/
public function addContentBlock() {
	var qCheck = 0;
	var sCheck = {};
	
	// Friendlier argument names
	if ( StructKeyExists(Arguments,"Name") AND NOT StructKeyExists(Arguments,"ContentBlockName") ) {
		Arguments.ContentBlockName = Arguments.Name;
		StructDelete(Arguments,"Name");
	}
	if ( StructKeyExists(Arguments,"Text") AND NOT StructKeyExists(Arguments,"ContentBlockText") ) {
		Arguments.ContentBlockText = Arguments.Text;
		StructDelete(Arguments,"Text");
	}
	if ( StructKeyExists(Arguments,"html") AND NOT StructKeyExists(Arguments,"isHTML") AND isBoolean(Arguments.html) ) {
		Arguments.isHTML = Arguments.html;
		StructDelete(Arguments,"html");
	}
	
	if ( StructKeyExists(Arguments,"Component") ) {
		qCheck = getContentBlocks(ContentBlockName=Arguments.ContentBlockName,ExcludeComponent=Arguments.Component,fieldlist="ContentBlockID,Component");
		
		if ( qCheck.RecordCount AND Len(Variables.Manager.DataMgr.getDatasource()) ) {
			throwError(Message="A content block of this name is already being used by another component (""#qCheck.Component#"").",ErrorCode="NameConflict");
		}
	}
	
	/*
	Only take action if this doesn't already exists for this component.
	(we don't want to update because the admin may have change the text from the default)
	*/
	sCheck["ContentBlockName"] = Arguments.ContentBlockName;
	if ( StructKeyExists(Arguments,"Component") ) {
		sCheck["Component"] = Arguments.Component;
	}
	if ( NOT hasContentBlocks(ArgumentCollection=sCheck) ) {
		Variables.sContentBocks[Arguments.ContentBlockName] = Arguments;

		saveContentBlock(ArgumentCollection=arguments);
	}
	
}

/**
* I get the HTML for the requested content block.
*/
public string function getContentBlockHTML(
	required string ContentBlockName,
	struct data
) {
	var qContentBlock = 0;
	var result = "";
	
	if ( Len(Variables.Manager.DataMgr.getDatasource()) ) {
		qContentBlock = getContentBlocks(ContentBlockName=Arguments.ContentBlockName,fieldlist="ContentBlockID,isHTML,ContentBlockText");
		
		if ( qContentBlock.RecordCount ) {
			result = qContentBlock.ContentBlockText;
			if ( NOT ( qContentBlock.isHTML IS true ) ) {
				result = ParagraphFormatFull(result);
			}
		}
	} else if ( StructKeyExists(Variables.sContentBocks,Arguments.ContentBlockName) ) {
		result = Variables.sContentBocks[Arguments.ContentBlockName].ContentBlockText;
		if (
			NOT (
				StructKeyExists(Variables.sContentBocks[Arguments.ContentBlockName],"isHTML")
				AND
				Variables.sContentBocks[Arguments.ContentBlockName].isHTML IS true
			)
		) {
			result = ParagraphFormatFull(result);
		}
	}

	if ( NOT StructKeyExists(Arguments,"data") ) {
		Arguments.data = {};
	}
	
	result = populate(result,Arguments.data);
	
	return result;
}

/**
* I get the ID for the requested content block.
*/
public string function getContentBlockID(required string ContentBlockName) {
	var qContentBlock = getContentBlocks(ContentBlockName=Arguments.ContentBlockName,fieldlist="ContentBlockID");
	var result = 0;
	
	if ( qContentBlock.RecordCount ) {
		result = qContentBlock.ContentBlockID;
	}
	
	return result;
}

/**
* I get the TEXT for the requested content block.
*/
public string function getContentBlockText(
	required string ContentBlockName,
	struct data
) {
	var qContentBlock = 0;
	var result = "";
	
	if ( Len(Variables.Manager.DataMgr.getDatasource()) ) {
		qContentBlock = getContentBlocks(ContentBlockName=Arguments.ContentBlockName,fieldlist="ContentBlockID,isHTML,ContentBlockText");
		if ( qContentBlock.RecordCount ) {
			result = qContentBlock.ContentBlockText;
			if ( qContentBlock.isHTML IS true ) {
				result = HTMLEditFormat(result);
			}
		}
	} else if ( StructKeyExists(Variables.sContentBocks,Arguments.ContentBlockName) ) {
		result = Variables.sContentBocks[Arguments.ContentBlockName].ContentBlockText;
		if (
			StructKeyExists(Variables.sContentBocks[Arguments.ContentBlockName],"isHTML")
			AND
			Variables.sContentBocks[Arguments.ContentBlockName].isHTML IS true
		) {
			result = ParagraphFormatFull(result);
		}
	}
	
	if ( NOT StructKeyExists(Arguments,"data") ) {
		Arguments.data = {};
	}
	
	result = populate(result,Arguments.data);
	
	return result;
}

public array function getFieldsArray() {
	var qContentBlocks = 0;
	var sContentBlock = 0;
	var sResult = 0;
	var aResults = 0;
	
	if (
		StructKeyExists(Arguments,"ContentBlockID")
		AND
		Len(Arguments.ContentBlockID)
		AND
		NOT isNumeric(Arguments.ContentBlockID)
	) {
		qContentBlocks = getContentBlocks(
			ContentBlockNames=Arguments.ContentBlockID,
			fieldlist="ContentBlockID,ContentBlockName,isHTML,ContentBlockText"
		);
		aResults = [];
		
		for ( sContentBlock in qContentBlocks ) {
			sResult = {};
			sResult["name"] = sContentBlock["ContentBlockID"];
			if ( isHTML IS true ) {
				sResult["type"] = "FCKeditor";
			} else {
				sResult["type"] = "textarea";
			}
			sResult["label"] = sContentBlock["ContentBlockName"];
			sResult["defaultValue"] = sContentBlock["ContentBlockText"];
			ArrayAppend(aResults,sResult);
		}

		return aResults;
	} else {
		return Super.getFieldsArray(ArgumentCollection=Arguments);
	}
}

public struct function getFieldsStruct() {
	var sFields = {};
	var aFields = 0;
	var sField = 0;
	
	aFields = getFieldsArray(ArgumentCollection=Arguments);
	
	for ( sField in aFields ) {
		if ( StructKeyExists(sField,"name") ) {
			sFields[sField["name"]] = sField;
		}
	}
	
	return sFields;
}

/**
* I populate the values within the string from the given structure (and from Settings, if available).
*/
public function populate(
	required string string,
	struct data
) {
	var result = Arguments.string;
	var key = "";

	if ( Len(Trim(result)) ) {
		if (
			StructKeyExists(Arguments,"data")
			AND
			StructCount(Arguments.data)
			AND
			ReFindNoCase("\[.*\]",result)
		) {
			for ( key in Arguments.data ) {
				if ( StructKeyExists(Arguments.data,key) AND isSimpleValue(Arguments.data[key]) ) {
					result = ReplaceNoCase(result,"[#key#]",Arguments.data[key]);
				}
			}
		}

		if (
			Len(result)
			AND
			StructKeyExists(Variables,"Settings")
			AND
			StructKeyExists(Variables.Settings,"populate")
		) {
			result = Variables.Settings.populate(result);
		}
	}
	
	return result;
}

public string function saveContentBlock() {
	var qContentBlocks = 0;
	var sContentBlock = 0;
	
	if ( isMultiEdit(ArgumentCollection=Arguments) ) {
		qContentBlocks = getContentBlocks(fieldlist="ContentBlockID");
		for ( sContentBlock in qContentBlocks ) {
			if ( StructKeyExists(Arguments,"a#sContentBlock['ContentBlockID']#") ) {
				saveRecord(
					ContentBlockID=sContentBlock['ContentBlockID'],
					ContentBlockText=Arguments["a#sContentBlock['ContentBlockID']#"]
				);
			}
		}
	} else {
		return saveRecord(ArgumentCollection=Arguments);
	}

}

public struct function validateContentBlock() {

	Arguments = validateBrief(ArgumentCollection=Arguments);

	return Arguments;
}

private boolean function isMultiEdit() {
	var qContentBlocks = getContentBlocks(fieldlist="ContentBlockID");
	var sContentBlock = 0;
	var result = false;
	
	for ( sContentBlock in qContentBlocks ) {
		if ( StructKeyExists(Arguments,"a#sContentBlock['ContentBlockID']#") ) {
			return true;
		}
	}
	
	return false;
}

private struct function validateBrief() {

	if ( StructKeyExists(Arguments,"ContentBlockText") ) {
		Arguments.ContentBlockBrief = Abbreviate(Arguments.ContentBlockText,150);
	}
	
	return Arguments;
}

public string function Abbreviate(
	required string string,
	required string length
) {
	var result = Arguments.string;
	var addEllipses = false;
	
	// Remove all contentless tags at the front and end of the string
	result = ReReplaceNoCase(result,"^.*?>","");
	result = ReReplaceNoCase(result,"^(<.*?>\s*)*","");
	result = ReReplaceNoCase(result, "(</[^>]*>|\s)*$","");
	
	if ( FindNoCase("</p>",result,1) GT 1 ) {
		result = Left(result,FindNoCase("</p>",result,1)-1);
		addEllipses = true;
	}
	if ( FindNoCase("<br",result,1) GT 1 ) {
		result = Left(result,FindNoCase("<br",result,1)-1);
		addEllipses = true;
	}
	
	result = Left(result,Arguments.length+1);
	if ( Len(Trim(result)) GT Arguments.length ) {
		result = Left(result,Arguments.length-3);
		result = ReReplaceNoCase(result,"[^\s]*$","");
		addEllipses = true;
	}
	
	result = Trim(result);
	result = stripHTML(result);
	
	if ( addEllipses ) {
		result = "#Trim(result)#...";
		result = ReReplaceNoCase(result,"\.{4,}$","...");
	}
	
	return result;
}
</cfscript>

<cffunction name="xml" access="public" output="yes">
<tables prefix="#variables.prefix#">
	<table entity="Content Block" universal="true" Specials="CreationDate,LastUpdateDate">
		<field name="Component" label="Component" type="text" Langth="120" help="A unique identifier for the component or program using this content block." urlvar="component" />
		<field name="isHTML" label="HTML?" type="boolean" default="false" />
		<field name="ContentBlockText" label="Text" type="memo" />
		<field name="ContentBlockBrief" label="Brief" type="text" Length="150" />
		<filter name="ExcludeComponent" field="Component" operator="NEQ" />
	</table>
</tables>
</cffunction>
<cfscript>
/**
 * Removes HTML from the string.
 * v2 mod by Steve Bryant to find trailing, half done HTML.        
 * v4 mod by James Moberg - empties out script/style blocks
 * 
 * @param string      String to be modified. (Required)
 * @return Returns a string. 
 * @author Raymond Camden (ray@camdenfamily.com) 
 * @version 4, October 4, 2010 
 */
function stripHTML(str) {
	str = reReplaceNoCase(str, "<*style.*?>(.*?)</style>","","all");
	str = reReplaceNoCase(str, "<*script.*?>(.*?)</script>","","all");

	str = reReplaceNoCase(str, "<.*?>","","all");
	//get partial html in front
	str = reReplaceNoCase(str, "^.*?>","");
	//get partial html at end
	str = reReplaceNoCase(str, "<.*$","");
	return trim(str);
}

function ParagraphFormatFull(str) {
	//first make Windows style into Unix style
	str = replace(str,chr(13)&chr(10),chr(10),"ALL");
	//now make Macintosh style into Unix style
	str = replace(str,chr(13),chr(10),"ALL");
	//now fix tabs
	str = replace(str,chr(9),"&nbsp;&nbsp;&nbsp;","ALL");
	//now return the text formatted in HTML
	str = replace(str,chr(10),"<br />","ALL");

	str = replace(str,"<br /><br />","</p><p>","ALL");

	str = "<p>#str#</p>";

	return str;
}
</cfscript>
</cfcomponent>