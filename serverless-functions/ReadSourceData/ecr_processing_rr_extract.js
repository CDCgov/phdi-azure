// Create the output message 
var next = output.append(input[0]);

//Populate the Orgiginal Doc Type Code property
//Get template code count 	
var templateCount = next.getRepeatCount('/ClinicalDocument/templateId');

//Declare variables used in processing the Orig_Doc_Type_eICR property 
var compareflag;
var DocTypeCode;
var DocTypeCodeFlag;

// loop through all interations of template count
for (var i = 1; i <= templateCount; i++) {


//Extracting extension value 
	var extensionCode = next.getField('/ClinicalDocument/templateId[' + i + ']/@extension');
	var rootCode = next.getField('/ClinicalDocument/templateId[' + i + ']/@root');
	//log.info("extensionCode: " + extensionCode);
	//log.info("rootCode: " + rootCode);
	
	
	if (extensionCode != null && compareflag != "true" ) {
		var compare1 = extensionCode;
		var root1 = rootCode;
		//log.info("one: " + compare1);
		compareflag = "true";
	}
	else if (extensionCode != null && compareflag == "true" ) {
		var compare2 = extensionCode;
		var root2 = rootCode;
		//log.info("two: " + compare2);
		compareflag = "true";
	}
// } probably this brace is misplaced? - GH
//Only one template root and one extension code
	if (compare2 == undefined && compare1 != undefined){
		DocTypeCode = root + "^" + compare1;
		next.setProperty("Orig_Doc_Type_eICR", DocTypeCode);
		//log.info("one extension and one root: " + rootCode + "^" + compare1 );
	} else {	
//Compare two extension codes 
		if (compare1 >= compare2) {
			DocTypeCode = root1 + "^" + compare1;
			next.setProperty("Orig_Doc_Type_eICR", DocTypeCode);
							
			DocTypeCodeFlag = "true";
		} else if (compare2 >= compare1) {
			DocTypeCode = root2 + "^" + compare2;
			next.setProperty("Orig_Doc_Type_eICR", DocTypeCode);	   
							
			DocTypeCodeFlag = "true";
		}
//Extract template root if extension code is not present 						
		if(extensionCode == null && DocTypeCodeFlag != "true" ) {
			next.setProperty("Orig_Doc_Type_eICR", rootCode); 
		}
	}
} // Guessing this should close the for loop? - GH
		
//Extracting the relevant jurisdictions
var jurisdiction = next.getProperty("jurisdiction");
	
//Making the rr parsable
var rrXML = input[1];


// Extract the software name and create property system_nm
var system_nm;
var tempdisplayName;
var tempSoftwareName;

tempdisplayName = next.getField('/ClinicalDocument/author/assignedAuthor/assignedAuthoringDevice/softwareName/@displayName');
tempSoftwareName = next.getField('/ClinicalDocument/author/assignedAuthor/assignedAuthoringDevice/softwareName');

if (tempdisplayName == null ) {
	system_nm = tempSoftwareName;
}  else {
	system_nm = tempdisplayName;
} 

if (system_nm == "" || system_nm == null) {
	var  Lookuptable = lookup("ConstantLookup", {QuestionIdentifier: 'AUT102'});	
	system_nm = Lookuptable.SampleValue;
	next.setProperty("system_nm", system_nm);
} else {
	next.setProperty("system_nm", system_nm);
}


//Defining variable for reportble conditions
var rrOutput = "";

//Calling function to extract reportable conditions
var reportableOutput = extractReportables(rrXML, rrOutput);

next.setProperty("reportableOutput", reportableOutput);


function extractReportables(rrXML, rrOutput){
	
	//Determining the total number of Components in document
	var componentLength = rrXML.getRepeatCount('/ClinicalDocument/component/structuredBody/component');

	//Looping through all of the components
	for (var i = 1; i <= componentLength; i++) {
	
		//Determining the total number of entries in current component
		var entryLength = rrXML.getRepeatCount('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry');
	
		//Looping through all of the entries
		for (var j = 1; j <= entryLength; j++) {
		
			//Determining the total number of entries in current component
			var subCompLength = rrXML.getRepeatCount('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/organizer/component');
	
			//Looping through all of the components within the entry
			//This is the level that will repeat if there are multiple reportable conditions
			for (var k = 1; k <= subCompLength; k++) {
				
				//Grabing Observation Code
				var obsCode = rrXML.getField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/organizer/component[' + k + ']/observation/code/@code');
		
				//Grabing Observation Translation Code
				var obsTransCode = rrXML.getField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/organizer/component[' + k + ']/observation/code/translation/@code');
				    
		
				//Grabing Participant Role ID Extension to verify jurisdiction
				var obsPartRoleExt = rrXML.getField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/organizer/component[' + k + ']/observation/entryRelationship/organizer/participant[' + 1 + ']/participantRole/id/@extension');
				
				
				if((obsCode == '64572001' || obsTransCode == '75323-6') && obsPartRoleExt == jurisdiction){
					
				//log.info("Inside code if");
					//Code
					var valueCode = rrXML.getField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/organizer/component[' + k + ']/observation/value/@code');
					
					//codeSystem
					var valueCodeSystem = rrXML.getField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/organizer/component[' + k + ']/observation/value/@codeSystem');
					
					//CodeSystemName
					var valueCodeSystemName = rrXML.getField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/organizer/component[' + k + ']/observation/value/@codeSystemName');
					
					//displayName
					var valueDisplayName = rrXML.getField('/ClinicalDocument/component/structuredBody/component[' + i + ']/section/entry[' + j + ']/organizer/component[' + k + ']/observation/value/@displayName');
					
					if(rrOutput == ""){
						rrOutput = valueCode + "|" + valueCodeSystem + "|" +  valueCodeSystemName + "|" +  valueDisplayName;
						
					}
					else{
					//log.info("Inside rr else");
						rrOutput = rrOutput + "_____" + valueCode + "|" + valueCodeSystem + "|" +  valueCodeSystemName + "|" +  valueDisplayName;
					}
						
					//return rrOutput;
				
				}
			}//End Sub Component Loop
		}//End Entry Loop
	} return rrOutput; //End component Loop
}