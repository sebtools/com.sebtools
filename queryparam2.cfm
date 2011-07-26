<cffunction name="queryparam" access="public" returntype="struct" output="no" hint="I run the given SQL.">
	<cfargument name="cfsqltype" type="string" required="no">
	<cfargument name="value" type="any" required="yes">
	<cfargument name="maxLength" type="string" required="no">
	<cfargument name="scale" type="string" default="0">
	<cfargument name="null" type="boolean" default="no">
	<cfargument name="list" type="boolean" default="no">
	<cfargument name="separator" type="string" default=",">
	
	<!--- initialize the return value, it needs to be a regular struct --->
	<cfset var sResult = structNew()>
	<cfset var key = "">
	
	<!--- set all arguments into the return struct --->
	<cfloop collection="#arguments#" item="key">
		<cfif StructKeyExists(arguments, key)>
			<cfset sResult[key] = arguments[key]>
		</cfif>
	</cfloop>
	
	<cfif NOT StructKeyExists(sResult,"cfsqltype")>
		<cfif StructKeyExists(sResult,"CF_DataType")>
			<cfset sResult["cfsqltype"] = sResult["CF_DataType"]>
		<cfelseif StructKeyExists(sResult,"Relation")>
			<cfif StructKeyExists(sResult.Relation,"CF_DataType")>
				<cfset sResult["cfsqltype"] = sResult.Relation["CF_DataType"]>
			<cfelseif StructKeyExists(sResult.Relation,"table") AND StructKeyExists(sResult.Relation,"field")>
				<cfset sResult.cfsqltype = getEffectiveDataType(argumentCollection=sResult)>
			</cfif>
		</cfif>
	</cfif>
	
	<cfif isStruct(arguments.value) AND StructKeyExists(arguments.value,"value")>
		<cfset sResult.value = arguments.value.value>
	</cfif>
	
	<cfif NOT isSimpleValue(arguments.value)>
		<cfthrow message="arguments.value must be a simple value" type="DataMgr" errorcode="ValueMustBeSimple">
	</cfif>
	
	<cfif NOT StructKeyExists(sResult,"maxLength")>
		<cfset sResult.maxLength = Len(sResult.value)>
	</cfif>
	
	<cfif StructKeyExists(sResult,"maxLength")>
		<cfset sResult.maxlength = Int(Val(sResult.maxlength))>
		<cfif NOT sResult.maxlength GT 0>
			<cfset sResult.maxlength = Len(sResult.value)>
		</cfif>
		<cfif NOT sResult.maxlength GT 0>
			<cfset sResult.maxlength = 100>
			<cfset sResult.null = "yes">
		</cfif>
	</cfif>
	
	<cfset sResult.scale = Max(int(val(sResult.scale)),2)>
	
	<cfreturn sResult>
</cffunction>
