<cfcomponent displayname="Volunteer Exchange Manager" hint="I manage tasks for the Volunteer Exchange.">

<cffunction name="init" access="public" returntype="VolexMgr" output="no" hint="I initialize and return this object.">
	<cfargument name="DataMgr" type="any" required="yes">
	<cfargument name="Mailer" type="com.sebtools.Mailer" required="yes">
	
	<cfset variables.DataMgr = arguments.DataMgr>
	<cfset variables.Mailer = arguments.Mailer>

	<cfset variables.datasource = variables.DataMgr.getDatasource()>
	<cfset variables.DataMgr.loadXML(getDbXml())>
	
	<cfset variables.DataMgr.CreateTables('vdxOrgs')>
	
	<cfreturn this>
</cffunction>

<cffunction name="updateVolunteer" access="public" returntype="void" output="no">
	<cfargument name="VolunteerID" type="string" required="yes">
	
	<!--- %%Need to make this more generic --->
	
	<cfset qGetUpdate = 0>
	<cfset qOrg = getOrg('CitizenCorpsTulsa')>
	
	<cfquery name="qGetUpdate" datasource="#variables.datasource#">
	SELECT		DISTINCT volVolunteers.VolunteerID
	FROM		volVolunteers
	INNER JOIN	volLocations
		ON		volVolunteers.VolunteerID = volLocations.VolunteerID
		AND		volLocations.County = 'Tulsa'
	WHERE		volVolunteers.VolunteerID = <cfqueryparam value="#arguments.VolunteerID#" cfsqltype="CF_SQL_IDSTAMP">
		AND		isApproved = 1
	</cfquery>
	
	<!--- <cfif qGetUpdate.RecordCount>
		<cfset variables.volex.sendUpdate(qOrg.orgname,qOrg.orgkey,VolunteerID)>
	</cfif> --->
	
</cffunction>

<cffunction name="register" access="public" returntype="boolean" output="no">
	<cfargument name="orgname" type="string" required="yes">
	<cfargument name="orgkey" type="string" required="yes">
	<cfargument name="wsloc" type="string" required="yes">
	<cfargument name="wsver" type="numeric" required="yes">
	<cfargument name="xmlver" type="numeric" required="yes">
	
	<cfset qCheckOrgName = 0>
	
	<cfquery name="qCheckOrgName" datasource="#variables.datasource#">
	SELECT	orgID
	FROM	vdxOrgs
	WHERE	orgname = <cfqueryparam value="#arguments.orgname#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	
	<cfif qCheckOrgName.RecordCount>
		<cfthrow message="An organization with the given orgname has already registered." type="VolexMgr" errorcode="org-already-registered">
	</cfif>
	<cfquery datasource="#variables.datasource#">
	INSERT INTO vdxOrgs (
		orgname,
		orgkey,
		wsloc,
		wsver,
		xmlver,
		approvedDateTime,
		isThis
	) VALUES (
		<cfqueryparam value="#arguments.orgname#" cfsqltype="CF_SQL_VARCHAR">,
		<cfqueryparam value="#arguments.orgkey#" cfsqltype="CF_SQL_VARCHAR">,
		<cfqueryparam value="#arguments.wsloc#" cfsqltype="CF_SQL_VARCHAR">,
		<cfqueryparam value="#arguments.wsver#" cfsqltype="CF_SQL_FLOAT">,
		<cfqueryparam value="#arguments.xmlver#" cfsqltype="CF_SQL_FLOAT">,
		NULL,
		0
	)
	</cfquery>
	
	<cfreturn true>
</cffunction>

