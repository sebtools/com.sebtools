<cfcomponent displayname="Utilities" hint="I perform several general-purpose functions.">

<cffunction name="init" access="public" returntype="com.sebtools.util" output="no" hint="I initialize and return this object.">
	<cfreturn this>
</cffunction>

<cffunction name="paramVar" access="public" returntype="any" output="no">
	<cfargument name="name" type="string" required="yes">
	<cfargument name="default" type="any" required="yes">
	<cfargument name="type" type="string" required="no">
	
	<cfset var types = "any,array,boolean,binary,date,numeric,query,string,struct,UUID">
	<cfset var doset = false>
	<cfset var val = "">
	
	<!--- If string is passed, it must be one of available types --->
	<cfif StructKeyExists(arguments,"type") AND NOT ListFindNoCase(types,arguments.type)>
		<cfthrow message="paramVar can only accept the following types: #types#">
	</cfif>
	
	<cfif isDefined(arguments.name)>
		<cfset val = evaluate(arguments.name)>
		<cfif StructKeyExists(arguments,"type")>
			<cfswitch expression="#arguments.type#">
			<cfcase value="array">
				<cfif NOT isArray(val)>
					<cfset doset = true>
				</cfif>
			</cfcase>
			<cfcase value="boolean">
				<cfif NOT isBoolean(val)>
					<cfset doset = true>
				</cfif>
			</cfcase>
			<cfcase value="binary">
				<cfif NOT IsBinary(val)>
					<cfset doset = true>
				</cfif>
			</cfcase>
			<cfcase value="date">
				<cfif NOT IsDate(val)>
					<cfset doset = true>
				</cfif>
			</cfcase>
			<cfcase value="numeric">
				<cfif NOT IsNumeric(val)>
					<cfset doset = true>
				</cfif>
			</cfcase>
			<cfcase value="query">
				<cfif NOT IsQuery(val)>
					<cfset doset = true>
				</cfif>
			</cfcase>
			<cfcase value="string">
				<cfif NOT IsSimpleValue(val)>
					<cfset doset = true>
				</cfif>
			</cfcase>
			<cfcase value="struct">
				<cfif NOT IsStruct(val)>
					<cfset doset = true>
				</cfif>
			</cfcase>
			</cfswitch>
		</cfif>
	<cfelse>
		<cfset doset = true>
	</cfif>
	
	<cfif doset>
		<cfset setVariable(arguments.name,arguments.default)>
	</cfif>
	
</cffunction>

<cfscript>
/**
 * Accepts a specifically formatted chunk of text, and returns it as a query object.
 * 
 * @param queryData 	 Specifically format chunk of text to convert to a query. 
 * @return Returns a query object. 
 * @author Bert Dawson (bert@redbanner.com) 
 * @version 1, September 26, 2001 
 */
function querySim(queryData) {
	var fieldsDelimiter="|";
	var colnamesDelimiter=",";
	var queryName="";
	var listOfColumns="";
	var tmpQuery="";
	var numLines="";
	var currentLine="";
	var cellValue="";
	var colName="";
	var lineDelimiter=chr(10) & chr(13);
    var lineNum=0;
    var colPosition=0;
	var cellValues="";
	
	// the first line is the name of the query, eg. "query name = myquery"
	queryName = Trim(ListLast(ListGetAt(queryData, 1, lineDelimiter),"="));

	// remove [ and ] for backward compatabilty with the .sim ini file format, ie where the first line is: [MyQueryName]
	queryName = Replace(Replace(queryName, "[", "", "all"), "]", "", "all");

	// the second line is the column list, eg "column list = column1,column2,column3"
	listOfColumns = Trim(ListLast(ListGetAt(queryData, 2, lineDelimiter),"="));
	
	// ensure that the delimiter in the listOfColumns is a comma, for passing to QueryNew() 
	listOfColumns = ListChangeDelims(listOfColumns, ",", colnamesDelimiter);
	
	// create a temporary Query
	tmpQuery = QueryNew(listOfColumns);

	// the number of lines in the queryData
	numLines = ListLen(queryData, lineDelimiter);
	
	// loop though the queryData starting at the third line
	for(lineNum=3;  lineNum LTE numLines;  lineNum = lineNum + 1) {
	    currentLine = ListGetAt(queryData, lineNum, lineDelimiter);
 
 		// this allows backward compatibility with old querySim.ini format.
		// The downside is that you can't use '=' in your data cells...
		cellValues = ListLast(currentLine, "=");

		if (ListLen(cellValues, fieldsDelimiter) IS ListLen(listOfColumns,",")) {
			QueryAddRow(tmpQuery);
			for (colPosition=1; colPosition LTE ListLen(listOfColumns); colPosition = colPosition + 1){
				cellValue = Trim(ListGetAt(cellValues, colPosition, fieldsDelimiter));
				colName   = Trim(ListGetAt(listOfColumns,colPosition));
				QuerySetCell(tmpQuery, colName, cellValue);
			}
		} 
	} 
	"#queryName#" = tmpQuery;
}


