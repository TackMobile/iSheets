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
@property (nonatomic, assign) BOOL hasModalViewController;

- (id)initWithRootViewController:(UIViewController *)rootViewController configuration:(SheetNavigationConfigBlock)configuration;
- (id)initWithRootViewController:(UIViewController *)rootViewController peekedViewController:(UIViewController *)peekedViewController configuration:(SheetNavigationConfigBlock)configuration;

- (UIViewController *)peekedSheet;
- (void)setSheetFullscreen:(BOOL)fullscreen completion:(void(^)())completion;
- (void)addDefaultPeekedViewController;
- (void)peekDefaultViewController;
- (void)layoutPeekedViewControllers;
- (void)peekViewController:(UIViewController *)viewController;
- (void)popViewControllerAnimated:(BOOL)animated;
- (void)popToRootViewControllerAnimated:(BOOL)animated;
- (void)popToViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)pushViewController:(UIViewController *)contentViewController inFrontOf:(UIViewController *)anchorViewController maximumWidth:(BOOL)maxWidth animated:(BOOL)animated;
- (void)pushViewController:(UIViewController *)viewController inFrontOf:(UIViewController *)anchorViewController configuration:(SheetNavigationConfigBlock)configuration;
- (void) forceCleanup;
    
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

- (CGRect)contentFrame;

@end

@protocol SheetNavigationControllerDelegate <NSObject>

@optional

- (void)sheetNavigationControllerWillAddSheet;
- (void)sheetNavigationControllerDidAddSheet;
- (void)sheetNavigationControllerDidRemoveSheet;
- (void)sheetNavigationController:(SheetNavigationController*)controller willMoveController:(UIViewController*)controller;
- (void)sheetNavigationController:(SheetNavigationController*)controller movingViewController:(UIViewController*)controller percentMoved:(float)percentMoved;
- (void)sheetNavigationController:(SheetNavigationController*)controller didMoveController:(UIViewController*)controller;

@end

@protocol SheetStackPage <NSObject>

@optional

// determines overall layout during stacking
- (SheetLayoutType)sheetType;

/**
 Sheet will be popped or dragged off the top of the stack
 */
- (void)sheetWillBeDismissed;

/**
 Sheet's content will be dropped out of memory and archived
 */
- (void)sheetWillBeDropped;

/**
 Sheet's content did get dropped out of memory and archived
 */
- (void)sheetDidGetDropped;

#pragma mark - Appearance callbacks for first stacked-on sheet

- (void)sheetNavItemTapped;

/**
 Top sheet will be covered (will have offset 2)
 */
- (void)sheetWillBeStacked;

/**
 Top sheet did get covered (now has offset 2)
 */
- (void)sheetDidGetStacked;

/**
 A stacked sheet (offset 2) will be uncovered ie returned to top position (offset 1). Generally 
 only UI updates should be peformed here. The user could still cancel their panning 
 gesture, after which the sheet will still be stacked on top of
 */
- (void)sheetWillBeUnstacked;

/**
 Stacked sheet is being uncovered
 */
- (void)sheetBeingUnstacked:(CGFloat)percentUnstacked;

/**
 Stacked sheet did get uncovered
 */
- (void)sheetDidGetUnstacked;

#pragma mark -

/**
 Allow it to be dropped for memory purposes
*/
- (BOOL)isProtectedSheet;

/**
 Allow it to be dragged on its own or attached to a dragging sheet above it
 */
- (BOOL)isDraggableSheet;

/**
 Shouldn't really behave like a sheet, other than
 sitting in the sheet stack
 */
- (BOOL)isNonInteractiveSheet;

- (UIView *)leftButtonViewForTopSheet;
- (UIView *)leftButtonViewForStackedSheet;

/**
 implement if different sheets need different offsets (ie gutters) from the left of the sheet
 */
- (CGFloat)nextItemDistanceForSheetClass:(NSString *)sheetClass;

/**
 implement if the sheet's content should be a specific width for different stacking positions
 and it's not subclassed from BasicSheetViewController.
 default is to stretch to fullscreen
  */
- (CGFloat)desiredWidthForSheetPosition:(SheetStackPosition)position navItem:(SheetNavigationItem *)navItem;

/**
 save any data necessary for restoration of the sheet if dropped
 */
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

/**
 callback to allow peeked sheet to update it's content
 when it's about to reappear between full sheet changes
 @param sheet Top sheet that is partially covered by the peeked sheet
 */
- (void)willPeekOnTopOfSheet:(UIViewController *)topSheet;

- (void)prepareContents;

/**
 Sheet did enter/exit peeked state
 This is where we add a transparent view on top of a peeked sheet's
 content to disable any user interaction
 */
- (void)isPeeking:(BOOL)peeking onTopOfSheet:(UIViewController *)topSheet;

/**
 Get current peeked state
 @param sheet Top sheet that is partially covered by the peeked sheet
 */
- (BOOL)peeked;

/**
 Allow the sheet to specify its readiness to appear
 */
- (BOOL)readyToPeek;

/**
 Notifies sheet it's about to be dragged */
- (void)sheetNavigationController:(SheetNavigationController*)navController
               willMoveController:(SheetController *)sheetController;

@optional

/**
 An expanded peeked sheet was returned to its peeked state
 */
- (void)didGetUnpeeked;
- (CGFloat)peekedWidth;
- (void)updateViewForPeeking;


@end

