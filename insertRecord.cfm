<cffunction name="insertRecord" access="public" returntype="string" output="no" hint="I insert a record into the given table with the provided data and do my best to return the primary key of the inserted record.">
	<cfargument name="tablename" type="string" required="yes" hint="The table in which to insert data.">
	<cfargument name="data" type="struct" required="yes" hint="A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.">
	<cfargument name="OnExists" type="string" default="insert" hint="The action to take if a record with the given values exists. Possible values: insert (inserts another record), error (throws an error), update (updates the matching record), skip (performs no action), save (updates only for matching primary key)).">
	
	<cfset var fields = getUpdateableFields(arguments.tablename)>
	<cfset var OnExistsValues = "insert,error,update,skip"><!--- possible values for OnExists argument --->
	<cfset var i = 0><!--- generic counter --->
	<cfset var fieldcount = 0><!--- count of fields --->
	<cfset var pkfields = getPKFields(arguments.tablename)>
	<cfset var in = clean(arguments.data)><!--- holder for incoming data (just for readability) --->
	<cfset var inPK = StructNew()><!--- holder for incoming pk data (just for readability) --->
	<cfset var qGetRecords = QueryNew('none')>
	<cfset var result = ""><!--- will hold primary key --->
	<cfset var qCheckKey = 0><!--- Used to get primary key --->
	<cfset var bSetGuid = false><!--- Set GUID (SQL Server specific) --->
	<cfset var bGetNewSeqId = false><!--- Alternate set GUID approach for newsequentialid() support (SQL Server specific) --->
	<cfset var GuidVar = "GUID"><!--- var to create variable name for GUID (SQL Server specific) --->
	<cfset var inf = "">
	<cfset var sqlarray = ArrayNew(1)>
	
	<cfset in = getRelationValues(arguments.tablename,in)>
	
	<!--- Create GUID for insert SQL Server where the table has on primary key field and it is a GUID --->
	<cfif ArrayLen(pkfields) EQ 1 AND pkfields[1].CF_Datatype EQ "CF_SQL_IDSTAMP" AND getDatabase() EQ "MS SQL" AND NOT StructKeyExists(in,pkfields[1].ColumnName)>
		<cfif StructKeyExists(pkfields[1], "default") and pkfields[1].Default contains "newsequentialid">
			<cfset bGetNewSeqId = true>
		<cfelse>
			<cfset bSetGuid = true>
		</cfif>
	</cfif>
	
	<!--- Create variable to hold GUID for SQL Server GUID inserts --->
	<cfif bSetGuid OR bGetNewSeqId>
		<cflock timeout="30" throwontimeout="No" name="DataMgr_GuidNum" type="EXCLUSIVE">
			<!--- %%I cant figure out a way to safely increment the variable to make it unique for a transaction w/0 the use of request scope --->
			<cfif isDefined("request.DataMgr_GuidNum")>
				<cfset request.DataMgr_GuidNum = Val(request.DataMgr_GuidNum) + 1>
			<cfelse>
				<cfset request.DataMgr_GuidNum = 1>
			</cfif>
			<cfset GuidVar = "GUID#request.DataMgr_GuidNum#">
		</cflock>
	</cfif>
	
	<!--- Check for existing records if an action other than insert should be take if one exists --->
	<cfif arguments.OnExists NEQ "insert">
		<cfif ArrayLen(pkfields)>
			<!--- Load up all primary key fields in temp structure --->
			<cfloop index="i" from="1" to="#ArrayLen(pkfields)#" step="1">
				<cfif StructKeyHasLen(in,pkfields[i].ColumnName)>
					<cfset inPK[pkfields[i].ColumnName] = in[pkfields[i].ColumnName]>
				</cfif>
			</cfloop>
		</cfif>
		
		<!--- Try to get existing record with given data --->
		<cfif arguments.OnExists NEQ "save">
				<!--- Use only pkfields if all are passed in, otherwise use all data available --->
				<cfif ArrayLen(pkfields)>
					<cfif StructCount(inPK) EQ ArrayLen(pkfields)>
						<!--- <cflock name="DataMgr_InsertCheck_#arguments.tablename#" timeout="30"> --->
							<cfset qGetRecords = getRecords(tablename=arguments.tablename,data=inPK,fieldlist=StructKeyList(inPK))>
						<!--- </cflock> --->
					<cfelse>
						<!--- <cflock name="DataMgr_InsertCheck_#arguments.tablename#" timeout="30"> --->
							<cfset qGetRecords = getRecords(tablename=arguments.tablename,data=in,fieldlist=StructKeyList(inPK))>
						<!--- </cflock> --->
					</cfif>
				<cfelse>
					<!--- <cflock name="DataMgr_InsertCheck_#arguments.tablename#" timeout="30"> --->
						<cfset qGetRecords = getRecords(tablename=arguments.tablename,data=in,fieldlist=StructKeyList(in))>
					<!--- </cflock> --->
				</cfif>
		</cfif>
		
		<!--- If no matching records by all fields, Check for existing record by primary keys --->
		<cfif arguments.OnExists EQ "save" OR qGetRecords.RecordCount EQ 0>
			<cfif ArrayLen(pkfields)>
				<!--- All all primary key fields exist, check for record --->
				<cfif StructCount(inPK) EQ ArrayLen(pkfields)>
					<cfset qGetRecords = getRecord(tablename=arguments.tablename,data=inPK,fieldlist=StructKeyList(inPK))>
				</cfif>
			</cfif>
		</cfif>
	</cfif>
	
	<!--- Check for existing records --->
	<cfif qGetRecords.RecordCount GT 0>
		<cfswitch expression="#arguments.OnExists#">
		<cfcase value="error">
			<cfthrow message="#arguments.tablename#: A record with these criteria already exists." type="DataMgr">
		</cfcase>
		<cfcase value="update,save">
			<cfloop index="i" from="1" to="#ArrayLen(pkfields)#" step="1">
				<cfset in[pkfields[i].ColumnName] = qGetRecords[pkfields[i].ColumnName][1]>
			</cfloop>
			<cfset result = updateRecord(arguments.tablename,in)>
			<cfreturn result>
		</cfcase>
		<cfcase value="skip">
			<cfif ArrayLen(pkfields)>
				<cfreturn qGetRecords[pkfields[1].ColumnName][1]>
			<cfelse>
				<cfreturn 0>
			</cfif>
		</cfcase>
		</cfswitch>
	</cfif>
	
	<!--- Check for specials --->
	<cfloop index="i" from="1" to="#ArrayLen(fields)#" step="1">
		<cfif StructKeyExists(fields[i],"Special") AND Len(fields[i].Special) AND NOT StructKeyExists(in,fields[i].ColumnName)>
			<!--- Set fields based on specials --->
			<!--- CreationDate has db default as of 2.2, but won't if fields were created earlier (or if no real db) --->
			<cfswitch expression="#fields[i].Special#">
			<cfcase value="CreationDate">
				<cfset in[fields[i].ColumnName] = now()>
			</cfcase>
			<cfcase value="LastUpdatedDate">
				<cfset in[fields[i].ColumnName] = now()>
			</cfcase>
			<cfcase value="Sorter">
				<cfset in[fields[i].ColumnName] = getNewSortNum(arguments.tablename,fields[i].ColumnName)>
			</cfcase>
			</cfswitch>
		</cfif>
	</cfloop>
	
	<!--- Insert record --->
	<cfif bSetGuid>
		<cfset ArrayAppend(sqlarray,"DECLARE @#GuidVar# uniqueidentifier")>
		<cfset ArrayAppend(sqlarray,"SET @#GuidVar# = NEWID()")>
	<cfelseif bGetNewSeqId>
		<cfset ArrayAppend(sqlarray, "DECLARE @#GuidVar# TABLE (inserted_guid uniqueidentifier);")>
	</cfif>
	<cfset ArrayAppend(sqlarray,"INSERT INTO #escape(arguments.tablename)# (")>
	
	<!--- Loop through all updateable fields --->
	<cfloop index="ii" from="1" to="#ArrayLen(fields)#" step="1">
		<cfif
				( useField(in,fields[ii]) OR (StructKeyExists(fields[ii],"Default") AND Len(fields[ii].Default) AND getDatabase() EQ "Access") )
			OR	NOT ( useField(in,fields[ii]) OR StructKeyExists(fields[ii],"Default") OR fields[ii].AllowNulls )
			OR	( StructKeyExists(fields[ii],"Special") AND Len(fields[ii].Special) AND ListFindNoCase(Specials,fields[ii]["Special"]) ) 
		><!--- Include the field in SQL if it has appropriate data --->
			<cfset fieldcount = fieldcount + 1>
			<cfif fieldcount GT 1>
				<cfset ArrayAppend(sqlarray,",")><!--- put a comma before every field after the first --->
			</cfif>
			<cfset ArrayAppend(sqlarray,escape(fields[ii].ColumnName))>
		</cfif>
	</cfloop>
	<cfloop index="ii" from="1" to="#ArrayLen(pkfields)#" step="1">
		<cfif ( useField(in,pkfields[ii]) AND NOT isIdentityField(pkfields[ii]) ) OR ( pkfields[ii].CF_Datatype EQ "CF_SQL_IDSTAMP" AND bSetGuid )><!--- Include the field in SQL if it has appropriate data --->
			<cfset fieldcount = fieldcount + 1>
			<cfif fieldcount GT 1>
				<cfset ArrayAppend(sqlarray,",")><!--- put a comma before every field after the first --->
			</cfif>
			<cfset ArrayAppend(sqlarray,"#escape(pkfields[ii].ColumnName)#")>
		</cfif>
	</cfloop>
	<cfset ArrayAppend(sqlarray,")")>
	<cfif bGetNewSeqId>
		<cfset ArrayAppend(sqlarray, "OUTPUT INSERTED.#escape(pkfields[1].ColumnName)# INTO @#GuidVar#")>
	</cfif>
	<cfif bUseSubquery>
		<cfset ArrayAppend(sqlarray,"SELECT ")>
	<cfelse>
		<cfset ArrayAppend(sqlarray,"VALUES (")>
	</cfif>
	<cfset fieldcount = 0>
	<!--- Loop through all updateable fields --->
	<cfloop index="ii" from="1" to="#ArrayLen(fields)#" step="1">
		<cfif useField(in,fields[ii])><!--- Include the field in SQL if it has appropriate data --->
			<cfset checkLength(fields[ii],in[fields[ii].ColumnName])>
			<cfset fieldcount = fieldcount + 1>
			<cfif fieldcount GT 1>
				<cfset ArrayAppend(sqlarray,",")><!--- put a comma before every field after the first --->
			</cfif>
			<cfset ArrayAppend(sqlarray,sval(fields[ii],in))>
		<cfelseif StructKeyExists(fields[ii],"Special") AND Len(fields[ii].Special) AND ListFindNoCase(Specials,fields[ii]["Special"])>
			<!--- Set fields based on specials --->
			<cfset fieldcount = fieldcount + 1>
			<cfif fieldcount GT 1>
				<cfset ArrayAppend(sqlarray,",")><!--- put a comma before every field after the first --->
			</cfif>
			<cfswitch expression="#fields[ii].Special#">
			<cfcase value="CreationDate">
				<cfset ArrayAppend(sqlarray,getNowSQL())>
			</cfcase>
			<cfcase value="LastUpdatedDate">
				<cfset ArrayAppend(sqlarray,getNowSQL())>
			</cfcase>
			<cfcase value="Sorter">
				<cfset ArrayAppend(sqlarray,getNewSortNum(arguments.tablename,fields[ii].ColumnName))>
			</cfcase>
			</cfswitch>
		<cfelseif StructKeyExists(fields[ii],"Default") AND Len(fields[ii].Default) AND getDatabase() EQ "Access">
			<cfset fieldcount = fieldcount + 1>
			<cfif fieldcount GT 1>
				<cfset ArrayAppend(sqlarray,",")><!--- put a comma before every field after the first --->
			</cfif>
			<cfset ArrayAppend(sqlarray,fields[ii].Default)>
		<cfelseif NOT ( useField(in,fields[ii]) OR StructKeyExists(fields[ii],"Default") OR fields[ii].AllowNulls )>
			<cfset fieldcount = fieldcount + 1>
			<cfif fieldcount GT 1>
				<cfset ArrayAppend(sqlarray,",")><!--- put a comma before every field after the first --->
			</cfif>
			<cfset ArrayAppend(sqlarray,"''")>
		</cfif>
	</cfloop>
	<cfloop index="ii" from="1" to="#ArrayLen(pkfields)#" step="1">
		<cfif useField(in,pkfields[ii]) AND NOT isIdentityField(pkfields[ii])><!--- Include the field in SQL if it has appropriate data --->
			<cfset checkLength(pkfields[ii],in[pkfields[ii].ColumnName])>
			<cfset fieldcount = fieldcount + 1>
			<cfif fieldcount GT 1>
				<cfset ArrayAppend(sqlarray,",")><!--- put a comma before every field after the first --->
			</cfif>
			<cfset ArrayAppend(sqlarray,sval(pkfields[ii],in))>
		<cfelseif pkfields[ii].CF_Datatype EQ "CF_SQL_IDSTAMP" AND bSetGuid>
			<cfset fieldcount = fieldcount + 1>
			<cfif fieldcount GT 1>
				<cfset ArrayAppend(sqlarray,",")><!--- put a comma before every field after the first --->
			</cfif>
			<cfset ArrayAppend(sqlarray,"@#GuidVar#")>
		</cfif>
	</cfloop><cfif fieldcount EQ 0><cfsavecontent variable="inf"><cfdump var="#in#"></cfsavecontent><cfthrow message="You must pass in at least one field that can be inserted into the database. Fields: #inf#" type="DataMgr" errorcode="NeedInsertFields"></cfif>
	<cfif bUseSubquery>
		<cfset ArrayAppend(sqlarray,"WHERE NOT EXISTS (")>
			<cfset ArrayAppend(sqlarray,"SELECT 1")>
			<cfset ArrayAppend(sqlarray,"FROM #escape(arguments.tablename)#")>
			<cfset ArrayAppend(sqlarray,"WHERE 1 = 1")>
			<cfset ArrayAppend(sqlarray,getWhereSQL(tablename=arguments.tablename,data=arguments.data_where,filters=arguments.filters))>
		<cfset ArrayAppend(sqlarray,")")>
	<cfelse>
		<cfset ArrayAppend(sqlarray,")")>
	</cfif>
	<cfif bSetGuid>
		<cfset ArrayAppend(sqlarray,";")>
		<cfset ArrayAppend(sqlarray,"SELECT @#GuidVar# AS NewID")>
	<cfelseif bGetNewSeqId>
		<cfset ArrayAppend(sqlarray,";")>
		<cfset ArrayAppend(sqlarray, "SELECT inserted_guid AS NewID FROM @#GuidVar#;")>
	</cfif>
	<!--- Perform insert --->
	<!--- <cflock timeout="30" throwontimeout="Yes" name="DataMgr_Insert_#arguments.tablename#" type="EXCLUSIVE"> --->
		<cfset qCheckKey = runSQLArray(sqlarray)>
	<!--- </cflock> --->
	
	<cfif isDefined("qCheckKey") AND isQuery(qCheckKey) AND qCheckKey.RecordCount AND ListFindNoCase(qCheckKey.ColumnList,"NewID")>
		<cfset result = qCheckKey.NewID>
	</cfif>
	
	<!--- Get primary key --->
	<cfif Len(result) EQ 0>
		<cfif ArrayLen(pkfields) AND StructKeyExists(in,pkfields[1].ColumnName) AND useField(in,pkfields[1]) AND NOT isIdentityField(pkfields[1])>
			<cfset result = in[pkfields[1].ColumnName]>
		<cfelseif ArrayLen(pkfields) AND StructKeyExists(pkfields[1],"Increment") AND isBoolean(pkfields[1].Increment) AND pkfields[1].Increment>
			<cfset result = getInsertedIdentity(arguments.tablename,pkfields[1].ColumnName)>
		<cfelse>
			<cftry>
				<cfset result = getPKFromData(arguments.tablename,in)>
				<cfcatch>
					<cfset result = "">
				</cfcatch>
			</cftry>
		</cfif>
	</cfif>
	
	<!--- set pkfield so that we can save relation data --->
	<cfif ArrayLen(pkfields)>
		<cfset in[pkfields[1].ColumnName] = result>
		<cfset saveRelations(arguments.tablename,in,pkfields[1],result)>
	</cfif>
	
	<!--- Log insert --->
	<cfif variables.doLogging AND NOT arguments.tablename EQ variables.logtable>
		<cfinvoke method="logAction">
			<cfinvokeargument name="tablename" value="#arguments.tablename#">
			<cfif ArrayLen(pkfields) EQ 1 AND StructKeyExists(in,pkfields[1].ColumnName)>
				<cfinvokeargument name="pkval" value="#in[pkfields[1].ColumnName]#">
			</cfif>
			<cfinvokeargument name="action" value="insert">
			<cfinvokeargument name="data" value="#in#">
			<cfinvokeargument name="sql" value="#sqlarray#">
		</cfinvoke>
	</cfif>
	
	<cfset setCacheDate()>
	
	<cfreturn result>
</cffunction>