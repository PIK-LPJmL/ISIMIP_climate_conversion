#!/bin/bash

###########################################################
## script to generate lwnet data for GCMs from ISIMIP3B

module purge
module load cdo/1.7.0
#module load intel/2018.1

# @PIK_cluster
directory_netcdf=/p/projects/isimip/isimip/ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily # directory containing main ISIMIP3b NetCDFs
directory_lwnet=/p/projects/lpjml/input/scenarios/ISIMIP3bv2/ # directory containing lwnet data (NetCDF)

process_piControl="TRUE"
process_historical="TRUE"
process_scenario="TRUE"

gcm_index=( 0 1 2 3 4 )
gcm_path=( "GFDL-ESM4" "IPSL-CM6A-LR" "MPI-ESM1-2-HR" "MRI-ESM2-0" "UKESM1-0-LL")
gcm_spath=( "gfdl-esm4" "ipsl-cm6a-lr" "mpi-esm1-2-hr" "mri-esm2-0" "ukesm1-0-ll")
gcm_runs=( "r1i1p1f1" "r1i1p1f1" "r1i1p1f1" "r1i1p1f1" "r1i1p1f2")
gcm_name=( ${gcm_path[@]} )

scen_index=( 0 1 2 )
scen_name=( "ssp126" "ssp370" "ssp585" )

# lwnet-Folder:
for m in ${gcm_index[@]}; do
    mkdir -p $directory_lwnet"lwnet/historical/"${gcm_path[$m]}"/"
    if [ $process_piControl == "TRUE" ]
        then 
        mkdir -p -v $directory_lwnet"lwnet/picontrol/"${gcm_path[$m]}"/"
        #else echo ""
    fi
    for s in ${scen_index[@]}; do
            mkdir -p -v $directory_lwnet"lwnet/"${scen_name[$s]}"/"${gcm_path[$m]}"/"
    done
