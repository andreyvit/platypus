/*
    Platypus - program for creating Mac OS X application wrappers around scripts
    Copyright (C) 2008 Sveinbjorn Thordarson <sveinbjornt@simnet.is>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

*/

#import "PlatypusAppSpec.h"

@implementation PlatypusAppSpec

/*****************************************
 - init / dealloc functions
*****************************************/

- (id)init
{
	if (self = [super init]) 
	{
		properties = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(id)initWithDefaults
{
	if (self = [super init]) 
	{
		properties = [[NSMutableDictionary alloc] init];
    }
	[self setDefaults];
	return self;
}

-(id)initWithDictionary: (NSDictionary *)dict
{
	if (self = [super init]) 
	{
		properties = [[NSMutableDictionary alloc] init];
		[properties addEntriesFromDictionary: dict];
		[properties setObject: PROGRAM_STAMP forKey: @"Creator"];
    }
	return self;
}

-(id)initWithProfile: (NSString *)filePath
{
	return [self initWithDictionary: [NSMutableDictionary dictionaryWithContentsOfFile: filePath]];
}

-(void)dealloc
{
	if (properties) { [properties release]; }
	[super dealloc];
}

#pragma mark -

/**********************************
	init a spec with default values for everything
**********************************/

-(void)setDefaults
{
	// stamp the spec with the creator
	[properties setObject: PROGRAM_STAMP forKey: @"Creator"];

	//prior properties
	[properties setObject: CMDLINE_EXEC_PATH
											forKey: @"ExecutablePath"];
	[properties setObject: CMDLINE_NIB_PATH
											forKey: @"NibPath"];
	[properties setObject: [@"~/Desktop/MyApp.app" stringByExpandingTildeInPath]
											forKey: @"Destination"];

	// primary attributes
	[properties setObject: @"MyApp"			forKey: @"Name"];
	[properties setObject: @""				forKey: @"ScriptPath"];
	[properties setObject: @"None"			forKey: @"Output"];
	[properties setObject: [NSNumber numberWithBool: YES]	forKey: @"HasCustomIcon"];
	[properties setObject: CMDLINE_ICON_PATH				forKey: @"CustomIconPath"];
	
	// secondary attributes
	[properties setObject: @"/bin/sh"		forKey: @"Interpreter"];
	[properties setObject: [NSMutableArray array]	forKey: @"Parameters"];
	[properties setObject: @"1.0"			forKey: @"Version"];
	[properties setObject: @"????"			forKey: @"Signature"];
	[properties setObject: [NSString stringWithFormat: @"org.%@.MyApp", NSUserName()]
											forKey: @"Identifier"];
	[properties setObject: NSFullUserName()	forKey: @"Author"];
	
	[properties setValue: [NSNumber numberWithBool: NO]					forKey: @"AppPathAsFirstArg"];
	[properties setValue: [NSNumber numberWithBool: NO]					forKey: @"Droppable"];
	[properties setValue: [NSNumber numberWithBool: NO]					forKey: @"Secure"];
	[properties setValue: [NSNumber numberWithBool: NO]					forKey: @"Authentication"];
	[properties setValue: [NSNumber numberWithBool: NO]					forKey: @"RemainRunning"];
	[properties setValue: [NSNumber numberWithBool: NO]					forKey: @"ShowInDock"];

	// bundled files
	[properties setObject: [NSMutableArray array]	forKey: @"BundledFiles"];
	
	// environment
	[properties setObject: [NSMutableDictionary dictionaryWithObject: PROGRAM_STAMP forKey: @"Creator"]	
											forKey: @"Environment"];

	// suffixes / file types
	[properties setObject: [NSMutableArray arrayWithObject: @"*"]						forKey: @"Suffixes"];
	[properties setObject: [NSMutableArray arrayWithObjects: @"****", @"fold", NULL]	forKey: @"FileTypes"];
	[properties setObject: @"Viewer"													forKey: @"Role"];

	// text output settings
	[properties setObject: [NSNumber numberWithInt: NSASCIIStringEncoding]											forKey: @"TextEncoding"];
	[properties setObject: [NSKeyedArchiver archivedDataWithRootObject: [NSFont fontWithName:@"Monaco" size: 10.0]]	forKey: @"TextFont"];
	[properties setObject: [NSKeyedArchiver archivedDataWithRootObject: [NSColor blackColor]]						forKey: @"TextForeground"];
	[properties setObject: [NSKeyedArchiver archivedDataWithRootObject: [NSColor whiteColor]]						forKey: @"TextBackground"];

}


/****************************************

	This function creates the Platypus app
	based on the data contained in the spec.
	It's long...

****************************************/

-(BOOL)create
{
	int	      i;
	NSString *contentsPath, *macosPath, *resourcesPath, *lprojPath, *tmpPath = @"/tmp/";
	NSString *execDestinationPath, *infoPlistPath, *iconPath, *bundledFileDestPath, *nibDestPath;
	NSString *execPath, *bundledFilePath;
	NSString *scriptFilePath, *appSettingsPlistPath;
	NSString *infoPlistStrings;
	NSString *b_enc_script = @"";
	NSMutableDictionary	*appSettingsPlist;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	/////// MAKE SURE CONDITIONS ARE ACCEPTABLE //////
	
	// make sure we can write to /tmp/
	if (![fileManager isWritableFileAtPath: tmpPath])
	{
		error = @"Could not write to the /tmp/ directory."; 
		return 0;
	}
	//make sure we have write privileges for the selected directory
	if (![fileManager isWritableFileAtPath: [ [properties objectForKey: @"Destination"] stringByDeletingLastPathComponent]])
	{
		error = @"Don't have permission to write to the destination directory";
		return 0;
	}

	//check if app already exists
	if ([fileManager fileExistsAtPath: [properties objectForKey: @"Destination"]])
	{
		error = @"App already exists at path";
		return 0;
	}
	
	[self dump];
	
	////////////////////////// CREATE THE FOLDER HIERARCHY /////////////////////////////////////
	
	// we begin by creating the application bundle in /tmp/
	
	//Application.app bundle in /tmp
	tmpPath = [tmpPath stringByAppendingString: [[properties objectForKey: @"Destination"] lastPathComponent]];
	[fileManager createDirectoryAtPath: tmpPath attributes:nil];
	
	//.app/Contents
	contentsPath = [tmpPath stringByAppendingString:@"/Contents"];
	[fileManager createDirectoryAtPath: contentsPath attributes:nil];
	
	//.app/Contents/MacOS
	macosPath = [contentsPath stringByAppendingString:@"/MacOS"];
	[fileManager createDirectoryAtPath: macosPath attributes:nil];
	
	//.app/Contents/Resources
	resourcesPath = [contentsPath stringByAppendingString:@"/Resources"];
	[fileManager createDirectoryAtPath: resourcesPath attributes:nil];
	
	//.app/Contents/Resources/English.lproj 
	lprojPath = [resourcesPath stringByAppendingString:@"/English.lproj"];
	[fileManager createDirectoryAtPath: lprojPath attributes:nil];
			
	////////////////////////// COPY FILES TO THE APP BUNDLE //////////////////////////////////
	
	//copy exec file
	//.app/Contents/Resources/MacOS/Exec
	execPath = [properties objectForKey: @"ExecutablePath"];
	execDestinationPath = [macosPath stringByAppendingString:@"/"];
	execDestinationPath = [execDestinationPath stringByAppendingString: [properties objectForKey: @"Name"]]; 
	[fileManager copyPath:execPath toPath:execDestinationPath handler:nil];
	
	//copy nib file to app bundle
	//.app/Contents/Resources/English.lproj/MainMenu.nib
	nibDestPath = [lprojPath stringByAppendingString:@"/MainMenu.nib"];
	[fileManager copyPath: [properties objectForKey: @"NibPath"] toPath: nibDestPath handler:nil];
		
	//create InfoPlist.strings file
	//.app/Contents/Resources/English.lproj/InfoPlist.strings
	infoPlistStrings = [NSString stringWithFormat:
						@"CFBundleName = \"%@\";\nCFBundleShortVersionString = \"%@\";\nCFBundleGetInfoString = \"%@ version %@ Copyright %d %@\";\nNSHumanReadableCopyright = \"Copyright %d %@.\";",  
										  [properties objectForKey: @"Name"], 
										  [properties objectForKey: @"Version"], 
										  [properties objectForKey: @"Name"],
										  [properties objectForKey: @"Version"], 
										  [[NSCalendarDate calendarDate] yearOfCommonEra], 
										  [properties objectForKey: @"Author"], 
										  [[NSCalendarDate calendarDate] yearOfCommonEra], 
										  [properties objectForKey: @"Author"]
						];
	[infoPlistStrings writeToFile:  [lprojPath stringByAppendingString:@"/InfoPlist.strings"] atomically: YES];
	
	// create script file in app bundle
	//.app/Contents/Resources/script
	//.app/Contents/Resources/.script
	NSString *scriptString = [NSString stringWithContentsOfFile: [properties objectForKey: @"ScriptPath"]];
	scriptFilePath = [resourcesPath stringByAppendingString:@"/script"];
	if ([[properties objectForKey: @"Secure"] boolValue])
		b_enc_script = [[NSData dataWithContentsOfFile: [properties objectForKey: @"ScriptPath"]] base64Encoding];
	else
		[scriptString writeToFile: scriptFilePath atomically: YES];
	
	//create AppSettings.plist file
	//.app/Contents/Resources/AppSettings.plist
	appSettingsPlist = [NSMutableDictionary dictionaryWithCapacity: 255];
	[appSettingsPlist setObject: [properties objectForKey: @"AppPathAsFirstArg"] forKey: @"AppPathAsFirstArg"];
	[appSettingsPlist setObject: [properties objectForKey: @"Authentication"] forKey: @"RequiresAdminPrivileges"];
	[appSettingsPlist setObject: [properties objectForKey: @"Droppable"] forKey: @"IsDroppable"];
	[appSettingsPlist setObject: [properties objectForKey: @"RemainRunning"] forKey: @"RemainRunningAfterCompletion"];
	[appSettingsPlist setObject: [properties objectForKey: @"Secure"] forKey: @"Secure"];
	[appSettingsPlist setObject: [properties objectForKey: @"Output"] forKey: @"OutputType"];
	[appSettingsPlist setObject: [properties objectForKey: @"Interpreter"] forKey: @"ScriptInterpreter"];
	[appSettingsPlist setObject: PROGRAM_STAMP forKey: @"Creator"];
	[appSettingsPlist setObject: [properties objectForKey: @"Parameters"] forKey: @"InterpreterParams"];
	[appSettingsPlist setObject: [properties objectForKey: @"TextFont"] forKey: @"TextFont"];
	[appSettingsPlist setObject: [properties objectForKey: @"TextForeground"] forKey: @"TextForeground"];
	[appSettingsPlist setObject: [properties objectForKey: @"TextBackground"] forKey: @"TextBackground"];
	[appSettingsPlist setObject: [properties objectForKey: @"TextEncoding"] forKey: @"TextEncoding"];
	
	if ([[properties objectForKey: @"Secure"] boolValue])
		[appSettingsPlist setObject: [NSKeyedArchiver archivedDataWithRootObject: b_enc_script] forKey: @"TextSettings"];
	
	appSettingsPlistPath = [resourcesPath stringByAppendingString:@"/AppSettings.plist"];
	[appSettingsPlist writeToFile: appSettingsPlistPath atomically: YES];//write it
	
	//create icon
	//.app/Contents/Resources/appIcon.icns
	iconPath = [resourcesPath stringByAppendingString:@"/appIcon.icns"];
	if ([[properties objectForKey: @"HasCustomIcon"] boolValue] == YES)
		[fileManager copyPath: [properties objectForKey: @"CustomIconPath"] toPath: iconPath handler:nil];
	else
	{
		NSImage *img = [[NSImage alloc] initWithData: [properties objectForKey: @"Icon"]];
		if (img != NULL)
		{
			[self writeIcon: img toPath: iconPath];
		}
	}

	//create Info.plist file
	//.app/Contents/Info.plist
	infoPlistPath = [contentsPath stringByAppendingString:@"/Info.plist"];
	// create the Info.plist dictionary
	NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
							@"English", @"CFBundleDevelopmentRegion",
							[properties objectForKey: @"Name"], @"CFBundleExecutable", 
							[properties objectForKey: @"Name"], @"CFBundleName",
							[properties objectForKey: @"Name"], @"CFBundleDisplayName",
							[NSString stringWithFormat: @"%@ %@ Copyright %d %@", [properties objectForKey: @"Name"], [properties objectForKey: @"Version"], [[NSCalendarDate calendarDate] yearOfCommonEra], [properties objectForKey: @"Author"] ], @"CFBundleGetInfoString", 
							[NSString stringWithFormat: @"%@ %@ Copyright %d %@", [properties objectForKey: @"Name"], [properties objectForKey: @"Version"], [[NSCalendarDate calendarDate] yearOfCommonEra], [properties objectForKey: @"Author"] ], @"NSHumanReadableCopyright", 
							@"appIcon.icns", @"CFBundleIconFile",  
							//[properties objectForKey: @"Version"], @"CFBundleVersion",
							[properties objectForKey: @"Version"], @"CFBundleShortVersionString", 
							[properties objectForKey: @"Identifier"], @"CFBundleIdentifier",  
							[properties objectForKey: @"ShowInDock"], @"LSUIElement",
							@"6.0", @"CFBundleInfoDictionaryVersion",
							@"APPL", @"CFBundlePackageType",
							[properties objectForKey: @"Signature"], @"CFBundleSignature",
							[NSNumber numberWithBool: NO], @"LSHasLocalizedDisplayName",
							[properties objectForKey: @"Environment"], @"LSEnvironment",
							[NSNumber numberWithBool: NO], @"NSAppleScriptEnabled",
							@"MainMenu", @"NSMainNibFile",
							@"10.4", @"LSMinimumSystemVersion",
							@"NSApplication", @"NSPrincipalClass",  nil];
		
	if ([[properties objectForKey: @"Droppable"] boolValue] == YES)
	{
		NSMutableDictionary	*typesAndSuffixesDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
						[properties objectForKey: @"Suffixes"], @"CFBundleTypeExtensions",//extensions
						[properties objectForKey: @"FileTYpes"], @"CFBundleTypeOSTypes",//os types
						[properties objectForKey: @"Role"], @"CFBundleTypeRole", nil];//viewer or editor?
		[infoPlist setObject: [NSArray arrayWithObject: typesAndSuffixesDict] forKey: @"CFBundleDocumentTypes"];
	}
		
	// finally, write the Info.plist file
	[infoPlist writeToFile: infoPlistPath atomically: YES];
			
	//copy files in file list to the Resources folder
	//.app/Contents/Resources/*
	for (i = 0; i < [[properties objectForKey: @"BundledFiles"] count]; i++)
	{
		bundledFilePath = [[properties objectForKey: @"BundledFiles"] objectAtIndex: i];
		bundledFileDestPath = [resourcesPath stringByAppendingString:@"/"];
		bundledFileDestPath = [bundledFileDestPath stringByAppendingString: [bundledFilePath lastPathComponent]];
		[fileManager copyPath: bundledFilePath toPath: bundledFileDestPath handler:nil];
	}

	////////////////////////////////// COPY APP OVER TO FINAL DESTINATION /////////////////////////////////
	
	// we've now created the application in /tmp/
	// now it's time to move it to the destination specified by the user
	
	[fileManager movePath: tmpPath toPath: [properties objectForKey: @"Destination"] handler:nil];//move
	if (![[NSFileManager defaultManager] fileExistsAtPath:[properties objectForKey: @"Destination"]]) //if move was a success
	{
		error = @"Platypus failed to create application at the specified destination";
		return 0;
	}

	
	return 1;
}

