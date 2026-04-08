<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import teamsAPI from 'dashboard/api/teams';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { getRandomColor } from 'dashboard/helper/labelColor';

const route = useRoute();
const router = useRouter();
const store = useStore();
const teams = useMapGetter('teams/getMyTeams');
const labels = useMapGetter('labels/getLabels');

const loading = ref(false);
const search = ref('');
const kanbansByTeam = ref([]);
const favoriteIds = ref([]);
const recentIds = ref([]);
const formDialogRef = ref(null);
const deleteDialogRef = ref(null);
const saving = ref(false);
const deleting = ref(false);
const creatingLabel = ref(false);

const form = ref({
  mode: 'create',
  teamId: null,
  kanbanId: null,
  name: '',
  description: '',
  selectedStageLabelIds: [],
  initialStageLabelId: null,
  newLabelTitle: '',
});
const deletingKanban = ref(null);

const favoritesKey = computed(
  () => `kanban:favorites:${route.params.accountId}:${store.getters.getCurrentUserID}`
);
const recentKey = computed(
  () => `kanban:recent:${route.params.accountId}:${store.getters.getCurrentUserID}`
);

const filteredGroups = computed(() => {
  const query = search.value.trim().toLowerCase();
  if (!query) return kanbansByTeam.value;

  return kanbansByTeam.value
    .map(group => ({
      ...group,
      kanbans: group.kanbans.filter(kanban =>
        [kanban.name, kanban.description, group.team.name]
          .filter(Boolean)
          .join(' ')
          .toLowerCase()
          .includes(query)
      ),
    }))
    .filter(group => group.kanbans.length);
});

const isFavorite = id => favoriteIds.value.includes(id);
const isRecent = id => recentIds.value.includes(id);

const persistLocalState = () => {
  localStorage.setItem(favoritesKey.value, JSON.stringify(favoriteIds.value));
  localStorage.setItem(recentKey.value, JSON.stringify(recentIds.value.slice(0, 10)));
};

const loadLocalState = () => {
  favoriteIds.value = JSON.parse(localStorage.getItem(favoritesKey.value) || '[]');
  recentIds.value = JSON.parse(localStorage.getItem(recentKey.value) || '[]');
};

const fetchKanbans = async () => {
  loading.value = true;
  try {
    const groups = await Promise.all(
      teams.value.map(async team => {
        const { data } = await teamsAPI.getKanbans(team.id);
        return {
          team,
          kanbans: (data?.payload || []).sort((a, b) => a.position - b.position),
        };
      })
    );
    kanbansByTeam.value = groups;
  } finally {
    loading.value = false;
  }
};

const openBoard = (teamId, kanbanId) => {
  recentIds.value = [kanbanId, ...recentIds.value.filter(id => id !== kanbanId)];
  persistLocalState();
  router.push({
    name: 'kanban_team_board',
    params: { accountId: route.params.accountId, teamId, kanbanId },
  });
};

const toggleFavorite = kanbanId => {
  favoriteIds.value = isFavorite(kanbanId)
    ? favoriteIds.value.filter(id => id !== kanbanId)
    : [...favoriteIds.value, kanbanId];
  persistLocalState();
};

const openCreate = () => {
  form.value = {
    mode: 'create',
    teamId: teams.value[0]?.id || null,
    kanbanId: null,
    name: '',
    description: '',
    selectedStageLabelIds: [],
    initialStageLabelId: null,
    newLabelTitle: '',
  };
  formDialogRef.value?.open();
};

const openEdit = (teamId, kanban) => {
  form.value = {
    mode: 'edit',
    teamId,
    kanbanId: kanban.id,
    name: kanban.name,
    description: kanban.description || '',
    selectedStageLabelIds: (kanban.columns || []).map(column => column.label_id),
    initialStageLabelId: kanban.initial_stage_label_id || null,
    newLabelTitle: '',
  };
  formDialogRef.value?.open();
};

const openDelete = (teamId, kanban) => {
  deletingKanban.value = { teamId, ...kanban };
  deleteDialogRef.value?.open();
};

