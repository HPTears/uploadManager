#
# Be sure to run `pod lib lint XKCornerRadius.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'XKUploadManager'
  s.version          = '1.0.3'
  s.summary          = 'A short description of XKUploadManager.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/sy5075391'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'sy5075391' => '447523382@qq.com' }
  s.source           = { :git => 'http://git.xksquare.com/XK-iOS-Component/XKUploadManager.git'}
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'Component/Classes/**/*'

  # s.resource_bundles = {
  #   'XKCornerRadius' => ['XKCornerRadius/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'Qiniu','7.2.4'
  s.dependency 'XKNetWork'
  s.dependency 'XKCategary'

end
