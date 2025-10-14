<cfcomponent displayname="Localizer" extends="com.sebtools.Records" output="no">
<cfscript>
/**
* I initialize and return this component.
* @Locales A comma delimited list of locales to support.
*/
public function init(
	required Manager,
	required string Locales,
	string DefaultLocale="en",
	Settings
) {
	
	if ( NOT ListFindNoCase(Arguments.Locales,Arguments.DefaultLocale) ) {
		Arguments.Locales = ListPrepend(Arguments.Locales,Arguments.DefaultLocale);
	}

	initInternal(ArgumentCollection=Arguments);
	
	Variables.MrECache = CreateObject("component","MrECache").init(
		id="localizer",
		timeSpan=CreateTimeSpan(1,0,0,0)
	);

	Variables.dbfields = "PhraseID,PhraseName";
	
	return This;
}

public string function addPhrase(required string Phrase) {

	if ( NOT StructKeyExists(Arguments,Variables.DefaultLocale) ) {
		Arguments[Variables.DefaultLocale] = Arguments.Phrase;
	}

	Arguments.Phrase = makePhraseKey(Arguments.Phrase);

	if ( hasPhrases(PhraseName=Arguments.Phrase) ) {
		return addPhraseLocales(ArgumentCollection=Arguments);
	} else {
		return savePhrase(ArgumentCollection=Arguments);
	}
}

public function addPhraseLocales(required string Phrase) {
	var qPhrases = 0>
	var sArgs = {}>
	var loc = "">

	Arguments.Phrase = makePhraseKey(Arguments.Phrase)>
	qPhrases = getPhrases(PhraseName=Arguments.Phrase)>

	// If the phrase doesn't exist, add it.
	if ( NOT qPhrases.RecordCount ) {
		return addPhrase(ArgumentCollection=Arguments);
	}

	// Only save translations that don't already exist for this phrase
	for ( loc in ListToArray(Variables.Locales) ) {
		if ( StructKeyHasLen(Arguments,loc) AND NOT Len(qPhrases[loc][1]) ) {
			sArgs[loc] = Arguments.loc;
		}
	}

	// Only save a record if at least one translation was added.
	if ( StructCount(sArgs) ) {
		sArgs["PhraseID"] = qPhrases.PhraseID;
		savePhrase(ArgumentCollection=sArgs);
	}

	return qPhrases.PhraseID;
}

public void function clearCaches() {
	Variables.MrECache.clearCaches();	
}

public string function formatLang(
	required string Locale,
	boolean validate="true"
) {
	var result = ReplaceNoCase(ListFirst(Arguments.Locale),'-','_');

	if ( Arguments.validate AND NOT ListFindNoCase(Variables.Locales,Arguments.Locale) ) {
		// If we can't find the locale given, then use the general version
		result = ListFirst(result,"_");
		// If we still can't find the locale, then it isn't a valid locale for this instance of Localizer.
		if ( NOT ListFindNoCase(Variables.Locales,result) ) {
			throwError('The locale "#Left(Arguments.Locale,5)#" is not a valid locale. Valid locales are: #Variables.Locales#.');
		}
	}

	return result;
}

/**
* I get the requested text in the requested language.
* @remember Create an empty record for the phrase if it doesn't exist.
*/
public string function translate(
	required string Phrase,
	string locale="#Variables.DefaultLocale#",
	boolean remember="false"
) {
	return getTranslation(ArgumentCollection=Arguments);
}

/**
* I get the requested text in the requested language.
* @remember Create an empty record for the phrase if it doesn't exist.
*/
public string function getTranslation(
	required string Phrase,
	string locale="#Variables.DefaultLocale#",
	boolean remember="false"
) {
	var result = "";

	Arguments.locale = formatLang(Arguments.locale);

	result = Variables.MrECache.method(
		id="#Arguments.locale#:#makePhraseKey(Arguments.Phrase)#",
		Component=This,
		MethodName="getTranslation_Live",
		Args="#Arguments#"
	);

	//Handle mustache-style parameters in text.
	if ( ReFindNoCase("{{[\w_]+}}",result) ) {
		//First use provided data
		if ( StructKeyExists(Arguments,"data") AND StructCount(Arguments.data) ) {
			for ( key in Arguments.data) {
				result = ReplaceNoCase(result,"{{#key#}}",Arguments.data[key],"ALL");
			}
		}
		//Then translate the parametered phrases.
		if ( ReFindNoCase("{{[\w_]+}}",result) ) {
			result = getNestedTranslation(result,Arguments.locale);
		}
	}

	return result;
}

