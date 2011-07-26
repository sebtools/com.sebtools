<cfcomponent displayname="Form Wizard" hint="I handle general tasks relating to a multi-step form process.">

<cffunction name="init" access="public" returntype="FormWizard" output="no">
	<cfscript>
	variables.keys = "";
	variables.isFormMapped = false;
	variables.InfoStructs = "";
	variables.Storage = StructNew();
	</cfscript>
	<cfreturn this>
</cffunction>

<cffunction name="setFormMap" access="public" returntype="void" output="no" hint="I set the form map which must be a structure containing a key for every group of information in the process. Each must in turn be a structure with the keys of fields (to store all of the field names) and required (to store the name of required fields).">
	<cfargument name="FormMap" type="struct" required="yes">
	
	<cfset var key = "">
	
	<cfif variables.isFormMapped>
		<cfthrow message="FormMap has already been created." type="MethodErr" detail="You cannot create the FormMap more than once for a given process." errorcode="FormMapExists">
	</cfif>
	
	<!--- %%Need to verify structure of FormMap, including the required includes only fields in fields --->
	
	<cfscript>
	variables.FormMap = arguments.FormMap;
	
	for (key in variables.FormMap) {
		variables.InfoStructs = ListAppend(variables.InfoStructs,key);
	}
	
	variables.isFormMapped = true;
	</cfscript>
	
</cffunction>

<cffunction name="getInfoStructs" access="package" returntype="string" output="no" hint="I return a list of the structures used to hold registration information.">
	<cfset checkIsMapped()>
	
	<cfreturn variables.InfoStructs>
</cffunction>

<cffunction name="getFieldLists" access="package" returntype="struct" output="no" hint="I return a structure with a list of fields for each type of registration information.">

	<cfscript>
	var fieldlists = StructNew();
	var key = "";
	
	checkIsMapped();
	
	for (key in variables.FormMap) {
		fieldlists[key] = variables.FormMap[key]["fields"];
	}
	</cfscript>
	
	<cfreturn fieldlists>
</cffunction>

<cffunction name="getRequiredLists" access="package" returntype="struct" output="no" hint="I return a structure with a list of required fields for each type of registration information.">
	<cfscript>
	var requiredlists = StructNew();
	var key = "";
	
	checkIsMapped();
	
	for (key in variables.FormMap) {
		requiredlists[key] = variables.FormMap[key]["required"];
	}
	</cfscript>
	
	<cfreturn requiredlists>
</cffunction>

<cffunction name="checkIsMapped" access="package" returntype="void" output="no">
	<cfif Not isDefined("variables.isFormMapped")>
		<cfthrow message="This method cannot be run unless the form wizard has been initiated - using init() or super.init()." type="MethodErr" detail="This method of this FormWizard requires that the structure of information for this FormWizard has been set (by calling its setFormMap method)." errorcode="NeedsInit">
	</cfif>
	<cfif Not variables.isFormMapped>
		<cfthrow message="This method cannot be run unless the form wizard structure has been created." type="MethodErr" detail="This method of this FormWizard requires that the structure of information for this FormWizard has been set (by calling its setFormMap method)." errorcode="FormMapRequired">
	</cfif>
</cffunction>

<cffunction name="checkReqFields" access="public" returntype="void" output="no" hint="I Throw an error if some required fields are missing.">
	<cfargument name="fields" type="string" required="yes">
	<cfargument name="ArgStruct" type="struct" required="yes">
	
	<cfset var missingfields = "">
	<cfset checkIsMapped()>
	
	<!--- Loop over required fields --->
	<cfloop index="field" list="#arguments.fields#">
		<!--- If the field is missing, add it to the list of missing fields --->
		<cfif Not (StructKeyExists(arguments.ArgStruct, field) AND Len(arguments.ArgStruct[field]))>
			<cfset missingfields = ListAppend(missingfields, field)>
		</cfif>
	</cfloop>
	<!--- If any required fields are missing, throw an error. --->
	<cfif Len(missingfields)>
		<cfthrow message="Required fields (#missingfields#) are missing." type="MethodErr" detail="The following fields are required: #arguments.fields#. Of those, the following are missing #missingfields#." errorcode="MissingField" extendedinfo="#missingfields#">
	</cfif>
	
</cffunction>

<!--- ********************** END OF WIZARD GENERATION ********************************* --->
<!--- ********************** START OF INFORMATION TRACKING  ********************************* --->

<cffunction name="begin" access="public" returntype="UUID" output="no">
	<cfscript>
	var processkey = CreateUUID();
	var key = "";
	var i = 1;
	var tmpField = "";
	
	checkIsMapped();

	variables.Storage[processkey] = StructNew();
	
	for (key in variables.FormMap) {
		variables.Storage[processkey][key] = StructNew();
		for (i=1; i lte ListLen(variables.FormMap[key].fields); i=i+1) {
			tmpField = ListGetAt(variables.FormMap[key].fields,i);
			variables.Storage[processkey][key][tmpField] = "";
		}
	}
	</cfscript>
	
	<cfreturn processkey>
</cffunction>

<cffunction name="setInfoStruct" access="package" returntype="void" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	<cfargument name="fielddata" type="struct" required="yes">
	
	<cfset fields = arguments.fielddata>
	
	<!--- Loop over each field in this struct --->
	<cfloop index="field" list="#variables.FormMap[InfoStruct].fields#">
		<!--- If information is passed in for this field, set the same field in info struct --->
		<cfif StructKeyExists(fields, field)>
			<cfset variables.Storage[arguments.processkey][arguments.InfoStruct][field] = fields[field]>
		</cfif>
	</cfloop>
	
	<!--- Check required fields --->
	<cfset this.checkReqFields(variables.FormMap[InfoStruct].required,fields)>
	
</cffunction>

<cffunction name="getInfoStruct" access="package" returntype="struct" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	
	<cfreturn variables.Storage[arguments.processkey][arguments.InfoStruct]>
</cffunction>

<cffunction name="setOneField" access="package" returntype="void" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	<cfargument name="InfoField" type="string" required="yes">
	<cfargument name="FieldValue" type="any" required="yes">

	<cfset variables.Storage[arguments.processkey][arguments.InfoStruct][arguments.InfoField] = arguments.FieldValue>
</cffunction>

<cffunction name="getOneField" access="package" returntype="string" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	<cfargument name="InfoField" type="string" required="yes">

	<cfreturn variables.Storage[arguments.processkey][arguments.InfoStruct][arguments.InfoField]>
</cffunction>

<cffunction name="getProcessData" access="public" returntype="struct" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfreturn variables.Storage[arguments.processkey]>
</cffunction>

</cfcomponent>