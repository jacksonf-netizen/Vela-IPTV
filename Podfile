project 'Vela IPTV.xcodeproj'
platform :osx, '14.0'
use_modular_headers!

target 'Vela' do
  use_frameworks!

  pod 'VLCKit'
  pod 'Sparkle'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
