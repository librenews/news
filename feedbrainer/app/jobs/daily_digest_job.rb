class DailyDigestJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting DailyDigestJob..."
    
    count = 0
    User.where.not(email: nil).find_each do |user|
      begin
        DigestMailer.daily_digest(user).deliver_now
        count += 1
      rescue => e
        Rails.logger.error "Failed to send digest to user #{user.id}: #{e.message}"
      end
    end

    Rails.logger.info "DailyDigestJob complete. Sent #{count} emails."
  end
end
