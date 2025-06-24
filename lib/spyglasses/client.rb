# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'thread'

module Spyglasses
  class Client
    include Spyglasses::Types

    attr_reader :configuration, :patterns, :ai_referrers, :pattern_version, :last_pattern_sync

    def initialize(config = nil)
      @configuration = config || Configuration.new
      @patterns = []
      @ai_referrers = []
      @pattern_regex_cache = {}
      @pattern_version = '1.0.0'
      @last_pattern_sync = 0
      @mutex = Mutex.new
      
      # Property settings loaded from API
      @block_ai_model_trainers = false
      @custom_blocks = []
      @custom_allows = []
      
      load_default_patterns
      
      # Auto-sync patterns if enabled and API key is present
      if @configuration.auto_sync? && @configuration.api_key_present?
        Thread.new do
          begin
            sync_patterns
          rescue => e
            log_debug("Error syncing patterns: #{e.message}")
          end
        end
      end
    end

    # Sync patterns from the API
    def sync_patterns
      unless @configuration.api_key_present?
        message = 'No API key set for pattern sync'
        log_debug(message)
        return message
      end

      begin
        uri = URI(@configuration.patterns_endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = 30
        http.open_timeout = 10

        request = Net::HTTP::Get.new(uri)
        request['Content-Type'] = 'application/json'
        request['x-api-key'] = @configuration.api_key

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          message = "Pattern sync HTTP error #{response.code}: #{response.message}"
          log_debug(message)
          return message
        end

        data = JSON.parse(response.body)
        api_response = ApiPatternResponse.new(data)

        # Thread-safe update of patterns
        @mutex.synchronize do
          @patterns = api_response.patterns
          @ai_referrers = api_response.ai_referrers
          @pattern_version = api_response.version
          @last_pattern_sync = Time.now.to_i
          
          # Update property settings
          @block_ai_model_trainers = api_response.property_settings.block_ai_model_trainers
          @custom_blocks = api_response.property_settings.custom_blocks
          @custom_allows = api_response.property_settings.custom_allows
          
          # Clear regex cache
          @pattern_regex_cache.clear
        end

        log_debug("Synced #{@patterns.length} patterns and #{@ai_referrers.length} AI referrers")
        log_debug("Property settings: block_ai_model_trainers=#{@block_ai_model_trainers}, custom_blocks=#{@custom_blocks.length}, custom_allows=#{@custom_allows.length}")

        api_response
      rescue => e
        message = "Error syncing patterns: #{e.message}"
        log_debug(message)
        message
      end
    end

    # Detect if a user agent is a bot
    def detect_bot(user_agent)
      return DetectionResult.new unless user_agent && !user_agent.empty?

      log_debug("Checking user agent: \"#{user_agent[0..149]}#{user_agent.length > 150 ? '...' : ''}\"")
      log_debug("Testing against #{@patterns.length} bot patterns")

      @patterns.each do |pattern|
        begin
          regex = get_regex_for_pattern(pattern.pattern)
          log_debug("Testing pattern: \"#{pattern.pattern}\" (#{pattern.type || 'unknown'} - #{pattern.company || 'unknown company'})")

          if regex.match?(user_agent)
            should_block = should_block_pattern?(pattern)
            
            log_debug("✅ BOT DETECTED! Pattern matched: \"#{pattern.pattern}\"")
            log_debug("Bot details: type=#{pattern.type}, category=#{pattern.category}, subcategory=#{pattern.subcategory}, company=#{pattern.company}, is_ai_model_trainer=#{pattern.is_ai_model_trainer}, should_block=#{should_block}")

            bot_info = BotInfo.new(
              pattern: pattern.pattern,
              type: pattern.type || 'unknown',
              category: pattern.category || 'Unknown',
              subcategory: pattern.subcategory || 'Unclassified',
              company: pattern.company,
              is_compliant: pattern.is_compliant || false,
              is_ai_model_trainer: pattern.is_ai_model_trainer || false,
              intent: pattern.intent || 'unknown',
              url: pattern.url
            )

            return DetectionResult.new(
              is_bot: true,
              should_block: should_block,
              source_type: 'bot',
              matched_pattern: pattern.pattern,
              info: bot_info
            )
          end
        rescue => e
          log_debug("Error with pattern #{pattern.pattern}: #{e.message}")
        end
      end

      log_debug('No bot patterns matched user agent')
      DetectionResult.new
    end

    # Detect if a referrer is from an AI platform
    def detect_ai_referrer(referrer)
      return DetectionResult.new unless referrer && !referrer.empty?

      log_debug("Checking referrer: \"#{referrer}\"")

      # Extract hostname from referrer
      hostname = extract_hostname(referrer)
      log_debug("Extracted hostname: \"#{hostname}\"")

      @ai_referrers.each do |ai_referrer|
        log_debug("Testing AI referrer: \"#{ai_referrer.name}\" (#{ai_referrer.company}) with patterns: #{ai_referrer.patterns.join(', ')}")

        ai_referrer.patterns.each do |pattern|
          log_debug("Testing AI referrer pattern: \"#{pattern}\" against hostname: \"#{hostname}\"")

          if hostname.include?(pattern)
            log_debug("✅ AI REFERRER DETECTED! Pattern matched: \"#{pattern}\"")
            log_debug("AI referrer details: name=#{ai_referrer.name}, company=#{ai_referrer.company}, id=#{ai_referrer.id}")

            return DetectionResult.new(
              is_bot: false,
              should_block: false,
              source_type: 'ai_referrer',
              matched_pattern: pattern,
              info: ai_referrer
            )
          end
        end
      end

      DetectionResult.new
    end

    # Combined detection for both bot and AI referrer
    def detect(user_agent, referrer = nil)
      log_debug("detect() called with user_agent: #{user_agent ? "\"#{user_agent[0..99]}#{user_agent.length > 100 ? '...' : ''}\"" : 'nil'}, referrer: #{referrer || 'nil'}")

      # Check for bot first
      bot_result = detect_bot(user_agent)
      if bot_result.is_bot
        log_debug('🤖 Final result: BOT detected, returning bot result')
        return bot_result
      end

      # Check for AI referrer if provided
      if referrer
        log_debug('No bot detected, starting AI referrer detection...')
        referrer_result = detect_ai_referrer(referrer)
        if referrer_result.source_type == 'ai_referrer'
          log_debug('🧠 Final result: AI REFERRER detected, returning referrer result')
          return referrer_result
        end
      else
        log_debug('No referrer provided, skipping AI referrer detection')
      end

      DetectionResult.new
    end

    # Log a request to the collector
    def log_request(detection_result, request_info)
      log_debug("log_request() called for source_type: #{detection_result.source_type}")

      return unless @configuration.api_key_present? && detection_result.source_type != 'none'

      log_debug("Preparing to log #{detection_result.source_type} event to collector")

      # Prepare metadata
      metadata = { was_blocked: detection_result.should_block }

      if detection_result.source_type == 'bot' && detection_result.info
        bot_info = detection_result.info
        metadata.merge!(
          agent_type: bot_info.type,
          agent_category: bot_info.category,
          agent_subcategory: bot_info.subcategory,
          company: bot_info.company,
          is_compliant: bot_info.is_compliant,
          intent: bot_info.intent,
          confidence: 0.9,
          detection_method: 'pattern_match'
        )
      elsif detection_result.source_type == 'ai_referrer' && detection_result.info
        referrer_info = detection_result.info
        metadata.merge!(
          source_type: 'ai_referrer',
          referrer_id: referrer_info.id,
          referrer_name: referrer_info.name,
          company: referrer_info.company
        )
      end

      payload = CollectorPayload.new(
        url: request_info[:url],
        user_agent: request_info[:user_agent],
        ip_address: request_info[:ip_address],
        request_method: request_info[:request_method],
        request_path: request_info[:request_path],
        request_query: request_info[:request_query],
        referrer: request_info[:referrer],
        response_status: request_info[:response_status] || (detection_result.should_block ? 403 : 200),
        response_time_ms: request_info[:response_time_ms] || 0,
        headers: request_info[:headers] || {},
        platform_type: @configuration.platform_type,
        metadata: metadata
      )

      # Send request in background thread to avoid blocking
      Thread.new do
        send_collector_request(payload, detection_result.source_type)
      end
    end

    private

    def load_default_patterns
      # Default patterns similar to the TypeScript SDK
      @patterns = [
        # AI Assistants
        BotPattern.new(
          pattern: 'ChatGPT-User\/[0-9]',
          url: 'https://platform.openai.com/docs/bots',
          type: 'chatgpt-user',
          category: 'AI Agent',
          subcategory: 'AI Assistants',
          company: 'OpenAI',
          is_compliant: true,
          is_ai_model_trainer: false,
          intent: 'UserQuery'
        ),
        BotPattern.new(
          pattern: 'Perplexity-User\/[0-9]',
          url: 'https://docs.perplexity.ai/guides/bots',
          type: 'perplexity-user',
          category: 'AI Agent',
          subcategory: 'AI Assistants',
          company: 'Perplexity AI',
          is_compliant: true,
          is_ai_model_trainer: false,
          intent: 'UserQuery'
        ),
        BotPattern.new(
          pattern: 'Gemini-User\/[0-9]',
          url: 'https://ai.google.dev/gemini-api/docs/bots',
          type: 'gemini-user',
          category: 'AI Agent',
          subcategory: 'AI Assistants',
          company: 'Google',
          is_compliant: true,
          is_ai_model_trainer: false,
          intent: 'UserQuery'
        ),
        BotPattern.new(
          pattern: 'Claude-User\/[0-9]',
          url: 'https://support.anthropic.com/en/articles/8896518-does-anthropic-crawl-data-from-the-web-and-how-can-site-owners-block-the-crawler',
          type: 'claude-user',
          category: 'AI Agent',
          subcategory: 'AI Assistants',
          company: 'Anthropic',
          is_compliant: true,
          is_ai_model_trainer: false,
          intent: 'UserQuery'
        ),
        
        # AI Model Training Crawlers
        BotPattern.new(
          pattern: 'CCBot\/[0-9]',
          url: 'https://commoncrawl.org/ccbot',
          type: 'ccbot',
          category: 'AI Crawler',
          subcategory: 'Model Training Crawlers',
          company: 'Common Crawl',
          is_compliant: true,
          is_ai_model_trainer: true,
          intent: 'DataCollection'
        ),
        BotPattern.new(
          pattern: 'ClaudeBot\/[0-9]',
          url: 'https://support.anthropic.com/en/articles/8896518-does-anthropic-crawl-data-from-the-web-and-how-can-site-owners-block-the-crawler',
          type: 'claude-bot',
          category: 'AI Crawler',
          subcategory: 'Model Training Crawlers',
          company: 'Anthropic',
          is_compliant: true,
          is_ai_model_trainer: true,
          intent: 'DataCollection'
        ),
        BotPattern.new(
          pattern: 'GPTBot\/[0-9]',
          url: 'https://platform.openai.com/docs/gptbot',
          type: 'gptbot',
          category: 'AI Crawler',
          subcategory: 'Model Training Crawlers',
          company: 'OpenAI',
          is_compliant: true,
          is_ai_model_trainer: true,
          intent: 'DataCollection'
        ),
        BotPattern.new(
          pattern: 'meta-externalagent\/[0-9]',
          url: 'https://developers.facebook.com/docs/sharing/webmasters/crawler',
          type: 'meta-externalagent',
          category: 'AI Crawler',
          subcategory: 'Model Training Crawlers',
          company: 'Meta',
          is_compliant: true,
          is_ai_model_trainer: true,
          intent: 'DataCollection'
        ),
        BotPattern.new(
          pattern: 'Applebot-Extended\/[0-9]',
          url: 'https://support.apple.com/en-us/119829',
          type: 'applebot-extended',
          category: 'AI Crawler',
          subcategory: 'Model Training Crawlers',
          company: 'Apple',
          is_compliant: true,
          is_ai_model_trainer: true,
          intent: 'DataCollection'
        )
      ]

      # Default AI referrers
      @ai_referrers = [
        AiReferrerInfo.new(
          id: 'chatgpt',
          name: 'ChatGPT',
          company: 'OpenAI',
          url: 'https://chat.openai.com',
          patterns: ['chat.openai.com', 'chatgpt.com'],
          description: 'Traffic from ChatGPT users clicking on links'
        ),
        AiReferrerInfo.new(
          id: 'claude',
          name: 'Claude',
          company: 'Anthropic',
          url: 'https://claude.ai',
          patterns: ['claude.ai'],
          description: 'Traffic from Claude users clicking on links'
        ),
        AiReferrerInfo.new(
          id: 'perplexity',
          name: 'Perplexity',
          company: 'Perplexity AI',
          url: 'https://perplexity.ai',
          patterns: ['perplexity.ai'],
          description: 'Traffic from Perplexity users clicking on links'
        ),
        AiReferrerInfo.new(
          id: 'gemini',
          name: 'Gemini',
          company: 'Google',
          url: 'https://gemini.google.com',
          patterns: ['gemini.google.com', 'bard.google.com'],
          description: 'Traffic from Gemini users clicking on links'
        ),
        AiReferrerInfo.new(
          id: 'copilot',
          name: 'Microsoft Copilot',
          company: 'Microsoft',
          url: 'https://copilot.microsoft.com/',
          patterns: ['copilot.microsoft.com', 'bing.com/chat'],
          description: 'Traffic from Microsoft Copilot users clicking on links'
        )
      ]
    end

    def get_regex_for_pattern(pattern)
      return @pattern_regex_cache[pattern] if @pattern_regex_cache.key?(pattern)

      @pattern_regex_cache[pattern] = Regexp.new(pattern, Regexp::IGNORECASE)
    end

    def should_block_pattern?(pattern_data)
      # Check if pattern is explicitly allowed
      return false if @custom_allows.include?("pattern:#{pattern_data.pattern}")

      category = pattern_data.category || 'Unknown'
      subcategory = pattern_data.subcategory || 'Unclassified'
      type = pattern_data.type || 'unknown'

      # Check if any parent is explicitly allowed
      return false if @custom_allows.include?("category:#{category}") ||
                      @custom_allows.include?("subcategory:#{category}:#{subcategory}") ||
                      @custom_allows.include?("type:#{category}:#{subcategory}:#{type}")

      # Check if pattern is explicitly blocked
      return true if @custom_blocks.include?("pattern:#{pattern_data.pattern}")

      # Check if any parent is explicitly blocked
      return true if @custom_blocks.include?("category:#{category}") ||
                     @custom_blocks.include?("subcategory:#{category}:#{subcategory}") ||
                     @custom_blocks.include?("type:#{category}:#{subcategory}:#{type}")

      # Check for AI model trainers global setting
      return true if @block_ai_model_trainers && pattern_data.is_ai_model_trainer

      # Default to not blocking
      false
    end

    def extract_hostname(referrer)
      uri = URI.parse(referrer)
      uri.hostname&.downcase || referrer.downcase
    rescue URI::InvalidURIError
      referrer.downcase
    end

    def send_collector_request(payload, source_type)
      begin
        uri = URI(@configuration.collect_endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = 10
        http.open_timeout = 5

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['x-api-key'] = @configuration.api_key
        request.body = payload.to_json

        log_debug("Making POST request to #{@configuration.collect_endpoint}")
        log_debug("Payload size: #{request.body.bytesize} bytes")

        response = http.request(request)

        log_debug("Collector response status: #{response.code} #{response.message}")

        if response.is_a?(Net::HTTPSuccess)
          log_debug("✅ Successfully logged #{source_type} event")
        else
          log_debug("❌ Failed to log #{source_type} event")
        end
      rescue => e
        log_debug("❌ Exception during collector request for #{source_type}: #{e.message}")
      end
    end

    def log_debug(message)
      return unless @configuration.debug?
      
      puts "[Spyglasses] #{message}"
    end
  end
end 