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

#import "CommonDefs.h"
#import "IconFamily.h"
#import "NSDataAdditions.h"

@interface PlatypusAppSpec : NSObject 
{
	NSMutableDictionary		*properties;
	NSString				*error;
}
-(id)initWithDefaults;
-(id)initWithDictionary: (NSDictionary *)dict;
-(id)initWithProfile: (NSString *)filePath;
-(void)setDefaults;
-(BOOL)create;
-(BOOL)verify;
-(void)dump;
-(void)setProperty: (id)property forKey: (NSString *)theKey;
-(id)propertyForKey: (NSString *)theKey;
-(NSDictionary *)properties;
-(void)addProperties: (NSDictionary *)dict;
-(NSString *)getError;
- (void)writeIcon: (NSImage *)img toPath: (NSString *)path;
@end
