//
//  SheetViewController.m
//  OpenClass
//
//  Created by Ben Pilcher on 4/1/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "SheetNavigationController.h"
#import "SheetLayoutModel.h"
#import "SheetNavigationItem.h"
#import "SheetHistoryManager.h"
#import "UIView+position.h"
#import <objc/runtime.h>
#import "UIViewController+SheetNavigationController.h"
#import <QuartzCore/QuartzCore.h>



#define SHEET_REMOVAL_ANIMATION_OPTION          UIViewAnimationOptionCurveLinear
#define SHEET_ADDING_ANIMATION_OPTION           UIViewAnimationOptionCurveEaseOut

#define isDefaultPeekedSheet(x)                 [x isEqual:self.peekedSheetController]
#define wantsDefaultPeekedSheet(x)              [self showsDefaultPeekedViewController:x]

typedef enum {
    SnappingPointsMethodNearest,
    SnappingPointsMethodCompact,
    SnappingPointsMethodExpand
} SnappingPointsMethod;

@interface SheetNavigationController () {
    // flag to capture user gesture intent
    BOOL _willExpandedPeeked;
    BOOL _willDismissTopSheet;
    BOOL _willPopToRootSheet;
    
    CGRect peekedFrame;
}

@property (nonatomic, strong) UITapGestureRecognizer            *tapGR;

@property (nonatomic, assign) BOOL dropLayersWhenPulledRight;

@property (nonatomic, strong) NSMutableArray                    *sheetViewControllers;
@property (nonatomic, weak) UIViewController                    *outOfBoundsViewController;
@property (nonatomic, weak) UIView                              *firstTouchedView;
@property (nonatomic, weak) UIView                              *dropNotificationView;

@property (nonatomic, strong) SheetController                   *peekedSheetController;
@property (nonatomic, weak) UIViewController                    *firstTouchedController;
@property (nonatomic, weak) SheetController                     *firstStackedController;
@property (nonatomic, strong) NSMutableArray                    *peekedViewControllers;

@end

@implementation SheetNavigationController

- (id)initWithRootViewController:(UIViewController *)rootViewController {
    return [self initWithRootViewController:rootViewController configuration:nil];
}

- (UIViewController *)peekedSheet{
    return self.peekedSheetController.contentViewController;
}

- (CGFloat)snappingVelocityThreshold {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    return UIInterfaceOrientationIsLandscape(orientation) ? 875.0 : 340.0;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
                   configuration:(void (^)(SheetNavigationItem *item))configuration {
    self = [super init];
    if (self) {
        
        _outOfBoundsViewController = nil;
        _userInteractionEnabled = YES;
        _historyManager = [[SheetHistoryManager alloc] init];
        [[SheetLayoutModel sharedInstance] setController:self];
        
        SheetController *sheetRC = [[SheetController alloc] initWithContentViewController:rootViewController maximumWidth:YES];
        sheetRC.sheetNavigationItem.index = 0;
        [sheetRC.sheetNavigationItem setCount:1];
        _sheetViewControllers = [[NSMutableArray alloc] initWithObjects:sheetRC, nil];
        
        if (configuration) {
            configuration(sheetRC.sheetNavigationItem);
        }
        
        [_historyManager addHistoryItemForSheetController:sheetRC];
        
        [self addChildViewController:sheetRC];
        [sheetRC didMoveToParentViewController:self];
        [[SheetLayoutModel sharedInstance] incrementTierCount];
        
    }
    return self;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController peekedViewController:(UIViewController *)peekedViewController configuration:(SheetNavigationConfigBlock)configuration  {
    self = [self initWithRootViewController:rootViewController configuration:configuration];
    if (self) {
        if (peekedViewController) {
            
            self.peekedSheetController = [[SheetController alloc] initWithContentViewController:peekedViewController maximumWidth:NO];
            SheetNavigationItem *navItem = self.peekedSheetController.sheetNavigationItem;
            float initXPos = self.topSheetContentViewController.sheetNavigationItem.nextItemDistance;
            navItem.initialViewPosition = CGPointMake(initXPos, 0.0);
            navItem.isPeekedSheet = YES;
            
            CGRect frame = self.peekedSheetController.view.frame;
            frame.origin.x = [self overallWidth];
            frame.size.width = [[SheetLayoutModel sharedInstance] desiredWidthForContent:peekedViewController navItem:navItem];
            frame.size.height = [self overallHeight];
            
            navItem.currentViewPosition = CGPointMake(frame.origin.x, 0.0);
            self.peekedSheetController.view.frame = frame;
            [self addPeekedSheetPanGesture];
        }
    }
    
    return self;
}

- (void) forceCleanup {
    [self viewDidUnload];
    
    [self popToRootViewControllerAnimated:NO];
    
    [self.topSheetContentViewController willMoveToParentViewController:nil];
    [self.topSheetContentViewController.view removeFromSuperview];
    [self.topSheetContentViewController removeFromParentViewController];
    
    [self.peekedSheetController willMoveToParentViewController:nil];
    [self.peekedSheetController.contentViewController removeFromParentViewController];
    [self.peekedSheetController.view removeFromSuperview];
    [self.peekedSheetController removeFromParentViewController];

    [self detachGestureRecognizers];
    self.peekedSheetController = nil;
    self.firstStackedController = nil;
    self.firstTouchedController = nil;
    [self.historyManager removeAllHistory];
    [self.sheetViewControllers removeAllObjects];
    
    [SheetLayoutModel resetSharedInstance];
}

- (void)addPeekedSheetPanGesture {
    self.peekedPanGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePeekedPanGesture:)];
    self.peekedPanGR.maximumNumberOfTouches = 1;
    [self.peekedSheetController.view addGestureRecognizer:self.peekedPanGR];
}

- (void)dealloc {
    [self detachGestureRecognizers];
}

#pragma mark - UIViewController interface

- (void)loadView {
    self.view = [[UIView alloc] init];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    for (SheetController *sheetController in self.sheetViewControllers) {
        
        float width = [[SheetLayoutModel sharedInstance] widthForNavItem:sheetController.sheetNavigationItem];
        sheetController.view.frame = CGRectMake(sheetController.sheetNavigationItem.currentViewPosition.x,
                                                sheetController.sheetNavigationItem.currentViewPosition.y,
                                                width,
                                                CGRectGetHeight(self.view.bounds));
        sheetController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:sheetController.view];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.userInteractionEnabled) {
        [self attachGestureRecognizers];
    }
    self.view.backgroundColor = [UIColor clearColor];
    
    if ([self shouldShowDefaultPeeked]) {
        if (self.peekedSheetController) {
            [self peekViewController:self.peekedSheetController animated:NO];
        }
    }
}

- (void)viewWillLayoutSubviews {

    SheetStackState state = [[SheetLayoutModel sharedInstance] stackState];
    if (state == kSheetStackStateAdding || state == kSheetStackStateRemoving) {
        [self doLayout];
    } else {
        [self layoutPeekedViewControllers];
        for (SheetController *sheetController in [self visibleSheets]) {
            //NSLog(@"laying out %@, %f",sheetController.sheetNavigationItem.sheetContentClass,[NSDate timeIntervalSinceReferenceDate]);
            [self layoutSheetController:sheetController];
        }
    }
}

- (NSMutableArray *)visibleSheets {
    int count = self.sheetViewControllers.count;
    if (count < 2) {
        return [@[[self topSheetController]] mutableCopy];
    }
    NSMutableArray *visible = [[NSMutableArray alloc] initWithCapacity:count];
    SheetNavigationItem *aboveNavItem = nil;
    for (SheetController *sheetController in [self.sheetViewControllers reverseObjectEnumerator]) {
        
        if (aboveNavItem != nil) {
            SheetNavigationItem *navItem = sheetController.sheetNavigationItem;
            float visibleWidth = aboveNavItem.initialViewPosition.x - navItem.initialViewPosition.x;
            if (visibleWidth > 0.0) {
                [visible addObject:sheetController];
                sheetController.isVisible = YES;
            } else {
                sheetController.isVisible = NO;
            }
        } else {
            [visible addObject:[self topSheetController]];
        }
        
        aboveNavItem = sheetController.sheetNavigationItem;
    }

    return visible;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self doLayout];
}

