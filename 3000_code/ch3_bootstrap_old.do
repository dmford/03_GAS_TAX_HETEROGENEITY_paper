clear all

cd "~\coding\03_GAS_TAX_HETEROGENEITY_paper\"

local predictors land_area weather_index urban_roadshare pop_density freq_border_pop_share 
*local y=1
*local outcome elast
*local aweight licensed_drivers
local bootnum 2
local seed = floor(runiform(1,1000))

timer clear
timer on 1

use "pciv\PCIV\Application\EstimationData\temp_all.dta", clear
gen state_fips = statefip

keep if year >= 1990 & year <2000

* merging with existing dataset 
merge m:1 state_fips using "2000_data\gas_elasticity_dataset", nogen

rename b1_logprice old_elast

save "2000_data\ch3_bootfile", replace

capture program drop ch3_boot
program ch3_boot, rclass

display "running a bootstrap replication..."

local i =  1

* I KNOW THAT THIS SECTION IS CORRECT (from a pre-existing published paper) 

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

capture noisely {
	foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {

	qui gen `exog'_x_hat_dem`i'=. 

	qui sum statefip
	qui levelsof statefip, local(levels) 
	foreach k of local levels {
	qui reg  `exog' `pc_ivlist' if statefip==`k'
	qui predict `exog'_x_hat_dem`i'_`k', resid
	qui replace `exog'_x_hat_dem`i' = `exog'_x_hat_dem`i'_`k' if statefip==`k'
	}
drop `exog'_x_hat_dem`i'_*
}
}

local m=1
foreach endo of varlist `pc_endoglist' {
qui gen x_hat_dem`i'_`m'=. 
qui sum statefip
qui levelsof statefip, local(levels) 
foreach k of local levels {
qui reg  `endo' `pc_ivlist' if statefip==`k'
qui predict x_hat_dem`i'_`m'_`var'_`k', resid
qui replace x_hat_dem`i'_`m' = x_hat_dem`i'_`m'_`var'_`k' if statefip==`k'
}
drop x_hat_dem`i'_`m'_*
}


* regress residualized x1 on residualized x2, then obtain x1_tilde = x1 - delta_hat*x2
display "regress residualized x1 on residualized x2, then obtain x1_tilde = x1 - delta_hat*x2"
qui reg x_hat_dem`i'_`m' *_x_hat_dem`i'
foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
qui gen x_tilde`i'_`m'_b_`exog'=_b[`exog'_x_hat_dem`i']
}

qui gen x_tilde`i'_`m' = `endo'
foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
qui replace x_tilde`i'_`m'= x_tilde`i'_`m' - (x_tilde`i'_`m'_b_`exog'*`exog')
}

foreach var of varlist `pc_ivlist' {
qui gen first_`m'_b`i'_`var'=.
}
qui gen first_`m'_resid`i'=x_tilde`i'_`m'

* reg x1_tilde on z
display "reg x1_tilde on z"
qui sum statefip
qui levelsof statefip, local(levels) 
foreach k of local levels {
qui reg  x_tilde`i'_`m' `pc_ivlist' if statefip==`k'

* get the estimates from the first stage
display "get the estimates from the first stage"
foreach var of varlist `pc_ivlist' {
qui replace first_`m'_b`i'_`var'=_b[`var'] if statefip==`k'
qui replace first_`m'_resid`i'=first_`m'_resid`i'-first_`m'_b`i'_`var'*`var' if statefip==`k'
}
}

* recover the x_hat by adding gamma_hat*x2
display "recover the x_hat by adding gamma_hat*x2"
qui gen x_hat`i'_`m'=0
foreach var of varlist `pc_ivlist' {
qui replace x_hat`i'_`m'= x_hat`i'_`m' + first_`m'_b`i'_`var'*`var'
}

foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
qui replace x_hat`i'_`m' = x_hat`i'_`m' + x_tilde`i'_`m'_b_`exog'*`exog'
}

*f-stats
display "f-stats"

statsby temp_first_fstat_`m'_`i'=e(F), by(statefip) saving(statsby`i'_`m', replace): reg x_tilde`i'_`m' `pc_ivlist'

sort statefip
merge m:1 statefip using statsby`i'_`m'
capture egen pickone`i'_`m' = tag(statefip)
drop _merge 

hotelling temp_first_fstat_`m'_`i' if pickone`i'_1==1

qui gen first_fstat_`m'_`i'=r(T2)


