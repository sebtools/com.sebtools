<!--- 1.0 Beta 3 (Build 36) --->
<!--- Last Updated: 2014-07-21 --->
<!--- Information: http://www.bryantwebconsulting.com/docs/com-sebtools/manager.cfm?version=Build%2012 --->
<cfcomponent output="false" extends="component">

<cfscript>
public function init(
	DataMgr,
	FileMgr,
	CFIMAGE,
	string wysiwyg="FCKeditor",
	string RootURL="",
	string RootPath="",
	Observer
) {
	var arg = "";
	var sTemp = {};

	// Set Variables from Arguments
	for ( arg in Arguments ) {
		if ( Len(Trim(arg)) AND StructKeyExists(Arguments,arg) ) {
			if ( NOT StructKeyExists(Variables,arg) ) {
				Variables[arg] = Arguments[arg];
			}
			if ( isObject(Arguments[arg]) AND NOT StructKeyExists(This,arg) ) {
				This[arg] = Arguments[arg];
			}
		}
	}

	if ( NOT StructKeyExists(Variables,"DataMgr") ) {
		if ( FileExists("#getDirectoryFromPath(getCurrentTemplatePath())#DataMgr.cfc") ) {
			Variables.DataMgr = CreateObject("component","DataMgr").init(ArgumentCollection=Arguments);
			This.DataMgr = Variables.DataMgr;
		} else {
			throw(message="Manager.cfc init() requires DataMgr.",type="Manager");
		}
	}
	if ( NOT StructKeyExists(Variables,"FileMgr") ) {
		if ( FileExists("#getDirectoryFromPath(getCurrentTemplatePath())#FileMgr.cfc") ) {
			if ( NOT StructKeyExists(Arguments,"UploadURL") ) {
				Arguments.UploadURL = "/f/";
			}
			if ( NOT StructKeyExists(Arguments,"UploadPath") ) {
				Arguments.UploadPath = ExpandPath(Arguments.UploadURL);
			}
			Variables.FileMgr = CreateObject("component","FileMgr").init(ArgumentCollection=Arguments);
			This.FileMgr = Variables.FileMgr;
		} else {
			throw(message="Manager.cfc init() requires FileMgr.",type="Manager");
		}
	}

	if (
		NOT StructKeyExists(Variables,"CFIMAGE")
		AND
		FileExists("#getDirectoryFromPath(getCurrentTemplatePath())#cfimagecfc.cfc")
	) {
		Variables.CFIMAGE = CreateObject("component","cfimagecfc").init();
		This.CFIMAGE = Variables.CFIMAGE;
	}
	if (
		NOT StructKeyExists(Variables,"Pluralizer")
		AND
		FileExists("#getDirectoryFromPath(getCurrentTemplatePath())#Pluralizer.cfc")
	) {
		Variables.Pluralizer = CreateObject("component","Pluralizer").init();
		This.Pluralizer = Variables.Pluralizer;
	}

	Variables.datasource = this.DataMgr.getDatasource();
	Variables.cachedata = {};
	Variables.sMetaData = {};
	Variables.UUID = CreateUUID();

	getTypesXml();
	loadTypesStruct();

	Variables.FileTypes = ArrayToList(GetValueArray(Variables.xTypes,"//type[@lcase_isfiletype='true']/@name"));
	Variables.TypeNames = ArrayToList(GetValueArray(Variables.xTypes,"//type/@name"));

	Variables.sSecurityPermissions = {};
	Variables.sTypesData = {};

	return This;
}

public string function getRootPath() {
	return Variables.RootPath;
}

public string function getRootURL() {
	return Variables.RootURL;
}

public function getTypeData(
	required string type,
	string transformer
) {
	var axTypes = 0;
	var key = makeTypeDataKey(ArgumentCollection=Arguments);
	var result = 0;

	if ( StructKeyExists(Variables.sTypes,key) ) {
		result = Variables.sTypes[key];
	} else if ( StructKeyExists(Variables.sTypesData,key) ) {
		result = Variables.sTypesData[key];
	} else {
		axTypes = getTypes(ArgumentCollection=Arguments);
		if ( ArrayLen(axTypes) EQ 1 ) {
			result = axTypes[1].XmlAttributes;
			Variables.sTypesData[key] = result;
		} else {
			result = {};
		}
	}

	return result;
}

public function getTypes(
	required string type,
	string transformer
) {
	var axResults = [];

	if ( Len(Trim(Arguments.type)) AND ListFindNoCase(Variables.TypeNames,Arguments.type) ) {
		if ( StructKeyExists(Arguments,"transformer") AND Len(Trim(Arguments.transformer)) ) {
			axResults = XmlSearch(xTypes,"//type[@lcase_name='#LCase(Arguments.type)#']/transform[@lcase_name='#LCase(Arguments.transformer)#']");
		} else {
			axResults = XmlSearch(xTypes,"//type[@lcase_name='#LCase(Arguments.type)#']");
		}
	}

	return axResults;
}

public function getTypesXml() {
	var xRawTypes = 0;
	var xAllTypes = 0;
	var ii = 0;
	var key = 0;

	if ( NOT StructKeyExists(Variables,"xTypes") ) {
		xRawTypes = XmlParse(types());
		xAllTypes = XmlSearch(xRawTypes,"//*");
		for ( ii=1; ii LTE ArrayLen(xAllTypes); ii++ ) {
			for ( key in xAllTypes[ii].XmlAttributes ) {
				xAllTypes[ii].XmlAttributes["lcase_#LCase(key)#"] = LCase(xAllTypes[ii].XmlAttributes[key]);
			}
		}
		Variables.xTypes = xRawTypes;
	}

	return Variables.xTypes;
}

public function loadTypesStruct() {
	var type_index = 0;
	var transformer_index = 0;
	var xType = 0;
	var xTransformer = 0;
	var type_key = "";
	var transformer_key = "";

	Variables.sTypes = {};

	for ( type_index=1; type_index LTE ArrayLen(Variables.xTypes.types.type); type_index++ ) {
		xType = Variables.xTypes.types.type[type_index];
		type_key = xType.XmlAttributes["lcase_name"];
		Variables.sTypes[type_key] = xType.XmlAttributes;
		if ( StructKeyExists(xType,"transform") ) {
			for ( transformer_index=1; transformer_index LTE ArrayLen(xType.transform); transformer_index++ ) {
				xTransformer = xType.transform[transformer_index];
				transformer_key = type_key & ":" & xTransformer.XmlAttributes["lcase_name"];
				Variables.sTypes[transformer_key] = xTransformer.XmlAttributes;
				StructAppend(Variables.sTypes[transformer_key],xType.XmlAttributes,"no");
			}
		}
	}

}

public function adjustImage(
	required string tablename,
	required string fieldname,
	required string filename
) {
	var sFields = getFieldsStruct(Arguments.tablename);
	var sField = sFields[Arguments.fieldname];
	var path = Variables.FileMgr.getFilePath(Arguments.filename,sField.Folder);

	var myImage = 0;
	var width = 0;
	var height = 0;

	if ( FileExists(path) AND StructKeyExists(Variables,"CFIMAGE") ) {
		// Resize if a size limitation exists
		if (
				( StructKeyExists(sField,"MaxWidth") AND isNumeric(sField.MaxWidth) AND sField.MaxWidth GT 0 )
			OR	( StructKeyExists(sField,"MaxHeight") AND isNumeric(sField.MaxHeight) AND sField.MaxHeight GT 0 )
			OR	( StructKeyExists(sField,"MaxSmallSide") AND isNumeric(sField.MaxSmallSide) AND sField.MaxSmallSide GT 0 )
		) {
			// Get image
			myImage = Variables.CFIMAGE.read(source=path);

			// Get height and width for scale to fit
			width = getWidth(sField,myImage);
			height = getHeight(sField,myImage);

			if ( width LT myImage.width OR height LT myImage.height ) {
				// Scale image to fit
				Variables.CFIMAGE.scaleToFit(
					source=path,
					quality=sField.quality,
					width=width,
					height=height
				);
			}
		}
	}

}

private struct function adjustImages(
	required string tablename,
	required struct data
) {
	var aFields = getFileFields(tablename=Arguments.tablename,data=Arguments.data);
	var sFields = getFieldsStruct(tablename=Arguments.tablename);
	var ii = 0;
	var sData = Duplicate(Arguments.data);
	var myImage = 0;

	// If cfimage is available and image is passed in, fit any images into box
	if ( StructKeyExists(Variables,"CFIMAGE") AND ArrayLen(aFields) ) {
		for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
			// Make sure images are big enough
			if (
					StructKeyExists(sData,aFields[ii].name)
				AND	( StructKeyExists(aFields[ii],"type") AND aFields[ii].type EQ "image")
				AND	( StructKeyExists(aFields[ii],"Folder") AND Len(aFields[ii].Folder) )
				AND (
							( StructKeyExists(aFields[ii],"MinBox") AND isNumeric(aFields[ii].MinBox) AND aFields[ii].MinBox GT 0 )
					)
				AND	FileExists(Variables.FileMgr.getFilePath(sData[aFields[ii].name],aFields[ii].Folder))
			) {
				// Get image
				myImage = Variables.CFIMAGE.read(source=Variables.FileMgr.getFilePath(sData[aFields[ii].name],aFields[ii].Folder));

				if (
					(
						myImage.width LT aFields[ii].MinBox
					)
					OR
					(
						myImage.height LT aFields[ii].MinBox
					)
				) {
					throw(message="Width and height of #aFields[ii].label# must both be at least #aFields[ii].MinBox#.",type="Manager");
				}
			}
		}
		// Copy/Resize thumbnail images
		for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
			// If this is a thumb with a folder
			if (
					isThumbField(Arguments.tablename,aFields[ii].name)
				AND	StructKeyExists(sData,aFields[ii].original)
				AND	isSimpleValue(sData[aFields[ii].original])
				AND	Len(sData[aFields[ii].original])
			) {
				makeThumb(Arguments.tablename,aFields[ii].name,sData[aFields[ii].original]);

				// Add to data
				sData[aFields[ii].name] = sData[aFields[ii].original];
			}
		}
		// Fit any images into box
		for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
			// If: image is in args and has folder and size limitation and file exists
			if (
					( StructKeyExists(sData,aFields[ii].name) AND isSimpleValue(sData[aFields[ii].name]) AND Len(sData[aFields[ii].name]) )
				AND	( StructKeyExists(aFields[ii],"type") AND aFields[ii].type EQ "image")
				AND	( StructKeyExists(aFields[ii],"Folder") AND Len(aFields[ii].Folder) )
			) {
				adjustImage(Arguments.tablename,aFields[ii].name,sData[aFields[ii].name]);
			}
		}
	}

	return sData;
}

public function getDataMgr() {
	return This.DataMgr;
}

private string function getDataMgrGetRecordsArgs() {
	
	if ( NOT StructKeyExists(Variables,"DataMgrGetRecordsArgs") ) {
		Variables.DataMgrGetRecordsArgs = getArgumentsList(Variables.DataMgr.getRecords);
	}

	return Variables.DataMgrGetRecordsArgs;
}

private string function getDataMgrSaveRecordArgs() {

	if ( NOT StructKeyExists(Variables,"DataMgrSaveRecordArgs") ) {
		Variables.DataMgrSaveRecordArgs = getArgumentsList(Variables.DataMgr.saveRecord);
	}

	return Variables.DataMgrSaveRecordArgs;
}

public function getFileMgr() {
	return This.FileMgr;
}

public function getMetaStruct(string tablename) {
	var result = 0;

	if (
		StructKeyExists(Arguments,"tablename")
		AND
		StructKeyExists(Variables.sMetaData,Arguments.tablename)
	) {
		result = Variables.sMetaData[Arguments.tablename];
	} else {
		result = Variables.sMetaData;
	}

	return result;
}

/*
public function getMetaXML() {
	return Variables.xMetaData;
}
*/

public string function getPrimaryKeyFields(
	required string tablename,
	xDef
) {
	var aPKFields = 0;
	var ii = 0;
	var result = "";

	if ( StructKeyExists(Arguments,"xDef") ) {
		aPKFields = XmlSearch(Arguments.xDef,"//table[@name='#Arguments.tablename#']/field[starts-with(@type,'pk:')]");
		for ( ii=1; ii LTE ArrayLen(aPKFields); ii++ ) {
			result = ListAppend(result,aPKFields[ii].XmlAttributes.name);
		}
	}

	if ( NOT Len(result) ) {
		aPKFields = Variables.DataMgr.getPKFields(Arguments.tablename);
		for ( ii=1; ii LTE ArrayLen(aPKFields); ii++ ) {
			result = ListAppend(result,aPKFields[ii].ColumnName);
		}
	}

	return result;
}

public string function getPrimaryKeyType(
	required string tablename,
	xDef
) {
	var result = "";
	var sTableMeta = sMetaData[Arguments.tablename];
	var sFields = getFieldsstruct(Arguments.tablename);
	var sField = 0;
	var pkfield = "";
	var ii = 0;

	if ( StructKeyExists(sTableMeta,"pkfield") ) {
		pkfield = sTableMeta.pkfield;
	} else {
		for ( ii=1; ii LTE ArrayLen(sTableMeta.fields); ii++ ) {
			if ( StructKeyExists(sTableMeta.fields[ii],"type") AND ListFirst(sTableMeta.fields[ii].type,":") EQ "pk" ) {
				pkfield = ListAppend(pkfield,sTableMeta.fields[ii].name);
			}
		}
	}

	if ( NOT Len(pkfield) ) {
		result = "complex";
	} else if ( ListLen(pkfield) EQ 1 ) {
		sField = sFields[pkfield];
		result = ListLast(sField.type,":");
	} else {
		result = "complex";
	}

	return result;
}

private string function getUniversalTableName(
	required string entity,
	required string tablename
) {
	var qRecords = 0;
	var sRecord = 0;
	var result = "";

	/*
	Make sure we have a table to store this in.
	This is essential that this has permanent storage.
	Currently this is the only scenario under which Manager creates a table or stores its own data in the database
	*/
	if ( NOT Variables.DataMgr.hasTable("mgrUniversals") ) {
		Variables.DataMgr.loadXml(
			'
				<tables>
					<table name="mgrUniversals">
						<field ColumnName="entity" CF_DataType="CF_SQL_VARCHAR" Length="250" PrimaryKey="true" />
						<field ColumnName="tablename" CF_DataType="CF_SQL_VARCHAR" Length="250" />
					</table>
				</tables>
			',
			true,
			true
		);
	}

	/*
	Load data from the database the first time this is used
	*/
	if ( NOT StructKeyExists(Variables,"sUniversals") ) {
		Variables.sUniversals = {};
		qRecords = Variables.DataMgr.getRecords(tablename="mgrUniversals");
		for ( sRecord in qRecords ) {
			Variables.sUniversals[sRecord["entity"]] = sRecord["tablename"];
		}
	}
	if ( NOT StructKeyExists(Variables.sUniversals,Arguments.entity) ) {
		Variables.DataMgr.saveRecord("mgrUniversals",Arguments);
		Variables.sUniversals[Arguments["entity"]] = Arguments["tablename"];
	}

	return Variables.sUniversals[Arguments.entity];
}

public string function isThumbField(
	required string tablename,
	required string fieldname
) {
	var sFields = getFieldsStruct(Arguments.tablename);
	var sField = sFields[Arguments.fieldname];
	var result = false;

	if (
			( StructKeyExists(sField,"type") AND sField.type EQ "thumb")
		AND	( StructKeyExists(sField,"Folder") AND Len(sField.Folder) )
		AND	(
					StructKeyExists(sField,"original")
				AND	StructKeyExists(sFields,sField.original)
			)
	) {
		result = true;
	}
	
	return result;
}

