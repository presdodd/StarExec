package org.starexec.data.to;

public class Website extends Identifiable {
	private String url;
	private String name;
	
	/**
	 * @return the url of the website
	 */
	public String getUrl() {
		return url;
	}
	
	/**
	 * @param url the url to set for the website
	 */
	public void setUrl(String url) {
		this.url = url;
	}
	
	/**
	 * @return the display name of the website
	 */
	public String getName() {
		return name;
	}
	
	/**
	 * @param name the display name to set for the website
	 */
	public void setName(String name) {
		this.name = name;
	}
	
	@Override
	public String toString() {
		return String.format("<a href='%s'>%s</a>", url, name);
	}
}
