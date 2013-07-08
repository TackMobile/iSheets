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
    SheetLayoutType type = navItem ? navItem.layoutType : kStandardSheetWidth;
    if (type == kSheetLayoutFullScreen || type == kSheetLayoutFullAvailable) {
        return [[SheetLayoutModel sharedInstance] availableWidthForOffset:navItem.initialViewPosition.x];
    } 
    
    return kStandardSheetWidth;
}

- (BOOL)isDraggableSheet {
    return YES;
}

- (BOOL)isProtectedSheet {
    return NO;
}

- (void)setPeekedHidden:(BOOL)hidden {
    self.sheetNavigationItem.showingPeeked = !hidden;
}

/*
 Call this method to perform additional UI work
 when a sheet is about to be stacked on top of for the first time
 */
- (void)willBeStacked {
    // The default implementation of this method is .... empty.
}

- (void)didGetStacked {
    // The default implementation of this method is .... empty.
}

- (void)willBeUnstacked {
    // The default implementation of this method is .... empty.
}

- (void)beingUnstacked:(CGFloat)percentUnstacked {
    // The default implementation of this method is .... empty.
}

- (void)didGetUnstacked {
    // The default implementation of this method is .... empty.
}

- (void)willBeDropped {
    // The default implementation of this method is .... empty.
}

- (void)didGetDropped {
    // The default implementation of this method is .... empty.
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

- (BOOL)showsDefaultPeekedViewController {
    return NO;
}

#pragma mark Sheet stack peeking

- (void)peekSheet:(UIViewController *)vc animated:(BOOL)animated {
    [self.sheetNavigationController peekViewController:vc];
}


- (void)sheetNavigationControllerWillMoveController:(UIViewController *)controller {
    // The default implementation of this method is ....  empty.
}

- (void)sheetNavigationControllerDidMoveController:(UIViewController *)controller {
    // The default implementation of this method is ....  empty.
}

- (void)pushNewSheet:(UIViewController *)vc {
    [self.sheetNavigationController pushViewController:vc inFrontOf:self configuration:nil];
}

@end