public function makeThumb(
	required string tablename,
	required string fieldname,
	required string filename
) {
	var sFields = getFieldsStruct(Arguments.tablename);
	var sField = sFields[Arguments.fieldname];

	var myImage = 0;
	var width = 0;
	var height = 0;

	// Copy file if original file exists --->
	var file_original = Variables.FileMgr.getFilePath(Arguments.filename,sFields[sField.original].Folder);
	var file_thumb = Variables.FileMgr.getFilePath(Arguments.filename,sField.Folder);

	if ( FileExists(file_original) ) {
		// Copy original image to thumb
		FileCopy(file_original,file_thumb);

		// Resize if a size limitation exists --->
		adjustImage(Arguments.tablename,Arguments.fieldname,Arguments.filename);
	}

}

public void function makeThumbs(
	required string tablename,
	string fieldname
) {
	var aFields = 0;
	var ii = 0;

	if ( StructKeyExists(Arguments,"fieldname") ) {
		makeThumbsInternal(ArgumentCollection=Arguments);
	} else {
		aFields = getFileFields(tablename=Arguments.tablename);
		for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
			if ( isThumbField(Arguments.tablename,aFields[ii].name) ) {
				makeThumbsInternal(Arguments.tablename,aFields[ii].name);
			}
		}
	}

	notifyEvent("makeThumbs",Arguments);

}

private void function makeThumbsInternal(
	required string tablename,
	required string fieldname
) {
	var sFields = 0;
	var sField = 0;
	var qRecords = 0;
	var sRecord = 0;
	var aFilters = 0;
	var sData = 0;
	var pkfield = "";

	//Only take action if the given field is a valid thumb field
	if ( isThumbField(Arguments.tablename,Arguments.fieldname) ) {
		sFields = getFieldsStruct(Arguments.tablename);
		sField = sFields[Arguments.fieldname];
		aFilters = [];

		// Only take action if table has some records with originals and no thumbnails
		ArrayAppend(aFilters,StructFromArgs(field=Arguments.fieldname,operator="=",value=""));
		ArrayAppend(aFilters,StructFromArgs(field=sField.original,operator="<>",value=""));
		qRecords = Variables.DataMgr.getRecords(
			tablename=Arguments.tablename,
			fieldlist="#getPrimaryKeyFields(Arguments.tablename)#,#Arguments.fieldname#,#sField.original#",
			filters=aFilters
		);

		for ( sRecord in qRecords ) {
			// Make thumbnail of original
			makeThumb(Arguments.tablename,Arguments.fieldname,sRecord[sField.original]);
			// Save data
			sData = {};
			sData[Arguments.fieldname] = sRecord[sField.original];
			for ( pkfield in ListToArray(getPrimaryKeyFields(Arguments.tablename)) ) {
				sData[pkfield] = sRecord[pkfield];
			}
			Variables.DataMgr.updateRecord(Arguments.tablename,sData);

		}
	}

}

public string function pluralize(required string string) {
	var result = Arguments.string;

	if ( Len(Trim(result)) ) {
		if ( StructKeyExists(Variables,"Pluralizer") ) {
			result = Variables.Pluralizer.pluralize(Arguments.string);
		}

		if ( result EQ Arguments.string ) {
			if ( Right(Arguments.string,1) EQ "s" ) {
				result = "#Arguments.string#es";
			} else {
				result = "#Arguments.string#s";
			}
		}
	}

	return result;
}

public function transformField(
	required struct field,
	string transformer=""
) {
	var sField = Arguments.field;
	var sType = 0;
	var att = "";
	var isListField = false;

	//If a transformer is present, adjust accordingly.
	if ( Len(Arguments.transformer) AND StructKeyExists(sField,"type") ) {
		sType = getTypeData(sField.type,Arguments.transformer);
		if ( StructCount(sType) ) {
			// Set all attributes
			for ( att in sType ) {
				if (
						att NEQ "name"
					AND	NOT ( Len(att) GT Len("lcase_") AND Left(att,Len("lcase_")) EQ "lcase_" )
					AND	NOT ( StructKeyExists(sField,att) AND Len(sField[att]) AND att NEQ "type" )
				) {
					sField[att] = sType[att];
				}
			}
			sType = getTypeData(sField.type);
			// Set all attributes
			if ( StructCount(sType) ) {
				for ( att in sType ) {
					if (
							att NEQ "name"
						AND	NOT ( Len(att) GT Len("lcase_") AND Left(att,Len("lcase_")) EQ "lcase_" )
						AND	NOT ( StructKeyExists(sField,att) AND Len(sField[att]) )
					) {
						sField[att] = sType[att];
					}
				}
			}
		} else {
			sField = {};
		}
	} else {
		if ( StructKeyExists(sField,"type") AND Len(Trim(sField.type)) ) {
			sType = getTypeData(sField.type);
			// Set all attributes
			if ( StructCount(sType) ) {
				for ( att in sType ) {
					if (
							att NEQ "name"
						AND	NOT ( Len(att) GT Len("lcase_") AND Left(att,Len("lcase_")) EQ "lcase_" )
						AND	NOT ( StructKeyExists(sField,att) AND Len(sField[att]) )
					) {
						sField[att] = sType[att];
					}
				}
			}
		}
	}

	// Default size shouldn't exceed 50
	if (
			StructKeyExists(sField,"Length")
		AND	isNumeric(sField.Length)
		AND	sField.Length GT 50
		AND	NOT StructKeyExists(sField,"size")
	) {
		sField["size"] = 50;
	}
	if ( StructKeyExists(sField,"Default") AND Arguments.transformer EQ "sebField" ) {
		sField["defaultValue"] = sField["Default"];
	}

	// Set values from attributes scoped for this transformer \
	if ( Len(Arguments.transformer) ) {
		for ( att in sField ) {
			if (
					ListLen(att,"_") EQ 2
				AND	ListFirst(att,"_") EQ Arguments.transformer
			) {
				sField[ListLast(att,"_")] = sField[att];
			}
		}
	}

	/*
	if ( Arguments.transformer EQ "sebColumn" ) {
		sField["dbfield"] = sField["name"];
		if ( NOT StructKeyExists(sField,"label") ) {
			sField["label"] = sField["name"];
		}
		if ( NOT StructKeyExists(sField,"header") ) {
			sField["header"] = sField["label"];
		}
	}
	*/

	isListField = ( StructKeyExists(sField,"relation") AND StructKeyExists(sField.relation,"type") AND isSimpleValue(sField.relation.type) AND sField.relation.type EQ "list" );

	if (
			StructKeyExists(Arguments,"transformer")
		AND	Arguments.transformer EQ "sebField"
	) {
		if ( isListField ) {
			sField.type="checkbox";
		/*
		} else if ( StructKeyExists(sField,"relation") ) {
			sField = {};
		*/
		}
	}

	// If field has attribute name matching transformer value with a value of "false", ditch field
	if (
		Len(Arguments.transformer)
		AND
		StructKeyExists(sField,Arguments.transformer)
		AND
		sField[Arguments.transformer] IS false
	) {
		sField = {};
	}

	return sField;
}

public array function getFieldsArray(
	required string tablename,
	string transformer=""
) {
	var aFields = getFieldsArrayInternal(transformer=Arguments.transformer,tablename=Arguments.tablename);
	var ii = 0;
	var sField = 0;

	for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
		if (
			(
					(
							Arguments.transformer EQ "sebField"
						OR	Arguments.transformer EQ "sebColumn"
					)
				AND	StructKeyExists(aFields[ii],"relation")
				AND	NOT (
							StructKeyExists(aFields[ii].relation,"type")
						AND	aFields[ii].relation.type EQ "list"
					)
			)
		) {// ( StructKeyExists(aFields[ii],"type") AND aFields[ii].type NEQ "relation" )
			ArrayDeleteAt(aFields,ii);
		} else if (
				(
						Arguments.transformer EQ "sebField"
					OR	Arguments.transformer EQ "sebColumn"
				)
			AND	(
						( StructKeyExists(aFields[ii],"type") AND ListFirst(aFields[ii].type,":") EQ "pk" )
					OR	( StructKeyExists(aFields[ii],"PrimaryKey") AND aFields[ii].PrimaryKey IS true )
				)
		) {
			ArrayDeleteAt(aFields,ii);
		} else if ( Arguments.transformer EQ "sebField" AND StructKeyExists(aFields[ii],"type") AND aFields[ii].type EQ "thumb" ) {
			ArrayDeleteAt(aFields,ii);
		} else if ( Arguments.transformer EQ "sebColumn" AND StructKeyExists(aFields[ii],"type") ) {
			// Sorter must always come first
			/*
			if ( aFields[ii].type EQ "Sorter" AND ii GT 1 ) {
				sField = Duplicate(aFields[ii]);
				ArrayDeleteAt(aFields,ii);
				ArrayPrepend(aFields,sField);
				ii = ArrayLen(aFields);
			*/
			if ( aFields[ii].type EQ "delete" ) {
				ArrayDeleteAt(aFields,ii);
			}
		}
	}

	for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
		if ( Arguments.transformer EQ "sebColumn" AND StructKeyExists(aFields[ii],"type") ) {
			sField = Duplicate(aFields[ii]);
			ArrayDeleteAt(aFields,ii);
			ArrayPrepend(aFields,sField);
		}
	}

	return aFields;
}

public array function getFieldsArrayInternal(
	string transformer="",
	required string tablename
) {
	var aRawFields = Duplicate(Variables.sMetaData[Arguments.tablename].fields);
	var aFields = [];
	var ii = 0;
	var sField = 0;

	for ( ii=1; ii LTE ArrayLen(aRawFields); ii++ ) {
		sField = transformField(aRawFields[ii],Arguments.transformer);
		if ( StructCount(sField) ) {
			ArrayAppend(aFields,sField);
		}
	}

	// For DataMgr, if a table has multiple pk:identity, none should increment
	if ( StructKeyExists(Arguments,"transformer") AND Arguments.transformer EQ "DataMgr" ) {
		aFields = alterDataMgrIncrements(aFields);
	}

	return aFields;
}

private boolean function hasOrdinalArgs(required struct Args) {
	var ii = 0;

	if ( NOT StructCount(Args) ) {
		return false;
	}

	for ( ii in Args ) {
		if ( NOT isNumeric(ii) ) {
			return false;
		}
	}

	return true;
}

/**
* @fieldlist A list of fields to return. If left blank, all fields will be returned.
*/
public query function getPKRecord(
	required string tablename,
	required struct data,
	string fieldlist=""
) {
	var sData = Arguments.data;
	var pkfields = 0;
	var ii = 0;
	var qRecord = QueryNew("none");
	var pklist = "";
	var sPKs = {};
	var sTable = {table=Arguments.tablename};

	pkfields = Variables.DataMgr.getPKFields(Arguments.tablename);

	if ( NOT ArrayLen(pkfields) ) {
		throw(message="getRecord can only be used against tables with at least one primary key field.",type="Manager");
	}

	// Make a list of pkfields
	for ( ii=1; ii LTE ArrayLen(pkfields); ii++ ) {
		pklist = ListAppend(pklist,pkfields[ii].ColumnName);
	}

	// Set argument names if not given by names
	if (
			hasOrdinalArgs(sData)
		AND	ArrayLen(sData) GTE ArrayLen(pkfields)
		AND NOT StructKeyExists(sData,pkfields[1].ColumnName)
	) {
		for ( ii=1; ii LTE ArrayLen(pkfields); ii++ ) {
			sData[pkfields[ii].ColumnName] = sData[ii];
		}
	}

	// Delete any Arguments that aren't simple and primary keys
	for ( ii in sData ) {
		if (
				(
							StructKeyExists(sData,ii)
						AND	isSimpleValue(sData[ii])
						AND	ListFindNoCase(pklist,ii)
						AND	Len(sData[ii])
					)
		) {
			sPKs[ii] = sData[ii];
		}
	}

	// If all pks are passed in, retrieve record
	if (
		ArrayLen(pkfields) GT 0
		AND
		StructCount(sData) GT 0
		AND
		ArrayLen(pkfields) EQ StructCount(sData)
	) {
		qRecord = Variables.DataMgr.getRecord(
			tablename=Arguments.tablename,
			data=sPKs,
			fieldlist=Arguments.fieldlist
		);
	}

	return qRecord;
}

public query function getRecord(
	required string tablename,
	required struct data
) {
	var qRecord = 0;

	Arguments.isGetRecord = true;

	Arguments = alterArgs(ArgumentCollection=Arguments);
	Arguments.data = makeNamedPKArgs(tablename=Arguments.tablename,data=Arguments.data);

	if ( NOT StructKeyExists(Arguments,"fieldlist") ) {
		Arguments.fieldlist = "";
	}

	qRecord = Variables.DataMgr.getRecord(ArgumentCollection=Arguments);

	return alterRecords(Arguments.tablename,qRecord);
}

public query function getRecords(
	required string tablename,
	required struct data
) {
	return alterRecords(Arguments.tablename,Variables.DataMgr.getRecords(ArgumentCollection=alterArgs(ArgumentCollection=Arguments)));
}

public array function getRecordsSQL(
	required string tablename,
	required struct data="#{}#"
) {
	return Variables.DataMgr.getRecordsSQL(ArgumentCollection=alterArgs(ArgumentCollection=Arguments));
}

public boolean function isRecordDeletable(
	required string tablename,
	struct data="#{}#",
	query query
) {
	var result = true;
	var qRecord = 0;
	var sMetaData = getMetaStruct();
	var sTableData = sMetaData[Arguments.tablename];
	var col = "";
	var negate = false;

	if ( StructKeyExists(Arguments,"query") ) {
		qRecord = Arguments.query;
	} else {
		qRecord = getRecord(tablename=Arguments.tablename,data=Arguments.data);
	}

	// Check "deletable" attribute/property of table
	if ( result IS true AND StructKeyExists(sTableData,"deletable") AND Len(sTableData.deletable) ) {
		if ( isBoolean(sTableData.deletable) ) {
			result = sTableData.deletable;
		} else {
			col = sTableData.deletable;
			if ( Left(sTableData.deletable,1) EQ "!" ) {
				col = ReplaceNoCase(col,"!",1);
				negate = true;
			}
			if ( ListFindNoCase(qRecord.ColumnList,col) ) {
				if ( isBoolean(qRecord[col][1]) ) {
					result = qRecord[col][1];
					if ( negate ) {
						result = NOT result;
					}
				}
			}
		}
	}

	// Check for no deletes for related records
	if ( result IS true ) {
		result = Variables.DataMgr.isDeletable(tablename=Arguments.tablename,data=Arguments.data,qRecord=qRecord);
	}

	return result;
}

