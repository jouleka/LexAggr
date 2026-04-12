class DocumentNode < ApplicationRecord
  belongs_to :legislation_version
  belongs_to :parent, class_name: "DocumentNode", optional: true
  has_many :children, class_name: "DocumentNode", foreign_key: :parent_id, dependent: :destroy

  scope :descendants_of, ->(path) { where("tree_path <@ ?::ltree", path.to_s) }
  scope :ancestors_of, ->(path) { where("tree_path @> ?::ltree", path.to_s) }
  scope :direct_children_of, ->(path) { where("tree_path ~ ?::lquery", "#{path}.*{1}") }
  scope :roots, -> { where(parent: nil) }

  HIERARCHICAL_TYPES = %w[part chapter title section article paragraph subparagraph clause point indent].freeze
end
