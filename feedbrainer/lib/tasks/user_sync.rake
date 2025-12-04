namespace :user_sync do
  desc "Sync new followers of open.news user"
  task new_followers: :environment do
    open_news_did = ENV["ATPROTO_DID"]
    
    if open_news_did.blank?
      puts "ERROR: ATPROTO_DID environment variable is not set"
      exit 1
    end

    puts "Syncing new followers for DID: #{open_news_did}"
    count = UserSyncService.sync_new_followers(open_news_did)
    puts "Sync complete. New users created: #{count}"
  end

  desc "Sync follows for all users"
  task all_follows: :environment do
    puts "Syncing follows for all users..."
    result = UserSyncService.sync_all_users_follows
    puts "Sync complete. Processed #{result[:processed]}/#{result[:total]} users"
  end

  desc "Sync follows for a specific user"
  task :user, [:user_id] => :environment do |_t, args|
    user_id = args[:user_id]
    
    if user_id.blank?
      puts "ERROR: Please provide a user_id: rake user_sync:user[123]"
      exit 1
    end

    user = User.find_by(id: user_id)
    
    unless user
      puts "ERROR: User with ID #{user_id} not found"
      exit 1
    end

    puts "Syncing follows for user #{user_id} (DID: #{user.atproto_did})"
    result = UserSyncService.sync_user_follows(user)
    puts "Sync complete. Added: #{result[:added]}, Removed: #{result[:removed]}, Total: #{result[:total]}"
  end

  desc "Compute friend-of-friend relationships for all users"
  task compute_friend_of_friend: :environment do
    users = User.where.not(atproto_did: nil)
    total = users.count
    processed = 0
    errors = 0

    puts "Computing friend-of-friend relationships for #{total} users..."
    
    users.find_each do |user|
      begin
        FriendOfFriendService.compute_for_user(user)
        processed += 1
        puts "Processed user #{user.id} (#{processed}/#{total})" if processed % 10 == 0
      rescue => e
        errors += 1
        puts "Error processing user #{user.id}: #{e.message}"
      end
    end

    puts "Complete. Processed: #{processed}, Errors: #{errors}"
  end

  desc "Compute friend-of-friend relationships for a specific user"
  task :compute_friend_of_friend_for_user, [:user_id] => :environment do |_t, args|
    user_id = args[:user_id]
    
    if user_id.blank?
      puts "ERROR: Please provide a user_id: rake user_sync:compute_friend_of_friend_for_user[123]"
      exit 1
    end

    user = User.find_by(id: user_id)
    
    unless user
      puts "ERROR: User with ID #{user_id} not found"
      exit 1
    end

    FriendOfFriendService.compute_for_user(user)
    puts "Friend-of-friend computation complete for user #{user.id}"
    puts "  Direct follows: #{user.reload.direct_follow_sources.count}"
    puts "  Friend of friend: #{user.friend_of_friend_sources.count}"
  end
end

