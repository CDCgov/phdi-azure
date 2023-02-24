from lxml import etree

rr = "CDA_RR.xml"

tree = etree.parse(rr)

print(tree)
