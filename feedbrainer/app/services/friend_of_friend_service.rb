class FriendOfFriendService
  def self.compute_for_user(user)
    new(user).compute
  end

  def initialize(user)
    @user = user
  end

  def compute
    Rails.logger.info("Computing friend-of-friend sources for user #{@user.id}")
    
    # Find all users that this user directly follows
    # Note: We need to find users (not sources) that this user follows
    # Since user_sources links users to sources, we need to find:
    # 1. All sources this user directly follows
    # 2. For each source, find all users who also follow that source
    # 3. For each of those users, get their direct_follow sources
    # 4. Those sources become friend_of_friend for this user
    
    # Actually, wait - we need to think about this differently.
    # The user follows sources directly. To find "friends" (users this user follows),
    # we need a user-to-user relationship. But we don't have that.
    
    # Let me reconsider: The user wants sources that are followed by users
    # that the current user follows. But "follows" here means follows sources.
    # So: User A follows Source X. User B also follows Source X. 
    # User A and User B are "friends" (they follow the same sources).
    # User B follows Source Y. Source Y becomes a friend_of_friend source for User A.
    
    # So the logic is:
    # 1. Find all sources this user directly follows
    # 2. For each source, find all other users who also follow that source (these are "friends")
    # 3. For each friend user, get their direct_follow sources
    # 4. Those sources become friend_of_friend for this user
    
    direct_follow_sources = @user.direct_follow_sources
    
    if direct_follow_sources.empty?
      Rails.logger.info("User #{@user.id} has no direct follows, skipping friend-of-friend computation")
      return
    end
    
    # Find all users who follow the same sources (friends)
    friend_user_ids = UserSource.where(source_id: direct_follow_sources.pluck(:id))
                                 .where(relationship_type: :direct_follow)
                                 .where.not(user_id: @user.id)
                                 .distinct
                                 .pluck(:user_id)
    
    if friend_user_ids.empty?
      Rails.logger.info("User #{@user.id} has no friends (users following same sources), skipping friend-of-friend computation")
      cleanup_invalid_friend_of_friend
      return
    end
    
    # Get all sources that friends directly follow
    friend_sources = Source.joins(:user_sources)
                          .where(user_sources: { user_id: friend_user_ids, relationship_type: :direct_follow })
                          .distinct
    
    # Get sources this user already directly follows (to avoid duplicates)
    existing_direct_follow_source_ids = direct_follow_sources.pluck(:id)
    
    # Get sources that should be friend_of_friend (not already direct follows)
    new_friend_of_friend_sources = friend_sources.where.not(id: existing_direct_follow_source_ids)
    
    # Get current friend_of_friend sources
    current_friend_of_friend_source_ids = @user.friend_of_friend_sources.pluck(:id)
    
    # Sources to add
    sources_to_add = new_friend_of_friend_sources.where.not(id: current_friend_of_friend_source_ids)
    
    # Sources to remove (no longer valid)
    sources_to_remove_ids = current_friend_of_friend_source_ids - new_friend_of_friend_sources.pluck(:id)
    
    # Add new friend_of_friend relationships
    sources_to_add.find_each do |source|
      UserSource.create!(
        user: @user,
        source: source,
        relationship_type: :friend_of_friend
      )
      Rails.logger.debug("Added friend_of_friend relationship: user #{@user.id} -> source #{source.id}")
    end
    
    # Remove invalid friend_of_friend relationships
    if sources_to_remove_ids.any?
      UserSource.where(user: @user, source_id: sources_to_remove_ids, relationship_type: :friend_of_friend).destroy_all
      Rails.logger.info("Removed #{sources_to_remove_ids.length} invalid friend_of_friend relationships for user #{@user.id}")
    end
    
    Rails.logger.info("Friend-of-friend computation complete for user #{@user.id}: added #{sources_to_add.count}, removed #{sources_to_remove_ids.length}")
  rescue => e
    Rails.logger.error("Error computing friend-of-friend for user #{@user.id}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    raise
  end

  private

  def cleanup_invalid_friend_of_friend
    # If user has no friends, remove all friend_of_friend relationships
    UserSource.where(user: @user, relationship_type: :friend_of_friend).destroy_all
  end
end

