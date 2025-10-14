<!--- 1.2 (Build 17) --->
<!--- Last Updated: 2015-09-03 --->
<!--- Created by Steve Bryant 2007-08-15 --->
<!--- Information: sebtools.com --->
<cfcomponent displayname="Spam Filter" output="false">
<cfset cr = "
">
<cfset variables.ignoreKeysDefaults = ["grecaptcharesponse", "g-recaptcha-response", "h-captcha-response", "email"]>
<cfset variables.ignoreKeys = variables.ignoreKeysDefaults>

<cffunction name="init" access="public" returntype="any" output="no" hint="I instantiate and return this component.">
	<cfargument name="DataMgr" type="any" required="yes">
	<cfargument name="getNewDefs" type="boolean" default="0">
	<cfargument name="Scheduler" type="any" required="false">

	<cfscript>
	var qWords = 0;

	variables.DataMgr = arguments.DataMgr;
	variables.getNewDefs = arguments.getNewDefs;

	variables.datasource = variables.DataMgr.getDatasource();
	variables.DataMgr.loadXML(getDbXml(),true,true);
	if ( StructKeyExists(arguments,"Scheduler") ) {
		variables.Scheduler = arguments.Scheduler;
		loadScheduledTask();
	}

	if ( Variables.getNewDefs AND NOT StructKeyExists(arguments,"Scheduler") ) {
		loadUniversalData();
	}

	// Add Default Words
	if ( Variables.DataMgr.hasRecords("spamWords") ) {
		loadWords(getDefaultSpamWords());
	}

	return This;
	</cfscript>
</cffunction>

<cffunction name="loadScheduledTask" access="public" returntype="void" output="no">
	<cfscript>
	if ( StructKeyExists(Variables,"Scheduler") ) {
		Variables.Scheduler.setTask(
			Name="SpamFilter",
			ComponentPath="com.sebtools.SpamFilter",
			Component="#This#",
			MethodName="loadUniversalData",
			interval="weekly",
			weekdays="Monday",
			Hours="1,2,3"
		)
	}
	</cfscript>
</cffunction>

<cffunction name="filter" access="public" returntype="struct" output="no" hint="I run the filter on the given structure and return it.">
	<cfargument name="data" type="struct" required="yes">
	<cfargument name="maxpoints" type="numeric" default="0">
	<cfscript>
	if ( isSpam(ArgumentCollection=Arguments) ) {
		throw(
			message="This message appears to be spam.",
			detail="If you feel that you have gotten this message in error, pleas change your entry and try again.",
			type="SpamFilter",
			errorcode="Spam"
		);
	}

	return Arguments.data;
	</cfscript>
</cffunction>

<cffunction name="isSpam" access="public" returntype="boolean" output="no" hint="I indicate whether the given structure is spam.">
	<cfargument name="data" type="struct" required="yes">
	<cfargument name="maxpoints" type="numeric" default="0">
	<cfscript>
	var pointlimit = Arguments.maxpoints;
	var pointval = 0;
	var result = false;

	// If we don't have a point limit, set it to the number of fields
	if ( NOT pointlimit ) {
		pointlimit = getPointLimit(Arguments.data,maxpoints);
	}

	// Run that filter!
	pointval = getPoints(Arguments.data,maxpoints);

	if ( pointval GT pointlimit ) {
		result = true;
	}

	return result;
	</cfscript>
</cffunction>

