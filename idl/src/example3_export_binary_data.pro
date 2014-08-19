pro example3_export_binary_data
  ;This software is in the public domain because it contains materials that originally came from the
  ;United States Geological Survey, an agency of the United States Department of Interior. For more
  ;information, see the official USGS copyright policy at http://www.usgs.gov/visual-id/credit_usgs.html#copyright

  ;---------------Example 3------------------------------------------------
  ;This example exports climatology information for each state from the time
  ;series NetCDF file created in Example 2 and saves them into a compressed
  ;binary file. The time periods are for: 1950-2005, 2025-2049, 2050-2074 
  ;and 2075-2099.
  ;------------------------------------------------------------------------

  exampleResourcesFolder = '/path/to/nccv_code_examples/idl/resources/'
  modelName = 'ACCESS1-0'
  experiment = 'rcp85'
  variable = 'tasmax'
  inputFile = exampleResourcesFolder+modelName+"_"+experiment+"_"+variable+".nc"
  outputFile = exampleResourcesFolder+modelName+"_"+experiment+"_"+variable+".bin"
  
  ;------------------------------------------------------------------------
  climatologyYear1 = [1950,2025,2050,2075]
  climatologyYear2 = [2005,2049,2074,2099]
  ;------------------------------------------------------------------------
  
  ;------------Load data file from example #2------------------------------
  ncid0=ncdf_open(inputFile, /nowrite)
  NCDF_VARGET, ncid0, variable,var_data
  NCDF_VARGET, ncid0, "time",time
  NCDF_VARGET, ncid0, "state_fips",state_fips
  ncdf_close,ncid0
  
  ;-----------convert julian days to month, day, year----------------------
  baseData = JULDAY(1,1,1950)
  CALDAT, time+baseData, month, day, year
  
  ;-------create variable to hold the climatolgy mean for each state-------
  data_mean = FLTARR(N_ELEMENTS(state_fips), N_ELEMENTS(climatologyYear1), 12)
  
  ;-----------loop over all experiments time perids------------------------
  for timeid = 0L, N_ELEMENTS(climatologyYear1)-1 do begin
    
    ;-----------find the date indicies for the future experiment-------------
    climatologyIndexes = where(year GE climatologyYear1[timeid] AND year LE climatologyYear2[timeid])

    ;-----------loop over all states-----------------------------------------
    for stateid = 0L, N_ELEMENTS(state_fips)-1 do begin

      ;extract historic and future data for this state
      thisStateData = reform(var_data[stateid,*])
      thisStateData = thisStateData[climatologyIndexes]
      
      ;reshape time series data to a 2D matrix by month (i.e. [12, 25])
      thisStateData_monthly = REFORM(thisStateData, [12, N_ELEMENTS(climatologyIndexes)/12])
      
      ;calculate the climatogical average for each month
      thisStateData_monthly_avg = mean(thisStateData_monthly, DIMENSION=2)
      
      ;store the resuling average in our data_mean variable
      data_mean[stateid, timeid, *] = thisStateData_monthly_avg
    endfor
  endfor

  

  ;get the size of the data dimensions (i.e. [49,4,12])
  data_size = size(data_mean,/DIMENSIONS)
  ;count the number of dimensions of the data (i.e. 3)
  num_dims = N_ELEMENTS(data_size)
  
  ;IDL uses column-major ordering for multidimensional arrays. To make reading the files in 
  ;Flex easier, we transpose the matrix.
  data_mean = TRANSPOSE(data_mean)
  
  ;in order to be able to compress the output file, the data must be reshaped to be a 1D vector.
  ;The format used here is [number of dimensions, size of each dimension, data]. Floating point 
  ;values are converted to integers (IDL fix function) and multiplied by 10. The client software
  ;that reads these data must divid by 10 to recreate the original value. 
  dataChunk = fix([num_dims,data_size,reform(data_mean, [N_ELEMENTS(state_fips) * (N_ELEMENTS(climatologyYear1)) * 12])*10])
  
  ;-----------write out compressed binary file-----------------------------
  ;-----------ZLIB compression is used without header metadata-------------
  GET_LUN, lun1
  OpenW, lun1, outputFile
  writeu, lun1, ZLIB_COMPRESS(dataChunk, /NO_HEADER)
  CLOSE,lun1 
  FREE_LUN, lun1
  

end