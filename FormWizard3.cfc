<cfcomponent displayname="Form Wizard" hint="I handle general tasks relating to a multi-step form process.">

<cffunction name="init" access="public" returntype="FormWizard3" output="no">
	<cfargument name="Scrubber" type="com.sebtools.Scrubber" required="yes">
	<cfargument name="FormMap" type="string" required="yes">
	<cfargument name="DataMgr" type="any" required="yes">
	
	<cfargument name="verify" type="boolean" default="true">

	<cfset var qTest = 0>
	
	<cfscript>
	variables.DataMgr = arguments.DataMgr;
	variables.Scrubber = arguments.Scrubber;
	variables.InfoStructs = "";
	
	// This structure is provided for backwards compatibility with FromWizard2
	variables.Key = StructNew();
	
	variables.Datasource = variables.DataMgr.getDatasource();
	setFormMap(arguments.FormMap);
	if ( verify ) {
		checkFormMap();
	}
	setFormScrubs();
	
	// This is done after setFormMap because it is dependent on values in the FormMap
	variables.DataMgr.loadXML(getTableXml());
	</cfscript>
		
	<!--- Create table if necessary. --->	
	<cftry>
		<cfquery name="qTest" datasource="#variables.datasource#">SELECT TOP 1 RecID FROM wizardFormStorage</cfquery>
		<cfcatch>
			<cfset variables.DataMgr.createTable('wizardFormStorage')>
		</cfcatch>
	</cftry>

	<cfreturn this>
</cffunction>

<cffunction name="checkFormMap" access="private" returntype="void" output="yes">
	
	<cfscript>
	var Data = variables.FormMapFull["data"];
	var struct = "";
	var datafield = "";
	var Pages = variables.FormMapFull["pages"];
	var page = "";
	var pagefield = "";
	
	var isStructFound = false;
	var isFieldFound = false;
	var missingDataFields = "";
	var missingPageFields = "";
	var errMessage = "";

	//Check each data field to make sure it has a form field associated with it
	for ( struct in Data ) {//loop over structs
		isStructFound = false;
		//First check to see if any page takes ownership of the whole struct
		for ( page in Pages ) {
			if ( StructKeyExists(Pages[page],"struct") AND Pages[page]["struct"] eq struct ) {
				isStructFound = true;
			}
		}
		//then check for each field
		if ( NOT isStructFound ) {
			for ( datafield in Data[struct] ) {//loop over each field in struct
				isFieldFound = false;
				for ( page in Pages ) {//look in each page
					for ( pagefield in Pages[page] ) {//look at each field in each page
						if ( isStruct(Pages[page][pagefield]) AND StructKeyExists(Pages[page][pagefield],"datastruct") ) {
							if ( (Pages[page][pagefield].datastruct eq struct) AND (Pages[page][pagefield].datafield eq datafield) ) {//
								isFieldFound = true;
							}
						}
					}
				}// /for
				if ( NOT isFieldFound ) {
					missingDataFields = ListAppend(missingDataFields,"#struct#:#datafield#");
				}// /if
			}// /for
		}// /if
	}// /for
	
	//Check each page field to make sure that the datafield it points to exists
	for ( page in Pages ) {
		for ( pagefield in Pages[page] ) {
			if ( isStruct(Pages[page][pagefield]) ) {
				isFieldFound = false;
				for ( struct in Data ) {
					if ( Pages[page][pagefield].datastruct eq struct ) {
						for ( datafield in Data[struct] ) {
							if ( Pages[page][pagefield]["datafield"] eq datafield ) {
								isFieldFound = true;
							}// /if
						}// /for
					}// /if
				}// /for
				if ( NOT isFieldFound ) {
					missingPageFields = ListAppend(missingPageFields,"#page#:#pagefield#");
				}// /if
			}// /if
		}// /for
	}// /for
	</cfscript>
	<cfif Len(missingDataFields)>
		<cfset errMessage = errMessage & "Some Data would not be captured by this wizard: #missingDataFields#<br>">
	</cfif>
	<cfif Len(missingPageFields)>
		<cfset errMessage = errMessage & "Some form fields would not be captured by this wizard: #missingPageFields#<br>">
	</cfif>
	<cfif Len(errMessage)>
		<cfthrow message="#errMessage#" type="InitializationError" errorcode="FormWizardInitializationError">
	</cfif>

