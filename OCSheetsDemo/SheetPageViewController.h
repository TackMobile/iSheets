//
//  SheetPageViewController.h
//  OpenClass
//
//  Created by Ben Pilcher on 4/1/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SheetNavigationController.h"
#import "BasicSheetViewController.h"

@interface SheetPageViewController : BasicSheetViewController

@property (nonatomic, copy) NSString *pageTitle;
@property (weak, nonatomic) IBOutlet UILabel *pageLabel;

- (IBAction)pushSheetPage:(id)sender;
- (IBAction)popCurrent:(id)sender;
- (IBAction)popToRoot:(id)sender;

@end
