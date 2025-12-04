class UserSyncService
  def self.sync_new_followers(open_news_did)
    new.sync_new_followers(open_news_did)
  end

  def self.sync_user_follows(user)
    new.sync_user_follows(user)
  end

  def self.sync_all_users_follows
    new.sync_all_users_follows
  end

  def sync_new_followers(open_news_did)
    Rails.logger.info("Starting sync of new followers for DID: #{open_news_did}")
    new_users_count = 0
    cursor = nil

    loop do
      result = SkytorchClient.get_followers(open_news_did, limit: 100, cursor: cursor)

      unless result[:success]
        Rails.logger.error("Failed to fetch followers: #{result[:error]}")
        break
      end

      followers = result[:data] || []
      break if followers.empty?

      # Create new users for DIDs not in database
      followers.each do |follower|
        did = follower["did"]
        next if did.blank?

        user = User.find_by(atproto_did: did)
        
        if user.nil?
          # User doesn't exist, create it
          profile_data = extract_profile_from_follower(follower)
          user = User.create!(atproto_did: did, profile: profile_data)
          Rails.logger.info("Created new user with DID: #{did}")
          new_users_count += 1
          # The after_create callback will enqueue SyncUserFollowsJob
        else
          # Update profile if we have new data
          profile_data = extract_profile_from_follower(follower)
          if profile_data.present?
            user.update(profile: profile_data)
          end
        end
      end

      cursor = result[:cursor]
      break if cursor.nil? || cursor.empty?
    end

    Rails.logger.info("Sync complete. New users created: #{new_users_count}")
    new_users_count
  rescue => e
    Rails.logger.error("Error syncing new followers: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    0
  end

  def sync_user_follows(user)
    return unless user&.atproto_did.present?

    Rails.logger.info("Starting sync of follows for user #{user.id} (DID: #{user.atproto_did})")
    
    # Fetch all follows with pagination
    all_follows = []
    cursor = nil

    loop do
      result = SkytorchClient.get_follows(user.atproto_did, limit: 100, cursor: cursor)

      unless result[:success]
        Rails.logger.error("Failed to fetch follows for user #{user.id}: #{result[:error]}")
        break
      end

      follows = result[:data] || []
      break if follows.empty?

      all_follows.concat(follows)

      cursor = result[:cursor]
      break if cursor.nil? || cursor.empty?
    end

    Rails.logger.info("Fetched #{all_follows.length} follows for user #{user.id}")

    # Update user's own profile if we have it from the API response
    # (The get_follows call might include the user's profile in the response)
    # Otherwise, fetch it if missing
    if user.profile.blank? || user.profile.empty?
      fetch_and_store_profile(user, user.atproto_did)
    end

    # Get current UserSources for this user
    current_source_dids = user.sources.pluck(:atproto_did).compact.to_set
    new_follow_dids = all_follows.map { |f| f["did"] }.compact.to_set

    # Find sources to add and remove
    sources_to_add = new_follow_dids - current_source_dids
    sources_to_remove = current_source_dids - new_follow_dids

    # Create Sources for new follows and update profiles
    sources_to_add.each do |did|
      # Find the follow data to extract profile info
      follow_data = all_follows.find { |f| f["did"] == did }
      
      # Check if source already exists
      source = Source.find_by(atproto_did: did)
      was_new = source.nil?
      
      if source.nil?
        # Create new source with profile data
        profile_data = follow_data ? extract_profile_from_follow(follow_data) : {}
        source = Source.create!(atproto_did: did, profile: profile_data)
      else
        # Update existing source's profile if we have new data
        if follow_data
          profile_data = extract_profile_from_follow(follow_data)
          if profile_data.present?
            source.update(profile: profile_data)
          end
        end
      end
      
      UserSource.find_or_create_by(user: user, source: source, relationship_type: :direct_follow)
      Rails.logger.debug("Added follow: #{did}")
    end

    # Remove UserSources for unfollowed accounts
    if sources_to_remove.any?
      sources_to_remove_ids = Source.where(atproto_did: sources_to_remove.to_a).pluck(:id)
      user.user_sources.where(source_id: sources_to_remove_ids).destroy_all
      Rails.logger.info("Removed #{sources_to_remove.length} unfollowed sources for user #{user.id}")
    end

    Rails.logger.info("Sync complete for user #{user.id}. Added: #{sources_to_add.length}, Removed: #{sources_to_remove.length}")
    
    # Compute friend-of-friend relationships after syncing direct follows
    FriendOfFriendService.compute_for_user(user)
    
    {
      added: sources_to_add.length,
      removed: sources_to_remove.length,
      total: all_follows.length
    }
  rescue => e
    Rails.logger.error("Error syncing follows for user #{user.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    { added: 0, removed: 0, total: 0 }
  end

  def sync_all_users_follows
    Rails.logger.info("Starting sync of follows for all users")
    users = User.where.not(atproto_did: nil)
    total = users.count
    enqueued = 0

    users.find_each do |user|
      begin
        # Enqueue individual jobs for each user to process in parallel
        SyncUserFollowsJob.perform_later(user.id)
        enqueued += 1
      rescue => e
        Rails.logger.error("Error enqueueing job for user #{user.id}: #{e.message}")
      end
    end

    Rails.logger.info("Enqueued #{enqueued}/#{total} user sync jobs")
    { processed: enqueued, total: total }
  rescue => e
    Rails.logger.error("Error in sync_all_users_follows: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    { processed: 0, total: 0 }
  end

  private

  def extract_profile_from_follower(follower)
    return {} unless follower.is_a?(Hash)
    
    {
      "did" => follower["did"],
      "handle" => follower["handle"],
      "display_name" => follower["display_name"],
      "avatar" => follower["avatar"]
    }.compact
  end

  def extract_profile_from_follow(follow)
    return {} unless follow.is_a?(Hash)
    
    {
      "did" => follow["did"],
      "handle" => follow["handle"],
      "display_name" => follow["display_name"],
      "avatar" => follow["avatar"]
    }.compact
  end

  def fetch_and_store_profile(record, did)
    return unless did.present?

    result = SkytorchClient.get_profile(did)
    if result[:success] && result[:profile]
      record.update(profile: result[:profile])
      Rails.logger.debug("Fetched and stored profile for #{record.class.name} #{record.id}")
    else
      Rails.logger.warn("Failed to fetch profile for #{did}: #{result[:error]}")
    end
  rescue => e
    Rails.logger.error("Error fetching profile for #{did}: #{e.message}")
  end
end

