*** |  (C) 2006-2020 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/DTcoup/presolve.gms

* *** calculate CF for dispatchable from solar pv share
* pm_cf_linear(tDT32,regi,DISPATCHte32_2)$regDTCoup(regi) = pm_cf(tDT32,regi,DISPATCHte32_2)$regDTCoup(regi) * ( 1 - 0.5 * v32_shSeEl.l(tDT32,regi,"spv")$regDTCoup(regi) / 100);

*** calculation of SE electricity price (useful for internal use and reporting purposes)
pm_SEPrice(t,regi,entySE)$(abs (qm_budget.m(t,regi)) gt sm_eps AND sameas(entySE,"seel")) =
       q32_balSe.m(t,regi,entySE) / qm_budget.m(t,regi);
*Display "electricity price", pm_SEPrice(t,"DEU","seel");


p32_budget(t,regi) = qm_budget.m(t,regi);
pm_prodSe(t,regi,enty,enty2,te) = vm_prodSe.l(t,regi,enty,enty2,te);
pm_demSe(t,regi,enty,enty2,te) = vm_demSe.l(t,regi,enty,enty2,te);


$IFTHEN.DTcoup %cm_DTcoup% == "on"
*** CG:load fuel prices from two previous iterations, avoid using marginals in case they are 0
p32_fuelprice_lastx2iter(t,regi,entyPe)$(regDTCoup(regi)) = p32_fuelprice_lastiter(t,regi,entyPe);
p32_fuelprice_lastiter(t,regi,entyPe)$(regDTCoup(regi)) = p32_fuelprice_curriter(t,regi,entyPe);
;

p32_seelUsableDem_last_iter(t,regi,enty)$(sameas(enty,"seel")) = p32_seelUsableDem(t,regi,enty);
p32_seelUsableProd_last_iter(t,regi,enty)$(sameas(enty,"seel")) = p32_seelUsableProd(t,regi,enty);

$IFTHEN.elh2_coup %cm_elh2_coup% == "on"
p32_shSeElDem(t,regi,te)$regDTCoup(regi) = v32_shSeElDem.l(t,regi,te);
p32_seh2elh2Dem_last_iter(t,regi,enty)$(sameas(enty,"seh2")) = vm_demSe.l(t,regi,"seel","seh2","elh2");
$ENDIF.elh2_coup
$ENDIF.DTcoup

$IFTHEN.DTcoup %cm_DTcoup% == "on"
    Execute_Loadpoint 'results_DIETER' p32_report4RM;
    Execute_Loadpoint 'results_DIETER' p32_reportmk_4RM;
*   Couple capacity factor from DIETER to REMIND
*   sum over gdxfile set removes this extra index that comes from gdxmerge algorithm
*   optional: averaging capfac over 2 iterations

***CG:noCF averaging
* if( (ord(iteration) le (sm32_DTiter + 1)) ,
*     pm_cf(t,regi,te)$(tDT32(t) AND COALte32(te) AND regDTCoup(regi))
*     			= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"coal","capfac")$(tDT32(t) AND regDTCoup(regi)));
*     pm_cf(t,regi,te)$(tDT32(t) AND NonPeakGASte32(te) AND regDTCoup(regi))
*     			= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"CCGT","capfac")$(tDT32(t) AND regDTCoup(regi)));
*     pm_cf(t,regi,te)$(tDT32(t) AND BIOte32(te) AND regDTCoup(regi))
*     			= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"bio","capfac")$(tDT32(t) AND regDTCoup(regi)));
*     pm_cf(t,regi,"ngt")$(tDT32(t) AND regDTCoup(regi))
*     			= sum(gdxfile32, p32_report4RM(gdxfile32,t,regi,"OCGT_eff","capfac")$(tDT32(t) AND regDTCoup(regi)));
*     pm_cf(t,regi,te)$(tDT32(t) AND NUCte32(te) AND regDTCoup(regi))
*     			= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"nuc","capfac")$(tDT32(t) AND regDTCoup(regi)));
* $IFTHEN.elh2_coup %cm_elh2_coup% == "on"
*     pm_cf(t,regi,"elh2")$(tDT32(t) AND regDTCoup(regi))
*     			= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"elh2","capfac")$(tDT32(t) AND regDTCoup(regi)));
* $ENDIF.elh2_coup
* );

