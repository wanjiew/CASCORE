library(pracma)
source("projSp.R") # for ADMM
source("rsc.R") # for ADMM
source("cl2mat.R") # for ADMM
source("normalizeSym.R") # for ADMM
source("ADMM.R") # for ADMM
library(Matrix)

CASCORE = function(Adj, Covariate, K, alpha = NULL, alphan = 5, itermax = 100, startn = 10){
  # Inputs:
  # 1) Adj: an n by n symmetric adjacency matrix whose diagonals = 0 and positive entries = 1.
  # 2) Covariate: an n by p covariate matrix
  # 3) K: a positive integer which is no larger than n. This is the predefined number of communities.
  # 4) alpha: a vector of positive numbers to tune the weight of covariate matrix
  # 5) alphan: if alpha is not given, alphan is required to find a proper weight by grid search. The 
  #            default value is 5.

  # Optional Arguments for Kmeans:
  # 1) itermax: the maximum number of iterations allowed. Default value 100.
  # 2) nstart: R will try startn different random starting assignments and 
  #            then select the one with the lowest within cluster variation. Default value 10.

  # Outputs:
  # 1) a factor indicating nodes' labels. Items sharing the same label are in the same community.

  if(!isSymmetric(Adj)) stop("Error! Adj is not symmetric!")
  if(K > dim(Adj)[1]) stop("Error! More communities than nodes!")
  if(K %% 1 != 0) stop("Error! K is not an integer!")
  if(K < 2) stop("Error: There must be at least 2 communities!")
  if(dim(Adj)[1] != dim(Covariate)[1]) stop("Error! Incompatible!")
  #  if(alpha < 0) stop("Negative Alpha")

  #Regularity check
  estall = rep(NA, dim(Adj)[1]);
  netrow = rowSums(Adj);
  covrow = rowSums(abs(Covariate));
  ind_reg = which(netrow != 0 | covrow != 0)
  Adj = Adj[ind_reg, ind_reg];
  Covariate = Covariate[ind_reg, ];

  ##Algorithm
  n = dim(Adj)[1]
  d = rowSums(Adj);
  X = Adj %*% Covariate

  diagcomp = cbind(1, median(d)/(d+1));
  lambda = apply(diagcomp, 1, min)
  
  if(is.null(alpha)){
    d.net = sort(abs(eig(Adj)), decreasing = TRUE);
    alphaupper = d.net[1]*log(n)/mean(d);
    alphalower = max(0.05, d.net[K]/4);

    alpha = seq(alphalower, alphaupper, length.out = alphan);
#    print(alpha)
    est1 = matrix(0, alphan, n); est2 = est1;
    prop1 = rep(0, alphan); prop2 = rep(0, alphan)

    for(i in 1:alphan){
#      Newmat = X + diag(alpha[i]/(d+1))%*%Covariate;
      Newmat = X + alpha[i]*diag(lambda)%*%Covariate;
      zz = Newmat%*%t(Newmat)
      c = eigen(zz)
      vec = c$vectors
      vecn = vec[,1:K]/apply(vec[,1:K], 1, Norm);
      result = kmeans(vecn, K, iter.max = itermax, nstart = startn);
      if (result$ifault==4) { result = kmeans(X, K,  iter.max = itermax, nstart = startn, algorithm="Lloyd"); }
      prop2[i] = result$tot.withinss;
      est2[i,] = as.factor(result$cluster);
    }
    est = est2[which.min(prop2), ];
#    print(prop2)
  }
  else{
      alphan = length(alpha);
      est1 = matrix(0, alphan, n); est2 = est1;
      prop1 = rep(0, alphan); prop2 = rep(0, alphan)
      
      for(i in 1:alphan){
        Newmat = X + alpha[i]*diag(lambda)%*%Covariate;
        zz = Newmat%*%t(Newmat)
        c = eigen(zz)
        vec = c$vectors
        vecn = vec[,1:K]/apply(vec[,1:K], 1, Norm);
        result = kmeans(vecn, K, iter.max = itermax, nstart = startn);
        if (result$ifault==4) { result = kmeans(X, K,  iter.max = itermax, nstart = startn, algorithm="Lloyd"); }
        prop2[i] = result$tot.withinss;
        est2[i,] = as.factor(result$cluster);
      }
      est = est2[which.min(prop2), ];
  }
  estall[ind_reg] = est;
  return(estall)
}



