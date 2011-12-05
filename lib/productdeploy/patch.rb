module ProductDeploy

    class Patch < Util
        # this patches are problematic and it should be ignored
        PATCHES_IGNORED = ["196", "210", "214", "223", "225", "227"]
        RAVE_VERSION = '5.6.3.86'
        XML_RAVE_PATCH_NAME = 'RavePatch3.xml'
        XML_CODER_PATCH_NAME = 'CoderVersion.xml'

       attr_reader :role, :xml_patches, :consolidated_patches


       def initialize(params)

           @output = select_output(params[:output_type]) # This method lives in Util class
           # After patching, write which patches were applied. 
           # For Web we first have to apply web role and then viewer, we'll store it after viewer
           @store_patches_applied = params[:store_patches_applied]
           @common_rave_path = params[:common_rave_path] || 'C:\MedidataAPP\Sites'
           @web_relative_path = params[:web_relative_path] || '' # || 'MedidataRAVE'
           @app_relative_path = params[:app_relative_path] || '' # || 'RaveService'
           @viewers_relative_path = params[:viewers_relative_path] || %w{RaveCrystalViewers\Viewer1 RaveCrystalViewers\Viewer2}
           
           # viewer integration, role only works with APP, WEB and SQL
           # there should be two vars, role and filetype
           @db_name, @s3_bucket  = params[:db_name], params[:rave_patches_bucket]
           @patches_to_apply = which_patches_to_apply(params[:requested_patches_to_apply])
         
           @xml_patches,@consolidated_patches = {}, {}
          
           @s3=Fog::Storage.new(:provider => 'AWS', :aws_access_key_id=>  params[:aws_access_key_id],
           	                                        :aws_secret_access_key =>  params[:aws_secret_access_key])
           @params = params # we need many params for coder_sql_patch logging into the table
           to_patch 
       end 



       # it calls all the necesary methods    

       
       # it actually apply every patch
       # this method is for for web and app, Sql overides it
       def apply(local_base_path,consolidated_patches)
           @output.puts("Paching...")
           consolidated_patches.each_pair do |local_folder,files|
               local_folder_cleaned = local_folder.gsub(/^\\/,"")
               files.each_pair do |file,s3_folder|

                    # Here there is a patch name convention, if it contains the word "Baselines", 
                    # it belongs to the baselines, that means that it may have subfolders in the s3 bucket
                    # the subfolders has the same hierarchy has "local_folder"
                    if s3_folder =~/Baseline/
                        s3_file = File.join(s3_folder,local_folder_cleaned.gsub(/\\/,"/"),file)
                    else
                        s3_file = File.join(s3_folder,file) # this is OS independent
                    end


                    local_route = file_join(local_base_path,local_folder_cleaned,file)

                    base_route = file_join(local_base_path,local_folder_cleaned)
                    FileUtils.mkdir_p(base_route) unless File.directory?(base_route)
                    
                    # if the path contains a /../ it resolves it, s3 doesn't know how to do it
                    # 001 - Baseline App/img/../hello.png => 001 - Baseline App/hello.png
                    # 001 - Baseline App/../hello.png => hello.png
                    s3_file.gsub!(/\/?.*\/\.\.\//,"")

                    s3_patch_file = get_s3_file(s3_file)
                    raise ("#{s3_file} not found. The xml file points to a file that doesn't exist on s3") unless s3_patch_file
                    local_md5 =''
                    local_md5 = generate_md5_checksum_for_file(local_route) if File.exists?(local_route)
                    remote_md5 = s3_patch_file.etag
                    #@output.puts  "Local File #{local_route} got: #{local_md5}"
                    #@output.puts  "Remote File #{s3_file} got: #{remote_md5}"
                    unless local_md5 == remote_md5
                        patch_number = extract_patch_number_from_folder(s3_folder)
                        File.rename(local_route,local_route + ".bak.#{patch_number}") if File.exists?(local_route)
                        #size = 0
                        size = s3_patch_file.content_length/1024
                        @output.puts  "+Patching #{local_route} with s3://#{@s3_bucket}/#{s3_file} (#{size} KB) "
                        File.open(local_route,'wb') do |file|
                            file << s3_patch_file.body
                        end
                    else
                        @output.puts "-Nothing to update. #{local_route} got the same md5 as s3://#{@s3_bucket}/#{s3_file} "
                    end
                end
            end
       end


       # It turns every RaveVersion3.xml included in every patch folder into a complex hash
       #  Check at the end for a real data example
       def turn_xml_patches_into_hash(xml_patch_name=XML_RAVE_PATCH_NAME)
            patch_folders = get_s3_files.common_prefixes
            patch_folders.each do |patch_folder|
                rave_patch_xml = get_s3_file(patch_folder + xml_patch_name)
                next unless rave_patch_xml # if it hasn't a RavePatch3.xml file
                tmp = {}
                tmp.store('folder',patch_folder)    
                tmp.store('xml',rave_patch_xml.key)
                
                patch_number = get_patch_number(rave_patch_xml.body)
                # verify is a 3 digit number
                raise("Patch number:#{patch_number} on #{rave_patch_xml.key} isn't valid") unless valid_patch_number(patch_number)
                scriptnames = get_scriptnames(rave_patch_xml.body)
                tmp.store(@role,scriptnames)
                @xml_patches.store(patch_number,tmp)
            end #do
                
       end
       
       # this is overriden in coder because it uses build numbers
       def valid_patch_number(patch_number)
           patch_number =~ /[0-9]{3}/
       end

       # Based on the patches to apply, it generates a final hash with:
       # folder, files and what s3 folder are located
       # It starts at the end going backwards, only adds files to the list if it doesn't exist yet
       def consolidate_patches # only web and app
           @consolidated_patches = {}
           @output.puts("Consolidaiting Patches: #{@patches_to_apply.join(' ')}")
           @patches_to_apply.sort.reverse.each do |n|
               raise("Patch number: #{n} doesn't exist") unless @xml_patches.has_key?(n)
               s3_patch_folder = @xml_patches[n]["folder"]
               folder_tree = @xml_patches[n][@role] # key: Folder name, value: array of filenames
               folder_tree.each_pair do |relative_path,script_names|
                   @consolidated_patches[relative_path] ||= {}
                   script_names.each do |script_name|
                        unless @consolidated_patches[relative_path].has_key_insensitive?(script_name)
                            # local_folder_destinitation - file_name -> what folder to find it in the s3 bucket
                            @consolidated_patches[relative_path][script_name] = s3_patch_folder
                        else
                            @output.puts  "Skipping #{script_name} from #{s3_patch_folder}"
                        end
                   end
               end
           end #do
       end

       # it will return and array of hashes equally splitted (chunks) according to the num of files 
       # in the hash and the max level of threading specified
       def split_consolidated_hash(consolidated_patches,max_thread)
           total_files = 0
           # how many total files are there?
           consolidated_patches.each_value {|v| total_files += v.size }
           array_container = []
           files_per_thread = total_files / max_thread
           
           chunk_number = 0
           current_items_store_left = files_per_thread
           
           consolidated_patches.each_pair do |local_folder,files|
                  tmp = {}
                  files.each_pair do |file,s3_folder|
                      tmp.store(file,s3_folder)
                      current_items_store_left = current_items_store_left - 1
                      array_container[chunk_number] ||= {}
                      #array_container[chunk_number][local_folder] ||= {}
                      array_container[chunk_number].store(local_folder,tmp)
                      if current_items_store_left == 0 # when you fill the bucket, you start in the next one
                          chunk_number += 1 
                          current_items_store_left = files_per_thread
                          tmp = {}
                      end
                  end
           end
           array_container
           
       end

       def debug
           role_debug_xml_patches = "#{DEBUG_XML_PATCHES}-#{@role}"
           @output.puts("Dumping @xml_patches into #{role_debug_xml_patches}")
           File.open(role_debug_xml_patches,'wb') {|f| f << @xml_patches.to_yaml }
           role_debug_consolidated_patches = "#{DEBUG_CONSOLIDATED_PATCHES}-#{@role}"
           @output.puts("Dumping @consolidated_patches into #{role_debug_consolidated_patches}")
           File.open(role_debug_consolidated_patches,'wb') {|f| f << @consolidated_patches.to_yaml }
       end
       

private
     def generate_md5_checksum_for_file(file)
       checksum_file(file, Digest::MD5.new)
     end
     
     def extract_patch_number_from_folder(folder_name)
        if folder_name =~ /^([0-9]{3}) /
            return $1
        else
            return 'xxx'
        end
        
     end
 
     def checksum_file(file, digest)
       File.open(file, 'rb') { |f| checksum_io(f, digest) }
     end
     
     def checksum_io(io, digest)
       while chunk = io.read(1024 * 8)
         digest.update(chunk)
       end
       digest.hexdigest
     end
     
 


      # Based on the current patch level, it returns the necesary patches to apply
      def which_patches_to_apply(requested)
           
             applied = read_patches_applied
             to_apply = requested - applied - PATCHES_IGNORED
             @output.puts("Paches to apply now: #{to_apply.empty? ? "None" : to_apply.join(' ')} =")
             @output.puts("  Requested patches: #{requested.empty? ? "None" : requested.join(' ')}")
             @output.puts("  - Current patch level: #{applied.empty? ? "None" : applied.join(' ')}") 
             @output.puts("  - Patches to ignore: #{PATCHES_IGNORED.empty? ? "None" : PATCHES_IGNORED.join(' ')}")
             to_apply
      end

      # return and array of matches
      def get_s3_files(folder=nil,delimeter='/')
          @s3.directories.get(@s3_bucket,{'delimiter' => delimeter, 'prefix' => folder}).files
      end
      
      # return either the file requested or false
      # for instance get_s3_file('000 - Baselines/Help.aspx.resx'), without the first slash
      def get_s3_file(s3_file) 
          #@s3.directories.get(@s3_bucket).files.get(s3_file) do |chunk|
          #    file << chunk
          #end

          # using the prefix is 10 times faster but i don't know how to pass a chunk block to body
          @s3.directories.get(@s3_bucket,{'delimiter' => '/','prefix' => s3_file}).files.each do |file|
              return file if file.key == s3_file
          end
          return false
      end
      
      
      # Extracts the content of 
      def get_scriptnames(xml_content)# xml_content belongs to a RavePatch3.xml file
          # we only care about two fields:     ScriptName => Medidata.Core.Objects.dll
          #                                    RelativePath => \bin
         doc = Nokogiri::XML(xml_content)
         patch_number = doc.xpath("//PatchNumber").children.to_s
         files_path = {}
         doc.xpath("//Script[@FileType = \"#{@role}\"]").each do |node|
            if @role == 'SQL'
                files_path["sql_scripts"] ||= []
                script_name = sql_extract_scriptname_xml(node,patch_number)                
                files_path["sql_scripts"] << script_name if script_name
            else 
                files_path["#{node["RelativePath"]}"] ||= []
                script_name = extract_scriptname_xml(node,patch_number)
                files_path["#{node["RelativePath"]}"] << script_name if script_name
            end
         end
         files_path["sql_scripts"] = [] if @role == 'SQL' and files_path.empty?
         files_path
      end

      def get_patch_number(xml_content)
          doc = Nokogiri::XML(xml_content)
          patch_number = doc.xpath("//PatchNumber").children.to_s
      end

      # It reads the vars of a single xml line (FileType = app or web)
      # <Script ScriptName="Medidata.Core.Common.dll" ScriptDate="" ScriptNumber="" ScriptRevision="0"
      # ScriptMinDBVersion="" ScriptMaxDBVersion="" ScriptIsRerunnable="0" ScriptRequiredForBuild="" ScriptDoNotRun="false"
      # FileType="WEB" RelativePath="\bin" BackObject="None" BackObjectName="" IsNew="false" />
      
      # <Script ScriptName="Medidata.Core.Common.dll" ScriptDate="" ScriptNumber="" ScriptRevision="0"
      # ScriptMinDBVersion="" ScriptMaxDBVersion="" ScriptIsRerunnable="0" ScriptRequiredForBuild="" ScriptDoNotRun="false"
      # FileType="APP" RelativePath="\" BackObject="None" BackObjectName="" IsNew="false" />
      def extract_scriptname_xml(node,patch_number)
          if ( node["ScriptName"].nil? || node["RelativePath"].nil? ) || ( node["ScriptName"].empty? || node["RelativePath"].empty? )
              @output.puts  "Error on #{patch_number}: #{node["ScriptName"]} -> #{node["RelativePath"]}"
          else            
              return node["ScriptName"]
          end 
          false
      end

    end #class

end #module





=begin

    load_xml_patches example:
    # "PatchNumber" -> {"ROLE","S3_XML_FILE_PATH","S3_FOLDER_PATH"}
    #        "ROLE" -> {"DST_FOLDER_1" -> FILES, "DST_FOLDER_2" -> FILES}
        "236"=>
          {"APP"=>
            {"\\"=>
              ["Medidata.Core.Common.dll",
               "Medidata.Core.Objects.dll",
               "Medidata.ExternalSystems.iMedidata.dll",
               "Medidata.HttpProxy.dll",
               "Medidata.PdfGenerator.dll"]},
           "xml"=>"236 - RaveQ42010/RavePatch3.xml",
           "folder"=>"236 - RaveQ42010/"},
=end

=begin
      consolidate_patches:
           This is a extract of @consolidated_patches
           "\\Modules\\eLearning"=>{"init.htm"=>"229 - iMedidata Patch/"},
           "\\Modules\\Reporting\\TSDV\\SharedPages"=>
            {"HeaderPage.aspx"=>"230 - TSDV Patch/",
             "SdvFrameset.aspx"=>"230 - TSDV Patch/",
             "Frameset.aspx"=>"230 - TSDV Patch/"}}

=end