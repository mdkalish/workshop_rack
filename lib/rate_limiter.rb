require 'time'
require 'rate_limiter/store'

class RateLimiter
  def initialize(app, options = {}, store = Store.new, &block)
    @app = app
    @options = options
    @remaining_requests = @options[:limit] || 60
    @clients = store
    @block = block
  end

  def call(env)
    @block = ->(args) { args["HTTP_X_FORWARDED_FOR"] || args['REMOTE_ADDR'] } if @block.nil?
    return @app.call(env) if @block.call(env).nil?
    @id = @block.call(env)
    set_client_limit_if_not_stored_yet
    return [429, {}, ['Too many requests.']] if @clients.get(@id)['remaining_requests'] <= 0
    @status, @headers, body = @app.call(env)
    update_headers_values
    set_headers
    [@status, @headers, body]
  end

  private

  def set_client_limit_if_not_stored_yet
    @clients.set(@id, 'remaining_requests' => @remaining_requests + 1) if @clients.get(@id).nil?
  end

  def update_headers_values
    reset_time
    decrease_ratelimit
  end

  def reset_time
    @reset_time = @clients.get(@id)['reset_time']
    if @reset_time.nil? || Time.now.to_i - @reset_time > 3600
      @reset_time = Time.now.to_i
      @remaining_requests = @options[:limit] || 60
      @clients.set(@id, 'reset_time' => @reset_time)
      @clients.set(@id, 'remaining_requests' => @remaining_requests)
    end
  end

  def decrease_ratelimit
    @remaining_requests = @clients.get(@id)['remaining_requests'] -= 1
    @clients.set(@id, 'remaining_requests' => @remaining_requests)
  end

  def set_headers
    set_header('X-RateLimit-Limit', @options[:limit] || 60)
    set_header('X-RateLimit-Remaining', @remaining_requests)
    set_header('X-RateLimit-Reset', @reset_time)
  end

  def set_header(header, value)
    @headers[header] = value.to_s
  end
end
