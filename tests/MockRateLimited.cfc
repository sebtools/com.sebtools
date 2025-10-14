<cfcomponent displayname="Rate Limited">

<cffunction name="init" access="public" returntype="any" output="no">

	<cfset This.Args = Arguments>
	<cfset This.DateLoaded = now()>

	<cfset Variables.RateLimiter = CreateObject("component","com.sebtools.RateLimiter").init(
		"mock"
	)>

	<cfreturn This>
</cffunction>

</cfcomponent>
