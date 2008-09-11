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

@interface IconController : NSObject
{
    IBOutlet id iconImageWell;
    IBOutlet id iconLabel;
    IBOutlet id window;
	IBOutlet id iconToggleButton;
	IBOutlet id iconNameTextField;
	
	int			usesIcnsFile;
	NSString	*icnsFilePath;

}
- (IBAction)copyIcon:(id)sender;
- (IBAction)pasteIcon:(id)sender;
- (IBAction)iconDidChange:(id)sender;
- (IBAction)nextIcon:(id)sender;
- (IBAction)previousIcon:(id)sender;
- (void)setAppIconForType: (int)type;
- (IBAction)switchIcons:(id)sender;
- (IBAction)selectIcnsFile:(id)sender;
- (void)selectIcnsFileDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)writeIconToPath: (NSString *)path;
- (IBAction) importIcon:(id)sender;
- (void)importIconDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (IBAction) selectIcon:(id)sender;
- (void)selectIconDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (BOOL) hasCustomIcon;
- (void) setImage: (NSImage *)img;
- (NSData *)getImage;
- (BOOL) usesIcnsFile;
- (NSString *)getIcnsFilePath;
- (void)setIcnsPath: (NSString *)icnsPath;

@end
