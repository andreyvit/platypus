//
//  PrefsController.h
//  Platypus
//
//  Created by Sveinbjorn Thordarson on 6/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <Security/Authorization.h>
#import "STUtil.h"
#import "CommonDefs.h"

@interface PrefsController : NSObject 
{
	IBOutlet id revealAppCheckbox;
    IBOutlet id defaultEditorMenu;
	IBOutlet id defaultBundleIdentifierTextField;
	IBOutlet id defaultAuthorTextField;
	IBOutlet id CLTStatusTextField;
	IBOutlet id installCLTButton;
	IBOutlet id installCLTProgressIndicator;
	IBOutlet id prefsWindow;
}
- (IBAction)showPrefs:(id)sender;
- (IBAction)applyPrefs:(id)sender;
- (void)setIconsForEditorMenu;
- (IBAction)restoreDefaultPrefs:(id)sender;
- (IBAction)installCLT:(id)sender;
-(void)installCommandLineTool;
-(void)uninstallCommandLineTool;
-(BOOL)isCommandLineToolInstalled;
- (void)executeScriptWithPrivileges: (NSString *)pathToScript;
- (IBAction) selectScriptEditor:(id)sender;
- (void)updateCLTStatus;
@end
