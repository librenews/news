require "cgi"

class ArticleTextCleaningService
  def self.call(article)
    new(article).call
  end

  def initialize(article)
    @article = article
  end

  def call
    return "" if @article.nil?
    
    # Prefer html_content if available, fall back to body_text
    source_text = @article.html_content || @article.body_text
    return "" if source_text.nil? || source_text.strip.empty?
    
    cleaned = clean_text(source_text)
    cleaned.strip
  end

  private

  def clean_text(text)
    # Remove script tags and their content
    text = text.gsub(/<script[^>]*>.*?<\/script>/mi, "")
    
    # Remove style tags and their content
    text = text.gsub(/<style[^>]*>.*?<\/style>/mi, "")
    
    # Remove common navigation/boilerplate patterns
    text = text.gsub(/<nav[^>]*>.*?<\/nav>/mi, "")
    text = text.gsub(/<header[^>]*>.*?<\/header>/mi, "")
    text = text.gsub(/<footer[^>]*>.*?<\/footer>/mi, "")
    text = text.gsub(/<aside[^>]*>.*?<\/aside>/mi, "")
    
    # Remove comments
    text = text.gsub(/<!--.*?-->/m, "")
    
    # Convert common block elements to newlines to preserve paragraph structure
    text = text.gsub(/<\/?(p|div|h[1-6]|article|section|li|br)[^>]*>/i, "\n")
    
    # Remove all remaining HTML tags
    text = text.gsub(/<[^>]+>/, "")
    
    # Decode HTML entities
    text = CGI.unescapeHTML(text)
    
    # Clean up whitespace: collapse multiple newlines to double newline (paragraph break)
    text = text.gsub(/\n{3,}/, "\n\n")
    
    # Collapse multiple spaces to single space (but preserve newlines)
    text = text.gsub(/[ \t]+/, " ")
    
    # Remove leading/trailing whitespace from each line
    text = text.split("\n").map(&:strip).join("\n")
    
    text
  end
end

