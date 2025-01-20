#!/bin/bash

###########################################################
## script to generate lwnet data for GCMs from ISIMIP3A

module purge
module load cdo/1.7.0
#module load intel/2018.1

# @PIK_cluster
directory_netcdf=/p/projects/isimip/isimip/ISIMIP3a/InputData/climate/atmosphere # directory containing main ISIMIP3a NetCDFs
directory_lwnet=/p/projects/lpjml/input/historical/ISIMIP3av2 # directory containing lwnet data (NetCDF)

# DSET_index=( 0 1 )
DSET_index=( 2 )
# DSET_index=( 1 2 3 )
DSET_path=( "GSWP3-W5E5" "20CRv3" "20CRv3-ERA5" "20CRv3-W5E5" )
DSET_name=( "gswp3-w5e5" "20crv3" "20crv3-era5" "20crv3-w5e5" )

scen_index=( 0 1 2 )
# scen_index=( 1 2 )
scen_name=( "obsclim" "spinclim" "counterclim" )

# lwnet-Folder:
for m in ${DSET_index[@]}; do
  for s in ${scen_index[@]}; do
    mkdir -p -v $directory_lwnet"/lwnet/"${scen_name[$s]}"/"${DSET_path[$m]}"/"
  done
done
            
            
for m in ${DSET_index[@]}; do
  echo ""
  echo "  *******  Data set: ${DSET_path[$m]}  *******"
  echo "  __________________________________"

  for s in ${scen_index[@]}; do
    echo -e "\n    ( climate version: ${scen_name[$s]} )\n"
    scen_tasfiles=( `ls $directory_netcdf/${scen_name[$s]}/global/daily/historical/${DSET_path[$m]}/${DSET_name[$m]}_${scen_name[$s]}_tas_global_daily_*.nc ` )
    firstyearindex=` expr ${#scen_tasfiles[0]} - 12 ` # this assumes that the filename ends on yyyy_yyyy.nc
    for nc_tas in ${scen_tasfiles[@]}; do
      t=${nc_tas:$firstyearindex:9}
      echo "    > calculate years $t"
      nc_rlds=$directory_netcdf/${scen_name[$s]}/global/daily/historical/${DSET_path[$m]}/${DSET_name[$m]}_${scen_name[$s]}_rlds_global_daily_$t.nc
      output_sigmat4=${directory_lwnet}/lwnet/${scen_name[$s]}/${DSET_path[$m]}/${DSET_name[$m]}_${scen_name[$s]}_sigmat4_global_daily_$t.nc
      output_lwnet=${directory_lwnet}/lwnet/${scen_name[$s]}/${DSET_path[$m]}/${DSET_name[$m]}_${scen_name[$s]}_lwnet_global_daily_$t.nc
      if [ -e "$output_lwnet" ]; then
        echo "    > Skipping because ${output_lwnet} exists"
        continue
      fi
      if [ ! -e "$nc_rlds" ]; then
        echo "    > Error: ${nc_rlds} not found"
        continue
      fi
      echo "   > use data: $nc_tas"
      echo "   > use data: $nc_rlds"
      echo "   > write data: $output_sigmat4 (deleted after processing)"
      echo "   > write data: $output_lwnet"
      echo ""

      cdo mulc,5.670373e-8 -mul $nc_tas -mul $nc_tas -mul $nc_tas $nc_tas $output_sigmat4
      cdo sub $nc_rlds $output_sigmat4 $output_lwnet
      rm $output_sigmat4
    done # t
    echo ""
  done # s
done # DSET

# END
