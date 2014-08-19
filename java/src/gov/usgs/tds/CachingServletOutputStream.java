/*
 * This software is in the public domain because it contains materials that originally came
 * from the United States Geological Survey, an agency of the United States Department of Interior.
 * For more information, see the official USGS copyright policy at
 * http://www.usgs.gov/visual-id/credit_usgs.html#copyright
 */
package gov.usgs.tds;

import java.io.ByteArrayOutputStream;
import java.io.IOException;

import javax.servlet.ServletOutputStream;

/**
 * CachingServletOutputStream mirrors the function of a ServletOutputStream but keeps a copy
 * of the output in a ByteArrayOutputStream which can then be cached. The original ServletOutputStream
 * is returned to the user's browser.
 */
public class CachingServletOutputStream extends ServletOutputStream {

	private ServletOutputStream sos;

    private ByteArrayOutputStream cache;

	public CachingServletOutputStream( ServletOutputStream sos_) {
		super();

	    sos = sos_;
	    cache = new ByteArrayOutputStream();
	}

	@Override
	public  void write(byte[] b) throws IOException {
		sos.write(b);
		cache.write(b);
	}

	@Override
	public void write(byte[] b, int off,int len) throws IOException {
		sos.write(b,off,len);
		cache.write(b,off,len);
	}

	@Override
	public void write(int b) throws IOException {
		sos.write(b);
	    cache.write(b);
	}

	/**
	 * Return the copy of the image output
	 */
	public ByteArrayOutputStream getBuffer( )
    {
		return cache;
    }

}
