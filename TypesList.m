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

#import "TypesList.h"


@implementation TypesList

- (id) init
{
		items = [[NSMutableArray alloc] init];
		return self;
}

-(void)dealloc
{
	[items release];
	[super dealloc];
}

- (NSString *)getTypeAtIndex:(int)index
{
	return ([[items objectAtIndex: index] objectAtIndex: 0]);
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return ([items count]);
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	//return ([items objectAtIndex: rowIndex]);
	if ([[aTableColumn identifier] caseInsensitiveCompare: @"2"] == NSOrderedSame)
	{
		return([[items objectAtIndex: rowIndex] objectAtIndex: 0]);
	}
	else if ([[aTableColumn identifier] caseInsensitiveCompare: @"1"] == NSOrderedSame)
	{
		if (rowIndex == 0)
		{
			NSImageCell* iconCell;
			iconCell = [[[NSImageCell alloc] init] autorelease];
			[aTableColumn setDataCell:iconCell];
		}
        
        return [[items objectAtIndex: rowIndex] objectAtIndex: 1];
	}
	return(@"");
}

- (void) addType: (NSString *)type
{	
	NSString *hfsFileType;

	//get hfs file type string
	if ([type isEqualToString: @"fold"])
		hfsFileType = @"'fldr'";
	else
		hfsFileType = [NSString stringWithFormat: @"'%@'", type];
		
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFileType: hfsFileType];
	[items addObject: [NSArray arrayWithObjects: type, icon, nil]];
}

- (void) addTypes: (NSArray *)types
{
	int i;
	
	for (i = 0; i < [types count]; i++)
		[self addType: [types objectAtIndex: i]];
}

- (BOOL) hasType: (NSString *)suffix
{
	int i;
	for (i = 0; i < [items count]; i++)
	{
		if ([[[items objectAtIndex: i] objectAtIndex: 0] isEqualToString: suffix])
			return YES;
	}
	return NO;
}

- (BOOL) hasAllTypes
{
	int i;
	for (i = 0; i < [items count]; i++)
	{
		if ([[[items objectAtIndex: i] objectAtIndex: 0] isEqualToString: @"****"])
			return YES;
	}
	return NO;
}

- (BOOL) hasFolderType
{
	int i;
	for (i = 0; i < [items count]; i++)
	{
		if ([[[items objectAtIndex: i] objectAtIndex: 0] isEqualToString: @"fold"])
			return YES;
	}
	return NO;
}

- (void) clearList
{
	[items removeAllObjects];
}

- (int) numTypes
{
		return ([items count]);
}

- (void) removeType: (int)index
{
	if ([items count] > 0)
		[items removeObjectAtIndex: index];
}

- (NSArray *) getTypesArray
{
	short i;
	NSMutableArray	*types = [NSMutableArray arrayWithCapacity: 255];
	
	for (i = 0; i < [items count]; i++)
	{
		[types addObject: [[items objectAtIndex: i] objectAtIndex: 0]];
	}

	return types;
}
@end
