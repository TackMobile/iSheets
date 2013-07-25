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
 * Controls the width and layout behavior of the sheet
 */
@property (nonatomic, assign) SheetLayoutType layoutType;

/**
 * Offset from top of stack. Non-zero indexed (1 means sheet is on top)
 */
@property (nonatomic, readonly) NSUInteger offset;

#pragma mark - Peeked sheet

/**
 * Expanded state of a peeked sheet (is open and interactive)
 */
@property (nonatomic, assign) BOOL expandedPeekedSheet;

/**
 * How much of a sheet you see in in its non-interactive peeked state
 */
@property (nonatomic, assign) CGFloat peekedWidth;

/**
 * Whether a sheet with a peeked sheet on top of it 
 is currently hiding or showing it 
 */
@property (nonatomic, getter=isShowingPeeked) BOOL showingPeeked;

/**
 * Whether a sheet with non-fullscreen layout has been set temporarily fullscreen
 */
@property (nonatomic, getter=isFullscreened) BOOL fullscreen;

/**
 Set visibility of left navigation button
 */
@property (nonatomic, assign) BOOL hidden;

/**
 Set position Y of left navigation button
 */
@property (nonatomic, assign) float offsetY;

/**
 Whether sheet is a peeked sheet
 */
@property (nonatomic, assign) BOOL isPeekedSheet;

#pragma mark - FRLayeredNavigationItem properties
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
