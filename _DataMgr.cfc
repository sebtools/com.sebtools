<!--- 2.6 (Build 180) --->
<!--- Last Updated: 2017-08-08 --->
<!--- Created by Steve Bryant 2004-12-08 --->
<!--- Information: http://www.bryantwebconsulting.com/docs/datamgr/?version=2.5 --->
<cfcomponent displayname="Data Manager" hint="I manage data interactions with the database. I can be used to handle inserts/updates.">
<cfscript>
Variables.DataMgrVersion = "2.6";
Variables.DefaultDatasource = getDefaultDatasource();

public struct function ArgumentsFi() {
	
	// This is a fix for function being a reserved word in cfscript
	if (
		StructKeyExists(Arguments,"functionName")
		AND
		NOT StructKeyExists(Arguments,"function")
	) {
		Arguments["function"] = Arguments.functionName;
	}

	return Arguments;
}

/**
* I instantiate and return DataMgr.
* @databasename If DataMgr should manage in a different database than the default, indicate that here.
*/
public function init(
	string datasource="#Variables.DefaultDatasource#",
	string database,
	string username,
	string password,
	boolean SmartCache="false",
	string SpecialDateType="CF",
	string XmlData,
	string logfile,
	Observer,
	string databasename
) {
	var me = 0;

	Variables.datasource = Arguments.datasource;
	Variables.CFServer = Server.ColdFusion.ProductName;
	Variables.CFVersion = ListFirst(Server.ColdFusion.ProductVersion);
	Variables.SpecialDateType = Arguments.SpecialDateType;

	if ( StructKeyExists(Arguments,"username") AND StructKeyExists(Arguments,"password") ) {
		Variables.username = Arguments.username;
		Variables.password = Arguments.password;
	}

	if ( StructKeyExists(Arguments,"logfile") AND Len(Arguments.logfile) ) {
		Variables.logfile = Arguments.logfile;
	}

	if ( StructKeyExists(Arguments,"Observer") ) {
		Variables.Observer = Arguments.Observer;
	}

	if ( StructKeyExists(Arguments,"defaultdatabase") ) {
		Variables.defaultdatabase = Arguments.defaultdatabase;
	}

	Variables.SmartCache = Arguments.SmartCache;

	Variables.dbprefix = "";
	Variables.prefix = "";
	if ( StructKeyExists(Arguments,"databasename") ) {
		Variables.databasename = Arguments.databasename;
		Variables.dbprefix = "#Variables.databasename#.";
		if ( NOT StructKeyExists(Arguments,"owner") ) {
			Variables.owner = "dbo";
		}
		Variables.prefix = "#Variables.dbprefix#dbo.";
	}

	Variables.DataMgr = This;

	Variables.dbprops = getProps();
	Variables.tables = StructNew();// Used to internally keep track of table fields used by DataMgr
	Variables.tableprops = StructNew();// Used to internally keep track of tables properties used by DataMgr
	setCacheDate();// Used to internally keep track caching

	// instructions for special processing decisions
	Variables.nocomparetypes = "CF_SQL_LONGVARCHAR,CF_SQL_CLOB,CF_SQL_BLOB";// Don't run comparisons against fields of these cf_datatypes for queries
	Variables.dectypes = "CF_SQL_DECIMAL";// Decimal types (shouldn't be rounded by DataMgr)
	Variables.aggregates = "avg,count,max,min,sum";

	// Information for logging
	Variables.doLogging = false;
	Variables.logtable = "datamgrLogs";
	Variables.UUID = CreateUUID();

	// Code to run only if not in a database adaptor already
	if ( ListLast(getMetaData(this).name,".") EQ "DataMgr" ) {
		if ( NOT StructKeyExists(Arguments,"database") ) {
			addEngineEnhancements(true);
			Arguments.database = getDatabase();
		}

		// This will make sure that if a database is passed the component for that database is returned
		if ( StructKeyExists(Arguments,"database") ) {
			if ( StructKeyExists(Variables,"username") AND StructKeyExists(Variables,"password") ) {
				me = CreateObject("component","DataMgr_#Arguments.database#").init(ArgumentCollection=Arguments);
			} else {
				me = CreateObject("component","DataMgr_#Arguments.database#").init(ArgumentCollection=Arguments);
			}
		}
	} else {
		addEngineEnhancements(false);
		me = this;
	}

	if ( StructKeyExists(Arguments,"XmlData") ) {
		me.loadXml(Arguments.XmlData,true,true);
	}

	return me;
}

private void function addEngineEnhancements(boolean isLoadingDatabaseType=false) {
	var oMixer = 0;
	var key = "";

	if ( ListFirst(Variables.CFServer," ") EQ "ColdFusion" AND Variables.CFVersion GTE 8 ) {
		oMixer = CreateObject("component","DataMgrEngine_cf8");
	} else if ( Variables.CFServer EQ "BlueDragon" ) {
		oMixer = CreateObject("component","DataMgrEngine_openbd");
	} else if ( Variables.CFServer EQ "Railo" ) {
		oMixer = CreateObject("component","DataMgrEngine_railo");
	} else if ( Variables.CFServer EQ "Lucee" ) {
		oMixer = CreateObject("component","DataMgrEngine_lucee");
	}

	if ( isObject(oMixer) ) {
		for ( key in oMixer ) {
			if ( key NEQ "getDatabase" OR Arguments.isLoadingDatabaseType ) {
				Variables[key] = oMixer[key];
				if ( StructKeyExists(This,key) ) {
					This[key] = oMixer[key];
				}
			}
		}
	}
}

private string function getAdvSQLDelimiter(required string key) {
	switch(Arguments.key) {
		case "SELECT":
		case "ORDER BY":
		case "GROUP BY":
		case "HAVING":
		case "SET":
			return ",";
		case "WHERE":
			return "AND";
		default:
			return "";
	}
}

public void function addAdvSQL(
	required struct Args,
	required string key,
	required sql
) {
	var delim = getAdvSQLDelimiter(Arguments.key);
	var sql_start = "";

	//This just allows a string to be passed in for the SQL for simple cases.
	if ( isSimpleValue(Arguments.sql) ) {
		Arguments.sql = [Arguments.sql];
	}

	//If the SQL isn't usable, throw an exception.
	if ( NOT isArray(Arguments.sql) ) {
		throwDMError("The sql argument of addAdvSQL must be either a string or a sqlarray.");
	}

	//Make sure AdvSQL exists.
	if ( NOT StructKeyExists(Arguments.Args,"AdvSQL") ) {
		Arguments.Args["AdvSQL"] = {};
	}

	//Make sure this key for AdvSQL exists.
	if ( NOT StructKeyExists(Arguments.Args.AdvSQL,Arguments.key) ) {
		Arguments.Args["AdvSQL"][Arguments.key] = [];
	}

	//Make sure we include delimiter ahead of incoming sql if it is needed.
	if ( Len(delim) AND ArrayLen(Arguments.Args["AdvSQL"][Arguments.key]) ) {
		if ( isSimpleValue(Arguments.sql[1]) ) {
			sql_start = Trim(Arguments.sql[1]);
		}

		//If the SQL doesn't start with the delimiter, add it to the start
		//Not adding it to the end of AdvSQL, just in case multiple things are messing with that at once.
		if ( NOT ( Len(sql_start) GTE Len(delim) AND Left(sql_start,Len(delim)) EQ delim ) ) {
			ArrayPrepend(Arguments.sql," #delim# ");
		}
	}

	ArrayAppend(Arguments.Args["AdvSQL"][Arguments.key],Arguments.sql);
}

/**
* I add a value to a list field if it doesn't already exist. Can be used with any list value (not just relation fields).
*/
public void function addRelationListValue(
	required string tablename,
	required string pkvalue,
	required string field,
	required string	value
) {
	var pklist = getPrimaryKeyFieldNames(arguments.tablename);
	var sPKData = {"#pklist#":Arguments.pkvalue};
	var qRecord = getRecords(tablename=Arguments.tablename,data=sPKData,fieldlist=Arguments.field);
	var OldValue = qRecord[Arguments.field][1];
	var sData = StructCopy(sPKData);

	if ( NOT ListFindNoCase(OldValue,Arguments.value) ) {
		sData[Arguments.field] = ListAppend(OldValue,Arguments.value);
		saveRecord(
			tablename=Arguments.tablename,
			data=sData
		);
	}
}

/**
 * @param tablename The name of the table involved in the event.
 * @param action The action performed (e.g., insert, update, delete).
 * @param method The DataMgr method executed.
 * @param data The data passed to the method.
 * @param fieldlist (Optional)
 * @param Args The arguments passed to the method.
 * @param sql (Optional)
 * @param pkvalue (Optional)
 * @param ChangeUUID (Optional)
 * @return void
 * @access private
 */
private void function announceEvent(
	required string tablename,
	required string action,
	required string method,
	required struct data,
	string fieldlist = "",
	required struct Args,
	any sql,
	any pkvalue,
	string ChangeUUID
) {
	
	if ( StructKeyExists(variables, "Observer") AND StructKeyExists(variables.Observer, "announceEvent") ) {
		variables.Observer.announceEvent(
			EventName = "DataMgr:#arguments.action#",
			Args = Arguments
		);
	}

}

public void function setCacheDate() {
	variables.CacheDate = now();
}

public void function setObserver(any Observer) {
	variables.Observer = Arguments.Observer;
}

public string function getDefaultDatasource() {
	var result = "";

	try {
		if ( isDefined("Application") AND StructKeyExists(Application,"Datasource") ) {
			result = Application.Datasource;
		}
	} catch( any e) {

	}

	return result;
}

/**
* I return a clean version (stripped of MS-Word characters) of the given structure.
*/

public struct function clean(required struct Struct) {
	var key = "";
	var sResult = {};

	for  (key in arguments.Struct ) {
		if ( Len(key) AND StructKeyExists(arguments.Struct,key) AND isSimpleValue(arguments.Struct[key]) ) {
			// Trim the field value. -- Don't do it! This causes trouble with encrypted strings
			//sResult[key] = Trim(sResult[key]);
			// Replace the special characters that Microsoft uses.
			sResult[key] = arguments.Struct[key];
			sResult[key] = Replace(sResult[key], Chr(8211), "-", "ALL");// dashes
			sResult[key] = Replace(sResult[key], Chr(8212), "-", "ALL");// dashes
			sResult[key] = Replace(sResult[key], Chr(8216), Chr(39), "ALL");// apostrophe / single-quote
			sResult[key] = Replace(sResult[key], Chr(8217), Chr(39), "ALL");// apostrophe / single-quote
			sResult[key] = Replace(sResult[key], Chr(8220), Chr(34), "ALL");// quotes
			sResult[key] = Replace(sResult[key], Chr(8221), Chr(34), "ALL");// quotes
			sResult[key] = Replace(sResult[key], Chr(8230), "...", "ALL");// elipses
			sResult[key] = Replace(sResult[key], Chr(8482), "&trade;", "ALL");// trademark

			sResult[key] = Replace(sResult[key], "&##39;", Chr(39), "ALL");// apostrophe / single-quote
			sResult[key] = Replace(sResult[key], "&##160;", Chr(39), "ALL");// space
			sResult[key] = Replace(sResult[key], "&##8211;", "-", "ALL");// dashes
			sResult[key] = Replace(sResult[key], "&##8212;", "-", "ALL");// dashes
			sResult[key] = Replace(sResult[key], "&##8216;", Chr(39), "ALL");// apostrophe / single-quote
			sResult[key] = Replace(sResult[key], "&##8217;", Chr(39), "ALL");// apostrophe / single-quote
			sResult[key] = Replace(sResult[key], "&##8220;", Chr(34), "ALL");// quotes
			sResult[key] = Replace(sResult[key], "&##8221;", Chr(34), "ALL");// quotes
			sResult[key] = Replace(sResult[key], "&##8230;", "...", "ALL");// elipses
			sResult[key] = Replace(sResult[key], "&##8482;", "&trade;", "ALL");// trademark
		}
	}

	return sResult;
}

/**
* I take a table (for which the structure has been loaded) and create the table in the database.
*/
public string function createTable(required string tablename) {
	var CreateSQL = getCreateSQL(arguments.tablename);
	var thisSQL = "";

	var arrFields = getFields(arguments.tablename);// table structure
	var sField = 0;
	var increments = 0;

	// Make sure table has no more than one increment field --->
	for ( sField in arrFields ) {
		if ( sField.Increment ) {
			increments++;
		}
	}
	if ( increments GT 1 ) {
		throwDMError("#arguments.tablename# has more than one increment field. A table is limited to only one increment field.","MultipleIncrements");
	}

	StructDelete(variables,"cache_dbtables");

	//try to create table
	try {
		for ( thisSQL in ListToArray(CreateSQL,";") ) {
			if ( thisSQL CONTAINS " " ) {
				//Ugly hack to get around Oracle's need for a semi-colon in SQL that doesn't split up SQL commands
				thisSQL = ReplaceNoCase(thisSQL,"|DataMgr_SemiColon|",";","ALL");
				runSQL(thisSQL);
			}
		}
	} catch( any err ) {
		//If the ceation fails, throw an error with the sql code used to create the database.
		if (
			NOT (
				err.Message CONTAINS "There is already an object named"
				OR
				(
					StructKeyExists(err,"Cause")
					AND
					StructKeyExists(err.Cause,"Message")
					AND
					err.Cause.Message CONTAINS "There is already an object named"
				)
			)
		) {
			throwDMError("SQL Error in Creation. Verify Datasource (#chr(34)##variables.datasource##chr(34)#) is valid.","CreateFailed",CreateSQL);
		}
	}

	setCacheDate();

	return CreateSQL;
}

/**
* I indicate whether or not the given table exists in the database.
*/
public boolean function dbtableexists(
	required string tablename,
	string dbtables
) {
	var result = false;
	var qTest = 0;

	if ( NOT ( StructKeyExists(arguments,"dbtables") AND Len(Trim(arguments.dbtables)) ) ) {
		arguments.dbtables = "";
		try {
			//Try to get a list of tables load in DataMgr
			arguments.dbtables = getDatabaseTablesCache();
		} catch( any err ) {

		}
	}

	if ( Len(arguments.dbtables) ) {// If we have tables loaded in DataMgr
		if ( ListFindNoCase(arguments.dbtables, arguments.tablename) ) {
			result = true;
		}
	}
	// SEB 2010-04-25: This seems a tad aggresive (a lot of penalty for a just in case measure). Let's ditch it unless it proves essential.
	if ( false AND NOT result ) {
		result = true;
		try {// create any table on which a select statement errors
			qTest = runSQL("SELECT #getMaxRowsPrefix(1)# #escape(variables.tables[arguments.tablename][1].ColumnName)# FROM #escape(arguments.tablename)# #getMaxRowsSuffix(1)#");
		} catch( any err ) {
			result = false;
		}
	}

	return result;
}

/**
* I create any tables that I know should exist in the database but don't.
* @tables A list of tables to create. If not provided, createTables will try to create any table that has been loaded into it but does not exist in the database.
* @dbtables A list of tables that exist in the database. If not provided, createTables will try to get a list of tables from the database.
*/
public string function CreateTables(
	string tables,
	string dbtables
) {
	var table = "";
	var tablesExist = {};
	var qTest = 0;
	var FailedSQL = "";
	var DBErr = "";
	var result = "";

	if ( NOT StructKeyExists(arguments,"tables") ) {
		arguments.tables = StructKeyList(variables.tables);
	}

	if ( NOT ( StructKeyExists(arguments,"dbtables") AND Len(Trim(arguments.dbtables)) ) ) {
		arguments.dbtables = "";
		try {
		// Try to get a list of tables load in DataMgr
			arguments.dbtables = getDatabaseTablesCache();
		} catch (any err) {

		}
	}

	for ( table in ListToArray(arguments.tables) ) {
		// Create table if it doesn't exist
		if ( NOT dbtableexists(table,arguments.dbtables) ) {
			try {
				createTable(table);
				arguments.dbtables = ListAppend(arguments.dbtables,table);
				result = ListAppend(result,table);
			}
			catch (DataMgr err) {
				if ( Len(err.Detail) ) {
					FailedSQL = ListAppend(FailedSQL,err.Detail,";");
				} else {
					FailedSQL = ListAppend(FailedSQL,err.Message,";");
				}
				if ( Len(err.ExtendedInfo) ) {
					DBErr = err.ExtendedInfo;
				}
			}
		}
	}

	if ( Len(FailedSQL) ) {
		throwDMError("SQL Error in Creation. Verify Datasource (#chr(34)##variables.datasource##chr(34)#) is valid.","CreateFailed",FailedSQL,DBErr);
	}

	return result;
}

/**
* I delete the record with the given Primary Key(s).
* @tablename The name of the table from which to delete a record.
* @data A structure indicating the record to delete. A key indicates a field. The structure should have a key for each primary key in the table.
*/
public void function deleteRecord(
	required string tablename,
	required data
) {
	var i = 0;// just a counter
	var fields = getUpdateableFields(arguments.tablename);
	var pkfields = getPKFields(arguments.tablename);// the primary key fields for this table
	var rfields = getRelationFields(arguments.tablename);// relation fields in table
	var sData = arguments.data;// The incoming data structure
	var isLogicalDelete = isLogicalDeletion(arguments.tablename);
	var qRecord = 0;
	var sqlarray = [];
	var out = 0;
	var temp2 = 0;
	//var qRelationList = 0;
	//var subdatum = {};
	//var sArgs = {};
	var conflicttables = "";
	var sCascadeDeletions = 0;
	var ChangeUUID = CreateUUID();
	var sAnnounceArgs = 0;
	var sLog = 0;
	var sEvent = 0;

	var pklist = getPrimaryKeyFieldNames(arguments.tablename);

	// Throw exception if any pkfields are missing from incoming data
	for ( i=1; i LTE ArrayLen(pkfields); i++ ) {
		if ( NOT StructKeyExists(sData,pkfields[i].ColumnName) ) {
			throwDMError("All Primary Key fields (#pklist#) must be used when deleting a record. (Passed = #StructKeyList(sData)#, Table=#arguments.tablename#)","RequiresAllPkFields");
		}
	}

	// Only get records by primary key
	for ( temp2 in sData ) {
		if ( NOT ListFindNoCase(pklist,temp2) ) {
			StructDelete(sData,temp2);
		}
	}
	arguments.data = sData;

	// Get the record containing the given data
	qRecord = getRecord(arguments.tablename,sData);

	if ( qRecord.RecordCount EQ 1 ) {
		// Look for onDelete errors
		conflicttables = getDeletionConflicts(tablename=arguments.tablename,data=arguments.data,qRecord=qRecord);
		if ( Len(conflicttables) ) {
			throwDMError("You cannot delete a record in #arguments.tablename# when associated records exist in #conflicttables#.","NoDeletesWithRelated");
		}
		
		sAnnounceArgs = {
			tablename="#arguments.tablename#",
			action="beforeDelete",
			data="#arguments.data#",
			Args="#Arguments#",
			ChangeUUID="#ChangeUUID#",
			method="deleteRecord"
		};
		if ( ArrayLen(pkfields) EQ 1 AND StructKeyExists(sData,pkfields[1].ColumnName) ) {
			sAnnounceArgs["pkvalue"] = sData[pkfields[1].ColumnName];
		}
		announceEvent(ArgumentCollection=sAnnounceArgs);

		// Look for onDelete cascade
		sCascadeDeletions = getCascadeDeletions(tablename=arguments.tablename,data=arguments.data,qRecord=qRecord);
		for ( temp2 in sCascadeDeletions ) {
			deleteRecords(tablename=temp2,data=sCascadeDeletions[temp2]);
		}

		// Perform the delete
		if ( isLogicalDelete ) {
			// Look for DeletionMark field
			for ( i=1; i LTE ArrayLen(fields); i++ ) {
				if ( StructKeyExists(fields[i],"Special") AND fields[i].Special EQ "DeletionMark" ) {
					if ( fields[i].CF_DataType EQ "CF_SQL_BIT" ) {
						sData[fields[i].ColumnName] = 1;
					} else if ( fields[i].CF_DataType EQ "CF_SQL_DATE" OR fields[i].CF_DataType EQ "CF_SQL_DATETIME" ) {
						sData[fields[i].ColumnName] = now();
					}
				}
			}
			updateRecord(arguments.tablename,sData);
		} else {
			// Delete Record
			sqlarray = ArrayNew(1);
			ArrayAppend(sqlarray,"DELETE FROM	#escape(Variables.prefix & arguments.tablename)# WHERE	1 = 1");
			ArrayAppend(sqlarray,getWhereSQL(argumentCollection=arguments));

			runSQLArray(sqlarray);

			//Log delete
			if ( Variables.doLogging AND NOT arguments.tablename EQ variables.logtable ) {
				sLog = {
					"action":"delete",
					"data":sData,
					"sql":sqlarray
				};
				if ( ArrayLen(pkfields) EQ 1 AND StructKeyExists(sData,pkfields[1].ColumnName) ) {
					sLog["pkval"] = "#sData[pkfields[1].ColumnName]#";
				}
				logAction(ArgumentCollection=sLog);
			}
		}

		sEvent = {
			tablename="#arguments.tablename#",
			action="afterDelete",
			data="#arguments.data#",
			Args="#Arguments#",
			ChangeUUID="#ChangeUUID#",
			method="deleteRecord"
		};
		if ( ArrayLen(pkfields) EQ 1 AND StructKeyExists(sData,pkfields[1].ColumnName) ) {
			sEvent["pkvalue"] = sData[pkfields[1].ColumnName];
		}
		if ( isArray(sqlarray) AND ArrayLen(sqlarray) ) {
			sEvent["sql"] = sqlarray;
		}
		announceEvent(ArgumentCollection=sEvent);

		setCacheDate();
	}
}

/**
* I delete the records with the given data.
* @tablename The name of the table from which to delete a record.
* @data A structure indicating the record to delete. A key indicates a field. The structure should have a key for each primary key in the table.
*/
public void function deleteRecords(
	required string tablename,
	required struct data={}
) {
	var qRecords = getRecords(tablename=arguments.tablename,data=arguments.data,fieldlist=getPrimaryKeyFieldNames(arguments.tablename));
	var out = 0;

	for ( out in qRecords ) {
		deleteRecord(arguments.tablename,out);
	}

}

public string function getBooleanSqlValue(required string value) {
	var result = "NULL";

	if ( isBoolean(arguments.value) ) {
		if ( arguments.value ) {
			result = "1";
		} else {
			result = "0";
		}
	}

	return result;
}

/**
* @tablename The name of the table from which to delete a record.
* @data A structure indicating the record to delete. A key indicates a field. The structure should have a key for each primary key in the table.
*/
public struct function getCascadeDeletions(
	required string tablename,
	required struct data
) {
	var rfields = getRelationFields(arguments.tablename);// relation fields in table
	var ii = 0;
	var sResult = {};

	if ( NOT StructKeyExists(arguments,"qRecord") ) {
		arguments.qRecord = getRecord(tablename=arguments.tablename,data=arguments.data);
	}

	for ( ii=1; ii LTE ArrayLen(rfields); ii++ ) {
		if (
				(
						ListFindNoCase(variables.aggregates,rfields[ii].Relation["type"])
					OR	rfields[ii].Relation["type"] EQ "list"
				)
			AND	(
						(
								StructKeyExists(rfields[ii].Relation,"onDelete")
							AND	rfields[ii].Relation["onDelete"] EQ "Cascade"
						)
					OR	(
								StructKeyExists(rfields[ii].Relation,"join-table")
							AND	NOT (
										StructKeyExists(rfields[ii].Relation,"onDelete")
									AND	rfields[ii].Relation["onDelete"] NEQ "Cascade"
								)
						)
				)
			AND	(
						StructKeyExists(rfields[ii].Relation,"table")
					AND	NOT StructKeyExists(sResult,rfields[ii].Relation["table"])
				)
		) {
			if ( StructKeyExists(rfields[ii].Relation,"join-table") ) {
				sResult[rfields[ii].Relation["join-table"]] = {};
				sResult[rfields[ii].Relation["join-table"]][rfields[ii].Relation["join-table-field-local"]] = arguments.qRecord[rfields[ii].Relation["local-table-join-field"]][1];
			} else {
				sResult[rfields[ii].Relation["table"]] = {};
				sResult[rfields[ii].Relation["table"]][rfields[ii].Relation["join-field-remote"]] = arguments.qRecord[rfields[ii].Relation["join-field-local"]][1];
			}
		}
	}

	return sResult;
}

public string function getCheckFields(required string tablename) {
	
	if (
		StructKeyExists(variables.tableprops,arguments.tablename)
		AND
		StructKeyExists(variables.tableprops[arguments.tablename],"checkfields")
	) {
		return variables.tableprops[arguments.tablename]["checkfields"];
	} else {
		return "";
	}
}

public function getConstraintConflicts(
	required string tablename,
	string ftable,
	string field
) {
	var result = 0;

	if ( StructKeyExists(Arguments,"ftable") ) {
		result = getConstraintConflicts_Field(ArgumentCollection=Arguments);
	} else {
		result = getConstraintConflicts_Table(ArgumentCollection=Arguments);
	}

	return result;
}

/**
* I return the database platform being used.
*/
public string function getDataBase() {
	var connection = 0;
	var db = "";
	var type = "";
	//var qDatabases = getSupportedDatabases();

	if ( Len(variables.datasource) ) {
		try {
			connection = getConnection();
		} catch ( any e) {
			if ( StructKeyExists(variables,"defaultdatabase") ) {
				type = variables.defaultdatabase;
			} else {
				try {
					connection.close();
				} catch ( any e2) {

				}
				if ( e.Message CONTAINS "Permission denied" ) {
					throwDMError("DataMgr was unable to determine database type.","DatabaseTypeRequired","DataMgr was unable to determine database type. Please pass the database argument (second argument of init method) to DataMgr.");
				} else {
					rethrow;
				}
			}
		}
		db = connection.getMetaData().getDatabaseProductName();
		connection.close();

		switch (db) {
			case "Microsoft SQL Server":
					type = "MSSQL";
				break;
			case "MySQL":
					type = "MYSQL";
				break;
			case "PostgreSQL":
					type = "PostGreSQL";
				break;
			case "Oracle":
					type = "Oracle";
				break;
			case "MS Jet":
					type = "Access";
				break;
			case "Apache Derby":
					type = "Derby";
				break;
			default:
					if ( ListFirst(db,"/") EQ "DB2" ) {
						type = "DB2";
					} else {
						type = "unknown";
						type = db;
					}
		}
	} else {
		type = "Sim";
	}

	return type;
}

/**
* I return some properties about this database.
*/
public struct function getDatabaseProperties() {
	var sProps = {};

	return sProps;
}

/**
 * I return the string that can be found in the driver or JDBC URL for the database platform being used.
 */
public string function getDatabaseShortString() {
	return "unknown"; // This method will get overridden in database-specific DataMgr components
}

/**
 * I return the string that can be found in the driver or JDBC URL for the database platform being used.
 */
public string function getDatabaseDriver() {
	return "";
}

/**
 * I return the datasource used by this Data Manager.
 * @return {string} The datasource.
 */
public string function getDatasource() {
	return variables.datasource;
}

/**
 * I return a list of fields in the database for the given table.
 * @param {string} tablename The name of the table.
 * @return {string} The list of fields.
 */
public string function getDBFieldList(required string tablename) {
	var qFields = runSQL("SELECT #getMaxRowsPrefix(1)# * FROM #escape(arguments.tablename)# #getMaxRowsSuffix(1)#");
	
	return qFields.ColumnList;
}

public struct function getDefaultValues(required string tablename) {
	var sFields = 0;
	var aFields = 0;
	var ii = 0;

	// If fields data if stored
	if ( StructKeyExists(variables.tableprops,arguments.tablename) AND StructKeyExists(variables.tableprops[arguments.tablename],"fielddefaults") ) {
		sFields = variables.tableprops[arguments.tablename]["fielddefaults"];
	} else {
		aFields = getFields(arguments.tablename);
		sFields = {};
		// Get fields with length and set key appropriately
		for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
			if ( StructKeyExists(aFields[ii],"Default") AND Len(aFields[ii].Default) ) {
				sFields[aFields[ii].ColumnName] = aFields[ii].Default;
			} else {
				sFields[aFields[ii].ColumnName] = "";
			}
		}
		variables.tableprops[arguments.tablename]["fielddefaults"] = sFields;
	}

	return sFields;
}

/**
* I get any deletion conflicts for the given table and data.
* @tablename The name of the table from which to delete a record.
* @data A structure indicating the record to delete. A key indicates a field. The structure should have a key for each primary key in the table.
*/
public string function getDeletionConflicts(
	required string tablename,
	required struct data
) {
	var rfields = getRelationFields(arguments.tablename);// relation fields in table
	var ii = 0;
	var subdatum = 0;
	var sArgs = 0;
	var qRelationList = 0;
	var result = "";

	if ( NOT StructKeyExists(arguments,"qRecord") ) {
		arguments.qRecord = getRecord(tablename=arguments.tablename,data=arguments.data);
	}

	for ( ii=1; ii LTE ArrayLen(rfields); ii++ ) {
		if (
				(
						StructKeyExists(rfields[ii].Relation,"onDelete")
					AND	rfields[ii].Relation["onDelete"] EQ "Error"
				)
			AND	(
						StructKeyExists(rfields[ii].Relation,"table")
					AND	NOT ListFindNoCase(result,rfields[ii].Relation["table"])
				)
			AND	(
						rfields[ii].Relation["type"] EQ "list"
					OR	ListFindNoCase(variables.aggregates,rfields[ii].Relation["type"])
				)
		) {
			sArgs = {};
			subdatum = {};
			subdatum.data = {};
			subdatum.advsql = {};

			if ( StructKeyExists(rfields[ii].Relation,"join-table") ) {
				subdatum.subadvsql = {};
				subdatum.subadvsql.WHERE = "#escape( rfields[ii].Relation['join-table'] & '.' & rfields[ii].Relation['join-table-field-remote'] )# = #escape( rfields[ii].Relation['table'] & '.' & rfields[ii].Relation['remote-table-join-field'] )#";
				subdatum.data[rfields[ii].Relation["local-table-join-field"]] = arguments.qRecord[rfields[ii].Relation["join-table-field-local"]][1];
				subdatum.advsql.WHERE = [];
				ArrayAppend(subdatum.advsql.WHERE,"EXISTS (");
				ArrayAppend(subdatum.advsql.WHERE,getRecordsSQL(tablename=rfields[ii].Relation["join-table"],data=subdatum.data,advsql=subdatum.subadvsql,isInExists=true));
				ArrayAppend(subdatum.advsql.WHERE,")");
			} else {
				subdatum.data[rfields[ii].Relation["join-field-remote"]] = arguments.qRecord[rfields[ii].Relation["join-field-local"]][1];
			}

			sArgs["tablename"] = rfields[ii].Relation["table"];
			sArgs["data"] = subdatum.data;
			sArgs["fieldlist"] = rfields[ii].Relation["field"];
			sArgs["advsql"] = subdatum.advsql;
			if ( StructKeyExists(rfields[ii].Relation,"filters") AND isArray(rfields[ii].Relation.filters) ) {
				sArgs["filters"] = rfields[ii].Relation.filters;
			}

			qRelationList = getRecords(argumentCollection=sArgs);

			if ( qRelationList.RecordCount ) {
				result = ListAppend(result,rfields[ii].Relation.table);
			}
		}
	}

	return result;
}

