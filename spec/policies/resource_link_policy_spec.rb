# frozen_string_literal: true

RSpec.describe ResourceLinkPolicy do
  include_context "viewer organization user"

  subject { described_class.new(org_user, resource_link) }

  let(:resource_link) do
    double(:resource_link, class: ResourceLink)
  end

  it { is_expected.to forbid_action(:index) }
  it { is_expected.to permit_action(:show) }
  it { is_expected.to forbid_new_and_create_actions }
  it { is_expected.to forbid_edit_and_update_actions }
  it { is_expected.to forbid_action(:destroy) }

  describe "as an author" do
    include_context "author organization user"

    it { is_expected.to permit_new_and_create_actions }
    it { is_expected.to forbid_edit_and_update_actions }
    it { is_expected.to forbid_action(:destroy) }
  end

  describe "as an editor" do
    include_context "editor organization user"

    it { is_expected.to permit_edit_and_update_actions }
    it { is_expected.to permit_action(:destroy) }
  end
end
