<cfcomponent extends="com.sebtools.component" displayname="Data Trashcan" hint="I handle putting deleted records into Trashcan tables." output="no">
<cfscript>
public function init(
	required DataLogger,
	string DatabaseName,
	string Owner="dbo"
) {

	Arguments.DataMgr = Arguments.DataLogger.getDataMgr();
	Arguments.Observer = Arguments.DataLogger.getObserver();

	initInternal(ArgumentCollection=Arguments);

	loadDataMgr();

	Variables.MrECache = CreateObject("component","com.sebtools.MrECache").init(
		id="deletes",
		timeSpan=CreateTimeSpan(0,0,0,5)
	);

	registerListener();

	Variables.sLoadedTables = {};

	Variables.DataLogger.setDataTrashcan(This);

	Variables.logged_tables = "";

	return This;
}

public function createTrashcanTable(required string tablename) {

	if ( NOT isTrackedTable(Arguments.tablename) ) {
		return false;
	}

	// Only load the table once per instantiation (should make sure it is current to recent changes without continuing to update it).
	if ( NOT StructKeyExists(Variables.sLoadedTables,Arguments.tablename) ) {
		makeTable(Arguments.tablename);
		growColumns(Arguments.tablename);
		Variables.sLoadedTables[Arguments.tablename] = now();
	}

}

public function getDatabaseName() {
	return Variables.DatabaseName;
}

public function getDatabaseOwner() {
	return Variables.Owner;
}

public function getDeletedRecord(
	required string tablename,
	struct data,
	string fieldlist
) {
	var qRecords = 0;
	var sData = StructCopy(Arguments);

	createTrashcanTable(Arguments.tablename);

	sData["Tablename"] = getTrackingTableName(Arguments.tablename);
	sData["maxrows"] = 1;
	sData["orderBy"] = "DataTrashcan_ID DESC";

	// Make sure DataTrashcan fields are returned.
	if ( StructKeyHasLen(Arguments,"fieldlist") ) {
		Arguments.fieldlist = ListAppend(Arguments.fieldlist,"DataTrashcan_ID,DataTrashcan_DateDeleted");
	}

	qRecords = Variables.DataMgrTrashcan.getRecords(ArgumentCollection=sData);

	return qRecords;
}

public function getTrackingTableName(
	required string tablename,
	boolean qualified=false
) {
	if ( Arguments.qualified ) {
		return "#Variables.DatabaseName#.#Variables.Owner#.#getTrackingTableName(Arguments.tablename)#";
	}

	return "aud_" & Arguments.tablename & "_Trashcan";
}

private function loadDataMgr() {
	var sArgs = {};// Don't pass all arguments in. We specifically don't want Observer in there.

	sArgs["datasource"] = Variables.DataMgr.getDatasource();
	if ( StructKeyHasLen(Variables,"DatabaseName") ) {
		sArgs["databasename"] = Variables.DatabaseName;
	}

	Variables.DataMgrTrashcan = CreateObject("component","com.sebtools.DataMgr").init(ArgumentCollection=sArgs);

}

public function logAction(
	required string tablename,
	required string action,
	struct data,
	string ChangeUUID,
	sql
) {
	var qRecords = 0;
	var sData = 0;
	var cache_id = Variables.MrECache.id("deletion",{tablename=Arguments.tablename,data=Arguments.data});

	if ( NOT isTrackedTable(Arguments.tablename) ) {
		return false;
	}

	qRecords = Variables.DataMgr.getRecords(tablename=Arguments.tablename,data=Arguments.data);


	//Try to see if this has been deleted by pk very recently
	if ( Variables.MrECache.exists(cache_id) ) {
		return false;
	}

	//Briefly cache deletion by pk, if possible.
	Variables.MrECache.put(cache_id,now());

	createTrashcanTable(Arguments.tablename);

	for ( sData in qRecords ) {
		Variables.DataMgrTrashcan.runSQLArray(Variables.DataMgrTrashcan.insertRecordSQL(tablename=getTrackingTableName(Arguments.tablename),data=sData));
	}

	return true;
}

public function logTable(required string tablename) {
	
	Arguments.tablename = Trim(Arguments.tablename);

	if ( Len(Arguments.tablename) AND NOT ListFindNoCase(Variables.logged_tables,Arguments.tablename) ) {
		Variables.logged_tables = ListAppend(Variables.logged_tables,Arguments.tablename);

		createTrashcanTable(Arguments.tablename);
	}

}

private function ensureTrashcanTableExists(required string tablename) {

}

/**
* I get the primary key value for the given data.
*/
private string function getPKValue(
	required string tablename,
	required struct data
) {
	var result = "";
	var pkfields = Variables.DataMgr.getPrimaryKeyFieldNames(arguments.tablename);
	var pkfield = "";

	for ( pkfield in ListToArray(pkfields) ) {
		result = ListAppend(result,Arguments.data[pkfield]);
	}

	return result;
}
</cfscript>

