# frozen_string_literal: true

RSpec.describe Spyglasses::Configuration do
  subject { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(subject.collect_endpoint).to eq('https://www.spyglasses.io/api/collect')
      expect(subject.patterns_endpoint).to eq('https://www.spyglasses.io/api/patterns')
      expect(subject.platform_type).to eq('ruby')
      expect(subject.debug).to be false
      expect(subject.auto_sync).to be true
      expect(subject.cache_ttl).to eq(24 * 60 * 60)
      expect(subject.exclude_paths).to eq([])
    end

    it 'loads values from environment variables' do
      ENV['SPYGLASSES_API_KEY'] = 'env-api-key'
      ENV['SPYGLASSES_DEBUG'] = 'true'
      ENV['SPYGLASSES_AUTO_SYNC'] = 'false'
      ENV['SPYGLASSES_CACHE_TTL'] = '3600'

      config = described_class.new

      expect(config.api_key).to eq('env-api-key')
      expect(config.debug).to be true
      expect(config.auto_sync).to be false
      expect(config.cache_ttl).to eq(3600)
    end
  end

  describe '#api_key_present?' do
    it 'returns false when api_key is nil' do
      subject.api_key = nil
      expect(subject.api_key_present?).to be false
    end

    it 'returns false when api_key is empty' do
      subject.api_key = ''
      expect(subject.api_key_present?).to be false
    end

    it 'returns true when api_key is present' do
      subject.api_key = 'test-key'
      expect(subject.api_key_present?).to be true
    end
  end

  describe '#debug?' do
    it 'returns debug value' do
      subject.debug = true
      expect(subject.debug?).to be true

      subject.debug = false
      expect(subject.debug?).to be false
    end
  end

  describe '#auto_sync?' do
    it 'returns auto_sync value' do
      subject.auto_sync = true
      expect(subject.auto_sync?).to be true

      subject.auto_sync = false
      expect(subject.auto_sync?).to be false
    end
  end

  describe '#validate!' do
    it 'raises error when api_key is missing' do
      subject.api_key = nil
      expect { subject.validate! }.to raise_error(Spyglasses::ConfigurationError, /API key is required/)
    end

    it 'raises error when collect_endpoint is invalid' do
      subject.api_key = 'test-key'
      subject.collect_endpoint = 'invalid-url'
      expect { subject.validate! }.to raise_error(Spyglasses::ConfigurationError, /Invalid collect endpoint/)
    end

    it 'raises error when patterns_endpoint is invalid' do
      subject.api_key = 'test-key'
      subject.patterns_endpoint = 'invalid-url'
      expect { subject.validate! }.to raise_error(Spyglasses::ConfigurationError, /Invalid patterns endpoint/)
    end

    it 'raises error when cache_ttl is negative' do
      subject.api_key = 'test-key'
      subject.cache_ttl = -1
      expect { subject.validate! }.to raise_error(Spyglasses::ConfigurationError, /Cache TTL must be non-negative/)
    end

    it 'passes when all values are valid' do
      subject.api_key = 'test-key'
      expect { subject.validate! }.not_to raise_error
    end
  end

  describe '#to_h' do
    it 'returns configuration as hash with masked api_key' do
      subject.api_key = 'test-api-key-123'
      subject.debug = true

      result = subject.to_h

      expect(result[:api_key]).to eq('test-api...')
      expect(result[:debug]).to be true
      expect(result[:platform_type]).to eq('ruby')
    end

    it 'handles nil api_key' do
      subject.api_key = nil
      result = subject.to_h
      expect(result[:api_key]).to be_nil
    end
  end
end 