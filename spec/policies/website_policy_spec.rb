RSpec.describe WebsitePolicy do
  let(:org_user) { double(:organization_user,admin?: false) }
  let(:record) { double(:record,class: Website) }
  let(:scope) { double(:scope) }

  subject { WebsitePolicy.new(org_user,record) }

  it { is_expected.to permit_action(:index)          }
  it { is_expected.to permit_action(:show)           }
  it { is_expected.to forbid_new_and_create_actions  }
  it { is_expected.to forbid_edit_and_update_actions }
  it { is_expected.to forbid_action(:destroy)        }
  
  specify { expect(subject.scope).to eq(Website) }

  context "as an admin" do
    before do
      allow(org_user).to receive_messages(admin?: true)
    end

    it { is_expected.to permit_action(:index)          }
    it { is_expected.to permit_action(:show)           }
    it { is_expected.to permit_new_and_create_actions  }
    it { is_expected.to permit_edit_and_update_actions }
    it { is_expected.to permit_action(:destroy)        }
  end
end