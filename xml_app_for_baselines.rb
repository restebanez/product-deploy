#!/usr/bin/env ruby
require 'rubygems'
require 'fileutils'



begining_file ='<?xml version="1.0" encoding="utf-8"?>
<Patch xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <PatchNumber>001</PatchNumber>
  <PatchDescription>001 - baseline, this is not a patch</PatchDescription>
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


# This is for web
#dst_path = "/Users/restebanez/Desktop/aws-mdsol-dev-rave-patches-5.6.3.86/000 - Baselines MedidataRave/"
#base_path = "/Users/restebanez/Desktop/aws-mdsol-dev-rave-patches-5.6.3.86/000 - Baselines/MedidataRave"


# This is for app, don't forget to modify PatchNumber above with 001 and the FileType
dst_path = "/Users/restebanez/Desktop/aws-mdsol-dev-rave-patches-5.6.3.86/001 - Baselines Raveservice/"
base_path = "/Users/restebanez/Desktop/aws-mdsol-dev-rave-patches-5.6.3.86/000 - Baselines/Rave Service"

dst_xml_file=dst_path + "RavePatch3.xml"
xml = File.open(dst_xml_file,"w")
xml << begining_file
Dir.chdir(base_path)
Dir.glob("**/*").each do |file|
    next if File.directory?(file) # we don't want directories
    script_name=File.basename(file)
    puts file
    full_dst_path = File.join(dst_path,script_name)
    abort("#{file} to #{full_dst_path} already exists") if File.file?(full_dst_path)
    FileUtils.cp(file,full_dst_path)
    abort("#{file} wasn't copied correctly to #{full_dst_path}") unless File.file?(full_dst_path)
    
    relative_path=File.dirname(file)
    relative_path.gsub!(/\//,"\\") # Linux to Windows
    relative_path="" if relative_path == '.' # clean up
    relative_path = "\\" + relative_path # it always starts with a \
    
    puts("Either non relative path or non relative_path on #{file}") if (relative_path.empty? || script_name.empty?)
    #print "."
    web_line="<Script ScriptName=\"#{script_name}\" ScriptDate=\"\" ScriptNumber=\"\" ScriptRevision=\"0\" ScriptMinDBVersion=\"\" ScriptMaxDBVersion=\"\" ScriptIsRerunnable=\"0\" ScriptRequiredForBuild=\"\" ScriptDoNotRun=\"false\" FileType=\"APP\" RelativePath=\"#{relative_path}\" BackObject=\"None\" BackObjectName=\"\" IsNew=\"false\" />\n"
    xml << web_line

end
xml << end_file