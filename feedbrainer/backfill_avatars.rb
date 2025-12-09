# Find sources with missing or empty profiles
sources = Source.where("profile IS NULL OR profile::text = '{}' OR profile::text = 'null'")
puts "Found #{sources.count} sources with missing profiles."

sources.find_each do |source|
  puts "Enqueueing SyncSourceProfileJob for source #{source.id} (#{source.atproto_did})"
  SyncSourceProfileJob.perform_later(source.id)
end

puts "Enqueued jobs for all missing profiles."
