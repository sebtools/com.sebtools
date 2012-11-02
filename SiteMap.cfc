<cfcomponent displayname="Site Map" hint="I handle the site map information from an XML file.">

<cffunction name="init" access="public" returntype="SiteMap" output="no" hint="I initialize the Site Map with an XML object of the site map.">
	<cfargument name="SiteMapXML" type="any" required="yes">
	
	<cfset variables.SiteMapXML = arguments.SiteMapXML>
	<cfset variables.SiteMap = parseSiteMap(variables.SiteMapXML)>
	<cfset variables.xSiteMap = XmlParse(variables.SiteMapXML,"no")>
	
	<cfreturn this>
</cffunction>

<cffunction name="getSiteMap" access="public" returntype="array" output="no" hint="I return the complex variable holding the site map data.">
	<cfargument name="UserPermissions" type="string" required="no">
	
	<cfset var result = Duplicate(variables.SiteMap)>
	
	<cfscript>
	//Restrict by permissions
	if ( StructKeyExists(arguments,"UserPermissions") ) {
		result = getBranch(result,arguments.UserPermissions);
	}
	</cfscript>
	
	<cfreturn result>
</cffunction>

<cffunction name="getBranch" access="private" returntype="array" output="no" hint="I return a branch of the site map, based on permissions.">
	<cfargument name="Branch" type="array" required="yes">
	<cfargument name="Permissions" type="string" required="yes">
	
	<cfset var i = 0>
	<cfset var temp = 0>
	<cfset var key = "">
	<cfset var result = ArrayNew(1)>
	
	<cfscript>
	for ( i=1; i lte ArrayLen(Branch); i=i+1 ) {
		temp = Branch[i];
		if ( NOT ( isStruct(temp) AND StructKeyExists(temp,"permissions") AND Len(temp.permissions) AND Not ListHasCommon(arguments.Permissions, temp.permissions) ) ) {
			//recurse of any arrays in struct
			if ( isStruct(temp) ) {
				for (key in temp) {
					if ( isArray(temp[key]) ) {
						temp[key] = Duplicate(getBranch(temp[key],arguments.Permissions));
					}
				}
			}
			ArrayAppend(result,temp);
		}
	}
	</cfscript>
	
	<cfreturn result>
</cffunction>

