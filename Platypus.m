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

#import "Platypus.h"

#define	kWindowExpansionHeight		312

@implementation Platypus

/*****************************************
 - init function
*****************************************/
- (id)init
{
	if (self = [super init]) 
		recentItems = [[NSMutableArray alloc] initWithCapacity: 10];
    return self;
}

/*****************************************
 - dealloc for controller object
   release all the stuff we alloc in init
*****************************************/
-(void)dealloc
{
	[recentItems release];
	[defaultInterpreters release];
    [super dealloc];
}

/*****************************************
 - When application is launched by the user for the very first time
*****************************************/
+ (void)initialize 
{ 
	// create the user defaults here if none exists
    // create a dictionary
    NSMutableDictionary *defaultPrefs = [NSMutableDictionary dictionary];
    
	// put default prefs in the dictionary
	
	// create default bundle identifier string from usename
	NSString *bundleId = [NSString stringWithFormat: @"org.%@.", NSUserName()];
	bundleId = [[bundleId componentsSeparatedByString: @" "] componentsJoinedByString: @""];//no spaces
	
	[defaultPrefs setObject: bundleId						forKey: @"DefaultBundleIdentifierPrefix"];
	[defaultPrefs setObject: @"Built-In"					forKey: @"DefaultEditor"];
	[defaultPrefs setObject: [NSNumber numberWithBool:NO]	forKey: @"ShowAdvancedOptions"];
	[defaultPrefs setObject: [NSArray array]				forKey: @"Profiles"];
	[defaultPrefs setObject: [NSNumber numberWithBool:NO]	forKey: @"RevealApplicationWhenCreated"];
	[defaultPrefs setObject: NSFullUserName()				forKey: @"DefaultAuthor"];
	
    // register the dictionary of defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultPrefs];
}


/*****************************************
 - Handler for when app is done launching
 - Set up the window and stuff like that
*****************************************/
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	int	i = 0;
	
	[self createAppSupportFolders];
	
	defaultInterpreters = [[NSArray alloc] initWithObjects:			@"/bin/sh",
																	@"/usr/bin/perl",
																	@"/usr/bin/python",
																	@"/usr/bin/ruby",
																	@"/usr/bin/osascript",
																	@"/usr/bin/tclsh",
																	@"/usr/bin/expect",
																	@"/usr/bin/php", 
																	@"",
																	nil];

	//set up window
	[window center];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowAdvancedOptions"] == YES)
	{
		[showAdvancedArrow setState: YES];
		[self toggleAdvancedOptions: self];
	}
	[window registerForDraggedTypes: [NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	[window makeFirstResponder: appNameTextField];
	[window makeKeyAndOrderFront: NULL];//show window

	//load recent items
	[recentItems addObjectsFromArray: [[NSUserDefaults standardUserDefaults] objectForKey:@"RecentItems"]];
	
	//remove all files there that no longer exist
	for (i = 0; i < [recentItems count]; i++)
	{
		if (![[NSFileManager defaultManager] fileExistsAtPath: [recentItems objectAtIndex: i]])
		{
			[recentItems removeObjectAtIndex: i];
			i = 0;
		}
	}
	[self constructOpenRecentMenu];
	
	//load profiles
	[profilesControl constructProfilesMenu];
	
	// if we haven't already loaded a profile via openfile delegate method
	// we set all fields to their defaults.  Any profile must contain a name
	// so we can be sure that one hasn't been loaded if the app name field is empty
	if ([[appNameTextField stringValue] isEqualToString: @""])
		[self clearAllFields: self];
}

/*****************************************
 - Create Application Support folder and subfolders
******************************************/
- (void) createAppSupportFolders
{
	BOOL isDir;

	if (! [[NSFileManager defaultManager] fileExistsAtPath: [APP_SUPPORT_FOLDER stringByExpandingTildeInPath] isDirectory: &isDir])
	{
		if (!isDir)	{	[STUtil alert: @"Error" subText: @"Unable to create Application Support folder"];	}
		
		if ( ! [[NSFileManager defaultManager] createDirectoryAtPath: [APP_SUPPORT_FOLDER stringByExpandingTildeInPath] attributes: NULL] )
			[STUtil alert: @"Error" subText: [NSString stringWithFormat: @"Could not create directory '%@'", [APP_SUPPORT_FOLDER stringByExpandingTildeInPath]]]; 
	}
	if (! [[NSFileManager defaultManager] fileExistsAtPath: [PROFILES_FOLDER stringByExpandingTildeInPath] isDirectory: &isDir])
	{
		if (!isDir)	{	[STUtil alert: @"Error" subText: @"Unable to create Profiles folder"];	}
		
		if ( ! [[NSFileManager defaultManager] createDirectoryAtPath: [PROFILES_FOLDER stringByExpandingTildeInPath] attributes: NULL] )
			[STUtil alert: @"Error" subText: [NSString stringWithFormat: @"Could not create directory '%@'", [PROFILES_FOLDER stringByExpandingTildeInPath]]]; 
	}
	if (! [[NSFileManager defaultManager] fileExistsAtPath: [TEMP_FOLDER stringByExpandingTildeInPath] isDirectory: &isDir])
	{
		if (!isDir)	{	[STUtil alert: @"Error" subText: @"Unable to create Temp folder"];	}
		
		if ( ! [[NSFileManager defaultManager] createDirectoryAtPath: [TEMP_FOLDER stringByExpandingTildeInPath] attributes: NULL] )
			[STUtil alert: @"Error" subText: [NSString stringWithFormat: @"Could not create directory '%@'", [TEMP_FOLDER stringByExpandingTildeInPath]]]; 
	}
}

/*****************************************
 - Handler for application termination
************c*****************************/
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	//save recent items
	[[NSUserDefaults standardUserDefaults] setObject: recentItems  forKey:@"RecentItems"];
	//save window status
	[[NSUserDefaults standardUserDefaults] setBool: [showAdvancedArrow state]  forKey:@"ShowAdvancedOptions"];
}

/*****************************************
 - Handler for dragged files and/or files opened via the Finder
   We handle these as scripts, not bundled files
*****************************************/

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	BOOL	isDir = NO;
		
	if([[NSFileManager defaultManager] fileExistsAtPath: filename isDirectory: &isDir] && !isDir)
	{	
		if ([filename hasSuffix: @"platypus"]) //load as profile
			[profilesControl loadProfileFile: filename];
		else //load as script
			[self loadScript: filename];
		return(YES);
	}
	return(NO);
}

#pragma mark -

/*****************************************
 - Create a new script and open in default editor
*****************************************/

