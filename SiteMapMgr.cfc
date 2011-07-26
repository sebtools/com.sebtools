<cfcomponent displayname="Site Map Manager">

<cfset br = "
">
<cfset tab = "	">

<cffunction name="init" access="public" returntype="SiteMapMgr" output="no" hint="I initialize and return this object.">
	<cfargument name="SiteMap" type="any" required="yes">
	<cfargument name="DataMgr" type="any" required="yes">
	<cfargument name="FilePath" type="string" required="yes">
	
	<cfscript>
	variables.FileLib = CreateObject("component","FileLib");
	variables.FilePath = arguments.FilePath;
	variables.SiteMap = arguments.SiteMap;
	variables.DataMgr = arguments.DataMgr;
	variables.datasource = variables.DataMgr.getDatasource();
	variables.DataMgr.loadXML(getDbXml(),true,true);
	variables.SitePages = QueryNew('URL,Label');
	variables.Observers = StructNew();
	variables.PageQueries = ArrayNew(1);
	//loadFile();
	</cfscript>
	
	<cfreturn this>
</cffunction>

<cffunction name="addPagesQuery" access="public" returntype="void" output="no">
	<cfargument name="Component" type="any" required="yes" hint="The component that will be called to perform the query.">
	<cfargument name="Method" type="string" required="yes" hint="The method to call on the component.">
	<cfargument name="QueryID" type="string" required="yes" hint="Any unique identifier for the query.">
	<cfargument name="labelfield" type="string" default="label">
	<cfargument name="urlfield" type="string" default="url">
	<cfargument name="ArgStruct" type="struct" required="no">
	
	<cfset var i = 0>
	<cfset var QueryExists = false>
	
	<cfloop index="i" from="1" to="#ArrayLen(variables.PageQueries)#" step="1">
		<cfif StructKeyExists(variables.PageQueries[i],"QueryID") AND variables.PageQueries[i].QueryID eq arguments.QueryID>
			<cfset QueryExists = true>
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfif NOT QueryExists>
		<cfset ArrayAppend(variables.PageQueries,StructNew())>
		<cfset i = ArrayLen(variables.PageQueries)>
		<cfset variables.PageQueries[i]["Component"] = arguments.Component>
		<cfset variables.PageQueries[i]["Method"] = arguments.Method>
		<cfset variables.PageQueries[i]["QueryID"] = arguments.QueryID>
		<cfset variables.PageQueries[i]["labelfield"] = arguments.labelfield>
		<cfset variables.PageQueries[i]["urlfield"] = arguments.urlfield>
		<cfif StructKeyExists(arguments,"ArgStruct")>
			<cfset variables.PageQueries[i]["ArgStruct"] = arguments.ArgStruct>
		</cfif>
	</cfif>
	
</cffunction>

<cffunction name="addObserver" access="public" returntype="void" output="no">
	<cfargument name="event" type="string" required="yes" hint="The subject event (method) to which to react.">
	<cfargument name="Observer" type="any" required="yes" hint="The observer component.">
	<cfargument name="ObserverID" type="string" required="yes" hint="Any unique identifier for the observer.">
	<cfargument name="ObserverMethod" type="string" required="yes" hint="The method to call on the observer.">
	
	<cfset var i = 0>
	<cfset var ObsExists = false>
	
	<!--- Make sure a record exists for this event --->
	<cfif NOT StructKeyExists(variables.Observers,event)>
		<cfset variables.Observers[event] = ArrayNew(1)>
	<cfelse>
		<!--- If a record already exists for this record, check to see if this observer is already registered --->
		<cfloop index="i" from="1" to="#ArrayLen(variables.Observers[event])#" step="1">
			<cfif (arguments.ObserverID eq variables.Observers[event][i].ObserverID) AND (arguments.ObserverMethod eq variables.Observers[event][i].ObserverMethod)>
				<cfset ObsExists = false>
			</cfif>
		</cfloop>
	</cfif>
	
	<cfif NOT ObsExists>
		<cfset ArrayAppend(variables.Observers[event],StructNew())>
		<cfset i = ArrayLen(variables.Observers[event])>
		<cfset variables.Observers[event][i]["Observer"] = arguments.Observer>
		<cfset variables.Observers[event][i]["ObserverID"] = arguments.ObserverID>
		<cfset variables.Observers[event][i]["ObserverMethod"] = arguments.ObserverMethod>
	</cfif>
	
</cffunction>

<cffunction name="announce" access="private" returntype="void" output="no">
	<cfargument name="event" type="string" required="yes">
	<cfargument name="args" type="any" required="no">
	
	<cfset var i = 0>
	<cfset var col = "">
	
	<cfif StructKeyExists(variables.Observers,event)>
		<cfloop index="i" from="1" to="#ArrayLen(variables.Observers[event])#" step="1">
			<cfif StructKeyExists(arguments,"args")>
				<cfif isStruct(arguments.args)>
					<cfinvoke component="#variables.Observers[event][i].Observer#" method="#variables.Observers[event][i].ObserverMethod#" argumentcollection="#arguments.args#"></cfinvoke>
				<cfelseif isQuery(arguments.args)>
					<cfinvoke component="#variables.Observers[event][i].Observer#" method="#variables.Observers[event][i].ObserverMethod#">
						<cfloop index="col" list="#arguments.args.ColumnList#">
							<cfif Len(arguments.args[col][1])>
								<cfinvokeargument name="#col#" value="#arguments.args[col][1]#">
							</cfif>
						</cfloop>
					</cfinvoke>
				</cfif>
			</cfif>
		</cfloop>
	</cfif>
	
