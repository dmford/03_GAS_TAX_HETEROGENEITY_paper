* boot_append.do

clear all

* (1) HPCC cluster, and (2) personal machine: 
*cd "\bigdata\mbateslab\dford013\coding\03_GAS_TAX_HETEROGENEITY_paper"
cd "~\coding\03_GAS_TAX_HETEROGENEITY_paper\"

********************************************************************************

*ssc install statastates
*ssc install asdocx

capture log close
log using "3000_code\SMCL_logs\boot_append", smcl replace

cd "~\coding\03_GAS_TAX_HETEROGENEITY_paper\2000_data\boot_saves\"

local tgroups t1 t2 t3 t4 t5 

local whichtable 1
foreach t of local tgroups {
	display "Appending Table `t'..."
	
	local filelist : dir "." files "*_`t'*.dta" 
	
	local n : word count `filelist' 
	display "Found `n' files for tgroup `t'" 
	
	if `n' != 11 {
		display as error "Warning: expected 11 files but found `n' for tgroup `t'"
	}
	
	local first : word 1 of `filelist' 
	use "`first'", clear
	
	forvalues i = 2/`n' {
		local f : word `i' of `filelist' 
		display "Appending `f'" 
		append using "`f'" 
	}
	
	qui count 
	display as result "combined_`t'.dta has " r(N) " bootstrapped estimates"

	ds 
	foreach var of varlist `r(varlist)' {
		rename `var' `var'_`t'
	}

	gen table = `whichtable'
	gen merge_id = _n
	order merge_id table
	drop if merge_id > 500
	
	qui count 
	display as result "combined_`t'.dta has " r(N) " bootstrapped estimates after dropping"

	save "combined\combined_`t'.dta", replace 
	display "Saved combined_`t'.dta"
	
	local ++whichtable
}

use "combined\combined_t1.dta", replace
merge 1:1 merge_id using "combined\combined_t2.dta", nogen
merge 1:1 merge_id using "combined\combined_t3.dta", nogen
merge 1:1 merge_id using "combined\combined_t4.dta", nogen
merge 1:1 merge_id using "combined\combined_t5.dta", nogen

foreach t of local tgroups {
	display ""
    di "Standard deviations for table `t':"
    ds *_`t'
    tabstat `r(varlist)', stat(sd)
}
