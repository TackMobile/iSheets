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

const CGFloat kSheetSnappingVelocityThreshold   = 340.0;

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
    BOOL willDismissTopSheet;
    BOOL willPopToRootSheet;
}

@property (nonatomic, strong) UITapGestureRecognizer *tapGR;
@property (nonatomic, readwrite, strong) UIPanGestureRecognizer *panGR;
@property (nonatomic) BOOL dropLayersWhenPulledRight;

@property (nonatomic, strong) NSMutableArray *sheetViewControllers;
@property (nonatomic, weak) UIViewController *outOfBoundsViewController;
@property (nonatomic, weak) UIView *firstTouchedView;
@property (nonatomic, weak) UIView *dropNotificationView;

@property (nonatomic, strong) SheetController *peekedSheetController;
@property (nonatomic, weak) UIViewController *firstTouchedController;
@property (nonatomic, weak) UIViewController *firstStackedController;
@property (nonatomic, strong) NSMutableArray *peekedViewControllers;

@end

@implementation SheetNavigationController

- (id)initWithRootViewController:(UIViewController *)rootViewController {
    return [self initWithRootViewController:rootViewController configuration:nil];
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
                   configuration:(void (^)(SheetNavigationItem *item))configuration {
    self = [super init];
    if (self) {
        
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
        
        _outOfBoundsViewController = nil;
        
        [self addChildViewController:sheetRC];
        [sheetRC didMoveToParentViewController:self];
        [[SheetLayoutModel sharedInstance] incrementProtectedCount];
        
    }
    return self;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController peekedViewController:(UIViewController *)peekedViewController configuration:(SheetNavigationConfigBlock)configuration {
    self = [self initWithRootViewController:rootViewController configuration:configuration];
    if (self) {
        self.peekedSheetController = [[SheetController alloc] initWithContentViewController:peekedViewController maximumWidth:NO];
    }
    
    return self;
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
    
    if (self.peekedSheetController) {
        [self peekViewController:self.peekedSheetController animated:NO];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation {
    NSLog(@"ORIENTATION, new size: %@", NSStringFromCGSize(self.view.bounds.size));
    [super didRotateFromInterfaceOrientation:orientation];
    [self doLayout];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self doLayout];
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

- (void)layoutPeekedViewControllers {
    
    SheetStackState sheetStackState = [[SheetLayoutModel sharedInstance] stackState];
    if (sheetStackState == kSheetStackStateDefault) {
        if (!self.peekedSheetController.sheetNavigationItem.expanded) {
            if (wantsDefaultPeekedSheet(self.topSheetContentViewController)) {
                self.peekedSheetController.view.frame = [self peekedFrameForViewController:self.peekedSheetController.contentViewController];
            } else {
                self.peekedSheetController.view.frameX = [self overallWidth];
            }
        }
    }
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
    
    if (sheetController.maximumWidth) {
        // standard sheet, no special layout rules
        // just make it full-width minus its offset from left
        navItem.width = CGRectGetWidth(self.view.bounds) - navItem.initialViewPosition.x;
        f.size.width = navItem.width;
        
    } else {
        
        [[SheetLayoutModel sharedInstance] updateNavItem:navItem];
        f.origin = navItem.initialViewPosition;
    }
    
    f.origin.x = floorf(f.origin.x);
    
    void(^stateChange)(void) = ^{
        sheetController.view.frame = f;
        [sheetController.view setNeedsLayout];
    };
    
    // animated if visible on top of stack and is not root
    BOOL animated = (offset > 0 && offset < kFirstStackedSheet+1) ? YES : NO;
    if (animated) {
        [UIView animateWithDuration:[SheetLayoutModel animateOnDuration]
                              delay:0
                            options: SHEET_ADDING_ANIMATION_OPTION
                         animations:^{
                             stateChange();
                         }
                         completion:^(BOOL finished){
                             
                         }];
    } else {
        stateChange();
    }
}

- (CGRect)peekedFrameForViewController:(UIViewController *)vc {
    const CGFloat peekWidth = [self getPeekedWidth:vc];
    CGFloat xPos = [self overallWidth];
    return CGRectMake(xPos - peekWidth,
                      0.0,
                      vc.view.frameWidth,
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
    if (navItem.expanded) {
        // offset it left to match initial x of peeked sheet
        offScreenX -= [self getPeekedWidth:navItem.layerController.contentViewController];
    }
    frame = CGRectMake(MAX(offScreenX, CGRectGetMinX(onscreenFrame)),
                       0.0,
                       CGRectGetWidth(onscreenFrame),
                       CGRectGetHeight(onscreenFrame));
    return frame;
}

#pragma mark - Public API

- (void)peekViewController:(SheetController *)viewController {
    [(id<SheetStackPage>)[self topSheetController] willBeStacked];
    [self peekViewController:viewController animated:YES];
    [(id<SheetStackPage>)[self topSheetController] didGetUnstacked];
}

- (void)popToRootViewControllerAnimated:(BOOL)animated {
    [self popToViewController:[self.sheetViewControllers objectAtIndex:0] animated:animated];
}

- (void)popToViewController:(UIViewController *)vc animated:(BOOL)animated {
    UIViewController *currentVc;
    
    while ((currentVc = [self.sheetViewControllers lastObject])) {
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
    
    if (vc.sheetNavigationItem.expanded) {
        xLoc -= vc.sheetNavigationItem.peekedWidth;
    }
    
    BOOL isFullscreen = vc.sheetNavigationItem.layoutType == kSheetLayoutFullScreen ? YES : NO;
    BOOL wantsDefaultPeekedSheet = wantsDefaultPeekedSheet([(SheetController *)self.firstStackedController contentViewController]);
    BOOL isPeekedSheet = vc.sheetNavigationItem.expanded;
    BOOL animateOutAndInDefaultPeekedSheet = wantsDefaultPeekedSheet && isFullscreen && !isPeekedSheet;
    
    if (isPeekedSheet) {
        xLoc -= [self getPeekedWidth:vc.contentViewController];
    }
    
    CGRect goAwayFrame = CGRectMake(xLoc,
                                    CGRectGetMinY(self.view.bounds),
                                    CGRectGetWidth(vc.view.frame),
                                    CGRectGetHeight(vc.view.frame));
    
    UIViewController *contentVC = vc.contentViewController;
    void (^completeViewRemoval)(BOOL) = ^(BOOL finished) {
        
        
        [self removeSheetFromViewHeirarchy:vc];
        
        if (isPeekedSheet) {
            vc.sheetNavigationItem.expanded = NO;
            [self peekViewController:self.peekedSheetController animated:NO];
        } else if (animateOutAndInDefaultPeekedSheet) {
            [UIView animateWithDuration:[SheetLayoutModel animateOnDuration]
                                  delay:0
                                options: SHEET_REMOVAL_ANIMATION_OPTION
                             animations:^{
                                 self.peekedSheetController.view.frame = [self peekedFrameForViewController:self.peekedSheetController.contentViewController];
                             }
                             completion:nil];
        }
    };
    
    UIViewAnimationOptions curve = isPeekedSheet ? SHEET_ADDING_ANIMATION_OPTION : SHEET_REMOVAL_ANIMATION_OPTION;
    if (animated) {
        [UIView animateWithDuration:[SheetLayoutModel animateOffDuration]
                              delay:0
                            options:curve
                         animations:^{
                             if (isPeekedSheet) {
                                 vc.view.frame = [self peekedFrameForViewController:contentVC];
                             } else if (animateOutAndInDefaultPeekedSheet) {
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
        if (![currentTop.contentViewController isEqual:self.peekedSheetController]) {
            [self layoutSheetController:currentTop];
        }
    }
    
    [[SheetLayoutModel sharedInstance] updateNavItem:navItem];
    
    const CGFloat overallWidth = [self overallWidth];
    
    CGRect onscreenFrame = [self onscreenFrameForNavItem:navItem];
    CGRect offscreenFrame = [self offscreenFrameForNavItem:navItem withOnscreenFrame:onscreenFrame];
    
    newSheetController.view.frame = offscreenFrame;
    
    [self.sheetViewControllers addObject:newSheetController];
    if ([self isProtectedSheet:contentViewController]) {
        [[SheetLayoutModel sharedInstance] incrementProtectedCount];
    }
    
    [_historyManager addHistoryItemForSheetController:newSheetController];
    
    NSUInteger count = self.sheetViewControllers.count;
    
    [self.sheetViewControllers enumerateObjectsUsingBlock:^(SheetController *vc, NSUInteger idx, BOOL *stop){
        [vc.sheetNavigationItem setCount:count];
    }];
    
    [self addChildViewController:newSheetController];
    [self.view addSubview:newSheetController.view];
    
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
        
        // protecting dashboard & course home
        if ([[SheetLayoutModel sharedInstance] shouldDropSheet]) {
            [self archiveStackedSheetContent];
        }
        
        if (self.peekedSheetController) {
            if (wantsDefaultPeekedSheet(contentViewController) && !isDefaultPeekedSheet(contentViewController)) {
                self.peekedSheetController.view.frameX = [self overallWidth];
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
                                     self.peekedSheetController.view.frame = [self peekedFrameForViewController:self.peekedSheetController.contentViewController];
                                 } completion:nil];
            }
        }
    };
    
    [UIView animateWithDuration:[SheetLayoutModel animateOnDuration]
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

- (UIViewController *)firstStackedOnSheetController {
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
    return [[self sheetControllerOf:vc] sheetNavigationItem];
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
    
    if ([self isProtectedSheet:vc]) {
        [[SheetLayoutModel sharedInstance] decrementProtectedCount];
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
    
    if ([contentViewController respondsToSelector:@selector(willBeDropped)]) {
        [contentViewController performSelector:@selector(willBeDropped)];
    }
    
    [vc dumpContentViewController];
    
    if ([contentViewController respondsToSelector:@selector(willBeDropped)]) {
        [contentViewController performSelector:@selector(didGetDropped)];
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
    [(id<SheetStackPage>)self.firstStackedController beingUnstacked:percentComplete];
    [(id<SheetStackPage>)[self.sheetViewControllers lastObject] beingUnstacked:percentComplete];
    
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
    
    if (abs(velocity) > kSheetSnappingVelocityThreshold) {
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
        if ([self isProtectedSheet:vc.contentViewController] || navItem.offset > 2) {
            return;
        }
        
        if (last == nil) {
            last = [self sheetControllerAtIndex:index-1];
            NSAssert(last != nil, @"we should have a last nav item");
            NSAssert(last.sheetNavigationItem.offset == navItem.offset+1, @"should be one back");
        }
        
        SheetNavigationItem *lastNavItem = last.sheetNavigationItem;
        
        const CGPoint myPos = navItem.currentViewPosition;
        const CGPoint myInitPos = navItem.initialViewPosition;
        
        const CGFloat curDiff = myPos.x - lastNavItem.currentViewPosition.x;
        const CGFloat initDiff = myInitPos.x - lastNavItem.initialViewPosition.x;
        const CGFloat maxDiff = CGRectGetWidth(last.view.frame);
        const CGFloat overallWidth = [self overallWidth];
        
        BOOL(^floatNotEqual)(float,float) = ^BOOL(float l,float r){
            return !(abs(l-r) < 0.1);
        };
        
        void(^doRightSnapping)(void) = ^{
            
            if (navItem.offset == 1) {
                
                xTranslation = overallWidth - myPos.x;
                if (vc.sheetNavigationItem.expanded) {
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
                    if (rightSnappingEdgeNearest || willDismissTopSheet) {
                        /* right snapping point is nearest */
                        /* and right snapping point is >= to nav width */
                        doRightSnapping();
                    } else {
                        /* left snapping point is nearest */
                        if (!willDismissTopSheet) {
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
                    if (willDismissTopSheet) {
                        doRightSnapping();
                    }
                }
            }
        } else if (willDismissTopSheet) {
            doRightSnapping();
        } else {
            doLeftSnapping();
        }
        
        if (navItem.offset == 1) {
            
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
    
    //NSLog(@"xTranslationGesture: %f",xTranslationGesture);
    
    BOOL descendentOfTouched = NO;
    SheetController *rootVC = [self.sheetViewControllers objectAtIndex:0];
    BOOL hasPeekedViewControllers = self.peekedSheetController ? YES : NO;
    
    for (SheetController *me in [self.sheetViewControllers reverseObjectEnumerator]) {
        if (rootVC == me) {
            break;
        }
        
        SheetNavigationItem *meNavItem = me.sheetNavigationItem;
        //BOOL movePeekedVC = hasPeekedViewControllers && meNavItem.index == 1 ? YES : NO;
        
        const CGPoint myPos = meNavItem.currentViewPosition;
        const CGPoint myInitPos = meNavItem.initialViewPosition;
        CGPoint myNewPos = myPos;
        const CGPoint myOldPos = myPos;
        
        const CGPoint parentPos = parentNavItem.currentViewPosition;
        const CGPoint parentInitPos = parentNavItem.initialViewPosition;
        
        const CGFloat minDiff = parentInitPos.x - myInitPos.x;
        CGFloat myWidth = CGRectGetWidth(me.view.frame);
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
                willDismissTopSheet = YES;
            } else if (abs(velocity) > kSheetSnappingVelocityThreshold) {
                if (velocity > 0) {
                    willDismissTopSheet = YES;
                }
            } else {
                willDismissTopSheet = NO;
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
            //if (movePeekedVC) {
            //                for (UIViewController *peekedViewController in self.peekedViewControllers) {
            //                    if ([peekedViewController isEqual:self.defaultPeekedViewController]) {
            //                        continue;
            //                    }
            //                    CGFloat peekedWidth = [self getPeekedWidth:peekedViewController];
            //                    CGFloat peekedXPos = CGRectGetMaxX(me.view.frame) - peekedWidth;
            //                    peekedViewController.view.frameX = peekedXPos;
            //                }
            //}
            
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
    if (navItem.expanded) {
        peekedWidth = navItem.peekedWidth;
    }
    
    if (bounded) {
        //NSLog(@"move view %f pixels to %f, navItem initial view position x: %f",origXTranslation,(vc.view.frame.origin.x + origXTranslation),initPos.x);
        /* apply translation to navigation item position first and then apply to view */
        CGRect f = vc.view.frame;
        f.origin = navItem.currentViewPosition;
        f.origin.x += origXTranslation;
        
        //NSLog(@"if (%f <= %f)",f.origin.x,initPos.x);
        if (f.origin.x <= initPos.x) {
            f.origin.x = initPos.x;
        }
        
        if (peekedWidth > 0.0 && navItem.offset == 1) {
            if (f.origin.x >= navViewWidth - peekedWidth) {
                f.origin.x = navViewWidth - peekedWidth;
            }
        }
        
        if (CGRectGetMaxX(f) > [self overallWidth] && navItem.offset == 2 && willDismissTopSheet) {
            f.origin.x = [self overallWidth] - f.size.width;
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

- (BOOL)showsDefaultPeekedViewController:(UIViewController *)vc {
    if ([vc respondsToSelector:@selector(showsDefaultPeekedViewController)]) {
        return [(id<SheetStackPeeking>)vc showsDefaultPeekedViewController];
    }
    return NO;
}

- (void)expandPeekedSheet {
    SheetController *peekedSheetController = self.peekedSheetController;//(SheetController *)[self topPeekedSheet];
    UIViewController *peekedVC = peekedSheetController.contentViewController;
    if ([peekedVC respondsToSelector:@selector(setPeeking:)]) {
        [(id<SheetStackPeeking>)peekedVC setPeeking:NO];
    }
    
    SheetNavigationItem *oldNavItem = peekedSheetController.sheetNavigationItem;
    
    [peekedSheetController removeFromParentViewController];
    [peekedSheetController.view removeFromSuperview];
    [peekedSheetController willMoveToParentViewController:nil];
    
    peekedVC.view.frameX = 0.0;
    peekedVC.view.frameY = 0.0;
    
    [self pushViewController:peekedVC inFrontOf:[self topSheetContentViewController] configuration:^(SheetNavigationItem *navItem){
        navItem.expanded = YES;
        navItem.peekedWidth = oldNavItem.peekedWidth;
    }];
}

- (void)peekViewController:(SheetController *)viewController animated:(BOOL)animated {
    
    if ([viewController respondsToSelector:@selector(setPeeking:)]) {
        [(id<SheetStackPeeking>)viewController setPeeking:YES];
    }
    
    [viewController willMoveToParentViewController:self];
    [viewController.view removeFromSuperview];
    [viewController removeFromParentViewController];
    [self addChildViewController:viewController];
    
    CGRect onscreenFrame = [self peekedFrameForViewController:viewController];
    
    [self.view addSubview:viewController.view];
    
    void(^doNewFrameMove)(void) = ^{
        viewController.view.frame = onscreenFrame;
    };
    void(^frameMoveComplete)(void) = ^{
        [viewController didMoveToParentViewController:self];
        [(id<SheetStackPage>)self.topSheetContentViewController didGetStacked];
        [viewController.view setNeedsLayout];
    };
    if (animated) {
        viewController.view.frameX = [self overallWidth];
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

//- (void)popPeekedViewController:(UIViewController *)viewController animated:(BOOL)animated {
//    if (self.peekedViewControllers.count==0) {
//        return;
//    }
//
//    [(id<SheetStackPage>)self.topSheetContentViewController willBeUnstacked];
//    SheetController *peekedController = [self sheetControllerOf:viewController];
//    __block UIViewController *vc = viewController;
//
//    void(^doNewFrameMove)(void) = ^{
//        if (isDefaultPeekedSheet(viewController)) {
//            peekedController.view.frameX = CGRectGetMaxX(self.view.bounds) - [self getPeekedWidth:viewController];
//        } else {
//            peekedController.view.frameX = CGRectGetMaxX(self.view.bounds);
//        }
//    };
//    void(^frameMoveComplete)(void) = ^{
//
//        vc.sheetNavigationItem.expanded = NO;
//
//        [vc willMoveToParentViewController:nil];
//        [vc.view removeFromSuperview];
//        [vc removeFromParentViewController];
//
//        [self removedPeekedViewController:viewController];
//
//    };
//    if (animated) {
//        [UIView animateWithDuration:0.5
//                              delay:0
//                            options: UIViewAnimationOptionCurveLinear
//                         animations:^{
//                             doNewFrameMove();
//                         }
//                         completion:^(BOOL finished) {
//                             frameMoveComplete();
//                         }];
//    } else {
//        doNewFrameMove();
//        frameMoveComplete();
//    }
//}

//- (void)removePeekedViewControllers {
//    UIViewController *currentVc;
//    while ((currentVc = [self.peekedViewControllers lastObject])) {
//        if (self.peekedViewControllers.count == 1) {
//            // leave default (stream) alone
//            return;
//        }
//        [self popPeekedViewController:currentVc animated:NO];
//    }
//}

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

- (void)handleTapGesture:(UIPanGestureRecognizer *)gestureRecognizer {
    
    switch (gestureRecognizer.state) {
            
        case UIGestureRecognizerStateEnded: {
            SheetNavItemState state = kSheetIgnore;
            
            UIView *touchedView = [gestureRecognizer.view hitTest:[gestureRecognizer locationInView:gestureRecognizer.view] withEvent:nil];
            self.firstTouchedView = touchedView;
            
            SheetController *topPeekedSheet = self.peekedSheetController;
            BOOL controllerContentIsPeekedSheet = [touchedView isDescendantOfView:topPeekedSheet.contentViewController.view];
            BOOL isExpandedPeekedSheet = [[self topSheetController] sheetNavigationItem].expanded;
            if (controllerContentIsPeekedSheet && !isExpandedPeekedSheet){
                [self expandPeekedSheet];
                
            } else {
                for (SheetController *controller in [self.sheetViewControllers reverseObjectEnumerator]) {
                    
                    if ([touchedView isDescendantOfView:controller.view]) {
                        BOOL controllerContentIsTopSheet = [controller.contentViewController isEqual:[self topSheetContentViewController]];
                        if (!controllerContentIsTopSheet) {
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
            
            if ([self.delegate respondsToSelector:@selector(layeredNavigationController:willMoveController:)]) {
                [self.delegate layeredNavigationController:self willMoveController:self.firstTouchedController];
            }
            
            if (self.firstTouchedController) {
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

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer
{
    if (self.count <= 1) {
        return;
    }
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStatePossible: {
            //NSLog(@"UIGestureRecognizerStatePossible");
            break;
        }
            
        case UIGestureRecognizerStateBegan: {
            //NSLog(@"UIGestureRecognizerStateBegan");
            
            UIView *touchedView =
            [gestureRecognizer.view hitTest:[gestureRecognizer locationInView:gestureRecognizer.view]
                                  withEvent:nil];
            self.firstTouchedView = touchedView;
            for (SheetController *controller in [self.sheetViewControllers reverseObjectEnumerator]) {
                if ([touchedView isDescendantOfView:controller.view]) {
                    self.firstTouchedController = controller.contentViewController;
                    
                    if (![self sheetShouldPan:self.firstTouchedController]) {
                        [gestureRecognizer setEnabled:NO];
                        [gestureRecognizer setEnabled:YES];
                    }
                    
                    break;
                }
            }
            
            if ([self.delegate respondsToSelector:@selector(layeredNavigationController:willMoveController:)]) {
                [self.delegate layeredNavigationController:self willMoveController:self.firstTouchedController];
            }
            
            UIViewController *firstStacked = [self firstStackedOnSheetController];
            [(id<SheetStackPage>)firstStacked performSelector:@selector(willBeUnstacked)];
            [self restoreFirstEmptySheetContentUnder:firstStacked];
            self.firstStackedController = firstStacked;
            
            willPopToRootSheet = gestureRecognizer.numberOfTouches == 2;
            
            
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            
            if (willPopToRootSheet) {
                return;
            }
            
            const CGFloat parentWidth = [self overallWidth];
            const CGFloat peekedWidth = [self getPeekedWidth:self.topSheetContentViewController];
            
            //float vel = [gestureRecognizer velocityInView:self.firstTouchedController.view].x;
            //NSLog(@"UIGestureRecognizerStateChanged, vel=%f",vel);
            
            const NSInteger startVcIdx = [self.sheetViewControllers count]-1;
            const SheetController *startVc = [self.sheetViewControllers objectAtIndex:startVcIdx];
            
            CGFloat xTranslation = [gestureRecognizer translationInView:self.view].x;
            [self moveViewControllersXTranslation:xTranslation velocity:[gestureRecognizer velocityInView:self.view].x];
            
            const SheetNavigationItem *navItem = startVc.sheetNavigationItem;
            if (navItem.offset == 1) {
                CGFloat initX = navItem.initialViewPosition.x;
                CGFloat rightEdge = (parentWidth-peekedWidth)-initX;
                float currPos = startVc.view.frameX-initX;
                CGFloat percComplete = currPos/rightEdge;
                [self forwardUnstackingPercentage:percComplete];
            }
            
            if ([self.delegate respondsToSelector:@selector(layeredNavigationController:movingViewController:)]) {
                [self.delegate layeredNavigationController:self movingViewController:self.firstTouchedController];
            }
            
            [gestureRecognizer setTranslation:CGPointZero inView:startVc.view];
            
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            
            const CGFloat velocity = [gestureRecognizer velocityInView:self.view].x;
            
            if (willPopToRootSheet && velocity > kSheetSnappingVelocityThreshold) {
                //NSLog(@"%i -----  %s",gestureRecognizer.numberOfTouches,willPopToRootSheet ? "yes" : "no");
                [self popToRootViewControllerAnimated:YES];
                willPopToRootSheet = NO;
                return;
            }
            
            NSTimeInterval defaultSpeed = [SheetLayoutModel animateOffDuration];
            NSTimeInterval duration = defaultSpeed;
            
            if (abs(velocity) != 0) {
                /* match speed of fast swipe */
                CGFloat currentX = abs([self topSheetController].view.frame.origin.x);
                CGFloat pointsX = [self overallWidth] - currentX;
                duration = pointsX / velocity;
            }
            /* but not too slow either */
            if (duration > defaultSpeed) {
                duration = defaultSpeed;
            }
            
            [UIView animateWithDuration:duration animations:^{
                [self moveToSnappingPointsWithGestureRecognizer:gestureRecognizer];
            }
                             completion:^(BOOL finished) {
                                 if ([self.delegate respondsToSelector:@selector(layeredNavigationController:didMoveController:)]) {
                                     [self.delegate layeredNavigationController:self didMoveController:self.firstTouchedController];
                                 }
                                 SheetStackState stackState = [[SheetLayoutModel sharedInstance] stackState];
                                 if (stackState == kSheetStackStateRemoving) {
                                     [self didRemoveSheetWithGesture];
                                 }
                                 
                                 self.firstTouchedView = nil;
                                 self.firstTouchedController = nil;
                                 willDismissTopSheet = NO;
                                 willPopToRootSheet = NO;
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
    BOOL isExpandedPeeked = vc.sheetNavigationItem.expanded;
    if (isExpandedPeeked){
        [self peekViewController:self.peekedSheetController animated:NO];
    }
    
    //    BOOL isDroppedSheet = !controller.contentViewController;
    //    if (isDroppedSheet) {
    //        [self restoreSheetContentAtIndex:[self.sheetViewControllers indexOfObject:controller]];
    //    }
    
    NSUInteger count = self.sheetViewControllers.count;
    [self.sheetViewControllers enumerateObjectsUsingBlock:^(SheetController *vc,NSUInteger idx,BOOL *stop){
        [vc.sheetNavigationItem setCount:count];
        [vc.sheetNavigationItem setIndex:idx];
    }];
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
    [self.tapGR removeTarget:self action:NULL];
    self.tapGR.delegate = nil;
    self.tapGR = nil;
    
    [self.panGR removeTarget:self action:NULL];
    self.panGR.delegate = nil;
    self.panGR = nil;
}

- (BOOL)sheetShouldPan:(UIViewController *)viewController {
    BOOL isProtectedSheet = [self isProtectedSheet:viewController];
    BOOL isStacked = [self sheetControllerOf:viewController].sheetNavigationItem.offset > 1;
    
    return !isProtectedSheet && !isStacked;
}

- (BOOL)isProtectedSheet:(UIViewController *)viewController {
    BOOL isProtected = NO;
    if ([viewController respondsToSelector:@selector(isProtectedSheet)]) {
        isProtected = [(id<SheetStackPage>)viewController isProtectedSheet];
    }
    return isProtected;
}

- (BOOL)sheetsInDropZone
{
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
    
    [(id<SheetStackPage>)[self topSheetController] willBeStacked];
    
    self.firstStackedController = [self topSheetContentViewController];
}

- (void)didAddSheet {
    if (self.firstStackedController) {
        [(id<SheetStackPage>)self.firstStackedController didGetStacked];
    }
    
    self.firstStackedController = nil;
    [[SheetLayoutModel sharedInstance] setStackState:kSheetStackStateDefault];
}

- (void)willRemoveSheet {
    [[SheetLayoutModel sharedInstance] setStackState:kSheetStackStateRemoving];
    
    UIViewController *vc = [self firstStackedOnSheetController];
    [(id<SheetStackPage>)vc willBeUnstacked];
    
    self.firstStackedController = vc;
}

- (void)didRemoveSheet {
    if (self.firstStackedController) {
        if ([self.firstStackedController respondsToSelector:@selector(didGetUnstacked)]) {
            [(id<SheetStackPage>)self.firstStackedController didGetUnstacked];
        }
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
    NSUInteger indexToPop = [_sheetViewControllers indexOfObject:viewController];
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
            [restoredSheetController setContentViewController:newViewController];
            
            if ([restoredSheetController.contentViewController respondsToSelector:@selector(decodeRestorableState:)]) {
                NSMutableDictionary *archiveDict = [_historyManager historyItemAtIndex:index];
                [(id<SheetStackPage>)restoredSheetController.contentViewController decodeRestorableState:archiveDict];
            }
            
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

- (void)logViewController:(SheetController *)controller {
    NSLog(@"content vc class: %@",controller.contentViewController);
    NSLog(@"nav item index: %i count:%i",controller.sheetNavigationItem.index,controller.sheetNavigationItem.count);
    NSLog(@"content vc is nil: %s",controller.contentViewController == nil ? "yes" : "no");
}

@end
