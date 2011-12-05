

# there is a patch name convention, if it contains the word "Baseline", files may be stored in different subfolders in s3, RelativePath field (from RaveVersion3.xml) is used to determine where to find them in s3

__DIR__ = File.dirname(__FILE__)

$LOAD_PATH.unshift __DIR__ unless
  $LOAD_PATH.include?(__DIR__) ||
  $LOAD_PATH.include?(File.expand_path(__DIR__))
  
  
#external gems
require 'rubygems'
require 'fog'
require 'nokogiri'
require 'fileutils'
require 'yaml'
require "benchmark"

# we extend Hash class with this method, because filenames are case-insensitive in windows
class Hash
    def has_key_insensitive?(key)
        self.keys.each { |k| return true if k.downcase == key.downcase } 
        return false
    end
end

MAX_THREAD = 30 #I've testing with 200 (too many open files), 100, 75, 50, 35, 30, 20

COMMON_RAVE_PATH = 'C:\MedidataAPP\Sites'
WEB_RELATIVE_PATH = 'MedidataRAVE'
APP_RELATIVE_PATH = 'RaveService'
VIEWERS_RELATIVE_PATH = %w{RaveCrystalViewers\Viewer1 RaveCrystalViewers\Viewer2} #In DR there are only 2 Viewers

CODER_COMMON_PATH = 'C:\Program Files (x86)\Medidata Solutions'
CODER_APP_RELATIVE_PATH = 'CoderWebServer2'
CODER_CWS_RELATIVE_PATH = 'CoderWebService2'

SQL_CMD = 'C:\Program Files\Microsoft SQL Server\100\Tools\binn\sqlcmd.exe'
CHEF_CLIENT_FILE = 'c:\chef\etc\client.rb'
PATCHES_APPLIED_FILE = 'c:\chef\etc\patches_applied.yaml'
DEBUG_XML_PATCHES = 'c:\chef\log\debug_xml_patches.yaml'
DEBUG_CONSOLIDATED_PATCHES = 'c:\chef\log\debug_consolidated_patches.yaml'

#internal
require 'productdeploy/output'
require 'productdeploy/output_chef'
require 'productdeploy/util'
require 'productdeploy/patch'
require 'productdeploy/app_patch'
require 'productdeploy/sql_patch'
require 'productdeploy/viewer_patch'
require 'productdeploy/web_patch'
require 'productdeploy/coder_app_patch.rb'
require 'productdeploy/coder_cws_patch.rb'


