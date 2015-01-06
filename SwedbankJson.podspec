Pod::Spec.new do |s|
  s.name         = "SwedbankJson"
  s.version      = "0.1"
  s.summary      = "Wrapper för Swedbanks stängda mobilapp API."
  s.homepage     = "https://github.com/viktorgardart/SwedbankJson"
  
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Viktor Gardart" => "viktor@gardart.se" }
  s.source       = { 
    :git => "https://github.com/viktorgardart/SwedbankJson.git", 
    :tag => "0.1"
  }
  
  s.platform     = :ios, '7.0'
  s.source_files = "src/*.{h,m}"
  s.requires_arc = true
end
