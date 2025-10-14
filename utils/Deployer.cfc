<cfcomponent output="no">
<cfscript>
public function init(required DataMgr) {

	Variables.DataMgr = Arguments.DataMgr;
	Variables.DataMgr.loadXml(getDbXml(),true,true);

	loadPastDeployments();
	deployNewLengths();

	return This;
}

public function loadPastDeployments() {
	var qDeployments = 0;
	var sDeployment = 0;
	var DeploymentStructKey = "";

	if ( NOT StructKeyExists(Variables,"sPastDeployments") ) {
		Variables.sPastDeployments = {};

		qDeployments = Variables.DataMgr.getRecords(tablename="utilDeployments",fieldlist="ComponentPath,Name,DateRun");

		for ( sDeployment in qDeployments ) {
			DeploymentStructKey = getDeploymentStructKey(Name=sDeployment.Name,ComponentPath=sDeployment.ComponentPath);
			Variables.sPastDeployments[DeploymentStructKey] = sDeployment.DateRun;
		}
	}

}

public function deploy(
	required string Name,
	required string ComponentPath,
	required Component,
	required string MethodName,
	struct Args
) {
	
	if ( NOT isDeployed(ArgumentCollection=Arguments) ) {
		try {
			runDeployment(ArgumentCollection=Arguments);
		} catch ( any e ) {
			rethrow;
		}
	}

	return This;
}

public void function require(
	required Component,
	required string MethodName
) {
	var sComponent = getMetaData(Arguments.Component);

	deploy(
		Name = "#sComponent.FullName#.#Arguments.MethodName#()",
		ComponentPath = "#sComponent.FullName#",
		Component = "#Arguments.Component#",
		MethodName = "#Arguments.MethodName#"
	);

}

public function runDeployment() {
	var TimeMarkBegin = 0;
	var TimeMarkEnd = 0;

	if ( NOT StructKeyExists(Arguments,"Args") ) {
		Arguments.Args = {};
	}

	TimeMarkBegin = getTickCount();
	invoke(Arguments.Component,MethodName,Arguments.Args);
	TimeMarkEnd = getTickCount();
	Arguments.Seconds = GetSecondsDiff(TimeMarkBegin,TimeMarkEnd);
	recordDeployment(ArgumentCollection=Arguments);

}

public boolean function isDeployed(
	required string Name,
	required string ComponentPath
) {
	var sTasks = {};
	var result = false;

	sTasks["Name"] = Arguments.Name;
	sTasks["ComponentPath"] = Arguments.ComponentPath;

	sTasks = Variables.DataMgr.truncate(tablename="utilDeployments",data=sTasks);

	// Look for the run in the local structure
	result = StructKeyExists(Variables.sPastDeployments,getDeploymentStructKey(ArgumentCollection=Arguments));

	// If not found in the local structure, double-check the database
	if ( NOT result ) {
		result = Variables.DataMgr.hasRecords(tablename="utilDeployments",data=sTasks);
	}

	return result;
}

private numeric function GetSecondsDiff(
	required numeric begin,
	required numeric end
) {
	var result = 0;

	if ( Arguments.end GTE Arguments.begin ) {
		result = Int( ( Arguments.end - Arguments.begin ) / 1000 );
	}

	return result;
}

public void function recordDeployment() {
	var DeploymentStructKey = getDeploymentStructKey(ArgumentCollection=Arguments);

	Variables.DataMgr.insertRecord(tablename="utilDeployments",data=Arguments,truncate=true);
	Variables.sPastDeployments[DeploymentStructKey] = now();

}

private string function getDeploymentStructKey(
	required string Name,
	required string ComponentPath
) {
	var sArgs = Variables.DataMgr.truncate(tablename="utilDeployments",data=Arguments);

	return "#sArgs.Name#:::#sArgs.ComponentPath#";
}

public void function deployNewLengths() {
	deploy(Name="deployNewDeploymentNameLength",ComponentPath="com.sebtools.utils.Deployer",Component=This,MethodName="changeLengths");
}
</cfscript>

<cffunction name="changeLengths" access="public" returntype="void" output="no">

	<cfset var qColumns = 0>

	<cfquery name="qColumns" datasource="#Variables.DataMgr.getDatasource()#">
	SELECT	column_name,character_maximum_length
	FROM	information_schema.columns
	WHERE	table_name = 'utilDeployments'
		AND	data_type = 'varchar'
		AND	column_name IN ('Name','ComponentPath','MethodName')
	</cfquery>

	<cfoutput query="qColumns">
		<cfif character_maximum_length LT 255>
			<cfquery datasource="#Variables.DataMgr.getDatasource()#">
			ALTER TABLE	utilDeployments
			ALTER COLUMN #column_name# VARCHAR(255)
			</cfquery>
		</cfif>
	</cfoutput>

</cffunction>

<cffunction name="getDbXml" access="private" returntype="string" output="no" hint="I return the XML for the tables needed for Deployer to work.">

	<cfset var result = "">

	<cfsavecontent variable="result">
	<tables>
		<table name="utilDeployments">
			<field ColumnName="DeploymentID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="Name" CF_DataType="CF_SQL_VARCHAR" Length="255" />
			<field ColumnName="ComponentPath" CF_DataType="CF_SQL_VARCHAR" Length="255" />
			<field ColumnName="MethodName" CF_DataType="CF_SQL_VARCHAR" Length="255" />
			<field ColumnName="DateRun" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
			<field ColumnName="ErrorMessage" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="ErrorDetail" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="Success" CF_DataType="CF_SQL_BIT" />
			<field ColumnName="Seconds" CF_DataType="CF_SQL_BIGINT" />
			<field ColumnName="ReturnVar" CF_DataType="CF_SQL_VARCHAR" Length="250" />
		</table>
	</tables>
	</cfsavecontent>

	<cfreturn result>
</cffunction>

</cfcomponent>
