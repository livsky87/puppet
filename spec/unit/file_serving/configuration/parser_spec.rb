#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_serving/configuration/parser'


module FSConfigurationParserTesting
  def write_config_file(content)
    # We want an array, but we actually want our carriage returns on all of it.
    File.open(@path, 'w') {|f| f.puts content}
  end
end

describe Puppet::FileServing::Configuration::Parser do
  include PuppetSpec::Files

  before :each do
    @path = tmpfile('fileserving_config')
    FileUtils.touch(@path)
    @parser = Puppet::FileServing::Configuration::Parser.new(@path)
  end

  describe Puppet::FileServing::Configuration::Parser, " when parsing" do
    include FSConfigurationParserTesting

    it "should allow comments" do
      write_config_file("# this is a comment\n")
      expect { @parser.parse }.not_to raise_error
    end

    it "should allow blank lines" do
      write_config_file("\n")
      expect { @parser.parse }.not_to raise_error
    end

    it "should create a new mount for each section in the configuration" do
      mount1 = mock 'one', :validate => true
      mount2 = mock 'two', :validate => true
      Puppet::FileServing::Mount::File.expects(:new).with("one").returns(mount1)
      Puppet::FileServing::Mount::File.expects(:new).with("two").returns(mount2)
      write_config_file "[one]\n[two]\n"
      @parser.parse
    end

    # This test is almost the exact same as the previous one.
    it "should return a hash of the created mounts" do
      mount1 = mock 'one', :validate => true
      mount2 = mock 'two', :validate => true
      Puppet::FileServing::Mount::File.expects(:new).with("one").returns(mount1)
      Puppet::FileServing::Mount::File.expects(:new).with("two").returns(mount2)
      write_config_file "[one]\n[two]\n"

      result = @parser.parse
      expect(result["one"]).to equal(mount1)
      expect(result["two"]).to equal(mount2)
    end

    it "should only allow mount names that are alphanumeric plus dashes" do
      write_config_file "[a*b]\n"
      expect { @parser.parse }.to raise_error(ArgumentError)
    end

    it "should fail if the value for path/allow/deny starts with an equals sign" do
      write_config_file "[one]\npath = /testing"
      expect { @parser.parse }.to raise_error(ArgumentError)
    end

    it "should validate each created mount" do
      mount1 = mock 'one'
      Puppet::FileServing::Mount::File.expects(:new).with("one").returns(mount1)
      write_config_file "[one]\n"

      mount1.expects(:validate)

      @parser.parse
    end

    it "should fail if any mount does not pass validation" do
      mount1 = mock 'one'
      Puppet::FileServing::Mount::File.expects(:new).with("one").returns(mount1)
      write_config_file "[one]\n"

      mount1.expects(:validate).raises RuntimeError

      expect { @parser.parse }.to raise_error(RuntimeError)
    end

    it "should return comprehensible error message, if invalid line detected" do
      write_config_file "[one]\n\n\x01path /etc/puppetlabs/puppet/files\n\x01allow *\n"

      expect { @parser.parse }.to raise_error(ArgumentError, /Invalid line.*in.*, line 3/)
    end
  end

  describe Puppet::FileServing::Configuration::Parser, " when parsing mount attributes" do
    include FSConfigurationParserTesting

    before do
      @mount = stub 'testmount', :name => "one", :validate => true
      Puppet::FileServing::Mount::File.expects(:new).with("one").returns(@mount)
      @parser.stubs(:add_modules_mount)
    end

    it "should set the mount path to the path attribute from that section" do
      write_config_file "[one]\npath /some/path\n"

      @mount.expects(:path=).with("/some/path")
      @parser.parse
    end

    it "should tell the mount to allow any allow values from the section" do
      write_config_file "[one]\nallow something\n"

      @mount.expects(:info)
      @mount.expects(:allow).with("something")
      @parser.parse
    end

    it "should support inline comments" do
      write_config_file "[one]\nallow something \# will it work?\n"

      @mount.expects(:info)
      @mount.expects(:allow).with("something")
      @parser.parse
    end

    it "should tell the mount to deny any deny values from the section" do
      write_config_file "[one]\ndeny something\n"

      @mount.expects(:info)
      @mount.expects(:deny).with("something")
      @parser.parse
    end

    it "should return comprehensible error message, if failed on invalid attribute" do
      write_config_file "[one]\ndo something\n"

      expect { @parser.parse }.to raise_error(ArgumentError, /Invalid argument 'do' in .*, line 2/)
    end
  end

  describe Puppet::FileServing::Configuration::Parser, " when parsing the modules mount" do
    include FSConfigurationParserTesting

    before do
      @mount = stub 'modulesmount', :name => "modules", :validate => true
    end

    it "should create an instance of the Modules Mount class" do
      write_config_file "[modules]\n"

      Puppet::FileServing::Mount::Modules.expects(:new).with("modules").returns @mount
      @parser.parse
    end

    it "should warn if a path is set" do
      write_config_file "[modules]\npath /some/path\n"
      Puppet::FileServing::Mount::Modules.expects(:new).with("modules").returns(@mount)

      Puppet.expects(:warning)
      @parser.parse
    end
  end

  describe Puppet::FileServing::Configuration::Parser, " when parsing the plugins mount" do
    include FSConfigurationParserTesting

    before do
      @mount = stub 'pluginsmount', :name => "plugins", :validate => true
    end

    it "should create an instance of the Plugins Mount class" do
      write_config_file "[plugins]\n"

      Puppet::FileServing::Mount::Plugins.expects(:new).with("plugins").returns @mount
      @parser.parse
    end

    it "should warn if a path is set" do
      write_config_file "[plugins]\npath /some/path\n"

      Puppet.expects(:warning)
      @parser.parse
    end
  end
end
