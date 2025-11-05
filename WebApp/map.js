const map = L.map('map').setView([48.2082, 16.3738], 16);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap-Mitwirkende'
    }).addTo(map);

    let marker = null;
    let circle = null;
    let currentPos = null;
    let targetPos = null;

    // Funktion zum glatten Bewegen des Markers
    function smoothMove() {
      if (!currentPos || !targetPos) return;

      const speed = 0.1; // Bewegungsgeschwindigkeit (0.1 = weich)
      currentPos.lat += (targetPos.lat - currentPos.lat) * speed;
      currentPos.lng += (targetPos.lng - currentPos.lng) * speed;

      marker.setLatLng(currentPos);
      circle.setLatLng(currentPos);

      requestAnimationFrame(smoothMove); // Gameloop 😎
    }

    function updatePosition(position) {
      const lat = position.coords.latitude;
      const lng = position.coords.longitude;
      const accuracy = position.coords.accuracy;

      targetPos = { lat, lng };

      if (!marker) {
        currentPos = { lat, lng };
        marker = L.marker([lat, lng]).addTo(map).bindPopup("Du bist hier 📍");
        circle = L.circle([lat, lng], { radius: accuracy }).addTo(map);
        map.setView([lat, lng], 16);
        smoothMove(); // Starte Gameloop
      } else {
        circle.setRadius(accuracy);
      }
    }

    function onError(error) {
      console.error("Fehler:", error.message);
    }

    // watchPosition mit höherer Aktualisierungsrate
    if ("geolocation" in navigator) {
      navigator.geolocation.watchPosition(updatePosition, onError, {
        enableHighAccuracy: true,
        maximumAge: 1000, // max 1 Sekunde alte Daten
        timeout: 3000
      });
    } else {
      alert("Geolocation wird von deinem Browser nicht unterstützt.");
    }