<cffunction name="growColumns" access="private" returntype="any" output="no" hint="I make sure that the columns in the trashcan are as big as their counterparts in the original table.">
	<cfargument name="tablename" type="string" required="yes">

	<cfset var qColumns = 0>
	<cfset var trashtable = getTrackingTableName(Arguments.tablename)>
	<cfset var DataTypeStr = "">

	<cf_DMQuery name="qColumns">
		SELECT		main.COLUMN_NAME,
					main.DATA_TYPE,
					main.IS_NULLABLE,
					trashcan.CHARACTER_MAXIMUM_LENGTH CurrentMax,
					main.CHARACTER_MAXIMUM_LENGTH TargetMax
		FROM		INFORMATION_SCHEMA.COLUMNS main
		INNER JOIN	<cf_DMObject name="#DatabaseName#">.INFORMATION_SCHEMA.COLUMNS trashcan
			ON		main.COLUMN_NAME = trashcan.COLUMN_NAME
		WHERE		1 = 1
			AND		main.TABLE_NAME = <cf_DMParam value="#Arguments.tablename#" cfsqltype="CF_SQL_VARCHAR">
			AND		trashcan.TABLE_NAME = <cf_DMParam value="#trashtable#" cfsqltype="CF_SQL_VARCHAR">
			AND		main.CHARACTER_MAXIMUM_LENGTH > trashcan.CHARACTER_MAXIMUM_LENGTH
			AND		trashcan.CHARACTER_MAXIMUM_LENGTH > 0
	</cf_DMQuery>

	<cfoutput query="qColumns">
		<cfscript>
		if ( DataTypeStr CONTAINS "char" ) {
			if ( Val(TargetMax) LTE 8000 ) {
				DataTypeStr = "#DATA_TYPE#(#TargetMax#)";
			} else {
				DataTypeStr = "#DATA_TYPE#(MAX)";
			}
		} else {
			DataTypeStr = "#DATA_TYPE#";
		}
		</cfscript>
		<cf_DMQuery>
		ALTER TABLE		<cf_DMObject name="#Variables.DatabaseName#.#Variables.Owner#.#trashtable#">
		ALTER COLUMN	<cf_DMObject name="#COLUMN_NAME#"> #DataTypeStr#<cfif IS_NULLABLE IS NOT true> NOT</cfif> NULL
		</cf_DMQuery>
	</cfoutput>

</cffunction>

<cfscript>
private boolean function isTrackedTable(required string tablename) {
	var tables = ListAppend(Variables.logged_tables,Variables.DataLogger.getLoggedTables());

	return booleanFormat(ListFindNoCase(tables,Arguments.tablename));
}

private function makeTable(required string tablename) {
	var sTypes = Variables.DataMgrTrashcan.getRelationTypes();
	var TableXml = Variables.DataMgr.getXml(Arguments.tablename);
	var xTable = XmlParse(TableXml);
	var aPKs = 0;
	var aRelations = 0;
	var DataType = "";
	var reltype = "";
	var sRelType = 0;

	// Rename table to tracking
	xTable.tables.table.XmlAttributes["name"] = getTrackingTableName(Arguments.tablename);

	// Need to preserve the value of the incoming field, not increment it.
	aPKs = XmlSearch(xTable,"//field[@Increment]");
	for ( xfield in aPKs ) {
		StructDelete(xfield.XmlAttributes,"Increment");
	}

	// External pk should not be a primary key. We may need to store more than one deletion for a given record (rare, probably).
	aPKs = XmlSearch(xTable,"//field[@PrimaryKey]");
	for ( xfield in aPKs ) {
		StructDelete(xfield.XmlAttributes,"PrimaryKey");
	}

	// Will store relation values directly in the trashcan table with appropriate data types,
	aRelations = XmlSearch(xTable,"//field[relation]");
	for ( xfield in aRelations ) {
		DataType = "CF_SQL_LONGVARCHAR";
		if ( StructKeyExists(xfield.XmlChildren[1].XmlAttributes,"type") ) {
			reltype = xfield.XmlChildren[1].XmlAttributes["type"];
			if ( StructKeyExists(xfield.XmlChildren[1].XmlAttributes,"cf_datatype") ) {
				DataType = xfield.XmlChildren[1].XmlAttributes["cf_datatype"];
			} else if ( StructKeyExists(sTypes,reltype) ) {
				sRelType = sTypes[reltype];
				if ( StructKeyExists(sRelType,"cfsqltype") AND Len(sRelType["cfsqltype"]) ) {
					DataType = sRelType["cfsqltype"];
				}
			}
		}
		xfield.XmlAttributes["CF_DataType"] = DataType;
		StructDelete(xfield,"XmlChildren");
	}

	TableXml = ToString(xTable);
	// Prepend Data Trashcan fields
	TableXml = ReplaceNoCase(TableXml, '<field', '<field ColumnName="DataTrashcan_DateDeleted" CF_DataType="CF_SQL_DATE" Special="CreationDate" /><field', 'ONE');
	TableXml = ReplaceNoCase(TableXml, '<field', '<field ColumnName="DataTrashcan_ID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" /><field', 'ONE');

	Variables.DataMgrTrashcan.loadXml(TableXml,true,true);

}

/**
* I register a listener with Observer to listen for services being loaded.
*/
private void function registerListener() {

	// Need to listen to delete events before they happen so we can capture the data just prior to the deletion.
	Variables.Observer.registerListener(
		Listener = This,
		ListenerName = "DataTrashcan",
		ListenerMethod = "logAction",
		EventName = "DataMgr:beforeDelete"
	);

	// Make sure all of our trashcan tables exist for any tables covered by
	Variables.Observer.registerListener(
		Listener = This,
		ListenerName = "DataTrashcan",
		ListenerMethod = "createTrashcanTable",
		EventName = "DataMgr:addTable"
	);
	
	// Need to listen to delete events on Manager as well, because if it runs from there then that will ditch some data..
	Variables.Observer.registerListener(
		Listener = This,
		ListenerName = "DataTrashcan",
		ListenerMethod = "logAction",
		EventName = "Manager:beforeRemove"
	);
	
}
</cfscript>

</cfcomponent>
