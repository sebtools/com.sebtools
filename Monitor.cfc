<cfcomponent display="Monitor" hint="I watch and track server performance. I am intended to be used in conjunction with load-testing to help identify bottle-necks.">

<cffunction name="init" access="public" returntype="Monitor" output="no">
	<cfargument name="datasource" type="string" required="yes">
	
	<cfscript>
	variables.datumlist = "AvgDBTime,AvgQueueTime,AvgReqTime,BytesIn,BytesOut,CachePops,DBHits,PageHits,ReqQueued,ReqRunning,ReqTimedOut";
	variables.datasource = arguments.datasource;
	variables.Baseline = StructNew();
	variables.AlertLevels_Above = StructNew();
	variables.AlertLevels_Below = StructNew();
	</cfscript>
	
	<cfreturn this>
</cffunction>

<cffunction name="getBaseline" access="public" returntype="struct" output="no" hint="I get the metric data baseline.">
	<cfreturn variables.Baseline>
</cffunction>

<cffunction name="getReports" access="public" returntype="query" output="no" hint="I get performance data.">

	<cfset qMetricData = 0>
	
	<cfquery name="qMetricData" datasource="#variables.datasource#">
	SELECT		*
	FROM		devMetricData
	ORDER BY	MetricsDateTime
	</cfquery>

	<cfreturn qMetricData>
</cffunction>

<cffunction name="setAlertValue" access="public" returntype="void" output="no" hint="I set the rules for when alerts should be sent.">
	<cfargument name="metric" type="string" required="yes">
	<cfargument name="abovebelow" type="string" required="yes">
	<cfargument name="limit" type="numeric" required="yes">
	
	<cfif arguments.abovebelow eq "below">
		<cfset variables.AlertLevels_Below[arguments.metric] = arguments.limit>
	<cfelse>
		<cfset variables.AlertLevels_Above[arguments.metric] = arguments.limit>
	</cfif>
	
</cffunction>

<cffunction name="setBaseline" access="public" returntype="void" output="no" hint="I set the performance baseline for comparison.">

	<cfset var MetricData = GetMetricData('PERF_MONITOR')>
	
	<cfset variables.Baseline = StructCopy(GetMetricData('PERF_MONITOR'))>
	
	<!--- <cfloop index="col" list="#variables.datumlist#">
		<cfset variables.Baseline[col] = MetricData[col]>
	</cfloop> --->
	
</cffunction>

<cffunction name="setReading" access="public" returntype="void" output="no" hint="I make any entry for current performance data.">

	<cfset var MetricData = GetMetricData('PERF_MONITOR')>
	
	<!--- Generate any alerts --->
	
	<!--- Add reading --->
	<cfquery datasource="#variables.datasource#">
	INSERT INTO devMetricData (
		MetricsDateTime,
		AvgDBTime,
		AvgQueueTime,
		AvgReqTime,
		BytesIn,
		BytesOut,
		CachePops,
		DBHits,
		PageHits,
		ReqQueued,
		ReqRunning,
		ReqTimedOut
	) VALUES (
		#CreateODBCDateTime(now())#,
		#MetricData.AvgDBTime#,
		#MetricData.AvgQueueTime#,
		#MetricData.AvgReqTime#,
		#MetricData.BytesIn#,
		#MetricData.BytesOut#,
		#MetricData.CachePops#,
		#MetricData.DBHits#,
		#MetricData.PageHits#,
		#MetricData.ReqQueued#,
		#MetricData.ReqRunning#,
		#MetricData.ReqTimedOut#
	)
	</cfquery>
</cffunction>

<cffunction name="install" access="public" returntype="void" output="no" hint="I install the Monitor component (by creating the required table).">
<cfquery datasource="#variables.datasource#">
CREATE TABLE devMetricData (
	[Monitor_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[MetricsDateTime] [smalldatetime] NULL ,
	[AvgDBTime] [int] NULL ,
	[AvgQueueTime] [int] NULL ,
	[AvgReqTime] [int] NULL ,
	[BytesIn] [bigint] NULL ,
	[BytesOut] [bigint] NULL ,
	[CachePops] [int] NULL ,
	[DBHits] [int] NULL ,
	[PageHits] [int] NULL ,
	[ReqQueued] [int] NULL ,
	[ReqRunning] [int] NULL ,
	[ReqTimedOut] [int] NULL ,
	CONSTRAINT PK_devMetricData PRIMARY KEY  CLUSTERED 
	(
		[Monitor_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
</cfquery>
</cffunction>

</cfcomponent>