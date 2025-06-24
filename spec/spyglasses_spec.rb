# frozen_string_literal: true

RSpec.describe Spyglasses do
  it 'has a version number' do
    expect(Spyglasses::VERSION).not_to be nil
  end

  describe '.configure' do
    it 'yields configuration object' do
      expect { |b| Spyglasses.configure(&b) }.to yield_with_args(Spyglasses::Configuration)
    end

    it 'allows setting configuration options' do
      Spyglasses.configure do |config|
        config.api_key = 'test-key'
        config.debug = true
      end

      expect(Spyglasses.configuration.api_key).to eq('test-key')
      expect(Spyglasses.configuration.debug).to be true
    end
  end

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(Spyglasses.configuration).to be_a(Spyglasses::Configuration)
    end

    it 'returns the same instance on multiple calls' do
      config1 = Spyglasses.configuration
      config2 = Spyglasses.configuration
      expect(config1).to be(config2)
    end
  end

  describe '.reset_configuration!' do
    it 'resets the configuration' do
      Spyglasses.configure { |c| c.api_key = 'test' }
      original_config = Spyglasses.configuration
      
      Spyglasses.reset_configuration!
      new_config = Spyglasses.configuration
      
      expect(new_config).not_to be(original_config)
      expect(new_config.api_key).to be_nil
    end
  end
end 