SCORE = function(Adj, K, itermax = NULL, startn = NULL){
  # Inputs:
  # 1) Adj: an n by n symmetric adjacency matrix whose diagonals = 0 and positive entries = 1.
  # 2) K: a positive integer which is no larger than n. This is the predefined number of communities.
  
  # Optional Arguments for Kmeans:
  # 1) itermax: the maximum number of iterations allowed.
  # 2) nstart: R will try startn different random starting assignments and then select the one with the lowest within cluster variation.
  
  # Outputs:
  # 1) a factor indicating nodes' labels. Items sharing the same label are in the same community.
  
  # Remark:
  # SCORE only works on connected graphs, i.e., no isolated node is allowed.
  
  # exclude all wrong possibilities:
  if(!isSymmetric(Adj)) stop("Error! Adj is not symmetric!")
  if(K > dim(Adj)[1]) stop("Error! More communities than nodes!")
  if(K %% 1 != 0) stop("Error! K is not an integer!")
  if(K <= 0) stop("Error! Nonpositive K!")
  
  g.eigen = eigen(Adj)
  if(sum(g.eigen$vectors[, 1]==0) > 0) stop("Error! Zeroes in the first column")
  R = g.eigen$vectors[, -1]
  R = R[, 1: (K-1)]
  R = R / g.eigen$vectors[, 1]
  R[R > sqrt(log(n))] = sqrt(log(n));
  R[R < -1*sqrt(log(n))] = -1*sqrt(log(n));
  
  # apply Kmeans to assign nodes into communities
  if(!is.null(itermax) & !is.null(startn)){
    result = kmeans(R, K, iter.max = itermax, nstart = startn) #apply kmeans on ratio matrix
  }
  if(!is.null(itermax) & is.null(startn)){
    result = kmeans(R, K, iter.max = itermax, nstart = 10) #apply kmeans on ratio matrix
  }
  if(is.null(itermax) & !is.null(startn)){
    result = kmeans(R, K, iter.max = 100, nstart = startn) #apply kmeans on ratio matrix
  }
  else{
    result = kmeans(R, K, iter.max = 100, nstart = 10) #apply kmeans on ratio matrix
  }
  
  est = as.factor(result$cluster)
  return(est)
}



nPCA = function(Adj, K, tau = NULL, itermax = 100, startn = 10){
  # Inputs:
  # 1) Adj: an n by n symmetric adjacency matrix whose diagonals = 0 and positive entries = 1.
  # 2) K: a positive integer which is no larger than n. This is the predefined number of communities.
  
  # Optional Arguments for Kmeans:
  # 1) itermax: the maximum number of iterations allowed.
  # 2) nstart: R will try startn different random starting assignments and then select the one with the lowest within cluster variation.
  
  # Outputs:
  # 1) a factor indicating nodes' labels. Items sharing the same label are in the same community.
  
  # Remark:
  # nPCA only works on connected graphs, i.e., no isolated node is allowed.
  if(!isSymmetric(Adj)) stop("Error! Adj is not symmetric!")
  if(K > dim(Adj)[1]) stop("Error! More communities than nodes!")
  if(K %% 1 != 0) stop("Error! K is not an integer!")
  if(K <= 0) stop("Error! Nonpositive K!")
  
  s = rowSums(Adj)
  if(is.null(tau)) tau = mean(s);
  s =  (s+tau)^(-1/2)
  S = diag(s)
  Z = S %*% Adj %*% S
  s.eigen = eigen(Z) 
  H = s.eigen$vectors
  H = H[, 1:K]
  #apply kmeans on ratio matrix
  result = tryCatch({kmeans(H, K, iter.max = itermax, nstart = startn)}, error = function(x)
  {kmeans(H, K, iter.max = 100, nstart = 99)})
  
  est = as.factor(result$cluster)
  return(est)
}

oPCA = function(Adj, K, itermax = 100, startn = 10){
  # Inputs:
  # 1) Adj: an n by n symmetric adjacency matrix whose diagonals = 0 and positive entries = 1.
  # 2) K: a positive integer which is no larger than n. This is the predefined number of communities.
  
  # Optional Arguments for Kmeans:
  # 1) itermax: the maximum number of iterations allowed.
  # 2) nstart: R will try startn different random starting assignments and then select the one with the lowest within cluster variation.
  
  # Outputs:
  # 1) a factor indicating nodes' labels. Items sharing the same label are in the same community.
  
  if(!isSymmetric(Adj)) stop("Error! Adj is not symmetric!")
  if(K > dim(Adj)[1]) stop("Error! More communities than nodes!")
  if(K %% 1 != 0) stop("Error! K is not an integer!")
  if(K <= 0) stop("Error! Nonpositive K!")
  
  o.eigen = eigen(Adj)
  O = o.eigen$vectors
  O = O[, 1:K]

  result = tryCatch({kmeans(O, K, iter.max = itermax, nstart = startn)}, error = function(x)
  {kmeans(O, K, iter.max = itermax, nstart = startn, algorithm="Lloyd")})
  
  est = as.factor(result$cluster)
  return(est)
}

