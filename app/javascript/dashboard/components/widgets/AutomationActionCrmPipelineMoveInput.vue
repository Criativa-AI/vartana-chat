<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => ['nil', null],
  },
  dropdownMaxHeight: {
    type: String,
    default: 'max-h-80',
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const teams = useMapGetter('teams/getTeams');
const labels = useMapGetter('labels/getLabels');

const PLACEHOLDER_STAGE_ID = '__crm_no_stage__';

const normalizeId = raw => {
  if (raw === null || raw === undefined) return null;
  if (typeof raw === 'object' && raw !== null && 'id' in raw) return raw.id;
  return raw;
};

const teamOptions = computed(() => [
  { id: 'nil', name: t('AUTOMATION.ACTION.CRM_MOVE_KEEP_TEAM') },
  ...(teams.value || []).map(tm => ({ id: tm.id, name: tm.name })),
]);

const labelOptions = computed(() => [
  {
    id: PLACEHOLDER_STAGE_ID,
    name: t('AUTOMATION.ACTION.CRM_MOVE_STAGE_PLACEHOLDER'),
  },
  ...(labels.value || []).map(l => ({ id: l.id, name: l.title })),
]);

const selectedTeam = computed({
  get() {
    const tid = normalizeId(props.modelValue?.[0]);
    return (
      teamOptions.value.find(o => o.id === tid) || teamOptions.value[0] || null
    );
  },
  set(opt) {
    if (!opt) return;
    const teamVal = opt.id ?? opt;
    const labelVal = props.modelValue?.[1];
    emit('update:modelValue', [teamVal, normalizeId(labelVal)]);
  },
});

const selectedLabel = computed({
  get() {
    const lid = normalizeId(props.modelValue?.[1]);
    if (
      lid === null ||
      lid === undefined ||
      lid === PLACEHOLDER_STAGE_ID ||
      !labelOptions.value.some(o => o.id === lid)
    ) {
      return labelOptions.value[0];
    }

    return labelOptions.value.find(o => o.id === lid);
  },
  set(opt) {
    const teamRaw = props.modelValue?.[0];
    const teamVal = normalizeId(teamRaw) ?? 'nil';
    if (!opt) {
      emit('update:modelValue', [teamRaw ?? teamVal, null]);
      return;
    }
    const lid = opt.id ?? opt;
    const realLid = lid === PLACEHOLDER_STAGE_ID ? null : lid;
    emit('update:modelValue', [teamRaw ?? teamVal, realLid]);
  },
});
</script>

<template>
  <div class="flex flex-col gap-3 w-full min-w-0">
    <div class="flex flex-col gap-1 min-w-0">
      <span class="text-xs text-n-slate-11">
        {{ $t('AUTOMATION.ACTION.CRM_MOVE_TEAM_LABEL') }}
      </span>
      <SingleSelect
        v-model="selectedTeam"
        :options="teamOptions"
        :dropdown-max-height="dropdownMaxHeight"
        disable-deselect
      />
    </div>
    <div class="flex flex-col gap-1 min-w-0">
      <span class="text-xs text-n-slate-11">
        {{ $t('AUTOMATION.ACTION.CRM_MOVE_STAGE_LABEL') }}
      </span>
      <SingleSelect
        v-model="selectedLabel"
        :options="labelOptions"
        :dropdown-max-height="dropdownMaxHeight"
        disable-deselect
      />
    </div>
    <p class="text-xs text-n-slate-11 mb-0 leading-relaxed">
      {{ $t('AUTOMATION.ACTION.CRM_MOVE_HELP') }}
    </p>
  </div>
</template>
