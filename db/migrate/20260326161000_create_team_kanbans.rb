class CreateTeamKanbans < ActiveRecord::Migration[7.1]
  def change
    create_table :team_kanbans do |t|
      t.references :account, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end

    add_index :team_kanbans, [:team_id, :name], unique: true
  end
end
