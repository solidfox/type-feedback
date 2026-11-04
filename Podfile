# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
platform :macos, '10.13'
source 'https://github.com/CocoaPods/Specs.git'

target 'TypeFeedback' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for TypeFeedback
  pod 'DynamicColor'

end

# Keep the Intel build compatible with High Sierra; Apple silicon starts at Big Sur.
# Xcode 27's SDK range check is an error by default, but its tools still build 10.13.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ARCHS'] = 'arm64 x86_64'
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.13'
      config.build_settings['MACOSX_DEPLOYMENT_TARGET[arch=arm64]'] = '11.0'
      config.build_settings['__DIAGNOSE_INVALID_DEPLOYMENT_TARGET_AS_ERROR'] = 'NO'
    end
  end
end
