//
//  SheetViewController.h
//  OpenClass
//
//  Created by Ben Pilcher on 4/1/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SheetController.h"
#import "SheetNavigationItem.h"
#import "SheetLayoutModel.h"

@class SheetHistoryManager;

typedef void(^SheetNavigationConfigBlock)(SheetNavigationItem *item);

@protocol SheetNavigationControllerDelegate;
@protocol SheetStackPage;

@interface SheetNavigationController : UIViewController <UIGestureRecognizerDelegate>

@property (nonatomic, weak) id <SheetNavigationControllerDelegate> delegate;
@property (nonatomic) BOOL userInteractionEnabled;
@property (nonatomic, readonly) UIViewController *topSheetContentViewController;
@property (nonatomic, readonly, strong) SheetHistoryManager *historyManager;

- (id)initWithRootViewController:(UIViewController *)rootViewController configuration:(SheetNavigationConfigBlock)configuration;
- (id)initWithRootViewController:(UIViewController *)rootViewController peekedViewController:(UIViewController *)peekedViewController configuration:(SheetNavigationConfigBlock)configuration;

- (UIViewController *)peekedSheet;

- (void)preloadDefaultPeekedViewController;
- (void)peekDefaultViewController;
- (void)layoutPeekedViewControllers;
- (void)peekViewController:(UIViewController *)viewController;
- (void)popViewControllerAnimated:(BOOL)animated;
- (void)popToRootViewControllerAnimated:(BOOL)animated;
- (void)popToViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)pushViewController:(UIViewController *)contentViewController inFrontOf:(UIViewController *)anchorViewController maximumWidth:(BOOL)maxWidth animated:(BOOL)animated;
- (void)pushViewController:(UIViewController *)viewController inFrontOf:(UIViewController *)anchorViewController configuration:(SheetNavigationConfigBlock)configuration;

- (SheetController *)sheetControllerAtIndex:(NSUInteger)index;
- (UIViewController *)sheetAtIndex:(int)index;
- (BOOL)sheetIsAtBottom:(UIViewController *)sheet;
- (SheetNavigationItem *)next:(SheetController *)controller;
- (SheetNavigationItem *)sheetNavigationItemForSheet:(UIViewController *)vc;
- (BOOL)viewControllerIsPeeked:(UIViewController *)viewController;

/* number of sheets pushed (both in memory and dropped/placeholders) */
- (NSUInteger)count;
/* number of sheets with content in memory */
- (NSUInteger)inflatedCount;

@end

@protocol SheetNavigationControllerDelegate <NSObject>

@optional

- (void)sheetNavigationController:(SheetNavigationController*)controller
                 willMoveController:(UIViewController*)controller;
- (void)sheetNavigationController:(SheetNavigationController*)controller
               movingViewController:(UIViewController*)controller;
- (void)sheetNavigationController:(SheetNavigationController*)controller
                  didMoveController:(UIViewController*)controller;

@end

@protocol SheetStackPage <NSObject>

@optional

// determines overall layout during stacking
- (SheetLayoutType)sheetType;

- (void)willBeDropped;
- (void)didGetDropped;

- (void)willBeStacked;
- (void)didGetStacked;

- (void)willBeUnstacked;
- (void)beingUnstacked:(CGFloat)percentUnstacked;
- (void)didGetUnstacked;

/**
 Allow it to be dropped for memory purposes
*/
- (BOOL)isProtectedSheet;
/**
 Allow it to be dragged on its own or
 attached to a dragging sheet above it
 */
- (BOOL)isDraggableSheet;
/**
 Shouldn't really behave like a sheet, other than
 sitting in the sheet stack
 */
- (BOOL)isNonInteractiveSheet;

- (UIView *)leftButtonViewForTopPosition;
- (UIView *)leftButtonViewForStackedPosition;

// implement if different sheets need different offsets (ie gutters) from the left of the sheet
- (CGFloat)nextItemDistanceForSheetClass:(NSString *)sheetClass;

// implement if the sheet's content should be a specific width for different stacking positions
// and it's not subclassed from BasicSheetViewController.
// default is to stretch to fullscreen
- (CGFloat)desiredWidthForSheetPosition:(SheetStackPosition)position navItem:(SheetNavigationItem *)navItem;

// encode any data necessary for restoration of the sheet if dropped
- (NSMutableDictionary *)encodeRestorableState;
/**
 unencode previous state for restoration of the sheet
  */
- (void)decodeRestorableState:(NSDictionary *)archiveDict;

- (void)sheetNavigationControllerWillPanSheet;
- (void)sheetNavigationControllerPanningSheet;
- (void)sheetNavigationControllerDidPanSheet;

- (BOOL)showPeeked;
- (BOOL)showsDefaultPeekedViewController;

@end

@protocol SheetStackPeeking <NSObject>

- (void)willPeekOnTopOfSheet:(UIViewController *)sheet;

// Sheet did enter/exit peeked state
- (void)isPeeking:(BOOL)peeking onTopOfSheet:(UIViewController *)sheet;
- (BOOL)peeked;

@optional

/**
 An expanded peeked sheet was return to its peeked state
 */
- (void)didGetUnpeeked;
- (CGFloat)peekedWidth;
- (void)updateViewForPeeking;


@end

