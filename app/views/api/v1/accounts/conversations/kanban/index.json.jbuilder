json.payload do
  json.columns do
    json.array! @columns do |column|
      json.id column[:id]
      json.title column[:title]
      json.conversations do
        json.array! column[:conversations] do |conversation|
          json.id conversation.id
          json.display_id conversation.display_id
          json.status conversation.status
          json.last_activity_at conversation.last_activity_at
          json.inbox_id conversation.inbox_id
          json.contact_name conversation.contact&.name
          json.contact_thumbnail conversation.contact&.avatar_url
          json.inbox_name conversation.inbox&.name
          json.team_name conversation.team&.name
          json.assignee_name conversation.assignee&.name
          json.assignee_thumbnail conversation.assignee&.avatar_url
          json.labels conversation.cached_label_list_array
        end
      end
    end
  end
end

