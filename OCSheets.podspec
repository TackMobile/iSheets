Pod::Spec.new do |s|
  s.name     = 'OCSheets'
  s.version  = '0.1.7'
  s.license  = 'Modified BSD'
  s.summary  = 'Layered navigation controller for hierarchical iPad apps.'
  s.homepage = 'https://github.com/TackMobile/iSheets'
  s.author   = { 'Ben Pilcher' => 'benpilcher@tackmobile.com' }
  s.source   = { :git => 'https://github.com/TackMobile/iSheets.git', :tag =>  s.version.to_s }

  s.description = 'Layered navigation controller for hierarchical iPad apps, with variable widths and history. Based originally on fork of FRLayeredNavigationController by Johannes Weiß'

  s.platform = :ios, '5.0'
  s.ios.source_files = 'OCSheets/*.{h,m}'
  s.framework = 'UIKit'
  s.requires_arc = true
end
