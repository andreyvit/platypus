/*
    platypus - command line equivalent to the Mac OS X Platypus application
			 - create application wrappers around scripts
			 
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

/*  CHANGE LOG

	4.0	- Rewritten for Platypus 4.0 release
	1.3	- File bundling, suffixes/types, for 3.4 release
	1.2 - For 3.3 release
    1.0 - * First release of the Platypus command line tool
*/

/*
	SUPPORT FILES FOR PROGRAM (defined in CommonDefs.h)

	/usr/local/share/platypus/exec						Executable bundled with app
	/usr/local/share/platypus/MainMenu.nib				Nib file for app
	/usr/local/share/platypus/PlatypusDefault.icns		Default icons for Platypus apps

*/

/*
	COMMAND LINE OPTIONS
	
	// *required*
	-a	Application Name
	-o	Output Type
	-c	Script File
	-P  Profile
	
	// *advanced options*
	
	-i	Icon file
	-p	Interpreter
	-V	Version
	-s	Signature (4 character string)
	-I	Identifier
	-f  Bundled file argument

	-A	Requires Administrator privileges
	-S	Secure bundled script
	-D	Is Droppable
	-B	Runs in background
	-R  remainRunningAfterCompletion
	
	-X  Suffixes supported
	-T  File Type Codes supported
	
	-b  Verbose output
	-v	Print version string
	-h	Print help
*/

///////////// IMPORTS/INCLUDES ////////////////

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>

#import "CommonDefs.h"
#import "PlatypusAppSpec.h"

#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>

///////////// DEFINITIONS ////////////////

#define		OPT_STRING			"P:c:f:a:t:o:i:u:p:V:s:I:ASDFBRvhX:T:G:N:b" 

//#define		DEBUG				1

///////////// PROTOTYPES ////////////////

static void PrintVersion (void);
static void PrintUsage (void);
static void PrintHelp (void);
static void NSPrintErr (NSString *str);
static void NSPrint (NSString *str);


