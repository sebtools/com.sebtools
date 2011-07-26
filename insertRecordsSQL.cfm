<cffunction name="insertRecordsSQL" access="public" returntype="array" output="false" hint="">
	<cfargument name="tablename" type="string" required="yes">
	<cfargument name="data_set" type="struct" required="yes" hint="A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.">
	<cfargument name="data_where" type="struct" required="no" hint="A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.">
	<cfargument name="filters" type="array" default="#ArrayNew(1)#">
	
	<cfset var bSetGuid = false>
	<cfset var GuidVar = "">
	<cfset var sqlarray = ArrayNew(1)>
	<cfset var ii = 0>
	<cfset var fieldcount = 0>
	<cfset var bUseSubquery = false>
	<cfset var fields = getUpdateableFields(arguments.tablename)>
	<cfset var pkfields = getPKFields(arguments.tablename)>
	<cfset var in = arguments.data_set><!--- holder for incoming data (just for readability) --->
	<cfset var inf = "">
	<cfset var Specials = "CreationDate,LastUpdatedDate,Sorter">
	
	<cfset in = getRelationValues(arguments.tablename,in)>
	
	<!--- Create GUID for insert SQL Server where the table has on primary key field and it is a GUID --->
	<cfif ArrayLen(pkfields) EQ 1 AND pkfields[1].CF_Datatype EQ "CF_SQL_IDSTAMP" AND getDatabase() EQ "MS SQL" AND NOT StructKeyExists(in,pkfields[1].ColumnName)>
		<cfif StructKeyExists(pkfields[1], "default") and pkfields[1].Default contains "newsequentialid">
			<cfset bGetNewSeqId = true>
		<cfelse>
			<cfset bSetGuid = true>
		</cfif>
	</cfif>
	
	<cfif StructKeyExists(arguments,"data_where") AND StructCount(arguments.data_where)>
		<cfset bUseSubquery = true>
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
	
	<cfreturn sqlarray>
</cffunction>