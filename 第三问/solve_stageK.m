function [pBuy, pCh, pDis, soc, dPup, dPdown] = solve_stageK(...
    loadPred, pvPred, price, M, dt, eta, socInit, ...
    socMin, socMax, pMax, pPlanSeg, isLastDay)

nVar = 7 * M;

maxReachSoc = socInit;
for t = 1:M
    maxReachSoc = min(maxReachSoc + pMax * eta * dt, socMax);
end
if isLastDay
    socReserveTarget = min(6000, maxReachSoc);
else
    socReserveTarget = [];
end

f = zeros(nVar, 1);
f(5*M+1:6*M) = 1.5 * price(1:M) * dt;
f(6*M+1:7*M) = 0.5 * price(1:M) * dt;

nEq = 3 * M;
Aeq = sparse(nEq, nVar);
beq = zeros(nEq, 1);

for t = 1:M
    row = t;
    Aeq(row, t) = 1;
    Aeq(row, M+t) = -1;
    Aeq(row, 2*M+t) = 1;
    Aeq(row, 3*M+t) = -1;
    beq(row) = loadPred(t) - pvPred(t);
end

for t = 1:M
    row = M + t;
    Aeq(row, 4*M+t) = 1;
    Aeq(row, M+t) = -eta * dt;
    Aeq(row, 2*M+t) = dt / eta;
    if t > 1
        Aeq(row, 4*M+t-1) = -1;
    else
        beq(row) = socInit;
    end
end

for t = 1:M
    row = 2*M + t;
    Aeq(row, t) = 1;
    Aeq(row, 5*M+t) = -1;
    Aeq(row, 6*M+t) = 1;
    beq(row) = pPlanSeg(t);
end

nUb = 2 * M;
if ~isempty(socReserveTarget), nUb = nUb + 1; end
Aub = sparse(nUb, nVar);
bUb = zeros(nUb, 1);
rowNum = 0;
for t = 1:M
    rowNum = rowNum + 1;
    Aub(rowNum, 4*M+t) = 1;  bUb(rowNum) = socMax;
    rowNum = rowNum + 1;
    Aub(rowNum, 4*M+t) = -1; bUb(rowNum) = -socMin;
end
if ~isempty(socReserveTarget)
    rowNum = rowNum + 1;
    Aub(rowNum, 4*M+M) = -1;
    bUb(rowNum) = -socReserveTarget;
end

lb = zeros(nVar, 1);
ub = inf(nVar, 1);
ub(M+1:2*M) = pMax;
ub(2*M+1:3*M) = pMax;
lb(4*M+1:5*M) = socMin;
ub(4*M+1:5*M) = socMax;

options = optimoptions('linprog', 'Display', 'off', 'Algorithm', 'dual-simplex');
[x, ~, exitflag] = linprog(f, Aub, bUb, Aeq, beq, lb, ub, options);

if exitflag == 1
    pBuy  = max(x(1:M), 0);
    pCh   = max(x(M+1:2*M), 0);
    pDis  = max(x(2*M+1:3*M), 0);
    soc      = x(4*M+1:5*M);
    dPup = max(x(5*M+1:6*M), 0);
    dPdown = max(x(6*M+1:7*M), 0);
else
    pBuy = []; pCh = []; pDis = []; soc = []; dPup = []; dPdown = [];
end
end