public void function removeRecord(
	required string tablename,
	required struct data="#{}#"
) {
	var sData = limitPKArgs(Arguments.tablename,makeNamedPKArgs(Arguments.tablename,Arguments.data,"removeRecord"));
	var aFileFields = getFileFields(tablename=Arguments.tablename);
	var ii = 0;
	var qRecord = getRecord(tablename=Arguments.tablename,data=sData);
	var sRecord = 0;
	var conflicttables = Variables.DataMgr.getDeletionConflicts(tablename=Arguments.tablename,data=sData,qRecord=qRecord);
	var sCascadeDeletions = Variables.DataMgr.getCascadeDeletions(tablename=Arguments.tablename,data=sData,qRecord=qRecord);
	var qRecords = 0;
	var isLogicalDelete = Variables.DataMgr.isLogicalDeletion(Arguments.tablename);
	
	if ( qRecord.RecordCount EQ 1 ) {
		// ToDo: Handle conflicts from cascade
		if ( Len(conflicttables) ) {
			throw(
				message="You cannot delete a record in #Arguments.tablename# when associated records exist in #conflicttables#.",
				type="Manager",
				errorcode="NoDeletesWithRelated"
			);
		}

		// Delete any files
		for ( ii=1; ii LTE ArrayLen(aFileFields); ii++ ) {
			if (
					Len(qRecord[aFileFields[ii].name][1])
				AND	(
							(
									isLogicalDelete IS true
								AND	(
											StructKeyExists(aFileFields[ii],"onRecordDelete")
										AND	aFileFields[ii].onRecordDelete EQ "Delete"
									)
							)
						OR	(
									isLogicalDelete IS false
								AND	NOT (
											StructKeyExists(aFileFields[ii],"onRecordDelete")
										AND	aFileFields[ii].onRecordDelete EQ "Ignore"
									)
							)
					)
			) {
				Variables.FileMgr.deleteFile(qRecord[aFileFields[ii].name][1],aFileFields[ii].Folder);
			}
		}

		notifyEvent(
			"beforeRemove",
			{
				tablename="#Arguments.tablename#",
				action="beforeDelete",
				data="#Arguments.data#",
				Args="#Arguments#",
				method="deleteRecord"
			}
		);

		// Perform cascade deletes
		for ( ii in sCascadeDeletions ) {
			qRecords = Variables.DataMgr.getRecords(tablename=ii,data=sCascadeDeletions[ii],fieldlist=getPrimaryKeyFields(ii));
			for ( sRecord in qRecords ) {
				/*
				If Manager knows about the table, it should handle the deletion. Otherwise let DataMgr do it.
				(Manager needs to handle in case there are files to delete - if it doesn't know about then there aren't any)
				*/
				if ( StructKeyExists(Variables.sMetaData,ii) ) {
					removeRecord(tablename=ii,data=sRecord);
				} else {
					Variables.DataMgr.deleteRecord(tablename=ii,data=sRecord);
				}
			}
		}

		Variables.DataMgr.deleteRecord(Arguments.tablename,sData);

	}

	notifyEvent("removeRecord",Arguments);

}

public string function copyRecord(
	required string tablename,
	required struct data="#{}#",
	boolean CopyChildren,
	boolean CopyFiles="true"
) {
	var sData = Duplicate(Arguments.data);
	var aFileFields = getFileFields(tablename=Arguments.tablename);
	var qRecord = 0;
	var sRecord = 0;
	var ii = 0;
	var result = "";
	var path = "";
	var pkfields = getPrimaryKeyFields(Arguments.tablename);
	var table = "";
	var sChildren = 0;
	var qChildren = 0;
	var childpkfields = 0;
	var sFTables = 0;
	var sChild = 0;

	Arguments.OnExists = "insert";

	StructDelete(Arguments,"data");

	qRecord = getPKRecord(tablename=Arguments.tablename,data=sData,fieldlist=getFieldListFromArray(getFieldsArray(Arguments.tablename)));
	sRecord = QueryRowToStruct(qRecord);

	StructAppend(sData,sRecord,"no");

	// Copy any associated files
	if ( ArrayLen(aFileFields) AND Arguments.CopyFiles ) {
		for ( ii=1; ii LTE ArrayLen(aFileFields); ii++ ) {
			// If the file name is passed in (with a new value) then action has already been taken against it
			if (
					Len(sRecord[aFileFields[ii].name])
				AND	NOT (
								StructKeyExists(sData,aFileFields[ii].name)
							AND	sData[aFileFields[ii].name] NEQ sRecord[aFileFields[ii].name]
						)
			) {
				sData[aFileFields[ii].name] = Variables.FileMgr.makeFileCopy(sRecord[aFileFields[ii].name],aFileFields[ii].folder);
			}
		}
	}
	
	// Ditch primary keys
	for ( ii in ListToArray(pkfields) ) {
		StructDelete(sData,ii);
	}

	Arguments.data = sData;

	result = saveRecord(ArgumentCollection=Arguments);

	if (
			( StructKeyExists(Arguments,"CopyChildren") AND Arguments.CopyChildren IS true )
		AND	qRecord.RecordCount
		AND	(
					StructKeyExists(Variables.sMetaData[Arguments.tablename],"childtables")
			AND	Len(Variables.sMetaData[Arguments.tablename]["childtables"])
			)
		AND	ListLen(pkfields) EQ 1
	) {
		for ( table in ListToArray(Variables.sMetaData[Arguments.tablename].childtables) ) {
			sChildren = {};
			sFTables = Variables.DataMgr.getFTableFields(table);
			if ( StructKeyExists(sFTables,Arguments.tablename) ) {
				sChildren[sFTables[Arguments.tablename]] = qRecord[pkfields][1];
				childpkfields = getPrimaryKeyFields(table);
				qChildren = getRecords(tablename=table,data=sChildren,fieldlist=childpkfields);
				for ( sChild in qChildren ) {
					sRecord = {};
					sRecord[sFTables[Arguments.tablename]] = result;
					for ( ii in ArrayToList(childpkfields) ) {
						sRecord[ii] = sChild[ii];
					}
					copyRecord(tablename=table,data=sRecord,CopyChildren=true);
				}
			}
		}
	}

	notifyEvent("copyRecord",Arguments,result);

	return result;
}

public void function copyRecordChildren(
	required string tablename,
	struct data="#{}#"
) {

}

/**
* @OnExists defaults to update.
*/
public string function saveRecord(
	required string tablename,
	struct data="#{}#",
	string OnExists
) {
	var sData = Arguments.data;
	var aFileFields = 0;
	var ii = 0;
	var qRecord = 0;
	var result = "";
	var FormField = "";
	var FileResult = "";
	var isUpload = false;
	var isFormUpload = false;
	var isFileHandling = false;
	var sTable = {table=Arguments.tablename};
	var sUploadArgs = 0;

	aFileFields = getFileFields(tablename=Arguments.tablename,data=Arguments.data);

	// Default OnExists to update, but use key from data if it exists
	if ( NOT StructKeyExists(Arguments,"OnExists") ) {
		if ( StructKeyExists(sData,"OnExists") ) {
			Arguments.OnExists = sData.OnExists;
		} else {
			Arguments.OnExists = "update";
		}
	}

	// Take actions on any file fields
	if ( ArrayLen(aFileFields) AND StructCount(sData) ) {
		qRecord = getPKRecord(tablename=Arguments.tablename,data=sData,fieldlist=getFieldListFromArray(aFileFields));
		for ( ii=1; ii LTE ArrayLen(aFileFields); ii++ ) {
			FormField = aFileFields[ii].name;
			if (
					StructKeyExists(sData,"#aFileFields[ii].name#_FormField")
				AND	StructKeyExists(Form,"#sData['#aFileFields[ii].name#_FormField']#")
			) {
				FormField = sData['#aFileFields[ii].name#_FormField'];
			}
			isUpload = false;
			isFormUpload = isUpload;
			if ( StructKeyExists(sData,aFileFields[ii].name) ) {
				if ( StructKeyExists(Form,FormField) ) {
					isUpload = FileExists(Form[FormField]);
					isFormUpload = isUpload;
				}
				if ( NOT isUpload ) {
					isUpload = FileExists(sData[aFileFields[ii].name]);
				}
			}
			/*
			if ( aFileFields[ii].name EQ "FileRecording" ) {
				writeDump(aFileFields[ii]);
				writeDump(isUpload);
				abort;
			}
			*/
			if ( isUpload ) {
				isFileHandling = true;
				// Ditch old file if it is being replaced my new upload.
				if ( qRecord.RecordCount AND Len(qRecord[aFileFields[ii].name][1]) ) {
					Variables.FileMgr.deleteFile(qRecord[aFileFields[ii].name][1],aFileFields[ii].Folder);
				}

				if ( isFormUpload ) {
					
					sUploadArgs = {"return":"name","Folder":aFileFields[ii].Folder};
					if ( isFormUpload ) {
						sUploadArgs["FieldName"] = FormField;
					} else {
						sUploadArgs["FieldName"] = sData[aFileFields[ii].name];
					}
					if ( StructKeyExists(aFileFields[ii],"NameConflict") ) {
						sUploadArgs["NameConflict"] = aFileFields[ii].NameConflict;
					}
					if ( StructKeyExists(aFileFields[ii],"accept") ) {
						sUploadArgs["accept"] = aFileFields[ii].accept;
					}
					if ( StructKeyExists(aFileFields[ii],"extensions") ) {
						sUploadArgs["extensions"] = aFileFields[ii].extensions;
					}
					FileResult = Variables.FileMgr.uploadFile(ArgumentCollection=sUploadArgs);

					if ( isStruct(FileResult) AND StructKeyExists(FileResult,"ServerFile") ) {
						sData[aFileFields[ii].name] = FileResult["ServerFile"];
					}
					if ( isSimpleValue(FileResult) ) {
						sData[aFileFields[ii].name] = FileResult;
					}
					if ( StructKeyExists(sData,aFileFields[ii].name) AND isSimpleValue(sData[aFileFields[ii].name]) ) {
						if ( NOT StructKeyExists(aFileFields[ii],"Length") ) {
							aFileFields[ii].Length = 50;
						}
						sData[aFileFields[ii].name] = fixFileName(sData[aFileFields[ii].name],Variables.FileMgr.getDirectory(aFileFields[ii].Folder),aFileFields[ii].Length);
					}
				} else {
					Variables.FileMgr.makeFileCopy(sData[aFileFields[ii].name],aFileFields[ii].Folder);
					//FileCopy(sData[aFileFields[ii].name],Variables.FileMgr.getDirectory(aFileFields[ii].Folder));
					sData[aFileFields[ii].name] = getFileFromPath(sData[aFileFields[ii].name]);
				}
			}
		}

		if ( isFileHandling ) {
			// fit any images into box (if possible)
			sData = adjustImages(tablename=Arguments.tablename,data=sData);
			// Delete any files that are cleared out
			if ( qRecord.RecordCount ) {
				for ( ii=1; ii LTE ArrayLen(aFileFields); ii++ ) {
					if (
						Len(qRecord[aFileFields[ii].name][1])
						AND
						StructKeyExists(sData,aFileFields[ii].name)
						AND
						NOT Len(Trim(sData[aFileFields[ii].name]))
					) {
						Variables.FileMgr.deleteFile(qRecord[aFileFields[ii].name][1],aFileFields[ii].Folder);
					}
				}
			}
		}
	}

	Arguments.data = sData;

	result = saveRecordDataOnly(ArgumentCollection=Arguments);

	return result;
}

public string function saveRecordDataOnly(
	required string tablename,
	struct data="#{}#",
	string OnExists
) {
	var result = 0;

	Arguments.alterargs_for = "save";
	result = Variables.DataMgr.insertRecord(ArgumentCollection=alterArgs(ArgumentCollection=Arguments));

	notifyEvent("saveRecord",Arguments,result);

	return result;
}

private string function getFieldListFromArray(required array aFields) {
	var result = "";
	var sField = 0;

	for (sField in Arguments.aFields ) {
		result = ListAppend(result,sField.name);
	}

	return result;
}

public array function getFileFields(
	required string tablename,
	struct data="#{}#"
) {
	var aResults = 0;
	var sData = 0;
	var aFields = 0;
	var ii = 0;

	if ( NOT StructKeyExists(Variables.sMetaData[Arguments.tablename],"fields_files") ) {

		aResults = [];
		sData = Arguments.data;
		aFields = getFieldsArray(tablename=Arguments.tablename);

		for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
			if (
					( StructKeyExists(aFields[ii],"Folder") AND	Len(aFields[ii].Folder) )
				AND	(
							(
									StructCount(sData) EQ 0
								OR	StructKeyExists(sData,aFields[ii].name)
							)
						OR	(
									StructKeyExists(aFields[ii],"original")
								AND	StructKeyExists(sData,aFields[ii].original)
							)
					)
			) {
				ArrayAppend(aResults,aFields[ii]);
			}
		}

		Variables.sMetaData[Arguments.tablename]["fields_files"] = aResults;
	}

	return Variables.sMetaData[Arguments.tablename]["fields_files"];
}

public query function alterRecords(
	required string tablename,
	required query query
) {
	//var sTable = Variables.sMetaData[Arguments.tablename];
	var aFields = getFieldsArray(Arguments.tablename);
	var sFields = getFieldsStruct(Arguments.tablename);
	var ii = 0;
	var FolderFields = "";
	var field = "";
	var aPaths = [];
	var aURLs = [];
	var sRow = 0;

	if ( Len(Trim(Variables.FileMgr.getUploadPath())) OR Len(Trim(Variables.FileMgr.getUploadURL())) ) {
		for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
			if ( StructKeyExists(aFields[ii],"Folder") AND Len(Trim(aFields[ii].Folder)) ) {
				FolderFields = ListAppend(FolderFields,aFields[ii].name);
			}
		}

		if ( Len(FolderFields) ) {
			for ( field in ListToArray(FolderFields) ) {
				if (
					Len(Trim(Variables.FileMgr.getUploadPath()))
					AND
					ListFindNoCase(Arguments.query.ColumnList,field)
					AND
					NOT ListFindNoCase(Arguments.query.ColumnList,"#field#URL")
				) {
					aPaths = [];
					for ( sRow in Arguments.query ) {
						if ( Len(Trim(sRow[field])) ) {
							ArrayAppend(aPaths,"#Variables.FileMgr.getFilePath(sRow[field],sFields[field].Folder)#");
						} else {
							ArrayAppend(aPaths,"");
						}
					}
					QueryAddColumn(Arguments.query,"#field#Path",aPaths);
				}
				if (
					Len(Trim(Variables.FileMgr.getUploadURL()))
					AND
					ListFindNoCase(Arguments.query.ColumnList,field)
					AND
					NOT ListFindNoCase(Arguments.query.ColumnList,"#field#URL")
				) {
					aURLs = [];
					for ( sRow in Arguments.query ) {
						if ( Len(Trim(sRow[field])) ) {
							ArrayAppend(aURLs,"#Variables.FileMgr.getFileURL(sRow[field],sFields[field].Folder)#");
						} else {
							ArrayAppend(aURLs,"");
						}
					}
					QueryAddColumn(Arguments.query,"#field#URL",aURLs);
				}
			}
		}
	}

	return Arguments.query;
}

public struct function alterArgs(string alterargs_for="get") {
	var sArgs = StructFromArgs(Arguments);
	var sMetaData = 0;
	var sTableData = 0;
	var sSort = 0;
	var dmargs = 0;
	var dmarg = "";

	if ( Arguments.alterargs_for EQ "save" ) {
		dmargs = getDataMgrSaveRecordArgs();
	} else {
		dmargs = getDataMgrGetRecordsArgs();
	}

	// Any data args that match DataMgr args should be copied there
	if ( StructKeyExists(Arguments,"data") ) {
		if ( StructKeyExists(Arguments.data,"data") ) {
			StructAppend(Arguments.data,Arguments.data.data,"no");
		}
		for ( dmarg in ListToArray(dmargs) ) {
			if ( StructKeyExists(sArgs.data,dmarg) AND NOT StructKeyExists(sArgs,dmarg) ) {
				sArgs[dmarg] = sArgs.data[dmarg];
			}
		}
	}

