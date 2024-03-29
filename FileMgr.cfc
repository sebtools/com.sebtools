<!--- 1.6 (Build 17) --->
<!--- Last Updated: 2011-12-14 --->
<!--- Information: sebtools.com --->
<cfcomponent displayname="File Manager">
<!--- %%Handle folders w/o write permission --->
<cffunction name="init" access="public" returntype="FileMgr" output="no" hint="I instantiate and return this object.">
	<cfargument name="UploadPath" type="string" required="yes" hint="The file path for uploads.">
	<cfargument name="UploadURL" type="string" default="" hint="The URL path for uploads.">
	<cfargument name="Observer" type="any" required="no">

	<cfset setUpVariables(ArgumentCollection=Arguments)>
	<cfset Variables.StorageMechanism = "local">

	<cfset makedir(Variables.UploadPath)>

	<cfif StructKeyExists(Arguments,"Observer")>
		<cfset Variables.Observer = Arguments.Observer>
	</cfif>

	<cftry>
		<cfset Variables.MrECache = CreateObject("component","MrECache").init("FileMgr",CreateTimeSpan(2,0,0,0))>
	<cfcatch>
	</cfcatch>
	</cftry>

	<cfreturn This>
</cffunction>

<cffunction name="setUpVariables" access="private" returntype="void" output="no">

	<cfset var key = "">

	<cfloop collection="#Arguments#" item="key">
		<cfset Variables[key] = Arguments[key]>
		<cfif isObject(Arguments[key])>
			<cfset This[key] = Arguments[key]>
		</cfif>
	</cfloop>

	<cfset getDirDelim()>
	<cfset variables.TempDir = GetTempDirectory()>

	<cfset This["getDirectoryList"] = getMyDirectoryList>
	<cfset variables["getDirectoryList"] = getMyDirectoryList>
	<cfset This["DirectoryList"] = getMyDirectoryList>
	<cfset variables["DirectoryList"] = getMyDirectoryList>

	<cfset variables.DefaultExtensions = "ai,asx,avi,bmp,csv,dat,doc,docx,eps,fla,flv,gif,html,ico,jpeg,jpg,m4a,mov,mp3,mp4,mpa,mpg,mpp,pdf,png,pps,ppsx,ppt,pptx,ps,psd,qt,ra,ram,rar,rm,rtf,svg,swf,tif,txt,vcf,vsd,wav,wks,wma,wps,xls,xlsx,xml">
</cffunction>

<cffunction name="getDefaultExtensions" acess="public" returntype="string" output="no">
	<cfreturn variables.DefaultExtensions>
</cffunction>

<cffunction name="getDirDelim" acess="public" returntype="string" output="no">

	<cfset var result = "/">

	<cfif NOT StructKeyExists(variables,"dirdelim")>
		<cftry>
			<cfset variables.dirdelim = CreateObject("java", "java.io.File").separator>
		<cfcatch>
			<cftry>
				<cfif Server.OS.name CONTAINS "Windows">
					<cfset variables.dirdelim = "\">
				<cfelse>
					<cfset variables.dirdelim = "/">
				</cfif>
			<cfcatch>
				<cfif getCurrentTemplatePath() CONTAINS "/">
					<cfset variables.dirdelim = "/">
				<cfelse>
					<cfset variables.dirdelim = "\">
				</cfif>
			</cfcatch>
			</cftry>
		</cfcatch>
		</cftry>
	</cfif>

	<cfset result = variables.dirdelim>

	<cfreturn result>
</cffunction>

<cffunction name="getMimeType" acess="public" returntype="string" output="no" hint="I return the mime-type for the given file (can be relative path, absolute path, or just the file name).">
	<cfargument name="FileName" type="string" required="true">

	<cfset var ext = ListLast(Arguments.FileName,".")>

	<cfset loadMimeTypes()>

	<cfif StructKeyExists(Variables.sTypes,ext)>
		<cfreturn Variables.sTypes[ext]>
	<cfelse>
		<cfreturn "">
	</cfif>
</cffunction>

<cffunction name="getStorageMechanism" acess="public" returntype="string" output="no" hint="I indicate how FileMgr is storing files.">
	<cfreturn Variables.StorageMechanism>
</cffunction>

