class SyncAllUsersFollowsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting SyncAllUsersFollowsJob")
    result = UserSyncService.sync_all_users_follows
    Rails.logger.info("SyncAllUsersFollowsJob complete: #{result[:processed]}/#{result[:total]} users processed")

    # Schedule next run in 24 hours (daily)
    SyncAllUsersFollowsJob.set(wait: 24.hours).perform_later
    Rails.logger.info("Scheduled next SyncAllUsersFollowsJob in 24 hours")
  rescue => e
    Rails.logger.error("Error in SyncAllUsersFollowsJob: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Still schedule next run even on error
    SyncAllUsersFollowsJob.set(wait: 24.hours).perform_later
  end
end

