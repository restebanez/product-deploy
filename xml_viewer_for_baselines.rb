#!/usr/bin/env ruby



begining_file ='<?xml version="1.0" encoding="utf-8"?>
<Patch xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <PatchNumber>002</PatchNumber>
  <PatchDescription>002 - Baselines ReportViewer, this is not a patch</PatchDescription>
  <PatchVersion>1</PatchVersion>
  <IsCritical>false</IsCritical>
  <PreRequisite></PreRequisite>
  <PreInstallation></PreInstallation>
  <MinDBVersion>5.6.3.0</MinDBVersion>
  <MaxDBVersion>5.6.3.87</MaxDBVersion>
  <StartInstructions></StartInstructions>
  <EndInstructions></EndInstructions>
  <RunInTransaction>false</RunInTransaction>
  <FailureEndInstructions></FailureEndInstructions>'

end_file ='</Patch>'

dst_path = "/Users/restebanez/Desktop/aws-mdsol-dev-rave-patches-5.6.3.86/002 - Baselines ReportViewer/"
base_path = "/Users/restebanez/Desktop/aws-mdsol-dev-rave-patches-5.6.3.86/002 - Baselines ReportViewer"
dst_xml_file=dst_path + "RavePatch3.xml"
xml = File.open(dst_xml_file,"w")
xml << begining_file
Dir.chdir(base_path)
Dir.glob("**/*").each do |file|
    next if File.directory?(file) # we don't want directories
    #script_name= "MedidataRave/" +File.basename(file)
    script_name= File.basename(file)
    #file = "MedidataRave/" + file
    puts file
    #FileUtils.cp(file,dst_path)
    
    relative_path=File.dirname(file)
    relative_path.gsub!(/\//,"\\") # Linux to Windows
    relative_path="" if relative_path == '.' # clean up
    relative_path = "\\" + relative_path # it always starts with a \
    
    puts("Either non relative path or non relative_path on #{file}") if (relative_path.empty? || file.empty?)
    #print "."
    web_line="<Script ScriptName=\"#{script_name}\" ScriptDate=\"\" ScriptNumber=\"\" ScriptRevision=\"0\" ScriptMinDBVersion=\"\" ScriptMaxDBVersion=\"\" ScriptIsRerunnable=\"0\" ScriptRequiredForBuild=\"\" ScriptDoNotRun=\"false\" FileType=\"VIEWER\" RelativePath=\"#{relative_path}\" BackObject=\"None\" BackObjectName=\"\" IsNew=\"false\" />\n"
    xml << web_line

end
xml << end_file