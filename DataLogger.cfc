<cfcomponent extends="com.sebtools.component" displayname="Data Logger" hint="I log data changes for auditing." output="no">

<cfscript>
public function init(
	required DataMgr,
	required Observer
) {

	initInternal(ArgumentCollection=Arguments);

	return This;
}

public function initInternal(
	required DataMgr,
	required Observer
) {

	Super.initInternal(ArgumentCollection=Arguments);

	Variables.logged_tables = "";

	Variables.DataMgr.loadXML(getDbXml(),true,true);

	registerListener();

	return This;
}

public void function catchError(
	required string MethodName,
	required any Error,
	required struct Args
) hint="I catch logging errors. This can be extended on a per-site basis." {

	Variables.Observer.announceEvent(
		EventName = "DataLogger:onError",
		Args = Arguments
	);

}

public function getDataMgr() {
	return Variables.DataMgr;
}

public function getObserver() {
	return Variables.Observer;
}
</cfscript>

<cffunction name="getRecordChanges" access="public" returntype="any" output="no">
	<cfargument name="tablename" type="string" required="yes">
	<cfargument name="pkvalue" type="string" required="yes">
	<cfargument name="fieldlist" type="string" required="no">

	<cfset var qChanges = 0>
	<cfset var sWhoNames = []>
	
	<cf_DMQuery name="qChanges">
		SELECT		
					s.ChangeSetID,
					s.DateLogged,
					<cf_DMSQL sql="#getWhoNameSQL('s.Who')#" />AS [Who],
					[Action],
					FieldName,
					OldValue,
					NewValue
		FROM		audChangeSets s
		LEFT JOIN	audChanges c
			ON		s.ChangeSetID = c.ChangeSetID
		WHERE		1 = 1
			AND		tablename = <cf_DMParam name="tablename" value="#Arguments.tablename#" cfsqltype="CF_SQL_VARCHAR">
			AND		pkvalue = <cf_DMParam name="pkvalue" value="#Arguments.pkvalue#" cfsqltype="CF_SQL_INTEGER">
		<cfif StructKeyHasLen(Arguments,"fieldlist")>
			AND		FieldName IN <cf_DMParam value="#Arguments.fieldlist#" cfsqltype="CF_SQL_VARCHAR" list="yes">
		</cfif>
		ORDER BY	s.ChangeSetID
	</cf_DMQuery>

	<cfreturn qChanges>
</cffunction>

<cffunction name="getRestoreChanges" access="public" returntype="struct" output="no" hint="I get the changes needed to restore a record to its state at a given time.">
	<cfargument name="tablename" type="string" required="yes">
	<cfargument name="pkvalue" type="string" required="yes">
	<cfargument name="when" type="date" required="yes">
	<cfargument name="fieldlist" type="string" required="no">

	<cfset var qChanges = 0>
	<cfset var sResult = {}>

	<cf_DMQuery name="qChanges">
	SELECT		FieldName,
				OldValue
	FROM		audChangeSets s
	LEFT JOIN	audChanges c
		ON		s.ChangeSetID = c.ChangeSetID
	WHERE		1 = 1
		AND		tablename = <cf_DMParam name="tablename" value="#Arguments.tablename#" cfsqltype="CF_SQL_VARCHAR">
		AND		pkvalue = <cf_DMParam name="pkvalue" value="#Arguments.pkvalue#" cfsqltype="CF_SQL_INTEGER">
		AND		FieldName IS NOT NULL
		<!--- Only the oldest change since the date  --->
		AND		ChangeID IN (
					SELECT		Min(ChangeID) ChangeID
					FROM		audChangeSets s
					LEFT JOIN	audChanges c
						ON		s.ChangeSetID = c.ChangeSetID
					WHERE		1 = 1
						AND		tablename = <cf_DMParam name="tablename" value="#Arguments.tablename#" cfsqltype="CF_SQL_VARCHAR">
						AND		pkvalue = <cf_DMParam name="pkvalue" value="#Arguments.pkvalue#" cfsqltype="CF_SQL_INTEGER">
						AND		FieldName IS NOT NULL
						AND		DateCompleted >= <cfoutput>'#DateFormat(Arguments.when,"yyyy-mm-dd")# #TimeFormat(Arguments.when,"hh:mm:ss")#'</cfoutput>
					GROUP BY	FieldName
				)
	</cf_DMQuery>

	<cfoutput query="qChanges">
		<cfset sResult[FieldName] = OldValue>
	</cfoutput>

	<cfreturn sResult>
