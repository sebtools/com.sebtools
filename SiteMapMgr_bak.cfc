<cfcomponent displayname="Site Map Manager">

<cffunction name="init" access="public" returntype="SiteMapMgr" output="no" hint="I initialize and return this object.">
	<cfargument name="SiteMap" type="com.sebtools.SiteMap" required="yes">
	<cfargument name="DataMgr" type="any" required="yes">
	<cfargument name="FilePath" type="string" required="yes">
	
	<cfscript>
	variables.FileLib = CreateObject("component","FileLib");
	variables.FilePath = arguments.FilePath;
	variables.SiteMap = arguments.SiteMap;
	variables.DataMgr = arguments.DataMgr;
	variables.datasource = variables.DataMgr.getDatasource();
	variables.DataMgr.loadXML(getDbXml(),true,true);
	variables.SitePages = QueryNew('URL,Title');
	//loadFile();
	</cfscript>
	
	<cfreturn this>
</cffunction>

<cffunction name="getPage" access="public" returntype="query" output="no" hint="I get a page with the given PageID.">
	<cfargument name="PageID" type="numeric" required="no">
	
	<cfreturn variables.DataMgr.getRecord('smapPages',arguments)>
</cffunction>

<cffunction name="getPages" access="public" returntype="query" output="no" hint="I get page for the given section.">
	<cfargument name="SectionID" type="numeric" required="yes">
	
	<cfset var qPages = 0>
	
	<!--- <cfreturn variables.DataMgr.getRecords('smapPages',arguments)> --->
	
	<cfquery name="qPages" datasource="#variables.datasource#">
	SELECT		PageID,ordernum,PageName,PageLabel,PageURL
	FROM		smapPages
	WHERE		1 = 1
	<cfif StructKeyExists(arguments,"SectionID")>
		AND		SectionID = <cfqueryparam value="#arguments.SectionID#" cfsqltype="CF_SQL_INTEGER">
	<cfelse>
		AND		SectionID IS NULL
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
	<cfargument name="SectionID" type="numeric" required="no">
	
	<cfreturn variables.DataMgr.getRecord('smapSections',arguments)>
</cffunction>

<cffunction name="getSections" access="public" returntype="query" output="no" hint="I get a section with the given SectionID.">
	<cfargument name="ParentSectionID" type="numeric" required="no">
	
	<cfset var qSections = 0>
	<cfset var qParentSection = 0>
	
	<cfif StructKeyExists(arguments,"ParentSectionID")>
		<cfset qParentSection = getSection(arguments.ParentSectionID)>
	</cfif>
	
	<cfquery name="qSections" datasource="#variables.datasource#">
	SELECT		SectionID,ordernum,SectionName,SectionLabel,
				<cfif StructKeyExists(arguments,"ParentSectionID")>('#qParentSection.SectionLabel# -&gt; ' + SectionLabel)<cfelse>SectionLabel</cfif> AS SectionLabelExt
	FROM		smapSections
	WHERE		1 = 1
	<cfif StructKeyExists(arguments,"ParentSectionID")>
		AND		ParentSectionID = <cfqueryparam value="#arguments.ParentSectionID#" cfsqltype="CF_SQL_INTEGER">
	<cfelse>
		AND		ParentSectionID IS NULL
	</cfif>
	ORDER BY	ordernum
	</cfquery>

	<cfreturn qSections>
</cffunction>

<cffunction name="getAllSections" access="public" returntype="query" output="no" hint="I get a section with the given SectionID.">
	
	<cfset var qBaseSections = getSections()>
	<cfset var cols = qBaseSections.ColumnList>
	<cfset var qSections = QueryNew(cols)>
	<cfset var sSubQeries = StructNew()>
	<cfset var key = "">
	<cfset var col = "">
	
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
		OR		Pages.SectionID = Subsections.SectionID
	WHERE		Sections.ParentSectionID IS NULL
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
	
	<cfset var qData = getData()>
	<cfset var result = "">
	<cfset var SectionPages = StructNew()>

