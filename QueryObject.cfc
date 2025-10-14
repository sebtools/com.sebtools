<cfcomponent extends="component">

	<cfscript>
	public function init(
		required query query,
		array aColumns=[],
		struct sLabels="#{}#"
	) {
		
		initInternal(ArgumentCollection=Arguments);

		if ( ArrayLen(Arguments.aColumns) ) {
			StructDelete(Variables,"aColumns");
			setColumnsArray(Arguments.aColumns);
		} else {
			Variables.listorder = "";
			Variables.aColumns = [];
		}
		
	}

	public function addColumnDef(required string name, string label,boolean order="true") {

		if ( NOT StructKeyExists(Variables,"aColumns") ) {
			Variables.aColumns = [];
		}

		ArrayAppend(Variables.aColumns,Arguments);

		if ( Arguments.order ) {
			Variables.listorder = ListAppend(Variables.listorder,Arguments.name);
		}

	}

	/**
	* I get the label for a column
	*/
	public string function getColumnLabel(required string name) {
		//If this column ha a specified label, use it. Otherwise just return the column name itself.
		return ((StructKeyHasLen(Variables.sLabels,Arguments.name)) ? Variables.sLabels[Arguments.name] : Arguments.name);
	}

	public array function getColumnsArray(boolean unlisted="true") {

		var aResults = [];
		
		if ( ArrayLen(Variables.aColumns) ) {
			for ( col in Variables.aColumns ) {
				if (
					NOT (
						StructKeyHasLen(col,"name")
						AND
						col["name"] NEQ "NULL"
					)
					OR
					Variables.query.keyexists(col.name)
				) {
					//aResults = addColumnToArray(aResults,col.name);
					ArrayAppend(aResults,col);
				}
			}
		} else if ( ListLen(Variables.listorder) ) {
			for ( col in ListToArray(Variables.listorder) ) {
				if ( Variables.query.keyexists(col) ) {
					//aResults = addColumnToArray(aResults,col);
					ArrayAppend(aResults,{name=col});
				}
			}
		}

		//Output the rest of the columns if requested or if no listorder exists
		if ( Arguments.unlisted OR NOT Len(Variables.listorder) ) {
			for ( col in ListToArray(Variables.query.ColumnList) ) {
				//Only output columns that haven't been included yet
				if ( NOT ListFindNoCase(Variables.listorder,col) ) {
					//aResults = addColumnToArray(aResults,col);
					ArrayAppend(aResults,{name=col});
				}
			}
		}

		return aResults;
	}

	public string function getHTMLTable(boolean unlisted="false") {
		var aColumns = getColumnsArray(Arguments.unlisted);
		var r = '<table>';
		var col = 0;
		var row = 0;
		var sCol = 0;

			r &= '<tr>';

			for ( col=1; col LTE ArrayLen(aColumns); col++ ) {
				sCol = aColumns[col];
				
				r &= '<th>#sCol["label"]#</th>';
			}
			r &= '</tr>';

			for ( sRow in Variables.query ) {
				row++;
				r &= '<tr>';
				for ( col=1; col LTE ArrayLen(aColumns); col++ ) {
					sCol = aColumns[col];
					r &= '<td>';
					r &= '#sRow[sCol["name"]]#';
					r &= '</td>';
				}
				r &= '</tr>';
			}


		r &= '</table>'


		return r;
	}

	public query function getQuery() {

		return Variables.query;		
	}

	public function makeCell(
		required oSpreadsheet,
		required struct sCol,
		required struct sRow,
		required numeric col,
		required numeric row
	) {

		//Get cell value
		if ( NOT StructKeyExists(Arguments,"value") ) {
			if ( StructKeyExists(sCol,"value") ) {
				Arguments["value"] = sCol["value"];
			} else if ( StructKeyHasLen(sCol,"name") AND sCol["name"] NEQ "NULL" ) {
				Arguments["value"] = sRow[sCol["name"]];
			} else {
				Arguments["value"] = "";
			}
		}

		if ( Len(Arguments["value"]) AND isDate(Arguments["value"]) ) {
			Arguments["value"] = Date2ExcelDate(Arguments["value"]);
		}

		if ( StructKeyHasLen(sCol,"formula") ) {
			SpreadsheetSetCellFormula(oSpreadsheet, sCol["formula"], row, col);
		} else if ( Len(Arguments["value"]) ) {
			SpreadsheetSetCellValue(oSpreadsheet, Arguments["value"], row, col);
		}

		if ( StructKeyExists(sCol,"format") ) {
			SpreadsheetFormatCell(oSpreadsheet, sCol["format"], row, col)
		}

	}

	public function makeSheet(
		required string name,
		oSpreadsheet,
		boolean unlisted="false",
		boolean freezeTopRow="true",
		boolean autofilter="false"
	) {
		var aColumns = getColumnsArray(Arguments.unlisted);
		var sCol = 0;
		var sRow = 0;
		var col = 0;
		var row = 0;

		//ColdFusion spreadsheet requires making a sheet when creating a file, so a conditional
		if ( StructKeyExists(Arguments,"oSpreadsheet") ) {
			SpreadsheetCreateSheet(oSpreadsheet, Arguments.name)
			SpreadsheetSetActiveSheet(oSpreadsheet, Arguments.name);
		} else {
			Arguments.oSpreadsheet = SpreadsheetNew(Arguments.name,true);
		}

		//Create columns
		for ( col=1; col LTE ArrayLen(aColumns); col++ ) {
			sCol = aColumns[col];
			row = 1;
			//Set header row
			SpreadsheetSetCellValue(oSpreadsheet, sCol["label"], row, col);

			SpreadsheetFormatCell(oSpreadsheet, {bold=true}, row, col);

			//Create data rows for this column
			for ( sRow in Variables.query ) {
				row++;

				makeCell(oSpreadsheet,sCol,sRow,col,row);

			}
		}

		//Freeze first row
		if ( Arguments.freezeTopRow ) {
			SpreadsheetAddFreezePane(oSpreadsheet, 0, 1);
		}

		if ( Arguments.autofilter ) {
			SpreadSheetAddAutofilter(oSpreadsheet,"A1:#getExcelColumn(ArrayLen(aColumns))##Variables.query.RecordCount+1#");
		}

		return oSpreadsheet;
	}

	public function setColumnsArray(required array array) {

		Variables.listorder = "";
		
		for ( var sCol in array) {
			//Can either be a key value pair of column name and label or individual keys of "name" and "label"

			if ( isSimpleValue(sCol) AND ListLen(sCol,"=") EQ 1 ) {
				addColumnDef(
					sCol,
					sCol
				);
			} else if ( isSimpleValue(sCol) AND ListLen(sCol,"=") EQ 2 ) {
				addColumnDef(
					ListFirst(sCol,"="),
					ListLast(sCol,"=")
				);
			} else if ( isStruct(sCol) ) {
				addColumnDef(ArgumentCollection=sCol);
			} else {
				throw("keys must either be a simple column name, a key/value pair, or a struct");
			}

		}

	}

	/**
	* I set the label for the specific column
	*/
	public function setColumnLabel(required string name,required string label) {
		Variables.sLabels[Arguments.name] = Arguments.label;
	}

	/**
	* I column labels using a struct of name to label pairs. Overwrites passed in values, but leaves other existing values.
	*/
	public function setColumnLabels(required struct sLabels) {
		StructAppend(Variables.sLabels,Arguments.sLabels,true);
	}

	/**
	* I set the order of the columns for the getColumnsArray function
	*/
	public function setColumnOrder(required string list) {
		Variables.listorder = Arguments.list;
	}

	/**
	* Converts a ColdFusion date to an Excel date format.
	* 
	* @param cfDate - The ColdFusion date to convert
	* @return - The equivalent Excel date as a number
	*/
	function Date2ExcelDate(cfDate) {
		// Base date for Excel (January 1, 1900)
		var excelBaseDate = createDate(1900, 1, 1);
		
		// Check if cfDate has no date portion (i.e., is only a time)
		if ( DateFormat(cfDate, "yyyy-MM-dd") == "1899-12-30" ) {
			// If only a time, convert directly to Excel's fractional day
			return hour(cfDate) / 24 + minute(cfDate) / 1440 + second(cfDate) / 86400;
		} else {
			// If cfDate has a date, calculate the day difference plus Excel adjustment (2 days to account for Excel's leap year bug for 1900)
			return DateDiff("d", excelBaseDate, cfDate) + 2;
		}
	}
	/*
	private array function addColumnToArray(required array array, required string col) {
		ArrayAppend(
			array,
			{
				"name":col,
				"label":getColumnLabel(col)
			}
		);
		
		return array;
	}
	*/

	/**
	* I get the letter for the associated column in Excel (written with help of ChatGPT)
	*/
	private string function getExcelColumn(required numeric number) {
		var result = "";
		var remainder = 0;

		while ( number > 0 ) {
			// Get the remainder for the current position (1-based index, hence the -1)
			remainder = (number - 1) % 26;
			// Convert remainder to corresponding letter
			result = chr(65 + remainder) & result;
			// Update the interval for the next loop (reduce by base 26)
			number = int((number - 1) / 26);
		}

		return result;
	}

</cfscript>


</cfcomponent>