	if ( Arguments.alterargs_for EQ "get" ) {
		sMetaData = getMetaStruct();
		sTableData = sMetaData[sArgs.tablename];
		// Default list to fields marked "isOnList=true" for multi-record queries (if none are marked, empty string will retrieve all fields)
		if ( NOT StructKeyExists(sArgs,"fieldlist") ) {
			if ( StructKeyExists(Arguments,"isGetRecord") ) {
				sArgs.fieldlist = "";
			} else {
				sArgs.fieldlist = sTableData["listfields"];
			}
		}

		if ( NOT ( StructKeyExists(sArgs,"sortfield") ) ) {
			if ( StructKeyExists(sTableData,"orderby") AND NOT ( StructKeyExists(sArgs,"orderby") ) ) {
				sArgs["orderby"] = sTableData["orderby"];
			} else {
				sSort = getTableSort(sArgs.tablename,sArgs.fieldlist);
				if ( StructKeyExists(sSort,"field") ) {
					sArgs["sortfield"] = sSort.field;
					sArgs["sortdir"] = sSort.dir;
				}
			}
		}
	}

	StructDelete(Arguments,"alterargs_for");

	return sArgs;
}

/**
* I make sure DataMgr isn't given multiple increments.
*/
private array function alterDataMgrIncrements(required array aFields) {
	var ii = 0;
	var incCount = 0;

	for ( ii=1; ii LTE ArrayLen(Arguments.aFields); ii++ ) {
		if (
				( StructKeyExists(Arguments.aFields[ii],"Increment") AND Arguments.aFields[ii].Increment IS true )
			OR	( StructKeyExists(Arguments.aFields[ii],"PrimaryKey") AND Arguments.aFields[ii].PrimaryKey IS true )
		) {
			incCount = incCount + 1;
		}
	}
	if ( incCount GT 1 ) {
		for ( ii=1; ii LTE ArrayLen(Arguments.aFields); ii++ ) {
			if ( StructKeyExists(Arguments.aFields[ii],"Increment") AND Arguments.aFields[ii].Increment EQ 1 ) {
				Arguments.aFields[ii]["Increment"] = false;
			}
		}
	}

	return Arguments.aFields;
}

private string function getWidth(
	required struct struct,
	required imagedata
) {
	var data = Arguments.struct;
	var result = imagedata.width;

	if (
		( StructKeyExists(data,"MaxWidth") AND isNumeric(data.MaxWidth) AND data.MaxWidth GT 0 )
		AND
		imagedata.width GT data.MaxWidth
	) {
		result = Int(data.MaxWidth);
	} else if (
		( StructKeyExists(data,"MaxSmallSide") AND isNumeric(data.MaxSmallSide) AND data.MaxSmallSide GT 0 )
		AND
		imagedata.height GTE imagedata.width
	) {
		result = Int(data.MaxSmallSide);
	}

	return result;
}

private string function getHeight(
	required struct struct,
	required imagedata
) {
	var data = Arguments.struct;
	var result = imagedata.height;

	if (
			( StructKeyExists(data,"MaxHeight") AND isNumeric(data.MaxHeight) AND data.MaxHeight GT 0 )
		AND	imagedata.height GT data.MaxHeight
	) {
		result = Int(data.MaxHeight);
	} else if (
			( StructKeyExists(data,"MaxSmallSide") AND isNumeric(data.MaxSmallSide) AND data.MaxSmallSide GT 0 )
		AND	imagedata.width GTE imagedata.height
	) {
		result = Int(data.MaxSmallSide);
	}

	return result;
}

public struct function limitPKArgs(
	required string tablename,
	required struct data
) {
	var pkfields = Variables.DataMgr.getPKFields(Arguments.tablename);
	var sPKField = 0;
	var sPKArgs = {};
	var pkfield = "";

	// Remove non-PK columns from struct
	for ( sPKField in pkfields ) {
		pkfield = sPKField.ColumnName;
		if ( StructKeyExists(Arguments.data,pkfield) ) {
			sPKArgs[pkfield] = Arguments.data[pkfield];
		}
	}

	return sPKArgs;
}

public struct function makeNamedPKArgs(
	required string tablename,
	required struct data,
	string method="getRecord"
) {
	var pkfields = Variables.DataMgr.getPKFields(Arguments.tablename);
	var ii = 0;

	if ( NOT ArrayLen(pkfields) ) {
		throw(message="#Arguments.method# can only be used against tables with at least one primary key field.",type="Manager");
	}

	// Set argument names if not given by names
	if (
			StructCount(Arguments.data) GTE ArrayLen(pkfields)
		AND	NOT StructKeyExists(Arguments.data,pkfields[1].ColumnName)
	) {
		for ( ii=1; ii LTE ArrayLen(pkfields); ii++ ) {
			if (
					StructKeyExists(Arguments.data,ii)
				AND	NOT StructKeyExists(Arguments.data,pkfields[ii].ColumnName)
			) {
				Arguments.data[pkfields[ii].ColumnName] = Arguments.data[ii];
				StructDelete(Arguments.data,ii);
			}
		}
	}

	return StructCopy(Arguments.data);
}

private void function setTable(required string tablename) {

	lock name="Manager_#Arguments.tablename#" timeout="30" {
		if ( NOT StructKeyExists(Variables.sMetaData,Arguments.tablename) ) {
			Variables.sMetaData[Arguments.tablename] = {};
			Variables.sMetaData[Arguments.tablename]["fieldlist"] = "";
			Variables.sMetaData[Arguments.tablename]["fields"] = [];
			Variables.sMetaData[Arguments.tablename]["listfields"] = "";
			Variables.sMetaData[Arguments.tablename]["fields"] = [];
			Variables.sMetaData[Arguments.tablename]["sFields"] = {};
			Variables.sMetaData[Arguments.tablename]["_sortfield"] = "";
			Variables.sMetaData[Arguments.tablename]["_sortdir"] = "";
			Variables.sMetaData[Arguments.tablename]["hasFileFields"] = false;
			Variables.sMetaData[Arguments.tablename]["sAttributes"] = {};
		}
	}

}

private struct function getTableSort(
	required string tablename,
	string fieldlist
) {
	var table = Arguments.tablename;
	var sTable = Variables.sMetaData[table];
	var aFields = sTable["fields"];
	var sField = 0;
	var ii = 0;

	var aSortDefaults = [];
	var aSorters = [];

	var sResult = {};

	if ( NOT (StructKeyExists(Arguments,"fieldlist") AND Len(Arguments.fieldlist) ) ) {
		Arguments.fieldlist = Variables.sMetaData[Arguments.tablename]["fieldlist"];
	}

	// Set internal sort field and direction
	if ( StructKeyExists(sTable,"sortfield") AND ListFindNoCase(Arguments.fieldlist,sTable["sortfield"]) ) {
		sResult["field"] = sTable["sortfield"];
		if ( StructKeyExists(sTable,"sortdir") ) {
			sResult["dir"] = sTable["sortdir"];
		}
	} else {
		for ( sField in aFields ) {

			if ( ListFindNoCase(Arguments.fieldlist,sField.name) ) {
				// Check for sort (apply to table if none exists)
				if ( StructKeyExists(sField,"defaultSort") AND ListFindNoCase("ASC,DESC",sField.defaultSort) ) {
					ArrayAppend(aSortDefaults,StructFromArgs(field=sField.name,dir=sField.defaultSort));
				}
				if (
						(StructKeyExists(sField,"Special") AND sField.Special EQ "Sorter")
					OR	(StructKeyExists(sField,"type") AND sField.type EQ "Sorter")
				) {
					ArrayAppend(aSorters,StructFromArgs(field=sField.name,dir="ASC"));
				}
			}
		}
		
		if ( ArrayLen(aSorters) ) {
			for ( ii=1; ii LTE ArrayLen(aSorters); ii++ ) {
				if ( ListFindNoCase(Arguments.fieldlist,aSorters[ii]["field"]) ) {
					sResult = aSorters[ii];
					break;
				}
			}
		} else if ( ArrayLen(aSortDefaults) ) {
			for ( ii=1; ii LTE ArrayLen(aSortDefaults); ii++ ) {
				if ( ListFindNoCase(Arguments.fieldlist,aSortDefaults[ii]["field"]) ) {
					sResult = aSortDefaults[ii];
					break;
				}
			}
		} else if ( StructKeyExists(sTable,"labelField") ) {
			sResult["field"] = sTable["labelField"];
		}
	}

	if ( StructKeyExists(sResult,"field") AND NOT StructKeyExists(sResult,"dir") ) {
		sResult["dir"] = "ASC";
	}

	return sResult;
}

public function setField(
	required string tablename,
	required string fieldname,
	string type
) {
	var sField = Duplicate(Arguments);
	var ii = 0;
	var sDataMgrField = 0;

	StructDelete(sField,"tablename");
	StructDelete(sField,"fieldname");
	sField["name"] = Arguments.fieldname;

	// Expand folder
	if (
			StructKeyExists(sField,"Folder")
		AND	StructKeyExists(Variables.sMetaData[Arguments.tablename],"folder")
		AND	NOT (
					StructKeyExists(sField,"ExpandFolder")
				AND	sField.ExpandFolder IS false
			)
	) {
		sField["Folder"] = ListPrepend(sField["Folder"],Variables.sMetaData[Arguments.tablename].folder);
	}

	// Default URLvar for foreign keys
	if ( NOT StructKeyExists(sField,"urlvar") ) {
		if (
				StructKeyExists(Arguments,"type")
			AND	ListFirst(Arguments.type,":") EQ "fk"
		) {
			sField["urlvar"] = LCase(sField["name"]);
			if ( Right(sField["urlvar"],2) EQ "id" ) {
				sField["urlvar"] = Left(sField["urlvar"],Len(sField["urlvar"])-2);
				if ( Right(sField["urlvar"],1) EQ "_" ) {
					sField["urlvar"] = Left(sField["urlvar"],Len(sField["urlvar"])-1);
				}
			}
		} else if (
				StructKeyExists(Arguments,"fentity")
			AND	Len(Arguments.fentity)
		) {
			sField["urlvar"] = LCase(makeCompName(Arguments.fentity));
		}
	}

	// Only set fields with a type or a relation
	if ( StructKeyExists(Arguments,"type") OR StructKeyExists(Arguments,"relation") ) {
		// Make sure a table exists for this field
		setTable(Arguments.tablename);
		if ( ListFindNoCase(Variables.sMetaData[Arguments.tablename]["fieldlist"],Arguments.fieldname) ) {
			// Update field
			for ( ii=1; ii LTE ArrayLen(Variables.sMetaData[Arguments.tablename].fields); ii++ ) {
				if ( Variables.sMetaData[Arguments.tablename].fields[ii].name EQ Arguments.fieldname ) {
					Variables.sMetaData[Arguments.tablename].fields[ii] = sField;
				}
			}
		} else {
			//Add field
			ArrayAppend(Variables.sMetaData[Arguments.tablename]["fields"],sField);
			Variables.sMetaData[Arguments.tablename]["fieldlist"] = ListAppend(Variables.sMetaData[Arguments.tablename]["fieldlist"],Arguments.fieldname);
			if ( StructKeyExists(Arguments,"isOnList") AND isBoolean(Arguments.isOnList) AND Arguments.isOnList ) {
				Variables.sMetaData[Arguments.tablename]["listfields"] = ListAppend(Variables.sMetaData[Arguments.tablename]["listfields"],Arguments.fieldname);
			}
		}
		Variables.sMetaData[Arguments.tablename]["sFields"][Arguments.fieldname] = sField;
		StructDelete(Variables.sMetaData[Arguments.tablename]["sFields"][Arguments.fieldname],"isInTableCreation");

		if (
			NOT (
				StructKeyExists(Arguments,"isInTableCreation")
				AND
				isBoolean(Arguments.isInTableCreation)
				AND
				Arguments.isInTableCreation
			)
		) {
			sDataMgrField = transformField(Duplicate(sField),"DataMgr");
			sDataMgrField["tablename"] = Arguments.tablename;
			sDataMgrField["ColumnName"] = Arguments.fieldname;
			Variables.DataMgr.setColumn(ArgumentCollection=sDataMgrField);

			// Make any thumbnails for new thumbnail field
			if ( isThumbField(Arguments.tablename,Arguments.fieldname) ) {
				makeThumbs(Arguments.tablename,Arguments.fieldname);
			}
		}

		if ( StructKeyExists(sField,"Folder") ) {
			Variables.FileMgr.makeFolder(sField.Folder);
			Variables.sMetaData[Arguments.tablename]["hasFileFields"] = true;
		}
		
	}

}

public function loadXml(required xml) {
	var xIn = XmlParse(Arguments.xml);
	var table = "";
	var aInTables = 0;
	var tt = 0;
	lock name="Manager_loadXml#Variables.UUID#" timeout="60" throwontimeout="yes" {
		adjustXml(xIn);

		loadXmlStruct(xIn);

		loadDataMgrXml(xIn);

		aInTables = XmlSearch(xIn,"//table[string-length(@name)>0]");

		// Make thumbnails
		for ( tt=1; tt LTE ArrayLen(aInTables); tt++ ) {
			table = aInTables[tt].XmlAttributes["name"];
			if ( Variables.sMetaData[table]["hasFileFields"] IS true ) {
				makeThumbs(table);
			}
		}
	}

	return xIn;
}

