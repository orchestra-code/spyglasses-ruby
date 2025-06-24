# frozen_string_literal: true

RSpec.describe Spyglasses::Client do
  let(:config) do
    Spyglasses::Configuration.new.tap do |c|
      c.api_key = 'test-api-key'
      c.auto_sync = false
      c.debug = false
    end
  end

  subject { described_class.new(config) }

  describe '#initialize' do
    it 'loads default patterns' do
      expect(subject.patterns).not_to be_empty
      expect(subject.ai_referrers).not_to be_empty
    end

    it 'does not auto-sync when disabled' do
      expect(subject.last_pattern_sync).to eq(0)
    end
  end

  describe '#sync_patterns' do
    context 'with valid API key' do
      before do
        stub_patterns_api
      end

      it 'fetches patterns from API' do
        result = subject.sync_patterns
        
        expect(result).to be_a(Spyglasses::Types::ApiPatternResponse)
        expect(subject.patterns.length).to eq(1)
        expect(subject.patterns.first.pattern).to eq('TestBot\/[0-9]')
        expect(subject.last_pattern_sync).to be > 0
      end
    end

    context 'without API key' do
      before do
        config.api_key = nil
      end

      it 'returns error message' do
        result = subject.sync_patterns
        expect(result).to be_a(String)
        expect(result).to include('No API key')
      end
    end

    context 'with API error' do
      before do
        stub_patterns_api({}, 500)
      end

      it 'returns error message' do
        result = subject.sync_patterns
        expect(result).to be_a(String)
        expect(result).to include('HTTP error 500')
      end
    end
  end

  describe '#detect_bot' do
    it 'returns negative result for empty user agent' do
      result = subject.detect_bot('')
      expect(result.is_bot).to be false
      expect(result.source_type).to eq('none')
    end

    it 'detects known bot patterns' do
      result = subject.detect_bot('GPTBot/1.0')
      
      expect(result.is_bot).to be true
      expect(result.source_type).to eq('bot')
      expect(result.matched_pattern).to eq('GPTBot\/[0-9]')
      expect(result.info).to be_a(Spyglasses::Types::BotInfo)
      expect(result.info.company).to eq('OpenAI')
    end

    it 'does not detect non-bot user agents' do
      result = subject.detect_bot('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
      
      expect(result.is_bot).to be false
      expect(result.source_type).to eq('none')
    end
  end

  describe '#detect_ai_referrer' do
    it 'returns negative result for empty referrer' do
      result = subject.detect_ai_referrer('')
      expect(result.is_bot).to be false
      expect(result.source_type).to eq('none')
    end

    it 'detects known AI referrers' do
      result = subject.detect_ai_referrer('https://chat.openai.com/')
      
      expect(result.is_bot).to be false
      expect(result.source_type).to eq('ai_referrer')
      expect(result.matched_pattern).to eq('chat.openai.com')
      expect(result.info).to be_a(Spyglasses::Types::AiReferrerInfo)
      expect(result.info.name).to eq('ChatGPT')
    end

    it 'does not detect non-AI referrers' do
      result = subject.detect_ai_referrer('https://google.com/')
      
      expect(result.is_bot).to be false
      expect(result.source_type).to eq('none')
    end
  end

  describe '#detect' do
    it 'prioritizes bot detection over AI referrer' do
      result = subject.detect('GPTBot/1.0', 'https://chat.openai.com/')
      
      expect(result.is_bot).to be true
      expect(result.source_type).to eq('bot')
    end

    it 'detects AI referrer when no bot detected' do
      result = subject.detect('Mozilla/5.0', 'https://chat.openai.com/')
      
      expect(result.is_bot).to be false
      expect(result.source_type).to eq('ai_referrer')
    end

    it 'returns negative result when nothing detected' do
      result = subject.detect('Mozilla/5.0', 'https://google.com/')
      
      expect(result.is_bot).to be false
      expect(result.source_type).to eq('none')
    end
  end

  describe '#log_request' do
    let(:detection_result) do
      Spyglasses::Types::DetectionResult.new(
        is_bot: true,
        should_block: false,
        source_type: 'bot',
        matched_pattern: 'TestBot/1.0'
      )
    end

    let(:request_info) do
      {
        url: 'https://example.com/',
        user_agent: 'TestBot/1.0',
        ip_address: '127.0.0.1',
        request_method: 'GET',
        request_path: '/',
        referrer: '',
        response_status: 200,
        response_time_ms: 100,
        headers: { 'host' => 'example.com' }
      }
    end

    before do
      stub_collector_api
    end

    it 'logs requests with detection results' do
      # Allow some time for the background thread
      subject.log_request(detection_result, request_info)
      sleep 0.1

      expect(WebMock).to have_requested(:post, 'https://www.spyglasses.io/api/collect')
        .with(headers: { 'x-api-key' => 'test-api-key' })
    end

    it 'does not log when no API key' do
      config.api_key = nil
      subject.log_request(detection_result, request_info)
      sleep 0.1

      expect(WebMock).not_to have_requested(:post, 'https://www.spyglasses.io/api/collect')
    end

    it 'does not log when source_type is none' do
      detection_result.source_type = 'none'
      subject.log_request(detection_result, request_info)
      sleep 0.1

      expect(WebMock).not_to have_requested(:post, 'https://www.spyglasses.io/api/collect')
    end
  end
end 