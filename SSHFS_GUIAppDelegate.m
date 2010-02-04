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
#include <util.h>
#include <math.h>

#include "shared.h"

#import "SSHFS_GUIAppDelegate.h"

@implementation SSHFS_GUIAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#ifndef RELEASE
	NSLog(@"Debugging");
	NSLog(@"applicationDidFinishLaunching\n");
#endif
	
	// it was really stupid for me to have only one pipe
	// and try to estabilish bi-directional connection to
	// asker utility
	
	// of course, one would need at least two pipes, otherwise
	// you would write something to the pipe and then read all data
	// you wrote there immediately, while waiting for data... how stupid :)
	
	pipe(pipes_read);
	pipe(pipes_write);

#ifndef RELEASE
	NSLog(@"pipes ids: read=%d,%d ; write=%d,%d\n", pipes_read[0], pipes_read[1], pipes_write[0], pipes_write[1]);
#endif
	
	[NSThread detachNewThreadSelector:@selector(passwordTeller) toTarget:self withObject:nil];
}

- (void)passwordTeller
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	int length, tmp, action;
	char *str, buf[1025];
	
	NSMutableString *msg;
	
	// zero or less read bytes probably means that pipe is
	// broken (it also could mean that read was interrupted
	// by a signal, but we do not care...)
	
	while( read(pipes_read[0], &action, sizeof(action)) > 0 )
	{
		switch (action)
		{
			case ACTION_ASK_PASSWORD:
				
				//printf("ask password\n");
				
				str = (char*) [[password stringValue] UTF8String];
				break;
			case ACTION_AUTHENTICITY_CHECK:
				
				//printf("authenticity check\n");
				
				msg = [[NSMutableString alloc] initWithUTF8String:""];
				
				read(pipes_read[0], &length, sizeof(length));
				while( (tmp = read(pipes_read[0], buf, length >= sizeof(buf)-1 ? sizeof(buf)-1 : length)) > 0 )
				{
					buf[tmp] = 0;
					//printf("%s", buf); // ignore the input
					length -= tmp;
					
					[msg appendFormat:@"%s", buf];
					
					if(length <= 0) break;
				}
				
				// it is quite interesting, what will happen if I do so and pass NSMutableString, and which NSAutoreleasePool will accept the allocated memory...
				[self performSelectorOnMainThread:@selector(askMessage:) withObject:msg waitUntilDone:YES];
				
				//printf("\n");
				
				str = (char*) [msg UTF8String];
				break;
		}
		
		length = strlen(str); // this might be different from "length" property of a [password stringValue], though it should not in this case
		
		write(pipes_write[1], &length, sizeof(length));
		write(pipes_write[1], str, length);
		
		
		
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];
	} 
}

- (void)awakeFromNib
{
	//NSLog(@"awakeFromNib\n");
	
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	
	/*
	 NSDictionary *dict = [def dictionaryRepresentation];
	 
	 for(NSString *key in dict)
	 {
	 NSLog(@"%@ = %@\n", key, [dict objectForKey:key]);
	 }
	 */
	
	NSFileManager *mng = [NSFileManager defaultManager];
	BOOL wasLaunched = [def boolForKey:@"wasLaunched"];
	
	//NSLog(@"wasLaunched = %d\n", wasLaunched);
	
	if(!wasLaunched)
	{
		// need to determine, what is installed, and if it is installed
		// if nothing is installed, show "Nothing found" message and quit
		
		FILE *pp = popen("/usr/bin/lsvfs fusefs | /usr/bin/grep fusefs | /usr/bin/wc -l", "r");
		int fusefs_installed = 0;
		//BOOL scanfs_success =
		fscanf(pp, "%d", &fusefs_installed);
		pclose(pp);
		
		//NSLog(@"fusefs_installed = %d, scanf_success = %d\n", fusefs_installed, scanfs_success);
		
		if( fusefs_installed )
		{
			[def setObject:@"MacFUSE" forKey:@"implementation"];
		}else if( [mng fileExistsAtPath:@"/Applications/sshfs/bin/mount_sshfs"] )
		{
			[def setObject:@"pqrs.org" forKey:@"implementation"];
		}else
		{
			NSAlert *alert = [NSAlert alertWithMessageText:@"SSHFS is not available" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"No implementations found\n(either one at http://pqrs.org/macosx/sshfs/ or MacFUSE at http://code.google.com/p/macfuse/).\n\nClick OK to quit the application"];
			
			[alert runModal];
			
			[currentApp terminate:nil];
		}
		
		
		[def setBool:YES forKey:@"compression"];
		
		[def setBool:YES forKey:@"wasLaunched"];
		
	}	
	
	if(![def stringForKey:@"login"])
	{
		[login setStringValue:[NSString stringWithUTF8String:getenv("USER")]];
	}
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if(stopButton && [stopButton isEnabled])
	{
		printf("Caught applicationShouldTerminate notification. Cancelling last connection attempt.\n");
		
		//currentApp = sender;
		shouldTerminate = YES;
		
		[self stopButtonClicked:nil];
		
		return NSTerminateLater;
		
		// there could be some processes left, which also
		// will be killed after system("mount_ssfhs / sshfs-static-leopard ...") call fails
		// because of ourselves killing all child processes,
		// including mount_sshfs / sshfs-static-leopard launched by system()
	}
	
	return NSTerminateNow;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (IBAction)connectButtonClicked:(id)sender
{
	[self setConnectingState:YES];
	
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
			//printf("%s", buf);
			kill(atoi(buf), SIGTERM);
		}
		
		pclose(pp);
	}
	
	[self setConnectingState:NO];
}