public function adjustXml(required xml) {
	var xDef = 0;
	var aTables = 0;
	var aFTables = 0;
	var table = "";
	var ftable = "";
	var aFields = 0;
	var tt = 0;
	var ff = 0;
	var ll = 0;
	var sField = "";
	var xField = "";
	var special = "";
	var xType = 0;
	var insertAt = 0;

	if ( isSimpleValue(Arguments.xml) ) {
		xDef = XmlParse(Arguments.xml);
	} else if ( isXMLDoc(Arguments.xml) ) {
		xDef = Arguments.xml;
	} else {
		throw(message="XML argument of loadXmlStruct must be XML.",type="Manager");
	}

	xDef = applyTableDefaults(xDef);
	xDef = applyEntities(xDef);
	xDef = applySecurityPermissions(xDef);

	aTables = XmlSearch(xDef,"//table[string-length(@name)>0]");

	//Table/Field pre-processing
	for ( tt=1; tt LTE ArrayLen(aTables); tt++ ) {
		table = aTables[tt].XmlAttributes["name"];
		// Create entry for table if not already in memory
		setTable(table);

		if ( NOT StructKeyExists(aTables[tt].XmlAttributes,"deletable") ) {
			aTables[tt].XmlAttributes["deletable"] = "isDeletable";
		}

		// Update table properties
		StructAppend(Variables.sMetaData[table]["sAttributes"],aTables[tt].XmlAttributes,"yes");
		StructAppend(Variables.sMetaData[table],aTables[tt].XmlAttributes,"yes");
		StructDelete(Variables.sMetaData[table],"name");

		if ( NOT StructKeyExists(aTables[tt].XmlAttributes,"methodSingular") ) {
			if ( StructKeyExists(Variables.sMetaData[table],"methodSingular") ) {
				aTables[tt].XmlAttributes["methodSingular"] = Variables.sMetaData[table]["methodSingular"];
			} else if ( StructKeyExists(aTables[tt].XmlAttributes,"labelSingular") ) {
				aTables[tt].XmlAttributes["methodSingular"] = makeCompName(aTables[tt].XmlAttributes["labelSingular"]);
				Variables.sMetaData[table]["methodSingular"] = aTables[tt].XmlAttributes["methodSingular"];
			}
		}
		if ( NOT StructKeyExists(aTables[tt].XmlAttributes,"methodPlural") ) {
			if ( StructKeyExists(Variables.sMetaData[table],"methodPlural") ) {
				aTables[tt].XmlAttributes["methodPlural"] = Variables.sMetaData[table]["methodPlural"];
			} else if ( StructKeyExists(aTables[tt].XmlAttributes,"labelPlural") ) {
				aTables[tt].XmlAttributes["methodPlural"] = makeCompName(aTables[tt].XmlAttributes["labelPlural"]);
				Variables.sMetaData[table]["methodPlural"] = aTables[tt].XmlAttributes["methodPlural"];
			}
		}

		aFields = XmlSearch(xDef,"//table[@name='#table#']//field[string-length(@name)>0]");

		// Create primary key field from pkfield attribute
		if (
				StructKeyExists(aTables[tt].XmlAttributes,"pkfield")
			AND	Len(Trim(aTables[tt].XmlAttributes.pkfield))
			AND	NOT StructKeyExists(Variables.sMetaData[table].sFields,Variables.sMetaData[table].pkfield)
			AND	NOT ArrayLen(XmlSearch(xDef,"//table[@name='#table#']//field[@name='#Variables.sMetaData[table].pkfield#']"))
		) {
			// Look for existing pkfield
			for ( ff=1; ff LTE ArrayLen(aFields); ff++ ) {
				if ( StructKeyExists(aFields[ff],"type") AND Len(aFields[ff].type) AND ListFirst(aFields[ff].type,":") EQ "pk" ) {
					throw(message="Primary key for #table# defined in pkfield attribute (#Variables.sMetaData[table].pkfield#) does not match a field defined as a primary key.",type="Manager");
				}
			}

			// No errors? Then create the field
			xField = XmlElemNew(xDef,"field");
			xField.XmlAttributes["name"] = Variables.sMetaData[table].pkfield;
			xField.XmlAttributes["type"] = "pk:integer";

			ArrayPrepend(aTables[tt].XmlChildren,Duplicate(xField));
		}

		// Create label field from labelField attribute
		if (
				StructKeyExists(aTables[tt].XmlAttributes,"labelField")
			AND	Len(Trim(aTables[tt].XmlAttributes.labelField))
			AND	NOT ListFindNoCase(Variables.sMetaData[table].fieldlist,Variables.sMetaData[table].labelField)
			AND	NOT StructKeyExists(Variables.sMetaData[table].sFields,Variables.sMetaData[table].labelField)
			AND	NOT ArrayLen(XmlSearch(xDef,"//table[@name='#table#']//field[@name='#Variables.sMetaData[table].labelField#']"))
		) {
			xField = XmlElemNew(xDef,"field");
			xField.XmlAttributes["name"] = Variables.sMetaData[table].labelField;
			xField.XmlAttributes["label"] = Variables.sMetaData[table]["labelSingular"];
			xField.XmlAttributes["type"] = "text";
			xField.XmlAttributes["required"] = "true";

			if (
					StructKeyExists(Variables.sMetaData[table],"labelLength")
				AND	isNumeric(Variables.sMetaData[table].labelLength)
				AND	Variables.sMetaData[table].labelLength GT 0
			) {
				xField.XmlAttributes["Length"] = Int(Variables.sMetaData[table].labelLength);
			} else {
				xField.XmlAttributes["Length"] = 120;
			}

			insertAt = Min(
				ArrayLen(
					XmlSearch(
						xDef,
						"//table[@name='#table#']//field"
					)
				) + 1,
				ArrayLen(
					XmlSearch(
						xDef,
						"//table[@name='#table#']//field[starts-with(@type,'pk:')]"
					)
				) + 1
			);

			if ( insertAt GTE ArrayLen(aTables[tt].XmlChildren) ) {
				ArrayAppend(aTables[tt].XmlChildren,xField);
			} else {
				ArrayInsertAt(aTables[tt].XmlChildren,insertAt,xField);
			}
		}

		// Add Special fields
		if (
				StructKeyExists(Variables.sMetaData[table],"Specials")
			AND	Len(Trim(Variables.sMetaData[table].Specials))
		) {
			for ( special in ListToArray(Variables.sMetaData[table].Specials) ) {
				if (
						ListFindNoCase(Variables.TypeNames,special)
					AND	NOT ArrayLen(XmlSearch(aTables[tt],"/field[@type='#special#']"))
				) {
					xField = XmlElemNew(xDef,"field");
					xField.XmlAttributes["type"] = special;
					if ( special EQ "CreationDate" OR special EQ "LastUpdatedDate" ) {
						xField.XmlAttributes["sebcolumn"] = false;
					}
					ArrayAppend(aTables[tt].XmlChildren,xField);
				}
			}
		}

		// Add help for image sizes
		for ( xField in aFields ) {
			if (
					StructKeyExists(xField.XmlAttributes,"type")
				AND	xField.XmlAttributes["type"] EQ "image"
				AND	( StructKeyExists(xField.XmlAttributes,"MaxWidth") AND Val(xField.XmlAttributes["MaxWidth"]) )
				AND	( StructKeyExists(xField.XmlAttributes,"MaxHeight") AND Val(xField.XmlAttributes["MaxHeight"]) )
				AND	NOT ( StructKeyExists(xField.XmlAttributes,"help") AND Len(xField.XmlAttributes["help"]) )
			) {
				xField.XmlAttributes["help"] = '( At least #xField.XmlAttributes["MaxWidth"]#px X #xField.XmlAttributes["MaxHeight"]#px )';
			}
		}

		// Add "IN" filter for pk field
		if (
				StructKeyExists(aTables[tt].XmlAttributes,"pkfield")
			AND	StructKeyExists(aTables[tt].XmlAttributes,"methodPlural")
			AND	ArrayLen(
					XmlSearch(
						xDef,
						"//table[@name='#table#']//field[starts-with(@type,'pk:')]"
					)
				) EQ 1
			AND NOT (
					ArrayLen(
						XmlSearch(
							xDef,
							"//table[@name='#table#']//filter[@name='#LCase(aTables[tt].XmlAttributes.methodPlural)#']"
						)
					)
				)
		) {
			xField = XmlElemNew(xDef,"filter");
			xField.XmlAttributes["name"] = LCase(aTables[tt].XmlAttributes.methodPlural);
			xField.XmlAttributes["field"] = aTables[tt].XmlAttributes.pkfield;
			xField.XmlAttributes["operator"] = "IN";
			ArrayAppend(aTables[tt].XmlChildren,Duplicate(xField));

			xField = XmlElemNew(xDef,"filter");
			xField.XmlAttributes["name"] = "exclude";
			xField.XmlAttributes["field"] = aTables[tt].XmlAttributes.pkfield;
			xField.XmlAttributes["operator"] = "NOT IN";
			ArrayAppend(aTables[tt].XmlChildren,Duplicate(xField));
		}

	}

	// Handle Fields with ftable attributes
	adjustXmlFTableFields(xDef);

	// Add names to fields with only types
	adjustXmlAddNamesToTypes(xDef);

	for ( tt=1; tt LTE ArrayLen(aTables); tt++ ) {
		table = aTables[tt].XmlAttributes["name"];
		aFields = XmlSearch(xDef,"//table[@name='#table#']//field[string-length(@name)>0]");
		// Add filters for fentities
		for ( ff=1; ff LTE ArrayLen(aFields); ff++ ) {
			if (
					StructKeyHasLen(aFields[ff].XmlAttributes,"fentity")
				AND	NOT (
							StructKeyHasLen(aTables[tt].XmlAttributes,"entity")
						AND	aFields[ff].XmlAttributes["fentity"] EQ aTables[tt].XmlAttributes["entity"]
					)
			) {
				xField = XmlElemNew(xDef,"filter");
				xField.XmlAttributes["name"] = Pluralize(makeCompName(aFields[ff].XmlAttributes["fentity"]));
				xField.XmlAttributes["field"] = aFields[ff].XmlAttributes["name"];
				xField.XmlAttributes["operator"] = "IN";
				ArrayAppend(aTables[tt].XmlChildren,Duplicate(xField));
			}
		}
	}
	
	return xDef;
}