/**
* I return SQL that indicates if the given record in the given table is deletable.
* @tablename The name of the table from which to delete a record.
*/
public array function getIsDeletableSQL(required string tablename) {
	var rfields = getRelationFields(arguments.tablename);// relation fields in table
	var ii = 0;
	var sArgs = 0;
	var aSQL = [];
	var tables = "";
	var hasNestedSQL = false;

	if ( NOT StructKeyExists(arguments,"tablealias") ) {
		arguments.tablealias = arguments.tablename;
	}

	if ( StructKeyExists(arguments,"ignore") ) {
		tables = arguments.ignore;
	}

	ArrayAppend(
		aSQL,
		"
		(
			CASE
			WHEN (
					1 = 1
		"
	);
	for ( ii=1; ii LTE ArrayLen(rfields); ii++ ) {
		if (
				(
						StructKeyExists(rfields[ii].Relation,"table")
					AND	NOT ListFindNoCase(tables,rfields[ii].Relation["table"])
				)
			AND	(
						rfields[ii].Relation["type"] EQ "list"
					OR	ListFindNoCase(variables.aggregates,rfields[ii].Relation["type"])
				)
			AND	(
						StructKeyExists(rfields[ii].Relation,"onDelete")
					AND	(
								rfields[ii].Relation["onDelete"] EQ "Error"
							OR	rfields[ii].Relation["onDelete"] EQ "Cascade"
						)
				)
		) {
			tables = ListAppend(tables,rfields[ii].Relation["table"]);
			sArgs = StructNew();
			sArgs["tablename"] = rfields[ii].Relation["table"];
			sArgs["tablealias"] = sArgs["tablename"];
			if ( sArgs["tablealias"] EQ arguments.tablealias ) {
				sArgs["tablealias"] = sArgs["tablealias"] & "_DataMgr_inner";
			}
			if ( rfields[ii].Relation["onDelete"] EQ "Error" ) {//  OR (  StructKeyExists(variables.tableprops[sArgs["tablename"]],"deletable") )
				sArgs["isInExists"] = true;
				sArgs["fieldlist"] = rfields[ii].Relation["field"];
				sArgs["ignore"] = arguments.tablename;
				if ( StructKeyExists(rfields[ii].Relation,"filters") AND isArray(rfields[ii].Relation.filters) ) {
					sArgs["filters"] = rfields[ii].Relation.filters;
				}
				sArgs["advsql"] = StructNew();
				sArgs["advsql"]["WHERE"] = ArrayNew(1);
				if ( StructKeyExists(rfields[ii].Relation,"join-table") ) {
					sArgs["tablename"] = rfields[ii].Relation["join-table"];
					StructDelete(sArgs,"tablealias");
					sArgs["join"] = StructNew();
					sArgs["join"]["table"] = rfields[ii].Relation["table"];
					sArgs["join"]["type"] = "INNER";
					sArgs["join"]["onright"] = rfields[ii].Relation["remote-table-join-field"];
					sArgs["join"]["onleft"] = rfields[ii].Relation["join-table-field-remote"];
					ArrayAppend(sArgs["advsql"]["WHERE"],getFieldSelectSQL(tablename=rfields[ii].Relation["join-table"],field=rfields[ii].Relation["join-table-field-local"],tablealias=rfields[ii].Relation["join-table"],useFieldAlias=false));
					ArrayAppend(sArgs["advsql"]["WHERE"]," = ");
					ArrayAppend(sArgs["advsql"]["WHERE"],getFieldSelectSQL(tablename=arguments.tablename,field=rfields[ii].Relation['local-table-join-field'],tablealias=arguments.tablealias,useFieldAlias=false));
				} else {
					ArrayAppend(sArgs["advsql"]["WHERE"],getFieldSelectSQL(tablename=sArgs.tablename,field=rfields[ii].Relation['join-field-remote'],tablealias=sArgs.tablealias,useFieldAlias=false));
					ArrayAppend(sArgs["advsql"]["WHERE"]," = ");
					ArrayAppend(sArgs["advsql"]["WHERE"],getFieldSelectSQL(tablename=arguments.tablename,field=rfields[ii].Relation['join-field-local'],tablealias=arguments.tablealias,useFieldAlias=false));
				}


				ArrayAppend(aSQL,"AND	NOT EXISTS (");
					ArrayAppend(aSQL,getRecordsSQL(argumentCollection=sArgs));
				ArrayAppend(aSQL,")");
			} else if ( rfields[ii].Relation["onDelete"] NEQ "Ignore" ) {
				sArgs["ignore"] = arguments.tablename;
				ArrayAppend(aSQL,"	AND	(");
				ArrayAppend(aSQL,"			NOT EXISTS (");
				ArrayAppend(aSQL,"				SELECT		1");
				if ( StructKeyExists(rfields[ii].Relation,"join-table") ) {
					sArgs["tablename"] = rfields[ii].Relation["join-table"];
					StructDelete(sArgs,"tablealias");
					ArrayAppend(aSQL,"				FROM		#escape(rfields[ii].Relation['join-table'])#");
					ArrayAppend(aSQL,"			INNER JOIN	#escape(rfields[ii].Relation["table"])#");
					ArrayAppend(aSQL,"				ON		#escape(rfields[ii].Relation["join-table"])#.#escape(rfields[ii].Relation["join-table-field-remote"])# = #escape(rfields[ii].Relation['table'])#.#escape(rfields[ii].Relation["remote-table-join-field"])#");
				} else {
					ArrayAppend(aSQL,"				FROM		#escape(rfields[ii].Relation['table'])#");
					}
				ArrayAppend(aSQL,"				WHERE		1 = 1");
				ArrayAppend(aSQL,"					AND		(");
				if ( StructKeyExists(rfields[ii].Relation,"join-table") ) {
					ArrayAppend(aSQL,getFieldSelectSQL(tablename=arguments.tablename,field=rfields[ii].Relation['local-table-join-field'],tablealias=arguments.tablealias,useFieldAlias=false));
					ArrayAppend(aSQL," = ");
					ArrayAppend(aSQL,getFieldSelectSQL(tablename=rfields[ii].Relation["join-table"],field=rfields[ii].Relation["join-table-field-local"],tablealias=rfields[ii].Relation["join-table"],useFieldAlias=false));
				} else {
					ArrayAppend(aSQL,getFieldSelectSQL(tablename=sArgs.tablename,field=rfields[ii].Relation['join-field-remote'],tablealias=sArgs.tablealias,useFieldAlias=false));
					ArrayAppend(aSQL," = ");
					ArrayAppend(aSQL,getFieldSelectSQL(tablename=arguments.tablename,field=rfields[ii].Relation['join-field-local'],tablealias=arguments.tablealias,useFieldAlias=false));
				}
				ArrayAppend(aSQL,"							)");
				ArrayAppend(aSQL,"					AND		(");
				ArrayAppend(aSQL,"									1 = 0");
				ArrayAppend(aSQL,"								OR	(");

				ArrayAppend(aSQL,getIsDeletableSQL(argumentCollection=sArgs));

				ArrayAppend(aSQL,"									) = 0");
					ArrayAppend(aSQL,"						)");
				ArrayAppend(aSQL,"			)");
				ArrayAppend(aSQL,"		)");
			}
			hasNestedSQL = true;
		}
	}
	ArrayAppend(
		aSQL,
		"
			)
			THEN #getBooleanSqlValue(true)#
			ELSE #getBooleanSqlValue(false)#
			END
		)
		"
	);

	if ( NOT hasNestedSQL ) {
		aSQL = [];
		ArrayAppend(aSQL,getBooleanSqlValue(true));
	}

	return aSQL;
}

/*
*I get a list of fields in DataMgr for the given table.
*/
public string function getFieldList(required string tablename) {
	var ii = 0;
	var fieldlist = "";
	var bTable = checkTable(arguments.tablename);

	if ( StructKeyExists(variables.tableprops,arguments.tablename) AND StructKeyExists(variables.tableprops[arguments.tablename],"fieldlist") ) {
		fieldlist = variables.tableprops[arguments.tablename]["fieldlist"];
	} else {
		// Loop over the fields in the table and make a list of them
		if ( StructKeyExists(variables.tables,arguments.tablename) ) {
			for ( ii=1; ii LTE ArrayLen(variables.tables[arguments.tablename]); ii++ ) {
				fieldlist = ListAppend(fieldlist, variables.tables[arguments.tablename][ii].ColumnName);
			}
		}
		variables.tableprops[arguments.tablename]["fieldlist"] = fieldlist;
	}

	return fieldlist;
}

/**
* I return a structure of the field lengths for fields where this is relevant.
*/
public struct function getFieldLengths(required string tablename) {
	var sFields = 0;
	var aFields = 0;
	var ii = 0;

	// If fields data if stored
	if ( StructKeyExists(variables.tableprops,arguments.tablename) AND StructKeyExists(variables.tableprops[arguments.tablename],"fieldlengths") ) {
		sFields = variables.tableprops[arguments.tablename]["fieldlengths"];
	} else {
		aFields = getFields(arguments.tablename);
		sFields = {};
		// Get fields with length and set key appropriately
		for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
			if (
					StructKeyExists(aFields[ii],"Length")
				AND	isNumeric(aFields[ii].Length)
				AND	aFields[ii].Length GT 0
				AND	FindNoCase("char",aFields[ii].CF_DataType)
				AND NOT FindNoCase("long",aFields[ii].CF_DataType)
			) {
				sFields[aFields[ii].ColumnName] = aFields[ii].Length;
			}
		}
		variables.tableprops[arguments.tablename]["fieldlengths"] = sFields;
	}

	return sFields;
}

/**
* I return an array of all real fields in the given table in DataMgr.
*/
public array function getFields(required string tablename) {
	var ii = 0;// counter
	var arrFields = [];// array of fields
	var bTable = checkTable(arguments.tablename);// Check whether table is loaded

	// If fields data if stored
	if ( StructKeyExists(variables.tableprops,arguments.tablename) AND StructKeyExists(variables.tableprops[arguments.tablename],"fields") ) {
		arrFields = variables.tableprops[arguments.tablename]["fields"];
	} else {
		// Loop over the fields and make an array of them
		for ( ii=1; ii LTE ArrayLen(variables.tables[arguments.tablename]); ii++ ) {
			if ( StructKeyExists(variables.tables[arguments.tablename][ii],"CF_DataType") AND NOT StructKeyExists(variables.tables[arguments.tablename][ii],"Relation") ) {
				ArrayAppend(arrFields, variables.tables[arguments.tablename][ii]);
			}
		}
		variables.tableprops[arguments.tablename]["fields"] = arrFields;
	}

	return arrFields;
}

/**
* I get the SQL before the field list in the select statement to limit the number of rows.
*/
public string function getMaxRowsPrefix(
	required numeric maxrows,
	numeric offset=0
) {
	return "TOP #arguments.maxrows+arguments.offset# ";
}

/**
* I get the SQL after the query to limit the number of rows.
*/
public string function getMaxRowsSuffix(
	required numeric maxrows,
	numeric offset=0
) {
	return "";
}

/**
* I get the SQL in the where statement to limit the number of rows.
*/
public string function getMaxRowsWhere(
	required numeric maxrows,
	numeric offset=0
) {
	return "1 = 1";
}

/**
* I get the value an increment higher than the highest value in the given field to put a record at the end of the sort order.
* @sortfield The field holding the sort order.
*/
public numeric function getNewSortNum(
	required string tablename,
	required string sortfield
) {
	var qLast = 0;
	var result = 0;

	qLast = runSQL("SELECT Max(#escape(arguments.sortfield)#) AS #escape(arguments.sortfield)# FROM #escape(arguments.tablename)#");

	if ( qLast.RecordCount and isNumeric(qLast[arguments.sortfield][1]) ) {
		result = qLast[arguments.sortfield][1] + 1;
	} else {
		result = 1;
	}

	return result;
}

/**
* I return an array of primary key fields.
*/
public array function getPKFields(required string tablename) {
	var bTable = checkTable(arguments.tablename);// Check whether table is loaded
	var ii = 0;// counter
	var arrFields = [];// array of primarykey fields

	// If pkfields data if stored
	if ( StructKeyExists(variables.tableprops,arguments.tablename) AND StructKeyExists(variables.tableprops[arguments.tablename],"pkfields") ) {
		arrFields = variables.tableprops[arguments.tablename]["pkfields"];
	} else {
		for ( ii=1; ii LTE ArrayLen(variables.tables[arguments.tablename]); ii++ ) {
			if ( StructKeyExists(variables.tables[arguments.tablename][ii],"PrimaryKey") AND variables.tables[arguments.tablename][ii].PrimaryKey ) {
				ArrayAppend(arrFields, variables.tables[arguments.tablename][ii]);
			}
		}
		variables.tableprops[arguments.tablename]["pkfields"] = arrFields;
	}

	return arrFields;
}

/**
* I return primary key field for this table.
* @tablename The table from which to return a primary key.
*/
public struct function getPrimaryKeyField(required string tablename) {
	var aPKFields = getPKFields(arguments.tablename);

	if ( ArrayLen(aPKFields) NEQ 1 ) {
		throwDMError("The #arguments.tablename# does not have a simple primary key and so it cannot be used for this purpose.","NoSimplePrimaryKey");
	}

	return aPKFields[1];
}

/**
* I return primary key field for this table.
* @tablename The table from which to return a primary key.
*/
public string function getPrimaryKeyFieldName(required string tablename) {
	var sField = getPrimaryKeyField(arguments.tablename);

	return sField.ColumnName;
}

/**
* I return a list of primary key field for this table.
* @tablename The table from which to return a primary key.
*/
public string function getPrimaryKeyFieldNames(required string tablename) {
	var pkfields = getPKFields(arguments.tablename);// the primary key fields for this table
	var result = "";
	var ii = 0;

	// Make list of primary key fields
	for ( ii=1; ii LTE ArrayLen(pkfields); ii++ ) {
		result = ListAppend(result,pkfields[ii].ColumnName);
	}

	return result;
}

/**
* I get the primary key of the record matching the given data.
* @tablename The table from which to return a primary key.
* @fielddata A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
*/
public string function getPKFromData(
	required string tablename,
	required struct fielddata
) {
	var qPK = 0;// The query used to get the primary key
	var fields = getUpdateableFields(arguments.tablename);// The (non-primarykey) fields for this table
	var pkfields = getPKFields(arguments.tablename);// The primary key field(s) for this table
	var result = 0;// The result of this method

	// This method is only to be used on fields with one pkfield
	if ( ArrayLen(pkfields) NEQ 1 ) {
		throwDMError("This method can only be used on tables with exactly one primary key field.","NeedOnePKField");
	}
	// This method can only be used on tables with updateable fields
	if ( NOT ArrayLen(fields) ) {
		throwDMError("This method can only be used on tables with updateable fields.","NeedUpdateableField");
	}

	// Run query to get primary key value from data fields
	qPK = getRecords(tablename=arguments.tablename,data=arguments.fielddata,fieldlist=pkfields[1].ColumnName);

	if ( qPK.RecordCount EQ 1 ) {
		result = qPK[pkfields[1].ColumnName][1];
	} else {
		throwDMError("Data Manager: A unique record could not be identified from the given data.","NoUniqueRecord");
	}

	return result;
}

/**
* I get a recordset based on the primary key value(s) given.
* @tablename The table from which to return a record.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key. Every primary key field should be included.
* @fieldlist A list of fields to return. If left blank, all fields will be returned.
*/
public query function getRecord(
	required string tablename,
	required struct data,
	string fieldlist=""
) {
	var ii = 0;// A generic counter
	var pkfields = getPKFields(arguments.tablename);
	var fields = getUpdateableFields(arguments.tablename);
	var sData = arguments.data;
	var totalfields = 0;// count of fields
	var DataString = "";

	// Figure count of fields
	for ( ii=1; ii LTE ArrayLen(pkfields); ii++ ) {
		if ( StructKeyExists(sData,pkfields[ii].ColumnName) AND isOfCFType(sData[pkfields[ii].ColumnName],pkfields[ii].CF_DataType) ) {
			totalfields = totalfields + 1;
		}
	}
	for ( ii=1; ii LTE ArrayLen(fields); ii++ ) {
		if ( StructKeyExists(sData,fields[ii].ColumnName) AND isOfCFType(sData[fields[ii].ColumnName],fields[ii].CF_DataType) ) {
			totalfields = totalfields + 1;
		}
	}

	// Make sure at least one field is passed in
	if ( totalfields EQ 0 ) {
		for ( ii in arguments.data ) {
			if ( isSimpleValue(arguments.data[ii]) ) {
				DataString = ListAppend(DataString,"#ii#=#arguments.data[ii]#",";");
			} else {
				DataString = ListAppend(DataString,"#ii#=(complex)",";");
			}
		}
		throwDMError("The data argument of getRecord must contain at least one field from the #arguments.tablename# table. To get all records, use the getRecords method.","NeedWhereFields","(data passed in: #DataString#)");
	}

	if ( ArrayLen(pkfields) ) {
		Arguments.orderBy = pkfields[1].ColumnName;
	}
	arguments.data = sData;
	arguments.maxrows = 1;

	return getRecords(argumentcollection=arguments);
}

/**
* I get a recordset based on the data given.
* @tablename The table from which to return a record.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @orderBy The field to order the results by.
* @maxrows The maximum number of rows to return.
* @fieldlist A list of fields to return. If left blank, all fields will be returned.
* @advsql A structure of sqlarrays for each area of a query (SELECT,FROM,WHERE,ORDER BY).
* @filters An array of filters to apply to the query.
* @offset The number of records to skip.
* @function A function to run against the results.
* @FunctionAlias An alias for the column returned by a function (only if function argument is used).
* @Distinct Whether to return distinct records.
* @WithDeletedRecords Whether to include records that have been deleted.
* @noorder If true then skip any ordering in the query.
*/
public query function getRecords(
	required string tablename,
	data,
	string orderBy="",
	numeric maxrows=0,
	string fieldlist="",
	struct advsql,
	array filters,
	numeric offset=0,
	string functionName="",
	string FunctionAlias,
	boolean Distinct=false,
	boolean WithDeletedRecords=false,
	string noorder="false"
) {
	Arguments = ArgumentsFi(ArgumentCollection=Arguments);

	var qRecords = 0;// The recordset to return
	var aSQL = getRecordsSQL(argumentCollection=arguments);
	var sArgs = {"sqlarray":aSQL};

	// We'll pass maxrows, but it will only be used for databases that don't support this in SQL (currently just Derby)
	if ( StructKeyExists(arguments,"maxrows") AND Val(arguments.maxrows) ) {
		sArgs["maxrows"] = arguments.maxrows;
	}
	if ( arguments.offset GT 0 ) {
		sArgs["offset" ] = arguments.offset;
	}

	// Get records
	qRecords = runSQLArray(ArgumentCollection=sArgs);

	//qRecords = applyConcatRelations(arguments.tablename,qRecords);// Not sufficiently tested yet
	qRecords = applyListRelations(arguments.tablename,qRecords);

	// Manage offset
	if ( arguments.offset GT 0 AND NOT dbHasOffset() ) {
		if ( arguments.offset GTE qRecords.RecordCount ) {
			qRecords = QueryNew(qRecords.ColumnList);
		} else {
			qRecords = QuerySliceAndDice(qRecords,arguments.offset+1,qRecords.RecordCount);
		}
	}

	return qRecords;
}

/**
* I get the SQL to get a recordset based on the data given.
* @tablename The table from which to return a record.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @orderBy The field to order the results by.
* @maxrows The maximum number of rows to return.
* @fieldlist A list of fields to return. If left blank, all fields will be returned.
* @function A function to run against the results.
* @advsql A structure of sqlarrays for each area of a query (SELECT,FROM,WHERE,ORDER BY).
* @filters An array of filters to apply to the query.
* @offset The number of records to skip.
* @FunctionAlias An alias for the column returned by a function (only if function argument is used).
* @noorder If true then skip any ordering in the query.
*/
public array function getRecordsSQL(
	required string tablename,
	data,
	string orderBy="",
	numeric maxrows=0,
	string fieldlist="",
	string functionName="",
	struct advsql,
	array filters,
	numeric offset=0,
	string FunctionAlias,
	string noorder="false"
) {
	Arguments = ArgumentsFi(ArgumentCollection=Arguments);

	var sqlarray = [];
	var aOrderBySQL = 0;

	arguments.fieldlist = Trim(arguments.fieldlist);

	if ( NOT ( StructKeyExists(arguments,"isInExists") AND isBoolean(arguments.isInExists) ) ) {
		arguments.isInExists = false;
	}
	if ( arguments.isInExists OR ( Len(arguments["function"]) AND NOT Len(arguments.fieldlist) ) ) {
		arguments.noorder = true;
	}
	if ( NOT ( StructKeyExists(arguments,"noorder") AND isBoolean(arguments.noorder) ) ) {
		arguments.noorder = false;
	}
	if ( NOT arguments.noorder ) {
		aOrderBySQL = getOrderBySQL(argumentCollection=arguments);
	}

	// Get Records
	ArrayAppend(sqlarray,"SELECT");
	if ( arguments.isInExists IS true ) {
		ArrayAppend(sqlarray," 1");
	} else {
		ArrayAppend(sqlarray,This.getSelectSQL(argumentCollection=arguments));
	}

	ArrayAppend(sqlarray,"FROM");
	ArrayAppend(sqlarray,getFromSQL(argumentCollection=arguments));
	if ( arguments.maxrows GT 0 ) {
		ArrayAppend(sqlarray,"WHERE		#getMaxRowsWhere(arguments.maxrows,arguments.offset)#");
	} else {
		ArrayAppend(sqlarray,"WHERE		1 = 1");
	}
	ArrayAppend(sqlarray,getWhereSQL(argumentCollection=arguments));
	if ( StructKeyExists(arguments,"advsql") AND StructKeyExists(arguments.advsql,"GROUP BY") ) {
		ArrayAppend(sqlarray,"GROUP BY ");
		ArrayAppend(sqlarray,arguments.advsql["GROUP BY"]);
	}
	if ( StructKeyExists(arguments,"advsql") AND StructKeyExists(arguments.advsql,"HAVING") ) {
		ArrayAppend(sqlarray,"HAVING ");
		ArrayAppend(sqlarray,arguments.advsql["HAVING"]);
	}
	if ( (NOT arguments.noorder) AND ArrayLen(aOrderBySQL) ) {
		ArrayAppend(sqlarray,"ORDER BY ");
		ArrayAppend(sqlarray,aOrderBySQL);
	}
	if ( arguments.maxrows GT 0 OR arguments.offset GT 0 ) {
		ArrayAppend(sqlarray,"#getMaxRowsSuffix(arguments.maxrows,arguments.offset)#");
	}

	return sqlarray;
}

/*
* I get the SQL for the FROM clause
* @tablename The table from which to return a record.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @orderBy The field to order the results by.
* @maxrows The maximum number of rows to return.
* @fieldlist A list of fields to return. If left blank, all fields will be returned.
* @function A function to run against the results.
* @advsql A structure of sqlarrays for each area of a query (SELECT,FROM,WHERE,ORDER BY).
*/
public array function getFromSQL(
	required string tablename,
	data,
	string orderBy="",
	numeric maxrows=0,
	string fieldlist="",
	string functionName="",
	struct advsql
) {
	Arguments = ArgumentsFi(ArgumentCollection=Arguments);

	var sqlarray = [];

	if ( NOT StructKeyExists(arguments,"tablealias") ) {
		arguments.tablealias = arguments.tablename;
	}

	ArrayAppend(sqlarray,"#escape(Variables.prefix & arguments.tablename)#");
	if ( arguments.tablealias NEQ arguments.tablename ) {
		ArrayAppend(sqlarray," #escape(Variables.prefix & arguments.tablealias)#");
	}
	if ( StructKeyExists(arguments,"advsql") AND StructKeyExists(arguments.advsql,"FROM") ) {
		ArrayAppend(sqlarray,arguments.advsql["FROM"]);
	}
	if ( StructKeyExists(arguments,"join") AND StructKeyExists(arguments.join,"table") ) {
		if ( StructKeyExists(arguments.join,"type") AND ListFindNoCase("inner,left,right", arguments.join.type) ) {
			ArrayAppend(sqlarray,"#UCase(arguments.join.type)# JOIN #escape(arguments.join.table)#");
		} else {
			ArrayAppend(sqlarray,"INNER JOIN #escape(arguments.join.table)#");
		}
		ArrayAppend(sqlarray,"	ON		#escape( arguments.tablealias & '.' & arguments.join.onleft )# = #escape( arguments.join.table & '.' & arguments.join.onright )#");
	}

	return sqlarray;
}

public struct function getRelationTypes() {
	var sTypes = {
		"label":{"atts_req":"table,field,join-field-local,join-field-remote","atts_opt":"","gentypes":"","cfsqltype":"CF_SQL_VARCHAR"},
		"concat":{"atts_req":"fields","atts_opt":"delimiter","gentypes":"","cfsqltype":"CF_SQL_VARCHAR"},
		"list":{"atts_req":"table,field","atts_opt":"join-field-local,join-field-remote,delimiter,sort-field,bidirectional,join-table","gentypes":"","cfsqltype":""},
		"avg":{"atts_req":"table,field,join-field-local,join-field-remote","atts_opt":"","gentypes":"numeric","cfsqltype":"CF_SQL_FLOAT"},
		"count":{"atts_req":"table,field,join-field-local,join-field-remote","atts_opt":"","gentypes":"","cfsqltype":"CF_SQL_BIGINT"},
		"max":{"atts_req":"table,field,join-field-local,join-field-remote","atts_opt":"","gentypes":"numeric,boolean,date","cfsqltype":"CF_SQL_FLOAT"},
		"min":{"atts_req":"table,field,join-field-local,join-field-remote","atts_opt":"","gentypes":"numeric,boolean,date","cfsqltype":"CF_SQL_FLOAT"},
		"sum":{"atts_req":"table,field,join-field-local,join-field-remote","atts_opt":"","gentypes":"numeric,boolean","cfsqltype":"CF_SQL_FLOAT"},
		"has":{"atts_req":"field","atts_opt":"","gentypes":"","cfsqltype":"CF_SQL_BIT"},
		"hasnot":{"atts_req":"field","atts_opt":"","gentypes":"","cfsqltype":"CF_SQL_BIT"},
		"math":{"atts_req":"field1,field2,operator","atts_opt":"","gentypes":"numeric","cfsqltype":"CF_SQL_FLOAT"},
		"now":{"atts_req":"","atts_opt":"","gentypes":"","cfsqltype":"CF_SQL_DATE"},
		"custom":{"atts_req":"","atts_opt":"sql,CF_Datatype","gentypes":"","cfsqltype":""}
	};

	return sTypes;
}

/**
* I get the SQL for the ORDER BY clause
* @tablename The table from which to return a record.
* @orderBy The field to order the results by.
* @maxrows The maximum number of rows to return.
* @fieldlist A list of fields to return. If left blank, all fields will be returned.
* @function A function to run against the results.
* @advsql A structure of sqlarrays for each area of a query (SELECT,FROM,WHERE,ORDER BY).
*/
public array function getOrderBySQL(
	required string tablename,
	data,
	string orderBy="",
	numeric maxrows=0,
	string fieldlist="",
	string functionName="",
	struct advsql={}
) {
	Arguments = ArgumentsFi(ArgumentCollection=Arguments);

	var aResults = [];
	var fields = getUpdateableFields(arguments.tablename);// non primary-key fields in table
	var pkfields = getPKFields(arguments.tablename);// primary key fields in table
	var ii = 0;

	if ( NOT StructKeyExists(arguments,"tablealias") ) {
		arguments.tablealias = arguments.tablename;
	}

	if ( StructKeyExists(arguments,"noorder") AND arguments.noorder EQ true ) {
		aResults = [];
	} else if ( StructKeyExists(arguments.advsql,"ORDER BY") ) {
		aResults = arguments.advsql["ORDER BY"];
	} else {
		// Check for Sorter//
		for ( ii=1; ii LTE ArrayLen(fields); ii++ ) {
			if ( StructKeyExists(fields[ii],"Special") AND fields[ii].Special EQ "Sorter" ) {
				if (
						( NOT Len(arguments["function"]) AND NOT ( StructKeyExists(arguments,"Distinct") AND arguments.Distinct IS true ) )
					OR	(
								Len(arguments.fieldlist) EQ 0
							OR	ListFindNoCase(arguments.fieldlist, fields[ii].ColumnName)
						)
				) {
					// Load field in sort order, if not there already
					if ( NOT (
								ListFindNoCase(arguments.orderBy,fields[ii].ColumnName)
							OR	ListFindNoCase(arguments.orderBy,escape(fields[ii].ColumnName))
							OR	ListFindNoCase(arguments.orderBy,"#fields[ii].ColumnName# DESC")
							OR	ListFindNoCase(arguments.orderBy,"#escape(fields[ii].ColumnName)# DESC")
							OR	ListFindNoCase(arguments.orderBy,"#fields[ii].ColumnName# ASC")
							OR	ListFindNoCase(arguments.orderBy,"#escape(fields[ii].ColumnName)# ASC")
							OR	ListFindNoCase(arguments.orderBy,"#escape(arguments.tablealias & '.' & fields[ii].ColumnName)#")
						)
					) {
						arguments.orderBy = ListAppend(arguments.orderBy,"#escape(arguments.tablealias & '.' & fields[ii].ColumnName)#");
					}
				}
			}
		}
		// Continue with conditionals
		if ( Len(arguments.orderBy) ) {
			aResults = getOrderByArray(arguments.tablename,arguments.orderby,arguments.tablealias);
		// ** USE AT YOUR OWN RISK! **: This is highly experimental and not supported on all database
		} else if (
				StructKeyExists(arguments,"sortfield")
			AND	Len(Trim(arguments.sortfield))
			AND	(
						( NOT Len(arguments["function"]) AND NOT ( StructKeyExists(arguments,"Distinct") AND arguments.Distinct IS true ) )
					OR	(
								Len(arguments.fieldlist) EQ 0
							OR	ListFindNoCase(arguments.fieldlist, arguments.sortfield)
						)
				)
		) {
			ArrayAppend(aResults,getFieldSelectSQL(tablename=arguments.tablename,field=arguments.sortfield,tablealias=arguments.tablealias,useFieldAlias=false));
			if ( StructKeyExists(arguments,"sortdir") AND (arguments.sortdir EQ "ASC" OR arguments.sortdir EQ "DESC") ) {
				ArrayAppend(aResults," #arguments.sortdir#");
			}
			// Fixing a bug in MS Access
			if ( getDatabase() EQ "Access" AND arguments.sortfield NEQ pkfields[1].ColumnName ) {
				ArrayAppend(aResults,",");
				ArrayAppend(aResults,getFieldSelectSQL(tablename=arguments.tablename,field=pkfields[1].ColumnName,tablealias=arguments.tablealias,useFieldAlias=false));
			}
		} else if ( arguments.maxrows GT 0 ) {
			aResults = getDefaultOrderBySQL(argumentCollection=arguments);
		}
	}

	return aResults;
}

/**
* I get the SQL for the SELECT clause
* @tablename The table from which to return a record.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @orderBy The field to order the results by.
* @maxrows The maximum number of rows to return.
* @fieldlist A list of fields to return. If left blank, all fields will be returned.
* @function A function to run against the results.
* @advsql A structure of sqlarrays for each area of a query (SELECT,FROM,WHERE,ORDER BY).
* @filters An array of filters to apply to the query.
* @offset The number of records to skip.
* @FunctionAlias An alias for the column returned by a function (only if function argument is used).
*/
public array function getSelectSQL(
	required string tablename,
	data,
	string orderBy="",
	numeric maxrows=0,
	string fieldlist="",
	string functionName="",
	struct advsql,
	array filters,
	numeric offset=0,
	string FunctionAlias
) {
	Arguments = ArgumentsFi(ArgumentCollection=Arguments);

	var bTable = checkTable(arguments.tablename);// Check whether table is loaded
	var sqlarray = ArrayNew(1);
	var adjustedfieldlist = "";
	var numcols = 0;
	var ii = 0;
	var aFields = variables.tables[arguments.tablename];
	var dbfields = "";
	var temp = "";
	var fields = "";

	if ( NOT StructKeyExists(arguments,"tablealias") ) {
		arguments.tablealias = arguments.tablename;
	}

	if ( NOT StructKeyExists(arguments,"FunctionAlias") ) {
		arguments.FunctionAlias = "DataMgr_FunctionResult";
	}

	if ( Len(arguments.fieldlist) ) {
		for ( temp in ListToArray(arguments.fieldlist) ) {
			adjustedfieldlist = ListAppend(adjustedfieldlist,escape(arguments.tablealias & '.' & temp));
		}
	}

	if ( StructKeyExists(arguments,"distinct") AND arguments.distinct IS true ) {
		ArrayAppend(sqlarray,"DISTINCT");
	}
	if ( arguments.maxrows GT 0 ) {
		ArrayAppend(sqlarray,getMaxRowsPrefix(arguments.maxrows,arguments.offset));
	}
	if ( Len(arguments.function) ) {
		// Just defeating an editor bug for opening parents in a string.
		temp = arguments.function & Chr(40);
		if ( Len(arguments.fieldlist) ) {
			temp &= adjustedfieldlist;
		} else {
			temp &= "*";
		}
		temp &= ") AS #arguments.FunctionAlias#";
		ArrayAppend(sqlarray,temp);
		numcols = numcols + 1;
	}  else {
		for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
				if (
					Len(aFields[ii]["ColumnName"])
					AND
					(
						NOT ListFindNoCase(fields,aFields[ii]["ColumnName"])
					)
					AND
					isFieldInSelect(aFields[ii],arguments.fieldlist,arguments.maxrows)
				) {
					if ( numcols GT 0 ) {
						ArrayAppend(sqlarray,",");
					}
					numcols = numcols + 1;
					fields = ListAppend(fields,aFields[ii]["ColumnName"]);
					ArrayAppend(sqlarray,getFieldSelectSQL(arguments.tablename,aFields[ii]["ColumnName"],arguments.tablealias));
				}
		}
		if (
				( StructKeyExists(variables.tableprops[arguments.tablename],"deletable") AND Len(variables.tableprops[arguments.tablename].deletable) )
			AND	NOT ListFindNoCase(getFieldList(arguments.tablename),variables.tableprops[arguments.tablename].deletable)
			AND	(
						Len(arguments.fieldlist) EQ 0
					OR	ListFindNoCase(arguments.fieldlist,variables.tableprops[arguments.tablename].deletable)
				)
		) {
			if ( numcols GT 0 ) {
				ArrayAppend(sqlarray,",");
			}
			numcols = numcols + 1;
			ArrayAppend(sqlarray,getIsDeletableSQL(tablename=arguments.tablename,tablealias=arguments.tablealias));
			ArrayAppend(sqlarray," AS ");
			ArrayAppend(sqlarray,escape(variables.tableprops[arguments.tablename].deletable));
		}
	}
	if (
			StructKeyExists(arguments,"advsql") AND StructKeyExists(arguments.advsql,"SELECT")
		AND	(
					( isSimpleValue(arguments.advsql["SELECT"]) AND Len(Trim(arguments.advsql["SELECT"])) )
				OR	( isArray(arguments.advsql["SELECT"]) AND ArrayLen(arguments.advsql["SELECT"]) )
			)
	) {
		ArrayAppend(sqlarray,",");numcols = numcols + 1;
		ArrayAppend(sqlarray,arguments.advsql["SELECT"]);
	}

	// Make sure at least one field is retrieved
	if ( numcols EQ 0 AND NOT Len(fields) ) {
		dbfields = getDBFieldList(arguments.tablename);
		throwDMError("At least one valid field must be retrieved from the #arguments.tablename# table (actual fields in table are: #dbfields#) (requested fields: #arguments.fieldlist#).","NeedSelectFields");
	}

	return sqlarray;
}

