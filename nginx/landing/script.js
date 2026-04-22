document.addEventListener("DOMContentLoaded", () => {
  const chartDefinitions = {
    survival: {
      chartType: "line",
      title: "示意生存趋势",
      description: "示意 AutoTFL 生成 Kaplan-Meier 结果时的图层结构，帮助预判最终交付图的表达方式。",
      data: {
        labels: ["0月", "3月", "6月", "9月", "12月", "15月"],
        datasets: [
          {
            label: "治疗组",
            data: [100, 93, 86, 79, 71, 66],
            borderColor: "#f97316",
            backgroundColor: "rgba(249, 115, 22, 0.2)",
            fill: true,
            tension: 0.35,
            borderWidth: 3,
            pointRadius: 3
          },
          {
            label: "对照组",
            data: [100, 88, 77, 67, 58, 49],
            borderColor: "#ffb36a",
            backgroundColor: "rgba(255, 179, 106, 0.14)",
            fill: true,
            tension: 0.35,
            borderWidth: 3,
            pointRadius: 3
          }
        ]
      }
    },
    compare: {
      chartType: "bar",
      title: "示意组间比较",
      description: "示意组间比较结果的阅读方式，帮助理解 AutoTFL 在研究汇报中可直接使用的输出形态。",
      data: {
        labels: ["对照组", "低剂量", "中剂量", "高剂量"],
        datasets: [
          {
            label: "响应率",
            data: [34, 46, 58, 71],
            backgroundColor: ["#4b2414", "#7c3716", "#c75410", "#ff9f43"],
            borderRadius: 10
          }
        ]
      }
    },
    response: {
      chartType: "doughnut",
      title: "示意响应构成",
      description: "示意响应构成与疗效分布输出，用于展示 AutoTFL 如何把结果摘要组织成可读图形。",
      data: {
        labels: ["完全缓解", "部分缓解", "疾病稳定", "疾病进展"],
        datasets: [
          {
            data: [12, 34, 38, 16],
            backgroundColor: ["#f97316", "#ff9f43", "#ffb36a", "#4b2414"],
            borderWidth: 0
          }
        ]
      }
    }
  };

  class ChartManager {
    constructor() {
      this.canvas = document.getElementById("demoChart");
      this.chartTitle = document.getElementById("chartTitle");
      this.chartDescription = document.getElementById("chartDescription");
      this.dataPoints = document.getElementById("dataPoints");
      this.updateTime = document.getElementById("updateTime");
      this.tabs = Array.from(document.querySelectorAll(".chart-tab"));
      this.currentKey = "survival";
      this.chart = null;
      this.initialize();
    }

    initialize() {
      if (!this.canvas || typeof Chart === "undefined") {
        return;
      }

      this.chart = new Chart(this.canvas.getContext("2d"), {
        type: chartDefinitions[this.currentKey].chartType,
        data: chartDefinitions[this.currentKey].data,
        options: this.getOptions(this.currentKey)
      });

      this.syncSummary(this.currentKey);
      this.tabs.forEach((tab) => {
        tab.addEventListener("click", () => this.switchChart(tab.dataset.chart));
      });
    }

    getOptions(key) {
      const isRoundChart = key === "response";

      return {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
          duration: 500,
          easing: "easeOutQuart"
        },
        plugins: {
          legend: {
            display: true,
            position: "top",
            labels: {
              usePointStyle: true,
              boxWidth: 8,
              color: "#ffe7d2",
              font: {
                family: "'Inter', sans-serif",
                size: 12
              }
            }
          },
          tooltip: {
            backgroundColor: "rgba(24, 16, 14, 0.94)",
            titleFont: {
              family: "'Inter', sans-serif",
              size: 13
            },
            bodyFont: {
              family: "'Inter', sans-serif",
              size: 12
            },
            padding: 12,
            cornerRadius: 10
          }
        },
        scales: isRoundChart
          ? {}
          : {
              x: {
                grid: {
                  display: false
                },
                ticks: {
                  color: "rgba(255, 224, 196, 0.7)",
                  font: {
                    family: "'Inter', sans-serif"
                  }
                }
              },
              y: {
                beginAtZero: true,
                grid: {
                  color: "rgba(249, 115, 22, 0.16)"
                },
                ticks: {
                  color: "rgba(255, 224, 196, 0.7)",
                  font: {
                    family: "'Inter', sans-serif"
                  },
                  callback: (value) => `${value}`
                }
              }
            }
      };
    }

    switchChart(key) {
      if (!this.chart || !chartDefinitions[key] || key === this.currentKey) {
        return;
      }

      this.currentKey = key;
      this.chart.config.type = chartDefinitions[key].chartType;
      this.chart.data = chartDefinitions[key].data;
      this.chart.options = this.getOptions(key);
      this.chart.update();
      this.syncSummary(key);
      this.tabs.forEach((tab) => tab.classList.toggle("active", tab.dataset.chart === key));
    }

    syncSummary(key) {
      const definition = chartDefinitions[key];
      const pointCount = definition.data.datasets.reduce((total, dataset) => total + dataset.data.length, 0);
      const now = new Date().toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit"
      });

      if (this.chartTitle) {
        this.chartTitle.textContent = definition.title;
      }

      if (this.chartDescription) {
        this.chartDescription.textContent = definition.description;
      }

      if (this.dataPoints) {
        this.dataPoints.textContent = pointCount.toLocaleString("zh-CN");
      }

      if (this.updateTime) {
        this.updateTime.textContent = now;
      }
    }
  }

  class CounterAnimator {
    constructor() {
      this.counters = document.querySelectorAll(".fact-number[data-count]");
      this.initialize();
    }

    initialize() {
      if (!("IntersectionObserver" in window)) {
        this.counters.forEach((counter) => {
          counter.textContent = counter.dataset.count;
        });
        return;
      }

      const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) {
            return;
          }

          this.animate(entry.target);
          observer.unobserve(entry.target);
        });
      }, { threshold: 0.5 });

      this.counters.forEach((counter) => observer.observe(counter));
    }

    animate(element) {
      const target = Number(element.dataset.count || 0);
      const start = performance.now();
      const duration = 900;

      const step = (time) => {
        const progress = Math.min((time - start) / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        const current = Math.round(target * eased);
        element.textContent = current.toLocaleString("zh-CN");

        if (progress < 1) {
          requestAnimationFrame(step);
        }
      };

      requestAnimationFrame(step);
    }
  }

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

  new ChartManager();
  new CounterAnimator();
  new NavigationManager();
  new RevealManager();
});
