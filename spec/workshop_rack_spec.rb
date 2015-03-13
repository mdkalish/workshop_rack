require 'spec_helper'

describe WorkshopRack do
  include Rack::Test::Methods

  let(:app) { lambda { |env| ['200', {'Content-Type' => 'text/html'}, ['Smoke test, darling.']] } }

  it 'has a version number' do
    expect(WorkshopRack::VERSION).not_to be nil
  end

  context 'when a request is sent' do
    it 'returns correct response' do
      get '/'
      expect(last_response.body).to eq('Smoke test, darling.')
    end
  end
end
