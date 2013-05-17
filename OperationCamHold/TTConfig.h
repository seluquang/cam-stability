//
//  TTCConfig.h
//  Tonto
//
//  Created by Quang Ngo on 2/05/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TTConfig : NSObject

+ (NSString *)dirImages;
+ (NSString *)dirVideos;
+ (NSString *)imageFileWithExtension:(NSString *)extension;
+ (NSString *)videoFileWithExtension:(NSString *)extension;
+ (NSString*)videoFileWithKey:(NSString*)key andExtension:(NSString*)extension;
+ (NSString*)imageFileWithKey:(NSString*)key andExtension:(NSString*)extension;

@end
