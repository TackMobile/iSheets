//
//  SheetNavigationItem.h
//  OpenClass
//
//  Created by Ben Pilcher on 4/5/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "SheetLayoutModel.h"

@class SheetController;

@interface SheetNavigationItem : NSObject

/**
 * The view controller's index within the stack
 */
@property (nonatomic, assign) NSUInteger index;

/**
 * The current count of the sheet stack
 */
@property (nonatomic, assign) NSUInteger count;

/**
 * The current count of the sheet stack
 */
@property (nonatomic, assign) BOOL expanded;
/**
 * How much of a sheet you see in in its peeked state
 */
@property (nonatomic, assign) CGFloat peekedWidth;
/**
 * Controls the width and behavior of the sheet
 */
@property (nonatomic, assign) SheetLayoutType layoutType;

/**
 * Offset from top of stack. Non-zero indexed (1 means sheet is on top)
 */
@property (nonatomic, readonly) NSUInteger offset;

/**
 * Whether a sheet with a peeked sheet is hiding or showing it currently
 */
@property (nonatomic, getter=isShowingPeeked) BOOL showingPeeked;


/**
 * All remaining properties below are documented in FRLayeredNavigationItem
 */
@property (nonatomic, assign) CGPoint initialViewPosition;
@property (nonatomic, assign) CGPoint currentViewPosition;
@property (nonatomic, assign) CGFloat nextItemDistance;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) BOOL displayShadow;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) UIView *leftButtonView;

@property (nonatomic, weak) SheetController *sheetController;

- (id)initWithType:(SheetLayoutType)layoutType;

@end
