require 'time'
require 'pry'

class WorkshopRack
  def initialize(app, options = {}, &block)
    @app = app
    @options = options
    @remaining_requests = @options[:limit] || 60
    @clients = {}
    @block = block || ->(_env) {}
  end

  def call(env)
    if nil_or_empty? [env['REMOTE_ADDR'], @block.call(env)]
      return [418, {}, ["I'm a teapot"]]
    elsif !nil_or_empty? [@block.call(env)]
      @id = @block.call(env)
    else
      @id = env['REMOTE_ADDR']
    end

    return [429, {}, ['Too many requests.']] if @remaining_requests <= 0
    @clients[@id] ||= {}
    @status, @headers, body = @app.call(env)
    prepare_headers
    [@status, @headers, body]
  end

  private

  def nil_or_empty?(obj = [])
    return true if obj.all? { |o| o.nil? }
    obj.all? { respond_to?(:empty?) ? !!empty? : !self }
  end

  def prepare_headers
    reset_time
    decrease_ratelimit
    set_header('X-RateLimit-Limit', @options[:limit] || 60)
    set_header('X-RateLimit-Remaining', @remaining_requests)
    set_header('X-RateLimit-Reset', @reset_time)
  end

  def decrease_ratelimit
    @remaining_requests  = @clients[@id]['remaining_requests'] -= 1
  end

  def set_header(header, value)
    @headers[header] = value.to_s
  end

  def reset_time
    @reset_time = @clients[@id]['reset_time']
    if @reset_time.nil? || Time.now.to_i - @reset_time > 3600
      @reset_time = @clients[@id]['reset_time'] = Time.now.to_i
      @remaining_requests = @clients[@id]['remaining_requests'] = @options[:limit] || 60
    end
  end
end