</cffunction>

<cffunction name="getObservers" access="public" returntype="any"><cfreturn variables.Observers></cffunction>

<cffunction name="getPage" access="public" returntype="query" output="no" hint="I get a page with the given PageID.">
	<cfargument name="PageID" type="numeric" required="no">
	
	<cfreturn variables.DataMgr.getRecord('smapPages',arguments)>
</cffunction>

<cffunction name="getPages" access="public" returntype="query" output="no" hint="I get page for the given section.">
	<cfargument name="SectionID" type="numeric" required="no">
	
	<cfset var qPages = 0>
	
	<cfquery name="qPages" datasource="#variables.datasource#">
	SELECT		PageID,ordernum,PageName,PageLabel,PageURL,onMenu,Permissions
	FROM		smapPages
	WHERE		1 = 1
	<cfif StructKeyExists(arguments,"SectionID") AND arguments.SectionID gt 0>
		AND		SectionID = <cfqueryparam value="#arguments.SectionID#" cfsqltype="CF_SQL_INTEGER">
	<cfelse>
		AND		(SectionID IS NULL OR SectionID = 0)
	</cfif>
	ORDER BY	ordernum
	</cfquery>

	<cfreturn qPages>
</cffunction>

<cffunction name="getPermission" access="public" returntype="query" output="no" hint="I get a permission with the given PermissionID.">
	<cfargument name="PermissionID" type="numeric" required="yes">
	
	<cfreturn variables.DataMgr.getRecord('smapPermissions',arguments)>
</cffunction>

<cffunction name="getSection" access="public" returntype="query" output="no" hint="I get a section with the given SectionID.">
	<cfargument name="SectionID" type="numeric" required="yes">
	
	<cfset var qSection = 0>
	<cfset var qParentSection = 0>
	
	<cfquery name="qSection" datasource="#variables.datasource#">
	SELECT	SectionID,ParentSectionID,ordernum,SectionName,SectionLabel,SectionURL,Permissions,
			SectionLabel AS SectionLabelExt
	FROM	smapSections
	WHERE	SectionID = <cfqueryparam value="#arguments.SectionID#" cfsqltype="CF_SQL_INTEGER">
	</cfquery>
	
	<cfif Len(qSection.ParentSectionID)>
		<cfset qParentSection = getSection(qSection.ParentSectionID)>
		<cfset QuerySetCell(qSection, "SectionLabelExt", "#qParentSection.SectionLabelExt# -&gt; #qSection.SectionLabel#")>
	</cfif>
	
	<!--- <cfreturn variables.DataMgr.getRecord('smapSections',arguments)> --->
	<cfreturn qSection>
</cffunction>

<cffunction name="getSections" access="public" returntype="query" output="no" hint="I get a recordset of sections with the given ParentSectionID.">
	<cfargument name="ParentSectionID" type="numeric" required="no">
	
	<cfset var qSections = 0>
	<cfset var qParentSection = 0>
	
	<cfset var qSubsections = 0>
	<cfset var qPages = 0>
	
	<cfif StructKeyExists(arguments,"ParentSectionID")>
		<cfset qParentSection = getSection(arguments.ParentSectionID)>
	</cfif>
	
	<cfquery name="qSections" datasource="#variables.datasource#">
	SELECT		SectionID,ordernum,SectionName,SectionLabel,SectionURL,Permissions,
				<cfif StructKeyExists(arguments,"ParentSectionID")>('#qParentSection.SectionLabelExt# -&gt; ' + SectionLabel)<cfelse>SectionLabel</cfif> AS SectionLabelExt,
				'0' AS hasChildren
	FROM		smapSections
	WHERE		1 = 1
	<cfif StructKeyExists(arguments,"ParentSectionID") AND arguments.ParentSectionID gt 0>
		AND		ParentSectionID = <cfqueryparam value="#arguments.ParentSectionID#" cfsqltype="CF_SQL_INTEGER">
	<cfelse>
		AND		(ParentSectionID IS NULL OR ParentSectionID = 0)
	</cfif>
	ORDER BY	ordernum
	</cfquery>
	
	<cfoutput query="qSections">
		<cfset qSubsections = getSections(SectionID)>
		<cfset qPages = getPages(SectionID)>
		<cfif qSubsections.RecordCount OR qPages.RecordCount>
			<cfset QuerySetCell(qSections, "hasChildren", 1, CurrentRow)>
		</cfif>
	</cfoutput>

	<cfreturn qSections>
</cffunction>

