component extends="component" {
	public function init(
		required service,
		required Record,
		string fields="",
		numeric row="1",
		boolean useZeroVals="false"
	) {
		var oMe = initInternal(ArgumentCollection=Arguments);

		return oMe;
	}

	public function initInternal(
		required service,
		required Record,
		string fields="",
		numeric row="1",
		boolean useZeroVals="false"
	) {
		var key = "";
		var qRecord = 0;
		var sArgs = {};
		var err = "";


		// If a single length array is passed in, use that
		if ( isArray(Arguments.Record) AND ArrayLen(Arguments.Record) EQ 1 ) {
			Arguments.Record = Arguments.Record[1];
		}

		Variables.oService = Arguments.Service;
		Variables.sServiceInfo = Variables.oService.getMetaStruct();
		Variables.ObjectName = "#Variables.sServiceInfo.Method_Singular#Object";
		Variables.useZeroVals = Arguments.useZeroVals;

		// Use RecordObject that is passed in.
		if ( isObject(Arguments.Record) AND StructKeyExists(Arguments.Record,"loadFields") ) {
			return Arguments.Record.loadFields(Arguments.fields);
		} else if (
				isStruct(Arguments.Record)
			AND	StructKeyExists(Arguments.Record,Variables.ObjectName)
			AND	isObject(Arguments.Record[Variables.ObjectName])
			AND	StructKeyExists(Arguments.Record[Variables.ObjectName],"loadFields")
		) {
			return Arguments.Record[Variables.ObjectName].loadFields(Arguments.fields);
		}

		Variables.instance = {};
		Variables.sFields = Variables.oService.getFieldsStruct();
		Variables.sKeys = {};

		// If a primary key value is passed in, use that.
		if ( isSimpleValue(Arguments.Record) AND ListLen(Variables.sServiceInfo.pkfields) EQ 1 ) {
			sArgs = {};
			sArgs[Variables.sServiceInfo.pkfields] = Arguments.Record;
			sArgs["fieldlist"] = Arguments.fields;
			Arguments.Record = {};
			Arguments.Record[Variables.sServiceInfo.pkfields] = sArgs[Variables.sServiceInfo.pkfields];
			/*
			Arguments.Record = invoke(
				Variables.oService,
				variables.sServiceInfo.method_get,
				sArgs
			);
			*/
		}

		// If a query is passed in, convert it to a structure.
		if ( isQuery(Arguments.Record) ) {
			Arguments.Record = QueryRowToStruct(Arguments.Record,Arguments.row);
		}

		// If a struct is passed in, use that
		if ( isStruct(Arguments.Record) ) {
			for ( key in Arguments.Record ) {
				if ( Len(key) AND StructKeyExists(Arguments.Record,key) ) {
					Variables.instance[key] = Arguments.Record[key];
					if ( ListFindNoCase(Variables.sServiceInfo.pkfields,key) ) {
						Variables.sKeys[key] = Arguments.Record[key];
					}
				}
			}
		} else {
			err = "Record argument of RecordObject method must be a";
			if ( ListLen(Variables.sServiceInfo.pkfields) EQ 1 ) {
				err = "#err# primary key value,";
			}
			err = "#err# query or structure - or another RecordObject of the same type.";
			Variables.oService.throwError(err);
		}

		// Make sure all primary key values are stored internally
		if ( StructCount(Variables.sKeys) LT ListLen(Variables.sServiceInfo.pkfields) ) {
			sArgs = Duplicate(Variables.instance);
			sArgs.fieldlist = Variables.sServiceInfo.pkfields;
			qRecord = invoke(
				Variables.oService,
				Variables.sServiceInfo.method_get,
				sArgs
			);
			StructAppend(variables.sKeys,QueryRowToStruct(qRecord),true);
		}

		// If a fieldlist is passed in and only primary key values are initially loaded, load up the requested data.
		if ( StructCount(Variables.instance) EQ ListLen(Variables.sServiceInfo.pkfields) AND Len(Arguments.fields) ) {
			sArgs = Duplicate(Variables.instance);
			sArgs.fieldlist = Arguments.fields;
			for ( key in ListToArray(Arguments.fields) ) {
				if ( ListFindNoCase(StructKeyList(Variables.instance),key) ) {
					sArgs.fieldlist = ListDeleteAt(sArgs.fieldlist,ListFindNoCase(sArgs.fieldlist,key));
				}
			}
			if ( ListLen(sArgs.fieldlist) ) {
				qRecord = invoke(
					Variables.oService,
					Variables.sServiceInfo.method_get,
					sArgs
				);
				StructAppend(variables.instance,QueryRowToStruct(qRecord),true);
			}
		}

		This.loadFields(Arguments.Fields);

		return This;
	}

	public function dump() {
		return Duplicate(Variables.Instance);
	}

	public function get(required string field) {
		var result = "";
		var sArgs = 0;
		var sFields = 0;

		if ( NOT has(Arguments.field) ) {
  			throw(message="#Variables.sServiceInfo.label_Singular# does not have a property named #Arguments.field#.");
		}

		if (
			NOT StructKeyExists(Variables.instance,Arguments.field)
			OR
			(
				isSimpleValue(Variables.instance[Arguments.field])
				AND
				Variables.instance[Arguments.field] EQ 0
				AND
				NOT Variables.useZeroVals
			)
		) {
			sArgs = {};
			StructAppend(sArgs,Variables.sKeys);
			sArgs["field"] = Arguments.field;

			if ( isQueryable() ) {
				result = invoke(
					Variables.oService,
					"getTableFieldValue",
					sArgs
				);
			} else if ( StructKeyExists(Variables.oService,"getFieldsStruct") ) {
				sFields = Variables.oService.getFieldsStruct();
				if ( StructKeyExists(sFields[Arguments.Field],"Default") ) {
					result = sFields[Arguments.Field].Default;
				}
			}
			Variables.instance[Arguments.field] = result;
		}

		return Variables.instance[Arguments.field];
	}

	public function getInstance() {
		return Variables.Instance;
	}

	public function getVariables() {
		return Variables;
	}

	public boolean function has(required string field) {
		var FieldBase = "";

		if ( StructKeyExists(Variables.instance,Arguments.field) ) {
			return true;
		}

		if ( NOT StructKeyExists(Variables.sFields,Arguments.field) ) {
			FieldBase = ReReplaceNoCase(Arguments.field,"(File$)|(URL$)","");
			if ( NOT ( StructKeyExists(Variables.sFields,FieldBase) AND Variables.sFields[FieldBase].type EQ "file" ) ) {
				return false;
			}
		}

		return true;
	}

	public boolean function isNewRecord() {
		
		if ( NOT StructKeyExists(Variables,"isNew") ) {
			Variables.isNew = NOT ( Variables.oService.isUpdate(ArgumentCollection=Variables.Instance) );
		}

		return Variables.isNew;
	}

	public boolean function isValidRecord() {
		var result = true;

		try {
			validate(ArgumentCollection=Arguments);
		} catch (any e) {
			result = false;
		}

		return result;
	}

	public function loadFields(string fields="") {
		var Field = "";
		var LoaddedFields = StructKeyList(Variables.instance);
		var MissingFields = "";
		var sArgs = 0;
		var qRecord = 0;
		var ServiceFields = "";

		for ( Field in ListToArray(Arguments.fields) ) {
			if ( NOT ListFindNoCase(LoaddedFields,Field) ) {
				MissingFields = ListAppend(MissingFields,Field);
			}
		}

		// Ditch any fields that don't actually exist in the service
		if ( Len(MissingFields) ) {
			ServiceFields = Variables.oService.getFieldList();
			for ( Field in ListToArray(Arguments.fields) ) {
				if ( ListFindNoCase(MissingFields,Field) AND NOT ListFindNoCase(ServiceFields,Field) ) {
					MissingFields = ListDeleteAt(MissingFields,ListFindNoCase(MissingFields,Field));
				}
			}
		}

		if ( Len(MissingFields) ) {
			sArgs = {};
			StructAppend(sArgs,Variables.sKeys);
			sArgs["fieldlist"] = MissingFields;
			if ( isQueryable() ) {
				qRecord = invoke(
					Variables.oService,
					Variables.sServiceInfo.method_get,
					sArgs
				);
			}
			if ( isQuery(qRecord) AND qRecord.RecordCount ) {
				for ( Field in ListToArray(MissingFields) ) {
					if ( ListFindNoCase(qRecord.ColumnList,Field) ) {
						Variables.instance[Field] = qRecord[Field][1];
					}
				}
			} else {
				for ( Field in ListToArray(MissingFields) ) {
					get(Field);
				}
			}
		}

		return This;
	}

	public void function remove() {
		invoke(
			Variables.oService,
			Variables.sServiceInfo.method_remove,
			Variables.sKeys
		);
		
		StructClear(Variables.Instance);
		StructClear(Variables.sKeys);

	}

	public function save() {
		var id = 0;
		var sArgs = Duplicate(Arguments);

		StructAppend(sArgs,Variables.sKeys,true);

		StructAppend(sArgs,StructCopy(Variables.instance),false);

		StructAppend(variables.instance,Arguments,true);
		Variables.isNew = false;

		id = invoke(
			Variables.oService,
			Variables.sServiceInfo.method_save,
			sArgs
		);

		if ( StructKeyExists(variables.sServiceInfo,"arg_pk") ) {
			if ( isDefined("id") AND isSimpleValue(id) AND Len(Trim(id)) ) {
				Variables.sKeys[variables.sServiceInfo.arg_pk] = id;
			}
		}

		return This;
	}

	public function validate() {
		var sArgs = Duplicate(Variables.instance);

		StructAppend(sArgs,ArgumentCollection,true);

		sArgs = invoke(
			Variables.oService,
			Variables.sServiceInfo.method_validate,
			sArgs
		);

		return This;
	}

	/*
	* I check to see if I can query the Service component for data.
	*/
	private boolean function isQueryable() {
		var result = ( StructKeyExists(Variables,"sKeys") AND StructCount(Variables.sKeys) GT 0 );
		var key = "";

		if ( result ) {
			for ( key in Variables.sKeys ) {
				if ( NOT ( StructKeyExists(Variables.sKeys,key) AND Len(Variables.sKeys[key]) ) ) {
					return false;
				}
			}
		}

		return result;
	}

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
		var sReturn = {};
		//if there is a second argument, use that for the row number
		if( ArrayLen(arguments) GT 1 )
			row = arguments[2];
		//loop over the cols and build the struct from the query row
		for( ii = 1; ii LTE ArrayLen(cols); ii++ ){
			sReturn[cols[ii]] = query[cols[ii]][row];
		}
		//return the struct
		return sReturn;
	}
}