/**
* I get the SQL for the WHERE clause
* @tablename The table from which to return a record.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @advsql A structure of sqlarrays for each area of a query (SELECT,FROM,WHERE,ORDER BY).
* @filters An array of filters to apply to the query.
*/
public array function getWhereSQL(
	required string tablename,
	data,
	struct advsql,
	array filters
) {
	var fields = getUpdateableFields(arguments.tablename);// non primary-key fields in table
	var sData = 0;// holder for incoming data (just for readability)
	var pkfields = getPKFields(arguments.tablename);// primary key fields in table
	var rfields = getRelationFields(arguments.tablename);// relation fields in table
	var sData = 0;// Generic counter
	var sqlarray = [];
	var sArgs = 0;
	var temp = "";
	var joiner = "AND";
	var sOtherFields = {};
	var ii = 0;

	// Convert data argument to "sData" struct
	if ( StructKeyExists(arguments,"data") ) {
		if ( isStruct(arguments.data) ) {
			sData = arguments.data;
		} else if ( isSimpleValue(arguments.data) ) {
			if ( ArrayLen(pkfields) EQ 1 ) {
				sData = {};
				sData[pkfields[1].ColumnName] = arguments.data;
			} else {
				throwDMError("Data argument can only be a string for tables with simple (single column) primary keys.");
			}
		} else {
			throwDMError("Data argument must be either a struct or a string.");
		}
	} else {
		sData = {};
	}

	// "Other Field" handling
	for ( ii=1; ii LTE ArrayLen(rfields); ii++ ) {
		if (
				StructKeyExists(rfields[ii].Relation,"other-field")
			AND	Len(rfields[ii].Relation["other-field"])
			AND	StructKeyExists(sData,rfields[ii].Relation["other-field"])
		) {
			sOtherFields[rfields[ii].Relation["other-field"]] = sData[rfields[ii].Relation["other-field"]];
			StructDelete(sData,rfields[ii].Relation["other-field"]);
		}
	}


	if ( NOT StructKeyExists(arguments,"filters") ) {
		arguments.filters = ArrayNew(1);
	}
	// Named Filters
	if ( StructCount(variables.tableprops[arguments.tablename]["filters"]) ) {
		for ( ii in variables.tableprops[arguments.tablename].filters ) {
			if ( StructKeyExists(sData,ii) ) {
				ArrayAppend(arguments.filters,StructCopy(variables.tableprops[arguments.tablename].filters[ii]));
				arguments.filters[ArrayLen(arguments.filters)].value = sData[ii];
			}
		}
	}

	if ( NOT StructKeyExists(arguments,"tablealias") ) {
		arguments.tablealias = arguments.tablename;
	}

	// filter by primary keys
	for ( ii=1; ii LTE ArrayLen(pkfields); ii++ ) {
		if ( StructKeyExists(sData,pkfields[ii].ColumnName) AND isOfCFType(sData[pkfields[ii].ColumnName],pkfields[ii].CF_DataType) ) {
			ArrayAppend(sqlarray,"#joiner#		#escape(arguments.tablealias & '.' & pkfields[ii].ColumnName)# = ");
			ArrayAppend(sqlarray,sval(pkfields[ii],sData));
		}
	}
	// filter by updateable fields
	for ( ii=1; ii LTE ArrayLen(fields); ii++ ) {
		if ( NOT ListFindNoCase(variables.nocomparetypes,fields[ii].CF_DataType) ) {
			if ( useField(sData,fields[ii]) OR ( StructKeyExists(sData,fields[ii].ColumnName) AND isSimpleValue(sData[fields[ii].ColumnName]) AND NOT Len(sData[fields[ii].ColumnName]) ) ) {
				ArrayAppend(sqlarray,joiner);
				ArrayAppend(sqlarray,getFieldWhereSQL(tablename=arguments.tablename,field=fields[ii].ColumnName,value=sData[fields[ii].ColumnName],tablealias=arguments.tablealias));
			} else if ( StructKeyExists(sData,fields[ii].ColumnName) AND isSimpleValue(sData[fields[ii].ColumnName]) AND NOT Len(Trim(sData[fields[ii].ColumnName])) ) {
				ArrayAppend(sqlarray,"#joiner#		#escape(arguments.tablealias & '.' & fields[ii].ColumnName)# IS NULL");
			} else if ( StructKeyExists(fields[ii],"Special") AND fields[ii].Special EQ "DeletionMark" AND NOT ( StructKeyExists(Arguments,"WithDeletedRecords") AND Arguments.WithDeletedRecords IS true ) ) {
				// Make sure not to get records that have been logically deleted
				if ( fields[ii].CF_DataType EQ "CF_SQL_BIT" ) {
					ArrayAppend(sqlarray,"#joiner#		(#escape(arguments.tablealias & '.' & fields[ii].ColumnName)# = #getBooleanSqlValue(0)# OR #escape(arguments.tablealias & '.' & fields[ii].ColumnName)# IS NULL)");
				} else if ( fields[ii].CF_DataType EQ "CF_SQL_DATE" OR fields[ii].CF_DataType EQ "CF_SQL_DATETIME" ) {
					ArrayAppend(sqlarray,"#joiner#		(#escape(arguments.tablealias & '.' & fields[ii].ColumnName)# = 0 OR #escape(arguments.tablealias & '.' & fields[ii].ColumnName)# IS NULL )");
				}
			}
		}
	}
	// Filter by relations
	for ( ii=1; ii LTE ArrayLen(rfields); ii++ ) {
		if ( useField(sData,rfields[ii]) OR ( StructKeyExists(sData,rfields[ii].ColumnName) AND isSimpleValue(sData[rfields[ii].ColumnName]) AND NOT Len(sData[rfields[ii].ColumnName]) ) ) {
			ArrayAppend(sqlarray," #joiner# ");
			sArgs = StructNew();
			sArgs["tablename"] = arguments.tablename;
			sArgs["field"] = rfields[ii]["ColumnName"];
			sArgs["value"] = sData[rfields[ii]["ColumnName"]];
			sArgs["tablealias"] = arguments.tablealias;
			if ( StructKeyExists(arguments,"join") AND StructKeyExists(arguments.join,"table") ) {
				sArgs["joinedtable"] = arguments.join.table;
			}
			if ( StructKeyExists(rfields[ii].Relation,"other-field") AND Len(rfields[ii].Relation["other-field"]) AND StructKeyExists(sOtherFields,rfields[ii].Relation["other-field"]) ) {
				sArgs["OtherVal"] = sOtherFields[rfields[ii].Relation["other-field"]];
			}
			ArrayAppend(sqlarray,getFieldWhereSQL(argumentCollection=Duplicate(sArgs)));
		}
	}
	// Filter by filters
	if ( StructKeyExists(arguments,"filters") AND ArrayLen(arguments.filters) ) {
		for ( ii=1; ii LTE ArrayLen(arguments.filters); ii++ ) {
			// Make sure this is a valid filter (has a field and a value <which either has length or equality operator>)
			if (
					StructKeyExists(arguments.filters[ii],"field")
				AND	Len(arguments.filters[ii]["field"])
				AND	(
							(
									StructKeyExists(arguments.filters[ii],"value")
								AND	(
											Len(arguments.filters[ii]["value"])
										OR	NOT ( StructKeyExists(arguments.filters[ii],"operator") AND Len(arguments.filters[ii]["operator"]) )
										OR	arguments.filters[ii]["operator"] EQ "="
										OR	arguments.filters[ii]["operator"] EQ "<>"
										OR	arguments.filters[ii]["operator"] EQ ">"
										OR	arguments.filters[ii]["operator"] EQ "IN"
									)

							)
						OR	( StructKeyExists(arguments.filters[ii],"sql") AND Len(arguments.filters[ii]["sql"]) )
					)
			) {
				// Determine the arguments of the where clause call
				sArgs = StructNew();
				if ( StructKeyExists(arguments.filters[ii],"table") AND Len(arguments.filters[ii]["table"]) ) {
					sArgs["tablename"] = arguments.filters[ii].table;
				} else {
					sArgs["tablename"] = arguments.tablename;
					sArgs["tablealias"] = arguments.tablealias;
				}
				sArgs["field"] = arguments.filters[ii].field;
				if ( StructKeyExists(arguments.filters[ii],"sql") AND Len(arguments.filters[ii]["sql"]) ) {
					sArgs["sql"] = arguments.filters[ii]["sql"];
					sArgs["value"] = "";
				} else {
					sArgs["value"] = ToString(arguments.filters[ii].value);
				}
				if ( StructKeyExists(arguments.filters[ii],"operator") AND Len(arguments.filters[ii]["operator"]) ) {
					sArgs["operator"] = arguments.filters[ii].operator;
				}
				if ( StructKeyExists(arguments,"join") AND StructKeyExists(arguments.join,"table") ) {
					sArgs["joinedtable"] = arguments.join.table;
				}
				// Only filter if the field is in the table
				if ( ListFindNoCase(getFieldList(sArgs["tablename"]),sArgs["field"]) ) {
					temp = getFieldWhereSQL(argumentCollection=Duplicate(sArgs));
					// Only filter if the where clause returned something
					if ( ( isArray(temp) AND ArrayLen(temp) ) OR ( isSimpleValue(temp) AND Len(Trim(temp)) ) ) {
						ArrayAppend(sqlarray," #joiner# ");
						ArrayAppend(sqlarray,temp);
					}
				}
			}
		}
	}
	// Filter by deletable property
	if (
			( StructKeyExists(variables.tableprops[arguments.tablename],"deletable") AND Len(variables.tableprops[arguments.tablename].deletable) )
		AND	NOT ListFindNoCase(getFieldList(arguments.tablename),variables.tableprops[arguments.tablename].deletable)
		AND	NOT ( StructKeyExists(variables.tableprops[arguments.tablename],"filters") AND StructKeyExists(variables.tableprops[arguments.tablename]["filters"],variables.tableprops[arguments.tablename].deletable) )
		AND	(
					StructKeyExists(sData,variables.tableprops[arguments.tablename].deletable)
				AND	isBoolean(sData[variables.tableprops[arguments.tablename].deletable])
			)
	) {
		ArrayAppend(sqlarray," #joiner# ");
		ArrayAppend(sqlarray,getIsDeletableSQL(tablename=arguments.tablename,tablealias=arguments.tablealias));
		ArrayAppend(sqlarray," = ");
		ArrayAppend(sqlarray,getBooleanSQLValue(sData[variables.tableprops[arguments.tablename].deletable]));
	}
	if ( StructKeyExists(arguments,"advsql") AND StructKeyExists(arguments.advsql,"WHERE") AND ( ( isArray(arguments.advsql["WHERE"]) AND ArrayLen(arguments.advsql["WHERE"]) ) OR ( isSimpleValue(arguments.advsql["WHERE"]) AND Len(Trim(arguments.advsql["WHERE"])) ) ) ) {
		if ( NOT ( isSimpleValue(arguments.advsql["WHERE"]) AND Left(Trim(arguments.advsql["WHERE"]),3) EQ "AND" ) ) {
			ArrayAppend(sqlarray,joiner);
		}
		ArrayAppend(sqlarray,arguments.advsql["WHERE"]);
	}

	return sqlarray;
}

/**
* I get the SQL for the SELECT clause for the given field.
* @tablename The table from which to return a record.
* @field The field to return.
* @tablealias The alias for the table.
* @useFieldAlias Whether to use the field alias.
*/
public function getFieldSelectSQL(
	required string tablename,
	required string field,
	string tablealias,
	boolean useFieldAlias=true
) {
	var ttemp = fillOutJoinTableRelations(arguments.tablename);
	var sField = 0;
	var sField2 = 0;
	var aSQL = [];
	var sAdvSQL = {};
	var sJoin = {};
	var sArgs = {};
	var temp = "";

	if ( isNumeric(arguments.field) ) {
		aSQL = arguments.field;
	} else if ( NOT Len(Trim(arguments.field)) ) {
		ArrayAppend(aSQL,"''");
	} else {
		sField = getField(arguments.tablename,arguments.field);

		if ( NOT StructKeyExists(arguments,"tablealias") ) {
			arguments.tablealias = arguments.tablename;
		}

		sArgs["noorder"] = NOT variables.dbprops["areSubqueriesSortable"];

		if ( StructKeyExists(sField,"Relation") AND StructKeyExists(sField.Relation,"type") ) {
			sField.Relation = expandRelationStruct(sField.Relation,sField);
			if ( StructKeyExists(sField["Relation"],"filters") AND isArray(sField["Relation"].filters) ) {
				sArgs["filters"] = sField["Relation"].filters;
			}
			ArrayAppend(aSQL,"(");
			switch (sField.Relation.type) {
				case "label":
						if ( StructKeyExists(sField.Relation,"sort-field") ) {
							sArgs["sortfield"] = sField.Relation["sort-field"];
							if ( StructKeyExists(sField.Relation,"sort-dir") ) {
								sArgs["sortdir"] = sField.Relation["sort-dir"];
							}
						} else if ( getDatabase() EQ "Access" ) {
							sArgs["noorder"] = true;
						}
						sArgs["tablename"] = sField.Relation["table"];
						sArgs["fieldlist"] = sField.Relation["field"];
						if ( arguments.tablealias EQ sField.Relation["table"] ) {
							sArgs["tablealias"] = sField.Relation["table"] & "_DataMgr_inner";
						} else {
							sArgs["tablealias"] = sField.Relation["table"];
						}
						// Only one record for fields in database (otherwise nesting will occur and it could cause trouble but not give any benefit)
						// if ( ListFindNoCase(getDBFieldList(sField.Relation["table"]),sField.Relation["field"]) ) {
							sArgs["maxrows"] = 1;
						// }
						sAdvSQL = StructNew();
						sAdvSQL["WHERE"] = ArrayNew(1);
						ArrayAppend(sAdvSQL["WHERE"], getFieldSelectSQL(tablename=sField.Relation['table'],field=sField.Relation['join-field-remote'],tablealias=sArgs.tablealias,useFieldAlias=false) );
						ArrayAppend(sAdvSQL["WHERE"], " = " );
						ArrayAppend(sAdvSQL["WHERE"], getFieldSelectSQL(tablename=arguments.tablename,field=sField.Relation['join-field-local'],tablealias=arguments.tablealias,useFieldAlias=false) );
						sArgs["advsql"] = sAdvSQL;
						ArrayAppend(aSQL,getRecordsSQL(argumentCollection=sArgs));
					break;
				case "list":
						ArrayAppend(aSQL,getFieldSQL_List(argumentCollection=arguments));
					break;
				case "concat":
						ArrayAppend(aSQL,"#concatFields(arguments.tablename,sField.Relation['fields'],sField.Relation['delimiter'],arguments.tablealias)#");
					break;
				case "avg":
				case "count":
				case "max":
				case "min":
				case "sum":
						sAdvSQL = StructNew();
						if ( arguments.tablename EQ sField.Relation["table"] ) {
							sArgs["tablealias"] = sField.Relation["table"] & "_datamgr_inner_table";
						} else {
							sArgs["tablealias"] = sField.Relation["table"];
						}
						if ( StructKeyExists(sField.Relation,"join-table") ) {
							sJoin = StructNew();
							sJoin["table"] = sField.Relation["join-table"];
							sJoin["onLeft"] = sField.Relation["remote-table-join-field"];
							sJoin["onRight"] = sField.Relation["join-table-field-remote"];
							sAdvSQL["WHERE"] = ArrayNew(1);
							ArrayAppend(sAdvSQL["WHERE"],getFieldSelectSQL(sField.Relation['join-table'],sField.Relation['join-table-field-local'],sField.Relation['join-table'],false));
							ArrayAppend(sAdvSQL["WHERE"]," = ");
							ArrayAppend(sAdvSQL["WHERE"],getFieldSelectSQL(arguments.tablename,sField.Relation['local-table-join-field'],arguments.tablealias,false));
						} else {
							sAdvSQL["WHERE"] = ArrayNew(1);
							ArrayAppend(sAdvSQL["WHERE"],getFieldSelectSQL(sField.Relation['table'],sField.Relation['join-field-remote'],sArgs.tablealias,false));
							ArrayAppend(sAdvSQL["WHERE"]," = ");
							ArrayAppend(sAdvSQL["WHERE"],getFieldSelectSQL(arguments.tablename,sField.Relation['join-field-local'],arguments.tablealias,false));
						}
						if ( StructKeyExists(sField.Relation,"sort-field") ) {
							sArgs["sortfield"] = sField.Relation["sort-field"];
							if ( StructKeyExists(sField.Relation,"sort-dir") ) {
								sArgs["sortdir"] = sField.Relation["sort-dir"];
							}
						}
						sArgs["tablename"] = sField.Relation["table"];
						sArgs["fieldlist"] = sField.Relation["field"];
						sArgs["function"] = sField.Relation["type"];
						sArgs["advsql"] = sAdvSQL;
						sArgs["join"] = sJoin;
						if ( arguments.tablename EQ sField.Relation["table"] ) {
							sArgs["tablealias"] = sField.Relation["table"]& "_datamgr_inner_table";
						}
						ArrayAppend(aSQL,getRecordsSQL(argumentCollection=sArgs));
					break;
				case "has":
						ArrayAppend(aSQL,getFieldSQL_Has(argumentCollection=arguments));
					break;
				case "math":
						ArrayAppend(aSQL,getFieldSQL_Math(argumentCollection=arguments));
					break;
				case "now":
						ArrayAppend(aSQL,getNowSQL());
					break;
				case "custom":
						if ( StructKeyExists(sField.Relation,"sql") AND Len(sField.Relation.sql) ) {
							ArrayAppend(aSQL,"#sField.Relation.sql#");
						} else {
							ArrayAppend(aSQL,"''");
						}
					break;
				default:
					ArrayAppend(aSQL,"''");
			}
			ArrayAppend(aSQL,")");
			if ( arguments.useFieldAlias AND Len(Trim(sField['ColumnName'])) ) {
				ArrayAppend(aSQL," AS #escape(sField['ColumnName'])#");
			}
		} else {
			ArrayAppend(aSQL,escape(arguments.tablealias & "." & sField["ColumnName"]));
		}
	}

	return aSQL;
}

public function getFieldSQL_Has(
	required string tablename,
	required string field,
	string tablealias
) {
	var sField = getField(arguments.tablename,arguments.field);
	var aSQL = 0;
	var sArgs = {tablename=arguments.tablename,field=sField.Relation.field};

	if ( StructKeyExists(arguments,"tablealias") ) {
		sArgs["tablealias"] = "#arguments.tablealias#";
	} else {
		sArgs["tablealias"] = "#arguments.tablename#";
	}

	aSQL = getHasFieldSQL(ArgumentCollection=sArgs);

	return aSQL;
}

public function getFieldSQL_List(
	required string tablename,
	required string field,
	string tablealias
) {
	var sField = getField(arguments.tablename,arguments.field);
	var aSQL = [];
	var temp = 0;
	var sField2 = 0;

	if ( StructKeyExists(sField.Relation,"join-table") ) {
		temp = getFieldSelectSQL(tablename=arguments.tablename,field=sField.Relation["local-table-join-field"],tablealias=arguments.tablealias,useFieldAlias=false);
		if ( Len(sField.Relation["local-table-join-field"]) ) {
			sField2 = getField(arguments.tablename,sField.Relation["local-table-join-field"]);
		} else {
			sField2 = StructNew();
		}
	} else {
		temp = getFieldSelectSQL(tablename=arguments.tablename,field=sField.Relation["join-field-local"],tablealias=arguments.tablealias,useFieldAlias=false);
		if ( Len(sField.Relation["join-field-local"]) ) {
			sField2 = getField(arguments.tablename,sField.Relation["join-field-local"]);
		} else {
			sField2 = StructNew();
		}
	}
	temp = readableSQL(temp);
	if ( Len(temp) ) {
		if ( StructKeyExists(sField2,"Relation") AND StructKeyExists(sField2.Relation,"type") AND sField2.Relation.type EQ "concat" ) {
			ArrayAppend(aSQL,temp);
		} else {
			ArrayAppend(aSQL,concat(temp));
		}
	} else {
		ArrayAppend(aSQL,"''");
	}

	return aSQL;
}

public function getHasFieldSQL(
	required string tablename,
	required string field,
	string tablealias
) {
	var dtype = getEffectiveDataType(arguments.tablename,arguments.field);
	var aSQL = ArrayNew(1);
	var sAdvSQL = StructNew();
	var sJoin = StructNew();
	var sArgs = StructNew();
	var temp = "";

	if ( NOT StructKeyExists(arguments,"tablealias") ) {
		arguments.tablealias = arguments.tablename;
	}

	switch (dtype) {
		case "numeric":
				ArrayAppend(aSQL,"isnull(CASE WHEN (");
				ArrayAppend(aSQL, getFieldSelectSQL(tablename=arguments.tablename,field=arguments.field,tablealias=arguments.tablealias,useFieldAlias=false) );
				ArrayAppend(aSQL,") > 0 THEN 1 ELSE 0 END,0)");
			break;
		case "string":
				ArrayAppend(aSQL,"isnull(len(");
				ArrayAppend(aSQL, getFieldSelectSQL(tablename=arguments.tablename,field=arguments.field,tablealias=arguments.tablealias,useFieldAlias=false) );
				ArrayAppend(aSQL,"),0)");
			break;
		case "date":
				ArrayAppend(aSQL,"CASE WHEN (");
				ArrayAppend(aSQL, getFieldSelectSQL(tablename=arguments.tablename,field=arguments.field,tablealias=arguments.tablealias,useFieldAlias=false) );
				ArrayAppend(aSQL,") IS NULL THEN 0 ELSE 1 END");
			break;
		case "boolean":
				ArrayAppend(aSQL,"isnull(");
				ArrayAppend(aSQL, getFieldSelectSQL(tablename=arguments.tablename,field=arguments.field,tablealias=arguments.tablealias,useFieldAlias=false) );
				ArrayAppend(aSQL,",0)");
			break;
	}

	return aSQL;
}

public function getFieldWhereSQL(
	required string tablename,
	required string field,
	required string value,
	string tablealias,
	string operator="=",
	any sql
) {
	var sField = getField(arguments.tablename,arguments.field);
	var aSQL = [];
	var sArgs = {};
	var temp = 0;
	var sAllField = 0;
	var operators = "=,>,<,>=,<=,LIKE,NOT LIKE,<>,IN,NOT IN";
	var operators_cf = "EQUAL,EQ,NEQ,GT,GTE,LT,LTE,IS,IS NOT,NOT";
	var operators_sql = "=,=,<>,>,>=,<,<=,=,<>,<>";
	var fieldval = arguments.value;
	var sRelationTypes = getRelationTypes();
	var sAdvSQL = 0;
	var inops = "IN,NOT IN";
	var dtype = getEffectiveDataType(arguments.tablename,arguments.field);
	var hasOtherFieldVal = false;
	var NegativeOperators = "<>,NOT LIKE,NOT IN";
	var isNegativeOperator = false;
	var isAll = false;

	if ( arguments.operator EQ "All" ) {
		isAll = true;
		arguments.operator = "=";
	}

	if ( NOT ( ListFindNoCase(operators,arguments.operator) OR ListFindNoCase(operators_cf,arguments.operator) ) ) {
		throwDMError("#arguments.operator# is not a valid operator. Valid operators are: #operators#,#operators_cf#","InvalidOperator");
	}

	if ( NOT StructKeyExists(arguments,"sql") ) {
		arguments.sql = "";
	}

	// Convert ColdFusion operator to SQL operator
	if ( ListFindNoCase(operators_cf,arguments.operator) ) {
		arguments.operator = ListGetAt(operators_sql,ListFindNoCase(operators_cf,arguments.operator));
	}

	isNegativeOperator = ( ListFindNoCase(NegativeOperators,arguments.operator) GT 0 );

	if ( arguments.operator CONTAINS "LIKE" AND dtype NEQ "string" ) {
		throwDMError("LIKE comparisons are only valid on string fields","LikeOnlyOnStrings");
	}

	if ( arguments.operator CONTAINS "LIKE" AND NOT ( fieldval CONTAINS "%" ) ) {
		fieldval = "%#fieldval#%";
	}

	if ( NOT StructKeyExists(arguments,"tablealias") ) {
		arguments.tablealias = arguments.tablename;
	}

	sArgs["noorder"] = NOT variables.dbprops["areSubqueriesSortable"];

	if ( StructKeyExists(sField,"Relation") AND StructKeyExists(sField.Relation,"type") ) {
		sField.Relation = expandRelationStruct(sField.Relation,sField);
		if ( StructKeyExists(sField["Relation"],"filters") AND isArray(sField["Relation"].filters) ) {
			sArgs["filters"] = sField["Relation"].filters;
		} else {
			sArgs["filters"] = ArrayNew(1);
		}
		switch (sField.Relation.type) {
			case "label":
					sArgs.tablename = sField.Relation["table"];
					sArgs.fieldlist = sField.Relation["field"];
					sArgs.maxrows = 1;
					sArgs.advsql = StructNew();
					sArgs.data = StructNew();

					ArrayAppend(aSQL,"EXISTS (");
						sArgs.operator = arguments.operator;
						sArgs.noorder = true;
						sArgs.isInExists = true;
						temp = StructNew();
						temp.field = sField.Relation["field"];
						temp.value = fieldval;
						temp.operator = arguments.operator;
						if ( arguments.tablealias EQ sField.Relation["table"] ) {
							sArgs["tablealias"] = sField.Relation["table"] & "_datamgr_inner";
						} else {
							sArgs["tablealias"] = sField.Relation["table"];
						}
						ArrayAppend(sArgs.filters,temp);
						sArgs.advsql["WHERE"] = ArrayNew(1);
						ArrayAppend(sArgs.advsql["WHERE"],getFieldSelectSQL(sField.Relation['table'],sField.Relation['join-field-remote'],sArgs.tablealias,false));
						ArrayAppend(sArgs.advsql["WHERE"]," = ");
						if ( StructKeyExists(arguments,"joinedtable") AND Len(arguments.joinedtable) ) {
							ArrayAppend(sArgs.advsql["WHERE"],getFieldSelectSQL(arguments.joinedtable,sField.Relation['join-field-local'],arguments.joinedtable,false));
						} else {
							ArrayAppend(sArgs.advsql["WHERE"],getFieldSelectSQL(arguments.tablename,sField.Relation['join-field-local'],arguments.tablealias,false));
						}
						ArrayAppend(aSQL,getRecordsSQL(argumentCollection=sArgs));
					ArrayAppend(aSQL,")");
				break;
			case "list":
					hasOtherFieldVal = (
							StructKeyExists(arguments,"OtherVal")
						AND	StructKeyExists(sField.Relation,"other-field")
						AND	Len(sField.Relation["other-field"])
						AND	(
								Len(arguments.OtherVal) EQ 0
							OR	isOfCFType(arguments.OtherVal,getEffectiveFieldDataType(getField(arguments.tablename,sField.Relation["other-field"]),true))
						)
					);

					if ( isAll ) {
						sArgs["function"] = "count";

					} else {
						sArgs.isInExists = true;
						sArgs.fieldlist = sField.Relation["field"];
					}

					sArgs.noorder = true;
					sArgs.tablename = sField.Relation["table"];
					sArgs.maxrows = 1;
					sArgs.join = StructNew();
					sArgs.advsql = StructNew();
					sArgs.advsql.WHERE = ArrayNew(1);
					temp = ArrayNew(1);

					if ( StructKeyExists(sField.Relation,"join-table") ) {
						sArgs.join.table = sField.Relation["join-table"];
						sArgs.join.onLeft = sField.Relation["remote-table-join-field"];
						sArgs.join.onRight = sField.Relation["join-table-field-remote"];

						ArrayAppend(sArgs.advsql.WHERE,getFieldSelectSQL(sField.Relation['join-table'],sField.Relation['join-table-field-local'],sField.Relation['join-table'],false));
						ArrayAppend(sArgs.advsql.WHERE," = ");
						ArrayAppend(sArgs.advsql.WHERE,getFieldSelectSQL(arguments.tablename,sField.Relation['local-table-join-field'],arguments.tablealias,false));
					} else {
						ArrayAppend(sArgs.advsql.WHERE,getFieldSelectSQL(sField.Relation['table'],sField.Relation['join-field-remote'],sField.Relation['table'],false));
						ArrayAppend(sArgs.advsql.WHERE," = ");
						ArrayAppend(sArgs.advsql.WHERE,getFieldSelectSQL(arguments.tablename,sField.Relation['join-field-local'],arguments.tablealias,false));
					}
					if ( Len(arguments.value) ) {
						ArrayAppend(sArgs.advsql.WHERE,"			AND		(");
						ArrayAppend(sArgs.advsql.WHERE,"							1 = 0");
						for ( temp in ListToArray(fieldval) ) {
							ArrayAppend(sArgs.advsql.WHERE,"					OR");
							ArrayAppend(sArgs.advsql.WHERE,"#getFieldSelectSQL(sField.Relation['table'],sField.Relation['field'],sField.Relation['table'],false)#");
							ArrayAppend(sArgs.advsql.WHERE," = ");// %%TODO: Needs to work for any operator
							ArrayAppend(sArgs.advsql.WHERE,sval(getField(sField.Relation["table"],sField.Relation["field"]),temp));
						}
						ArrayAppend(sArgs.advsql.WHERE,"					)");
					}

					if ( hasOtherFieldVal ) {
						ArrayAppend(aSQL,"(");
						ArrayAppend(aSQL,getFieldWhereSQL(tablename=arguments.tablename,field=sField.Relation["other-field"],value=arguments.OtherVal,tablealias=arguments.tablealias));
						ArrayAppend(aSQL," OR ");
					}
					if ( isNegativeOperator OR NOT Len(arguments.value) ) {
						ArrayAppend(aSQL," NOT ");
					}
					if ( NOT isAll ) {
						ArrayAppend(aSQL,"EXISTS");
					}
					ArrayAppend(aSQL," (");
						ArrayAppend(aSQL,getRecordsSQL(argumentCollection=sArgs));
					ArrayAppend(aSQL,"		)");
					if ( isAll ) {
						ArrayAppend(aSQL," = #ListLen(fieldval)#");
					}
					if ( hasOtherFieldVal ) {
						ArrayAppend(aSQL,")");
					}
				break;
			case "concat":
					ArrayAppend(aSQL,getFieldSelectSQL(arguments.tablename,arguments.field,arguments.tablealias,false));
					ArrayAppend(aSQL,getComparatorSQL(fieldval,"CF_SQL_VARCHAR",arguments.operator,true,arguments.sql));
				break;
			case "avg":
			case "count":
			case "max":
			case "min":
			case "sum":
					sArgs.tablename = sField.Relation["table"];
					sArgs.fieldlist = sField.Relation["field"];
					sArgs.advsql = StructNew();
					sArgs.join = StructNew();

					sAdvSQL = StructNew();
					if ( StructKeyExists(sField.Relation,"join-table") ) {
						sArgs.join["table"] = sField.Relation["join-table"];
						sArgs.join["onLeft"] = sField.Relation["remote-table-join-field"];
						sArgs.join["onRight"] = sField.Relation["join-table-field-remote"];
						sArgs.advsql["WHERE"] = ArrayNew(1);
						ArrayAppend(sArgs.advsql["WHERE"],getFieldSelectSQL(sField.Relation['join-table'],sField.Relation['join-table-field-local'],sField.Relation['join-table'],false));
						ArrayAppend(sArgs.advsql["WHERE"]," = ");
						ArrayAppend(sArgs.advsql["WHERE"],getFieldSelectSQL(arguments.tablename,sField.Relation['local-table-join-field'],arguments.tablealias,false));
					} else {
						sArgs.advsql["WHERE"] = ArrayNew(1);
						ArrayAppend(sArgs.advsql["WHERE"],getFieldSelectSQL(sField.Relation['table'],sField.Relation['join-field-remote'],sField.Relation['table'],false));
						ArrayAppend(sArgs.advsql["WHERE"]," = ");
						ArrayAppend(sArgs.advsql["WHERE"],getFieldSelectSQL(arguments.tablename,sField.Relation['join-field-local'],arguments.tablealias,false));
					}
					sArgs["function"] = sField.Relation["type"];
					if ( arguments.tablename EQ sField.Relation["table"] ) {
						sArgs["tablealias"] = sField.Relation["table"] & "_datamgr_inner_table";
					}
					ArrayAppend(aSQL,"(");
						ArrayAppend(aSQL,getRecordsSQL(argumentCollection=sArgs));
					ArrayAppend(aSQL,")");
					ArrayAppend(aSQL,getComparatorSQL(fieldval,"CF_SQL_NUMERIC",arguments.operator,true,arguments.sql));
				break;
			case "custom":
					if ( StructKeyExists(sField.Relation,"sql") AND Len(sField.Relation.sql) AND StructKeyExists(sField.Relation,"CF_DataType") ) {
						ArrayAppend(aSQL,"(");
						ArrayAppend(aSQL,"#sField.Relation.sql#");
						ArrayAppend(aSQL,")");
						ArrayAppend(aSQL,getComparatorSQL(fieldval,sField.Relation["CF_DataType"],arguments.operator,true,arguments.sql));
					} else {
						ArrayAppend(aSQL,"1 = 1");
					}
				break;
			default:
					ArrayAppend(aSQL, getFieldSelectSQL(tablename=arguments.tablename,field=arguments.field,tablealias=arguments.tablealias,useFieldAlias=false) );
					if ( StructKeyExists(sRelationTypes,sField.Relation.type) AND Len(sRelationTypes[sField.Relation.type].cfsqltype) ) {
						ArrayAppend(aSQL,getComparatorSQL(fieldval,sRelationTypes[sField.Relation.type].cfsqltype,arguments.operator,true,arguments.sql));
					} else {
						ArrayAppend(aSQL,getComparatorSQL(Val(fieldval),"CF_SQL_NUMERIC",arguments.operator,true,arguments.sql));
					}
		}
		if ( StructKeyExists(sField.Relation,"all-field") ) {
			sAllField = getField(arguments.tablename,sField.Relation["all-field"]);
			sArgs = arguments;
			sArgs.field = sField.Relation["all-field"];
			sArgs.value = 1;
			if ( isStruct(sAllField) ) {
				ArrayPrepend(aSQL," OR ");
				ArrayPrepend(aSQL,getFieldWhereSQL(argumentCollection=sArgs));
				ArrayPrepend(aSQL,"(");
				ArrayAppend(aSQL,")");
			}
		}
	} else {
		if ( getDatabase() EQ "Access" AND sField.CF_Datatype EQ "CF_SQL_BIT" ) {
			ArrayAppend(aSQL,"abs(#escape(arguments.tablealias & '.' & sField.ColumnName)#)");
		} else {
			ArrayAppend(aSQL,"#escape(arguments.tablealias & '.' & sField.ColumnName)#");
		}
		if ( getDatabase() EQ "Derby" AND arguments.operator CONTAINS "LIKE" ) {
			ArrayPrepend(aSQL,"LOWER(");
			ArrayAppend(aSQL,")");
			fieldval = LCase(fieldval);
		}
		ArrayAppend(aSQL,getComparatorSQL(fieldval,sField.CF_Datatype,arguments.operator,true,arguments.sql));
	}

	return aSQL;
}

/**
* @tablename The table in which to insert data.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
*/
public struct function getMatchingRecordKeys(
	required string tablename,
	required struct data,
	boolean pksonly=true
) {
	var aPKFields = getPKFields(arguments.tablename);
	var ii = 0;
	var sData = arguments.data;// holder for incoming data (just for readability)
	var inPK = StructNew();// holder for incoming pk data (just for readability)
	var qGetRecords = 0;
	var sResult = StructNew();
	var pkfields = "";

	if ( ArrayLen(aPKFields) ) {
		// Load up all primary key fields in temp structure
		for ( ii=1; ii LTE ArrayLen(aPKFields); ii++ ) {
			pkfields = ListAppend(pkfields,aPKFields[ii].ColumnName);
			if ( StructKeyHasLen(sData,aPKFields[ii].ColumnName) ) {
				inPK[aPKFields[ii].ColumnName] = sData[aPKFields[ii].ColumnName];
			}
		}
	}

	// Try to get existing record with given data
	if ( NOT arguments.pksonly ) {
		// Use only aPKFields if all are passed in, otherwise use all data available
		if ( ArrayLen(aPKFields) ) {
			if ( StructCount(inPK) EQ ArrayLen(aPKFields) ) {
				qGetRecords = getRecords(tablename=arguments.tablename,data=inPK,fieldlist=pkfields,MaxRows=1);
			} else {
				qGetRecords = getRecords(tablename=arguments.tablename,data=sData,fieldlist=pkfields,MaxRows=1);
			}
		} else {
			qGetRecords = getRecords(tablename=arguments.tablename,data=sData,fieldlist=pkfields,MaxRows=1);
		}
	}

	// If no matching records by all fields, Check for existing record by primary keys
	if ( arguments.pksonly OR NOT qGetRecords.RecordCount ) {
		if ( ArrayLen(aPKFields) ) {
			// All all primary key fields exist, check for record
			if ( StructCount(inPK) EQ ArrayLen(aPKFields) ) {
				qGetRecords = getRecords(tablename=arguments.tablename,data=inPK,fieldlist=pkfields,MaxRows=1);
			}
		}
	}

	if ( isQuery(qGetRecords) AND qGetRecords.RecordCount ) {
		for ( ii in ListToArray(qGetRecords.ColumnList) ) {
			sResult[ii] = qGetRecords[ii][1];
		}
	}

	return sResult;
}