*standard errors
display "standard errors"
foreach var of varlist `pc_ivlist' {
egen first_`m'_reg`i'_`var' = mean(first_`m'_b`i'_`var')
qui gen first_`m'_dhat`i'_`var'=first_`m'_b`i'_`var'-first_`m'_reg`i'_`var'
qui gen first_`m'_sum_errors`i'_`var'=.
}

qui sum statefip
qui levelsof statefip, local(levels) 
foreach k of local levels {
mkmat `pc_ivlist' if statefip==`k' `options', matrix(Z) 
mkmat first_`m'_resid`i' if statefip==`k' `options', matrix(e)
matrix zz=Z'*Z
matrix ze=Z'*e
matrix sum_comp=invsym(zz)*ze
local j=1
foreach var of varlist `pc_ivlist' {
local d`j'=sum_comp[`j',1]
qui replace first_`m'_sum_errors`i'_`var'=`d`j'' if statefip==`k'
local j `++j'
}
}
foreach var of varlist `pc_ivlist' {
egen first_`m'_var`i'_dhat_`var'=sd(first_`m'_dhat`i'_`var') if pickone`i'_1==1
egen first_`m'_var`i'_`var'=sd(first_`m'_sum_errors`i'_`var') if pickone`i'_1==1
qui gen first_`m'_se`i'_`var'=sqrt((first_`m'_var`i'_dhat_`var'^2+first_`m'_var`i'_`var'^2)/51)
qui gen first_`m'_t`i'_`var'=first_`m'_reg`i'_`var'/first_`m'_se`i'_`var'
}
local m `++m'
}

*** second stage ***
display "second stage"

foreach var of varlist `pc_endoglist' {
qui gen b`i'_`var'=.
}
qui gen b`i'_cons=.

qui gen yhat`i'=.

* first obtain the residuals by regressing y and x2 on x1_hat per cluster
display "first obtain the residuals by regressing y and x2 on x1_hat per cluster"
qui sum statefip
qui levelsof statefip, local(levels) 
foreach k of local levels {
qui reg logvolume x_hat`i'_* if statefip==`k'
qui predict yhat`i'_`k', resid
qui replace yhat`i' = yhat`i'_`k' if statefip==`k'
}

drop yhat`i'_*

capture noisely {
	foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {

qui gen `exog'_2hat`i'=.

qui sum statefip
qui levelsof statefip, local(levels) 
foreach k of local levels {
qui reg `exog' x_hat`i'_* if statefip==`k'
qui predict `exog'_2hat`i'_`k', resid
qui replace `exog'_2hat`i' = `exog'_2hat`i'_`k' if statefip==`k'
}

drop `exog'_2hat`i'_*
}
}

* regress residualized y on residualized x2. Then, obtain y_breve = y - delta_hat*x2
display "regress residualized y on residualized x2. Then, obtain y_breve = y - delta_hat*x2"

qui reg yhat`i' *_2hat`i'
foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
qui gen y_breve`i'_b_`exog'=_b[`exog'_2hat`i']
}

qui gen y_breve`i' = logvolume
foreach exog of varlist `covars' `covars_miss' tm1-tm359 dat {
qui replace y_breve`i'= y_breve`i' - (y_breve`i'_b_`exog'*`exog')
}

* reg y_breve on x1_hat per cluster
display "reg y_breve on x1_hat per cluster"

qui gen resid`i'= y_breve`i'

qui sum statefip
qui levelsof statefip, local(levels) 
foreach k of local levels {
 
qui reg y_breve`i' x_hat`i'_* if statefip==`k'
local m=1
foreach var of varlist `pc_endoglist' {
qui replace b`i'_`var'=_b[x_hat`i'_`m'] if statefip==`k'
qui replace resid`i'=resid`i'-b`i'_`var'*`var' if statefip==`k'
local m `++m'
}
}

* END OF SECTION WHICH I KNOW IS CORRECT (from a pre-existing published paper)

* extracting part I care about (elasticities)
rename b1_logprice elast
keep elast statefip state_fips land_area weather_index urban_roadshare pop_density freq_border_pop_share licensed_drivers 
duplicates drop 

* Diagnostics for this replication (put right before reg ...)
count if !missing(elast, land_area, licensed_drivers)
local nobs = r(N)
di as txt "DEBUG: observations with nonmissing outcome, land_area, and aweight = `nobs'"

qui su land_area if !missing(land_area), meanonly
di as txt "DEBUG: land_area: min=`r(min)' mean=`r(mean)' max=`r(max)'"

qui su elast if !missing(elast), meanonly
di as txt "DEBUG: elast min=`r(min)' mean=`r(mean)' max=`r(max)'"

qui su licensed_drivers if !missing(licensed_drivers), meanonly
di as txt "DEBUG: aweight (licensed_drivers) min=`r(min)' mean=`r(mean)' max=`r(max)'"

*reg elast land_area [aweight=licensed_drivers], robust 
*return scalar b_land_area = _b[land_area]
capture noisely reg elast land_area [aweight=licensed_drivers], robust 
local rc = _rc 
if `rc' {
	display as error "REGRESSION ERROR in this replication: rc=`rc'. Returning missing."
	return scalar b_land_area = .
}

capture confirm matrix e(b) 
if _rc {
	display as error "No e(b) after regression; returning missing."
	return scalar b_land_area = .
}

capture scalar tmp = _b[land_area] 
if _rc {
	display as error "Coefficient land_area not found in e(b). Possible omission/collinearity or no variation. Returning missing."
	display as txt "e(N) = " e(N)
	return scalar b_land_area = .
}

else {
	return scalar b_land_area = _b[land_area]
}

*reg elast weather_index [aweight=licensed_drivers], robust 
*return scalar b_weather_index = _b[weather_index]
capture noisely reg elast weather_index [aweight=licensed_drivers], robust 
local rc = _rc 
if `rc' {
	display as error "REGRESSION ERROR in this replication: rc=`rc'. Returning missing."
	return scalar b_weather_index = .
}

