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


#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <AppKit/NSTableView.h>

@interface FileList : NSObject 
{
	UInt64			totalSize;
	NSMutableArray  *files;
	
	IBOutlet id		window;
	IBOutlet id addFileButton;
	IBOutlet id removeFileButton;
	IBOutlet id revealFileButton;
	IBOutlet id clearFileListButton;
	IBOutlet id tableView;
	IBOutlet id bundleSizeTextField;
	IBOutlet id contextualMenu;
	IBOutlet id platypusControl;
}
- (NSString *)getFileAtIndex:(int)index;
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (void) addFile: (NSString *)file;
- (void) addFiles: (NSArray *)fileNames;
- (BOOL) hasFile: (NSString *)fileName;
- (void) clearList;
- (int) numFiles;
- (NSArray *)getFilesArray;
- (void) removeFile: (int)index;
- (void) revealInFinder:(int)index;
- (IBAction)addFileToFileList:(id)sender;
- (void)addFilesPanelDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (IBAction)clearFileList:(id)sender;
- (IBAction)revealFileInFileList:(id)sender;
- (IBAction)removeFileFromFileList:(id)sender;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
- (int)selectedRow;
- (void)updateFileSizeField;
- (BOOL)allPathsAreValid;
- (UInt64)getTotalSize;

@end
