// Evaluate this body in the running application's JavaScript context.
(() => {
    const app = hs.application;
    const N = 200;
    const now = () => hs.timer.absoluteTime();
    const warm = app.installedApps();
    let sameIdentity = true;
    let sink = 0;
    let start = now();
    for (let i = 0; i < N; i++) {
        const value = app.installedApps();
        sameIdentity = sameIdentity && value === warm;
        sink += value.length;
    }
    const hitMeanUs = (now() - start) / N / 1000;

    start = now();
    for (let i = 0; i < N; i++) sink += JSON.parse(JSON.stringify(warm)).length;
    const jsonRoundTripMeanUs = (now() - start) / N / 1000;

    app.invalidateInstalledAppsCache();
    start = now();
    const rescanned = app.installedApps();
    const forcedRescanMs = (now() - start) / 1e6;

    const ids = [];
    for (const record of rescanned) {
        if (app.pathForBundleID(record.bundleID)) ids.push(record.bundleID);
        if (ids.length === 8) break;
    }
    if (ids.length !== 8) throw new Error('Eight installed applications are required');
    const firstIcons = [];
    const iconsMsByRound = [];
    let iconBytesEqual = true;
    let iconsPresent = true;
    for (let round = 0; round < 5; round++) {
        start = now();
        for (let i = 0; i < ids.length; i++) {
            const icon = app.iconForBundleID(ids[i]);
            iconsPresent = iconsPresent && typeof icon === 'string' && icon.length > 0;
            if (round === 0) firstIcons[i] = icon;
            else iconBytesEqual = iconBytesEqual && icon === firstIcons[i];
        }
        iconsMsByRound.push((now() - start) / 1e6);
    }
    return JSON.stringify({
        calls: N, apps: warm.length, hitMeanUs, sameIdentity,
        jsonRoundTripMeanUs, forcedRescanMs,
        icons: ids.length, iconRounds: 5, iconsMsByRound,
        warmIconMeanUs: iconsMsByRound.slice(1).reduce((sum, ms) => sum + ms, 0) * 1000 / 32,
        iconBytesEqual, iconsPresent, sink
    });
})();
