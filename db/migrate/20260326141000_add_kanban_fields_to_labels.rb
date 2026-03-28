class AddKanbanFieldsToLabels < ActiveRecord::Migration[7.1]
  def change
    add_column :labels, :kind, :integer, default: 0, null: false
    add_column :labels, :position, :integer, default: 0, null: false

    add_index :labels, [:account_id, :kind, :position]
  end
end