<cffunction name="getMenuItems" access="public" returntype="query" output="no" hint="I get the menu items for the given section/subsection.">
	<cfargument name="section" type="string" required="yes">
	<cfargument name="subsection" type="string" default="">
	<cfargument name="permissions" type="string" required="no">
	
	<cfset var varSiteMap = XmlSiteMap()>
	<cfset var qMenuItems = QueryNew('label,url')>
	<cfset var elementA = 0>
	<cfset var elementB = 0>
	<cfset var element = ArrayNew(1)>
	<cfset var i = 0>
	
	<cfif Len(arguments.subsection)>
		<cfset elementA = XmlSearch(varSiteMap,'/site//subsection[@name="#arguments.subsection#"]/page')>
		<cfset elementB = XmlSearch(varSiteMap,'/site//section[@name="#arguments.subsection#"]/page')>
	<cfelseif Len(arguments.section)>
		<cfset elementA = XmlSearch(varSiteMap,'/site/section[@name="#arguments.section#"]/page')>
		<cfset elementB = XmlSearch(varSiteMap,'/site//section[@name="#arguments.section#"]/page')>
	</cfif>
	
	<cfif isArray(elementA) AND ArrayLen(elementA)>
		<cfset element = elementA>
	<cfelseif isArray(elementB) AND ArrayLen(elementB)>
		<cfset element = elementB>
	<cfelse>
		<cfif Len(arguments.subsection)>
			<cfset elementA = XmlSearch(varSiteMap,'/site//subsection[@label="#arguments.subsection#"]/page')>
			<cfset elementB = XmlSearch(varSiteMap,'/site//section[@label="#arguments.subsection#"]/page')>
		<cfelseif Len(arguments.section)>
			<cfset elementA = XmlSearch(varSiteMap,'/site/section[@label="#arguments.section#"]/page')>
			<cfset elementB = XmlSearch(varSiteMap,'/site//section[@label="#arguments.section#"]/page')>
		</cfif>
		<cfif isArray(elementA) AND ArrayLen(elementA)>
			<cfset element = elementA>
		<cfelseif isArray(elementB) AND ArrayLen(elementB)>
			<cfset element = elementB>
		</cfif>
	</cfif>
	
	<cfloop index="i" from="1" to="#ArrayLen(element)#" step="1">
		<cfscript>
		if ( StructKeyExists(element[i],"XmlAttributes") ) {// AND NOT ( StructKeyExists(arguments.permissions) )
			//Check restrictions/permissions
			if ( NOT StructKeyExists(arguments,"permissions") OR NOT ( StructKeyExists(element[i].XmlAttributes,"restricted") AND isBoolean(element[i].XmlAttributes["restricted"]) AND element[i].XmlAttributes["restricted"]) OR ListHasCommon(element[i].XmlAttributes["permissions"],arguments.permissions) ) {
				QueryAddRow(qMenuItems);
				if ( StructKeyExists(element[i].XmlAttributes,"label") ) {
					QuerySetCell(qMenuItems, 'label', element[i].XmlAttributes["label"]);
				}
				if ( StructKeyExists(element[i].XmlAttributes,"url") ) {
					QuerySetCell(qMenuItems, 'url', element[i].XmlAttributes["url"]);
				}
			}
		}
		</cfscript>
	</cfloop>
	
	<cfreturn qMenuItems>
</cffunction>

