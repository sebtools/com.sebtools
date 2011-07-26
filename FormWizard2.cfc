<cfcomponent displayname="Form Wizard" hint="I handle general tasks relating to a multi-step form process.">

<cffunction name="init" access="public" returntype="FormWizard2" output="no">
	<cfargument name="Scrubber" type="com.sebtools.Scrubber" required="yes">
	<cfargument name="FormMap" type="string" required="yes">
	<cfargument name="verify" type="boolean" default="true">
	
	<cfscript>
	variables.Scrubber = arguments.Scrubber;
	variables.keys = "";
	variables.InfoStructs = "";
	variables.Storage = StructNew();
	variables.Saved = StructNew();
	variables.Key = StructNew();
	setFormMap(arguments.FormMap);
	if ( verify ) {
		checkFormMap();
	}
	setFormScrubs();
	</cfscript>
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
	var i = 1;
	var j = 1;
	var k = 1;
	var key = "";
	
	var result = StructNew();
	
	var fields = "";
	var required = "";
	
	result["MapOld"] = StructNew();
	
	//elem = myXML.xmlRoot;
	// Loop over categories of information
	for (i=1; i lte ArrayLen(myXML.xmlRoot.XmlChildren); i=i+1  ) {
		tag_cat = myXML.xmlRoot.XmlChildren[i];

		result["MapFull"][tag_cat.xmlName] = StructNew();
		//If category is "data", loop through data
		switch (tag_cat.xmlName) {
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
		<cfif Not (StructKeyExists(arguments.ArgStruct, field) AND Len(arguments.ArgStruct[field]))>
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

<cffunction name="begin" access="public" returntype="UUID" output="no">
	<cfscript>
	var processkey = CreateUUID();
	var key = "";
	var i = 1;
	var tmpField = "";
	
	//checkIsMapped();

	variables.Storage[processkey] = StructNew();
	variables.Saved[processkey] = false;
	variables.Key[processkey] = 0;
	
	for (key in variables.FormMap) {
		variables.Storage[processkey][key] = StructNew();
		for (i=1; i lte ListLen(variables.FormMap[key].fields); i=i+1) {
			tmpField = ListGetAt(variables.FormMap[key].fields,i);
			variables.Storage[processkey][key][tmpField] = "";
		}
	}
	</cfscript>
	
	<cfreturn processkey>
</cffunction>

<cffunction name="getProcessData" access="public" returntype="struct" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfreturn variables.Storage[arguments.processkey]>
</cffunction>

<cffunction name="isProcessSaved" access="public" returntype="boolean" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfreturn variables.Saved[arguments.processkey]>
</cffunction>

<cffunction name="markSaved" access="public" output="no">
	<cfargument name="processkey" type="UUID" required="yes">

	<cfset variables.Saved[arguments.processkey] = true>

</cffunction>

<cffunction name="savePageFields" access="public" returntype="void" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfargument name="pagename" type="string" required="yes">
	<cfargument name="formdata" type="struct" required="yes">
	
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
		if ( StructKeyExists(Pages[pagename],"struct") ) {
			variables.Storage[processkey][Pages[pagename].struct][field] = formdata[field];
		} else {
			if ( StructKeyExists(Pages[pagename],field) ) {
				variables.Storage[processkey][Pages[pagename][field].datastruct][Pages[pagename][field].datafield] = formdata[field];	
			}
		}
	}
	if ( StructKeyExists(Validations,pagename) ) {
		variables.Scrubber.checkForm(pagename,formdata);
	}
	</cfscript>
	
</cffunction>

<cffunction name="setInfoStruct" access="package" returntype="void" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	<cfargument name="fielddata" type="struct" required="yes">
	
	<cfset fields = arguments.fielddata>
	
	<!--- Loop over each field in this struct --->
	<cfloop index="field" list="#variables.FormMap[InfoStruct].fields#">
		<!--- If information is passed in for this field, set the same field in info struct --->
		<cfif StructKeyExists(fields, field)>
			<cfset variables.Storage[arguments.processkey][arguments.InfoStruct][field] = fields[field]>
		</cfif>
	</cfloop>
	
	<!--- Check required fields --->
	<cfset this.checkReqFields(variables.FormMap[InfoStruct].required,fields)>
	
</cffunction>

<cffunction name="getInfoStruct" access="package" returntype="struct" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	
	<cfreturn variables.Storage[arguments.processkey][arguments.InfoStruct]>
</cffunction>

<cffunction name="setOneField" access="package" returntype="void" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	<cfargument name="InfoField" type="string" required="yes">
	<cfargument name="FieldValue" type="any" required="yes">

	<cfset variables.Storage[arguments.processkey][arguments.InfoStruct][arguments.InfoField] = arguments.FieldValue>
</cffunction>

<cffunction name="getOneField" access="package" returntype="string" output="no">
	<cfargument name="processkey" type="UUID" required="yes">
	<cfargument name="InfoStruct" type="string" required="yes">
	<cfargument name="InfoField" type="string" required="yes">

	<cfreturn variables.Storage[arguments.processkey][arguments.InfoStruct][arguments.InfoField]>
</cffunction>

</cfcomponent>