# Spyglasses Ruby Gem

[![Gem Version](https://badge.fury.io/rb/spyglasses.svg)](https://badge.fury.io/rb/spyglasses)
[![Ruby](https://github.com/spyglasses/spyglasses-ruby/actions/workflows/ruby.yml/badge.svg)](https://github.com/spyglasses/spyglasses-ruby/actions/workflows/ruby.yml)

AI Agent Detection and Management for Ruby web applications. Spyglasses provides comprehensive AI agent detection and management capabilities for Ruby web applications, including Rails, Sinatra, and other Rack-based frameworks.

## Features

- 🤖 **AI Bot Detection**: Automatically detect AI agents like GPTBot, ClaudeBot, ChatGPT-User, and more
- 🧠 **AI Referrer Detection**: Track traffic from AI platforms like ChatGPT, Claude, Perplexity
- 🚫 **Flexible Blocking**: Configure blocking rules via the Spyglasses platform
- 📊 **Request Logging**: Non-blocking request logging to Spyglasses collector
- ⚡ **High Performance**: Minimal overhead with pattern caching and background processing
- 🔧 **Easy Integration**: Drop-in Rack middleware for any Ruby web framework
- 🛡️ **Thread Safe**: Built for concurrent Ruby applications

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'spyglasses'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install spyglasses
```

## Quick Start

### 1. Get Your API Key

Sign up at [spyglasses.io](https://spyglasses.io) to get your API key.

### 2. Set Environment Variable

```bash
export SPYGLASSES_API_KEY=your_api_key_here
```

### 3. Add Middleware

#### Rails

Add to your `config/application.rb`:

```ruby
# config/application.rb
class Application < Rails::Application
  config.middleware.use Spyglasses::Middleware
end
```

Or with options:

```ruby
# config/application.rb
class Application < Rails::Application
  config.middleware.use Spyglasses::Middleware, {
    api_key: ENV['SPYGLASSES_API_KEY'],
    debug: Rails.env.development?,
    exclude_paths: ['/admin', '/internal']
  }
end
```

#### Sinatra

```ruby
require 'sinatra'
require 'spyglasses'

use Spyglasses::Middleware, api_key: ENV['SPYGLASSES_API_KEY']

get '/' do
  'Hello World!'
end
```

#### Rack Application

```ruby
# config.ru
require 'spyglasses'

use Spyglasses::Middleware, api_key: ENV['SPYGLASSES_API_KEY']

app = lambda do |env|
  [200, {'Content-Type' => 'text/plain'}, ['Hello World!']]
end

run app
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SPYGLASSES_API_KEY` | Your Spyglasses API key | Required |
| `SPYGLASSES_DEBUG` | Enable debug logging | `false` |
| `SPYGLASSES_AUTO_SYNC` | Auto-sync patterns on startup | `true` |
| `SPYGLASSES_CACHE_TTL` | Pattern cache TTL in seconds | `86400` (24 hours) |
| `SPYGLASSES_COLLECT_ENDPOINT` | Custom collector endpoint | `https://www.spyglasses.io/api/collect` |
| `SPYGLASSES_PATTERNS_ENDPOINT` | Custom patterns endpoint | `https://www.spyglasses.io/api/patterns` |

### Middleware Options

```ruby
use Spyglasses::Middleware, {
  api_key: 'your-api-key',           # API key (overrides env var)
  debug: true,                       # Enable debug logging
  auto_sync: true,                   # Auto-sync patterns
  platform_type: 'rails',           # Platform identifier
  exclude_paths: [                   # Paths to exclude from monitoring
    '/admin',
    '/api/internal',
    /\.json$/                        # Regex patterns supported
  ],
  collect_endpoint: 'https://...',   # Custom collector endpoint
  patterns_endpoint: 'https://...'   # Custom patterns endpoint
}
```

### Global Configuration

```ruby
# config/initializers/spyglasses.rb (Rails)
Spyglasses.configure do |config|
  config.api_key = ENV['SPYGLASSES_API_KEY']
  config.debug = Rails.env.development?
  config.platform_type = 'rails'
  config.exclude_paths = ['/admin', '/internal']
end
```

## Usage Examples

### Manual Detection

```ruby
require 'spyglasses'

# Configure the client
client = Spyglasses::Client.new(
  Spyglasses::Configuration.new.tap do |config|
    config.api_key = 'your-api-key'
  end
)

# Detect bots
result = client.detect_bot('GPTBot/1.0')
puts "Bot detected: #{result.is_bot}" # => true
puts "Should block: #{result.should_block}" # => depends on your settings

# Detect AI referrers
result = client.detect_ai_referrer('https://chat.openai.com/')
puts "AI referrer: #{result.source_type}" # => 'ai_referrer'

# Combined detection
result = client.detect('Mozilla/5.0', 'https://chat.openai.com/')
puts "Source type: #{result.source_type}" # => 'ai_referrer'
```

### Custom Rack Middleware

```ruby
class MyCustomMiddleware
  def initialize(app)
    @app = app
    @spyglasses = Spyglasses::Client.new
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Detect using Spyglasses
    result = @spyglasses.detect(request.user_agent, request.referrer)
    
    if result.is_bot && result.should_block
      return [403, {}, ['Forbidden']]
    end
    
    # Log the request if something was detected
    if result.source_type != 'none'
      @spyglasses.log_request(result, {
        url: request.url,
        user_agent: request.user_agent,
        # ... other request info
      })
    end
    
    @app.call(env)
  end
end
```

## Blocking Configuration

Blocking rules are configured through the [Spyglasses platform](https://spyglasses.io) dashboard, not in code:

1. **Global AI Model Trainer Blocking**: Block all AI training bots (GPTBot, ClaudeBot, etc.)
2. **Custom Block Rules**: Block specific categories, subcategories, or individual patterns
3. **Custom Allow Rules**: Create exceptions for specific bots

The middleware automatically loads and applies these settings.

## Default Patterns

The gem includes default patterns for common AI agents:

### AI Assistants (Usually Allowed)
- ChatGPT-User/* - OpenAI ChatGPT user requests
- Claude-User/* - Anthropic Claude user requests  
- Perplexity-User/* - Perplexity AI user requests
- Gemini-User/* - Google Gemini user requests

### AI Model Training Crawlers (Can be Blocked)
- GPTBot/* - OpenAI training crawler
- ClaudeBot/* - Anthropic training crawler
- CCBot/* - Common Crawl bot
- meta-externalagent/* - Meta training crawler
- Applebot-Extended/* - Apple training crawler

### AI Referrers
- chat.openai.com, chatgpt.com - ChatGPT
- claude.ai - Claude
- perplexity.ai - Perplexity
- gemini.google.com - Gemini
- copilot.microsoft.com - Microsoft Copilot

## Framework Integration

### Rails Integration

For Rails applications, you can also create an initializer:

```ruby
# config/initializers/spyglasses.rb
Spyglasses.configure do |config|
  config.api_key = Rails.application.credentials.spyglasses_api_key
  config.debug = Rails.env.development?
  config.platform_type = 'rails'
  config.exclude_paths = [
    '/rails/active_storage',
    '/admin',
    /^\/api\/internal/
  ]
end

# Add middleware
Rails.application.config.middleware.use Spyglasses::Middleware
```

### Sinatra Integration

```ruby
# app.rb
require 'sinatra'
require 'spyglasses'

configure do
  Spyglasses.configure do |config|
    config.api_key = ENV['SPYGLASSES_API_KEY']
    config.platform_type = 'sinatra'
  end
  
  use Spyglasses::Middleware
end
```

## Testing

Add to your test helper:

```ruby
# spec/spec_helper.rb or test/test_helper.rb
require 'spyglasses'

# Disable API calls in tests
Spyglasses.configure do |config|
  config.api_key = nil
  config.auto_sync = false
end
```

Run the test suite:

```bash
$ bundle exec rspec
```

## Development

After checking out the repo, run:

```bash
$ bin/setup      # Install dependencies
$ rake spec      # Run tests  
$ rake console   # Interactive console
$ rake check     # Run all checks (tests + linting)
```

## Performance

The Spyglasses middleware is designed for high-performance applications:

- **Pattern Caching**: Regex patterns are compiled and cached
- **Background Logging**: API calls are made in background threads
- **Minimal Overhead**: Typical overhead is <1ms per request
- **Smart Exclusions**: Static assets and health checks are automatically excluded

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/spyglasses/spyglasses-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Support

- 📧 Email: support@spyglasses.io
- 📖 Documentation: https://www.spyglasses.io/docs/platforms/ruby
- 🐛 Issues: https://github.com/spyglasses/spyglasses-ruby/issues
