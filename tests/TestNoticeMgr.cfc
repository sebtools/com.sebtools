<cfcomponent displayname="NoticeMgr" extends="RecordsTester" output="no"><cfscript>
public void function setUp() {
	Variables.DataMgr = CreateObject("component","DataMgr").init("TestSQL");
	var sConfig = StructFromArgs(datasource="#Variables.DataMgr.getDatasource()#");
	Variables.ServiceFactory = CreateObject("component","_framework.ServiceFactory").init(config=sConfig);
	Variables.ServiceFactory.setScope(Variables);
	loadServices();
	Variables.NoticeMgr = CreateObject("component","com.sebtools.NoticeMgr").init(DataMgr=Variables.DataMgr, Mailer=Variables.Mailer);
}

/**
* One time notices should only be sent one time.
*/
public void function shouldSendOneTimeNoticeOneTime() mxunit:transaction="rollback" {
	var NoticeName = "Test #getTickCount()#";
	var sNotice = {
		Component: "does.not.exist",
		Name: NoticeName,
		Subject: "Test #getTickCount()#",
		Text: "Testing 123",
		OneTimeList: "OrgID"
	};
	var OrgID = 999999;
	Variables.NoticeMgr.addNotice(argumentCollection=sNotice);
	var OneTimeNoticeID = Variables.NoticeMgr.sendNotice(Name=NoticeName, data={OrgID: OrgID}).OneTimeNoticeID;
	assertTrue(OneTimeNoticeID, "One-time notice was not sent.");
	OneTimeNoticeID = Variables.NoticeMgr.sendNotice(Name=NoticeName, data={OrgID: OrgID}).OneTimeNoticeID;
	assertFalse(OneTimeNoticeID, "Duplicate notice was sent.");
}
/**
* Any notice should be able to send with manual OneTimeList unless the notice has its own OneTimeList.
*/
public void function shouldSendManualOneTimeNotice() mxunit:transaction="rollback" {
	var NoticeName = "Test #getTickCount()#";
	var sNotice = {
		Component: "does.not.exist",
		Name: NoticeName,
		Subject: "Test #getTickCount()#",
		Text: "Testing 123"
	};
	var OrgID = 999999;
	Variables.NoticeMgr.addNotice(argumentCollection=sNotice);
	var OneTimeNoticeID = Variables.NoticeMgr.sendNotice(Name=NoticeName, data={OrgID: OrgID}, OneTimeList="OrgID").OneTimeNoticeID;
	assertTrue(OneTimeNoticeID, "One-time notice was not sent.");
	OneTimeNoticeID = Variables.NoticeMgr.sendNotice(Name=NoticeName, data={OrgID: OrgID}, OneTimeList="OrgID").OneTimeNoticeID;
	assertFalse(OneTimeNoticeID, "Duplicate notice was sent.");
	
	NoticeName = "Test OneTime #getTickCount()#";
	sNotice = {
		Component: "does.not.exist",
		Name: NoticeName,
		Subject: "Test #getTickCount()#",
		Text: "Testing 123",
		OneTimeList: "OrgID"
	};
	Variables.NoticeMgr.addNotice(argumentCollection=sNotice);

	var ErrorMsg = "";
	try {
		Variables.NoticeMgr.sendNotice(Name=NoticeName, data={OrgID: OrgID}, OneTimeList="OrgID");
	} catch (any e) {
		ErrorMsg = e.message;
	}

	assertEquals("You may not pass a OneTimeList to sendNotice for notices that have their own value (#NoticeName#).", ErrorMsg, "No error thrown for manual OneTimeList");
}

private void function loadServices() {
	Variables.ServiceFactory.loadXml(getXML());
	Variables.ServiceFactory.getAllServices();
}
</cfscript>

<cffunction name="getXML" access="private" returntype="string" output="no">
	<cfset var TestXML = "">
	
	<cfsavecontent variable="TestXML"><cfoutput><site>
		<components>
			<component name="DataMgr" path="com.sebtools.DataMgr">
				<argument name="datasource" arg="datasource" />
			</component>
			<component name="Mailer" path="com.sebtools.Mailer">
				<argument name="DataMgr" ifmissing="skiparg" />
				<argument name="MailServer" value="mail.test.com" />
				<argument name="From" value="from@example.com" />
				<argument name="Mode" value="Sim" />
			</component>
		</components>
	</site></cfoutput></cfsavecontent>
	
	<cfreturn TestXML>
</cffunction>

</cfcomponent>


