//
//  TTNSString+Extensions.m
//  tonto-ios-sdk
//
//  Created by Quang Ngo on 4/04/13.
//  Copyright (c) 2013 Tonto. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import <CommonCrypto/CommonDigest.h>

@implementation  NSString (Extensinos)

+ (NSString *)uuid
{
    NSString *result = nil;
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    result = (__bridge NSString *)CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return [result lowercaseString];
}

+ (NSString *)mimeTypeForFileExtension:(NSString *)fileExtension
{
    if ([fileExtension length] == 0)
        return nil;
    
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);
    CFStringRef mimeType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!mimeType) {
        return @"application/octet-stream";
    }
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault
                                                                                 ,(CFStringRef)mimeType, NULL, NULL, kCFStringEncodingUTF8));
}

- (NSString *)stringFromMD5{
    
    if(self == nil || [self length] == 0)
        return nil;
    
    const char *value = [self UTF8String];
    
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, strlen(value), outputBuffer);
    
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [outputString appendFormat:@"%02x",outputBuffer[count]];
    }
    
    return outputString;
}

@end
