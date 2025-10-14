<cfcomponent displayname="File Manager" extends="FileMgr" output="no">

<cffunction name="init" access="public" returntype="FileMgr" output="no" hint="I instantiate and return this object.">
	<cfargument name="UploadPath" type="string" default="" hint="The file path for uploads.">
	<cfargument name="UploadURL" type="string" default="http://s3.amazonaws.com/" hint="The URL path for uploads.">
	<cfargument name="Bucket" type="string" required="true" hint="AWS S3 Bucket name.">
	<cfargument name="Credentials" type="any" required="true" hint="AWS Credentials.">

	<cfset setUpVariables(ArgumentCollection=Arguments)>
	<cfset Variables.StorageMechanism = "S3">

	<!--- Make sure needed S3 credentials exist. --->
	<cfif NOT ( Variables.Credentials.has("AccessKey") AND Variables.Credentials.has("SecretKey") AND Variables.Credentials.has("CanonicalUserID")  )>
		<cfthrow message="S3 FileMgr requires AWS credentials (AccessKey,SecretKey,CanonicalUserID)." type="FileMgr">
	</cfif>

	<cfif NOT Len(Trim(Variables.UploadPath))>
		<cfset Variables.UploadPath = 's3://' & Variables.Credentials.get("AccessKey") & ':' & Variables.Credentials.get("SecretKey") & '@' & Variables.Bucket & '/'>
	</cfif>

	<cfif Variables.UploadURL CONTAINS "s3.amazonaws.com" AND NOT Variables.UploadURL CONTAINS Arguments.Bucket>
		<cfset Variables.UploadURL = UploadURL & Arguments.Bucket & "/">
	</cfif>

	<cfreturn This>
</cffunction>

<cffunction name="convertFolder" access="public" returntype="string" output="no">
	<cfargument name="Folder" type="string" required="yes">
	<cfargument name="delimiter" type="string" default="/">

	<cfreturn LCase(Super.convertFolder(ArgumentCollection=Arguments))>
</cffunction>

<cfscript>
public void function deleteFile(required string FileName, required string Folder) {

	if (this.FileExists(Arguments.FileName, Arguments.folder)) {
		var deleteFilePath = getFilePath(argumentCollection=arguments);
		cffile(action="DELETE", file=deleteFilePath);
		notifyEvent("deleteFile",Arguments);
	}
}

public boolean function fileExists(required string fileName, required string folder) {
	var fileURL = getFileURL(Arguments.fileName, Arguments.folder);
	cfhttp(url=fileURL, method="head");

	return booleanFormat(cfhttp.statusCode contains "200");
}
</cfscript>

<cffunction name="getDirDelim" acess="public" returntype="string" output="no">

	<cfif NOT StructKeyExists(variables,"dirdelim")>
		<cfset variables.dirdelim = "/">
	</cfif>

	<cfreturn variables.dirdelim>
</cffunction>

<cffunction name="makedir" access="public" returntype="any" output="no" hint="I make a directory (if it doesn't exist already).">
	<cfargument name="Directory" type="string" required="yes">

	<cfset Super.makedir(ArgumentCollection=Arguments)>

</cffunction>

<cffunction name="makedir_private" access="private" returntype="any" output="no" hint="I make a directory.">
	<cfargument name="Directory" type="string" required="yes">

	<cfdirectory action="CREATE" directory="#Arguments.Directory#">

</cffunction>

<cffunction name="makeFolder" access="public" returntype="void" output="no">
	<cfargument name="Folder" type="string" required="yes">

	<!--- We don't actually need to make folders on S3. --->
	<cfset var foo = "bar">

</cffunction>

<cffunction name="setFilePermissions" access="public" returntype="void" output="no">
	<cfargument name="destination" type="string" required="yes">

	<cfset StoreSetACL("#Arguments.destination#",getStandardS3Permissions())>

</cffunction>

