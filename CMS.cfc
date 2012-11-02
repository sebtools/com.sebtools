<!--- 0.1 Build 1 --->
<cfcomponent displayname="Content Management System" hint="I manage the content and pages for a site.">

<cffunction name="init" access="public" returntype="any" output="no" hint="I initialize and return this object.">
	<cfargument name="DataMgr" type="any" required="yes" hint="An instantiated DataMgr component.">
	<cfargument name="RootPath" type="string" hint="The absolute path to the root directory in which any files should be saved.">
	<cfargument name="createDefaultSection" type="boolean" default="true">
	<cfargument name="SiteMapMgr" type="any" required="no" hint="An instantiated SiteMapMgr component.">
	<cfargument name="skeleton" type="string" default="">
	<cfargument name="OnlyOverwriteCMS" type="boolean" default="true">
	
	<!--- Copy initialization arguments to variables so that they will be persistant with component but not available outside component --->
	<cfscript>
	var fileObj = createObject("java", "java.io.File");
	var qSiteVersions = 0;
	var qSections = 0;
	
	variables.DataMgr = arguments.DataMgr;
	variables.OnlyOverwriteCMS = arguments.OnlyOverwriteCMS;
	
	variables.datasource = variables.DataMgr.getDatasource();
	variables.DataMgr.loadXML(getDbXml(),true,true);
	if ( StructKeyExists(arguments,"RootPath") ) {
		variables.RootPath = arguments.RootPath;
	}
	if ( StructKeyExists(arguments,"SiteMapMgr") ) {
		variables.SiteMapMgr = arguments.SiteMapMgr;
	}
	variables.skeleton = arguments.skeleton;
	
	variables.dirdelim = fileObj.separator;// file delim of "/" or "\" depending on system.
	</cfscript>
	
	<!--- Make sure at least one site version exists --->
	<!--- <cfquery name="qSiteVersions" datasource="#variables.datasource#">
	SELECT	SiteVersionID
	FROM	cmsSiteVersions
	</cfquery> --->
	<cfset qSiteVersions = variables.DataMgr.getRecords(tablename="cmsSiteVersions",fieldlist="SiteVersionID")>
	
	<cfif qSiteVersions.RecordCount eq 0>
		<cfinvoke method="setSiteVersion">
			<cfinvokeargument name="SiteName" value="main">
			<cfinvokeargument name="isDefault" value="True">
		</cfinvoke>
	</cfif>
	
	<!--- Make sure at least one section exists --->
	<!--- <cfquery name="qSections" datasource="#variables.datasource#">
	SELECT	SectionID
	FROM	cmsSections
	</cfquery> --->
	<cfset qSections = variables.DataMgr.getRecords(tablename="cmsSections",fieldlist="SectionID")>
	
	<cfif arguments.createDefaultSection AND qSections.RecordCount eq 0>
		<cfinvoke method="setSection">
			<cfinvokeargument name="SectionTitle" value="main">
		</cfinvoke>
	</cfif>
	
	<!--- If SiteMapMgr is passed, set some observers on it --->
	<cfscript>
	if ( StructKeyExists(variables,"SiteMapMgr") ) {
		variables.SiteMapMgr.addObserver('savePage',this,'com.sebtools.CMS','mapSavePage');
		variables.SiteMapMgr.addObserver('saveSection',this,'com.sebtools.CMS','mapSaveSection');
		variables.SiteMapMgr.addObserver('removeSection',this,'com.sebtools.CMS','mapRemoveSection');
		variables.SiteMapMgr.addPagesQuery(this,'getAllPages','com.sebtools.CMS.getAllPages','Title','UrlPath');
	}
	</cfscript>
	
	<cfreturn this>
</cffunction>

<cffunction name="getDatasource" access="public" returntype="string" output="no">
	<cfreturn variables.datasource> 
</cffunction>

<cffunction name="deletePage" access="public" returntype="void" output="no">
	<cfargument name="PageID" type="numeric" required="yes">
	
	<cfif variables.DataMgr.getDatabase() NEQ "Sim">
		<cfquery datasource="#variables.datasource#">
		UPDATE	cmsPages
		SET		isDeleted = 1
		WHERE	PageID = #Val(arguments.PageID)#
		</cfquery>
	</cfif>
	
</cffunction>

<cffunction name="deleteSection" access="public" returntype="void" output="no">
	<cfargument name="SectionID" type="numeric" required="yes">
	
	<cfset var qPages = getPages(arguments.SectionID)>
	<cfset var qSubsections = getSections(arguments.SectionID)>
	
	<cfif NOT (qPages.RecordCount OR qSubsections.RecordCount)>
		<cfset variables.DataMgr.deleteRecord('cmsSections',arguments)>
	</cfif>
	
</cffunction>

<cffunction name="getFullFilePath" access="public" returntype="string">
	<cfargument name="SectionID" type="numeric" required="yes">
	<cfargument name="FileName" type="string" required="yes">
	
	<cfset var result = variables.RootPath & getSectionPath(SectionID) & FileName>
	
	<cfreturn result>
</cffunction>

<cffunction name="getPage" access="public" returntype="query" output="no" hint="I get all of the information for the given page.">
	<cfargument name="PageID" type="numeric" required="yes">
	<cfargument name="SiteVersionID" type="numeric" required="no">
	<cfargument name="PageVersionID" type="numeric" required="no">
	
	<cfset var qPage = QueryNew('PageID,PageName,FileName,SectionID,Title,Description,Keywords,Contents,Contents2')>
	<cfset var result = StructNew()>
	<cfset var path = "">
	<cfset var contentFixed = "">
	
	<cfquery name="qPage" datasource="#variables.DataSource#">
	SELECT		TOP 1
				cmsPages.PageID,PageName,FileName,SectionID,
				cmsPageVersions.Title,cmsPageVersions.Description,cmsPageVersions.Keywords,cmsPageVersions.Contents,cmsPageVersions.Contents2,ImageFileName,
				'' AS FullFilePath, '' AS UrlPath, FileName AS FileNameOld,
				cmsPageVersions.WhenCreated AS Updated,
				MapPageID,
				TemplateID
	FROM		cmsPages,
				cmsPages2Versions,
				cmsPageVersions,
				cmsSiteVersions
	WHERE		cmsPages.PageID = #Val(arguments.PageID)#
		AND		cmsPages.PageID = cmsPages2Versions.PageID
		AND		cmsPages.isDeleted = 0
	<cfif Not StructKeyExists(arguments,"PageVersionID")>
		AND		cmsPages2Versions.PageVersionID = cmsPageVersions.PageVersionID
	</cfif>
		AND		(
					cmsPages2Versions.SiteVersionID = cmsSiteVersions.SiteVersionID
				OR	(
						cmsPages2Versions.SiteVersionID IS NULL
					AND	cmsSiteVersions.isDefault = 1
					)
				)
	<cfif StructKeyExists(arguments,"PageVersionID")>
		AND		cmsPageVersions.PageVersionID = #Val(arguments.PageVersionID)#
	<cfelse>
		AND 	(
					cmsSiteVersions.isDefault = 1
				<cfif StructKeyExists(arguments,"SiteVersionID")>
				OR	cmsSiteVersions.SiteVersionID = #Val(arguments.SiteVersionID)#
				</cfif>
				)
	</cfif>
	ORDER BY	isDefault
	</cfquery>
	
	<cfoutput query="qPage">
		<cfset QuerySetCell(qPage, "FullFilePath", getFullFilePath(SectionID,FileName), CurrentRow)>
		<cfset path = getUrlPath(qPage.SectionID[CurrentRow],qPage.FileName[CurrentRow])>
		<cfset QuerySetCell(qPage, "UrlPath", path, CurrentRow)>
		
		<!--- Strip out some junk MS styling --->
		<cfset contentFixed = Contents>
		<cfset contentFixed = ReReplaceNoCase(contentFixed, '<span([^>]*) style="FONT-SIZE[^"]*"([^>]*)>', "<span\1\2>", "all")>
		<cfset contentFixed = ReReplaceNoCase(contentFixed, '<div([^>]*) style="MARGIN[^"]*"([^>]*)>', "<div\1\2>", "all")>
		<cfset QuerySetCell(qPage, "Contents", contentFixed, CurrentRow)>
	</cfoutput>
	
	<cfset result = queryRowToStruct(qPage)>
	
	<cfreturn qPage>
