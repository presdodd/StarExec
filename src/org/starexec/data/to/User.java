package org.starexec.data.to;

import java.sql.Timestamp;

/**
 * Represents a user in the database
 * 
 * @author Tyler Jensen
 */
public class User extends Identifiable {
	private String email;
	private String firstName;
	private String lastName;
	private String institution;	
	private String role;
	private Timestamp createDate;	
	private transient String password;		
	
	/**
	 * @return the user's registered email address
	 */
	public String getEmail() {
		return email;
	}

	/**
	 * @param email the email address to set
	 */
	public void setEmail(String email) {
		this.email = email;
	}

	/**
	 * @return the user's first name
	 */
	public String getFirstName() {
		return firstName;
	}

	/**
	 * @param firstName the first name to set for the user
	 */
	public void setFirstName(String firstName) {
		this.firstName = firstName;
	}

	/**
	 * @return the user's last name
	 */
	public String getLastName() {
		return lastName;
	}

	/**
	 * @param lastName the last name to set for the user
	 */
	public void setLastName(String lastName) {
		this.lastName = lastName;
	}

	/**
	 * @return the institution the user belongs to
	 */
	public String getInstitution() {
		return institution;
	}

	/**
	 * @param institution the institution to set for the user
	 */
	public void setInstitution(String institution) {
		this.institution = institution;
	}
	
	/**
	 * @return the role of the user
	 */
	public String getRole() {
		return role;
	}

	/**
	 * @param role the role to set for the user
	 */
	public void setRole(String role) {
		this.role = role;
	}

	/**
	 * @return the date the user joined the system
	 */
	public Timestamp getCreateDate() {
		return createDate;
	}

	/**
	 * @param createDate the date to set when the user joined the system
	 */
	public void setCreateDate(Timestamp createDate) {
		this.createDate = createDate;
	}

	/**
	 * @return the user's password
	 */
	public String getPassword() {
		return password;
	}

	/**
	 * @param password to set for the user
	 */
	public void setPassword(String password) {
		this.password = password;
	}

	/**
	 * @return the user's first and last name with a space in between
	 */
	public String getFullName() {
		return firstName + " " + lastName;
	}
	
	@Override
	public String toString() {
		return this.getFullName();
	}
}