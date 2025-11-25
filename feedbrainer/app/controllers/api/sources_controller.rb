class Api::SourcesController < ApplicationController
  def index
    atproto_dids = Source.pluck(:atproto_did)
    render json: atproto_dids
  end
end

