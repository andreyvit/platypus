/*
    ScriptExec - binary bundled into Platypus-created applications
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
#import <Security/Authorization.h>
#import <WebKit/WebKit.h>

#import <sys/wait.h>
#import <stdio.h>
#import <fcntl.h>

#import "CommonDefs.h"
#import "NSDataAdditions.h"

//limits
#define	kMaxFileArguments		4096
#define	kMaxPathLength			4096

// output modes
#define	kNoOutput			1
#define	kProgressBarOutput	2
#define	kTextOutput			3
#define kWebOutput			4

#define kNormalExecution		0
#define kPrivilegedExecution	1

// path to temp script file
#define	kTempScriptFile		@"/tmp/.plx_tmp"

@interface ScriptExecController : NSObject
{
    IBOutlet id cancelButton;
    IBOutlet id messageTextField;
    IBOutlet id progressBar;
	IBOutlet id progressWindow;
	
	IBOutlet id textOutputWindow;
	IBOutlet id textOutputCancelButton;
	IBOutlet id textOutputTextField;
	IBOutlet id textOutputProgressIndicator;
	
	IBOutlet id webOutputWindow;
	IBOutlet id webOutputCancelButton;
	IBOutlet id webOutputWebView;
	IBOutlet id webOutputProgressIndicator;
	
	//menu items
	IBOutlet id hideMenuItem;
	IBOutlet id quitMenuItem;
	IBOutlet id aboutMenuItem;
	
	NSTask			*task;
	NSTimer			*checkStatusTimer;

	NSPipe			*outputPipe;
	NSFileHandle	*readHandle;

	NSMutableArray  *arguments;
	NSMutableArray  *fileArgs;
	NSArray			*paramsArray;

	NSString		*interpreter;
	NSString		*scriptPath;
	NSString		*hiddenScriptPath;
	NSString		*appName;
	
	NSFont			*textFont;
	NSColor			*textForeground;
	NSColor			*textBackground;
	int				 textEncoding;
	
	int			appPathAsFirstArg;
	int			execStyle;
	int			outputType;
	int			isDroppable;
	int			remainRunning;
	int			secureScript;
	int			childPid;
	
	BOOL		isTaskDone;
	BOOL		isTaskStarted;
}
- (void)executeScript;
- (void)checkTaskStatus;
- (void)executeScriptWithPrivileges;
- (void)checkPrivilegedTaskStatus;
- (void)taskFinished;
- (void)getTextData: (NSNotification *)aNotification;
- (void)loadSettings;
- (IBAction)cancel:(id)sender;
- (void)fatalAlert: (NSString *)message subText: (NSString *)subtext;
@end
