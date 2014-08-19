/*
 * This software is in the public domain because it contains materials that originally came
 * from the United States Geological Survey, an agency of the United States Department of Interior.
 * For more information, see the official USGS copyright policy at
 * http://www.usgs.gov/visual-id/credit_usgs.html#copyright
 */
package gov.usgs.tds;

import java.io.IOException;
import java.io.PrintWriter;

import javax.servlet.ServletOutputStream;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;

/**
 * TDSCachingHttpServletResponseWrapper wraps the standard HttpServletResponseWrapper so we can inject
 * a CachingServletOutputStream, which will keep a copy of the returned WMS image byte array. We can
 * then cache the duplicate byte array while still returning the original outputstream to the user's
 * browser.
 */
public class TDSCachingHttpServletResponseWrapper extends
		HttpServletResponseWrapper {

	private int httpStatus;

	HttpServletResponse originalResponse;
	PrintWriter responseWriter;
	CachingServletOutputStream csos;

	public TDSCachingHttpServletResponseWrapper(HttpServletResponse response) {
		super(response);
		originalResponse = response;
	}

	@Override
	public PrintWriter getWriter() throws IOException {
		if(responseWriter == null)
		 responseWriter = originalResponse.getWriter();
		return responseWriter;
	}

	/*
	 * return a CachingServletOutputStream rather than standard ServletOutputStream
	 */
	@Override
	public ServletOutputStream getOutputStream() throws IOException {
		if(csos == null)
		{
			csos = new CachingServletOutputStream(super.getOutputStream());
		}
		return csos;
	}

	@Override
    public void setStatus(int sc) {
        httpStatus = sc;
        super.setStatus(sc);
    }

	public int getRequestStatus() {
        return httpStatus;
    }


}