<cffunction name="getPoints" access="public" returntype="numeric" output="no"hint="I return the number of points in the given structure.">
	<cfargument name="data" type="struct" required="yes">
	<cfargument name="maxpoints" type="numeric" default="0">
	<cfscript>
	var langPoints = 0;
	var pointval = 0;
	var qWords = variables.DataMgr.getRecords("spamWords", {orderBy="points DESC"});
	var sWord = 0;
	var qRegExs = variables.DataMgr.getRecords("spamRegExs");
	var sRegEx = 0;
	var field = "";
	var finds = 0;
	var field2 = "";
	var duplist = "";

	for ( field in Arguments.data ) {
		if (
			ArrayFindNoCase(variables.ignoreKeys, field)
			OR
			ListFindNoCase("validate,finger", listFirst(field,"_"))
		) {
			// Ignore
		} else if ( 
			isSimpleValue(arguments.data[field])
			AND
			Len(field)
			AND
			Len(arguments.data[field])
			AND
			field NEQ "Email"
		) {
			for ( sWord in qWords ) {
				// Get the number of times the word appears
				finds = numWordMatches(Arguments.data[field],trim(sWord.Word),Arguments.maxpoints);
				pointval = pointval + (finds * Val(sWord.points));
				if ( maxpoints GT 0 AND pointval GT maxpoints ) {
					return pointval;
				}
			}
			for ( sRegEx in qRegExs ) {
				// Get the number of times the expression is matched
				finds = numRegExMatches(arguments.data[field],trim(sRegEx.RegEx),Val(sRegEx.checkcase),Arguments.maxpoints);
				pointval = pointval + (finds * Val(sRegEx.points));
				if ( maxpoints GT 0 AND sRegEx.pointval GT maxpoints ) {
					return pointval;
				}
			}
			// Points for duplicate field values
			duplist = ListAppend(duplist,field);
			for ( field2 in Arguments.data ) {
				if (
						(field2 NEQ field)
					AND	isSimpleValue(arguments.data[field])
					AND	isSimpleValue(arguments.data[field2])
					AND	(arguments.data[field2] EQ arguments.data[field])
					AND	NOT ListFindNoCase(duplist,field2)
				) {
					pointval = pointval + 1;
					duplist = ListAppend(duplist,field2);
					if ( maxpoints GT 0 AND pointval GT maxpoints ) {
						return pointval;
					}
				}
			}

			// get points for banned foreign languages
			langPoints = getForeignLanguagePoints(arguments.data[field]);
			pointval = pointval + langPoints;

		}
	}

	return pointval;
	</cfscript>
</cffunction>

<cffunction name="getPointsArray" access="public" returntype="array" output="no"hint="I return an array of details about the points in the given structure.">
	<cfargument name="data" type="struct" required="yes">
	<cfscript>
	var pointval = 0;
	var qWords = Variables.DataMgr.getRecords("spamWords", {orderBy="points DESC"});
	var sWord = 0;
	var qRegExs = Variables.DataMgr.getRecords("spamRegExs");
	var sRegEx = 0;
	var field = "";
	var finds = 0;
	var aPoints = [];
	var field2 = "";
	var duplist = "";

	for ( field in Arguments.data ) {
		if (
			isSimpleValue(arguments.data[field])
			AND
			Len(field)
			AND
			Len(arguments.data[field])
			AND
			field NEQ "Email"
		) {
			for ( sWord in qWords ) {
				// Get the number of times the word appears
				finds = numWordMatches(arguments.data[field],trim(sWord.Word));
				if ( finds ) {
					pointval = pointval + (finds * sWord.points);
					ArrayAppend(aPoints,"#(finds * sWord.points)#:#trim(sWord.Word)#");
				}
			}
			for ( sRegEx in qRegExs ) {
				// Get the number of times the expression is matched
				finds = numRegExMatches(arguments.data[field],trim(sRegEx.RegEx),Val(sRegExcheckcase));
				if ( finds ) {
					pointval = pointval + (finds * sRegExpoints);
					ArrayAppend(aPoints,"#(finds * sRegExpoints)#:(#sRegEx.Label#):#trim(sRegEx.Regex)#");
				}
			}
			// Points for duplicate field values
			duplist = ListAppend(duplist,field);
			for ( field2 in Arguments.data ) {
				if (
						(field2 neq field)
					AND	isSimpleValue(arguments.data[field])
					AND	isSimpleValue(arguments.data[field2])
					AND	(arguments.data[field2] eq arguments.data[field])
					AND	NOT ListFindNoCase(duplist,field2)
				) {
					pointval = pointval + 1;
					duplist = ListAppend(duplist,field2);
					ArrayAppend(aPoints,"#(1)#:(duplicate):#field2#:#arguments.data[field2]#");
				}
			}
		}
	}

	return aPoints;
	</cfscript>
</cffunction>

<cffunction name="getRegEx" access="public" returntype="query" output="no" hint="I return the requested regex.">
	<cfargument name="RegExID" type="string" required="yes">

	<cfreturn variables.DataMgr.getRecord("spamRegExs",arguments)>
