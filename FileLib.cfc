<cfcomponent>

<!---
 Mimics the cfdirectory, action=&quot;list&quot; command.
 Updated with final CFMX var code.
 Fixed a bug where the filter wouldn't show dirs.
 
 @param directory 	 The directory to list. (Required)
 @param filter 	 Optional filter to apply. (Optional)
 @param sort 	 Sort to apply. (Optional)
 @param recurse 	 Recursive directory list. Defaults to false. (Optional)
 @return Returns a query. 
 @author Raymond Camden (ray@camdenfamily.com) 
 @version 2, April 8, 2004 
--->
<cffunction name="directoryList" access="public" returnType="query" output="no">
	<cfargument name="directory" type="string" required="true">
	<cfargument name="filter" type="string" required="false" default="">
	<cfargument name="sort" type="string" required="false" default="">
	<cfargument name="recurse" type="boolean" required="false" default="false">
	<!--- temp vars --->
	<cfargument name="dirInfo" type="query" required="false">
	<cfargument name="thisDir" type="query" required="false">
	<cfset var path="">
    <cfset var temp="">
	
	<cfif not recurse>
		<cfdirectory name="temp" directory="#directory#" filter="#filter#" sort="#sort#">
		<cfreturn temp>
	<cfelse>
		<!--- We loop through until done recursing drive --->
		<cfif not isDefined("dirInfo")>
			<cfset dirInfo = queryNew("attributes,datelastmodified,mode,name,size,type,directory")>
		</cfif>
		<cfset thisDir = directoryList(directory,filter,sort,false)>
		<cfif server.os.name contains "Windows">
			<cfset path = "\">
		<cfelse>
			<cfset path = "/">
		</cfif>
		<cfloop query="thisDir">
			<cfset queryAddRow(dirInfo)>
			<cfset querySetCell(dirInfo,"attributes",attributes)>
			<cfset querySetCell(dirInfo,"datelastmodified",datelastmodified)>
			<cfset querySetCell(dirInfo,"mode",mode)>
			<cfset querySetCell(dirInfo,"name",name)>
			<cfset querySetCell(dirInfo,"size",size)>
			<cfset querySetCell(dirInfo,"type",type)>
			<cfset querySetCell(dirInfo,"directory",directory)>
			<cfif type is "dir">
				<!--- go deep! --->
				<cfset directoryList(directory & name & path,filter,sort,true,dirInfo)>
			</cfif>
		</cfloop>
		<cfreturn dirInfo>
	</cfif>
</cffunction>

<cffunction name="getDirDelim" access="public" returntype="string" output="no">
	<cfscript>
	var fileObj = createObject("java", "java.io.File");
	var result = fileObj.separator;
	
	return result;
	</cfscript>
</cffunction>

<cffunction name="makeUri" access="public" returntype="string" output="no">
	<cfargument name="FilePath" type="string" required="yes">
	<cfargument name="RootFilePath" type="string" required="yes">
	<cfargument name="RootUri" type="string" default="/">
	
	<cfset var result = ReplaceNoCase(FilePath,RootFilePath,"")>
	<cfset result = ReplaceNoCase(result, getDirDelim(),  "/", "ALL")>
	
	<cfif Left(result,1) neq "/">
		<cfset result = "/#result#">
	</cfif>
	
	<cfset result = ReplaceNoCase(result, "/", RootUri, "ONE")>
	
	<cfreturn result>
</cffunction>

</cfcomponent>