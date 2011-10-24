package org.starexec.constants;

/**
 * Class which holds static resources (R) available for use
 * throughout the entire application. This will include many
 * constant strings and numbers that other classes rely on.
 * @author Tyler Jensen
 */
public class R {
	/* 
	 * IMPORTANT: This class only supports string, int and boolean types.
	 * DO NOT change field names without changing their corresponding keys
	 * in starexec-config.xml. Field names must match property key names!
	 * 
	 * Any fields set here will be treated as defaults
	 */
	
	public R() throws Exception{
		throw new Exception("Cannot instantiate class because it is static.");
	}
	
	// Email properties
	public static String EMAIL_SMTP = "localhost";
	public static int EMAIL_SMTP_PORT = 25;
	public static String EMAIL_USER = null;
	public static String EMAIL_PWD = null;
	public static String EMAIL_PARTICLE = "@divms.uiowa.edu";	
	
	// MySQL properties
	public static String MYSQL_URL = null;									// MySQL connection string for JDBC
	public static String MYSQL_USERNAME = null;								// Starexec's username for the database
	public static String MYSQL_PASSWORD = null;								// Starexec database password
	public static String MYSQL_DRIVER = "com.mysql.jdbc.Driver";			// MySQL java driver class (we use JDBC)
	public static int MYSQL_POOL_MAX_SIZE = 1;								// The maximum number of connections in the database pool
	public static int MYSQL_POOL_MIN_SIZE = 1;								// The minimum number of connections to keep open to the database
	
	// Global path information
	public static String SOLVER_PATH = null;								// The top-level directory in which to save the solver file(s)
	public static String BENCHMARK_PATH = null;								// The top-level directory in which to save the benchmark file(s)
	public static String STAREXEC_ROOT = null;								// The directory of the starexec webapp	
	public static String CONFIG_PATH = null;								// The directory of starexec's configuration and template files relative to the root path
	public static String NODE_WORKING_DIR = null;							// The directory on the local nodes where they can use for scratch space (read/write)
	public static String JOB_INBOX_DIR = null;								// Where to deposit new job scripts until SGE distributes it to a node    	
	
	// Job Manager (JM) constants
	public static String JOBFILE_FORMAT = null;								// The filename format (with standard java string formatting) for generated jobscript files
	public static String SOLVER_BIN_DIR = null;								// The path to the bin directory to look for runscripts (relative to the solver's toplevel directory)
	public static int NEXT_JID = 1;											// The number of the next Job to be ran
	public static int PAIR_ID = 1;											// The number of the next pair to be ran
	
	// Job status strings
	public static String JOB_STATUS_DONE = "Done";							// The status of a successfully finished job
	public static String JOB_STATUS_RUNNING = "Running";					// The status of a currently running job
	public static String JOB_STATUS_ENQUEUED = "Enqueued";					// The status of a job that SGE has queued up to be run
	public static String JOB_STATUS_ERR = "Error";							// The status of a failed job
	
	// Misc application properties
	public static boolean LOG_TO_CONSOLE = true;							// Whether or not to output log messages to the console
	public static String PWD_HASH_ALGORITHM = "SHA-512";					// Which algorithm to use to hash user passwords
}
