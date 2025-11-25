require "rails_helper"

RSpec.describe Source, type: :model do
  it "has many users through user_sources" do
    user1 = User.create!(atproto_did: "did:plc:user1")
    user2 = User.create!(atproto_did: "did:plc:user2")
    source = described_class.create!(atproto_did: "did:plc:source")

    UserSource.create!(user: user1, source:)
    UserSource.create!(user: user2, source:)

    expect(source.users).to contain_exactly(user1, user2)
  end
end

