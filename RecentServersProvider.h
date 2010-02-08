//
//  RecentServersProvider.h
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 07.02.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface RecentServersProvider : NSObject {
	
	NSUserDefaults *def;
	
	NSArray *entries;
}

- (id)init;
- (void)release;

- (NSString *)getEntryAtIndex:(NSUInteger)rowIndex;
- (void)addEntry:(NSString *)server;
- (void)deleteEntryAtIndex:(NSUInteger)rowIndex;

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

@end
