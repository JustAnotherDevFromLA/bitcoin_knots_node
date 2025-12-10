const express = require('express');
const si = require('systeminformation');
const app = express();
const port = 3000;

app.use(express.static('public'));

app.get('/api/metrics', async (req, res) => {
    try {
        const [cpu, mem, fsStats, networkStats] = await Promise.all([
            si.currentLoad(),
            si.mem(),
            si.fsStats(),
            si.networkStats()
        ]);

        const diskIO = {
            rIO: fsStats.rIO,
            wIO: fsStats.wIO,
            tIO: fsStats.tIO
        };

        const network = {
            rx_sec: networkStats[0].rx_sec,
            tx_sec: networkStats[0].tx_sec
        };

        res.json({
            cpu: cpu.currentLoad,
            memory: {
                total: mem.total,
                used: mem.used
            },
            diskIO,
            network
        });
    } catch (e) {
        res.status(500).send('Error retrieving system metrics');
    }
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Server listening at http://0.0.0.0:${port}`);
});
