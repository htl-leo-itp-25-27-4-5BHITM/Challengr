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
    const cardList = document.querySelector('.card-list');
    cardList.innerHTML = '';
    const sortList = ["Fitness", "Mutprobe", "Wissen", "Suchen"];
    sortList.forEach(cat => {
      if(!(cat in data)) return;
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
