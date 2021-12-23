#%%
# use lxml
from lxml import etree

#%%
# the data needs to be accessed from https://isd.digital.nhs.uk/trud
# NHSBSA dm+d supplementary, file names of the .zip starting with 'nhsbsa_dmdbonus_xxx'
# the zip file contains an .xml file that needs to be read using nhsbsa_dmdbonus_
tree = etree.parse("data/week492021-r2_3-BNF/f_bnf1_0021221.xml")
vmps = tree.xpath("/BNF_DETAILS/VMPS/VMP")

# %%
# writing a .csv file row by row using this nested for loop
with open("data/ddd_week492021.csv", "w") as f:
    f.write('"VPID","BNF","ATC","DDD","DDD_UOMCD"\n')
    fields = ["VPID", "BNF", "ATC", "DDD", "DDD_UOMCD"]
    for vmp in vmps:
        values = {f: "" for f in fields}
        for child in vmp.getchildren():
            values[child.tag] = child.text if child.text != "n/a" else ""
        vpid = values["VPID"]
        bnf = values["BNF"]
        atc = values["ATC"]
        ddd = values["DDD"]
        ddd_uomcd = values["DDD_UOMCD"]
        f.write(f'"{vpid}","{bnf}","{atc}","{ddd}","{ddd_uomcd}"\n')
