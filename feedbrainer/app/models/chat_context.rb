class ChatContext < ApplicationRecord
  belongs_to :chat
  belongs_to :context, polymorphic: true
end
