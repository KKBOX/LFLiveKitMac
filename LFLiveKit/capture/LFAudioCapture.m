//
//  LFAudioCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFAudioCapture.h"
@import AudioToolbox;

NSString *const LFAudioComponentFailedToCreateNotification = @"LFAudioComponentFailedToCreateNotification";

@interface LFAudioCapture ()
@property (nonatomic, assign) AudioComponentInstance componetInstance;
@property (nonatomic, assign) AudioComponent component;
@property (nonatomic, strong) dispatch_queue_t taskQueue;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong, nullable) LFLiveAudioConfiguration *configuration;
@end

@implementation LFAudioCapture

#pragma mark -- LiftCycle

- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)configuration audioCaptureDevice:(nullable AVCaptureDevice *)device sampleRate:(Float64 *)outSampleRate channels:(UInt32 *)outChannels
{
	if (self = [super init]) {
		_configuration = configuration;
		self.isRunning = NO;
		self.taskQueue = dispatch_queue_create("com.youku.Laifeng.audioCapture.Queue", NULL);
		AudioComponentDescription audioComponentDescription;
		audioComponentDescription.componentType = kAudioUnitType_Output;
		audioComponentDescription.componentSubType = kAudioUnitSubType_HALOutput;
		audioComponentDescription.componentManufacturer = 0;
		audioComponentDescription.componentFlags = 0;
		audioComponentDescription.componentFlagsMask = 0;

		self.component = AudioComponentFindNext(NULL, &audioComponentDescription);

		if (self.component == NULL) {
			NSAssert(0, @"Unable to find audio component.");
		}

		OSStatus status = noErr;
		status = AudioComponentInstanceNew(self.component, &_componetInstance);

		if (noErr != status) {
			[self handleAudioComponentCreationFailure];
		}

		UInt32 flagOne = 1;

		AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));

		flagOne = 0;
		AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &flagOne, sizeof(flagOne));

		if (device == nil) {
			AudioDeviceID inputDevice;
			UInt32 size = sizeof(AudioDeviceID);
			status = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultInputDevice, &size, &inputDevice);
			if (status == noErr) {
				status = AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &inputDevice, sizeof(inputDevice));
				if (status == noErr) {
					[self updateFormatForDevice:inputDevice sampleRate:outSampleRate channels:outChannels];
				}
			}
		}
		else {
			[self setAudioCaptureDevice:device sampleRate:outSampleRate channels:outChannels];
		}

		AURenderCallbackStruct cb;
		cb.inputProcRefCon = (__bridge void *)(self);
		cb.inputProc = handleInputBuffer;
		AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));

		status = AudioUnitInitialize(self.componetInstance);

		if (noErr != status) {
			[self handleAudioComponentCreationFailure];
		}
	}
	return self;
}

- (void)setAudioCaptureDevice:(nonnull AVCaptureDevice *)device sampleRate:(Float64 *)outSampleRate channels:(UInt32 *)outChannels
{
	if (![device hasMediaType:AVMediaTypeAudio]) {
		return;
	}

	AudioObjectPropertyAddress propertyAddress = {
		kAudioHardwarePropertyDevices,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};

	UInt32 dataSize = 0;
	OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize);
	if (kAudioHardwareNoError != status) {
		fprintf(stderr, "AudioObjectGetPropertyDataSize (kAudioHardwarePropertyDevices) failed: %i\n", status);
		return;
	}

	UInt32 deviceCount = (UInt32)(dataSize / sizeof(AudioDeviceID));

	AudioDeviceID *audioDevices = (AudioDeviceID *)(malloc(dataSize));
	if (NULL == audioDevices) {
		fputs("Unable to allocate memory", stderr);
		return;
	}

	status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize, audioDevices);
	if (kAudioHardwareNoError != status) {
		fprintf(stderr, "AudioObjectGetPropertyData (kAudioHardwarePropertyDevices) failed: %i\n", status);
		free(audioDevices), audioDevices = NULL;
		return;
	}

	// Iterate through all the devices and determine which are input-capable
	propertyAddress.mScope = kAudioDevicePropertyScopeInput;
	for (UInt32 i = 0; i < deviceCount; ++i) {
		// Query device UID
		CFStringRef deviceUID = NULL;
		dataSize = sizeof(deviceUID);
		propertyAddress.mSelector = kAudioDevicePropertyDeviceUID;
		status = AudioObjectGetPropertyData(audioDevices[i], &propertyAddress, 0, NULL, &dataSize, &deviceUID);
		if (kAudioHardwareNoError != status) {
			fprintf(stderr, "AudioObjectGetPropertyData (kAudioDevicePropertyDeviceUID) failed: %i\n", status);
			continue;
		}

		if ([(__bridge NSString *)deviceUID isEqualToString:device.uniqueID]) {
			status = AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &audioDevices[i], sizeof(audioDevices[i]));
			[self updateFormatForDevice:audioDevices[i] sampleRate:outSampleRate channels:outChannels];
			break;
		}
	}

	free(audioDevices);
	audioDevices = NULL;
}

