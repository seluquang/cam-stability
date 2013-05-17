//
//  TTGCDTimer.h
//  Tonto
//
//  Created by Quang Ngo on 30/04/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TTGCDTimer : NSObject
{
    dispatch_source_t _timer;
}

- (void)startWithRepeatSeconds:(double)repeatSeconds handler:(dispatch_block_t)handler;
- (void)stop;

@end
