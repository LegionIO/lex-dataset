# frozen_string_literal: true

require_relative 'lib/legion/extensions/dataset/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-dataset'
  spec.version       = Legion::Extensions::Dataset::VERSION
  spec.authors       = ['Matthew Iverson']
  spec.email         = ['matt@iverson.io']

  spec.summary       = 'Versioned dataset management for LegionIO'
  spec.description   = 'Provides versioned dataset storage with import/export (CSV/JSON/JSONL), ' \
                       'experiment runner with evaluator integration, and regression detection.'
  spec.homepage      = 'https://github.com/LegionIO/lex-dataset'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.files         = Dir['lib/**/*', 'LICENSE', 'README.md']
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
end
