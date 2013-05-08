//
//  BasicSheetViewController.m
//  OpenClass
//
//  Created by Ben Pilcher on 4/17/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "BasicSheetViewController.h"
#import "UIView+position.h"
#import <QuartzCore/QuartzCore.h>

#define DELAYED_BLOCK(block,delay) dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)); \
dispatch_after(popTime, dispatch_get_main_queue(), ^(void){ \
block(); \
});

#define COVER_TAG               45

@interface BasicSheetViewController () {
    //BOOL _peeking;
}

@property (nonatomic, strong) UIView *coverView;

@end

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
    //NSLog(@"Index: %i, count: %i, offset: %i",navItem.index,navItem.count,navItem.offset);
    
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
    
}

- (void)didGetStacked {
    
}

- (void)willBeUnstacked {

}

- (void)beingUnstacked:(CGFloat)percentUnstacked {

}

- (void)didGetUnstacked {

}

- (void)willBeDropped {
    
}

- (void)didGetDropped {
    
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

#pragma mark Sheet stack peeking

- (void)peekSheet:(UIViewController *)vc animated:(BOOL)animated {
    [self.sheetNavigationController peekViewController:vc];
}

- (BOOL)shouldPeekDefaultSheet {
    return YES;
}

- (void)sheetNavigationControllerWillMoveController:(UIViewController *)controller {

}

- (void)sheetNavigationControllerDidMoveController:(UIViewController *)controller {

}

- (void)pushNewSheet:(UIViewController *)vc {
    [self.sheetNavigationController pushViewController:vc inFrontOf:self configuration:nil];
}

@end
