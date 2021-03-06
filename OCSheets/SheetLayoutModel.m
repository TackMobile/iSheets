//
//  SheetLayoutManager.m
//  OpenClass
//
//  Created by Ben Pilcher on 4/14/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "SheetLayoutModel.h"
#import "SheetNavigationController.h"
#import "SheetNavigationItem.h"
#import "SheetController.h"
#import "BasicSheetViewController.h"

@implementation SheetLayoutModel

const CGFloat kCoverOpacity                 = 0.3;
const CGFloat kDefaultXOffset               = 100.0;
const NSUInteger kFirstStackedSheet         = 2;

/* drop sheets only after reaching this count */
const NSUInteger kInflatedSheetCountMax     = 3;
/* protect dashboard and course home */
const NSUInteger kProtectedSheetCount       = 2;

const CGFloat kSheetStackGutterWidth        = 24.0;
const CGFloat kSheetNextItemDefaultDistance = 3.0;
const CGFloat kSheetDefaultPeekedWidth      = 50.0;

// Sheet rules
const CGFloat kStandardSheetWidth           = 600.0;
const CGFloat kSheetMenuWidth               = 200.0;

#define USE_HARD_CODED_WIDTHS YES

__strong static SheetLayoutModel *_sharedInstance;
+ (SheetLayoutModel *) sharedInstance {
    if (_sharedInstance == nil) {
        _sharedInstance = [[self alloc] init];
    }
    return _sharedInstance;
}

+ (void) resetSharedInstance { 
    _sharedInstance.controller = nil;
    _sharedInstance = nil; 
}

#pragma mark Width calculations

- (void)setStackState:(SheetStackState)stackState {
    _stackState = stackState;
}

- (CGFloat)desiredWidthForContent:(UIViewController *)viewController navItem:(SheetNavigationItem *)navItem {
    
    CGFloat desiredWidth = 0.0;
    SheetStackPosition position = -1;
    switch (navItem.offset) {
        case 1:
            position = kSheetStackTop;
            break;
        case 2:
            position = kSheetStackFirstStacked;
            break;
        default:
            position = kSheetStackHidden;
            break;
    }
    
    if ([viewController isKindOfClass:[BasicSheetViewController class]]) {
        BasicSheetViewController *vc = (BasicSheetViewController *)viewController;
        desiredWidth = [vc widthForSheetPosition:position navItem:navItem];
        
    } else {
        if ([viewController respondsToSelector:@selector(desiredWidthForSheetPosition:navItem:)]) {
            desiredWidth = [[viewController performSelector:@selector(desiredWidthForSheetPosition:navItem:) withObject:navItem withObject:[NSNumber numberWithInt:position]] floatValue];
        }
    }
    // update with overidden width from subclass
    navItem.width = desiredWidth;
    
    return desiredWidth;
}

- (void)incrementTierCount {
    _tierCount += 1;
}

- (void)decrementTierCount {
    if (_tierCount == 0) {
        return;
    }
    _tierCount --;
}

- (void)updateNavItem:(SheetNavigationItem *)navItem {
    
    navItem.width = [self widthForNavItem:navItem];
    navItem.initialViewPosition = [self initialPositionForNavItem:navItem];
    navItem.currentViewPosition = navItem.initialViewPosition;
    navItem.nextItemDistance = [self nextItemDistanceForNavItem:navItem];
}

- (CGFloat)widthForNavItem:(SheetNavigationItem *)navItem {
    
    SheetLayoutType layoutType = navItem.layoutType;
    
    CGFloat width = 0.0;
    BOOL shouldTakeAvailableWidth = NO;
    CGFloat availableWidthModifier = 0.0;
    CGFloat availableWidthPerc = 0.0;
    
    
    if (layoutType == kSheetLayoutFullScreen || navItem.isFullscreened) {
        width = [self navControllerWidth];
    } else if (layoutType == kSheetLayoutFullAvailable) {
        width = [self navControllerWidth];
        CGFloat xPos = [self initX:navItem];
        width -= xPos;

    } else if (layoutType == kSheetLayoutDefault) {
        
        if (USE_HARD_CODED_WIDTHS) {
            if (navItem.offset == 1) {
                CGFloat desiredWidth = [self desiredWidthForContent:navItem.sheetController.contentViewController navItem:navItem];
                if (desiredWidth != 0.0) {
                    width = desiredWidth;
                }
            } else if (navItem.offset == 2) {
                CGFloat desiredWidth = [self desiredWidthForContent:navItem.sheetController.contentViewController navItem:navItem];
                if (desiredWidth != 0.0) {
                    width = desiredWidth;
                } else {
                    width = kStandardSheetWidth;
                }
            } else {
                shouldTakeAvailableWidth = YES;
            }
            
        } else {
            // else percentage based
            shouldTakeAvailableWidth = YES;
            availableWidthPerc = [self widthPercentageForNavItem:navItem];
        }
        
    }
    
    if (shouldTakeAvailableWidth) {
        CGFloat initPosX = [self initX:navItem];
        const CGFloat availableWidth = [self availableWidthForOffset:initPosX];
        width = availableWidth;
        if (availableWidthModifier != 0) {
            width += availableWidthModifier;
        } else if (availableWidthPerc > 0) {
            width *= availableWidthPerc;
        }
    } else if (width == 0.0) {
        width = kStandardSheetWidth;
    }
    
    return floorf(width);
}

