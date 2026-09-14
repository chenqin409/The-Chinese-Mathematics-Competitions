function [pBuy, pCh, pDis, soc] = optimize_daily(...
    loadPred, pvPred, price, N, dt, eta, socInit, socMin, socMax, pMax, socEndMin)

if nargin < 11
    socEndMin = 0;
end

nVar = 5 * N;

f = zeros(nVar,1);
f(1:N) = price * dt;

nEq = 2 * N;
Aeq = sparse(nEq, nVar);
beq = zeros(nEq, 1);

for t = 1:N
    Aeq(t, t) = 1;
    Aeq(t, N+t) = -1;
    Aeq(t, 2*N+t) = 1;
    Aeq(t, 4*N+t) = -1;
    beq(t) = loadPred(t) - pvPred(t);
end

for t = 1:N
    row = N + t;
    Aeq(row, 3*N+t) = 1;
    Aeq(row, N+t) = -eta*dt;
    Aeq(row, 2*N+t) = dt/eta;
    if t > 1
        Aeq(row, 3*N+t-1) = -1;
    else
        beq(row) = socInit;
    end
end

if socEndMin > socMin
    nUb = 2*N + 1;
else
    nUb = 2*N;
end
Aub = sparse(nUb, nVar);
bUb = zeros(nUb, 1);
for t = 1:N
    Aub(t, 3*N+t) = 1;      bUb(t) = socMax;
    Aub(N+t, 3*N+t) = -1;   bUb(N+t) = -socMin;
end
if socEndMin > socMin
    Aub(nUb, 3*N+N) = -1;
    bUb(nUb) = -socEndMin;
end

lb = zeros(nVar,1);
ub = inf(nVar,1);
ub(N+1:2*N) = pMax;
ub(2*N+1:3*N) = pMax;
lb(3*N+1:4*N) = socMin;
ub(3*N+1:4*N) = socMax;

options = optimoptions('linprog', 'Display', 'off');
[x, ~, exitflag] = linprog(f, Aub, bUb, Aeq, beq, lb, ub, options);

if exitflag == 1
    pBuy = max(x(1:N), 0);
    pCh = max(x(N+1:2*N), 0);
    pDis = max(x(2*N+1:3*N), 0);
    soc = x(3*N+1:4*N);
else
    pBuy = []; pCh = []; pDis = []; soc = [];
end
end
