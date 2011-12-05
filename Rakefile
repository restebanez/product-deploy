require 'rubygems'
require 's3'

require 'bundler/setup'
require 'date'
require 'digest/md5'
require 'fog'
require 'fog/core/credentials'

require 'mime/types'




Bundler::GemHelper.install_tasks


#############################################################################
#
# Helper functions
#
#############################################################################

def name
  @name ||= Dir['*.gemspec'].first.split('.').first
end

def version
  line = File.read("lib/#{name}/version.rb")[/^\s*VERSION\s*=\s*.*/]
  line.match(/.*VERSION\s*=\s*['"](.*)['"]/)[1]
end

def date
  Date.today.to_s
end

def gemspec_file
  "#{name}.gemspec"
end

def gem_file
  "#{name}-#{version}.gem"
end

def replace_header(head, header_name)
  head.sub!(/(\.#{header_name}\s*= ').*'/) { "#{$1}#{send(header_name)}'"}
end


#############################################################################
#
# Standard tasks
#
#############################################################################


desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -r ./lib/#{name}.rb"
end


desc "copy gem to /Users/restebanez/aws-mdsol-dev-gems/"
task :copy do
    sh "cp ./pkg/*.gem /Users/restebanez/aws-mdsol-dev-gems/gems/"
end

desc "Generate gem index"
task :index do
    sh "gem generate_index -d /Users/restebanez/aws-mdsol-dev-gems"
end

=begin
desc "Deploy all gems in aws-mdsol-dev-gems/**/* to S3/aws-mdsol-dev-gems"
task :upload do

      AWS_BUCKET = 'aws-mdsol-dev-gems'

    ## Use the `s3` gem to connect my bucket
        puts "== Uploading gmes to S3/aws-mdsol-dev-gems"

        s3=Fog::AWS::Compute.new(Fog.credentials)
        
        bucket = service.buckets.find(AWS_BUCKET)

    ## Needed to show progress
        STDOUT.sync = true

    ## Find all files (recursively) in ./public and process them.
        Dir.glob("/Users/restebanez/aws-mdsol-dev-gems/**/*").each do |file|
            puts file
    ## Only upload files, we're not interested in directories
          if File.file?(file)

    ## Slash 'public/' from the filename for use on S3
            remote_file = file.gsub("/Users/restebanez/aws-mdsol-dev-gems/", "")

    ## Try to find the remote_file, an error is thrown when no
    ## such file can be found, that's okay.  
            puts remote_file
            begin
              obj = bucket.objects.find_first(remote_file)
            rescue
              obj = nil
            end

    ## If the object does not exist, or if the MD5 Hash / etag of the 
    ## file has changed, upload it.
            if !obj || (obj.etag != Digest::MD5.hexdigest(File.read(file)))
                print "U"

    ## Simply create a new object, write the content and set the proper 
    ## mime-type. `obj.save` will upload and store the file to S3.
                obj = bucket.objects.build(remote_file)
                obj.content = open(file)
                obj.content_type = MIME::Types.type_for(file).to_s
                obj.save
            else
              print "."
            end
          end
        end
        STDOUT.sync = false # Done with progress output.

        puts
        puts "== Done syncing gems"
      
    
    
end
=end

desc "Deploy all gems in aws-mdsol-dev-gems/**/* to S3/aws-mdsol-dev-gems"
task :upload do
      unless Fog.respond_to?('credentials')
         abort('Please create the .fog file with the right credentials') 
      end
      aws_key_id = Fog.credentials[:aws_access_key_id]
      aws_secret_key = Fog.credentials[:aws_secret_access_key]

      AWS_BUCKET = 'aws-mdsol-dev-gems'

    ## Use the `s3` gem to connect my bucket
        puts "== Uploading gmes to S3/aws-mdsol-dev-gems"

        service = S3::Service.new(
          :access_key_id => aws_key_id,
          :secret_access_key => aws_secret_key)
        bucket = service.buckets.find(AWS_BUCKET)

    ## Needed to show progress
        STDOUT.sync = true

    ## Find all files (recursively) in ./public and process them.
        Dir.glob("/Users/restebanez/aws-mdsol-dev-gems/**/*").each do |file|
    ## Only upload files, we're not interested in directories
          if File.file?(file)

    ## Slash 'public/' from the filename for use on S3
        remote_file = file.gsub("/Users/restebanez/aws-mdsol-dev-gems/", "")

    ## Try to find the remote_file, an error is thrown when no
    ## such file can be found, that's okay.  
            begin
              obj = bucket.objects.find_first(remote_file)
            rescue
              obj = nil
            end

    ## If the object does not exist, or if the MD5 Hash / etag of the 
    ## file has changed, upload it.
            if !obj || (obj.etag != Digest::MD5.hexdigest(File.read(file)))
                print "U"

    ## Simply create a new object, write the content and set the proper 
    ## mime-type. `obj.save` will upload and store the file to S3.
                obj = bucket.objects.build(remote_file)
                obj.content = open(file)
                obj.content_type = MIME::Types.type_for(file).to_s
                obj.save
            else
              print "."
            end
          end
        end
        STDOUT.sync = false # Done with progress output.

        puts
        puts "== Done syncing gems"
      
    
    
end

desc "build a new gem and upload it to http://aws-mdsol-dev-gems.s3.amazonaws.com/"
task :build_and_upload => [:build, :copy, :index, :upload] 
