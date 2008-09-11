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


#import <Cocoa/Cocoa.h>
#import "Platypus.h"

@interface ProfilesController : NSObject 
{
	IBOutlet id profilesMenu;
	IBOutlet id platypusControl;
}
- (IBAction) loadProfile:(id)sender;
- (void) loadProfileFile: (NSString *)file;
- (IBAction) saveProfile:(id)sender;
- (IBAction) saveProfileToLocation:(id)sender;
- (void) writeProfile: (NSDictionary *)dict toFile: (NSString *)profileDestPath;
- (void) profileMenuItemSelected: (id)sender;
- (IBAction) clearAllProfiles:(id)sender;
- (void) constructProfilesMenu;
- (NSArray *) getProfilesList;
@end
