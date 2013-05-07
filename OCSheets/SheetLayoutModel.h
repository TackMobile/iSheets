//
//  SheetLayoutManager.h
//  OpenClass
//
//  Created by Ben Pilcher on 4/14/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const CGFloat kCoverOpacity;
extern const NSUInteger kFirstStackedSheet;
extern const NSUInteger kInflatedSheetCountMax;
extern const NSUInteger kProtectedSheetCount;
extern const CGFloat kSheetStackGutterWidth;
extern const CGFloat kSheetNextItemDefaultDistance;
extern const CGFloat kSheetDefaultPeekedWidth;

extern const CGFloat kSheetMenuWidth;
extern const CGFloat kStandardSheetWidth;
extern const CGFloat kSheetNotificationWidth;

typedef enum {
    kSheetLayoutFullScreen,
    kSheetLayoutFullAvailable,
    kSheetLayoutDefault,
    kSheetLayoutPeeked
} SheetLayoutType;

typedef enum {
    kSheetStackStateDefault,
    kSheetStackStateAdding,
    kSheetStackStateRemoving
} SheetStackState;

typedef enum {
    kSheetStackTop,
    kSheetStackFirstStacked,
    kSheetStackHidden
} SheetStackPosition;

@class SheetNavigationController;
@class SheetController;
@class SheetNavigationItem;

@interface SheetLayoutModel : NSObject

+ (SheetLayoutModel *) sharedInstance;
+ (void) resetSharedInstance;


@property (nonatomic, strong) SheetNavigationController *controller;
@property (nonatomic, assign) SheetStackState stackState;
@property (nonatomic, readonly) NSUInteger protectedCount;

- (void)incrementProtectedCount;
- (void)decrementProtectedCount;
- (NSUInteger)thresholdForDroppingSheets;
- (BOOL)shouldDropSheet;
- (void)updateNavItem:(SheetNavigationItem *)navItem;

- (CGFloat)desiredWidthForContent:(UIViewController *)viewController navItem:(SheetNavigationItem *)navItem;
- (CGFloat)widthForNavItem:(SheetNavigationItem *)navItem;
- (CGFloat)availableWidthForOffset:(CGFloat)offset;

+ (CGFloat)stickingEdgeForNavItem:(SheetNavigationItem *)navItem;
+ (CGRect)getScreenBoundsForCurrentOrientation;
+ (SheetLayoutType)layoutTypeForSheetController:(SheetController *)sheetController;
+ (NSTimeInterval)animateOnDuration;
+ (NSTimeInterval)animateOffDuration;
+ (BOOL)shouldShowLeftNavItem:(SheetNavigationItem *)navItem;

@end
