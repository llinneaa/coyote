# frozen_string_literal: true

# == Schema Information
#
# Table name: resources
#
#  id                    :bigint           not null, primary key
#  identifier            :string           not null
#  title                 :string           default("(no title provided)"), not null
#  resource_type         :enum             not null
#  canonical_id          :string           not null
#  source_uri            :citext
#  organization_id       :bigint           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  representations_count :integer          default(0), not null
#  priority_flag         :boolean          default(FALSE), not null
#  host_uris             :string           default([]), not null, is an Array
#  ordinality            :integer
#
# Indexes
#
#  index_resources_on_identifier                        (identifier) UNIQUE
#  index_resources_on_organization_id                   (organization_id)
#  index_resources_on_organization_id_and_canonical_id  (organization_id,canonical_id) UNIQUE
#  index_resources_on_priority_flag                     (priority_flag)
#  index_resources_on_representations_count             (representations_count)
#  index_resources_on_source_uri_and_organization_id    (source_uri,organization_id) UNIQUE WHERE ((source_uri IS NOT NULL) AND (source_uri <> ''::citext))
#

RSpec.describe ResourcesController do
  let(:organization) { create(:organization) }
  let(:resource_group) { create(:resource_group, organization: organization) }
  let(:resource) { create(:resource, organization: organization) }

  let(:base_params) do
    {organization_id: organization.id}
  end

  let(:resource_params) do
    base_params.merge(id: resource.id)
  end

  let(:new_resource_params) do
    resource = attributes_for(:resource, organization: organization)
    resource[:resource_group_id] = resource_group.id
    base_params.merge(resource: resource)
  end

  let(:update_resource_params) do
    resource_params.merge(resource: {title: "NEWTITLE"})
  end

  describe "as a signed-out user" do
    include_context "signed-out user"

    it "requires login for all actions" do
      aggregate_failures do
        get :index, params: base_params
        expect(response).to redirect_to(new_user_session_url)

        get :show, params: resource_params
        expect(response).to redirect_to(new_user_session_url)

        get :edit, params: resource_params
        expect(response).to redirect_to(new_user_session_url)

        get :new, params: base_params
        expect(response).to redirect_to(new_user_session_url)

        post :create, params: new_resource_params
        expect(response).to redirect_to(new_user_session_url)

        patch :update, params: update_resource_params
        expect(response).to redirect_to(new_user_session_url)

        delete :destroy, params: update_resource_params
        expect(response).to redirect_to(new_user_session_url)
      end
    end
  end

  describe "as an author" do
    include_context "signed-in author user"

    it "shows resources" do
      get :show, params: resource_params
      expect(response).to be_successful
    end

    it "lists resources" do
      get :index, params: base_params
      expect(response).to be_successful
    end

    it "shows an edit page" do
      expect {
        get :edit, params: resource_params
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "shows a new page" do
      get :new, params: base_params
      expect(response).to be_successful
    end

    it "creates valid resources" do
      expect {
        post :create, params: new_resource_params
        expect(response).to be_redirect
      }.to change(organization.resources, :count).by(1)
    end

    it "does not create invalid resources" do
      post :create, params: base_params.merge(resource: {resource_group_id: nil})
      expect(response).not_to be_redirect
    end

    it "updates resources" do
      expect {
        patch :update, params: update_resource_params
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "deletes resources" do
      expect {
        delete :destroy, params: update_resource_params
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "as an editor" do
    include_context "signed-in editor user"

    it "succeeds for critical actions" do
      get :new, params: base_params
      expect(response).to be_successful

      get :edit, params: resource_params
      expect(response).to be_successful

      expect {
        patch :update, params: update_resource_params
        expect(response).to redirect_to(resource)
        resource.reload
      }.to change(resource, :title).to("NEWTITLE")

      post :update, params: update_resource_params.merge(resource: {resource_type: ""})
      expect(response).not_to be_redirect

      expect {
        delete :destroy, params: update_resource_params
        expect(response).to redirect_to(organization_resources_url(organization))
      }.to change { Resource.exists?(resource.id) }
        .from(true).to(false)
    end
  end
end