/************************

	Make sure the data
	in the spec isn't
	insane

************************/

-(BOOL)verify
{
	BOOL isDir;
	
	if (![[properties objectForKey: @"Destination"] hasSuffix: @"app"])
	{
		error = @"Destination must end with .app";
		return 0;
	}

	if ([[properties objectForKey: @"Name"] isEqualToString: @""])
	{
		error = @"Empty app name";
		return 0;
	}
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: [properties objectForKey: @"ScriptPath"] isDirectory:&isDir] || isDir)
	{
		error = @"Script not found at the specified path";
		return 0;
	}
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: [properties objectForKey: @"NibPath"] isDirectory:&isDir] || !isDir)
	{
		error = @"Nib not found at the specified path";
		return 0;
	}
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: [properties objectForKey: @"ExecutablePath"] isDirectory:&isDir] || isDir)
	{
		error = @"Executable not found at the specified path";
		return 0;
	}
	
	return 1;
}

/************************

	Dump property dict to stdout

************************/

-(void)dump
{
	[properties writeToFile: @"/dev/stdout" atomically: YES];
}

/****************************
 Accessor functions
*****************************/

-(void)setProperty: (id)property forKey: (NSString *)theKey
{
	[properties setObject: property forKey: theKey];
}

-(id)propertyForKey: (NSString *)theKey
{
	return [properties objectForKey: theKey];
}

-(void)addProperties: (NSDictionary *)dict
{
	[properties addEntriesFromDictionary: dict];
}

-(NSDictionary *)properties
{
	return [properties retain];
}

-(NSString *)getError
{
	return error;
}

/*****************************************
 - Write an NSImage as icon to a path
*****************************************/

- (void)writeIcon: (NSImage *)img toPath: (NSString *)path
{
	IconFamily *iconFam = [[IconFamily alloc] initWithThumbnailsOfImage: img];
	if (iconFam == NULL) { return; }
	[iconFam writeToFile: path];
	[iconFam release];
}

@end
