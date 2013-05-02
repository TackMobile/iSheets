//
//  SheetLayoutManager.h
//  OpenClass
//
//  Created by Ben Pilcher on 4/14/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UsefulMacros.h"

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
    kSheetLayoutDefault
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

DEFINE_SHARED_INSTANCE_METHODS_ON_CLASS(SheetLayoutModel);

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
- (CGFloat)viewWidthForSheetClassName:(NSString *)sheetClass;

+ (CGFloat)stickingEdgeForNavItem:(SheetNavigationItem *)navItem;
+ (CGRect)getScreenBoundsForCurrentOrientation;
+ (SheetLayoutType)layoutTypeForSheetController:(SheetController *)sheetController;

@end