<!--- 1.0 Beta 3 (Build 35) --->
<!--- Last Updated: 2011-11-23 --->
<!--- Created by Steve Bryant 2007-09-13 --->
<!--- Information: http://www.bryantwebconsulting.com/docs/com-sebtools/records.cfm?version=Build%2012 --->
<cfcomponent output="false" extends="component">
<cfscript>
Variables.sSpecifyingValues = {};
Variables.OnExists = "save";

public function init(required Manager) {

	initInternal(ArgumentCollection=Arguments);

	return This;
}

private function initInternal(required Manager) {
	var key = "";
	var loc = {};

	StructAppend(Variables,Arguments);

	// Get all components from Manager
	for ( key in Variables.Manager ) {
		if ( isObject(Variables.Manager[key]) ) {
			Variables[key] = Variables.Manager[key];
		}
	}

	// Get all components from arguments
	for ( key in Arguments ) {
		if ( isObject(Arguments[key]) ) {
			Variables[key] = Arguments[key];
			This[key] = Arguments[key];
		}
	}

	loc.metaXml = getMethodOutputValue(Variables,"xml");

	if ( NOT StructKeyExists(loc,"metaXml") ) {
		throw(type="Records",message="Your xml method must return the XML that it creates.");
	}
	if ( Len(loc.metaXml) ) {
		Variables.xDef = Variables.Manager.loadXml(loc.metaXml);
	}

	Variables.sMetaData = Variables.Manager.getMetaStruct();
	Variables.cachedata = {};
	Variables.datasource = Variables.DataMgr.getDatasource();
	// It could exist if it was passed in as an initialization argument.
	if ( StructKeyExists(Arguments,"table") AND isSimpleValue(Arguments.table) AND Len(Trim(Arguments.table)) ) {
		Variables.table = Arguments.table;
	} else {
		Variables.table = getTableVariable(loc.metaXml);
	}

	if ( StructKeyExists(Variables.sMetaData,Variables.table) ) {
		Variables.labelSingular = Variables.sMetaData[Variables.table].labelSingular;
		Variables.labelPlural = Variables.sMetaData[Variables.table].labelPlural;
		if ( StructKeyExists(Variables.sMetaData[Variables.table],"methodSingular") ) {
			Variables.methodSingular = Variables.sMetaData[variables.table].methodSingular;
		}
		if ( StructKeyExists(Variables.sMetaData[Variables.table],"methodPlural") ) {
			Variables.methodPlural = Variables.sMetaData[Variables.table].methodPlural;
		}
	}

	if ( NOT StructKeyExists(Variables,"labelSingular") ) {
		Variables.labelSingular = "Record";
	}
	if ( NOT StructKeyExists(Variables,"labelPlural") ) {
		Variables.labelPlural = "Records";
	}
	if ( NOT StructKeyExists(Variables,"methodSingular") ) {
		Variables.methodSingular = Variables.labelSingular;
	}
	if ( NOT StructKeyExists(variables,"methodPlural") ) {
		Variables.methodPlural = Variables.labelPlural;
	}
	Variables.methodSingular = makeCompName(Variables.methodSingular);
	Variables.methodPlural = makeCompName(Variables.methodPlural);

	setMetaStruct();

	addMethods();

}

/**
* I add a value to a list field if it doesn't already exist. Can be used with any list value (not just relation fields).
*/
public void function addRelationListValue() {
	
	Arguments.tablename = getTableVariable();

	Variables.DataMgr.addRelationListValue(ArgumentCollection=Arguments);

}