/**
* I return a list of datypes that hold strings / character values.
*/
public string function getStringTypes() {
	return "";
}

/**
* I return the databases supported by this installation of DataMgr.
*/
public query function getSupportedDatabases() {
	var qComponents = 0;
	var aComps = ArrayNew(1);
	var i = 0;
	var qDatabases = QueryNew("Database,DatabaseName,shortstring,driver");
	var sComponent = 0;

	if ( StructKeyExists(variables,"databases") AND isQuery(variables.databases) ) {
		qDatabases = variables.databases;
	} else {
		qComponents = directoryList(path=getDirectoryFromPath(GetCurrentTemplatePath()),filter = "*.cfc");
		for ( sComponent in qComponents ) {
			if ( sComponent.name CONTAINS "DataMgr_" ) {
				try {
					ArrayAppend(aComps,CreateObject("component","#ListFirst(sComponent.name,'.')#").init(""));
					QueryAddRow(qDatabases);
					QuerySetCell(qDatabases, "Database", ReplaceNoCase(ListFirst(sComponent.name,"."),"DataMgr_","") );
					QuerySetCell(qDatabases, "DatabaseName", aComps[ArrayLen(aComps)].getDatabase() );
					QuerySetCell(qDatabases, "shortstring", aComps[ArrayLen(aComps)].getDatabaseShortString() );
					QuerySetCell(qDatabases, "driver", aComps[ArrayLen(aComps)].getDatabaseDriver() );
				} catch (any e) {

				}
			}
		}
		variables.databases = qDatabases;
	}

	return qDatabases;
}

/**
* I return information about all of the tables currently loaded into this instance of Data Manager.
*/
public struct function getTableData(string tablename) {

	var sResult = 0;

	if ( StructKeyExists(arguments,"tablename") AND Len(arguments.tablename) ) {
		checkTable(arguments.tablename);// Check whether table is loaded
		sResult = StructNew();
		if ( ListFindNoCase(StructKeyList(variables.tables),arguments.tablename) ) {
			sResult[arguments.tablename] = variables.tables[arguments.tablename];
		}
	} else {
		sResult = variables.tables;
	}

	return sResult;
}

/**
* I return an array of fields that can be updated.
*/
public array function getUpdateableFields(required string tablename) {
	var bTable = checkTable(arguments.tablename);// Check whether table is loaded
	var ii = 0;// counter
	var arrFields = ArrayNew(1);// array of udateable fields

	if ( StructKeyExists(variables.tableprops,arguments.tablename) AND StructKeyExists(variables.tableprops[arguments.tablename],"updatefields") ) {
		arrFields = variables.tableprops[arguments.tablename]["updatefields"];
	} else {
		for ( ii=1; ii LTE ArrayLen(variables.tables[arguments.tablename]); ii++ ) {
			// Make sure field isn't a relation
			if ( StructKeyExists(variables.tables[arguments.tablename][ii],"CF_Datatype") AND NOT StructKeyExists(variables.tables[arguments.tablename][ii],"Relation") ) {
				// Make sure field isn't a primary key
				if ( NOT StructKeyExists(variables.tables[arguments.tablename][ii],"PrimaryKey") OR NOT variables.tables[arguments.tablename][ii].PrimaryKey ) {
					ArrayAppend(arrFields, variables.tables[arguments.tablename][ii]);
				}
			}
		}
		variables.tableprops[arguments.tablename]["updatefields"] = arrFields;
	}

	return arrFields;
}

public string function getVersion() {
	return variables.DataMgrVersion;
}

/**
* @tablename The table from which to return a record.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @advsql A structure of sqlarrays for each area of a query (SELECT,FROM,WHERE,ORDER BY).
* @filters An array of filters to apply to the query.
*/
public boolean function hasRecords(
	required string tablename,
	any data,
	struct advsql,
	array filters
) {
	var aSQL = [];
	var qHasRecords = 0;
	var result = false;

	ArrayAppend(aSQL,"SELECT	CASE WHEN EXISTS ( ");
		ArrayAppend(aSQL,"SELECT	1 ");
		ArrayAppend(aSQL,"FROM");
		ArrayAppend(aSQL,getFromSQL(argumentCollection=arguments));
		ArrayAppend(aSQL,"WHERE		1 = 1");
		ArrayAppend(aSQL,getWhereSQL(argumentCollection=arguments));
	ArrayAppend(aSQL," ) THEN #getBooleanSqlValue(1)# ELSE #getBooleanSqlValue(0)# END AS hasRecords");

	qHasRecords = runSQLArray(aSQL);

	return qHasRecords.hasRecords;
}

/**
* I insert a record into the given table with the provided data and do my best to return the primary key of the inserted record.
* @tablename The table in which to insert data.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @OnExists The action to take if a record with the given values exists. Possible values: insert (inserts another record), error (throws an error), update (updates the matching record), skip (performs no action), save (updates only for matching primary key)).
* @fieldlist A list of insertable fields. If left blank, any field can be inserted.
* @truncate Should the field values be automatically truncated to fit in the available space for each field?
* @checkfields Only for OnExists=update. A list of fields to use to check for existing records (default to checking all updateable fields for update).
*/
public string function insertRecord(
	required string tablename,
	required struct data,
	string OnExists="insert",
	string fieldlist="",
	boolean truncate=false,
	string checkfields=""
) {
	var OnExistsValues = "insert,error,update,skip";// possible values for OnExists argument
	var ii = 0;// generic counter
	var pkfields = 0;
	var sData = arguments.data;// holder for incoming data (just for readability)
	var qGetRecords = QueryNew('none');
	var result = "";// will hold primary key
	var qCheckKey = 0;// Used to get primary key
	var sqlarray = ArrayNew(1);
	var aInsertSQL = ArrayNew(1);
	var sMatchingKeys = 0;
	var sCheckData = 0;
	var ChangeUUID = CreateUUID();
	var sTable = {table=Arguments.tablename};
	var isTiming = false AND (Arguments.tablename EQ "secProfiles");
	var pklist = getPrimaryKeyFieldNames(arguments.tablename);
	var sLog = 0;

	sData = getRelationValues(arguments.tablename,sData);

	if (
		(
			Arguments.OnExists EQ "update"
			OR
			Arguments.OnExists EQ "save"
		)
		AND
		NOT Len(Arguments.checkfields)
	) {
		Arguments.checkfields = getCheckFields(Arguments.tablename);
		if ( Len(Arguments.checkfields) ) {
			Arguments.OnExists = "update";
		}
	}

	if ( NOT StructKeyExists(Arguments,"log") ) {
		Arguments.log = variables.doLogging;
	}
	if ( Arguments.log ) {
		if ( arguments.tablename EQ variables.logtable ) {
			Arguments.log = false;
		}
	}

	pkfields = getPKFields(arguments.tablename);

	if ( arguments.truncate ) {
		sData = variables.truncate(arguments.tablename,sData);
	}

	sCheckData = StructCopy(sData);

	if ( ListLen(arguments.checkfields) ) {
		arguments.checkfields = ListAppend(pklist,arguments.checkfields);
		for ( ii in sCheckData ) {
			if ( NOT ListFindNoCase(arguments.checkfields,ii) ) {
				StructDelete(sCheckData,ii);
			}
		}
	}

	// Check for existing records if an action other than insert should be take if one exists
	if ( arguments.OnExists NEQ "insert" ) {
		sMatchingKeys = getMatchingRecordKeys(tablename=arguments.tablename,data=sCheckData,pksonly=(arguments.OnExists EQ "save"));
		if ( StructCount(sMatchingKeys) ) {
			switch (arguments.OnExists) {
				case "error":
						throwDMError("#arguments.tablename#: A record with these criteria already exists.");
					break;
				case "update":
				case "save":
						StructAppend(sData,sMatchingKeys,"yes");
						result = updateRecord(arguments.tablename,sData);
						return result;
					break;
				case "skip":
						if ( ArrayLen(pkfields) ) {
							return sMatchingKeys[pkfields[1].ColumnName];
						} else {
							return 0;
						}
					break;
			}
		}
	}

	// Perform insert
	aInsertSQL = insertRecordSQL(tablename=arguments.tablename,data=sData,fieldlist=arguments.fieldlist);
	if ( ArrayLen(aInsertSQL) ) {
		announceEvent(tablename=arguments.tablename,action="beforeInsert",method="insertRecord",data=sData,fieldlist=Arguments.fieldlist,Args=Arguments,sql=aInsertSQL,ChangeUUID=ChangeUUID);
		qCheckKey = runSQLArray(aInsertSQL);
	}

	if ( isDefined("qCheckKey") AND isQuery(qCheckKey) AND qCheckKey.RecordCount AND ListFindNoCase(qCheckKey.ColumnList,"NewID") ) {
		result = qCheckKey.NewID;
	}

	// Get primary key
	if ( Len(result) EQ 0 ) {
		if ( ArrayLen(pkfields) AND StructKeyExists(sData,pkfields[1].ColumnName) AND useField(sData,pkfields[1]) AND NOT isIdentityField(pkfields[1]) ) {
			result = sData[pkfields[1].ColumnName];
		} else if ( ArrayLen(pkfields) AND StructKeyExists(pkfields[1],"Increment") AND isBoolean(pkfields[1].Increment) AND pkfields[1].Increment ) {
			result = getInsertedIdentity(arguments.tablename,pkfields[1].ColumnName);
		} else {
			try {
				result = getPKFromData(arguments.tablename,sData);
			} catch (any e) {
				result = "";
			}
		}
	}

	// set pkfield so that we can save relation data
	if ( ArrayLen(pkfields) ) {
		if ( ArrayLen(pkfields) EQ 1 AND NOT Len(result) ) {
			result = getPKFromData(arguments.tablename,sData);
		}
		sData[pkfields[1].ColumnName] = result;
		if ( Len(Trim(result)) ) {
			saveRelations(arguments.tablename,sData,pkfields[1],result);
		}
	}

	// Log insert
	if ( Arguments.log ) {
		sLog = {action="insert",data=sData,sql=sqlarray};
		if ( ArrayLen(pkfields) EQ 1 AND StructKeyExists(sData,pkfields[1].ColumnName) ) {
			sLog["pkval"] = sData[pkfields[1].ColumnName];
		}
		logAction(ArgumentCollection=sLog);
	}

	announceEvent(tablename=arguments.tablename,action="afterInsert",method="insertRecord",data=sData,fieldlist=Arguments.fieldlist,Args=Arguments,sql=aInsertSQL,pkvalue=result,ChangeUUID=ChangeUUID);

	setCacheDate();

	return result;
}

/**
* I insert a record into the given table with the provided data and do my best to return the primary key of the inserted record.
* @tablename The table in which to insert data.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @fieldlist A list of insertable fields. If left blank, any field can be inserted.
*/
public array function insertRecordSQL(
	required string tablename,
	required struct data,
	string fieldlist=""
) {

	return insertRecordsSQL(tablename=arguments.tablename,data_set=arguments.data,fieldlist=arguments.fieldlist);
}

/**
* @data_set A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @data_where A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @fieldlist A list of insertable fields. If left blank, any field can be inserted.
* @filters An array of filters to apply to the query.
*/
public array function insertRecordsSQL(
	required string tablename,
	required struct data_set,
	struct data_where,
	string fieldlist="",
	array filters=[]
) {
	var bSetGuid = false;
	var bGetNewSeqId = false;// Alternate set GUID approach for newsequentialid() support (SQL Server specific)
	var GuidVar = "";
	var sqlarray = ArrayNew(1);
	var ii = 0;
	var fieldcount = 0;
	var bUseSubquery = false;
	var fields = getUpdateableFields(arguments.tablename);
	var pkfields = getPKFields(arguments.tablename);
	var sData = clean(arguments.data_set);// holder for incoming data (just for readability)
	var inf = "";
	var Specials = "CreationDate,LastUpdatedDate,Sorter,UUID";

	// Restrict data to fieldlist
	if ( Len(Trim(arguments.fieldlist)) ) {
		for ( ii in sData ) {
			if ( NOT ListFindNoCase(arguments.fieldlist,ii) ) {
				StructDelete(sData,ii);
			}
		}
	}

	sData = getRelationValues(arguments.tablename,sData);

	// Create GUID for insert SQL Server where the table has on primary key field and it is a GUID
	if ( ArrayLen(pkfields) EQ 1 AND pkfields[1].CF_Datatype EQ "CF_SQL_IDSTAMP" AND getDatabase() EQ "MS SQL" AND NOT StructKeyExists(sData,pkfields[1].ColumnName) ) {
		if ( StructKeyExists(pkfields[1], "default") and pkfields[1].Default contains "newsequentialid" ) {
			bGetNewSeqId = true;
		} else {
			bSetGuid = true;
		}
	}

	if ( StructKeyExists(arguments,"data_where") AND StructCount(arguments.data_where) ) {
		bUseSubquery = true;
	}

	// Create variable to hold GUID for SQL Server GUID inserts
	if ( bSetGuid OR bGetNewSeqId ) {
		lock timeout = 30 name = "DataMgr_GuidNum" type = "EXCLUSIVE" throwontimeout = "No" {
			// %%I cant figure out a way to safely increment the variable to make it unique for a transaction w/0 the use of request scope
			if ( isDefined("request.DataMgr_GuidNum")) {
				request.DataMgr_GuidNum = Val(request.DataMgr_GuidNum) + 1;
			} else {
				request.DataMgr_GuidNum = 1;
			}
			GuidVar = "GUID#request.DataMgr_GuidNum#";
		}
	}

	// Insert record
	if ( bSetGuid ) {
		ArrayAppend(sqlarray,"DECLARE @#GuidVar# uniqueidentifier");
		ArrayAppend(sqlarray,"SET @#GuidVar# = NEWID()");
	} else if ( bGetNewSeqId ) {
		ArrayAppend(sqlarray, "DECLARE @#GuidVar# TABLE (inserted_guid uniqueidentifier);");
	}
	ArrayAppend(sqlarray,"INSERT INTO #escape(Variables.prefix & arguments.tablename)# (");

	// Loop through all updateable fields
	for ( ii=1; ii LTE ArrayLen(fields); ii++ ) {
		if (
				( useField(sData,fields[ii]) OR (StructKeyExists(fields[ii],"Default") AND Len(fields[ii].Default) AND getDatabase() EQ "Access") )
			OR	NOT ( useField(sData,fields[ii]) OR StructKeyExists(fields[ii],"Default") OR fields[ii].AllowNulls )
			OR	( StructKeyExists(fields[ii],"Special") AND Len(fields[ii].Special) AND ListFindNoCase(Specials,fields[ii]["Special"]) )
		) {// Include the field in SQL if it has appropriate data
			fieldcount = fieldcount + 1;
			if ( fieldcount GT 1 ) {
				ArrayAppend(sqlarray,",");// put a comma before every field after the first
			}
			ArrayAppend(sqlarray,escape(fields[ii].ColumnName));
		}
	}
	for ( ii=1; ii LTE ArrayLen(pkfields); ii++ ) {
		if ( ( useField(sData,pkfields[ii]) AND NOT isIdentityField(pkfields[ii]) ) OR ( pkfields[ii].CF_Datatype EQ "CF_SQL_IDSTAMP" AND bSetGuid ) ) {// Include the field in SQL if it has appropriate data ---
			fieldcount = fieldcount + 1;
			if ( fieldcount GT 1 ) {
				ArrayAppend(sqlarray,",");// put a comma before every field after the first
			}
			ArrayAppend(sqlarray,"#escape(pkfields[ii].ColumnName)#");
		}
	}
	ArrayAppend(sqlarray,")");
	if ( bGetNewSeqId ) {
		ArrayAppend(sqlarray, "OUTPUT INSERTED.#escape(pkfields[1].ColumnName)# INTO @#GuidVar#");
	}
	if ( bUseSubquery) {
		ArrayAppend(sqlarray,"SELECT ");
	} else {
		ArrayAppend(sqlarray,"VALUES (");
	}
	fieldcount = 0;
	// Loop through all updateable fields
	for ( ii=1; ii LTE ArrayLen(fields); ii++ ) {
		if ( useField(sData,fields[ii]) ) {// Include the field in SQL if it has appropriate data
			checkLength(fields[ii],sData[fields[ii].ColumnName]);
			fieldcount = fieldcount + 1;
			if ( fieldcount GT 1 ) {
				ArrayAppend(sqlarray,",");// put a comma before every field after the first
			}
			ArrayAppend(sqlarray,sval(fields[ii],sData));
		} else if ( StructKeyExists(fields[ii],"Special") AND Len(fields[ii].Special) AND ListFindNoCase(Specials,fields[ii]["Special"]) ) {
			// Set fields based on specials
			fieldcount = fieldcount + 1;
			if ( fieldcount GT 1 ) {
				ArrayAppend(sqlarray,",");// put a comma before every field after the first
			}
			switch (fields[ii].Special) {
				case "CreationDate":
						ArrayAppend(sqlarray,getFieldNowValue(arguments.tablename,fields[ii]));
					break;
				case "LastUpdatedDate":
						ArrayAppend(sqlarray,getFieldNowValue(arguments.tablename,fields[ii]));
					break;
				case "Sorter":
						ArrayAppend(sqlarray,getNewSortNum(arguments.tablename,fields[ii].ColumnName));
					break;
				case "UUID":
						if ( structKeyExists(fields[ii],"CF_DataType") ) {
							ArrayAppend(sqlarray,queryparam(cfsqltype=fields[ii].CF_DataType,value=CreateUUID()));
						} else {
							ArrayAppend(sqlarray,queryparam(cfsqltype="CF_SQL_VARCHAR",value=CreateUUID()));
						}
					break;
			}
		} else if ( StructKeyExists(fields[ii],"Default") AND Len(fields[ii].Default) AND getDatabase() EQ "Access" ) {
			fieldcount = fieldcount + 1;
			if ( fieldcount GT 1 ) {
				ArrayAppend(sqlarray,",");// put a comma before every field after the first
			}
			ArrayAppend(sqlarray,fields[ii].Default);
		} else if ( NOT ( useField(sData,fields[ii]) OR StructKeyExists(fields[ii],"Default") OR fields[ii].AllowNulls ) ) {
			fieldcount = fieldcount + 1;
			if ( fieldcount GT 1 ) {
				ArrayAppend(sqlarray,",");// put a comma before every field after the first
			}
			ArrayAppend(sqlarray,"''");
		}
	}
	for ( ii=1; ii LTE ArrayLen(pkfields); ii++ ) {
		if ( useField(sData,pkfields[ii]) AND NOT isIdentityField(pkfields[ii]) ) {// Include the field in SQL if it has appropriate data
			checkLength(pkfields[ii],sData[pkfields[ii].ColumnName]);
			fieldcount = fieldcount + 1;
			if ( fieldcount GT 1 ) {
				ArrayAppend(sqlarray,",");// put a comma before every field after the first
			}
			ArrayAppend(sqlarray,sval(pkfields[ii],sData));
		} else if ( pkfields[ii].CF_Datatype EQ "CF_SQL_IDSTAMP" AND bSetGuid ) {
			fieldcount = fieldcount + 1;
			if ( fieldcount GT 1 ) {
				ArrayAppend(sqlarray,",");// put a comma before every field after the first
			}
			ArrayAppend(sqlarray,"@#GuidVar#");
		}
	}
	if ( fieldcount EQ 0 ) {
		//<cfsavecontent variable="inf"><cfdump var="#sData#"></cfsavecontent>--->
		throwDMError("You must pass in at least one field that can be inserted into the database. Fields: #StructKeyList(sData)#","NeedInsertFields");
	}
	if ( bUseSubquery ) {
		ArrayAppend(sqlarray,"WHERE NOT EXISTS (");
			ArrayAppend(sqlarray,"SELECT 1");
			ArrayAppend(sqlarray,"FROM #escape(arguments.tablename)#");
			ArrayAppend(sqlarray,"WHERE 1 = 1");
			ArrayAppend(sqlarray,getWhereSQL(tablename=arguments.tablename,data=arguments.data_where,filters=arguments.filters));
		ArrayAppend(sqlarray,")");
	} else {
		ArrayAppend(sqlarray,")");
	}
	if ( bSetGuid ) {
		ArrayAppend(sqlarray,";");
		ArrayAppend(sqlarray,"SELECT @#GuidVar# AS NewID");
	} else if ( bGetNewSeqId ) {
		ArrayAppend(sqlarray,";");
		ArrayAppend(sqlarray, "SELECT inserted_guid AS NewID FROM @#GuidVar#;");
	}

	if ( fieldcount EQ 0 ) {
		sqlarray = ArrayNew(1);
	}

	return sqlarray;
}

/**
* @tablename The name of the table from which to delete a record.
* @data A structure indicating the record to delete. A key indicates a field. The structure should have a key for each primary key in the table.
*/
public boolean function isDeletable(
	required string tablename,
	required struct data
) {
	return ( Len(getDeletionConflicts(argumentCollection=arguments)) EQ 0 );
}

public boolean function isLogging() {
	if ( NOT StructKeyExists(variables,"doLogging") ) {
		variables.doLogging = false;
	}

	return variables.doLogging;
}

public boolean function isLogicalDeletion(required string tablename) {
	var fields = getUpdateableFields(arguments.tablename);
	var ii = 0;
	var result = false;

	for ( ii=1; ii LTE ArrayLen(fields); ii++ ) {
		if (
				( StructKeyExists(fields[ii],"Special") AND fields[ii].Special EQ "DeletionMark" )
			AND	(
						fields[ii].CF_DataType EQ "CF_SQL_BIT"
					OR	fields[ii].CF_DataType EQ "CF_SQL_DATE"
					OR	fields[ii].CF_DataType EQ "CF_SQL_DATETIME"
				)
		) {
			result = true;
			break;
		}
	}

	return result;
}

/**
* @tablename The table in which to insert data.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
*/
public boolean function isMatchingRecord(
	required string tablename,
	required struct data,
	boolean pksonly=true
) {
	return BooleanFormat( StructCount(getMatchingRecordKeys(argumentCollection=arguments)) GT 0 );
}

public boolean function isValidDate(required string value) {
	var result = (
			isDate(arguments.value)
		OR	(
					isNumeric(arguments.value)
				AND	arguments.value GT 0
				AND	arguments.value LT 65538
			)
	);

	return result;
}

/**
* I load a table from the database into DataMgr.
*/
public void function loadTable(
	required string tablename,
	boolean ErrorOnNotExists=true
) {
	var ii = 0;
	var arrTableStruct = 0;

	try {
		arrTableStruct = getDBTableStruct(arguments.tablename);

		for ( ii=1; ii LTE ArrayLen(arrTableStruct); ii++ ) {
			if ( StructKeyExists(arrTableStruct[ii],"Default") AND Len(arrTableStruct[ii]["Default"]) ) {
				arrTableStruct[ii]["Default"] = makeDefaultValue(arrTableStruct[ii]["Default"],arrTableStruct[ii].CF_DataType);
			}
		}
		addTable(arguments.tablename,arrTableStruct);

		setCacheDate();
	} catch (any e) {
		if ( arguments.ErrorOnNotExists ) {
			rethrow;
		}
	}
}

/**
* I add tables from XML and optionally create tables/columns as needed (I can also load data to a table upon its creation).
* @xmldata XML data of tables and columns to load into DataMgr. Follows schema: http://www.bryantwebconsulting.com/cfcs/DataMgr.xsd
* @docreate I indicate if the table should be created in the database if it doesn't already exist.
* @addcolumns I indicate if missing columns should be be created.
*/
public function loadXML(
	required string xmldata,
	boolean docreate=false,
	boolean addcolumns=false
) {
	var xmlstring = "";
	var dbtables = "";
	var MyTables = StructNew();
	var varXML = 0;
	var xTables = 0;
	var xData = 0;

	var i = 0;
	var j = 0;
	var k = 0;
	var mytable = 0;
	var xTable = 0;
	var sTable = 0;
	var thisTableName = 0;
	var thisField = 0;
	var sFieldDef = 0;
	var aTableNames = 0;
	var sDBTableFields = StructNew();

	var aJoinRelations = ArrayNew(1);
	var sRelation = 0;
	var sJoinTables = 0;

	var tables_made = "";
	var fields = StructNew();
	var fieldlist = "";
	//var qTest = 0;

	var colExists = false;
	//var arrDbTable = 0;

	var FailedSQL = "";
	var DBErrs = "";
	var sArgs = 0;
	var sFilter = 0;
	var sField = StructNew();
	var sTablesFilters = StructNew();
	var sTablesProps = StructNew();
	var key = "";

	var sDBTableData = 0;

	lock name="DataMgr_loadXml_#variables.UUID#" timeout="1800" throwontimeout="yes" {
		if ( isSimpleValue(arguments.xmldata) ) {
			if ( arguments.xmldata CONTAINS "</tables>" ) {
				xmlstring = arguments.xmldata;
			} else if ( FileExists(arguments.xmldata) ) {
				xmlstring = FileRead(arguments.xmldata);
			} else {
				throwDMError("xmldata argument for LoadXML must be a valid XML or a path to a file holding a valid XML string.","LoadFailed");
			}
			varXML = XmlParse(xmlstring,"no");
		} else if ( isXmlDoc(arguments.xmldata) ) {
			varXML = arguments.xmldata;
		} else {
			throwDMError("xmldata argument for LoadXML must be a valid XML or a path to a file holding a valid XML string.","LoadFailed");
		}

		xTables = varXML.XmlRoot.XmlChildren;
		xData = XmlSearch(varXML, "//data");
		aTableNames = XmlSearch(varXML, "//table/@name");

		for (i=1; i LTE ArrayLen(aTableNames);i=i+1) {
			tables_made = ListAppend(tables_made,ListLast(aTableNames[i].XmlValue,"."));
		}

		dbtables = getDatabaseTablesCache();

		//  Loop over all root elements in XML
		for (i=1; i LTE ArrayLen(xTables);i=i+1) {
			//  If element is a table and has a name, add it to the data
			if ( xTables[i].XmlName EQ "table" AND StructKeyExists(xTables[i].XmlAttributes,"name") ) {
				//temp variable to reference this table
				xTable = xTables[i];
				if ( StructKeyExists(xTables[i],"XmlAttributes") AND StructCount(xTables[i].XmlAttributes) ) {
					sTable = StructNew();
					for ( key in xTables[i].XmlAttributes ) {
						sTable[key] = xTables[i].XmlAttributes[key];
					}
				}
				sTable["filters"] = StructNew();
				//table name
				thisTableName = ListLast(xTable.XmlAttributes["name"],".");
				//Add table to list
				tables_made = ListAppend(tables_made,thisTableName);
				//introspect table
				if ( ListFindNoCase(dbtables,thisTableName) AND StructKeyExists(xTables[i].XmlAttributes,"introspect") AND isBoolean(xTables[i].XmlAttributes.introspect) AND xTables[i].XmlAttributes.introspect ) {
					loadTable(thisTableName,false);
				}
				//  Only add to struct if table doesn't exist or if cols should be altered
				//if ( NOT StructKeyExists(variables.tables,thisTableName) ) {//arguments.addcolumns OR NOT ( StructKeyExists(variables.tables,thisTableName) OR ListFindNoCase(dbtables,thisTableName) )
					//Add to array of tables to add/alter
					if ( NOT StructKeyExists(MyTables,thisTableName) ) {
						MyTables[thisTableName] = ArrayNew(1);
					}
					if ( NOT StructKeyExists(fields,thisTableName) ) {
						fields[thisTableName] = "";
					}
					//  Loop through fields in table
					for (j=1; j LTE ArrayLen(xTable.XmlChildren);j=j+1) {
						//  If this xml tag is a field
						if ( xTable.XmlChildren[j].XmlName EQ "field" OR xTable.XmlChildren[j].XmlName EQ "column" ) {
							thisField = xTable.XmlChildren[j].XmlAttributes;
							sFieldDef = StructNew();
							sFieldDef["tablename"] = thisTableName;
							//If "name" attribute exists, but "ColumnName" att doesn't use name as ColumnName
							if ( StructKeyExists(thisField,"name") AND NOT StructKeyExists(thisField,"ColumnName") ) {
								thisField["ColumnName"] = thisField["name"];
							}
							if ( StructKeyExists(thisField,"ColumnName") ) {
								//Set ColumnName
								sFieldDef["ColumnName"] = thisField["ColumnName"];
								//If "cfsqltype" attribute exists, but "CF_DataType" att doesn't use name as CF_DataType
								if ( StructKeyExists(thisField,"cfsqltype") AND NOT StructKeyExists(thisField,"CF_DataType") ) {
									thisField["CF_DataType"] = thisField["cfsqltype"];
								}
								//Set CF_DataType
								if ( StructKeyExists(thisField,"CF_DataType") ) {
									sFieldDef["CF_DataType"] = thisField["CF_DataType"];
								}
								if ( StructKeyExists(sFieldDef,"CF_DataType") ) {
									//Set PrimaryKey (defaults to false)
									if ( StructKeyExists(thisField,"PrimaryKey") AND isBoolean(thisField["PrimaryKey"]) AND thisField["PrimaryKey"] ) {
										sFieldDef["PrimaryKey"] = true;
									} else {
										sFieldDef["PrimaryKey"] = false;
									}
									//Set AllowNulls (defaults to true)
									if ( StructKeyExists(thisField,"AllowNulls") AND isBoolean(thisField["AllowNulls"]) AND NOT thisField["AllowNulls"] ) {
										sFieldDef["AllowNulls"] = false;
									} else {
										sFieldDef["AllowNulls"] = true;
									}
									//Set length (if it exists and isnumeric)
									if ( StructKeyExists(thisField,"Length") AND isNumeric(thisField["Length"]) AND NOT sFieldDef["CF_DataType"] EQ "CF_SQL_LONGVARCHAR" ) {
										sFieldDef["Length"] = Val(thisField["Length"]);
									} else {
										sFieldDef["Length"] = 0;
									}
									//Set increment (if exists and true)
									if ( StructKeyExists(thisField,"Increment") AND isBoolean(thisField["Increment"]) AND thisField["Increment"] ) {
										sFieldDef["Increment"] = true;
									} else {
										sFieldDef["Increment"] = false;
									}
									//Set precision (if exists and true)
									if ( StructKeyExists(thisField,"Precision") AND isNumeric(thisField["Precision"]) ) {
										sFieldDef["Precision"] = Val(thisField["Precision"]);
									} else {
										sFieldDef["Precision"] = "";
									}
									//Set scale (if exists and true)
									if ( StructKeyExists(thisField,"Scale") AND isNumeric(thisField["Scale"]) ) {
										sFieldDef["Scale"] = Val(thisField["Scale"]);
									} else {
										sFieldDef["Scale"] = "";
									}
								}
								//Set default (if exists)
								if ( StructKeyExists(thisField,"Default") AND Len(thisField["Default"]) ) {
									//sFieldDef["Default"] = makeDefaultValue(thisField["Default"],sFieldDef["CF_DataType"]);
									sFieldDef["Default"] = thisField["Default"];
								//} else {
								//	sFieldDef["Default"] = "";
								}
								//Set Special (if exists)
								if ( StructKeyExists(thisField,"Special") ) {
									sFieldDef["Special"] = Trim(thisField["Special"]);
								}
								if ( StructKeyExists(thisField,"SpecialDateType") ) {
									sFieldDef["SpecialDateType"] = Trim(thisField["SpecialDateType"]);
								}
								if ( StructKeyExists(thisField,"useInMultiRecordsets") AND isBoolean(thisField.useInMultiRecordsets) AND NOT thisField.useInMultiRecordsets ) {
									sFieldDef["useInMultiRecordsets"] = false;
								} else {
									sFieldDef["useInMultiRecordsets"] = true;
								}
								//Set alias (if exists)
								if ( StructKeyHasLen(thisField,"alias") ) {
									sFieldDef["alias"] = Trim(thisField["alias"]);
								}
								if ( StructKeyExists(thisField,"ftable") ) {
									sFieldDef["ftable"] = Trim(thisField["ftable"]);
								}
								if ( StructKeyExists(thisField,"OtherField") ) {
									sFieldDef["OtherField"] = Trim(thisField["OtherField"]);
								}
								if ( StructKeyExists(thisField,"OldField") ) {
									sFieldDef["OldField"] = Trim(thisField["OldField"]);
								}
								//sJoinTables
								//Set relation (if exists)
								if ( ArrayLen(xTable.XmlChildren[j].XmlChildren) EQ 1 AND xTable.XmlChildren[j].XmlChildren[1].XmlName EQ "relation" ) {
									//sFieldDef["Relation"] = expandRelationStruct(xTable.XmlChildren[j].XmlChildren[1].XmlAttributes,sFieldDef);
									sFieldDef["Relation"] = StructFromArgs(xTable.XmlChildren[j].XmlChildren[1].XmlAttributes);
									if ( StructKeyExists(xTable.XmlChildren[j].XmlChildren[1],"filter") ) {
										sFieldDef["Relation"]["filters"] = ArrayNew(1);
										for ( k=1; k LTE ArrayLen(xTable.XmlChildren[j].XmlChildren[1].filter); k=k+1 ) {
											ArrayAppend(sFieldDef["Relation"]["filters"],xTable.XmlChildren[j].XmlChildren[1].filter[k].XmlAttributes);
										}
									}
									if ( StructKeyExists(sFieldDef["Relation"],"join-table") OR StructKeyExists(sFieldDef["Relation"],"join_table") ) {
										ArrayAppend(aJoinRelations,StructNew());
										aJoinRelations[ArrayLen(aJoinRelations)]["table"] = thisTableName;
										aJoinRelations[ArrayLen(aJoinRelations)]["sField"] = sFieldDef;
									}
								}
								//Copy data set in temporary structure to result storage
								if (
											( NOT ListFindNoCase(fields[thisTableName], sFieldDef["ColumnName"]) )
										AND	NOT (
														StructKeyExists(variables.tableprops,thisTableName)
													AND	StructKeyExists(variables.tableprops[thisTableName],"fieldlist")
													AND	ListFindNoCase(variables.tableprops[thisTableName]["fieldlist"], sFieldDef["ColumnName"])
												)
									) {
									fields[thisTableName] = ListAppend(fields[thisTableName],sFieldDef["ColumnName"]);
									ArrayAppend(MyTables[thisTableName], convertColumnAtts(argumentCollection=sFieldDef));
									//MyTables[thisTableName][ArrayLen(MyTables[thisTableName])] = Duplicate(sFieldDef);
								} else if ( StructKeyExists(variables.tables,thisTableName) AND getColumnIndex(thisTableName,sFieldDef["ColumnName"]) ) {
									variables.tables[thisTableName][getColumnIndex(thisTableName,sFieldDef["ColumnName"])] = convertColumnAtts(argumentCollection=sFieldDef);
								}
							}
						}// /If this xml tag is a field
						//  If this xml tag is a filter
						if ( xTable.XmlChildren[j].XmlName EQ "filter" ) {
							if (
									StructKeyExists(xTable.XmlChildren[j].XmlAttributes,"name") AND Len(Trim(xTable.XmlChildren[j].XmlAttributes["name"]))
								AND	StructKeyExists(xTable.XmlChildren[j].XmlAttributes,"field") AND Len(Trim(xTable.XmlChildren[j].XmlAttributes["field"]))
								AND	StructKeyExists(xTable.XmlChildren[j].XmlAttributes,"operator") AND Len(Trim(xTable.XmlChildren[j].XmlAttributes["operator"]))
							) {
								sFilter = StructNew();
								sFilter["field"] = xTable.XmlChildren[j].XmlAttributes["field"];
								sFilter["operator"] = xTable.XmlChildren[j].XmlAttributes["operator"];
								sTable["filters"][xTable.XmlChildren[j].XmlAttributes["name"]] = sFilter;
							}
						}
					}// /Loop through fields in table
				//}// /Only add to struct if table doesn't exist or if cols should be altered
				sTablesFilters[thisTableName] = sTable["filters"];
				sTablesProps[thisTableName] = sTable;
				StructDelete(sTablesProps[thisTableName],"filters");
			}// /If element is a table and has a name, add it to the data
		}// /Loop over all root elements in XML

		//Add tables to DataMgr
		for ( mytable in MyTables ) {
			addTable(mytable,MyTables[mytable],sTablesFilters[mytable],sTablesProps[mytable]);
		}

		//Create tables if requested to do so.
		if ( arguments.docreate ) {
			//Try to create the tables, if that fails we'll load up the failed SQL in a variable so it can be returned in a handy lump.
			try {
				tables_made = CreateTables(tables_made,dbtables);
			} catch (DataMgr exception) {
				if ( Len(exception.Detail) ) {
					FailedSQL = ListAppend(FailedSQL,exception.Detail,";");
				} else {
					FailedSQL = ListAppend(FailedSQL,exception.Message,";");
				}
				if ( Len(exception.extendedinfo) ) {
					DBErrs = ListAppend(DBErrs,exception.Message,";");
				}
			}

		}// if

		if ( Len(FailedSQL) ) {
			throwDMError("LoadXML Failed (verify datasource ""#variables.datasource#"" is correct) #DBErrs#","LoadFailed",FailedSQL,DBErrs);
		}

		//Add columns to tables as needed if requested to do so.
		if ( arguments.addcolumns ) {
			//Loop over tables (from XML)
			for ( mytable in MyTables ) {
				// get list of fields in table
				if ( StructKeyExists(sDBTableFields,mytable) ) {
					fieldlist = sDBTableFields[mytable];
				} else {
					fieldlist = getDBFieldList(mytable);
				}
				//Loop over fields (from XML)
				for ( i=1; i LTE ArrayLen(MyTables[mytable]); i=i+1 ) {
					colExists = false;
					//check for existence of this field
					if ( ListFindNoCase(fieldlist,MyTables[mytable][i].ColumnName) OR StructKeyExists(MyTables[mytable][i],"Relation") OR NOT StructKeyExists(MyTables[mytable][i],"CF_DataType") ) {
						colExists = true;
					}
					//If no match, add column
					if ( NOT colExists ) {
						try {
							sArgs = StructNew();
							sArgs["tablename"] = mytable;
							sArgs["dbfields"] = fieldlist;
							StructAppend(sArgs,MyTables[mytable][i],"no");
							setColumn(argumentCollection=sArgs);
						} catch (DataMgr exception) {
							FailedSQL = ListAppend(FailedSQL,exception.Detail,";");
						}
					}
					if (
							StructKeyExists(MyTables[mytable][i],"OldField")
						AND	Len(MyTables[mytable][i]["OldField"])
						AND	NOT StructKeyExists(MyTables[mytable][i],"CF_DataType")
					) {
						updateFromOldField(tablename=mytable,NewField=MyTables[mytable][i].ColumnName,OldField=MyTables[mytable][i].OldField,dbfields=fieldlist);
					}
				}
			}
		}
		if ( ArrayLen(aJoinRelations) ) {
			sJoinTables = StructNew();
			for ( i=1; i LTE ArrayLen(aJoinRelations); i=i+1 ) {
				if ( StructKeyExists(aJoinRelations[i].sField.Relation,"join_table") ) {
					mytable = aJoinRelations[i].sField.Relation["join_table"];
				} else {
					mytable = aJoinRelations[i].sField.Relation["join-table"];
				}
				if (
					NOT (
								StructKeyExists(sJoinTables,mytable)
							OR	ListFindNoCase(tables_made,mytable)
							OR	ListFindNoCase(dbtables,mytable)
						)
				) {
					sRelation = expandRelationStruct(aJoinRelations[i].sField.Relation,aJoinRelations[i].sField);
					if (
							Len(Trim(sRelation["local-table-join-field"]))
						AND	Len(Trim(sRelation["remote-table-join-field"]))
						AND	Len(Trim(sRelation["join-table-field-local"]))
						AND	Len(Trim(sRelation["join-table-field-remote"]))
					) {
							sJoinTables[mytable] = ArrayNew(1);
							sJoinTables[mytable][1] = StructNew();
							sJoinTables[mytable][2] = StructNew();

							sField = getField(aJoinRelations[i]["table"],sRelation["local-table-join-field"]);
							sJoinTables[mytable][1]["ColumnName"] = sRelation["join-table-field-local"];
							sJoinTables[mytable][1]["CF_DataType"] = sField["CF_DataType"];
							sJoinTables[mytable][1]["PrimaryKey"] = true;

							sField = getField(sRelation["table"],sRelation["remote-table-join-field"]);
							sJoinTables[mytable][2]["ColumnName"] = sRelation["join-table-field-remote"];
							sJoinTables[mytable][2]["CF_DataType"] = sField["CF_DataType"];
							sJoinTables[mytable][2]["PrimaryKey"] = true;

							sJoinTables[mytable][1] = adjustColumnArgs(sJoinTables[mytable][1]);
							sJoinTables[mytable][2] = adjustColumnArgs(sJoinTables[mytable][2]);

					}

				}
			}

			for (mytable in sJoinTables ) {
				addTable(mytable,sJoinTables[mytable]);
			}

			//Create tables if requested to do so.
			if ( arguments.docreate ) {
				//Try to create the tables, if that fails we'll load up the failed SQL in a variable so it can be returned in a handy lump.
				try {
					CreateTables(StructKeyList(sJoinTables),dbtables);
				} catch (DataMgr exception) {
					if ( Len(exception.Detail) ) {
						FailedSQL = ListAppend(FailedSQL,exception.Detail,";");
					} else {
						FailedSQL = ListAppend(FailedSQL,exception.Message,";");
					}
					if ( Len(exception.extendedinfo) ) {
						DBErrs = ListAppend(DBErrs,exception.Message,";");
					}
				}

			}// if
		}

		if ( Len(FailedSQL) ) {
			throwDMError("LoadXML Failed","LoadFailed",FailedSQL);
		}

		if ( arguments.docreate ) {
			seedData(varXML,tables_made);
			seedConstraints(varXML);
			seedIndexes(varXML);
		}
	}

	setCacheDate();

	return This;
}

