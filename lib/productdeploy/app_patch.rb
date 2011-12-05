module ProductDeploy

    class AppPatch < Patch
        

        def to_patch
            @role='APP' #this refers to FileType in the xml file
            
            if @patches_to_apply.empty?
                @output.puts "Patches were already applied"
                return true
            end
            turn_xml_patches_into_hash
            consolidate_patches
            dst_rave_path=get_rave_path(@db_name)
            @output.puts("Patching under #{dst_rave_path}")
            apply(dst_rave_path,@consolidated_patches)
            @output.puts("Updating #{PATCHES_APPLIED_FILE} with the patches applied")
            update_patches_applied(@patches_to_apply,PATCHES_APPLIED_FILE) if @store_patches_applied
        end
        
        def get_rave_path(db_name)        
                 file_join(COMMON_RAVE_PATH,db_name,APP_RELATIVE_PATH)
        end
         
    end #class
end #module