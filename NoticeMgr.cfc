<!--- Created by Steve Bryant 2006-12-07 --->
<cfcomponent displayname="Notices Manager" output="no" hint="I manage sending and editing notice email messages.">
<cfscript>
public function init(
	required DataMgr,
	required Mailer,
	Observer
) {
	
	initInternal(ArgumentCollection=Arguments);

	return This;
}

public function initInternal(
	required DataMgr,
	required Mailer,
	Observer
) {

	variables.DataMgr = arguments.DataMgr;
	variables.Mailer = arguments.Mailer;
	This.DataMgr = arguments.DataMgr;
	This.Mailer = arguments.Mailer;
	if ( StructKeyExists(Arguments,"Observer") ) {
		Variables.Observer = Arguments.Observer;
	}

	variables.datasource = variables.DataMgr.getDatasource();

	variables.DataMgr.loadXML(getDbXml(),true,true);
	loadNotices();

	//upgrade();

}
</cfscript>

<cffunction name="addNotice" access="public" returntype="any" output="no" hint="I add the given notice if it doesn't yet exist.">
	<cfargument name="Component" type="string" required="yes" hint="The path to your component (example com.sebtools.NoticeMgr).">
	<cfargument name="Name" type="string" required="yes" hint="The name of this notice (must be unique)">
	<cfargument name="Subject" type="string" required="yes" hint="The subject of the email.">
	<cfargument name="Text" type="string" required="no" hint="The text of the email (for plan-text email).">
	<cfargument name="HTML" type="string" required="no" hint="The HTML for the email (for HTML email)">
	<cfargument name="DataKeys" type="string" required="no" hint="A list of data keys for the component (the values to evaluate from within brackets in the email).">
	<cfargument name="Notes" type="string" required="no" hint="Notes about the Notice.">

	<cfset var qCheckNotice = 0>
	<cfset var sCheckNotice = StructNew()>

	<!---
	If a notice of this name already exists for another component, throw an error (type="NoticeMgr")
	--->
	<cfif Len(variables.datasource)>
		<cfquery name="qCheckNotice" datasource="#variables.datasource#">
		SELECT	NoticeID,Component
		FROM	emlNotices
		WHERE	Name = <cfqueryparam value="#arguments.Name#" cfsqltype="CF_SQL_VARCHAR">
			AND	Component <> <cfqueryparam value="#arguments.Component#" cfsqltype="CF_SQL_VARCHAR">
		</cfquery>
		<cfif qCheckNotice.RecordCount>
			<cfthrow message="A notice of this name is already being used by another component (""#qCheckNotice.Component#"")." type="NoticeMgr" errorcode="NameConflict">
		</cfif>
	</cfif>

	<!---
	Only take action if this notice of this name doesn't already exists for this component.
	(we don't want to update because the admin may have change the notice from the default settings)
	--->
	<cfset sCheckNotice["Name"] = arguments.Name>
	<cfset sCheckNotice["Component"] = arguments.Component>
	<cfset qCheckNotice = variables.DataMgr.getRecords(tablename="emlNotices",data=sCheckNotice,fieldlist="NoticeID,Component,Name,Subject,DataKeys,HTML,Text")>
	<cfif NOT qCheckNotice.RecordCount>
		<!--- Save notice if it exists (which includes updating Mailer with the information --->
		<cfset saveNotice(argumentCollection=arguments)>
	<cfelseif NOT StructKeyExists(variables.Mailer.getNotices(),qCheckNotice.Name)>
		<!--- If it does exist, make sure Mailer has it (don't send it to Mailer again if it doesn't though. --->
		<cfinvoke method="addMailerNotice">
			<cfinvokeargument name="name" value="#qCheckNotice.Name#">
			<cfinvokeargument name="Subject" value="#qCheckNotice.Subject#">
			<cfinvokeargument name="datakeys" value="#qCheckNotice.DataKeys#">
			<cfinvokeargument name="html" value="#qCheckNotice.HTML#">
			<cfinvokeargument name="text" value="#qCheckNotice.Text#">
		</cfinvoke>
	</cfif>

</cffunction>

<cffunction name="changeDataKeys" access="public" returntype="void" output="no" hint="I change the Data Keys for the given notice.">
	<cfargument name="Name" type="string" required="yes" hint="The name of this notice (must be unique)">
	<cfargument name="DataKeys" type="string" required="no" hint="A list of data keys for the component (the values to evaluate from within brackets in the email).">

	<cfset var qCheckNotice = 0>
	<cfset var data = StructNew()>

	<cfset data["Name"] = arguments.Name>
	<cfset qCheckNotice = variables.DataMgr.getRecords(tablename="emlNotices",data=data,fieldlist="NoticeID,Subject,HTML,Text")>

	<cfif qCheckNotice.RecordCount>
		<cfset data = StructNew()>
		<cfset data["NoticeID"] = qCheckNotice.NoticeID>
		<cfset data["DataKeys"] = arguments.DataKeys>
		<cfset variables.DataMgr.updateRecord("emlNotices",data)>
		<cfinvoke method="addMailerNotice">
			<cfinvokeargument name="name" value="#arguments.Name#">
			<cfinvokeargument name="Subject" value="#qCheckNotice.Subject#">
			<cfinvokeargument name="datakeys" value="#arguments.DataKeys#">
			<cfinvokeargument name="html" value="#qCheckNotice.HTML#">
			<cfinvokeargument name="text" value="#qCheckNotice.Text#">
		</cfinvoke>
	<cfelse>
		<cfthrow message="No notice of this name (#arguments.Name#) exists." type="NoticeMgr" errorcode="NoSuchNotice">
	</cfif>

</cffunction>

<cffunction name="getDataMgr" access="public" returntype="any" output="no" hint="I get the DataMgr for this component.">
	<cfreturn variables.DataMgr>
</cffunction>

<cffunction name="getMailer" access="public" returntype="any" output="no" hint="I get the Mailer for this component.">
	<cfreturn variables.Mailer>
</cffunction>

<cffunction name="getMailerData" access="public" returntype="struct" output="no" hint="I get the root data for the Mailer for this component.">
	<cfreturn variables.Mailer.getData()>
</cffunction>

<cffunction name="getNotice" access="public" returntype="query" output="no" hint="I get the requested notice.">
	<cfargument name="NoticeID" type="string" required="no" hint="The database id for this notice.">
	<cfargument name="Name" type="string" required="no" hint="The unique name for this notice.">

	<cfset var reqargs = "NoticeID,Name">
	<cfset var arg = "">
	<cfset var hasArg = false>

	<cfloop index="arg" list="#reqargs#">
		<cfif StructKeyExists(arguments,arg)>
			<cfset hasArg = true>
		</cfif>
	</cfloop>

	<cfif NOT hasArg>
		<cfthrow message="getNotice requires one of the following arguments: #reqargs#" type="NoticeMgr" errorcode="GetNoticeRequiredArgs">
	</cfif>


	<cfreturn variables.DataMgr.getRecord("emlNotices",arguments)>
</cffunction>

<cffunction name="getNotices" access="public" returntype="query" output="no" hint="I get all of the notices.">
	<cfargument name="fieldlist" type="string" default="">

	<cfset Arguments.tablename = "emlNotices">

	<cfreturn variables.DataMgr.getRecords(ArgumentCollection=Arguments)>
</cffunction>

<cffunction name="loadNotices" access="public" returntype="any" output="no">

	<cfset var qNotices = getNotices(fieldlist="Name,Subject,DataKeys,HTML,Text")>

	<cfloop query="qNotices">
		<cfinvoke method="addMailerNotice">
			<cfinvokeargument name="name" value="#Name#">
			<cfinvokeargument name="Subject" value="#Subject#">
			<cfinvokeargument name="datakeys" value="#DataKeys#">
			<cfinvokeargument name="html" value="#HTML#">
			<cfinvokeargument name="text" value="#Text#">
		</cfinvoke>
	</cfloop>

</cffunction>

<cffunction name="addMailerNotice" access="private" returntype="void" output="no" hint="I add a notice to the mailer.">
	<cfset Variables.Mailer.addNotice(ArgumentCollection=Arguments)>
</cffunction>

<cffunction name="removeNotice" access="public" returntype="void" output="no" hint="I remove a notice.">
	<cfargument name="name" type="string" required="yes">

	<cfset var qNotice = getNotice(Name=arguments.Name)>
	<cfset var data = StructNew()>

	<cfif qNotice.RecordCount>
		<cfset data["NoticeID"] = qNotice.NoticeID>
		<cfset variables.DataMgr.deleteRecord("emlNotices",data)>
	</cfif>

	<cfset variables.Mailer.removeNotice(arguments.Name)>

</cffunction>

<cfscript>
/**
* @hint I save a notice.
* @Name The unique name for this notice.
* @Component The path to your component (example com.sebtools.NoticeMgr).
* @Subject The subject of the email.
* @Text The text of the email (for plan-text email).
* @HTML The HTML for the email (for HTML email).
* @DataKeys A list of data keys for the component (the values to evaluate from within brackets in the email).
* @Notes Notes about the Notice.
* @OneTimeList A list of data keys for which the notice should only be sent one time. 
*/
public string function saveNotice(
	required string Name,
	string Component,
	required string Subject,
	string Text,
	string HTML,
	string DataKeys,
	string Notes,
	string OneTimeList=""
) {
	var result = 0;
	var qNotice = getNotice(Name=arguments.Name);
	
	// Actions to perform if this is an existing notice
	if ( qNotice.RecordCount ) {
		// Name drives the id here, not vice-versa
		arguments["NoticeID"] = qNotice.NoticeID;

		// TODO: Make sure Component and Name haven't changed if this is an existing notice
		if ( StructKeyExists(arguments, "Component") AND arguments.Component neq qNotice.Component ) {
			throw(message="You cannot change the component with which a notice is associated.", type="NoticeMgr", errorcode="ChangeComponent");
		}
	}

	// Make sure notice has something in it
	if (
		NOT
		(
				( StructKeyExists(arguments, "html") AND Len(arguments.html) )
			OR	( StructKeyExists(arguments, "text") AND Len(arguments.text) )
		)
	) {
		throw(message="If Contents argument is not provided than either html or text arguments must be.", type="Mailer", errorcode="ContentsRequired");
	}
	
	// Save notice record
	result = variables.DataMgr.saveRecord("emlNotices", arguments);

	// get notice record
	qNotice = getNotice(Name=arguments.Name);

	// Add/save notice to mailer
	if ( Len(qNotice.HTML) OR Len(qNotice.Text) ) {
		addMailerNotice(name=qNotice.Name, Subject=qNotice.Subject, datakeys=qNotice.DataKeys, html=qNotice.HTML,text=qNotice.Text);
	}
}

/**
* @hint I send set/override any data based on the data given and send the given notice.
* @Name The name of the notice you want to send.
* @data The data you want to use for this email message.
* @OneTimeList An optional list of data keys for which the notice should only be sent one time.
*/
public struct function sendNotice(required string name, struct data, string OneTimeList) {
	var OneTimeNoticeID = 0;
	validateSendNotice(sArgs=arguments);
	// validateSendNotice will set arguments.OneTimeList to either the passed value or the notice record value if valid
	if ( StructKeyExists(arguments, "OneTimeList") ) {
		var sSendOneTime = getSendOneTime(argumentCollection=arguments);
		if ( sSendOneTime.doSend ) {
			OneTimeNoticeID = logOneTimeNotice(arguments.name, sSendOneTime.ArgsHash);
		} else {
			return {OneTimeNoticeID: OneTimeNoticeID};
		}
	}

	if ( StructKeyExists(Variables, "Observer") ) {
		Variables.Observer.announceEvent(EventName="NoticeMgr:sendNotice", Args=Arguments);
	}

	var sReturn = variables.Mailer.sendNotice(argumentCollection=arguments);
	sReturn.OneTimeNoticeID = OneTimeNoticeID;
	return sReturn;
}

private struct function getSendOneTime(required string name, required struct data, required string OneTimeList) {
	// Make sure this isn't a one-time notice already sent
	var sData = arguments.data;
	var sOneTime = {};
	arguments.OneTimeList.listEach(function(arg) {
		sOneTime[arg] = sData[arg];
	});
	var sOneTimeSorted = sOneTime.toSorted(function(value1, value2, key1, key2) {
		return compareNoCase(key1, key2);
	});
	var argsHash = hash(serializeJSON(sOneTimeSorted));
	var sentNotice = variables.DataMgr.getRecords("emlOneTimeNotices", {Name: arguments.Name, ArgsHash: argsHash});

	return {
		doSend: booleanFormat(NOT sentNotice.RecordCount),
		ArgsHash: argsHash
	};
}

public numeric function logOneTimeNotice(required string Name, required string ArgsHash) {
	return variables.DataMgr.saveRecord("emlOneTimeNotices", {Name: arguments.Name, ArgsHash: arguments.ArgsHash});
}

private void function validateOneTimeList(required string OneTimeList, required struct data) {
	if ( Len(arguments.OneTimeList) ) {
		if ( StructCount(Arguments.data) ) {
			var sArgs = arguments.data;
			arguments.OneTimeList.listEach(function(arg) {
				if ( NOT StructKeyExists(sArgs, arg) ) {
					throw(type="NoticeMgr", message="The OneTimeList value contained #arg#, but #arg# was not passed in as a data key.");
				}
			});
		}
	}
}

private void function validateSendNotice(required struct sArgs) {
	var args = arguments.sArgs;
	var qNotice = getNotice(Name=args.Name, fieldlist="OneTimeList");
	if (StructKeyExists(args, "OneTimeList")) {
		// Passing a OneTimeList is not allowed if the notice already has its own.
		if ( Len(qNotice.OneTimeList) ) {
			throw(type="NoticeMgr", message="You may not pass a OneTimeList to sendNotice for notices that have their own value (#args.Name#).");
		}
	}
	if ( StructKeyExists(args, "OneTimeList") OR Len(qNotice.OneTimeList) ) {
		var listToValidate = Len(qNotice.OneTimeList) ? qNotice.OneTimeList : args.OneTimeList;
		validateOneTimeList(listToValidate, args.data);
		args.OneTimeList = listToValidate;
	}
}
</cfscript>

<cffunction name="upgrade" access="private" returntype="any" output="no">

	<cfset var dbtables = variables.DataMgr.getDatabaseTables()>
	<cfset var qOldRecords = 0>
	<cfset var qNewRecords = getNotices()>

	<!---
	Look for mainResponses table and copy all responses to emlNotices.
	Then ditch mainResponses.
	--->
	<cfif Len(variables.datasource) AND ListFindNoCase(dbtables,"mainResponses")>
		<cfquery datasource="#variables.datasource#">
		INSERT INTO emlNotices (
				Component,
				Name,
				Subject,
				Text,
				HTML,
				DataKeys
		)
		SELECT	Component,
				Response_Title,
				Response_Subject,
				Response_Text,
				NULL,
				Data_Keys
		FROM	mainResponses
		WHERE	NOT EXISTS (
					SELECT	NoticeID
					FROM	emlNotices
					WHERE	Component = mainResponses.Component
						AND	Name = mainResponses.Response_Title
				)
		</cfquery>
	</cfif>

</cffunction>

<cffunction name="getDbXml" access="private" returntype="string" output="no" hint="I return the XML for the tables needed for Searcher to work.">
	<cfset var tableXML = "">

	<cfsavecontent variable="tableXML">
	<tables>
		<table name="emlNotices">
			<field ColumnName="NoticeID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="Component" CF_DataType="CF_SQL_VARCHAR" Length="50" />
			<field ColumnName="Name" CF_DataType="CF_SQL_VARCHAR" Length="50" />
			<field ColumnName="Subject" CF_DataType="CF_SQL_VARCHAR" Length="100" />
			<field ColumnName="Text" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="HTML" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="DataKeys" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="Notes" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="OneTimeList" CF_DataType="CF_SQL_LONGVARCHAR" />
		</table>
		<table name="emlOneTimeNotices">
			<field ColumnName="OneTimeNoticeID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="Name" CF_DataType="CF_SQL_VARCHAR" Length="50" />
			<field ColumnName="ArgsHash" CF_DataType="CF_SQL_LONGVARCHAR" />
			<field ColumnName="DateSent" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
		</table>
	</tables>
	</cfsavecontent>

	<cfreturn tableXML>
</cffunction>

</cfcomponent>
