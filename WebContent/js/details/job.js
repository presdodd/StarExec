var summaryTable; 
var pairTable;
var curSpaceId; //stores the ID of the job space that is currently selected from the space viewer
var jobId; //the ID of the job being viewed
var lastValidSelectOption;
var panelArray=null;
var useWallclock=true;
var syncResults=false;
$(document).ready(function(){
	jobId=$("#jobId").attr("value");
	
	//sets up buttons and so on
	initUI();
	
	//sets up the job space tree on the left side of the page
	initSpaceExplorer();
	initDataTables();
	
	//update the tables every 30 seconds
	setInterval(function() {
		pairTable.fnDraw(false);
		refreshPanels();
	},30000);
	
	//puts data into the data tables
	reloadTables($("#spaceId").attr("value"));
});

function setSyncResultsText() {
	if (syncResults) {
		$("#syncResults .ui-button-text").html("un-synchronize results");
	} else {
		$("#syncResults .ui-button-text").html("synchronize results");

	}
}

function refreshPanels(){
	for (i=0;i<panelArray.length;i++) {
		panelArray[i].api().ajax.reload(null,true);
	}
}

function refreshStats(id){
	//summaryTable.fnProcessingIndicator(true);
	summaryTable.api().ajax.reload(function() {
        updateGraphs();
	},true);
	
}

function createDownloadRequest(item,type,returnIds,getCompleted) {
	createDialog("Processing your download request, please wait. This will take some time for large jobs.");
	token=Math.floor(Math.random()*100000000);
	href = starexecRoot+"secure/download?token=" +token+ "&type="+ type +"&id="+$("#jobId").attr("value");
	if (typeof returnIds!= 'undefined' ) {
		href=href+"&returnids="+returnIds;
	}
	if (typeof getCompleted!='undefined') {
		href=href+"&getcompleted="+getCompleted;
	}
	$(item).attr('href', href);
	destroyOnReturn(token);		//when we see the download token as a cookie, destroy the dialog box
	window.location.href = href;
}


function initSpaceExplorer() {
	// Set the path to the css theme for the jstree plugin
	
	$.jstree._themes = starexecRoot+"css/jstree/";
	var id;
	// Initialize the jstree plugin for the explorer list
	$("#exploreList").jstree({  
		"json_data" : { 
			"ajax" : { 
				"url" : starexecRoot+"services/space/" +jobId+ "/jobspaces/true",	// Where we will be getting json data from 
				"data" : function (n) {
					
					return { id : n.attr ? n.attr("id") : 0}; // What the default space id should be
				} 
			} 
		}, 
		"themes" : { 
			"theme" : "default", 					
			"dots" : true, 
			"icons" : true
		},		
		"types" : {				
			"max_depth" : -2,
			"max_children" : -2,					
			"valid_children" : [ "space" ],
			"types" : {						
				"space" : {
					"valid_children" : [ "space" ],
					"icon" : {
						"image" : starexecRoot+"images/jstree/db.png"
					}
				}
			}
		},
		"ui" : {			
			"select_limit" : 1,			
			"selected_parent_close" : "select_parent",			
			"initially_select" : [ "1" ]			
		},
		"plugins" : [ "types", "themes", "json_data", "ui", "cookies"] ,
		"core" : { animation : 200 }
	}).bind("select_node.jstree", function (event, data) {
		// When a node is clicked, get its ID and display the info in the details pane
		id = data.rslt.obj.attr("id");
		name = data.rslt.obj.attr("name");
		maxStages = data.rslt.obj.attr("maxStages");
		setMaxStagesDropdown(parseInt(maxStages));
		$("#spaceName").text($('.jstree-clicked').text());
		$("#displayJobSpaceID").text("id  = "+id);
		reloadTables(id);
	}).on( "click", "a", function (event, data) { event.preventDefault();  });// This just disable's links in the node title	
}

function clearPanels() {
	if (panelArray==null)  {
		return;
	}
	for (i=0;i<panelArray.length;i++) {
		panelArray[i].fnDestroy();
		$(panelArray[i]).remove();
	}
	$(".panelField").remove();
	panelArray=null;
}


