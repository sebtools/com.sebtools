<cfcomponent name="ReSpooler" displayname="ReSpooler" hint="I respool undelivered mail.">

<cffunction name="init" access="public" returntype="any" output="no" hint="I initialize and return this component.">
	<cfargument name="DataMgr" type="any" required="false" hint="DataMgr component (see sebtools.com).">
	<cfargument name="retries" type="numeric" default="3" hint="number of retries for an email before it is declared a permanent problem.">
	<cfargument name="daysold" type="numeric" default="3" hint="The number of days an email can exist before it is declared a permanent problem (to keep from resending outdated email).">
	<cfargument name="Mailer" type="any" required="false" hint="Mail component (see sebtools.com)">
	<cfargument name="ErrEmail" type="string" required="false" hint="The email address to send alerts to if any problem email messages are found.">
	
	<cfscript>
	var dirdelim = CreateObject("java", "java.io.File").separator;
	
	variables.DataMgr = arguments.DataMgr;
	variables.DataMgr.loadXml(getDbXml(),true,true);
	variables.datasource = variables.DataMgr.getDatasource();
	
	//Copying args to component-level variables
	variables.retries = arguments.retries;
	variables.daysold = arguments.daysold;
	
	//Mail Folders
	variables.MailDir = ListAppend(Server.ColdFusion.rootdir,"Mail",dirdelim);
	variables.SpoolDir = ListAppend(variables.MailDir,"Spool",dirdelim) & dirdelim;
	variables.UndelivrDir = ListAppend(variables.MailDir,"Undelivr",dirdelim) & dirdelim;
	variables.ErrorDir = ListAppend(variables.MailDir,"Error",dirdelim) & dirdelim;
	
	//Alert Mailing Information (send email alert only if Mailer is provided)
	if ( StructKeyExists(arguments,"Mailer") ) {
		variables.Mailer = arguments.Mailer;
	}
	if ( StructKeyExists(arguments,"ErrEmail") ) {
		variables.ErrEmail = arguments.ErrEmail;
	}
	</cfscript>
	
	<!--- Make sure error folder exists --->
	<cfif NOT DirectoryExists(variables.ErrorDir)>
		<cfdirectory action="CREATE" directory="#variables.ErrorDir#">
	</cfif>
	
	<!--- Try to get the name of this machine (helps for admins with multiple machines) --->
	<cftry>
		<cfregistry action="GET"
			branch="HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\ComputerName\ActiveComputerName"
			entry="ComputerName"
			variable="variables.MachineName"
			type="String">
		<cfcatch type="Any">
			<cfset variables.MachineName = "" >
		</cfcatch>
	</cftry>
	
	<cfreturn this>
</cffunction>

<cffunction name="checkUndelivr" access="public" returntype="void" output="no" hint="I check and respool undelivered email.">
	
	<cfset var qUndelivr = getUndelivr()>
	<cfset var FileData = StructNew()>
	<cfset var qCount = 0>
	
	<cfloop query="qUndelivr">
		<!--- See if this file is too old. --->
		<cfif DateDiff("d",DateLastModified,now()) gt variables.daysold>
			<cfset errMail(name)>
		<cfelse>
			<!--- Make sure an entry exists --->
			<cfset FileData = StructNew()>
			<cfset FileData["name"] = name>
			<cfset FileData["size"] = size>
			<cfset FileData["DateFound"] = now()>
			<cfset FileData["Machine"] = variables.MachineName>
			<cfset variables.DataMgr.insertRecord("undlvrFiles",FileData,"insert")>
			
			<!--- See if this file has been retried to many times. --->
			<cfquery name="qCount" datasource="#variables.datasource#">
			SELECT	Count(*) AS FileCount
			FROM	undlvrFiles
			WHERE	name = <cfqueryparam value="#name#" cfsqltype="CF_SQL_VARCHAR">
				AND	size = <cfqueryparam value="#size#" cfsqltype="CF_SQL_INTEGER">
				AND	Machine = <cfqueryparam value="#variables.MachineName#" cfsqltype="CF_SQL_VARCHAR" null="#IIf(Len(Trim(variables.MachineName)),DE('no'),DE('yes'))#">
			</cfquery>
			<cfif qCount.FileCount gt variables.retries>
				<cfset errMail(name)>
			<cfelseif FileExists("#variables.UndelivrDir##name#")>
				<cffile action="MOVE" source="#variables.UndelivrDir##name#" destination="#variables.SpoolDir##name#">
			</cfif>
		</cfif>
	</cfloop>
	
</cffunction>

<cffunction name="errMail" access="public" returntype="void" output="no" hint="I move an email to the error folder.">
	<cfargument name="FileName" type="string" required="true">
	 
	<cfset var ErrData = StructNew()>
	 
	 <!--- Move file to error folder --->
	<cffile action="MOVE" source="#variables.UndelivrDir##arguments.FileName#" destination="#variables.ErrorDir##arguments.FileName#">
	
	<cfset ErrData["name"] = arguments.FileName>
	<cfset ErrData["DateErrored"] = now()>
	<cfset ErrData["Machine"] = variables.MachineName>
	
	<cfset variables.DataMgr.insertRecord("undlvrErrs",ErrData)>
	
