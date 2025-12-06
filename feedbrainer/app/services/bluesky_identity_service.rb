class BlueskyIdentityService
  # Resolve a Bluesky handle to DID and PDS endpoint
  def self.resolve_handle(handle)
    require "net/http"
    require "json"

    # Remove @ if present
    handle = handle.gsub(/^@/, "")

    # Step 1: Resolve handle to DID via DNS or HTTPS
    did = resolve_handle_to_did(handle)
    return { error: "Could not resolve handle to DID" } unless did

    # Step 2: Get PDS endpoint from DID document
    pds_endpoint = resolve_did_to_pds(did)
    return { error: "Could not resolve PDS endpoint" } unless pds_endpoint

    { did: did, pds_endpoint: pds_endpoint }
  rescue => e
    Rails.logger.error "Handle resolution error: #{e.message}"
    { error: e.message }
  end

  private

  def self.resolve_handle_to_did(handle)
    # Try HTTPS resolution first
    uri = URI("https://#{handle}/.well-known/atproto-did")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 5

    response = http.get(uri.path)
    return response.body.strip if response.code == "200" && response.body.start_with?("did:")

    # Fallback to bsky.social resolution
    uri = URI("https://bsky.social/xrpc/com.atproto.identity.resolveHandle")
    uri.query = URI.encode_www_form(handle: handle)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    response = http.get(uri)
    if response.code == "200"
      data = JSON.parse(response.body)
      return data["did"]
    end

    nil
  rescue => e
    Rails.logger.warn "Handle to DID resolution failed: #{e.message}"
    nil
  end

  def self.resolve_did_to_pds(did)
    # Fetch DID document
    uri = URI("https://plc.directory/#{did}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 5

    response = http.get(uri.path)
    return nil unless response.code == "200"

    did_doc = JSON.parse(response.body)

    # Extract PDS endpoint from service array
    services = did_doc["service"] || []
    pds_service = services.find { |s| s["id"] == "#atproto_pds" }

    pds_service&.dig("serviceEndpoint")
  rescue => e
    Rails.logger.warn "DID to PDS resolution failed: #{e.message}"
    nil
  end

  def self.get_profile(did)
    uri = URI("https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile")
    uri.query = URI.encode_www_form(actor: did)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 5

    response = http.get(uri)
    return nil unless response.code == "200"

    JSON.parse(response.body)
  rescue => e
    Rails.logger.warn "Profile fetch failed: #{e.message}"
    nil
  end

  def self.get_email(access_token, pds_endpoint)
    require "jwt"
    require "securerandom"
    require_relative "../../lib/omniauth/atproto/key_manager"

    require "digest"
    require "base64"

    endpoint = "#{pds_endpoint}/xrpc/com.atproto.server.getSession"
    uri = URI(endpoint)

    # Generate DPoP Proof
    private_key = OmniAuth::Atproto::KeyManager.current_private_key
    jwk = OmniAuth::Atproto::KeyManager.current_jwk

    # Calculate ath (Access Token Hash)
    # SHA-256 hash of the access token, base64url encoded
    ath = Base64.urlsafe_encode64(Digest::SHA256.digest(access_token), padding: false)

    # DPoP Header
    headers = {
      typ: "dpop+jwt",
      alg: "ES256",
      jwk: jwk
    }

    # DPoP Payload
    # Helper to generate DPoP proof
    generate_proof = ->(nonce = nil) {
      payload = {
        jti: SecureRandom.uuid,
        htm: "GET",
        htu: endpoint,
        iat: Time.now.to_i,
        exp: Time.now.to_i + 60,
        ath: ath
      }
      payload[:nonce] = nonce if nonce

      JWT.encode(payload, private_key, "ES256", headers)
    }

    # First attempt
    dpop_proof = generate_proof.call
    
    # Make Request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "DPoP #{access_token}"
    request["DPoP"] = dpop_proof
    request["Accept"] = "application/json"

    response = http.request(request)
    
    # Handle DPoP Nonce requirement (retry with nonce)
    if response.code == "401" && response["DPoP-Nonce"].present?
      nonce = response["DPoP-Nonce"]
      Rails.logger.info "🔄 Retrying with DPoP Nonce: #{nonce}"
      
      dpop_proof = generate_proof.call(nonce)
      
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "DPoP #{access_token}"
      request["DPoP"] = dpop_proof
      request["Accept"] = "application/json"
      
      response = http.request(request)
    end

    if response.code == "200"
      data = JSON.parse(response.body)
      return data["email"]
    else
      Rails.logger.warn "Email fetch failed: #{response.code} #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "Email fetch error: #{e.message}"
    nil
  end
end
