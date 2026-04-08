<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import Draggable from 'vuedraggable';
import conversationsAPI from 'dashboard/api/conversations';
import teamsAPI from 'dashboard/api/teams';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ContactPanel from './ContactPanel.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';

const uiFlags = ref({ isLoading: false, isMoving: false });
const isDragging = ref(false);
const boardScroller = ref(null);
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const store = useStore();
const { isAdmin } = useAdmin();
const { accountScopedRoute } = useAccount();

const isGeneralKanban = computed(() => route.name === 'kanban_general');
const isTeamKanbanBoard = computed(() => route.name === 'kanban_team_board');
const currentTeamId = computed(() => route.params.teamId);
const currentKanbanId = computed(() => route.params.kanbanId);
const currentKanbanMeta = ref(null);
const isDetailsOpen = ref(false);
const isDetailsLoading = ref(false);
const detailsError = ref('');
const selectedConversation = ref(null);
const selectedConversationDisplayId = ref(null);

const ensureBacklogColumn = inputColumns => {
  const normalizedColumns = Array.isArray(inputColumns) ? inputColumns : [];
  const hasBacklog = normalizedColumns.some(column => column?.id == null);
  if (hasBacklog) {
    return normalizedColumns;
  }

  return [{ id: null, title: 'backlog', conversations: [] }, ...normalizedColumns];
};

const columns = ref([]);

const fetchBoard = async () => {
  uiFlags.value.isLoading = true;
  try {
    const params = {};
    if (isTeamKanbanBoard.value) {
      params.team_id = currentTeamId.value;
      params.team_kanban_id = currentKanbanId.value;
      const { data: kanbansData } = await teamsAPI.getKanbans(currentTeamId.value);
      currentKanbanMeta.value = (kanbansData?.payload || []).find(
        item => String(item.id) === String(currentKanbanId.value)
      );
    }
    const { data } = isGeneralKanban.value
      ? await conversationsAPI.getKanbanGeneral(params)
      : await conversationsAPI.getKanban(params);
    columns.value = isGeneralKanban.value
      ? data?.payload?.columns || []
      : ensureBacklogColumn(data?.payload?.columns);
  } finally {
    uiFlags.value.isLoading = false;
  }
};

const onDrop = async (event, targetColumn) => {
  if (!event?.added?.element) {
    return;
  }

  const movedConversation = event.added.element;
  uiFlags.value.isMoving = true;
  try {
    if (isGeneralKanban.value) {
      await conversationsAPI.moveStatus(movedConversation.display_id, targetColumn.id);
    } else {
      await conversationsAPI.moveStage(movedConversation.display_id, targetColumn.id);
    }
  } catch (error) {
    await fetchBoard();
  } finally {
    uiFlags.value.isMoving = false;
  }
};

const formatLastActivity = lastActivityAt => {
  if (!lastActivityAt) {
    return '--';
  }
  return new Date(lastActivityAt).toLocaleString();
};

const statusBadgeClass = status => {
  const statusClassMap = {
    open: 'bg-n-teal-3 text-n-teal-11',
    resolved: 'bg-n-slate-3 text-n-slate-11',
    pending: 'bg-n-amber-3 text-n-amber-11',
    snoozed: 'bg-n-ruby-3 text-n-ruby-11',
  };

  return statusClassMap[status] || 'bg-n-alpha-2 text-n-slate-11';
};

