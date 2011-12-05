module ProductDeploy

    class CoderSqlPatch < Patch
        
        def to_patch
            @role='SQL' #this refers to FileType in the xml file
            
            if @patches_to_apply.empty?
                @output.puts "Patches were already applied"
                return true
            end
            turn_xml_patches_into_hash(XML_CODER_PATCH_NAME)
            apply
            #@output.puts("Updating #{PATCHES_APPLIED_FILE} with the patches applied")
            #update_patches_applied(@patches_to_apply,PATCHES_APPLIED_FILE) if @store_patches_applied
        end
    

        

        # Methods called:
        # - sql_extract_scriptname_xml(node,patch_number)
        # Called from:
        #  - turn_xml_patches_into_hash
        
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
                  # Coder uses the relative path
                  if node["RelativePath"].nil? || node["RelativePath"].empty?
                      raise("RelativePath can not be empty, error on #{patch_number}, ScriptName #{script_name}")
                  else
                      script_name = File.join(node["RelativePath"],script_name) 
                  end
                  files_path["sql_scripts"] << script_name if script_name
        
              end
           end
           files_path["sql_scripts"] = [] if files_path.empty?
           files_path
        end
        
        # Methods called:
        #  - query_patch
        #  - apply_sql_patch_script
        # Apply all the sql patches specified
        def apply(dst_folder='c:\chef\tmp',error_log='c:\chef\log\sql_patches.err' )
            
            errors = 0
            no_errors = 0
            #list = @patches_to_apply.sort # It doesn't sort properly: 100 comes before 99
            list = @patches_to_apply
            
            #abort("APPLY:This is a test:#{list}") #DELETE
            list.each do |n|
                raise("Build number: #{n} doesn't exist") unless @xml_patches.has_key?(n)
                if query_patch(n)
                    @output.puts("Build #{n} has already been applied (dbo.AppVersions table)") 
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
                        raise("\n\nSTOP!! this is done by design. The script can't continue because #{sql_script} failed\n\t check #{error_log} for further information\n\n")
                        
                        
                    end
                end
                      
                # Set active to 1 on AppVersion table
                update_build_applied(n)
            end
            if errors > 0
                @output.puts  "There were #{errors} errors and #{no_errors} OKs"
                @output.puts  "Check out #{error_log} for further information"
            else
                @output.puts  "#{no_errors} Patched were applied"
            end        
        end
        
        # Applies a single sql script, it logs every sql transaction to the same folder as the sql 
        # script with a .log extension.
        # Errors are log to "error_log"
        def apply_sql_patch_script(sql_script,n,sub_n,dst_folder,error_log,s3_folder)
            return_func = true
            local_route = file_join(dst_folder,"#{n}-#{sub_n}_#{sql_script.gsub(/[\/\\]/,'_').gsub(/[ ]/,'-')}")
            
            # if the sql_script log already exsits in local it means that it was alreay apply. 
            # fair enought?
            log = "#{local_route}.log"
            if File.exists?(log)
                @output.puts  " Skipping: #{log} was already applied (log exists)"
            else
                
                s3_file = File.join(s3_folder,sql_script)
                s3_patch_file = get_s3_file(s3_file)
                # This means that XML has wrong information
                raise("\"#{s3_file}\" doesn't exist") unless s3_patch_file
                File.open(local_route,'wb') { |file| file << s3_patch_file.body }
                @output.print " Applying: #{local_route}"
                log = "#{local_route}.log"
                # using \" \" because local_route (filename) can contain spaces
                # -b adds exit codes to sqlcmd.exe
                cmd_to_run = "#{SQL_CMD} -I -b -d #{@db_name} -i \"#{local_route}\" -o \"#{log}\""
                # System captures the exit code of the the command, if 0 returns TRUE if non 0 
                # returns FALSE
                start_time = Time.now.strftime("%Y-%m-%d %H:%M:%S")
                unless system(cmd_to_run)
                    @output.print " ...FAILED\n"
                    log_msg = File.open(log,'rb') {|f| f.read }
                    File.open(error_log,'ab') do |file|
                        file << "\r\n#{time_now} There was a problem running the command: #{cmd_to_run}\r\n"
                        file << "                   Error code: #{$?.inspect}\r\n"
                        file << log_msg
                    end
                    
                    # Rename log file to err, otherwise it will think it was applied next time
                    FileUtils.mv(log,log.chomp(File.extname(log)) + '.err')
                    return_func = false
                else
                    @output.print " ...OK\n"
                    log_msg = File.open(log,'rb').read
                    return_func =  true
                end
                
                log_to_db({:app_version => n,:script_name => sql_script,:start_time => start_time,
                    :result_message => log_msg,:sql_result_code => $?})
            end
            return return_func  
        end
        
