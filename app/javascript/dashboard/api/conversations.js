/* global axios */
import ApiClient from './ApiClient';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  getKanban(params = {}) {
    return axios.get(`${this.url}/kanban`, { params });
  }

  getKanbanGeneral(params = {}) {
    return axios.get(`${this.url}/kanban_general`, { params });
  }

  moveStage(conversationID, stageLabelId) {
    return axios.post(`${this.url}/${conversationID}/move_stage`, {
      stage_label_id: stageLabelId,
    });
  }

  moveStatus(conversationID, status) {
    return axios.post(`${this.url}/${conversationID}/move_status`, { status });
  }
}

export default new ConversationApi();
