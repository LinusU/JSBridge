Pod::Spec.new do |s|
  s.name         = "LinusU_JSBridge"
  s.version      = %x(git describe --tags --abbrev=0).chomp
  s.summary      = "Bridge your JavaScript library for usage in Swift"
  s.description  = "Use a hidden WKWebView to bridge your JavaScript library for consumption from Swift"
  s.homepage     = "https://github.com/LinusU/JSBridge"
  s.license      = "MIT"
  s.author       = { "Linus Unnebäck" => "linus@folkdatorn.se" }

  s.swift_version = "4.0"
  s.ios.deployment_target = "11.0"
  s.osx.deployment_target = "10.13"

  s.source       = { :git => "https://github.com/LinusU/JSBridge.git", :tag => "#{s.version}" }
  s.source_files = "Sources"

  s.dependency "PromiseKit", "~> 6.0"
end
