//
//  AppController.h
//  SelfCapturing
//
//  Created by Summer on 13-6-3.
//  Copyright (c) 2013年 rocry. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AppController : NSObject
{
    NSStatusItem * statusItem;
}

@property (weak) IBOutlet NSMenuItem *toggleRecordMenuItem;

- (IBAction)saveAndExit:(id)sender;

@end
