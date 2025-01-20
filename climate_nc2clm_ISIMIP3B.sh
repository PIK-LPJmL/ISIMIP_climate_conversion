#!/bin/bash

module load netcdf-c/4.6.1/intel/serial
module load intel/2019.5
echo -e "\n\n  ##########################################\n\n  run the shellscript 'climate_nc2clm_ISIMIP3B.sh'\n  to convert NetCDF to clm-files\n\n  ###########################################\n\n"


# setup
# *****
username=` id -u -n `
# @PIK_cluster
directory_netcdf=/p/projects/isimip/isimip/ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily # directory containing main ISIMIP3b NetCDFs
directory_lwnet=/p/projects/lpjml/input/scenarios/ISIMIP3bv2/ # directory containing lwnet data (NetCDF)
gridpath=/p/projects/lpjml/input/historical/input_VERSION2/grid.bin # path to LPJmL input grid
directory_clm=/p/projects/lpjml/input/scenarios/ISIMIP3bv2 # base directory for output


# setup
program=./isimip_nc2clm_v2 # executable that converts NetCDF into CLM2
#ncells=67420 # this is now determined from input grid

var_index=( 0 1 2 3 4 5 6 7 )
#var_index=3
var_name=( "pr"       "tas"     "rsds" "lwnet" "sfcwind" "tasmax"  "tasmin"  "huss" )
offset=(   "0.0"      "-273.15" "0.0"  "0.0"   "0.0"     "-273.15" "-273.15" "0.0" )
convert=(  "864000.0" "10.0"    "10.0" "10.0"  "100.0"   "10.0"    "10.0"    "1.0" )
scale=(    "0.1"      "0.1"     "0.1"  "0.1"   "0.01"    "0.1"     "0.1"     "1.0" )
flag=(     ""         ""        ""     ""      ""        ""        ""        "-float" ) # flag "-float" creates CLM version 3 with data type float

gcm_index=( 0 1 2 3 4 )
#gcm_index=0
gcm_path=( "GFDL-ESM4" "IPSL-CM6A-LR" "MPI-ESM1-2-HR" "MRI-ESM2-0" "UKESM1-0-LL")
gcm_name=( ${gcm_path[@]} )
gcm_spath=( "gfdl-esm4" "ipsl-cm6a-lr" "mpi-esm1-2-hr" "mri-esm2-0" "ukesm1-0-ll")
gcm_runs=( "r1i1p1f1" "r1i1p1f1" "r1i1p1f1" "r1i1p1f1" "r1i1p1f2")

scen_index=( 0 1 2  )
#scen_index=2
scen_name=( "ssp126" "ssp370" "ssp585" )

process_piControl="TRUE"
process_historical="TRUE" 
process_scenarios="TRUE" 




# make clm-Folder structure:
# **************************

# clm Folder:
for m in ${gcm_index[@]}; do
    mkdir -p -v $directory_clm"/historical/"${gcm_path[$m]}"/"
    mkdir -p -v $directory_clm"/picontrol/"${gcm_path[$m]}"/"
    for s in ${scen_index[@]}; do
        mkdir -p -v $directory_clm"/"${scen_name[$s]}"/"${gcm_path[$m]}
    done