</cffunction>

<cfscript>
public query function getRecord(
	required string tablename,
	required string pkvalue,
	required date when,
	string fieldlist
) hint="I get the record as it would have existed at the given point in time." {

	var qRecord = 0;
	var sGet = {tablename=Arguments.tablename};
	var pkfield = Variables.DataMgr.getPrimaryKeyFieldName(Arguments.tablename);
	var sChanges = 0;
	var field = "";
	var cols = "";

	sGet["data"] = {"#pkfield#"=Arguments.pkvalue};

	if ( StructKeyExists(Arguments,"fieldlist") ) {
		sGet["fieldlist"] = Arguments.fieldlist;
	}

	qRecord = Variables.DataMgr.getRecord(ArgumentCollection=sGet);

	if ( NOT qRecord.RecordCount ) {
		if ( StructKeyExists(Variables,"DataTrashcan") ) {
			qRecord = Variables.DataTrashcan.getDeletedRecord(ArgumentCollection=sGet);
		}

		if ( NOT qRecord.RecordCount ) {
			//If record isn't found at all, then throw error. If it is found, but deleted still then return empty query.
			throw(type="DataLogger",message="Unable to retrieve record for table #Arguments.tablename# with primary key value of #Arguments.data[pkfield]#.");
		}

		//If a deleted record is found, make sure it was deleted after the When date
		if ( qRecord.RecordCount AND ListFindNoCase(qRecord.ColumnList,"DataTrashcan_DateDeleted") ) {
			//If the record was deleted before the given date, treat it as still deleted and return nothing.
			if ( qRecord.DataTrashcan_DateDeleted LT Arguments.when ) {
				QueryDeleteRow(qRecord, 1);
			}
		}
	}

	sChanges = getRestoreChanges(ArgumentCollection=Arguments);

	cols = qRecord.ColumnList;
	for ( field in sChanges ) {
		if ( ListFindNoCase(cols,field) ) {
			QuerySetCell(qRecord,field,sChanges[field]);
		}
	}

	return qRecord;
}

public string function getWho() hint="I get the 'Who' value for the data logging. This should be overridden on a per-site basis." {
	return CGI.REMOTE_ADDR;
}
</cfscript>

<cffunction name="getWhoAdded" access="public" returntype="string" output="no" hint="I get the 'Who' value for who added the given record.">
	<cfargument name="tablename" type="string" required="yes">
	<cfargument name="pkvalue" type="string" required="no">
	
	<cfset var qAdd = 0>

	<cf_DMQuery name="qAdd">
		SELECT		Who
		FROM		audChangeSets s
		WHERE		1 = 1
			AND		tablename = <cf_DMParam value="#Arguments.tablename#" cfsqltype="CF_SQL_VARCHAR">
			AND		[Action] = 'insert'
			AND		pkvalue = <cf_DMParam value="#Arguments.pkvalue#" cfsqltype="CF_SQL_VARCHAR">
	</cf_DMQuery>

	<cfreturn qAdd.Who>
</cffunction>

<cfscript>
public string function addChangeSet(
	required string action,
	string pkvalue,
	string ChangeUUID,
	any sql
) hint="I add a change set to the log." {

	var sArgs = StructCopy(Arguments);

	if ( NOT StructKeyExists(sArgs,"ChangeUUID") ) {
		sArgs.ChangeUUID = CreateUUID();
	}
	sArgs["Who"] = getWho();
	if ( StructKeyExists(sArgs,"sql") ) {
		sArgs["sql"] = Variables.DataMgr.readableSQL(sArgs.sql);
	}

	return Variables.DataMgr.insertRecord(tablename="audChangeSets",data=sArgs);
}

