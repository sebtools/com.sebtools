<cfcomponent displayname="Site Map" hint="I handle the site map information from an XML file.">

<cffunction name="init" access="public" returntype="SiteMap" output="no" hint="I initialize the Site Map with an XML object of the site map.">
	<cfargument name="SiteMapXML" type="any" required="yes">
	
	<cfset variables.SiteMap = parseSiteMap(arguments.SiteMapXML)>
	
	<cfreturn this>
</cffunction>

<cffunction name="getSiteMap" access="public" returntype="array" output="no" hint="I return the complex variable holding the site map data.">
	<cfargument name="UserPermissions" type="string" required="no">
	
	<cfset var result = Duplicate(variables.SiteMap)>
	
	<cfscript>
	//Restrict by permissions
	if ( StructKeyExists(arguments,"UserPermissions") ) {
		//Loop through sections (backwards, again for safe deletion)
		for ( i=ArrayLen(result); i gte 1; i=i-1 ) {
			if ( Len(result[i].permissions) AND Not ListHasCommon(arguments.UserPermissions, result[i].permissions) ) {
				ArrayDeleteAt(result, i);
			} else {
				if ( ArrayLen(result[i].subsections) ) {
					for ( j=ArrayLen(result[i].subsections); j gte 1; j=j-1 ) {
						if ( Len(result[i].subsections[j].permissions) AND Not ListHasCommon(arguments.UserPermissions, result[i].subsections[j].permissions) ) {
							ArrayDeleteAt(result[i].subsections, j);
						} else {
							if ( ArrayLen(result[i].subsections[j].pages) ) {
								for ( k=ArrayLen(result[i].subsections[j].pages); k gte 1; k=k-1 ) {
									if ( Len(result[i].subsections[j].pages[k].permissions) AND Not ListHasCommon(arguments.UserPermissions, result[i].subsections[j].pages[k].permissions) ) {
										ArrayDeleteAt(result[i].subsections[j].pages, k);
									}// /if
								}// /for
							}// /if
						}// /if
					}// /for
				}// /if
				if ( ArrayLen(result[i].pages) ) {
					for ( j=ArrayLen(result[i].pages); j gte 1; j=j-1 ) {
						if ( Len(result[i].pages[j].permissions) AND Not ListHasCommon(arguments.UserPermissions, result[i].pages[j].permissions) ) {
							ArrayDeleteAt(result[i].pages, j);
						}// /if
					}// /for
				}// /if
			}// /if
		}// /for
	}// /if
	</cfscript>
	
	<cfreturn result>
</cffunction>

<cffunction name="getPageLabel" access="public" returntype="string" hint="I return the label of the page based on its url.">
	<cfargument name="SCRIPT_NAME" type="string" required="yes">
	
	<cfset var PageLabel = "">
	<cfset var i = 0>
	<cfset var j = 0>
	<cfset var h = 0>
	
	<!--- Look in each section for this URL --->
	<cfloop index="i" from="1" to="#ArrayLen(variables.SiteMap)#" step="1">
		<!--- Look in each page in this section for this URL --->
		<cfloop index="j" from="1" to="#ArrayLen(variables.SiteMap[i].pages)#" step="1">
			<!--- If this page matches the given URL, set the result and quit looking --->
			<cfif arguments.SCRIPT_NAME eq variables.SiteMap[i].pages[j].url>
				<cfset PageLabel = variables.SiteMap[i].pages[j].label>
				<cfbreak>
			</cfif>
		</cfloop>
		<cfif Len(PageLabel)><cfbreak></cfif>
		<cfif ArrayLen(variables.SiteMap[i].subsections)>
			<!--- Look in each page in each subsection for this URL --->
			<cfloop index="h" from="1" to="#ArrayLen(variables.SiteMap[i].subsections)#" step="1">
				<!--- Look in each page in this subsection for this URL --->
				<cfloop index="j" from="1" to="#ArrayLen(variables.SiteMap[i].subsections[h].pages)#" step="1">
					<!--- If this page matches the given URL, set the result and quit looking --->
					<cfif arguments.SCRIPT_NAME eq variables.SiteMap[i].subsections[h].pages[j].url>
						<cfset PageLabel = variables.SiteMap[i].subsections[h].pages[j].label>
						<cfbreak>
					</cfif>
				</cfloop>
				<!--- If the result has been found quit looking (have to break out of outer loop separately) --->
				<cfif Len(PageLabel)><cfbreak></cfif>
			</cfloop>
		</cfif>
		<!--- If the result has been found quit looking (have to break out of outer loop separately) --->
		<cfif Len(PageLabel)><cfbreak></cfif>
	</cfloop>
	
	<cfreturn PageLabel>
</cffunction>

