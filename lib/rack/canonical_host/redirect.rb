require 'addressable/uri'
require 'rack'

module Rack
  class CanonicalHost
    class Redirect
      HTML_TEMPLATE = <<-HTML.gsub(/^\s+/, '')
        <!DOCTYPE html>
        <html lang="en-US">
          <head><title>301 Moved Permanently</title></head>
          <body>
            <h1>Moved Permanently</h1>
            <p>The document has moved <a href="%s">here</a>.</p>
          </body>
        </html>
      HTML

      def initialize(env, host, options={})
        self.env = env
        self.host = host
        self.ignore = options[:ignore]
        self.conditions = Array(options[:if])
        self.cache_control = options[:cache_control]
      end

      def canonical?
        return true unless enabled?
        known? || ignored?
      end

      def response
        [301, headers, [HTML_TEMPLATE % new_url]]
      end

    protected

      attr_accessor :env
      attr_accessor :host
      attr_accessor :ignore
      attr_accessor :conditions
      attr_accessor :cache_control

    private

      def any_match?(patterns, string)
        patterns.any? { |pattern| string[pattern] }
      end

      def headers
        {
          'Cache-Control' => cache_control,
          'Content-Type' => 'text/html',
          'Location' => new_url,
        }.reject { |_, value| !value }
      end

      def enabled?
        return true if conditions.empty?

        conditions.include?(request_uri.host) ||
          any_match?(conditions, request_uri.host)
      end

      def ignored?
        return ignore.call(rack_request) if ignore.is_a?(Proc)

        ignore_options = Array(ignore)

        return false if ignore_options.empty?

        ignore_options.include?(request_uri.host) ||
          any_match?(ignore_options, request_uri.host)
      end

      def known?
        host.nil? || request_uri.host == host
      end

      def new_url
        uri = request_uri.dup
        uri.host = host
        uri.normalize.to_s
      end

      def request_uri
        @request_uri ||= Addressable::URI.parse(rack_request.url)
      end

      def rack_request
        @rack_request ||= Rack::Request.new(env)
      end
    end
  end
end