CAclustering = function(Adj, Covariate, K, alphan = 5, itermax = 100, startn = 10){
  s = rowSums(Adj)
  s = s + mean(s)
  s =  s^(-1/2)
  S = diag(s)
  Z = S %*% Adj %*% S
  net.eigen = eigen(Z%*%Z)
  ca = Covariate %*% t(Covariate); 
  ca.eigen = eigen(ca);
  alphalower = (net.eigen$values[K] - net.eigen$values[K+1])/ca.eigen$values[1];
  alphaupper = net.eigen$values[1]/(ca.eigen$values[K] - ca.eigen$values[K+1]);
  d = rep(0, alphan);  
  alpha = seq(alphalower, alphaupper, length.out = alphan);
  est = matrix(NA, alphan, dim(Adj)[1])
  
  for(ii in 1:alphan){
    casc.eigen = eigen(Z%*%Z + alpha[ii]*ca);
    U = casc.eigen$vectors[,1:K];
    Unorm = apply(U, 1, Norm); 
    indu = which(Unorm > 0); 
    U = U[indu, ]/Unorm[indu]
    result = kmeans(U, K, iter.max = itermax, nstart = startn); 
    d[ii] = result$tot.withinss;
    est[ii, indu] = as.factor(result$cluster)
  }
  result = est[which.min(d), ]
  return(result)
}


admm = function(A, C, lambda, K, alpha, rho, TT, tol, quiet = NULL, 
                report_interval = NULL, r = NULL){
  
  # Inputs:     A: adjacency matrix
  #             C: n x p covaraite matrix 
  #             lambda: tuning parameter between graph and covariates
  #             K: number of clusters
  #             alpha: elementwise upper bound in the SDP
  #             rho: learning rate of ADMM
  #             TT:   max iteration
  #             quiet: whether to print result at each step
  #             tol: tolerance for stopping criterion
  #             report_interval: frequency to print intermediate result
  #             r: expected rank of the solution, leave blank if no constraint is required.
  # Outputs:    X: optmal solution
  #             T_term: number of iteration taken to converge
  
  As = A + lambda* C %*% t(C) 
  
  n = dim(As)[1]  
  U <- V <- matrix(0, n, n)
  
  #Initialization - spectral with perturbation
  v = eigen(As)$vectors[, 1: K]
  e = diag(eigen(As)$values[1: K])
  X = v %*% t(v) + 0.1*matrix(rnorm(n*n), nrow = n) 
  Y = v %*% t(v) + 0.1*matrix(rnorm(n*n), nrow = n) 
  Z = v %*% t(v) + 0.1*matrix(rnorm(n*n), nrow = n) 
  
  As_rescaled = (1/rho) * As;
  
  if(is.null(report_interval)) report_interval = 1
  if(is.null(quiet)) quiet = FALSE
  if(is.null(r)) r = Inf
  
  if (is.infinite(TT)) {
    delta = matrix(0, 1000, 1)
    infeas = matrix(0, 1000, 1)
  }
  else {
    delta = matrix(0, TT, 1)
    infeas = matrix(0, TT, 1)
  }
  
  dt = matrix(0, 1, 3);
  t = 1; 
  CONVERGED = FALSE;
  
  while(CONVERGED == FALSE & t<= TT){
    Xold = X
    X = projAXb(0.5*(Z - U + Y - V + As_rescaled), K, n); 
    Z = X + U
    Z[Z < 0] = 0
    Z[Z > alpha] = alpha
    
    #if (r < Inf) Y = projSp(X + V, r, 1e-3)
    #else 
    Y = projSp(X + V);
    U = U + X - Z;
    V = V + X - Y;
    delta[t] = norm(X - Xold) / norm(Xold);
    infeas[t] = (sqrt(sum(diag(t(X - Y) * (X - Y)))) + sqrt(sum(diag(t(X - Z) * (X - Z))))) / sqrt(sum(diag(t(X)*X)));
    CONVERGED = max(delta[t], infeas[t]) < tol;
    t = t + 1;
  }
  
  T_term = t - 1
  est = rsc(X, K, 'adj')
  return(est)
}