public struct function getExpectedFutureData(
	struct args="#{}#",
	string fieldlist=""
) {
	var LocalFieldList = "";
	var sMetaStruct = getMetaStruct();
	var sArgs = 0;
	var aFields = 0;
	var sFields = 0;
	var sBefore = 0;
	var sAfter = 0;

	//Fieldlist order: 1 Explicit, 2 from args, 3 all fields
	if ( StructKeyHasLen(Arguments,"fieldlist") ) {
		LocalFieldList = Arguments.fieldlist;
	} else if ( StructKeyHasLen(Arguments.args,"fieldlist") ) {
		LocalFieldList = Arguments.args.fieldlist;
	} else {
		LocalFieldList = getFieldList();
	}

	//Get before data
	if (
		StructKeyHasLen(sMetaStruct,"arg_pk")
		AND
		StructKeyHasLen(Arguments.args,sMetaStruct["arg_pk"])
	) {
		//If pk is provided, get before data from record.
		sArgs = {
			"#sMetaStruct.arg_pk#":Arguments.args[sMetaStruct["arg_pk"]]
		};
		sArgs["fieldlist"] = LocalFieldList;

		sBefore = QueryRowToStruct(
			getRecords(ArgumentCollection=sArgs)
		);

	} else {
		//If no pk is provided, get before data from defaults.

		aFields = ListToArray(LocalFieldList);

		sFields = getFieldsStruct();
		sBefore = {};

		for ( field in aFields ) {
			if ( StructKeyExists(sFields,field) ) {
				if ( StructKeyExists(sFields[field],"default") ) {
					//Use default if provided.
					sBefore[field] = sFields[field]["default"];
				} else if (
					NOT (
						StructKeyExists(sFields[field],"type")
						AND
						ListFirst(sFields[field]["type"],":") EQ "pk"
					)
				) {
					//Return empty value if not a pkfield.
					sBefore[field] = "";
				}
			}
		}
	}

	//Copy before to after
	sAfter = sBefore;
	//Overwrite with incoming data
	StructAppend(
		sAfter,
		StructCopyKeys(Arguments.args,LocalFieldList),
		true
	);

	return sAfter;
}

public string function getFieldList() {
	
	return variables.sMetaData[variables.table].fieldlist;
}

public string function getPrimaryKeyValues() {
	var sMetaStruct = getMetaStruct();
	var result = 0;

	if ( StructKeyExists(sMetaStruct,"arg_pk") ) {
		Arguments.field = sMetaStruct["arg_pk"];
		Arguments.useDefault = false;
		result = invoke(Variables,"getTableFieldValue",Arguments);
	}

	return result;
}

public string function getTableFieldValue() {
	var sFields = getFieldsStruct();
	var qRecords= 0;
	var result = "";
	var sArgs = StructCopy(Arguments);

	if ( 
		NOT (
				StructKeyExists(Arguments,"field")
				AND
				Len(arguments.field)
				AND
				ListLen(Arguments.field) EQ 1
				AND
				StructKeyExists(sFields,Arguments.field)
		)
	) {
		throwError("getTableFieldValue must have a field argument with one and only one field from this table.");
	}

	if (
			NOT (
				StructKeyExists(Arguments,"useDefault")
				AND
				isBoolean(arguments.useDefault)
			)
	) {
		Arguments.useDefault = true;
	}

	sArgs.fieldlist = Arguments.field;
	//Ditch internal arguments from being passed to getRecords
	StructDelete(sArgs,"field");
	StructDelete(sArgs,"useDefault");
	qRecords = getRecords(ArgumentCollection=sArgs);

	if ( qRecords.RecordCount ) {
		result = ArrayToList(qRecords[Arguments.field]);
	} else if ( Arguments.useDefault AND StructKeyExists(sFields[Arguments.field],"default") ) {
		result = sFields[Arguments.field]["default"];
	}

	return result;
}