function reloadTables(id) {
	//we only need to update if we've actually selected a new space 
	if (curSpaceId!=id) {
		curSpaceId=id;
		summaryTable.fnClearTable();	//immediately get rid of the current data, which makes it look more responsive
		clearPanels();
		pairTable.fnClearTable();
		
		//clear out the graphs
		$("#solverChoice1").empty();
		$("#solverChoice2").empty();
		$("#spaceOverviewSelections").empty();
		$("#spaceOverview").attr("src",starexecRoot+"/images/loadingGraph.png");
		$("#solverComparison").attr("src",starexecRoot+"/images/loadingGraph.png");
		
		//tell the tables to display a "loading" indicator
		summaryTable.fnProcessingIndicator(true);
		
		pairTable.fnProcessingIndicator(true);
		refreshStats(id);
		
		initializePanels();

	}

}

function updateGraphs() {
	
	summaryTable.fnProcessingIndicator(false);

	rows = summaryTable.fnGetNodes();
	if (summaryTable.fnSettings().fnRecordsTotal()==0) {
		$("#graphField").hide();
	} else {
		$("#graphField").show();
		$("#spaceOverviewSelections").empty();
		$(rows).each(function() {
			//alert(this.html());
			solverName=$(this).find("a:first").attr("title");
			configName=$(this).find("td:nth-child(2)").children("a:first").attr("title");
			configId=$(this).find("td:nth-child(2)").children("a:first").attr("id");
			htmlString='<option value="' +configId+ '">' +solverName+'/'+configName+ '</ option>';
			$("#spaceOverviewSelections").append(htmlString);
			$("#solverChoice1").append(htmlString);
			$("#solverChoice2").append(htmlString);
		});
		//select first five solver/ configuration pairs
		$("#spaceOverviewSelections").children("option:lt(5)").prop("selected",true);
		lastValidSelectOption = $("#spaceOverviewSelections").val();
		updateSpaceOverviewGraph();
		if (summaryTable.fnSettings().fnRecordsTotal()>1) {
			$("#solverComparison").show();
			$("#solverComparisonOptionField").show();
			
			$("#solverChoice1").children("option:first").prop("selected",true);
			$("#solverChoice1").children("option:nth-child(2)").prop("selected",true);
			updateSolverComparison(false);
		} else {
			$("#solverComparison").hide();
			$("#solverComparisonOptionField").hide();

		}
		
	}	
}

/**
 * Initializes the user-interface
 */
