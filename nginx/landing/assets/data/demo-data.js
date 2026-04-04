// 模拟数据生成器 - 用于Chart.js图表展示

const DemoData = {
  // 生成趋势分析数据（折线图）
  generateTrendData: (points = 12) => {
    const labels = [];
    const data = [];
    let value = 50;

    for (let i = 0; i < points; i++) {
      const month = new Date(2026, i, 1).toLocaleDateString('zh-CN', { month: 'short' });
      labels.push(`${month}`);

      // 添加随机波动和趋势
      value += (Math.random() - 0.5) * 20;
      value = Math.max(30, Math.min(90, value));
      data.push(Math.round(value));
    }

    return {
      labels,
      datasets: [{
        label: '临床响应率 (%)',
        data,
        borderColor: '#2563eb',
        backgroundColor: 'rgba(37, 99, 235, 0.1)',
        borderWidth: 3,
        fill: true,
        tension: 0.4,
        pointRadius: 5,
        pointBackgroundColor: '#2563eb',
        pointBorderColor: '#ffffff',
        pointBorderWidth: 2
      }]
    };
  },

  // 生成对比分析数据（柱状图）
  generateComparisonData: () => {
    const groups = ['对照组', '低剂量组', '中剂量组', '高剂量组'];
    const metrics = ['总缓解率', '疾病控制率', '无进展生存期', '总生存期'];

    return {
      labels: groups,
      datasets: metrics.map((metric, index) => {
        const colors = ['#10b981', '#8b5cf6', '#f59e0b', '#ef4444'];
        return {
          label: metric,
          data: groups.map(() => Math.floor(Math.random() * 60) + 20),
          backgroundColor: `${colors[index]}80`, // 80表示50%透明度
          borderColor: colors[index],
          borderWidth: 2,
          borderRadius: 4
        };
      })
    };
  },

  // 生成分布分析数据（饼图）
  generateDistributionData: () => {
    const categories = [
      '完全缓解 (CR)',
      '部分缓解 (PR)',
      '疾病稳定 (SD)',
      '疾病进展 (PD)',
      '无法评估 (NE)'
    ];

    // 生成总和为100的数据
    const values = [];
    let remaining = 100;

    for (let i = 0; i < categories.length - 1; i++) {
      const value = Math.floor(Math.random() * (remaining / 2)) + 5;
      values.push(value);
      remaining -= value;
    }
    values.push(remaining);

    const colors = ['#10b981', '#3b82f6', '#f59e0b', '#ef4444', '#94a3b8'];

    return {
      labels: categories,
      datasets: [{
        data: values,
        backgroundColor: colors,
        borderColor: colors.map(color => color.replace('80', '')),
        borderWidth: 2,
        hoverOffset: 15
      }]
    };
  },

  // 生成实时更新数据（用于动态图表）
  generateRealTimeData: (count = 10) => {
    const labels = [];
    const data = [];

    const now = new Date();
    for (let i = count - 1; i >= 0; i--) {
      const time = new Date(now.getTime() - i * 60000);
      labels.push(time.toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      }));
      data.push(Math.floor(Math.random() * 100) + 50);
    }

    return {
      labels,
      datasets: [{
        label: '实时数据流',
        data,
        borderColor: '#8b5cf6',
        backgroundColor: 'rgba(139, 92, 246, 0.1)',
        borderWidth: 2,
        fill: true,
        tension: 0.4
      }]
    };
  },

  // 生成热图数据
  generateHeatmapData: (rows = 8, cols = 12) => {
    const rowLabels = ['基因A', '基因B', '基因C', '基因D', '基因E', '基因F', '基因G', '基因H'];
    const colLabels = Array.from({ length: cols }, (_, i) => `样本${i + 1}`);

    const data = [];
    for (let i = 0; i < rows; i++) {
      const row = [];
      for (let j = 0; j < cols; j++) {
        row.push(Math.random() * 2 - 1); // -1 到 1 的值
      }
      data.push(row);
    }

    return {
      rowLabels,
      colLabels,
      data
    };
  },

  // 获取统计数据
  getStats: () => ({
    totalDataPoints: 1523478,
    reportsGenerated: 2345,
    userSatisfaction: 98.2,
    systemUptime: 99.7,
    activeUsers: 124,
    dataProcessedToday: 12567
  }),

  // 获取平台指标
  getPlatformMetrics: () => [
    { label: '数据处理速度', value: '1.2M/秒', change: '+5.3%' },
    { label: '分析准确率', value: '99.2%', change: '+0.8%' },
    { label: '响应时间', value: '0.8秒', change: '-12%' },
    { label: '并发用户', value: '256', change: '+18%' }
  ]
};

// 如果是在浏览器环境中，将DemoData附加到window对象
if (typeof window !== 'undefined') {
  window.DemoData = DemoData;
}