public string function getTableVariable(string metaXml="") {
	var result = "";
	var xDef = 0;

	if ( StructKeyExists(Variables,"table") ) {
		result = Variables.table;
	} else {
		// Allow component to be created init(Manager=Manager,table=tablename)
		if ( StructKeyExists(Arguments,"table") AND isSimpleValue(Arguments.table) ) {
			result = Arguments.table;
		} else if ( StructKeyExists(Variables,"xDef") ) {
			result = Variables.xDef.tables.table[1].XmlAttributes.name;
		/*
		<!---
		} else if ( Len(metaXml) ) {
			xDef = XmlParse(metaXml);
			result = xDef.tables.table[1].XmlAttributes.name;
		*/
		} else if ( StructKeyExists(Variables,"Parent") AND isObject(Variables.Parent) AND StructKeyExists(variables.Parent,"getComponentTableName") ) {
			result = Variables.Parent.getComponentTableName(This);
		}
	}

	if ( Len(result) ) {
		Variables.table = result;
	} else { 
		throw(type="Records",message="If xml method is not provided, Variables.table must be set.");
	}

	return result;
}

public string function copyRecord() {
	var result = Variables.Manager.copyRecord(tablename=Variables.table,data=Arguments);

	notifyEvent(EventName=variables.sMetaStruct["method_copy"],Args=Arguments,result=result);

	return result;
}

public array function getFieldsArray(string transformer) {

	if (
		StructKeyExists(Variables,"cachedata")
		AND
		StructKeyExists(Variables.cachedata,"FieldsArray")
		AND
		isArray(Variables.cachedata["FieldsArray"])
		AND
		NOT StructCount(Arguments)
	) {
		return Variables.cachedata["FieldsArray"];
	} else {
		Arguments["tablename"] = Variables.table;
		return Variables.Manager.getFieldsArray(argumentCollection=Arguments);
	}
}

public function getFieldSelectSQL(
	required string field,
	string tablealias,
	boolean useFieldAlias="true"
) {

	return Variables.DataMgr.getFieldSelectSQL(tablename=Variables.table,ArgumentCollection=Arguments);
}

public string function getFieldsList(string transformer) {
	var aFields = getFieldsArray(ArgumentCollection=Arguments);
	var sField = 0;
	var result = "";

	for ( sField in aFields ) {
		result = ListAppend(result,sField.name);
	}

	return result;
}

public struct function getFieldsStruct(string transformer) {
	
	if (
		StructKeyExists(Variables,"cachedata")
		AND
		StructKeyExists(Variables.cachedata,"FieldsStruct")
		AND
		isStruct(Variables.cachedata["FieldsStruct"])
		AND
		NOT StructCount(Arguments)
	) {
		return Variables.cachedata["FieldsStruct"];
	} else {
		Arguments["tablename"] = Variables.table;
		return Variables.Manager.getFieldsStruct(ArgumentCollection=Arguments);
	}

}

public string function getFolder(required string field) {
	var sFields = getFieldsStruct();
	var result = "";

	if ( StructKeyExists(sFields,Arguments.field) AND StructKeyExists(sFields[Arguments.field],"folder") ) {
		result = sFields[Arguments.field]["folder"];
	}

	return Variables.FileMgr.convertFolder(result,"/");
}

public string function getLabelFieldValue() {
	var qRecord = 0;
	var sManagerData = variables.Manager.getMetaStruct(Variables.table);
	var sArgs = {};
	var result = "";

	if ( NOT StructKeyExists(sManagerData,"labelField") ) {
		throw(message="getLabelFieldValue can only be used against tables with a defined labelField.",type="Records");
	}

	 qRecord = Variables.Manager.getRecord(tablename=Variables.table,data=Arguments,fieldlist=sManagerData.labelField);

	if ( qRecord.RecordCount ) {
		result = qRecord[sManagerData.labelField][1];
	}

	/*
	sArgs.field = sManagerData.labelField;
	Arguments.tablename = Variables.table;
	sArgs.data = Variables.Manager.alterArgs(ArgumentCollection=Arguments);
	writeDump(var=sArgs,abort=true);
	return getTableFieldValue(ArgumentCollection=sArgs);
	*/

	return result;
}

public struct function getMetaStruct() {
	
	if ( NOT StructKeyExists(variables,"sMetaStruct") ) {
		setMetaStruct();
	}

	return variables.sMetaStruct;
}

