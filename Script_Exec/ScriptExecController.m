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

#import "ScriptExecController.h"

@implementation ScriptExecController

- (id)init
{
	if (self = [super init]) 
	{
		arguments = [[NSMutableArray alloc] initWithCapacity: kMaxFileArguments+2];
		fileArgs = [[NSMutableArray alloc] initWithCapacity: kMaxFileArguments];
		isTaskDone = NO;
		isTaskStarted = NO;
		textEncoding = NSASCIIStringEncoding;
    }
    return self;
}

-(void)dealloc
{
	if (arguments != NULL) { [arguments release]; }
	if (fileArgs != NULL)  { [fileArgs release];  }
	
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//load settings from app bundle
	[self loadSettings];
	
	//put application name into the relevant menu items
	[quitMenuItem setTitle: [NSString stringWithFormat: @"Quit %@", appName]];
	[aboutMenuItem setTitle: [NSString stringWithFormat: @"About %@", appName]];
	[hideMenuItem setTitle: [NSString stringWithFormat: @"Hide %@", appName]];
	
	//create progress window if so specified
	if (outputType == kProgressBarOutput)
	{
		//prepare progress bar
		[progressBar setUsesThreadedAnimation: YES];
		[progressBar startAnimation: self];
		
		//preare window
		[progressWindow setTitle: appName];
		[progressWindow center];
		[progressWindow makeKeyAndOrderFront: self];
	}
	else if (outputType == kTextOutput)
	{   		
		// set font and color
		[textOutputTextField setFont: textFont];
		[textOutputTextField setTextColor: textForeground];
		[textOutputTextField setBackgroundColor: textBackground];
		
		// fire off progress indicator
		[textOutputProgressIndicator setUsesThreadedAnimation: YES];
		[textOutputProgressIndicator startAnimation: self];
		
		// prepare window
		[textOutputWindow setTitle: appName];
		[textOutputWindow center];
		[textOutputWindow makeKeyAndOrderFront: self];
	}
	else if (outputType == kWebOutput)
	{
		// fire off progress indicator
		[webOutputProgressIndicator setUsesThreadedAnimation: YES];
		[webOutputProgressIndicator startAnimation: self];
		
		// prepare window
		[webOutputWindow setTitle: appName];
		[webOutputWindow center];
		[webOutputWindow makeKeyAndOrderFront: self];		
	}

	//create argument list
	[arguments addObjectsFromArray: paramsArray];

	// add script as argument to interpreter
	if (secureScript)
		[arguments addObject: kTempScriptFile];
	else
		[arguments addObject: scriptPath];
	
	//set $1 as path of application bundle
	if (appPathAsFirstArg)
		[arguments addObject: [[NSBundle mainBundle] bundlePath]]; 
	
	if ([fileArgs count] > 0)//if there are any dropped files, we add them as arguments after $1
		[arguments addObjectsFromArray: fileArgs];

	//start new thread for executing script
	if (execStyle == kPrivilegedExecution) //Authentication mode
		[self executeScriptWithPrivileges];
	else //plain old regular
		[self executeScript];
}

#pragma mark -

//launch regular user task with NSTask
- (void)executeScript
{	
	isTaskStarted = YES;

	//initalize task
	task = [[NSTask alloc] init];
	
	// we monitor output if TextWindow or web output
	if (outputType == kTextOutput || outputType == kWebOutput)
	{
		outputPipe = [NSPipe pipe];
		[task setStandardOutput: outputPipe];
		[task setStandardError: outputPipe];
		readHandle = [outputPipe fileHandleForReading];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getTextData:) name:NSFileHandleReadCompletionNotification object:readHandle];
		[readHandle readInBackgroundAndNotify];
	}

	//apply settings for task
	[task setLaunchPath: interpreter];
	[task setArguments: arguments];
	
	//set it off
	[task launch];
	
	//set off timer that checks task status, i.e. when it's done 
	checkStatusTimer = [NSTimer scheduledTimerWithTimeInterval: 0.25 target: self selector:@selector(checkTaskStatus) userInfo: nil repeats: YES];
}