</cffunction>

<cffunction name="getUrlPath" access="public" returntype="string" output="no">
	<cfargument name="SectionID" type="numeric" required="yes">
	<cfargument name="FileName" type="string" required="yes">
	
	<cfset var result = ReplaceNoCase(getSectionPath(arguments.SectionID), variables.dirdelim, "/", "ALL") & arguments.FileName>
	
	<cfif Left(result,1) neq "/">
		<cfset result = "/" & result>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getAllPages" access="public" returntype="query" output="no" hint="I return all of the pages in the given section.">
	<cfargument name="skeleton" type="string" required="no" hint="The HTML skeleton to feed the contents of the page into. The name of any field can be placed in brackets and will be replaced by the contents of that field for the given page. For example, to place the contents of the page, use [Contents] as place-holder.">

	<cfset var qPages = 0>
	
	<cfif variables.Datamgr.getDatabase() EQ "Sim">
		<cfset qPages = variables.DataMgr.getRecords("cmsPages")>
	<cfelse>
		<cfquery name="qPages" datasource="#variables.datasource#">
		SELECT		cmsPages.PageID,SectionID,PageName,FileName,
					cmsPageVersions.Title,cmsPageVersions.Description,cmsPageVersions.Keywords,cmsPageVersions.Contents,cmsPageVersions.Contents2,
					'' AS FileOutput, '' AS FullFilePath, '' AS UrlPath
		FROM		cmsPages
		INNER JOIN	cmsPages2Versions
			ON		cmsPages.PageID = cmsPages2Versions.PageID
		INNER JOIN	cmsPageVersions
			ON		cmsPages2Versions.PageVersionID = cmsPageVersions.PageVersionID
		INNER JOIN	cmsSiteVersions
			ON		cmsPages2Versions.SiteVersionID = cmsSiteVersions.SiteVersionID
					OR	cmsPages2Versions.SiteVersionID IS NULL
		WHERE		cmsSiteVersions.isDefault = 1
			AND		cmsPages.isDeleted = 0
		</cfquery>
		
		<cfoutput query="qPages">
			<cfset QuerySetCell(qPages, "FullFilePath", variables.RootPath & getSectionPath(SectionID) & FileName, CurrentRow)>
			<cfset QuerySetCell(qPages, "UrlPath", getUrlPath(SectionID,FileName), CurrentRow)>
			<cfif StructKeyExists(arguments,"skeleton")>
				<cfset QuerySetCell(qPages, "FileOutput", arguments.skeleton, CurrentRow)>
				<cfloop index="col" list="#ColumnList#">
					<cfset QuerySetCell(qPages, "FileOutput", ReplaceNoCase(FileOutput, "[#col#]", qPages[col][CurrentRow], "ALL"), CurrentRow)>
				</cfloop>
			</cfif>
		</cfoutput>
	</cfif>
	
	<cfreturn qPages>
</cffunction>

<cffunction name="getPages" access="public" returntype="query" output="no" hint="I return all of the pages in the given section.">
	<cfargument name="SectionID" type="numeric" required="yes">
	
	<cfset var qPages = 0>
	
	<cfif variables.DataMgr.getDatabase() EQ "Sim">
		<cfset qPages = variables.DataMgr.getRecords('cmsPages',arguments)>
	<cfelse>
		<cfquery name="qPages" datasource="#variables.datasource#">
		SELECT		cmsPages.PageID,SectionID,PageName,FileName,
					cmsPages.Title
		FROM		cmsPages
		INNER JOIN	cmsPages2Versions
			ON		cmsPages.PageID = cmsPages2Versions.PageID
		INNER JOIN	cmsPageVersions
			ON		cmsPages2Versions.PageVersionID = cmsPageVersions.PageVersionID
		WHERE		cmsPages.isDeleted = 0
		<cfif arguments.SectionID gt 0>
			AND		SectionID = <cfqueryparam value="#arguments.SectionID#" cfsqltype="CF_SQL_INTEGER">
		<cfelse>
			AND		(
						SectionID = 0
					OR	SectionID IS NULL
					)
		</cfif>
		<!--- WHERE		cmsSiteVersions.isDefault = 1 --->
		<!--- WHERE		cmsPages.PageID = <cfqueryparam value="#arguments.PageID#" cfsqltype="CF_SQL_INTEGER"> --->
		</cfquery>
	</cfif>
	
	<!--- <cfset var qPages = variables.DataMgr.getRecords('cmsPages',arguments)> --->
	
	<cfreturn qPages>
</cffunction>

<cffunction name="getPageVersions" access="public" returntype="query" output="no" hint="I return every version (archived and current) for the given page.">
	<cfargument name="PageID" type="numeric" required="yes">
	<cfargument name="SiteVersionID" type="numeric">
	
	<cfset var qVersions = variables.DataMgr.getRecords('cmsPageVersions',arguments)>
	
	<cfif qVersions.RecordCount AND Not Len(qVersions.VersionDescription[1])>
		<cfset QuerySetCell(qVersions, "VersionDescription", "(original)", 1)>
	</cfif>
	
	<cfreturn qVersions>
</cffunction>

<cffunction name="getTopSectionID" access="public" returntype="numeric" output="no">
	<cfargument name="SectionID" type="numeric" default="0">
	
	<cfset var qSection = getSection(arguments.SectionID)>
	<cfset var result = qSection.SectionID>
	<cfset var prevresult = 0>
	
	<cfif isNumeric(qSection.ParentSectionID) AND qSection.ParentSectionID GT 0>
		<cfloop condition="prevresult NEQ result">
			<cfset prevresult = result>
			<cfset result = getTopSectionID(qSection.ParentSectionID)>
		</cfloop>
	</cfif>
	
	<cfreturn Val(result)>
</cffunction>

<cffunction name="getSection" access="public" returntype="query" output="no">
	<cfargument name="SectionID" type="numeric" default="0">
	
	<cfset var qParentSection = 0>
	<cfset var qSection = variables.DataMgr.getRecord("cmsSections",arguments)>
	
	<cfif qSection.RecordCount>
		<cfif Len(qSection.ParentSectionID) AND qSection.ParentSectionID GT 0>
			<cfset qParentSection = getSection(qSection.ParentSectionID)>
			<cfset QuerySetCell(qSection, "SectionLabelExt", "#qParentSection.SectionLabelExt# --&gt; #qSection.SectionTitle#")>
		<cfelse>
			<cfset QuerySetCell(qSection, "SectionLabelExt", "#qSection.SectionTitle#")>
		</cfif>
	</cfif>
	
	<!--- <cfif StructKeyExists(arguments,"SectionID")>
		<cfquery name="qSection" datasource="#variables.DataSource#">
		SELECT	SectionID,ParentSectionID,SectionTitle,Description,Keywords,
				SectionDir,SectionLink,
				MapSectionID
		FROM	cmsSections
		WHERE	SectionID = #Val(arguments.SectionID)#
		</cfquery>
	</cfif>

	<cfreturn qSection> --->
	<cfreturn qSection>
</cffunction>

