# frozen_string_literal: true

module ConversationsCrmFeatureGate
  extend ActiveSupport::Concern

  included do
    before_action :ensure_conversations_crm_enabled!
  end

  private

  def ensure_conversations_crm_enabled!
    return if Current.account.conversations_crm_enabled?

    render json: { error: 'Conversations CRM is disabled for this account' }, status: :forbidden
  end
end