<cffunction name="getPageLabel" access="public" returntype="string" hint="I return the label of the page based on its url.">
	<cfargument name="SCRIPT_NAME" type="string" required="yes">
	
	<cfset var element = XmlSearch(variables.xSiteMap,'/site//page[@url="#XmlFormat(arguments.SCRIPT_NAME)#"]')>
	<cfset var result = "">
	
	<cfif isArray(element) AND ArrayLen(element) eq 1 AND StructKeyExists(element[1],"XmlAttributes") AND StructKeyExists(element[1].XmlAttributes,"label")>
		<cfset result = element[1].XmlAttributes["label"]>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getPageSection" access="public" returntype="string" hint="I return the section name for the given page.">
	<cfargument name="SCRIPT_NAME" type="string" required="yes">
	
	<cfset var element = XmlSearch(variables.xSiteMap,'/site/section//page[@url="#arguments.SCRIPT_NAME#"]/ancestor::section')>
	<cfset var result = "">
	
	<cfif isArray(element) AND ArrayLen(element) eq 1 AND StructKeyExists(element[1],"XmlAttributes")>
		<cfif StructKeyExists(element[1].XmlAttributes,"name") AND Len(Trim(element[1].XmlAttributes["name"]))>
			<cfset result = element[1].XmlAttributes["name"]>
		<cfelseif StructKeyExists(element[1].XmlAttributes,"label") AND Len(Trim(element[1].XmlAttributes["label"]))>
			<cfset result = element[1].XmlAttributes["label"]>
		</cfif>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSectionByLabel" access="public" returntype="string" output="no" hint="I get the name of the section with the given label.">
	<cfargument name="SectionLabel" type="string" required="yes">
	
	<cfset var element = XmlSearch(variables.xSiteMap,'/site/section[@label="#arguments.SectionLabel#"]')>
	<cfset var result = "">
	
	<cfif isArray(element) AND ArrayLen(element) eq 1 AND StructKeyExists(element[1],"XmlAttributes") AND StructKeyExists(element[1].XmlAttributes,"name")>
		<cfset result = element[1].XmlAttributes["name"]>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSectionLabel" access="public" returntype="string" output="no" hint="I get the label of the section with the given name.">
	<cfargument name="SectionName" type="string" required="yes">
	
	<cfset var element = XmlSearch(variables.xSiteMap,'/site/section[@name="#arguments.SectionName#"]')>
	<cfset var result = "">
	
	<cfif isArray(element) AND ArrayLen(element) eq 1 AND StructKeyExists(element[1],"XmlAttributes") AND StructKeyExists(element[1].XmlAttributes,"label")>
		<cfset result = element[1].XmlAttributes["label"]>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSubsectionByLabel" access="public" returntype="string" output="no" hint="I get the name of the subsection with the given label.">
	<cfargument name="SubsectionLabel" type="string" required="yes">
	
	<cfset var elementA = XmlSearch(variables.xSiteMap,'/site//subsection[@label="#arguments.SubsectionLabel#"]')>
	<cfset var elementB = XmlSearch(variables.xSiteMap,'/site//section[@label="#arguments.SubsectionLabel#"]')>
	<cfset var result = "">
	
	<cfif isArray(elementA) AND ArrayLen(elementA) gte 1 AND StructKeyExists(elementA[1],"XmlAttributes") AND StructKeyExists(elementA[1].XmlAttributes,"name")>
		<cfset result = elementA[1].XmlAttributes["name"]>
	<cfelseif isArray(elementB) AND ArrayLen(elementB) gte 1 AND StructKeyExists(elementB[1],"XmlAttributes") AND StructKeyExists(elementB[1].XmlAttributes,"name")>
		<cfset result = elementB[1].XmlAttributes["name"]>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSubsectionLabel" access="public" returntype="string" output="no" hint="I get the label of the subsection with the given name.">
	<cfargument name="Subsection" type="string" required="yes">
	
	<cfset var elementA = XmlSearch(variables.xSiteMap,'/site//subsection[@name="#arguments.Subsection#"]')>
	<cfset var elementB = XmlSearch(variables.xSiteMap,'/site//section[@name="#arguments.Subsection#"]')>
	<cfset var result = "">
	
	<cfif isArray(elementA) AND ArrayLen(elementA) gte 1 AND StructKeyExists(elementA[1],"XmlAttributes") AND StructKeyExists(elementA[1].XmlAttributes,"label")>
		<cfset result = elementA[1].XmlAttributes["label"]>
	<cfelseif isArray(elementB) AND ArrayLen(elementB) gte 1 AND StructKeyExists(elementB[1],"XmlAttributes") AND StructKeyExists(elementB[1].XmlAttributes,"label")>
		<cfset result = elementB[1].XmlAttributes["label"]>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSectionLink" access="public" returntype="string" output="no" hint="I get the url of the section with the given name.">
	<cfargument name="section" type="string" required="yes">
	
	<cfset var elementA = XmlSearch(variables.xSiteMap,'/site//section[@name="#arguments.section#"]')>
	<cfset var elementB = XmlSearch(variables.xSiteMap,'/site//subsection[@name="#arguments.section#"]')>
	<cfset var result = "">
	
	<cfif isArray(elementA) AND ArrayLen(elementA) gte 1 AND StructKeyExists(elementA[1],"XmlAttributes") AND StructKeyExists(elementA[1].XmlAttributes,"url")>
		<cfset result = elementA[1].XmlAttributes["url"]>
	<cfelseif isArray(elementB) AND ArrayLen(elementB) gte 1 AND StructKeyExists(elementB[1],"XmlAttributes") AND StructKeyExists(elementB[1].XmlAttributes,"url")>
		<cfset result = elementB[1].XmlAttributes["url"]>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getGroupLinks" access="public" returntype="query" output="no" hint="I get a recordset of this pages brother links.">
	<cfargument name="scriptname" type="string" required="yes">
	<cfargument name="section" type="string" required="yes">
	
	<cfset var elementA = "">
	<cfset var elementB = "">
	<cfset var result = querynew("label,url")>
	<cfset var elements = "">
	<cfset var i = 0>
	
	<!--- if we are looking at the top level --->
	<cfif scriptname EQ "/" OR scriptname EQ "/index.cfm">
		<cfset elements = XmlSearch(variables.xSiteMap,'/site//section[@name!="admin"]')>
		<cfloop index="i" from="1" to="#arraylen(elements)#">
			<cfset QueryAddRow(result)>
			<cfset querySetCell(result,'label',elements[i].xmlattributes.label)>
			<cfset querySetCell(result,'url',elements[i].xmlattributes.url)>
		</cfloop>
		<cfreturn result>
	</cfif>
	
	<!--- <cfif right(scriptname, 9) EQ 'index.cfm'>
		<cfset scriptname = left(scriptname,len(scriptname) - 9)>
	</cfif> --->

	<cfset elements = XmlSearch(variables.xSiteMap,"/site/section[@name='#section#']//subsection[@url='#scriptname#']")>
	
	<cfif arraylen(elements) EQ 0>

		<cfset elements = XmlSearch(variables.xSiteMap,"/site/section[@name='#section#']//*[@url='#scriptname#']/..")>
	</cfif>

	<cfif arraylen(elements) EQ 0 OR elements[1].xmlname EQ 'site'>
		<cfreturn result>
	</cfif>
	
	<cfloop index="i" from="1" to="#arraylen(elements[1].xmlChildren)#">
		<cfif elements[1].xmlChildren[i].xmlattributes.label NEQ 'admin'>
			<cfset QueryAddRow(result)>
			<cfset querySetCell(result,'label',elements[1].xmlChildren[i].xmlattributes.label)>
			<cfset querySetCell(result,'url',elements[1].xmlChildren[i].xmlattributes.url)>
		</cfif>
	</cfloop>
	
	<cfreturn result>
