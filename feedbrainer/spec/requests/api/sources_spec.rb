require "rails_helper"

RSpec.describe "API::Sources", type: :request do

  describe "GET /api/sources" do
    it "returns all source atproto_dids" do
      user = User.create!(atproto_did: "did:plc:user")
      dids = %w[did:plc:source1 did:plc:source2 did:plc:source3]
      dids.each do |did|
        source = Source.create!(atproto_did: did)
        UserSource.create!(user:, source:)
      end

      get api_sources_path, as: :json, headers: { "User-Agent" => "Mozilla/5.0" }
      puts response.body
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(dids)
    end

    it "returns an empty array when no sources exist" do
      get api_sources_path, as: :json, headers: { "User-Agent" => "Mozilla/5.0" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end
  end
end

