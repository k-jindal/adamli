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