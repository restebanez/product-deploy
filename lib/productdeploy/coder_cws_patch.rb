module ProductDeploy

    class CoderCwsPatch < Patch
                
        def to_patch
            @role='CWS' #this refers to FileType in the xml file
            
            if @patches_to_apply.empty?
                @output.puts "Patches were already applied"
                return true
            end
            turn_xml_patches_into_hash
            consolidate_patches
            dst_rave_path=get_rave_path
            @output.puts("Patching under #{dst_rave_path}")
            
            i = 0
            arr = []
            split_consolidated_hash(@consolidated_patches,MAX_THREAD).each do |chunk|
                    arr[i] = Thread.new { apply(dst_rave_path,chunk) }
                    i += 1
            end
            arr.each {|t| t.join }
            @output.puts("Updating #{PATCHES_APPLIED_FILE} with the patches applied")
            update_patches_applied(@patches_to_apply,PATCHES_APPLIED_FILE) if @store_patches_applied

        end
        
        def get_rave_path
            file_join(CODER_COMMON_PATH,CODER_CWS_RELATIVE_PATH)
        end
    end #class
end #module