public string function hasReset(required string ChangeSetID) {
	var sArgs = {ChangeSetID=Arguments.ChangeSetID,action="restore"};

	return Variables.DataMgr.hasRecords(tablename="audChangeSets",data=sArgs);
}

public function convertArgs() {
	var sArgs = {};

	sArgs["tablename"] = Arguments.tablename;
	sArgs["action"] = Arguments.action;
	if ( StructKeyExists(Arguments,"ChangeUUID") ) {
		sArgs["ChangeUUID"] = Arguments.ChangeUUID;
	}
	if ( StructKeyExists(Arguments,"sql") ) {
		sArgs["sql"] = Arguments.sql;
	}
	if ( StructKeyExists(Arguments,"pkvalue") ) {
		sArgs["pkvalue"] = Arguments.pkvalue;
	}

	//Convert action arguments.
	if ( Arguments.action CONTAINS "insert" ) {
		sArgs["action"] = "insert";
	} else if ( Arguments.action CONTAINS "update" ) {
		sArgs["action"] = "update";
	} else if ( Arguments.action CONTAINS "delete" ) {
		sArgs["action"] = "delete";
	} else {
		// For now, only logging the above actions
		return false;
	}

	if (
		Arguments.action CONTAINS "after"
		OR
		StructKeyExists(Arguments, "after")
		OR
		( StructKeyExists(Arguments,"complete") AND Arguments.complete IS true )
	) {
		sArgs["DateCompleted"] = now();
	}

	//We won't know the primary key value yet for an insert
	if ( NOT ( StructKeyExists(Arguments,"pkvalue") AND Len(Arguments["pkvalue"]) ) ) {
		if ( StructKeyExists(Arguments,"data") AND StructCount(Arguments.data) ) {
			if ( sArgs["action"] NEQ "insert" AND NOT StructKeyExists(Arguments,"pkvalue") ) {
				Arguments["pkvalue"] = getPKValue(Arguments.tablename,Arguments.data);
			}
		}
	}

	return sArgs;
}

public function logAction(
	required string tablename,
	required string action,
	struct data,
	string ChangeUUID,
	any sql,
	any before,
	any after
) {

	var sArgs = {};
	var sDataChanges = {};
	var ChangeSetID = 0;
	var aChanges = 0;
	var ii = 0;
	var key = "";

	// Don't create an infinite loop by attempting to log the DataLogger tables.
	if ( Arguments.tablename CONTAINS "audChange" ) {
		return false;
	}

	// Only log tables that DataLogger has been requested to log.
	if ( NOT ListFindNoCase(Variables.logged_tables,Arguments.tablename) ) {
		return false;
	}

	sArgs = convertArgs(ArgumentCollection=Arguments);

	// ** Log the Change **
	if (
		StructKeyExists(Arguments,"data")
		AND
		StructKeyHasVal(Arguments.data,"DataLogger_ChangeSetID")
		AND
		hasReset(Arguments.data["DataLogger_ChangeSetID"])
	) {
		// In rare event where data specified a ChangeSetID, use it. Only current case: a restore
		ChangeSetID = Arguments.data["DataLogger_ChangeSetID"];
	} else {
		// The rest of the time, we'll create one.
		ChangeSetID = addChangeSet(ArgumentCollection=sArgs);
	}

	if ( sArgs["action"] EQ "update" ) {
		aChanges = getDataChanges(ArgumentCollection=Arguments);
		for  ( ii=1; ii LTE ArrayLen(aChanges); ii++ ) {
			// Make sure to track the change set
			aChanges[ii]["ChangeSetID"] = ChangeSetID;
			if ( StructCount(aChanges[ii]) GT 1 ) {
				// Save the change
				Variables.DataMgr.runSQLArray(
					Variables.DataMgr.insertRecordSQL(
						tablename="audChanges",
						OnExists="insert",
						data=aChanges[ii]
					)
				);
			}
		}
	}

}

