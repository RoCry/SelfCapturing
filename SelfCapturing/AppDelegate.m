//
//  AppDelegate.m
//  SelfCapturing
//
//  Created by Summer on 13-5-31.
//  Copyright (c) 2013年 rocry. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
}

- (void)awakeFromNib{
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusItem setMenu:self.statusMenu];
    [statusItem setImage:[NSImage imageNamed:@"Icon"]];
    [statusItem setHighlightMode:YES];
}

@end
