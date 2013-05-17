//
//  TTDirHelper.m
//  Tonto
//
//  Created by Quang Ngo on 2/05/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#import "TTDirHelper.h"
#import "TTNSString+Extensions.h"

@implementation TTDirHelper

+ (NSString *)documentDir
{
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [documentPaths objectAtIndex:0];
}

+ (NSString *)documentDirWithRelativePath:(NSString *)relativePath
{
    return [self documentDirWithRelativePath:relativePath createIfNotExist:NO];
}

+ (NSString *)documentDirWithRelativePath:(NSString *)relativePath createIfNotExist:(BOOL)createIfNotExist
{
    NSString *path = [[self documentDir] stringByAppendingPathComponent:relativePath];

    if(!createIfNotExist)
        return path;
    
    BOOL isDir;
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if(![fm fileExistsAtPath:path isDirectory:&isDir]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    if(error)
        NSLog(@"TTDirHelper: unable to create dir with path %@. %@", path, error.localizedDescription);
    
    return path;
}

+ (NSString *)uniqueFileWithExtension:(NSString *)extension inDir:(NSString *)inDir
{
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", [NSString uuid], extension];
    return [inDir stringByAppendingPathComponent:fileName];
}

+ (NSString *)fileWithKey:(NSString*)key andExtension:(NSString*)extension inDir:(NSString*)inDir {
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", key, extension];
    return [inDir stringByAppendingPathComponent:fileName];
}

@end