done
            
            
for m in ${gcm_index[@]}; do
    echo ""
    echo "  *******  GCM: ${gcm_path[$m]}  *******"
    echo "  __________________________________"
    

    if [ $process_piControl == "TRUE" ]
        then
        echo ""
        echo "    PROCESS 'lwnet'-piControl DATA"
        echo ""
        picontrol_tasfiles=( `ls $directory_netcdf/picontrol/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}_w5e5_picontrol_tas_global_*.nc ` ) # look for temperature files
        firstyearindex=` expr ${#picontrol_tasfiles[0]} - 12 ` # index of firstyear in filename; this assumes that the filename ends on yyyy-yyyy.nc, computes filename_length-21; adapt if filenames change
        #break

        #for nc_tas in ${picontrol_tasfiles[@]}; do
         for nc_tas in $(ls $directory_netcdf/picontrol/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}_w5e5_picontrol_tas_global_*.nc); do 
            t=${nc_tas:$firstyearindex:9} # gets substring of nc_tas from position firstyearindex with length 9 (yyyy-yyyy)
            echo "    > calculate years $t"
            nc_rlds=$directory_netcdf/picontrol/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}"_w5e5_picontrol_rlds_global_daily_"$t".nc"
            output_sigmat4=$directory_lwnet"lwnet/picontrol/"${gcm_path[$m]}"/sigmat4_day_"${gcm_spath[$m]}"_picontrol_"${gcm_runs[$m]}"_"$t".nc"
            output_lwnet=$directory_lwnet"lwnet/picontrol/"${gcm_name[$m]}"/lwnet_day_picontrol_"${gcm_runs[$m]}"_"$t".nc"
            if [ -f "$output_lwnet" ]; then
                echo "    > Skipping because ${output_lwnet} exists"
                continue
            fi
            if [ ! -f "$nc_rlds" ]; then
                echo "    > Error: ${nc_rlds} not found"
                continue
            fi
            if [ ! -f "$nc_tas" ]; then
                echo "    > Error: ${nc_tas} not found"
                continue
            fi
            echo "   > use data: $nc_tas"
            echo "   > use data: $nc_rlds"
            echo "   > write data: $output_sigmat4 (deleted after processing)"
            echo "   > write data: $output_lwnet"
            echo ""
            # continue # Only for testing
            cdo mulc,5.670373e-8 -mul $nc_tas -mul $nc_tas -mul $nc_tas $nc_tas $output_sigmat4
            cdo sub $nc_rlds $output_sigmat4 $output_lwnet
            rm $output_sigmat4
        done # t
    else
        echo ""
        echo "   ( do not process piControl-data )"
        echo ""
    fi
                                        
    # generate historical lwnet-data:
    # *******************************
    if [ $process_historical == "TRUE" ]
        then
        echo ""
        echo "    PROCESS HISTORICAL 'lwnet'-DATA:"
        echo ""

        #hist_tasfiles=( `ls $directory_netcdf/${gcm_path[$m]}.landonly/EWEMBI/tas_day_${gcm_name[$m]}_historical_r1i1p1_EWEMBI_landonly_*.nc4 ` ) # look for temperature files
        hist_tasfiles=( `ls $directory_netcdf/historical/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}_w5e5_historical_tas_global_*.nc ` ) # look for temperature files
        firstyearindex=` expr ${#hist_tasfiles[0]} - 12 ` # this assumes that the filename ends on yyyy-yyyy.nc
        #break

        for nc_tas in ${hist_tasfiles[@]}; do
            t=${nc_tas:$firstyearindex:9}
            echo "    > calculate years $t"
            nc_rlds=$directory_netcdf/historical/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}"_w5e5_historical_rlds_global_daily_"$t".nc"
            output_sigmat4=$directory_lwnet"lwnet/historical/"${gcm_path[$m]}"/sigmat4_day_"${gcm_spath[$m]}"_historical_"${gcm_runs[$m]}"_"$t".nc"
            output_lwnet=$directory_lwnet"lwnet/historical/"${gcm_name[$m]}"/lwnet_day_historical_"${gcm_runs[$m]}"_"$t".nc"
            if [ -f "$output_lwnet" ]; then
                echo "    > Skipping because ${output_lwnet} exists"
                continue
            fi
            if [ ! -f "$nc_rlds" ]; then
                echo "    > Error: ${nc_rlds} not found"
                continue
            fi
            if [ ! -f "$nc_tas" ]; then
                echo "    > Error: ${nc_tas} not found"
                continue
            fi
            echo "   > use data: $nc_tas"
            echo "   > use data: $nc_rlds"
            echo "   > write data: $output_sigmat4 (deleted after processing)"
            echo "   > write data: $output_lwnet"
            echo ""
            # continue # Only for testing
            cdo mulc,5.670373e-8 -mul $nc_tas -mul $nc_tas -mul $nc_tas $nc_tas $output_sigmat4
            cdo sub $nc_rlds $output_sigmat4 $output_lwnet
            rm $output_sigmat4
        done # t
    else
        echo ""
        echo "   ( do not process historical-data )"
        echo ""
    fi

    # generate scenario lwnet-data:
    # ******************************
    if [ $process_scenario == "TRUE" ]
        then
        echo ""
        echo "    PROCESS 'lwnet'-SCENARIO-DATA:"
        echo ""
        for s in ${scen_index[@]}; do
            echo "    ( scenario: ${scen_name[$s]} )"
            echo ""
            scen_tasfiles=( `ls $directory_netcdf/${scen_name[$s]}/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}_w5e5_${scen_name[$s]}_tas_global_*.nc ` )
            firstyearindex=` expr ${#scen_tasfiles[0]} - 12 ` # this assumes that the filename ends on yyyy-yyyy.nc
            #break

            for nc_tas in ${scen_tasfiles[@]}; do
                t=${nc_tas:$firstyearindex:9}
                echo "    > calculate years $t"
                nc_rlds=$directory_netcdf/${scen_name[$s]}/${gcm_path[$m]}/${gcm_spath[$m]}_${gcm_runs[$m]}"_w5e5_"${scen_name[$s]}"_rlds_global_daily_"$t".nc"
                output_sigmat4=$directory_lwnet"lwnet/"${scen_name[$s]}"/"${gcm_path[$m]}"/sigmat4_day_"${gcm_spath[$m]}"_"${scen_name[$s]}"_"${gcm_runs[$m]}"_"$t".nc"
                output_lwnet=$directory_lwnet"lwnet/"${scen_name[$s]}"/"${gcm_name[$m]}"/lwnet_day_"${scen_name[$s]}"_"${gcm_runs[$m]}"_"$t".nc"
                if [ -f "$output_lwnet" ]; then
                    echo "    > Skipping because ${output_lwnet} exists"
                    continue
                fi
                if [ ! -f "$nc_rlds" ]; then
                    echo "    > Error: ${nc_rlds} not found"
                    continue
                fi
                if [ ! -f "$nc_tas" ]; then
                    echo "    > Error: ${nc_tas} not found"
                    continue
                fi
                echo "   > use data: $nc_tas"
                echo "   > use data: $nc_rlds"
                echo "   > write data: $output_sigmat4 (deleted after processing)"
                echo "   > write data: $output_lwnet"
                echo ""
                # continue # Only for testing
                cdo mulc,5.670373e-8 -mul $nc_tas -mul $nc_tas -mul $nc_tas $nc_tas $output_sigmat4
                cdo sub $nc_rlds $output_sigmat4 $output_lwnet
                rm $output_sigmat4
            done # t
            echo ""
        done # s
    else
        echo ""
        echo "   ( do not process scenario-data )"
        echo ""
    fi
done # gcm

# END
