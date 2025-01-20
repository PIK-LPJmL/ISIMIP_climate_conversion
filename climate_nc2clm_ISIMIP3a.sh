#!/bin/bash

module load netcdf-c/4.6.1/intel/serial
module load intel/2019.5
echo -e "\n\n  ##########################################\n\n  run the shellscript 'climate_nc2clm_ISIMIP3a.sh'\n  to convert NetCDF to clm-files\n\n  ###########################################\n\n"


# setup
# *****
username=` id -u -n `
# @PIK_cluster
directory_netcdf=/p/projects/isimip/isimip/ISIMIP3a/InputData/climate/atmosphere # directory containing main ISIMIP3a NetCDFs
directory_lwnet=/p/projects/lpjml/input/historical/ISIMIP3av2 # directory containing lwnet data (NetCDF)
gridpath=/p/projects/lpjml/input/historical/ISIMIP3a/grid_shift.bin # update 2020-07-06: counterclim and spinclim versions use grid where one cell is shifted by 0.5° causing missing values in CLM data. This grid file fixes this by remapping this one cell to the position in the LPJmL default grid
directory_clm=/p/projects/lpjml/input/historical/ISIMIP3av2 # base directory for output


# setup
program=/p/projects/lpjml/scripts/ISIMIP3/climate/isimip_nc2clm_v2 # executable that converts NetCDF into CLM2
#ncells=67420 # this is now determined from input grid

var_index=( 0 1 2 3 4 5 6 7 )
var_name=( "pr" "tas" "rsds" "lwnet" "sfcwind" "tasmax" "tasmin" "huss" )
offset=( "0.0" "-273.15" "0.0" "0.0" "0.0" "-273.15" "-273.15" "0.0" )
convert=( "864000.0" "10.0" "10.0" "10.0" "100.0" "10.0" "10.0" "1.0" )
scale=( "0.1" "0.1" "0.1" "0.1" "0.01" "0.1" "0.1" "1.0" )
flag=(   ""    ""     ""   ""     ""     ""    ""   "-float" ) # flag "-float" creates CLM version 3 with data type float

# DSET_index=( 0 1 )
DSET_index=( 0 )
#DSET_index=( 1 2 3 )
DSET_path=( "GSWP3-W5E5" "20CRv3" "20CRv3-ERA5" "20CRv3-W5E5" )
DSET_name=( "gswp3-w5e5" "20crv3" "20crv3-era5" "20crv3-w5e5" )

#scen_index=( 0 1 2 )
scen_index=( 1 2 )
scen_name=( "obsclim" "spinclim" "counterclim" )

# make clm-Folder structure:
# **************************

# clm Folder:
for m in ${DSET_index[@]}; do
  for s in ${scen_index[@]}; do
    mkdir -p -v ${directory_clm}/${scen_name[$s]}/${DSET_path[$m]}
  done
done
        
        
for m in ${DSET_index[@]}; do
  time_m1=$(date +%s)
  echo -e "\n\n  ___________________________________\n\n  *******  Dataset: ${DSET_path[$m]}  *******\n  ___________________________________\n"
    for s in ${scen_index[@]}; do
      echo -e "  >> PROCESS CLIMATE VERSION: ${scen_name[$s]}"

      for v in ${var_index[@]}; do
        echo -e "  > VARIABLE: ${var_name[$v]} (offset: ${offset[$v]}, convert: ${convert[$v]}, scale: ${scale[$v]})"

        time_sc1=$(date +%s)
        if [ ${var_name[$v]} == "lwnet" ]
        then
          scen_filename=( `ls ${directory_lwnet}/lwnet/${scen_name[$s]}/${DSET_path[$m]}/${DSET_name[$m]}_${scen_name[$s]}_${var_name[$v]}_global_daily_*.nc ` )
        else
          scen_filename=( `ls $directory_netcdf/${scen_name[$s]}/global/daily/historical/${DSET_path[$m]}/${DSET_name[$m]}_${scen_name[$s]}_${var_name[$v]}_global_daily_*.nc ` )
        fi
        if [ ${#scen_filename[@]} -gt 0 ]; then
          firstyearindex=` expr ${#scen_filename[0]} - 12` # this assumes that the filename ends on yyyy_yyyy.nc
          firstyear=${scen_filename[0]:$firstyearindex:4}
          lastyearindex=` expr ${#scen_filename[${#scen_filename[@]}-1]} - 7 `
          lastyear=${scen_filename[${#scen_filename[@]}-1]:$lastyearindex:4}
        else
          echo -e "  > Error: No source files found. Skipping variable ${var_name[$v]}"
          continue
        fi
        echo ""
        # run the program:
        # ****************   
        # write complete filenamestring:
        complete_filestring=( ${scen_filename[@]} )
        # set output-path and name of clm-files:
        outputfile=${directory_clm}/${scen_name[$s]}/${DSET_path[$m]}/${var_name[$v]}_${DSET_name[$m]}_${scen_name[$s]}_${firstyear}-${lastyear}.clm
        variable=""
        if [ ${var_name[$v]} == "lwnet" ]; then
          variable="rlds"
        elif [ ${var_name[$v]} == "sfcwind" ] && [ ${scen_name[$s]} == "obsclim" ]; then
          # variable is named incorrectly in obsclim version of wind speed
          # variable="wind"
          # update June 10: now named correctly
          variable=${var_name[$v]}
        else 
          variable=${var_name[$v]}
        fi
        nc_number=${#scen_filename[@]}
        # create row of arguments to run the program (to create clm-files from NetCDF-data in workspace):
        run_program=$program" "$nc_number" "${complete_filestring[@]}" "$variable" "$firstyear" "$gridpath" "${offset[$v]}" "${convert[$v]}" "${scale[$v]}" "$outputfile" "${flag[$v]}
        echo "       > running program (with arguments as follows):"
        echo "       $run_program"
        echo ""
        # start program:
        #continue # TESTING ONLY
        $run_program
        echo -e "       > CLM-FILE: $outputfile"
        time_sc2=$(date +%s)
        echo -e "       (end processing of variable "${var_name[$v]}" in climate version ${scen_path[$s]};  duration ~ $(((time_sc2-time_sc1)/60)) min.)\n\n"   
      done # variables
    echo -e "   *************************************************************************"
  done # versions

time_m2=$(date +%s)
echo -e "  ( end processing of dataset ${DSET_path[$m]};  duration ~ $(((time_m2-time_m1)/60)) min. )\n"

done # datasets

# END
