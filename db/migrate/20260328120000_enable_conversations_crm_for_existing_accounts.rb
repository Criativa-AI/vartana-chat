# frozen_string_literal: true

# Conversations CRM is stored in accounts.settings (jsonb), not feature_flags: the Featurable
# bitmask is a signed 64-bit column and cannot represent additional flags beyond ~63 positions.
class EnableConversationsCrmForExistingAccounts < ActiveRecord::Migration[7.0]
  def up
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each do |account|
        settings = account.settings.blank? ? {} : account.settings.stringify_keys
        next if settings.key?('conversations_crm')

        settings['conversations_crm'] = true
        account.update_columns(settings: settings, updated_at: Time.current)
      end
    end
  end
end
