//
//  SheetController.m
//  OpenClass
//
//  Created by Ben Pilcher on 4/5/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "SheetController.h"
#import "SheetNavigationItem.h"
#import "SheetLayoutModel.h"
#import "UIView+position.h"
#import "SheetNavigationController.h"
#import "UIViewController+SheetNavigationController.h"
#import <QuartzCore/QuartzCore.h>

#define DEFAULT_MENU_WIDTH      200.0
#define DROPPED_BG_COLOR        [UIColor clearColor]
#define SAVED_IMAGE_VIEW        80
#define DEBUG_DROPPED_SHEETS    NO

@interface SheetController ()

@property (nonatomic, readwrite, strong) SheetNavigationItem *sheetNavigationItem;
@property (nonatomic, readwrite) BOOL maximumWidth;
@property (nonatomic, strong) UIView *borderView;
@property (nonatomic, strong) UIView *leftNavButtonItem;
@property (nonatomic, weak) UIView *contentView;

@end

@implementation SheetController

#pragma mark - init/dealloc

- (id)initWithContentViewController:(UIViewController *)vc maximumWidth:(BOOL)maxWidth
{
    if ((self = [super init])) {
        _contentViewController = vc;
        
        SheetLayoutType layoutType = [SheetLayoutModel layoutTypeForSheetController:self];
        self.sheetNavigationItem = [[SheetNavigationItem alloc] initWithType:layoutType];
        self.sheetNavigationItem.sheetController = self;
        self.sheetNavigationItem.nextItemDistance = kSheetNextItemDefaultDistance;
        self.maximumWidth = maxWidth;
        _isRestored = NO;
        
    }
    
    return self;
}

- (void)addObservers {
    if ([SheetLayoutModel shouldShowLeftNavItem:self.sheetNavigationItem]) {
        [self.sheetNavigationItem addObserver:self forKeyPath:@"offset" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
        [self.sheetNavigationItem addObserver:self forKeyPath:@"leftButtonView" options:NSKeyValueObservingOptionNew context:NULL];
        self.leftNavButtonItem = self.sheetNavigationItem.leftButtonView;
        self.leftNavButtonItem.alpha = 1.0;
        [self.view addSubview:self.leftNavButtonItem];
    }
}

- (void)dealloc {
    if ([SheetLayoutModel shouldShowLeftNavItem:self.sheetNavigationItem]) {
        [self.sheetNavigationItem removeObserver:self forKeyPath:@"offset"];
        [self.sheetNavigationItem removeObserver:self forKeyPath:@"leftButtonView"];
    }
    
    self.sheetNavigationItem.sheetController = nil;
}

- (void)dumpContentViewController {
    [self.contentViewController willMoveToParentViewController:nil];
    
    void(^animationsComplete)(void) = ^{
        [self.contentViewController.view removeFromSuperview];
        [self.contentViewController removeFromParentViewController];
        _contentViewController = nil;
    };
    
    // TODO: move this into basic sheet OR hook sheetcontroller into
    // willGetStacked and didGetStacked
    if (DEBUG_DROPPED_SHEETS) {
        animationsComplete();
        self.view.backgroundColor = [UIColor redColor];
        return;
    }
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        UIImageView *savedImage = [self snapshotView];
        savedImage.frame = self.contentView.frame;
        savedImage.tag = SAVED_IMAGE_VIEW;
        savedImage.alpha = 0.0;
        [self.view addSubview:savedImage];
        
        [UIView animateWithDuration:0.3
                              delay:0
                            options: UIViewAnimationOptionCurveLinear
                         animations:^{
                             self.contentViewController.view.alpha = 0.0;
                             savedImage.alpha = 1.0;
                         }
                         completion:^(BOOL finished) {
                             if (finished) {
                                 animationsComplete();
                             }
                         }];
    });
    
    self.view.backgroundColor = DROPPED_BG_COLOR;
}

- (UIImageView *)snapshotView
{
    UIGraphicsBeginImageContextWithOptions(self.contentView.bounds.size,YES,0.0f); //screenshot
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [self.contentView.layer renderInContext:context];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImageView *snapshot = [[UIImageView alloc] initWithImage:viewImage];
    if (self.sheetNavigationItem.displayShadow) {
        [self addShadow:snapshot];
    }
    
    return snapshot;
}

