//
//  PrefsController.m
//  Platypus
//
//  Created by Sveinbjorn Thordarson on 6/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PrefsController.h"


@implementation PrefsController

/*****************************************
 - Set controls according to data in NSUserDefaults
*****************************************/

- (IBAction)showPrefs:(id)sender
{	
	if ([prefsWindow isVisible])// if prefs are already visible we just bring the window front
	{
		[prefsWindow makeKeyAndOrderFront: sender];
		return;
	}
	
	// set controls according to NSUserDefaults
	[revealAppCheckbox setState: [[NSUserDefaults standardUserDefaults] boolForKey:@"RevealApplicationWhenCreated"]];
	[defaultEditorMenu setTitle: [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultEditor"]];
	[defaultAuthorTextField setStringValue: [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultAuthor"]];
	[defaultBundleIdentifierTextField setStringValue: [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultBundleIdentifierPrefix"]];

	//set icons for editor menu
	[self setIconsForEditorMenu];
	[self updateCLTStatus];

	//center and show prefs window
	[prefsWindow center];
	[prefsWindow makeKeyAndOrderFront: sender];
}

/*****************************************
 - Set the icons for the menu items in the Editors list
*****************************************/

- (void)setIconsForEditorMenu
{
	int i;
	NSSize	smallIconSize = { 16, 16 };

	for (i = 0; i < [defaultEditorMenu numberOfItems]; i++)
	{
		if ([[[defaultEditorMenu itemAtIndex: i] title] isEqualToString: @"Built-In"] == YES)
		{
			NSImage *icon = [NSImage imageNamed: @"Platypus"];
			[icon setSize: smallIconSize];
			[[defaultEditorMenu itemAtIndex: i] setImage: icon];
		}
		else if ([[[defaultEditorMenu itemAtIndex: i] title] isEqualToString: @"Select..."] == NO && [[[defaultEditorMenu itemAtIndex: i] title] length] > 0)
		{
			NSImage *icon = [NSImage imageNamed: @"NSDefaultApplicationIcon"];
			NSString *appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication: [[defaultEditorMenu itemAtIndex: i] title]];
			if (appPath != NULL) // app found
				icon = [[NSWorkspace sharedWorkspace] iconForFile: appPath];
			[icon setSize: smallIconSize];
			[[defaultEditorMenu itemAtIndex: i] setImage: icon];
		}
	}
}

/*****************************************
 - Set NSUserDefaults according to control settings
*****************************************/

- (IBAction)applyPrefs:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool: [revealAppCheckbox state]  forKey:@"RevealApplicationWhenCreated"];
	[[NSUserDefaults standardUserDefaults] setObject: [defaultEditorMenu titleOfSelectedItem]  forKey:@"DefaultEditor"];
	//make sure bundle identifier ends with a '.'
	if ([[defaultBundleIdentifierTextField stringValue] characterAtIndex: [[defaultBundleIdentifierTextField stringValue]length]-1] != '.')
		
		[[NSUserDefaults standardUserDefaults] setObject: [[defaultBundleIdentifierTextField stringValue] stringByAppendingString: @"."]  forKey:@"DefaultBundleIdentifierPrefix"];
	else
		[[NSUserDefaults standardUserDefaults] setObject: [defaultBundleIdentifierTextField stringValue]  forKey:@"DefaultBundleIdentifierPrefix"];
	[[NSUserDefaults standardUserDefaults] setObject: [defaultAuthorTextField stringValue]  forKey:@"DefaultAuthor"];
	
	[prefsWindow performClose: sender];
}


/*****************************************
 - Restore prefs to their default value
*****************************************/

- (IBAction)restoreDefaultPrefs:(id)sender
{
	[revealAppCheckbox setState: NO];
	[defaultEditorMenu setTitle: @"Built-In"];
	[defaultAuthorTextField setStringValue: NSFullUserName()];
	
	// create default bundle identifier prefix string
	NSString *bundleId = [NSString stringWithFormat: @"org.%@.", NSUserName()];
	bundleId = [[bundleId componentsSeparatedByString:@" "] componentsJoinedByString:@""];//remove all spaces
	[defaultBundleIdentifierTextField setStringValue: bundleId];
}


/*****************************************
 - For selecting any application as the external editor for script
*****************************************/

- (IBAction) selectScriptEditor:(id)sender
{
	int			result;
	NSString	*editorName;
	
	//create open panel
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	[oPanel setTitle: @"Select Editor"];
    [oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories: NO];
	
	//run open panel
    result = [oPanel runModalForDirectory:nil file:nil types: [NSArray arrayWithObject:@"app"]];
    if (result == NSOKButton) 
	{
		//set app name minus .app suffix
		editorName = [STUtil cutSuffix: [[oPanel filename] lastPathComponent]];
		[defaultEditorMenu setTitle: editorName];
		[self setIconsForEditorMenu];
	}
	else
		[defaultEditorMenu setTitle: [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultEditor"]];
}

/*****************************************
 - Update report on command line tool install status
    -- both text field and button
*****************************************/

- (void)updateCLTStatus
{
	//set status of clt install button and text field
	if ([self isCommandLineToolInstalled])
	{
		NSString *versionString = [NSString stringWithContentsOfFile: CMDLINE_VERSION_PATH encoding: NSASCIIStringEncoding error: NULL];
		
		if ([versionString isEqualToString: PROGRAM_VERSION]) // it's installed and current
		{
			[CLTStatusTextField setTextColor: [NSColor greenColor]];
			[CLTStatusTextField setStringValue: @"Command line tool is installed"];
		}
		else // installed but not this version
		{
			[CLTStatusTextField setTextColor: [NSColor orangeColor]];

			if ([versionString floatValue] < [PROGRAM_VERSION floatValue])
				[CLTStatusTextField setStringValue: @"Old version of command line"]; //older
			else
				[CLTStatusTextField setStringValue: @"Newer version of command line"]; //newer
		}
		[installCLTButton setTitle: @"Uninstall"];
	}
	else  // it's not installed at all
	{
		[CLTStatusTextField setStringValue: @"Command line tool is not installed"];
		[CLTStatusTextField setTextColor: [NSColor redColor]];
		[installCLTButton setTitle: @"Install"];
	}
}

/*****************************************
 - Install/uninstall CLT based on install status
*****************************************/

- (IBAction)installCLT:(id)sender;
{
	if ([self isCommandLineToolInstalled] == NO)
		[self installCommandLineTool];
	else
		[self uninstallCommandLineTool];
}

/*****************************************
 - Run install script for CLT stuff
*****************************************/

-(void)installCommandLineTool
{
	[installCLTProgressIndicator setUsesThreadedAnimation: YES];
	[installCLTProgressIndicator startAnimation: self];

	[self executeScriptWithPrivileges: [[NSBundle mainBundle] pathForResource: @"InstallCommandLineTool.sh" ofType: NULL]];
	
	[self updateCLTStatus];
	[installCLTProgressIndicator stopAnimation: self];
}

/*****************************************
 - Run UNinstall script for CLT stuff
*****************************************/

-(void)uninstallCommandLineTool
{
	[installCLTProgressIndicator setUsesThreadedAnimation: YES];
	[installCLTProgressIndicator startAnimation: self];

	[self executeScriptWithPrivileges: [[NSBundle mainBundle] pathForResource: @"UninstallCommandLineTool.sh" ofType: NULL]];
	
	[self updateCLTStatus];
	[installCLTProgressIndicator stopAnimation: self];
}

/*****************************************
 - Determine whether command line tool is installed
*****************************************/

-(BOOL)isCommandLineToolInstalled
{
	if	   ([[NSFileManager defaultManager] fileExistsAtPath: CMDLINE_VERSION_PATH] &&
				[[NSFileManager defaultManager] fileExistsAtPath: CMDLINE_TOOL_PATH] &&
				[[NSFileManager defaultManager] fileExistsAtPath: CMDLINE_MANPAGE_PATH] &&
				[[NSFileManager defaultManager] fileExistsAtPath: CMDLINE_EXEC_PATH] &&
				[[NSFileManager defaultManager] fileExistsAtPath: CMDLINE_ICON_PATH])
	{
		return YES;
	}
	return NO;
}

/*****************************************
 - Run script with privileges using Authentication Manager
*****************************************/
- (void)executeScriptWithPrivileges: (NSString *)pathToScript
{
	OSErr					err = noErr;
	AuthorizationRef 		authorizationRef;
	char					*args[2];
	char					resDirPath[4096];
	char					scriptPath[4096];

	//get path to script in c string format
	[pathToScript getCString: (char *)&scriptPath maxLength: 4096];
	
	//create array of arguments - first argument is the Resource directory of the Platypus application
	[[[NSBundle mainBundle] resourcePath] getCString: (char *)&resDirPath];
	args[0] = resDirPath;
	args[1] = NULL;
    
    // Use Apple's Authentication Manager APIs to get an Authorization Reference
    err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    if (err != errAuthorizationSuccess)
	{
		NSLog(@"Authorization for script execution failed - Error %d", err);
        return;
	}
	
	//use Authorization Reference to execute the script with privileges
    if (!(err = AuthorizationExecuteWithPrivileges(authorizationRef,(char *)&scriptPath, kAuthorizationFlagDefaults, args, NULL)) != noErr)
	{
		// wait for task to finish
		int child;
		wait(&child);
			
		// destroy the auth ref
		AuthorizationFree(authorizationRef, kAuthorizationFlagDefaults);
	}
}

#pragma mark -

@end
