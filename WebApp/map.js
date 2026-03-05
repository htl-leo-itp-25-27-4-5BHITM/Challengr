import { GameClient } from "./GameSocketClient.js";

window.myName = "WebappSpieler"; 
let myId = 3;
const gameClient = new GameClient(myId);
gameClient.connect();

let sheetMode = "challenges"; // oder "trophy"
let isResultPending = false;



const api = (url) => fetch(url).then(r => r.json());


// Battle State
let currentBattleState = {
  battleId: null,
  challengeName: "",
  category: "",
  playerLeft: "",
  playerRight: "",
  fromPlayerId: null,
  toPlayerId: null,
  isInitiator: false  // true wenn ich die challenge gestartet habe
};
let currentKnowledgeQuestion = null;


const incomingBackdrop = document.getElementById("incoming-challenge-backdrop");
const incomingOpponentEl = document.getElementById("incoming-opponent");
const incomingTextEl = document.getElementById("incoming-challenge-text");
const incomingAcceptBtn = document.getElementById("incoming-accept");
const incomingDeclineBtn = document.getElementById("incoming-decline");
const pendingOverlay = document.getElementById("battle-pending-overlay");


let incomingBattleId = null;

function showIncomingChallengeUI({ opponentName, opponentRank, challengeText, onAccept, onDecline }) {
  const rankText = opponentRank ? ` · ${opponentRank}` : "";
  incomingOpponentEl.textContent = (opponentName + rankText).toUpperCase();
  incomingTextEl.textContent = challengeText;
  incomingBackdrop.classList.remove("hidden");

  function cleanup() {
    incomingBackdrop.classList.add("hidden");
    incomingAcceptBtn.onclick = null;
    incomingDeclineBtn.onclick = null;
  }

  incomingAcceptBtn.onclick = () => {
    cleanup();
    if (onAccept) onAccept();
  };

  incomingDeclineBtn.onclick = () => {
    cleanup();
    if (onDecline) onDecline();
  };
}

gameClient.on("battle-question", ({ battleId, challenge }) => {
  console.log("Knowledge question:", battleId, challenge);

  if (battleId !== currentBattleState.battleId) return;
  if (currentBattleState.category !== "Wissen") return;

  currentKnowledgeQuestion = challenge;

  const backdrop  = document.getElementById("knowledge-battle-backdrop");
  const qEl       = document.getElementById("kb-question");
  const choicesEl = document.getElementById("kb-choices");
  const statusEl  = document.getElementById("kb-status");

  if (!backdrop || !qEl || !choicesEl) return;
  backdrop.classList.remove("hidden");

  qEl.textContent = challenge.text;
  choicesEl.innerHTML = "";
  statusEl.textContent = "";

  (challenge.choices || []).forEach((choiceText, index) => {
    const btn = document.createElement("button");
    btn.className = "kb-choice-btn";
    btn.textContent = choiceText;
    btn.onclick = () => {
      // Buttons sperren, Status anzeigen
      document
        .querySelectorAll("#kb-choices .kb-choice-btn")
        .forEach(b => b.disabled = true);

      statusEl.textContent = "Antwort gesendet – warte auf Ergebnis …";
      gameClient.sendKnowledgeAnswer(currentBattleState.battleId, index);
    };
    choicesEl.appendChild(btn);
  });
});



gameClient.on("battle-requested", async (msg) => {
  console.log("➡ battle-requested:", msg);

  if (msg.toPlayerId !== myId) {
    // Kopie für Angreifer, nichts anzeigen
    return;
  }

  Object.assign(currentBattleState, {
    battleId: msg.battleId,
    fromPlayerId: msg.fromPlayerId,
    toPlayerId: msg.toPlayerId,
    isInitiator: false
  });
  incomingBattleId = msg.battleId;

  try {
    const challenge = await api(`/api/challenges/id/${msg.challengeId}`);
    const [fromPlayer, toPlayer] = await Promise.all([
      api(`/api/players/${msg.fromPlayerId}`),
      api(`/api/players/${msg.toPlayerId}`)
    ]);

    Object.assign(currentBattleState, {
  challengeName: challenge.text,
  category: challenge.category || "Challenge",
  playerLeft: fromPlayer.name,
  playerRight: toPlayer.name
});


    showIncomingChallengeUI({
      opponentName: fromPlayer.name,
      opponentRank: fromPlayer.rankName,
      challengeText: currentBattleState.challengeName,
      onAccept: () => {
  gameClient.updateBattleStatus(incomingBattleId, "ACCEPTED");

  if (currentBattleState.category === "Wissen") {
    showKnowledgeBattle();   // wartet auf battle-question
  } else {
    showBattleDialog({
      category: currentBattleState.category,
      challengeName: currentBattleState.challengeName,
      playerLeft: currentBattleState.playerLeft,
      playerRight: currentBattleState.playerRight,
      onSuccess: handleBattleSuccess,
      onSurrender: handleBattleSurrender,
      onClose: () => console.log("Battle dialog closed")
    });
  }
},

      onDecline: () => {
        gameClient.updateBattleStatus(incomingBattleId, "DECLINED");
      }
    });
  } catch (e) {
    console.error("Battle load failed", e);
  }
});




