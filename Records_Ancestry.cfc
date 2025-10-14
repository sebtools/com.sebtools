<cfcomponent displayname="Records (Ancestry)" extends="com.sebtools.Records" output="no">

<cfscript>
public string function getAncestors() {
	var sMeta = getMetaStruct();
	var PrimaryKeyName = sMeta.arg_pk;
	var ParentKeyName = "Parent#PrimaryKeyName#";
	var ii = 0;
	var NumRecs = numRecords();
	var sGet = 0;
	var qRecord = 0;
	var result = "";

	Arguments = convertArgs(ArgumentCollection=Arguments);

	sGet = {"#PrimaryKeyName#"=Arguments[PrimaryKeyName]};
	qRecord = getRecord(ArgumentCollection=sGet,fieldlist=ParentKeyName);

	if ( Val(qRecord[ParentKeyName][1]) ) {
		result = qRecord[ParentKeyName][1];
	}
	//Traverse up the tree to find all of the parents (but no more times than records exist)
	while ( ii LT NumRecs AND Val(qRecord[ParentKeyName][1]) ) {
		sGet = {"#PrimaryKeyName#"=qRecord[ParentKeyName][1]};
		qRecord = getRecord(ArgumentCollection=sGet,fieldlist=ParentKeyName);
		//Prepend if there is a parent that isn't already in the list.
		if ( Val(qRecord[ParentKeyName][1]) AND NOT ListFindNoCase(result,qRecord[ParentKeyName][1]) ) {
			result = ListPrepend(result,qRecord[ParentKeyName][1]);
		} else {
			break;
		}
		ii = ii + 1;
	}

	return result;
}

public string function getAncestorNamesParentID(required string AncestorNames) {
	var sMeta = getMetaStruct();
	// The last item on the AncestorNames list will be the label of the direct parent.
	var sRecord = {
		"#sMeta.field_label#"=Trim(ListLast(Arguments.AncestorNames,"|")),
		fieldlist="#sMeta.arg_pk#"
	};
	var qRecord = 0;

	// If no AncesterNames value is passed, then no ancestor (return NULL)
	if ( NOT Len(Arguments.AncestorNames) ) {
		return "";
	}

	if ( ListLen(Arguments.AncestorNames,"|") GT 1 ) {
		sRecord["AncestorNames"] = getAncestorNamesParentNames(Arguments.AncestorNames);
	} else {
		sRecord["AncestorNames"] = "";
	}

	// Find the ancestor record indicated
	qRecord = getRecords(ArgumentCollection=sRecord);

	// If an ancestor record is found, return its id.
	if ( qRecord.RecordCount ) {
		return qRecord[sMeta.arg_pk][1];
	}

	// If no record found, then no ancestor (return NULL)
	return "";
}

public string function getAncestorNamesParentNames(required string AncestorNames) {
	var result = "";

	// If AncestorNames has more than one value then the values before the first will be the AncestorNames for the parent.
	if ( ListLen(Arguments.AncestorNames,"|") GT 1 ) {
		result = ListDeleteAt(
			Arguments.AncestorNames,
			ListLen(
				Arguments.AncestorNames,
				"|"
			),
			"|"
		);
	}

	return result;
}

public string function getAncestorNames(required string Ancestors) {
	var sMeta = getMetaStruct();
	var qAncestors = 0;
	var sAncestor = 0;
	var sAdvSQL = {};
	var OrderBy = "";
	var ii = 0;
	var result = "";
	var sArgs = 0;

	// Put records in order of list of ancestors
	OrderBy = "case #sMeta.pkfields# ";
	for ( ii=1; ii LTE ListLen(Arguments.Ancestors); ii++ ) {
		OrderBy = "#OrderBy# WHEN #ListGetAt(Arguments.Ancestors,ii)# THEN #ii#";
	}
	OrderBy = "#OrderBy# ELSE #ii+1#";
	OrderBy = "#OrderBy# END";

	sAdvSQL["ORDER BY"] = ArrayNew(1);
	ArrayAppend(sAdvSQL["ORDER BY"],OrderBy);

	sArgs = {
		"#sMeta.method_Plural#"=Arguments.Ancestors,
		fieldlist="#sMeta.field_label#",
		AdvSQL=sAdvSQL
	};

	qAncestors = getRecords(ArgumentCollection=sArgs);

	for ( sAncestor in qAncestors ) {
		result = ListAppend(result,sAncestor[sMeta.field_label],"|");
	}
	
	return result;
}

public struct function getFullTree() {
	var sMeta = getMetaStruct();
	var qRecords = getRecords(orderby="AncestorNames",fieldlist="#sMeta.pkfields#,#sMeta.field_label#,AncestorNames");
	var sRecord = 0;
	var sResults = {};
	var node = "";
	var ancestor = "";

	for ( sRecord in qRecords ) {
		sThis = sResults;
		for ( ancestor in ListToArray(sRecord.AncestorNames,"|") ) {
			if ( NOT StructKeyExists(sThis,ancestor) ) {
				sThis[ancestor] = {};
			}
			sThis = sThis[ancestor];
		}
		sThis[LossDetailName][0] = {
			"#sMeta.pkfields#":sRecord[sMeta.pkfields],
			"#sMeta.field_label#":sRecord[sMeta.field_label]
		};
	}

	return sResults;
}

public string function saveRecord() {
	var result = 0;

	result = Super.saveRecord(ArgumentCollection=Arguments);

	setAncestors(result);

	return result;
}