public numeric function numRecords(
	required string tablename,
	struct data={}
) {
	var qRecords = getRecords(tablename=arguments.tablename,data=arguments.data,function="count",FunctionAlias="NumRecords");

	return Val(qRecords.NumRecords);
}

public struct function queryparam(
	string cfsqltype,
	value,
	string maxLength,
	string scale=0,
	boolean null=false,
	boolean list=false,
	string separator=","
) {
	if ( NOT StructKeyExists(arguments,"cfsqltype") ) {
		if ( StructKeyExists(arguments,"CF_DataType") ) {
			arguments["cfsqltype"] = arguments["CF_DataType"];
		} else if ( StructKeyExists(arguments,"Relation") ) {
			if ( StructKeyExists(arguments.Relation,"CF_DataType") ) {
				arguments["cfsqltype"] = arguments.Relation["CF_DataType"];
			} else if ( StructKeyExists(arguments.Relation,"table") AND StructKeyExists(arguments.Relation,"field") ) {
				arguments["cfsqltype"] = getEffectiveDataType(argumentCollection=arguments);
			}
		}
	}

	if ( isStruct(arguments.value) AND StructKeyExists(arguments.value,"value") ) {
		arguments.value = arguments.value.value;
	}

	if ( NOT isSimpleValue(arguments.value) ) {
		throwDMError("arguments.value must be a simple value","ValueMustBeSimple");
	}

	if ( NOT StructKeyExists(arguments,"maxLength") ) {
		arguments.maxLength = Len(arguments.value);
	}

	if ( StructKeyExists(arguments,"maxLength") ) {
		arguments.maxlength = Int(Val(arguments.maxlength));
		if ( NOT arguments.maxlength GT 0 ) {
			arguments.maxlength = Len(arguments.value);
		}
		if ( NOT arguments.maxlength GT 0 ) {
			arguments.maxlength = 100;
			arguments.null = "yes";
			arguments.null = "no";
		}
	}

	if ( StructKeyExists(Arguments,"cfsqltype") ) {
		switch (Arguments.cfsqltype) {
			case "CF_SQL_BLOB":
					Arguments.value = BinaryDecode(Arguments.value,"Hex");
				break;
			case "CF_SQL_BIT":
					Arguments.value = getBooleanSQLValue(Arguments.value);
				break;
		}
	}

	if ( NOT StructKeyExists(arguments,"null") ) {
		arguments.null = "no";
	}

	arguments.scale = Max(int(val(arguments.scale)),2);

	return StructFromArgs(arguments);
}

/**
* I remove a column from a table.
*/
public function removeColumn(
	required string tablename,
	required string field
) {
	var ii = 0;

	if ( ListFindNoCase(getDBFieldList(arguments.tablename),arguments.field) ) {
		runSQL("ALTER TABLE #escape(arguments.tablename)# DROP COLUMN #escape(arguments.field)#");
	}

	// Reset table properties
	resetTableProps(arguments.tablename);

	// Remove field from internal definition of table
	if ( StructKeyExists(variables.tables,arguments.tablename) ) {
		for ( ii=1; ii LTE ArrayLen(variables.tables[arguments.tablename]); ii++ ) {
			if (
				StructKeyExists(variables.tables[arguments.tablename][ii],"ColumnName")
				AND
				variables.tables[arguments.tablename][ii]["ColumnName"] EQ arguments.field
			) {
				ArrayDeleteAt(variables.tables[arguments.tablename],ii);
			}
		}
	}
}

/**
* I remove a record from a table.
*/
public function removeRecord(required string tablename) {
	runSQL("DROP TABLE #escape(arguments.tablename)#");

	// Remove table properties
	StructDelete(variables.tableprops,arguments.tablename);
	// Remote internal table representation
	StructDelete(variables.tables,arguments.tablename);
}

public struct function getQueryAttributes() {
	var sQuery = {name="qQuery",datasource="#variables.datasource#"};

	if ( StructKeyExists(variables,"username") AND StructKeyExists(variables,"password") ) {
		sQuery["username"] = variables.username;
		sQuery["password"] = variables.password;
	}
	if ( variables.SmartCache ) {
		sQuery["cachedafter"] = "#variables.CacheDate#";
	}

	if ( StructKeyExists(Arguments,"atts") ) {
		StructAppend(sQuery,Arguments.atts,"no");
	}
	StructAppend(sQuery,Arguments,"no");

	return sQuery;
}

/**
* I run the given SQL.
* @sql The SQL to run.
* @atts Attributes for cfquery.
*/
public function runSQL(
	required string sql,
	struct atts
) {
	var loc = {};

	if ( Len(arguments.sql) ) {
		loc.qQuery = QueryExecute(Trim(DMPreserveSingleQuotes(arguments.sql)), [], getQueryAttributes(argumentCollection=arguments));
		logSQL(arguments.sql);
	}

	if ( StructKeyExists(loc,"qQuery") AND isQuery(loc.qQuery) ) {
		return loc.qQuery;
	}
}
</cfscript>

<cffunction name="runSQLArray" access="public" returntype="any" output="no" hint="I run the given array representing SQL code (structures in the array represent params).">
	<cfargument name="sqlarray" type="array" required="yes">
	<cfargument name="atts" type="struct" required="no" hint="Attributes for cfquery.">

	<cfset var qQuery = 0>
	<cfset var ii = 0>
	<cfset var temp = "">
	<cfset var aSQL = cleanSQLArray(arguments.sqlarray)>
	<cfset var sAttributes = getQueryAttributes(ArgumentCollection=Arguments)>

	<cftry>
		<cfif ArrayLen(aSQL)>
			<cfquery AttributeCollection="#sAttributes#"><cfloop index="ii" from="1" to="#ArrayLen(aSQL)#" step="1"><cfif IsSimpleValue(aSQL[ii])><cfset temp = aSQL[ii]>#Trim(DMPreserveSingleQuotes(temp))#<cfelseif IsStruct(aSQL[ii])><cfset aSQL[ii] = queryparam(argumentCollection=aSQL[ii])><cfif StructKeyExists(aSQL[ii],"cfsqltype")><cfswitch expression="#aSQL[ii].cfsqltype#"><cfcase value="CF_SQL_BIT">#getBooleanSqlValue(aSQL[ii].value)#</cfcase><cfcase value="CF_SQL_DATE,CF_SQL_DATETIME">#CreateODBCDateTime(aSQL[ii].value)#</cfcase><cfdefaultcase><!--- <cfif ListFindNoCase(variables.dectypes,aSQL[ii].cfsqltype)>#Val(aSQL[ii].value)#<cfelse> ---><cfqueryparam value="#sqlvalue(aSQL[ii].value,aSQL[ii].cfsqltype)#" cfsqltype="#aSQL[ii].cfsqltype#" maxlength="#aSQL[ii].maxlength#" scale="#aSQL[ii].scale#" null="#aSQL[ii].null#" list="#aSQL[ii].list#" separator="#aSQL[ii].separator#"><!--- </cfif> ---></cfdefaultcase></cfswitch></cfif></cfif> </cfloop></cfquery>
		</cfif>

		<cfset logSQL(aSQL)>
	<cfcatch>
		<cfthrow message="#CFCATCH.Message#" detail="#CFCATCH.detail#" extendedinfo="#readableSQL(aSQL)#">
	</cfcatch>
	</cftry>

	<cfif IsDefined("qQuery") AND isQuery(qQuery)>
		<cfreturn qQuery>
	</cfif>

</cffunction>

<cffunction name="getConstraintConflicts_Field" access="private" returntype="query" output="no">
	<cfargument name="tablename" type="string" required="true">
	<cfargument name="ftable" type="string" required="true">
	<cfargument name="field" type="string" required="false">

	<cfset var qConflicts = QueryNew("pkvalue")>
	<cfset var pkfield = getPrimaryKeyFieldName(Arguments.tablename)>
	<cfset var fpkfield = getPrimaryKeyFieldName(Arguments.ftable)>

	<cfif NOT StructKeyExists(Arguments, "field")>
		<cfset Arguments.field = fpkfield>
	</cfif>

	<cfif ListLen(fpkfield) EQ 1>
		<cf_DMQuery name="qConflicts">
		SELECT	<cf_DMObject name="#pkfield#"> AS pkvalue,
				<cf_DMObject name="#Arguments.field#"> AS fkvalue
		FROM	<cf_DMObject name="#Arguments.tablename#">
		WHERE	NOT <cf_DMObject name="#Arguments.field#"> IN (
					SELECT	<cf_DMObject name="#fpkfield#">
					FROM	<cf_DMObject name="#Arguments.ftable#">
				)
		</cf_DMQuery>
	</cfif>

	<cfreturn qConflicts>
</cffunction>

<cfscript>
private function getConstraintConflicts_Table(required string tablename) {
	var varXML = getXml(Arguments.tablename);
	var xTable = Xmlparse(varXML);
	var aForeignFields = XmlSearch(xTable, "//field[@ftable][@ColumnName]");//Get all real fields that reference other tables
	var ii = 0;
	var xField = 0;
	var sField = 0;
	var xParent = 0;
	var useConstraint = "";
	var sResult = {};

	for ( ii = 1; ii LTE ArrayLen(aForeignFields); ii=ii+1 ) {
		xField = aForeignFields[ii];
		sField = xField.XmlAttributes;
		useConstraint = true;
		xParent = xField.XmlParent;//Because we might have traversed up while determining if we should use a constraint.

		//For now, don't handle join-tables. Will need to though, at some point.
		if ( StructKeyHasLen(sField,"jointable") ) {
			useConstraint = false;
		}

		if ( sField["ftable"] EQ Arguments.tablename ) {
			useConstraint = false;
		}

		//If we are using a constraint, make sure it exists.
		if ( useConstraint IS true ) {
			sResult[sField["ColumnName"]] = getConstraintConflicts_Field(Arguments.tablename,sField["ftable"],sField["ColumnName"]);
		}
	}
	

	return sResult;
}

private void function logSQL(required sql) {
	var text = "";

	if ( StructKeyExists(Variables,"logfile") AND Len(Variables.logfile) ) {
		if ( isSimpleValue(Arguments.sql) AND Len(Arguments.sql) ) {
			text = Arguments.sql;
		} else if ( isArray(Arguments.sql) AND ArrayLen(Arguments.sql) ) {
			text = readableSQL(Arguments.sql);
		}

		if ( Len(text) ) {
			writeLog(file="#Variables.logfile#",text="#text#");
		}
	}

}

/**
* I return human-readable SQL from a SQL array (not to be sent to the database).
* @sqlarray The SQL array to convert.
* @runnable Indicates whether the resulting SQL should be runnable( buit unprotected).
*/

public string function readableSQL(
	required array sqlarray,
	boolean runnable=false
) {
	var aSQL = cleanSQLArray(arguments.sqlarray);
	var ii = 0;
	var result = "";
	var marker = "";

	for ( ii=1; ii LTE ArrayLen(aSQL); ii++ ) {
		if ( isSimpleValue(aSQL[ii]) ) {
			result = result & " " & aSQL[ii];
		} else if ( isStruct(aSQL[ii]) ) {
			//Try to include parameter inline as runnable SQL.
			if ( Arguments.runnable ) {
				marker = "'";
				if (
					StructKeyExists(aSQL[ii],"cfsqltype")
					AND
					(
						aSQL[ii]["cfsqltype"] CONTAINS "int"
						OR
						aSQL[ii]["cfsqltype"] CONTAINS "bit"
						OR
						aSQL[ii]["cfsqltype"] CONTAINS "decimal"
					)
				) {
					marker = "";
				}
				result = result & " " & marker & aSQL[ii].value & marker;
			} else {
				result = result & " " & "(#aSQL[ii].value#)";
			}
		}
	}

	return result;
}

/**
* I set a column in the given table
* @tablename The name of the table to which a column will be added.
* @columnname The name of the column to add.
* @CF_Datatype The ColdFusion SQL Datatype of the column.
* @Length The ColdFusion SQL Datatype of the column.
* @Default The default value for the column.
* @Special The special behavior for the column.
* @Relation Relationship information for this column.
* @PrimaryKey Indicates whether this column is a primary key.
*/
public function setColumn(
	required string tablename,
	required string columnname,
	string CF_Datatype,
	numeric Length=0,
	string Default,
	string Special,
	struct Relation,
	boolean PrimaryKey,
	boolean AllowNulls=true,
	boolean useInMultiRecordsets=true
) {
	var type = "";
	var sql = "";
	var FailedSQL = "";
	var FieldIndex = 0;
	var aTable = 0;

	var sArgs = convertColumnAtts(argumentCollection=arguments);

	if ( NOT (StructKeyExists(arguments, "dbfields") AND Len(arguments.dbfields)) ) {
		arguments.dbfields = getDBFieldList(sArgs.tablename);
	}

	if ( StructKeyExists(sArgs, "CF_Datatype") ) {
		if ( NOT ListFindNoCase(arguments.dbfields, sArgs.columnname) ) {
			sql = "ALTER TABLE " & escape(Variables.prefix & sArgs.tablename) & " ADD " & sqlCreateColumn(sArgs);
			try {
				runSQL(sql);
			} catch (any e) {
				FailedSQL = ListAppend(FailedSQL, sql, ";");
			}
			if ( Len(FailedSQL) ) {
				throwDMError(message="Failed to add Column (""#arguments.columnname#"").", detail=FailedSQL);
			}
			if ( StructKeyExists(sArgs, "OldField") AND Len(Trim(sArgs.OldField)) ) {
				updateFromOldField(tablename=sArgs.tablename, NewField=sArgs.columnname, OldField=sArgs.OldField, dbfields=ListAppend(arguments.dbfields, sArgs.columnname));
			}
			if ( StructKeyExists(sArgs, "Default") AND Len(Trim(sArgs.Default)) ) {
				sql = '
					UPDATE	#escape(Variables.prefix & sArgs.tablename)#
					SET		#escape(sArgs.columnname)# = #sArgs.Default#
					WHERE	#escape(sArgs.columnname)# IS NULL
				';
				try {
					runSQL(sql);
				} catch ( any e ) {
					FailedSQL = ListAppend(FailedSQL, sql, ";");
				}
			}
		}
	} else {
		if ( StructKeyExists(sArgs, "OldField") AND Len(Trim(sArgs.OldField)) ) {
			updateFromOldField(tablename=sArgs.tablename, NewField=sArgs.columnname, OldField=sArgs.OldField, dbfields=arguments.dbfields);
		}
	}

	FieldIndex = getColumnIndex(arguments.tablename, arguments.columnname);

	if ( NOT Len(FailedSQL) ) {
		if ( NOT FieldIndex ) {
			ArrayAppend(variables.tables[arguments.tablename], sArgs);
			FieldIndex = ArrayLen(variables.tables[arguments.tablename]);
		}
		aTable = variables.tables[arguments.tablename];

		if ( StructKeyExists(sArgs, "Special") AND Len(sArgs.Special) ) {
			aTable[FieldIndex]["Special"] = sArgs.Special;
		}
		if ( StructKeyExists(sArgs, "Relation") ) {
			if (
				StructKeyExists(sArgs["Relation"], "type")
				AND
				sArgs["Relation"].type EQ "list"
				AND
				StructKeyExists(sArgs, "OtherField")
				AND
				NOT StructKeyExists(sArgs["Relation"], "other-field")
			) {
				sArgs["Relation"]["other-field"] = sArgs["OtherField"];
			}
			aTable[FieldIndex]["Relation"] = sArgs.Relation;
		}
		if ( StructKeyExists(sArgs, "PrimaryKey") AND isBoolean(sArgs.PrimaryKey) AND sArgs.PrimaryKey ) {
			aTable[FieldIndex]["PrimaryKey"] = true;
		}
		if ( StructKeyExists(sArgs, "useInMultiRecordsets") AND isBoolean(sArgs.useInMultiRecordsets) ) {
			aTable[FieldIndex]["useInMultiRecordsets"] = sArgs.useInMultiRecordsets;
		}
	}

	announceEvent(
		tablename=Arguments.tablename,
		action="setColumn",
		method="setColumn",
		data={},
		fieldlist=Arguments.columnname,
		Args=Arguments
	);

	resetTableProps(arguments.tablename);
}
/**
* I insert or update a record in the given table (update if a matching record is found) with the provided data and return the primary key of the updated record.
* @param tablename The table on which to update data.
* @param data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @param fieldlist A list of insertable fields. If left blank, any field can be inserted.
* @param truncate Should the field values be automatically truncated to fit in the available space for each field?
* @param checkfields Only for OnExists=update. A list of fields to use to check for existing records (default to checking all updateable fields for update).
* @return The primary key of the updated record.
*/
public string function saveRecord(
	required string tablename,
	required struct data,
	string fieldlist="",
	boolean truncate=false,
	string checkfields=""
) {
	var result = insertRecord(
		tablename = arguments.tablename,
		data = arguments.data,
		OnExists = "update",
		fieldlist = arguments.fieldlist,
		truncate = arguments.truncate,
		checkfields = arguments.checkfields
	);

	return result;
}
/**
 * I save a many-to-many relationship.
 * 
 * @param tablename The table holding the many-to-many relationships.
 * @param keyfield The field holding our key value for relationships.
 * @param keyvalue The value of our primary field.
 * @param multifield The field holding our many relationships for the given key.
 * @param multilist The list of related values for our key.
 * @param reverse Should the reverse of the relationship be run as well (for self-joins)?
 */
public void function saveRelationList(
	required string tablename,
	required string keyfield,
	required string keyvalue,
	required string multifield,
	required string multilist,
	boolean reverse=false
) {
	var bTable = checkTable(arguments.tablename);// Check whether table is loaded
	var getStruct = StructNew();
	var setStruct = StructNew();
	var qExistingRecords = 0;
	var sExistingRecord = 0;
	var item = "";
	var ExistingList = "";

	// Make sure a value is passed in for the primary key value
	if ( NOT Len(Trim(arguments.keyvalue)) ) {
		throwDMError("You must pass in a value for keyvalue of saveRelationList","NoKeyValueForSaveRelationList");
	}

	if ( arguments.reverse ) {
		saveRelationList(
			tablename=arguments.tablename,
			keyfield=arguments.multifield,
			keyvalue=arguments.keyvalue,
			multifield=arguments.keyfield,
			multilist=arguments.multilist
		);
	}

	// Get existing records
	getStruct[arguments.keyfield] = arguments.keyvalue;
	qExistingRecords = getRecords(arguments.tablename,getStruct);

	// Remove existing records not in list
	for ( sExistingRecord in qExistingRecords ) {
		ExistingList = ListAppend(ExistingList,sExistingRecord[arguments.multifield]);
		if ( NOT ListFindNoCase(arguments.multilist,sExistingRecord[arguments.multifield]) ) {
			setStruct = StructNew();
			setStruct[arguments.keyfield] = arguments.keyvalue;
			setStruct[arguments.multifield] = sExistingRecord[arguments.multifield];
			deleteRecords(arguments.tablename,setStruct);
		}
	}

	// Add records from list that don't exist
	for ( item in ArrayToList(arguments.multilist) ) {
		if ( isOfCFType(item,getEffectiveDataType(arguments.tablename,arguments.multifield)) AND NOT ListFindNoCase(ExistingList,item) ) {
			setStruct = StructNew();
			setStruct[arguments.keyfield] = arguments.keyvalue;
			setStruct[arguments.multifield] = Trim(item);
			insertRecord(arguments.tablename,setStruct,"skip");
			ExistingList = ListAppend(ExistingList,item);// in case list has one item more than once (4/26/06)
		}
	}

	setCacheDate();

}
/**
 * I save the sort order of records - putting them in the same order as the list of primary key values.
 * @param tablename The table on which to update data.
 * @param sortfield The field holding the sort order.
 * @param sortlist The list of primary key field values in sort order.
 * @param PrecedingRecords The number of records preceding those being sorted.
 */
public void function saveSortOrder(
	required string tablename,
	required string sortfield,
	required string sortlist,
	numeric PrecedingRecords=0
) {
	var pkfields = getPKFields(arguments.tablename);
	var ii = 0;
	var keyval = 0;
	var sqlarray = ArrayNew(1);
	var sqlStatements = "";

	arguments.PrecedingRecords = Int(arguments.PrecedingRecords);
	if ( arguments.PrecedingRecords LT 0 ) {
		arguments.PrecedingRecords = 0;
	}

	if ( ArrayLen(pkfields) NEQ 1 ) {
		throwDMError("This method can only be used on tables with exactly one primary key field.","SortWithOneKey");
	}

	for ( ii=1; ii LTE ListLen(arguments.sortlist); ii++ ) {
		keyval = ListGetAt(arguments.sortlist,ii);
		sqlarray = ArrayNew(1);
		ArrayAppend(sqlarray,"UPDATE	#escape(Variables.prefix & arguments.tablename)#");
		ArrayAppend(sqlarray,"SET		#escape(arguments.sortfield)# = #Val(ii)+arguments.PrecedingRecords#");
		ArrayAppend(sqlarray,"WHERE	#escape(pkfields[1].ColumnName)# = ");
		ArrayAppend(sqlarray,sval(pkfields[1],keyval));
		runSQLArray(sqlarray);
		sqlStatements = ListAppend(sqlStatements,readableSQL(sqlarray),";");
	}

	if ( variables.doLogging AND ListLen(arguments.sortlist) ) {
		logAction(
			tablename=arguments.tablename,
			action="sort",
			data=arguments,
			sql=sqlStatements
		);
	}

	setCacheDate();

}

public function sqlvalue(
	required string value,
	string cfdatatype
) {
	var result = arguments.value;
	var strval = "";

	// Some automatic conversion code for GUIDs, thanks to Chuck Brockman
	if ( StructKeyExists(Arguments,"cfdatatype") AND Arguments.cfdatatype EQ "CF_SQL_IDSTAMP" ) {
		result = "";
		for ( strval in ListToArray(Arguments.value) ) {
			if ( Len(strval) GTE 23 ) {
				if ( isValid('guid', strval) ) {
					result = ListAppend(result,strval);
				} else {
					result = ListAppend(result,insert("-", strval, 23));
				}
			}
		}
	}

	return result;
}

/**
* I log an action in the database.
*/
public function logAction(
	required string tablename,
	string pkval,
	required string action,
	struct data,
	any sql
) {
	if ( NOT arguments.tablename EQ variables.logtable ) {
		if ( StructKeyExists(arguments,"data") ) {
			arguments.data = serializeJSON(arguments.data);
		}

		if ( StructKeyExists(arguments,"sql") ) {
			if ( isSimpleValue(arguments.sql) ) {
				arguments.sql = arguments.sql;
			} else if ( isArray(arguments.sql) ) {
				arguments.sql = readableSQL(arguments.sql);
			} else {
				throwDMError("The sql argument logAction method must be a string of SQL code or a DataMgr SQL Array.","LogActionSQLDataType");
			}
		}

		insertRecord(variables.logtable, arguments);
	}
}

public void function setNamedFilter(
	required string tablename,
	required string name,
	required string field,
	required string operator
) {

	variables.tableprops[arguments.tablename]["filters"][arguments.name] = StructNew();
	variables.tableprops[arguments.tablename]["filters"][arguments.name]["field"] = arguments.field;
	variables.tableprops[arguments.tablename]["filters"][arguments.name]["operator"] = arguments.operator;

}

/**
* I turn on logging.
*/
public void function startLogging(string logtable=variables.logtable) {
	var dbxml = "";

	variables.doLogging = true;
	variables.logtable = arguments.logtable;

	dbxml = '
		<table name="#variables.logtable#">
			<field ColumnName="LogID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="tablename" CF_DataType="CF_SQL_VARCHAR" Length="180" />
			<field ColumnName="pkval" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="action" CF_DataType="CF_SQL_VARCHAR" Length="60" />
			<field ColumnName="DatePerformed" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
			<field ColumnName="data" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="sql" CF_DataType="CF_SQL_LONGVARCHAR" />
		</table>
	';
	
	loadXML(dbxml,true,true);

}

/**
* I turn off logging.
*/
public void function stopLogging() {
	variables.doLogging = false;
}

/**
* I return the structure with the values truncated to the limit of the fields in the table.
* @tablename The table for which to truncate data.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
*/
public struct function truncate(
	required string tablename,
	required struct data
) {
	var bTable = checkTable(arguments.tablename);//Check whether table is loaded
	var sTables = getTableData();
	var aColumns = sTables[arguments.tablename];
	var ii = 0;

	for ( ii=1; ii LTE ArrayLen(aColumns); ii=ii+1 ) {
		if ( StructKeyExists(arguments.data,aColumns[ii].ColumnName) ) {
			if ( StructKeyExists(aColumns[ii],"Length") AND aColumns[ii].Length AND aColumns[ii].CF_DataType NEQ "CF_SQL_LONGVARCHAR" ) {
				arguments.data[aColumns[ii].ColumnName] = Left(arguments.data[aColumns[ii].ColumnName],aColumns[ii].Length);
			}
		}
	}

	return arguments.data;
}

/**
* I update a record in the given table with the provided data and return the primary key of the updated record.">
* @tablename The table on which to update data.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @advsql A structure of sqlarrays for each area of a query (SET,WHERE).
* @truncate Should the field values be automatically truncated to fit in the available space for each field?
* @fieldlist A list of updateable fields. If left blank, any field can be updated.
*/
public string function updateRecord(
	required string tablename,
	required struct data,
	struct advsql = {},
	boolean truncate = false,
	string fieldlist = ""
) {
	var bTable = checkTable(arguments.tablename);
	var ii = 0; // generic counter
	var pkfields = getPKFields(arguments.tablename);
	var sData = clean(arguments.data); // holds incoming data for ease of use
	var qGetUpdateRecord = 0; // used to check for existing record
	var temp = "";
	var result = 0;
	var sqlarray = [];
	var ChangeUUID = CreateUUID();
	var sGetArgs = {"tablename":arguments.tablename,"data":{},"fieldlist":arguments.fieldlist};
	var qBefore = 0;
	var qAfter = 0;

	if ( arguments.truncate ) {
		sData = variables.truncate(arguments.tablename, sData);
	}

	if ( NOT ArrayLen(pkfields) ) {
		throwDMError("#arguments.tablename# has no primary key fields. updateRecord and saveRecord can only be called on tables with primary key fields. Use updateRecords or insertRecord (without OnExists of 'update' or 'save') instead.", "NoPkFields");
	}

	// Check for existing record
	sqlarray = [];
	sqlarray.append("SELECT " & escape(pkfields[1].ColumnName));
	sqlarray.append("FROM " & escape(arguments.tablename));
	sqlarray.append("WHERE 1 = 1");
	for ( ii = 1; ii <= ArrayLen(pkfields); ii++ ) {
		sqlarray.append("AND " & escape(pkfields[ii].ColumnName) & " = ");
		sqlarray.append(sval(pkfields[ii], sData));
		sGetArgs["data"][pkfields[ii].ColumnName] = sData[pkfields[ii].ColumnName];
	}
	qGetUpdateRecord = runSQLArray(sqlarray);

	// Make sure record exists to update
	if ( NOT qGetUpdateRecord.RecordCount ) {
		temp = "";
		for (ii = 1; ii <= ArrayLen(pkfields); ii++) {
			temp = ListAppend(temp, escape(pkfields[ii].ColumnName) & "=" & sData[pkfields[ii].ColumnName]);
		}
		throwDMError("No record exists for update criteria (#temp#).", "NoUpdateRecord");
	}

	if ( NOT Len(Trim(sGetArgs.fieldlist)) ) {
		sGetArgs["fieldlist"] = StructKeyList(arguments.data);
	}

	qBefore = getRecord(argumentCollection=sGetArgs);

	sqlarray = updateRecordSQL(argumentCollection=arguments);

	announceEvent(tablename=arguments.tablename, action="beforeUpdate", method="updateRecord", data=sData, fieldlist=arguments.fieldlist, Args=arguments, sql=sqlarray, ChangeUUID=ChangeUUID);

	if ( ArrayLen(sqlarray) ) {
		runSQLArray(sqlarray);
	}

	result = qGetUpdateRecord[pkfields[1].ColumnName][1];

	// set pkfield so that we can save relation data
	sData[pkfields[1].ColumnName] = result;

	// Save any relations
	saveRelations(arguments.tablename, sData, pkfields[1], result);

	qAfter = getRecord(argumentCollection = sGetArgs);

	// Log update
	if ( variables.doLogging AND arguments.tablename NEQ variables.logtable ) {
		logAction(
			tablename=arguments.tablename,
			pkval=result,
			action="update",
			data=sData,
			sql=sqlarray
		);
	}

	announceEvent(tablename=arguments.tablename,action="afterUpdate",method="updateRecord",data=sData,fieldlist=arguments.fieldlist,Args=arguments,pkvalue=result,sql=sqlarray,ChangeUUID=ChangeUUID,before=qBefore,after=qAfter);

	setCacheDate();

	return result;
}

