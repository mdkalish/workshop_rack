require 'workshop_rack/version'
require 'pry'

class WorkshopRack
  def initialize(app, options = {})
    @app = app
    @options = options
    @x_ratelimit_remaining = @options[:limit] || 60
  end

  def call(env)
    status, headers, body = @app.call(env)
    decrease_ratelimit
    prepare_headers(headers)
    [status, headers, body]
  end

  private

  def decrease_ratelimit
    @x_ratelimit_remaining -= 1
  end

  def prepare_headers(headers)
    add_header(headers, 'X-RateLimit-Limit', @options[:limit] || 60)
    add_header(headers, 'X-RateLimit-Remaining', @x_ratelimit_remaining)
  end

  def add_header(headers, header, value)
    headers.merge!(header.to_s => value.to_s) # By the SPEC, headers must be String
  end
end
