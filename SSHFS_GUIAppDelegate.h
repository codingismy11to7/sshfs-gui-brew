//
//  SSHFS_GUIAppDelegate.h
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 10.01.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Foundation/Foundation.h"

#define IMPLEMENTATION_NONE    0
#define IMPLEMENTATION_MACFUSE 1
#define IMPLEMENTATION_PRQSORG 2

@interface SSHFS_GUIAppDelegate : NSObject
{
    NSWindow *window;
	IBOutlet NSWindow *preferencesWindow;
	
	IBOutlet NSTextField *server;
	IBOutlet NSTextField *login;
	IBOutlet NSSecureTextField *password;
	
	IBOutlet NSProgressIndicator *progress;
	
	IBOutlet NSButton *connectButton;
	IBOutlet NSButton *stopButton;
	
	IBOutlet NSApplication *currentApp;
	
	BOOL shouldTerminate;
	BOOL shouldSkipConnectionError;
	
	int implementation;
	BOOL compression;
	
	int pipes_read[2], pipes_write[2];
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)connectButtonClicked:(id)sender;
- (IBAction)stopButtonClicked:(id)sender;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication;

- (IBAction)showAboutPanel:(id)sender;
- (IBAction)showPreferencesPane:(id)sender;

- (void)setConnectingState:(BOOL)connecting;
- (void)askMessage:(id)msg;
- (void)passwordTeller;

- (void)awakeFromNib;

@end
