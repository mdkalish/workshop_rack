require 'time'
require 'rate_limiter/store'

class RateLimiter
  def initialize(app, options = {}, &block)
    @app = app
    @options = options
    @default_requests_limit = @options[:limit] || 60
    @clients = options[:store] || Store.new
    @block = block || ->(args) { args["HTTP_X_FORWARDED_FOR"] || args['REMOTE_ADDR'] }
  end

  def call(env)
    @id = @block.call(env)
    return @app.call(env) if @id.nil?
    set_remaining_requests if @clients.get(@id).nil?
    @clients_limits = @clients.get(@id)
    reset_clients_limits if should_reset_limits?
    return too_many_requests if request_limit_exceeded?
    status, @headers, body = @app.call(env)
    decrease_ratelimit
    store_updated_limits
    set_headers
    [status, @headers, body]
  end

  private

  def set_remaining_requests
    @clients.set(@id, 'remaining_requests' => @default_requests_limit)
  end

  def too_many_requests
    [429, {}, ['Too many requests.']]
  end

  def request_limit_exceeded?
    @clients_limits['remaining_requests'] <= 0
  end

  def reset_clients_limits
    @reset_time = Time.now.to_i
    @remaining_requests = @default_requests_limit
    store_updated_limits
  end

  def should_reset_limits?
    @clients_limits['reset_time'].nil? || Time.now.to_i - @clients_limits['reset_time'] > 3600
  end

  def decrease_ratelimit
    @remaining_requests = @clients.get(@id)['remaining_requests'] -= 1
  end

  def set_headers
    set_header('X-RateLimit-Limit', @default_requests_limit)
    set_header('X-RateLimit-Remaining', @remaining_requests)
    set_header('X-RateLimit-Reset', @reset_time)
  end

  def set_header(header, value)
    @headers[header] = value.to_s
  end

  def store_updated_limits
    @clients.set(@id, {'remaining_requests' => @remaining_requests,
                       'reset_time' => @reset_time})
  end
end
