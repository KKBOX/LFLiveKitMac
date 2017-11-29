@import QuartzCore;
#import "VolumeView.h"

@interface VolumeView ()
{
	CVDisplayLinkRef displayLink; //display link for managing rendering thread
}
@property (strong, nonatomic) CALayer *barLayer;
@end

@implementation VolumeView

- (void)_init
{
	self.wantsLayer = YES;
	self.layer = [[CALayer alloc] init];
	self.layer.backgroundColor = [NSColor blackColor].CGColor;
	self.barLayer = [[CALayer alloc] init];
	self.barLayer.backgroundColor = [NSColor redColor].CGColor;
	[self.layer addSublayer:self.barLayer];
}

- (instancetype)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self _init];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		[self _init];
	}
	return self;
}

- (void)dealloc
{
	[self stoptTimer];
}

- (void)startTimer
{
	[self stoptTimer];
	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

	// Set the renderer output callback function
	CVDisplayLinkSetOutputCallback(displayLink, &MyDisplayLinkCallback, (__bridge void * _Nullable)(self));
	CVDisplayLinkStart(displayLink);
}

- (void)stoptTimer
{
	if (displayLink) {
		CVDisplayLinkRelease(displayLink);
		displayLink = NULL;
	}
}

static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
	VolumeView *self = (__bridge VolumeView*)displayLinkContext;
	NSData *data = [self.delegate volumeViewRequestAudioData:self];
	if (!data) {
		return kCVReturnSuccess;
	}
	NSInteger length = data.length;
	NSInteger sampleCount = length / 4;
	float sum = 0;
	const short *bytes = data.bytes;
	for (size_t i = 0; i < sampleCount * 4; i += 4) {
		short *sp = (short *)(bytes + i);
		short left = abs(*sp);
		short right = abs(*(sp + 1));
		short average = (left + right) / 2;
		sum += average / 32767.0;
	}
	float average = sum / (float)sampleCount;
	average *= 5;

	dispatch_async(dispatch_get_main_queue(), ^{
		[CATransaction begin];
		[CATransaction setAnimationDuration:0.05];
		CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.barLayer.superlayer.frame) * average, CGRectGetHeight(self.barLayer.superlayer.frame));
		self.barLayer.frame = frame;
		if (average < 0.7) {
			self.barLayer.backgroundColor = [NSColor greenColor].CGColor;
		}
		else if (average < 0.9) {
			self.barLayer.backgroundColor = [NSColor yellowColor].CGColor;
		}
		else {
			self.barLayer.backgroundColor = [NSColor redColor].CGColor;
		}

		[CATransaction commit];
	});
	return kCVReturnSuccess;
}

@end
