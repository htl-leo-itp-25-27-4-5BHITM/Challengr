// GameClient.js

export class GameClient {
  constructor(playerId) {
    // Spieler-ID dynamisch (z.B. aus Login)
    this.playerId = playerId;
    this.socket = null;

    // Event-Callbacks (ähnlich wie Closures in Swift)
    this.handlers = {
      "battle-requested": [],
      "battle-updated": [],
      "battle-result": [],
      "battle-created": []
    };
  }

  // =====================
  // CONNECT / DISCONNECT
  // =====================

  connect() {
    if (this.socket) return;

    const url = `ws://localhost:8080/ws/game?playerId=${this.playerId}`;
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

  /**
   * Registriert einen Listener für einen bestimmten Message-Typ.
   * type: "battle-requested" | "battle-updated" | "battle-result"
   */
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

  /**
   * Battle anlegen (wir sind der Angreifer).
   * toPlayerId: Gegner
   * challengeId: ID der Challenge
   */
  createBattle(toPlayerId, challengeId) {
    this.send({
      type: "create-battle",
      fromId: this.playerId,
      toId: toPlayerId,
      challengeId: challengeId
    });
  }

  /**
   * Battle-Status updaten:
   * z.B. "ACCEPTED", "DECLINED", "DONE_SURRENDER"
   */
  updateBattleStatus(battleId, status) {
    this.send({
      type: "update-battle-status",
      battleId,
      status
    });
  }
  

  /**
   * Vote im Voting-Screen senden.
   */
  voteBattle(battleId, winnerName) {
    this.send({
      type: "battle-vote",
      battleId,
      winnerName
    });
  }

  // =====================
  // RECEIVE
  // =====================

  handleIncoming(msg) {
    const type = msg.type;
    if (!type) return;

    // battle-requested
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

    // battle-updated
    if (type === "battle-updated") {
      this.emit("battle-updated", {
        battleId: msg.battleId,
        status: msg.status
      });
    }

    // battle-result
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

    // optional: error-handling
    if (type === "error") {
      console.error("Server error:", msg.message);
    }
  }
}
