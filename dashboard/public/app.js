document.addEventListener('DOMContentLoaded', () => {
    const metricsGrid = document.getElementById('metrics-grid');

    const createMetricCard = (title, id, isChart = true) => {
        const card = document.createElement('div');
        card.className = 'metric-card';

        let content = `<h2>${title}</h2>`;
        if (isChart) {
            content += `<div class="chart-container"><canvas id="${id}Chart"></canvas></div>
                        <p id="${id}-usage" class="metric-value">Loading...</p>`;
        } else {
            content += `<p id="${id}" class="metric-value">Loading...</p>`;
        }
        card.innerHTML = content;
        metricsGrid.appendChild(card);
    };

    // Create the layout once
    createMetricCard('CPU Usage', 'cpu', true);
    createMetricCard('Memory Usage', 'mem', true);
    createMetricCard('Disk Read', 'disk-read', false);
    createMetricCard('Disk Write', 'disk-write', false);
    createMetricCard('Network Received', 'net-rx', false);
    createMetricCard('Network Transmitted', 'net-tx', false);

    // Get references to the elements that will be updated
    const cpuUsageText = document.getElementById('cpu-usage');
    const memUsageText = document.getElementById('mem-usage');
    const diskReadEl = document.getElementById('disk-read');
    const diskWriteEl = document.getElementById('disk-write');
    const netRxEl = document.getElementById('net-rx');
    const netTxEl = document.getElementById('net-tx');
    
    const cpuCtx = document.getElementById('cpuChart').getContext('2d');
    const memCtx = document.getElementById('memChart').getContext('2d');

    const createChart = (ctx, label) => {
        return new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: [label, 'Free'],
                datasets: [{
                    data: [0, 100],
                    backgroundColor: ['var(--primary-color)', '#eeeeee'],
                    hoverBackgroundColor: ['var(--primary-color)', '#eeeeee'],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutoutPercentage: 80,
                animation: {
                    duration: 200 // Faster animation
                },
                legend: {
                    display: false
                },
                tooltips: {
                    enabled: false
                }
            }
        });
    };

    const cpuChart = createChart(cpuCtx, 'CPU Usage');
    const memChart = createChart(memCtx, 'Memory Usage');

    const updateChart = (chart, used) => {
        chart.data.datasets[0].data[0] = used;
        chart.data.datasets[0].data[1] = 100 - used;
        chart.update('none'); // Use 'none' to prevent animation reset
    };

    const formatBytes = (bytes, decimals = 2) => {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
    };

    const fetchData = async () => {
        try {
            const response = await fetch('/api/metrics');
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();

            // CPU
            const cpuUsed = data.cpu.toFixed(2);
            updateChart(cpuChart, cpuUsed);
            cpuUsageText.textContent = `${cpuUsed}%`;

            // Memory
            const memUsedPercent = ((data.memory.used / data.memory.total) * 100).toFixed(2);
            updateChart(memChart, memUsedPercent);
            memUsageText.textContent = `${formatBytes(data.memory.used)} / ${formatBytes(data.memory.total)}`;

            // Disk I/O
            diskReadEl.textContent = formatBytes(data.diskIO.rIO);
            diskWriteEl.textContent = formatBytes(data.diskIO.wIO);

            // Network
            netRxEl.textContent = `${formatBytes(data.network.rx_sec)}/s`;
            netTxEl.textContent = `${formatBytes(data.network.tx_sec)}/s`;

        } catch (error) {
            console.error('Error fetching data:', error);
        }
    };

    setInterval(fetchData, 2000);
    fetchData();
});