<cfscript>
public any function uploadFile(
	required string FieldName,
	string Folder,
	string NameConflict="Error",
	string TempDirectory=variables.TempDir
) {
	var destination = getDirectory(argumentCollection=arguments);
	var CFFILE = StructNew();
	var sOrigFile = 0;
	var tempPath = "";
	var serverPath = "";
	var skip = false;
	var dirdelim = '/';
	var result = "";
	var S3Folder = destination;
	var S3FileName = "";
	var S3FileExists = false;

	// Make sure the destination exists.
	if ( StructKeyExists(arguments, "Folder") ) {
		 makeFolder(arguments.Folder);
	}

	// Set default extensions.
	if ( NOT StructKeyExists(arguments, "extensions") ) {
		arguments.extensions = variables.DefaultExtensions;
	}

	// Upload to temp directory.
	if ( StructKeyExists(Form, Arguments.FieldName) ) {
		S3FileName = cleanFileName(getClientFileName(Arguments.FieldName));
		destination = "#destination##S3FileName#";
		// Handle nameconflict resolution
		if (this.fileExists(S3FileName, S3Folder)) {
			switch(arguments.NameConflict) {
				case "error":
					throw(type="FileMgr", message="File already exists at destination.");
					break;
				case "skip":
					return StructNew();
					break;
				case "overwrite":
					// Have to delete the file on S3 before we save the new version
					cffile(action="DELETE", file=destination);
					break;
				case "makeunique":
					destination = createUniqueFileName(destination);
					break;
			}
		}
		if ( StructKeyExists(arguments, "accept") ) {
			if ( ListFindNoCase(arguments.accept, "application/msword") AND NOT ListFindNoCase(arguments.accept, "application/unknown") ) {
				arguments.accept = ListAppend(arguments.accept, "application/unknown");
			}
			if ( ListFindNoCase(arguments.accept, "application/vnd.ms-excel") AND NOT ListFindNoCase(arguments.accept, "application/octet-stream") ) {
				arguments.accept = ListAppend(arguments.accept, "application/octet-stream");
			}
			cffile(action="UPLOAD", filefield=Arguments.FieldName, destination=destination, nameconflict=Arguments.NameConflict, result="CFFILE", accept=arguments.accept);
		} else {
			cffile(action="UPLOAD", filefield=Arguments.FieldName, destination=destination, nameconflict=Arguments.NameConflict, result="CFFILE");
		}
	} else {
		cffile(destination=Arguments.TempDirectory, source=Arguments.FieldName, action="copy", result="CFFILE");
	}
	serverPath = ListAppend(CFFILE.ServerDirectory, CFFILE.ServerFile, getDirDelim());

	// Check file extension
	if (
			Len(arguments.extensions)
		AND	NOT ListFindNoCase(arguments.extensions, ListLast(serverPath, "."))
	) {
		// Bad file extension.  Delete file.
		cffile(action="DELETE", file=serverPath);
		return StructNew();
	}

	StoreSetMetadata(serverPath, convertS3MetaFromCFFILE(CFFILE));

	// set permissions on the newly created file on S3
	setFilePermissions(serverPath);

	CFFILE.ServerDirectory = getDirectoryFromPath(serverPath);
	CFFILE.ServerFile = getFileFromPath(serverPath);
	CFFILE.ServerFileName = ReReplaceNoCase(CFFILE.ServerFile, "\.#CFFILE.SERVERFILEEXT#$", "");

	if ( StructKeyExists(arguments, "return") AND isSimpleValue(arguments.return) ) {
		if ( arguments.return EQ "name" ) {
			arguments.return = "ServerFile";
		}
		if ( StructKeyExists(CFFILE, arguments.return) ) {
			result = CFFILE[arguments.return];
			if ( isSimpleValue(result) AND isSimpleValue(variables.dirdelim) ) {
				result = ListLast(result, variables.dirdelim);
			}
		}
	} else {
		result = CFFILE;
	}

	return result;
}
</cfscript>

<cffunction name="writeFile" access="public" returntype="string" output="no" hint="I save a file.">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Contents" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var destination = Super.writeFile(ArgumentCollection=Arguments)>

	<!--- set permissions on the newly created file on S3 --->
	<cfset setFilePermissions(destination)>

	<cfreturn destination>
</cffunction>

<cffunction name="writeBinaryFile" access="public" returntype="string" output="no" hint="I save a file.">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Contents" type="binary" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var destination = Super.writeBinaryFile(ArgumentCollection=Arguments)>

	<!--- set permissions on the newly created file on S3 --->
	<cfset setFilePermissions(destination)>

	<cfreturn destination>
</cffunction>

<cffunction name="getStandardS3Permissions" access="private" returntype="array" output="no">
	<cfset var perms = [{group="all", permission="read"},{id="#Variables.Credentials.get('CanonicalUserID')#", permission="full_control"}]>
	<cfreturn perms>
</cffunction>

<cffunction name="convertS3MetaFromCFFILE" access="private" returntype="struct" output="no">
	<cfargument name="CFFILE" type="struct" required="yes">

	<cfset var sResult = {
		last_modified=GetHTTPTimeString(Arguments.CFFILE.TIMELASTMODIFIED),
		date=GetHTTPTimeString(Arguments.CFFILE.TIMECREATED),
		content_length=JavaCast("String",Arguments.CFFILE.FILESIZE),
		content_type=getMimeType(Arguments.CFFILE.ServerFile)
	}>

	<!--- 	OTHER KEYS:
			owner=
			etag=
			content_encoding=
			content_disposition=
			content_language=
			content_md5=
			md5_hash=
	 --->

	<cfreturn sResult>
</cffunction>

<cffunction name="getClientFileName" returntype="string" output="false" hint="">
    <cfargument name="fieldName" required="true" type="string" hint="Name of the Form field" />

    <cfset var tmpPartsArray = Form.getPartsArray() />

    <cfif IsDefined("tmpPartsArray")>
        <cfloop array="#tmpPartsArray#" index="local.tmpPart">
            <cfif local.tmpPart.isFile() AND local.tmpPart.getName() EQ arguments.fieldName> <!---   --->
                <cfreturn local.tmpPart.getFileName() />
            </cfif>
        </cfloop>
    </cfif>

    <cfreturn "" />
</cffunction>
</cfcomponent>
