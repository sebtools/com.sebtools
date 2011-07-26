<cfcomponent displayname="Mailer" hint="I handle sending of email notices. The advantage of using Mailer instead of cfmail is that I can be instantiated with information and then passed as an object to a component that sends email, circumventing the need to pass a bunch of email-related information to each component that send email.">

<cffunction name="init" access="public" returntype="Mailer" output="no" hint="I instantiate and return this object.">
	<cfargument name="MailServer" type="string" required="yes">
	<cfargument name="From" type="string" required="yes">
	<cfargument name="To" type="string" default="">
	<cfargument name="username" type="string" default="">
	<cfargument name="password" type="string" default="">
	
	<cfset variables.MailServer = arguments.MailServer>
	<cfset variables.DefaultFrom = arguments.From>
	<cfset variables.DefaultTo = arguments.To>
	<cfset variables.username = arguments.username>
	<cfset variables.password = arguments.password>
	
	<cfset variables.Notices = StructNew()>
	
	<cfreturn this>
</cffunction>

<cffunction name="addNotice" access="public" returntype="void" output="no" hint="I add a notice to the mailer.">
	<cfargument name="name" type="string" required="yes">
	<cfargument name="Subject" type="string" required="yes">
	<cfargument name="Contents" type="string" required="yes">
	<cfargument name="To" type="string" required="#variables.DefaultTo#">
	<cfargument name="From" type="string" default="#variables.DefaultFrom#">
	<cfargument name="datakeys" type="string">
	<cfargument name="type" type="string" default="">
	<cfargument name="CC" type="string" default="">
	<cfargument name="BCC" type="string" default="">
	
	<cfscript>
	variables.Notices[arguments.name] = StructNew();
	variables.Notices[arguments.name].To = arguments.To;
	variables.Notices[arguments.name].Subject = arguments.Subject;
	variables.Notices[arguments.name].Contents = arguments.Contents;
	variables.Notices[arguments.name].From = arguments.Subject;
	variables.Notices[arguments.name].CC = arguments.CC;
	variables.Notices[arguments.name].BCC = arguments.BCC;
	variables.Notices[arguments.name].type = arguments.type;
	if ( StructKeyExists(arguments,"datakeys") ) {
		variables.Notices[arguments.name].DataKeys = arguments.datakeys;
	} else {
		variables.Notices[arguments.name].DataKeys = "";
	}
	
	</cfscript>
	
</cffunction>

<cffunction name="getDataKeys" access="public" returntype="string" output="no" hint="I get the datakeys for the given email notice. The datakeys are the items that can/should be overridden by incoming data.">
	<cfargument name="name" type="string" required="yes">
	
	<cfset var result = "">
	<cfif StructKeyExists(variables.Notices, arguments.name)>
		<cfset result = variables.Notices[arguments.name].DataKeys>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="runLoadFile" access="public" returntype="void" output="no" hint="I run (include) the given load file, which should be located in the same directory as the Mailer component.">
	<cfargument name="loadfile" type="string" required="yes">
	
	<cfset var Mailer = this>
	<cfinclude template="#arguments.loadfile#">
</cffunction>

<cffunction name="send" access="public" returntype="void" output="no" hint="I send an email message.">
	<cfargument name="To" type="string" required="yes">
	<cfargument name="Subject" type="string" required="yes">
	<cfargument name="Contents" type="string" required="yes">
	<cfargument name="From" type="string" default="#variables.DefaultFrom#">
	<cfargument name="CC" type="string" default="">
	<cfargument name="BCC" type="string" default="">
	<cfargument name="type" type="string" default="text">
	
	<cfmail to="#arguments.To#" from="#arguments.From#" type="#arguments.type#" subject="#arguments.Subject#" cc="#arguments.CC#" bcc="#arguments.BCC#" server="#variables.MailServer#">#arguments.Contents#</cfmail>
</cffunction>

<cffunction name="sendNotice" access="public" returntype="void" output="no" hint="I send set/override any data based on the data given and send the given notice.">
	<cfargument name="name" type="string" required="yes">
	<cfargument name="data" type="struct">
	
	<cfset var key = 0>
	<cfset var thisNotice = StructCopy(variables.Notices[arguments.name])>
	
	<cfif isDefined("arguments.data")>
		<!--- If any data is passed, reset values and modify contents accordingly. --->
		<cfloop collection="#arguments.data#" item="key">
			<!--- If this data key matches a key in the main struct for this notice, replace it --->
			<cfif StructKeyExists(thisNotice, key)>
				<cfset thisNotice[key] = arguments.data[key]>
			</cfif>
			<!--- Modify any parameters in contents for this datakey --->
			<cfset thisNotice.Contents = ReplaceNoCase(thisNotice.Contents, "[#key#]", arguments.data[key], "ALL")>
		</cfloop>
	</cfif>
	
	<cfset send(thisNotice.To,thisNotice.Subject,thisNotice.Contents,thisNotice.From,thisNotice.CC,thisNotice.BCC,thisNotice.type)>

</cffunction>

</cfcomponent>