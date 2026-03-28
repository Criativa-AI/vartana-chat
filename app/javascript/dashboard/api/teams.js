/* global axios */
// import ApiClient from './ApiClient';
import CacheEnabledApiClient from './CacheEnabledApiClient';

export class TeamsAPI extends CacheEnabledApiClient {
  constructor() {
    super('teams', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'team';
  }

  // eslint-disable-next-line class-methods-use-this
  extractDataFromResponse(response) {
    return response.data;
  }

  // eslint-disable-next-line class-methods-use-this
  marshallData(dataToParse) {
    return { data: dataToParse };
  }

  getAgents({ teamId }) {
    return axios.get(`${this.url}/${teamId}/team_members`);
  }

  addAgents({ teamId, agentsList }) {
    return axios.post(`${this.url}/${teamId}/team_members`, {
      user_ids: agentsList,
    });
  }

  updateAgents({ teamId, agentsList }) {
    return axios.patch(`${this.url}/${teamId}/team_members`, {
      user_ids: agentsList,
    });
  }

  getKanbans(teamId) {
    return axios.get(`${this.url}/${teamId}/kanbans`);
  }

  createKanban(teamId, kanban) {
    return axios.post(`${this.url}/${teamId}/kanbans`, { kanban });
  }

  updateKanban(teamId, kanbanId, kanban) {
    return axios.patch(`${this.url}/${teamId}/kanbans/${kanbanId}`, { kanban });
  }

  deleteKanban(teamId, kanbanId) {
    return axios.delete(`${this.url}/${teamId}/kanbans/${kanbanId}`);
  }

  setDefaultKanban(teamId, kanbanId) {
    return axios.post(`${this.url}/${teamId}/kanbans/${kanbanId}/set_default`);
  }

  reorderKanbans(teamId, kanbanIds) {
    return axios.patch(`${this.url}/${teamId}/kanbans/reorder`, {
      kanban_ids: kanbanIds,
    });
  }
}

export default new TeamsAPI();
