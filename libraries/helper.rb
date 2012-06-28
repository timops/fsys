#                                                                                                                                                         
# Author:: Tim Green <tgreen@opscode.com>
# Cookbook Name:: fsys
# Resource:: monitor
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


require 'json'
require 'digest'
require 'find'


class DirEntity

  include Enumerable

  attr_accessor :filename
  attr_accessor :file_hash
  attr_accessor :perms
  attr_accessor :owner
  attr_accessor :group
  attr_accessor :is_dir
  attr_accessor :mtime

  def initialize(filename, is_dir=false)
    @filename = filename
    @is_dir = is_dir

    @file_hash = nil
    @owner = nil
    @group = nil
    @perms = nil
    @mtime = nil
  end 

  def report
    puts "filename: #{@filename}"
    puts "directory: #{@is_dir}"
    puts "file_hash: #{@file_hash}"
    puts "owner: #{@owner}"
    puts "group: #{@group}"
    puts "perms: #{@perms}"
  end

  def print_json
    puts JSON.pretty_generate(
      { @filename => 
        { 'directory' => @is_dir, 'file_hash' => @file_hash, 'owner' => @owner, 'group' => @group, 'perms' => @perms, 'mtime' => @mtime } 
      }
    )
  end

  def create_json
    @json_obj = JSON.generate(
      { @filename => 
        { 'directory' => @is_dir, 'file_hash' => @file_hash, 'owner' => @owner, 'group' => @group, 'perms' => @perms, 'mtime' => @mtime } 
      }
    )
  end

  def to_hash
    h = {}
    h[@filename] = { 'directory' => @is_dir, 'file_hash' => @file_hash, 'owner' => @owner, 'group' => @group, 'perms' => @perms, 'mtime' => @mtime }
  end

end

class NodeEntity
  def initialize
    @fsys_objects = [] 
  end

  # create a DirEntity object for each file/directory in the specified directory.
  # the filesystem objects get appended to an array of hashes - @fsys_objects.
  def scan_dirs(path)
    #paths.each do |dir_obj|
    dir_obj = File::expand_path(path)
    Find.find(dir_obj) do |ent|
      dir_ent = DirEntity.new(ent)
      # get SHA 256 if it's a file
      if File.ftype(ent) == 'file'
        dir_ent.file_hash = Digest::SHA256.file(ent) 
      elsif File.ftype(ent) == 'directory'
        dir_ent.is_dir = true
      else File.ftype(ent) == 'link'
        # how to check for dangling symlink?  'next' if there is one.
        next
      end
      # stat both files and directories to be stored.
      stat = File::Stat.new(ent)
      dir_ent.perms = sprintf("%o", stat.mode)
      dir_ent.owner, dir_ent.group, dir_ent.mtime = stat.uid, stat.gid, stat.mtime
        
      # extra output for debugging.
      # dir_ent.report
      # dir_ent.print_json
        
      # append to filesystem object array.
      @fsys_objects << dir_ent.to_hash
    end
  end

  # dump @fsys_objects to valid JSON file in specified directory.
  def dump_json(directory, node)
    @node = node
    @filename = "#{directory}/#{@node}.json"
    unless File.exists?("#{@filename}")
      f = File.new("#{@filename}", "w") 
      @fsys_objects.each do |dir_ent|
        f << "#{dir_ent.create_json}\n"
      end
      f.close
    end
  end

  # return individual filesystem object to caller.
  def get_node_object
    unless @fsys_objects.empty?
      @fsys_objects.each do |fs_obj|
        puts fs_obj.class
        puts fs_obj
        @filename, @obj = fs_obj.shift
        yield @filename, @obj
      end
    end
  end

  # load JSON baseline from disk.
  def load_json(directory, node)
    @node = node
    @json_file = "#{directory}/#{@node}.json"
    begin
      f = File.open(@json_file)
    rescue Errno::ENOENT => no_baseline
      Chef::Log.info("Baseline for this node does not exist.  Did you use action :baseline first?")
    end

    # Deserialize JSON data.
    f.each do |line|
      j = JSON.load(line)
      @fsys_objects << j
      # @filename, @obj = j.shift
    end

    f.close
  end
end 