const submitForm = async () => {
  const payload = {
    name: form.value.name.trim(),
    description: form.value.description.trim() || null,
    column_label_ids: form.value.selectedStageLabelIds,
    initial_stage_label_id: form.value.initialStageLabelId,
  };
  if (!payload.name || !form.value.teamId || !payload.column_label_ids.length) return;

  saving.value = true;
  try {
    if (form.value.mode === 'create') {
      await teamsAPI.createKanban(form.value.teamId, payload);
    } else {
      await teamsAPI.updateKanban(form.value.teamId, form.value.kanbanId, payload);
    }
    formDialogRef.value?.close();
    await fetchKanbans();
  } finally {
    saving.value = false;
  }
};

const confirmDelete = async () => {
  if (!deletingKanban.value) return;

  deleting.value = true;
  try {
    await teamsAPI.deleteKanban(deletingKanban.value.teamId, deletingKanban.value.id);
    deleteDialogRef.value?.close();
    await fetchKanbans();
  } finally {
    deleting.value = false;
  }
};

const setDefault = async (teamId, kanbanId) => {
  await teamsAPI.setDefaultKanban(teamId, kanbanId);
  await fetchKanbans();
};

const moveKanban = async (teamId, kanbanId, direction) => {
  const group = kanbansByTeam.value.find(item => item.team.id === teamId);
  if (!group) return;
  const current = group.kanbans.find(item => item.id === kanbanId);
  if (!current) return;
  const targetPosition = current.position + direction;
  const target = group.kanbans.find(item => item.position === targetPosition);
  if (!target) return;

  const ordered = group.kanbans
    .map(item => {
      if (item.id === current.id) return { ...item, position: target.position };
      if (item.id === target.id) return { ...item, position: current.position };
      return item;
    })
    .sort((a, b) => a.position - b.position)
    .map(item => item.id);

  await teamsAPI.reorderKanbans(teamId, ordered);
  await fetchKanbans();
};

const createLabelFromForm = async () => {
  const title = form.value.newLabelTitle?.trim()?.toLowerCase();
  if (!title) return;
  creatingLabel.value = true;
  try {
    await store.dispatch('labels/create', {
      title,
      description: 'Etapa do kanban por time',
      color: getRandomColor(),
      show_on_sidebar: true,
    });
    await store.dispatch('labels/get');
    const created = labels.value.find(label => label.title === title);
    if (created) {
      form.value.selectedStageLabelIds = [
        ...new Set([...form.value.selectedStageLabelIds, created.id]),
      ];
      form.value.initialStageLabelId ||= created.id;
    }
    form.value.newLabelTitle = '';
  } finally {
    creatingLabel.value = false;
  }
};

const availableLabels = computed(() => {
  const selectedIds = new Set(form.value.selectedStageLabelIds);
  return labels.value.filter(label => !selectedIds.has(label.id));
});

const orderedSelectedLabels = computed(() => {
  const map = new Map(labels.value.map(label => [label.id, label]));
  return form.value.selectedStageLabelIds
    .map(id => map.get(id))
    .filter(Boolean);
});

const addStageLabel = labelId => {
  if (!labelId) return;
  if (form.value.selectedStageLabelIds.includes(labelId)) return;
  form.value.selectedStageLabelIds.push(labelId);
  form.value.initialStageLabelId ||= labelId;
};

const removeStageLabel = labelId => {
  form.value.selectedStageLabelIds = form.value.selectedStageLabelIds.filter(
    id => id !== labelId
  );
  if (form.value.initialStageLabelId === labelId) {
    form.value.initialStageLabelId = form.value.selectedStageLabelIds[0] || null;
  }
};

const moveStageLabel = (labelId, direction) => {
  const currentIndex = form.value.selectedStageLabelIds.indexOf(labelId);
  if (currentIndex < 0) return;
  const targetIndex = currentIndex + direction;
  if (targetIndex < 0 || targetIndex >= form.value.selectedStageLabelIds.length) return;

  const updated = [...form.value.selectedStageLabelIds];
  [updated[currentIndex], updated[targetIndex]] = [
    updated[targetIndex],
    updated[currentIndex],
  ];
  form.value.selectedStageLabelIds = updated;
};

onMounted(async () => {
  await store.dispatch('teams/get');
  await store.dispatch('labels/get');
  loadLocalState();
  await fetchKanbans();
});
</script>