</cffunction>

<cffunction name="getRegExs" access="public" returntype="query" output="no" hint="I return all of the regexs.">

	<cfreturn variables.DataMgr.getRecords("spamRegExs",arguments)>
</cffunction>

<cffunction name="getWord" access="public" returntype="query" output="no" hint="I return the requested word.">
	<cfargument name="WordID" type="string" required="yes">

	<cfreturn variables.DataMgr.getRecord("spamWords",arguments)>
</cffunction>

<cffunction name="getWords" access="public" returntype="query" output="no" hint="I return all of the words.">

	<cfreturn variables.DataMgr.getRecords("spamWords",arguments)>
</cffunction>

<cffunction name="loadUniversalData" access="public" returntype="void" output="no" hint="I get external spam definitions.">

	<cftry>
		<!--- Do an HTTP call to get a text file with spam words --->
		<cfhttp url="http://www.bryantwebconsulting.com/spamdefs.txt" method="GET" resolveurl="false"></cfhttp>

		<!--- Parse the XML file and load new spam words --->
		<cfset loadWords(CFHTTP.FileContent)>

		<cfcatch>
		</cfcatch>
	</cftry>

	<cftry>
		<!--- Do an HTTP call to get an XML file with spam expressions --->
		<cfhttp url="http://www.bryantwebconsulting.com/spamdefs.xml" method="GET" resolveurl="false"></cfhttp>

		<!--- Parse the XML file and load new spam expressions --->
		<cfset variables.DataMgr.loadXML(CFHTTP.FileContent,true,true)>

		<cfcatch>
		</cfcatch>
	</cftry>

</cffunction>

<cffunction name="loadWords" access="public" returntype="void" output="no"hint="I load the given list of (carriage-return delimited) words to the spam words definitions.">
	<cfargument name="wordlist" type="string" required="yes">

	<cfset var word = "">
	<cfset var data = StructNew()>

	<cfloop list="#arguments.wordlist#" index="word" delimiters="#cr#">
		<cfset data["Word"] = trim(word)>
		<cfset variables.DataMgr.insertRecord("spamWords",data,"skip")>
	</cfloop>

</cffunction>

<cffunction name="removeRegEx" access="public" returntype="void" output="no" hint="I delete the given RegEx.">
	<cfargument name="RegExID" type="string" required="yes">

	<cfset variables.DataMgr.deleteRecord("spamRegExs",arguments)>

</cffunction>

<cffunction name="removeWord" access="public" returntype="void" output="no" hint="I delete the given Word.">
	<cfargument name="WordID" type="string" required="yes">

	<cfset variables.DataMgr.deleteRecord("spamWords",arguments)>

</cffunction>

<cffunction name="saveRegEx" access="public" returntype="string" output="no" hint="I save a RegEx.">
	<cfargument name="RegExID" type="string" required="no">
	<cfargument name="RegEx" type="string" required="no">
	<cfargument name="Label" type="string" required="no">
	<cfargument name="points" type="string" required="no">

	<cfreturn variables.DataMgr.saveRecord("spamRegExs",arguments)>
</cffunction>

<cffunction name="saveWord" access="public" returntype="string" output="no" hint="I save a Word.">
	<cfargument name="WordID" type="string" required="no">
	<cfargument name="Word" type="string" required="no">
	<cfargument name="points" type="string" required="no">

	<cfreturn variables.DataMgr.saveRecord("spamWords",arguments)>
</cffunction>

<cffunction name="numRegExMatches" access="public" returntype="numeric" output="no" hint="I return the number of times the given regular expression is matched in the given string.">
	<cfargument name="string" type="string" require="true">
	<cfargument name="regex" type="string" require="true">
	<cfargument name="checkcase" type="boolean" default="false">

	<cfset var result = 0>
	<cfset var sFind = 0>

	<cfif arguments.checkcase>
		<cfreturn numRegExCaseMatches(arguments.string,arguments.regex)>
	</cfif>

	<cfscript>
	sFind = REFindNoCase(arguments.regex, arguments.string, 1, true);
	while ( sFind.pos[1] GT 0 ) {
		result = result + 1;
		sFind = REFindNoCase(arguments.regex, arguments.string, sFind.pos[1]+sFind.len[1], true );
	}
	</cfscript>

	<cfreturn result>
