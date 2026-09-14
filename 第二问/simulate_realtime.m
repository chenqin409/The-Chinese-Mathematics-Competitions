function [emg, costPlan, costEmg, socHist] = simulate_realtime(...
        pBuy, pCh, pDis, loadAct, pvAct, price, dt, ...
        socInit, eta, socMin, socMax, pMax)

    N = length(pBuy);
    emg = zeros(N,1);
    socHist = zeros(N,1);
    soc = socInit;

    for t = 1:N
        available = pvAct(t) + pBuy(t);
        need = loadAct(t);

        if available >= need
            surplus = available - need;

            chLimP = pMax;
            chLimE = (socMax - soc) / (eta * dt);
            chNow = min([surplus, chLimP, chLimE]);
            chNow = max(chNow, 0);

            disNow = 0;
            emg(t) = 0;
        else
            deficit = need - available;

            chNow = 0;

            disLimP = pMax;
            disLimE = (soc - socMin) * eta / dt;
            disNow = min([deficit, disLimP, disLimE]);
            disNow = max(disNow, 0);

            deficit = deficit - disNow;

            emg(t) = max(deficit, 0);
        end

        soc = soc + eta * chNow * dt - disNow * dt / eta;
        soc = max(min(soc, socMax), socMin);
        socHist(t) = soc;
    end

    costPlan = sum(price .* pBuy * dt);
    costEmg  = sum(5 * price .* emg * dt);
end