// check if task is running
- (void)checkTaskStatus
{
	if (![task isRunning])//if it's no longer running, we do clean up
	{
		[checkStatusTimer invalidate];
		[self taskFinished];
	}
}

#pragma mark -

//launch task with privileges using Authentication Manager
- (void)executeScriptWithPrivileges
{
	OSErr					err = noErr;
    short					i;
    char					*args[kMaxFileArguments+2];
	char					interpreterStr[kMaxPathLength];
	FILE					*outputFile;
	AuthorizationRef 		authorizationRef;

	isTaskStarted = YES;

	//interpreter
	[interpreter getCString: (char *)&interpreterStr maxLength: kMaxPathLength];

	//create arguments array
	for (i = 0; i < [arguments count]; i++)
	{
		args[i] = malloc(kMaxPathLength);
		[[arguments objectAtIndex:i] getCString: (char *)args[i] maxLength: kMaxPathLength];
		if (i == [arguments count]-1) // if last argument, we terminate array of args with a null
			args[i+1] = NULL;
	}
    
    // Use Apple's Authentication Manager APIs to get an Authorization Reference
	// This is not the Apple-recommended way of doing this -- but with setuid under attack etc, it'll just have to do
	// The question remains whether we should use something other than an empty environment
	// A lot of people have reported problems with scripts because of unset environmental variables
    err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    if (err != errAuthorizationSuccess)
	{
		free(args);
		NSLog(@"Authorization for script execution failed - Error %d", err);
        [[NSApplication sharedApplication] terminate: self];
	}
	
	//use Authorization Reference to execute script with privileges
    if (!(err = AuthorizationExecuteWithPrivileges(authorizationRef,(char *)&interpreterStr, kAuthorizationFlagDefaults, args, &outputFile)) != noErr)
	{
		//get NSFileHandle for the task output
		readHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileno(outputFile)];
		childPid = fcntl(fileno(outputFile), F_GETOWN, 0);//get pid
		
		// read the filehandle in the background and regularly print output into text window
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getTextData:) name:NSFileHandleReadCompletionNotification object:readHandle];
		[readHandle readInBackgroundAndNotify];
		[NSTimer scheduledTimerWithTimeInterval: 0.25 target: self selector:@selector(checkPrivilegedTaskStatus) userInfo: nil repeats: YES];

		// destroy the auth ref
		AuthorizationFree(authorizationRef, kAuthorizationFlagDefaults);
		
		if (args != NULL)
			free(args);
	}
	else
	{
		NSLog(@"Error %d occurred when attempting to run AuthorizationExecuteWithPrivileges. Terminating...", err);
		[[NSApplication sharedApplication] terminate: self];
	}
}

// check if privileged task is running
- (void)checkPrivilegedTaskStatus
{
    int ret, pid;
    pid = waitpid(childPid, &ret, WNOHANG);
    if (pid != 0)
        [self taskFinished];
}

#pragma mark -

// OK, called when task is finished.  Some cleaning up to do, controls need to be adjusted, etc.
- (void)taskFinished
{
		//if we're using the hidden encrypted script, we must remove the temporary clear-text one in /tmp/
		if (secureScript)
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath: kTempScriptFile])
				[[NSFileManager defaultManager] removeFileAtPath: kTempScriptFile handler: nil];
		}

		if (!remainRunning)
		{	// we quit if the app isn't explicity set to continue running
			[[NSApplication sharedApplication] terminate: self];
		}
		else if (outputType == kTextOutput)
		{
			//update controls for text output window
			[textOutputCancelButton setTitle: @"Quit"];
			[textOutputCancelButton setKeyEquivalent:@"\r"];
			[textOutputProgressIndicator stopAnimation: self];
		}
		else if (outputType == kProgressBarOutput)
		{
			//update controls for progress bar output
			[messageTextField setStringValue: @"Task completed"];
			[progressBar stopAnimation: self];
			[cancelButton setTitle: @"Quit"];
			[cancelButton setKeyEquivalent:@"\r"];
		}
		else if (outputType == kWebOutput)
		{
			//update controls for web output window
			[webOutputCancelButton setTitle: @"Quit"];
			[webOutputCancelButton setKeyEquivalent:@"\r"];
			[webOutputProgressIndicator stopAnimation: self];
		}
		
		isTaskDone = YES;
}

