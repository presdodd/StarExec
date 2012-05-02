package org.starexec.servlets;

import java.awt.Graphics2D;
import java.awt.geom.AffineTransform;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.util.HashMap;

import javax.imageio.ImageIO;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.log4j.Logger;
import org.apache.tomcat.util.http.fileupload.FileItem;
import org.starexec.constants.R;
import org.starexec.util.SessionUtil;
import org.starexec.util.Util;

/**
 * This class is to handle the upload of a picture. Notice that this upload
 * will go straight into the file system instead of the database. When a
 * picture is uploaded, the original picture is stored along with a
 * shrunk one for the thumbnail.
 * @author Ruoyu Zhang
 *
 */
@SuppressWarnings("serial")
public class UploadPicture extends HttpServlet {
	private static final Logger log = Logger.getLogger(UploadPicture.class);	 
    
    // Request attributes
    private static final String PICTURE_FILE = "f";
    private static final String TYPE = "type";
    private static final String ID = "Id";
    
    /**
     * UploadPicture doesn't handle doGet request
     */
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
    	response.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED, "Wrong type of request.");
    }
    

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {    	
    	int userId = SessionUtil.getUserId(request);
    	try {	
			// Extract data from the multipart request
			HashMap<String, Object> form = Util.parseMultipartRequest(request);
			
			// If the request is valid
			if(this.isRequestValid(form)) {
				response.sendRedirect(this.handleUploadRequest(userId, form));
			} else {
				// Or else the request was invalid, send bad request error
				response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid picture upload request");
			}					
		} catch (Exception e) {
			log.error(e.getMessage(), e);
		}
	}
    
    /**
     * Upload the picture to the file system and return the redirection string.
     * @param userId The user uploading picture.
     * @param form the form submitted for the upload.
     * @return the redirection string.
     * @throws Exception
     */
	private String handleUploadRequest(int userId, HashMap<String, Object> form) throws Exception {
		try {
			FileItem item = (FileItem)form.get(UploadPicture.PICTURE_FILE);
			String fileName = "";
			String redir = "/starexec/secure/edit/account.jsp";
			
			String type = (String)form.get(UploadPicture.TYPE);
			String id = (String)form.get(UploadPicture.ID);
			StringBuilder sb = new StringBuilder();
			
			if (type.equals("user")) {
				sb.delete(0, sb.length());
				sb.append("/users/Pic");
				sb.append(id);
				fileName = sb.toString();
				redir = "/starexec/secure/edit/account.jsp";
			} else if (type.equals("solver")) {
				sb.delete(0, sb.length());
				sb.append("/solvers/Pic");
				sb.append(id);			
				fileName = sb.toString();
				
				sb.delete(0, sb.length());
				sb.append("/starexec/secure/details/solver.jsp?id=");
				sb.append(id);			
				redir = sb.toString();
			} else if (type.equals("benchmark")) {
				sb.delete(0, sb.length());
				sb.append("/benchmarks/Pic");
				sb.append(id);			
				fileName = sb.toString();
				
				sb.delete(0, sb.length());
				sb.append("/starexec/secure/details/benchmark.jsp?id=");
				sb.append(id);			
				redir = sb.toString();
			}
			
			sb.delete(0, sb.length());
			sb.append(R.PICTURE_PATH);
			sb.append(File.separator);
			sb.append(fileName);
			sb.append("_org.jpg");
	    	String filenameupload = sb.toString();  	

			File archiveFile = new File(filenameupload);
			item.write(archiveFile);

			sb.delete(0, sb.length());
			sb.append(R.PICTURE_PATH);
			sb.append(File.separator);
			sb.append(fileName);
			sb.append("_thn.jpg");
			String fileNameThumbnail = sb.toString();
			scale(filenameupload, 100, 120, fileNameThumbnail);
			
			return redir;
		} catch (Exception e) {
			log.error(e.getMessage(), e);
		}
		return null;	
	}
	
	/**
	 * Validates a picture upload request to determine if it can be acted on or not.
	 * @param form A list of form items contained in the request
	 * @return True if the request is valid to act on, false otherwise
	 */
	private boolean isRequestValid(HashMap<String, Object> form) {
		try {			
			if(!form.containsKey(PICTURE_FILE) ||
			   !form.containsKey(TYPE) ||
			   !form.containsKey(ID)) {
				return false;
			}			
		} catch (Exception e) {
			log.warn(e.getMessage(), e);
		}
		
		// Return true if no problem
		return true;	
	}
	
	/**
	 * Scale the source file into a shrunk one with the width and height
	 * specified in the parameter.
	 * @param srcFile The original source file need to shrink
	 * @param destWidth The width of the shrunk picture.
	 * @param destHeight The height of the shrunk picture.
	 * @param destFile The file of the shrunk picture.
	 * @throws IOException
	 */
	public static void scale(String srcFile, int destWidth, int destHeight, String destFile) throws IOException {
		
		BufferedImage src = ImageIO.read(new File(srcFile));
		BufferedImage dest = new BufferedImage(destWidth, destHeight, BufferedImage.TYPE_INT_RGB);
		Graphics2D g = dest.createGraphics();
		AffineTransform at = AffineTransform.getScaleInstance(
				(double)destWidth/src.getWidth(),
				(double)destHeight/src.getHeight());
		
		g.drawRenderedImage(src, at);
		ImageIO.write(dest,"JPG",new File(destFile));
		}
}
