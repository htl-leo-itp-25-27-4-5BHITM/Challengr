// GameClient.js

export class GameClient {
  constructor(playerId) {
    this.playerId = playerId;
    this.socket = null;
    this.shouldReconnect = true;
    this.reconnectTimer = null;
    this.reconnectDelayMs = 1000;
    this.maxReconnectDelayMs = 10000;
    this.pendingMessages = [];
    this.maxPendingMessages = 30;

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
    this.shouldReconnect = true;

    if (
      this.socket &&
      (this.socket.readyState === WebSocket.OPEN ||
        this.socket.readyState === WebSocket.CONNECTING)
    ) {
      return;
    }

    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const url = `${protocol}//${window.location.host}/ws/game?playerId=${this.playerId}`;
    this.socket = new WebSocket(url);

    this.socket.onopen = () => {
      console.log("🔌 WS connected (player", this.playerId, ")");
      this.reconnectDelayMs = 1000;
      this.flushPendingMessages();
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
      if (this.shouldReconnect) {
        this.scheduleReconnect();
      }
    };

    this.socket.onerror = (err) => {
      console.error("❌ WS error", err);
    };
  }

  disconnect() {
    this.shouldReconnect = false;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
  }

  scheduleReconnect() {
    if (this.reconnectTimer || !this.shouldReconnect) return;

    const delay = this.reconnectDelayMs;
    console.log(`🔁 WS reconnect in ${delay}ms`);

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect();
    }, delay);

    this.reconnectDelayMs = Math.min(
      Math.floor(this.reconnectDelayMs * 1.8),
      this.maxReconnectDelayMs
    );
  }

  flushPendingMessages() {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) return;

    while (this.pendingMessages.length > 0) {
      const msg = this.pendingMessages.shift();
      this.socket.send(msg);
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
    const payload = JSON.stringify(data);

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(payload);
      return;
    }

    if (this.pendingMessages.length >= this.maxPendingMessages) {
      this.pendingMessages.shift();
    }
    this.pendingMessages.push(payload);

    console.warn("⚠️ WS not connected yet, message queued");
    this.connect();
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

  // Send compass result (for testing/fake data from webapp)
  sendCompassResult(battleId, distance) {
    this.send({
      type: "compass-result",
      battleId,
      distance
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
