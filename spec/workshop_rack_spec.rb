require 'spec_helper'
require 'workshop_rack'

describe WorkshopRack do
  include Rack::Test::Methods

  let(:test_app) { ->(_env) { ['200', {'Content-Type' => 'text/html'}, ['Smoke test, darling.']] } }

  it 'has a version number' do
    expect(WorkshopRack::VERSION).not_to be nil
  end

  context 'when a default request is sent' do
    let(:app) { Rack::Lint.new(WorkshopRack.new(test_app)) }

    it 'returns correct response' do
      get '/'
      expect(last_response.body).to eq('Smoke test, darling.')
    end

    it 'adds X-RateLimit-Limit header' do
      get '/'
      expect(last_response.headers).to have_key('X-RateLimit-Limit')
    end
  end

  context 'when request with opts is sent' do
    let(:app) { Rack::Lint.new(WorkshopRack.new(test_app, limit: '21')) }

    it 'adds arbitrary X-RateLimit-Limit header' do
      get '/'
      expect(last_response.headers['X-RateLimit-Limit']).to eq('21')
    end
  end
end
