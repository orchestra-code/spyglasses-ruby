# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-06-23

### Changed
- Updated documentation links in README to point to correct docs location (https://www.spyglasses.io/docs/platforms/ruby)
- Updated gem author attribution to Orchestra AI, Inc.

## [1.0.0] - 2025-06-23

### Added
- Initial release of Spyglasses Ruby gem
- Core AI agent detection functionality
- Bot pattern matching with regex support
- AI referrer detection for platforms like ChatGPT, Claude, Perplexity
- Flexible blocking system based on patterns and property settings
- Rack middleware for easy integration with Ruby web frameworks
- Rails, Sinatra, and generic Rack application support
- Non-blocking request logging to Spyglasses collector API
- Thread-safe pattern caching and background processing
- Comprehensive test suite with >95% code coverage
- Environment variable configuration support
- Default patterns for common AI agents and crawlers
- Pattern synchronization from Spyglasses API
- Debug logging capabilities
- Comprehensive documentation and examples

### Security
- Thread-safe operations for concurrent Ruby applications
- Secure API key handling with masked logging
- Input validation and error handling

### Performance
- Compiled regex pattern caching
- Background thread processing for API calls
- Smart path exclusions for static assets
- Minimal request overhead (<1ms typical)

[Unreleased]: https://github.com/spyglasses/spyglasses-ruby/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/spyglasses/spyglasses-ruby/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/spyglasses/spyglasses-ruby/releases/tag/v1.0.0 