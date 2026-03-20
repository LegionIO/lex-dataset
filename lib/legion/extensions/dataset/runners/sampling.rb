# frozen_string_literal: true

module Legion
  module Extensions
    module Dataset
      module Runners
        module Sampling
          def sample_from_traces(dataset_name:, source: :legion_data, filters: {},
                                 sample_size: nil, strategy: :recent, **)
            traces = fetch_traces(source, filters)
            sampled = apply_strategy(traces, strategy, sample_size)
            rows = sampled.map { |t| { input: t[:input], expected_output: nil, metadata: t[:span_kind] } }
            create_dataset(name: dataset_name, rows: rows)
          end

          private

          def fetch_traces(source, filters)
            case source
            when :legion_data then fetch_from_db(filters)
            else raise ArgumentError, "unknown trace source: #{source}"
            end
          end

          def fetch_from_db(filters)
            query = db[:traces]
            query = query.where(span_kind: filters[:span_kind]) if filters[:span_kind]
            query = query.where(status: filters[:status]) if filters[:status]
            if filters[:time_range]
              cutoff = Time.now.utc - filters[:time_range]
              query = query.where { created_at >= cutoff }
            end
            query.order(Sequel.desc(:created_at)).all
          end

          def apply_strategy(traces, strategy, sample_size)
            case strategy.to_sym
            when :random       then sample_random(traces, sample_size)
            when :error_biased then sample_error_biased(traces, sample_size)
            when :stratified   then sample_stratified(traces, sample_size)
            else sample_recent(traces, sample_size)
            end
          end

          def sample_recent(traces, size)
            size ? traces.first(size) : traces
          end

          def sample_random(traces, size)
            size ? traces.sample(size) : traces.shuffle
          end

          def sample_error_biased(traces, size)
            errors, successes = traces.partition { |t| t[:status] == 'error' }
            return traces unless size

            half = size / 2
            (errors.first(half) + successes.first(size - half)).first(size)
          end

          def sample_stratified(traces, size)
            groups = traces.group_by { |t| t[:span_kind] }
            return traces unless size

            per_group = [size / [groups.size, 1].max, 1].max
            groups.values.flat_map { |g| g.first(per_group) }.first(size)
          end
        end
      end
    end
  end
end