- (IBAction)showAboutPanel:(id)sender
{
	const char *credits_html = "<div style='font-family: \"Lucida Grande\"; font-size: 10px;' align='center'>by<br><br><b>Yuriy Nasretdinov</b><br><br>Project is located at <br><a href='http://code.google.com/p/sshfs-gui/'>http://code.google.com/p/sshfs-gui/</a></div>";
	
	NSData *HTML = [[NSData alloc] initWithBytes:credits_html length:strlen(credits_html)];
	NSAttributedString *credits = [[NSAttributedString alloc] initWithHTML:HTML documentAttributes:NULL];
	
	NSString *version = @"1.0.2";
	NSString *applicationVersion = [NSString stringWithFormat:@"Version %@", version];
	
	NSArray *keys = [NSArray arrayWithObjects:@"Credits", @"Version", @"ApplicationVersion", nil];
	NSArray *objects = [NSArray arrayWithObjects:credits, @"", applicationVersion, nil];
	NSDictionary *options = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
	
	
	
	[currentApp orderFrontStandardAboutPanelWithOptions:options];
}

- (IBAction)showPreferencesPane:(id)sender
{
	[preferencesWindow setIsVisible:YES];
}


// reads the message from NSMutableString *msg and puts either @"yes" or @"no" back

- (void)askMessage:(id)msg
{
	NSMutableString *buf = msg;
	
	NSAlert *alert = [NSAlert alertWithMessageText:@"Authenticity check" defaultButton:@"Accept key" alternateButton:@"Dismiss key" otherButton:nil informativeTextWithFormat:buf];
	
	int response = [alert runModal];
	
	if(response == NSAlertDefaultReturn)
	{
		[buf setString:@"yes"];
	}else
	{
		// of course, mount_sshfs / sshfs-static-leopard would raise an error
		// when connecting, but we can skip this error and do not show the error
		// message to user, because it is not really an error, just a notice
		// that you refused SSH authentity check
		
		[buf setString:@"no"];
		shouldSkipConnectionError = YES;
	}
}

