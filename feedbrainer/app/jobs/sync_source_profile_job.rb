class SyncSourceProfileJob < ApplicationJob
  queue_as :default
  
  # Retry on failures with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(source_id)
    source = Source.find_by(id: source_id)
    unless source
      Rails.logger.warn("SyncSourceProfileJob: Source #{source_id} not found")
      return
    end

    # Skip if profile already exists and is not empty
    if source.profile.present? && source.profile != {}
      Rails.logger.debug("SyncSourceProfileJob: Profile already exists for #{source.atproto_did}")
      return
    end

    # Use DID as the actor identifier
    # Use SkytorchClient which handles auth and rate limits better than direct public API
    result = SkytorchClient.get_profile(source.atproto_did)

    if result[:success]
      # Only update if we got actual profile data
      if result[:profile].present?
        source.update!(profile: result[:profile])
        Rails.logger.info("SyncSourceProfileJob: Updated profile for #{source.atproto_did} (handle: #{result[:profile]['handle']})")
      else
        Rails.logger.warn("SyncSourceProfileJob: Empty profile returned for #{source.atproto_did}")
      end
    else
      error_msg = result[:error] || "Unknown error"
      Rails.logger.error("SyncSourceProfileJob: Failed to fetch profile for #{source.atproto_did}: #{error_msg}")
      # Re-raise to trigger retry
      raise "Failed to fetch profile: #{error_msg}"
    end
  end
end
