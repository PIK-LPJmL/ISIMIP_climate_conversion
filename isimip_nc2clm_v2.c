/*
 * isimip_nc2clm_v2.c
 *
 *  Created from isimip_nc2clm: May 19, 2020
 *                          by: ostberg
 *  The version allows the creation of CLM3 files with data type LPJ_FLOAT
 *  Use the new optional command line argument -float for this
 *  Some additional changes compared to its predecessor including how to
 *  print error messages, how to print ranges for very small values and
 *  recognizing "prec" as precipitation in addition to "pr" and "prsn"
 */
/* compile on cluster e.g:
 * module load netcdf-c/4.6.1/intel/serial
 * module load intel/2019.5
 * icc -O3 -xCORE-AVX2 -no-vec isimip_nc2clm_v2.c -o isimip_nc2clm_v2 -B $NETCDF_CROOT -B $NETCDF_CROOT/lib -lnetcdf -lm
 */


#include <stdio.h>
#include <string.h>
#include <netcdf.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
#include <float.h>
#define is_equal(a, b) (fabs((a) - (b)) < 0.0001)
/* make sure that these correspond to values defined in types.h of LPJmL */
#define LPJ_FLOAT 3
#define LPJ_SHORT 1


typedef struct {
	int version, order, firstyear, nyear, firstcell, ncell, nband;
	float cellsize, scalar;
} Header; // cellsize = float

// ***** swap-functions *****
static void swap(char *a,char *b){
	char h;
	h=*a;
	*a=*b;
	*b=h;
}

short int swapshort(short int x){
	swap((char *)&x,(char *)(&x)+1);
	return x;
}

int swapint(int x){
	swap((char *)&x,(char *)(&x)+3);
	swap((char *)&x+1,(char *)(&x)+2);
	return x;
} 

static float swapfloat(int num)
{
	float ret;
	num=swapint(num);
	memcpy(&ret,&num,sizeof(int));
	return ret;
} // of 'swapfloat'

void usage(char* progname){
	fprintf(stderr, "Use: %s number_of_infiles infilenames var firstyear path_to_gridfile offset convert scalar path_to_outfile [-float]\n", progname);
	fprintf(stderr, "Provide as many infilenames as number_of_infiles.\n");
	fprintf(stderr, "var: variable name in NetCDF files (only provided once, not for each file)\n");
  fprintf(stderr, "firstyear: first year of generated CLM file, corresponds to first year in first input file\n");
  fprintf(stderr, "path_to_gridfile: must be input grid with new header\n");
	fprintf(stderr, "offset: offset added to values read from input file\n");
  fprintf(stderr, "convert: conversion factor, multiplied with input values (after adding offset)\n");
  fprintf(stderr, "scalar: scalar to be used in LPJmL when reading CLM2 (written to header, has no effect on values in this program)\n");
	fprintf(stderr, "path_to_outfile: all input files are combined into one single output file (CLM2).\n");
  fprintf(stderr, "-float: optional parameter to force generation of CLM3 with data type LPJ_FLOAT. Default is to omit this parameter and generate CLM2 with LPJ_SHORT.\n\n");
  fprintf(stderr, "Note: data conversion: CLM data = (NetCDF data + offset) * convert\n");
	exit(-1);
}

