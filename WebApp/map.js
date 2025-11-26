const map = L.map('map').setView([48.2082, 16.3738], 13);
L.tileLayer(
  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}@2x.png',
  {
    subdomains: ['a','b','c','d'],
    attribution: '&copy; OpenStreetMap contributors &copy; CARTO',
    maxZoom: 19
  }
).addTo(map);

if (navigator.geolocation) {
  navigator.geolocation.getCurrentPosition(pos => {
    const lat = pos.coords.latitude;
    const lon = pos.coords.longitude;
    map.setView([lat, lon], 15);
    L.marker([lat, lon]).addTo(map).bindPopup("Dein Standort");
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
  marker.bindPopup(text);

  window._pins.push(marker);
  return marker;
}


function clearPins() {
  window._pins.forEach(pin => {
    map.removeLayer(pin);
  });
  window._pins = []; 
}


loadOtherPlayers();

async function loadOtherPlayers() {
  try {
    const res = await fetch("http://localhost:8080/api/players");
    const players = await res.json();

    clearPins(); // alte Pins weg

    players.forEach(p => {
      // Leaflet muss Double/Float haben → parseFloat
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

