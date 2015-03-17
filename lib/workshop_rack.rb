require 'workshop_rack/version'
require 'pry'

class WorkshopRack
  def initialize(app, options = {})
    @app = app
    @options = options
    @remaining_requests = @options[:limit] || 60
  end

  def call(env)
    return [429, {}, ['Too many requests.']] if @remaining_requests <= 0
    @status, headers, body = @app.call(env)
    decrease_ratelimit
    prepare_headers(headers)
    [@status, headers, body]
  end

  private

  def decrease_ratelimit
    @remaining_requests -= 1
  end

  def prepare_headers(headers)
    add_header(headers, 'X-RateLimit-Limit', @options[:limit] || 60)
    add_header(headers, 'X-RateLimit-Remaining', @remaining_requests)
  end

  def add_header(headers, header, value)
    headers.merge!(header.to_s => value.to_s) # By the SPEC, headers must be String
  end
end
