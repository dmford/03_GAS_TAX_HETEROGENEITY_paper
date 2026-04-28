* manual IV regression example: 
webuse hsng2, clear

* first stage: predicting x2hat 
reg hsngval pcturban faminc i.region, robust
predict x2hat, xb

* target: 
ivregress 2sls rent pcturban (hsngval = faminc i.region), small

* second stage: using x2hat in place of x2
	* (b is the same, se is not)
reg rent x2hat pcturban, robust

* reduced form: 
reg rent hsngval, robust

**********

* PCIV: 
* y_i,j 	= (x1,i,j * b_i) 	+ (x2,i,j * delta) 	+ e_i,j
* x1,i,j 	= (z_i,j * gamma_i) + (x2,i,j * eta) 	+ u_i,j

* FIRST STAGE: 
* per-clister, regress logprice and covariates on gas taxes 
* save residuals x_tilta1,i and x_tilda2,i
	* allows elimination of g_i when estimating eta in step 2
* to estimate eta, regress x_tilta1,i,j on x_tilda2,i,j pooling over clusters to get etahat
* estimate g_i per-clister by regressing (x1,i,j - x2,i.j * etahat) on z_i,j 

* SECOND STAVE: 
* regress y_i,j and x2,i,j on xhat1,i,j per-clister, obtaining residuals ydot_i and xdot2,i 
* regress resids ydot_i,j on xdot2,i,j pooling over clusters to eliminate b_i when estimating deltahat 
* het slopes bhat_i can be estimated by regressing (y_i,j - x2,i,j * deltahat) on xhat1,i,j per-clister
* averaging over bhat_i obtains bhat_PCIV 

* IN THIS CONTEXT: 
* logsales_i,j = a1,i + (logprice_i,j * b_i) + (x_i,j * delta) + e_i,j
* logprice_i,j = a_0,i + (logtaxes_i,j * g_i) + (x_i,j *   eta) + u_i,j
	* b_i is the elasticity for each state 															<--- what I want 

* output is average elasticity: E[b_i], where I want b_i 
* use logtaxes to instrument for endog logprice 
	* het in passthrough modeled by gamma_i (coef on logtaxes)

* INTUITION: 
* OLS regress each x1,i,j on z_i,j separately for each state, obtain fitted x1hat_i,j
* OLS regress y_i,j on fitted x1hat_i,j within each state, obtain cluster-specific bhat_i 			<--- what I want 
* average over bhat_i to get PAE estimate, Bhat_PCIV
	
* COMPARING: 
* y_i,j 		= (x1,i,j * b_i) 		+ (x2,i,j * delta) 	+ e_i,j
* x1,i,j 		= (z_i,j * gamma_i) 	+ (x2,i,j * eta) 	+ u_i,j
* logsales_i,j 	= (logprice_i,j * b_i) 	+ (x_i,j * delta) 	+ a1,i + e_i,j
* logprice_i,j 	= (logtaxes_i,j * g_i) 	+ (x_i,j *   eta) 	+ a_0,i + u_i,j

* y  = logsales 
* x1 = logprice 
* z  = logtaxes
* x2 = 1 + covariates