</cffunction>

<cffunction name="getEmail" access="public" returntype="string" output="no" hint="I return the given email.">
	<cfargument name="FileName" type="string" required="true">
	<cfargument name="type" type="string" default="Error">
	
	<cfset var result = "">
	
	<cfif FileExists("#variables.ErrorDir##arguments.FileName#")>
		<cffile action="read" file="#variables.ErrorDir##arguments.FileName#" variable="result">
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="getErrMessages" access="public" returntype="query" output="no" hint="I get the undelivered email.">
	<cfset var qErrMessages = 0>
	
	<cfdirectory action="LIST" directory="#variables.ErrorDir#" name="qErrMessages">
	
	<cfreturn qErrMessages>
</cffunction>

<cffunction name="getMailDir" access="public" returntype="string" output="no" hint="I return the mail folder.">
	
	<cfreturn variables.MailDir>
</cffunction>


<cffunction name="getMailInfo" access="public" returntype="struct" output="no" hint="I parse a mail file for info.">
	<cfargument name="fileName" type="string" required="true">
	<cfargument name="type" type="string" default="Error">
	
	<cfset var result = structNew()>
	<cfset var mail = "">
	<cfset var pos = "">
	<cfset var line = "">
	
	<cfset result.sender = "">
	<cfset result.to = "">
	<cfset result.subject = "">
	
	<!--- read in file --->
	<cfset mail = getEmail(arguments.FileName,arguments.type)>
		
	<!--- start parsing --->
	<cfset pos = reFindNoCase("(?m)^from: (.*?)\n", mail, 1, 1)>
	<cfif pos.len[1] is not 0>
		<cfset result.sender = trim(mid(mail, pos.pos[2], pos.len[2]))>
	</cfif>
	<cfset pos = reFindNoCase("(?m)^to: (.*?)\n", mail, 1, 1)>
	<cfif pos.len[1] is not 0>
		<cfset result.to = trim(mid(mail, pos.pos[2], pos.len[2]))>
	</cfif>
	<cfset pos = reFindNoCase("(?m)^subject: (.*?)\n", mail, 1, 1)>
	<cfif pos.len[1] is not 0>
		<cfset result.subject = trim(mid(mail, pos.pos[2], pos.len[2]))>
	</cfif>

	<!--- body is all lines with body: in front. So we will do it the slow way. --->
	<cfset result.body = "">
	<cfloop index="line" list="#mail#" delimiters="#chr(10)##chr(13)#">
		<cfif findNoCase("body: ", line) is 1>
			<cfset result.body = result.body & replaceNoCase(line, "body: ", "") & chr(10)>
		</cfif>
	</cfloop>
	
	<cfset result.sent = getFileLastModified("#variables.ErrorDir#/#arguments.filename#")>
	
	<cfreturn result>
</cffunction>


<cffunction name="getUndelivr" access="public" returntype="query" output="no" hint="I get the undelivered email.">
	<cfset var qUndelivr = 0>
	
	<cfdirectory action="LIST" directory="#variables.UndelivrDir#" name="qUndelivr">
	
	<cfreturn qUndelivr>
</cffunction>

<cffunction name="moveMessages" access="public" returntype="void" output="no" hint="I remove the given errored messages.">
	 	<cfargument name="Messages" type="string" required="true">
	 	
	 	<cfset var FileName = "">
	 	
	 	<cfloop list="#arguments.Messages#" index="FileName">
			<cfif FileExists("#variables.ErrorDir##FileName#")>
				<cftry>
					<cffile action="MOVE" source="#variables.ErrorDir##FileName#" destination="#variables.SpoolDir##FileName#">
					<cfcatch>
					</cfcatch>
				</cftry>
			</cfif>
		</cfloop>
	 	
</cffunction>

<cffunction name="removeMessages" access="public" returntype="void" output="no" hint="I remove the given errored messages.">
	 	<cfargument name="Messages" type="string" required="true">
	 	
	 	<cfset var FileName = "">
	 	
	 	<cfloop list="#arguments.Messages#" index="FileName">
			<cfif FileExists("#variables.ErrorDir##FileName#")>
				<cftry>
					<cffile action="delete" file="#variables.ErrorDir##FileName#">
					<cfcatch>
					</cfcatch>
				</cftry>
			</cfif>
		</cfloop>
	 	
</cffunction>

<cffunction name="runTask" access="public" returntype="void" output="no" hint="I run the scheduled task for ReSpooler.">
	<cfargument name="url" type="string" required="yes">
	
	<cfset checkUndelivr()>
	<cfset sendAlert(arguments.url)>
	
</cffunction>