<cffunction name="getAllSections" access="public" returntype="query" output="no" hint="I get a section with the given SectionID.">
	<cfargument name="addRoot" type="boolean" default="false">
	
	<cfset var qBaseSections = getSections()>
	<cfset var cols = qBaseSections.ColumnList>
	<cfset var qSections = QueryNew(cols)>
	<cfset var sSubQeries = StructNew()>
	<cfset var key = "">
	<cfset var col = "">
	
	<cfif arguments.addRoot>
		<cfset QueryAddRow(qSections)>
		<cfset QuerySetCell(qSections, "SectionID", 0)>
		<cfset QuerySetCell(qSections, "ordernum", 0)>
		<cfset QuerySetCell(qSections, "SectionName", "root")>
		<cfset QuerySetCell(qSections, "SectionLabel", "(root)")>
		<cfset QuerySetCell(qSections, "SectionURL", "/")>
		<cfset QuerySetCell(qSections, "Permissions", "")>
		<cfset QuerySetCell(qSections, "SectionLabelExt", "(root)")>
	</cfif>
	
	<cfoutput query="qBaseSections">
		<cfset sSubQeries[SectionID] = getSections(SectionID)>
		<cfset QueryAddRow(qSections)>
		<cfloop index="col" list="#cols#">
			<cfset QuerySetCell(qSections, col, qBaseSections[col][CurrentRow])>
		</cfloop>
	</cfoutput>
	
	<cfloop collection="#sSubQeries#" item="key">
		<cfoutput query="sSubQeries.#key#">
			<cfset QueryAddRow(qSections)>
			<cfloop index="col" list="#cols#">
				<cfset QuerySetCell(qSections, col, sSubQeries[key][col][CurrentRow])>
			</cfloop>
		</cfoutput>
	</cfloop>
	
	<cfreturn qSections>
</cffunction>

<!--- <cffunction name="getSectionLabelExt" access="private" returntype="string" output="no">
	<cfargument name="SectionID" type="numeric" required="yes">
	
	<cfset var qSection = getSection(arguments.SectionID)>
	<cfset var result = qSection.SectionLabel>
	
	<cfif isNumeric(qSection.ParentSectionID)>
		<cfset result = getSectionLabelExt(qSection.ParentSectionID) & " -&gt; " & result>
	</cfif>
	
	<cfreturn result>
</cffunction> --->

<cffunction name="getData" access="public" returntype="query" output="no">
	<cfargument name="SectionID" type="numeric" required="no">
	<cfargument name="SubsectionID" type="numeric" required="no">
	
	<cfset var qData = 0>
	<cfset var cols = "">
	<cfset var col = "">
	
	<cfquery name="qData" datasource="#variables.datasource#">
	SELECT		Sections.SectionID, Sections.SectionName, Sections.SectionLabel, Sections.SectionURL, Sections.Permissions AS SectionPermissions,
				Subsections.SectionID AS SubsectionID, Subsections.SectionName AS SubsectionName, Subsections.SectionLabel AS SubsectionLabel, Subsections.SectionURL AS SubsectionURL, Subsections.Permissions AS SubsectionPermissions,
				Pages.SectionID AS PageSectionID, PageID, PageName, PageLabel, PageURL, onMenu, Pages.Permissions AS PagePermissions
	FROM		smapSections Sections
	LEFT JOIN	smapSections Subsections
		ON		Subsections.ParentSectionID = Sections.SectionID
	LEFT JOIN	smapPages Pages
		ON		Pages.SectionID = Sections.SectionID
			OR	Pages.SectionID = Subsections.SectionID
	WHERE		(Sections.ParentSectionID IS NULL OR Sections.ParentSectionID = 0)
	<cfif StructKeyExists(arguments,"SectionID")>
		AND		Sections.SectionID = <cfqueryparam value="#arguments.SectionID#" cfsqltype="CF_SQL_INTEGER">
	</cfif>
	<cfif StructKeyExists(arguments,"SubsectionID")>
		AND		Subsections.SectionID = <cfqueryparam value="#arguments.SubsectionID#" cfsqltype="CF_SQL_INTEGER">
	</cfif>
	ORDER BY	Sections.ordernum, Subsections.ordernum, Pages.ordernum
	</cfquery>
	
	<cfset cols = qData.ColumnList>
	<cfoutput query="qData">
		<cfloop index="col" list="#cols#">
			<cfif Len(qData[col][CurrentRow]) AND NOT ( isBoolean(qData[col][CurrentRow]) OR isNumeric(qData[col][CurrentRow]) )>
				<cfset QuerySetCell(qData, col, XmlFormat(qData[col][CurrentRow]), CurrentRow)>
			</cfif>
		</cfloop>
	</cfoutput>
	
	<cfreturn qData>
</cffunction>

<cffunction name="getXml" access="public" returntype="string" output="no" hint="I return the XML for the Site Map XML file based on the data in the database.">
	
	<cfset var qSections = getSections()>
	<cfset var qPages = getPages()>
	<cfset var result = "">
	<cfset var branch = "">
	<cfset var comment = "">
	
	<cfset comment = "Make sure to call a page on this site with ?refresh=SiteMap if you change this file.">
	<cfset comment = "Do not update this file directly! Update via site admin instead.">
	
