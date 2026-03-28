namespace :db do
  namespace :seed do
    desc 'Create simulated conversations for an account/inbox'
    task sample_conversations: :environment do
      count = ENV.fetch('COUNT', 30).to_i
      count = 1 if count < 1

      account = if ENV['ACCOUNT_ID'].present?
                  Account.find(ENV.fetch('ACCOUNT_ID'))
                else
                  Account.first
                end
      raise 'No account found. Create an account first.' unless account

      inbox = if ENV['INBOX_ID'].present?
                account.inboxes.find(ENV.fetch('INBOX_ID'))
              else
                account.inboxes.first
              end
      raise "No inbox found for account #{account.id}." unless inbox

      user = account.users.first || User.first
      raise 'No user found to send outgoing messages.' unless user

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

      created = 0
      count.times do |index|
        contact_inbox = ContactInboxWithContactBuilder.new(
          source_id: "seed-contact-#{Time.current.to_i}-#{index + 1}",
          inbox: inbox,
          hmac_verified: true,
          contact_attributes: {
            name: "Seed Contact #{index + 1}",
            email: "seed.contact.#{Time.current.to_i}.#{index + 1}@example.com",
            phone_number: "+1555000#{format('%04d', index + 1)}"
          }
        ).perform

        conversation = Conversation.create!(
          account: account,
          inbox: inbox,
          status: statuses[index % statuses.length],
          assignee: (index % 3).zero? ? user : nil,
          contact: contact_inbox.contact,
          contact_inbox: contact_inbox,
          additional_attributes: {}
        )

        stage_label = stage_labels[index % stage_labels.length]
        conversation.update!(label_list: [stage_label]) if index.even?

        Message.create!(
          content: "Mensagem inicial #{index + 1}: preciso de ajuda com meu pedido.",
          account: account,
          inbox: inbox,
          conversation: conversation,
          sender: contact_inbox.contact,
          message_type: :incoming
        )
        Message.create!(
          content: "Resposta do suporte para conversa ##{conversation.display_id}.",
          account: account,
          inbox: inbox,
          conversation: conversation,
          sender: user,
          message_type: :outgoing
        )

        created += 1
      end

      puts "Created #{created} simulated conversations on account ##{account.id}, inbox ##{inbox.id}."
    end
  end
end
