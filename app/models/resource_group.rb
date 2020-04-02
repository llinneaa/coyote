# frozen_string_literal: true

# == Schema Information
#
# Table name: resource_groups
#
#  id              :integer          not null, primary key
#  title           :string           not null
#  created_at      :datetime
#  updated_at      :datetime
#  organization_id :integer          not null
#  default         :boolean          default(FALSE)
#
# Indexes
#
#  index_resource_groups_on_organization_id_and_title  (organization_id,title) UNIQUE
#

# Represents the situation in which a subject is being considered. Determines what strategy we use to present a description of a subject.
# Examples of resource_groups include Web, Exhibitions, Poetry, Digital Interactive, Mobile, Audio Tour
# @see https://github.com/coyote-team/coyote/issues/112
class ResourceGroup < ApplicationRecord
  DEFAULT_TITLE = "Uncategorized"

  before_destroy :check_for_resources_or_default

  validates :title, presence: true
  validates :title, uniqueness: {scope: :organization_id}
  validates :default, uniqueness: {if: :default?, scope: :organization_id}

  has_many :resources, inverse_of: :resource_group

  belongs_to :organization, inverse_of: :resource_groups

  scope :by_default_and_name, -> { order({default: :desc}, {title: :asc}) }
  scope :default, -> { where(default: true) }

  def title_with_default_annotation
    "#{self}#{default ? " (default)" : ""}"
  end

  # @return [String] title of this group
  def to_s
    title
  end

  private

  def check_for_resources_or_default
    if default? || resources.any?
      errors.add(:base, default? ? "The default resource group cannot be deleted" : "It has resources in it")
      throw(:abort)
    end
  end
end
