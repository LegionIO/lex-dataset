# frozen_string_literal: true

require 'json'

module Legion
  module Extensions
    module Dataset
      module Runners
        module Experiment
          def run_experiment(name:, dataset_name:, task_callable:, dataset_version: nil, evaluators: [], **)
            ds = get_dataset(name: dataset_name, version: dataset_version)
            return { error: ds[:error] } if ds[:error]

            exp_id = db[:experiments].insert(
              name: name, dataset_version_id: ds[:version_id],
              eval_config: ::JSON.dump(evaluators.map { |e| e.respond_to?(:name) ? e.name : e.to_s }),
              status: 'running', created_at: Time.now.utc
            )

            results = ds[:rows].map do |row|
              start_time = Time.now
              output = task_callable.call(row[:input])
              latency = ((Time.now - start_time) * 1000).round

              scores = evaluators.map do |evaluator|
                evaluator.evaluate(input: row[:input], output: output, expected: row[:expected_output])
              end

              passed = scores.empty? || scores.all? { |s| s[:passed] }
              db[:experiment_results].insert(
                experiment_id: exp_id, row_index: row[:row_index],
                output: output.to_s, eval_scores: ::JSON.dump(scores),
                latency_ms: latency, passed: passed
              )
              { row_index: row[:row_index], passed: passed, latency_ms: latency }
            end

            summary = build_summary(results)
            db[:experiments].where(id: exp_id).update(
              status: 'completed', summary: ::JSON.dump(summary), completed_at: Time.now.utc
            )
            { experiment_id: exp_id, name: name, summary: summary }
          end

          def compare_experiments(exp1_name:, exp2_name:, **)
            r1 = load_experiment_results(exp1_name)
            r2 = load_experiment_results(exp2_name)
            return { error: 'experiments_not_found' } unless r1 && r2

            pairs = r1.zip(r2).select { |a, b| a && b }
            regressions = pairs.select { |a, b| a[:passed] && !b[:passed] }.map { |a, _| a[:row_index] }
            improvements = pairs.select { |a, b| !a[:passed] && b[:passed] }.map { |_, b| b[:row_index] }

            { exp1: exp1_name, exp2: exp2_name, rows_compared: pairs.size,
              regressions: regressions, improvements: improvements,
              regression_count: regressions.size, improvement_count: improvements.size }
          end

          private

          def build_summary(results)
            {
              total:          results.size,
              passed:         results.count { |r| r[:passed] },
              failed:         results.count { |r| !r[:passed] },
              avg_latency_ms: results.empty? ? 0 : (results.sum { |r| r[:latency_ms] } / results.size).round
            }
          end

          def load_experiment_results(name)
            exp = db[:experiments].where(name: name).first
            return nil unless exp

            db[:experiment_results].where(experiment_id: exp[:id]).order(:row_index).all
          end
        end
      end
    end
  end
end