<cfsavecontent variable="result"><cfoutput><?xml version="1.0" encoding="utf-8"?></cfoutput>
<cfoutput><site></cfoutput><cfoutput query="qData" group="SectionID">
	<section name="#SectionName#" label="#SectionLabel#" url="#SectionURL#"<cfif Len(SectionPermissions)> permissions="#SectionPermissions#"</cfif>><cfset SectionPages[SectionID] = ""><cfoutput><cfif (PageSectionID eq SectionID) AND NOT ListFindNoCase(SectionPages[SectionID],PageID)>
		<page<cfif Len(PageName)> name="#PageName#"</cfif> label="#PageLabel#" url="#PageURL#"<cfif Len(onMenu) AND isBoolean(onMenu)> onMenu="<cfif onMenu>true<cfelse>false</cfif>"</cfif><cfif Len(PagePermissions)> permissions="#PagePermissions#"</cfif> /><cfset SectionPages[SectionID] = ListAppend(SectionPages[SectionID],PageID)></cfif></cfoutput><cfoutput group="SubsectionID"><cfif Len(SubsectionName) OR Len(SubsectionLabel) OR Len(SubsectionURL)>
		<subsection name="#SubsectionName#" label="#SubsectionLabel#" url="#SubsectionURL#"<cfif Len(SubsectionPermissions)> permissions="#SubsectionPermissions#"</cfif>><cfoutput><cfif PageSectionID eq SubsectionID>
			<page<cfif Len(PageName)> name="#PageName#"</cfif> label="#PageLabel#" url="#PageURL#"<cfif Len(Trim(onMenu))> onMenu="<cfif onMenu eq 1>true<cfelse>false</cfif>"</cfif><cfif Len(PagePermissions)> permissions="#PagePermissions#"</cfif> /></cfif></cfoutput>
		</subsection></cfif></cfoutput>
	</section></cfoutput>
<cfoutput></site></cfoutput></cfsavecontent>
	
	<cfreturn result>
</cffunction>