// Wenn ich die Battle erstelle, bekomme ich eine Bestätigung zurück
gameClient.on("battle-created", (msg) => {
  console.log("Battle created confirmation:", msg);
  currentBattleState.battleId = msg.battleId;
});


gameClient.on("battle-updated", (msg) => {
  console.log("Battle updated:", msg);

  if (msg.status === "ACCEPTED" &&
      msg.battleId === currentBattleState.battleId &&
      currentBattleState.isInitiator) {

    if (currentBattleState.category === "Wissen") {
      showKnowledgeBattle();          // ⬅️ NEU
    } else {
      showBattleDialog({
        category: currentBattleState.category,
        challengeName: currentBattleState.challengeName,
        playerLeft: currentBattleState.playerLeft,
        playerRight: currentBattleState.playerRight,
        onSuccess: handleBattleSuccess,
        onSurrender: handleBattleSurrender,
        onClose: () => console.log("Battle dialog closed")
      });
    }
  }

  if (msg.status === "READY_FOR_VOTING" &&
      msg.battleId === currentBattleState.battleId) {

        
    showVotingDialog({
      playerA: currentBattleState.playerLeft,
      playerB: currentBattleState.playerRight,
      onVote: (winnerName) => {
        console.log("Vote für:", winnerName);
        gameClient.voteBattle(currentBattleState.battleId, winnerName);

        isResultPending = true;
        if (pendingOverlay) {
          pendingOverlay.classList.remove("hidden");
        }
      }
    });
  }
});

gameClient.on("battle-pending", (msg) => {
  console.log("battle-pending:", msg);
  isResultPending = true;
  if (pendingOverlay) {
    pendingOverlay.classList.remove("hidden");
  }
});






gameClient.on("battle-result", (msg) => {
  console.log("Battle result received:", msg);

  // Loader kurz stehen lassen
  setTimeout(() => {
    isResultPending = false;
    if (pendingOverlay) pendingOverlay.classList.add("hidden");

    const kbBackdrop = document.getElementById("knowledge-battle-backdrop");
    if (kbBackdrop) kbBackdrop.classList.add("hidden");

    const myName = window.myName || `Player_${myId}`;
    const iWon = msg.winnerName === myName;

    if (iWon) {
      showBattleWin({
        winnerName: msg.winnerName,
        winnerAvatar: "playerGirl.png", 
        winnerPointsDelta: msg.winnerPointsDelta,
        loserName: msg.loserName,
        loserAvatar: "playerBoy.png",
        loserPointsDelta: Math.abs(msg.loserPointsDelta)
      });
    } else {
      showBattleLose({
        loserName: msg.loserName,
        loserAvatar: "playerGirl.png",
        loserPointsDelta: Math.abs(msg.loserPointsDelta),
        winnerName: msg.winnerName, 
        winnerAvatar: "playerBoy.png",
        winnerPointsDelta: msg.winnerPointsDelta,
        trashTalk: msg.trashTalk
      });
    }

    const battleDialogBackdrop =
      document.getElementById("battle-dialog-backdrop");
    if (battleDialogBackdrop) {
      battleDialogBackdrop.classList.add("hidden");
    }
    // Punkte nach dem Battle neu laden
    loadPlayerPoints(myId);
  }, 2500);  // 2 Sekunden Loading
});


function handleBattleSuccess() {
  console.log("Battle erfolgreich abgeschlossen → READY_FOR_VOTING");
  gameClient.updateBattleStatus(currentBattleState.battleId, "READY_FOR_VOTING");
}


function handleBattleSurrender() {
  console.log("Aufgegeben - DONE_SURRENDER senden");
  gameClient.updateBattleStatus(currentBattleState.battleId, "DONE_SURRENDER");
  // Optional: zusätzlich direkt einen Vote schicken, wenn du willst:
  // const opponent = currentBattleState.isInitiator
  //   ? currentBattleState.playerRight
  //   : currentBattleState.playerLeft;
  // gameClient.voteBattle(currentBattleState.battleId, opponent);
}






