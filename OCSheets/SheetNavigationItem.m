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
    NSString *desc = [NSString stringWithFormat:@"\nindex: %i\n",self.index];
    desc = [desc stringByAppendingFormat:@"count: %i\n",self.count];
    desc = [desc stringByAppendingFormat:@"offset: %i\n",self.offset];
    desc = [desc stringByAppendingFormat:@"width: %f\n",self.width];
    desc = [desc stringByAppendingFormat:@"expanded: %s\n",self.expandedPeekedSheet ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"peeked width: %f\n",self.peekedWidth];
    desc = [desc stringByAppendingFormat:@"display shadow: %s\n",self.displayShadow ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"layout type: %i\n",self.layoutType];
    desc = [desc stringByAppendingFormat:@"class: %@\n",[self sheetContentClass]];
    desc = [desc stringByAppendingFormat:@"init view postion: %@\n",NSStringFromCGPoint(self.initialViewPosition)];
    desc = [desc stringByAppendingFormat:@"current view position: %@\n",NSStringFromCGPoint(self.currentViewPosition)];
    desc = [desc stringByAppendingFormat:@"next item distance: %f\n",self.nextItemDistance];
    desc = [desc stringByAppendingFormat:@"fullscreened: %s\n",self.fullscreen ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"is peeked sheet: %s\n",self.isPeekedSheet ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"offset Y: %f\n",self.offsetY];
    
    return desc;
}

- (NSString *)sheetContentClass {
    return [NSString stringWithFormat:@"%@[%i]",NSStringFromClass([self.sheetController.contentViewController class]),self.index];
}

//- (CGPoint)initialViewPosition {
//    if (self.layoutType == kSheetLayoutFullScreen) {
//        return CGPointMake(0, 0);
//    }
//    return _initialViewPosition;
//}

@end