function initUI(){
	
	$('#dialog-confirm-delete').hide();
	$('#dialog-confirm-pause').hide();
	$('#dialog-confirm-resume').hide();
	$( "#dialog-warning").hide();
	$("#dialog-return-ids").hide();
	$("#dialog-solverComparison").hide();
	$("#dialog-spaceOverview").hide();
	$("#dialog-postProcess").hide();
	$("#dialog-changeQueue").hide();
	$("#errorField").hide();
	$("#statsErrorField").hide();
	$('#editJobNameWrapper').hide();

	
	//for aesthetics, make the heights of the two option fields identical
	$("#solverComparisonOptionField").height($("#spaceOverviewOptionField").height());
	
	$("#jobOutputDownload").button({
		icons: {
			primary: "ui-icon-arrowthick-1-s"
		}
    });

	$('#editJobNameButton').button();

	$("#compareSolvers").button({
		icons: {
			primary: "ui-icon-arrowthick-1-s"
		}
    });
	$("#compareSolvers").hide();
	
	$("#compareSolvers").click(function(){
		c1=$(".first_selected").find(".configLink").attr("id");
		c2=$(".second_selected").find(".configLink").attr("id");
		window.open(starexecRoot+"secure/details/solverComparison.jsp?id="+jobId+"&sid="+curSpaceId+"&c1="+c1+"&c2="+c2);
	});

	
	
	attachSortButtonFunctions();
	
	$("#rerunPairs").button({
		icons: {
			primary: "ui-icon-arrowreturnthick-1-e"
		}
    });
	
	$("#jobXMLDownload").button({
		icons: {
			primary: "ui-icon-arrowthick-1-s"
		}
    });
	
	$('#clearCache').button( {
		icons: {
			secondary: "ui-icon-arrowrefresh-1-e"
		}
	});
	
	$('#recompileSpaces').button( {
		icons: {
			secondary: "ui-icon-arrowrefresh-1-e"
		}
	});
	
	$("#postProcess").button({
		icons: {
			primary: "ui-icon-arrowthick-1-n"
		}
	});
	
	$("#popoutPanels").button({
		icons: {
			primary: "ui-icon-extlink"
		}
	});
	$("#collapsePanels").button( {
		icons: {
			primary: "ui-icon-folder-collapsed"
		}
	}) ;
	$("#openPanels").button( {
		icons: {
			primary: "ui-icon-folder-open"
		}
	}) ;
	$(".changeTime").button({
		icons: {
			primary: "ui-icon-refresh"
		}
	
	});

	$("#matrixViewButton").button({
		icons: {
			primary: "ui-icon-newwin"
		}
	});
	
	$("#syncResults").button({
		icons: {
			primary: "ui-icon-gear"
	}
	});

	$("#matrixViewButton").click(function() {
		popup(starexecRoot+'secure/details/jobMatrixView.jsp?id='+jobId+'&stage=1&jobSpaceId='+curSpaceId);
	});
	
	$("#syncResults").click(function() {
		//just change the sync results boolean and update the button text.
		syncResults=!syncResults;
		setSyncResultsText();
		pairTable.fnDraw(false);
	});
	
	$("#spaceOverviewUpdate").button({
		icons: {
			primary: "ui-icon-arrowrefresh-1-e"
		}
	});
	$("#solverComparisonUpdate").button({
		icons: {
			primary: "ui-icon-arrowrefresh-1-e"
		}
	});
	$("#jobDownload").button({
		icons: {
			primary: "ui-icon-arrowthick-1-s"
		}
    });
	
	$('#deleteJob').button({
		icons: {
			secondary: "ui-icon-minus"
		}
	});
	
	$('#pauseJob').button({
		icons: {
			secondary: "ui-icon-pause"
		}
	});
	
	
	$('#resumeJob').button({
		icons: {
			secondary: "ui-icon-play"
		}
	});
	
	$('#changeQueue').button({
		icons: {
			secondary: "ui-icon-transferthick-e-w"
		}
	});

	
	$("#popoutPanels").click(function() {
		// default to primary stage
		window.open(starexecRoot+"secure/details/jobPanelView.jsp?jobid="+jobId+"&spaceid="+curSpaceId+"&stage=1");
	});
	$("#collapsePanels").click(function() {
		$(".panelField").each(function() {
			legend = $(this).children('legend:first');
			isOpen = $(legend).data('open');
			if (isOpen) {
				$(legend).trigger("click");
			}
		});
	});
	$("#openPanels").click(function() {
		$(".panelField").each(function() {
			legend = $(this).children('legend:first');
			isOpen = $(legend).data('open');
			
			if (!isOpen) {
				$(legend).trigger("click");
			}
		});
	});

	$('#jobNameText').click(function() {
		$('#jobNameText').hide();
		$('#editJobNameWrapper').show();
		$('#editJobName').select();
	});

	// Had to use mousedown here so that it would precede $('editJobName').blur()
	$('#editJobNameButton').mousedown(function() {
		log('Attempting to change name...');
		var name = $('#editJobName').val();
		// Make sure the name is a valid primitive name.
		var primNameRegex =new RegExp(getPrimNameRegex());
		if (!primNameRegex.test(name)) {
			showMessage("error", "The given name contains illegal characters.", 5000);
			return;
		}
		$.post(
			starexecRoot+'services/job/edit/name/'+jobId+'/'+name,
			{},
			function(returnCode) {
				success = parseReturnCode(returnCode);
				if (success) {
					$('#jobNameText').text(name);
					$('#editJobName').val(name);
				}
			},
			'json'
		);	
		$('#editJobNameWrapper').hide();
		$('#jobNameText').show();		
	});	

	$('#editJobName').blur(function() {
		$('#editJobNameWrapper').hide();
		$('#jobNameText').show();
		$('#editJobName').val($('#jobNameText').text());
	});

	$(".changeTime").click(function() {
		useWallclock=!useWallclock;
		setTimeButtonText();
		refreshPanels();
		refreshStats(curSpaceId);
		pairTable.fnDraw(false);
	});
	$(".stageSelector").change(function() {
		//set the value of all .stageSelectors to this one to sync them.
		//this does not trigger the change event, which is good because it would loop forever
		$(".stageSelector").val($(this).val());
		pairTable.fnDraw(false);
		refreshPanels();
		refreshStats(curSpaceId);
		
	});
	
	$("#recompileSpaces").click(function() {
		$.get(
				starexecRoot+"services/recompile/"+jobId,
				function(returnCode) {
					s=parseReturnCode(returnCode);	
		});
	});
	
	$("#clearCache").click(function(){
			
			$("#dialog-warning-txt").text('Are you sure you want to clear the cache for this primitive?');		
			$("#dialog-warning").dialog({
				modal: true,
				width: 380,
				height: 165,
				buttons: {
					'clear cache': function() {
						$(this).dialog("close");
							$.post(
									starexecRoot+"services/cache/clear/stats/"+jobId+"/",
									function(returnCode) {
										s=parseReturnCode(returnCode);	
							});
															
					},
					"cancel": function() {
						$(this).dialog("close");
					}
				}
			});
	});
	
	
	$("#deleteJob").click(function(){
		$('#dialog-confirm-delete-txt').text('are you sure you want to delete this job?');
		
		$('#dialog-confirm-delete').dialog({
			modal: true,
			width: 380,
			height: 165,
			buttons: {
				'OK': function() {
					log('user confirmed job deletion.');
					$('#dialog-confirm-delete').dialog('close');
					
					$.post(
							starexecRoot+"services/delete/job",
							{selectedIds: [getParameterByName("id")]},
							function(returnCode) {
								s=parseReturnCode(returnCode);
								if (s) {
									window.location = starexecRoot+'secure/explore/spaces.jsp';

								}
								
							},
							"json"
					);
				},
				"cancel": function() {
					log('user canceled job deletion');
					$(this).dialog("close");
				}
			}
		});
	});
	
	$("#postProcess").click(function(){
		$('#dialog-postProcess-txt').text('Please select a post-processor to use for this job.');
		
		$('#dialog-postProcess').dialog({
			modal: true,
			width: 380,
			height: 200,
			buttons: {
				'OK': function() {
					$('#dialog-postProcess').dialog('close');
					showMessage("info","Beginning job pair processing. ",3000);
					$.post(
							starexecRoot+"services/postprocess/job/" + getParameterByName("id")+"/"+$("#postProcessorSelection").val()+"/"+getSelectedStage(),
							function(returnCode) {
								parseReturnCode(returnCode);
								
							},
							"json"
					);
				},
				"cancel": function() {
					$(this).dialog("close");
				}
			}
		});
	});
	
	
	$("#pauseJob").click(function(){
		
		$.post(
				starexecRoot+"services/pause/job/" + getParameterByName("id"),
				function(returnCode) {
					s=parseReturnCode(returnCode);
					if (s) {
						document.location.reload(true);

					}
					
				},
				"json"
		);
	});
	
	$("#resumeJob").click(function(){
		$.post(
				starexecRoot+"services/resume/job/" + getParameterByName("id"),
				function(returnCode) {
					s=parseReturnCode(returnCode);
					if (s) {
						document.location.reload(true);

					}
					
				},
				"json"
		);
	});
	
	$("#changeQueue").click(function(){
		$('#dialog-changeQueue-txt').text('Please select a new queue to use for this job.');
		
		$('#dialog-changeQueue').dialog({
			modal: true,
			width: 380,
			height: 200,
			buttons: {
				'OK': function() {
					$('#dialog-changeQueue').dialog('close');
					$.post(
							starexecRoot+"services/changeQueue/job/" + getParameterByName("id")+"/"+$("#changeQueueSelection").val(),
							function(returnCode) {
								s=parseReturnCode(returnCode);
								if (s) {
									setTimeout(function(){document.location.reload(true);}, 1000);

								}
							},
							"json"
					);
				},
				"cancel": function() {
					$(this).dialog("close");
				}
			}
		});
	});
	
	
	$('#jobDownload').unbind("click");
	$('#jobDownload').click(function(e) {
		e.preventDefault();
		$('#dialog-return-ids-txt').text('do you want ids for job pairs, solvers, and benchmarks to be included in the CSV?');
		
		$('#dialog-return-ids').dialog({
			modal: true,
			width: 380,
			height: 200,
			buttons: {
				'download': function() {
					$('#dialog-return-ids').dialog('close');
					createDownloadRequest("#jobDownload","job",$("#includeids").prop("checked"),$("#getcompleted").prop("checked"));		
				},
				"cancel": function() {
					$(this).dialog("close");
				}
			}
		});

	});

	$('#jobXMLDownload').unbind("click");
	$('#jobXMLDownload').click(function(e) {
		e.preventDefault();
		createDownloadRequest("#jobXMLDownload","jobXML");
	});
	
	$('#jobOutputDownload').unbind("click");
	$('#jobOutputDownload').click(function(e) {
		e.preventDefault();
		createDownloadRequest("#jobOutputDownload","j_outputs");
	});
		
	//set teh two default solvers to compare
	defaultSolver1 = $('#solverChoice1').attr('default');
	$('#solverChoice1 option[value=' + defaultSolver1 + ']').prop('selected', true);
	
	defaultSolver2 = $('#solverChoice2').attr('default');
	$('#solverChoice2 option[value=' + defaultSolver2 + ']').prop('selected', true);
	
	//set all fieldsets as expandable
	$('#solverSummaryField').expandable(false);
	$("#pairTblField").expandable(false);
	$("#graphField").expandable(false);
	$("#errorField").expandable(false);
	$("#statsErrorField").expandable(false);
	$("#optionField").expandable(true);
	$("#detailField").expandable(true);
	$("#actionField").expandable(true);
	
	
	$("#subspaceSummaryField").expandable(false);
	
	lastValidSelectOption = $("#spaceOverviewSelections").val();
	$("#spaceOverviewUpdate").click(function() {
	  	updateSpaceOverviewGraph();
	});
	$("#solverComparisonUpdate").click(function() {
		updateSolverComparison(false);
	});
	$("#spaceOverviewSelections").change(function() {
	        if ($(this).val().length > 5) {
	          showMessage('error',"You may only choose a maximum of 5 solver / configuration pairs to display at one time",5000);
	          $(this).val(lastValidSelectOption);
	        } else {
	        	lastValidSelectOption = $(this).val();
	        	
	        }
	      
	});
	$("#solverComparison").click(function() {
		$('#dialog-solverComparison').dialog({
			modal: true,
			width: 850,
			height: 850
		});
	});
	$("#spaceOverview").click(function() {
		$('#dialog-spaceOverview').dialog({
			modal: true,
			width: 850,
			height: 850
		});
	});
	setTimeButtonText();
}

