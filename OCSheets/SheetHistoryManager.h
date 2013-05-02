//
//  SheetHistoryManager.h
//  OpenClass
//
//  Created by Ben Pilcher on 4/11/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SheetNavigationItemKey @"navItem"
#define SheetClassKey @"sheetClass"

@class SheetController;

@interface SheetHistoryManager : NSObject

@property (nonatomic, strong) NSMutableArray *history;

- (NSMutableDictionary *)historyItemAtIndex:(NSUInteger)index;
- (void)addHistoryItemForSheetController:(SheetController *)sheetController;
- (void)updateHistoryItem:(NSDictionary *)item atIndex:(NSUInteger)index;
- (void)popHistoryItem;
- (NSUInteger)count;
- (UIViewController *)restoredViewControllerForIndex:(NSUInteger)index;

@end