public function logActionComplete(
	string ChangeUUID
) {

	var sWhere = {DateCompleted=""};
	var sSet = {DateCompleted=now()};

	if ( StructKeyExists(Arguments,"ChangeUUID") AND Len(Arguments.ChangeUUID) ) {
		try {
			// Set change set to completed
			Variables.DataMgr.updateRecords(
				tablename="audChangeSets",
				data_set=sSet,
				data_where=sWhere
			);
			// Record the primary key value for the change set if we got it and didn't have it before.
			if ( StructKeyExists(Arguments,"pkvalue") AND Len(Arguments.pkvalue) ) {
				sWhere = {ChangeUUID=Arguments.ChangeUUID,pkvalue=""};
				sSet = {pkvalue=Arguments.pkvalue};
				Variables.DataMgr.updateRecords(
					tablename="audChangeSets",
					data_set=sSet,
					data_where=sWhere
				);
			}
		} catch (any e) {
			catchError("logActionComplete",e,Arguments);
		}
	}

}

public function getLoggedTables() {
	return Variables.logged_tables;
}
</cfscript>

<cffunction name="isFieldChanged" access="public" returntype="any" output="no">
	<cfargument name="tablename" type="string" required="yes">
	<cfargument name="FieldName" type="string" required="yes">
	<cfargument name="pkvalue" type="string" required="yes">
	<cfargument name="withadd" type="boolean" default="true">
	<cfargument name="since" type="date" required="no">

	<cfset var qChanges = 0>

	<!--- Default time to within the last minute --->
	<cfif NOT StructKeyExists(Arguments,"since")>
		<cfset Arguments.since = DateAdd("n",-1,now())>
	</cfif>

	<cf_DMQuery name="qChanges">
	SELECT		s.ChangeSetID
	FROM		audChangeSets s
	LEFT JOIN	audChanges c
		ON		s.ChangeSetID = c.ChangeSetID
	WHERE		1 = 1
		AND		tablename = <cf_DMParam name="tablename" value="#Arguments.tablename#" cfsqltype="CF_SQL_VARCHAR">
		AND		pkvalue = <cf_DMParam name="pkvalue" value="#Arguments.pkvalue#" cfsqltype="CF_SQL_VARCHAR">
		AND		DateLogged >= <cf_DMParam name="since" value="#Arguments.since#" cfsqltype="CF_SQL_DATE">
		AND		(
					FieldName = <cf_DMParam name="FieldName" value="#Arguments.FieldName#" cfsqltype="CF_SQL_VARCHAR">
				<cfif Arguments.withadd>
					OR
					[Action] = 'insert'
				</cfif>
				)
	</cf_DMQuery>

	<cfreturn ( qChanges.RecordCount GT 0 )>
</cffunction>

<cfscript>
public function logTable(required string tablename) {
	
	Arguments.tablename = Trim(Arguments.tablename);

	if ( Len(Arguments.tablename) AND NOT ListFindNoCase(Variables.logged_tables,Arguments.tablename) ) {
		Variables.logged_tables = ListAppend(Variables.logged_tables,Arguments.tablename);
	}
}

public function logTables(required string tables) {
	var table = "";

	if ( ArrayLen(Arguments) GT 1 ) {
		Arguments.tables = ArrayToList(Arguments);
	}

	for ( table in Arguments.tables ) {
		logTable(table);
	}

}
</cfscript>

