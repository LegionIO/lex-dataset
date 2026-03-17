# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Dataset::Runners::Experiment do
  let(:client) { Legion::Extensions::Dataset::Client.new(db: DB) }

  before do
    client.create_dataset(
      name: 'test_ds',
      rows: [
        { input: 'hello', expected_output: 'HELLO' },
        { input: 'world', expected_output: 'WORLD' }
      ]
    )
  end

  describe '#run_experiment' do
    it 'runs callable against dataset rows' do
      result = client.run_experiment(
        name:          'exp1',
        dataset_name:  'test_ds',
        task_callable: lambda(&:upcase)
      )
      expect(result[:summary][:total]).to eq(2)
      expect(result[:summary][:passed]).to eq(2)
    end

    it 'integrates evaluators' do
      evaluator = double('evaluator', name: 'mock_eval')
      allow(evaluator).to receive(:evaluate).and_return({ passed: true, score: 1.0 })

      result = client.run_experiment(
        name:          'exp_eval',
        dataset_name:  'test_ds',
        task_callable: lambda(&:upcase),
        evaluators:    [evaluator]
      )
      expect(result[:summary][:passed]).to eq(2)
    end

    it 'returns error for missing dataset' do
      result = client.run_experiment(
        name:          'bad',
        dataset_name:  'missing',
        task_callable: ->(_) { 'x' }
      )
      expect(result[:error]).to eq('not_found')
    end
  end

  describe '#compare_experiments' do
    it 'detects regressions and improvements' do
      pass_eval = double('pass', name: 'p')
      allow(pass_eval).to receive(:evaluate).and_return({ passed: true, score: 1.0 })

      fail_eval = double('fail', name: 'f')
      allow(fail_eval).to receive(:evaluate).and_return({ passed: false, score: 0.0 })

      client.run_experiment(
        name: 'baseline', dataset_name: 'test_ds',
        task_callable: lambda(&:upcase), evaluators: [pass_eval]
      )

      client.run_experiment(
        name: 'candidate', dataset_name: 'test_ds',
        task_callable: lambda(&:downcase), evaluators: [fail_eval]
      )

      result = client.compare_experiments(exp1_name: 'baseline', exp2_name: 'candidate')
      expect(result[:regression_count]).to eq(2)
      expect(result[:improvement_count]).to eq(0)
    end
  end
end
