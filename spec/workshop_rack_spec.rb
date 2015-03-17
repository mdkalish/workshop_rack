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

    it 'adds X-RateLimit-Remaining header' do
      get '/'
      expect(last_response.headers).to have_key('X-RateLimit-Remaining')
    end

    it 'decreases the X-RateLimit-Remaining header' do
      3.times { get '/' }
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('57')
    end
  end

  context 'when request with opts is sent' do
    let(:app) { Rack::Lint.new(WorkshopRack.new(test_app, limit: 4)) }

    it 'adds arbitrary X-RateLimit-Limit header' do
      get '/'
      expect(last_response.headers['X-RateLimit-Limit']).to eq('4')
    end

    it 'blocks requests after hitting the X-RateLimit-Remaining' do
      5.times { get '/' }
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(429)
      expect(last_response.body).to eq('Too many requests.')
    end

    it 'calls the app within ratelimit' do
      expect(test_app).to receive(:call).and_call_original
      get '/'
    end

    context 'when hit limit is reached' do
      before { 4.times { get '/' } }

      it 'prevents calling the app if ratelimit hit' do
        expect(test_app).not_to receive(:call)
        get '/'
      end
    end
  end
end
