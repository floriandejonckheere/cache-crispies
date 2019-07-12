require 'spec_helper'

describe CacheCrispies::Plan do
  class CerealSerializerForPlan < CacheCrispies::Base
    def self.key
      :cereal
    end

    def self.cache_key_addons(options)
      ['addon1', options[:extra_addon]]
    end

    serialize :name
  end

  let(:serializer) { CerealSerializerForPlan }
  let(:serializer_file_path) {
    File.expand_path('fixtures/test_serializer.rb', __dir__)
  }
  let(:model_cache_key) { 'model-cache-key' }
  let(:model) { OpenStruct.new(name: 'Sugar Smacks', cache_key: model_cache_key) }
  let(:cacheable) { model }
  let(:options) { {} }
  let(:instance) { described_class.new(serializer, cacheable, options) }
  subject { instance }

  before do
    allow(Rails).to receive_message_chain(:root, :join).and_return(
      serializer_file_path
    )
  end

  describe '#collection?' do
    context 'when not a collection' do
      let(:cacheable) { Object.new }

      it 'returns false' do
        expect(subject.collection?).to be false
      end
    end

    context 'when a collection' do
      let(:cacheable) { [Object.new] }

      it 'returns false' do
        expect(subject.collection?).to be true
      end
    end
  end

  describe '#etag' do

  end

  describe '#cache_key' do
    let(:options) { { extra_addon: 'addon2' } }

    it 'returns a string' do
      expect(subject.cache_key).to be_a String
    end

    it 'includes the CACHE_KEY_PREFIX' do
      expect(subject.cache_key).to include CacheCrispies::CACHE_KEY_PREFIX
    end

    it "includes the serializer's #cache_key_base" do
      expect(subject.cache_key).to include serializer.cache_key_base
    end

    it "includes the addons_key" do
      expect(subject.cache_key).to include(
        Digest::MD5.hexdigest('addon1|addon2')
      )
    end

    it "includes the cacheable #cache_key" do
      expect(subject.cache_key).to include model_cache_key
    end

    it 'includes the CACHE_KEY_SEPARATOR' do
      expect(subject.cache_key).to include CacheCrispies::CACHE_KEY_SEPARATOR
    end

    it 'generates the key correctly' do
      expect(subject.cache_key).to eq(
        'cache-crispies' \
        "+CerealSerializerForPlan-#{Digest::MD5.file(serializer_file_path)}" \
        "+#{Digest::MD5.hexdigest('addon1|addon2')}" \
        '+model-cache-key'
      )
    end

    context 'without addons' do
      it 'generates the key without that section' do
        expect(serializer).to receive(:cache_key_addons).and_return []

        expect(subject.cache_key).to eq(
          'cache-crispies' \
          "+CerealSerializerForPlan-#{Digest::MD5.file(serializer_file_path)}" \
          '+model-cache-key'
        )
      end
    end
  end

  describe '#cache' do
  end

  describe '#wrap' do
    let(:json_hash) { { name: 'Kix' } }
    subject { instance.wrap(json_hash) }

    context 'when the serializer has no key' do
      before { expect(serializer).to receive(:key).and_return nil }

      it 'returns the json Hash directly' do
        expect(subject).to be json_hash
      end
    end

    context 'when key is false' do
      let(:options) { { key: false } }

      it 'returns json_hash unchanged' do
        expect(subject).to be json_hash
      end
    end

    context 'with an optional key' do
      let(:options) { { key: :cereal_test } }

      it 'wraps the hash using the provided key option' do
        expect(subject).to eq cereal_test: json_hash
      end
    end

    context "when it's a colleciton" do
      let(:cacheable) { [model] }

      it "wraps the hash in the serializer's colleciton_key" do
        expect(subject).to eq cereals: json_hash
      end
    end

    context "when it's not a collection" do
      it "wraps the hash in the serializer's key" do
        expect(subject).to eq cereal: json_hash
      end
    end
  end
end