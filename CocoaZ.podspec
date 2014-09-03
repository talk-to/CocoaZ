Pod::Spec.new do |s|
  s.name     = 'CocoaZ'
  s.version  = '1.2.0'
  s.summary  = 'Objective C wrapper over zlib'
  s.homepage = 'https://github.com/talk-to/cocoaz'
  s.author   = 'Talk.to'
  s.license  = { :type => 'COMMERCIAL', :text => 'Property of Talk.to FZC' }
  s.source   = {
    :git => 'git@github.com:talk-to/CocoaZ.git',
    :tag => "#{s.version}"
  }
  s.requires_arc = true

  s.library = 'z'

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'

  s.source_files = 'CocoaZ/*.{h,m}'
  s.header_mappings_dir = 'CocoaZ'
end