</cffunction>

<cffunction name="setFormScrubs" access="private" returntype="void" output="no" hint="I set the validations/scrubs for each form.">
	
	<cfscript>
	var page = "";
	var field = "";
	var datafield = "";
	
	var stcPages = variables.FormMapFull["pages"];
	var stcData = variables.FormMapFull["data"];
	var stcValidations = StructNew();
	</cfscript><!--- <cfdump var="#variables.FormMapFull#"><cfabort> --->
	<cfscript>
	for ( page in stcPages ) {
		stcValidations = StructNew();
		
		if ( StructKeyExists(stcPages[page],"struct") ) {
			//If this page is directly mapped to a data struct
			
			for ( field in stcData[stcPages[page]["struct"]] ) {
				stcValidations[field] = stcData[stcPages[page]["struct"]][field];
			}
		} else {
			//If this page is not directly mapped to a data struct
			
			for ( field in stcPages[page] ) {
				if ( StructKeyExists(stcPages[page][field],"datafield") ) {
					datafield = stcPages[page][field].datafield;
				} else {
					datafield = stcPages[page][field].formfield;
				}
				if ( StructKeyExists(stcData,stcPages[page][field].datastruct) AND StructKeyExists(stcData[stcPages[page][field].datastruct],datafield) ) {
					stcValidations[stcPages[page][field].formfield] = stcData[stcPages[page][field].datastruct][datafield];
				}
				//stcValidations[stcPages[page][field].formfield] = stcData[stcPages[page][field].datastruct][datafield];
			}
			
		}// /if
		//WriteOutput("#page#<br>");
		variables.Scrubber.addForm(page,stcValidations);
	}// /for
	//WriteOutput("Blah<br>");
	</cfscript><!--- <cfabort> --->
</cffunction>

<cffunction name="getValidations" access="public" returntype="struct">
	<cfreturn variables.Scrubber.getForms()>
</cffunction>