<cffunction name="loadFile" access="public" returntype="void" output="no" hint="I load data into the database from the Site Map XML file.">
	
	<cfset var XmlString = "">
	<cfset var XmlData = 0>
	<cfset var i = 0>
	<cfset var j = 0>
	<cfset var k = 0>
	
	<cfset var curr = 0>
	<cfset var arrTop = ArrayNew(1)>
	<cfset var arrMiddle = ArrayNew(1)>
	<cfset var arrLast = ArrayNew(1)>
	<cfset var SectionID = "">
	<cfset var SubsectionID = "">
	
	<cffile action="READ" file="#variables.FilePath#" variable="XmlString">
	
	<cfset XmlData = XmlParse(XmlString)>
	
	<cfset arrTop = XmlData.XmlRoot.XmlChildren>
	
	<!--- Clear Data --->
	<cfset clearData()>
	
	<!--- Save data from XML file --->
	<!---  Loop through sections --->
	<cfloop index="i" from="1" to="#ArrayLen(arrTop)#" step="1">
		<cfset curr = arrTop[i]>
		<cfset SectionID = "">
		<cfif curr.XmlName eq "section">
			<!--- Save section --->
			<cfinvoke method="saveSection" returnvariable="SectionID">
				<cfif StructKeyExists(curr.XmlAttributes,"name")>
					<cfinvokeargument name="SectionName" value="#curr.XmlAttributes.name#">
				</cfif>
				<cfif StructKeyExists(curr.XmlAttributes,"label")>
					<cfinvokeargument name="SectionLabel" value="#curr.XmlAttributes.label#">
				</cfif>
				<cfif StructKeyExists(curr.XmlAttributes,"url")>
					<cfinvokeargument name="SectionURL" value="#curr.XmlAttributes.url#">
				</cfif>
				<cfif StructKeyExists(curr.XmlAttributes,"permissions")>
					<cfinvokeargument name="Permissions" value="#curr.XmlAttributes.permissions#">
				</cfif>
			</cfinvoke>
		</cfif>
		<cfif curr.XmlName eq "page">
			<!--- Save page --->
			<cfinvoke method="savePage">
				<cfif StructKeyExists(curr.XmlAttributes,"name")>
					<cfinvokeargument name="PageName" value="#curr.XmlAttributes.name#">
				</cfif>
				<cfif StructKeyExists(curr.XmlAttributes,"label")>
					<cfinvokeargument name="PageLabel" value="#curr.XmlAttributes.label#">
				</cfif>
				<cfif StructKeyExists(curr.XmlAttributes,"url")>
					<cfinvokeargument name="PageURL" value="#curr.XmlAttributes.url#">
				</cfif>
				<cfif StructKeyExists(curr.XmlAttributes,"onMenu")>
					<cfinvokeargument name="onMenu" value="#curr.XmlAttributes.onMenu#">
				</cfif>
				<cfif StructKeyExists(curr.XmlAttributes,"permissions")>
					<cfinvokeargument name="Permissions" value="#curr.XmlAttributes.permissions#">
				</cfif>
			</cfinvoke>
		</cfif>
		<cfif StructKeyExists(curr,"XmlChildren") AND ArrayLen(curr.XmlChildren)>
			<cfset arrMiddle = curr.XmlChildren>
			<!---  Loop through subsections --->
			<cfloop index="j" from="1" to="#ArrayLen(arrMiddle)#" step="1">
				<cfset curr = arrMiddle[j]>
				<cfset SubsectionID = "">
				<cfif curr.XmlName eq "subsection">
					<!--- Save subsection --->
					<cfinvoke method="saveSection" returnvariable="SubsectionID">
						<cfinvokeargument name="ParentSectionID" value="#SectionID#">
						<cfif StructKeyExists(curr.XmlAttributes,"name")>
							<cfinvokeargument name="SectionName" value="#curr.XmlAttributes.name#">
						</cfif>
						<cfif StructKeyExists(curr.XmlAttributes,"label")>
							<cfinvokeargument name="SectionLabel" value="#curr.XmlAttributes.label#">
						</cfif>
						<cfif StructKeyExists(curr.XmlAttributes,"url")>
							<cfinvokeargument name="SectionURL" value="#curr.XmlAttributes.url#">
						</cfif>
						<cfif StructKeyExists(curr.XmlAttributes,"permissions")>
							<cfinvokeargument name="Permissions" value="#curr.XmlAttributes.permissions#">
						</cfif>
					</cfinvoke>
				</cfif>
				<cfif curr.XmlName eq "page">
					<!--- Save page --->
					<cfinvoke method="savePage">
						<cfinvokeargument name="SectionID" value="#SectionID#">
						<cfif StructKeyExists(curr.XmlAttributes,"name")>
							<cfinvokeargument name="PageName" value="#curr.XmlAttributes.name#">
						</cfif>
						<cfif StructKeyExists(curr.XmlAttributes,"label")>
							<cfinvokeargument name="PageLabel" value="#curr.XmlAttributes.label#">
						</cfif>
						<cfif StructKeyExists(curr.XmlAttributes,"url")>
							<cfinvokeargument name="PageURL" value="#curr.XmlAttributes.url#">
						</cfif>
						<cfif StructKeyExists(curr.XmlAttributes,"onMenu")>
							<cfinvokeargument name="onMenu" value="#curr.XmlAttributes.onMenu#">
						</cfif>
						<cfif StructKeyExists(curr.XmlAttributes,"permissions")>
							<cfinvokeargument name="Permissions" value="#curr.XmlAttributes.permissions#">
						</cfif>
					</cfinvoke>
				</cfif>
				<cfif StructKeyExists(curr,"XmlChildren") AND ArrayLen(curr.XmlChildren)>
					<cfset arrLast = curr.XmlChildren>
					<!---  Loop through pages --->
					<cfloop index="k" from="1" to="#ArrayLen(arrLast)#" step="1">
						<cfset curr = arrLast[k]>
						<!--- Save page --->
						<cfinvoke method="savePage">
							<cfinvokeargument name="SectionID" value="#SubsectionID#">
							<cfif StructKeyExists(curr.XmlAttributes,"name")>
								<cfinvokeargument name="PageName" value="#curr.XmlAttributes.name#">
							</cfif>
							<cfif StructKeyExists(curr.XmlAttributes,"label")>
								<cfinvokeargument name="PageLabel" value="#curr.XmlAttributes.label#">
							</cfif>
							<cfif StructKeyExists(curr.XmlAttributes,"url")>
								<cfinvokeargument name="PageURL" value="#curr.XmlAttributes.url#">
							</cfif>
							<cfif StructKeyExists(curr.XmlAttributes,"onMenu")>
								<cfinvokeargument name="onMenu" value="#curr.XmlAttributes.onMenu#">
							</cfif>
							<cfif StructKeyExists(curr.XmlAttributes,"permissions")>
								<cfinvokeargument name="Permissions" value="#curr.XmlAttributes.permissions#">
							</cfif>
						</cfinvoke>
					</cfloop>
					<!--- /Loop through pages --->
				</cfif>
			</cfloop>
			<!--- /Loop through subsections --->
		</cfif>
	</cfloop>
	<!--- /Loop through sections --->
	
	<!--- Remove stuff that doesn't exist in XML file. --->
	
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
			<cfif StructKeyExists(arguments,"ParentSectionID")>
				<cfinvokeargument name="ParentSectionID" value="#arguments.ParentSectionID#">
			</cfif>
			<cfinvokeargument name="ordernum" value="#i#">
		</cfinvoke>
	</cfloop>
	
	<cfset updateSiteMap()>
	
