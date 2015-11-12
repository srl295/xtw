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
    NSDate *now = [NSDate date];
    NSInteger overdue = 0, pHigh = 0, pMedium = 0;
    
    NSMutableDictionary *menuAttributes = [NSMutableDictionary dictionary];
    
    [menuAttributes setObject:[NSFont fontWithName:@"Avenir Next"
                                              size:14]
                       forKey:NSFontAttributeName];
    
    NSTask * taskCommand = [[NSTask alloc] init];
    NSString *path = @"/usr/local/bin/task";
    [taskCommand setLaunchPath:path];
    NSArray *args = [NSArray arrayWithObjects:@"export", @"status:pending", nil];
    [taskCommand setArguments:args];
    NSPipe * out = [NSPipe pipe];
    [taskCommand setStandardOutput:out];
    
    [taskCommand launch];
    [taskCommand waitUntilExit];
    [taskCommand release];
    
    
    NSFileHandle * read = [out fileHandleForReading];
    NSData * dataRead = [read readDataToEndOfFile];
    taskContents = [[[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding] autorelease];
    
    NSError *jsonError;
    NSArray *tasksJSON;
    
    if ([taskContents isEqualToString:@""]) {
        tasksJSON = nil;
    } else {
        tasksJSON = [NSJSONSerialization JSONObjectWithData:dataRead options:NSJSONReadingMutableContainers error:&jsonError];
    }
    
    NSMutableArray *tasks = [NSMutableArray array];
    
    for (NSDictionary *task in tasksJSON) {
        [tasks addObject:task];
    }
    
    [tasks sortUsingComparator:^(id a, id b) {
        return [[b objectForKey:@"urgency"] compare:[a objectForKey:@"urgency"]];
    }];
    
    NSDate *dueDate;
    NSMenuItem *taskMI;
    NSDictionary *attributes;
    
   for (NSDictionary *task in tasks) {
        taskMI = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(task[@"description"],@"")
                                           action:NULL
                                    keyEquivalent:@""] autorelease];
        
        attributes = @{
                       NSFontAttributeName: [NSFont fontWithName:@"Lucida Grande" size:12.0],
                       NSForegroundColorAttributeName: textColor
                       };
        
        NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:[taskMI title] attributes:attributes];
        
        
        if (task[@"priority"]) {
            if ([task[@"priority"]  isEqual: @"H"]) {
                pHigh++;
                [attributedTitle addAttribute:NSForegroundColorAttributeName value:[NSColor magentaColor] range:NSMakeRange(0,[taskMI title].length)];
            } else if ([task[@"priority"]  isEqual: @"M"]) {
                pMedium++;
                [attributedTitle addAttribute:NSForegroundColorAttributeName value:[NSColor orangeColor] range:NSMakeRange(0,[taskMI title].length)];
            }
        }
        
        if (task[@"due"]) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyyMMdd'T'HHmmss'Z'"];
            dueDate = [dateFormatter dateFromString:task[@"due"]];
            switch ([dueDate compare:now]) {
                case NSOrderedSame: //dueDate == now
                case NSOrderedAscending: //dueDate < now
                    overdue++;
                    [attributedTitle addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,[taskMI title].length)];
                    break;
            }
        }
        
        if(task[@"start"]) {
            [attributedTitle addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleThick) range:NSMakeRange(0,[taskMI title].length)];
        }
        
        NSMenu *submenu = [[NSMenu alloc] init];
        
        // Start the task
        NSMenuItem *startMI = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Start",@"")
                                                          action:@selector(start:)
                                                   keyEquivalent:@""] autorelease];
        if (task[@"start"]) {
            [startMI setAction:NULL];
        } else {
            [startMI setTarget:self];
            [startMI setRepresentedObject:task];
        }
        [submenu addItem:startMI];
        
        // Finish the task
        NSMenuItem *doneMI = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Done",@"")
                                    action:@selector(done:)
                             keyEquivalent:@""] autorelease];
        [doneMI setTarget:self];
        [doneMI setRepresentedObject:task];
        [submenu addItem:doneMI];
        
        [taskMI setAttributedTitle:attributedTitle];
        [taskMI setSubmenu:submenu];
        [menu insertItem:taskMI atIndex:index++];
    }
    
    [menuAttributes setObject:textColor
                       forKey:NSForegroundColorAttributeName];
    statusTitle = [NSString stringWithFormat:@"%lu", (unsigned long)[tasksJSON count]];
    if (pMedium > 0) {
        [menuAttributes setObject:[NSColor orangeColor]
                           forKey:NSForegroundColorAttributeName];
        statusTitle = [NSString stringWithFormat:@"%lux%ld", (unsigned long)[tasksJSON count], (long)pMedium];
    }
    if (pHigh > 0) {
        [menuAttributes setObject:[NSColor magentaColor]
                           forKey:NSForegroundColorAttributeName];
        statusTitle = [NSString stringWithFormat:@"%lux%ld", (unsigned long)[tasksJSON count], (long)pHigh];
    }
    if (overdue > 0) {
        [menuAttributes setObject:[NSColor redColor]
                           forKey:NSForegroundColorAttributeName];
        statusTitle = [NSString stringWithFormat:@"%lux%ld", (unsigned long)[tasksJSON count], (long)overdue];
    }
    
    
    [statusItem setAttributedTitle:[[[NSAttributedString alloc]
                                     initWithString:statusTitle
                                     attributes:menuAttributes] autorelease]];
}

- (void)start: (id) taskMI
{
    id task = [taskMI representedObject];
    NSTask * taskCommand = [[NSTask alloc] init];
    NSString *path = @"/usr/local/bin/task";
    [taskCommand setLaunchPath:path];
    NSArray *args = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%@",task[@"id"]], @"start", nil];
    [taskCommand setArguments:args];
    
    [taskCommand launch];
    [taskCommand release];
    
}

- (void)done: (id) taskMI
{
    id task = [taskMI representedObject];
    NSTask * taskCommand = [[NSTask alloc] init];
    NSString *path = @"/usr/local/bin/task";
    [taskCommand setLaunchPath:path];
    NSArray *args = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%@",task[@"id"]], @"done", nil];
    [taskCommand setArguments:args];
    
    [taskCommand launch];
    [taskCommand release];
    
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
        menu = [[NSMenu alloc] init];
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
