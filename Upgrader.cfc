<cfcomponent>

<cffunction name="makeXmlFile" access="public" returntype="void" output="false">
	<cfargument name="dir" type="string" required="true" hint="The directory from which to make an XML file.">
	<cfargument name="file" type="string" required="true" hint="The full path of the file to save.">
	
	<cfset var qFiles = 0>
	<cfset var xFiles = 0>
	<cfset var filepath = "">
	
	<cfdirectory directory="#arguments.dir#" action="list" recurse="yes" name="qFiles">
	
	<cfxml variable="xFiles"><cfoutput>
	<build date="#DateFormat(now(),'yyyy-mm-dd')#">
	<cfloop query="qFiles">
		<cfset filepath = ReplaceNoCase(Directory,arguments.dir,"")>
		<cfset filepath = ReplaceNoCase(filepath,"\","/")>
		<cfset filepath = "#filepath#/#name#">
		<cfif Type EQ "file">
			<file path="#filepath#" size="#size#" modified="#DateFormat(DateLastModified,'yyyy-mm-dd')#" />
		</cfif>
	</cfloop>
	</build>
	</cfoutput></cfxml>
	
	<cffile action="write" file="#arguments.file#" output="#XmlHumanReadable(xFiles)#">
</cffunction>

<cfscript>
/**
 * Formats an XML document for readability.
 * update by Fabio Serra to CR code
 * 
 * @param XmlDoc 	 XML document. (Required)
 * @return Returns a string. 
 * @author Steve Bryant (steve@bryantwebconsulting.com) 
 * @version 2, March 20, 2006 
 */
function XmlHumanReadable(XmlDoc) {
	var elem = "";
	var result = "";
	var tab = "	";
	var att = "";
	var i = 0;
	var temp = "";
	var cr = createObject("java","java.lang.System").getProperty("line.separator");
	
	if ( isXmlDoc(XmlDoc) ) {
		elem = XmlDoc.XmlRoot;//If this is an XML Document, use the root element
	} else if ( IsXmlElem(XmlDoc) ) {
		elem = XmlDoc;//If this is an XML Document, use it as-as
	} else if ( NOT isXmlDoc(XmlDoc) ) {
		XmlDoc = XmlParse(XmlDoc);//Otherwise, try to parse it as an XML string
		elem = XmlDoc.XmlRoot;//Then use the root of the resulting document
	}
	//Now we are just working with an XML element
	result = "<#elem.XmlName#";//start with the element name
	if ( StructKeyExists(elem,"XmlAttributes") ) {//Add any attributes
		for ( att in elem.XmlAttributes ) {
			result = '#result# #att#="#XmlFormat(elem.XmlAttributes[att])#"';
		}
	}
	if ( Len(elem.XmlText) OR (StructKeyExists(elem,"XmlChildren") AND ArrayLen(elem.XmlChildren)) ) {
		result = "#result#>#cr#";//Add a carriage return for text/nested elements
		if ( Len(Trim(elem.XmlText)) ) {//Add any text in this element
			result = "#result##tab##XmlFormat(Trim(elem.XmlText))##cr#";
		}
		if ( StructKeyExists(elem,"XmlChildren") AND ArrayLen(elem.XmlChildren) ) {
			for ( i=1; i lte ArrayLen(elem.XmlChildren); i=i+1 ) {
				temp = Trim(XmlHumanReadable(elem.XmlChildren[i]));
				temp = "#tab##ReplaceNoCase(trim(temp), cr, "#cr##tab#", "ALL")#";//indent
				result = "#result##temp##cr#";
			}//Add each nested-element (indented) by using recursive call
		}
		result = "#result#</#elem.XmlName#>";//Close element
	} else {
		result = "#result# />";//self-close if the element doesn't contain anything
	}
	
	return result;
}
</cfscript>

</cfcomponent>