</cffunction>

<cffunction name="removePage" access="public" returntype="void" output="no" hint="I remove the given page.">
	<cfargument name="PageID" type="numeric" required="yes">
	
	<cfset variables.DataMgr.deleteRecord('smapPages',arguments)>
	
	<cfset updateSiteMap()>
	
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
	
	<!--- Set default ordernum --->
	<cfif NOT StructKeyExists(arguments,"ordernum")>
		<cfinvoke method="getNewPageOrderNum" returnvariable="arguments.ordernum">
			<cfif StructKeyExists(arguments,"SectionID")>
				<cfinvokeargument name="SectionID" value="#arguments.SectionID#">
			</cfif>
		</cfinvoke>
	</cfif>
	
	<!--- Get Page title --->
	<cfif StructKeyExists(arguments,"PageURL") AND NOT StructKeyExists(arguments,"PageLabel")>
		<cfset arguments.PageLabel = getTitleFromUrl(arguments.PageURL)>
	</cfif>
	
	<!--- Update site map for new page --->
	<cfif NOT StructKeyExists(arguments,"PageID")>
		<cfset doUpdate = true>
	</cfif>
	
	<!--- Save this page --->
	<cfset arguments.PageID = variables.DataMgr.saveRecord('smapPages',arguments)>
	
	<!--- Set permissions for this page --->
	<!--- %%Need to convert to list of ids first --->
	<!--- <cfif StructKeyExists(arguments,"Permissions")>
		<cfset variables.DataMgr.saveRelationList('smapPages2Permissions','PageID',arguments.PageID,'PermissionID',arguments.Permissions)>
	</cfif> --->
	
	<cfif doUpdate>
		<cfset updateSiteMap()>
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
	
	<cfset var qParentSection = 0>
	<cfset var doUpdate = false>
	
	<cfif NOT StructKeyExists(arguments,"ordernum")>
		<cfif StructKeyExists(arguments,"ParentSectionID")>
			<cfset arguments.ordernum = getNewSectionOrderNum(arguments.ParentSectionID)>
		<cfelse>
			<cfset arguments.ordernum = getNewSectionOrderNum()>
		</cfif>
	</cfif>
	
	<!--- A section can have a parent, but no grandparent --->
	<cfif StructKeyExists(arguments,"ParentSectionID") AND isNumeric(arguments.ParentSectionID)>
		<cfset qParentSection = getSection(arguments.ParentSectionID)>
		
		<cfif qParentSection.RecordCount eq 0>
			<cfthrow message="Indicated Parent Section doesn't exist.">
		</cfif>
		
		<cfif Len(qParentSection.ParentSectionID)>
			<cfthrow message="A section cannot be a child of a section that is not a top-level section.">
		</cfif>
	</cfif>
	
	<!--- Update site map for new page --->
	<cfif NOT StructKeyExists(arguments,"SectionID")>
		<cfset doUpdate = true>
	</cfif>
	
	<!--- Save this section --->
	<cfset arguments.SectionID = variables.DataMgr.saveRecord('smapSections',arguments)>
	
	<!--- Set permissions for this section --->
	<!--- %%Need to convert to list of ids first --->
	<!--- <cfif StructKeyExists(arguments,"Permissions")>
		<cfset variables.DataMgr.saveRelationList('smapSections2Permissions','SectionID',arguments.SectionID,'PermissionID',arguments.Permissions)>
	</cfif> --->
	
	<cfif doUpdate>
		<cfset updateSiteMap()>
	</cfif>
	
	<cfreturn arguments.SectionID>
