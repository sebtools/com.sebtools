<cfcomponent extends="_DataMgr">

<cffunction name="getCollections" access="public" returntype="any">
	<cfargument name="tablename" type="string" required="yes" hint="The table from which to return a record.">
	<cfargument name="data" type="struct" required="no" hint="A structure with the data for the desired record. Each key/value indicates a value for the field matching that key.">
	<cfargument name="orderBy" type="string" default="">
	<cfargument name="maxrows" type="numeric" required="no">
	<cfargument name="fieldlist" type="string" default="" hint="A list of fields to return. If left blank, all fields will be returned.">
	<cfargument name="advsql" type="struct" hint="A structure of sqlarrays for each area of a query (SELECT,FROM,WHERE,ORDER BY).">
	<cfargument name="filters" type="array">
	
	<cfreturn QueryToArray(getRecords(argumentCollection=arguments))>
</cffunction>

<cffunction name="QueryToArray" access="private" returntype="array" output="false" hint="This turns a query into an array of structures.">
	<!--- Define arguments. --->
	<cfargument name="Data" type="query" required="yes" />
	
	<cfscript>
	// Define the local scope.
	var LOCAL = StructNew();
	
	// Get the column names as an array.
	LOCAL.Columns = ListToArray( ARGUMENTS.Data.ColumnList );
	
	// Create an array that will hold the query equivalent.
	LOCAL.QueryArray = ArrayNew( 1 );
	
	// Loop over the query.
	for (LOCAL.RowIndex = 1 ; LOCAL.RowIndex LTE ARGUMENTS.Data.RecordCount ; LOCAL.RowIndex = (LOCAL.RowIndex + 1)){
		
		// Create a row structure.
		LOCAL.Row = StructNew();
		
		// Loop over the columns in this row.
		for (LOCAL.ColumnIndex = 1 ; LOCAL.ColumnIndex LTE ArrayLen( LOCAL.Columns ) ; LOCAL.ColumnIndex = (LOCAL.ColumnIndex + 1)){
		
			// Get a reference to the query column.
			LOCAL.ColumnName = LOCAL.Columns[ LOCAL.ColumnIndex ];
			
			// Store the query cell value into the struct by key.
			LOCAL.Row[ LOCAL.ColumnName ] = ARGUMENTS.Data[ LOCAL.ColumnName ][ LOCAL.RowIndex ];
		
		}
		
		// Add the structure to the query array.
		ArrayAppend( LOCAL.QueryArray, LOCAL.Row );
	
	}
	
	// Return the array equivalent.
	return( LOCAL.QueryArray );
	</cfscript>
</cffunction>

</cfcomponent>