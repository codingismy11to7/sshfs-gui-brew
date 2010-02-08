//
//  RecentServersProvider.m
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 07.02.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#import "RecentServersProvider.h"


@implementation RecentServersProvider

- (id)init
{
	[super init];
	
	def = [[NSUserDefaults standardUserDefaults] retain];
	
	if(!(entries = [def objectForKey:@"recentServers"]))
	{
		entries = [NSArray array];
		
		[def setObject:entries forKey:@"recentServers"];
	}
	
	return self;
}

- (void)addEntry:(NSString *)server
{
	NSMutableArray *a = [NSMutableArray arrayWithArray:entries];
	
	[a removeObject:server];
	[a insertObject:server atIndex:0];
	
	[def setObject:a forKey:@"recentServers"];
	
	entries = [def objectForKey:@"recentServers"];
}

- (NSString *)getEntryAtIndex:(NSUInteger)rowIndex
{
	return [entries objectAtIndex:rowIndex];
}

- (void)deleteEntryAtIndex:(NSUInteger)rowIndex
{
	NSMutableArray *a = [NSMutableArray arrayWithArray:entries];
	
	[a removeObjectAtIndex:rowIndex];
	
	[def setObject:a forKey:@"recentServers"];
	
	entries = [def objectForKey:@"recentServers"];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [entries count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	//NSLog(@"rowIndex — %d\n", rowIndex);
	// numbering starts with 0
	
	return [self getEntryAtIndex:rowIndex];
}

- (void)release
{
	[def release];
	
	[super release];
}

@end
