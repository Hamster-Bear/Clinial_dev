document.addEventListener("DOMContentLoaded", () => {
  class NavigationManager {
    constructor() {
      this.navbar = document.querySelector(".navbar");
      this.toggle = document.querySelector(".navbar-toggle");
      this.mobileMenu = document.getElementById("mobileMenu");
      this.closeButton = document.getElementById("closeMobileMenu");
      this.links = document.querySelectorAll(".nav-link, .mobile-nav-link");
      this.loadingOverlay = document.getElementById("loadingOverlay");
      this.initialize();
    }

    initialize() {
      this.toggle?.addEventListener("click", () => this.openMenu());
      this.closeButton?.addEventListener("click", () => this.closeMenu());

      this.links.forEach((link) => {
        link.addEventListener("click", (event) => {
          const href = link.getAttribute("href");

          if (!href) {
            return;
          }

          if (href.startsWith("#")) {
            event.preventDefault();
            this.scrollTo(href.slice(1));
          }

          if (href === "/app/") {
            this.showLoading();
          }

          this.closeMenu();
        });
      });

      window.addEventListener("scroll", () => {
        this.navbar?.classList.toggle("scrolled", window.scrollY > 8);
      });
    }

    openMenu() {
      this.mobileMenu?.classList.add("active");
      document.body.classList.add("menu-open");
    }

    closeMenu() {
      this.mobileMenu?.classList.remove("active");
      document.body.classList.remove("menu-open");
    }

    scrollTo(sectionId) {
      const section = document.getElementById(sectionId);
      if (!section) {
        return;
      }

      const offset = this.navbar ? this.navbar.offsetHeight + 16 : 0;
      window.scrollTo({
        top: section.offsetTop - offset,
        behavior: "smooth"
      });
    }

    showLoading() {
      if (!this.loadingOverlay) {
        return;
      }

      this.loadingOverlay.classList.add("active");
      const cleanUp = () => this.loadingOverlay.classList.remove("active");
      window.addEventListener("beforeunload", cleanUp, { once: true });
      setTimeout(cleanUp, 30000);
    }
  }

  class RevealManager {
    constructor() {
      this.items = document.querySelectorAll(".reveal");
      this.initialize();
    }

    initialize() {
      if (!("IntersectionObserver" in window)) {
        this.items.forEach((item) => item.classList.add("is-visible"));
        return;
      }

      const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      }, {
        threshold: 0.14,
        rootMargin: "0px 0px -40px 0px"
      });

      this.items.forEach((item) => observer.observe(item));
    }
  }

  new NavigationManager();
  new RevealManager();
});
