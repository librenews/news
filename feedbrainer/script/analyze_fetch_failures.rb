#!/usr/bin/env ruby
# Analyze ProcessPostJob fetch failures by domain and error type

require 'uri'

failures = []
error_types = Hash.new(0)
domains = Hash.new(0)
domain_errors = Hash.new { |h, k| h[k] = Hash.new(0) }

# Read all log files
Dir.glob('feedbrainer/log/*.log*').each do |log_file|
  next unless File.file?(log_file)
  
  File.readlines(log_file).each do |line|
    if line.match(/ProcessPostJob: Failed to fetch/)
      # Extract URL and error
      if match = line.match(/Failed to fetch (https?:\/\/[^\s]+): (.+)$/)
        url = match[1]
        error = match[2].strip
        
        begin
          domain = URI.parse(url).host
          domain = domain.gsub(/^www\./, '') if domain
          
          failures << { url: url, domain: domain, error: error }
          error_types[error] += 1
          domains[domain] += 1 if domain
          domain_errors[domain][error] += 1 if domain
        rescue URI::InvalidURIError
          # Skip invalid URLs
        end
      end
    end
  end
end

puts "=" * 80
puts "FETCH FAILURE ANALYSIS"
puts "=" * 80
puts "\nTotal failures: #{failures.count}\n\n"

puts "ERROR TYPES (by frequency):"
puts "-" * 80
error_types.sort_by { |_, count| -count }.each do |error, count|
  puts "  #{count.to_s.rjust(4)}  #{error}"
end

puts "\n\nDOMAINS (by failure count):"
puts "-" * 80
domains.sort_by { |_, count| -count }.first(20).each do |domain, count|
  puts "  #{count.to_s.rjust(4)}  #{domain}"
end

puts "\n\nDOMAIN + ERROR BREAKDOWN:"
puts "-" * 80
domain_errors.sort_by { |domain, _| -domains[domain] }.first(10).each do |domain, errors|
  puts "\n#{domain} (#{domains[domain]} total failures):"
  errors.sort_by { |_, count| -count }.each do |error, count|
    puts "  #{count.to_s.rjust(4)}  #{error}"
  end
end

puts "\n\nSAMPLE FAILED URLS:"
puts "-" * 80
failures.first(10).each do |failure|
  puts "  #{failure[:domain]}: #{failure[:error]}"
  puts "    #{failure[:url]}"
end

