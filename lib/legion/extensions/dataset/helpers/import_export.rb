# frozen_string_literal: true

require 'csv'
require 'json'

module Legion
  module Extensions
    module Dataset
      module Helpers
        module ImportExport
          module_function

          def import_csv(path)
            rows = []
            CSV.foreach(path, headers: true, header_converters: :symbol) do |row|
              rows << { input: row[:input], expected_output: row[:expected_output], metadata: row[:metadata] }
            end
            rows
          end

          def import_json(path)
            data = ::JSON.parse(File.read(path), symbolize_names: true)
            data.is_a?(Array) ? data : []
          end

          def import_jsonl(path)
            File.readlines(path).map { |line| ::JSON.parse(line.strip, symbolize_names: true) }
          end

          def export_csv(rows, path)
            CSV.open(path, 'w', headers: %w[input expected_output metadata], write_headers: true) do |csv|
              rows.each { |row| csv << [row[:input], row[:expected_output], row[:metadata]] }
            end
          end

          def export_json(rows, path)
            File.write(path, ::JSON.pretty_generate(rows))
          end

          def export_jsonl(rows, path)
            File.open(path, 'w') do |f|
              rows.each { |row| f.puts(::JSON.generate(row)) }
            end
          end
        end
      end
    end
  end
end
