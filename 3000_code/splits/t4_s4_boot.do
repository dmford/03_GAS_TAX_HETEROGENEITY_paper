* t4_s4_boot.do

clear all 

* (1) HPCC cluster, and (2) personal machine: 
cd "/bigdata/mbateslab/dford013/coding/03_GAS_TAX_HETEROGENEITY_paper"
*cd "~\coding\03_GAS_TAX_HETEROGENEITY_paper\"

********************************************************************************

capture log close
log using "3000_code/SMCL_logs/t4_s4_boot", smcl replace

* list of predictors for table 
local predictors = "state_pop pop_density border_pop_share licensure"

about 

* defining local macros 
local bootnum 50
local seed = floor(runiform(1,10000))

* loading working dataset (to merge with temp_all.dta)
use "2000_data/gas_elasticity_dataset.dta", replace 
gen statefip = state_fips 

* dropping old outcomes, will gen new ones in boot
drop b1_logprice b2_logprice elasticity

merge 1:m statefip using "pciv/PCIV/Application/EstimationData/temp_all.dta", nogen 

sort statefip year month 
*gen obsid = _n
bysort statefip (year month): gen obsid = _n

* this step is to expedite the troubleshooting 
*keep if year>=1990 & year<2000

save "2000_data/toboot_t4_s4", replace

xtset, clear 
timer clear 
timer on 1

* dropping and defining program 
capture program drop ch3_boot, clear 
program ch3_boot, rclass

preserve 

display "running a bootstrap replication..."

*	generate variable for coef =.
return scalar b_state_pop = .
return scalar b_pop_density = .
return scalar b_border_pop_share = .
return scalar b_licensure = .


*	pciv regression
local i = 1
*forv i =  1/2{

if `i'==1 {
*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
dis "Regression without covariates"
*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;

local dcovars_rt ""
local dcovars_miss_rt ""
local  new_covars ""
local  new_covars_miss ""
local  covars ""
local  covars_miss ""
local ivlist dlogtax_rt
local endoglist "dlogprice_rt"
local new_ivlist "new_logtax"
local new_endoglist "new_logprice"
local pc_ivlist "logtax"
local pc_endoglist "logprice"
local options ""
local lincomlist "dlogprice_rt"
local new_lincomlist "new_logprice"
local pc_lincomlist "logprice"
local rf_lincomlist "dlogtax_rt"
local rf_new_lincomlist "new_logtax"
local rf_pc_lincomlist "logtax"


}


********************************** PCIV ****************************************

*** first stage ***

* getting the residuals by regressing x1 and x2 on Z


foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {

gen `exog'_x_hat_dem`i'=. 

sum statefip
levelsof statefip, local(levels) 
foreach k of local levels {
reg  `exog' `pc_ivlist' if statefip==`k'
predict `exog'_x_hat_dem`i'_`k', resid
replace `exog'_x_hat_dem`i' = `exog'_x_hat_dem`i'_`k' if statefip==`k'
}

drop `exog'_x_hat_dem`i'_*
}

local m=1
foreach endo of varlist `pc_endoglist' {
gen x_hat_dem`i'_`m'=. 
sum statefip
levelsof statefip, local(levels) 
foreach k of local levels {
reg  `endo' `pc_ivlist' if statefip==`k'
predict x_hat_dem`i'_`m'_`var'_`k', resid
replace x_hat_dem`i'_`m' = x_hat_dem`i'_`m'_`var'_`k' if statefip==`k'
}

drop x_hat_dem`i'_`m'_*


* regress residualized x1 on residualized x2, then obtain x1_tilde = x1 - delta_hat*x2
reg x_hat_dem`i'_`m' *_x_hat_dem`i'
foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
gen x_tilde`i'_`m'_b_`exog'=_b[`exog'_x_hat_dem`i']
}

gen x_tilde`i'_`m' = `endo'
foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
replace x_tilde`i'_`m'= x_tilde`i'_`m' - (x_tilde`i'_`m'_b_`exog'*`exog')
}

foreach var of varlist `pc_ivlist' {
gen first_`m'_b`i'_`var'=.
}
gen first_`m'_resid`i'=x_tilde`i'_`m'

* reg x1_tilde on z
sum statefip
levelsof statefip, local(levels) 
foreach k of local levels {
reg  x_tilde`i'_`m' `pc_ivlist' if statefip==`k'

* get the estimates from the first stage
foreach var of varlist `pc_ivlist' {
replace first_`m'_b`i'_`var'=_b[`var'] if statefip==`k'
replace first_`m'_resid`i'=first_`m'_resid`i'-first_`m'_b`i'_`var'*`var' if statefip==`k'
}
}

* recover the x_hat by adding gamma_hat*x2
gen x_hat`i'_`m'=0
foreach var of varlist `pc_ivlist' {
replace x_hat`i'_`m'= x_hat`i'_`m' + first_`m'_b`i'_`var'*`var'
}

foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
replace x_hat`i'_`m' = x_hat`i'_`m' + x_tilde`i'_`m'_b_`exog'*`exog'
}

*f-stats

