# loading installation configs
GlobalConfig.clear_cache
ConfigLoader.new.process

## Seeds productions
if Rails.env.production?
  # Setup Onboarding flow
  Redis::Alfred.set(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING, true)
end

## Seeds for Local Development
unless Rails.env.production?

  # Enables creating additional accounts from dashboard
  installation_config = InstallationConfig.find_by(name: 'CREATE_NEW_ACCOUNT_FROM_DASHBOARD')
  installation_config.value = true
  installation_config.save!
  GlobalConfig.clear_cache

  account = Account.create!(
    name: 'Acme Inc'
  )

  secondary_account = Account.create!(
    name: 'Acme Org'
  )

  user = User.new(name: 'John', email: 'john@acme.inc', password: 'Password1!', type: 'SuperAdmin')
  user.skip_confirmation!
  user.save!

  AccountUser.create!(
    account_id: account.id,
    user_id: user.id,
    role: :administrator
  )

  AccountUser.create!(
    account_id: secondary_account.id,
    user_id: user.id,
    role: :administrator
  )

  web_widget = Channel::WebWidget.create!(account: account, website_url: 'https://acme.inc')

  inbox = Inbox.create!(channel: web_widget, account: account, name: 'Acme Support')
  InboxMember.create!(user: user, inbox: inbox)

  contact_inbox = ContactInboxWithContactBuilder.new(
    source_id: user.id,
    inbox: inbox,
    hmac_verified: true,
    contact_attributes: { name: 'jane', email: 'jane@example.com', phone_number: '+2320000' }
  ).perform

  conversation = Conversation.create!(
    account: account,
    inbox: inbox,
    status: :open,
    assignee: user,
    contact: contact_inbox.contact,
    contact_inbox: contact_inbox,
    additional_attributes: {}
  )

  # sample email collect
  Seeders::MessageSeeder.create_sample_email_collect_message conversation

  Message.create!(content: 'Hello', account: account, inbox: inbox, conversation: conversation, sender: contact_inbox.contact,
                  message_type: :incoming)

  # sample location message
  #
  location_message = Message.new(content: 'location', account: account, inbox: inbox, sender: contact_inbox.contact, conversation: conversation,
                                 message_type: :incoming)
  location_message.attachments.new(
    account_id: account.id,
    file_type: 'location',
    coordinates_lat: 37.7893768,
    coordinates_long: -122.3895553,
    fallback_title: 'Bay Bridge, San Francisco, CA, USA'
  )
  location_message.save!

  # sample card
  Seeders::MessageSeeder.create_sample_cards_message conversation
  # input select
  Seeders::MessageSeeder.create_sample_input_select_message conversation
  # form
  Seeders::MessageSeeder.create_sample_form_message conversation
  # articles
  Seeders::MessageSeeder.create_sample_articles_message conversation
  # csat
  Seeders::MessageSeeder.create_sample_csat_collect_message conversation

  CannedResponse.create!(account: account, short_code: 'start', content: 'Hello welcome to chatwoot.')

  if ActiveModel::Type::Boolean.new.cast(ENV.fetch('SEED_SAMPLE_CONVERSATIONS', false))
    conversation_count = ENV.fetch('SEED_SAMPLE_CONVERSATIONS_COUNT', 30).to_i
    conversation_count = 1 if conversation_count < 1

    statuses = %i[open resolved pending snoozed]
    stage_labels = %w[lead qualified proposal won]

    stage_labels.each_with_index do |label_title, index|
      account.labels.find_or_create_by!(title: label_title) do |label|
        label.description = "Pipeline stage #{label_title}"
        label.color = format('#%06x', ((index + 1) * 1118481) % 0xffffff)
        label.show_on_sidebar = true
        label.kind = :pipeline_stage
        label.position = index
      end
    end

    conversation_count.times do |index|
      contact_inbox = ContactInboxWithContactBuilder.new(
        source_id: "seed-contact-#{index + 1}",
        inbox: inbox,
        hmac_verified: true,
        contact_attributes: {
          name: "Seed Contact #{index + 1}",
          email: "seed.contact.#{index + 1}@example.com",
          phone_number: "+1555000#{format('%04d', index + 1)}"
        }
      ).perform

      seeded_conversation = Conversation.create!(
        account: account,
        inbox: inbox,
        status: statuses[index % statuses.length],
        assignee: (index % 3).zero? ? user : nil,
        contact: contact_inbox.contact,
        contact_inbox: contact_inbox,
        additional_attributes: {}
      )

      stage_label = stage_labels[index % stage_labels.length]
      seeded_conversation.update!(label_list: [stage_label]) if index.even?

      Message.create!(
        content: "Mensagem inicial #{index + 1}: preciso de ajuda com meu pedido.",
        account: account,
        inbox: inbox,
        conversation: seeded_conversation,
        sender: contact_inbox.contact,
        message_type: :incoming
      )
      Message.create!(
        content: "Resposta do suporte para conversa ##{seeded_conversation.display_id}.",
        account: account,
        inbox: inbox,
        conversation: seeded_conversation,
        sender: user,
        message_type: :outgoing
      )
    end
  end
end
