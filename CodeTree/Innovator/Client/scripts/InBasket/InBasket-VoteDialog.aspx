<!DOCTYPE HTML>
<!-- (c) Copyright by Aras Corporation, 2004-2013. -->
<!-- #INCLUDE FILE="../include/utils.aspx" -->
<html>
<head>
	<title></title>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	<link rel="stylesheet" type="text/css" href="../../styles/default.css" />
	<style type="text/css">
		@import "../../javascript/dojo/resources/dojo.css";
		@import "../../javascript/dijit/themes/claro/claro.css";
		@import "../../javascript/dojox/grid/resources/claroGrid.css";
		@import "../../javascript/include.aspx?classes=common.css";
		@import "../../styles/default.css";

		html,body{
			overflow: hidden;
			width: 100%;
			height: 100%;
			margin: 0px;
			padding: 0px;
		}
		.dialogContainer{
			overflow: auto;
			position: absolute;
			left: 0px;
			right: 0px;
			top: 0px;
			bottom: 0px;
			padding: 5px;
		}
		fieldset{
			border: 1px solid black;
			padding-bottom: 5px;
			text-align: left;
		}
		legend{
			font-weight: bold;
		}
		.logicalSection{
			position: relative;
			text-align: center;
			margin-top: 30px;
			padding: 0px 20px;
			min-width: 600px;
		}
		.logicalSubSection{
			font-family: arial;
			font-size: 12px;
			padding-top: 15px;
		}
		.logicalSubSection2{
			padding-top: 5px;
		}
		
	</style>
	<script>
		var isModalDialog = !!(window.frameElement && window.frameElement.dialogArguments);
		var aras = isModalDialog ? window.frameElement.dialogArguments.aras : parent.parent.aras;
		var topWnd = parent.parent;
	</script>
	<script type="text/javascript" src="../../javascript/dialog.js"></script>
	<script type="text/javascript" src="../../javascript/include.aspx?classes=XmlDocument,ArasModules"></script>
	<script type="text/javascript" src="../../javascript/include.aspx?classes=/dojo.js" data-dojo-config="isDebug: true, parseOnLoad: false, baseUrl:'../../javascript/dojo'"></script>
	<script type="text/javascript" src="../../javascript/PopulateDocByLabels.js"></script>
	<script type="text/javascript" src="../../javascript/md5.js"></script>
	<script type="text/javascript">
		function getItemFromServer(amlQuery) {
			var tmpRes = aras.soapSend("ApplyItem", amlQuery);
			if (tmpRes.getFaultCode() != 0) {
				aras.AlertError(tmpRes);
				return null;
			}
			return tmpRes.getResult().selectSingleNode("Item");
		}

		var VoteDialogArguments = isModalDialog ? window.frameElement.dialogArguments : parent.dialogArguments;
		var taskgrid = null;
		var votersgrid = null;  // Changes for AdHoc Workflow assigments - to same WF activity -  rolf 3 Apr 2020
		var voterList = [];
		
		clientControlsFactory.createControl("Aras.Client.Controls.Public.GridContainer", undefined, function (control) {
			taskgrid = control;
			taskgrid.setLayout_Experimental([{ field: "sequence", name: aras.getResource("", "inbasketvd.sequence"), width: "12%", styles: "text-align: center;", headerStyles: "text-align: center;" },
			{ field: "required", name: aras.getResource("", "inbasketvd.required"), width: "12%", styles: "text-align: center;", headerStyles: "text-align: center;", editable: false },
			{ field: "description", name: aras.getResource("", "inbasketvd.description"), width: "64%", styles: "text-align: left;", headerStyles: "text-align: center;" },
			{ field: "complete", name: aras.getResource("", "inbasketvd.complete"), width: "12%", styles: "text-align: center;", headerStyles: "text-align: center;", editable: true}]);
			getAllowedVotes();
			populateTasksList();
			document.getElementById("delegate").addEventListener("blur", function (e) { doSearchIdentity() }, true);
		});

	</script>
	<script type="text/javascript">
		var MyActivity = VoteDialogArguments.activity;
		var workflowName = VoteDialogArguments.wflName;
		var workflowId = VoteDialogArguments.wflId;
		var itemId = VoteDialogArguments.itemId;
		var MyActId = aras.getItemProperty(MyActivity, "id");
		var MyActLabel = aras.getItemProperty(MyActivity, "label") || aras.getItemProperty(MyActivity, "name");
		var CanDelegate = aras.getItemProperty(MyActivity, "can_delegate");
		var CanRefuse = aras.getItemProperty(MyActivity, "can_refuse");

		var MyWflName = workflowName; //Workflow Process name
		var MyWflId = workflowId;

		var MyAssID = VoteDialogArguments.assignmentId; //LOL :))
		var MyAssItem = getItemFromServer("<Item type='Activity Assignment' action='get' levels='1' id='"+MyAssID+"'/>");
		var delegateID = 0;

		onload = function() {
			populateNames();
			populateVariables();
			refreshFieldsColor();
			processPasswordField();

		};

		function processPasswordField(){
			if (!aras.isLocalAuthenticationType()){
				const passwordElements = document.getElementsByClassName("password");
				Array.from(passwordElements).forEach(function(passwordElement){
					passwordElement.style.display = "none";
				});
				document.querySelector("#AuthSection table").width = "45%";
			}
		}

		function refreshFieldsColor(){
			var fields = document.querySelectorAll(".dynamicBkColor");
			for (var i = 0; i < fields.length; i++){
				fields[i].style["backgroundColor"] = fields[i].readOnly ? "#D3D3D3" : "white";
			}
		}

		function populateNames(){
			document.getElementById("WorkflowNameCell").innerHTML = MyWflName;
			document.getElementById("ActivityLabelCell").innerHTML = MyActLabel;
		}

		function esc(str){
			return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
		}

		function getSequenceOrderArray(nodes) {
			var arr = new Array(nodes.length);
			var text_val;

			for (var i = 0; i < nodes.length; i++) {
				text_val = aras.getItemProperty(nodes[i], "sequence");
				text_val = text_val ? parseInt(text_val, 10) : "";
				arr[i] = { seq: text_val, ind: i };
			}

			return arr.sort(function(a,b) { return a.seq - b.seq });
		}

		function populateTasksList() {
			var taskList, task, taskValItem;
			var row_id, cell;
			var sequence, is_required, descr, completed_on;

			if (!(MyActivity)) return;
			taskList = MyActivity.selectNodes('Relationships/Item[@type="Activity Task"]');
			var items = [];
			var arr = getSequenceOrderArray(taskList);
			for (var i = 0; i < taskList.length; i++) {
				task = taskList[arr[i].ind];
				row_id = aras.getItemProperty(task, "id");

				sequence = aras.getItemProperty(task, "sequence");
				sequence = sequence ? parseInt(sequence, 10) : "";
				is_required = ("1" == aras.getItemProperty(task, "is_required"));
				descr = aras.getItemProperty(task, "description");

				taskValItem = MyAssItem.selectSingleNode("Relationships/Item[@type='Activity Task Value' and task='" + row_id + "']");
				if (!taskValItem) {
					var tempItemNode = MyAssItem.ownerDocument.createElement("Item");
					tempItemNode.setAttribute("type", "Activity Task Value");
					tempItemNode.setAttribute("action", "add");

					var tempNode = tempItemNode.ownerDocument.createElement("task");
					tempNode.text = row_id;
					tempItemNode.appendChild(tempNode);

					tempNode = tempItemNode.ownerDocument.createElement("source_id");
					tempNode.setAttribute("type", "Activity Assignment");
					tempNode.text = MyAssID;
					tempItemNode.appendChild(tempNode);
					if (!MyAssItem.selectSingleNode("Relationships")) {
						tempNode = MyAssItem.ownerDocument.createElement("Relationships");
						MyAssItem.appendChild(tempNode);
					}
					MyAssItem.selectSingleNode("Relationships").appendChild(tempItemNode);
				}

				completed_on = taskValItem ? aras.getItemProperty(taskValItem, "completed_on") : "";
				items.push( { uniqueId: row_id, sequence: sequence, required: is_required, description: descr, complete: (!!completed_on) } );
			}
			taskgrid.setArrayData_Experimental(items);
		}

		function populateVariables() {
			var varList,
				variable,
				tempTd,
				tempSelect,
				varsTr,
				varValItem,
				varLabel,
				varID,
				varType,
				varValue,
				checked,
				srcListID,
				listVals,
				arr,
				i,
				j;

			function appendElement (parentToExpand, elementType, attributes, properties) {
				var element = document.createElement(elementType),
					prop;
				if (element) {
					if (attributes) {
						for (prop in attributes) {
							element.setAttribute(prop, attributes[prop]);
						}
					}
					if (properties) {
						for (prop in properties) {
							element[prop] = properties[prop];
						}
					}
					if (parentToExpand && 'appendChild' in parentToExpand) {
						parentToExpand.appendChild(element);
					}
				}
				return element;
			}

			if (MyActivity) {
				varList = MyActivity.selectNodes('Relationships/Item[@type="Activity Variable" and (not(is_hidden) or is_hidden="0")]');
				if (varList.length == 0) {
					document.getElementById("VariablesSection").style.display = "none";
					return;
				}
			}

			if (!(varList)) return;
			arr = getSequenceOrderArray(varList);
			var varTable = document.getElementById("VariablesTable");
			for (i = 0; i < varList.length; i++) {
				actVar = varList[arr[i].ind];
				varLabel = aras.getItemProperty(actVar, "label");
				if (varLabel == ""){
					varLabel = aras.getItemProperty(actVar, "name");
				}
				varType = aras.getItemProperty(actVar, "datatype");
				varID = aras.getItemProperty(actVar, "id");
				varValItem = MyAssItem.selectSingleNode("Relationships/Item[@type='Activity Variable Value' and variable='" + varID + "']");
				if (!varValItem) {
					aras.AlertError(aras.getResource("", "inbasketvd.act_variable_not_found_varid", varID), undefined, undefined, topWnd.window);
					return;
				}

				varValue = aras.getItemProperty(varValItem, "value");
				varsTr = appendElement(varTable, 'tr');
				tempTd = appendElement(varsTr, 'td', {style: "padding: 2px 5px;"}, { innerHTML:'<b>' + varLabel + '</b>' });

				// column with value
				tempTd = appendElement(varsTr, 'td', {style: "padding: 2px 0px;"} );
				if (varType == "String" || varType == "Integer" || varType == "Float") {
					appendElement(tempTd, 'input', { type:'text', name:varID, value:varValue, style:'width:200px;' });
				} else if (varType == "Boolean") {
					var attributes = { type:'checkbox', name:varID, style:'position: relative;'},
						checkbox;
					if (varValue == "1") {
						attributes.checked = "checked";
					}
					checkbox = appendElement(tempTd, 'input', attributes);
					appendElement(tempTd, 'label', { style:'position: relative; left: ' + (-checkbox.offsetWidth) + 'px;' });
				} else if (varType == "List") {
					tempSelect = appendElement(tempTd, 'select', { name:varID, style:'width:200px;' });
					srcListID = aras.getItemProperty(actVar, "source");
					listVals = aras.getListValues(srcListID);

					for (j = 0; j < listVals.length; j++){
						val = aras.getItemProperty(listVals[j], "value");
						lab = aras.getItemProperty(listVals[j], "label");

						if (varValue == val){
							appendElement(tempSelect, 'option', { value:val, selected:'selected' }, { text:lab });
						}
						else{
							appendElement(tempSelect, 'option', { value:val }, { text:lab });
						}
					}
				}
			}
		}

		function getAllowedVotes() {
			if (!document.getElementById("VoteList")) {
				setTimeout('getAllowedVotes()', 10);
				return;
			}
			// fetch the path and auth properties from the Activities structure and the Tasks
			if (!MyActivity) return;
			var paths = MyActivity.selectNodes('Relationships/Item[@type="Workflow Process Path"][not(is_complete) or is_complete!="1"]');
			if (paths == null) {
				aras.AlertError(aras.getResource("", "inbasketvd.act_no_allowed_votes"), undefined, undefined, topWnd.window);
				return;
			}

			var voteIndex = 0;
			var voteList = document.getElementById("VoteList");

			var pathItem, path_name, path_label, path_id;
			for (var i = 0; i < paths.length; i++) {
				pathItem = paths[i];

				var clonedAsNode = pathItem.selectSingleNode('related_id/Item[@type="Activity"]/cloned_as');
				if (!clonedAsNode || "1" === clonedAsNode.getAttribute("is_null")) {
					path_label = aras.getItemProperty(pathItem, "label");
					path_name = aras.getItemProperty(pathItem, "name");
					if (path_label == "") {
						path_label = path_name;
					}
					path_id = aras.getItemProperty(pathItem, "id");

					var newOption = new Option();
					newOption.text = path_label;
					newOption.textname = path_name;
					newOption.value = path_id;
					voteList.options[voteIndex++] = newOption;
				}
			}

			// check if the Refuse and/or Delegate should be added
			if (CanDelegate == "1") {
				var newOption = new Option();
				newOption.text = "Delegate";
				newOption.textname = "Delegate";
				newOption.value = "Delegate";
				voteList.options[voteIndex++] = newOption;
			}

			if (CanRefuse == "1") {
				var newOption = new Option();
				newOption.text = "Refuse";
				newOption.textname = "Refuse";
				newOption.value = "Refuse";
				voteList.options[voteIndex++] = newOption;
			}

			document.getElementById("Comments").value = aras.getItemProperty(MyAssItem, "comments");
			voteList.options.selectedIndex = -1;
		}

		function onChangeVote() {
			var voteList = document.getElementById("VoteList"),
				password = document.querySelector("input[name=password]"),
				esignature = document.querySelector("input[name=esignature]"),
				selInd = voteList.options.selectedIndex;

			if (selInd == -1) {
				return;
			}

			var MyPath = voteList.options[selInd].text;
			delegate.readOnly = MyPath != "Delegate";
			delegate_img.disabled = MyPath != "Delegate";

			var MyAuth = "none";
			if (MyPath != "Delegate" && MyPath != "Refuse"){
				var path_id = voteList.options[selInd].value;
				var pathItem = MyActivity.selectSingleNode('Relationships/Item[@type="Workflow Process Path" and id="' + path_id + '"]');
				MyAuth = aras.getItemProperty(pathItem, 'authentication');
			}

			if (password) {
				password.readOnly = MyAuth !== "password";
			}
			if (esignature) {
				esignature.readOnly = MyAuth !== "esignature";
			}
			refreshFieldsColor();

			aras.updateDomSelectLabel(voteList);
		}

		var lastDelegateVal = "";
		function showSearchDialog(itemTypeName) {
			if (delegate.readOnly) {
				return;
			}
			var params = { aras: window.aras, itemtypeName: itemTypeName, type: "SearchDialog" };
			var win = aras.getMostTopWindowWithAras(window);
			var dialog = (win.main || win).ArasModules.MaximazableDialog.show("iframe", params);
			dialog.promise.then(function (dlgRes) {
				if (!dlgRes) {
					return;
				}
				delegateID = dlgRes.itemID;
				delegate.value = dlgRes.keyed_name;
				lastDelegateVal = delegate.value;
			});
		}

		function doSearchIdentity() {
			if (lastDelegateVal == delegate.value) {
				return;
			}

			var item = aras.uiGetItemByKeyedName("Identity", delegate.value);
			if (!item) {
				if (delegate.value != "") {
					aras.AlertError(aras.getResource("", "inbasketvd.wrong_iden"), undefined, undefined, topWnd.window);
				}
				delegate.value = "";
				lastDelegateVal = "";
				delegateID = 0;
				return;
			}
			else {
				delegate.value = item.selectSingleNode("keyed_name").text;
			}

			delegateID = aras.getItemProperty(item, "id");
			lastDelegateVal = delegate.value;
		}

		function delegateOnKeydown(event) {
			//F2: keyCode = 113
			event = window.event || event;
			if (event.keyCode == 113) {
				showSearchDialog("Identity");
			}
		}

		function delegateClick() {
			showSearchDialog("Identity");
		}

		function doComplete() {
			completeActivity("complete");
		}

		function saveChanges() {
			completeActivity("save");
		}

		function cancelVote() {
			closeDialog();
		}

		function closeDialog(data) {
			if (!isModalDialog) {
				topWnd.window.close();
			} else {
				VoteDialogArguments.dialog.close(data);
			}
		}

		function completeActivity(mode) {
			var voteList = document.getElementById("VoteList"),
				esignature = document.querySelector("input[name=esignature]"),
				password = document.querySelector("input[name=password]");

			if (mode != "complete" && mode != "save") {
				return;
			}

			var selInd = voteList.options.selectedIndex;
			if (selInd == -1) {
				if (mode == "complete") {
					aras.AlertError(aras.getResource("", "inbasketvd.votelist_no_selected_items"), undefined, undefined, topWnd.window);
					return;
				}
				else {
					selInd = 0; //to allow save
				}
			}

			if (voteList.options[selInd] == null) {
				aras.AlertError(aras.getResource("", "inbasketvd.votelist_no_items"), undefined, undefined, topWnd.window);
				return;
			}

			var MyPathName = voteList.options[selInd].textname;
			var MyPath = voteList.options[selInd].text;
			var pathID = voteList.options[selInd].value;
			var pathItem = MyActivity.selectSingleNode('Relationships/Item[@type="Workflow Process Path" and id="' + pathID + '"]');

			var MyAuth = "none";
			if (MyPath != "Delegate" && MyPath != "Refuse") {
				MyAuth = aras.getItemProperty(pathItem, 'authentication');
			}
			var MD5Auth = "";
			var AuthMode = "";

			// check for password required at this point
			if (MyAuth == "password") {
				AuthMode = "password";
				if (mode == "complete") {
					if (!aras.isLocalAuthenticationType()) {
						// InnovatorClient does not have information about password for external authentication type.
						// Sending request without validation allows to support previous behavior and processes completion
						// for external authentication types.
						// This solution based on fact that EvaluateActivity action does not validate password.
						// This should be corrected during implementation of
						// IR-075893 "IST: Possibility to process EvaluateActivity without validation"
						// and IR-075894 "AF: Usage of esignature in workflow for external authentication".
						processVote('');
						return;
					}
					if (password && password.value == '') {
						aras.AlertError(aras.getResource("", "inbasketvd.enter_pwd"), undefined, undefined, topWnd.window);
						return;
					}
				}

				var MD5AuthHandler = function() {
					if (aras.getVariable('fips_mode')) {
						return ArasModules.cryptohash.SHA256(password.value);
					} else {
						return calcMD5(password.value);
					}
				};
				MD5Auth = MD5AuthHandler();
				function checkResult(hash) {
					if (mode == "complete") {
						var resultXML = aras.ValidateVote(hash, "password");
						if (!resultXML) {
							aras.AlertError(aras.getResource("", "common.an_internal_error_has_occured"), aras.getResource("", "inbasketvd.validatevote_resultxml_empty"), aras.getResource("", "common.client_side_err"),aras.getMostTopWindowWithAras(window));
							return;
						}

						var result = resultXML.selectSingleNode(aras.XPathResult());
						if (result.text != "pass") {
							aras.AlertError(aras.getResource("", "inbasketvd.pwd_invalid"), undefined, undefined, topWnd.window);
							return;
						}
					}
					return true;
				}
				if (MD5Auth && MD5Auth.then) {
					return MD5Auth.then(function(hash){
						hash = hash.toUpperCase();
						if (!checkResult(hash)) {
							return;
						}
						return hash;
					}.bind(this)).then(function(hash){
						if (hash) {
							processVote(hash);
						}
					}.bind(this));
				} else {
					if (!checkResult(MD5Auth)) {
						return;
					}
				}

			}
			else if (MyAuth == "esignature") {
				if (mode == "complete") {
					if (esignature.value == "") {
						aras.AlertError(aras.getResource("", "inbasketvd.enter_esign"), undefined, undefined, topWnd.window);
						return;
					}
				}

				function doAdditionalESignatureCheck(hash) {
					if (mode == "complete") {
						var resultXML = aras.ValidateVote(hash, "esignature");
						if (!resultXML) {
							aras.AlertError(aras.getResource("", "common.an_internal_error_has_occured"), aras.getResource("", "inbasketvd.validatevote_resultxml_empty"), aras.getResource("", "common.client_side_err"));
							return;
						}

						var result = resultXML.selectSingleNode(aras.XPathResult());
						if (result.text != "pass") {
							aras.AlertError(aras.getResource("", "inbasketvd.esign_invalid"), undefined, undefined, topWnd.window);
							return;
						}
					}
					return true;
				}

				AuthMode = "esignature";
				if (aras.getVariable('fips_mode')) {
					return ArasModules.cryptohash.SHA256(esignature.value).then(function(hash) {
						if (!doAdditionalESignatureCheck(hash)) {
							return;
						}
						return hash;
					}.bind(this)).then(function(hash) {
						if (hash) {
							processVote(hash);
						}
					}.bind(this));
				} else {
					MD5Auth = calcMD5(esignature.value);
				}

				if (!doAdditionalESignatureCheck(MD5Auth)) {
					return;
				}
			}
			function processVote(hash) {
				if (MyPath == "Delegate")
				{
					if (mode == "complete") {
						if (delegate.value == "") {
							aras.AlertError(aras.getResource("", "inbasketvd.someone_delegate_to"), undefined, undefined, topWnd.window);
							return;
						}
					}
				}

				var body = "";
				body += '<Item type="' + MyActivity.getAttribute('type') + '" action="EvaluateActivity">';
				body += "<Activity>" + MyActId + "</Activity>";
				body += "<ActivityAssignment>" + MyAssID + "</ActivityAssignment>";

				body += "<Paths>";
				body += "<Path id='" + pathID + "'><![CDATA[" + MyPathName + "]]></Path>";
				body += "</Paths>";

				body += "<DelegateTo>" + delegateID + "</DelegateTo>";

				var taskList, task, taskID,
					row_id, cell, sequence, is_required, task_complete,
					validate = ("complete" === mode && "Delegate" !== MyPath && "Refuse" !== MyPath);

				body += "<Tasks>";
				taskList = MyActivity.selectNodes('Relationships/Item[@type="Activity Task"]');
				for (var i = 0; i < taskList.length; i++) {
					task = taskList[i];
					taskID = aras.getItemProperty(task, "id");
					row_id = taskID;

					sequence = this.taskgrid.items_Experimental.get(row_id, "value", "sequence");
					is_required = this.taskgrid.items_Experimental.get(row_id, "value", "required");
					task_complete = this.taskgrid.items_Experimental.get(row_id, "value", "complete");
					if (validate) {
						if (is_required && !task_complete)
						{
							aras.AlertError(aras.getResource("", "inbasketvd.task_required", sequence), undefined, undefined, topWnd.window);
							return;
						}
					}

					body += "<Task id='" + taskID + "' completed='" + (task_complete ? 1 : 0) + "'></Task>";
				}
				body += "</Tasks>";

				var varList, actVar, varLabel, varType, varID, varValItem;
				var elem, is_required, is_hidden, value;

				body += "<Variables>";
				varList = MyActivity.selectNodes('Relationships/Item[@type="Activity Variable"]');
				for (i = 0; i < varList.length; i++) {
					actVar = varList[i];
					varLabel = aras.getItemProperty(actVar, "label");
					if (varLabel == "") {
						varLabel = aras.getItemProperty(actVar, "name");
					}
					varType = aras.getItemProperty(actVar, "datatype");
					varID = aras.getItemProperty(actVar, "id");
					is_required = (aras.getItemProperty(actVar, "is_required") == "1" ? true : false);
					is_hidden = (aras.getItemProperty(actVar, "is_hidden") == "1" ? true : false);
					value = "";

					if (is_hidden) {
						varValItem = MyAssItem.selectSingleNode("Relationships/Item[@type='Activity Variable Value' and variable='" + varID + "']");
						if (!varValItem) {
							aras.AlertError(aras.getResource("", "inbasketvd.act_variable_not_found_varid", varID), undefined, undefined, topWnd.window);
							return;
						}

						value = aras.getItemProperty(varValItem, "value");
					}
					else {
						elem = document.getElementsByName(varID)[0];
						if (!elem) return;

						if (varType == "String" || varType == "Integer" || varType == "Float") {
							value = elem.value;

							if (validate) {
								if (is_required && value == "") {
									aras.AlertError(aras.getResource("", "inbasketvd.variable_required", varLabel), undefined, undefined, topWnd.window);
									return;
								}
							}
						}
						else if (varType == "Boolean") {
							value = elem.checked ? "1" : "0";
						}
						else if (varType == "List") {
							if (elem.options.selectedIndex != -1)
								value = elem.options[elem.options.selectedIndex].text;
							else {
								if (validate) {
									if (is_required && elem.options.length > 0) {
										aras.AlertError(aras.getResource("", "inbasketvd.variable_required", varLabel), undefined, undefined, topWnd.window);
										return;
									}
								}
							}
						}
					}

					body += "<Variable id='" + varID + "'>" + esc(value) + "</Variable>";
				}
				body += "</Variables>";

				body += "<Authentication mode='" + AuthMode + "'>" + hash + "</Authentication>";

				body += "<Comments>" + esc(document.getElementById("Comments").value) + "</Comments>";

				if (mode == "complete")
					body += "<Complete>1</Complete>";
				else if (mode == "save")
					body += "<Complete>0</Complete>";

				body += "</Item>";
				var result = "<AML>";
				var needForClearItem = false;
				if (mode == "save") {
					var valuesToAdd = MyAssItem.selectNodes('Relationships/Item[@type="Activity Task Value" and @action="add"]');
					var valuesList = getSequenceOrderArray(valuesToAdd);
					var tempBody = "";
					var tempTaskValue;
					for (var i = 0; i < valuesToAdd.length; i++) {
						tempTaskValue = valuesToAdd.item(valuesList[i].ind);
						tempBody += tempTaskValue.xml;
						needForClearItem = true;
					}
					result += tempBody;
				}
				result += body;
				result += "</AML>";

				// now OK to execute the Vote.
				var res = aras.soapSend("ApplyAML", result);
				if (res.isFault()) {
					if (res.getFaultCode() == "SOAP-ENV:Server.ItemIsLockedException") {
						var type = res.results.selectSingleNode("//detail/*[local-name()='item']/@type").value;
						var id = res.results.selectSingleNode("//detail/*[local-name()='item']/@id").value;
						if (CheckPermissionToLock(id, type)) {
							showLockItemDialog(id, type, function (action) {
								if (action === "btnUnlock" && unlockItem(id, type)) {
									completeActivity(mode);
								}
							});
							return;
						}
					}
					aras.AlertError(res, undefined, undefined, window);
				}
				else {
					if (mode == "save") {
						aras.itemsCache.deleteItem(MyAssID);
						if (needForClearItem) {
							aras.itemsCache.deleteItem(itemId);
						}
					}
					if (window.onCompleteHandler){
						window.onCompleteHandler(mode);
					}

					closeDialog({updated: true});
				}
			}
			processVote(MD5Auth);
		}

		function CheckPermissionToLock(id, type) {
			if (!aras.isAdminUser()) {
				//false if temp node of is not locked by current user.
				var itemNd = aras.getItemById(type, id);
				return aras.isLockedByUser(itemNd);
			}
			return true;
		}

		function unlockItem(id, type) {
			var win = aras.uiFindWindowEx(id);
			if (win) {
				return win.document.frames["tearoff_menu"].onClickMenuItem("unlock");
			}
			else {
				var item = aras.unlockItem(id, type);
				if (!item) {
					return false;
				}
			}
			return true;
		}

		function showLockItemDialog(id, type, callback) {
			var itemType = aras.getItemTypeForClient(type, "name");
			var itemTypeLabel = itemType.getProperty("label");
			var keyedName = aras.getKeyedName(id, type);
			var unlockDlgParams = {};
			unlockDlgParams.aras = aras;
			unlockDlgParams.title = aras.getResource("", "inbasketvd.unlock_dialog_title", itemTypeLabel);
			unlockDlgParams.message = aras.getResource("", "inbasketvd.unlock_dialog_message", itemTypeLabel, keyedName);
			unlockDlgParams.buttons = {
				btnUnlock: aras.getResource("", "common.unlock"),
				btnCancel: aras.getResource("", "common.cancel")
			};
			unlockDlgParams.callback = callback;
			unlockDlgParams.defaultButton = "btnCancel";
			unlockDlgParams.dialogHeight = 150;
			unlockDlgParams.dialogWidth = 450;
			unlockDlgParams.content = "groupChgsDialog.html"

			var win = aras.getMostTopWindowWithAras(window);
			var dialog = (win.main || win).ArasModules.MaximazableDialog.show("iframe", unlockDlgParams);
			dialog.promise.then(callback);
		}

	// Changes for AdHoc Workflow assigments - to same WF activity -  rolf 3 Apr 2020
	// based on older community project from peter 1.17.2008
	// this new approach is not creating a new workflow process to request help
	// it actually adds new assignment to activities in active workflow process

		var CurrentCol=0;   // used for the AdHoc grid  F2 and Tab function
		var CurrentRow="";   // used for the AdHoc grid  F2 and Tab function
		var OldValue="";
		var uniqueID=0;
		var clickedRow=0;
		var votersListHasChanged = false;
		var deletedVotersAssignmentIds="";
		var innovator = aras.newIOMInnovator();
		var userNd = aras.getLoggedUserItem();
		var identityNd = userNd.selectSingleNode("Relationships/Item[@type='Alias']/related_id/Item[@type='Identity']");
		var MyAliasId = identityNd.getAttribute("id");
		var	deletedRowTextColor = '#b0b0b0';

		// MyWflId is id of type "Workflow Process" that is the "related_id" of "Workflow" that has a prop "source_type" that is the type of the controlled item
		// itemId - from dialog'S arguments is the id of the controlled item
		var wflItem = aras.newIOMItem("Workflow","get");
		wflItem.setAttribute("select","source_type");
		wflItem.setProperty("related_id",MyWflId); // workflow process id
		wflItem = wflItem.apply();
		var controlledItemType = wflItem.getPropertyAttribute("source_type","keyed_name","");
		var controlledItemNd = aras.getItemById(controlledItemType, itemId);
		var ownedById = aras.getItemProperty(controlledItemNd,"owned_by_id","");
		var MyIdentityList = aras.getIdentityList(); // identities this user is a member of
		var MyUserCanEdit = (MyIdentityList.indexOf(ownedById) >= 0);
		
		// if current user not ownwer of controlledItem, hide add, delete, save buttons	
		function enableVoterModification() {
			// check if current user is the owner of the controlled item
			if (MyUserCanEdit) {
				var el = document.getElementById("VoterModificationBouttons");
				if (el) {
					el.style.display = "block";
				}
			}
		}

		function viewVoters() {
			VoteSection.style.display = 'none';
			VoterSection.style.display = 'block';
			AuthSection.style.display = 'none';
			ButtonSection.style.display = 'none';
			
			enableVoterModification();

			if(votersgrid == null){
				clientControlsFactory.createControl("Aras.Client.Controls.Public.GridContainer", {id: "votersgrid", connectId: "votersgridTD"}, function (control) {
					votersgrid = control;

					votersgrid.setLayout_Experimental([
					{ field: "assignid", name: "Name", width: "20%", styles: "text-align: left;text-color: #000000;", headerStyles: "text-align: center;", editable: false },
					{ field: "voter_is_required", name: "Required", width: "10%", styles: "text-align: center;", headerStyles: "text-align: center;", editable: true },
					{ field: "voter_voting_weight", name: "Voting Weight", width: "18%", styles: "text-align: center;", headerStyles: "text-align: center;", editable: true },
					{ field: "voter_is_adhoc", name: "Adhoc", width: "7%", styles: "text-align: center;", headerStyles: "text-align: center;", editable: false },
					{ field: "voter_how_voted", name: "How Voted", width: "15%", styles: "text-align: left;", headerStyles: "text-align: center;", editable: false },
					{ field: "voter_comment", name: "Comments", width: "15%", styles: "text-align: left;", headerStyles: "text-align: center;", editable: false },
					{ field: "voter_escalate_to", name: "Escalate To", width: "15%", styles: "text-align: left;", headerStyles: "text-align: center;", editable: false }
					]);

					clientControlsFactory.on(votersgrid, {
						"gridClick": function (rowID, column) {
							onVoterGridEditCell(rowID, column);
						}
					});
			
					populateExistingVoters();	
				});

			}
		}

		function populateExistingVoters() {
			votersListHasChanged = false;
			
			// get current assignment of MyActivity
			if (!(MyActivity)) return;
			
			// fetch all assignments of this activity
			var actAssignments = aras.newIOMItem("");
			actAssignments.loadAML("<Item type='Activity Assignment' action='get' select='*' ><source_id>"+MyActId+"</source_id></Item>");
			actAssignments = actAssignments.apply();

			CurrentRow=uniqueID+1;
			CurrentCol = 0;
			for (var i = 0; i < actAssignments.getItemCount(); i++) {
				var actAssignment = actAssignments.getItemByIndex(i);
				
				voterList.push( { uniqueId: ++uniqueID, assignid: '', voter_is_required: '', voter_voting_weight: '0', voter_escalate_to: '', voter_is_adhoc:  '', voter_how_voted: '', voter_comment: '' } );
				votersgrid.setArrayData_Experimental(voterList);
				
				var identityKN = actAssignment.getPropertyAttribute("related_id","keyed_name","");
				
				votersgrid.cells(uniqueID,0).setValue(identityKN); 
				votersgrid.setUserData(uniqueID,"assignid",actAssignment.getProperty("related_id",""));
				votersgrid.setUserData(uniqueID,"assignkn",identityKN);
				
				votersgrid.setUserData(uniqueID,"voter_is_required",actAssignment.getProperty("is_required","0"));
				votersgrid.cells(uniqueID,1).setValue((actAssignment.getProperty("is_required","0") == "1"));
				
				votersgrid.setUserData(uniqueID,"voter_voting_weight",actAssignment.getProperty("voting_weight","0"));
				votersgrid.cells(uniqueID,2).setValue(actAssignment.getProperty("voting_weight","0"));
				
				votersgrid.setUserData(uniqueID,"voter_is_adhoc",actAssignment.getProperty("is_adhoc","0"));
				votersgrid.cells(uniqueID,3).setValue((actAssignment.getProperty("is_adhoc","0") == "1"));

				votersgrid.cells(uniqueID,4).setValue(actAssignment.getProperty("path",""));
				votersgrid.cells(uniqueID,5).setValue(actAssignment.getProperty("comments",""));
				
				votersgrid.setUserData(uniqueID,"voter_escalate_to",actAssignment.getProperty("assigned_to",""));
				votersgrid.cells(uniqueID,6).setValue(actAssignment.getPropertyAttribute("assigned_to","keyed_name",""));

				votersgrid.setUserData(uniqueID,"closed_on",actAssignment.getProperty("closed_on","open"));
				votersgrid.setUserData(uniqueID,"actAssignmentId",actAssignment.getID());
			}
		}

		function backFromViewVoters() {
			if (votersListHasChanged) {
				if (aras.confirm("Voters list has changed. Do you want to save the changes ?")) { //  // ## TODO I18N ##
					saveVotingChanges(true);
					return;
				}
			}
			votersgrid.turnEditOff();
			VoteSection.style.display = 'block';
			VoterSection.style.display = 'none';
			AuthSection.style.display = 'block';
			ButtonSection.style.display = 'block';
		}

		function delVoter() {
			if (!MyUserCanEdit) {return;}
			
			var rows = votersgrid.getSelectedItemIDs('|');

			var id_array = rows.split("|");
			for (i=0; i<id_array.length; i++) {
				var row = id_array[i];
			
				var rowIsAdhoc = (votersgrid.getUserData(row,"voter_is_adhoc") != "1");
				
				// can not delete own assignments (of current user)
				var assignedIdentity = votersgrid.getUserData(row,"assignid");
				if (rowIsAdhoc && assignedIdentity == MyAliasId) {
					aras.AlertError("Cannot delete your own voter!");  // ## TODO I18N ##
					return;
				}
				// can only delete newly added rows
				if (votersgrid.getUserData(row,"closed_on") != "open") {
					aras.AlertError("Cannot delete this voter! This Voters has already voted.");  // ## TODO I18N ##
					return;
				}
				if (!rowIsAdhoc) {
					if (!aras.confirm("Contiune deleting a non-adhoc user !")) {  // ## TODO I18N ##
						return;
					}
				}
				
				// do the delete
				var id = votersgrid.getUserData(row,"actAssignmentId");
				if (id != "add") {
					deletedVotersAssignmentIds += ","+id;
				}
				votersgrid.deleteRow(row);   // ## TODO ## grey out deleted rows instead of removing from grid !
				/*
				for (var j=0; j<votersgrid.GetColumnCount(); j++){
					//## SetCellTextColor thows an error .. it cannot find 'style' of cell
					votersgrid.SetCellTextColor(row, j, deletedRowTextColor);
				}
				*/
				votersgrid.setUserData(row,"row_is_deleted","1");
				votersgrid.turnEditOff();
			}
			votersListHasChanged = true;
		}

		function addVoter(rowExists) {
			if (!MyUserCanEdit) {return;}

			if (rowExists) {
				clickedRow = votersgrid.getSelectedId();
			} else {
				clickedRow = 0;
			}
			setTimeout('lookupAssignee()',1);
			lookupAssignee(col);  // starts search dialog
		}

		function addSelectedVoter(itemID, keyed_name) {
			var row;
			if (clickedRow == 0) {
				voterList.push( { uniqueId: ++uniqueID, assignid: '', voter_is_required: '', voter_voting_weight: '0', voter_escalate_to: '', voter_is_adhoc:  '', voter_how_voted: '', voter_comment: '' } );
				votersgrid.setArrayData_Experimental(voterList);
				
				row = uniqueID;
				var userNd = aras.getLoggedUserItem();
				var identityNd = userNd.selectSingleNode("Relationships/Item[@type='Alias']/related_id/Item[@type='Identity']");
				
				votersgrid.setUserData(row,"voter_escalate_to",identityNd.getAttribute("id"));
				votersgrid.cells(row,6).setValue(top.aras.getItemProperty(identityNd,"keyed_name"));

				votersgrid.setUserData(uniqueID,"voter_is_adhoc", "1");
				votersgrid.cells(uniqueID,3).setValue(true);
			
				votersgrid.setUserData(row,"voter_voting_weight","0");  // default weight -- means voter is CC only - no voting required for this activity
				votersgrid.cells(row,2).setValue("0");

				votersgrid.setUserData(row,"voter_is_required","1");  // default to required -- user can reset this before saving
				votersgrid.cells(row,1).setValue(true);

				votersgrid.setUserData(row,"closed_on","open");
				votersgrid.setUserData(row,"actAssignmentId","add");
			}
			else {
				row = clickedRow;
			}
			votersgrid.cells(row,0).setValue(keyed_name);
			votersgrid.setUserData(row,"assignid",itemID);
			votersgrid.setUserData(row,"assignkn",keyed_name);
			
			votersListHasChanged = true;

			CurrentCol = 0;
			CurrentRow=row;
		}
		
		function lookupAssignee() {
			var params = { aras: window.aras, itemtypeName: "Identity", type: "SearchDialog" };
			var win = aras.getMostTopWindowWithAras(window);
			var dialog = (win.main || win).ArasModules.MaximazableDialog.show("iframe", params);
			dialog.promise.then(function (dlgRes) {
				if (!dlgRes) {
					return;
				}
				if (dlgRes.itemID == "" || dlgRes.keyed_name == "") {
				  return;
				}
				addSelectedVoter(dlgRes.itemID, dlgRes.keyed_name);
			});
		}
		
		function updateContextOfEditableCellsOfAdhocRows() {
			//return true, if changes found
			var changesFound = false;
			var ids =votersgrid.getAllItemIds("|");
			var id_array = ids.split("|");
			for (i=0; i<id_array.length; i++) {
				var row = id_array[i];
		
				var prevVal;
				var currVal;
				if (votersgrid.getUserData(row,"voter_is_adhoc") == "1") {
					
					// voter_is_required
					prevVal = (votersgrid.setUserData(row,"voter_is_required") == "1");
					currVal = votersgrid.cells(row,1).getValue();
					if (currVal != prevVal) {
						votersgrid.setUserData(row,"voter_is_required", currVal ? '1' : '0');
						changesFound = true;
					}

					// voter_voting_weight
					prevVal = votersgrid.setUserData(row,"voter_voting_weight");
					currVal = votersgrid.cells(row,2).getValue();
					if (currVal != prevVal) {
						votersgrid.setUserData(row,"voter_voting_weight", currVal);
						changesFound = true;
					}
				}
			}
			return changesFound;
		}

		function onVoterGridEditCell(row, col) {
			clickedRow = row;
		
			var rowIsFrozen = (votersgrid.getUserData(row,"voter_is_adhoc") != "1");
			rowIsFrozen = (rowIsFrozen || votersgrid.getUserData(row,"closed_on") != "open");
			rowIsFrozen = (rowIsFrozen || votersgrid.getUserData(row,"row_is_deleted") == "1");
			rowIsFrozen = (rowIsFrozen || !MyUserCanEdit);

			if (rowIsFrozen) {
				// redo edits
				var  oldVal;

				switch (col) {
				case 0:
					oldVal = votersgrid.getUserData(row,"assignedkn");
					break;
				case 1:
					oldVal = (votersgrid.getUserData(row,"voter_is_required") == "1");
					break;
				case 2:
					oldVal = votersgrid.getUserData(row,"voter_voting_weight");
					break;
				}
				votersgrid.cells(row,col).setValue(oldVal);
				top.aras.AlertError("You cannot edit this row!");  // ## TODO I18N ##
				return;
			}
			switch(col) {
				case 0:  // assignedid
					addVoter(true);
					break;
				case 1:  // is required
					votersgrid.setUserData(row,"voter_is_required", votersgrid.cells(row,1).getValue() ? '1' : '0');
					votersListHasChanged = true;
					break;
				default:
					votersListHasChanged = true;
					break;
			}
		}

		function onKeyPressed( kEv ) {
			if (!MyUserCanEdit) {return false;}
			
			var keyCode = kEv.keyCode;
			if (keyCode == 155) {  // Insert
				if (MyIdentityList.indexOf(ownedById) < 0) {
					top.aras.AlertError("You do not have permissions to perform this action. You must be member of Owner of this '"+controlledItemType+"' !");  // ## TODO I18N ##
					return false;
				}
				addVoter(false);
			}
			if (keyCode == 113) {  // F2 Lookup key for Dialogs
				if (clickedRow != 0) {
    				if (votersgrid.getUserData(clickedRow,"row_is_deleted") == "1" || votersgrid.getUserData(clickedRow,"closed_on") != "open") {
    					return false;
    				}
				}
				if (CurrentCol == 0) {
					votersgrid.turnEditOff();
					addVoter(true);
				}
			}
			return true;
		}

		function saveVotingChanges(ignoreConfirm)  {
			if (!ignoreConfirm) {
				if (!aras.confirm("Continue saving changes to the Voters list ?")) { //  // ## TODO I18N ##
					return;
				}
			}
			votersgrid.turnEditOff();

			var row = "";
			var ids =votersgrid.getAllItemIds("|");
			var id_array = ids.split("|");
			var assignedIdentity;
			MyIdentityCount=0;
			for (i=0; i<id_array.length; i++) {
				row = id_array[i];
				assignedIdentity = votersgrid.getUserData(row,"assignid");
				
				if (assignedIdentity == MyAliasId) {
					MyIdentityCount++;
				}
				if (MyIdentityCount > 1) {
					aras.AlertError("You cannot add yourself multiple times !");  // ## TODO I18N ##
					return;
				}
			}
			
			// updates context to current values
			updateContextOfEditableCellsOfAdhocRows();

			// read data from voters grid
			var aml = "<Item type='Activity' id='"+MyActId+"'><Relationships>";
			var i;
			for (i=0; i<id_array.length; i++) {
				row = id_array[i];
				
				assignedIdentity = votersgrid.getUserData(row,"assignid");
				var rowIsFrozen = (votersgrid.getUserData(row,"voter_is_adhoc") != "1");
				rowIsFrozen = (rowIsFrozen || votersgrid.getUserData(row,"closed_on") != "open");
				
				if (!rowIsFrozen && assignedIdentity != MyAliasId) {
					aml += "<Item type='Activity Assignment' ";
					var id = votersgrid.getUserData(row,"actAssignmentId");
					if (id == "add") {
						aml += "action='add' >";
					}
					else {
						aml += "action='merge' id='"+id+"' >";
					}
					aml += "<source_id>"+MyActId+"</source_id>";
					aml += "<related_id>"+assignedIdentity+"</related_id>";
					var cellVal;

					cellVal = votersgrid.getUserData(row,"voter_is_required");
					aml += "<is_required>"+cellVal+"</is_required>";

					cellVal = votersgrid.cells(row,2).getValue();  // col of voter_voting_weight
					aml += "<voting_weight>"+cellVal+"</voting_weight>";
					
					cellVal = votersgrid.getUserData(row,"voter_is_adhoc");
					aml += "<is_adhoc>"+cellVal+"</is_adhoc>";
					
					aml += "</Item>";
				}
			}
			// add assignments to be deleted
			id_array = deletedVotersAssignmentIds.split(",");
			for (i=1; i<id_array.length; i++) {
				aml += "<Item type='Activity Assignment' action='delete' id='"+id_array[i]+"' >";
				aml += "</Item>";
			}
			aml += "</Relationships></Item>";
			
			var callServerMethod = aras.newIOMItem("");
			callServerMethod.loadAML(aml);
			
			callServerMethod = callServerMethod.apply("AddOrDelete_AdHoc_WFAssignments");
			if (callServerMethod.isError()) {
				aras.AlertError(callServerMethod.getErrorString());
			}
			aras.AlertSuccess("Voters list of this Activity got updated !");
			//backFromViewVoters();
			
			// close completion dialog
			closeDialog();
		}
	// end of - Changes for AdHoc Workflow assigments

	</script>

	</head>
	<body class="claro">
	<div class="dialogContainer">
		<div id="TitleSection" class="logicalSection">
			<font style="font-family: Arial, Helvetica, sans-serif; font-size: 12pt"><b aras_ui_resource_key="inbasketvd.workflow_activity_completion"></b></font>
			<div style="text-align: center; height: 8px">
				<div style="vertical-align: middle; display: inline-block; height: 1px; width: 180px; background: #D4D4D4;"></div>
			</div>
			<table width="100%" cellpadding="0" cellspacing="0" cols="2">
				<tr>
					<td align="right" width="50%" class="logicalSubSection" style="padding-right: 5px">
						<b aras_ui_resource_key="inbasketvd.workflow"></b>
					</td>
					<td id="WorkflowNameCell" align="left" class="logicalSubSection">
					</td>
				</tr>
				<tr>
					<td align="right" width="50%" style="padding-right: 5px">
						<b aras_ui_resource_key="inbasketvd.activity"></b>
					</td>
					<td id="ActivityLabelCell" align="left">
					</td>
				</tr>
			</table>
		</div>
		<div id="TasksSection" class="logicalSection">
			<fieldset>
				<legend aras_ui_resource_key="inbasketvd.tasks"></legend>
				<div id="gridTD" style="height: 100px;">
				</div>
			</fieldset>
		</div>
		<div id="VariablesSection" class="logicalSection">
			<fieldset>
				<legend aras_ui_resource_key="inbasketvd.variables"></legend>
				<div style="max-height: 100px; overflow: auto;">
					<table id="VariablesTable" cellpadding="0" cellspacing="0" border="0">
					</table>
				</div>
			</fieldset>
		</div>

	<!--  Changes for AdHoc Workflow assigments - added for the AdHoc Voters logic -->
		<div id="VoterSection" style="display: none" class="logicalSection">
		  <FIELDSET>
		    <legend>assigned Voters</legend>
				<div id="VoterModificationBouttons" style="display: none" >
				<table><tr style="height:30px;">
					<td style="margin-left: 10px"><a id="addVoter" href="javascript:addVoter();" title="Add Voter"><img src="../../images/NewRow.svg" style="width:22px;height:22px;" /></a></td>
					<td style="margin-left: 10px"><a id="delVoter" href="javascript:delVoter();" title="Delete Voter"><img src="../../images/DeleteRow.svg" style="width:22px;height:22px;" /></a></td>
					<td style="margin-left: 10px"><a id="saveVotingChanges" href="javascript:saveVotingChanges();" title="Save Changes"><img src="../../images/Save.svg" style="width:22px;height:22px;"/></a></td>
				</tr></table>
				</div>
				<div id="votersgridTD" style="height: 100px; width: 600px;">
				
				</div>
				<div style="margin-left:5px;" >
					<button class="btn" id="Back" onClick="backFromViewVoters()">Back</button>
				</div>
		  </FIELDSET>
		</div>
    <!-- end of Changes for AdHoc Workflow assigments -->

		<div id="VoteSection" class="logicalSection">
			<fieldset>
				<legend aras_ui_resource_key="inbasketvd.vote"></legend>
				<table cellpadding="0" border="0" cellspacing="0" width="100%" cols="4">
					<tr>
						<td align="right">
							<b aras_ui_resource_key="inbasketvd.vote_with_colon"></b>&nbsp;
						</td>
							<td>
							<div id="div_select_VoteList" class="sys_f_div_select">
								<select id="VoteList" class="sys_f_select" size="1" width="20" onchange="onChangeVote();">
								</select>
								<span id="selected_option_VoteList" class="sys_f_span_select"></span>
							</div>
						</td>
						<td align="right">
							<b aras_ui_resource_key="inbasketvd.delegate_to"></b>&nbsp;
						</td>
						<td>
							<input type="text" id="delegate" size="30" class="dynamicBkColor" onkeydown="delegateOnKeydown(event)" onfocusout="doSearchIdentity()" />
							<img id="delegate_img" align="absmiddle" src="../../images/Ellipsis.svg" style="width: auto; height: auto; max-height: 18px; max-width: 18px; display: inline; cursor: pointer;" onclick="delegateClick()" />
						</td>
						<!--  	<!--  Changes for AdHoc Workflow assigments - added next TD for the AdHoc Voters logic -->
							<TD align="LEFT" style="margin-left: 10px">
								<input type="button" class="btn" name="AdHoc Assignments"  value="View Other Voters" onClick="viewVoters()">
							</TD>
				        <!-- end of 	<!--  Changes for AdHoc Workflow assigments - added for the AdHoc Voters logic -->
					</tr>
					<tr>
						<td align="right" class="logicalSubSection2">
							<br />
							<b aras_ui_resource_key="inbasketvd.comments"></b>&nbsp;<br />
						</td>
						<td colspan="4" class="logicalSubSection2">
							<textarea id="Comments" style="overflow:auto; width:415px; height:30px; resize:none; border:1px solid #808080"></textarea>
						</td>
					</tr>
				</table>
			</fieldset>
		</div>
		<div id="AuthSection" class="logicalSection" align="center">
			<fieldset>
				<legend aras_ui_resource_key="inbasketvd.authentication"></legend>
				<table cellpadding="0" cellspacing="0" border="0" width="90%" cols="4">
					<tr>
						<td align="right" class="password">
							<b aras_ui_resource_key="inbasketvd.password"></b>&nbsp;
						</td>
						<td align="left" class="password">
							<input type="password" name="password" size="25" class="dynamicBkColor" autocomplete="new-password">
						</td>
						<td align="right">
							<b aras_ui_resource_key="inbasketvd.e_signature"></b>&nbsp;
						</td>
						<td align="left">
							<input type="password" name="esignature" size="30" class="dynamicBkColor" autocomplete="new-password">
						</td>
					</tr>
				</table>
			</fieldset>
		</div>
		<div id="ButtonSection" class="logicalSubSection" align="center" style="padding-bottom: 15px;">
			<input type="button" class="btn" id="completeButton" name="Complete" aras_ui_resource_key="inbasketvd.complete_html_value" onclick="doComplete()" />
			<input type="button" class="btn" id="saveButtom" name="Save" aras_ui_resource_key="inbasketvd.save_changes_html_value" style="margin-left: 10px" onclick="saveChanges()" />
			<input type="button" class="btn cancel_button" name="Cancel" aras_ui_resource_key="inbasketvd.cancel_html_value" style="margin-left: 10px" onclick="cancelVote()" />
		</div>
	</div>
	<script type="text/javascript">
		PopulateDocByLabels();
	</script>
</body>
</html>