capture confirm matrix e(b) 
if _rc {
	display as error "No e(b) after regression; returning missing."
	return scalar b_weather_index = .
}

capture scalar tmp = _b[weather_index] 
if _rc {
	display as error "Coefficient land_area not found in e(b). Possible omission/collinearity or no variation. Returning missing."
	display as txt "e(N) = " e(N)
	return scalar b_weather_index = .
}

else {
	return scalar b_weather_index = _b[weather_index]
}

*reg elast urban_roadshare [aweight=licensed_drivers], robust 
*return scalar b_urban_roadshare = _b[urban_roadshare]
capture noisely reg elast urban_roadshare [aweight=licensed_drivers], robust 
local rc = _rc 
if `rc' {
	display as error "REGRESSION ERROR in this replication: rc=`rc'. Returning missing."
	return scalar b_urban_roadshare = .
}

capture confirm matrix e(b) 
if _rc {
	display as error "No e(b) after regression; returning missing."
	return scalar b_urban_roadshare = .
}

capture scalar tmp = _b[urban_roadshare] 
if _rc {
	display as error "Coefficient land_area not found in e(b). Possible omission/collinearity or no variation. Returning missing."
	display as txt "e(N) = " e(N)
	return scalar b_urban_roadshare = .
}

else {
	return scalar b_urban_roadshare = _b[urban_roadshare]
}

*reg elast pop_density [aweight=licensed_drivers], robust 
*return scalar b_pop_density = _b[pop_density]
capture noisely reg elast pop_density [aweight=licensed_drivers], robust 
local rc = _rc 
if `rc' {
	display as error "REGRESSION ERROR in this replication: rc=`rc'. Returning missing."
	return scalar b_pop_density = .
}

capture confirm matrix e(b) 
if _rc {
	display as error "No e(b) after regression; returning missing."
	return scalar b_pop_density = .
}

capture scalar tmp = _b[pop_density] 
if _rc {
	display as error "Coefficient land_area not found in e(b). Possible omission/collinearity or no variation. Returning missing."
	display as txt "e(N) = " e(N)
	return scalar b_pop_density = .
}

else {
	return scalar b_pop_density = _b[pop_density]
}

*reg elast freq_border_pop_share [aweight=licensed_drivers], robust 
*return scalar b_freq_border_pop_share = _b[freq_border_pop_share]
capture noisely reg elast freq_border_pop_share [aweight=licensed_drivers], robust 
local rc = _rc 
if `rc' {
	display as error "REGRESSION ERROR in this replication: rc=`rc'. Returning missing."
	return scalar b_freq_border_pop_share = .
}

capture confirm matrix e(b) 
if _rc {
	display as error "No e(b) after regression; returning missing."
	return scalar b_freq_border_pop_share = .
}

capture scalar tmp = _b[freq_border_pop_share] 
if _rc {
	display as error "Coefficient land_area not found in e(b). Possible omission/collinearity or no variation. Returning missing."
	display as txt "e(N) = " e(N)
	return scalar b_freq_border_pop_share = .
}

else {
	return scalar b_freq_border_pop_share = _b[freq_border_pop_share]
}

end

bootstrap ///
	b_land_area=r(b_land_area) ///
	b_weather_index=r(b_weather_index) ///
	b_urban_roadshare=r(b_urban_roadshare) ///
	b_pop_density=r(b_pop_density) ///
	b_freq_border_pop_share=r(b_freq_border_pop_share), ///
	reps(`bootnum') seed(`seed') ///
	cluster(statefip) idcluster(state_fips) ///
	saving(ch3_boot_s`seed'.dta, replace): ch3_boot

timer off 1
timer list

*use ch3_boot_s`seed'.dta, clear
*tabstat b_hetvar, stat(sd)