function updateSpaceOverviewGraph() {
	var configs = new Array();
	$("#spaceOverviewSelections option:selected").each(function() {
		configs.push($(this).attr("value"));
	});
	logY=false;
	if ($("#logScale").prop("checked")) {
		logY=true;
	}
	
	$.post(
			starexecRoot+"services/jobs/" + jobId + "/" + curSpaceId+"/graphs/spaceOverview/"+getSelectedStage(),
			{logY : logY, selectedIds: configs},
			function(returnCode) {
				s=parseReturnCode(returnCode);
				if (s) {
					currentConfigs=new Array();
					$("#spaceOverviewSelections option:selected").each(function() {
						currentConfigs.push($(this).attr("value"));
					});
					//we only want to update the graph if the request we made still matches what the user has put in
					//it is possible the user changed their selections and sent out a new request which has returned already
					//also, equality checking doesn't work on arrays, but less than and greater than do
					if (!(currentConfigs>configs) && !(currentConfigs<configs)) {
						$("#spaceOverview").attr("src",returnCode);
						$("#bigSpaceOverview").attr("src",returnCode+"600");
					}
				} else {
					$("#spaceOverview").attr("src",starexecRoot+"/images/noDisplayGraph.png");

				}
				
					
					
					
				
			},
			"text"
	);
}


