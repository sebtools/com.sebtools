<!---
Query Manager
Build 01
Version 0.1
--->
<cfcomponent displayname="Query Manager" hint="I manage volunteer queries.">

<cffunction name="init" access="public" returntype="QueryMgr" output="no" hint="I instantiate and return this object.">
	<cfargument name="DataMgr" type="any" required="yes">
	
	<cfset variables.DataMgr = arguments.DataMgr>
	<cfset variables.datasource = variables.DataMgr.getDatasource()>
	<cfset variables.DataMgr.loadXML(getDbXml(),true,true)>
	
	<cfreturn this>
</cffunction>

<cffunction name="getChoices" access="public" returntype="struct" output="no" hint="I get all of the choices available for the items with finite options.">
	
	<cfset var qQueries = 0>
	<cfset var qTempQuery = 0>
	<cfset var stcQueries = StructNew()>
	
	<cfquery name="qQueries" datasource="#variables.datasource#">
	SELECT	KeyName,queryTable,queryLabelField,queryValueField,querySQL
	FROM	qmFields
	WHERE	type = 'query'
	</cfquery>
	
	<cfoutput query="qQueries">
		<cfif Len(querySQL)>
			<cftry>
				<cfquery name="qTempQuery" datasource="#variables.datasource#">#PreserveSingleQuotes(querySQL)#</cfquery>
				<cfcatch>
					<cfthrow message="Choices Query Failed:<br>#querySQL#" type="QueryMgr" errorcode="querySQL">
				</cfcatch>
			</cftry>
		<cfelseif Len(queryTable) AND Len(queryLabelField) AND Len(queryValueField)>
			<cfquery name="qTempQuery" datasource="#variables.datasource#">
			SELECT		#queryLabelField# AS Label, #queryValueField# AS Value
			FROM		#queryTable#
			ORDER BY	#queryLabelField#
			</cfquery>
		</cfif>
		<cfset stcQueries[KeyName] = qTempQuery>
	</cfoutput>
	
	<cfreturn stcQueries>
</cffunction>

<cffunction name="getArrayFromForm" access="public" returntype="array" output="no">
	<cfargument name="Form" type="struct" required="yes">
	<cfargument name="numChoices" type="numeric" required="yes">
	
	<cfset var arrSearch = ArrayNew(1)>
	<cfset var qQueries = 0>
	<cfset var querylist = "">
	
	<cfscript>
	//If user selected a saved query, get the criteria
	if ( isDefined("Form.Query") AND Len(Form.Query) ) {
	
		qQueries = Application.QueryMgr.getQueries();
		querylist = ValueList(qQueries.QueryName);
	
		if ( ListFindNoCase(querylist,form.Query) ) {
			arrSearch = Application.QueryMgr.getQuery(Form.Query);
		}
		//form.isApproved = Application.QueryMgr.getApproval(form.Query);
	
	//If user selected criteria, convert criteria to an array for easy use with component
	} else {
		if ( isDefined("Form.isApproved") AND isBoolean(Form.isApproved) ) {
				ArrayAppend(arrSearch,StructNew());
				arrSearch[ArrayLen(arrSearch)]["KeyName"] ="isApproved";
				arrSearch[ArrayLen(arrSearch)].Value = form.isApproved;
		}
		// Loop through choices
		for ( i=1; i lte numChoices; i=i+1 ) {
			//If this choice has been passed with some value
			if ( StructKeyExists(Form,"field#i#") AND Len(Form["field#i#"]) ) {
				ArrayAppend(arrSearch,StructNew());
				arrSearch[ArrayLen(arrSearch)]["KeyName"] = Form["field#i#"];
				arrSearch[ArrayLen(arrSearch)].Value = "";
				if ( StructKeyExists(Form,"value#i#") AND Len(Form["value#i#"]) ) {
					arrSearch[ArrayLen(arrSearch)].Value = Form["value#i#"];
				}
				if ( StructKeyExists(form,"choice#i#") AND Len(Form["choice#i#"]) ) {
					arrSearch[ArrayLen(arrSearch)].Value = Form["choice#i#"];
				}
				//Ditch criterian if it has no value
				if ( Not Len(arrSearch[ArrayLen(arrSearch)].Value) ) {
					ArrayDeleteAt(arrSearch, ArrayLen(arrSearch));
				}
			}// /if
		}// /for
	}// /if
	
	//Optionally save query if a name is entered for that purpose
	if ( StructKeyExists(Form,"queryname") AND Len(Form.queryname) AND ArrayLen(arrSearch) ) {
		Application.QueryMgr.saveQuery(Form.queryname,getExpandedCriteria(arrSearch));
	}
	</cfscript>
	
	<cfreturn arrSearch>
