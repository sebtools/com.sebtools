<cfcomponent displayname="Capitalizer">
<cfscript>
public function init(required DataMgr) {

	Variables.DataMgr = Arguments.DataMgr;
	Variables.datasource = Variables.Datamgr.getDatasource();

	return This;
}

public string function fixCase(
	required string string,
	boolean forcefix="false"
) {
	var lcasewords = "for,of,the,a,an,of,or,and";
	var directions = "N,E,S,W,NE,SE,SW,NW,NNE,ENE,ESE,SSE,SSW,WSW,WNW,NNW";
	var word = "";
	var titlewords = TitleCaseList(string,"., ('");
	var result = "";

	// No work to do unless string is at least two characters.
	Arguments.string = Trim(Arguments.string);
	if ( Len(Arguments.string) LTE 1 ) {
		return UCase(Arguments.string);
	}

	// Only change if string is all one case, unless "forcefix" is true
	if ( Arguments.forcefix OR Compare(arguments.string,LCase(arguments.string)) EQ 0 OR Compare(arguments.string,UCase(arguments.string)) EQ 0 ) {
		for ( word in ListToArray(titlewords," ") ) {
			if ( ListFindNoCase(lcasewords,word) ) {
				// lower-case words that are always lower-case
				result = ListAppend(result,LCase(word)," ");
			} else if ( ListFindNoCase(directions,word) ) {
				// upper-case directions
				result = ListAppend(result,UCase(word)," ");
			} else if ( Len(word) gt 3 AND Left(word,2) eq "mc" ) {
				// Special capitalization for words starting with "mc"
				word = "Mc" & UCase(Mid(word,3,1)) & LCase(Mid(word,4,Len(word)-3));
				result = ListAppend(result,word," ");
			} else {
				// Keep the corrected case for everything else
				result = ListAppend(result,word," ");
			}
		}
		// Always capitalize the first letter
		if ( Len(result) GTE 2 ) {
			result = UCase(Mid(result,1,1)) & Mid(result,2,Len(result)-1);
		}
		result = ReReplace(result,"'S\b","'s","ALL");
	} else {
		result = Arguments.string;
	}

	return Trim(result);
}

public void function fixFieldCase(
	required string table,
	required string field,
	required string pkfields,
	boolean forcefix="false"
) {
	var qRecords = getSuspectRecords(ArgumentCollection=Arguments);
	var pkfield = "";
	var data = 0;
	var sRecord = 0;

	for ( sRecord in qRecords ) {
		data = {};
		for ( pkfield in ListToArray(Arguments.pkfields) ) {
			data[pkfield] = sRecord[pkfield];
		}
		data[Arguments.field] = fixCase(sRecord[Arguments.field],Arguments.forcefix);
		Variables.DataMgr.updateRecord(tablename=Arguments.table,data=data);
	}

}

public query function getSuspectRecords(
	required string table,
	required string field,
	required string pkfields
) {
	var qSuspectRecords = 0;
	var sArgs = Duplicate(Arguments);
	var FieldSQL = Variables.DataMgr.escape(Arguments.field);

	StructDelete(sArgs,"table");
	StructDelete(sArgs,"field");
	StructDelete(sArgs,"pkfields");
	sArgs["fieldlist"] = "#Arguments.field#,#Arguments.pkfields#";
	sArgs["tablename"] = Arguments.table;
	if ( NOT StructKeyExists(sArgs,"AdvSQL") ) {
		sArgs["AdvSQL"] = {};
	}
	if ( NOT StructKeyExists(sArgs.AdvSQL,"WHERE") ) {
		sArgs["AdvSQL"]["WHERE"] = "";
	}

	sArgs["AdvSQL"]["WHERE"] = "
		#sArgs.AdvSQL.WHERE#
	AND	(
				1 = 0
			OR	#Arguments.field# = UPPER(#FieldSQL#) COLLATE Latin1_General_BIN
			OR	#Arguments.field# = LOWER(#FieldSQL#) COLLATE Latin1_General_BIN
			OR	#Arguments.field# LIKE '% %'
			OR	#Arguments.field# = ( SUBSTRING(LOWER(#FieldSQL#), 1, 1) + SUBSTRING(UPPER(#FieldSQL#), 2, LEN(#FieldSQL#)-1) ) COLLATE Latin1_General_BIN
		)
	";

	qSuspectRecords = Variables.DataMgr.getRecords(ArgumentCollection=sArgs);

	return qSuspectRecords;
}

/**
 * Title cases all elements in a list.
 *
 * @param list 	 List to modify. (Required)
 * @param delimiters 	 Delimiters to use. Defaults to a space. (Optional)
 * @return Returns a string.
 * @author Adrian Lynch (adrian.l@thoughtbubble.net)
 * @version 1, November 3, 2003
 */
function TitleCaseList( list, delimiters ) {

	var returnString = "";
	var isFirstLetter = true;

	// Loop through each character in list
	for ( i = 1; i LTE Len( list ); i = i + 1 ) {

		// Check if character is a delimiter
		if ( Find( Mid(list, i, 1 ), delimiters, 1 ) ) {

			//	Add character to variable returnString unchanged
			returnString = returnString & Mid(list, i, 1 );
			isFirstLetter = true;

		} else {

			if ( isFirstLetter ) {

				// Uppercase
			 	returnString = returnString & UCase(Mid(list, i, 1 ) );
				isFirstLetter = false;

			} else {

				// Lowercase
				returnString = returnString & LCase(Mid(list, i, 1 ) );

			}

		}

	}

	return returnString;
}
</cfscript>
</cfcomponent>
