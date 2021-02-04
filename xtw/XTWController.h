//
//  XTWController.h
//  xtw
//
//  Created by Tom MacWright on 11/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//
//  Updated by Andy Grant on 2015-09-16.
//

#import <Foundation/Foundation.h>

@interface XTWController : NSObject
{
    NSStatusItem *statusItem;
    NSMenu *menu;
    NSTimer *automaticUpdateTimer;
    NSString *pendingPath;
    NSString *taskContents;
    NSString *activeContents;
    NSMenuItem *quitMI;
    NSMenuItem *aboutMI;
    BOOL darkModeOn;
    NSColor *textColor;
    NSInteger index;
}
@end
