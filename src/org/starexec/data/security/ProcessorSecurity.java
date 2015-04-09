package org.starexec.data.security;

import java.util.List;

import org.starexec.constants.R;
import org.starexec.data.database.Permissions;
import org.starexec.data.database.Processors;
import org.starexec.data.database.Solvers;
import org.starexec.data.database.Users;
import org.starexec.data.to.Permission;
import org.starexec.data.to.Processor;
import org.starexec.data.to.Solver;
import org.starexec.util.Validator;

public class ProcessorSecurity {
	
	
	/** 
	 * Checks to see whether the given user is allowed to delete the given processor
	 * @param procId The ID of the processor being checked
	 * @param userId The ID of the user making the request
	 * @return new ValidatorStatusCode(true) if the operation is allowed and a status code from ValidatorStatusCodes otherwise
	 */
	public static ValidatorStatusCode canUserDeleteProcessor(int procId, int userId) {
		Processor p = Processors.get(procId);
		
		// Permissions check; ensures user is the leader of the community that owns the processor
		Permission perm = Permissions.get(userId, p.getCommunityId());	
		if(perm == null || !perm.isLeader()) {
			return new ValidatorStatusCode(false, "You do not have permission delete the selected processor");
		}
		return new ValidatorStatusCode(true);
		
	}
	/** 
	 * Checks to see whether the given user is allowed to delete all of the given processors
	 * @param procId The IDs of the processors being checked
	 * @param userId The ID of the user making the request
	 * @return new ValidatorStatusCode(true) if the operation is allowed and a status code from ValidatorStatusCodes otherwise
	 * If the user lacks the necessary permissions for even one solver, a status code will be returned
	 */
	public static ValidatorStatusCode canUserDeleteProcessors(List<Integer> procIds, int userId) {
		for (Integer id : procIds) {
			ValidatorStatusCode status=canUserDeleteProcessor(id,userId);
			if (!status.isSuccess()) {
				return status;
			}
		}
		return new ValidatorStatusCode(true);
	}
	
	/** 
	 * Checks to see whether the given user is allowed to edit the given processor
	 * @param procId The ID of the processor being checked
	 * @param userId The ID of the user making the request
	 * @return new ValidatorStatusCode(true) if the operation is allowed and a status code from ValidatorStatusCodes otherwise
	 */
	
	public static ValidatorStatusCode canUserEditProcessor(int procId, int userId) {
		Processor p=Processors.get(procId);
		Permission perm= Permissions.get(userId,p.getCommunityId());
		if (perm==null || !perm.isLeader()) {
			return new ValidatorStatusCode(false, "You do not have permission edit the selected processor");
		}		
		
		return new ValidatorStatusCode(true);
	}
	
	/** 
	 * Checks to see whether the given user is allowed to edit the given processor
	 * @param procId The ID of the processor being checked
	 * @param userId The ID of the user making the request
	 * @return new ValidatorStatusCode(true) if the operation is allowed and a status code from ValidatorStatusCodes otherwise
	 */
	
	public static ValidatorStatusCode canUserEditProcessor(int procId, int userId, String name, String desc) {
		Processor p=Processors.get(procId);
		Permission perm= Permissions.get(userId,p.getCommunityId());
		if (perm==null || !perm.isLeader()) {
			return new ValidatorStatusCode(false, "You do not have permission edit the selected processor");
		}
		if(!Validator.isValidProcessorName(name)){
			return new ValidatorStatusCode(false, "The given name is not formatted correctly. Please refer to the help pages to see the proper format");
		}
		
		if( !Validator.isValidPrimDescription(desc)){
			return new ValidatorStatusCode(false, "The given description is not formatted correctly. Please refer to the help pages to see the proper format");
		}
		
		return new ValidatorStatusCode(true);
	}
	
	public static ValidatorStatusCode canUserSeeProcessor(int procId, int userId) {
		Processor p=Processors.get(procId);
		if (p==null) {
			return new ValidatorStatusCode(false, "The given processor could not be found");
		}
		
		if (!Users.isAdmin(userId) && procId!=R.NO_TYPE_PROC_ID && !Users.isMemberOfCommunity(userId, p.getCommunityId())) {
			return new ValidatorStatusCode(false, "You do not have permission to see the given processor");
		}
		
		return new ValidatorStatusCode(true);
		
	}
	
	/**
	 * Checks to see whether the user is allowed to download the Json object representing the solver
	 * @param procId
	 * @param userId
	 * @return
	 */
	public static ValidatorStatusCode canGetJsonProcessor(int procId, int userId) {
		
		ValidatorStatusCode status=canUserSeeProcessor(procId,userId);
		if (!status.isSuccess()) {
			return status;
		}
		return new ValidatorStatusCode(true);
	}
}