<cffunction name="LimitFileNameLength" acess="public" returntype="string" output="no">
	<cfargument name="Length" type="numeric" required="true">
	<cfargument name="Root" type="string" required="true">
	<cfargument name="Suffix" type="string" default="">

	<cfset var FileName = "">
	<cfset var Dir = "">
	<cfset var result = "">
	<cfset var LeftLength = 0>

	<cfif Arguments.Length EQ 0>
		<cfset Arguments.Length = 1000>
	</cfif>

	<cfif arguments.Length GT 0>
		<cfif Len(arguments.Suffix) EQ 0 AND ListLen(arguments.Root,".") GT 1>
			<cfset arguments.Suffix = "." & ListLast(arguments.Root,".")>
			<cfset arguments.Root = ListDeleteAt(arguments.Root,ListLen(arguments.Root,"."),".")>
		</cfif>

		<cfset result = "#arguments.Root##arguments.Suffix#">
		<cfset FileName = getFileFromPath(result)>
		<cfif ( result NEQ FileName )>
			<cfset arguments.Root = getFileFromPath(arguments.Root)>
			<cfset Dir = getDirectoryFromPath(result)>
		</cfif>

		<cfif Len(arguments.Suffix) GTE arguments.Length>
			<cfthrow message="Suffix (#arguments.Suffix#) is too long for file length limit (#arguments.Length#)">
		</cfif>

		<cfif Len(FileName) GT arguments.Length>
			<cfset LeftLength = arguments.Length - Len(arguments.Suffix) - 1>
			<cfif LeftLength GT 0>
				<cfset FileName = Left(arguments.Root,LeftLength) & "~" & arguments.Suffix>
			<cfelse>
				<cfset FileName = "~" & arguments.Suffix>
			</cfif>
		</cfif>

		<cfset result = Dir & FileName>
	<cfelse>
		<cfset result = arguments.Root & arguments.Suffix>
	</cfif>

	<cfreturn result>
</cffunction>

<cffunction name="loadMimeTypes" access="public" returntype="any" output="false">

	<cfset var CFHTTP = 0>
	<cfset var sMimes = 0>
	<cfset var key = "">

	<cfif NOT StructKeyExists(Variables,"sTypes")>
		<cfif StructKeyExists(Variables,"MrECache")>
			<cfset Variables.sTypes = Variables.MrECache.meth(
				Component=This,
				MethodName="loadMimeTypes_RealTime"
			)>
		<cfelse>
			<cfset loadMimeTypes_RealTime()>
		</cfif>
	</cfif>

	<cfreturn Variables.sTypes>
</cffunction>

<cffunction name="loadMimeTypes_RealTime" access="public" returntype="any" output="false">

	<cfset var CFHTTP = 0>
	<cfset var sMimes = 0>
	<cfset var key = "">
	<cfset var ii = 0>
	<cfset var filename = "mime-db.json">

	<cfif NOT StructKeyExists(Variables,"sTypes")>
		<cfset Variables.sTypes = {}>

		<cfhttp
			method="get"
			result="CFHTTP"
			url="https://cdn.rawgit.com/jshttp/mime-db/v1.30.0/db.json">
		</cfhttp>

		<cfscript>
		if ( isJSON(CFHTTP.FileContent) ) {
			sMimes = DeserializeJSON(CFHTTP.FileContent);
			/* Save the JSON locally in case we can't reach it remotely later. */
			if ( NOT FileExists(getFilePath(filename)) ) {
				writeFile(filename,CFHTTP.FileContent);
			}
		} else if ( FileExists(getFilePath(filename)) ) {
			/* If we fail to get the JSON locally, we'll use our saved copy (if we have one). */
			sMimes = DeserializeJSON(readFile(filename));
		}

		//An error here means that the JSON retrieval failed both remotely and didn't exist locally.
		for ( key in sMimes ) {
			if ( StructKeyExists(sMimes[key],"extensions") AND ArrayLen(sMimes[key]["extensions"]) ) {
				for ( ii=1; ii LTE ArrayLen(sMimes[key]["extensions"]); ii++ ) {
					Variables.sTypes[sMimes[key]["extensions"][ii]] = key;
				}
			}
		}
		</cfscript>

	</cfif>

	<cfreturn Variables.sTypes>
</cffunction>

<cffunction name="makeFileCopy" access="public" returntype="string" output="no" hint="I make a copy of a file and return the new file name.">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var path_old = getFilePath(argumentCollection=arguments)>
	<cfset var path_new = createUniqueFileName(path_old)>

	<cffile action="copy" source="#path_old#" destination="#path_new#">

	<cfreturn ListLast(path_new,variables.dirdelim)>