- (IBAction)newScript:(id)sender
{
	int			i = 0;
	int			randnum;
	NSString	*tempScript;
	
	// get a random number to append to script name in /tmp/
	do
	{
		randnum =  random() / 1000000;
		tempScript = [NSString stringWithFormat: @"%@/PlatypusScript.%d", [TEMP_FOLDER stringByExpandingTildeInPath], randnum];
	}
	while ([[NSFileManager defaultManager] fileExistsAtPath: tempScript]);
	
	//put shebang line in the new script text file
	NSString	*shebangStr = [NSString stringWithFormat: @"#!%@\n\n", [interpreterTextField stringValue]];
	
	//if this is a perl or shell script, we add a commented list of paths to the bundled files 
	if (([[interpreterTextField stringValue] isEqualToString: @"/usr/bin/perl"] || [[interpreterTextField stringValue] isEqualToString: @"/bin/sh"]) && [fileList numFiles] > 0)
	{
		shebangStr = [shebangStr stringByAppendingString: @"# You can access your bundled files at the following paths:\n#\n"];
		for (i = 0; i < [fileList numFiles]; i++)
		{
			if ([[interpreterTextField stringValue] isEqualToString: @"/bin/sh"])//shell script
				shebangStr = [shebangStr stringByAppendingString: [NSString stringWithFormat:@"# \"$1/Contents/Resources/%@\"\n", [[fileList getFileAtIndex: i] lastPathComponent]]];
			else if ([[interpreterTextField stringValue] isEqualToString: @"/usr/bin/perl"])//perl script
				shebangStr = [shebangStr stringByAppendingString: [NSString stringWithFormat:@"# \"$ARGV[0]/Contents/Resources/%@\"\n", [[fileList getFileAtIndex: i] lastPathComponent]]];
		}
		shebangStr = [shebangStr stringByAppendingString: @"#\n#\n\n"];
	}
	
	//write the default content to the new script
	[shebangStr writeToFile: tempScript atomically: YES];

	//load and edit the script
	[self loadScript: tempScript];
	[self editScript: self];

}

/*****************************************
 - Reveal script in Finder
*****************************************/

- (IBAction)revealScript:(id)sender
{
	if ([[scriptPathTextField stringValue] length] == 0)//make sure the script path is not an empty string
		return;
	//see if file exists
	if ([[NSFileManager defaultManager] fileExistsAtPath: [scriptPathTextField stringValue] ])
		[[NSWorkspace sharedWorkspace] selectFile:[scriptPathTextField stringValue] inFileViewerRootedAtPath:nil];
	else
		[STUtil alert:@"File does not exist" subText: @"No file exists at the specified path"];
}

/*****************************************
 - Open script in external editor
*****************************************/