<cfsavecontent variable="result"><cfoutput><?xml version="1.0" encoding="utf-8"?></cfoutput>
<cfoutput><site><!-- #comment# --></cfoutput><cfoutput query="qSections">
	<section name="#XmlFormat(SectionName)#" label="#XmlFormat(SectionLabel)#" url="#XmlFormat(SectionURL)#"<cfif Len(Permissions)> permissions="#XmlFormat(Permissions)#"</cfif>><!--- <cfset branch = ReplaceNoCase(getXmlBranch(SectionID), br, "#br##tab##tab#", "ALL")><cfif Len(Trim(branch))>#branch#</cfif> --->
		#getXmlBranch(SectionID,2)#
	</section></cfoutput><cfoutput query="qPages">
	<page<cfif Len(PageName)> name="#XmlFormat(PageName)#"</cfif> label="#XmlFormat(PageLabel)#" url="#XmlFormat(PageURL)#"<cfif Len(onMenu) AND isBoolean(onMenu)> onMenu="<cfif onMenu>true<cfelse>false</cfif>"</cfif><cfif Len(Permissions)> permissions="#XmlFormat(Permissions)#"</cfif> /></cfoutput>
<cfoutput></site></cfoutput></cfsavecontent>
	
	<cfreturn result>
</cffunction>

<cffunction name="getXmlBranch" access="public" returntype="string" output="no">
	<cfargument name="SectionID" type="numeric" required="yes">
	<cfargument name="indents" type="numeric" default="1">
	
	<cfset var qPages = getPages(arguments.SectionID)>
	<cfset var qSubsections = getSections(arguments.SectionID)>
	<cfset var result = "">
	<cfset var branch = "">
	<cfset var i = 0>
	<cfset var indention = "">
	
	
<cfsavecontent variable="result"><cfoutput query="qPages">
<page<cfif Len(PageName)> name="#XmlFormat(PageName)#"</cfif> label="#XmlFormat(PageLabel)#" url="#XmlFormat(PageURL)#"<cfif Len(onMenu) AND isBoolean(onMenu)> onMenu="<cfif onMenu>true<cfelse>false</cfif>"</cfif><cfif Len(Permissions)> permissions="#XmlFormat(Permissions)#"</cfif> /></cfoutput><cfoutput query="qSubsections">
<subsection name="#XmlFormat(SectionName)#" label="#XmlFormat(SectionLabel)#" url="#XmlFormat(SectionURL)#"<cfif Len(Permissions)> permissions="#XmlFormat(Permissions)#"</cfif>><!--- <cfset branch = ReplaceNoCase(getXmlBranch(qSubsections.SectionID[CurrentRow]), br, "#br##tab#", "ALL")><cfif Len(Trim(branch))> --->
	#getXmlBranch(qSubsections["SectionID"][CurrentRow],1)#
</subsection></cfoutput></cfsavecontent>
	
	<cfscript>
	//make indention
	for ( i=1; i lte indents; i=i+1 ) {
		indention = indention & tab;
	}
	while ( Len(result) gt 1 AND Left(result,1) neq "<" ) {
		result = Right(result,Len(result)-1);
	}
	result = Trim(result);
	result = ReplaceNoCase(result, br, "#br##indention#", "ALL");
	</cfscript>
	
	<cfreturn result>
</cffunction>

<cffunction name="loadFile" access="public" returntype="void" output="no" hint="I load data into the database from the Site Map XML file.">
	
	<cfset var XmlString = "">
	<cfset var XmlData = 0>
	
	<cffile action="READ" file="#variables.FilePath#" variable="XmlString">
	
	<cfset XmlData = XmlParse(XmlString,"no")>
	
	<!--- Clear Data --->
	<!--- <cfset clearData()> --->
	
	<!--- <cfset loadBranch(XmlData.XmlRoot.XmlChildren)> --->
	
</cffunction>