- (void)viewWillUnload {
    [self detachGestureRecognizers];
    self.firstTouchedView = nil;
    self.outOfBoundsViewController = nil;
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.dropNotificationView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark Sheet layout

- (void)doLayout {

    [self.sheetViewControllers enumerateObjectsUsingBlock:^(SheetController *vc, NSUInteger index, BOOL *stop){
        [self layoutSheetController:vc];
    }];
    
    [self layoutPeekedViewControllers];
}

- (void)setSheetFullscreen:(BOOL)fullscreen completion:(void(^)())completion {
    SheetController *topController = [self sheetControllerOf:self.topSheetContentViewController];
    SheetNavigationItem *navItem = self.topSheetContentViewController.sheetNavigationItem;
    [navItem setFullscreen:fullscreen];
    [[SheetLayoutModel sharedInstance] updateNavItem:navItem];
    [UIView animateWithDuration:0.2
                     animations:^{
                         
                         [self layoutSheetController:topController];
                     }
                     completion:^(BOOL finished){
                         if (completion) completion();
                     }];
}

- (void)layoutPeekedViewControllers {
    
    SheetStackState sheetStackState = [[SheetLayoutModel sharedInstance] stackState];
    
    if (sheetStackState == kSheetStackStateDefault) {
        if ([self.peekedSheetController.contentViewController isViewLoaded]) {
            if ([self shouldLayoutPeekedSheet]) {
                SheetNavigationItem *navItem = self.topSheetContentViewController.sheetNavigationItem;
                float duration = navItem.showingPeeked  ? 0.5 : 0.0;
                [UIView animateWithDuration:duration
                                      delay:0
                                    options: SHEET_ADDING_ANIMATION_OPTION
                                 animations:^{
                                     CGRect frameForPeeked = [self peekedFrameForSheetController:self.peekedSheetController];
                                     self.peekedSheetController.view.frame = frameForPeeked;
                                  }
                                 completion:nil];
                
            } else {
                self.peekedSheetController.view.frameX = [self overallWidth];
            }
        }
    }
}

- (BOOL)shouldLayoutPeekedSheet {
    BOOL notExpanded = !self.peekedSheetController.sheetNavigationItem.expandedPeekedSheet;
    return notExpanded && wantsDefaultPeekedSheet(self.topSheetContentViewController);
}

- (CGRect)frameForDefaultPeeked {
    if ([self peekedSheetReadyToPeek]) {
        return [self peekedFrameForSheetController:self.peekedSheetController];
    }
    CGRect frame = self.peekedSheetController.view.frame;
    frame.origin.x = [self overallWidth];
    return frame;
}

- (void)layoutSheetController:(SheetController *)sheetController {
    CGRect f = sheetController.view.frame;
    SheetNavigationItem *navItem = sheetController.sheetNavigationItem;
    
    
    // snap everything to its initial x pos
    if (navItem.currentViewPosition.x < navItem.initialViewPosition.x) {
        navItem.currentViewPosition = navItem.initialViewPosition;
    }
    
    int offset = navItem.offset;
    
    f.origin = navItem.currentViewPosition;
    f.size.height = CGRectGetHeight(self.view.bounds);
    
    // sheet controller frame (scf) width is always sheet nav controller's frame (sncf)
    // width - distance from sncf origin x to sheet controller's nav item's initialViewPosition (the gutter, show as /*-*/ below).
    
    // content vc width is <= scf width (less, if sheet content vc implementation specifies a desired width)
    // & aligns to left or right of containing vc (sheet controller)
    
    /*-*/ /*********************************/
    /*-*/ /* ***********************       */
    /*-*/ /*   ^ content vc frame  *       */
    /*-*/ /*                       *       */
    /*-*/ /*                       *       */
    /*-*/ /*                       *       */
    /*-*/ /* ***********************       */
    /*-*/ /*********************************/
    //         ^ sheet controller frame
    
    SheetStackState state = [[SheetLayoutModel sharedInstance] stackState];

    [[SheetLayoutModel sharedInstance] updateNavItem:navItem];
    
    float availableWidth = CGRectGetWidth(self.view.bounds) - navItem.initialViewPosition.x;
    f.origin = navItem.initialViewPosition;
    
    // controller width needs to match the content's width when on top (offset 1)
    // but when stacked it should stretch from navItem.initialViewPosition all the way
    // to right side of the screen. We update these immediately– they never need animation
    float controllerWidth = offset == 1 ? navItem.width : availableWidth;
    sheetController.view.frameWidth = controllerWidth;
    sheetController.view.frameHeight = f.size.height;
    
    // content width should respect layout rules of navItem
    sheetController.contentViewController.view.frameWidth = navItem.width;
            
    void(^sheetPositionChange)(void) = ^{
        // animates the entire position of the sheet, content is just along for the ride
        sheetController.view.frameX = f.origin.x;
    };

    UIViewAnimationOptions curve = state == kSheetStackStateAdding ? SHEET_ADDING_ANIMATION_OPTION : SHEET_REMOVAL_ANIMATION_OPTION;
    float duration = state == kSheetStackStateAdding ? [SheetLayoutModel animateOnDuration] : [SheetLayoutModel animateOffDuration];
    
    // animated if visible on top of stack and is not root
    BOOL animated = (offset > 0 && offset < kFirstStackedSheet+1) ? YES : NO;
    if (animated) {
        [UIView animateWithDuration:duration
                              delay:0
                            options:curve
                         animations:^{
                             sheetPositionChange();
                         }
                         completion:nil];
    } else {
        sheetPositionChange();
    }
}

- (CGRect)peekedFrameForSheetController:(SheetController *)sheetController {
    
    const CGFloat peekWidth = [self getPeekedWidth:sheetController.contentViewController];
    
    BOOL shouldShow = [self shouldShowDefaultPeeked];
    
    CGFloat width = [SheetLayoutModel getScreenBoundsForCurrentOrientation].size.width;
    CGFloat dWidth = [[SheetLayoutModel sharedInstance] desiredWidthForContent:sheetController.contentViewController navItem:sheetController.sheetNavigationItem];
    if (shouldShow) {
        width -= peekWidth;
        
    }
    self.peekedSheetController.leftNavButtonItem.hidden = !shouldShow;
    return CGRectMake(width,
                      0.0,
                      dWidth,
                      [self overallHeight]);
}

- (CGFloat)overallWidth {
    return CGRectGetWidth(self.view.bounds) > 0 ? CGRectGetWidth(self.view.bounds) : [SheetLayoutModel getScreenBoundsForCurrentOrientation].size.width;
}

- (CGFloat)overallHeight {
    return CGRectGetHeight(self.view.bounds) > 0 ? CGRectGetHeight(self.view.bounds) : [SheetLayoutModel getScreenBoundsForCurrentOrientation].size.height;
}

- (CGRect)onscreenFrameForNavItem:(SheetNavigationItem *)navItem {
    CGRect frame = CGRectMake(navItem.currentViewPosition.x,
                              navItem.currentViewPosition.y,
                              navItem.width,
                              [self overallHeight]);
    return frame;
}

- (CGRect)offscreenFrameForNavItem:(SheetNavigationItem *)navItem withOnscreenFrame:(CGRect)onscreenFrame {
    CGRect frame = CGRectZero;
    CGFloat offScreenX = [SheetLayoutModel getScreenBoundsForCurrentOrientation].size.width;
    if (navItem.expandedPeekedSheet) {
        // offset it left to match initial x of peeked sheet
        offScreenX -= [self getPeekedWidth:navItem.sheetController.contentViewController];
    }
    frame = CGRectMake(MAX(offScreenX, CGRectGetMinX(onscreenFrame)),
                       0.0,
                       CGRectGetWidth(onscreenFrame),
                       CGRectGetHeight(onscreenFrame));
    return frame;
}

#pragma mark - Public API

- (void)peekViewController:(SheetController *)viewController {
    [(id<SheetStackPage>)[self topSheetController] sheetWillBeStacked];
    [self peekViewController:viewController animated:YES];
    [(id<SheetStackPage>)[self topSheetController] sheetDidGetUnstacked];
}

- (void)popToRootViewControllerAnimated:(BOOL)animated {
    [self popToViewController:[self.sheetViewControllers objectAtIndex:0] animated:animated];
}

- (void)popToViewController:(UIViewController *)vc animated:(BOOL)animated {
    UIViewController *currentVc = [self.sheetViewControllers lastObject];
    
    NSInteger *currentVcIndex = [self.sheetViewControllers indexOfObject:currentVc];
    NSInteger *endingVcIndex = [self.sheetViewControllers indexOfObject:vc];
    
    while (currentVcIndex > endingVcIndex) {
        BOOL currentVCisSheetController = [currentVc class] == [SheetController class];
        BOOL sheetControllerContentisVC = [(SheetController *)currentVc contentViewController] == vc;
        BOOL currentVCisNotSheetControllerClass = [currentVc class] != [SheetController class];
        
        if ((currentVCisSheetController && sheetControllerContentisVC) || (currentVCisNotSheetControllerClass && currentVc == vc)) {
            break;
        }
        
        if ([self.sheetViewControllers count] == 1) {
            /* don't remove root view controller */
            return;
        }
        
        [self popViewControllerAnimated:animated];
        
        currentVc = [self.sheetViewControllers lastObject];
        currentVcIndex = [self.sheetViewControllers indexOfObject:currentVc];
    }
}

- (void)popViewControllerAnimated:(BOOL)animated {
    
    [self willRemoveSheet];
    [self forwardUnstackingPercentage:1.0];
    
    if ([self.sheetViewControllers count] == 1) {
        /* don't remove root view controller */
        [self didRemoveSheet];
        return;
    }
    
    SheetController *vc = [self.sheetViewControllers lastObject];
    
    [self removeSheetFromHistory:vc];
    
    
    [self layoutSheetController:[self.sheetViewControllers lastObject]];
    
    CGFloat xLoc = CGRectGetMaxX(self.view.bounds);
    
    if (vc.sheetNavigationItem.expandedPeekedSheet) {
        xLoc -= vc.sheetNavigationItem.peekedWidth;
    }
    
    BOOL isFullscreen = vc.sheetNavigationItem.layoutType == kSheetLayoutFullScreen ? YES : NO;
    BOOL wantsDefaultPeekedSheet = wantsDefaultPeekedSheet(self.firstStackedController.contentViewController);
    BOOL isPeekedSheet = vc.sheetNavigationItem.expandedPeekedSheet;
    BOOL animateOutAndInDefaultPeekedSheet = wantsDefaultPeekedSheet && isFullscreen && !isPeekedSheet;
    
    if (isPeekedSheet) {
        xLoc -= [self getPeekedWidth:vc.contentViewController];
    }
    
    CGRect goAwayFrame = CGRectMake(xLoc,
                                    CGRectGetMinY(self.view.bounds),
                                    CGRectGetWidth(vc.view.frame),
                                    CGRectGetHeight(vc.view.frame));
    
    void (^completeViewRemoval)(BOOL) = ^(BOOL finished) {
        
        UIViewController *contentVC = vc.contentViewController;
        [self removeSheetFromViewHeirarchy:vc];
        
        if (isPeekedSheet) {
            vc.sheetNavigationItem.expandedPeekedSheet= NO;
            [self addPeekedSheetPanGesture];
            if ([contentVC respondsToSelector:@selector(didGetUnpeeked)]) {
                [(id<SheetStackPeeking>)contentVC didGetUnpeeked];
            }
            [self peekViewController:self.peekedSheetController animated:NO];
        } else if (animateOutAndInDefaultPeekedSheet) {
            
            [UIView animateWithDuration:[SheetLayoutModel animateOnDuration]
                                  delay:0
                                options: SHEET_REMOVAL_ANIMATION_OPTION
                             animations:^{
                                 //NSLog(@"%i: showing peeked at peeked position",__LINE__);
                                 self.peekedSheetController.view.frame = [self peekedFrameForSheetController:self.peekedSheetController];
                             }
                             completion:^(BOOL finished){
                                 if ([self.peekedSheetController.contentViewController respondsToSelector:@selector(willPeekOnTopOfSheet:)]) {
                                     [(id<SheetStackPeeking>)self.peekedSheetController.contentViewController willPeekOnTopOfSheet:self.topSheetContentViewController];
                                 }
             
                             }];
        }
    };
    
    UIViewAnimationOptions curve = isPeekedSheet ? SHEET_ADDING_ANIMATION_OPTION : SHEET_REMOVAL_ANIMATION_OPTION;
    if (animated) {
        [UIView animateWithDuration:[SheetLayoutModel animateOffDuration]
                              delay:0
                            options:curve
                         animations:^{
                             if (isPeekedSheet) {
                                 vc.view.frame = [self peekedFrameForSheetController:vc];
                             } else if (animateOutAndInDefaultPeekedSheet) {
                                 //NSLog(@"%i for overallwidth pos",__LINE__);
                                 self.peekedSheetController.view.frameX = [self overallWidth];
                                 vc.view.frame = goAwayFrame;
                             } else {
                                 vc.view.frame = goAwayFrame;
                             }
                             
                         }
                         completion:completeViewRemoval];
    } else {
        completeViewRemoval(YES);
    }
}

- (void)pushViewController:(UIViewController *)viewController inFrontOf:(UIViewController *)anchorViewController configuration:(SheetNavigationConfigBlock)configuration {
    [self pushViewController:viewController inFrontOf:anchorViewController maximumWidth:NO animated:YES configuration:configuration];
}

- (void)pushViewController:(UIViewController *)contentViewController
                 inFrontOf:(UIViewController *)anchorViewController
              maximumWidth:(BOOL)maxWidth
                  animated:(BOOL)animated {
    [self pushViewController:contentViewController
                   inFrontOf:anchorViewController
                maximumWidth:maxWidth
                    animated:animated
               configuration:^(SheetNavigationItem *item) {
               }];
}

- (void)pushViewController:(UIViewController *)contentViewController
                 inFrontOf:(UIViewController *)anchorViewController
              maximumWidth:(BOOL)maxWidth
                  animated:(BOOL)animated
             configuration:(void (^)(SheetNavigationItem *item))configuration {
    
    SheetController *newSheetController = [[SheetController alloc] initWithContentViewController:contentViewController maximumWidth:maxWidth];
    SheetController *parentLayerController = [self sheetControllerOf:anchorViewController];
    
    if (parentLayerController == nil) {
        /* view controller to push on not found */
        NSLog(@"WARNING: View controller to push in front of ('%@') not pushed (yet), pushing on top instead.",
              anchorViewController);
        [self pushViewController:contentViewController
                       inFrontOf:((SheetController *)[self.sheetViewControllers lastObject]).contentViewController
                    maximumWidth:maxWidth
                        animated:animated
                   configuration:configuration];
        return;
    }
    
    [self willAddSheet];
    
    SheetNavigationItem *navItem = newSheetController.sheetNavigationItem;
    
    if (contentViewController.parentViewController.parentViewController == self) {
        /* no animation if the new content view controller is already a child of self */
        [self popToViewController:anchorViewController animated:NO];
    } else {
        [self popToViewController:anchorViewController animated:YES];
    }
    
    navItem.title = nil;
    navItem.index = self.sheetViewControllers.count;
    int newCount = self.sheetViewControllers.count+1;
    
    [navItem setCount:newCount];
    [navItem setLayoutType:[SheetLayoutModel layoutTypeForSheetController:newSheetController]];
    
    if (configuration) {
        configuration(newSheetController.sheetNavigationItem);
    }
        
    if (newCount>=2) {
        SheetController *currentTop = [self.sheetViewControllers lastObject];
        [currentTop.sheetNavigationItem setCount:newCount];
        if (![currentTop.contentViewController isEqual:self.peekedSheetController] && currentTop.sheetNavigationItem.index != 0) {
            [self layoutSheetController:currentTop];
        }
    }
    
    [[SheetLayoutModel sharedInstance] updateNavItem:navItem];

    if (navItem.expandedPeekedSheet) {
        float expandedW = [[SheetLayoutModel sharedInstance] availableWidthForOffset:navItem.initialViewPosition.x];
        newSheetController.contentViewController.view.frameWidth = expandedW;
    }
    
    const CGFloat overallWidth = [self overallWidth];
    
    CGRect onscreenFrame = [self onscreenFrameForNavItem:navItem];
    CGRect offscreenFrame = [self offscreenFrameForNavItem:navItem withOnscreenFrame:onscreenFrame];
    
    newSheetController.view.frame = offscreenFrame;
    contentViewController.view.frameWidth = navItem.width;
    contentViewController.view.frameHeight = self.view.frameHeight;
    
    #if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_6_0
        CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
        float statusBarHeight = MIN(statusBarSize.width, statusBarSize.height);
        contentViewController.view.frameHeight = [SheetLayoutModel getScreenBoundsForCurrentOrientation].size.height - statusBarHeight;
    #else
        contentViewController.view.frameHeight = [SheetLayoutModel getScreenBoundsForCurrentOrientation].size.height;;
    #endif
    
    [newSheetController.view setNeedsLayout];
    [newSheetController.contentViewController.view setNeedsLayout];
    [self.sheetViewControllers addObject:newSheetController];
    if (navItem.isTier) {
        [[SheetLayoutModel sharedInstance] incrementTierCount];
    }
    
    [_historyManager addHistoryItemForSheetController:newSheetController];
    
    NSUInteger count = self.sheetViewControllers.count;
    
    [self.sheetViewControllers enumerateObjectsUsingBlock:^(SheetController *vc, NSUInteger idx, BOOL *stop){
        [vc.sheetNavigationItem setCount:count];
    }];
    
    [self addChildViewController:newSheetController];
    [self.view addSubview:newSheetController.view];
    
    BOOL isExpanded = navItem.expandedPeekedSheet;
    [parentLayerController prepareCoverViewForNewSheetWithCurrentAlpha:isExpanded];
    [parentLayerController animateInCoverView];
    
    void (^doNewFrameMove)() = ^() {
        CGFloat saved = [self savePlaceWanted:CGRectGetMinX(onscreenFrame)+navItem.width-overallWidth];
        CGFloat xPos = CGRectGetMinX(onscreenFrame) - saved;
        if (!newSheetController.maximumWidth) {
            xPos = overallWidth - navItem.width;
        }
        xPos = floorf(xPos);
        newSheetController.view.frame = CGRectMake(xPos,
                                                   CGRectGetMinY(onscreenFrame),
                                                   CGRectGetWidth(onscreenFrame),
                                                   CGRectGetHeight(onscreenFrame));
        newSheetController.sheetNavigationItem.currentViewPosition = newSheetController.view.frame.origin;
        
        if ([[SheetLayoutModel sharedInstance] shouldDropSheet]) {
            [self archiveStackedSheetContent];
        }
        
        if (self.peekedSheetController) {
            if (wantsDefaultPeekedSheet(contentViewController) && !isDefaultPeekedSheet(contentViewController)) {
                //NSLog(@"%i for overallwidth pos",__LINE__);
                
                CGRect offscreenPeekedFrame = [self frameForDefaultPeeked];
                offscreenPeekedFrame.origin.x = [self overallWidth];
                self.peekedSheetController.view.frame = offscreenPeekedFrame;
            }
        }
    };
    void (^newFrameMoveCompleted)(BOOL) = ^(BOOL finished) {
        if (finished) {
            [newSheetController didMoveToParentViewController:self];
            [self didAddSheet];
            
            if (wantsDefaultPeekedSheet(contentViewController)) {
                [UIView animateWithDuration:0.5
                                      delay:0
                                    options: SHEET_ADDING_ANIMATION_OPTION
                                 animations:^{
                                     [self.view addSubview:self.peekedSheetController.view];
                                     
                                     if ([self.peekedSheetController.contentViewController respondsToSelector:@selector(willPeekOnTopOfSheet:)]) {
                                         [(id<SheetStackPeeking>)self.peekedSheetController.contentViewController willPeekOnTopOfSheet:self.topSheetContentViewController];
                                     }

                                     if ([self peekedSheetReadyToPeek]) {
                                         //NSLog(@"%i: showing peeked at peeked position",__LINE__);
                                         self.peekedSheetController.view.frame = [self frameForDefaultPeeked];
                                         
                                     }
                                     
                                 } completion:nil];
            }
        }
    };
    float duration = animated ? [SheetLayoutModel animateOnDuration] : 0.0;
    [UIView animateWithDuration:duration
                          delay:0
                        options: SHEET_ADDING_ANIMATION_OPTION
                     animations:^{
                         doNewFrameMove();
                     }
                     completion:^(BOOL finished) {
                         newFrameMoveCompleted(finished);
                     }];
    
    //[self addDebugLineAtPoint:CGRectGetMidX(onscreenFrame)];
}

#pragma mark -

- (BOOL)peekedSheetReadyToPeek {
    BOOL readyToPeek = YES;
    if ([self.peekedSheetController.contentViewController respondsToSelector:@selector(readyToPeek)]) {
        readyToPeek = [(id<SheetStackPeeking>)self.peekedSheetController.contentViewController readyToPeek];
    }
    return readyToPeek;
}

- (NSUInteger)count {
    return _sheetViewControllers.count;
}

// if its index is 1 and there are two in list
- (SheetNavigationItem *)next:(SheetController *)controller {
    
    NSUInteger idx = [self.sheetViewControllers indexOfObject:controller];
    if (idx != NSNotFound) {
        NSUInteger count = self.sheetViewControllers.count;
        NSUInteger nextIdx = idx + 1;
        if ((nextIdx > count-1) || count == 0) {
            return nil;
        }
        
        SheetController *nextController = [self.sheetViewControllers objectAtIndex:nextIdx];
        return nextController.sheetNavigationItem;
    }
    return nil;
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
{
    if (self.userInteractionEnabled != userInteractionEnabled) {
        self->_userInteractionEnabled = userInteractionEnabled;
        
        if (self.userInteractionEnabled) {
            [self attachGestureRecognizers];
        } else {
            [self detachGestureRecognizers];
        }
    }
}

#pragma Public helpers

- (NSArray *)viewControllers {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[self.sheetViewControllers count]];
    [self.sheetViewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [result addObject:((SheetController*)obj).contentViewController];
    }];
    return [result copy];
}