</cffunction>

<cffunction name="getCriterianLabel" access="public" returntype="string" output="no" hint="I get the label for the given criterian.">
	<cfargument name="KeyName" type="string" required="yes">
	
	<cfset var qLabel = 0>
	<cfset var result = "">
	
	<cfquery name="qLabel" datasource="#variables.datasource#">
	SELECT	Label
	FROM	qmFields
	WHERE	KeyName = <cfqueryparam value="#KeyName#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<cfif qLabel.RecordCount>
		<cfset result = qLabel.Label>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getCriterianValue" access="public" returntype="string" output="no" hint="I get the value of the given criterian.">
	<cfargument name="KeyName" type="string" required="yes">
	<cfargument name="CriteriaValue" type="string" required="yes">
	
	<cfset var stcChoices = getChoices()>
	<cfset var myquery = 0>
	<cfset var result = arguments.CriteriaValue>
	
	<cfif StructKeyExists(stcChoices,arguments.KeyName)>
		<cfset myquery = stcChoices[arguments.KeyName]>
		<cfloop query="myquery">
			<cfif Value eq arguments.CriteriaValue>
				<cfset result = Label>
				<cfbreak>
			</cfif>
		</cfloop>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getExpandedCriteria" access="public" returntype="query" output="no" hint="I return the expanded query for the given criteria.">
	<cfargument name="Criteria" type="array" required="yes">
	
	<cfscript>
	var i = 0;
	var qCriteria = QueryNew('KeyName');
	var col = "";
	</cfscript>
	
	<cfscript>
	for ( i=1; i lte ArrayLen(Criteria); i=i+1 ) {
		Criteria[i] = getExpandedCriterian(Criteria[i]);
		if ( i eq 1 ) {
			qCriteria = QueryNew(StructKeyList(Criteria[i]));
			QueryAddRow(qCriteria);
			for ( col in Criteria[1]) {
				QuerySetCell(qCriteria, col, '');
			}
		}
		QueryAddRow(qCriteria);
		for ( col in Criteria[i]) {
			QuerySetCell(qCriteria, col, Criteria[i][col]);
		}
	}
	</cfscript>
	
	<cfreturn qCriteria>
</cffunction>

<cffunction name="getExpandedCriterian" access="public" returntype="struct" output="no" hint="I return a structure of data for the given criterian.">
	<cfargument name="Criterian" type="struct" required="yes">
	
	<cfscript>
	var qFilters = 0;
	</cfscript>
	
	<cfquery name="qFilters" datasource="#variables.datasource#">
	SELECT	FieldID, keyname, jointable, filterfields, filtertype, cfdatatype, ordernum, type
	FROM	qmFields
	WHERE	keyname = <cfqueryparam value="#Criterian.KeyName#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<cfscript>
	Criterian["FieldID"] = qFilters.FieldID;
	Criterian["jointable"] = qFilters.jointable;
	Criterian["FilterFields"] = qFilters.filterfields;
	Criterian["filtertype"] = qFilters.filtertype;
	Criterian["Label"] = getCriterianLabel(Criterian.KeyName);
	if ( qFilters.type eq "boolean" ) {
		Criterian["ValueLabel"] = YesNoFormat(Criterian.Value);
	} else if ( qFilters.type eq "query" ) {
		Criterian["ValueLabel"] = getCriterianValue(Criterian.KeyName,Criterian.Value);
	} else {
		Criterian["ValueLabel"] = Criterian.Value;
	}
	
	Criterian["cfdatatype"] = qFilters.cfdatatype;
	Criterian["ordernum"] = qFilters.ordernum;
	</cfscript>
	
	<cfreturn Criterian>
</cffunction>

<cffunction name="getFields" access="public" returntype="query" output="no" hint="I get all of the query fields.">

	<cfset var qFields = 0>
	
	<cfquery name="qFields" datasource="#variables.datasource#">
	SELECT		*
	FROM		qmFields
	WHERE		ordernum <> 0
	ORDER BY	ordernum
	</cfquery>

	<cfreturn qFields>