</cffunction>

<cffunction name="copyFiles" access="public" returntype="void" output="no" hint="I copy files from one folder to another.">
	<cfargument name="from" type="string" required="yes">
	<cfargument name="to" type="string" required="yes">
	<cfargument name="overwrite" type="boolean" default="false">

	<cfset var dir_from = getDirectory(arguments.from)>
	<cfset var dir_to = getDirectory(arguments.to)>
	<cfset var qFiles = getDirectoryList(directory=dir_from)>

	<cfloop query="qFiles">
		<cfif arguments.overwrite OR NOT FileExists("#dir_to##name#")>
			<cffile action="copy" source="#dir_from##name#" destination="#dir_to##name#">
			<cfset notifyEvent(
				"copyFiles:file",
				StructFromArgs(source="#dir_from##name#",destination="#dir_to#")
			)>
		</cfif>
	</cfloop>

	<cfset notifyEvent("copyFiles",Arguments)>

</cffunction>

<cffunction name="deleteFile" access="public" returntype="any" output="no" hint="I delete the given file.">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset Arguments.destination = getFilePath(argumentCollection=arguments)>

	<cfif FileExists(Arguments.destination)>
		<cfset FileDelete(Arguments.destination)>
		<cfset notifyEvent("deleteFile",Arguments)>
	</cfif>

</cffunction>

<cffunction name="getFolderList" output="false" returnType="query">
	<cfargument name="Folder" type="string" required="true">

	<cfset Arguments.directory = getDirectory(Arguments.Folder)>

	<cfreturn getMyDirectoryList(ArgumentCollection=Arguments)>
</cffunction>

<!---
 Mimics the cfdirectory, action=&quot;list&quot; command.
 Updated with final CFMX var code.
 Fixed a bug where the filter wouldn't show dirs.

 @param directory 	 The directory to list. (Required)
 @param filter 	 Optional filter to apply. (Optional)
 @param sort 	 Sort to apply. (Optional)
 @param recurse 	 Recursive directory list. Defaults to false. (Optional)
 @return Returns a query.
 @author Raymond Camden (ray@camdenfamily.com)
 @version 2, April 8, 2004
