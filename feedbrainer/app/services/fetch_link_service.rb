require "net/http"
require "uri"

class FetchLinkService
  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    uri = URI.parse(@url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "Feedbrainer/1.0"
    
    response = http.request(request)
    
    if response.code.to_i >= 200 && response.code.to_i < 300
      {
        success: true,
        html_content: response.body,
        url: @url
      }
    else
      {
        success: false,
        error: "HTTP #{response.code}"
      }
    end
  rescue => e
    Rails.logger.error("FetchLinkService error for #{@url}: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end
end