private function adjustXmlFTableFields(required xDef) {
	var axFields = XmlSearch(xDef,"//field[string-length(@ftable)>0]");
	var xField = 0;
	var xTable = 0;
	var ff = 0;
	var table = "";
	var ftable = "";
	var axFTables = 0;
	var xFTable = 0;
	var xLabelField = 0;
	var NumField = "";
	var xNumField = 0;
	var HasField = "";
	var xHasField = 0;
	var xListField = 0;
	var xListNamesField = 0;
	var isMany2Many = 0;

	for ( ff=1; ff LTE ArrayLen(axFields); ff++ ) {
		xField = axFields[ff];
		xTable = xField.XmlParent;
		table = xTable.XmlAttributes["name"];
		ftable = xField.XmlAttributes["ftable"];
		axFTables = XmlSearch(xDef,"//table[@name='#ftable#']");
		if ( ArrayLen(axFTables) ) {
			
			xFTable = axFTables[1];

			if ( NOT StructKeyExists(xField.XmlAttributes,"subcomp") ) {
				if ( StructKeyExists(Variables.sMetaData, ftable) AND StructKeyExists(Variables.sMetaData[ftable],"methodPlural") ) {
					xField.XmlAttributes["subcomp"] = makeCompName(Variables.sMetaData[ftable]["methodPlural"]);
				} else if ( StructKeyExists(xFTable.XmlAttributes,"methodPlural") ) {
					xField.XmlAttributes["subcomp"] = makeCompName(xFTable.XmlAttributes["methodPlural"]);
				}
			}

			if (
					StructKeyExists(xField.XmlAttributes,"jointype")
				AND	(
							xField.XmlAttributes["jointype"] EQ "many"
						OR	xField.XmlAttributes["jointype"] EQ "list"
						OR	xField.XmlAttributes["jointype"] EQ "many2many"
					)
			) {
				isMany2Many = ( xField.XmlAttributes["jointype"] EQ "many2many" OR ArrayLen(XmlSearch(xDef,"//table[@name='#ftable#']/field[@ftable='#table#'][@jointype='many' or @jointype='list' or @jointype='many2many']")) );
				if ( NOT StructKeyExists(xField.XmlAttributes,"type") ) {
					xField.XmlAttributes["type"] = "Relation";
				}
				if ( NOT StructKeyExists(xField.XmlAttributes,"name") ) {
					if ( StructKeyExists(xField.XmlAttributes,"fentity") ) {
						xField.XmlAttributes["name"] = Pluralize(makeCompName(xField.XmlAttributes["fentity"]));
					} else if ( StructKeyExists(Variables.sMetaData,ftable) ) {
						xField.XmlAttributes["name"] = makeCompName(Variables.sMetaData[ftable]["methodPlural"]);
					}
					if ( table EQ ftable ) {
						xField.XmlAttributes.name = "Related#xField.XmlAttributes.name#";
					}
				}
				if ( NOT StructKeyExists(xField.XmlAttributes,"Label") ) {
					if ( StructKeyExists(Variables.sMetaData, ftable) AND StructKeyExists(Variables.sMetaData[ftable],"labelPlural") ) {
						xField.XmlAttributes["Label"] = Variables.sMetaData[ftable]["labelPlural"];
						if ( table EQ ftable ) {
							xField.XmlAttributes.Label = "Related #xField.XmlAttributes.Label#";
						}
					}
				}
				/*
				if ( NOT StructKeyExists(xField.XmlAttributes,"OldField") ) {
					xField.XmlAttributes["OldField"] = getPrimaryKeyFields(ftable,xDef);
					if ( ListLen(xField.XmlAttributes["OldField"]) NEQ 1 ) {
						//throw(message="You must provide a field name for joins with #ftable# as no single primary key field could be found.",type="Manager");
						StructDelete(xField.XmlAttributes,"OldField");
					}
				}
				*/
				if ( NOT StructKeyExists(xField.XmlAttributes,"jointable") ) {
					xField.XmlAttributes["jointable"] = getJoinTableName(xDef,table,ftable);
				}
				ArrayAppend(xField.XmlChildren,XmlElemNew(xDef,"relation"));
				xField.XmlChildren[1].XmlAttributes["type"] = "list";
				xField.XmlChildren[1].XmlAttributes["table"] = ftable;
				xField.XmlChildren[1].XmlAttributes["field"] = getPrimaryKeyFields(ftable,xDef);
				xField.XmlChildren[1].XmlAttributes["join-table"] = xField.XmlAttributes["jointable"];
				xField.XmlChildren[1].XmlAttributes["local-table-join-field"] = getPrimaryKeyFields(table,xDef);
				xField.XmlChildren[1].XmlAttributes["join-table-field-local"] = getPrimaryKeyFields(table,xDef);
				xField.XmlChildren[1].XmlAttributes["join-table-field-remote"] = getPrimaryKeyFields(ftable,xDef);
				xField.XmlChildren[1].XmlAttributes["remote-table-join-field"] = getPrimaryKeyFields(ftable,xDef);
				if ( table EQ ftable ) {
					xField.XmlChildren[1].XmlAttributes["join-table-field-remote"] = "Related#getPrimaryKeyFields(ftable,xDef)#";
					if ( StructKeyExists(xField.XmlAttributes,"bidirectional") AND isBoolean(xField.XmlAttributes["bidirectional"]) ) {
						xField.XmlChildren[1].XmlAttributes["bidirectional"] = xField.XmlAttributes["bidirectional"];
					} else {
						xField.XmlChildren[1].XmlAttributes["bidirectional"] = true;
					}
				}
				if ( NOT StructKeyExists(xField.XmlAttributes,"listshowfield") ) {
					if ( StructKeyExists(Variables.sMetaData, ftable) AND StructKeyExists(Variables.sMetaData[ftable],"methodSingular") ) {
						xField.XmlAttributes["listshowfield"] = makeCompName(Variables.sMetaData[ftable]["methodSingular"] & "Names");
						if ( table EQ ftable ) {
							xField.XmlAttributes.listshowfield = "Related#xField.XmlAttributes.listshowfield#";
						}
					}
				}
				if ( StructKeyExists(xField.XmlAttributes,"listshowfield") ) {
					// Add label and has relation fields (if they don't exists)
					if ( NOT ArrayLen( XmlSearch(xDef,"//table[@name='#table#']/field[@name='#xField.XmlAttributes.listshowfield#']") ) ) {
						xLabelField = XmlElemNew(xDef,"field");
						xLabelField.XmlAttributes["name"] = xField.XmlAttributes.listshowfield;
						xLabelField.XmlAttributes["label"] = xField.XmlAttributes.label;
						ArrayAppend(xLabelField.XmlChildren,XmlElemNew(xDef,"relation"));
						xLabelField.XmlChildren[1].XmlAttributes["type"] = "list";
						xLabelField.XmlChildren[1].XmlAttributes["table"] = ftable;
						xLabelField.XmlChildren[1].XmlAttributes["field"] = Variables.sMetaData[ftable]["labelField"];
						xLabelField.XmlChildren[1].XmlAttributes["join-table"] = xField.XmlAttributes["jointable"];
						xLabelField.XmlChildren[1].XmlAttributes["local-table-join-field"] = getPrimaryKeyFields(table,xDef);
						xLabelField.XmlChildren[1].XmlAttributes["join-table-field-local"] = getPrimaryKeyFields(table,xDef);
						xLabelField.XmlChildren[1].XmlAttributes["join-table-field-remote"] = getPrimaryKeyFields(ftable,xDef);
						xLabelField.XmlChildren[1].XmlAttributes["remote-table-join-field"] = getPrimaryKeyFields(ftable,xDef);
						ArrayAppend(xTable.XmlChildren,xLabelField);
					}
				}
				// Add Num and Has relation fields (if they don't exist)
				var xHere = xTable;
				var xThere = xFTable;
				var runs = 0;
				do {
					if ( table EQ ftable ) {
						NumField = "NumRelated#xThere.XmlAttributes.methodPlural#";
						HasField = "hasRelated#xThere.XmlAttributes.methodPlural#";
					} else {
						NumField = "Num#xThere.XmlAttributes.methodPlural#";
						HasField = "has#xThere.XmlAttributes.methodPlural#";
					}
					if ( NOT ArrayLen(XmlSearch(xHere,"/field[@name='#NumField#']")) ) {
						xNumField = XmlElemNew(xDef,"field");
						xNumField.XmlAttributes["name"] = NumField;
						xNumField.XmlAttributes["label"] = xThere.XmlAttributes.labelPlural;
						if ( table EQ ftable ) {
							xNumField.XmlAttributes.label = "Related #xNumField.XmlAttributes.label#";
						}
						xNumField.XmlAttributes["sebcolumn_type"] = "numeric";
						ArrayAppend(xNumField.XmlChildren,XmlElemNew(xDef,"relation"));
						xNumField.XmlChildren[1].XmlAttributes["type"] = "count";
						xNumField.XmlChildren[1].XmlAttributes["table"] = xField.XmlAttributes["jointable"];
						xNumField.XmlChildren[1].XmlAttributes["field"] = getPrimaryKeyFields(xThere.XmlAttributes["name"],xDef);
						xNumField.XmlChildren[1].XmlAttributes["join-field-local"] = getPrimaryKeyFields(xHere.XmlAttributes["name"],xDef);
						xNumField.XmlChildren[1].XmlAttributes["join-field-remote"] = getPrimaryKeyFields(xHere.XmlAttributes["name"],xDef);
						if ( StructKeyExists(xField.XmlAttributes,"onRemoteDelete") ) {
							xNumField.XmlChildren[1].XmlAttributes["onDelete"] = xField.XmlAttributes["onRemoteDelete"];
						}
						if ( ListLen(xNumField.XmlChildren[1].XmlAttributes["join-field-local"]) EQ 1 ) {
							ArrayAppend(xHere.XmlChildren,xNumField);
						}
					}
					if ( NOT ArrayLen(XmlSearch(xHere,"/field[@name='#HasField#']")) ) {
						xHasField = XmlElemNew(xDef,"field");
						xHasField.XmlAttributes["name"] = HasField;
						xHasField.XmlAttributes["label"] = "Has #xThere.XmlAttributes.labelPlural#?";
						if ( table EQ ftable ) {
							xHasField.XmlAttributes.label = "Has Child #xNumField.XmlAttributes.label#s?";
						}
						xHasField.XmlAttributes["sebcolumn_type"] = "yesno";
						ArrayAppend(xHasField.XmlChildren,XmlElemNew(xDef,"relation"));
						xHasField.XmlChildren[1].XmlAttributes["type"] = "has";
						xHasField.XmlChildren[1].XmlAttributes["field"] = NumField;
						ArrayAppend(xHere.XmlChildren,xHasField);
					}
					runs++;
					xHere = xFTable;
					xThere = xTable;
				} while( table NEQ ftable AND runs LTE 2 );
			} else {
				if ( NOT StructKeyExists(xField.XmlAttributes,"type") ) {
					xField.XmlAttributes["type"] = "fk:integer";
				}
				if ( NOT StructKeyExists(xField.XmlAttributes,"name") ) {
					xField.XmlAttributes["name"] = getPrimaryKeyFields(ftable,xDef);
					if ( ListLen(xField.XmlAttributes["name"]) NEQ 1 ) {
						throw(message="You must provide a field name for joins with #ftable# as no single primary key field could be found.",type="Manager");
					}
					if ( table EQ ftable ) {
						xField.XmlAttributes.name = "Parent#xField.XmlAttributes.name#";
					}
				}
				if ( NOT StructKeyExists(xField.XmlAttributes,"Label") ) {
					if ( StructKeyExists(Variables.sMetaData, ftable) AND StructKeyExists(Variables.sMetaData[ftable],"labelSingular") ) {
						xField.XmlAttributes["Label"] = Variables.sMetaData[ftable]["labelSingular"];
						if ( table EQ ftable ) {
							xField.XmlAttributes.Label = "Parent #xField.XmlAttributes.Label#";
						}
					}
				}
				if ( NOT StructKeyExists(xField.XmlAttributes,"listshowfield") ) {
					if ( StructKeyExists(Variables.sMetaData, ftable) AND StructKeyExists(Variables.sMetaData[ftable],"methodSingular") ) {
						xField.XmlAttributes["listshowfield"] = makeCompName(Variables.sMetaData[ftable]["methodSingular"]);
						if ( table EQ ftable ) {
							xField.XmlAttributes.listshowfield = "Parent#xField.XmlAttributes.listshowfield#";
						}
					}
				}
				if ( table EQ ftable AND NOT StructKeyExists(xField.XmlAttributes,"urlvar") ) {
					xField.XmlAttributes["urlvar"] = LCase(makeCompName(Variables.sMetaData[ftable]["methodSingular"]));
				}

				if ( StructKeyExists(xField.XmlAttributes,"listshowfield") ) {
					// Add label and has relation fields (if they don't exists)
					if ( NOT ArrayLen( XmlSearch(xDef,"//table[@name='#table#']/field[@name='#xField.XmlAttributes.listshowfield#']") ) ) {
						xLabelField = XmlElemNew(xDef,"field");
						xLabelField.XmlAttributes["name"] = xField.XmlAttributes.listshowfield;
						xLabelField.XmlAttributes["label"] = xField.XmlAttributes.label;
						ArrayAppend(xLabelField.XmlChildren,XmlElemNew(xDef,"relation"));
						xLabelField.XmlChildren[1].XmlAttributes["type"] = "label";
						xLabelField.XmlChildren[1].XmlAttributes["table"] = ftable;
						xLabelField.XmlChildren[1].XmlAttributes["field"] = Variables.sMetaData[ftable]["labelField"];
						xLabelField.XmlChildren[1].XmlAttributes["join-field-local"] = xField.XmlAttributes["name"];
						xLabelField.XmlChildren[1].XmlAttributes["join-field-remote"] = getPrimaryKeyFields(ftable,xDef);
						if ( StructKeyExists(xField.XmlAttributes,"onMissing") ) {
							xLabelField.XmlChildren[1].XmlAttributes["onMissing"] = xField.XmlAttributes["onMissing"];
						}
						if ( ListLen(xLabelField.XmlChildren[1].XmlAttributes["join-field-remote"]) EQ 1 ) {
							ArrayAppend(xTable.XmlChildren,xLabelField);
						}
					}
					if ( NOT ArrayLen( XmlSearch(xDef,"//table[@name='#table#']/field[@name='Has#xField.XmlAttributes.listshowfield#']") ) ) {
						xHasField = XmlElemNew(xDef,"field");
						xHasField.XmlAttributes["name"] = "Has#xField.XmlAttributes.listshowfield#";
						xHasField.XmlAttributes["label"] = "Has #xField.XmlAttributes.label#?";
						ArrayAppend(xHasField.XmlChildren,XmlElemNew(xDef,"relation"));
						xHasField.XmlChildren[1].XmlAttributes["type"] = "has";
						xHasField.XmlChildren[1].XmlAttributes["field"] = xField.XmlAttributes.listshowfield;
						ArrayAppend(xTable.XmlChildren,xHasField);
					}
				}

				// Add Num and Has relation field to ftable (if they don't exist)
				if ( table EQ ftable ) {
					NumField = "NumChild#xTable.XmlAttributes.methodPlural#";
					HasField = "hasChild#xTable.XmlAttributes.methodPlural#";
				} else {
					NumField = "Num#xTable.XmlAttributes.methodPlural#";
					HasField = "has#xTable.XmlAttributes.methodPlural#";
				}
				if ( NOT ArrayLen(XmlSearch(xFTable,"/field[@name='#NumField#']")) ) {
					xNumField = XmlElemNew(xDef,"field");
					xNumField.XmlAttributes["name"] = NumField;
					xNumField.XmlAttributes["label"] = xTable.XmlAttributes.labelPlural;
					if ( table EQ ftable ) {
						xNumField.XmlAttributes.label = "Child #xNumField.XmlAttributes.label#";
					}
					xNumField.XmlAttributes["sebcolumn_type"] = "numeric";
					ArrayAppend(xNumField.XmlChildren,XmlElemNew(xDef,"relation"));
					xNumField.XmlChildren[1].XmlAttributes["type"] = "count";
					xNumField.XmlChildren[1].XmlAttributes["table"] = table;
					xNumField.XmlChildren[1].XmlAttributes["field"] = getPrimaryKeyFields(ftable,xDef);
					xNumField.XmlChildren[1].XmlAttributes["join-field-local"] = getPrimaryKeyFields(ftable,xDef);
					xNumField.XmlChildren[1].XmlAttributes["join-field-remote"] = xField.XmlAttributes["name"];
					if ( StructKeyExists(xField.XmlAttributes,"onRemoteDelete") ) {
						xNumField.XmlChildren[1].XmlAttributes["onDelete"] = xField.XmlAttributes["onRemoteDelete"];
					}
					if ( ListLen(xNumField.XmlChildren[1].XmlAttributes["join-field-local"]) EQ 1 ) {
						ArrayAppend(xFTable.XmlChildren,xNumField);
					}
				}
				if ( NOT ArrayLen(XmlSearch(xFTable,"/field[@name='#HasField#']")) ) {
					xHasField = XmlElemNew(xDef,"field");
					xHasField.XmlAttributes["name"] = HasField;
					xHasField.XmlAttributes["label"] = "Has #xTable.XmlAttributes.labelPlural#?";
					if ( table EQ ftable ) {
						xHasField.XmlAttributes.label = "Has Child #xNumField.XmlAttributes.label#s?";
					}
					xHasField.XmlAttributes["sebcolumn_type"] = "yesno";
					ArrayAppend(xHasField.XmlChildren,XmlElemNew(xDef,"relation"));
					xHasField.XmlChildren[1].XmlAttributes["type"] = "has";
					xHasField.XmlChildren[1].XmlAttributes["field"] = NumField;
					ArrayAppend(xFTable.XmlChildren,xHasField);
				}
			}

			if ( StructKeyExists(Variables.sMetaData, ftable) ) {
				if ( NOT StructKeyExists(Variables.sMetaData[ftable],"childtables") ) {
					Variables.sMetaData[ftable]["childtables"] = "";
				}
				if ( NOT ListFindNoCase(Variables.sMetaData[ftable]["childtables"],table) ) {
					Variables.sMetaData[ftable]["childtables"] = ListAppend(Variables.sMetaData[ftable]["childtables"],table);
				}
			}
		}
	}

	return xDef;
}

private string function getEntityTableName(
	required string entity,
	string prefix,
	xDef,
	boolean ErrorOnFail="true"
) {
	var result = "";
	var axTables = 0;
	var xpath = "";
	var table = "";

	// TODO: find without prefix

	if ( StructKeyExists(Arguments,"xDef") ) {
		applyTableDefaults(Arguments.xDef);
		xpath = "//table";
		if ( StructKeyExists(Arguments,"prefix") ) {
			xpath = "#xpath#[@prefix='#Arguments.prefix#']";
		}
		xpath = "#xpath#[@entity='#Arguments.entity#'][string-length(@name)>0]";

		axTables = XmlSearch(xDef,xpath);
		if ( ArrayLen(axTables) EQ 1 ) {
			result = axTables[1].XmlAttributes["name"];
		}
	}

	if ( NOT Len(result) ) {
		for ( table in Variables.smetaData ) {
			if (
					StructKeyExists(Variables.sMetaData[table],"entity")
				AND	Variables.sMetaData[table]["entity"] EQ Arguments.entity
				AND	(
							NOT StructKeyExists(Arguments,"prefix")
						OR	(
									StructKeyExists(Variables.sMetaData[table],"prefix")
								AND	Variables.sMetaData[table]["prefix"] EQ Arguments.prefix
							)

					)
			) {
				result = ListAppend(result,table);
				break;
			}
		}
	}

	if ( ListLen(result) GT 1 ) {
		result = "";
	}

	if ( Arguments.ErrorOnFail AND NOT Len(result) ) {
		if ( StructKeyExists(Arguments,"prefix") ) {
			throw(message="Unable to determine table for entity #Arguments.entity# with prefix #Arguments.prefix#.",type="Manager");
		} else {
			throw(message="Unable to determine table for entity #Arguments.entity#.",type="Manager");
		}
	}

	return result;
}

private string function getJoinTableName(
	required xDef,
	required string Table1,
	required string Table2
) {
	var result = "";
	var axTable1 = 0;
	var axTable2 = 0;
	var axFind = 0;
	var sTables = {};
	var table = "";
	var OrderedTableNames = "";

	applyTableDefaults(Arguments.xDef);

	axTable1 = XmlSearch(Arguments.xDef,"//table[@name='#Arguments.Table1#']");
	axTable2 = XmlSearch(Arguments.xDef,"//table[@name='#Arguments.Table2#']");
	sTables[Arguments.Table1] = {};
	sTables[Arguments.Table2] = {};

	if ( ArrayLen(axTable1) EQ 1 AND ArrayLen(axTable2) EQ 1 ) {
		sTables[Arguments.Table1]["xTable"] = axTable1[1];
		sTables[Arguments.Table2]["xTable"] = axTable2[1];
	} else {
		throw(message="Unable to find both tables: #Arguments.Table1# and #Arguments.Table2# needed for a join relation.",type="Manager");
	}

	sTables[Arguments.Table1]["name"] = Arguments.Table1;
	sTables[Arguments.Table2]["name"] = Arguments.Table2;
	for ( table in sTables ) {
		if ( StructKeyExists(sTables[table]["xTable"].XmlAttributes,"prefix") ) {
			sTables[table]["prefix"] = sTables[table]["xTable"].XmlAttributes["prefix"];
		} else {
			sTables[Arguments.Table2]["prefix"] = "";
		}
		sTables[table]["Root"] = sTables[table]["name"];
		if ( Len(sTables[table]["prefix"]) AND Left(sTables[table]["name"],Len(sTables[table]["prefix"])) EQ sTables[table]["prefix"] ) {
			sTables[table]["Root"] = ReplaceNoCase(sTables[table]["name"],sTables[table]["prefix"],"","ONE");
		}
	}

	OrderedTableNames = ListSort(StructKeyList(sTables),"text");
	if ( sTables[Arguments.Table1]["prefix"] EQ sTables[Arguments.Table2]["prefix"] ) {
		for ( table in ListToArray(OrderedTableNames) ) {
			result = ListAppend(result,sTables[table]["Root"],"2");
		}
		result = sTables[Arguments.Table1]["prefix"] & result;
	} else {
		for ( table in ListToArray(OrderedTableNames) ) {
			result = ListAppend(result,sTables[table]["name"],"2");
		}
	}

	return result;
}

