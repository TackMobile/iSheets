//
//  BasicSheetViewController.m
//  OpenClass
//
//  Created by Ben Pilcher on 4/17/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "BasicSheetViewController.h"

@implementation BasicSheetViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        //_peeking = NO;
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (CGFloat)widthForSheetPosition:(NSUInteger)position navItem:(SheetNavigationItem *)navItem {
    return [self desiredWidthForSheetPosition:position navItem:navItem];
}

#pragma mark Sheet Stack Page

/*
 Implement this method to specify a different width for the sheet's
 content at different stacking positions
 */
- (CGFloat)desiredWidthForSheetPosition:(SheetStackPosition)position navItem:(SheetNavigationItem *)navItem {
    SheetLayoutType type = navItem.layoutType;
    if (type == kSheetLayoutFullScreen) {
        return [[SheetLayoutModel sharedInstance] availableWidthForOffset:navItem.initialViewPosition.x];
    }
    
    return kStandardSheetWidth;
}

- (BOOL)isProtectedSheet {
    return NO;
}

/*
 Call this method to perform additional UI work
 when a sheet is about to be stacked on top of for the first time
 */
- (void)willBeStacked {
    // The default implementation of this method isn't not empty.
}

- (void)didGetStacked {
    // The default implementation of this method isn't not empty.
}

- (void)willBeUnstacked {
    // The default implementation of this method isn't not empty.
}

- (void)beingUnstacked:(CGFloat)percentUnstacked {
    // The default implementation of this method isn't not empty.
}

- (void)didGetUnstacked {
    // The default implementation of this method isn't not empty.
}

- (void)willBeDropped {
    // The default implementation of this method isn't not empty.
}

- (void)didGetDropped {
    // The default implementation of this method isn't not empty.
}

- (NSMutableDictionary *)encodeRestorableState {
    return nil;
}

- (void)decodeRestorableState:(NSDictionary *)archiveDict {
 
}

- (UIView *)leftButtonViewForStackedPosition {
    UIImageView *circleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sheetsCircleStacked"]];
    UIView *view = [[UIView alloc] initWithFrame:circleImage.bounds];
    [view addSubview:circleImage];
    return view;
}

- (float)availableContentWidth {
    return [self desiredWidthForSheetPosition:kSheetStackTop navItem:self.sheetNavigationItem];
}

#pragma mark Sheet stack peeking

- (void)peekSheet:(UIViewController *)vc animated:(BOOL)animated {
    [self.sheetNavigationController peekViewController:vc];
}

- (BOOL)shouldPeekDefaultSheet {
    return YES;
}

- (void)sheetNavigationControllerWillMoveController:(UIViewController *)controller {
    // The default implementation of this method isn't not empty.
}

- (void)sheetNavigationControllerDidMoveController:(UIViewController *)controller {
    // The default implementation of this method isn't not empty.
}

- (void)pushNewSheet:(UIViewController *)vc {
    [self.sheetNavigationController pushViewController:vc inFrontOf:self configuration:nil];
}

@end
