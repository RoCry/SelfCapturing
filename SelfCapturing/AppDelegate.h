//
//  AppDelegate.h
//  SelfCapturing
//
//  Created by Summer on 13-5-31.
//  Copyright (c) 2013年 rocry. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    NSStatusItem * statusItem;
}
@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSMenu *statusMenu;

@end
