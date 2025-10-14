<cfcomponent extends="com.sebtools.Records" output="no">
<cfscript>
Variables.prefix = "util";
Variables.types = "boolean,date,email,float,guid,integer,text,url";

public function init(
	required Manager,
	DataLogger
) {
	
	initInternal(ArgumentCollection=Arguments);

	if ( StructKeyExists(Variables,"DataLogger") ) {
		Variables.DataLogger.logTables("#variables.prefix#Settings");
	}

	resetCache();

	return This;
}

/**
* I find a list of all valid settings within the given string.
* @return Possible Values: id,name,query
*/
public function FindSettings(
	required string string,
	string returnvar="name"
) {
	var qSettings = 0;
	var result = "";
	var sSetting = 0;

	if ( StructKeyHasLen(Arguments,"returnvar") AND NOT StructKeyHasLen(Arguments,"returnvar") ) {
		Arguments["return"] = Arguments["returnvar"];
	}
	
	if ( ReFindNoCase("\[.*\]",Arguments.string) ) {
		qSettings = getSettings(fieldlist="SettingID,SettingName");
		for ( sSetting in qSettings ) {
			if ( FindNoCase("[#sSetting.SettingName#]",Arguments.string) ) {
				if ( Arguments.return EQ "name" ) {
					result = ListAppend(result,sSetting.SettingName);
				} else {
					result = ListAppend(result,sSetting.SettingID);
				}
			}
		}

		if ( Arguments.return EQ "query" ) {
			result = getSettings(Settings=result,fieldlist="SettingID,SettingName,SettingLabel,type,ValueText,Help");
		}

	} else if ( Arguments.return EQ "query" ) {
		result = QueryNew("SettingID,SettingName,SettingLabel,type,ValueText,Help");
	}

	return result;
}

/**
* I populate the values of any valid settings within the given string.
*/
public function populate(required string string) {
	var qSettings = 0;
	var sSetting = 0;
	var result = Arguments.string;

	if ( ReFindNoCase("\[.*\]",result) ) {
		qSettings = getSettings();
		for ( sSetting in qSettings ) {
			result = ReplaceNoCase(result,"[#sSetting.SettingName#]",sSetting[getValueField(sSetting.type)]);
		}
	}

	return result;
}

