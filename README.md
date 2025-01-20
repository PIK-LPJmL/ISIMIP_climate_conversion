# ISIMIP climate input conversion
-----

This repository provides code to convert climate inputs provided by the
Inter-Sectoral Impact Model Intercomparison Project (https://www.isimip.org/)
into inputs that can be used with LPJmL.

The purpose is to document how climate source data as provided by ISIMIP during
phase 3 a & b (that include leap years and are split into separate files per
decade) are converted into inputs that can be used with LPJmL (without leap
years).

It may also help other users to generate climate inputs for their versions of
LPJmL.

## Requirements

- bash
- C compiler
- CDO (Climate Data Operators, https://code.mpimet.mpg.de/projects/cdo)
- NetCDF library (including header files)

## Files

- `climate_nc2clm_ISIMIP3a.sh`, `climate_nc2clm_ISIMIP3B.sh`: bash scripts that
  determine available source files and generate call to conversion tool
  `isimip_nc2clm_v2`
- `generate_lwnet_ISIMIP3a.sh`, `generate_lwnet_ISIMIP3B.sh`: bash scripts that
  generate long-wave net radiation (used by LPJmL) from Surface Downwelling
  Longwave Radiation (rlds) and Near-Surface Air Temperature (tas) provided by
  ISIMIP using CDO
- `isimip_nc2clm_v2.c`: source code for conversion tool `isimip_nc2clm_v2`
- `LICENSE`: copy of GNU AFFERO GENERAL PUBLIC LICENSE
- `README.md`: this file

## Notes
- Some commands in the bash scripts to load software modules and all mentioned
  directories are specific to the software environment at the Potsdam Institute
  for Climate Impact Research (PIK). Adjust to your system.
- Likewise, the comment how to compile `isimip_nc2clm_v2.c` is specific to the
  software and hardware environment at PIK. You may be able to install both
  `cdo` and the NetCDF library using the package manager of your system and may
  use a different C compiler with different optimization settings.
