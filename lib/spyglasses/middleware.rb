# frozen_string_literal: true

require 'uri'

module Spyglasses
  class Middleware
    include Spyglasses::Types

    def initialize(app, options = {})
      @app = app
      @configuration = setup_configuration(options)
      @client = Client.new(@configuration)
      @exclude_paths = @configuration.exclude_paths + default_exclude_paths
      
      log_debug("Spyglasses middleware initialized with configuration: #{@configuration.to_h}")
    end

    def call(env)
      request_start_time = Time.now
      request = Rack::Request.new(env)
      
      # Skip excluded paths
      if should_exclude_path?(request.path)
        log_debug("Excluding path: #{request.path}")
        return @app.call(env)
      end

      # Extract request information
      user_agent = request.user_agent || ''
      referrer = request.referrer || ''
      
      log_debug("Processing request to #{request.path}")
      log_debug("User-Agent: #{user_agent[0..99]}#{user_agent.length > 100 ? '...' : ''}")
      log_debug("Referrer: #{referrer}") unless referrer.empty?

      # Detect bot or AI referrer
      detection_result = @client.detect(user_agent, referrer)
      
      if detection_result.source_type != 'none'
        log_debug("Detection result: #{detection_result.to_h}")
        
        # Handle blocking
        if detection_result.should_block
          log_debug("Blocking request from #{detection_result.source_type}: #{detection_result.matched_pattern}")
          
          # Log the blocked request
          log_request_async(detection_result, request, 403, Time.now - request_start_time)
          
          # Return 403 Forbidden
          return forbidden_response
        end
      end

      # Process the request normally
      begin
        status, headers, response = @app.call(env)
        response_time = Time.now - request_start_time
        
        # Log successful requests with detection results
        if detection_result.source_type != 'none'
          log_request_async(detection_result, request, status, response_time)
        end
        
        [status, headers, response]
      rescue => e
        # Log error requests if we detected something
        if detection_result.source_type != 'none'
          response_time = Time.now - request_start_time
          log_request_async(detection_result, request, 500, response_time)
        end
        
        raise e
      end
    end

    private

    def setup_configuration(options)
      config = Configuration.new
      
      # Override with provided options
      options.each do |key, value|
        case key.to_sym
        when :api_key
          config.api_key = value
        when :debug
          config.debug = value
        when :collect_endpoint
          config.collect_endpoint = value
        when :patterns_endpoint
          config.patterns_endpoint = value
        when :auto_sync
          config.auto_sync = value
        when :platform_type
          config.platform_type = value
        when :cache_ttl
          config.cache_ttl = value.to_i
        when :exclude_paths
          config.exclude_paths = Array(value)
        end
      end
      
      config
    end

    def default_exclude_paths
      [
        # Static assets
        /\.(css|js|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|eot)$/i,
        # Rails specific
        %r{^/rails/},
        %r{^/assets/},
        # Common paths
        %r{^/favicon\.ico},
        %r{^/robots\.txt},
        %r{^/sitemap\.xml},
        # Health checks
        %r{^/health},
        %r{^/status},
        %r{^/ping}
      ]
    end

    def should_exclude_path?(path)
      @exclude_paths.any? do |pattern|
        case pattern
        when String
          path.include?(pattern)
        when Regexp
          pattern.match?(path)
        else
          false
        end
      end
    end

    def log_request_async(detection_result, request, status, response_time)
      return unless @configuration.api_key_present?

      # Ensure ip_address is never nil
      client_ip = extract_client_ip(request) || '127.0.0.1'
      
      request_info = {
        url: request.url,
        user_agent: request.user_agent || '',
        ip_address: client_ip,
        request_method: request.request_method,
        request_path: request.path,
        # Ensure request_query is never nil - use empty string if no query
        request_query: request.query_string || '',
        referrer: request.referrer,
        response_status: status,
        response_time_ms: (response_time * 1000).round,
        headers: extract_headers(request)
      }

      @client.log_request(detection_result, request_info)
      
      log_debug("Logging #{detection_result.source_type} visit: #{detection_result.matched_pattern}")
    end

    def extract_client_ip(request)
      # Try various headers to get the real client IP
      ip = [
        request.env['HTTP_X_FORWARDED_FOR'],
        request.env['HTTP_X_REAL_IP'],
        request.env['HTTP_CF_CONNECTING_IP'], # Cloudflare
        request.env['HTTP_X_CLIENT_IP'],
        request.env['REMOTE_ADDR']
      ].find { |ip| ip && !ip.empty? && ip != '127.0.0.1' }
      
      # If we found an IP in headers, handle comma-separated lists (X-Forwarded-For)
      if ip && ip.include?(',')
        ip = ip.split(',').first.strip
      end
      
      # Return the found IP or fallback to request.ip
      ip || request.ip
    end

    def extract_headers(request)
      headers = {}
      request.env.each do |key, value|
        if key.start_with?('HTTP_') && value.is_a?(String)
          header_name = key[5..-1].downcase.tr('_', '-')
          headers[header_name] = value
        end
      end
      headers
    end

    def forbidden_response
      [
        403,
        {
          'Content-Type' => 'text/plain',
          'Content-Length' => '13'
        },
        ['Access Denied']
      ]
    end

    def log_debug(message)
      return unless @configuration.debug?
      
      puts "[Spyglasses] #{message}"
    end
  end
end 