</cffunction>

<cffunction name="getSubSectionLabelByScriptName" access="public" returntype="string" output="no" hint="I get a subsection label if there exists one">
	<cfargument name="scriptname" type="string" required="yes">
	<cfset var elements = "">

	<cfset elements = XmlSearch(variables.xSiteMap,"//subsection/*[@url='#scriptname#']/..")>

	<cfif arraylen(elements) EQ 0 OR elements[1].xmlname EQ 'site'>
		<cfreturn "">
	</cfif>
	
	<cfreturn elements[1].xmlattributes.label>

</cffunction>

<cffunction name="getSectionLinks" access="public" returntype="query" output="no" hint="I get a recordset of links from this section.">
	<cfargument name="section" type="string" required="yes">
	<cfset var result = querynew("label,url")>
	<cfset var elements = "">
	<cfset var xpath = "/site/section[@name='#section#']/subsection">
	<cfset var i = 0>
<!--- <cfoutput>#xpath# --->
	<cfset elements = XmlSearch(variables.xSiteMap,xpath)>
<!--- <cfdump var=#elements#><cfabort></cfoutput>	 --->
	<cfif arraylen(elements) EQ 0>
		<cfreturn result>
	</cfif>
	
	<cfloop index="i" from="1" to="#arraylen(elements)#">
		<cfset QueryAddRow(result)>
		<cfset querySetCell(result,'label',elements[i].xmlattributes.label)>
		<cfset querySetCell(result,'url',elements[i].xmlattributes.url)>
	</cfloop>
	
	<cfreturn result>
</cffunction>



<cffunction name="makeFiles" access="public" returntype="void" output="no" hint="I create all of the files in the site map.">
	<cfargument name="rootPath" type="string" required="yes" hint="I am the absolute root path of the site in which files will be created.">
	<cfargument name="startcode" type="string" required="yes" hint="I am the code to put in each file as it is created.">
	<cfargument name="recreateExistingFiles" type="boolean" default="false">
	
	<cfset var fileObj = createObject("java", "java.io.File")>
	<cfset var dirdelim = fileObj.separator><!--- file delim of "/" or "\" depending on system. --->
	
	<!--- Make sure that rootPath ends with file seperator --->
	<cfif Right(arguments.rootPath,1) neq dirdelim>
		<cfset arguments.rootPath = arguments.rootPath & dirdelim>
	</cfif>
	
	<cfset makeBranchFiles(getSiteMap(),rootPath,startcode,recreateExistingFiles)>
	
