require 'spec_helper'

describe RateLimiter do
  include Rack::Test::Methods
  let(:test_app) { ->(_env) { [200, {'Content-Type' => 'text/html'}, ['Smoke test, darling.']] } }
  let(:raw_app) { RateLimiter.new(test_app) }
  let(:app) { Rack::Lint.new(raw_app) }

  before { allow(test_app).to receive(:call).and_call_original }

  it 'has a version number' do
    expect(RateLimiter::VERSION).not_to be nil
  end

  context 'upon any request to default app' do
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

    context 'with timelimit for storing requests count' do
      before { 9.times { get '/' } }
      after { Timecop.return }

      it 'stores X-RateLimit-Remaining within timelimit' do
        Timecop.travel(Time.now + 3600)
        get '/'
        expect(last_response.headers['X-RateLimit-Remaining']).to eq('49')
      end

      it 'resets X-RateLimit-Remaining after timelimit lapse' do
        Timecop.travel(Time.now + 3601)
        get '/'
        expect(last_response.headers['X-RateLimit-Remaining']).to eq('59')
      end
    end

    describe 'blocking clients after hitting ratelimit' do
      before { 60.times { get '/' } }

      it 'works basing on accumulated requests for a client individually' do
        expect(last_response).not_to be_ok
        expect(last_response.status).to eq(429)
        expect(last_response.body).to eq('Too many requests.')
      end

      it 'does not work basing on accumulated requests from different clients' do
        get '/', {}, 'REMOTE_ADDR' => '10.0.0.4'
        expect(last_response.headers['X-RateLimit-Remaining']).to eq('59')
        expect(test_app).to have_received(:call).exactly(61).times
      end
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

  context 'when app is initialized with custom ratelimit' do
    let(:raw_app) { RateLimiter.new(test_app, limit: 4) }

    before { 4.times { get '/' } }

    it 'adds custom X-RateLimit-Limit header' do
      expect(last_response.headers['X-RateLimit-Limit']).to eq('4')
    end

    it 'calls the app no more times than custom ratelimit' do
      get '/'
      expect(test_app).to have_received(:call).exactly(4).times
    end

    it 'blocks client after hitting custom ratelimit' do
      get '/'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(429)
      expect(last_response.body).to eq('Too many requests.')
    end

    it 'does not prevent calling the app if custom ratelimit hit by other client' do
      get '/', {}, 'REMOTE_ADDR' => '10.0.0.4'
      expect(test_app).to have_received(:call).exactly(5).times
    end
  end

  context 'when called with explicit store' do
    let(:store) { double('store') }
    let(:raw_app) { RateLimiter.new(test_app, {limit: 5, store: store}) }
    let(:response_from_get) { {'reset_time' => 1, 'remaining_requests' => 2} }

    before do
      allow(store).to receive(:set)
      allow(store).to receive(:get).with('1.2.3.4').and_return(response_from_get)
    end

    it 'calls set on the store' do
      get '/', {}, 'REMOTE_ADDR' => '1.2.3.4'
      expect(store).to have_received(:set).exactly(2).times
    end

    it 'receives correct response from get' do
      expect(store.get('1.2.3.4')).to eq(response_from_get)
    end
  end
end
