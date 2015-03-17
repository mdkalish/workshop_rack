require 'spec_helper'
require 'workshop_rack'
require 'timecop'

describe WorkshopRack do
  include Rack::Test::Methods
  let(:test_app) { ->(_env) { ['200', {'Content-Type' => 'text/html'}, ['Smoke test, darling.']] } }
  let(:app) { Rack::Lint.new(WorkshopRack.new(test_app)) }

  it 'has a version number' do
    expect(WorkshopRack::VERSION).not_to be nil
  end

  context 'upon any request' do
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

    it 'adds X-RateLimit-Reset header' do
      get '/'
      expect(last_response.headers).to have_key('X-RateLimit-Reset')
    end

    it 'decreases X-RateLimit-Remaining header' do
      3.times { get '/' }
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('57')
    end

    it 'resets X-RateLimit-Remaining after timelimit lapse' do
      remaining_before_calls = get('/').headers['X-RateLimit-Remaining'].to_i
      5.times { get '/' }
      remaining_after_calls = last_response.headers['X-RateLimit-Remaining'].to_i
      expect(remaining_after_calls).to eq(remaining_before_calls - 5)

      Timecop.travel(Time.now + 3601) # lapse is 3600
      remaining_after_reset = get('/').headers['X-RateLimit-Remaining'].to_i
      expect(remaining_after_reset).to eq(remaining_before_calls)
    end
  end

  context 'when requests come from various users' do
    it 'keeps separate ratelimits' do
      get '/', {}, 'REMOTE_ADDR' => '10.0.0.1'
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('59')
      3.times { get '/', {}, 'REMOTE_ADDR' => '10.0.0.2' }
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('57')
      get '/', {}, 'REMOTE_ADDR' => '10.0.0.1'
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('58')
      4.times { get '/', {}, 'REMOTE_ADDR' => '10.0.0.2' }
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('53')
      5.times { get '/', {}, 'REMOTE_ADDR' => '10.0.0.3' }
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('55')
    end
  end

  context 'when request with opts is sent' do
    let(:app) { Rack::Lint.new(WorkshopRack.new(test_app, limit: 4)) }

    it 'adds arbitrary X-RateLimit-Limit header' do
      get '/'
      expect(last_response.headers['X-RateLimit-Limit']).to eq('4')
    end

    it 'calls the app until hitting ratelimit' do
      expect(test_app).to receive(:call).and_call_original
      get '/'
    end

    it 'blocks requests after hitting ratelimit' do
      5.times { get '/' }
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(429)
      expect(last_response.body).to eq('Too many requests.')
    end

    it 'prevents calling the app if ratelimit hit' do
      4.times { get '/' }
      expect(test_app).not_to receive(:call)
      get '/'
    end
  end
end
