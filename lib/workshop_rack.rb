require 'workshop_rack/version'

class WorkshopRack
  def initialize(app, options = {})
    @app = app
    @options = options
  end

  def call(env)
    status, headers, body = @app.call(env)
    add_rate_limit_header(headers, @options[:limit] || '60')
    [status, headers, body]
  end

  def add_rate_limit_header(headers, limit)
    headers.merge!('X-RateLimit-Limit' => limit)
  end
end
