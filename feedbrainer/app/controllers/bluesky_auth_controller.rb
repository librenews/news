class BlueskyAuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:callback]

  def start
    handle = params[:handle].to_s.strip

    if handle.blank?
      redirect_to root_path, alert: "Please enter your Bluesky handle (e.g., username.bsky.social)"
      return
    end

    # Remove @ if present
    handle = handle.gsub(/^@/, "")

    Rails.logger.info "🔍 Resolving Bluesky handle: #{handle}"

    # Resolve handle to DID and PDS endpoint
    resolution_result = BlueskyIdentityService.resolve_handle(handle)

    unless resolution_result[:did] && resolution_result[:pds_endpoint]
      redirect_to root_path, alert: "Failed to resolve handle: #{resolution_result[:error] || 'Unknown error'}"
      return
    end

    # Store in session for callback and OmniAuth setup
    session[:bluesky_handle] = handle
    session[:bluesky_did] = resolution_result[:did]
    session[:bluesky_pds_endpoint] = resolution_result[:pds_endpoint]

    Rails.logger.info "✅ Resolved handle #{handle} to DID #{resolution_result[:did]} with PDS #{resolution_result[:pds_endpoint]}"

    # Redirect to OmniAuth with PDS endpoint in session
    redirect_to "/auth/atproto", allow_other_host: false
  end

  def callback
    auth_hash = request.env["omniauth.auth"]

    unless auth_hash
      redirect_to root_path, alert: "Bluesky authentication failed."
      return
    end

    did = auth_hash.dig("info", "did")
    unless did
      redirect_to root_path, alert: "Could not retrieve Bluesky account information."
      return
    end

    # Extract OAuth credentials
    credentials = auth_hash["credentials"] || {}
    oauth_credentials = {
      access_token: credentials["token"],
      refresh_token: credentials["refresh_token"],
      expires_at: credentials["expires_at"] ? Time.at(credentials["expires_at"]) : nil,
      scope: credentials["scope"]
    }

    # Extract email from auth hash (from transition:email scope)
    email = auth_hash.dig("info", "email")
    
    # Debug logging
    Rails.logger.info "🔍 Auth Hash Info: #{auth_hash['info'].inspect}"
    Rails.logger.info "🔍 Auth Hash Extra: #{auth_hash['extra'].inspect}"

    # Find or create user
    user = User.find_by(atproto_did: did)
    
    if user.nil?
      user = User.new(atproto_did: did)
      user.email = email if email.present?
      user.save!(validate: false)  # Skip validations for OAuth-only users
    end

    # Create or update identity
    identity = user.identities.find_or_initialize_by(provider: "bluesky", uid: did)
    identity.access_token = oauth_credentials[:access_token]
    identity.refresh_token = oauth_credentials[:refresh_token]
    identity.expires_at = oauth_credentials[:expires_at]
    identity.scope = oauth_credentials[:scope]
    identity.raw_info = auth_hash["info"]
    identity.save!

    # Fetch profile if missing from auth_hash
    handle = auth_hash.dig("info", "handle")
    display_name = auth_hash.dig("info", "name")
    avatar_url = auth_hash.dig("info", "image")

    if handle.blank?
      Rails.logger.info "⚠️ Profile info missing in auth_hash, fetching manually..."
      profile = BlueskyIdentityService.get_profile(did)
      if profile
        handle = profile["handle"]
        display_name = profile["displayName"]
        avatar_url = profile["avatar"]
      end
    end

    # Fetch email if missing (requires DPoP signed request)
    if email.blank?
      Rails.logger.info "⚠️ Email missing in auth_hash, fetching from session..."
      # Use PDS endpoint from session or default
      pds_endpoint = session[:bluesky_pds_endpoint] || "https://bsky.social"
      email = BlueskyIdentityService.get_email(oauth_credentials[:access_token], pds_endpoint)
      Rails.logger.info "📧 Fetched email: #{email}" if email.present?
    end

    # Update user with Bluesky profile info
    user.update!(
      email: email || user.email,  # Update email if provided
      bluesky_handle: handle,
      bluesky_display_name: display_name,
      bluesky_avatar_url: avatar_url,
      bluesky_connected_at: Time.current
    )

    # Set session
    session[:user_id] = user.id

    Rails.logger.info "✅ User #{user.id} authenticated via Bluesky OAuth"
    Rails.logger.info "   Email: #{user.email}" if user.email.present?
    Rails.logger.info "   Handle: #{user.bluesky_handle}"

    redirect_to root_path, notice: "Successfully connected to Bluesky!"
  end

  def failure
    error_message = params[:message] || "Authentication failed"
    redirect_to root_path, alert: "Bluesky connection failed: #{error_message}"
  end

  def client_metadata
    # Generate client metadata JSON for OAuth registration
    scheme = request.ssl? ? "https" : "http"

    # For tunnel connections, use standard port (no port in URL)
    if request.ssl? && request.port != 443
      app_url = "#{scheme}://#{request.host}"
    else
      app_url = "#{scheme}://#{request.host_with_port}"
    end

    client_id = "#{app_url}/oauth/client-metadata.json"

    client_metadata = {
      client_id: client_id,
      application_type: "web",
      client_name: "FeedBrainer News",
      client_uri: app_url,
      dpop_bound_access_tokens: true,
      grant_types: [
        "authorization_code",
        "refresh_token"
      ],
      redirect_uris: [
        "#{app_url}/auth/atproto/callback"
      ],
      response_types: [
        "code"
      ],
      scope: "atproto transition:email",
      token_endpoint_auth_method: "private_key_jwt",
      token_endpoint_auth_signing_alg: "ES256",
      jwks: {
        keys: [ OmniAuth::Atproto::KeyManager.current_jwk ]
      }
    }

    render json: client_metadata
  end
end
