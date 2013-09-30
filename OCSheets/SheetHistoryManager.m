//
//  SheetHistoryManager.m
//  OpenClass
//
//  Created by Ben Pilcher on 4/11/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "SheetHistoryManager.h"
#import "SheetController.h"

@implementation SheetHistoryManager

- (id)init {
    self = [super init];
    if (self) {
        _history = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) removeAllHistory {
    [_history removeAllObjects];
}

- (NSMutableDictionary *)historyItemAtIndex:(NSUInteger)index {
    return [_history objectAtIndex:index];
}

- (void)addHistoryItemForSheetController:(SheetController *)sheetController {
    NSMutableDictionary *archiveDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:sheetController.sheetNavigationItem,SheetNavigationItemKey,NSStringFromClass([sheetController.contentViewController class]),SheetClassKey,nil];
    if ([sheetController.contentViewController respondsToSelector:@selector(encodeRestorableState)]) {
        NSMutableDictionary *archiveDictForContent = [sheetController.contentViewController performSelector:@selector(encodeRestorableState)];
        if (archiveDictForContent != nil && archiveDictForContent.allKeys.count == 0) {
            NSLog(@"Warning: archive dict supplied by %@ has no data",NSStringFromClass([sheetController.contentViewController class]));
        }
        [archiveDict addEntriesFromDictionary:archiveDictForContent];
    }
    
    [_history addObject:archiveDict];
}

- (void)popHistoryItem {
    [_history removeLastObject];
}

- (void)updateHistoryItem:(NSDictionary *)item atIndex:(NSUInteger)index {
    [[_history objectAtIndex:index] addEntriesFromDictionary:item];
}

- (UIViewController *)restoredViewControllerForIndex:(NSUInteger)index {
    NSMutableDictionary *archiveDict = [_history objectAtIndex:index];
    NSString *myUIViewControllerClassName = [archiveDict objectForKey:SheetClassKey];
    Class myClass = NSClassFromString(myUIViewControllerClassName);
    NSObject *myObject = [myClass new];
    if( [myObject isKindOfClass:[UIViewController class]] ) {
        UIViewController *newViewController = (UIViewController *) myObject;

        return newViewController;
    }
    
    return nil;
}

- (NSUInteger)count {
    return _history.count;
}

- (void)logHistory {
    for (NSDictionary *dict in _history) {
        NSLog(@"sheet type %@",[dict objectForKey:SheetClassKey]);
    }
}

@end