/**
* I update a record in the given table with the provided data and return the primary key of the updated record.
* @tablename The table on which to update data.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @fieldlist A list of updateable fields. If left blank, any field can be updated.
* @advsql A structure of sqlarrays for each area of a query (SET,WHERE).
*/
public array function updateRecordSQL(
	required string tablename,
	required struct data,
	string fieldlist="",
	struct advsql={}
) {
	var bTable = checkTable(arguments.tablename);
	var fields = getUpdateableFields(arguments.tablename);
	var ii = 0; // generic counter
	var pkfields = getPKFields(arguments.tablename);
	var sData = clean(arguments.data); // holds incoming data for ease of use
	var data_set = {};
	var data_where = {};

	sData = getRelationValues(arguments.tablename, sData);

	// This method requires at least one primary key
	if ( NOT ArrayLen(pkfields) ) {
		throwDMError("This method can only be used on tables with at least one primary key field.", "NeedPKField");
	}

	// All primary key values must be provided
	for ( ii = 1; ii <= ArrayLen(pkfields); ii++ ) {
		if ( NOT StructKeyExists(sData, pkfields[ii].ColumnName) ) {
			throwDMError("All Primary Key fields must be used when updating a record.", "RequiresAllPkFields");
		}
		data_where[pkfields[ii].ColumnName] = sData[pkfields[ii].ColumnName];
	}

	for ( ii = 1; ii <= ArrayLen(fields); ii++ ) {
		if ( StructKeyExists(sData, fields[ii].ColumnName) ) {
			data_set[fields[ii].ColumnName] = sData[fields[ii].ColumnName];
		}
	}

	return updateRecordsSQL(
		tablename = arguments.tablename,
		data_set = data_set,
		data_where = data_where,
		fieldlist = arguments.fieldlist,
		advsql = arguments.advsql
	);
}

/*
* @tablename The table on which to update data.
* @data_set A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @data_where A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @filters An array of filters to apply to the query.
* @fieldlist A list of updateable fields. If left blank, any field can be updated.
* @advsql A structure of sqlarrays for each area of a query (SET,WHERE).
*/
public void function updateRecords(
	required string tablename,
	required struct data_set,
	struct data_where={},
	array filters=[],
	string fieldlist="",
	struct advsql={}
) {
	var sqlarray = updateRecordsSQL(argumentCollection=arguments);
	var qRecords = 0;
	var sAdvSQL = {};
	var pklist = getPrimaryKeyFieldNames(arguments.tablename);
	var pkfields = getPKFields(arguments.tablename); // the primary key fields for this table

	if ( ArrayLen(sqlarray) ) {
		runSQLArray(sqlarray);
	}

	// Save any relations
	if ( ListLen(pklist) EQ 1 ) {
		if ( StructKeyExists(arguments.advsql, "WHERE") ) {
			sAdvSQL["WHERE"] = arguments.advsql["WHERE"];
		}

		qRecords = getRecords(
			tablename = arguments.tablename,
			data = data_where,
			fieldlist = pklist,
			advsql = sAdvSQL,
			filters = arguments.filters
		);

		for ( var i = 1; i <= qRecords.RecordCount; i++ ) {
			saveRelations(
				tablename = arguments.tablename,
				data = data_set,
				pkfield = pkfields[1],
				pkval = qRecords[pklist][i]
			);
		}
	}

	setCacheDate();
}

/**
* @tablename The table on which to update data.
* @data_set A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @data_where A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @filters An array of filters to apply to the query.
* @fieldlist A list of updateable fields. If left blank, any field can be updated.
* @advsql A structure of sqlarrays for each area of a query (SET,WHERE).
*/
public array function updateRecordsSQL(
	required string tablename,
	struct data_set={},
	struct data_where,
	array filters=[],
	string fieldlist="",
	struct advsql={}
) {
	var bTable = checkTable(arguments.tablename);
	var fields = getUpdateableFields(arguments.tablename);
	var ii = 0;// generic counter
	var fieldcount = 0;// number of fields
	var sData = clean(arguments.data_set);// holds incoming data for ease of use
	var sqlarray = [];
	var Specials = "LastUpdatedDate";
	var usedfields = "";
	var colnum = 0;

	if ( NOT StructKeyExists(arguments,"data_where") ) {
		arguments.data_where = {};
	}

	// Restrict data to fieldlist
	if ( Len(Trim(arguments.fieldlist)) ) {
		for ( ii in sData )
			if ( NOT ListFindNoCase(arguments.fieldlist,ii) ) {
				StructDelete(sData,ii);
			}
	}

	sData = getRelationValues(arguments.tablename,sData);

	// Restrict data to fieldlist
	if ( Len(Trim(arguments.fieldlist)) ) {
		for ( ii in sData ) {
			if ( NOT ListFindNoCase(arguments.fieldlist,ii) ) {
				StructDelete(sData,ii);
			}
		}
	}

	// Throw exception on any attempt to update a table with no updateable fields
	if ( NOT ArrayLen(fields) ) {
		throwDMError("This table does not have any updateable fields.","NoUpdateableFields");
	}

	ArrayAppend(sqlarray,"UPDATE	#escape(Variables.prefix & arguments.tablename)#");
	ArrayAppend(sqlarray,"SET");
	for ( ii=1; ii LTE ArrayLen(fields); ii++ ) {
		if ( StructKeyExists(fields[ii],"ColumnName") AND NOT ListFindNoCase(usedfields,fields[ii]["ColumnName"]) ) {
			if ( useField(sData,fields[ii]) ) {// Include update if this is valid data
				checkLength(fields[ii],sData[fields[ii].ColumnName]);
				fieldcount = fieldcount + 1;
				usedfields = ListAppend(usedfields,fields[ii]["ColumnName"]);
				if ( fieldcount GT 1 ) {
					ArrayAppend(sqlarray,",");
				}
				ArrayAppend(sqlarray,"#escape(fields[ii].ColumnName)# = ");
				ArrayAppend(sqlarray,sval(fields[ii],sData));
			} else if ( isBlankValue(sData,fields[ii]) ) {// Or if it is passed in as empty value and null are allowed
				fieldcount = fieldcount + 1;
				usedfields = ListAppend(usedfields,fields[ii]["ColumnName"]);
				if ( fieldcount GT 1 ) {
					ArrayAppend(sqlarray,",");
				}
				if ( StructKeyExists(fields[ii],"AllowNulls") AND isBoolean(fields[ii].AllowNulls) AND NOT fields[ii].AllowNulls ) {
					ArrayAppend(sqlarray,"#escape(fields[ii].ColumnName)# = ''");
				} else {
					ArrayAppend(sqlarray,"#escape(fields[ii].ColumnName)# = NULL");
				}
				} else if ( StructKeyExists(fields[ii],"Special") AND Len(fields[ii].Special) AND ListFindNoCase(Specials,fields[ii].Special) ) {
				if ( fields[ii]["Special"] EQ "LastUpdatedDate" ) {
					fieldcount = fieldcount + 1;
					usedfields = ListAppend(usedfields,fields[ii]["ColumnName"]);
					if ( fieldcount GT 1 ) {
						ArrayAppend(sqlarray,",");
					}
					ArrayAppend(sqlarray,"#escape(fields[ii].ColumnName)# = ");
					ArrayAppend(sqlarray,getFieldNowValue(arguments.tablename,fields[ii]));
				}
			}
		}
	}
	if ( StructKeyExists(arguments,"advsql") AND StructKeyExists(arguments.advsql,"SET") ) {
		if ( fieldcount ) {
			ArrayAppend(sqlarray,",");colnum = colnum + 1;
		}
		fieldcount = fieldcount + 1;
		ArrayAppend(sqlarray,arguments.advsql["SET"]);
	}
	ArrayAppend(sqlarray,"WHERE	1 = 1");
	ArrayAppend(sqlarray,getWhereSQL(tablename=arguments.tablename,data=arguments.data_where,filters=arguments.filters));
	if ( fieldcount ) {
		fieldcount = 0;
	} else {
		sqlarray = [];
	}

	return sqlarray;
}

/*
* I add a column to the given table (deprecated in favor of setColumn).
* @tablename The name of the table to which a column will be added.
* @columnname The name of the column to add.
* @CF_Datatype The ColdFusion SQL Datatype of the column.
* @Length The ColdFusion SQL Datatype of the column.
* @Default The default value for the column.
*/
public function addColumn(
	required string tablename,
	required string columnname,
	string CF_Datatype,
	numeric Length=50,
	string Default
) {

	setColumn(argumentCollection=arguments);

}

/**
* I add a table to the Data Manager.
*/
private boolean function addTable(
	required string tablename,
	required array fielddata,
	struct filters,
	struct props
) {
	var isTableAdded = false;
	var ii = 0;
	var jj = 0;
	var hasField = false;

	if ( StructKeyExists(variables.tables,arguments.tablename) ) {
		// If the table exists, add new columns
		for ( ii=1; ii LTE ArrayLen(arguments.fielddata); ii++ ) {
			hasField = false;
			for ( jj=1; jj LTE ArrayLen(variables.tables[arguments.tablename]); jj++ ) {
				if ( arguments.fielddata[ii]["ColumnName"] EQ variables.tables[arguments.tablename][jj]["ColumnName"] ) {
					hasField = true;
					variables.tables[arguments.tablename][jj] = arguments.fielddata[ii];
				}
			}
			if ( NOT hasField ) {
				ArrayAppend(variables.tables[arguments.tablename],arguments.fielddata[ii]);
			}
		}
	} else {
		// If the table doesn't exist, just add it as given
		variables.tables[arguments.tablename] = arguments.fielddata;
	}

	resetTableProps(arguments.tablename);

	if ( StructKeyExists(arguments,"filters") AND StructCount(arguments.filters) ) {
		StructAppend(variables.tableprops[arguments.tablename]["filters"],arguments.filters,true);
	}

	if ( StructKeyExists(arguments,"props") AND StructCount(arguments.props) ) {
		setTableProps(arguments.tablename,arguments.props);
	}

	isTableAdded = true;

	announceEvent(
		tablename=Arguments.tablename,
		action="addTable",
		method="addTable",
		data={},
		Args=Arguments
	);

	setCacheDate();

	return isTableAdded;
}

private function adjustColumnArgs(required struct args) {
	var sArgs = StructCopy(arguments.args);

	// Require ColumnName
	if ( NOT (StructKeyExists(sArgs, "ColumnName") AND Len(Trim(sArgs.ColumnName))) ) {
		throwDMError("ColumnName is required");
	}
	// Require CF_Datatype
	if ( NOT (StructKeyExists(sArgs, "CF_Datatype") AND Len(Trim(sArgs.CF_Datatype)) GT 7 AND Left(sArgs.CF_Datatype, 7) EQ "CF_SQL_") ) {
		throwDMError("CF_Datatype is required");
	}
	if ( NOT (StructKeyExists(sArgs, "Length") AND isNumeric(sArgs.Length) AND Int(sArgs.Length) GT 0) ) {
		sArgs.Length = 255;
	}
	if ( NOT isStringType(getDBDataType(sArgs.CF_DataType)) ) {
		StructDelete(sArgs, "Length");
	}
	if ( NOT (StructKeyExists(sArgs, "PrimaryKey") AND isBoolean(sArgs.PrimaryKey)) ) {
		sArgs.PrimaryKey = false;
	}
	if ( NOT (StructKeyExists(sArgs, "Increment") AND isBoolean(sArgs.Increment)) ) {
		sArgs.Increment = false;
	}
	if ( NOT StructKeyExists(sArgs, "Default") ) {
		sArgs.Default = "";
	}
	if ( NOT StructKeyExists(sArgs, "Special") ) {
		sArgs.Special = "";
	}
	if ( NOT StructKeyExists(sArgs, "useInMultiRecordsets") ) {
		sArgs.useInMultiRecordsets = true;
	}
	if ( NOT (StructKeyExists(sArgs, "AllowNulls") AND isBoolean(sArgs.AllowNulls)) ) {
		sArgs.AllowNulls = true;
	}
	if ( StructKeyExists(sArgs, "Length") ) {
		sArgs.Length = Int(sArgs.Length);
	}
	if ( StructKeyExists(sArgs, "precision") OR StructKeyExists(sArgs, "scale") ) {
		if ( NOT (StructKeyExists(sArgs, "precision") AND Val(sArgs.precision) NEQ 0) ) {
			sArgs.precision = 12;
		}
		if ( NOT (StructKeyExists(sArgs, "scale") AND Val(sArgs.scale) NEQ 0) ) {
			sArgs.scale = 2;
		}
	}

	return sArgs;
}

public query function applyConcatRelations(
	required string tablename,
	required query query
) {
	var qRecords = arguments.query;
	var rfields = getRelationFields(arguments.tablename); // relation fields in table
	var i = 0; // Generic counter
	var hasConcats = false;
	var qRelationList = 0;
	var temp = 0;

	// Check for list values in recordset
	for ( i = 1; i <= ArrayLen(rfields); i++ ) {
		if ( ListFindNoCase(qRecords.ColumnList, rfields[i].ColumnName) ) {
			if ( rfields[i].Relation.type EQ "concat" ) {
				hasConcats = true;
				break;
			}
		}
	}

	// Get list values
	if ( hasConcats ) {
		for ( var row = 1; row <= qRecords.RecordCount; row++ ) {
			for ( i = 1; i <= ArrayLen(rfields); i++ ) {
				if ( rfields[i].Relation["type"] EQ "concat" AND ListFindNoCase(qRecords.ColumnList, rfields[i].ColumnName) AND Len(rfields[i].relation.delimiter) ) {
					if ( ReFindNoCase("^(#rfields[i].relation.delimiter#\\s?)+$", qRecords[rfields[i].ColumnName][row]) ) {
						qRecords[rfields[i].ColumnName][row] = "";
					}
				}
			}
		}
	}

	return qRecords;
}

public query function applyListRelations(
	required string tablename,
	required query query
) {
	var qRecords = arguments.query;
	var rfields = getRelationFields(arguments.tablename);// relation fields in table
	var i = 0;// Generic counter
	var hasLists = false;
	var qRelationList = 0;
	var temp = 0;
	var sRecord = 0;
	var sRelation = 0;

	// Check for list values in recordset
	for ( i=1; i LTE ArrayLen(rfields); i++ ) {
		if ( ListFindNoCase(qRecords.ColumnList,rfields[i].ColumnName) ) {
			if ( rfields[i].Relation.type EQ "list" ) {
				hasLists = true;
			}
		}
	}

	// Get list values
	if ( hasLists ) {
		for ( sRecord in qRecords ) {
			for ( i=1; i LTE ArrayLen(rfields); i++ ) {
				if ( rfields[i].Relation["type"] EQ "list" AND StructKeyExists(sRecord,rfields[i].ColumnName) ) {
					fillOutJoinTableRelations(arguments.tablename);
					temp = {};
					temp.tablename = rfields[i].Relation["table"];
					temp.fieldlist = rfields[i].Relation["field"];
					if ( StructKeyExists(rfields[i].Relation,"distinct") AND rfields[i].Relation["distinct"] IS true ) {
						temp.distinct = true;
						temp["sortfield"] = rfields[i].Relation["field"];
					}
					temp.advsql = StructNew();
					if ( StructKeyExists(rfields[i].Relation,"sort-field") ) {
						temp["sortfield"] = rfields[i].Relation["sort-field"];
						if ( StructKeyExists(rfields[i].Relation,"sort-dir") ) {
							temp["sortdir"] = rfields[i].Relation["sort-dir"];
						}
					}

					temp.filters = [];
					if ( StructKeyExists(rfields[i].Relation,"filters") ) {
						temp.filters = rfields[i].Relation["filters"];
					}
					if ( StructKeyExists(rfields[i].Relation,"join-table") ) {
						temp.join = StructNew();
						temp.join["table"] = rfields[i].Relation["join-table"];
						temp.join["onleft"] = rfields[i].Relation["remote-table-join-field"];
						temp.join["onright"] = rfields[i].Relation["join-table-field-remote"];
						// Use filters for extra join fielter
						ArrayAppend(temp.filters,StructNew());
						temp.filters[ArrayLen(temp.filters)].table = rfields[i].Relation["join-table"];
						temp.filters[ArrayLen(temp.filters)].field = rfields[i].Relation["join-table-field-local"];
						temp.filters[ArrayLen(temp.filters)].operator = "IN";
						temp.filters[ArrayLen(temp.filters)].value = sRecord[rfields[i].ColumnName];
					} else {
						// Use filters for extra join fielter
						ArrayAppend(temp.filters,StructNew());
						temp.filters[ArrayLen(temp.filters)].table = rfields[i].Relation["table"];
						temp.filters[ArrayLen(temp.filters)].field = rfields[i].Relation["join-field-remote"];
						temp.filters[ArrayLen(temp.filters)].operator = "IN";
						temp.filters[ArrayLen(temp.filters)].value = sRecord[rfields[i].ColumnName];
					}
					qRelationList = getRecords(argumentCollection=temp);

					temp = "";
					for ( sRelation in qRelationList ) {
						if ( Len(qRelationList[rfields[i].Relation["field"]][CurrentRow]) ) {
							if ( StructKeyExists(rfields[i].Relation,"delimiter") ) {
								//temp = ListAppend(temp,sRelation[rfields[i].Relation["field"]],rfields[i].Relation["delimiter"]);
								if ( Len(temp) ) {
									temp = temp & rfields[i].Relation["delimiter"];
								}
								temp = temp & sRelation[rfields[i].Relation["field"]];
							} else {
								temp = ListAppend(temp,sRelation[rfields[i].Relation["field"]]);
							}
						}
					}
					//QuerySetCell(qRecords, rfields[i].ColumnName, temp, CurrentRow);
					sRecord[rfields[i].ColumnName] = temp;
				}
			}
		}
	}

	return qRecords;
}

/**
* @tablename The name of the table to which a column will be added.
* @columnname The name of the column to add.
* @CF_Datatype The ColdFusion SQL Datatype of the column.
* @Length The ColdFusion SQL Datatype of the column.
* @Default The default value for the column.
* @Special The special behavior for the column.
* @Relation Relationship information for this column.
* @PrimaryKey Indicates whether this column is a primary key.
* @AllowNulls Indicates whether this column allows null values.
* @useInMultiRecordsets Indicates whether this column should be included in multi-recordset queries.
*/
private struct function convertColumnAtts(
	required string tablename,
	required string columnname,
	string CF_Datatype,
	numeric Length=0,
	string Default,
	string Special,
	struct Relation,
	boolean PrimaryKey,
	boolean AllowNulls=true,
	boolean useInMultiRecordsets=true
) {

	// Default length to 255 (only used for text types)
	if ( arguments.Length EQ 0 AND StructKeyExists(arguments,"CF_Datatype") ) {
		arguments.Length = 255;
	}

	if ( StructKeyExists(arguments,"CF_Datatype") ) {
		arguments.CF_Datatype = UCase(arguments.CF_Datatype);
		
		//Set default (if exists)
		if ( StructKeyExists(arguments,"Default") AND Len(arguments["Default"]) ) {
			arguments["Default"] = makeDefaultValue(arguments["Default"],arguments["CF_DataType"]);
		}
		//Set Special (if exists)
		if ( StructKeyExists(arguments,"Special") ) {
			arguments["Special"] = Trim(arguments["Special"]);
			//Sorter or DeletionMark should default to zero/false
			if (  NOT StructKeyExists(arguments,"Default") ) {
				if ( arguments["Special"] EQ "Sorter" OR ( arguments["Special"] EQ "DeletionMark" AND arguments["CF_Datatype"] EQ "CF_SQL_BIT" ) ) {
					arguments["Default"] = makeDefaultValue(0,arguments["CF_DataType"]);
				}
				if ( arguments["Special"] EQ "CreationDate" OR arguments["Special"] EQ "LastUpdatedDate" ) {
					arguments["Default"] = getNowSQL();
				}
			}
		} else {
			arguments["Special"] = "";
		}
	}
	//Other field for list relation
	if (
			StructKeyExists(arguments,"Relation")
		AND	StructKeyExists(arguments["Relation"],"type")
		AND	arguments["Relation"].type EQ "list"
		AND	StructKeyExists(arguments,"OtherField")
		AND	NOT StructKeyExists(arguments["Relation"],"other-field")
	) {
		arguments["Relation"]["other-field"] = arguments["OtherField"];
	}

	return StructFromArgs(arguments);
}

private array function getComparatorSQL(
	required string value,
	required string cfsqltype,
	string operator="=",
	boolean nullable=true,
	any sql
) {
	var aSQL = ArrayNew(1);
	var inops = "IN,NOT IN";
	var posops = "=,IN,LIKE,>,>=";

	if ( StructKeyExists(arguments,"sql") AND ( NOT isSimpleValue(arguments.sql) OR Len(arguments.sql) ) ) {
		if ( ListFindNoCase(inops,arguments.operator) ) {
			ArrayAppend(aSQL," #arguments.operator# (");
			ArrayAppend(aSQL,arguments.sql);
			ArrayAppend(aSQL," )");
		} else {
			ArrayAppend(aSQL," #arguments.operator#");
			ArrayAppend(aSQL,arguments.sql);
		}
	} else if ( Len(Trim(arguments.value)) OR NOT arguments.nullable ) {
		if ( ListFindNoCase(inops,arguments.operator) ) {
			ArrayAppend(aSQL," #arguments.operator# (");
			ArrayAppend(aSQL,queryparam(cfsqltype=arguments.cfsqltype,value=arguments.value,list=true));
			ArrayAppend(aSQL," )");
		} else {
			ArrayAppend(aSQL," #arguments.operator#");
			ArrayAppend(aSQL,queryparam(arguments.cfsqltype,arguments.value));
		}
	} else {
		if ( ListFindNoCase(posops,arguments.operator) ) {
			ArrayAppend(aSQL," IS");
		} else {
			ArrayAppend(aSQL," IS NOT");
		}
		ArrayAppend(aSQL," NULL");
	}

	return aSQL;
}

/**
* I get a list of all tables in the current database.
*/
public string function getDatabaseTablesCache() {
	if ( NOT StructKeyExists(variables,"cache_dbtables") ) {
		variables.cache_dbtables = getDatabaseTables();
	}

	return variables.cache_dbtables;
}

public string function getDBDataTypeFull(required struct sField) {
	var cftype = StructKeyExists(sField,"CF_DataType") ? sField.CF_DataType : sField.CFSQLTYPE;
	var dbtype = getDBDataType(cftype);

	if ( isStringType(getDBDataType(cftype)) ) {
		if ( StructKeyExists(sField,"Length") AND Val(sField.Length) ) {
			dbtype = dbtype & "(#Val(sField.Length)#)";
		} else if ( StructKeyExists(sField,"MaxLength") AND Val(sField.MaxLength) ) {
			dbtype = dbtype & "(#Val(sField.MaxLength)#)";
		}
	}

	return dbtype;
}

/**
* I check to see if the given table exists in the Datamgr.
*/
public boolean function hasTable(required string tablename) {
	var result = true;

	try {
		checkTable(arguments.tablename);
	} catch ( any e ) {
		result = false;
	}

	return result;
}

private array function getDefaultOrderBySQL(
	required string tablename,
	required string tablealias,
	string fieldlist=""
) {
	var aResults = [];
	var fields = getUpdateableFields(arguments.tablename);// non primary-key fields in table
	var pkfields = getPKFields(arguments.tablename);// primary key fields in table
	var ii = 0;
	var temp = "";

	if ( ArrayLen(pkfields) AND pkfields[1].CF_DataType EQ "CF_SQL_INTEGER" AND ( ListFindNoCase(arguments.fieldlist,pkfields[1].ColumnName) OR NOT Len(arguments.fieldlist) ) ) {
		ArrayAppend(aResults,getFieldSelectSQL(arguments.tablename,pkfields[1].ColumnName,arguments.tablealias,false));
	} else if ( Len(arguments.fieldlist) ) {
		ArrayAppend(aResults,getOrderbyFieldList(argumentCollection=arguments));
	} else if ( ArrayLen(pkfields) ) {
		ArrayAppend(aResults,getFieldSelectSQL(arguments.tablename,pkfields[1].ColumnName,arguments.tablealias,false));
	} else {
		for ( ii=1; ii LTE Min(ArrayLen(fields),3); ii++ ) {
			if ( NOT ListFindNoCase(variables.nocomparetypes,fields[ii].CF_DataType) ) {
				ArrayAppend(aResults,getFieldSelectSQL(arguments.tablename,fields[ii].ColumnName,arguments.tablealias,false));
				break;
			}
		}
	}

	if ( Len(arguments.function) ) {
		temp = arguments["function"] & "(";
		ArrayPrepend(aResults,temp);
		ArrayAppend(aResults,")");
	}

	return aResults;
}

private function  getFieldNowValue(
	required string tablename,
	required struct sField
) {
	var result = "";
	var type = getSpecialDateType(arguments.tablename,arguments.sField);

	switch ( type ) {
		case "DB":
		case "SQL":
			result = getNowSQL();
			break;
		case "UTC":
			result = sval(arguments.sField,DateAdd('s',GetTimezoneInfo().utcTotalOffset,now()));
			break;
		default:
			result = sval(arguments.sField,now());
	}

	return result;
}

public struct function getFTableFields(required string tablename) {
	var aFields = 0;
	var ii = 0;
	var sResult = 0;

	if ( StructKeyExists(variables.tableprops, arguments.tablename) ) {
		if ( NOT StructKeyExists(variables.tableprops[arguments.tablename],"ftablekeys") ) {
			variables.tableprops[arguments.tablename]["ftablekeys"] = {};
			aFields = getFields(arguments.tablename);
			for ( ii = 1; ii <= ArrayLen(aFields); ii++ ) {
				if ( StructKeyExists(aFields[ii], "ftable") ) {
					variables.tableprops[arguments.tablename]["ftablekeys"][aFields[ii].ftable] = aFields[ii].ColumnName;
				}
			}
		}
		sResult = variables.tableprops[arguments.tablename]["ftablekeys"];
	} else {
		sResult = {};
	}

	return sResult;
}

private function getSpecialDateType(
	required string tablename,
	required struct sField
) {
	var result = "CF";
	var validtypes = "CF,UTC,DB,SQL";

	if ( StructKeyExists(arguments.sField, "SpecialDateType") AND ListFindNoCase(validtypes, arguments.sField.SpecialDateType) ) {
		result = arguments.sField.SpecialDateType;
	} else if ( StructKeyExists(variables.tableprops[arguments.tablename], "SpecialDateType") AND ListFindNoCase(validtypes, variables.tableprops[arguments.tablename].SpecialDateType) ) {
		result = variables.tableprops[arguments.tablename].SpecialDateType;
	} else if ( StructKeyExists(variables, "SpecialDateType") AND ListFindNoCase(validtypes, variables.SpecialDateType) ) {
		result = variables.SpecialDateType;
	}

	return result;
}

private function getFieldSQL_Math(
	required string tablename,
	required string field,
	string tablealias
) {
	var sField = getField(arguments.tablename, arguments.field);
	var aSQL = [];

	ArrayAppend(aSQL, "(");
	ArrayAppend(aSQL, getFieldSelectSQL(tablename=arguments.tablename, field=sField.Relation['field1'], tablealias=arguments.tablealias, useFieldAlias=false));
	ArrayAppend(aSQL, sField.Relation['operator']);
	ArrayAppend(aSQL, getFieldSelectSQL(tablename=arguments.tablename, field=sField.Relation['field2'], tablealias=arguments.tablealias, useFieldAlias=false));
	ArrayAppend(aSQL, ")");

	return aSQL;
}

/**
* I determine if the given field is in the select list.
*/
private boolean function isFieldInSelect(
	required struct field,
	string fieldlist="",
	numeric maxrows=0
) {
	var sField = arguments.field;
	var result = false;

	if (
			(
					Len(arguments.fieldlist) EQ 0
				AND	(
							NOT	StructKeyExists(sField, "useInMultiRecordsets")
						OR	sField.useInMultiRecordsets IS true
						OR	arguments.maxrows EQ 1
					)
			)
		OR	ListFindNoCase(arguments.fieldlist, sField.ColumnName)
	) {
		result = true;
	}

	return result;
}

/**
* I check the length of incoming data to see if it can fit in the designated field (making for a more developer-friendly error messages).
*/
private void function checkLength(
	required struct field,
	required string data
) {
	var type = getDBDataType(arguments.field.CF_DataType);

	if (
		isStringType(type)
		AND
		StructKeyExists(arguments.field, "Length")
		AND
		isNumeric(arguments.field.Length)
		AND
		arguments.field.Length GT 0
		AND
		Len(arguments.data) GT arguments.field.Length
	) {
		throwDMError("The data for '#arguments.field.ColumnName#' must be no more than #arguments.field.Length# characters in length.");
	}
}

/**
* I check to see if the given table exists in the DataMgr.
*/
private boolean function checkTable(
	required string tablename
) {

	//Note that this method is overridden for any database for which DataMgr can introspect the database table

	if ( NOT StructKeyExists(variables.tables, arguments.tablename) ) {
		throwDMError("The table #arguments.tablename# must be loaded into DataMgr before you can use it.", "NoTableLoaded");
	}

	return true;
}

/**
* I check to see if the given table has a primary key.
*/
private void function checkTablePK(
	required string tablename
) {
	var i = 0; // counter
	var arrFields = ArrayNew(1); // array of primarykey fields

	// If pkfields data if stored
	if (
		StructKeyExists(variables.tableprops, arguments.tablename)
		AND
		StructKeyExists(variables.tableprops[arguments.tablename], "pkfields")
	) {
		arrFields = variables.tableprops[arguments.tablename]["pkfields"];
	} else {
		for ( i = 1; i <= ArrayLen(variables.tables[arguments.tablename]); i++ ) {
			if (
				StructKeyExists(variables.tables[arguments.tablename][i], "PrimaryKey")
				AND
				variables.tables[arguments.tablename][i].PrimaryKey
			) {
				ArrayAppend(arrFields, variables.tables[arguments.tablename][i]);
			}
		}
	}

	if ( NOT ArrayLen(arrFields) ) {
		throwDMError("The table #arguments.tablename# must have at least one primary key field to be used by DataMgr.", "NoPKField");
	}
}

/**
* I take a potentially nested SQL array and return a flat SQL array.
*/
private array function cleanSQLArray(
	required array sqlarray
) {
	return _cleanSQLArray(arguments.sqlarray);
}

/**
* I take a potentially nested SQL array and return a flat SQL array.
*/
private array function _cleanSQLArray(
	required array sqlarray
) {
	var result = ArrayNew(1);
	var i = 0;
	var j = 0;
	var temparray = 0;

	for ( i = 1; i <= ArrayLen(arguments.sqlarray); i++ ) {
		if ( isArray(arguments.sqlarray[i]) ) {
			temparray = _cleanSQLArray(arguments.sqlarray[i]);
			for ( j = 1; j <= ArrayLen(temparray); j++ ) {
				ArrayAppend(result, temparray[j]);
			}
		} else if ( isStruct(arguments.sqlarray[i]) ) {
			ArrayAppend(result, queryparam(argumentCollection=arguments.sqlarray[i]));
		} else {
			ArrayAppend(result, arguments.sqlarray[i]);
		}
	}

	return result;
}

private function DMDuplicate(
	required any var
) {
	var result = 0;
	var key = "";

	if ( isStruct(arguments.var) ) {
		result = StructCopy(arguments.var);
	} else {
		result = arguments.var;
	}

	return result;
}

private string function DMPreserveSingleQuotes(
	required any sql
) {
	return PreserveSingleQuotes(arguments.sql);
}

/**
* I return an escaped value for a table or field.
*/
private string function escape(
	required string name
) {
	return "#arguments.name#";
}

