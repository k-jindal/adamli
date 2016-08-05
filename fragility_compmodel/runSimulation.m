%%- Compute Fixed Point
p = [];
alpha = 0.1;
link = 'tanh';
while (isempty(p))
    frac = 0.5;
    N = 3;
    disp(['Generating Synaptic weights of excitatory and inhibitory']);
    
    [We, Wi] = GenerateNetwork(N, frac);
    
    % use gradient descent to compute fixed point
    h = 0.25+0.5*(rand(N,1));                  % external input
    beta = 1.0+0.0*rand(N,1);                  %
    p = GradientDescent(alpha, beta, We-Wi, h, link);     
end

% put excitatory and inhibitory into 1 network
N = N*2;
h = [h; h];
beta = [beta; beta];
p = [p; p];
W = [We -Wi; We -Wi]; % the general structural conenctivity

%%- Compute Functional Perturbation
J = -alpha*p + diag(tanh(W*p + h)) * (1-p);

w = 1:21; % sweep over these rows to

% initialize parameters to store
DelJ = cell(length(w), 1); % the change to functional connectivity
DelW = cell(length(w), 1); % the change to structural connectivity

Wp = cell(length(w), 1); % the perturbed structural network
Jp = cell(length(w), 1); % the perturbed functional connect

constrained = zeros(length(w), 1);
omega = linspace(0, 2*pi/10, 101);
r = zeros(length(w), 1);
lambda = zeros(length(w), 1);

for i=1:length(w)
    % verify that the fragility is continuous
    
    % perturb network at a certain row
%     alpha, beta, W, p, h, J, DelJ{i}, constrained(i)
    N = length(p); % number of nodes in network
    r = find(sum(abs(DelJ{i}) , 2));
    er = [zeros(r-1, 1); 1; zeros(N-r, 1)];
    
    
end