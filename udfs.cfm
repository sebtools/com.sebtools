<cfscript>
Variables.udfs = true;

if ( NOT StructKeyExists(variables,"getURL") ) {
	struct function getURL() {
		
		return StructCopy(URL);
	}
}

if ( NOT StructKeyExists(variables,"checkValidRemoteArgs") ) {
	/**
	 * I throw a 404 if a remote method is being caleld with an invalid argument signature.
	 */
	public function checkValidRemoteArgs() {
		var sArgs = 0;
		var sURL = getURL();

		//If the CFC is being called directly and has a method argument that points to a valid method
		if (
			GetBaseTemplatePath() EQ GetCurrentTemplatePath()
			AND
			StructKeyHasLen(sURL,"method")
			AND
			StructKeyExists(This,sURL.method)
		)  {

			if ( StructCount(Form) ) {
				sArgs = Form;
			} else {
				sArgs = StructCopy(sURL);
				StructDelete(sArgs,"method");
			}

			if ( NOT isValidArgs(sArgs,sURL.method) ) {
				cfheader(statusCode=404, statusText="Not Found");
				WriteOutput("Invalid Arguments");
				abort;
			}

		}
	}
}

if ( NOT StructKeyExists(variables,"da") ) {
	private void function da() {
		writeDump(Arguments);
		abort;
	}
}

if ( NOT StructKeyExists(variables,"getStructKeyWithDefault") ) {
	function getStructKeyWithDefault(
		required struct struct,
		required string key,
		default=""
	) {
		if ( StructKeyExists(Arguments.struct,Arguments.key) ) {
			return Arguments.struct[Arguments.key]
		} else {
			return Arguments.default;
		}
	}
}

if ( NOT StructKeyExists(Variables,"ListInCommon") ) {
	/**
	* Returns elements in list1 that are found in list2.
	* 
	* @param List1 Full list of delimited values.
	* @param List2 Delimited list of values you want to compare to List1.
	* @param Delim1 Delimiter used for List1. Default is ','.
	* @param Delim2 Delimiter used for List2. Default is ','.
	* @param Delim3 Delimiter to use for the list returned by the function. Default is ','.
	* @return The resulting list after comparing List1 and List2.
	*/
	public string function ListInCommon(
		required string List1,
		required string List2,
		string Delim1=",",
		string Delim2=",",
		string Delim3=","
	) {
		var ii = 0;

		//Cycle backwards so we can delete from list.
		for ( ii=ListLen(Arguments.List1, Arguments.Delim1); ii GTE 1; ii=ii-1 ) {
			if ( NOT ListFindNoCase(Arguments.List2, ListGetAt(Arguments.List1, ii, Arguments.Delim1), Arguments.Delim2) ) {
				Arguments.List1 = ListDeleteAt(Arguments.List1, ii);
			}
		}
		//Change delims if return delimiter isn't the same as the incoming list delimiter.
		if ( Arguments.Delim1 NEQ Arguments.Delim3 ) {
			Arguments.List1 = ListChangeDelims(Arguments.List1, Arguments.Delim3, Arguments.Delim1);
		}

		return Arguments.List1;
	}
}

if ( NOT StructKeyExists(Variables,"makeLink") ) {
	/**
	* Creates a link based on a given path and query string arguments.
	* 
	* @param Path The path to use for the link.
	* @param Args Query string arguments to include in the link. Default is an empty struct.
	* @return The resulting link.
	*/
	function makeLink(
		required string Path,
		required struct Args={}
	) {
		var result = Arguments.Path;

		if ( StructCount(Arguments.Args) ) {
			result = "#result#?#Struct2QueryString(Arguments.Args)#";
		}

		return result;
	}
}


if ( NOT StructKeyExists(Variables,"href") ) {
	/**
	* Returns a link to the current page with additional query string arguments.
	* 
	* @return A link to the current page with additional query string arguments.
	*/
	function href() {

		return 'href="#self(ArgumentCollection=Arguments)#"';
	}
}