<cffunction name="restoreRecord" access="public" returntype="any" output="no" hint="I restore the record to the given point in time.">
	<cfargument name="tablename" type="string" required="yes">
	<cfargument name="pkvalue" type="string" required="yes">
	<cfargument name="when" type="date" required="yes">
	<cfargument name="fieldlist" type="string" required="no">

	<cfset var qRecord = getRecord(ArgumentCollection=Arguments)>
	<cfset var sRecord = {}>
	<cfset var pkfield = Variables.DataMgr.getPrimaryKeyFieldName(Arguments.tablename)>
	<cfset var sql_insert = 0>
	<cfset var ChangeSetID = 0>

	<cfif qRecord.RecordCount>
		<cfset sRecord = Variables.DataMgr.QueryRowToStruct(qRecord,qRecord.RecordCount)>
		<cfset sRecord[pkfield] = Arguments.pkvalue>

		<cfif Variables.DataMgr.hasRecords(Arguments.tablename,{"#pkfield#"=Arguments.pkvalue})>
			<cfset Variables.DataMgr.saveRecord(tablename=Arguments.tablename,data=sRecord)>
		<cfelse>
			<!--- Need ability to do identity insert on recovering deleted record. --->
			<cftransaction isolation="serializable">
				<cf_DMQuery sqlresult="sql_insert">
					SET IDENTITY_INSERT <cf_DMObject name="#Arguments.tablename#"> ON
					INSERT INTO <cf_DMObject name="#Arguments.tablename#"> (
						<cf_DMObject name="#pkfield#">
					) VALUES (
						<cf_DMParam value="#Arguments.pkvalue#" cfsqltype="CF_SQL_INTEGER">
					)
					SET IDENTITY_INSERT <cf_DMObject name="#Arguments.tablename#"> OFF
				</cf_DMQuery>
				<cfset ChangeSetID = addChangeSet(
					tablename=Arguments.tablename,
					action="restore",
					pkvalue=Arguments.pkvalue,
					sql=sql_insert
				)>
				<cfset sRecord["DataLogger_ChangeSetID"] = ChangeSetID>
				<cfset Variables.DataMgr.saveRecord(tablename=Arguments.tablename,data=sRecord)>
			</cftransaction>
		</cfif>
		<cfset addRestore(ArgumentCollection=Arguments)>
	<cfelse>
		<cfthrow type="DataLogger" message="Nothing to restore.">
	</cfif>

</cffunction>

<cffunction name="getUpdateSQLWithLogging" access="public" returntype="any" output="no">
	<cfargument name="tablename" type="string" required="yes">
	<cfargument name="set" type="struct" required="yes">
	<cfargument name="where" type="any" required="yes">
	<cfargument name="from" type="any" required="no">
	<cfargument name="tablealias" type="string" required="no">

	<cfscript>
	var aSQL = 0;
	var pkfield = Variables.DataMgr.getPrimaryKeyFieldName(Arguments.tablename);
	var aFields = 0;
	var aSetFields = [];
	var key = "";
	var sSet = 0;
	var ii = 0;
	var sql = Variables.DataMgr.readableSQL(getUpdateSQLFromParts(ArgumentCollection=Arguments));//ToDo: Need to get the SQL for the update

	for ( key in Arguments.set ) {
		ArrayAppend(aSetFields, {field=key, sql=Arguments.set[key]});
	}

	if ( NOT StructKeyHasLen(Arguments,"tablealias") ) {
		Arguments.tablealias = Arguments.tablename;
	}
	</cfscript>
	
	<cf_DMSQL name="aSQL">
			DECLARE @ChangeSetID INT;

			DECLARE @CurrentChange TABLE (
					ChangeSetID INT,
					pkvalue varchar(250)
			)

			DECLARE @Changes TABLE (
			<cfloop index="ii" from="1" to="#ArrayLen(aSetFields)#" step="1">
				<cf_DMObject name="Old_#ii#"> varchar(max),
				<cf_DMObject name="New_#ii#"> varchar(max),
			</cfloop>
				pkvalue varchar(250)
			);

			UPDATE	<cf_DMObject name="#Arguments.tablealias#">
			SET		
				<cfloop index="ii" from="1" to="#ArrayLen(aSetFields)#" step="1">
					<cfset sSet = aSetFields[ii]>
						<cf_DMObject name="#sSet.field#"> = <cf_DMSQL sql="#sSet.sql#" />
					<cfif ii LT ArrayLen(aSetFields)>
						,
					</cfif>
				</cfloop>
		<cfif StructKeyExists(Arguments,"from")>
			FROM	<cf_DMSQL sql="#Arguments.from#" />
		<cfelseif Arguments.tablealias NEQ Arguments.tablename>
			FROM	<cf_DMObject name="#Arguments.tablename#"> <cf_DMObject name="#Arguments.tablealias#" />
		</cfif>
			OUTPUT
			<cfloop array="#aSetFields#" index="sSet">
				CAST(DELETED.<cf_DMObject name="#sSet.field#"> AS VARCHAR(MAX)),
				CAST(INSERTED.<cf_DMObject name="#sSet.field#"> AS VARCHAR(MAX)),
			</cfloop>
				INSERTED.<cf_DMObject name="#pkfield#">
			INTO	@Changes
			WHERE	<cf_DMSQL sql="#Arguments.where#" />
			;


			INSERT INTO audChangeSets (
					tablename,
					[Action],
					DateLogged,
					Who,
					pkvalue,
					[SQL],
					DateCompleted
			)
			OUTPUT
					INSERTED.ChangeSetID,
					INSERTED.pkvalue
			INTO    @CurrentChange(ChangeSetID, pkvalue)
			SELECT
					<cf_DMParam name="table" value="#Arguments.tablename#" cfsqltype="CF_SQL_VARCHAR"> AS tablename,
					'update' AS [Action],
					getDate() AS DateLogged,
					<cf_DMParam name="Who" value="#getWho()#" cfsqltype="CF_SQL_VARCHAR"> AS Who,
					c.pkvalue AS pkvalue,
					<cf_DMParam name="sql" value="#sql#" cfsqltype="CF_SQL_VARCHAR"> AS [SQL],
					getDate() AS DateCompleted
			FROM    @Changes c
			
			;
		<cfloop index="ii" from="1" to="#ArrayLen(aSetFields)#" step="1">
			INSERT INTO audChanges (
					ChangeSetID,
					FieldName,
					OldValue,
					NewValue
			)
			SELECT	c.ChangeSetID,
					<cf_DMParam value="#aSetFields[ii].field#" cfsqltype="CF_SQL_VARCHAR">,
					ch.<cf_DMObject name="Old_#ii#">,
					ch.<cf_DMObject name="New_#ii#">
			FROM	@CurrentChange c
			JOIN	@Changes ch
				ON	c.pkvalue = ch.pkvalue
			;
		</cfloop>

	</cf_DMSQL>

	<cfreturn aSQL>