public struct function expandRelationStruct(
	required struct Relation,
	struct field
) {
	var sResult = Duplicate(arguments.Relation);
	var key = "";
	var sField = {};
	var sLocalFTables = 0;
	var sRemoteFTables = 0;
	var isFtableInUse = false;

	if ( StructKeyExists(arguments,"field") ) {
		sField = arguments.field;
	}

	for ( key in sResult ) {
		if ( key CONTAINS "_" AND KEY NEQ "CF_Datatype" ) {
			sResult[ListChangeDelims(key,"-","_")] = sResult[key];
			StructDelete(sResult,key);
		}
	}

	if ( StructKeyHasLen(sResult,"type") AND sResult["type"] EQ "list" ) {
		if ( NOT StructKeyHasLen(sResult,"delimiter") ) {
			sResult["delimiter"] = ",";
		}
	}
	if ( StructKeyExists(sResult,"join-table") ) {
		if ( StructKeyExists(sResult,"join-field") AND NOT StructKeyExists(sResult,"join-field-local") ) {
			sResult["join-field-local"] = sResult["join-field"];
		}
		if ( StructKeyExists(sResult,"join-field") AND NOT StructKeyExists(sResult,"join-field-remote") ) {
			sResult["join-field-remote"] = sResult["field"];
		}
		if ( StructKeyExists(sResult,"join-field-local") AND Len(sResult["join-field-local"]) AND NOT StructKeyExists(sResult,"join-table-field-local") ) {
			sResult["join-table-field-local"] = sResult["join-field-local"];
		}
		if ( StructKeyExists(sResult,"join-field-remote") AND Len(sResult["join-field-remote"]) AND NOT StructKeyExists(sResult,"join-table-field-remote") ) {
			sResult["join-table-field-remote"] = sResult["join-field-remote"];
		}
		if ( NOT StructKeyExists(sResult,"join-table-field-local") ) {
			sResult["join-table-field-local"] = "";
		}
		if ( NOT StructKeyExists(sResult,"join-table-field-remote") ) {
			sResult["join-table-field-remote"] = "";
		}
		if ( NOT StructKeyExists(sResult,"local-table-join-field") ) {
			sResult["local-table-join-field"] = sResult["join-table-field-local"];
		}
		if ( NOT StructKeyExists(sResult,"remote-table-join-field") ) {
			sResult["remote-table-join-field"] = sResult["join-table-field-remote"];
		}
	} else {
		if ( NOT StructKeyExists(sResult,"join-field") ) {
			if ( StructKeyExists(sField,"tablename") AND StructKeyExists(sResult,"table") ) {
				if ( NOT StructKeyExists(sResult,"join-field-local") ) {
					sLocalFTables = getFTableFields(sField["tablename"]);
					if ( StructKeyExists(sLocalFTables,sResult["table"]) ) {
						sResult["join-field-local"] = sLocalFTables[sResult["table"]];
						isFtableInUse = true;
					}
				}
				if ( NOT StructKeyExists(sResult,"join-field-remote") ) {
					sRemoteFTables = getFTableFields(sResult["table"]);
					if ( StructKeyExists(sRemoteFTables,sField["tablename"]) ) {
						sResult["join-field-remote"] = sRemoteFTables[sField["tablename"]];
						isFtableInUse = true;
					}
				}
				if ( isFtableInUse ) {
					if ( NOT StructKeyExists(sResult,"join-field-local") ) {
						sResult["join-field-local"] = getPrimaryKeyFieldNames(sField["tablename"]);
					}
					if ( NOT StructKeyExists(sResult,"join-field-remote") ) {
						sResult["join-field-remote"] = getPrimaryKeyFieldNames(sResult["table"]);
					}
				}
			}
			if ( StructKeyExists(sResult,"field") AND NOT isFtableInUse ) {
				sResult["join-field"] = sResult["field"];
			}
		}
		if ( StructKeyExists(sResult,"join-field") AND NOT StructKeyExists(sResult,"join-field-local") ) {
			sResult["join-field-local"] = sResult["join-field"];
		}
		if ( StructKeyExists(sResult,"join-field") AND NOT StructKeyExists(sResult,"join-field-remote") ) {
			sResult["join-field-remote"] = sResult["join-field"];
		}
	}

	// Checking for invalid combinations
	if ( StructKeyExists(sResult,"table") AND StructKeyExists(sResult,"join-table") ) {
		if ( Len(sResult.table) AND sResult["table"] EQ sResult["join-table"] ) {
			throwDMError("The table and join-table attributes cannot be the same.","RelationAttributesError");
		}
	}

	if ( StructKeyExists(sField,"ColumnName") ) {
		if ( StructKeyExists(sResult,"join-field-local") AND sField["ColumnName"] EQ sResult["join-field-local"] ) {
			throwDMError("A field cannot refer to itself in a relation.","RelationAttributesError","#sField.ColumnName#");
		}
		if ( StructKeyExists(sResult,"local-table-join-field") AND sField["ColumnName"] EQ sResult["local-table-join-field"] ) {
			throwDMError("A field cannot refer to itself in a relation.","RelationAttributesError","#sField.ColumnName#");
		}
	}

	return sResult;
}

private void function fillOutJoinTableRelations(required string tablename) {
	var bCheckTable = checkTable(arguments.tablename);
	var relates = variables.tables[arguments.tablename];
	var ii = 0;
	var sFillOut = 0;

	if ( NOT StructKeyExists(variables.tableprops[arguments.tablename], "fillOutJoinTableRelations") ) {
		for ( ii = 1; ii <= ArrayLen(relates); ii++ ) {
			if ( StructKeyExists(relates[ii], "Relation") ) {
				if ( StructKeyExists(relates[ii].Relation, "table") AND StructKeyExists(relates[ii].Relation, "join-table") ) {
					checkTable(relates[ii].Relation["table"]);
					checkTable(relates[ii].Relation["join-table"]);
					sFillOut = {};
					if ( NOT (StructKeyExists(relates[ii].Relation, "join-table-field-local") AND Len(relates[ii].Relation["join-table-field-local"])) ) {
						sFillOut["join-table-field-local"] = getPrimaryKeyFieldName(arguments.tablename);
					}
					if ( NOT (StructKeyExists(relates[ii].Relation, "join-table-field-remote") AND Len(relates[ii].Relation["join-table-field-remote"])) ) {
						sFillOut["join-table-field-remote"] = getPrimaryKeyFieldName(relates[ii].Relation["table"]);
					}
					if ( NOT (StructKeyExists(relates[ii].Relation, "local-table-join-field") AND Len(relates[ii].Relation["local-table-join-field"])) ) {
						sFillOut["local-table-join-field"] = getPrimaryKeyFieldName(arguments.tablename);
					}
					if ( NOT (StructKeyExists(relates[ii].Relation, "remote-table-join-field") AND Len(relates[ii].Relation["remote-table-join-field"])) ) {
						sFillOut["remote-table-join-field"] = getPrimaryKeyFieldName(relates[ii].Relation["table"]);
					}
					StructAppend(variables.tables[arguments.tablename][ii].Relation, sFillOut);
				}
			}
		}
		variables.tableprops[arguments.tablename]["fillOutJoinTableRelations"] = true;
	}
}

private numeric function getColumnIndex(
	required string tablename,
	required string columnname
) {
	var bTable = checkTable(arguments.tablename);
	var aTable = 0;
	var ii = 0;
	var result = 0;

	aTable = variables.tables[arguments.tablename];

	for ( ii = 1; ii <= ArrayLen(aTable); ii++ ) {
		if ( aTable[ii].ColumnName EQ arguments.columnname ) {
			result = ii;
			break;
		}
	}

	return result;
}

/**
* Returns a java.sql.Connection (taken from Transfer with permission).
*/
private any function getConnection() {
	var datasourceService = createObject("Java", "coldfusion.server.ServiceFactory").getDataSourceService();

	if ( StructKeyExists(variables,"username") AND StructKeyExists(variables,"password") ) {
		return datasourceService.getDatasource(variables.datasource).getConnection(variables.username, variables.password);
	} else {
		return datasourceService.getDatasource(variables.datasource).getConnection();
	}
}

/**
* I return a struct from a data string or struct for a table.
*/
private struct function getDataStruct(
	required string tablename,
	required any data
) {
	var result = 0;
	var pkfields = 0;

	if ( isStruct(arguments.data) ) {
		result = StructCopy(arguments);
	} else if ( isSimpleValue(arguments.data) ) {
		pkfields = getPKFields(arguments.tablename);
		if ( ArrayLen(pkfields) EQ 1 ) {
			result = {};
			result[pkfields[1].ColumnName] = arguments.data;
		}
	}

	if ( isStruct(result) ) {
		result = clean(result);
	} else {
		throwDMError("The data argument must be a structure or must be a a primary key value for a table with a simple primary key.", "InvalidDataArgument");
	}

	return result;
}

/**
* I get the generic ColdFusion data type for the given field.
*/
private string function getEffectiveDataType(
	required string tablename,
	required string fieldname
) {
	var sField = 0;
	var result = "invalid";

	if ( isNumeric(arguments.fieldname) ) {
		result = "numeric";
	} else {
		try {
			sField = getField(arguments.tablename, arguments.fieldname);
			result = getEffectiveFieldDataType(sField);
		} catch ( any e ) {
		}
	}

	return result;
}

/**
* I get the generic ColdFusion data type for the given field.
*/
private string function getEffectiveFieldDataType(
	required struct field
) {
	var sField = arguments.field;
	var result = "invalid";

	if ( StructKeyExists(sField, "Relation") AND StructKeyExists(sField.Relation, "type") ) {
		switch ( sField.Relation.type ) {
			case "label":
				result = getEffectiveDataType(sField.Relation.table, sField.Relation.field);
				break;
			case "concat":
				result = "string";
				break;
			case "list":
				if ( arguments.isInWhere ) {
					result = getEffectiveDataType(sField.Relation.table, sField.Relation.field);
				} else {
					result = "invalid";
				}
				break;
			case "avg,count,max,min,sum":
				result = "numeric";
				break;
			case "has":
				result = "boolean";
				break;
			case "math":
				result = "numeric";//Unless I figure out datediff 
				break;
			case "now":
				result = "date";
				break;
			case "custom":
				if ( StructKeyExists(sField.Relation, "CF_Datatype") ) {
					result = getGenericType(sField.Relation.CF_Datatype);
				} else {
					result = "invalid";
				}
				break;
		}
	} else if ( StructKeyExists(sField, "CF_Datatype") ) {
		result = getGenericType(sField.CF_Datatype);
	}

	return result;
}

/**
* I get the generic ColdFusion data type for the given field.
*/
private string function getGenericType(
	required string CF_Datatype
) {
	var result = "invalid";

	switch ( arguments.CF_Datatype ) {
		case "CF_SQL_BIGINT":
		case "CF_SQL_DECIMAL":
		case "CF_SQL_DOUBLE":
		case "CF_SQL_FLOAT":
		case "CF_SQL_INTEGER":
		case "CF_SQL_MONEY":
		case "CF_SQL_MONEY4":
		case "CF_SQL_NUMERIC":
		case "CF_SQL_REAL":
		case "CF_SQL_SMALLINT":
		case "CF_SQL_TINYINT":
			result = "numeric";
			break;
		case "CF_SQL_BIT":
			result = "boolean";
			break;
		case "CF_SQL_BLOB":
			result = "binary";
			break;
		case "CF_SQL_CHAR":
		case "CF_SQL_IDSTAMP":
		case "CF_SQL_VARCHAR":
			result = "string";
			break;
		case "CF_SQL_DATE":
			result = "date";
			break;
		case "CF_SQL_DATETIME":
		case "CF_SQL_TIMESTAMP":
			result = "datetime";
			break;
		case "CF_SQL_LONGVARCHAR":
		case "CF_SQL_CLOB":
			result = "invalid";
			break;
	}

	return result;
}

/**
* I get field of the given name.
*/
public struct function getField(
	required string tablename,
	required string fieldname
) {
	var ii = 0;
	var result = "";

	try {
		checkTable(arguments.tablename);
	} catch ( any e ) {
		throwDMError("The #arguments.tablename# table does not exist.", "NoSuchTable");
	}

	// Loop over the fields in the table and make a list of them
	if ( StructKeyExists(variables.tables, arguments.tablename) ) {
		for ( ii = 1; ii <= ArrayLen(variables.tables[arguments.tablename]); ii++ ) {
			if ( variables.tables[arguments.tablename][ii].ColumnName EQ arguments.fieldname ) {
				result = Duplicate(variables.tables[arguments.tablename][ii]);
				result["tablename"] = arguments.tablename;
				result["fieldname"] = arguments.fieldname;
				break;
			}
		}
		if ( NOT isStruct(result) ) {
			throwDMError("The field '#arguments.fieldname#' could not be found in the #arguments.tablename# table.", "NoSuchField");
		}
	} else {
		throwDMError("The #arguments.tablename# table does not exist.", "NoSuchTable");
	}

	return result;
}

/**
* I get the value of the identity field that was just inserted into the given table.
*/
private string function getInsertedIdentity(
	required string tablename,
	required string identfield
) {
	var qCheckKey = 0;
	var result = 0;
	var sqlarray = ArrayNew(1);

	ArrayAppend(sqlarray, "SELECT Max(#escape(identfield)#) AS NewID");
	ArrayAppend(sqlarray, "FROM #escape(arguments.tablename)#");
	qCheckKey = runSQLArray(sqlarray);

	result = Val(qCheckKey.NewID);

	return result;
}

private array function getOrderByArray(
	required string tablename,
	required string orderby,
	string tablealias=arguments.tablename
) {
	var bTable = checkTable(arguments.tablename);
	var aResults = [];
	var aFields = getFields(arguments.tablename);
	var ii = 0;
	var OrderClause = "";
	var SortOrder = "";
	var isFieldFound = false;

	for ( OrderClause in ListToArray(arguments.orderby) ) {
		isFieldFound = false;

		// Determine sort order
		if ( ListLast(OrderClause, " ") EQ "DESC" ) {
			SortOrder = "DESC";
		} else {
			SortOrder = "ASC";
		}

		// Peel off sort order
		if ( ListFindNoCase("ASC,DESC",ListLast(OrderClause," ")) ) {
			OrderClause = reverse(ListRest(reverse(OrderClause), " "));
		}

		for ( ii = 1; ii <= ArrayLen(aFields); ii++ ) {
			if ( aFields[ii].ColumnName EQ OrderClause OR aFields[ii].ColumnName EQ Trim(OrderClause) ) {
				ArrayAppend(aResults,getFieldSelectSQL(tablename=arguments.tablename,field=aFields[ii].ColumnName,tablealias=arguments.tablealias));
				ArrayAppend(aResults,SortOrder);
				ArrayAppend(aResults,",");
				isFieldFound = true;
				break;
			}
		}

		// If a field was found, no more work to do
		if ( NOT isFieldFound ) {
			// Security measure, a semicolon indicates the start of a new SQL statement (this is after the field search so that a field name could contain one)
			if ( OrderClause CONTAINS ";" ) {
				break;
			}
			ArrayAppend(aResults,OrderClause);
			ArrayAppend(aResults,SortOrder);
			ArrayAppend(aResults,",");
		}
	}

	// Ditch trailing comma
	if ( ArrayLen(aResults) AND aResults[ArrayLen(aResults)] EQ "," ) {
		ArrayDeleteAt(aResults,ArrayLen(aResults));
	}

	return aResults;
}

private array function getOrderbyFieldList() {
	var orderarray = [];
	var temp = "";
	var fields = getFieldList(tablename=arguments.tablename);
	var sql = "";
	var sqlkeys = "";
	var sqlkey = "";
	var count = 0;

	if ( Len(arguments.fieldlist) ) {
		for ( temp in ListToArray(arguments.fieldlist) ) {
			if ( ListFindNoCase(fields, temp) ) {
				count++;
				if (count <= 3) {
					sql = getFieldSelectSQL(tablename=arguments.tablename, field=temp, tablealias=arguments.tablealias, useFieldAlias=false);
					sqlkey = Hash(readableSQL(sql));
					if ( NOT ListFindNoCase(sqlkeys, sqlkey) ) {
						if ( ArrayLen(orderarray) > 0 ) {
							ArrayAppend(orderarray, ",");
						}
						ArrayAppend(orderarray, sql);
						sqlkeys = ListAppend(sqlkeys, sqlkey);
					} else {
						count--;
					}
				}
			}
		}
	}

	return orderarray;
}

private struct function getProps() {
	var sProps = {};

	sProps["areSubqueriesSortable"] = true;
	StructAppend(sProps, getDatabaseProperties(), true);

	return sProps;
}

private struct function getRelationValues(
	required string tablename,
	required struct data
) {
	var sData = DMDuplicate(arguments.data);
	var rfields = getRelationFields(arguments.tablename); // relation fields in table
	var dbfields = getDBFieldList(arguments.tablename);
	var i = 0;
	var qRecords = 0;
	var temp = 0;
	var temp2 = 0;
	var j = 0;

	// Check for incoming label values
	for ( i = 1; i <= ArrayLen(rfields); i++ ) {
		// Perform action for labels where join-field isn't already being given a value
		if ( StructKeyExists(sData, rfields[i].ColumnName) AND NOT ListFindNoCase(dbfields, rfields[i].ColumnName) ) {
			// If this is a label and the associated value isn't already set and valid
			if ( rfields[i].Relation.type EQ "label" AND NOT useField(sData, getField(arguments.tablename, rfields[i].Relation["join-field-local"])) ) {
				// Get the value for the relation field
				temp = {};
				temp[rfields[i].Relation["field"]] = sData[rfields[i].ColumnName];
				qRecords = getRecords(tablename=rfields[i].Relation["table"],data=temp,maxrows=1,fieldlist=rfields[i].Relation["join-field-remote"]);
				// If a record is found, set the value
				if ( qRecords.RecordCount ) {
					sData[rfields[i].Relation["join-field-local"]] = qRecords[rfields[i].Relation["join-field-remote"]][1];
				} 
				// If no record is found, but an "onMissing" att is, take appropriate action
				else if ( StructKeyExists(rfields[i].Relation, "onMissing") ) {
					switch (rfields[i].Relation.onMissing) {
						case "insert":
							temp2 = insertRecord(rfields[i].Relation["table"], temp);
							qRecords = getRecords(tablename=rfields[i].Relation["table"],data=temp,maxrows=1,fieldlist=rfields[i].Relation["join-field-remote"]);
							sData[rfields[i].Relation["join-field-local"]] = qRecords[rfields[i].Relation["join-field-remote"]][1];
							break;
						case "error":
							throwDMError("""#sData[rfields[i].ColumnName]#"" is not a valid value for ""#rfields[i].ColumnName#""", "InvalidLabelValue");
							break;
					}
				}
				// ditch this column name from in struct (no longer needed)
				StructDelete(sData, rfields[i].ColumnName);
			} 
			else if ( rfields[i].Relation.type EQ "concat" AND StructKeyExists(rfields[i].Relation, "delimiter") AND StructKeyExists(rfields[i].Relation, "fields") AND Len(sData[rfields[i].ColumnName]) ) {
				if ( ListLen(rfields[i].Relation["fields"]) EQ ListLen(sData[rfields[i].ColumnName], rfields[i].Relation["delimiter"]) ) {
					// Make sure none of the component fields are being passed in.
					temp2 = true;
					for (temp in ListToArray(rfields[i].Relation.fields)) {
						if ( StructKeyExists(sData, temp) ) {
							temp2 = false;
						}
					}
					// If none of the fields are being passed in already, set fields based on concat
					if ( temp2 ) {
						for ( j = 1; j <= ListLen(rfields[i].Relation.fields); j++ ) {
							temp = ListGetAt(rfields[i].Relation.fields, j);
							sData[temp] = ListGetAt(sData[rfields[i].ColumnName], j, rfields[i].Relation["delimiter"]);
						}
					}
				} else {
					throwDMError("The number of items in #rfields[i].ColumnName# don't match the number of fields.", "ConcatListLenMisMatch");
				}
			}
		}
	}

	return sData;
}

private query function getPreSeedRecords(required string tablename) {
	return getRecords(tablename=arguments.tablename,function="count",FunctionAlias="NumRecords");
}

/**
* I return an array of relation fields.
*/
public array function getRelationFields(required string tablename) {
	var i = 0; // counter
	var arrFields = []; // array of primarykey fields
	var bTable = checkTable(arguments.tablename); // Check whether table is loaded
	var novar = fillOutJoinTableRelations(arguments.tablename);
	var relates = variables.tables[arguments.tablename];
	var mathoperators = "+,-,*,/";
	var sRelationTypes = getRelationTypes();
	var key = "";
	var fieldatts = "field,field1,field2,fields";
	var dtype = "";
	var sThisRelation = 0;
	var field = "";

	if ( StructKeyExists(variables.tableprops, arguments.tablename) AND StructKeyExists(variables.tableprops[arguments.tablename], "relatefields") ) {
		arrFields = variables.tableprops[arguments.tablename]["relatefields"];
	} else {
		for ( i=1; i <= ArrayLen(relates); i++ ) {
			if ( StructKeyExists(relates[i], "Relation") ) {
				sThisRelation = expandRelationStruct(relates[i].Relation, relates[i]);
				// Make sure relation type exists
				if ( StructKeyExists(sThisRelation, "type") ) {
					// Make sure all needed attributes exist
					if ( StructKeyExists(sRelationTypes, sThisRelation.type) ) {
						for ( key in ListToArray(sRelationTypes[sThisRelation.type].atts_req) ) {
							if ( NOT StructKeyExists(sThisRelation, key) AND NOT (key CONTAINS "join-field" AND (StructKeyExists(sThisRelation, "join-field") OR StructKeyExists(sThisRelation, "join-table"))) ) {
								throwDMError("There is a problem with the #relates[i].ColumnName# field in the #arguments.tablename# table: The #key# attribute is required for a relation type of #sThisRelation.type#.", "RelationTypeMissingAtt");
							}
						}
					}
					// Check data types
					for ( key in ListToArray(fieldatts) ) {
						if ( StructKeyExists(sThisRelation, key) ) {
							for ( field in ListToArray(sThisRelation[key]) ) {
								if ( StructKeyExists(sThisRelation, "table") ) {
									dtype = getEffectiveDataType(sThisRelation.table, field);
								} else {
									dtype = getEffectiveDataType(arguments.tablename, field);
								}
								if ( dtype == "invalid" OR (Len(sRelationTypes[sThisRelation.type].gentypes) AND !ListFindNoCase(sRelationTypes[sThisRelation.type].gentypes, dtype)) ) {
									throwDMError("There is a problem with the #relates[i].ColumnName# field in the #arguments.tablename# table: #dtype# fields (#field#) cannot be used with a relation type of #sThisRelation.type#.", "InvalidRelationGenericType");
								}
							}
						}
					}
				} else {
					throwDMError("There is a problem with the #relates[i].ColumnName# field in the #arguments.tablename# table has no relation type.", "NoSuchRelationType");
				}
				ArrayAppend(arrFields, relates[i]);
			}
		}
		variables.tableprops[arguments.tablename]["relatefields"] = arrFields;
	}

	for ( i=1; i <= ArrayLen(arrFields); i++ ) {
		arrFields[i].Relation = expandRelationStruct(arrFields[i].Relation, arrFields[i]);
	}

	return arrFields;
}

/**
* I see if the given field is passed in as blank and is a nullable field.
*/
private boolean function isBlankValue(
	required struct Struct,
	required struct Field
) {
	var Key = arguments.Field.ColumnName;
	var result = false;

	if (
			StructKeyExists(arguments.Struct,Key)
		AND	NOT Len(arguments.Struct[Key])
	) {
		result = true;
	}

	return result;
}

private boolean function isIdentityField(required struct Field) {
	var result = false;

	if ( StructKeyExists(Field, "Increment") AND Field.Increment ) {
		result = true;
	}

	return result;
}

private function getTypeOfCFType(required string CF_DataType) {
	var result = "";

	switch (arguments.CF_DataType) {
		case "CF_SQL_BIT":
			result = "boolean";
			break;
		case "CF_SQL_BLOB":
			result = "binary";
			break;
		case "CF_SQL_DECIMAL":
		case "CF_SQL_DOUBLE":
		case "CF_SQL_FLOAT":
		case "CF_SQL_NUMERIC":
			result = "numeric";
			break;
		case "CF_SQL_BIGINT":
		case "CF_SQL_INTEGER":
		case "CF_SQL_SMALLINT":
		case "CF_SQL_TINYINT":
			result = "integer";
			break;
		case "CF_SQL_DATE":
		case "CF_SQL_DATETIME":
			result = "date";
			break;
		default:
			result = arguments.CF_DataType;
			break;
	}

	return result;
}

/**
* I check if the given value is of the given data type.
*/
private boolean function isOfCFType(
	required any value,
	required string CF_DataType
) {
	return isOfType(arguments.value, getTypeOfCFType(arguments.CF_DataType));
}

/**
* I check if the given value is of the given data type.
*/
public boolean function isOfType(
	required any value,
	required string type
) {
	var datum = arguments.value;
	var isOK = false;

	if ( isStruct(datum) AND StructKeyExists(datum,"value") ) {
		datum = datum.value;
	}

	switch (arguments.type) {
		case "boolean":
			isOK = isBoolean(datum);
			break;
		case "numeric":
		case "number":
			isOK = isNumeric(datum) OR isBoolean(datum);
			break;
		case "integer":
			isOK = (isNumeric(datum) OR isBoolean(datum)) AND ( datum EQ Int(datum) ) AND datum LTE 2147483647;
			break;
		case "date":
			isOK = isValidDate(datum);
			break;
		default:
			isOK = true;
			break;
	}

	return isOK;
}

/**
* I return the value of the default for the given datatype and raw value.
*/
private string function makeDefaultValue(
	required string value,
	required string CF_DataType
) {
	var result = Trim(arguments.value);
	var type = getDBDataType(arguments.CF_DataType);
	var isFunction = true;

	// If default isn't a string and is in parens, remove it from parens
	while ( Left(result,1) EQ "(" AND Right(result,1) EQ ")" ) {
		result = Mid(result,2,Len(result)-2);
	}

	// If default is in single quotes, remove it from single quotes
	if ( Left(result,1) EQ "'" AND Right(result,1) EQ "'" ) {
		result = Mid(result,2,Len(result)-2);
		isFunction = false;// Functions aren't in single quotes
	}

	// Functions must have an opening paren and end with a closing paren
	if ( isFunction AND NOT (FindNoCase("(", result) AND Right(result,1) EQ ")") ) {
		isFunction = false;
	}
	// Functions don't start with a paren
	if ( isFunction AND Left(result,1) EQ "(" ) {
		isFunction = false;
	}

	// boolean values should be stored as one or zero
	if ( arguments.CF_DataType EQ "CF_SQL_BIT" ) {
		result = getBooleanSqlValue(result);
	}

	// string values that aren't functions, should be in single quotes.
	if ( isStringType(type) AND NOT isFunction ) {
		result = ReplaceNoCase(result, "'", "''", "ALL");
		result = "'#result#'";
	}

	return result;
}

/**
*I get the internal table representation ready for use by DataMgr.
*/
private void function readyTable(
	required string tablename
) {
	checkTable();

	if ( NOT ( StructKeyExists(variables.tableprops, arguments.tablename) AND StructCount(variables.tableprops[arguments.tablename]) ) ) {
		getFieldList(arguments.tablename);
		getPKFields(arguments.tablename);
		getUpdateableFields(arguments.tablename);
		getRelationFields();
		makeFieldSQLs();
	}
}

/**
* I get the internal table representation ready for use by DataMgr.
*/
public struct function getTableProps(
	string tablename
) {
	if ( StructKeyExists(arguments,"tablename") ) {
		return variables.tableprops[arguments.tablename];
	} else {
		return variables.tableprops;
	}
}

/**
* I indicate if the current database natively supports offsets.
*/
public boolean function dbHasOffset() {
	return false;
}

private void function resetTableProps(required string tablename) {
	var keys = "fielddefaults,fieldlist,fieldlengths,fields,pkfields,updatefields,fillOutJoinTableRelations,relatefields";
	var key = "";

	if ( NOT StructKeyExists(variables.tableprops,arguments.tablename) ) {
		variables.tableprops[arguments.tablename] = StructNew();
	}
	if ( NOT StructKeyExists(variables.tableprops[arguments.tablename],"filters") ) {
		variables.tableprops[arguments.tablename]["filters"] = StructNew();
	}

	for ( key in ListToArray(keys) ) {
		StructDelete(variables.tableprops[arguments.tablename],key);
	}
}

private void function setTableProps(
	required string tablename,
	required struct props
) {
	var keys = "fielddefaults,fieldlist,fieldlengths,fields,pkfields,updatefields,fillOutJoinTableRelations,relatefields";
	var key = "";

	for ( key in arguments.props ) {
		if ( NOT ListFindNoCase(keys,key) ) {
			variables.tableprops[arguments.tablename][key] = arguments.props[key];
		}
	}
}

/**
* @tablename The table on which to update data.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @pkfield The primary key field for the record.
* @pkval The primary key for the record.
*/
private void function saveRelations(
	required string tablename,
	required struct data,
	required struct pkfield,
	required string pkval
) {
	var relates = getRelationFields(arguments.tablename);
	var i = 0;
	var sData = DMDuplicate(arguments.data);
	var rtablePKeys = 0;
	var temp = "";
	var value = "";
	var list = "";
	var fieldPK = "";
	var fieldMulti = "";
	var reverse = false;
	var qRecords = 0;
	var qRecord = 0;

	if ( ArrayLen(relates) AND Len(arguments.pkval) ) {
		for ( i=1; i LTE ArrayLen(relates); i++ ) {
			// Make sure all needed attributes exist
			if (
					StructKeyExists(sData,relates[i].ColumnName)
				AND	relates[i].Relation["type"] EQ "list"
				AND	StructKeyExists(relates[i].Relation,"join-table")
			) {
				rtablePKeys = getPKFields(relates[i].Relation["table"]);
				if ( NOT ArrayLen(rtablePKeys) ) {
					rtablePKeys = getUpdateableFields(relates[i].Relation["table"]);
				}

				// Get correct value for local table value
				if ( Len(relates[i].Relation["local-table-join-field"]) ) {
					fieldPK = relates[i].Relation["local-table-join-field"];
					if ( relates[i].Relation["local-table-join-field"] NEQ getPrimaryKeyFieldName(arguments.tablename) ) {
						temp = StructNew();
						temp[getPrimaryKeyFieldName(arguments.tablename)] = arguments.pkval;
						qRecord = getRecords(tablename=arguments.tablename,data=temp,fieldlist=fieldPK);
						arguments.pkval = qRecord[fieldPK][1];
					}
					if ( Len(relates[i].Relation["join-table-field-local"]) ) {
						fieldPK = relates[i].Relation["join-table-field-local"];
					}
				}

				// Set field for join-table that points to local table
				if ( Len(relates[i].Relation["join-table-field-local"]) ) {
					fieldPK = relates[i].Relation["join-table-field-local"];
				} else {
					fieldPK = getPrimaryKeyFieldName(arguments.tablename);
				}

				// Set field for join-table that points to remote table
				if ( Len(relates[i].Relation["join-table-field-remote"]) ) {
					fieldMulti = relates[i].Relation["join-table-field-remote"];
				} else {
					fieldMulti = getPrimaryKeyFieldName(relates[i].Relation["table"]);
				}

				if (
						arguments.tablename EQ relates[i].Relation["table"]
					AND	StructKeyExists(relates[i].Relation,"bidirectional")
					AND	isBoolean(relates[i].Relation["bidirectional"])
					AND	relates[i].Relation["bidirectional"]
				) {
					reverse = true;
				} else {
					reverse = false;
				}

				// If relate column is pk, use saveRelationList normally
				if ( relates[i].Relation["field"] EQ rtablePKeys[1].ColumnName ) {
					// Save this relation list
					saveRelationList(relates[i].Relation["join-table"],fieldPK,arguments.pkval,fieldMulti,sData[relates[i].ColumnName],reverse);
				} else {
					list = "";
					// Otherwise, get the values
					for ( value in ListToArray(sData[relates[i].ColumnName]) ) {
						temp = StructNew();
						temp[relates[i].Relation["field"]] = Trim(value);
						qRecords = getRecords(tablename=relates[i].Relation["table"],data=temp,fieldlist=rtablePKeys[1].ColumnName);
						if ( qRecords.RecordCount ) {
							list = ListAppend(list,qRecords[rtablePKeys[1].ColumnName][1]);
						}
					}
					saveRelationList(relates[i].Relation["join-table"],fieldPK,arguments.pkval,fieldMulti,list,reverse);
				}
			}
		}
	}

}
</cfscript>

<cffunction name="seedConstraint" access="private" returntype="void" output="no">
	<cfargument name="tablename" type="string" required="true">
	<cfargument name="ftable" type="string" required="true">
	<cfargument name="field" type="string" required="true">
	<cfargument name="onDelete" type="string" required="false">

	<cfset var qConflicts = 0>
	<cfset var pkfield = "">
	<cfset var fpkfield = "">

	<!--- If no foreign key constraint... --->
	<cfif NOT hasConstraint(arguments.tablename,arguments.ftable)>
		<!--- Delete invalid records so that foreign key constraint can be created if onDelete="Cascade"? --->

		<cfset pkfield = getPrimaryKeyFieldName(Arguments.tablename)>
		<cfset fpkfield = getPrimaryKeyFieldName(Arguments.ftable)>

		<cfif ListLen(fpkfield) EQ 1>
			<cfif
					ListLen(pkfield) EQ 1
				AND	StructKeyExists(Arguments,"onDelete")
				AND	Arguments.onDelete EQ "Cascade"
			>
				<cf_DMQuery name="qConflicts">
				SELECT	<cf_DMObject name="#pkfield#"> AS pkvalue
				FROM	<cf_DMObject name="#Arguments.tablename#">
				WHERE	NOT <cf_DMObject name="#Arguments.field#"> IN (
							SELECT	<cf_DMObject name="#fpkfield#">
							FROM	<cf_DMObject name="#Arguments.ftable#">
						)
				</cf_DMQuery>
				<!--- Delete conflict records. Doing one at a time in case table changes are being tracked by DataLogger. --->
				<cfoutput query="qConflicts">
					<cfset deleteRecord(
						tablename=Arguments.tablename,
						data={"#pkfield#"=pkvalue}
					)>
				</cfoutput>
			</cfif>
			<!--- Create constraint in the database. --->
			<cfset runSQLArray(sqlCreateConstraint(ArgumentCollection=Arguments))>
		</cfif>
	</cfif>

</cffunction>

<cfscript>
/**
* @xmldata XML data of tables to load into DataMgr follows. Schema: http://www.bryantwebconsulting.com/cfc/DataMgr.xsd
*/
private void function seedConstraints(
	required any xmldata
) {
	var varXML = arguments.xmldata;
	var aForeignFields = XmlSearch(varXML, "//field[@ftable][@ColumnName]");//Get all real fields that reference other tables
	var ii = 0;
	var xField = 0;
	var sField = 0;
	var xParent = 0;
	var useConstraint = "";
	var sConstraint = 0;

	for ( ii = 1; ii LTE ArrayLen(aForeignFields); ii=ii+1 ) {
		xField = aForeignFields[ii];
		sField = xField.XmlAttributes;
		useConstraint = "";
		//Use a constraint if the attribute exists and is true
		if ( StructKeyExists(sField,"constraint") AND isBoolean(sField["constraint"]) ) {
			useConstraint = sField["constraint"];
		} else {
			//If no "constraint" attribute, then head up the tree looking for "useConstraint"
			xParent = xField;
			//Travel up the tree until we find a value or can go no farther.
			while (
					StructKeyExists(xParent,"XmlParent")
				AND	NOT ( IsBoolean(useConstraint) )
			) {
				xParent = xParent.XmlParent;//Go up one level.
				if (
						StructKeyExists(xParent,"XmlAttributes")
					AND	StructKeyExists(xParent.XmlAttributes,"useConstraints")
					AND	isBoolean(xParent.XmlAttributes["useConstraints"])
				) {
					useConstraint = xParent.XmlAttributes["useConstraints"];
				}
			}
		}
		xParent = xField.XmlParent;//Because we might have traversed up while determining if we should use a constraint.

		//For now, don't handle join-tables. Will need to though, at some point.
		if ( StructKeyHasLen(sField,"jointable") ) {
			useConstraint = false;
		}

		//If we are using a constraint, make sure it exists.
		if ( useConstraint IS true ) {
			sConstraint = {};
			if ( StructKeyExists(sField,"table") ) {
				sConstraint["tablename"] = sField.table;
			} else if ( xParent.XmlName EQ "table" AND StructKeyExists(xParent.XmlAttributes,"name") ) {
				sConstraint["tablename"] = xParent.XmlAttributes["name"];
			}
			sConstraint["field"] = sField["ColumnName"];
			sConstraint["ftable"] = sField["ftable"];
			if ( StructKeyExists(sField,"onDelete") ) {
				sConstraint["onDelete"] = sField["onDelete"];
			}
			if ( StructKeyExists(sConstraint,"tablename") AND sConstraint["tablename"] NEQ sConstraint["ftable"] ) {
				seedConstraint(ArgumentCollection=sConstraint);
			}
		}
	}
}