/*
	This library is part of the Common Function Library Project. An open source
	collection of UDF libraries designed for ColdFusion 5.0. For more information,
	please see the web site at:
		
		http://www.cflib.org
		
	Warning:
	You may not need all the functions in this library. If speed
	is _extremely_ important, you may want to consider deleting
	functions you do not plan on using. Normally you should not
	have to worry about the size of the library.
		
	License:
	This code may be used freely. 
	You may modify this code as you see fit, however, this header, and the header
	for the functions must remain intact.
	
	This code is provided as is.  We make no warranty or guarantee.  Use of this code is at your own risk.

	* Returns a number converted into a string (i.e. 1 becomes &quot;One&quot;).
	* Added catch for number=0. Thanks to Lucas for finding it.
	* 
	* @param number 	 The number to translate. (Required)
	* @return Returns a string. 
	* @author Ben Forta (ben@forta.com) 
	* @version 2, August 20, 2002 
*/

function NumberAsString(number)
{
   var Result="";          // Generated result
   var Str1="";            // Temp string
   var Str2="";            // Temp string
   var n=number;           // Working copy
   var Billions=0;
   var Millions=0;
   var Thousands=0;
   var Hundreds=0;
   var Tens=0;
   var Ones=0;
   var Point=0;
   var HaveValue=0;        // Flag needed to know if to process "0"

   // Initialize strings
   // Strings are "externalized" to simplify
   // changing text or translating
   if (NOT IsDefined("REQUEST.Strs"))
   {
      REQUEST.Strs=StructNew();
      REQUEST.Strs.space=" ";
      REQUEST.Strs.and="and";
      REQUEST.Strs.point="Point";
      REQUEST.Strs.n0="Zero";
      REQUEST.Strs.n1="One";
      REQUEST.Strs.n2="Two";
      REQUEST.Strs.n3="Three";
      REQUEST.Strs.n4="Four";
      REQUEST.Strs.n5="Five";
      REQUEST.Strs.n6="Six";
      REQUEST.Strs.n7="Seven";
      REQUEST.Strs.n8="Eight";
      REQUEST.Strs.n9="Nine";
      REQUEST.Strs.n10="Ten";
      REQUEST.Strs.n11="Eleven";
      REQUEST.Strs.n12="Twelve";
      REQUEST.Strs.n13="Thirteen";
      REQUEST.Strs.n14="Fourteen";
      REQUEST.Strs.n15="Fifteen";
      REQUEST.Strs.n16="Sixteen";
      REQUEST.Strs.n17="Seventeen";
      REQUEST.Strs.n18="Eighteen";
      REQUEST.Strs.n19="Nineteen";
      REQUEST.Strs.n20="Twenty";
      REQUEST.Strs.n30="Thirty";
      REQUEST.Strs.n40="Forty";
      REQUEST.Strs.n50="Fifty";
      REQUEST.Strs.n60="Sixty";
      REQUEST.Strs.n70="Seventy";
      REQUEST.Strs.n80="Eighty";
      REQUEST.Strs.n90="Ninety";
      REQUEST.Strs.n100="Hundred";
      REQUEST.Strs.nK="Thousand";
      REQUEST.Strs.nM="Million";
      REQUEST.Strs.nB="Billion";
   }
   
   // Save strings to an array once to improve performance
   if (NOT IsDefined("REQUEST.StrsA"))
   {
      // Arrays start at 1, to 1 contains 0
      // 2 contains 1, and so on
      REQUEST.StrsA=ArrayNew(1);
      ArrayResize(REQUEST.StrsA, 91);
      REQUEST.StrsA[1]=REQUEST.Strs.n0;
      REQUEST.StrsA[2]=REQUEST.Strs.n1;
      REQUEST.StrsA[3]=REQUEST.Strs.n2;
      REQUEST.StrsA[4]=REQUEST.Strs.n3;
      REQUEST.StrsA[5]=REQUEST.Strs.n4;
      REQUEST.StrsA[6]=REQUEST.Strs.n5;
      REQUEST.StrsA[7]=REQUEST.Strs.n6;
      REQUEST.StrsA[8]=REQUEST.Strs.n7;
      REQUEST.StrsA[9]=REQUEST.Strs.n8;
      REQUEST.StrsA[10]=REQUEST.Strs.n9;
      REQUEST.StrsA[11]=REQUEST.Strs.n10;
      REQUEST.StrsA[12]=REQUEST.Strs.n11;
      REQUEST.StrsA[13]=REQUEST.Strs.n12;
      REQUEST.StrsA[14]=REQUEST.Strs.n13;
      REQUEST.StrsA[15]=REQUEST.Strs.n14;
      REQUEST.StrsA[16]=REQUEST.Strs.n15;
      REQUEST.StrsA[17]=REQUEST.Strs.n16;
      REQUEST.StrsA[18]=REQUEST.Strs.n17;
      REQUEST.StrsA[19]=REQUEST.Strs.n18;
      REQUEST.StrsA[20]=REQUEST.Strs.n19;
      REQUEST.StrsA[21]=REQUEST.Strs.n20;
      REQUEST.StrsA[31]=REQUEST.Strs.n30;
      REQUEST.StrsA[41]=REQUEST.Strs.n40;
      REQUEST.StrsA[51]=REQUEST.Strs.n50;
      REQUEST.StrsA[61]=REQUEST.Strs.n60;
      REQUEST.StrsA[71]=REQUEST.Strs.n70;
      REQUEST.StrsA[81]=REQUEST.Strs.n80;
      REQUEST.StrsA[91]=REQUEST.Strs.n90;
   }

   //zero shortcut
   if(number is 0) return "Zero";

   // How many billions?
   // Note: This is US billion (10^9) and not
   // UK billion (10^12), the latter is greater
   // than the maximum value of a CF integer and
   // cannot be supported.
   Billions=n\1000000000;
   if (Billions)
   {
      n=n-(1000000000*Billions);
      Str1=NumberAsString(Billions)&REQUEST.Strs.space&REQUEST.Strs.nB;
      if (Len(Result))
         Result=Result&REQUEST.Strs.space;
      Result=Result&Str1;
      Str1="";
      HaveValue=1;
   }

   // How many millions?
   Millions=n\1000000;
   if (Millions)
   {
      n=n-(1000000*Millions);
      Str1=NumberAsString(Millions)&REQUEST.Strs.space&REQUEST.Strs.nM;
      if (Len(Result))
         Result=Result&REQUEST.Strs.space;
      Result=Result&Str1;
      Str1="";
      HaveValue=1;
   }

   // How many thousands?
   Thousands=n\1000;
   if (Thousands)
   {
      n=n-(1000*Thousands);
      Str1=NumberAsString(Thousands)&REQUEST.Strs.space&REQUEST.Strs.nK;
      if (Len(Result))
         Result=Result&REQUEST.Strs.space;
      Result=Result&Str1;
      Str1="";
      HaveValue=1;
   }

   // How many hundreds?
   Hundreds=n\100;
   if (Hundreds)
   {
      n=n-(100*Hundreds);
      Str1=NumberAsString(Hundreds)&REQUEST.Strs.space&REQUEST.Strs.n100;
      if (Len(Result))
         Result=Result&REQUEST.Strs.space;
      Result=Result&Str1;
      Str1="";
      HaveValue=1;
   }   

   // How many tens?
   Tens=n\10;
   if (Tens)
      n=n-(10*Tens);
    
   // How many ones?
   Ones=n\1;
   if (Ones)
      n=n-(Ones);
   
   // Anything after the decimal point?
   if (Find(".", number))
      Point=Val(ListLast(number, "."));
   
   // If 1-9
   Str1="";
   if (Tens IS 0)
   {
      if (Ones IS 0)
      {
         if (NOT HaveValue)
            Str1=REQUEST.StrsA[0];
      }
      else
         // 1 is in 2, 2 is in 3, etc
         Str1=REQUEST.StrsA[Ones+1];
   }
   else if (Tens IS 1)
   // If 10-19
   {
      // 10 is in 11, 11 is in 12, etc
      Str1=REQUEST.StrsA[Ones+11];
   }
   else
   {
      // 20 is in 21, 30 is in 31, etc
      Str1=REQUEST.StrsA[(Tens*10)+1];
      
      // Get "ones" portion
      if (Ones)
         Str2=NumberAsString(Ones);
      Str1=Str1&REQUEST.Strs.space&Str2;
   }
   
   // Build result   
   if (Len(Str1))
   {
      if (Len(Result))
         Result=Result&REQUEST.Strs.space&REQUEST.Strs.and&REQUEST.Strs.space;
      Result=Result&Str1;
   }

   // Is there a decimal point to get?
   if (Point)
   {
      Str2=NumberAsString(Point);
      Result=Result&REQUEST.Strs.space&REQUEST.Strs.point&REQUEST.Strs.space&Str2;
   }
    
   return Result;
}
</cfscript>