<template>
  <div class="flex flex-col w-full min-w-0 h-full bg-n-background p-4 gap-4">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h2 class="text-base font-medium text-n-slate-12">Kanban por Time</h2>
        <p class="text-sm text-n-slate-11 mb-0">Escolha um fluxo para abrir o board</p>
      </div>
      <button
        class="h-9 px-3 text-sm rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
        type="button"
        @click="openCreate"
      >
        + Novo Kanban
      </button>
    </div>

    <div class="rounded-lg border border-n-alpha-2 bg-n-solid-1 p-3">
      <input
        v-model="search"
        type="text"
        placeholder="Buscar por time ou kanban"
        class="w-full h-9 px-3 text-sm rounded-md border border-n-alpha-2 bg-n-background text-n-slate-12"
      />
    </div>

    <div v-if="loading" class="text-sm text-n-slate-11">Carregando kanbans...</div>

    <div v-else class="flex flex-col gap-4 overflow-y-auto">
      <section
        v-for="group in filteredGroups"
        :key="group.team.id"
        class="rounded-lg border border-n-alpha-2 bg-n-solid-1 p-3"
      >
        <h3 class="text-sm font-medium text-n-slate-12 mb-3">{{ group.team.name }}</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
          <article
            v-for="kanban in group.kanbans"
            :key="kanban.id"
            class="rounded-md border border-n-alpha-2 bg-n-background p-3 flex flex-col gap-2"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <p class="text-sm font-medium text-n-slate-12 truncate mb-0">
                  {{ kanban.name }}
                </p>
                <p class="text-xs text-n-slate-11 truncate mb-0">
                  {{ kanban.description || 'Sem descricao' }}
                </p>
              </div>
              <button
                type="button"
                class="text-xs text-n-slate-11 hover:text-n-slate-12"
                @click="toggleFavorite(kanban.id)"
              >
                {{ isFavorite(kanban.id) ? '★' : '☆' }}
              </button>
            </div>

            <div class="flex items-center gap-2 text-[11px] text-n-slate-10">
              <span>{{ kanban.columns?.length || 0 }} etapas</span>
              <span v-if="kanban.is_default" class="px-1.5 py-0.5 rounded bg-n-teal-3 text-n-teal-11">
                padrao
              </span>
              <span v-if="isRecent(kanban.id)" class="px-1.5 py-0.5 rounded bg-n-amber-3 text-n-amber-11">
                recente
              </span>
            </div>

            <div class="flex items-center gap-2 flex-wrap">
              <button
                type="button"
                class="h-8 px-3 text-xs rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
                @click="openBoard(group.team.id, kanban.id)"
              >
                Abrir
              </button>
              <button
                type="button"
                class="h-8 px-2 text-xs rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
                @click="openEdit(group.team.id, kanban)"
              >
                Editar
              </button>
              <button
                type="button"
                class="h-8 px-2 text-xs rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
                @click="setDefault(group.team.id, kanban.id)"
              >
                Padrao
              </button>
              <button
                type="button"
                class="h-8 px-2 text-xs rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
                @click="moveKanban(group.team.id, kanban.id, -1)"
              >
                ↑
              </button>
              <button
                type="button"
                class="h-8 px-2 text-xs rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2"
                @click="moveKanban(group.team.id, kanban.id, 1)"
              >
                ↓
              </button>
              <button
                type="button"
                class="h-8 px-2 text-xs rounded-md border border-n-alpha-2 text-n-ruby-11 hover:bg-n-alpha-2"
                @click="openDelete(group.team.id, kanban)"
              >
                Excluir
              </button>
            </div>
          </article>
        </div>
      </section>
    </div>

    <Dialog
      ref="formDialogRef"
      :title="form.mode === 'create' ? 'Novo Kanban' : 'Editar Kanban'"
      description="Configure o fluxo do kanban por time"
      confirm-button-label="Salvar"
      cancel-button-label="Cancelar"
      :disable-confirm-button="!form.name || !form.teamId || !form.selectedStageLabelIds.length"
      :is-loading="saving"
      width="2xl"
      @confirm="submitForm"
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div class="flex flex-col gap-1">
          <label class="text-xs text-n-slate-11">Time</label>
          <select
            v-model="form.teamId"
            :disabled="form.mode === 'edit'"
            class="h-9 px-2 text-sm rounded-md border border-n-alpha-2 bg-n-solid-1 text-n-slate-12 disabled:opacity-60"
          >
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-xs text-n-slate-11">Nome</label>
          <input
            v-model="form.name"
            type="text"
            class="h-9 px-2 text-sm rounded-md border border-n-alpha-2 bg-n-solid-1 text-n-slate-12"
          />
        </div>
      </div>

      <div class="flex flex-col gap-1 mt-2">
        <label class="text-xs text-n-slate-11">Descricao</label>
        <textarea
          v-model="form.description"
          rows="2"
          class="px-2 py-2 text-sm rounded-md border border-n-alpha-2 bg-n-solid-1 text-n-slate-12"
        />
      </div>

      <div class="flex flex-col gap-2 mt-2">
        <p class="text-xs text-n-slate-11 mb-0">Etapas por etiqueta</p>
        <div class="flex items-center gap-2">
          <input
            v-model="form.newLabelTitle"
            type="text"
            placeholder="Criar nova etiqueta"
            class="flex-1 h-9 px-2 text-sm rounded-md border border-n-alpha-2 bg-n-solid-1 text-n-slate-12"
          />
          <button
            type="button"
            class="h-9 px-3 text-xs rounded-md border border-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50"
            :disabled="creatingLabel || !form.newLabelTitle"
            @click="createLabelFromForm"
          >
            + Etiqueta
          </button>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div class="rounded-md border border-n-alpha-2 p-2">
            <p class="text-xs text-n-slate-11 mb-2">Etiquetas disponiveis</p>
            <div class="max-h-40 overflow-y-auto">
              <button
                v-for="label in availableLabels"
                :key="label.id"
                type="button"
                class="w-full text-left px-2 py-1.5 text-sm rounded hover:bg-n-alpha-2 text-n-slate-12"
                @click="addStageLabel(label.id)"
              >
                + {{ label.title }}
              </button>
              <p v-if="!availableLabels.length" class="text-xs text-n-slate-10 mb-0 px-2 py-1">
                Sem etiquetas disponiveis
              </p>
            </div>
          </div>

          <div class="rounded-md border border-n-alpha-2 p-2">
            <p class="text-xs text-n-slate-11 mb-2">Ordem da esteira</p>
            <div class="max-h-40 overflow-y-auto flex flex-col gap-1">
              <div
                v-for="(label, index) in orderedSelectedLabels"
                :key="label.id"
                class="flex items-center gap-2 px-2 py-1.5 rounded bg-n-solid-1"
              >
                <input
                  :checked="form.initialStageLabelId === label.id"
                  type="radio"
                  name="initial-stage"
                  @change="form.initialStageLabelId = label.id"
                />
                <span class="text-sm text-n-slate-12 flex-1 truncate">
                  {{ index + 1 }}. {{ label.title }}
                </span>
                <button
                  type="button"
                  class="text-xs text-n-slate-11 hover:text-n-slate-12"
                  @click="moveStageLabel(label.id, -1)"
                >
                  ↑
                </button>
                <button
                  type="button"
                  class="text-xs text-n-slate-11 hover:text-n-slate-12"
                  @click="moveStageLabel(label.id, 1)"
                >
                  ↓
                </button>
                <button
                  type="button"
                  class="text-xs text-n-ruby-11 hover:text-n-ruby-12"
                  @click="removeStageLabel(label.id)"
                >
                  Remover
                </button>
              </div>
              <p v-if="!orderedSelectedLabels.length" class="text-xs text-n-slate-10 mb-0 px-2 py-1">
                Adicione pelo menos uma etapa
              </p>
            </div>
            <p class="text-[11px] text-n-slate-10 mt-2 mb-0">
              Selecione no radio qual e o estagio inicial.
            </p>
          </div>
        </div>
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      title="Excluir Kanban"
      description="Tem certeza que deseja excluir este kanban?"
      confirm-button-label="Excluir"
      cancel-button-label="Cancelar"
      :is-loading="deleting"
      @confirm="confirmDelete"
    />
  </div>
</template>
