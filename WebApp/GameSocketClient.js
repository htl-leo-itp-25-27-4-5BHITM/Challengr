// GameClient.js

export class GameClient {
  constructor(playerId) {
    this.playerId = playerId;
    this.socket = null;

    // Event-Callbacks
    this.handlers = {
      "battle-requested": [],
      "battle-updated": [],
      "battle-result": [],
      "battle-created": [],
      "battle-pending": [],
      "battle-question": []   // NEU: Wissen-Fragen
    };
  }

  // =====================
  // CONNECT / DISCONNECT
  // =====================

  connect() {
    if (this.socket) return;

    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const url = `${protocol}//${window.location.host}/ws/game?playerId=${this.playerId}`;
    this.socket = new WebSocket(url);

    this.socket.onopen = () => {
      console.log("🔌 WS connected (player", this.playerId, ")");
    };

    this.socket.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        console.log("⬇ WS message:", msg);
        this.handleIncoming(msg);
      } catch (e) {
        console.error("❌ WS parse error", e);
      }
    };

    this.socket.onclose = () => {
      console.log("🔌 WS disconnected");
      this.socket = null;
    };

    this.socket.onerror = (err) => {
      console.error("❌ WS error", err);
    };
  }

  disconnect() {
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
  }

  // =====================
  // EVENT SYSTEM (on / emit)
  // =====================

  on(type, callback) {
    if (!this.handlers[type]) {
      this.handlers[type] = [];
    }
    this.handlers[type].push(callback);
  }

  emit(type, payload) {
    if (!this.handlers[type]) return;
    this.handlers[type].forEach((cb) => cb(payload));
  }

  // =====================
  // SEND
  // =====================

  send(data) {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      console.warn("❌ WS not connected");
      return;
    }
    this.socket.send(JSON.stringify(data));
  }

  createBattle(toPlayerId, challengeId) {
    this.send({
      type: "create-battle",
      fromId: this.playerId,
      toId: toPlayerId,
      challengeId: challengeId
    });
  }

  updateBattleStatus(battleId, status) {
    this.send({
      type: "update-battle-status",
      battleId,
      status
    });
  }

  voteBattle(battleId, winnerName) {
    this.send({
      type: "battle-vote",
      battleId,
      winnerName
    });
  }

  // NEU: Antwort im Wissen-Battle senden
  sendKnowledgeAnswer(battleId, answerIndex) {
    this.send({
      type: "battle-answer",
      battleId,
      answerIndex
    });
  }

  // =====================
  // RECEIVE
  // =====================

  handleIncoming(msg) {
    const type = msg.type;
    if (!type) return;

    if (type === "battle-requested") {
      this.emit("battle-requested", {
        battleId: msg.battleId,
        fromPlayerId: msg.fromPlayerId,
        toPlayerId: msg.toPlayerId,
        challengeId: msg.challengeId,
        status: msg.status
      });
    }

    if (type === "battle-created") {
      this.emit("battle-created", {
        battleId: msg.battleId,
        fromPlayerId: msg.fromPlayerId,
        toPlayerId: msg.toPlayerId,
        challengeId: msg.challengeId,
        status: msg.status
      });
    }

    if (type === "battle-updated") {
      this.emit("battle-updated", {
        battleId: msg.battleId,
        status: msg.status
      });
    }

    if (type === "battle-pending") {
      this.emit("battle-pending", {
        battleId: msg.battleId
      });
    }

    if (type === "battle-result") {
      this.emit("battle-result", {
        battleId: msg.battleId,
        winnerName: msg.winnerName,
        loserName: msg.loserName,
        winnerPointsDelta: msg.winnerPointsDelta,
        loserPointsDelta: msg.loserPointsDelta,
        trashTalk: msg.trashTalk
      });
    }

    // NEU: Wissen-Frage
    if (type === "battle-question") {
      this.emit("battle-question", {
        battleId: msg.battleId,
        challenge: msg.challenge
        // challenge: { id, text, category, choices: [..], correctIndex }
      });
    }

    if (type === "error") {
      console.error("Server error:", msg.message);
    }
  }
}
