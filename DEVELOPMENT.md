# Development Guide

This guide provides information for developers working on the Spyglasses Ruby gem.

## Architecture Overview

The gem is structured into several key components:

### Core Components

1. **`Spyglasses::Configuration`** - Handles configuration management and environment variables
2. **`Spyglasses::Client`** - Core detection logic and API communication  
3. **`Spyglasses::Middleware`** - Rack middleware for web framework integration
4. **`Spyglasses::Types`** - Data structures and type definitions

### Key Features

- **Pattern Management**: Loads default patterns and syncs from API
- **Detection Logic**: Bot and AI referrer detection with regex matching
- **Blocking System**: Configurable blocking based on property settings
- **Request Logging**: Non-blocking background logging to collector API
- **Thread Safety**: Mutex-protected pattern updates and caching

## Development Setup

```bash
git clone https://github.com/spyglasses/spyglasses-ruby.git
cd spyglasses-ruby
bin/setup
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage
rake coverage

# Run specific test file
bundle exec rspec spec/spyglasses/client_spec.rb

# Run specific test
bundle exec rspec spec/spyglasses/client_spec.rb:42
```

## Code Quality

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a

# Run all checks
rake check
```

## Building and Testing the Gem

```bash
# Build the gem
rake build

# Install locally for testing
rake install_local

# Test in an app
gem 'spyglasses', path: '/path/to/spyglasses-ruby'
```

## Testing with Real API

To test with the real Spyglasses API:

```bash
export SPYGLASSES_API_KEY=your_real_api_key
export SPYGLASSES_DEBUG=true

# Create a test script
cat > test_api.rb << 'EOF'
require 'spyglasses'

client = Spyglasses::Client.new
result = client.sync_patterns
puts "Sync result: #{result.class}"
puts "Patterns loaded: #{client.patterns.length}"

detection = client.detect('GPTBot/1.0')
puts "Detection result: #{detection.to_h}"
EOF

ruby test_api.rb
```

## Performance Testing

```bash
# Simple benchmark
cat > benchmark.rb << 'EOF'
require 'benchmark'
require 'spyglasses'

client = Spyglasses::Client.new(
  Spyglasses::Configuration.new.tap { |c| c.auto_sync = false }
)

user_agents = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  'GPTBot/1.0',
  'ClaudeBot/1.0',
  'ChatGPT-User/1.0'
]

Benchmark.bm do |x|
  x.report("1000 detections") do
    1000.times do
      user_agents.each { |ua| client.detect(ua) }
    end
  end
end
EOF

ruby benchmark.rb
```

## Release Process

1. Update version in `lib/spyglasses/version.rb`
2. Update `CHANGELOG.md` with changes
3. Ensure all tests pass: `rake check`
4. Build and test the gem: `rake build && rake install_local`
5. Commit changes: `git commit -am "Release v1.x.x"`
6. Tag the release: `git tag v1.x.x`
7. Push: `git push && git push --tags`
8. Publish: `gem push pkg/spyglasses-1.x.x.gem`

## Contributing Guidelines

### Code Style

- Follow Ruby community standards
- Use RuboCop for linting
- Write descriptive commit messages
- Include tests for new functionality

### Testing Requirements

- Maintain >90% test coverage
- Include unit tests for all public methods
- Test error conditions and edge cases
- Use WebMock to stub HTTP requests

### Documentation

- Update README.md for user-facing changes
- Add inline documentation for complex methods
- Include usage examples in docstrings
- Update CHANGELOG.md for all changes

## Debugging

### Enable Debug Mode

```ruby
# In code
Spyglasses.configure do |config|
  config.debug = true
end

# Via environment
export SPYGLASSES_DEBUG=true
```

### Common Issues

1. **Pattern loading fails**: Check API key and network connectivity
2. **Tests fail with real HTTP**: Ensure WebMock stubs are in place
3. **Middleware not detecting**: Check user agent patterns and exclusions
4. **Performance issues**: Profile pattern matching and API calls

### Debugging API Issues

```ruby
# Test API connectivity
require 'net/http'
require 'json'

uri = URI('https://www.spyglasses.io/api/patterns')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Get.new(uri)
request['x-api-key'] = 'your-api-key'

response = http.request(request)
puts "Status: #{response.code}"
puts "Body: #{response.body[0..200]}..."
```

## Compatibility

- **Ruby**: 2.7+ (tested on 2.7, 3.0, 3.1, 3.2, 3.3)
- **Rails**: 6.0+ (all versions with Rack 2.0+)
- **Rack**: 2.0+ 
- **Other frameworks**: Sinatra, Hanami, Roda, etc.

## Security Considerations

- API keys are masked in logs and debug output
- No sensitive data is stored in memory longer than necessary
- HTTP requests use TLS/SSL for API communication
- Input validation prevents regex injection attacks 