//
//  UIViewController+SheetNavigationController.h
//  OpenClass
//
//  Created by Jacob Henry on 4/5/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SheetNavigationController.h"
#import <objc/runtime.h>

@interface UIViewController (SheetNavigationController)

/**
 * The nearest ancestor in the view controller hierarchy that is a SheetNavigationController.
 */
@property (nonatomic, readonly, strong) SheetNavigationController *sheetNavigationController;
@property (nonatomic, readonly, strong) SheetNavigationItem *sheetNavigationItem;

@end

@implementation UIViewController (SheetNavigationController)

- (SheetNavigationController *)sheetNavigationController
{
    UIViewController *here = self;
    
    while (here != nil) {
        if([here isKindOfClass:[SheetNavigationController class]]) {
            return (SheetNavigationController *)here;
        }
        
        here = here.parentViewController;
    }
    
    return nil;
}

- (SheetNavigationItem *)sheetNavigationItem {
    SheetNavigationItem *navItem = [self.sheetNavigationController sheetNavigationItemForSheet:self];
    if (navItem != nil) {
        return navItem;
    } else {
        if ([self.parentViewController isKindOfClass:[SheetController class]]) {
            return [(SheetController *)self.parentViewController sheetNavigationItem];
        }
    }
    
    return nil;
}

@end

