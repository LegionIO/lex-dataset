# frozen_string_literal: true

require 'openssl'
require 'json'

module Legion
  module Extensions
    module Dataset
      module Runners
        module Dataset
          def self.remote_invocable?
            false
          end

          def create_dataset(name:, description: nil, rows: [], **)
            ds_id = db[:datasets].insert(name: name, description: description, created_at: Time.now.utc)
            create_version(ds_id, rows)
            { created: true, name: name, version: 1, row_count: rows.size }
          end

          def import_dataset(name:, path:, format: 'json', description: nil, **)
            rows = case format.to_s
                   when 'csv'   then Helpers::ImportExport.import_csv(path)
                   when 'jsonl' then Helpers::ImportExport.import_jsonl(path)
                   else Helpers::ImportExport.import_json(path)
                   end
            create_dataset(name: name, description: description, rows: rows)
          end

          def export_dataset(name:, path:, format: 'json', version: nil, **)
            rows = get_rows(name, version)
            case format.to_s
            when 'csv'   then Helpers::ImportExport.export_csv(rows, path)
            when 'jsonl' then Helpers::ImportExport.export_jsonl(rows, path)
            else Helpers::ImportExport.export_json(rows, path)
            end
            { exported: true, path: path, row_count: rows.size }
          end

          def list_datasets(**)
            db[:datasets].all.map do |dataset|
              latest = db[:dataset_versions].where(dataset_id: dataset[:id]).order(Sequel.desc(:version)).first
              { name: dataset[:name], description: dataset[:description],
                latest_version: latest ? latest[:version] : nil,
                row_count:      latest ? latest[:row_count] : 0 }
            end
          end

          def get_dataset(name:, version: nil, **)
            ds = db[:datasets].where(name: name).first
            return { error: 'not_found' } unless ds

            ver = if version
                    db[:dataset_versions].where(dataset_id: ds[:id], version: version).first
                  else
                    db[:dataset_versions].where(dataset_id: ds[:id]).order(Sequel.desc(:version)).first
                  end
            return { error: 'version_not_found' } unless ver

            rows = db[:dataset_rows].where(version_id: ver[:id]).order(:row_index).all
            { name: name, version: ver[:version], version_id: ver[:id], row_count: ver[:row_count],
              rows: rows.map { |r| { row_index: r[:row_index], input: r[:input], expected_output: r[:expected_output] } } }
          end

          def generate_dataset(name:, description:, count: 10, schema: nil, model: nil, **)
            return { error: 'legion-llm is not available' } unless llm_available?

            rows = call_llm_for_rows(description: description, count: count, schema: schema, model: model)
            return rows if rows.is_a?(Hash) && rows[:error]

            result = create_dataset(name: name, description: description, rows: rows)
            result.merge(generated: true)
          end

          private

          def llm_available?
            defined?(Legion::LLM) && Legion::LLM.respond_to?(:started?) && Legion::LLM.started?
          end

          def call_llm_for_rows(description:, count:, schema:, model:)
            prompt = build_generate_prompt(description: description, count: count, schema: schema)
            llm_opts = model ? { model: model } : {}

            response = invoke_llm(prompt: prompt, **llm_opts)
            rows = parse_llm_rows(response)

            if rows.nil?
              retry_prompt = "#{prompt}\n\nIMPORTANT: Your previous response was not valid JSON. Return ONLY a valid JSON array."
              response = invoke_llm(prompt: retry_prompt, **llm_opts)
              rows = parse_llm_rows(response)
            end

            rows || { error: 'LLM did not return valid JSON after retry' }
          end

          def invoke_llm(prompt:, **llm_opts)
            result = if Legion::LLM.respond_to?(:structured)
                       Legion::LLM.structured(
                         message: prompt,
                         schema:  generate_schema,
                         caller:  { extension: 'lex-dataset', operation: 'generate' },
                         **llm_opts
                       )
                     else
                       Legion::LLM.chat(message: prompt, caller: { extension: 'lex-dataset', operation: 'generate' }, **llm_opts)
                     end
            content = result.respond_to?(:content) ? result.content : result.to_s
            content.strip.sub(/\A```(?:json)?\n?/, '').sub(/\n?```\z/, '')
          end

          def parse_llm_rows(content)
            parsed = ::JSON.parse(content)
            return nil unless parsed.is_a?(Array)

            parsed.map do |item|
              h = item.transform_keys(&:to_sym)
              { input: h[:input].to_s, expected_output: h[:expected_output]&.to_s }
            end
          rescue ::JSON::ParserError
            nil
          end

          def build_generate_prompt(description:, count:, schema:)
            lines = []
            lines << "You are a test case generator. Generate exactly #{count} test cases as a JSON array."
            lines << 'Each test case must have "input" and "expected_output" fields.'
            lines << ''
            lines << "Description: #{description}"
            if schema
              lines << ''
              lines << 'Schema guidance for inputs and outputs:'
              lines << "\n#{::JSON.generate(schema)}\n"
            end
            lines << ''
            lines << 'Respond ONLY with a valid JSON array, no other text.'
            lines.join("\n")
          end

          def generate_schema
            {
              type:  'array',
              items: {
                type:       'object',
                properties: {
                  input:           { type: 'string' },
                  expected_output: { type: 'string' }
                },
                required:   %w[input expected_output]
              }
            }
          end

          def create_version(dataset_id, rows)
            hash = OpenSSL::Digest.new('SHA256').hexdigest(rows.to_s)
            ver_num = (db[:dataset_versions].where(dataset_id: dataset_id).max(:version) || 0) + 1
            ver_id = db[:dataset_versions].insert(
              dataset_id: dataset_id, version: ver_num, row_count: rows.size,
              content_hash: hash, created_at: Time.now.utc
            )
            rows.each_with_index do |row, idx|
              db[:dataset_rows].insert(
                version_id: ver_id, row_index: idx,
                input:           row[:input].to_s,
                expected_output: row[:expected_output]&.to_s,
                metadata:        row[:metadata]&.to_s
              )
            end
            ver_id
          end

          def get_rows(name, version)
            result = get_dataset(name: name, version: version)
            result[:rows] || []
          end

          def db
            @db
          end
        end
      end
    end
  end
end
