/*
 * This software is in the public domain because it contains materials that originally came
 * from the United States Geological Survey, an agency of the United States Department of Interior.
 * For more information, see the official USGS copyright policy at
 * http://www.usgs.gov/visual-id/credit_usgs.html#copyright
 *
 * Example 5: sample implementation of a memcached filter that is added to the Thredds software stack.
 * The filter intercepts WMS requests prior to ncWMS execution, which allows us to cache maps.
 */
package gov.usgs.tds;

import java.io.IOException;
import java.security.MessageDigest;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.codec.binary.Base64;

import net.rubyeye.xmemcached.MemcachedClient;
import net.rubyeye.xmemcached.MemcachedClientBuilder;
import net.rubyeye.xmemcached.XMemcachedClientBuilder;
import net.rubyeye.xmemcached.utils.AddrUtil;

/**
 * Servlet Filter implementation class XMemcacheFilter
 */
@WebFilter("/XMemcacheFilter")
public class XMemcacheFilter implements Filter
{
	/**
	 * XMemcached connection client that will be used for the life span of the Filter
	 */
	public MemcachedClient client;

	/**
	 * Default constructor.
	 */
	public XMemcacheFilter(){
	}

	/**
	 * When the Filter is initialized, create a memcached client that uses a connection pool of 20
	 * @see Filter#init(FilterConfig)
	 */
	public void init(FilterConfig fConfig) throws ServletException
	{
		try {
			//set up a connection to a memcached server running at localhost port 11211
			MemcachedClientBuilder builder = new XMemcachedClientBuilder(AddrUtil.getAddresses("localhost:11211"));
			//set connection pool size to twenty
		    builder.setConnectionPoolSize(20);
		    //create connection and build client
		    client= builder.build();

		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	/**
	 * When the Filter is destroyed, shutdown the memcached connection
	 * @see Filter#destroy()
	 */
	public void destroy() {
		try {
			client.shutdown();
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	/**
	 * Intercept WMS GetMap requests, test to see if the url has been previously cached,
	 * if not, create the map via ncWMS and add the resulting image into memcached
	 * @see Filter#doFilter(ServletRequest, ServletResponse, FilterChain)
	 */
	public void doFilter(ServletRequest request, ServletResponse response,
			FilterChain chain) throws IOException, ServletException {

		try {

			//get the WMS request argument, regardless of case
			String wmsRequest = request.getParameter("request");
			if (wmsRequest == null)
				wmsRequest = request.getParameter("REQUEST");

			// only proceed with caching if the request is for a map / not an info request or legend
			if (wmsRequest != null && wmsRequest.equals("GetMap")) {

				HttpServletRequest httpServletRequest = (HttpServletRequest) request;
				HttpServletResponse httpServletResponse = (HttpServletResponse) response;

				//get WMS map format, regardless of case
				String wmsformat = request.getParameter("format");
				if (wmsformat == null)
					wmsformat = request.getParameter("FORMAT");

				// build full requesting URL
				StringBuffer cacheKeyBuffer = new StringBuffer();
				cacheKeyBuffer.append(httpServletRequest.getRequestURL());
				if (httpServletRequest.getQueryString() != null) {
					cacheKeyBuffer.append("?");
					cacheKeyBuffer.append(httpServletRequest.getQueryString());
				}

				//MD5 hash and Base64 encode request URL to be used as the cache key
				MessageDigest md = MessageDigest.getInstance("MD5");
				String cacheKey = new String(Base64.encodeBase64(md.digest(cacheKeyBuffer.toString().getBytes())));

				try {
					//test if the key (ie url) is in memcache (time out after 500ms)
					String value = (String) client.get(cacheKey,500);

					// key is not in memcache
					if (value == null) {
						// use custom response wrapper to get a copy of the returning image
						TDSCachingHttpServletResponseWrapper cachingResponseWrapper = new TDSCachingHttpServletResponseWrapper(httpServletResponse);

						//create the map using ncWMS
						chain.doFilter(httpServletRequest,cachingResponseWrapper);

						// if the map was correctly created / ie HTTP 200
						if (cachingResponseWrapper.getRequestStatus() == HttpServletResponse.SC_OK) {
							// cast OutputStream to CachingServletOutputStream
							CachingServletOutputStream csos = (CachingServletOutputStream) cachingResponseWrapper.getOutputStream();

							// get image byte array and Base64 encode image
							value = new String(Base64.encodeBase64(csos.getBuffer().toByteArray()));

							// put image in memcache
							client.set(cacheKey, 0, value);
						} else {
							// do nothing for maps that returned errors
						}
					}
					// key is in already in memcached
					else {
						//set content output type to WMS map format
						httpServletResponse.setContentType(wmsformat);
						// Base64 decode image string and write to output stream
						httpServletResponse.getOutputStream().write(Base64.decodeBase64(value.getBytes()));
					}
				} catch (Exception e) {
					//Memcached either timed out or threw an error. Send map reqest to ncWMS so an uncached
					//map is still returned
					System.out.println("Memcached timed out. Get non-cached map."); //replace with better logging
					chain.doFilter(request, response);
				}

			} else {
				// not a GetMap request, so don't cache (could be GetCapabilities)
				chain.doFilter(request, response);
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
