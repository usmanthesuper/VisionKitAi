Pod::Spec.new do |spec|
  spec.name               = "VisionKit"
  spec.version            = "1.2.7"
  spec.platform           = :ios, '15.2'
  spec.ios.deployment_target = '15.2'

  spec.summary            = "A framework for interfacing with VisionKit models"
  spec.description        = "A framework for interfacing with hosted computer vision models using VisionKit"
  
  spec.homepage           = "https://www.visionkit.ai"
  spec.documentation_url  = "https://docs.visionkit.ai"
  
  spec.license            = { :type => 'Apache', :text => 'See LICENSE at https://visionkit.ai' }
  spec.author             = { "VisionKit" => "hello@visionkit.ai" }
  
  spec.swift_versions     = ['5.3']
  spec.source             = { :git => 'https://github.com/yourusername/visionkit-swift.git', :tag => "#{spec.version}" }
  spec.source_files       = 'Sources/**/*'
end
