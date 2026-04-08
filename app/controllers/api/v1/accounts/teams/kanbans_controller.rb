class Api::V1::Accounts::Teams::KanbansController < Api::V1::Accounts::BaseController
  include ConversationsCrmFeatureGate

  before_action :set_team
  before_action :set_kanban, only: [:update, :destroy, :set_default]

  def index
    authorize @team, :show?
    ensure_default_kanban!
    @kanbans = @team.kanbans.includes(columns: :label).ordered
  end

  def create
    authorize @team, :update?
    @kanban = @team.kanbans.new(kanban_params.except(:column_label_ids))
    @kanban.account = Current.account
    @kanban.position = (@team.kanbans.maximum(:position) || -1) + 1
    @kanban.is_default = @team.kanbans.empty?
    @kanban.save!
    sync_columns!(@kanban)
    @kanban.reload
    render :show
  end

  def update
    authorize @team, :update?
    @kanban.update!(kanban_params.except(:column_label_ids))
    sync_columns!(@kanban) if kanban_params.key?(:column_label_ids)
    @kanban.reload
    render :show
  end

  def destroy
    authorize @team, :update?
    return render json: { error: 'At least one kanban is required' }, status: :unprocessable_entity if @team.kanbans.count <= 1

    @kanban.destroy!
    normalize_positions!
    head :ok
  end

  def set_default
    authorize @team, :update?
    @team.kanbans.where.not(id: @kanban.id).update_all(is_default: false)
    @kanban.update!(is_default: true)
    render :show
  end

  def reorder
    authorize @team, :update?
    ordered_ids = Array(params[:kanban_ids]).map(&:to_i)
    return head :ok if ordered_ids.empty?

    kanbans = @team.kanbans.where(id: ordered_ids).index_by(&:id)
    ordered_ids.each_with_index do |kanban_id, index|
      kanban = kanbans[kanban_id]
      next unless kanban

      kanban.update!(position: index)
    end

    normalize_positions!
    @kanbans = @team.kanbans.includes(columns: :label).ordered
    render :index
  end

  private

  def set_team
    @team = Current.account.teams.find(params[:team_id])
    ensure_team_access!(@team)
  end

  def set_kanban
    @kanban = @team.kanbans.find(params[:id])
  end

  def kanban_params
    params.require(:kanban).permit(:name, :description, :is_default, :initial_stage_label_id, column_label_ids: [])
  end

  def sync_columns!(kanban)
    label_ids = Array(kanban_params[:column_label_ids]).reject(&:blank?).map(&:to_i)
    allowed_labels = Current.account.labels.where(id: label_ids).index_by(&:id)
    if kanban.initial_stage_label_id.present? && !label_ids.include?(kanban.initial_stage_label_id)
      kanban.update_column(:initial_stage_label_id, nil)
    end

    kanban.columns.where.not(label_id: label_ids).destroy_all

    label_ids.each_with_index do |label_id, index|
      next unless allowed_labels[label_id]

      column = kanban.columns.find_or_initialize_by(label_id: label_id)
      column.account = Current.account
      column.position = index
      column.save!
    end
  end

  def ensure_default_kanban!
    return unless @team.kanbans.empty?

    kanban = @team.kanbans.create!(
      account: Current.account,
      name: "#{@team.name} default",
      is_default: true,
      position: 0
    )

    labels_from_team_conversations.each_with_index do |label, index|
      kanban.columns.create!(
        account: Current.account,
        label: label,
        position: index
      )
    end
  end

  def labels_from_team_conversations
    team_conversations = Current.account.conversations.where(team_id: @team.id)
    titles = team_conversations.flat_map(&:cached_label_list_array).uniq
    return [] if titles.blank?

    Current.account.labels.where(title: titles).reorder(:position, :title).to_a
  end

  def ensure_team_access!(team)
    return if Current.account_user.administrator?
    return if team.members.exists?(id: Current.user.id)

    raise Pundit::NotAuthorizedError
  end

  def normalize_positions!
    @team.kanbans.ordered.each_with_index do |kanban, index|
      next if kanban.position == index

      kanban.update_column(:position, index)
    end
  end
end
