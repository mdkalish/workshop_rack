require 'spec_helper'
require 'workshop_rack'

describe WorkshopRack do
  include Rack::Test::Methods

  let(:test_app) { ->(_env) { ['200', {'Content-Type' => 'text/html'}, ['Smoke test, darling.']] } }

  it 'has a version number' do
    expect(WorkshopRack::VERSION).not_to be nil
  end

  context 'when a request is sent' do
    let(:app) { WorkshopRack.new(test_app) }

    it 'returns correct response' do
      get '/'
      expect(last_response.body).to eq('Smoke test, darling.')
    end

    it 'adds X-RateLimit-Limit' do
      get '/'
      expect(last_response.headers).to include('X-RateLimit-Limit')
    end
  end
end