public function getServiceComponent(required string name) {
	var result = Arguments.name;

	if (
		StructKeyExists(Variables,"Parent")
		AND
		isObject(variables.Parent)
		AND
		StructKeyExists(Variables.Parent,Arguments.name)
	) {
		result = Variables.Parent[Arguments.name];
	}

	return result;
}

public function getParentComponent() {

	if ( StructKeyExists(variables,"Parent") AND isObject(variables.Parent) ) {
		return variables.Parent;
	}
}

public query function getPKRecord() {

	return Variables.Manager.getPKRecord(tablename=Arguments.table,data=Arguments);
}

public query function getRecord() {
	
	Arguments.alterargs_for = "get";
	Arguments = alterArgs(argumentCollection=Arguments);

	StructAppend(Arguments,getSpecifyingValues(),"no");

	return alterRecords(Variables.Manager.getRecord(tablename=Variables.table,data=Arguments),Arguments);
}

public query function getRecords() {
	
	Arguments.alterargs_for = "gets";
	Arguments = alterArgs(ArgumentCollection=Arguments);

	StructAppend(Arguments,getSpecifyingValues(),"no");

	return alterRecords(Variables.Manager.getRecords(tablename=Variables.table,data=Arguments),Arguments);
}

public array function getRecordsSQL() {

	if ( NOT ( StructKeyExists(Arguments,"alter") AND Arguments.alter EQ false ) ) {
		Arguments.alterargs_for = "gets";
		Arguments = alterArgs(argumentCollection=Arguments);
	}

	StructAppend(Arguments,getSpecifyingValues(),"no");

	return Variables.Manager.getRecordsSQL(tablename=Variables.table,data=Arguments);
}

public struct function getTableMetaStruct() {

	return Variables.Manager.getMetaStruct(Variables.table);
}

public boolean function hasField(required string name) {
	var sFields = getFieldsStruct();

	return BooleanFormat(StructKeyExists(sFields,Arguments.name));
}

public boolean function hasRecords() {
	var result = false;

	if ( StructKeyExists(Variables.DataMgr,"hasRecords") ) {
		Arguments.alterargs_for = "has";
		Arguments.data = alterArgs(ArgumentCollection=StructCopy(Arguments));

		result = Variables.DataMgr.hasRecords(tablename=Variables.table,ArgumentCollection=Variables.Manager.alterArgs(ArgumentCollection=Arguments));
	} else {
		result = (numRecords(ArgumentCollection=alterArgs(ArgumentCollection=Arguments)) GT 0);
	}

	return result;
}

public numeric function numRecords() {
	var sArgs = {};
	var qRecords = 0;

	sArgs["tablename"] = Variables.table;
	sArgs["Function"] = "count";
	sArgs["FunctionAlias"] = "NumRecords";
	Arguments.alterargs_for = "num";
	sArgs["data"] = alterArgs(ArgumentCollection=Arguments);
	sArgs["fieldlist"] = "";

	if ( StructKeyExists(sArgs["data"],"AdvSQL") ) {
		sArgs["data"]["AdvSQL"] = StructCopy(sArgs["data"]["AdvSQL"]);
		StructDelete(sArgs["data"]["AdvSQL"],"SELECT");
		StructDelete(sArgs["data"]["AdvSQL"],"ORDER BY");
	}

	qRecords = Variables.Manager.getRecords(ArgumentCollection=sArgs);

	return Val(qRecords.NumRecords);
}

public void function deleteRecord() {
	
	removeRecord(ArgumentCollection=Arguments);

}

public void function removeRecord() {
	
	Variables.Manager.removeRecord(Variables.table,Arguments);

	notifyEvent(EventName=Variables.sMetaStruct["method_remove"],Args=Arguments);

}

public function RecordObject(
	required Record,
	string fields=""
) {
	
	Arguments.Service = This;

	return CreateObject("component","RecordObject").init(ArgumentCollection=Arguments);
}

