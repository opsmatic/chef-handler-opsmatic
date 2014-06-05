require 'chef/handler'
require 'chef/resource/directory'
require 'net/http'
require 'uri'
require 'json'

class Chef
  class Handler
    class Opsmatic < ::Chef::Handler
      def initialize(config = {})
        @config = config
      end

      def report
        if @config[:integration_token].nil? || @config[:integration_token].empty?
          Chef::Log.warn("Opsmatic integraton integration_token missing, report handler disabled")
          return
        end

        if run_status.success?
          resource_count = run_status.updated_resources.count
          resource_word  = (resource_count == 1) ? "resource" : "resources"
          summary = "Chef updated #{resource_count} #{resource_word}"
        else
          summary = "Chef run failed"
        end

        opsmatic_event = {
          :timestamp => run_status.end_time.to_i,
          :source => 'chef_raw',
          :subject_type => 'hostname',
          :subject => node.fqdn,
          :type => 'cm/chef',
          :summary => summary,
          :data => {
            :status      => run_status.success? ? "success" : "failure",
            :start_time  => run_status.start_time,
            :end_time    => run_status.end_time,
            :duration    => run_status.elapsed_time,
            :updated_resources => []
          }
        }

        if not run_status.updated_resources.nil?
          run_status.updated_resources.each do |resource|
            detail = {
              :cookbook_name => resource.cookbook_name,
              :recipe_name   => resource.recipe_name,
              :action        => resource.action,
              :name          => resource.name,
              :resource_name => resource.resource_name
            }
            opsmatic_event[:data][:updated_resources] << detail
          end
        end

        # if there's an exception include details in event
        if !run_status.exception.nil? 
          opsmatic_event[:data][:exception] = run_status.formatted_exception
        end

        submit opsmatic_event
      end

      def submit(event) 
        Chef::Log.info("Posting chef run report to Opsmatic")
        
        url = URI.parse("#{@config[:collector_url]}?token=#{@config[:integration_token]}")

        http = Net::HTTP.new(url.host, url.port)
        http.open_timeout = 2
        http.read_timeout = 2
        http.use_ssl = (url.scheme == 'https')

        request = Net::HTTP::Post.new(url.request_uri)
        request["Content-Type"] = "application/json"
        request.body = [event].to_json

        begin
          response = http.request(request)
          if response.code != "202"
            Chef::Log.warn("Got a #{response.code} from Opsmatic event service, chef run wasn't recorded")
            Chef::Log.info(response.body)
          end
        rescue Timeout::Error
          Chef::Log.warn("Timed out connecting to Opsmatic event service, chef run wasn't recorded")
        rescue Exception => msg 
          Chef::Log.warn("An unhandled execption occured while posting event to Opsmatic event service: #{msg}")
        end
      end
    end
  end
end
