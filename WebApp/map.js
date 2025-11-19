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

fetch("http://localhost:8080/challenge")
  .then(res => res.json())
  .then(data => {
    console.log("Daten geladen:", data);
    challenges = data;
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

function showDetail(title, data) {
  categoriesDiv.classList.add("hidden");
  detailView.classList.remove("hidden");
  document.getElementById("detail-title").textContent = title;
  document.getElementById("detail-desc").textContent = data.description;

  const list = document.getElementById("detail-tasks");
  list.innerHTML = "";
  data.tasks.forEach(task => {
    const li = document.createElement("li");
    li.textContent = task;
    list.appendChild(li);
  });
}

window._pins = [];

addPin(48.2100, 16.3600);


function addPin(lat, lon, text = "Gegner") {
  const marker = L.marker([lat, lon]).addTo(map);
  marker.bindPopup(text);

  window._pins.push(marker); // speichern für späteres Löschen
  return marker;
}


function clearPins() {
  window._pins.forEach(pin => {
    map.removeLayer(pin);
  });
  window._pins = []; // Liste zurücksetzen
}