</cffunction>

<cffunction name="getQueries" access="public" returntype="query" output="no" hint="I get all of the saved queries.">
	
	<cfset var qQueries = 0>
	
	<cfquery name="qQueries" datasource="#variables.datasource#">
	SELECT		QueryName
	FROM		qmQueries
	ORDER BY	QueryName
	</cfquery>
	
	<cfreturn qQueries>
</cffunction>

<cffunction name="getQuery" access="public" returntype="array" output="no" hint="I return the given saved query.">
	<cfargument name="QueryName" type="string" required="yes">
	
	<cfset var qQuery = 0>
	<cfset var arrSearch = ArrayNew(1)>
	
	<cfquery name="qQuery" datasource="#variables.datasource#">
	SELECT		qmFields.FieldID, KeyName, Label, jointable, FilterFields, filtertype, FieldValue AS Value, '' AS ValueLabel, cfdatatype
	FROM		qmQueries
	INNER JOIN	qmQueryFields
		ON		qmQueries.QueryID = qmQueryFields.QueryID
	INNER JOIN	qmFields
		ON		qmQueryFields.FieldID = qmFields.FieldID
	WHERE		QueryName = <cfqueryparam value="#arguments.QueryName#" cfsqltype="CF_SQL_VARCHAR">
	ORDER BY	QueryName
	</cfquery>
	
	<cfoutput query="qQuery">
		<cfscript>
		ArrayAppend(arrSearch,StructNew());
		arrSearch[ArrayLen(arrSearch)]["KeyName"] = KeyName;
		arrSearch[ArrayLen(arrSearch)]["Value"] = Value;
		</cfscript>
	</cfoutput>
	
	<cfreturn arrSearch>
</cffunction>