- (UIViewController *)topSheetContentViewController {
    const SheetController *topSheetController = [self.sheetViewControllers lastObject];
    return topSheetController.contentViewController;
}

- (SheetController *)firstStackedOnSheetController {
    if (self.count < 2) {
        return nil;
    }
    
    return [self.sheetViewControllers objectAtIndex:self.count-2];
}

- (SheetController *)topSheetController {
    return [self.sheetViewControllers lastObject];
}

- (SheetController *)sheetControllerAtIndex:(NSUInteger)index {
    return [_sheetViewControllers objectAtIndex:index];
}

- (SheetNavigationItem *)sheetNavigationItemForSheet:(UIViewController *)vc {
    SheetNavigationItem *navItem = [[self sheetControllerOf:vc] sheetNavigationItem];
    if (!navItem) {
        if ([vc isEqual:self.peekedSheetController.contentViewController]) {
            navItem = self.peekedSheetController.sheetNavigationItem;
        }
    }
    return navItem;
}

- (UIViewController *)sheetAtIndex:(int)index {
    if (index > _sheetViewControllers.count-1) {
        return nil;
    }
    return [[_sheetViewControllers objectAtIndex:index] contentViewController];
}

- (BOOL)sheetIsAtBottom:(UIViewController *)sheet {
    return [[[self.sheetViewControllers objectAtIndex:0] contentViewController] isEqual:sheet];
}

