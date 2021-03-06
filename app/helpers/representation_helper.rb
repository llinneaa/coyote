# frozen_string_literal: true

module RepresentationHelper
  REPRESENTATION_STATUS_CLASSES = {
    ready_to_review: "partial",
    approved:        "success",
    not_approved:    "warning",
  }.freeze

  def representation_status_tag(representation, tag: :span)
    tag_class = REPRESENTATION_STATUS_CLASSES[representation.status.to_sym]
    content_tag(tag, class: "tag tag--#{tag_class}") do
      block_given? ? yield : representation.status.to_s.titleize
    end
  end
end
