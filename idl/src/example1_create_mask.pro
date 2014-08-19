pro example1_create_mask
  ;This software is in the public domain because it contains materials that originally came from the 
  ;United States Geological Survey, an agency of the United States Department of Interior. For more 
  ;information, see the official USGS copyright policy at http://www.usgs.gov/visual-id/credit_usgs.html#copyright

  ;---------------Example 1------------------------------------------------
  ;This example uses the United State shape file that comes with IDL to determine which cells 
  ;in the NEX grid fall within each state. This creates a mask where the states FIPS codes for
  ;each state are assigned the encolsed grid cells. The state FIPS mask is then save as a 
  ;NetCDF file.
  ;------------------------------------------------------------------------

  exampleResourcesFolder = '/path/to/nccv_code_examples/idl/resources/'
  
  ;------------------------------------------------------------------------
  ;---------------Define the NEX grid--------------------------------------
  ncols=7025
  nrows=3105
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
  ;------------------------------------------------------------------------
  
  ;------------------------------------------------------------------------
  ;open shape file packaged with IDL 8.3 and get metadata
  ;Update the shapefile path for your IDL installation
  state_shape=OBJ_NEW('IDLffShape', '/Applications/exelis/idl83/resource/maps/shape/states.shp')
  state_shape->IDLffShape::GetProperty, N_ENTITIES=num_states
  state_shape->GetProperty, ATTRIBUTE_INFO=state_attr_info, ATTRIBUTE_NAMES=state_attr_names
  
  ;initialize variables to hold the state FIPS code, state name, the mask of FIPS code 
  ;and a count of how many grids are in each state
  state_fips = INTARR(num_states)
  state_names = STRARR(num_states)
  state_fips_mask = INTARR(ncols, nrows)
  grid_cell_count = fltarr(num_states)
  ;keep a special matrix enumerating the 1D index of each cell in the NEX matrix
  indexes_for_nex_grid = lindgen(ncols, nrows)
  
  ;loop over each state in the shape file
  FOR state_id=0, num_states-1 DO BEGIN
    ;get shape metadata and geometry
    state_attr = state_shape->IDLffShape::GetAttributes(state_id)
    state_entity = state_shape->IDLffShape::GetEntity(state_id)
    
    ;state FIPS code
    state_fips[state_id] = state_attr.ATTRIBUTE_2
    ;state name
    state_names[state_id] = state_attr.ATTRIBUTE_1
    
    print, "Find grid cells for "+state_names[state_id]
    
    ;states can be composed of multiple polygons, loop over each polygon
    cuts = [*state_entity.parts, state_entity.n_vertices]
    FOR k=0, state_entity.n_parts-1 DO BEGIN

      ;extract the lat/lon vertices for the current polygon
      lon_x = reform((*state_entity.vertices)[0, cuts[k]:cuts[k+1]-1])
      lat_y = reform((*state_entity.vertices)[1, cuts[k]:cuts[k+1]-1])

      ;define the polygon bounding box
      minX = min(lon_x)
      maxX = max(lon_x)
      minY = min(lat_y)
      maxY = max(lat_y)
      
      ;use the IDL where function to search for all latitudes and longitudes in the bounding box
      lonIndex = where(lon_center ge minX AND lon_center LE maxX, lon_count)
      latIndex = where(lat_center ge minY AND lat_center LE maxy, lat_count)
      
      ;make sure at least on latitude and longitude are found in the bounding box. Since the NEX grid is
      ;for the Continental US (CONUS) only, Alaska and Hawaii will not pass this test.
      if(lon_count GT 0 AND lat_count GT 0) then begin
        ;using the bounding box, subset the latitude, longitude and index matrices
        lon_center_2d_mini = lon_center_2d[lonIndex[0]:lonIndex[-1],latIndex[0]:latIndex[-1]]
        lat_center_2d_mini = lat_center_2d[lonIndex[0]:lonIndex[-1],latIndex[0]:latIndex[-1]]
        mask_indexes_mini = indexes_for_nex_grid[lonIndex[0]:lonIndex[-1],latIndex[0]:latIndex[-1]]
        
        ;the inside_object function calls IDLs' IDLanROI.containspoints routine to determine if the grid cell 
        ;centers are within the current polygon. If the function returns greater than 0, the cell is within 
        ;the polygon 
        inside_object, lon_x,lat_y,lon_center_2d_mini,lat_center_2d_mini,hits
        
        ;use the IDL where function to search for the cells that are found to be within the polygon
        hitIndex = where(hits ge 1, hitCount)
        if(hitcount GT 0) then begin
          ;using the subset grid of indexes, we can assign the FIPS code to to the correct cells in the full mask matrix
          state_fips_mask[mask_indexes_mini[hitIndex]] = state_fips[state_id]
          ;keep track of the number of grid cells in this polygon/state
          grid_cell_count[state_id] += hitCount
        endif
      endif
    ENDFOR
  ENDFOR
  
  ;------------------------------------------------------------------------
  ;-----Remove any states outside CONUS and sort them by FIPS code----------
  index = where(grid_cell_count GT 0, num_conus_states) 
  state_fips = state_fips[index]
  state_names = state_names[index]
  
  ;sort by FIPS
  sort_index = SORT(state_fips)
  state_fips = state_fips[sort_index]
  state_names = state_names[sort_index]
  
  state_name_max_length = max(strlen(state_names))
  ;------------------------------------------------------------------------
  
  ;------------------------------------------------------------------------
  ;-----------Save the resulting FIPS mask to a NetCDF file----------------
  ncid1=ncdf_create(exampleFolder+"state_mask.nc", /CLOBBER)
  
  xDim=NCDF_DIMDEF(ncid1,'lon',ncols)
  yDim=NCDF_DIMDEF(ncid1,'lat',nrows)
  
  stateDim=NCDF_DIMDEF(ncid1,'state',num_conus_states)
  stateNameLenDim=NCDF_DIMDEF(ncid1,'state_name_len',state_name_max_length)

  latID = NCDF_VARDEF(ncid1,'lat',[ydim], /FLOAT)
  NCDF_ATTPUT, ncid1, latID, 'long_name', "latitude"
  NCDF_ATTPUT, ncid1, latID, 'units', "degrees_north"
  NCDF_ATTPUT, ncid1, latID, "actual_range" , [min(lat_center), max(lat_center)], LENGTH=2, /FLOAT

  lonID = NCDF_VARDEF(ncid1,'lon',[xdim], /FLOAT)
  NCDF_ATTPUT, ncid1, lonID, 'long_name', "lonitude"
  NCDF_ATTPUT, ncid1, lonID, 'units', "degrees_east"
  NCDF_ATTPUT, ncid1, lonID, "actual_range" , [min(lon_center), max(lon_center)], LENGTH=2, /FLOAT

  state_name_ID = NCDF_VARDEF(ncid1,'state',[stateNameLenDim, stateDim], /CHAR)
  NCDF_ATTPUT, ncid1, state_name_ID, "units"," "
  NCDF_ATTPUT, ncid1, state_name_ID, "missing_value"," " ;
  NCDF_ATTPUT, ncid1, state_name_ID, "long_name","state_name"
  
  state_fips_ID = NCDF_VARDEF(ncid1,'state_fips',[stateDim], /SHORT)
  NCDF_ATTPUT, ncid1, state_fips_ID, "units"," "
  NCDF_ATTPUT, ncid1, state_fips_ID, "missing_value"," " ;
  NCDF_ATTPUT, ncid1, state_fips_ID, "long_name","state_fips" 
  
  state_fips_mask_ID = NCDF_VARDEF(ncid1,'state_fips_mask',[xDim, yDim], /SHORT)
  NCDF_ATTPUT, ncid1, state_fips_mask_ID, 'long_name', "State FIPS Mask"
  NCDF_ATTPUT, ncid1, state_fips_mask_ID, "missing_value" , 0, /SHORT

  NCDF_ATTPUT, ncid1, "Conventions","CF-1.6", /GLOBAL
  NCDF_ATTPUT, ncid1, "standard_name_vocabulary","CF-1.6" , /GLOBAL
  NCDF_ATTPUT, ncid1, "creation_date", SYSTIME(), /GLOBAL

  ncdf_control, ncid1, /endef
  
  NCDF_VARPUT, ncid1, latID, lat_center
  NCDF_VARPUT, ncid1, lonID, lon_center
  NCDF_VARPUT, ncid1, state_name_ID, state_names
  NCDF_VARPUT, ncid1, state_fips_ID, state_fips
  NCDF_VARPUT, ncid1, state_fips_mask_ID, state_fips_mask
  
  ;close the NetCDF file and shape file
  ncdf_close,ncid1
  OBJ_DESTROY, state_shape

end