<cffunction name="getSectionPath" access="public" returntype="string" output="no">
	<cfargument name="SectionID" type="numeric" required="yes">
	
	<cfset var qSection = variables.DataMgr.getRecord('cmsSections',arguments)>
	<cfset var result = qSection.SectionDir>
	
	<cfif Len(qSection.ParentSectionID) AND qSection.ParentSectionID gt 0>
		<cfset result = getSectionPath(qSection.ParentSectionID) & result>
	</cfif>
	
	<cfif Len(result)>
		<cfset result = result & variables.dirdelim>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSections" access="public" returntype="query" output="no">
	<cfargument name="ParentSectionID" type="numeric" required="no">
	
	<cfset var qParentSection = 0>
	<cfset var qSections = 0>
	
	<cfif variables.DataMgr.getDatabase() EQ "Sim">
		<cfset qSections = variables.DataMgr.getRecords("cmsSections",arguments)>
	<cfelse>
		<cfquery name="qSections" datasource="#variables.datasource#">
		SELECT		SectionID, SectionTitle, OrderNum, '' AS SectionLabelExt, ParentSectionID, SectionLink, Description
		FROM		cmsSections
		WHERE		( isDeleted = 0 OR isDeleted IS NULL )
		<cfif StructKeyExists(arguments,"ParentSectionID")>
			<cfif arguments.ParentSectionID GT 0>
			AND		ParentSectionID = #Val(arguments.ParentSectionID)#
			<cfelse>
			AND		(ParentSectionID IS NULL OR ParentSectionID = 0)
			</cfif>
		</cfif>
		ORDER BY	OrderNum,SectionTitle
		</cfquery>
	</cfif>
	
	<cfloop query="qSections">
		<cfif Len(ParentSectionID)>
			<cfset qParentSection = getSection(ParentSectionID)>
			<cfset QuerySetCell(qSections, "SectionLabelExt", "#qParentSection.SectionLabelExt# --&gt; #SectionTitle#",CurrentRow)>
		<cfelse>
			<cfset QuerySetCell(qSections, "SectionLabelExt", "#SectionTitle#",CurrentRow)>
		</cfif>
	</cfloop>
	
	<cfreturn qSections>
</cffunction>

<cffunction name="getSiteVersionID" access="public" returntype="numeric" output="no" hint="I get the SiteVersionID based on the domain name or site name (which may be the language of the site).">
	<cfargument name="SiteName" type="string" hint="The name of the site or the language being used.">
	<cfargument name="DomainName" type="string" hint="the domain name.">
	
	<cfset var qSiteVersion = 0>
	<cfset var result = 0>
	
	<cfquery name="qSiteVersion" datasource="#variables.datasource#">
	SELECT		TOP 1 SiteVersionID
	FROM		cmsSiteVersions
	WHERE		isDefault = 1
		OR		(
					1 = 1
				<cfif StructKeyExists(arguments,"SiteName")>
					AND	SiteName = <cfqueryparam value="#arguments.SiteName#" cfsqltype="CF_SQL_VARCHAR">
				</cfif>
				<cfif StructKeyExists(arguments,"DomainName")>
					AND	DomainRoot LIKE <cfqueryparam value="%#arguments.DomainName#%" cfsqltype="CF_SQL_VARCHAR">
				</cfif>
				)
	ORDER BY	isDefault
	</cfquery>
	
</cffunction>

<cffunction name="hasMenuMgr" access="private" returntype="boolean" output="no" hint="I determine if a SiteMapMgr is associated with this CMS.">
	<cfreturn isDefined("variables.SiteMapMgr")>
</cffunction>

<cffunction name="makeFiles" access="public" returntype="void" output="no" hint="I make a file for each active page. Each file will be placed in the RootPath given to this component (or a subdirectory thereof).">
	<cfargument name="skeleton" type="string" required="yes" hint="The HTML skeleton to feed the contents of the page into. The name of any field can be placed in brackets and will be replaced by the contents of that field for the given page. For example, to place the contents of the page, use [Contents] as place-holder.">
	<cfargument name="overwrite" type="boolean" default="true" hint="Should an existing file be overwritten. If false, makeFiles() will not create a file if it already exists.">
	
	<cfset writeFiles(skeleton=skeleton,overwrite=overwrite)>
	
</cffunction>

<cffunction name="restoreVersion" access="public" returntype="any" output="no" hint="I restore an old version of a page.">
	<cfargument name="PageID" type="numeric" required="yes" hint="The PageID of the page being restored.">
	<cfargument name="PageVersionID" type="numeric" required="yes" hint="The PageVersion ID of the version being restored.">
	<cfargument name="SiteVersionID" type="numeric" required="no" hint="The Site Version for this page. Use as default if left blank.">
	
	<!--- Make this version the live version --->
	<cfquery datasource="#variables.datasource#">
	INSERT INTO cmsPages2Versions
	SELECT	#Val(arguments.PageID)#,
			<cfif StructKeyExists(arguments,"SiteVersionID")>#Val(arguments.SiteVersionID)#<cfelse>NULL</cfif>,
			#Val(arguments.PageVersionID)#
	WHERE	NOT EXISTS (
				SELECT	PageVersionID
				FROM	cmsPages2Versions
				WHERE	PageID = #Val(arguments.PageID)#
				<cfif StructKeyExists(arguments,"SiteVersionID")>
					AND	SiteVersionID = #Val(arguments.SiteVersionID)#
				<cfelse>
					AND	SiteVersionID IS NULL
				</cfif>
			)
	</cfquery>
	<cfquery datasource="#variables.datasource#">
	UPDATE	cmsPages2Versions
	SET		PageVersionID = #Val(arguments.PageVersionID)#
	WHERE	PageID = #Val(arguments.PageID)#
	<cfif StructKeyExists(arguments,"SiteVersionID")>
		AND	SiteVersionID = #Val(arguments.SiteVersionID)#
	<cfelse>
		AND	SiteVersionID IS NULL
	</cfif>
	</cfquery>
	
</cffunction>

<cffunction name="savePage" access="public" returntype="numeric" output="no" hint="I create or update a page and return the PageID.">
	<cfreturn setPage(argumentCollection=arguments)>
</cffunction>

