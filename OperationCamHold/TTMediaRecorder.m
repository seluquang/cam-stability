//
//  TTMediaRecorder.m
//  Tonto
//
//  Created by Stu on 27/04/13.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#include <sys/xattr.h>
#import "TTMediaRecorder.h"
#import <ImageIO/ImageIO.h>
#import "TTGCDTimer.h"
#import "TTNSString+Extensions.h"
#import "TTConfig.h"
#import "TTLog.h"

@implementation TTMediaRecorder
{
    BOOL hasFrontCamera;
    BOOL hasBackCamera;
    BOOL isUsingFrontCamera;
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    AVCaptureSession *session;
    AVCaptureStillImageOutput *noisyPhotoOutput;
    AVCaptureVideoDataOutput *silentPhotoOutput;
    AVCaptureVideoDataOutput *videoOutput;
    AVCaptureAudioDataOutput *audioOutput;
    AVCaptureMovieFileOutput *fileOutput;
    
    AVAssetWriter *videoWriter;
    AVAssetWriter *videoWriterFinished;
    
    AVAssetWriterInput *videoWriterInput;
    AVAssetWriterInput *audioWriterInput;
    
    dispatch_queue_t audioQueue;
    dispatch_queue_t videoQueue;
    
    NSMutableArray *photoCallbackBlocks;
    NSMutableArray *videoCallbackBlocks;
    
    int photoFrequencySec;
    NSDate *nextPhotoDue;
    NSDate *nextSegmentDue;
    
    AVAssetImageGenerator *imgGen;
    
    AVCaptureInput *currentVideoInput;
    AVCaptureInput *currentAudioInput;
    AVCaptureOutput *currentOutput;
    
    NSString *_currentVideoKey;
    NSDate *_currentVideoStartTime;
    NSString *_preferredFrontCameraSessionPreset;
    NSString *_preferredBackCameraSessionPreset;
    
    TTGCDTimer *_audioSamplingTimer;
    NSMutableArray *_audioCallbackBlocks;
    
    BOOL isTakingPhoto;
}

@synthesize mode = _mode;
@synthesize audioRecordIfAboveThreshold = _audioRecordIfAboveThreshold;

+ (TTMediaRecorder *)sharedRecorder
{
    static dispatch_once_t pred;
    static TTMediaRecorder *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[TTMediaRecorder alloc] init];
    });
    
    return shared;
}

