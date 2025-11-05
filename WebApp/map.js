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

    console.log(`Position: ${lat.toFixed(6)}, ${lng.toFixed(6)} (±${Math.round(acc)}m)`);
    currentposition = [lat, lng, acc];
    console.log(currentposition);

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