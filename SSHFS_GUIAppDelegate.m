//
//  SSHFS_GUIAppDelegate.m
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 10.01.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/types.h>

#import "SSHFS_GUIAppDelegate.h"

@implementation SSHFS_GUIAppDelegate

//@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
}

- (IBAction)connectButtonClicked:(id)sender
{
	[self setConnectingState:TRUE];
	
	[NSThread detachNewThreadSelector:@selector(connectToServer:) toTarget:self withObject:nil];
}

- (IBAction)stopButtonClicked:(id)sender
{
	// kill the spawned applications, so that the thread will terminate
	
	NSString *cmd = [NSString stringWithFormat:@"/bin/ps -ajx | /usr/bin/awk '{ if($3 == %d) print $2; }'", getpid()];
	
	//printf("%s\n", [cmd UTF8String]);
	
	FILE *pp = popen([cmd UTF8String], "r");
	
	if(pp)
	{
		char buf[1025];
		
		while(!feof(pp))
		{
			fread(buf, 1, sizeof(buf)-1, pp);
			printf("%s", buf);
			kill(atoi(buf), SIGTERM);
		}
		
		pclose(pp);
	}
	
	[self setConnectingState:FALSE];
}

#define TMPFILE_PREFIX "/tmp/sshfs-tmp"

#define PASS_TMPFILE TMPFILE_PREFIX ".pass"
#define ASKPASS_TMPFILE TMPFILE_PREFIX ".askpass"
#define ERR_TMPFILE TMPFILE_PREFIX ".err"

- (void)connectToServer:(id)data
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *srv = [server stringValue];
	NSString *log = [login stringValue];
	NSString *pass = [password stringValue];
	
	NSString *mnt_loc = [NSString stringWithFormat:@"/Volumes/SSHFS %@", srv];
	NSString *cmd = [NSString stringWithFormat:@"/Applications/sshfs/bin/mount_sshfs %@@%@ '%@' >%s 2>&1", log, srv, mnt_loc, ERR_TMPFILE];
	
	//printf("%s\n", [cmd UTF8String]);
	
	[pass writeToFile:[NSString stringWithUTF8String:PASS_TMPFILE] atomically:FALSE encoding:NSUTF8StringEncoding error:NULL];
	
	NSString *askpass_text = [NSString stringWithFormat:@"#!/bin/sh\ncat %s", PASS_TMPFILE];
	[askpass_text writeToFile:[NSString stringWithUTF8String:ASKPASS_TMPFILE] atomically:FALSE encoding:NSUTF8StringEncoding error:NULL];
	chmod(ASKPASS_TMPFILE, 0755);
	
	putenv("SSH_ASKPASS=" ASKPASS_TMPFILE);
	
	mkdir([mnt_loc UTF8String], 0755);
	int opcode = system([cmd UTF8String]);
	
	NSString *errorText = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:ERR_TMPFILE] encoding:NSUTF8StringEncoding error:NULL];
	
	unlink(PASS_TMPFILE);
	unlink(ASKPASS_TMPFILE);
	unlink(ERR_TMPFILE);
	
	//printf("server: %s, login: %s, password: %s\n", [[server stringValue] UTF8String], [[login stringValue] UTF8String], [[password stringValue] UTF8String]);
	
	NSArray *keys = [NSArray arrayWithObjects:@"mountPoint", @"errorText", @"opcode", @"server", nil];
	NSArray *objects = [NSArray arrayWithObjects:mnt_loc, errorText, [NSString stringWithFormat:@"%d", opcode], srv, nil];
	NSDictionary *dictionary = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
	
	[self performSelectorOnMainThread:@selector(finishConnectToServer:) withObject:dictionary waitUntilDone:NO];
	
	[pool release];
}

- (void)finishConnectToServer:(id)dictionary
{
	NSDictionary *dict = dictionary;
	
	NSString *mountPoint = [dict valueForKey:@"mountPoint"];
	NSString *errorText = [dict valueForKey:@"errorText"];
	int opcode = [[dict valueForKey:@"opcode"] intValue];
	NSString *srv = [dict valueForKey:@"server"];
	
	if(opcode == 0)
	{
		system([[NSString stringWithFormat:@"open '%@'", mountPoint] UTF8String]);
	}else if(opcode != SIGTERM) // if error code is SIGTERM, this means our app killed the process by ourselves (look at "stop" button code)
	{
		if([errorText hasPrefix:@"Host key verification failed."])
		{
			errorText = [NSString stringWithFormat:@"Host key verification failed.\n\nPlease first connect to a server through SSH, using command below and verify the RSA fingerprint for a host:\n\n$ ssh %@@%@", [login stringValue], srv];
		}
		
		NSAlert *alert = [NSAlert alertWithMessageText:@"Could not connect" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:errorText];
		
		[alert runModal];
		
		//printf("mount finished at %s with code %d and error text: %s\n", [mountPoint UTF8String], opcode, [errorText UTF8String]);
	}else
	{
		// unfortunately, some processes are left after we terminate all our direct children processes, so we will kill all the rest the hanging processes manually
		
		system([[NSString stringWithFormat:@"/bin/kill `/bin/ps -ax | grep '/Applications/sshfs/bin/mount_sshfs %@@%@' | awk '{print $1;}'`", [login stringValue], srv] UTF8String] );
	}


	
	[self setConnectingState:FALSE];
}

- (void)setConnectingState:(BOOL)connecting
{
	BOOL cs = connecting ? FALSE : TRUE;  // connect [controls] state (enabled or disabled)
	BOOL ss = connecting ? TRUE  : FALSE; // stop    [button]   state (enabled or disabled)
	
	if(connecting) [progress startAnimation:nil];
	else           [progress stopAnimation:nil];
	
	[server   setEditable:cs];
	[login    setEditable:cs];
	[password setEditable:cs];
	
	[connectButton setEnabled:cs];
	[stopButton    setEnabled:ss];
}

@end