<cffunction name="setPage" access="public" returntype="numeric" output="no" hint="I create or update a page and return the PageID.">
	<cfargument name="SectionID" type="string" required="no" default="0">
	<cfargument name="PageID" type="numeric" hint="New page created if this value is not passed in.">
	<cfargument name="SiteVersionID" type="numeric">
	<cfargument name="Title" type="string">
	<cfargument name="PageName" type="string">
	<cfargument name="OrderNum" type="numeric" hint="Used for ordering query results.">
	<cfargument name="FileName" type="string" hint="The file name for this page. To be used with makeFiles(). May include folder. Will be placed below RootPath and below any folder for section.">
	<cfargument name="Contents" type="string" hint="The contents of this page.">
	<cfargument name="Contents2" type="string" hint="Any secondary contents for this page.">
	<cfargument name="Description" type="string">
	<cfargument name="Keywords" type="string">
	<cfargument name="ImageFileName" type="string" hint="A file name for an image being used on this page.">
	<cfargument name="VersionDescription" type="string" hint="Any comments on the changes being made.">
	<cfargument name="VersionBy" type="string" hint="The person making the change.">
	<cfargument name="onMenu" type="boolean" required="no" hint="Indicates if this page will appear on the navigation menu.">
	<cfargument name="MapPageID" type="string" required="no">
	<cfargument name="skeleton" type="string" default="#variables.skeleton#">
	
	<cfscript>
	var liPageItems = "PageID,SectionID,PageName,FileName,MapPageID,ImageFileName";
	var liVersionItems = "PageID,SiteVersionID,Title,Description,Keywords,Contents,Contents2,VersionDescription,VersionBy";
	var col = "";
	
	var setPage = StructNew();
	var setVersion = StructNew();
	
	var doUpdate = false;
	
	//SiteMapMgr variables
	var Map = StructNew();
	
	var qPage = 0;
	var output = "";
	
	var qCheckFileName = 0;
	var isExistingFile = 0;
	
	if ( StructKeyExists(arguments,"PageID") AND NOT Val(arguments.PageID) ) {
		StructDelete(arguments,"PageID");
	}
	if ( StructKeyExists(arguments,"SectionID") ) {
		arguments.SectionID = val(arguments.SectionID);
	}
	if ( StructKeyExists(arguments,"PageID") ) {
		qPage = getPage(arguments.PageID);
		if ( StructKeyExists(arguments,"FileName") AND FileNameFromString(arguments.FileName) neq FileNameFromString(qPage.FileName) ) {
			StructDelete(arguments,"PageID");
		}
		//hasChanges(qPage,arguments);
	}
	
	if ( NOT StructKeyExists(arguments,"PageID") ) {
		doUpdate = true;
		//Make File Name
		if ( NOT StructKeyExists(arguments,"FileName") OR NOT Len(arguments.FileName) ) {
			arguments.FileName = arguments.Title;
		}
		if ( NOT StructKeyExists(arguments,"PageName") OR NOT Len(arguments.PageName) ) {
			arguments.PageName = ReplaceNoCase(arguments.Title, " ", "_", "ALL");
		}
	}
	if ( StructKeyExists(arguments,"FileName") ) {
		arguments.FileName = FileNameFromString(arguments.FileName);
	}
	if ( StructKeyExists(arguments,"PageName") AND NOT Len(arguments.PageName) ) {
		StructDelete(arguments,"PageName");
	}
	</cfscript>
	<cfloop index="col" list="#liPageItems#">
		<cfif StructKeyExists(arguments,col)>
			<cfset setPage[col] = arguments[col]>
		</cfif>
	</cfloop>
	<cfset setPage["isDeleted"] = false>
	
	<cfloop index="col" list="#liVersionItems#">
		<cfif StructKeyExists(arguments,col)>
			<cfset setVersion[col] = arguments[col]>
		</cfif>
	</cfloop>
	<cfset setVersion["WhenCreated"] = now()>
	<cfset setVersion["isLive"] = now()>
	
	<!--- Check if file name already exists --->
	<cfif StructKeyExists(arguments,"FileName")>
		<cfquery name="qCheckFileName" datasource="#variables.datasource#">
		SELECT	PageID,SectionID,FileName
		FROM	cmsPages
		WHERE	FileName = <cfqueryparam value="#arguments.FileName#" cfsqltype="CF_SQL_VARCHAR">
			AND	(isDeleted = 0 OR isDeleted IS NULL)
		<cfif StructKeyExists(arguments,"PageID")>
			AND NOT PageID = #Val(arguments.PageID)#
		</cfif>
		</cfquery>
		<cfif qCheckFileName.RecordCount>
			<cfif StructKeyExists(arguments,"SectionID")>
				<cfif getFullFilePath(arguments.SectionID,arguments.FileName) eq getFullFilePath(Val(qCheckFileName.SectionID),qCheckFileName.FileName)>
					<cfset isExistingFile = true>
				</cfif>
			<cfelseif isQuery(qPage)>
				<cfif getFullFilePath(qPage.SectionID,arguments.FileName) eq getFullFilePath(Val(qCheckFileName.SectionID),qCheckFileName.FileName)>
					<cfset isExistingFile = true>
				</cfif>
			<cfelse>
				<cfif getFullFilePath(0,arguments.FileName) eq getFullFilePath(Val(qCheckFileName.SectionID),qCheckFileName.FileName)>
					<cfset isExistingFile = true>
				</cfif>
			</cfif>
			<cfif isExistingFile>
				<cfthrow message="The entered file name is already in use for another page." type="CMS">
			</cfif>
		</cfif>
	</cfif>
	
	<cftransaction>
		<!--- Update page --->
		<cfset setPage["PageID"] = variables.DataMgr.saveRecord('cmsPages',setPage)>
		
		<!--- Add page version --->
		<cfset setVersion["PageID"] = setPage["PageID"]>
		<cfset setVersion["PageVersionID"] = variables.DataMgr.insertRecord('cmsPageVersions',setVersion)>
		
		<!--- Always set the updated information as the live version --->
		<cfinvoke method="restoreVersion">
			<cfinvokeargument name="PageID" value="#setVersion.PageID#">
			<cfinvokeargument name="PageVersionID" value="#setVersion.PageVersionID#">
			<cfif StructKeyExists(arguments,"SiteVersionID")><cfinvokeargument name="SiteVersionID" value="#arguments.SiteVersionID#"></cfif>
		</cfinvoke>
	</cftransaction>
	<!--- <cfset makeFileName(setPage["PageID"])>
	<cfset makePageName(setPage["PageID"])> --->
	
	<!--- Edit Site Map --->
	<cfif StructKeyExists(variables,"SiteMapMgr") AND doUpdate AND StructKeyExists(arguments,"onMenu") AND arguments.onMenu AND NOT StructKeyExists(arguments,"MapPageID")>
		<cfset Map.PageID = getSiteMapPageID(setVersion.PageID)>
		<cfset Map.SectionID = getSiteMapSectionID(arguments.SectionID)>
		<cfinvoke component="#variables.SiteMapMgr#" method="savePage" returnvariable="setPage.MapPageID">
			<cfinvokeargument name="PageID" value="#Map.PageID#">
			<cfinvokeargument name="SectionID" value="#Map.SectionID#">
			<cfif StructKeyExists(arguments,"PageName")>
				<cfinvokeargument name="PageName" value="#arguments.PageName#">
			</cfif>
			<cfif StructKeyExists(arguments,"Title")>
				<cfinvokeargument name="PageLabel" value="#arguments.Title#">
			</cfif>
			<cfif StructKeyExists(arguments,"FileName")>
				<cfinvokeargument name="PageURL" value="#getUrlPath(arguments.SectionID,arguments.FileName)#">
			</cfif>
			<cfif StructKeyExists(arguments,"onMenu")>
				<cfinvokeargument name="onMenu" value="#arguments.onMenu#">
			<cfelse>
				<cfinvokeargument name="onMenu" value="false">
			</cfif>
			<!--- <cfinvokeargument name="Permissions" value=""> --->
		</cfinvoke>
		<cfset variables.DataMgr.updateRecord('cmsPages',setPage)>
	</cfif>

	<cfif Len(arguments.skeleton)><!--- doUpdate AND  --->
		<cfset writeFile(setPage["PageID"],arguments.skeleton,true)>
	</cfif>
	
	<cfreturn setPage["PageID"]>
</cffunction>

