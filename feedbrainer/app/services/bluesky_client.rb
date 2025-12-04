require "net/http"
require "uri"
require "json"

class BlueskyClient
  BASE_URL = "https://public.api.bsky.app"

  def self.get_posts(uris)
    new.get_posts(uris)
  end

  def get_posts(uris)
    uris = [uris] unless uris.is_a?(Array)
    return { success: true, posts: [] } if uris.empty?

    uri = URI.parse("#{BASE_URL}/xrpc/app.bsky.feed.getPosts")
    # Construct query string manually to handle multiple 'uris' parameters
    query_params = uris.map { |u| "uris=#{CGI.escape(u)}" }.join("&")
    uri.query = query_params

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Content-Type"] = "application/json"

    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      data = JSON.parse(response.body)
      {
        success: true,
        posts: data["posts"] || []
      }
    else
      Rails.logger.error("BlueskyClient.get_posts failed: HTTP #{response.code}: #{response.body}")
      {
        success: false,
        error: "HTTP #{response.code}: #{response.body}"
      }
    end
  rescue => e
    Rails.logger.error("BlueskyClient.get_posts error: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end
end
