namespace :sources do
  desc "Backfill missing source profiles"
  task backfill_profiles: :environment do
    sources_without_profiles = Source.where(profile: {})
    total = sources_without_profiles.count
    
    puts "Found #{total} sources without profiles"
    
    if total == 0
      puts "All sources have profiles!"
      next
    end
    
    puts "Enqueuing profile sync jobs..."
    
    sources_without_profiles.find_each.with_index do |source, index|
      SyncSourceProfileJob.perform_later(source.id)
      
      if (index + 1) % 100 == 0
        puts "Enqueued #{index + 1}/#{total} jobs..."
      end
    end
    
    puts "Finished enqueuing #{total} profile sync jobs"
    puts "Jobs will be processed by Sidekiq workers"
  end
  
  desc "Show profile statistics"
  task profile_stats: :environment do
    total = Source.count
    with_profile = Source.where.not(profile: {}).count
    without_profile = Source.where(profile: {}).count
    
    puts "=== Source Profile Statistics ==="
    puts "Total sources: #{total}"
    puts "With profiles: #{with_profile} (#{(with_profile.to_f / total * 100).round(2)}%)"
    puts "Without profiles: #{without_profile} (#{(without_profile.to_f / total * 100).round(2)}%)"
    
    if without_profile > 0
      puts "\nRun 'rake sources:backfill_profiles' to sync missing profiles"
    end
  end
end
