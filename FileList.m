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

#import "FileList.h"
#import "STUtil.h"
#import "Platypus.h"

@implementation FileList

- (id) init
{
		files = [[NSMutableArray alloc] init];
		return self;
}

-(void)dealloc
{
	[files release];
	[super dealloc];
}

- (void)awakeFromNib
{
	totalSize = 0;
	[tableView registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
}


- (NSString *)getFileAtIndex:(int)index
{
	return [[files objectAtIndex: index] objectAtIndex: 0];
}

- (void) addFile: (NSString *)fileName
{
	[self addFiles: [NSArray arrayWithObject: fileName] ];
}

- (void) addFiles: (NSArray *)fileNames
{
	NSImage *icon;
	int i;
	for (i = 0; i < [fileNames count]; i++)
	{
		if (![self hasFile: [fileNames objectAtIndex: i]])
		{
			icon = [[NSWorkspace sharedWorkspace] iconForFile: [fileNames objectAtIndex: i]];
			[files addObject: [NSArray arrayWithObjects: [fileNames objectAtIndex: i], icon, nil]];
		}
	}
	[tableView reloadData];
	[self tableViewSelectionDidChange: NULL];
	[self updateFileSizeField];
}

- (BOOL) hasFile: (NSString *)fileName
{
	int i;
	
	for (i = 0; i < [files count]; i++)
	{
		if ([[[files objectAtIndex: i] objectAtIndex: 0] isEqualToString: fileName])
			return YES;
	}
	return NO;
}

- (void) clearList
{
	[files removeAllObjects];
}

- (void) removeFile: (int)index
{
	[files removeObjectAtIndex: index];
}

- (int)numFiles
{
	return([files count]);
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return([files count]);
}

- (NSArray *)getFilesArray
{
	NSMutableArray	*fileNames = [NSMutableArray arrayWithCapacity: 255];
	int				i;
	
	for (i = 0; i < [files count]; i++)
		[fileNames addObject: [[files objectAtIndex: i] objectAtIndex: 0]];

	return fileNames;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{	
	if ([[aTableColumn identifier] caseInsensitiveCompare: @"2"] == NSOrderedSame)//path
	{
		// check if bundled file still exists at path
		NSString *filePath = [[files objectAtIndex: rowIndex] objectAtIndex: 0];
		if ([[NSFileManager defaultManager] fileExistsAtPath: filePath])
			return(filePath);
		else // if not, we hilight red
		{
			NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys: [NSColor redColor], NSForegroundColorAttributeName, nil];
			return([[[NSAttributedString alloc] initWithString: filePath attributes: attr] autorelease]);
		}
	}
	else if ([[aTableColumn identifier] caseInsensitiveCompare: @"1"] == NSOrderedSame)//icon
	{
        return [[files objectAtIndex: rowIndex] objectAtIndex: 1];
	}
	
	return(@"");
}


- (void)revealInFinder: (int)index
{
	BOOL		isDir;
	NSString	*path = [[files objectAtIndex: index] objectAtIndex: 0];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) 
	{
            if (isDir)
				[[NSWorkspace sharedWorkspace] selectFile:nil inFileViewerRootedAtPath:path];
            else
				[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
	}
}




/*****************************************
 - called when a [+] button is pressed
*****************************************/

- (IBAction)addFileToFileList:(id)sender
{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	[oPanel setPrompt:@"Add"];
	[oPanel setCanChooseDirectories:YES];
    [oPanel setAllowsMultipleSelection:YES];
	
	[window setTitle: @"Platypus - Select files or folders to add"];
	
	//run open panel
    [oPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow: window modalDelegate: self didEndSelector: @selector(addFilesPanelDidEnd:returnCode:contextInfo:) contextInfo: nil];
}

- (void)addFilesPanelDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		//add all the files to the file list
        NSArray *filesToOpen = [oPanel filenames];
        int i, count = [filesToOpen count];
        for (i=0; i<count; i++) 
		{
			//we don't add if it already exists in the array
			if ([self hasFile: [filesToOpen objectAtIndex:i]] == NO)
				[self addFile: [filesToOpen objectAtIndex:i]];
        }
	}
	
	[window setTitle: @"Platypus"];
}

/*****************************************
 - called when [C] button is pressed
*****************************************/

- (IBAction)clearFileList:(id)sender
{
	[self clearList];
	[tableView reloadData];
	//update button status
	[self tableViewSelectionDidChange: NULL];
	[self updateFileSizeField];
}


