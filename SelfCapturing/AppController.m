//
//  AppController.m
//  SelfCapturing
//
//  Created by Summer on 13-6-3.
//  Copyright (c) 2013年 rocry. All rights reserved.
//

#import "AppController.h"
#import <AVFoundation/AVFoundation.h>

#define DEFAULT_FRAMES_PER_SECOND 10
#define VIDEO_WIDTH 640
#define VIDEO_HEIGHT 480

#define ONE_DAY 24 * 3600

@interface AppController ()
{
	AVCaptureSession *session;
	AVCaptureStillImageOutput *stillImageOutput;
	BOOL started;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *videoInput;
	CMTime frameDuration;
	CMTime nextPresentationTime;
    
    NSTimer *startTimer;
    NSTimer *stopTimer;
}

@property (nonatomic, strong) NSURL *outputURL;
@property (weak) IBOutlet NSDateFormatter *dateFormatter;

@end

@implementation AppController

- (id)init {
    self = [super init];
    if (self) {
        frameDuration = CMTimeMakeWithSeconds(1. / DEFAULT_FRAMES_PER_SECOND, 90000);
        [self setupAVCapture];
        [self resetTimer];
    }
    return self;
}

- (NSURL*)outputURL
{
    if (!_outputURL) {
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSURL *desktopDir = [fm URLsForDirectory:NSDesktopDirectory
                                       inDomains:NSUserDomainMask][0];
        NSURL *appDir = [desktopDir URLByAppendingPathComponent:@"SelfCapturing"];
        NSError *theError;
        if (![fm createDirectoryAtURL:appDir withIntermediateDirectories:YES attributes:nil error:&theError]) {
            return nil;
        }
        
        NSString *fileName = [NSString stringWithFormat:@"%@.mov", [self.dateFormatter stringFromDate:[NSDate date]]];
        _outputURL = [appDir URLByAppendingPathComponent:fileName];
    }
    return _outputURL;
}

- (void)resetTimer {
    if (startTimer) [startTimer invalidate];
    if (stopTimer)  [stopTimer invalidate];
    
    NSDate *nowDate = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];
    unsigned int unitFlags =    NSYearCalendarUnit |
                                NSMonthCalendarUnit |
                                NSDayCalendarUnit |
                                NSHourCalendarUnit |
                                NSMinuteCalendarUnit |
                                NSSecondCalendarUnit;
    
    // start timer setting
    NSDateComponents *startComps = [cal components:unitFlags fromDate:nowDate];
    [startComps setHour:8];
    [startComps setMinute:0];
    [startComps setSecond:0];
    if ([[cal dateFromComponents:startComps] timeIntervalSinceNow] < 5) {
        [startComps setDay:startComps.day+1];
    }
    startTimer = [[NSTimer alloc] initWithFireDate:[cal dateFromComponents:startComps]
                                          interval:ONE_DAY
                                            target:self
                                          selector:@selector(startTimerFired:)
                                          userInfo:nil
                                           repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:startTimer forMode:NSDefaultRunLoopMode];
    
    // stop timer setting
    NSDateComponents *stopComps = [cal components:unitFlags fromDate:nowDate];
    [stopComps setHour:20];
    [stopComps setMinute:0];
    [stopComps setSecond:0];
    if ([[cal dateFromComponents:stopComps] timeIntervalSinceNow] < 5) {
        [stopComps setDay:stopComps.day+1];
    }
    stopTimer = [[NSTimer alloc] initWithFireDate:[cal dateFromComponents:stopComps]
                                         interval:ONE_DAY
                                           target:self
                                         selector:@selector(stopTimerFired:)
                                         userInfo:nil
                                          repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:stopTimer forMode:NSDefaultRunLoopMode];
    
    NSLog(@"auto start time: %@, stop time: %@", startTimer.fireDate, stopTimer.fireDate);
}

- (void)startTimerFired:(id)sender {
    NSLog(@"%s", __FUNCTION__);
    
    if (!started) {
        [self startCaptureFrame];
        started = !started;
        [self.toggleRecordMenuItem setTitle:@"Stop"];
    }
}

- (void)stopTimerFired:(id)sender {
    NSLog(@"%s", __FUNCTION__);
    
    if (started) {
        [self teardownAssetWriterAndOpen:NO];
        started = !started;
        [self.toggleRecordMenuItem setTitle:@"Start"];
    }
}

- (IBAction)toggleStart:(id)sender {
    if (started) {
		// finish
		[self teardownAssetWriterAndOpen:YES];
		[sender setTitle:@"Start"];
	} else {
        [self startCaptureFrame];
		[sender setTitle:@"Stop"];
	}
	started = !started;
}

- (void)startCaptureFrame {
    [self saveOneFrame];
    [self performSelector:@selector(startCaptureFrame) withObject:nil afterDelay:5.0];
}