public void function setAncestors() {
	var sMeta = getMetaStruct();
	var sDescend = 0;
	var qDescendants = 0;
	var sDescendant = 0;
	var ancestor = "";

	Arguments = convertArgs(ArgumentCollection=Arguments);

	sDescend = {"Parent#sMeta.arg_pk#"=Arguments[sMeta.arg_pk],fieldlist=sMeta.arg_pk};
	qDescendants = getRecords(ArgumentCollection=sDescend);

	Arguments.Ancestors = getAncestors(Arguments[sMeta.arg_pk]);
	if ( Len(Arguments.Ancestors) ) {
		Arguments.AncestorNames = getAncestorNames(Arguments.Ancestors);
	} else {
		Arguments.AncestorNames = "";
	}

	variables.DataMgr.saveRecord(tablename=variables.table,data=Arguments,fieldlist="#sMeta.arg_pk#,Ancestors,AncestorNames");

	if ( NOT ( StructKeyExists(Arguments,"recurse") AND Arguments.recurse EQ false ) ) {
		for ( sDescendant in qDescendants ) {
			setAncestors(sDescendant[sMeta.arg_pk]);
		}
	}

}

public struct function validateRecord() {
	var sArgs = Super.validateRecord(ArgumentCollection=Arguments);

	sArgs = validateAncestry(ArgumentCollection=sArgs);

	return sArgs;
}

	private struct function convertArgs() {
		var sMeta = getMetaStruct();

		// If primary key argument isn't passed in by name, then get it from the first argument.
		if ( NOT StructKeyExists(Arguments,sMeta.arg_pk) ) {
			Arguments[sMeta.arg_pk] = Arguments[1];
			StructDelete(Arguments,"1");
		}

		return Arguments;
	}

/**
* I make sure that the ancestry can work.
*/
private struct function validateAncestry() {
	var sMeta = getMetaStruct();
	var qBefore = 0;
	var sRec = 0;

	// Make sure that the label doesn't contain a pipe.
	if (
			StructKeyExists(Arguments,smeta.label_Singular)
		AND	isSimpleValue(Arguments[smeta.label_Singular])
		AND	Len(Arguments[smeta.label_Singular])
		AND	Arguments[smeta.label_Singular] CONTAINS "|"
	) {
		Arguments[smeta.label_Singular] = ReplaceNoCase(Arguments[smeta.label_Singular],"|","&##124;","ALL");
	}

	// Allow parent value to be set using ancestor arguments
	if ( NOT StructKeyExists(Arguments,"Parent#sMeta.arg_pk#") ) {
		if ( StructKeyHasLen(Arguments,"Ancestors") ) {
			Arguments["Parent#sMeta.arg_pk#"] = ListLast(Arguments.Ancestors);
		} else if ( StructKeyHasLen(Arguments,"AncestorNames") ) {
			Arguments["Parent#sMeta.arg_pk#"] = getAncestorNamesParentID(Arguments.AncestorNames);
			if ( NOT Val(Arguments["Parent#sMeta.arg_pk#"]) ) {
				StructDelete(Arguments,"Parent#sMeta.arg_pk#");
				if ( StructKeyExists(Arguments,"createMissingAncestors") AND Arguments.createMissingAncestors IS true ) {
					Arguments["Parent#sMeta.arg_pk#"] = invoke(
						This,
						"save#variables.methodSingular#",
						{
							"#smeta.field_label#":ListLast(Arguments.AncestorNames,'|'),
							"AncestorNames":getAncestorNamesParentNames(Arguments.AncestorNames),
							"createMissingAncestors":true
						}
					);
				} else {
					throw(type="#smeta.method_Plural#",message="AncestorNames (#Arguments.AncestorNames#) passed in for which no value was found.");
				}
			}
		}
	}

	// Make sure that a record cannot change its parent (unless specified).
	if ( StructKeyExists(Arguments,"#sMeta.arg_pk#") AND StructKeyExists(Arguments,"Parent#sMeta.arg_pk#") ) {
		sRec = {"#sMeta.arg_pk#"=Arguments[sMeta.arg_pk],fieldlist="Parent#sMeta.arg_pk#"};
		qBefore = getRecord(ArgumentCollection=sRec);

		if (
			qBefore.RecordCount
			AND
			qBefore["Parent#sMeta.arg_pk#"][1] NEQ Arguments["Parent#sMeta.arg_pk#"]
		) {
			if ( NOT ( StructKeyExists(Arguments,"doChangeParent") AND Arguments.doChangeParent IS true ) ) {
				throw(type="#smeta.method_Plural#",message="Parent #LCase(smeta.label_Plural)# may not be altered. If you want to change the parent, then pass in true for the argument 'doChangeParent'.");
			}
		}
	}

	// Make sure than a record is not its own ancestor
	StructDelete(Arguments,"Ancestors");
	StructDelete(Arguments,"AncestorNames");
	if (
			StructKeyExists(Arguments,"#sMeta.arg_pk#")
		AND StructKeyExists(Arguments,"Parent#sMeta.arg_pk#")
		AND	isNumeric(Arguments["#sMeta.arg_pk#"])
		AND	isNumeric(Arguments["Parent#sMeta.arg_pk#"])
	) {
		Arguments.Ancestors = getAncestors(Arguments["Parent#sMeta.arg_pk#"]);
		if ( ( Arguments["Parent#sMeta.arg_pk#"] EQ Arguments["#sMeta.arg_pk#"] OR ListFindNoCase(Arguments.Ancestors,Arguments["#sMeta.arg_pk#"]) ) ) {
			variables.Parent.throwError("A #LCase(sMeta.label_Singular)# cannot be a child of itself.");
		}
	}

	return Arguments;
}
</cfscript>

</cfcomponent>
