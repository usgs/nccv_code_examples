nccv_code_examples
==================

National Climate Change Viewer Code Examples

--------------

The following examples demonstrate key aspects of the data processing,
data exporting/importing for a web client and map caching used in the
implementation of the USGS National Climate Change Viewer. These examples
were developed in Exelis IDL for NetCDF data processing and analysis, Apache
Flex for web-based visualization and Java for caching maps within the Unidata
THREDDS Data Server software stack.

IDL Data processing examples 
Example 1 demonstrates how to use the US States shape file packaged with IDL to 
create a 30-arcsecond mask that assigns all the grid cells within each state to 
the states FIPS code. This mask is used to determine which states are enclosed by
a given state.

Example 2 demonstrates how to create monthly time series of state averages
using the NASA NEX-DCP30 climate data set.  This example uses the mask
created in Example 1 to calculate area-weighted state averages from
1950-2099 for each state and store them as a Discrete Sampling Geometry
NetCDF time series. The example uses maximum temperature for the ACCESS1-0
model, but the code can easily be modified for different variables or
models. In order to run the example, data should be downloaded from:
http://portal.nccs.nasa.gov/portal_home/published/NEX.html

Example 3 shows how climatological averages for four time periods (1950-2005,
2025-2049, 2050-2074 and 2075-2099) are calculate and exported to a binary
file that can be read by Flex. The binary file contains averages of maximum
temperature from the ACCESS1-0 model for the states in the Continental US,
four climatology periods and 12 months. The resulting binary data file is a
multidimensional array with the size [49,4,12] and metadata for the size
of the array at the beginning of the file.

Flex binary data loading example
Example 4 reads the binary file exported in Example 3 and plots the seasonal 
cycle of maximum temperature from the ACCESS1-0 model for the four climatology 
periods. A utility is provided for parsing the binary files exported by IDL in 
Example 3. This example was developed with Apache Flex 4.6 SDK, but should also 
work in previous versions of Adobe Flex. A live version of this example can be 
found at: http://regclim.coas.oregonstate.edu/nccv_examples

Java Filter for caching maps with Memcached
The final example includes the Java source code for a web application filter that
is added to the Thredds software stack to intercept and cache maps using memcached
(http://memcached.org). To run this example you need to install the memcached
service and have a working version of Thredds (version 4.3 or higher). The
Java filter uses the XMemcached (http://code.google.com/p/xmemcached/) Java
library to interface with the memcached service. A Java IDE such as Eclipse,
NetBeans or IntelliJ is recommended for source code compilation.

Source code dependencies: 
xmemcached-2.0.0.jar (included here in the java/lib folder)
commons-codec-1.6.jar (included in the Thredds web application)
slf4j-api-1.7.5.jar (included in the Thredds web application)
servlet-api.jar(included in Tomcat installation)

Once compiled, the resulting class files should be copied to the thredds
web application at: /thredds/WEB-INF/classes/gov/usgs/tds/

The xmemcached-2.0.0.jar needs to be copied to the web application lib folder:
/thredds/WEB-INF/lib/

The Thredds web.xml file needs to be modified to enable the memcached filter:

Add the memcache file to the list of filters at the top of the file:
``` 
<filter>
   <filter-name>MemcacheFilter</filter-name>
   <filter-class>gov.usgs.tds.XMemcacheFilter</filter-class>
</filter>
```

Add the MemcacheFilter mapping to the top of the filter mapping list:
```
<filter-mapping>
   <filter-name>MemcacheFilter</filter-name>
   <servlet-name>wms</servlet-name>
</filter-mapping>
```

The Tomcat web server will need to restarted after the web.xml file has
been edited. 

