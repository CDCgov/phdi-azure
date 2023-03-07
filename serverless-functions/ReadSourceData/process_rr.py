from lxml import etree

# from phdi.cloud.azure import AzureCredentialManager, AzureCloudContainerConnection


def rr_to_ecr(rr, ecr):
    # storage_account_url = "https://phdidevphi9d194c64.blob.core.windows.net"
    # container_name = "source-data"
    # filename1 = "ecr/CDA_RR.xml"
    # filename2 = "ecr/CDA_eICR.xml"

    # cred_manager = AzureCredentialManager(resource_location=storage_account_url)
    # cloud_container_connection = AzureCloudContainerConnection(
    #     storage_account_url=storage_account_url, cred_manager=cred_manager
    # )
    # rr = cloud_container_connection.download_object(
    #     container_name=container_name, filename=filename1
    # )
    # ecr = cloud_container_connection.download_object(
    #     container_name=container_name, filename=filename2
    # )

    rr = etree.fromstring(rr)
    ecr = etree.fromstring(ecr)
    
    # Create the tags for elements we'll be looking for
    rr_tags = [
        "templateId",
        "id",
        "code",
        "title",
        "effectiveTime",
        "confidentialityCode",
    ]
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
        if entry.attrib and "DRIV" in entry.attrib["typeCode"]:
            organizer = entry.find(f"./{organizer_tag}", namespaces=entry.nsmap)
            if (
                organizer is not None
                and "CLUSTER" in organizer.attrib["classCode"]
                and "EVN" in organizer.attrib["moodCode"]
            ):
                rr_entry = entry
                exit

    # Create the section element with root-level elements
    # and entry to insert in the eICR
    if rr_entry is not None:
        # TODO figure out if we need to make the tag this way
        ecr_section_tag = "{urn:hl7-org:v3}" + "section"
        ecr_section = etree.Element(ecr_section_tag)
        # ecr_section.set('xmlns', 'urn:hl7-org:v3')  # not sure if we need this
        ecr_section.extend(rr_elements)
        ecr_section.append(rr_entry)

    # Append the ecr section into the eCR - puts it at the end
    ecr.append(ecr_section)

    # # TODO remove this - makes sure the section is in the ecr with all elements
    # section_tag = "{urn:hl7-org:v3}" + "section"
    # all_sections = ecr.findall(f"./{section_tag}", namespaces=ecr.nsmap)
    # print(all_sections[0].tag)
    # print(all_sections[0][0].tag)
    # print(all_sections[0][1].tag)
    # print(all_sections[0][2].tag)
    # print(all_sections[0][3].tag)
    # print(all_sections[0][4].tag)
    # print(all_sections[0][5].tag)
    # print(all_sections[0][6].tag)

    return ecr
