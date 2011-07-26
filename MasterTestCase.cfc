<cfcomponent displayname="Master Test Case" extends="net.sourceforge.cfunit.framework.TestCase">

<cffunction name="getRandomValue" access="private" returntype="string" output="no">
	<cfargument name="field" type="struct" required="yes">
	
	<cfset var result = "">
	
	<cfswitch expression="#field.datatype#">
	<cfcase value="boolean">
		<cfset result = RandRange(0,1)>
	</cfcase>
	<cfcase value="date">
		<cfset result = DateFormat(DateAdd("d",RandRange(30,1095),now()),"yyyy-mm-dd")>
	</cfcase>
	<cfcase value="text">
		<cfset result = "Test#RandRange(1,10000)#">
	</cfcase>
	</cfswitch>
	
	<cfreturn result>
</cffunction>

<cffunction name="QueryGetRandom" access="private" returntype="any" output="no">
	<cfargument name="query" type="query" required="true">
	<cfargument name="field" type="string" required="true">
	
	<cfset var result = arguments.query[arguments.field][RandRange(1,arguments.query.RecordCount)]>
	
	<cfif isBinary(result)>
		<cfset result = ToBase64(result)>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cfscript>
function StructToQuery(struct){
	var qResult = QueryNew(StructKeyList(arguments.struct));
	var key = "";
	
	queryAddRow(qResult);
	
	for( key in arguments.struct){
		if ( StructKeyExists(arguments.struct,key) ) {
			QuerySetCell(qResult, key, arguments.struct[key]);
		}
	}
	
	return qResult;
}
function queryRowToStruct(query){
	//by default, do this to the first row of the query
	var row = 1;
	//a var for looping
	var ii = 1;
	//the cols to loop over
	var cols = listToArray(query.columnList);
	//the struct to return
	var stReturn = structnew();
	//if there is a second argument, use that for the row number
	if(arrayLen(arguments) GT 1)
		row = arguments[2];
	//loop over the cols and build the struct from the query row	
	for(ii = 1; ii lte arraylen(cols); ii = ii + 1){
		stReturn[cols[ii]] = query[cols[ii]][row];
	}		
	//return the struct
	return stReturn;
}
</cfscript>

</cfcomponent>