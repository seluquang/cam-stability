//
//  TTGCDTimer.m
//  Tonto
//
//  Created by Quang Ngo on 30/04/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#import "TTGCDTimer.h"

@implementation TTGCDTimer

- (void)dealloc
{
    dispatch_source_cancel(_timer);
    //dispatch_release(_timer);
}

- (void)startWithRepeatSeconds:(double)repeatSeconds handler:(dispatch_block_t)handler
{
    uint64_t interval = NSEC_PER_SEC * repeatSeconds;
    uint64_t leeway = NSEC_PER_SEC * 1;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                     0, 0, queue);
    if (timer)
    {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), interval, leeway);
        dispatch_source_set_event_handler(timer, handler);
        dispatch_resume(timer);
    }
    
    _timer = timer;
}

- (void)stop
{
    if(_timer)
        dispatch_source_cancel(_timer);
}

@end