//big is a boolean that determines whether we should get the big or the small map
function updateSolverComparison(big) {
	config1=$("#solverChoice1 option:selected").attr("value");
	config2=$("#solverChoice2 option:selected").attr("value");
	
	$.post(
			starexecRoot+"services/jobs/" + jobId + "/" + curSpaceId+"/graphs/solverComparison/"+config1+"/"+config2+"/"+big+"/"+getSelectedStage(),
			{},
			function(returnCode) {
				s=parseReturnCode(returnCode);
				if (s) {
					jsonObject=$.parseJSON(returnCode);
					src=jsonObject.src;
					map=jsonObject.map;
					if (big) {
						$("#bigSolverComparison").attr("src",src);
						$("#bigSolverComparisonMap").remove();
						$("#dialog-solverComparison").append(map);
					} else {
						$("#solverComparison").attr("src",src);
						$("#solverComparisonMap").remove();
						$("#graphField").append(map);
						updateSolverComparison(true);
					}
					
				} else {
					$("#solverComparison").attr("src",starexecRoot+"/images/noDisplayGraph.png");

				}
				
			},
			"text"
	);
}

function openSpace(childId) {
	$("#exploreList").jstree("open_node", "#" + curSpaceId, function() {
		$.jstree._focused().select_node("#" + childId, true);	
	});	
}


