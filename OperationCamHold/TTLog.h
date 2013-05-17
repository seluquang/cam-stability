//
//  TTLog.h
//  Tonto
//
//  Created by Quang Ngo on 12/05/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#import <Foundation/Foundation.h>

#define TTLogON() [TTLog on]
#define TTLogFilterCat(categories) [TTLog filterCategories:categories]
#define TTLog(format, ...) [TTLog log:format, ## __VA_ARGS__]
#define TTLogCat(category, format,...) [TTLog logCat:category form:format, ##__VA_ARGS__]


@interface TTLog : NSObject

+ (void)on;

+ (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

+ (void)logCat:(NSString *)category form:(NSString *)format, ... NS_FORMAT_FUNCTION(2,3);

+ (void)filterCategories:(NSArray *)categories;

@end
