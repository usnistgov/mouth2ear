function [ix, C] = kmeans_mcv(x, k, varargin)
%KMEANS_MCV use the kmeans algorithm to partition data
%
%   [ix,C] = KMEANS_MCV(x,k) partitions the data in x into k clusters. The
%   cluster indicies are returned in ix and the centroid values are
%   returned in C. Initial center locations are initialized as the mean of
%   the data plus/minus the standard deviation of the data.
%
%   [ix,C] = KMEANS_MCV(x,k,iC) same as above but give initial guesses for
%   the center locations.
%
% Notes: Function only written for one dimensional data values...

%This software was developed by employees of the National Institute of
%Standards and Technology (NIST), an agency of the Federal Government.
%Pursuant to title 17 United States Code Section 105, works of NIST
%employees are not subject to copyright protection in the United States and
%are considered to be in the public domain. Permission to freely use, copy,
%modify, and distribute this software and its documentation without fee is
%hereby granted, provided that this notice and disclaimer of warranty
%appears in all copies.
%
%THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, EITHER
%EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY
%WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED
%WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
%FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL
%CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR
%FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT
%LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING
%OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE,
%WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER
%OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND
%WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR
%USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.

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