Pod::Spec.new do |s|
  s.name             = 'QCBandSDKLegacy'
  s.version          = '1.0.0'
  s.summary          = 'Legacy wrapper for QCBandSDK.framework'
  s.description      = 'Local wrapper pod for legacy QCBandSDK.framework binary.'
  s.homepage         = 'https://example.invalid/qcbandsdk'
  s.license          = { :type => 'Commercial', :text => 'Proprietary binary SDK.' }
  s.author           = { 'Picnique' => 'dev@picnique.local' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.vendored_frameworks = 'QCBandSDK.framework'
end