</cffunction>

<cffunction name="getRegExCaseMatches" access="public" returntype="array" output="no" hint="I return an array of the given regular expression is matches in the given string.">
	<cfargument name="string" type="string" require="true">
	<cfargument name="regex" type="string" require="true">

	<cfset var aResults = ArrayNew(1)>
	<cfset var sFind = REFind(arguments.regex, arguments.string,1,true)>

	<cfscript>
	while ( sFind.pos[1] GT 0 ) {
		ArrayAppend(aResults, Mid(Arguments.string,sFind.pos[1],sFind.len[1]));
		sFind = REFind(arguments.regex, arguments.string, sFind.pos[1]+1,true);
	}
	</cfscript>

	<cfreturn aResults>
</cffunction>

<cffunction name="numRegExCaseMatches" access="public" returntype="numeric" output="no" hint="I return the number of times the given regular expression is matched in the given string.">
	<cfargument name="string" type="string" require="true">
	<cfargument name="regex" type="string" require="true">
	<cfargument name="maxpoints" type="numeric" default="0">

	<cfset var result = 0>
	<cfset var findat = REFind(arguments.regex, arguments.string)>

	<cfscript>
	while ( findat GT 0 ) {
		result = result + 1;
		if ( arguments.maxpoints GT 0 AND result GT arguments.maxpoints ) {
			return result;
		}
		findat = REFind(arguments.regex, arguments.string, findat+1);
	}
	</cfscript>

	<cfreturn result>
</cffunction>

<cffunction name="numWordMatches" access="public" returntype="numeric" output="no" hint="I return the number of times the given word is found in the given string.">
	<cfargument name="string" type="string" require="true">
	<cfargument name="word" type="string" require="true">
	<cfargument name="maxpoints" type="numeric" default="0">

	<cfreturn numRegExMatches(arguments.string,"\b#arguments.word#\b",arguments.maxpoints)>
</cffunction>

<cffunction name="getPointLimit" access="public" returntype="numeric" output="no">
	<cfargument name="struct" type="struct" required="yes">

	<cfset var key = "">
	<cfset var result = 0>

	<cfloop collection="#arguments.struct#" item="key">
		<cfif StructKeyExists(arguments.struct,key) AND isSimpleValue(arguments.struct[key]) AND Len(Trim(arguments.struct[key])) AND key NEQ "Email">
			<cfset result = result + 1>
		</cfif>
	</cfloop>

	<cfreturn result>
</cffunction>

<cffunction name="getForeignLanguagePoints" access="public" returntype="numeric" output="no">
	<cfargument name="string" type="string" require="true">

	<cfset var pointval = 1>
	<cfset var result = 0>

	<!--- Test for Cyrilic --->
	<cfif arguments.string.matches("(.*)[\u0400-\u04FF](.*)")>
		<cfset result = result + pointval>
	</cfif>

	<!--- Test for Kanji --->
	<cfif arguments.string.matches("(.*)[\u4E00-\u9FFF](.*)")>
		<cfset result = result + pointval>
	</cfif>

	<cfreturn result>
</cffunction>