<cffunction name="loadBranch" access="private" returntype="void" output="no">
	<cfargument name="branch" type="array" required="yes">
	<cfargument name="SectionID" type="numeric" required="no">
	
	<cfset var i = 0>
	<cfset var localSectionID = 0>
	<cfset var curr = 0>
	
	<cfif StructKeyExists(arguments,"SectionID")>
		<cfset localSectionID = arguments.SectionID>
	</cfif>
	
	<cfloop index="i" from="1" to="#ArrayLen(arguments.branch)#" step="1">
		<cfset curr = arguments.branch[i]>
		<cfif StructKeyExists(curr,"XmlName") AND StructKeyExists(curr,"XmlAttributes")>
			<cfif curr["XmlName"] eq "page"><!--- <cfbreak> --->
				<!--- Save page --->
				<cfinvoke method="savePage">
					<cfif localSectionID>
						<cfinvokeargument name="SectionID" value="#localSectionID#">
					</cfif>
					<cfif StructKeyExists(curr["XmlAttributes"],"name")>
						<cfinvokeargument name="PageName" value="#curr['XmlAttributes']['name']#">
					</cfif>
					<cfif StructKeyExists(curr["XmlAttributes"],"label")>
						<cfinvokeargument name="PageLabel" value="#curr['XmlAttributes']['label']#">
					</cfif>
					<cfif StructKeyExists(curr["XmlAttributes"],"url")>
						<cfinvokeargument name="PageURL" value="#curr['XmlAttributes']['url']#">
					</cfif>
					<cfif StructKeyExists(curr["XmlAttributes"],"onMenu")>
						<cfinvokeargument name="onMenu" value="#curr['XmlAttributes']['onMenu']#">
					</cfif>
					<cfif StructKeyExists(curr["XmlAttributes"],"permissions")>
						<cfinvokeargument name="Permissions" value="#curr['XmlAttributes']['permissions']#">
					</cfif>
				</cfinvoke>
			<cfelse>
				<!--- Save section --->
				<cfinvoke method="saveSection" returnvariable="localSectionID">
					<cfif StructKeyExists(arguments,"SectionID") AND isNumeric(arguments.SectionID) AND arguments.SectionID gt 0>
						<cfinvokeargument name="ParentSectionID" value="#arguments.SectionID#">
					</cfif>
					<cfif StructKeyExists(curr["XmlAttributes"],"name")>
						<cfinvokeargument name="SectionName" value="#curr['XmlAttributes']['name']#">
					</cfif>
					<cfif StructKeyExists(curr["XmlAttributes"],"label")>
						<cfinvokeargument name="SectionLabel" value="#curr['XmlAttributes']['label']#">
					</cfif>
					<cfif StructKeyExists(curr["XmlAttributes"],"url")>
						<cfinvokeargument name="SectionURL" value="#curr['XmlAttributes']['url']#">
					</cfif>
					<cfif StructKeyExists(curr["XmlAttributes"],"permissions")>
						<cfinvokeargument name="Permissions" value="#curr['XmlAttributes']['permissions']#">
					</cfif>
				</cfinvoke>
				
				<cfif StructKeyExists(curr,"XmlChildren") AND ArrayLen(curr["XmlChildren"])>
					<cfset loadBranch(curr["XmlChildren"],localSectionID)>
				</cfif>
			</cfif>
		</cfif>
	</cfloop>
	
</cffunction>

<cffunction name="orderPages" access="public" returntype="void" output="no" hint="I save the order of the given sections.">
	<cfargument name="SectionID" type="numeric" required="no">
	<cfargument name="Pages" type="string" required="no">
	
	<cfset var i = 0>
	<cfset var PageID = 0>
	
	<cfloop index="i" from="1" to="#ListLen(arguments.Pages)#" step="1">
		<cfset PageID = ListGetAt(arguments.Pages,i)>
		<cfinvoke method="savePage">
			<cfinvokeargument name="PageID" value="#PageID#">
			<cfif StructKeyExists(arguments,"SectionID")>
				<cfinvokeargument name="SectionID" value="#arguments.SectionID#">
			</cfif>
			<cfinvokeargument name="ordernum" value="#i#">
		</cfinvoke>
	</cfloop>
	
	<cfset updateSiteMap()>
	
</cffunction>

<cffunction name="orderSections" access="public" returntype="void" output="no" hint="I save the order of the given sections.">
	<cfargument name="ParentSectionID" type="numeric" required="no">
	<cfargument name="Sections" type="string" required="no">
	
	<cfset var i = 0>
	<cfset var SectionID = 0>
	
	<cfloop index="i" from="1" to="#ListLen(arguments.Sections)#" step="1">
		<cfset SectionID = ListGetAt(arguments.Sections,i)>
		<cfinvoke method="saveSection">
			<cfinvokeargument name="SectionID" value="#SectionID#">
			<cfif StructKeyExists(arguments,"ParentSectionID") AND arguments.ParentSectionID gt 0>
				<cfinvokeargument name="ParentSectionID" value="#arguments.ParentSectionID#">
			</cfif>
			<cfinvokeargument name="ordernum" value="#i#">
			<cfinvokeargument name="noupdate" value="true">
		</cfinvoke>
	</cfloop>
	
	<cfset updateSiteMap()>
	
</cffunction>

<cffunction name="removePage" access="public" returntype="void" output="no" hint="I remove the given page.">
	<cfargument name="PageID" type="numeric" required="yes">
	
	<cfset variables.DataMgr.deleteRecord('smapPages',arguments)>
	
	<cfset updateSiteMap()>
	
	<cfset announce('removePage',arguments)>
	
</cffunction>

<cffunction name="removePermission" access="public" returntype="void" output="no" hint="I remove the given permission.">
	<cfargument name="PermissionID" type="numeric" required="yes">
	
	<cfset updateSiteMap()>
	
</cffunction>

<cffunction name="removeSection" access="public" returntype="void" output="no" hint="I remove the given section.">
	<cfargument name="SectionID" type="numeric" required="yes">
	
	<cfset var qPages = getPages(arguments.SectionID)>
	<cfset var qSubsections = getSections(arguments.SectionID)>
	
	<cfif NOT (qPages.RecordCount OR qSubsections.RecordCount)>
		<cfset variables.DataMgr.deleteRecord('smapSections',arguments)>
		<cfset updateSiteMap()>
	</cfif>
	
	<cfset announce('removeSection',arguments)>
	
