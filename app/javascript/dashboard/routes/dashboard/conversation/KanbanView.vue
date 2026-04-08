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

const uiFlags = ref({ isLoading: false, isMoving: false });
const isDragging = ref(false);
const boardScroller = ref(null);
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const store = useStore();

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
        detailsError.value =
          'Nao foi possivel carregar os detalhes completos desta conversa.';
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

onMounted(fetchBoard);
watch(() => route.fullPath, fetchBoard);
</script>

<template>
  <div class="flex w-full min-w-0 h-full bg-n-background">
    <div class="flex flex-col flex-1 min-w-0 p-4 gap-4">
      <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-3">
      <h2 class="text-base font-medium text-n-slate-12 shrink-0">
        {{
          isGeneralKanban
            ? 'Kanban Geral'
            : currentKanbanMeta?.name || $t('CONVERSATION.KANBAN.TITLE')
        }}
      </h2>
      <div
        class="w-full lg:w-auto flex flex-col sm:flex-row sm:items-center gap-2 rounded-lg border border-n-alpha-2 bg-n-solid-1 px-3 py-2"
      >
        <button
          v-if="isTeamKanbanBoard"
          class="h-9 px-3 text-sm leading-none rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
          type="button"
          @click="backToKanbanList"
        >
          Voltar para lista
        </button>
        <div v-if="isTeamKanbanBoard" class="hidden sm:block h-5 w-px bg-n-alpha-2 mx-1" />
        <div class="flex items-center gap-2">
        <button
          class="h-9 px-2 text-sm leading-none rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
          type="button"
          @click="scrollBoard('left')"
        >
          ←
        </button>
        <button
          class="h-9 px-2 text-sm leading-none rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
          type="button"
          @click="scrollBoard('right')"
        >
          →
        </button>
        <button
          class="h-9 px-2 text-sm leading-none rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
          type="button"
          @click="scrollToBoardEnd"
        >
          ⇥
        </button>
        <button
          class="h-9 px-3 text-sm leading-none rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50"
          :disabled="uiFlags.isLoading || uiFlags.isMoving"
          @click="fetchBoard"
        >
          {{ $t('CONVERSATION.KANBAN.REFRESH') }}
        </button>
        </div>
      </div>
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
        <div class="flex w-max gap-3 pr-10">
        <div
          v-for="column in columns"
          :key="column.id || 'backlog'"
          class="w-[300px] shrink-0 rounded-lg border border-n-alpha-2 bg-n-solid-1 flex flex-col"
        >
          <div class="px-3 py-2 border-b border-n-alpha-2 flex items-center justify-between">
            <p class="text-sm font-medium text-n-slate-12">
              {{
                !isGeneralKanban && !column.id
                  ? $t('CONVERSATION.KANBAN.BACKLOG')
                  : isGeneralKanban
                    ? statusLabel(column.title)
                    : column.title
              }}
            </p>
            <span class="text-xs text-n-slate-10">{{ column.conversations.length }}</span>
          </div>

          <Draggable
            v-model="column.conversations"
            item-key="id"
            group="kanban-conversations"
            class="p-2 flex flex-col gap-2 min-h-20 max-h-[calc(100vh-220px)] overflow-y-auto"
            @start="isDragging = true"
            @end="setTimeout(() => { isDragging = false; }, 0)"
            @change="event => onDrop(event, column)"
          >
            <template #item="{ element }">
              <button
                type="button"
                class="w-full rounded-md border border-n-alpha-2 bg-n-solid-2 p-2 text-left hover:border-n-brand-6 hover:bg-n-alpha-1"
                @click="openConversation(element)"
              >
                <div class="flex items-center justify-between gap-2 mb-1">
                  <p class="text-xs text-n-slate-10 truncate">#{{ element.display_id }}</p>
                  <span
                    class="px-1.5 py-0.5 rounded text-[10px] uppercase tracking-wide truncate"
                    :class="statusBadgeClass(element.status)"
                  >
                    {{ statusLabel(element.status) }}
                  </span>
                </div>
                <div class="flex items-center gap-2">
                  <Avatar
                    :name="
                      element.contact_name || $t('CONVERSATION.KANBAN.UNNAMED_CONTACT')
                    "
                    :src="element.contact_thumbnail"
                    :size="22"
                    rounded-full
                  />
                  <p class="text-sm text-n-slate-12 font-medium truncate">
                    {{ element.contact_name || $t('CONVERSATION.KANBAN.UNNAMED_CONTACT') }}
                  </p>
                </div>
                <p class="text-xs text-n-slate-11 truncate mt-1">{{ element.inbox_name }}</p>
                <p
                  v-if="isGeneralKanban && element.team_name"
                  class="text-xs text-n-slate-10 truncate"
                >
                  Time: {{ element.team_name }}
                </p>
                <div v-if="element.assignee_name" class="flex items-center gap-1.5 mt-1">
                  <Avatar
                    :name="element.assignee_name"
                    :src="element.assignee_thumbnail"
                    :size="16"
                    rounded-full
                  />
                  <p class="text-xs text-n-slate-11 truncate">{{ element.assignee_name }}</p>
                </div>
                <p class="text-[11px] text-n-slate-10 truncate mt-1">
                  {{ formatLastActivity(element.last_activity_at) }}
                </p>
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
      class="w-[390px] h-full shrink-0 border-l border-n-alpha-2 bg-n-solid-1 overflow-y-auto"
    >
      <div class="flex items-center justify-between px-3 py-2 border-b border-n-alpha-2">
        <p class="text-sm font-medium text-n-slate-12 mb-0">Detalhes da conversa</p>
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="h-8 px-2 text-xs rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
            @click="goToFullConversation"
          >
            Ir para conversa
          </button>
          <button
            type="button"
            class="h-8 px-2 text-xs rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
            @click="closeDetailsPanel"
          >
            Fechar
          </button>
        </div>
      </div>
      <div v-if="isDetailsLoading" class="p-4 text-sm text-n-slate-11">
        Carregando detalhes...
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

