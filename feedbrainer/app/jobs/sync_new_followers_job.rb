class SyncNewFollowersJob < ApplicationJob
  queue_as :default

  def perform
    open_news_did = ENV["ATPROTO_DID"]
    
    if open_news_did.blank?
      Rails.logger.error("ATPROTO_DID environment variable is not set")
      return
    end

    Rails.logger.info("Starting SyncNewFollowersJob for DID: #{open_news_did}")
    UserSyncService.sync_new_followers(open_news_did)

    # Schedule next run in 15 minutes
    SyncNewFollowersJob.set(wait: 15.minutes).perform_later
    Rails.logger.info("Scheduled next SyncNewFollowersJob in 15 minutes")
  rescue => e
    Rails.logger.error("Error in SyncNewFollowersJob: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Still schedule next run even on error
    SyncNewFollowersJob.set(wait: 15.minutes).perform_later
  end
end

