module ProductDeploy

    # this class should contain any methods that don't have any dependency and can be called from the command line
    class Util

        


        # Read the current patch version applied from a yaml file
        # We don't want to doble patch
        # return an array of numbers or and empty array
        def read_patches_applied(filename_path=PATCHES_APPLIED_FILE)
            return [] unless File.exists?(filename_path)
            file = File.open(filename_path,'rb') 
            # if file is empty returns [] instead of false
            return YAML::load( file ) || [] 
        end


        # append a list of patches to the conf file, it will sort and uniq it
        def update_patches_applied(patches_to_append=[],filename_path=PATCHES_APPLIED_FILE)
            patches = read_patches_applied(filename_path)
            total_patches = patches + patches_to_append
            File.open(filename_path,'wb') {|f| f << total_patches.sort.uniq.to_yaml } 
        end

        # it parses c:\chef\etc\client.rb to find out the role
        # it'll return app,web or sql
        def self.get_cloud_type # this term comes from medistrano
            raise "#{CHEF_CLIENT_FILE} doesn't exist" unless File.exists?(CHEF_CLIENT_FILE)
            chef_conf = File.open(CHEF_CLIENT_FILE,'rb').read
            return $1 if chef_conf =~ /^node_name \".*?\.(\w+)\.i-.*\"/
            return false
            
        end
        
        def self.get_dll_version(filename_path)
             s = File.read(filename_path)
             x = s.match(/F\0i\0l\0e\0V\0e\0r\0s\0i\0o\0n\0*(.*?)\0\0\0/)

             if x.class == MatchData
               ver=x[1].gsub(/\0/,"")
             else
               ver="No version"
             end

             @output.puts ver
         end
        
        def self.query_patches_from_table(db_to_use,raveversion = '5.6.3.86')
             sql_query = "SELECT distinct [PatchNumber] FROM [#{db_to_use}].[dbo].[RavePatches] WHERE RaveVersion = \'#{raveversion}\'"
             cmd_to_run = "#{SQL_CMD} -b -d #{db_to_use} -Q \"#{sql_query}\""
             output = %x{#{cmd_to_run}}
             lines = output.split("\n")
             patches = []
             lines.each { |l| patches << $1 if l =~ /^([0-9]{3}) / }
             return patches

         end
         
         def self.get_db_names_from_bak(db_file_name)
             raise("DB File #{db_file_name} doesn't exist") unless File.exists?(db_file_name)
             sql_query = "Restore filelistonly from disk = \'#{db_file_name}\'"
             cmd_to_run = "#{SQL_CMD} -b -Q \"#{sql_query}\""
             output = %x{#{cmd_to_run}}
             cvs = output.gsub(/[ \t]+/,',').split("\n")
             raise("SQL output doesn't look right, #{output}") unless cvs.size > 5
             cvs.delete_at(0) # columns name
             cvs.delete_at(0) # ------------
             cvs.delete_at(-1) # blank line
             cvs.delete_at(-1) #(2 selected raws)
             
             db_structure = []
             cvs.each do |c|
                 tmp = {}
                 tmp.store(:logical_name, c.split(',')[0])
                 tmp.store(:physical_name, c.split(',')[1])
                 tmp.store(:physical_basename, File.basename(c.split(',')[1]))
                 tmp.store(:type, c.split(',')[2])
                 db_structure << tmp
             end
             db_structure
             
         end

        # We need to output differently based on the context
        # Command line => STDOUT, if chef requires this gem we need to use Chef::Log, if testing we need array
        def select_output(output)
            case output
             when "chef"
                 ProductDeploy::OutputChef.new         
             when "stdout"
                 STDOUT
             when "array"
                 ProductDeploy::Output.new
             else
                 raise("select chef, array or stdout")
             end
         end

=begin
         # it returns and string for SQL, APP adn WEB, it returns and ARRAY for viewer
         def get_rave_path(db_name,role)
             case role
             when "SQL"
                 @output.puts "ERROR: SQL role doen't have binaries to deploy"

              when "APP"                
                 file_join(@common_rave_path,db_name,@app_relative_path)

              when "WEB"
                 file_join(@common_rave_path,db_name,@web_relative_path)
                 
              when "VIEWER"
                  viewer_full_path =[]
                  @viewers_relative_path.each do |viewer_relative_path|
                      viewer_full_path << file_join(@common_rave_path,db_name,viewer_relative_path)
                  end
                  viewer_full_path
              else
                 @output.puts  "role #{role} unknown, use WEB,VIEWER,APP or SQL"
              end

         end
=end   
         def file_join(*files) 
             # The asterisk is actually taking all arguments you send to the method  
             # and assigning them to an array named files

             # In linux it will return the join with /, in windows \\
             #ALT_SEPARATOR is only defined in Windows as \\
             File.join(files).gsub(File::SEPARATOR,File::ALT_SEPARATOR || File::SEPARATOR)
         end

    end

end #module    