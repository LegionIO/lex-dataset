# frozen_string_literal: true

require_relative 'dataset/version'
require_relative 'dataset/helpers/import_export'
require_relative 'dataset/runners/dataset'
require_relative 'dataset/runners/experiment'
require_relative 'dataset/runners/sampling'
require_relative 'dataset/client'

module Legion
  module Extensions
    module Dataset
      extend Legion::Extensions::Core if defined?(Legion::Extensions::Core)

      def self.remote_invocable?
        false
      end
    end
  end
end
