//
//  TTNSString+Extensions.h
//  tonto-ios-sdk
//
//  Created by Quang Ngo on 4/04/13.
//  Copyright (c) 2013 Tonto. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Extensinos)

+ (NSString *)uuid;
+ (NSString *)mimeTypeForFileExtension:(NSString *)fileExtension;
- (NSString *)stringFromMD5;

@end
