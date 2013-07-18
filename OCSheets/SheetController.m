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

#define DELAYED_BLOCK(block,delay) dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)); \
dispatch_after(popTime, dispatch_get_main_queue(), ^(void){ \
block(); \
});

@interface SheetController () {
    BOOL _peeking;
    BOOL _showsLeftNavButton;
    NSMutableArray *keyValueObserving;
}

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
        _peeking = NO;
        SheetLayoutType layoutType = [SheetLayoutModel layoutTypeForSheetController:self];
        self.sheetNavigationItem = [[SheetNavigationItem alloc] initWithType:layoutType];
        self.sheetNavigationItem.sheetController = self;
        self.sheetNavigationItem.nextItemDistance = kSheetNextItemDefaultDistance;
        self.maximumWidth = maxWidth;
        _isRestored = NO;
        keyValueObserving = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (BOOL)shouldAutomaticallyForwardRotationMethods {
    return YES;
}

- (void)dealloc {
    [self removeObservers];
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

- (void)loadView
{
    self.view = [[UIView alloc] init];
    self.view.backgroundColor = [UIColor whiteColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    
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
    
    _showsLeftNavButton = [SheetLayoutModel shouldShowLeftNavItem:self.sheetNavigationItem];
    
    [self addObservers];
    
    if (_showsLeftNavButton) {
        self.leftNavButtonItem = self.sheetNavigationItem.leftButtonView;
        if (!self.leftNavButtonItem) {
            self.leftNavButtonItem = [self.sheetNavigationItem leftButtonView];
        }
        self.leftNavButtonItem.alpha = 1.0;
        [self.view addSubview:self.leftNavButtonItem];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    
    self.leftNavButtonItem.alpha = self.sheetNavigationItem.offset == 1 ? 1.0 : 00.;
}

- (void)viewWillLayoutSubviews {
    [self doViewLayout];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    self.borderView = nil;
    self.contentView = nil;
    self.leftNavButtonItem = nil;
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
        if (_peeking) {
            [self.view addSubview:self.coverView];
        }
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

- (void)rasterizeAndSnapshot {
    if (self.sheetNavigationItem.offset == 2) {
        UIImageView *snapshot = [self snapshotView];
        snapshot.tag = 120;
        [self.view insertSubview:snapshot belowSubview:self.coverView];
        [self.view.layer setShouldRasterize:YES];
        //NSLog(@"did turn ON rasterization for %@",NSStringFromClass([self.sheetNavigationItem.sheetController.contentViewController class]));
    }
}

- (void)unrasterizeAndUnsnapshot {
    [[self.view viewWithTag:120] removeFromSuperview];
    [self.view.layer setShouldRasterize:NO];
    ///NSLog(@"did turn OFF rasterization for %@",NSStringFromClass([self.sheetNavigationItem.sheetController.contentViewController class]));
}

#pragma mark Sheet stack page

- (void)willBeUnstacked {
    if ([self.contentViewController respondsToSelector:@selector(willBeUnstacked)]) {
        [(id<SheetStackPage>)self.contentViewController willBeUnstacked];
    }
}

- (void)beingUnstacked:(CGFloat)percentUnstacked {
    if (percentUnstacked == 1.0 && self.coverView.alpha == kCoverOpacity) {
        [self hideView:self.coverView withDuration:[SheetLayoutModel animateOffDuration] withDelay:0.0];
        return;
    }
    self.coverView.alpha = kCoverOpacity*(1-percentUnstacked);
    [self.view addSubview:self.coverView];
    
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
    [self removeView:self.coverView];
    if (self.sheetNavigationItem.offset == 1) {
        //[self unrasterizeAndUnsnapshot];
    }
    
    if ([self.contentViewController respondsToSelector:@selector(didGetUnstacked)]) {
        [(id<SheetStackPage>)self.contentViewController didGetUnstacked];
    }
}

- (void)willBeStacked {
    
    [self.view addSubview:self.coverView];
    self.coverView.backgroundColor = [UIColor blackColor];
    [self revealView:self.coverView withDelay:0.0];
    
    if ([self.contentViewController respondsToSelector:@selector(willBeStacked)]) {
        [(id<SheetStackPage>)self.contentViewController willBeStacked];
    }
}

- (void)didGetStacked {
    if (self.sheetNavigationItem.offset == 2) {
        //[self rasterizeAndSnapshot];
    }
    if ([self.contentViewController respondsToSelector:@selector(didGetStacked)]) {
        [(id<SheetStackPage>)self.contentViewController didGetStacked];
    }
}

- (void)decodeRestorableState:(NSDictionary *)archiveDict {
    [self.view addSubview:self.coverView];
    self.coverView.alpha = kCoverOpacity;
    self.coverView.backgroundColor = [UIColor blackColor];
    
    if ([self.contentViewController respondsToSelector:@selector(decodeRestorableState)]) {
        [(id<SheetStackPage>)self.contentViewController decodeRestorableState:archiveDict];
    }
}

- (void)isPeeking:(BOOL)peeking onTopOfSheet:(UIViewController *)sheet {
    _peeking = peeking;
    [self updateViewForPeeking];
    
    if ([self.contentViewController respondsToSelector:@selector(isPeeking:onTopOfSheet:)]) {
        [(id<SheetStackPeeking>)self.contentViewController isPeeking:_peeking onTopOfSheet:sheet];
    }
}

- (BOOL)peeked {
    return _peeking;
}

- (void)updateViewForPeeking {
    if (_peeking) {
        [self.view addSubview:self.coverView];
        self.coverView.backgroundColor = [UIColor clearColor];
        self.coverView.alpha = 1.0;
    } else {
        [self removeView:_coverView];
    }
}

#pragma mark - KVO

- (void)addObservers {
    if (_showsLeftNavButton) {
        [self observeKeyPath:@"offset" forItem:self.sheetNavigationItem];
        [self observeKeyPath:@"leftButtonView" forItem:self.sheetNavigationItem];
        [self observeKeyPath:@"hidden" forItem:self.sheetNavigationItem];
    }
    [self observeKeyPath:@"showingPeeked" forItem:self.sheetNavigationItem];
}

- (void)observeKeyPath:(NSString *)keyPath forItem:(NSObject *)object {
    [keyValueObserving addObject:keyPath];
    [object addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)removeObservers {
    for (NSString *keyPath in keyValueObserving) {
        [self.sheetNavigationItem removeObserver:self forKeyPath:keyPath];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"offset"]) {
        [self updateLeftNavButton:change];
    } else if ([keyPath isEqualToString:@"leftButtonView"]) {
        if ([self.sheetNavigationItem.leftButtonView isEqual:self.leftNavButtonItem]) {
            self.leftNavButtonItem = self.sheetNavigationItem.leftButtonView;
        } else {
            [self.leftNavButtonItem removeFromSuperview];
            self.leftNavButtonItem = self.sheetNavigationItem.leftButtonView;
            self.leftNavButtonItem.alpha = 1.0;
            [self.view addSubview:self.leftNavButtonItem];
        }
    } else if ([keyPath isEqualToString:@"hidden"]) {
        BOOL hidden = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        [self.leftNavButtonItem setHidden:hidden];
    } else if ([keyPath isEqualToString:@"showingPeeked"]) {
        
        [self.sheetNavigationController layoutPeekedViewControllers];
    }
}

#pragma mark -

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

- (UIView *)coverView {
    if (!_coverView) {
        _coverView = [[UIView alloc] initWithFrame:CGRectZero];
        _coverView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    }
    [_coverView setFrame:self.view.bounds];
    return _coverView;
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