<cffunction name="getDbXml" access="public" returntype="string" output="no" hint="I return the XML for the tables needed for SpamFilter.cfc to work.">

	<cfset var tableXML = "">

	<cfsavecontent variable="tableXML"><cfoutput>
	<tables>
		<table name="spamWords">
			<field ColumnName="WordID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="Word" CF_DataType="CF_SQL_VARCHAR" Length="150" />
			<field ColumnName="points" CF_DataType="CF_SQL_INTEGER" Default="1" />
		</table>
		<table name="spamRegExs">
			<field ColumnName="RegExID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
			<field ColumnName="RegEx" CF_DataType="CF_SQL_VARCHAR" Length="250" />
			<field ColumnName="Label" CF_DataType="CF_SQL_VARCHAR" Length="60" />
			<field ColumnName="points" CF_DataType="CF_SQL_INTEGER" Default="1" />
			<field ColumnName="checkcase" CF_DataType="CF_SQL_BIT" Default="0" />
		</table>
		<data table="spamRegExs" permanentRows="true" checkFields="Label" onexists="update">
			<row Label="Email" points="2" RegEx="^['_a-z0-9-]+(\.['_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*\.(([a-z]{2,3})|(aero|coop|info|museum|name|jobs|travel))$" />
			<row Label="URL" points="2" RegEx="https?://(\w*:\w*@)?[-\w.]+(:\d+)?(/([\w/_.]*(\?\S+)?)?)?" />
			<row Label="URL2" points="2" RegEx="URL=[\w-]+\.+[\w-]{3,}\b" />
			<row Label="Million Dollars" points="3" Regex="\$.*,\d{3},\d{3}(\.d{2})?" />
			<row Label="IP Address" points="3" Regex="\b(((\d{1,2})|(1\d{2})|(2[0-4])|(25[0-5]))\.){3}((\d{1,2})|(1\d{2})|(2[0-4])|(25[0-5]))\b" />
			<row Label="GobbledyGook" points="0" Regex="\b[^\s]*?[bcdfghjklmnpqrstvxwz]{5,}[^\s]*?\b" />
			<row Label="Junk" points="3" Regex="[^a-z\d_\-\.@##\s:;/\+]{5,}" />
			<row Label="Case Changes" points="2" Regex="\b([a-z][A-Z][^ \n\b]*){3,}\b" checkcase="true" />
			<row Label="Words with numbers" points="2" Regex="\b[a-z]+\d+\w+\b" />
		</data>
	</tables>
	</cfoutput></cfsavecontent>

	<cfreturn tableXML>
</cffunction>

<cffunction name="setIgnoreKeys" access="public" returntype="void" output="no" hint="I set struct keys to ignore">
	<cfargument name="keys" type="any" required="yes">
	<cfset var k = duplicate(arguments.keys)>
	<cfset var thisKey = "">
	<cfif isSimpleValue(k)>
		<cfset k = listtoarray(k)>
	</cfif>
	<cfset variables.ignoreKeys = k>
	<cfloop array="#variables.ignoreKeysDefault#" index="thisKey">
		<cfset arrayAppend(variables.ignoreKeys, thisKey)>
	</cfloop>
</cffunction>

<cffunction name="identifySpam" access="public" returntype="struct" output="no" hint="I return spam points score and rules that were triggered.">
	<cfargument name="data" type="struct" required="yes">
	<cfargument name="maxpoints" type="numeric" default="0">

	<cfset var pointlimit = arguments.maxpoints>
	<cfset var result = structNew()>
	<cfset var thisKey = "">

	<!--- If we don't have a point limit, set it to the number of fields --->
	<cfif NOT pointlimit>
		<cfset pointlimit = getPointLimit(arguments.data,maxpoints)>
	</cfif>

	<!--- Run that filter! --->
	<cfset result = getPointsStruct(arguments.data,maxpoints)>

	<!--- Identify ignored fields --->
	<cfset result.ignored = StructNew()>
	<cfloop array="#variables.ignoreKeys#" index="thisKey">
		<cfif StructKeyExists(data, thisKey)>
			<cfset result.ignored[thisKey] = data[thisKey]>
		</cfif>
	</cfloop>

	<cfset result.isSpam = false>
	<cfif result.score GT pointlimit>
		<cfset result.isSpam = true>
	</cfif>

	<cfreturn result>
</cffunction>