<cffunction name="copyPage" access="public" returntype="void" output="no">
	<cfargument name="PageID" type="numeric" required="yes">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="SectionID" type="string" required="no">
	
	<cfset var qCheckFileName = 0>
	<cfset var qPage = getPage(arguments.PageID)>
	<cfset var isExistingFile = false>
	<cfset var sPage = QueryRowToStruct(qPage)>
	
	<cfquery name="qCheckFileName" datasource="#variables.datasource#">
	SELECT	PageID,SectionID,FileName
	FROM	cmsPages
	WHERE	FileName = <cfqueryparam value="#arguments.FileName#" cfsqltype="CF_SQL_VARCHAR">
		AND	(isDeleted = 0 OR isDeleted IS NULL)
	</cfquery>
	<cfif qCheckFileName.RecordCount>
		<cfif StructKeyExists(arguments,"SectionID") AND isNumeric(arguments.SectionID) AND arguments.SectionID GT 0>
			<cfif getFullFilePath(arguments.SectionID,arguments.FileName) eq getFullFilePath(Val(qCheckFileName.SectionID),qCheckFileName.FileName)>
				<cfset isExistingFile = true>
			</cfif>
		<cfelseif isQuery(qPage)>
			<cfif getFullFilePath(qPage.SectionID,arguments.FileName) eq getFullFilePath(Val(qCheckFileName.SectionID),qCheckFileName.FileName)>
				<cfset isExistingFile = true>
			</cfif>
		<cfelse>
			<cfif getFullFilePath(0,arguments.FileName) eq getFullFilePath(Val(qCheckFileName.SectionID),qCheckFileName.FileName)>
				<cfset isExistingFile = true>
			</cfif>
		</cfif>
		<cfif isExistingFile>
			<cfthrow message="The entered file name is already in use for another page." type="CMS">
		</cfif>
	</cfif>
	
	<cfset sPage.FileName = arguments.FileName>
	<cfset sPage.PageName = ListFirst(arguments.FileName,".")>
	<cfset StructDelete(sPage,"PageID")>
	<cfif StructKeyExists(arguments,"SectionID")>
		<cfset sPage.SectionID = arguments.SectionID>
	</cfif>
	
	<cfset savePage(argumentCollection=sPage)>
	
	
</cffunction>

<cffunction name="renamePageFile" access="public" returntype="void" output="no">
	<cfargument name="PageID" type="numeric" required="yes">
	<cfargument name="FileName" type="string" required="yes">
	
	<cfset var qCheckFileName = 0>
	<cfset var qPageOld = getPage(arguments.PageID)>
	<cfset var isExistingFile = false>
	<cfset var qPageNew = 0>

	<cfquery name="qCheckFileName" datasource="#variables.datasource#">
	SELECT	PageID,SectionID,FileName
	FROM	cmsPages
	WHERE	FileName = <cfqueryparam value="#arguments.FileName#" cfsqltype="CF_SQL_VARCHAR">
		AND	PageID <> <cfqueryparam value="#arguments.PageID#" cfsqltype="CF_SQL_INTEGER">
		AND	(isDeleted = 0 OR isDeleted IS NULL)
	</cfquery>
	
	<cfif qCheckFileName.RecordCount>
		<cfif getFullFilePath(qPageOld.SectionID,arguments.FileName) eq getFullFilePath(Val(qCheckFileName.SectionID),qCheckFileName.FileName)>
			<cfset isExistingFile = true>
		</cfif>
		<cfif isExistingFile>
			<cfthrow message="The entered file name is already in use for another page." type="CMS">
		</cfif>
	</cfif>
	
	<cfset variables.DataMgr.updateRecord("cmsPages",arguments)>
	<cfset qPageNew = getPage(arguments.PageID)>
	
	<cftry>
		<cffile action="RENAME" source="#qPageOld.FullFilePath#" destination="#qPageNew.FullFilePath#">
	<cfcatch>
	</cfcatch>
	</cftry>
	<cfif Len(variables.skeleton)><!--- doUpdate AND  --->
		<cfset writeFile(arguments.PageID,variables.skeleton,true)>
	</cfif>
	
	
</cffunction>

<cffunction name="makeFileName" access="public" returntype="void" output="no">
	<cfargument name="PageID" type="numeric" required="yes">
	
	<cfset var qPage = getPage(arguments.PageID)>
	<cfset var setPage = StructNew()>
	
	<cfset setPage["PageID"] = arguments.PageID>
	<cfset setPage.FileName = "">
	
	<cfif Len(Trim(qPage.FileName))>
		<cfif qPage.FileName neq FileNameFromString(qPage.FileName)>
			<cfset setPage.FileName = FileNameFromString(qPage.FileName)>
		</cfif>
	<cfelse>
		<cfset setPage.FileName = FileNameFromString(qPage.Title)>
	</cfif>
	
	<cfif Len(Trim(setPage.FileName))>
		<cfset variables.DataMgr.updateRecord('cmsPages',setPage)>
	</cfif>
	
</cffunction>

<cffunction name="makePageName" access="public" returntype="void" output="no">
	<cfargument name="PageID" type="numeric" required="yes">
	
	<cfset var qPage = getPage(arguments.PageID)>
	<cfset var setPage = StructNew()>
	
	<cfset setPage["PageID"] = arguments.PageID>
	<cfset setPage.PageName = "">
	
	<cfif NOT Len(Trim(qPage.PageName))>
		<cfset setPage.PageName = qPage.FileName>
		<cfset variables.DataMgr.updateRecord('cmsPages',setPage)>
	</cfif>
	
</cffunction>

<cffunction name="FileNameFromString" access="public" returntype="string" output="no">
	<cfargument name="string" type="string" required="yes">
	
	<cfset var reChars = "([0-9]|[a-z]|[A-Z])">
	<cfset var exts = "cfm,htm,html">
	<cfset var i = 0>
	<cfset var result = "">
	<cfset var ext = ListLast(string,".")>
	
	<cfif Len(ext) AND ListFindNoCase(exts,ext) AND (Len(string)-Len(ext)-1) gt 0>
		<cfset string = Left(string,Len(string)-Len(ext)-1)>
	</cfif>

	<cfloop index="i" from="1" to="#Len(string)#" step="1">
		<cfif REFindNoCase(reChars, Mid(string,i,1))>
			<cfset result = result & Mid(string,i,1)>
		<cfelse>
			<cfset result = result & "_">
		</cfif>
	</cfloop>
	
	<cfset result = REReplaceNoCase(result, "_{2,}", "_", "ALL")>
	
	<cfif Len(result)>
		<cfif Len(ext) AND ListFindNoCase(exts,ext)>
			<cfset result = "#result#.#ext#">
		<cfelse>
			<cfset result = "#result#.#ListFirst(exts)#">
		</cfif>
	</cfif>
	
	<cfreturn LCase(result)>
</cffunction>

