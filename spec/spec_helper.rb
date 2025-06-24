# frozen_string_literal: true

require 'bundler/setup'
require 'webmock/rspec'
require 'rack/test'

# Configure SimpleCov for coverage reporting
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
  end
end

require 'spyglasses'

# Configure WebMock
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Include Rack::Test methods
  config.include Rack::Test::Methods

  # Reset configuration before each test
  config.before(:each) do
    Spyglasses.reset_configuration!
    # Clear environment variables that might affect tests
    ENV.delete('SPYGLASSES_API_KEY')
    ENV.delete('SPYGLASSES_DEBUG')
    ENV.delete('SPYGLASSES_AUTO_SYNC')
  end

  # Helper methods
  config.include Module.new {
    def stub_patterns_api(response_body = nil, status = 200)
      response_body ||= {
        version: '1.0.0',
        patterns: [
          {
            pattern: 'TestBot\/[0-9]',
            type: 'test-bot',
            category: 'Test',
            subcategory: 'Test Bots',
            company: 'Test Company',
            is_compliant: true,
            is_ai_model_trainer: false,
            intent: 'Testing'
          }
        ],
        ai_referrers: [
          {
            id: 'test-ai',
            name: 'Test AI',
            company: 'Test Company',
            patterns: ['test.ai.com']
          }
        ],
        property_settings: {
          block_ai_model_trainers: false,
          custom_blocks: [],
          custom_allows: []
        }
      }

      stub_request(:get, 'https://www.spyglasses.io/api/patterns')
        .with(headers: { 'x-api-key' => 'test-api-key' })
        .to_return(
          status: status,
          body: response_body.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    def stub_collector_api(status = 200)
      stub_request(:post, 'https://www.spyglasses.io/api/collect')
        .with(headers: { 'x-api-key' => 'test-api-key' })
        .to_return(status: status)
    end

    def create_test_env(path = '/', user_agent = 'TestBot/1.0', referrer = nil)
      env = {
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => path,
        'REQUEST_URI' => path,
        'HTTP_HOST' => 'example.com',
        'SERVER_NAME' => 'example.com',
        'SERVER_PORT' => '80',
        'SCRIPT_NAME' => '',
        'QUERY_STRING' => '',
        'rack.version' => [1, 6],
        'rack.input' => StringIO.new,
        'rack.errors' => StringIO.new,
        'rack.multithread' => false,
        'rack.multiprocess' => true,
        'rack.run_once' => false,
        'rack.url_scheme' => 'http'
      }
      
      env['HTTP_USER_AGENT'] = user_agent if user_agent
      env['HTTP_REFERER'] = referrer if referrer
      
      env
    end

    def test_app
      @test_app ||= lambda do |env|
        [200, { 'Content-Type' => 'text/plain' }, ['OK']]
      end
    end
  }
end 