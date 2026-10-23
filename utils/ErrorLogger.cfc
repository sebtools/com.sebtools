<cfcomponent output="no">
<cfscript>
public any function init(
	required any DataMgr
) {
	Variables.DataMgr = Arguments.DataMgr;
	Variables.tablename = "logErrors";

	Variables.DataMgr.loadXML(LogTableXML(),true,true);

	return This;
}

public function logError(
	required string message,
	string code="",
	string message_extended = ""
) {
	return variables.DataMgr.insertRecord(
		variables.tableName,
		{
			Code = Arguments.code,
			Message = Arguments.message,
			Message_Extended = Arguments.message_extended
		}
	);
}
</cfscript>

<cffunction name="LogTableXML" access="public" returntype="string" output="no">

	<cfset var result = "">

	<cfsavecontent variable="result"><cfoutput>
	<tables>
		<table name="logErrors">
			<field ColumnName="ErrorID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="ErrorDate" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
			<field ColumnName="Code" CF_DataType="CF_SQL_VARCHAR" Length="255" />
			<field ColumnName="Message" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="Message_Extended" CF_DataType="CF_SQL_LONGVARCHAR" />
		</table>
	</tables>
	</cfoutput></cfsavecontent>

	<cfreturn result>
</cffunction>

</cfcomponent>