// ***** start of program *****
int main(int argc, char *argv[0]) // *1
{
	
	
	// ***** variables *****
	Header *grid_header, *clm_header;
	size_t lonlen, latlen, time_len; // length of variables in NetCDF
	size_t start[3], count[3];
	int status, ncid, var_id, lat_id, lon_id, time_id;
	int leap_yr = 0; // leap_yr: used as boolean (if current year is a leap-year the value is 1)
	int firstyear = 0; // should be the first year of the first NetCDF-file (given as argument)
	int number_yr = 0; // number_yr: number of years in current NetCDF
	int all_years = 0; // whole number of years in clm-file
	int nc_index = 0;
	int clm_index = 0;
	int cell, clm_day, column, day, febday, file, row, year; // counter-variables in loops
	int *ilon, *ilat;
	short *clm_writedata_short, *grid_data;
	float convert = 0.0;
	float offset = 0.0;
	float scalar = 0.0;
	float fill_value = 0.0;
	float *clm_data, *nc_data;
	int ncells = 0;
  int writefloat = 0;
  int datatype = LPJ_SHORT;
	double *nclon, *nclat;
	char *var, *path_to_gridfile, *path_to_outfile, *grid_headername;
	FILE *grid_file, *clm_file;
	short swap_grid, grid_error, file_error, memory_error, filename_mentioned;
	long int fill_error, range_error;
	float fieldmin, fieldmax;
	
	/* initialization */
	grid_file=clm_file=NULL;
	clm_data=nc_data=NULL;
	ilon=ilat=NULL;
	clm_writedata_short=grid_data=NULL;
	nclon=nclat=NULL;
	swap_grid=grid_error=file_error=memory_error = 0;
	fill_error=range_error = 0;
	
	
	// ***** assign Arguments *****
	if(argc < 10)
		usage(argv[0]);
	int number_infiles = atoi(argv[1]);
	if(argc != number_infiles+9 && argc != number_infiles+10)
		usage(argv[0]);
	
	var = (char*)argv[number_infiles+2];
	firstyear = atoi(argv[number_infiles+3]);
	path_to_gridfile = (char*)argv[number_infiles+4];
	offset = (float)atof(argv[number_infiles+5]);	
	convert = (float)atof(argv[number_infiles+6]);	
	scalar = (float)atof(argv[number_infiles+7]);	
	path_to_outfile = (char*)argv[number_infiles+8];
  if(argc==number_infiles+10) {
    if(strcmp((char*)argv[number_infiles+9], "-float") == 0) {
      writefloat=1;
      datatype=LPJ_FLOAT;
    } else {
      fprintf(stdout, "\t\tUnknown argument %s\n", argv[number_infiles+9]);
    }
  }
	
	
	// ***** LPJmL grid-file *****
	
	// open grid-file:
	grid_file = fopen(path_to_gridfile, "rb");
	if(grid_file == NULL) {
		fprintf(stderr, "\t\terror: could not open grid_file %s\n", path_to_gridfile);
		exit(-1);
	}
	
	// read header of grid_file:  
	grid_headername = (char *)malloc(7+1); // LPJGRID 
	grid_header = (Header *)malloc(sizeof(Header));
	fread(grid_headername, 7, 1, grid_file);
	fread(grid_header, sizeof(Header), 1, grid_file);
	
	if(grid_header->version != 1 && grid_header->version != 2) {
		if(swapint(grid_header->version) != 1 && swapint(grid_header->version) != 2) {
			fprintf(stderr, "\t\tinfo: error - cannot determine endian of grid_file\n");
			fclose(grid_file);
			exit(-1);
		}
		else{
			swap_grid = 1;
			grid_header->version = swapint(grid_header->version);
			grid_header->order = swapint(grid_header->order);
			grid_header->firstyear = swapint(grid_header->firstyear);
			grid_header->nyear = swapint(grid_header->nyear);
			grid_header->firstcell = swapint(grid_header->firstcell);
			grid_header->ncell = swapint(grid_header->ncell);
			grid_header->nband = swapint(grid_header->nband);
			grid_header->cellsize = swapfloat(grid_header->cellsize);
			grid_header->scalar = swapfloat(grid_header->scalar);
		}
	}
	ncells = grid_header->ncell;
	
	fprintf(stdout,"\t\t###############################\n");
	fprintf(stdout, "\t\t* number of infiles: %d\n", number_infiles);
	fprintf(stdout, "\t\t* var: %s\n", var);
	fprintf(stdout, "\t\t* firstyear: %d\n", firstyear);
	fprintf(stdout, "\t\t* path to gridfile: %s (ncells=%d)\n",path_to_gridfile, ncells);
	fprintf(stdout, "\t\t* offset (add): %f\n", offset);
	fprintf(stdout, "\t\t* convert units (mult): %f\n", convert);
	fprintf(stdout, "\t\t* scalar factor applied when read into LPJ (no change): %f\n", scalar);
	fprintf(stdout, "\t\t* path to outfile: %s\n\n",path_to_outfile);
  if(writefloat) {
    fprintf(stdout, "\t\t* outfile will be created as CLM type 3 with data type LPJ_FLOAT\n");
  }
  if(convert==0.0) {
    fprintf(stdout,"\t\t* Warning: You have set convert to 0.0 which will set all values to zero in CLM file.\n");
  }
  if(scalar==0.0) {
    fprintf(stdout,"\t\t* Warning: You have set scalar to 0.0 which will prompt LPJmL to multiply all CLM file values by zero when reading.\n");
  }
	
	// read grid-data:
	grid_data = malloc(sizeof(short)*ncells*2);
	if(grid_data == NULL) {
		fprintf(stderr, "Error allocating memory for grid_data\n");
		fclose(grid_file);
		exit(-1);
	}
	fread(grid_data, sizeof(short), ncells*2, grid_file);
	if(swap_grid == 1)
		for(cell = 0; cell < ncells*2; cell++)
			grid_data[cell] = swapshort(grid_data[cell]);
		
	ilon = (int*) malloc(sizeof(int)*ncells);
	ilat = (int*) malloc(sizeof(int)*ncells);
	if(ilat == NULL) {
		fprintf(stderr, "Error allocating memory for ilat\n");
		fclose(grid_file);
		exit(-1);
	}
	if(ilon == NULL) {
		fprintf(stderr, "Error allocating memory for ilon\n");
		fclose(grid_file);
		exit(-1);
	}
	
	/* memory for 1 year of LPJ data */
	clm_data = (float *)malloc(sizeof(float)*ncells*365); 
	clm_writedata_short = (short *)malloc(sizeof(short)*ncells*365);
	if(clm_data == NULL) {
		fprintf(stderr, "Error allocating memory for clm_data\n");
		fclose(grid_file);
		exit(-1);
	}
	if(clm_writedata_short == NULL) {
		fprintf(stderr, "Error allocating memory for clm_writedata_short\n");
		fclose(grid_file);
		exit(-1);
	}
	
	// ***** write header of clm-file *****
	
	// collect headerdata:
	clm_header = (Header*)malloc(sizeof(Header));
  if(writefloat) {
    clm_header->version = 3;
  } else {
    clm_header->version = 2;
  }
	clm_header->order = 1;
	clm_header->firstyear = firstyear;
	clm_header->nyear = 0;
	clm_header->firstcell = grid_header->firstcell; 
	clm_header->ncell = grid_header->ncell;
	clm_header->nband = 365;
	clm_header->cellsize = grid_header->cellsize;
	clm_header->scalar = scalar;
	
	
	// write header to clm-file:
	clm_file = fopen(path_to_outfile, "wb");
	if(clm_file == NULL) {
		fprintf(stderr, "\t\tinfo: could not open clm_file %s\n", clm_file);
		exit(-1);
		if(grid_file != NULL)
			fclose(grid_file);
	}
	fwrite("LPJCLIM", 7, 1, clm_file);
	fwrite(clm_header, sizeof(Header),1,clm_file);
  if(writefloat) {
    fwrite(&clm_header->cellsize, sizeof(float),1,clm_file); // assume cellsize_lat==cellsize_lon
    fwrite(&datatype, sizeof(int),1,clm_file);
  }

    
	
	/***** start of "file"-loop (to combine the different NetCDF-files) ****
	 ***********************************************************************/
	
	for (file=0; file<number_infiles; file++) {
  	filename_mentioned=0;
		// some information:
		fprintf(stdout, "\n\t\tread %d. NetCDF  ...\n",file+1);
		//fprintf(stdout, "\t\t***************\n\n");
		fprintf(stdout, "\t\tuse data from: %s\n",argv[file+2]);
		
		// open connection to NetCDF:
		status = nc_open(argv[file+2], 0, &ncid);          
		if(status != NC_NOERR) {
			/* could not open input file. Abort completely. */
			fprintf(stdout, "\t\tError no.%d: %s\n",status, nc_strerror(status));
			fprintf(stderr, "Error opening %s. Aborting.\n", argv[file+2]);
			file_error=-1;
			break;
		}
		
		// ***** get parameter of NetCDF *****
		// variable:
		status = nc_inq_varid(ncid,argv[number_infiles+2],&var_id);
		if(status != NC_NOERR){
			/* could not find variable */
			fprintf(stdout, "\t\tError no.%d: %s\n", status, nc_strerror(status));
			fprintf(stderr, "Error finding variable %s in inputfile. Aborting.\n", argv[number_infiles+2]);
			file_error=-1;
			break;
		}
		
		// get Fill-value:
		status = (int)nc_get_att_float(ncid, var_id, "_FillValue", &fill_value);
    if(status != NC_NOERR) {
      /* no _FillValue found, try missing_value */
      fprintf(stdout,"\t\tError no.%d: %s\n", status, nc_strerror(status));
      fprintf(stdout,"\t\tNo _FillValue attribute, checking for missing_value attribute\n");
      status = (int)nc_get_att_float(ncid, var_id, "missing_value", &fill_value);
      if(status != NC_NOERR) {
        fprintf(stdout,"\t\tError no.%d: %s\n", status, nc_strerror(status));
        fprintf(stderr,"Error finding either _FillValue or missing_value attribute. Aborting.\n");
        file_error=-1;
        break;
      } else {
        fprintf(stdout,"\t\tUsing missing_value attribute instead of _FillValue attribute.\n");
      }
    }
		
		// time:
		status = nc_inq_dimid(ncid,"time", &time_id);
    if(status != NC_NOERR) {
      /* no time dimension */
      fprintf(stdout,"\t\tError no.%d: %s\n", status, nc_strerror(status));
      fprintf(stderr,"Error finding time dimension in inputfile. Aborting.\n");
      file_error=-1;
      break;
    }
		status = nc_inq_dimlen(ncid, time_id, &time_len);
		number_yr = (int) (time_len/365);
		
		// latitude:   
		status = nc_inq_dimid(ncid,"lat",&lat_id);
    if(status != NC_NOERR) {
      /* no time dimension */
      fprintf(stdout,"\t\tError no.%d: %s\n", status, nc_strerror(status));
      fprintf(stderr,"Error finding lat dimension in inputfile. Aborting.\n");
      file_error=-1;
      break;
    }
		status = nc_inq_dimlen(ncid, lat_id, &latlen);
		nclat = (double*)malloc(sizeof(double)*latlen);
		if(nclat == NULL) {
			fprintf(stderr, "Error allocating memory for nclat\n");
			memory_error=-1;
			break;
		}
		status = (int) nc_inq_varid(ncid,"lat",&lat_id);
		status = (int) nc_get_var_double(ncid, lat_id, nclat);
		
		// longitude:
		status = nc_inq_dimid(ncid,"lon",&lon_id);
    if(status != NC_NOERR) {
      /* no time dimension */
      fprintf(stdout,"\t\tError no.%d: %s\n", status, nc_strerror(status));
      fprintf(stderr,"Error finding lon dimension in inputfile. Aborting.\n");
      file_error=-1;
      break;
    }
		status = nc_inq_dimlen(ncid, lon_id, &lonlen);
		nclon = (double*)malloc(sizeof(double)*lonlen);  
		if(nclon == NULL) {
			fprintf(stderr, "Error allocating memory for nclon\n");
			memory_error=-1;
			break;
		}
		status = (int) nc_inq_varid(ncid,"lon",&lon_id);
		status = (int) nc_get_var_double(ncid, lon_id, nclon);
		
		/***** write ilat and ilon *****/
		for(cell=0; cell<ncells; cell++){
			ilon[cell] = -999;
			ilat[cell] = -999;
			for(column=0; column<lonlen; column++) {
				if(is_equal((grid_data[cell*2]*grid_header->scalar),nclon[column]))
					ilon[cell] = column;
			}
			for(row = 0; row<latlen; row++){
				if(is_equal((grid_data[cell*2+1]*grid_header->scalar),nclat[row]))
					ilat[cell] = row;
			}
			if(is_equal(ilat[cell], -999) || is_equal(ilon[cell], -999)) {
				fprintf(stderr, "Error finding cell %d (%.2f E %.2f N) in NetCDF. Aborting.\n", cell, grid_data[cell*2]*grid_header->scalar, grid_data[cell*2+1]*grid_header->scalar);
				grid_error = -1;
			}
		}
		if(grid_error) {
			/* stop processing this and any following files */
			break;
		}
		
		
		// ***** start of "year"-loop *****
		
		// allocate memory for nc_data for one year:
		nc_data = (float*)malloc(sizeof(float)*lonlen*latlen*366);
		if(nc_data == NULL) {
			fprintf(stderr, "Error allocating memory for nc_data");
			memory_error = -1;
			break;
		}
		
		start[0] = (size_t) 0;
		for(year=0; year<number_yr; year++) {
			fprintf(stdout, "\t\t *** calculate year %d\n",firstyear+year);
			fieldmin=SHRT_MAX;
			fieldmax=SHRT_MIN;
      if(writefloat) {
        fieldmin=1e30;
        fieldmax=-1e30;
      }
			for(cell=0; cell < ncells*365; cell++) {
				clm_data[cell] = 0.0;
				clm_writedata_short[cell] = 0;
			}
			for(cell=0; cell < lonlen*latlen*366; cell++)
				nc_data[cell] = 0.0;
			
			// identify leap_year and "time_len":
			if( ((firstyear+year)%4 == 0) && ((firstyear+year)%100 != 0) || ((firstyear+year)%400 == 0) ) {
				leap_yr = 1;
				fprintf(stdout, "\t\t *** (leap year)\n");
				time_len = 366;
			} else {
				leap_yr = 0;
				time_len = 365;
			}
			
			// define start and number of reading values:
			start[1] = 0; // lat
			start[2] = 0; // lon
			count[0] = (size_t) time_len;
			count[1] = (size_t) latlen; 
			count[2] = (size_t) lonlen;
			
			// read values in nc_data:
			status = (int) nc_get_vara_float(ncid, var_id, start, count, nc_data);
			
			// ***** process values of NetCDF and write clm-file *****
			for(cell=0; cell<ncells; cell++){
				clm_day = 0;
				for(day=0; day<time_len; day++){
					if( leap_yr == 1 && day == 59 && (strcmp(var,"pr") != 0 && strcmp(var,"prsn") != 0 && strcmp(var, "prec") != 0) ) continue;
					if(cell==0 && leap_yr == 1 && day == 59)
						fprintf(stdout, "\t\tdistribute leapday values in february\n");
					
					// determine indices of NetCDF and clm-file: 
					nc_index = day*latlen*lonlen + ilat[cell]*lonlen + ilon[cell];
					clm_index = cell * 365 + clm_day;
					
					//test for fill-values and NaN
					if( is_equal(nc_data[nc_index], fill_value) ) {
						if(!filename_mentioned) {
							fprintf(stderr, "File: %s\n", argv[file+2]);
							filename_mentioned=1;
						}
						fprintf(stderr, "Fill-value found in nc_data (cell: %d (%.2f°, %.2f°), day: %d, year: %d)\n",cell, grid_data[cell*2]*grid_header->scalar, grid_data[cell*2+1]*grid_header->scalar, day, firstyear+year);
						fill_error+=1;
						//return 1;
					} else if(isnan(nc_data[nc_index])) {
						if(!filename_mentioned) {
							fprintf(stderr, "File: %s\n", argv[file+2]);
							filename_mentioned=1;
						}
						fprintf(stderr, "NaN found in nc_data (cell: %d (%.2f°, %.2f°), day: %d, year: %d)\n",cell, grid_data[cell*2]*grid_header->scalar, grid_data[cell*2+1]*grid_header->scalar, day, firstyear+year);
						fill_error+=1;
						//return 1;
					}
					
					// convert values (considering leap-year):
					clm_data[clm_index] = (nc_data[nc_index] + offset)*convert;
					if(leap_yr == 0 || day != 59) clm_day++;
					if(leap_yr == 1 && day == 59 && !is_equal(nc_data[nc_index], fill_value)) {
						for(febday=31; febday<59; febday++) 
							clm_data[cell*365+febday] += (nc_data[nc_index]/28+offset)*convert;
					}
					
					// Test: are nc-data in range of short-type:
					if( ((nc_data[nc_index] + offset)*convert < SHRT_MIN || (nc_data[nc_index] + offset)*convert > SHRT_MAX) && !is_equal(nc_data[nc_index], fill_value) && writefloat==0){
						if(!filename_mentioned) {
							fprintf(stderr, "File: %s\n", argv[file+2]);
							filename_mentioned=1;
						}
						fprintf(stderr, "clm_data values out of range of short-type (lon %i (%.2f°), lat %i (%.2f°), cell: %d, day: %d, year: %d, converted clm-value: %f)\n", ilon[cell], grid_data[cell*2]*grid_header->scalar, ilat[cell], grid_data[cell*2+1]*grid_header->scalar , cell, day, firstyear+year, (nc_data[nc_index] + offset)*convert);
						range_error += 1;
						//return 1;
					}
					
				} // end of day-loop
				
			} // end of cell-loop
			
			/* prepare "writedata": */
			for(cell=0; cell < ncells*365; cell++) {
				clm_writedata_short[cell] = (short)roundf(clm_data[cell]);
				if(clm_data[cell] < fieldmin)
					fieldmin=clm_data[cell];
				if(clm_data[cell] > fieldmax)
					fieldmax=clm_data[cell];
			} // end of cell-loop
			if(fieldmax*scalar > 1e-1)
  			fprintf(stdout, "\t\tData range in field: %.2f - %.2f\n", writefloat ? fieldmin*scalar : roundf(fieldmin)*scalar, writefloat ? fieldmax*scalar : roundf(fieldmax)*scalar);
  		else if(fieldmax*scalar > 1e-3)
  			fprintf(stdout, "\t\tData range in field: %.4f - %.4f\n", writefloat ? fieldmin*scalar : roundf(fieldmin)*scalar, writefloat ? fieldmax*scalar : roundf(fieldmax)*scalar);
  		else
  			fprintf(stdout, "\t\tData range in field: %.8f - %.8f\n", writefloat ? fieldmin*scalar : roundf(fieldmin)*scalar, writefloat ? fieldmax*scalar : roundf(fieldmax)*scalar);
			
			// write clm-file:
      if(writefloat) {
        fwrite(clm_data, sizeof(float), ncells*365, clm_file);
      } else {
        fwrite(clm_writedata_short, sizeof(short), ncells*365, clm_file);
      }
			start[0] += (size_t) time_len;   
			
		} // end of "year"-loop
		
		// update firstyear of next NetCDF-file and count all years in clm-file:
		firstyear+=number_yr;
		all_years +=number_yr;
		
		// close file and free allocated memory:
		status = nc_close(ncid);
		free(nclon);
		free(nclat);
		free(nc_data);
		
		fprintf(stdout, "\t\t( current NetCDF done )\n");
	} // end of "file"-loop
	
	// rewrite nyears in clm-header:
	clm_header->nyear = all_years;
	fseek(clm_file, 7 ,SEEK_SET);
	fwrite(clm_header, sizeof(Header),1,clm_file);
	
	fclose(clm_file);
	fclose(grid_file);
	
	free(grid_header);
	free(grid_headername);
	free(clm_header);
	free(clm_data);
	free(clm_writedata_short);
	free(grid_data);
	free(ilon);
	free(ilat);
	if(grid_error) {
		fprintf(stdout, "\t\tProgram aborted prematurely because of grid error\n");
		fprintf(stderr, "Program aborted prematurely because of grid error\n");
	}
	if(file_error) {
		fprintf(stderr, "Program aborted prematurely because of NetCDF file error\n");
		fprintf(stdout, "\t\tProgram aborted prematurely because of NetCDF file error\n");
	}
	if(fill_error)
		fprintf(stdout, "\t\tProgram encountered %ld NAN or missing values.\n", fill_error);
	if(range_error)
		fprintf(stdout, "\t\tProgram encountered %ld values out of SHORT range, not incl. possible NAN or missing values\n", range_error);
	fprintf(stdout, "\t\t( end of program )\n\n");
	
	if(grid_error)
		return grid_error;
	if(file_error)
		return file_error;
	if(fill_error || range_error)
		return -1;
	return 0;
}

