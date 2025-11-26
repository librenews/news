require "digest"

class ArticleChunkingService
  # Target token count per chunk (using ~4 chars per token estimation)
  TARGET_CHUNK_TOKENS = 300
  OVERLAP_PERCENTAGE = 0.12 # 12% overlap

  def self.call(cleaned_text)
    new(cleaned_text).call
  end

  def initialize(cleaned_text)
    @cleaned_text = cleaned_text || ""
  end

  def call
    return [] if @cleaned_text.strip.empty?

    # Split by paragraphs (double newlines)
    paragraphs = @cleaned_text.split(/\n\n+/).map(&:strip).reject(&:empty?)
    return [] if paragraphs.empty?

    chunks = []
    chunk_index = 0

    paragraphs.each do |paragraph|
      paragraph_tokens = estimate_tokens(paragraph)

      if paragraph_tokens <= TARGET_CHUNK_TOKENS
        # Paragraph fits in one chunk
        chunks << create_chunk(paragraph, chunk_index)
        chunk_index += 1
      else
        # Paragraph is too long, split into sliding windows
        window_chunks = split_into_windows(paragraph, chunk_index)
        chunks.concat(window_chunks)
        chunk_index += window_chunks.size
      end
    end

    chunks
  end

  private

  def estimate_tokens(text)
    # Simple estimation: ~4 characters per token
    # This is a rough approximation; for more accuracy, consider using tiktoken_ruby
    (text.length / 4.0).ceil
  end

  def split_into_windows(text, start_index)
    chunks = []
    current_index = start_index
    target_chars = TARGET_CHUNK_TOKENS * 4 # Convert tokens to approximate characters
    overlap_chars = (target_chars * OVERLAP_PERCENTAGE).to_i

    start_pos = 0
    while start_pos < text.length
      end_pos = [start_pos + target_chars, text.length].min

      # Try to break at sentence boundary if possible
      if end_pos < text.length
        # Look for sentence endings within the last 20% of the window
        search_start = [end_pos - (target_chars * 0.2).to_i, start_pos].max
        sentence_end = text[search_start..end_pos].index(/[.!?]\s+/)
        if sentence_end
          end_pos = search_start + sentence_end + 1
        end
      end

      chunk_text = text[start_pos..end_pos].strip
      chunks << create_chunk(chunk_text, current_index) unless chunk_text.empty?

      # Move start position with overlap
      start_pos = [end_pos - overlap_chars, start_pos + 1].max
      current_index += 1

      # Safety check to avoid infinite loops
      break if start_pos >= text.length || chunks.size > 1000
    end

    chunks
  end

  def create_chunk(text, chunk_index)
    token_count = estimate_tokens(text)
    checksum = Digest::SHA256.hexdigest(text)

    {
      text: text,
      chunk_index: chunk_index,
      token_count: token_count,
      checksum: checksum
    }
  end
end