</cffunction>

<cffunction name="makeBranchFiles" access="public" returntype="void" output="no" hint="I create the files in the given branch.">
	<cfargument name="Branch" type="array" required="yes" hint="I am the branch of the site for which to create files.">
	<cfargument name="rootPath" type="string" required="yes" hint="I am the absolute root path of the site in which files will be created.">
	<cfargument name="startcode" type="string" required="yes" hint="I am the code to put in each file as it is created.">
	<cfargument name="recreateExistingFiles" type="boolean" default="false">
	
	<cfset var fileObj = createObject("java", "java.io.File")>
	<cfset var dirdelim = fileObj.separator><!--- file delim of "/" or "\" depending on system. --->
	<cfset var Template = arguments.startcode>
	<cfset var i = 0>
	<cfset var temp = 0>
	<cfset var key = "">
	<cfset var result = ArrayNew(1)>
	
	<cfloop index="i" from="1" to="#ArrayLen(Branch)#" step="1">
		<cfset temp = Branch[i]>
		<cfif isStruct(temp) AND StructKeyExists(temp,"url") AND Len(temp.url)>
			<cfset thisFile = arguments.rootPath & ReplaceNoCase(temp.url, "/", dirdelim, "ALL")>
			<cfset thisFile = ReplaceNoCase(thisFile, "#dirdelim##dirdelim#", dirdelim)>
			<cfif arguments.recreateExistingFiles OR NOT FileExists(thisFile)>
				<cffile action="WRITE" file="#thisFile#" output="#Template#" addnewline="No">
			</cfif>
		</cfif>
		<cfif isArray(temp) AND ArrayLen(temp)>
			<cfset makeBranchFiles(Branch,rootPath,startcode,recreateExistingFiles)>
		</cfif>
	</cfloop>
	
</cffunction>

<cffunction name="parseSiteMap" access="private" returntype="array" output="no" hint="I parse the XML object.">
	<cfargument name="sitemap" type="any" required="yes">
	
	<cfscript>
	var varMenu = XmlParse(arguments.sitemap,"yes");
	var arrSections = varMenu.XmlRoot.XmlChildren;
	var result = ArrayNew(1);
	var ii = 0;
	var temp = 0;

	//Loop through sections
	for ( ii=1; ii lte ArrayLen(arrSections); ii=ii+1 ) {
		//Add a new section in the result for each section in the xml
		ArrayAppend(result, StructNew()); 
		
		//Set the attributes for each section
		for (att in arrSections[ii].XmlAttributes) {
			result[ii][att] = arrSections[ii].XmlAttributes[att];
		}
		
		//default "restricted" attribute to false:
		if ( Not StructKeyExists(result[ii],"restricted") ) result[ii]["restricted"] = false;
		
		//default "permissions" to empty:
		if ( Not StructKeyExists(result[ii],"permissions") ) {
			result[ii]["permissions"] = "";
		}
		
		//default "url" to empty:
		if ( Not StructKeyExists(result[ii],"url") ) {
			result[ii]["url"] = "";
		}
		
		//Set arrays for pages and subsections in this section
		temp = parseBranch(arrSections[ii]);
		result[ii]["subsections"] = Duplicate(temp["subsections"]);
		result[ii]["pages"] = Duplicate(temp["pages"]);
		result[ii]["children"] = Duplicate(temp["children"]);
	}// /for (sections)
	</cfscript>
	
	<cfreturn result>
</cffunction>

