//
//  ViewController.m
//  OperationCamHold
//
//  Created by Quang Ngo on 17/05/13.
//  Copyright (c) 2013 Tonto. All rights reserved.
//

#import "ViewController.h"
#import "TTMediaRecorder.h"
#import "TTLog.h"

@interface ViewController ()
{
    
}

@end

@implementation ViewController

@synthesize mrStartedLabel = _mrStartedLabel;
@synthesize mrLabel = _mrLabel;
@synthesize avStartedLabel = _avStartedLabel;
@synthesize avLabel = _avLabel;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    ///////////// LOGS
    TTLogON();
    
    NSArray *logFilters =
    @[
      @"MR",
      @"MR:Photo",
      @"MR:Video",
      ];
    
    TTLogFilterCat(logFilters);
    
    ///////////// MR HANDLERS
    TTMediaRecorder *mr = [TTMediaRecorder sharedRecorder];
    [mr setPreferredBackCameraSessionPreset:AVCaptureSessionPreset640x480];
    [mr setPreferredFrontCameraSessionPreset:AVCaptureSessionPreset640x480];
    
    [mr addPhotoCallback:^(NSURL *imageURL, NSString *key, NSDate *timeTaken) {
        TTLogCat(@"MR:Photo", @"addPhotoCallback:key:%@ timeTaken:%@", key, timeTaken);
        _mrLabel.text = [NSString stringWithFormat:@"p-proc: %@", [NSDate date]];
    }];
    
    [mr addVideoCallback:^(NSURL *videoURL, NSString *key, NSDate *startTime, NSNumber *duration) {
        TTLogCat(@"MR:Video", @"addVideoCallback:%@ key:%@ startTime:%@ duration:%f", videoURL, key, startTime, [duration floatValue]);
        _mrLabel.text = [NSString stringWithFormat:@"v-proc: %@", [NSDate date]];
    }];
    
    [mr addAudioCallback:^(float averagePowerLevel) {
        TTLogCat(@"MR:Audio", @"addAudioCallback:%f", averagePowerLevel);
        //_mrLabel.text = [NSString stringWithFormat:@"a-proc: %@", [NSDate date]];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)mrStart:(id)sender
{
    [[TTMediaRecorder sharedRecorder] startRecordingVideoWithPhotosEvery:6];
    [[TTMediaRecorder sharedRecorder] startSamplingAudioWithIntervalSecs:0.1];
    
    _mrStartedLabel.text = [NSString stringWithFormat:@"started: %@", [NSDate date]];
    TTLogCat(@"MR", @"MR Started");
}

- (IBAction)mrStop:(id)sender
{
    [[TTMediaRecorder sharedRecorder] stopRecordingVideo];
    [[TTMediaRecorder sharedRecorder] stopSamplingAudio];
    TTLogCat(@"MR", @"MR Stopped");
}

- (IBAction)avStart:(id)sender
{
    _avStartedLabel.text = [NSString stringWithFormat:@"started: %@", [NSDate date]];
    TTLogCat(@"AV", @"AV Started");
}

- (IBAction)avStop:(id)sender
{
    TTLogCat(@"AV", @"AV Stopped");
}

- (void)viewDidUnload {
    [self setMrLabel:nil];
    [self setAvLabel:nil];
    [self setAvStartedLabel:nil];
    [self setMrStartedLabel:nil];
    [super viewDidUnload];
}

@end
