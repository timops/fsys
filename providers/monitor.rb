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
  check_gems

  @baseline = {}
  @new_data = {}
  @recursive = @new_resource.recursive

  # load baseline data from JSON.
  @node_saved = NodeEntity.new
  @node_saved.load_json(@new_resource.cache_dir, node.hostname)
  # populate updated node data about monitored filesystems into @node_new.
  @node_new = NodeEntity.new
  @new_resource.paths.each do |path|
    @node_new.scan_dirs(path)
  end
  # create new baseline if force_update is enabled. 
  @node_new.dump_json(@new_resource.cache_dir, node.hostname, true) if @new_resource.force_update == true
  @node_new.get_node_object do |fname, fs_obj|
    @new_data[fname] = fs_obj
  end
  @node_saved.get_node_object do |fname, fs_obj|
    @baseline[fname] = fs_obj
  end 
  @delta = {}
  @baseline.each do |fname, stats|
    @new_data.each do |fnew, stats_new|
      # if the filename is a match, we should compare stats.
      if fname == fnew
        if stats == stats_new
          puts "[LOG]: #{fname} has not changed."
        else
          puts "[LOG]: #{fname} has changed!"
          @delta[fname] = {}
          @delta[fname]['old'] = stats
          @delta[fname]['new'] = stats_new
        end
        # remove files from both hashes to speed things up.  we also need to do some work on added/removed files when we're done.
        @baseline.delete(fname)
        @new_data.delete(fnew)
      end
    end
  end
  report_results(@delta) 
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

def report_results(delta)
  @num_changed = delta.size
  puts %(\t----------------
         summary report for node #{node.hostname}
         Total files changed: #{@num_changed}
         ----------------
        )
  delta.each do |fname, stats|
    puts "#{fname}"
    puts "----------------------------------\n"
    stats['old'].each do |key, val|
      if stats['old'][key] != stats['new'][key]
        puts "#{key}: #{stats['old'][key]} | #{stats['new'][key]}"
      end
    end
    puts "\n\n"
  end
end
