@import Cocoa;

@class VolumeView;

@protocol VolumeViewDelegate <NSObject>
- (nullable NSData *)volumeViewRequestAudioData:(nonnull VolumeView *)view;
@end

@interface VolumeView : NSView

- (void)startTimer;
- (void)stoptTimer;

@property (weak, nonatomic, nullable) IBOutlet id <VolumeViewDelegate> delegate;
@end