/**
* @xmldata XML data of tables to load into DataMgr follows. Schema: http://www.bryantwebconsulting.com/cfc/DataMgr.xsd
*/
private void function seedData(
	required any xmldata,
	required string CreatedTables
) {
	var varXML = arguments.xmldata;
	var arrData = XmlSearch(varXML, "//data");
	var stcData = StructNew();
	var tables = "";

	var i = 0;
	var table = "";
	var j = 0;
	var rowElement = 0;
	var rowdata = 0;
	var att = "";
	var k = 0;
	var fieldElement = 0;
	var fieldatts = 0;
	var reldata = 0;
	var m = 0;
	var relfieldElement = 0;

	var data = 0;
	var col = "";
	var qRecord = 0;
	var qRecords = 0;
	var checkFields = "";
	var onexists = "";
	var doSeed = false;

	if ( ArrayLen(arrData) ) {
		//  Loop through data elements
		for ( i=1; i LTE ArrayLen(arrData); i=i+1 ) {
			//  Get table name
			if ( StructKeyExists(arrData[i].XmlAttributes,"table") ) {
				table = arrData[i].XmlAttributes["table"];
			} else  if ( StructKeyExists(arrData[i],"XmlParent") AND arrData[i].XmlParent.XmlName EQ "table" AND StructKeyExists(arrData[i].XmlParent.XmlAttributes,"name") ) {
				table = arrData[i].XmlParent.XmlAttributes["name"];
			} else {
				throwDMError("data element must either have a table attribute or be within a table element that has a name attribute.");
			}
			if ( NOT ( StructKeyExists(arrData[i].XmlAttributes,"permanentRows") AND isBoolean(arrData[i].XmlAttributes["permanentRows"]) ) ) {
				arrData[i].XmlAttributes["permanentRows"] = false;
			}
			// /Get table name
			if ( ListFindNoCase(arguments.CreatedTables,table) OR arrData[i].XmlAttributes["permanentRows"] ) {
				//  Make sure structure exists for this table
				if ( NOT StructKeyExists(stcData,table) ) {
					stcData[table] = ArrayNew(1);
					tables = ListAppend(tables,table);
				}
				// /Make sure structure exists for this table
				//  Loop through rows
				for ( j=1; j LTE ArrayLen(arrData[i].XmlChildren); j=j+1 ) {
					//  Make sure this element is a row
					if ( arrData[i].XmlChildren[j].XmlName EQ "row" ) {
						rowElement = arrData[i].XmlChildren[j];
						rowdata = StructNew();
						//  Loop through fields in row tag
						for ( att in rowElement.XmlAttributes ) {
							rowdata[att] = rowElement.XmlAttributes[att];
						}
						// /Loop through fields in row tag
						//  Loop through field tags
						if ( StructKeyExists(rowElement,"XmlChildren") AND ArrayLen(rowElement.XmlChildren) ) {
							//  Loop through field tags
							for ( k=1; k LTE ArrayLen(rowElement.XmlChildren); k=k+1 ) {
								fieldElement = rowElement.XmlChildren[k];
								//  Make sure this element is a field
								if ( fieldElement.XmlName EQ "field" ) {
									fieldatts = "name,value,reltable,relfield";
									reldata = StructNew();
									//  If this field has a name
									if ( StructKeyExists(fieldElement.XmlAttributes,"name") ) {
										if ( StructKeyExists(fieldElement.XmlAttributes,"value") ) {
											rowdata[fieldElement.XmlAttributes["name"]] = fieldElement.XmlAttributes["value"];
										} else if ( StructKeyExists(fieldElement.XmlAttributes,"reltable") ) {
											if ( NOT StructKeyExists(fieldElement.XmlAttributes,"relfield") ) {
												fieldElement.XmlAttributes["relfield"] = fieldElement.XmlAttributes["name"];
											}
											//  Loop through attributes for related fields
											for ( att in fieldElement.XmlAttributes ) {
												if ( NOT ListFindNoCase(fieldatts,att) ) {
													reldata[att] = fieldElement.XmlAttributes[att];
												}
											}
											// /Loop through attributes for related fields
											if ( ArrayLen(fieldElement.XmlChildren) ) {
												//  Loop through relfield elements
												for ( m=1; m LTE ArrayLen(fieldElement.XmlChildren); m=m+1 ) {
													relfieldElement = fieldElement.XmlChildren[m];
													if ( relfieldElement.XmlName EQ "relfield" AND StructKeyExists(relfieldElement.XmlAttributes,"name") AND StructKeyExists(relfieldElement.XmlAttributes,"value") ) {
														reldata[relfieldElement.XmlAttributes["name"]] = relfieldElement.XmlAttributes["value"];
													}
												}
												// /Loop through relfield elements
											}
											rowdata[fieldElement.XmlAttributes["name"]] = StructNew();
											rowdata[fieldElement.XmlAttributes["name"]]["reltable"] = fieldElement.XmlAttributes["reltable"];
											rowdata[fieldElement.XmlAttributes["name"]]["relfield"] = fieldElement.XmlAttributes["relfield"];
											rowdata[fieldElement.XmlAttributes["name"]]["reldata"] = reldata;
										}
									}
									// /If this field has a name
								}
								// /Make sure this element is a field
							}
							// /Loop through field tags
						}
						// /Loop through field tags
						ArrayAppend(stcData[table], rowdata);
					}
					// /Make sure this element is a row
				}
				// /Loop through rows
			}
		}
		// /Loop through data elements
		if ( Len(tables) ) {
			//  Loop through tables
			for ( i=1; i LTE ArrayLen(arrData); i=i+1 ) {
			//for ( i=1; i LTE ListLen(tables); i=i+1 ) {
				//table = ListGetAt(tables,i);
				if ( StructKeyExists(arrData[i].XmlAttributes,"table") ) {
					table = arrData[i].XmlAttributes["table"];
				} else if ( StructKeyExists(arrData[i].XmlParent.XmlAttributes,"name") ) {
					table = arrData[i].XmlParent.XmlAttributes["name"];
				} else {
					da(arrData[i]);
				}

				checkFields = "";
				onexists = "skip";
				if ( StructKeyExists(arrData[i].XmlAttributes,"checkFields") ) {
					checkFields = arrData[i].XmlAttributes["checkFields"];
				}
				if ( StructKeyExists(arrData[i].XmlAttributes,"onexists") AND arrData[i].XmlAttributes["onexists"] EQ "update" ) {
					onexists = "update";
				}
				if ( StructKeyExists(stcData,table) AND ArrayLen(stcData[table]) ) {
					doSeed = arrData[i].XmlAttributes["permanentRows"];
					if ( NOT doSeed ) {
						qRecords = getPreSeedRecords(table);
						doSeed = ( qRecords.NumRecords EQ 0);
					}
				} else {
					doSeed = false;
				}

				//  If table has seed records
				if ( doSeed ) {
					//  Loop through seed records
					for ( j=1; j LTE ArrayLen(stcData[table]); j=j+1 ) {
						data = StructNew();
						//  Loop through fields in table
						for ( col in stcData[table][j] ) {
							//  Simple val?
							if ( isSimpleValue(stcData[table][j][col]) ) {
								data[col] = stcData[table][j][col];
							} else {
								//  Struct?
								if ( isStruct(stcData[table][j][col]) ) {
									//  Get record of related data
									qRecord = getRecords(stcData[table][j][col]["reltable"],stcData[table][j][col]["reldata"]);
									if ( qRecord.RecordCount EQ 1 AND ListFindNoCase(qRecord.ColumnList,stcData[table][j][col]["relfield"]) ) {
										data[col] = qRecord[stcData[table][j][col]["relfield"]][1];
									}
								}
								// /Struct?
							}
							// /Simple val?
						}
						// /Loop through fields in table
						if ( StructCount(data) ) {
							seedRecord(table,data,onexists,checkFields);
						}
					}
					// /Loop through seed records
				}
				//  If table has seed records
			}
			// /Loop through tables
		}
	}
}

/**
* @xmldata XML data of tables to load into DataMgr follows. Schema: http://www.bryantwebconsulting.com/cfc/DataMgr.xsd
*/
private void function seedData_BAK(
	required any xmldata,
	required string CreatedTables
) {
	var varXML = arguments.xmldata;
	var arrData = XmlSearch(varXML, "//data");
	var stcData = StructNew();
	var tables = "";

	var i = 0;
	var table = "";
	var j = 0;
	var rowElement = 0;
	var rowdata = 0;
	var att = "";
	var k = 0;
	var fieldElement = 0;
	var fieldatts = 0;
	var reldata = 0;
	var m = 0;
	var relfieldElement = 0;

	var data = 0;
	var col = "";
	var qRecord = 0;
	var qRecords = 0;
	var checkFields = "";
	var onexists = "";

	if ( ArrayLen(arrData) ) {
		//  Loop through data elements
		for ( i=1; i LTE ArrayLen(arrData); i=i+1 ) {
			//  Get table name
			if ( StructKeyExists(arrData[i].XmlAttributes,"table") ) {
				table = arrData[i].XmlAttributes["table"];
			} else  if ( StructKeyExists(arrData[i],"XmlParent") AND arrData[i].XmlParent.XmlName EQ "table" AND StructKeyExists(arrData[i].XmlParent.XmlAttributes,"name") ) {
				table = arrData[i].XmlParent.XmlAttributes["name"];
			} else {
				throwDMError("data element must either have a table attribute or be within a table element that has a name attribute.");
			}
			if ( NOT ( StructKeyExists(arrData[i].XmlAttributes,"permanentRows") AND isBoolean(arrData[i].XmlAttributes["permanentRows"]) ) ) {
				arrData[i].XmlAttributes["permanentRows"] = false;
			}
			// /Get table name
			if ( ListFindNoCase(arguments.CreatedTables,table) OR arrData[i].XmlAttributes["permanentRows"] ) {
				//  Make sure structure exists for this table
				if ( NOT StructKeyExists(stcData,table) ) {
					stcData[table] = ArrayNew(1);
					tables = ListAppend(tables,table);
				}
				// /Make sure structure exists for this table
				//  Loop through rows
				for ( j=1; j LTE ArrayLen(arrData[i].XmlChildren); j=j+1 ) {
					//  Make sure this element is a row
					if ( arrData[i].XmlChildren[j].XmlName EQ "row" ) {
						rowElement = arrData[i].XmlChildren[j];
						rowdata = StructNew();
						//  Loop through fields in row tag
						for ( att in rowElement.XmlAttributes ) {
							rowdata[att] = rowElement.XmlAttributes[att];
						}
						// /Loop through fields in row tag
						//  Loop through field tags
						if ( StructKeyExists(rowElement,"XmlChildren") AND ArrayLen(rowElement.XmlChildren) ) {
							//  Loop through field tags
							for ( k=1; k LTE ArrayLen(rowElement.XmlChildren); k=k+1 ) {
								fieldElement = rowElement.XmlChildren[k];
								//  Make sure this element is a field
								if ( fieldElement.XmlName EQ "field" ) {
									fieldatts = "name,value,reltable,relfield";
									reldata = StructNew();
									//  If this field has a name
									if ( StructKeyExists(fieldElement.XmlAttributes,"name") ) {
										if ( StructKeyExists(fieldElement.XmlAttributes,"value") ) {
											rowdata[fieldElement.XmlAttributes["name"]] = fieldElement.XmlAttributes["value"];
										} else if ( StructKeyExists(fieldElement.XmlAttributes,"reltable") ) {
											if ( NOT StructKeyExists(fieldElement.XmlAttributes,"relfield") ) {
												fieldElement.XmlAttributes["relfield"] = fieldElement.XmlAttributes["name"];
											}
											//  Loop through attributes for related fields
											for ( att in fieldElement.XmlAttributes ) {
												if ( NOT ListFindNoCase(fieldatts,att) ) {
													reldata[att] = fieldElement.XmlAttributes[att];
												}
											}
											// /Loop through attributes for related fields
											if ( ArrayLen(fieldElement.XmlChildren) ) {
												//  Loop through relfield elements
												for ( m=1; m LTE ArrayLen(fieldElement.XmlChildren); m=m+1 ) {
													relfieldElement = fieldElement.XmlChildren[m];
													if ( relfieldElement.XmlName EQ "relfield" AND StructKeyExists(relfieldElement.XmlAttributes,"name") AND StructKeyExists(relfieldElement.XmlAttributes,"value") ) {
														reldata[relfieldElement.XmlAttributes["name"]] = relfieldElement.XmlAttributes["value"];
													}
												}
												// /Loop through relfield elements
											}
											rowdata[fieldElement.XmlAttributes["name"]] = StructNew();
											rowdata[fieldElement.XmlAttributes["name"]]["reltable"] = fieldElement.XmlAttributes["reltable"];
											rowdata[fieldElement.XmlAttributes["name"]]["relfield"] = fieldElement.XmlAttributes["relfield"];
											rowdata[fieldElement.XmlAttributes["name"]]["reldata"] = reldata;
										}
									}
									// /If this field has a name
								}
								// /Make sure this element is a field
							}
							// /Loop through field tags
						}
						// /Loop through field tags
						ArrayAppend(stcData[table], rowdata);
					}
					// /Make sure this element is a row
				}
				// /Loop through rows
			}
		}
		// /Loop through data elements
		if ( Len(tables) ) {
			//  Loop through tables
			for ( i=1; i LTE ArrayLen(arrData); i=i+1 ) {
			//for ( i=1; i LTE ListLen(tables); i=i+1 ) {
				//table = ListGetAt(tables,i);
				table = arrData[i].XmlAttributes["table"];
				checkFields = "";
				onexists = "skip";
				if ( StructKeyExists(arrData[i].XmlAttributes,"checkFields") ) {
					checkFields = arrData[i].XmlAttributes["checkFields"];
				}
				if ( StructKeyExists(arrData[i].XmlAttributes,"onexists") AND arrData[i].XmlAttributes["onexists"] EQ "update" ) {
					onexists = "update";
				}
				qRecords = getPreSeedRecords(table);
				//  If table has seed records
				if ( ( StructKeyExists(stcData,table) AND ArrayLen(stcData[table]) ) AND ( arrData[i].XmlAttributes["permanentRows"] OR NOT qRecords.NumRecords ) ) {
					//  Loop through seed records
					for ( j=1; j LTE ArrayLen(stcData[table]); j=j+1 ) {
						data = StructNew();
						//  Loop through fields in table
						for ( col in stcData[table][j] ) {
							//  Simple val?
							if ( isSimpleValue(stcData[table][j][col]) ) {
								data[col] = stcData[table][j][col];
							} else {
								//  Struct?
								if ( isStruct(stcData[table][j][col]) ) {
									//  Get record of related data
									qRecord = getRecords(stcData[table][j][col]["reltable"],stcData[table][j][col]["reldata"]);
									if ( qRecord.RecordCount EQ 1 AND ListFindNoCase(qRecord.ColumnList,stcData[table][j][col]["relfield"]) ) {
										data[col] = qRecord[stcData[table][j][col]["relfield"]][1];
									}
								}
								// /Struct?
							}
							// /Simple val?
						}
						// /Loop through fields in table
						if ( StructCount(data) ) {
							seedRecord(table,data,onexists,checkFields);
						}
					}
					// /Loop through seed records
				}
				//  If table has seed records
			}
			// /Loop through tables
		}
	}
}

private void function seedIndex(
	required string indexname,
	required string tablename,
	required string fields,
	required boolean unique=false,
	required boolean clustered=false
) {
	var UniqueSQL = "";
	var ClusteredSQL = "";

	if ( unique ) {
		UniqueSQL = " unique";
	}
	if ( clustered ) {
		ClusteredSQL = " CLUSTERED";
	}

	if ( NOT hasIndex(arguments.tablename,arguments.indexname) ) {
		runSQL("CREATE#UniqueSQL##ClusteredSQL# INDEX #escape(arguments.indexname)# ON #escape(arguments.tablename)# (#arguments.fields#)");
	}
}

/**
* @xmldata XML data of tables to load into DataMgr follows. Schema: http://www.bryantwebconsulting.com/cfc/DataMgr.xsd
*/
private void function seedIndexes(
	required any xmldata
) {
	var varXML = arguments.xmldata;
	var aIndexes = XmlSearch(varXML, "//index");
	var ii = 0;
	var sIndex = 0;

	for ( ii = 1; ii LTE ArrayLen(aIndexes); ii=ii+1 ) {
		if ( StructKeyExists(aIndexes[ii],"XmlAttributes") AND StructKeyExists(aIndexes[ii].XmlAttributes,"indexname") AND StructKeyExists(aIndexes[ii].XmlAttributes,"fields") ) {
			sIndex = aIndexes[ii].XmlAttributes;
			if ( StructKeyExists(aIndexes[ii].XmlAttributes,"table") ) {
				sIndex["tablename"] = aIndexes[ii].XmlAttributes.table;
			} else {
				if ( aIndexes[ii].XmlParent.XmlName EQ "indexes" AND StructKeyExists(aIndexes[ii].XmlParent.XmlAttributes,"table") ) {
					sIndex["tablename"] = aIndexes[ii].XmlParent.XmlAttributes["table"];
				}
				if ( aIndexes[ii].XmlParent.XmlName EQ "table" AND StructKeyExists(aIndexes[ii].XmlParent.XmlAttributes,"name") ) {
					sIndex["tablename"] = aIndexes[ii].XmlParent.XmlAttributes["name"];
				}
			}
			seedIndex(argumentCollection=sIndex);
		}
	}
}

public boolean function hasConstraint(
	required string tablename,
	required string ftable
) {
	return false;
}

public boolean function hasIndex(
	required string tablename,
	required string indexname
) {
	return false;
}

/**
* @tablename The table on which to update data.
* @data A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.
* @OnExists The action to take if a record with the given values exists. Possible values: insert (inserts another record), error (throws an error), update (updates the matching record), skip (performs no action).
* @checkFields The fields to check for a matching record.
*/
private string function seedRecord(
	required string tablename,
	required struct data,
	required string OnExists="insert",
	required string checkFields=""
) {
	var result = 0;
	var key = 0;
	var sArgs = {};
	var qRecord = 0;

	if ( Len(arguments.checkFields) ) {
		//  Compile data for get
		for ( key in arguments.data ) {
			if ( ListFindNoCase(arguments.checkFields,key) ) {
				sArgs[key] = arguments.data[key];
			}
		}
		qRecord = getRecords(arguments.tablename,sArgs);
		if ( qRecord.RecordCount ) {
			if ( arguments.OnExists EQ "update" ) {
				StructAppend(sArgs,QueryRowToStruct(qRecord),"no");
				StructAppend(sArgs,arguments.data,"yes");
				result = updateRecord(arguments.tablename,sArgs);
			}
		} else {
			result = insertRecord(argumentCollection=arguments);
		}
	} else {
		result = insertRecord(argumentCollection=arguments);
	}

	return result;
}

/**
* I return a structure for use in runSQLArray (I make a value key in the structure with the appropriate value).
*/
private struct function skey(
	required string name,
	required string val
) {
	var result = {};

	result[arguments.name] = arguments.val;

	return result;
}

private struct function StructFromArgs() {
	var sTemp = 0;
	var sResult = {};
	var key = "";

	if ( StructCount(arguments) EQ 1 AND isStruct(arguments[1]) ) {
		sTemp = arguments[1];
	} else {
		sTemp = arguments;
	}

	//  set all arguments into the return struct
	for ( key in sTemp ) {
		if ( StructKeyExists(sTemp,key) ) {
			sResult[key] = sTemp[key];
		}
	}

	return sResult;
}

/**
* I check to see if the given key of the given structure exists and has a value with any length.
*/
private boolean function StructKeyHasLen(
	required struct Struct,
	required string Key
) {
	var result = false;

	if ( StructKeyExists(arguments.Struct,arguments.Key) AND isSimpleValue(arguments.Struct[arguments.Key]) AND Len(arguments.Struct[arguments.Key]) ) {
		result = true;
	}

	return result;
}

/**
* I return a structure for use in runSQLArray (I make a value key in the structure with the appropriate value).
*/
private struct function sval(
	required struct struct,
	required any val
) {
	var currval = DMDuplicate(arguments.val);
	var sResult = DMDuplicate(arguments.struct);

	if ( IsSimpleValue(val) ) {
		sResult.value = currval;
	} else if ( IsStruct(currval) AND StructKeyExists(sResult,"ColumnName") AND StructKeyExists(currval,sResult.ColumnName) ) {
		sResult.value = val[struct.ColumnName];
	} else if ( IsQuery(currval) AND StructKeyExists(sResult,"ColumnName") AND ListFindNoCase(currval.ColumnList,sResult.ColumnName) ) {
		sResult.value = currval[sResult.ColumnName][1];
	} else {
		throwDMError("Unable to add data to structure for #sResult.ColumnName#");
	}

	if (
			IsBoolean(sResult.value)
		AND	(
					( StructKeyExists(sResult,"CF_Datatype") AND sResult.CF_Datatype EQ "CF_SQL_BIT" )
				OR	( StructKeyExists(sResult,"Relation") AND isStruct(sResult.Relation) AND sResult.Relation.CF_Datatype EQ "CF_SQL_BIT" )
			)
	) {
		sResult.value = getBooleanSqlValue(sResult.value);
	}

	return sResult;
}

private void function throwDMError(
	required string message,
	required string errorcode="",
	required string detail="",
	required string extendedinfo=""
) {
	throw(message=message,errorcode=errorcode,detail=detail,type="DataMgr",extendedinfo=extendedinfo);
}

public void function updateFromOldField(
	required string tablename,
	required string NewField,
	required string OldField
) {
	var sql = "";
	var sData = {};
	var qRecords = 0;
	var pklist = "";
	var key = "";
	var numTotalRecords = 0;
	var numEmptyNewField = 0;

	if ( NOT (StructKeyExists(arguments, "dbfields") AND Len(arguments.dbfields)) ) {
		arguments.dbfields = getDBFieldList(arguments.tablename);
	}

	if ( NOT (StructKeyExists(arguments, "fields") AND Len(arguments.fields)) ) {
		arguments.fields = getFieldList(arguments.tablename);
	}

	if ( ListFindNoCase(arguments.dbfields, arguments.NewField) AND ListFindNoCase(arguments.dbfields, arguments.OldField) ) {
		sql = "UPDATE " & escape(variables.prefix & arguments.tablename) & " SET " & escape(arguments.NewField) & " = " & escape(arguments.OldField) & " WHERE " & escape(arguments.NewField) & " IS NULL";
		runSQL(sql);
	} else if ( ListFindNoCase(arguments.fields, arguments.NewField) AND ListFindNoCase(arguments.fields, arguments.OldField) ) {
		pklist = getPrimaryKeyFieldNames(arguments.tablename);
		sData[arguments.NewField] = "";

		numTotalRecords = numRecords(tablename=arguments.tablename);
		try {
			numEmptyNewField = numRecords(tablename=arguments.tablename, data=sData);
		} catch (any e) {
			// If the field doesn't exist, numEmptyNewField will be 0.
			numEmptyNewField = 0;
		}
		

		// Make sure all records have no value for new field (which is to say, new field doesn't have a value for any record yet ) - Makes function idempotent
		if ( numTotalRecords EQ numEmptyNewField ) {
			qRecords = getRecords(tablename=arguments.tablename, data=StructCopy(sData), fieldlist=ListAppend(pklist, arguments.OldField));

			if ( ListFindNoCase(qRecords.ColumnList, arguments.OldField) ) {
				for ( var i = 1; i <= qRecords.RecordCount; i++ ) {
					sData = {};
					for ( key in ListToArray(pklist) ) {
						sData[key] = qRecords[key][i];
					}
					sData[arguments.NewField] = qRecords[arguments.OldField][i];
					updateRecord(tablename=arguments.tablename, data=StructCopy(sData));
				}
			}
		}
	}
}

/**
* I check to see if the given field should be used in the SQL statement.
*/
private boolean function useField(
	required struct Struct,
	required struct Field
) {
	var result = false;

	if (
			StructKeyHasLen(Struct, Field.ColumnName)
		AND	(
					isOfCFType(Struct[Field.ColumnName], getEffectiveFieldDataType(Field, true))
				OR	(
							StructKeyExists(Field, "Relation")
						AND	StructKeyExists(Field.Relation, "type")
						AND	Field.Relation.type EQ "list"
					)
			)
	) {
		result = true;
	}

	return result;
}

/*
Returns specific number of records starting with a specific row.
Renamed by RCamden
Version 2 with column name support by Christopher Bradford, christopher.bradford@aliveonline.com

@param theQuery      The query to work with. (Required)
@param StartRow      The row to start on. (Required)
@param NumberOfRows      The number of rows to return. (Required)
@param ColumnList      List of columns to return. Defaults to all the columns. (Optional)
@return Returns a query.
@author Kevin Bridges (christopher.bradford@aliveonline.comcyberswat@orlandoartistry.com)
@version 2, May 23, 2005
*/
private query function QuerySliceAndDice(
	required query theQuery,
	required numeric StartRow,
	required numeric NumberOfRows,
	string ColumnList=""
) {
	var FinalQuery = "";
	var EndRow = StartRow + NumberOfRows;
	var counter = 1;
	var x = "";
	var y = "";

	if ( Len(arguments.ColumnList) EQ 0 ) {
		arguments.ColumnList = theQuery.ColumnList;
	}
	FinalQuery = QueryNew(arguments.ColumnList);

	if ( EndRow GT theQuery.recordcount ) {
		EndRow = theQuery.recordcount + 1;
	}

	QueryAddRow(FinalQuery, EndRow - StartRow);

	for ( x = 1; x LTE theQuery.recordcount; x = x + 1 ) {
		if ( x GTE StartRow AND x LT EndRow ) {
			for ( y = 1; y LTE ListLen(arguments.ColumnList); y = y + 1 ) {
				QuerySetCell(FinalQuery, ListGetAt(arguments.ColumnList, y), theQuery[ListGetAt(arguments.ColumnList, y)][x], counter);
			}
			counter = counter + 1;
		}
	}

	return FinalQuery;
}


/**
 * Makes a row of a query into a structure.
 *
 * @param query 	 The query to work with.
 * @param row 	 Row number to check. Defaults to row 1.
 * @return Returns a structure.
 * @author Nathan Dintenfass (nathan@changemedia.com)
 * @version 1, December 11, 2001
 */
function queryRowToStruct(query){
	//by default, do this to the first row of the query
	var row = 1;
	//a var for looping
	var ii = 1;
	//the cols to loop over
	var cols = listToArray(query.columnList);
	//the struct to return
	var sReturn = {};
	//if there is a second argument, use that for the row number
	if ( ArrayLen(arguments) GT 1 ) {
		row = arguments[2];
	}
	//loop over the cols and build the struct from the query row
	for ( ii = 1; ii LTE arraylen(cols); ii = ii + 1 ){
		sReturn[cols[ii]] = query[cols[ii]][row];
	}
	//return the struct
	return sReturn;
}
</cfscript>

<cffunction name="getDatabaseXml" access="public" returntype="string" output="no" hint="I return the XML for the given table or for all tables in the database.">
	<cfargument name="indexes" type="boolean" default="false">

	<cfset var tables = getDatabaseTables()>
	<cfset var table = "">
	<cfset var result = "">
	<cfset var aFields = 0>
	<cfset var sField = 0>
	<cfset var qIndexes = 0>
	<cfset var ii = 0>

<cfsavecontent variable="result"><cfoutput>
<tables><cfloop list="#tables#" index="table"><cfset aFields = getDBTableStruct(table)>
	<table name="#table#"><cfloop index="ii" from="1" to="#ArrayLen(aFields)#" step="1"><cfset sField = aFields[ii]>
		<field ColumnName="#sField.ColumnName#" CF_DataType="#sField.CF_DataType#"<cfif StructKeyExists(sField,"PrimaryKey") AND sField.PrimaryKey IS true> PrimaryKey="true"</cfif><cfif StructKeyExists(sField,"Increment") AND sField.Increment IS true> Increment="true"</cfif><cfif StructKeyExists(sField,"Length") AND isNumeric(sField.Length) AND sField.Length GT 0> Length="#Int(sField.Length)#"</cfif><cfif StructKeyExists(sField,"Default") AND Len(sField.Default)> Default="#sField.Default#"</cfif><cfif StructKeyExists(sField,"Precision") AND isNumeric(sField["Precision"])> Precision="#sField["Precision"]#"</cfif><cfif StructKeyExists(sField,"Scale") AND isNumeric(sField["Scale"])> Scale="#sField["Scale"]#"</cfif> AllowNulls="#sField["AllowNulls"]#" /></cfloop><cfif arguments.indexes AND isDefined("getDBTableIndexes")><cfset qIndexes = getDBTableIndexes(tablename=table)><cfloop query="qIndexes">
		<index indexname="#indexname#" fields="#fields#"<cfif isBoolean(unique) AND unique> unique="true"</cfif><cfif isBoolean(clustered) AND clustered> clustered="true"</cfif> /></cfloop></cfif>
	</table></cfloop>
</tables>
</cfoutput></cfsavecontent>

	<cfreturn result>
</cffunction>

<cffunction name="getXML" access="public" returntype="string" output="no" hint="I return the XML for the given table or for all loaded tables if none given.">
	<cfargument name="tablename" type="string" required="no">
	<cfargument name="indexes" type="boolean" default="false">
	<cfargument name="showroot" type="boolean" default="true">

	<cfset var result = "">

	<cfset var table = "">
	<cfset var i = 0>
	<cfset var rAtts = "table,type,field,join-table,join-field,join-field-local,join-field-remote,fields,delimiter,onDelete,onMissing">
	<cfset var rKey = "">
	<cfset var sTables = 0>
	<cfset var qIndexes = 0>

	<cfif StructKeyExists(arguments,"tablename")>
		<cfset checkTable(arguments.tablename)><!--- Check whether table is loaded --->
	</cfif>

	<cfinvoke method="getTableData" returnvariable="sTables">
		<cfif StructKeyExists(arguments,"tablename") AND Len(arguments.tablename)>
			<cfinvokeargument name="tablename" value="#arguments.tablename#">
		</cfif>
	</cfinvoke>

<cfsavecontent variable="result"><cfoutput>
<cfif arguments.showroot><tables></cfif><cfloop collection="#sTables#" item="table">
	<table name="#table#"><cfloop index="i" from="1" to="#ArrayLen(sTables[table])#" step="1"><cfif StructKeyExists(sTables[table][i],"CF_DataType")>
		<field ColumnName="#sTables[table][i].ColumnName#"<cfif StructKeyHasLen(sTables[table][i],"alias")> alias="#sTables[table][i].alias#"</cfif> CF_DataType="#sTables[table][i].CF_DataType#"<cfif StructKeyExists(sTables[table][i],"PrimaryKey") AND isBoolean(sTables[table][i].PrimaryKey) AND sTables[table][i].PrimaryKey> PrimaryKey="true"</cfif><cfif StructKeyExists(sTables[table][i],"Increment") AND isBoolean(sTables[table][i].Increment) AND sTables[table][i].Increment> Increment="true"</cfif><cfif StructKeyExists(sTables[table][i],"Length") AND isNumeric(sTables[table][i].Length) AND sTables[table][i].Length GT 0> Length="#Int(sTables[table][i].Length)#"</cfif><cfif StructKeyHasLen(sTables[table][i],"Default")> Default="#sTables[table][i].Default#"</cfif><cfif StructKeyExists(sTables[table][i],"Precision") AND isNumeric(sTables[table][i]["Precision"])> Precision="#sTables[table][i]["Precision"]#"</cfif><cfif StructKeyExists(sTables[table][i],"Scale") AND isNumeric(sTables[table][i]["Scale"])> Scale="#sTables[table][i]["Scale"]#"</cfif> AllowNulls="#sTables[table][i]["AllowNulls"]#"<cfif StructKeyHasLen(sTables[table][i],"Special")> Special="#sTables[table][i]["Special"]#"</cfif><cfif StructKeyHasLen(sTables[table][i],"ftable")> ftable="#sTables[table][i]["ftable"]#"</cfif> /><cfelseif StructKeyExists(sTables[table][i],"Relation")>
		<field ColumnName="#sTables[table][i].ColumnName#">
			<relation<cfloop index="rKey" list="#rAtts#"><cfif StructKeyExists(sTables[table][i].Relation,rKey) AND isSimpleValue(sTables[table][i].Relation[rKey])> #rKey#="#XmlFormat(sTables[table][i].Relation[rKey])#"</cfif></cfloop><cfloop collection="#sTables[table][i].Relation#" item="rKey"><cfif isSimpleValue(sTables[table][i].Relation[rKey]) AND NOT ListFindNoCase(rAtts,rKey)> #LCase(rKey)#="#XmlFormat(sTables[table][i].Relation[rKey])#"</cfif></cfloop> />
		</field></cfif></cfloop><cfif arguments.indexes AND isDefined("getDBTableIndexes")><cfset qIndexes = getDBTableIndexes(tablename=table)><cfloop query="qIndexes">
		<index indexname="#indexname#" fields="#fields#"<cfif isBoolean(unique) AND unique> unique="true"</cfif><cfif isBoolean(clustered) AND clustered> clustered="true"</cfif> /></cfloop></cfif><cfif StructCount(variables.tableprops[table]["filters"])><cfloop collection="#variables.tableprops[table].filters#" item="i">
		<filter name="#i#" field="#variables.tableprops[table].filters[i].field#" operator="#XmlFormat(variables.tableprops[table].filters[i].operator)#" /></cfloop></cfif>
	</table></cfloop><cfif arguments.showroot>
</tables></cfif>
</cfoutput></cfsavecontent>

	<cfreturn result>
</cffunction>

<cffunction name="da" access="private"><cfdump var="#arguments#"><cfabort></cffunction>
</cfcomponent>
