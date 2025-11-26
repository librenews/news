require "net/http"
require "uri"
require "json"

class SkytorchClient
  def self.generate_embedding(text, model_name: "all-MiniLM-L6-v2")
    new.generate_embedding(text, model_name: model_name)
  end

  def self.extract_entities(text)
    new.extract_entities(text)
  end

  def initialize
    @base_url = ENV.fetch("SKYTORCH_URL", "http://skytorch:5000")
  end

  def generate_embedding(text, model_name: "all-MiniLM-L6-v2")
    uri = URI.parse("#{@base_url}/api/v1/embeddings")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 30
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request.body = {
      text: text,
      model_name: model_name
    }.to_json

    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      data = JSON.parse(response.body)
      {
        success: true,
        embedding: data["embedding"],
        model_version: data["model_version"]
      }
    else
      {
        success: false,
        error: "HTTP #{response.code}: #{response.body}"
      }
    end
  rescue => e
    Rails.logger.error("SkytorchClient.generate_embedding error: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  def extract_entities(text)
    uri = URI.parse("#{@base_url}/api/v1/entities")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 30
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request.body = {
      text: text
    }.to_json

    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      data = JSON.parse(response.body)
      {
        success: true,
        entities: data["entities"] || [],
        count: data["count"] || 0
      }
    else
      {
        success: false,
        error: "HTTP #{response.code}: #{response.body}"
      }
    end
  rescue => e
    Rails.logger.error("SkytorchClient.extract_entities error: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end
end

