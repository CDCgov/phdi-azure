from lxml import etree
import json
from pathlib import Path
import xmltodict

# TODO Convert the code to the body of a function
# called `process_rr` that takes the rr and ecr read
# from blob storage. process_rr will get called in the
# ReadSourceData main function and process_rr will send
# back an xml file
# (this is way too much code to put directly in the file)
# def process_rr(rr, ecr) -> __file__:

# TODO Get jsonifying files to work properly so the
# processing works. Need to convert the xml pulled
# directly from blob storage, currently using the two
# files below for testing

# Get the RR and eICR files
# (eventually want to just use the parameters passed in
# instead of these hard coded testing files)
ecr_file_name = 'CDA_eICR.xml'
rr_file_name = 'CDA_RR.xml'
with open(rr_file_name, 'r') as rr_file:
    data_dict_rr = xmltodict.parse(rr_file.read())
with open(ecr_file_name, 'r') as ecr_file:
    data_dict_ecr = xmltodict.parse(ecr_file.read())

# generate the object using json.dumps()
# corresponding to json data
json_data_rr = json.dumps(data_dict_rr)
json_data_ecr = json.dumps(data_dict_ecr)

# Write the json data to output
# json file
jsonified_rr_file_name = "jsonified_CDA_RR.xml"
jsonified_ecr_file_name = "jsonified_CDA_eICR.xml"
with open(jsonified_rr_file_name, "w") as json_file:
    json_file.write(json_data_rr)
with open(jsonified_ecr_file_name, "w") as json_file:
    json_file.write(json_data_ecr)

# Everything works from here, given we jsonified the xml files correctly
# (currently not jsonified correctly so it fails on lines 48-49)
# Read and parse the file

# this does not work
rr = json.loads(Path(jsonified_rr_file_name).read_text())
ecr = json.loads(Path(jsonified_ecr_file_name).read_text())
# this works
# rr = json.loads(Path("sample_jsonified_CDA_RR.xml").read_text())
# ecr = json.loads(Path("sample_jsonified_CDA_eICR.xml").read_text())

ecr = etree.fromstring(ecr)
rr = etree.fromstring(rr)

# Create the tags for elements we'll be looking for
rr_tags = ["templateId", "id", "code", "title", "effectiveTime", "confidentialityCode"]
rr_tags = ["{urn:hl7-org:v3}" + tag for tag in rr_tags]
rr_elements = []

# Find root-level elements and add them to a list
for tag in rr_tags:
    rr_elements.append(rr.find(f"./{tag}", namespaces=rr.nsmap))

# TODO remove this - makes sure rr_elements contains everything we want
# for element in rr_elements:
#     if (element.attrib):
#         print(str(element.tag) + " " + str(element.attrib))
#     elif (element.text):
#         print(str(element.tag) + " " + str(element.text))
#     else:
#         print(str(element.tag))

# Find the nested entry element that we need
entry_tag = "{urn:hl7-org:v3}" + "component/structuredBody/component/section/entry"
rr_nestedEntries = rr.findall(f"./{entry_tag}", namespaces=rr.nsmap)

organizer_tag = "{urn:hl7-org:v3}" + "organizer"

# For now we assume there is only one matching entry
for entry in rr_nestedEntries:
    if entry.attrib and 'DRIV' in entry.attrib['typeCode']:
        organizer = entry.find(f"./{organizer_tag}", namespaces=entry.nsmap)
        if (
            organizer is not None
            and 'CLUSTER' in organizer.attrib['classCode']
            and 'EVN' in organizer.attrib['moodCode']
        ):
            rr_entry = entry
            exit

# Create the section element with root-level elements and entry to insert in the eICR
if rr_entry is not None:
    # TODO figure out if we need to make the tag this way
    ecr_section_tag = "{urn:hl7-org:v3}" + "section"
    ecr_section = etree.Element(ecr_section_tag)
    # ecr_section.set('xmlns', 'urn:hl7-org:v3')  # not sure if we need this
    ecr_section.extend(rr_elements)
    ecr_section.append(rr_entry)

# Append the ecr section into the eCR - puts it at the end
ecr.append(ecr_section)

# TODO remove this - makes sure the section is in the ecr with all elements
section_tag = "{urn:hl7-org:v3}" + "section"
all_sections = ecr.findall(f"./{section_tag}", namespaces=ecr.nsmap)
print(all_sections[0].tag)
print(all_sections[0][0].tag)
print(all_sections[0][1].tag)
print(all_sections[0][2].tag)
print(all_sections[0][3].tag)
print(all_sections[0][4].tag)
print(all_sections[0][5].tag)
print(all_sections[0][6].tag)

# TODO Need to convert the jsonified ecr back to xml
# because that's what ReadSourceData expects
# return ecr

# Garbage -->

# # Experiment #1 - not working
# rr = "CDA_RR.xml"
# tree = etree.parse(rr)
# root = tree.getroot()
# thing = root.xpath('component')
# print(len(thing))

# # Experiment #2 - not working
# namespaces = {
#     "hl7": "urn:hl7-org:v3",
#     "xsi": "http://www.w3.org/2005/Atom",
#     "cda": "urn:hl7-org:v3",
#     "sdtc": "urn:hl7-org:sdtc",
#     "voc": "http://www.lantanagroup.com/voc",
# }

# xml = rr.encode("utf-8")
# parser = etree.XMLParser(ns_clean=True, recover=True, encoding="utf-8")
# parsed_rr = etree.fromstring(xml, parser=parser)
# matched_nodes = parsed_rr.getRoot().xpath('/ClinicalDocument/templateId')
# print(matched_nodes)
# matched_nodes = parsed_rr.xpath(cda_path, namespaces=namespaces)