</cffunction>

<cffunction name="runUpdateWithLog" access="public" returntype="void" output="no">
	<cfargument name="tablename" type="string" required="yes">
	<cfargument name="set" type="struct" required="yes">
	<cfargument name="where" type="string" required="yes">

	<cf_DMQuery>
		<cf_DMSQL sql="#getUpdateSQLWithLogging(ArgumentCollection=Arguments)#" />
	</cf_DMQuery>

</cffunction>

<cfscript>
public function setDataTrashcan(required DataTrashcan) {
	
	Variables.DataTrashcan = Arguments.DataTrashcan;

}

public string function addRestore(
	required string tablename,
	required string pkvalue,
	required date when,
	string fieldlist
) {

	var sArgs = {
		"tablename"=Arguments.tablename,
		"pkvalue"=Arguments.pkvalue,
		"DateRestoredFrom"=Arguments.when
	};

	if ( StructKeyExists(Arguments,"fieldlist") ) {
		sArgs["fieldlist"] = Arguments.fieldlist;
	}

	return Variables.DataMgr.insertRecord(tablename="audRestores",data=sArgs);
}
</cfscript>

<cffunction name="getWhoNameSQL" access="package" returntype="any" output="no">
	<cfargument name="FieldNameSQL" type="any" required="true">

	<cfset var aSQL = 0>

	<cf_DMSQL name="aSQL">
		Who
	</cf_DMSQL>

	<cfreturn aSQL>
</cffunction>

<cfscript>
private query function getCurrentData(
	required string tablename,
	required struct data
) hint="I get the current data for the given record." {

	var sPKData = getPKData(Arguments.tablename,Arguments.data);
	var qRecord = Variables.DataMgr.getRecord(
		tablename=Arguments.tablename,
		data=sPKData,
		fieldlist=StructKeyList(Arguments.data)
	);

	return qRecord;
}

