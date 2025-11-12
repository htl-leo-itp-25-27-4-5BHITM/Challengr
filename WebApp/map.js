// 🌍 Karte initialisieren
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
    L.marker([lat, lon]).addTo(map).bindPopup("📍 Dein Standort");
  });
}

// 🏆 Sheet öffnen/schließen
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

// 📚 Daten
const challenges = {
  "Fitness": {
    color: "card-yellow",
    icon: "💪",
    desc: "Verschiedene sportliche Challenges!",
    tasks: [
      "Mach 20 Liegestütze!",
      "Laufe 2 km ohne Pause!",
      "Springseil 100x ohne Fehler!",
      "Halte eine Plank 60 Sekunden!"
    ]
  },
  "Mutprobe": {
    color: "card-red",
    icon: "🔥",
    desc: "Wer traut sich mehr?",
    tasks: [
      "Sprich eine fremde Person an!",
      "Sing in der Öffentlichkeit!",
      "Erzähle eine peinliche Story!",
      "Mach ein Selfie in der Menge!"
    ]
  },
  "Wissen": {
    color: "card-green",
    icon: "💡",
    desc: "Teste dein Wissen!",
    tasks: [
      "Was ist die Hauptstadt von Kanada?",
      "Wie viele Knochen hat ein Mensch?",
      "Wer erfand die Glühbirne?",
      "Was ist H2O?"
    ]
  },
  "Suchen": {
    color: "card-black",
    icon: "🔍",
    desc: "Wer findet etwas zuerst?",
    tasks: [
      "Finde etwas Rotes.",
      "Mach ein Foto von einem Tier.",
      "Suche einen Spielplatz.",
      "Finde ein Schild mit deinem Anfangsbuchstaben."
    ]
  }
};

// Karten erzeugen
for (const [title, data] of Object.entries(challenges)) {
  const card = document.createElement("div");
  card.className = `card ${data.color}`;
  card.innerHTML = `
    <div class="icon">${data.icon}</div>
    <div>
      <h3>${title}</h3>
      <p>${data.desc}</p>
    </div>
  `;
  card.addEventListener("click", () => showDetail(title, data));
  categoriesDiv.appendChild(card);
}

// Detailansicht
function showDetail(title, data) {
  categoriesDiv.classList.add("hidden");
  detailView.classList.remove("hidden");
  document.getElementById("detail-title").textContent = title;
  document.getElementById("detail-desc").textContent = data.desc;
  const list = document.getElementById("detail-tasks");
  list.innerHTML = "";
  data.tasks.forEach(task => {
    const li = document.createElement("li");
    li.textContent = task;
    list.appendChild(li);
  });
}