<cffunction name="getStates" access="public" returntype="query" output="no" hint="I return a query of states. I have one optional argument to a list of acceptable state types. Options are state,district,territory. Defaults to 'state,district'.">
	<cfargument name="types" type="string" default="state,district" hint="I allow you to choose which types of states you want with a comma delimited list. Possible options are state,district,territory. I default to 'state,district'.">
	
	<cfset var qStates = QueryNew('code,name')>
	<cfset var txtStates = "">

<cfsavecontent variable="txtStates"><!--- Text data of state (to be used to generate query) --->
qStates
code,name,type
AK|Alaska|state
AL|Alabama|state
AR|Arkansas|state
AS|American Samoa|territory
AZ|Arizona|state
CA|California|state
CO|Colorado|state
CT|Connecticut|state
DC|District of Columbia|district
DE|Delaware|state
FL|Florida|state
FM|Federated States of Micronesia|territory
GA|Georgia|state
GU|Guam|territory
HI|Hawaii|state
IA|Iowa|state
ID|Idaho|state
IL|Illinois|state
IN|Indiana|state
KS|Kansas|state
KY|Kentucky|state
LA|Louisiana|state
MA|Massachusetts|state
MD|Maryland|state
ME|Maine|state
MH|Marshall Islands
MI|Michigan|state
MN|Minnesota|state
MO|Missouri|state
MP|Northern Mariana Islands|territory
MS|Mississippi|state
MT|Montana|state
NC|North Carolina|state
ND|North Dakota|state
NE|Nebraska|state
NH|New Hampshire|state
NJ|New Jersey|state
NM|New Mexico|state
NV|Nevada|state
NY|New York|state
OH|Ohio|state
OK|Oklahoma|state
OR|Oregon|state
PA|Pennsylvania|state
PW|Palau|territory
RI|Rhode Island|state
SC|South Carolina|state
SD|South Dakota|state
TN|Tennessee|state
TX|Texas|state
UT|Utah|state
VA|Virginia|state
VI|Virgin Islands|territory
VT|Vermont|state
WA|Washington|state
WI|Wisconsin|state
WV|West Virginia|state
WY|Wyoming|state
</cfsavecontent>
	<cfset qStates = querySim(txtStates)><!--- Create query from text file --->
	<cftry>
		<cfquery name="qStates" dbtype="query"><!--- filter and order query --->
		SELECT		code,name
		FROM		qStates
		<cfif Len(arguments.types)>
		WHERE		type IN ('#ListChangeDelims(arguments.types, "','")#')
		</cfif>
		ORDER BY	name
		</cfquery>
		<cfcatch>
		</cfcatch>
	</cftry>
	
	<cfreturn qStates>
</cffunction>

<cffunction name="getRandomNumber" access="public" returntype="numeric" output="no" hint="I return a random number.">
	<cfset var nRandomNumber = 0>
	
	<cfset nRandomNumber = Rand()>
	
	<!--- Convert to integer. --->
	<cfloop condition="1 EQ 1">
		 <cfif left(nRandomNumber,1) EQ 0 OR left(nRandomNumber,1) EQ ".">
 			<cfset nRandomNumber = Right(nRandomNumber,len(nRandomNumber) - 1)>
		<cfelse>
			<cfbreak>
 		</cfif>	
	</cfloop>

	<cfreturn nRandomNumber>
</cffunction>

<cffunction name="getDayEndingString" access="public" returntype="string" output="no" hint="Returns the ending string (st,nd,rd,th) for a given day">
	<cfargument name="day" required="yes" type="numeric">
	
	<cfscript>
		var cLetters = "";
		
		switch (arguments.day)
			{
				case "1": case "21": case "31":  cLetters = "st"; break;
				case "2": case "22": cLetters = "nd"; break;
				case "3": case "23": cLetters = "rd"; break;
				default: cLetters = "th";
			}
	</cfscript>
	
	<cfreturn cLetters>
</cffunction>

</cfcomponent>
