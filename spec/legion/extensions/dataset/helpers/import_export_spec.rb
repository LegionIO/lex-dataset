# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Dataset::Helpers::ImportExport do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(tmpdir) }

  describe '.import_json and .export_json' do
    it 'round-trips data' do
      rows = [{ input: 'hello', expected_output: 'world' }]
      path = File.join(tmpdir, 'test.json')
      described_class.export_json(rows, path)
      imported = described_class.import_json(path)
      expect(imported.first[:input]).to eq('hello')
    end
  end

  describe '.import_jsonl and .export_jsonl' do
    it 'round-trips data' do
      rows = [{ input: 'a' }, { input: 'b' }]
      path = File.join(tmpdir, 'test.jsonl')
      described_class.export_jsonl(rows, path)
      imported = described_class.import_jsonl(path)
      expect(imported.size).to eq(2)
      expect(imported.first[:input]).to eq('a')
    end
  end

  describe '.import_csv and .export_csv' do
    it 'round-trips data' do
      rows = [{ input: 'x', expected_output: 'y', metadata: nil }]
      path = File.join(tmpdir, 'test.csv')
      described_class.export_csv(rows, path)
      imported = described_class.import_csv(path)
      expect(imported.first[:input]).to eq('x')
      expect(imported.first[:expected_output]).to eq('y')
    end
  end
end