#pragma mark - Internal methods

- (void)removeSheetFromHistory:(UIViewController *)vc {
    if (self.count == 1) {
        return;
    }
    
    [self restoreFirstEmptySheetContentUnder:vc];
    [self.sheetViewControllers removeObject:vc];
    
    [_historyManager popHistoryItem];
    
    NSUInteger count = self.sheetViewControllers.count;
    [self.sheetViewControllers enumerateObjectsUsingBlock:^(SheetController *vc,NSUInteger idx,BOOL *stop){
        [vc.sheetNavigationItem setCount:count];
    }];
    
    if (vc.sheetNavigationItem.isTier) {
        [[SheetLayoutModel sharedInstance] decrementTierCount];
    }
}

- (void)removeSheetFromViewHeirarchy:(UIViewController *)vc {
    [vc willMoveToParentViewController:nil];
    [vc.view removeFromSuperview];
    [vc removeFromParentViewController];
    [self didRemoveSheet];
}

- (UIViewController *)sheetContentAtIndex:(NSUInteger)index {
    SheetController *sheetController = [_sheetViewControllers objectAtIndex:index];
    return sheetController.contentViewController;
}

- (SheetController *)sheetControllerOf:(UIViewController *)vc
{
    for (SheetController *lvc in self.sheetViewControllers) {
        if (lvc.contentViewController == vc) {
            return lvc;
        }
    }
    return nil;
}

- (CGFloat)savePlaceWanted:(CGFloat)pointsWanted; {
    CGFloat xTranslation = 0;
    if (pointsWanted <= 0) {
        return 0;
    }
    
    for (SheetController *vc in self.sheetViewControllers) {
        const CGFloat initX = vc.sheetNavigationItem.initialViewPosition.x;
        const CGFloat currentX = vc.sheetNavigationItem.currentViewPosition.x;
        
        if (initX < currentX + xTranslation) {
            xTranslation += initX - (currentX + xTranslation);
        }
        
        if (abs(xTranslation) >= pointsWanted) {
            break;
        }
    }
    
    for (SheetController *vc in self.sheetViewControllers) {
        if (vc == [self.sheetViewControllers lastObject]) {
            break;
        }
        [self viewController:vc xTranslation:xTranslation bounded:YES];
    }
    return abs(xTranslation);
}

- (BOOL)areViewControllersMaximallyCompressed
{
    BOOL maximalCompression = YES;
    
    for (SheetController *lvc in self.sheetViewControllers) {
        if (lvc.sheetNavigationItem.currentViewPosition.x > lvc.sheetNavigationItem.initialViewPosition.x) {
            maximalCompression = NO;
        }
    }
    
    return maximalCompression;
}

- (void)addDebugLineAtPoint:(float)point {
    UIView *line = [self.view viewWithTag:800];
    if (!line) {
        line = [[UIView alloc] initWithFrame:CGRectZero];
        line.backgroundColor = [UIColor redColor];
    }
    line.frame = CGRectMake(point, 0.0, 1.0, [self overallHeight]);
    line.tag = 800;
    
    [self.view addSubview:line];
}

- (NSMutableDictionary *)dropSheetControllerContent:(SheetController *)vc {
    UIViewController *contentViewController = vc.contentViewController;
    
    // keep it fresh with current position, etc
    NSMutableDictionary *archiveDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:vc.sheetNavigationItem,SheetNavigationItemKey,nil];
    if ([contentViewController respondsToSelector:@selector(encodeRestorableState)]) {
        NSMutableDictionary *archiveDictForContent = [contentViewController performSelector:@selector(encodeRestorableState)];
        [archiveDict addEntriesFromDictionary:archiveDictForContent];
    }
    
    if ([contentViewController respondsToSelector:@selector(sheetWillBeDropped)]) {
        [contentViewController performSelector:@selector(sheetWillBeDropped)];
    }
    
    [vc dumpContentViewController];
    
    if ([contentViewController respondsToSelector:@selector(sheetWillBeDropped)]) {
        [contentViewController performSelector:@selector(sheetDidGetDropped)];
    }
    
    return archiveDict;
}

- (BOOL)viewControllerIsPeeked:(UIViewController *)viewController {
    BOOL peeked = NO;
    if ([self.peekedSheetController isEqual:viewController]) {
        peeked = YES;
    }
    return peeked;
}

- (void)forwardUnstackingPercentage:(CGFloat)percentComplete {
    // only top two sheets need to update their ui's during gestures and popping
    [(id<SheetStackPage>)self.firstStackedController sheetBeingUnstacked:percentComplete];
    
    const NSInteger startVcIdx = [self.sheetViewControllers count]-1;
    SheetController *startVc = [self.sheetViewControllers objectAtIndex:startVcIdx];
    [startVc setPercentDragged:percentComplete];
    
    if ([self.delegate respondsToSelector:@selector(sheetNavigationController:movingViewController:percentMoved:)]) {
        [self.delegate sheetNavigationController:self movingViewController:self.firstTouchedController percentMoved:percentComplete];
    }
}

- (BOOL)shouldAutomaticallyForwardRotationMethods  {
    return YES;
}

- (BOOL) shouldAutomaticallyForwardAppearanceMethods {
    return YES;
}

- (void)removeViewControllerFromHeirarchy:(UIViewController *)viewController {
    [viewController willMoveToParentViewController:viewController.parentViewController];
    [viewController.view removeFromSuperview];
    [viewController removeFromParentViewController];
}

#pragma mark Gesture/animation helpers

- (void)moveToSnappingPointsWithGestureRecognizer:(UIPanGestureRecognizer *)g
{
    const CGFloat velocity = [g velocityInView:self.view].x;
    SnappingPointsMethod method;
    
    if (abs(velocity) > [self snappingVelocityThreshold]) {
        if (velocity > 0) {
            method = SnappingPointsMethodExpand;
        } else {
            method = SnappingPointsMethodCompact;
        }
    } else {
        method = SnappingPointsMethodNearest;
    }
    [self viewControllersToSnappingPointsMethod:method velocity:velocity];
}

