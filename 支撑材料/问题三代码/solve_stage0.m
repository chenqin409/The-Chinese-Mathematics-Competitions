function [pPlan, pCh, pDis, soc] = solve_stage0(...
    loadPred, pvPred, price, N, dt, eta, socInit, ...
    socMin, socMax, pMax, isLastDay)

nVar = 5 * N;

f = zeros(nVar, 1);
f(1:N) = price * dt;

nEq = 3 * N;
Aeq = zeros(nEq, nVar);
beq = zeros(nEq, 1);

for t = 1:N
    row = t;
    Aeq(row, t) = 1;
    Aeq(row, N+t) = -1;
    Aeq(row, 2*N+t) = 1;
    Aeq(row, 3*N+t) = -1;
    beq(row) = loadPred(t) - pvPred(t);
end

for t = 1:N
    row = N + t;
    Aeq(row, 2*N+t) = dt / eta;
    Aeq(row, N+t) = -eta * dt;
    Aeq(row, 4*N+t) = 1;
    if t == 1
        beq(row) = socInit;
    else
        Aeq(row, 4*N+t-1) = -1;
    end
end

socReserve = 4500;
Aineq = zeros(1, nVar);
Aineq(5*N) = -1;
bineq = -socReserve;

lb = zeros(nVar, 1);
ub = inf(nVar, 1);
lb(4*N+1 : 5*N) = socMin;
ub(4*N+1 : 5*N) = socMax;
ub(N+1 : 2*N) = pMax;
ub(2*N+1 : 3*N) = pMax;

options = optimoptions('linprog', 'Display', 'off', 'Algorithm', 'dual-simplex');
[x, ~, exitflag] = linprog(f, Aineq, bineq, Aeq, beq, lb, ub, options);

if exitflag <= 0
    warning('阶段0优化未收敛，exitflag = %d', exitflag);
    pPlan = []; pCh = []; pDis = []; soc = [];
    return;
end

pPlan = x(1:N);
pCh = x(N+1 : 2*N);
pDis = x(2*N+1 : 3*N);
soc = x(4*N+1 : 5*N);
end