<cffunction name="parseBranch" access="private" returntype="struct" hint="I parse a branch of the site map.">
	<cfargument name="section" type="any" required="yes">
	
	<cfset var arKids = section.XmlChildren>
	<cfset var result = StructNew()>
	<cfset var ii = 0>
	<cfset var att = "">
	<cfset var children = ArrayNew(1)>
	
	<cfscript>
	result["childtype"] = "subsection";
	
	for (att in section.XmlAttributes) {
		result[att] = section.XmlAttributes[att];
	}
		
	//default "restricted" attribute to false:
	if ( Not StructKeyExists(result,"restricted") ) result["restricted"] = false;
		
	//default "permissions" to empty:
	if ( Not StructKeyExists(result,"permissions") ) {
		result["permissions"] = "";
	}
	
	//default "url" to empty:
	if ( Not StructKeyExists(result,"url") ) {
		result["url"] = "";
	}
	
	for ( ii=1; ii lte ArrayLen(arKids); ii=ii+1 ) {
		//Add new child
		ArrayAppend(children, StructNew());
		//Set attributes for this child
		for (att in arKids[ii].XmlAttributes) {
			children[ArrayLen(children)][att] = arKids[ii].XmlAttributes[att];
		}
		
		//default "permissions" to empty:
		if ( Not StructKeyExists(children[ArrayLen(children)],"permissions") ) {
			children[ArrayLen(children)]["permissions"] = "";
		}
		
		//default "url" to empty:
		if ( Not StructKeyExists(children[ArrayLen(children)],"url") ) {
			children[ArrayLen(children)]["url"] = "";
		}
		
		//If this child is a page, add it to the pages array
		if ( arKids[ii].xmlName eq "page" ) {
			children[ArrayLen(children)]["childtype"] = "page";
		} else {
			children[ArrayLen(children)]["childtype"] = "subsection";
			if  ( StructKeyExists(arKids[ii],"XmlChildren") AND ArrayLen(arKids[ii].XmlChildren) ) {
				children[ArrayLen(children)] = parseBranch(arKids[ii]);
			}		
		}
	}
	
	result["children"] = children;
	result["subsections"] = ArrayNew(1);
	result["pages"] = ArrayNew(1);
	
	for ( ii=1; ii lte ArrayLen(children); ii=ii+1 ) {
		if ( children[ii]["childtype"] eq "page" ) {
			ArrayAppend(result["pages"],Duplicate(children[ii]));
		} else {
			ArrayAppend(result["subsections"],Duplicate(children[ii]));
		}
	}
	</cfscript>
	
	<cfreturn result>
</cffunction>

<cffunction name="XmlSiteMap" access="public" returntype="any" output="no" hint="I parse the XML object.">
	<cfargument name="sitemap" type="any" default="#variables.SiteMapXML#">
	
	<cfscript>
	var xSiteMap = XmlParse(arguments.sitemap,"yes");
	var result = Duplicate(xSiteMap);
	var ii = 0;
	var temp = 0;
	
	//Loop through sections
	for ( ii=1; ii lte ArrayLen(result.XmlRoot.XmlChildren); ii=ii+1 ) {
		result.XmlRoot.XmlChildren[ii] = XmlSiteMapBranch(result.XmlRoot.XmlChildren[ii]);
	}
	</cfscript>
	
	<cfreturn result>
</cffunction>

