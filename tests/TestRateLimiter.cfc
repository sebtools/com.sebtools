<cfcomponent displayname="Rate Limiter" extends="mxunit.framework.TestCase" output="no">
<!---
Rate Limiter should be able to:
--->
<cffunction name="beforeTests" access="public" returntype="void" output="no">

	<cfset Variables.Component = CreateObject("component","MockRateLimited.cfc").init()>

</cffunction>

<cffunction name="shouldGetFilePath" access="public" returntype="void" output="no"
	hint="FileMgr should be able to get the full file path of a file in a folder."
>

	<!--- Action: Get the path of the "example.txt" using getFilePath(). --->
	<cfset var testFilePath = Variables.FileMgr.getFilePath(FileName="example.txt")>

	<!--- Assert: The file path matches the location of that file. --->
	<cfset assertEquals('#Variables.UploadPath#example.txt',testFilePath,'File path returned is incorrect.')>

</cffunction>

<cffunction name="stub" access="public" returntype="void" output="no">
	<cfset fail("No test written yet.")>
</cffunction>

</cfcomponent>