done
        
        
for m in ${gcm_index[@]}; do
    time_m1=$(date +%s)
    echo -e "\n\n  ___________________________________\n\n  *******  GCM: ${gcm_path[$m]}  *******\n  ___________________________________\n\n"
            
            
    for v in ${var_index[@]}; do
        echo -e "\n  > VARIABLE: ${var_name[$v]} (offset: ${offset[$v]}, convert: ${convert[$v]}, scale: ${scale[$v]})\n\n"
                
        # piControl-data:
        # ************

        if [ $process_piControl == "TRUE" ]
        then
            echo "  >> PROCESS piControl-DATA:"
            echo ""
            time_sp1=$(date +%s)
            spinup_filename=""
            if [ ${var_name[$v]} == "lwnet" ]
            then
                spinup_filename=( `ls $directory_lwnet/lwnet/picontrol/${gcm_name[$m]}/lwnet_day_picontrol_${gcm_runs[$m]}*.nc ` )
            else
                spinup_filename=( `ls $directory_netcdf/picontrol/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}_w5e5_picontrol_${var_name[$v]}_global_*.nc ` )
            fi
            ## extract first year
            if [ ${#spinup_filename[@]} -gt 0 ]; then
                sp_firstyearindex=` expr ${#spinup_filename[0]} - 12 ` # this assumes that the filename ends on yyyy-yyyy.nc; filename_length-12
                sp_firstyear=${spinup_filename[0]:$sp_firstyearindex:4} # substring of spinup_filename[0] starting from index sp_firstyear and length 4
                sp_lastyearindex=` expr ${#spinup_filename[${#spinup_filename[@]}-1]} - 7 ` # filename_length-7
                sp_lastyear=${spinup_filename[${#spinup_filename[@]}-1]:$sp_lastyearindex:4}
                # run the program for piControl data:
                # *******************************    
                # set output-path and name of clm-files:
                outputfile=$directory_clm"/picontrol/"${gcm_path[$m]}"/"${var_name[$v]}"_"${gcm_spath[$m]}"_picontrol_"$sp_firstyear"-"$sp_lastyear".clm"             
                variable=""
                if [ ${var_name[$v]} == "lwnet" ]
                then variable="rlds"
                else variable=${var_name[$v]}
                fi
                # create row of arguments to run the program (to create clm-files from NetCDF-data in workspace):
                run_program=$program" "${#spinup_filename[@]}" "${spinup_filename[@]}" "$variable" "$sp_firstyear" "$gridpath" "${offset[$v]}" "${convert[$v]}" "${scale[$v]}" "$outputfile" "${flag[$v]}
                echo ""
                echo "  > running program (with arguments as follows):"
                echo "       $run_program"
                echo ""
                # start program:
                #continue # TESTING ONLY
                $run_program
                time_sp2=$(date +%s)
                echo -e "\n  > CLM-FILE: $outputfile\n\n"
                echo -e "  (end processing of piControl data: variable "${var_name[$v]}";  duration ~ $(((time_sp2-time_sp1)/60)) min.)\n\n"   
                echo -e "  **************************************************************************************\n\n\n"
            else
                echo -e "  > Error: no piControl data files found for variable " ${var_name[$v]}
            fi
        else
            echo -e "  ( do not process piControl-data )\n\n"
        fi

        
        if [ $process_historical == "TRUE" ]
        then
            echo "  >> PROCESS historical-DATA:"
            echo ""
            # historical files:
            hist_filename=""
            if [ ${var_name[$v]} == "lwnet" ]
            then
                hist_filename=( `ls $directory_lwnet/lwnet/historical/${gcm_name[$m]}/lwnet_day_historical_${gcm_runs[$m]}*.nc ` )
            else
                hist_filename=( `ls $directory_netcdf/historical/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}_w5e5_historical_${var_name[$v]}_global_*.nc ` )
            fi
            ## extract first year
            if [ ${#hist_filename[@]} -gt 0 ]; then
                firstyearindex=` expr ${#hist_filename[0]} - 12 ` # this assumes that the filename ends on yyyy-yyyy.nc
                firstyear=${hist_filename[0]:$firstyearindex:4}
                lastyearindex=` expr ${#hist_filename[${#hist_filename[@]}-1]} - 7 `
                lastyear=${hist_filename[${#hist_filename[@]}-1]:$lastyearindex:4}
                # run the program for spinupdata:
                # *******************************    
                # set output-path and name of clm-files:
                outputfile=$directory_clm"/historical/"${gcm_path[$m]}"/"${var_name[$v]}"_"${gcm_spath[$m]}"_historical_"$firstyear"-"$lastyear".clm"
                variable=""
                if [ ${var_name[$v]} == "lwnet" ]
                then variable="rlds"
                else variable=${var_name[$v]}
                fi
                # create row of arguments to run the program (to create clm-files from NetCDF-data in workspace):
                run_program=$program" "${#hist_filename[@]}" "${hist_filename[@]}" "$variable" "$firstyear" "$gridpath" "${offset[$v]}" "${convert[$v]}" "${scale[$v]}" "$outputfile" "${flag[$v]}
                echo ""
                echo "  > running program (with arguments as follows):"
                echo "       $run_program"
                echo ""
                # start program:
                #continue # TESTING ONLY
                $run_program
                time_sp2=$(date +%s)
                echo -e "\n  > CLM-FILE: $outputfile\n\n"
                echo -e "  (end processing of historical data: variable "${var_name[$v]}";  duration ~ $(((time_sp2-time_sp1)/60)) min.)\n\n"   
                echo -e "  **************************************************************************************\n\n\n"
            else
                echo -e "  > Error: no historical data files found for variable " ${var_name[$v]}
            fi
        else
            echo -e "  ( do not process piControl-data )\n\n"
        fi
        
        
        # climate-scenarios:
        # ******************

        if [ $process_scenarios == "TRUE" ]
        then
            echo -e "  >> PROCESS SCENARIO-DATA:\n\n"

            # scenario-files:
            for s in ${scen_index[@]}; do
                time_sc1=$(date +%s)
                if [ ${var_name[$v]} == "lwnet" ]
                then
                    scen_filename=( `ls $directory_lwnet/lwnet/${scen_name[$s]}/${gcm_name[$m]}/lwnet_day_${scen_name[$s]}_${gcm_runs[$m]}*.nc ` )
                else
                    scen_filename=( `ls $directory_netcdf/${scen_name[$s]}/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}_w5e5_${scen_name[$s]}_${var_name[$v]}_global_*.nc ` )
                fi
                if [ ${#scen_filename[@]} -gt 0 ]; then
                    firstyearindex=` expr ${#scen_filename[0]} - 12` # this assumes that the filename ends on yyyy-yyyy.nc
                    firstyear=${scen_filename[0]:$firstyearindex:4}
                fi
                if [ ${#scen_filename[@]} -gt 0 ]; then
                    lastyearindex=` expr ${#scen_filename[${#scen_filename[@]}-1]} - 7 `
                    lastyear=${scen_filename[${#scen_filename[@]}-1]:$lastyearindex:4}
                fi
                echo ""
                echo "       > SCENARIO: ${scen_name[$s]}"
                echo ""

                # run the program:
                # ****************   
                # write complete filenamestring:
                complete_filestring=( ${scen_filename[@]} )
                # set output-path and name of clm-files:
                outputfile=$directory_clm"/"${scen_name[$s]}"/"${gcm_path[$m]}"/"${var_name[$v]}"_"${gcm_spath[$m]}"_"${scen_name[$s]}"_"$firstyear"-"$lastyear".clm"
                variable=""
                if [ ${var_name[$v]} == "lwnet" ]
                then variable="rlds"
                else variable=${var_name[$v]}
                fi

                nc_number=${#scen_filename[@]}
                # create row of arguments to run the program (to create clm-files from NetCDF-data in workspace):
                run_program=$program" "$nc_number" "${complete_filestring[@]}" "$variable" "$firstyear" "$gridpath" "${offset[$v]}" "${convert[$v]}" "${scale[$v]}" "$outputfile" "${flag[$v]}
                echo ""
                echo "       > running program (with arguments as follows):"
                echo "       $run_program"
                echo ""
                # start program:
                #continue # TESTING ONLY
                $run_program
                echo -e "\n       > CLM-FILE: $outputfile\n\n"
                time_sc2=$(date +%s)
                echo -e "       (end processing of variable "${var_name[$v]}" in scenario ${scen_path[$s]};  duration ~ $(((time_sc2-time_sc1)/60)) min.)\n\n"   

            done # s
            # remove files in workspace:
            #echo "       > remove files in workspace ..." 
            #rm $work_directory" *"

        else
            echo -e "  ( do not process scenario-data )\n\n"
        fi
        echo -e "\n   *************************************************************************\n\n"
    done # v

    time_m2=$(date +%s)
    echo -e "  ( end processing of model ${gcm_path[$m]};  duration ~ $(((time_m2-time_m1)/60)) min. )\n\n"

done # m

# END
