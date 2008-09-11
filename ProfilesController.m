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

#import "ProfilesController.h"

@implementation ProfilesController

/*****************************************
 - Select dialog for .platypus profile
*****************************************/

- (IBAction)loadProfile:(id)sender
{
	NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	[oPanel setPrompt:@"Open"];
    [oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories: NO];
	
	if (NSOKButton == [oPanel	runModalForDirectory: [PROFILES_FOLDER stringByExpandingTildeInPath] file: NULL types: [NSArray arrayWithObjects: @"platypus", NULL]])
		[self loadProfileFile: [oPanel filename]];
}

/*****************************************
 - Deal with dropped .platypus profile files
*****************************************/

- (void)loadProfileFile: (NSString *)file
{	
	PlatypusAppSpec *spec = [[PlatypusAppSpec alloc] initWithProfile: file];
	[platypusControl controlsFromAppSpec: spec];
	[spec release];
	[platypusControl controlTextDidChange: NULL];
}

/*****************************************
 - Save a profile with values from fields in default location
*****************************************/

- (IBAction) saveProfile:(id)sender;
{
	if (![platypusControl verifyFieldContents])
		return;

	// get profile from platypus controls
	NSDictionary *profileDict = [[platypusControl appSpecFromControls] properties];
	
	// create path for profile file and write to it
	NSString *profileDestPath = [NSString stringWithFormat: @"%@/%@.platypus", [PROFILES_FOLDER stringByExpandingTildeInPath], [profileDict objectForKey: @"Name"]];
	[self writeProfile: profileDict toFile: profileDestPath];
}

/*****************************************
 - Save a profile with in user-specified location
*****************************************/

- (IBAction) saveProfileToLocation:(id)sender;
{
	if (![platypusControl verifyFieldContents])
		return;

	// get profile from platypus controls
	NSDictionary *profileDict = [[platypusControl appSpecFromControls] properties];
	NSString *defaultName = [NSString stringWithFormat: @"%@.platypus", [profileDict objectForKey: @"Name"]];
	
	NSSavePanel *sPanel = [NSSavePanel savePanel];
	[sPanel setTitle:@"Save Platypus Profile"];
	[sPanel setPrompt:@"Save"];
	
	if ([sPanel runModalForDirectory:  [PROFILES_FOLDER stringByExpandingTildeInPath] file: defaultName] == NSFileHandlingPanelOKButton)
		[self writeProfile: profileDict toFile: [sPanel filename]];
}


/*****************************************
 - Write profile dictionary to path
*****************************************/

- (void)writeProfile: (NSDictionary *)dict toFile: (NSString *)profileDestPath;
{
	// if there's a file already, make sure we can overwrite
	if ([[NSFileManager defaultManager] fileExistsAtPath: profileDestPath] && ![[NSFileManager defaultManager] isDeletableFileAtPath: profileDestPath])
	{
		[STUtil alert: @"Error" subText: [NSString stringWithFormat: @"Cannot delete file %@.", profileDestPath]];
		return;
	}
	[dict writeToFile: profileDestPath atomically: YES];
	[self constructProfilesMenu];
}


/*****************************************
 - Fill Platypus fields in with data from profile when it's selected in the menu
*****************************************/

-(void) profileMenuItemSelected: (id)sender
{
	NSString *profilePath = [NSString stringWithFormat: @"%@/%@", [PROFILES_FOLDER stringByExpandingTildeInPath], [sender title]];

	// if command key is down, we reveal in finder
	if(GetCurrentKeyModifiers() & cmdKey)
		[[NSWorkspace sharedWorkspace] selectFile: profilePath inFileViewerRootedAtPath:nil];
	else
		[self loadProfileFile: profilePath];
}

/*****************************************
 - Clear the profiles list
*****************************************/

- (IBAction) clearAllProfiles:(id)sender
{
	if (NO == [STUtil proceedWarning: @"Delete all profiles?" subText: @"This will permanently delete all profiles in your Profiles folder.  Are you sure you wish to proceed?"])
		return;

	//delete all .platypus files in PROFILES_FOLDER
	
	NSFileManager			*manager = [NSFileManager defaultManager];
	NSDirectoryEnumerator	*dirEnumerator = [manager enumeratorAtPath: [PROFILES_FOLDER stringByExpandingTildeInPath]];
	NSString *filename;
	
	while ((filename = [dirEnumerator nextObject]) != NULL)
	{
		if ([filename hasSuffix: @"platypus"])
		{
			NSString *path = [NSString stringWithFormat: @"%@/%@",[PROFILES_FOLDER stringByExpandingTildeInPath],filename];
			if (![manager isDeletableFileAtPath: path])
				[STUtil alert: @"Error" subText: [NSString stringWithFormat: @"Cannot delete file %@.", path]];
			[manager removeFileAtPath: path handler: NULL];
		}
	}
	
	//regenerate the menu
	[self constructProfilesMenu];
}

/*****************************************
 - Generate the Profiles menu according to the save profiles
*****************************************/

- (void) constructProfilesMenu
{
	int i;
	NSArray *profiles = [self getProfilesList];

	//clear out all menu itesm
	while ([profilesMenu numberOfItems] > 4)
		[profilesMenu removeItemAtIndex: 4];

	if ([profiles count] > 0)
	{
		//populate with contents of array
		for (i = 0; i < [profiles count]; i++)
		{
			NSMenuItem *menuItem = [profilesMenu addItemWithTitle: [profiles objectAtIndex: i] action: @selector(profileMenuItemSelected:) keyEquivalent:@""];
			[menuItem setTarget: self];
			[menuItem setEnabled: YES];
			[menuItem setImage: [[NSWorkspace sharedWorkspace] iconForFileType: @"platypus"]];
		}
	}
	else
		[profilesMenu addItemWithTitle: @"Empty" action: NULL keyEquivalent:@""];
}

/*****************************************
 - Get list of .platypus files in Profiles folder
*****************************************/

- (NSArray *)getProfilesList
{
	NSMutableArray			*profilesArray = [NSMutableArray arrayWithCapacity: 255];;
	NSFileManager			*manager = [NSFileManager defaultManager];
	NSDirectoryEnumerator	*dirEnumerator = [manager enumeratorAtPath: [PROFILES_FOLDER stringByExpandingTildeInPath]];
	NSString *filename;
	while ((filename = [dirEnumerator nextObject]) != NULL)
	{
		if ([filename hasSuffix: @"platypus"])
			[profilesArray addObject: filename];
	}
	return profilesArray;
}

/*****************************************
 - Profile menu item validation
*****************************************/

- (BOOL)validateMenuItem:(NSMenuItem*)anItem 
{
	if ([[anItem title] isEqualToString:@"Clear All Profiles"] && [[self getProfilesList] count] < 1)
		return NO;
	
	return YES;
}

@end
