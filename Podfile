# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
platform :macos, '12.0'
source 'https://github.com/CocoaPods/Specs.git'

target 'TypeFeedback' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for TypeFeedback
  pod 'DynamicColor'

end

# Xcode no longer builds for macOS older than 12.0, so lift pods that ask for less.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
