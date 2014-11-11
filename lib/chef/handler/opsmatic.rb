require 'chef/handler'
require 'chef/resource/directory'
require 'net/http'
require 'uri'
require 'json'

require 'chef/handler/opsmatic_version'

class Chef
  class Handler
    class Opsmatic < ::Chef::Handler

      def initialize(config = {})
        @config = config
        @config[:agent_dir] ||= "/var/db/opsmatic-agent"
        @watch_files = {}
      end

      # prepares a report of the current chef run
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
          :category => 'automation',
          :type => 'cm/chef',
          :summary => summary,
          :data => {
            :status      => run_status.success? ? "success" : "failure",
            :start_time  => run_status.start_time.to_i,
            :end_time    => run_status.end_time.to_i,
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
          clean_exception = run_status.formatted_exception.encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'})
          opsmatic_event[:data][:exception] = clean_exception
        end

        # analyze and collect any potentially monitorable resources
        collect_resources run_status.all_resources

        # submit our event
        submit opsmatic_event
      end

      # collects up details on file resources managed by chef on the host and writes
      # the list to a directory for the opsmatic-agent to consume to hint at interesting
      # files the agent can watch
      def collect_resources(all_resources)
        return unless File.directory?(@config[:agent_dir])

        # if the chef run didn't even make it far enough to report resources
        # we don't want to do anything
        return if all_resources.nil? or all_resources.empty?

        all_resources.each do |resource|
          case resource
          when Chef::Resource::CookbookFile
            @watch_files[resource.path] = true
          when Chef::Resource::Template
            @watch_files[resource.path] = true
          when Chef::Resource::RemoteFile
            @watch_files[resource.path] = true
          end
        end

        begin
          data_dir = "#{@config[:agent_dir]}/external.d"
          if not File.directory?(data_dir)
            Dir.mkdir(data_dir)
          end
          File.open("#{data_dir}/chef_resources.json", "w") do |f|
            watchlist = []
            @watch_files.keys.each do |k|
              watchlist << { "path" => k } 
            end
            f.write({ "files" => watchlist }.to_json)
          end
        rescue Exception => msg
          Chef::Log.warn("Unable to save opsmatic agent file watch list: #{msg}")
        end
      end

      def check_proxy(proxy)
      begin
        proxy_uri = URI.parse(ENV[proxy])
        if not proxy_uri.host
          Chef::Log.warn("#{proxy} set but could not parse URI")
          return nil
        end
      rescue URI::InvalidURIError
        Chef::Log.warn("#{proxy} set with invalid URI")
        return nil
        end
      return proxy_uri
      end

      # submit report to the opsmatic collector
      def submit(event) 
        Chef::Log.info("Posting chef run report to Opsmatic")
        
        url = URI.parse(@config[:collector_url])

        qs = url.query.nil? ? [] : url.query.split("&")
        qs << "token=#{@config[:integration_token]}"
        url.query = qs.join("&")
        proxy_uri = nil

        %w(HTTPS_PROXY https_proxy HTTP_PROXY http_proxy).each do |proxy|
          proxy_uri = check_proxy(proxy)
          break if proxy_uri
        end

        if proxy_uri
          p_user, p_pass = proxy_uri.userinfo.split(/:/) if proxy_uri.userinfo
          http = Net::HTTP.new(url.host, url.port, proxy_uri.host, proxy_uri.port, p_user, p_pass)
        else
          http = Net::HTTP.new(url.host, url.port)
        end

        http.open_timeout = 2
        http.read_timeout = 2
        http.use_ssl = (url.scheme == 'https')

        if not @config[:ssl_peer_verify]
          # TODO: need to work out how to correctly find CA's on all platforms
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        request = Net::HTTP::Post.new(url.request_uri)
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "Opsmatic Chef Handler #{Chef::Handler::Opsmatic::VERSION}"
        request.body = event.to_json

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
