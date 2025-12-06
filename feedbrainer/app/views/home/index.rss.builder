xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "LibreNews - Top News Articles"
    xml.description "Trending news articles from the Bluesky network, ranked by engagement"
    xml.link root_url
    xml.tag! "atom:link", href: root_url(format: :rss), rel: "self", type: "application/rss+xml"
    xml.language "en"
    xml.lastBuildDate Time.now.rfc822

    @articles.each do |article|
      xml.item do
        xml.title article.title
        xml.description article.description || article.title
        xml.link article.url
        xml.guid article.url, isPermaLink: "true"
        xml.pubDate article.published_at&.rfc822 || article.created_at.rfc822
        xml.author article.author if article.author.present?
        
        # Add share count as custom element
        xml.tag! "shareCount", article.attributes["share_count"]
        
        # Add image if available
        if article.image_url.present?
          xml.enclosure url: article.image_url, type: "image/jpeg"
        end
        
        # Add source information
        if article.posts.any?
          first_post = article.posts.first
          if first_post.source
            xml.tag! "source" do
              xml.tag! "name", first_post.source.display_name
              xml.tag! "handle", first_post.source.handle
              xml.tag! "url", "https://bsky.app/profile/#{first_post.source.handle}"
            end
          end
        end
      end
    end
  end
end
