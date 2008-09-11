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

#import "IconController.h"
#import "IconFamily.h"
#import "STUtil.h"

@implementation IconController

/*****************************************
 - init function
*****************************************/
- (id)init
{
	if (self = [super init]) 
	{
		usesIcnsFile = FALSE;
	}
    return self;
}

- (IBAction)copyIcon:(id)sender
{
	[[NSPasteboard generalPasteboard] declareTypes: [NSArray arrayWithObject: NSTIFFPboardType] owner: self];
	[[NSPasteboard generalPasteboard] setData: [[iconImageWell image] TIFFRepresentation] forType: NSTIFFPboardType];
}

- (IBAction)pasteIcon:(id)sender
{
	NSImage *pastedIcon = [[[NSImage alloc] initWithPasteboard: [NSPasteboard generalPasteboard]] autorelease];
	if (pastedIcon != NULL)
	{
		[iconImageWell setImage: pastedIcon];
		[self iconDidChange: self];
		usesIcnsFile = 0;
	}
}

/*****************************************
 - Responds when user drags custom icon on image well
*****************************************/

- (IBAction) iconDidChange:(id)sender
{
	[iconNameTextField setStringValue:@"Custom Icon"];
	[iconImageWell performClick: self];//prevents the background from graying out
}

- (IBAction)nextIcon:(id)sender
{
	if ([iconToggleButton intValue] + 1 > [iconToggleButton maxValue])
		[iconToggleButton setIntValue: [iconToggleButton minValue]];
	else
		[iconToggleButton setIntValue: [iconToggleButton intValue] + 1];
	
	[self setAppIconForType: [iconToggleButton intValue]];

}

- (IBAction)previousIcon:(id)sender
{
	if ([iconToggleButton intValue] - 1 < [iconToggleButton minValue])
		[iconToggleButton setIntValue: [iconToggleButton maxValue]];
	else
		[iconToggleButton setIntValue: [iconToggleButton intValue] - 1];
	
	[self setAppIconForType: [iconToggleButton intValue]];
}

/*****************************************
 - Each script type has a certain icon associated with it.
 - Set the icon according to the type specified
*****************************************/

- (void)setAppIconForType: (int)type
{
	switch(type)
	{
		case 0:
			[iconImageWell setImage: [NSImage imageNamed:@"PlatypusDefault"]];
			[iconNameTextField setStringValue:@"Platypus Default"];
			break;
		case 1:
			[iconImageWell setImage: [NSImage imageNamed:@"PlatypusInstaller"]];
			[iconNameTextField setStringValue:@"Platypus Installer"];
			break;
		case 2:
			[iconImageWell setImage: [NSImage imageNamed:@"PlatypusPlate"]];
			[iconNameTextField setStringValue:@"Platypus Plate"];
			break;	
		case 3:
			[iconImageWell setImage: [NSImage imageNamed:@"NSDefaultApplicationIcon"]];
			[iconNameTextField setStringValue:@"Generic Application Icon"];
			break;
				
	}
	usesIcnsFile = 0;
}

- (IBAction)switchIcons:(id)sender
{
	[self setAppIconForType: [sender intValue]];
}

- (IBAction)selectIcnsFile:(id)sender
{
	NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	[oPanel setPrompt:@"Select"];
    [oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories: NO];
	
	[window setTitle: @"Platypus - Select an icns file"];

	//run open panel
    [oPanel beginSheetForDirectory:nil file:nil types: [NSArray arrayWithObject: @"icns"] modalForWindow: window modalDelegate: self didEndSelector: @selector(selectIcnsFileDidEnd:returnCode:contextInfo:) contextInfo: nil];
}

- (void)selectIcnsFileDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSImage *customIcon = [[NSImage alloc] initWithContentsOfFile: [oPanel filename]];
		if (customIcon != NULL)
		{
			[self setIcnsPath: [oPanel filename]];
		}
		else
			[STUtil alert:@"Corrupt Image File" subText: @"The image file you selected appears to be damaged or corrupt."];
	}
	[window setTitle: @"Platypus"];
}

- (void)setIcnsPath: (NSString *)icnsPath
{
		NSImage *customIcon = [[NSImage alloc] initWithContentsOfFile: icnsPath];
		if (customIcon != NULL)
		{
			icnsFilePath = [icnsPath retain];
			[iconImageWell setImage: customIcon];
			[customIcon autorelease];
			[self iconDidChange: self];
			usesIcnsFile = 1;
		}
		else
			[STUtil alert:@"Corrupt Image File" subText: @"The icns file you selected appears to be damaged or corrupt."];
}

