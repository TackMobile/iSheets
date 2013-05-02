//
//  BasicSheetViewController.h
//  OpenClass
//
//  Created by Ben Pilcher on 4/17/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SheetNavigationController.h"
#import "UIViewController+SheetNavigationController.h"

@interface BasicSheetViewController : UIViewController <SheetStackPage,SheetStackPeeking>

@property (nonatomic, strong) UIViewController *peekedViewController;

- (void)pushNewSheet:(UIViewController *)vc;
- (void)peekSheet:(UIViewController *)vc animated:(BOOL)animated;

// TODO: needed?
- (NSNumber *)widthForSheetPosition:(NSNumber *)position navItem:(SheetNavigationItem *)navItem;

@end