- (void)addShadow:(UIView *)view {
    view.layer.shadowRadius = 3.0;
    view.layer.shadowOffset = CGSizeMake(-2.0, -1.0);
    view.layer.shadowOpacity = 0.3;
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.view.bounds].CGPath;
}

- (void)setContentViewController:(UIViewController *)contentViewController {
    if (_contentViewController != contentViewController) {
        
        [[self.view viewWithTag:SAVED_IMAGE_VIEW] removeFromSuperview];
        [UIView animateWithDuration:0.5
                         animations:^{
                             [[self.view viewWithTag:SAVED_IMAGE_VIEW] setAlpha:0.0];
                         }
                         completion:^(BOOL finished){
                             [[self.view viewWithTag:SAVED_IMAGE_VIEW] removeFromSuperview];
                         }];
        
        _contentViewController = contentViewController;
        
        [self.contentViewController willMoveToParentViewController:self];
        [self addChildViewController:self.contentViewController];
        [self.contentViewController didMoveToParentViewController:self];
        
        self.contentView = self.contentViewController.view;
        [self.view addSubview:self.contentView];
        [self.view addSubview:self.leftNavButtonItem];
        
        _isRestored = YES;
        self.view.backgroundColor = [UIColor whiteColor];
        
        [self doViewLayout];
    }
}

#pragma mark - internal methods

- (void)doViewLayout
{
    if (self.leftNavButtonItem) {
        CGRect frame = self.leftNavButtonItem.bounds;
        self.leftNavButtonItem.frameX = -floorf(frame.size.width*0.5);
        self.leftNavButtonItem.frameY = 7.0;
    }
    
    CGRect contentFrame = CGRectZero;
    contentFrame.origin = CGPointMake(0.0, 0.0);
    
    CGRect borderFrame = CGRectZero;
    const CGFloat borderSpacing = 0.0;
    //self.sheetNavigationItem.hasBorder ? 1 : 0;
    
    borderFrame = CGRectMake(0,0,CGRectGetWidth(self.view.bounds),CGRectGetHeight(self.view.bounds));
    contentFrame = CGRectMake(borderSpacing,
                              borderSpacing,
                              CGRectGetWidth(self.view.bounds)-(2*borderSpacing),
                              CGRectGetHeight(self.view.bounds)-(2*borderSpacing));
    
    SheetNavigationItem *navItem = self.sheetNavigationItem;
    
    CGFloat desiredWidth = [[SheetLayoutModel sharedInstance] desiredWidthForContent:self.contentViewController navItem:navItem];
    if (desiredWidth == 0.0) { // sheet subclass didn't specify anything
        desiredWidth = navItem.width;
    }
    
    if (desiredWidth == 0.0) {
        contentFrame.size.width = 100.0; // arbitrary
    } else {
        contentFrame.size.width = desiredWidth;
    }
    
    void(^doFrameMove)(void) = ^{
        self.contentView.frame = contentFrame;
    };
    void(^frameMoveComplete)(void) = ^{
        [self.contentView setNeedsLayout];
    };
    
    if (navItem.displayShadow ||
        navItem.layoutType == kSheetLayoutDefault ||
        navItem.layoutType == kSheetLayoutFullAvailable) {
        [self addShadow:self.contentView];
    }
    
    //BOOL animated = (navItem.index > 0 && navItem.index < kFirstStackedSheet+1) ? YES : NO;
    BOOL animated = (navItem.index > 0 && navItem.offset <= 3);
    float duration = 0.5;
    if (animated) {
        [UIView animateWithDuration:duration
                         animations:^{
                             doFrameMove();
                         }
                         completion:^(BOOL finished){
                             frameMoveComplete();
                         }];
    } else {
        doFrameMove();
        frameMoveComplete();
    }
}

#pragma mark - UIViewController interface methods

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addObservers];
}

- (void)loadView
{
    self.view = [[UIView alloc] init];
    self.view.backgroundColor = [UIColor whiteColor];
    
    if (self.contentView == nil && self.contentViewController.parentViewController == self) {
        /* when loaded again after a low memory view removal */
        self.contentView = self.contentViewController.view;
    }
    
    if (self.contentView != nil) {
        [self.view addSubview:self.contentView];
        
        if (self.sheetNavigationItem.displayShadow ||
            self.sheetNavigationItem.layoutType == kSheetLayoutDefault ||
            self.sheetNavigationItem.layoutType == kSheetLayoutFullAvailable) {
            [self addShadow:self.contentView];
        }
    }
    
    //self.view.layer.borderColor = [UIColor redColor].CGColor;
    //self.view.layer.borderWidth = 1.0;
}

