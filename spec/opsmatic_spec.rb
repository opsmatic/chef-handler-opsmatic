require 'spec_helper'

require 'pp'

describe "Chef::Handler::Opsmatic" do
  before(:all) do
    COLLECTOR_URL = "http://api.opsmatic.com/webhooks/events/chef"
    INTEGRATION_TOKEN = "xxxxx-yyyyy"
    HOSTNAME = "foo.example.com"

    @handler = Chef::Handler::Opsmatic.new(
      :integration_token => INTEGRATION_TOKEN,
      :collector_url => COLLECTOR_URL
    )

    @node = Chef::Node.build(HOSTNAME)
    @node.attributes.default[:fqdn] = HOSTNAME
  end

  before (:each) do
    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, {}, @events)
    @run_status = Chef::RunStatus.new(@node, @events)
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
end