<cffunction name="getResults" access="public" returntype="query" output="yes" hint="I get the results for the given critera query.">
	<cfargument name="qCriteria" type="query" required="yes">
	
	<cfscript>
	var tables = "";
	var table = "";
	var joins = "volVolunteers,volLocations,volQualifications";
	var joins2 = joins;
	var qReport = 0;
	var fields = "";
	
	var i = 0;
	</cfscript>
	
	<cfthrow message="The getResults() method of QueryMgr must be overwritten in an extended component." type="QueryMgr" errorcode="NeedGetResultsMethod">
	
	<cfoutput query="qCriteria">
		<cfscript>
		if ( Not ListFindNoCase(tables,jointable) ) {
			tables = ListAppend(tables,jointable);
		}
		</cfscript>
	</cfoutput>
	
	<cfif qCriteria.RecordCount>
		<cfquery name="qCriteria" dbtype="query">SELECT * FROM qCriteria ORDER BY KeyName</cfquery>
	</cfif>
	

	<cfquery name="qReport" datasource="#variables.datasource#">
	FROM		MainTable
	<cfif Len(tables)><cfloop index="table" list="#tables#"><cfif Not ListFindNoCase(joins,table)>
				,#table#
	<cfset joins = ListAppend(joins,table)></cfif></cfloop></cfif>
	WHERE		1 = 1
	<cfif Len(tables)><cfloop index="table" list="#tables#"><cfif Not ListFindNoCase(joins2,table)>
		AND		volVolunteers.VolunteerID = #table#.VolunteerID
	<cfset joins2 = ListAppend(joins2,table)></cfif></cfloop></cfif>
	<cfif qCriteria.RecordCount>
	<cfoutput query="qCriteria" group="KeyName">
		AND	(
				0 = 1
		<cfoutput>
			<cfloop index="field" list="#filterfields#">
			OR	<cfif ListLen(filterfields) eq 1><cfif Len(jointable)>#jointable#<cfelse>volVolunteers</cfif>.</cfif>#field#
				<cfswitch expression="#filtertype#">
				<cfcase value="CONTAINS">LIKE <cfif Len(cfdatatype)><cfqueryparam value="%#Value#%" cfsqltype="#cfdatatype#"><cfelse>'%#Value#%'</cfif></cfcase>
				<cfcase value="Equals">LIKE <cfif Len(cfdatatype)><cfqueryparam value="#Value#" cfsqltype="#cfdatatype#"><cfelse>'%#Value#%'</cfif></cfcase>
				<cfcase value="AreaCode">LIKE <cfif Len(cfdatatype)><cfqueryparam value="#Left(Value,3)#%" cfsqltype="#cfdatatype#"><cfelse>'#Left(Value,3)#%'</cfif></cfcase>
				<cfcase value="GUID">= <cfif Len(cfdatatype)><cfqueryparam value="#Value#" cfsqltype="#cfdatatype#"><cfelse>'#Value#'</cfif></cfcase>
				<cfcase value="ID">= <cfif Len(cfdatatype)><cfqueryparam value="#Value#" cfsqltype="#cfdatatype#"><cfelse>#Val(Value)#</cfif></cfcase>
				<cfcase value="boolean"><cfif isBoolean(Value)>= <cfif Value>1<cfelse>0</cfif></cfif></cfcase>
				<cfcase value="YesOrNull"><cfif isBoolean(Value) AND Value>= 1<cfelse>IS NULL</cfif></cfcase>
				<cfcase value="Exists"><cfif isBoolean(Value) AND Value>IS NOT NULL<cfelse>IS NULL</cfif></cfcase>
				<cfcase value="List"> IN <cfif Len(cfdatatype)>(<cfqueryparam value="#Value#" cfsqltype="#cfdatatype#" list="Yes">)<cfelse>(#Value#)</cfif></cfcase>
				<cfdefaultcase>1 = 1</cfdefaultcase>
				</cfswitch>
			</cfloop>
		</cfoutput>
		)
	</cfoutput>
	</cfif>
	</cfquery>

	<cfreturn qReport>
</cffunction>

<cffunction name="removeQuery" access="public" returntype="void" output="no">
	<cfargument name="QueryName" type="string" required="yes">
	
	<cfset var qQuery = 0>
	<cfset var QueryID = "">
	
	<cfquery name="qQuery" datasource="#variables.datasource#">
	SELECT		QueryID
	FROM		qmQueries
	WHERE		QueryName = <cfqueryparam value="#arguments.QueryName#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<cfif qQuery.RecordCount>
		<cfset QueryID = qQuery.QueryID>
	<cfelse>
		<cfthrow message="No query named '#arguments.QueryName#' could be found." type="QueryMgr" errorcode="NoSuchQuery">
	</cfif>
	
	<cftransaction>
		<cfquery datasource="#variables.datasource#">
		DELETE
		FROM	qmQueryFields
		WHERE	QueryID = <cfqueryparam value="#QueryID#" cfsqltype="CF_SQL_IDSTAMP">
		</cfquery>
		<cfquery datasource="#variables.datasource#">
		DELETE
		FROM	qmQueries
		WHERE	QueryID = <cfqueryparam value="#QueryID#" cfsqltype="CF_SQL_IDSTAMP">
		</cfquery>
	</cftransaction>
	
</cffunction>

<cffunction name="saveQuery" access="public" returntype="void" output="no" hint="I save a query.">
	<cfargument name="QueryName" type="string" required="yes">
	<cfargument name="qCriteria" type="query" required="yes">
	
	<cfset qQuery = 0>
	<cfset QueryID = "">
	
	<cfquery name="qQuery" datasource="#variables.datasource#">
	SELECT	QueryID
	FROM	qmQueries
	WHERE	QueryName = <cfqueryparam value="#arguments.QueryName#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	
	<cfif qQuery.RecordCount>
		<cfthrow message="A query with that name already exists." type="QueryMgr" errorcode="QueryExists">
	</cfif>
	
	<cftransaction>
		<cfquery datasource="#variables.datasource#">
		INSERT INTO qmQueries (
			QueryName
		)
		VALUES (
			<cfqueryparam value="#arguments.QueryName#" cfsqltype="CF_SQL_VARCHAR">
		)
		</cfquery>
		
		<cfquery name="qQuery" datasource="#variables.datasource#">
		SELECT	QueryID
		FROM	qmQueries
		WHERE	QueryName = <cfqueryparam value="#arguments.QueryName#" cfsqltype="CF_SQL_VARCHAR">
		</cfquery>
		<cfset QueryID = qQuery.QueryID>
		
		<cfoutput query="qCriteria">
			<cfif Len(FieldID)>
				<cfquery datasource="#variables.datasource#">
				INSERT INTO qmQueryFields (
					QueryID,
					FieldID,
					FieldValue,
					ordernum
				) VALUES (
					'#QueryID#',
					'#FieldID#',
					'#Value#',
					#CurrentRow#
				)
				</cfquery>
			</cfif>
		</cfoutput>
	</cftransaction>
	
</cffunction>

<!---
 Sorts a query using Query of Query.
 Updated for CFMX var syntax.
 
 @param query 	 The query to sort. (Required)
 @param column 	 The column to sort on. (Required)
 @param sortDir  	 The direction of the sort. Default is "ASC." (Optional)
 @return Returns a query. 
 @author Raymond Camden (ray@camdenfamily.com) 
 @version 2, October 15, 2002 
--->
<cffunction name="QuerySort" output="no" returnType="query">
	<cfargument name="query" type="query" required="true">
	<cfargument name="column" type="string" required="true">
	<cfargument name="sort_order" type="string" required="false" default="asc">

	<cfset var newQuery = 0>
	
	<cfset var sortlist = "">
	<cfset var val = "">
	<cfset var subquery = "">
	<cfset var col = "">
	
	<cftry>
		<cfquery name="newQuery" dbType="query">
		SELECT		*
		FROM		query
		ORDER BY	#column# #sort_order#
		</cfquery>
		<cfcatch>
			<cfset newQuery = QueryNew(query.ColumnList)>
			<cfset sortlist = ArrayToList(query[column])>
			<cfset sortlist = ListSort(sortlist, "text", sort_order)>
			<cfloop index="val" list="#sortlist#">
				<cfquery name="subquery" dbType="query">
				SELECT	*
				FROM	query
				WHERE	#column# = '#val#'
				</cfquery>
				<cfloop query="subquery">
					<cfset QueryAddRow(newQuery)>
					<cfloop index="col" list="#subquery.ColumnList#">
						<cfset QuerySetCell(newQuery, col, subquery[col][CurrentRow])>
					</cfloop>
				</cfloop>
			</cfloop>
		</cfcatch>
	</cftry>
	
	<cfreturn newQuery>
	
</cffunction>

<cffunction name="getDbXml" access="private" returntype="string" output="no" hint="I return the XML for the tables needed for Searcher to work.">
<cfset var tableXML = "">
<cfsavecontent variable="tableXML">
<tables>
	<table name="qmFields">
		<field ColumnName="FieldID" CF_DataType="CF_SQL_IDSTAMP" PrimaryKey="true" /><!-- Need to make GUID -->
		<field ColumnName="KeyName" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="Label" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="GroupName" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="ordernum" CF_DataType="CF_SQL_INTEGER" />
		<field ColumnName="type" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="jointable" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="filterfields" CF_DataType="CF_SQL_VARCHAR" Length="400" />
		<field ColumnName="filtertype" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="queryTable" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="queryLabelField" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="queryValueField" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="querySQL" CF_DataType="CF_SQL_VARCHAR" Length="1000" />
		<field ColumnName="cfdatatype" CF_DataType="CF_SQL_VARCHAR" Length="50" />
	</table>
	<table name="qmQueries">
		<field ColumnName="QueryID" CF_DataType="CF_SQL_IDSTAMP" PrimaryKey="true" /><!-- Need to make GUID -->
		<field ColumnName="QueryName" CF_DataType="CF_SQL_VARCHAR" Length="50" />
		<field ColumnName="DateAdded" CF_DataType="CF_SQL_DATE" />
		<field ColumnName="isApproved" CF_DataType="CF_SQL_BIT" />
	</table>
	<table name="qmQueryFields">
		<field ColumnName="CriterianID" CF_DataType="CF_SQL_IDSTAMP" PrimaryKey="true" /><!-- Need to make GUID -->
		<field ColumnName="QueryID" CF_DataType="CF_SQL_IDSTAMP" />
		<field ColumnName="FieldID" CF_DataType="CF_SQL_IDSTAMP" />
		<field ColumnName="FieldValue" CF_DataType="CF_SQL_VARCHAR" Length="80" />
		<field ColumnName="ordernum" CF_DataType="CF_SQL_INTEGER" />
	</table>
</tables>
</cfsavecontent>
<cfreturn tableXML>
</cffunction>

</cfcomponent>