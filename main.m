//
//  main.m
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 10.01.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
#ifndef RELEASE
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	unlink( [[@"~/Library/Preferences/org.YNProducts.SSHFS-GUI.plist" stringByExpandingTildeInPath] UTF8String] );
	
	[pool release];
#endif	

    return NSApplicationMain(argc,  (const char **) argv);
}