const statusLabel = status => {
  if (!status) return '--';
  return t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${status}.TEXT`);
};

const boardTitle = computed(() =>
  isGeneralKanban.value
    ? t('CONVERSATION.KANBAN.GENERAL_TITLE')
    : currentKanbanMeta.value?.name || t('CONVERSATION.KANBAN.TITLE')
);

const boardSubtitle = computed(() =>
  isGeneralKanban.value
    ? t('CONVERSATION.KANBAN.SUBTITLE_GENERAL')
    : t('CONVERSATION.KANBAN.SUBTITLE_TEAM')
);

const columnAccentClass = column => {
  if (!isGeneralKanban.value && column?.id == null) {
    return 'border-l-n-slate-8';
  }
  return 'border-l-n-brand-9';
};

const cardLabelsPreview = labels => {
  if (!Array.isArray(labels) || !labels.length) {
    return { items: [], more: 0 };
  }
  const max = 3;
  return {
    items: labels.slice(0, max),
    more: Math.max(0, labels.length - max),
  };
};

const scrollBoard = direction => {
  boardScroller.value?.scrollBy({
    left: direction === 'right' ? 360 : -360,
    behavior: 'smooth',
  });
};

const scrollToBoardEnd = () => {
  if (!boardScroller.value) return;
  boardScroller.value.scrollTo({
    left: boardScroller.value.scrollWidth,
    behavior: 'smooth',
  });
};

const openConversation = async conversation => {
  if (isDragging.value) {
    return;
  }
  isDetailsOpen.value = true;
  isDetailsLoading.value = true;
  detailsError.value = '';
  selectedConversation.value = null;
  selectedConversationDisplayId.value = conversation.display_id;
  try {
    await store.dispatch('getConversation', conversation.display_id);
    const detailedConversation = store.getters.getConversationById(
      conversation.id
    );

    if (detailedConversation?.id && detailedConversation?.meta?.sender?.id) {
      selectedConversation.value = detailedConversation;
      store.commit('SET_CURRENT_CHAT_WINDOW', detailedConversation);
    } else {
      const { data } = await conversationsAPI.show(conversation.display_id);
      if (data?.meta?.sender?.id) {
        selectedConversation.value = data;
        store.commit('SET_CURRENT_CHAT_WINDOW', data);
      } else {
        detailsError.value = t('CONVERSATION.KANBAN.DETAILS_ERROR');
      }
    }
  } finally {
    isDetailsLoading.value = false;
  }
};

const goToFullConversation = () => {
  const displayId =
    selectedConversation.value?.display_id || selectedConversationDisplayId.value;
  if (!displayId) return;
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: displayId,
    },
  });
};

const closeDetailsPanel = () => {
  isDetailsOpen.value = false;
  isDetailsLoading.value = false;
  detailsError.value = '';
  selectedConversation.value = null;
  selectedConversationDisplayId.value = null;
};

const backToKanbanList = () => {
  router.push({
    name: 'kanban_teams_hub',
    params: { accountId: route.params.accountId },
  });
};

const goToAutomations = () => {
  router.push(accountScopedRoute('automation_list'));
};

onMounted(fetchBoard);
watch(() => route.fullPath, fetchBoard);
</script>

<template>
  <div class="flex w-full min-w-0 h-full bg-n-background">
    <div class="flex flex-col flex-1 min-w-0 p-4 lg:p-5 gap-4">
      <div
        class="flex flex-col lg:flex-row lg:items-end lg:justify-between gap-4 rounded-xl border border-n-alpha-2 bg-n-solid-1 px-4 py-4 shadow-sm"
      >
        <div class="min-w-0 space-y-1">
          <p
            class="text-[11px] font-semibold uppercase tracking-wider text-n-slate-10 mb-0"
          >
            {{ $t('CONVERSATION.KANBAN.CRM_BADGE') }}
          </p>
          <h1 class="text-lg font-semibold text-n-slate-12 tracking-tight truncate mb-0">
            {{ boardTitle }}
          </h1>
          <p class="text-sm text-n-slate-11 mb-0 max-w-prose">
            {{ boardSubtitle }}
          </p>
        </div>
        <div
          class="w-full lg:w-auto flex flex-col sm:flex-row sm:items-center gap-2 shrink-0"
        >
          <button
            v-if="isTeamKanbanBoard"
            class="h-9 px-3 text-sm font-medium leading-none rounded-lg border border-n-alpha-2 bg-n-background text-n-slate-12 hover:bg-n-alpha-2"
            type="button"
            @click="backToKanbanList"
          >
            {{ $t('CONVERSATION.KANBAN.BACK_TO_LIST') }}
          </button>
          <div
            v-if="isTeamKanbanBoard"
            class="hidden sm:block h-5 w-px bg-n-alpha-2 mx-1"
          />
          <div
            class="flex items-center gap-1.5 rounded-lg border border-n-alpha-2 bg-n-background p-1"
          >
            <button
              class="h-8 w-8 text-sm font-medium leading-none rounded-md text-n-slate-12 hover:bg-n-alpha-2"
              type="button"
              @click="scrollBoard('left')"
            >
              ←
            </button>
            <button
              class="h-8 w-8 text-sm font-medium leading-none rounded-md text-n-slate-12 hover:bg-n-alpha-2"
              type="button"
              @click="scrollBoard('right')"
            >
              →
            </button>
            <button
              class="h-8 w-8 text-sm font-medium leading-none rounded-md text-n-slate-12 hover:bg-n-alpha-2"
              type="button"
              @click="scrollToBoardEnd"
            >
              ⇥
            </button>
            <button
              class="h-8 px-3 text-xs font-semibold leading-none rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50"
              :disabled="uiFlags.isLoading || uiFlags.isMoving"
              type="button"
              @click="fetchBoard"
            >
              {{ $t('CONVERSATION.KANBAN.REFRESH') }}
            </button>
          </div>
        </div>
      </div>

      <div
        v-if="isAdmin"
        class="rounded-xl border border-n-alpha-2 bg-n-solid-1 px-4 py-3 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3"
      >
        <p class="text-xs text-n-slate-11 mb-0 max-w-3xl leading-relaxed">
          {{
            isGeneralKanban
              ? $t('CONVERSATION.KANBAN.AUTOMATIONS_HINT_GENERAL')
              : $t('CONVERSATION.KANBAN.AUTOMATIONS_HINT_TEAM')
          }}
        </p>
        <button
          type="button"
          class="h-9 shrink-0 px-3 text-xs font-semibold rounded-lg border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2 whitespace-nowrap"
          @click="goToAutomations"
        >
          {{ $t('CONVERSATION.KANBAN.AUTOMATIONS') }}
        </button>
      </div>

      <div
        v-if="uiFlags.isLoading"
        class="flex items-center justify-center h-full text-n-slate-11 gap-2"
      >
        <span>{{ $t('CONVERSATION.KANBAN.LOADING') }}</span>
        <Spinner class="size-5" />
      </div>

      <div
        v-else
        ref="boardScroller"
        class="flex-1 min-h-0 w-full overflow-x-auto overflow-y-hidden pb-4"
      >
        <div class="flex w-max gap-4 pr-10">
        <div
          v-for="column in columns"
          :key="column.id || 'backlog'"
          class="w-[320px] shrink-0 flex flex-col rounded-xl bg-n-solid-1 shadow-sm ring-1 ring-n-alpha-2"
        >
          <div
            class="flex items-center justify-between gap-2 px-3 py-3 border-b border-n-alpha-2 bg-n-alpha-1 rounded-t-xl border-l-4 pl-3"
            :class="columnAccentClass(column)"
          >
            <div class="min-w-0">
              <p class="text-sm font-semibold text-n-slate-12 truncate mb-0">
                {{
                  !isGeneralKanban && !column.id
                    ? $t('CONVERSATION.KANBAN.BACKLOG')
                    : isGeneralKanban
                      ? statusLabel(column.title)
                      : column.title
                }}
              </p>
              <p class="text-[11px] text-n-slate-10 mb-0 mt-0.5">
                {{ $t('CONVERSATION.KANBAN.STAGE_TOTAL', { count: column.conversations.length }) }}
              </p>
            </div>
            <span
              class="shrink-0 tabular-nums rounded-full bg-n-solid-2 px-2.5 py-1 text-xs font-semibold text-n-slate-12 ring-1 ring-n-alpha-2"
            >
              {{ column.conversations.length }}
            </span>
          </div>

          <Draggable
            v-model="column.conversations"
            item-key="id"
            group="kanban-conversations"
            class="p-2.5 flex flex-col gap-2.5 min-h-24 max-h-[calc(100vh-240px)] overflow-y-auto"
            @start="isDragging = true"
            @end="setTimeout(() => { isDragging = false; }, 0)"
            @change="event => onDrop(event, column)"
          >
            <template #item="{ element }">
              <button
                type="button"
                class="group w-full rounded-xl bg-n-solid-1 p-3 text-left ring-1 ring-n-alpha-2 transition-all hover:ring-n-brand/35 hover:shadow-sm"
                @click="openConversation(element)"
              >
                <div class="flex items-start justify-between gap-2 mb-2">
                  <p
                    class="text-[11px] font-semibold tabular-nums text-n-slate-10 uppercase tracking-wide mb-0"
                  >
                    {{ $t('CONVERSATION.KANBAN.REF_LABEL') }}
                    #{{ element.display_id }}
                  </p>
                  <span
                    class="shrink-0 max-w-[120px] px-2 py-0.5 rounded-md text-[10px] font-semibold uppercase tracking-wide truncate"
                    :class="statusBadgeClass(element.status)"
                  >
                    {{ statusLabel(element.status) }}
                  </span>
                </div>
                <div class="flex items-center gap-3">
                  <Avatar
                    :name="
                      element.contact_name || $t('CONVERSATION.KANBAN.UNNAMED_CONTACT')
                    "
                    :src="element.contact_thumbnail"
                    :size="28"
                    rounded-full
                  />
                  <p class="text-sm text-n-slate-12 font-semibold leading-snug truncate mb-0">
                    {{ element.contact_name || $t('CONVERSATION.KANBAN.UNNAMED_CONTACT') }}
                  </p>
                </div>

                <div
                  v-if="cardLabelsPreview(element.labels).items.length"
                  class="flex flex-wrap gap-1 mt-2.5"
                >
                  <span
                    v-for="tag in cardLabelsPreview(element.labels).items"
                    :key="tag"
                    class="max-w-full truncate rounded-md bg-n-alpha-2 px-2 py-0.5 text-[10px] font-medium text-n-slate-11"
                  >
                    {{ tag }}
                  </span>
                  <span
                    v-if="cardLabelsPreview(element.labels).more"
                    class="rounded-md bg-n-solid-2 px-2 py-0.5 text-[10px] font-semibold text-n-slate-10"
                  >
                    {{ $t('CONVERSATION.KANBAN.TAGS_MORE', { count: cardLabelsPreview(element.labels).more }) }}
                  </span>
                </div>

                <div
                  class="mt-2.5 flex flex-col gap-1 border-t border-n-alpha-2 pt-2.5 text-xs text-n-slate-11"
                >
                  <p v-if="element.inbox_name" class="truncate mb-0">
                    <span class="text-n-slate-10">{{ $t('CONVERSATION.KANBAN.INBOX') }}:</span>
                    {{ element.inbox_name }}
                  </p>
                  <p
                    v-if="isGeneralKanban && element.team_name"
                    class="truncate mb-0"
                  >
                    <span class="text-n-slate-10">{{ $t('CONVERSATION.KANBAN.TEAM') }}:</span>
                    {{ element.team_name }}
                  </p>
                  <div v-if="element.assignee_name" class="flex items-center gap-2 min-w-0">
                    <Avatar
                      :name="element.assignee_name"
                      :src="element.assignee_thumbnail"
                      :size="18"
                      rounded-full
                    />
                    <p class="truncate mb-0">
                      <span class="text-n-slate-10">{{ $t('CONVERSATION.KANBAN.OWNER') }}:</span>
                      {{ element.assignee_name }}
                    </p>
                  </div>
                  <p class="text-[11px] text-n-slate-10 mb-0">
                    <span class="font-medium text-n-slate-11">{{ $t('CONVERSATION.KANBAN.LAST_ACTIVITY') }}:</span>
                    {{ formatLastActivity(element.last_activity_at) }}
                  </p>
                </div>
              </button>
            </template>
          </Draggable>
        </div>
        <div class="w-2 shrink-0" aria-hidden="true" />
        </div>
      </div>
    </div>

    <aside
      v-if="isDetailsOpen"
      class="w-full max-w-[400px] h-full shrink-0 border-l border-n-alpha-2 bg-n-background overflow-y-auto"
    >
      <div
        class="sticky top-0 z-10 border-b border-n-alpha-2 bg-n-solid-1/90 backdrop-blur-md px-3 py-2.5 sm:px-4"
      >
        <div
          class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between sm:gap-3"
        >
          <div class="min-w-0">
            <p class="text-[10px] font-semibold uppercase tracking-wider text-n-slate-10 mb-0.5">
              {{ $t('CONVERSATION.KANBAN.CRM_BADGE') }}
            </p>
            <p class="text-sm font-semibold text-n-slate-12 mb-0 tracking-tight">
              {{ $t('CONVERSATION.KANBAN.DETAILS_TITLE') }}
            </p>
          </div>
          <div
            class="flex items-center justify-end gap-1.5 shrink-0 flex-wrap"
          >
            <button
              type="button"
              class="inline-flex items-center justify-center h-7 min-h-7 px-2.5 text-[11px] font-medium rounded-md border border-n-brand/40 text-n-brand bg-n-solid-1 hover:bg-n-brand hover:text-white hover:border-n-brand transition-colors whitespace-nowrap"
              @click="goToFullConversation"
            >
              {{ $t('CONVERSATION.KANBAN.OPEN_CONVERSATION') }}
            </button>
            <button
              type="button"
              class="inline-flex items-center justify-center h-7 min-h-7 px-2 text-[11px] font-medium rounded-md text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
              @click="closeDetailsPanel"
            >
              {{ $t('CONVERSATION.KANBAN.CLOSE') }}
            </button>
          </div>
        </div>
      </div>
      <div v-if="isDetailsLoading" class="p-4 text-sm text-n-slate-11">
        {{ $t('CONVERSATION.KANBAN.LOADING_DETAILS') }}
      </div>
      <div v-else-if="detailsError" class="p-4 text-sm text-n-ruby-11">
        {{ detailsError }}
      </div>
      <ContactPanel
        v-else-if="selectedConversation?.id"
        :conversation-id="selectedConversation.id"
        :inbox-id="selectedConversation.inbox_id"
        @panelClose="closeDetailsPanel"
      />
    </aside>
  </div>
</template>

