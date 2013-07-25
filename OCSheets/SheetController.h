//
//  SheetController.h
//  OpenClass
//
//  Created by Ben Pilcher on 4/5/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SheetNavigationController.h"

@class SheetNavigationItem;

@interface SheetController : UIViewController

@property (nonatomic, readonly, strong) SheetNavigationItem *sheetNavigationItem;
@property (nonatomic, strong) UIViewController *contentViewController;
@property (nonatomic, readonly) BOOL maximumWidth;
@property (nonatomic, readonly) BOOL isRestored;
@property (nonatomic, strong) UIView *coverView;

- (id)initWithContentViewController:(UIViewController *)contentViewController  maximumWidth:(BOOL)maxWidth;
- (void)dumpContentViewController;

- (void)animateInCoverView;
- (void)prepareCoverViewForNewSheetWithCurrentAlpha:(BOOL)current;

@end
