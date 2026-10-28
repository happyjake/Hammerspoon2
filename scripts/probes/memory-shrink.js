// Evaluate this body in the running app only during an idle period.
// Read JSON.stringify(globalThis.__hsMemoryShrinkProbe) after status is "done".
// Zone counters are malloc statistics, not VM-region dirty-byte measurements.
(() => {
    if (globalThis.__hsMemoryShrinkProbe?.status === "running") {
        throw new Error("A memory shrink probe is already running");
    }
    const N = 6;
    const settleSeconds = 2;
    const now = () => hs.timer.absoluteTime();
    const state = globalThis.__hsMemoryShrinkProbe = {
        status: "running", callsPerArm: N, settleSeconds, rows: []
    };
    const sample = () => {
        const s = hs.memory.stats();
        return {
            atNs: now(), footprint: s.footprint,
            webkit: s.malloc.zones.filter(z => /webkit/i.test(z.name)),
            js: s.js && {heapSize: s.js.heapSize, heapCapacity: s.js.heapCapacity}
        };
    };
    const fail = error => {
        state.status = "error";
        state.error = String(error);
    };
    let index = 0;
    const next = () => {
        try {
            const arm = index < N ? "control" : "shrink";
            const row = {arm, call: index % N + 1, before: sample()};
            state.rows.push(row);
            const start = now();
            row.result = arm === "control"
                ? hs.memory.relieve()
                : hs.memory.relieve({gc: true, malloc: false, shrink: true});
            row.requestMs = (now() - start) / 1e6;
            row.immediate = sample();
            const settleStart = now();
            hs.timer.doAfter(settleSeconds, () => {
                try {
                    row.settled = sample();
                    row.settleMs = (now() - settleStart) / 1e6;
                    row.footprintDelta = row.settled.footprint - row.before.footprint;
                    const loopStart = now();
                    let sum = 0;
                    for (let i = 0; i < 100000; i++) sum += i;
                    row.loopMs = (now() - loopStart) / 1e6;
                    row.loopSum = sum;
                    if (sum !== 4999950000) throw new Error("JS loop failed after relief");
                    if (arm === "shrink" && typeof row.result.shrinkAvailable !== "boolean") {
                        throw new Error("This app does not expose the shrink option");
                    }
                    index++;
                    if (index === 2 * N) state.status = "done";
                    else hs.timer.doAfter(0, next);
                } catch (error) { fail(error); }
            });
        } catch (error) { fail(error); }
    };
    hs.timer.doAfter(0, next);
    return "Scheduled 6 control calls, then 6 shrink calls; allow at least 24 seconds.";
})();
