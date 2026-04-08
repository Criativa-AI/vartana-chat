class AddInitialStageLabelToTeamKanbans < ActiveRecord::Migration[7.1]
  def change
    add_reference :team_kanbans, :initial_stage_label, foreign_key: { to_table: :labels }, null: true
  end
end
