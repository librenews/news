class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [:show, :update]

  def index
    @chats = current_user.chats.order(updated_at: :desc)
  end

  def show
    @messages = @chat.chat_messages.order(:created_at)
  end

  def create
    @chat = current_user.chats.new(chat_params)
    
    if @chat.save
      # Default to Global Feed context if none provided
      @chat.chat_contexts.create!(context: GlobalFeed.first_or_create!)
      redirect_to @chat
    else
      redirect_to chats_path, alert: "Failed to create chat"
    end
  end

  private

  def set_chat
    @chat = current_user.chats.find(params[:id])
  end

  def chat_params
    params.require(:chat).permit(:title)
  end
end
