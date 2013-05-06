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

- (void)layeredNavigationController:(SheetNavigationController*)layeredController
                 willMoveController:(UIViewController*)controller;
- (void)layeredNavigationController:(SheetNavigationController*)layeredController
               movingViewController:(UIViewController*)controller;
- (void)layeredNavigationController:(SheetNavigationController*)layeredController
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

- (BOOL)isProtectedSheet;

- (UIView *)viewForLeftNavButton;

// implement if different sheets need different offsets (ie gutters) from the left of the sheet
- (CGFloat)nextItemDistanceForSheetClass:(NSString *)sheetClass;

// implement if the sheet's content should be a specific width for different stacking positions
// and it's not subclassed from BasicSheetViewController.
// default is to strecth to fullscreen
- (CGFloat)desiredWidthForSheetPosition:(SheetStackPosition)position navItem:(SheetNavigationItem *)navItem;

// encode any data necessary for restoration of the sheet if dropped
- (NSMutableDictionary *)encodeRestorableState;

// unencode previous state for restoration of the sheet
- (void)decodeRestorableState:(NSDictionary *)archiveDict;

// peloaded view controller peeking in 50px from right


@end

@protocol SheetStackPeeking <NSObject>

- (BOOL)shouldPeekDefaultSheet;
- (void)setPeeking:(BOOL)peeking;
- (BOOL)peeked;

@optional
- (void)didGetUnpeeked;
- (CGFloat)peekedWidth;
- (void)updateViewForPeeking;
- (BOOL)showsDefaultPeekedViewController;

@end