<cffunction name="setFormMap" access="private" returntype="void" output="no" hint="I set the form map which must be a structure containing a key for every group of information in the process. Each must in turn be a structure with the keys of fields (to store all of the field names) and required (to store the name of required fields).">
	<cfargument name="FormMap" type="string" required="yes">
	
	<cfscript>
	var myXML = XmlParse(arguments.FormMap);
	var elem = 0;
	var tag_cat = 0;
	var tag_struct = 0;
	var tag_field = 0;
	var tag_page = 0;
	var tag_param = 0;
	var i = 1;
	var j = 1;
	var k = 1;
	var key = "";

	var FoundConfigSection = false; //Used to determine if we should default the config values.
	
	var result = StructNew();
	
	var fields = "";
	var required = "";
	
	result["MapOld"] = StructNew();
	
	// Loop over categories of information
	for (i=1; i lte ArrayLen(myXML.xmlRoot.XmlChildren); i=i+1  ) {
		tag_cat = myXML.xmlRoot.XmlChildren[i];

		result["MapFull"][tag_cat.xmlName] = StructNew();
		
		switch (tag_cat.xmlName) {
			// Get all the configuration parameters
			case "config":
				FoundConfigSection = true;
				for (j=1; j lte ArrayLen(tag_cat.XmlChildren); j=j+1  ) {
					tag_param = tag_cat.XmlChildren[j];
					StructInsert(result["MapFull"][tag_cat.xmlName],tag_param.XmlAttributes.name,tag_param.XmlAttributes.value);
					}
			break;
			// Get all the data keys
			case "data":
				//Loop through structures
				for (j=1; j lte ArrayLen(tag_cat.XmlChildren); j=j+1  ) {
					tag_struct = tag_cat.XmlChildren[j];
					//If data is structure, loop over fields
					if ( tag_struct.xmlName eq "struct" ) {
						result["MapOld"][tag_struct.xmlAttributes["name"]] = StructNew();
						result["MapFull"][tag_cat.xmlName][tag_struct.xmlAttributes["name"]] = StructNew();
						fields = "";
						required = "";
						structstruct = StructNew();
						//Loop through fields
						for (k=1; k lte ArrayLen(tag_struct.XmlChildren); k=k+1  ) {
							tag_field = tag_struct.XmlChildren[k];
							tag_field_atts = tag_field.xmlAttributes;
							
							result["MapFull"][tag_cat.xmlName][tag_struct.xmlAttributes["name"]][tag_field_atts["name"]] = tag_field_atts;
							fields = ListAppend(fields,tag_field_atts["name"]);
							if ( StructKeyExists(tag_field_atts,"required") AND isBoolean(tag_field_atts["required"]) AND tag_field_atts["required"] ) {
								required = ListAppend(required,tag_field.xmlAttributes["name"]);
							}
						} // /for
						result["MapOld"][tag_struct.xmlAttributes["name"]]["fields"] = fields;
						result["MapOld"][tag_struct.xmlAttributes["name"]]["required"] = required;
					}// /if
				} // /for
			break;
			// Get all the page association information
			case "pages":
				for (j=1; j lte ArrayLen(tag_cat.XmlChildren); j=j+1  ) {
					tag_page = tag_cat.XmlChildren[j];
					result["MapFull"][tag_cat.xmlName][tag_page.xmlAttributes["name"]] = StructNew();
					if ( StructKeyExists(tag_page.xmlAttributes,"struct") ) {
						result["MapFull"][tag_cat.xmlName][tag_page.xmlAttributes["name"]]["struct"] = tag_page.xmlAttributes["struct"];
					}
					for (k=1; k lte ArrayLen(tag_page.XmlChildren); k=k+1  ) {
						tag_in = tag_page.XmlChildren[k];
						result["MapFull"][tag_cat.xmlName][tag_page.xmlAttributes["name"]][tag_in.xmlAttributes["formfield"]] = tag_in.xmlAttributes;
						if ( Not StructKeyExists(result["MapFull"][tag_cat.xmlName][tag_page.xmlAttributes["name"]][tag_in.xmlAttributes["formfield"]],"datafield") ) {
							result["MapFull"][tag_cat.xmlName][tag_page.xmlAttributes["name"]][tag_in.xmlAttributes["formfield"]].datafield = tag_in.xmlAttributes["formfield"];
						}
					}
				}
			break;
		}// /switch

	}// /for

	// If not config section was found we need to default those settings.
	if (NOT FoundConfigSection) {
		result["MapFull"]["config"] = StructNew();
		StructInsert(result["MapFull"]["config"],"StorageTableName","wizardFormStorage");
		StructInsert(result["MapFull"]["config"],"StorageTableIdentityField","UniqueID");
		StructInsert(result["MapFull"]["config"],"StorageTableCFIdentityFieldType","CF_SQL_IDSTAMP");
		StructInsert(result["MapFull"]["config"],"StorageTableSQLIdentityFieldType","UniqueIdentifier");
		StructInsert(result["MapFull"]["config"],"IncrementStorageTableIdentity","true");
	}

	variables.FormMap = result["MapOld"];
	variables.FormMapFull = result["MapFull"];
	
	for (key in variables.FormMap) {
		variables.InfoStructs = ListAppend(variables.InfoStructs,key);
	}
	
	variables.isFormMapped = true;
	</cfscript>
</cffunction>

<cffunction name="getInfoStructs" access="package" returntype="string" output="no" hint="I return a list of the structures used to hold registration information.">
	<!--- <cfset checkIsMapped()> --->
	
	<cfreturn variables.InfoStructs>
</cffunction>

<cffunction name="getFullMap" access="public" returntype="struct" output="no">
	<cfreturn variables.FormMapFull>
</cffunction>

<cffunction name="getFieldLists" access="package" returntype="struct" output="no" hint="I return a structure with a list of fields for each type of registration information.">

	<cfscript>
	var fieldlists = StructNew();
	var key = "";
	
	for (key in variables.FormMap) {
		fieldlists[key] = variables.FormMap[key]["fields"];
	}
	</cfscript>
	
	<cfreturn fieldlists>