- (IBAction)saveAndExit:(id)sender {
    if (started) {
        [self teardownAssetWriterAndOpen:NO];
    }
    [[NSApplication sharedApplication] terminate:sender];
}

#pragma mark - AV
- (BOOL)setupAVCapture
{
	NSError *error = nil;
    
    session = [AVCaptureSession new];
	[session setSessionPreset:AVCaptureSessionPresetPhoto];
	
	// Select a video device, make an input
	for (AVCaptureDevice *device in [AVCaptureDevice devices]) {
		if ([device hasMediaType:AVMediaTypeVideo] || [device hasMediaType:AVMediaTypeMuxed]) {
			AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
			if (error) {
                NSLog(@"deviceInputWithDevice failed with error %@", [error localizedDescription]);
				return NO;
            }
			if ([session canAddInput:input])
				[session addInput:input];
			break;
		}
	}
    
    // Make a still image output
	stillImageOutput = [AVCaptureStillImageOutput new];
	if ([session canAddOutput:stillImageOutput])
		[session addOutput:stillImageOutput];
	
    // start the capture session running, note this is an async operation
    // status is provided via notifications such as AVCaptureSessionDidStartRunningNotification/AVCaptureSessionDidStopRunningNotification
    [session startRunning];
	
	return YES;
}

- (BOOL)setupAssetWriterForURL:(NSURL *)fileURL formatDescription:(CMFormatDescriptionRef)formatDescription
{
	NSError *error = nil;
    
    // allocate the writer object with our output file URL
	assetWriter = [[AVAssetWriter alloc] initWithURL:fileURL fileType:AVFileTypeQuickTimeMovie error:&error];
	if (error) {
        NSLog(@"AVAssetWriter initWithURL failed with error %@", [error localizedDescription]);
        return NO;
    }
    
    // initialized a new input for video to receive sample buffers for writing
    // passing nil for outputSettings instructs the input to pass through appended samples, doing no processing before they are written
	videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:nil]; // passthru
	[videoInput setExpectsMediaDataInRealTime:YES];
	if ([assetWriter canAddInput:videoInput])
		[assetWriter addInput:videoInput];
	
    // initiates a sample-writing at time 0
	nextPresentationTime = kCMTimeZero;
	[assetWriter startWriting];
	[assetWriter startSessionAtSourceTime:nextPresentationTime];
    
	return YES;
}

- (void)saveOneFrame {
    // initiate a still image capture, return immediately
    // the completionHandler is called when a sample buffer has been captured
	AVCaptureConnection *stillImageConnection = [stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
	[stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
												  completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *__strong error) {
                                                      
        // set up the AVAssetWriter using the format description from the first sample buffer captured
        if (!assetWriter) {
            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(imageDataSampleBuffer);
            if ( NO == [self setupAssetWriterForURL:self.outputURL formatDescription:formatDescription] ) return;
        }
        
        // re-time the sample buffer
        CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;
        timingInfo.duration = frameDuration;
        timingInfo.presentationTimeStamp = nextPresentationTime;
        CMSampleBufferRef sbufWithNewTiming = NULL;
        OSStatus err = CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault,
                                                             imageDataSampleBuffer,
                                                             1, // numSampleTimingEntries
                                                             &timingInfo,
                                                             &sbufWithNewTiming);
        if (err) {
            NSLog(@"CMSampleBufferCreateCopyWithNewTiming failed with error %d", err);
            return;
        }
        
        // append the sample buffer if we can and increment presnetation time
        if ( [videoInput isReadyForMoreMediaData] ) {
            if ([videoInput appendSampleBuffer:sbufWithNewTiming]) {
                nextPresentationTime = CMTimeAdd(frameDuration, nextPresentationTime);
            }
            else {
                NSError *error = [assetWriter error];
                NSLog(@"failed to append sbuf: %@", [error localizedDescription]);
            }
        }
        
        // release the copy of the sample buffer we made
        CFRelease(sbufWithNewTiming);
    }];
}

- (void)teardownAssetWriterAndOpen:(BOOL)open
{
    if (assetWriter) {
		[videoInput markAsFinished];
		[assetWriter finishWriting];
        if (open) [[NSWorkspace sharedWorkspace] openURL:[assetWriter outputURL]];
		videoInput = nil;
		assetWriter = nil;
	}
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startCaptureFrame) object:nil];
	self.outputURL = nil;
}

- (float)framesPerSecond
{
	return (float)((1.0 / CMTimeGetSeconds(frameDuration)));
}

- (void)setFramesPerSecond:(float)framesPerSecond
{
	frameDuration = CMTimeMakeWithSeconds( 1.0 / framesPerSecond, 90000);
}

@end

