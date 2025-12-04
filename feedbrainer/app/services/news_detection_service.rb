require "json"
require "cgi"

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
        return decode_html_entities(item["headline"])
      end
    end
    
    # Fall back to HTML title tag
    title_match = @html_content.match(/<title[^>]*>(.*?)<\/title>/mi)
    if title_match
      return decode_html_entities(title_match[1].strip)
    end
    
    # Try og:title
    og_title_match = @html_content.match(/<meta[^>]*property=["']og:title["'][^>]*content=["']([^"']+)["']/i)
    if og_title_match
      return decode_html_entities(og_title_match[1].strip)
    end
    
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
        author_name = nil
        if author.is_a?(Hash)
          author_name = author["name"] || author["@value"]
        elsif author.is_a?(String)
          author_name = author
        elsif author.is_a?(Array) && author.first
          author_obj = author.first
          author_name = author_obj["name"] || author_obj["@value"] if author_obj.is_a?(Hash)
        end
        return decode_html_entities(author_name) if author_name
      end
    end
    nil
  end

  def extract_description
    # Look for description in NewsArticle schema
    @jsonld_data.each do |item|
      if item["@type"] == "NewsArticle" && item["description"]
        return decode_html_entities(item["description"])
      end
    end

    # Fallback: Try og:description
    og_description_match = @html_content.match(/<meta[^>]*property=["']og:description["'][^>]*content=["']([^"']+)["']/i)
    if og_description_match
      return decode_html_entities(og_description_match[1].strip)
    end

    # Fallback: Try standard description meta tag
    description_match = @html_content.match(/<meta[^>]*name=["']description["'][^>]*content=["']([^"']+)["']/i)
    if description_match
      return decode_html_entities(description_match[1].strip)
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
    # Note: We preserve paragraph structure (newlines) for chunking purposes
    cleaned = @html_content.gsub(/<script[^>]*>.*?<\/script>/mi, "")
                           .gsub(/<style[^>]*>.*?<\/style>/mi, "")
    
    # Convert block elements to newlines to preserve paragraph structure
    cleaned = cleaned.gsub(/<\/?(p|div|h[1-6]|article|section|li|br)[^>]*>/i, "\n")
    
    # Remove all remaining HTML tags
    cleaned = cleaned.gsub(/<[^>]+>/, " ")
    
    # Decode HTML entities (but preserve newlines for paragraph detection)
    cleaned = CGI.unescapeHTML(cleaned)
    
    # Normalize whitespace: collapse multiple spaces/tabs but preserve newlines
    # Collapse 3+ newlines to double newline (paragraph break)
    cleaned = cleaned.gsub(/\n{3,}/, "\n\n")
                     .gsub(/[ \t]+/, " ")  # Collapse spaces/tabs but keep newlines
                     .gsub(/[ \t]*\n[ \t]*/, "\n")  # Clean up spaces around newlines
    
    # Remove leading/trailing whitespace from each line
    cleaned = cleaned.split("\n").map(&:strip).join("\n")
    
    # Limit to reasonable length
    cleaned[0, 50000]
  end

  def decode_html_entities(text)
    return nil if text.nil?
    return text unless text.is_a?(String)
    
    # Decode HTML entities like &#8217; (apostrophe), &amp; (ampersand), etc.
    decoded = CGI.unescapeHTML(text)
    
    # Normalize whitespace for display fields (title, description, author)
    # Replace multiple spaces/newlines/tabs with single space
    # and remove leading/trailing whitespace
    decoded.gsub(/[\r\n\t]+/, " ").gsub(/\s+/, " ").strip
  rescue => e
    Rails.logger.warn("Failed to decode HTML entities: #{e.message}")
    text # Return original text if decoding fails
  end
end

