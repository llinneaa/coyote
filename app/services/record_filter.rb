# frozen_string_literal: true

# Handles all of the logic for transforming a user's query parameters into a subset of records
# @see RecordPaginator
class RecordFilter
  attr_writer :record_paginator

  # @param filter_params [Hash]
  # @param pagination_params [Hash]
  # @param base_scope [ActiveRecord::Relation] the basis of all queries;
  #   typically this is based on who is logged-in, and whether the query is Coyote-wide (as in a UI index page)
  #   or organization-specific (as in an API call)
  def initialize(filter_params, pagination_params, base_scope, default_order: [])
    @filter_params = filter_params.to_hash.with_indifferent_access.tap do |params|
      params.each do |key, value|
        params[key] = value.to_s.split(/(\s|,)/) if /_(cont_all|any)$/.match?(key.to_s)
      end
    end
    @pagination_params = pagination_params
    @default_order = default_order

    filter_scope = @filter_params.delete(:scope)
    Array(filter_scope).each { |scope| @filter_params[scope] = true } if filter_scope.present?

    # TODO: Separate filtering and ordering properly.
    # This applies default ordering unless filter params are present - for now.
    default_order = Array(default_order)
    @base_scope = if default_order.any? && @filter_params.empty?
      default_order.inject(base_scope) { |scope, filter| scope.send(filter) }
    else
      base_scope
    end
  end

  # A set of links that should be rendered for browser users. The only difference between this and what an API user
  # would see is that we suppress the first page link if the user is already viewing the first page
  # @return (see #pagination_link_params)
  def browser_pagination_link_params
    pagination_link_params.tap do |p|
      p.delete(:first) if records.first_page?
    end
  end

  # @return [Hash] links that point to other available filtered pages
  def pagination_link_params
    base_link_params = {}
    base_link_params[:q] = filter_params.to_hash if filter_params.present?
    record_paginator.pagination_links_for(base_link_params)
  end

  # @return [ActiveRecord::Relation] the filtered collection of records, ready to be enumerated
  def records
    @records ||= record_paginator.query
  end

  # @return [Ransack::Search] for use with Ransack's simple_form_for form helper
  def search
    @search ||= base_scope.ransack(filter_params)
  end

  private

  attr_reader :filter_params, :pagination_params, :base_scope

  def record_paginator
    @record_paginator ||= RecordPaginator.new(pagination_params, search.result)
  end
end
