//
//  TTCConfig.m
//  Tonto
//
//  Created by Quang Ngo on 2/05/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#import "TTConfig.h"
#import "TTDirHelper.h"

@implementation TTConfig

+ (void)initialize
{
    [TTDirHelper documentDirWithRelativePath:@"images" createIfNotExist:YES];
    [TTDirHelper documentDirWithRelativePath:@"videos" createIfNotExist:YES];
}

+ (NSString *)dirImages
{
    return [TTDirHelper documentDirWithRelativePath:@"images"];
}

+ (NSString *)dirVideos
{
    return [TTDirHelper documentDirWithRelativePath:@"videos"];
}

+ (NSString *)imageFileWithExtension:(NSString *)extension
{
    return [TTDirHelper uniqueFileWithExtension:extension inDir:[self dirImages]];
}

+ (NSString *)videoFileWithExtension:(NSString *)extension
{
    return [TTDirHelper uniqueFileWithExtension:extension inDir:[self dirVideos]];
}

+ (NSString*)videoFileWithKey:(NSString*)key andExtension:(NSString*)extension {
    return [TTDirHelper fileWithKey:key andExtension:extension inDir:[self dirVideos]];
}

+ (NSString*)imageFileWithKey:(NSString*)key andExtension:(NSString*)extension {
    return [TTDirHelper fileWithKey:key andExtension:extension inDir:[self dirImages]];
}

@end
