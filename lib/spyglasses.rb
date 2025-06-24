# frozen_string_literal: true

require_relative 'spyglasses/version'
require_relative 'spyglasses/types'
require_relative 'spyglasses/configuration'
require_relative 'spyglasses/client'
require_relative 'spyglasses/middleware'

module Spyglasses
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  class << self
    # Global configuration
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = nil
    end
  end
end 