public string function saveRecord() {
	var sArgs = 0;
	var sSpecifyingValues = getSpecifyingValues();
	var result = 0;

	if ( StructCount(sSpecifyingValues) AND NOT isUpdate() ) {
		StructAppend(Arguments,sSpecifyingValues,"no");
	}

	Arguments = invoke(This,"validate#Variables.methodSingular#",Arguments);
	
	if ( NOT StructKeyExists(Arguments,"OnExists") ) {
		Arguments.OnExists = Variables.OnExists;
	}

	result = Variables.Manager.saveRecord(Variables.table,Arguments);

	notifyEvent(EventName=Variables.sMetaStruct["method_save"],Args=Arguments,result=result);

	return result;
}

public string function saveRecordDataOnly() {
	var sSpecifyingValues = getSpecifyingValues();

	if ( StructCount(sSpecifyingValues) AND NOT isUpdate() ) {
		StructAppend(Arguments,sSpecifyingValues,"no");
	}

	return Variables.Manager.saveRecordDataOnly(variables.table,Arguments);
}

public string function saveRecordOnly() {
	var sSpecifyingValues = getSpecifyingValues();

	if ( StructCount(sSpecifyingValues) AND NOT isUpdate() ) {
		StructAppend(Arguments,sSpecifyingValues,"no");
	}

	return Variables.Manager.saveRecord(variables.table,Arguments);
}

public string function Security_getPermissions() {

	return Variables.Manager.Security_getPermissions(Variables.table);
}

public void function sortRecords() {
	var sortfield = getSortField();

	if ( Len(sortfield) ) {
		if ( StructKeyExists(Arguments,Variables.methodPlural) ) {
			Variables.DataMgr.saveSortOrder(Variables.table,sortfield,Arguments[Variables.methodPlural]);
		} else if ( ArrayLen(Arguments) AND ListLen(Arguments[1]) GT 1 ) {
			Variables.DataMgr.saveSortOrder(Variables.table,sortfield,Arguments[1]);
		}
	}

	notifyEvent(EventName=Variables.sMetaStruct["method_sort"],Args=Arguments);

}

public struct function validateRecord() {
	
	return Arguments;
}

private void function addMethods() {
	var singular = variables.methodSingular;
	var plural = variables.methodPlural;
	var methods = "get#singular#,get#plural#,remove#singular#,save#singular#,sort#plural#,copy#singular#,num#plural#,has#plural#,validate#singular#";
	var rmethods = "getRecord,getRecords,removeRecord,saveRecord,sortRecords,copyRecord,numRecords,hasRecords,validateRecord";
	var method = "";
	var rmethod = "";
	var ii = 0;
	var sMetaStruct = getMetaStruct();

	if ( StructKeyExists(sMetaStruct,"arg_pk") ) {
		methods = ListAppend(methods,"get#sMetaStruct.arg_pk#s");
		rmethods = ListAppend(rmethods,"getPrimaryKeyValues");
	}

	for ( ii=1; ii LTE ListLen(methods); ii++ ) {
		method = ListGetAt(methods,ii);
		rmethod = ListGetAt(rmethods,ii);
		if ( NOT StructKeyExists(This,method) ) {
			This[method] = variables[rmethod];
		}
		if ( NOT StructKeyExists(variables,method) ) {
			variables[method] = variables[rmethod];
		}
	}

}

private struct function alterArgs() {

	return Arguments;
}

private query function alterRecords(
	required query query,
	required struct Args
) {

	return Arguments.query;
}

public string function getFieldsOfTypes(required string Types) {
	var aFields = getFieldsArray();
	var sField = 0;
	var result = "";

	for ( sField in aFields ) {
		if ( StructKeyExists(sField,"type") AND ListFindNoCase(Arguments.Types,sField.type) ) {
			result = ListAppend(result,sField.name);
		}
	}

	return result;
}
</cfscript>

