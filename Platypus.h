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
#import <Carbon/Carbon.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#import "CommonDefs.h"
#import "PlatypusAppSpec.h"
#import "FileList.h"
#import "SuffixList.h"
#import "TypesList.h"
#import "IconFamily.h"
#import "STUtil.h"
#import "EnvController.h"
#import "IconController.h"
#import "FileTypesController.h"
#import "ParamsController.h"
#import "ProfilesController.h"
#import "TextSettingsController.h"

@interface Platypus : NSObject
{
	//basic controls    
	IBOutlet id appNameTextField;
	IBOutlet id scriptTypePopupMenu;
    IBOutlet id scriptPathTextField;
	IBOutlet id editScriptButton;
	IBOutlet id revealScriptButton;
	IBOutlet id outputTypePopupMenu;
	IBOutlet id createAppButton;
	IBOutlet id textOutputSettingsButton;
    
    IBOutlet id showAdvancedArrow;
	IBOutlet id showOptionsTextField;
	
	//advanced options controls
	IBOutlet id interpreterTextField;
	IBOutlet id versionTextField;
	IBOutlet id signatureTextField;
	IBOutlet id bundleIdentifierTextField;
	IBOutlet id authorTextField;

	IBOutlet id rootPrivilegesCheckbox;
	IBOutlet id encryptCheckbox;
    IBOutlet id isDroppableCheckbox;
	IBOutlet id showInDockCheckbox;
	IBOutlet id remainRunningCheckbox;	
	IBOutlet id editTypesButton;
	IBOutlet id toggleAdvancedMenuItem;
	
	IBOutlet id appSizeTextField;
		
	//editor
	IBOutlet id editorCheckSyntaxButton;
	IBOutlet id editorWindow;
	IBOutlet id editorScriptPath;
	IBOutlet id editorText;
	
	IBOutlet id commandWindow;
	IBOutlet id commandTextField;
	
	//menus
	IBOutlet id openRecentMenu;
		
	IBOutlet id syntaxCheckerTextField;
	IBOutlet id syntaxScriptPathTextField;
	
	//windows
	IBOutlet id window;
	IBOutlet id syntaxCheckerWindow;//sheet
	
	// interface controllers
	IBOutlet id envControl;
	IBOutlet id iconControl;
	IBOutlet id typesControl;
	IBOutlet id paramsControl;
	IBOutlet id profilesControl;
	IBOutlet id textSettingsControl;
	IBOutlet id prefsControl;
	
	FileList			*fileList;
	NSMutableArray		*recentItems;
	NSArray				*defaultInterpreters;
}

- (void) createAppSupportFolders;
- (IBAction)createButtonPressed: (id)sender;
- (void)createApp:(NSSavePanel *)sPanel returnCode:(int)result contextInfo:(void *)contextInfo;
- (IBAction)editScript:(id)sender;
- (IBAction)newScript:(id)sender;
- (IBAction)revealScript:(id)sender;
- (IBAction)runScript:(id)sender;

- (IBAction)outputTypeWasChanged:(id)sender;

- (IBAction)scriptTypeSelected:(id)sender;
- (IBAction)selectScript:(id)sender;
- (void)selectScriptPanelDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (IBAction)toggleAdvancedOptions:(id)sender;


- (BOOL)verifyFieldContents;
- (IBAction)isDroppableWasClicked:(id)sender;

- (IBAction)clearAllFields:(id)sender;

- (void)setScriptType: (int)typeNum;
- (void)loadScript:(NSString *)filename;
- (int)getFileTypeFromSuffix: (NSString *)fileName;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
- (NSString *)generateBundleIdentifier;
- (BOOL)validateMenuItem:(NSMenuItem*)anItem;
-(void) constructOpenRecentMenu;

- (void)updateEstimatedAppSize;
- (NSString *)estimatedAppSize;

-(id)appSpecFromControls;
- (void) controlsFromAppSpec: (id)spec;

//Help
- (IBAction) showHelp:(id)sender;
- (IBAction) showReadme:(id)sender;
- (IBAction) openWebsite: (id)sender;

//Select editor
- (void)openScriptInBuiltInEditor: (NSString *)path;
@end
