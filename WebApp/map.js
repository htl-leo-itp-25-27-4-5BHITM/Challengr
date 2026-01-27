import { GameClient } from "./GameSocketClient.js";

let myId = 3;             // deine Spieler-ID
const gameClient = new GameClient(myId);
gameClient.connect();

gameClient.on("battle-requested", (msg) => {
  console.log("Battle für mich:", msg);

  // Einfacher Dialog
  alert(`Neue Challenge von Spieler ${msg.fromPlayerId}!\nChallenge-ID: ${msg.challengeId}`);
});

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
  playerName: "",
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
  sheet.classList.remove("hidden");
  setTimeout(() => sheet.classList.add("visible"), 10);
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
    case "Wissen": return "#6BCB77";
    case "Suchen": return "#222222";
    default: return "#3498db";
  }
}

const colorMap = {
  "Fitness": "card-yellow",
  "Mutprobe": "card-red",
  "Wissen": "card-green",
  "Suchen": "card-black"
};

const iconMap = {
  "Fitness": "💪",
  "Mutprobe": "🔥",
  "Wissen": "💡",
  "Suchen": "🔍"
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

    categories.forEach(cat => {
      challenges[cat.name] = {
        description: cat.description,
        tasks: allChallenges
          .filter(c => c.challengeCategory && c.challengeCategory.id === cat.id)
          .map(c => ({ id: c.id, text: c.text }))
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
    challengOtherPlayer(player.id, player.name);
  });

  window._pins.push(marker);
  return marker;
}

function challengOtherPlayer(playerId, playerName = "Spieler") {
  dialogState.isOpen = true;
  dialogState.isLoading = false;
  dialogState.selectedChallenge = null;
  dialogState.selectedChallengeId = null;
  dialogState.playerName = playerName;
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
  title.textContent = `Challenge ${dialogState.playerName}`;

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
  if (!dialogState.targetPlayerId || !dialogState.selectedChallengeId) return;

  gameClient.createBattle(
    dialogState.targetPlayerId,
    dialogState.selectedChallengeId
  );

  dialogState.isOpen = false;
  dialogState.selectedChallenge = null;
  dialogState.selectedChallengeId = null;

  document
    .getElementById("challenge-dialog-backdrop")
    .classList.add("hidden");

  // Angenommen, Spieler + Challenge ausgewählt
  showBattleDialog({
    category: dialogState.selectedChallenge ? "Fitness" : "Mutprobe",
    challengeName: dialogState.selectedChallenge || "Sprint 100m",
    playerLeft: "Ich",
    playerRight: dialogState.playerName || "Spieler 2",
    onClose: () => {
      console.log("Challenge erfolgreich abgeschlossen");
      dialogState.isOpen = false;
    },
    onSurrender: () => {
      console.log("Aufgegeben");
      dialogState.isOpen = false;
    }
  });

}




  // Kategorien anzeigen
  subtitle.textContent = "Wähle eine Kategorie";

  ["Fitness", "Mutprobe", "Wissen", "Suchen"].forEach(cat => {
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



async function loadRandomChallenge(categoryName) {
  dialogState.isLoading = true;
  renderChallengeDialog();

  const category = challenges[categoryName];
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


function showBattleDialog({ category, challengeName, playerLeft, playerRight, onClose, onSurrender }) {
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
    showBattleWin({
  winnerName: "Ich",
  winnerPointsDelta: 50
});

    cleanup();
    if (onClose) onClose();
  };

  surrenderBtn.onclick = () => {
    showBattleLose({
  loserName: "Ich",
  loserPointsDelta: 25,
  trashTalk: "Haha, nächstes Mal packst du es!",
  winnerName: "Spieler 2"
});

    cleanup();
    if (onSurrender) onSurrender();
  };

  closeBtn.onclick = cleanup;
}


function showBattleWin({ winnerName, winnerAvatar, winnerPointsDelta }) {
  const backdrop = document.getElementById("battle-win-backdrop");
  const nameEl = document.getElementById("battle-win-name");
  const pointsEl = document.getElementById("battle-win-points");
  const footerEl = document.getElementById("battle-win-footer");
  const closeBtn = document.getElementById("battle-win-close");

  nameEl.textContent = winnerName;
  pointsEl.textContent = `+${winnerPointsDelta} Punkte`;
  footerEl.textContent = `Sieger: ${winnerName}`;

  backdrop.classList.remove("hidden");

  function cleanup() {
    backdrop.classList.add("hidden");
    closeBtn.onclick = null;
  }

  closeBtn.onclick = cleanup;
}

function showBattleLose({ loserName, loserPointsDelta, trashTalk, winnerName }) {
  const backdrop = document.getElementById("battle-lose-backdrop");
  const nameEl = document.getElementById("battle-lose-name");
  const pointsEl = document.getElementById("battle-lose-points");
  const trashEl = document.getElementById("battle-lose-trash");
  const footerEl = document.getElementById("battle-lose-footer");
  const closeBtn = document.getElementById("battle-lose-close");

  nameEl.textContent = loserName || "Du";
  pointsEl.textContent = `-${loserPointsDelta} Punkte`;
  trashEl.textContent = trashTalk || "";
  footerEl.textContent = `Sieger: ${winnerName}`;

  backdrop.classList.remove("hidden");

  function cleanup() {
    backdrop.classList.add("hidden");
    closeBtn.onclick = null;
  }

  closeBtn.onclick = cleanup;
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