private function getDataChangeArgs(
	required string tablename,
	struct data,
	any before,
	any after
) hint="I get the data that has changed." {

	var sChangeArgs = {};

	if ( StructKeyExists(Arguments,"data") AND StructCount(Arguments.data) ) {
		sChangeArgs["data"] = Arguments.data;
	}

	//If data is supplied, but no before then assume this is done before the change and query the data.
	if ( StructKeyExists(sChangeArgs,"data") AND NOT StructKeyExists(Arguments,"before") ) {
		Arguments["before"] = getCurrentData(Arguments.tablename,Arguments.data);
	}

	if ( StructKeyExists(Arguments, "before") ) {

		sChangeArgs["before"] = Arguments.before;

		if ( isQuery(sChangeArgs["before"]) AND sChangeArgs["before"].RecordCount ) {
			sChangeArgs["before"] = QueryRowToStruct(sChangeArgs["before"]);
		}

		if ( NOT ( isStruct(sChangeArgs["before"]) AND StructCount(sChangeArgs["before"]) ) ) {
			StructDelete(sChangeArgs,"before");
		}

	}

	//If data is supplied, but no after then assume this is done and that the data change will take as supplied.
	if ( StructKeyExists(sChangeArgs,"data") AND NOT StructKeyExists(sChangeArgs,"after") ) {
		Arguments["after"] = sChangeArgs["data"];
	}

	if ( StructKeyExists(Arguments, "before") AND StructKeyExists(Arguments, "after") ) {

		sChangeArgs["after"] = Arguments.after;

		if ( isQuery(sChangeArgs["after"]) AND sChangeArgs["after"].RecordCount ) {
			sChangeArgs["after"] = QueryRowToStruct(sChangeArgs["after"]);
		}

		if ( NOT ( isStruct(sChangeArgs["after"]) AND StructCount(sChangeArgs["after"]) ) ) {
			StructDelete(sChangeArgs,"after");
		}

	}

	//If after is supplied, but no data then use the after as the data.
	if ( StructKeyExists(sChangeArgs,"after") AND NOT StructKeyExists(sChangeArgs,"data") ) {
		sChangeArgs["data"] = sChangeArgs["after"];
	}

	if ( StructCount(sChangeArgs) ) {
		sChangeArgs["tablename"] = Arguments.tablename;
	}

	return sChangeArgs;
}

private function getDataChanges(
	required string tablename,
	struct data,
	any before,
	any after
) hint="I get the data that has changed." {

	var sArgs = getDataChangeArgs(ArgumentCollection=Arguments);
	var qRecord = 0;
	var aResults = [];
	var sChange = [];
	var key = "";

	if ( StructCount(sArgs) ) {
		//Loop through the data fields provided (data changed in any other manner will have to be captured in the SQL passed in)
		for ( key in sArgs["data"] ) {
			//Make sure the field exists in the record (or nothing to compare to)
			if (
						StructKeyExists(sArgs,"before")
					AND StructKeyExists(sArgs["before"],key)
					AND isSimpleValue(sArgs["before"][key])
					AND StructKeyExists(sArgs,"after")
					AND StructKeyExists(sArgs["after"],key)
					AND isSimpleValue(sArgs["after"][key])
				) {
				//Only track if the data isn't the same
				if ( ListSort(sArgs["before"][key],"text") NEQ ListSort(sArgs["after"][key],"text") ) {
					sChange = {
						FieldName=key,
						OldValue=sArgs["before"][key],
						NewValue=sArgs["after"][key]
					};
					ArrayAppend(
						aResults,
						sChange
					);
				}
			}
		}
	}

	return aResults;
}

private void function registerListener() hint="I register a listener with Observer to listen for services being loaded." {
	Variables.Observer.registerListeners(
		Listener = This,
		ListenerName = "DataLogger",
		ListenerMethod = "logAction",
		EventNames = "DataMgr:afterInsert,DataMgr:afterDelete,DataMgr:afterUpdate"
	);
}

private function getPKData(
	required string tablename,
	required struct data
) hint="I get the primary key value for the given data." {

	var sResult = {};
	var pkfields = Variables.DataMgr.getPrimaryKeyFieldNames(Arguments.tablename);
	var pkfield = "";

	for ( pkfield in ListToArray(pkfields) ) {
		sResult[pkfield] = Arguments.data[pkfield];
	}

	return sResult;
}