// Sound that is played when a new nearby player appears
const playerCountSound = new Audio("./sound1.mp3");

// Stores the last known number of nearby players (without yourself)
let lastPlayerCount = 0;

// Search radius in meters for nearby players
let playerRadius = 200;

// State object for the challenge dialog UI
let dialogState = {
  isOpen: false,
  isLoading: false,
  selectedChallenge: null,
  selectedChallengeId: null,
  selectedCategory: null,
  playerName: "",
  playerRank: "",          // NEU
  targetPlayerId: null
};



// Create Leaflet map and set initial view (Vienna as fallback)
const map = L.map('map').setView([48.2082, 16.3738], 13);
L.tileLayer(
  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}@2x.png',
  {
    subdomains: ['a','b','c','d'],
    attribution: '&copy; OpenStreetMap contributors &copy; CARTO',
    maxZoom: 19
  }
).addTo(map);

// Global coordinates for the current user
let lat = 0;
let lon = 0;

if (navigator.geolocation) {
  navigator.geolocation.getCurrentPosition(async pos => {
    lat = pos.coords.latitude;
    lon = pos.coords.longitude;

    map.setView([lat, lon], 15);
    L.marker([lat, lon]).addTo(map).bindPopup("Dein Standort");

    const pulseCircle = L.circle([lat, lon], {
      radius: playerRadius,
      color: 'blue',
      fillColor: 'blue',
      fillOpacity: 0.05
    }).addTo(map);

    // CSS-Klasse hinzufügen → aktiviert Animation
    pulseCircle.getElement().classList.add("pulse-circle");

    await updateMyPosition(myId, lat, lon);
  });
}

// References to bottom‑sheet challenge UI elements
const challengeBtn = document.getElementById("challenge-btn");
const sheet = document.getElementById("challenge-sheet");
const closeBtn = document.getElementById("close-btn");
const backBtn = document.getElementById("back-btn");
const categoriesDiv = document.getElementById("categories");
const detailView = document.getElementById("detail-view");

challengeBtn.addEventListener("click", () => {
  sheetMode = "trophy";
  openSheet();
  renderSheet();
});

closeBtn.addEventListener("click", () => {
  sheet.classList.remove("visible");
  setTimeout(() => sheet.classList.add("hidden"), 300);
});
backBtn.addEventListener("click", () => {
  detailView.classList.add("hidden");
  categoriesDiv.classList.remove("hidden");
});

function getCategoryColor(category) {
  switch (category) {
    case "Fitness": return "#FFD93D";
    case "Mutprobe": return "#F05454";
    case "Wissen":   return "#6BCB77";
    case "iPhone":   return "#222222";
    case "Customer": return "#999999";
    default: return "#3498db";
  }
}

const colorMap = {
  "Fitness":  "card-yellow",
  "Mutprobe": "card-red",
  "Wissen":   "card-green",
  "iPhone":   "card-black",
  "Customer": "card-gray"
};

const iconMap = {
  "Fitness":  "💪",
  "Mutprobe": "🔥",
  "Wissen":   "💡",
  "iPhone":   "📱",
  "Customer": "👥"
};


let challenges = {};

// Load categories and challenges from backend (über Vite-Proxy!)
Promise.all([
  fetch("/api/challenges/categories").then(r => r.json()),
  fetch("/api/challenges").then(r => r.json())
])
  .then(([categories, allChallenges]) => {
    console.log("Kategorien:", categories);
    console.log("Challenges:", allChallenges);

    challenges = {};

   challenges = {};

categories.forEach(cat => {
  challenges[cat.name] = {
    description: cat.description,
    tasks: allChallenges
      .filter(c => c.category === cat.name)      // <– NEU
      .map(c => ({ id: c.id, text: c.text }))   // id + text bleiben
  };
});


    renderCards();
  })
  .catch(err => console.error("Fehler beim Laden:", err));

function renderCards() {
  categoriesDiv.innerHTML = "";

  for (const [title, data] of Object.entries(challenges)) {
    const card = document.createElement("div");
    card.className = `card ${colorMap[title] || "card-default"}`;

    card.innerHTML = `
      <div class="icon">${iconMap[title] || "❓"}</div>
      <div>
        <h3>${title}</h3>
        <p>${data.description}</p>
      </div>
    `;

    card.addEventListener("click", () => showDetail(title, data));
    categoriesDiv.appendChild(card);
  }
}

let categoriesRaw = [];
let allChallenges = [];

