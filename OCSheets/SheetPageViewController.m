//
//  SheetPageViewController.m
//  OpenClass
//
//  Created by Ben Pilcher on 4/1/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "SheetPageViewController.h"
#import "UIViewController+SheetNavigationController.h"
#import <QuartzCore/QuartzCore.h>

#define DELAYED_BLOCK(block,delay) dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)); \
dispatch_after(popTime, dispatch_get_main_queue(), ^(void){ \
block(); \
});

#define TITLE_KEY @"myTitle"
#define COVER_TAG 45

@implementation SheetPageViewController

- (id)init {
    self = [super initWithNibName:@"SheetPageView" bundle:nil];
    if (self){
        _pageTitle = @"content";
        self.pageLabel.text = _pageTitle;
    }
    
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ([self.sheetNavigationController sheetIsAtBottom:self]) {
        [[self.view viewWithTag:70] setHidden:YES];
    }
}

- (IBAction)pushSheetPage:(id)sender {
    SheetPageViewController *svc = [[SheetPageViewController alloc] init];
    [self.sheetNavigationController pushViewController:svc inFrontOf:self configuration:nil];
}

- (IBAction)popCurrent:(id)sender {
    [self.sheetNavigationController popViewControllerAnimated:YES];
}

- (IBAction)popToRoot:(id)sender {
    [self.sheetNavigationController popToRootViewControllerAnimated:YES];
}

#pragma mark Restoration

- (void)willBeStacked {
    [super willBeStacked];
    
}

- (void)willBeUnstacked {
    [super willBeUnstacked];
    
}

- (void)willBeDropped {
    NSLog(@"will drop %s",__PRETTY_FUNCTION__);
}

- (void)didGetDropped {
    NSLog(@"did drop %s",__PRETTY_FUNCTION__);
}

- (NSMutableDictionary *)encodeRestorableState {
    return [[NSMutableDictionary alloc] initWithObjectsAndKeys:self.pageTitle,TITLE_KEY,nil];
}

- (void)decodeRestorableState:(NSDictionary *)archiveDict {
    [super decodeRestorableState:archiveDict];
    
    if ([archiveDict objectForKey:TITLE_KEY]) {
        _pageTitle = [archiveDict objectForKey:TITLE_KEY];
        self.pageLabel.text = [NSString stringWithFormat:@"Restored %@",_pageTitle];
    }
}

- (void)viewDidUnload {
    [self setPageLabel:nil];
    [super viewDidUnload];
}

@end


