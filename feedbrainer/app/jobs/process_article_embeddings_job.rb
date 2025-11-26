class ProcessArticleEmbeddingsJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)

    # Step 1: Clean the text
    cleaned_text = ArticleTextCleaningService.call(article)
    if cleaned_text.present?
      article.update_column(:cleaned_text, cleaned_text)
    else
      Rails.logger.warn("No cleaned text for article #{article_id}")
      return
    end

    # Step 2: Chunk the cleaned text
    chunks = ArticleChunkingService.call(cleaned_text)
    if chunks.empty?
      Rails.logger.warn("No chunks created for article #{article_id}")
      return
    end

    # Step 3: Generate embeddings for each chunk and store
    model_version = "all-MiniLM-L6-v2"
    chunks.each do |chunk_data|
      embedding_result = SkytorchClient.generate_embedding(chunk_data[:text], model_name: model_version)

      if embedding_result[:success]
        ArticleChunk.create!(
          article: article,
          chunk_index: chunk_data[:chunk_index],
          text: chunk_data[:text],
          embedding_vector: embedding_result[:embedding],
          embedding_version: embedding_result[:model_version],
          token_count: chunk_data[:token_count],
          checksum: chunk_data[:checksum]
        )
      else
        Rails.logger.error("Failed to generate embedding for chunk #{chunk_data[:chunk_index]} of article #{article_id}: #{embedding_result[:error]}")
      end
    end

    Rails.logger.info("Processed #{chunks.size} chunks for article #{article_id}")

    # Step 4: Extract entities and store
    extract_and_store_entities(article, cleaned_text)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Article #{article_id} not found: #{e.message}")
  rescue => e
    Rails.logger.error("Error processing article embeddings for #{article_id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    raise
  end

  private

  def extract_and_store_entities(article, cleaned_text)
    entities_result = SkytorchClient.extract_entities(cleaned_text)

    unless entities_result[:success]
      Rails.logger.error("Failed to extract entities for article #{article.id}: #{entities_result[:error]}")
      return
    end

    entities = entities_result[:entities] || []
    return if entities.empty?

    # Group entities by name and type to calculate frequency
    entity_groups = entities.group_by { |e| [e["text"], e["label"]] }

    entity_groups.each do |(name, label), occurrences|
      # Map Spacy labels to our entity types
      entity_type = map_spacy_label_to_type(label)
      next unless entity_type

      # Find or create entity
      normalized_name = name.downcase.strip
      entity = Entity.find_or_create_by!(
        normalized_name: normalized_name,
        type: entity_type
      ) do |e|
        e.name = name
      end

      # Calculate frequency and positions
      frequency = occurrences.size
      sentence_positions = occurrences.map { |occ| occ["start"] }
      # Simple confidence: use average if we had confidence scores, otherwise default
      confidence_score = 0.8 # Default confidence

      # Find or create article_entity join record
      article_entity = ArticleEntity.find_or_initialize_by(
        article: article,
        entity: entity
      )

      if article_entity.new_record?
        article_entity.frequency = frequency
        article_entity.sentence_positions = sentence_positions
        article_entity.confidence_score = confidence_score
        article_entity.save!
      else
        # Update frequency and merge positions if entity already linked
        article_entity.update!(
          frequency: article_entity.frequency + frequency,
          sentence_positions: (article_entity.sentence_positions + sentence_positions).uniq.sort
        )
      end
    end

    Rails.logger.info("Extracted and stored #{entity_groups.size} unique entities for article #{article.id}")
  end

  def map_spacy_label_to_type(label)
    # Map Spacy entity labels to our entity types
    case label
    when "PERSON"
      "PERSON"
    when "ORG", "ORGANIZATION"
      "ORG"
    when "GPE", "LOC", "LOCATION"
      "PLACE"
    when "EVENT"
      "EVENT"
    else
      nil # Skip unknown types
    end
  end
end