// read from the file handle and append it to the text window
- (void) getTextData: (NSNotification *)aNotification
{
	//get the data
	NSData *data = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
	
	//make sure there's actual data
	if ([data length]) 
	{
		//append the output to the text field
		NSString *outputStr = [[NSString alloc] initWithData: data encoding: textEncoding];
		[textOutputTextField setString: [[textOutputTextField string] stringByAppendingString: outputStr] ];
		[outputStr release];
		
		// if web output, we continually re-render to accomodate incoming data, else we scroll down
		if (outputType == kWebOutput)
			[[webOutputWebView mainFrame] loadHTMLString: [textOutputTextField string] baseURL: [NSURL fileURLWithPath: [[NSBundle mainBundle] resourcePath]] ];
		else
			[textOutputTextField scrollRangeToVisible:NSMakeRange([[textOutputTextField string] length], 0)];
		
		// we schedule the file handle to go and read more data in the background again.
		[[aNotification object] readInBackgroundAndNotify];
	}
}

#pragma mark -

// respond to AEOpenDoc -- so much more convenient than working with Apple Event Descriptors
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	if (!isTaskStarted)
	{
		[fileArgs addObject: filename];
		return TRUE;
	}
	else //once script task has started, we refuse all opened files
		return FALSE;
	// This is something worth working on -- the launching of the script again when new
	// files are dropped
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	//terminate task
	if (task != NULL)
	{
		if ([task isRunning])
			[task terminate];
		[task release];
	}
	
	// just one more time, make sure we don't leave the clear-text script in the /tmp/ directory
	if ([[NSFileManager defaultManager] fileExistsAtPath: kTempScriptFile])
		[[NSFileManager defaultManager] removeFileAtPath: kTempScriptFile handler: nil];
	
	return(YES);
}

#pragma mark -

