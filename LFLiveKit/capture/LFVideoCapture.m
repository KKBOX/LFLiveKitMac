//
//  LFVideoCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFVideoCapture.h"
#import "LFGPUImageEmptyFilter.h"

#if __has_include(<GPUImage/GPUImageFramework.h>)
#import <GPUImage/GPUImageFramework.h>
#elif __has_include(<GPUImage/GPUImage.h>)
#import <GPUImage/GPUImage.h>
#elif __has_include("GPUImage/GPUImage.h")
#import "GPUImage/GPUImage.h"
#else
#import "GPUImage.h"
#endif

@interface LFVideoCapture ()

@property (nonatomic, strong) GPUImageAVCamera *videoCamera;
@property (nonatomic, strong) GPUImageFilter *filter;
@property (nonatomic, strong) GPUImageOutput <GPUImageInput> *output;
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;
@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;

@end

@implementation LFVideoCapture

#pragma mark -- LifeCycle

- (nullable instancetype)initWithVideoConfiguration:(nullable LFLiveVideoConfiguration *)configuration videoCaptureDevice:(nullable AVCaptureDevice *)device
{
	if (self = [super init]) {
		_configuration = configuration;
		self.mirror = YES;
		_videoCaptureDevice = device;
	}
	return self;
}

- (void)dealloc
{
	[_videoCamera stopCameraCapture];
	if (_gpuImageView) {
		[_gpuImageView removeFromSuperview];
		_gpuImageView = nil;
	}
}

#pragma mark -- Setter Getter

- (GPUImageAVCamera *)videoCamera
{
	if (!_videoCamera) {
		_videoCamera = [[GPUImageAVCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraDevice:self.videoCaptureDevice];
		_videoCamera.horizontallyMirrorFrontFacingCamera = NO;
		_videoCamera.horizontallyMirrorRearFacingCamera = NO;
		_videoCamera.frameRate = (int32_t) _configuration.videoFrameRate;
	}
	return _videoCamera;
}

- (void)setRunning:(BOOL)running
{
	if (_running == running) {
		return;
	}
	_running = running;

	if (!_running) {
		[self.videoCamera stopCameraCapture];
		if (self.saveLocalVideo) {
			[self.movieWriter finishRecording];
		}
	}
	else {
		[self reloadFilter];
		[self.videoCamera startCameraCapture];
		if (self.saveLocalVideo) {
			[self.movieWriter startRecording];
		}
	}
}

- (void)setPreView:(NSView *)preView
{
	if (self.gpuImageView.superview) {
		[self.gpuImageView removeFromSuperview];
	}
	[preView addSubview:self.gpuImageView];
	self.gpuImageView.frame = CGRectMake(0, 0, preView.frame.size.width, preView.frame.size.height);
}

- (NSView *)preView
{
	return self.gpuImageView.superview;
}

- (void)setVideoFrameRate:(NSInteger)videoFrameRate
{
	if (videoFrameRate <= 0) {
		return;
	}
	if (videoFrameRate == self.videoCamera.frameRate) {
		return;
	}
	self.videoCamera.frameRate = (uint32_t) videoFrameRate;
}

- (NSInteger)videoFrameRate
{
	return self.videoCamera.frameRate;
}

- (void)setVideoCaptureDevice:(nonnull AVCaptureDevice *)device
{
	BOOL running = _running;
	self.running = NO;
	_videoCamera = nil;
	_videoCaptureDevice = device;
	[self videoCamera];
	self.running = running;
}

- (void)setMirror:(BOOL)mirror
{
	_mirror = mirror;
}

- (GPUImageView *)gpuImageView
{
	if (!_gpuImageView) {
		_gpuImageView = [[GPUImageView alloc] initWithFrame:NSZeroRect];
//		[_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
		[_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatio];
		[_gpuImageView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	}
	return _gpuImageView;
}

- (GPUImageMovieWriter *)movieWriter
{
	if (!_movieWriter) {
		_movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.saveLocalVideoPath size:self.configuration.videoSize];
		_movieWriter.encodingLiveVideo = YES;
		_movieWriter.shouldPassthroughAudio = YES;
		self.videoCamera.audioEncodingTarget = self.movieWriter;
	}
	return _movieWriter;
}

#pragma mark -- Custom Method

- (void)processVideo:(GPUImageOutput *)output
{
	__weak typeof(self) _self = self;
	@autoreleasepool {
		GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
		CVPixelBufferRef pixelBuffer = [imageFramebuffer pixelBuffer];
		if (pixelBuffer && _self.delegate && [_self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:)]) {
			[_self.delegate captureOutput:_self pixelBuffer:pixelBuffer];
		}
	}
}

- (void)reloadFilter
{
	[self.videoCamera removeAllTargets];
	[self.filter removeAllTargets];
	[self.output removeAllTargets];

//	CGRect cropRect = CGRectMake((16. - 9.) / 16. / 2., 0, 9. / 16., 1);
	CGRect cropRect = CGRectMake(0, 0, 1, 1);
	self.filter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRect];
	self.output = [[LFGPUImageEmptyFilter alloc] init];

	[self.videoCamera addTarget:self.filter];
	[self.filter addTarget:self.gpuImageView];
	[self.filter addTarget:self.output];
	[self.filter forceProcessingAtSize:self.configuration.videoSize];
//	[self.filter forceProcessingAtSize:CGSizeMake(640, 640)];

	__weak typeof(self) _self = self;

	[self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
		[_self processVideo:output];
	}];

}

@end
