Pod::Spec.new do |spec|
  spec.name               = "VisionKit"
  spec.version            = "1.2.7"
  spec.platform           = :ios, '15.2'
  spec.ios.deployment_target = '15.2'
  spec.summary            = "A framework for computer vision and machine learning"
  spec.description        = "A framework for running computer vision models locally on iOS devices"
  spec.homepage           = "https://github.com/yourusername/visionkit-swift"
  spec.documentation_url  = "https://github.com/yourusername/visionkit-swift"
  spec.license            = { :type => 'Apache', :text => 'See LICENSE file' }
  spec.author             = { "VisionKit" => "your-email@example.com" } 
  spec.swift_versions     = ['5.3']
  spec.source             = { :git => 'https://github.com/yourusername/visionkit-swift.git', :tag => "#{spec.version}" }
  spec.source_files       = 'Sources/**/*'
end
