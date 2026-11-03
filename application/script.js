// Menu responsivo e indicador de protocolo (HTTPS via CloudFront).
(function () {
  "use strict";

  var toggle = document.querySelector(".menu-toggle");
  var menu = document.getElementById("menu");

  if (toggle && menu) {
    toggle.addEventListener("click", function () {
      var aberto = menu.classList.toggle("open");
      toggle.setAttribute("aria-expanded", String(aberto));
    });
    menu.addEventListener("click", function (e) {
      if (e.target.tagName === "A") {
        menu.classList.remove("open");
        toggle.setAttribute("aria-expanded", "false");
      }
    });
  }

  var status = document.getElementById("status");
  if (status) {
    if (location.protocol === "https:") {
      status.textContent = "Conexão segura (HTTPS) entregue pelo CloudFront.";
    } else {
      status.textContent = "Você está em " + location.protocol + " - acesse a URL HTTPS do CloudFront.";
    }
  }
})();
