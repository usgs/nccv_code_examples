pro example2_create_timeseries
  ;This software is in the public domain because it contains materials that originally came from the
  ;United States Geological Survey, an agency of the United States Department of Interior. For more
  ;information, see the official USGS copyright policy at http://www.usgs.gov/visual-id/credit_usgs.html#copyright

  ;---------------Example 2------------------------------------------------
  ;This example uses the state mask created in Example 1 and data from the 
  ;NEX-DCP30 dataset (which can be downloaded from http://esgf.nccs.nasa.gov).
  ;The example takes one model (ACCESS1-0) for one scenario (RCP8.5) and caclulates
  ;state area weighted average for Maximum Temperature for each state in the 
  ;Continental US (CONUS). State averages are caculated from 1950-2099.  
  ;------------------------------------------------------------------------

  modelName = 'ACCESS1-0'
  experiment = 'rcp85'
  variable = 'tasmax'
  exampleResourcesFolder = '/path/to/nccv_code_examples/idl/resources/'
  maskFile = exampleResourcesFolder+'state_mask.nc'
  outputFile = exampleResourcesFolder+modelName+"_"+experiment+"_"+variable+".nc"
  
  ;dataPath is where you've downloaded the NEX-DCP30 data for ACCESS1-0
  ;data subfolders should be: 
  ;/path/to/NEX-DCP30/data/ACCESS1-0/historical/
  ;/path/to/NEX-DCP30/data/ACCESS1-0/rcp85/
  dataPath = '/path/to/NEX-DCP30/data/'+modelName+'/'

  ;------------------------------------------------------------------------
  ;---------------Define the NEX grid--------------------------------------
  ncols=7025l
  nrows=3105l
  num_cells = nrows*ncols
  xllcorner=-125.02083333333
  yllcorner=24.06250000000
  cellsize=0.00833333333

  lat_lowerlelft = (FINDGEN(nrows) * cellsize) + yllcorner
  lon_lowerlelft = (FINDGEN(ncols) * cellsize) + xllcorner

  lat_center = lat_lowerlelft + cellsize*0.5
  lon_center = lon_lowerlelft + cellsize*0.5

  ;use the rebin/reform functions to reshape the lat/lons into a 2 dimensional matrix
  lon_center_2d = Rebin(lon_center, ncols, nrows, /SAMPLE)
  lat_center_2d = Rebin(Reform(lat_center, 1, nrows), ncols, nrows, /SAMPLE)
  ;calculate the cosine of the latitude, which will be used to will be used to calculate 
  ;the area weighted average
  cos_lat_center_2d = COS(lat_center_2d * !DTOR)

  ;------------------------------------------------------------------------
  ;--Load the state names, FIPS and FIPS mask from Example 1---------------
  ncid0=ncdf_open(maskFile, /nowrite)
  NCDF_VARGET, ncid0, "state_fips",state_fips
  NCDF_VARGET, ncid0, "state",state
  NCDF_VARGET, ncid0, "state_fips_mask",state_fips_mask
  ncdf_close,ncid0
  
  state = string(state)

  ;------------------------------------------------------------------------
  ;Loop over all states and find which grid cells are assigned to each state.
  ;The IDL Hash function is used here so we can save the indicies and weights
  ;rather than needing to calculate them multiple times
  stateIndexHash = Hash()
  stateWeightsHash = Hash()
  
  for i = 0L, N_ELEMENTS(state_fips)-1 do begin
    ;use the IDL where function to find the indicies for grid cells in each state
    index = where(state_fips_mask eq state_fips[i], count)
    if(count GT 0) then begin
      stateIndexHash[state[i]] = index
      ;using the cosine of the latitudes, create the weights to be used in the area weighted average
      stateWeightsHash[state[i]] = cos_lat_center_2d[index] / total(cos_lat_center_2d[index])
    endif
  endfor

  ;------------------------------------------------------------------------
  ;-- get a list of historical and RCP8.5 files for ACCESS1-0--------------
  ;/path/to/NEX-DCP30/data/ACCESS1-0/historical/
  ;/path/to/NEX-DCP30/data/ACCESS1-0/rcp85/
  historical_files = FILE_SEARCH( dataPath+"/historical/"+variable+"_*_??????-??????.nc")
  exp_files = FILE_SEARCH( dataPath+"/"+experiment+"/"+variable+"_*_??????-??????.nc")

  files = [historical_files, exp_files]
  ;define the dates
  outputDates = TIMEGEN(START=JULDAY(1,1,1950), FINAL=JULDAY(12,1,2099), UNITS='M')
  
  ;------------------------------------------------------------------------
  ;create the output NetCDF to store the area weighted time series for each state
  ncid1=ncdf_create(outputFile, /CLOBBER)
  timeDim=NCDF_DIMDEF(ncid1,'time',N_ELEMENTS(outputDates))
  stateDim=NCDF_DIMDEF(ncid1,'state',N_ELEMENTS(state_fips))
  
  time_ID = NCDF_VARDEF(ncid1,'time',[timeDim], /FLOAT)
  NCDF_ATTPUT, ncid1, time_ID, "axis","T"
  NCDF_ATTPUT, ncid1, time_ID, "long_name","time" ;
  NCDF_ATTPUT, ncid1, time_ID, "standard_name","time" ;
  NCDF_ATTPUT, ncid1, time_ID, "units","days since 1950-01-01 00:00:00"
  NCDF_ATTPUT, ncid1, time_ID, "calendar","standard"
  
  state_fips_ID = NCDF_VARDEF(ncid1,'state_fips',[stateDim], /SHORT)
  NCDF_ATTPUT, ncid1, state_fips_ID, "units"," "
  NCDF_ATTPUT, ncid1, state_fips_ID, "missing_value"," " ;
  NCDF_ATTPUT, ncid1, state_fips_ID, "long_name","state_fips"
  NCDF_ATTPUT, ncid1, state_fips_ID, "cf_role","timeseries_id" ;
  
  netcdf_var_ID = NCDF_VARDEF(ncid1,variable,[stateDim, timeDim], /FLOAT)
  NCDF_ATTPUT, ncid1, netcdf_var_ID, "_FillValue",1.0E20, /FLOAT
  NCDF_ATTPUT, ncid1, netcdf_var_ID, "missing_value",1.0E20, /FLOAT
  NCDF_ATTPUT, ncid1, netcdf_var_ID, "long_name","Daily Minimum Near-Surface Air Temperature";
  NCDF_ATTPUT, ncid1, netcdf_var_ID, "standard_name","air_temperature"
  NCDF_ATTPUT, ncid1, netcdf_var_ID, "units","K"
  
  NCDF_ATTPUT, ncid1, "Conventions","CF-1.6", /GLOBAL
  NCDF_ATTPUT, ncid1, "featureType","timeSeries", /GLOBAL
  NCDF_ATTPUT, ncid1, "cdm_data_type","Station", /GLOBAL
  NCDF_ATTPUT, ncid1, "standard_name_vocabulary","CF-1.6" , /GLOBAL
  NCDF_ATTPUT, ncid1, "creation_date", SYSTIME(), /GLOBAL
  
  ncdf_control, ncid1, /endef
  
  NCDF_VARPUT, ncid1, state_fips_ID, state_fips
  
  ;keep a counter of how many months have been loaded
  startTime = 0
  
  ;loop through all files to load the data and create the state average
  for fileid = 0L, N_ELEMENTS(files)-1 do begin
    
    ;open the file and read both the temperature data and the time stamps
    nc0=ncdf_open(files[fileid], /nowrite)
    NCDF_VARGET, nc0, "time",time
    time_size = N_ELEMENTS(time)
    print,"Start reading "+variable+" from "+files[fileid]
    NCDF_VARGET, nc0, variable,var_data
    ncdf_close,nc0

    ;create a temporary place for storing the state average time series. This is used so
    ;that we only need to save to NetCDF one per input file.
    temp_data = FLTARR(N_ELEMENTS(state_fips), time_size)
    
    ;loop over each state to create the area average for the current data. 
    ;The NEX-DCP30 data is generally stored in 5-yr files.
    for i = 0L, N_ELEMENTS(state_fips)-1 do begin
      
      ;restore the indicies and weights for the current state
      index = stateIndexHash[state[i]]
      weights = stateWeightsHash[state[i]]

      ;--------------this section is technical and IDL centric------------------
      ;reshape the indices for this state to be 2D so we can extract all the data
      ;for this state across the full 5 years in the file
      index2d = rebin(index, [N_ELEMENTS(index), time_size])
      
      ;the indicies calculated at the top of the file are for the first 'slice' (month) of data.
      ;We need to add an offset to the indicies in the 2nd dimension so we can address the full
      ;5 years of data.  
      offset = INDGEN(time_size)*num_cells
      offset2d = Rebin(Reform(offset, 1, time_size), N_ELEMENTS(index), time_size, /SAMPLE)
      index2d +=  offset2d
      
      ;reshape the weights for the area average to also be 2D, where time is the second dimension.
      weights2d = Rebin(weights, N_ELEMENTS(index), time_size)
      
      ;extract all the data for the state using the 2D indicies. It will be [N x 60], where N is 
      ;the number of grid cells in the state and 60 is 5-years of monthly data.
      data_slice = var_data[index2d]

      ;create the area weighted average. The result will be an array of 60 elements
      var_data_ts = total(data_slice * weights2d,1)
      
      ;put the resulting 5-yr state averages in the temporary storage
      temp_data[i,*] = var_data_ts
    endfor

    ;save the resulting state averages and time stamps into the NetCDF file
    NCDF_VARPUT, ncid1, netcdf_var_ID, temp_data, OFFSET=[0, startTime], COUNT=[N_ELEMENTS(state_fips), time_size]
    NCDF_VARPUT, ncid1, time_ID, time, OFFSET=[startTime], COUNT=[time_size]

    ;increament the time counter by 60
    startTime += time_size
    print,"Done reading: "+files[fileid]
  endfor
  
  ;close the output NetCDF file.
  ncdf_close,ncid1

end