/* Single input message case */
// Create the output message 
var next = output.append(input[0]);

//Extracting the property that contains the reportble conditions from the rr
var rr = next.getProperty('reportableOutput');
var ProblemencountersFlag = next.getProperty('ProblemencountersFlag');

//Adding rrXML to the output message
if(rr != null){
	
	//Creating an array
	var reportablesArray = rr.split("_____");
		
	//Looping through all of the reportables
	for (var r = 0; r <= reportablesArray.length - 1; r++) {
		 
		//Creating and array of fields
		var fieldArray = reportablesArray[r].split("|");
		
		//Extracting fields from array
		var code = fieldArray[0].toString();
		var codeSystem = fieldArray[1].toString();
		var codeSystemName = fieldArray[2].toString();
		var displayName = fieldArray[3].toString();
		
		//Determining the total number of Components in document
		var componentLength = next.getRepeatCount('/ClinicalDocument/component/structuredBody/component');
		
		//Looping through all of the components
		for (var i = 1; i <= componentLength; i++) {
			
			//Extracting template id, which will be used to verify relevant section
			var componentCode = next.getField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/code/@code');
			
			/*     ----------     ----------     ----------     ----------     Problems     ----------     ----------     ----------     ----------     */
			
			//Determining number of entries in the problem component
			var problemEntryLength = next.getRepeatCount('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry');			
			
			//Finding the Problems section by code
			if(componentCode == "11450-4" && problemEntryLength >= 1){
				for (var j = 1; j <= problemEntryLength; j++) {
					var currentTime = currentDateUTC();
									
					//ClinicalDocument/component/structuredBody/component/section/text/paragraph
					next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/text/paragraph', "One or more reportable conditions added to problem list during processing");
					if (j == problemEntryLength && ProblemencountersFlag == "true"){
						
						//Insert Template
						var entryRelEntryLength = next.getRepeatCount('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/encounter/entryRelationship/act/entryRelationship');	
						var n = parseInt(entryRelEntryLength) + 1;
						//Call function to create entryRelationship in eICR
						createEncounterEntryRelationship(code, codeSystem, codeSystemName, displayName, problemEntryLength, n);
						
					}//Close ProblemEngryLength if 
					else if (j == problemEntryLength && ProblemencountersFlag != "true"){
					
						//Insert Template
						var entryRelEntryLength = next.getRepeatCount('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/act/entryRelationship');	
						var n = parseInt(entryRelEntryLength) + 1;
						//Call function to create entryRelationship in eICR
						createEntryRelationship(code, codeSystem, codeSystemName, displayName, problemEntryLength, n);
						
					}//Close ProblemEngryLength if
				}//Close Component if
			}	else if (componentCode == "11450-4" && problemEntryLength == 0) {
				
						var currentTime = currentDateUTC();
						
						//ClinicalDocument/component/structuredBody/component/section/text/paragraph
						next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/text/paragraph', "adding reportable conditions to problem list during processing");
				
						//Insert Template
						var j = parseInt(problemEntryLength) + 1;
				
						//Call function to create entry in eICR
						createEntry(code, codeSystem, codeSystemName, displayName, j);
				
				}//Close else if
		}//Close Component for
	}//Closing reportables loop
}//Close RR Null if

	//set message to property
	next.setProperty("XMLmessage", next.text);

function createEntry(code, codeSystem, codeSystemName, displayName, entryIndex){
	
	//ACT
	next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/@classCode', "ACT");
	next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/@moodCode', "EVN");
	
		//Template IDs
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/templateId[' + 1 + ']/@root', "2.16.840.1.113883.10.20.22.4.3");
		
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/templateId[' + 2 + ']/@extension', "2015-08-01");
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/templateId[' + 2 + ']/@root', "2.16.840.1.113883.10.20.22.4.3");
		
		//ID
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/id/@extension', "8745579-concern");
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/id/@root', "1.2.840.114350.1.13.199.2.7.2.768076");
		
		//Code
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/code/@code', "CONC");
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/code/@codeSystem', "2.16.840.1.113883.5.6");
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/code/@codeSystemName', "HL7ActClass");
		
		//Status Code
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/statusCode/@code', "active");
		
		//Effective Time
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/effectiveTime/low/@value', currentDateUTC());
		
		//Entry Relationship
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/@typeCode', "SUBJ");
		
			//Observation
			next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/@moodCode', "EVN");
			next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/@classCode', "OBS");
			next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/@negationInd', "false");
				
				//Template Ids
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/templateId[' + 1 + ']/@root', "2.16.840.1.113883.10.20.22.4.4");
				
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/templateId[' + 2 + ']/@root', "2.16.840.1.113883.10.20.22.4.4");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/templateId[' + 2 + ']/@extension', "2015-08-01");

				//Id
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/id/@root', uuidv4());
				
				
				//Code
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/code/@code', "41813009"); 
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/code/@codeSystem', "2.16.840.1.113883.6.96");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/code/@codeSystemName', "SNOMED");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/code/@displayName', "Patient condition finding (finding)");
				
				//Status Code
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/statusCode/@code', "completed");
				
				//Effective Time
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/effectiveTime/low/@value', currentDateUTC());
				
				//Value
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/value/@xmlns:xsi', "http://www.w3.org/2001/XMLSchema-instance");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/value/@code', code);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/value/@displayName', displayName);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/value/@codeSystem', codeSystem);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/value/@codeSystemName', codeSystemName);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship/observation/value/@xsi:type', "CD");
}

