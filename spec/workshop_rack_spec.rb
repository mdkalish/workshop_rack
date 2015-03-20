require 'spec_helper'

describe RateLimiter do
  include Rack::Test::Methods
  let(:test_app) { ->(_env) { [200, {'Content-Type' => 'text/html'}, ['Smoke test, darling.']] } }
  let(:app) { Rack::Lint.new(RateLimiter.new(test_app)) }

  it 'has a version number' do
    expect(RateLimiter::VERSION).not_to be nil
  end

  context 'upon any request' do
    it 'returns correct response' do
      get '/'
      expect(last_response.body).to eq('Smoke test, darling.')
    end

    it 'adds X-RateLimit-Limit header' do
      get '/'
      expect(last_response.headers).to have_key('X-RateLimit-Limit')
      expect(last_response.headers['X-RateLimit-Limit']).to eq('60')
    end

    it 'adds X-RateLimit-Remaining header' do
      get '/'
      expect(last_response.headers).to have_key('X-RateLimit-Remaining')
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('59')
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
    context 'distinguished by ips' do
      it 'keeps separate ratelimits' do
        get '/', {}, 'REMOTE_ADDR' => '10.0.0.1'
        expect(last_response.headers['X-RateLimit-Remaining']).to eq('59')

        3.times { get('/', {}, 'REMOTE_ADDR' => '10.0.0.2') }
        expect(last_response.headers['X-RateLimit-Remaining']).to eq('57')

        get '/', {}, 'REMOTE_ADDR' => '10.0.0.1'
        expect(last_response.headers['X-RateLimit-Remaining']).to eq('58')

        4.times { get '/', {}, 'REMOTE_ADDR' => '10.0.0.2' }
        expect(last_response.headers['X-RateLimit-Remaining']).to eq('53')

        5.times { get '/', {}, 'REMOTE_ADDR' => '10.0.0.3' }
        expect(last_response.headers['X-RateLimit-Remaining']).to eq('55')
      end
    end

    context 'distinguished by custom ids passed in block' do
      context 'when block returns valid identifier' do
        let (:app) { RateLimiter.new(test_app) { |env| env['QUERY_STRING'] } }

        it 'responds with limiting headers' do
          get '/'
          expect(last_response.headers['X-RateLimit-Limit']).not_to be_nil
          expect(last_response.headers['X-RateLimit-Remaining']).not_to be_nil
          expect(last_response.headers['X-RateLimit-Reset']).not_to be_nil
        end

        it 'keeps separate ratelimits' do
          2.times { get '/', {}, 'QUERY_STRING' => 'qs_token_one' }
          expect(last_response.headers['X-RateLimit-Remaining']).to eq('58')

          3.times { get '/', {}, 'QUERY_STRING' => 'qs_token_two' }
          expect(last_response.headers['X-RateLimit-Remaining']).to eq('57')

          4.times { get '/', {}, 'QUERY_STRING' => 'qs_token_one' }
          expect(last_response.headers['X-RateLimit-Remaining']).to eq('54')

          5.times { get '/', {}, 'QUERY_STRING' => 'qs_token_three' }
          expect(last_response.headers['X-RateLimit-Remaining']).to eq('55')
        end

        it 'responds 429 if limit hit' do
          61.times { get('/', {}, 'QUERY_STRING' => 'qs_token_four') }
          expect(last_response.status).to eq(429)
          expect(last_response.body).to eq('Too many requests.')
        end
      end

      context 'when block returns nil' do
        let(:stack) { Rack::Lint.new(RateLimiter.new(app) { nil }) }
        let(:request) { Rack::MockRequest.new(stack) }
        let(:response) { request.get('/') }

        it 'responds with 418' do
          expect(response.status).to eq(418)
          expect(response.body).to eq("I'm a teapot")
        end

        it 'responds without limiting headers' do
          expect(response.headers.length).to eq(1)
          expect(response.headers.keys).to eq(['Content-Length'])
        end
      end
    end
  end

  context 'when app is initialized with options[:limit]' do
    let(:app) { Rack::Lint.new(RateLimiter.new(test_app, limit: 4)) }

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