statsby temp_first_fstat_`m'_`i'=e(F), by(statefip) saving(statsby`i'_`m'_t4_s4, replace): reg x_tilde`i'_`m' `pc_ivlist'

sort statefip
merge m:1 statefip using statsby`i'_`m'_t4_s4
capture egen pickone`i'_`m' = tag(statefip)
drop _merge 

hotelling temp_first_fstat_`m'_`i' if pickone`i'_1==1

gen first_fstat_`m'_`i'=r(T2)


*standard errors
foreach var of varlist `pc_ivlist' {
egen first_`m'_reg`i'_`var' = mean(first_`m'_b`i'_`var')
gen first_`m'_dhat`i'_`var'=first_`m'_b`i'_`var'-first_`m'_reg`i'_`var'
gen first_`m'_sum_errors`i'_`var'=.
}

sum statefip
levelsof statefip, local(levels) 
foreach k of local levels {
mkmat `pc_ivlist' if statefip==`k' `options', matrix(Z) 
mkmat first_`m'_resid`i' if statefip==`k' `options', matrix(e)
matrix zz=Z'*Z
matrix ze=Z'*e
matrix sum_comp=invsym(zz)*ze
local j=1
foreach var of varlist `pc_ivlist' {
local d`j'=sum_comp[`j',1]
replace first_`m'_sum_errors`i'_`var'=`d`j'' if statefip==`k'
local j `++j'
}
}
foreach var of varlist `pc_ivlist' {
egen first_`m'_var`i'_dhat_`var'=sd(first_`m'_dhat`i'_`var') if pickone`i'_1==1
egen first_`m'_var`i'_`var'=sd(first_`m'_sum_errors`i'_`var') if pickone`i'_1==1
gen first_`m'_se`i'_`var'=sqrt((first_`m'_var`i'_dhat_`var'^2+first_`m'_var`i'_`var'^2)/51)
gen first_`m'_t`i'_`var'=first_`m'_reg`i'_`var'/first_`m'_se`i'_`var'
}
local m `++m'
}

*** second stage ***

foreach var of varlist `pc_endoglist' {
gen b`i'_`var'=.
}
gen b`i'_cons=.

gen yhat`i'=.

* first obtain the residuals by regressing y and x2 on x1_hat per cluster
sum statefip
levelsof statefip, local(levels) 
foreach k of local levels {
reg logvolume x_hat`i'_* if statefip==`k'
predict yhat`i'_`k', resid
replace yhat`i' = yhat`i'_`k' if statefip==`k'
}

drop yhat`i'_*

foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {

gen `exog'_2hat`i'=.

sum statefip
levelsof statefip, local(levels) 
foreach k of local levels {
reg `exog' x_hat`i'_* if statefip==`k'
predict `exog'_2hat`i'_`k', resid
replace `exog'_2hat`i' = `exog'_2hat`i'_`k' if statefip==`k'
}

drop `exog'_2hat`i'_*

}

* regress residualized y on residualized x2. Then, obtain y_breve = y - delta_hat*x2

reg yhat`i' *_2hat`i'
foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
gen y_breve`i'_b_`exog'=_b[`exog'_2hat`i']
}

gen y_breve`i' = logvolume
foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
replace y_breve`i'= y_breve`i' - (y_breve`i'_b_`exog'*`exog')
}

* reg y_breve on x1_hat per cluster

gen resid`i'= y_breve`i'

sum statefip
levelsof statefip, local(levels) 
foreach k of local levels {
 
reg y_breve`i' x_hat`i'_* if statefip==`k'
local m=1
foreach var of varlist `pc_endoglist' {
replace b`i'_`var'=_b[x_hat`i'_`m'] if statefip==`k'
replace resid`i'=resid`i'-b`i'_`var'*`var' if statefip==`k'
local m `++m'
}
}

* my pieces 
rename b1_logprice elast 
keep statefip state_fips obsid elast state_pop pop_density border_pop_share licensure licensed_drivers 
duplicates drop statefip, force

*local predictors = "state_pop pop_density border_pop_share licensure"

* regressions 
reg elast state_pop [aweight=licensed_drivers], robust 
return scalar b_state_pop = _b[state_pop]

reg elast pop_density [aweight=licensed_drivers], robust 
return scalar b_pop_density = _b[pop_density]

reg elast border_pop_share [aweight=licensed_drivers], robust 
return scalar b_border_pop_share = _b[border_pop_share]

reg elast licensure [aweight=licensed_drivers], robust 
return scalar b_licensure = _b[licensure]

restore 

end

****Check program
bootstrap b_state_pop=r(b_state_pop) b_pop_density=r(b_pop_density) b_border_pop_share=r(b_border_pop_share) b_licensure=r(b_licensure), reps(`bootnum') seed(`seed') cluster(statefip) idcluster(state_fips) saving("2000_data/ch3_boot_t4_s4.dta", every(10) replace): ch3_boot

timer off 1
timer list

use "2000_data/ch3_boot_t4_s4.dta", clear
tabstat b_state_pop, stat(sd)
tabstat b_pop_density, stat(sd)
tabstat b_border_pop_share, stat(sd)
tabstat b_licensure, stat(sd)

log close
