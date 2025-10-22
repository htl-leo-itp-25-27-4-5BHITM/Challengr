fetch("http://localhost:8080/challenge")
  .then(res => res.json())
  .then(data => {
    const cards = document.getElementById("category-cards");
    const overlay = document.getElementById("full-overlay");
    const overlayTitle = document.getElementById("overlay-title");
    const overlayList = document.getElementById("overlay-list");
    const goBack = document.getElementById("go-back");

    cards.innerHTML = '';
    Object.entries(data).forEach(([cat, value]) => {
      // value: { description: "...", tasks: [...] }
      const card = document.createElement('div');
      card.className = 'category-card';
      card.innerHTML = `
        <span class="category-title">${cat}</span>
        <span class="category-desc">${value.description}</span>
      `;
      card.addEventListener('click', () => {
        overlay.style.display = '';
        overlayTitle.textContent = cat;
        overlayList.innerHTML = value.tasks.map(t => `<li>${t}</li>`).join('');
        document.body.style.overflow = 'hidden';
      });
      cards.appendChild(card);
    });

    goBack.onclick = () => {
      overlay.style.display = 'none';
      document.body.style.overflow = '';
    };
  });
