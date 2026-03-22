# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Dataset::Runners::Sampling do
  let(:host) do
    obj = Object.new
    obj.extend(described_class)
    obj.extend(Legion::Extensions::Dataset::Runners::Dataset)
    obj.instance_variable_set(:@db, DB)
    obj
  end

  before do
    DB.create_table?(:traces) do
      primary_key :id
      String :span_kind
      String :input, text: true
      String :output, text: true
      String :status
      DateTime :created_at
      String :metadata, text: true
    end
    DB[:traces].delete
  end

  describe '#sample_from_traces' do
    before do
      5.times do |i|
        DB[:traces].insert(span_kind: 'LLM', input: "prompt #{i}", output: "response #{i}",
                           status: 'ok', created_at: Time.now.utc - (i * 60))
      end
      3.times do |i|
        DB[:traces].insert(span_kind: 'TOOL', input: "tool_input #{i}", output: "tool_output #{i}",
                           status: 'error', created_at: Time.now.utc - (i * 60))
      end
    end

    it 'creates a dataset from recent traces' do
      result = host.sample_from_traces(dataset_name: 'sampled', strategy: :recent, sample_size: 3)
      expect(result[:created]).to be true
      expect(result[:row_count]).to eq(3)
    end

    it 'filters by span_kind' do
      result = host.sample_from_traces(dataset_name: 'tools_only',
                                       filters: { span_kind: 'TOOL' }, strategy: :recent)
      expect(result[:row_count]).to eq(3)
    end

    it 'filters by status' do
      result = host.sample_from_traces(dataset_name: 'errors_only',
                                       filters: { status: 'error' }, strategy: :recent)
      expect(result[:row_count]).to eq(3)
    end

    it 'uses random strategy' do
      result = host.sample_from_traces(dataset_name: 'random_sample',
                                       strategy: :random, sample_size: 2)
      expect(result[:row_count]).to eq(2)
    end

    it 'uses error_biased strategy' do
      result = host.sample_from_traces(dataset_name: 'biased',
                                       strategy: :error_biased, sample_size: 4)
      expect(result[:row_count]).to eq(4)
    end

    it 'uses stratified strategy' do
      result = host.sample_from_traces(dataset_name: 'stratified',
                                       strategy: :stratified, sample_size: 4)
      expect(result[:row_count]).to eq(4)
    end

    it 'returns all traces when sample_size is nil' do
      result = host.sample_from_traces(dataset_name: 'all_traces', strategy: :recent)
      expect(result[:row_count]).to eq(8)
    end
  end
end