- (void)updateFormatForDevice:(AudioDeviceID)device sampleRate:(Float64 *)outSampleRate channels:(UInt32 *)outChannels
{

	AudioObjectPropertyAddress propertyAddress = {0};
	CFStringRef uidString = NULL;
	UInt32 dataSize = sizeof(uidString);
	propertyAddress.mSelector = kAudioDevicePropertyDeviceUID;
	propertyAddress.mScope = kAudioDevicePropertyScopeInput;
	propertyAddress.mElement = kAudioObjectPropertyElementMaster;
	OSStatus status = AudioObjectGetPropertyData(device, &propertyAddress, 0, NULL, &dataSize, &uidString);
	if (kAudioHardwareNoError != status) {
		fprintf(stderr, "AudioObjectGetPropertyData (kAudioDevicePropertyDeviceUID) failed: %i\n", status);
		return;
	}
	AVCaptureDevice *captureDevice = [AVCaptureDevice deviceWithUniqueID: (__bridge NSString *)uidString];
	if (!captureDevice) {
		NSLog(@"No available captureDevice with uid: %@", uidString);
		return;
	}
	UInt32 channels = 0;
	Float64 sampleRate = 0;
	for (NSUInteger i = 0; i < [captureDevice formats].count; i++) {
		const AudioFormatListItem *audioFormatListItem = CMAudioFormatDescriptionGetFormatList([[captureDevice formats][i] formatDescription], nil);
		AudioStreamBasicDescription asbd = audioFormatListItem->mASBD;
		if (asbd.mSampleRate >= 44100 && asbd.mChannelsPerFrame >= 2) {
			channels = 2;
			sampleRate = asbd.mSampleRate;
			break;
		}
		if (asbd.mSampleRate > sampleRate) {
			channels = asbd.mChannelsPerFrame >= 2 ? 2 : asbd.mChannelsPerFrame < 2 ? 1 : asbd.mChannelsPerFrame;
			sampleRate = asbd.mSampleRate;
		}
		
	}
	*outSampleRate = sampleRate;
	*outChannels = channels;

	AudioStreamBasicDescription streamFormatDescription = {0};
	streamFormatDescription.mSampleRate = sampleRate;
	streamFormatDescription.mFormatID = kAudioFormatLinearPCM;
	streamFormatDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
	streamFormatDescription.mChannelsPerFrame = channels;
	streamFormatDescription.mFramesPerPacket = 1;
	streamFormatDescription.mBitsPerChannel = 16;
	streamFormatDescription.mBytesPerFrame = streamFormatDescription.mBitsPerChannel / 8 * streamFormatDescription.mChannelsPerFrame;
	streamFormatDescription.mBytesPerPacket = streamFormatDescription.mBytesPerFrame * streamFormatDescription.mFramesPerPacket;
	streamFormatDescription.mReserved = 0;
	AudioUnitSetProperty(self.componetInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &streamFormatDescription, sizeof(streamFormatDescription));
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	self.delegate = nil;

	dispatch_sync(self.taskQueue, ^{
		if (self.componetInstance) {
			self.isRunning = NO;
			AudioOutputUnitStop(self.componetInstance);
			AudioComponentInstanceDispose(self.componetInstance);
			self.componetInstance = nil;
			self.component = nil;
		}
	});
}

#pragma mark -- Setter

- (void)setRunning:(BOOL)running
{
	if (_running == running) {
		return;
	}
	_running = running;
	if (_running) {
		dispatch_async(self.taskQueue, ^{
			self.isRunning = YES;
			NSLog(@"MicrophoneSource: startRunning");
			AudioOutputUnitStart(self.componetInstance);
		});
	}
	else {
		dispatch_sync(self.taskQueue, ^{
			self.isRunning = NO;
			NSLog(@"MicrophoneSource: stopRunning");
			AudioOutputUnitStop(self.componetInstance);
		});
	}
}

#pragma mark -- CustomMethod

- (void)handleAudioComponentCreationFailure
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:LFAudioComponentFailedToCreateNotification object:nil];
	});
}

#pragma mark -- CallBack

static OSStatus handleInputBuffer(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
	@autoreleasepool {
		LFAudioCapture *source = (__bridge LFAudioCapture *)inRefCon;
		if (!source) {
			return -1;
		}

		AudioBuffer buffer;
		buffer.mData = NULL;
		buffer.mDataByteSize = 0;
		buffer.mNumberChannels = 1;

		AudioBufferList buffers;
		buffers.mNumberBuffers = 1;
		buffers.mBuffers[0] = buffer;

		OSStatus status = AudioUnitRender(source.componetInstance, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &buffers);

		if (source.muted) {
			for (int i = 0; i < buffers.mNumberBuffers; i++) {
				AudioBuffer ab = buffers.mBuffers[i];
				memset(ab.mData, 0, ab.mDataByteSize);
			}
		}

		if (!status) {
			if (source.delegate && [source.delegate respondsToSelector:@selector(captureOutput:audioData:)]) {
				[source.delegate captureOutput:source audioData:[NSData dataWithBytes:buffers.mBuffers[0].mData length:buffers.mBuffers[0].mDataByteSize]];
			}
		}
		return status;
	}
}

@end