<cffunction name="getMethodOutputValue" access="private" returntype="string" output="no" hint="DEPRECATED">
	<cfargument name="component" type="any" required="yes">
	<cfargument name="method" type="string" required="yes">
	<cfargument name="args" type="struct" required="no">

	<cfset var result = "">
	<cfset var fMethod = component[method]>

	<cfif StructKeyExists(arguments,"args")>
		<cfsavecontent variable="result"><cfoutput>#fMethod(argumentCollection=args)#</cfoutput></cfsavecontent>
	<cfelse>
		<cfsavecontent variable="result"><cfoutput>#fMethod()#</cfoutput></cfsavecontent>
	</cfif>

	<cfset result = Trim(result)>

	<cfreturn result>
</cffunction>

<cfscript>
private string function getSortField() {
	
	if (
		StructKeyExists(variables,"cachedata")
		AND
		StructKeyExists(variables.cachedata,"SortField")
		AND
		isSimpleValue(variables.cachedata["SortField"])
	) {
		return Variables.cachedata["SortField"];
	} else {
		return getSortFieldInternal(ArgumentCollection=Arguments);
	}
}

private string function getSortFieldInternal() {
	var aFields = getFieldsArray();
	var sField = 0;

	for ( sField in aFields ) {
		if ( StructKeyExists(sField,"type") AND sField.type EQ "Sorter" ) {
			return sField.name;
		}
	}

	return "";
}

public struct function getSpecifyingValues() {

	return Variables.sSpecifyingValues;
}

/**
* I return a list of tables being referenced in this component. 
*/
private string function getTableList() {
	var ii = 0;
	var result = "";

	if ( StructKeyExists(variables,"xDef") ) {
		for ( ii=1; ii LTE ArrayLen(variables.xDef.tables.table); ii++  ) {
			result = ListAppend(result,variables.xDef.tables.table[ii].XmlAttributes.name);
		}
	} else {
		result = Variables.table;
	}

	return result;
}

public boolean function isUpdate() {
	var result = false;

	return booleanFormat(Variables.DataMgr.isMatchingRecord(tablename=Variables.table,data=StructFromArgs(Arguments),pksonly=(Variables.OnExists EQ "save")));
}

public struct function setMetaStruct() {
	var sMethods = {};
	var aPKFields = variables.Manager.DataMgr.getPKFields(getTableVariable());
	var sManagerData = variables.Manager.getMetaStruct(getTableVariable());
	var single = variables.methodSingular;
	var plural = variables.methodSingular;
	var sParent = 0;

	if ( StructKeyExists(sManagerData,"labelField") ) {
		sMethods["field_label"] = "#sManagerData.labelField#";
	}
	if ( StructKeyExists(sManagerData,"entity") ) {
		sMethods["entity"] = "#sManagerData.entity#";
		sMethods["entities"] = "#variables.Manager.pluralize(sManagerData.entity)#";
		single = sMethods["entity"];
		plural = sMethods["entities"];
	}
	sMethods["label_Singular"] = "#variables.labelSingular#";
	sMethods["label_Plural"] = "#variables.labelPlural#";
	sMethods["method_Singular"] = "#variables.methodSingular#";
	sMethods["method_Plural"] = "#variables.methodPlural#";
	sMethods["method_copy"] = "copy#variables.methodSingular#";
	sMethods["method_get"] = "get#variables.methodSingular#";
	sMethods["method_gets"] = "get#variables.methodPlural#";
	sMethods["method_remove"] = "remove#variables.methodSingular#";
	sMethods["method_save"] = "save#variables.methodSingular#";
	sMethods["method_sort"] = "sort#variables.methodPlural#";
	sMethods["method_delete"] = "remove#variables.methodSingular#";
	sMethods["method_validate"] = "validate#variables.methodSingular#";
	sMethods["method_security_permissions"] = "Security_GetPermissions";
	if ( StructKeyExists(sManagerData,"deletable") ) {
		sMethods["property_deletable"] = "#sManagerData.deletable#";
	}
	sMethods["property_hidecols"] = true;
	sMethods["property_pktype"] = variables.Manager.getPrimaryKeyType(getTableVariable());
	sMethods["property_handles_files"] = true;
	sMethods["message_save"] = "#variables.labelSingular# Saved.";
	sMethods["message_remove"] = "#variables.labelSingular# Deleted.";
	sMethods["message_sort"] = "#variables.labelPlural# Sorted.";