***CG:CF averaging, only after DT is coupled for one iteration (to avoid pm_cf being distorted by default high values)
* if( (ord(iteration) gt (sm32_DTiter + 1)),
p32_cf_last_iter(t,regi,te)$(tDT32(t) AND regDTCoup(regi)) = pm_cf(t,regi,te);

pm_cf(t,regi,te)$(tDT32(t) AND COALte32(te) AND regDTCoup(regi))
			= 0.5 * ( p32_cf_last_iter(t,regi,te)$(COALte32(te))
      + sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"coal","capfac")$(tDT32(t) AND regDTCoup(regi))) );
pm_cf(t,regi,te)$(tDT32(t) AND NonPeakGASte32(te) AND regDTCoup(regi))
			= 0.5 * ( p32_cf_last_iter(t,regi,te)$(NonPeakGASte32(te))
      + sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"CCGT","capfac")$(tDT32(t) AND regDTCoup(regi))) );
pm_cf(t,regi,te)$(tDT32(t) AND BIOte32(te) AND regDTCoup(regi))
			= 0.5 * ( p32_cf_last_iter(t,regi,te)$(BIOte32(te))
			+ sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"bio","capfac")$(tDT32(t) AND regDTCoup(regi))) );
pm_cf(t,regi,"ngt")$(tDT32(t) AND regDTCoup(regi))
			= 0.5 * ( p32_cf_last_iter(t,regi,"ngt")
			+ sum(gdxfile32, p32_report4RM(gdxfile32,t,regi,"OCGT_eff","capfac")$(tDT32(t) AND regDTCoup(regi))) );
pm_cf(t,regi,te)$(tDT32(t) AND NUCte32(te) AND regDTCoup(regi))
			= 0.5 * ( p32_cf_last_iter(t,regi,te)$(NUCte32(te))
			+ sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"nuc","capfac")$(tDT32(t) AND regDTCoup(regi))) );
$IFTHEN.elh2_coup %cm_elh2_coup% == "on"
pm_cf(t,regi,"elh2")$(tDT32(t) AND regDTCoup(regi))
      = 0.5 * ( p32_cf_last_iter(t,regi,"elh2")
			+ sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"elh2","capfac")$(tDT32(t) AND regDTCoup(regi))) );
$ENDIF.elh2_coup
* );

*   pass peak demand from DIETER to REMIND as a fraction of the total demand
    p32_peakDemand_relFac(t,regi)$(tDT32(t) AND regDTCoup(regi))
		      = sum(gdxfile32, p32_report4RM(gdxfile32,t,regi,"all_te","ResPeakDem_relFac")$(tDT32(t) AND regDTCoup(regi)));

*** dividing each DIETER tech into REMIND tech, using the last iteration REMIND share within DIETER tech category to scale down the generation share
    p32_tech_category_genshare(t,regi,te)$(BIOte32(te) AND regDTCoup(regi))
		      = p32_shSeEl(t,regi,te)$(BIOte32(te) AND regDTCoup(regi))/sum(te2$(BIOte32(te2)),p32_shSeEl(t,regi,te2)$regDTCoup(regi) + sm_eps);
		p32_tech_category_genshare(t,regi,te)$(NonPeakGASte32(te) AND regDTCoup(regi))
		      = p32_shSeEl(t,regi,te)$(NonPeakGASte32(te) AND regDTCoup(regi))/sum(te2$(NonPeakGASte32(te2)),p32_shSeEl(t,regi,te2)$regDTCoup(regi) + sm_eps);
		p32_tech_category_genshare(t,regi,te)$(NUCte32(te) AND regDTCoup(regi))
		      = p32_shSeEl(t,regi,te)$(NUCte32(te) AND regDTCoup(regi))/sum(te2$(NUCte32(te2)),p32_shSeEl(t,regi,te2)$regDTCoup(regi) + sm_eps);
		p32_tech_category_genshare(t,regi,te)$(COALte32(te) AND regDTCoup(regi))
		      = p32_shSeEl(t,regi,te)$(COALte32(te) AND regDTCoup(regi))/sum(te2$(COALte32(te2)),p32_shSeEl(t,regi,te2)$regDTCoup(regi) + sm_eps);

    p32_DIETER_shSeEl(t,regi,"spv")$(tDT32(t) AND regDTCoup(regi))
					= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"Solar","gen_share")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_shSeEl(t,regi,"wind")$(tDT32(t) AND regDTCoup(regi))
					= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"Wind_on","gen_share")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_shSeEl(t,regi,"ngt")$(tDT32(t) AND regDTCoup(regi))
					= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"OCGT_eff","gen_share")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_shSeEl(t,regi,"hydro")$(tDT32(t) AND regDTCoup(regi))
					= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"ror","gen_share")$(tDT32(t) AND regDTCoup(regi)));
