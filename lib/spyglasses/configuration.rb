# frozen_string_literal: true

module Spyglasses
  class Configuration
    DEFAULT_COLLECT_ENDPOINT = 'https://www.spyglasses.io/api/collect'
    DEFAULT_PATTERNS_ENDPOINT = 'https://www.spyglasses.io/api/patterns'
    DEFAULT_CACHE_TTL = 24 * 60 * 60 # 24 hours in seconds
    DEFAULT_PLATFORM_TYPE = 'ruby'

    attr_accessor :api_key, :debug, :collect_endpoint, :patterns_endpoint, 
                  :auto_sync, :platform_type, :cache_ttl, :exclude_paths

    def initialize
      # Load from environment variables by default
      @api_key = ENV['SPYGLASSES_API_KEY']
      @debug = ENV['SPYGLASSES_DEBUG'] == 'true'
      @collect_endpoint = ENV['SPYGLASSES_COLLECT_ENDPOINT'] || DEFAULT_COLLECT_ENDPOINT
      @patterns_endpoint = ENV['SPYGLASSES_PATTERNS_ENDPOINT'] || DEFAULT_PATTERNS_ENDPOINT
      @auto_sync = ENV['SPYGLASSES_AUTO_SYNC'] != 'false' # Default to true
      @platform_type = ENV['SPYGLASSES_PLATFORM_TYPE'] || DEFAULT_PLATFORM_TYPE
      @cache_ttl = (ENV['SPYGLASSES_CACHE_TTL'] || DEFAULT_CACHE_TTL).to_i
      @exclude_paths = []
    end

    def api_key_present?
      !@api_key.nil? && !@api_key.empty?
    end

    def debug?
      @debug
    end

    def auto_sync?
      @auto_sync
    end

    def validate!
      unless api_key_present?
        raise ConfigurationError, 'API key is required. Set SPYGLASSES_API_KEY environment variable or configure via Spyglasses.configure'
      end

      unless valid_url?(@collect_endpoint)
        raise ConfigurationError, "Invalid collect endpoint: #{@collect_endpoint}"
      end

      unless valid_url?(@patterns_endpoint)
        raise ConfigurationError, "Invalid patterns endpoint: #{@patterns_endpoint}"
      end

      if @cache_ttl < 0
        raise ConfigurationError, "Cache TTL must be non-negative: #{@cache_ttl}"
      end
    end

    def to_h
      {
        api_key: @api_key ? "#{@api_key[0..7]}..." : nil,
        debug: @debug,
        collect_endpoint: @collect_endpoint,
        patterns_endpoint: @patterns_endpoint,
        auto_sync: @auto_sync,
        platform_type: @platform_type,
        cache_ttl: @cache_ttl,
        exclude_paths: @exclude_paths
      }
    end

    private

    def valid_url?(url)
      return false if url.nil? || url.empty?
      
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end
  end
end 