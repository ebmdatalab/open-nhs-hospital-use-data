#%%
# use lxml
from lxml import etree

#%%
tree = etree.parse("data/week492021-r2_3-BNF/f_bnf1_0021221.xml")
vmps = tree.xpath("/BNF_DETAILS/VMPS/VMP")

# %%
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