<cffunction name="getMenuItems" access="public" returntype="query" output="no" hint="I get the menu items for the given section/subsection.">
	<cfargument name="section" type="string" required="yes">
	<cfargument name="subsection" type="string" default="">
	<cfargument name="permissions" type="string" required="no">
	
	<cfset var varSiteMap = variables.SiteMap>
	<cfset var qMenuItems = QueryNew('label,url')>
	<cfset var i = 0>
	<cfset var j = 0>
	<cfset var h = 0>
	
	<cfif StructKeyExists(arguments,"permissions")>
		<cfset varSiteMap = getSiteMap(arguments.permissions)>
	</cfif>
	
	
	<!--- Loop through sections --->
	<cfloop index="i" from="1" to="#ArrayLen(varSiteMap)#" step="1">
		<!--- If this is the correct section, add a menu item for each page. --->
		<cfif Len(arguments.subsection) AND ArrayLen(varSiteMap[i].subsections)>
			<cfloop index="h" from="1" to="#ArrayLen(varSiteMap[i].subsections)#" step="1">
				<cfif arguments.subsection eq xmlFormat(varSiteMap[i].subsections[h].name)>
					<cfloop index="j" from="1" to="#ArrayLen(varSiteMap[i].subsections[h].pages)#" step="1">
						<cfscript>
						QueryAddRow(qMenuItems);
						QuerySetCell(qMenuItems, 'label', varSiteMap[i].subsections[h].pages[j].label);
						QuerySetCell(qMenuItems, 'url', varSiteMap[i].subsections[h].pages[j].url);
						</cfscript>
					</cfloop>
				</cfif>
			</cfloop>
		<cfelseif arguments.section eq xmlFormat(varSiteMap[i].name)>
			<cfloop index="j" from="1" to="#ArrayLen(varSiteMap[i].pages)#" step="1">
				<cfscript>
				QueryAddRow(qMenuItems);
				QuerySetCell(qMenuItems, 'label', varSiteMap[i].pages[j].label);
				QuerySetCell(qMenuItems, 'url', varSiteMap[i].pages[j].url);
				</cfscript>
			</cfloop>
		</cfif>
	</cfloop>

	<cfreturn qMenuItems>
</cffunction>

<cffunction name="getSectionByLabel" access="public" returntype="string" output="no" hint="I get the name of the section with the given label.">
	<cfargument name="SectionLabel" type="string" required="yes">
	
	<cfset var result = "">
	<cfset var i = 0>
	
	<cfloop index="i" from="1" to="#ArrayLen(variables.SiteMap)#" step="1">
		<cfif variables.SiteMap[i].label eq arguments.SectionLabel>
			<cfset result = variables.SiteMap[i].name>
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSectionLabel" access="public" returntype="string" output="no" hint="I get the name of the section with the given label.">
	<cfargument name="SectionName" type="string" required="yes">
	
	<cfset var result = "">
	<cfset var i = 0>
	
	<cfloop index="i" from="1" to="#ArrayLen(variables.SiteMap)#" step="1">
		<cfif variables.SiteMap[i].name eq arguments.SectionName>
			<cfset result = variables.SiteMap[i].label>
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSubsectionByLabel" access="public" returntype="string" output="no" hint="I get the name of the subsection with the given label.">
	<cfargument name="SubsectionLabel" type="string" required="yes">
	
	<cfset var result = "">
	<cfset var i = 0>
	<cfset var h = 0>
	
	<cfloop index="i" from="1" to="#ArrayLen(variables.SiteMap)#" step="1">
		<cfif ArrayLen(variables.SiteMap[i].subsections)>
			<cfloop index="h" from="1" to="#ArrayLen(variables.SiteMap[i].subsections)#" step="1">
				<cfif arguments.SubSectionLabel eq xmlFormat(variables.SiteMap[i].subsections[h].label)>
					<cfset result = variables.SiteMap[i].subsections[h].name>
					<cfbreak>
				</cfif>
			</cfloop>
		</cfif>
		<cfif Len(result)>
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSubsectionLabel" access="public" returntype="string" output="no" hint="I get the name of the subsection with the given label.">
	<cfargument name="Subsection" type="string" required="yes">
	
	<cfset var result = "">
	<cfset var i = 0>
	<cfset var h = 0>
	
	<cfloop index="i" from="1" to="#ArrayLen(variables.SiteMap)#" step="1">
		<cfif ArrayLen(variables.SiteMap[i].subsections)>
			<cfloop index="h" from="1" to="#ArrayLen(variables.SiteMap[i].subsections)#" step="1">
				<cfif arguments.Subsection eq xmlFormat(variables.SiteMap[i].subsections[h].name)>
					<cfset result = variables.SiteMap[i].subsections[h].label>
					<cfbreak>
				</cfif>
			</cfloop>
		</cfif>
		<cfif Len(result)>
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSectionLink" access="public" returntype="string" output="no" hint="I get the url for the given section/subsection.">
	<cfargument name="section" type="string" required="yes">
	
	<cfset var page = "">
	
	<cfloop index="i" from="1" to="#ArrayLen(variables.SiteMap)#" step="1">
		<cfif arguments.section eq xmlFormat(variables.SiteMap[i].name)>
			<cfset page = variables.SiteMap[i].url>
			<cfbreak>
		<cfelseif ArrayLen(variables.SiteMap[i].subsections)>
			<cfloop index="h" from="1" to="#ArrayLen(variables.SiteMap[i].subsections)#" step="1">
				<cfif arguments.section eq xmlFormat(variables.SiteMap[i].subsections[h].name)>
					<cfset page = variables.SiteMap[i].subsections[h].url>
					<cfbreak>
				</cfif>
			</cfloop>
			<cfif Len(page)><cfbreak></cfif>
		</cfif>
	</cfloop>
	
	<cfreturn page>