<cffunction name="setSection" access="public" returntype="numeric" output="no" hint="I create or update a section and return the SectionID.">
	<cfargument name="SectionID" type="numeric" hint="New section created if not passed in.">
	<cfargument name="ParentSectionID" type="numeric">
	<cfargument name="OrderNum" type="numeric" hint="Used for ordering query results.">
	<cfargument name="SectionTitle" type="string">
	<cfargument name="Description" type="string">
	<cfargument name="Keywords" type="string">
	<cfargument name="SectionLink" type="string" hint="An optional primary link for this section.">
	<cfargument name="SectionDir" type="string" hint="A folder path for this section.">
	<cfargument name="MapSectionID" type="numeric" required="no">
	
	<cfscript>
	var qSection = 0;
	var qGetSection = 0;
	var result = 0;
	var doUpdate = false;
	var DirSection = "";
	var FileApplicationCFM = "";
	var ApplicationCFMOutput = "";
	
	if ( StructKeyExists(arguments,"SectionID") AND Not Val(arguments.SectionID) ) {
		StructDelete(arguments,"SectionID");
	}
	if ( StructKeyExists(arguments,"ParentSectionID") AND Not Val(arguments.ParentSectionID) ) {
		StructDelete(arguments,"ParentSectionID");
	}
	</cfscript>
	
	<!--- If SectionID isn't passed in, use section with same title and parent --->
	<cfif NOT StructKeyExists(arguments,"SectionID")>
		<cfquery name="qGetSection" datasource="#variables.datasource#">
		SELECT	SectionID
		FROM	cmsSections
		WHERE	1 = 1
		<cfif StructKeyExists(arguments,"SectionTitle")>
			AND		SectionTitle = <cfqueryparam value="#arguments.SectionTitle#" cfsqltype="CF_SQL_VARCHAR">
		</cfif>
		<cfif StructKeyExists(arguments,"MapSectionID")>
			AND		MapSectionID = <cfqueryparam value="#arguments.MapSectionID#" cfsqltype="CF_SQL_INTEGER">
		</cfif>
		<cfif StructKeyExists(arguments,"ParentSectionID")>
		AND		ParentSectionID = #Val(arguments.ParentSectionID)#
		<cfelse>
		AND		ParentSectionID IS NULL
		</cfif>
		</cfquery>
		<cfif qGetSection.RecordCount>
			<cfset arguments.SectionID = qGetSection.SectionID>
		</cfif>
	</cfif>
	
	<cfscript>
	//Get previous state
	if ( StructKeyExists(arguments,"SectionID") ) {
		qSection = getSection(arguments.SectionID);
		doUpdate = hasChanges(qSection,arguments);
	} else {
		doUpdate = true;
	}
	</cfscript>

	<!--- Save section --->
	<cfset result = variables.DataMgr.saveRecord("cmsSections",arguments)>
	
	<!--- Try to create new directory --->
	<cfif StructKeyExists(arguments,"SectionDir")>
		<cfset DirSection = "#variables.RootPath##variables.dirdelim##getSectionPath(result)#">
		<cfif NOT DirectoryExists(DirSection)>
			<cftry>
				<cfdirectory action="CREATE" directory="#DirSection#" mode="777">
			<cfcatch>
			</cfcatch>
			</cftry>
		</cfif>
		<cfset FileApplicationCFM = DirSection & "Application.cfm">
		<cfif NOT FileExists(FileApplicationCFM)>
			<cfset ApplicationCFMOutput = '<cfinclude template="../Application.cfm"><cfset layout.setSection("#qSection.SectionTitle#")>'>
			<cffile action="write" file="#FileApplicationCFM#" output="#ApplicationCFMOutput#" >
		</cfif>
	</cfif>
	
	<!--- Update site map --->
	<cfif StructKeyExists(variables,"SiteMapMgr") AND doUpdate AND NOT StructKeyExists(arguments,"MapSectionID")>
		<cfinvoke component="#variables.SiteMapMgr#" method="saveSection" returnvariable="arguments.MapSectionID">
			<cfinvokeargument name="SectionID" value="#getSiteMapSectionID(result)#">
			<cfif StructKeyExists(arguments,"ParentSectionID")>
				<cfinvokeargument name="ParentSectionID" value="#getSiteMapSectionID(arguments.ParentSectionID)#">
			</cfif>
			<cfif StructKeyExists(arguments,"OrderNum")>
				<cfinvokeargument name="ordernum" value="#arguments.OrderNum#">
			</cfif>
			<!--- <cfinvokeargument name="SectionName" value=""> --->
			<cfif StructKeyExists(arguments,"SectionTitle")>
				<cfinvokeargument name="SectionLabel" value="#arguments.SectionTitle#">
			</cfif>
			<cfif StructKeyExists(arguments,"SectionLink")>
				<cfinvokeargument name="SectionURL" value="#arguments.SectionLink#">
			</cfif>
			<!--- <cfinvokeargument name="Permissions" value=""> --->
		</cfinvoke>
		<cfset arguments.SectionID = result>
		<cfset variables.DataMgr.updateRecord("cmsSections",arguments)>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="setSiteVersion" access="public" returntype="numeric" output="no" hint="I create/update a site version and return the SiteVersionID. A version of a site could represent a language or other variations of the same site.">
	<cfargument name="SiteVersionID" type="numeric" hint="New site version created if not passed in.">
	<cfargument name="SiteName" type="string" required="yes">
	<cfargument name="DomainRoot" type="string">
	<cfargument name="isDefault" type="boolean">
	
	<cfset var result = 0>

	<!--- If this site version is the default, set all site versions as not default (this one will then be set as default later in this method) --->
	<cfif StructKeyExists(arguments,"isDefault") AND arguments.isDefault>
		<cfquery datasource="#variables.datasource#">
		UPDATE	cmsSiteVersions
		SET		isDefault = 0
		</cfquery>
	</cfif>
	
	<cfif StructKeyExists(arguments,"SiteVersionID")>
		<cfset variables.DataMgr.updateRecord('cmsSiteVersions',arguments)>
		<cfset result = arguments.SiteVersionID>
	<cfelse>
		<cfset variables.DataMgr.insertRecord('cmsSiteVersions',arguments)>
		<cfset result = variables.DataMgr.getPKFromData('cmsSiteVersions',arguments)>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSiteMapPageID" access="public" returntype="numeric" output="no">
	<cfargument name="PageID" type="numeric" required="yes">
	
	<cfset var qPage = getPage(arguments.PageID)>
	<cfset var qMapPage = 0>
	<cfset var getMapPage = StructNew()>
	<cfset var result = 0>
	
	<cfif NOT StructKeyExists(variables,"SiteMapMgr")>
		<cfthrow message="This method can only be used when SiteMapMgr is passed to CMS.">
	</cfif>
	
	<cfif isNumeric(qPage.MapPageID) AND qPage.MapPageID gt 0>
		<cfset result = qPage.MapPageID>
	<cfelse>
		<cfif isNumeric(qPage.SectionID) AND qPage.SectionID gt 0>
			<cfset getMapPage.SectionID = getSiteMapSectionID(qPage.SectionID)>
		</cfif>
		<cfif Len(Trim(qPage.Title))>
			<cfset getMapPage.PageLabel = qPage.Title>
		</cfif>
		<cfif Len(Trim(qPage.UrlPath))>
			<cfset getMapPage.PageURL = qPage.UrlPath>
		</cfif>
		
		<cfset qMapPage = variables.SiteMapMgr.getPage(argumentCollection=getMapPage)>
		
		<cfif qMapPage.RecordCount eq 1>
			<cfset result = qMapPage.PageID>
		</cfif>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSiteMapSectionID" access="public" returntype="numeric" output="no">
	<cfargument name="SectionID" type="numeric" required="yes">
	
	<cfset var qSection = getSection(arguments.SectionID)>
	<cfset var qMapSection = 0>
	<cfset var getMapSection = StructNew()>
	<cfset var result = 0>
	
	<cfset getMapSection.SectionID = arguments.SectionID>
	
	<cfif NOT StructKeyExists(variables,"SiteMapMgr")>
		<cfthrow message="This method can only be used when SiteMapMgr is passed to CMS.">
	</cfif>
	
	<cfif isNumeric(qSection.MapSectionID) AND qSection.MapSectionID gt 0>
		<cfset result = qSection.MapSectionID>
	<cfelse>
		<cfif isNumeric(qSection.ParentSectionID) AND qSection.ParentSectionID gt 0>
			<cfset getMapSection.ParentSectionID = getSiteMapSectionID(qSection.ParentSectionID)>
		</cfif>
		<cfif Len(Trim(qSection.SectionTitle))>
			<cfset getMapSection.SectionLabel = qSection.SectionTitle>
		</cfif>
		<cfif Len(Trim(qSection.SectionLink))>
			<cfset getMapSection.SectionURL = qSection.SectionLink>
		</cfif>
		
		<cfset qMapSection = variables.SiteMapMgr.getSection(argumentCollection=getMapSection)>
		
		<cfif qMapSection.RecordCount eq 1>
			<cfset result = qMapSection.SectionID>
		</cfif>	
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="orderSections" access="public" returntype="void" output="no" hint="I save the order of the given sections.">
	<cfargument name="ParentSectionID" type="numeric" required="no">
	<cfargument name="Sections" type="string" required="no">
	
	<cfset var i = 0>
	<cfset var SectionID = 0>
	
	<cfloop index="i" from="1" to="#ListLen(arguments.Sections)#" step="1">
		<cfset SectionID = ListGetAt(arguments.Sections,i)>
		<cfinvoke method="setSection">
			<cfinvokeargument name="SectionID" value="#SectionID#">
			<cfif StructKeyExists(arguments,"ParentSectionID")>
				<cfinvokeargument name="ParentSectionID" value="#arguments.ParentSectionID#">
			</cfif>
			<cfinvokeargument name="ordernum" value="#i#">
		</cfinvoke>
	</cfloop>
	
