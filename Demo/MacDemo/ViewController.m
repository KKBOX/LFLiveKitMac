@import QuartzCore;
@import AVFoundation;
#import <LFLiveKit.h>
#import "ViewController.h"

@interface PreviewView: NSView
@end

@implementation PreviewView

- (void)drawRect:(NSRect)dirtyRect
{
	if ([self needsToDrawRect:dirtyRect]) {
		[[NSColor blackColor] setFill];
		NSRectFill(dirtyRect);
	}
}

@end

typedef NS_ENUM(NSUInteger, ViewControllerState) {
	ViewControllerStateNotConnected,
	ViewControllerStateConnecting,
	ViewControllerStateConnected,
	ViewControllerStateError
};

@interface ViewController () <LFLiveSessionDelegate>
{
	LFLiveSession *_session;
}

@property (strong) NSString *currentURL;

@property (weak) IBOutlet NSButton *liveButton;
@property (weak) IBOutlet NSTextField *messageLabel;
@property (weak) IBOutlet NSPopUpButton *audioDevicesPopUpButton;
@property (weak) IBOutlet NSPopUpButton *videoDevicesPopUpButton;
@property (weak) IBOutlet NSTextField *rtmpURLTextField;
@property (weak) IBOutlet NSPopUpButton *broadcastOptionPopUpButton;
@property (weak) IBOutlet NSView *preview;

@property (assign, nonatomic) ViewControllerState state;

@property (strong) AVCaptureDevice *currentAudioDevice;
@property (strong) AVCaptureDevice *currentVideoDevice;

- (IBAction)setAudioDevice:(id)sender;
- (IBAction)setVideoDevice:(id)sender;
- (IBAction)startLive:(id)sender;
- (IBAction)stopLive:(id)sender;
@end

@implementation ViewController

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.view.wantsLayer = YES;
	self.view.layer = [[CALayer alloc] init];

	[self _updateAudioDevices];
	[self _updateVideoDevices];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDidConnect:) name:AVCaptureDeviceWasConnectedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDidDisconnect:) name:AVCaptureDeviceWasDisconnectedNotification object:nil];
	self.session.running = YES;
	_session.preView = self.preview;

	NSString *rtmpURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"rtmpURL"];
	if (!rtmpURL) {
		rtmpURL = @"rtmp://...";
		[[NSUserDefaults standardUserDefaults] setObject:rtmpURL forKey:@"rtmpURL"];
	}
	self.rtmpURLTextField.stringValue = rtmpURL;
	self.state = ViewControllerStateNotConnected;
}

