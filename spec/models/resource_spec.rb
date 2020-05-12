# frozen_string_literal: true

# == Schema Information
#
# Table name: resources
#
#  id                    :bigint           not null, primary key
#  host_uris             :string           default([]), not null, is an Array
#  identifier            :string           not null
#  ordinality            :integer
#  priority_flag         :boolean          default(FALSE), not null
#  representations_count :integer          default(0), not null
#  resource_type         :enum             not null
#  source_uri            :citext
#  title                 :string           default("(no title provided)"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  canonical_id          :string           not null
#  organization_id       :bigint           not null
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
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id) ON DELETE => restrict ON UPDATE => cascade
#

require "webmock/rspec"

# rubocop:disable RSpec/MultipleExpectations
RSpec.describe Resource do
  subject { resource }

  let(:resource) { build(:resource, :image, title: "Mona Lisa", identifier: "abc123", source_uri: source_uri) }
  let(:source_uri) { "http://example.com/100.jpg" }

  it { is_expected.to validate_presence_of(:resource_type) }

  it { is_expected.to validate_uniqueness_of(:identifier) }

  specify { expect(resource.label).to eq("Mona Lisa (abc123)") }

  specify do
    expect(resource).to have_many(:subject_resource_links).class_name(:ResourceLink).with_foreign_key(:subject_resource_id).inverse_of(:subject_resource)
  end

  specify do
    expect(resource).to have_many(:object_resource_links).class_name(:ResourceLink).with_foreign_key(:object_resource_id).inverse_of(:object_resource)
  end

  specify do
    expect(resource).to be_viewable
  end

  describe "without the presence of a source URI" do
    let(:resource) { build(:resource, :image, source_uri: "") }

    specify do
      expect(resource).not_to be_viewable
    end
  end

  describe "with a non-image resource type" do
    let(:resource) { build(:resource, :physical_object) }

    specify do
      expect(resource).not_to be_viewable
    end
  end

  describe "#related_resources" do
    # this test requires the database as rspec stubs don't completely replicate has_many behaviors
    let!(:resource_link) do
      create(:resource_link, verb: "hasPart")
    end

    let(:subject_resource) { resource_link.subject_resource }
    let(:object_resource) { resource_link.object_resource }

    it "returns correctly labeled predicates" do
      expect(subject_resource.related_resources).to eq([["hasPart", resource_link, object_resource]])
      expect(object_resource.related_resources).to eq([["isPartOf", resource_link, subject_resource]])
    end
  end

  describe "::has_approved_representations" do
    let!(:approved_resource) { create(:resource) }

    before do
      create(:representation, resource: approved_resource, status: "approved")
      create(:resource)
      create(:representation, resource: approved_resource, status: "not_approved")
    end

    it "returns resources that have approved represents" do
      expect(described_class.with_approved_representations).to eq([approved_resource])
    end
  end

  describe "when saved" do
    it "sets a unique identifier based on the title" do
      resource = build(:resource, identifier: "", title: "This is a test, isn't it?! YES!")
      expect(resource.identifier).to be_blank
      resource.save!
      expect(resource.identifier).to eq("this-is-a-test-isn-t-it-yes")

      allow(SecureRandom).to receive(:hex).with(3).and_return("abcdef")

      resource_2 = create(:resource, identifier: "", title: "This is a test, isn't it?! YES!")
      expect(resource_2.identifier).to eq("this-is-a-test-isn-t-it-yes-abcdef")
      expect(SecureRandom).to have_received(:hex).with(3)
    end

    it "sets a unique canonical id" do
      resource = build(:resource)
      expect(resource.canonical_id).to be_blank
      resource.save!
      expect(resource.canonical_id).to be_present
    end

    it "does not set a canonical ID if one is given" do
      resource = build(:resource)
      resource.canonical_id = "123"
      resource.save!
      expect(resource.canonical_id).to eq("123")
    end
  end

  describe "#notify_webhook!" do
    include_context "webhooks"

    it "sends webhook notifications when resources are created" do
      resource = create(:resource, resource_groups: [resource_group])
      expect(a_request(:post, "http://www.example.com/webhook/goes/here").with { |req|
        data = JSON.parse(req.body)["data"]
        expect(data).to have_attribute(:canonical_id).with_value(resource.canonical_id)
      }).to have_been_made
    end
  end

  describe "receiving representations in attributes", clean_db: true do
    let(:organization) { create(:organization) }
    let!(:user) { create(:membership, organization: organization).user }
    let!(:user_2) { create(:membership, organization: organization).user }

    let!(:endpoint) { Endpoint.find_or_create_by!(name: "Any") }
    let!(:endpoint_2) { create(:endpoint, :website) }

    let!(:license) { create(:license, :universal) }
    let!(:license_2) { create(:license, :attribution_international) }

    let!(:metum) { create(:metum, :short) }
    let!(:metum_2) { create(:metum, :long) }

    let(:representation_attributes) { attributes_for(:representation) }

    describe "on new records" do
      let(:resource) {
        create(:resource,
          organization:               organization,
          representations_attributes: {0 => representation_attributes})
      }
      let(:representation) { resource.representations.first }

      it "creates representations for the resource" do
        expect(resource).to be_persisted
        expect(representation.attributes.symbolize_keys).to include(representation_attributes)
      end

      it "automatically assigns the first active organization user" do
        expect(representation.author).to eq(user)
      end

      it "accepts an author" do
        representation_attributes[:author_id] = user_2.id
        expect(representation.author).to eq(user_2)
      end

      it "automatically assigns the universal license" do
        expect(representation.license).to eq(license)
      end

      it "accepts a license" do
        representation_attributes[:license] = license_2.name
        expect(representation.license).to eq(license_2)
      end

      it "automatically assigns the 'any' endpoint" do
        expect(representation.endpoint).to eq(endpoint)
      end

      it "accepts an endpoint" do
        representation_attributes[:endpoint] = endpoint_2.name
        expect(representation.endpoint).to eq(endpoint_2)
      end

      it "automatically assigns the 'Short' metum" do
        expect(representation.metum).to eq(metum)
      end

      it "accepts a metum" do
        representation_attributes[:metum] = metum_2.title
        expect(representation.metum).to eq(metum_2)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations
