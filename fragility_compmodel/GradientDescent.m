%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FUNCTION: Gradient Descent
% DESCRIPTION: Used to compute the fixed point of our linear model.
%
% INPUT:
% - alpha = 
% - beta =
% - W = We - Wi is the resulting synaptic weight matrix, with negative
% values corresponding to inhibition and positive weights to excitation
% - h = 
% - link = the corresponding response function (e.g. 'tanh')
%
% OUTPUT:
% - p = 
% - CF = 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [p CF] = GradientDescent(alpha, beta, W, h, link)
alpha = 0.1;
link = 'tanh';
N = 3;
h = 0.25+0.5*(rand(N,1));
beta = 1.0+0.0*rand(N,1);
frac = 1;
[We, Wi] = GenerateNetwork(N, frac);
W = We - Wi;

% define parameters for gradient descent
N = length(W);
tol = sqrt(N)*2e-3;         % the tolerance at which, to stop grad descent
numSteps = 10000;            % number of steps to take
iter = 1;                   % initialize iteration count of times to do descent
gamma = 0.5;                % step size for grad descent
eta = 0.5;                  % line search step size
line_search = 0;

% initialize return parameters
CF = inf(0, 1);
p = zeros(N, 0);
pt = rand(N, 1);
search = true;
t = 1;

while (search && t<= 10)
    for i=1:numSteps   % perform number of grad descent steps
        % nodal rate equation for network probability
        pdot = -alpha*pt + diag(tanh(W*pt + h)) * (1-pt);

        % compute Jacobian using eqn 2.29 from paper and gradient of cost
        % function from A3
        f = tanh(W*pt + h);
        df = sech(W*pt+h);
        grad = repmat(df, [1 N]).*W.*repmat(1-pt, [1 N]);
        grad = grad'*pdot;
        cost = norm(grad);          % get l2 norm of gradient of cost 

        %%- OPTIONAL do a line search to improve rate of convergence
        if (line_search)
            plook = -alpha*pt + diag(tanh(W*(pt-grad) + h)) * (1-pt);
            crit = 2*norm(pdot-plook)/norm(grad)^2;

            if (crit < 1)
                gamma = eta^floor(log(crit)/log(eta));
            else
                gamma = eta;
            end
        end

        % update nodal rate
        pt = pt - gamma*grad;
    end % end of loop through grad descent
    disp([t iter cost sum(pt>=0)]);
    if (i == numSteps)
        CF(t) = cost;
        p(:,t) = pt;
    end
    if ~(cost < (11-iter)*tol && (sum(pt>0) == N))
        pt = rand(N, 1);
        iter = 1;
    else
        iter = iter+1;
        if (iter == 11)
            search = false;
        end
        t = t-1;
    end
    t = t+1;
end

if (search)
    p = [];
    CF = [];
else
    pos = find(sum(p>=0, 1)==N);
    CF = CF(pos);
    p = p(:,pos);
    [CF ind] = min(CF);
    p = p(:,ind);
end
p 
CF
end

