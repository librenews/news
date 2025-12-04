class SyncUserFollowsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    
    unless user
      Rails.logger.warn("User with ID #{user_id} not found")
      return
    end

    unless user.atproto_did.present?
      Rails.logger.warn("User #{user_id} has no atproto_did, skipping sync")
      return
    end

    Rails.logger.info("Starting SyncUserFollowsJob for user #{user_id}")
    UserSyncService.sync_user_follows(user)
  rescue => e
    Rails.logger.error("Error in SyncUserFollowsJob for user #{user_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end
end

