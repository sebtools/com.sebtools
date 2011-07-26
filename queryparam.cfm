<cffunction name="queryparam" access="public" returntype="struct" output="no" hint="I run the given SQL.">
	<cfargument name="cfsqltype" type="string" required="no">
	<cfargument name="value" type="any" required="yes">
	<cfargument name="maxLength" type="string" required="no">
	<cfargument name="scale" type="string" default="0">
	<cfargument name="null" type="boolean" default="no">
	<cfargument name="list" type="boolean" default="no">
	<cfargument name="separator" type="string" default=",">
	
	<cfif NOT StructKeyExists(arguments,"cfsqltype")>
		<cfif StructKeyExists(arguments,"CF_DataType")>
			<cfset arguments["cfsqltype"] = arguments["CF_DataType"]>
		<cfelseif StructKeyExists(arguments,"Relation")>
			<cfif StructKeyExists(arguments.Relation,"CF_DataType")>
				<cfset arguments["cfsqltype"] = arguments.Relation["CF_DataType"]>
			<cfelseif StructKeyExists(arguments.Relation,"table") AND StructKeyExists(arguments.Relation,"field")>
				<cfset arguments["cfsqltype"] = getEffectiveDataType(argumentCollection=arguments)>
			</cfif>
		</cfif>
	</cfif>
	
	<cfif isStruct(arguments.value) AND StructKeyExists(arguments.value,"value")>
		<cfset arguments.value = arguments.value.value>
	</cfif>
	
	<cfif NOT isSimpleValue(arguments.value)>
		<cfthrow message="arguments.value must be a simple value" type="DataMgr" errorcode="ValueMustBeSimple">
	</cfif>
	
	<cfif NOT StructKeyExists(arguments,"maxLength")>
		<cfset arguments.maxLength = Len(arguments.value)>
	</cfif>
	
	<cfif StructKeyExists(arguments,"maxLength")>
		<cfset arguments.maxlength = Int(Val(arguments.maxlength))>
		<cfif NOT arguments.maxlength GT 0>
			<cfset arguments.maxlength = Len(arguments.value)>
		</cfif>
		<cfif NOT arguments.maxlength GT 0>
			<cfset arguments.maxlength = 100>
			<cfset arguments.null = "yes">
		</cfif>
	</cfif>
	
	<cfset arguments.scale = Max(int(val(arguments.scale)),2)>
	
	<cfreturn arguments>
</cffunction>