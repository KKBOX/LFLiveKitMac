
Pod::Spec.new do |s|

  s.name         = "LFLiveKitMac"
  s.version      = "0.1"
  s.summary      = "LFLiveKit macOS port. Based on LFLiveKit for iOS 2.6."
  s.homepage     = "https://github.com/KKBOX/LFLiveKitMac"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "zonble" => "zonble@gmail.com" }
  s.platform     = :osx, "10.8"
  s.osx.deployment_target = "10.8"
  s.source       = { :git => "https://github.com/KKBOX/LFLiveKitMac.git", :tag => "#{s.version}" }
  s.source_files  = "LFLiveKit/**/*.{h,m,mm,cpp,c}"
  s.public_header_files = ['LFLiveKit/*.h', 'LFLiveKit/objects/*.h', 'LFLiveKit/configuration/*.h']

  s.frameworks = "VideoToolbox", "AudioToolbox","AVFoundation","Foundation","UIKit"
  s.libraries = "c++", "z"

  s.requires_arc = true
end
