// Karte laden
const map = L.map('map').setView([48.2082, 16.3738], 15);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '© OpenStreetMap'
}).addTo(map);

let currentposition = []
let marker = null;
let circle = null;

function updatePosition(pos) {
    const lat = pos.coords.latitude;
    const lng = pos.coords.longitude;
    const acc = pos.coords.accuracy;

    /*
    console.log(`Position: ${lat.toFixed(6)}, ${lng.toFixed(6)} (±${Math.round(acc)}m)`);
    currentposition = [lat, lng, acc];
    console.log(currentposition);
    */

    if (!marker) {
        marker = L.marker([lat, lng]).addTo(map).bindPopup("Du bist hier");
        circle = L.circle([lat, lng], { radius: acc }).addTo(map);
        map.setView([lat, lng], 16);
    } else {
        marker.setLatLng([lat, lng]);
        circle.setLatLng([lat, lng]);
        circle.setRadius(acc);
    }

    requestNextPosition();
}

function onError(err) {
    console.error("Standortfehler:", err.message);
    setTimeout(requestNextPosition, 5000);
}

function requestNextPosition() {
    navigator.geolocation.getCurrentPosition(updatePosition, onError, {
        enableHighAccuracy: true,
        timeout: 60000, 
        maximumAge: 0
    });
}


if ("geolocation" in navigator) {
    console.log("🛰️ Starte Standortabfragen...");
    requestNextPosition();
} else {
    alert("Geolocation wird von deinem Browser nicht unterstützt.");
}

function cards() {
document.getElementById("ChallengesStyle").innerHTML = `<main>
        <h1>Challengr Kategorien</h1>
        <div class="card-list"></div>
        <div class="detail-overlay" style="display:none;">
            <button id="go-back" class="go-back-btn">&#8592;</button>
            <div id="detail-content"></div>
        </div>

        <a class="card-icon" href="./map.html">🗺️</a>
    </main>`

    const colorMap = {
  "Fitness": "#FDD006",
  "Mutprobe": "#c42036ff",
  "Wissen": "#44AF69",
  "Suchen": "#ffffffff"
};

const overlayColorMap = {
  "Fitness": "#d8a50bff",
  "Mutprobe": "#830919ff",
  "Wissen": "#1f6b4dff",
  "Suchen": "#000000ff"
};

const iconMap = {
  "Fitness": "🏋️",
  "Mutprobe": "🔥",
  "Wissen": "💡",
  "Suchen": "🔍"
};

fetch("http://localhost:8080/challenge")
  .then(res => res.json())
  .then(data => {
    console.log(data);
    const cardList = document.querySelector('.card-list');
    cardList.innerHTML = '';
    const sortList = ["Fitness", "Mutprobe", "Wissen", "Suchen"];
    sortList.forEach(cat => {
      if (!(cat in data)) return;
      const value = data[cat];
      const card = document.createElement('div');
      card.className = "card";
      card.style.setProperty('--card-color', overlayColorMap[cat] || "#55495a");
      card.innerHTML = `
        <div class="card-icon" style="background:${colorMap[cat] || "#55495a"};">
          ${iconMap[cat] || "❓"}
        </div>
        <div class="card-content">
          <div class="card-title">${cat}</div>
          <div class="card-subtitle">${value.description}</div>
        </div>
      `;
      card.addEventListener('click', () => showDetail(cat, value));
      cardList.appendChild(card);
    });
  });

function showDetail(cat, value) {
  const overlay = document.querySelector('.detail-overlay');
  const content = document.getElementById('detail-content');
  overlay.style.display = '';
  overlay.style.background = overlayColorMap[cat] || "#180019";
  content.innerHTML = `
    <div class="detail-title" style="color:${colorMap[cat]};">${cat}</div>
    <div class="detail-desc">${value.description}</div>
    <ul class="task-list">
      ${value.tasks.map(t => `<li>${t}</li>`).join('')}
    </ul>
  `;
  document.body.style.overflow = 'hidden';
}

document.getElementById('go-back').onclick = () => {
  document.querySelector('.detail-overlay').style.display = 'none';
  document.body.style.overflow = '';
};

}