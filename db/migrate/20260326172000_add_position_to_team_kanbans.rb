class AddPositionToTeamKanbans < ActiveRecord::Migration[7.1]
  def change
    add_column :team_kanbans, :position, :integer, null: false, default: 0
    add_index :team_kanbans, [:team_id, :position]
  end
end