--->
<cffunction name="getMyDirectoryList" output="false" returnType="query">
	<cfargument name="directory" type="string" required="true">
	<cfargument name="filter" type="string" required="false" default="">
	<cfargument name="sort" type="string" required="false" default="">
	<cfargument name="recurse" type="boolean" required="false" default="false">
	<!--- temp vars --->
	<cfargument name="dirInfo" type="query" required="false">
	<cfargument name="thisDir" type="query" required="false">
	<!--- more vars --->
	<cfargument name="exclude" type="string" default="">

	<cfset var delim = variables.dirdelim>
	<cfset var ScriptName = 0>
	<cfset var isExcluded = false>
	<cfset var exdir = false>
	<cfset var qDirs = 0>
	<cfset var qFiles = 0>
	<cfset var cols = "attributes,datelastmodified,mode,name,size,type,directory">
	<cfset var sDirectoryAttributes = {name="qFiles",directory="#arguments.directory#",type="file"}>
	<cfset var replacer = ReplaceNoCase(Arguments.directory, Variables.UploadPath, "", "ONE")>

	<cfif Right(arguments.directory,1) NEQ delim>
		<cfset arguments.directory = "#arguments.directory##delim#">
	</cfif>

	<cfif NOT StructKeyExists(arguments,"dirInfo")>
		<cfset arguments.dirInfo = QueryNew(cols)>
	</cfif>

	<cfif Len(Arguments.sort)>
		<cfset sDirectoryAttributes["sort"] = Arguments.sort>
	</cfif>

	<cfif Len(Arguments.filter)>
		<cfset sDirectoryAttributes["filter"] = Arguments.filter>
	</cfif>

	<cfdirectory attributeCollection="#sDirectoryAttributes#">

	<cfif arguments.recurse>
		<cfdirectory name="qDirs" directory="#arguments.directory#" sort="#sort#" type="dir">
		<cfloop query="qDirs">
			<cfif type IS "dir">
				<cfif StructKeyExists(variables,"instance") AND StructKeyExists(variables.instance,"RootPath")>
					<cfset ScriptName = "/" & ReplaceNoCase(ReplaceNoCase("#arguments.directory##name#",variables.instance.RootPath,""),"\","/","ALL")>
				</cfif>
				<cfset isExcluded = false>
				<cfif Len(arguments.exclude)>
					<cfloop list="#arguments.exclude#" index="exdir">
						<cfif
								( Len(ScriptName) AND ListLen(exdir,"/") EQ 1 AND exdir EQ ListFindNoCase("#ScriptName#/",exdir,"/") )
							OR	( Len(ScriptName) AND Len(exdir) AND Left(ScriptName,Len(exdir)) EQ exdir )
							OR	( Len(ScriptName) AND Len(exdir) AND Left(exdir,Len(ScriptName)) EQ ScriptName )
							OR	( exdir EQ name )
						>
							<cfset isExcluded = true>
						</cfif>
					</cfloop>
				</cfif>
				<cfif NOT isExcluded>
					<cfset getMyDirectoryList(directory=directory & name,filter=filter,sort=sort,recurse=true,dirInfo=arguments.dirInfo,exclude=exclude)>
				</cfif>
			</cfif>
		</cfloop>
	</cfif>
	<cfoutput query="qFiles">
		<cfset QueryAddRow(arguments.dirInfo)>
		<cfset QuerySetCell(arguments.dirInfo,"attributes",attributes)>
		<cfset QuerySetCell(arguments.dirInfo,"datelastmodified",datelastmodified)>
		<cfset QuerySetCell(arguments.dirInfo,"mode",mode)>
		<cfset QuerySetCell(arguments.dirInfo,"name",ReplaceNoCase(name,replacer,"","ONE"))>
		<cfset QuerySetCell(arguments.dirInfo,"size",size)>
		<cfset QuerySetCell(arguments.dirInfo,"type",type)>
		<cfset QuerySetCell(arguments.dirInfo,"directory",arguments.directory)>
	</cfoutput>

	<cfreturn arguments.dirInfo>
</cffunction>

<cffunction name="FileNameFromString" access="public" returntype="string" output="no">
	<cfargument name="string" type="string" required="yes">
	<cfargument name="extensions" type="string" default="cfm,htm,html">

	<cfset var exts = arguments.extensions>
	<cfset var result = "">
	<cfset var ext = ListLast(arguments.string,".")>

	<cfif Len(ext) AND ListFindNoCase(exts,ext) AND (Len(arguments.string)-Len(ext)-1) GT 0>
		<cfset arguments.string = Left(arguments.string,Len(arguments.string)-Len(ext)-1)>
	</cfif>

	<cfset result = PathNameFromString(arguments.string)>

	<cfif Len(result)>
		<cfif Len(ext) AND ListFindNoCase(exts,ext)>
			<cfset result = "#result#.#ext#">
		<cfelse>
			<cfset result = "#result#.#ListFirst(exts)#">
		</cfif>
	</cfif>

	<cfreturn LCase(result)>
</cffunction>

<cffunction name="getDelimiter" access="public" returntype="string" output="no">
	<cfreturn variables.dirdelim>
</cffunction>

<cffunction name="getDirectory" access="public" returntype="string" output="no">
	<cfargument name="Folder" type="string" required="no">

	<cfset var result = variables.UploadPath>

	<cfif StructKeyExists(arguments,"Folder")>
		<cfset arguments.Folder = convertFolder(arguments.Folder,variables.dirdelim)>
		<cfif len(result) gt 1>
			<cfif Right(result,1) EQ variables.dirdelim>
				<cfset result = Left(result,Len(result)-1)>
			</cfif>
		</cfif>
		<cfif DirectoryExists(arguments.Folder)>
			<cfset result = arguments.Folder>
		<cfelse>
			<cfset result = ListAppend(result,arguments.Folder,variables.dirdelim)>
		</cfif>
	</cfif>

	<cfif Right(result,1) NEQ variables.dirdelim>
		<cfset result = "#result##variables.dirdelim#">
	</cfif>

	<cfreturn result>
</cffunction>

<cffunction name="getFileLen" access="public" returntype="numeric" output="no">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var result = 0>
	<cfset var path = getDirectory(argumentCollection=arguments)>
	<cfset var qFiles = 0>

	<cfdirectory action="LIST" directory="#path#" name="qFiles" filter="#arguments.FileName#">

	<cfloop query="qFiles">
		<cfif Name EQ arguments.FileName>
			<cfset result = size>
		</cfif>
	</cfloop>

	<cfreturn result>
</cffunction>

<cffunction name="getFilePath" access="public" returntype="string" output="no">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Folder" type="string" default="">

	<cfset var result = "">
	<cfset var FileName_Clean = cleanFileName(arguments.FileName)>

	<cfif ListLen(Arguments.FileName,variables.dirdelim) GT 1 AND FileExists(Arguments.FileName)>
		<cfset result = Arguments.FileName>
	<cfelse>
		<cfset result = getDirectory(arguments.Folder) & arguments.FileName>
		<cfif ( arguments.FileName NEQ FileName_Clean ) AND NOT FileExists(result)>
			<cfset result = getDirectory(arguments.Folder) & cleanFileName(arguments.FileName)>
		</cfif>
	</cfif>

	<cfreturn result>
</cffunction>

<cffunction name="getFileURL" access="public" returntype="string" output="no">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var result = variables.UploadURL>

	<cfif StructKeyExists(arguments,"Folder")>
		<cfset result = ListAppend(result,convertFolder(arguments.Folder,"/"),"/")>
	</cfif>
	<cfset result = ListAppend(result,arguments.FileName,"/")>

	<cfset result = ReplaceNoCase(result,"//","/","ALL")>
	<cfset result = ReReplaceNoCase(result,"^(\w+:)/","\1//","ALL")>

	<cfreturn result>
</cffunction>

<cffunction name="getUploadPath" access="public" returntype="string" output="no">
	<cfreturn variables.UploadPath>
</cffunction>

<cffunction name="getUploadURL" access="public" returntype="string" output="no">
	<cfreturn variables.UploadURL>
</cffunction>

<cffunction name="makedir" access="public" returntype="any" output="no" hint="I make a directory (if it doesn't exist already).">
	<cfargument name="Directory" type="string" required="yes">

	<cfset var parent = "">

	<cfif NOT DirectoryExists(Arguments.Directory) AND ListLen(Arguments.Directory,variables.dirdelim)>
		<cfset parent = ListDeleteAt(Arguments.Directory,ListLen(Arguments.Directory,variables.dirdelim),variables.dirdelim)>
		<cfif NOT DirectoryExists(parent)>
			<cfset makedir(parent)>
		</cfif>
		<cfset makedir_private(Arguments.Directory)>
		<cfset notifyEvent("makedir",Arguments)>
	</cfif>

</cffunction>

<cffunction name="makedir_private" access="private" returntype="any" output="no" hint="I make a directory.">
	<cfargument name="Directory" type="string" required="yes">

	<cfdirectory action="CREATE" directory="#Arguments.Directory#">

</cffunction>

<cffunction name="makeFolder" access="public" returntype="void" output="no">
	<cfargument name="Folder" type="string" required="yes">

	<cfset makedir(getDirectory(Arguments.Folder))>

</cffunction>

<cffunction name="PathNameFromString" access="public" returntype="string" output="false" hint="">
	<cfargument name="string" type="string" required="yes">

	<cfset var reChars = "([0-9]|[a-z]|[A-Z])">
	<cfset var ii = 0>
	<cfset var result = "">

	<cfloop index="ii" from="1" to="#Len(string)#" step="1">
		<cfif REFindNoCase(reChars, Mid(string,ii,1))>
			<cfset result = result & Mid(string,ii,1)>
		<cfelse>
			<cfset result = result & "-">
		</cfif>
	</cfloop>

	<cfset result = REReplaceNoCase(result, "_{2,}", "_", "ALL")>
	<cfset result = REReplaceNoCase(result, "-{2,}", "-", "ALL")>

	<cfset result = ReplaceNoCase(result,"-"," ","ALL")>
	<cfset result = ReplaceNoCase(Trim(result)," ","-","ALL")>

	<cfreturn LCase(result)>
</cffunction>

<cffunction name="readBinaryFile" access="public" returntype="binary" output="no" hint="I return the contents of a file.">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var destination = getFilePath(argumentCollection=arguments)>
	<cfset var result = "">

	<cffile action="readBinary" file="#destination#" variable="result">

	<cfreturn result>
</cffunction>

<cffunction name="readFile" access="public" returntype="string" output="no" hint="I return the contents of a file.">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var destination = getFilePath(argumentCollection=arguments)>
	<cfset var result = "">

	<cffile action="READ" file="#destination#" variable="result">

	<cfreturn result>
</cffunction>

<cffunction name="writeFile" access="public" returntype="string" output="no" hint="I save a file.">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Contents" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var destination = getFilePath(argumentCollection=arguments)>

	<cfif StructKeyExists(arguments,"Folder")>
		<cfset makeFolder(arguments.Folder)>
	</cfif>

	<cffile action="WRITE" file="#destination#" output="#arguments.Contents#" addnewline="no">

	<cfset notifyEvent("writeFile",Arguments)>

	<cfreturn destination>
</cffunction>

<cffunction name="writeBinaryFile" access="public" returntype="string" output="no" hint="I save a file.">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Contents" type="binary" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var destination = getFilePath(argumentCollection=arguments)>

	<cfif StructKeyExists(arguments,"Folder")>
		<cfset makeFolder(arguments.Folder)>
	</cfif>

	<cffile action="WRITE" file="#destination#" output="#arguments.Contents#" addnewline="no">

	<cfset notifyEvent("writeBinaryFile",Arguments)>

	<cfreturn destination>
</cffunction>

<cffunction name="addLine" access="public" returntype="string" output="no" hint="I add a line to a file.">
	<cfargument name="FileName" type="string" required="yes">
	<cfargument name="Contents" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">

	<cfset var result = "">
	<cfset var cr = "
">

	<cfset Arguments.Contents = Trim(Arguments.Contents)>

	<cfif Len(Arguments.Contents)>
		<cfset Arguments.Contents =	readFile(ArgumentCollection=Arguments) & cr & Arguments.Contents>
		<cfset result = writeFile(ArgumentCollection=Arguments)>
	<cfelse>
		<cfset result = getFilePath(argumentCollection=arguments)>
	</cfif>

	<cfreturn result>
</cffunction>

<cffunction name="uploadFile" access="public" returntype="any" output="no">
	<cfargument name="FieldName" type="string" required="yes">
	<cfargument name="Folder" type="string" required="no">
	<cfargument name="NameConflict" type="string" default="Error">
	<cfargument name="TempDirectory" default="#variables.TempDir#">

	<cfset var destination = getDirectory(argumentCollection=arguments)>
	<cfset var CFFILE = StructNew()>
	<cfset var serverPath = "">
	<cfset var dirdelim = getDirDelim()>
	<cfset var result = "">
	<cfset var UploadFileName = "">
	<cfset var sFileArgs = {
		action="UPLOAD",
		filefield="#Arguments.FieldName#",
		NameConflict=Arguments.NameConflict,
		result="CFFILE",
		destination=destination
	}>
	<cfif StructKeyExists(Arguments,"accept")>
		<cfset sFileArgs["accept"] = Arguments.accept>
	</cfif>

	<!--- Make sure the destination exists. --->
	<cfif StructKeyExists(arguments,"Folder")>
		<cfset makeFolder(arguments.Folder)>
	</cfif>

	<!--- Set default extensions --->
	<cfif NOT StructKeyExists(arguments,"extensions")>
		<cfset arguments.extensions = variables.DefaultExtensions>
	</cfif>

	<cfif StructKeyExists(Form,Arguments.FieldName)>

		<cfset UploadFileName = getClientFileName(Arguments.FieldName)>
		<cfset UploadFileName = FileNameFromString(UploadFileName,ListLast(UploadFileName,"."))>

		<!--- Check file extension --->
		<cfif
				Len(arguments.extensions)
			AND	NOT ListFindNoCase(arguments.extensions,ListLast(UploadFileName,"."))
		>
			<cfreturn StructNew()>
		</cfif>

		<cfset sFileArgs["destination"] = ListAppend(sFileArgs["destination"],UploadFileName,dirDelim)>
	<cfelse>
		<cfset sFileArgs["action"] = "COPY">
	</cfif>

	<!--- Handle the upload --->
	<cffile attributeCollection="#sFileArgs#">

	<cfif StructKeyExists(arguments,"return") AND isSimpleValue(arguments.return)>
		<cfif arguments.return EQ "name">
			<cfset arguments.return = "ServerFile">
		</cfif>
		<cfif StructKeyExists(CFFILE,arguments.return)>
			<cfset result = CFFILE[arguments.return]>
			<cfif isSimpleValue(result) AND isSimpleValue(variables.dirdelim)>
				<cfset result = ListLast(result,variables.dirdelim)>
			</cfif>
		</cfif>
	<cfelse>
		<cfset result = CFFILE>
	</cfif>

	<cfset notifyEvent("uploadFile",Arguments)>

	<cfreturn result>
</cffunction>

<cffunction name="convertFolder" access="public" returntype="string" output="no">
	<cfargument name="Folder" type="string" required="yes">
	<cfargument name="delimiter" type="string" default="/">

	<cfset var result = arguments.Folder>

	<cfset result = ListChangeDelims(result,"/",",")>
	<cfset result = ListChangeDelims(result,variables.dirdelim,"/")>

	<cfset result = ListChangeDelims(result,arguments.delimiter,variables.dirdelim)>

	<cfreturn result>
</cffunction>

<cffunction name="getFilePrefix" access="public" returntype="string" output="no" hint="I return the file name without the extension.">
	<cfargument name="FileName" type="string" required="yes">

	<cfreturn Reverse(ListRest(Reverse(getFileFromPath(arguments.FileName)),"."))>
</cffunction>

<!---
Copies a directory.

@param source      Source directory. (Required)
@param destination      Destination directory. (Required)
@param nameConflict      What to do when a conflict occurs (skip, overwrite, makeunique). Defaults to overwrite. (Optional)
@return Returns nothing.
@author Joe Rinehart (joe.rinehart@gmail.com)
@version 1, July 27, 2005
--->
<cffunction name="copyDirectories" output="true">
    <cfargument name="source" required="true" type="string">
    <cfargument name="destination" required="true" type="string">
    <cfargument name="nameconflict" required="true" default="overwrite">

    <cfset var contents = "" />
    <cfset var dirDelim = getDelimiter()>

    <cfif not(directoryExists(arguments.destination))>
        <cfdirectory action="create" directory="#arguments.destination#">
    </cfif>

    <cfdirectory action="list" directory="#arguments.source#" name="contents">

    <cfloop query="contents">
        <cfif contents.type eq "file">
            <cffile action="copy" source="#arguments.source##dirDelim##name#" destination="#arguments.destination##dirDelim##name#" nameconflict="#arguments.nameConflict#">
        <cfelseif contents.type eq "dir">
            <cfset copyDirectories(arguments.source & dirDelim & name, arguments.destination & dirDelim & name) />
        </cfif>
    </cfloop>

</cffunction>

<!---
 * v2, bug found with dots in path, bug found by joseph
 *
 * @author Marc Esher (marc.esher@cablespeed.com)
 * @version 2, January 22, 2008
--->
<cffunction name="createUniqueFileName" acess="public" returntype="string" output="no" hint="Creates a unique file name; used to prevent overwriting when moving or copying files from one location to another.">
	<cfargument name="fullPath" type="string" required="true" hint="Full path to file.">
	<cfargument name="maxfilelength" type="numeric" default="0">
	<cfscript>
	var extension = "";
	var thePath = "";
	var dir = "";
	var filebase = "";
	var result = arguments.fullPath;
	var counter = 0;
	if ( FileExists(Arguments.fullPath) ) {
		if( ListLen(fullPath,".") gte 2 ) {
			extension = "." & ListLast(fullPath,".");
		}
		thePath = ListDeleteAt(fullPath,ListLen(fullPath,"."),".");
		filebase = ListLast(arguments.fullPath,getDirDelim());
		dir = ReReplaceNoCase(arguments.fullPath,"#ReplaceNoCase(filebase,'.','\.','ALL')#$","");
		filebase = ListDeleteAt(filebase,ListLen(filebase,"."),".");

		if ( arguments.maxfilelength AND Len(filebase & extension) GT arguments.maxfilelength ) {
			filebase = Left(filebase,arguments.maxfilelength-extension);
		}

		while( FileExists(result) ) {
			counter = counter + 1;
			result = LimitFileNameLength(arguments.maxfilelength,thePath,"_" & counter & extension);
		}
	}

	return result;
	</cfscript>
</cffunction>

<cfscript>
/**
 * Makes a row of a query into a structure.
 *
 * @param query 	 The query to work with.
 * @param row 	 Row number to check. Defaults to row 1.
 * @return Returns a structure.
 * @author Nathan Dintenfass (nathan@changemedia.com)
 * @version 1, December 11, 2001
 */
</cfscript>

<cffunction name="cleanFileName" access="public" returntype="string" output="false">
	<cfargument name="name" type="string" required="yes">
	<cfargument name="maxlength" type="numeric" default="0">

	<cfset var result = ReReplaceNoCase(arguments.name,"[^a-zA-Z0-9_\-\.]","_","ALL")><!--- Remove special characters from file name --->
	<cfset result = ReReplaceNoCase(result,"\s+","_","ALL")><!--- Remove empty space from file name --->

	<cfset result = ReReplaceNoCase(result,"_{2,}","_","ALL")>

	<cfset result = LimitFileNameLength(arguments.maxlength,result)>

	<cfreturn result>
</cffunction>

<cffunction name="unzip" access="public" returntype="any" output="false">
	<cfargument name="file" type="string" required="yes">
	<cfargument name="destination" type="string" required="yes">

	<cfset Arguments.action = "unzip">

	<cfzip AttributeCollection="#Arguments#">

	<cfset notifyEvent("unzip",Arguments)>

</cffunction>

<cffunction name="zip" access="public" returntype="any" output="false">
	<cfargument name="source" type="string" required="yes">
	<cfargument name="file" type="string" required="yes">

	<cfset Arguments.action = "zip">

	<cfzip AttributeCollection="#Arguments#">

	<cfset notifyEvent("zip",Arguments)>

</cffunction>

<cffunction name="notifyEvent" access="package" returntype="void" output="false" hint="">
	<cfargument name="EventName" type="string" required="true">
	<cfargument name="Args" type="struct" required="false">
	<cfargument name="result" type="any" required="false">

	<cfif StructKeyExists(Variables,"Observer")>
		<cfset Arguments.EventName = "FileMgr:#Arguments.eventName#">
		<cfset Variables.Observer.notifyEvent(ArgumentCollection=Arguments)>
	</cfif>

</cffunction>

<cffunction name="fixFileName" access="private" returntype="string" output="false">
	<cfargument name="name" type="string" required="yes">
	<cfargument name="dir" type="string" required="yes">
	<cfargument name="maxlength" type="numeric" default="0">

	<cfset var dirdelim = getDirDelim()>
	<cfset var result = cleanFileName(name=Arguments.name,maxlength=Arguments.maxlength)>
	<cfset var path = "#dir##dirdelim##result#">

	<!--- If corrected file name doesn't match original, rename it --->
	<cfif arguments.name NEQ result AND FileExists("#arguments.dir##dirdelim##arguments.name#")>
		<cfset path = createUniqueFileName(path,arguments.maxlength)>
		<cfset result = ListLast(path,dirdelim)>
		<cffile action="rename" source="#arguments.dir##dirdelim##arguments.name#" destination="#result#">
	</cfif>

	<cfreturn result>
</cffunction>

<cffunction name="StructFromArgs" access="public" returntype="struct" output="false" hint="">

	<cfset var sTemp = 0>
	<cfset var sResult = StructNew()>
	<cfset var key = "">

	<cfif ArrayLen(arguments) EQ 1 AND isStruct(arguments[1])>
		<cfset sTemp = arguments[1]>
	<cfelse>
		<cfset sTemp = arguments>
	</cfif>

	<!--- set all arguments into the return struct --->
	<cfloop collection="#sTemp#" item="key">
		<cfif StructKeyExists(sTemp, key)>
			<cfset sResult[key] = sTemp[key]>
		</cfif>
	</cfloop>

	<cfreturn sResult>
</cffunction>
<cfscript>
//http://www.stillnetstudios.com/get-filename-before-calling-cffile/
function getClientFileName(fieldName) {
	var loc = {};

	loc.aParts = Form.getPartsArray();
	loc.part = "";

	if ( StructKeyExists(loc,"aParts") ) {
		for (loc.part in loc.aParts) {
			if ( loc.part.isFile() AND loc.part.getName() EQ Arguments.fieldName ) {
				return loc.part.getFileName();
			}
		}
	}
	//Railo code.
	loc.sHere = GetPageContext();
	if ( StructKeyExists(loc.sHere,"formScope") ) {
		loc.sHere = loc.sHere.formScope();
		if ( StructKeyExists(loc.sHere,"getUploadResource") ) {
			loc.sHere = loc.sHere.getUploadResource(Arguments.fieldName);
			if ( StructKeyExists(loc.sHere,"getName") ) {
				return loc.sHere.getName();
			}
		}
	}
	//GetPageContext().formScope().getUploadResource("myFormField").getName()

	return "";
}
</cfscript>
</cfcomponent>