</cffunction>

<cffunction name="parseSiteMap" access="private" returntype="array" output="no" hint="I parse the XML object.">
	<cfargument name="sitemap" type="any" required="yes">
	
	<cfscript>
	var varMenu = XmlParse(arguments.sitemap,"yes");
	//var mySiteMap = ArrayNew(1);
	var arrSections = varMenu.XmlRoot.XmlChildren;
	var result = ArrayNew(1);
	var i = 0;
	var j = 0;
	var k = 0;

	//Loop through sections
	for ( i=1; i lte ArrayLen(arrSections); i=i+1 ) {
		//Add a new section in the result for each section in the xml
		ArrayAppend(result, StructNew()); 
		//Set the attributes for each section
		for (att in arrSections[i].XmlAttributes) {
			result[i][att] = arrSections[i].XmlAttributes[att];
		}
		//default "restricted" attribute to false:
		if ( Not StructKeyExists(result[i],"restricted") ) result[i]["restricted"] = false;
		//default "permissions" to empty:
		if ( Not StructKeyExists(result[i],"permissions") ) result[i]["permissions"] = "";
		
		//Set an array of any children of this section
		arKids = arrSections[i].XmlChildren;
		//Set arrays for pages and subsections in this section
		result[i]["subsections"] = ArrayNew(1);
		result[i]["pages"] = ArrayNew(1);
		
		//Look at each child of this section
		for ( j=1; j lte ArrayLen(arKids); j=j+1 ) {
			//If this child is a page, add it to the pages array
			if ( arKids[j].xmlName eq "page" ) {
				//Add new page
				ArrayAppend(result[i].pages, StructNew());
				//Set attributes for this page
				for (att in arKids[j].XmlAttributes) {
					result[i].pages[ArrayLen(result[i].pages)][att] = arKids[j].XmlAttributes[att];
				}
				//default "permissions" to empty:
				if ( Not StructKeyExists(result[i].pages[ArrayLen(result[i].pages)],"permissions") ) result[i].pages[ArrayLen(result[i].pages)]["permissions"] = "";
			//If this child is a subsection, add it to the subsections array
			} else if ( arKids[j].xmlName eq "subsection" ) {
				//Add a new subsection
				ArrayAppend(result[i].subsections, StructNew());
				//Set attributes for this subsection
				for (att in arKids[j].XmlAttributes) {
					result[i].subsections[ArrayLen(result[i].subsections)][att] = arKids[j].XmlAttributes[att];
				}
				//default "permissions" to empty:
				if ( Not StructKeyExists(result[i].subsections[ArrayLen(result[i].subsections)],"permissions") ) result[i].subsections[ArrayLen(result[i].subsections)]["permissions"] = "";
				//Set an array of pages for this subsection
				result[i].subsections[ArrayLen(result[i].subsections)].pages = ArrayNew(1);
				//Add each page to this subsection
				for (k=1; k lte ArrayLen(arKids[j].XmlChildren); k=k+1) {
					//Add a new page
					ArrayAppend(result[i].subsections[ArrayLen(result[i].subsections)].pages, StructNew());
					//Set attributes for this page
					for (att in arKids[j].XmlChildren[k].XmlAttributes) {
						result[i].subsections[ArrayLen(result[i].subsections)].pages[ArrayLen(result[i].subsections[ArrayLen(result[i].subsections)].pages)][att] = arKids[j].XmlChildren[k].XmlAttributes[att];
					}
					//default "permissions" to empty:
					if ( Not StructKeyExists(result[i].subsections[ArrayLen(result[i].subsections)].pages[ArrayLen(result[i].subsections[ArrayLen(result[i].subsections)].pages)],"permissions") ) result[i].subsections[ArrayLen(result[i].subsections)].pages[ArrayLen(result[i].subsections[ArrayLen(result[i].subsections)].pages)]["permissions"] = "";
				}// /for (subsection pages)
			}// /if (page or subsection)
		}// /for (section children)
	}// /for (sections)
	</cfscript>
	
	<cfreturn result>
</cffunction>

<cffunction name="ListHasCommon" access="private" returntype="boolean" output="no">
	<cfargument name="list1" type="string">
	<cfargument name="list2" type="string">
	<cfargument name="delim1" type="string" default=",">
	<cfargument name="delim2" type="string" default=",">
	
	<cfset var result = false>
	<cfset var i = 0>
	
	<cfscript>
	for (i=1; i LTE ListLen(list1, delim1); i=i+1) {
		if (ListFindNoCase(list2, ListGetAt(list1, i, delim1), delim2)){
			result = true;
		}
	}
	</cfscript>
	
	<cfreturn result>
</cffunction>

</cfcomponent>