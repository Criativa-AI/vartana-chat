class CreateTeamKanbanColumns < ActiveRecord::Migration[7.1]
  def change
    create_table :team_kanban_columns do |t|
      t.references :account, null: false, foreign_key: true
      t.references :team_kanban, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :name_override

      t.timestamps
    end

    add_index :team_kanban_columns, [:team_kanban_id, :position]
    add_index :team_kanban_columns, [:team_kanban_id, :label_id], unique: true
  end
end