- (IBAction)editScript:(id)sender
{
	//make sure the script path is not an empty string
	if ([[scriptPathTextField stringValue] length] == 0)
		return;
		
	//see if file exists
	if ([[NSFileManager defaultManager] fileExistsAtPath: [scriptPathTextField stringValue] ])
	{
		// if the default editor is the built-in editor, we pop down the editor sheet
		if ([[[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultEditor"] isEqualToString: @"Built-In"])
		{
			[self openScriptInBuiltInEditor: [scriptPathTextField stringValue]];
		}
		else // open it in the external application
		{
			NSString *defaultEditor = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultEditor"];
			if ([[NSWorkspace sharedWorkspace] fullPathForApplication: defaultEditor] != NULL)
				[[NSWorkspace sharedWorkspace] openFile: [scriptPathTextField stringValue] withApplication: defaultEditor];
			else
			{
				// Complain if editor is not found, set it to the built-in editor
				[STUtil alert: @"Application not found" subText: [NSString stringWithFormat: @"The application '%@' could not be found on your system.  Reverting to the built-in editor.", defaultEditor]];
				[[NSUserDefaults standardUserDefaults] setObject: @"Built-In"  forKey:@"DefaultEditor"];
				[self openScriptInBuiltInEditor: [scriptPathTextField stringValue]];
			}
		}
	}
	else
		[STUtil alert:@"File does not exist" subText: @"No file exists at the specified path"];
}


/*****************************************
 - Run the script in Terminal.app
*****************************************/
- (IBAction)runScript:(id)sender
{
	NSTask	*theTask = [[NSTask alloc] init];

	//open Terminal.app
	[[NSWorkspace sharedWorkspace] launchApplication: @"Terminal.app"];

	//the applescript command to run the script in Terminal.app
	NSString *osaCmd = [NSString stringWithFormat: @"tell application \"Terminal\"\n\tdo script \"%@ '%@'\"\nend tell", [interpreterTextField stringValue], [scriptPathTextField stringValue]];
	
	//initialize task -- we launc the AppleScript via the 'osascript' CLI program
	[theTask setLaunchPath: @"/usr/bin/osascript"];
	[theTask setArguments: [NSArray arrayWithObjects: @"-e", osaCmd, nil]];
	
	//launch, wait until it's done and then release it
	[theTask launch];
	[theTask waitUntilExit];
	[theTask release];
}

/*****************************************
 - Report on syntax of script
*****************************************/

- (IBAction)checkSyntaxOfScript: (id)sender
{
	NSTask			*interpreter = [[NSTask alloc] init];
	NSPipe			*outputPipe = [NSPipe pipe];
	NSFileHandle	*readHandle;

	if (![[NSFileManager defaultManager] fileExistsAtPath: [scriptPathTextField stringValue] ])//make sure it exists
		return;

	//let's see if the script type is supported for syntax checking
	//if so, we set up the task's launch path as the script interpreter and set the relevant flags and arguments
	switch([[scriptTypePopupMenu selectedItem] tag])
	{
		case 0: //shell scripts - /bin/sh
			[interpreter setLaunchPath: [defaultInterpreters objectAtIndex: 0]];
			[interpreter setArguments: [NSArray arrayWithObjects: @"-n", [scriptPathTextField stringValue], nil]];
			break;
		case 1: //perl scripts - /usr/bin/perl
			[interpreter setLaunchPath: [defaultInterpreters objectAtIndex: 4]];
			[interpreter setArguments: [NSArray arrayWithObjects: @"-c", [scriptPathTextField stringValue], nil]];
			break;
		case 2: //python scripts -- use bundled syntax checking script
			[interpreter setLaunchPath: [[NSBundle mainBundle] pathForResource: @"pycheck" ofType: @"py"]];
			[interpreter setArguments: [NSArray arrayWithObjects: [scriptPathTextField stringValue], nil]];
			break;
		case 3: //ruby scripts - /usr/bin/ruby
			[interpreter setLaunchPath: [defaultInterpreters objectAtIndex: 5]];
			[interpreter setArguments: [NSArray arrayWithObjects: @"-c", [scriptPathTextField stringValue], nil]];
			break;
		case 7: //php scripts - /usr/bin/php
			[interpreter setLaunchPath: [defaultInterpreters objectAtIndex: 7]];
			[interpreter setArguments: [NSArray arrayWithObjects: @"-l", [scriptPathTextField stringValue], nil]];
			break;
		default:
			[STUtil sheetAlert: @"Syntax Checking Unsupported" subText: @"Syntax checking is not supported for the scripting language you have selected" forWindow: window];
			[interpreter release];
			return;
	}
	
	//direct the output of the task into a file handle for reading
	[interpreter setStandardOutput: outputPipe];
	[interpreter setStandardError: outputPipe];
	readHandle = [outputPipe fileHandleForReading];
	//launch task
	[interpreter launch];
	[interpreter waitUntilExit];
	//get output in string
	NSString *outputStr = [[[NSString alloc] initWithData: [readHandle readDataToEndOfFile] encoding: NSASCIIStringEncoding] autorelease];
	
	if ([outputStr length] == 0) //if the syntax report string is empty, we report syntax as OK
		outputStr = [NSString stringWithString: @"Syntax OK"];
	
	//set syntax checked file's path in syntax chcker window
	[syntaxScriptPathTextField setStringValue: [scriptPathTextField stringValue]];
	[syntaxCheckerTextField setString: outputStr];
	
	[interpreter release];//release the NSTask

	//report the result
	[window setTitle: @"Platypus - Syntax Check Report"];
	[NSApp beginSheet:	syntaxCheckerWindow
						modalForWindow: window 
						modalDelegate:nil
						didEndSelector:nil
						contextInfo:nil];
	[NSApp runModalForWindow: syntaxCheckerWindow];
	[NSApp endSheet:syntaxCheckerWindow];
    [syntaxCheckerWindow orderOut:self];
}

- (IBAction)closeSyntaxCheckerWindow: (id)sender
{
	[window setTitle: @"Platypus"];
	[NSApp stopModal];
}

#pragma mark -

/*********************************************************************
 - Create button was pressed: Verify that field values are valid
 - Then put up a sheet for designating location to create application
**********************************************************************/

- (IBAction)createButtonPressed: (id)sender
{
	if (![self verifyFieldContents])//are there invalid values in the fields?
		return;

	NSSavePanel *sPanel = [NSSavePanel savePanel];
	[sPanel setPrompt:@"Create"];
	[window setTitle: @"Platypus - Select place to create app"];
	
	//run save panel
    [sPanel beginSheetForDirectory:nil file: [appNameTextField stringValue] modalForWindow: window modalDelegate: self didEndSelector: @selector(createApp:returnCode:contextInfo:) contextInfo: nil];

}

/*************************************************
 - generate application bundle from data provided
**************************************************/
- (void)createApp:(NSSavePanel *)sPanel returnCode:(int)result contextInfo:(void *)contextInfo
{
	//restore window title
	[window setTitle: @"Platypus"];

	// if user pressed cancel, we do nothing
	if (result != NSOKButton) 
		return;
	
	// we begin by making sure destination path ends in .app
	NSString *appPath = [sPanel filename];
	if (![appPath hasSuffix:@".app"])
		appPath = [appPath stringByAppendingString:@".app"];
	
	//check if app already exists, and if so, prompt if to replace
	if ([[NSFileManager defaultManager] fileExistsAtPath: appPath])
	{
		if (NO == [STUtil proceedWarning: @"Application already exists" subText: @"An application with this name already exists in the location you specified.  Do you wish to overwrite it?"])
			return;

		if ([[NSFileManager defaultManager] isDeletableFileAtPath: appPath])
			[[NSFileManager defaultManager] removeFileAtPath: appPath handler: NULL];
		else
		{
			[STUtil alert: @"Failed to overwrite" subText: [NSString stringWithFormat: @"Could not overwrite %@.  Make sure that you have write privileges.", appPath]]; 
			return;
		}
	}
	
	// create spec from controls and verify
	PlatypusAppSpec	*spec = [self appSpecFromControls];
	
	// we set this specifically -- extra-profile data
	[spec setProperty: appPath forKey: @"Destination"];
	[spec setProperty: [[NSBundle mainBundle] pathForResource: @"ScriptExec" ofType: NULL] forKey: @"ExecutablePath"];
	[spec setProperty: [[NSBundle mainBundle] pathForResource: @"MainMenu.nib" ofType: NULL] forKey: @"NibPath"];
	
	// create the app from spec
	if (![spec verify] || ![spec create])
	{
		[STUtil alert: @"Error creating app" subText: [spec getError]];
		return;
	}

	// reveal newly create app in Finder, if prefs say so
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"RevealApplicationWhenCreated"])
		[[NSWorkspace sharedWorkspace] selectFile: appPath inFileViewerRootedAtPath:nil];
	
}

/*************************************************
 - Create app spec and fill it w. data from controls
**************************************************/

-(id)appSpecFromControls
{
	PlatypusAppSpec *spec = [[PlatypusAppSpec alloc] initWithDefaults];
	
	[spec setProperty: [appNameTextField stringValue]		forKey: @"Name"];
	[spec setProperty: [scriptPathTextField stringValue]	forKey: @"ScriptPath"];
	
	// set output type to the name of the output type, minus spaces
	[spec setProperty: [outputTypePopupMenu titleOfSelectedItem]
															forKey: @"Output"];
	
	// icon
	if ([iconControl usesIcnsFile])
	{
		[spec setProperty: [NSNumber numberWithBool: YES]	forKey: @"HasCustomIcon"];
		[spec setProperty: [iconControl getIcnsFilePath]	forKey: @"CustomIconPath"];
	}
	else
	{
		[spec setProperty: [NSNumber numberWithBool: NO]	forKey: @"HasCustomIcon"];
		[spec setProperty: [iconControl getImage]	forKey: @"Icon"];
	}
	
	// advanced attributes
	[spec setProperty: [interpreterTextField stringValue]	forKey: @"Interpreter"];
	[spec setProperty: [paramsControl paramsArray]			forKey: @"Parameters"];
	[spec setProperty: [versionTextField stringValue]		forKey: @"Version"];
	[spec setProperty: [signatureTextField stringValue]		forKey: @"Signature"];
	[spec setProperty: [bundleIdentifierTextField stringValue]
															forKey: @"Identifier"];
	[spec setProperty: [authorTextField stringValue]		forKey: @"Author"];
	
	// checkbox attributes
	[spec setProperty: [NSNumber numberWithBool: [paramsControl passAppPathAsFirstArg]] 
															forKey: @"AppPathAsFirstArg"];
	
	[spec setProperty: [NSNumber numberWithBool:[isDroppableCheckbox state]]					
															forKey: @"Droppable"];
	[spec setProperty: [NSNumber numberWithBool:[encryptCheckbox state]]
															forKey: @"Secure"];
	[spec setProperty: [NSNumber numberWithBool:[rootPrivilegesCheckbox state]]		
															forKey: @"Authentication"];
	[spec setProperty: [NSNumber numberWithBool:[remainRunningCheckbox state]]
															forKey: @"RemainRunning"];
	[spec setProperty: [NSNumber numberWithBool:[showInDockCheckbox state]]
															forKey: @"ShowInDock"];

	// bundled files
	[spec setProperty: [fileList getFilesArray]	forKey: @"BundledFiles"];
	
	// environment
	[spec setProperty: [envControl environmentDictionary]	forKey: @"Environment"];

	// file types
	[spec setProperty: (NSMutableArray *)[(SuffixList *)[typesControl suffixes] getSuffixArray]				forKey: @"Suffixes"];
	[spec setProperty: (NSMutableArray *)[(TypesList *)[typesControl types] getTypesArray]					forKey: @"FileTypes"];
	[spec setProperty: [typesControl role]																	forKey: @"Role"];

	//  text output text settings
	[spec setProperty: [NSNumber numberWithInt: (int)[textSettingsControl getTextEncoding]]							forKey: @"TextEncoding"];
	[spec setProperty: [NSKeyedArchiver archivedDataWithRootObject: [textSettingsControl getTextFont]]				forKey: @"TextFont"];
	[spec setProperty: [NSKeyedArchiver archivedDataWithRootObject: [textSettingsControl getTextForeground]]		forKey: @"TextForeground"];
	[spec setProperty: [NSKeyedArchiver archivedDataWithRootObject: [textSettingsControl getTextBackground]]		forKey: @"TextBackground"];

	return spec;
}

- (void) controlsFromAppSpec: (id)spec
{
	[appNameTextField setStringValue: [spec propertyForKey: @"Name"]];
	[scriptPathTextField setStringValue: [spec propertyForKey: @"ScriptPath"]];

	[versionTextField setStringValue: [spec propertyForKey: @"Version"]];
	[signatureTextField setStringValue: [spec propertyForKey: @"Signature"]];
	[authorTextField setStringValue: [spec propertyForKey: @"Author"]];
	
	[outputTypePopupMenu selectItemWithTitle: [spec propertyForKey: @"Output"]];
	[self outputTypeWasChanged: NULL];
	[interpreterTextField setStringValue: [spec propertyForKey: @"Interpreter"]];
	
	//icon
	if ([[spec propertyForKey: @"HasCustomIcon"] boolValue] == YES)
		[iconControl setIcnsPath: [spec propertyForKey: @"CustomIconPath"]];
	else
		[iconControl setImage: [[NSImage alloc] initWithData: [spec propertyForKey: @"Icon"]]  ];

	//checkboxes
	[rootPrivilegesCheckbox setState: [[spec propertyForKey: @"Authentication"] boolValue]];
	[isDroppableCheckbox setState: [[spec propertyForKey: @"Droppable"] boolValue]];
		[self isDroppableWasClicked: isDroppableCheckbox];
	[encryptCheckbox setState: [[spec propertyForKey: @"Secure"] boolValue]];
	[showInDockCheckbox setState: [[spec propertyForKey: @"ShowInDock"] boolValue]];
	[remainRunningCheckbox setState: [[spec propertyForKey: @"RemainRunning"] boolValue]];
	
	//file list
		[fileList clearList];
		[fileList addFiles: [spec propertyForKey: @"BundledFiles"]];

		//update button status
		[fileList tableViewSelectionDidChange: NULL];
	
	//suffix list
		[(SuffixList *)[typesControl suffixes] clearList];
		[(SuffixList *)[typesControl suffixes] addSuffixes: [spec propertyForKey: @"Suffixes"]];
	
	//types list
		[(TypesList *)[typesControl types] clearList];
		[(TypesList *)[typesControl types] addTypes: [spec propertyForKey: @"FileTypes"]];
		
		[typesControl tableViewSelectionDidChange: NULL];
		[typesControl setRole: [spec propertyForKey: @"Role"]];
	
	// environment
		[envControl set: [spec propertyForKey: @"Environment"]];
	
	// parameters
		[paramsControl set: [spec propertyForKey: @"Parameters"]];
		[paramsControl setAppPathAsFirstArg: [[spec propertyForKey: @"AppPathAsFirstArg"] boolValue]];

		 
	// text output settings
	[textSettingsControl setTextEncoding: [[spec propertyForKey: @"TextEncoding"] intValue]];
	[textSettingsControl setTextFont: [NSKeyedUnarchiver unarchiveObjectWithData: [spec propertyForKey: @"TextFont"]]];
	[textSettingsControl setTextForeground: [NSKeyedUnarchiver unarchiveObjectWithData: [spec propertyForKey: @"TextForeground"]]];
	[textSettingsControl setTextBackground: [NSKeyedUnarchiver unarchiveObjectWithData: [spec propertyForKey: @"TextBackground"]]];

	//update buttons
	[self controlTextDidChange: NULL];
	
	[self updateEstimatedAppSize];
	
	[bundleIdentifierTextField setStringValue: [spec propertyForKey: @"Identifier"]];
}

/*************************************************
 - Make sure that all fields contain valid values
**************************************************/

- (BOOL)verifyFieldContents
{
	BOOL			isDir;

	//file manager
	NSFileManager *fileManager = [NSFileManager defaultManager];

	//script path
	if ([[appNameTextField stringValue] length] == 0)//make sure a name has been assigned
	{
		[STUtil sheetAlert:@"Invalid Application Name" subText: @"You must specify a name for your application" forWindow: window];
		return NO;
	}

	//script path
	if (([fileManager fileExistsAtPath: [scriptPathTextField stringValue] isDirectory: &isDir] == NO) || isDir)//make sure script exists and isn't a folder
	{
		[STUtil sheetAlert:@"Invalid Script Path" subText: @"No file exists at the script path you have specified" forWindow: window];
		return NO;
	}
	//interpreter
	if ([fileManager fileExistsAtPath: [interpreterTextField stringValue]] == NO)//make sure interpreter exists
	{
		if (NO == [STUtil proceedWarning: @"Invalid Interpreter" subText: @"The specified interpreter does not exist on this system.  Do you wish to proceed anyway?"])
			return NO;
	}
	//make sure typeslist contains valid values
	if ([(TypesList *)[typesControl types] numTypes] <= 0 && [isDroppableCheckbox state] == YES)
	{
		[STUtil sheetAlert:@"Invalid Types List" subText: @"The app has been set to be droppable but no file types are set.  Please modify the Types list to correct this." forWindow: window];
		return NO;
	}
	//make sure the signature is 4 characters
	if ([[signatureTextField stringValue] length] != 4)
	{
		[STUtil sheetAlert:@"Invalid App Signature" subText: @"The signature set for the application is invalid.  An app's signature must consist of four upper and/or lowercase ASCII characters." forWindow: window];
		return NO;
	}
	
	//make sure we have an icon
	if ([iconControl getImage] == NULL)
	{
		[STUtil sheetAlert:@"Missing Icon" subText: @"You must set an icon for your application." forWindow: window];
		return NO;
	}
	
	// let's be certain that the bundled files list doesn't contain entries that have been moved
	if(![fileList allPathsAreValid])
	{
		[STUtil sheetAlert: @"Moved or missing files" subText:@"One or more of the files that are to be bundled with the application have been moved.  Please rectify this and try again." forWindow: window];
		return NO;
	}
	
	return YES;
}


/*****************************************
 - Called when script type radio button is pressed
*****************************************/

- (IBAction)scriptTypeSelected:(id)sender
{
	[self setScriptType: [[sender selectedItem] tag] ];
}

- (void)selectScriptTypeBasedOnInterpreter
{
	int i;
	
	for (i = 0; i < [defaultInterpreters count]; i++)
	{
		if ([[interpreterTextField stringValue] isEqualToString: [defaultInterpreters objectAtIndex: i]])
		{
			[scriptTypePopupMenu selectItemAtIndex: i];
			return;
		}
	}
	[scriptTypePopupMenu selectItemAtIndex: 8];
}

/*****************************************
 - Updates data in interpreter, icon and script type radio buttons
*****************************************/

- (void)setScriptType: (int)typeNum
{	
	// set the script type based on the number which identifies each type
	[interpreterTextField setStringValue: [defaultInterpreters objectAtIndex: typeNum ] ];
	[scriptTypePopupMenu selectItemWithTag: typeNum];
	[self controlTextDidChange: NULL];
}

/********************************************************************
 - Parse the Shebang line (#!) to get the interpreter for the script
**********************************************************************/

- (NSString *)getInterpreterFromShebang: (NSString *)path
{
	NSString	*script, *firstLine, *shebang, *interpreterCmd, *theInterpreter;
	NSArray		*lines, *words;
	
	// get the first line of the script
	script = [NSString stringWithContentsOfFile: path encoding: NSASCIIStringEncoding error: nil];
	lines = [script componentsSeparatedByString: @"\n"];
	firstLine = [lines objectAtIndex: 0];
	
	// if the first line of the script is shorter than 2 chars, it can't possibly be a shebang line
	if ([firstLine length] <= 2)
		return @"";
	
	// get first two characters of first line
	shebang = [firstLine substringToIndex: 2]; // first two characters should be #!
	if (![shebang isEqualToString: @"#!"])
		return @"";
	
	// get everything that follows after the #!
	// seperate it by whitespaces, in order not to get also the params to the interpreter
	interpreterCmd = [firstLine substringFromIndex: 2];
	words = [interpreterCmd componentsSeparatedByString: @" "];
	theInterpreter = [words objectAtIndex: 0];
	return (theInterpreter);
}


/*****************************************
 - Open sheet to select script to load
*****************************************/

- (IBAction)selectScript:(id)sender
{
	//create open panel
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	[oPanel setPrompt:@"Select"];
    [oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories: NO];
	
	[window setTitle: @"Platypus - Select script"];
	
	//run open panel
    [oPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow: window modalDelegate: self didEndSelector: @selector(selectScriptPanelDidEnd:returnCode:contextInfo:) contextInfo: nil];
		
}

- (void)selectScriptPanelDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
		[self loadScript: [oPanel filename]];
	[window setTitle: @"Platypus"];
}

/*****************************************
 - Loads script data into platypus window
*****************************************/

- (void)loadScript:(NSString *)filename
{
	NSString	*shebangInterpreter;
	int			i;

	//make sure file we're loading actually exists
	if (![[NSFileManager defaultManager] fileExistsAtPath: filename])
		return;

	//set script path
	[scriptPathTextField setStringValue: filename];

	//set app name
	NSString *appName = [STUtil cutSuffix: [filename lastPathComponent]];
	[appNameTextField setStringValue: appName];
	
	//read shebang line
	shebangInterpreter = [self getInterpreterFromShebang: filename];
	
	//if no interpreter can be retrieved from shebang line
	if ([shebangInterpreter caseInsensitiveCompare: @""] == NSOrderedSame)
	{
		//try to determine type from suffix
		[self setScriptType: (int)[self getFileTypeFromSuffix: filename] ];
	}
	else
	{
		//see if interpreter matches a preset
		for (i = 0; i < [defaultInterpreters count]; i++)
		{
			if ([shebangInterpreter caseInsensitiveCompare: [defaultInterpreters objectAtIndex: i]] == NSOrderedSame)
				[self setScriptType: i];
		}
		
		//set shebang interpreter into interpreter field
		[interpreterTextField setStringValue: shebangInterpreter ];
	}
	
	[self controlTextDidChange: NULL];
	[self updateEstimatedAppSize];
	
		//add to open recent menu
	if (![recentItems containsObject: filename])
	{
		if ([recentItems count] == 8)
			[recentItems removeObjectAtIndex: 0];

		[recentItems addObject: filename];
		[self constructOpenRecentMenu];
	}	
}

/*****************************************
 - Toggles between advanced options mode
*****************************************/

- (IBAction)toggleAdvancedOptions:(id)sender
{
	NSRect winRect = [window frame];

	if ([showAdvancedArrow state] == NSOffState)
	{
		winRect.origin.y += kWindowExpansionHeight;
		winRect.size.height -= kWindowExpansionHeight;
		[showOptionsTextField setStringValue: @"Show Advanced Options"];
		[toggleAdvancedMenuItem setTitle: @"Show Advanced Options"];
		[signatureTextField setEditable: NO];
		[bundleIdentifierTextField setEditable: NO];
		[authorTextField setEditable: NO];
		[versionTextField setEditable: NO];
		
		[window setFrame: winRect display:TRUE animate: TRUE];
		
	}
	else if ([showAdvancedArrow state] == NSOnState)
	{
		winRect.origin.y -= kWindowExpansionHeight;
		winRect.size.height += kWindowExpansionHeight;
		[showOptionsTextField setStringValue: @"Hide advanced options"];
		[toggleAdvancedMenuItem setTitle: @"Hide Advanced Options"];
		[signatureTextField setEditable: YES];
		[bundleIdentifierTextField setEditable: YES];
		[authorTextField setEditable: YES];
		[versionTextField setEditable: YES];
		
		[window setFrame: winRect display:TRUE animate: TRUE];
	}
}

/*****************************************
 - called when [X] Is Droppable is pressed
*****************************************/

- (IBAction)isDroppableWasClicked:(id)sender
{
	//register the data source for the types and suffix lists
	[editTypesButton setHidden: ![isDroppableCheckbox state]];
	[editTypesButton setEnabled: [isDroppableCheckbox state]];
}

/*****************************************
 - called when [X] Is Droppable is pressed
*****************************************/

- (IBAction)outputTypeWasChanged:(id)sender
{
	if ([[outputTypePopupMenu titleOfSelectedItem] isEqualToString: @"Text Window"])
	{
		[textOutputSettingsButton setHidden: NO];
		[textOutputSettingsButton setEnabled: YES];
	}
	else
	{
		[textOutputSettingsButton setHidden: YES];
		[textOutputSettingsButton setEnabled: NO];
	}
}

/*****************************************
 - called when (Clear) button is pressed 
 -- restores fields to startup values
*****************************************/

- (IBAction)clearAllFields:(id)sender
{
	//clear all text field to start value
	[appNameTextField setStringValue: @""];
	[scriptPathTextField setStringValue: @""];
	[versionTextField setStringValue: @"1.0"];
	[signatureTextField setStringValue: @"????"];
	
	[bundleIdentifierTextField setStringValue: [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultBundleIdentifierPrefix"]];
	[authorTextField setStringValue: [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultAuthor"]];
	
	//uncheck all options
	[isDroppableCheckbox setIntValue: 0];
	[self isDroppableWasClicked: isDroppableCheckbox];
	[encryptCheckbox setIntValue: 0];
	[rootPrivilegesCheckbox setIntValue: 0];
	[remainRunningCheckbox setIntValue: 0];
	[showInDockCheckbox setIntValue: 0];
	
	//clear file list
	[fileList clearFileList: self];
	
	//clear suffix and types lists to default values
	[typesControl setDefaultTypes: self];
	
	//set environment variables list to default
	[envControl resetDefaults: self];
	
	//set parameters to default
	[paramsControl resetDefaults: self];
	
	//set text ouput settings to default
	[textSettingsControl resetDefaults: self];
	
	//set script type
	[self setScriptType: 0];
	
	//set output type
	[outputTypePopupMenu selectItemWithTitle: @"Progress Bar"];
	[self outputTypeWasChanged: outputTypePopupMenu];
	
	//update button status
	[self controlTextDidChange: NULL];
	
	[appSizeTextField setStringValue: @""];
	
	[iconControl setAppIconForType: 0];
}

/*****************************************
 - Generate the shell command for the platypus
   command line tool based on the settings 
   provided in the graphical interface
*****************************************/

- (NSString *)commandLineStringFromSettings
{
	int i;
	NSString *checkboxParamStr = @"";
	NSString *iconParamStr = @"";
	NSString *suffixesString = @"", *filetypesString = @"", *parametersString = @"", *environmentString = @"";
	NSArray *outputTypes = [NSArray arrayWithObjects: @"None", @"Progress Bar", @"Text Window", @"Web", nil];
	
	if ([paramsControl passAppPathAsFirstArg])
		checkboxParamStr = [checkboxParamStr stringByAppendingString: @"F"];
	if ([rootPrivilegesCheckbox intValue])
		checkboxParamStr = [checkboxParamStr stringByAppendingString: @"A"];
	if ([encryptCheckbox intValue])
		checkboxParamStr = [checkboxParamStr stringByAppendingString: @"S"];
	if ([isDroppableCheckbox intValue])
		checkboxParamStr = [checkboxParamStr stringByAppendingString: @"D"];
	if ([showInDockCheckbox intValue])
		checkboxParamStr = [checkboxParamStr stringByAppendingString: @"B"];
	if ([remainRunningCheckbox intValue])
		checkboxParamStr = [checkboxParamStr stringByAppendingString: @"R"];
	
	if ([checkboxParamStr length] != 0)
		checkboxParamStr = [NSString stringWithFormat: @"-%@ ", checkboxParamStr];
	
	// if it's droppable, we need the Types and Suffixes
	if ([isDroppableCheckbox intValue])
	{
		//create suffixes param
		suffixesString = [[[typesControl suffixes] getSuffixArray] componentsJoinedByString:@"|"];
		suffixesString = [NSString stringWithFormat: @"-X '%@' ", suffixesString];
		
		//create filetype codes param
		filetypesString = [[(TypesList *)[typesControl types] getTypesArray] componentsJoinedByString:@"|"];
		filetypesString = [NSString stringWithFormat: @"-T '%@' ", filetypesString];
	}
	
	//create bundled files string
	NSString *bundledFilesCmdString = @"";
	NSArray *bundledFiles = [fileList getFilesArray];
	for (i = 0; i < [bundledFiles count]; i++)
	{
		bundledFilesCmdString = [bundledFilesCmdString stringByAppendingString: [NSString stringWithFormat: @"-f '%@' ", [bundledFiles objectAtIndex: i]]];
	}
	
	if ([[paramsControl paramsArray] count])
	{
		parametersString = [[paramsControl paramsArray] componentsJoinedByString:@"|"];
		parametersString = [NSString stringWithFormat: @"-G '%@' ", parametersString];
	}
	
	//if ([[[envControl environmentDictionary] keys] count])
	{
		// do this later
	}
	
	//create custom icon string
	if ([iconControl usesIcnsFile])
		iconParamStr = [NSString stringWithFormat: @" -i '%@' ", [iconControl getIcnsFilePath]];
	
	// finally, generate the command
	NSString *commandStr = [NSString stringWithFormat: 
	@"/usr/local/bin/platypus %@%@-a '%@' -o '%@' -u '%@' -p '%@' -V '%@' -s '%@' -I '%@' %@%@%@%@%@ -c '%@' 'MyApp.app'",
	checkboxParamStr,
	iconParamStr,
	[appNameTextField stringValue],
	[outputTypes objectAtIndex: [[outputTypePopupMenu selectedItem] tag]],
	[authorTextField stringValue],
	[interpreterTextField stringValue],
	[versionTextField stringValue],
	[signatureTextField stringValue], 
	[bundleIdentifierTextField stringValue],
	suffixesString,
	filetypesString,
	bundledFilesCmdString,
	parametersString,
	environmentString,
	[scriptPathTextField stringValue],
	nil];

	return commandStr;
}

/*****************************************
 - Generate shell command and display in text field
*****************************************/

- (IBAction)showCommandLineString: (id)sender
{
	[commandTextField setFont:[NSFont userFixedPitchFontOfSize: 10.0]];
	[commandTextField setString: [self commandLineStringFromSettings]];

	[window setTitle: @"Platypus - Shell Command String"];
	[NSApp beginSheet:	commandWindow
						modalForWindow: window 
						modalDelegate:nil
						didEndSelector:nil
						contextInfo:nil];
	[NSApp runModalForWindow: commandWindow];
	[NSApp endSheet:commandWindow];
    [commandWindow orderOut:self];
}

- (IBAction)closeCommandWindow: (id)sender
{
	[window setTitle: @"Platypus"];
	[NSApp stopModal];
}


#pragma mark -

/*****************************************
 - Determine script type based on a file's suffix
*****************************************/

- (int)getFileTypeFromSuffix: (NSString *)fileName
{
	if ([fileName hasSuffix: @".sh"])
		return 0;
	else if ([fileName hasSuffix: @".pl"] || [fileName hasSuffix: @".perl"])
		return 1;
	else if ([fileName hasSuffix: @".py"])
		return 2;
	else if ([fileName hasSuffix: @".rb"] || [fileName hasSuffix: @".rbx"])
		return 3;
	else if ([fileName hasSuffix: @".scpt"] || [fileName hasSuffix: @".applescript"])
		return 4;
	else if ([fileName hasSuffix: @".tcl"])
		return 5;
	else if ([fileName hasSuffix: @".exp"] || [fileName hasSuffix: @".expect"])
		return 6;
	else if ([fileName hasSuffix: @".php"])
		return 7;
	else
		return 0;
}

/*****************************************
 - //return the bundle identifier for the application to be generated
 -  based on username etc.
*****************************************/

- (NSString *)generateBundleIdentifier
{
	NSString	*bundleId;
	//The format is "org.username.appname"
	bundleId = [NSString stringWithFormat: @"%@%@", [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultBundleIdentifierPrefix"], [appNameTextField stringValue]];
	bundleId = [[bundleId componentsSeparatedByString:@" "] componentsJoinedByString:@""];//no spaces
	return(bundleId);
}

#pragma mark -

/*****************************************
 - // set app size textfield to formatted str with app size
*****************************************/

- (void)updateEstimatedAppSize
{
	[appSizeTextField setStringValue: [NSString stringWithFormat: @"Estimated final app size: ~%@", [self estimatedAppSize]]];
}

/*****************************************
 - // Make a decent guess concerning final app size
*****************************************/

- (NSString *)estimatedAppSize
{
	UInt64 estimatedAppSize = 0;
	
	estimatedAppSize += 4096; // Info.plist
	estimatedAppSize += 4096; // InfoPlist.strings
	estimatedAppSize += 4096; // AppSettings.plist
	estimatedAppSize += 60000; // AppIcon.icns
	estimatedAppSize += [STUtil fileOrFolderSize: [scriptPathTextField stringValue]];
	estimatedAppSize += [STUtil fileOrFolderSize: [[NSBundle mainBundle] pathForResource: @"ScriptExec" ofType: NULL]];  // executable binary
	estimatedAppSize += [STUtil fileOrFolderSize: [[NSBundle mainBundle] pathForResource: @"MainMenu.nib" ofType: NULL]];  // bundled nib
	estimatedAppSize += [fileList getTotalSize];
		
	return [STUtil sizeAsHumanReadable: estimatedAppSize];
}

#pragma mark -

/*****************************************
 - Dragging and dropping for Platypus window
*****************************************/

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard	*pboard = [sender draggingPasteboard];
	NSString		*filename;
	BOOL			isDir = FALSE;

    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) 
	{
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
		filename = [files objectAtIndex: 0];//we only load the first dragged item
		if ([[NSFileManager defaultManager] fileExistsAtPath: filename isDirectory:&isDir] && !isDir)
		{
			if ([filename hasSuffix: @"platypus"])
				[profilesControl loadProfileFile: filename];
			else
				[self loadScript: filename];
			return YES;
		}
	}
	return NO;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender 
{

    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;

    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];

    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) 
	{
        if (sourceDragMask & NSDragOperationLink) 
            return NSDragOperationLink;
		else if (sourceDragMask & NSDragOperationCopy)
            return NSDragOperationCopy;
    }

    return NSDragOperationNone;
}

#pragma mark -

/*****************************************
 - Delegate for when text changes in any of the Platypus text fields
*****************************************/
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	BOOL	isDir, exists = NO, validName = NO;
	
	//app name or script path was changed
	if ([aNotification object] == NULL || [aNotification object] == appNameTextField || [aNotification object] == scriptPathTextField)
	{
		if ([[appNameTextField stringValue] length] > 0)
			validName = YES;
		if ([[NSFileManager defaultManager] fileExistsAtPath: [scriptPathTextField stringValue] isDirectory:&isDir] && !isDir)
			exists = YES;
		
		//edit and reveal buttons -- and text coloring
		if (exists)
		{
			[scriptPathTextField setTextColor: [NSColor blackColor]];
			[editScriptButton setEnabled: YES];
			[revealScriptButton setEnabled: YES];
		}
		else
		{
			[scriptPathTextField setTextColor: [NSColor redColor]];
			[editScriptButton setEnabled: NO];
			[revealScriptButton setEnabled: NO];
		}
		
		//enable/disable create app button
		if (validName && exists)
			[createAppButton setEnabled: YES];
		else
			[createAppButton setEnabled: NO];
		
		//update identifier
		if (validName)
			[bundleIdentifierTextField setStringValue: [self generateBundleIdentifier]];
		else
			[bundleIdentifierTextField setStringValue: [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultBundleIdentifierPrefix"]];
	}
	
	//bundle signature or "type code" changed
	if ([aNotification object] == signatureTextField || [aNotification object] == NULL)
	{
		NSRange	 range = { 0, 4 };
		NSString *sig = [[aNotification object] stringValue];
		
		if ([sig length] > 4)
		{
			[[aNotification object] setStringValue: [sig substringWithRange: range]];
		}
		else if ([sig length] < 4)
			[[aNotification object] setTextColor: [NSColor redColor]];
		else if ([sig length] == 4)
			[[aNotification object] setTextColor: [NSColor blackColor]];
	}
	
	//interpreter changed
	if ([aNotification object] == interpreterTextField || [aNotification object] == NULL)
	{
		[self selectScriptTypeBasedOnInterpreter];
		if ([[NSFileManager defaultManager] fileExistsAtPath: [interpreterTextField stringValue] isDirectory:&isDir] && !isDir)
			[interpreterTextField setTextColor: [NSColor blackColor]];
		else
			[interpreterTextField setTextColor: [NSColor redColor]];
	}
}

/*****************************************
 - Delegate for enabling and disabling menu items
*****************************************/
- (BOOL)validateMenuItem:(NSMenuItem*)anItem 
{
	BOOL isDir;

	//edit script
	if ([[anItem title] isEqualToString:@"Edit Script"] && (![[NSFileManager defaultManager] fileExistsAtPath: [scriptPathTextField stringValue] isDirectory:&isDir] || isDir))
		return NO;
		
	//reveal script
	if ([[anItem title] isEqualToString:@"Reveal Script"] && (![[NSFileManager defaultManager] fileExistsAtPath: [scriptPathTextField stringValue] isDirectory:&isDir] || isDir))
		return NO;
		
	//run script
	if ([[anItem title] isEqualToString:@"Run Script in Terminal"] && (![[NSFileManager defaultManager] fileExistsAtPath: [scriptPathTextField stringValue] isDirectory:&isDir] || isDir))
		return NO;
	
	//check script syntax
	if ([[anItem title] isEqualToString:@"Check Script Syntax"] && (![[NSFileManager defaultManager] fileExistsAtPath: [scriptPathTextField stringValue] isDirectory:&isDir] || isDir))
		return NO;
	
	//create app menu
	if ([[anItem title] isEqualToString:@"Create App"] && (![[NSFileManager defaultManager] fileExistsAtPath: [scriptPathTextField stringValue] isDirectory:&isDir] || isDir))
		return NO;
		
	return YES;
}

/*****************************************
 - Load the script of item selected in Open Recent Menu
*****************************************/
-(void) openRecentMenuItemSelected: (id)sender
{
	BOOL	isDir = NO;

	if ([[NSFileManager defaultManager] fileExistsAtPath: [sender title] isDirectory: &isDir] && isDir == NO)
		[self loadScript: [sender title]];
	else
		[STUtil alert:@"Invalid item" subText: @"The file you selected no longer exists at the specified path."];
}

/*****************************************
 - Generate the Open Recent Menu
*****************************************/
-(void) constructOpenRecentMenu
{
	int i;

	//clear out all menu itesm
	while ([openRecentMenu numberOfItems])
		[openRecentMenu removeItemAtIndex: 0];

	if ([recentItems count] > 0)
	{
		//populate with contents of array
		for (i = [recentItems count]-1; i >= 0 ; i--)
		{
			[openRecentMenu addItemWithTitle: [recentItems objectAtIndex: i] action: @selector(openRecentMenuItemSelected:) keyEquivalent:@""];
		}
		
		//add seperator and clear menu
		[openRecentMenu addItem: [NSMenuItem separatorItem]];
		[openRecentMenu addItemWithTitle: @"Clear" action: @selector(clearRecentItems) keyEquivalent:@""];
		
	}
	else
	{
		[openRecentMenu addItemWithTitle: @"Empty" action: NULL keyEquivalent:@""];
		[[openRecentMenu itemAtIndex: 0] setEnabled: NO];
	}
}

/*****************************************
 - Clear the Recent Items menu
*****************************************/
-(void) clearRecentItems
{
	[recentItems removeAllObjects];
	[self constructOpenRecentMenu];
}

#pragma mark -

/*****************************************
 - Built-In script editor and associated functions
*****************************************/

- (void)openScriptInBuiltInEditor: (NSString *)path
{
	[editorText setFont:[NSFont userFixedPitchFontOfSize: 10.0]]; //set monospace font
	
	//update text notifying user of the path to the script he is editing
	[editorScriptPath setStringValue: [NSString stringWithFormat: @"Editing %@", path]];
	[editorText setString: [NSString stringWithContentsOfFile: path]];

	[window setTitle: @"Platypus Built-In Script Editor"];
	[NSApp beginSheet:	editorWindow
						modalForWindow: window 
						modalDelegate:nil
						didEndSelector:nil
						contextInfo:nil];
	[NSApp runModalForWindow: editorWindow];
	[NSApp endSheet: editorWindow];
    [editorWindow orderOut:self];	
}

- (IBAction)editorSave: (id)sender
{
	//see if we can write it
	if (![[NSFileManager defaultManager] isWritableFileAtPath: [scriptPathTextField stringValue]])
        [STUtil alert: @"Unable to save changes" subText: @"You don't the neccesary privileges to save this text file."];
	else //save it
		[[editorText string] writeToFile: [scriptPathTextField stringValue] atomically: YES];

	[window setTitle: @"Platypus"];
	[NSApp stopModal];
}

- (IBAction)editorCancel: (id)sender
{
	[window setTitle: @"Platypus"];
	[NSApp stopModal];
}

- (IBAction)editorCheckSyntax: (id)sender
{
	[[editorText string] writeToFile: [scriptPathTextField stringValue] atomically: YES];
	[self checkSyntaxOfScript: self];
}

#pragma mark -

/*****************************************
 - Open Platypus Help HTML file within app bundle
*****************************************/
- (IBAction) showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:
	 [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource:@"PlatypusDocumentation.html" ofType:nil]]
	];
}

/*****************************************
 - Open 'platypus' command line tool man page in PDF
*****************************************/
- (IBAction) showManPage:(id)sender
{	
	[[NSWorkspace sharedWorkspace] openFile: [[NSBundle mainBundle] pathForResource:@"platypus.man.pdf" ofType:nil]];
}

/*****************************************
 - Open Readme file
*****************************************/
- (IBAction) showReadme:(id)sender
{	
	[[NSWorkspace sharedWorkspace] openURL: 
	[NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource:@"Readme.html" ofType:nil]]
	];
}

/*****************************************
 - Open Platypus website in default browser
*****************************************/
- (IBAction) openWebsite: (id)sender
{
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: PROGRAM_WEBSITE]];
}
@end