</cffunction>

<cffunction name="savePage" access="public" returntype="numeric" output="no" hint="I save a page with the given data.">
	<cfargument name="PageID" type="numeric" required="no">
	<cfargument name="SectionID" type="numeric" required="no">
	<cfargument name="ordernum" type="numeric" required="no">
	<cfargument name="PageName" type="string" required="no">
	<cfargument name="PageLabel" type="string" required="no">
	<cfargument name="PageURL" type="string" required="no">
	<cfargument name="onMenu" type="boolean" required="no">
	<cfargument name="Permissions" type="string" required="no">
	
	<cfset var doUpdate = false>
	<cfset var qPage = 0>

	<!--- Set default ordernum --->
	<!--- <cfif NOT StructKeyExists(arguments,"PageID") AND NOT StructKeyExists(arguments,"ordernum")>
		<cfinvoke method="getNewPageOrderNum" returnvariable="arguments.ordernum">
			<cfif StructKeyExists(arguments,"SectionID")>
				<cfinvokeargument name="SectionID" value="#arguments.SectionID#">
			</cfif>
		</cfinvoke>
	</cfif> --->
	
	<!--- Get Page title --->
	<cfif StructKeyExists(arguments,"PageURL") AND NOT StructKeyExists(arguments,"PageLabel")>
		<cfset arguments.PageLabel = getTitleFromUrl(arguments.PageURL)>
	</cfif>

	<!--- Update site map for new page or if data changed --->
	<cfif StructKeyExists(arguments,"PageID")>
		<cfset qPage = getPage(arguments.PageID)>
		<cfset doUpdate = hasChanges(qPage,arguments)>
	<cfelse>
		<cfset doUpdate = true>
	</cfif>

	<cfif doUpdate>
		
		<!--- Save this page --->
		<cfset arguments.PageID = variables.DataMgr.saveRecord('smapPages',arguments)>
		
		<!--- Set permissions for this page --->
		<!--- %%Need to convert to list of ids first --->
		<!--- <cfif StructKeyExists(arguments,"Permissions")>
			<cfset variables.DataMgr.saveRelationList('smapPages2Permissions','PageID',arguments.PageID,'PermissionID',arguments.Permissions)>
		</cfif> --->
		
		<cfset updateSiteMap()>
		<cfset qPage = getPage(arguments.PageID)>
		<cfset announce('savePage',qPage)>
	</cfif>
	
	<cfreturn arguments.pageID>
</cffunction>

<cffunction name="savePermission" access="public" returntype="numeric" output="no" hint="I save a permission with the given data.">>
	<cfargument name="PermissionID" type="numeric" required="no">
	<cfargument name="PermissionName" type="string" required="yes">
	
	<cfset arguments.PermissionID = variables.DataMgr.saveRecord('smapPermissions',arguments)>
	
	<cfreturn arguments.PermissionID>
</cffunction>

<cffunction name="saveSection" access="public" returntype="numeric" output="no" hint="I save a section with the given data.">
	<cfargument name="SectionID" type="numeric" required="no">
	<cfargument name="ParentSectionID" type="numeric" required="no">
	<cfargument name="ordernum" type="numeric" required="no">
	<cfargument name="SectionName" type="string" required="no">
	<cfargument name="SectionLabel" type="string" required="no">
	<cfargument name="SectionURL" type="string" required="no">
	<cfargument name="Permissions" type="string" required="no">
	<cfargument name="noupdate" type="boolean" default="false">
	
	<cfset var doUpdate = false>
	<cfset var qSection = 0>
	<cfset var ParentSection = 0>

	<!--- <cfif NOT StructKeyExists(arguments,"SectionID") AND NOT StructKeyExists(arguments,"ordernum")>
		<cfif StructKeyExists(arguments,"ParentSectionID")>
			<cfset arguments.ordernum = getNewSectionOrderNum(arguments.ParentSectionID)>
		<cfelse>
			<cfset arguments.ordernum = getNewSectionOrderNum()>
		</cfif>
	</cfif> --->

	<!--- Update site map for new section or if data changed --->
	<cfif StructKeyExists(arguments,"SectionID")>
		<cfset qSection = getSection(arguments.SectionID)>
		<cfset doUpdate = hasChanges(qSection,arguments)>
	<cfelse>
		<cfset doUpdate = true>
	</cfif>

	<cfif doUpdate>

		<!--- Save this section --->
		<cfset arguments.SectionID = variables.DataMgr.saveRecord('smapSections',arguments)>

		<!--- Set permissions for this section --->
		<!--- %%Need to convert to list of ids first --->
		<!--- <cfif StructKeyExists(arguments,"Permissions")>
			<cfset variables.DataMgr.saveRelationList('smapSections2Permissions','SectionID',arguments.SectionID,'PermissionID',arguments.Permissions)>
		</cfif> --->
		
		<!--- Update site map only if this is just a re-order --->
		<cfif NOT noupdate>
			<cfset updateSiteMap()>
			<cfset qSection = getSection(arguments.SectionID)>
			<cfset announce('saveSection',qSection)>
		</cfif>
		
	</cfif>
	
	<cfreturn Val(arguments.SectionID)>