	sMethods["arg_sort"] = "#variables.methodPlural#";
	sMethods["catch_types"] = "#variables.methodPlural#";
	if ( StructKeyExists(Variables,"Parent") AND isObject(Variables.Parent) ) {
		if ( StructKeyExists(Variables.Parent,"getErrorType") ) {
			sMethods["catch_types"] = ListAppend(sMethods["catch_types"],Variables.Parent.getErrorType());
		} else {
			sParent = getMetaData(Variables.Parent);
			sMethods["catch_types"] = ListAppend(sMethods["catch_types"],ListFirst(ListLast(sParent.name,'.')),'_');
		}
	}

	sMethods["pkfields"] = variables.Manager.getPrimaryKeyFields(getTableVariable());
	if ( ArrayLen(aPKFields) EQ 1 ) {
		sMethods["arg_pk"] = aPKFields[1].ColumnName;
	}

	variables.sMetaStruct = sMethods;

	return sMethods;
}

private boolean function ListEquals(
	required string List1,
	required string List2,
	string sort_type
) {

	// Check for same number of items. If those are different, lists can't be equal.
	if ( ListLen(Arguments.List1) NEQ ListLen(Arguments.List2) ) {
		return false;
	}

	// If both lists are empty, they are equal.
	if ( Len(Trim(Arguments.List1)) EQ 0 AND Len(Trim(Arguments.List2)) EQ 0 ) {
		return true;
	}

	// Determine default sort_type
	if ( NOT StructKeyExists(Arguments,"sort_type") ) {
		// Numeric lists default to "numeric", all other default to "text".
		if ( REFindNoCase("^(\d+,*)+$", "#Arguments.List1#,#Arguments.List2#") ) {
			Arguments["sort_type"] = "numeric";
		} else {
			Arguments["sort_type"] = "text";
		}
	}

	return BooleanFormat(ListSort(Arguments.List1,Arguments.sort_type) EQ ListSort(Arguments.List2,Arguments.sort_type));
}

private struct function StructFromArgs() {
	var sTemp = 0;
	var sResult = {};
	var key = "";

	if ( StructCount(Arguments) EQ 1 AND isStruct(Arguments[1]) ) {
		sTemp = Arguments[1];
	} else {
		sTemp = Arguments;
	}

	// set all arguments into the return struct
	for ( key in sTemp ) {
		if ( StructKeyExists(sTemp, key) ) {
			sResult[key] = sTemp[key];
		}
	}

	return sResult;
}
</cfscript>

