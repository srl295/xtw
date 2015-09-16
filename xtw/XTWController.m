//
//  XTWController.m
//  xtw
//
//  Created by Tom MacWright on 11/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//
//  Updated by Andy Grant on 2015-09-16.
//

#import "XTWController.h"

@implementation XTWController
- (void)updateCount
{
    for (int i = ([menu numberOfItems] - 4.0); i >= 0; i--) {
        [menu removeItemAtIndex:i];
        index--;
    }
    
    NSString *statusTitle = nil;
    NSInteger timestamp = (long)[[NSDate date] timeIntervalSince1970];
    NSInteger overdue = 0;
    
    NSMutableDictionary *menuAttributes = [NSMutableDictionary dictionary];
    
    [menuAttributes setObject:[NSFont fontWithName:@"Avenir Next"
                                              size:14]
                       forKey:NSFontAttributeName];
    
    NSTask * task = [[NSTask alloc] init];
    NSString *path = @"/usr/local/bin/task";
    [task setLaunchPath:path];
    NSArray *args = [NSArray arrayWithObjects:@"export", @"status:pending", nil];
    [task setArguments:args];
    NSPipe * out = [NSPipe pipe];
    [task setStandardOutput:out];
    
    [task launch];
    [task waitUntilExit];
    [task release];
    
    
    NSFileHandle * read = [out fileHandleForReading];
    NSData * dataRead = [read readDataToEndOfFile];
    taskContents = [[[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding] autorelease];
    
    NSArray *tasks = [[taskContents stringByTrimmingCharactersInSet:
                       [NSCharacterSet newlineCharacterSet]]
                      componentsSeparatedByCharactersInSet:
                      [NSCharacterSet newlineCharacterSet]];
    
    NSEnumerator *e = [tasks objectEnumerator];
    id object;
    NSInteger dueDate;
    NSError *jsonError;
    NSData *tData;
    NSDictionary *taskData;
    NSMenuItem *desc;
    NSDictionary *attributes;
    while (object = [e nextObject]) {
        tData = [object dataUsingEncoding:NSUTF8StringEncoding];
        taskData = [NSJSONSerialization JSONObjectWithData:tData
                                                   options:NSJSONReadingMutableContainers
                                                     error:&jsonError];
        desc = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(taskData[@"description"],@"")
                                           action:NULL
                                    keyEquivalent:@""] autorelease];
        attributes = @{
                       NSFontAttributeName: [NSFont fontWithName:@"Lucida Grande" size:12.0],
                       NSForegroundColorAttributeName: textColor
                       };
        
        if (taskData[@"due"]) {
            dueDate = [taskData[@"due"] integerValue];
            if (dueDate < timestamp) {
                overdue++;
                attributes = @{
                               NSFontAttributeName: [NSFont fontWithName:@"Lucida Grande" size:12.0],
                               NSForegroundColorAttributeName: [NSColor redColor]
                               };
            }
        }
        
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:[desc title] attributes:attributes];
        [desc setAttributedTitle:attributedTitle];
        [menu insertItem:desc atIndex:index++];
    }
    if (overdue > 0) {
        [menuAttributes setObject:[NSColor redColor]
                           forKey:NSForegroundColorAttributeName];
        statusTitle = [NSString stringWithFormat:@"%lux%ld", (unsigned long)[tasks count], (long)overdue];
    } else {
        [menuAttributes setObject:textColor
                           forKey:NSForegroundColorAttributeName];
        statusTitle = [NSString stringWithFormat:@"%lu", (unsigned long)[tasks count]];
    }
    
    e = [tasks objectEnumerator];
    
    
    [statusItem setAttributedTitle:[[[NSAttributedString alloc]
                                     initWithString:statusTitle
                                     attributes:menuAttributes] autorelease]];
}
- (id)init
{
    self = [super init];
    if(self)
    {
        // Determine current menubar dark/light-mode
        NSDictionary *dict = [[NSUserDefaults standardUserDefaults] persistentDomainForName:NSGlobalDomain];
        id style = [dict objectForKey:@"AppleInterfaceStyle"];
        darkModeOn = (style && [style isKindOfClass:[NSString class]] && NSOrderedSame == [style caseInsensitiveCompare:@"dark"]);
        [self setTextColor];
        
        // Register observer to handle menubar dark/light-mode change
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
        
        taskContents = [[NSString alloc] retain];
        pendingPath = [[@"~/.task/pending.data" stringByExpandingTildeInPath] retain];
        menu                     = [[NSMenu alloc] init];
        index = 0;
        
        // Set up my status item
        statusItem               = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
        [statusItem setMenu:menu];
        [statusItem retain];
        [statusItem setToolTip:@"taskwarrior"];
        [statusItem setHighlightMode:YES];
        
        // Set up the menu
        quitMI = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit",@"")
                                             action:@selector(terminate:)
                                      keyEquivalent:@""] autorelease];
        
        aboutMI = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"About xtw",@"")
                                              action:@selector(orderFrontStandardAboutPanel:)
                                       keyEquivalent:@""] autorelease];
        NSDictionary *attributes = @{
                                     NSFontAttributeName: [NSFont fontWithName:@"Lucida Grande" size:12.0],
                                     NSForegroundColorAttributeName: textColor
                                     };
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:[quitMI title] attributes:attributes];
        [quitMI setAttributedTitle:attributedTitle];
        [quitMI setTarget:NSApp];
        attributedTitle = [[NSAttributedString alloc] initWithString:[aboutMI title] attributes:attributes];
        [aboutMI setAttributedTitle:attributedTitle];
        [aboutMI setTarget:NSApp];
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItem:aboutMI];
        [menu addItem:quitMI];
        
        // Keep the thing updated
        automaticUpdateTimer     = [[NSTimer scheduledTimerWithTimeInterval:10
                                                                     target:self
                                                                   selector:@selector(downloadNewDataTimerFired)
                                                                   userInfo:nil
                                                                    repeats:YES] retain];
        
        // Run the initial update
        [self updateCount];
    }
    return self;
}

-(void)setTextColor
{
    textColor = (darkModeOn ? [NSColor whiteColor] : [NSColor blackColor]);
}

-(void)darkModeChanged:(NSNotification *)notif
{
    darkModeOn = !darkModeOn;
    [self setTextColor];
    [self updateCount];
}

- (void)downloadNewDataTimerFired
{
    [self updateCount];
}
@end