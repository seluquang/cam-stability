//
//  TTMediaRecorder.h
//  Tonto
//
//  Created by Stu on 27/04/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

/*
 
 We need the following settings:
 
 - mode - photo / video / video stream
 - which camera(s) should be used
 - what quality level we should be recording at
 - 
 
 
 
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

enum kTTMediaRecorderMode {
    kTTMediaRecorderModeStillPhoto,
    kTTMediaRecorderModeStillPhotoSilent,
    kTTMediaRecorderModeVideo,
    kTTMediaRecorderModeStream
};

typedef void (^TTImageBlock)(NSURL *imageURL, NSString *key, NSDate *timeTaken);
typedef void (^TTVideoBlock)(NSURL *videoURL, NSString *key, NSDate *startTime, NSNumber *duration);
typedef void (^TTAudioBlock)(float averagePowerLevel);

@interface TTMediaRecorder : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate>

@property (assign) enum kTTMediaRecorderMode mode;
@property (assign) BOOL canUseFrontCamera;
@property (assign) BOOL canUseBackCamera;

+ (TTMediaRecorder *)sharedRecorder;

#pragma mark Video & Photo Configs
- (void)setPreferredFrontCameraSessionPreset:(NSString *)avCaptureSessionPreset;
- (void)setPreferredBackCameraSessionPreset:(NSString *)avCaptureSessionPreset;

#pragma mark Photos
- (void)startTakingPhotosEvery:(int)sec silent:(BOOL)silent;
- (void)stopTakingPhotos;
- (void)takePhoto:(BOOL)silent;

#pragma mark Photo Callback Blocks
- (void)addPhotoCallback:(TTImageBlock)block;
- (void)removePhotoCallback:(TTImageBlock)block;

#pragma mark Audio

/** Default is 0 (no threshold). If set, audio blocks will only get call if level is above threshold. */
@property (readwrite, nonatomic) double audioRecordIfAboveThreshold;

- (void)startSamplingAudioWithIntervalSecs:(double)intervalSecs;
- (void)stopSamplingAudio;

#pragma mark Audio Callback Blocks
- (void)addAudioCallback:(TTAudioBlock)block;
- (void)removeAudioCallback:(TTAudioBlock)block;

#pragma mark Video
- (void)startRecordingVideo;
- (void)startRecordingVideoWithPhotosEvery:(int)seconds;
- (void)stopRecordingVideo;

#pragma mark Video Callback Blocks
- (void)addVideoCallback:(TTVideoBlock)block;
- (void)removeVideoCallback:(TTVideoBlock)block;

@end
