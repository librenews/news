require "rails_helper"

RSpec.describe UserSource, type: :model do
  it "enforces uniqueness on user/source pairs" do
    user = User.create!(atproto_did: "did:plc:user")
    source = Source.create!(atproto_did: "did:plc:source")

    described_class.create!(user:, source:)

    duplicate = described_class.new(user:, source:)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to include("has already been taken")
  end
end

