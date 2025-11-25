require "rails_helper"

RSpec.describe User, type: :model do
  it "has many sources through user_sources" do
    user = described_class.create!(atproto_did: "did:plc:user")
    source1 = Source.create!(atproto_did: "did:plc:source1")
    source2 = Source.create!(atproto_did: "did:plc:source2")

    UserSource.create!(user:, source: source1)
    UserSource.create!(user:, source: source2)

    expect(user.sources).to contain_exactly(source1, source2)
  end
end