- (id)init {
    self = [super init];
    if (self) {
        
        hasBackCamera = [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
        hasFrontCamera = [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
        isUsingFrontCamera = NO;
        self.canUseFrontCamera = YES;
        self.canUseBackCamera = YES;
        
        // Get all cameras
        NSArray *allCameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        
        // Assign available camera devices
        for ( int i = 0; i < allCameras.count; i++ ) {
            AVCaptureDevice *camera = [allCameras objectAtIndex:i];
            if (camera.position == AVCaptureDevicePositionFront) {
                frontCamera = camera;
            }
            if (camera.position == AVCaptureDevicePositionBack) {
                backCamera = camera;
            }
        }
        
        // create processing queue
        audioQueue = dispatch_queue_create("audioQueue", DISPATCH_QUEUE_PRIORITY_DEFAULT);
        videoQueue = dispatch_queue_create("videoQueue", DISPATCH_QUEUE_PRIORITY_DEFAULT);
        
        // audio timer
        _audioSamplingTimer = [[TTGCDTimer alloc] init];
        
    }
    return self;
}

- (void)selectOutput {
    [session beginConfiguration];
    [session removeOutput:currentOutput];
    
    switch (_mode) {
        case kTTMediaRecorderModeStillPhoto:
        {
            noisyPhotoOutput = [[AVCaptureStillImageOutput alloc] init];
            [session addOutput:noisyPhotoOutput];
            break;
        }
        case kTTMediaRecorderModeStillPhotoSilent:
        {
            silentPhotoOutput = [[AVCaptureVideoDataOutput alloc] init];
            NSDictionary *settings = @{(NSString*)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
            [silentPhotoOutput setVideoSettings:settings];
            [session addOutput:silentPhotoOutput];
            break;
        }
        case kTTMediaRecorderModeVideo:
        {
            fileOutput = [[AVCaptureMovieFileOutput alloc] init];
            [session addOutput:fileOutput];
            break;
        }
        default:
            break;
    }
    
    [session commitConfiguration];
}

-(BOOL) setupWriter:(NSURL *)videoURL session:(AVCaptureSession *)captureSessionLocal
{
    NSError *error = nil;
    
    AVAssetWriter *tempVideoWriter = [[AVAssetWriter alloc] initWithURL:videoURL fileType:AVFileTypeQuickTimeMovie
                                                                  error:&error];
    NSParameterAssert(tempVideoWriter);
    
    
    // Add video input
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:640], AVVideoWidthKey,
                                   [NSNumber numberWithInt:480], AVVideoHeightKey,
                                   nil];
    
    videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                          outputSettings:videoSettings];
    
    
    NSParameterAssert(videoWriterInput);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    
    // Add the audio input
    AudioChannelLayout acl;
    bzero( &acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    
    
    NSDictionary* audioOutputSettings = nil;
    
    // Both type of audio inputs causes output video file to be corrupted.
    // should work on any device requires more space
    audioOutputSettings = [ NSDictionary dictionaryWithObjectsAndKeys:
                           [ NSNumber numberWithInt: kAudioFormatAppleLossless ], AVFormatIDKey,
                           [ NSNumber numberWithInt: 16 ], AVEncoderBitDepthHintKey,
                           [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                           [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                           [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                           nil ];
    
    audioWriterInput = [AVAssetWriterInput
                        assetWriterInputWithMediaType: AVMediaTypeAudio
                        outputSettings: audioOutputSettings ];
    
    audioWriterInput.expectsMediaDataInRealTime = YES;
    
    // add input
    [tempVideoWriter addInput:videoWriterInput];
    [tempVideoWriter addInput:audioWriterInput];
    
    videoWriter = tempVideoWriter;
    
    return YES;
}

- (void)selectInput {
    
    [session beginConfiguration];
    [session removeInput:currentVideoInput];
    [session removeInput:currentAudioInput];
    
    [session setSessionPreset:AVCaptureSessionPresetMedium];
    
    NSError *error = nil;
    
    if (hasBackCamera && self.canUseBackCamera && !isUsingFrontCamera) {
        AVCaptureDeviceInput *backInput =
        [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        currentVideoInput = backInput;
        [session addInput:backInput];
    }
    
    if (hasFrontCamera && self.canUseFrontCamera && isUsingFrontCamera) {
        AVCaptureDeviceInput *frontInput =
        [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        currentVideoInput = frontInput;
        [session addInput:frontInput];
    }
    
    if (_mode == kTTMediaRecorderModeVideo || _mode == kTTMediaRecorderModeStream) {
        
        AVCaptureDevice *audioCapture = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioCapture error:nil];
        currentAudioInput = audioInput;
        [session addInput:audioInput];
    }
    
    
    
    [session commitConfiguration];
}

- (void)startInMode:(enum kTTMediaRecorderMode)mode {
    
    
    if ([session isRunning]) {
        [self stop];
    }
    
    _mode = mode;
    
    session =  [[AVCaptureSession alloc] init];
    
    [self selectInput];
    [self selectOutput];
    
    [session startRunning];
}

- (void)pause {
    [session stopRunning];
}

- (void)resume {
    [session startRunning];
}

- (void)stop {
    
    [session stopRunning];
    
    if (fileOutput) {
        [fileOutput stopRecording];
    }
    
    [videoOutput setSampleBufferDelegate:nil queue:nil];
    
    videoOutput = nil;
    noisyPhotoOutput = nil;
    silentPhotoOutput = nil;
    currentOutput = nil;
    
    fileOutput = nil;
    
    currentAudioInput = nil;
    currentVideoInput = nil;
    
    session = nil;
    
    
}

- (void)toggleLight {
    
    if (isTakingPhoto) {
        return;
    }
    
    // Start session configuration
    [session beginConfiguration];
    [backCamera lockForConfiguration:nil];
    
    if ([backCamera torchMode] == AVCaptureTorchModeOff) {
        [backCamera setTorchMode:AVCaptureTorchModeOn];
    } else {
        [backCamera setTorchMode:AVCaptureTorchModeOff];
    }
    
    [backCamera unlockForConfiguration];
    [session commitConfiguration];
}

-(void) switchInputs
{
    if (![session isRunning]) {
        return;
    }
    if(backCamera && frontCamera) {
        isUsingFrontCamera = !isUsingFrontCamera;
        [self selectInput];
    }
}

#pragma mark Video & Photo Configs
- (void)setPreferredFrontCameraSessionPreset:(NSString *)avCaptureSessionPreset
{
    _preferredFrontCameraSessionPreset = avCaptureSessionPreset;
}

- (void)setPreferredBackCameraSessionPreset:(NSString *)avCaptureSessionPreset
{
    _preferredBackCameraSessionPreset = avCaptureSessionPreset;
}

#pragma mark Photos

- (void)startTakingPhotosEvery:(int)sec silent:(BOOL)silent {
    if(!hasFrontCamera && !hasBackCamera)
    {
        TTLogCat(@"TTMediaRecorder", @"device has no cameras.");
        return;
    }
    
    if (silent) {
        [self startInMode:kTTMediaRecorderModeStillPhotoSilent];
    } else {
        [self startInMode:kTTMediaRecorderModeStillPhoto];
    }
    [self repeatedTakePhotosWithRepeatDelay:sec];
}

- (void)stopTakingPhotos
{
    if(!hasFrontCamera && !hasBackCamera)
    {
        TTLogCat(@"TTMediaRecorder", @"device has no cameras.");
        return;
    }
    
    [self stop];
}



- (void)repeatedTakePhotosWithRepeatDelay:(int)sec {
    // stop repeating if the session has ended
    if (![session isRunning]) {
        return;
    }
    if (_mode == kTTMediaRecorderModeStillPhotoSilent || _mode == kTTMediaRecorderModeVideo) {
        // take lower quality photo but silently using a video frame
        [silentPhotoOutput setSampleBufferDelegate:self queue:videoQueue];
        double delayInSeconds = sec;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self switchInputs];
            [self repeatedTakePhotosWithRepeatDelay:sec];
        });
    } else {
        // take higher quality photo using still image capture, but may make a noise
        [self takeNoisyPhoto:^(UIImage *image) {
            [self savePhotoAndPerformPhotoCallbacksWithImage:image timeTaken:[NSDate date]];
            double delayInSeconds = sec;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self repeatedTakePhotosWithRepeatDelay:sec];
            });
        }];
    }
    
}

- (void)takePhoto:(BOOL)silent {
    if(!hasFrontCamera && !hasBackCamera)
    {
        TTLogCat(@"TTMediaRecorder", @"device has no cameras.");
        return;
    }
    
    if (silent == NO) {
        [self takeNoisyPhoto:^(UIImage *image) {
            [self savePhotoAndPerformPhotoCallbacksWithImage:image timeTaken:[NSDate date]];
        }];
    }
}


- (void)takeNoisyPhoto:(void (^)(UIImage*))completed {
    
    if(!hasFrontCamera && !hasBackCamera)
    {
        TTLogCat(@"TTMediaRecorder", @"device has no cameras.");
        return;
    }
    
    if (![currentOutput isEqual:noisyPhotoOutput]) {
        return;
    }
    
    isTakingPhoto = YES;
    [self switchInputs];
    AVCaptureConnection *connectionToUse = [noisyPhotoOutput.connections objectAtIndex:0];
    
    [noisyPhotoOutput captureStillImageAsynchronouslyFromConnection:connectionToUse completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        isTakingPhoto = NO;
        if (imageDataSampleBuffer != NULL) {
            NSData *imageData = [AVCaptureStillImageOutput
                                 jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *photo = [[UIImage alloc] initWithData:imageData];
            completed(photo);
        }
    }];
}

