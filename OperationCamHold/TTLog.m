//
//  TTLog.m
//  Tonto
//
//  Created by Quang Ngo on 12/05/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#import "TTLog.h"

@implementation TTLog

static BOOL _loggingOn;
static NSArray *_filterCategories;

+ (void)on
{
    _loggingOn = YES;
}

+ (void)log:(NSString *)format, ...
{
    if(!_loggingOn || _filterCategories)
        return;
    
    va_list argumentList;
    va_start(argumentList, format);
    
    NSMutableString * message = [[NSMutableString alloc] initWithFormat:format
                                                              arguments:argumentList];
    
    NSLog(message, argumentList);
    
    va_end(argumentList);
}

+ (void)logCat:(NSString *)category form:(NSString *)format, ...
{
    if(!_loggingOn || !_filterCategories || ![_filterCategories containsObject:category])
        return;
    
    va_list argumentList;
    va_start(argumentList, format);
    
    NSString * message = [[NSMutableString alloc] initWithFormat:format
                                                       arguments:argumentList];

    NSLog(@"%@: %@", category, message);
    
    va_end(argumentList);
}

+ (void)filterCategories:(NSArray *)categories
{
    _filterCategories = categories;
}


@end
