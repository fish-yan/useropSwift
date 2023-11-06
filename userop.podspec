Pod::Spec.new do |spec|
    spec.name         = 'useropSwift'
    spec.version      = '0.0.1'
    spec.ios.deployment_target = "13.0"
    spec.osx.deployment_target = "12.0"
    spec.license      = { :type => 'MIT License', :file => 'LICENSE.md' }
    spec.summary      = 'swift version of https://github.com/stackup-wallet/userop.js'
    spec.homepage     = 'https://github.com/fish-yan/useropSwift'
    spec.author       = { 'xueyan' => '757094197@qq.com' }
    spec.source       = { :git => 'https://github.com/fish-yan/useropSwift.git', :tag => spec.version.to_s }
    spec.swift_version = '5.8'

    spec.source_files =  "Sources/useropSwift/**/*.swift"
    spec.frameworks = 'Foundation'

    spec.dependency 'Web3Core'
    spec.dependency 'web3swift'
end