public string function Security_getPermissions(required string tablename) {
	var result = "";

	if ( StructKeyExists(Variables.sSecurityPermissions,Arguments.tablename) ) {
		result = Variables.sSecurityPermissions[Arguments.tablename];
	}

	return result;
}

private function Security_AddPermissions(required string Permissions) {
	if ( Len(Arguments.Permissions) ) {
		if ( StructKeyExists(Variables,"Security") ) {
			Variables.Security.addPermissions(permissions=Arguments.Permissions,OnExists="update");
		} else {
			if ( NOT StructKeyExists(Variables,"Security_Permissions") ) {
				Variables.Security_Permissions = "";
			}
			Variables.Security_Permissions = ListAppend(Variables.Security_Permissions,Arguments.Permissions);
		}
	}
}

public function Security_Register(required Component) {

	Variables.Security = Arguments.Component;

	if ( StructKeyExists(Variables,"Security_Permissions") ) {
		Security_AddPermissions(Variables.Security_Permissions);
		StructDelete(Variables,"Security_Permissions");
	}

}

private function adjustXmlAddNamesToTypes(required xDef) {
	var axFields = XmlSearch(xDef,"//field[string-length(@type)>0][not(@name)]");
	var xField = 0;
	var xTable = 0;
	var ff = 0;
	var table = "";
	var sType = 0;

	for ( ff=1; ff LTE ArrayLen(axFields); ff++ ) {
		xField = axFields[ff];
		xTable = xField.XmlParent;
		table = xTable.XmlAttributes["name"];
		sType = getTypeData(xField.XmlAttributes.type);
		if ( StructCount(sType) ) {
			if ( StructKeyExists(sType,"defaultFieldName") ) {
				xField.XmlAttributes["name"] = sType["defaultFieldName"];
			} else {
				if ( StructKeyExists(xTable.XmlAttributes,"entity") ) {
					xField.XmlAttributes["name"] = makeCompName(xTable.XmlAttributes["entity"]) & xField.XmlAttributes["type"];
				} else if ( StructKeyExists(xTable.XmlAttributes,"methodSingular") ) {
					xField.XmlAttributes["name"] = makeCompName(xTable.XmlAttributes["methodSingular"]) & xField.XmlAttributes["type"];
				} else if ( StructKeyExists(xTable.XmlAttributes,"labelSingular") ) {
					xField.XmlAttributes["name"] = makeCompName(xTable.XmlAttributes["labelSingular"]) & xField.XmlAttributes["type"];
				} else {
					xField.XmlAttributes["name"] = xField.XmlAttributes["type"];
				}
			}
			if ( StructKeyExists(sType,"defaultFieldLabel") AND NOT StructKeyExists(xField.XmlAttributes,"label") ) {
				xField.XmlAttributes["label"] = sType["defaultFieldLabel"];
			}
		}
	}

	 return Arguments.xDef;
}

private function applyTableDefaults(required xDef) {
	var axTablesRoot = XmlSearch(xDef,"/tables");
	var axTables = 0;
	var ii = 0;
	var key = 0;

	if ( StructCount(axTablesRoot[1].XmlAttributes) ) {
		axTables = XmlSearch(xDef,"/tables/table");
		for ( ii=1; ii LTE ArrayLen(axTables); ii++ ) {
			for ( key in axTablesRoot[1].XmlAttributes ) {
				if ( NOT StructKeyExists(axTables[ii].XmlAttributes,key) ) {
					axTables[ii].XmlAttributes[key] = axTablesRoot[1].XmlAttributes[key];
				}
			}
		}
	}

	return Arguments.xDef;
}

private function applySecurityPermissions(required xDef) {
	var axPermissions = XmlSearch(xDef,"//table[string-length(@permissions)>0]");
	var ii = 0;
	var key = "";

	for ( ii=1; ii LTE ArrayLen(axPermissions); ii++ ) {
		Security_AddPermissions(axPermissions[ii].XmlAttributes["permissions"]);
		if ( StructKeyExists(axPermissions[ii].XmlAttributes,"name") ) {
			if ( StructKeyExists(Variables.sSecurityPermissions,axPermissions[ii].XmlAttributes["name"]) ) {
				for ( key in ListToArray(axPermissions[ii].XmlAttributes.permissions) ) {
					if ( NOT ListFindNoCase(Variables.sSecurityPermissions[axPermissions[ii].XmlAttributes["name"]],key) ) {
						Variables.sSecurityPermissions[axPermissions[ii].XmlAttributes["name"]] = ListAppend(Variables.sSecurityPermissions[axPermissions[ii].XmlAttributes["name"]],key);
					}
				}
			} else {
				Variables.sSecurityPermissions[axPermissions[ii].XmlAttributes["name"]] = axPermissions[ii].XmlAttributes.permissions;
			}
		/*
		} else {
			writeDump(axPermissions[ii]);
			abort;
		*/
		}
	}

	return Arguments.xDef;
}

private function hasPKFields(required xTable) {
	var ff = 0;

	if (
		StructKeyExists(xTable,"field")
		AND
		ArrayLen(xTable.field)
	) {
		for ( ff=1; ff LTE ArrayLen(xTable.field); ff++ ) {
			if (
				StructKeyExists(xTable.field.XmlAttributes,"type")
				AND
				ListFirst(xTable.field.XmlAttributes["type"],":") EQ "pk"
			) {
				return true;
			}
		}
	}

	return false;
}

private function applyEntities(required xDef) {
	var xEntities = XmlSearch(xDef,"//table[string-length(@entity)>0]");
	var ee = 0;
	var prefix = "";
	var base = "";
	var root = "";
	var sEntityTables = {};
	var axFields = 0;
	var ff = 0;
	var axRelations = 0;
	var rr = 0;
	var prefixes = "";
	var permissions = "";
	var table = "";
	var sEntity = 0;

	for ( ee=1; ee LTE ArrayLen(xEntities); ee++ ) {
		root = makeCompName(xEntities[ee].XmlAttributes.entity);
		if ( StructKeyExists(xEntities[ee].XmlAttributes,"prefix") ) {
			prefix = xEntities[ee].XmlAttributes.prefix;
		} else {
			prefix = "";
		}
		if ( Len(prefix) ) {
			prefixes = ListAppend(prefixes,prefix);
		}
		if ( StructKeyExists(xEntities[ee].XmlAttributes,"base") ) {
			base = makeCompName(xEntities[ee].XmlAttributes.base);
		} else {
			base = makeCompName(pluralize(xEntities[ee].XmlAttributes.entity));
		}
		if ( NOT StructKeyExists(xEntities[ee].XmlAttributes,"name") ) {
			xEntities[ee].XmlAttributes["name"] = "#prefix##base#";
		}
		if ( StructKeyExists(xEntities[ee].XmlAttributes,"universal") AND xEntities[ee].XmlAttributes.universal IS true ) {
			xEntities[ee].XmlAttributes["name"] = getUniversalTableName(entity=xEntities[ee].XmlAttributes.entity,tablename=xEntities[ee].XmlAttributes.name);
		}
		if ( StructKeyExists(Variables.sMetaData,xEntities[ee].XmlAttributes["name"]) AND StructKeyExists(Variables.sMetaData[xEntities[ee].XmlAttributes["name"]],"sAttributes") ) {
			StructAppend(xEntities[ee].XmlAttributes,Variables.sMetaData[xEntities[ee].XmlAttributes["name"]]["sAttributes"],"no");
		}
		if ( NOT StructKeyExists(xEntities[ee].XmlAttributes,"labelSingular") ) {
			xEntities[ee].XmlAttributes["labelSingular"] = xEntities[ee].XmlAttributes.entity;
		}
		if ( NOT StructKeyExists(xEntities[ee].XmlAttributes,"labelPlural") ) {
			xEntities[ee].XmlAttributes["labelPlural"] = pluralize(xEntities[ee].XmlAttributes.labelSingular);
		}
		if ( NOT StructKeyExists(xEntities[ee].XmlAttributes,"methodSingular") ) {
			xEntities[ee].XmlAttributes["methodSingular"] = makeCompName(xEntities[ee].XmlAttributes.entity);
		}
		if ( NOT StructKeyExists(xEntities[ee].XmlAttributes,"methodPlural") ) {
			xEntities[ee].XmlAttributes["methodPlural"] = makeCompName(pluralize(xEntities[ee].XmlAttributes.entity));
		}
		if (
			NOT (
				StructKeyExists(xEntities[ee].XmlAttributes,"pkfield")
				OR
				hasPKFields(xEntities[ee])
			)
		) {
			xEntities[ee].XmlAttributes["pkfield"] = "#root#ID";
		}
		if ( NOT StructKeyExists(xEntities[ee].XmlAttributes,"labelField") ) {
			xEntities[ee].XmlAttributes["labelField"] = "#root#Name";
		}
		if ( NOT StructKeyExists(xEntities[ee].XmlAttributes,"folder") ) {
			xEntities[ee].XmlAttributes["folder"] = "#Variables.FileMgr.PathNameFromString(base)#";
			if ( Len(prefix) ) {
				xEntities[ee].XmlAttributes["folder"] = ListPrepend(xEntities[ee].XmlAttributes["folder"],Variables.FileMgr.PathNameFromString(prefix));
			}
		}
		sEntityTables[xEntities[ee].XmlAttributes.entity] = xEntities[ee].XmlAttributes.name;
	}

	// Convert fentity fields to ftable fields
	axFields = XmlSearch(xDef,"//field[string-length(@fentity)>0][not(@ftable)]");
	for ( ff=1; ff LTE ArrayLen(axFields); ff++ ) {
		if ( StructKeyExists(sEntityTables,axFields[ff].XmlAttributes["fentity"]) ) {
			axFields[ff].XmlAttributes["ftable"] = sEntityTables[axFields[ff].XmlAttributes["fentity"]];
		} else {
			// TODO: Find elsewhere or throw exception
		}
	}

	axRelations = XmlSearch(xDef,"//relation[string-length(@entity)>0][not(@table)]");
	for ( rr=1; rr LTE ArrayLen(axRelations); rr++ ) {
		if ( StructKeyExists(sEntityTables,axRelations[rr].XmlAttributes["entity"]) ) {
			axRelations[rr].XmlAttributes["table"] = sEntityTables[axRelations[rr].XmlAttributes["entity"]];
		} else {
			// TODO: Find elsewhere or throw exception
		}
	}

	xEntities = XmlSearch(xDef,"//data[string-length(@entity)>0]");
	for ( ee=1; ee LTE ArrayLen(xEntities); ee++ ) {
		sEntity = {
			"Entity":xEntities[ee].XmlAttributes['entity'],
			"xDef":Arguments.xDef
		};
		if ( StructKeyExists(xEntities[ee].XmlAttributes,"prefix") ) {
			sEntity["prefix"] = xEntities[ee].XmlAttributes['prefix'];
		}

		xEntities[ee].XmlAttributes['table'] = getEntityTableName(ArgumentCollection=sEntity);
	}

	return Arguments.xDef;
}

private function loadDataMgrXml(required xml) {
	var xDef = Arguments.xml;
	var tables = 0;
	var table = "";
	var sTables = {};
	var xFields = 0;
	var ii = 0;
	var xField = 0;
	var fieldname = "";
	var sField = 0;
	var att = 0;

	tables = ArrayToList(GetValueArray(xDef,"//tables/table[string-length(@name)>0]/@name"));

	for ( table in ListToArray(tables) ) {
		sTables[table] = getFieldsStructInternal(transformer="DataMgr",tablename=table);
	}

	xFields = XmlSearch(xDef,"//tables/table[string-length(@name)>0]/field[string-length(@name)>0]");

	// Process fields to alter attributes for DataMgr needs
	for ( ii=1; ii LTE ArrayLen(xFields); ii++ ) {
		xField = xFields[ii];
		table = xField.XmlParent.XmlAttributes["name"];
		fieldname = xField.XmlAttributes["name"];
		if ( StructKeyExists(sTables[table],fieldname) ) {
			// Alter attributes for DataMgr 
			sField = sTables[table][fieldname];
			StructClear(xField.XmlAttributes);
			for ( att in sField ) {
				if ( StructKeyExists(sField,att) AND isSimpleValue(sField[att]) ) {
					xField.XmlAttributes[att] = sField[att];
				}
			}
			xField.XmlAttributes["ColumnName"] = sField["name"];
			StructDelete(xField.XmlAttributes,"name");
			StructDelete(xField.XmlAttributes,"type");
		}
	}

	Variables.DataMgr.loadXml(xDef,true,true);

}

public void function loadXmlStruct(required xml) {
	var xDef = 0;
	var aTables = 0;
	var table = "";
	var aFields = 0;
	var tt = 0;
	var ff = 0;
	var ll = 0;
	var sField = "";
	var key = "";

	if ( isSimpleValue(Arguments.xml) ) {
		xDef = XmlParse(Arguments.xml);
	} else if ( isXMLDoc(Arguments.xml) ) {
		xDef = Arguments.xml;
	} else {
		throw(message="XML argument of loadXmlStruct must be XML.",type="Manager");
	}
	aTables = XmlSearch(xDef,"//table[string-length(@name)>0]");

	// Actually add the tables and fields
	for ( tt=1; tt LTE ArrayLen(aTables); tt++ ) {
		table = aTables[tt].XmlAttributes["name"];
		Variables.sMetaData[table]["sFields"] = {};
		aFields = XmlSearch(xDef,"//table[@name='#table#']//field[string-length(@name)>0]");
		for ( ff=1; ff LTE ArrayLen(aFields); ff++ ) {
			sField = Duplicate(aFields[ff].XmlAttributes);
			sField["tablename"] = table;
			sField["fieldname"] = aFields[ff].XmlAttributes.name;
			// If a relation element is included, make a key for the element
			if ( StructKeyExists(aFields[ff],"relation") ) {
				sField["relation"] = {};
				sField["relation"] = Duplicate(aFields[ff].relation.XmlAttributes);
				if ( StructKeyExists(aFields[ff].relation,"filter") ) {
					sField["relation"]["filters"] = [];
					for ( ll=1; ll LTE ArrayLen(aFields[ff].relation.filter); ll++ ) {
						ArrayAppend(sField["relation"]["filters"],aFields[ff].relation.filter[ll].XmlAttributes);
					}
				}
			}

			// Default folder for file types
			if (
					StructKeyExists(sField,"type")
				AND	ListFindNoCase(Variables.FileTypes,sField.type)
				AND	NOT StructKeyExists(sField,"folder")
			) {
				sField["folder"] = Variables.FileMgr.PathNameFromString(sField["fieldname"]);
			}

			sField["isInTableCreation"] = true;
			setField(ArgumentCollection=sField);
		}
	}

}

private string function fixFileName(
	required string name,
	required string dir,
	numeric maxlength
) {
	var dirdelim = Variables.FileMgr.getDirDelim();
	var result = ReReplaceNoCase(Arguments.name,"[^a-zA-Z0-9_\-\.]","_","ALL");// Remove special characters from file name
	var path = "";

	result = Variables.FileMgr.LimitFileNameLength(Arguments.maxlength,result);

	path = "#dir##dirdelim##result#";

	// If corrected file name doesn't match original, rename it
	if ( Arguments.name NEQ result AND FileExists("#Arguments.dir##dirdelim##Arguments.name#") ) {
		path = Variables.FileMgr.createUniqueFileName(path,Arguments.maxlength);
		result = ListLast(path,dirdelim);
		cffile(action="rename",source="#Arguments.dir##dirdelim##Arguments.name#",destination="#result#");
	}

	return result;
}
</cfscript>