</cffunction>

<cffunction name="write" access="public" returntype="void" output="no" hint="I save the XML file with the current data.">
	<cfset var output = getXml()>
	<cflock timeout="40" throwontimeout="No" name="SiteMapFileWrite" type="EXCLUSIVE">
		<cffile action="WRITE" file="#variables.FilePath#" output="#output#" addnewline="no">
	</cflock>
</cffunction>

<cffunction name="updateSiteMap" access="public" returntype="void" output="no">
	<cfscript>
	write();
	variables.SiteMap.init(getXml());
	</cfscript>
</cffunction>

<cffunction name="clearData" access="private" returntype="void" output="no" hint="I clear the data in the database so that it can be populated from the XML file.">
	
	<cfscript>
	var i = 0;
	var SiteMgrTables = XmlParse(getDbXml());
	var arrTables = SiteMgrTables.XmlRoot.XmlChildren;
	</cfscript>
	
	<cfloop index="i" from="1" to="#ArrayLen(arrTables)#" step="1">
		<cfif StructKeyExists(arrTables[i].XmlAttributes,"name")>
			<cfquery datasource="#variables.datasource#">
			DELETE
			FROM	#arrTables[i].XmlAttributes.name#
			</cfquery>			
		</cfif>
	</cfloop>
	
</cffunction>