#pragma mark Photo Callback Blocks

- (void)addPhotoCallback:(TTImageBlock)block {
    if (!photoCallbackBlocks) {
        photoCallbackBlocks = [NSMutableArray array];
    }
    [photoCallbackBlocks addObject:block];
}

- (void)removePhotoCallback:(TTImageBlock)block {
    [photoCallbackBlocks removeObject:block];
}

- (void)savePhotoAndPerformPhotoCallbacksWithImage:(UIImage*)image timeTaken:(NSDate*)timeTaken {
    
    NSData *imgData = UIImageJPEGRepresentation(image, 1);
    NSString *key = [NSString uuid];
    NSString *imagePath = [TTConfig imageFileWithKey:key andExtension:@"jpg"];
    
    if ([imgData writeToFile:imagePath atomically:YES]) {
        TTLogCat(@"TTMediaRecorder", @"savePhotoAndPerformPhotoCallbacksWithImage with key %@.", key);
        
        for (TTImageBlock block in photoCallbackBlocks) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block([NSURL fileURLWithPath:imagePath], key, timeTaken);
            });
        }
    }
    
}

#pragma mark Audio
- (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return connection;
			}
		}
	}
	return nil;
}

- (float)audioAvgPowerLevel
{
    float noNoise = -160;
    
    for (AVCaptureOutput *outpt in [session outputs]) {
        if([outpt isKindOfClass:[AVCaptureMovieFileOutput class]]) {
            AVCaptureConnection *audioConnection = [self connectionWithMediaType:AVMediaTypeAudio fromConnections:[outpt connections]];
            if(!audioConnection)
                return noNoise;
            
            NSArray *audioChannels = audioConnection.audioChannels;
            
            for (AVCaptureAudioChannel *channel in audioChannels) {
                TTLogCat(@"TTMediaRecorder:Audio:Raw", @"%f", channel.averagePowerLevel);
                return channel.averagePowerLevel;
            }
        }
    }
    
    return noNoise;
}

- (void)startSamplingAudioWithIntervalSecs:(double)intervalSecs
{
    [_audioSamplingTimer startWithRepeatSeconds:intervalSecs handler:^{
        
        float avgPower = [self audioAvgPowerLevel];
        if(_audioRecordIfAboveThreshold == 0 || avgPower > _audioRecordIfAboveThreshold)
        {
            TTLogCat(@"TTMediaRecorder:Audio", @"%f", avgPower);
            [self performAudioCallbacksWithAveragePowerLevel:avgPower];
        }
    }];
}

- (void)stopSamplingAudio
{
    [_audioSamplingTimer stop];
}

#pragma mark Audio Callback Blocks
- (void)addAudioCallback:(TTAudioBlock)block
{
    if (!_audioCallbackBlocks) {
        _audioCallbackBlocks = [NSMutableArray array];
    }
    [_audioCallbackBlocks addObject:block];
}

- (void)removeAudioCallback:(TTAudioBlock)block
{
    [_audioCallbackBlocks removeObject:block];
}

- (void)performAudioCallbacksWithAveragePowerLevel:(float)averagePowerLevel
{
    for (TTAudioBlock block in _audioCallbackBlocks) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block(averagePowerLevel);
        });
    }
}

#pragma mark Video Callback Blocks

- (void)addVideoCallback:(TTVideoBlock)block {
    if (!videoCallbackBlocks) {
        videoCallbackBlocks = [NSMutableArray array];
    }
    [videoCallbackBlocks addObject:block];
}