function createEntryRelationship(code, codeSystem, codeSystemName, displayName, entryIndex, entryRelIndex){
		
		//Entry Relationship
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/@typeCode', "SUBJ");
		
			//Observation
			next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/@moodCode', "EVN");
			next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/@classCode', "OBS");
			next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/@negationInd', "false");
				
				//Template Ids
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/templateId[' + 1 + ']/@root', "2.16.840.1.113883.10.20.22.4.4");
				
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/templateId[' + 2 + ']/@root', "2.16.840.1.113883.10.20.22.4.4");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/templateId[' + 2 + ']/@extension', "2015-08-01");
				
				//Id
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/id/@root', uuidv4());
				
				//Code
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/code/@code', "41813009"); 
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/code/@codeSystem', "2.16.840.1.113883.6.96");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/code/@codeSystemName', "SNOMED");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/code/@displayName', "Patient condition finding (finding)");
				
				//Status Code
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/statusCode/@code', "completed");
				
				//Effective Time
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/effectiveTime/low/@value', currentDateUTC());
				
				//Value
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/value/@xmlns:xsi', "http://www.w3.org/2001/XMLSchema-instance");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/value/@code', code);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/value/@displayName', displayName);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/value/@codeSystem', codeSystem);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/value/@codeSystemName', codeSystemName);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/act/entryRelationship['+ entryRelIndex +']/observation/value/@xsi:type', "CD");
}
function createEncounterEntryRelationship(code, codeSystem, codeSystemName, displayName, entryIndex, entryRelIndex){
		
		//Entry Relationship
		next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/@typeCode', "SUBJ");
		
			//Observation
			next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/@moodCode', "EVN");
			next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/@classCode', "OBS");
			next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/@negationInd', "false");
				
				//Template Ids
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/templateId[' + 1 + ']/@root', "2.16.840.1.113883.10.20.22.4.4");
				
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/templateId[' + 2 + ']/@root', "2.16.840.1.113883.10.20.22.4.4");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/templateId[' + 2 + ']/@extension', "2015-08-01");
				
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/templateId[' + 3 + ']/@root', "2.16.840.1.113883.10.20.15.2.3.3");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/templateId[' + 3 + ']/@extension', "2016-12-01");
				
				//Id
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/id/@root', uuidv4());
				
				//Code
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/code/@code', "41813009"); 
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/code/@codeSystem', "2.16.840.1.113883.6.96");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/code/@codeSystemName', "SNOMED");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/code/@displayName', "Condition");
				
				//Status Code
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/statusCode/@code', "completed");
				
				//Effective Time
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/effectiveTime/low/@value', currentDateUTC());
				
				//Value
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/value/@xmlns:xsi', "http://www.w3.org/2001/XMLSchema-instance");
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/value/@code', code);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/value/@displayName', displayName);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/value/@codeSystem', codeSystem);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/value/@codeSystemName', codeSystemName);
				next.setField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry['+ entryIndex +']/encounter/entryRelationship/act/entryRelationship['+ entryRelIndex +']/observation/value/@xsi:type', "CD");
}
					
function currentDateUTC(){
	
	//Get the current date/time
	var mydate		=	new Date();
	var hours	=	mydate.getUTCHours();
	var minutes	=	mydate.getUTCMinutes();
	var seconds	=	mydate.getUTCSeconds();
	var milliseconds = mydate.getUTCMilliseconds();
	var year = mydate.getUTCFullYear();
	var month = mydate.getUTCMonth() + 1; //This returns 0 - 11. We have to increment by one to get accurate month
	if(month <= 9)
    month = '0'+month;
	var day = mydate.getDate();
	if(day <= 9)
    day = '0'+day;
	
	var now = year.toString() + month.toString() + day.toString();
	return now;	
}

function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}