function getPanelTable(space) {
	spaceName=space.attr("name");
	spaceId=parseInt(space.attr("id"));
	
	table="<fieldset class=\"panelField\">" +
			"<legend class=\"panelHeader\">"+spaceName+"</legend>" +
			"<table id=panel"+spaceId+" spaceId=\""+spaceId+"\" class=\"panel\"><thead>" +
					"<tr class=\"viewSubspace\"><th colspan=\"4\" >Go To Subspace</th></tr>" +
			"<tr><th class=\"solverHead\">solver</th><th class=\"configHead\">config</th> " +
			"<th class=\"solvedHead\" title=\"Number of job pairs for which the result matched the expected result, or those attributes are undefined, over the number of job pairs that completed without any system errors\">solved</th> " +
			"<th class=\"timeHead\" title=\"total wallclock or cpu time for all job pairs run that were solved correctly\">time</th> </tr>" +
			"</thead>" +
			"<tbody></tbody> </table></fieldset>";
	return table;
	
}

function initializePanels() {
	sentSpaceId=curSpaceId;
	$.getJSON(starexecRoot+"services/space/" +jobId+ "/jobspaces/false?id="+sentSpaceId,function(spaces) {
		panelArray=new Array();
		var open=true;
		if (spaces.length==0) {
			$("#subspaceSummaryField").hide();
		}else {
			$("#subspaceSummaryField").show();
			
		}
		
		for (i=0;i<spaces.length;i++) {
			
			space=$(spaces[i]);
			spaceName=space.attr("name");
			spaceId=parseInt(space.attr("id"));
			
			child=getPanelTable(space);
			//if the user has changed spaces since this request was sent, we don't want to continue
			//generating panels for the old space.
			if (sentSpaceId!=curSpaceId) {
				return;
			}
			$("#panelActions").after(child); //put the table after the panelActions fieldset
			
			panelArray[i]=$("#panel"+spaceId).dataTable({
		        "sDom"			: 'rt<"clear">',
		        "iDisplayStart"	: 0,
		        "iDisplayLength": 1000, // make sure we show every entry
		        "sAjaxSource"	: starexecRoot+"services/jobs/" + jobId+"/solvers/pagination/"+spaceId+"/true/",
		        "sServerMethod" : "POST",
		        "fnServerData" : fnShortStatsPaginationHandler
		    });
		}
		
		$(".viewSubspace").each(function() {
			$(this).click(function() {
				spaceId=$(this).parents("table.panel").attr("spaceId");
				openSpace(spaceId);	
			});
			
		});
		$(".panelField").expandable(true);
	});
	
}