- (void)removeVideoCallback:(TTVideoBlock)block {
    [videoCallbackBlocks removeObject:block];
}

- (void)performVideoCallbacksWithURL:(NSURL*)url key:(NSString*)key startTime:(NSDate*)startTime duration:(NSNumber*)duration  {
    for (TTVideoBlock block in videoCallbackBlocks) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block(url, key, startTime, duration);
        });
    }
}

#pragma mark Video

- (void)startRecordingVideo {
    [self startRecordingVideoWithPhotosEvery:0];
    
}

- (void)startRecordingVideoWithPhotosEvery:(int)seconds {
    if(!hasFrontCamera && !hasBackCamera)
    {
        TTLogCat(@"TTMediaRecorder", @"device has no cameras.");
        return;
    }
    
    photoFrequencySec = seconds;
    nextPhotoDue = [NSDate date];
    
    nextSegmentDue = [[NSDate date] dateByAddingTimeInterval:10];
    
    [self startInMode:kTTMediaRecorderModeVideo];
    [self recordSegment];
}

- (void)stopRecordingVideo
{
    if(!hasFrontCamera && !hasBackCamera)
    {
        TTLogCat(@"TTMediaRecorder", @"device has no cameras.");
        return;
    }
    
    [self stop];
}

-(void) recordSegment
{
    TTLogCat(@"TTMediaRecorder", @"recordSegment");
    _currentVideoKey = [NSString uuid];
    
    NSURL *videoFile = [NSURL fileURLWithPath:[TTConfig videoFileWithKey:_currentVideoKey andExtension:@"mp4"]];
    
    [fileOutput setMaxRecordedDuration:CMTimeMake(10, 1)];
    
    [session beginConfiguration];
    
    // set the capture session preset after we fiddle with the inputs and outputs
    if(isUsingFrontCamera && [_preferredFrontCameraSessionPreset length] > 0 && [session canSetSessionPreset:_preferredFrontCameraSessionPreset])
    {
        [session setSessionPreset:_preferredFrontCameraSessionPreset];
    }
    else if([_preferredBackCameraSessionPreset length] > 0 && [session canSetSessionPreset:_preferredBackCameraSessionPreset])
    {
        [session setSessionPreset:_preferredBackCameraSessionPreset];
    }
    else if([session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        [session setSessionPreset:AVCaptureSessionPreset1280x720];
    } else if([session canSetSessionPreset:AVCaptureSessionPresetMedium]) {
        [session setSessionPreset:AVCaptureSessionPresetMedium];
    } else if([session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [session setSessionPreset:AVCaptureSessionPreset640x480];
    }
    
    [session commitConfiguration];
    
    [fileOutput startRecordingToOutputFileURL:videoFile recordingDelegate:self];
}

#pragma mark Frame Delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    TTLogCat(@"TTMediaRecorder", @"captureOutput");
    if( !CMSampleBufferDataIsReady(sampleBuffer) )
    {
        TTLogCat(@"TTMediaRecorder", @"sample buffer is not ready, skipping sample.");
        return;
    }
    
    switch (_mode) {
        case kTTMediaRecorderModeStillPhotoSilent:
        {
            // the delegate is only set when ready to take a photo
            // we only want one frame then turn our delegate off
            [silentPhotoOutput setSampleBufferDelegate:nil queue:nil];
            [self takePhotoFromSampleBuffer:sampleBuffer];
            
            break;
        }
        case kTTMediaRecorderModeVideo:
        {
            
            if ([nextPhotoDue timeIntervalSinceNow] < 0 && captureOutput == videoOutput) {
                nextPhotoDue = [NSDate dateWithTimeIntervalSinceNow:photoFrequencySec];
                [self takePhotoFromSampleBuffer:sampleBuffer];
            }
            
            if ([nextSegmentDue timeIntervalSinceNow] < 0) {
                nextSegmentDue = [NSDate dateWithTimeIntervalSinceNow:10];
                // start a new segment
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self recordSegment];
                });
                
                return;
            }
            
            break;
        }
        default:
            break;
    }
    
}