<cffunction name="dbXml" access="public" returntype="string" output="no">

	<cfscript>
	var result = "";
	var aFields = 0;
	var ii = 0;
	var jj = 0;
	var col = "";
	var att = "";
	var attlist = "ColumnName,CF_DataType,PrimaryKey,Increment,Length";
	var noshowatts = "name,type";
	var tables = getTableList();
	var table = "";
	</cfscript>

	<cfsavecontent variable="result"><cfoutput>
	<tables><cfloop list="#tables#" index="table"><cfset aFields = variables.Manager.getFieldsArray(transformer="DataMgr",tablename=table)>
		<table name="#table#"><cfloop index="ii" from="1" to="#ArrayLen(aFields)#" step="1">
			<field ColumnName="#aFields[ii].name#"<cfloop list="#attlist#" index="col"><cfif StructKeyExists(aFields[ii],col)> #col#="#aFields[ii][col]#"</cfif></cfloop><cfloop collection="#aFields[ii]#" item="col"><cfif isSimpleValue(aFields[ii][col]) AND NOT ListFindNoCase(noshowatts,col) AND NOT ListFindNoCase(attlist,col)> #col#="#aFields[ii][col]#"</cfif></cfloop><cfif NOT StructKeyExists(aFields[ii],"relation")> /><cfelse>>
				<relation<cfloop collection="#aFields[ii].relation#" item="col"><cfif isSimpleValue(aFields[ii].relation[col])> #col#="#XmlFormat(aFields[ii].relation[col])#"</cfif></cfloop><cfif NOT StructKeyExists(aFields[ii].relation,"filters")> /</cfif>><cfif StructKeyExists(aFields[ii].relation,"filters")><cfloop index="jj" from="1" to="#ArrayLen(aFields[ii].relation.filters)#" step="1">
					<filter<cfloop collection="#aFields[ii].relation.filters[jj]#" item="att"> #att#="#XmlFormat(aFields[ii].relation.filters[jj][att])#"</cfloop> /></cfloop>
				</relation></cfif>
			</field></cfif></cfloop>
		</table></cfloop><cfif StructKeyExists(variables,"xDef")><cfloop index="ii" from="1" to="#ArrayLen(variables.xDef.tables.XmlChildren)#" step="1">
			<cfif variables.xDef.tables.XmlChildren[ii].XmlName NEQ "table">
				#XmlAsString(variables.xDef.tables.XmlChildren[ii])#
			</cfif>
		</cfloop></cfif>
	</tables>
	</cfoutput></cfsavecontent>

	<cfreturn result>
</cffunction>

<cfscript>
public function XmlAsString(required XmlElem) {

	return Variables.Manager.XmlAsString(Arguments.XmlElem);
}

public string function xml() {
	var result = "";

	return result;
}

public function onMissingMethod() {
	var loc = {};
	var method = Arguments.missingMethodName;
	var args = Arguments.missingMethodArguments;
	var newmethod = "";
	var isValid = false;

	if ( Arguments.missingMethodName CONTAINS Variables.methodPlural ) {
		newmethod = ReplaceNoCase(Arguments.missingMethodName,Variables.methodPlural,"Records");
		if ( StructKeyExists(This,newmethod) ) {
			isValid = true;
		}
	}
	if ( NOT isValid AND Arguments.missingMethodName CONTAINS Variables.methodSingular ) {
		newmethod = ReplaceNoCase(Arguments.missingMethodName,Variables.methodSingular,"Record");
		if ( StructKeyExists(This,newmethod) ) {
			isValid = true;
		}
	}
	if ( isValid ) {
		loc.result = invoke(Variables,newmethod,args);
	} else {
		throw(message="The method #Arguments.missingMethodName# was not found in component #getCurrentTemplatePath()#",detail=" Ensure that the method is defined, and that it is spelled correctly.");
	}

	if ( StructKeyExists(loc,"result") ) {
		return loc.result;
	}
}

package void function notifyEvent(
	required string EventName,
	struct Args,
	result
) {

	Arguments["This"] = This;

	if ( StructKeyExists(Variables,"Parent") AND isObject(Variables.Parent) AND StructKeyExists(Variables.Parent,"notifyEvent") ) {
		Variables.Parent.notifyEvent(ArgumentCollection=Arguments);
	}

	if ( StructKeyExists(Variables,"Observer") ) {
		Variables.Observer.notifyEvent(ArgumentCollection=Arguments);
	}

}

public void function throwError(
	required string message,
	string errorcode="",
	string detail="",
	string extendedinfo=""
) {

	if (
		StructKeyExists(Variables,"Parent")
		AND
		isObject(Variables.Parent)
		AND
		StructKeyExists(Variables.Parent,"throwError")
	) {
		Variables.Parent.throwError(ArgumentCollection=Arguments);
	} else {
		throw(
			type="#variables.methodPlural#",
			message="#arguments.message#",
			errorcode="#arguments.errorcode#",
			detail="#arguments.detail#",
			extendedinfo="#arguments.extendedinfo#"
		);
	}

}
</cfscript>

</cfcomponent>