int main (int argc, const char * argv[]) 
{
    NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];//set up autorelease pool
	NSApplication		*app				= [NSApplication sharedApplication];//establish connection to Window Server
	NSFileManager		*fm					= [NSFileManager defaultManager];
	
	// we start with an application spec set to all the default settings
	// command line params can fill in the settings user wants
	PlatypusAppSpec		*appSpec			= [[PlatypusAppSpec alloc] initWithDefaults];

	int					rc, optch;
    static char			optstring[] = OPT_STRING;

	NSPrint(@"Starting argument parsing");

    while ( (optch = getopt(argc, (char * const *)argv, optstring)) != -1)
    {
        switch(optch)
        {
			// Profile
			case 'P':
			{
				NSString *profilePath = [NSString stringWithCString: optarg];
				if (![fm fileExistsAtPath: profilePath])
				{
					NSPrintErr(@"Profile path invalid\n");
					exit(1);
				}
				[appSpec release];
				appSpec = [[PlatypusAppSpec alloc] initWithProfile: profilePath];
			}
			break;
		
			// App Name
			case 'a':				
				[appSpec setProperty: [NSString stringWithCString: optarg] forKey: @"Name"];
				break;
			
			// A bundled file
			case 'f':
			{
				NSString *filePath = [[NSString stringWithCString: optarg] stringByExpandingTildeInPath];
				if (![fm fileExistsAtPath: filePath])
				{
					NSPrintErr([NSString stringWithFormat: @"No file exists at path '%@'\n", filePath]);
					exit(1);
				}
				[[appSpec propertyForKey: @"BundledFiles"] addObject: filePath];
			}
			break;
			
			// Script path
			case 'c':
			{
				NSString *scriptPath = [[NSString stringWithCString: optarg] stringByExpandingTildeInPath];
				if (![fm fileExistsAtPath: scriptPath])
				{
					NSPrintErr([NSString stringWithFormat: @"No script file exists at path '%@'\n", scriptPath]);
					exit(1);
				}
				[appSpec setProperty: scriptPath forKey: @"ScriptPath"];
			}
			break;
		
			// Output Type
            case 'o':
			{
				NSString *outputType = [NSString stringWithCString: optarg];
				if ([outputType caseInsensitiveCompare: @"None"] != NSOrderedSame &&
					[outputType caseInsensitiveCompare: @"Progress Bar"] != NSOrderedSame &&
					[outputType caseInsensitiveCompare: @"Text Window"] != NSOrderedSame &&
					[outputType caseInsensitiveCompare: @"Web"] != NSOrderedSame)
				{
						NSPrintErr(@"Invalid output type.\n");
						exit(1);
				}
				[appSpec setProperty: [NSString stringWithCString: optarg] forKey: @"Output"];
			}
			break;
			
			// Author
			case 'u':
				[appSpec setProperty: [NSString stringWithCString: optarg] forKey: @"Author"];
				break;
			
			// Icon
			case 'i':
			{
				NSString *iconPath = [[NSString stringWithCString: optarg] stringByExpandingTildeInPath];
				if (![fm fileExistsAtPath: iconPath])
				{
					NSPrintErr([NSString stringWithFormat: @"No icon file exists at path '%@'\n", iconPath]);
					exit(1);
				}
				
				 // specifying an icns file, that means we just use the file
				if ([iconPath hasSuffix: @"icns"])
				{
					[appSpec setProperty: [NSNumber numberWithBool: YES] forKey: @"HasCustomIcon"];
					[appSpec setProperty: [NSString stringWithCString: optarg] forKey: @"CustomIconPath"];
				}
				else
				{
					// read image from file
					NSImage *iconImage = [[NSImage alloc] initWithContentsOfFile: iconPath];
					if (iconImage == NULL)
					{
						NSPrintErr([NSString stringWithFormat: @"Unable to get icon from file '%@'\n", iconPath]);
						exit(1);
					}
					[appSpec setProperty: [NSNumber numberWithBool: NO] forKey: @"HasCustomIcon"];
					[appSpec setProperty: [NSKeyedArchiver archivedDataWithRootObject: iconImage] forKey: @"Icon"];
					[iconImage release];
				}
			}
			break;
			
			// Interpreter
			case 'p':
				[appSpec setProperty: [NSString stringWithCString: optarg] forKey: @"Interpreter"];
				break;
			
			// Version
			case 'V':
				[appSpec setProperty: [NSString stringWithCString: optarg] forKey: @"Version"];
				break;
			
			// Signature
			case 's':
			{
				NSString *signatureStr = [NSString stringWithCString: optarg];
				if ([signatureStr length] != 4) // it must be a 4-character string
				{
					NSPrintErr(@"Signature invalid.\nA signature must consist of exactly 4 ASCII characters.\n");
					exit(1);
				}
				[appSpec setProperty: signatureStr forKey: @"Signature"];
			}
			break;
			
			// The checkbox options
			case 'I':
				[appSpec setProperty: [NSString stringWithCString: optarg] forKey: @"Identifier"];
				break;
            case 'A':
				[appSpec setProperty: [NSNumber numberWithBool: YES] forKey: @"Authentication"];
				break;
			case 'S':
				[appSpec setProperty: [NSNumber numberWithBool: YES] forKey: @"Secure"];
				break;
			case 'D':
				[appSpec setProperty: [NSNumber numberWithBool: YES] forKey: @"Droppable"];
				break;
			case 'F':
				[appSpec setProperty: [NSNumber numberWithBool: YES] forKey: @"AppPathAsFirstArg"];
				break;
			case 'B':
				[appSpec setProperty: [NSNumber numberWithBool: YES] forKey: @"ShowInDock"];				
				break;
			case 'R':
				[appSpec setProperty: [NSNumber numberWithBool: YES] forKey: @"RemainRunning"];
				break;
				
			// Suffixes
			case 'X':
			{
				NSString *suffixesStr = [NSString stringWithCString: optarg];
				NSArray *suffixes = [suffixesStr componentsSeparatedByString: @"|"];
				[appSpec setProperty: suffixes forKey:  @"Suffixes"];
			}
			break;
			
			// File Types
			case 'T':
			{
				NSString *filetypesStr = [NSString stringWithCString: optarg];
				NSArray *fileTypes = [filetypesStr componentsSeparatedByString: @"|"];
				[appSpec setProperty: fileTypes forKey: @"FileTypes"];
			}
			break;
			
			// Parameters for interpreter
			case 'G':
			{
				NSString *parametersString = [NSString stringWithCString: optarg];
				NSArray *parametersArray = [parametersString componentsSeparatedByString: @"|"];
				[appSpec setProperty: parametersArray forKey: @"Parameters"];
			}
			break;
			
			// Environment
			case 'N':
			{
				NSMutableDictionary *envDict = [[[NSMutableDictionary alloc] initWithCapacity: 255] autorelease];
				int i;
				NSString *environmentVarsString = [NSString stringWithCString: optarg];
				NSArray *envVarDefs = [environmentVarsString componentsSeparatedByString: @"|"];
				for (i = 0; i < [envVarDefs count]; i++)
				{
					NSArray *nameValPair = [[envVarDefs objectAtIndex: i] componentsSeparatedByString: @"="];
					[envDict setObject: [nameValPair objectAtIndex: 1] forKey: [nameValPair objectAtIndex: 0]];
				}
				[appSpec setProperty: envDict forKey: @"Environment"];
			}
			break;
			
			case 'v':
                PrintVersion();
                exit(0);
                break;
            case 'h':
                PrintHelp();
                return 0;
                break;
            default:
                rc = 1;
                PrintUsage();
                return 0;
        }
    }
	
	if (argc - optind < 1) //  application destination must follow
    {
        NSPrintErr(@"Too few arguments.\n");
        PrintUsage();
        exit(1);
    }
			
	//get application destination parameter
	NSString *appPath = [[NSString stringWithCString: argv[optind]] stringByExpandingTildeInPath];
	if (appPath == NULL)
	{
		NSPrintErr(@"Missing parameter:  Application Destination Path\n");
		PrintUsage();
		exit(1);
	}
	
	[appSpec setProperty: appPath forKey: @"Destination"];
		
	// set nib and exec paths
	[appSpec setProperty: CMDLINE_NIB_PATH forKey: @"NibPath"];
	[appSpec setProperty: CMDLINE_EXEC_PATH forKey: @"ExecutablePath"];
	
	// create the app from spec
	if (![appSpec verify] || ![appSpec create])
	{
		NSPrintErr([appSpec getError]);
		return 1;
	}
	
	[appSpec release];
    [pool release];
	
	return 0;
}

