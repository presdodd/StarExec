package org.starexec.servlets;


import java.io.IOException;
import java.sql.Date;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import javax.servlet.ServletException;
import javax.servlet.http.Cookie;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.log4j.Logger;
import org.starexec.constants.R;
import org.starexec.data.database.Cluster;
import org.starexec.data.database.Queues;
import org.starexec.data.database.Requests;
import org.starexec.data.database.Spaces;
import org.starexec.data.database.Users;
import org.starexec.data.to.Benchmark;
import org.starexec.data.to.Configuration;
import org.starexec.data.to.Queue;
import org.starexec.data.to.QueueRequest;
import org.starexec.data.to.Solver;
import org.starexec.data.to.User;
import org.starexec.data.to.WorkerNode;
import org.starexec.util.GridEngineUtil;
import org.starexec.util.Mail;
import org.starexec.util.RobustRunnable;
import org.starexec.util.Util;
import org.starexec.util.Validator;


/**
 * Servlet which handles incoming requests adding new permanent queues
 * @author Wyatt Kaiser
 */
@SuppressWarnings("serial")
public class CreatePermanentQueue extends HttpServlet {		
	private static final Logger log = Logger.getLogger(AddSpace.class);	

	// Request attributes
	private static final String name = "name";
	//private static final String Nodes = "Nodes";
	private static final String nodes = "node";

	
	/**
	 * @see HttpServlet#doGet(HttpServletRequest request, HttpServletResponse response)
	 */
	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		response.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED);
	}

	/**
	 * @see HttpServlet#doPost(HttpServletRequest request, HttpServletResponse response)
	 */
	protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {	

		String queue_name = (String)request.getParameter(name);
		//String node_name = (String)request.getParameter(Nodes);
		List<Integer> nodeIds = Util.toIntegerList(request.getParameterValues(nodes));

	
		// Make sure that the queue has a unique name
		if(Queues.notUniquePrimitiveName(queue_name)) {
			response.sendError(HttpServletResponse.SC_BAD_REQUEST, "The requested queue name is already in use. Please select another.");
			return;
		}
		
		HashMap<WorkerNode, Queue> NQ = new HashMap<WorkerNode, Queue>();
		
		log.debug("nodeIds = " + nodeIds);
		for (int id : nodeIds) {
			log.debug("id = " + id);
			WorkerNode n = new WorkerNode();
			n.setId(id);
			n.setName(Cluster.getNodeNameById(id));
			Queue q = Cluster.getQueueForNode(n);
			NQ.put(n, q);
		}
		
		//GridEngine Changes
		QueueRequest req = new QueueRequest();
		req.setQueueName(queue_name);
		GridEngineUtil.createPermanentQueue(req, true, NQ);
		
		//DatabaseChanges
		boolean success = Queues.makeQueuePermanent(Queues.getIdByName(queue_name));
		
		if (!success) {
			response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "There was an internal error addign the queue to the starexec database");
		} else {
			// On success, redirect to the space explorer so they can see changes
		    response.sendRedirect(Util.docRoot("secure/admin/cluster.jsp"));
		}
	}
}
