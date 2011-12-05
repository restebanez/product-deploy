module ProductDeploy

    class WebPatch < Patch
        
        def to_patch
            @role='WEB' #this refers to FileType in the xml file
            
            if @patches_to_apply.empty?
                @output.puts "Patches were already applied"
                return true
            end
            turn_xml_patches_into_hash
            consolidate_patches
            dst_rave_path=get_rave_path(@db_name)
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
        
        def get_rave_path(db_name)
                 file_join(COMMON_RAVE_PATH,db_name,WEB_RELATIVE_PATH)
        end
        

    end #class
end #module