</cffunction>

<cffunction name="mapGetPageID" access="private" returntype="numeric" output="no">
	<cfargument name="PageID" type="numeric" required="no">
	
	<cfset var result = 0>
	<cfset var qPage = 0>
	
	<cfquery name="qPage" datasource="#variables.datasource#">
	SELECT	PageID
	FROM	cmsPages
	WHERE	MapPageID = <cfqueryparam value="#arguments.PageID#" cfsqltype="CF_SQL_INTEGER">
	</cfquery>
	<cfif qPage.RecordCount eq 1>
		<cfset result = qPage.PageID>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="mapGetSectionID" access="private" returntype="numeric" output="no">
	<cfargument name="SectionID" type="numeric" required="no" default="0">
	
	<cfset var result = 0>
	<cfset var qSection = 0>
	<cfset var argcount = 0>
	
	<cfif StructKeyExists(arguments,"ParentSectionID")>
		<cfset arguments.ParentSectionID = mapGetSectionID(arguments.ParentSectionID)>
	</cfif>
	
	<cfquery name="qSection" datasource="#variables.datasource#">
	SELECT	SectionID
	FROM	cmsSections
	WHERE	MapSectionID = <cfqueryparam value="#arguments.SectionID#" cfsqltype="CF_SQL_INTEGER">
	</cfquery>
	<cfif qSection.RecordCount eq 1>
		<cfset result = qSection.SectionID>
	<cfelse>
		<cfquery name="qSection" datasource="#variables.datasource#">
		SELECT	SectionID
		FROM	cmsSections
		WHERE	1 = 1
		<cfif StructKeyExists(arguments,"SectionLabel") AND Len(arguments.SectionLabel)>
			AND	SectionTitle = <cfqueryparam value="#arguments.SectionLabel#" cfsqltype="CF_SQL_VARCHAR">
			<cfset argcount = argcount + 1>
		</cfif>
		<cfif StructKeyExists(arguments,"SectionURL") AND Len(arguments.SectionURL)>
			AND	SectionLink = <cfqueryparam value="#arguments.SectionURL#" cfsqltype="CF_SQL_VARCHAR">
			<cfset argcount = argcount + 1>
		</cfif>
		<cfif StructKeyExists(arguments,"ParentSectionID")>
			<cfif isNumeric(arguments.ParentSectionID) AND arguments.ParentSectionID gt 0>
			AND	(ParentSectionID = 0 OR ParentSectionID IS NULL)
			<cfelse>
			AND	ParentSectionID = <cfqueryparam value="#arguments.ParentSectionID#" cfsqltype="CF_SQL_INTEGER">
			</cfif>
			<cfset argcount = argcount + 1>
		</cfif>
		</cfquery>
		<cfif qSection.RecordCount eq 1 AND argcount gte 2>
			<cfset result = qSection.SectionID>
		</cfif>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="mapRemoveSection" access="public" returntype="void" output="no">
	<cfargument name="SectionID" type="numeric" required="yes">
	
	<cfset var CMSSectionID = mapGetSectionID(argumentCollection=arguments)>
	
	<cfset deleteSection(CMSSectionID)>
	
</cffunction>

<cffunction name="mapSaveSection" access="public" returntype="void" output="no">
	<cfargument name="SectionID" type="numeric" required="no">
	<cfargument name="ParentSectionID" type="numeric" required="no">
	<cfargument name="ordernum" type="numeric" required="no">
	<cfargument name="SectionName" type="string" required="no">
	<cfargument name="SectionLabel" type="string" required="no">
	<cfargument name="SectionURL" type="string" required="no">
	<cfargument name="Permissions" type="string" required="no">
	
	<cfset var CMSSectionID = mapGetSectionID(argumentCollection=arguments)>
	
	<cfinvoke method="setSection">
		<cfif CMSSectionID>
			<cfinvokeargument name="SectionID" value="#CMSSectionID#">
		</cfif>
		<cfif StructKeyExists(arguments,"SectionID")>
			<cfinvokeargument name="MapSectionID" value="#arguments.SectionID#">
		</cfif>
		<cfif StructKeyExists(arguments,"ParentSectionID")>
			<cfinvokeargument name="ParentSectionID" value="#mapGetSectionID(arguments.ParentSectionID)#">
		</cfif>
		<cfif StructKeyExists(arguments,"ordernum")>
			<cfinvokeargument name="OrderNum" value="#arguments.ordernum#">
		</cfif>
		<cfif StructKeyExists(arguments,"SectionLabel")>
			<cfinvokeargument name="SectionTitle" value="#arguments.SectionLabel#">
		</cfif>
		<cfif StructKeyExists(arguments,"SectionURL")>
			<cfinvokeargument name="SectionLink" value="#arguments.SectionURL#">
		</cfif>
	</cfinvoke>
	
</cffunction>

