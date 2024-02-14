functions {
  real k_func(real a0, real a1, real mu) {
    real k;
    k = a0*mu^a1;
    return k;
  }
  
  real parasite_index(real a0, real a1, real mu){
    real index_p;
    real k;
    k = k_func(a0, a1, mu);
    index_p = 1 - (1 + mu/k)^(-k);
    return index_p;
  }
}

data {
  int<lower=0> N;                                   // number of observations
  int<lower=0> N_patient;                           // number of patient samples
  int<lower=0> K_batch;                             // number of batches
  int<lower=0> L_treatment;                         // number of treatment regimens
  int<lower=0> K_covs;                              // number of model covariates
  int<lower=1,upper=N_patient> patient_id[N];       // patient sample
  int<lower=1,upper=K_batch> batch_id[N];           // mosquito sample
  int<lower=1,upper=L_treatment> regimen_id[N];     // drug regimen
  int<lower=0,upper=1> drug[N];                     // assignment to drug or control
  int y[N];                                         // count data
  matrix[N,K_covs] X;                               // covariate data (parasite count, day 0 outcomes etc)
  int<lower=0,upper=1> art[N];
  // priors
  real mu_pop_prior;
  
  // predictions
  int K_pred;
  real mu_pred[K_pred];
}


parameters {
  real mu_log_population;                           // population mean
  real mu_log_patient[N_patient];                   // patient random effect
  real batch_rand_effect[K_batch];                  // batch random effect
  real<lower=0> sigma_patient;
  real<lower=0> sigma_batch;
  real a0_log;                                      // convergence is better when this is on the log scale
  real a1_log;                                      // convergence is better when this is on the log scale
  real beta_drug[L_treatment];
  real art_wash;                                    // account for difference in artesunate samples
  vector[K_covs] beta_covs;
  
}

transformed parameters {
  real mu_log[N];
  real<lower=0> k[N]; 
  
  {
    vector[N] X_beta;
    X_beta = rep_vector(0, N);
    if(K_covs >0) {
      X_beta = X * beta_covs;
    } 
    for(i in 1:N){
      // individual estimate of the mean log count
      mu_log[i] = 
      mu_log_population +                       // population mean count
      mu_log_patient[patient_id[i]] +           // patient random effect
      batch_rand_effect[batch_id[i]] +          // batch random effect
      (beta_drug[regimen_id[i]]*drug[i]) +      // drug effect
      (art_wash*art[i]) +  // artemisinin washing effect 
      X_beta[i];
      // individual estimate of the dispersion parameter
      k[i] = k_func(exp(a0_log), exp(a1_log), exp(mu_log[i]));
    }
  }
}

model {
  // prior
  mu_log_population ~ normal(mu_pop_prior,5);
  mu_log_patient ~ normal(0, sigma_patient);
  batch_rand_effect ~ student_t(7,0, sigma_batch);
  sigma_patient ~ normal(1,0.25) T[0,];
  sigma_batch ~ normal(0.5,0.25) T[0,];
  
  a0_log ~ normal(-1,1);
  a1_log ~ normal(-1,1);
  
  beta_drug ~ normal(0,1);
  art_wash ~ normal(0,1);
  beta_covs ~ normal(0,1);
  
  //likelihood - vectorised is much faster!
  y ~ neg_binomial_2(exp(mu_log), k);
  
}

generated quantities{
  vector[K_pred] prevalence_infection;
  for(i in 1:K_pred){
    prevalence_infection[i] = parasite_index(exp(a0_log), exp(a1_log), mu_pred[i]);
  }
}

