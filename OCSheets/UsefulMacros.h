//
//  UsefulMacros.h
//  OpenClass
//
//  Created by Tony Hillerson on 5/11/12.
//  Copyright (c) 2012 Pearson Education. All rights reserved.
//

#define kLogout @"logout"
#define OCTextSeparator @" • "

#define kToolbarWidth 219
#define kToolbarWidthCollapsed 47

#define DEFINE_SHARED_INSTANCE_METHODS_ON_CLASS(klass) \
+ (klass *) sharedInstance; \
+ (void) resetSharedInstance; \


#define SHARED_INSTANCE_ON_CLASS_WITH_INIT_BLOCK(klass, block) \
__strong static klass *_sharedInstance; \
+ (klass *) sharedInstance { \
    if (_sharedInstance == nil) { \
        _sharedInstance = block(); \
        [[NSNotificationCenter defaultCenter] addObserver:self \
                                                 selector:@selector(resetSharedInstance) \
                                                     name:kLogout \
                                                   object:nil]; \
    } \
    return _sharedInstance; \
} \
+ (void) resetSharedInstance { \
    if ([_sharedInstance respondsToSelector:@selector(resetSharedInstance)]) {\
        [_sharedInstance performSelector:@selector(resetSharedInstance)];\
    }\
    _sharedInstance = nil; \
    [[NSNotificationCenter defaultCenter] removeObserver:self]; \
}

#define DEFINE_ABSTRACT_METHOD(returnType, name)\
- (returnType)name { @throw [NSException exceptionWithName:NSInternalInconsistencyException \
reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]\
userInfo:nil];\
}

#define IS_IPHONE_5 ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

static BOOL isIPhone() {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return YES;
    }
    return NO;
}

static NSString *addIPhoneSuffixWhenOnIPhone(NSString *resourceName) {
    if(isIPhone()) {
        return [resourceName stringByAppendingString:@"-iPhone"];
    }
    else {
        return resourceName;
    }
}

static BOOL isIOS5OrLess() {
    NSString *currentVersion = [[UIDevice currentDevice] systemVersion];
    NSArray *numbers = [currentVersion componentsSeparatedByString:@"."];
    if (numbers) {
        NSString *firstNumber = [numbers objectAtIndex:0];
        if ([firstNumber intValue] <= 5) {
            return YES;
        }
    }
    return NO;
}

static BOOL appBuiltWithPQAModeEnabled() {
#if PQA_MODE
    return YES;
#else
    return NO;
#endif
}