/**
* I get the requested text in the requested language.
* @remember Create an empty record for the phrase if it doesn't exist.
*/
public string function getTranslation_Live(
	required string Phrase,
	string locale="#Variables.DefaultLocale#",
	boolean remember="false"
) {
	var qPhrases = getRecords(PhraseName=makePhraseKey(Arguments.Phrase),fieldlist="#Arguments.locale#,#Variables.DefaultLocale#");
	var result = "";

	if ( qPhrases.RecordCount ) {
		if ( Len(qPhrases[Arguments.locale][1]) ) {
			result = qPhrases[Arguments.locale][1];
		} else if ( Len(qPhrases[Variables.DefaultLocale][1]) ) {
			result = qPhrases[Variables.DefaultLocale][1];
		}
	} else if ( Arguments.remember ) {
		addPhrase(Arguments.Phrase);
	}

	if ( NOT Len(Trim(result)) ) {
		result = Arguments.Phrase;
	}

	return result;
}

public boolean function hasPhrases() {

	if ( StructKeyList(Arguments) EQ 1 ) {
		Arguments.PhraseName = Arguments[1];
	}
	if ( StructKeyExists(Arguments,"PhraseName") ) {
		Arguments.PhraseName = makePhraseKey(Arguments.PhraseName);
	}
	
	return hasRecords(ArgumentCollection=Arguments);
}

public string function makePhraseKey(required string string) {
	var result = Trim(Arguments.string);
	
	// Ditch punctuation
	result = REReplaceNoCase(result,"[.,\/##!$%\^&\*;:{}=\-`~()\?']","","All");

	// Turn spaces (or any other non-letters) into underscores
	result = REReplaceNoCase(result,"[^\w]+","_","All");

	// Use a Hash() in place of any key longer than 50.
	if ( Len(result) GT 50 ) {
		result = Hash(result);
	}

	return result;
}

public numeric function savePhrase(required string string) {
	var result = 0;
	var key = "";

	// Make sure locales use "_" syntax.
	for ( key in Arguments ) {
		if ( NOT ListFindNoCase(Variables.dbfields,key) ) {
			Arguments[formatLang(key,false)] = Arguments[key];
		}
	}

	Arguments.PhraseName = Arguments.Phrase;

	result = saveRecord(ArgumentCollection=Arguments);

	clearPhraseCache(Arguments.PhraseName);

	return result;
}

public struct function validatePhrase() {

	if ( NOT isUpdate(ArgumentCollection=Arguments) ) {
		Arguments = validateDefaultLanguage(ArgumentCollection=Arguments);
		Arguments = validatePhraseKey(ArgumentCollection=Arguments);
	}

	return Arguments;
}

public struct function validateDefaultLanguage() {

	if ( NOT StructKeyHasLen(Arguments,Variables.DefaultLocale) ) {
		<cfset throwError("You must provide the phrase in the default language (#Variables.DefaultLocale#).")>
	}

	return Arguments;
}

public struct function validatePhraseKey() {
	// Make sure we have a string for the phrase name.
	if ( NOT StructKeyHasLen(Arguments,"PhraseName") ) {
		Arguments.PhraseName = Arguments[Variables.DefaultLocale];
	}

	Arguments.PhraseName = makePhraseKey(Arguments.PhraseName);

	return Arguments;
}

private void function clearPhraseCache(required string Phrase) {
	var lang = "";

	for ( lang in ListToArray(Variables.Locales) ) {
		Variables.MrECache.clearCaches("#lang#:#Arguments.Phrase#");
		Variables.MrECache.clearCaches("#formatLang(lang)#:#Arguments.Phrase#");
	}

}

private string function getNestedTranslation(
	required string PartialTranslation,
	required string locale
) {
	var result = Arguments.PartialTranslation;
	var resultBefore = "";
	var key = 0;
	var phrase = 0;

	do {
		resultBefore = result;//To see if text was changed in this loop.
		for ( key in REMatch('{{[\w_]+}}', result) ) {
			phrase = ReReplaceNoCase(key,"[{|}]","","ALL");//Need to get the phrase inside the curly braces
			if ( hasPhrases(phrase) ) {//Translate phrase if it exists
				result = ReplaceNoCase(result,key,getTranslation(Phrase=phrase,locale=Arguments.locale),"ALL");
			}
		}
	} while ( result NEQ resultBefore );

	return result;
}
</cfscript>

<cffunction name="xml" access="public" output="yes"><cfset var lang = "">
<tables prefix="locale">
	<table entity="Phrase" methodPlural="Phrases" Specials="CreationDate,LastUpdateDate">
		<field name="isHTML" label="HTML?" type="boolean" default="false" /><cfloop list="#Variables.Locales#" index="lang">
		<field name="#formatLang(lang,false)#" label="#lang#" type="memo" /></cfloop>
	</table>
</tables>
</cffunction>

</cfcomponent>