if ( NOT StructKeyExists(Variables,"self") ) {
	/**
	* Returns a link to the current page with additional query string arguments.
	* 
	* @return A link to the current page with additional query string arguments.
	*/
	function self() {
		var sURL = QueryStringToStruct(CGI.QUERY_STRING);

		StructAppend(sURL, Arguments, true);

		return makeLink(CGI.SCRIPT_NAME, sURL);
	}
}

if ( NOT StructKeyExists(variables,"selflink") ) {
	/**
	* Returns an HTML link element with a href attribute pointing to the current page with additional query string arguments.
	* 
	* @param label The label for the link.
	* @param args Query string arguments to include in the link. Default is an empty struct.
	* @param activeclass The CSS class to apply to the link if it is currently active. Default is an empty string.
	* @return The resulting HTML link element.
	*/
	function selflink(string label, struct args={}, string activeclass="",atts={}) {
		var result = href(ArgumentCollection=args);
		var sURL = getURL();
		var isActive = false;
		var arg = "";
		var att = "";

		if ( StructKeyHasLen(Arguments,"activeclass") ) {
			isActive = true;
			for ( arg in args ) {
				if ( NOT ( StructKeyExists(sURL,arg) AND args[arg] EQ sURL[arg] ) ) {
					isActive = false;
				}
			}
			if ( isActive ) {
				result = '#result# class="#Arguments.activeclass#"';
			}
		}
		if ( StructCount(Arguments.atts) ) {
			for ( att in Arguments.atts ) {
				result = '#result# #LCase(att)#="#Arguments.atts[att]#"';
			}
		}
		result = '#result#>#Arguments.label#</a>';

		return result
	}
}

if ( NOT StructKeyExists(variables,"selflink_li") ) {
	/**
	* Returns an HTML list item with a link element pointing to the current page with additional query string arguments.
	* 
	* @param label (required) The label for the link.
	* @param args (optional) Query string arguments to include in the link. Default is an empty struct.
	* @param activeclass (optional) The CSS class to apply to the link if it is currently active. Default is an empty string.
	* @return The resulting HTML list item.
	*/
	function selflink_li(
		required string label,
		struct args={},
		string activeclass=""
	) {
		var sURL = getURL();
		var result = '<li';
		var isActive = false;
		var arg = "";

		if ( StructKeyHasLen(arguments, "activeclass") ) {
			isActive = true;
			for ( arg in arguments.args ) {
				if (
					NOT (
						StructKeyExists(sURL, arg)
						AND
						arguments.args[arg] EQ sURL[arg]
					)
				) {
					isActive = false;
					break;
				}
			}
			if ( isActive ) {
				result = '#result# class="#activeclass#"';
			}
		}
		result = '#result#><a #href(ArgumentCollection=args)#>#label#</a></li>';

		return result;
	}
}

if ( NOT StructKeyExists(variables,"isValidArgs") ) {
	/**
	* I check to see if the given arguments constitute a valid method signature for the given method.
	*/
	public boolean function isValidArgs(
		required struct args,
		required string method,
		component
	) {
		var sMeta = 0;
		var sArg = 0;

		//If no component is passed it, assume that we are checking in this one.
		if ( NOT StructKeyExists(Arguments,"Component") ) {
			Arguments.Component = Variables;
		}

		//Get the information about the given method.
		sMeta = getMetaData(Arguments.component[Arguments.method]);

		//If the method has no paramters, then the arguments must be valid.
		if ( StructKeyExists(sMeta,"Parameters") ) {
			for ( sArg in sMeta["Parameters"] ) {
				if ( StructKeyExists(Arguments.args,sArg["name"]) ) {
					//If arg exists, check type
					if ( StructKeyExists(sArg,"type") ) {
						if ( NOT isValid(sArg["type"],Arguments.args[sArg["name"]]) ) {
							return false;
						}
					}
				} else {
					//If arg doesn't exist, see if it is required
					if ( StructKeyExists(sArg,"required") AND sArg["required"] IS true ) {
						return false;
					}
				}
			}
		}

		//If no problems have been found then it is valid.
		return true;
	}
}

