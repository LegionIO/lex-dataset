# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Dataset do
  it 'has a version number' do
    expect(Legion::Extensions::Dataset::VERSION).not_to be_nil
  end

  it 'version is a string' do
    expect(Legion::Extensions::Dataset::VERSION).to be_a(String)
  end
end
