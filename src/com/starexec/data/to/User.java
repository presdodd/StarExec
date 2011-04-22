package com.starexec.data.to;

import java.util.Date;

/**
 * Class which represents a user.
 * This directly corresponds with the user table in the database.
 * @author Tyler Jensen 
 */
public class User {
	private int userid = -1;
	private String username;
	private String password;
	private String firstName;
	private String lastName;
	private String affiliation;
	private Date createDate;
	private String email;
	private boolean verified;
	
	public User(int userid, String username){
		this.userid = userid;
		this.username = username;
	}
	
	public User(String username){	
		this.username = username;
	}
	
	public String getFirstName() {
		return firstName;
	}
	public void setFirstName(String firstName) {
		this.firstName = firstName;
	}
	public String getLastName() {
		return lastName;
	}
	public void setLastName(String lastName) {
		this.lastName = lastName;
	}
	public String getAffiliation() {
		return affiliation;
	}
	public void setAffiliation(String affiliation) {
		this.affiliation = affiliation;
	}
	public Date getCreateDate() {
		return createDate;
	}
	public String getEmail() {
		return email;
	}
	public void setEmail(String email) {
		this.email = email;
	}
	public boolean isVerified() {
		return verified;
	}
	public int getUserId() {
		return userid;
	}
	public String getUsername() {
		return username;
	}	
	public String getPassword() {
		return password;
	}
	public void setPassword(String password) {
		this.password = password;
	}
	public String getFullName() {
		return firstName + " " + lastName;
	}
}