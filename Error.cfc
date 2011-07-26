<cfcomponent displayname="Error" hint="Error CFC allows you to show an error on a page other than the page on which the error is raised. Error CFC should be instantiated (using init) into a persistent scope.">

<cffunction name="init" access="public" returntype="Error" output="no" hint="I instantiate and return the current object.">
	<cfargument name="validateType" type="boolean" default="false" hint="If true, all errors must use an error type available to Error.cfc (one of the default types, or one added with setType).">

	<cfscript>
	variables.this = StructNew();
	variables.this.Errors = StructNew();
	variables.this.Types = StructNew();
	
	variables.this.validateType = arguments.validateType;
	setTypes("Application,Database,Template,Security,Object,Synchronization,MissingInclude,Expression,Lock");
	setType("ErrorCFC");
	setError("No such error type","ErrorCFC","ErrorCFCMissingType","Make sure to create an error type before using it.");
	
	This["throw"] = throwErr;
	</cfscript>

	<cfreturn this>
</cffunction>

<cffunction name="getErrorData" access="public" returntype="struct" output="no">
	<cfreturn variables.this.Errors>
</cffunction>

<cffunction name="getError" access="public" returntype="struct" output="no" hint="I return a structure of the error with the following keys: message,type,detail,extendedinfo.">
	<cfargument name="errorcode" type="string" required="yes">
	
	<cfset var result = StructNew()>
	
	<cfif StructKeyExists(variables.this.Errors,arguments.errorcode)>
		<cfset result = variables.this.Errors[arguments.errorcode]>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getErrorMessage" access="public" returntype="string" output="no" hint="I Return the error message for the given error.">
	<cfargument name="errorcode" type="string" required="yes">
	<cfreturn getMessage(arguments.errorcode)>
</cffunction>

<cffunction name="getExtendedInfo" access="public" returntype="string" output="no" hint="I Return the error message for the given error.">
	<cfargument name="errorcode" type="string" required="yes">
	
	<!--- Set message to "unknown error" in case this error doesn't exist in the Error object. --->
	<cfset var message = "">
	<cfif StructKeyExists(variables.this.Errors, arguments.errorcode)>
		<!--- If the error is in the Error object, return the message for the error --->
		<cfset message = variables.this.Errors[arguments.errorcode].extendedinfo>
	</cfif>
	
	<cfreturn message>
</cffunction>

<cffunction name="getMessage" access="public" returntype="string" output="no" hint="I Return the error message for the given error.">
	<cfargument name="errorcode" type="string" required="yes">
	
	<!--- Set message to "unknown error" in case this error doesn't exist in the Error object. --->
	<cfset var message = "unknown error">
	<cfif StructKeyExists(variables.this.Errors, arguments.errorcode)>
		<!--- If the error is in the Error object, return the message for the error --->
		<cfset message = variables.this.Errors[arguments.errorcode].message>
	</cfif>
	
	<cfreturn message>
</cffunction>

<cffunction name="pass" access="public" returntype="void" output="no" hint="I add a caught error to the error object and send the browser to another page to display the error.">
	<cfargument name="passto" type="string" required="yes">
	<cfargument name="errordata" type="struct" required="yes">
</cffunction>

<cffunction name="removeError" access="public" returntype="void" output="no">
	<cfargument name="errorcode" type="string" required="yes">
	
	<cfset StructDelete(variables.this.Errors, arguments.errorcode)>
	
</cffunction>

<cffunction name="setError" access="public" returntype="void" output="no" hint="I Add the given error to the errors in Error.cfc so that it can be referenced later.">
	<cfargument name="message" type="string" required="yes">
	<cfargument name="type" type="string" required="yes">
	<cfargument name="errorcode" type="string" required="yes">
	<cfargument name="detail" type="string" required="no" default="">
	<cfargument name="extendedinfo" type="string" required="no" default="">
	
	<!--- If the Error object is set to only allow error types it is aware of, throw an error if the error type is not in the Error object.. --->
	<cfif variables.this.validateType AND Not StructKeyExists(variables.this.Types, arguments.type)>
		<cfthrow message="No such error type" type="ErrorCFC" detail="Make sure to create an error type before using it." errorcode="ErrorCFCMissingType">
	</cfif>
	<!--- Add a new error to the Error object. --->
	<cfscript>
	variables.this.Errors[arguments.errorcode] = StructNew();
	variables.this.Errors[arguments.errorcode].message = arguments.message;
	variables.this.Errors[arguments.errorcode].type = arguments.type;
	variables.this.Errors[arguments.errorcode].detail = arguments.detail;
	variables.this.Errors[arguments.errorcode].extendedinfo = arguments.extendedinfo;
	</cfscript>
	
</cffunction>

<cffunction name="setType" access="public" returntype="void" output="no" hint="I add an error type - useful if you want to limit errors to using specific types.">
	<cfargument name="type" type="string" required="yes">

	<cfif Not StructKeyExists(variables.this.Types,arguments.type)>
		<cfset variables.this.Types[arguments.type] = true>
	</cfif>
</cffunction>

<cffunction name="showError" access="public" returntype="string" output="no">
	<cfargument name="errorcode" type="string" required="yes">
	<cfargument name="class" type="string" required="yes">
	<cfargument name="remove" type="boolean" default="true">
	
	<cfset var result = ''>
	
	<cfif Len(arguments.errorcode)>
		<cfsavecontent variable="result"><cfoutput><p class="#arguments.class#">#getErrorMessage(arguments.errorcode)#</p></cfoutput></cfsavecontent>
	</cfif>
	
	<!--- <cfset removeError(arguments.errorcode)> --->
	
	<cfreturn result>
</cffunction>

<cffunction name="throwError" access="public" returntype="variableName" output="no" hint="I Add the given error to Error.cfc and then I throw that error.">
	<cfargument name="message" type="string" required="yes">
	<cfargument name="type" type="string" required="yes">
	<cfargument name="errorcode" type="string" required="yes">
	<cfargument name="detail" type="string" required="no" default="">
	<cfargument name="extendedinfo" type="string" required="no" default="">
	
	<cfset setError(arguments.message,arguments.type,arguments.errorcode,arguments.detail,arguments.extendedinfo)>
	<cfset throw(arguments.errorcode)>
</cffunction>

<cffunction name="throwErr" access="public" returntype="variableName" output="no" hint="I Throw an error that is already available in Error.cfc">
	<cfargument name="errorcode" type="string" required="yes">
	
	<cfset var Error = getError(arguments.errorcode)>
	
	<cfthrow message="#Error.message#" type="#Error.type#" detail="#Error.detail#" errorcode="#Error.errorcode#" extendedinfo="#Error.extendedinfo#">
</cffunction>

<cffunction name="setTypes" access="private" returntype="void" output="no" hint="I am called from the constructor and I set default error types.">
	<cfargument name="types" type="string" required="yes">
	
	<cfloop index="type" list="arguments.type">
		<cfset setType(type)>
	</cfloop>

</cffunction>

</cfcomponent>