<cffunction name="mapSavePage" access="public" returntype="void" output="no">
	<cfargument name="PageID" type="numeric" required="no">
	<cfargument name="SectionID" type="numeric" required="no">
	<cfargument name="ordernum" type="numeric" required="no">
	<cfargument name="PageName" type="string" required="no">
	<cfargument name="PageLabel" type="string" required="no">
	<cfargument name="PageURL" type="string" required="no">
	<cfargument name="onMenu" type="boolean" required="no">
	<cfargument name="Permissions" type="string" required="no">
	
	<cfset var CMSPageID = 0>
	
	<cfif StructKeyExists(arguments,"PageID")>
		<cfset CMSPageID = mapGetPageID(arguments.PageID)>
	</cfif>
	
	<!--- Save the page, if it already exists in CMS (we don't create new CMS pages just because they are in the site map) --->
	<cfif CMSPageID>
		<cfinvoke method="setPage">
			<cfif StructKeyExists(arguments,"SectionID")>
				<cfinvokeargument name="SectionID" value="#mapGetSectionID(arguments.SectionID)#">
			</cfif>
			<cfif StructKeyExists(arguments,"PageID")>
				<cfinvokeargument name="MapPageID" value="#arguments.PageID#">
				<cfinvokeargument name="PageID" value="#CMSPageID#">
			</cfif>
			<cfif StructKeyExists(arguments,"PageLabel")>
				<cfinvokeargument name="Title" value="#arguments.PageLabel#">
			</cfif>
			<cfif StructKeyExists(arguments,"PageName")>
				<cfinvokeargument name="PageName" value="#arguments.PageName#">
			</cfif>
			<cfif StructKeyExists(arguments,"ordernum")>
				<cfinvokeargument name="OrderNum" value="#arguments.ordernum#">
			</cfif>
			<cfif StructKeyExists(arguments,"PageURL")>
				<cfinvokeargument name="FileName" value="#ListLast(arguments.PageURL,'/')#">
			</cfif>
			<!--- <cfargument name="onMenu" value=""> --->
		</cfinvoke>
	</cfif>
</cffunction>

<cffunction name="writeFile" access="public" returntype="void" output="no" hint="I make a file for each active page. Each file will be placed in the RootPath given to this component (or a subdirectory thereof).">
	<cfargument name="PageID" type="numeric" required="yes">
	<cfargument name="skeleton" type="string" required="yes" hint="The HTML skeleton to feed the contents of the page into. The name of any field can be placed in brackets and will be replaced by the contents of that field for the given page. For example, to place the contents of the page, use [Contents] as place-holder.">
	<cfargument name="overwrite" type="boolean" default="true" hint="Should an existing file be overwritten. If false, makeFiles() will not create a file if it already exists.">
	
	<cfset var qPage = getPage(arguments.PageID)>
	<cfset var output = arguments.skeleton>
	<cfset var col = "">
	
	<cfset var precode = "">
	<cfset var isCmsPage = false>
	
	<cfif StructKeyExists(arguments,"skeleton")>
		<cfloop index="col" list="#qPage.ColumnList#">
			<cfset output = ReplaceNoCase(output, "[#col#]", qPage[col][1], "ALL")>
		</cfloop>
	</cfif>
	
	<cfif Len(qPage.FileName) AND Len(output)>
		<cfif FileExists(qPage.FullFilePath)>
			<!--- Only overwrite existing pages if overwrite argument is true and page is a CMS page --->
			<cfif arguments.overwrite>
				<cfset isCmsPage = false>
				<cffile action="READ" file="#qPage.FullFilePath#" variable="precode">
				<cfif
						FindNoCase("CMS", precode)
					AND	FindNoCase("nosearchy", precode)
				>
					<cfset isCmsPage = true>
				</cfif>
				<!--- Overwrite CMS pages, otherwise delete --->
				<cfif isCmsPage OR NOT variables.OnlyOverwriteCMS>
					<!--- <cfif NOT FindNoCase("nowritey", precode)> --->
					<cfif NOT ( precode CONTAINS "nowritey" )>
						<cffile action="WRITE" file="#qPage.FullFilePath#" output="#output#">
					</cfif>
				<cfelse>
					<cfset deletePage(arguments.PageID)>
				</cfif>
			</cfif>
		<cfelse>
			<cffile action="WRITE" file="#qPage.FullFilePath#" output="#output#">
		</cfif>
	</cfif>
	
</cffunction>

<cffunction name="writeFiles" access="public" returntype="void" output="no" hint="I make a file for each active page. Each file will be placed in the RootPath given to this component (or a subdirectory thereof).">
	<cfargument name="skeleton" type="string" required="yes" hint="The HTML skeleton to feed the contents of the page into. The name of any field can be placed in brackets and will be replaced by the contents of that field for the given page. For example, to place the contents of the page, use [Contents] as place-holder.">
	<cfargument name="overwrite" type="boolean" default="true" hint="Should an existing file be overwritten. If false, makeFiles() will not create a file if it already exists.">
	
	<cfset var qPages = getAllPages(arguments.skeleton)>
	
	<cfloop query="qPages">
		<cfinvoke method="writeFile" PageID="#PageID#" skeleton="#arguments.skeleton#" overwrite="#arguments.overwrite#">
		</cfinvoke>
	</cfloop>
	
</cffunction>

<cffunction name="getDbXml" access="public" returntype="string" output="no" hint="I return the XML for the tables.">
	
	<cfset var tableXML = "">
	
	<cfsavecontent variable="tableXML">
	<tables>
		<table name="cmsPages" simrows="20">
			<field ColumnName="PageID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="SectionID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="TemplateID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="PageName" CF_DataType="CF_SQL_VARCHAR" Length="180" />
			<field ColumnName="FileName" CF_DataType="CF_SQL_VARCHAR" Length="60" />
			<field ColumnName="MapPageID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="ImageFileName" CF_DataType="CF_SQL_VARCHAR" Length="180" />
			<field ColumnName="isDeleted" CF_DataType="CF_SQL_BIT" Default="0" />
			<cfif variables.Datamgr.getDatabase() EQ "Sim">
			<field ColumnName="Title" CF_DataType="CF_SQL_VARCHAR" Length="20" />
			<field ColumnName="WhenCreated" CF_DataType="CF_SQL_DATE" />
			<field ColumnName="Description" CF_DataType="CF_SQL_VARCHAR" Length="500" />
			<field ColumnName="Keywords" CF_DataType="CF_SQL_VARCHAR" Length="900" />
			<field ColumnName="Contents" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="Contents2" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="VersionDescription" CF_DataType="CF_SQL_VARCHAR" Length="240" />
			<field ColumnName="VersionBy" CF_DataType="CF_SQL_VARCHAR" Length="80" />
			
			<field ColumnName="FileOutput" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="FullFilePath" CF_DataType="CF_SQL_VARCHAR" Length="120" />
			<field ColumnName="UrlPath" CF_DataType="CF_SQL_VARCHAR" Length="120" />
			</cfif>
		</table>
		<table name="cmsPageVersions">
			<field ColumnName="PageVersionID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="PageID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="SiteVersionID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="Title" CF_DataType="CF_SQL_VARCHAR" Length="120" />
			<field ColumnName="WhenCreated" CF_DataType="CF_SQL_DATE" />
			<field ColumnName="Description" CF_DataType="CF_SQL_VARCHAR" Length="500" />
			<field ColumnName="Keywords" CF_DataType="CF_SQL_VARCHAR" Length="900" />
			<field ColumnName="Contents" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="Contents2" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="VersionDescription" CF_DataType="CF_SQL_VARCHAR" Length="240" />
			<field ColumnName="VersionBy" CF_DataType="CF_SQL_VARCHAR" Length="80" />
		</table>
		<table name="cmsSections">
			<field ColumnName="SectionID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="ParentSectionID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="SectionTitle" CF_DataType="CF_SQL_VARCHAR" Length="60" />
			<field ColumnName="Description" CF_DataType="CF_SQL_VARCHAR" Length="240" />
			<field ColumnName="Keywords" CF_DataType="CF_SQL_VARCHAR" Length="900" />
			<field ColumnName="SectionDir" CF_DataType="CF_SQL_VARCHAR" Length="240" />
			<field ColumnName="SectionLink" CF_DataType="CF_SQL_VARCHAR" Length="240" />
			<field ColumnName="MapSectionID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="OrderNum" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="SectionLabelExt" CF_DataType="CF_SQL_VARCHAR" Length="240" />
			<field ColumnName="isDeleted" CF_DataType="CF_SQL_BIT" Default="0" />
		</table>
		<table name="cmsSiteVersions">
			<field ColumnName="SiteVersionID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="SiteName" CF_DataType="CF_SQL_VARCHAR" length="80" />
			<field ColumnName="DomainRoot" CF_DataType="CF_SQL_VARCHAR" length="140" />
			<field ColumnName="isDefault" CF_DataType="CF_SQL_BIT" />
		</table>
		<table name="cmsPages2Versions">
			<field ColumnName="PageID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="SiteVersionID" CF_DataType="CF_SQL_INTEGER" />
			<field ColumnName="PageVersionID" CF_DataType="CF_SQL_INTEGER" />
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

<cfscript>
/**
 * Makes a row of a query into a structure.
 * 
 * @param query 	 The query to work with. 
 * @param row 	 Row number to check. Defaults to row 1. 
 * @return Returns a structure. 
 * @author Nathan Dintenfass (nathan@changemedia.com) 
 * @version 1, December 11, 2001 
 */
function queryRowToStruct(query) {
	var row = 1;//by default, do this to the first row of the query
	var ii = 1;//a var for looping
	var cols = listToArray(query.columnList);//the cols to loop over
	var stReturn = structnew();//the struct to return
	//if there is a second argument, use that for the row number
	if(arrayLen(arguments) GT 1)
		row = arguments[2];
	//loop over the cols and build the struct from the query row
	for(ii = 1; ii lte arraylen(cols); ii = ii + 1){
		stReturn[cols[ii]] = query[cols[ii]][row];
	}
	//return the struct
	return stReturn;
}
</cfscript>

</cfcomponent>