// the connection to the server itself is run on a separate thread to prevent application UI blocking
- (void)connectToServer:(id)data
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *srv  = [server stringValue];
	NSString *log  = [login stringValue];
	NSString *pass = [password stringValue];
	
	// cut the port from domain name (can be in form "example.com:port_number")
	
	NSRange rng = [srv rangeOfString:@":"];
	
	int port = 22;
	
	if(rng.location != NSNotFound )
	{
		port = [[srv substringFromIndex:rng.location+1] intValue];
		srv = [srv substringToIndex:rng.location];
	}
	
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	compression = [def boolForKey:@"compression"];
	
	if( [[def stringForKey:@"implementation"] isEqualToString:@"MacFUSE"] ) implementation = IMPLEMENTATION_MACFUSE;
	else                                                                    implementation = IMPLEMENTATION_PRQSORG;
	
	// prepare variables for execution of mount_sshfs
	
	NSString *mnt_loc = [NSString stringWithFormat:@"/Volumes/%@@%@", log, srv];
	NSString *cmd;
	
	switch(implementation)
	{
		case IMPLEMENTATION_PRQSORG:
			cmd = [NSString stringWithFormat:@"/Applications/sshfs/bin/mount_sshfs -p %d %@@%@ '%@' >%s 2>&1", port, log, srv, mnt_loc, ERR_TMPFILE];
			break;
		case IMPLEMENTATION_MACFUSE:
			chdir( [[[NSBundle mainBundle] bundlePath] UTF8String] );
			cmd = [NSString stringWithFormat:@"./Contents/Resources/sshfs-static-leopard %@@%@: '%@' -p %d -o workaround=nonodelay -ovolname='%@@%@' -oNumberOfPasswordPrompts=1 -o idmap=user %@ >%s 2>&1", log, srv, mnt_loc, port, log, srv, compression ? @" -C" : @"", ERR_TMPFILE];
			break;
	}
	
	//NSLog(@"%@", cmd);
	
	// check for errors in input parameters
	
	NSString *errorText = @"";
	
	BOOL canContinue = YES;
	
	int opcode = -1;
	
	if([srv rangeOfString:@" "].location != NSNotFound )
	{
		canContinue = NO;
		
		errorText = @"Domain name cannot contain spaces";
	}
	
	else if(![srv length])
	{
		canContinue = NO;
		
		errorText = @"Domain name cannot be empty";
	}
	
	else if( [log rangeOfString:@" "].location != NSNotFound )
	{
		canContinue = NO;
		
		errorText = @"Login cannot contain spaces";
	}
	
	else if(![log length])
	{
		canContinue = NO;
		
		errorText = @"Login cannot be empty";
	}else if([[NSFileManager defaultManager] fileExistsAtPath:mnt_loc])
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Already mounted" defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"It looks like you have already mounted this volume. If you continue, you might experience undesired side effects, especially if you have just switched the SSHFS implementation.\n\nDo you want to continue?"];
		
		int response = [alert runModal];
		
		if(response != NSAlertDefaultReturn) canContinue = NO;
		shouldSkipConnectionError = YES;
	}
	
	// if all parameters are correct, we can launch the utility itself
	
	if(canContinue)
	{
		mkdir([mnt_loc UTF8String], 0755);
		
		putenv("DISPLAY="); // need to set something DISPLAY variable in order SSH_ASKPASS to activate
		putenv((char*)[[NSString stringWithFormat:@"SSHFS_PIPES=%d,%d;%d,%d", pipes_write[0], pipes_write[1], pipes_read[0], pipes_read[1]] UTF8String]);
		putenv((char*)[[NSString stringWithFormat:@"SSH_ASKPASS=%@/Contents/Resources/asker", [[NSBundle mainBundle] bundlePath]] UTF8String]);
		
		//printf("Preparing to make a system call\n");
		
		opcode = system([cmd UTF8String]);
		
		errorText = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:ERR_TMPFILE] encoding:NSUTF8StringEncoding error:NULL];
		unlink(ERR_TMPFILE);
		
		//printf("opcode: %d\n", opcode);
		
		if([errorText hasPrefix:@"Permission denied"])
		{
			errorText = @"Permission denied. Please verify your login and password.";
		}
		
		if(opcode == 32512 && implementation == IMPLEMENTATION_PRQSORG) // file does not exist
		{
			errorText = @"You do not have mount_sshfs utility installed.\n\nPlease go to http://code.google.com/p/sshfs-gui/ and install it.";
		}
	}
	
	//printf("server: %s, login: %s, password: %s\n", [[server stringValue] UTF8String], [[login stringValue] UTF8String], [[password stringValue] UTF8String]);
	
	NSArray *keys = [NSArray arrayWithObjects:@"mountPoint", @"errorText", @"opcode", @"port", @"server", nil];
	NSArray *objects = [NSArray arrayWithObjects:mnt_loc, errorText, [NSString stringWithFormat:@"%d", opcode], [NSString stringWithFormat:@"%d", port], srv, nil];
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
	int port = [[dict valueForKey:@"port"] intValue];
	NSString *srv = [dict valueForKey:@"server"];
	
	if(opcode == 0)
	{
		system([[NSString stringWithFormat:@"open '%@'", mountPoint] UTF8String]);
	}else if(opcode != SIGTERM && !shouldSkipConnectionError) // if error code is SIGTERM, this means our app killed the process by ourselves (look at stopButtonClicked: code)
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Could not connect" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:errorText];
		
		[alert runModal];
		
		//printf("mount finished at %s with code %d and error text: %s\n", [mountPoint UTF8String], opcode, [errorText UTF8String]);
	}else if(opcode == SIGTERM)
	{
		// unfortunately, some processes are left after we terminate all our direct children processes, so we will kill all the rest hanging processes manually
		
		switch(implementation)
		{
			case IMPLEMENTATION_PRQSORG:
				system([[NSString stringWithFormat:@"/bin/kill `/bin/ps -ax | /usr/bin/grep '/Applications/sshfs/bin/mount_sshfs -p %d %@@%@' | /usr/bin/awk '{print $1;}'`", port, [login stringValue], srv] UTF8String] );
				break;
			case IMPLEMENTATION_MACFUSE:
				system([[NSString stringWithFormat:@"/bin/kill `/bin/ps -ax | /usr/bin/grep './Contents/Resources/sshfs-static-leopard %@@%@:' | /usr/bin/awk '{print $1;}'`", [login stringValue], srv] UTF8String] );
				system([[NSString stringWithFormat:@"/bin/kill `/bin/ps -ax | /usr/bin/grep 'ssh .* %@@%@ -s sftp' | /usr/bin/awk '{print $1;}'`", [login stringValue], srv] UTF8String] );
				break;
		}
		
		if(shouldTerminate) [currentApp replyToApplicationShouldTerminate:YES];
	}

	if(opcode) rmdir([mountPoint UTF8String]);
	
	[self setConnectingState:NO];
}

- (void)setConnectingState:(BOOL)connecting
{
	BOOL cs = connecting ? NO  : YES; // connect [controls] state (enabled or disabled)
	BOOL ss = connecting ? YES : NO;  // stop    [button]   state (enabled or disabled)
	
	if(connecting) [progress startAnimation:nil];
	else           [progress stopAnimation:nil];
	
	[server   setEditable:cs];
	[login    setEditable:cs];
	[password setEditable:cs];
	
	[connectButton setEnabled:cs];
	[stopButton    setEnabled:ss];
}

@end
