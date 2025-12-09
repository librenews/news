class BackfillMissingProfilesJob < ApplicationJob
  queue_as :default

  def perform
    # Find sources with missing or empty profiles
    # Limit to 100 to avoid overloading the queue/server
    sources = Source.where("profile IS NULL OR profile::text = '{}' OR profile::text = 'null'")
                    .limit(100)
    
    if sources.any?
      Rails.logger.info("BackfillMissingProfilesJob: Found #{sources.count} sources with missing profiles. Enqueueing sync jobs.")
      
      sources.each do |source|
        SyncSourceProfileJob.perform_later(source.id)
      end
    else
      Rails.logger.info("BackfillMissingProfilesJob: No missing profiles found.")
    end

    # Reschedule to run again in 1 hour
    # This ensures continuous self-correction
    self.class.set(wait: 1.hour).perform_later
  end
end