if ( NOT StructKeyExists(variables,"ListDeleteItem") ) {
	public string function ListDeleteItem(
		required string list,
		required string item
	) {
		var spot = ListFindNoCase(Arguments.list,Arguments.item);
		if ( spot ) {
			Arguments.list = ListDeleteAt(Arguments.list,spot);
		}

		return Arguments.list;
	}
}

if ( NOT StructKeyExists(variables,"ListToHTML") ) {
	/**
	 * I return a list as an HTML list.
	 */
	public string function ListToHTML(
		required string list,
		string delimiter=","
	) {
		var result = "";
		var aItems = 0;
		var ii = 0;

		if ( Len(Trim(Arguments.list)) ) {
			aItems = ListToArray(list,delimiter);
			result = "<ul>";
			for ( ii=1; ii LTE ArrayLen(aItems); ii++ ) {
				result = "#result#<li>#aItems[ii]#</li>";
			}

			result = "#result#</ul>";
		}

		return result;
	}
}

if ( NOT StructKeyExists(variables,"ListIntegers") ) {
	function ListIntegers(list) { return ReReplaceNoCase(ReReplaceNoCase(list,'[^0-9]',',','ALL'),',{2,}',',','ALL'); }
}

if ( NOT StructKeyExists(variables,"makeCompName") ) {
	function makeCompName(str) { return variables.Manager.makeCompName(str); }
}

if ( NOT StructKeyExists(variables,"QueryAddRowStruct") ) {
	function QueryAddRowStruct(query,struct) {
		var cols = Arguments.query.ColumnList;
		var col = "";

		QueryAddRow(query);

		for ( col in Arguments.struct ) {
			if ( ListFindNoCase(cols,col) ) {
				querySetCell(Arguments.query, col, Arguments.struct[col]);
			}
		}
	}
}

if ( false AND NOT StructKeyExists(variables,"QueryRowToStruct") ) {
	/**
	* Makes a row of a query into a structure.
	*
	* @param query      The query to work with.
	* @param row      Row number to check. Defaults to row 1.
	* @return Returns a structure.
	* @author Nathan Dintenfass (nathan@changemedia.com)
	* @version 1, December 11, 2001
	*/
	function QueryRowToStruct(query){
		//by default, do this to the first row of the query
		var row = 1;
		//a var for looping
		var ii = 1;
		//the cols to loop over
		var cols = listToArray(query.columnList);
		//the struct to return
		var stReturn = {};

		//if there is a second argument, use that for the row number
		if ( arrayLen(arguments) GT 1 ) {
			row = arguments[2];
		}
		//loop over the cols and build the struct from the query row
		for ( ii = 1; ii lte arraylen(cols); ii = ii + 1 ) {
			stReturn[cols[ii]] = query[cols[ii]][row];
		}

		//return the struct
		return stReturn;
	}
}

if ( NOT StructKeyExists(variables,"QueryToArray") ) {
	/**
	 * This turns a query into an array of structures.
	 */
	public array function QueryToArray(required query Data) {
		// Define the local scope.
		var LOCAL = StructNew();
		// Get the column names as an array.
		LOCAL.Columns = ListToArray( ARGUMENTS.Data.ColumnList );
		// Create an array that will hold the query equivalent.
		LOCAL.QueryArray = ArrayNew( 1 );
		// Loop over the query.
		for (LOCAL.RowIndex = 1 ; LOCAL.RowIndex LTE ARGUMENTS.Data.RecordCount ; LOCAL.RowIndex = (LOCAL.RowIndex + 1)){
			// Create a row structure.
			LOCAL.Row = StructNew();
			// Loop over the columns in this row.
			for (LOCAL.ColumnIndex = 1 ; LOCAL.ColumnIndex LTE ArrayLen( LOCAL.Columns ) ; LOCAL.ColumnIndex = (LOCAL.ColumnIndex + 1)){
				// Get a reference to the query column.
				LOCAL.ColumnName = LOCAL.Columns[ LOCAL.ColumnIndex ];
				// Store the query cell value into the struct by key.
				LOCAL.Row[ LOCAL.ColumnName ] = ARGUMENTS.Data[ LOCAL.ColumnName ][ LOCAL.RowIndex ];
			}
			// Add the structure to the query array.
			ArrayAppend( LOCAL.QueryArray, LOCAL.Row );
		}
		// Return the array equivalent.
		return( LOCAL.QueryArray );
	}
}

