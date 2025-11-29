require "json"

class NewsDetectionService
  def self.call(html_content, url)
    new(html_content, url).call
  end

  def initialize(html_content, url)
    @html_content = html_content
    @url = url
    @jsonld_data = extract_jsonld
  end

  def call
    return { is_news_article: false } unless news_article?

    {
      is_news_article: true,
      jsonld_data: @jsonld_data,
      title: extract_title,
      published_at: extract_published_at,
      author: extract_author,
      description: extract_description,
      image_url: extract_image_url,
      body_text: extract_body_text
    }
  end

  def news_article?
    return false if @jsonld_data.nil? || @jsonld_data.empty?
    
    # Check if any JSON-LD item has @type of "NewsArticle"
    @jsonld_data.each do |item|
      if item.is_a?(Hash)
        type = item["@type"] || item[:@type]
        if type == "NewsArticle" || type == "https://schema.org/NewsArticle"
          return true
        end
      end
    end
    
    false
  end

  private

  def extract_jsonld
    # Extract all JSON-LD scripts from HTML
    jsonld_scripts = @html_content.scan(/<script[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/mi)
    
    jsonld_data = []
    jsonld_scripts.each do |script_content|
      begin
        # Clean up the script content (remove CDATA, whitespace)
        cleaned = script_content[0].gsub(/<!\[CDATA\[/, "").gsub(/\]\]>/, "").strip
        parsed = JSON.parse(cleaned)
        # Handle both single objects and arrays
        if parsed.is_a?(Array)
          jsonld_data.concat(parsed)
        elsif parsed.is_a?(Hash) && parsed["@graph"].is_a?(Array)
          jsonld_data.concat(parsed["@graph"])
        else
          jsonld_data << parsed
        end
      rescue JSON::ParserError => e
        Rails.logger.warn("Failed to parse JSON-LD: #{e.message}")
      end
    end
    
    jsonld_data
  end

  def extract_title
    # Try to extract title from JSON-LD NewsArticle first
    @jsonld_data.each do |item|
      if item["@type"] == "NewsArticle" && item["headline"]
        return item["headline"]
      end
    end
    
    # Fall back to HTML title tag
    title_match = @html_content.match(/<title[^>]*>(.*?)<\/title>/mi)
    return title_match[1].strip if title_match
    
    # Try og:title
    og_title_match = @html_content.match(/<meta[^>]*property=["']og:title["'][^>]*content=["']([^"']+)["']/i)
    return og_title_match[1].strip if og_title_match
    
    nil
  end

  def extract_published_at
    # Look for datePublished in NewsArticle schema
    @jsonld_data.each do |item|
      if item["@type"] == "NewsArticle" && item["datePublished"]
        return Time.parse(item["datePublished"]) rescue nil
      end
    end
    nil
  end

  def extract_author
    # Look for author in NewsArticle schema
    @jsonld_data.each do |item|
      if item["@type"] == "NewsArticle" && item["author"]
        author = item["author"]
        if author.is_a?(Hash)
          return author["name"] || author["@value"]
        elsif author.is_a?(String)
          return author
        elsif author.is_a?(Array) && author.first
          author_obj = author.first
          return author_obj["name"] || author_obj["@value"] if author_obj.is_a?(Hash)
        end
      end
    end
    nil
  end

  def extract_description
    # Look for description in NewsArticle schema
    @jsonld_data.each do |item|
      if item["@type"] == "NewsArticle" && item["description"]
        return item["description"]
      end
    end
    nil
  end

  def extract_image_url
    # Look for image in NewsArticle schema
    @jsonld_data.each do |item|
      if item["@type"] == "NewsArticle" && item["image"]
        image = item["image"]
        if image.is_a?(Hash)
          return image["url"] || image["@value"]
        elsif image.is_a?(String)
          return image
        elsif image.is_a?(Array) && image.first
          img_obj = image.first
          if img_obj.is_a?(Hash)
            return img_obj["url"] || img_obj["@value"]
          elsif img_obj.is_a?(String)
            return img_obj
          end
        end
      end
    end
    nil
  end

  def extract_body_text
    # Basic extraction - remove scripts, styles, and get main content
    # This is a simple implementation; you might want to use a gem like Nokogiri
    cleaned = @html_content.gsub(/<script[^>]*>.*?<\/script>/mi, "")
                           .gsub(/<style[^>]*>.*?<\/style>/mi, "")
                           .gsub(/<[^>]+>/, " ")
                           .gsub(/\s+/, " ")
                           .strip
    
    # Limit to reasonable length
    cleaned[0, 50000]
  end
end