- (void)viewWillLayoutSubviews {
    [self doViewLayout];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    self.borderView = nil;
    self.contentView = nil;
    self.leftNavButtonItem = nil;
    if ([SheetLayoutModel shouldShowLeftNavItem:self.sheetNavigationItem]) {
        [self.sheetNavigationItem removeObserver:self forKeyPath:@"offset"];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    [super willMoveToParentViewController:parent];
    
    if (parent != nil) {
        /* will shortly attach to parent */
        [self addChildViewController:self.contentViewController];
        self.contentView = self.contentViewController.view;
        [self.view addSubview:self.contentView];
        [self.view addSubview:self.leftNavButtonItem];
        
    } else {
        /* will shortly detach from parent view controller */
        [self.contentViewController willMoveToParentViewController:nil];
        [self.contentView removeFromSuperview];
        self.contentView = nil;
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    [super didMoveToParentViewController:parent];
    
    if (parent != nil) {
        /* just attached to parent view controller */
        [self.contentViewController didMoveToParentViewController:self];
    } else {
        /* did just detach */
        [self.contentViewController removeFromParentViewController];
    }
}

#pragma mark Sheet stack page

- (void)willBeUnstacked {
    if ([self.contentViewController respondsToSelector:@selector(willBeUnstacked)]) {
        [(id<SheetStackPage>)self.contentViewController willBeUnstacked];
    }
}

- (void)beingUnstacked:(CGFloat)percentUnstacked {
    if ([self.contentViewController respondsToSelector:@selector(beingUnstacked:)]) {
        [(id<SheetStackPage>)self.contentViewController beingUnstacked:percentUnstacked];
    }
    
    if (self.leftNavButtonItem && self.sheetNavigationItem.offset == 1) {
        [UIView animateWithDuration:0.5
                              delay:0
                            options: UIViewAnimationOptionCurveLinear
                         animations:^{
                             self.leftNavButtonItem.alpha = 1-percentUnstacked;
                         }
                         completion:nil];
    }
}

- (void)didGetUnstacked {
    if ([self.contentViewController respondsToSelector:@selector(didGetUnstacked)]) {
        [(id<SheetStackPage>)self.contentViewController didGetUnstacked];
    }
}

- (void)willBeStacked {
    if ([self.contentViewController respondsToSelector:@selector(willBeStacked)]) {
        [(id<SheetStackPage>)self.contentViewController willBeStacked];
    }
    
}

- (void)didGetStacked {
    if ([self.contentViewController respondsToSelector:@selector(didGetStacked)]) {
        [(id<SheetStackPage>)self.contentViewController didGetStacked];
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"offset"]) {
        [self updateLeftNavButton:change];
    } else if ([keyPath isEqualToString:@"leftButtonView"]) {
        [self.leftNavButtonItem removeFromSuperview];
        self.leftNavButtonItem = self.sheetNavigationItem.leftButtonView;
        self.leftNavButtonItem.alpha = 1.0;
        [self.view addSubview:self.leftNavButtonItem];
    }
}

- (void)updateLeftNavButton:(NSDictionary *)change {
    NSNumber *oldOffset = (NSNumber *)[change objectForKey:NSKeyValueChangeOldKey];
    NSNumber * newOffset = (NSNumber *)[change objectForKey:NSKeyValueChangeNewKey];
    
    BOOL justRevealed = oldOffset.intValue == 3 && newOffset.intValue == 2;
    BOOL justHidden = oldOffset.intValue == 2 && newOffset.intValue == 3;
    
    if (justRevealed || newOffset.intValue < 3) {
        [self.leftNavButtonItem removeFromSuperview];
        self.leftNavButtonItem = [self.sheetNavigationItem leftButtonView];
        self.leftNavButtonItem.alpha = 1.0;
        [self.view addSubview:self.leftNavButtonItem];
    } else if (justHidden) {
        [UIView animateWithDuration:0.4
                              delay:0.25
                            options: UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             self.leftNavButtonItem.alpha = 0.0;
                         }
                         completion:^(BOOL finished) {
                             [self.leftNavButtonItem setHidden:YES];
                         }];
    }
    
}

@end
