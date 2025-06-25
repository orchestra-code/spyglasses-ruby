# frozen_string_literal: true

module Spyglasses
  module Types
    # Base detection result
    class DetectionResult
      attr_accessor :is_bot, :should_block, :source_type, :matched_pattern, :info

      def initialize(is_bot: false, should_block: false, source_type: 'none', matched_pattern: nil, info: nil)
        @is_bot = is_bot
        @should_block = should_block
        @source_type = source_type
        @matched_pattern = matched_pattern
        @info = info
      end

      def to_h
        {
          is_bot: @is_bot,
          should_block: @should_block,
          source_type: @source_type,
          matched_pattern: @matched_pattern,
          info: @info&.to_h
        }
      end
    end

    # Bot pattern from API
    class BotPattern
      attr_accessor :pattern, :url, :type, :category, :subcategory, :company, 
                    :is_compliant, :is_ai_model_trainer, :intent, :instances

      def initialize(data = {})
        @pattern = data['pattern'] || data[:pattern]
        @url = data['url'] || data[:url]
        @type = data['type'] || data[:type]
        @category = data['category'] || data[:category]
        @subcategory = data['subcategory'] || data[:subcategory]
        @company = data['company'] || data[:company]
        @is_compliant = data['is_compliant'] || data[:is_compliant] || data['isCompliant']
        @is_ai_model_trainer = data['is_ai_model_trainer'] || data[:is_ai_model_trainer] || data['isAiModelTrainer']
        @intent = data['intent'] || data[:intent]
        @instances = data['instances'] || data[:instances] || []
      end

      def to_h
        {
          pattern: @pattern,
          url: @url,
          type: @type,
          category: @category,
          subcategory: @subcategory,
          company: @company,
          is_compliant: @is_compliant,
          is_ai_model_trainer: @is_ai_model_trainer,
          intent: @intent,
          instances: @instances
        }
      end
    end

    # Bot info for detection results
    class BotInfo
      attr_accessor :pattern, :type, :category, :subcategory, :company, 
                    :is_compliant, :is_ai_model_trainer, :intent, :url

      def initialize(data = {})
        @pattern = data['pattern'] || data[:pattern]
        @type = data['type'] || data[:type]
        @category = data['category'] || data[:category]
        @subcategory = data['subcategory'] || data[:subcategory]
        @company = data['company'] || data[:company]
        @is_compliant = data['is_compliant'] || data[:is_compliant] || false
        @is_ai_model_trainer = data['is_ai_model_trainer'] || data[:is_ai_model_trainer] || false
        @intent = data['intent'] || data[:intent]
        @url = data['url'] || data[:url]
      end

      def to_h
        {
          pattern: @pattern,
          type: @type,
          category: @category,
          subcategory: @subcategory,
          company: @company,
          is_compliant: @is_compliant,
          is_ai_model_trainer: @is_ai_model_trainer,
          intent: @intent,
          url: @url
        }
      end
    end

    # AI referrer info
    class AiReferrerInfo
      attr_accessor :id, :name, :company, :url, :patterns, :description, :logo_url

      def initialize(data = {})
        @id = data['id'] || data[:id]
        @name = data['name'] || data[:name]
        @company = data['company'] || data[:company]
        @url = data['url'] || data[:url]
        @patterns = data['patterns'] || data[:patterns] || []
        @description = data['description'] || data[:description]
        @logo_url = data['logo_url'] || data[:logo_url] || data['logoUrl']
      end

      def to_h
        {
          id: @id,
          name: @name,
          company: @company,
          url: @url,
          patterns: @patterns,
          description: @description,
          logo_url: @logo_url
        }
      end
    end

    # API pattern response
    class ApiPatternResponse
      attr_accessor :version, :patterns, :ai_referrers, :property_settings

      def initialize(data = {})
        @version = data['version'] || data[:version]
        @patterns = (data['patterns'] || data[:patterns] || []).map { |p| BotPattern.new(p) }
        @ai_referrers = (data['ai_referrers'] || data[:ai_referrers] || data['aiReferrers'] || []).map { |r| AiReferrerInfo.new(r) }
        
        settings_data = data['property_settings'] || data[:property_settings] || data['propertySettings'] || {}
        @property_settings = PropertySettings.new(settings_data)
      end

      def to_h
        {
          version: @version,
          patterns: @patterns.map(&:to_h),
          ai_referrers: @ai_referrers.map(&:to_h),
          property_settings: @property_settings.to_h
        }
      end
    end

    # Property settings from API
    class PropertySettings
      attr_accessor :block_ai_model_trainers, :custom_blocks, :custom_allows

      def initialize(data = {})
        @block_ai_model_trainers = data['block_ai_model_trainers'] || data[:block_ai_model_trainers] || data['blockAiModelTrainers'] || false
        @custom_blocks = data['custom_blocks'] || data[:custom_blocks] || data['customBlocks'] || []
        @custom_allows = data['custom_allows'] || data[:custom_allows] || data['customAllows'] || []
      end

      def to_h
        {
          block_ai_model_trainers: @block_ai_model_trainers,
          custom_blocks: @custom_blocks,
          custom_allows: @custom_allows
        }
      end
    end

    # Collector payload
    class CollectorPayload
      attr_accessor :url, :user_agent, :ip_address, :request_method, :request_path, 
                    :request_query, :request_body, :referrer, :response_status, 
                    :response_time_ms, :headers, :timestamp, :platform_type, :metadata

      def initialize(data = {})
        @url = data[:url]
        @user_agent = data[:user_agent]
        @ip_address = data[:ip_address]
        @request_method = data[:request_method]
        @request_path = data[:request_path]
        @request_query = data[:request_query]
        @request_body = data[:request_body]
        @referrer = data[:referrer]
        @response_status = data[:response_status]
        @response_time_ms = data[:response_time_ms]
        @headers = data[:headers] || {}
        @timestamp = data[:timestamp] || Time.now.utc.iso8601
        @platform_type = data[:platform_type]
        @metadata = data[:metadata] || {}
      end

      def to_h
        {
          url: @url,
          user_agent: @user_agent,
          ip_address: @ip_address || '',
          request_method: @request_method,
          request_path: @request_path,
          request_query: @request_query || '',
          request_body: @request_body,
          referrer: @referrer,
          response_status: @response_status,
          response_time_ms: @response_time_ms,
          headers: @headers,
          timestamp: @timestamp,
          platformType: @platform_type,
          metadata: @metadata
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end
  end
end 