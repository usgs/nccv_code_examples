/*
This software is in the public domain because it contains materials that originally came from the 
United States Geological Survey, an agency of the United States Department of Interior. For more 
information, see the official USGS copyright policy at http://www.usgs.gov/visual-id/credit_usgs.html#copyright
*/
package gov.usgs.nccv.examples
{
	import flash.utils.ByteArray;
	
	/**
	 * Sample utility for reading mutlidimensional data written by IDL 
	 */	
	public class BinaryUtils
	{
		/**
		 * readBinaryData() reads the data array dimensions and reads the data from binary file
		 * @param data raw binary data stored in a ByteArray
		 * @param scalar floating point number to scale the binary data by if scalars were used in IDL
		 * @return parsed mutlidimensional array
		 * 
		 */
		public static function readBinaryData(data:ByteArray, scalar:Number=1.0):Array
		{
			//get the number of dimensions stored in the binary file
			var numDims:uint = data.readShort();
			
			//get the size of each dimension
			var dimSizes:Array = new Array(numDims);
			for(var i:int=0; i<numDims; i++)
			{
				dimSizes[i] = data.readShort();
			}
			
			//recursively create the mutlidimensional array (i.e. of size [48,4,12])
			var arr:Array = recursivelyCreateArray(dimSizes);
			//recursively read binary data stored in row-major order
			recursivelyReadBinary(data, dimSizes, arr, scalar, 0);
			
			//returned the parsed data
			return arr;
		}
		
		/**
		 * Recursively create a multidimensional array of the correct size.
		 * @param dimSizes the size of each dimension
		 * @param depthIndex the current level of recursion
		 * @return the newly created empty array
		 * 
		 */
		public static function recursivelyCreateArray(dimSizes:Array, depthIndex:uint=0):Array
		{
			if(depthIndex < dimSizes.length)
			{
				var arr:Array = new Array(dimSizes[depthIndex]);
				for(var i:uint=0; i< dimSizes[depthIndex]; i++)
				{
					arr[i]  = recursivelyCreateArray(dimSizes, depthIndex+1);
				}
			}
			
			return arr;
		}
		
		/**
		 * Recursively read binary data stored in row-major order
		 * @param data the binary data
		 * @param dimSizes the size of each dimension
		 * @param arr the resulting parsed data array
		 * @param scalar floating point number to scale the binary data by if scalars were used in IDL
		 * @param depthIndex the current level of recursion
		 * 
		 */
		public static function recursivelyReadBinary(data:ByteArray, dimSizes:Array, arr:Array=null, scalar:Number=1.0,depthIndex:uint=0):void
		{
			for(var i:uint=0; i< dimSizes[depthIndex]; i++)
			{
				if(depthIndex == dimSizes.length-1)
				{
					//if this is the last dimension, read the binary data and scale it
					arr[i] = data.readShort()*scalar;
				}
				else
				{
					//if this is not the last dimension, recurse
					recursivelyReadBinary(data, dimSizes, arr[i], scalar, depthIndex+1);
				}
				
			}
		}
	}
}