/* Applies snapping rules to top two sheets */
- (void)viewControllersToSnappingPointsMethod:(SnappingPointsMethod)method velocity:(CGFloat)velocity
{
    __block SheetController *last = nil;
    __block CGFloat xTranslation = 0;
    
    [self.sheetViewControllers enumerateObjectsUsingBlock:^(SheetController *vc, NSUInteger index, BOOL *stop){
        SheetNavigationItem *navItem = vc.sheetNavigationItem;
        
        BOOL isNotDraggable = ![self sheetShouldPan:vc.contentViewController];
        BOOL isNonInteractive = [self isNonInteractiveSheet:vc.contentViewController];
        BOOL isNotVisible = navItem.offset > 2;
        BOOL isStackedFullscreen = (navItem.layoutType == kSheetLayoutFullScreen || navItem.isFullscreened) && navItem.offset > 1;
        if (isNotDraggable || isNonInteractive || isNotVisible || isStackedFullscreen) {
            return;
        }
        
        if (last == nil) {
            last = [self sheetControllerAtIndex:index-1];
            NSAssert(last != nil, @"we should have a last nav item");
            //NSAssert(last.sheetNavigationItem.offset == navItem.offset+1, @"should be one back");
        }
        
        SheetNavigationItem *lastNavItem = last.sheetNavigationItem;
        
        const CGPoint myPos = navItem.currentViewPosition;
        const CGPoint myInitPos = navItem.initialViewPosition;
        
        const CGFloat curDiff = myPos.x - lastNavItem.currentViewPosition.x;
        if (curDiff == kSheetNextItemDefaultDistance && navItem.offset == 2) {
            return;
        }
        const CGFloat initDiff = myInitPos.x - lastNavItem.initialViewPosition.x;
        const CGFloat maxDiff = CGRectGetWidth(last.view.frame);
        const CGFloat overallWidth = [self overallWidth];
        
        BOOL(^floatNotEqual)(float,float) = ^BOOL(float l,float r){
            return !(abs(l-r) < 0.1);
        };
        
        void(^doRightSnapping)(void) = ^{
            
            if (navItem.offset == 1) {
                
                xTranslation = overallWidth - myPos.x;
                if (vc.sheetNavigationItem.expandedPeekedSheet) {
                    xTranslation -= [self getPeekedWidth:vc.contentViewController];
                }
                [self willRemoveSheet];
                [self forwardUnstackingPercentage:1.0];
                
            } else if (navItem.offset == 2) {
                xTranslation = (overallWidth - navItem.width) - curDiff;
            }
        };
        
        void(^doLeftSnapping)(void) = ^{
            xTranslation = initDiff - curDiff;
            
            [self forwardUnstackingPercentage:0.0];
        };
        
        BOOL hasMoved = floatNotEqual(curDiff, initDiff);
        //NSLog(@"has moved: %s",hasMoved ? "yes" : "no");
        BOOL hasNotExceededWidthOfSheetBelow = floatNotEqual(curDiff, maxDiff);
        //NSLog(@"has not exceeded width of sheet below: %s",hasNotExceededWidthOfSheetBelow ? "yes" : "no");
        
        BOOL movedPastRightEdgeOfSheetBelow = (curDiff - initDiff) > (maxDiff - curDiff);
        BOOL movedPastHalfOwnWidth = (curDiff - initDiff) > (navItem.width*0.5);
        BOOL rightSnappingEdgeNearest = movedPastRightEdgeOfSheetBelow && movedPastHalfOwnWidth;// || maxDiff > overallWidth;
        //NSLog(@"snap right: %s",rightSnappingEdgeNearest ? "yes" : "no");
        
        if (xTranslation == 0 && hasMoved && hasNotExceededWidthOfSheetBelow) {
            // sheet has been dragged somewhere IN BETWEEN initial position
            // and the right edge of the underlying sheet
            
            switch (method) {
                case SnappingPointsMethodNearest: {
                    if (rightSnappingEdgeNearest || _willDismissTopSheet) {
                        /* right snapping point is nearest */
                        /* and right snapping point is >= to nav width */
                        doRightSnapping();
                    } else {
                        /* left snapping point is nearest */
                        if (!_willDismissTopSheet) {
                            doLeftSnapping();
                        }
                    }
                    break;
                }
                case SnappingPointsMethodCompact: {
                    xTranslation = initDiff - curDiff;
                    break;
                }
                case SnappingPointsMethodExpand: {
                    doRightSnapping();
                    break;
                }
                default: {
                    if (_willDismissTopSheet) {
                        doRightSnapping();
                    }
                }
            }
        } else if (_willDismissTopSheet) {
            doRightSnapping();
        } else {
            doLeftSnapping();
        }
        
        BOOL didMoveOutOfBounds = [self viewController:vc xTranslation:xTranslation bounded:YES];
        if (didMoveOutOfBounds) {
            [self willRemoveSheet];
        }
        last = vc;
    }];
}

- (void)moveViewControllersXTranslation:(CGFloat)xTranslationGesture velocity:(float)velocity
{
    // ref to sheet above, if any
    SheetNavigationItem *parentNavItem = nil;
    CGPoint parentOldPos = CGPointZero;
    float threshold = [self snappingVelocityThreshold];
    //NSLog(@"xTranslationGesture: %f",xTranslationGesture);
    
    BOOL descendentOfTouched = NO;
    SheetController *rootVC = [self.sheetViewControllers objectAtIndex:0];
    //BOOL hasPeekedViewControllers = self.peekedSheetController ? YES : NO;
    
    for (SheetController *me in [self.sheetViewControllers reverseObjectEnumerator]) {
        if (rootVC == me) {
            break;
        }
        
        SheetNavigationItem *meNavItem = me.sheetNavigationItem;
        
        BOOL shouldPan = [self sheetShouldPan:me.contentViewController];
        BOOL stackedFullscreen = (meNavItem.layoutType == kSheetLayoutFullScreen || meNavItem.isFullscreened) && meNavItem.offset > 1;
        if (!shouldPan || stackedFullscreen) {
            continue;
        }
        
        const CGPoint myPos = meNavItem.currentViewPosition;
        const CGPoint myInitPos = meNavItem.initialViewPosition;
        CGPoint myNewPos = myPos;
        const CGPoint myOldPos = myPos;
        
        const CGPoint parentPos = parentNavItem.currentViewPosition;
        const CGPoint parentInitPos = parentNavItem.initialViewPosition;
        
        const CGFloat minDiff = parentInitPos.x - myInitPos.x;
        CGFloat myWidth = meNavItem.width;
        if (myWidth <= minDiff) {
            myWidth = minDiff;
        }
        
        CGFloat xTranslation = 0;
        
        if (parentNavItem == nil || !descendentOfTouched) {
            xTranslation = xTranslationGesture;
            
        } else {
            
            CGFloat newX = myPos.x;
            
            if (parentOldPos.x >= myPos.x + myWidth || parentPos.x >= myPos.x + myWidth) {
                /* if snapped to parent's snapping edge, move with parent */
                newX = parentPos.x - myWidth;
            }
            
            if (parentPos.x - myNewPos.x <= minDiff) {
                /* at least minDiff difference between parent and me */
                newX = parentPos.x - minDiff;
            }
            
            xTranslation = newX - myPos.x;
        }
        
        
        if (meNavItem.offset == 1) {
            
            float initPosX = meNavItem.initialViewPosition.x;
            BOOL movedPastHalfOwnWidth = (xTranslation+meNavItem.currentViewPosition.x) > (meNavItem.width*0.5) + initPosX;
            if (movedPastHalfOwnWidth) {
                _willDismissTopSheet = YES;
            } else if (abs(velocity) > threshold) {
                if (velocity > 0) {
                    _willDismissTopSheet = YES;
                }
            } else {
                _willDismissTopSheet = NO;
            }
        }
        
        const BOOL isTouchedView = !descendentOfTouched && [self.firstTouchedView isDescendantOfView:me.view];
        
        if (self.outOfBoundsViewController == nil ||
            self.outOfBoundsViewController == me ||
            xTranslationGesture < 0) {
            const BOOL boundedMove = !(isTouchedView && [self areViewControllersMaximallyCompressed]);
            
            /*
             * IF no view controller is out of bounds (too far on the left)
             * OR if me who is out of bounds
             * OR the translation goes to the left again
             * THEN: apply the translation
             */
            const BOOL outOfBoundsMove = [self viewController:me xTranslation:xTranslation bounded:boundedMove];
            
            if (outOfBoundsMove) {
                /* this move was out of bounds */
                self.outOfBoundsViewController = me;
                
            } else if(!outOfBoundsMove && self.outOfBoundsViewController == me) {
                /* I have been moved out of bounds some time ago but now I'm back in the bounds :-), so:
                 * - no one can be out of bounds now
                 * - I have to be reset to my initial position
                 * - discard the rest of the translation
                 */
                
                self.outOfBoundsViewController = nil;
                [SheetNavigationController viewControllerToInitialPosition:me];
                break; /* this discards the rest of the translation (i.e. stops the loop) */
            }
        }
        
        if (isTouchedView) {
            NSAssert(!descendentOfTouched, @"cannot be descendent of touched AND touched view");
            descendentOfTouched = YES;
        }
        
        /* initialize next iteration */
        parentNavItem = meNavItem;
        
        parentOldPos = myOldPos;
    }
}

+ (void)viewControllerToInitialPosition:(SheetController *)vc
{
    const CGPoint initPos = vc.sheetNavigationItem.initialViewPosition;
    CGRect f = vc.view.frame;
    f.origin = initPos;
    vc.sheetNavigationItem.currentViewPosition = initPos;
    vc.view.frame = f;
}

- (BOOL)viewController:(SheetController *)vc xTranslation:(CGFloat)origXTranslation bounded:(BOOL)bounded
{
    BOOL didMoveOutOfBounds = NO;
    const SheetNavigationItem *navItem = vc.sheetNavigationItem;
    const CGPoint initPos = navItem.initialViewPosition;
    const CGFloat navViewWidth = vc.sheetNavigationController.view.bounds.size.width;
    
    CGFloat peekedWidth = 0.0;
    if (navItem.expandedPeekedSheet) {
        peekedWidth = navItem.peekedWidth;
    }
    
    if (bounded) {
        /* apply translation to navigation item position first and then apply to view */
        CGRect f = vc.view.frame;
        f.origin = navItem.currentViewPosition;
        f.origin.x += origXTranslation;
        
        if (f.origin.x <= initPos.x) {
            f.origin.x = initPos.x;
        }
        
        if (peekedWidth > 0.0 && navItem.offset == 1) {
            if (f.origin.x >= navViewWidth - peekedWidth) {
                f.origin.x = navViewWidth - peekedWidth;
            }
        }
        
        if (navItem.width+initPos.x > [self overallWidth] && navItem.offset == 2 && _willDismissTopSheet) {
            f.origin.x = [self overallWidth] - navItem.width;
        }
        
        vc.view.frame = f;
        navItem.currentViewPosition = f.origin;
        
    } else {
        CGRect f = vc.view.frame;
        CGFloat xTranslation = 0.0;
        
        if (f.origin.x < initPos.x || origXTranslation < 0) {
            /* if view already left from left bound and still moving left, half moving speed */
            xTranslation = 0.0;
        } else {
            xTranslation = origXTranslation;
        }
        
        f.origin.x += xTranslation;
        
        if (peekedWidth > 0.0) {
            if (f.origin.x >= navViewWidth - peekedWidth) {
                f.origin.x = navViewWidth - peekedWidth;
            }
        }
        
        /* apply translation to frame first */
        if (f.origin.x <= initPos.x) {
            didMoveOutOfBounds = YES;
            f.origin.x = initPos.x;
        }
        
        navItem.currentViewPosition = f.origin;
        vc.view.frame = f;
    }
    
    return didMoveOutOfBounds;
}

#pragma mark Peeked view controllers

