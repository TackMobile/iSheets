//
//  SheetNavigationItem.m
//  OpenClass
//
//  Created by Ben Pilcher on 4/5/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "SheetNavigationItem.h"
#import "SheetController.h"

@interface SheetNavigationItem()

@property (nonatomic, assign) NSUInteger offset;

@end

@implementation SheetNavigationItem

@synthesize leftButtonView=_leftButtonView;

- (id)initWithType:(SheetLayoutType)layoutType
{
    if ((self = [super init])) {
        _layoutType = layoutType;
        _displayShadow = YES;
        _width = -1;
        _nextItemDistance = -1;
        _offsetY = -1;
        _showingPeeked = YES;
        _expandedPeekedSheet = NO;
        _isPeekedSheet = NO;
        _count = 0;
    }
    
    return self;
}

- (void)setCount:(NSUInteger)count {
    _count = count;
    self.offset = _count - _index;
}

- (void)setExpandedPeeked:(BOOL)expandedPeeked {
    _expandedPeekedSheet = expandedPeeked;
}

- (NSString *)description {
    NSString *desc = [NSString stringWithFormat:@"\nsheet count: %i, nav item index: %i, offset: %i\n",self.count,self.index,self.offset];
    desc = [desc stringByAppendingFormat:@"width: %f, peeked width: %f\n",self.width, self.peekedWidth];
    desc = [desc stringByAppendingFormat:@"layout type: %@\n",[self layoutName]];
    desc = [desc stringByAppendingFormat:@"class: %@\n",[self sheetContentClass]];
    desc = [desc stringByAppendingFormat:@"expanded: %s\n",self.expandedPeekedSheet ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"is peeked sheet: %s\n",self.isPeekedSheet ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"init view postion: %@\n",NSStringFromCGPoint(self.initialViewPosition)];
    desc = [desc stringByAppendingFormat:@"current view position: %@\n",NSStringFromCGPoint(self.currentViewPosition)];
    desc = [desc stringByAppendingFormat:@"next item distance: %f\n",self.nextItemDistance];
    desc = [desc stringByAppendingFormat:@"fullscreened: %s\n",self.fullscreen ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"display shadow: %s\n",self.displayShadow ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"offset Y: %f\n",self.offsetY];
    
    return desc;
}

- (NSString *)layoutName {
    switch (self.layoutType) {
        case kSheetLayoutFullScreen:
            return @"FullScreen";
            break;
        case kSheetLayoutFullAvailable:
            return @"FullAvailable";
            break;
        case kSheetLayoutDefault:
            return @"Default";
            break;
        case kSheetLayoutPeeked:
            return @"Peeked";
            break;
        default:
            break;
    }
    return @"";
}

- (NSString *)sheetContentClass {
    return [NSString stringWithFormat:@"%@[%i]",NSStringFromClass([self.sheetController.contentViewController class]),self.index];
}

@end