*CG* downscaling technology shares in REMIND
    p32_DIETER_shSeEl(t,regi,te)$(tDT32(t) AND regDTCoup(regi)AND BIOte32(te) )
					= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"bio","gen_share")$(tDT32(t) AND regDTCoup(regi)))
							*	p32_tech_category_genshare(t,regi,te)$(BIOte32(te) AND regDTCoup(regi)) ;
    p32_DIETER_shSeEl(t,regi,te)$(tDT32(t) AND regDTCoup(regi) AND NonPeakGASte32(te))
					= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"CCGT","gen_share")$(tDT32(t) AND regDTCoup(regi)))
						 	* p32_tech_category_genshare(t,regi,te)$(NonPeakGASte32(te) AND regDTCoup(regi)) ;
    p32_DIETER_shSeEl(t,regi,te)$(tDT32(t) AND regDTCoup(regi) AND NUCte32(te))
					= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"nuc","gen_share")$(tDT32(t) AND regDTCoup(regi)))
					  	* p32_tech_category_genshare(t,regi,te)$(NUCte32(te) AND regDTCoup(regi)) ;
    p32_DIETER_shSeEl(t,regi,te)$(tDT32(t) AND regDTCoup(regi) AND COALte32(te))
					= sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"coal","gen_share")$(tDT32(t) AND regDTCoup(regi)))
				    	* p32_tech_category_genshare(t,regi,te)$(COALte32(te) AND regDTCoup(regi)) ;

*   supply side tech market value
    p32_DIETER_MV(t,regi,te)$(tDT32(t) AND BIOte32(te) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"bio","market_value")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_MV(t,regi,te)$(tDT32(t) AND NonPeakGASte32(te) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"CCGT","market_value")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_MV(t,regi,"ngt")$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"OCGT_eff","market_value")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_MV(t,regi,te)$(tDT32(t) AND NUCte32(te) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"nuc","market_value")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_MV(t,regi,te)$(tDT32(t) AND COALte32(te) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"coal","market_value")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_MV(t,regi,"spv")$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"Solar","market_value")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_MV(t,regi,"hydro")$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"ror","market_value")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_MV(t,regi,"wind")$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"Wind_on","market_value")$(tDT32(t) AND regDTCoup(regi)));

$IFTHEN.elh2_coup %cm_elh2_coup% == "on"
*   flexible demand side tech market value (electricity price that the flex tech "sees")
    p32_DIETER_MP(t,regi,"elh2")$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"elh2","market_price")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_MP(t,regi,"tdels")$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"el","market_price")$(tDT32(t) AND regDTCoup(regi)));
    p32_DIETER_MP(t,regi,"tdelt")$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"el","market_price")$(tDT32(t) AND regDTCoup(regi)));
$ENDIF.elh2_coup

*** DIETER electricity price
    p32_DIETER_elecprice(t,regi)$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_reportmk_4RM(gdxfile32,t,regi,"all_te","elec_price")$(tDT32(t) AND regDTCoup(regi)));

*** CG: storage related coupling parameters
* if( (ord(iteration) le (sm32_DTiter + 1)),
* ** no curt_ratio averaging
p32_DIETER_curtailmentratio(t,regi,"spv")$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"Solar","curt_ratio")$(tDT32(t) AND regDTCoup(regi)));
p32_DIETER_curtailmentratio(t,regi,"wind")$(tDT32(t) AND regDTCoup(regi)) = sum(gdxfile32,p32_report4RM(gdxfile32,t,regi,"Wind_on","curt_ratio")$(tDT32(t) AND regDTCoup(regi)));
* );

* with curt_ratio averaging
* if( (ord(iteration) gt (sm32_DTiter + 1)),
p32_DIETER_curtailmentratio(t,regi,"spv")$(tDT32(t) AND regDTCoup(regi)) =
      0.5 * (p32_DIETER_curtailmentratio_last_iter(t,regi,"spv") + p32_DIETER_curtailmentratio(t,regi,"spv"));

p32_DIETER_curtailmentratio(t,regi,"wind")$(tDT32(t) AND regDTCoup(regi)) =
      0.5 * (p32_DIETER_curtailmentratio_last_iter(t,regi,"wind") + p32_DIETER_curtailmentratio(t,regi,"wind"));
* );

* ror capfac is harmonized by putting capfac in DIETER to be the same as that in REMIND

$ENDIF.DTcoup

*** EOF ./modules/32_power/DTcoup/presolve.gms
