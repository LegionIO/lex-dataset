# frozen_string_literal: true

require 'spec_helper'

LlmGenerateResponse = Struct.new(:content)

module Legion
  module LLM
    class << self
      def started?
        @started ||= false
      end

      def start_generate_stub
        @started = true
      end

      def stop_generate_stub
        @started = false
      end

      def chat(**)
        raise NotImplementedError, 'stub — override in specs'
      end

      def structured(**)
        raise NotImplementedError, 'stub — override in specs'
      end
    end
  end
end

RSpec.describe Legion::Extensions::Dataset::Runners::Dataset, '#generate_dataset' do
  let(:client) { Legion::Extensions::Dataset::Client.new(db: DB) }

  let(:valid_rows_json) do
    JSON.generate([
                    { 'input' => 'hello', 'expected_output' => 'HELLO' },
                    { 'input' => 'world', 'expected_output' => 'WORLD' }
                  ])
  end

  before { Legion::LLM.start_generate_stub }
  after  { Legion::LLM.stop_generate_stub }

  context 'when Legion::LLM is available' do
    context 'using Legion::LLM.structured (preferred path)' do
      before do
        allow(Legion::LLM).to receive(:respond_to?).and_call_original
        allow(Legion::LLM).to receive(:respond_to?).with(:started?).and_return(true)
        allow(Legion::LLM).to receive(:respond_to?).with(:structured).and_return(true)
        allow(Legion::LLM).to receive(:structured)
          .and_return(LlmGenerateResponse.new(valid_rows_json))
      end

      it 'returns generated: true with name and version' do
        result = client.generate_dataset(name: 'gen_ds', description: 'greet inputs')
        expect(result[:generated]).to be true
        expect(result[:name]).to eq('gen_ds')
        expect(result[:version]).to eq(1)
      end

      it 'persists the generated rows' do
        client.generate_dataset(name: 'gen_ds', description: 'greet inputs')
        stored = client.get_dataset(name: 'gen_ds')
        expect(stored[:row_count]).to eq(2)
        expect(stored[:rows].first[:input]).to eq('hello')
        expect(stored[:rows].first[:expected_output]).to eq('HELLO')
      end

      it 'passes count to the prompt' do
        expect(Legion::LLM).to receive(:structured) do |**kwargs|
          expect(kwargs[:message]).to include('5')
          LlmGenerateResponse.new(valid_rows_json)
        end
        client.generate_dataset(name: 'gen_ds', description: 'greet inputs', count: 5)
      end

      it 'includes description in the prompt' do
        expect(Legion::LLM).to receive(:structured) do |**kwargs|
          expect(kwargs[:message]).to include('greet inputs')
          LlmGenerateResponse.new(valid_rows_json)
        end
        client.generate_dataset(name: 'gen_ds', description: 'greet inputs')
      end

      it 'passes model kwarg when provided' do
        expect(Legion::LLM).to receive(:structured)
          .with(hash_including(model: 'claude-3-5-sonnet'))
          .and_return(LlmGenerateResponse.new(valid_rows_json))
        client.generate_dataset(name: 'gen_ds', description: 'greet inputs', model: 'claude-3-5-sonnet')
      end

      it 'does not pass model kwarg when nil' do
        expect(Legion::LLM).to receive(:structured) do |**kwargs|
          expect(kwargs).not_to have_key(:model)
          LlmGenerateResponse.new(valid_rows_json)
        end
        client.generate_dataset(name: 'gen_ds', description: 'greet inputs')
      end

      context 'with schema provided' do
        let(:schema) { { 'type' => 'object', 'properties' => { 'input' => { 'type' => 'string' } } } }

        it 'includes schema JSON in the prompt' do
          expect(Legion::LLM).to receive(:structured) do |**kwargs|
            expect(kwargs[:message]).to include('Schema guidance')
            LlmGenerateResponse.new(valid_rows_json)
          end
          client.generate_dataset(name: 'gen_ds', description: 'greet inputs', schema: schema)
        end
      end
    end

    context 'using Legion::LLM.chat (fallback path)' do
      before do
        allow(Legion::LLM).to receive(:respond_to?).and_call_original
        allow(Legion::LLM).to receive(:respond_to?).with(:started?).and_return(true)
        allow(Legion::LLM).to receive(:respond_to?).with(:structured).and_return(false)
        allow(Legion::LLM).to receive(:chat)
          .and_return(LlmGenerateResponse.new(valid_rows_json))
      end

      it 'falls back to chat and still persists rows' do
        result = client.generate_dataset(name: 'chat_ds', description: 'greet inputs')
        expect(result[:generated]).to be true
        stored = client.get_dataset(name: 'chat_ds')
        expect(stored[:row_count]).to eq(2)
      end

      it 'strips markdown fences from chat response' do
        allow(Legion::LLM).to receive(:chat)
          .and_return(LlmGenerateResponse.new("```json\n#{valid_rows_json}\n```"))
        result = client.generate_dataset(name: 'fence_ds', description: 'greet inputs')
        expect(result[:generated]).to be true
      end
    end

    context 'JSON parse failure with retry' do
      let(:call_count) { { n: 0 } }

      before do
        allow(Legion::LLM).to receive(:respond_to?).and_call_original
        allow(Legion::LLM).to receive(:respond_to?).with(:started?).and_return(true)
        allow(Legion::LLM).to receive(:respond_to?).with(:structured).and_return(false)
        allow(Legion::LLM).to receive(:chat) do
          call_count[:n] += 1
          if call_count[:n] == 1
            LlmGenerateResponse.new('not valid json at all')
          else
            LlmGenerateResponse.new(valid_rows_json)
          end
        end
      end

      it 'retries once and succeeds on valid second response' do
        result = client.generate_dataset(name: 'retry_ds', description: 'greet inputs')
        expect(call_count[:n]).to eq(2)
        expect(result[:generated]).to be true
      end

      it 'includes "IMPORTANT" correction text in the retry prompt' do
        prompts = []
        allow(Legion::LLM).to receive(:chat) do |**kwargs|
          prompts << kwargs[:message]
          call_count[:n] += 1
          if call_count[:n] == 1
            LlmGenerateResponse.new('bad json')
          else
            LlmGenerateResponse.new(valid_rows_json)
          end
        end
        client.generate_dataset(name: 'retry_ds2', description: 'greet inputs')
        expect(prompts.last).to include('IMPORTANT')
      end

      context 'when both attempts return invalid JSON' do
        before do
          allow(Legion::LLM).to receive(:chat)
            .and_return(LlmGenerateResponse.new('still not json'))
        end

        it 'returns an error hash' do
          result = client.generate_dataset(name: 'fail_ds', description: 'greet inputs')
          expect(result[:error]).to be_a(String)
          expect(result[:error]).to include('valid JSON')
        end
      end
    end
  end

  context 'when Legion::LLM is not available' do
    before { Legion::LLM.stop_generate_stub }

    it 'returns error hash without calling LLM' do
      result = client.generate_dataset(name: 'no_llm_ds', description: 'greet inputs')
      expect(result[:error]).to eq('legion-llm is not available')
    end
  end

  context 'when Legion::LLM is defined but started? returns false' do
    before do
      allow(Legion::LLM).to receive(:respond_to?).and_call_original
      allow(Legion::LLM).to receive(:respond_to?).with(:started?).and_return(true)
      allow(Legion::LLM).to receive(:started?).and_return(false)
    end

    it 'returns error hash' do
      result = client.generate_dataset(name: 'stopped_ds', description: 'greet inputs')
      expect(result[:error]).to eq('legion-llm is not available')
    end
  end
end
