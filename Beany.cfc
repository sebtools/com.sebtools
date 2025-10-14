<cfcomponent displayname="Beany" output="no">
<cfscript>
/*
* I instantiate and return this object.
* @mutable Are the properties mutable (can they be changed)?
*/

public function init(boolean mutable="true") {

	if ( NOT StructKeyExists(Variables,"Props") ) {
		Variables.Props = {};
	}
	if ( NOT StructKeyExists(Variables,"mutable") ) {
		Variables.mutable = Arguments.mutable;
	}
	StructDelete(Arguments,"mutable");

	initProperties(ArgumentCollection=Arguments);

	return This;
}

/*
* I add a value to a property array.
*/
public function AddToArray(
	required string property,
	required value
) {

	checkMutable(Arguments.property);

	__AddToArray(ArgumentCollection=Arguments);

	return get(Arguments.property);
}

/*
* I add a value to a property string.
*/
public function AddToList(
	required string property,
	required string value,
	string delimiter=","
) {

	checkMutable(Arguments.property);

	__AddToList(ArgumentCollection=Arguments);

	return get(Arguments.property);
}

/*
* I add a value to a property string.
*/
public function AddToString(
	required string property,
	required string value
) {

	checkMutable(Arguments.property);

	__AddToString(ArgumentCollection=Arguments);

	return get(Arguments.property);
}

/*
* I add a value to a property structure.
*/
public function AddToStruct(
	required string property,
	required string key,
	required value,
	boolean overwrite="true"
) {

	checkMutable(Arguments.property);

	__AddToStruct(ArgumentCollection=Arguments);

	return get(Arguments.property);
}

public function dump() {

	return Variables.Props;
}

/*
* I return the value for the property.
*/
public function get(required string property) {
	return Variables.Props[Arguments.property];
}

/*
* I indicate if the property exists.
*/
public boolean function has(required string property) {
	
	return StructKeyExists(Variables.Props,Arguments.property);
}

/*
* I lock this Beany, making it immutable.
*/
public void function lock() {
	
	Variables.mutable = false;

}

/*
* I remove the property from the bean.
*/
public void function remove(requried string property) {
	
	checkMutable(Arguments.property);

	__remove(ArgumentCollection=Arguments);

}

/*
* I set the value for the property.
*/
public function set(
	required string property,
	required value
) {
	checkMutable(Arguments.property);

	__set(ArgumentCollection=Arguments);

	return get(Arguments.property);
}

/*
* I initialize property values.
*/
public function initProperties() {
	var ii = 0;

	for ( ii in Arguments ) {
		if ( NOT StructKeyExists(Variables,ii) ) {
			Variables.Props[ii] = Arguments[ii];
		}
	}
}

/*
* I return a list of properties for the bean.
*/
public string function property_list() {

	return StructKeyList(Variables.Props);
}

function getMissingMethodHandler() {
	var method = Trim(Arguments.missingMethodName);
	var property = ReReplaceNoCase(method,"^(([gs]et)|(has)|(remove))","");
	var action = "";

	if ( Len(property) ) {
		action = Reverse(Replace(Reverse(method), Reverse(property), ""));
	}

	return {action=action,property=property};
}

function onMissingMethod() {
	var sMethod = getMissingMethodHandler(ArgumentCollection=Arguments);
	var fMethod = 0;
	var args = Arguments.missingMethodArguments;

	if ( NOT StructKeyExists(This,sMethod.action) ) {
		throw("No such method.");
	}

	fMethod = This[sMethod.action];

	if ( sMethod.action IS "set" ) {
		sMethod["result"] = fMethod(sMethod.property,args[1]);
	} else {
		sMethod["result"] = fMethod(sMethod.property);
	}

	if ( StructKeyExists(sMethod,"result") ) {
		return sMethod["result"];
	}
}

/*
* I throw an exception when calls are made to change values if the bean is not mutable.
*/
private void function checkMutable(required string property) {
	
	if ( NOT Variables.mutable ) {
		throw(
			type="Beany",
			message="Unable to alter property. Object is not mutable.",
			detail="Unable to alter #Arguments.property# property. Object is not mutable."
		);
	}

}

/*
* I add a value to a property array.
*/
private void function __AddToArray(
	required string property,
	required value
) {
	
	// If the property doesn't already exist, add it as an empty array.
	if ( NOT has(Arguments.property) ) {
		set(Arguments.property,[]);
	}

	// Can only add to arrays.
	if ( NOT isArray(get(Arguments.property)) ) {
		throw(
			type="Beany",
			message="Property is not an array.",
			detail="#Arguments.property# property is not an array."
		);
	}

	// Append the Array.
	ArrayAppend(Variables.Props[Arguments.property],Arguments.value);

}

/*
* I add a value to a property string.
*/
private void function __AddToList(
	required string property,
	required string value,
	string delimiter=","
) {

	// If the property doesn't already exist, add it as an empty string.
	if ( NOT has(Arguments.property) ) {
		set(Arguments.property,"");
	}

	// Can only add to strings.
	if ( NOT isSimpleValue(get(Arguments.property)) ) {
		throw(
			type="Beany",
			message="Property is not a string.",
			detail="#Arguments.property# property is not a string."
		);
	}

	// Append the List.
	Variables.Props[Arguments.property] = ListAppend(get(Arguments.property),Arguments.value,Arguments.delimiter);

}

/*
* I add a value to a property string.
*/
private void function __AddToString(
	required string property,
	required string value
) {
	
	// If the property doesn't already exist, add it as an empty string.
	if ( NOT has(Arguments.property) ) {
		__set(Arguments.property,"");
	}

	// Can only add to strings.
	if ( NOT isSimpleValue(get(Arguments.property)) ) {
		throw(
			type="Beany",
			message="Property is not a string.",
			detail="#Arguments.property# property is not a string."
		);
	}

	// Append the String.
	Variables.Props[Arguments.property] &= Arguments.value;

}

/*
* I add a value to a property structure.
*/
private void function __AddToStruct(
	required string property,
	required string key,
	required value,
	boolean overwrite="true"
) {

	// If the property doesn't already exist, add it as an empty struct.
	if ( NOT has(Arguments.property) ) {
		Variables.Props[Arguments.property] = {};
	}

	// Can only add to structs.
	if ( NOT isStruct(get(Arguments.property)) ) {
		throw(
			type="Beany",
			message="Property is not a struct.",
			detail="#Arguments.property# property is not a struct."
		);
	}

	// Make sure we don't overwrite properties if we are told not to do so.
	if ( Arguments.overwrite OR NOT StructKeyExists(Variables.Props[Arguments.property],key) ) {
		Variables.Props[Arguments.property][Arguments.key] = Arguments.value;
	}

}

/*
* I remove the property from the bean.
*/
private void function __remove(required string property) {

	StructDelete(Variables.Props,Arguments.property);

}

/*
* I set the value for the property.
*/
public void function __set(
	required string property,
	required value
) {
	
	checkMutable(Arguments.property);

	Variables.Props[Arguments.property] = Arguments.value;

}
</cfscript>
</cfcomponent>
