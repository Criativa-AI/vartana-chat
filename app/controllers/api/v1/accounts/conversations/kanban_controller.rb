class Api::V1::Accounts::Conversations::KanbanController < Api::V1::Accounts::BaseController
  include ConversationsCrmFeatureGate

  BACKLOG_COLUMN_TITLE = 'backlog'.freeze
  GENERAL_STATUSES = %w[open pending snoozed resolved].freeze
  before_action :set_conversation, only: [:move_stage, :move_status]

  CONVERSATION_LIMIT = 200

  def index
    authorize Conversation, :index?

    scoped_conversations = apply_team_filter(policy_scope(Current.account.conversations))
    @conversations = apply_filters(scoped_conversations)
                       .includes(:contact, :assignee, :inbox)
                       .order(last_activity_at: :desc)
                       .limit(CONVERSATION_LIMIT)

    @stage_labels = resolve_stage_labels
    @stage_titles = @stage_labels.map(&:title)

    grouped = @conversations.group_by { |conversation| stage_for(conversation) }
    @columns = [
      { id: nil, title: BACKLOG_COLUMN_TITLE, conversations: grouped[nil] || [] }
    ]
    @columns += @stage_labels.map do |label|
      { id: label.id, title: label.title, conversations: grouped[label.title] || [] }
    end
  end

  def general
    authorize Conversation, :index?

    scoped_conversations = apply_team_filter(policy_scope(Current.account.conversations))
    @conversations = apply_filters(scoped_conversations)
                       .includes(:contact, :assignee, :inbox)
                       .order(last_activity_at: :desc)
                       .limit(CONVERSATION_LIMIT)

    grouped = @conversations.group_by(&:status)
    @columns = GENERAL_STATUSES.map do |status|
      { id: status, title: status, conversations: grouped[status] || [] }
    end

    render :index
  end

  def move_stage
    stage = Conversations::PipelineStageService.new(
      conversation: @conversation,
      account: Current.account
    ).assign_stage!(params[:stage_label_id])

    render json: {
      payload: {
        conversation_id: @conversation.display_id,
        stage_label_id: stage&.id
      }
    }
  end

  def move_status
    status = params[:status].to_s
    return render json: { error: 'Invalid status' }, status: :unprocessable_entity unless GENERAL_STATUSES.include?(status)

    @conversation.update!(status: status)
    render json: {
      payload: {
        conversation_id: @conversation.display_id,
        status: @conversation.status
      }
    }
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:id])
    authorize @conversation, :show?
  end

  def apply_filters(scope)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope = scope.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    scope
  end

  def apply_team_filter(scope)
    return scope if params[:team_id].blank?

    team = Current.account.teams.find(params[:team_id])
    ensure_team_access!(team)
    scope.where(team_id: team.id)
  end

  def resolve_stage_labels
    return labels_from_team_kanban if params[:team_id].present?

    stage_titles = @conversations.flat_map(&:cached_label_list_array).uniq
    Current.account.labels.where(title: stage_titles).reorder(:position, :title)
  end

  def labels_from_team_kanban
    team = Current.account.teams.find(params[:team_id])
    ensure_team_access!(team)
    kanban = if params[:team_kanban_id].present?
               team.kanbans.find(params[:team_kanban_id])
             else
               team.kanbans.order(is_default: :desc, id: :asc).first
             end
    return Current.account.labels.none unless kanban

    label_ids = kanban.columns.order(:position).pluck(:label_id)
    labels = Current.account.labels.where(id: label_ids).index_by(&:id)
    label_ids.map { |id| labels[id] }.compact
  end

  def ensure_team_access!(team)
    return if Current.account_user.administrator?
    return if team.members.exists?(id: Current.user.id)

    raise Pundit::NotAuthorizedError
  end

  def stage_for(conversation)
    labels = conversation.cached_label_list_array
    (@stage_titles & labels).first
  end
end

