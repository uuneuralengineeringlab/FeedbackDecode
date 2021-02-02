function loss = stopCrit(X, mu, resid, k, type)

%This function calculates the AIC or BIC, given:
%X: The signal to be estimated
%mu: The current signal estimate
%resid: X-mu, can be sent to the function in place of X and mu. The resid 
%sent into the function is used regardless of whether or not X and mu are 
%also given.
%k: the number of parameters used so far in the model
%type: The stopping criterion type. Can be AIC, AICc, or BIC

%loss: the scalar stopping criterion value.

%Usage: 
% BIC: 
%   testLoss = stopCrit(X,mu,[],k,'BIC');
% AICc with resid:
%   testLoss = stopCrit([],[],resid,k,'AICc');

%Jacob Nieveen, University of Utah, 2016

if isempty(resid)
    resid = X-mu;
end

RSS = resid(:)'*resid(:);



switch type
    case 'AIC'
        loss = 2*k+numel(resid)*log(RSS);
    case 'AICc'
        loss = 2*k+numel(resid)*log(RSS)+...
            2*k*(k+1)/(numel(resid)-k-1);
    case 'BIC'
        loss = k*log(numel(resid))+numel(resid)*log(RSS);
    otherwise
        loss = -k;
end