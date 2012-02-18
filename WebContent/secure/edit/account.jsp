<%@page contentType="text/html" pageEncoding="UTF-8" import="org.apache.commons.io.*, java.util.List, org.starexec.data.database.*, org.starexec.data.to.*, org.starexec.util.*, org.starexec.data.to.Processor.ProcessorType" session="true"%>
<%@taglib prefix="star" tagdir="/WEB-INF/tags" %>
<%@taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%
	try {
		User user = SessionUtil.getUser(request);
		long disk_usage = Users.getDiskUsage(user.getId());
		
		request.setAttribute("diskQuota", FileUtils.byteCountToDisplaySize(user.getDiskQuota()));
		request.setAttribute("diskUsage", FileUtils.byteCountToDisplaySize(disk_usage));
	} catch (Exception e) {
		response.sendError(HttpServletResponse.SC_BAD_REQUEST);
	}
%>
<star:template title="edit account" css="edit/account" js="lib/jquery.validate.min, lib/jquery.validate.password, edit/account, lib/jquery.dataTables.min">
	<p>review and edit your account details here.</p>
	<fieldset>
		<legend>personal information</legend>
		<table id="personal">
			<tr>
				<th class="label">attribute</th>
				<th>current value</th>
			</tr>
			<tr>
				<td>first name </td>
				<td id="editfirstname">${user.firstName}</td>
			</tr>
			<tr>
				<td>last name</td>
				<td id="editlastname">${user.lastName}</td>
			</tr>
			<tr>
				<td>institution </td>
				<td id="editinstitution">${user.institution}</td>
			</tr>
			<tr>
				<td>email </td>
				<td>${user.email}</td>
			</tr>
		</table>
		<h6>(click the current value of an attribute to edit it; email addresses are currently not editable)</h6>
	</fieldset>
	<fieldset>
		<legend>associated websites</legend>
		<table id="websites" class="shaded"></table>
		<span id="toggleWebsite" class="caption"><span>+</span> add new</span>
		<div id="new_website">
			name: <input type="text" id="website_name" /> 
			url: <input type="text" id="website_url" /> 
			<button id="addWebsite">add</button>
		</div>
	</fieldset>
	<fieldset>
		<legend>user disk quota</legend>
		<table id="diskUsageTable" class="shaded">
			<tr>
				<td>disk quota</td>
				<td><input type="text" readonly="readonly" value="${diskQuota}"/></td>
			</tr>
			<tr>
				<td>current disk usage</td>
				<td><input type="text" readonly="readonly" value="${diskUsage}"/></td>
			</tr>
		</table>
	</fieldset>
	<fieldset>
		<legend>password</legend>
		<form id="changePassForm">
			<table id="passwordTable" class="shaded">
				<tr>
					<td>current password</td>
					<td><input type="password" id="current_pass" name="current_pass"/></td>
				</tr>
				<tr>
					<td>new password</td>
					<td>
						<input type="password" id="password" name="pwd"/>
						<div class="password-meter" id="pwd-meter" style="visibility:visibile">
							<div class="password-meter-message"> </div>
							<div class="password-meter-bg">
								<div class="password-meter-bar"></div>
							</div>
						</div>
					</td>
				</tr>
				<tr>
					<td>re-enter new password</td>
					<td><input type="password" id="confirm_pass" name="confirm_pass"/></td>
				</tr>
				<tr></tr>
				<tr>
					<td colspan="2"><button id="changePass">change</button></td>
				</tr>
			</table>
		</form>
	</fieldset>
	<!--   <fieldset>
		<legend>misc.</legend>
		<table id="misc">
			<tr>
				<td>preferred archive type</td>
				<td>
					<select id="selectArchive">
						<option value=".zip">.zip</option>
						<option value=".tar">.tar</option>
						<option value=".tar.gz">.tar.gz</option>
					</select>
				</td>
			</tr>
		</table>
	</fieldset> -->
</star:template>