if ( NOT StructKeyExists(variables,"QueryStringToStruct") ) {
	/**
	 * I accept a URL query string and return it as a structure.
	 * @querystring I am the query string for which to parse.
	 */
	 public function QueryStringToStruct(required string querystring) {
		var aList = ListToArray(Arguments.querystring,"&");
		return aList.reduce(function(result,item,index){
			result[ListFirst(item,"=")] = ListRest(item,"=");
			return result;
		},{});
	 }
}

if ( NOT StructKeyExists(variables,"Struct2QueryString") ) {
	/**
	 * I accept a structure and return it as a URL query string.
	 * @struct I am the struct to turn into a query string.
	 */
	 public string function Struct2QueryString(required struct struct) {
		return Arguments.struct.reduce(function(result, key, value) {
				result = result?:"";
				return ListAppend(result,"#LCase(key)#=#URLEncodedFormat(value)#","&");
		},"");
	 }
}
if ( NOT StructKeyExists(variables,"StructCopyKeys") ) {
	function StructCopyKeys(
		required struct struct,
		string keys=""
	) {
		var sResult = {};
		var aKeys = 0;
		var key = "";

		if ( Len(Trim(Arguments.keys)) ) {
			aKeys = ListToArray(Arguments.keys);
			for ( key in aKeys ) {
				if ( StructKeyExists(Arguments.struct,key) ) {
					sResult[key] = Arguments.struct[key];
				}
			}
		} else {
			sResult = StructCopy(Arguments.struct);
		}

		return sResult;
	}
}

if ( NOT StructKeyExists(variables,"StructIncrement") ) {
	function StructIncrement(
		required struct struct,
		required string name
	) {
		Arguments.struct[Arguments.name] = ( StructKeyExists(Arguments.struct,Arguments.name) ? Arguments.struct[Arguments.name] + 1 : 0);
	}
}

if ( NOT StructKeyExists(variables,"StructKeyHasLen") ) {
	function StructKeyHasLen(struct,key){
		return booleanFormat( StructKeyExists(Arguments.struct,key) AND Len(Trim(Arguments.struct[key])) );
	}
}

if ( NOT StructKeyExists(variables,"StructKeyHasVal") ) {
	function StructKeyHasVal(struct,key){
		return booleanFormat( StructKeyExists(Arguments.struct,key) AND Val(Arguments.struct[key]) );
	}
}

if ( NOT StructKeyExists(variables,"TrimAll") ) {
	function TrimAll(str) {
		var wschars = "160,194";
		str = Trim(str);
		//Trim right
		while ( Len(str) AND ListFindNoCase(wschars,Asc(Right(str,1))) ) {
			if ( Len(str) GT 1 ) {
				str = Trim(Left(str,Len(str)-1));
			} else {
				return "";
			}
		}
		//Trim left
		while ( Len(str) AND ListFindNoCase(wschars,Asc(Left(str,1))) ) {
			if ( Len(str) GT 1 ) {
				str = Trim(Right(str,Len(str)-1));
			} else {
				return "";
			}
		}
		return str;
	}
}

if ( StructKeyExists(Variables, "ThisTag") ) {
	// Optional "returnvar" argument to put functions into the specified variable.
	if (structKeyExists(Attributes, "returnvar")) {
		if ( NOT structKeyExists(Caller, Attributes.returnvar) ) {
			Caller[Attributes.returnvar] = {};
		}
		scope = Caller[Attributes.returnvar];
	} else {
		// If no returnvar specified, then just put them in Variables scope on the calling page.
		scope = Caller;
	}
	for ( varname in variables ) {
		if ( isCustomFunction(Variables[varname]) AND NOT StructKeyExists(scope, varname) ) {
			scope[varname] = Variables[varname];
		}
	}
}

</cfscript>
