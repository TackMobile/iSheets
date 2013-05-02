//
//  OCAppDelegate.h
//  OCSheets
//
//  Created by Ben Pilcher on 5/2/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import <UIKit/UIKit.h>

@class OCViewController;

@interface OCAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) OCViewController *viewController;

@end
