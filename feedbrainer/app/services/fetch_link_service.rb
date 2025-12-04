require "net/http"
require "uri"

class FetchLinkService
  MAX_REDIRECTS = 5

  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    fetch_with_redirects(@url, 0)
  end

  private

  def fetch_with_redirects(url, redirect_count)
    if redirect_count > MAX_REDIRECTS
      return {
        success: false,
        error: "Too many redirects (max #{MAX_REDIRECTS})"
      }
    end

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "Feedbrainer/1.0"
    
    response = http.request(request)
    
    case response.code.to_i
    when 200..299
      {
        success: true,
        html_content: response.body,
        url: url
      }
    when 300..399
      # Handle redirects
      redirect_location = response["Location"]
      unless redirect_location
        return {
          success: false,
          error: "HTTP #{response.code} (no Location header)"
        }
      end

      # Handle relative redirects
      redirect_uri = URI.parse(redirect_location)
      if redirect_uri.relative?
        redirect_uri = uri + redirect_uri
      end

      Rails.logger.debug("FetchLinkService: Following redirect #{redirect_count + 1}/#{MAX_REDIRECTS} from #{url} to #{redirect_uri}")
      fetch_with_redirects(redirect_uri.to_s, redirect_count + 1)
    else
      {
        success: false,
        error: "HTTP #{response.code}"
      }
    end
  rescue URI::InvalidURIError => e
    Rails.logger.error("FetchLinkService: Invalid URI #{url}: #{e.message}")
    {
      success: false,
      error: "Invalid URI: #{e.message}"
    }
  rescue => e
    Rails.logger.error("FetchLinkService error for #{url}: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end
end

