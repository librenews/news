class Entity < ApplicationRecord
  has_many :article_entities, dependent: :destroy
  has_many :articles, through: :article_entities

  validates :name, presence: true
  validates :type, presence: true, inclusion: { in: %w[PERSON ORG PLACE EVENT] }
  validates :normalized_name, presence: true
  validates :normalized_name, uniqueness: { scope: :type }

  before_validation :normalize_name

  private

  def normalize_name
    self.normalized_name = name&.downcase&.strip if normalized_name.blank? && name.present?
  end
end