/**
 * Initializes the DataTable objects
 */
function initDataTables(){
	extendDataTableFunctions();
	//summary table
	summaryTable=$('#solveTbl').dataTable( {
        "sDom"			: 'rt<"bottom"flpi><"clear">',
        "iDisplayStart"	: 0,
        "iDisplayLength": defaultPageSize,
        "bSort": true,
        "bPaginate": true,
		"pagingType"    : "full_numbers",

        "sAjaxSource"	: starexecRoot+"services/jobs/",
        "sServerMethod" : "POST",
        "fnServerData" : fnStatsPaginationHandler
    });
	
	$("#solveTbl").on("mousedown", "tr", function(){
		if (!$(this).hasClass("row_selected")) {
			$("#solveTbl").find(".second_selected").each(function(){
				$(this).removeClass("second_selected");
				$(this).removeClass("row_selected");

			});
			$("#solveTbl").find(".first_selected").each(function(){
				$(this).removeClass("first_selected");
				$(this).addClass("second_selected");

			});
			
			$(this).addClass("first_selected");
			$(this).addClass("row_selected");
		} else {
			$(this).removeClass("row_selected");
			$(this).removeClass("first_selected");
			$(this).removeClass("second_selected");

			$("#solveTbl").find(".second_selected").each(function(){
				$(this).removeClass("second_selected");
				$(this).removeClass("first_selected");

				$(this).addClass("first_selected");

			});
		}
		if ($("#solveTbl").find(".second_selected").size()>0) {
			$("#compareSolvers").show();
			
		} else {
			$("#compareSolvers").hide();

		}
	});
	
	// Job pairs table
	pairTable=$('#pairTbl').dataTable( {
        "sDom"			: 'rt<"bottom"flpi><"clear">',
        "iDisplayStart"	: 0,
        "iDisplayLength": defaultPageSize,
        "bServerSide"	: true,
		"pagingType"    : "full_numbers",

        "sAjaxSource"	: starexecRoot+"services/jobs/",
        "sServerMethod" : "POST",
        "fnServerData"	: fnPaginationHandler 
    });
	
	setSortTable(pairTable);
	
	$("#pairTbl thead").click(function(){
		resetSortButtons();
	});
	
	$('#detailTbl').dataTable( {
		"sDom": 'rt<"bottom"f><"clear">',
		"aaSorting": [],
		"bPaginate": false,        
		"bSort": true        
	});
	
	$('#pairTbl tbody').on( "click", "a", function(event) {
		event.stopPropogation();
	});
	
	//Set up row click to send to pair details page
	$("#pairTbl tbody").on("click", "tr",  function(){
		var pairId = $(this).find('input').val();
		window.location.assign(starexecRoot+"secure/details/pair.jsp?id=" + pairId);
	});
	
	// Change the filter so that it only queries the server when the user stops typing
	$('#pairTbl').dataTable().fnFilterOnDoneTyping();
	
}


/**
 * Adds fnProcessingIndicator and fnFilterOnDoneTyping to dataTables api
 */
