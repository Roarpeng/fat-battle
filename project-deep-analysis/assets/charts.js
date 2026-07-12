(function() {
  var style = getComputedStyle(document.documentElement);
  var accent = style.getPropertyValue('--accent').trim();
  var accent2 = style.getPropertyValue('--accent2').trim();
  var accent3 = style.getPropertyValue('--accent3').trim();
  var ink = style.getPropertyValue('--ink').trim();
  var muted = style.getPropertyValue('--muted').trim();
  var rule = style.getPropertyValue('--rule').trim();
  var bg2 = style.getPropertyValue('--bg2').trim();
  var bg3 = style.getPropertyValue('--bg3').trim();
  var danger = style.getPropertyValue('--danger').trim();
  var warning = style.getPropertyValue('--warning').trim();
  var success = style.getPropertyValue('--success').trim();

  // --- Chart 1: File Lines Bar Chart ---
  var chart1 = echarts.init(document.getElementById('chart-file-lines'), null, { renderer: 'svg' });
  chart1.setOption({
    animation: false,
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      backgroundColor: bg2,
      borderColor: rule,
      textStyle: { color: ink, fontSize: 13 },
      appendToBody: true
    },
    grid: { left: '3%', right: '5%', bottom: '3%', top: '3%', containLabel: true },
    xAxis: {
      type: 'value',
      max: 1500,
      axisLine: { lineStyle: { color: rule } },
      axisLabel: { color: muted, fontSize: 11 },
      splitLine: { lineStyle: { color: rule, type: 'dashed' } }
    },
    yAxis: {
      type: 'category',
      data: [
        'poseService.ts',
        'PoseDetectionPage.tsx',
        'BattlePage.tsx',
        'BluetoothPage.tsx',
        'SetupPage.tsx',
        'BattleEffects.tsx',
        'monsters.ts',
        'foods.ts',
        'FoodRecognitionModal.tsx',
        'SettingsPage.tsx',
        'bluetoothService.ts',
        'FoodPage.tsx',
        'ExercisePage.tsx',
        'CodexPage.tsx',
        'monsterTaunts.ts'
      ],
      axisLine: { lineStyle: { color: rule } },
      axisLabel: { color: ink, fontSize: 11 },
      inverse: true
    },
    series: [{
      type: 'bar',
      data: [
        { value: 1429, itemStyle: { color: danger } },
        { value: 1384, itemStyle: { color: danger } },
        { value: 792, itemStyle: { color: warning } },
        { value: 742, itemStyle: { color: warning } },
        { value: 651, itemStyle: { color: accent3 } },
        { value: 619, itemStyle: { color: accent3 } },
        { value: 613, itemStyle: { color: accent3 } },
        { value: 602, itemStyle: { color: accent2 } },
        { value: 474, itemStyle: { color: accent2 } },
        { value: 460, itemStyle: { color: accent2 } },
        { value: 427, itemStyle: { color: accent2 } },
        { value: 418, itemStyle: { color: accent2 } },
        { value: 376, itemStyle: { color: accent2 } },
        { value: 365, itemStyle: { color: accent2 } },
        { value: 348, itemStyle: { color: accent2 } }
      ],
      barWidth: '60%',
      label: {
        show: true,
        position: 'right',
        color: muted,
        fontSize: 11,
        formatter: '{c} lines'
      }
    }]
  });
  window.addEventListener('resize', function() { chart1.resize(); });

  // --- Chart 2: Priority Matrix Scatter ---
  var chart2 = echarts.init(document.getElementById('chart-priority-matrix'), null, { renderer: 'svg' });
  chart2.setOption({
    animation: false,
    tooltip: {
      trigger: 'item',
      backgroundColor: bg2,
      borderColor: rule,
      textStyle: { color: ink, fontSize: 13 },
      appendToBody: true,
      formatter: function(params) {
        return '<b>' + params.data.name + '</b><br/>' +
               '影响度: ' + params.data.value[0] + '/10<br/>' +
               '复杂度: ' + params.data.value[1] + '/10<br/>' +
               '优先级: ' + params.data.priority;
      }
    },
    grid: { left: '8%', right: '15%', bottom: '12%', top: '8%' },
    xAxis: {
      type: 'value',
      name: '实施复杂度',
      nameLocation: 'middle',
      nameGap: 30,
      nameTextStyle: { color: muted, fontSize: 12 },
      min: 0, max: 11,
      axisLine: { lineStyle: { color: rule } },
      axisLabel: { color: muted, fontSize: 11 },
      splitLine: { lineStyle: { color: rule, type: 'dashed' } }
    },
    yAxis: {
      type: 'value',
      name: '问题影响度',
      nameLocation: 'middle',
      nameGap: 40,
      nameTextStyle: { color: muted, fontSize: 12 },
      min: 0, max: 11,
      axisLine: { lineStyle: { color: rule } },
      axisLabel: { color: muted, fontSize: 11 },
      splitLine: { lineStyle: { color: rule, type: 'dashed' } }
    },
    series: [{
      type: 'scatter',
      symbolSize: function(data) { return data.size || 20; },
      data: [
        { name: '1. 接入真实食物识别API', value: [7, 10], priority: 'Critical', size: 28, itemStyle: { color: danger } },
        { name: '2. 统一两端游戏算法', value: [8, 10], priority: 'Critical', size: 28, itemStyle: { color: danger } },
        { name: '3. 拆分poseService.ts', value: [6, 8], priority: 'High', size: 24, itemStyle: { color: warning } },
        { name: '4. 拆分PoseDetectionPage', value: [5, 8], priority: 'High', size: 24, itemStyle: { color: warning } },
        { name: '5. 升级为IndexedDB', value: [4, 7], priority: 'High', size: 24, itemStyle: { color: warning } },
        { name: '6. 添加Error Boundary', value: [3, 6], priority: 'Medium', size: 20, itemStyle: { color: accent3 } },
        { name: '7. 路由懒加载', value: [2, 5], priority: 'Medium', size: 20, itemStyle: { color: accent3 } },
        { name: '8. 补充单元测试', value: [6, 6], priority: 'Medium', size: 20, itemStyle: { color: accent3 } },
        { name: '9. 状态订阅优化', value: [3, 4], priority: 'Low', size: 16, itemStyle: { color: success } },
        { name: '10. PWA离线完善', value: [4, 3], priority: 'Low', size: 16, itemStyle: { color: success } }
      ],
      label: {
        show: true,
        position: 'right',
        color: ink,
        fontSize: 10,
        formatter: function(params) {
          return params.data.name.split('. ')[0];
        }
      }
    },
    {
      type: 'scatter',
      symbolSize: 0,
      data: [[5.5, 5.5]],
      markLine: {
        silent: true,
        symbol: 'none',
        lineStyle: { color: rule, type: 'dashed', width: 1 },
        data: [
          { xAxis: 5.5 },
          { yAxis: 5.5 }
        ],
        label: { show: false }
      }
    }],
    graphic: [
      {
        type: 'text',
        right: '5%',
        top: '5%',
        style: { text: '高影响 + 低复杂度\n(立即行动)', fill: success, fontSize: 11 }
      },
      {
        type: 'text',
        left: '5%',
        top: '5%',
        style: { text: '高影响 + 高复杂度\n(优先规划)', fill: danger, fontSize: 11 }
      },
      {
        type: 'text',
        right: '5%',
        bottom: '15%',
        style: { text: '低影响 + 低复杂度\n(快速完成)', fill: accent3, fontSize: 11 }
      },
      {
        type: 'text',
        left: '5%',
        bottom: '15%',
        style: { text: '低影响 + 高复杂度\n(暂缓)', fill: muted, fontSize: 11 }
      }
    ]
  });
  window.addEventListener('resize', function() { chart2.resize(); });
})();
