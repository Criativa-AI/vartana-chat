# == Schema Information
#
# Table name: team_kanbans
#
#  id                     :bigint           not null, primary key
#  description            :text
#  is_default             :boolean          default(FALSE), not null
#  name                   :string           not null
#  position               :integer          default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  initial_stage_label_id :bigint
#  team_id                :bigint           not null
#
# Indexes
#
#  index_team_kanbans_on_account_id              (account_id)
#  index_team_kanbans_on_initial_stage_label_id  (initial_stage_label_id)
#  index_team_kanbans_on_team_id                 (team_id)
#  index_team_kanbans_on_team_id_and_name        (team_id,name) UNIQUE
#  index_team_kanbans_on_team_id_and_position    (team_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (initial_stage_label_id => labels.id)
#  fk_rails_...  (team_id => teams.id)
#
class TeamKanban < ApplicationRecord
  belongs_to :account
  belongs_to :team
  belongs_to :initial_stage_label, class_name: 'Label', optional: true
  has_many :columns, class_name: 'TeamKanbanColumn', dependent: :destroy_async

  validates :name, presence: true, uniqueness: { scope: :team_id }
  validates :position, presence: true

  scope :ordered, -> { order(:position, :id) }
end