<cffunction name="sendAlert" access="public" returntype="void" output="no" hint="I alert the given email address of any emails moved the error folder.">
	<cfargument name="url" type="string" required="yes">
	
	<cfset var qNewErrors = 0>
	<cfset var Subject = "Problems resending email messages">
	<cfset var Contents = "ReSpooler was unable to send one or more messages. Please check in the ColdFusion Administrator or #variables.ErrorDir# to find those messages.">
	<cfset var MailInfo = 0>
	<cfset var errCount = 0>
	
	<cfif Len(variables.MachineName)>
		<cfset Subject = "#Subject# on #variables.MachineName#">
	</cfif>
	<cfset Subject = "#Subject#.">
	
	<cfquery name="qNewErrors" datasource="#variables.datasource#">
	SELECT	name
	FROM	undlvrErrs
	WHERE	DateErrored >= #CreateODBCDate(now())#
		AND	Machine <cfif Len(Trim(variables.MachineName))>= <cfqueryparam value="#variables.MachineName#" cfsqltype="CF_SQL_VARCHAR"><cfelse>IS NULL</cfif>
	</cfquery>
	
	<cfsavecontent variable="Contents">
	<cfoutput>
	<p>#Contents#</p>
	<cfloop query="qNewErrors"><cfset MailInfo = getMailInfo(name)><cfif Len(MailInfo.Sender) OR Len(MailInfo.To)><cfset errCount = errCount + 1>
	<hr>
	<p>
		Date/Time: #DateFormat(MailInfo.sent,"m/dd/yyyy")#<br>
		From: #MailInfo.Sender#<br>
		To: #MailInfo.To#<br>
		Subject: #MailInfo.Subject#<br>
	</p>
	<p>
		<a href="#arguments.url#?message=#name#&action=view">view</a> &nbsp;&nbsp;
		<a href="#arguments.url#?message=#name#&action=delete">delete</a> &nbsp;&nbsp;
		<a href="#arguments.url#?message=#name#&action=respool">respool</a><br>
	</p>
	</cfif></cfloop>
	</cfoutput>
	</cfsavecontent>
	
	<cfif errCount AND StructKeyExists(variables,"Mailer")>
		<cfinvoke component="#variables.Mailer#" method="send">
			<cfif StructKeyExists(variables,"ErrEmail")>
				<cfinvokeargument name="To" value="#variables.ErrEmail#">
			</cfif>
			<cfinvokeargument name="Subject" value="#Subject#">
			<cfinvokeargument name="html" value="#Contents#">
		</cfinvoke>
	</cfif>
	
</cffunction>

<!--- Jesse Houwing (j.houwing@student.utwente.nl)  --->
<cffunction name="getFileLastModified" access="private" returntype="date" output="no">
	<cfargument name="FileName" type="string" required="yes">
	<cfscript>
	var _File = CreateObject("java","java.io.File");
	// Calculate adjustments fot timezone and daylightsavindtime
	var _Offset = ((GetTimeZoneInfo().utcHourOffset)+1)*-3600;
	_File.init(JavaCast("string", filename));
	</cfscript>
	<!--- Date is returned as number of seconds since 1-1-1970 --->
	<cfreturn DateAdd('s', (Round(_File.lastModified()/1000))+_Offset, CreateDateTime(1970, 1, 1, 0, 0, 0))>
</cffunction>

<cfscript>
/**
 * Returns the date the file was last modified.
 * 
 * @param filename 	 Name of the file. (Required)
 * @return Returns a date. 
 * @author Jesse Houwing (j.houwing@student.utwente.nl) 
 * @version 1, November 15, 2002 
 */
function fileLastModified(filename){
	var _File =  createObject("java","java.io.File");
	// Calculate adjustments fot timezone and daylightsavindtime
	var _Offset = ((GetTimeZoneInfo().utcHourOffset)+1)*-3600;
	_File.init(JavaCast("string", filename));
	// Date is returned as number of seconds since 1-1-1970
	return DateAdd('s', (Round(_File.lastModified()/1000))+_Offset, CreateDateTime(1970, 1, 1, 0, 0, 0));
}
</cfscript>

<cffunction name="getDbXml" access="public" returntype="string" output="no" hint="I return the XML for the tables needed for Searcher to work.">
<cfset var tableXML = "">
<cfsavecontent variable="tableXML">
<tables>
	<table name="undlvrFiles">
		<field ColumnName="name" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="size" CF_DataType="CF_SQL_INTEGER" />
		<field ColumnName="DateFound" CF_DataType="CF_SQL_DATE" />
		<field ColumnName="Machine" CF_DataType="CF_SQL_VARCHAR" Length="180" />
	</table>
	<table name="undlvrErrs">
		<field ColumnName="name" CF_DataType="CF_SQL_VARCHAR" Length="180" />
		<field ColumnName="DateErrored" CF_DataType="CF_SQL_DATE" />
		<field ColumnName="Machine" CF_DataType="CF_SQL_VARCHAR" Length="180" />
	</table>
</tables>
</cfsavecontent>
<cfreturn tableXML>
</cffunction>

</cfcomponent>