<cffunction name="types" access="public" returntype="string" output="no">

	<cfset var result = "">

	<cfsavecontent variable="result"><cfoutput>
	<types>
		<type name="pk:integer" datatype="number">
			<transform name="sebField" type="numeric" PrimaryKey="true" />
			<transform name="sebColumn" type="numeric" PrimaryKey="true" />
			<transform name="DataMgr" CF_DataType="CF_SQL_INTEGER" PrimaryKey="true" Increment="true" />
		</type>
		<type name="pk:bigint" datatype="number">
			<transform name="sebField" type="numeric" PrimaryKey="true" />
			<transform name="sebColumn" type="numeric" PrimaryKey="true" />
			<transform name="DataMgr" CF_DataType="CF_SQL_BIGINT" PrimaryKey="true" Increment="true" />
		</type>
		<type name="pk:uuid" datatype="text">
			<transform name="sebField" type="text" PrimaryKey="true" />
			<transform name="sebColumn" type="text" PrimaryKey="true" />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" PrimaryKey="true" Special="UUID" />
		</type>
		<type name="fk:integer" datatype="number">
			<transform name="sebField" type="select" more="..." />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_INTEGER" />
		</type>
		<type name="pk:text" datatype="text">
			<transform name="sebField" type="text" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" PrimaryKey="true" />
		</type>
		<type name="fk:text" datatype="text">
			<transform name="sebField" type="select" more="..." />
			<transform name="sebColumn" type="select" more="..." />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" />
		</type>
		<type name="text" datatype="text">
			<transform name="sebField" type="text" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" />
		</type>
		<type name="pk:idstamp" datatype="text">
			<transform name="sebField" type="pkfield" />
			<transform name="sebColumn" type="pkfield" />
			<transform name="DataMgr" CF_DataType="CF_SQL_IDSTAMP" PrimaryKey="true" />
		</type>
		<type name="fk:idstamp" datatype="text">
			<transform name="sebField" type="select" more="..." />
			<transform name="sebColumn" type="select" more="..." />
			<transform name="DataMgr" CF_DataType="CF_SQL_IDSTAMP" />
		</type>
		<type name="idstamp" datatype="text">
			<transform name="sebField" type="text" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_IDSTAMP" />
		</type>
		<type name="string" datatype="text">
			<transform name="sebField" type="text" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" />
		</type>
		<type name="boolean" datatype="boolean">
			<transform name="sebField" type="yesno" />
			<transform name="sebColumn" type="yesno" />
			<transform name="DataMgr" CF_DataType="CF_SQL_BIT" />
		</type>
		<type name="integer" datatype="number">
			<transform name="sebField" type="integer" size="4" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_INTEGER" />
		</type>
		<type name="bigint" datatype="number">
			<transform name="sebField" type="integer" size="12" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_BIGINT" />
		</type>
		<type name="decimal" datatype="decimal">
			<transform name="sebField" type="decimal" size="4" />
			<transform name="sebColumn" type="numeric" />
			<transform name="DataMgr" CF_DataType="CF_SQL_DECIMAL" precision="18" scale="2" />
		</type>
		<type name="money" datatype="number">
			<transform name="sebField" type="money" size="6" />
			<transform name="sebColumn" type="money" />
			<transform name="DataMgr" CF_DataType="CF_SQL_DECIMAL" precision="18" scale="2" />
		</type>
		<type name="float" datatype="number">
			<transform name="sebField" type="text" size="6" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_FLOAT" />
		</type>
		<type name="CreationDate" datatype="date" defaultFieldName="DateCreated" defaultFieldLabel="Date Created">
			<transform name="DataMgr" CF_DataType="CF_SQL_DATE" Special="CreationDate" />
			<transform name="sebColumn" type="date" />
		</type>
		<type name="LastUpdatedDate" datatype="date" defaultFieldName="DateUpdated" defaultFieldLabel="Date Updated">
			<transform name="DataMgr" CF_DataType="CF_SQL_DATE" Special="LastUpdatedDate" />
			<transform name="sebColumn" type="date" />
		</type>
		<type name="date" datatype="date">
			<transform name="sebField" type="date2" />
			<transform name="sebColumn" type="date" />
			<transform name="DataMgr" CF_DataType="CF_SQL_DATE" />
		</type>
		<type name="time" datatype="time">
			<transform name="sebField" type="time" />
			<transform name="sebColumn" type="time" />
			<transform name="DataMgr" CF_DataType="CF_SQL_DATE" />
		</type>
		<type name="file" datatype="text" isFileType="true" Length="120" NameConflict="makeunique">
			<transform name="sebField" type="file" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" />
		</type>
		<type name="image" datatype="text" quality="1.0" isFileType="true" Length="120" NameConflict="makeunique">
			<transform name="sebField" type="image" />
			<transform name="sebColumn" type="image" />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" />
		</type>
		<type name="thumb" datatype="text" quality="1.0" isFileType="true" Length="120" NameConflict="makeunique">
			<transform name="sebField" type="thumb" />
			<transform name="sebColumn" type="image" />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" />
		</type>
		<type name="memo" datatype="text">
			<transform name="sebField" type="textarea" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_LONGVARCHAR" />
		</type>
		<type name="html" datatype="text">
			<transform name="sebField" type="#Variables.wysiwyg#" />
			<transform name="sebColumn" type="html" />
			<transform name="DataMgr" CF_DataType="CF_SQL_LONGVARCHAR" />
		</type>
		<type name="tinymce" datatype="text">
			<transform name="sebField" type="tinymce" />
			<transform name="sebColumn" type="html" />
			<transform name="DataMgr" CF_DataType="CF_SQL_LONGVARCHAR" />
		</type>
		<type name="email" datatype="text" Length="120">
			<transform name="sebField" type="email" />
			<transform name="sebColumn" type="text" />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" />
		</type>
		<type name="password" datatype="text" Length="120">
			<transform name="sebField" type="password" />
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" />
		</type>
		<type name="Sorter" defaultFieldName="ordernum">
			<transform name="sebColumn" type="Sorter" />
			<transform name="DataMgr" CF_DataType="CF_SQL_INTEGER" Special="Sorter" />
		</type>
		<type name="DeletionDate" datatype="date" defaultFieldName="WhenDeleted">
			<transform name="DataMgr" CF_DataType="CF_SQL_DATE" Special="DeletionMark" />
			<transform name="sebColumn" type="delete" />
		</type>
		<type name="DeletionMark" datatype="boolean" defaultFieldName="isDeleted">
			<transform name="DataMgr" CF_DataType="CF_SQL_BIT" Special="DeletionMark" />
			<transform name="sebColumn" type="delete" />
		</type>
		<type name="URL" datatype="text" Length="250">
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" />
			<transform name="sebColumn" type="text" />
			<transform name="sebField" type="url" />
		</type>
		<type name="UUID" datatype="text">
			<transform name="DataMgr" CF_DataType="CF_SQL_VARCHAR" Special="UUID" />
		</type>
		<type name="relation">
			<transform name="sebColumn" type="text" />
			<transform name="sebField" type="text" />
			<transform name="DataMgr" />
		</type>
	</types>
	</cfoutput></cfsavecontent>

	<cfreturn result>
</cffunction>

<cfscript>
public function XmlAsString(required XmlElem) {
	var result = ToString(Arguments.XmlElem);

	// Remove XML encoding (so that this can be embedded in another document)
	result = ReReplaceNoCase(result,"<\?xml[^>]*>","","ALL");

	return result;
}

public struct function getFieldsStruct(
	required string tablename,
	string transformer
) {

	if ( StructCount(Arguments) EQ 1 ) {
		if (
			NOT (
					StructKeyExists(Variables,"cachedata")
				AND	StructKeyExists(Variables.cachedata,Arguments.tablename)
				AND	StructKeyExists(Variables.cachedata[Arguments.tablename],"FieldsStruct")
				AND	isStruct(Variables.cachedata[Arguments.tablename]["FieldsStruct"])
			)
		) {
			Variables.cachedata[Arguments.tablename]["FieldsStruct"] = getFieldsStructInternal(ArgumentCollection=Arguments);
		}
		return Variables.cachedata[Arguments.tablename]["FieldsStruct"];
	} else {
		return getFieldsStructInternal(ArgumentCollection=Arguments);
	}
}

public function getVariables() {
	return Variables;
}

private struct function getFieldsStructInternal(
	required string tablename,
	string transformer
) {
	var sFields = {};
	var aFields = 0;
	var ii = 0;

	aFields = getFieldsArrayInternal(ArgumentCollection=Arguments);

	for ( ii=1; ii LTE ArrayLen(aFields); ii++ ) {
		if ( StructKeyExists(aFields[ii],"name") ) {
			sFields[aFields[ii]["name"]] = aFields[ii];
		}
	}

	return sFields;
}

private string function makeTypeDataKey(
	required string type,
	string transformer
) {
	var result = Arguments.type;

	if ( StructKeyExists(Arguments,"transformer") AND Len(Trim(Arguments.transformer)) ) {
		result = ListAppend(result,Arguments.transformer,":");
	}

	return result;
}

private function manageTableFieldSorts(required string tablename) {

}

private void function notifyEvent(
	required string EventName,
	struct Args,
	result
) {
	
	if ( StructKeyExists(Variables,"Observer") ) {
		Arguments.EventName = "Manager:#Arguments.eventName#";
		Variables.Observer.notifyEvent(ArgumentCollection=Arguments);
	}

}

public struct function StructFromArgs() {
	var sTemp = 0;
	var sResult = {};
	var key = "";

	if ( ArrayLen(Arguments) EQ 1 AND isStruct(Arguments[1]) ) {
		sTemp = Arguments[1];
	} else {
		sTemp = Arguments;
	}

	// set all Arguments into the return struct
	for ( key in sTemp ) {
		if ( StructKeyExists(sTemp, key) ) {
			sResult[key] = sTemp[key];
		}
	}

	return sResult;
}

/**
* Returns an array of of either attribute values or node text values.
* @XML The ColdFusion XML document we are searching.
* @XPath The XPath that will return the XML nodes from which we will be getting the values for our array.
* @NumericOnly Flags whether only numeric values will be selected.
*/
public array function GetValueArray(
	required XML,
	required string XPath,
	boolean NumericOnly="false"
) {
	// Define the local scope.
	var LOCAL = {};

	/*
		Get the matching XML nodes based on the
		given XPath.
	*/
	LOCAL.Nodes = XmlSearch(
		ARGUMENTS.XML,
		ARGUMENTS.XPath
	);


	// Set up an array to hold the returned values.
	LOCAL.Return = [];

	// Loop over the matched nodes.
	for ( LOCAL.Node in LOCAL.Nodes ) {

		/*
			Check to see what kind of value we are getting -
			different nodes will have different values. When
			getting the value, we must also check to see if
			only numeric values are being returned.
		*/
		if (
			StructKeyExists( LOCAL.Node, "XmlText" )
			AND
			(
				(NOT ARGUMENTS.NumericOnly) OR
				IsNumeric( LOCAL.Node.XmlText )
			)
		) {

			// Add the element node text.
			ArrayAppend(
				LOCAL.Return,
				LOCAL.Node.XmlText
			);

		} else if (
			StructKeyExists( LOCAL.Node, "XmlValue" )
			AND
			(
				(NOT ARGUMENTS.NumericOnly)
				OR
				IsNumeric( LOCAL.Node.XmlValue )
			)
		) {

			// Add the attribute node value.
			ArrayAppend(
				LOCAL.Return,
				LOCAL.Node.XmlValue
			);

		}

	}


	// Return value array.
	return LOCAL.Return;
}

/**
* Copies the children of one node to the node of another document.
* @NodeA The node whose children will be added to.
* @NodeB The node whose children will be copied to another document.
*/
public function XmlAppend(
	required NodeA,
	required NodeB
) {
	// Set up local scope.
	var LOCAL = {};

	/*
		Get the child nodes of the originating XML node.
		This will return both tag nodes and text nodes.
		We only want the tag nodes.
	*/
	LOCAL.ChildNodes = ARGUMENTS.NodeB.GetChildNodes();


	// Loop over child nodes.
	for ( LOCAL.ChildIndex=1; LOCAL.ChildIndex LTE LOCAL.ChildNodes.GetLength(); LOCAL.ChildIndex++ ) {


		/*
			Get a short hand to the current node. Remember
			that the child nodes NodeList starts with
			index zero. Therefore, we must subtract one
			from out child node index.
		*/
		LOCAL.ChildNode = LOCAL.ChildNodes.Item(
			JavaCast(
				"int",
				(LOCAL.ChildIndex - 1)
			)
		);

		/*
			Import this noded into the target XML doc. If we
			do not do this first, then COldFusion will throw
			an error about us using nodes that are owned by
			another document. Importing will return a reference
			to the newly created xml node. The TRUE argument
			defines this import as DEEP copy.
		*/
		LOCAL.ChildNode = ARGUMENTS.NodeA.GetOwnerDocument().ImportNode(
			LOCAL.ChildNode,
			JavaCast( "boolean", true )
		);

		/*
			Append the imported xml node to the child nodes
			of the target node.
		*/
		 ARGUMENTS.NodeA.AppendChild(
			LOCAL.ChildNode
		);

	}


	// Return the target node.
	return ARGUMENTS.NodeA;
}

function makeCompName(str) {
	var result = "";
	var find = FindNoCase(" ",result);
	var word = "";
	var ii = 0;

	if ( find ) {
		/* Turn all special characters into spaces */
		str = ReReplaceNoCase(str,"[^a-z0-9]"," ","ALL");

		/* Remove duplicate spaces */
		while ( find GT 0 ) {
			str = ReplaceNoCase(str,"  "," ","ALL");
			find = FindNoCase("  ",str);
		}

		/* Proper case words and remove spaces */
		for ( ii=1; ii LTE ListLen(str," "); ii=ii+1 ) {
			word = ListGetAt(str,ii," ");
			word = UCase(Left(word,1)) & LCase(Mid(word,2,Len(word)-1));
			result = "#result##word#";
		}
	} else {
		result = ReReplaceNoCase(str,"[^a-z0-9]","","ALL");
	}

	return result;
}
/**
 * Tests passed value to see if it is a properly formatted U.S. zip code.
 *
 * @param str 	 String to be checked. (Required)
 * @return Returns a boolean.
 * @author Jeff Guillaume (jeff@kazoomis.com)
 * @version 1, May 8, 2002
 */
function IsZipUS(str) {
	return REFind('^[[:digit:]]{5}(( |-)?[[:digit:]]{4})?$', str);
}
/**
 * Makes a row of a query into a structure.
 *
 * @param query 	 The query to work with.
 * @param row 	 Row number to check. Defaults to row 1.
 * @return Returns a structure.
 * @author Nathan Dintenfass (nathan@changemedia.com)
 * @version 1, December 11, 2001
 */
function QueryRowToStruct(query){
	var row = 1;//by default, do this to the first row of the query
	var ii = 1;//a var for looping
	var cols = listToArray(query.columnList);//the cols to loop over
	var sReturn = {};//the struct to return

	if(arrayLen(Arguments) GT 1) row = Arguments[2];//if there is a second argument, use that for the row number

	//loop over the cols and build the struct from the query row
	for(ii = 1; ii lte arraylen(cols); ii = ii + 1){
		sReturn[cols[ii]] = query[cols[ii]][row];
	}

	return sReturn;//return the struct
}
</cfscript>

</cfcomponent>