/*****************************************
 - Write an NSImage as icon to a path
*****************************************/

- (void)writeIconToPath: (NSString *)path
{
	if ([iconImageWell image] == NULL)
		[STUtil alert:@"Icon Error" subText: @"No icon could be found for your application.  Please set an icon to fix this."];

	IconFamily *iconFam = [[IconFamily alloc] initWithThumbnailsOfImage: [iconImageWell image]];
	[iconFam writeToFile: path];
	[iconFam release];
}

/*****************************************
 - Put up dialog prompting file to take icon from
*****************************************/
- (IBAction) importIcon:(id)sender
{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	[oPanel setPrompt:@"Select"];
    [oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories: YES];
	
	[window setTitle: @"Platypus - Import a file's icon"];

	//run open panel
    [oPanel beginSheetForDirectory:nil file:nil types: nil modalForWindow: window modalDelegate: self didEndSelector: @selector(importIconDidEnd:returnCode:contextInfo:) contextInfo: nil];	
}

- (void)importIconDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		IconFamily  *icon = [IconFamily iconFamilyWithIconOfFile: [oPanel filename]];
		if (icon != NULL)
		{
			[iconImageWell setImage: [icon imageWithAllReps]];
			[self iconDidChange: self];
			usesIcnsFile = 0;
		}
		else
			[STUtil alert:@"Error getting icon" subText: @"The icon of the file you selected appears to be damaged or corrupt."];
	}
	[window setTitle: @"Platypus"];
}


/*****************************************
 - Put up dialog prompting for image file to use as icon
*****************************************/
- (IBAction) selectIcon:(id)sender
{
	//file types acceptable as custom icon data -- I think that's the lot that Apple's APIs can handle
	NSArray *fileTypes = [NSArray arrayWithObjects: @"icns", @"jpg", @"jpeg",@"gif",@"png",@"tif",@"tiff",@"bmp",@"pict",@"psd",@"pdf",@"tga",@"sgi",@"pntg", nil];

    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	[oPanel setPrompt:@"Select"];
    [oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories: NO];
	
	[window setTitle: @"Platypus - Select an image file"];

	//run open panel
    [oPanel beginSheetForDirectory:nil file:nil types: fileTypes modalForWindow: window modalDelegate: self didEndSelector: @selector(selectIconDidEnd:returnCode:contextInfo:) contextInfo: nil];
		
}

- (void)selectIconDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSImage *customIcon = [[NSImage alloc] initWithContentsOfFile: [oPanel filename]];
		if (customIcon != NULL)
		{
			[iconImageWell setImage: customIcon];
			[customIcon autorelease];
			[self iconDidChange: self];
			usesIcnsFile = 0;
		}
		else
			[STUtil alert:@"Corrupt Image File" subText: @"The image file you selected appears to be damaged or corrupt."];
	}
	[window setTitle: @"Platypus"];
}

- (BOOL) hasCustomIcon
{
	if ([[iconNameTextField stringValue] isEqualToString: @"Custom Icon"])
		return YES;
	
	return NO;
}

- (void) setImage: (NSImage *)img
{
	[iconImageWell setImage: img];
	[iconNameTextField setStringValue: @"Custom Icon"];
}

- (NSData *)getImage
{
	return [[iconImageWell image] TIFFRepresentation];
}

- (BOOL) usesIcnsFile
{
	return (BOOL)usesIcnsFile;
}

- (NSString *) getIcnsFilePath
{
	if (![[NSFileManager defaultManager] fileExistsAtPath: icnsFilePath])
	{
		[STUtil alert: @"Missing icns file" subText: [NSString stringWithFormat: @"The icns file %@ could not be found at the location you specified", icnsFilePath]];
		return @"";
	}
	return icnsFilePath;
}

- (BOOL)validateMenuItem:(NSMenuItem*)anItem 
{
	if ([[anItem title] isEqualToString:@"Paste Icon"])
	{
		NSArray		 *pbTypes = [NSArray arrayWithObjects: NSTIFFPboardType, NSPDFPboardType,NSPICTPboardType,NSPostScriptPboardType, NULL];
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		NSString	 *type = [pb availableTypeFromArray: pbTypes];
		
		if (type == nil)
			return NO;
	}
	return YES;
}

@end