<cffunction name="getNewPageOrderNum" access="private" returntype="numeric" output="no" hint="I return the next order number for a new page in the given section.">
	<cfargument name="SectionID" type="numeric" required="no">
	
	<cfset var qLast = 0>
	<cfset var result = 0>
	
	<cfquery name="qLast" datasource="#variables.datasource#">
	SELECT		TOP 1 ordernum
	FROM		smapPages
	<cfif StructKeyExists(arguments,"SectionID")>
	WHERE		SectionID = <cfqueryparam value="#arguments.SectionID#" cfsqltype="CF_SQL_INTEGER">
	<cfelse>
	WHERE		SectionID IS NULL
	</cfif>
	ORDER BY	ordernum DESC
	</cfquery>
	
	<cfif qLast.RecordCount and isNumeric(qLast.ordernum)>
		<cfset result = qLast.ordernum + 1>
	<cfelse>
		<cfset result = 1>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getNewSectionOrderNum" access="private" returntype="numeric" output="no" hint="I return the next order number for a new section in the given parent section.">
	<cfargument name="ParentSectionID" type="numeric" required="no">
	
	<cfset var qLast = 0>
	<cfset var result = 0>
	
	<cfquery name="qLast" datasource="#variables.datasource#">
	SELECT		TOP 1 ordernum
	FROM		smapSections
	<cfif StructKeyExists(arguments,"ParentSectionID")>
	WHERE		ParentSectionID = <cfqueryparam value="#arguments.ParentSectionID#" cfsqltype="CF_SQL_INTEGER">
	<cfelse>
	WHERE		ParentSectionID IS NULL
	</cfif>
	ORDER BY	ordernum DESC
	</cfquery>
	
	<cfif qLast.RecordCount and isNumeric(qLast.ordernum)>
		<cfset result = qLast.ordernum + 1>
	<cfelse>
		<cfset result = 1>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSiteFiles" access="public" returntype="query" output="no">
	<cfargument name="SiteRootPath" type="string" required="yes">
	<cfargument name="excludedirs" type="string" default="">
	<cfargument name="ValidExtensions" type="string" default="cfm,cfml,htm,html">
	
	<cfset var qTempFiles = variables.FileLib.directoryList(directory=arguments.SiteRootPath,recurse=true)>
	<cfset var qReturnFiles = QueryNew('Label,URL')>
	<cfset var PageURL = "">
	<cfset var thisDir = "">
	<cfset var isOK = true>
	
	<cfoutput query="qTempFiles">
		<cfif type eq "File" AND name neq "Application.cfm" AND ListFindNoCase(arguments.ValidExtensions,ListLast(name,"."))>
			<cfset PageURL = "/" & ReplaceNoCase(ReplaceNoCase(Directory, arguments.SiteRootPath, ""), "\", "/", "All") & name>
			<cfset isOK = true>
			<cfloop index="thisDir" list="#arguments.excludedirs#">
				<cfif Left(PageURL,Len(thisDir)) eq thisDir>
					<cfset isOK = false>
				</cfif>
			</cfloop>
			<cfif isOK>
				<cfset QueryAddRow(qReturnFiles)>
				<cfset QuerySetCell(qReturnFiles, "Label", name)>
				<cfset QuerySetCell(qReturnFiles, "URL", PageURL)>
			</cfif>
		</cfif>
	</cfoutput>
	
	<cfreturn qReturnFiles>
</cffunction>

<cffunction name="getSitePages" access="public" returntype="query" output="no">
	<cfargument name="SiteRootPath" type="string" required="no">
	<cfargument name="ExcludeDirs" type="string" required="no">
	<cfargument name="ValidExtensions" type="string" default="cfm,cfml,htm,html">
	
	<cfset var qResult = QueryNew("Label,URL")>
	<cfset var i = 1>
	<cfset var qTemp = 0>
	
	<cfif ArrayLen(variables.PageQueries)>
		<cfloop index="i" from="1" to="#ArrayLen(variables.PageQueries)#" step="1">
			<cfif StructKeyExists(variables.PageQueries[i],"ArgStruct")>
				<cfinvoke component="#variables.PageQueries[i].Component#" method="#variables.PageQueries[i].Method#" returnvariable="qTemp" argumentcollection="#variables.PageQueries[i].ArgStruct#"></cfinvoke>
			<cfelse>
				<cfinvoke component="#variables.PageQueries[i].Component#" method="#variables.PageQueries[i].Method#" returnvariable="qTemp"></cfinvoke>
			</cfif>
			<cfif isQuery(qTemp) AND qTemp.RecordCount>
				<cfoutput query="qTemp">
					<cfset QueryAddRow(qResult)>
					<cfset QuerySetCell(qResult, "Label", qTemp[variables.PageQueries[i].labelfield][CurrentRow], qResult.RecordCount)>
					<cfset QuerySetCell(qResult, "URL", qTemp[variables.PageQueries[i].urlfield][CurrentRow], qResult.RecordCount)>
				</cfoutput>
			</cfif>
		</cfloop>
	<cfelse>
		<cfset qResult = getSiteFiles(arguments.SiteRootPath,arguments.ExcludeDirs,arguments.ValidExtensions)>
	</cfif>
	
	<cfset variables.SitePages = qResult>
	
	<cfreturn qResult>
</cffunction>

<cffunction name="getTitleFromUrl" access="public" returntype="string" output="no">
	<cfargument name="URL" type="string" required="yes">
	
	<cfset var qSitePages = variables.SitePages>
	<cfset var qFindPage = 0>
	<cfset var result = "">
	
	<cfquery name="qFindPage" dbtype="query">
	SELECT	Label AS Title
	FROM	qSitePages
	WHERE	URL = '#arguments.URL#'
	</cfquery>
	
	<cfif qFindPage.RecordCount eq 1>
		<cfset result = qFindPage.Title>
	<cfelse>
		<!--- %%Add code to get title if record isn't in set --->
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getDbXml" access="public" returntype="string" output="no" hint="I return the XML for the tables needed for Searcher to work.">
<cfset var tableXML = "">
<cfsavecontent variable="tableXML">
<tables>
	<table name="smapSections">
		<field ColumnName="SectionID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
		<field ColumnName="ParentSectionID" CF_DataType="CF_SQL_INTEGER" />
		<field ColumnName="ordernum" CF_DataType="CF_SQL_INTEGER" Special="Sorter" Default="0" />
		<field ColumnName="SectionName" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="SectionLabel" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="SectionURL" CF_DataType="CF_SQL_VARCHAR" Length="240" />
		<field ColumnName="Permissions" CF_DataType="CF_SQL_VARCHAR" Length="250" />
	</table>
	<table name="smapPages">
		<field ColumnName="PageID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
		<field ColumnName="SectionID" CF_DataType="CF_SQL_INTEGER" />
		<field ColumnName="ordernum" CF_DataType="CF_SQL_INTEGER" Special="Sorter" Default="0" />
		<field ColumnName="PageName" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="PageLabel" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="PageURL" CF_DataType="CF_SQL_VARCHAR" Length="240" />
		<field ColumnName="onMenu" CF_DataType="CF_SQL_BIT" />
		<field ColumnName="Permissions" CF_DataType="CF_SQL_VARCHAR" Length="250" />
	</table>
	<table name="smapPermissions">
		<field ColumnName="PermissionID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
		<field ColumnName="PermissionName" CF_DataType="CF_SQL_VARCHAR" Length="60" />
	</table>
	<table name="smapSections2Permissions">
		<field ColumnName="SectionID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" />
		<field ColumnName="PermissionID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" />
	</table>
	<table name="smapPages2Permissions">
		<field ColumnName="PageID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" />
		<field ColumnName="PermissionID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" />
	</table>
</tables>
</cfsavecontent>
<cfreturn tableXML>
</cffunction>

<cffunction name="hasChanges" access="private" returntype="boolean" output="no">
	<cfargument name="query" type="query" required="yes">
	<cfargument name="args" type="struct" required="yes">
	
	<cfset var cols = query.ColumnList>
	<cfset var col = "">
	<cfset var key = "">
	<cfset var result = false>
	
	<cfloop collection="#args#" item="key">
		<cfif ListFindNoCase(cols,key)>
			<cfif query[key][1] neq args[key]>
				<cfset result = true>
			</cfif>
		</cfif>
	</cfloop>
	
	<cfreturn result>
</cffunction>

</cfcomponent>