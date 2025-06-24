# frozen_string_literal: true

RSpec.describe Spyglasses::Middleware do
  let(:app) { test_app }
  let(:options) { { api_key: 'test-api-key', debug: false, auto_sync: false } }
  let(:middleware) { described_class.new(app, options) }

  describe '#initialize' do
    it 'sets up configuration and client' do
      expect(middleware).to be_a(described_class)
    end
  end

  describe '#call' do
    before do
      stub_collector_api
    end

    context 'with excluded paths' do
      [
        '/favicon.ico',
        '/assets/application.js',
        '/rails/active_storage',
        '/health',
        '/status.png'
      ].each do |path|
        it "excludes #{path}" do
          env = create_test_env(path, 'GPTBot/1.0')
          status, headers, body = middleware.call(env)

          expect(status).to eq(200)
          expect(body).to eq(['OK'])
        end
      end
    end

    context 'with regular requests' do
      it 'processes requests normally when no bot detected' do
        env = create_test_env('/', 'Mozilla/5.0')
        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(body).to eq(['OK'])
      end

      it 'logs bot requests but allows them through' do
        env = create_test_env('/', 'ChatGPT-User/1.0')
        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(body).to eq(['OK'])
        
        # Allow time for background logging
        sleep 0.1
        expect(WebMock).to have_requested(:post, 'https://www.spyglasses.io/api/collect')
      end

      it 'logs AI referrer requests' do
        env = create_test_env('/', 'Mozilla/5.0', 'https://chat.openai.com/')
        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(body).to eq(['OK'])
        
        # Allow time for background logging
        sleep 0.1
        expect(WebMock).to have_requested(:post, 'https://www.spyglasses.io/api/collect')
      end
    end

    context 'with blocking enabled' do
      before do
        # Stub API to return patterns with blocking enabled
        stub_patterns_api({
          version: '1.0.0',
          patterns: [
            {
              pattern: 'BlockedBot\/[0-9]',
              type: 'blocked-bot',
              category: 'Test',
              subcategory: 'Blocked Bots',
              company: 'Test Company',
              is_compliant: true,
              is_ai_model_trainer: true,
              intent: 'Testing'
            }
          ],
          ai_referrers: [],
          property_settings: {
            block_ai_model_trainers: true,
            custom_blocks: [],
            custom_allows: []
          }
        })

        # Initialize new middleware to pick up the stubbed response
        client = Spyglasses::Client.new(Spyglasses::Configuration.new.tap { |c| c.api_key = 'test-api-key' })
        client.sync_patterns
        allow(Spyglasses::Client).to receive(:new).and_return(client)
      end

      it 'blocks requests from blocked bots' do
        env = create_test_env('/', 'BlockedBot/1.0')
        middleware_with_blocking = described_class.new(app, options)
        status, headers, body = middleware_with_blocking.call(env)

        expect(status).to eq(403)
        expect(headers['Content-Type']).to eq('text/plain')
        expect(body).to eq(['Access Denied'])
        
        # Allow time for background logging
        sleep 0.1
        expect(WebMock).to have_requested(:post, 'https://www.spyglasses.io/api/collect')
      end
    end

    context 'with application errors' do
      let(:error_app) do
        lambda do |env|
          raise StandardError, 'Test error'
        end
      end
      
      let(:error_middleware) { described_class.new(error_app, options) }

      it 'logs detected requests even when app raises error' do
        env = create_test_env('/', 'ChatGPT-User/1.0')
        
        expect { error_middleware.call(env) }.to raise_error(StandardError, 'Test error')
        
        # Allow time for background logging
        sleep 0.1
        expect(WebMock).to have_requested(:post, 'https://www.spyglasses.io/api/collect')
      end
    end

    context 'without API key' do
      let(:options) { { api_key: nil } }

      it 'processes requests but does not log' do
        env = create_test_env('/', 'GPTBot/1.0')
        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(body).to eq(['OK'])
        
        sleep 0.1
        expect(WebMock).not_to have_requested(:post, 'https://www.spyglasses.io/api/collect')
      end
    end
  end

  describe 'configuration options' do
    it 'accepts custom exclude paths' do
      options[:exclude_paths] = ['/custom-exclude']
      middleware = described_class.new(app, options)
      
      env = create_test_env('/custom-exclude', 'GPTBot/1.0')
      status, headers, body = middleware.call(env)

      expect(status).to eq(200)
      expect(body).to eq(['OK'])
    end

    it 'accepts debug option' do
      options[:debug] = true
      expect { described_class.new(app, options) }.not_to raise_error
    end

    it 'accepts custom endpoints' do
      options[:patterns_endpoint] = 'https://custom.example.com/patterns'
      options[:collect_endpoint] = 'https://custom.example.com/collect'
      expect { described_class.new(app, options) }.not_to raise_error
    end
  end
end 