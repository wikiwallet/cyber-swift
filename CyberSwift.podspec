Pod::Spec.new do |spec|

    spec.name               =   "CyberSwift"
    spec.platform           =   :ios, "11.0"
    spec.swift_version      =   "4.2"

    spec.summary            =   "Swift framework for Cyberway.golos.io"
    spec.homepage           =   "https://cyberway.golos.io/"
    spec.license            =   { :type => 'MIT', :file => 'LICENSE.md' }
    spec.author             =   "msm72"
    spec.source_files       =   "CyberSwift", "CyberSwift/**/*.{h,m,swift}"

    spec.version            =   "1.0.7"
    spec.source             =   { :git => "https://github.com/GolosChain/cyber-ios.git", :tag => "#{spec.version}" }

    # Cocoapods
    spec.dependency 'Checksum'
    spec.dependency 'Locksmith'
    spec.dependency 'eosswift', '~> 1.5'
    spec.dependency 'RxBlocking', '~> 4.0'
    spec.dependency 'Starscream', '~> 3.0'
    spec.dependency 'Localize-Swift', '~> 2.0'

end