<cffunction name="XmlSiteMapBranch" access="private" returntype="any" output="no" hint="I parse the XML object.">
	<cfargument name="element" type="any">
	<!--- <cfargument name="parent" type="any"> --->
	
	<cfset var ii = 0>
	<cfset var parent = element.XmlParent>
	
	<cfscript>
	//default "restricted" attribute to parent/false:
	if ( Not StructKeyExists(element.XmlAttributes,"restricted") ) {
		if ( StructKeyExists(parent.XmlAttributes,"restricted") ) {
			element.XmlAttributes["restricted"] = parent.XmlAttributes["restricted"];
		} else {
			element.XmlAttributes["restricted"] = false;
		}
	}
	
	if ( StructKeyExists(element.XmlAttributes,"permissions") ) {
		//If this element requires permissions, and parent is restricted then permissions to see this page are permissions for parent and for this element.
		if ( StructKeyExists(parent.XmlAttributes,"restricted") AND parent.XmlAttributes["restricted"] ) {
			element.XmlAttributes["permissions"] = ListInCommon(element.XmlAttributes["permissions"], parent.XmlAttributes["permissions"]);
		}
	} else {
		//default "permissions" to parent/empty:
		if ( StructKeyExists(parent.XmlAttributes,"permissions") ) {
			element.XmlAttributes["permissions"] = parent.XmlAttributes["permissions"];
		} else {
			element.XmlAttributes["permissions"] = "";
		}
	}
	
	//If this element has permissions associated with it, it is restricted
	if ( Len(element.XmlAttributes["permissions"]) ) {
		element.XmlAttributes["restricted"] = true;
	}
	
	//default "url" to empty:
	if ( Not StructKeyExists(element.XmlAttributes,"url") ) {
		element.XmlAttributes["url"] = "";
	}
	
	if ( StructKeyExists(element,"XmlChildren") AND isArray(element.XmlChildren) AND ArrayLen(element.XmlChildren) ) {
		for ( ii=1; ii lte ArrayLen(element.XmlChildren); ii=ii+1 ) {
			element.XmlChildren[ii] = XmlSiteMapBranch(element.XmlChildren[ii]);
		}
	}
	</cfscript>
	
	<cfreturn element>
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

<!---
author Kreig Zimmerman (kkz@foureyes.com) 
version 1, November 15, 2002 
--->
<cffunction name="XMLUnFormat" access="private" returntype="string" output="no" hint="UN-escapes the five forbidden characters in XML data.">
	<cfargument name="string" type="string" required="yes" hint="String to format">
	<cfscript>
	var resultString=string;
	resultString=ReplaceNoCase(resultString,"&apos;","'","ALL");
	resultString=ReplaceNoCase(resultString,"&quot;","""","ALL");
	resultString=ReplaceNoCase(resultString,"&lt;","<","ALL");
	resultString=ReplaceNoCase(resultString,"&gt;",">","ALL");
	resultString=ReplaceNoCase(resultString,"&amp;","&","ALL");
	return resultString;
	</cfscript>
</cffunction>

<!---
Based on ListCompare by Rob Brooks-Bilson (rbils@amkor.com)
return Returns a delimited list of values. 
author Michael Slatoff (michael@slatoff.com) 
version 1, August 20, 2001 
--->
<cffunction name="ListInCommon" access="private" returntype="string" output="no" hint="Returns elements in list1 that are found in list2.">
	<cfargument name="List1" type="string" required="yes" hint="Full list of delimited values.">
	<cfargument name="List2" type="string" required="yes" hint="Delimited list of values you want to compare to List1.">
	<cfargument name="Delim1" type="string" default="," hint="Delimiter used for List1.">
	<cfargument name="Delim2" type="string" default="," hint="Delimiter used for List2.">
	<cfargument name="Delim3" type="string" default="," hint="Delimiter to use for the list returned by the function.">
	<cfscript>
	var TempList = "";
	var i = 0;
	/* Loop through the second list, checking for the values from the first list.
	* Add any elements from the second list that are found in the first list to the
	* temporary list
	*/  
	for (i=1; i LTE ListLen(List2, "#Delim2#"); i=i+1) {
		if (ListFindNoCase(List1, ListGetAt(List2, i, "#Delim2#"), "#Delim1#")){
			TempList = ListAppend(TempList, ListGetAt(List2, i, "#Delim2#"), "#Delim3#");
		}
	}
	Return TempList;
	</cfscript>
</cffunction>

</cfcomponent>