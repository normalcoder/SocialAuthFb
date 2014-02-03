Pod::Spec.new do |s|
  s.name      = 'SocialAuthFb'
	s.version   = '0.0.1'
  s.homepage  = 'https://github.com/normalcoder/SocialAuthFb'
  s.source    = { :git => 'https://github.com/normalcoder/SocialAuthFb.git' }
  s.source_files = 'SocialAuthFb/*.{h,m}'
  s.requires_arc = true
	s.dependency 'Facebook-iOS-SDK', '~> 3.11'
end
