#                                                                                                                                                         
# Author:: Tim Green <tgreen@opscode.com>
# Cookbook Name:: fsys
# Provider:: monitor
#
# Copyright 2012, Opscode, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


action :baseline do
  check_gems
  # Right now, only supports recursion.  The resource attribute on the next line doesn't do anything at the moment.
  @recursive = @new_resource.recursive
  @node_obj = NodeEntity.new  
  @new_resource.paths.each do |path|
    # Populate all the fsys objects which the NodeEntity is composed of.
    @node_obj.scan_dirs(path)
  end
  @node_obj.dump_json(@new_resource.cache_dir, node.hostname)
end

action :check do
  @source = {}
  @dest = {}

  check_gems
  @recursive = @new_resource.recursive
  @node_saved = NodeEntity.new
  @node_saved.load_json(@new_resource.cache_dir, node.hostname)

  @node_new = NodeEntity.new
  @new_resource.paths.each do |path|
    @node_new.scan_dirs(path)
  end

  @node_new.get_node_object do |fname, attribs|
    @source[fname] = {}
    @source[fname] = attribs  
  end
 
  @node_saved.get_node_object do |fname, attribs|
    @dest[fname] = {}
    @dest[fname] = attribs
  end 

  puts @source
  puts @dest
end

private 

def check_gems
  begin
    require 'digest'
    require 'json'
    require 'fileutils'
  rescue LoadError
    Chef::Log.info("Missing required gems, installing now.")
    %w(digest json fileutils).each do |gempkg|
      chef_gem gempkg do
        action :install
      end
    end
    require 'digest'
    require 'json'
    require 'fileutils'
  end
end
