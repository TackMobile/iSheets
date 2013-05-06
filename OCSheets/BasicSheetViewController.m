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

#define COVER_TAG 45

@interface BasicSheetViewController () {
    BOOL _peeked;
}

@property (nonatomic, strong) UIView *coverView;

@end

@implementation BasicSheetViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _peeked = NO;
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)addShadow {
    self.view.layer.shadowRadius = 3.0;
    self.view.layer.shadowOffset = CGSizeMake(-2.0, -1.0);
    self.view.layer.shadowOpacity = 0.3;
    self.view.layer.shadowColor = [UIColor blackColor].CGColor;
    self.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.view.bounds].CGPath;
}

- (UIView *)coverView {
    if (!_coverView) {
        _coverView = [[UIView alloc] initWithFrame:CGRectZero];
        _coverView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    }
    [_coverView setFrame:self.view.bounds];
    return _coverView;
}

- (NSNumber *)widthForSheetPosition:(NSNumber *)position navItem:(SheetNavigationItem *)navItem {
    NSNumber *width = [NSNumber numberWithFloat:[self desiredWidthForSheetPosition:position.intValue navItem:navItem]];
    return width;
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
    [self.view addSubview:self.coverView];
    self.coverView.backgroundColor = [UIColor blackColor];
    [self revealView:self.coverView withDelay:0.0];
}

- (void)didGetStacked {
    
}

- (void)willBeUnstacked {
    
}

- (void)beingUnstacked:(CGFloat)percentUnstacked {
    if (percentUnstacked == 1.0 && self.coverView.alpha == kCoverOpacity) {
        [self hideView:self.coverView withDuration:[SheetLayoutModel animateOffDuration] withDelay:0.0];
        return;
    }
    self.coverView.alpha = kCoverOpacity*(1-percentUnstacked);
}

- (void)didGetUnstacked {
    [self removeView:self.coverView];
}

- (void)willBeDropped {
    
}

- (void)didGetDropped {
    
}

- (NSMutableDictionary *)encodeRestorableState {
    return nil;
}

- (void)decodeRestorableState:(NSDictionary *)archiveDict {
    
    [self.view addSubview:self.coverView];
    self.coverView.alpha = kCoverOpacity;
    self.coverView.backgroundColor = [UIColor blackColor];
}

- (UIView *)viewForLeftNavButton {
    UIView *view = nil;
    UIImageView *circleImage = nil;
    if (self.sheetNavigationItem.offset > 1) {
        circleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sheetsCircleStacked"]];
    } else {
        circleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sheetsCircle"]];
    }
    
    CGRect frame = circleImage.bounds;
    view = [[UIView alloc] initWithFrame:frame];
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

- (void)setPeeking:(BOOL)peeked {
    _peeked = peeked;
    [self updateViewForPeeking];
}

- (BOOL)peeked {
    return _peeked;
}

- (void)updateViewForPeeking {
    if (_peeked) {
        [self.view addSubview:self.coverView];
        self.coverView.backgroundColor = [UIColor clearColor];
        self.coverView.alpha = 1.0;
    } else {
        [self removeView:_coverView];
    }
}

#pragma mark View helpers

- (void)pushNewSheet:(UIViewController *)vc {
    [self.sheetNavigationController pushViewController:vc inFrontOf:self configuration:nil];
}

- (void)hideView:(UIView *)view withDuration:(float)duration withDelay:(float)delay {
    
    void(^hide)(void) = ^{[UIView animateWithDuration:duration
                                           animations:^{
                                               view.alpha = 0.0;
                                           }
                                           completion:nil];
    };
    DELAYED_BLOCK(hide, delay);
}

- (void)revealView:(UIView *)view withDelay:(float)delay {
    view.alpha = 0.0;
    void(^show)(void) = ^{
        [UIView animateWithDuration:0.5
                         animations:^{
                             view.alpha = kCoverOpacity;
                         }
                         completion:nil];
    };
    DELAYED_BLOCK(show, delay);
}

- (void)removeView:(UIView *)view {
    [UIView animateWithDuration:0.5
                     animations:^{
                         view.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         [view removeFromSuperview];
                     }];
}

@end
