class Conversations::PipelineStageService
  pattr_initialize [:conversation!, :account!]

  def assign_stage!(stage_label_id = nil)
    stage = find_stage(stage_label_id)
    stage_titles = account.labels.pluck(:title)

    current_labels = conversation.label_list
    next_labels = current_labels - stage_titles
    next_labels << stage.title if stage.present?

    conversation.update_labels(next_labels.uniq)
    stage
  end

  private

  def find_stage(stage_label_id)
    return nil if stage_label_id.blank?

    account.labels.find(stage_label_id)
  end
end

