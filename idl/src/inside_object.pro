;Simple function that wraps the IDLanROI.containspoints routine.

;-----------------------From IDL Documentation--------------------------------
;The IDLanROI::ContainsPoints function method determines whether the given data 
;coordinates are contained within the closed polygon region.
;
;The return value is a vector of values, one per provided point, indicating 
;whether that point is contained. Valid values within this return vector include:
;0 = Exterior. The point lies strictly out of bounds of the ROI
;1 = Interior. The point lies strictly inside the bounds of the ROI
;2 = On edge. The point lies on an edge of the ROI boundary
;3 = On vertex. The point matches a vertex of the ROI

pro inside_object,roi_x,roi_y,pt_x,pt_y,inside_val
 obj=obj_new('IDLanROI',roi_x,roi_y)
 inside_val=obj->containspoints(pt_x,pt_y)
 obj_destroy,obj
end 