#pragma mark -

////////////////////////////////////////
// Print version and author to stdout
///////////////////////////////////////

static void PrintVersion (void)
{
    NSPrint([NSString stringWithFormat: @"%@ version %@ by %@\n", CMDLINE_PROGNAME, PROGRAM_VERSION, PROGRAM_AUTHOR]);
}

////////////////////////////////////////
// Print usage string to stdout
///////////////////////////////////////

static void PrintUsage (void)
{
    NSPrint([NSString stringWithFormat: @"usage: %@ [-vh] [-P profile] [-a name] [-o outputType] [-p interpreter] [-FASDBRiuVsIXTGN] script destination\n", CMDLINE_PROGNAME]);
}

////////////////////////////////////////
// Print help string to stdout
///////////////////////////////////////

static void PrintHelp (void)
{
	puts("platypus - command line application wrapper generator for scripts");
	PrintVersion();
    PrintUsage();
	puts("");
	puts("Options:");
	puts("");
	puts("-P [profile]		Load settings from profile file");
	puts("-a [name]		Set name of application bundle");
	puts("-o [type]		Set output type.  See man page for accepted types");
	puts("-c [script]		Set script for application");
	puts("-p [interpreter]	Set interpreter for script");
	puts("");
	puts("-i [icon]		Set icon for application");
	puts("-u [author]		Set name of application author");
	puts("-V [version]		Set version of application");
	puts("-s [signature]		Set 4-character bundle signature");
	puts("-I [identifier]		Set bundle identifier (i.e. org.yourname.appname)");
	puts("");
	puts("-F			Script receives path to app as first argument");
	puts("-A			App runs with Administrator privileges");
	puts("-S			Secure bundled script");
	puts("-D			App accepts dropped files as argument to script");
	puts("-B			App runs in background (LSUI Element)");
	puts("-R			App remains running after executing script");
	puts("");
	puts("-X [suffixes]		Set suffixes handled by application");
	puts("-T [filetypes]		Set file type codes handled by application");
	puts("-G [arguments]		Set arguments for script interpreter");
	puts("-N [environment]	Set environmental variables for script");
	puts("");
	puts("-h			Prints help");
	puts("-v			Prints program name, version and author");
	puts("");
}

#pragma mark -

/**************************************************
void NSPrint (NSString *str)
Utility function -- dumps NSString to stdout
************************************************/
static void NSPrint (NSString *str)
{
     [str writeToFile: @"/dev/stdout" atomically: NO];
}

static void NSPrintErr (NSString *str)
{
	[str writeToFile: @"/dev/stderr" atomically: NO];
}
