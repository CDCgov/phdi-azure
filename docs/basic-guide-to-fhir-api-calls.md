
### Basic guide to FHIR Server REST calls:
Once you have data in your FHIR server you can access it through REST API calls. Below are SOME examples of calls you can make.
For additional information visit the [Microsoft FHIR API docs](https://learn.microsoft.com/en-us/azure/healthcare-apis/fhir/fhir-rest-api-capabilities) and/or the [HL7 FHIR Docs site](https://build.fhir.org/).

#### Prerequisites:
- Access to Azure FHIR server

- Azure cli tool

  - Auth Bearer token (autoexpires and may need regeneration every 60~90 mins)

      - Generate Token by logging in with with `az login` then
   
        `az account get-access-token --resource={{FHIR-server-url}} --query accessToken --output tsv`

- An API tool - Postman, Insomnia, or curl. Make sure to set up your auth header using the generated token.
    - Postman Example Auth Header key value pair: `Authorization: Bearer <Your Token>`
    - The end of Step 4 of this guide has a CURL example

- Curl request example from command line: `curl -X GET --header "Authorization: Bearer <Your Token>" <Your FHIR server URL>/Patient`
  
- Shortcut for Postman Users:
  - You can import the phdi-fhir-api-template.postman_collection.json in this directory into Postman to auto-load this collection.
  - In Postman, import the collection with the Import button.
  - Click the three dots by the collection name and select Edit
  - Add your generated authorization token to the Authorization tab and your FHIR server url to the variables tab.
  - Update any and all variables in the variable tab for requests you want to try
  - DON'T FORGET TO HIT SAVE IN THE TOP RIGHT AFTER DOING THIS or Postman will not apply the changes. The save button may be obscured by the Collection Details panel, so close that if you can't find save 

#### Gotchas:
Watch out for capitalization in urls, for example:
{{FHIR-server-url}}/Patient not {FHIR-server-url}/patient

GET Metadata, does not require auth, good for health checking the server
`{{FHIR-server-url}}/Metadata`

###Basic Templates
####GET Requests
Template format to GET all of a certain resource:  
`{{FHIR-server-url}}/{{Resource Name}}`

Examples:

    GET all Patients:  
    `{{FHIR-server-url}}/Patient`
    
    GET all immunizations:  
    `{{FHIR-server-url}}/Immunization`


Template format to GET a specific resource by id:  
`{{FHIR-server-url}}/{{Resource Name}}/<id>`

Example:

    GET a specific Patient by id:  
    `{{FHIR-server-url}}/Patient/<id>`

Template DORMAT to GET all resources associated with a specific resource:  
`{{FHIR-server-url}}/{{Resource Name}}/<id>/{{Other Resource Name}}`

Example:

    GET all Observations associated with a Patient ID:  
    `{{FHIR-server-url}}/Patient/<PatientID>/Observation`

Template format resources with specific fields. Can be chained with multiple search fields and values using &:  
`{{FHIR-server-url}}/{{Resource Name}}?{{first search field name}}={{search value}}&{{second search field name}}={{search value}}`

Examples:

    GET all patients named John Doe:  
    `{{FHIR-server-url}}/Patient?family=DOE&given=JOHN`
    
    GET all Immunizations associated with a Patient ID:  
    `{{FHIR-server-url}}/Patient/<PatientID>/Immunization`

Template for chaining resource references using nested objects:  
`{{FHIR-server-url}}/{{Resource Name}}?{{object.key}}={{search value}}`

Example:

    GET all immunizations for Patients with a specific family name:  
    `{{FHIR-server-url}}/Immunization?subject.family=<family name>`

####PUT
Template for modifying resource with PUT:  
`{{FHIR-server-url}}/{{Resource Name}}/<ResourceID>`

Example:

    Update a patient with PUT:  
    `{{FHIR-server-url}}/Patient/<PatientID>`
    Request Body: RAW JSON Patient object

####POST
Template for adding a resource:  
`{{FHIR-server-url}}/{{Resource Name}}/<ResourceID>`   
`Request Body: Raw JSON resource object`

Example:

    Add a patient with POST:  
    `{{FHIR-server-url}}/Patient`
    Request Body: RAW JSON Patient object

####DELETE
Template for removing a resource:  
`{{FHIR-server-url}}/{{Resource Name}}/<ResourceID>`

Example:

    Remove a patient with DELETE:  
    `{{FHIR-server-url}}/Patient/<PatientID>`

###Operations to include referenced resources
####_include
GET a resource, AND resource(s) referenced within it

Template to join resources using _include:  
`{{FHIR-server-url}}/{{Resource Name}}?_include={{Resource Name}}:{{matching reference type}}`

Examples:

    GET all Observation Resources AND the Patient resource referenced within:  
    `{{FHIR-server-url}}/Observation?_include=Observation:subject`
    
    GET a specific Observation Resource AND the Performer referenced within:  
    `{{FHIR-server-url}}/Observation?_id=<id>&_include=Observation:performer`
    
    GET a Claim resource by ID AND the Provider referenced within:  
    `{{FHIR-server-url}}/Claim?_id=<id>&_include=Claim:provider`

####_revinclude
GET a resource AND resource(s) referencing that resource

Template to join resources using _revinclude:  
`{{FHIR-server-url}}/{{Resource Name}}?_include={{Referencing Resource Name}}:{{matching reference type}}`

Examples:

    GET all Patient resources AND all Observation resources referencing those Patients:  
    `{{FHIR-server-url}}/Patient?_revinclude=Observation:subject`
    
    GET a Patient Resource by id AND all Immunization resources associated with that Patient:  
    `{{FHIR-server-url}}/Patient?_id=<Patient id>&_revinclude=Immunization:patient`
    
    GET a Practitioner Resource by id AND all Encounters referencing that Practitioner:  
    `{{FHIR-server-url}}/Practitioner?_id=<id>&_revinclude=Encounter:practitioner`

###Additional Modifiers

Add a total found record count:  
`&_total=accurate`

Set number of items returned per page:
`?_count=<desired number of items>`

De-paginates a request response, if the bundle size would be paginated:  
`$everything`
