module ProductDeploy

    class SqlPatch < Patch
        
        def to_patch
            @role='SQL' #this refers to FileType in the xml file
            
            if @patches_to_apply.empty?
                @output.puts "Patches were already applied"
                return true
            end
            turn_xml_patches_into_hash
            apply
            @output.puts("Updating #{PATCHES_APPLIED_FILE} with the patches applied")
            update_patches_applied(@patches_to_apply,PATCHES_APPLIED_FILE) if @store_patches_applied
        end

        def get_rave_path(db_name)
                 @output.puts "ERROR: SQL role doen't have binaries to deploy"
         end

        def update_ravepatches_table(patch_number,version,description)
            sql_insert = "INSERT INTO [#{@db_name}].[dbo].[RavePatches] ([RaveVersion],[PatchNumber],[version],[Description],[DateApplied],[AppliedBy],[AppliedFrom],[Active]) VALUES('5.6.3.86',\'#{patch_number}\',\'#{version}\',\'#{description}\',current_timestamp,'chef','chef',1)"
            cmd_to_run = "#{SQL_CMD} -b -d #{@db_name} -Q \"#{sql_insert}\""
            output = %x{#{cmd_to_run}}
            return $? 
        end
        
        # it returns ok if it exists, false if it doesn't
        def query_patch(patch_number)
            sql_query = "SELECT [PatchNumber] FROM [#{@db_name}].[dbo].[RavePatches] WHERE PatchNumber = \'#{patch_number}\'"
            cmd_to_run = "#{SQL_CMD} -b -d #{@db_name} -Q \"#{sql_query}\""
            output = %x{#{cmd_to_run}}
            return !output.grep(/^#{patch_number}/).empty? #grep returns an array of matches
        end
        

    
        # Applies a single sql script, it logs every sql transaction to the same folder as the sql 
        # script with a .log extension.
        # Errors are log to "error_log"
        def apply_sql_patch_script(sql_script,n,sub_n,dst_folder,error_log,s3_folder)
            
                local_route = file_join(dst_folder,"#{n}-#{sub_n}-#{sql_script}")
                
                # if the sql_script already exsits in local it means that it was alreay apply. 
                # fair enought?
                if File.exists?(local_route)
                    @output.puts  " Skipping: #{local_route} was already applied"
                else
                    
                    s3_file = File.join(s3_folder,sql_script)
                    #s3_patch_file = @s3.directories.get(@s3_bucket,{'delimiter' => '/','prefix' => s3_file}).files.first # it may show more than one file
                    s3_patch_file = get_s3_file(s3_file)
                    # This means that XML has wrong information
                    raise("\"#{s3_file}\" doesn't exist") if s3_patch_file.nil?
                    File.open(local_route,'wb') { |file| file << s3_patch_file.body }
                    @output.print " Applying: #{local_route}"
                    log = "#{local_route}.log"
                    # using \" \" because local_route (filename) can contain spaces
                    # -b adds exit codes to sqlcmd.exe
                    cmd_to_run = "#{SQL_CMD} -b -d #{@db_name} -i \"#{local_route}\" -o \"#{log}\""
                    # System captures the exit code of the the command, if 0 returns TRUE if non 0 
                    # returns FALSE
                    unless system(cmd_to_run)
                        @output.print " ...FAILED\n"
                        File.open(error_log,'ab') do |file|
                            file << "\r\n#{time_now} There was a problem running the command: #{cmd_to_run}\r\n"
                            file << "                   Error code: #{$?.inspect}\r\n"
                            file << File.open(log,'rb').read
                        end
                        return false
                    else
                        @output.print " ...OK\n"
                        return true
                    end
                end   
        end
    
        # Apply all the sql patches specified
        def apply(dst_folder='c:\chef\tmp',error_log='c:\chef\log\sql_patches.err' )
            
            errors = 0
            no_errors = 0
            list = @patches_to_apply.sort
            list.each do |n|
                raise("Patch number: #{n} doesn't exist") unless @xml_patches.has_key?(n)
                if query_patch(n)
                    @output.puts("Patch #{n} has already been applied (dbo.RavePatches table)") 
                    next
                end
                s3_folder = @xml_patches[n]["folder"]
                
                sub_n = 0          
                @xml_patches[n][@role]["sql_scripts"].each do |sql_script|
                    sub_n += 1
                    if apply_sql_patch_script(sql_script,n,sub_n,dst_folder,error_log,s3_folder)
                        no_errors += 1 
                    else 
                        errors += 1
                    end
                end
                      
                
                update_ravepatches_table(n,1,s3_folder)
            end
            if errors > 0
                @output.puts  "There were #{errors} errors and #{no_errors} OKs"
                @output.puts  "Check out #{error_log} for further information"
            else
                @output.puts  "#{no_errors} Patched were applied"
            end        
        end
        
        def time_now
            Time.now.strftime("%Y/%m/%d %H:%M")
        end
        
        def sql_extract_scriptname_xml(node,patch_number)
            if ( node["ScriptName"].nil? ) || ( node["ScriptName"].empty? )
                  @output.puts  "Error on #{patch_number}: #{node["ScriptName"]}"
            elsif node["BackObject"].nil? || node["BackObject"].empty? || node["BackObject"] == "None" || node["BackObject"] == "StoredProcedure"
                  # Filenames can't have spaces at the begining or at the end but, xml content can
                  if node["ScriptName"] =~ /^\s+|\s+$/
                      @output.puts  "Warning: #{patch_number}-#{node["ScriptName"]} has spaces, cleaning up"
                      return node["ScriptName"].gsub(/^\s+|\s+$/,'') 
                  else
                      return node["ScriptName"]
                  end
             else
                  @output.puts  "Error on #{patch_number}: BackObject is neither empty nor a StoredProcedure, it got #{node["BackObject"]} "
             end
             false
        end
        
    end #class
end #module