function extendDataTableFunctions(){
	
	// Allows manually turning on and off of the processing indicator (used for jobs table)
	jQuery.fn.dataTableExt.oApi.fnProcessingIndicator = function (oSettings, onoff)	{
		if( typeof(onoff) == 'undefined' ) {
			onoff = true;
		}
		this.oApi._fnProcessingDisplay(oSettings, onoff);
	};
	// Changes the filter so that it only queries when the user is done typing
	jQuery.fn.dataTableExt.oApi.fnFilterOnDoneTyping = function (oSettings) {
	    var _that = this;
	    this.each(function (i) {
	        $.fn.dataTableExt.iApiIndex = i;
	        var anControl = $('input', _that.fnSettings().aanFeatures.f);
	        anControl.unbind('keyup').bind('keyup', $.debounce( 400, function (e) {
                $.fn.dataTableExt.iApiIndex = i;
                _that.fnFilter(anControl.val());
	        }));
	        return this;
	    });
	    return this;
	};
	
	
}

function fnShortStatsPaginationHandler(sSource, aoData, fnCallback) {
	$.post(  
			sSource+useWallclock+"/"+getSelectedStage(),
			aoData,
			function(nextDataTablePage){
				//if the user has clicked on a different space since this was called, we want those results, not these
				s=parseReturnCode(nextDataTablePage);
				if (s) {
					fnCallback(nextDataTablePage);						

				}
				
			},  
			"json"
	).error(function(){
		showMessage('error',"Internal error populating data table",5000);
	});
}

function fnStatsPaginationHandler(sSource, aoData, fnCallback) {
	if (typeof curSpaceId=='undefined') {
		return;
	}
	outSpaceId=curSpaceId;
	$.post(  
			sSource + jobId+"/solvers/pagination/"+outSpaceId+"/false/"+useWallclock+"/"+getSelectedStage(),
			aoData,
			function(nextDataTablePage){
				//if the user has clicked on a different space since this was called, we want those results, not these
				if (outSpaceId!=curSpaceId) {
					return;
				}
				s=parseReturnCode(nextDataTablePage);
				if (s) {
					$("#solverSummaryField").show();
					$("#graphField").show();
					$("#statsErrorField").hide();
					fnCallback(nextDataTablePage);		
				}

			},  
			"json"
	).error(function(){
		showMessage('error',"Internal error populating data table",5000);
	});
}

/**
 * Handles querying for pages in a given DataTable object
 * 
 * @param sSource the "sAjaxSource" of the calling table
 * @param aoData the parameters of the DataTable object to send to the server
 * @param fnCallback the function that actually maps the returned page to the DataTable object
 */
function fnPaginationHandler(sSource, aoData, fnCallback) {
	if (typeof curSpaceId=='undefined') {
		return;
	}
	outSpaceId=curSpaceId;
	if (sortOverride!=null) {
		aoData.push( { "name": "sort_by", "value":getSelectedSort() } );
		aoData.push( { "name": "sort_dir", "value":isASC() } );

	}
	$.post(  
			sSource + jobId + "/pairs/pagination/"+outSpaceId+"/"+useWallclock+"/"+syncResults+"/"+getSelectedStage(),
			aoData,
			function(nextDataTablePage){
				//do nothing if this is no longer the current request
				if (outSpaceId!=curSpaceId) {
					return;
				}
				s=parseReturnCode(nextDataTablePage);
				if (s) {
					
					pairTable.fnProcessingIndicator(false);
					fnCallback(nextDataTablePage);
					$("#errorField").hide();
					if (pairTable.fnSettings().fnRecordsTotal()==0) {
						$("#pairTblField").hide();
					} else {
						$("#pairTblField").show();
					}
				} else {
					//if we weren't successful, we need to check to see if it was because there are too many pairs
					code=getStatusCode(nextDataTablePage);
					if (code==1) {
						$("#pairTblField").hide();
						$("#errorField").show();
					}
				}
					
			},  
			"json"
	).error(function(){
		showMessage('error',"Internal error populating data table",5000);
	});
}

function popup(url) {
	'use strict';
	var win = window.open(url, '_blank');
	if (win) {
		// Browser allowed opening of popup.
		win.focus();
	}
}
