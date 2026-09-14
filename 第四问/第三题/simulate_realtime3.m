function [emg, pCh, pDis, socTrace, costEmg] = simulate_realtime3(...
    pBuy, loadAct, pvAct, price, N, dt, eta, socInit, ...
    socMin, socMax, pMax)

emg       = zeros(N, 1);
pCh      = zeros(N, 1);
pDis     = zeros(N, 1);
socTrace = zeros(N, 1);
soc = socInit;

for t = 1:N
    supply = pvAct(t) + pBuy(t);
    demand = loadAct(t);

    if supply >= demand
        surplus    = supply - demand;
        chLimE = (socMax - soc) / (eta * dt);
        chNow  = min([surplus, pMax, chLimE]);
        chNow  = max(chNow, 0);

        pCh(t) = chNow;
        soc = soc + chNow * eta * dt;
    else
        deficit     = demand - supply;
        disLimE = (soc - socMin) * eta / dt;
        disNow  = min([deficit, pMax, disLimE]);
        disNow  = max(disNow, 0);

        pDis(t) = disNow;
        soc = soc - disNow * dt / eta;

        remaining = deficit - disNow;
        emg(t) = max(remaining, 0);
    end

    soc = max(min(soc, socMax), socMin);
    socTrace(t) = soc;
end

costEmg = sum(5 * price .* emg) * dt;
end