/*****************************************
 - called when [R] button is pressed
*****************************************/
- (IBAction)revealFileInFileList:(id)sender
{	
	int i;
	NSIndexSet *selectedItems = [tableView selectedRowIndexes];
	
	for (i = 0; i < [self numFiles]; i++)
	{
		if ([selectedItems containsIndex: i])
			[self revealInFinder: i];
	}
}

/*****************************************
 - called when [-] button is pressed
*****************************************/

- (IBAction)removeFileFromFileList:(id)sender
{
	int i, didRemove = FALSE;
	NSIndexSet *selectedItems = [tableView selectedRowIndexes];
	
	for (i = [self numFiles]; i >= 0; i--)
	{
		if ([selectedItems containsIndex: i])
		{
			[self removeFile: i];
			didRemove = TRUE;
		}
	}
	
	[tableView reloadData];
	[self tableViewSelectionDidChange: NULL];
	[self updateFileSizeField];
}

/*****************************************
 - Updates text field listing total size of bundled files
*****************************************/
- (void)updateFileSizeField
{
	int			i;
	
	totalSize = 0;
	NSString	*totalSizeString;
	

	//if there are no items, we just list it as 0 items
	if ([self numFiles] <= 0)
	{
		[bundleSizeTextField setStringValue: [NSString stringWithFormat: @"%d items", [self numFiles]]];
		[platypusControl updateEstimatedAppSize];
		return;
	}
	
	//otherwise, loop through all files, calculate size
	for (i = 0; i < [self numFiles]; i++)
	{		
		totalSize += [STUtil fileOrFolderSize: [self getFileAtIndex: i]];
	}
	
	totalSizeString = [STUtil sizeAsHumanReadable: totalSize];
	if ([self numFiles] > 1)
		[bundleSizeTextField setStringValue: [NSString stringWithFormat: @"%d items  ( %@ )", [self numFiles], totalSizeString]];
	else
		[bundleSizeTextField setStringValue: [NSString stringWithFormat: @"%d item  ( %@ )", [self numFiles], totalSizeString]];

	[platypusControl updateEstimatedAppSize];
}


/*****************************************
 - Delegate managing selection in the Bundled Files list
*****************************************/

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int i;
	int selected = 0;
	NSIndexSet *selectedItems;
	
	//selection changed in File List
	if ([aNotification object] == tableView || [aNotification object] == NULL)
	{
		selectedItems = [tableView selectedRowIndexes];
		for (i = 0; i < [self numFiles]; i++)
		{
			if ([selectedItems containsIndex: i])
			{
				selected++;
			}
		}
		
		//update button status
		if (selected == 0)
		{
			[removeFileButton setEnabled: NO];
			[revealFileButton setEnabled: NO];
		}
		else
		{
			[removeFileButton setEnabled: YES];
			[revealFileButton setEnabled: YES];
		}
		
		if ([self numFiles] == 0)
			[clearFileListButton setEnabled: NO];
		else
			[clearFileListButton setEnabled: YES];
	}
}

- (int)selectedRow
{
	return [tableView selectedRow];
}


/*****************************************
 - Drag and drop handling
*****************************************/
-(BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard *pboard = [info draggingPasteboard];	
	NSArray *draggedFiles = [pboard propertyListForType:NSFilenamesPboardType];
	[self addFiles: draggedFiles];
	return YES;
}

-(NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	return NSDragOperationLink;
}


/*****************************************
 - Delegate for enabling and disabling contextual menu items
*****************************************/
- (BOOL)validateMenuItem:(NSMenuItem*)anItem 
{
	int selectedRow = [tableView selectedRow];

	if ([[anItem title] isEqualToString: @"Add New File"] || [[anItem title] isEqualToString: @"Add File To Bundle"])
		return YES;
	
	if ([[anItem title] isEqualToString: @"Clear File List"] && [self numFiles] >= 1)
		return YES;

	if (selectedRow == -1)
		return NO;

	return YES;
}


/*****************************************
 - Tells us whether there are missing/moved files on the list
*****************************************/
- (BOOL)allPathsAreValid
{
	int i;
	
	for (i = 0; i < [self numFiles]; i++)
	{
		if (![[NSFileManager defaultManager] fileExistsAtPath: [[files objectAtIndex: i] objectAtIndex: 0]])
		{
			return NO;
		}
	}
	return YES;
}

/*****************************************
 - Returns the total size of all bundled files at the moment
*****************************************/

-(UInt64)getTotalSize
{
	return totalSize;
}

@end
