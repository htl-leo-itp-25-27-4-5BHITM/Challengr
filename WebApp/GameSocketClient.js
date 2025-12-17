// GameClient.js
export class GameClient {
  constructor(playerId) {
    this.playerId = playerId;
    this.socket = null;
    this.listeners = {
      "battle-requested": [],
      "battle-updated": []
    };
  }

  connect() {
    this.socket = new WebSocket(`ws://localhost:8080/ws/game?playerId=${this.playerId}`);

    this.socket.onopen = () => console.log("WS open", this.playerId);
    this.socket.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      const list = this.listeners[msg.type] || [];
      list.forEach(cb => cb(msg));
    };
    this.socket.onerror = (e) => console.error("WS error", e);
  }

  on(type, cb) {
    if (!this.listeners[type]) this.listeners[type] = [];
    this.listeners[type].push(cb);
  }

  createBattle(toId, challengeId) {
    this.socket.send(JSON.stringify({
      type: "create-battle",
      fromId: this.playerId,
      toId,
      challengeId
    }));
  }

  updateBattleStatus(battleId, status) {
    this.socket.send(JSON.stringify({
      type: "update-battle-status",
      battleId,
      status
    }));
  }
}
