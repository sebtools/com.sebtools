<cfcomponent displayname="Volunteer Exchange 1.0" hint="I handle the exchange of volunteer information between the OK MRC and other volunteer organizations.">

<!---
%% I should use a shared-scope variable inside a CFC,
but I can't figure out how to get this information without this component being stored in state.
It can't be stored in state since it is accessed as a web service
--->
<cffunction name="init" access="public" returntype="void" output="no">
	<cfparam name="request.SystemDSN" default="MRCSQL" type="string">
	<cfset variables.datasource = request.SystemDSN>
	<cfset variables.VolexMgr = CreateObject("component","VolexMgr").init(variables.datasource)>
</cffunction>

<cffunction name="updateVolunteer" access="remote" returntype="boolean" output="no" hint="I update the given volunteer record with the given data and indicate if the update was successful.">
	<cfargument name="orgname" type="string" required="yes">
	<cfargument name="orgkey" type="string" required="yes">
	<cfargument name="uuid" type="string" required="yes">
	<cfargument name="data" type="string" required="yes">
	
	<cfset var result = false>
	
	<cfreturn result>
</cffunction>

<cffunction name="getVolunteer" access="remote" returntype="string" output="no" hint="I return the given volunteer.">
	<cfargument name="orgname" type="string" required="yes">
	<cfargument name="orgkey" type="string" required="yes">
	<cfargument name="uuid" type="string" required="yes">
	<cfargument name="data" type="string" required="yes">
	
	<cfset var result = false>
	
	<cfreturn result>
</cffunction>

<cffunction name="getUpdates" access="remote" returntype="array" output="no" hint="I return an array of volunteers that need to be updated from this system.">
	<cfargument name="orgname" type="string" required="yes">
	<cfargument name="orgkey" type="string" required="yes">
	
	<cfset var result = false>
	
	<cfreturn result>
</cffunction>

<cffunction name="runUpdates" access="remote" returntype="void" output="no" hint="I update any records on the calling system that have been added or changed. The calling system will be responsible to ensure that no data is corrupted.">
	<cfargument name="orgname" type="string" required="yes">
</cffunction>

<cffunction name="register" access="remote" returntype="boolean" output="no" hint="I process the registration of a new volunteer organization. The new organization will not be able to interact with this organization until approved.">
	<cfargument name="orgname" type="string" required="yes">
	<cfargument name="orgkey" type="string" required="yes">
	<cfargument name="wsloc" type="string" required="yes">
	<cfargument name="wsver" type="numeric" required="yes">
	<cfargument name="xmlver" type="numeric" required="yes">
	
	<cfreturn true>
</cffunction>

<cffunction name="checkOrgApproval" access="remote" returntype="boolean" output="no" hint="I indicate if the given organization has been approved.">
	<cfargument name="orgname" type="string" required="yes">
	<cfargument name="orgkey" type="string" required="yes">
	
	<cfreturn false>
</cffunction>

<cffunction name="UpdateOrg" access="remote" returntype="boolean" output="no" hint="I update the information about the given organization. orgname and orgkey must match and cannot be updated with this method.">
	<cfargument name="orgname" type="string" required="yes">
	<cfargument name="orgkey" type="string" required="yes">
	<cfargument name="wsloc" type="string" required="yes">
	<cfargument name="wsver" type="numeric" required="yes">
	<cfargument name="xmlver" type="numeric" required="yes">
	
	<cfreturn true>
</cffunction>

<cffunction name="UpdateOrgNameKey" access="remote" returntype="boolean" output="no" hint="I update the orgname and/or orgkey for the given organization.">
	<cfargument name="orgname" type="string" required="yes">
	<cfargument name="orgkey" type="string" required="yes">
	<cfargument name="neworgname" type="string" required="yes">
	<cfargument name="neworgkey" type="string" required="yes">
	
	<cfreturn true>
</cffunction>

</cfcomponent>