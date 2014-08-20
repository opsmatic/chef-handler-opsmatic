require 'spec_helper'
require 'pp'

describe "Chef::Handler::Opsmatic" do
  before(:all) do
    COLLECTOR_URL = "http://api.opsmatic.com/webhooks/events/chef"
    INTEGRATION_TOKEN = "xxxxx-yyyyy"
    HOSTNAME = "foo.example.com"
    AGENT_DIR = "/var/tmp/opsmatic"
    WATCHLIST_PATH = "external.d/chef_resources.json"

    @handler = Chef::Handler::Opsmatic.new(
      :integration_token => INTEGRATION_TOKEN,
      :collector_url => COLLECTOR_URL,
      :agent_dir => "/var/tmp/opsmatic"
    )

    @node = Chef::Node.build(HOSTNAME)
    @node.attributes.default[:fqdn] = HOSTNAME

    unless File.directory?(AGENT_DIR)
      Dir.mkdir(AGENT_DIR)
    end
  end

  before (:each) do
    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, {}, @events)
    @run_status = Chef::RunStatus.new(@node, @events)

    # mock some resources
    template = Chef::Resource::Template.new "/etc/sudoers.d/deploy_user"
    cookbook = Chef::Resource::CookbookFile.new "/etc/nginx/conf.d/ssl.conf"
    remote_file = Chef::Resource::RemoteFile.new "/var/db/translations.db"

    @all_resources = [ template, cookbook, remote_file ]
    @run_context.resource_collection.all_resources.replace(@all_resources)

    @run_status.start_clock
    @run_status.stop_clock
    @run_status.run_context = @run_context
    stub_request(:post, /#{COLLECTOR_URL}/).to_return(status: 202)
  end

  it "should successfully post an event" do
    @handler.run_report_unsafe(@run_status)
    expect a_request(:post, COLLECTOR_URL)
  end

  it "should not fail if exception is encoded ASCII-8BIT" do
    @run_status.exception = Exception.new("Exception with a binary char \xA9".force_encoding("ASCII-8BIT"))
    @handler.run_report_unsafe(@run_status)
    expect a_request(:post, COLLECTOR_URL)
  end

  it "should write a list of resources for the opsmatic agent to watch" do
    @handler.run_report_unsafe(@run_status)
    expect a_request(:post, COLLECTOR_URL)
    expect(File.exists?("#{AGENT_DIR}/#{WATCHLIST_PATH}")).to be true
  end

  it "should write a list of resources for the opsmatic agent to watch" do
    @handler.run_report_unsafe(@run_status)
    expect a_request(:post, COLLECTOR_URL)
    expect(File.exists?("#{AGENT_DIR}/#{WATCHLIST_PATH}")).to be true
  end

  it "should be valid json containing all the resources" do
    @handler.run_report_unsafe(@run_status)
    expect a_request(:post, COLLECTOR_URL)

    watched_files = {}
    result = JSON.parse(File.read("#{AGENT_DIR}/#{WATCHLIST_PATH}"))
    result["files"].each do |file|
      watched_files[file["path"]] = true
    end

    @all_resources.each do |resource|
      watched_files.delete(resource.path)
    end

    expect(watched_files.length).to equal(0)
  end

  after(:all) do
    FileUtils.rmtree(AGENT_DIR)
  end
end
