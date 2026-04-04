// Hamster Analysis Landing Page - 主交互脚本

document.addEventListener('DOMContentLoaded', function() {
  // ============================================
  // 初始化函数
  // ============================================

  // 图表管理器
  class ChartManager {
    constructor() {
      this.chart = null;
      this.currentType = 'line';
      this.initializeChart();
      this.setupChartTabs();
      this.setupAutoUpdate();
    }

    // 初始化图表
    initializeChart() {
      const ctx = document.getElementById('demoChart').getContext('2d');

      // 初始数据（折线图）
      const data = this.getChartData('line');

      this.chart = new Chart(ctx, {
        type: 'line',
        data: data,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: true,
              position: 'top',
              labels: {
                font: {
                  family: "'Inter', sans-serif"
                },
                padding: 20,
                usePointStyle: true
              }
            },
            tooltip: {
              backgroundColor: 'rgba(15, 23, 42, 0.9)',
              titleFont: { family: "'Inter', sans-serif", size: 14 },
              bodyFont: { family: "'Inter', sans-serif", size: 13 },
              padding: 12,
              cornerRadius: 6,
              displayColors: true
            }
          },
          scales: {
            x: {
              grid: {
                color: 'rgba(203, 213, 225, 0.2)'
              },
              ticks: {
                font: {
                  family: "'Inter', sans-serif"
                }
              }
            },
            y: {
              beginAtZero: true,
              grid: {
                color: 'rgba(203, 213, 225, 0.2)'
              },
              ticks: {
                font: {
                  family: "'Inter', sans-serif"
                },
                callback: function(value) {
                  return value + '%';
                }
              }
            }
          },
          interaction: {
            intersect: false,
            mode: 'index'
          },
          animation: {
            duration: 750,
            easing: 'easeOutQuart'
          }
        }
      });

      this.updateChartStats(data);
    }

    // 获取图表数据
    getChartData(type) {
      if (typeof DemoData !== 'undefined') {
        switch(type) {
          case 'line':
            return DemoData.generateTrendData();
          case 'bar':
            return DemoData.generateComparisonData();
          case 'pie':
            return DemoData.generateDistributionData();
          default:
            return DemoData.generateTrendData();
        }
      } else {
        // 备用数据
        return this.getFallbackData(type);
      }
    }

    // 备用数据
    getFallbackData(type) {
      const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];

      switch(type) {
        case 'line':
          return {
            labels: months,
            datasets: [{
              label: '临床响应率',
              data: [65, 68, 72, 75, 78, 82, 85, 83, 80, 78, 76, 74],
              borderColor: '#2563eb',
              backgroundColor: 'rgba(37, 99, 235, 0.1)',
              borderWidth: 3,
              fill: true
            }]
          };
        case 'bar':
          return {
            labels: ['对照组', '低剂量', '中剂量', '高剂量'],
            datasets: [
              {
                label: '总缓解率',
                data: [35, 45, 60, 75],
                backgroundColor: 'rgba(16, 185, 129, 0.7)'
              },
              {
                label: '疾病控制率',
                data: [50, 65, 78, 85],
                backgroundColor: 'rgba(139, 92, 246, 0.7)'
              }
            ]
          };
        case 'pie':
          return {
            labels: ['完全缓解', '部分缓解', '疾病稳定', '疾病进展'],
            datasets: [{
              data: [15, 35, 40, 10],
              backgroundColor: ['#10b981', '#3b82f6', '#f59e0b', '#ef4444']
            }]
          };
      }
    }

    // 切换图表类型
    switchChart(type) {
      if (this.currentType === type) return;

      this.currentType = type;

      // 更新图表类型和数据
      this.chart.config.type = type === 'pie' ? 'pie' : type === 'bar' ? 'bar' : 'line';
      this.chart.data = this.getChartData(type);

      // 更新选项以适应不同类型的图表
      if (type === 'pie') {
        this.chart.options.scales = {};
      } else {
        this.chart.options.scales = {
          x: {
            grid: {
              color: 'rgba(203, 213, 225, 0.2)'
            },
            ticks: {
              font: {
                family: "'Inter', sans-serif"
              }
            }
          },
          y: {
            beginAtZero: true,
            grid: {
              color: 'rgba(203, 213, 225, 0.2)'
            },
            ticks: {
              font: {
                family: "'Inter', sans-serif"
              },
              callback: function(value) {
                return type === 'line' ? value + '%' : value;
              }
            }
          }
        };
      }

      this.chart.update('none');
      this.updateChartStats(this.chart.data);

      // 更新活动标签
      this.updateActiveTab(type);
    }

    // 设置图表标签切换
    setupChartTabs() {
      const tabs = document.querySelectorAll('.chart-tab');
      tabs.forEach(tab => {
        tab.addEventListener('click', () => {
          const type = tab.dataset.chart;
          this.switchChart(type);
        });
      });
    }

    // 更新活动标签
    updateActiveTab(type) {
      document.querySelectorAll('.chart-tab').forEach(tab => {
        if (tab.dataset.chart === type) {
          tab.classList.add('active');
        } else {
          tab.classList.remove('active');
        }
      });
    }

    // 更新图表统计信息
    updateChartStats(data) {
      const dataPoints = data.datasets.reduce((sum, dataset) => sum + dataset.data.length, 0);
      const now = new Date();
      const timeString = now.toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      });

      document.getElementById('dataPoints').textContent = dataPoints;
      document.getElementById('updateTime').textContent = timeString;
    }

    // 设置自动更新
    setupAutoUpdate() {
      // 每30秒更新一次数据
      setInterval(() => {
        this.chart.data = this.getChartData(this.currentType);
        this.chart.update('none');
        this.updateChartStats(this.chart.data);
      }, 30000);
    }
  }

  // ============================================
  // 计数器动画
  // ============================================

  class CounterAnimator {
    constructor() {
      this.counters = document.querySelectorAll('.stat-value[data-count]');
      this.observer = null;
      this.initialize();
    }

    initialize() {
      // 创建Intersection Observer来检测元素是否进入视口
      this.observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this.animateCounter(entry.target);
            this.observer.unobserve(entry.target);
          }
        });
      }, {
        threshold: 0.5,
        rootMargin: '0px 0px -100px 0px'
      });

      // 观察所有计数器
      this.counters.forEach(counter => {
        this.observer.observe(counter);
      });
    }

    animateCounter(element) {
      const target = parseInt(element.getAttribute('data-count'));
      const suffix = element.textContent.replace(/\d+/g, ''); // 保留非数字后缀
      const duration = 2000; // 动画时长（毫秒）
      const startTime = Date.now();
      const startValue = 0;

      const animate = () => {
        const elapsed = Date.now() - startTime;
        const progress = Math.min(elapsed / duration, 1);

        // 使用缓动函数使动画更自然
        const easeOutQuart = 1 - Math.pow(1 - progress, 4);
        const currentValue = Math.floor(startValue + (target - startValue) * easeOutQuart);

        // 格式化数字（添加千位分隔符）
        const formattedValue = currentValue.toLocaleString('zh-CN');
        element.textContent = formattedValue + suffix;

        if (progress < 1) {
          requestAnimationFrame(animate);
        } else {
          element.textContent = target.toLocaleString('zh-CN') + suffix;
        }
      };

      requestAnimationFrame(animate);
    }
  }

  // ============================================
  // 导航和移动端菜单
  // ============================================

  class NavigationManager {
    constructor() {
      this.navbarToggle = document.querySelector('.navbar-toggle');
      this.mobileMenu = document.getElementById('mobileMenu');
      this.closeMobileMenu = document.getElementById('closeMobileMenu');
      this.navLinks = document.querySelectorAll('.nav-link, .mobile-nav-link');
      this.initialize();
    }

    initialize() {
      // 移动端菜单切换
      if (this.navbarToggle) {
        this.navbarToggle.addEventListener('click', () => {
          this.mobileMenu.classList.add('active');
          document.body.style.overflow = 'hidden';
        });
      }

      if (this.closeMobileMenu) {
        this.closeMobileMenu.addEventListener('click', () => {
          this.mobileMenu.classList.remove('active');
          document.body.style.overflow = '';
        });
      }

      // 点击导航链接关闭移动端菜单
      this.navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
          if (link.classList.contains('primary') && link.getAttribute('href') === '/app/') {
            // 如果是进入应用的链接，显示加载指示器
            this.showLoading();
          }

          if (window.innerWidth < 768) {
            this.mobileMenu.classList.remove('active');
            document.body.style.overflow = '';
          }

          // 处理锚点链接的平滑滚动
          const href = link.getAttribute('href');
          if (href && href.startsWith('#')) {
            e.preventDefault();
            this.scrollToSection(href.substring(1));
          }
        });
      });

      // 监听滚动，更新导航栏样式
      window.addEventListener('scroll', () => {
        this.updateNavbarStyle();
      });

      // 初始更新导航栏样式
      this.updateNavbarStyle();
    }

    scrollToSection(sectionId) {
      const section = document.getElementById(sectionId);
      if (section) {
        const navbarHeight = document.querySelector('.navbar').offsetHeight;
        const targetPosition = section.offsetTop - navbarHeight - 20;

        window.scrollTo({
          top: targetPosition,
          behavior: 'smooth'
        });
      }
    }

    updateNavbarStyle() {
      const navbar = document.querySelector('.navbar');
      if (window.scrollY > 50) {
        navbar.style.boxShadow = '0 4px 20px rgba(15, 23, 42, 0.1)';
        navbar.style.backdropFilter = 'blur(10px)';
        navbar.style.backgroundColor = 'rgba(255, 255, 255, 0.95)';
      } else {
        navbar.style.boxShadow = '0 1px 2px 0 rgba(0, 0, 0, 0.05)';
        navbar.style.backdropFilter = 'none';
        navbar.style.backgroundColor = '';
      }
    }

    showLoading() {
      const loadingOverlay = document.getElementById('loadingOverlay');
      if (loadingOverlay) {
        loadingOverlay.classList.add('active');

        // 3秒后自动隐藏（模拟加载完成）
        setTimeout(() => {
          loadingOverlay.classList.remove('active');
        }, 3000);
      }
    }
  }

  // ============================================
  // 页面效果和交互
  // ============================================

  class PageEffects {
    constructor() {
      this.initializeAnimations();
      this.setupHoverEffects();
      this.setupFormInteractions();
    }

    initializeAnimations() {
      // 添加滚动触发动画的观察器
      const animatedElements = document.querySelectorAll('.feature-card, .app-card, .tech-item, .stat-card');

      const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            entry.target.classList.add('animate-in');
          }
        });
      }, {
        threshold: 0.1,
        rootMargin: '0px 0px -100px 0px'
      });

      animatedElements.forEach(element => {
        observer.observe(element);
      });
    }

    setupHoverEffects() {
      // 为卡片添加悬停效果
      const cards = document.querySelectorAll('.app-card, .feature-card');
      cards.forEach(card => {
        card.addEventListener('mouseenter', () => {
          card.style.transform = 'translateY(-8px)';
        });

        card.addEventListener('mouseleave', () => {
          card.style.transform = 'translateY(0)';
        });
      });
    }

    setupFormInteractions() {
      // 如果有表单元素，可以在这里添加交互
      // 例如：联系表单、订阅表单等
    }
  }

  // ============================================
  // 性能优化
  // ============================================

  class PerformanceOptimizer {
    constructor() {
      this.lazyImages = document.querySelectorAll('img[data-src]');
      this.initialize();
    }

    initialize() {
      this.setupLazyLoading();
      this.setupResourcePreloading();
    }

    setupLazyLoading() {
      if ('IntersectionObserver' in window) {
        const imageObserver = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              const img = entry.target;
              img.src = img.dataset.src;
              img.classList.remove('lazy');
              imageObserver.unobserve(img);
            }
          });
        });

        this.lazyImages.forEach(img => imageObserver.observe(img));
      } else {
        // 不支持IntersectionObserver的浏览器回退方案
        this.lazyImages.forEach(img => {
          img.src = img.dataset.src;
        });
      }
    }

    setupResourcePreloading() {
      // 预加载关键资源
      const preloadLinks = [
        '/landing/assets/images/hero-bg.svg',
        '/landing/assets/images/data-visual.svg'
      ];

      preloadLinks.forEach(href => {
        const link = document.createElement('link');
        link.rel = 'preload';
        link.as = 'image';
        link.href = href;
        document.head.appendChild(link);
      });
    }
  }

  // ============================================
  // 主初始化
  // ============================================

  // 初始化所有组件
  function init() {
    console.log('Hamster Analysis Landing Page - 初始化中...');

    // 检查浏览器支持
    if (!('querySelector' in document) || !('addEventListener' in window)) {
      console.warn('您的浏览器版本较旧，部分功能可能无法正常使用。');
      return;
    }

    // 浏览器兼容性检测
    function checkBrowserCompatibility() {
      const isIE = /MSIE|Trident/.test(navigator.userAgent);
      const isOldChrome = /Chrome\/([0-9]+)/.test(navigator.userAgent) && parseInt(RegExp.$1) < 80;
      const isOldFirefox = /Firefox\/([0-9]+)/.test(navigator.userAgent) && parseInt(RegExp.$1) < 78;

      if (isIE || isOldChrome || isOldFirefox) {
        const warning = document.getElementById('browserWarning');
        if (warning) {
          warning.style.display = 'block';
        }
      }
    }

    // 执行浏览器检测
    checkBrowserCompatibility();

    // 初始化各个管理器
    const chartManager = new ChartManager();
    const counterAnimator = new CounterAnimator();
    const navigationManager = new NavigationManager();
    const pageEffects = new PageEffects();
    const performanceOptimizer = new PerformanceOptimizer();

    // 设置全局错误处理
    window.addEventListener('error', function(e) {
      console.error('页面错误:', e.error);

      // 可以向用户显示友好的错误信息
      if (e.error && e.error.message && e.error.message.includes('Chart')) {
        console.warn('图表加载失败，显示备用数据');
      }
    });

    // 页面加载完成
    setTimeout(() => {
      document.body.classList.add('loaded');
      console.log('Hamster Analysis Landing Page - 初始化完成');
    }, 500);
  }

  // 开始初始化
  init();

  // ============================================
  // 工具函数
  // ============================================

  // 防抖函数
  function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  // 节流函数
  function throttle(func, limit) {
    let inThrottle;
    return function(...args) {
      if (!inThrottle) {
        func.apply(this, args);
        inThrottle = true;
        setTimeout(() => inThrottle = false, limit);
      }
    };
  }

  // 设备检测
  function getDeviceType() {
    const ua = navigator.userAgent;
    if (/Mobile|Android|iP(hone|od|ad)/.test(ua)) {
      return 'mobile';
    } else if (/Tablet|iPad/.test(ua)) {
      return 'tablet';
    } else {
      return 'desktop';
    }
  }

  // 主题检测
  function getPreferredTheme() {
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      return 'dark';
    }
    return 'light';
  }

  // 导出到全局（如果需要）
  window.HamsterAnalysis = {
    ChartManager,
    CounterAnimator,
    NavigationManager,
    PageEffects,
    PerformanceOptimizer,
    utils: {
      debounce,
      throttle,
      getDeviceType,
      getPreferredTheme
    }
  };
});