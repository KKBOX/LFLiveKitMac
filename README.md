# LFLiveKitMac

Porting LFLiveKit to macOS

---

[![License MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://raw.githubusercontent.com/KKBOX/LFLiveKitMac/blob/master/LICENSE)&nbsp;
[![CocoaPods](http://img.shields.io/cocoapods/v/LFLiveKitMac.svg?style=flat)](http://cocoapods.org/?q=LFLiveKitMac)&nbsp;
[![Support](https://img.shields.io/badge/macOS-10-orange.svg)](https://www.apple.com/tw/macos)&nbsp;
![Platform](https://img.shields.io/badge/platform-macOS-ff69b4.svg)&nbsp;


[LFLiveKit](https://github.com/LaiFengiOS/LFLiveKit) is an opensource
RTMP streaming SDK for iOS, and the project ports LFLiveKit to macOS.
It helps you to broadcast RTMP streams in your macOS apps.

## Requirements

Currently it is only tested on macOS 10.12 and Xcode 8.3. However, but it
should support Xcode 7 and macOS 10.8 and above.

## Usage

Uilike iOS, it is very possible that a mac user has a lot of external
audio and video capture devices conncted, such as USB microphones,
webcams and so on. Thus, we change the interface for creating
LFLiveSession obejcts, specifying a video device and an audio device
is required.

You may have code like this:

	LFLiveAudioConfiguration *audioConfig = [LFLiveAudioConfiguration defaultConfiguration];
	LFLiveVideoConfiguration *videoConfig = [LFLiveVideoConfiguration defaultConfigurationForQuality:LFLiveVideoQuality_Medium3];
	AVCaptureDevice *audioDevice = [LFLiveSession availableAudioDevices][0];
	AVCaptureDevice *videoDevice = [LFLiveSession availableCameraDevices][0];
	_session = [[LFLiveSession alloc] initWithAudioConfiguration:audioConfig audioDevice:audioDevice videoConfiguration:videoConfig videoDevice:videoDevice captureType:LFLiveCaptureMaskAll];
	_session.delegate = self;

## Modification from the Original LFLiveKit

Since APIs differ between iOS and macOS, we need to modify LFLiveKit
to make it able to build and run on macOS. What we did are including

* Change all of the OpenES API calls to correspoding OpenGL ones.
* Change the audio component for audio recoring. LFLiveKit uses the
  remoteIO node on iOS, but we need to use kAudioUnitSubType_HALOutput
  on mac OS.
* Change the way that GPUImageFramebuffer generates pixel
  buffer. GPUImageFramebuffer uses an iOS specific texture cache to
  read proccessed textures and write them into CVPixelBufferRef
  objects. However, the cache does not exist on macOS. We have to use
  another way to create CVPixelBufferRef obejcts.
* LFHardwareAudioEncoder does not work on macOS, we always use
  LFH264VideoEncoder.
* Some video filters are removes temporarily in order to make the
  project simpler while doing porting.
* Settings for camera torch and rotation are removed as well, since
  macOS does not support them.

Enjoy!

## License
 **LFLiveKit is released under the MIT license. See LICENSE for details.**
