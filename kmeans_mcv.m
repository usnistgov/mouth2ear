function [ix, C] = kmeans_mcv(x, k, varargin)
% Inputs: x - data
%         k - number of centers
%         iC - initialization guess for center locations. If not provided
%         iC initialized as the mean of the data plus/minus the standard
%         deviation of the data.
% Outputs: ix - array designating assigned center for each data point
%          C - centroid values
% Notes: Function only written for one dimensional data values...
iterTol = 10000;
convTol = 1e-16;
p = inputParser;

default_iC = 0;
addRequired(p, 'x', @isnumeric);
addRequired(p, 'k', @isnumeric);
addOptional(p, 'iC', default_iC, @isnumeric);
parse(p, x, k, varargin{:});
iC = p.Results.iC;
[mC, nC] = size(iC);
if(iC == default_iC)
    % Initialize guesses as mean +- standard deviation of data
    m_0 = mean(x);
    s_0 = std(x);
    iC = [m_0-s_0; m_0 + s_0];
    C = iC;
elseif(mC == 1 & nC == k)
    % row vector of initial guesses
    C = iC';
elseif(mC == k & nC == 1)
    % column vector of initial guesses
    C = iC;
else
   error('Initial guesses do not match k') 
end
%number data points
nd = length(x);
% Initialize distance array
dV = zeros(nd,k);
% count iterations
numIter = 1;
% converagance condition
convFlag = 1;
while(numIter<iterTol && convFlag)
    % Assign distance value from each data point to each center guess
    for i = 1:k
        dV(:,i) = abs(x-C(i));
    end
    % define closest centroid
    [~,ix] = min(dV,[],2);
    
    % save last centroid locations
    iC = C;
    % update centroid locations
    for i = 1:k
        idx = [ix ==i];
        C(i) = mean(x(idx));
    end
    % Update convergance tracker
    conv = abs(C - iC);
    % Flag if max change smaller than tol
    if(max(max(conv))<convTol)
        convFlag = 0;
    end
    % update iteration count
    numIter = numIter + 1;
end
% disp(['Kmeans converged in ' num2str(numIter) ' iterations'])