- (void)expandPeekedSheet:(BOOL)animated {
    SheetController *peekedSheetController = self.peekedSheetController;
    
    if ([peekedSheetController respondsToSelector:@selector(isPeeking:onTopOfSheet:)]) {
        [(id<SheetStackPeeking>)peekedSheetController isPeeking:NO onTopOfSheet:self.topSheetContentViewController];
    }
    
    SheetNavigationItem *oldNavItem = peekedSheetController.sheetNavigationItem;

    if ([self.delegate respondsToSelector:@selector(sheetNavigationController:movingViewController:percentMoved:)]) {
        [self.delegate sheetNavigationController:self movingViewController:self.firstTouchedController percentMoved:1.0];
    }
    
    [peekedSheetController removeFromParentViewController];
    [peekedSheetController.view removeFromSuperview];
    [peekedSheetController willMoveToParentViewController:nil];
    
    UIViewController *peekedVC = peekedSheetController.contentViewController;
    peekedVC.view.frameX = 0.0;
    peekedVC.view.frameY = 0.0;
    
    [self.peekedSheetController.view removeGestureRecognizer:self.peekedPanGR];
    [self.peekedPanGR removeTarget:self action:NULL];
    self.peekedPanGR = nil;
    
    [self pushViewController:peekedVC inFrontOf:self.topSheetContentViewController maximumWidth:peekedFrame.size.width animated:animated configuration:^(SheetNavigationItem *navItem){
        navItem.isPeekedSheet = YES;
        navItem.expandedPeekedSheet = YES;
        navItem.peekedWidth = oldNavItem.peekedWidth;
        navItem.offsetY = oldNavItem.offsetY;
    }];
}

- (BOOL)shouldShowDefaultPeeked {
    BOOL shouldShow = YES;
    if ([self.topSheetContentViewController respondsToSelector:@selector(showPeeked)]) {
        shouldShow = [(id<SheetStackPage>)self.topSheetContentViewController showPeeked];
    }
    return shouldShow;
}

- (BOOL)showsDefaultPeekedViewController:(UIViewController *)vc {
    if ([vc respondsToSelector:@selector(showsDefaultPeekedViewController)]) {
        return [(id<SheetStackPage>)vc showsDefaultPeekedViewController];
    }
    return NO;
}

- (void)addDefaultPeekedViewController {
    UIViewController *topSheet = self.topSheetContentViewController;
    if ([self.peekedSheetController respondsToSelector:@selector(isPeeking:onTopOfSheet:)]) {
        [(id<SheetStackPeeking>)self.peekedSheetController isPeeking:YES onTopOfSheet:topSheet];
    }
    
    [self.peekedSheetController willMoveToParentViewController:self];
    [self.peekedSheetController.view removeFromSuperview];
    [self.peekedSheetController removeFromParentViewController];
    [self addChildViewController:self.peekedSheetController];

    if ([self.peekedSheetController.contentViewController respondsToSelector:@selector(willPeekOnTopOfSheet:)]) {
        [(id<SheetStackPeeking>)self.peekedSheetController.contentViewController willPeekOnTopOfSheet:topSheet];
    }

    [self.view addSubview:self.peekedSheetController.view];
    
    [self layoutPeekedViewControllers];
}

- (void)peekDefaultViewController {
    [self peekViewController:self.peekedSheetController animated:YES];
}

- (void)peekViewController:(SheetController *)sheetController animated:(BOOL)animated {
    
    if ([sheetController respondsToSelector:@selector(isPeeking:onTopOfSheet:)]) {
        [(id<SheetStackPeeking>)sheetController isPeeking:YES onTopOfSheet:self.topSheetContentViewController];
    }
    
    [sheetController willMoveToParentViewController:self];
    [sheetController.view removeFromSuperview];
    [sheetController removeFromParentViewController];
    [self addChildViewController:sheetController];
    
    CGRect onscreenFrame = [self peekedFrameForSheetController:sheetController];
    
    [self.view addSubview:sheetController.view];
    
    void(^doNewFrameMove)(void) = ^{
        sheetController.view.frame = onscreenFrame;
    };
    void(^frameMoveComplete)(void) = ^{
        [sheetController didMoveToParentViewController:self];
        [(id<SheetStackPage>)[self topSheetController] sheetDidGetStacked];
        [sheetController.view setNeedsLayout];
        
        if (sheetController.sheetNavigationItem) {
            sheetController.sheetNavigationItem.expandedPeekedSheet = NO;
        } 
    };
    
    if (animated) {
        sheetController.view.frameX = [self overallWidth];
        [UIView animateWithDuration:0.5
                              delay:0
                            options: SHEET_ADDING_ANIMATION_OPTION
                         animations:^{
                             doNewFrameMove();
                         }
                         completion:^(BOOL finished) {
                             frameMoveComplete();
                         }];
        
    } else {
        doNewFrameMove();
        frameMoveComplete();
    }
}

- (UIViewController *)topPeekedSheet {
    return [self.peekedViewControllers lastObject];
}

- (CGFloat)getPeekedWidth:(UIViewController *)viewController {
    CGFloat width = kSheetDefaultPeekedWidth;
    if ([viewController respondsToSelector:@selector(peekedWidth)]) {
        width = [(id<SheetStackPeeking>)viewController peekedWidth];
    }
    return width;
}

#pragma mark - UIGestureRecognizer delegate interface

- (BOOL)peekedSheetTouched:(UIView *)touchedView {
    SheetController *topPeekedSheet = self.peekedSheetController;
    BOOL controllerContentIsPeekedSheet = [touchedView isDescendantOfView:topPeekedSheet.view];
    BOOL isExpandedPeekedSheet = [[self topSheetController] sheetNavigationItem].expandedPeekedSheet;
    return controllerContentIsPeekedSheet && !isExpandedPeekedSheet;
}

- (void)handleTapGesture:(UIPanGestureRecognizer *)gestureRecognizer {
    
    switch (gestureRecognizer.state) {
            
        case UIGestureRecognizerStateEnded: {

            UIView *touchedView = [gestureRecognizer.view hitTest:[gestureRecognizer locationInView:gestureRecognizer.view] withEvent:nil];
            self.firstTouchedView = touchedView;
            
            CGPoint pointInView = [gestureRecognizer locationInView:gestureRecognizer.view];
            UIView *navButtonView = [[self topSheetController] leftNavButtonItem];
            CGPoint correctedPoint = [[self topSheetController].view convertPoint:pointInView fromView:self.view];
            BOOL touchInsideNavButton = [navButtonView pointInside:correctedPoint withEvent:nil];
            if (touchInsideNavButton) {
                
                [gestureRecognizer setEnabled:NO];
                [gestureRecognizer setEnabled:YES];
                    
                if ([navButtonView isKindOfClass:[UIButton class]]) {
                    // if outside bounds of sheet controller view
                    // call the button's touch up inside handler
                    [(UIButton *)navButtonView sendActionsForControlEvents: UIControlEventTouchUpInside];
                }
                
                break;
            }
            
            if ([self peekedSheetTouched:touchedView]){
                self.firstStackedController = [self firstStackedOnSheetController];
                if (self.firstStackedController == nil) {
                    self.firstStackedController = [self.sheetViewControllers objectAtIndex:0];
                }
                [self.firstStackedController prepareCoverViewForNewSheetWithCurrentAlpha:NO];
                [self.firstStackedController animateInCoverView];
                [self expandPeekedSheet:YES];
                break;
            } else {
                for (SheetController *controller in [self.sheetViewControllers reverseObjectEnumerator]) {
                    
                    if ([touchedView isDescendantOfView:controller.view]) {
                        BOOL controllerContentIsTopSheet = [controller.contentViewController isEqual:[self topSheetContentViewController]];
                        //BOOL isSubviewOfRoot = controller.sheetNavigationItem.index == 0 ? YES : NO;
                        if (!controllerContentIsTopSheet) {// && !isSubviewOfRoot) {
                            BOOL isDroppedSheet = !controller.contentViewController;
                            if (isDroppedSheet) {
                                [self restoreSheetContentAtIndex:[self.sheetViewControllers indexOfObject:controller]];
                            }
                            
                            self.firstTouchedController = controller.contentViewController;
                            break;
                        } 
                    }
                }
            }
            
            if (self.firstTouchedController) {
                
                if ([self.delegate respondsToSelector:@selector(sheetNavigationController:willMoveController:)]) {
                    [self.delegate sheetNavigationController:self willMoveController:self.firstTouchedController];
                }
                if (![[self.sheetViewControllers lastObject] isEqual:[self sheetControllerOf:self.firstTouchedController]]) {
                    [self popViewControllerAnimated:YES];
                }
            }
            
            self.firstTouchedView = nil;
            self.firstTouchedController = nil;
            
            break;
        }
            
        default:
            break;
    }
}

