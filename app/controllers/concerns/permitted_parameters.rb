# frozen_string_literal: true

# Defines common parameter handling behavior among controllers
# @see http://guides.rubyonrails.org/action_controller_overview.html#strong-parameters
module PermittedParameters
  REPRESENTATION_PARAMS = %i[
    author_id
    content_type
    content_uri
    language
    license
    license_id
    metum
    metum_id
    notes
    ordinality
    status
    text
  ].freeze

  RESOURCE_PARAMS = (
    %i[
      canonical_id
      host_uris
      identifier
      name
      ordinality
      priority_flag
      resource_group_id
      resource_group_ids
      resource_type
      source_uri
      uploaded_resource
    ] + [{
      representations:    REPRESENTATION_PARAMS,
      resource_group_ids: [],
    }]).freeze

  private

  def clean_resource_params(resource_params)
    resource_params.permit(*RESOURCE_PARAMS).tap do |params|
      representations = params.delete(:representations)
      if representations.present?
        clean_representations = representations.each_with_index.map { |representation, index|
          representation[:author_id] ||= current_user.id
          [index, representation]
        }
        params[:representations_attributes] = Hash[*clean_representations.flatten]
      end
    end
  end

  def pagination_params
    params.fetch(:page, params).permit(:number, :per_page, :size)
  end

  def representation_params
    params.require(:representation).permit(*REPRESENTATION_PARAMS)
  end

  def resource_params
    clean_resource_params(params.require(:resource))
  end
end
