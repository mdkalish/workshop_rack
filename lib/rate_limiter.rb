require 'time'
require 'rate_limiter/store'
require 'pry'

class RateLimiter
  def initialize(app, options = {}, store = Store.new, &block)
    @app = Rack::Lint.new(app)
    @options = options
    @remaining_requests = @options[:limit] || 60
    @clients = store
    @block = block
  end

  def call(env)
    if !@block.nil? && nil_or_empty?([@block.call(env)])
      @status, @headers, body = @app.call(env)
      return [@status, @headers, body]
    end
    determine_id(env)
    set_client_limit_if_not_stored_yet
    if @clients.get(@id)['remaining_requests'] <= 0
      return [429, {}, ['Too many requests.']]
    end
    @status, @headers, body = @app.call(env)
    update_headers_values
    set_headers
    [@status, @headers, body]
  end

  private

  def nil_or_empty?(obj = [])
    return true if obj.all? { |o| o.nil? }
    obj.all? { respond_to?(:empty?) ? !!empty? : !self }
  end

  def determine_id(env)
    if @block.nil?
      @id = env['REMOTE_ADDR']
    elsif @block.call(env)
      @id = @block.call(env)
    end
  end

  def set_client_limit_if_not_stored_yet
    @clients.set(@id, {'remaining_requests' => @remaining_requests + 1}) if @clients.get(@id).nil?
  end

  def update_headers_values
    reset_time
    decrease_ratelimit
  end

  def reset_time
    @reset_time = @clients.get(@id)['reset_time']
    if @reset_time.nil? || Time.now.to_i - @reset_time > 3600
      @reset_time = @clients.get(@id)['reset_time'] = Time.now.to_i
      @remaining_requests = @clients.get(@id)['remaining_requests'] = @options[:limit] || 60
    end
  end

  def decrease_ratelimit
    @remaining_requests = @clients.get(@id)['remaining_requests'] -= 1
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