- (void)handlePeekedPanGesture:(UIPanGestureRecognizer *)gestureRecognizer {
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStatePossible: {
        }
            break;
            
        case UIGestureRecognizerStateBegan: {
            //NSLog(@"p dragging begun");
            
            self.firstStackedController = [self topSheetController];
            if (self.firstStackedController == nil) {
                self.firstStackedController = [self.sheetViewControllers objectAtIndex:0];
            }
            
            [self.firstStackedController performSelector:@selector(sheetWillBeStacked)];
            
            [(SheetController *)self.firstStackedController prepareCoverViewForNewSheetWithCurrentAlpha:NO];
            
            if ([self.delegate respondsToSelector:@selector(sheetNavigationController:willMoveController:)]) {
                [self.delegate sheetNavigationController:self willMoveController:self.firstTouchedController];
            }
            
            peekedFrame = [self peekedFrameForSheetController:self.peekedSheetController];
            
        }
            break;
            
        case UIGestureRecognizerStateChanged: {
            //NSLog(@"p dragging changed");
            float initPosX = peekedFrame.origin.x;
            
            CGFloat xTranslation = [gestureRecognizer translationInView:gestureRecognizer.view].x;
            CGFloat velocity = [gestureRecognizer velocityInView:gestureRecognizer.view].x;
            
            const CGPoint myPos = gestureRecognizer.view.frame.origin;
            
            BOOL movedPastHalfOwnWidth = (xTranslation+myPos.x) < initPosX - (peekedFrame.size.width*0.5);
            const BOOL boundedMove  = (xTranslation+myPos.x) > initPosX || (xTranslation+myPos.x) < 0.0;
            
            //NSLog(@"x Translation: %f",xTranslation);
            //NSLog(@"moved Past Half Own Width: %s",movedPastHalfOwnWidth?"YES":"NO");
            //NSLog(@"bounded Move: %s",boundedMove?"YES":"NO");
            CGFloat rightEdge = [self overallWidth] - 24.0 - 50.0;
            float currPos = initPosX - myPos.x;
            CGFloat percComplete = (currPos/rightEdge);
            
            // note: not using [self forwardUnstackingPercentage:percComplete]
            // intentionally because peeked sheet is different! 
            [(id<SheetStackPage>)self.firstStackedController sheetBeingUnstacked:1.0-percComplete];
            if ([self.delegate respondsToSelector:@selector(sheetNavigationController:movingViewController:percentMoved:)]) {
                [self.delegate sheetNavigationController:self movingViewController:self.firstTouchedController percentMoved:percComplete];
            }
            
            if (!boundedMove && percComplete < 1.0) {
                self.peekedSheetController.view.frameX += xTranslation;
            }
            //NSLog(@"velocity %f",velocity);
            if (movedPastHalfOwnWidth) {
                _willExpandedPeeked = YES;
            } else if (abs(velocity) > [self snappingVelocityThreshold]) {
                _willExpandedPeeked = YES;
            } else {
                _willExpandedPeeked = NO;
            }
            
            [gestureRecognizer setTranslation:CGPointZero inView:gestureRecognizer.view];
        }
            break;
            
        case UIGestureRecognizerStateEnded: {
            const CGFloat velocity = [gestureRecognizer velocityInView:self.view].x;
            
            if (_willExpandedPeeked) {
                [self.firstStackedController prepareCoverViewForNewSheetWithCurrentAlpha:YES];
                [self.firstStackedController animateInCoverView];
                
                if ([self.delegate respondsToSelector:@selector(sheetNavigationController:movingViewController:percentMoved:)]) {
                    [self.delegate sheetNavigationController:self movingViewController:self.firstTouchedController percentMoved:1.0];
                }
            } else {
                if ([self.delegate respondsToSelector:@selector(sheetNavigationController:movingViewController:percentMoved:)]) {
                    [self.delegate sheetNavigationController:self movingViewController:self.firstTouchedController percentMoved:0.0];
                }
            }
            
            if (_willExpandedPeeked && velocity > [self snappingVelocityThreshold]) {
                [self expandPeekedSheet:YES];
                _willExpandedPeeked = NO;
                return;
            } else {
                
                NSTimeInterval defaultSpeed = [SheetLayoutModel animateOffDuration];
                NSTimeInterval duration = defaultSpeed;
                
                if (abs(velocity) != 0) {
                    /* match speed of fast swipe */
                    CGFloat currentX = abs(self.peekedSheetController.view.frame.origin.x);
                    CGFloat pointsX = [self overallWidth] - currentX;
                    duration = pointsX / abs(velocity);
                    duration *= 1.2; // was too fast
                }
                /* but not too slow either */
                if (duration > defaultSpeed) {
                    duration = defaultSpeed;
                }
                
                CGPoint destinationPoint = _willExpandedPeeked ? CGPointMake(0.0, 0.0) : peekedFrame.origin;
                if (_willExpandedPeeked) {
                    destinationPoint.x += self.topSheetContentViewController.sheetNavigationItem.nextItemDistance;
                }
                
                [UIView animateWithDuration:duration
                                 animations:^{
                                     UIView *view = self.peekedSheetController.view;
                                     view.frameX = destinationPoint.x;
                                 }
                                 completion:^(BOOL finished){
                                     if (_willExpandedPeeked && finished) {
                                         [self expandPeekedSheet:NO];
                                         _willExpandedPeeked = NO;
                                     } else {
                                         [self.firstStackedController performSelector:@selector(sheetDidGetUnstacked)];
                                     }
                                     self.firstStackedController = nil;
                                 }];
            }
        }
            break;
        
        default:
            break;
    }
    
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer {
    
    if (self.count <= 1) return;
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStatePossible: {
            //NSLog(@"UIGestureRecognizerStatePossible");
            break;
        }
        case UIGestureRecognizerStateCancelled: {
            //NSLog(@"UIGestureRecognizerStateCancelled");
            break;
        }
            
        case UIGestureRecognizerStateBegan: {
            //NSLog(@"UIGestureRecognizerStateBegan");
            
            UIView *touchedView = [gestureRecognizer.view hitTest:[gestureRecognizer locationInView:gestureRecognizer.view] withEvent:nil];
            self.firstTouchedView = touchedView;
            
            if ([self peekedSheetTouched:touchedView]) {
                self.firstTouchedController = self.peekedSheetController;
            } else {
                
                for (SheetController *controller in [self.sheetViewControllers reverseObjectEnumerator]) {
                    if ([touchedView isDescendantOfView:controller.view]) {
                        
                        BOOL shouldPan = [self sheetShouldPan:controller.contentViewController];
                        BOOL isGutter = [self isGutter:controller.contentViewController];
                        if (!shouldPan && !isGutter) {
                            // kill the gesture
                            [gestureRecognizer setEnabled:NO];
                            [gestureRecognizer setEnabled:YES];
                        } else if (isGutter) {
                            self.firstTouchedController = [self topSheetContentViewController];
                        }
                        
                        break;
                    }
                }
            }
            
            if ([self.delegate respondsToSelector:@selector(sheetNavigationController:willMoveController:)]) {
                [self.delegate sheetNavigationController:self willMoveController:self.firstTouchedController];
            }
            
            SheetController *firstStacked =  [self firstStackedOnSheetController];
            [(id<SheetStackPage>)firstStacked performSelector:@selector(sheetWillBeUnstacked)];
            [self restoreFirstEmptySheetContentUnder:firstStacked];
            if ([firstStacked.contentViewController respondsToSelector:@selector(sheetNavigationControllerWillPanSheet)]) {
                [(id<SheetStackPage>)firstStacked.contentViewController sheetNavigationControllerWillPanSheet];
            }
            self.firstStackedController = firstStacked;
            self.firstStackedController.isVisible = YES;
            [self layoutSheetController:firstStacked];
            
            _willPopToRootSheet = gestureRecognizer.numberOfTouches == 2;
            
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            
            if (_willPopToRootSheet) {
                return;
            }
            
            const CGFloat parentWidth = [self overallWidth];
            const CGFloat peekedWidth = [self getPeekedWidth:self.topSheetContentViewController];
            
            const NSInteger startVcIdx = [self.sheetViewControllers count]-1;
            const SheetController *startVc = [self.sheetViewControllers objectAtIndex:startVcIdx];
            
            CGFloat xTranslation = [gestureRecognizer translationInView:self.view].x;
            [self moveViewControllersXTranslation:xTranslation velocity:[gestureRecognizer velocityInView:self.view].x];
            
            const SheetNavigationItem *navItem = startVc.sheetNavigationItem;
            CGFloat percComplete;
            if (navItem.offset == 1) {
                CGFloat initX = navItem.initialViewPosition.x;
                CGFloat rightEdge = (parentWidth-peekedWidth)-initX;
                float currPos = startVc.view.frameX-initX;
                percComplete = currPos/rightEdge;
                [self forwardUnstackingPercentage:percComplete];
            }
            
            if ([self.firstStackedController.contentViewController respondsToSelector:@selector(sheetNavigationControllerPanningSheet)]) {
                [(id<SheetStackPage>)self.firstStackedController.contentViewController sheetNavigationControllerPanningSheet];
            }
            
            [gestureRecognizer setTranslation:CGPointZero inView:startVc.view];
            
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            
            const CGFloat velocity = [gestureRecognizer velocityInView:self.view].x;
            //NSLog(@"willPopToRootSheet: %s",willPopToRootSheet?"yes":"no");
            if (_willPopToRootSheet && velocity > [self snappingVelocityThreshold]) {
                //NSLog(@"%i -----  %s",gestureRecognizer.numberOfTouches,willPopToRootSheet ? "yes" : "no");
                int tierCount = [[SheetLayoutModel sharedInstance] tierCount];
                SheetController *vc = self.sheetViewControllers[tierCount-1];
                [self popToViewController:vc animated:YES];
                _willPopToRootSheet = NO;
                return;
            }
            
            
            NSTimeInterval defaultSpeed = [SheetLayoutModel animateOffDuration];
            NSTimeInterval duration = defaultSpeed;
            
            if (abs(velocity) != 0) {
                /* match speed of fast swipe */
                CGFloat currentX = abs([self topSheetController].view.frame.origin.x);
                CGFloat pointsX = [self overallWidth] - currentX;
                duration = pointsX / velocity;
                
                //NSLog(@"velocity: %f", velocity);
            }
            /* but not too slow either */
            if (duration > defaultSpeed) {
                duration = defaultSpeed;
            }
            
            [UIView animateWithDuration:duration animations:^{
                [self moveToSnappingPointsWithGestureRecognizer:gestureRecognizer];
            }
                             completion:^(BOOL finished) {
                                 if ([self.delegate respondsToSelector:@selector(sheetsheetNavigationController:didMoveController:)]) {
                                     [self.delegate sheetNavigationController:self didMoveController:self.firstTouchedController];
                                 }
                                 if ([self.firstStackedController.contentViewController respondsToSelector:@selector(sheetNavigationControllerDidPanSheet)]) {
                                     [(id<SheetStackPage>)self.firstStackedController.contentViewController sheetNavigationControllerDidPanSheet];
                                 }
                                 SheetStackState stackState = [[SheetLayoutModel sharedInstance] stackState];
                                 if (stackState == kSheetStackStateRemoving) {
                                     [self didRemoveSheetWithGesture];
                                 }
                                 
                                 self.firstTouchedView = nil;
                                 self.firstTouchedController = nil;
                                 _willDismissTopSheet = NO;
                                 _willPopToRootSheet = NO;
                             }];
            
            break;
        }
            
        default:
            break;
    }
}

