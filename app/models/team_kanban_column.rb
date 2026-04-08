# == Schema Information
#
# Table name: team_kanban_columns
#
#  id             :bigint           not null, primary key
#  name_override  :string
#  position       :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  label_id       :bigint           not null
#  team_kanban_id :bigint           not null
#
# Indexes
#
#  index_team_kanban_columns_on_account_id                   (account_id)
#  index_team_kanban_columns_on_label_id                     (label_id)
#  index_team_kanban_columns_on_team_kanban_id               (team_kanban_id)
#  index_team_kanban_columns_on_team_kanban_id_and_label_id  (team_kanban_id,label_id) UNIQUE
#  index_team_kanban_columns_on_team_kanban_id_and_position  (team_kanban_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (label_id => labels.id)
#  fk_rails_...  (team_kanban_id => team_kanbans.id)
#
class TeamKanbanColumn < ApplicationRecord
  belongs_to :account
  belongs_to :team_kanban
  belongs_to :label

  validates :label_id, uniqueness: { scope: :team_kanban_id }
end
