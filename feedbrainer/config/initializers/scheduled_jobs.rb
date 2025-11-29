# Schedule periodic jobs on application start
# This ensures the jobs run even after server restarts

Rails.application.config.after_initialize do
  # Only schedule if we're not in a rake task or console
  next if defined?(Rails::Console) || File.basename($0) == "rake"

  # Use a simple flag to avoid scheduling duplicates on multiple workers
  # The jobs themselves handle rescheduling, so this just ensures they start
  begin
    # Schedule new followers sync job (runs every 15 minutes)
    # Start after 1 minute to allow app to fully initialize
    SyncNewFollowersJob.set(wait: 1.minute).perform_later
    Rails.logger.info("Scheduled initial SyncNewFollowersJob (will run in 1 minute)")

    # Schedule all users follows sync job (runs daily)
    # Start after 1 hour to allow initial setup
    SyncAllUsersFollowsJob.set(wait: 1.hour).perform_later
    Rails.logger.info("Scheduled initial SyncAllUsersFollowsJob (will run in 1 hour)")
  rescue => e
    Rails.logger.error("Error scheduling jobs: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end
end

