* update_bootstrap_SEs.do

clear all

********************************************************************************
* AUTOMATIC BOOTSTRAPPED STANDARD ERROR REPLACEMENT IN LATEX TABLES
* Corrected for numeric SDs and exact variable mappings for t1–t5
********************************************************************************

cd "~/coding/03_GAS_TAX_HETEROGENEITY_paper/"

********************************************************************************
* Helper program: replace numeric SEs in parentheses
********************************************************************************
capture program drop replace_se
program define replace_se
    syntax , infile(string) outfile(string) varlist(string)

    file open fi using "`infile'", read text
    file open fo using "`outfile'", write replace text

    while (1) {
        file read fi line
        if r(eof) continue, break

        local new = "`line'"

        tokenize "`varlist'"
        while "`1'" != "" {
            local sd_val "`1'"
            local pattern = "\([0-9eE\.\-\+]+\)"
            local new = regexr("`new'", "`pattern'", "(`sd_val')")
            macro shift
        }

        file write fo "`new'" _n
    }

    file close fi
    file close fo
end

********************************************************************************
* ------------------ t1: etable_y1_main_w.tex ------------------
********************************************************************************
use "2000_data/boot_saves/combined/combined_t1.dta", clear

summ b_land_area, meanonly
local sd_land = r(sd)
summ b_weather_index, meanonly
local sd_weather = r(sd)
summ b_urban_roadshare, meanonly
local sd_urban = r(sd)
summ b_pop_density, meanonly
local sd_pop = r(sd)
summ b_freq_border_pop_share, meanonly
local sd_freq = r(sd)

summ b1_full, meanonly
local sd_b1 = r(sd)
summ b2_full, meanonly
local sd_b2 = r(sd)
summ b3_full, meanonly
local sd_b3 = r(sd)
summ b4_full, meanonly
local sd_b4 = r(sd)
summ b5_full, meanonly
local sd_b5 = r(sd)

* Correct order: first 5 single-variable regressions, then full regression
replace_se,                                   ///
    infile("6000_LaTeX/etable_y1_main_w.tex") ///
    outfile("6000_LaTeX/etable_y1_main_w_boot.tex") ///
    varlist("`sd_land' `sd_weather' `sd_urban' `sd_pop' `sd_freq' `sd_b1' `sd_b2' `sd_b3' `sd_b4' `sd_b5'")

********************************************************************************
* ------------------ t2: etable_y1_environmental_w.tex ------------------
********************************************************************************
use "2000_data/boot_saves/combined/combined_t2.dta", clear

summ b_land_area, meanonly
local sd_land = r(sd)
summ b_weather_index, meanonly
local sd_weather = r(sd)
summ b_flatness_index, meanonly
local sd_flat = r(sd)

replace_se,                                               ///
    infile("6000_LaTeX/etable_y1_environmental_w.tex") ///
    outfile("6000_LaTeX/etable_y1_environmental_w_boot.tex") ///
    varlist("`sd_land' `sd_weather' `sd_flat'")

********************************************************************************
* ------------------ t3: etable_y1_transportation_w.tex ------------------
********************************************************************************
use "2000_data/boot_saves/combined/combined_t3.dta", clear

summ b_urban_mileage, meanonly
local sd_um = r(sd)
summ b_total_mileage, meanonly
local sd_tm = r(sd)
summ b_urban_roadshare, meanonly
local sd_urs = r(sd)
summ b_pub_tran_average, meanonly
local sd_pt = r(sd)

replace_se,                                              ///
    infile("6000_LaTeX/etable_y1_transportation_w.tex") ///
    outfile("6000_LaTeX/etable_y1_transportation_w_boot.tex") ///
    varlist("`sd_um' `sd_tm' `sd_urs' `sd_pt'")

********************************************************************************
* ------------------ t4: etable_y1_demographic_w.tex ------------------
********************************************************************************
use "2000_data/boot_saves/combined/combined_t4.dta", clear

summ b_state_pop, meanonly
local sd_sp = r(sd)
summ b_pop_density, meanonly
local sd_pd = r(sd)
summ b_border_pop_share, meanonly
local sd_bps = r(sd)
summ b_licensure, meanonly
local sd_lic = r(sd)

replace_se,                                       ///
    infile("6000_LaTeX/etable_y1_demographic_w.tex") ///
    outfile("6000_LaTeX/etable_y1_demographic_w_boot.tex") ///
    varlist("`sd_sp' `sd_pd' `sd_bps' `sd_lic'")

********************************************************************************
* ------------------ t5: etable_y1_demographic_w.tex (t5) ------------------
********************************************************************************
use "2000_data/boot_saves/combined/combined_t5.dta", clear

summ b_border_pop_share, meanonly
local sd_bps = r(sd)
summ b_freq_border_pop_share, meanonly
local sd_freq = r(sd)
summ b_avg_border_pop_share, meanonly
local sd_avg = r(sd)
summ b_med_border_pop_share, meanonly
local sd_med = r(sd)

replace_se,                                           ///
    infile("6000_LaTeX/etable_y1_demographic_w.tex")     ///
    outfile("6000_LaTeX/etable_y1_demographic_w_boot.tex") ///
    varlist("`sd_bps' `sd_freq' `sd_avg' `sd_med'")

********************************************************************************
di "ALL DONE — Bootstrapped LaTeX tables written!"
********************************************************************************

sum _all
