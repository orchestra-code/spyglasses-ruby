# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2024-12-29

### Fixed
- **BREAKING**: Fixed API payload format to match TypeScript collector endpoint
  - Changed `platform_type` to `platformType` in JSON payload (camelCase)
  - Ensured `ip_address` and `request_query` are never nil (required strings in API schema)
  - Enhanced IP extraction from forwarded headers with comma-separated values
- Fixed 400 Bad Request errors when logging to collector endpoint
- Improved error handling and data validation for API compatibility

### Changed
- **BREAKING**: JSON payload field names now use camelCase to match API expectations
- Enhanced middleware IP extraction with better fallback handling
- Improved request query string handling to ensure non-nil values

## [1.0.1] - 2024-12-28

### Added
- Comprehensive Ruby documentation in main docs site
- Rails-specific configuration examples
- Deployment platform guidance (Heroku, Railway, etc.)
- Troubleshooting section for common issues

### Fixed
- Documentation formatting and code examples
- Installation instructions for various Ruby frameworks

## [1.0.0] - 2024-12-28

### Added
- Initial release of Spyglasses Ruby gem
- AI bot detection with pattern matching
- AI referrer detection for traffic from AI platforms
- Flexible blocking rules via Spyglasses platform
- Non-blocking request logging to collector API
- Rack middleware for universal Ruby framework support
- Thread-safe operations for concurrent applications
- Default patterns for common AI agents and crawlers
- Configuration via environment variables
- Debug logging support
- Pattern synchronization with API
- Support for Rails, Sinatra, and other Rack-based frameworks

### Features
- **Bot Detection**: GPTBot, ClaudeBot, ChatGPT-User, Claude-User, and more
- **AI Referrer Detection**: ChatGPT, Claude, Perplexity, Gemini, Copilot
- **Blocking Rules**: Configurable via platform dashboard
- **Performance**: Pattern caching, background logging, minimal overhead
- **Framework Support**: Universal Rack middleware design

[Unreleased]: https://github.com/spyglasses/spyglasses-ruby/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/spyglasses/spyglasses-ruby/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/spyglasses/spyglasses-ruby/releases/tag/v1.0.0 