</cffunction>

<cffunction name="write" access="public" returntype="void" output="no" hint="I save the XML file with the current data.">
	<cflock timeout="40" throwontimeout="No" name="SiteMapFileWrite" type="EXCLUSIVE">
		<cffile action="WRITE" file="#variables.FilePath#" output="#getXml()#" addnewline="no">
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
	<!--- %%Need to finish this method --->
	<cfset var qTempFiles = variables.FileLib.directoryList(directory=arguments.SiteRootPath,recurse=true)>
	<cfset var qReturnFiles = 0>
	
	<cfoutput query="qTempFiles">
		
	</cfoutput>
	
	<cfdirectory action="LIST" directory="s" name="qTempFiles">
	
</cffunction>

<cffunction name="getSitePages" access="public" returntype="query" output="no">
	<cfargument name="SiteRootPath" type="string" required="yes">
	<cfargument name="ExcludeDirs" type="string" required="yes">
	<!--- !! Will usually be over-ridden by a local version of same method !! --->
	<cfset var result = getSiteFiles(SiteRootPath,ExcludeDirs)>
	
	<cfset variables.SitePages = result>
	
	<cfreturn result>
</cffunction>

<cffunction name="getTitleFromUrl" access="public" returntype="string" output="no">
	<cfargument name="URL" type="string" required="yes">
	
	<cfset var qSitePages = variables.SitePages>
	<cfset var qFindPage = 0>
	<cfset var result = "">
	
	<cfquery name="qFindPage" dbtype="query">
	SELECT	Title
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
		<field ColumnName="ordernum" CF_DataType="CF_SQL_INTEGER" />
		<field ColumnName="SectionName" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="SectionLabel" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="SectionURL" CF_DataType="CF_SQL_VARCHAR" Length="240" />
		<field ColumnName="Permissions" CF_DataType="CF_SQL_VARCHAR" Length="250" />
	</table>
	<table name="smapPages">
		<field ColumnName="PageID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
		<field ColumnName="SectionID" CF_DataType="CF_SQL_INTEGER" />
		<field ColumnName="ordernum" CF_DataType="CF_SQL_INTEGER" />
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

</cfcomponent>