<cffunction name="getPointsStruct" access="public" returntype="struct" output="no" hint="I return the number of points in the given structure.">
	<cfargument name="data" type="struct" required="yes">
	<cfargument name="maxpoints" type="numeric" default="0">

	<cfset var result = {score = 0, rules = ArrayNew(1)}>
	<cfset var qWords = variables.DataMgr.getRecords("spamWords", {orderBy="points DESC"})>
	<cfset var qRegExs = variables.DataMgr.getRecords("spamRegExs")>
	<cfset var field = "">
	<cfset var finds = 0>
	<cfset var field2 = "">
	<cfset var duplist = "">

	<cfloop collection="#arguments.data#" item="field">
		<cfif ArrayFindNoCase(variables.ignoreKeys, field) or ListFindNoCase("validate,finger", listFirst(Field,"_"))>
			<!--- Ignore --->
		<cfelseif isSimpleValue(arguments.data[field]) and Len(field) and Len(arguments.data[field]) and field neq "Email">
			<cfloop query="qWords">
				<!--- Get the number of times the word appears --->
				<cfset finds = numWordMatches(arguments.data[field],trim(Word),Arguments.maxpoints)>
				<cfif finds gt 0>
					<cfset result.score = result.score + (finds * Val(points))>
					<cfset ArrayAppend(result.rules, {points=(finds * points), type="word", rule=trim(Word)})>
					<cfif maxpoints GT 0 and result.score gt maxpoints>
						<cfreturn result>
					</cfif>
				</cfif>
			</cfloop>
			<cfloop query="qRegExs">
				<!--- Get the number of times the expression is matched --->
				<cfset finds = numRegExMatches(arguments.data[field],trim(RegEx),Val(checkcase),Arguments.maxpoints)>
				<cfif finds GT 0>
					<cfset result.score = result.score + (finds * Val(points))>
					<cfset ArrayAppend(result.rules, {points=(finds * points), type=Label, rule=trim(Regex)})>
					<cfif maxpoints gt 0 and result.score gt maxpoints>
						<cfreturn result>
					</cfif>
				</cfif>
			</cfloop>
			<!--- Points for duplicate field values --->
			<cfset duplist = ListAppend(duplist,field)>
			<cfloop collection="#arguments.data#" item="field2">
				<cfif
						(field2 neq field)
					and	isSimpleValue(arguments.data[field])
					and	isSimpleValue(arguments.data[field2])
					and	(arguments.data[field2] EQ arguments.data[field])
					and not ListFindNoCase(duplist,field2)
				>
					<cfset result.score = result.score + 1>
					<cfset ArrayAppend(result.rules, {points=1, type="duplicate", rule="#field2#=#arguments.data[field2]#"})>
					<cfset duplist = ListAppend(duplist,field2)>
					<cfif maxpoints GT 0 and result.score gt maxpoints>
						<cfreturn result>
					</cfif>
				</cfif>
			</cfloop>

			<!--- get points for banned foreign languages --->
			<cfset langPoints = getForeignLanguagePoints(arguments.data[field]) />
			<cfif val(langPoints) gt 1>
				<cfset result.score = result.score + langPoints />
				<cfset ArrayAppend(result.rules, {points=langPoints, type="foreign", rule="Cyrilic/Kanji"})>
			</cfif>

		</cfif>
	</cfloop>

	<cfreturn result>
</cffunction>

<cffunction name="getDefaultSpamWords" access="private" returntype="string" output="no">

	<cfset var result = "">
<cfsavecontent variable="result"><cfoutput>-online
4u
adipex
adult book
adult comic
advicer
baccarrat
blackjack
bllogspot
bondage
booker
byob
car-rental-e-site
car-rentals-e-site
carisoprodol
casino
casinos
chatroom
cialis
coolcoolhu
coolhu
credit-card-debt
credit-report-4u
cwas
cyclen
cyclobenzaprine
dating-e-site
day-trading
debt-consolidation
debt-consolidation-consultant
discreetordering
duty-free
dutyfree
equityloans
fioricet
flowers-leading-site
freenet-shopping
freenet
free-site-host.com
gambling-
hair-loss
health-insurancedeals-4u
homeequityloans
homefinance
holdem
holdempoker
holdemsoftware
holdemtexasturbowilson
hotel-dealse-site
hotele-site
hotelse-site
incest
insurance-quotesdeals-4u
insurancedeals-4u
jrcreations
levitra
macinstruct
MILLION UNITED STATES DOLLARS
mortgage-4-u
mortgagequotes
online-gambling
onlinegambling-4u
ottawavalleyag
ownsthis
palm-texas-holdem-game
paxil
penis
pharmacy
phentermine
poker-chip
porn
porno
poze
propecia
pussy
rental-car-e-site
ringtones
roulette
sex
shemale
shoes
slot-machine
texas-holdem
thorcarlson
top-site
top-e-site
tramadol
trim-spa
ultram
valeofglamorganconservatives
viagra
vioxx
xanax
zolus</cfoutput></cfsavecontent>
	<cfreturn result>
</cffunction>

</cfcomponent> 
