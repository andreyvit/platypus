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
#import "EnvController.h"

@implementation EnvController

- (id) init
{
		keys = [[NSMutableArray alloc] init];
		values = [[NSMutableArray alloc] init];
		[keys addObject: @"APP_BUNDLER"];
		[values addObject: PROGRAM_STAMP];
		return self;
}

-(void)dealloc
{
	[keys release];
	[values release];
	[super dealloc];
}

- (IBAction)add:(id)sender
{
	[keys addObject: @"VARIABLE"];
	[values addObject: @"Value"];
	[envTableView reloadData];
	[envTableView selectRow: [keys count]-1 byExtendingSelection: NO];
	[self tableViewSelectionDidChange: NULL];
}

- (void)set: (NSDictionary *)dict;
{
	[keys release];
	[values release];

	keys = [[NSMutableArray alloc] initWithArray: [dict allKeys]];
	values = [[NSMutableArray alloc] initWithArray: [dict allValues]];
		
	[self tableViewSelectionDidChange: NULL];
}

- (IBAction)apply:(id)sender
{
	[window setTitle: @"Platypus"];
	[NSApp stopModal];
}

- (IBAction)clear:(id)sender
{
	[keys removeAllObjects];
	[values removeAllObjects];
	[envTableView reloadData];
	[self tableViewSelectionDidChange: NULL];
}

- (IBAction)help:(id)sender
{	
	NSURL *fileURL = [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource:@"env.html" ofType:nil]];
	[[NSWorkspace sharedWorkspace] openURL: fileURL];
}

- (IBAction)remove:(id)sender
{
	if ([envTableView selectedRow] == -1)
		return;
	
	[keys removeObjectAtIndex: [envTableView selectedRow]];
	[values removeObjectAtIndex: [envTableView selectedRow]];
	[envTableView reloadData];
	[self tableViewSelectionDidChange: NULL];
}

- (IBAction)resetDefaults:(id)sender
{
	[self clear: self];
	[keys addObject: @"APP_BUNDLER"];
	[values addObject: PROGRAM_STAMP];
	[envTableView reloadData];
	[self tableViewSelectionDidChange: NULL];
}

- (IBAction)show:(id)sender
{
	[window setTitle: @"Platypus - Environmental Variables"];
	[envTableView reloadData];
	[NSApp beginSheet:	envWindow
						modalForWindow: window 
						modalDelegate:nil
						didEndSelector:nil
						contextInfo:nil];
	[NSApp runModalForWindow: envWindow];
	[NSApp endSheet:envWindow];
    [envWindow orderOut:self];
}


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return([keys count]);
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ([[aTableColumn identifier] caseInsensitiveCompare: @"2"] == NSOrderedSame)//value
	{
		return([values objectAtIndex: rowIndex]);
	}
	else if ([[aTableColumn identifier] caseInsensitiveCompare: @"1"] == NSOrderedSame)//name
	{
        return [keys objectAtIndex: rowIndex];
	}
	return(@"");
}

- (void)tableView:(NSTableView *)aTableView setObjectValue: anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    if (rowIndex < 0 || rowIndex > [values count]-1)
		return;
	
	if ([[aTableColumn identifier] caseInsensitiveCompare: @"2"] == NSOrderedSame)//value
	{
		[values replaceObjectAtIndex: rowIndex withObject: anObject];
	}
	else if ([[aTableColumn identifier] caseInsensitiveCompare: @"1"] == NSOrderedSame)//keys
	{
        [keys replaceObjectAtIndex: rowIndex withObject: [anObject uppercaseString]];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int selected = [envTableView selectedRow];

	if (selected != -1) //there is a selected item
		[removeButton setEnabled: YES];
	else
		[removeButton setEnabled: NO];

	if ([keys count] == 0)
		[clearButton setEnabled: NO];
	else
		[clearButton setEnabled: YES];
	
	if ([keys count] == 255)
		[addButton setEnabled: NO];
	else
		[addButton setEnabled: YES];
}

- (NSMutableDictionary *)environmentDictionary
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjects: values forKeys: keys];
	return([dict retain]);
}

- (BOOL)validateMenuItem:(NSMenuItem*)anItem 
{
	if ([[anItem title] isEqualToString:@"Remove Entry"] && [envTableView selectedRow] == -1)
		return NO;
	return YES;
}

@end