<cffunction name="checkOrg" access="public" returntype="numeric" output="no">
	<cfargument name="orgname" type="string" required="yes">
	<cfargument name="orgkey" type="string" required="yes">
	
	<cfset qOrg = 0>
	<cfset OrgID = 0>
	
	<cfquery name="qOrg" datasource="#variables.datasource#">
	SELECT	OrgID,approvedDateTime
	FROM	vdxOrgs
	WHERE	orgname = <cfqueryparam value="#arguments.orgname#" cfsqltype="CF_SQL_VARCHAR">
		AND	orgkey = <cfqueryparam value="#arguments.orgkey#" cfsqltype="CF_SQL_VARCHAR">
		AND	approvedDateTime IS NOT NULL
		AND	(isThis = 0 OR isThis IS NULL)
	</cfquery>
	
	<cfif qOrg.RecordCount eq 0>
		<cfthrow message="The given org name doesn't match any organizations listed on this site." type="VolexMgr" errorcode="no-such-org">
	</cfif>
	<cfif NOT isDate(qOrg.approvedDateTime)>
		<cfthrow message="The given org has not yet been approved." type="VolexMgr" errorcode="org-not-approved">
	</cfif>
	
	<cfreturn qOrg.OrgID>
</cffunction>

<cffunction name="getOrg" access="public" returntype="query" output="no">
	<cfargument name="orgname" type="string" required="yes">
	
	<cfset qOrg = 0>
	
	<cfquery name="qOrg" datasource="#variables.datasource#">
	SELECT	orgID,orgname,orgkey,wsloc,wsver,xmlver,approvedDateTime,isThis
	FROM	vdxOrgs
	WHERE	approvedDateTime IS NOT NULL
		AND	(isThis = 0 OR isThis IS NULL)
		AND	orgname = <cfqueryparam value="#arguments.orgname#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	
	<cfif qOrg.RecordCount eq 0>
		<cfthrow message="The given org name doesn't match any approved organizations listed on this site." type="VolexMgr" errorcode="no-such-org">
	</cfif>
	
	<cfreturn qOrg>
</cffunction>

<cffunction name="getThisOrg" access="public" returntype="query" output="no">
	
	<cfset qOrg = 0>
	
	<cfquery name="qOrg" datasource="#variables.datasource#">
	SELECT	orgID,orgname,orgkey,wsloc,wsver,xmlver,approvedDateTime,isThis
	FROM	vdxOrgs
	WHERE	isThis = 1
	</cfquery>
	
	<cfreturn qOrg>
</cffunction>

<cffunction name="sendError" access="public" returntype="void" output="no">
	<cfargument name="Error" type="any" required="yes">
	<cfargument name="Data" type="any" required="no">
	
	<cfset var Content = "">
	
	<cfsavecontent variable="Content">
		<cfdump var="#Error#">
		<cfif StructKeyExists(Error,"Message")><cfdump var="#Error.Message#"></cfif>
		<cfif StructKeyExists(Error,"Detail")><cfdump var="#Error.Detail#"></cfif>
		<cfif StructKeyExists(Error,"TagContext")><cfdump var="#Error.TagContext#"></cfif>
		<cfif StructKeyExists(arguments,"Data")><cfdump var="#arguments.Data#"></cfif>
	</cfsavecontent>
	
	<cfinvoke component="#variables.Mailer#" method="send">
		<cfinvokeargument name="To" value="sbryant@csihealthmedia.com">
		<cfinvokeargument name="Subject" value="MRC Volunteer Exchange Error">
		<cfinvokeargument name="Contents" value="#Content#">
		<cfinvokeargument name="type" value="html">
	</cfinvoke>
	
</cffunction>

<cffunction name="getDbXml" access="public" returntype="string" output="no" hint="I return the XML for the tables needed for Searcher to work.">
<cfset var tableXML = "">
<cfsavecontent variable="tableXML">
<tables>
	<table name="vdxOrgs">
		<field ColumnName="orgID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
		<field ColumnName="orgname" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="orgkey" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="wsloc" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="wsver" CF_DataType="CF_SQL_FLOAT" />
		<field ColumnName="xmlver" CF_DataType="CF_SQL_FLOAT" />
		<field ColumnName="approvedDateTime" CF_DataType="CF_SQL_DATE" />
		<field ColumnName="isThis" CF_DataType="CF_SQL_BIT" />
	</table>
</tables>
</cfsavecontent>
<cfreturn tableXML>
</cffunction>

</cfcomponent>