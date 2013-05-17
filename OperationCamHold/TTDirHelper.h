//
//  TTDirHelper.h
//  Tonto
//
//  Created by Quang Ngo on 2/05/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TTDirHelper : NSObject

+ (NSString *)documentDir;
+ (NSString *)documentDirWithRelativePath:(NSString *)relativePath;
+ (NSString *)documentDirWithRelativePath:(NSString *)relativePath createIfNotExist:(BOOL)createIfNotExist;

+ (NSString *)uniqueFileWithExtension:(NSString *)extension inDir:(NSString *)inDir;
+ (NSString *)fileWithKey:(NSString*)key andExtension:(NSString*)extension inDir:(NSString*)inDir;

@end
