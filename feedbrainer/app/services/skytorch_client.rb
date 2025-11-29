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

  def self.get_followers(did, limit: 100, cursor: nil)
    new.get_followers(did, limit: limit, cursor: cursor)
  end

  def self.get_follows(did, limit: 100, cursor: nil)
    new.get_follows(did, limit: limit, cursor: cursor)
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

  def get_followers(did, limit: 100, cursor: nil)
    params = { did: did, limit: limit }
    params[:cursor] = cursor if cursor
    uri = URI.parse("#{@base_url}/api/v1/followers")
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 30
    http.read_timeout = 60

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Content-Type"] = "application/json"

    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      data = JSON.parse(response.body)
      {
        success: true,
        data: data["followers"] || [],
        cursor: data["cursor"],
        count: data["count"] || 0
      }
    else
      {
        success: false,
        error: "HTTP #{response.code}: #{response.body}"
      }
    end
  rescue => e
    Rails.logger.error("SkytorchClient.get_followers error: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  def get_follows(did, limit: 100, cursor: nil)
    params = { did: did, limit: limit }
    params[:cursor] = cursor if cursor
    uri = URI.parse("#{@base_url}/api/v1/follows")
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 30
    http.read_timeout = 60

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Content-Type"] = "application/json"

    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      data = JSON.parse(response.body)
      {
        success: true,
        data: data["follows"] || [],
        cursor: data["cursor"],
        count: data["count"] || 0
      }
    else
      {
        success: false,
        error: "HTTP #{response.code}: #{response.body}"
      }
    end
  rescue => e
    Rails.logger.error("SkytorchClient.get_follows error: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end
end

