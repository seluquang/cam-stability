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
        [self handleImageCreatedWithURL:imageURL key:key timeTaken:timeTaken];

        _mrLabel.text = [NSString stringWithFormat:@"p-proc: %@", [NSDate date]];
    }];
    
    [mr addVideoCallback:^(NSURL *videoURL, NSString *key, NSDate *startTime, NSNumber *duration) {
        [self handleVideoCreatedWithURL:videoURL key:key startTime:startTime duration:duration];

        _mrLabel.text = [NSString stringWithFormat:@"v-proc: %@", [NSDate date]];
    }];
    
    [mr addAudioCallback:^(float averagePowerLevel) {
        [self handleAudioSampleWithAveragePowerLevel:averagePowerLevel];
        //_mrLabel.text = [NSString stringWithFormat:@"a-proc: %@", [NSDate date]];
    }];
    
    _rawDataRecordingQueue = dispatch_queue_create("kTTCQueueDataRecording", DISPATCH_QUEUE_SERIAL);
}

- (void)handleImageCreatedWithURL:(NSURL *)url key:(NSString *)key timeTaken:(NSDate *)timeTaken {
    
    dispatch_async(_rawDataRecordingQueue, ^{
        
//        TTDeviceLocationManager *lm = [TTDeviceLocationManager sharedDeviceLocationManager];
//        [_rawDataRecorder addPhotoWithKey:key lat:lm.latitude lon:lm.longitude takenManually:NO];
//        
//        [[TTQueueManager sharedQueueManager] addInBackgroundWithItemName:kTTCQueueItemPhotoFile itemID:[url path]];
        TTLogCat(@"MR:Photo", @"addPhotoCallback:key:%@ timeTaken:%@", key, timeTaken);
    });
}


- (void)handleVideoCreatedWithURL:(NSURL *)videoURL key:(NSString *)key startTime:(NSDate *)startTime duration:(NSNumber *)duration
{
    dispatch_async(_rawDataRecordingQueue, ^{
        
//        TTDeviceLocationManager *lm = [TTDeviceLocationManager sharedDeviceLocationManager];
//        
//        [_rawDataRecorder addVideoWithKey:key lat:lm.latitude lon:lm.longitude takenManually:NO];
        TTLogCat(@"MR:Video", @"addVideoCallback:%@ key:%@ startTime:%@ duration:%f", videoURL, key, startTime, [duration floatValue]);
    });
};

- (void)handleAudioSampleWithAveragePowerLevel:(float)averagePowerLevel
{
    dispatch_async(_rawDataRecordingQueue, ^{
//        [_rawDataRecorder addSound:averagePowerLevel];
        TTLogCat(@"MR:Audio", @"addAudioCallback:%f", averagePowerLevel);
    });
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