//load configuration files from application bundle
- (void)loadSettings
{
	NSBundle		*appBundle = [NSBundle mainBundle];
	NSFileManager   *fmgr = [NSFileManager defaultManager];
	NSDictionary	*appSettingsPlist;
	
	//make sure all the config files are present -- if not, we quit
	if (	![fmgr fileExistsAtPath: [appBundle pathForResource:@"AppSettings.plist" ofType:nil]])
		[self fatalAlert: @"Corrupted app bundle" subText: @"Vital configuration file missing from the application bundle."];
	
	//get app name
	appName = [[appBundle executablePath] lastPathComponent];
	
	//get dictionary with app settings
	appSettingsPlist = [NSDictionary dictionaryWithContentsOfFile: [appBundle pathForResource:@"AppSettings.plist" ofType:nil]];
	if (appSettingsPlist == NULL)
		[self fatalAlert: @"Corrupted app settings" subText: @"The AppSettings.plist file for this application is corrupt."]; 
	
	//determine output type
	NSString *outputTypeStr = [appSettingsPlist objectForKey:@"OutputType"];
	if ([outputTypeStr isEqualToString: @"Progress Bar"])
		outputType = kProgressBarOutput;
	else if ([outputTypeStr isEqualToString: @"Text Window"])
	{
		outputType = kTextOutput;
		
		// if we have text output, we dearchive the color/font objects
		textFont		= [NSKeyedUnarchiver unarchiveObjectWithData: [appSettingsPlist objectForKey:@"TextFont"]];
		textForeground	= [NSKeyedUnarchiver unarchiveObjectWithData: [appSettingsPlist objectForKey:@"TextForeground"]];
		textBackground	= [NSKeyedUnarchiver unarchiveObjectWithData: [appSettingsPlist objectForKey:@"TextBackground"]];
		textEncoding	= (int)[[appSettingsPlist objectForKey:@"TextEncoding"] intValue];
		
		//make sure all this data is sane
		if (textFont == NULL)		{ textFont = [NSFont fontWithName: @"Monaco" size: 10.0]; }
		if (textForeground == NULL) { textForeground = [NSColor blackColor]; }
		if (textBackground == NULL) { textBackground = [NSColor blackColor]; }
		if (textEncoding < 1)		{ textEncoding = NSASCIIStringEncoding;  }
	}
	else if ([outputTypeStr isEqualToString: @"Web View"])
		outputType = kWebOutput;
	else
		outputType = kNoOutput;
		
	//arguments to interpreter
	paramsArray = [appSettingsPlist objectForKey:@"InterpreterParams"];
	
	//pass app path as first arg?
	appPathAsFirstArg = [[appSettingsPlist objectForKey:@"AppPathAsFirstArg"] boolValue];
	
	//determine execution style
	execStyle = [[appSettingsPlist objectForKey:@"RequiresAdminPrivileges"] boolValue];

	//remain running?
	remainRunning = [[appSettingsPlist objectForKey:@"RemainRunningAfterCompletion"] boolValue];
	
	//is script encrypted and checksummed?
	secureScript = [[appSettingsPlist objectForKey: @"Secure"] boolValue];
	
	//get interpreter
	interpreter = [appSettingsPlist objectForKey:@"ScriptInterpreter"];
	
	//if the script is not "Secure" then we need a script file, else we need data in appsettings.plist
	if ((!secureScript && ![fmgr fileExistsAtPath: [appBundle pathForResource:@"script" ofType:nil]]) || (secureScript && [appSettingsPlist objectForKey:@"TextSettings"] == NULL))
		[self fatalAlert: @"Corrupted app bundle" subText: @"Script missing from application bundle."];
	
	//get path to script
	scriptPath = [appBundle pathForResource:@"script" ofType:nil];
	hiddenScriptPath = [appBundle pathForResource:@".script" ofType:nil];
	
	//if it is secured, we decode and write it to /tmp/
	if (secureScript)
	{
		// make sure we can write to /tmp/ -- you never know, eh?
		BOOL existsAtPath = [fmgr fileExistsAtPath: kTempScriptFile];
		
		if (![fmgr isWritableFileAtPath: TMP_PATH] || ([fmgr fileExistsAtPath: kTempScriptFile] && ![fmgr isWritableFileAtPath: TMP_PATH]))
		{
			[self fatalAlert: @"Unable to write temporary files" subText: @"Could not write to the /tmp/ directory.  Make sure this directory exists and that you have write privileges."]; 
		}
		
		// remove file if it does exist and we have write privileges
		if (existsAtPath) {	[fmgr removeFileAtPath: kTempScriptFile handler: nil]; }
		
		// decode and write script
		NSString *b_str = [NSKeyedUnarchiver unarchiveObjectWithData: [appSettingsPlist objectForKey:@"TextSettings"]];
		NSData *sd = [NSData dataWithBase64EncodedString: b_str];
		NSString *ss = [[NSString alloc] initWithData: sd encoding: NSASCIIStringEncoding];
		[ss writeToFile: kTempScriptFile atomically: YES];
		[ss release];
	}
}

// Respond to Cancel by exiting application
- (IBAction)cancel:(id)sender
{
	[[NSApplication sharedApplication] terminate: self];
}

#pragma mark -

- (void)fatalAlert: (NSString *)message subText: (NSString *)subtext
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText: message];
	[alert setInformativeText: subtext];
	[alert setAlertStyle: NSCriticalAlertStyle];
	
	if ([alert runModal] == NSAlertFirstButtonReturn) 
	{
		[alert release];
		[[NSApplication sharedApplication] terminate: self];
	} 
}

@end
