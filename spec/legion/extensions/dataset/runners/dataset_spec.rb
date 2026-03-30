# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Dataset::Runners::Dataset do
  let(:client) { Legion::Extensions::Dataset::Client.new(db: DB) }

  describe '.remote_invocable?' do
    it 'exists as a singleton method' do
      expect(described_class).to respond_to(:remote_invocable?)
    end

    it 'returns false to force local dispatch' do
      expect(described_class.remote_invocable?).to be false
    end
  end

  describe '#create_dataset' do
    it 'creates a dataset with rows' do
      result = client.create_dataset(
        name: 'test',
        rows: [{ input: 'q1', expected_output: 'a1' }, { input: 'q2', expected_output: 'a2' }]
      )
      expect(result[:created]).to be true
      expect(result[:row_count]).to eq(2)
      expect(result[:version]).to eq(1)
    end
  end

  describe '#get_dataset' do
    before do
      client.create_dataset(name: 'ds', rows: [{ input: 'hello', expected_output: 'world' }])
    end

    it 'returns dataset with rows' do
      result = client.get_dataset(name: 'ds')
      expect(result[:name]).to eq('ds')
      expect(result[:rows].size).to eq(1)
      expect(result[:rows].first[:input]).to eq('hello')
    end

    it 'returns error for missing dataset' do
      result = client.get_dataset(name: 'missing')
      expect(result[:error]).to eq('not_found')
    end
  end

  describe '#list_datasets' do
    it 'returns all datasets' do
      client.create_dataset(name: 'a', rows: [{ input: 'x' }])
      client.create_dataset(name: 'b', rows: [{ input: 'y' }])
      result = client.list_datasets
      expect(result.size).to eq(2)
    end
  end

  describe '#import_dataset and #export_dataset' do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    it 'round-trips via JSON' do
      path = File.join(tmpdir, 'data.json')
      File.write(path, JSON.generate([{ input: 'a', expected_output: 'b' }]))

      client.import_dataset(name: 'imported', path: path, format: 'json')
      result = client.get_dataset(name: 'imported')
      expect(result[:rows].first[:input]).to eq('a')

      export_path = File.join(tmpdir, 'export.json')
      client.export_dataset(name: 'imported', path: export_path)
      expect(File.exist?(export_path)).to be true
    end
  end
end
