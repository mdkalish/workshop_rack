require 'rack/test'
require 'rate_limiter'
require 'timecop'

RSpec.configure do |config|
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
