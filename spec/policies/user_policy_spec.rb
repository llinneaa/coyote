# frozen_string_literal: true

RSpec.describe UserPolicy do
  subject { described_class.new(org_user, user_record) }

  let(:org_user) do
    double(:organization_user, id: 1, staff?: false)
  end

  let(:user_record) do
    double(:user, id: 2)
  end

  it { is_expected.to forbid_action(:index) }
  it { is_expected.to permit_action(:show) }
  it { is_expected.to forbid_action(:destroy) }
  it { is_expected.to forbid_new_and_create_actions }
  it { is_expected.to forbid_edit_and_update_actions }

  describe "as a user, with own record" do
    let(:user_record) do
      double(:user, id: org_user.id)
    end

    it { is_expected.to permit_edit_and_update_actions }
    it { is_expected.to forbid_action(:destroy) }
  end

  describe "as a staff member, with any record" do
    before do
      allow(org_user).to receive_messages(staff?: true)
    end

    it { is_expected.to permit_edit_and_update_actions }
    it { is_expected.to permit_action(:destroy) }
  end
end
