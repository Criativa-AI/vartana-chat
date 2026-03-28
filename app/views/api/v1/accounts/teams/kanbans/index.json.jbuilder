json.payload do
  json.array! @kanbans do |kanban|
    json.id kanban.id
    json.team_id kanban.team_id
    json.name kanban.name
    json.description kanban.description
    json.is_default kanban.is_default
    json.position kanban.position
    json.initial_stage_label_id kanban.initial_stage_label_id
    json.columns do
      json.array! kanban.columns.sort_by(&:position) do |column|
        json.id column.id
        json.position column.position
        json.label_id column.label_id
        json.label_title column.label&.title
      end
    end
  end
end
