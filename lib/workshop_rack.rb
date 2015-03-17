require 'workshop_rack/version'
require 'time'
require 'pry'

class WorkshopRack
  def initialize(app, options = {})
    @app = app
    @options = options
    @remaining_requests = @options[:limit] || 60
  end

  def call(env)
    return [429, {}, ['Too many requests.']] if @remaining_requests <= 0
    @status, @headers, body = @app.call(env)
    prepare_headers
    [@status, @headers, body]
  end

  private

  def prepare_headers
    reset_time
    decrease_ratelimit
    set_header('X-RateLimit-Limit', @options[:limit] || 60)
    set_header('X-RateLimit-Remaining', @remaining_requests)
    set_header('X-RateLimit-Reset', @reset_time)
  end

  def decrease_ratelimit
    @remaining_requests -= 1
  end

  def set_header(header, value)
    @headers[header] = value.to_s
  end

  def reset_time
    if @reset_time.nil? || Time.now.to_i - @reset_time > 3600
      @reset_time = Time.now.to_i
      @remaining_requests = @options[:limit] || 60
    end
  end
end
