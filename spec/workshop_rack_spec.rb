require 'spec_helper'

describe RateLimiter do
  include Rack::Test::Methods
  let(:test_app) { ->(_env) { [200, {'Content-Type' => 'text/html'}, ['Smoke test, darling.']] } }
  let(:raw_app) { RateLimiter.new(test_app) }
  let(:app) { Rack::Lint.new(raw_app) }

  it 'has a version number' do
    expect(RateLimiter::VERSION).not_to be nil
  end

  context 'upon any request' do
    before { get '/' }

    it 'returns correct response' do
      expect(last_response.body).to eq('Smoke test, darling.')
    end

    it 'adds X-RateLimit-Limit header' do
      expect(last_response.headers).to have_key('X-RateLimit-Limit')
      expect(last_response.headers['X-RateLimit-Limit']).to eq('60')
    end

    it 'adds X-RateLimit-Remaining header' do
      expect(last_response.headers).to have_key('X-RateLimit-Remaining')
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('59')
    end

    it 'adds X-RateLimit-Reset header' do
      expect(last_response.headers).to have_key('X-RateLimit-Reset')
    end

    it 'decreases X-RateLimit-Remaining header' do
      2.times { get '/' }
      expect(last_response.headers['X-RateLimit-Remaining']).to eq('57')
    end

    it 'resets X-RateLimit-Remaining after timelimit lapse' do
      remaining_before_calls = get('/').headers['X-RateLimit-Remaining'].to_i
      4.times { get '/' }
      remaining_after_calls = last_response.headers['X-RateLimit-Remaining'].to_i
      expect(remaining_after_calls).not_to be_within(3).of(remaining_before_calls)
      expect(remaining_after_calls).to be_within(4).of(remaining_before_calls)

      Timecop.travel(Time.now + 3601)
      remaining_after_reset = get('/').headers['X-RateLimit-Remaining'].to_i
      expect(remaining_after_reset - 1).to eq(remaining_before_calls)
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
        let (:raw_app) { RateLimiter.new(test_app) { |env| env['QUERY_STRING'] } }

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
        let(:raw_app) { RateLimiter.new(test_app) { nil } }

        it 'responds without limiting headers' do
          get '/'
          expect(last_response.headers).not_to be_nil
          expect(last_response.headers.keys).not_to include('X-RateLimit-Limit')
          expect(last_response.headers.keys).not_to include('X-RateLimit-Remaining')
          expect(last_response.headers.keys).not_to include('X-RateLimit-Reset')
        end
      end
    end
  end

  context 'when app is initialized with options[:limit]' do
    let(:raw_app) { RateLimiter.new(test_app, limit: 4) }

    it 'adds arbitrary X-RateLimit-Limit header' do
      get '/'
      expect(last_response.headers['X-RateLimit-Limit']).to eq('4')
    end

    it 'calls the app until hitting arbitrary ratelimit' do
      expect(test_app).to receive(:call).and_call_original.exactly(4).times
      5.times { get '/' }
    end

    it 'blocks requests after hitting arbitrary ratelimit' do
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

    it 'does not prevent calling the app if ratelimit hit by other client' do
      4.times { get '/' }
      expect(test_app).to receive(:call).and_call_original
      get '/', {}, 'REMOTE_ADDR' => '10.0.0.4'
    end
  end

  context 'when called with explicit store' do
    let(:raw_app) { RateLimiter.new(test_app, {limit: 5}, @store) }

    before do
      @get_return_value = {'reset_time' => 1, 'remaining_requests' => 2}
      @store = double('store')
      allow(@store).to receive(:get).with('1.2.3.4').and_return(@get_return_value)
    end

    it 'uses the store object properly' do
      expect(@store.get('1.2.3.4')).to eq(@get_return_value)
      get '/', {}, 'REMOTE_ADDR' => '1.2.3.4'
      expect(@store.get('1.2.3.4')['reset_time']).to eq(Time.now.to_i)
      expect(@store.get('1.2.3.4')['remaining_requests']).to eq(4)
    end
  end
end
