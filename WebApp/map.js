const playerCountSound = new Audio("./sound1.mp3");
let lastPlayerCount = 0;
let playerRadius = 50000; 
let dialogState = {
  isOpen: false,
  isLoading: false,
  selectedChallenge: null,
  playerName: ""
};


const map = L.map('map').setView([48.2082, 16.3738], 13);
L.tileLayer(
  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}@2x.png',
  {
    subdomains: ['a','b','c','d'],
    attribution: '&copy; OpenStreetMap contributors &copy; CARTO',
    maxZoom: 19
  }
).addTo(map);

let lat = 0;
let lon = 0;
let myId = 3;

if (navigator.geolocation) {
  navigator.geolocation.getCurrentPosition(async pos => {
    lat = pos.coords.latitude;
    lon = pos.coords.longitude;

    map.setView([lat, lon], 15);
    L.marker([lat, lon]).addTo(map).bindPopup("Dein Standort");

    const myId = 3; 

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

Promise.all([
  fetch("http://localhost:8080/api/challenges/categories").then(r => r.json()),
  fetch("http://localhost:8080/api/challenges").then(r => r.json())
])
  .then(([categories, allChallenges]) => {
    console.log("Kategorien:", categories);
    console.log("Challenges:", allChallenges);

    challenges = {};

    categories.forEach(cat => {
      challenges[cat.name] = {
        description: cat.description,
        tasks: allChallenges
          .filter(c => c.category_id === cat.id)
          .map(c => c.text)
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
challenges = {};

Promise.all([
  fetch("http://localhost:8080/api/challenges/categories").then(r => r.json()),
  fetch("http://localhost:8080/api/challenges").then(r => r.json())
])
  .then(([categories, challengesData]) => {
    
    categoriesRaw = categories;   
    allChallenges = challengesData;

    challenges = {};

    categories.forEach(cat => {
      challenges[cat.name] = {
        id: cat.id,
        description: cat.description
      };
    });
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



function addPin(lat, lon, text = "Challengr") {
  const marker = L.marker([lat, lon], { icon: redIcon }).addTo(map);
  

   marker.on("click", () => {
    console.log("Pin geklickt:", text, lat, lon);
    challengOtherPlayer();
  });

  window._pins.push(marker);
  return marker;
}

function challengOtherPlayer(playerName = "Spieler") {
  console.log("challengOtherPlayer called", playerName);

  dialogState = {
    isOpen: true,
    isLoading: false,
    selectedChallenge: null,
    playerName
  };

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
  resultDiv.classList.add("hidden");
  subtitle.classList.remove("hidden");

  // Loading
  if (dialogState.isLoading) {
  subtitle.textContent = "Wird geladen...";
  categoriesDiv.innerHTML = "";
  return;
}

  // Challenge ausgewählt
  if (dialogState.selectedChallenge) {
    subtitle.textContent = "Zufällige Challenge:";
    resultDiv.textContent = dialogState.selectedChallenge;
    resultDiv.classList.remove("hidden");
    return;
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

  const category = categoriesRaw.find(c => c.name === categoryName);
  if (!category) {
    dialogState.selectedChallenge = "Kategorie nicht gefunden";
    dialogState.isLoading = false;
    renderChallengeDialog();
    return;
  }

const filtered = allChallenges.filter(c =>
  c.challengeCategory && c.challengeCategory.id === category.id
);

  dialogState.selectedChallenge =
    filtered.length
      ? filtered[Math.floor(Math.random() * filtered.length)].text
      : "Keine Challenge gefunden.";

  dialogState.isLoading = false;
  renderChallengeDialog();
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

    // jetzt Nearby laden und später regelmäßig updaten
    await loadNearbyPlayersWeb(myId, lat, lon, playerRadius);
    setInterval(() => loadNearbyPlayersWeb(myId, lat, lon, playerRadius), 5000); // alle 5s prüfen
  }, err => {
    console.error("Geolocation error:", err);
  }, { enableHighAccuracy: true });
} else {
  console.warn("Browser unterstützt Geolocation nicht");
}

async function loadNearbyPlayersWeb(currentPlayerId, lat, lon, radiusMeters) {
  try {
    const url = `http://localhost:8080/api/players/nearby?playerId=${currentPlayerId}&latitude=${lat}&longitude=${lon}&radius=${radiusMeters}`;

    const res = await fetch(url);
    const players = await res.json();

    console.log("Nearby Players:", players);

    // Spieler ohne dich selbst zählen
    const currentCount = players.filter(p => p.id !== currentPlayerId).length;

    // Wenn höher als vorher → Sound abspielen
    if (currentCount > lastPlayerCount) {
      playerCountSound.currentTime = 0; // immer von vorne
      playerCountSound.play();
      console.log("Neuer Spieler in der Nähe! Sound abgespielt.");
    }

    // Counter aktualisieren
    lastPlayerCount = currentCount;

    // Pins aktualisieren
    clearPins();
    players.forEach(p => {
      if (p.id === currentPlayerId) return;
      const lat = parseFloat(p.latitude);
      const lon = parseFloat(p.longitude);
      if (!isNaN(lat) && !isNaN(lon)) addPin(lat, lon, p.name || "Spieler");
    });

  } catch (err) {
    console.error("Fehler beim Laden der Nearby Players:", err);
  }
}


async function loadOtherPlayers() {
  try {
    const res = await fetch("http://localhost:8080/api/players/nearby");
    const players = await res.json();

        console.log("Nearby Players:", players);

    clearPins();
  
      players.forEach(p => {
        if (p.id === 1) return;
        const lat = parseFloat(p.latitude);
        const lon = parseFloat(p.longitude);

        if (!isNaN(lat) && !isNaN(lon)) {
          addPin(lat, lon, p.name || "Spieler");
        }
      });
    

  } catch (err) {
    console.error("Fehler beim Laden der Spieler-Pins:", err);
  }
}


async function updateMyPosition(playerId, lat, lon) {
  try {
    const res = await fetch(`http://localhost:8080/api/players/${playerId}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        id: playerId,
        name: window.myName || null, // optional
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
    const res = await fetch("http://localhost:8080/api/players", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        name: "Player_" + Math.floor(Math.random()*9999),
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