</cffunction>

<cffunction name="getRequiredLists" access="package" returntype="struct" output="no" hint="I return a structure with a list of required fields for each type of registration information.">
	<cfscript>
	var requiredlists = StructNew();
	var key = "";
	
	for (key in variables.FormMap) {
		requiredlists[key] = variables.FormMap[key]["required"];
	}
	</cfscript>
	
	<cfreturn requiredlists>
</cffunction>

<cffunction name="checkReqFields" access="public" returntype="void" output="no" hint="I Throw an error if some required fields are missing.">
	<cfargument name="fields" type="string" required="yes">
	<cfargument name="ArgStruct" type="struct" required="yes">
	
	<cfset var missingfields = "">
	
	<!--- Loop over required fields --->
	<cfloop index="field" list="#arguments.fields#">
		<!--- If the field is missing, add it to the list of missing fields --->
		<cfif Not (StructKeyExists(arguments.ArgStruct, field) AND Len(Trim(arguments.ArgStruct[field])))>
			<cfset missingfields = ListAppend(missingfields, field)>
		</cfif>
	</cfloop>
	<!--- If any required fields are missing, throw an error. --->
	<cfif Len(missingfields)>
		<cfthrow message="Required fields (#missingfields#) are missing." type="MethodErr" detail="The following fields are required: #arguments.fields#. Of those, the following are missing #missingfields#." errorcode="MissingField" extendedinfo="#missingfields#">
	</cfif>
	
</cffunction>

<!--- ********************** END OF WIZARD GENERATION ********************************* --->
<!--- ********************** START OF INFORMATION TRACKING  ********************************* --->

