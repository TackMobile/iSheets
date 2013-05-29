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

- (id)initWithType:(SheetLayoutType)layoutType
{
    if ((self = [super init])) {
        self.layoutType = layoutType;
        self.displayShadow = YES;
        self.width = -1;
        self.nextItemDistance = -1;
        _expanded = NO;
        _count = 0;
    }
    
    return self;
}

- (void)setCount:(NSUInteger)count {
    _count = count;
    self.offset = _count - _index;
}

- (void)setPeeked:(BOOL)peeked {
    _expanded = peeked;
}

- (UIView *)leftButtonView {
    if (self.offset == 1) {
        if ([self.sheetController.contentViewController respondsToSelector:@selector(leftButtonViewForTopPosition)]) {
            return [(id<SheetStackPage>)self.sheetController.contentViewController leftButtonViewForTopPosition];
        }
    } else {
        if ([self.sheetController.contentViewController respondsToSelector:@selector(leftButtonViewForStackedPosition)]) {
            return [(id<SheetStackPage>)self.sheetController.contentViewController leftButtonViewForStackedPosition];
        }
    }
    
    return _leftButtonView;
}

- (NSString *)description {
    NSString *desc = [NSString stringWithFormat:@"\nindex: %i\n",self.index];
    desc = [desc stringByAppendingFormat:@"count: %i\n",self.count];
    desc = [desc stringByAppendingFormat:@"offset: %i\n",self.offset];
    desc = [desc stringByAppendingFormat:@"width: %f\n",self.width];
    desc = [desc stringByAppendingFormat:@"expanded: %s\n",self.expanded ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"peeked width: %f\n",self.peekedWidth];
    desc = [desc stringByAppendingFormat:@"display shadow: %s\n",self.displayShadow ? "yes" : "no"];
    desc = [desc stringByAppendingFormat:@"layout type: %i\n",self.layoutType];
    desc = [desc stringByAppendingFormat:@"class: %@\n",NSStringFromClass([self.sheetController.contentViewController class])];
    desc = [desc stringByAppendingFormat:@"init view postion: %@\n",NSStringFromCGPoint(self.initialViewPosition)];
    desc = [desc stringByAppendingFormat:@"current view position: %@\n",NSStringFromCGPoint(self.currentViewPosition)];
    desc = [desc stringByAppendingFormat:@"next item distance: %f\n",self.nextItemDistance];
    
    return desc;
}

@end