- (void)_updateAudioDevices
{
	[self.audioDevicesPopUpButton removeAllItems];
	NSArray *devices = [LFLiveSession availableAudioDevices];
	NSInteger index = 0;
	NSInteger selectedIndex = NSNotFound;
	AVCaptureDevice *defaultDevice = self.currentAudioDevice ?: [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
	for (AVCaptureDevice *device in devices) {
		[self.audioDevicesPopUpButton addItemWithTitle:device.localizedName];
		if ([device.uniqueID isEqualToString:defaultDevice.uniqueID]) {
			selectedIndex = index;
		}
		index++;
	}
	if (selectedIndex != NSNotFound) {
		[self.audioDevicesPopUpButton selectItemAtIndex:selectedIndex];
	}
}

- (void)_updateVideoDevices
{
	[self.videoDevicesPopUpButton removeAllItems];
	NSArray *devices = [LFLiveSession availableCameraDevices];
	NSInteger index = 0;
	NSInteger selectedIndex = NSNotFound;
	AVCaptureDevice *defaultDevice = self.currentVideoDevice ?: [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	for (AVCaptureDevice *device in devices) {
		[self.videoDevicesPopUpButton addItemWithTitle:device.localizedName];
		if ([device.uniqueID isEqualToString:defaultDevice.uniqueID]) {
			selectedIndex = index;
		}
		index++;
	}
	if (selectedIndex != NSNotFound) {
		[self.audioDevicesPopUpButton selectItemAtIndex:selectedIndex];
	}
}

- (void)_rebuildSession
{
	self.session.running = NO;
	_session = nil;
	self.session.running = YES;
	_session.preView = self.preview;
	if (self.state == ViewControllerStateConnected) {
		[self.session stopLive];
		LFLiveStreamInfo *streamInfo = [LFLiveStreamInfo new];
		streamInfo.url = self.currentURL;
		[self.session startLive:streamInfo];
	}
}

- (IBAction)setAudioDevice:(id)sender
{
	AVCaptureDevice *audioDevice = [LFLiveSession availableAudioDevices][self.audioDevicesPopUpButton.indexOfSelectedItem];
	self.currentAudioDevice = audioDevice;
	self.session.audioDevice = audioDevice;
}

- (IBAction)setVideoDevice:(id)sender
{
	AVCaptureDevice *videoDevice = [LFLiveSession availableCameraDevices][self.videoDevicesPopUpButton.indexOfSelectedItem];
	self.currentVideoDevice = videoDevice;
	self.session.videoDevice = videoDevice;
}

- (IBAction)changeBroadcastOption:(id)sender
{
	[self _rebuildSession];
}

- (IBAction)startLive:(id)sender
{
	[self.session stopLive];
	LFLiveStreamInfo *streamInfo = [LFLiveStreamInfo new];
	NSString *rtmpURL = self.rtmpURLTextField.stringValue;
	self.currentURL = rtmpURL;
	streamInfo.url = rtmpURL;
	[[NSUserDefaults standardUserDefaults] setObject:rtmpURL forKey:@"rtmpURL"];
	[self.session startLive:streamInfo];
}

- (IBAction)stopLive:(id)sender
{
	[self.session stopLive];
}

- (LFLiveSession *)session
{
	if (!_session) {
		LFLiveAudioConfiguration *audioConfig = [LFLiveAudioConfiguration defaultConfiguration];
		LFLiveVideoConfiguration *videoConfig = [LFLiveVideoConfiguration defaultConfigurationForQuality:LFLiveVideoQuality_High1];
//		videoConfig.videoSize = CGSizeMake(640, 640);
		AVCaptureDevice *audioDevice = [LFLiveSession availableAudioDevices][self.audioDevicesPopUpButton.indexOfSelectedItem];
		AVCaptureDevice *videoDevice = [LFLiveSession availableCameraDevices][self.videoDevicesPopUpButton.indexOfSelectedItem];
		LFLiveCaptureTypeMask type = self.broadcastOptionPopUpButton.indexOfSelectedItem == 0 ? LFLiveCaptureMaskAll : LFLiveCaptureMaskAudio;

		_session = [[LFLiveSession alloc] initWithAudioConfiguration:audioConfig audioDevice:audioDevice videoConfiguration:videoConfig videoDevice:videoDevice captureType:type];
		_session.delegate = self;
	}
	return _session;
}

#pragma mark -

- (void)deviceDidConnect:(NSNotification *)notification
{
	[self _updateAudioDevices];
	[self _updateVideoDevices];
}

- (void)deviceDidDisconnect:(NSNotification *)notification
{
	AVCaptureDevice *device = notification.object;
	if ([device.uniqueID isEqualToString:self.currentAudioDevice.uniqueID]) {
		self.currentAudioDevice = nil;
	}
	if ([device.uniqueID isEqualToString:self.currentVideoDevice.uniqueID]) {
		self.currentVideoDevice = nil;
	}
	[self _updateAudioDevices];
	[self _updateVideoDevices];
	[self _rebuildSession];
}

#pragma mark -

- (void)setState:(ViewControllerState)state
{
	_state = state;
	switch (_state) {
		case ViewControllerStateNotConnected:
			self.rtmpURLTextField.editable = YES;
			self.rtmpURLTextField.enabled = YES;
			self.liveButton.title = NSLocalizedString(@"Start Live", @"");
			self.liveButton.action = @selector(startLive:);
			self.messageLabel.stringValue = @"";
			break;
		case ViewControllerStateConnecting:
			self.rtmpURLTextField.editable = NO;
			self.rtmpURLTextField.enabled = NO;
			self.liveButton.title = NSLocalizedString(@"Connecting", @"");
			self.liveButton.action = NULL;
			self.messageLabel.stringValue = NSLocalizedString(@"Connecting...", @"");
			break;
		case ViewControllerStateConnected:
			self.rtmpURLTextField.editable = NO;
			self.rtmpURLTextField.enabled = NO;
			self.liveButton.title = NSLocalizedString(@"Stop Live", @"");
			self.liveButton.action = @selector(stopLive:);
			self.messageLabel.stringValue = NSLocalizedString(@"Connected.", @"");
			break;
		case ViewControllerStateError:
			self.rtmpURLTextField.editable = YES;
			self.rtmpURLTextField.enabled = YES;
			self.liveButton.title = NSLocalizedString(@"Stop Live", @"");
			self.liveButton.action = @selector(startLive:);
			self.messageLabel.stringValue = NSLocalizedString(@"Error.", @"");
			break;
		default:
			break;
	}
}

- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange:(LFLiveState)state
{
	NSLog(@"%s %lu", __PRETTY_FUNCTION__, (unsigned long)state);
	switch (state) {
		case LFLivePending:
			self.state = ViewControllerStateConnecting;
			break;
		case LFLiveStart:
			self.state = ViewControllerStateConnected;
			break;
		case LFLiveStop:
			self.state = ViewControllerStateNotConnected;
			break;
		case LFLiveError:
			self.state = ViewControllerStateError;
			break;
		default:
			break;
	}
}

- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug *)debugInfo
{
	NSLog(@"%s %@", __PRETTY_FUNCTION__, debugInfo);
}

- (void)liveSession:(nullable LFLiveSession *)session errorCode:(LFLiveSocketErrorCode)errorCode
{
	NSLog(@"%s %lu", __PRETTY_FUNCTION__, (unsigned long)errorCode);
	self.state = ViewControllerStateError;
}

@end
