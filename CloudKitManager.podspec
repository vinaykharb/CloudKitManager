Pod::Spec.new do |s|
  s.name             = 'CloudKitManager'
  s.version          = '0.1.6'
  s.summary          = 'CRUD operations for the Apple CloudKit integration.'
 
  s.description      = <<-DESC
CRUD operations for the Apple CloudKit integration. Can be used in a reactive way, all you need to do is add ReactiveSwift and Result libraries.
                       DESC
 
  s.homepage         = 'https://github.com/vinaykharb/CloudKitManager'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Vinay Kharb' => 'vinay.student.ece10@itbhu.ac.in' }
  s.source           = { :git => 'https://github.com/vinaykharb/CloudKitManager.git', :branch => "master", :tag => s.version.to_s }
 
  s.ios.deployment_target = '11.0'
  s.swift_version = '5.0'
  s.source_files = 'CloudKitManager.swift'
  s.dependency 'ReactiveSwift'
  s.dependency 'Result'
  
end