- (NSUInteger)thresholdForDroppingSheets {
    //NSLog(@"%i + %i",kInflatedSheetCountMax,[self protectedCount]);
    return kInflatedSheetCountMax + [self tierCount];
}

- (BOOL)shouldDropSheet {
    //NSLog(@"%i >= %i",self.controller.count,[self thresholdForDroppingSheets]);
    return self.controller.count >= [self thresholdForDroppingSheets];
}

- (CGFloat)nextItemDistanceForNavItem:(SheetNavigationItem *)navItem  {
    
    SheetController *controller = navItem.sheetController;
    
    if (navItem.index >= [self thresholdForDroppingSheets]) {
        navItem.displayShadow = NO;
        return 0.0;
    }
    
    if ([controller.contentViewController respondsToSelector:@selector(nextItemDistanceForSheetClass:)]) {
        CGFloat nextDistance = [(id<SheetStackPage>)controller.contentViewController nextItemDistanceForSheetClass:nil];
        return nextDistance;
    }
    
    return kSheetNextItemDefaultDistance;
}

- (CGFloat)availableWidthForOffset:(CGFloat)offset {
    CGFloat width = [self navControllerWidth] - offset;
    return floorf(width);
}

- (CGFloat)navControllerWidth {
    return self.controller.view.bounds.size.width;
}

- (CGPoint)initialPositionForNavItem:(SheetNavigationItem *)navItem {
    
    static float yOffset = 0.0;
    
    CGFloat initX = 0.0;
    // offset from right
    if (navItem.offset == 1) {
        initX = (CGRectGetWidth(self.controller.view.bounds) - navItem.width);
        return CGPointMake(initX, yOffset);
    }
    // else offset from left
    return CGPointMake([self initX:navItem], yOffset);
}

- (CGFloat)initX:(SheetNavigationItem *)navItem {
    // else offset from left
    if (navItem.index == 0 || navItem.layoutType == kSheetLayoutFullScreen || navItem.isFullscreened) {
        return 0.0; // root sheet
    }
    SheetController *parentLayerController = [self.controller sheetControllerAtIndex:navItem.index-1];
    UIViewController *parentVc = parentLayerController.contentViewController;
    SheetNavigationItem *parentNavItem = parentLayerController.sheetNavigationItem;
    
    UIViewController *sheetContent = navItem.sheetController.contentViewController;
    CGFloat desiredNextDist = [self desiredNextItemDistanceForParent:parentVc forChild:sheetContent];
    parentNavItem.nextItemDistance = desiredNextDist >= 0.0 ? desiredNextDist : parentNavItem.nextItemDistance;
    
    CGFloat anchorInitX = parentNavItem.initialViewPosition.x;
    CGFloat initX = anchorInitX + (parentNavItem.nextItemDistance >= 0 ?
                                   parentNavItem.nextItemDistance :
                                   kStandardSheetWidth);
    
    return floorf(initX);
}

- (CGFloat)desiredNextItemDistanceForParent:(UIViewController *)parent forChild:(UIViewController *)child {
    if ([parent respondsToSelector:@selector(nextItemDistanceForSheetClass:)]) {
        float nextDistance = [(id<SheetStackPage>)parent nextItemDistanceForSheetClass:NSStringFromClass(child.class)];
        return nextDistance;
    }
    return -1.0;
}

- (CGFloat)widthPercentageForNavItem:(SheetNavigationItem *)navItem {
    
    int offsetForFocusedSheet = 1;
    if (_stackState == kSheetStackStateRemoving) {
        // when removing, the first stacked sheet will
        // be focused, but its offset is still two, momentarily
        offsetForFocusedSheet = 2;
    }
    
    switch (navItem.layoutType) {
        case kSheetLayoutFullScreen:
            return 1.0;
            break;
        case kSheetLayoutDefault:
        {
            return navItem.offset == offsetForFocusedSheet ? 0.6 : 1.0;
            break;
        }
        default:
            return 1.0;
            break;
    }
}

#pragma mark - Helpers/Rules

+ (BOOL)shouldShowLeftNavItem:(SheetNavigationItem *)navItem {
    if (navItem.layoutType == kSheetLayoutFullScreen) {
        return NO;
    }
    return YES;
}

#define DurationMultiplier 0.75

+ (NSTimeInterval)animateOffDuration {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        return 0.25*DurationMultiplier;
    } else {
        return 0.3*DurationMultiplier;
    }
}

+ (NSTimeInterval)animateOnDuration {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        return 0.3*DurationMultiplier;
    } else {
        return 0.4*DurationMultiplier;
    }
}

+ (SheetLayoutType)layoutTypeForSheetController:(SheetController *)sheetController {
    SheetLayoutType sheetLayoutType = kSheetLayoutDefault;
    if ([sheetController.contentViewController respondsToSelector:@selector(sheetType)]) {
        sheetLayoutType = [(id<SheetStackPage>)sheetController.contentViewController sheetType];
    }
    
    return sheetLayoutType;
}

@end
