# frozen_string_literal: true

require 'rspec'
require 'sequel'
require 'json'
require 'tmpdir'
require 'fileutils'

DB = Sequel.sqlite

DB.create_table(:datasets) do
  primary_key :id
  String :name, null: false, unique: true, size: 255
  String :description, text: true
  DateTime :created_at
end

DB.create_table(:dataset_versions) do
  primary_key :id
  foreign_key :dataset_id, :datasets, null: false
  Integer :version, null: false
  Integer :row_count, default: 0
  String :content_hash, size: 64
  DateTime :created_at
end

DB.create_table(:dataset_rows) do
  primary_key :id
  foreign_key :version_id, :dataset_versions, null: false
  Integer :row_index, null: false
  String :input, text: true, null: false
  String :expected_output, text: true
  String :metadata, text: true
end

DB.create_table(:experiments) do
  primary_key :id
  String :name, null: false, size: 255
  foreign_key :dataset_version_id, :dataset_versions, null: false
  String :eval_config, text: true
  String :status, default: 'pending', size: 20
  String :summary, text: true
  DateTime :created_at
  DateTime :completed_at
end

DB.create_table(:experiment_results) do
  primary_key :id
  foreign_key :experiment_id, :experiments, null: false
  Integer :row_index, null: false
  String :output, text: true
  String :eval_scores, text: true
  Integer :latency_ms
  TrueClass :passed
end

module Legion
  module Extensions
    module Helpers
      module Lex; end
    end

    module Core; end
  end

  module Logging
    def self.debug(*); end
    def self.info(*); end
    def self.warn(*); end
    def self.error(*); end
  end
end

require 'legion/extensions/dataset'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:each) do
    DB[:experiment_results].delete
    DB[:experiments].delete
    DB[:dataset_rows].delete
    DB[:dataset_versions].delete
    DB[:datasets].delete
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed
end