<cffunction name="begin" access="public" returntype="any" output="no">
	<cfscript>
	var ID = "";
	var ProcessKey = 0;
	var wddxStorage = "";
	var sData = StructNew();
	var key = "";
	var i = 1;
	var tmpField = "";
	
	// Default all the wizard fields to empty strings
	for (key in variables.FormMap) {
		sData[key] = StructNew();
		for (i=1; i lte ListLen(variables.FormMap[key].fields); i=i+1) {
			tmpField = ListGetAt(variables.FormMap[key].fields,i);
			sData[key][tmpField] = "";
		}
	}
	</cfscript>
	
	<cfwddx action="CFML2WDDX" input="#sData#" output="wddxStorage">
	<cfquery name="qRecID" datasource="#variables.Datasource#">
	INSERT INTO [#variables.FormMapFull.config.StorageTableName#] (
		LastUpdate,
		FormData,
		Saved
	) VALUES(
		GETDATE(),
		<cfqueryparam value="#wddxStorage#" cfsqltype="CF_SQL_LONGVARCHAR">,
		0
	)
	
	SELECT @@Identity As [ID]
	</cfquery>		
	
	<!--- We need to retrieve the GUID created by SQL. --->
	<cfif variables.FormMapFull.config.StorageTableCFIdentityFieldType EQ "CF_SQL_IDSTAMP">
		<cfquery name="qRecID" datasource="#variables.Datasource#">
		SELECT	[#variables.FormMapFull.config.StorageTableIdentityField#] AS [ID]
		FROM	[#variables.FormMapFull.config.StorageTableName#]
		WHERE	RecID = <cfqueryparam value="#qRecID.ID#" cfsqltype="CF_SQL_INTEGER">
		</cfquery>	
	</cfif>
	
	<!--- This is done to provide backward compatibility with FormWizard2 --->
	<cfset variables.Key[qRecID.ID] = qRecID.ID>
	
	<cfreturn qRecID.ID>
</cffunction>

<cffunction name="getProcessData" access="public" returntype="struct" output="no">
	<cfargument name="Key" type="any" required="yes">
	
	<cfset var qData = 0>
	<cfset var sData = 0>
	
	<!--- Retrieve record and convert to structure --->
	<cfquery name="qData" datasource="#variables.datasource#">
	SELECT	FormData
	FROM	[#variables.FormMapFull.config.StorageTableName#]
	WHERE	#variables.FormMapFull.config.StorageTableIdentityField# = <cfqueryparam value="#arguments.Key#" cfsqltype="#variables.FormMapFull.config.StorageTableCFIdentityFieldType#">
	</cfquery>
	
	<cfif qData.RecordCount>
		<cfwddx action="WDDX2CFML" input="#qData.FormData#" output="sData">
	<cfelse>
		<cfthrow message="No application can be found for the process key of #arguments.Key#.">
	</cfif>
	
	<cfreturn sData>
</cffunction>

<cffunction name="isProcessSaved" access="public" returntype="boolean" output="no">
	<cfargument name="Key" type="Any" required="yes">

	<cfset var qData = 0>
	
	<!--- Retrieve record and convert to structure --->
	<cfquery name="qData" datasource="#variables.datasource#">
	SELECT	Saved
	FROM	[#variables.FormMapFull.config.StorageTableName#]
	WHERE	#variables.FormMapFull.config.StorageTableIdentityField# = <cfqueryparam value="#arguments.Key#" cfsqltype="#variables.FormMapFull.config.StorageTableCFIdentityFieldType#">		
	</cfquery>
	
	<cfif qData.Saved EQ 1>
		<cfreturn true>
	<cfelse>
		<cfreturn false>
	</cfif>
</cffunction>

<cffunction name="markSaved" access="public" output="no">
	<cfargument name="Key" type="Any" required="yes">

	<cfquery datasource="#variables.datasource#">
	UPDATE	[#variables.FormMapFull.config.StorageTableName#]
	SET		Saved = 1
	WHERE	#variables.FormMapFull.config.StorageTableIdentityField# = <cfqueryparam value="#arguments.Key#" cfsqltype="#variables.FormMapFull.config.StorageTableCFIdentityFieldType#">
	</cfquery>
</cffunction>

<cffunction name="savePageFields" access="public" returntype="void" output="no">
	<cfargument name="Key" type="any" required="yes">
	<cfargument name="pagename" type="string" required="yes">
	<cfargument name="formdata" type="struct" required="yes">
	
	<!--- Retrieve the current data so that we can alter or add to it. --->
	<cfset var sDataToStore = getProcessData(arguments.Key)>
	
	<cfset var field = "">
	<cfset var Pages = variables.FormMapFull["pages"]>
	<cfset var Data = variables.FormMapFull["data"]>
	<cfset var Validations = getValidations()>
	
	<cfscript>
	//Scrub data
	if ( StructKeyExists(Validations,pagename) ) {
		for ( field in formdata ) {
			if ( StructKeyExists(Validations[pagename],field) ) {
				formdata[field] = variables.Scrubber.scrubField(formdata[field],Validations[pagename][field]);
			}
		}
	}
	//Set data
	for ( field in formdata ) {
		if ( StructKeyExists(Pages,pagename) AND StructKeyExists(Pages[pagename],"struct") ) {
			sDataToStore[Pages[pagename].struct][field] = formdata[field];
		} else {
			if ( StructKeyExists(Pages[pagename],field) ) {
				sDataToStore[Pages[pagename][field].datastruct][Pages[pagename][field].datafield] = formdata[field];	
			}
		}
	}

	saveDataStruct(arguments.Key,sDataToStore);

	if ( StructKeyExists(Validations,pagename) ) {
		variables.Scrubber.checkForm(pagename,formdata);
	}
	</cfscript>
	
</cffunction>

<cffunction name="saveDataStruct" access="private" returntype="void" output="no">
	<cfargument name="Key" type="any" required="yes">
	<cfargument name="DataStruct" type="struct" required="yes">

	<cfset var wddxStorage = 0>

	<cfwddx action="CFML2WDDX" input="#arguments.DataStruct#" output="wddxStorage">
	
	<cfquery name="qRecID" datasource="#variables.Datasource#">
	UPDATE	[#variables.FormMapFull.config.StorageTableName#]
		SET	LastUpdate = GETDATE(),
			FormData = <cfqueryparam value="#wddxStorage#" cfsqltype="CF_SQL_LONGVARCHAR">
	WHERE	#variables.FormMapFull.config.StorageTableIdentityField# = <cfqueryparam value="#arguments.Key#" cfsqltype="#variables.FormMapFull.config.StorageTableCFIdentityFieldType#">
	</cfquery>
</cffunction>

<cffunction name="setInfoStruct" access="package" returntype="void" output="no">
	<cfargument name="Key" type="any" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	<cfargument name="fielddata" type="struct" required="yes">
	<cfargument name="checkrequired" type="boolean" default="true">
	
	<!--- Retrieve the current data so that we can alter or add to it. --->
	<cfset var sDataToStore = getProcessData(arguments.Key)>
	
	<!--- <cfset var fields = arguments.fielddata> --->
	
	<!--- Loop over each field in this struct --->
	<!--- <cfloop index="field" list="#variables.FormMap[InfoStruct].fields#"> --->
		<!--- If information is passed in for this field, set the same field in info struct --->
		<!--- <cfif StructKeyExists(fields, field)>
			<cfset sDataToStore[arguments.InfoStruct][field] = fields[field]>
		</cfif>
	</cfloop> --->
	<!--- <cfset sDataToStore[arguments.InfoStruct][field] = fields[field]> --->
	<cfset StructAppend(sDataToStore[arguments.InfoStruct], arguments.fielddata)>
	
	<cfset saveDataStruct(arguments.Key, sDataToStore)>
	
	<!--- Check required fields --->
	<cfif arguments.checkrequired>
		<cfset this.checkReqFields(variables.FormMap[InfoStruct].required,arguments.fielddata)>
	</cfif>

</cffunction>

<cffunction name="getInfoStruct" access="package" returntype="struct" output="no">
	<cfargument name="Key" type="any" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	
	<!--- Retrieve the current data so that we can alter or add to it. --->
	<cfset var sDataToStore = getProcessData(arguments.Key)>

	<cfreturn sDataToStore[arguments.InfoStruct]>
</cffunction>

<cffunction name="setOneField" access="package" returntype="void" output="no">
	<cfargument name="Key" type="any" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	<cfargument name="InfoField" type="string" required="yes">
	<cfargument name="FieldValue" type="any" required="yes">

	<!--- Retrieve the current data so that we can alter or add to it. --->
	<cfset var sDataToStore = getProcessData(arguments.Key)>
	
	<cfset sDataToStore[arguments.InfoStruct][arguments.InfoField] = arguments.FieldValue>

	<cfset saveDataStruct(arguments.Key, sDataToStore)>
</cffunction>

<cffunction name="getOneField" access="package" returntype="string" output="no">
	<cfargument name="Key" type="any" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	<cfargument name="InfoField" type="string" required="yes">

	<!--- Retrieve the current data so that we can alter or add to it. --->
	<cfset var sDataToStore = getProcessData(arguments.Key)>

	<cfreturn sDataToStore[arguments.InfoStruct][arguments.InfoField]>
</cffunction>

<cffunction name="getTableXml" access="public" returntype="string" output="no" hint="I return the XML for the tables needed for FormWizard to work.">
	<cfset var tableXML = "">
	
	<cfoutput>
		<cfsavecontent variable="tableXML">
		<tables>
			<table name="#variables.FormMapFull.config.StorageTableName#">
				<field ColumnName="RecID" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="Yes" />
				<field ColumnName="#variables.FormMapFull.config.StorageTableIdentityField#" CF_DataType="#variables.FormMapFull.config.StorageTableCFIdentityFieldType#"/>
				<field ColumnName="LastUpdate" CF_DataType="CF_SQL_DATE" />
				<field ColumnName="FormData" CF_DataType="CF_SQL_LONGVARCHAR" />
				<field ColumnName="Saved" CF_DataType="CF_SQL_BIT" />
			</table>
		</tables>
		</cfsavecontent>
	</cfoutput>
	
	<cfreturn tableXML>
</cffunction>

<cffunction name="getExistingProcessKey" access="public" returntype="string" output="no">
	<cfargument name="SearchCriteria" required="yes" type="array">
	
	<cfscript>
		var nCounter = 0;
		// Used to throw error if no structures are passed in the array.
		var lContainedStructures = false;
		var cWhereClause = "1 = 1";
		var sOutput = "";
		var qData = QueryNew("Key");
		var qResults = 0;
		var lAddRecord = false;
	</cfscript>

	<cfquery name="qResults" datasource="#variables.Datasource#">
		SELECT #variables.FormMapFull.config.StorageTableIdentityField#, FormData FROM [#variables.FormMapFull.config.StorageTableName#]
		WHERE 1 = 1
		<cfloop from="1" to="#ArrayLen(arguments.SearchCriteria)#" step="1" index="nCounter">
			<cfif isStruct(arguments.SearchCriteria[nCounter])>
				<cfset lContainedStructures = true>
	
				<!--- Make sure structure is valid --->
				<cfif NOT StructKeyExists(arguments.SearchCriteria[nCounter],"Struct")>
					<cfthrow message="arguments.SearchCriteria[#nCounter#] MUST contain a Struct key." type="FormWizardErr">
				</cfif>
				<cfif NOT StructKeyExists(arguments.SearchCriteria[nCounter],"Field")>
					<cfthrow message="arguments.SearchCriteria[#nCounter#] MUST contain a Field key." type="FormWizardErr">
				</cfif>
				<cfif NOT StructKeyExists(arguments.SearchCriteria[nCounter],"Value")>
					<cfthrow message="arguments.SearchCriteria[#nCounter#] MUST contain a Value key." type="FormWizardErr">
				</cfif>			

				AND FormData LIKE <cfqueryparam value="%#arguments.SearchCriteria[nCounter].value#%" cfsqltype="CF_SQL_VARCHAR">
			</cfif>
		</cfloop>
	</cfquery>

	<cfif NOT lContainedStructures>
		<cfthrow message="arguments.SearchCriteria contained no structures." type="FormWizardErr">
	</cfif>
	
	<cfif qResults.RecordCount GT 0>
		<cfloop query="qResults">
			<cfset lAddRecord = false>
			<cfwddx action="WDDX2CFML" input="#qResults.FormData#" output="sOutput">

			<cfloop from="1" to="#ArrayLen(arguments.SearchCriteria)#" step="1" index="nCounter">
				<!--- Make sure this structure exists in the retrieved record --->
				<cfif StructKeyExists(sOutput,arguments.SearchCriteria[nCounter].Struct) AND isStruct(sOutput[arguments.SearchCriteria[nCounter].Struct])>
					<!--- Make sure the field we are looking for exists in this structure --->
					<cfif StructKeyExists(sOutput[arguments.SearchCriteria[nCounter].Struct],arguments.SearchCriteria[nCounter].Field)>
						<cfif sOutput[arguments.SearchCriteria[nCounter].Struct][arguments.SearchCriteria[nCounter].Field] EQ arguments.SearchCriteria[nCounter].Value>
							<cfset lAddRecord = true>
						</cfif>
					</cfif>
				<cfelse>
					<cfthrow message="The structure #arguments.SearchCriteria[nCounter].Struct# could not be found." type="FormWizardErr">
				</cfif>
			</cfloop>
			
			<cfif lAddRecord>
				<!--- Add to list --->
				<cfset QueryAddRow(qData)>
				<cfset QuerySetCell(qData,"Key",qResults[variables.FormMapFull.config.StorageTableIdentityField][qResults.CurrentRow])>
			</cfif>
		</cfloop>
		
		<cfif qData.RecordCount GT 0>
			<cfif qData.RecordCount GT 1>
				<cfthrow message="Two or more records were located matching the search criteria specified in arguments.SearchCriteria" type="FormWizardErr">							
			<cfelse>
				<cfreturn qData.Key>
			</cfif>
		<cfelse>
			<cfthrow message="Records were found matching the search criteria specified in arguments.SearchCriteria, however no records could be identified within the given structures" type="FormWizardErr">			
		</cfif>
	<cfelse>
		<cfthrow message="No records found matching the search criteria specified in arguments.SearchCriteria." type="FormWizardErr">
	</cfif>	
</cffunction>

</cfcomponent>