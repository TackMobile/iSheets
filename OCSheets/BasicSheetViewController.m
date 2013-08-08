//
//  BasicSheetViewController.m
//  OpenClass
//
//  Created by Ben Pilcher on 4/17/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "BasicSheetViewController.h"

@interface BasicSheetViewController()
@property (nonatomic, assign) BOOL disallowFuturePeek;
@end

@implementation BasicSheetViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
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

- (CGFloat)desiredWidthForSheetPosition:(SheetStackPosition)position navItem:(SheetNavigationItem *)navItem orientation:(UIInterfaceOrientation)orientation {
    SheetLayoutType type = navItem ? navItem.layoutType : kStandardSheetWidth;
    if (type == kSheetLayoutFullScreen || type == kSheetLayoutFullAvailable) {
        return [[SheetLayoutModel sharedInstance] availableWidthForOffset:navItem.initialViewPosition.x orientation:orientation];
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
    self.sheetNavigationItem.showingPeeked = !_disallowFuturePeek ? !hidden : NO;
}

- (void)setPeekedHidden:(BOOL)hidden disallowingFuturePeek:(BOOL)peekDisallowed {
    _disallowFuturePeek = peekDisallowed;
    [self setPeekedHidden:!_disallowFuturePeek ? hidden : YES];
}

/*
 Call this method to perform additional UI work
 when a sheet is about to be stacked on top of for the first time
 */
- (void)sheetWillBeStacked {
    // The default implementation of this method is .... empty.
}

- (void)sheetDidGetStacked {
    // The default implementation of this method is .... empty.
}

- (void)sheetWillBeUnstacked {
    // The default implementation of this method is .... empty.
    
}

- (void)sheetBeingUnstacked:(CGFloat)percentUnstacked {
    // The default implementation of this method is .... empty.
}

- (void)sheetDidGetUnstacked {
    // The default implementation of this method is .... empty.
}

- (void)sheetWillBeDropped {
    // The default implementation of this method is .... empty.
}

- (void)sheetDidGetDropped {
    // The default implementation of this method is .... empty.
}

- (NSMutableDictionary *)encodeRestorableState {
    return nil;
}

- (void)decodeRestorableState:(NSDictionary *)archiveDict {
 
}

- (UIView *)leftButtonViewForStackedSheet {
    UIImageView *circleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sheetsCircleStacked"]];
    UIView *view = [[UIView alloc] initWithFrame:circleImage.bounds];
    [view addSubview:circleImage];
    return view;
}

- (float)availableContentWidthForOrientation:(UIInterfaceOrientation)orientation {
    return [self desiredWidthForSheetPosition:kSheetStackTop navItem:self.sheetNavigationItem orientation:orientation];
}

- (float)availableContentWidth {
    return [self desiredWidthForSheetPosition:kSheetStackTop navItem:self.sheetNavigationItem];
}

- (void)sheetNavigationControllerWillMoveController:(UIViewController *)controller {
    // The default implementation of this method is ....  empty.
}

- (void)sheetNavigationControllerDidMoveController:(UIViewController *)controller {
    // The default implementation of this method is ....  empty.
}

- (BOOL)showsDefaultPeekedViewController {
    return NO;
}

#pragma mark Convenience helpers

- (void)peekSheet:(UIViewController *)vc animated:(BOOL)animated {
    [self.sheetNavigationController peekViewController:vc];
}

- (void)pushNewSheet:(UIViewController *)vc {
    [self.sheetNavigationController pushViewController:vc inFrontOf:self configuration:nil];
}


@end
