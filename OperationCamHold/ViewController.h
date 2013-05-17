//
//  ViewController.h
//  OperationCamHold
//
//  Created by Quang Ngo on 17/05/13.
//  Copyright (c) 2013 Tonto. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
{
    dispatch_queue_t _rawDataRecordingQueue;
}

@property (weak, nonatomic) IBOutlet UILabel *mrStartedLabel;
@property (weak, nonatomic) IBOutlet UILabel *mrLabel;
- (IBAction)mrStart:(id)sender;
- (IBAction)mrStop:(id)sender;


@property (weak, nonatomic) IBOutlet UILabel *avStartedLabel;
@property (weak, nonatomic) IBOutlet UILabel *avLabel;
- (IBAction)avStart:(id)sender;
- (IBAction)avStop:(id)sender;

@end
