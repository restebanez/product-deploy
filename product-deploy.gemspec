# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "productdeploy/version"

Gem::Specification.new do |s|
  s.name        = "product-deploy"
  s.version     = ProductDeploy::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Rodrigo Estebanez"]
  s.email       = ["restebanez@mdsol.com"]
  s.homepage    = ""
  s.summary     = %q{deploy rave binaries and sql script to an arbitrary version}
  s.description = %q{deploy rave binaries and sql script to an arbitrary version}

  s.rubyforge_project = "product-deploy"
  s.require_paths = ["lib"]

  s.files         = %w{Rakefile 
                       product-deploy.gemspec 
                       util/xml_app_for_baselines.rb
                       util/xml_web_for_baselines.rb
                       bin/raveversion
                       bin/raveversion564
                       bin/coderversion  
                       lib/productdeploy.rb 
                       lib/productdeploy/util.rb 
                       lib/productdeploy/output.rb 
                       lib/productdeploy/output_chef.rb
                       lib/productdeploy/patch.rb                         
                       lib/productdeploy/app_patch.rb
                       lib/productdeploy/coder_app_patch.rb
                       lib/productdeploy/coder_cws_patch.rb
                       lib/productdeploy/coder_sql_patch.rb                       
                       lib/productdeploy/viewer_patch.rb  
                       lib/productdeploy/web_patch.rb 
                       lib/productdeploy/sql_patch.rb 
                       lib/productdeploy/version.rb 
                       }
#  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
#  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
#  s.default_executable = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

## If your gem includes any executables, list them here.
  s.executables = ["raveversion","coderversion"]
#  s.default_executable = 'productdeploy'


  s.add_dependency('excon','0.2.8')
  s.add_dependency('fog','0.3.30')
  s.add_dependency('nokogiri')
  s.add_dependency('trollop')  
end