#!/usr/bin/env ruby -w

require 'json'
require 'digest'
require 'find'

files_and_dirs = [ '~/chef-repo/cookbooks', '~/chef-repo/README.md', '/Users/timgreen/chef-repo/ec2-boot.sh' ] 

class DirEntity
  attr_accessor :filename
  attr_accessor :file_hash
  attr_accessor :perms
  attr_accessor :owner
  attr_accessor :group
  attr_accessor :is_dir

  def initialize(filename, is_dir=false)
    @filename = filename
    @is_dir = is_dir

    @file_hash = nil
    @owner = nil
    @group = nil
    @perms = nil
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
        { 'directory' => @is_dir, 'file_hash' => @file_hash, 'owner' => @owner, 'group' => @group, 'perms' => @perms } 
      }
    )
  end

  def create_json
    @json_obj = JSON.generate(
      { @filename => 
        { 'directory' => @is_dir, 'file_hash' => @file_hash, 'owner' => @owner, 'group' => @group, 'perms' => @perms } 
      }
    )
  end
end

class NodeEntity
  def initialize
    @fsys_objects = [] 
  end

  # create object for each file/directory, and collect attributes to be serialized.
  def scan_dirs(paths)
    paths.each do |dir_obj|
      dir_obj = File::expand_path(dir_obj)
      Find.find(dir_obj) do |ent|
        dir_ent = DirEntity.new(ent)
        # get SHA 256 if it's a file
        if File.ftype(ent) == 'file'
          dir_ent.file_hash = Digest::SHA256.file(ent) 
        else
          dir_ent.is_dir = true
        end
        # stat both files and directories to be stored.
        stat = File::Stat.new(ent)
        dir_ent.perms = sprintf("%o", stat.mode)
        dir_ent.owner, dir_ent.group = stat.uid, stat.gid 

        dir_ent.report
        dir_ent.print_json
        @fsys_objects << dir_ent.create_json
      end
    end
  end

  def dump_json(directory, node)
    @node = 'test'
    @filename = "#{directory}/#{@node}.json"
    unless File.exists?("#{@filename}")
      f = File.new("#{@filename}", "w") 
      @fsys_objects.each do |json_ent|
        f << "#{json_ent}\n"
        # json_ent.dump(f)
      end
      f.close
    end
  end
end 

n = NodeEntity.new
n.scan_dirs(files_and_dirs)
n.dump_json('/tmp')

f = File.open('/private/tmp/test.json')

f.each do |line|
  j = JSON.load(line)
  filename, obj = j.shift
  if obj['directory'] == false
    puts obj['file_hash']
  end
end
