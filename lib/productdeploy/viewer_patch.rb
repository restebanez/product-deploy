module ProductDeploy

    class ViewerPatch < Patch
        
        def to_patch
            @role='VIEWER' #this refers to FileType in the xml file
            
            if @patches_to_apply.empty?
                @output.puts "Patches were already applied"
                return true
            end
            turn_xml_patches_into_hash
            consolidate_patches
            dst_rave_paths=get_rave_path(@db_name) # X number of Viewers
            #dst_rave_paths.each do |dst_rave_path|
            i = 0
            arr = []
            @consolidated_patches.each_pair do |k,v|
                consolidated_folder = {}
                consolidated_folder.store(k,v)
                dst_rave_paths.each do |dst_rave_path|
                    arr[i] = Thread.new { apply(dst_rave_path,consolidated_folder) }
                    i += 1
                end
            end
            arr.each {|t| t.join }
            
            @output.puts("Updating #{PATCHES_APPLIED_FILE} with the patches applied")
            update_patches_applied(@patches_to_apply,PATCHES_APPLIED_FILE)            
        end
        
        def get_rave_path(db_name)
            viewer_full_path =[]
            @viewers_relative_path.each do |viewer_relative_path|
                viewer_full_path << file_join(@common_rave_path,db_name,viewer_relative_path)
            end
            viewer_full_path
         end
        
    end #class
end #module