- (void)takePhotoFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    TTLogCat(@"TTMediaRecorder", @"takePhotoFromSampleBuffer");
    
    // Create a UIImage from sample buffer data
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:(CGFloat)1.0 orientation:UIImageOrientationRight];
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    
    [self savePhotoAndPerformPhotoCallbacksWithImage:image timeTaken:[NSDate date]];
}

#pragma mark AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        addSkipBackupAttributeToItemAtURL(fileURL);
    });
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    TTLogCat(@"TTMediaRecorder", @"captureOutput");
    
    if(error && error.code != AVErrorMaximumDurationReached) {
        TTLogCat(@"TTMediaRecorder", @"failed to capture content: %@", error.localizedDescription);
    } else {
        
        AVAsset *movieAsset = [AVAsset assetWithURL:outputFileURL];
        
        NSString *cam;
        if (isUsingFrontCamera) {
            cam = @"front";
        } else {
            cam = @"rear";
        }
        
        float duration = CMTimeGetSeconds([movieAsset duration]);
        [self performVideoCallbacksWithURL:outputFileURL key:_currentVideoKey startTime:_currentVideoStartTime duration:[NSNumber numberWithFloat:duration]];
        
        [self createImageFromVideo:movieAsset createdAt:[NSDate date] using:cam];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self switchInputs];
            [self recordSegment];
        });
    }
}

-(void) createImageFromVideo:(AVAsset *)movieAsset createdAt:(NSDate*)movieCreateDate using:(NSString*)cam
{
    @try
    {
        TTLogCat(@"TTMediaRecorder", @"createImageFromVideo");
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [imgGen cancelAllCGImageGeneration];
            imgGen = [AVAssetImageGenerator assetImageGeneratorWithAsset:movieAsset];
            
            __block TTMediaRecorder *blockSelf = self;
            AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error)
            {
                @try
                {
                    if (result != AVAssetImageGeneratorSucceeded) {
                        TTLogCat(@"TTMediaRecorder", @"error generating thumbnail. %@", error.localizedDescription);
                    } else {
                        
                        UIImage *image = [UIImage imageWithCGImage:im];
                        
                        NSDate *actualTimeTaken = [_currentVideoStartTime dateByAddingTimeInterval:CMTimeGetSeconds(actualTime)];
                        
                        [blockSelf savePhotoAndPerformPhotoCallbacksWithImage:image timeTaken:actualTimeTaken];
                    }
                }
                @catch (NSException *e)
                {
                    TTLogCat(@"TTMediaRecorder", @"createImageFromVideo handler error, %@", e);                }
            };
            // grab an image at zero seconds
            NSMutableArray *timePoints = [NSMutableArray array];
            float seconds = CMTimeGetSeconds([movieAsset duration]);
            for(float i=0.0; i<seconds; i+= photoFrequencySec)
            {
                [timePoints addObject:[NSValue valueWithCMTime:CMTimeMake(i, 1)]];
            }
            
            // quang-Do not take image at 0 seconds.
            if(timePoints && [timePoints count] > 1)
                [timePoints removeObjectAtIndex:0];
            
            [imgGen generateCGImagesAsynchronouslyForTimes:timePoints completionHandler:handler];
        });
    }
    @catch (NSException *e)
    {
        TTLogCat(@"TTMediaRecorder", @"createImageFromVideo error, %@", e);
    }
}

// From apple - prevents backup to iCloud
// https://developer.apple.com/library/ios/#qa/qa1719/_index.html
BOOL addSkipBackupAttributeToItemAtURL(NSURL *URL)
{
    const char* filePath = [[URL path] fileSystemRepresentation];
    
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    
    int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
    return result == 0;
}


@end