// Nochmals Challenges laden (falls du das brauchst)
Promise.all([
  fetch("/api/challenges/categories").then(r => r.json()),
  fetch("/api/challenges").then(r => r.json())
])
  .then(([categories, challengesData]) => {
    categoriesRaw = categories;
    allChallenges = challengesData;
  });

function showDetail(categoryName) {
  categoriesDiv.classList.add("hidden");
  detailView.classList.remove("hidden");

  document.getElementById("detail-title").textContent = categoryName;
  document.getElementById("detail-desc").textContent = `Challenges für ${categoryName}`;

  const list = document.getElementById("detail-tasks");
  list.innerHTML = "";

  const cardClass = colorMap[categoryName] || "card-default";
  const icon = iconMap[categoryName] || "❓";

  const category = categoriesRaw.find(c => c.name === categoryName);
  if (!category) return;

  const filtered = allChallenges.filter(ch =>
    ch.challengeCategory && ch.challengeCategory.id === category.id
  );

  filtered.forEach(ch => {
    const card = document.createElement("div");
    card.className = `card ${cardClass} task-card`;
    card.innerHTML = `
      <div class="icon">${icon}</div>
      <div>
        <h4>${ch.text}</h4>
      </div>
    `;
    list.appendChild(card);
  });
}

const redIcon = L.icon({
  iconUrl: "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-red.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

window._pins = [];

function addPin(lat, lon, player) {
  const marker = L.marker([lat, lon], { icon: redIcon }).addTo(map);

  marker.on("click", () => {
    console.log("Pin geklickt:", player.name, lat, lon);
    challengOtherPlayer(player.id, player.name, player.rankName);
  });

  window._pins.push(marker);
  return marker;
}

function challengOtherPlayer(playerId, playerName = "Spieler", playerRank = "") {
  dialogState.isOpen = true;
  dialogState.isLoading = false;
  dialogState.selectedChallenge = null;
  dialogState.selectedChallengeId = null;
  dialogState.playerName = playerName;
  dialogState.playerRank = playerRank; 
  dialogState.targetPlayerId = playerId;

  renderChallengeDialog();
}


function renderChallengeDialog() {
  const backdrop = document.getElementById("challenge-dialog-backdrop");
  const title = document.getElementById("dialog-title");
  const subtitle = document.getElementById("dialog-subtitle");
  const categoriesDiv = document.getElementById("dialog-categories");
  const resultDiv = document.getElementById("dialog-result");

  if (!backdrop || !title || !subtitle || !categoriesDiv || !resultDiv) {
    console.error("Dialog HTML fehlt");
    return;
  }

  backdrop.classList.remove("hidden");
  const rankSuffix = dialogState.playerRank ? ` · ${dialogState.playerRank}` : "";
  title.textContent = `Challenge ${dialogState.playerName}${rankSuffix}`;


  // Reset
  categoriesDiv.innerHTML = "";
  resultDiv.innerHTML = "";
  resultDiv.classList.add("hidden");

  const oldBtn = document.getElementById("dialog-send-btn");
  if (oldBtn) oldBtn.remove();



  // Loading
  if (dialogState.isLoading) {
    subtitle.textContent = "Wird geladen...";
    categoriesDiv.innerHTML = "";
    return;
  }

  // Challenge ausgewählt
 if (dialogState.selectedChallenge) {
  subtitle.textContent = "Ausgewählte Challenge:";
  resultDiv.textContent = dialogState.selectedChallenge;
  resultDiv.classList.remove("hidden");

  // alten Send-Button entfernen
  const oldBtn = document.getElementById("dialog-send-btn");
  if (oldBtn) oldBtn.remove();

  // neuen Button UNTERHALB der Challenge
const sendBtn = document.createElement("button");
sendBtn.id = "dialog-send-btn";
sendBtn.textContent = "Senden";

// Inline-Style wie close-btn (funktioniert überall)
sendBtn.style.width = "100%";
sendBtn.style.padding = "12px";
sendBtn.style.marginTop = "12px";
sendBtn.style.borderRadius = "12px";
sendBtn.style.border = "1px solid #ddd";
sendBtn.style.background = "#fff";
sendBtn.style.color = "#000";
sendBtn.style.fontSize = "16px";
sendBtn.style.cursor = "pointer";

sendBtn.onclick = sendChallenge;

// UNTER den Challenge-Text setzen
resultDiv.parentElement.appendChild(sendBtn);


  return;
}



function sendChallenge() {
  console.log("sendChallenge aufgerufen", dialogState);
  if (!dialogState.targetPlayerId || !dialogState.selectedChallengeId) return;

  // Battle anlegen
  gameClient.createBattle(
    dialogState.targetPlayerId,
    dialogState.selectedChallengeId
  );

  // State merken, aber KEIN showBattleDialog hier
  currentBattleState.isInitiator = true;
  currentBattleState.fromPlayerId = myId;
  currentBattleState.toPlayerId = dialogState.targetPlayerId;
  currentBattleState.challengeName = dialogState.selectedChallenge;
  currentBattleState.category = dialogState.selectedCategory || "Challenge";
  currentBattleState.playerLeft = window.myName || `Player_${myId}`;
  currentBattleState.playerRight = dialogState.playerName;

  dialogState.isOpen = false;
  dialogState.selectedChallenge = null;
  dialogState.selectedChallengeId = null;

  document
    .getElementById("challenge-dialog-backdrop")
    .classList.add("hidden");

  // Optional: „Warte bis Gegner annimmt…“ anzeigen, aber NICHT die Challenge selbst.
}





  // Kategorien anzeigen
  subtitle.textContent = "Wähle eine Kategorie";

  ["Fitness", "Mutprobe", "Wissen", "iPhone", "Customer"].forEach(cat => {
  const btn = document.createElement("button");
  btn.innerHTML = `
    <span class="dialog-icon">${iconMap[cat]}</span>
    <span class="dialog-text">${cat}</span>
    <span class="dialog-spacer"></span>
  `;

  btn.style.background = getCategoryColor(cat);
  btn.onclick = () => loadRandomChallenge(cat);
  categoriesDiv.appendChild(btn);
});
}

function showKnowledgeBattle() {
  const backdrop = document.getElementById("knowledge-battle-backdrop");
  const qEl      = document.getElementById("kb-question");
  const choicesEl = document.getElementById("kb-choices");
  const statusEl  = document.getElementById("kb-status");

  if (!backdrop || !qEl || !choicesEl) {
    console.error("Knowledge Battle HTML fehlt");
    return;
  }

  backdrop.classList.remove("hidden");
  qEl.textContent = "Frage wird geladen …";
  choicesEl.innerHTML = "";
  statusEl.textContent = "";
}


async function loadRandomChallenge(categoryName) {
  
  dialogState.isLoading = true;
  dialogState.selectedCategory = categoryName;  // Kategorie merken
  renderChallengeDialog();

  const category = challenges[categoryName];
  console.log("loadRandomChallenge", categoryName, category);
  if (!category || !category.tasks || category.tasks.length === 0) {
    dialogState.isLoading = false;
    dialogState.selectedChallenge = "Keine Challenges in dieser Kategorie.";
    dialogState.selectedChallengeId = null;
    renderChallengeDialog();
    return;
  }

  const random = category.tasks[Math.floor(Math.random() * category.tasks.length)];

  dialogState.isLoading = false;
  dialogState.selectedChallenge = random.text;
  dialogState.selectedChallengeId = random.id;
  renderChallengeDialog();
}


function showBattleDialog({ category, challengeName, playerLeft, playerRight, onClose, onSurrender, onSuccess }) {
  const backdrop = document.getElementById("battle-dialog-backdrop");
  const categoryEl = document.getElementById("battle-category");
  const challengeEl = document.getElementById("battle-challenge");
  const vsEl = document.getElementById("battle-vs");

  categoryEl.textContent = category.toUpperCase();
  challengeEl.textContent = challengeName;
  vsEl.textContent = `${playerLeft}  VS  ${playerRight}`;

  backdrop.classList.remove("hidden");

  const successBtn = document.getElementById("battle-success-btn");
  const surrenderBtn = document.getElementById("battle-surrender-btn");
  const closeBtn = document.getElementById("battle-close-btn");

  function cleanup() {
    backdrop.classList.add("hidden");
    successBtn.onclick = null;
    surrenderBtn.onclick = null;
    closeBtn.onclick = null;
  }

  successBtn.onclick = () => {
    cleanup();
    if (onSuccess) onSuccess();
  };

  surrenderBtn.onclick = () => {
    cleanup();
    if (onSurrender) onSurrender();
  };

  closeBtn.onclick = cleanup;
}


function showVotingDialog({ playerA, playerB, onVote }) {
  const backdrop = document.getElementById("battle-voting-backdrop");
  const btnA = document.getElementById("vote-player-a");
  const btnB = document.getElementById("vote-player-b");
  const feedback = document.getElementById("voting-feedback");

  btnA.textContent = playerA.toUpperCase();
  btnB.textContent = playerB.toUpperCase();
  
  let hasVoted = false;

  function handleVote(playerName) {
    if (hasVoted) return;
    hasVoted = true;
    
    feedback.textContent = `DU HAST FÜR ${playerName.toUpperCase()} GESTIMMT`;
    feedback.style.color = "#4CAF50";
    
    btnA.disabled = true;
    btnB.disabled = true;
    btnA.style.opacity = "0.5";
    btnB.style.opacity = "0.5";
    
    if (onVote) onVote(playerName);
    
    // Dialog nach 2 Sekunden schließen
    setTimeout(() => {
      backdrop.classList.add("hidden");
      hasVoted = false;
      btnA.disabled = false;
      btnB.disabled = false;
      btnA.style.opacity = "1";
      btnB.style.opacity = "1";
      feedback.textContent = "Tippe auf einen Spieler";
      feedback.style.color = "gray";
    }, 2000);
  }

  btnA.onclick = () => handleVote(playerA);
  btnB.onclick = () => handleVote(playerB);

  backdrop.classList.remove("hidden");
}

function showBattleWin({
  winnerName,
  winnerAvatar,
  winnerPointsDelta,
  loserName,
  loserAvatar,
  loserPointsDelta
}) {

  console.log(winnerAvatar, loserAvatar);
  
  const backdrop = document.getElementById("battle-win-backdrop");

  document.getElementById("battle-win-subtitle")
    .textContent = `GLÜCKWUNSCH, ${winnerName.toUpperCase()}!`;

  document.getElementById("battle-win-name-winner")
    .textContent = winnerName.toUpperCase();

  document.getElementById("battle-win-points-winner")
    .textContent = `+${winnerPointsDelta} PUNKTE`;

  document.getElementById("battle-win-avatar-winner")
    .src = "./Assets/" + winnerAvatar;

  document.getElementById("battle-win-name-loser")
    .textContent = loserName.toUpperCase();

  document.getElementById("battle-win-points-loser")
    .textContent = `-${loserPointsDelta} PUNKTE`;

  document.getElementById("battle-win-avatar-loser")
    .src = "./Assets/" + loserAvatar;

  document.getElementById("battle-win-bigpoints")
    .textContent = `+${winnerPointsDelta} PUNKTE`;

  backdrop.classList.remove("hidden");

  document.getElementById("battle-win-close").onclick = () => {
    backdrop.classList.add("hidden");

    const battleDialogBackdrop =
      document.getElementById("battle-dialog-backdrop");

    if (battleDialogBackdrop) {
      battleDialogBackdrop.classList.add("hidden");
    }
  };
}

function showBattleLose({
  winnerName,
  winnerAvatar,
  winnerPointsDelta,
  loserName,
  loserAvatar,
  loserPointsDelta,
  trashTalk
}) {


  const backdrop = document.getElementById("battle-lose-backdrop");

  document.getElementById("battle-lose-subtitle")
    .textContent = `KOPF HOCH, ${loserName.toUpperCase()}!`;

  document.getElementById("battle-lose-name-loser")
    .textContent = loserName.toUpperCase();

  document.getElementById("battle-lose-points-loser")
    .textContent = `-${loserPointsDelta > 0 ? "" : ""}${loserPointsDelta} PUNKTE`;

  document.getElementById("battle-lose-avatar-loser")
    .src = "./Assets/" + loserAvatar;

  document.getElementById("battle-lose-name-winner")
    .textContent = winnerName.toUpperCase();

  document.getElementById("battle-lose-points-winner")
    .textContent = `+${winnerPointsDelta} PUNKTE`;

  document.getElementById("battle-lose-avatar-winner")
    .src = "./Assets/" + winnerAvatar;

  document.getElementById("battle-lose-bigpoints")
    .textContent =
      loserPointsDelta === 0
        ? "0 PUNKTE VERÄNDERT"
        : `${loserPointsDelta > 0 ? "-" : ""}${loserPointsDelta} PUNKTE`;

  document.getElementById("battle-lose-trash")
    .textContent = trashTalk;

  backdrop.classList.remove("hidden");

  document.getElementById("battle-lose-close").onclick = () => {
    backdrop.classList.add("hidden");
  };
}


challengeBtn.addEventListener("click", () => {
  sheetMode = "trophy";
  openSheet();
  renderSheet();
});

document.getElementById("sheet-info-btn").onclick = () => {
  sheetMode = sheetMode === "challenges" ? "trophy" : "challenges";
  renderSheet();
};

function openSheet() {
  sheet.classList.remove("hidden");
  setTimeout(() => sheet.classList.add("visible"), 10);
}


let trophyRanks = [];
let playerPoints = 210; // TODO: vom Backend laden, falls vorhanden

async function loadTrophyRanks() {
  try {
    const res = await fetch("/api/ranks");
    trophyRanks = await res.json();

    // optional: direkt nach dem Laden die Road rendern, falls Sheet offen
    if (sheetMode === "trophy") renderTrophyRoad();
  } catch (err) {
    console.error("Fehler beim Laden der Trophy Ranks:", err);
  }
}

// Lade die Ränge gleich beim Start
loadTrophyRanks();

function getCurrentRank() {
  return trophyRanks.find(r => playerPoints >= r.min && playerPoints <= r.max) || trophyRanks[0];
}

async function loadPlayerPoints(playerId) {
  try {
    const res = await fetch(`/api/players/${playerId}`);
    const player = await res.json();
    playerPoints = player.points || 0;

    if (sheetMode === "trophy") renderTrophyRoad();
  } catch (err) {
    console.error("Fehler beim Laden der Spieler-Punkte:", err);
  }
}

// z.B.
loadPlayerPoints(myId);


const trophyBtn = document.getElementById("challenge-btn");
const trophyBackdrop = document.getElementById("trophy-road-backdrop");
const trophyList = document.getElementById("trophy-road-list");
const trophyClose = document.getElementById("trophy-close");
const trophyInfoBtn = document.getElementById("trophy-info-btn");

trophyBtn.addEventListener("click", () => {
  renderTrophyRoad();

  // Auto-scroll wie SwiftUI
  setTimeout(() => {
    const current = document.querySelector(".trophy-rank.current");
    if (current) current.scrollIntoView({ behavior: "smooth", block: "center" });
  }, 100);
});


const sheetInfoBtn = document.getElementById("sheet-info-btn");

if (sheetInfoBtn) {
  sheetInfoBtn.onclick = () => {
    sheetMode = sheetMode === "challenges" ? "trophy" : "challenges";
    renderSheet();
  };
}

function renderTrophyRoad() {
  const container = document.getElementById("trophy-road-list");
  container.innerHTML = "";

  if (!trophyRanks || trophyRanks.length === 0) return;

  const current = getCurrentRank();

  // reversed wie in Swift
  const reversed = [...trophyRanks].reverse();

  reversed.forEach((rank, index) => {

    // Rank Card
    const card = document.createElement("div");
    card.className = "trophy-rank-swift";
    card.dataset.rankId = rank.id;

    card.style.background = `
      linear-gradient(
        135deg,
        ${rank.color} 70%,
        rgb(0, 0, 0)
      )
    `;

    const isCurrent = current && current.id === rank.id;

    card.innerHTML = `
      <div class="trophy-rank-content">
        <div>
          <div class="trophy-rank-title">${rank.name.toUpperCase()}</div>
          <div class="trophy-range">${rank.min} – ${rank.max} PUNKTE</div>
          ${isCurrent ? `<div class="trophy-current">AKTUELLER RANG</div>` : ""}
        </div>
        ${isCurrent ? `<div class="trophy-points">${playerPoints}</div>` : ""}
      </div>
    `;

    container.appendChild(card);

    // Connector (wie etappenBlock in Swift)
    if (index < reversed.length - 1) {
      container.appendChild(createEtappenBlock(rank, isCurrent));
    }
  });

  // auto scroll wie SwiftUI
  setTimeout(() => {
    const el = document.querySelector(".trophy-current");
    if (el) {
      el.closest(".trophy-rank-swift")
        .scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }, 200);
}

function createEtappenBlock(rank, isCurrentRank) {
  const wrapper = document.createElement("div");
  wrapper.className = "etappen-wrapper";

  const canvas = document.createElement("canvas");
  canvas.width = 300;
  canvas.height = 320;

  wrapper.appendChild(canvas);

  const ctx = canvas.getContext("2d");

  const steps = 10;
  const stepHeight = 30;
  const width = canvas.width;
  const centerX = width / 2;

  ctx.lineWidth = 6;
  ctx.lineCap = "round";
  ctx.strokeStyle = rank.color + "80";

  ctx.beginPath();

  for (let i = 0; i < steps; i++) {
    const t = i / (steps - 1);
    const x = centerX + Math.sin(t * Math.PI * 2) * 60;
    const y = i * stepHeight + 10;

    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }

  ctx.stroke();

  // Steps
  for (let i = 0; i < steps; i++) {
    const t = i / (steps - 1);
    const x = centerX + Math.sin(t * Math.PI * 2) * 60;
    const y = i * stepHeight + 10;

    ctx.beginPath();
    ctx.fillStyle = rank.color;
    ctx.arc(x, y, 7, 0, Math.PI * 2);
    ctx.fill();
  }

  // Spielerfigur animieren wenn aktueller Rank
  if (isCurrentRank) {
    const progress =
      (playerPoints - rank.min) / (rank.max - rank.min || 1);

    const stepIndex = Math.round(progress * (steps - 1));
    const t = stepIndex / (steps - 1);

    const x = centerX + Math.sin(t * Math.PI * 2) * 60;
    const y = stepIndex * stepHeight + 10;

    const img = new Image();
    img.src = "playerBoy.png"; // dein Bild

    img.onload = () => {
      ctx.drawImage(img, x - 22, y - 50, 44, 44);
    };
  }

  return wrapper;
}



function renderSheet() {
  const categories = document.getElementById("categories");
  const detail = document.getElementById("detail-view");
  const trophyView = document.getElementById("trophy-road-view");

  categories.classList.add("hidden");
  detail.classList.add("hidden");
  trophyView.classList.add("hidden");

  if (sheetMode === "challenges") {
    categories.classList.remove("hidden");
  } else {
    trophyView.classList.remove("hidden");
    renderTrophyRoad();
  }
}

























function clearPins() {
  window._pins.forEach(pin => {
    map.removeLayer(pin);
  });
  window._pins = [];
}

if (navigator.geolocation) {
  navigator.geolocation.getCurrentPosition(async pos => {
    lat = pos.coords.latitude;
    lon = pos.coords.longitude;

    console.log("Got GPS:", lat, lon);
    map.setView([lat, lon], 15);
    L.marker([lat, lon]).addTo(map).bindPopup("Dein Standort");

    // update server position first
    await updateMyPosition(myId, lat, lon);

    // loading nearby players
    await loadNearbyPlayersWeb(myId, lat, lon, playerRadius);
    setInterval(() => loadNearbyPlayersWeb(myId, lat, lon, playerRadius), 5000);
  }, err => {
    console.error("Geolocation error:", err);
  }, { enableHighAccuracy: true });
} else {
  console.warn("Browser unterstützt Geolocation nicht");
}

async function loadNearbyPlayersWeb(currentPlayerId, lat, lon, radiusMeters) {
  try {
    const url =
      `/api/players/nearby?playerId=${currentPlayerId}` +
      `&latitude=${lat}&longitude=${lon}&radius=${radiusMeters}`;

    const res = await fetch(url);
    const players = await res.json();

    console.log("Nearby Players:", players);

    const currentCount = players.filter(p => p.id !== currentPlayerId).length;

    if (currentCount > lastPlayerCount) {
      playerCountSound.currentTime = 0;
      playerCountSound.play();
      console.log("Neuer Spieler in der Nähe! Sound abgespielt.");
    }

    lastPlayerCount = currentCount;

    clearPins();
    players.forEach(p => {
      if (p.id === currentPlayerId) return;
      const plat = parseFloat(p.latitude);
      const plon = parseFloat(p.longitude);
      if (!isNaN(plat) && !isNaN(plon)) addPin(plat, plon, p);
    });

  } catch (err) {
    console.error("Fehler beim Laden der Nearby Players:", err);
  }
}

async function loadOtherPlayers() {
  try {
    const res = await fetch("/api/players/nearby");
    const players = await res.json();

    console.log("Nearby Players:", players);

    clearPins();

    players.forEach(p => {
      if (p.id === 1) return;
      const plat = parseFloat(p.latitude);
      const plon = parseFloat(p.longitude);

      if (!isNaN(plat) && !isNaN(plon)) {
        addPin(plat, plon, p.name || "Spieler");
      }
    });

  } catch (err) {
    console.error("Fehler beim Laden der Spieler-Pins:", err);
  }
}

async function updateMyPosition(playerId, lat, lon) {
  try {
    const res = await fetch(`/api/players/${playerId}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        id: playerId,
        name: window.myName || null,
        latitude: lat,
        longitude: lon
      })
    });

    if (!res.ok) {
      console.error("Fehler beim Updaten deiner Position:", await res.text());
    }

  } catch (err) {
    console.error("Update Position Error:", err);
  }
}

async function createNewPlayer(lat, lon) {
  try {
    const res = await fetch("/api/players", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        name: "Player_" + Math.floor(Math.random() * 9999),
        latitude: lat,
        longitude: lon
      })
    });

    return await res.json();

  } catch (err) {
    console.error("Fehler beim Erstellen eines Players:", err);
  }
}

document.getElementById("dialog-close").addEventListener("click", () => {
  document.getElementById("challenge-dialog-backdrop").classList.add("hidden");
  dialogState.isOpen = false;
});