private

        # spScriptExecutionLogInsert StoreProcedure is used to log the run of every sql script
        def log_to_db(log)
            @output.puts 'Logging to ScriptExcecutionLog table'
            log_file = 'c:\chef\log\tmp_sql_cmd_output.log' # used as a temporary file
            
            log[:end_time] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
            log[:script_run_by_db_login] = @params[:script_run_by_db_login]
            log[:applied_by] = @params[:applied_by]
            log[:applied_from] = @params[:applied_from]
            log[:segment_id] = 'NULL'
            log[:study_id] = 'NULL'
            log[:result_message].gsub!(/[\r\n'"]/,'-') # Remove characters that can't be pass throught the cmd line
            
            sql_query = "spScriptExecutionLogInsert \'#{log[:app_version]}\', \'#{log[:script_name]}\', \'#{log[:script_run_by_db_login]}\', \'#{log[:applied_by]}\', \'#{log[:applied_from]}\', \'#{log[:start_time]}\', \'#{log[:end_time]}\', \'#{log[:result_message]}\', #{log[:sql_result_code]}, #{log[:segment_id]}, #{log[:segment_id]}"
            #sql_cmd = "sqlcmd -S localhost -d #{@db_name}  -b -Q \ -o \"#{log_file}\""
            sql_cmd = "#{SQL_CMD} -b -d #{@db_name} -E -Q \"#{sql_query}\" -o \"#{log_file}\""
            
            system(sql_cmd)
            raise("sql command failed #{$?.inspect},\n\t Output this error: #{File.read(log_file)},\n\t Command to run: #{sql_cmd}") if $? != 0
            return true
        end
        
        def time_now
            Time.now.strftime("%Y/%m/%d %H:%M")
        end
        
        def update_build_applied(build_number)
            log_file = 'c:\chef\log\sql_cmd_output.log'
            
            sql_query = "update [#{@db_name}].[dbo].[AppVersions] set [active] = 1 where [version] = \'#{build_number}\'"
            sql_cmd = "#{SQL_CMD} -b -d #{@db_name} -Q \"#{sql_query}\" -o \"#{log_file}\""
            system(sql_cmd)
            raise("sql command failed #{$?.inspect},\n\t Output this error: #{File.read(log_file)},\n\t Command to run: #{sql_cmd}") if $? != 0
            return true
            
        end

        # select 
        def query_patch(build_number)
            #build_number='1.0.56'
            #@db_name='coder_v1_WhoDrugB2'
            sql_query = "SELECT [Version] FROM [#{@db_name}].[dbo].[AppVersions] WHERE [Active] = \'1\'"
            cmd_to_run = "#{SQL_CMD} -b -d #{@db_name} -Q \"#{sql_query}\""
            output = %x{#{cmd_to_run}}
            return !output.grep(/^#{build_number}/).empty? #grep returns an array of matches

        end

        def valid_patch_number(build_number)
            build_number =~ /[0-9.]{4,9}/
        end
        
        # Methods called:
        # - none
        
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
        
        
    end#class
end#module

