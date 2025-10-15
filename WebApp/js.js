fetch("http://localhost:8080/challenge")
  .then(res => res.json())
  .then(data => {
    console.log(data);
    const content = document.getElementById("content");
    
    for (let category in data) {
      content.innerHTML += `<h2>${category}</h2><ul>${data[category].map(task => `<li>${task}</li>`).join('')}</ul>`;
    }
  });