- (void)didRemoveSheetWithGesture {
    
    SheetController *vc = (SheetController *)[self.sheetViewControllers lastObject];
    [self removeSheetFromHistory:vc];
    [self removeSheetFromViewHeirarchy:vc];
    
    if ([vc.contentViewController respondsToSelector:@selector(didGetUnpeeked)]) {
        [(id<SheetStackPeeking>)vc.contentViewController didGetUnpeeked];
    }
    
    BOOL isExpandedPeeked = vc.sheetNavigationItem.expandedPeekedSheet;
    if (isExpandedPeeked){
        [self peekViewController:self.peekedSheetController animated:NO];
        [self addPeekedSheetPanGesture];
    }
    
    if ([self animateOutAndInDefaultPeekedSheet:vc]) {
        if ([self.peekedSheetController.contentViewController respondsToSelector:@selector(willPeekOnTopOfSheet:)]) {
            [(id<SheetStackPeeking>)self.peekedSheetController.contentViewController willPeekOnTopOfSheet:self.topSheetContentViewController];
        }
    }
    
    NSUInteger count = self.sheetViewControllers.count;
    [self.sheetViewControllers enumerateObjectsUsingBlock:^(SheetController *vc,NSUInteger idx,BOOL *stop){
        [vc.sheetNavigationItem setCount:count];
        [vc.sheetNavigationItem setIndex:idx];
    }];
    
}

- (BOOL)animateOutAndInDefaultPeekedSheet:(SheetController *)vc {
    BOOL isFullscreen = vc.sheetNavigationItem.layoutType == kSheetLayoutFullScreen ? YES : NO;
    BOOL wantsDefaultPeekedSheet = wantsDefaultPeekedSheet(self.topSheetContentViewController);
    BOOL isPeekedSheet = vc.sheetNavigationItem.expandedPeekedSheet;
    BOOL hasDefaultPeekedSheet = self.peekedSheetController ? YES : NO;
    return wantsDefaultPeekedSheet && isFullscreen && !isPeekedSheet && hasDefaultPeekedSheet;
}

- (void)removedPeekedViewController:(SheetController *)vc {
    if (!isDefaultPeekedSheet(vc)) {
        [self.peekedViewControllers addObject:vc];
    }
    
    [self peekViewController:vc animated:NO];
}

- (void)attachGestureRecognizers {
    self.tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    self.tapGR.delegate = self;
    self.tapGR.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.tapGR];
    
    self.panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    self.panGR.maximumNumberOfTouches = 2;
    self.panGR.delegate = self;
    [self.view addGestureRecognizer:self.panGR];
}

- (void)detachGestureRecognizers {
    [self.view removeGestureRecognizer:self.tapGR];
    [self.tapGR removeTarget:self action:NULL];
    self.tapGR.delegate = nil;
    self.tapGR = nil;
    
    [self.view removeGestureRecognizer:self.panGR];
    [self.panGR removeTarget:self action:NULL];
    self.panGR.delegate = nil;
    self.panGR = nil;
}

- (BOOL)sheetShouldPan:(UIViewController *)viewController {
    BOOL isDraggable = YES;
    if ([viewController respondsToSelector:@selector(isDraggableSheet)]) {
        isDraggable = [(id<SheetStackPage>)viewController isDraggableSheet];
    }
    return isDraggable;
}

- (BOOL)isGutter:(UIViewController *)viewController {
    int offset = [self sheetControllerOf:viewController].sheetNavigationItem.offset;
    BOOL isInGutter = offset == 2 ? YES : NO;
    return isInGutter;
}

- (BOOL)isNonInteractiveSheet:(UIViewController *)viewController {
    BOOL isNonInteractive = NO;
    if ([viewController respondsToSelector:@selector(isInteractiveSheet)]) {
        isNonInteractive = [(id<SheetStackPage>)viewController isNonInteractiveSheet];
    }
    // never allow root sheet to be interactive
    int index = [self sheetControllerOf:viewController].sheetNavigationItem.index;
    isNonInteractive = index == 0 ? YES : isNonInteractive;
    return isNonInteractive;
}

- (BOOL)isProtectedSheet:(UIViewController *)viewController {
    BOOL isProtected = NO;
    if ([viewController isKindOfClass:[SheetController class]]) {
        viewController = [(SheetController *)viewController contentViewController];
    }
    if ([viewController respondsToSelector:@selector(isProtectedSheet)]) {
        isProtected = [(id<SheetStackPage>)viewController isProtectedSheet];
    }
    return isProtected;
}

- (BOOL)sheetsInDropZone {
    if ([self.sheetViewControllers count] > 1) {
        const SheetController *rootVC = [self.sheetViewControllers objectAtIndex:0];
        const SheetController *sheet1VC = [self.sheetViewControllers objectAtIndex:1];
        const SheetNavigationItem *rootNI = rootVC.sheetNavigationItem;
        const SheetNavigationItem *sheet1NI = sheet1VC.sheetNavigationItem;
        
        if (sheet1NI.currentViewPosition.x - rootNI.currentViewPosition.x - rootNI.width > 300) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

#pragma mark Sheet stacking callbacks

- (void)willAddSheet {
    [[SheetLayoutModel sharedInstance] setStackState:kSheetStackStateAdding];
    
    [(id<SheetStackPage>)[self topSheetController] sheetWillBeStacked];
    
    if ([self.delegate respondsToSelector:@selector(sheetNavigationControllerWillAddSheet)]) {
        [self.delegate sheetNavigationControllerWillAddSheet];
    }
    
    self.firstStackedController = [self topSheetController];
}

- (void)didAddSheet {
    if (self.firstStackedController) {
        [(id<SheetStackPage>)self.firstStackedController sheetDidGetStacked];
    }
    
    if ([self.delegate respondsToSelector:@selector(sheetNavigationControllerDidAddSheet)]) {
        [self.delegate sheetNavigationControllerDidAddSheet];
    }
    
    self.firstStackedController = nil;
    [[SheetLayoutModel sharedInstance] setStackState:kSheetStackStateDefault];
}

- (void)willRemoveSheet {
    [[SheetLayoutModel sharedInstance] setStackState:kSheetStackStateRemoving];
    
    SheetController *vc = [self firstStackedOnSheetController];
    [(id<SheetStackPage>)vc sheetWillBeUnstacked];
    
    if ([self.topSheetContentViewController respondsToSelector:@selector(sheetWillBeDismissed)]) {
        [(id<SheetStackPage>)self.topSheetContentViewController sheetWillBeDismissed];
    }
    
    self.firstStackedController = vc;
}

- (void)didRemoveSheet {
    if (self.firstStackedController) {
        if ([self.firstStackedController respondsToSelector:@selector(sheetDidGetUnstacked)]) {
            [(id<SheetStackPage>)self.firstStackedController sheetDidGetUnstacked];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(sheetNavigationControllerDidRemoveSheet)]) {
        [self.delegate sheetNavigationControllerDidRemoveSheet];
    }
    
    self.firstStackedController = nil;
    [[SheetLayoutModel sharedInstance] setStackState:kSheetStackStateDefault];
}

#pragma mark History management

- (void)archiveStackedSheetContent {
    NSUInteger count = self.sheetViewControllers.count;
    if (count == 1) {
        /* don't remove root view controller */
        return;
    }
    
    NSUInteger archiveIndex = (count - kInflatedSheetCountMax);
    
    SheetController *vc = [self sheetViewControllers][archiveIndex];
    
    /* don't drop a protected sheet */
    if ([self isProtectedSheet:vc]) {
        return;
    }
    
    NSMutableDictionary *freshArchiveDict = [self dropSheetControllerContent:vc];
    [_historyManager updateHistoryItem:freshArchiveDict atIndex:archiveIndex];
}

- (void)restoreFirstEmptySheetContentUnder:(UIViewController *)viewController {
    NSUInteger count = _sheetViewControllers.count;
    NSUInteger threshold = [[SheetLayoutModel sharedInstance] thresholdForDroppingSheets];
    if (count < threshold) {
        /* haven't dropped any sheets yet */
        return;
    }
    
    for (SheetController *sheetController in [self.sheetViewControllers reverseObjectEnumerator]) {
        if (!sheetController.contentViewController) {
            [self restoreSheetContentAtIndex:[self.sheetViewControllers indexOfObject:sheetController]];
            break;
        }
    }
}

- (void)restoreSheetContentAtIndex:(NSUInteger)index {
    UIViewController *vc = [self sheetContentAtIndex:index];
    if (!vc) {
        // restore it from history
        UIViewController *newViewController = [_historyManager restoredViewControllerForIndex:index];
        if (newViewController) {
            SheetController *restoredSheetController = [self.sheetViewControllers objectAtIndex:index];
            NSMutableDictionary *archiveDict = [_historyManager historyItemAtIndex:index];
            if ([newViewController respondsToSelector:@selector(decodeRestorableState:)]) {
                [(id<SheetStackPage>)newViewController decodeRestorableState:archiveDict];
            }
            
            [restoredSheetController setContentViewController:newViewController];
            
            //NSLog(@"new count: %i",self.sheetViewControllers.count-1);
            restoredSheetController.sheetNavigationItem.count = self.sheetViewControllers.count-1;
            
            [self layoutSheetController:restoredSheetController];
        }
    } else {
        // not sure when this would happen, being defensive
        SheetController *sheetController = [self sheetControllerOf:vc];
        [self layoutSheetController:sheetController];
    }
}

/* Number of heavy views actually in stack */
- (NSUInteger)inflatedCount {
    NSMutableArray *inflatedViewControllers = [[NSMutableArray alloc] init];
    [self.sheetViewControllers enumerateObjectsUsingBlock:^(SheetController *controller, NSUInteger idx, BOOL *stop) {
        
        if ([controller.contentViewController isKindOfClass:[UIViewController class]]) {
            [inflatedViewControllers addObject:controller];
        }
    }];
    
    return inflatedViewControllers.count;
}


@end