/**
* I add the given setting if it doesn't yet exist.
*/
public function addSetting() {
	var qCheck = getSettings(SettingName=Arguments.SettingName,ExcludeComponent=Arguments.Component,fieldlist="SettingID,Component");

	if ( qCheck.RecordCount ) {
		throwError(Message="A setting of this name is already being used by another component (""#qCheck.Component#"").",ErrorCode="NameConflict");
	}

	/*
	Only take action if this doesn't already exists for this component.
	(we don't want to update because the admin may have change the notice from the default settings)
	*/
	if ( NOT hasSettings(SettingName=Arguments.SettingName,Component=Arguments.Component) ) {
		if ( NOT StructKeyExists(Arguments,"type") ) {
			Arguments.type = "text";
		}
		if ( NOT StructKeyExists(Arguments,"SettingLabel") ) {
			Arguments.SettingLabel = Arguments.SettingName;
		}
		saveSetting(ArgumentCollection=Arguments);
	}

}
public array function getFieldsArray() {
	var qSettings = 0;
	var sSetting = 0;
	var sResult = 0;
	var aResults = 0;
	
	if ( StructKeyHasLen(Arguments,"SettingID") AND NOT isNumeric(Arguments.SettingID) ) {
		qSettings = getSettings(SettingNames=Arguments.SettingID,fieldlist="SettingID,SettingName,SettingLabel,type,ValueText,Help");
	}

	if ( StructKeyHasLen(Arguments,"Settings") ) {
		qSettings = getSettings(Settings=Arguments.Settings,fieldlist="SettingID,SettingName,SettingLabel,type,ValueText,Help");
	}

	if ( StructKeyHasLen(Arguments,"string") ) {
		qSettings = FindSettings(Arguments.string,"query");
	}

	if ( StructKeyExists(Arguments,"query") AND isQuery(Arguments.query) ) {
		qSettings = getSettings(Settings=Arguments.SettingID,fieldlist="SettingID,SettingName,SettingLabel,type,ValueText,Help");
	}

	if ( isQuery(qSettings) ) {
		aResults = [];

		for ( sSetting in qSettings ) {
			sResult = {};
			sResult["name"] = sSetting.SettingName;
			sResult["type"] = sSetting.type;
			sResult["label"] = sSetting.SettingLabel;
			sResult["defaultValue"] = sSetting.ValueText;
			if ( Len(sSetting.ValueText) ) {
				sResult["size"] = Len(sSetting.ValueText) + 2;
			}
			if ( Len(sSetting.Help) ) {
				sResult["Help"] = sSetting.Help;
			}
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
* I get the ID for the requested setting.
*/
public string function getSettingID(required string SettingName) {
	var qSetting = getSettings(SettingName=Arguments.SettingName,fieldlist="SettingID");
	var result = 0;

	if ( qSetting.RecordCount ) {
		result = qSetting.SettingID;
	}

	return result;
}

/**
* I get the value for the requested setting.
*/
public function getSettingValue(required string SettingName) {
	var qSetting = 0;
	var field = "";
	var result = "";

	if ( NOT StructKeyExists(Variables.sSettings,Arguments.SettingName) ) {
		qSetting = getSettings(SettingName=Arguments.SettingName,fieldlist="SettingID,type,ValueText,ValueInteger,ValueFloat,ValueDate,ValueBoolean");

		if ( qSetting.RecordCount ) {
			field = getValueField(qSetting.type);
			Variables.sSettings[Arguments.SettingName] = qSetting[field][1];
		}
	}

	if ( StructKeyExists(Variables.sSettings,Arguments.SettingName) ) {
		result = Variables.sSettings[Arguments.SettingName];
	}

	return result;
}

/**
* I get the name of the field that will hold the value for the given type.
*/
public string function getValueField(required string type) {
	var result = ""

	switch ( Arguments.type ) {
		case "boolean":
				result = "ValueBoolean";
			break;
		case "date":
				result = "ValueDate";
			break;
		case "float":
				result = "ValueFloat";
			break;
		case "integer":
				result = "ValueInteger";
			break;
		default:
				result = "ValueText";
	}

	return result;
}

public function saveSetting() {
	var result = 0;

	if ( isMultiEdit(ArgumentCollection=Arguments) ) {
		saveSettings(ArgumentCollection=Arguments);
	} else {
		result = saveRecord(ArgumentCollection=Arguments);
		resetCache();
	}

	return result;
}

public void function saveSettings() {
	var qSettings = getSettings(fieldlist="SettingID,SettingName");
	var sSetting = 0;

	for ( sSetting in qSettings ) {
		if ( StructKeyExists(Arguments,"#qSettings['SettingName'][CurrentRow]#") ) {
			saveRecord(SettingID=qSettings['SettingID'][CurrentRow],Value=Arguments["#qSettings['SettingName'][CurrentRow]#"]);
		}
	}

	resetCache();

}

public struct function validateSetting() {
	
	Arguments = validateSettingID(ArgumentCollection=Arguments);
	Arguments = validateSettingType(ArgumentCollection=Arguments);
	Arguments = validateSettingValue(ArgumentCollection=Arguments);

	return Arguments;
}

private struct function validateSettingID() {
	var id = 0;

	//If a SettingName is passed in without a SettingID, try to determine the SettingID and put it in Arguments.
	if ( StructKeyHasLen(Arguments,"SettingName") AND NOT StructKeyHasVal(Arguments,"SettingID") ) {
		id = getSettingID(Arguments["SettingName"]);
		if ( Val(id) ) {
			Arguments["SettingID"] = id;
		}
	}

	return Arguments;
}

private struct function validateSettingType() {
	var oSetting = 0;

	if ( StructKeyExists(Arguments,"type") ) {
		if ( isUpdate(ArgumentCollection=Arguments) ) {
			StructDelete(Arguments,"type");
			oSetting = RecordObject(Record=Arguments,fields="type");
			Arguments.type = oSetting.get("type");
		} else {
			if ( NOT ListFindNoCase(variables.types,Arguments.type) ) {
				throwError("#Arguments.type# is not a valid type. Valid types are: #variables.types#.");
			}
		}
	}

	return Arguments;
}

private struct function validateSettingValue() {
	var oSetting = RecordObject(Record=Arguments,fields="type");

	if ( StructKeyExists(Arguments,"SettingValue") ) {
		Arguments.Value = Arguments.SettingValue;
		StructDelete(Arguments,"SettingValue");
	}

	if ( StructKeyExists(Arguments,"ValueText") AND NOT StructKeyExists(Arguments,"Value") ) {
		Arguments.Value = Arguments.ValueText;
	}

	if ( StructKeyExists(Arguments,"Value") ) {
		switch ( oSetting.get('type') ) {
			case "boolean":
					Arguments.ValueBoolean = Arguments.Value;
					Arguments.ValueText = YesNoFormat(Arguments.Value);
				break;
			case "date":
					Arguments.ValueDate = Arguments.Value;
					Arguments.ValueText = DateFormat(Arguments.Value);
				break;
			case "float":
					Arguments.ValueFloat = Arguments.Value;
					Arguments.ValueText = NumberFormat(Arguments.Value);
				break;
			case "integer":
					Arguments.ValueInteger = Arguments.Value;
					Arguments.ValueText = NumberFormat(Arguments.Value);
				break;
			default:
					Arguments.ValueText = Arguments.Value;
		}
	}

	return Arguments;
}

private boolean function isMultiEdit() {
	var qSettings = getSettings(fieldlist="SettingID,SettingName");
	var sSetting = 0;
	var result = false;

	for ( sSetting in qSettings ) {
		if ( StructKeyExists(Arguments,sSetting["SettingName"]) ) {
			return true;
		}
	}

	return false;
}

private function resetCache() {
	Variables.sSettings = {};
}
</cfscript>

<cffunction name="xml" access="public" output="yes">
<tables prefix="#variables.prefix#">
	<table entity="Setting" universal="true" Specials="CreationDate,LastUpdateDate">
		<field name="Component" label="Component" type="text" Langth="120" help="A unique identifier for the component or program using this setting" />
		<field name="type" label="type" type="text" Length="250" sebcolumn="false" default="text" />
		<field name="SettingLabel" label="Label" type="text" Length="250" />
		<field name="Help" label="Label" type="text" Length="250" />
		<field name="ValueText" label="Text Value" type="text" Length="250" />
		<field name="ValueInteger" label="Integer Value" type="integer" />
		<field name="ValueFloat" label="Float Value" type="float" />
		<field name="ValueDate" label="Date Value" type="date" />
		<field name="ValueBoolean" label="Boolean Value" type="boolean" />
		<filter name="ExcludeComponent" field="Component" operator="NEQ" />
	</table>
</tables>
</cffunction>

</cfcomponent>