private string function getPKValue(
	required string tablename,
	required struct data
) hint="I get the primary key value for the given data." {

	var result = "";
	var pkfields = Variables.DataMgr.getPrimaryKeyFieldNames(Arguments.tablename);
	var pkfield = "";

	for ( pkfield in ListToArray(pkfields) ) {
		result = ListAppend(result,Arguments.data[pkfield]);
	}

	return result;
}
</cfscript>

<cffunction name="getUpdateSQLFromParts" access="private" returntype="any" output="no" hint="I get the SQL for an update statement.">
	<cfargument name="tablename" type="string" required="yes">
	<cfargument name="set" type="struct" required="yes">
	<cfargument name="where" type="any" required="yes">
	<cfargument name="from" type="any" required="no">
	<cfargument name="tablealias" type="string" required="no">

	<cfscript>
	var aSQL = 0;
	var aSetFields = [];
	var key = "";
	var sSet = 0;
	var ii = 0;

	for ( key in Arguments.set ) {
		ArrayAppend(aSetFields, {field=key, sql=Arguments.set[key]});
	}

	if ( NOT StructKeyHasLen(Arguments,"tablealias") ) {
		Arguments.tablealias = Arguments.tablename;
	}
	</cfscript>

	<cf_DMSQL name="aSQL">
			UPDATE	<cf_DMObject name="#Arguments.tablealias#">
			SET		
				<cfloop index="ii" from="1" to="#ArrayLen(aSetFields)#" step="1">
					<cfset sSet = aSetFields[ii]>
						<cf_DMObject name="#sSet.field#"> = <cf_DMSQL sql="#sSet.sql#" />
					<cfif ii LT ArrayLen(aSetFields)>
						,
					</cfif>
				</cfloop>
		<cfif StructKeyExists(Arguments,"from")>
			FROM	<cf_DMSQL sql="#Arguments.from#" />
		<cfelseif Arguments.tablealias NEQ Arguments.tablename>
			FROM	<cf_DMObject name="#Arguments.tablename#"> <cf_DMObject name="#Arguments.tablealias#" />
		</cfif>
			WHERE	<cf_DMSQL sql="#Arguments.where#" />
	</cf_DMSQL>

	<cfreturn aSQL>
</cffunction>

<cffunction name="getDbXml" access="public" returntype="string" output="no" hint="I return the XML for the tables needed for SpamFilter.cfc to work.">

	<cfset var tableXML = "">

	<cfsavecontent variable="tableXML"><cfoutput>
	<tables>
		<table name="audChangeSets">
			<field ColumnName="ChangeSetID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="tablename" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="Action" CF_DataType="CF_SQL_VARCHAR" Length="50" />
			<field ColumnName="ChangeUUID" CF_DataType="CF_SQL_VARCHAR" Length="50" />
	        <field ColumnName="DateLogged" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
	        <field ColumnName="Who" CF_DataType="CF_SQL_VARCHAR" Length="250" />
	        <field ColumnName="pkvalue" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="SQL" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="DateCompleted" CF_DataType="CF_SQL_DATE" />
			<field ColumnName="DateDeleted" CF_DataType="CF_SQL_DATE" />
			<field ColumnName="DeletionReason" CF_DataType="CF_SQL_VARCHAR" Length="250" />
		</table>
		<table name="audChanges">
			<field ColumnName="ChangeID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="ChangeSetID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="FieldName" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="OldValue" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="NewValue" CF_DataType="CF_SQL_LONGVARCHAR" />
		</table>
		<table name="audRestores">
			<field ColumnName="RestoreID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="tablename" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="pkvalue" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="DateRestorePerformed" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
			<field ColumnName="DateRestoredFrom" CF_DataType="CF_SQL_DATE" />
		</table>
	</tables>
	</cfoutput></cfsavecontent>

	<cfreturn tableXML>
</cffunction>

</cfcomponent>
