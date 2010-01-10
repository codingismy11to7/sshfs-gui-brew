//
//  SSHFS_GUIAppDelegate.h
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 10.01.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5)
@interface SSHFS_GUIAppDelegate : NSObject
#else
@interface SSHFS_GUIAppDelegate : NSObject <NSApplicationDelegate>
#endif
{
    //NSWindow *window;
	
	IBOutlet NSTextField *server;
	IBOutlet NSTextField *login;
	IBOutlet NSSecureTextField *password;
	
	IBOutlet NSProgressIndicator *progress;
	
	IBOutlet NSButton *connectButton;
	IBOutlet NSButton *stopButton;
}

//@property (assign) IBOutlet NSWindow *window;

- (IBAction)connectButtonClicked:(id)sender;
- (IBAction)stopButtonClicked:(id)sender;

- (void)setConnectingState:(BOOL)connecting;

@end
