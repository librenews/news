class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat

  def create
    @message = @chat.chat_messages.new(message_params)
    @message.role = 'user'

    if @message.save
      # TODO: Trigger LLM response job here
      redirect_to @chat
    else
      redirect_to @chat, alert: "Failed to send message"
    end
  end

  private

  def set_chat
    @chat = current_user.chats.find(params[:chat_id])
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
